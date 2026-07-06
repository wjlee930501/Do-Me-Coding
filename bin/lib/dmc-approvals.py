#!/usr/bin/env python3
"""dmc-approvals.py — DMC v1.0 M4 typed approvals ledger + R12 anti-laundering (P17).

Appends `approval`-kind trace-linkage records to `.harness/runs/<run-id>/approvals.jsonl`
(append-only, hash-chained, tamper-evident) with the FIXED human-release-gate provenance the
Trace Linkage Contract (`.harness/schemas/trace-linkage.schema.md`) pins for approvals, plus a
NEW local field `gate_kind` carrying the seven gate kinds. The seven kinds do NOT live in `type`
(the copied v0.6.1.0 validator pins `type` and `producer_milestone_id` to the literal
`human-release-gate`); they live in `gate_kind`, validated by this module's own local rule.

Two gates, defense-in-depth (plan §DMC-T009c, Risks/approvals row, Acceptance 4 & 7):
  1. LOCAL RULE (T009c-owned) — enforced for EVERY record regardless of kind: the 7-enum on
     `gate_kind` (unknown/missing REFUSED) AND the R12 provenance predicate with byte-identical
     semantics to the copied validator's (`source` prefixed `human-release-gate:` + non-empty
     auth-id + `type == producer_milestone_id == human-release-gate`), plus the subject binding
     (`work_id` + hash-shaped `plan_hash`/`repo_hash`) and a value-blind secret scan.
  2. SPLIT cross-check — post-verification kinds (release/push/waiver) MUST carry a non-empty
     `verification_ref` (presence-only — ref->artifact resolution is enforced by the M9 release
     gate, not here) and are ADDITIONALLY cross-checked by invoking the copied
     `bin/lib/dmc-v0.6.1.0-trace-linkage.py validate-entry approval` as a read-only subprocess;
     pre-verification kinds (plan_approval/scope_amendment/bound_raise/live_call) MUST OMIT
     `verification_ref` (the copied validator unconditionally requires one, so it is inapplicable
     to them) and are gated by the local rule only. A pre-verification record carrying ANY
     `verification_ref` (placeholder or otherwise) is REFUSED.

Subcommands / flags:
  append --run-id ID --gate-kind KIND --auth-id AUTH [--verification-ref REF] [--id ID] [--root DIR]
                                   append one approval record (fail-closed: local rule must pass,
                                   and post-verification kinds must also pass the copied cross-check)
  --validate FILE                  fail-closed ledger validator (VALID => 0, REFUSED => 3):
                                   per-record local rule + hash-chain integrity + post-verification
                                   cross-check + (if a sibling run.json exists) binding-vs-run
  --self-test                      hermetic section self-test (tempdir only)

House rules (v0.6.x / M2-M3 lineage): stdlib-only, deterministic (sorted-key canonical hashing;
run-id/binding come from run.json, never wall-clock), env-independent (no env reads; the only
subprocess is the copied validator over stdin), offline (no network), fail-closed with named
reason codes and negative controls, value-blind refusals (name schema constants/enums, never
document content), secret-bearing paths refused by path only. Advisory tier: the runtime
enforcement floor stays the hooks (M6). R12 is provenance-not-authentication (honest label, v1.1+).
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

# ---- fixed human-release-gate provenance (verbatim from trace-linkage.schema.md) -------------
PRODUCER = "human-release-gate"        # approval entry producer_milestone_id (T8)
APPROVAL_TYPE = "human-release-gate"   # approval.type literal (T7)
APPROVAL_PREFIX = "human-release-gate:"  # approval.source allowlist prefix (R12/T7c)

# ---- the seven gate kinds (local field; NOT carried in `type`) --------------------------------
PRE_VERIFICATION_KINDS = {"plan_approval", "scope_amendment", "bound_raise", "live_call"}
POST_VERIFICATION_KINDS = {"release", "push", "waiver"}
GATE_KINDS = PRE_VERIFICATION_KINDS | POST_VERIFICATION_KINDS

GENESIS = "0" * 64                      # hash-chain root (hash-shaped, so prev_hash is uniform)
HASH_RE = re.compile(r"^[0-9a-f]{16,}$")
POINTER_NAME = "current-run-id"         # local-only pointer minted by T009a (gitignored)
COPIED_VALIDATOR = "dmc-v0.6.1.0-trace-linkage.py"  # invoked read-only; never edited

SECRET_ALLOW_BASENAMES = {".env.example", ".env.sample", ".env.template", ".env.dist"}

# Value-blind reject-on-match set (copied verbatim from dmc-v0.6.1.0-trace-linkage.py's UNSAFE so
# a secret-shaped auth-id / field is refused with the same semantics as the copied validator).
UNSAFE = re.compile(
    r'sk-[A-Za-z0-9_-]{16,}|AKIA[0-9A-Z]{8,}|(?:BEGIN|END)[A-Z ]*PRIVATE KEY|xox[baprs]-[A-Za-z0-9-]{6,}'
    r'|gh[opsu]_[A-Za-z0-9]{16,}|github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{16,}|npm_[A-Za-z0-9]{30,}'
    r'|AIza[0-9A-Za-z_-]{20,}|dop_v1_[A-Za-z0-9]{32,}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'
    r'|ya29\.[A-Za-z0-9_-]{10,}|AccountKey=[A-Za-z0-9+/=]{20,}|Bearer\s+[A-Za-z0-9._-]{12,}'
    r'|(?:password|api_key|client_secret|aws_secret_access_key)\s*=\s*\S+|[A-Za-z0-9_-]*_token\s*[=:]\s*\S+'
)


# ------------------------------------------------------------------- helpers

def die(msg, code=2):
    sys.stderr.write("dmc-approvals: %s\n" % msg)
    sys.exit(code)


def refuse(reasons):
    for r in reasons:
        print("REFUSED: %s" % r)
    sys.exit(3)


def nestr(x):
    """Non-empty single-line string (byte-identical to the copied validator's nestr)."""
    return isinstance(x, str) and x != "" and "\n" not in x


def scan(o):
    """Recursive value-blind secret scan (reject-on-match); mirrors the copied validator."""
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
    """Duplicate-key-rejecting JSON parse."""
    return json.loads(text, object_pairs_hook=_no_dup)


def load_json_file(path):
    with open(path, "r", encoding="utf-8") as f:
        return loads_strict(f.read())


def iso_now():
    """UTC ISO-8601 stamp. Runtime clock read only; self-tests never depend on the value."""
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def seal(rec):
    """Return a new record with entry_hash = canon_hash(record - entry_hash) (append-only chain)."""
    core = {k: v for k, v in rec.items() if k != "entry_hash"}
    return dict(core, entry_hash=canon_hash(core))


# ------------------------------------------------------------------- storage layout

def runs_dir(root):
    return os.path.join(root, ".harness", "runs")


def run_json_path(root, run_id):
    return os.path.join(runs_dir(root), run_id, "run.json")


def ledger_path(root, run_id):
    return os.path.join(runs_dir(root), run_id, "approvals.jsonl")


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


def run_binding(doc):
    """Extract the subject binding (work_id + hash-shaped plan_hash/repo_hash) from a run.json dict.
    Returns (binding_dict, reasons); binding is None if any reason is present. Does not re-validate
    the whole run-state (that is T009a's validator) — only the three fields this ledger binds to."""
    b, reasons = {}, []
    for k in ("work_id", "plan_hash", "repo_hash"):
        v = doc.get(k)
        if not nestr(v):
            reasons.append("APPROVAL-RUN-BINDING: run.json %s missing/empty" % k)
        else:
            b[k] = v
    for hk in ("plan_hash", "repo_hash"):
        if hk in b and not HASH_RE.match(b[hk]):
            reasons.append("APPROVAL-RUN-BINDING: run.json %s not hash-shaped" % hk)
            b.pop(hk, None)
    if reasons:
        return None, reasons
    return b, []


# ------------------------------------------------------------------- the LOCAL RULE

def local_rule(rec, expected_binding=None):
    """The T009c-owned gate. Returns a list of named reason codes ([] == VALID) for ONE record.

    Enforced for EVERY record regardless of gate_kind:
      - value-blind secret scan (reject-on-match)
      - kind == approval, non-empty id
      - R12 provenance, byte-identical to the copied validator: type == producer_milestone_id ==
        human-release-gate; source prefixed 'human-release-gate:' with a non-empty auth-id
      - subject binding: non-empty work_id, hash-shaped plan_hash/repo_hash
      - gate_kind in the seven (unknown/missing REFUSED)
      - verification_ref split: post-verification kinds require a non-empty one (presence-only;
        ref->artifact resolution is enforced by the M9 release gate, not here); pre-verification
        kinds must omit it entirely (any present value REFUSED)
      - if expected_binding given: work_id/plan_hash/repo_hash must equal the run's (no foreign subject)
    """
    if not isinstance(rec, dict):
        return ["APPROVAL-NOT-OBJECT: record is not a JSON object"]
    reasons = []
    if scan(rec):
        reasons.append("APPROVAL-SECRET-SHAPED: secret-shaped value present (value-blind, T10)")
    if rec.get("kind") != "approval":
        reasons.append("APPROVAL-BAD-KIND: kind != approval")
    if not nestr(rec.get("id")):
        reasons.append("APPROVAL-BAD-ID: id missing/empty")

    # R12 provenance predicate (identical literals/semantics to dmc-v0.6.1.0-trace-linkage.py)
    if rec.get("type") != APPROVAL_TYPE:
        reasons.append("APPROVAL-BAD-TYPE: type != human-release-gate (R12/T7)")
    if rec.get("producer_milestone_id") != PRODUCER:
        reasons.append("APPROVAL-BAD-PRODUCER: producer_milestone_id != human-release-gate (R12/T8)")
    src = rec.get("source")
    if not (nestr(src) and src.startswith(APPROVAL_PREFIX)):
        reasons.append("APPROVAL-BAD-SOURCE: source not 'human-release-gate:' prefixed (R12/T7c)")
    elif src[len(APPROVAL_PREFIX):].strip() == "":
        reasons.append("APPROVAL-EMPTY-AUTH-ID: source missing non-empty auth-id (R12/T7d)")

    # subject binding shape
    if not nestr(rec.get("work_id")):
        reasons.append("APPROVAL-BAD-WORK-ID: work_id missing/empty")
    for hk in ("plan_hash", "repo_hash"):
        v = rec.get(hk)
        if not (isinstance(v, str) and HASH_RE.match(v)):
            reasons.append("APPROVAL-BAD-HASH: %s not hash-shaped" % hk)

    # gate_kind 7-enum + the pre/post verification_ref split
    gk = rec.get("gate_kind")
    if gk is None:
        reasons.append("APPROVAL-MISSING-GATE-KIND: gate_kind absent (must be one of the seven)")
    elif gk not in GATE_KINDS:
        reasons.append("APPROVAL-UNKNOWN-GATE-KIND: gate_kind %r not in {%s}"
                       % (gk, ",".join(sorted(GATE_KINDS))))
    elif gk in POST_VERIFICATION_KINDS:
        if not nestr(rec.get("verification_ref")):
            reasons.append("APPROVAL-MISSING-VERIFICATION-REF: post-verification kind %s "
                           "requires a non-empty verification_ref (presence-only; ref->artifact "
                           "resolution is the M9 release gate, not here)" % gk)
    else:  # pre-verification kind
        if "verification_ref" in rec:
            reasons.append("APPROVAL-UNEXPECTED-VERIFICATION-REF: pre-verification kind %s "
                           "must omit verification_ref" % gk)

    # binding vs the run (no foreign-subject approval)
    if expected_binding is not None:
        for k in ("work_id", "plan_hash", "repo_hash"):
            if rec.get(k) != expected_binding.get(k):
                reasons.append("APPROVAL-SUBJECT-MISMATCH: %s != run binding (foreign subject)" % k)
    return reasons


# ------------------------------------------------------- copied-validator cross-check (subprocess)

def cross_check(rec):
    """Invoke the copied v0.6.1.0 `validate-entry approval` over stdin (read-only). Returns
    (ok, detail). Used for post-verification kinds only (they carry a non-empty verification_ref;
    presence-only — ref->artifact resolution is the M9 release gate, not here)."""
    copied = os.path.join(os.path.dirname(os.path.abspath(__file__)), COPIED_VALIDATOR)
    if not os.path.isfile(copied):
        return False, "copied validator not found: %s" % COPIED_VALIDATOR
    try:
        r = subprocess.run([sys.executable, copied, "validate-entry", "approval", "-"],
                           input=json.dumps(rec, ensure_ascii=False),
                           capture_output=True, text=True, timeout=20)
    except Exception as e:  # noqa: BLE001 — a broken cross-check must fail closed
        return False, "cross-check subprocess error: %s" % e.__class__.__name__
    detail = (r.stderr.strip() or r.stdout.strip() or ("exit %d" % r.returncode))
    return r.returncode == 0, detail


# ------------------------------------------------------------------- ledger validation (chain)

def validate_ledger(lines, expected_binding=None, do_cross_check=True):
    """Fail-closed whole-ledger validator: per-record local rule + append-only hash-chain
    integrity (a rewritten or dropped line is detectable) + post-verification cross-check.
    Returns a list of named reason codes ([] == VALID)."""
    reasons = []
    prev = GENESIS
    for i, raw in enumerate(lines):
        try:
            rec = loads_strict(raw)
        except ValueError as e:
            reasons.append("APPROVAL-LINE-%d-BAD-JSON: %s" % (i, e))
            prev = None  # chain is unrecoverable past a bad line
            continue
        for r in local_rule(rec, expected_binding):
            reasons.append("APPROVAL-LINE-%d %s" % (i, r))
        # append-only chain: seq is the line index; prev_hash links to the prior entry_hash;
        # entry_hash must recompute (rewrite => TAMPER; drop/reorder => BAD-SEQ + CHAIN-BREAK).
        if rec.get("seq") != i:
            reasons.append("APPROVAL-LINE-%d-BAD-SEQ: seq %r != position %d (dropped/reordered)"
                           % (i, rec.get("seq"), i))
        if rec.get("prev_hash") != prev:
            reasons.append("APPROVAL-LINE-%d-CHAIN-BREAK: prev_hash != prior entry_hash" % i)
        core = {k: v for k, v in rec.items() if k != "entry_hash"}
        if canon_hash(core) != rec.get("entry_hash"):
            reasons.append("APPROVAL-LINE-%d-TAMPER: entry_hash != recomputed canonical hash" % i)
        prev = rec.get("entry_hash")
        if do_cross_check and rec.get("gate_kind") in POST_VERIFICATION_KINDS:
            ok, detail = cross_check(rec)
            if not ok:
                reasons.append("APPROVAL-LINE-%d-CROSSCHECK-FAIL: copied validate-entry approval "
                               "rejected: %s" % (i, detail))
    return reasons


# ------------------------------------------------------------------- record construction / append

def build_record(binding, gate_kind, auth_id, verification_ref, id_override, seq, prev):
    """Assemble one UNSEALED approval record from the run binding + gate inputs. The local rule
    (run after this) enforces provenance/enum/split; append refuses if it does not pass."""
    rec = {
        "kind": "approval",
        "id": id_override or ("approval-%04d-%s" % (seq, gate_kind)),
        "producer_milestone_id": PRODUCER,
        "type": APPROVAL_TYPE,
        "source": APPROVAL_PREFIX + (auth_id if auth_id is not None else ""),
        "gate_kind": gate_kind,
        "work_id": binding["work_id"],
        "plan_hash": binding["plan_hash"],
        "repo_hash": binding["repo_hash"],
        "seq": seq,
        "prev_hash": prev,
        "created_at": iso_now(),
    }
    # Only attach verification_ref when explicitly supplied, so the local rule's pre/post split is
    # decidable: a pre-verification kind given a ref keeps it and is REFUSED; a post-verification
    # kind without one omits it and is REFUSED ("post requires a non-empty verification_ref";
    # presence-only — ref->artifact resolution is the M9 release gate, not here).
    if verification_ref is not None:
        rec["verification_ref"] = verification_ref
    return rec


def cmd_append(root, run_id, gate_kind, auth_id, verification_ref, id_override):
    rid = run_id or read_pointer(root)
    if not rid:
        refuse(["APPROVAL-NO-RUN: no --run-id given and no current-run-id pointer present"])
    rjp = run_json_path(root, rid)
    if is_secret_path(rjp) or is_secret_path(ledger_path(root, rid)):
        refuse(["APPROVAL-SECRET-PATH: refusing a secret-shaped run/ledger path"])
    if not os.path.isfile(rjp):
        refuse(["APPROVAL-RUN-NOT-FOUND: no run.json for run-id %s" % rid])
    try:
        doc = load_json_file(rjp)
    except Exception as e:  # noqa: BLE001
        refuse(["APPROVAL-RUN-UNREADABLE: %s" % e.__class__.__name__])
    binding, breasons = run_binding(doc)
    if breasons:
        refuse(breasons)

    lpath = ledger_path(root, rid)
    seq, prev = 0, GENESIS
    if os.path.isfile(lpath):
        lines = read_lines(lpath)
        # Never append onto a broken chain (append-only guard).
        errs = validate_ledger(lines, binding)
        if errs:
            refuse(["APPROVAL-LEDGER-TAINTED: refusing to append onto an invalid ledger",
                    "  first reason: %s" % errs[0]])
        if lines:
            last = loads_strict(lines[-1])
            seq, prev = last["seq"] + 1, last["entry_hash"]

    rec = build_record(binding, gate_kind, auth_id, verification_ref, id_override, seq, prev)
    errs = local_rule(rec, binding)
    if errs:
        refuse(errs)
    if gate_kind in POST_VERIFICATION_KINDS:
        ok, detail = cross_check(rec)
        if not ok:
            refuse(["APPROVAL-CROSSCHECK-FAIL: copied validate-entry approval rejected: %s" % detail])

    sealed = seal(rec)
    append_line(lpath, json.dumps(sealed, sort_keys=True, ensure_ascii=False))
    print("appended: run=%s seq=%d gate_kind=%s id=%s" % (rid, seq, gate_kind, sealed["id"]))


def cmd_validate(path):
    if is_secret_path(path):
        refuse(["APPROVAL-SECRET-PATH: refusing a secret-shaped path"])
    if not os.path.isfile(path):
        refuse(["APPROVAL-LEDGER-NOT-FOUND: file not found: %s" % path])
    lines = read_lines(path)
    if not lines:
        refuse(["APPROVAL-EMPTY-LEDGER: no approval records to validate"])
    binding = None
    sib = os.path.join(os.path.dirname(os.path.abspath(path)), "run.json")
    if os.path.isfile(sib) and not is_secret_path(sib):
        try:
            binding, _ = run_binding(load_json_file(sib))
        except Exception:  # noqa: BLE001 — best-effort binding context; chain+local rule still run
            binding = None
    errs = validate_ledger(lines, binding)
    if errs:
        refuse(errs)
    print("VALID: %s (%d record(s); chain intact, R12 uniform, split enforced%s)"
          % (path, len(lines), ", bound to run" if binding else ""))


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
        """Assert the local rule produced a refusal carrying `needle`."""
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


def _write_run(root, rid, work_id="W1", ph="a" * 64, rh="b" * 64):
    """Write a minimal `dmc.run-state.v1`-shaped run.json (binding fields only) into the tempdir."""
    d = os.path.join(runs_dir(root), rid)
    os.makedirs(d, exist_ok=True)
    doc = {"schema": "dmc.run-state.v1", "run_id": rid, "work_id": work_id,
           "plan_path": "plan.md", "plan_hash": ph, "repo_hash": rh, "status": "RUNNING",
           "seq": 1, "created_at": "t", "updated_at": "t", "prev_hash": GENESIS}
    with open(os.path.join(d, "run.json"), "w", encoding="utf-8") as f:
        json.dump(doc, f)
    return {"work_id": work_id, "plan_hash": ph, "repo_hash": rh}


def _rec(binding, gate_kind="plan_approval", **over):
    """Craft a well-formed approval record for a given kind, then apply overrides for negatives."""
    r = {"kind": "approval", "id": "A-%s" % gate_kind, "producer_milestone_id": PRODUCER,
         "type": APPROVAL_TYPE, "source": APPROVAL_PREFIX + "wjlee", "gate_kind": gate_kind,
         "work_id": binding["work_id"], "plan_hash": binding["plan_hash"],
         "repo_hash": binding["repo_hash"]}
    if gate_kind in POST_VERIFICATION_KINDS:
        r["verification_ref"] = ".harness/verification/dmc-v1-m4-run-lifecycle.md"
    r.update(over)
    return r


def _run_cli(root, *args):
    return subprocess.run([sys.executable, os.path.abspath(__file__), *args, "--root", root],
                          capture_output=True, text=True)


def selftest():
    t = ST("approvals")
    before = _real_repo_porcelain()
    tmp = tempfile.mkdtemp(prefix="dmc-approvals-")
    try:
        rid = "dmc-run-selftest01"
        b = _write_run(tmp, rid)
        lpath = ledger_path(tmp, rid)

        # ---- POSITIVE round-trip: pre + two post kinds append, chain validates ----------------
        r1 = _run_cli(tmp, "append", "--run-id", rid, "--gate-kind", "plan_approval",
                      "--auth-id", "wjlee")
        t.ok("P1 append plan_approval (pre, no vref) exit 0 + 1 line",
             r1.returncode == 0 and len(read_lines(lpath)) == 1)
        r2 = _run_cli(tmp, "append", "--run-id", rid, "--gate-kind", "release", "--auth-id",
                      "wjlee", "--verification-ref", ".harness/verification/dmc-v1-m4.md")
        t.ok("P2 append release (post, non-empty vref) exit 0 + 2 lines",
             r2.returncode == 0 and len(read_lines(lpath)) == 2)
        r3 = _run_cli(tmp, "append", "--run-id", rid, "--gate-kind", "push", "--auth-id",
                      "wjlee", "--verification-ref", ".harness/verification/dmc-v1-m4.md")
        t.ok("P2b append push (post, non-empty vref) exit 0 + 3 lines",
             r3.returncode == 0 and len(read_lines(lpath)) == 3)

        rv = _run_cli(tmp, "--validate", lpath)
        t.ok("P3 --validate whole ledger exit 0 (chain intact + cross-check)", rv.returncode == 0)

        lines = read_lines(lpath)
        t.ok("P3b programmatic validate_ledger returns [] (bound to run)",
             validate_ledger(lines, b) == [])

        # ---- POSITIVE cross-check: the copied validate-entry approval ACCEPTS a release record --
        release_rec = loads_strict(lines[1])
        ok_x, _ = cross_check(release_rec)
        t.ok("P4 POSITIVE cross-check: copied validate-entry approval ACCEPTS release (exit 0)", ok_x)
        t.ok("P5 local_rule ACCEPTS the sealed release record", local_rule(release_rec, b) == [])
        t.ok("P5b local_rule ACCEPTS a valid pre record (plan_approval, no vref)",
             local_rule(_rec(b, "plan_approval"), b) == [])

        # ---- NEGATIVE controls (local rule, each a real REFUSE) --------------------------------
        # laundered source for a PRE and a POST kind (R12 re-test, uniform across kinds)
        t.refused("N1 laundered source 'codex-accept-123' (pre plan_approval) REFUSED",
                  local_rule(_rec(b, "plan_approval", source="codex-accept-123"), b),
                  "APPROVAL-BAD-SOURCE")
        laundered_post = _rec(b, "release", source="codex-accept-123")
        t.refused("N2 laundered source 'codex-accept-123' (post release) REFUSED by local rule",
                  local_rule(laundered_post, b), "APPROVAL-BAD-SOURCE")
        ok_lx, _ = cross_check(laundered_post)
        t.ok("N2b laundered post ALSO rejected by copied validate-entry approval (T7c)", not ok_lx)

        t.refused("N3 empty auth-id ('human-release-gate:') REFUSED",
                  local_rule(_rec(b, "plan_approval", source=APPROVAL_PREFIX), b),
                  "APPROVAL-EMPTY-AUTH-ID")
        t.refused("N4 type != human-release-gate REFUSED",
                  local_rule(_rec(b, "plan_approval", type="plan"), b), "APPROVAL-BAD-TYPE")
        t.refused("N5 producer_milestone_id != human-release-gate REFUSED",
                  local_rule(_rec(b, "plan_approval", producer_milestone_id="v0.6.5"), b),
                  "APPROVAL-BAD-PRODUCER")
        t.refused("N6 unknown gate_kind 'rubber_stamp' REFUSED",
                  local_rule(_rec(b, "rubber_stamp"), b), "APPROVAL-UNKNOWN-GATE-KIND")
        no_gk = _rec(b, "plan_approval")
        del no_gk["gate_kind"]
        t.refused("N7 missing gate_kind REFUSED", local_rule(no_gk, b),
                  "APPROVAL-MISSING-GATE-KIND")
        t.refused("N8 subject-binding mismatch vs run (work_id) REFUSED",
                  local_rule(_rec(b, "plan_approval", work_id="OTHER"), b),
                  "APPROVAL-SUBJECT-MISMATCH")
        t.refused("N9 pre-verification kind carrying a placeholder verification_ref REFUSED",
                  local_rule(_rec(b, "plan_approval", verification_ref="PLACEHOLDER"), b),
                  "APPROVAL-UNEXPECTED-VERIFICATION-REF")
        post_no_vref = _rec(b, "release")
        del post_no_vref["verification_ref"]
        t.refused("N10 post-verification kind missing verification_ref REFUSED",
                  local_rule(post_no_vref, b), "APPROVAL-MISSING-VERIFICATION-REF")
        t.refused("N11 value-blind: secret-shaped auth-id REFUSED",
                  local_rule(_rec(b, "plan_approval",
                                  source=APPROVAL_PREFIX + "ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ012345"), b),
                  "APPROVAL-SECRET-SHAPED")

        # ---- NEGATIVE controls (append-only chain tamper detection) ----------------------------
        # rewrite line 0 body (change created_at only): recomputed entry_hash != stored => TAMPER
        rewritten = dict(loads_strict(lines[0]), created_at="1999-01-01T00:00:00Z")
        tampered_lines = [json.dumps(rewritten, sort_keys=True, ensure_ascii=False)] + lines[1:]
        t.refused("N12 rewritten prior line detected (append-only) REFUSED",
                  validate_ledger(tampered_lines, b, do_cross_check=False),
                  "APPROVAL-LINE-0-TAMPER")
        # drop the middle line: seq/prev_hash linkage breaks
        dropped_lines = [lines[0], lines[2]]
        t.refused("N13 dropped line detected (bad seq) REFUSED",
                  validate_ledger(dropped_lines, b, do_cross_check=False),
                  "APPROVAL-LINE-1-BAD-SEQ")
        t.refused("N13b dropped line also breaks the chain link REFUSED",
                  validate_ledger(dropped_lines, b, do_cross_check=False),
                  "APPROVAL-LINE-1-CHAIN-BREAK")

        # ---- NEGATIVE controls end-to-end via the append CLI (fail-closed, real exit 3) --------
        c1 = _run_cli(tmp, "append", "--run-id", rid, "--gate-kind", "rubber_stamp",
                      "--auth-id", "wjlee")
        t.ok("C1 append unknown gate_kind exit 3 (fail-closed, not written)",
             c1.returncode == 3 and "APPROVAL-UNKNOWN-GATE-KIND" in c1.stdout
             and len(read_lines(lpath)) == 3)
        c2 = _run_cli(tmp, "append", "--run-id", rid, "--gate-kind", "plan_approval",
                      "--auth-id", "")
        t.ok("C2 append empty auth-id exit 3",
             c2.returncode == 3 and "APPROVAL-EMPTY-AUTH-ID" in c2.stdout)
        c3 = _run_cli(tmp, "append", "--run-id", rid, "--gate-kind", "plan_approval",
                      "--auth-id", "wjlee", "--verification-ref", "PLACEHOLDER")
        t.ok("C3 append pre-kind + verification_ref exit 3",
             c3.returncode == 3 and "APPROVAL-UNEXPECTED-VERIFICATION-REF" in c3.stdout)
        c4 = _run_cli(tmp, "append", "--run-id", rid, "--gate-kind", "release", "--auth-id", "wjlee")
        t.ok("C4 append post-kind without verification_ref exit 3",
             c4.returncode == 3 and "APPROVAL-MISSING-VERIFICATION-REF" in c4.stdout)
        c5 = _run_cli(tmp, "append", "--run-id", "no-such-run", "--gate-kind", "plan_approval",
                      "--auth-id", "wjlee")
        t.ok("C5 append against a missing run REFUSED exit 3",
             c5.returncode == 3 and "APPROVAL-RUN-NOT-FOUND" in c5.stdout)
        t.ok("C6 ledger still exactly 3 lines after all refused appends (append-only, no partial)",
             len(read_lines(lpath)) == 3)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    after = _real_repo_porcelain()
    t.ok("H1 real repo git status --porcelain byte-identical before/after (or git absent)",
         before == after)
    t.done()


# ------------------------------------------------------------------------ main

def main():
    ap = argparse.ArgumentParser(prog="dmc-approvals")
    ap.add_argument("command", nargs="?", choices=["append"])
    ap.add_argument("--root", default=".")
    ap.add_argument("--run-id", dest="run_id", metavar="ID")
    ap.add_argument("--gate-kind", dest="gate_kind", metavar="KIND")
    ap.add_argument("--auth-id", dest="auth_id", metavar="AUTH")
    ap.add_argument("--verification-ref", dest="verification_ref", metavar="REF")
    ap.add_argument("--id", dest="id_override", metavar="ID")
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
        die("usage: dmc-approvals append --run-id ID --gate-kind KIND --auth-id AUTH "
            "[--verification-ref REF] [--id ID] [--root DIR] | --validate FILE | --self-test", 2)

    root = os.path.abspath(a.root)
    if not os.path.isdir(root):
        die("--root is not a directory: %s" % root, 2)

    if a.command == "append":
        if a.gate_kind is None:
            die("append requires --gate-kind", 2)
        if a.auth_id is None:
            die("append requires --auth-id", 2)
        cmd_append(root, a.run_id, a.gate_kind, a.auth_id, a.verification_ref, a.id_override)


if __name__ == "__main__":
    main()
