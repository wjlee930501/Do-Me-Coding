#!/usr/bin/env python3
# DMC v0.6.5 Decision Traceability (core) — the capstone. ADVISORY / READ-ONLY / INPUT-ONLY, fail-closed.
# Answers Q5 + ships the mandatory six-question E2E proof: --answer validates a complete trace-linkage record via the
# v0.6.1.0 contract, resolves decision links to declared entries, and answers Q1-Q6 from the record alone (no model memory).
# No temp/heredoc, no git, no env/.env/network.
#   python3 dmc-v0.6.5-decision-trace.py validate <decision|->
#   python3 dmc-v0.6.5-decision-trace.py answer <record|-> [--out f]
#   python3 dmc-v0.6.5-decision-trace.py selftest
# Exit: validate 0/1/2; answer 0 ANSWERED / 1 REFUSE / 2 usage.
import json, sys, re, os, subprocess

BIND = ("work_id","plan_hash","repo_hash","verification_ref")
LINK_KEYS = ("capability_id","evidence_ids","finding_ids","goal_id","approval_id")
HASH_RE = re.compile(r'^[0-9a-f]{16,}$')
TOKEN_RE = re.compile(r'^[A-Za-z0-9._-]+$')
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

def validate_decision(d):
    if not isinstance(d, dict): raise Bad("decision not object")
    if scan(d): raise Bad("secret-shaped string present (D8)")
    if d.get("kind") != "decision": raise Bad("kind != decision")
    if d.get("producer_milestone_id") != "v0.6.5": raise Bad("producer_milestone_id != v0.6.5")
    if not nestr(d.get("id")): raise Bad("id missing/empty")
    for b in BIND:
        if not nestr(d.get(b)): raise Bad("binding.%s missing/empty" % b)
    if not HASH_RE.match(d["plan_hash"]) or not HASH_RE.match(d["repo_hash"]): raise Bad("plan_hash/repo_hash not hash-shaped")
    if not token_ok(d.get("rationale_class")): raise Bad("rationale_class missing/not-token (undocumented D2)")
    links = d.get("links")
    if not isinstance(links, dict): raise Bad("links missing (D3)")
    for k in LINK_KEYS:
        if k not in links: raise Bad("links.%s missing (D3)" % k)
    if not token_ok(links.get("capability_id")) or not token_ok(links.get("goal_id")) or not token_ok(links.get("approval_id")):
        raise Bad("links.capability_id/goal_id/approval_id not token (D3)")
    for arrk in ("evidence_ids","finding_ids"):
        v = links.get(arrk)
        if not isinstance(v, list) or any(not token_ok(x) for x in v): raise Bad("links.%s not all tokens (D3)" % arrk)
    return True

def contract_validate_record(record):
    try:
        r = subprocess.run([sys.executable, CONTRACT, "validate", "-"], input=json.dumps(record).encode(), capture_output=True)
        return r.returncode
    except Exception:
        return 2

def answer(record):
    if not isinstance(record, dict): raise Bad("record not object")
    if scan(record): raise Bad("secret-shaped string present (D8)")
    # 1. full-record validation via the committed contract (completeness + per-entry + edges + cross-subject)
    if contract_validate_record(record) != 0: raise Bad("record fails trace-linkage --validate (D5) -> REFUSE")
    regs = record["registers"]
    def ids(rk): return {e["id"] for e in regs.get(rk, [])}
    cap_ids, ev_ids, fnd_ids, goal_ids, appr_ids = ids("capability"), ids("evidence"), ids("finding"), ids("goal"), ids("approval")
    decisions = regs.get("decision", [])
    # 2. decision linkage: rationale documented + every link resolves to a declared entry of the matching register
    for d in decisions:
        if not token_ok(d.get("rationale_class")): raise Bad("decision %s rationale_class not token (undocumented D2) -> REFUSE" % d.get("id"))
        links = d.get("links")
        if not isinstance(links, dict) or any(k not in links for k in LINK_KEYS): raise Bad("decision %s links missing (D3) -> REFUSE" % d.get("id"))
        if links["capability_id"] not in cap_ids: raise Bad("decision %s links.capability_id unresolved (D6) -> REFUSE" % d.get("id"))
        if any(x not in ev_ids for x in links["evidence_ids"]): raise Bad("decision %s links.evidence_ids unresolved (D6) -> REFUSE" % d.get("id"))
        if any(x not in fnd_ids for x in links["finding_ids"]): raise Bad("decision %s links.finding_ids unresolved (D6) -> REFUSE" % d.get("id"))
        if links["goal_id"] not in goal_ids: raise Bad("decision %s links.goal_id unresolved (D6) -> REFUSE" % d.get("id"))
        if links["approval_id"] not in appr_ids: raise Bad("decision %s links.approval_id unresolved (untraceable approval D6) -> REFUSE" % d.get("id"))
    # 3. answer Q1-Q6 from the record alone
    return {"verdict":"ANSWERED","all_answerable":True,
            "Q1_capability": sorted(cap_ids),
            "Q2_evidence": sorted(ev_ids),
            "Q3_findings": sorted([{"id":e["id"],"state":e.get("state")} for e in regs.get("finding",[])], key=lambda r: r["id"]) or "none",
            "Q4_goal": sorted(goal_ids),
            "Q5_decision": sorted([{"id":d["id"],"rationale_class":d["rationale_class"]} for d in decisions], key=lambda r: r["id"]),
            "Q6_approval": sorted(appr_ids)}

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
    try: d = load(path)
    except ValueError as ex: sys.stderr.write("INVALID: json: %s\n" % ex); return 1
    except Exception as ex: sys.stderr.write("INVALID: read: %s\n" % ex); return 2
    try: validate_decision(d)
    except Bad as ex: sys.stderr.write("INVALID: %s\n" % ex); return 1
    sys.stdout.write("VALID\n"); return 0

def answer_path(path, out=None):
    try: rec = load(path)
    except ValueError as ex: sys.stderr.write("REFUSE: json: %s\n" % ex); return 1
    except Exception as ex: sys.stderr.write("REFUSE: read: %s\n" % ex); return 2
    try: r = answer(rec)
    except Bad as ex: r = {"verdict":"REFUSE","reason":str(ex)}
    blob = json.dumps(r, indent=2, sort_keys=True)
    if out:
        if out_unsafe(out): sys.stderr.write("REFUSED: unsafe --out path: %s\n" % out); return 2
        open(out, "w").write(blob + "\n")
    else:
        sys.stdout.write(blob + "\n")
    return 0 if r["verdict"] == "ANSWERED" else 1

def selftest():
    import copy
    pas = fai = 0; lines = []
    def rec(ok, name):
        nonlocal pas, fai
        lines.append("  [%s] %s" % ("PASS" if ok else "FAIL", name)); pas += ok; fai += (not ok)
    H = "a"*64
    bind = {"work_id":"W1","plan_hash":H,"repo_hash":H,"verification_ref":"ver/r.md"}
    def e(kind, eid, prod, **x):
        d = {"kind":kind,"id":eid,"producer_milestone_id":prod}; d.update(bind); d.update(x); return d
    def decision_entry(**x):
        d = e("decision","D1","v0.6.5", rationale_class="ship-it",
              links={"capability_id":"cheap-fast","evidence_ids":["E1"],"finding_ids":["F1"],"goal_id":"g1","approval_id":"A1"})
        d.update(x); return d
    def full_record():
        return {"schema":"dmc.trace-linkage.v1",
                "subject":{"work_id":"W1","plan_hash":H,"milestone_id":"v0.6.1.0","repo_hash":H,"verification_ref":"ver/r.md"},
                "registers":{
                  "capability":[e("capability_class","cheap-fast","v0.6.1")],
                  "evidence":[e("evidence_receipt","E1","v0.6.2")],
                  "finding":[e("finding","F1","v0.6.3", state="resolved")],
                  "goal":[e("goal","g1","v0.4.1")],
                  "decision":[decision_entry()],
                  "approval":[e("approval","A1","human-release-gate", type="human-release-gate", source="human-release-gate:auth1")]},
                "edges":[{"from":{"kind":"decision","id":"D1"},"to":{"kind":"evidence_receipt","id":"E1"}}]}
    def vok(d):
        try: validate_decision(d); return True
        except Bad: return False
    # D1
    rec(vok(decision_entry()), "D1 valid decision entry")
    base = {k:decision_entry()[k] for k in ("kind","id","producer_milestone_id",*BIND)}
    rec(__import__("subprocess").run([sys.executable, CONTRACT, "validate-entry","decision","-"], input=json.dumps(base).encode(), capture_output=True).returncode == 0, "D1 contract --validate-entry decision")
    # D2 / D3
    rec(not vok(decision_entry(rationale_class="why is fine")) and not vok(decision_entry(rationale_class=None)), "D2 prose/missing rationale_class -> REJECT")
    rec(not vok(decision_entry(links={"capability_id":"c"})) and not vok(decision_entry(links={"capability_id":"cheap-fast","evidence_ids":["E1"],"finding_ids":["F1"],"goal_id":"g1","approval_id":"bad id"})), "D3 links missing-key / bad-id -> REJECT")
    # D4 the mandatory six-question E2E proof
    def ans(r):
        try: return answer(r)
        except Bad: return {"verdict":"REFUSE"}
    a = ans(full_record())
    rec(a["verdict"] == "ANSWERED" and all(k in a for k in ("Q1_capability","Q2_evidence","Q3_findings","Q4_goal","Q5_decision","Q6_approval")) and a["Q6_approval"] == ["A1"] and a["Q4_goal"] == ["g1"] and a["Q1_capability"] == ["cheap-fast"], "D4 complete trace -> ANSWERED (Q1-Q6 all present)")
    # D5 contract reject -> REFUSE (empty evidence register)
    r5 = copy.deepcopy(full_record()); r5["registers"]["evidence"] = []
    rec(ans(r5)["verdict"] == "REFUSE", "D5 incomplete record (empty evidence) -> REFUSE")
    # D6 untraceable approval link
    r6 = copy.deepcopy(full_record()); r6["registers"]["decision"][0]["links"]["approval_id"] = "A9"
    rec(ans(r6)["verdict"] == "REFUSE", "D6 unresolved links.approval_id -> REFUSE")
    # D7 findings empty still answered; capability empty -> REFUSE
    r7 = copy.deepcopy(full_record()); r7["registers"]["finding"] = []; r7["registers"]["decision"][0]["links"]["finding_ids"] = []
    rec(ans(r7)["verdict"] == "ANSWERED" and ans(r7)["Q3_findings"] == "none", "D7 empty findings -> ANSWERED (Q3=none)")
    r7b = copy.deepcopy(full_record()); r7b["registers"]["capability"] = []
    rec(ans(r7b)["verdict"] == "REFUSE", "D7 empty capability -> REFUSE")
    # D8 dup-key / secret / malformed
    try: json.loads('{"id":"x","id":"y"}', object_pairs_hook=no_dup); d8=False
    except ValueError: d8=True
    rec(d8, "D8 duplicate JSON key -> REJECT")
    rec(not vok(decision_entry(rationale_class="ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ012345")), "D8 secret-shaped -> REJECT")
    rec(ans("nope")["verdict"] == "REFUSE", "D8 malformed root -> REFUSE")
    sys.stdout.write("\n".join(lines) + "\n")
    sys.stdout.write("  ---- self-test: %d PASS / %d FAIL ----\n" % (pas, fai))
    return 0 if fai == 0 else 1

def main():
    m = sys.argv[1] if len(sys.argv) > 1 else ""
    if m == "validate":
        if len(sys.argv) < 3: sys.stderr.write("usage: validate <decision|->\n"); return 2
        return validate_path(sys.argv[2])
    if m == "answer":
        if len(sys.argv) < 3: sys.stderr.write("usage: answer <record|-> [--out f]\n"); return 2
        out = None
        if "--out" in sys.argv:
            i = sys.argv.index("--out")
            if i+1 < len(sys.argv): out = sys.argv[i+1]
        return answer_path(sys.argv[2], out)
    if m == "selftest":
        return selftest()
    sys.stderr.write("usage: validate <decision|-> | answer <record|-> [--out f] | selftest\n"); return 2

if __name__ == "__main__":
    sys.exit(main())
