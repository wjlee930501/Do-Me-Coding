#!/usr/bin/env bash
# v0.1.3 verification harness (run: bash .harness/evidence/dmc-v0.1.3-verify.sh)
set -u
ROOT="$(pwd)"; H="$ROOT/.claude/hooks"; PASS=0; FAIL=0
ok(){ echo "  PASS $1"; PASS=$((PASS+1)); }
no(){ echo "  FAIL $1"; FAIL=$((FAIL+1)); }
sg(){ printf '%s' "$1" | "$H/secret-guard.sh"; }

echo "== bash -n all hooks + installers =="
for f in "$H"/*.sh "$ROOT"/.claude/install/*.sh; do bash -n "$f" && ok "bash -n $(basename "$f")" || no "bash -n $(basename "$f")"; done

echo "== secret-guard: Read DENY secret paths =="
for p in /r/.env /r/.env.local /r/.env.prod.local /r/.env.production /r/id_rsa /r/x.pem /r/api.key /r/.npmrc /r/svc-service-account.json /h/.ssh/id_ed25519 /h/.aws/credentials /r/app-secrets.json; do
  printf '{"tool_name":"Read","tool_input":{"file_path":"%s"}}' "$p" | "$H/secret-guard.sh" | grep -q '"deny"' && ok "deny $p" || no "deny $p"
done
echo "== secret-guard: Read ALLOW non-secrets =="
for p in /r/.env.example /r/.env.sample /r/src/environment.ts /r/src/app.ts /r/README.md; do
  [ "$(printf '{"tool_name":"Read","tool_input":{"file_path":"%s"}}' "$p" | "$H/secret-guard.sh" | wc -c | tr -d ' ')" = 0 ] && ok "allow $p" || no "allow $p"
done
echo "== secret-guard: Glob deny/allow =="
printf '{"tool_name":"Glob","tool_input":{"glob":"**/.env*"}}' | "$H/secret-guard.sh" | grep -q '"deny"' && ok "glob deny **/.env*" || no "glob deny"
[ "$(printf '{"tool_name":"Glob","tool_input":{"glob":"src/**/*.ts"}}' | "$H/secret-guard.sh" | wc -c | tr -d ' ')" = 0 ] && ok "glob allow ts" || no "glob allow ts"
echo "== secret-guard: mode-independent floor (denies regardless of .harness/mode) =="
T="$(mktemp -d)"; mkdir -p "$T/.harness"
for m in active passive off; do printf '%s\n' "$m" > "$T/.harness/mode"; printf '{"tool_name":"Read","tool_input":{"file_path":"/r/.env"}}' | CLAUDE_PROJECT_DIR="$T" "$H/secret-guard.sh" | grep -q '"deny"' && ok "secret deny in mode=$m" || no "secret deny in mode=$m"; done
rm -rf "$T"

echo "== v0.1 regression: existing hooks still enforce (active) =="
printf '{"tool_input":{"command":"rm -rf /"}}' | "$H/pre-tool-guard.sh" | grep -q '"deny"' && ok "pre-tool-guard rm-rf deny" || no "pre-tool-guard rm-rf deny"
printf '{"tool_input":{"command":"cat .env"}}' | "$H/pre-tool-guard.sh" | grep -q '"deny"' && ok "pre-tool-guard cat .env deny (bash)" || no "pre-tool-guard cat .env deny"
printf '{"tool_input":{"command":"npm install"}}' | "$H/pre-tool-guard.sh" | grep -q '"ask"' && ok "pre-tool-guard npm ask" || no "pre-tool-guard npm ask"
[ "$(printf '{"tool_input":{"command":"ls"}}' | "$H/pre-tool-guard.sh" | wc -c | tr -d ' ')" = 0 ] && ok "pre-tool-guard benign 0" || no "pre-tool-guard benign"

echo "== existing 4 hooks byte-unchanged this run? (git) =="
ch="$(git diff --name-only .claude/hooks/pre-tool-guard.sh .claude/hooks/scope-guard.sh .claude/hooks/stop-verify-gate.sh .claude/hooks/evidence-log.sh)"
[ -z "$ch" ] && ok "4 existing hooks unchanged" || no "existing hooks changed: $ch"

echo "== settings.json valid + only added matcher =="
python3 -m json.tool .claude/settings.json >/dev/null 2>&1 && ok "settings valid json" || no "settings invalid"
[ "$(python3 -c 'import json;print(len(json.load(open(".claude/settings.json"))["hooks"]["PreToolUse"]))')" = 3 ] && ok "PreToolUse has 3 matchers (added secret-guard)" || no "PreToolUse matcher count"
grep -q 'secret-guard.sh' .claude/settings.json && ok "secret-guard wired" || no "secret-guard not wired"

echo "== installer dry-run + dangling-ref (real install temp) =="
H2="$(mktemp -d)"; .claude/install/dmc-install.sh "$H2" >/dev/null 2>&1
[ "$(cat "$H2/.harness/mode")" = active ] && ok "clean host -> active" || no "mode default"
[ -f "$H2/.claude/hooks/secret-guard.sh" ] && ok "secret-guard installed" || no "secret-guard install"
[ ! -f "$H2/AGENTS.md" ] && ok "AGENTS.md not installed" || no "AGENTS.md installed (bad)"
dang=0; for s in DMC.md CLAUDE.md .claude/skills/dmc-off/SKILL.md; do for ref in $(grep -oE 'docs/[A-Za-z0-9_./-]+\.md' "$H2/$s" 2>/dev/null|sort -u); do [ -f "$H2/$ref" ] || dang=1; done; done
[ "$dang" = 0 ] && ok "zero dangling references" || no "dangling references"
H3="$(mktemp -d)"; mkdir -p "$H3/.omc"; .claude/install/dmc-install.sh "$H3" >/dev/null 2>&1
[ "$(cat "$H3/.harness/mode")" = passive ] && ok ".omc host -> passive" || no "passive detection"
rm -rf "$H2" "$H3"

echo "== no GLM/worker execution code =="
if grep -riE 'glm|worker[ -]?bridge|worker[ -]?exec' .claude/hooks .claude/install INSTALL_MANIFEST.md 2>/dev/null | grep -v 'future dependency'; then no "GLM/worker code found"; else ok "no GLM/worker code"; fi

echo
echo "==== SUMMARY: PASS=$PASS FAIL=$FAIL ===="
[ "$FAIL" = 0 ] && echo "RESULT: ALL PASS" || echo "RESULT: FAILURES"
