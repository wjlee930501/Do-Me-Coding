#!/usr/bin/env python3
"""dmc-delegation.py — DMC v1.0 delegation-record validator + runtime records pipeline
(P14 records: M5 schema-check, DMC-T010c; M7 append/check runtime chain, DMC-T012.3).

Validates a single `dmc.delegation.v1` delegation record (see `.harness/schemas/delegation.schema.md`)
— subject-binding fields, `capability_class` enum, `role` resolution against
`orchestration/roles.json`, the `depth <= max_depth` recursion bound, the `may_mutate` / scope-lock
rule, and the `validation_verdict` consumption gate — and, as of M7, chain-appends and
chain-verifies the per-run `delegations.jsonl` runtime record log.

SCOPE: this module ships BOTH halves of P14 now. `validate` is the read-only SCHEMA check
(unchanged since M5): callable against any single delegation-record JSON document, it never
appends, mutates, or writes anything. `append` and `check` (M7) are the delegation *runtime
records pipeline* the M5 docstring deferred: `append` is the ONLY subcommand that writes, and it
writes exactly one JSONL line to an already-existing run's `.harness/runs/<RUN_ID>/delegations.jsonl`
(append-only, hash-chained); `check` re-validates and re-verifies that file end-to-end and is
itself read-only.

Subcommands:
  validate <path> [--registry PATH]   fail-closed record validator. ACCEPT => exit 0,
                                       REFUSE => exit 3 (usage error => exit 2). `--registry`
                                       overrides the roles.json path used for role resolution
                                       (default: orchestration/roles.json under the repo root, via
                                       bin/lib/dmc-roles.py's own default).
  append --run RUN_ID RECORD.json [--registry PATH]
                                       fail-closed: full `validate_delegation()` first, then
                                       chain-append RECORD.json as one line to
                                       `.harness/runs/RUN_ID/delegations.jsonl` (RUN_ID's run
                                       directory must already exist). The record's `prev_hash`
                                       must equal the sha256 of the previous line's exact bytes
                                       (terminating LF excluded) or the literal `genesis` when the
                                       file is absent/empty. For `may_mutate: true` records,
                                       `scope_lock_ref` must additionally resolve to an existing,
                                       parseable `scope.lock.json` whose `run_id` matches RUN_ID
                                       (closes the scope-lock judgment call below). ACCEPT => exit
                                       0, REFUSE => exit 3 (nothing is written on refusal).
  check --run RUN_ID [--registry PATH]
                                       read-only: re-validates every line of
                                       `.harness/runs/RUN_ID/delegations.jsonl` (schema +
                                       validate-before-consumption) and re-verifies the prev_hash
                                       chain end-to-end. PASS => exit 0, REFUSE => exit 3 (a
                                       missing chain file is a REFUSE, not a vacuous pass).
  --self-test                         embedded section self-test (prints
                                       "[delegation] N PASS / M FAIL"); exit 0 all-pass / 1 any-fail.

House rules (v0.6.x / M3-M5 lineage, mirrors bin/lib/dmc-instance-validate.py and
bin/lib/dmc-roles.py): stdlib-only, env-independent (no env reads), offline (no network; git is
invoked only best-effort, read-only, for the self-test's own hermeticity check, with a no-git
fallback), input-only (`validate`/`check` only read named files; `append` writes exactly the one
named JSONL append, nothing else), value-blind (refusals name schema constants/reason codes, never
the document's content values), duplicate-JSON-key rejecting, secret-path refused by path,
secret-shaped field *content* also refused, fail-closed with named reason codes and negative
controls. Advisory tier: the runtime enforcement floor stays the hooks.

Role resolution (composition with T010a): `role` resolution is delegated entirely to
`python3 bin/lib/dmc-roles.py lookup <role>` as a read-only subprocess, per that module's
documented lookup contract — exit 0 + a JSON role record on stdout means the role resolves; exit 3
(unknown role, or an unreadable/invalid registry) means it does not. This module NEVER opens or
parses `orchestration/roles.json` itself; every fact about a role (whether it resolves at all, and
whether the registry marks it mutation-capable) is read from the subprocess's own JSON output.
Fail-closed composition: any subprocess anomaly this module cannot positively confirm as "exit 0
with a well-formed JSON object" — a non-zero exit, a missing/unreadable registry, a spawn failure,
a timeout, or malformed stdout — is treated identically to "does not resolve" (REFUSE), never
silently ignored or treated as a pass.

Judgment call — the scope-lock reference field (M5, closed at M7): `delegation.schema.md`'s
illustrative JSON block does not name a distinct field for "an active scope.lock reference" (the
prose rule only says a mutation-capable dispatch requires one; the schema and its M3 authors are
out of this task's edit scope). This validator names that field `scope_lock_ref` — a non-null,
non-empty string identifying the run's `scope.lock.json` (schema `dmc.scope-lock.v1`; see
`bin/lib/dmc-scope-lock.py`, whose `REQUIRED_FIELDS` include `run_id` and `state_hash` as the
natural handles such a reference would name) — and requires it whenever `may_mutate: true`.
`validate_delegation()` (used by `validate`, and by `append`/`check` as their first gate) still
checks only that the reference is present and non-empty (a schema-shape check) — it never opens a
file, so it stays usable against a bare record with no run context. `append` closes the deeper
content tier `validate_delegation()` cannot reach: for a `may_mutate: true` record it additionally
resolves `scope_lock_ref` to a real file (path-like ref => that path, resolved relative to the
repo root; anything else => the run's own default `.harness/runs/<RUN_ID>/scope.lock.json`) and
requires that file to exist, parse as JSON, and carry a `run_id` equal to `--run`. This is
existence + parse + run_id binding ONLY — it does not cross-validate the referenced lock's own
schema (`bin/lib/dmc-scope-lock.py --validate`'s tamper/hash checks) or confirm the delegated
record's own paths sit inside that lock's `files[]`; that deeper semantic equivalence stays a
disclosed non-goal (M9+).
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

# The artifact this validator certifies (in-tool contract id).
SCHEMA_ID = "dmc.delegation.v1"

# The six capability classes (docs/ORCHESTRATION_TAXONOMY.md Output 2 / v0.6.1 enum; same set
# dmc-roles.py enforces on the registry). Kept as a local literal (each M5 validator is standalone).
CAPABILITY_CLASSES = (
    "frontier-long-horizon",
    "standard-implementation",
    "cheap-fast",
    "adversarial-review",
    "deterministic-tool",
    "human-only-gate",
)

VALIDATION_VERDICTS = ("PASS", "FAIL", "PENDING")

GENESIS = "genesis"
HASH_RE = re.compile(r"^[0-9a-f]{16,}$")

# Value-blind reject-on-match set (copied verbatim from bin/lib/dmc-v0.6.1.0-trace-linkage.py's
# UNSAFE, per the established house convention — e.g. bin/lib/dmc-approvals.py, bin/lib/dmc-fixloop.py
# — so a secret-shaped field in a delegation record is refused with the same semantics as elsewhere).
UNSAFE = re.compile(
    r'sk-[A-Za-z0-9_-]{16,}|AKIA[0-9A-Z]{8,}|(?:BEGIN|END)[A-Z ]*PRIVATE KEY|xox[baprs]-[A-Za-z0-9-]{6,}'
    r'|gh[opsu]_[A-Za-z0-9]{16,}|github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{16,}|npm_[A-Za-z0-9]{30,}'
    r'|AIza[0-9A-Za-z_-]{20,}|dop_v1_[A-Za-z0-9]{32,}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'
    r'|ya29\.[A-Za-z0-9_-]{10,}|AccountKey=[A-Za-z0-9+/=]{20,}|Bearer\s+[A-Za-z0-9._-]{12,}'
    r'|(?:password|api_key|client_secret|aws_secret_access_key)\s*=\s*\S+|[A-Za-z0-9_-]*_token\s*[=:]\s*\S+'
)


# ------------------------------------------------------------------- helpers

def die(msg, code=2):
    sys.stderr.write("dmc-delegation: %s\n" % msg)
    sys.exit(code)


def refuse(reasons):
    for r in reasons:
        print("REFUSED: %s" % r)
    sys.exit(3)


def is_secret_path(path):
    """Path-only secret filter (mirror of DMC.md secret patterns). Never opens the file."""
    base = os.path.basename(path).lower()
    parts = [p.lower() for p in path.replace(os.sep, "/").split("/")]
    if base in {".env.example", ".env.sample", ".env.template", ".env.dist"}:
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


def read_text(path):
    if is_secret_path(path):
        die("refused: secret-shaped target path", 3)
    with open(path, "r", encoding="utf-8", errors="strict") as f:
        return f.read()


def _no_dup(pairs):
    """object_pairs_hook that rejects duplicate JSON keys (fail-closed on ambiguity)."""
    d = {}
    for k, v in pairs:
        if k in d:
            raise ValueError("duplicate JSON key: %r" % k)
        d[k] = v
    return d


def load_json_text(text):
    """Parse record JSON text, rejecting duplicate keys. Raises ValueError on malformed input."""
    return json.loads(text, object_pairs_hook=_no_dup)


def repo_root():
    return os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                         "..", ".."))


def _nestr(x):
    """Non-empty single-line string."""
    return isinstance(x, str) and x != "" and "\n" not in x


def _is_int(x):
    """A real int, not a bool (bool is a subclass of int in Python)."""
    return isinstance(x, int) and not isinstance(x, bool)


def _scan_unsafe(obj):
    """Recursive value-blind secret scan (reject-on-match); mirrors the copied UNSAFE validators."""
    if isinstance(obj, dict):
        for k, v in obj.items():
            if isinstance(k, str) and UNSAFE.search(k):
                return True
            if _scan_unsafe(v):
                return True
    elif isinstance(obj, list):
        for x in obj:
            if _scan_unsafe(x):
                return True
    elif isinstance(obj, str):
        if UNSAFE.search(obj):
            return True
    return False


# --------------------------------------------------------------- role resolution (subprocess)

def roles_script_path():
    """The dmc-roles.py module, resolved by file location (not cwd, not PATH)."""
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), "dmc-roles.py")


def resolve_role(role_key, registry_path=None):
    """Resolve `role_key` via the `dmc-roles.py lookup` subprocess (read-only, fail-closed).

    Returns (resolved: bool, record: dict|None). `resolved` is True only on a clean subprocess
    exit 0 whose stdout parses as a JSON object; every other outcome (exit 3, a spawn failure, a
    timeout, or malformed stdout) returns (False, None) — fail-closed, never a silent pass.
    """
    script = roles_script_path()
    cmd = [sys.executable or "python3", script, "lookup", role_key]
    if registry_path:
        cmd = cmd + ["--registry", registry_path]
    try:
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              timeout=10, check=False)
    except (OSError, subprocess.SubprocessError, ValueError):
        return False, None
    if proc.returncode != 0:
        return False, None
    try:
        record = json.loads(proc.stdout.decode("utf-8", errors="strict"))
    except (ValueError, UnicodeError):
        return False, None
    if not isinstance(record, dict):
        return False, None
    return True, record


# --------------------------------------------------------------- validate

def validate_delegation(obj, registry_path=None):
    """Return a list of value-blind reason codes; empty list == ACCEPT."""
    if not isinstance(obj, dict):
        return ["DELEG-NOT-OBJECT: top-level document is not a JSON object"]

    errs = []

    if obj.get("schema") != SCHEMA_ID:
        errs.append("DELEG-BAD-SCHEMA: 'schema' must be %r" % SCHEMA_ID)

    # Secret-shaped content refusal (value-blind; whole-document scan of keys and string values).
    if _scan_unsafe(obj):
        errs.append("DELEG-SECRET-SHAPED: a secret-shaped value is present (value-blind)")

    # Subject-binding fields: work_id non-empty; plan_hash/repo_hash hash-shaped (hex >=16).
    if not _nestr(obj.get("work_id")):
        errs.append("DELEG-MISSING-BINDING: work_id missing/empty")
    for hk in ("plan_hash", "repo_hash"):
        v = obj.get(hk)
        if not (isinstance(v, str) and HASH_RE.match(v)):
            errs.append("DELEG-BAD-HASH: %s not hash-shaped (hex>=16)" % hk)

    if not _nestr(obj.get("delegation_id")):
        errs.append("DELEG-FIELD-MISSING: delegation_id missing/empty")

    # capability_class: required, then must be in the six-class enum.
    cclass = obj.get("capability_class")
    if not _nestr(cclass):
        errs.append("DELEG-FIELD-MISSING: capability_class missing/empty")
    elif cclass not in CAPABILITY_CLASSES:
        errs.append("DELEG-BAD-CLASS: capability_class not in the six-class enum")

    # may_mutate must be a bool.
    may_mutate = obj.get("may_mutate")
    if not isinstance(may_mutate, bool):
        errs.append("DELEG-MUTATE-NOT-BOOL: may_mutate must be a bool")

    # role: required, then must resolve in orchestration/roles.json via the lookup subprocess.
    role = obj.get("role")
    resolved, role_record = False, None
    if not _nestr(role):
        errs.append("DELEG-ROLE-MISSING: role missing/empty")
    else:
        resolved, role_record = resolve_role(role, registry_path)
        if not resolved:
            errs.append("DELEG-ROLE-UNRESOLVED: role does not resolve in orchestration/roles.json")

    # may_mutate:true rule: only a registry-mutation-capable role, and only under a scope-lock ref.
    if may_mutate is True:
        if not (resolved and isinstance(role_record, dict) and role_record.get("may_mutate") is True):
            errs.append("DELEG-ILLEGAL-MUTATOR: may_mutate:true but the resolved role is not "
                        "mutation-capable per orchestration/roles.json")
        if not _nestr(obj.get("scope_lock_ref")):
            errs.append("DELEG-NO-SCOPE-LOCK: may_mutate:true requires a non-empty scope_lock_ref")

    # depth / max_depth: ints; depth >= 0; max_depth >= 1; depth <= max_depth.
    depth = obj.get("depth")
    max_depth = obj.get("max_depth")
    depth_ok = _is_int(depth) and depth >= 0
    max_depth_ok = _is_int(max_depth) and max_depth >= 1
    if not depth_ok:
        errs.append("DELEG-BAD-DEPTH: depth must be an int >= 0")
    if not max_depth_ok:
        errs.append("DELEG-BAD-MAX-DEPTH: max_depth must be an int >= 1")
    if depth_ok and max_depth_ok and depth > max_depth:
        errs.append("DELEG-DEPTH-EXCEEDS-MAX: depth > max_depth")

    # validation_verdict enum.
    verdict = obj.get("validation_verdict")
    if verdict not in VALIDATION_VERDICTS:
        errs.append("DELEG-BAD-VERDICT: validation_verdict not in PASS|FAIL|PENDING")

    # artifact_ref / artifact_schema: each null or a non-empty string; paired presence; consumption
    # (artifact_ref present) requires validation_verdict == PASS.
    artifact_ref = obj.get("artifact_ref")
    artifact_schema = obj.get("artifact_schema")
    ref_present = artifact_ref is not None
    schema_present = artifact_schema is not None
    if ref_present and not _nestr(artifact_ref):
        errs.append("DELEG-BAD-ARTIFACT-REF: artifact_ref must be null or a non-empty string")
    if schema_present and not _nestr(artifact_schema):
        errs.append("DELEG-BAD-ARTIFACT-SCHEMA: artifact_schema must be null or a non-empty string")
    if ref_present and not schema_present:
        errs.append("DELEG-ARTIFACT-SCHEMA-MISSING: artifact_ref present but artifact_schema is null")
    if schema_present and not ref_present:
        errs.append("DELEG-ARTIFACT-REF-ORPHAN-SCHEMA: artifact_schema present but artifact_ref is null")
    if ref_present and verdict != "PASS":
        errs.append("DELEG-UNVALIDATED-CONSUMPTION: artifact_ref present (consumption) but "
                    "validation_verdict != PASS")

    # prev_hash: hex>=16 or the literal 'genesis'.
    pv = obj.get("prev_hash")
    if not (isinstance(pv, str) and (pv == GENESIS or HASH_RE.match(pv))):
        errs.append("DELEG-BAD-PREV-HASH: prev_hash not hash-shaped (hex>=16 or genesis)")

    return errs


def load_delegation_record(path):
    """Read + parse a delegation-record file (secret-path guard inside `read_text`; die(3) on
    secret shape — identical to the pre-M7 `validate_file` behavior). Returns (obj, errs): errs
    is `["DELEG-UNREADABLE: ..."]` and obj is None on a parse failure (malformed JSON or a
    duplicate key); otherwise errs is `[]` and obj is the parsed document."""
    text = read_text(path)
    try:
        return load_json_text(text), []
    except ValueError as e:
        return None, ["DELEG-UNREADABLE: %s" % e]


def validate_file(path, registry_path=None):
    """Load + validate a delegation-record file. Returns a list of reason codes (empty == ACCEPT)."""
    obj, errs = load_delegation_record(path)
    if errs:
        return errs
    return validate_delegation(obj, registry_path)


# --------------------------------------------------------------- append / check (M7, DMC-T012.3)

def _harness_runs_dir(root):
    return os.path.join(root, ".harness", "runs")


def _delegations_path(root, run_id):
    return os.path.join(_harness_runs_dir(root), run_id, "delegations.jsonl")


def _default_scope_lock_path(root, run_id):
    return os.path.join(_harness_runs_dir(root), run_id, "scope.lock.json")


def resolve_scope_lock_ref(root, run_id, ref):
    """Resolve a (schema-validated, non-empty-string) `scope_lock_ref` to a filesystem path.

    Explicit resolution rule (closes the docstring's M5 judgment call at the content tier): a
    path-like ref (contains a `/` or ends in `.json`) IS the path, resolved relative to `root`
    unless already absolute; anything else (a bare token) resolves to the run's own default
    `.harness/runs/<run_id>/scope.lock.json`. Path-only — never opens the file.
    """
    if not isinstance(ref, str) or not ref:
        return None
    # Path-traversal guard (B2, defense-in-depth): reject a ref whose path form carries a
    # parent-directory ('..') SEGMENT BEFORE any os.path.join(root, ref), so a relative ref can
    # never escape `root`. Segment-based, not substring: a filename like '..foo.json' is fine.
    # Reject ONLY '..' segments — an absolute, '..'-free ref (A3/A7/A8) still resolves below.
    if ".." in ref.replace(os.sep, "/").split("/"):
        return None
    looks_like_path = ("/" in ref) or ref.endswith(".json")
    if looks_like_path:
        return ref if os.path.isabs(ref) else os.path.join(root, ref)
    return _default_scope_lock_path(root, run_id)


def _load_json_path_safe(path):
    """Read + parse a JSON document at `path` WITHOUT ever exiting the process (unlike
    `read_text`/`die`) — needed so `append`'s core logic stays a pure, self-test-callable
    function. Returns (obj, reason): reason is None on success; obj is None and reason is a
    single value-blind `DELEG-*` string on any failure (secret-shaped path, missing/unreadable
    file, malformed/duplicate-key JSON)."""
    if is_secret_path(path):
        return None, "DELEG-SCOPE-LOCK-SECRET-PATH: refused: scope_lock_ref target is secret-shaped"
    try:
        with open(path, "r", encoding="utf-8", errors="strict") as f:
            text = f.read()
    except (OSError, UnicodeError):
        return None, "DELEG-SCOPE-LOCK-UNREADABLE: scope_lock_ref target could not be opened"
    try:
        return load_json_text(text), None
    except ValueError:
        return None, "DELEG-SCOPE-LOCK-UNREADABLE: scope_lock_ref target is not parseable JSON"


def _chain_tip_hash(deleg_path):
    """The expected `prev_hash` for the NEXT appended record.

    = sha256(hex) of the delegations.jsonl file's LAST line's exact bytes, with the terminating
    LF EXCLUDED (the newline is the JSONL record separator, not part of the hashed record, so an
    externally-authored record can compute this value without reading this file's own trailing-
    newline convention — Rev 2/A4a) — or the literal 'genesis' when the file is absent or empty.
    """
    if not os.path.isfile(deleg_path):
        return GENESIS
    with open(deleg_path, "rb") as f:
        content = f.read()
    lines = content.split(b"\n")
    if lines and lines[-1] == b"":
        lines = lines[:-1]              # trailing LF produces one empty trailing element; drop it
    if not lines:
        return GENESIS
    return hashlib.sha256(lines[-1]).hexdigest()   # LF EXCLUDED from the hashed bytes


def append_delegation_record(root, run_id, record_path, registry_path=None):
    """Core, non-exiting `append` logic. Returns (ok, reasons): ok=True (reasons==[]) iff the
    record schema-validates AND chains cleanly onto the run's `delegations.jsonl`, in which case
    exactly one line has been appended. On ok=False, reasons is a non-empty list of value-blind
    `DELEG-*` codes and NOTHING has been written (fail-closed, side-effect-free refusal)."""
    obj, errs = load_delegation_record(record_path)
    if errs:
        return False, errs
    errs = validate_delegation(obj, registry_path)
    if errs:
        return False, errs

    run_dir = os.path.join(_harness_runs_dir(root), run_id)
    if not os.path.isdir(run_dir):
        return False, ["DELEG-NO-RUN: run directory does not exist: .harness/runs/%s" % run_id]

    # scope_lock_ref content tier (may_mutate:true only) — validate_delegation() already required
    # a non-empty string; here we additionally require it to resolve to a real, parseable
    # scope.lock.json whose run_id binds to THIS --run.
    if obj.get("may_mutate") is True:
        lock_path = resolve_scope_lock_ref(root, run_id, obj.get("scope_lock_ref"))
        if lock_path is None:
            return False, ["DELEG-SCOPE-LOCK-TRAVERSAL: may_mutate:true scope_lock_ref path form "
                           "contains a parent-directory ('..') traversal segment (value-blind)"]
        if not os.path.isfile(lock_path):
            return False, ["DELEG-SCOPE-LOCK-UNRESOLVED: may_mutate:true scope_lock_ref does not "
                           "resolve to an existing file"]
        lock_obj, reason = _load_json_path_safe(lock_path)
        if reason:
            return False, [reason]
        if not isinstance(lock_obj, dict) or lock_obj.get("run_id") != run_id:
            return False, ["DELEG-SCOPE-LOCK-RUN-MISMATCH: scope_lock_ref's run_id does not match "
                           "--run"]

    deleg_path = _delegations_path(root, run_id)
    expected_prev = _chain_tip_hash(deleg_path)
    if obj.get("prev_hash") != expected_prev:
        return False, ["DELEG-CHAIN-BREAK: prev_hash does not match sha256 of the previous "
                       "record's line bytes (LF excluded), or 'genesis' when the chain file is "
                       "absent/empty"]

    line = json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    with open(deleg_path, "a", encoding="utf-8") as f:
        f.write(line + "\n")
    return True, []


def check_delegation_chain(root, run_id, registry_path=None):
    """Core, non-exiting `check` logic. Returns (ok, reasons, count): ok=True (reasons==[]) iff
    the chain file exists, every line parses (duplicate-key rejecting) and independently
    schema-validates (`validate_delegation`, which already enforces validate-before-consumption
    via DELEG-UNVALIDATED-CONSUMPTION), and the prev_hash chain is unbroken end-to-end (each
    line's prev_hash == sha256 of the PRIOR line's exact bytes, LF excluded; the first line's
    prev_hash == 'genesis'). `count` is the number of records checked (0 on early failure)."""
    deleg_path = _delegations_path(root, run_id)
    if not os.path.isfile(deleg_path):
        return False, ["DELEG-NO-CHAIN: .harness/runs/%s/delegations.jsonl does not exist"
                       % run_id], 0
    with open(deleg_path, "rb") as f:
        content = f.read()
    lines = content.split(b"\n")
    if lines and lines[-1] == b"":
        lines = lines[:-1]
    expected_prev = GENESIS
    for i, line_bytes in enumerate(lines):
        try:
            text = line_bytes.decode("utf-8", errors="strict")
            obj = load_json_text(text)
        except (ValueError, UnicodeError):
            return False, ["DELEG-UNREADABLE: line %d is not parseable JSON (or has a duplicate "
                           "key)" % i], i
        errs = validate_delegation(obj, registry_path)
        if errs:
            return False, errs, i
        if obj.get("prev_hash") != expected_prev:
            return False, ["DELEG-CHAIN-BREAK: line %d prev_hash does not match the running hash "
                           "chain" % i], i
        expected_prev = hashlib.sha256(line_bytes).hexdigest()
    return True, [], len(lines)


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
        except Exception as e:  # noqa: BLE001 — a broken fixture must FAIL, never abort the run
            self.ok("%s [EXC:%s]" % (label, e.__class__.__name__), False)
            return

        self.ok(label, cond)

    def done(self):
        print("[%s] %d PASS / %d FAIL" % (self.name, self.passed, self.failed))
        sys.exit(0 if self.failed == 0 else 1)


def _base_record(**overrides):
    """A full, valid base delegation record (role=verifier, read-only, no artifact). Every
    negative-control fixture mutates a copy of this."""
    rec = {
        "schema": SCHEMA_ID,
        "work_id": "self-test-work-id",
        "plan_hash": "a" * 16,
        "repo_hash": "b" * 16,
        "delegation_id": "deleg-0001",
        "role": "verifier",
        "capability_class": "deterministic-tool",
        "may_mutate": False,
        "depth": 0,
        "max_depth": 3,
        "artifact_ref": None,
        "artifact_schema": None,
        "validation_verdict": "PENDING",
        "prev_hash": GENESIS,
    }
    rec.update(overrides)
    return rec


def _write(td, obj, name="delegation.json"):
    p = os.path.join(td, name)
    with open(p, "w", encoding="utf-8") as f:
        f.write(json.dumps(obj))
    return p


def _git_status_snapshot(root):
    """Best-effort `git status --porcelain` snapshot for the hermeticity check; None if git is
    unavailable (the check then degrades to a no-op pass — the same no-git fallback used elsewhere
    in this codebase, e.g. bin/lib/dmc-acceptance.py's repo_hash())."""
    git = shutil.which("git")
    if not git:
        return None
    try:
        r = subprocess.run([git, "-C", root, "status", "--porcelain"],
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=10)
        if r.returncode != 0:
            return None
        return r.stdout
    except (OSError, subprocess.SubprocessError):
        return None


def selftest():
    t = ST("delegation")
    root = repo_root()
    git_before = _git_status_snapshot(root)

    with tempfile.TemporaryDirectory() as td:
        # ---- positive controls ----

        # D0: a valid read-only (verifier) dispatch, resolved against the REAL orchestration/roles.json.
        t.check("D0 valid read-only dispatch (role=verifier) ACCEPTED (real registry, positive control)",
                lambda: validate_delegation(_base_record()) == [])

        # D1: a valid executor (mutation-capable) dispatch under a scope-lock reference.
        t.check("D1 valid executor dispatch (may_mutate:true + scope_lock_ref) ACCEPTED",
                lambda: validate_delegation(_base_record(
                    role="implementer", capability_class="standard-implementation",
                    may_mutate=True, scope_lock_ref=".harness/runs/self-test/scope.lock.json",
                )) == [])

        # D2: a valid consumption record (artifact_ref + artifact_schema + validation_verdict PASS).
        t.check("D2 valid consumption record (artifact_ref + PASS) ACCEPTED",
                lambda: validate_delegation(_base_record(
                    artifact_ref=".harness/artifacts/self-test.json",
                    artifact_schema="dmc.self-test.v1", validation_verdict="PASS",
                )) == [])

        # D3: full-pipeline check (read_text -> parse -> validate) via a real tempdir file.
        t.check("D3 full-pipeline validate_file() on a valid fixture ACCEPTED",
                lambda: validate_file(_write(td, _base_record())) == [])

        # ---- plan-mandated negative controls (must REFUSE) ----

        # N1: role absent from the registry.
        t.check("N1 negative control: role absent from roles.json REFUSED",
                lambda: any(e.startswith("DELEG-ROLE-UNRESOLVED")
                            for e in validate_delegation(_base_record(role="frobnicator-nonexistent"))))

        # N2: may_mutate:true with no scope-lock reference (role IS mutation-capable).
        t.check("N2 negative control: may_mutate:true with no scope-lock reference REFUSED",
                lambda: any(e.startswith("DELEG-NO-SCOPE-LOCK")
                            for e in validate_delegation(_base_record(
                                role="implementer", capability_class="standard-implementation",
                                may_mutate=True))))

        # N3: depth > max_depth.
        t.check("N3 negative control: depth > max_depth REFUSED",
                lambda: any(e.startswith("DELEG-DEPTH-EXCEEDS-MAX")
                            for e in validate_delegation(_base_record(depth=5, max_depth=3))))

        # N4: consumption recorded with validation_verdict != PASS (both FAIL and PENDING variants).
        for bad_verdict in ("FAIL", "PENDING"):
            t.check("N4 negative control: consumption with validation_verdict=%s REFUSED" % bad_verdict,
                    lambda v=bad_verdict: any(
                        e.startswith("DELEG-UNVALIDATED-CONSUMPTION")
                        for e in validate_delegation(_base_record(
                            artifact_ref=".harness/artifacts/x.json",
                            artifact_schema="dmc.x.v1", validation_verdict=v))))

        # ---- house-style hardening negative controls ----

        # N5: missing subject-binding field.
        def no_work_id():
            o = _base_record()
            del o["work_id"]
            return o
        t.check("N5 negative control: missing binding field (work_id) REFUSED",
                lambda: any(e.startswith("DELEG-MISSING-BINDING") for e in validate_delegation(no_work_id())))

        # N6: bad enum (capability_class outside the six-class enum).
        t.check("N6 negative control: capability_class outside enum REFUSED",
                lambda: any(e.startswith("DELEG-BAD-CLASS")
                            for e in validate_delegation(_base_record(capability_class="super-frontier"))))

        # N7: tampered/duplicate JSON key at parse time.
        def dup_key_path():
            p = os.path.join(td, "dup-key.json")
            with open(p, "w", encoding="utf-8") as f:
                f.write('{"schema":"dmc.delegation.v1","schema":"x"}')
            return p
        t.check("N7 negative control: duplicate JSON key REFUSED",
                lambda: any(e.startswith("DELEG-UNREADABLE") for e in validate_file(dup_key_path())))

        # N8: secret-shaped field content.
        t.check("N8 negative control: secret-shaped field content REFUSED",
                lambda: any(e.startswith("DELEG-SECRET-SHAPED")
                            for e in validate_delegation(_base_record(
                                delegation_id="sk-abcdefghijklmnopqrstuvwxyz"))))

        # N9: an illegal mutator (may_mutate:true on a non-mutation-capable role).
        t.check("N9 negative control: may_mutate:true on non-executor role REFUSED",
                lambda: any(e.startswith("DELEG-ILLEGAL-MUTATOR")
                            for e in validate_delegation(_base_record(role="verifier", may_mutate=True))))

        # N10: bad hash shape.
        t.check("N10 negative control: plan_hash not hex REFUSED",
                lambda: any(e.startswith("DELEG-BAD-HASH")
                            for e in validate_delegation(_base_record(plan_hash="not-hex"))))

        # N11: bad prev_hash shape.
        t.check("N11 negative control: prev_hash not hex/genesis REFUSED",
                lambda: any(e.startswith("DELEG-BAD-PREV-HASH")
                            for e in validate_delegation(_base_record(prev_hash="not-a-hash"))))

        # N12: wrong schema id.
        t.check("N12 negative control: wrong schema id REFUSED",
                lambda: any(e.startswith("DELEG-BAD-SCHEMA")
                            for e in validate_delegation(_base_record(schema="dmc.delegation.v2"))))

        # N13: may_mutate not a bool.
        t.check("N13 negative control: may_mutate not bool REFUSED",
                lambda: any(e.startswith("DELEG-MUTATE-NOT-BOOL")
                            for e in validate_delegation(_base_record(may_mutate="true"))))

        # N14: bad depth (negative).
        t.check("N14 negative control: negative depth REFUSED",
                lambda: any(e.startswith("DELEG-BAD-DEPTH")
                            for e in validate_delegation(_base_record(depth=-1))))

        # N15: bad max_depth (< 1).
        t.check("N15 negative control: max_depth < 1 REFUSED",
                lambda: any(e.startswith("DELEG-BAD-MAX-DEPTH")
                            for e in validate_delegation(_base_record(max_depth=0))))

        # N16: bad validation_verdict value.
        t.check("N16 negative control: bad validation_verdict value REFUSED",
                lambda: any(e.startswith("DELEG-BAD-VERDICT")
                            for e in validate_delegation(_base_record(validation_verdict="MAYBE"))))

        # N17: artifact_ref present, artifact_schema null (orphan ref).
        t.check("N17 negative control: artifact_ref without artifact_schema REFUSED",
                lambda: any(e.startswith("DELEG-ARTIFACT-SCHEMA-MISSING")
                            for e in validate_delegation(_base_record(
                                artifact_ref=".harness/artifacts/x.json", validation_verdict="PASS"))))

        # N18: artifact_schema present, artifact_ref null (orphan schema).
        t.check("N18 negative control: artifact_schema without artifact_ref REFUSED",
                lambda: any(e.startswith("DELEG-ARTIFACT-REF-ORPHAN-SCHEMA")
                            for e in validate_delegation(_base_record(artifact_schema="dmc.x.v1"))))

        # N19: role field missing entirely.
        def no_role():
            o = _base_record()
            del o["role"]
            return o
        t.check("N19 negative control: role field missing REFUSED",
                lambda: any(e.startswith("DELEG-ROLE-MISSING") for e in validate_delegation(no_role())))

        # N20: fail-closed on a broken/unreadable registry (composition failure mode, not just an
        # unresolved role name) — a role that WOULD resolve against the real registry is still
        # REFUSED when --registry points at a nonexistent path, proving the subprocess composition
        # fails closed rather than silently falling back to some other resolution path.
        bad_registry = os.path.join(td, "does-not-exist", "roles.json")
        t.check("N20 negative control: broken registry path -> role resolution fails closed",
                lambda: any(e.startswith("DELEG-ROLE-UNRESOLVED")
                            for e in validate_delegation(_base_record(role="verifier"), bad_registry)))

        # N21: determinism — identical input yields identical reason list.
        dupd = dict(_base_record(role="frobnicator-nonexistent"))
        t.ok("N21 determinism: identical input -> identical reason list",
             validate_delegation(dupd) == validate_delegation(dict(dupd)))

        # N22: not-an-object top-level document.
        t.ok("N22 negative control: top-level non-object REFUSED",
             any(e.startswith("DELEG-NOT-OBJECT") for e in validate_delegation(["not", "an", "object"])))

    # N23: secret-shaped path filter (never opens the file).
    t.ok("N23 secret-shaped path filter",
         is_secret_path("orchestration/.env") and is_secret_path("x/id_rsa")
         and not is_secret_path("orchestration/roles.json"))

    # N23b: service-account*.json refused by is_secret_path (B1 — the 11th sibling branch, verbatim
    # from bin/lib/dmc-approvals.py, that this tool was the sole one of 11 missing).
    t.ok("N23b service-account json refused by is_secret_path (B1)",
         is_secret_path("deploy/my-service-account.json")
         and is_secret_path("service-account.json")
         and not is_secret_path("orchestration/roles.json"))

    # B2: a scope_lock_ref whose path form carries a '..' SEGMENT is rejected (returns None) BEFORE
    # the join, while a '..'-free absolute ref still resolves — path-only, no filesystem access.
    t.ok("B2 scope_lock_ref '..' traversal rejected; absolute ref still resolves",
         resolve_scope_lock_ref(root, "r", "../evil.lock.json") is None
         and resolve_scope_lock_ref(root, "r", "a/../b.json") is None
         and resolve_scope_lock_ref(root, "r", "/abs/scope.lock.json") == "/abs/scope.lock.json")

    # ---- M7 runtime-records pipeline: append / check (DMC-T012.3) ----
    # Hermetic: an entirely synthetic repo root under TemporaryDirectory() with its own
    # .harness/runs/<run_id>/ subdirectories — never the live .harness/runs/dmc-run-92b7f126f79d/.
    with tempfile.TemporaryDirectory() as ar:
        RUN = "self-test-run"
        run_dir = os.path.join(ar, ".harness", "runs", RUN)
        os.makedirs(run_dir)
        deleg_path = os.path.join(run_dir, "delegations.jsonl")

        def _nlines():
            return len(open(deleg_path, "rb").read().splitlines())

        # A1 (positive): genesis append onto an absent chain file succeeds; exactly 1 line written.
        rec1 = _write(ar, _base_record(delegation_id="deleg-a1"), name="rec1.json")
        ok1, reasons1 = append_delegation_record(ar, RUN, rec1)
        t.ok("A1 append: genesis record onto an absent chain file ACCEPTED (file created, 1 line)",
             ok1 and reasons1 == [] and os.path.isfile(deleg_path) and _nlines() == 1)

        # A2 (positive): a correctly chained 2nd record (prev_hash = sha256 of line 1, LF excluded).
        tip1 = _chain_tip_hash(deleg_path)
        rec2 = _write(ar, _base_record(delegation_id="deleg-a2", prev_hash=tip1), name="rec2.json")
        ok2, reasons2 = append_delegation_record(ar, RUN, rec2)
        t.ok("A2 append: chained 2nd record (prev_hash = sha256(line1, LF-excluded)) ACCEPTED",
             ok2 and reasons2 == [] and _nlines() == 2)

        # A3 (positive): may_mutate:true record whose scope_lock_ref resolves + run_id matches —
        # closes the docstring's :44-53 judgment call at the content tier.
        lock_ok_path = os.path.join(ar, "scope-ok.lock.json")
        with open(lock_ok_path, "w", encoding="utf-8") as f:
            f.write(json.dumps({"schema": "dmc.scope-lock.v1", "run_id": RUN}))
        tip2 = _chain_tip_hash(deleg_path)
        rec3 = _write(ar, _base_record(
            delegation_id="deleg-a3", role="implementer",
            capability_class="standard-implementation", may_mutate=True,
            scope_lock_ref=lock_ok_path, prev_hash=tip2), name="rec3.json")
        ok3, reasons3 = append_delegation_record(ar, RUN, rec3)
        t.ok("A3 append: may_mutate:true + resolvable scope_lock_ref (matching run_id) ACCEPTED",
             ok3 and reasons3 == [] and _nlines() == 3)

        # A4 (positive): check() PASSes over the clean 3-record chain built above.
        okc, reasonsc, countc = check_delegation_chain(ar, RUN)
        t.ok("A4 check: clean 3-record chain PASSES end-to-end",
             okc and reasonsc == [] and countc == 3)

        # ---- negative controls (append/check never writes on refusal) ----

        # A5: wrong prev_hash (not the actual chain tip) REFUSED; chain file untouched (3 lines).
        rec_bad_prev = _write(ar, _base_record(delegation_id="deleg-bad-prev",
                                                prev_hash="f" * 16), name="rec-bad-prev.json")
        ok5, reasons5 = append_delegation_record(ar, RUN, rec_bad_prev)
        t.ok("A5 append NEG: wrong prev_hash REFUSED (DELEG-CHAIN-BREAK), chain untouched",
             not ok5 and any(e.startswith("DELEG-CHAIN-BREAK") for e in reasons5) and _nlines() == 3)

        # A6: nonexistent run directory REFUSED.
        rec_no_run = _write(ar, _base_record(delegation_id="deleg-no-run"), name="rec-no-run.json")
        ok6, reasons6 = append_delegation_record(ar, "no-such-run", rec_no_run)
        t.ok("A6 append NEG: nonexistent run directory REFUSED (DELEG-NO-RUN)",
             not ok6 and any(e.startswith("DELEG-NO-RUN") for e in reasons6))

        # A7/A8 share a valid chain-tip prev_hash so the ONLY reason for refusal is the
        # scope-lock content-tier check under test (isolated negative controls).
        tip3 = _chain_tip_hash(deleg_path)

        # A7: may_mutate:true with an unresolvable scope_lock_ref REFUSED.
        rec_unresolved = _write(ar, _base_record(
            delegation_id="deleg-unresolved", role="implementer",
            capability_class="standard-implementation", may_mutate=True,
            scope_lock_ref=os.path.join(ar, "does-not-exist.lock.json"),
            prev_hash=tip3), name="rec-unresolved.json")
        ok7, reasons7 = append_delegation_record(ar, RUN, rec_unresolved)
        t.ok("A7 append NEG: may_mutate:true + unresolvable scope_lock_ref REFUSED "
             "(DELEG-SCOPE-LOCK-UNRESOLVED)",
             not ok7 and any(e.startswith("DELEG-SCOPE-LOCK-UNRESOLVED") for e in reasons7)
             and _nlines() == 3)

        # A8: may_mutate:true with a resolvable scope_lock_ref whose run_id does NOT match --run.
        lock_mismatch_path = os.path.join(ar, "scope-mismatch.lock.json")
        with open(lock_mismatch_path, "w", encoding="utf-8") as f:
            f.write(json.dumps({"schema": "dmc.scope-lock.v1", "run_id": "some-other-run"}))
        rec_mismatch = _write(ar, _base_record(
            delegation_id="deleg-mismatch", role="implementer",
            capability_class="standard-implementation", may_mutate=True,
            scope_lock_ref=lock_mismatch_path, prev_hash=tip3), name="rec-mismatch.json")
        ok8, reasons8 = append_delegation_record(ar, RUN, rec_mismatch)
        t.ok("A8 append NEG: scope_lock_ref resolves but run_id mismatches REFUSED "
             "(DELEG-SCOPE-LOCK-RUN-MISMATCH)",
             not ok8 and any(e.startswith("DELEG-SCOPE-LOCK-RUN-MISMATCH") for e in reasons8)
             and _nlines() == 3)

        # A9: a schema-invalid record REFUSED before the chain file is even touched (proves
        # validate_delegation() runs FIRST, per the append contract).
        rec_invalid = _write(ar, _base_record(delegation_id="deleg-invalid",
                                               role="frobnicator-nonexistent"),
                              name="rec-invalid.json")
        ok9, reasons9 = append_delegation_record(ar, RUN, rec_invalid)
        t.ok("A9 append NEG: schema-invalid record REFUSED pre-chain (validate_delegation first), "
             "chain untouched",
             not ok9 and any(e.startswith("DELEG-ROLE-UNRESOLVED") for e in reasons9)
             and _nlines() == 3)

        # A10: check() over a run with no delegations.jsonl at all REFUSED (not a vacuous pass).
        empty_run = "self-test-empty-run"
        os.makedirs(os.path.join(ar, ".harness", "runs", empty_run))
        ok10, reasons10, count10 = check_delegation_chain(ar, empty_run)
        t.ok("A10 check NEG: missing delegations.jsonl REFUSED (DELEG-NO-CHAIN)",
             not ok10 and any(e.startswith("DELEG-NO-CHAIN") for e in reasons10) and count10 == 0)

        # A11: a tampered middle line breaks the hash chain for check().
        tamper_run = "self-test-tamper-run"
        tamper_dir = os.path.join(ar, ".harness", "runs", tamper_run)
        os.makedirs(tamper_dir)
        tamper_path = os.path.join(tamper_dir, "delegations.jsonl")
        t_rec1 = _base_record(delegation_id="deleg-t1")
        t_line1 = json.dumps(t_rec1, sort_keys=True, separators=(",", ":"))
        t_tip1 = hashlib.sha256(t_line1.encode("utf-8")).hexdigest()
        t_rec2 = _base_record(delegation_id="deleg-t2", prev_hash=t_tip1)
        t_line2 = json.dumps(t_rec2, sort_keys=True, separators=(",", ":"))
        tampered_line1 = json.dumps(dict(t_rec1, delegation_id="deleg-t1-TAMPERED"),
                                    sort_keys=True, separators=(",", ":"))
        with open(tamper_path, "w", encoding="utf-8") as f:
            f.write(tampered_line1 + "\n" + t_line2 + "\n")
        ok11, reasons11, count11 = check_delegation_chain(ar, tamper_run)
        t.ok("A11 check NEG: tampered middle line breaks the hash chain REFUSED "
             "(DELEG-CHAIN-BREAK)",
             not ok11 and any(e.startswith("DELEG-CHAIN-BREAK") for e in reasons11))

        # A12: a chain line carrying an unvalidated consumption (artifact_ref set, verdict !=
        # PASS) smuggled directly into the file (bypassing append) is caught by check().
        uc_run = "self-test-unvalidated-consumption-run"
        uc_dir = os.path.join(ar, ".harness", "runs", uc_run)
        os.makedirs(uc_dir)
        uc_path = os.path.join(uc_dir, "delegations.jsonl")
        uc_rec = _base_record(delegation_id="deleg-uc", artifact_ref=".harness/artifacts/x.json",
                              artifact_schema="dmc.x.v1", validation_verdict="PENDING")
        with open(uc_path, "w", encoding="utf-8") as f:
            f.write(json.dumps(uc_rec, sort_keys=True, separators=(",", ":")) + "\n")
        ok12, reasons12, count12 = check_delegation_chain(ar, uc_run)
        t.ok("A12 check NEG: unvalidated-consumption record in the chain REFUSED "
             "(DELEG-UNVALIDATED-CONSUMPTION)",
             not ok12 and any(e.startswith("DELEG-UNVALIDATED-CONSUMPTION") for e in reasons12))

    # N24 (hermeticity): the real repo's tracked tree is untouched by this self-test — every fixture
    # above was written under a TemporaryDirectory(); nothing in this run touches the real tree.
    git_after = _git_status_snapshot(root)
    t.ok("N24 hermeticity: real repo git status --porcelain unchanged across the self-test "
         "(tempdir-only fixtures)",
         git_before is None or git_after is None or git_before == git_after)

    t.done()


# ------------------------------------------------------------------------ main

def main():
    ap = argparse.ArgumentParser(prog="dmc-delegation")
    ap.add_argument("command", nargs="?", choices=["validate", "append", "check"])
    ap.add_argument("arg", nargs="?",
                    help="path to a delegation-record JSON document (validate, append)")
    ap.add_argument("--registry", metavar="PATH", help="override the roles.json registry path used "
                    "for role resolution (default: orchestration/roles.json, via dmc-roles.py)")
    ap.add_argument("--run", metavar="RUN_ID", help="the run id whose "
                    ".harness/runs/RUN_ID/delegations.jsonl is appended to or checked "
                    "(append, check)")
    ap.add_argument("--self-test", action="store_true")
    # parse_intermixed_args (not parse_args): the ADVERTISED `append --run RUN_ID RECORD.json`
    # order interleaves a positional after an optional after a positional — plain parse_args()
    # cannot place the trailing positional there ("unrecognized arguments"); intermixed parsing
    # accepts BOTH orders (`append --run RID REC.json` and `append REC.json --run RID`).
    a = ap.parse_intermixed_args()

    if a.self_test:
        selftest()
        return

    if a.command == "validate":
        if not a.arg:
            die("validate requires <path>", 2)
        try:
            errs = validate_file(a.arg, a.registry)
        except FileNotFoundError:
            refuse(["DELEG-UNREADABLE: file not found"])
        except (OSError, UnicodeError) as e:
            refuse(["DELEG-UNREADABLE: %s" % e.__class__.__name__])
        if errs:
            refuse(errs)
        print("VALID: %s conforms to %s" % (a.arg, SCHEMA_ID))
        return

    if a.command == "append":
        if not a.run or not a.arg:
            die("append requires --run RUN_ID RECORD.json", 2)
        try:
            ok, reasons = append_delegation_record(repo_root(), a.run, a.arg, a.registry)
        except FileNotFoundError:
            refuse(["DELEG-UNREADABLE: file not found"])
        except (OSError, UnicodeError) as e:
            refuse(["DELEG-UNREADABLE: %s" % e.__class__.__name__])
        if not ok:
            refuse(reasons)
        print("APPENDED: 1 record to .harness/runs/%s/delegations.jsonl" % a.run)
        return

    if a.command == "check":
        if not a.run:
            die("check requires --run RUN_ID", 2)
        ok, reasons, count = check_delegation_chain(repo_root(), a.run, a.registry)
        if not ok:
            refuse(reasons)
        print("VALID: chain for run %s (%d record(s)) conforms to %s" % (a.run, count, SCHEMA_ID))
        return

    die("usage: validate <path> [--registry PATH] | "
        "append --run RUN_ID RECORD.json [--registry PATH] | "
        "check --run RUN_ID [--registry PATH] | --self-test", 2)


if __name__ == "__main__":
    main()
