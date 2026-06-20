#!/usr/bin/env bash
# v0.2.3 provider-router verification (run: bash .harness/evidence/dmc-v0.2.3-verify.sh).
# MOCK-ONLY + LOCAL-STUB-ONLY. No external provider, no real OAuth credential, no network.
set -u
ROOT="$(pwd)"; PASS=0; FAIL=0
ok(){ echo "  PASS $1"; PASS=$((PASS+1)); }
no(){ echo "  FAIL $1"; FAIL=$((FAIL+1)); }
R="$ROOT/.claude/workers/providers/provider-router.py"
GLM="$ROOT/.claude/workers/providers/glm-api/glm-api-adapter.py"
GLM_FX="$ROOT/.claude/workers/providers/glm-api/fixtures/glm-response-mock.json"
OAUTH_FX="$ROOT/.claude/workers/providers/oauth-cli/fixtures/cli-response-success.json"
STUB="$ROOT/.claude/workers/providers/oauth-cli/fixtures/fake-cli/fake-cli.py"
VAL="$ROOT/.claude/hooks/worker-result-check.py"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
NOCI="env -u CI -u GITHUB_ACTIONS -u GITLAB_CI -u BUILDKITE -u JENKINS_URL"

mktask(){ # $1 type  $2 provider  $3 outfile
  python3 -c 'import json,sys
t=sys.argv[2]; p=sys.argv[3]
pt={"type":t,"provider":p,"model":"m","execution_mode":"proposal_only","credential_policy":"no_credentials_in_repo","secret_policy":"no_secret_context"} if t else {}
json.dump({"task_id":"route-"+(t or "none"),"objective":"Add Pikachu to src/setNames.ts.","allowed_files":["src/setNames.ts"],"forbidden_files":["src/secrets.ts"],"context_summary":"x","relevant_snippets":[],"expected_output_type":"unified_diff","provider_target":pt}, open(sys.argv[1],"w"))' "$1" "$2" "$3"; }
mktask "$T/glm.json"   api_key   glm-api
mktask "$T/oauth.json" oauth_cli oauth-cli
mktask "$T/mock.json"  mock      ""
mktask "$T/unk.json"   api_key   nope
mktask "$T/empty.json" api_key   ""        # empty provider, single-adapter type -> routes
python3 -c 'import json,sys; json.dump({"task_id":"noPT","objective":"x","allowed_files":[],"relevant_snippets":[]}, open(sys.argv[1],"w"))' "$T/nopt.json"
accept(){ python3 "$VAL" "$1" "$2" >/dev/null 2>&1; }

echo "== syntax =="
python3 -m py_compile "$R" && ok "py_compile router" || no "py_compile router"

echo "== V1: route api_key/glm-api --mock -> glm adapter, ACCEPT =="
python3 "$R" --task "$T/glm.json" --mock "$GLM_FX" --out "$T/v1.json" >/dev/null 2>"$T/e"; rc=$?
[ "$rc" = 0 ] && accept "$T/glm.json" "$T/v1.json" && ok "V1 routed to glm-api + ACCEPT" || no "V1 ($rc)"

echo "== V2: route oauth_cli/oauth-cli --mock -> oauth adapter, ACCEPT =="
python3 "$R" --task "$T/oauth.json" --mock "$OAUTH_FX" --out "$T/v2.json" >/dev/null 2>"$T/e"; rc=$?
[ "$rc" = 0 ] && accept "$T/oauth.json" "$T/v2.json" && ok "V2 routed to oauth-cli + ACCEPT" || no "V2 ($rc)"

echo "== V3: routed --out file byte-identical to direct glm-api --out (mock) =="
python3 "$R"   --task "$T/glm.json" --mock "$GLM_FX" --out "$T/via-router.json" >/dev/null 2>&1
python3 "$GLM" --task "$T/glm.json" --mock "$GLM_FX" --out "$T/direct.json"     >/dev/null 2>&1
cmp -s "$T/via-router.json" "$T/direct.json" && ok "V3 routed --out == direct --out (byte-identical)" || no "V3 differ"

echo "== V4: unknown (type,provider) -> refuse, no adapter exec =="
python3 "$R" --task "$T/unk.json" --mock "$GLM_FX" --out "$T/v4.json" >/dev/null 2>"$T/e"; rc=$?
[ "$rc" != 0 ] && [ ! -f "$T/v4.json" ] && grep -qi 'no adapter registered' "$T/e" && ok "V4 unknown -> refuse" || no "V4 ($rc)"

echo "== V5: mock / missing provider_target -> refuse =="
python3 "$R" --task "$T/mock.json" --mock "$GLM_FX" >/dev/null 2>"$T/e"; rc=$?; [ "$rc" != 0 ] && grep -qi 'no live adapter' "$T/e" && ok "V5 mock type -> refuse" || no "V5 mock ($rc)"
python3 "$R" --task "$T/nopt.json" --mock "$GLM_FX" >/dev/null 2>"$T/e"; rc=$?; [ "$rc" != 0 ] && grep -qi 'no provider_target' "$T/e" && ok "V5 missing provider_target -> refuse" || no "V5 nopt ($rc)"

echo "== V6: empty provider, single-adapter type -> routes deterministically =="
python3 "$R" --task "$T/empty.json" --mock "$GLM_FX" --out "$T/v6.json" >/dev/null 2>"$T/e"; rc=$?
[ "$rc" = 0 ] && accept "$T/empty.json" "$T/v6.json" && ok "V6 empty-provider api_key -> glm-api (1 adapter)" || no "V6 ($rc)"
# (ambiguity-refuse branch: no type currently has >1 adapter; covered by code review of select_entry.)

echo "== V7: route selection independent of env (bogus env does not change selection) =="
sel(){ $NOCI GLM_API_KEY=bogus DMC_OAUTHCLI_BIN=/bogus FOO=bar python3 "$R" --task "$1" --mock x --print-dispatch 2>/dev/null | python3 -c 'import json,sys;print(json.load(sys.stdin)["adapter"])'; }
a1="$(sel "$T/glm.json")"; a2="$(sel "$T/oauth.json")"
[ "${a1##*/}" = "glm-api-adapter.py" ] && [ "${a2##*/}" = "oauth-cli-adapter.py" ] && ok "V7 selection unchanged under bogus env" || no "V7 (a1=$a1 a2=$a2)"

echo "== V8: live-flag translation (print-dispatch, NO live call) =="
disp(){ python3 "$R" --task "$1" --live "$2" --print-dispatch 2>"$T/e"; }
g="$(disp "$T/glm.json" --allow-network)"; echo "$g" | grep -q -- '--allow-network' && ! echo "$g" | grep -q -- '--allow-exec' && ok "V8 glm-api forwards --allow-network only" || no "V8 glm"
o="$(disp "$T/oauth.json" --allow-exec)"; echo "$o" | grep -q -- '--allow-exec' && ! echo "$o" | grep -q -- '--allow-network' && ok "V8 oauth-cli forwards --allow-exec only" || no "V8 oauth"
python3 "$R" --task "$T/glm.json" --live --allow-exec --print-dispatch >/dev/null 2>"$T/e"; rc=$?
[ "$rc" != 0 ] && grep -qi 'mismatched opt-in' "$T/e" && ok "V8 cross-flag (glm + --allow-exec) refused before dispatch" || no "V8 cross ($rc)"

echo "== V8b: adapter-layer cross-flag backstop (direct, no live) =="
python3 "$GLM" --task "$T/glm.json" --mock "$GLM_FX" --allow-exec >/dev/null 2>"$T/e"; rc=$?
[ "$rc" != 0 ] && grep -qi 'unrecognized arguments' "$T/e" && ok "V8b glm-api argparse rejects --allow-exec" || no "V8b ($rc)"

echo "== V14: env passthrough router->adapter (offline stub; nonzero-mode must reach stub) =="
# If the router stripped env, DMC_FAKECLI_MODE would not reach the adapter->stub and the stub would default to success.
$NOCI DMC_OAUTHCLI_BIN="$STUB" DMC_FAKECLI_MODE=nonzero-exit python3 "$R" --task "$T/oauth.json" --live --allow-exec >/dev/null 2>"$T/e"; rc=$?
[ "$rc" != 0 ] && grep -qi 'non-zero' "$T/e" && ok "V14 env passthrough: parent DMC_FAKECLI_MODE reached child (nonzero->fail-closed)" || no "V14 passthrough ($rc)"
$NOCI DMC_OAUTHCLI_BIN="$STUB" DMC_FAKECLI_MODE=success python3 "$R" --task "$T/oauth.json" --live --allow-exec --out "$T/v14.json" >/dev/null 2>"$T/e"; rc=$?
[ "$rc" = 0 ] && accept "$T/oauth.json" "$T/v14.json" && ok "V14 positive control: success mode -> ACCEPT" || no "V14 positive ($rc)"

echo "== V10/O4: argv hygiene + no shell=True/git apply =="
disp_glm="$(python3 "$R" --task "$T/glm.json" --mock "$GLM_FX" --out "$T/x.json" --print-dispatch 2>/dev/null)"
# child argv must contain only paths + flags; assert no task content (objective text) leaked onto argv
echo "$disp_glm" | grep -q 'Add Pikachu' && no "V10 task-derived string on argv" || ok "V10 no task-derived string on child argv"
grep -nE 'shell=True|git[[:space:]]+apply' "$R" && no "shell=True/git apply in router" || ok "V10 no shell=True / no git apply"

echo "== V11: no repo mutation during routed mock run =="
[ -z "$(git status --porcelain .claude/workers/providers/glm-api .claude/workers/providers/oauth-cli .claude/hooks)" ] && ok "V11 no mutation of adapters/hooks" || no "V11 mutation"

echo "== V15/O2: router persists no raw stream file (writes only adapter --out) =="
# router itself writes nothing; only the adapter wrote $T/v1.json etc. Assert router has no open(...,'w') for streams.
grep -nE "open\(.*['\"]w['\"]" "$R" && no "V15 router writes a file" || ok "V15 router persists no stream/result file"

echo "== V12: protected files byte-unchanged this run =="
ch="$(git diff --name-only .claude/hooks/ WORKER_TASK_SCHEMA.md WORKER_RESULT_SCHEMA.md WORKER_REVIEW_SCHEMA.md dmc-glm-smoke .claude/workers/providers/glm-api/ .claude/workers/providers/oauth-cli/)"
[ -z "$ch" ] && ok "V12 adapters/hooks/schemas/smoke-runner unchanged" || no "V12 changed: $ch"

echo
echo "==== SUMMARY: PASS=$PASS FAIL=$FAIL ===="
[ "$FAIL" = 0 ] && echo "RESULT: ALL PASS" || echo "RESULT: FAILURES"
