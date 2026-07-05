#!/usr/bin/env python3
"""dmc-legacy-selftest.py — DMC v1.0 M3 legacy-tool aggregator + bin<->original mirror-check.

Covers the 49 pre-v1.0 `.harness/evidence/dmc-v0.*.{sh,py}` tools that DMC-T008b copy-routes
into `bin/lib/`. The `.harness/evidence/` originals stay in place and canonical (copy-only,
never edited); this module runs the *copies* in `bin/lib/`, aggregates their own printed
PASS/FAIL/N/A summaries, and compares the aggregate against the pinned baseline recorded in
`.harness/evidence/dmc-v1-m3-baseline.md` (49 tools / 802 PASS / 3 FAIL / 3 N/A, dated
2026-07-06). It also verifies bin/lib <-> .harness/evidence byte-equality for all 55 copied
files (49 `.sh` + 6 `.py`), and exercises the M3 rollback procedure ("delete bin/ — originals
were never moved or edited") against a disposable temp copy, never the real repo.

Subcommands:
  selftest-all       run all 49 legacy tools' self-tests against the bin/lib copies, aggregate,
                     compare to the pinned baseline (exact match required, not merely "0 FAIL" —
                     the honest baseline itself carries 3 pre-existing upstream FAILs); ALSO
                     runs the rollback-test. Slow (~2-3 min) — `dmc selftest --all` only.
  mirror --check     one-shot bin/lib/dmc-v0.*.{sh,py} <-> .harness/evidence/dmc-v0.*.{sh,py}
                     byte-equality report (55 files; same-name-set + same-bytes)
  mirror --self-test fast default `dmc selftest` section ("legacy-mirror"): the same check PLUS
                     a negative control (tamper a disposable scratch copy, prove it's detected)
  rollback-test      simulate "rm -rf bin/" in a disposable temp copy; prove the real
                     .harness/evidence originals are untouched and still reproduce the pinned
                     legacy aggregate on their own (i.e. bin/ is deletable without any functional
                     loss, because it was a copy, never a move)

House rules: offline (no network, no live provider call), reads only files under this repo,
never edits `.harness/evidence/dmc-v0.*` (copy source), never writes outside `bin/lib/` and a
disposable `tempfile.mkdtemp()` directory it always cleans up. No shell=True anywhere.
"""

import argparse
import hashlib
import os
import re
import shutil
import subprocess
import sys
import tempfile

TIMEOUT_SEC = 90

# Tools invoked with no flag: the whole script body is the self-test
# (usage comment: "run: bash <script>"; no case-statement dispatch at all).
NOFLAG_TOOLS = [
    "dmc-v0.1.3-verify.sh",
    "dmc-v0.2-verify.sh",
    "dmc-v0.2.1-verify.sh",
    "dmc-v0.2.1.1-verify.sh",
    "dmc-v0.2.2-verify.sh",
    "dmc-v0.2.3-verify.sh",
    "dmc-v0.2.4-verify.sh",
    "dmc-v0.2.5-verify.sh",
    "dmc-v0.2.9-effort-provider-policy.sh",
    "dmc-v0.3.1-verify.sh",
    "dmc-v0.3.2-verify.sh",
    "dmc-v0.3.3-verify.sh",
]

# Tools invoked with `--self-test` as a real case-statement arm.
SELFTEST_TOOLS = [
    "dmc-v0.2.6-gate-check-runner.sh",
    "dmc-v0.2.7-run-manifest.sh",
    "dmc-v0.2.8-task-intake-classifier.sh",
    "dmc-v0.3.0-e2e-completion.sh",
    "dmc-v0.3.4-provider-selector.sh",
    "dmc-v0.3.5-execution-manifest.sh",
    "dmc-v0.3.6-review-packet.sh",
    "dmc-v0.3.7-closure-controller.sh",
    "dmc-v0.3.8-delegation-harness.sh",
    "dmc-v0.3.9-e2e-dry-run.sh",
    "dmc-v0.4.0-autonomy-charter.sh",
    "dmc-v0.4.1-goal-plan-compiler.sh",
    "dmc-v0.4.2-branch-isolation-guard.sh",
    "dmc-v0.4.3-scope-overeager-guard.sh",
    "dmc-v0.4.4-evidence-harness.sh",
    "dmc-v0.4.5-secret-network-live-guard.sh",
    "dmc-v0.4.6-reviewer-loop.sh",
    "dmc-v0.4.7-context-audit.sh",
    "dmc-v0.4.8-interop-doc-check.sh",
    "dmc-v0.4.9-autonomous-dry-run.sh",
    "dmc-v0.5.0-run-metrics.sh",
    "dmc-v0.5.1-context-budgeter.sh",
    "dmc-v0.5.2-effort-controller.sh",
    "dmc-v0.5.3-dynamic-workflow-selector.sh",
    "dmc-v0.5.4-workflow-state-machine.sh",
    "dmc-v0.5.5-verification-planner.sh",
    "dmc-v0.5.6-review-packet-v2.sh",
    "dmc-v0.5.7-resume-recovery.sh",
    "dmc-v0.5.8-dynamic-delegation.sh",
    "dmc-v0.5.9-dynamic-workflow-acceptance.sh",
    "dmc-v0.6.0-verify.sh",
    "dmc-v0.6.1-capability-router.sh",
    "dmc-v0.6.1.0-trace-linkage.sh",
    "dmc-v0.6.2-evidence-receipt.sh",
    "dmc-v0.6.3-findings-gate.sh",
    "dmc-v0.6.4-goal-ledger.sh",
    "dmc-v0.6.5-decision-trace.sh",
]

# .py cores, sibling-composed by their owning .sh wrapper (never invoked directly).
PY_CORES = [
    "dmc-v0.6.1-capability-router.py",
    "dmc-v0.6.1.0-trace-linkage.py",
    "dmc-v0.6.2-evidence-receipt.py",
    "dmc-v0.6.3-findings-gate.py",
    "dmc-v0.6.4-goal-ledger.py",
    "dmc-v0.6.5-decision-trace.py",
]

ALL_SH_TOOLS = NOFLAG_TOOLS + SELFTEST_TOOLS
ALL_LEGACY_FILES = ALL_SH_TOOLS + PY_CORES  # the 55-file copy set

# Pinned baseline: .harness/evidence/dmc-v1-m3-baseline.md, run_id dmc-v1-m3-20260706,
# 2026-07-06, HEAD cf3072088b860e1bd1d59cf0d2dbc4813009a278. Frozen at DMC-T008a; this is NOT
# re-derived at runtime from prose — a change here must be a deliberate re-pin, not a silent
# drift accommodation.
PINNED_BASELINE = {"tools": 49, "pass": 802, "fail": 3, "na": 3}
BASELINE_FILE = os.path.join(".harness", "evidence", "dmc-v1-m3-baseline.md")

SUMMARY_PATTERNS = [
    re.compile(r"SUMMARY:\s*PASS=(\d+)\s*FAIL=(\d+)(?:\s*N/A=(\d+))?"),
    re.compile(r"self-test:\s*PASS=(\d+)\s*FAIL=(\d+)"),
    re.compile(r"self-test:\s*(\d+)\s*PASS\s*/\s*(\d+)\s*FAIL"),
    re.compile(r"RESULT:\s*(\d+)\s*PASS\s*/\s*(\d+)\s*FAIL"),
]


def repo_root():
    return os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                         "..", ".."))


def sha256_file(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def parse_summary(output):
    """Best-effort extraction of (pass, fail, na) from a tool's own printed summary line."""
    for pat in SUMMARY_PATTERNS:
        m = pat.search(output)
        if m:
            groups = m.groups()
            p, f = int(groups[0]), int(groups[1])
            na = int(groups[2]) if len(groups) > 2 and groups[2] else 0
            return p, f, na
    return None, None, None


def run_tool(base_dir, tool):
    """Run one legacy tool from `base_dir` (bin/lib or .harness/evidence), cwd=repo_root()."""
    path = os.path.join(base_dir, tool)
    args = ["bash", path] if tool in NOFLAG_TOOLS else ["bash", path, "--self-test"]
    try:
        proc = subprocess.run(args, cwd=repo_root(), capture_output=True, text=True,
                               timeout=TIMEOUT_SEC)
        output = proc.stdout + "\n" + proc.stderr
        p, f, na = parse_summary(output)
        return {"tool": tool, "pass": p, "fail": f, "na": na, "exit": proc.returncode,
                "timeout": False, "output": output}
    except subprocess.TimeoutExpired:
        return {"tool": tool, "pass": None, "fail": None, "na": None, "exit": None,
                "timeout": True, "output": ""}


def run_all_legacy(base_dir):
    results = [run_tool(base_dir, t) for t in ALL_SH_TOOLS]
    agg = {"tools": len(results),
           "pass": sum(r["pass"] or 0 for r in results),
           "fail": sum(r["fail"] or 0 for r in results),
           "na": sum(r["na"] or 0 for r in results),
           "timeouts": sum(1 for r in results if r["timeout"]),
           "unparsed": sum(1 for r in results if not r["timeout"] and r["pass"] is None)}
    return results, agg


# --------------------------------------------------------------------- mirror-check

def mirror_check(evidence_dir=None, copies_dir=None):
    """(ok, report_lines) — byte-equality of the 55-file copy set, both directions."""
    root = repo_root()
    evidence_dir = evidence_dir or os.path.join(root, ".harness", "evidence")
    copies_dir = copies_dir or os.path.join(root, "bin", "lib")
    lines = []
    ok = True

    for fname in ALL_LEGACY_FILES:
        src = os.path.join(evidence_dir, fname)
        dst = os.path.join(copies_dir, fname)
        if not os.path.exists(src):
            lines.append("FAIL missing original: %s" % fname)
            ok = False
            continue
        if not os.path.exists(dst):
            lines.append("FAIL missing copy: %s" % fname)
            ok = False
            continue
        if sha256_file(src) != sha256_file(dst):
            lines.append("FAIL byte-mismatch: %s" % fname)
            ok = False
        else:
            lines.append("PASS byte-identical: %s" % fname)

    # No stray dmc-v0.* copies beyond the pinned 55-file set.
    extra = sorted(
        f for f in os.listdir(copies_dir)
        if f.startswith("dmc-v0.") and (f.endswith(".sh") or f.endswith(".py"))
        and f not in ALL_LEGACY_FILES
    )
    if extra:
        ok = False
        lines.append("FAIL unexpected extra copies in bin/lib: %s" % ", ".join(extra))
    else:
        lines.append("PASS no stray dmc-v0.* copies beyond the pinned 55-file set")

    return ok, lines


class ST:
    """Section self-test bookkeeping (same shape as dmc-instance-validate.py's ST)."""

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


def _scratch_mirror_pair(real_evidence_dir):
    """A disposable (evidence_copy, lib_copy) pair pre-populated with all 55 files, for a
    negative-control test that tampers one file without ever touching the real repo."""
    tmp = tempfile.mkdtemp(prefix="dmc-mirror-negctl-")
    ev_tmp = os.path.join(tmp, "evidence")
    lib_tmp = os.path.join(tmp, "lib")
    os.makedirs(ev_tmp)
    os.makedirs(lib_tmp)
    for fname in ALL_LEGACY_FILES:
        src = os.path.join(real_evidence_dir, fname)
        shutil.copy(src, os.path.join(ev_tmp, fname))
        shutil.copy(src, os.path.join(lib_tmp, fname))
    return tmp, ev_tmp, lib_tmp


def selftest_mirror():
    """Fast default `dmc selftest` section: real mirror-check + a negative control proving the
    check can actually detect drift (not merely a check that always reports green)."""
    t = ST("legacy-mirror")
    root = repo_root()
    real_evidence_dir = os.path.join(root, ".harness", "evidence")

    real_ok, _lines = mirror_check()
    t.ok("M1 all %d bin/lib copies byte-identical to their .harness/evidence originals, "
         "both directions, no stray dmc-v0.* files" % len(ALL_LEGACY_FILES), real_ok)

    tmp, ev_tmp, lib_tmp = _scratch_mirror_pair(real_evidence_dir)
    try:
        clean_ok, _ = mirror_check(evidence_dir=ev_tmp, copies_dir=lib_tmp)
        t.ok("M2 a freshly duplicated, untampered scratch pair reports clean", clean_ok)

        sample = ALL_LEGACY_FILES[0]
        pre_tamper_hash = sha256_file(os.path.join(real_evidence_dir, sample))
        with open(os.path.join(lib_tmp, sample), "ab") as f:
            f.write(b"\n# tampered for negative control; lives only in a disposable tempdir\n")
        tampered_ok, tampered_lines = mirror_check(evidence_dir=ev_tmp, copies_dir=lib_tmp)
        sample_flagged = any(("byte-mismatch: %s" % sample) in line for line in tampered_lines)
        t.ok("M3 negative control: a single tampered byte in one scratch bin/lib copy is "
             "REFUSED overall and the specific file is named (proves mirror-check can fail, "
             "not just always pass)", (not tampered_ok) and sample_flagged)

        t.ok("M4 negative control never touched the real .harness/evidence original",
             pre_tamper_hash == sha256_file(os.path.join(real_evidence_dir, sample)))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    t.done()


# --------------------------------------------------------------------- rollback-test

def rollback_test():
    """Simulate 'rm -rf bin/' in a disposable temp copy; prove originals are unaffected.

    Never touches the real bin/ or .harness/evidence — copies bin/ into a tempdir, deletes the
    legacy tool copies there, then re-hashes the REAL .harness/evidence originals against their
    pre-test hashes (must be identical) and re-runs the originals' own self-tests (must still
    reproduce the pinned aggregate) to prove the rollback ("delete bin/") loses no functionality.
    """
    root = repo_root()
    evidence_dir = os.path.join(root, ".harness", "evidence")
    bin_dir = os.path.join(root, "bin")
    lines = []
    ok = True

    pre_hashes = {f: sha256_file(os.path.join(evidence_dir, f)) for f in ALL_LEGACY_FILES}

    tmp = tempfile.mkdtemp(prefix="dmc-rollback-test-")
    try:
        tmp_bin = os.path.join(tmp, "bin")
        shutil.copytree(bin_dir, tmp_bin)
        removed = 0
        for f in ALL_LEGACY_FILES:
            p = os.path.join(tmp_bin, "lib", f)
            if os.path.exists(p):
                os.remove(p)
                removed += 1
        lines.append("simulated rollback: removed %d/%d legacy copies from disposable "
                      "temp bin/ (%s)" % (removed, len(ALL_LEGACY_FILES), tmp_bin))

        post_hashes = {f: sha256_file(os.path.join(evidence_dir, f)) for f in ALL_LEGACY_FILES}
        if pre_hashes != post_hashes:
            ok = False
            lines.append("FAIL real .harness/evidence originals changed during rollback sim")
        else:
            lines.append("PASS real .harness/evidence originals byte-unchanged during "
                          "rollback sim (%d files re-hashed)" % len(pre_hashes))

        _results, agg = run_all_legacy(evidence_dir)
        matches = (agg["tools"] == PINNED_BASELINE["tools"]
                   and agg["pass"] == PINNED_BASELINE["pass"]
                   and agg["fail"] == PINNED_BASELINE["fail"]
                   and agg["na"] == PINNED_BASELINE["na"])
        if matches:
            lines.append("PASS originals alone (bin/ absent from the equation) still "
                          "reproduce the pinned baseline: tools=%d PASS=%d FAIL=%d N/A=%d"
                          % (agg["tools"], agg["pass"], agg["fail"], agg["na"]))
        else:
            ok = False
            lines.append("FAIL originals alone do not reproduce the pinned baseline: "
                          "got tools=%d PASS=%d FAIL=%d N/A=%d vs pinned %s"
                          % (agg["tools"], agg["pass"], agg["fail"], agg["na"],
                             PINNED_BASELINE))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    return ok, lines


# --------------------------------------------------------------------- selftest-all

def selftest_all():
    root = repo_root()
    copies_dir = os.path.join(root, "bin", "lib")
    overall_ok = True

    print("== dmc selftest --all : legacy tool aggregate (bin/lib copies) ==")
    results, agg = run_all_legacy(copies_dir)
    for r in results:
        if r["timeout"]:
            print("  TIMEOUT %s (>%ds)" % (r["tool"], TIMEOUT_SEC))
        elif r["pass"] is None:
            print("  UNPARSED %s (exit=%s)" % (r["tool"], r["exit"]))
        else:
            print("  %-45s PASS=%-3d FAIL=%-3d N/A=%-3d exit=%s"
                  % (r["tool"], r["pass"], r["fail"], r["na"], r["exit"]))
    print("  -- aggregate: tools=%d PASS=%d FAIL=%d N/A=%d timeouts=%d unparsed=%d --"
          % (agg["tools"], agg["pass"], agg["fail"], agg["na"], agg["timeouts"],
             agg["unparsed"]))

    baseline_match = (agg["tools"] == PINNED_BASELINE["tools"]
                       and agg["pass"] == PINNED_BASELINE["pass"]
                       and agg["fail"] == PINNED_BASELINE["fail"]
                       and agg["na"] == PINNED_BASELINE["na"]
                       and agg["timeouts"] == 0 and agg["unparsed"] == 0)
    if baseline_match:
        print("  PASS aggregate == pinned baseline exactly (%s, see %s)"
              % (PINNED_BASELINE, BASELINE_FILE))
    else:
        overall_ok = False
        print("  FAIL aggregate DRIFTED from pinned baseline %s (see %s)"
              % (PINNED_BASELINE, BASELINE_FILE))

    # Mirror-check itself is NOT re-run here: it's a fast default `dmc selftest` section
    # (`legacy-mirror`, with its own negative control) that `selftest --all` already runs
    # ahead of this heavier aggregate, per plan §M3 point 6 ("default selftest must remain
    # fast ... the heavy 49-tool run lives only under --all").

    print("== rollback-test : simulate 'rm -rf bin/' in a disposable temp copy ==")
    rok, rlines = rollback_test()
    for line in rlines:
        print("  " + line)
    print("  RESULT: %s" % ("PASS rollback procedure verified safe"
                             if rok else "FAIL rollback procedure verification failed"))
    overall_ok = overall_ok and rok

    print("==== SELFTEST-ALL RESULT: %s ====" % ("PASS" if overall_ok else "FAIL"))
    return overall_ok


# ------------------------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser(prog="dmc-legacy-selftest")
    ap.add_argument("command", choices=["selftest-all", "mirror", "rollback-test"])
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args()

    if a.command == "selftest-all":
        ok = selftest_all()
        sys.exit(0 if ok else 1)

    if a.command == "mirror":
        if a.self_test:
            selftest_mirror()
            return
        # default / --check: one-shot report (used by `dmc mirror-check`)
        ok, lines = mirror_check()
        for line in lines:
            print(line)
        print("RESULT: %s" % ("PASS mirror-check green" if ok else "FAIL mirror-check red"))
        sys.exit(0 if ok else 1)

    if a.command == "rollback-test":
        ok, lines = rollback_test()
        for line in lines:
            print(line)
        print("RESULT: %s" % ("PASS rollback verified safe" if ok else "FAIL rollback check"))
        sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
