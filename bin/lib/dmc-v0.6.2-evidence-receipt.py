#!/usr/bin/env python3
# DMC v0.6.2 Evidence Receipt Gate (core). ADVISORY / READ-ONLY / INPUT-ONLY, fail-closed. "No evidence -> no completion."
# Validates evidence receipts (Q2) and runs the completion-block gate: DONE is REFUSED unless a present, inspectable
# (non-prose artifact ref), subject-consistent verification-report receipt exists. Never trusts prose/summary/self-report.
# No temp/heredoc, no git, no env/.env/network. Receipt = a trace-linkage `evidence` fragment + v0.6.2-owned fields.
#   python3 dmc-v0.6.2-evidence-receipt.py validate <receipt.json|->
#   python3 dmc-v0.6.2-evidence-receipt.py gate <claim.json|-> [--out <file>]
#   python3 dmc-v0.6.2-evidence-receipt.py selftest
# Exit: validate 0 valid/1 invalid/2 usage; gate 0 ALLOW/1 REFUSE/2 usage; selftest 0/1.
import json, sys, re, os, subprocess

EVIDENCE_TYPES = {"verification-report","test-result","artifact-existence","review-packet","audit-report"}
REQUIRED_TYPE = "verification-report"
HASH_RE = re.compile(r'^[0-9a-f]{16,}$')
PATH_RE = re.compile(r'^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)+$')
UNSAFE = re.compile(
  r'sk-[A-Za-z0-9_-]{16,}|AKIA[0-9A-Z]{8,}|(?:BEGIN|END)[A-Z ]*PRIVATE KEY|xox[baprs]-[A-Za-z0-9-]{6,}'
  r'|gh[opsu]_[A-Za-z0-9]{16,}|github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{16,}|npm_[A-Za-z0-9]{30,}'
  r'|AIza[0-9A-Za-z_-]{20,}|dop_v1_[A-Za-z0-9]{32,}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'
  r'|ya29\.[A-Za-z0-9_-]{10,}|AccountKey=[A-Za-z0-9+/=]{20,}|Bearer\s+[A-Za-z0-9._-]{12,}'
  r'|(?:password|api_key|client_secret|aws_secret_access_key)\s*=\s*\S+|[A-Za-z0-9_-]*_token\s*[=:]\s*\S+'
)
CONTRACT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "dmc-v0.6.1.0-trace-linkage.py")
BIND = ("work_id","plan_hash","repo_hash","verification_ref")

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

def artifact_ref_ok(a):
    if not nestr(a): return False
    if any(c.isspace() for c in a): return False              # no whitespace/control
    if HASH_RE.match(a): return True
    if PATH_RE.match(a) and ".." not in a.split("/"): return True   # safe relative path, no traversal
    return False

def validate_receipt(r):
    if not isinstance(r, dict): raise Bad("receipt not object")
    if scan(r): raise Bad("secret-shaped string present (E8b)")
    if r.get("kind") != "evidence_receipt": raise Bad("kind != evidence_receipt")
    if r.get("producer_milestone_id") != "v0.6.2": raise Bad("producer_milestone_id != v0.6.2")
    if not nestr(r.get("id")): raise Bad("id missing/empty")
    for b in BIND:
        if not nestr(r.get(b)): raise Bad("binding.%s missing/empty" % b)
    if not HASH_RE.match(r["plan_hash"]): raise Bad("plan_hash not hash-shaped")
    if not HASH_RE.match(r["repo_hash"]): raise Bad("repo_hash not hash-shaped")
    if r.get("evidence_type") not in EVIDENCE_TYPES: raise Bad("evidence_type not in the five (E2d)")
    if not artifact_ref_ok(r.get("artifact_ref")): raise Bad("artifact_ref prose/unsafe/missing (E2/E2d)")
    if r.get("machine_verifiable") is True and not nestr(r.get("checker")): raise Bad("machine_verifiable without checker (E3)")
    return True

def gate(claim):
    if not isinstance(claim, dict): raise Bad("claim not object")
    if scan(claim): raise Bad("secret-shaped string present (E8b)")
    subj = claim.get("subject")
    if not isinstance(subj, dict): raise Bad("subject missing")
    for k in ("work_id","plan_hash","milestone_id","repo_hash","verification_ref"):
        if not nestr(subj.get(k)): raise Bad("subject.%s missing/empty" % k)
    if not HASH_RE.match(subj["plan_hash"]) or not HASH_RE.match(subj["repo_hash"]): raise Bad("subject hashes not hash-shaped")
    ev = claim.get("evidence")
    if not isinstance(ev, list) or len(ev) < 1: raise Bad("no evidence (empty/missing array) -> REFUSE (E4)")
    for i, r in enumerate(ev):
        try:
            validate_receipt(r)
        except Bad as e:
            raise Bad("invalid receipt[%d]: %s" % (i, e))
        for b in BIND:
            if r.get(b) != subj.get(b): raise Bad("receipt[%d].%s != subject (cross-subject/stale E6) -> REFUSE" % (i, b))
    if not any(r.get("evidence_type") == REQUIRED_TYPE for r in ev): raise Bad("required '%s' missing (E5) -> REFUSE" % REQUIRED_TYPE)
    return {"verdict":"ALLOW","reason":"required evidence present + all receipts subject-consistent",
            "subject":subj,"required_present":{REQUIRED_TYPE:True},
            "evidence_answering_Q2":[{"evidence_type":r["evidence_type"],"id":r["id"],"artifact_ref":r["artifact_ref"],
                                      "machine_verifiable":bool(r.get("machine_verifiable"))} for r in ev],
            "n_receipts":len(ev)}

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

def read_text(path):
    if path == "-": return sys.stdin.read()
    with open(path, "r") as f: return f.read()

def load(path):
    return json.loads(read_text(path), object_pairs_hook=no_dup)

def validate_path(path):
    try: rec = load(path)
    except ValueError as e: sys.stderr.write("INVALID: json: %s\n" % e); return 1
    except Exception as e: sys.stderr.write("INVALID: read: %s\n" % e); return 2
    try: validate_receipt(rec)
    except Bad as e: sys.stderr.write("INVALID: %s\n" % e); return 1
    sys.stdout.write("VALID\n"); return 0

def gate_path(path, out=None):
    try: claim = load(path)
    except ValueError as e:
        sys.stderr.write("REFUSE: json: %s\n" % e); return 1      # fail-closed: malformed -> no DONE
    except Exception as e:
        sys.stderr.write("REFUSE: read: %s\n" % e); return 2
    try:
        rec = gate(claim)
    except Bad as e:
        rec = {"verdict":"REFUSE","reason":str(e)}
    blob = json.dumps(rec, indent=2, sort_keys=True)
    if out:
        if out_unsafe(out): sys.stderr.write("REFUSED: unsafe --out path: %s\n" % out); return 2
        with open(out, "w") as f: f.write(blob + "\n")
    else:
        sys.stdout.write(blob + "\n")
    return 0 if rec["verdict"] == "ALLOW" else 1

def validate_fragment_via_contract(entry):
    try:
        r = subprocess.run([sys.executable, CONTRACT, "validate-entry", "evidence", "-"],
                           input=json.dumps(entry).encode(), capture_output=True)
        return r.returncode
    except Exception:
        return 2

def selftest():
    import copy
    pas = fai = 0; lines = []
    def rec(ok, name, detail=""):
        nonlocal pas, fai
        lines.append("  [%s] %-40s %s" % ("PASS" if ok else "FAIL", name, detail)); pas += ok; fai += (not ok)
    H = "a"*64
    bind = {"work_id":"W1","plan_hash":H,"repo_hash":H,"verification_ref":"ver/report.md"}
    def receipt(**x):
        d = {"kind":"evidence_receipt","id":"E1","producer_milestone_id":"v0.6.2","evidence_type":"verification-report",
             "artifact_ref":"ver/report.md","machine_verifiable":False,"checker":None}; d.update(bind); d.update(x); return d
    def valid(fn_obj):
        try: validate_receipt(fn_obj); return True
        except Bad: return False
    def refuses_receipt(fn_obj):
        try: validate_receipt(fn_obj); return False
        except Bad: return True

    # E1: each of the 5 types valid + contract accepts the base entry
    e1 = all(valid(receipt(evidence_type=t, id="E_"+t)) for t in EVIDENCE_TYPES)
    e1 = e1 and validate_fragment_via_contract(receipt()) == 0
    rec(e1, "E1 5 valid types + contract --validate-entry", "")
    # E2 artifact_ref predicate
    rec(refuses_receipt(receipt(artifact_ref="done")), "E2a bare token -> REJECT")
    rec(refuses_receipt(receipt(artifact_ref="see the report")), "E2b sentence/whitespace -> REJECT")
    rec(all(refuses_receipt(receipt(artifact_ref=a)) for a in ("/etc/passwd","a/../b","~/x","http://x/y","a\\b","a;rm")),
        "E2c absolute/../~/url/backslash/metachar -> REJECT")
    rec(refuses_receipt(receipt(artifact_ref=None)) and refuses_receipt(receipt(evidence_type="bogus")),
        "E2d missing ref / unknown type -> REJECT")
    # E3 machine_verifiable without checker
    rec(refuses_receipt(receipt(machine_verifiable=True, checker=None)), "E3 machine_verifiable w/o checker -> REJECT")
    # gate helpers
    def claim(ev, **subjx):
        s = {"work_id":"W1","plan_hash":H,"milestone_id":"v0.6.1","repo_hash":H,"verification_ref":"ver/report.md"}
        s.update(subjx)
        return {"subject":s,"completion_claim":{"done_requested":True,"claimed_by":"verifier"},"evidence":ev}
    def gv(c):
        try: return gate(c)["verdict"]
        except Bad: return "REFUSE"
    # E4 no-evidence / prose-only
    rec(gv(claim([])) == "REFUSE", "E4a empty evidence -> REFUSE")
    rec(gv({"subject":claim([])["subject"],"completion_claim":{"done_requested":True},"summary":"all good"}) == "REFUSE",
        "E4b prose-only (no evidence array) -> REFUSE")
    # E5 no verification-report
    rec(gv(claim([receipt(evidence_type="test-result", id="T1", artifact_ref="t/r.xml")])) == "REFUSE",
        "E5 no verification-report -> REFUSE")
    # E6 per-field subject mismatch
    for fld, badv in (("work_id","W2"),("plan_hash","b"*64),("repo_hash","b"*64),("verification_ref","other/ref.md")):
        r = receipt(); r[fld] = badv
        rec(gv(claim([r])) == "REFUSE", "E6 receipt.%s != subject -> REFUSE" % fld)
    # E7 ALLOW
    g7 = gate(claim([receipt()]))
    rec(g7["verdict"] == "ALLOW" and g7["required_present"][REQUIRED_TYPE] and g7["n_receipts"] == 1, "E7 valid verification-report -> ALLOW")
    # E8 dup key / secret / malformed
    try: load_text_dup = json.loads('{"kind":"evidence_receipt","kind":"x"}', object_pairs_hook=no_dup); e8a = False
    except ValueError: e8a = True
    rec(e8a, "E8a duplicate JSON key -> REJECT")
    rec(refuses_receipt(receipt(id="ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ012345")), "E8b secret-shaped -> REJECT")
    rec(gv("notadict") == "REFUSE" and gv({"subject":claim([])["subject"],"evidence":"nope"}) == "REFUSE"
        and gv(claim([receipt(producer_milestone_id="v9")])) == "REFUSE", "E8c malformed/non-array/invalid-receipt -> REFUSE")
    # contract negative: tampered fragment rejected by contract
    bad = receipt(producer_milestone_id="v9")
    rec(validate_fragment_via_contract(bad) == 1, "Cneg tampered fragment -> contract REJECT")

    sys.stdout.write("\n".join(lines) + "\n")
    sys.stdout.write("  ---- self-test: %d PASS / %d FAIL ----\n" % (pas, fai))
    return 0 if fai == 0 else 1

def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    if mode == "validate":
        if len(sys.argv) < 3: sys.stderr.write("usage: validate <receipt.json|->\n"); return 2
        return validate_path(sys.argv[2])
    if mode == "gate":
        if len(sys.argv) < 3: sys.stderr.write("usage: gate <claim.json|-> [--out <file>]\n"); return 2
        out = None
        if "--out" in sys.argv:
            i = sys.argv.index("--out")
            if i+1 < len(sys.argv): out = sys.argv[i+1]
        return gate_path(sys.argv[2], out)
    if mode == "selftest":
        return selftest()
    sys.stderr.write("usage: validate <receipt|-> | gate <claim|-> [--out <file>] | selftest\n"); return 2

if __name__ == "__main__":
    sys.exit(main())
