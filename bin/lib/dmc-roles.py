#!/usr/bin/env python3
"""dmc-roles.py — DMC v1.0 M5 role-registry validator + lookup (P14 registry).

`orchestration/roles.json` is the single machine-readable orchestration taxonomy: six roles
(Strategic Orchestrator, Implementer, Critic/Falsifier, Release Auditor, Verifier, Human Release
Gate), each bound to a `session_binding`, a `capability_class` from the six-class enum, and a
`may_mutate` flag. It is model-name-free by invariant (capability classes only; model names live
in the dated orchestration/models.json, M8). Every other M5 tool (the delegation validator, the
link-check) resolves role references against this registry.

Subcommands:
  validate <path>              fail-closed shape/enum/uniqueness/model-name-free validator.
                               ACCEPT => exit 0, REFUSE => exit 3 (usage error => exit 2).
  lookup <role> [--registry P] resolve a role by its `id` or its exact display `role` name against
                               the registry (defaults to orchestration/roles.json). On a match it
                               prints the role record as JSON to stdout and exits 0; an unknown
                               role (or an unreadable/invalid registry) prints a REFUSED reason and
                               exits 3. This is the interface downstream M5 tools call as a
                               subprocess: exit 0 + JSON == resolves, exit 3 == absent/invalid.
  --self-test                  embedded section self-test (prints "[roles] N PASS / M FAIL";
                               exit 0 all-pass / 1 any-fail).

House rules (v0.6.x / M3 lineage, mirrors bin/lib/dmc-instance-validate.py): stdlib-only,
env-independent (no env reads), offline (no network, no git), input-only (reads only the named
file), value-blind (refusals name schema constants and reason codes, never the document's content
values), duplicate-JSON-key rejecting, secret-path refused by path, fail-closed with named reason
codes and negative controls. Advisory tier: the runtime enforcement floor stays the hooks.
"""

import argparse
import json
import os
import re
import sys
import tempfile

# The artifact this validator certifies (in-tool contract id).
SCHEMA_ID = "dmc.roles.v1"

# The six capability classes (docs/ORCHESTRATION_TAXONOMY.md Output 2 / v0.6.1 enum). Durable unit;
# no model name ever appears here or in a role record.
CAPABILITY_CLASSES = (
    "frontier-long-horizon",
    "standard-implementation",
    "cheap-fast",
    "adversarial-review",
    "deterministic-tool",
    "human-only-gate",
)

# The six canonical role ids (docs/ORCHESTRATION_TAXONOMY.md Output 1). The registry must encode
# exactly this set — dropped/renamed/extra roles are drift and are REFUSED.
CANONICAL_ROLE_IDS = (
    "strategic-orchestrator",
    "implementer",
    "critic-falsifier",
    "release-auditor",
    "verifier",
    "human-release-gate",
)

# may_mutate:true is legal for exactly this one role (the executor/Implementer), and only under an
# active scope.lock. Any other role marked may_mutate:true is REFUSED (C11 / mutation rule).
MUTATION_CAPABLE_ROLE_ID = "implementer"

# Per-role required fields (all non-empty single-line strings except may_mutate, a bool).
REQUIRED_STR_FIELDS = ("id", "role", "session_binding", "capability_class", "mutation_constraint")

# Model-name detector (v0.6.1 self-scan invariant). Catches at least the plan-mandated patterns;
# case-insensitive to be stricter than the belt-and-suspenders `grep -RInE`. Model names belong in
# orchestration/models.json (M8), never in the registry.
MODEL_NAME_RE = re.compile(
    r"claude-(?:opus|sonnet|haiku|fable|mythos)|gpt-[0-9]|codex-[0-9]", re.IGNORECASE
)


# ------------------------------------------------------------------- helpers

def die(msg, code=2):
    sys.stderr.write("dmc-roles: %s\n" % msg)
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


def load_registry_text(text):
    """Parse registry JSON text, rejecting duplicate keys. Raises ValueError on malformed input."""
    return json.loads(text, object_pairs_hook=_no_dup)


def repo_root():
    return os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                         "..", ".."))


def default_registry_path():
    return os.path.join(repo_root(), "orchestration", "roles.json")


def _nestr(x):
    """Non-empty single-line string."""
    return isinstance(x, str) and x != "" and "\n" not in x


def _scan_model_name(obj):
    """Recursively scan every JSON key and string value for a model name. Value-blind: returns a
    bool, never the offending substring."""
    if isinstance(obj, dict):
        for k, v in obj.items():
            if isinstance(k, str) and MODEL_NAME_RE.search(k):
                return True
            if _scan_model_name(v):
                return True
    elif isinstance(obj, list):
        for x in obj:
            if _scan_model_name(x):
                return True
    elif isinstance(obj, str):
        if MODEL_NAME_RE.search(obj):
            return True
    return False


# --------------------------------------------------------------- validate

def validate_registry(obj):
    """Return a list of value-blind reason codes; empty list == ACCEPT."""
    errs = []
    if not isinstance(obj, dict):
        return ["ROLES-NOT-OBJECT: top-level document is not a JSON object"]

    if obj.get("schema") != SCHEMA_ID:
        errs.append("ROLES-BAD-SCHEMA: 'schema' must be %r" % SCHEMA_ID)

    # Model-name-free invariant applies to the WHOLE document (provenance text included).
    if _scan_model_name(obj):
        errs.append("ROLES-MODEL-NAME: a model-name string is present (capability classes only; "
                    "model names belong in orchestration/models.json, M8)")

    # Declared capability-class enum (if present) must equal the canonical six.
    if "capability_classes" in obj:
        cc = obj["capability_classes"]
        if not isinstance(cc, list) or set(cc) != set(CAPABILITY_CLASSES) or len(cc) != len(CAPABILITY_CLASSES):
            errs.append("ROLES-BAD-CLASS-ENUM: 'capability_classes' must be exactly the six-class enum")

    # Declared mutation-capable role must be the executor/Implementer.
    if obj.get("mutation_capable_role") != MUTATION_CAPABLE_ROLE_ID:
        errs.append("ROLES-BAD-MUTATION-DECL: 'mutation_capable_role' must be %r"
                    % MUTATION_CAPABLE_ROLE_ID)

    roles = obj.get("roles")
    if not isinstance(roles, list) or not roles:
        errs.append("ROLES-NO-ROLES: 'roles' must be a non-empty list")
        return errs

    seen_ids = {}
    seen_names = {}
    for i, r in enumerate(roles):
        if not isinstance(r, dict):
            errs.append("ROLES-ROLE-NOT-OBJECT: roles[%d] is not an object" % i)
            continue
        for f in REQUIRED_STR_FIELDS:
            if not _nestr(r.get(f)):
                errs.append("ROLES-FIELD-MISSING: roles[%d].%s missing/empty/multiline" % (i, f))
        if not isinstance(r.get("may_mutate"), bool):
            errs.append("ROLES-MUTATE-NOT-BOOL: roles[%d].may_mutate must be a bool" % i)

        rid = r.get("id")
        if _nestr(rid):
            if rid in seen_ids:
                errs.append("ROLES-DUP-ID: duplicate role id at roles[%d]" % i)
            seen_ids[rid] = i
        rname = r.get("role")
        if _nestr(rname):
            if rname in seen_names:
                errs.append("ROLES-DUP-NAME: duplicate role name at roles[%d]" % i)
            seen_names[rname] = i

        cclass = r.get("capability_class")
        if _nestr(cclass) and cclass not in CAPABILITY_CLASSES:
            errs.append("ROLES-BAD-CLASS: roles[%d].capability_class not in the six-class enum" % i)

        # Mutation rule: only the declared mutation-capable role may be may_mutate:true.
        if r.get("may_mutate") is True:
            if rid != MUTATION_CAPABLE_ROLE_ID:
                errs.append("ROLES-ILLEGAL-MUTATOR: roles[%d] may_mutate:true but is not the "
                            "executor/Implementer role" % i)
            else:
                constraint = r.get("mutation_constraint") or ""
                if not re.search(r"scope[.\-]lock", constraint, re.IGNORECASE):
                    errs.append("ROLES-MUTATOR-NO-SCOPE-LOCK: the mutation-capable role must state "
                                "its scope.lock constraint in 'mutation_constraint'")

    # Faithfulness: the registry must encode exactly the six canonical role ids.
    if seen_ids:
        got = set(seen_ids)
        want = set(CANONICAL_ROLE_IDS)
        for missing in sorted(want - got):
            errs.append("ROLES-MISSING-ROLE: canonical role id %r absent" % missing)
        for extra in sorted(got - want):
            errs.append("ROLES-UNKNOWN-ROLE: non-canonical role id %r present" % extra)

    # The declared mutation-capable role must actually exist and be may_mutate:true.
    if obj.get("mutation_capable_role") == MUTATION_CAPABLE_ROLE_ID:
        idx = seen_ids.get(MUTATION_CAPABLE_ROLE_ID)
        if idx is None:
            errs.append("ROLES-MUTATOR-ABSENT: declared mutation-capable role %r not in 'roles'"
                        % MUTATION_CAPABLE_ROLE_ID)
        elif roles[idx].get("may_mutate") is not True:
            errs.append("ROLES-MUTATOR-NOT-CAPABLE: role %r must be may_mutate:true"
                        % MUTATION_CAPABLE_ROLE_ID)

    return errs


def validate_file(path):
    """Load + validate a registry file. Returns a list of reason codes (empty == ACCEPT)."""
    text = read_text(path)  # is_secret_path guard inside; die(3) on secret shape.
    try:
        obj = load_registry_text(text)
    except ValueError as e:
        return ["ROLES-UNREADABLE: %s" % e]
    return validate_registry(obj)


# --------------------------------------------------------------- lookup

def resolve_role(obj, key):
    """Resolve a role by exact `id` or exact display `role` name. Returns the role dict or None."""
    roles = obj.get("roles") if isinstance(obj, dict) else None
    if not isinstance(roles, list):
        return None
    for r in roles:
        if isinstance(r, dict) and (r.get("id") == key or r.get("role") == key):
            return r
    return None


def lookup_cli(role_key, registry_path):
    errs = validate_file(registry_path)
    if errs:
        # A malformed registry cannot answer a lookup — fail closed.
        refuse(["ROLES-REGISTRY-INVALID: registry does not validate"] + errs)
    obj = load_registry_text(read_text(registry_path))
    rec = resolve_role(obj, role_key)
    if rec is None:
        refuse(["ROLES-UNKNOWN-ROLE: role does not resolve in the registry"])
    print(json.dumps(rec, indent=2, sort_keys=True, ensure_ascii=False))
    sys.exit(0)


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


# A full, valid base registry the negative controls mutate. Model-name-free by construction.
def _base_registry():
    return {
        "schema": SCHEMA_ID,
        "provenance": {"note": "self-test fixture"},
        "capability_classes": list(CAPABILITY_CLASSES),
        "mutation_capable_role": MUTATION_CAPABLE_ROLE_ID,
        "roles": [
            {"id": "strategic-orchestrator", "role": "Strategic Orchestrator",
             "session_binding": "the main session", "capability_class": "frontier-long-horizon",
             "may_mutate": False, "mutation_constraint": "never mutates directly"},
            {"id": "implementer", "role": "Implementer",
             "session_binding": "executor agent; worker providers",
             "capability_class": "standard-implementation", "may_mutate": True,
             "mutation_constraint": "executor only, under an active scope.lock"},
            {"id": "critic-falsifier", "role": "Critic / Falsifier",
             "session_binding": "critic agent", "capability_class": "adversarial-review",
             "may_mutate": False, "mutation_constraint": "read-only (C11)"},
            {"id": "release-auditor", "role": "Release Auditor",
             "session_binding": "release-auditor agent", "capability_class": "adversarial-review",
             "may_mutate": False, "mutation_constraint": "read-only (C11)"},
            {"id": "verifier", "role": "Verifier",
             "session_binding": "verifier agent; bin/dmc", "capability_class": "deterministic-tool",
             "may_mutate": False, "mutation_constraint": "read-only"},
            {"id": "human-release-gate", "role": "Human Release Gate",
             "session_binding": "human only", "capability_class": "human-only-gate",
             "may_mutate": False, "mutation_constraint": "not applicable"},
        ],
    }


def _write(td, obj):
    """Write a fixture dict to a roles.json in the tempdir; return its path."""
    p = os.path.join(td, "roles.json")
    with open(p, "w", encoding="utf-8") as f:
        f.write(json.dumps(obj))
    return p


def selftest():
    t = ST("roles")

    # Positive control: the REAL orchestration/roles.json validates.
    real = default_registry_path()
    t.check("R0 real orchestration/roles.json ACCEPTED (positive control)",
            lambda: validate_file(real) == [])

    with tempfile.TemporaryDirectory() as td:
        # R1 base fixture ACCEPTED.
        t.check("R1 valid base fixture ACCEPTED",
                lambda: validate_file(_write(td, _base_registry())) == [])

        # R2 negative control: capability_class outside the six-class enum.
        def bad_class():
            o = _base_registry()
            o["roles"][2]["capability_class"] = "super-frontier"
            return o
        t.check("R2 negative control: capability_class outside enum REFUSED",
                lambda: any(e.startswith("ROLES-BAD-CLASS")
                            for e in validate_file(_write(td, bad_class()))))

        # R3 negative control: a role other than the Implementer marked may_mutate:true.
        def bad_mutator():
            o = _base_registry()
            o["roles"][2]["may_mutate"] = True   # critic-falsifier
            return o
        t.check("R3 negative control: non-executor may_mutate:true REFUSED",
                lambda: any(e.startswith("ROLES-ILLEGAL-MUTATOR")
                            for e in validate_file(_write(td, bad_mutator()))))

        # R4 negative control: a seeded model-name string anywhere in the fixture.
        for pat in ("claude-opus-4-8", "gpt-5", "codex-5"):
            def seeded(p=pat):
                o = _base_registry()
                o["roles"][0]["session_binding"] = "runs on %s" % p
                return o
            t.check("R4 negative control: seeded model name %r REFUSED" % pat,
                    lambda p=pat: any(e.startswith("ROLES-MODEL-NAME")
                                      for e in validate_file(_write(td, seeded(p)))))

        # R5 negative control: duplicate role id.
        def dup_id():
            o = _base_registry()
            o["roles"][3]["id"] = "verifier"   # collides with roles[4]
            return o
        t.check("R5 negative control: duplicate role id REFUSED",
                lambda: any(e.startswith("ROLES-DUP-ID")
                            for e in validate_file(_write(td, dup_id()))))

        # R6 negative control: a dropped canonical role (only five present).
        def drop_role():
            o = _base_registry()
            o["roles"] = o["roles"][:-1]
            return o
        t.check("R6 negative control: missing canonical role REFUSED",
                lambda: any(e.startswith("ROLES-MISSING-ROLE")
                            for e in validate_file(_write(td, drop_role()))))

        # R7 negative control: missing required field.
        def drop_field():
            o = _base_registry()
            del o["roles"][0]["session_binding"]
            return o
        t.check("R7 negative control: missing required field REFUSED",
                lambda: any(e.startswith("ROLES-FIELD-MISSING")
                            for e in validate_file(_write(td, drop_field()))))

        # R8 negative control: may_mutate not a bool.
        def non_bool():
            o = _base_registry()
            o["roles"][1]["may_mutate"] = "true"
            return o
        t.check("R8 negative control: may_mutate not bool REFUSED",
                lambda: any(e.startswith("ROLES-MUTATE-NOT-BOOL")
                            for e in validate_file(_write(td, non_bool()))))

        # R9 negative control: mutation-capable role without a scope.lock constraint.
        def no_lock():
            o = _base_registry()
            o["roles"][1]["mutation_constraint"] = "executor only"
            return o
        t.check("R9 negative control: mutator without scope.lock constraint REFUSED",
                lambda: any(e.startswith("ROLES-MUTATOR-NO-SCOPE-LOCK")
                            for e in validate_file(_write(td, no_lock()))))

        # R10 negative control: wrong schema id.
        def bad_schema():
            o = _base_registry()
            o["schema"] = "dmc.roles.v2"
            return o
        t.check("R10 negative control: wrong schema id REFUSED",
                lambda: any(e.startswith("ROLES-BAD-SCHEMA")
                            for e in validate_file(_write(td, bad_schema()))))

        # R11 negative control: duplicate JSON key rejected at parse time.
        def dup_key_path():
            p = os.path.join(td, "roles.json")
            with open(p, "w", encoding="utf-8") as f:
                f.write('{"schema":"dmc.roles.v1","schema":"x","roles":[]}')
            return p
        t.check("R11 negative control: duplicate JSON key REFUSED",
                lambda: any(e.startswith("ROLES-UNREADABLE")
                            for e in validate_file(dup_key_path())))

        # R12 lookup resolves by id AND by display name; unknown role does not resolve.
        base_path = _write(td, _base_registry())
        obj = load_registry_text(read_text(base_path))
        t.ok("R12 lookup by id resolves", resolve_role(obj, "implementer") is not None)
        t.ok("R12 lookup by display name resolves",
             resolve_role(obj, "Human Release Gate") is not None)
        t.ok("R12 lookup unknown role does not resolve",
             resolve_role(obj, "frobnicator") is None)

        # R13 determinism: same input, same reasons.
        badp = _write(td, bad_class())
        t.ok("R13 determinism", validate_file(badp) == validate_file(badp))

    # R14 secret-path refusal is by path (never opens the file).
    t.ok("R14 secret-shaped path filter", is_secret_path("orchestration/.env")
         and is_secret_path("x/id_rsa") and not is_secret_path("orchestration/roles.json"))

    t.done()


# ------------------------------------------------------------------------ main

def main():
    ap = argparse.ArgumentParser(prog="dmc-roles")
    ap.add_argument("command", nargs="?", choices=["validate", "lookup"])
    ap.add_argument("arg", nargs="?", help="path (validate) or role id/name (lookup)")
    ap.add_argument("--registry", metavar="PATH", help="registry path for lookup "
                    "(default: orchestration/roles.json)")
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args()

    if a.self_test:
        selftest()
        return

    if a.command == "validate":
        if not a.arg:
            die("validate requires <path>", 2)
        try:
            errs = validate_file(a.arg)
        except FileNotFoundError:
            refuse(["ROLES-UNREADABLE: file not found"])
        except (OSError, UnicodeError) as e:
            refuse(["ROLES-UNREADABLE: %s" % e.__class__.__name__])
        if errs:
            refuse(errs)
        print("VALID: %s conforms to %s" % (a.arg, SCHEMA_ID))
        return

    if a.command == "lookup":
        if not a.arg:
            die("lookup requires <role>", 2)
        path = a.registry or default_registry_path()
        try:
            lookup_cli(a.arg, path)
        except FileNotFoundError:
            refuse(["ROLES-UNREADABLE: registry file not found"])
        except (OSError, UnicodeError) as e:
            refuse(["ROLES-UNREADABLE: %s" % e.__class__.__name__])
        return

    die("usage: validate <path> | lookup <role> [--registry PATH] | --self-test", 2)


if __name__ == "__main__":
    main()
