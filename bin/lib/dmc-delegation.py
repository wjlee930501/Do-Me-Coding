#!/usr/bin/env python3
"""dmc-delegation.py — DMC v1.0 M5 delegation-record validator (P14 records schema-check).

Validates a single `dmc.delegation.v1` delegation record (see `.harness/schemas/delegation.schema.md`)
— subject-binding fields, `capability_class` enum, `role` resolution against
`orchestration/roles.json`, the `depth <= max_depth` recursion bound, the `may_mutate` / scope-lock
rule, and the `validation_verdict` consumption gate.

SCOPE: this module ships the SCHEMA validator ONLY (P14 records schema-check, DMC-T010c). The
delegation *runtime records pipeline* — appending `delegations.jsonl` at dispatch time, enforcing
validate-before-consumption live during a run — is out of scope and lands in M7 (P14 runtime
records; `.harness/plans/dmc-v1-m5-orchestration.md` Out of Scope). This module is a standalone,
read-only check callable against any single delegation-record JSON document; it does not append,
mutate, or write anything.

Subcommands:
  validate <path> [--registry PATH]   fail-closed record validator. ACCEPT => exit 0,
                                       REFUSE => exit 3 (usage error => exit 2). `--registry`
                                       overrides the roles.json path used for role resolution
                                       (default: orchestration/roles.json under the repo root, via
                                       bin/lib/dmc-roles.py's own default).
  --self-test                         embedded section self-test (prints
                                       "[delegation] N PASS / M FAIL"); exit 0 all-pass / 1 any-fail.

House rules (v0.6.x / M3-M5 lineage, mirrors bin/lib/dmc-instance-validate.py and
bin/lib/dmc-roles.py): stdlib-only, env-independent (no env reads), offline (no network; git is
invoked only best-effort, read-only, for the self-test's own hermeticity check, with a no-git
fallback), input-only (reads only the named file), value-blind (refusals name schema
constants/reason codes, never the document's content values), duplicate-JSON-key rejecting,
secret-path refused by path, secret-shaped field *content* also refused, fail-closed with named
reason codes and negative controls. Advisory tier: the runtime enforcement floor stays the hooks.

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

Judgment call — the scope-lock reference field: `delegation.schema.md`'s illustrative JSON block
does not name a distinct field for "an active scope.lock reference" (the prose rule only says a
mutation-capable dispatch requires one; the schema and its M3 authors are out of this task's edit
scope). This validator names that field `scope_lock_ref` — a non-null, non-empty string identifying
the run's `scope.lock.json` (schema `dmc.scope-lock.v1`; see `bin/lib/dmc-scope-lock.py`, whose
`REQUIRED_FIELDS` include `run_id` and `state_hash` as the natural handles such a reference would
name) — and requires it whenever `may_mutate: true`. This validator checks only that the reference
is present and non-empty (a schema-shape check); it does not itself open or cross-validate the
referenced scope.lock.json's content, which is a runtime (M7) concern. Flagged for verification
(T010f) attention.
"""

import argparse
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


def validate_file(path, registry_path=None):
    """Load + validate a delegation-record file. Returns a list of reason codes (empty == ACCEPT)."""
    text = read_text(path)  # is_secret_path guard inside; die(3) on secret shape.
    try:
        obj = load_json_text(text)
    except ValueError as e:
        return ["DELEG-UNREADABLE: %s" % e]
    return validate_delegation(obj, registry_path)


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
    ap.add_argument("command", nargs="?", choices=["validate"])
    ap.add_argument("arg", nargs="?", help="path to a delegation-record JSON document (validate)")
    ap.add_argument("--registry", metavar="PATH", help="override the roles.json registry path used "
                    "for role resolution (default: orchestration/roles.json, via dmc-roles.py)")
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args()

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

    die("usage: validate <path> [--registry PATH] | --self-test", 2)


if __name__ == "__main__":
    main()
