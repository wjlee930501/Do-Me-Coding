#!/usr/bin/env bash
# DMC Reviewer Loop (v0.4.6) — ADVISORY / READ-ONLY.
#
# Validates a self-review artifact (.harness/schemas/self-review.schema.md) and, with --handoff, emits a populated
# external-review handoff (docs/REVIEW_HANDOFF_TEMPLATE.md) for Codex/Kim. The reviewer is advisory: this tool BLOCKS a
# self-review whose `auto_apply` is true (reviewer output is NEVER auto-applied). Mutates nothing; no live call.
#
# Usage:  reviewer-loop.sh --validate <self-review.json>   |   --handoff <self-review.json>   |   --self-test
# Exit: 0 = valid (auto_apply false), 1 = invalid / auto_apply true, 2 = usage.
set -u
set -o pipefail
export PYTHONDONTWRITEBYTECODE=1
ROOTDIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

validate() { # <self-review.json>  -> prints result; return 0 valid / 1 invalid
  python3 - "$1" <<'PY'
import json,sys
try: r=json.load(open(sys.argv[1]))
except Exception as e: print("INVALID: not valid JSON"); sys.exit(1)
errs=[]
if not isinstance(r,dict): print("INVALID: not an object"); sys.exit(1)
for k in ("review_id","risk_level","files_touched","tests_run","evidence_refs","findings","open_questions","auto_apply"):
    if k not in r: errs.append("missing field: %s"%k)
if r.get("risk_level") not in ("low","medium","high"): errs.append("risk_level must be low|medium|high")
for k in ("files_touched","tests_run","evidence_refs","findings","open_questions"):
    if k in r and not isinstance(r[k],list): errs.append("%s must be a list"%k)
# the load-bearing safety rule: reviewer output is NEVER auto-applied
if r.get("auto_apply") is not False: errs.append("auto_apply must be false (reviewer output is advisory; never auto-applied)")
if errs:
    print("INVALID:")
    for e in errs: print("  - "+e)
    sys.exit(1)
print("VALID: self-review conforms; auto_apply=false (advisory; findings=%d; risk=%s)"%(len(r.get("findings",[])), r.get("risk_level")))
sys.exit(0)
PY
}

handoff() { # <self-review.json>  -> emit a populated review handoff (redacts nothing it shouldn't; advisory)
  validate "$1" >/dev/null || { echo "reviewer-loop: self-review invalid — refusing to emit a handoff" >&2; return 1; }
  python3 - "$1" "$ROOTDIR/docs/REVIEW_HANDOFF_TEMPLATE.md" <<'PY'
import json,sys
r=json.load(open(sys.argv[1]))
def lst(x): return ", ".join(str(i) for i in x) if isinstance(x,list) else str(x)
out=open(sys.argv[2]).read()
# emit only the fenced prompt with placeholders filled
import re
m=re.search(r'```text\n(.*?)```', out, re.S)
t=m.group(1) if m else out
t=t.replace("<review_id>", str(r.get("review_id","")))
t=t.replace("<risk_level>", str(r.get("risk_level","")))
t=t.replace("<files_touched>", lst(r.get("files_touched",[])))
t=t.replace("<tests_run, command : result>", "; ".join("%s : %s"%(x.get("command",""),x.get("result","")) for x in r.get("tests_run",[]) if isinstance(x,dict)))
t=t.replace("<evidence_refs>", lst(r.get("evidence_refs",[])))
t=t.replace("<findings>", "; ".join(x.get("title","") for x in r.get("findings",[]) if isinstance(x,dict)))
t=t.replace("<open_questions>", lst(r.get("open_questions",[])))
sys.stdout.write(t)
PY
}

# ---------------------------------------------------------------- self-test
self_test() {
  local P=0 F=0; ok(){ echo "  PASS $1"; P=$((P+1)); }; no(){ echo "  FAIL $1"; F=$((F+1)); }
  local TT; TT="$(mktemp -d)"; trap 'rm -rf "$TT"' RETURN
  local PRE; PRE="$(git -C "$ROOTDIR" status --porcelain 2>/dev/null | md5)"

  printf '%s' '{"review_id":"r-1","risk_level":"low","files_touched":["a.sh"],"tests_run":[{"command":"bash a.sh --self-test","result":"7 PASS / 0 FAIL"}],"evidence_refs":[".harness/evidence/a.sh"],"findings":[{"severity":"info","title":"all green"}],"open_questions":[],"auto_apply":false}' > "$TT/ok.json"
  printf '%s' '{"review_id":"r-2","risk_level":"low","files_touched":[],"tests_run":[],"evidence_refs":[],"findings":[],"open_questions":[],"auto_apply":true}' > "$TT/auto.json"
  printf '%s' '{"review_id":"r-3","risk_level":"extreme","files_touched":[],"tests_run":[],"evidence_refs":[],"findings":[],"open_questions":[],"auto_apply":false}' > "$TT/badrisk.json"
  printf '%s' '{"review_id":"r-4","auto_apply":false}' > "$TT/missing.json"
  printf '%s' 'not json' > "$TT/notjson.json"

  validate "$TT/ok.json" >/dev/null; [ $? = 0 ] && ok "AC1 valid self-review (auto_apply=false) => VALID" || no "AC1 valid rejected"
  validate "$TT/auto.json" >/dev/null; [ $? = 1 ] && ok "AC2 auto_apply=true => INVALID (reviewer output never auto-applied)" || no "AC2 auto_apply not blocked"
  validate "$TT/badrisk.json" >/dev/null; [ $? = 1 ] && ok "AC3 invalid risk_level => INVALID" || no "AC3 bad risk allowed"
  validate "$TT/missing.json" >/dev/null; [ $? = 1 ] && ok "AC4 missing required fields => INVALID" || no "AC4 missing allowed"
  validate "$TT/notjson.json" >/dev/null; [ $? = 1 ] && ok "AC5 non-JSON => INVALID (no crash)" || no "AC5 notjson"

  # AC6 handoff emitted from a valid self-review, placeholders filled, advisory note present
  local h; h="$(handoff "$TT/ok.json" 2>/dev/null)"
  { printf '%s' "$h" | grep -q 'DMC Independent Review — r-1' && printf '%s' "$h" | grep -q 'a.sh' \
    && printf '%s' "$h" | grep -qi 'advisory' && printf '%s' "$h" | grep -qi 'never .*auto-appl\|does NOT auto-apply'; } \
    && ok "AC6 handoff: populated Codex/Kim prompt; advisory + no-auto-apply note present" || no "AC6 handoff"
  # AC7 handoff refused on an invalid (auto_apply) self-review
  handoff "$TT/auto.json" >/dev/null 2>&1; [ $? = 1 ] && ok "AC7 handoff refused on an auto_apply self-review" || no "AC7 handoff not refused"

  [ "$(git -C "$ROOTDIR" status --porcelain 2>/dev/null | md5)" = "$PRE" ] && ok "AC8 read-only: repo byte-unchanged" || no "AC8 repo changed"
  echo "  ---- self-test: PASS=$P FAIL=$F ----"; [ "$F" = 0 ]
}

case "${1:-}" in
  --self-test) echo "==== DMC REVIEWER LOOP — SELF-TEST ===="; self_test; exit $?;;
  --validate) [ -f "${2:-}" ] || { echo "reviewer-loop: --validate <self-review.json> not found" >&2; exit 2; }; validate "$2"; exit $?;;
  --handoff) [ -f "${2:-}" ] || { echo "reviewer-loop: --handoff <self-review.json> not found" >&2; exit 2; }; handoff "$2"; exit $?;;
  -h|--help) sed -n '2,10p' "$0"; exit 0;;
  *) echo "reviewer-loop: use --validate <f> | --handoff <f> | --self-test" >&2; exit 2;;
esac
