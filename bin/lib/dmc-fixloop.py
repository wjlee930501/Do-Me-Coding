#!/usr/bin/env python3
"""dmc-fixloop.py — DMC v1.0 M4 bounded fix-loop counters (P13; architecture §P13).

Appends `.harness/runs/<run-id>/fixloop.log.jsonl` per `fixloop.schema.md`, one JSON object per
line (append-only, hash-chained, tamper-evident). Each entry maps a failing acceptance `check_id`
to a fix attempt and enforces the bounded loop: `attempt > bound` forces `verdict: STOP` (hand off
to P12 restore + P17 structured failure report).

Counter binding (the anti-gaming invariant). Attempt counters are keyed on `(plan_hash, check_id)`,
NOT run-id, so a fresh run cannot launder a counter back to zero. There is deliberately NO separate
mutable counter index: the counter's single source of truth is the union of every
`runs/*/fixloop.log.jsonl` that shares the `plan_hash`, aggregated at append/validate time. Because
`append` scans ALL sibling run dirs (not just the current one) and mints the next attempt as
`high-water-mark + 1`, the counter is plan_hash-scoped and outlives any single run dir; a fresh run
that tries to re-use an already-recorded attempt number for the same `(plan_hash, check_id)`
collides in the cross-run aggregate and is REFUSED (reset gaming). One durable append-only log set,
no index to desync or launder.

`hypothesis` is advisory free-form metadata (P13: "hypothesis quality is advisory"): the producer
redacts secret-shaped content at append (value-blind), the validator treats it value-blind and
never trusts it as evidence. Non-advisory fields are secret-scanned and REFUSED if secret-shaped.

Subcommands / flags:
  append --run-id ID --check-id CID --bound N [--hypothesis H] [--files-touched a,b] [--root DIR]
                                   mint the next attempt (attempt = cross-run high-water + 1),
                                   auto-set verdict (STOP iff attempt > bound), append hash-chained
  --validate FILE                  fail-closed log validator (VALID => 0, REFUSED => 3): per-record
                                   schema + bound->STOP + files_touched + within-file monotonic +
                                   append-only hash-chain + (if under .harness/runs) cross-run
                                   counter aggregate (no duplicate/gap per (plan_hash, check_id))
  --self-test                      hermetic section self-test (tempdir only)

House rules (v0.6.x / M2-M4 lineage): stdlib-only, deterministic (attempt minted from durable
history, never wall-clock; sorted-key canonical hashing), env-independent (no env reads), offline
(no network), fail-closed with named reason codes and negative controls, value-blind refusals
(name schema constants/enums, never document content), secret-bearing paths refused by path only.
Advisory tier: the runtime enforcement floor stays the hooks (M6).
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

SCHEMA = "dmc.fixloop.v1"
VERDICTS = {"CONTINUE", "STOP"}
GENESIS = "0" * 64                    # hash-chain root; hash-shaped, so prev_hash is uniform
HASH_RE = re.compile(r"^[0-9a-f]{16,}$")
POINTER_NAME = "current-run-id"       # local-only pointer minted by T009a (gitignored)
LOG_NAME = "fixloop.log.jsonl"

SECRET_ALLOW_BASENAMES = {".env.example", ".env.sample", ".env.template", ".env.dist"}

# Value-blind reject-on-match set (verbatim from dmc-approvals.py / the copied v0.6.1.0 validator so
# a secret-shaped field is refused, and a secret-shaped hypothesis is redacted, with identical
# semantics to the rest of the M4 tools).
UNSAFE = re.compile(
    r'sk-[A-Za-z0-9_-]{16,}|AKIA[0-9A-Z]{8,}|(?:BEGIN|END)[A-Z ]*PRIVATE KEY|xox[baprs]-[A-Za-z0-9-]{6,}'
    r'|gh[opsu]_[A-Za-z0-9]{16,}|github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{16,}|npm_[A-Za-z0-9]{30,}'
    r'|AIza[0-9A-Za-z_-]{20,}|dop_v1_[A-Za-z0-9]{32,}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'
    r'|ya29\.[A-Za-z0-9_-]{10,}|AccountKey=[A-Za-z0-9+/=]{20,}|Bearer\s+[A-Za-z0-9._-]{12,}'
    r'|(?:password|api_key|client_secret|aws_secret_access_key)\s*=\s*\S+|[A-Za-z0-9_-]*_token\s*[=:]\s*\S+'
)
REDACTION = "[REDACTED-SECRET]"


# ------------------------------------------------------------------- helpers

def die(msg, code=2):
    sys.stderr.write("dmc-fixloop: %s\n" % msg)
    sys.exit(code)


def refuse(reasons):
    for r in reasons:
        print("REFUSED: %s" % r)
    sys.exit(3)


def nestr(x):
    return isinstance(x, str) and x != "" and "\n" not in x


def redact(text):
    """Value-blind redaction of secret-shaped substrings in advisory free-form text."""
    if not isinstance(text, str):
        return text
    return UNSAFE.sub(REDACTION, text)


def scan(o):
    """Recursive value-blind secret scan (reject-on-match)."""
    if isinstance(o, dict):
        for k, v in o.items():
            if isinstance(k, str) and UNSAFE.search(k):
                return True
            if scan(v):
                return True
    elif isinstance(o, list):
        for x in o:
            if scan(x):
                return True
    elif isinstance(o, str):
        if UNSAFE.search(o):
            return True
    return False


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
    """Shared canonical serialization hash: sorted keys, compact separators, UTF-8, sha256 hex.
    Identical to the run-lifecycle canonicalizer so every M4 artifact chains under one rule."""
    payload = json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def _no_dup(pairs):
    keys = [k for k, _ in pairs]
    if len(keys) != len(set(keys)):
        raise ValueError("duplicate key in JSON object")
    return dict(pairs)


def loads_strict(text):
    return json.loads(text, object_pairs_hook=_no_dup)


def load_json_file(path):
    with open(path, "r", encoding="utf-8") as f:
        return loads_strict(f.read())


def seal(rec):
    """Return a new record with entry_hash = canon_hash(record - entry_hash) (append-only chain)."""
    core = {k: v for k, v in rec.items() if k != "entry_hash"}
    return dict(core, entry_hash=canon_hash(core))


# ------------------------------------------------------------------- storage layout

def runs_dir(root):
    return os.path.join(root, ".harness", "runs")


def run_json_path(root, run_id):
    return os.path.join(runs_dir(root), run_id, "run.json")


def log_path(root, run_id):
    return os.path.join(runs_dir(root), run_id, LOG_NAME)


def pointer_path(root):
    return os.path.join(runs_dir(root), POINTER_NAME)


def read_pointer(root):
    p = pointer_path(root)
    if not os.path.isfile(p):
        return None
    with open(p, "r", encoding="utf-8") as f:
        rid = f.read().strip()
    return rid or None


def read_lines(path):
    with open(path, "r", encoding="utf-8") as f:
        return [ln for ln in f.read().splitlines() if ln.strip()]


def append_line(path, line):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "a", encoding="utf-8") as f:
        f.write(line + "\n")


def iter_run_logs(root):
    """Yield (run_id, log_path) for every readable fixloop log under .harness/runs/*/."""
    base = runs_dir(root)
    if not os.path.isdir(base):
        return
    for rid in sorted(os.listdir(base)):
        lp = os.path.join(base, rid, LOG_NAME)
        if os.path.isfile(lp) and not is_secret_path(lp):
            yield rid, lp


# ------------------------------------------------------------------- per-record + chain validation

def rel_ok(p):
    """A files_touched entry must be a non-empty relative path with no '..' component."""
    if not nestr(p):
        return False
    if os.path.isabs(p) or p.startswith("/") or (len(p) > 1 and p[1] == ":"):
        return False
    parts = p.replace("\\", "/").split("/")
    return ".." not in parts


def record_reasons(rec):
    """Per-record schema + bounded-loop + files + secret checks (no chain context). [] == VALID."""
    if not isinstance(rec, dict):
        return ["FIX-NOT-OBJECT: record is not a JSON object"]
    reasons = []
    if scan(rec):
        reasons.append("FIX-SECRET-SHAPED: secret-shaped value present (value-blind, hypothesis "
                       "must be redacted at source)")
    if rec.get("schema") != SCHEMA:
        reasons.append("FIX-BAD-SCHEMA: schema != %s" % SCHEMA)
    ph = rec.get("plan_hash")
    if not (isinstance(ph, str) and HASH_RE.match(ph)):
        reasons.append("FIX-BAD-PLAN-HASH: plan_hash missing/not hash-shaped")
    if not nestr(rec.get("check_id")):
        reasons.append("FIX-BAD-CHECK-ID: check_id missing/empty")
    attempt = rec.get("attempt")
    if isinstance(attempt, bool) or not isinstance(attempt, int) or attempt < 1:
        reasons.append("FIX-BAD-ATTEMPT: attempt must be an integer >= 1")
        attempt = None
    bound = rec.get("bound")
    if isinstance(bound, bool) or not isinstance(bound, int) or bound < 1:
        reasons.append("FIX-BAD-BOUND: bound must be an integer >= 1")
        bound = None
    verdict = rec.get("verdict")
    if verdict not in VERDICTS:
        reasons.append("FIX-BAD-VERDICT: verdict not in %s" % "|".join(sorted(VERDICTS)))
    # bounded loop: attempt > bound => verdict MUST be STOP (schema rule, fail-closed)
    if attempt is not None and bound is not None and attempt > bound and verdict != "STOP":
        reasons.append("FIX-BOUND-NOT-STOP: attempt %d > bound %d requires verdict STOP" %
                       (attempt, bound))
    ft = rec.get("files_touched")
    if not isinstance(ft, list) or any(not rel_ok(p) for p in ft):
        reasons.append("FIX-BAD-FILES-TOUCHED: files_touched must be relative paths with no '..'")
    return reasons


def validate_log(lines):
    """Fail-closed whole-log validator: per-record + append-only hash-chain + within-file
    monotonic attempt per (plan_hash, check_id). Returns named reason codes ([] == VALID)."""
    reasons = []
    prev = GENESIS
    last_attempt = {}
    for i, raw in enumerate(lines):
        try:
            rec = loads_strict(raw)
        except ValueError as e:
            reasons.append("FIX-LINE-%d-BAD-JSON: %s" % (i, e))
            prev = None
            continue
        for r in record_reasons(rec):
            reasons.append("FIX-LINE-%d %s" % (i, r))
        # append-only chain: seq is the line index; prev_hash links to the prior entry_hash;
        # entry_hash must recompute (rewrite => TAMPER; drop/reorder => BAD-SEQ + CHAIN-BREAK).
        if rec.get("seq") != i:
            reasons.append("FIX-LINE-%d-BAD-SEQ: seq %r != position %d (dropped/reordered)"
                           % (i, rec.get("seq"), i))
        if rec.get("prev_hash") != prev:
            reasons.append("FIX-LINE-%d-CHAIN-BREAK: prev_hash != prior entry_hash" % i)
        core = {k: v for k, v in rec.items() if k != "entry_hash"}
        if canon_hash(core) != rec.get("entry_hash"):
            reasons.append("FIX-LINE-%d-TAMPER: entry_hash != recomputed canonical hash" % i)
        prev = rec.get("entry_hash")
        # within-file monotonic: attempts for one (plan_hash, check_id) must strictly increase
        key = (rec.get("plan_hash"), rec.get("check_id"))
        a = rec.get("attempt")
        if isinstance(a, int) and not isinstance(a, bool):
            if key in last_attempt and a <= last_attempt[key]:
                reasons.append("FIX-LINE-%d-COUNTER-DECREASE: attempt %r <= prior %r for the same "
                               "(plan_hash, check_id) (reset/replay)" % (i, a, last_attempt[key]))
            last_attempt[key] = max(a, last_attempt.get(key, a))
    return reasons


# ------------------------------------------------------------------- cross-run counter aggregate

def collect_attempts(root, plan_filter=None):
    """Aggregate {(plan_hash, check_id): [attempts...]} across ALL run logs (the durable, plan_hash
    -scoped counter). Fail-closed: a tampered sibling log raises so callers refuse rather than trust
    a corrupt high-water-mark. Returns (mapping, taint_reasons)."""
    agg, taints = {}, []
    for rid, lp in iter_run_logs(root):
        lines = read_lines(lp)
        errs = validate_log(lines)
        if errs:
            taints.append("FIX-SIBLING-TAINTED: run %s log fails validation (first: %s)"
                          % (rid, errs[0]))
            continue
        for raw in lines:
            rec = loads_strict(raw)
            ph, cid, a = rec.get("plan_hash"), rec.get("check_id"), rec.get("attempt")
            if plan_filter is not None and ph != plan_filter:
                continue
            if isinstance(a, int) and not isinstance(a, bool):
                agg.setdefault((ph, cid), []).append(a)
    return agg, taints


def cross_run_reasons(root, plan_filter=None):
    """Cross-run counter invariant: per (plan_hash, check_id) the attempt numbers across ALL runs
    must be unique and contiguous 1..N. A duplicate = a fresh run re-using a recorded number
    (reset gaming); a gap = a laundered/forged jump. Fail-closed. Returns named reason codes."""
    agg, taints = collect_attempts(root, plan_filter)
    reasons = list(taints)
    for (ph, cid), attempts in sorted(agg.items(), key=lambda kv: (kv[0][0] or "", kv[0][1] or "")):
        s = sorted(attempts)
        if len(s) != len(set(s)):
            reasons.append("FIX-RESET-GAMING: duplicate attempt across runs for (plan_hash=%s.., "
                           "check_id=%s) — a fresh run re-used a recorded counter" % (ph[:8], cid))
        elif s != list(range(1, len(s) + 1)):
            reasons.append("FIX-COUNTER-GAP: attempts for (plan_hash=%s.., check_id=%s) are not "
                           "contiguous 1..N (%s)" % (ph[:8], cid, s))
    return reasons


def high_water(root, plan_hash, check_id):
    """Highest recorded attempt for (plan_hash, check_id) across ALL run logs (0 if none).
    Raises ValueError if any sibling log is tainted (fail-closed)."""
    agg, taints = collect_attempts(root, plan_hash)
    if taints:
        raise ValueError(taints[0])
    return max(agg.get((plan_hash, check_id), [0]) or [0])


# ------------------------------------------------------------------- run binding

def run_plan_hash(doc):
    """Extract the plan_hash the counters bind to from a run.json dict; (None, reason) on failure."""
    ph = doc.get("plan_hash")
    if not (isinstance(ph, str) and HASH_RE.match(ph)):
        return None, "FIX-RUN-BINDING: run.json plan_hash missing/not hash-shaped"
    return ph, None


# ------------------------------------------------------------------- append

def cmd_append(root, run_id, check_id, bound, hypothesis, files_touched):
    rid = run_id or read_pointer(root)
    if not rid:
        refuse(["FIX-NO-RUN: no --run-id given and no current-run-id pointer present"])
    rjp = run_json_path(root, rid)
    lp = log_path(root, rid)
    if is_secret_path(rjp) or is_secret_path(lp):
        refuse(["FIX-SECRET-PATH: refusing a secret-shaped run/log path"])
    if not os.path.isfile(rjp):
        refuse(["FIX-RUN-NOT-FOUND: no run.json for run-id %s" % rid])
    try:
        doc = load_json_file(rjp)
    except Exception as e:  # noqa: BLE001
        refuse(["FIX-RUN-UNREADABLE: %s" % e.__class__.__name__])
    plan_hash, reason = run_plan_hash(doc)
    if reason:
        refuse([reason])
    if not nestr(check_id):
        refuse(["FIX-BAD-CHECK-ID: --check-id missing/empty"])
    if scan({"check_id": check_id}):
        refuse(["FIX-SECRET-SHAPED: secret-shaped check_id"])
    if isinstance(bound, bool) or not isinstance(bound, int) or bound < 1:
        refuse(["FIX-BAD-BOUND: --bound must be an integer >= 1"])
    files_touched = files_touched or []
    if any(not rel_ok(p) for p in files_touched):
        refuse(["FIX-BAD-FILES-TOUCHED: files_touched must be relative paths with no '..'"])

    # Guard against appending onto a tainted own-log, and against a pre-existing cross-run collision.
    if os.path.isfile(lp):
        errs = validate_log(read_lines(lp))
        if errs:
            refuse(["FIX-LOG-TAINTED: refusing to append onto an invalid log",
                    "  first reason: %s" % errs[0]])
    xr = cross_run_reasons(root, plan_hash)
    if xr:
        refuse(["FIX-CROSS-RUN-TAINTED: refusing to append while the cross-run counter is invalid",
                "  first reason: %s" % xr[0]])

    # Mint the next attempt from the durable cross-run high-water-mark (anti reset-gaming).
    try:
        hw = high_water(root, plan_hash, check_id)
    except ValueError as e:
        refuse(["FIX-CROSS-RUN-TAINTED: %s" % e])
    attempt = hw + 1
    verdict = "STOP" if attempt > bound else "CONTINUE"

    seq, prev = 0, GENESIS
    if os.path.isfile(lp):
        lines = read_lines(lp)
        if lines:
            last = loads_strict(lines[-1])
            seq, prev = last["seq"] + 1, last["entry_hash"]

    rec = {
        "schema": SCHEMA,
        "plan_hash": plan_hash,
        "check_id": check_id,
        "attempt": attempt,
        "hypothesis": redact(hypothesis if hypothesis is not None else ""),
        "files_touched": list(files_touched),
        "bound": bound,
        "verdict": verdict,
        "seq": seq,
        "prev_hash": prev,
    }
    errs = record_reasons(rec)
    if errs:
        refuse(errs)   # self-refusal: never write a record that fails its own validator
    sealed = seal(rec)
    append_line(lp, json.dumps(sealed, sort_keys=True, ensure_ascii=False))
    print("appended: run=%s seq=%d check_id=%s attempt=%d/%d verdict=%s"
          % (rid, seq, check_id, attempt, bound, verdict))


# ------------------------------------------------------------------- validate

def _under_runs(path):
    """If FILE is <root>/.harness/runs/<rid>/fixloop.log.jsonl, return <root>; else None."""
    ap = os.path.abspath(path)
    rid_dir = os.path.dirname(ap)
    runs = os.path.dirname(rid_dir)
    harness = os.path.dirname(runs)
    if os.path.basename(runs) == "runs" and os.path.basename(harness) == ".harness":
        return os.path.dirname(harness)
    return None


def cmd_validate(path):
    if is_secret_path(path):
        refuse(["FIX-SECRET-PATH: refusing a secret-shaped path"])
    if not os.path.isfile(path):
        refuse(["FIX-LOG-NOT-FOUND: file not found: %s" % path])
    lines = read_lines(path)
    if not lines:
        refuse(["FIX-EMPTY-LOG: no fix-loop records to validate"])
    errs = validate_log(lines)
    root = _under_runs(path)
    if root:
        errs = errs + cross_run_reasons(root)
    if errs:
        refuse(errs)
    print("VALID: %s (%d record(s); chain intact, bound->STOP enforced%s)"
          % (path, len(lines), ", cross-run counter monotonic" if root else ""))


# ------------------------------------------------------------------- self-test (hermetic)

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

    def refused(self, label, reasons, needle):
        self.ok(label, any(needle in r for r in reasons))

    def done(self):
        print("[%s] %d PASS / %d FAIL" % (self.name, self.passed, self.failed))
        sys.exit(0 if self.failed == 0 else 1)


def _real_repo_porcelain():
    git = shutil.which("git")
    if not git:
        return None
    root = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
    try:
        r = subprocess.run([git, "-C", root, "status", "--porcelain"],
                           capture_output=True, timeout=10)
        return r.stdout if r.returncode == 0 else None
    except Exception:  # noqa: BLE001
        return None


def _write_run(root, rid, plan_hash):
    d = os.path.join(runs_dir(root), rid)
    os.makedirs(d, exist_ok=True)
    doc = {"schema": "dmc.run-state.v1", "run_id": rid, "work_id": "W1", "plan_path": "plan.md",
           "plan_hash": plan_hash, "repo_hash": "b" * 64, "status": "RUNNING", "seq": 1,
           "created_at": "t", "updated_at": "t", "prev_hash": GENESIS}
    with open(os.path.join(d, "run.json"), "w", encoding="utf-8") as f:
        json.dump(doc, f)


def _run_cli(root, *args):
    return subprocess.run([sys.executable, "-B", os.path.abspath(__file__), *args, "--root", root],
                          capture_output=True, text=True)


def _forge_log(root, rid, plan_hash, entries):
    """Write a hash-chained log from a list of partial dicts (test helper — the ONLY writer that
    can produce a cross-run collision, so the aggregate guard has something to catch)."""
    lp = log_path(root, rid)
    prev, out = GENESIS, []
    for i, e in enumerate(entries):
        rec = {"schema": SCHEMA, "plan_hash": plan_hash, "check_id": e["check_id"],
               "attempt": e["attempt"], "hypothesis": e.get("hypothesis", ""),
               "files_touched": e.get("files_touched", []), "bound": e.get("bound", 3),
               "verdict": e.get("verdict", "CONTINUE"), "seq": i, "prev_hash": prev}
        sealed = seal(rec)
        prev = sealed["entry_hash"]
        out.append(json.dumps(sealed, sort_keys=True, ensure_ascii=False))
    os.makedirs(os.path.dirname(lp), exist_ok=True)
    with open(lp, "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")
    return lp


def _sweep_pycache():
    shutil.rmtree(os.path.join(os.path.dirname(os.path.abspath(__file__)), "__pycache__"),
                  ignore_errors=True)


def selftest():
    t = ST("fixloop")
    before = _real_repo_porcelain()
    ph = "a" * 64
    tmp = tempfile.mkdtemp(prefix="dmc-fixloop-")
    try:
        rid = "dmc-run-fl01"
        _write_run(tmp, rid, ph)
        lp = log_path(tmp, rid)

        # ---- POSITIVE: append mints monotonic attempts, bound->STOP at the boundary -------------
        a1 = _run_cli(tmp, "append", "--run-id", rid, "--check-id", "CHK-aaa", "--bound", "3",
                      "--hypothesis", "off-by-one in the loop")
        a2 = _run_cli(tmp, "append", "--run-id", rid, "--check-id", "CHK-aaa", "--bound", "3")
        a3 = _run_cli(tmp, "append", "--run-id", rid, "--check-id", "CHK-aaa", "--bound", "3")
        a4 = _run_cli(tmp, "append", "--run-id", rid, "--check-id", "CHK-aaa", "--bound", "3")
        recs = [loads_strict(x) for x in read_lines(lp)]
        t.ok("P1 four appends mint attempts 1..4 for the same (plan_hash, check_id)",
             [r["attempt"] for r in recs] == [1, 2, 3, 4] and a1.returncode == 0
             and a4.returncode == 0)
        t.ok("P2 verdict CONTINUE within bound, STOP once attempt > bound",
             [r["verdict"] for r in recs] == ["CONTINUE", "CONTINUE", "CONTINUE", "STOP"])
        t.ok("P3 attempt bound to plan_hash from run.json (not run-id)",
             all(r["plan_hash"] == ph for r in recs))
        rv = _run_cli(tmp, "--validate", lp)
        t.ok("P4 --validate whole log exit 0 (chain + bound + cross-run)", rv.returncode == 0)
        t.ok("P5 programmatic validate_log returns []", validate_log(read_lines(lp)) == [])

        # ---- POSITIVE: a second check_id counts independently -----------------------------------
        _run_cli(tmp, "append", "--run-id", rid, "--check-id", "CHK-bbb", "--bound", "2")
        recs = [loads_strict(x) for x in read_lines(lp)]
        t.ok("P6 independent counter per check_id (CHK-bbb starts at attempt 1)",
             [r["attempt"] for r in recs if r["check_id"] == "CHK-bbb"] == [1])

        # ---- POSITIVE: hypothesis redaction (advisory, value-blind) ------------------------------
        secret = "ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ012345"
        _run_cli(tmp, "append", "--run-id", rid, "--check-id", "CHK-ccc", "--bound", "3",
                 "--hypothesis", "leaked token %s in config" % secret)
        red = [loads_strict(x) for x in read_lines(lp) if loads_strict(x)["check_id"] == "CHK-ccc"][0]
        t.ok("P7 hypothesis redaction: secret-shaped content replaced, never stored verbatim",
             secret not in red["hypothesis"] and REDACTION in red["hypothesis"])
        t.ok("P7b redacted log still validates (no secret-shaped value survives)",
             validate_log(read_lines(lp)) == [] and not scan([loads_strict(x)
                                                               for x in read_lines(lp)]))

        # ---- POSITIVE: cross-run resume continues the SAME counter (no reset) --------------------
        rid2 = "dmc-run-fl02"
        _write_run(tmp, rid2, ph)
        _run_cli(tmp, "append", "--run-id", rid2, "--check-id", "CHK-aaa", "--bound", "3")
        cont = [loads_strict(x) for x in read_lines(log_path(tmp, rid2))]
        t.ok("P8 fresh run resumes CHK-aaa at attempt 5 (cross-run high-water+1, not reset to 1)",
             [r["attempt"] for r in cont] == [5])
        t.ok("P8b cross-run aggregate is clean (contiguous 1..5 across both run dirs)",
             cross_run_reasons(tmp, ph) == [])

        # ---- NEGATIVE: attempt < 1 (crafted) REFUSED --------------------------------------------
        t.refused("N1 attempt < 1 REFUSED",
                  record_reasons({"schema": SCHEMA, "plan_hash": ph, "check_id": "CHK-x",
                                  "attempt": 0, "bound": 3, "verdict": "CONTINUE",
                                  "files_touched": []}),
                  "FIX-BAD-ATTEMPT")
        # ---- NEGATIVE: attempt > bound with verdict != STOP (crafted) REFUSED --------------------
        t.refused("N2 attempt over bound with verdict CONTINUE REFUSED",
                  record_reasons({"schema": SCHEMA, "plan_hash": ph, "check_id": "CHK-x",
                                  "attempt": 4, "bound": 3, "verdict": "CONTINUE",
                                  "files_touched": []}),
                  "FIX-BOUND-NOT-STOP")
        # ---- NEGATIVE: files_touched with '..' (crafted) REFUSED --------------------------------
        t.refused("N3 files_touched entry with '..' REFUSED",
                  record_reasons({"schema": SCHEMA, "plan_hash": ph, "check_id": "CHK-x",
                                  "attempt": 1, "bound": 3, "verdict": "CONTINUE",
                                  "files_touched": ["../etc/passwd"]}),
                  "FIX-BAD-FILES-TOUCHED")
        t.refused("N3b files_touched absolute path REFUSED",
                  record_reasons({"schema": SCHEMA, "plan_hash": ph, "check_id": "CHK-x",
                                  "attempt": 1, "bound": 3, "verdict": "CONTINUE",
                                  "files_touched": ["/etc/passwd"]}),
                  "FIX-BAD-FILES-TOUCHED")
        # ---- NEGATIVE: within-file counter decrease (crafted, chained) REFUSED -------------------
        # Forged bad logs live in their own tempdir so they never pollute the clean root's
        # cross-run aggregate (a tainted sibling fails EVERY validate under that root — fail-closed).
        dtmp = tempfile.mkdtemp(prefix="dmc-fixloop-dec-")
        try:
            dec = _forge_log(dtmp, "run-D", "c" * 64,
                             [{"check_id": "CHK-d", "attempt": 3},
                              {"check_id": "CHK-d", "attempt": 2}])
            t.refused("N4 within-file counter decrease REFUSED",
                      validate_log(read_lines(dec)), "FIX-LINE-1-COUNTER-DECREASE")
        finally:
            shutil.rmtree(dtmp, ignore_errors=True)

        # ---- NEGATIVE: cross-run RESET GAMING (fresh run re-uses a recorded attempt) REFUSED -----
        gtmp = tempfile.mkdtemp(prefix="dmc-fixloop-gm-")
        try:
            gph = "d" * 64
            _forge_log(gtmp, "run-A", gph, [{"check_id": "CHK-g", "attempt": 1},
                                            {"check_id": "CHK-g", "attempt": 2},
                                            {"check_id": "CHK-g", "attempt": 3}])
            reset = _forge_log(gtmp, "run-B", gph, [{"check_id": "CHK-g", "attempt": 1}])
            t.refused("N5 cross-run reset gaming (fresh run attempt 1 re-uses a recorded counter) "
                      "REFUSED", cross_run_reasons(gtmp, gph), "FIX-RESET-GAMING")
            rg = _run_cli(gtmp, "--validate", reset)
            t.ok("N5b --validate on the fresh-run log exits 3 (cross-run reset gaming detected)",
                 rg.returncode == 3 and "FIX-RESET-GAMING" in rg.stdout)
            # and an append into the colliding run refuses to extend the tainted counter
            _write_run(gtmp, "run-B", gph)
            ap = _run_cli(gtmp, "append", "--run-id", "run-B", "--check-id", "CHK-g", "--bound", "5")
            t.ok("N5c append refuses to extend a tainted cross-run counter (fail-closed)",
                 ap.returncode == 3 and "FIX-CROSS-RUN-TAINTED" in ap.stdout)
        finally:
            shutil.rmtree(gtmp, ignore_errors=True)

        # ---- NEGATIVE: append onto a tampered own-log REFUSED -----------------------------------
        ttmp = tempfile.mkdtemp(prefix="dmc-fixloop-tp-")
        try:
            tph = "e" * 64
            _write_run(ttmp, "run-T", tph)
            tlp = _forge_log(ttmp, "run-T", tph, [{"check_id": "CHK-t", "attempt": 1}])
            recs = read_lines(tlp)
            tampered = dict(loads_strict(recs[0]), hypothesis="MUTATED")   # entry_hash now stale
            with open(tlp, "w", encoding="utf-8") as f:
                f.write(json.dumps(tampered, sort_keys=True, ensure_ascii=False) + "\n")
            t.refused("N6 tampered own-log detected by the chain (entry_hash stale) REFUSED",
                      validate_log(read_lines(tlp)), "FIX-LINE-0-TAMPER")
            ap = _run_cli(ttmp, "append", "--run-id", "run-T", "--check-id", "CHK-t", "--bound", "3")
            t.ok("N6b append refuses onto a tampered own-log (exit 3, not written)",
                 ap.returncode == 3 and "FIX-LOG-TAINTED" in ap.stdout)
        finally:
            shutil.rmtree(ttmp, ignore_errors=True)

        # ---- NEGATIVE: append against a missing run REFUSED -------------------------------------
        c5 = _run_cli(tmp, "append", "--run-id", "no-such-run", "--check-id", "CHK-x", "--bound", "3")
        t.ok("N7 append against a missing run REFUSED exit 3",
             c5.returncode == 3 and "FIX-RUN-NOT-FOUND" in c5.stdout)

        # ---- determinism + env independence -----------------------------------------------------
        d1 = _run_cli(tmp, "--validate", lp)
        d2 = subprocess.run([sys.executable, "-B", os.path.abspath(__file__), "--validate", lp,
                             "--root", tmp], capture_output=True, text=True,
                            env={"PATH": os.environ.get("PATH", ""), "GLM_API_KEY": "x",
                                 "DMC_FIX": "y"})
        t.ok("H1 env-independent: --validate identical under injected env",
             d1.returncode == d2.returncode == 0 and d1.stdout == d2.stdout)
        d3 = subprocess.run(["env", "-i", "PATH=" + os.environ.get("PATH", ""), sys.executable,
                             "-B", os.path.abspath(__file__), "--validate", lp, "--root", tmp],
                            capture_output=True, text=True)
        t.ok("H2 env -i identical: --validate byte-identical under a stripped environment",
             d3.returncode == 0 and d3.stdout == d1.stdout)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
        _sweep_pycache()

    after = _real_repo_porcelain()
    t.ok("H3 real repo git status --porcelain byte-identical before/after (or git absent)",
         before == after)
    t.done()


# ------------------------------------------------------------------------ main

def _split_csv(s):
    if s is None:
        return []
    return [p.strip() for p in s.split(",") if p.strip()]


def main():
    ap = argparse.ArgumentParser(prog="dmc-fixloop")
    ap.add_argument("command", nargs="?", choices=["append"])
    ap.add_argument("--root", default=".")
    ap.add_argument("--run-id", dest="run_id", metavar="ID")
    ap.add_argument("--check-id", dest="check_id", metavar="CID")
    ap.add_argument("--bound", type=int, metavar="N")
    ap.add_argument("--hypothesis", metavar="TEXT")
    ap.add_argument("--files-touched", dest="files_touched", metavar="A,B")
    ap.add_argument("--validate", metavar="FILE")
    ap.add_argument("--self-test", dest="self_test", action="store_true")
    a = ap.parse_args()

    if a.self_test:
        selftest()
        return
    if a.validate:
        cmd_validate(a.validate)
        return
    if not a.command:
        die("usage: dmc-fixloop append --run-id ID --check-id CID --bound N [--hypothesis H] "
            "[--files-touched a,b] [--root DIR] | --validate FILE | --self-test", 2)

    root = os.path.abspath(a.root)
    if not os.path.isdir(root):
        die("--root is not a directory: %s" % root, 2)

    if a.command == "append":
        if not a.check_id:
            die("append requires --check-id", 2)
        if a.bound is None:
            die("append requires --bound", 2)
        cmd_append(root, a.run_id, a.check_id, a.bound, a.hypothesis,
                   _split_csv(a.files_touched))


if __name__ == "__main__":
    main()
