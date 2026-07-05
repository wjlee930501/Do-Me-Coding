#!/usr/bin/env python3
# DMC v0.6.3 Findings Gate (core). ADVISORY / READ-ONLY / INPUT-ONLY, fail-closed. "No unresolved finding crosses invisibly."
# Answers Q3. Validates findings (state in {resolved,accepted-risk,deferred,blocked}); --gate (snapshot closure);
# --append-check (no drop/rewrite, canonical-JSON per id); --release = append-check AND gate (authoritative, anti-bypass).
# No temp/heredoc, no git, no env/.env/network. Findings are trace-linkage `finding` fragments (producer=v0.6.3).
#   python3 dmc-v0.6.3-findings-gate.py validate <finding.json|->
#   python3 dmc-v0.6.3-findings-gate.py gate <{subject,findings}.json|->
#   python3 dmc-v0.6.3-findings-gate.py append-check <{prev,next}.json|->
#   python3 dmc-v0.6.3-findings-gate.py release <{subject,prev,next}.json|-> [--out <file>]
#   python3 dmc-v0.6.3-findings-gate.py selftest
# Exit: validate 0/1/2; gate/append-check/release 0 ALLOW / 1 REFUSE / 2 usage.
import json, sys, re, os, subprocess

STATES = {"resolved","accepted-risk","deferred","blocked"}
BIND = ("work_id","plan_hash","repo_hash","verification_ref")
HASH_RE = re.compile(r'^[0-9a-f]{16,}$')
TOKEN_RE = re.compile(r'^[A-Za-z0-9._-]+$')
PATH_RE = re.compile(r'^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)+$')
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
def token_ok(s): return nestr(s) and len(s) <= 128 and TOKEN_RE.match(s) is not None
def ref_ok(s):
    if not nestr(s): return False
    if token_ok(s): return True
    if HASH_RE.match(s): return True
    if PATH_RE.match(s) and ".." not in s.split("/"): return True
    return False
def canonical(e): return json.dumps(e, sort_keys=True, separators=(",", ":"))

def validate_entry_via_contract(kind, entry):
    try:
        r = subprocess.run([sys.executable, CONTRACT, "validate-entry", kind, "-"],
                           input=json.dumps(entry).encode(), capture_output=True)
        return r.returncode
    except Exception:
        return 2

def validate_finding(f):
    if not isinstance(f, dict): raise Bad("finding not object")
    if scan(f): raise Bad("secret-shaped string present (F10)")
    if f.get("kind") != "finding": raise Bad("kind != finding")
    if f.get("producer_milestone_id") != "v0.6.3": raise Bad("producer_milestone_id != v0.6.3")
    if not nestr(f.get("id")): raise Bad("id missing/empty")
    for b in BIND:
        if not nestr(f.get(b)): raise Bad("binding.%s missing/empty" % b)
    if not HASH_RE.match(f["plan_hash"]) or not HASH_RE.match(f["repo_hash"]): raise Bad("plan_hash/repo_hash not hash-shaped")
    st = f.get("state")
    if st not in STATES: raise Bad("state not in the four (F2)")
    if not token_ok(f.get("summary_class")): raise Bad("summary_class missing/prose/not-token (F4)")
    if st == "resolved":
        if not ref_ok(f.get("evidence_ref")): raise Bad("resolved requires ref_ok evidence_ref (F3a)")
    elif st == "accepted-risk":
        w = f.get("waiver")
        if not isinstance(w, dict) or not isinstance(w.get("approval"), dict): raise Bad("accepted-risk requires waiver.approval (F3d)")
        appr = w["approval"]
        for b in BIND:
            if appr.get(b) != f.get(b): raise Bad("waiver.approval.%s != finding subject (F3c)" % b)
        if validate_entry_via_contract("approval", appr) != 0: raise Bad("waiver.approval fails --validate-entry approval (F3b)")
    elif st == "deferred":
        for k in ("owner","target","release_policy"):
            if not token_ok(f.get(k)): raise Bad("deferred requires token %s (F3e)" % k)
    # blocked: a well-formed finding (valid to record), but FAILs release at the gate
    return True

def _subject5(subj):
    if not isinstance(subj, dict): raise Bad("subject missing")
    for k in ("work_id","plan_hash","milestone_id","repo_hash","verification_ref"):
        if not nestr(subj.get(k)): raise Bad("subject.%s missing/empty" % k)
    if not HASH_RE.match(subj["plan_hash"]) or not HASH_RE.match(subj["repo_hash"]): raise Bad("subject hashes not hash-shaped")

def gate(claim):
    if not isinstance(claim, dict): raise Bad("claim not object")
    if scan(claim): raise Bad("secret-shaped string present (F10)")
    _subject5(claim.get("subject"))
    subj = claim["subject"]
    findings = claim.get("findings")
    if not isinstance(findings, list): raise Bad("findings not an array")
    remaining = []
    for i, f in enumerate(findings):
        try: validate_finding(f)
        except Bad as e: raise Bad("invalid finding[%d]: %s" % (i, e))
        for b in BIND:
            if f.get(b) != subj.get(b): raise Bad("finding[%d].%s != subject (F6)" % (i, b))
        if f["state"] == "blocked": raise Bad("finding[%d] is blocked -> cannot cross release (F5)" % i)
        remaining.append({"id": f["id"], "state": f["state"], "summary_class": f["summary_class"]})
    return {"verdict":"ALLOW","reason":"all findings subject-consistent + release-PASS","subject":subj,
            "findings_remaining_Q3": remaining, "n_findings": len(findings)}

def _id_map(lst, where):
    if not isinstance(lst, list): raise Bad("%s not an array" % where)
    seen = {}
    for e in lst:
        if not isinstance(e, dict): raise Bad("%s entry not object" % where)
        i = e.get("id")
        if not nestr(i): raise Bad("%s entry.id missing" % where)
        if i in seen: raise Bad("duplicate finding id in %s: %s (F8c)" % (where, i))
        seen[i] = e
    return seen

def append_check(obj):
    if not isinstance(obj, dict): raise Bad("input not object")
    if scan(obj): raise Bad("secret-shaped string present (F10)")
    pmap = _id_map(obj.get("prev"), "prev"); nmap = _id_map(obj.get("next"), "next")
    for i, pe in pmap.items():
        if i not in nmap: raise Bad("prev finding dropped: %s (F8a)" % i)
        if canonical(pe) != canonical(nmap[i]): raise Bad("prev finding rewritten: %s (F8b)" % i)
    return {"verdict":"ALLOW","reason":"append-only (no drop/rewrite)","n_prev":len(pmap),"n_next":len(nmap)}

def release(obj):
    if not isinstance(obj, dict): raise Bad("input not object")
    if scan(obj): raise Bad("secret-shaped string present (F10)")
    append_check({"prev": obj.get("prev"), "next": obj.get("next")})          # raises Bad on drop/rewrite/dup
    g = gate({"subject": obj.get("subject"), "findings": obj.get("next")})     # raises Bad on blocked/unknown/bad-subject
    return {"verdict":"ALLOW","reason":"append-only AND closure both pass","subject":g["subject"],
            "findings_remaining_Q3": g["findings_remaining_Q3"], "n_findings": g["n_findings"]}

def out_unsafe(out):
    root = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
    if ".." in out.replace("\\", "/").split("/"): return True
    if os.path.islink(out): return True
    parent = os.path.dirname(os.path.abspath(out)) or "."
    try: cparent = os.path.realpath(parent)
    except Exception: return True
    if not os.path.isdir(cparent): return True
    canon = os.path.join(cparent, os.path.basename(out))
    if canon == root or (canon + os.sep).startswith(root + os.sep): return True
    low = canon.lower()
    return any(p in low for p in (".env", ".pem", ".key", "id_rsa", "id_ed25519", "credentials", "secret", "provider-router"))

def read_text(path): return sys.stdin.read() if path == "-" else open(path, "r").read()
def load(path): return json.loads(read_text(path), object_pairs_hook=no_dup)

def validate_path(path):
    try: f = load(path)
    except ValueError as e: sys.stderr.write("INVALID: json: %s\n" % e); return 1
    except Exception as e: sys.stderr.write("INVALID: read: %s\n" % e); return 2
    try: validate_finding(f)
    except Bad as e: sys.stderr.write("INVALID: %s\n" % e); return 1
    sys.stdout.write("VALID\n"); return 0

def _decide(path, fn, out=None):
    try: obj = load(path)
    except ValueError as e: sys.stderr.write("REFUSE: json: %s\n" % e); return 1
    except Exception as e: sys.stderr.write("REFUSE: read: %s\n" % e); return 2
    try: rec = fn(obj)
    except Bad as e: rec = {"verdict":"REFUSE","reason":str(e)}
    blob = json.dumps(rec, indent=2, sort_keys=True)
    if out:
        if out_unsafe(out): sys.stderr.write("REFUSED: unsafe --out path: %s\n" % out); return 2
        open(out, "w").write(blob + "\n")
    else:
        sys.stdout.write(blob + "\n")
    return 0 if rec["verdict"] == "ALLOW" else 1

def selftest():
    import copy
    pas = fai = 0; lines = []
    def rec(ok, name):
        nonlocal pas, fai
        lines.append("  [%s] %s" % ("PASS" if ok else "FAIL", name)); pas += ok; fai += (not ok)
    H = "a"*64
    bind = {"work_id":"W1","plan_hash":H,"repo_hash":H,"verification_ref":"ver/r.md"}
    def appr(**x):
        d = {"kind":"approval","id":"A1","producer_milestone_id":"human-release-gate","type":"human-release-gate","source":"human-release-gate:auth1"}; d.update(bind); d.update(x); return d
    def fnd(state="resolved", **x):
        d = {"kind":"finding","id":"F"+state[:3],"producer_milestone_id":"v0.6.3","state":state,"summary_class":"perf-regression"}; d.update(bind)
        if state == "resolved": d["evidence_ref"] = "evidenceid123456"
        if state == "accepted-risk": d["waiver"] = {"approval": appr()}
        if state == "deferred": d.update(owner="team-x", target="v0.6.4", release_policy="defer-ok")
        d.update(x); return d
    def vok(f):
        try: validate_finding(f); return True
        except Bad: return False
    def vno(f): return not vok(f)
    # F1: 4 states valid + contract
    rec(all(vok(fnd(s)) for s in STATES), "F1 4 states valid")
    rec(validate_entry_via_contract("finding", {k:v for k,v in fnd("blocked").items() if k in ("kind","id","producer_milestone_id","state",*BIND)}) == 0, "F1 contract --validate-entry finding")
    rec(validate_entry_via_contract("finding", {**{k:fnd("blocked")[k] for k in ("kind","id","state",*BIND)}, "producer_milestone_id":"v9"}) == 1, "F1neg contract rejects producer!=v0.6.3")
    # F2 unknown state
    rec(vno(fnd("maybe")), "F2 unknown state -> REJECT")
    # F3
    rec(vno(fnd("resolved", evidence_ref=None)), "F3a resolved w/o evidence_ref -> REJECT")
    rec(vno(fnd("accepted-risk", waiver={"approval": appr(type="plan")})), "F3b waiver non-human type -> REJECT")
    rec(vno(fnd("accepted-risk", waiver={"approval": appr(source="codex-x")})), "F3b waiver bad source -> REJECT")
    rec(vno(fnd("accepted-risk", waiver={"approval": appr(work_id="W2")})), "F3c waiver foreign-subject -> REJECT")
    rec(vno(fnd("accepted-risk", waiver=None)), "F3d accepted-risk w/o waiver -> REJECT")
    rec(all(vno(fnd("deferred", **{k:None})) for k in ("owner","target","release_policy")), "F3e deferred missing owner/target/policy -> REJECT")
    # F4 summary_class
    rec(vno(fnd("resolved", summary_class="a b")) and vno(fnd("resolved", summary_class="x/y")) and vno(fnd("resolved", summary_class=None)), "F4 prose/path/missing summary_class -> REJECT")
    # gate helpers
    def claim(findings, **sx):
        s = {"work_id":"W1","plan_hash":H,"milestone_id":"v0.6.1","repo_hash":H,"verification_ref":"ver/r.md"}; s.update(sx)
        return {"subject":s,"findings":findings}
    def gv(c):
        try: return gate(c)["verdict"]
        except Bad: return "REFUSE"
    # F5 blocked / unknown -> REFUSE
    rec(gv(claim([fnd("blocked")])) == "REFUSE", "F5 blocked present -> REFUSE")
    # F6 subject mismatch
    rec(all(gv(claim([fnd("resolved", **{b:("W2" if b=="work_id" else "b"*64 if "hash" in b else "other/x")})])) == "REFUSE" for b in BIND), "F6 finding subject != claim -> REFUSE")
    # F7 all pass + empty
    rec(gate(claim([fnd("resolved"), fnd("deferred"), fnd("accepted-risk")]))["verdict"] == "ALLOW", "F7 all-PASS -> ALLOW")
    rec(gate(claim([]))["verdict"] == "ALLOW", "F7 empty findings -> ALLOW")
    # F8 append-check
    def ac(prev, nxt):
        try: return append_check({"prev":prev,"next":nxt})["verdict"]
        except Bad: return "REFUSE"
    p = [fnd("blocked", id="X1")]
    rec(ac(p, []) == "REFUSE", "F8a drop -> REFUSE")
    rec(ac(p, [fnd("resolved", id="X1")]) == "REFUSE", "F8b state rewrite -> REFUSE")
    reordered = json.loads(json.dumps({**fnd("blocked", id="X1")}))  # same content
    rec(ac(p, [reordered]) == "ALLOW", "F8b reorder/identical -> ALLOW")
    rec(ac([fnd("blocked", id="X1"), fnd("blocked", id="X1")], []) == "REFUSE", "F8c duplicate id -> REFUSE")
    rec(ac(p, [fnd("blocked", id="X1"), fnd("resolved", id="X2")]) == "ALLOW", "F8d pure addition -> ALLOW")
    # F9 release anti-bypass: drop a prior blocked, gate(next) would ALLOW, but release REFUSEs
    def rel(o):
        try: return release(o)["verdict"]
        except Bad: return "REFUSE"
    prev_b = [fnd("blocked", id="B1")]
    rec(gv(claim([])) == "ALLOW" and rel({"subject":claim([])["subject"],"prev":prev_b,"next":[]}) == "REFUSE", "F9 release refuses bypass-by-drop")
    rec(rel({"subject":claim([])["subject"],"prev":[fnd("resolved", id="R1")],"next":[fnd("resolved", id="R1")]}) == "ALLOW", "F9 release ALLOW when append-only + closure pass")
    # F10 dup-key / secret / malformed
    try: json.loads('{"id":"x","id":"y"}', object_pairs_hook=no_dup); e=False
    except ValueError: e=True
    rec(e, "F10 duplicate JSON key -> REJECT")
    rec(vno(fnd("resolved", summary_class="ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ012345")), "F10 secret-shaped -> REJECT")
    rec(gv("nope") == "REFUSE" and gv(claim("x")) == "REFUSE", "F10 malformed/non-array -> REFUSE")
    sys.stdout.write("\n".join(lines) + "\n")
    sys.stdout.write("  ---- self-test: %d PASS / %d FAIL ----\n" % (pas, fai))
    return 0 if fai == 0 else 1

def main():
    m = sys.argv[1] if len(sys.argv) > 1 else ""
    if m == "validate":
        if len(sys.argv) < 3: sys.stderr.write("usage: validate <finding|->\n"); return 2
        return validate_path(sys.argv[2])
    if m in ("gate","append-check","release"):
        if len(sys.argv) < 3: sys.stderr.write("usage: %s <json|-> [--out <file>]\n" % m); return 2
        out = None
        if "--out" in sys.argv:
            i = sys.argv.index("--out")
            if i+1 < len(sys.argv): out = sys.argv[i+1]
        fn = {"gate":gate,"append-check":append_check,"release":release}[m]
        return _decide(sys.argv[2], fn, out)
    if m == "selftest":
        return selftest()
    sys.stderr.write("usage: validate|gate|append-check|release <json|-> | selftest\n"); return 2

if __name__ == "__main__":
    sys.exit(main())
