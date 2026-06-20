#!/usr/bin/env bash
# v0.2.1.1 GLM output-normalization verification (run: bash .harness/evidence/dmc-v0.2.1.1-verify.sh). NO live call.
# Mock-only. Proves: choices[].message.content normalization (bare JSON / fenced / prose), defensive envelope
# handling, plain-text/empty/non-stop fallback, length bounding, validator still gates adversarial output,
# adapter-enforced fields can't be overridden, mock-first back-compat, and guards/schemas/smoke-runner unchanged.
set -u
ROOT="$(pwd)"; PASS=0; FAIL=0
ok(){ echo "  PASS $1"; PASS=$((PASS+1)); }
no(){ echo "  FAIL $1"; FAIL=$((FAIL+1)); }
AD="$ROOT/.claude/workers/providers/glm-api/glm-api-adapter.py"
FX="$ROOT/.claude/workers/providers/glm-api/fixtures"
VAL="$ROOT/.claude/hooks/worker-result-check.py"
TASK="$ROOT/.harness/workers/tasks/mock-001.json"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

# adapter --mock <fixture> --task <task> -> $T/r.json ; returns adapter exit code
gen(){ python3 "$AD" --task "${2:-$TASK}" --mock "$FX/$1" --out "$T/r.json" >/dev/null 2>"$T/err"; }
accept(){ python3 "$VAL" "${1:-$TASK}" "$T/r.json" >/dev/null 2>"$T/verr"; }   # rc 0 = ACCEPT
# field <dotted.path> -> prints python repr of result field
field(){ DMC_FP="$1" python3 -c 'import json,os; r=json.load(open(os.environ["DMC_RJSON"]));
import functools
v=r
for k in os.environ["DMC_FP"].split("."):
    v=v.get(k) if isinstance(v,dict) else None
print(v)'; }
export DMC_RJSON="$T/r.json"

echo "== syntax =="
python3 -m py_compile "$AD" && ok "py_compile adapter" || no "py_compile adapter"

echo "== mock-first back-compat: top-level mock fixture unchanged (no choices key) =="
gen glm-response-mock.json && accept && [ "$(field summary)" != "None" ] && [ -n "$(field summary)" ] \
  && ok "top-level mock -> populated, ACCEPT (no regression)" || no "mock-first regression"

echo "== choices[].message.content bare JSON -> structured fields populated, ACCEPT =="
gen glm-response-success-choices.json
if accept && [ "$(field files_changed)" = "['src/setNames.ts']" ] && [ -n "$(field summary)" ] \
   && [ "$(field proposed_patch)" != "" ]; then ok "success-choices normalized + ACCEPT"; else no "success-choices"; fi

echo "== C1: fenced JSON (prose + \`\`\`json fence) -> SAME structured fields, ACCEPT =="
gen glm-response-fenced-json.json
if accept && [ "$(field files_changed)" = "['src/setNames.ts']" ] && [ -n "$(field summary)" ]; then
  ok "fenced-json extracted (naive json.loads would fail) + ACCEPT"; else no "fenced-json extraction"; fi

echo "== C2: empty choices [] -> graceful low-confidence empty result, no crash, ACCEPT =="
gen glm-response-empty-choices.json; rc=$?
if [ "$rc" = 0 ] && accept && [ "$(field files_changed)" = "[]" ] && [ "$(field confidence)" = "low" ]; then
  ok "empty-choices -> empty/low-confidence, no crash, ACCEPT"; else no "empty-choices envelope ($rc)"; fi

echo "== C2: missing choices key -> graceful empty (pass-through), no crash, ACCEPT =="
gen glm-response-missing-choices.json; rc=$?
if [ "$rc" = 0 ] && accept && [ "$(field files_changed)" = "[]" ]; then
  ok "missing-choices -> graceful empty, no crash, ACCEPT"; else no "missing-choices envelope ($rc)"; fi

echo "== malformed / non-JSON content -> plain-text fallback (instructions), files_changed [], ACCEPT =="
gen glm-response-malformed-content.json
if accept && [ "$(field files_changed)" = "[]" ] && [ -n "$(field instructions)" ] && [ "$(field confidence)" = "low" ]; then
  ok "malformed -> instructions fallback, ACCEPT"; else no "malformed fallback"; fi

echo "== empty content -> empty-but-valid, ACCEPT =="
gen glm-response-empty-content.json; rc=$?
if [ "$rc" = 0 ] && accept && [ "$(field files_changed)" = "[]" ]; then
  ok "empty-content -> ACCEPT (no crash)"; else no "empty-content ($rc)"; fi

echo "== non-stop finish_reason (length) -> fallback, confidence low, ACCEPT =="
gen glm-response-nonstop-finish.json
if accept && [ "$(field confidence)" = "low" ] && [ "$(field files_changed)" = "[]" ]; then
  ok "nonstop-finish -> low-confidence fallback, ACCEPT"; else no "nonstop-finish handling"; fi

echo "== overlong content -> bounded (instructions <= cap 8000), no crash, ACCEPT =="
gen glm-response-overlong-content.json; rc=$?
ilen="$(DMC_FP=instructions python3 -c 'import json,os; r=json.load(open(os.environ["DMC_RJSON"])); print(len(r.get("instructions") or ""))')"
if [ "$rc" = 0 ] && accept && [ "$ilen" -le 8000 ]; then
  ok "overlong-content bounded to $ilen<=8000, ACCEPT"; else no "overlong bounding ($rc, len $ilen)"; fi

echo "== validator still gates model output: out-of-scope files_changed -> REJECT =="
gen glm-response-bad-scope-choices.json
accept && no "bad-scope should REJECT" || ok "bad-scope (out-of-scope) -> validator REJECT"

echo "== validator gates disallowed category: lockfile patch -> REJECT (even when task allows it) =="
python3 -c 'import json,sys; json.dump({"task_id":"lock","objective":"x","allowed_files":["package-lock.json"],"forbidden_files":[],"relevant_snippets":[],"provider_target":{"type":"api_key"}}, open(sys.argv[1],"w"))' "$T/lock-task.json"
gen glm-response-disallowed-category.json "$T/lock-task.json"
if accept "$T/lock-task.json"; then no "disallowed-category should REJECT"; else
  grep -qi 'disallowed' "$T/verr" && ok "disallowed-category [lockfile] -> validator REJECT" || ok "disallowed-category -> REJECT"
fi

echo "== adapter-enforced fields: model cannot override credential_exposure / no_direct_mutation =="
gen glm-response-override-attempt.json
ce="$(field provider_metadata.credential_exposure)"; nm="$(field no_direct_mutation)"
leaked="$(grep -c 'leaked' "$T/r.json" || true)"
if accept && [ "$ce" = "none" ] && [ "$nm" = "True" ] && [ "$leaked" = "0" ]; then
  ok "override-attempt ignored -> credential_exposure=none, no_direct_mutation=True, no 'leaked' in result"; else
  no "override-attempt (ce=$ce nm=$nm leaked=$leaked)"; fi

echo "== json.loads only — no eval/exec on response content in adapter =="
if grep -nE '\beval\(|\bexec\(' "$AD"; then no "eval/exec present in adapter"; else ok "no eval/exec in adapter"; fi

echo "== guards / validator / schemas / smoke-runner byte-unchanged this run =="
ch="$(git diff --name-only .claude/hooks/ WORKER_TASK_SCHEMA.md WORKER_RESULT_SCHEMA.md WORKER_REVIEW_SCHEMA.md dmc-glm-smoke 2>/dev/null)"
[ -z "$ch" ] && ok "hooks/schemas/smoke-runner unchanged" || no "changed: $ch"

echo
echo "==== SUMMARY: PASS=$PASS FAIL=$FAIL ===="
[ "$FAIL" = 0 ] && echo "RESULT: ALL PASS" || echo "RESULT: FAILURES"
