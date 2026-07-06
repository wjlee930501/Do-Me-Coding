#!/usr/bin/env python3
"""dmc-run-lifecycle.py — DMC v1.0 M4 run-lifecycle state machine (P-run; architecture §0.3/§0.4).

Turns the plan->execute->verify loop into a persisted, hash-chained, tamper-evident state
machine. `dmc run start` mints a content-derived run-id and writes
`.harness/runs/<run-id>/run.json` (the machine run-state, schema `dmc.run-state.v1`, an in-tool
contract — no schema doc, per the M4 approval) plus a run-id pointer; suspend/resume/status drive
and report the INIT->RUNNING->SUSPENDED->RESUMING->RUNNING->DONE state machine.

Subcommands:
  start --plan FILE [--root DIR] [--work-id ID]   mint + arm a run (refuses unless plan APPROVED;
                                                  refuses a second start while a run is active)
  suspend|resume|status [--root DIR] [--run-id ID] transition / report; SUSPENDED != active
  --validate FILE                                  fail-closed run.json validator (VALID=>0,
                                                   REFUSED=>3)
  --self-test                                      hermetic section self-test (tempdir only)

House rules (v0.6.x / M2-M3 lineage): stdlib-only, deterministic (run-id is content-derived, never
wall-clock; sorted-key canonical hashing), env-independent (no env reads; git is best-effort with a
no-git fallback), offline (no network), fail-closed validators with named reason codes and negative
controls, value-blind refusals (name schema constants/enums, never document content), secret-bearing
paths refused by path only. Advisory tier: the runtime enforcement floor stays the hooks (M6).
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

SCHEMA = "dmc.run-state.v1"
STATES = ["INIT", "RUNNING", "SUSPENDED", "RESUMING", "DONE"]
# A second `start` is refused while a run is in one of these (concurrent-lock); SUSPENDED and DONE
# do not present as active (architecture §0.4; plan acceptance criterion 3).
ACTIVE_STATES = {"INIT", "RUNNING", "RESUMING"}
# Legal state-machine edges. The genesis mint is INIT; `start` arms INIT->RUNNING; DONE is terminal.
TRANSITIONS = {
    "INIT": {"RUNNING"},
    "RUNNING": {"SUSPENDED", "DONE"},
    "SUSPENDED": {"RESUMING"},
    "RESUMING": {"RUNNING"},
    "DONE": set(),
}
GENESIS = "0" * 64          # chain root; hash-shaped, so prev_hash is uniformly hash-shaped
HASH_RE = re.compile(r"^[0-9a-f]{16,}$")
POINTER_NAME = "current-run-id"   # local-only pointer (gitignored via .harness/runs/current-*)
REQUIRED_FIELDS = ["schema", "run_id", "work_id", "plan_path", "plan_hash", "repo_hash",
                   "status", "seq", "created_at", "updated_at", "prev_hash", "state_hash"]

SECRET_ALLOW_BASENAMES = {".env.example", ".env.sample", ".env.template", ".env.dist"}


# ------------------------------------------------------------------- helpers

def die(msg, code=2):
    sys.stderr.write("dmc-run-lifecycle: %s\n" % msg)
    sys.exit(code)


def refuse(reasons):
    for r in reasons:
        print("REFUSED: %s" % r)
    sys.exit(3)


def is_secret_path(path):
    """Path-only secret filter (mirror of DMC.md secret patterns). Never opens the file."""
    base = os.path.basename(path).lower()
    parts = [p.lower() for p in path.replace(os.sep, "/").split("/")]
    if base in SECRET_ALLOW_BASENAMES:
        return False
    if base == ".env" or base.startswith(".env."):
        return True
    if re.search(r"\.(pem|key|p12|pfx|keystore|jks)$", base):
        return True
    if base.startswith(("id_rsa", "id_ed25519")):
        return True
    if base in {".npmrc", ".netrc", ".pgpass", "credentials.json"}:
        return True
    if "service-account" in base and base.endswith(".json"):
        return True
    if "secret" in base and re.search(r"\.(json|ya?ml|env)$", base):
        return True
    if ".ssh" in parts or ".gnupg" in parts:
        return True
    if ".aws" in parts and base == "credentials":
        return True
    return False


def canon_hash(obj):
    """Shared canonical serialization hash: sorted keys, compact separators, UTF-8, sha256 hex."""
    payload = json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def load_json_strict(path):
    """Duplicate-key-rejecting JSON load."""
    def hook(pairs):
        keys = [k for k, _ in pairs]
        if len(keys) != len(set(keys)):
            raise ValueError("duplicate key in JSON object")
        return dict(pairs)
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f, object_pairs_hook=hook)


def iso_now():
    """UTC ISO-8601 stamp. Runtime clock read is allowed; self-tests never depend on the value."""
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def repo_hash(root):
    """Env-free `git status --porcelain | sha256` (established pattern); no-git => sha256(b'')."""
    git = shutil.which("git")
    data = b""
    if git:
        try:
            r = subprocess.run([git, "-C", root, "status", "--porcelain"],
                               capture_output=True, timeout=10)
            if r.returncode == 0:
                data = r.stdout
        except Exception:
            data = b""
    return hashlib.sha256(data).hexdigest()


def plan_hash(path):
    return hashlib.sha256(read_bytes(path)).hexdigest()


def read_bytes(path):
    if is_secret_path(path):
        die("refused: secret-shaped plan path", 3)
    with open(path, "rb") as f:
        return f.read()


def read_text(path):
    return read_bytes(path).decode("utf-8", errors="strict")


def plan_is_approved(text):
    """Fail-closed: the plan's Approval Status section must carry `Status: APPROVED`."""
    m = re.search(r"(?ms)^##\s+Approval Status\s*$(.*?)(?:^##\s+|\Z)", text)
    if not m:
        return False
    return bool(re.search(r"(?m)^\s*Status:\s*APPROVED\b", m.group(1)))


def derive_work_id(text, path):
    m = re.search(r"(?m)^\s*Plan ID:\s*([A-Za-z0-9._-]+)", text)
    if m:
        return m.group(1)
    stem = os.path.splitext(os.path.basename(path))[0]
    return "work-" + re.sub(r"[^A-Za-z0-9._-]", "-", stem)


def mint_run_id(work_id, ph, rh):
    """Content-derived, deterministic run-id (no wall-clock, no randomness)."""
    digest = hashlib.sha256(("%s|%s|%s" % (work_id, ph, rh)).encode("utf-8")).hexdigest()
    return "dmc-run-" + digest[:12]


# ------------------------------------------------------------- state machine

def can_transition(frm, to):
    return to in TRANSITIONS.get(frm, set())


def seal(body):
    """Return a new record with state_hash = canon_hash(body-without-state_hash) (immutable)."""
    core = {k: v for k, v in body.items() if k != "state_hash"}
    return dict(core, state_hash=canon_hash(core))


def genesis_record(run_id, work_id, plan_path, ph, rh, now):
    return seal({
        "schema": SCHEMA,
        "run_id": run_id,
        "work_id": work_id,
        "plan_path": plan_path,
        "plan_hash": ph,
        "repo_hash": rh,
        "status": "INIT",
        "seq": 0,
        "created_at": now,
        "updated_at": now,
        "prev_hash": GENESIS,
    })


def advance(rec, to, now):
    """Chain the next state: prev_hash links to the current record's state_hash (§0.4)."""
    body = {k: v for k, v in rec.items() if k != "state_hash"}
    body["status"] = to
    body["seq"] = rec["seq"] + 1
    body["prev_hash"] = rec["state_hash"]
    body["updated_at"] = now
    return seal(body)


# ------------------------------------------------------------------- storage

def runs_dir(root):
    return os.path.join(root, ".harness", "runs")


def run_json_path(root, run_id):
    return os.path.join(runs_dir(root), run_id, "run.json")


def pointer_path(root):
    return os.path.join(runs_dir(root), POINTER_NAME)


def read_pointer(root):
    p = pointer_path(root)
    if not os.path.isfile(p):
        return None
    with open(p, "r", encoding="utf-8") as f:
        rid = f.read().strip()
    return rid or None


def write_pointer(root, run_id):
    with open(pointer_path(root), "w", encoding="utf-8") as f:
        f.write(run_id + "\n")


def save_run(root, rec):
    d = os.path.join(runs_dir(root), rec["run_id"])
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, "run.json"), "w", encoding="utf-8") as f:
        f.write(json.dumps(rec, sort_keys=True, indent=2, ensure_ascii=False) + "\n")


def load_run(root, run_id):
    p = run_json_path(root, run_id)
    if not os.path.isfile(p):
        return None
    return load_json_strict(p)


# --------------------------------------------------------------------- verbs

def cmd_start(root, plan, work_id_override):
    if not os.path.isfile(plan):
        refuse(["RUN-PLAN-NOT-FOUND: plan file does not exist"])
    text = read_text(plan)
    if not plan_is_approved(text):
        refuse(["RUN-PLAN-NOT-APPROVED: plan Approval Status is not 'Status: APPROVED'"])
    ph = plan_hash(plan)
    rh = repo_hash(root)
    work_id = work_id_override or derive_work_id(text, plan)
    run_id = mint_run_id(work_id, ph, rh)

    os.makedirs(runs_dir(root), exist_ok=True)
    # Concurrent-lock: one active run per repo (architecture §0.4). SUSPENDED/DONE do not block.
    ptr = read_pointer(root)
    if ptr:
        try:
            cur = load_run(root, ptr)
        except Exception:
            refuse(["RUN-CONCURRENT-LOCK: pointer names an unreadable run; resolve it before start"])
        if cur is not None and cur.get("status") in ACTIVE_STATES:
            refuse(["RUN-CONCURRENT-LOCK: an active run already exists "
                    "(status in %s); suspend or complete it first" % "|".join(sorted(ACTIVE_STATES))])
    if load_run(root, run_id) is not None:
        refuse(["RUN-EXISTS: a run with this content-derived id already exists; will not clobber"])

    now = iso_now()
    genesis = genesis_record(run_id, work_id, plan, ph, rh, now)   # INIT (chain root)
    armed = advance(genesis, "RUNNING", now)                       # INIT -> RUNNING
    save_run(root, armed)
    write_pointer(root, run_id)
    print("run_id: %s" % run_id)
    print("status: RUNNING")
    print("active: true")


def _resolve(root, run_id_override):
    rid = run_id_override or read_pointer(root)
    if not rid:
        refuse(["RUN-NO-ACTIVE: no run-id given and no pointer present"])
    rec = load_run(root, rid)
    if rec is None:
        refuse(["RUN-NOT-FOUND: no run.json for the requested run-id"])
    errs = validate_run_state(rec)
    if errs:
        refuse(["RUN-STATE-INVALID: on-disk run.json failed validation: %s" % errs[0]])
    return rid, rec


def cmd_suspend(root, run_id_override):
    rid, rec = _resolve(root, run_id_override)
    if not can_transition(rec["status"], "SUSPENDED"):
        refuse(["RUN-INVALID-TRANSITION: suspend requires status RUNNING (from=%s to=SUSPENDED)"
                % rec["status"]])
    nxt = advance(rec, "SUSPENDED", iso_now())
    save_run(root, nxt)
    print("run_id: %s" % rid)
    print("status: SUSPENDED")
    print("active: false")


def cmd_resume(root, run_id_override):
    rid, rec = _resolve(root, run_id_override)
    if rec["status"] != "SUSPENDED":
        refuse(["RUN-INVALID-TRANSITION: resume requires status SUSPENDED (from=%s)" % rec["status"]])
    now = iso_now()
    resuming = advance(rec, "RESUMING", now)     # SUSPENDED -> RESUMING
    running = advance(resuming, "RUNNING", now)  # RESUMING -> RUNNING
    save_run(root, running)
    print("run_id: %s" % rid)
    print("status: RUNNING")
    print("active: true")


def cmd_status(root, run_id_override):
    rid, rec = _resolve(root, run_id_override)
    active = rec["status"] in ACTIVE_STATES
    print("run_id: %s" % rid)
    print("status: %s" % rec["status"])
    print("active: %s" % ("true" if active else "false"))


# ----------------------------------------------------------------- validator

def validate_run_state(doc):
    """Fail-closed run.json validator. Returns a list of named reason codes ([] == VALID)."""
    if not isinstance(doc, dict):
        return ["RUN-STATE-NOT-OBJECT: run.json root is not a JSON object"]
    errs = []
    for k in REQUIRED_FIELDS:
        if k not in doc:
            errs.append("RUN-STATE-MISSING-FIELD: %s" % k)
    if errs:
        return errs
    if doc["schema"] != SCHEMA:
        errs.append("RUN-STATE-BAD-SCHEMA: schema != %s" % SCHEMA)
    if doc["status"] not in STATES:
        errs.append("RUN-STATE-BAD-STATUS: status not in %s" % "|".join(STATES))
    for hk in ("plan_hash", "repo_hash"):
        if not (isinstance(doc[hk], str) and HASH_RE.match(doc[hk])):
            errs.append("RUN-STATE-BAD-HASH: %s not hash-shaped" % hk)
    if not (isinstance(doc["prev_hash"], str) and HASH_RE.match(doc["prev_hash"])):
        errs.append("RUN-STATE-BAD-PREV-HASH: prev_hash not hash-shaped")
    if isinstance(doc["seq"], bool) or not isinstance(doc["seq"], int) or doc["seq"] < 0:
        errs.append("RUN-STATE-BAD-SEQ: seq must be a non-negative integer")
    else:
        if doc["seq"] == 0 and doc["prev_hash"] != GENESIS:
            errs.append("RUN-STATE-BAD-PREV-HASH: seq 0 (genesis) requires prev_hash == GENESIS")
        if doc["seq"] > 0 and doc["prev_hash"] == GENESIS:
            errs.append("RUN-STATE-BAD-PREV-HASH: seq > 0 must not carry the GENESIS prev_hash")
    if errs:
        return errs
    # Tamper detection: the sealed state_hash must equal the recomputed canonical hash (§0.4).
    core = {k: v for k, v in doc.items() if k != "state_hash"}
    if canon_hash(core) != doc["state_hash"]:
        errs.append("RUN-STATE-TAMPER: state_hash != recomputed canonical hash")
    return errs


# ------------------------------------------------------------------- self-test

SYNTH_APPROVED_PLAN = """# Plan: synthetic run-lifecycle self-test plan

Plan ID: dmc-selftest-run

## Goal
g
## User Intent
feature
## Current Repo Findings
- Finding: f
  Source: s
## Relevant Files
| Path | Reason | Allowed to Edit |
|---|---|---|
| p | r | yes |
## Out of Scope
- x
## Proposed Changes
- Change: c
  Files: p
  Rationale: r
## Acceptance Criteria
- Criterion: c
  Verification Method: m
## Risks
| Risk | Severity | Mitigation |
|---|---|---|
| r | low | m |
## Assumptions
| Assumption | Confidence | How to Verify |
|---|---|---|
| a | high | v |
## Execution Tasks
- [ ] DMC-T001: t
  Files: p
  Notes: n
## Verification Commands
| Command | Reason | Required |
|---|---|---|
| c | r | yes |
## Approval Status
Status: APPROVED
Approver: SYNTHETIC-FIXTURE
Approved At: 2026-07-06
"""

SYNTH_DRAFT_PLAN = SYNTH_APPROVED_PLAN.replace("Status: APPROVED", "Status: DRAFT")


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
    """Best-effort `git status --porcelain` of the real repo; None if git is unavailable."""
    git = shutil.which("git")
    if not git:
        return None
    root = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
    try:
        r = subprocess.run([git, "-C", root, "status", "--porcelain"],
                           capture_output=True, timeout=10)
        return r.stdout if r.returncode == 0 else None
    except Exception:
        return None


def _mkfixture(plan_text):
    """Disposable tempdir 'repo' with an APPROVED plan; best-effort git init (graceful no-git)."""
    tmp = tempfile.mkdtemp(prefix="dmc-run-")
    plan = os.path.join(tmp, "plan.md")
    with open(plan, "w", encoding="utf-8") as f:
        f.write(plan_text)
    git = shutil.which("git")
    if git:
        try:
            subprocess.run([git, "init", "-q", tmp], capture_output=True, timeout=10)
        except Exception:
            pass
    return tmp, plan


def _run_cli(root, *args):
    """Invoke this module as a subprocess for real exit-code assertions."""
    return subprocess.run([sys.executable, os.path.abspath(__file__), *args, "--root", root],
                          capture_output=True, text=True)


def selftest():
    t = ST("run-lifecycle")
    before = _real_repo_porcelain()

    # -- state-machine table (pure) ------------------------------------------------
    t.ok("S1 legal chain INIT->RUNNING->SUSPENDED->RESUMING->RUNNING->DONE",
         can_transition("INIT", "RUNNING") and can_transition("RUNNING", "SUSPENDED")
         and can_transition("SUSPENDED", "RESUMING") and can_transition("RESUMING", "RUNNING")
         and can_transition("RUNNING", "DONE"))
    t.ok("S1b illegal edges refused (INIT->SUSPENDED, RUNNING->RESUMING, DONE->*, SUSPENDED->RUNNING)",
         not can_transition("INIT", "SUSPENDED") and not can_transition("RUNNING", "RESUMING")
         and not can_transition("DONE", "RUNNING") and not can_transition("SUSPENDED", "RUNNING"))
    t.ok("S1c SUSPENDED/DONE are not active; INIT/RUNNING/RESUMING are",
         "SUSPENDED" not in ACTIVE_STATES and "DONE" not in ACTIVE_STATES
         and ACTIVE_STATES == {"INIT", "RUNNING", "RESUMING"})

    # -- run-id minting: content-derived + deterministic ---------------------------
    t.ok("S2 mint_run_id deterministic + content-derived (no wall-clock)",
         mint_run_id("w", "a" * 64, "b" * 64) == mint_run_id("w", "a" * 64, "b" * 64)
         and mint_run_id("w", "a" * 64, "b" * 64) != mint_run_id("w2", "a" * 64, "b" * 64))

    tmp1, plan1 = _mkfixture(SYNTH_APPROVED_PLAN)
    tmp2, plan2 = _mkfixture(SYNTH_APPROVED_PLAN)
    tmp3, plan3 = _mkfixture(SYNTH_DRAFT_PLAN)
    try:
        # -- start round-trip ------------------------------------------------------
        r1 = _run_cli(tmp1, "start", "--plan", plan1)
        rid1 = read_pointer(tmp1)
        rec1 = load_run(tmp1, rid1) if rid1 else None
        t.ok("S3 start exit 0 + writes run.json + pointer",
             r1.returncode == 0 and rid1 is not None and rec1 is not None)
        t.ok("S3b started run.json validates (schema/binding/hash-chain)",
             rec1 is not None and validate_run_state(rec1) == [])
        t.ok("S3c started status is RUNNING (armed INIT->RUNNING) and active",
             rec1 is not None and rec1["status"] == "RUNNING" and rec1["seq"] == 1
             and rec1["prev_hash"] != GENESIS)
        t.ok("S3d run.json carries the binding + timestamps",
             rec1 is not None and HASH_RE.match(rec1["plan_hash"])
             and HASH_RE.match(rec1["repo_hash"]) and rec1["work_id"] == "dmc-selftest-run"
             and rec1["created_at"] and rec1["updated_at"])

        # -- determinism: identical content => identical run-id --------------------
        _run_cli(tmp2, "start", "--plan", plan2)
        t.ok("S4 identical fixture content yields identical content-derived run-id",
             read_pointer(tmp2) == rid1)

        # -- NEGATIVE: second start while active is REFUSED (concurrent-lock) -------
        r_dup = _run_cli(tmp1, "start", "--plan", plan1)
        t.ok("S5 NEG concurrent-lock: second start while active REFUSED exit 3",
             r_dup.returncode == 3 and "RUN-CONCURRENT-LOCK" in r_dup.stdout)

        # -- NEGATIVE: start on a non-APPROVED plan is REFUSED ----------------------
        r_draft = _run_cli(tmp3, "start", "--plan", plan3)
        t.ok("S6 NEG start refuses a non-APPROVED (DRAFT) plan exit 3",
             r_draft.returncode == 3 and "RUN-PLAN-NOT-APPROVED" in r_draft.stdout)

        # -- suspend / status ------------------------------------------------------
        r_sus = _run_cli(tmp1, "suspend")
        rec_sus = load_run(tmp1, rid1)
        t.ok("S7 suspend -> SUSPENDED, reported not-active, chain extended",
             r_sus.returncode == 0 and rec_sus["status"] == "SUSPENDED"
             and rec_sus["seq"] == 2 and rec_sus["prev_hash"] == rec1["state_hash"]
             and validate_run_state(rec_sus) == [])
        r_stat = _run_cli(tmp1, "status")
        t.ok("S7b status reports SUSPENDED distinctly from active",
             r_stat.returncode == 0 and "status: SUSPENDED" in r_stat.stdout
             and "active: false" in r_stat.stdout)

        # -- resume passes through RESUMING back to RUNNING ------------------------
        r_res = _run_cli(tmp1, "resume")
        rec_res = load_run(tmp1, rid1)
        t.ok("S8 resume SUSPENDED->RESUMING->RUNNING, active again, chain intact",
             r_res.returncode == 0 and rec_res["status"] == "RUNNING"
             and rec_res["seq"] == 4 and validate_run_state(rec_res) == [])

        # -- NEGATIVE: resume a non-suspended (RUNNING) run is REFUSED -------------
        r_badres = _run_cli(tmp1, "resume")
        t.ok("S9 NEG invalid transition: resume a RUNNING run REFUSED exit 3",
             r_badres.returncode == 3 and "RUN-INVALID-TRANSITION" in r_badres.stdout)

        # -- validator negative controls (malformed run.json) ----------------------
        valid = rec_res
        no_bind = {k: v for k, v in valid.items() if k != "work_id"}
        t.ok("S10 NEG validator: missing binding field (work_id) REFUSED",
             any(e.startswith("RUN-STATE-MISSING-FIELD") for e in validate_run_state(no_bind)))
        bad_status = dict(valid, status="WOBBLING")
        t.ok("S10b NEG validator: bad status enum REFUSED",
             any(e.startswith("RUN-STATE-BAD-STATUS") for e in validate_run_state(bad_status)))
        broken_prev = dict(valid, prev_hash="not-a-hash")
        t.ok("S10c NEG validator: broken prev_hash REFUSED",
             any(e.startswith("RUN-STATE-BAD-PREV-HASH") for e in validate_run_state(broken_prev)))
        tampered = dict(valid, status="SUSPENDED")   # valid enum, but state_hash now stale
        t.ok("S10d NEG validator: tampered body (stale state_hash) REFUSED",
             any(e.startswith("RUN-STATE-TAMPER") for e in validate_run_state(tampered)))
        t.ok("S10e validator ACCEPTS the sealed valid record", validate_run_state(valid) == [])

        # -- start-after-suspend is permitted (SUSPENDED is not active) ------------
        _run_cli(tmp1, "suspend")   # RUNNING -> SUSPENDED
        r_start2 = _run_cli(tmp1, "start", "--plan", plan1, "--work-id", "second-work")
        t.ok("S11 start permitted while the prior run is SUSPENDED (non-active)",
             r_start2.returncode == 0 and read_pointer(tmp1) != rid1)
    finally:
        for d in (tmp1, tmp2, tmp3):
            shutil.rmtree(d, ignore_errors=True)

    # -- hermeticity: the real repo working tree is byte-unchanged -----------------
    after = _real_repo_porcelain()
    t.ok("S12 real repo git status --porcelain byte-identical before/after (or git absent)",
         before == after)
    t.done()


# ------------------------------------------------------------------------ main

def main():
    ap = argparse.ArgumentParser(prog="dmc-run-lifecycle")
    ap.add_argument("command", nargs="?", choices=["start", "suspend", "resume", "status"])
    ap.add_argument("--plan", metavar="FILE")
    ap.add_argument("--root", default=".")
    ap.add_argument("--run-id", dest="run_id", metavar="ID")
    ap.add_argument("--work-id", dest="work_id", metavar="ID")
    ap.add_argument("--validate", metavar="FILE")
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args()

    if a.self_test:
        selftest()
        return

    if a.validate:
        try:
            doc = load_json_strict(a.validate)
        except FileNotFoundError:
            refuse(["RUN-STATE-UNREADABLE: file not found"])
        except Exception as e:
            refuse(["RUN-STATE-UNREADABLE: %s" % e.__class__.__name__])
        errs = validate_run_state(doc)
        if errs:
            refuse(errs)
        print("VALID: %s conforms to %s" % (a.validate, SCHEMA))
        return

    if not a.command:
        die("usage: dmc-run-lifecycle (start --plan FILE | suspend | resume | status) "
            "[--root DIR] [--run-id ID] | --validate FILE | --self-test", 2)

    root = os.path.abspath(a.root)
    if not os.path.isdir(root):
        die("--root is not a directory: %s" % root, 2)

    if a.command == "start":
        if not a.plan:
            die("start requires --plan FILE", 2)
        cmd_start(root, a.plan, a.work_id)
    elif a.command == "suspend":
        cmd_suspend(root, a.run_id)
    elif a.command == "resume":
        cmd_resume(root, a.run_id)
    elif a.command == "status":
        cmd_status(root, a.run_id)


if __name__ == "__main__":
    main()
