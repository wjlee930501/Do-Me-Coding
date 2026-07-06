#!/usr/bin/env python3
"""dmc-critic-verdict.py — DMC v1.0 M5 critic-verdict validator (P16).

A `critic-verdict.json` is the critic role's recorded gate verdict artifact (not chat prose),
per `.harness/schemas/critic-verdict.schema.md`. This validator makes that artifact
machine-checkable and fail-closed.

Invariant C11 (load-bearing): the verdict is ADVISORY evidence — it never flips approval. The
schema encodes this as `advisory == true`; a verdict with `advisory != true` is a routing
violation and is REFUSED here. Approval is a P17 human-gate record, never a critic verdict.

Subcommands:
  validate <path>              fail-closed shape/enum/subject-binding validator.
                               ACCEPT => exit 0, REFUSE => exit 3 (usage error => exit 2).
  --self-test                  embedded section self-test (prints "[verdict-validate] N PASS /
                               M FAIL"; exit 0 all-pass / 1 any-fail).

House rules (v0.6.x / M3 lineage, mirrors bin/lib/dmc-roles.py and dmc-instance-validate.py):
stdlib-only, env-independent (no env reads), offline (no network, no git), input-only (reads only
the named file), value-blind (refusals name schema constants and reason codes, never the
document's content values), duplicate-JSON-key rejecting, secret-path refused by path,
secret-shaped content refused (value-blind), fail-closed with named reason codes and negative
controls. Advisory tier: the runtime enforcement floor stays the hooks.
"""

import argparse
import json
import os
import re
import sys
import tempfile

# The artifact this validator certifies (schema id from critic-verdict.schema.md).
SCHEMA_ID = "dmc.critic-verdict.v1"

# Verdict enum (schema §Rules). Value-blind: refusals name the enum, never the document's value.
VERDICTS = ("APPROVE", "REJECT", "NEEDS_CLARIFICATION")

# context_provenance enum. A binding review requires `fresh` (the diff author may not emit its own
# critic verdict); `shared` is a valid recorded value but flagged as non-independent by consumers.
PROVENANCE = ("fresh", "shared")

# criteria_checked[].result enum.
CRITERION_RESULTS = ("met", "unmet", "na")

# Subject-binding string fields (non-empty single-line). plan_hash/repo_hash are hash-shaped below.
SUBJECT_STR_FIELDS = ("work_id", "target_ref")
HASH_FIELDS = ("plan_hash", "repo_hash")

# Hash shape shared with the M4 run-lifecycle (`<hex >=16>` per the schema).
HASH_RE = re.compile(r"^[0-9a-f]{16,}$")

# High-precision secret-MATERIAL detectors (value-blind hardening). Deliberately narrow to avoid
# false positives on advisory free-form `note` prose; each returns a bool, never the match.
SECRET_CONTENT_RES = (
    re.compile(r"-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----"),
    re.compile(r"AKIA[0-9A-Z]{16}"),
    re.compile(r"gh[pousr]_[A-Za-z0-9]{20,}"),
    re.compile(r"xox[baprs]-[A-Za-z0-9-]{10,}"),
    re.compile(r"sk-[A-Za-z0-9]{20,}"),
)


# ------------------------------------------------------------------- helpers

def die(msg, code=2):
    sys.stderr.write("dmc-critic-verdict: %s\n" % msg)
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


def load_verdict_text(text):
    """Parse verdict JSON text, rejecting duplicate keys. Raises ValueError on malformed input."""
    return json.loads(text, object_pairs_hook=_no_dup)


def _nestr(x):
    """Non-empty single-line string."""
    return isinstance(x, str) and x != "" and "\n" not in x


def _has_secret_content(obj):
    """Recursively scan JSON keys and string values for secret material. Value-blind: returns a
    bool, never the offending substring."""
    if isinstance(obj, dict):
        for k, v in obj.items():
            if isinstance(k, str) and any(rx.search(k) for rx in SECRET_CONTENT_RES):
                return True
            if _has_secret_content(v):
                return True
    elif isinstance(obj, list):
        for x in obj:
            if _has_secret_content(x):
                return True
    elif isinstance(obj, str):
        if any(rx.search(obj) for rx in SECRET_CONTENT_RES):
            return True
    return False


# --------------------------------------------------------------- validate

def validate_verdict(obj):
    """Return a list of value-blind reason codes; empty list == ACCEPT."""
    errs = []
    if not isinstance(obj, dict):
        return ["VERDICT-NOT-OBJECT: top-level document is not a JSON object"]

    if obj.get("schema") != SCHEMA_ID:
        errs.append("VERDICT-BAD-SCHEMA: 'schema' must be %r" % SCHEMA_ID)

    # Secret-shaped content anywhere in the artifact is refused (value-blind hardening).
    if _has_secret_content(obj):
        errs.append("VERDICT-SECRET-CONTENT: secret-shaped material present in the verdict "
                    "(value-blind refusal — never inline a credential in an advisory artifact)")

    # Subject binding: work_id + target_ref present/non-empty; plan_hash/repo_hash hash-shaped.
    for f in SUBJECT_STR_FIELDS:
        if not _nestr(obj.get(f)):
            errs.append("VERDICT-FIELD-MISSING: %s missing/empty/multiline (subject binding)" % f)
    for hf in HASH_FIELDS:
        v = obj.get(hf)
        if not (isinstance(v, str) and HASH_RE.match(v)):
            errs.append("VERDICT-BAD-HASH: %s not hash-shaped (hex >=16)" % hf)

    # Verdict enum.
    verdict = obj.get("verdict")
    if verdict not in VERDICTS:
        errs.append("VERDICT-BAD-VERDICT: 'verdict' must be one of %s" % "|".join(VERDICTS))

    # C11: advisory MUST be boolean true — the verdict opens no gate.
    if obj.get("advisory") is not True:
        errs.append("VERDICT-NOT-ADVISORY: 'advisory' must be boolean true "
                    "(C11: the verdict is advisory evidence, never a grant)")

    # Author-role sanity: context_provenance in the enum (fresh|shared).
    if obj.get("context_provenance") not in PROVENANCE:
        errs.append("VERDICT-BAD-PROVENANCE: 'context_provenance' must be one of %s"
                    % "|".join(PROVENANCE))

    # lenses is a non-empty list of non-empty strings (schema §Rules).
    lenses = obj.get("lenses")
    if not (isinstance(lenses, list) and lenses and all(_nestr(x) for x in lenses)):
        errs.append("VERDICT-BAD-LENSES: 'lenses' must be a non-empty list of non-empty strings")

    # blockers structure (any verdict): if present, a list of objects each carrying a non-empty
    # id and a non-empty statement (no vague blocker).
    blockers = obj.get("blockers")
    if blockers is not None:
        if not isinstance(blockers, list):
            errs.append("VERDICT-BLOCKER-BAD: 'blockers' must be a list")
            blockers = None
        else:
            for i, b in enumerate(blockers):
                if not isinstance(b, dict):
                    errs.append("VERDICT-BLOCKER-BAD: blockers[%d] is not an object" % i)
                    continue
                if not _nestr(b.get("id")):
                    errs.append("VERDICT-BLOCKER-BAD: blockers[%d].id missing/empty/multiline" % i)
                if not _nestr(b.get("statement")):
                    errs.append("VERDICT-BLOCKER-BAD: blockers[%d].statement missing/empty "
                                "(no vague blocker)" % i)

    # REJECT => non-empty blockers (no vague rejection).
    if verdict == "REJECT" and not (isinstance(blockers, list) and len(blockers) > 0):
        errs.append("VERDICT-REJECT-NO-BLOCKERS: verdict REJECT requires a non-empty 'blockers' "
                    "list (no vague rejection)")

    # criteria_checked structure if present: list of objects with result in the enum.
    cc = obj.get("criteria_checked")
    if cc is not None:
        if not isinstance(cc, list):
            errs.append("VERDICT-CRITERIA-BAD: 'criteria_checked' must be a list")
        else:
            for i, c in enumerate(cc):
                if not isinstance(c, dict):
                    errs.append("VERDICT-CRITERIA-BAD: criteria_checked[%d] is not an object" % i)
                    continue
                if not _nestr(c.get("criterion_ref")):
                    errs.append("VERDICT-CRITERIA-BAD: criteria_checked[%d].criterion_ref "
                                "missing/empty" % i)
                if c.get("result") not in CRITERION_RESULTS:
                    errs.append("VERDICT-CRITERIA-BAD: criteria_checked[%d].result not in %s"
                                % (i, "|".join(CRITERION_RESULTS)))

    return errs


def validate_file(path):
    """Load + validate a verdict file. Returns a list of reason codes (empty == ACCEPT)."""
    text = read_text(path)  # is_secret_path guard inside; die(3) on secret shape.
    try:
        obj = load_verdict_text(text)
    except ValueError as e:
        return ["VERDICT-UNREADABLE: %s" % e]
    return validate_verdict(obj)


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


def _base_verdict():
    """A full, valid critic-verdict the negative controls mutate. Secret-free by construction."""
    return {
        "schema": SCHEMA_ID,
        "work_id": "dmc-v1-m5-orchestration",
        "plan_hash": "a" * 40,
        "repo_hash": "b" * 40,
        "target_ref": ".harness/plans/dmc-v1-m5-orchestration.md",
        "verdict": "APPROVE",
        "lenses": ["correctness", "scope", "security"],
        "criteria_checked": [{"criterion_ref": "AC1", "result": "met", "note": "advisory note"}],
        "blockers": [],
        "advisory": True,
        "context_provenance": "fresh",
    }


def _reject_verdict():
    """A well-formed REJECT (with a real blocker) — must ACCEPT (reject-with-blocker is valid)."""
    o = _base_verdict()
    o["verdict"] = "REJECT"
    o["blockers"] = [{"id": "B1", "statement": "the scope table omits a not-edit row",
                      "evidence_ref": "plan#relevant-files"}]
    return o


def _write(td, obj, name="critic-verdict.json"):
    p = os.path.join(td, name)
    with open(p, "w", encoding="utf-8") as f:
        f.write(json.dumps(obj))
    return p


def selftest():
    t = ST("verdict-validate")

    with tempfile.TemporaryDirectory() as td:
        # Positive controls.
        t.check("C0 valid APPROVE verdict ACCEPTED",
                lambda: validate_file(_write(td, _base_verdict())) == [])
        t.check("C1 well-formed REJECT (with blocker) ACCEPTED",
                lambda: validate_file(_write(td, _reject_verdict())) == [])

        # Plan-mandated negative control: REJECT with empty blockers.
        def reject_empty():
            o = _base_verdict()
            o["verdict"] = "REJECT"
            o["blockers"] = []
            return o
        t.check("C2 negative control: REJECT with empty blockers REFUSED",
                lambda: any(e.startswith("VERDICT-REJECT-NO-BLOCKERS")
                            for e in validate_file(_write(td, reject_empty()))))

        # Plan-mandated negative control: advisory != true (C11).
        def not_advisory():
            o = _base_verdict()
            o["advisory"] = False
            return o
        t.check("C3 negative control: advisory != true REFUSED (C11)",
                lambda: any(e.startswith("VERDICT-NOT-ADVISORY")
                            for e in validate_file(_write(td, not_advisory()))))

        # Plan-mandated negative control: a missing subject-binding field.
        def drop_work_id():
            o = _base_verdict()
            del o["work_id"]
            return o
        t.check("C4 negative control: missing work_id (subject binding) REFUSED",
                lambda: any(e.startswith("VERDICT-FIELD-MISSING")
                            for e in validate_file(_write(td, drop_work_id()))))

        # Hardening: subject-binding hash not hash-shaped.
        def bad_hash():
            o = _base_verdict()
            o["plan_hash"] = "not-a-hash"
            return o
        t.check("C5 negative control: plan_hash not hash-shaped REFUSED",
                lambda: any(e.startswith("VERDICT-BAD-HASH")
                            for e in validate_file(_write(td, bad_hash()))))

        # Hardening: unknown verdict value.
        def bad_verdict():
            o = _base_verdict()
            o["verdict"] = "MAYBE"
            return o
        t.check("C6 negative control: unknown verdict value REFUSED",
                lambda: any(e.startswith("VERDICT-BAD-VERDICT")
                            for e in validate_file(_write(td, bad_verdict()))))

        # Hardening: context_provenance outside the enum.
        def bad_prov():
            o = _base_verdict()
            o["context_provenance"] = "borrowed"
            return o
        t.check("C7 negative control: bad context_provenance REFUSED",
                lambda: any(e.startswith("VERDICT-BAD-PROVENANCE")
                            for e in validate_file(_write(td, bad_prov()))))

        # Hardening: empty lenses list.
        def empty_lenses():
            o = _base_verdict()
            o["lenses"] = []
            return o
        t.check("C8 negative control: empty lenses REFUSED",
                lambda: any(e.startswith("VERDICT-BAD-LENSES")
                            for e in validate_file(_write(td, empty_lenses()))))

        # Hardening: a blocker with an empty statement (vague blocker).
        def vague_blocker():
            o = _reject_verdict()
            o["blockers"] = [{"id": "B1", "statement": "", "evidence_ref": "r"}]
            return o
        t.check("C9 negative control: blocker with empty statement REFUSED",
                lambda: any(e.startswith("VERDICT-BLOCKER-BAD")
                            for e in validate_file(_write(td, vague_blocker()))))

        # Hardening: wrong schema id.
        def bad_schema():
            o = _base_verdict()
            o["schema"] = "dmc.critic-verdict.v2"
            return o
        t.check("C10 negative control: wrong schema id REFUSED",
                lambda: any(e.startswith("VERDICT-BAD-SCHEMA")
                            for e in validate_file(_write(td, bad_schema()))))

        # Hardening: criteria_checked[].result outside the enum.
        def bad_criterion():
            o = _base_verdict()
            o["criteria_checked"] = [{"criterion_ref": "AC1", "result": "sorta"}]
            return o
        t.check("C11 negative control: bad criterion result REFUSED",
                lambda: any(e.startswith("VERDICT-CRITERIA-BAD")
                            for e in validate_file(_write(td, bad_criterion()))))

        # Hardening: duplicate JSON key rejected at parse time.
        def dup_key_path():
            p = os.path.join(td, "dup.json")
            with open(p, "w", encoding="utf-8") as f:
                f.write('{"schema":"dmc.critic-verdict.v1","schema":"x","verdict":"APPROVE"}')
            return p
        t.check("C12 negative control: duplicate JSON key REFUSED",
                lambda: any(e.startswith("VERDICT-UNREADABLE")
                            for e in validate_file(dup_key_path())))

        # Hardening: secret-shaped content anywhere in the artifact (value-blind).
        def secret_content():
            o = _base_verdict()
            fake_aws = "AKIA" + "1234567890ABCDEF"   # not a real key; matches AKIA[0-9A-Z]{16}
            o["criteria_checked"] = [{"criterion_ref": "AC1", "result": "met", "note": fake_aws}]
            return o
        t.check("C13 negative control: secret-shaped content REFUSED",
                lambda: any(e.startswith("VERDICT-SECRET-CONTENT")
                            for e in validate_file(_write(td, secret_content()))))

        # Determinism: same input, same reasons.
        badp = _write(td, bad_verdict())
        t.ok("C14 determinism", validate_file(badp) == validate_file(badp))

    # C15 secret-path refusal is by path (never opens the file).
    t.ok("C15 secret-shaped path filter",
         is_secret_path("x/critic-verdict.pem") and is_secret_path("x/.env")
         and not is_secret_path("x/critic-verdict.json"))

    t.done()


# ------------------------------------------------------------------------ main

def main():
    ap = argparse.ArgumentParser(prog="dmc-critic-verdict")
    ap.add_argument("command", nargs="?", choices=["validate"])
    ap.add_argument("arg", nargs="?", help="path (validate)")
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
            refuse(["VERDICT-UNREADABLE: file not found"])
        except (OSError, UnicodeError) as e:
            refuse(["VERDICT-UNREADABLE: %s" % e.__class__.__name__])
        if errs:
            refuse(errs)
        print("VALID: %s conforms to %s" % (a.arg, SCHEMA_ID))
        return

    die("usage: validate <path> | --self-test", 2)


if __name__ == "__main__":
    main()
