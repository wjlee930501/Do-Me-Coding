#!/usr/bin/env python3
"""dmc-orchestration-linkcheck.py — DMC v1.0 M5 deterministic orchestration link-check (T010f).

Proves that no skill / agent / doc-banner references an orchestration artifact that does not
exist. Three fixed-regex reference classes are extracted from each scanned file and resolved:

  (a) dmc VERBS — inline-code and fenced-code `dmc <verb>` (or `bin/dmc <verb>`) spans, resolved
      against the dispatcher's own declared verb set. The verb set is parsed from `bin/dmc`'s
      single top-level `case "$cmd" in ... esac` block (the ONE source of truth for the verb
      surface): the arm patterns at case-depth 1 are the declared verbs. See `dispatcher_verbs`.
  (b) PATHS — `orchestration/<name>.json` and `.harness/schemas/<name>.schema.md` path references,
      resolved against the filesystem (root-relative).
  (c) ROLES — role *bindings* of the form `Role: `<id>`` (the machine-consumable registry binding
      the agents declare), resolved against `orchestration/roles.json` via `dmc-roles.py lookup`
      (exit 0 = resolves, exit 3 = absent). Prose display-name mentions in skills/docs are not
      role bindings; they point at the path-checked registry (class (b)) and are not resolved here.

Scanned surface (the real tree): `.claude/skills/*/SKILL.md`, `.claude/agents/*.md`, and the three
registry-pointer docs (DMC_AGENT_HANDOFF, DYNAMIC_DELEGATION, DMC_DELEGATION_HARNESS) whose banners
reference the registry. Test fixtures under tests/fixtures/orchestration/ are NOT part of the real
surface — the self-test points the same checker at them explicitly.

CLI:
  (no args) | check [--root DIR]   run the link-check over the real tree. Clean => exit 0; any
                                   dangling reference => exit 3 with each dangling ref NAMED.
  --self-test                      embedded section self-test (prints "[linkcheck] N PASS / M FAIL";
                                   exit 0 all-pass / 1 any-fail). Includes the plan's negative
                                   controls (a fixture skill referencing `dmc frobnicate`, a
                                   nonexistent schema path, an unregistered role — each REFUSED and
                                   named) and the arm-run-id pre-run (drives a fixture plan+verdict
                                   through `dmc verdict gate` -> `dmc run start` in a tempdir).

House rules (v0.6.x / M3-M5 lineage, mirrors bin/lib/dmc-roles.py): stdlib-only, env-independent
(no env reads), offline (no network; git is best-effort and confined to a tempdir), input-only,
value-blind (dangling refs are named by their extracted token; secret-shaped tokens are refused by
shape without being echoed), duplicate-JSON-key rejecting, secret-path refused by path, fail-closed.
Every cross-tool call (dmc-roles.py lookup, bin/dmc verdict gate / run start) is a read-only
subprocess, never an import, so this module stays independently deletable per the additive-rollback
contract.
"""

import argparse
import glob
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))                       # bin/lib
REPO_ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
BIN_DMC = os.path.normpath(os.path.join(HERE, "..", "dmc"))             # bin/dmc
ROLES_PY = os.path.join(HERE, "dmc-roles.py")

# The three registry-pointer docs whose banners the link-check also covers.
POINTER_DOCS = (
    "docs/DMC_AGENT_HANDOFF.md",
    "docs/DYNAMIC_DELEGATION.md",
    "docs/DMC_DELEGATION_HARNESS.md",
)

# ---- fixed extraction regexes (deterministic; documented above) ---------------------------------
# A dmc verb reference: `dmc <verb>` / `bin/dmc <verb>` with a real space (so `dmc.roles.v1` and
# `dmc-v0.3.8-...` do NOT match) and no left word-boundary bleed (so `subdmc run` does not match).
VERB_RE = re.compile(r"(?<![\w-])(?:bin/)?dmc[ \t]+([a-z][a-z0-9-]*)")
# Concrete orchestration / schema path references (flat basenames under fixed roots).
ORCH_PATH_RE = re.compile(r"orchestration/[A-Za-z0-9_.-]+\.json")
SCHEMA_PATH_RE = re.compile(r"\.harness/schemas/[A-Za-z0-9_.-]+\.schema\.md")
# A role BINDING cue: `Role: `<id>`` (case-insensitive on the label; the id is an inline-code token).
ROLE_BIND_RE = re.compile(r"(?i)\brole:\s*`([a-z][a-z0-9-]*)`")

HASH_RE = re.compile(r"^[0-9a-f]{16,}$")


# ------------------------------------------------------------------- helpers (house style)

def die(msg, code=2):
    sys.stderr.write("dmc-linkcheck: %s\n" % msg)
    sys.exit(code)


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


def sweep_pycache():
    shutil.rmtree(os.path.join(HERE, "__pycache__"), ignore_errors=True)


# ------------------------------------------------------------------- dispatcher verb set

def dispatcher_verbs(dmc_text):
    """Parse bin/dmc's single top-level `case "$cmd" in ... esac` block and return the set of
    declared verbs (the arm patterns at case-depth 1). Nested `case ... in` blocks (the per-verb
    sub-dispatch) are tracked by depth and excluded, so only the top-level command surface is
    returned. The wildcard `*` arm is dropped. This is the ONE source of truth for the verb set."""
    verbs = set()
    depth = 0
    started = False
    arm_re = re.compile(r"^\s*([A-Za-z0-9_.\-][A-Za-z0-9_.\-|]*)\)")
    open_case_re = re.compile(r"\bcase\b\s+.*\bin\b")
    for line in dmc_text.splitlines():
        if not started:
            if re.search(r'case\s+"\$cmd"\s+in', line):
                started = True
                depth = 1
            continue
        if line.strip() == "esac":
            depth -= 1
            if depth == 0:
                break
            continue
        if depth == 1:
            m = arm_re.match(line)
            if m:
                for pat in m.group(1).split("|"):
                    pat = pat.strip()
                    if pat and pat != "*":
                        verbs.add(pat)
        if open_case_re.search(line):
            depth += 1
    return verbs


# ------------------------------------------------------------------- reference extraction

def code_regions(text):
    """Concatenate every markdown code region (fenced ```...``` blocks + inline `...` spans). Verb
    references are only trusted inside code regions, so prose mentions of the project name (e.g.
    'DMC orchestration' in a heading) never become spurious verb references."""
    regions = re.findall(r"```.*?```", text, re.DOTALL)
    without_fenced = re.sub(r"```.*?```", " ", text, flags=re.DOTALL)
    regions.extend(re.findall(r"`[^`\n]+`", without_fenced))
    return "\n".join(regions)


def extract_verbs(text):
    return [m.group(1) for m in VERB_RE.finditer(code_regions(text))]


def extract_paths(text):
    return ORCH_PATH_RE.findall(text) + SCHEMA_PATH_RE.findall(text)


def extract_roles(text):
    return [m.group(1) for m in ROLE_BIND_RE.finditer(text)]


# ------------------------------------------------------------------- resolvers

def resolve_role(role_id):
    """Resolve a role id against the real orchestration/roles.json via the dmc-roles.py lookup
    subprocess (the T010a contract: exit 0 = resolves, exit 3 = absent/invalid). Any subprocess
    failure degrades to 'does not resolve' (fail-closed)."""
    try:
        r = subprocess.run([sys.executable, "-B", ROLES_PY, "lookup", role_id],
                           capture_output=True, text=True, timeout=60)
    except Exception:  # noqa: BLE001 — a spawn failure is a non-resolution, never an abort
        return False
    return r.returncode == 0


def check_file(path, root, verbset, rel=None):
    """Return a list of value-blind dangling-reference reasons for one scanned file (empty=clean).
    Each reason NAMES the offending extracted token and its source file."""
    reasons = []
    where = rel if rel is not None else os.path.relpath(path, root)
    text = read_text(path)

    for verb in extract_verbs(text):
        if verb not in verbset:
            reasons.append("LINK-UNKNOWN-VERB: %s references `dmc %s` (not a declared bin/dmc verb)"
                           % (where, verb))

    for ref in extract_paths(text):
        if is_secret_path(ref):
            reasons.append("LINK-SECRET-REF: %s references a secret-shaped path (not echoed)" % where)
            continue
        if not os.path.exists(os.path.join(root, ref)):
            reasons.append("LINK-DANGLING-PATH: %s references %s (no such file)" % (where, ref))

    for role in extract_roles(text):
        if not resolve_role(role):
            reasons.append("LINK-UNKNOWN-ROLE: %s binds role `%s` (absent from orchestration/roles.json)"
                           % (where, role))
    return reasons


def gather_targets(root):
    """The real scanned surface: every skill SKILL.md, every agent .md, and the three pointer docs."""
    targets = []
    targets += sorted(glob.glob(os.path.join(root, ".claude", "skills", "*", "SKILL.md")))
    targets += sorted(glob.glob(os.path.join(root, ".claude", "agents", "*.md")))
    for d in POINTER_DOCS:
        p = os.path.join(root, d)
        if os.path.exists(p):
            targets.append(p)
    return targets


def link_check(root):
    """Scan the whole real surface; return (files_scanned, dangling_reasons)."""
    verbset = dispatcher_verbs(read_text(BIN_DMC))
    targets = gather_targets(root)
    reasons = []
    for path in targets:
        reasons.extend(check_file(path, root, verbset))
    return targets, reasons


# ------------------------------------------------------------------- self-test harness

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
        return bool(cond)

    def check(self, label, thunk):
        try:
            cond = bool(thunk())
        except Exception as e:  # noqa: BLE001 — a broken fixture must FAIL, never abort the run
            self.ok("%s [EXC:%s]" % (label, e.__class__.__name__), False)
            return False
        return self.ok(label, cond)

    def done(self):
        print("[%s] %d PASS / %d FAIL" % (self.name, self.passed, self.failed))
        sys.exit(0 if self.failed == 0 else 1)


FIX_DIR = os.path.join(REPO_ROOT, "tests", "fixtures", "orchestration")


def _reasons_for(fixture_name, verbset):
    """Run the checker over one committed fixture file (read-only) and return its dangling reasons."""
    path = os.path.join(FIX_DIR, fixture_name)
    return check_file(path, REPO_ROOT, verbset)


def real_repo_porcelain():
    """Best-effort `git status --porcelain` of the REAL repo; None if git is unavailable."""
    git = shutil.which("git")
    if not git:
        return None
    try:
        r = subprocess.run([git, "-C", REPO_ROOT, "status", "--porcelain"],
                           capture_output=True, timeout=20)
        return r.stdout if r.returncode == 0 else None
    except Exception:  # noqa: BLE001
        return None


def _git_id(root, *args):
    """git with a self-contained identity so a bare CI host needs no ambient user.name/email."""
    return subprocess.run(["git", "-C", root, "-c", "user.name=dmc", "-c", "user.email=dmc@x",
                           "-c", "commit.gpgsign=false", *args], capture_output=True, text=True)


def _run_dmc(*args):
    return subprocess.run(["bash", BIN_DMC, *args], capture_output=True, text=True, timeout=120)


def arm_run_prerun(t):
    """Arm-run-id pre-run (plan Acceptance Criterion 4): drive the committed fixture plan+verdict
    through `bin/dmc verdict gate` -> `bin/dmc run start` inside a disposable tempdir git repo, and
    assert a `.harness/runs/<run-id>/` directory appears IN THE TEMPDIR while the REAL repo's
    `git status --porcelain` stays byte-identical before/after."""
    plan_fx = os.path.join(FIX_DIR, "arm-run", "plan.md")
    verdict_fx = os.path.join(FIX_DIR, "arm-run", "critic-verdict.json")

    with open(plan_fx, "rb") as f:
        plan_bytes = f.read()
    plan_hash = hashlib.sha256(plan_bytes).hexdigest()
    vobj = json.loads(read_text(verdict_fx))

    # A0 fixture integrity: the committed verdict's plan_hash binds the committed plan (sha256).
    t.ok("A0 committed critic-verdict.plan_hash == sha256(committed plan) (fixture integrity)",
         vobj.get("plan_hash") == plan_hash)

    if not shutil.which("git"):
        t.ok("A-git git available for the arm-run pre-run (SKIP-graceful if absent)", True)
        return

    before = real_repo_porcelain()
    tmp = tempfile.mkdtemp(prefix="dmc-linkcheck-armrun-")
    try:
        subprocess.run(["git", "init", "-q", tmp], capture_output=True)
        tplan = os.path.join(tmp, "plan.md")
        with open(tplan, "wb") as f:
            f.write(plan_bytes)
        tverdict = os.path.join(tmp, "critic-verdict.json")
        # Regenerate the verdict in the tempdir with plan_hash re-derived at runtime (robust to any
        # later reformat of the fixture plan); the committed pair is asserted consistent by A0.
        vobj_tmp = dict(vobj)
        vobj_tmp["plan_hash"] = plan_hash
        with open(tverdict, "w", encoding="utf-8") as f:
            f.write(json.dumps(vobj_tmp))
        _git_id(tmp, "add", "-A")
        _git_id(tmp, "commit", "-q", "-m", "arm-run fixture init")

        g = _run_dmc("verdict", "gate", "--verdict", tverdict, "--plan-hash", plan_hash)
        t.ok("A1 `dmc verdict gate` PASSES the valid plan+verdict pair (exit 0)", g.returncode == 0)

        g_bad = _run_dmc("verdict", "gate", "--verdict", tverdict, "--plan-hash", "0" * 64)
        t.ok("A1b `dmc verdict gate` REFUSES a mismatched plan_hash (exit 3)", g_bad.returncode == 3)

        r = _run_dmc("run", "start", "--plan", tplan, "--root", tmp)
        runs = os.path.join(tmp, ".harness", "runs")
        ptr = os.path.join(runs, "current-run-id")
        run_id = ""
        if os.path.isfile(ptr):
            with open(ptr, encoding="utf-8") as f:
                run_id = f.read().strip()
        run_dir = os.path.join(runs, run_id) if run_id else ""
        armed = (r.returncode == 0 and run_id != "" and os.path.isdir(run_dir)
                 and os.path.isfile(os.path.join(run_dir, "run.json")))
        t.ok("A2 `dmc run start` arms a run-id directory .harness/runs/<run-id>/ in the tempdir", armed)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    after = real_repo_porcelain()
    t.ok("A3 REAL repo `git status --porcelain` byte-identical before/after the pre-run (or git absent)",
         before == after)


def selftest():
    t = ST("linkcheck")
    verbset = dispatcher_verbs(read_text(BIN_DMC))

    # L0 the dispatcher verb-set parse includes the four M5 verbs + the load-bearing core verbs.
    t.ok("L0 dispatcher verb set includes the four M5 verbs (roles/verdict/delegation/linkcheck)",
         {"roles", "verdict", "delegation", "linkcheck"} <= verbset)
    t.ok("L0b dispatcher verb set includes the pre-existing core verbs",
         {"run", "validate", "selftest", "orient", "mirror-check"} <= verbset)

    # L1 positive control: the REAL tree link-checks clean (0 dangling).
    targets, reasons = link_check(REPO_ROOT)
    t.ok("L1 real tree (skills + agents + 3 pointer docs) link-checks CLEAN (0 dangling)",
         reasons == [])
    t.ok("L1b real tree scanned a non-trivial surface (>= 9 files)", len(targets) >= 9)

    # L2-L4 negative controls: each seeded dangling reference is REFUSED and NAMED.
    r_verb = _reasons_for("linkcheck-neg-verb.md", verbset)
    t.ok("L2 seeded `dmc frobnicate` REFUSED and named",
         any("LINK-UNKNOWN-VERB" in x and "frobnicate" in x for x in r_verb))

    r_path = _reasons_for("linkcheck-neg-path.md", verbset)
    t.ok("L3 seeded nonexistent schema path REFUSED and named",
         any("LINK-DANGLING-PATH" in x and "nonexistent" in x for x in r_path))

    r_role = _reasons_for("linkcheck-neg-role.md", verbset)
    t.ok("L4 seeded unregistered role REFUSED and named",
         any("LINK-UNKNOWN-ROLE" in x and "frobnicator-nonexistent" in x for x in r_role))

    # L5 a fixture seeding ALL THREE dangling classes at once names all three.
    r_all = _reasons_for("linkcheck-neg-all.md", verbset)
    t.ok("L5 combined negative fixture names all three dangling classes",
         any("LINK-UNKNOWN-VERB" in x for x in r_all)
         and any("LINK-DANGLING-PATH" in x for x in r_all)
         and any("LINK-UNKNOWN-ROLE" in x for x in r_all))

    # L6 positive control fixture (clean references) link-checks clean.
    r_pos = _reasons_for("linkcheck-pos.md", verbset)
    t.ok("L6 positive fixture (all refs resolve) link-checks CLEAN", r_pos == [])

    # L7 determinism: same input -> identical reason list.
    t.ok("L7 determinism (identical input -> identical reasons)",
         _reasons_for("linkcheck-neg-all.md", verbset) == r_all)

    # L8 role resolver composes with the real registry: a real id resolves, a fake id does not.
    t.ok("L8 role resolver: real id resolves, fake id does not",
         resolve_role("implementer") and not resolve_role("frobnicator-nonexistent"))

    # L9 secret-path refusal is by path (never opens the file).
    t.ok("L9 secret-shaped path filter", is_secret_path(".claude/agents/.env")
         and is_secret_path("x/id_rsa") and not is_secret_path(".claude/agents/critic.md"))

    # A* arm-run-id pre-run (tempdir; real repo untouched).
    arm_run_prerun(t)

    sweep_pycache()
    t.done()


# ------------------------------------------------------------------------ main

def main():
    ap = argparse.ArgumentParser(prog="dmc-linkcheck")
    ap.add_argument("command", nargs="?", choices=["check"], default="check")
    ap.add_argument("--root", metavar="DIR", default=REPO_ROOT,
                    help="repository root to scan (default: the repo containing bin/)")
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args()

    if a.self_test:
        selftest()
        return

    root = os.path.abspath(a.root)
    try:
        targets, reasons = link_check(root)
    except FileNotFoundError as e:
        die("unreadable input: %s" % e.__class__.__name__, 3)
    if reasons:
        for r in reasons:
            print("REFUSED: %s" % r)
        print("dmc linkcheck: %d dangling reference(s) across %d file(s)" % (len(reasons), len(targets)),
              file=sys.stderr)
        sys.exit(3)
    print("OK: linkcheck clean — %d file(s) scanned, every dmc-verb / artifact-path / role "
          "reference resolves" % len(targets))
    sys.exit(0)


if __name__ == "__main__":
    main()
