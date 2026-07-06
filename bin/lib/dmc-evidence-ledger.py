#!/usr/bin/env python3
"""dmc-evidence-ledger.py — DMC v1.0 M4 evidence ledger (P10; architecture spine).

Mints append-only, hash-chained evidence receipts (the shipped v0.6.2 evidence-receipt shape,
producer_milestone_id="v0.6.2", plus the new additive `check_id` field) into
`.harness/runs/<run-id>/receipts/` with a single JSONL index (`receipts/index.jsonl`), one receipt
file per entry. `check_id` is REQUIRED by this ledger's own minting policy (the "post-extension"
rule — the v0.6.2 schema itself treats the field as optional/ignored for backward compatibility with
receipts minted before this extension, but nothing this ledger mints may omit it, since P10 receipts
must be check-referable for P12 checkpoint coverage and P13 fix-loop counters).

Secret handling (value-blind, per DMC.md + the v0.5.0/v0.6.2 UNSAFE-shape convention):
  - Opaque, non-format-constrained fields (`id`, `work_id`, `verification_ref`, `checker`,
    `check_id`) are individually scanned; a secret-shaped match REDACTS that field to the fixed
    placeholder `[redacted:unsafe-metadata]` (v0.5.0 pattern) rather than persisting the raw value.
  - `artifact_ref` is format-constrained (hash-shaped or a safe relative path, per the v0.6.2
    predicate) — redacting it would corrupt that shape into an invalid ref, so a secret-shaped
    `artifact_ref` REFUSES the mint outright instead of emitting a broken/laundered receipt.
  - As a final safety net the fully-built receipt is re-scanned before it is persisted; a residual
    match (should never occur given the above) also REFUSES the mint.

Subcommands:
  mint --root DIR --run-id ID --check-id ID --evidence-type TYPE --artifact-ref REF
       --work-id ID --plan-hash HEX --repo-hash HEX --verification-ref REF
       [--id ID] [--machine-verifiable] [--checker ID]
  coverage --root DIR --run-id ID --check-id ID     exit 0 COVERED / 1 NOT-COVERED / 3 REFUSED
  --validate-ledger --root DIR --run-id ID           full chain + receipt-hash validation
  --self-test                                        hermetic section self-test (tempdir only)

House rules (v0.6.x / M4 lineage, matching dmc-run-lifecycle.py): stdlib-only, deterministic
(receipt ids are content-derived, never wall-clock, unless explicitly overridden), env-independent
(no env reads), offline (no network; git is best-effort read-only), fail-closed validators with
named reason codes, value-blind refusals/redactions (name the rule, never the matched content).
Reuse-by-invocation, not by import: the v0.6.2 gate is called read-only, as a subprocess, ONLY from
the self-test's compatibility control — never edited, never imported, never on the mint path.
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

GENESIS = "0" * 64
HASH_RE = re.compile(r"^[0-9a-f]{16,}$")
PATH_RE = re.compile(r"^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)+$")
RUN_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")
EVIDENCE_TYPES = {"verification-report", "test-result", "artifact-existence", "review-packet", "audit-report"}
PRODUCER_MILESTONE_ID = "v0.6.2"
REDACTED = "[redacted:unsafe-metadata]"

# Copied verbatim from dmc-v0.6.2-evidence-receipt.py's UNSAFE constant (compatibility target: a
# receipt this ledger deems secret-free must also be scan()-clean under the v0.6.2 gate).
UNSAFE = re.compile(
  r'sk-[A-Za-z0-9_-]{16,}|AKIA[0-9A-Z]{8,}|(?:BEGIN|END)[A-Z ]*PRIVATE KEY|xox[baprs]-[A-Za-z0-9-]{6,}'
  r'|gh[opsu]_[A-Za-z0-9]{16,}|github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{16,}|npm_[A-Za-z0-9]{30,}'
  r'|AIza[0-9A-Za-z_-]{20,}|dop_v1_[A-Za-z0-9]{32,}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'
  r'|ya29\.[A-Za-z0-9_-]{10,}|AccountKey=[A-Za-z0-9+/=]{20,}|Bearer\s+[A-Za-z0-9._-]{12,}'
  r'|(?:password|api_key|client_secret|aws_secret_access_key)\s*=\s*\S+|[A-Za-z0-9_-]*_token\s*[=:]\s*\S+'
)

V062_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "dmc-v0.6.2-evidence-receipt.py")


# ------------------------------------------------------------------- helpers

def die(msg, code=2):
    sys.stderr.write("dmc-evidence-ledger: %s\n" % msg)
    sys.exit(code)


def refuse(reasons):
    for r in reasons:
        print("REFUSED: %s" % r)
    sys.exit(3)


def nestr(x):
    return isinstance(x, str) and x != "" and "\n" not in x


def artifact_ref_ok(a):
    if not nestr(a):
        return False
    if any(c.isspace() for c in a):
        return False
    if HASH_RE.match(a):
        return True
    if PATH_RE.match(a) and ".." not in a.split("/"):
        return True
    return False


def scan_unsafe(o):
    """Recursive value-blind scan (mirrors the v0.6.2 gate's scan()) for the final safety net."""
    if isinstance(o, dict):
        for k, v in o.items():
            if isinstance(k, str) and UNSAFE.search(k):
                return True
            if scan_unsafe(v):
                return True
    elif isinstance(o, list):
        for x in o:
            if scan_unsafe(x):
                return True
    elif isinstance(o, str):
        if UNSAFE.search(o):
            return True
    return False


def redact(s):
    """Value-blind redact-on-match for opaque fields (v0.5.0 pattern). Returns (value, was_redacted)."""
    if s is not None and UNSAFE.search(s):
        return REDACTED, True
    return s, False


def canon_hash(obj):
    """Shared canonical serialization hash: sorted keys, compact separators, UTF-8, sha256 hex."""
    payload = json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def iso_now():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def strict_obj_hook(pairs):
    keys = [k for k, _ in pairs]
    if len(keys) != len(set(keys)):
        raise ValueError("duplicate key in JSON object")
    return dict(pairs)


def safe_run_id(run_id):
    return bool(run_id) and bool(RUN_ID_RE.match(run_id)) and ".." not in run_id


def sanitize_filename(s):
    return re.sub(r"[^A-Za-z0-9._-]", "_", s)[:80]


# ------------------------------------------------------------------- storage

def runs_dir(root):
    return os.path.join(root, ".harness", "runs")


def receipts_dir(root, run_id):
    return os.path.join(runs_dir(root), run_id, "receipts")


def index_path(root, run_id):
    return os.path.join(receipts_dir(root, run_id), "index.jsonl")


def read_index_entries(root, run_id):
    """Read the JSONL index in file order. Raises ValueError on a malformed line (fail-closed)."""
    p = index_path(root, run_id)
    if not os.path.isfile(p):
        return []
    entries = []
    with open(p, "r", encoding="utf-8") as f:
        for line in f:
            line = line.rstrip("\n")
            if line == "":
                continue
            entries.append(json.loads(line, object_pairs_hook=strict_obj_hook))
    return entries


def append_index_entry(root, run_id, entry):
    os.makedirs(receipts_dir(root, run_id), exist_ok=True)
    with open(index_path(root, run_id), "a", encoding="utf-8") as f:
        f.write(json.dumps(entry, sort_keys=True, separators=(",", ":"), ensure_ascii=False) + "\n")


def save_receipt(root, run_id, rel_path, receipt):
    full = os.path.join(runs_dir(root), run_id, rel_path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w", encoding="utf-8") as f:
        f.write(json.dumps(receipt, sort_keys=True, indent=2, ensure_ascii=False) + "\n")


def load_receipt(root, run_id, rel_path):
    full = os.path.join(runs_dir(root), run_id, rel_path)
    with open(full, "r", encoding="utf-8") as f:
        return json.load(f, object_pairs_hook=strict_obj_hook)


# --------------------------------------------------------------------- chain

def verify_chain(entries):
    """Fail-closed hash-chain + append-only check. Returns a list of named reasons ([] == valid)."""
    prev = GENESIS
    for i, e in enumerate(entries):
        if not isinstance(e, dict):
            return ["EVID-CHAIN-ENTRY-NOT-OBJECT: index entry %d is not a JSON object" % i]
        core = {k: v for k, v in e.items() if k != "entry_hash"}
        if canon_hash(core) != e.get("entry_hash"):
            return ["EVID-CHAIN-TAMPER: index entry %d hash mismatch (rewritten line)" % i]
        if e.get("prev_hash") != prev:
            return ["EVID-CHAIN-BROKEN: index entry %d prev_hash does not chain from the prior "
                     "entry (dropped/reordered/tampered line)" % i]
        if e.get("seq") != i:
            return ["EVID-CHAIN-SEQ-GAP: index entry %d has seq=%r, expected %d "
                     "(dropped/reordered line)" % (i, e.get("seq"), i)]
        prev = e["entry_hash"]
    return []


def validate_ledger(root, run_id):
    """Chain check + cross-check that every receipt file's content matches its indexed hash."""
    try:
        entries = read_index_entries(root, run_id)
    except ValueError as e:
        return ["EVID-INDEX-MALFORMED: %s" % e]
    errs = verify_chain(entries)
    if errs:
        return errs
    seen_ids = set()
    for i, e in enumerate(entries):
        rp = e.get("receipt_path")
        if not isinstance(rp, str) or ".." in rp.replace(os.sep, "/").split("/") or rp.startswith("/"):
            errs.append("EVID-BAD-RECEIPT-PATH: index entry %d has an unsafe receipt_path" % i)
            continue
        try:
            body = load_receipt(root, run_id, rp)
        except FileNotFoundError:
            errs.append("EVID-RECEIPT-MISSING: %s" % rp)
            continue
        except ValueError as ex:
            errs.append("EVID-RECEIPT-UNREADABLE: %s (%s)" % (rp, ex))
            continue
        if canon_hash(body) != e.get("receipt_hash"):
            errs.append("EVID-RECEIPT-HASH-MISMATCH: %s (receipt file edited post-mint)" % rp)
        rid = e.get("receipt_id")
        if rid in seen_ids:
            errs.append("EVID-DUP-RECEIPT-ID: %s" % rid)
        seen_ids.add(rid)
    return errs


def check_coverage(root, run_id, check_id):
    """Returns (covered: bool|None, errs). covered is None (with errs set) if the ledger is broken."""
    errs = validate_ledger(root, run_id)
    if errs:
        return None, errs
    entries = read_index_entries(root, run_id)
    covered = any(e.get("check_id") == check_id for e in entries)
    return covered, []


# ---------------------------------------------------------------- receipt build

def mint_receipt_id(check_id, evidence_type, artifact_ref, seq):
    digest = hashlib.sha256(("%s|%s|%s|%d" % (check_id, evidence_type, artifact_ref, seq)).encode("utf-8")).hexdigest()
    return "rcpt-" + digest[:16]


def struct_errors(work_id, ph, rh, verification_ref, evidence_type, artifact_ref,
                   machine_verifiable, checker, check_id):
    """Structural/shape/enum checks only — no secret-scan (that is handled separately so opaque
    fields can be redacted rather than blanket-refused)."""
    errs = []
    if not nestr(check_id):
        errs.append("EVID-CHECK-ID-REQUIRED: check_id is required for ledger-minted receipts "
                    "(post-extension policy)")
    if not nestr(work_id):
        errs.append("EVID-BAD-WORK-ID: work_id missing/empty")
    if not (isinstance(ph, str) and HASH_RE.match(ph)):
        errs.append("EVID-BAD-PLAN-HASH: plan_hash not hash-shaped")
    if not (isinstance(rh, str) and HASH_RE.match(rh)):
        errs.append("EVID-BAD-REPO-HASH: repo_hash not hash-shaped")
    if not nestr(verification_ref):
        errs.append("EVID-BAD-VERIFICATION-REF: verification_ref missing/empty")
    if evidence_type not in EVIDENCE_TYPES:
        errs.append("EVID-BAD-TYPE: evidence_type not in the five evidence types")
    if artifact_ref is not None and UNSAFE.search(artifact_ref):
        errs.append("EVID-SECRET-ARTIFACT-REF: artifact_ref contains a secret-shaped substring; "
                    "refusing rather than emitting a broken/laundered receipt")
    elif not artifact_ref_ok(artifact_ref):
        errs.append("EVID-BAD-ARTIFACT-REF: artifact_ref not a decidable non-prose ref "
                    "(hash-shaped or safe relative path, no '..')")
    if machine_verifiable and not nestr(checker):
        errs.append("EVID-CHECKER-REQUIRED: machine_verifiable=true requires a non-empty checker")
    return errs


def build_receipt(work_id, ph, rh, verification_ref, evidence_type, artifact_ref,
                   machine_verifiable, checker, check_id, id_override, seq):
    """Returns (receipt|None, reasons, redacted_field_names)."""
    reasons = struct_errors(work_id, ph, rh, verification_ref, evidence_type, artifact_ref,
                             machine_verifiable, checker, check_id)
    if reasons:
        return None, reasons, []

    work_id2, r1 = redact(work_id)
    verification_ref2, r2 = redact(verification_ref)
    checker2, r3 = redact(checker) if checker is not None else (checker, False)
    check_id2, r4 = redact(check_id)
    id_val = id_override if id_override else mint_receipt_id(check_id2, evidence_type, artifact_ref, seq)
    id_val2, r5 = redact(id_val)

    redactions = [name for flag, name in (
        (r1, "work_id"), (r2, "verification_ref"), (r3, "checker"), (r4, "check_id"), (r5, "id"),
    ) if flag]

    receipt = {
        "kind": "evidence_receipt",
        "id": id_val2,
        "producer_milestone_id": PRODUCER_MILESTONE_ID,
        "work_id": work_id2,
        "plan_hash": ph,
        "repo_hash": rh,
        "verification_ref": verification_ref2,
        "evidence_type": evidence_type,
        "artifact_ref": artifact_ref,
        "machine_verifiable": bool(machine_verifiable),
        "checker": checker2,
        "check_id": check_id2,
    }

    # Final value-blind safety net: should never trip given the above, but never persist a
    # residual secret-shaped string anywhere in the built receipt.
    if scan_unsafe(receipt):
        return None, ["EVID-RESIDUAL-SECRET: a secret-shaped value survived redaction; refusing mint"], []

    return receipt, [], redactions


# --------------------------------------------------------------------- verbs

def cmd_mint(root, run_id, a):
    if not safe_run_id(run_id):
        refuse(["EVID-BAD-RUN-ID: run-id is not a safe identifier"])
    try:
        entries = read_index_entries(root, run_id)
    except ValueError as e:
        refuse(["EVID-INDEX-MALFORMED: %s" % e])
    chain_errs = verify_chain(entries)
    if chain_errs:
        refuse(chain_errs)
    seq = len(entries)

    receipt, reasons, redactions = build_receipt(
        work_id=a.work_id, ph=a.plan_hash, rh=a.repo_hash, verification_ref=a.verification_ref,
        evidence_type=a.evidence_type, artifact_ref=a.artifact_ref,
        machine_verifiable=a.machine_verifiable, checker=a.checker, check_id=a.check_id,
        id_override=a.id_, seq=seq)
    if reasons:
        refuse(reasons)

    filename = "%04d-%s.json" % (seq, sanitize_filename(receipt["id"]))
    rel_path = "receipts/%s" % filename
    receipt_hash = canon_hash(receipt)
    prev_hash = entries[-1]["entry_hash"] if entries else GENESIS
    entry_core = {
        "seq": seq,
        "receipt_id": receipt["id"],
        "check_id": receipt["check_id"],
        "receipt_path": rel_path,
        "receipt_hash": receipt_hash,
        "prev_hash": prev_hash,
        "created_at": iso_now(),
    }
    entry = dict(entry_core, entry_hash=canon_hash(entry_core))

    save_receipt(root, run_id, rel_path, receipt)
    append_index_entry(root, run_id, entry)

    for name in redactions:
        print("REDACTED: %s (secret-shaped value replaced)" % name)
    print("receipt_id: %s" % receipt["id"])
    print("check_id: %s" % receipt["check_id"])
    print("seq: %d" % seq)
    print("receipt_path: %s" % rel_path)


def cmd_coverage(root, run_id, check_id):
    if not safe_run_id(run_id):
        refuse(["EVID-BAD-RUN-ID: run-id is not a safe identifier"])
    if not nestr(check_id):
        refuse(["EVID-BAD-CHECK-ID: --check-id missing/empty"])
    covered, errs = check_coverage(root, run_id, check_id)
    if errs:
        refuse(errs)
    if covered:
        print("COVERED: %s" % check_id)
        sys.exit(0)
    print("NOT-COVERED: %s" % check_id)
    sys.exit(1)


def cmd_validate_ledger(root, run_id):
    if not safe_run_id(run_id):
        refuse(["EVID-BAD-RUN-ID: run-id is not a safe identifier"])
    errs = validate_ledger(root, run_id)
    if errs:
        refuse(errs)
    print("VALID: ledger for run %s" % run_id)


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


def _run_cli(root, *args):
    return subprocess.run([sys.executable, os.path.abspath(__file__), *args, "--root", root],
                          capture_output=True, text=True)


H = "a" * 64
BIND = {"work_id": "W1", "plan_hash": H, "repo_hash": H, "verification_ref": "ver/report.md"}


def _mint(root, run_id, check_id, evidence_type="verification-report", artifact_ref="ver/report.md",
           extra=None):
    args = ["mint", "--run-id", run_id, "--check-id", check_id, "--evidence-type", evidence_type,
            "--artifact-ref", artifact_ref, "--work-id", BIND["work_id"], "--plan-hash", BIND["plan_hash"],
            "--repo-hash", BIND["repo_hash"], "--verification-ref", BIND["verification_ref"]]
    if extra:
        args += extra
    return _run_cli(root, *args)


def selftest():
    t = ST("evidence-ledger")
    before = _real_repo_porcelain()
    tmp = tempfile.mkdtemp(prefix="dmc-evid-")
    run_id = "dmc-run-selftest"

    try:
        # -- basic mint round-trip --------------------------------------------------------
        r1 = _mint(tmp, run_id, "C1")
        t.ok("E1 mint exit 0 + prints check_id/receipt_path", r1.returncode == 0
             and "check_id: C1" in r1.stdout and "receipt_path: receipts/" in r1.stdout)
        errs = validate_ledger(tmp, run_id)
        t.ok("E1b freshly-minted ledger validates clean (chain + receipt-hash cross-check)", errs == [])

        # -- all 5 evidence types mintable, distinct check_ids ----------------------------
        ok_all_types = True
        for i, et in enumerate(sorted(EVIDENCE_TYPES)):
            rr = _mint(tmp, run_id, "TYPE-%d" % i, evidence_type=et)
            ok_all_types = ok_all_types and rr.returncode == 0
        t.ok("E2 all 5 evidence_type values mintable", ok_all_types)

        # -- compatibility: minted receipt file ACCEPTED by the v0.6.2 gate (positive control) --
        entries = read_index_entries(tmp, run_id)
        rp = os.path.join(runs_dir(tmp), run_id, entries[0]["receipt_path"])
        cr = subprocess.run([sys.executable, V062_PATH, "validate", rp], capture_output=True, text=True)
        t.ok("E3 v0.6.2 gate ACCEPTS a ledger-minted receipt (compatibility control)",
             cr.returncode == 0 and "VALID" in cr.stdout)

        # -- coverage query ----------------------------------------------------------------
        r_cov = _run_cli(tmp, "coverage", "--run-id", run_id, "--check-id", "C1")
        t.ok("E4 coverage COVERED for a minted check_id (exit 0)",
             r_cov.returncode == 0 and "COVERED: C1" in r_cov.stdout)
        r_nocov = _run_cli(tmp, "coverage", "--run-id", run_id, "--check-id", "C-NEVER-MINTED")
        t.ok("E5 NEG coverage NOT-COVERED for an unminted check_id (exit 1)",
             r_nocov.returncode == 1 and "NOT-COVERED" in r_nocov.stdout)

        # -- NEGATIVE: no check_id (post-extension policy) --------------------------------
        r_nockid = _run_cli(tmp, "mint", "--run-id", run_id, "--evidence-type", "verification-report",
                            "--artifact-ref", "ver/x.md", "--work-id", BIND["work_id"],
                            "--plan-hash", BIND["plan_hash"], "--repo-hash", BIND["repo_hash"],
                            "--verification-ref", BIND["verification_ref"])
        t.ok("E6 NEG mint with no --check-id REFUSED exit 3 (EVID-CHECK-ID-REQUIRED)",
             r_nockid.returncode == 3 and "EVID-CHECK-ID-REQUIRED" in r_nockid.stdout)

        # -- NEGATIVE: secret-shaped value in a free-form field -> REDACTED, not persisted raw --
        secret = "ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        r_secret = _mint(tmp, run_id, "C-SECRET", extra=["--id", "id-" + secret])
        minted_ok = r_secret.returncode == 0 and "REDACTED: id" in r_secret.stdout
        entries2 = read_index_entries(tmp, run_id) if minted_ok else []
        last_rp = os.path.join(runs_dir(tmp), run_id, entries2[-1]["receipt_path"]) if entries2 else None
        body_text = open(last_rp, encoding="utf-8").read() if last_rp else ""
        t.ok("E7 NEG secret-shaped free-form field REDACTED (raw secret never persisted, mint succeeds)",
             minted_ok and secret not in body_text and REDACTED in body_text)

        # -- NEGATIVE: secret-shaped value in artifact_ref -> REFUSE (cannot redact a shaped field) --
        r_secret_ref = _mint(tmp, run_id, "C-SECRET-REF",
                              artifact_ref="runs/" + secret.replace("ghp_", "ghp_a"))
        t.ok("E8 NEG secret-shaped artifact_ref REFUSED exit 3 (EVID-SECRET-ARTIFACT-REF)",
             r_secret_ref.returncode == 3 and "EVID-SECRET-ARTIFACT-REF" in r_secret_ref.stdout)

        # -- NEGATIVE: broken hash-chain — rewritten line ----------------------------------
        ip = index_path(tmp, run_id)
        lines = open(ip, encoding="utf-8").read().splitlines()
        tampered = json.loads(lines[0])
        tampered["check_id"] = "TAMPERED"   # entry_hash now stale for this line
        lines_rewritten = [json.dumps(tampered)] + lines[1:]
        with open(ip, "w", encoding="utf-8") as f:
            f.write("\n".join(lines_rewritten) + "\n")
        errs_tamper = validate_ledger(tmp, run_id)
        t.ok("E9 NEG rewritten index line detected (EVID-CHAIN-TAMPER)",
             any(e.startswith("EVID-CHAIN-TAMPER") for e in errs_tamper))

        # -- NEGATIVE: broken hash-chain — dropped middle line -----------------------------
        with open(ip, "w", encoding="utf-8") as f:
            f.write("\n".join(lines) + "\n")   # restore
        lines_dropped = [lines[0]] + lines[2:]  # drop the 2nd entry entirely
        with open(ip, "w", encoding="utf-8") as f:
            f.write("\n".join(lines_dropped) + "\n")
        errs_drop = validate_ledger(tmp, run_id)
        t.ok("E10 NEG dropped index line detected (EVID-CHAIN-BROKEN or EVID-CHAIN-SEQ-GAP)",
             any(e.startswith(("EVID-CHAIN-BROKEN", "EVID-CHAIN-SEQ-GAP")) for e in errs_drop))
        with open(ip, "w", encoding="utf-8") as f:
            f.write("\n".join(lines) + "\n")   # restore for any later assertions

        # -- NEGATIVE: receipt file edited post-mint (hash cross-check) -------------------
        entries3 = read_index_entries(tmp, run_id)
        rp3 = os.path.join(runs_dir(tmp), run_id, entries3[-1]["receipt_path"])
        body3 = load_receipt(tmp, run_id, entries3[-1]["receipt_path"])
        body3["artifact_ref"] = "ver/edited-post-mint.md"
        with open(rp3, "w", encoding="utf-8") as f:
            f.write(json.dumps(body3, sort_keys=True, indent=2) + "\n")
        errs_edit = validate_ledger(tmp, run_id)
        t.ok("E11 NEG receipt file edited post-mint detected (EVID-RECEIPT-HASH-MISMATCH)",
             any(e.startswith("EVID-RECEIPT-HASH-MISMATCH") for e in errs_edit))

        # -- NEGATIVE: run-id path traversal refused ---------------------------------------
        r_trav = _run_cli(tmp, "coverage", "--run-id", "../../etc", "--check-id", "C1")
        t.ok("E12 NEG unsafe --run-id REFUSED exit 3 (EVID-BAD-RUN-ID)",
             r_trav.returncode == 3 and "EVID-BAD-RUN-ID" in r_trav.stdout)

        # -- env-independence: module reads no environment variables ----------------------
        # Tokens are split via concatenation so this check does not match its own source line.
        src = open(os.path.abspath(__file__), encoding="utf-8").read()
        env_tokens = ("os" + "." + "environ", "get" + "env" + "(")
        t.ok("E13 module never reads process environment variables (env-free by construction)",
             all(tok not in src for tok in env_tokens))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    after = _real_repo_porcelain()
    t.ok("E14 real repo git status --porcelain byte-identical before/after (or git absent)",
         before == after)
    t.done()


# ------------------------------------------------------------------------ main

def main():
    ap = argparse.ArgumentParser(prog="dmc-evidence-ledger")
    ap.add_argument("command", nargs="?", choices=["mint", "coverage"])
    ap.add_argument("--root", default=".")
    ap.add_argument("--run-id", dest="run_id")
    ap.add_argument("--work-id", dest="work_id")
    ap.add_argument("--plan-hash", dest="plan_hash")
    ap.add_argument("--repo-hash", dest="repo_hash")
    ap.add_argument("--verification-ref", dest="verification_ref")
    ap.add_argument("--evidence-type", dest="evidence_type")
    ap.add_argument("--artifact-ref", dest="artifact_ref")
    ap.add_argument("--machine-verifiable", dest="machine_verifiable", action="store_true")
    ap.add_argument("--checker", dest="checker")
    ap.add_argument("--check-id", dest="check_id")
    ap.add_argument("--id", dest="id_")
    ap.add_argument("--validate-ledger", action="store_true")
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args()

    if a.self_test:
        selftest()
        return

    if a.validate_ledger:
        if not a.run_id:
            die("--validate-ledger requires --run-id", 2)
        cmd_validate_ledger(os.path.abspath(a.root), a.run_id)
        return

    if not a.command:
        die("usage: dmc-evidence-ledger (mint ... | coverage --run-id ID --check-id ID) "
            "[--root DIR] | --validate-ledger --run-id ID | --self-test", 2)

    root = os.path.abspath(a.root)
    if not os.path.isdir(root):
        die("--root is not a directory: %s" % root, 2)
    if not a.run_id:
        die("%s requires --run-id" % a.command, 2)

    if a.command == "mint":
        cmd_mint(root, a.run_id, a)
    elif a.command == "coverage":
        cmd_coverage(root, a.run_id, a.check_id)


if __name__ == "__main__":
    main()
