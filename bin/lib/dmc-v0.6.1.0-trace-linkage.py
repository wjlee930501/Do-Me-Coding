#!/usr/bin/env python3
# DMC v0.6.1.0 Trace Linkage Contract validator (core). ADVISORY / READ-ONLY / INPUT-ONLY, fail-closed, value-blind.
# Invoked by dmc-v0.6.1.0-trace-linkage.sh. No temp files, no heredoc, no git, no env/.env/network read.
#   python3 dmc-v0.6.1.0-trace-linkage.py validate <record.json>   |   python3 dmc-v0.6.1.0-trace-linkage.py selftest
# Exit: 0 valid, 1 invalid (fail-closed), 2 usage/read-error.
import json, sys, re

SCHEMA = "dmc.trace-linkage.v1"
CLASSES = {"frontier-long-horizon","standard-implementation","cheap-fast","adversarial-review","deterministic-tool","human-only-gate"}
STATES  = {"resolved","accepted-risk","deferred","blocked"}
# register key -> (required entry kind, required producer_milestone_id)   [pinned verbatim from the schema doc]
REG = {
  "capability": ("capability_class","v0.6.1"),
  "evidence":   ("evidence_receipt","v0.6.2"),
  "finding":    ("finding","v0.6.3"),
  "goal":       ("goal","v0.4.1"),
  "decision":   ("decision","v0.6.5"),
  "approval":   ("approval","human-release-gate"),
}
# a VALID record is a COMPLETE trace: every register key present; these five non-empty so Q1/Q2/Q4/Q5/Q6 are answerable
# (findings may be legitimately empty — "no findings" is a valid Q3 answer).
REQUIRED_NONEMPTY = ("capability","evidence","goal","decision","approval")
APPROVAL_PREFIX = "human-release-gate:"
HASH_RE = re.compile(r'^[0-9a-f]{16,}$')
UNSAFE = re.compile(
  r'sk-[A-Za-z0-9_-]{16,}|AKIA[0-9A-Z]{8,}|(?:BEGIN|END)[A-Z ]*PRIVATE KEY|xox[baprs]-[A-Za-z0-9-]{6,}'
  r'|gh[opsu]_[A-Za-z0-9]{16,}|github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{16,}|npm_[A-Za-z0-9]{30,}'
  r'|AIza[0-9A-Za-z_-]{20,}|dop_v1_[A-Za-z0-9]{32,}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'
  r'|ya29\.[A-Za-z0-9_-]{10,}|AccountKey=[A-Za-z0-9+/=]{20,}|Bearer\s+[A-Za-z0-9._-]{12,}'
  r'|(?:password|api_key|client_secret|aws_secret_access_key)\s*=\s*\S+|[A-Za-z0-9_-]*_token\s*[=:]\s*\S+'
)

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

def validate_record(rec):
    if not isinstance(rec, dict): raise Bad("root not object")
    if scan(rec): raise Bad("secret-shaped string present (T10)")
    if rec.get("schema") != SCHEMA: raise Bad("schema mismatch")
    subj = rec.get("subject")
    if not isinstance(subj, dict): raise Bad("subject missing")
    for k in ("work_id","plan_hash","milestone_id","repo_hash","verification_ref"):
        if not nestr(subj.get(k)): raise Bad("subject.%s missing/empty (T2)" % k)
    if not HASH_RE.match(subj["plan_hash"]): raise Bad("subject.plan_hash not hash-shaped (T2b)")
    if not HASH_RE.match(subj["repo_hash"]): raise Bad("subject.repo_hash not hash-shaped (T2b)")
    SW, SP, SR, SV = subj["work_id"], subj["plan_hash"], subj["repo_hash"], subj["verification_ref"]

    registers = rec.get("registers")
    if not isinstance(registers, dict): raise Bad("registers missing")
    # completeness (T15): every register key present; the five answer-bearing registers non-empty
    for rk in REG:
        if rk not in registers: raise Bad("registers missing key %s (completeness T15)" % rk)
    for rk in registers:
        if rk not in REG: raise Bad("unknown register: %s" % rk)
    for rk in REQUIRED_NONEMPTY:
        if not (isinstance(registers[rk], list) and len(registers[rk]) >= 1):
            raise Bad("register %s empty/missing — a VALID trace must answer Q1/Q2/Q4/Q5/Q6 (completeness T15)" % rk)

    declared = set()
    for rk, entries in registers.items():
        exp_kind, exp_prod = REG[rk]
        if not isinstance(entries, list): raise Bad("register %s not a list" % rk)
        for e in entries:
            if not isinstance(e, dict): raise Bad("entry in %s not object" % rk)
            if e.get("kind") != exp_kind: raise Bad("kind mismatch in %s (T6b/type)" % rk)
            eid = e.get("id")
            if not nestr(eid): raise Bad("entry.id missing in %s" % rk)
            if e.get("producer_milestone_id") != exp_prod: raise Bad("producer_milestone_id mismatch in %s (T8)" % rk)
            for bk, sv in (("work_id",SW),("plan_hash",SP),("repo_hash",SR),("verification_ref",SV)):
                if e.get(bk) != sv: raise Bad("entry %s.%s != subject (cross-subject T3/T3b/T4)" % (rk, bk))
            key = (exp_kind, eid)
            if key in declared: raise Bad("duplicate (kind,id): %r (T5)" % (key,))
            declared.add(key)
            if rk == "capability" and eid not in CLASSES: raise Bad("capability_class not in six (T9)")
            if rk == "finding" and e.get("state") not in STATES: raise Bad("finding.state not in four (T9)")
            if rk == "approval":
                if e.get("type") != "human-release-gate": raise Bad("approval.type not human-release-gate (T7)")
                src = e.get("source")
                if not (nestr(src) and src.startswith(APPROVAL_PREFIX)): raise Bad("approval.source not 'human-release-gate:' (T7c)")
                if src[len(APPROVAL_PREFIX):].strip() == "": raise Bad("approval.source missing non-empty auth-id (T7d)")

    edges = rec.get("edges", [])
    if not isinstance(edges, list): raise Bad("edges not a list")
    for ed in edges:
        if not isinstance(ed, dict): raise Bad("edge not object")
        for side in ("from","to"):
            ep = ed.get(side)
            if not isinstance(ep, dict): raise Bad("edge.%s not object" % side)
            k, i = ep.get("kind"), ep.get("id")
            if not (nestr(k) and nestr(i)): raise Bad("edge endpoint missing kind/id")
            if (k, i) not in declared: raise Bad("edge endpoint undeclared/type-confused: %r (T6/T6b)" % ((k,i),))
    return True

def validate_text(text):
    try:
        rec = json.loads(text, object_pairs_hook=no_dup)
    except ValueError as e:
        return 1, "json: %s" % e            # incl. duplicate-key (T11)
    try:
        validate_record(rec)
    except Bad as e:
        return 1, str(e)
    return 0, "VALID"

def read_text(path):
    if path == "-": return sys.stdin.read()      # stdin (no temp file needed in a no-temp sandbox)
    with open(path, "r") as f: return f.read()

def validate_path(path):
    try:
        text = read_text(path)
    except Exception as e:
        sys.stderr.write("INVALID: read: %s\n" % e); return 2
    code, msg = validate_text(text)
    if code == 0: sys.stdout.write("VALID\n")
    else: sys.stderr.write("INVALID: %s\n" % msg)
    return code

# entry-level (fragment) validation: a producer milestone (v0.6.1-v0.6.5) mints ONE register entry, not a complete trace.
# This checks the entry's WELL-FORMEDNESS (kind/producer/id/enum/binding-fields-present+shaped/approval/no-secret/no-dup-key).
# Cross-subject + completeness + edges remain RECORD-level checks (validate_record), done by the composer (v0.6.5).
def validate_entry(register_key, e):
    if register_key not in REG: raise Bad("unknown register key: %s" % register_key)
    if not isinstance(e, dict): raise Bad("entry not object")
    if scan(e): raise Bad("secret-shaped string present (entry T10)")
    exp_kind, exp_prod = REG[register_key]
    if e.get("kind") != exp_kind: raise Bad("entry.kind != %s" % exp_kind)
    if not nestr(e.get("id")): raise Bad("entry.id missing/empty")
    if e.get("producer_milestone_id") != exp_prod: raise Bad("entry.producer_milestone_id != %s (T8)" % exp_prod)
    for bk in ("work_id","plan_hash","repo_hash","verification_ref"):
        if not nestr(e.get(bk)): raise Bad("entry.%s missing/empty (binding)" % bk)
    if not HASH_RE.match(e["plan_hash"]): raise Bad("entry.plan_hash not hash-shaped")
    if not HASH_RE.match(e["repo_hash"]): raise Bad("entry.repo_hash not hash-shaped")
    if register_key == "capability" and e["id"] not in CLASSES: raise Bad("capability_class not in six (T9)")
    if register_key == "finding" and e.get("state") not in STATES: raise Bad("finding.state not in four (T9)")
    if register_key == "approval":
        if e.get("type") != "human-release-gate": raise Bad("approval.type not human-release-gate (T7)")
        if not (nestr(e.get("source")) and e["source"].startswith(APPROVAL_PREFIX)): raise Bad("approval.source not 'human-release-gate:' (T7c)")
        if e["source"][len(APPROVAL_PREFIX):].strip() == "": raise Bad("approval.source missing non-empty auth-id (T7d)")
    return True

def validate_entry_path(register_key, path):
    try:
        text = read_text(path)
    except Exception as e:
        sys.stderr.write("INVALID: read: %s\n" % e); return 2
    try:
        ent = json.loads(text, object_pairs_hook=no_dup)
    except ValueError as ex:
        sys.stderr.write("INVALID: json: %s\n" % ex); return 1
    try:
        validate_entry(register_key, ent)
    except Bad as ex:
        sys.stderr.write("INVALID: %s\n" % ex); return 1
    sys.stdout.write("VALID\n"); return 0

# ---------- in-memory self-test (no temp files, no git): positive + a negative control per reject rule ----------
def _base():
    H = "a"*64
    b = {"work_id":"W1","plan_hash":H,"repo_hash":H,"verification_ref":"ver/report.md"}
    def ent(kind, eid, prod, **x):
        e = {"kind":kind, "id":eid, "producer_milestone_id":prod}; e.update(b); e.update(x); return e
    return {
      "schema": SCHEMA,
      "subject": {"work_id":"W1","plan_hash":H,"milestone_id":"v0.6.1.0","repo_hash":H,"verification_ref":"ver/report.md"},
      "registers": {
        "capability":[ent("capability_class","deterministic-tool","v0.6.1")],
        "evidence":[ent("evidence_receipt","E1","v0.6.2")],
        "finding":[ent("finding","F1","v0.6.3", state="resolved")],
        "goal":[ent("goal","G1","v0.4.1")],
        "decision":[ent("decision","D1","v0.6.5")],
        "approval":[ent("approval","A1","human-release-gate", type="human-release-gate", source="human-release-gate:auth1")],
      },
      "edges":[{"from":{"kind":"decision","id":"D1"}, "to":{"kind":"evidence_receipt","id":"E1"}}],
    }

def selftest():
    import copy
    def mut(fn):
        r = copy.deepcopy(_base()); fn(r); return json.dumps(r)
    def secret(r): r["registers"]["evidence"][0]["id"] = "ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ012345"
    cases = [
      ("positive",                    json.dumps(_base()), True),
      ("T2-missing-subject-field",    mut(lambda r: r["subject"].pop("work_id")), False),
      ("T2b-bad-plan-hash",           mut(lambda r: r["subject"].update(plan_hash="not-hex")), False),
      ("T3-cross-subject-work_id",    mut(lambda r: r["registers"]["evidence"][0].update(work_id="W2")), False),
      ("T3b-cross-subject-plan_hash", mut(lambda r: r["registers"]["evidence"][0].update(plan_hash="b"*64)), False),
      ("T5-dup-kind-id",              mut(lambda r: r["registers"]["evidence"].append(copy.deepcopy(r["registers"]["evidence"][0]))), False),
      ("T6-dangling-edge",            mut(lambda r: r["edges"].append({"from":{"kind":"decision","id":"D1"},"to":{"kind":"evidence_receipt","id":"E9"}})), False),
      ("T6b-type-confusion-edge",     mut(lambda r: r["edges"].append({"from":{"kind":"finding","id":"E1"},"to":{"kind":"evidence_receipt","id":"E1"}})), False),
      ("T7-bad-approval-type",        mut(lambda r: r["registers"]["approval"][0].update(type="plan")), False),
      ("T7b-foreign-subject-approval",mut(lambda r: r["registers"]["approval"][0].update(work_id="W2")), False),
      ("T7c-bad-approval-source",     mut(lambda r: r["registers"]["approval"][0].update(source="codex-accept-123")), False),
      ("T7d-empty-approval-id",       mut(lambda r: r["registers"]["approval"][0].update(source="human-release-gate:")), False),
      ("T7d-blank-approval-id",       mut(lambda r: r["registers"]["approval"][0].update(source="human-release-gate:   ")), False),
      ("T8-wrong-producer",           mut(lambda r: r["registers"]["evidence"][0].update(producer_milestone_id="v0.6.9")), False),
      ("T9-bad-capability-class",     mut(lambda r: r["registers"]["capability"][0].update(id="not-a-class")), False),
      ("T9-bad-finding-state",        mut(lambda r: r["registers"]["finding"][0].update(state="maybe")), False),
      ("T10-secret-shaped",           mut(secret), False),
      ("T11-duplicate-json-key",      '{"schema":"%s","schema":"dup"}' % SCHEMA, False),
      ("T15-empty-registers",         mut(lambda r: r.update(registers={})), False),
      ("T15-missing-approval",        mut(lambda r: r["registers"].update(approval=[])), False),
      ("T15-empty-evidence",          mut(lambda r: r["registers"].update(evidence=[])), False),
    ]
    pas = fai = 0; lines = []
    for name, text, expect in cases:
        code, msg = validate_text(text)
        ok = (code == 0) == expect
        lines.append("  [%s] %-30s -> %s (expect %s)" % ("PASS" if ok else "FAIL", name, "VALID" if code==0 else "INVALID", "VALID" if expect else "INVALID"))
        pas += ok; fai += (not ok)
    # entry-level (fragment) validation controls
    H = "a"*64
    bind = {"work_id":"W1","plan_hash":H,"repo_hash":H,"verification_ref":"ver/report.md"}
    def cap(**x):
        d = {"kind":"capability_class","id":"cheap-fast","producer_milestone_id":"v0.6.1"}; d.update(bind); d.update(x); return d
    entry_cases = [
      ("entry-positive-capability", "capability", cap(), True),
      ("entry-wrong-kind",          "capability", cap(kind="evidence_receipt"), False),
      ("entry-wrong-producer",      "capability", cap(producer_milestone_id="v0.6.9"), False),
      ("entry-bad-class",           "capability", cap(id="not-a-class"), False),
      ("entry-missing-binding",     "capability", {k:v for k,v in cap().items() if k != "repo_hash"}, False),
      ("entry-secret",              "capability", cap(id="ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ012345"), False),
      ("entry-approval-bad-source", "approval",   {"kind":"approval","id":"A1","producer_milestone_id":"human-release-gate","type":"human-release-gate","source":"codex-x", **bind}, False),
      ("entry-approval-empty-id",   "approval",   {"kind":"approval","id":"A1","producer_milestone_id":"human-release-gate","type":"human-release-gate","source":"human-release-gate:", **bind}, False),
    ]
    for name, rk, ent, expect in entry_cases:
        try:
            validate_entry(rk, ent); code = 0
        except Bad:
            code = 1
        ok = (code == 0) == expect
        lines.append("  [%s] %-30s -> %s (expect %s)" % ("PASS" if ok else "FAIL", name, "VALID" if code==0 else "INVALID", "VALID" if expect else "INVALID"))
        pas += ok; fai += (not ok)
    sys.stdout.write("\n".join(lines) + "\n")
    sys.stdout.write("  ---- self-test: %d PASS / %d FAIL ----\n" % (pas, fai))
    return 0 if fai == 0 else 1

def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    if mode == "validate":
        if len(sys.argv) < 3: sys.stderr.write("usage: validate <path>\n"); return 2
        return validate_path(sys.argv[2])
    if mode == "validate-entry":
        if len(sys.argv) < 4: sys.stderr.write("usage: validate-entry <register-key> <path>\n"); return 2
        return validate_entry_path(sys.argv[2], sys.argv[3])
    if mode == "selftest":
        return selftest()
    sys.stderr.write("usage: validate <path> | validate-entry <register-key> <path> | selftest\n"); return 2

if __name__ == "__main__":
    sys.exit(main())
