#!/usr/bin/env bash
# Standalone offline smoke test for the v1.1.1 ask-tier bypass-awareness in pre-tool-guard.sh.
#
# NOT wired into `dmc selftest` (test-install-wrapper.sh precedent). It runs the LIVE hook against
# synthetic PreToolUse envelopes from a disposable CLAUDE_PROJECT_DIR sandbox: no network, no repo
# writes (every scratch file lives inside a mktemp dir that is removed on exit).
#
# Behavior under test: when Block C (the active-mode ask tier) matches AND the host session reports
# permission_mode == "bypassPermissions", the ask is downgraded to an advisory stand-down (allow
# pass-through + a value-blind class/timestamp log line). Deny floors never stand down; every other
# permission_mode value keeps the frozen ask. See tests/install and docs/MILESTONES.md v1.1.1.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$REPO_ROOT/.claude/hooks/pre-tool-guard.sh"

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); printf 'PASS  %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }

if [ ! -f "$HOOK" ]; then
  printf 'FATAL: hook not found at %s\n' "$HOOK"
  exit 2
fi

HAVE_PY=0
command -v python3 >/dev/null 2>&1 && HAVE_PY=1

TMPROOT="$(mktemp -d)"
cleanup() { chmod -R u+w "$TMPROOT" 2>/dev/null || true; rm -rf "$TMPROOT"; }
trap cleanup EXIT

# new_sandbox <mode> -> prints a fresh CLAUDE_PROJECT_DIR with .harness/mode preset.
new_sandbox() {
  _sb="$(mktemp -d "$TMPROOT/sb.XXXXXX")"
  mkdir -p "$_sb/.harness"
  printf '%s\n' "$1" > "$_sb/.harness/mode"
  printf '%s' "$_sb"
}

# run_hook <sandbox> <json> -> sets HOOK_OUT (stdout) and HOOK_RC (exit code).
run_hook() {
  HOOK_OUT="$(printf '%s' "$2" | CLAUDE_PROJECT_DIR="$1" bash "$HOOK")"
  HOOK_RC=$?
}

has_ask()  { printf '%s' "$1" | grep -q '"permissionDecision":"ask"'; }
has_deny() { printf '%s' "$1" | grep -q '"permissionDecision":"deny"'; }
has_sysmsg() { printf '%s' "$1" | grep -q '"systemMessage"'; }

# --- Case 1: npm install, NO permission_mode, mode=active => ask (frozen v0.1.3 compat) ---
sb="$(new_sandbox active)"
run_hook "$sb" '{"tool_input":{"command":"npm install"}}'
if has_ask "$HOOK_OUT"; then
  pass "case1 npm install (no permission_mode) => ask [frozen-compat]"
else
  fail "case1 npm install (no permission_mode) => expected ask, got: $HOOK_OUT"
fi

# --- Case 2: npm install + acceptEdits => ask (acceptEdits is NOT blanket bash consent) ---
sb="$(new_sandbox active)"
run_hook "$sb" '{"tool_input":{"command":"npm install"},"permission_mode":"acceptEdits"}'
if has_ask "$HOOK_OUT"; then
  pass "case2 npm install + acceptEdits => ask"
else
  fail "case2 npm install + acceptEdits => expected ask, got: $HOOK_OUT"
fi

# --- Case 3: npm install + bypassPermissions => stand-down (no ask, rc0, systemMessage, 1 log line) ---
sb="$(new_sandbox active)"
run_hook "$sb" '{"tool_input":{"command":"npm install"},"permission_mode":"bypassPermissions"}'
log="$sb/.harness/metrics/ask-tier-advisory.log"
ok=1
has_ask "$HOOK_OUT" && ok=0
has_sysmsg "$HOOK_OUT" || ok=0
[ "$HOOK_RC" = 0 ] || ok=0
if [ "$HAVE_PY" = 1 ]; then
  printf '%s' "$HOOK_OUT" | python3 -m json.tool >/dev/null 2>&1 || ok=0
fi
logn=0
[ -f "$log" ] && logn="$(wc -l < "$log" | tr -d '[:space:]')"
[ "$logn" = 1 ] || ok=0
{ [ -f "$log" ] && grep -Eq '^[0-9TZ:-]+ ask-tier-standdown class=install$' "$log"; } || ok=0
if [ "$ok" = 1 ]; then
  pass "case3 npm install + bypass => stand-down (no ask, rc0, systemMessage parseable, 1 value-blind log line class=install)"
else
  fail "case3 npm install + bypass => FAILED (rc=$HOOK_RC logn=$logn out=$HOOK_OUT log=$( [ -f "$log" ] && cat "$log" ))"
fi

# --- Case 4: git push --force + bypass => STILL deny (Block A floor never stands down) ---
sb="$(new_sandbox active)"
run_hook "$sb" '{"tool_input":{"command":"git push --force"},"permission_mode":"bypassPermissions"}'
if has_deny "$HOOK_OUT"; then
  pass "case4 git push --force + bypass => deny [floor never stands down]"
else
  fail "case4 git push --force + bypass => expected deny, got: $HOOK_OUT"
fi

# --- Case 5: cat .env + bypass => STILL deny (secret-exposure floor) ---
sb="$(new_sandbox active)"
run_hook "$sb" '{"tool_input":{"command":"cat .env"},"permission_mode":"bypassPermissions"}'
if has_deny "$HOOK_OUT"; then
  pass "case5 cat .env + bypass => deny [secret floor]"
else
  fail "case5 cat .env + bypass => expected deny, got: $HOOK_OUT"
fi

# --- Case 6: (non-prisma) migrate reset + bypass => stand-down class=migrate ---
# `prisma migrate reset` is a Block A deny (bypass never stands a deny floor down); a non-prisma
# migrate-reset reaches Block C so the consequential class is recorded for the pilot to review.
sb="$(new_sandbox active)"
run_hook "$sb" '{"tool_input":{"command":"sqlx migrate reset"},"permission_mode":"bypassPermissions"}'
log="$sb/.harness/metrics/ask-tier-advisory.log"
if [ "$HOOK_RC" = 0 ] && ! has_ask "$HOOK_OUT" \
   && [ -f "$log" ] && grep -Eq '^[0-9TZ:-]+ ask-tier-standdown class=migrate$' "$log"; then
  pass "case6 migrate reset + bypass => stand-down class=migrate logged"
else
  fail "case6 migrate reset + bypass => FAILED (rc=$HOOK_RC out=$HOOK_OUT log=$( [ -f "$log" ] && cat "$log" ))"
fi

# --- Case 7: mode=passive + no permission_mode => no ask (passive stands the ask-tier down) ---
sb="$(new_sandbox passive)"
run_hook "$sb" '{"tool_input":{"command":"npm install"}}'
if [ "$HOOK_RC" = 0 ] && ! has_ask "$HOOK_OUT"; then
  pass "case7 npm install, mode=passive, no permission_mode => no ask [passive semantics intact]"
else
  fail "case7 npm install, mode=passive => expected no ask, got rc=$HOOK_RC out=$HOOK_OUT"
fi

# --- Case 8: log-append failure injection (read-only metrics dir) => hook still exits 0 allowing ---
sb="$(new_sandbox active)"
mkdir -p "$sb/.harness/metrics"
chmod a-w "$sb/.harness/metrics"
run_hook "$sb" '{"tool_input":{"command":"npm install"},"permission_mode":"bypassPermissions"}'
rc8="$HOOK_RC"
out8="$HOOK_OUT"
chmod u+w "$sb/.harness/metrics" 2>/dev/null || true
if [ "$rc8" = 0 ] && has_sysmsg "$out8" && ! has_ask "$out8"; then
  pass "case8 read-only metrics dir + bypass => hook exits 0 allowing (best-effort log swallowed)"
else
  fail "case8 read-only metrics dir + bypass => expected rc0 + systemMessage + no ask, got rc=$rc8 out=$out8"
fi

# --- Negative control: value-blind log — a fake token in the command NEVER enters the log line ---
FAKE_TOKEN='sk-FAKE0000NOTAREALKEY'
sb="$(new_sandbox active)"
run_hook "$sb" '{"tool_input":{"command":"npm install # sk-FAKE0000NOTAREALKEY"},"permission_mode":"bypassPermissions"}'
log="$sb/.harness/metrics/ask-tier-advisory.log"
if [ -f "$log" ] && grep -Eq '^[0-9TZ:-]+ ask-tier-standdown class=install$' "$log" \
   && ! grep -q "$FAKE_TOKEN" "$log"; then
  pass "negctl fake token in command => log records class only, token absent [value-blind]"
else
  fail "negctl value-blind => FAILED (log=$( [ -f "$log" ] && cat "$log" ))"
fi

printf '\nRESULT: %d passed, %d failed (total %d)\n' "$PASS" "$FAIL" "$((PASS + FAIL))"
[ "$FAIL" -gt 0 ] && exit 1
exit 0
