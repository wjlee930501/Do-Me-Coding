#!/usr/bin/env python3
"""dmc-checkpoints.py — DMC v1.0 M4 checkpoints (P12; architecture spine).

Records named git-ref + state-snapshot-hash checkpoints into
`.harness/runs/<run-id>/checkpoints.json`. A checkpoint may reference one or more P10 `check_id`s;
creation is REFUSED unless every referenced `check_id` already has receipt coverage in the evidence
ledger (`dmc-evidence-ledger.py coverage`, invoked read-only as a subprocess — reuse by invocation,
not by import, so this file and the ledger stay independently deletable) — this is the "no
false-green checkpoint" invariant.

Subcommands:
  create --root DIR --run-id ID --name NAME --check-id ID [--check-id ID ...]
  --validate FILE       fail-closed checkpoints.json validator (VALID=>0, REFUSED=>3)
  --self-test           hermetic section self-test (tempdir only)

House rules (matches dmc-run-lifecycle.py / dmc-evidence-ledger.py): stdlib-only, deterministic
where possible, env-independent (no env reads), offline (git is best-effort read-only with a
no-git fallback), fail-closed validators with named reason codes, no receipt/ledger re-implementation
(coverage is always asked of the ledger, never inferred locally).
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
from datetime import datetime, timezone

CKPT_SCHEMA = "dmc.checkpoint.v1"
CKPT_REQUIRED = ["name", "git_ref", "snapshot_hash", "check_ids", "created_at"]
HASH_RE = re.compile(r"^[0-9a-f]{16,}$")
RUN_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")

LEDGER_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "dmc-evidence-ledger.py")


# ------------------------------------------------------------------- helpers

def die(msg, code=2):
    sys.stderr.write("dmc-checkpoints: %s\n" % msg)
    sys.exit(code)


def refuse(reasons):
    for r in reasons:
        print("REFUSED: %s" % r)
    sys.exit(3)


def nestr(x):
    return isinstance(x, str) and x != "" and "\n" not in x


def iso_now():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def strict_obj_hook(pairs):
    keys = [k for k, _ in pairs]
    if len(keys) != len(set(keys)):
        raise ValueError("duplicate key in JSON object")
    return dict(pairs)


def safe_run_id(run_id):
    return bool(run_id) and bool(RUN_ID_RE.match(run_id)) and ".." not in run_id


# ------------------------------------------------------------------- storage

def checkpoints_path(root, run_id):
    return os.path.join(root, ".harness", "runs", run_id, "checkpoints.json")


def load_checkpoints(root, run_id):
    p = checkpoints_path(root, run_id)
    if not os.path.isfile(p):
        return {"schema": CKPT_SCHEMA, "checkpoints": []}
    with open(p, "r", encoding="utf-8") as f:
        return json.load(f, object_pairs_hook=strict_obj_hook)


def save_checkpoints(root, run_id, doc):
    p = checkpoints_path(root, run_id)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w", encoding="utf-8") as f:
        f.write(json.dumps(doc, sort_keys=True, indent=2, ensure_ascii=False) + "\n")


# ------------------------------------------------------------------- git helpers

def get_git_ref(root):
    """Best-effort `git rev-parse HEAD`; env-free, no-git fallback (matches repo_hash() pattern)."""
    git = shutil.which("git")
    if git:
        try:
            r = subprocess.run([git, "-C", root, "rev-parse", "HEAD"], capture_output=True,
                               text=True, timeout=10)
            if r.returncode == 0 and r.stdout.strip():
                return r.stdout.strip()
        except Exception:
            pass
    return "no-git"


def snapshot_hash(root):
    """Env-free `git status --porcelain | sha256`; no-git => sha256(b'')."""
    git = shutil.which("git")
    data = b""
    if git:
        try:
            r = subprocess.run([git, "-C", root, "status", "--porcelain"], capture_output=True, timeout=10)
            if r.returncode == 0:
                data = r.stdout
        except Exception:
            data = b""
    return hashlib.sha256(data).hexdigest()


# ------------------------------------------------------------------- ledger coverage

def query_coverage(root, run_id, check_id):
    """(covered: bool, errs: list). Asks the ledger, never re-derives coverage locally."""
    r = subprocess.run([sys.executable, LEDGER_PATH, "coverage", "--root", root, "--run-id", run_id,
                        "--check-id", check_id], capture_output=True, text=True, timeout=30)
    if r.returncode == 0:
        return True, []
    if r.returncode == 1:
        return False, []
    detail = (r.stdout.strip() or r.stderr.strip() or "coverage query failed rc=%d" % r.returncode)
    return False, [detail]


# ----------------------------------------------------------------- validator

def validate_checkpoints_doc(doc):
    """Fail-closed checkpoints.json validator. Returns a list of named reasons ([] == VALID)."""
    if not isinstance(doc, dict):
        return ["CKPT-NOT-OBJECT: checkpoints.json root is not a JSON object"]
    errs = []
    if doc.get("schema") != CKPT_SCHEMA:
        errs.append("CKPT-BAD-SCHEMA: schema != %s" % CKPT_SCHEMA)
    cps = doc.get("checkpoints")
    if not isinstance(cps, list):
        errs.append("CKPT-BAD-LIST: checkpoints is not an array")
        return errs
    for i, c in enumerate(cps):
        if not isinstance(c, dict):
            errs.append("CKPT-ENTRY-NOT-OBJECT: checkpoints[%d]" % i)
            continue
        missing = [k for k in CKPT_REQUIRED if k not in c]
        if missing:
            errs.append("CKPT-MISSING-FIELD: checkpoints[%d].%s" % (i, missing[0]))
            continue
        if not nestr(c.get("name")):
            errs.append("CKPT-BAD-NAME: checkpoints[%d].name missing/empty" % i)
        if not (isinstance(c.get("git_ref"), str) and c["git_ref"] != ""):
            errs.append("CKPT-BAD-GIT-REF: checkpoints[%d].git_ref missing/empty" % i)
        if not (isinstance(c.get("snapshot_hash"), str) and HASH_RE.match(c["snapshot_hash"])):
            errs.append("CKPT-BAD-SNAPSHOT-HASH: checkpoints[%d].snapshot_hash not hash-shaped" % i)
        cids = c.get("check_ids")
        if not (isinstance(cids, list) and len(cids) > 0 and all(nestr(x) for x in cids)):
            errs.append("CKPT-NO-CHECK-COVERAGE: checkpoints[%d].check_ids must be a non-empty "
                        "list of check ids" % i)
        if not nestr(c.get("created_at")):
            errs.append("CKPT-BAD-CREATED-AT: checkpoints[%d].created_at missing/empty" % i)
    return errs


# --------------------------------------------------------------------- verbs

def cmd_create(root, run_id, name, check_ids):
    if not safe_run_id(run_id):
        refuse(["CKPT-BAD-RUN-ID: run-id is not a safe identifier"])
    reasons = []
    if not nestr(name):
        reasons.append("CKPT-BAD-NAME: --name missing/empty")
    if not check_ids:
        reasons.append("CKPT-NO-CHECKS: at least one --check-id is required")
    if reasons:
        refuse(reasons)

    uncovered = []
    for cid in check_ids:
        covered, errs = query_coverage(root, run_id, cid)
        if errs:
            refuse(["CKPT-LEDGER-REFUSED: coverage query refused for check_id=%s: %s" % (cid, errs[0])])
        if not covered:
            uncovered.append(cid)
    if uncovered:
        refuse(["CKPT-NO-RECEIPT-COVERAGE: no receipt coverage for check_id(s): %s "
                "(false-green checkpoint refused)" % ",".join(uncovered)])

    entry = {
        "name": name,
        "git_ref": get_git_ref(root),
        "snapshot_hash": snapshot_hash(root),
        "check_ids": list(check_ids),
        "created_at": iso_now(),
    }
    doc = load_checkpoints(root, run_id)
    doc.setdefault("schema", CKPT_SCHEMA)
    doc.setdefault("checkpoints", [])
    doc["checkpoints"].append(entry)

    errs = validate_checkpoints_doc(doc)
    if errs:
        refuse(errs)
    save_checkpoints(root, run_id, doc)

    print("name: %s" % entry["name"])
    print("git_ref: %s" % entry["git_ref"])
    print("snapshot_hash: %s" % entry["snapshot_hash"])
    print("check_ids: %s" % ",".join(entry["check_ids"]))


def cmd_validate(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            doc = json.load(f, object_pairs_hook=strict_obj_hook)
    except FileNotFoundError:
        refuse(["CKPT-UNREADABLE: file not found"])
    except ValueError as e:
        refuse(["CKPT-UNREADABLE: %s" % e])
    errs = validate_checkpoints_doc(doc)
    if errs:
        refuse(errs)
    print("VALID: %s conforms to %s" % (path, CKPT_SCHEMA))


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


def _run_cli(root, *args):
    return subprocess.run([sys.executable, os.path.abspath(__file__), *args, "--root", root],
                          capture_output=True, text=True)


def _mint_via_ledger(root, run_id, check_id):
    H = "a" * 64
    return subprocess.run(
        [sys.executable, LEDGER_PATH, "mint", "--root", root, "--run-id", run_id,
         "--check-id", check_id, "--evidence-type", "verification-report",
         "--artifact-ref", "ver/report.md", "--work-id", "W1", "--plan-hash", H,
         "--repo-hash", H, "--verification-ref", "ver/report.md"],
        capture_output=True, text=True)


def selftest():
    t = ST("checkpoints")
    before = _real_repo_porcelain()
    tmp = tempfile.mkdtemp(prefix="dmc-ckpt-")
    run_id = "dmc-run-selftest"
    git = shutil.which("git")
    if git:
        try:
            subprocess.run([git, "init", "-q", tmp], capture_output=True, timeout=10)
        except Exception:
            pass

    try:
        rmint = _mint_via_ledger(tmp, run_id, "C1")
        t.ok("K0 fixture receipt minted via the ledger (setup)", rmint.returncode == 0)

        # -- happy path: checkpoint with receipt-covered check_id --------------------------
        r_ok = _run_cli(tmp, "create", "--run-id", run_id, "--name", "cp1", "--check-id", "C1")
        t.ok("K1 create succeeds when the check_id has receipt coverage", r_ok.returncode == 0
             and "name: cp1" in r_ok.stdout)
        doc = load_checkpoints(tmp, run_id)
        t.ok("K1b checkpoints.json round-trips and validates clean",
             validate_checkpoints_doc(doc) == [] and len(doc["checkpoints"]) == 1
             and doc["checkpoints"][0]["check_ids"] == ["C1"])

        # -- NEGATIVE: false-green — check_id never minted ---------------------------------
        r_fg = _run_cli(tmp, "create", "--run-id", run_id, "--name", "cp-bad", "--check-id", "C-NEVER")
        t.ok("K2 NEG checkpoint without receipt coverage REFUSED exit 3 (false-green blocked)",
             r_fg.returncode == 3 and "CKPT-NO-RECEIPT-COVERAGE" in r_fg.stdout)
        doc_after = load_checkpoints(tmp, run_id)
        t.ok("K2b false-green attempt left checkpoints.json unchanged (still 1 entry)",
             len(doc_after["checkpoints"]) == 1)

        # -- NEGATIVE: no --check-id at all -------------------------------------------------
        r_none = _run_cli(tmp, "create", "--run-id", run_id, "--name", "cp-empty")
        t.ok("K3 NEG create with zero --check-id REFUSED exit 3 (CKPT-NO-CHECKS)",
             r_none.returncode == 3 and "CKPT-NO-CHECKS" in r_none.stdout)

        # -- validator negative controls ----------------------------------------------------
        good = doc["checkpoints"][0]
        t.ok("K4 NEG validator: missing snapshot_hash REFUSED",
             any(e.startswith("CKPT-MISSING-FIELD") for e in validate_checkpoints_doc(
                 {"schema": CKPT_SCHEMA, "checkpoints": [
                     {k: v for k, v in good.items() if k != "snapshot_hash"}]})))
        t.ok("K5 NEG validator: empty check_ids REFUSED",
             any(e.startswith("CKPT-NO-CHECK-COVERAGE") for e in validate_checkpoints_doc(
                 {"schema": CKPT_SCHEMA, "checkpoints": [dict(good, check_ids=[])]})))
        t.ok("K6 NEG validator: bad schema REFUSED",
             any(e.startswith("CKPT-BAD-SCHEMA") for e in validate_checkpoints_doc(
                 {"schema": "wrong", "checkpoints": [good]})))
        t.ok("K7 NEG validator: non-hash snapshot_hash REFUSED",
             any(e.startswith("CKPT-BAD-SNAPSHOT-HASH") for e in validate_checkpoints_doc(
                 {"schema": CKPT_SCHEMA, "checkpoints": [dict(good, snapshot_hash="not-a-hash")]})))
        t.ok("K8 validator ACCEPTS the persisted valid document", validate_checkpoints_doc(doc) == [])

        # -- NEGATIVE: run-id path traversal refused ----------------------------------------
        r_trav = _run_cli(tmp, "create", "--run-id", "../../etc", "--name", "x", "--check-id", "C1")
        t.ok("K9 NEG unsafe --run-id REFUSED exit 3 (CKPT-BAD-RUN-ID)",
             r_trav.returncode == 3 and "CKPT-BAD-RUN-ID" in r_trav.stdout)

        # -- env-independence: module reads no environment variables -----------------------
        # Tokens are split via concatenation so this check does not match its own source line.
        src = open(os.path.abspath(__file__), encoding="utf-8").read()
        env_tokens = ("os" + "." + "environ", "get" + "env" + "(")
        t.ok("K10 module never reads process environment variables (env-free by construction)",
             all(tok not in src for tok in env_tokens))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    after = _real_repo_porcelain()
    t.ok("K11 real repo git status --porcelain byte-identical before/after (or git absent)",
         before == after)
    t.done()


# ------------------------------------------------------------------------ main

def main():
    ap = argparse.ArgumentParser(prog="dmc-checkpoints")
    ap.add_argument("command", nargs="?", choices=["create"])
    ap.add_argument("--root", default=".")
    ap.add_argument("--run-id", dest="run_id")
    ap.add_argument("--name")
    ap.add_argument("--check-id", dest="check_ids", action="append", default=[])
    ap.add_argument("--validate", metavar="FILE")
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args()

    if a.self_test:
        selftest()
        return

    if a.validate:
        cmd_validate(a.validate)
        return

    if not a.command:
        die("usage: dmc-checkpoints create --root DIR --run-id ID --name NAME "
            "--check-id ID [--check-id ID ...] | --validate FILE | --self-test", 2)

    root = os.path.abspath(a.root)
    if not os.path.isdir(root):
        die("--root is not a directory: %s" % root, 2)
    if not a.run_id:
        die("create requires --run-id", 2)

    if a.command == "create":
        cmd_create(root, a.run_id, a.name, a.check_ids)


if __name__ == "__main__":
    main()
