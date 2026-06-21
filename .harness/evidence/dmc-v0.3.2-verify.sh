#!/usr/bin/env bash
# v0.3.2 Manual Import Router Wiring — verification (run: bash .harness/evidence/dmc-v0.3.2-verify.sh).
# MOCK / OFFLINE ONLY. No external provider, no network, no real credential, no .env*. Routing-layer only.
# AC1-AC6 per the approved plan. PROVIDER_CONTRACT C8 routed-vs-direct parity for manual_import + glm/oauth no-regression.
set -u
export PYTHONDONTWRITEBYTECODE=1
ROOT="$(pwd)"; PASS=0; FAIL=0
ok(){ echo "    PASS $1"; PASS=$((PASS+1)); }
no(){ echo "    FAIL $1"; FAIL=$((FAIL+1)); }
PROV="$ROOT/.claude/workers/providers"
ROUTER="$PROV/provider-router.py"
MI_ADAPTER="$PROV/manual-import/manual-import-adapter.py"
MI_FX="$PROV/manual-import/fixtures/import-success.json"
GLM_FX="$PROV/glm-api/fixtures/glm-response-success-choices.json"
OC_FX="$PROV/oauth-cli/fixtures/cli-response-success.json"
SELF="$ROOT/.harness/evidence/dmc-v0.3.2-verify.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
md5(){ command md5 2>/dev/null || md5sum; }
disp(){ python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get(sys.argv[2]))' "$1" "$2"; }
mktask(){ # outfile type provider
  python3 -c 'import json,sys
json.dump({"task_id":"r-"+sys.argv[2],"objective":"x","allowed_files":["src/app.ts"],"forbidden_files":[],"context_summary":"x","relevant_snippets":[],"expected_output_type":"unified_diff","provider_target":{"type":sys.argv[2],"provider":sys.argv[3],"model":"m","execution_mode":"proposal_only","credential_policy":"no_credentials_in_repo","secret_policy":"no_secret_context"}}, open(sys.argv[1],"w"))' "$@"; }

echo "== syntax =="
python3 -c 'import ast,sys; ast.parse(open(sys.argv[1]).read())' "$ROUTER" >/dev/null 2>&1 && ok "router parses" || no "router syntax"

MI="$T/mi.json"; mktask "$MI" manual_import manual-import
GLM="$T/glm.json"; mktask "$GLM" api_key glm-api
OC="$T/oc.json"; mktask "$OC" oauth_cli oauth-cli
MOCKT="$T/mock.json"; mktask "$MOCKT" mock ""
EMPTYT="$T/empty.json"; mktask "$EMPTYT" "" ""

echo "== AC1 routed selection (manual_import) =="
python3 "$ROUTER" --task "$MI" --import "$MI_FX" --print-dispatch >"$T/d1" 2>/dev/null
ad="$(disp "$T/d1" adapter)"; argv="$(disp "$T/d1" argv)"
if [ "${ad##*/}" = "manual-import-adapter.py" ] && printf '%s' "$argv" | grep -q -- '--import' \
   && ! printf '%s' "$argv" | grep -q -- '--mock' && ! printf '%s' "$argv" | grep -q -- '--live'; then
  ok "AC1 manual_import -> manual-import-adapter; argv has --import, no --mock/--live"; else no "AC1 (ad=$ad)"; fi

echo "== AC2 routed-vs-direct --out parity (same task + same fixture; --out JSON only) =="
python3 "$ROUTER" --task "$MI" --import "$MI_FX" --out "$T/routed.json" >/dev/null 2>&1
python3 "$MI_ADAPTER" --task "$MI" --import "$MI_FX" --out "$T/direct.json" >/dev/null 2>&1
cmp -s "$T/routed.json" "$T/direct.json" && ok "AC2 routed --out byte-identical to direct (mock/offline)" || no "AC2 differ"

echo "== AC3 manual_import --live refused (live not supported) =="
python3 "$ROUTER" --task "$MI" --import "$MI_FX" --live >/dev/null 2>"$T/e3"; r3=$?
[ "$r3" != 0 ] && grep -q 'live not supported' "$T/e3" && ok "AC3 --live -> refused with 'live not supported'" || no "AC3 (r3=$r3)"

echo "== AC3b router-side cross-flag refused (provider-router: prefix, exit 1; not the adapter backstop) =="
python3 "$ROUTER" --task "$GLM" --import "$MI_FX" >/dev/null 2>"$T/e4"; r4=$?
python3 "$ROUTER" --task "$MI" --mock "$MI_FX" >/dev/null 2>"$T/e5"; r5=$?
if [ "$r4" = 1 ] && grep -q '^provider-router:' "$T/e4" && grep -q -- '--import is not valid' "$T/e4" \
   && [ "$r5" = 1 ] && grep -q '^provider-router:' "$T/e5" && grep -q -- '--mock is not valid' "$T/e5"; then
  ok "AC3b --import@glm and --mock@manual_import both router-refused pre-exec (exit 1, provider-router:)"; else no "AC3b (r4=$r4 r5=$r5)"; fi

echo "== AC4 no regression: glm/oauth dispatch + parity + ''/mock refuse + live-flag translation =="
ac4=1
# glm + oauth still select their adapters
python3 "$ROUTER" --task "$GLM" --mock "$GLM_FX" --print-dispatch >"$T/dg" 2>/dev/null; [ "$(disp "$T/dg" adapter)" = "$PROV/glm-api/glm-api-adapter.py" ] || ac4=0
python3 "$ROUTER" --task "$OC"  --mock "$OC_FX"  --print-dispatch >"$T/do" 2>/dev/null; [ "$(disp "$T/do" adapter)" = "$PROV/oauth-cli/oauth-cli-adapter.py" ] || ac4=0
# routed-vs-direct parity (mock) for glm + oauth
python3 "$ROUTER" --task "$GLM" --mock "$GLM_FX" --out "$T/gr.json" >/dev/null 2>&1
python3 "$PROV/glm-api/glm-api-adapter.py" --task "$GLM" --mock "$GLM_FX" --out "$T/gd.json" >/dev/null 2>&1
cmp -s "$T/gr.json" "$T/gd.json" || ac4=0
python3 "$ROUTER" --task "$OC" --mock "$OC_FX" --out "$T/or.json" >/dev/null 2>&1
python3 "$PROV/oauth-cli/oauth-cli-adapter.py" --task "$OC" --mock "$OC_FX" --out "$T/od.json" >/dev/null 2>&1
cmp -s "$T/or.json" "$T/od.json" || ac4=0
# ""/mock still refuse
python3 "$ROUTER" --task "$MOCKT" --mock "$MI_FX" >/dev/null 2>&1 && ac4=0
python3 "$ROUTER" --task "$EMPTYT" --mock "$MI_FX" >/dev/null 2>&1 && ac4=0
# live-flag translation: glm forwards --allow-network only; cross --allow-exec refused; oauth forwards --allow-exec only
python3 "$ROUTER" --task "$GLM" --mock "$GLM_FX" --live --allow-network --print-dispatch >"$T/gl" 2>/dev/null \
  && printf '%s' "$(disp "$T/gl" argv)" | grep -q -- '--allow-network' || ac4=0
python3 "$ROUTER" --task "$GLM" --mock "$GLM_FX" --live --allow-exec >/dev/null 2>&1 && ac4=0
python3 "$ROUTER" --task "$OC"  --mock "$OC_FX"  --live --allow-exec --print-dispatch >"$T/ol" 2>/dev/null \
  && printf '%s' "$(disp "$T/ol" argv)" | grep -q -- '--allow-exec' || ac4=0
[ "$ac4" = 1 ] && ok "AC4 glm/oauth dispatch+parity unchanged; ''/mock refuse; live-flag translation intact" || no "AC4 regression"

echo "== AC5 protected surface scoped (only router + ROUTING.md changed; rest byte-unchanged) =="
nochange="$(git -C "$ROOT" diff --name-only -- \
  .claude/workers/providers/manual-import .claude/workers/providers/glm-api .claude/workers/providers/oauth-cli \
  .claude/hooks WORKER_TASK_SCHEMA.md WORKER_RESULT_SCHEMA.md WORKER_REVIEW_SCHEMA.md \
  .claude/workers/providers/PROVIDER_CONTRACT.md dmc-glm-smoke)"
changed="$(git -C "$ROOT" diff --name-only -- .claude/workers/providers/provider-router.py .claude/workers/providers/ROUTING.md | sort | tr '\n' ' ')"
if [ -z "$nochange" ] && [ "$changed" = ".claude/workers/providers/ROUTING.md .claude/workers/providers/provider-router.py " ]; then
  ok "AC5 only provider-router.py + ROUTING.md changed; adapters/schemas/hooks/contract/smoke byte-unchanged"; else no "AC5 (nochange='$nochange' changed='$changed')"; fi

echo "== AC6 router self-audit (no new network/exec/secret surface) =="
SHT="shell""=True"; NETN="url""lib"; REQN="requ""ests"; SOCKN="sock""et"
if grep -q 'shell=False' "$ROUTER" && ! grep -qE -- "$SHT|$NETN|$REQN|$SOCKN" "$ROUTER" \
   && grep -q 'subprocess.run(argv, shell=False)' "$ROUTER"; then
  ok "AC6 dispatch shell=False; no network lib; no shell=True; execs only a registered adapter"; else no "AC6"; fi

echo
echo "==== SUMMARY: PASS=$PASS FAIL=$FAIL ===="
[ "$FAIL" = 0 ] && echo "RESULT: ALL PASS" || echo "RESULT: FAILURES"
[ "$FAIL" = 0 ]; exit $?
