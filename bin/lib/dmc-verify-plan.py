#!/usr/bin/env python3
"""dmc-verify-plan.py — DMC v1.0 M4 verification-planner promotion (P9; architecture §P9).

Promotes the shipped v0.5.5 verification planner to a run-fed interface. It translates
`acceptance.json` (P8) + `radius.json` (P5) into v0.5.5 `--from` facts, invokes the COPIED
`bin/lib/dmc-v0.5.5-verification-planner.sh` as a read-only subprocess, and consumes its verdict —
verbatim — into `runs/<run-id>/verify-plan.json`. The v0.5.5 planning logic is REUSED BY
INVOCATION and never re-implemented or forked here; this tool only translates in and consumes out.

Coverage linkage is enforced fail-closed: every radius entry must resolve to >=1 acceptance check
(by shared check_id or by an acceptance check whose radius_links carry the entry path). A coverage
gap is REFUSED. A stored plan is self-checked by re-running the copied planner on the stored facts
and asserting the output is byte-identical to the stored verdict (no silent divergence).

Subcommands:
  compile --acceptance FILE --radius FILE [--planner FILE] [--out FILE] [--prev-hash HEX]
                                          translate + invoke v0.5.5 + write verify-plan.json
  --validate FILE                          fail-closed validator (VALID=>0, REFUSED=>3);
                                           re-runs the copied planner to detect verdict divergence
  --self-test                              hermetic section self-test (tempdir only)

House rules (v0.6.x / M2-M4 lineage): stdlib-only python (the v0.5.5 call is a bash subprocess of
the copied file — allowed), deterministic, env-independent (no env reads), offline (no network),
fail-closed with named reason codes + negative controls, value-blind refusals, secret paths refused
by path only. Advisory tier: the runtime enforcement floor stays the hooks (M6).
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

SCHEMA = "dmc.verify-plan.v1"
ACCEPTANCE_SCHEMA = "dmc.acceptance.v1"
RADIUS_SCHEMA = "dmc.radius.v1"
GENESIS = "0" * 64
HASH_RE = re.compile(r"^[0-9a-f]{16,}$")
PLANNER_NAME = "dmc-v0.5.5-verification-planner.sh"
FACTS_KEYS = ("changed_paths", "lane", "protected_surface", "prior_findings", "test_failures")
PROTECTED_LANDMARKS = {"enforcement", "contract", "release"}

SECRET_ALLOW_BASENAMES = {".env.example", ".env.sample", ".env.template", ".env.dist"}


# ------------------------------------------------------------------- helpers

def die(msg, code=2):
    sys.stderr.write("dmc-verify-plan: %s\n" % msg)
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
    if is_secret_path(path):
        die("refused: secret-shaped input path", 3)
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f, object_pairs_hook=hook)


def sibling(name):
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), name)


# ---------------------------------------------------------- reuse-by-invocation

def planner_run(planner_path, facts):
    """Invoke the COPIED v0.5.5 planner on `facts` as a read-only subprocess; verbatim capture.

    Returns (exit_code, stdout_text). The planner's verdict flows through UNMODIFIED — we only
    write the facts to a temp file and capture its stdout; no parsing/rewriting of the verdict.
    """
    tmp = tempfile.mkdtemp(prefix="dmc-vp-facts-")
    try:
        fp = os.path.join(tmp, "facts.json")
        with open(fp, "w", encoding="utf-8") as f:
            f.write(json.dumps(facts, sort_keys=True, separators=(",", ":")))
        r = subprocess.run(["bash", planner_path, "--from", fp],
                           capture_output=True, text=True, timeout=30)
        return r.returncode, r.stdout
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def gate_acceptance(acc_path):
    """Gate the acceptance input through the P8 validator (single source of truth); fail-closed."""
    tool = sibling("dmc-acceptance.py")
    if not os.path.isfile(tool):
        refuse(["VP-ACCEPTANCE-TOOL-MISSING: dmc-acceptance.py sibling not found"])
    r = subprocess.run([sys.executable, "-B", tool, "--validate", acc_path],
                       capture_output=True, text=True, timeout=30)
    if r.returncode != 0:
        refuse(["VP-ACCEPTANCE-INVALID: acceptance.json failed the P8 validator (exit %d)"
                % r.returncode])


# ------------------------------------------------------------- facts translate

def translate_facts(radius):
    """Translate a radius.json into the v0.5.5 `--from` facts shape (string-valued, CLI-parity)."""
    scope = radius.get("scope") or []
    scope = sorted({p for p in scope if isinstance(p, str) and p})
    classes = {e.get("landmark_class") for e in (radius.get("entries") or [])
               if isinstance(e, dict)}
    protected = bool(classes & PROTECTED_LANDMARKS)
    return {
        "changed_paths": ",".join(scope),
        "lane": "protected-surface" if protected else "",
        "protected_surface": "true" if protected else "false",
        "prior_findings": "0",
        "test_failures": "0",
    }


def resolve_coverage(acceptance, radius):
    """Resolve each radius entry to acceptance checks; returns (coverage_list, gap_paths).

    An entry resolves if its check_ids intersect acceptance check_ids, OR an acceptance check's
    radius_links carry the entry path (architecture §P5: 'every entry must reference >=1 check id
    in acceptance.json' — satisfied by id-match or by the reverse path link).
    """
    checks = acceptance.get("checks") or []
    acc_ids = {c.get("check_id") for c in checks if isinstance(c, dict)}
    coverage, gaps = [], []
    for e in (radius.get("entries") or []):
        if not isinstance(e, dict):
            continue
        path = e.get("path")
        ids = {i for i in (e.get("check_ids") or []) if isinstance(i, str) and i}
        resolved = sorted(ids & acc_ids)
        if not resolved and isinstance(path, str):
            resolved = sorted(c["check_id"] for c in checks
                              if isinstance(c, dict) and path in (c.get("radius_links") or []))
        if not resolved:
            gaps.append(path)
        coverage.append({"path": path, "radius_check_ids": sorted(ids), "resolved_by": resolved})
    return coverage, gaps


def compile_verify_plan(acc_path, radius_path, planner_path, prev_hash):
    """Translate -> invoke copied v0.5.5 -> consume verdict into a verify-plan doc; fail-closed."""
    if not os.path.isfile(acc_path):
        refuse(["VP-ACCEPTANCE-NOT-FOUND: acceptance file does not exist"])
    if not os.path.isfile(radius_path):
        refuse(["VP-RADIUS-NOT-FOUND: radius file does not exist"])
    if not os.path.isfile(planner_path):
        refuse(["VP-PLANNER-MISSING: copied v0.5.5 planner not found at the expected path"])

    gate_acceptance(acc_path)
    acceptance = load_json_strict(acc_path)
    radius = load_json_strict(radius_path)
    if radius.get("schema") != RADIUS_SCHEMA:
        refuse(["VP-RADIUS-BAD-SCHEMA: radius schema != %s" % RADIUS_SCHEMA])
    if not isinstance(radius.get("entries"), list) or not radius["entries"]:
        refuse(["VP-RADIUS-EMPTY: radius has no entries"])

    # coverage linkage (fail-closed).
    coverage, gaps = resolve_coverage(acceptance, radius)
    if gaps:
        refuse(["VP-COVERAGE-GAP: radius entry resolves to no acceptance check (path=%s)" % g
                for g in gaps])

    # translate + invoke the copied planner; consume its verdict verbatim.
    facts = translate_facts(radius)
    exit_code, plan_text = planner_run(planner_path, facts)
    if exit_code != 0:
        refuse(["VP-PLANNER-REFUSED: the copied v0.5.5 planner refused the facts (exit %d)"
                % exit_code])

    doc = {
        "schema": SCHEMA,
        "work_id": acceptance.get("work_id"),
        "plan_hash": acceptance.get("plan_hash"),
        "repo_hash": acceptance.get("repo_hash"),
        "planner_tool": PLANNER_NAME,
        "planner_exit": exit_code,
        "facts": facts,
        "plan_text": plan_text,
        "coverage": coverage,
        "immutable": True,
        "prev_hash": prev_hash or canon_hash(acceptance),
    }
    errs = validate_verify_plan(doc, planner_path=planner_path)
    if errs:
        refuse(errs)   # self-refusal: never emit an artifact that fails its own validator
    return doc


# ----------------------------------------------------------------- validator

def validate_verify_plan(doc, planner_path=None):
    """Fail-closed verify-plan.json validator. Returns reason codes ([] == VALID).

    When a planner path is available, re-runs the copied planner on the stored facts and requires
    byte-identical output (VP-DIVERGENCE otherwise) — the no-silent-divergence guarantee.
    """
    if not isinstance(doc, dict):
        return ["VP-NOT-OBJECT: verify-plan.json root is not a JSON object"]
    errs = []
    if doc.get("schema") != SCHEMA:
        errs.append("VP-BAD-SCHEMA: schema != %s" % SCHEMA)
    if not (isinstance(doc.get("work_id"), str) and doc["work_id"].strip()):
        errs.append("VP-MISSING-BINDING: work_id missing/empty")
    for hk in ("plan_hash", "repo_hash"):
        if not (isinstance(doc.get(hk), str) and HASH_RE.match(doc.get(hk, ""))):
            errs.append("VP-BAD-HASH: %s not hash-shaped" % hk)
    if doc.get("immutable") is not True:
        errs.append("VP-NOT-IMMUTABLE: immutable must be boolean true")
    pv = doc.get("prev_hash")
    if not (isinstance(pv, str) and (pv == GENESIS or HASH_RE.match(pv))):
        errs.append("VP-BAD-PREV-HASH: prev_hash not hash-shaped (hex>=16 or genesis)")
    if doc.get("planner_tool") != PLANNER_NAME:
        errs.append("VP-BAD-PLANNER-TOOL: planner_tool != %s" % PLANNER_NAME)
    if doc.get("planner_exit") != 0:
        errs.append("VP-PLANNER-NOT-OK: planner_exit must be 0 (a refused plan is not stored)")
    facts = doc.get("facts")
    if not isinstance(facts, dict) or any(k not in facts for k in FACTS_KEYS):
        errs.append("VP-BAD-FACTS: facts must carry all v0.5.5 keys %s" % "|".join(FACTS_KEYS))
        facts = None
    if not (isinstance(doc.get("plan_text"), str) and doc["plan_text"].strip()):
        errs.append("VP-EMPTY-PLAN-TEXT: plan_text (the copied verdict) missing/empty")
    cov = doc.get("coverage")
    if not isinstance(cov, list) or not cov:
        errs.append("VP-EMPTY-COVERAGE: coverage must be a non-empty array")
    else:
        for i, c in enumerate(cov):
            if not isinstance(c, dict) or not (isinstance(c.get("resolved_by"), list)
                                               and c["resolved_by"]):
                errs.append("VP-COVERAGE-GAP: coverage[%d] resolves to no acceptance check" % i)
    if errs:
        return errs
    # divergence check: the stored verdict must reproduce from the stored facts (no silent fork).
    if planner_path and os.path.isfile(planner_path) and facts is not None:
        rexit, rtext = planner_run(planner_path, {k: facts[k] for k in FACTS_KEYS})
        if rexit != 0 or rtext != doc["plan_text"]:
            errs.append("VP-DIVERGENCE: stored verdict differs from re-running the copied planner "
                        "on the stored facts (silent divergence)")
    return errs


# ------------------------------------------------------------------ storage

def write_doc(doc, out_path):
    d = os.path.dirname(os.path.abspath(out_path))
    os.makedirs(d, exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(json.dumps(doc, sort_keys=True, indent=2, ensure_ascii=False) + "\n")
    return out_path


# ------------------------------------------------------------------ self-test

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


def _fixtures_dir():
    return os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                         "..", "..", "tests", "fixtures", "run"))


def _real_repo_porcelain():
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


def _run_cli(*args):
    return subprocess.run([sys.executable, "-B", os.path.abspath(__file__), *args],
                          capture_output=True, text=True)


def _compile_acceptance(plan, orient, radius, out_dir):
    args = [sys.executable, "-B", sibling("dmc-acceptance.py"), "compile",
            "--plan", plan, "--orientation", orient, "--out-dir", out_dir]
    if radius:
        args += ["--radius", radius]
    subprocess.run(args, capture_output=True, text=True, check=False)
    return os.path.join(out_dir, "acceptance.json")


def _sweep_pycache():
    d = os.path.join(os.path.dirname(os.path.abspath(__file__)), "__pycache__")
    shutil.rmtree(d, ignore_errors=True)


def selftest():
    t = ST("verify-plan")
    before = _real_repo_porcelain()
    fx = _fixtures_dir()
    plan = os.path.join(fx, "plan.md")
    orient = os.path.join(fx, "orientation.json")
    radius = os.path.join(fx, "radius.json")
    planner = sibling(PLANNER_NAME)
    tmp = tempfile.mkdtemp(prefix="dmc-vp-")
    try:
        # -- happy path: acceptance WITH radius resolves coverage by path ----------------------
        acc = _compile_acceptance(plan, orient, radius, os.path.join(tmp, "acc"))
        doc = compile_verify_plan(acc, radius, planner, None)
        t.ok("V1 compile emits a valid verify-plan.json from the committed fixture",
             validate_verify_plan(doc, planner_path=planner) == [] and doc["schema"] == SCHEMA)
        t.ok("V2 coverage: every radius entry resolves to >=1 acceptance check",
             doc["coverage"] and all(c["resolved_by"] for c in doc["coverage"]))
        t.ok("V3 facts carry all v0.5.5 keys, string-valued (CLI parity)",
             all(k in doc["facts"] and isinstance(doc["facts"][k], str) for k in FACTS_KEYS))

        # -- PROOF OF REUSE: the stored verdict is byte-identical to a direct v0.5.5 call -------
        direct_exit, direct_text = planner_run(planner, {k: doc["facts"][k] for k in FACTS_KEYS})
        t.ok("V4 proof-of-reuse: stored plan_text == direct copied-planner output (verbatim, no fork)",
             direct_exit == 0 and direct_text == doc["plan_text"] and doc["planner_exit"] == 0)

        # -- linkage round-trip: stored facts reproduce the stored verdict ---------------------
        t.ok("V5 round-trip: re-running the copied planner on stored facts matches stored verdict",
             validate_verify_plan(doc, planner_path=planner) == [])

        # -- determinism -----------------------------------------------------------------------
        doc2 = compile_verify_plan(acc, radius, planner, None)
        t.ok("V6 deterministic: identical inputs => byte-identical artifact",
             json.dumps(doc2, sort_keys=True) == json.dumps(doc, sort_keys=True))

        # -- NEGATIVE: coverage gap (acceptance compiled WITHOUT radius) is REFUSED -------------
        acc_norad = _compile_acceptance(plan, orient, None, os.path.join(tmp, "accn"))
        r_gap = _run_cli("compile", "--acceptance", acc_norad, "--radius", radius,
                         "--out", os.path.join(tmp, "gap", "verify-plan.json"))
        t.ok("V7 NEG coverage gap (no acceptance check resolves a radius entry) REFUSED exit 3",
             r_gap.returncode == 3 and "VP-COVERAGE-GAP" in r_gap.stdout)

        # -- NEGATIVE: tampered stored verdict => divergence REFUSED ---------------------------
        tampered = dict(doc, plan_text=doc["plan_text"] + "\nINJECTED LINE")
        t.ok("V8 NEG tampered plan_text (verdict divergence) REFUSED by validator",
             any(e.startswith("VP-DIVERGENCE")
                 for e in validate_verify_plan(tampered, planner_path=planner)))

        # -- NEGATIVE: tampered facts => the stored verdict no longer reproduces ----------------
        # a docs path classifies differently (markdown checks, not the maximal set), so re-running
        # the copied planner on the tampered facts yields a verdict that diverges from the stored one.
        badfacts = dict(doc, facts=dict(doc["facts"], changed_paths="docs/readme.md",
                                        lane="docs-only"))
        t.ok("V9 NEG tampered facts (stored verdict no longer reproduces) REFUSED",
             any(e.startswith("VP-DIVERGENCE")
                 for e in validate_verify_plan(badfacts, planner_path=planner)))

        # -- structural validator negative controls --------------------------------------------
        t.ok("V10 NEG empty coverage REFUSED",
             any(e.startswith("VP-EMPTY-COVERAGE")
                 for e in validate_verify_plan(dict(doc, coverage=[]))))
        t.ok("V11 NEG unresolved coverage entry REFUSED",
             any(e.startswith("VP-COVERAGE-GAP") for e in validate_verify_plan(
                 dict(doc, coverage=[{"path": "x", "radius_check_ids": [], "resolved_by": []}]))))
        t.ok("V12 NEG immutable != true REFUSED",
             any(e.startswith("VP-NOT-IMMUTABLE")
                 for e in validate_verify_plan(dict(doc, immutable=False))))
        t.ok("V13 NEG planner_exit != 0 REFUSED",
             any(e.startswith("VP-PLANNER-NOT-OK")
                 for e in validate_verify_plan(dict(doc, planner_exit=2))))
        t.ok("V14 NEG missing facts key REFUSED",
             any(e.startswith("VP-BAD-FACTS") for e in validate_verify_plan(
                 dict(doc, facts={"changed_paths": "x"}))))

        # -- CLI exit-code contract ------------------------------------------------------------
        good_path = write_doc(doc, os.path.join(tmp, "good", "verify-plan.json"))
        r_ok = _run_cli("--validate", good_path)
        bad_path = os.path.join(tmp, "bad.json")
        with open(bad_path, "w", encoding="utf-8") as f:
            f.write(json.dumps(dict(doc, coverage=[])))
        r_no = _run_cli("--validate", bad_path)
        t.ok("V15 CLI --validate: valid=>0, invalid=>3",
             r_ok.returncode == 0 and r_no.returncode == 3)

        # -- env independence ------------------------------------------------------------------
        r_env = subprocess.run([sys.executable, "-B", os.path.abspath(__file__),
                                "--validate", good_path], capture_output=True, text=True,
                               env={"PATH": os.environ.get("PATH", ""),
                                    "GLM_API_KEY": "x", "DMC_VERIFY": "y"})
        t.ok("V16 env-independent: --validate identical under injected env",
             r_env.returncode == 0 and r_env.stdout == r_ok.stdout)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
        _sweep_pycache()

    after = _real_repo_porcelain()
    t.ok("V17 real repo git status --porcelain byte-identical before/after (or git absent)",
         before == after)
    t.done()


# ------------------------------------------------------------------------ main

def main():
    ap = argparse.ArgumentParser(prog="dmc-verify-plan")
    ap.add_argument("command", nargs="?", choices=["compile"])
    ap.add_argument("--acceptance", metavar="FILE")
    ap.add_argument("--radius", metavar="FILE")
    ap.add_argument("--planner", metavar="FILE", default=sibling(PLANNER_NAME))
    ap.add_argument("--out", metavar="FILE")
    ap.add_argument("--prev-hash", dest="prev_hash", metavar="HEX")
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
            refuse(["VP-UNREADABLE: file not found"])
        except Exception as e:
            refuse(["VP-UNREADABLE: %s" % e.__class__.__name__])
        planner = a.planner if os.path.isfile(a.planner) else None
        errs = validate_verify_plan(doc, planner_path=planner)
        if errs:
            refuse(errs)
        print("VALID: %s conforms to %s" % (a.validate, SCHEMA))
        return

    if a.command == "compile":
        if not (a.acceptance and a.radius):
            die("compile requires --acceptance FILE and --radius FILE", 2)
        out = a.out or os.path.join(os.path.dirname(os.path.abspath(a.acceptance)),
                                    "verify-plan.json")
        doc = compile_verify_plan(a.acceptance, a.radius, a.planner, a.prev_hash)
        path = write_doc(doc, out)
        print("wrote: %s" % path)
        print("coverage_entries: %d" % len(doc["coverage"]))
        return

    die("usage: dmc-verify-plan (compile --acceptance FILE --radius FILE [--planner FILE] "
        "[--out FILE]) | --validate FILE | --self-test", 2)


if __name__ == "__main__":
    main()
