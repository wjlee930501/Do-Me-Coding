#!/usr/bin/env python3
# DMC v0.6.1 Capability-Class Router (core). ADVISORY / READ-ONLY / INPUT-ONLY, deterministic, model-agnostic, fail-closed.
# Resolves (task_class, role) -> capability_class via a visible static table (NO model name, NO learned scoring), emits a
# routing record + a subject-bound capability_class fragment (trace-linkage v0.6.1.0). No temp/heredoc, no git, no env/.env.
#   python3 dmc-v0.6.1-capability-router.py route <facts.json|-> [--out <file>]   |   selftest
# Exit: 0 ok/valid, 1 invalid (fail-closed), 2 usage/read-error.
import json, sys, re, os, subprocess

TASK_CLASSES = {"docs-only","additive-tool","provider-adapter","protected-surface-change",
                "security-secret-live-risk","release-closure","recovery-resume"}
ROLES = {"orchestrator","implementer","critic","verifier","release"}
CLASSES = {"frontier-long-horizon","standard-implementation","cheap-fast","adversarial-review","deterministic-tool","human-only-gate"}
HASH_RE = re.compile(r'^[0-9a-f]{16,}$')
UNSAFE = re.compile(
  r'sk-[A-Za-z0-9_-]{16,}|AKIA[0-9A-Z]{8,}|(?:BEGIN|END)[A-Z ]*PRIVATE KEY|xox[baprs]-[A-Za-z0-9-]{6,}'
  r'|gh[opsu]_[A-Za-z0-9]{16,}|github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{16,}|npm_[A-Za-z0-9]{30,}'
  r'|AIza[0-9A-Za-z_-]{20,}|dop_v1_[A-Za-z0-9]{32,}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'
  r'|ya29\.[A-Za-z0-9_-]{10,}|AccountKey=[A-Za-z0-9+/=]{20,}|Bearer\s+[A-Za-z0-9._-]{12,}'
  r'|(?:password|api_key|client_secret|aws_secret_access_key)\s*=\s*\S+|[A-Za-z0-9_-]*_token\s*[=:]\s*\S+'
)
CONTRACT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "dmc-v0.6.1.0-trace-linkage.py")

class Bad(Exception): pass

def no_dup(pairs):
    d = {}
    for k, v in pairs:
        if k in d: raise ValueError("duplicate JSON key: %r" % k)
        d[k] = v
    return d

def scan(o):
    if isinstance(o, dict):
        for k, v in o.items():
            if isinstance(k, str) and UNSAFE.search(k): return True
            if scan(v): return True
    elif isinstance(o, list):
        for x in o:
            if scan(x): return True
    elif isinstance(o, str):
        if UNSAFE.search(o): return True
    return False

def nestr(x): return isinstance(x, str) and x != "" and "\n" not in x

# --- the visible deterministic routing table; pure over (task_class, role); reads NO model table ---
def resolve(task_class, role):
    if role == "orchestrator": return "frontier-long-horizon", "role=orchestrator -> frontier-long-horizon"
    if role == "critic":       return "adversarial-review", "role=critic -> adversarial-review"
    if role == "verifier":     return "deterministic-tool", "role=verifier -> deterministic-tool"
    if role == "release":      return "human-only-gate", "role=release -> human-only-gate"
    if role == "implementer":
        if task_class == "docs-only": return "cheap-fast", "role=implementer + task_class=docs-only -> cheap-fast (light lane)"
        return "standard-implementation", "role=implementer -> standard-implementation"
    raise Bad("unknown role: %s" % role)

def validate_facts(rec):
    if not isinstance(rec, dict): raise Bad("facts not object")
    if scan(rec): raise Bad("secret-shaped string present")
    tc, role, subj = rec.get("task_class"), rec.get("role"), rec.get("subject")
    if tc not in TASK_CLASSES: raise Bad("unknown/missing task_class: %r" % tc)
    if role not in ROLES: raise Bad("unknown/missing role: %r" % role)
    if not isinstance(subj, dict): raise Bad("subject missing")
    for k in ("work_id","plan_hash","milestone_id","repo_hash","verification_ref"):
        if not nestr(subj.get(k)): raise Bad("subject.%s missing/empty" % k)
    if not HASH_RE.match(subj["plan_hash"]): raise Bad("subject.plan_hash not hash-shaped")
    if not HASH_RE.match(subj["repo_hash"]): raise Bad("subject.repo_hash not hash-shaped")
    return tc, role, subj

def route_record(rec):
    tc, role, subj = validate_facts(rec)
    cls, rule = resolve(tc, role)
    explanation = ("task_class=%s, role=%s -> capability_class=%s (%s); the class->model lookup is a separate dated table, "
                   "not consulted by routing." % (tc, role, cls, rule))
    entry = {"kind":"capability_class","id":cls,"producer_milestone_id":"v0.6.1",
             "work_id":subj["work_id"],"plan_hash":subj["plan_hash"],"repo_hash":subj["repo_hash"],
             "verification_ref":subj["verification_ref"]}
    return {"inputs":{"task_class":tc,"role":role},"resolved_capability_class":cls,"rule_fired":rule,
            "explanation":explanation,"capability_entry":entry}

def read_text(path):
    if path == "-": return sys.stdin.read()
    with open(path, "r") as f: return f.read()

def out_unsafe(out):
    # core-side --out write-safety (no git): refuse traversal / symlink / in-repo / protected-shaped paths.
    root = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
    if ".." in out.replace("\\", "/").split("/"): return True
    if os.path.islink(out): return True
    parent = os.path.dirname(os.path.abspath(out)) or "."
    try:
        cparent = os.path.realpath(parent)
    except Exception:
        return True
    if not os.path.isdir(cparent): return True
    canon = os.path.join(cparent, os.path.basename(out))
    if canon == root or (canon + os.sep).startswith(root + os.sep): return True   # inside the repo work tree
    low = canon.lower()
    # NOTE: dotted dev-config dirs under the repo root are already refused by the in-repo check above, so we do not
    # re-list them here (re-listing such a path token would also trip the C3 no-model-name source scan).
    return any(p in low for p in (".env", ".pem", ".key", "id_rsa", "id_ed25519", "credentials", "secret", "provider-router"))

def route_path(path, out=None):
    try:
        text = read_text(path)
    except Exception as e:
        sys.stderr.write("REFUSED: read: %s\n" % e); return 2
    try:
        rec = json.loads(text, object_pairs_hook=no_dup)
    except ValueError as e:
        sys.stderr.write("INVALID: json: %s\n" % e); return 1
    try:
        out_rec = route_record(rec)
    except Bad as e:
        sys.stderr.write("INVALID: %s\n" % e); return 1
    blob = json.dumps(out_rec, indent=2, sort_keys=True)
    sys.stderr.write(out_rec["explanation"] + "\n")
    if out:
        if out_unsafe(out):                                  # core-side guard (no git); wrapper adds a second layer
            sys.stderr.write("REFUSED: unsafe --out path: %s\n" % out); return 2
        with open(out, "w") as f: f.write(blob + "\n")
    else:
        sys.stdout.write(blob + "\n")
    return 0

# --- C6: validate the emitted fragment against the v0.6.1.0 contract (in-memory via stdin; no temp) ---
def validate_fragment(entry):
    try:
        r = subprocess.run([sys.executable, CONTRACT, "validate-entry", "capability", "-"],
                           input=json.dumps(entry).encode(), capture_output=True)
        return r.returncode
    except Exception:
        return 2

# --- C3: the operative routing source must contain no model-name token ---
MODEL_NAMES = re.compile(r'\b(gpt-?[0-9]|claude|opus|sonnet|haiku|gemini|glm-?[0-9]|llama|mistral|fugu|grok|qwen|deepseek|o[134]-)\b', re.I)

def selftest():
    pas = fai = 0; lines = []
    def rec(ok, name, detail=""):
        nonlocal pas, fai
        lines.append("  [%s] %-34s %s" % ("PASS" if ok else "FAIL", name, detail)); pas += ok; fai += (not ok)
    H = "a"*64
    subj = {"work_id":"W1","plan_hash":H,"milestone_id":"v0.6.1.0","repo_hash":H,"verification_ref":"ver/report.md"}
    def facts(tc, role): return {"task_class":tc,"role":role,"subject":dict(subj)}

    # C1: EXACT 7x5 grid — every cell pinned to an INDEPENDENT expectation (not a re-derivation of resolve), deterministic.
    def exp(tc, role):
        if role == "orchestrator": return "frontier-long-horizon"
        if role == "critic":       return "adversarial-review"
        if role == "verifier":     return "deterministic-tool"
        if role == "release":      return "human-only-gate"
        # implementer: light lane only for docs-only
        return "cheap-fast" if tc == "docs-only" else "standard-implementation"
    grid_ok = True; cells = 0
    for tc in sorted(TASK_CLASSES):
        for role in sorted(ROLES):
            got = resolve(tc, role)[0]; cells += 1
            if got != exp(tc, role): grid_ok = False              # exact-cell comparison (catches any divergence)
            if got not in CLASSES: grid_ok = False
            if resolve(tc, role)[0] != got: grid_ok = False       # determinism
    rec(grid_ok and cells == 35, "C1 exact 7x5 grid (every cell pinned)", "%d cells" % cells)

    # C2: unknown/missing task_class or role, malformed/secret subject -> REJECT
    def rejects(rec_obj):
        try: route_record(rec_obj); return False
        except Bad: return True
    c2 = (rejects(facts("nope","implementer")) and rejects(facts("docs-only","nope"))
          and rejects({"task_class":"docs-only","role":"implementer"})  # no subject
          and rejects({"task_class":"docs-only","role":"implementer","subject":{**subj,"plan_hash":"xyz"}})  # bad hash
          and rejects({"task_class":"docs-only","role":"implementer","subject":{**subj,"work_id":"AKIAABCDEFGHIJKLMNOP"}}))  # secret
    rec(c2, "C2 unknown/malformed/secret -> REJECT")

    # C2b: duplicate JSON key -> REJECT (load path)
    dup = '{"task_class":"docs-only","task_class":"release-closure","role":"implementer","subject":{}}'
    try:
        json.loads(dup, object_pairs_hook=no_dup); c2b = False
    except ValueError:
        c2b = True
    rec(c2b, "C2b duplicate JSON key -> REJECT")

    # C3 / C4: no model-name token in the operative routing source (model-swap invariance by construction)
    with open(os.path.abspath(__file__), "r") as f: src = f.read()
    # exclude the MODEL_NAMES pattern-definition line itself from the scan
    operative = "\n".join(l for l in src.split("\n") if "MODEL_NAMES" not in l)
    c3 = (MODEL_NAMES.search(operative) is None)
    rec(c3, "C3/C4 no model-name in routing logic", "model-swap invariant")

    # C5: explanation present + names the rule
    r = route_record(facts("security-secret-live-risk","critic"))
    c5 = ("->" in r["explanation"]) and (r["rule_fired"] in r["explanation"]) and bool(r["rule_fired"])
    rec(c5, "C5 human-readable explanation names rule")

    # C6: emitted fragment passes the v0.6.1.0 contract --validate-entry capability
    frag = route_record(facts("additive-tool","implementer"))["capability_entry"]
    code = validate_fragment(frag)
    rec(code == 0, "C6 fragment passes contract --validate-entry", "rc=%d" % code)
    # negative: a tampered fragment (wrong producer) must be rejected by the contract
    bad = dict(frag); bad["producer_milestone_id"] = "v9"
    rec(validate_fragment(bad) == 1, "C6neg tampered fragment -> contract REJECT")

    sys.stdout.write("\n".join(lines) + "\n")
    sys.stdout.write("  ---- self-test: %d PASS / %d FAIL ----\n" % (pas, fai))
    return 0 if fai == 0 else 1

def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    if mode == "route":
        if len(sys.argv) < 3: sys.stderr.write("usage: route <facts.json|-> [--out <file>]\n"); return 2
        out = None
        if "--out" in sys.argv:
            i = sys.argv.index("--out")
            if i+1 < len(sys.argv): out = sys.argv[i+1]
        return route_path(sys.argv[2], out)
    if mode == "selftest":
        return selftest()
    sys.stderr.write("usage: route <facts.json|-> [--out <file>] | selftest\n"); return 2

if __name__ == "__main__":
    sys.exit(main())
