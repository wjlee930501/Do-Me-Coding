#!/usr/bin/env python3
# DMC v0.6.4 Goal Ledger (core). ADVISORY / READ-ONLY / INPUT-ONLY, fail-closed, append-only/immutable history.
# Answers Q4. Validates goal-ledger entries; --transition (state machine); --append-check (no rewrite/delete, canonical
# per (goal_id,seq)); --trace (every completion traces to an approved goal); --authorize = append-check AND trace (anti-bypass).
# No temp/heredoc, no git, no env/.env/network. goal_id is a preexisting v0.4.1 reference.
#   python3 dmc-v0.6.4-goal-ledger.py validate <entry|->
#   python3 dmc-v0.6.4-goal-ledger.py transition <{from,to}|->
#   python3 dmc-v0.6.4-goal-ledger.py append-check <{prev,next}|-> [--out f]
#   python3 dmc-v0.6.4-goal-ledger.py trace <{ledger,completion}|-> [--out f]
#   python3 dmc-v0.6.4-goal-ledger.py authorize <{prev,next,completion}|-> [--out f]
#   python3 dmc-v0.6.4-goal-ledger.py selftest
# Exit: validate/transition 0/1/2; gate-likes 0 ALLOW / 1 REFUSE / 2 usage.
import json, sys, re, os, subprocess

GOAL_STATES = {"proposed","approved","in-progress","completed","blocked","abandoned"}
TRANSITIONS = {
  "proposed": {"approved","abandoned"},
  "approved": {"in-progress","abandoned"},
  "in-progress": {"completed","blocked","abandoned"},
  "blocked": {"in-progress","abandoned"},
  "completed": set(),
  "abandoned": set(),
}
COMPLETION_STATES = {"open","done"}
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
    if token_ok(s) or HASH_RE.match(s): return True
    return PATH_RE.match(s) is not None and ".." not in s.split("/")
def is_int(x): return isinstance(x, int) and not isinstance(x, bool)
def canonical(e): return json.dumps(e, sort_keys=True, separators=(",", ":"))

def validate_entry_via_contract(kind, entry):
    try:
        r = subprocess.run([sys.executable, CONTRACT, "validate-entry", kind, "-"],
                           input=json.dumps(entry).encode(), capture_output=True)
        return r.returncode
    except Exception:
        return 2

def validate_entry(e):
    if not isinstance(e, dict): raise Bad("entry not object")
    if scan(e): raise Bad("secret-shaped string present (G8)")
    if e.get("entry_kind") != "goal_ledger": raise Bad("entry_kind != goal_ledger")
    if e.get("producer_milestone_id") != "v0.6.4": raise Bad("producer_milestone_id != v0.6.4")
    if not token_ok(e.get("goal_id")): raise Bad("goal_id missing/not-token (G4)")
    if not is_int(e.get("seq")) or e["seq"] < 0: raise Bad("seq not int>=0 (G2)")
    if e.get("goal_state") not in GOAL_STATES: raise Bad("goal_state not in the six (G2)")
    if not token_ok(e.get("scope")) or not token_ok(e.get("constraints")): raise Bad("scope/constraints not token (G4)")
    el = e.get("evidence_links", [])
    if not isinstance(el, list) or any(not ref_ok(x) for x in el): raise Bad("evidence_links not all ref_ok (G4)")
    if e.get("completion_state") not in COMPLETION_STATES: raise Bad("completion_state not open|done (G2)")
    for b in BIND:
        if not nestr(e.get(b)): raise Bad("binding.%s missing/empty (G2)" % b)
    if not HASH_RE.match(e["plan_hash"]) or not HASH_RE.match(e["repo_hash"]): raise Bad("plan_hash/repo_hash not hash-shaped")
    if e["goal_state"] == "approved":
        appr = e.get("approval")
        if not isinstance(appr, dict): raise Bad("approved requires approval (G3)")
        for b in BIND:
            if appr.get(b) != e.get(b): raise Bad("approval.%s != entry subject (G3 foreign)" % b)
        if validate_entry_via_contract("approval", appr) != 0: raise Bad("approval fails --validate-entry approval (G3)")
    return True

def transition_ok(frm, to):
    return frm in GOAL_STATES and to in GOAL_STATES and to in TRANSITIONS.get(frm, set())

def _keymap(lst, where):
    if not isinstance(lst, list): raise Bad("%s not an array" % where)
    seen = {}
    for e in lst:
        if not isinstance(e, dict): raise Bad("%s entry not object" % where)
        gid, seq = e.get("goal_id"), e.get("seq")
        if not nestr(gid): raise Bad("%s entry.goal_id missing" % where)
        if not is_int(seq) or seq < 0: raise Bad("%s entry.seq not int>=0" % where)
        k = (gid, seq)
        if k in seen: raise Bad("duplicate (goal_id,seq) in %s: %s (G6)" % (where, k))
        seen[k] = e
    return seen

def append_check(obj):
    if not isinstance(obj, dict): raise Bad("input not object")
    if scan(obj): raise Bad("secret-shaped string present (G8)")
    pm = _keymap(obj.get("prev"), "prev"); nm = _keymap(obj.get("next"), "next")
    for k, pe in pm.items():
        if k not in nm: raise Bad("prev entry dropped: %s (G6)" % (k,))
        if canonical(pe) != canonical(nm[k]): raise Bad("prev entry rewritten: %s (G6)" % (k,))
    return {"verdict":"ALLOW","reason":"append-only (no drop/rewrite)","n_prev":len(pm),"n_next":len(nm)}

def trace(obj):
    if not isinstance(obj, dict): raise Bad("input not object")
    if scan(obj): raise Bad("secret-shaped string present (G8)")
    ledger = obj.get("ledger"); comp = obj.get("completion")
    if not isinstance(ledger, list): raise Bad("ledger not an array")
    if not isinstance(comp, dict): raise Bad("completion not object")
    seen = set(); bygoal = {}
    for e in ledger:
        validate_entry(e)
        k = (e["goal_id"], e["seq"])
        if k in seen: raise Bad("duplicate (goal_id,seq) in ledger: %s (G7)" % (k,))
        seen.add(k); bygoal.setdefault(e["goal_id"], []).append(e)
    gid = comp.get("goal_id")
    if not token_ok(gid): raise Bad("completion.goal_id missing/not-token")
    if gid not in bygoal: raise Bad("completion goal_id not in ledger (G7) -> REFUSE")
    hist = sorted(bygoal[gid], key=lambda e: e["seq"])
    if not any(e["goal_state"] == "approved" for e in hist): raise Bad("goal never approved in full history (G7) -> REFUSE")
    latest = hist[-1]["goal_state"]
    if not transition_ok(latest, "completed"): raise Bad("latest state '%s' cannot legally -> completed (G7) -> REFUSE" % latest)
    return {"verdict":"ALLOW","reason":"completion traces to an approved goal",
            "authorizing_goal_Q4":{"goal_id":gid,"latest_state":latest,"approved_in_history":True,"history_len":len(hist)}}

def authorize(obj):
    if not isinstance(obj, dict): raise Bad("input not object")
    if scan(obj): raise Bad("secret-shaped string present (G8)")
    append_check({"prev": obj.get("prev"), "next": obj.get("next")})        # raises on drop/rewrite/dup
    g = trace({"ledger": obj.get("next"), "completion": obj.get("completion")})  # raises on no-approved/illegal/not-in-ledger
    return {"verdict":"ALLOW","reason":"append-only AND completion-traces-to-goal both pass",
            "authorizing_goal_Q4": g["authorizing_goal_Q4"]}

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
    try: e = load(path)
    except ValueError as ex: sys.stderr.write("INVALID: json: %s\n" % ex); return 1
    except Exception as ex: sys.stderr.write("INVALID: read: %s\n" % ex); return 2
    try: validate_entry(e)
    except Bad as ex: sys.stderr.write("INVALID: %s\n" % ex); return 1
    sys.stdout.write("VALID\n"); return 0

def transition_path(path):
    try: o = load(path)
    except ValueError as ex: sys.stderr.write("ILLEGAL: json: %s\n" % ex); return 1
    except Exception as ex: sys.stderr.write("ILLEGAL: read: %s\n" % ex); return 2
    if not isinstance(o, dict) or scan(o) or not transition_ok(o.get("from"), o.get("to")):
        sys.stderr.write("ILLEGAL transition: %s -> %s\n" % (o.get("from") if isinstance(o, dict) else "?", o.get("to") if isinstance(o, dict) else "?")); return 1
    sys.stdout.write("LEGAL\n"); return 0

def _decide(path, fn, out=None):
    try: obj = load(path)
    except ValueError as ex: sys.stderr.write("REFUSE: json: %s\n" % ex); return 1
    except Exception as ex: sys.stderr.write("REFUSE: read: %s\n" % ex); return 2
    try: rec = fn(obj)
    except Bad as ex: rec = {"verdict":"REFUSE","reason":str(ex)}
    blob = json.dumps(rec, indent=2, sort_keys=True)
    if out:
        if out_unsafe(out): sys.stderr.write("REFUSED: unsafe --out path: %s\n" % out); return 2
        open(out, "w").write(blob + "\n")
    else:
        sys.stdout.write(blob + "\n")
    return 0 if rec["verdict"] == "ALLOW" else 1

def selftest():
    pas = fai = 0; lines = []
    def rec(ok, name):
        nonlocal pas, fai
        lines.append("  [%s] %s" % ("PASS" if ok else "FAIL", name)); pas += ok; fai += (not ok)
    H = "a"*64
    bind = {"work_id":"W1","plan_hash":H,"repo_hash":H,"verification_ref":"ver/r.md"}
    def appr(**x):
        d = {"kind":"approval","id":"A1","producer_milestone_id":"human-release-gate","type":"human-release-gate","source":"human-release-gate:auth1"}; d.update(bind); d.update(x); return d
    def ent(goal_id="g1", seq=0, goal_state="proposed", **x):
        d = {"entry_kind":"goal_ledger","producer_milestone_id":"v0.6.4","goal_id":goal_id,"seq":seq,"goal_state":goal_state,
             "scope":"feature-x","constraints":"no-net","evidence_links":["evid123456"],"completion_state":"open"}; d.update(bind)
        if goal_state == "approved": d["approval"] = appr()
        d.update(x); return d
    def vok(e):
        try: validate_entry(e); return True
        except Bad: return False
    # G1 valid entries + approval via contract
    rec(all(vok(ent(goal_state=s)) for s in GOAL_STATES), "G1 valid entries (6 states)")
    rec(vok(ent(goal_state="approved")) and validate_entry_via_contract("approval", appr()) == 0, "G1 approved entry's approval passes contract")
    # G2 bad fields
    rec(not vok(ent(goal_state="weird")), "G2 unknown goal_state -> REJECT")
    rec(not vok(ent(seq=-1)) and not vok(ent(seq="0")) and not vok(ent(seq=True)), "G2 bad seq -> REJECT")
    rec(not vok({k:v for k,v in ent().items() if k != "entry_kind"}), "G2 missing entry_kind -> REJECT")
    # G3 approval
    rec(not vok(ent(goal_state="approved", approval=appr(type="plan"))), "G3 non-human approval -> REJECT")
    rec(not vok(ent(goal_state="approved", approval=appr(source="codex-x"))), "G3 bad approval source -> REJECT")
    rec(not vok(ent(goal_state="approved", approval=appr(work_id="W2"))), "G3 foreign-subject approval -> REJECT")
    rec(not vok(ent(goal_state="approved", approval=None)), "G3 approved w/o approval -> REJECT")
    # G4 tokens
    rec(not vok(ent(scope="a b")) and not vok(ent(constraints="x/y")) and not vok(ent(goal_id="g 1")), "G4 prose scope/constraints/goal_id -> REJECT")
    rec(not vok(ent(evidence_links=["bad ref"])), "G4 bad evidence_links -> REJECT")
    # G5 transitions
    legal = [("proposed","approved"),("approved","in-progress"),("in-progress","completed"),("in-progress","blocked"),("blocked","in-progress"),("approved","abandoned")]
    illegal = [("proposed","completed"),("proposed","in-progress"),("completed","proposed"),("completed","in-progress"),("abandoned","approved"),("blocked","completed")]
    rec(all(transition_ok(a,b) for a,b in legal) and all(not transition_ok(a,b) for a,b in illegal), "G5 transitions legal/illegal (incl terminal re-entry)")
    # G6 append-check
    def ac(prev, nxt):
        try: return append_check({"prev":prev,"next":nxt})["verdict"]
        except Bad: return "REFUSE"
    p = [ent("g1", 0, "approved")]
    rec(ac(p, []) == "REFUSE", "G6 delete -> REFUSE")
    rec(ac(p, [ent("g1", 0, "abandoned")]) == "REFUSE", "G6 rewrite -> REFUSE")
    rec(ac(p, [json.loads(json.dumps(ent("g1", 0, "approved")))]) == "ALLOW", "G6 reorder/identical -> ALLOW")
    rec(ac([ent("g1",0), ent("g1",0)], []) == "REFUSE", "G6 duplicate (goal_id,seq) -> REFUSE")
    rec(ac(p, [ent("g1",0,"approved"), ent("g1",1,"in-progress")]) == "ALLOW", "G6 pure addition -> ALLOW")
    # G7 trace
    def tr(ledger, comp):
        try: return trace({"ledger":ledger,"completion":comp})["verdict"]
        except Bad: return "REFUSE"
    L_ok = [ent("g1",0,"approved"), ent("g1",1,"in-progress")]
    rec(tr(L_ok, {"goal_id":"gX","completion_state":"done"}) == "REFUSE", "G7 goal not in ledger -> REFUSE")
    rec(tr([ent("g1",0,"proposed"), ent("g1",1,"in-progress")], {"goal_id":"g1"}) == "REFUSE", "G7 never approved -> REFUSE")
    rec(tr([ent("g1",0,"approved"), ent("g1",1,"abandoned")], {"goal_id":"g1"}) == "REFUSE", "G7 abandoned latest -> REFUSE")
    rec(tr([ent("g1",0,"approved"), ent("g1",0,"in-progress")], {"goal_id":"g1"}) == "REFUSE", "G7 duplicate seq -> REFUSE")
    rec(tr(L_ok, {"goal_id":"g1","completion_state":"done"}) == "ALLOW", "G7 in-progress + prior approved -> ALLOW")
    # G7b authorize anti-bypass: prev has g1 abandoned@5; next fabricates approved@0+in-progress@1 (drops @5)
    def az(o):
        try: return authorize(o)["verdict"]
        except Bad: return "REFUSE"
    prev_real = [ent("g1", 5, "abandoned")]
    next_forged = [ent("g1", 0, "approved"), ent("g1", 1, "in-progress")]
    rec(tr(next_forged, {"goal_id":"g1"}) == "ALLOW" and az({"prev":prev_real,"next":next_forged,"completion":{"goal_id":"g1"}}) == "REFUSE", "G7b authorize refuses bypass-by-rewrite")
    rec(az({"prev":L_ok,"next":L_ok,"completion":{"goal_id":"g1"}}) == "ALLOW", "G7b authorize ALLOW when append-only + trace pass")
    # G8 dup-key / secret / malformed
    try: json.loads('{"goal_id":"x","goal_id":"y"}', object_pairs_hook=no_dup); e8=False
    except ValueError: e8=True
    rec(e8, "G8 duplicate JSON key -> REJECT")
    rec(not vok(ent(scope="ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ012345")), "G8 secret-shaped -> REJECT")
    rec(tr("x", {}) == "REFUSE" and ac("x", "y") == "REFUSE", "G8 malformed/non-array -> REFUSE")
    sys.stdout.write("\n".join(lines) + "\n")
    sys.stdout.write("  ---- self-test: %d PASS / %d FAIL ----\n" % (pas, fai))
    return 0 if fai == 0 else 1

def main():
    m = sys.argv[1] if len(sys.argv) > 1 else ""
    if m == "validate":
        if len(sys.argv) < 3: sys.stderr.write("usage: validate <entry|->\n"); return 2
        return validate_path(sys.argv[2])
    if m == "transition":
        if len(sys.argv) < 3: sys.stderr.write("usage: transition <{from,to}|->\n"); return 2
        return transition_path(sys.argv[2])
    if m in ("append-check","trace","authorize"):
        if len(sys.argv) < 3: sys.stderr.write("usage: %s <json|-> [--out f]\n" % m); return 2
        out = None
        if "--out" in sys.argv:
            i = sys.argv.index("--out")
            if i+1 < len(sys.argv): out = sys.argv[i+1]
        fn = {"append-check":append_check,"trace":trace,"authorize":authorize}[m]
        return _decide(sys.argv[2], fn, out)
    if m == "selftest":
        return selftest()
    sys.stderr.write("usage: validate|transition|append-check|trace|authorize <json|-> | selftest\n"); return 2

if __name__ == "__main__":
    sys.exit(main())
