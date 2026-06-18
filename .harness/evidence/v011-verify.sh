#!/usr/bin/env bash
# v0.1.1 verification harness (run via: bash .harness/evidence/v011-verify.sh)
# Tests run against temp CLAUDE_PROJECT_DIR dirs so the real repo mode/state is untouched.
set -u
ROOT="$(pwd)"
H="$ROOT/.claude/hooks"
PASS=0; FAIL=0
ok(){ echo "  PASS $1"; PASS=$((PASS+1)); }
no(){ echo "  FAIL $1"; FAIL=$((FAIL+1)); }

newproj(){ T="$(mktemp -d)"; mkdir -p "$T/.harness/runs" "$T/.harness/verification" "$T/.harness/evidence" "$T/src" "$T/other"; printf '%s\n' "$1" > "$T/.harness/mode"; echo "$T"; }
guard(){ printf '{"tool_input":{"command":"%s"}}' "$2" | CLAUDE_PROJECT_DIR="$1" bash "$H/pre-tool-guard.sh"; }
router(){ printf '{"prompt":"%s","cwd":"%s"}' "$1" "${2:-$ROOT}" | CLAUDE_PROJECT_DIR="${2:-$ROOT}" bash "$H/dmc-router.sh"; }

echo "== T005 syntax: bash -n all hooks =="
for f in "$H"/*.sh; do bash -n "$f" && ok "bash -n $(basename "$f")" || no "bash -n $(basename "$f")"; done

echo "== T009 mode-gate block identical across the 4 existing hooks =="
n=$(for f in pre-tool-guard scope-guard stop-verify-gate evidence-log; do awk '/DMC_MODE_FILE=/{f=1} f{print} f&&/^fi$/{exit}' "$H/$f.sh" | md5; done | sort -u | wc -l | tr -d ' ')
[ "$n" = 1 ] && ok "mode-gate md5 unique=1" || no "mode-gate md5 unique=$n"

echo "== active mode (today's behavior) =="
T=$(newproj active)
guard "$T" "rm -rf /" | grep -q '"deny"' && ok "active rm-rf deny" || no "active rm-rf deny"
guard "$T" "npm install" | grep -q '"ask"' && ok "active npm ask" || no "active npm ask"
[ "$(guard "$T" "ls" | wc -c | tr -d ' ')" = 0 ] && ok "active benign 0" || no "active benign 0"
printf 'src/\n' > "$T/.harness/runs/current-scope.txt"
printf '{"tool_name":"Write","tool_input":{"file_path":"%s/other/x.ts"},"cwd":"%s"}' "$T" "$T" | CLAUDE_PROJECT_DIR="$T" bash "$H/scope-guard.sh" | grep -q '"deny"' && ok "active scope out deny" || no "active scope out deny"
[ "$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s/src/x.ts"},"cwd":"%s"}' "$T" "$T" | CLAUDE_PROJECT_DIR="$T" bash "$H/scope-guard.sh" | wc -c | tr -d ' ')" = 0 ] && ok "active scope in 0" || no "active scope in 0"
printf 'RUN-X\n' > "$T/.harness/runs/current-run-id"
printf '{"stop_hook_active":"false","last_assistant_message":"done, completed","cwd":"%s"}' "$T" | CLAUDE_PROJECT_DIR="$T" bash "$H/stop-verify-gate.sh" | grep -q '"block"' && ok "active stop block" || no "active stop block"
printf '{"tool_name":"Bash","tool_input":{"command":"echo hi"},"cwd":"%s"}' "$T" | CLAUDE_PROJECT_DIR="$T" bash "$H/evidence-log.sh" >/dev/null 2>&1
ef="$(ls "$T"/.harness/evidence/*.md 2>/dev/null | head -1)"; { [ -n "$ef" ] && grep -q '### .* Bash' "$ef"; } && ok "active evidence body" || no "active evidence body"
rm -rf "$T"

echo "== passive mode (deny tier kept, ask dropped, gates stand down) =="
T=$(newproj passive)
guard "$T" "rm -rf /" | grep -q '"deny"' && ok "passive rm-rf deny" || no "passive rm-rf deny"
guard "$T" "cat .env" | grep -q '"deny"' && ok "passive secret deny" || no "passive secret deny"
[ "$(guard "$T" "npm install" | wc -c | tr -d ' ')" = 0 ] && ok "passive npm pass (no ask)" || no "passive npm pass"
printf 'src/\n' > "$T/.harness/runs/current-scope.txt"
[ "$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s/other/x.ts"},"cwd":"%s"}' "$T" "$T" | CLAUDE_PROJECT_DIR="$T" bash "$H/scope-guard.sh" | wc -c | tr -d ' ')" = 0 ] && ok "passive scope pass-through" || no "passive scope pass-through"
printf 'RUN-X\n' > "$T/.harness/runs/current-run-id"
[ "$(printf '{"stop_hook_active":"false","last_assistant_message":"done","cwd":"%s"}' "$T" | CLAUDE_PROJECT_DIR="$T" bash "$H/stop-verify-gate.sh" | wc -c | tr -d ' ')" = 0 ] && ok "passive stop pass-through" || no "passive stop pass-through"
printf '{"tool_name":"Bash","tool_input":{"command":"echo hi"},"cwd":"%s"}' "$T" | CLAUDE_PROJECT_DIR="$T" bash "$H/evidence-log.sh" >/dev/null 2>&1
[ -z "$(ls "$T"/.harness/evidence/*.md 2>/dev/null)" ] && ok "passive evidence no-op" || no "passive evidence no-op"
rm -rf "$T"

echo "== off mode (catastrophic + secret deny only) =="
T=$(newproj off)
guard "$T" "rm -rf /" | grep -q '"deny"' && ok "off rm-rf deny" || no "off rm-rf deny"
guard "$T" "git push --force origin main" | grep -q '"deny"' && ok "off push-force deny" || no "off push-force deny"
guard "$T" "cat .env" | grep -q '"deny"' && ok "off secret deny" || no "off secret deny"
[ "$(guard "$T" "npm install" | wc -c | tr -d ' ')" = 0 ] && ok "off npm pass" || no "off npm pass"
[ "$(guard "$T" "git reset --hard" | wc -c | tr -d ' ')" = 0 ] && ok "off git-reset pass (Block B stands down)" || no "off git-reset pass"
rm -rf "$T"

echo "== router: suffix routing + precedence + negative + parser =="
router "fix the parser dmc" | grep -q 'dmc-ultrawork' && ok "router dmc->ultrawork" || no "router dmc->ultrawork"
router "design the schema dmc-plan" | grep -q 'dmc-plan-hard' && ok "router dmc-plan->planning" || no "router dmc-plan->planning"
[ "$(router "just a normal request" | wc -c | tr -d ' ')" = 0 ] && ok "router passthrough" || no "router passthrough"
[ "$(router "the dmc-off switch is documented here" | wc -c | tr -d ' ')" = 0 ] && ok "router negative mid-sentence" || no "router negative mid-sentence"
grep -q 'DMC_HOOK_INPUT="$INPUT" python3' "$H/dmc-router.sh" && ok "router env-var parse (no regression)" || no "router env-var parse"

echo "== router-write independence (mode file written regardless of advisory routing) =="
T=$(newproj active); rm -f "$T/.harness/mode"
router "x dmc" "$T" >/dev/null; [ "$(cat "$T/.harness/mode" 2>/dev/null)" = active ] && ok "router 'dmc' writes active" || no "router 'dmc' writes active"
router "x dmc-off" "$T" >/dev/null; [ "$(cat "$T/.harness/mode" 2>/dev/null)" = off ] && ok "router 'dmc-off' writes off" || no "router 'dmc-off' writes off"
printf 'active\n' > "$T/.harness/mode"; router "x dmc-plan" "$T" >/dev/null; [ "$(cat "$T/.harness/mode")" = active ] && ok "router 'dmc-plan' leaves mode unchanged" || no "router 'dmc-plan' unchanged"
printf 'active\n' > "$T/.harness/mode"; router "normal prompt" "$T" >/dev/null; [ "$(cat "$T/.harness/mode")" = active ] && ok "router normal: no mode write" || no "router normal: no mode write"
echo "  (run-in-progress warning) :"; T2=$(newproj off); printf 'RUN-Y\n' > "$T2/.harness/runs/current-run-id"; router "x dmc-off" "$T2" | grep -q 'run is in progress' && ok "router dmc-off warns on active run" || no "router dmc-off warns"; rm -rf "$T2"
rm -rf "$T"

echo "== settings.json valid + UserPromptSubmit wired; existing 6 skills present =="
python3 -m json.tool .claude/settings.json >/dev/null 2>&1 && ok "settings valid json" || no "settings valid json"
grep -q 'dmc-router.sh' .claude/settings.json && ok "router wired in settings" || no "router wired"
[ "$(ls .claude/skills/dmc-critic .claude/skills/dmc-init-deep .claude/skills/dmc-plan-hard .claude/skills/dmc-start-work .claude/skills/dmc-ultrawork .claude/skills/dmc-verify-hard -d 2>/dev/null | wc -l | tr -d ' ')" = 6 ] && ok "6 existing skills present" || no "6 existing skills present"

echo "== .harness/mode + .omc gitignored =="
git check-ignore .harness/mode >/dev/null 2>&1 && ok ".harness/mode ignored" || no ".harness/mode ignored"
git check-ignore .omc/x >/dev/null 2>&1 && ok ".omc ignored" || no ".omc ignored"

echo
echo "==== SUMMARY: PASS=$PASS FAIL=$FAIL ===="
[ "$FAIL" = 0 ] && echo "RESULT: ALL PASS" || echo "RESULT: FAILURES PRESENT"
