#!/usr/bin/env python3
"""dmc-verdict-gate.py — DMC v1.0 M5 Ring-0 start-work verdict-gate (P16).

The deterministic precondition a start-work path must clear: a critic-verdict must EXIST, be
schema-VALID (per dmc-critic-verdict.py), and be BOUND to the run's plan (its embedded `plan_hash`
must equal the hash the caller derived from the approved plan).

Invariant C11 (load-bearing): THE GATE OPENS NOTHING. It does not write, approve, or mutate
anything, and it is value-blind on the verdict DECISION — a well-formed, plan-bound `REJECT` (or
`NEEDS_CLARIFICATION`) PASSES THROUGH exactly like an `APPROVE`. The gate proves only that an
independent critic actually reviewed THIS plan; approval remains a P17 human-gate record. The gate
therefore has exactly two outcomes: REFUSE (exit 3) or PASS-THROUGH (exit 0). Layer disclosure:
this refusal is Ring-0 (deterministic); the OBLIGATION to invoke the gate before mutating is
Ring-2 skill prose until M6 wires the Ring-1 Stop/scope hooks.

Refusal conditions:
  - the referenced verdict file is absent;
  - it fails `dmc-critic-verdict validate` (invoked as a read-only subprocess — no import, so the
    validator stays independently deletable);
  - its `plan_hash` != the `--plan-hash` the caller supplied (binding failure).
Hardening refusals: a secret-shaped verdict path; a malformed `--plan-hash` argument.

Usage:
  gate --verdict <file> --plan-hash <hex>    ACCEPT => exit 0, REFUSE => exit 3, usage => exit 2.
  --self-test                                embedded section self-test.

House rules (v0.6.x / M3 lineage): stdlib-only, env-independent (no env reads), offline (no
network, no git), input-only (reads only the referenced verdict), value-blind (refusals name codes
only, never plan_hash values or verdict content), secret-path refused by path, fail-closed with
named reason codes and negative controls.
"""

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile

# Hash shape shared with dmc-critic-verdict.py / the M4 run-lifecycle (`<hex >=16>`).
HASH_RE = re.compile(r"^[0-9a-f]{16,}$")

# The sibling validator this gate shells out to. Co-located in bin/lib/; both ship in T010b.
VALIDATOR_NAME = "dmc-critic-verdict.py"


# ------------------------------------------------------------------- helpers

def die(msg, code=2):
    sys.stderr.write("dmc-verdict-gate: %s\n" % msg)
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


def _no_dup(pairs):
    """object_pairs_hook that rejects duplicate JSON keys (fail-closed on ambiguity)."""
    d = {}
    for k, v in pairs:
        if k in d:
            raise ValueError("duplicate JSON key: %r" % k)
        d[k] = v
    return d


def _validator_path():
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), VALIDATOR_NAME)


def _run_validator(verdict_path):
    """Invoke the sibling critic-verdict validator as a read-only subprocess. Returns its exit
    code: 0 == schema-valid, 3 == refused, anything else == the validator did not complete
    (missing module, crash) — all non-zero is treated fail-closed by the caller."""
    try:
        proc = subprocess.run(
            [sys.executable, _validator_path(), "validate", verdict_path],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
    except OSError:
        return 127
    return proc.returncode


def _load(verdict_path):
    """Read + JSON-parse the verdict (duplicate-key rejecting). Secret-path guarded by the caller."""
    with open(verdict_path, "r", encoding="utf-8", errors="strict") as f:
        return json.loads(f.read(), object_pairs_hook=_no_dup)


# --------------------------------------------------------------- gate

def gate_check(verdict_path, plan_hash):
    """Return a list of value-blind reason codes ([] == PASS-THROUGH). The gate opens nothing
    (C11): it only refuses or passes a valid, plan-bound critic-verdict through, and is value-blind
    on the verdict decision (APPROVE/REJECT/NEEDS_CLARIFICATION all pass when valid + bound)."""
    # Secret-shaped verdict path is refused up front (never opened).
    if is_secret_path(verdict_path):
        return ["GATE-SECRET-PATH: refused secret-shaped verdict path"]

    errs = []
    arg_ok = isinstance(plan_hash, str) and bool(HASH_RE.match(plan_hash))
    if not arg_ok:
        errs.append("GATE-BAD-PLAN-HASH-ARG: --plan-hash is not hash-shaped (hex >=16)")

    # Absence — nothing further to check.
    if not os.path.isfile(verdict_path):
        errs.append("GATE-VERDICT-ABSENT: no critic-verdict at the referenced path")
        return errs

    # Schema validity via the sibling validator (subprocess; deletable, import-free).
    rc = _run_validator(verdict_path)
    if rc == 3:
        errs.append("GATE-VERDICT-INVALID: referenced critic-verdict fails "
                    "dmc-critic-verdict validation")
        return errs
    if rc != 0:
        errs.append("GATE-VALIDATOR-ERROR: critic-verdict validator did not complete "
                    "(non-zero exit %d)" % rc)
        return errs

    # Binding: the verdict's embedded plan_hash must equal the caller-supplied plan hash.
    try:
        obj = _load(verdict_path)
    except (ValueError, OSError, UnicodeError):
        errs.append("GATE-VERDICT-UNREADABLE: referenced verdict not parseable")
        return errs
    embedded = obj.get("plan_hash") if isinstance(obj, dict) else None
    if not (isinstance(embedded, str) and HASH_RE.match(embedded)):
        errs.append("GATE-VERDICT-BAD-HASH: verdict plan_hash not hash-shaped")
    elif arg_ok and embedded != plan_hash:
        errs.append("GATE-PLAN-HASH-MISMATCH: verdict plan_hash != the run's plan_hash "
                    "(binding failure)")

    return errs


def gate_cli(verdict_path, plan_hash):
    errs = gate_check(verdict_path, plan_hash)
    if errs:
        refuse(errs)
    # PASS-THROUGH: the gate opened nothing; it only affirms a valid, plan-bound verdict exists.
    print("PASS: verdict gate — referenced critic-verdict is schema-valid and plan-bound "
          "(C11: no gate opened; verdict is advisory only)")
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


# Verdict fixtures built inline (no import of the validator — modules stay independent). The
# validator subprocess certifies them at gate time.
def _valid_verdict(plan_hash, verdict="APPROVE", blockers=None):
    o = {
        "schema": "dmc.critic-verdict.v1",
        "work_id": "dmc-v1-m5-orchestration",
        "plan_hash": plan_hash,
        "repo_hash": "b" * 40,
        "target_ref": ".harness/plans/dmc-v1-m5-orchestration.md",
        "verdict": verdict,
        "lenses": ["correctness", "scope"],
        "criteria_checked": [{"criterion_ref": "AC1", "result": "met", "note": "n"}],
        "blockers": blockers if blockers is not None else [],
        "advisory": True,
        "context_provenance": "fresh",
    }
    return o


def _write(td, obj, name="critic-verdict.json"):
    p = os.path.join(td, name)
    with open(p, "w", encoding="utf-8") as f:
        f.write(json.dumps(obj))
    return p


def selftest():
    t = ST("verdict-gate")
    good = "a" * 40
    other = "c" * 40

    with tempfile.TemporaryDirectory() as td:
        # G0 valid pair PASSES THROUGH (empty reason list).
        vp = _write(td, _valid_verdict(good))
        t.check("G0 valid pair (present + valid + plan-bound) PASSES", lambda: gate_check(vp, good) == [])

        # G1 C11: a well-formed, plan-bound REJECT (with a blocker) also PASSES — the gate is
        # value-blind on the decision; it opens nothing.
        rp = _write(td, _valid_verdict(good, verdict="REJECT",
                                       blockers=[{"id": "B1", "statement": "must change X",
                                                  "evidence_ref": "r"}]),
                    name="reject-verdict.json")
        t.check("G1 C11: plan-bound REJECT PASSES (gate is value-blind on the decision)",
                lambda: gate_check(rp, good) == [])

        # G2 plan-mandated negative control: no verdict file.
        missing = os.path.join(td, "does-not-exist.json")
        t.check("G2 negative control: absent verdict REFUSED",
                lambda: any(e.startswith("GATE-VERDICT-ABSENT") for e in gate_check(missing, good)))

        # G3 plan-mandated negative control: plan_hash mismatch.
        t.check("G3 negative control: plan_hash mismatch REFUSED",
                lambda: any(e.startswith("GATE-PLAN-HASH-MISMATCH") for e in gate_check(vp, other)))

        # G4 negative control: a schema-invalid verdict (advisory:false) REFUSED via the subprocess.
        bad = _valid_verdict(good)
        bad["advisory"] = False
        bp = _write(td, bad, name="invalid-verdict.json")
        t.check("G4 negative control: schema-invalid verdict REFUSED (validator subprocess)",
                lambda: any(e.startswith("GATE-VERDICT-INVALID") for e in gate_check(bp, good)))

        # G5 hardening: malformed --plan-hash argument.
        t.check("G5 negative control: malformed --plan-hash arg REFUSED",
                lambda: any(e.startswith("GATE-BAD-PLAN-HASH-ARG")
                            for e in gate_check(vp, "not-a-hash")))

        # G6 determinism.
        t.ok("G6 determinism", gate_check(vp, other) == gate_check(vp, other))

    # G7 hardening: secret-shaped verdict path refused by path (file never opened).
    t.ok("G7 negative control: secret-shaped verdict path REFUSED",
         any(e.startswith("GATE-SECRET-PATH") for e in gate_check("x/id_rsa", good)))

    # G8 the gate opens nothing: gate_check returns only reason lists, writes no file. Assert the
    # tempdir contained exactly the fixtures we wrote (no gate-side artifact) — proven by G0-G7
    # running read-only; here we assert the PASS path emits an empty reason list, not a grant token.
    with tempfile.TemporaryDirectory() as td2:
        vp2 = _write(td2, _valid_verdict(good))
        before = sorted(os.listdir(td2))
        _ = gate_check(vp2, good)
        after = sorted(os.listdir(td2))
        t.ok("G8 gate writes nothing (C11: opens nothing)", before == after)

    t.done()


# ------------------------------------------------------------------------ main

def main():
    ap = argparse.ArgumentParser(prog="dmc-verdict-gate")
    ap.add_argument("command", nargs="?", choices=["gate"])
    ap.add_argument("--verdict", metavar="FILE", help="path to the critic-verdict.json")
    ap.add_argument("--plan-hash", metavar="HEX", help="the run's plan_hash to bind against")
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args()

    if a.self_test:
        selftest()
        return

    if a.verdict is None or a.plan_hash is None:
        die("usage: gate --verdict <file> --plan-hash <hex> | --self-test", 2)
    gate_cli(a.verdict, a.plan_hash)


if __name__ == "__main__":
    main()
