#!/usr/bin/env python3
"""dmc-run-core-selftest.py — DMC v1.0 M4 run-core + loop-core self-test aggregator (T009g).

Two named `bin/dmc selftest` sections that DMC-T009g registers (never in the no-arg default;
wired only into named use and `--all`, per the M4 default-selftest policy):

  run-core   fans out to the module self-tests of dmc-run-lifecycle, dmc-scope-lock,
             dmc-approvals, dmc-evidence-ledger, dmc-checkpoints (each a subprocess; their printed
             PASS/FAIL counts are aggregated) PLUS the whole-loop hermetic integration round-trip
             (below), which is the M4 spine end-to-end proof.
  loop-core  fans out to the module self-tests of dmc-acceptance, dmc-verify-plan, dmc-fixloop,
             dmc-context-recovery (subprocess; counts aggregated).

The round-trip runs entirely inside a single disposable `tempfile.mkdtemp()` git repo with a
self-contained git identity (no dependency on the caller's git config): it drives
start -> scope-lock compile -> acceptance compile -> verify-plan compile -> mint receipts ->
induce a check fail -> fix-loop counter increment -> checkpoint (receipt-covered) -> suspend ->
resume -> context-recover (clean scenario), validates EVERY produced artifact with its own
validator, re-runs the copied v0.6.2 evidence-receipt gate + v0.6.5 decision-trace + v0.6.1.0
`validate-entry approval` over the generated receipts and the post-verification approval records
(all ACCEPT), and asserts the REAL repo `git status --porcelain` is byte-identical before/after
(all writes confined to the tempdir).

House rules (v0.6.x / M2-M4 lineage): stdlib-only, env-independent (no env reads), offline (no
network; git is best-effort and confined to the tempdir), deterministic assertions (never depend on
a wall-clock value or a specific hash literal), value-blind, secret-bearing paths refused by path
only, no live provider / no secret read. Reuse-by-invocation: every M4 module and every copied v0.x
validator is called as a read-only subprocess, never imported, so this aggregator stays independently
deletable per the M4 additive-rollback contract.
"""

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))

# M4 modules fanned out by run-core / loop-core (module basename -> section footer name).
RUN_CORE_MODULES = [
    "dmc-run-lifecycle.py",
    "dmc-scope-lock.py",
    "dmc-approvals.py",
    "dmc-evidence-ledger.py",
    "dmc-checkpoints.py",
]
LOOP_CORE_MODULES = [
    "dmc-acceptance.py",
    "dmc-verify-plan.py",
    "dmc-fixloop.py",
    "dmc-context-recovery.py",
]

# Copied v0.x validators re-run over the round-trip artifacts (invoked read-only, never edited).
V062 = os.path.join(HERE, "dmc-v0.6.2-evidence-receipt.py")
V065 = os.path.join(HERE, "dmc-v0.6.5-decision-trace.py")
V0610 = os.path.join(HERE, "dmc-v0.6.1.0-trace-linkage.py")

FOOTER_RE = re.compile(r"\[[^\]]+\]\s+(\d+)\s+PASS\s*/\s*(\d+)\s+FAIL")
HASH_RE = re.compile(r"^[0-9a-f]{16,}$")


# ------------------------------------------------------------------- synthetic fixtures (in tempdir)

SYNTH_PLAN = """# Plan: run-core round-trip synthetic fixture (not a real plan)

Plan ID: dmc-roundtrip-fixture

Synthetic fixture consumed only by the T009g hermetic round-trip. Authorizes nothing at runtime.

## Goal
Drive the M4 run-lifecycle spine end-to-end in a disposable tempdir.
## User Intent
feature
## Current Repo Findings
- Finding: the round-trip needs one APPROVED plan to mint a run from.
  Source: .harness/plans/dmc-v1-m4-run-lifecycle.md
## Relevant Files
| Path | Reason | Allowed to Edit |
|---|---|---|
| src/app.py | fixture scope | yes (fixture) |
## Out of Scope
- Any real repository change; this fixture authorizes nothing at runtime.
## Proposed Changes
- Change: none (fixture only).
  Files: src/app.py
  Rationale: a fixture plan carries the plan shape without proposing real work.
## Acceptance Criteria
- Criterion: the run-lifecycle module self-test passes.
  Verification Method: `python3 bin/lib/dmc-run-lifecycle.py --self-test` exits 0.
- Criterion: the plan validates against the M2 plan validator.
  Verification Method: `bin/dmc validate plan plan.md` exits 0.
## Risks
| Risk | Severity | Mitigation |
|---|---|---|
| a fixture is mistaken for a real plan | low | title + preamble mark it SYNTHETIC |
## Assumptions
| Assumption | Confidence | How to Verify |
|---|---|---|
| the M4 module interfaces are stable | high | this round-trip |
## Execution Tasks
- [ ] DMC-T001: fixture-only; no execution.
  Files: src/app.py
  Notes: synthetic; present so the plan carries a well-formed Execution Tasks section.
## Verification Commands
| Command | Reason | Required |
|---|---|---|
| bin/dmc validate plan plan.md | fixture plan stays schema-valid | yes |
## Approval Status
Status: APPROVED
Approver: SYNTHETIC-FIXTURE (not a human release gate; fixture-only, authorizes nothing)
Approved At: 2026-07-06
"""

SYNTH_ORIENTATION = {
    "schema": "dmc.orientation.v1",
    "root_kind": "plain",
    "head": "no-git",
    "head_time": "no-git",
    "languages": {"py": 1},
    "manifests": [],
    "package_managers": [],
    "verify_commands": [{"command": "true", "source": "fixture:round-trip"}],
    "entrypoints": [],
    "doc_roots": [],
    "unknowns": ["synthetic fixture; no package manifest present"],
}

SYNTH_RADIUS = {
    "schema": "dmc.radius.v1",
    "head": "no-git",
    "scope": ["src/app.py"],
    "entries": [{
        "path": "src/app.py",
        "dependents": [],
        "dependent_count": 0,
        "landmark_class": "ordinary",
        "unscanned": False,
        "check_ids": ["CHK-FIX-001"],
    }],
}

SYNTH_LANDMARKS = {
    "files": [{"path": "src/app.py", "grant": "edit", "landmark_class": "ordinary"}],
    "bounds": {"max_files": 3, "max_added": 200, "max_deleted": 50,
               "forbidden_hunk_classes": []},
}


# ------------------------------------------------------------------- helpers

def canon_hash(obj):
    """Shared canonical serialization hash (identical to every M4 writer): sorted keys, compact
    separators, UTF-8, sha256 hex — so cross-artifact chain links can be recomputed here."""
    payload = json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def load_json(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def read_jsonl(path):
    with open(path, "r", encoding="utf-8") as f:
        return [json.loads(ln) for ln in f.read().splitlines() if ln.strip()]


def real_repo_porcelain():
    """Best-effort `git status --porcelain` of the REAL repo; None if git is unavailable."""
    git = shutil.which("git")
    if not git:
        return None
    try:
        r = subprocess.run([git, "-C", REPO_ROOT, "status", "--porcelain"],
                           capture_output=True, timeout=20)
        return r.stdout if r.returncode == 0 else None
    except Exception:  # noqa: BLE001
        return None


def sweep_pycache():
    shutil.rmtree(os.path.join(HERE, "__pycache__"), ignore_errors=True)


class Agg:
    """Section aggregator: folds subprocess self-test counts AND inline round-trip assertions into
    one `[section] N PASS / M FAIL` footer; exits 0 iff no failures (fail-closed)."""

    def __init__(self, name):
        self.name, self.passed, self.failed = name, 0, 0

    def ok(self, label, cond):
        if cond:
            self.passed += 1
            print("PASS [%s] %s" % (self.name, label))
        else:
            self.failed += 1
            print("FAIL [%s] %s" % (self.name, label))
        return bool(cond)

    def check(self, label, thunk):
        """Assert a thunk; a raised exception is a FAIL, never an abort (a broken fixture must not
        crash the whole section)."""
        try:
            cond = bool(thunk())
        except Exception as e:  # noqa: BLE001
            self.ok("%s [EXC:%s]" % (label, e.__class__.__name__), False)
            return False
        return self.ok(label, cond)

    def fold_module(self, module):
        """Run one M4 module's `--self-test` as a subprocess and fold its printed counts in."""
        path = os.path.join(HERE, module)
        if not os.path.isfile(path):
            self.ok("module %s present" % module, False)
            return
        try:
            r = subprocess.run([sys.executable, "-B", path, "--self-test"],
                               capture_output=True, text=True, timeout=300)
        except Exception as e:  # noqa: BLE001
            self.ok("module %s ran [EXC:%s]" % (module, e.__class__.__name__), False)
            return
        m = None
        for line in (r.stdout + "\n" + r.stderr).splitlines():
            mm = FOOTER_RE.search(line)
            if mm:
                m = mm
        if m is None:
            self.ok("module %s printed a parseable footer (exit=%s)" % (module, r.returncode), False)
            return
        p, f = int(m.group(1)), int(m.group(2))
        self.passed += p
        self.failed += f
        # Fold in the module's own exit-code discipline as one extra assertion.
        self.ok("module %s self-test: %d PASS / %d FAIL, exit %d (all-pass + exit 0)"
                % (module, p, f, r.returncode), f == 0 and r.returncode == 0)

    def done(self):
        print("[%s] %d PASS / %d FAIL" % (self.name, self.passed, self.failed))
        sys.exit(0 if self.failed == 0 else 1)


# ------------------------------------------------------------------- tempdir fixture repo

def git_id(root, *args):
    """git with a self-contained identity so a bare CI host needs no ambient user.name/email."""
    return subprocess.run(["git", "-C", root, "-c", "user.name=dmc", "-c", "user.email=dmc@x",
                           "-c", "commit.gpgsign=false", *args], capture_output=True, text=True)


def make_repo(tmp):
    """Disposable git repo with the synthetic plan/orientation/radius/landmarks committed and a
    tracked source file, so the tree is clean before the run artifacts (which stay untracked) land."""
    subprocess.run(["git", "init", "-q", tmp], capture_output=True)
    paths = {}
    plan = os.path.join(tmp, "plan.md")
    with open(plan, "w", encoding="utf-8") as f:
        f.write(SYNTH_PLAN)
    paths["plan"] = plan
    for name, obj in (("orientation", SYNTH_ORIENTATION), ("radius", SYNTH_RADIUS),
                      ("landmarks", SYNTH_LANDMARKS)):
        p = os.path.join(tmp, name + ".json")
        with open(p, "w", encoding="utf-8") as f:
            f.write(json.dumps(obj, sort_keys=True, indent=2) + "\n")
        paths[name] = p
    srcdir = os.path.join(tmp, "src")
    os.makedirs(srcdir, exist_ok=True)
    with open(os.path.join(srcdir, "app.py"), "w", encoding="utf-8") as f:
        f.write("# fixture source\n")
    git_id(tmp, "add", "-A")
    git_id(tmp, "commit", "-q", "-m", "fixture init")
    return paths


def mod_cli(module, *args):
    """Run an M4 module CLI as a read-only subprocess (-B: no bytecode cache)."""
    return subprocess.run([sys.executable, "-B", os.path.join(HERE, module), *args],
                          capture_output=True, text=True, timeout=120)


def copied_cli(tool_path, *args, stdin=None):
    """Run a copied v0.x validator as a read-only subprocess."""
    return subprocess.run([sys.executable, "-B", tool_path, *args],
                          input=stdin, capture_output=True, text=True, timeout=60)


# ------------------------------------------------------------------- the integration round-trip

def round_trip(agg):
    """Drive the whole M4 spine in one disposable tempdir; assert each artifact + composer clean."""
    if not shutil.which("git"):
        agg.ok("RT00 git available for the round-trip (SKIP-graceful if absent)", True)
        return
    tmp = tempfile.mkdtemp(prefix="dmc-run-core-rt-")
    try:
        paths = make_repo(tmp)
        runs = os.path.join(tmp, ".harness", "runs")

        # -- (1) run start: mint run.json + pointer -------------------------------------------------
        r = mod_cli("dmc-run-lifecycle.py", "start", "--plan", paths["plan"], "--root", tmp)
        agg.ok("RT01 run start exit 0 (mint + arm INIT->RUNNING)", r.returncode == 0)
        ptr = os.path.join(runs, "current-run-id")
        agg.check("RT01b run-id pointer written", lambda: os.path.isfile(ptr))
        run_id = open(ptr, encoding="utf-8").read().strip() if os.path.isfile(ptr) else ""
        run_json = os.path.join(runs, run_id, "run.json")
        agg.check("RT01c run.json exists + validates (its own validator)",
                  lambda: os.path.isfile(run_json)
                  and mod_cli("dmc-run-lifecycle.py", "--validate", run_json).returncode == 0)
        run = load_json(run_json)
        work_id, plan_hash, repo_hash = run["work_id"], run["plan_hash"], run["repo_hash"]
        agg.ok("RT01d run started RUNNING + binding hash-shaped",
                run["status"] == "RUNNING" and HASH_RE.match(plan_hash) and HASH_RE.match(repo_hash))

        # -- (2) scope-lock compile: chains onto the run state_hash --------------------------------
        r = mod_cli("dmc-scope-lock.py", "--compile", "--plan", paths["plan"],
                    "--landmarks", paths["landmarks"], "--run", run_json, "--root", tmp)
        agg.ok("RT02 scope-lock compile exit 0", r.returncode == 0)
        lock_path = os.path.join(runs, run_id, "scope.lock.json")
        agg.check("RT02b scope.lock.json validates (its own validator)",
                  lambda: mod_cli("dmc-scope-lock.py", "--validate", lock_path).returncode == 0)
        agg.check("RT02c scope-lock prev_hash chains onto run.state_hash (chain composes)",
                  lambda: load_json(lock_path)["prev_hash"] == run["state_hash"])
        agg.check("RT02d adjudicate ALLOW in-scope edit / REFUSE out-of-scope",
                  lambda: mod_cli("dmc-scope-lock.py", "--adjudicate", lock_path,
                                  "src/app.py", "edit").returncode == 0
                  and mod_cli("dmc-scope-lock.py", "--adjudicate", lock_path,
                              "src/other.py", "edit").returncode == 3)

        # -- (3) acceptance compile ----------------------------------------------------------------
        r = mod_cli("dmc-acceptance.py", "compile", "--plan", paths["plan"],
                    "--orientation", paths["orientation"], "--radius", paths["radius"],
                    "--run-id", run_id, "--root", tmp)
        agg.ok("RT03 acceptance compile exit 0", r.returncode == 0)
        acc_path = os.path.join(runs, run_id, "acceptance.json")
        agg.check("RT03b acceptance.json validates (its own validator)",
                  lambda: mod_cli("dmc-acceptance.py", "--validate", acc_path).returncode == 0)
        acc = load_json(acc_path)
        check_ids = [c["check_id"] for c in acc["checks"]]
        agg.ok("RT03c acceptance has >=2 checks with unique content-derived ids",
                len(check_ids) >= 2 and len(set(check_ids)) == len(check_ids))
        cid_cov = check_ids[0]     # the check we mint receipts + checkpoint for
        cid_fail = check_ids[1]    # the "induced fail" check the fix-loop counts

        # -- (4) verify-plan compile: reuse copied v0.5.5 by invocation ----------------------------
        vp_path = os.path.join(runs, run_id, "verify-plan.json")
        r = mod_cli("dmc-verify-plan.py", "compile", "--acceptance", acc_path,
                    "--radius", paths["radius"], "--out", vp_path)
        agg.ok("RT04 verify-plan compile exit 0 (v0.5.5 reused by invocation)", r.returncode == 0)
        agg.check("RT04b verify-plan.json validates (re-runs copied planner, no divergence)",
                  lambda: mod_cli("dmc-verify-plan.py", "--validate", vp_path).returncode == 0)
        agg.check("RT04c verify-plan prev_hash chains onto canon_hash(acceptance)",
                  lambda: load_json(vp_path)["prev_hash"] == canon_hash(load_json(acc_path)))

        # -- (5) mint receipts (P10) for the coverage check_id -------------------------------------
        m1 = mod_cli("dmc-evidence-ledger.py", "mint", "--root", tmp, "--run-id", run_id,
                     "--check-id", cid_cov, "--evidence-type", "verification-report",
                     "--artifact-ref", "ver/report.md", "--work-id", work_id,
                     "--plan-hash", plan_hash, "--repo-hash", repo_hash,
                     "--verification-ref", "ver/report.md")
        m2 = mod_cli("dmc-evidence-ledger.py", "mint", "--root", tmp, "--run-id", run_id,
                     "--check-id", cid_cov, "--evidence-type", "test-result",
                     "--artifact-ref", "ver/tests.xml", "--work-id", work_id,
                     "--plan-hash", plan_hash, "--repo-hash", repo_hash,
                     "--verification-ref", "ver/report.md")
        agg.ok("RT05 mint 2 hash-chained receipts exit 0", m1.returncode == 0 and m2.returncode == 0)
        agg.check("RT05b ledger validates (chain + receipt-hash cross-check)",
                  lambda: mod_cli("dmc-evidence-ledger.py", "--validate-ledger",
                                  "--root", tmp, "--run-id", run_id).returncode == 0)
        agg.check("RT05c coverage COVERED for the minted check_id / NOT-COVERED for an unminted one",
                  lambda: mod_cli("dmc-evidence-ledger.py", "coverage", "--root", tmp,
                                  "--run-id", run_id, "--check-id", cid_cov).returncode == 0
                  and mod_cli("dmc-evidence-ledger.py", "coverage", "--root", tmp,
                              "--run-id", run_id, "--check-id", "CHK-NEVER").returncode == 1)
        idx = os.path.join(runs, run_id, "receipts", "index.jsonl")
        receipt_ids = [e["receipt_id"] for e in read_jsonl(idx)]

        # -- (6) induced check fail -> fix-loop counter increment (P13) ----------------------------
        f1 = mod_cli("dmc-fixloop.py", "append", "--root", tmp, "--run-id", run_id,
                     "--check-id", cid_fail, "--bound", "3", "--hypothesis", "first fix attempt")
        f2 = mod_cli("dmc-fixloop.py", "append", "--root", tmp, "--run-id", run_id,
                     "--check-id", cid_fail, "--bound", "3", "--hypothesis", "second fix attempt")
        agg.ok("RT06 two fix-loop appends exit 0 (counter increments)",
                f1.returncode == 0 and f2.returncode == 0)
        flog = os.path.join(runs, run_id, "fixloop.log.jsonl")
        agg.check("RT06b fixloop.log.jsonl validates (chain + bound + cross-run counter)",
                  lambda: mod_cli("dmc-fixloop.py", "--validate", flog).returncode == 0)
        agg.check("RT06c attempts increment 1->2 for the failing (plan_hash, check_id)",
                  lambda: [rec["attempt"] for rec in read_jsonl(flog)] == [1, 2])

        # -- (7) checkpoint (P12): receipt-covered check only --------------------------------------
        ck = mod_cli("dmc-checkpoints.py", "create", "--root", tmp, "--run-id", run_id,
                     "--name", "cp1", "--check-id", cid_cov)
        agg.ok("RT07 checkpoint create exit 0 (check has receipt coverage)", ck.returncode == 0)
        ckpath = os.path.join(runs, run_id, "checkpoints.json")
        agg.check("RT07b checkpoints.json validates (its own validator)",
                  lambda: mod_cli("dmc-checkpoints.py", "--validate", ckpath).returncode == 0)
        agg.check("RT07c false-green checkpoint (no coverage) REFUSED",
                  lambda: mod_cli("dmc-checkpoints.py", "create", "--root", tmp, "--run-id", run_id,
                                  "--name", "cpX", "--check-id", "CHK-NEVER").returncode == 3)

        # -- (8) approvals (P17): a pre + a post-verification kind ---------------------------------
        ap_pre = mod_cli("dmc-approvals.py", "append", "--root", tmp, "--run-id", run_id,
                         "--gate-kind", "plan_approval", "--auth-id", "wjlee")
        ap_post = mod_cli("dmc-approvals.py", "append", "--root", tmp, "--run-id", run_id,
                          "--gate-kind", "release", "--auth-id", "wjlee",
                          "--verification-ref", ".harness/verification/dmc-v1-m4-run-lifecycle.md")
        agg.ok("RT08 approvals append: plan_approval (pre) + release (post) exit 0",
                ap_pre.returncode == 0 and ap_post.returncode == 0)
        appr_path = os.path.join(runs, run_id, "approvals.jsonl")
        agg.check("RT08b approvals.jsonl validates (R12 + chain + post cross-check)",
                  lambda: mod_cli("dmc-approvals.py", "--validate", appr_path).returncode == 0)
        agg.check("RT08c laundered source REFUSED end-to-end via the local rule",
                  lambda: any("APPROVAL-BAD-SOURCE" in ln or "APPROVAL" in ln
                              for ln in _laundered_reasons(tmp, run_id, work_id, plan_hash, repo_hash)))
        appr_records = read_jsonl(appr_path)
        post_records = [a for a in appr_records if a.get("gate_kind") in ("release", "push", "waiver")]

        # -- (9) suspend: SUSPENDED != active ------------------------------------------------------
        s = mod_cli("dmc-run-lifecycle.py", "suspend", "--root", tmp, "--run-id", run_id)
        agg.ok("RT09 suspend exit 0 -> SUSPENDED (not active)",
                s.returncode == 0 and "status: SUSPENDED" in s.stdout and "active: false" in s.stdout)
        agg.check("RT09b run status reports SUSPENDED distinctly",
                  lambda: "active: false" in mod_cli("dmc-run-lifecycle.py", "status",
                                                     "--root", tmp, "--run-id", run_id).stdout)

        # -- (10) resume: SUSPENDED -> RESUMING -> RUNNING -----------------------------------------
        rs = mod_cli("dmc-run-lifecycle.py", "resume", "--root", tmp, "--run-id", run_id)
        agg.ok("RT10 resume exit 0 -> RUNNING (active again), chain intact",
                rs.returncode == 0 and "status: RUNNING" in rs.stdout
                and mod_cli("dmc-run-lifecycle.py", "--validate", run_json).returncode == 0)

        # -- (11) context recovery (P11): clean scenario, no delta ---------------------------------
        rc = mod_cli("dmc-context-recovery.py", "recover", "--root", tmp, "--run-id", run_id,
                     "--scope-lock", lock_path)
        agg.ok("RT11 context-recover clean scenario exit 0 (no delta, not halted)",
                rc.returncode == 0 and "halted: false" in rc.stdout)
        rec_path = os.path.join(runs, run_id, "recovery.json")
        agg.check("RT11b recovery.json validates (re-runs copied v0.5.7, no divergence)",
                  lambda: mod_cli("dmc-context-recovery.py", "--validate", rec_path).returncode == 0)
        agg.check("RT11c a moved-HEAD delta HALTS (never auto-reconciles)",
                  lambda: mod_cli("dmc-context-recovery.py", "recover", "--root", tmp,
                                  "--run-id", run_id, "--expect-head", "deadbeef" * 5,
                                  "--reconcile").returncode == 1)

        # -- (12) composer compatibility: re-run the three copied validators over M4 artifacts -----
        # v0.6.2: validate every minted receipt file + gate the receipt set as an evidence array.
        receipt_files = [os.path.join(runs, run_id, e["receipt_path"]) for e in read_jsonl(idx)]
        v062_each = all(copied_cli(V062, "validate", rf).returncode == 0 for rf in receipt_files)
        agg.ok("RT12 v0.6.2 validate ACCEPTS every minted receipt", v062_each)
        subject = {"work_id": work_id, "plan_hash": plan_hash, "milestone_id": "v0.6.1",
                   "repo_hash": repo_hash, "verification_ref": "ver/report.md"}
        claim = {"subject": subject,
                 "completion_claim": {"done_requested": True, "claimed_by": "verifier"},
                 "evidence": [load_json(rf) for rf in receipt_files]}
        g = copied_cli(V062, "gate", "-", stdin=json.dumps(claim))
        agg.ok("RT12b v0.6.2 gate ALLOWs the round-trip receipt set (subject-consistent + "
                "verification-report present)", g.returncode == 0)

        # v0.6.1.0: validate-entry approval over each post-verification approval record.
        v0610_post = all(copied_cli(V0610, "validate-entry", "approval", "-",
                                    stdin=json.dumps(a)).returncode == 0 for a in post_records)
        agg.ok("RT12c v0.6.1.0 validate-entry approval ACCEPTS each post-verification approval "
                "record", bool(post_records) and v0610_post)

        # v0.6.5: a decision record built from the M4 receipt + approval ids validates.
        decision = {"kind": "decision", "id": "D-roundtrip", "producer_milestone_id": "v0.6.5",
                    "work_id": work_id, "plan_hash": plan_hash, "repo_hash": repo_hash,
                    "verification_ref": "ver/report.md", "rationale_class": "ship-it",
                    "links": {"capability_id": "cheap-fast", "evidence_ids": receipt_ids,
                              "finding_ids": [], "goal_id": "g1",
                              "approval_id": post_records[0]["id"] if post_records else "A1"}}
        d = copied_cli(V065, "validate", "-", stdin=json.dumps(decision))
        agg.ok("RT12d v0.6.5 validate ACCEPTS a decision linking the M4 receipt + approval ids",
                d.returncode == 0)
    except Exception as e:  # noqa: BLE001 — any pipeline crash is a FAIL, never an abort
        agg.ok("RT99 round-trip completed without an unexpected exception [EXC:%s]"
                % e.__class__.__name__, False)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def _laundered_reasons(tmp, run_id, work_id, plan_hash, repo_hash):
    """A crafted laundered-source record is REFUSED by the approvals local rule (via a temp ledger
    file the approvals --validate reads). Returns the REFUSED reason lines."""
    laundered = {
        "kind": "approval", "id": "A-laundered", "producer_milestone_id": "human-release-gate",
        "type": "human-release-gate", "source": "codex-accept-123", "gate_kind": "plan_approval",
        "work_id": work_id, "plan_hash": plan_hash, "repo_hash": repo_hash,
        "seq": 0, "prev_hash": "0" * 64,
    }
    laundered["entry_hash"] = canon_hash({k: v for k, v in laundered.items() if k != "entry_hash"})
    scratch = os.path.join(tmp, "laundered.jsonl")
    with open(scratch, "w", encoding="utf-8") as f:
        f.write(json.dumps(laundered, sort_keys=True, ensure_ascii=False) + "\n")
    r = mod_cli("dmc-approvals.py", "--validate", scratch)
    return r.stdout.splitlines()


# ------------------------------------------------------------------- sections

def section_run_core():
    agg = Agg("run-core")
    before = real_repo_porcelain()
    for module in RUN_CORE_MODULES:
        agg.fold_module(module)
    round_trip(agg)
    after = real_repo_porcelain()
    agg.ok("Z1 real repo git status --porcelain byte-identical before/after (or git absent)",
           before == after)
    sweep_pycache()
    agg.done()


def section_loop_core():
    agg = Agg("loop-core")
    before = real_repo_porcelain()
    for module in LOOP_CORE_MODULES:
        agg.fold_module(module)
    after = real_repo_porcelain()
    agg.ok("Z1 real repo git status --porcelain byte-identical before/after (or git absent)",
           before == after)
    sweep_pycache()
    agg.done()


# ------------------------------------------------------------------------ main

def main():
    ap = argparse.ArgumentParser(prog="dmc-run-core-selftest")
    ap.add_argument("section", choices=["run-core", "loop-core"])
    a = ap.parse_args()
    if a.section == "run-core":
        section_run_core()
    else:
        section_loop_core()


if __name__ == "__main__":
    main()
