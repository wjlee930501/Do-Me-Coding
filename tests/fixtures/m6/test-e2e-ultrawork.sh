#!/usr/bin/env bash
# test-e2e-ultrawork.sh — DMC v1 M6 ultrawork stop-block E2E (master §M6 acceptance).
#
# Nature: END-TO-END test. Stands up a mktemp repo with the FULL DMC surface
# COPIED from the live working tree (bin/, .claude/, orchestration/, schema
# roots), arms a run through the real Ring-0 arming path exactly as the
# ultrawork `dmc run start` binding does, then drives the ACTUAL
# stop-verify-gate.sh shim (resolving the COPIED $tmp/bin/dmc) across the three
# acceptance transitions:
#   1. armed run + missing verification  -> stop HELD (block),
#   2. + a crosscheck-passing verification report -> stop PASSES,
#   3. `dmc run suspend` -> stop PASSES (the designed escape hatch).
#
# Never reads .env / credentials; never mutates the live repo (porcelain
# before/after); no network / live / model / API call. Everything runs inside
# the copied sandbox.
#
# Usage: test-e2e-ultrawork.sh   Run all checks, print PASS/FAIL + summary, exit 0/1.

set -u

SELF_DIR=$(cd -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd -P) || { echo "FATAL: script dir"; exit 2; }
# shellcheck source=_m6common.sh
. "$SELF_DIR/_m6common.sh"

if ! git -C "$M6_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "FATAL: repo root is not a git worktree: $M6_ROOT"; exit 2
fi

SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/dmc-m6-e2e.XXXXXX") || { echo "FATAL: mktemp"; exit 2; }
cleanup() { rm -rf "$SANDBOX"; }
trap cleanup EXIT

# Copy the FULL DMC surface from the WORKING TREE (not HEAD — the M6 CLIs/shims
# are uncommitted). Enough to run start + scope-lock compile + stop-gate +
# semantic cross-check (instance-validate resolves schemas from bin/lib's
# grandparent, so the schema roots must travel with bin/).
REPO="$SANDBOX/repo"
mkdir -p "$REPO"
copy_surface() {
  local d f
  for d in bin .claude orchestration .harness/schemas; do
    if [ -e "$M6_ROOT/$d" ]; then
      mkdir -p "$REPO/$(dirname "$d")"
      cp -R "$M6_ROOT/$d" "$REPO/$d"
    fi
  done
  for f in PLAN_SCHEMA.md RUN_SCHEMA.md VERIFICATION_SCHEMA.md; do
    [ -f "$M6_ROOT/$f" ] && cp "$M6_ROOT/$f" "$REPO/$f"
  done
}

DMC_LOCAL="$REPO/bin/dmc"
SVG_LOCAL="$REPO/.claude/hooks/stop-verify-gate.sh"

# stop() drives the copied stop shim against the copied surface; echoes exit code
# on the last line, decision on the first.
stop_gate() {
  local out rc
  out=$(printf '{"stop_hook_active":false,"cwd":%s}' "$(json_str "$REPO")" \
        | CLAUDE_PROJECT_DIR="$REPO" bash "$SVG_LOCAL")
  rc=$?
  printf '%s\n%s' "$(stop_decision_of "$out")" "$rc"
}

e2e() {
  echo "  -- ultrawork stop-block E2E (full surface copied) --"
  copy_surface
  [ -x "$DMC_LOCAL" ] && record PASS "surface copy: copied bin/dmc present + executable" \
                      || { record FAIL "surface copy: bin/dmc missing after copy"; return; }
  [ -f "$SVG_LOCAL" ] && record PASS "surface copy: stop-verify-gate.sh shim present" \
                      || { record FAIL "surface copy: stop shim missing"; return; }

  # ---- baseline + arm via the COPIED bin/dmc (the ultrawork arming path) ----
  git init -q "$REPO"
  git -C "$REPO" config user.email t@example.com
  git -C "$REPO" config user.name "M6 E2E"
  mkdir -p "$REPO/src"
  printf 'print("app")\n' > "$REPO/src/app.py"
  printf '# e2e\n' > "$REPO/README.md"
  # keep run pointers + copied surface out of the porcelain the cross-check inspects
  printf '.harness/runs/current-*\n' > "$REPO/.gitignore"
  m6_write_plan "$REPO/plan.md" "dmc-e2e-ultrawork" "E2E"
  m6_write_landmarks "$REPO/landmarks.json"
  git -C "$REPO" add -A
  git -C "$REPO" commit -q -m baseline

  "$DMC_LOCAL" run start --plan "$REPO/plan.md" --root "$REPO" >/dev/null 2>&1
  local rid; rid=$(cat "$REPO/.harness/runs/current-run-id" 2>/dev/null)
  [ -n "$rid" ] && record PASS "ultrawork arm: dmc run start minted run '$rid' (RUNNING)" \
                || { record FAIL "ultrawork arm: dmc run start did not arm"; return; }
  python3 "$REPO/bin/lib/dmc-scope-lock.py" --compile --plan "$REPO/plan.md" \
    --landmarks "$REPO/landmarks.json" --run-id "$rid" --root "$REPO" >/dev/null 2>&1
  [ -f "$REPO/.harness/runs/$rid/scope.lock.json" ] \
    && record PASS "ultrawork arm: scope.lock.json compiled (immutable, operative snapshot pinned)" \
    || { record FAIL "ultrawork arm: scope-lock compile failed"; return; }

  # ---- transition 1: stop with NO verification -> HELD ----
  local r dec rc
  r=$(stop_gate); dec=$(printf '%s' "$r" | head -1); rc=$(printf '%s' "$r" | tail -1)
  { [ "$dec" = block ] && [ "$rc" -eq 0 ]; } \
    && record PASS "E2E-1 armed run + missing verification -> stop HELD (decision block, hook exit 0)" \
    || record FAIL "E2E-1 stop should HOLD (got decision=$dec rc=$rc)"

  # ---- transition 2: add a crosscheck-passing verification report -> PASSES ----
  mkdir -p "$REPO/.harness/verification"
  m6_write_pass_report "$REPO/.harness/verification/$rid.md" "$rid"
  r=$(stop_gate); dec=$(printf '%s' "$r" | head -1); rc=$(printf '%s' "$r" | tail -1)
  { [ "$dec" = pass ] && [ "$rc" -eq 0 ]; } \
    && record PASS "E2E-2 crosscheck-passing verification report -> stop PASSES (empty envelope)" \
    || record FAIL "E2E-2 stop should PASS with a passing report (got decision=$dec rc=$rc)"

  # cross-check independently ACCEPTs the report (semantic gate, not a keyword match).
  "$DMC_LOCAL" verify-crosscheck --report "$REPO/.harness/verification/$rid.md" \
    --run "$REPO/.harness/runs/$rid" >/dev/null 2>&1
  assert_eq 0 "$?" "E2E-2b dmc verify-crosscheck ACCEPTs the report (run-id bound, in-scope, honest PASS)"

  # ---- transition 3: suspend -> stop PASSES (escape hatch), even if we drop the report ----
  rm -f "$REPO/.harness/verification/$rid.md"
  "$DMC_LOCAL" run suspend --root "$REPO" >/dev/null 2>&1
  assert_eq 0 "$?" "E2E-3a dmc run suspend transitions RUNNING -> SUSPENDED"
  r=$(stop_gate); dec=$(printf '%s' "$r" | head -1); rc=$(printf '%s' "$r" | tail -1)
  { [ "$dec" = pass ] && [ "$rc" -eq 0 ]; } \
    && record PASS "E2E-3b a SUSPENDED run does NOT block stop (designed escape hatch)" \
    || record FAIL "E2E-3b suspended run should not block stop (got decision=$dec rc=$rc)"
}

main() {
  echo "test-e2e-ultrawork.sh :: root=$M6_ROOT"
  m6_capture_before
  e2e
  echo "  -- real-repo cleanliness --"
  m6_assert_repo_untouched
  echo "  ----"
  echo "  RESULT: $PASS PASS / $FAIL FAIL"
  [ "$FAIL" -eq 0 ] && exit 0 || exit 1
}

main
