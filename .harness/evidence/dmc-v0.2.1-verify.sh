#!/usr/bin/env bash
# v0.2.1 glm-api adapter verification (run: bash .harness/evidence/dmc-v0.2.1-verify.sh). NO live call.
set -u
ROOT="$(pwd)"; PASS=0; FAIL=0
ok(){ echo "  PASS $1"; PASS=$((PASS+1)); }
no(){ echo "  FAIL $1"; FAIL=$((FAIL+1)); }
AD="$ROOT/.claude/workers/providers/glm-api/glm-api-adapter.py"
FX="$ROOT/.claude/workers/providers/glm-api/fixtures"
VAL="$ROOT/.claude/hooks/worker-result-check.py"
TASK="$ROOT/.harness/workers/tasks/mock-001.json"
T="$(mktemp -d)"

echo "== syntax =="
python3 -m py_compile "$AD" && ok "py_compile adapter" || no "py_compile adapter"

echo "== mock mode maps to WORKER_RESULT_SCHEMA and validates ACCEPT (no network) =="
python3 "$AD" --task "$TASK" --mock "$FX/glm-response-mock.json" --out "$T/r.json" >/dev/null 2>&1 && ok "adapter --mock produced result" || no "adapter --mock"
python3 "$VAL" "$TASK" "$T/r.json" >/dev/null 2>&1 && ok "mock result -> worker-result-check ACCEPT" || no "mock result ACCEPT"

echo "== missing key: --live without GLM_API_KEY -> clear non-printing error, no network =="
env -u GLM_API_KEY python3 "$AD" --task "$TASK" --live --allow-network >"$T/o1" 2>"$T/e1"; rc=$?
[ "$rc" != 0 ] && grep -qi 'GLM_API_KEY' "$T/e1" && ok "missing-key error (exit $rc)" || no "missing-key error"
grep -qiE 'sk-|AKIA|FAKE' "$T/e1" "$T/o1" && no "secret-like text in missing-key output" || ok "no secret printed on missing key"

echo "== live gating: missing --allow-network and CI-detected both refuse (no network) =="
python3 "$AD" --task "$TASK" --live >/dev/null 2>"$T/e2"; [ "$?" != 0 ] && grep -qi 'allow-network' "$T/e2" && ok "--live without --allow-network refused" || no "--allow-network gate"
CI=1 GLM_API_KEY=FAKE-do-not-use python3 "$AD" --task "$TASK" --live --allow-network >/dev/null 2>"$T/e3"; [ "$?" != 0 ] && grep -qi 'CI' "$T/e3" && ok "CI-detected live blocked (defense-in-depth)" || no "CI gate"
grep -q 'FAKE-do-not-use' "$T/e3" && no "fake key echoed in CI-block msg" || ok "fake key not echoed (CI block)"

echo "== fake key never echoed in mock mode =="
GLM_API_KEY=FAKE-do-not-use python3 "$AD" --task "$TASK" --mock "$FX/glm-response-mock.json" --out "$T/r2.json" >"$T/o4" 2>&1
grep -rq 'FAKE-do-not-use' "$T/o4" "$T/r2.json" && no "fake key leaked" || ok "fake key never echoed/serialized"

echo "== secret-bearing path cannot enter payload (context-guard fail-closed) =="
cat > "$T/secrettask.json" <<'JSON'
{"task_id":"sec","objective":"x","allowed_files":["src/a.ts","/x/.env.local"],"relevant_snippets":[],"provider_target":{"type":"api_key"}}
JSON
python3 "$AD" --task "$T/secrettask.json" --mock "$FX/glm-response-mock.json" >/dev/null 2>"$T/e5"; [ "$?" != 0 ] && grep -qi 'context-guard' "$T/e5" && ok "secret path -> context-guard fail-closed (no payload)" || no "secret path not blocked"

echo "== adversarial responses rejected at import =="
python3 "$AD" --task "$TASK" --mock "$FX/glm-response-bad-scope.json" --out "$T/bs.json" >/dev/null 2>&1
python3 "$VAL" "$TASK" "$T/bs.json" >/dev/null 2>&1 && no "out-of-scope should REJECT" || ok "out-of-scope result -> REJECT"
python3 "$AD" --task "$TASK" --mock "$FX/glm-response-bad-secret.json" --out "$T/bsec.json" >/dev/null 2>&1
python3 "$VAL" "$TASK" "$T/bsec.json" >/dev/null 2>&1 && no "inline-secret should REJECT" || ok "inline-secret result -> REJECT"

echo "== no repo mutation during adapter run (tracked product files unchanged) =="
[ -z "$(git status --porcelain .claude/hooks WORKER_TASK_SCHEMA.md WORKER_RESULT_SCHEMA.md)" ] && ok "no mutation of guards/schemas" || no "mutation detected"

echo "== no git apply INVOCATION in adapter script; README only forbids =="
if grep -rnE 'git[[:space:]]+apply|(^|[^a-z])patch[[:space:]]+-' .claude/workers/providers/glm-api/*.py 2>/dev/null; then no "git apply invoked in adapter"; else ok "no git apply invoked in adapter"; fi
if grep -rn 'git apply' .claude/workers/providers/glm-api/*.md 2>/dev/null | grep -viE 'never|forbidden|not '; then no "git apply in docs outside forbidding context"; else ok "docs mention git apply only to forbid"; fi

echo "== no REAL credential VALUE in committed adapter code (test harnesses/fixtures carry fakes by design) =="
# Scope to committed adapter + worker code; exclude verify harnesses + fixtures + known fake tokens.
hits="$(grep -rnE 'GLM_API_KEY[[:space:]]*=[[:space:]]*[A-Za-z0-9]|sk-[A-Za-z0-9]{8,}|AKIA[0-9A-Z]{16}' .claude/workers .claude/hooks 2>/dev/null | grep -viE 'FAKE-do-not-use|AKIAABCDEFGHIJKLMNOP|sk-abcdef|/fixtures/|verify\.sh')"
[ -z "$hits" ] && ok "no real credential values in adapter/worker code" || { echo "$hits"; no "credential value found"; }

echo "== existing guards/validator/schemas byte-unchanged this run =="
ch="$(git diff --name-only .claude/hooks/pre-tool-guard.sh .claude/hooks/scope-guard.sh .claude/hooks/stop-verify-gate.sh .claude/hooks/evidence-log.sh .claude/hooks/secret-guard.sh .claude/hooks/worker-context-guard.sh .claude/hooks/worker-result-check.py .claude/hooks/lib/secret-paths.sh WORKER_TASK_SCHEMA.md WORKER_RESULT_SCHEMA.md WORKER_REVIEW_SCHEMA.md)"
[ -z "$ch" ] && ok "guards/validator/schemas unchanged" || no "changed: $ch"

echo "== installer wires glm-api + provider ignore =="
H2="$(mktemp -d)"; .claude/install/dmc-install.sh "$H2" >/dev/null 2>&1
[ -f "$H2/.claude/workers/providers/glm-api/glm-api-adapter.py" ] && ok "adapter installed" || no "adapter install"
grep -q '.harness/workers/providers/' "$H2/.gitignore" && ok "provider runtime gitignored in host" || no "provider ignore"
rm -rf "$H2"
rm -rf "$T"

echo
echo "==== SUMMARY: PASS=$PASS FAIL=$FAIL ===="
[ "$FAIL" = 0 ] && echo "RESULT: ALL PASS" || echo "RESULT: FAILURES"
