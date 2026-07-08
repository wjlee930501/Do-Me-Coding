#!/usr/bin/env python3
"""dmc-repo-intel.py — DMC v1.0 M2 Repository Intelligence core (P1/P2/P4/P5).

Subcommands: orient | landmarks | depsurface | radius — each with generate (default),
--validate FILE (fail-closed instance validator; VALID=>0, REFUSED=>3), and --self-test.

House rules (v0.6.x lineage): deterministic (sorted keys/lists, no wall-clock values),
env-independent output, offline (no network), fail-closed validators with negative controls,
self-tests write only under mktemp, secret-bearing paths excluded by PATH ONLY (never opened),
duplicate-key-rejecting JSON loads. Advisory tier: the enforcement floor stays the hooks.
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

SCHEMAS = {
    "orient": "dmc.orientation.v1",
    "landmarks": "dmc.landmarks.v1",
    "depsurface": "dmc.depsurface.v1",
    "radius": "dmc.radius.v1",
}
CLASSES = ["enforcement", "contract", "release", "data", "ordinary"]
DEPSURFACE_NOTE = "regex tier; known-shapes-only; not a completeness guarantee"
LANDMARK_SEED = "heuristics+dmc-protected-union-v1"
SKIP_DIRS = {".git", "node_modules", "__pycache__", ".venv", "venv", "dist", "build",
             ".pytest_cache", ".mypy_cache", ".DS_Store"}
LANG_EXTS = {".py": "py", ".js": "js", ".mjs": "js", ".cjs": "js", ".ts": "js",
             ".tsx": "js", ".jsx": "js", ".sh": "sh", ".bash": "sh"}
COUNT_EXTS = (".py .js .mjs .cjs .ts .tsx .jsx .sh .bash .go .rs .java .rb .md .json "
              ".yml .yaml .toml").split()

SECRET_ALLOW_BASENAMES = {".env.example", ".env.sample", ".env.template", ".env.dist"}


def is_secret_path(rel):
    """Path-only secret filter (mirror of DMC.md secret patterns). Never opens the file."""
    base = os.path.basename(rel).lower()
    parts = [p.lower() for p in rel.split("/")]
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


def die(msg, code=2):
    sys.stderr.write("dmc-repo-intel: %s\n" % msg)
    sys.exit(code)


def refuse(reasons):
    for r in reasons:
        print("REFUSED: %s" % r)
    sys.exit(3)


def canon(obj):
    return json.dumps(obj, sort_keys=True, indent=2, ensure_ascii=False) + "\n"


def load_json_strict(path):
    """Duplicate-key-rejecting JSON load."""
    def hook(pairs):
        keys = [k for k, _ in pairs]
        if len(keys) != len(set(keys)):
            raise ValueError("duplicate key in JSON object")
        return dict(pairs)
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f, object_pairs_hook=hook)


def git_head(root):
    git = shutil.which("git")
    if not git:
        return "plain", "no-git", "no-git"
    try:
        def run(args):
            r = subprocess.run([git, "-C", root] + args, capture_output=True,
                               text=True, timeout=10)
            return r.returncode, r.stdout.strip()
        rc, inside = run(["rev-parse", "--is-inside-work-tree"])
        if rc != 0 or inside != "true":
            return "plain", "no-git", "no-git"
        _, sha = run(["rev-parse", "HEAD"])
        _, when = run(["log", "-1", "--format=%cI"])
        return "git", (sha or "no-git"), (when or "no-git")
    except Exception:
        return "plain", "no-git", "no-git"


def walk_files(root):
    out = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = sorted(d for d in dirnames if d not in SKIP_DIRS)
        for name in sorted(filenames):
            full = os.path.join(dirpath, name)
            if os.path.islink(full):
                continue
            rel = os.path.relpath(full, root).replace(os.sep, "/")
            if is_secret_path(rel):
                continue
            out.append(rel)
    return sorted(out)


def write_out(text, out_path):
    if out_path is None:
        sys.stdout.write(text)
        return
    if ".." in out_path.split(os.sep):
        die("--out refused: traversal in target", 3)
    if os.path.islink(out_path) or os.path.exists(out_path):
        die("--out refused: target exists or is a symlink", 3)
    parent = os.path.dirname(os.path.abspath(out_path)) or "."
    if os.path.islink(parent) or not os.path.isdir(parent):
        die("--out refused: bad parent", 3)
    if is_secret_path(out_path.replace(os.sep, "/")):
        die("--out refused: secret-shaped target", 3)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(text)


def rel_ok(p):
    return isinstance(p, str) and p and not p.startswith("/") and ".." not in p.split("/")


# ---------------------------------------------------------------- orient (P1)

def gen_orient(root):
    root_kind, head, head_time = git_head(root)
    files = walk_files(root)
    languages = {}
    for f in files:
        ext = os.path.splitext(f)[1]
        if ext in COUNT_EXTS:
            languages[ext.lstrip(".")] = languages.get(ext.lstrip("."), 0) + 1

    manifests, managers, verify, entry = [], set(), [], []

    def read(relp):
        try:
            with open(os.path.join(root, relp), "r", encoding="utf-8") as f:
                return f.read()
        except Exception:
            return None

    if "package.json" in files:
        manifests.append("package.json")
        managers.add("npm")
        try:
            pkg = load_json_strict(os.path.join(root, "package.json"))
        except Exception:
            pkg = {}
        scripts = pkg.get("scripts", {}) if isinstance(pkg, dict) else {}
        for name in sorted(scripts):
            if name in ("test", "lint", "build", "typecheck"):
                cmd = "npm test" if name == "test" else "npm run %s" % name
                verify.append({"command": cmd, "source": "package.json:scripts.%s" % name})
        if isinstance(pkg.get("main"), str):
            entry.append({"path_or_module": pkg["main"], "source": "package.json:main"})
        if isinstance(pkg.get("bin"), dict):
            for k in sorted(pkg["bin"]):
                entry.append({"path_or_module": pkg["bin"][k],
                              "source": "package.json:bin.%s" % k})
    if "pyproject.toml" in files:
        manifests.append("pyproject.toml")
        managers.add("python")
        text = read("pyproject.toml") or ""
        if "[tool.pytest" in text:
            verify.append({"command": "pytest",
                           "source": "pyproject.toml:[tool.pytest.ini_options]"})
        for m in re.finditer(r"^\s*([A-Za-z0-9_-]+)\s*=\s*\"([\w.]+:[\w.]+)\"", text, re.M):
            entry.append({"path_or_module": m.group(2),
                          "source": "pyproject.toml:[project.scripts] %s" % m.group(1)})
    if "Cargo.toml" in files:
        manifests.append("Cargo.toml")
        managers.add("cargo")
        verify.append({"command": "cargo test", "source": "Cargo.toml"})
    if "go.mod" in files:
        manifests.append("go.mod")
        managers.add("go")
        verify.append({"command": "go test ./...", "source": "go.mod"})
    if "Makefile" in files:
        manifests.append("Makefile")
        managers.add("make")
        text = read("Makefile") or ""
        for target in ("test", "lint", "build"):
            if re.search(r"^%s\s*:" % target, text, re.M):
                verify.append({"command": "make %s" % target,
                               "source": "Makefile:%s" % target})

    doc_roots = sorted(d for d in
                       ("README.md", "CLAUDE.md", "AGENTS.md", "DMC.md", "docs")
                       if os.path.exists(os.path.join(root, d)))

    unknowns = []
    if not manifests:
        unknowns.append("no package manifest detected; package manager unknown")
    if not verify:
        unknowns.append("no verify commands detected from manifests")

    return {
        "schema": SCHEMAS["orient"],
        "root_kind": root_kind,
        "head": head,
        "head_time": head_time,
        "languages": languages,
        "manifests": sorted(manifests),
        "package_managers": sorted(managers),
        "verify_commands": sorted(verify, key=lambda x: (x["command"], x["source"])),
        "entrypoints": sorted(entry, key=lambda x: (x["path_or_module"], x["source"])),
        "doc_roots": doc_roots,
        "unknowns": sorted(unknowns),
    }


def validate_orient(doc, root=None):
    errs = []
    req = ["schema", "root_kind", "head", "head_time", "languages", "manifests",
           "package_managers", "verify_commands", "entrypoints", "doc_roots", "unknowns"]
    if not isinstance(doc, dict):
        return ["artifact is not a JSON object"]
    for k in req:
        if k not in doc:
            errs.append("missing key: %s" % k)
    if errs:
        return errs
    if doc["schema"] != SCHEMAS["orient"]:
        errs.append("schema != %s" % SCHEMAS["orient"])
    if doc["root_kind"] not in ("git", "plain"):
        errs.append("root_kind invalid")
    if doc["root_kind"] == "plain" and (doc["head"] != "no-git" or doc["head_time"] != "no-git"):
        errs.append("plain root must carry head/head_time == no-git")
    for row in doc["verify_commands"]:
        if not isinstance(row, dict) or not row.get("command") or not row.get("source"):
            errs.append("verify_commands entry lacks command/source evidence")
    for row in doc["entrypoints"]:
        if not isinstance(row, dict) or not row.get("path_or_module") or not row.get("source"):
            errs.append("entrypoints entry lacks path_or_module/source evidence")
    for p in list(doc["manifests"]) + list(doc["doc_roots"]):
        if not rel_ok(p):
            errs.append("non-relative or traversal path: %r" % p)
        elif root is not None and not os.path.exists(os.path.join(root, p)):
            errs.append("stale map: %s does not exist under --root" % p)
        if isinstance(p, str) and is_secret_path(p):
            errs.append("secret-shaped path present: %r" % p)
    return errs


# ------------------------------------------------------------ landmarks (P2)

def classify_landmark(rel):
    """Return (class, reason) or None for ordinary. Heuristics + DMC protected-union seed."""
    base = os.path.basename(rel)
    if (rel.startswith(".claude/hooks/") or rel == ".claude/settings.json"
            or rel.startswith(".github/workflows/") or rel.startswith("adapters/")
            or rel.startswith(".claude/install/") or rel == "bin/dmc"
            or rel.startswith("bin/lib/") or rel.startswith(".codex/")):
        return "enforcement", "enforcement-surface heuristic / dmc-protected-union"
    if (base.endswith(".schema.md") or base.endswith("_SCHEMA.md")
            or rel.startswith(".claude/workers/providers/")
            or base in {"package.json", "pyproject.toml", "Cargo.toml", "go.mod",
                        "package-lock.json", "pnpm-lock.yaml", "yarn.lock",
                        "poetry.lock", "Cargo.lock"}):
        return "contract", "machine-consumed contract heuristic"
    if rel == "docs/MILESTONES.md" or base.startswith("CHANGELOG") or base == "VERSION":
        return "release", "release-record heuristic"
    if ("/migrations/" in "/" + rel or rel.startswith("migrations/")
            or base.endswith(".sql") or rel.startswith(("prisma/", "drizzle/"))):
        return "data", "data-surface heuristic"
    return None


def gen_landmarks(root):
    _, head, _ = git_head(root)
    marks = []
    for rel in walk_files(root):
        hit = classify_landmark(rel)
        if hit:
            marks.append({"path": rel, "class": hit[0], "reason": hit[1]})
    return {
        "schema": SCHEMAS["landmarks"],
        "head": head,
        "seed": LANDMARK_SEED,
        "classes": CLASSES,
        "landmarks": sorted(marks, key=lambda m: m["path"]),
    }


def validate_landmarks(doc):
    errs = []
    if not isinstance(doc, dict):
        return ["artifact is not a JSON object"]
    for k in ("schema", "head", "seed", "classes", "landmarks"):
        if k not in doc:
            errs.append("missing key: %s" % k)
    if errs:
        return errs
    if doc["schema"] != SCHEMAS["landmarks"]:
        errs.append("schema != %s" % SCHEMAS["landmarks"])
    if doc["classes"] != CLASSES:
        errs.append("classes enum mismatch")
    seen = set()
    for m in doc["landmarks"]:
        if not isinstance(m, dict):
            errs.append("landmark entry not an object")
            continue
        p = m.get("path")
        if not rel_ok(p):
            errs.append("bad landmark path: %r" % p)
        if p in seen:
            errs.append("duplicate landmark path: %r" % p)
        seen.add(p)
        if m.get("class") not in CLASSES or m.get("class") == "ordinary":
            errs.append("landmark class invalid (ordinary must not be listed): %r" % p)
        if not m.get("reason"):
            errs.append("landmark without reason: %r" % p)
    return errs


# ----------------------------------------------------------- depsurface (P4)

PY_IMPORT = re.compile(r"^\s*(?:from\s+([\w.]+)\s+import|import\s+([\w.]+))", re.M)
JS_IMPORT = re.compile(
    r"""(?:require\(\s*['"]([^'"]+)['"]\s*\)|import\s+(?:[\w{},*\s]+\s+from\s+)?['"]([^'"]+)['"])""")
SH_SOURCE = re.compile(r"""^\s*(?:source|\.)\s+([^\s;]+)""", re.M)


def resolve_js(root, src_rel, spec):
    if not spec.startswith("."):
        return None
    base = os.path.normpath(os.path.join(os.path.dirname(src_rel), spec)).replace(os.sep, "/")
    if ".." in base.split("/"):
        return None
    for cand in (base, base + ".js", base + ".mjs", base + ".cjs", base + ".ts",
                 base + ".tsx", base + "/index.js", base + "/index.ts"):
        if os.path.isfile(os.path.join(root, cand)):
            return cand
    return None


def resolve_py(root, src_rel, module):
    mod = module.lstrip(".")
    if module.startswith("."):
        basedir = os.path.dirname(src_rel)
        cand_base = os.path.join(basedir, mod.replace(".", "/")) if mod else basedir
    else:
        cand_base = mod.replace(".", "/")
    cand_base = os.path.normpath(cand_base).replace(os.sep, "/")
    if ".." in cand_base.split("/"):
        return None
    for cand in (cand_base + ".py", cand_base + "/__init__.py"):
        if os.path.isfile(os.path.join(root, cand)):
            return cand
    return None


def resolve_sh(root, src_rel, spec):
    if spec.startswith(("$", "~", "/")):
        return None
    cand = os.path.normpath(os.path.join(os.path.dirname(src_rel), spec)).replace(os.sep, "/")
    if ".." in cand.split("/"):
        return None
    return cand if os.path.isfile(os.path.join(root, cand)) else None


def gen_depsurface(root):
    _, head, _ = git_head(root)
    files_out, unscanned = {}, []
    all_files = walk_files(root)
    for rel in all_files:
        ext = os.path.splitext(rel)[1]
        lang = LANG_EXTS.get(ext)
        if lang is None:
            if ext and ext not in (".md", ".json", ".toml", ".yml", ".yaml", ".txt",
                                   ".gitkeep", ".zip"):
                unscanned.append(rel)
            continue
        try:
            with open(os.path.join(root, rel), "r", encoding="utf-8",
                      errors="replace") as f:
                text = f.read()
        except Exception:
            unscanned.append(rel)
            continue
        internal, external = set(), set()
        if lang == "py":
            for m in PY_IMPORT.finditer(text):
                module = m.group(1) or m.group(2)
                hit = resolve_py(root, rel, module)
                (internal if hit else external).add(hit or module)
        elif lang == "js":
            for m in JS_IMPORT.finditer(text):
                spec = m.group(1) or m.group(2)
                hit = resolve_js(root, rel, spec)
                (internal if hit else external).add(hit or spec)
        elif lang == "sh":
            for m in SH_SOURCE.finditer(text):
                hit = resolve_sh(root, rel, m.group(1))
                if hit:
                    internal.add(hit)
                else:
                    external.add(m.group(1))
        internal.discard(rel)
        files_out[rel] = {"lang": lang,
                          "imports_internal": sorted(internal),
                          "imports_external": sorted(external)}
    inbound = {}
    for src, row in files_out.items():
        for tgt in row["imports_internal"]:
            inbound.setdefault(tgt, []).append(src)
    return {
        "schema": SCHEMAS["depsurface"],
        "head": head,
        "note": DEPSURFACE_NOTE,
        "files": files_out,
        "inbound": {k: sorted(v) for k, v in sorted(inbound.items())},
        "unscanned": sorted(unscanned),
    }


def validate_depsurface(doc):
    errs = []
    if not isinstance(doc, dict):
        return ["artifact is not a JSON object"]
    for k in ("schema", "head", "note", "files", "inbound", "unscanned"):
        if k not in doc:
            errs.append("missing key: %s" % k)
    if errs:
        return errs
    if doc["schema"] != SCHEMAS["depsurface"]:
        errs.append("schema != %s" % SCHEMAS["depsurface"])
    if "not a completeness guarantee" not in str(doc["note"]):
        errs.append("note lacks the non-completeness attestation")
    recomputed = {}
    for src, row in doc["files"].items():
        if not rel_ok(src):
            errs.append("bad file path: %r" % src)
        for tgt in row.get("imports_internal", []):
            if not rel_ok(tgt):
                errs.append("bad internal import path: %r" % tgt)
            recomputed.setdefault(tgt, []).append(src)
    recomputed = {k: sorted(v) for k, v in recomputed.items()}
    if recomputed != doc["inbound"]:
        errs.append("inbound is not the exact inversion of imports_internal")
    for p in doc["unscanned"]:
        if p in doc["files"]:
            errs.append("path both scanned and unscanned: %r" % p)
    return errs


# --------------------------------------------------------------- radius (P5)

def gen_radius(dep, marks, scope, checks):
    landmark_by_path = {m["path"]: m["class"] for m in marks.get("landmarks", [])}
    unscanned = set(dep.get("unscanned", []))
    inbound = dep.get("inbound", {})
    entries, missing = [], []
    for path in sorted(set(scope)):
        if not rel_ok(path):
            refuse(["scope path invalid: %r" % path])
        ids = checks.get(path, [])
        ids = [c for c in ids if isinstance(c, str) and c.strip()]
        if not ids:
            missing.append(path)
            continue
        dependents = sorted(inbound.get(path, []))
        entries.append({
            "path": path,
            "dependents": dependents,
            "dependent_count": len(dependents),
            "landmark_class": landmark_by_path.get(path, "ordinary"),
            "unscanned": path in unscanned,
            "check_ids": sorted(set(ids)),
        })
    if missing:
        refuse(["radius entry without >=1 check_id (fail-closed, never weakened): %s" % p
                for p in missing])
    return {
        "schema": SCHEMAS["radius"],
        "head": dep.get("head", "no-git"),
        "scope": sorted(set(scope)),
        "entries": entries,
    }


def validate_radius(doc):
    errs = []
    if not isinstance(doc, dict):
        return ["artifact is not a JSON object"]
    for k in ("schema", "head", "scope", "entries"):
        if k not in doc:
            errs.append("missing key: %s" % k)
    if errs:
        return errs
    if doc["schema"] != SCHEMAS["radius"]:
        errs.append("schema != %s" % SCHEMAS["radius"])
    entry_paths = []
    for e in doc["entries"]:
        if not isinstance(e, dict):
            errs.append("entry not an object")
            continue
        p = e.get("path")
        entry_paths.append(p)
        if not rel_ok(p):
            errs.append("bad entry path: %r" % p)
        ids = e.get("check_ids", [])
        if not ids or any((not isinstance(c, str)) or (not c.strip()) for c in ids):
            errs.append("entry without >=1 non-empty check_id: %r" % p)
        if e.get("dependent_count") != len(e.get("dependents", [])):
            errs.append("dependent_count mismatch: %r" % p)
        if e.get("landmark_class") not in CLASSES:
            errs.append("bad landmark_class: %r" % p)
        if not isinstance(e.get("unscanned"), bool):
            errs.append("unscanned must be bool: %r" % p)
    if sorted(entry_paths) != sorted(doc["scope"]):
        errs.append("entries[].path set != scope set (drop or dup)")
    if len(set(entry_paths)) != len(entry_paths):
        errs.append("duplicate entry paths")
    return errs


# ------------------------------------------------------------------ selftest

def repo_root():
    return os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                         "..", ".."))


def fixtures_dir():
    return os.path.join(repo_root(), "tests", "fixtures")


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


def selftest_orient():
    t = ST("orient")
    fx = fixtures_dir()
    node = gen_orient(os.path.join(fx, "node"))
    t.ok("O1 npm detected", "npm" in node["package_managers"])
    t.ok("O1b npm test from scripts.test",
         any(v["command"] == "npm test" and v["source"] == "package.json:scripts.test"
             for v in node["verify_commands"]))
    t.ok("O1c entrypoint from package.json:main",
         any(e["source"] == "package.json:main" for e in node["entrypoints"]))
    py = gen_orient(os.path.join(fx, "python"))
    t.ok("O2 pyproject detected", "pyproject.toml" in py["manifests"])
    t.ok("O2b project.scripts entrypoint",
         any("project.scripts" in e["source"] for e in py["entrypoints"]))
    empty = gen_orient(os.path.join(fx, "empty"))
    t.ok("O3 empty => no manifests + explicit unknowns",
         empty["manifests"] == [] and len(empty["unknowns"]) >= 1)
    t.ok("O4 determinism", canon(gen_orient(os.path.join(fx, "node"))) == canon(node))
    t.ok("O5 validator accepts valid", validate_orient(node) == [])
    bad = dict(node)
    del bad["manifests"]
    t.ok("O5b negative control: missing key REFUSED", validate_orient(bad) != [])
    bad2 = json.loads(canon(node))
    bad2["manifests"] = ["does-not-exist.json"]
    t.ok("O5c negative control: stale path REFUSED (with --root)",
         validate_orient(bad2, root=os.path.join(fx, "node")) != [])
    t.done()


def selftest_landmarks():
    t = ST("landmarks")
    doc = gen_landmarks(repo_root())
    cls = {m["path"]: m["class"] for m in doc["landmarks"]}
    t.ok("L1 self-scan: hooks are enforcement",
         cls.get(".claude/hooks/pre-tool-guard.sh") == "enforcement")
    t.ok("L1b self-scan: settings.json is enforcement",
         cls.get(".claude/settings.json") == "enforcement")
    t.ok("L1c self-scan: provider router is contract",
         cls.get(".claude/workers/providers/provider-router.py") == "contract")
    t.ok("L1d self-scan: schemas are contract",
         cls.get(".harness/schemas/trace-linkage.schema.md") == "contract")
    t.ok("L1e self-scan: MILESTONES is release",
         cls.get("docs/MILESTONES.md") == "release")
    t.ok("L1f self-scan: dmc-glm-smoke correctly absent",
         "dmc-glm-smoke" not in cls)
    t.ok("L1g self-scan: .codex/config.toml is enforcement",
         cls.get(".codex/config.toml") == "enforcement")
    t.ok("L1g self-scan: .codex/hooks.json is enforcement",
         cls.get(".codex/hooks.json") == "enforcement")
    tmp = tempfile.mkdtemp(prefix="dmc-lm-")
    try:
        os.makedirs(os.path.join(tmp, ".claude", "hooks"))
        with open(os.path.join(tmp, ".claude", "hooks", "fake.sh"), "w") as f:
            f.write("#!/bin/sh\n")
        seeded = gen_landmarks(tmp)
        t.ok("L2 negative control: seeded fake hook detected as enforcement",
             any(m["path"] == ".claude/hooks/fake.sh" and m["class"] == "enforcement"
                 for m in seeded["landmarks"]))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    empty = gen_landmarks(os.path.join(fixtures_dir(), "empty"))
    t.ok("L3 empty fixture => no landmarks", empty["landmarks"] == [])
    t.ok("L4 determinism", canon(gen_landmarks(repo_root())) == canon(doc))
    t.ok("L5 validator accepts valid", validate_landmarks(doc) == [])
    bad = json.loads(canon(doc))
    bad["landmarks"].append({"path": "x", "class": "ordinary", "reason": "r"})
    t.ok("L5b negative control: listed 'ordinary' REFUSED", validate_landmarks(bad) != [])
    t.done()


def selftest_depsurface():
    t = ST("depsurface")
    fx = fixtures_dir()
    node = gen_depsurface(os.path.join(fx, "node"))
    t.ok("D1 seeded js dependent found (b.js -> a.js)",
         "src/b.js" in node["inbound"].get("src/a.js", []))
    t.ok("D1b external specifier kept external",
         "left-pad" in node["files"]["src/b.js"]["imports_external"])
    t.ok("D1c css labeled unscanned", "src/style.css" in node["unscanned"])
    py = gen_depsurface(os.path.join(fx, "python"))
    t.ok("D2 seeded py dependent found (cli.py -> core.py)",
         "pkg/cli.py" in py["inbound"].get("pkg/core.py", []))
    t.ok("D3 determinism", canon(gen_depsurface(os.path.join(fx, "node"))) == canon(node))
    t.ok("D4 validator accepts valid", validate_depsurface(node) == [])
    bad = json.loads(canon(node))
    bad["inbound"] = {}
    t.ok("D4b negative control: broken inversion REFUSED", validate_depsurface(bad) != [])
    bad2 = json.loads(canon(node))
    bad2["note"] = "totally complete"
    t.ok("D4c negative control: missing attestation REFUSED",
         validate_depsurface(bad2) != [])
    t.done()


def selftest_radius():
    t = ST("radius")
    fx = os.path.join(fixtures_dir(), "node")
    dep = gen_depsurface(fx)
    marks = gen_landmarks(fx)
    checks = {"src/a.js": ["CHK-SYNTH-001"], "package.json": ["CHK-SYNTH-002"]}
    doc = gen_radius(dep, marks, ["src/a.js", "package.json"], checks)
    by = {e["path"]: e for e in doc["entries"]}
    t.ok("R1 dependent-bearing entry has synthetic check_ids",
         by["src/a.js"]["check_ids"] == ["CHK-SYNTH-001"]
         and by["src/a.js"]["dependent_count"] == 1)
    t.ok("R1b landmark class carried (package.json => contract)",
         by["package.json"]["landmark_class"] == "contract")
    rc = subprocess.run(
        [sys.executable, os.path.abspath(__file__), "radius",
         "--depsurface", "-", "--landmarks", "-", "--checks", "-", "--scope", "src/a.js"],
        input=json.dumps({"dep": dep, "marks": marks, "checks": {}}),
        capture_output=True, text=True)
    t.ok("R2 negative control: missing check_id => REFUSED exit 3 (refusal not weakened)",
         rc.returncode == 3 and "without >=1 check_id" in rc.stdout)
    t.ok("R3 determinism",
         canon(gen_radius(dep, marks, ["src/a.js", "package.json"], checks)) == canon(doc))
    t.ok("R4 validator accepts valid", validate_radius(doc) == [])
    bad = json.loads(canon(doc))
    bad["entries"][0]["check_ids"] = []
    t.ok("R4b negative control: checkless entry REFUSED", validate_radius(bad) != [])
    bad2 = json.loads(canon(doc))
    bad2["entries"] = bad2["entries"][:1]
    t.ok("R4c negative control: dropped scope entry REFUSED", validate_radius(bad2) != [])
    t.done()


# ---------------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser(prog="dmc-repo-intel")
    ap.add_argument("command", choices=["orient", "landmarks", "depsurface", "radius"])
    ap.add_argument("--root", default=".")
    ap.add_argument("--out")
    ap.add_argument("--validate", metavar="FILE")
    ap.add_argument("--self-test", action="store_true")
    ap.add_argument("--depsurface", metavar="FILE")
    ap.add_argument("--landmarks", metavar="FILE")
    ap.add_argument("--checks", metavar="FILE")
    ap.add_argument("--scope", nargs="*", default=[])
    a = ap.parse_args()

    if a.self_test:
        {"orient": selftest_orient, "landmarks": selftest_landmarks,
         "depsurface": selftest_depsurface, "radius": selftest_radius}[a.command]()
        return

    if a.validate:
        try:
            doc = load_json_strict(a.validate)
        except Exception as e:
            refuse(["unreadable/duplicate-key JSON: %s" % e])
        errs = {"orient": lambda d: validate_orient(
                    d, root=a.root if a.root != "." else None),
                "landmarks": validate_landmarks,
                "depsurface": validate_depsurface,
                "radius": validate_radius}[a.command](doc)
        if errs:
            refuse(errs)
        print("VALID: %s conforms to %s" % (a.validate, SCHEMAS[a.command]))
        return

    if a.command == "radius":
        if not (a.depsurface and a.landmarks and a.checks and a.scope):
            die("radius requires --depsurface --landmarks --checks --scope", 2)
        if a.depsurface == "-":
            bundle = json.load(sys.stdin)
            dep, marks, checks = bundle["dep"], bundle["marks"], bundle["checks"]
        else:
            dep = load_json_strict(a.depsurface)
            marks = load_json_strict(a.landmarks)
            checks = load_json_strict(a.checks)
        for label, doc, fn in (("depsurface", dep, validate_depsurface),
                               ("landmarks", marks, validate_landmarks)):
            errs = fn(doc)
            if errs:
                refuse(["input %s invalid: %s" % (label, e) for e in errs])
        out = gen_radius(dep, marks, a.scope, checks)
    else:
        root = os.path.abspath(a.root)
        if not os.path.isdir(root):
            die("--root is not a directory: %s" % root, 2)
        out = {"orient": gen_orient, "landmarks": gen_landmarks,
               "depsurface": gen_depsurface}[a.command](root)

    write_out(canon(out), a.out)


if __name__ == "__main__":
    main()
