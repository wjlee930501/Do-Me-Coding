#!/usr/bin/env bash
# v0.2 Worker Bridge verification harness (run: bash .harness/evidence/dmc-v0.2-verify.sh)
set -u
ROOT="$(pwd)"; PASS=0; FAIL=0
ok(){ echo "  PASS $1"; PASS=$((PASS+1)); }
no(){ echo "  FAIL $1"; FAIL=$((FAIL+1)); }
VAL="$ROOT/.claude/hooks/worker-result-check.py"
CTX="$ROOT/.claude/hooks/worker-context-guard.sh"

echo "== syntax =="
for f in .claude/hooks/worker-context-guard.sh; do bash -n "$f" && ok "bash -n $(basename "$f")" || no "bash -n $f"; done
python3 -m py_compile "$VAL" && ok "py_compile worker-result-check.py" || no "py_compile"

echo "== drift: is_secret_path identical in secret-guard.sh and lib/secret-paths.sh =="
A="$(awk '/^is_secret_path\(\)/,/^}/' .claude/hooks/secret-guard.sh | md5)"
B="$(awk '/^is_secret_path\(\)/,/^}/' .claude/hooks/lib/secret-paths.sh | md5)"
[ "$A" = "$B" ] && ok "secret detector md5-identical (no drift)" || no "secret detector DRIFT ($A vs $B)"

echo "== schemas present =="
for s in WORKER_TASK_SCHEMA.md WORKER_RESULT_SCHEMA.md WORKER_REVIEW_SCHEMA.md; do [ -f "$s" ] && ok "schema $s" || no "schema $s"; done

echo "== context-guard: clean mock task passes; secret-bearing task fails closed =="
$CTX .harness/workers/tasks/mock-001.json >/dev/null 2>&1 && ok "context-guard clean task -> pass" || no "context-guard clean task"
T="$(mktemp -d)"; cat > "$T/bad.json" <<'JSON'
{"task_id":"bad","objective":"x","allowed_files":["src/a.ts","/x/.env.local"],"relevant_snippets":[]}
JSON
$CTX "$T/bad.json" >/dev/null 2>&1 && no "context-guard should FAIL on .env.local" || ok "context-guard .env.local -> FAIL-CLOSED"
cat > "$T/badinline.json" <<'JSON'
{"task_id":"bad2","objective":"x","allowed_files":["src/a.ts"],"relevant_snippets":[{"file":"src/a.ts","text":"const k='sk-abcdef1234567890'"}]}
JSON
$CTX "$T/badinline.json" >/dev/null 2>&1 && no "context-guard should FAIL on inline secret" || ok "context-guard inline secret -> FAIL-CLOSED"
rm -rf "$T"

echo "== result validator: clean mock-001 ACCEPT; adversarial -> REJECT =="
TASK=.harness/workers/tasks/mock-001.json
python3 "$VAL" "$TASK" .harness/workers/results/mock-001.json >/dev/null 2>&1 && ok "mock-001 result -> ACCEPT" || no "mock-001 ACCEPT"
T="$(mktemp -d)"
# out-of-scope
cat > "$T/scope.json" <<'JSON'
{"task_id":"mock-001","summary":"x","files_considered":["src/other.ts"],"files_changed":["src/other.ts"],"proposed_patch":"--- a/src/other.ts\n+++ b/src/other.ts\n@@ -1 +1 @@\n-a\n+b\n","no_direct_mutation":true,"provider_metadata":{"credential_exposure":"none"}}
JSON
python3 "$VAL" "$TASK" "$T/scope.json" >/dev/null 2>&1 && no "out-of-scope should REJECT" || ok "out-of-scope diff -> REJECT"
# disallowed lockfile
cat > "$T/lock.json" <<'JSON'
{"task_id":"mock-001","summary":"x","files_considered":["pnpm-lock.yaml"],"files_changed":["pnpm-lock.yaml"],"proposed_patch":"--- a/pnpm-lock.yaml\n+++ b/pnpm-lock.yaml\n@@ -1 +1 @@\n-a\n+b\n","no_direct_mutation":true,"provider_metadata":{"credential_exposure":"none"}}
JSON
python3 "$VAL" "$TASK" "$T/lock.json" >/dev/null 2>&1 && no "lockfile should REJECT" || ok "disallowed lockfile -> REJECT"
# files_changed != diff
cat > "$T/mismatch.json" <<'JSON'
{"task_id":"mock-001","summary":"x","files_considered":["src/setNames.ts"],"files_changed":["src/setNames.ts"],"proposed_patch":"--- a/src/setNames.ts\n+++ b/src/setNames.ts\n@@ -1 +1 @@\n-a\n+b\n--- a/src/extra.ts\n+++ b/src/extra.ts\n@@ -1 +1 @@\n-a\n+b\n","no_direct_mutation":true,"provider_metadata":{"credential_exposure":"none"}}
JSON
python3 "$VAL" "$TASK" "$T/mismatch.json" >/dev/null 2>&1 && no "mismatch should REJECT" || ok "files_changed!=diff -> REJECT"
# no_direct_mutation false
cat > "$T/mut.json" <<'JSON'
{"task_id":"mock-001","summary":"x","files_changed":["src/setNames.ts"],"proposed_patch":"--- a/src/setNames.ts\n+++ b/src/setNames.ts\n@@ -1 +1 @@\n-a\n+b\n","no_direct_mutation":false,"provider_metadata":{"credential_exposure":"none"}}
JSON
python3 "$VAL" "$TASK" "$T/mut.json" >/dev/null 2>&1 && no "no_direct_mutation=false should REJECT" || ok "no_direct_mutation=false -> REJECT"
# inline secret in result
cat > "$T/sec.json" <<'JSON'
{"task_id":"mock-001","summary":"AKIAABCDEFGHIJKLMNOP","files_changed":["src/setNames.ts"],"proposed_patch":"--- a/src/setNames.ts\n+++ b/src/setNames.ts\n@@ -1 +1 @@\n-a\n+b\n","no_direct_mutation":true,"provider_metadata":{"credential_exposure":"none"}}
JSON
python3 "$VAL" "$TASK" "$T/sec.json" >/dev/null 2>&1 && no "inline secret should REJECT" || ok "inline secret in result -> REJECT"
rm -rf "$T"

echo "== reject-without-mutation: validation changed no tracked files =="
[ -z "$(git status --porcelain .claude/hooks/secret-guard.sh)" ] && ok "validation mutated no guard" || no "guard changed"

echo "== no git apply/patch INVOCATION in worker scripts; skills only forbid it =="
if grep -rnE 'git[[:space:]]+apply|(^|[^a-z])patch[[:space:]]+-' .claude/hooks/worker-* 2>/dev/null; then no "git apply invoked in worker scripts"; else ok "no git apply in worker scripts"; fi
if grep -rn 'git apply' .claude/skills/dmc-worker* 2>/dev/null | grep -viE 'never|forbidden|not appl|importing never'; then no "git apply in skills outside forbidding context"; else ok "skills mention git apply only to forbid it"; fi

echo "== no credentials / live API in worker code =="
if grep -rniE 'api[_-]?key|GLM_.*KEY|https?://|oauth.*token|bearer ' .claude/skills/dmc-worker* .claude/hooks/worker-* 2>/dev/null | grep -v 'no_credentials\|no live\|never'; then no "credential/API ref found"; else ok "no credentials / live API"; fi

echo "== existing guards byte-unchanged this run =="
ch="$(git diff --name-only .claude/hooks/pre-tool-guard.sh .claude/hooks/scope-guard.sh .claude/hooks/stop-verify-gate.sh .claude/hooks/evidence-log.sh .claude/hooks/secret-guard.sh)"
[ -z "$ch" ] && ok "5 existing guards unchanged" || no "guards changed: $ch"

echo "== installer wires workers + no dangling refs =="
H2="$(mktemp -d)"; .claude/install/dmc-install.sh "$H2" >/dev/null 2>&1
[ -f "$H2/.claude/hooks/worker-context-guard.sh" ] && [ -f "$H2/.claude/hooks/worker-result-check.py" ] && [ -f "$H2/.claude/hooks/lib/secret-paths.sh" ] && ok "worker hooks installed" || no "worker hooks install"
[ -d "$H2/.claude/skills/dmc-worker-plan" ] && [ -f "$H2/WORKER_TASK_SCHEMA.md" ] && [ -d "$H2/.harness/workers/tasks" ] && ok "worker skills/schemas/skeleton installed" || no "worker surface install"
dang=0; for s in DMC.md CLAUDE.md .claude/skills/dmc-off/SKILL.md; do for ref in $(grep -oE 'docs/[A-Za-z0-9_./-]+\.md' "$H2/$s" 2>/dev/null|sort -u); do [ -f "$H2/$ref" ] || dang=1; done; done
[ "$dang" = 0 ] && ok "zero dangling references" || no "dangling references"
rm -rf "$H2"

echo
echo "==== SUMMARY: PASS=$PASS FAIL=$FAIL ===="
[ "$FAIL" = 0 ] && echo "RESULT: ALL PASS" || echo "RESULT: FAILURES"
