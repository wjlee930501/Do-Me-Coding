#!/usr/bin/env bash
# test-compat.sh — DMC v1 M6 hook-hardening compatibility matrix.
#
# Nature: COMPATIBILITY test. Proves the shims do NOT over-block: every
# legitimate operation still passes, the six legacy behavioral contracts hold,
# each hook honours its per-mode gate (active / passive / off), unarmed runs
# stand L1 down while the L0 floor holds, armed runs allow in-scope work, and
# the stop-path quick gate stays under its latency budget. Each row is a real
# hook invocation (synthetic tool JSON + a mktemp CLAUDE_PROJECT_DIR) or a real
# Ring-0 CLI call against a mktemp fixture.
#
# Never reads .env / credentials; never mutates the live repo (porcelain
# before/after); no network / live / model / API call.
#
# Usage: test-compat.sh   Run all checks, print PASS/FAIL + summary, exit 0/1.

set -u

SELF_DIR=$(cd -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd -P) || { echo "FATAL: script dir"; exit 2; }
# shellcheck source=_m6common.sh
. "$SELF_DIR/_m6common.sh"

if ! git -C "$M6_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "FATAL: repo root is not a git worktree: $M6_ROOT"; exit 2
fi

SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/dmc-m6-compat.XXXXXX") || { echo "FATAL: mktemp"; exit 2; }
cleanup() { rm -rf "$SANDBOX"; }
trap cleanup EXIT

set_mode() { mkdir -p "$1/.harness"; printf '%s\n' "$2" > "$1/.harness/mode"; }   # set_mode TMP mode

# ============================================================================
# The six legacy behavioral rows (shim runtime contract). These are the
# live-hook assertions the pinned 802/3/3 baseline also exercises.
# ============================================================================
legacy_rows() {
  echo "  -- six legacy behavioral rows (shim runtime contract) --"
  local tmp="$SANDBOX/legacy" out
  mkdir -p "$tmp/.harness"

  # (1) empty stdout on allow — a benign Bash command produces NO envelope.
  out=$(hook_run pre-tool-guard.sh "$(bash_input 'echo hello')" "$tmp")
  [ -z "$out" ] && record PASS "L1 empty stdout on allow (benign Bash command)" \
                || record FAIL "L1 empty stdout on allow (got: $out)"

  # (2) ask-tier on npm install (active).
  out=$(hook_run pre-tool-guard.sh "$(bash_input 'npm install left-pad')" "$tmp")
  assert_eq ask "$(decision_of "$out")" "L2 npm install -> ask tier (active)"

  # (3) deny on destructive-rm and dot-env read.
  out=$(hook_run pre-tool-guard.sh "$(bash_input 'rm -rf /')" "$tmp")
  assert_eq deny "$(decision_of "$out")" "L3a destructive rm -rf / -> deny"
  out=$(hook_run secret-guard.sh "$(read_input '/proj/.env')" "$tmp")
  assert_eq deny "$(decision_of "$out")" "L3b Read of .env -> deny (secret floor)"

  # (4) secret deny floor holds in ALL modes.
  local m
  for m in active passive off; do
    set_mode "$tmp" "$m"
    out=$(hook_run secret-guard.sh "$(read_input '/proj/.env')" "$tmp")
    assert_eq deny "$(decision_of "$out")" "L4 secret floor DENIES .env in mode=$m"
  done
  rm -f "$tmp/.harness/mode"

  # (5) synthetic CLAUDE_PROJECT_DIR with no bin/dmc and no .harness/runs: the L0 static floor
  # still fires inline; a benign command still allows; nothing crashes (exit 0).
  local syn="$SANDBOX/synth"; mkdir -p "$syn"
  out=$(hook_run pre-tool-guard.sh "$(bash_input 'git apply x.patch')" "$syn"); local rc=$?
  { [ "$(decision_of "$out")" = deny ] && [ "$rc" -eq 0 ]; } \
    && record PASS "L5a synthetic CLAUDE_PROJECT_DIR (no bin/dmc): L0 git-apply floor fires, exit 0" \
    || record FAIL "L5a synthetic CLAUDE_PROJECT_DIR: L0 floor should fire cleanly (rc=$rc)"
  out=$(hook_run pre-tool-guard.sh "$(bash_input 'echo hi')" "$syn"); rc=$?
  { [ -z "$out" ] && [ "$rc" -eq 0 ]; } \
    && record PASS "L5b synthetic CLAUDE_PROJECT_DIR: a benign command allows (empty stdout, exit 0)" \
    || record FAIL "L5b synthetic CLAUDE_PROJECT_DIR: benign command should allow cleanly"

  # (6) fail-closed only bites active+armed: an UNARMED synthetic dir never bricks (already L5b);
  # passive/off never deny a benign command either.
  set_mode "$syn" passive
  out=$(hook_run pre-tool-guard.sh "$(bash_input 'echo hi')" "$syn")
  [ -z "$out" ] && record PASS "L6 passive mode never bricks a benign command (empty stdout)" \
                || record FAIL "L6 passive mode should not brick (got: $out)"
  rm -f "$syn/.harness/mode" 2>/dev/null || true
}

# ============================================================================
# Per-hook x per-mode floor rows.
# ============================================================================
per_mode_rows() {
  echo "  -- per-hook x per-mode (active/passive/off) --"
  local tmp="$SANDBOX/mode-armed" rid out m
  rid=$(arm_fixture "$tmp" "dmc-compat-mode") || { record FAIL "mode arm fixture"; return; }

  # pre-tool-guard: catastrophic always denies; git reset --hard denies active+passive not off;
  # npm install asks active only; git apply denies all.
  for m in active passive off; do
    set_mode "$tmp" "$m"
    out=$(hook_run pre-tool-guard.sh "$(bash_input 'rm -rf /')" "$tmp")
    assert_eq deny "$(decision_of "$out")" "PTG mode=$m catastrophic rm -rf / -> deny (all modes)"
    out=$(hook_run pre-tool-guard.sh "$(bash_input 'git apply p.patch')" "$tmp")
    assert_eq deny "$(decision_of "$out")" "PTG mode=$m git apply -> deny (all modes)"
  done
  set_mode "$tmp" active
  assert_eq deny "$(decision_of "$(hook_run pre-tool-guard.sh "$(bash_input 'git reset --hard HEAD')" "$tmp")")" \
    "PTG active: git reset --hard -> deny"
  assert_eq ask  "$(decision_of "$(hook_run pre-tool-guard.sh "$(bash_input 'npm install x')" "$tmp")")" \
    "PTG active: npm install -> ask"
  set_mode "$tmp" passive
  assert_eq deny  "$(decision_of "$(hook_run pre-tool-guard.sh "$(bash_input 'git reset --hard HEAD')" "$tmp")")" \
    "PTG passive: git reset --hard -> deny (Block B holds in passive)"
  assert_eq allow "$(decision_of "$(hook_run pre-tool-guard.sh "$(bash_input 'npm install x')" "$tmp")")" \
    "PTG passive: npm install -> allow (ask tier stands down)"
  set_mode "$tmp" off
  assert_eq allow "$(decision_of "$(hook_run pre-tool-guard.sh "$(bash_input 'git reset --hard HEAD')" "$tmp")")" \
    "PTG off: git reset --hard -> allow (Block B stands down)"

  # scope-guard: enforces in active only; passive/off pass-through an out-of-scope Edit.
  set_mode "$tmp" active
  assert_eq deny  "$(decision_of "$(hook_run scope-guard.sh "$(edit_input "$tmp/outofscope.py" "$tmp")" "$tmp")")" \
    "scope-guard active: out-of-scope Edit -> deny"
  set_mode "$tmp" passive
  assert_eq allow "$(decision_of "$(hook_run scope-guard.sh "$(edit_input "$tmp/outofscope.py" "$tmp")" "$tmp")")" \
    "scope-guard passive: stands down (out-of-scope Edit allowed)"
  set_mode "$tmp" off
  assert_eq allow "$(decision_of "$(hook_run scope-guard.sh "$(edit_input "$tmp/outofscope.py" "$tmp")" "$tmp")")" \
    "scope-guard off: stands down (out-of-scope Edit allowed)"

  # secret-guard: security floor independent of mode (denies .env in all three).
  for m in active passive off; do
    set_mode "$tmp" "$m"
    assert_eq deny "$(decision_of "$(hook_run secret-guard.sh "$(read_input '/x/.env')" "$tmp")")" \
      "secret-guard mode=$m: .env Read -> deny (mode-independent floor)"
  done

  # stop-verify-gate: gates in active only; passive/off pass-through (empty).
  set_mode "$tmp" active
  out=$(hook_run stop-verify-gate.sh "$(printf '{"stop_hook_active":false,"cwd":%s}' "$(json_str "$tmp")")" "$tmp")
  assert_eq block "$(stop_decision_of "$out")" "stop-gate active: armed run + no verification -> block"
  for m in passive off; do
    set_mode "$tmp" "$m"
    out=$(hook_run stop-verify-gate.sh "$(printf '{"stop_hook_active":false,"cwd":%s}' "$(json_str "$tmp")")" "$tmp")
    [ -z "$out" ] && record PASS "stop-gate mode=$m: stands down (empty stdout, stop not gated)" \
                  || record FAIL "stop-gate mode=$m should stand down (got: $out)"
  done

  # evidence-log: no-op in passive/off (empty stdout, no evidence file written).
  local tmp2="$SANDBOX/evlog-off"; mkdir -p "$tmp2/.harness"
  set_mode "$tmp2" off
  out=$(hook_run evidence-log.sh "$(bash_post_input 'echo hi' "$tmp2")" "$tmp2")
  { [ -z "$out" ] && [ ! -d "$tmp2/.harness/evidence" ]; } \
    && record PASS "evidence-log off: no-op (empty stdout, no evidence dir created)" \
    || record FAIL "evidence-log off: should be a no-op"
  rm -f "$tmp/.harness/mode"
}

# ============================================================================
# Unarmed rows: with no active run, L1 stands down, L0 floor holds.
# ============================================================================
unarmed_rows() {
  echo "  -- unarmed (no active run): L1 stands down, L0 floor holds --"
  local tmp="$SANDBOX/unarmed" out
  mk_repo "$tmp" "dmc-compat-unarmed" >/dev/null 2>&1 || { record FAIL "unarmed repo"; return; }
  # no run start -> no current-run-id, no scope.lock.json.

  # out-of-scope Edit passes (no scope to enforce).
  out=$(hook_run scope-guard.sh "$(edit_input "$tmp/anything.py" "$tmp")" "$tmp")
  assert_eq allow "$(decision_of "$out")" "unarmed: out-of-scope Edit ALLOWED (L1 stands down)"

  # Bash write passes L1 untouched.
  out=$(hook_run pre-tool-guard.sh "$(bash_input 'echo x > anywhere.py')" "$tmp")
  assert_eq allow "$(decision_of "$out")" "unarmed: Bash write ALLOWED (L1 stands down)"

  # but git apply still L0-denies.
  out=$(hook_run pre-tool-guard.sh "$(bash_input 'git apply p.patch')" "$tmp")
  assert_eq deny "$(decision_of "$out")" "unarmed: git apply still L0-DENIED (static floor)"

  # out-of-project Edit unarmed -> allow (no run/scope -> scope-guard exits before the deny).
  out=$(hook_run scope-guard.sh "$(edit_input "/tmp/outside-$$.py" "$tmp")" "$tmp")
  assert_eq allow "$(decision_of "$out")" "unarmed: out-of-project Edit ALLOWED (nothing to enforce)"
}

# ============================================================================
# Armed rows: legitimate work under an active run passes.
# ============================================================================
armed_rows() {
  echo "  -- armed: legitimate operations pass --"
  local tmp="$SANDBOX/armed" rid out
  rid=$(arm_fixture "$tmp" "dmc-compat-armed") || { record FAIL "armed arm fixture"; return; }

  # in-scope Edit -> allow.
  out=$(hook_run scope-guard.sh "$(edit_input "$tmp/src/app.py" "$tmp")" "$tmp")
  assert_eq allow "$(decision_of "$out")" "armed: in-scope Edit (src/app.py) ALLOWED"

  # create-grant target -> allow.
  out=$(hook_run scope-guard.sh "$(write_input "$tmp/src/new_mod.py" "$tmp")" "$tmp")
  assert_eq allow "$(decision_of "$out")" "armed: create-grant Write (src/new_mod.py) ALLOWED"

  # evidence + verification writes -> allow (narrow exemption).
  out=$(hook_run scope-guard.sh "$(write_input "$tmp/.harness/evidence/note.md" "$tmp")" "$tmp")
  assert_eq allow "$(decision_of "$out")" "armed: .harness/evidence write ALLOWED (exempt)"
  out=$(hook_run scope-guard.sh "$(write_input "$tmp/.harness/verification/$rid.md" "$tmp")" "$tmp")
  assert_eq allow "$(decision_of "$out")" "armed: .harness/verification write ALLOWED (exempt)"

  # out-of-project Edit while armed -> DENY (pinned).
  out=$(hook_run scope-guard.sh "$(edit_input "/tmp/outside-armed-$$.py" "$tmp")" "$tmp")
  assert_eq deny "$(decision_of "$out")" "armed: out-of-project Edit DENIED (pinned)"

  # symlink INTO the repo pointing at an in-scope file -> adjudicated as the real target (allow).
  ln -s "$tmp/src/app.py" "$tmp/link-to-app.py"
  out=$(hook_run scope-guard.sh "$(edit_input "$tmp/link-to-app.py" "$tmp")" "$tmp")
  assert_eq allow "$(decision_of "$out")" "armed: symlink -> in-scope target adjudicated as the real target (allow)"

  # untracked-noise present at ARMING time never trips the post-Bash guard.
  local tmp2="$SANDBOX/noise"
  mk_repo "$tmp2" "dmc-compat-noise" >/dev/null 2>&1 || { record FAIL "noise repo"; return; }
  printf 'pre-existing local noise\n' > "$tmp2/local-noise.log"     # untracked, BEFORE arming
  "$M6_DMC" run start --plan "$tmp2/plan.md" --root "$tmp2" >/dev/null 2>&1
  local rid2; rid2=$(cat "$tmp2/.harness/runs/current-run-id")
  python3 "$M6_SCOPELOCK" --compile --plan "$tmp2/plan.md" --landmarks "$tmp2/landmarks.json" \
    --run-id "$rid2" --root "$tmp2" >/dev/null 2>&1
  "$M6_DMC" postbash-diff --scope-lock "$tmp2/.harness/runs/$rid2/scope.lock.json" \
    --snapshot "$tmp2/.harness/runs/$rid2/snapshot.txt" --root "$tmp2" >/dev/null 2>&1
  assert_eq 0 "$?" "armed: pre-existing untracked noise (in the arming snapshot) -> postbash-diff CLEAN"

  # `bin/dmc selftest m6-core` stays green under an armed fixture cwd (self-tests write only mktemp).
  ( cd "$tmp" && "$M6_DMC" selftest m6-core >/dev/null 2>&1 )
  assert_eq 0 "$?" "armed: bin/dmc selftest m6-core is green under an armed fixture cwd (mktemp-only)"
}

# ============================================================================
# Latency: the stop-path quick gate stays under 2s.
# ============================================================================
latency_row() {
  echo "  -- latency: stop-gate quick < 2s --"
  local tmp="$SANDBOX/lat" rid
  rid=$(arm_fixture "$tmp" "dmc-compat-lat") || { record FAIL "lat arm fixture"; return; }
  local elapsed
  elapsed=$(python3 - "$M6_DMC" "$tmp" <<'PY'
import subprocess, sys, time
dmc, root = sys.argv[1], sys.argv[2]
t0 = time.time()
subprocess.run([dmc, "stop-gate", "quick", "--root", root],
               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
print("%.3f" % (time.time() - t0))
PY
)
  awk -v e="$elapsed" 'BEGIN{exit !(e+0 < 2.0)}' \
    && record PASS "stop-gate quick latency ${elapsed}s < 2s budget" \
    || record FAIL "stop-gate quick latency ${elapsed}s EXCEEDS 2s budget"
}

main() {
  echo "test-compat.sh :: root=$M6_ROOT"
  m6_capture_before
  legacy_rows
  per_mode_rows
  unarmed_rows
  armed_rows
  latency_row
  echo "  -- real-repo cleanliness --"
  m6_assert_repo_untouched
  echo "  ----"
  echo "  RESULT: $PASS PASS / $FAIL FAIL"
  [ "$FAIL" -eq 0 ] && exit 0 || exit 1
}

main
