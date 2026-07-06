#!/usr/bin/env python3
"""dmc-verify-crosscheck.py — DMC v1.0 M6 semantic verification-report cross-check (§M6 (iii)).

A verification report can be structurally VALID (per `dmc validate verification`) yet dishonest: it
can claim a PASS while a required command failed, name the wrong run, or omit a changed file that is
actually dirty in the worktree. This cross-check closes that gap — it is the semantic gate the Stop
hook consults before a completion claim is accepted.

Checks (all against `--run DIR`, the active run directory):
  1. STRUCTURAL — the report passes `dmc validate verification` (dmc-instance-validate, reused by
     subprocess). A structurally-broken report is refused outright.
  2. RUN-ID BINDING — the report's `## Run ID` equals the active run id (run.json run_id, else the
     run-dir basename). A report for another run cannot close this one.
  3. CHANGED-FILES INTEGRITY — every path declared under `## Changed Files` adjudicates INSIDE the
     scope lock or the narrow internal exemption; AND (git ground truth) no actually-dirty,
     non-exempt worktree path is left UNDECLARED. Either way ⇒ REFUSE.
  4. PASS HONESTY — a `## Final Status` of PASS is refused when any `## Commands Run` row is FAIL,
     or is SKIP/SKIPPED without a non-empty Reason cell (no silent green).

Reuse-by-subprocess: dmc-instance-validate (structural) and dmc-scope-lock (adjudication) are read-
only subprocesses; this module imports neither, so all three stay independently deletable.

Exit:   0 ACCEPT · 3 REFUSE (itemized reasons)  ·  usage error ⇒ 2
House rules (v0.6.x / M2-M6 lineage): stdlib-only, deterministic, env-independent (no env reads),
offline (git is a read-only ground-truth query), fail-closed, value-blind (reasons name the rule +
paths, never file contents), secret paths refused by path.
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

INSTANCE_VALIDATE_NAME = "dmc-instance-validate.py"
SCOPE_LOCK_NAME = "dmc-scope-lock.py"
EXEMPT_PREFIXES = (".harness/evidence/", ".harness/verification/", ".harness/runs/")
FINAL_STATUSES = ("PASS", "FAIL", "PARTIAL")
SKIP_TOKENS = ("SKIP", "SKIPPED", "N/A", "NA")


# ------------------------------------------------------------------- helpers

def die(msg, code=2):
    sys.stderr.write("dmc-verify-crosscheck: %s\n" % msg)
    sys.exit(code)


def refuse(reasons):
    for r in reasons:
        print("REFUSED: %s" % r)
    sys.exit(3)


def sibling(name):
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), name)


def _norm(p):
    return p.replace("\\", "/").strip()


def parse_sections(text):
    """Fence-aware markdown parse: {exact h2 header -> body lines}. Mirrors the instance parser."""
    sections, cur, in_fence = {}, None, False
    for line in text.splitlines():
        stripped = line.lstrip()
        if stripped.startswith("```"):
            in_fence = not in_fence
            if cur is not None:
                sections[cur].append(line)
            continue
        if not in_fence and line.startswith("## "):
            cur = line[3:].strip()
            sections.setdefault(cur, [])
            continue
        if cur is not None:
            sections[cur].append(line)
    return sections


def _first_nonempty(lines):
    for ln in lines:
        if ln.strip():
            return ln.strip()
    return ""


def parse_changed_files(lines):
    """Declared changed paths from a `## Changed Files` section. Skips a 'none' placeholder."""
    paths = []
    for ln in lines:
        s = ln.strip()
        if not s.startswith("-"):
            continue
        item = s[1:].strip()
        if item.lower() in ("none", "n/a", "na", "(none)"):
            continue
        head = item.split(":", 1)[0].strip()
        head = head.strip("`").strip()
        if head:
            paths.append(_norm(head))
    return paths


def parse_command_rows(lines):
    """Data rows of the `## Commands Run` markdown table → list of (result, reason)."""
    rows = []
    for ln in lines:
        s = ln.strip()
        if not s.startswith("|"):
            continue
        cells = [c.strip() for c in s.strip("|").split("|")]
        if not cells:
            continue
        joined = "".join(cells).replace(" ", "")
        if set(joined) <= set("-:"):        # the |---|---| separator row
            continue
        if cells[0].lower() in ("command", "cmd"):   # header row
            continue
        result = cells[1].upper() if len(cells) > 1 else ""
        reason = cells[2] if len(cells) > 2 else ""
        rows.append((result, reason))
    return rows


# ------------------------------------------------------------ reuse-by-subprocess

def structural_ok(report_path):
    tool = sibling(INSTANCE_VALIDATE_NAME)
    if not os.path.isfile(tool):
        return False
    try:
        r = subprocess.run([sys.executable, "-B", tool, "verification", "--validate", report_path],
                           capture_output=True, text=True, timeout=30)
    except OSError:
        return False
    return r.returncode == 0


def adjudicate_in_scope(scope_lock_path, path):
    tool = sibling(SCOPE_LOCK_NAME)
    if not os.path.isfile(tool) or not os.path.isfile(scope_lock_path):
        return False
    try:
        r = subprocess.run([sys.executable, "-B", tool, "--adjudicate", scope_lock_path,
                            path, "edit"], capture_output=True, text=True, timeout=15)
    except OSError:
        return False
    return r.returncode == 0


def git_changed(root):
    """Actual dirty paths (status --porcelain -uall ∪ diff --name-only). git-absent ⇒ None."""
    git = shutil.which("git")
    if not git:
        return None
    paths = set()
    try:
        r = subprocess.run([git, "-C", root, "status", "--porcelain", "--untracked-files=all"],
                           capture_output=True, text=True, timeout=15)
        if r.returncode == 0:
            for line in r.stdout.splitlines():
                if len(line) >= 4:
                    body = line[3:]
                    body = body.split(" -> ", 1)[1] if " -> " in body else body
                    paths.add(_norm(body.strip().strip('"')))
    except Exception:
        return None
    try:
        r2 = subprocess.run([git, "-C", root, "diff", "--name-only"],
                            capture_output=True, text=True, timeout=15)
        if r2.returncode == 0:
            paths.update(_norm(x.strip().strip('"')) for x in r2.stdout.splitlines() if x.strip())
    except Exception:
        pass
    return {p for p in paths if p}


def _is_exempt(p):
    return p.startswith(EXEMPT_PREFIXES)


# --------------------------------------------------------------- cross-check

def active_run_id(run_dir):
    """The run's id: run.json run_id if present/valid, else the run-dir basename."""
    rj = os.path.join(run_dir, "run.json")
    if os.path.isfile(rj):
        try:
            with open(rj, "r", encoding="utf-8") as f:
                obj = json.load(f)
            rid = obj.get("run_id") if isinstance(obj, dict) else None
            if isinstance(rid, str) and rid.strip():
                return rid.strip()
        except Exception:
            pass
    return os.path.basename(os.path.normpath(run_dir))


def crosscheck(report_path, run_dir):
    """Return a list of itemized REFUSE reasons ([] == ACCEPT)."""
    reasons = []
    if not os.path.isfile(report_path):
        return ["CROSSCHECK-REPORT-ABSENT: no verification report at the referenced path"]
    if not os.path.isdir(run_dir):
        return ["CROSSCHECK-RUN-DIR-ABSENT: --run is not a directory"]

    # (1) structural gate — a broken report cannot be cross-checked.
    if not structural_ok(report_path):
        return ["CROSSCHECK-STRUCTURAL-INVALID: report fails `dmc validate verification` "
                "(structural gate)"]

    with open(report_path, "r", encoding="utf-8") as f:
        sections = parse_sections(f.read())

    root = os.path.normpath(os.path.join(run_dir, "..", "..", ".."))
    scope_lock = os.path.join(run_dir, "scope.lock.json")

    # (2) run-id binding.
    declared_run = _first_nonempty(sections.get("Run ID", []))
    active = active_run_id(run_dir)
    # A report may present the id as `run_id: X` or a bare token — normalize a leading label.
    declared_run_norm = re.sub(r"(?i)^run[_ ]?id:\s*", "", declared_run).strip().strip("`")
    if declared_run_norm != active:
        reasons.append("CROSSCHECK-RUN-ID-MISMATCH: report Run ID does not match the active run id")

    # (3) changed-files integrity.
    declared = [p for p in parse_changed_files(sections.get("Changed Files", []))]
    for p in declared:
        if _is_exempt(p):
            continue
        if not adjudicate_in_scope(scope_lock, p):
            reasons.append("CROSSCHECK-CHANGED-FILE-OUT-OF-SCOPE: a declared Changed File "
                           "adjudicates outside the locked scope (%s)" % p)
    actual = git_changed(root)
    if actual is not None:
        declared_set = set(declared)
        undeclared = sorted(a for a in actual
                            if not _is_exempt(a) and a not in declared_set
                            and os.path.basename(report_path) != os.path.basename(a))
        for a in undeclared:
            reasons.append("CROSSCHECK-UNDECLARED-CHANGED-FILE: a dirty worktree path is not "
                           "declared under Changed Files (%s)" % a)

    # (4) PASS honesty.
    final = _first_nonempty(sections.get("Final Status", [])).upper()
    final_tok = final.split()[0] if final else ""
    rows = parse_command_rows(sections.get("Commands Run", []))
    if final_tok == "PASS":
        for result, reason in rows:
            if result == "FAIL":
                reasons.append("CROSSCHECK-PASS-WITH-FAIL: Final Status PASS but a required "
                               "Commands-Run row is FAIL")
            elif result in SKIP_TOKENS and not reason.strip():
                reasons.append("CROSSCHECK-PASS-WITH-UNJUSTIFIED-SKIP: Final Status PASS but a "
                               "required Commands-Run row is SKIPPED without a Reason")
    return reasons


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

    def check(self, label, thunk):
        try:
            cond = bool(thunk())
        except Exception as e:  # noqa: BLE001 — a broken fixture must FAIL, never abort the section
            self.ok("%s [EXC:%s]" % (label, e.__class__.__name__), False)
            return
        self.ok(label, cond)

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
        "schema": "dmc.scope-lock.v1", "work_id": "dmc-crosscheck-selftest",
        "plan_hash": "a" * 40, "repo_hash": "b" * 40, "run_id": "dmc-run-fixture",
        "approved_by": "SYNTHETIC-FIXTURE",
        "files": [{"path": "src/app.py", "grant": "edit", "landmark_class": "ordinary"}],
        "bounds": {"max_files": 3, "max_added": 200, "max_deleted": 50,
                   "forbidden_hunk_classes": []},
        "immutable": True, "compiled_at_head": "no-git", "prev_hash": "0" * 64,
    }
    core = {k: v for k, v in body.items() if k != "state_hash"}
    lock = dict(core, state_hash=_canon_hash(core))
    p = os.path.join(run_dir, "scope.lock.json")
    with open(p, "w", encoding="utf-8") as f:
        f.write(json.dumps(lock, sort_keys=True, indent=2) + "\n")
    return p


def _report(run_id="dmc-run-fixture", changed="- src/app.py: edited", cmd_result="PASS",
            cmd_reason="r", final="PASS"):
    return """# Verification Report

## Run ID
%s
## Plan
.harness/plans/x.md
## Changed Files
%s
## Commands Run
| Command | Result | Reason | Output Summary |
|---|---|---|---|
| pytest | %s | %s | s |
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
""" % (run_id, changed, cmd_result, cmd_reason, final)


def selftest():
    t = ST("verify-crosscheck")
    before = _real_repo_porcelain()
    tmp = tempfile.mkdtemp(prefix="dmc-crosscheck-")
    try:
        run_dir = os.path.join(tmp, ".harness", "runs", "dmc-run-fixture")
        os.makedirs(run_dir, exist_ok=True)
        _fixture_lock(run_dir)
        # A minimal run.json so active_run_id resolves via run_id (not just the dir basename).
        with open(os.path.join(run_dir, "run.json"), "w", encoding="utf-8") as f:
            f.write(json.dumps({"run_id": "dmc-run-fixture"}) + "\n")

        def write_report(text, name="report.md"):
            p = os.path.join(run_dir, name)
            with open(p, "w", encoding="utf-8") as f:
                f.write(text)
            return p

        # C0 clean report ACCEPTS (git absent in tmp non-repo ⇒ undeclared check skipped).
        good = write_report(_report())
        t.check("C0 valid, run-bound, in-scope, honest-PASS report ACCEPTED",
                lambda: crosscheck(good, run_dir) == [])

        # C1 run-id mismatch REFUSED.
        t.check("C1 REFUSE: report Run ID != active run id",
                lambda: any(e.startswith("CROSSCHECK-RUN-ID-MISMATCH")
                            for e in crosscheck(write_report(_report(run_id="dmc-run-other"),
                                                             "r1.md"), run_dir)))

        # C2 changed-file out of scope REFUSED.
        t.check("C2 REFUSE: a declared Changed File outside the locked scope",
                lambda: any(e.startswith("CROSSCHECK-CHANGED-FILE-OUT-OF-SCOPE")
                            for e in crosscheck(write_report(_report(changed="- src/other.py: x"),
                                                             "r2.md"), run_dir)))

        # C3 PASS with a FAIL command row REFUSED.
        t.check("C3 REFUSE: Final Status PASS but a Commands-Run row is FAIL",
                lambda: any(e.startswith("CROSSCHECK-PASS-WITH-FAIL")
                            for e in crosscheck(write_report(_report(cmd_result="FAIL"),
                                                             "r3.md"), run_dir)))

        # C4 PASS with a SKIPPED-no-reason row REFUSED.
        t.check("C4 REFUSE: Final Status PASS but a row is SKIPPED without a Reason",
                lambda: any(e.startswith("CROSSCHECK-PASS-WITH-UNJUSTIFIED-SKIP")
                            for e in crosscheck(write_report(
                                _report(cmd_result="SKIP", cmd_reason=""), "r4.md"), run_dir)))

        # C4b SKIPPED WITH a reason under PASS is allowed (skip is justified).
        t.check("C4b ACCEPT: SKIPPED with a non-empty Reason under PASS",
                lambda: crosscheck(write_report(_report(cmd_result="SKIP", cmd_reason="not applicable"),
                                                "r4b.md"), run_dir) == [])

        # C5 FAIL final status with a FAIL row is honest ⇒ no PASS-honesty refusal.
        t.check("C5 ACCEPT: an honest FAIL report (FAIL final + FAIL row) is not PASS-gated",
                lambda: not any(e.startswith("CROSSCHECK-PASS-WITH")
                                for e in crosscheck(write_report(
                                    _report(cmd_result="FAIL", final="FAIL"), "r5.md"), run_dir)))

        # C6 structurally-broken report REFUSED (missing Final Status section).
        broken = _report().replace("## Final Status\nPASS\n", "")
        t.check("C6 REFUSE: structurally-invalid report (structural gate)",
                lambda: any(e.startswith("CROSSCHECK-STRUCTURAL-INVALID")
                            for e in crosscheck(write_report(broken, "r6.md"), run_dir)))

        # C7 absent report REFUSED.
        t.check("C7 REFUSE: absent report path",
                lambda: any(e.startswith("CROSSCHECK-REPORT-ABSENT")
                            for e in crosscheck(os.path.join(run_dir, "nope.md"), run_dir)))

        # C8 undeclared-changed-file (git ground truth): a real repo with a dirty out-of-scope file.
        if shutil.which("git"):
            gtmp = tempfile.mkdtemp(prefix="dmc-crosscheck-git-")
            try:
                subprocess.run(["git", "-C", gtmp, "init", "-q"], check=False)
                subprocess.run(["git", "-C", gtmp, "config", "user.email", "s@x.invalid"], check=False)
                subprocess.run(["git", "-C", gtmp, "config", "user.name", "s"], check=False)
                grun = os.path.join(gtmp, ".harness", "runs", "dmc-run-fixture")
                os.makedirs(os.path.join(gtmp, "src"), exist_ok=True)
                os.makedirs(grun, exist_ok=True)
                _fixture_lock(grun)
                with open(os.path.join(grun, "run.json"), "w", encoding="utf-8") as f:
                    f.write(json.dumps({"run_id": "dmc-run-fixture"}) + "\n")
                with open(os.path.join(gtmp, "src", "app.py"), "w", encoding="utf-8") as f:
                    f.write("print('x')\n")
                # An out-of-scope dirty file that the report does NOT declare.
                with open(os.path.join(gtmp, "src", "sneaky.py"), "w", encoding="utf-8") as f:
                    f.write("print('undeclared')\n")
                grep = os.path.join(grun, "report.md")
                with open(grep, "w", encoding="utf-8") as f:
                    f.write(_report(changed="- src/app.py: edited"))
                res = crosscheck(grep, grun)
                t.ok("C8 REFUSE: an undeclared dirty worktree path (git ground truth)",
                     any(e.startswith("CROSSCHECK-UNDECLARED-CHANGED-FILE") for e in res))
            finally:
                shutil.rmtree(gtmp, ignore_errors=True)
        else:
            t.ok("C8 undeclared-changed-file (skipped: git absent)", True)

        # C9 determinism.
        t.ok("C9 determinism", crosscheck(good, run_dir) == crosscheck(good, run_dir))

        # C10 CLI exit codes.
        r_ok = subprocess.run([sys.executable, "-B", os.path.abspath(__file__),
                               "--report", good, "--run", run_dir], capture_output=True, text=True)
        r_no = subprocess.run([sys.executable, "-B", os.path.abspath(__file__), "--report",
                               write_report(_report(run_id="x"), "r10.md"), "--run", run_dir],
                              capture_output=True, text=True)
        t.ok("C10 CLI: ACCEPT=>0, REFUSE=>3", r_ok.returncode == 0 and r_no.returncode == 3)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    after = _real_repo_porcelain()
    t.ok("Z1 real repo git status --porcelain byte-identical before/after (or git absent)",
         before == after)
    t.done()


# ------------------------------------------------------------------------ main

def main():
    ap = argparse.ArgumentParser(prog="dmc-verify-crosscheck")
    ap.add_argument("--report", metavar="FILE")
    ap.add_argument("--run", metavar="DIR", help="the active run directory (.harness/runs/<run-id>)")
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args()

    if a.self_test:
        selftest()
        return

    if not a.report or not a.run:
        die("usage: dmc-verify-crosscheck --report FILE --run DIR | --self-test", 2)
    reasons = crosscheck(a.report, os.path.abspath(a.run))
    if reasons:
        refuse(reasons)
    print("ACCEPT: verification report is structurally valid, run-bound, in-scope, and honest")
    sys.exit(0)


if __name__ == "__main__":
    main()
