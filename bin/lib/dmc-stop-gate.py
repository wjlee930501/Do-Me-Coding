#!/usr/bin/env python3
"""dmc-stop-gate.py — DMC v1.0 M6 stop-completion quick gate (§M6 (iv)).

The fast, state-file-only precondition the Stop hook consults before a completion claim is accepted.
It replaces the legacy keyword-triggered existence check with a real receipt-coverage + semantic
gate armed from run state. Budget: < 2s on a fixture repo (no network, no full self-test, a handful
of state-file reads + a few read-only subprocesses).

Decision:
  - No active run, or the run is SUSPENDED / DONE  ⇒ PASS (nothing to hold; `dmc run suspend` is the
    escape hatch).
  - `blocked.json` present (unresolved sidecar marker)  ⇒ HOLD (a post-Bash out-of-scope change or a
    guard block is outstanding; cleared only by `dmc run unblock`).
  - Receipt coverage: every REQUIRED check_id (verify-plan.json `resolved_by`, else acceptance.json
    `checks[].check_id`) must have a receipt in the evidence ledger (dmc-evidence-ledger coverage,
    reuse-by-subprocess). Any uncovered required check ⇒ HOLD. When a verification report is present
    it is additionally cross-checked (dmc-verify-crosscheck); a REFUSE ⇒ HOLD.
  - No compiled check set at all ⇒ fall back to: a verification report exists for this run AND
    dmc-verify-crosscheck ACCEPTs it — else HOLD (no evidence of completion).

Inputs:  [--run DIR] [--root DIR] [--run-id ID] [--report FILE]
Exit:    0 PASS · 4 HOLD  (usage error ⇒ 2)

House rules (v0.6.x / M2-M6 lineage): stdlib-only, deterministic, env-independent (no env reads),
offline, fail-closed, value-blind, secret paths refused by path. Reuse-by-subprocess: the evidence
ledger and the cross-check are read-only subprocesses so the modules stay independently deletable.
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time

EXIT_PASS = 0
EXIT_HOLD = 4

ACTIVE_STATES = {"INIT", "RUNNING", "RESUMING"}
POINTER_NAME = "current-run-id"
LEDGER_NAME = "dmc-evidence-ledger.py"
CROSSCHECK_NAME = "dmc-verify-crosscheck.py"


# ------------------------------------------------------------------- helpers

def die(msg, code=2):
    sys.stderr.write("dmc-stop-gate: %s\n" % msg)
    sys.exit(code)


def sibling(name):
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), name)


def _emit(decision, reason):
    print("%s: %s" % ("STOP-PASS" if decision == "pass" else "STOP-HOLD", reason))
    sys.exit(EXIT_PASS if decision == "pass" else EXIT_HOLD)


def _load_json(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return None


def runs_dir(root):
    return os.path.join(root, ".harness", "runs")


def resolve_run(root, run_dir_arg, run_id_arg):
    """Return (run_dir | None, run_id | None, root). None run_dir ⇒ no active run resolvable."""
    if run_dir_arg:
        rd = os.path.abspath(run_dir_arg)
        rid = os.path.basename(os.path.normpath(rd))
        derived_root = os.path.normpath(os.path.join(rd, "..", "..", ".."))
        return rd, rid, derived_root
    if run_id_arg:
        return os.path.join(runs_dir(root), run_id_arg), run_id_arg, root
    ptr = os.path.join(runs_dir(root), POINTER_NAME)
    if os.path.isfile(ptr):
        with open(ptr, "r", encoding="utf-8") as f:
            rid = f.read().strip()
        if rid:
            return os.path.join(runs_dir(root), rid), rid, root
    return None, None, root


def required_checks(run_dir):
    """Required check_ids: verify-plan.json resolved_by (preferred), else acceptance.json ids.

    Returns (checks: set, source: str|None). source None ⇒ no compiled check set.
    """
    vp = _load_json(os.path.join(run_dir, "verify-plan.json"))
    if isinstance(vp, dict) and isinstance(vp.get("coverage"), list):
        ids = set()
        for c in vp["coverage"]:
            if isinstance(c, dict):
                ids.update(i for i in (c.get("resolved_by") or []) if isinstance(i, str) and i)
        if ids:
            return ids, "verify-plan.json"
    acc = _load_json(os.path.join(run_dir, "acceptance.json"))
    if isinstance(acc, dict) and isinstance(acc.get("checks"), list):
        ids = {c.get("check_id") for c in acc["checks"]
               if isinstance(c, dict) and isinstance(c.get("check_id"), str) and c.get("check_id")}
        if ids:
            return ids, "acceptance.json"
    return set(), None


def ledger_covered(root, run_id, check_id):
    """True iff the evidence ledger reports COVERED (exit 0). Reuse-by-subprocess."""
    tool = sibling(LEDGER_NAME)
    if not os.path.isfile(tool):
        return False
    try:
        r = subprocess.run([sys.executable, "-B", tool, "coverage", "--root", root,
                            "--run-id", run_id, "--check-id", check_id],
                           capture_output=True, text=True, timeout=20)
    except OSError:
        return False
    return r.returncode == 0


def discover_report(run_dir, report_arg):
    """The run's verification report: --report, else <run_dir>/verification.md if present."""
    if report_arg and os.path.isfile(report_arg):
        return os.path.abspath(report_arg)
    local = os.path.join(run_dir, "verification.md")
    return local if os.path.isfile(local) else None


def crosscheck_accepts(report_path, run_dir):
    """True iff dmc-verify-crosscheck ACCEPTs the report (exit 0). Reuse-by-subprocess."""
    tool = sibling(CROSSCHECK_NAME)
    if not os.path.isfile(tool):
        return False
    try:
        r = subprocess.run([sys.executable, "-B", tool, "--report", report_path, "--run", run_dir],
                           capture_output=True, text=True, timeout=20)
    except OSError:
        return False
    return r.returncode == 0


# --------------------------------------------------------------------- gate

def gate(root, run_dir_arg, run_id_arg, report_arg):
    run_dir, run_id, root2 = resolve_run(root, run_dir_arg, run_id_arg)
    if not run_dir or not os.path.isdir(run_dir):
        _emit("pass", "no active run resolvable (nothing to hold)")

    run = _load_json(os.path.join(run_dir, "run.json"))
    status = run.get("status") if isinstance(run, dict) else None
    if status not in ACTIVE_STATES:
        _emit("pass", "run not active (status=%s); stop not gated" % (status or "unknown"))

    # BLOCKED sidecar marker (unresolved) holds the stop unconditionally.
    blocked = _load_json(os.path.join(run_dir, "blocked.json"))
    if blocked is not None:
        reason = blocked.get("reason") if isinstance(blocked, dict) else None
        _emit("hold", "run is BLOCKED (unresolved blocked.json): %s — clear via `dmc run unblock`"
                      % (reason or "see blocked.json"))

    report = discover_report(run_dir, report_arg)
    checks, source = required_checks(run_dir)

    if checks:
        uncovered = sorted(c for c in checks if not ledger_covered(root2, run_id, c))
        if uncovered:
            _emit("hold", "receipt coverage incomplete for %d required check(s) from %s "
                          "(uncovered: %s)" % (len(uncovered), source, ", ".join(uncovered)))
        if report is not None and not crosscheck_accepts(report, run_dir):
            _emit("hold", "verification report present but fails the semantic cross-check")
        _emit("pass", "all %d required check(s) from %s are receipt-covered"
                      % (len(checks), source))

    # No compiled check set: require a report + an ACCEPTing cross-check.
    if report is None:
        _emit("hold", "no compiled check set and no verification report for this run "
                      "(no evidence of completion)")
    if not crosscheck_accepts(report, run_dir):
        _emit("hold", "verification report fails the semantic cross-check")
    _emit("pass", "verification report present and cross-check ACCEPTs (no compiled check set)")


# ------------------------------------------------------------------- self-test

class ST:
    def __init__(self, name):
        self.name, self.passed, self.failed = name, 0, 0

    def ok(self, label, cond):
        if cond:
            self.passed += 1
            print("PASS [%s] %s" % (self.name, label))
        else:
            self.failed += 1
            print("FAIL [%s] %s" % (self.name, label))

    def done(self):
        print("[%s] %d PASS / %d FAIL" % (self.name, self.passed, self.failed))
        sys.exit(0 if self.failed == 0 else 1)


def _real_repo_porcelain():
    git = shutil.which("git")
    if not git:
        return None
    root = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
    try:
        r = subprocess.run([git, "-C", root, "status", "--porcelain"], capture_output=True, timeout=10)
        return r.stdout if r.returncode == 0 else None
    except Exception:
        return None


def _canon_hash(obj):
    import hashlib
    payload = json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def _fixture_lock(run_dir):
    body = {
        "schema": "dmc.scope-lock.v1", "work_id": "dmc-stopgate-selftest",
        "plan_hash": "a" * 40, "repo_hash": "b" * 40, "run_id": os.path.basename(run_dir),
        "approved_by": "SYNTHETIC-FIXTURE",
        "files": [{"path": "src/app.py", "grant": "edit", "landmark_class": "ordinary"}],
        "bounds": {"max_files": 3, "max_added": 200, "max_deleted": 50,
                   "forbidden_hunk_classes": []},
        "immutable": True, "compiled_at_head": "no-git", "prev_hash": "0" * 64,
    }
    core = {k: v for k, v in body.items() if k != "state_hash"}
    lock = dict(core, state_hash=_canon_hash(core))
    with open(os.path.join(run_dir, "scope.lock.json"), "w", encoding="utf-8") as f:
        f.write(json.dumps(lock, sort_keys=True, indent=2) + "\n")


def _mk_run(root, run_id, status="RUNNING"):
    rd = os.path.join(runs_dir(root), run_id)
    os.makedirs(rd, exist_ok=True)
    with open(os.path.join(rd, "run.json"), "w", encoding="utf-8") as f:
        f.write(json.dumps({"run_id": run_id, "status": status}) + "\n")
    with open(os.path.join(runs_dir(root), POINTER_NAME), "w", encoding="utf-8") as f:
        f.write(run_id + "\n")
    _fixture_lock(rd)
    return rd


def _mint(root, run_id, check_id):
    tool = sibling(LEDGER_NAME)
    return subprocess.run([sys.executable, "-B", tool, "mint", "--root", root, "--run-id", run_id,
                           "--check-id", check_id, "--evidence-type", "verification-report",
                           "--artifact-ref", "ver/report.md", "--work-id", "W",
                           "--plan-hash", "a" * 40, "--repo-hash", "b" * 40,
                           "--verification-ref", "ver/report.md"],
                          capture_output=True, text=True)


def _write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def _report_text(run_id, changed="- src/app.py: edited", cmd_result="PASS", final="PASS"):
    return """# Verification Report

## Run ID
%s
## Plan
p
## Changed Files
%s
## Commands Run
| Command | Result | Reason | Output Summary |
|---|---|---|---|
| pytest | %s | r | s |
## Manual Checks
| Check | Result | Notes |
|---|---|---|
| c | PASS | n |
## Scope Review
Result: PASS

Notes:
## Package / Env / Migration Review
Package files changed: no
Env files changed: no
Migration files changed: no

Notes:
## Unresolved Risks
- none
## Final Status
%s
""" % (run_id, changed, cmd_result, final)


def _run_cli(root, *args):
    return subprocess.run([sys.executable, "-B", os.path.abspath(__file__), "--root", root, *args],
                          capture_output=True, text=True)


def selftest():
    t = ST("stop-gate")
    before = _real_repo_porcelain()
    tmp = tempfile.mkdtemp(prefix="dmc-stopgate-")
    try:
        os.makedirs(runs_dir(tmp), exist_ok=True)

        # C0 no active run (no pointer) ⇒ PASS.
        r = _run_cli(tmp)
        t.ok("C0 no active run ⇒ PASS exit 0", r.returncode == EXIT_PASS)

        # C1 SUSPENDED run ⇒ PASS (suspend escape hatch).
        _mk_run(tmp, "dmc-run-suspended", status="SUSPENDED")
        r = _run_cli(tmp)
        t.ok("C1 SUSPENDED run ⇒ PASS exit 0", r.returncode == EXIT_PASS)

        # C2 RUNNING + blocked.json present ⇒ HOLD.
        rd = _mk_run(tmp, "dmc-run-blocked", status="RUNNING")
        _write(os.path.join(rd, "blocked.json"),
               json.dumps({"reason": "out-of-scope write", "paths": ["x"]}) + "\n")
        r = _run_cli(tmp)
        t.ok("C2 RUNNING + unresolved blocked.json ⇒ HOLD exit 4",
             r.returncode == EXIT_HOLD and "BLOCKED" in r.stdout)

        # C3 compiled checks fully receipt-covered, no report ⇒ PASS.
        rd = _mk_run(tmp, "dmc-run-covered", status="RUNNING")
        _write(os.path.join(rd, "verify-plan.json"), json.dumps({
            "coverage": [{"path": "src/app.py", "radius_check_ids": ["CHK-A"],
                          "resolved_by": ["CHK-A"]}]}) + "\n")
        m = _mint(tmp, "dmc-run-covered", "CHK-A")
        r = _run_cli(tmp)
        t.ok("C3 required checks receipt-covered ⇒ PASS exit 0",
             m.returncode == 0 and r.returncode == EXIT_PASS)

        # C4 a required check NOT covered ⇒ HOLD.
        rd = _mk_run(tmp, "dmc-run-uncovered", status="RUNNING")
        _write(os.path.join(rd, "verify-plan.json"), json.dumps({
            "coverage": [{"path": "src/app.py", "radius_check_ids": ["CHK-A", "CHK-B"],
                          "resolved_by": ["CHK-A", "CHK-B"]}]}) + "\n")
        _mint(tmp, "dmc-run-uncovered", "CHK-A")     # only CHK-A minted; CHK-B uncovered
        r = _run_cli(tmp)
        t.ok("C4 an uncovered required check ⇒ HOLD exit 4",
             r.returncode == EXIT_HOLD and "coverage incomplete" in r.stdout)

        # C5 no compiled check set + no report ⇒ HOLD.
        _mk_run(tmp, "dmc-run-bare", status="RUNNING")
        r = _run_cli(tmp)
        t.ok("C5 no compiled checks + no report ⇒ HOLD exit 4",
             r.returncode == EXIT_HOLD and "no evidence of completion" in r.stdout)

        # C6 no compiled check set + a report that cross-checks ACCEPT ⇒ PASS.
        rd = _mk_run(tmp, "dmc-run-reportonly", status="RUNNING")
        _write(os.path.join(rd, "verification.md"), _report_text("dmc-run-reportonly"))
        r = _run_cli(tmp)
        t.ok("C6 report-only + cross-check ACCEPT ⇒ PASS exit 0", r.returncode == EXIT_PASS)

        # C7 compiled checks covered BUT report cross-check REFUSES (PASS-with-FAIL) ⇒ HOLD.
        rd = _mk_run(tmp, "dmc-run-dishonest", status="RUNNING")
        _write(os.path.join(rd, "verify-plan.json"), json.dumps({
            "coverage": [{"path": "src/app.py", "radius_check_ids": ["CHK-A"],
                          "resolved_by": ["CHK-A"]}]}) + "\n")
        _mint(tmp, "dmc-run-dishonest", "CHK-A")
        _write(os.path.join(rd, "verification.md"),
               _report_text("dmc-run-dishonest", cmd_result="FAIL", final="PASS"))
        r = _run_cli(tmp)
        t.ok("C7 covered checks + dishonest report (PASS-with-FAIL) ⇒ HOLD exit 4",
             r.returncode == EXIT_HOLD and "cross-check" in r.stdout)

        # C8 timing budget: the covered-run quick gate completes well under 2s.
        start = time.monotonic()
        _run_cli(tmp, "--run-id", "dmc-run-covered")
        elapsed = time.monotonic() - start
        t.ok("C8 quick gate under 2s (%.3fs)" % elapsed, elapsed < 2.0)

        # C9 --run DIR form resolves the run directly.
        r = _run_cli(tmp, "--run", os.path.join(runs_dir(tmp), "dmc-run-covered"))
        t.ok("C9 --run DIR form resolves + PASSes the covered run", r.returncode == EXIT_PASS)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    after = _real_repo_porcelain()
    t.ok("Z1 real repo git status --porcelain byte-identical before/after (or git absent)",
         before == after)
    t.done()


# ------------------------------------------------------------------------ main

def main():
    ap = argparse.ArgumentParser(prog="dmc-stop-gate")
    ap.add_argument("--root", default=".")
    ap.add_argument("--run", dest="run_dir", metavar="DIR")
    ap.add_argument("--run-id", dest="run_id", metavar="ID")
    ap.add_argument("--report", metavar="FILE")
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args()

    if a.self_test:
        selftest()
        return

    root = os.path.abspath(a.root)
    gate(root, a.run_dir, a.run_id, a.report)


if __name__ == "__main__":
    main()
