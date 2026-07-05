#!/usr/bin/env bash
# v0.2.2 oauth-cli adapter verification (run: bash .harness/evidence/dmc-v0.2.2-verify.sh).
# MOCK-ONLY + LOCAL-STUB-ONLY. No external provider, no real OAuth credential, no network.
set -u
ROOT="$(pwd)"; PASS=0; FAIL=0
ok(){ echo "  PASS $1"; PASS=$((PASS+1)); }
no(){ echo "  FAIL $1"; FAIL=$((FAIL+1)); }
AD="$ROOT/.claude/workers/providers/oauth-cli/oauth-cli-adapter.py"
FX="$ROOT/.claude/workers/providers/oauth-cli/fixtures"
STUB="$ROOT/.claude/workers/providers/oauth-cli/fixtures/fake-cli/fake-cli.py"
VAL="$ROOT/.claude/hooks/worker-result-check.py"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export DMC_RJSON="$T/r.json"
# unset any CI markers so the local-stub exec path (gated not-CI) can run
NOCI="env -u CI -u GITHUB_ACTIONS -u GITLAB_CI -u BUILDKITE -u JENKINS_URL"

# toy task (clean, in-scope)
python3 -c 'import json,sys; json.dump({"task_id":"oauth-001","objective":"Add Pikachu to src/setNames.ts.","allowed_files":["src/setNames.ts"],"forbidden_files":["src/secrets.ts",".env.local","pnpm-lock.yaml"],"context_summary":"append one name","relevant_snippets":[],"expected_output_type":"unified_diff","provider_target":{"type":"oauth_cli","provider":"oauth-cli","model":"oauth-cli-model","execution_mode":"proposal_only","credential_policy":"no_credentials_in_repo","secret_policy":"no_secret_context"}}, open(sys.argv[1],"w"))' "$T/task.json"
TASK="$T/task.json"
field(){ DMC_FP="$1" python3 -c 'import json,os; r=json.load(open(os.environ["DMC_RJSON"]));
v=r
for k in os.environ["DMC_FP"].split("."):
    v=v.get(k) if isinstance(v,dict) else None
print(v)'; }
mock(){ python3 "$AD" --task "$TASK" --mock "$FX/$1" --out "$T/r.json" >/dev/null 2>"$T/err"; }
accept(){ python3 "$VAL" "$TASK" "$T/r.json" >/dev/null 2>&1; }

echo "== syntax =="
python3 -m py_compile "$AD" && ok "py_compile adapter" || no "py_compile adapter"
python3 -m py_compile "$STUB" && ok "py_compile fake-cli stub" || no "py_compile stub"

echo "== mock: choices-less CLI stdout (bare JSON) -> populated, ACCEPT (C2 envelope) =="
mock cli-response-success.json
if accept && [ "$(field files_changed)" = "['src/setNames.ts']" ] && [ -n "$(field summary)" ] && [ "$(field proposed_patch)" != "" ]; then
  ok "success stdout normalized + ACCEPT"; else no "success stdout"; fi

echo "== mock: fenced/prose stdout extracted; plain-text/empty fall back safely =="
mock cli-response-fenced.json
accept && [ "$(field files_changed)" = "['src/setNames.ts']" ] && ok "fenced stdout extracted + ACCEPT" || no "fenced"
mock cli-response-plain-text.json
accept && [ "$(field files_changed)" = "[]" ] && [ "$(field confidence)" = "low" ] && [ -n "$(field instructions)" ] && ok "plain-text -> instructions fallback + ACCEPT" || no "plain-text"
mock cli-response-empty.json; rc=$?
[ "$rc" = 0 ] && accept && [ "$(field files_changed)" = "[]" ] && ok "empty stdout -> valid, no AttributeError (C2)" || no "empty stdout ($rc)"

echo "== mock: adversarial out-of-scope stdout -> validator REJECT =="
mock cli-response-bad-scope.json
accept && no "bad-scope should REJECT" || ok "bad-scope (out-of-scope) -> validator REJECT"

echo "== C1: token in stdout / stderr (SECRET_VALUE-missed) -> redact-and-reject, no token persisted =="
mock cli-response-token-leak.json; rc=$?
if [ "$rc" != 0 ] && grep -qi 'token-like material' "$T/err" && [ ! -s "$T/r.json" -o -z "$(grep -l eyJ "$T/r.json" 2>/dev/null)" ]; then
  ok "stdout token -> redact-and-reject (no result persisted)"; else no "stdout token-leak ($rc)"; fi
: > "$T/r.json"
mock cli-response-stderr-token-leak.json; rc=$?
[ "$rc" != 0 ] && grep -qi 'token-like material' "$T/err" && ok "stderr token -> redact-and-reject" || no "stderr token-leak ($rc)"

echo "== adapter-stamped fields: CLI cannot override credential_exposure / no_direct_mutation =="
mock cli-response-override-attempt.json
ce="$(field provider_metadata.credential_exposure)"; nm="$(field no_direct_mutation)"; leaked="$(grep -c leaked "$T/r.json" 2>/dev/null || true)"
if accept && [ "$ce" = "none" ] && [ "$nm" = "True" ] && [ "$leaked" = "0" ]; then
  ok "override-attempt ignored -> none/True, no 'leaked' in result"; else no "override (ce=$ce nm=$nm leaked=$leaked)"; fi

echo "== C1 token-detector unit test: guard strictly stronger than SECRET_VALUE =="
python3 - <<'PY' && ok "token-guard matches all OAuth shapes SECRET_VALUE misses" || no "token-guard coverage"
import importlib.util, os
spec = importlib.util.spec_from_file_location("ad", os.path.join(os.getcwd(), ".claude/workers/providers/oauth-cli/oauth-cli-adapter.py"))
ad = importlib.util.module_from_spec(spec); spec.loader.exec_module(ad)
samples = ["eyJabc.def.ghi", "Authorization: Bearer eyJa.b.c", "authorization: tok_live_abcdef",
           "access_token=ya29.AbCdEf", '"refresh_token": "1//0eXyZ"', "id_token = eyJr.payload.sig",
           "gho_"+"A"*30, "ghu_"+"B"*22, "ghs_"+"C"*25, "ya29.AbCdEf_123"]
assert all(ad.find_token_material(s) for s in samples), "missed a token shape"
# placeholders excluded; clean code not flagged
assert not ad.find_token_material('{"access_token": "<redacted>"}'), "placeholder should be excluded"
assert not ad.find_token_material('--- a/src/setNames.ts\n+++ b/src/setNames.ts'), "clean diff flagged"
PY

echo "== C3: fake-CLI stub exercises the REAL exec wrapper offline (no provider) =="
run_stub(){ $NOCI DMC_OAUTHCLI_BIN="$STUB" DMC_FAKECLI_MODE="$1" DMC_OAUTHCLI_TIMEOUT_SECONDS="${2:-30}" \
  python3 "$AD" --task "$TASK" --live --allow-exec --out "$T/r.json" >/dev/null 2>"$T/serr"; }
run_stub success;  rc=$?; [ "$rc" = 0 ] && accept && [ "$(field files_changed)" = "['src/setNames.ts']" ] && ok "stub success -> normalized + ACCEPT" || no "stub success ($rc)"
run_stub fenced;   rc=$?; [ "$rc" = 0 ] && accept && ok "stub fenced -> extracted + ACCEPT" || no "stub fenced ($rc)"
run_stub nonzero-exit; rc=$?; [ "$rc" != 0 ] && grep -qi 'non-zero' "$T/serr" && ok "stub nonzero-exit -> fail-closed" || no "stub nonzero-exit ($rc)"
run_stub timeout 2; rc=$?; [ "$rc" != 0 ] && grep -qi 'timeout' "$T/serr" && ok "stub timeout -> killed + fail-closed" || no "stub timeout ($rc)"
run_stub stdout-token; rc=$?; [ "$rc" != 0 ] && grep -qi 'token-like material' "$T/serr" && ok "stub stdout-token -> redact-and-reject" || no "stub stdout-token ($rc)"
run_stub stderr-token; rc=$?; [ "$rc" != 0 ] && grep -qi 'token-like material' "$T/serr" && ok "stub stderr-token -> redact-and-reject" || no "stub stderr-token ($rc)"
run_stub auth-unauthenticated; rc=$?; [ "$rc" != 0 ] && grep -qi 'not authenticated' "$T/serr" && ok "stub unauthenticated -> fail-closed BEFORE run" || no "stub unauthenticated ($rc)"

echo "== C4: binary-resolution negatives refused =="
neg(){ $NOCI DMC_OAUTHCLI_BIN="$2" python3 "$AD" --task "$TASK" --live --allow-exec >/dev/null 2>"$T/nerr"; rc=$?
  [ "$rc" != 0 ] && grep -qiE 'refusing|absolute|symlink|executable|regular|metacharacter' "$T/nerr" && ok "binary refused: $1" || no "binary not refused: $1 ($rc)"; }
neg "relative path" "fixtures/fake-cli/fake-cli.py"
neg "non-existent" "/nonexistent/dmc-oauth-cli-xyz"
neg "shell metachar" "/tmp/foo;rm -rf x"
ln -s "$STUB" "$T/link-to-stub"; neg "symlink" "$T/link-to-stub"
neg "directory" "$(dirname "$STUB")"
printf '#x\n' > "$T/nonexec"; neg "non-executable" "$T/nonexec"

echo "== exec-guard: mock mode never execs the configured CLI =="
TRIP="$T/tripwire.sh"; printf '#!/bin/sh\ntouch "%s"\n' "$T/TRIPPED" > "$TRIP"; chmod +x "$TRIP"
DMC_OAUTHCLI_BIN="$TRIP" python3 "$AD" --task "$TASK" --mock "$FX/cli-response-success.json" --out "$T/r.json" >/dev/null 2>&1
[ ! -f "$T/TRIPPED" ] && ok "mock mode spawned NO configured-CLI subprocess" || no "mock mode execed the CLI"

echo "== context-guard fail-closed on secret-bearing task (.env* in allowed_files) =="
python3 -c 'import json,sys; json.dump({"task_id":"sec","objective":"x","allowed_files":["src/a.ts","/x/.env.local"],"forbidden_files":[],"relevant_snippets":[],"provider_target":{"type":"oauth_cli"}}, open(sys.argv[1],"w"))' "$T/sectask.json"
python3 "$AD" --task "$T/sectask.json" --mock "$FX/cli-response-success.json" >/dev/null 2>"$T/cerr"; rc=$?
[ "$rc" != 0 ] && grep -qi 'context-guard' "$T/cerr" && ok "secret task -> context-guard fail-closed" || no "context-guard not fail-closed ($rc)"

echo "== no shell=True / no git apply in adapter =="
grep -nE 'shell=True|git[[:space:]]+apply' "$AD" && no "shell=True/git apply present" || ok "no shell=True / no git apply"

echo "== protected files byte-unchanged this run =="
ch="$(git diff --name-only .claude/hooks/ WORKER_TASK_SCHEMA.md WORKER_RESULT_SCHEMA.md WORKER_REVIEW_SCHEMA.md dmc-glm-smoke .claude/workers/providers/glm-api/)"
[ -z "$ch" ] && ok "hooks/schemas/glm-api/smoke-runner unchanged" || no "changed: $ch"

echo
echo "==== SUMMARY: PASS=$PASS FAIL=$FAIL ===="
[ "$FAIL" = 0 ] && echo "RESULT: ALL PASS" || echo "RESULT: FAILURES"
