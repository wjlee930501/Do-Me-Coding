#!/usr/bin/env bash
# test-e2e-loop.sh — DMC v1 M9 whole-loop E2E on a committed host-shaped fixture (master §M9).
#
# Nature: END-TO-END. On a COPIED DMC surface with tests/fixtures/host-node overlaid into a mktemp
# repo, it drives the ENTIRE v1 loop exactly as a real session would:
#   orient -> landmarks -> plan (APPROVED) -> synthetic critic verdict (APPROVE, plan-bound) ->
#   `dmc verdict gate --plan-hash` PASS -> `dmc run start` -> scope-lock compile -> EXECUTE (one
#   benign in-scope edit) -> ONE DENIED ATTEMPT PER CANONICAL-FIVE CLASS (value-blind) ->
#   acceptance/verify-plan materialized + receipts minted -> ONE fix-loop attempt -> `dmc run
#   suspend` -> stop-gate quick PASS (suspended) -> `dmc run resume` -> verification report written
#   (validates) + release approval -> `git add` the scoped modified/new set (AA3) -> `dmc gate
#   release --full` PASS -> the human-gate record (the release approval) asserted present+validated
#   -> LATENCY rows: `dmc stop-gate quick` AND `dmc gate release --quick` both measured < 2s.
#
# The five denials mirror the shipped negative controls, each asserted VALUE-BLIND (verdict / exit
# code only, never the fixture value): (1) bash out-of-scope deny (pre-tool-guard), (2) scope.lock
# self-edit deny (scope-guard), (3) secret-glob deny (secret-guard), (4) JWT worker-result REJECT,
# (5) rename-diff-to-forbidden worker-result REJECT.
#
# Never reads .env / credentials; never mutates the live repo (proven by a porcelain-before/after
# check); no network / live / model / API call. Self-set git identity.
#
# Usage: test-e2e-loop.sh   Run the loop, print RESULT + summary, exit 0/1.

set -u

SELF_DIR=$(cd -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd -P) || { echo "FATAL: script dir"; exit 2; }
# shellcheck source=_m9common.sh
. "$SELF_DIR/_m9common.sh"

if ! git -C "$M9_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "FATAL: repo root is not a git worktree: $M9_ROOT"; exit 2
fi

SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/dmc-m9-e2e.XXXXXX") || { echo "FATAL: mktemp"; exit 2; }
cleanup() { rm -rf "$SANDBOX"; m9_cleanup; }
trap cleanup EXIT

KIT="$SANDBOX/m9kit.py"
m9_write_kit "$KIT"

REPO="$SANDBOX/repo"

# ---- the five canonical denied attempts (each value-blind: verdict/exit only) --
denied_five() {
  local rid="$1" lock="$REPO/.harness/runs/$rid/scope.lock.json"

  # (1) Bash write OUTSIDE the locked scope -> armed pre-tool-guard DENY.
  local d
  d=$(decision_of "$(hook_run pre-tool-guard.sh "$(bash_input 'echo stray > outofscope.py')" "$REPO")")
  assert_eq deny "$d" "denial (1) bash out-of-scope write DENIED (pre-tool-guard, armed)"

  # (2) Edit of the run's OWN scope.lock.json -> scope-guard DENY.
  d=$(decision_of "$(hook_run scope-guard.sh "$(edit_input "$lock" "$REPO")" "$REPO")")
  assert_eq deny "$d" "denial (2) scope.lock self-edit DENIED (scope-guard)"

  # (3) Glob pattern targeting .env* -> secret-guard DENY (path-only, opens nothing).
  d=$(decision_of "$(hook_run secret-guard.sh "$(glob_input '**/.env*')" "$REPO")")
  assert_eq deny "$d" "denial (3) secret-glob '**/.env*' DENIED (secret-guard)"

  # (4) Worker result carrying SYNTHETIC token material -> worker-result-check REJECT (value-blind).
  local task="$SANDBOX/den-task.json" result="$SANDBOX/den-result.json"
  python3 "$KIT" wtask "$task" "m9-e2e-den" "src/util.js"
  python3 "$KIT" wresult "$result" "m9-e2e-den" "src/util.js" jwt
  python3 "$REPO/.claude/hooks/worker-result-check.py" "$task" "$result" >/dev/null 2>&1
  assert_eq 1 "$?" "denial (4) JWT-in-result worker-result REJECTED (value-blind, exit 1)"

  # (5) Rename diff onto a FORBIDDEN path -> worker-result-check REJECT.
  python3 "$KIT" wresult "$result" "m9-e2e-den" "src/util.js" "" rename-forbidden
  python3 "$REPO/.claude/hooks/worker-result-check.py" "$task" "$result" >/dev/null 2>&1
  assert_eq 1 "$?" "denial (5) rename-to-forbidden worker-result REJECTED (exit 1)"
}

e2e() {
  echo "  -- whole-loop E2E on the host-node fixture (single-path scope) --"
  local run_dir rid ph rc t0 t1

  # ---- orient -> landmarks -> plan (setup writes plan + APPROVED landmarks; baseline committed) ----
  m9_setup_repo "$REPO" single
  [ -x "$REPO/bin/dmc" ] && record PASS "surface copy: copied bin/dmc present + executable" \
                         || { record FAIL "surface copy: bin/dmc missing"; return; }
  mkdir -p "$REPO/.harness"
  "$REPO/bin/dmc" orient --root "$REPO" --out "$REPO/.harness/orientation.json" >/dev/null 2>&1
  { [ "$?" -eq 0 ] && [ -f "$REPO/.harness/orientation.json" ]; } \
    && record PASS "orient: dmc orient --root --out wrote orientation.json" \
    || record FAIL "orient: dmc orient --root --out failed"
  "$REPO/bin/dmc" landmarks --root "$REPO" --out "$REPO/.harness/landmarks.map.json" >/dev/null 2>&1
  { [ "$?" -eq 0 ] && [ -f "$REPO/.harness/landmarks.map.json" ]; } \
    && record PASS "landmarks: dmc landmarks --root --out wrote the landmark map" \
    || record FAIL "landmarks: dmc landmarks --root --out failed"

  # ---- synthetic critic verdict (APPROVE, plan-bound) -> verdict gate PASS ----
  mkdir -p "$REPO/.harness/evidence"
  ph=$(python3 "$KIT" verdict "$REPO/.harness/evidence/verdict.json" "$REPO" "$REPO/plan.md" APPROVE)
  "$REPO/bin/dmc" verdict gate --verdict "$REPO/.harness/evidence/verdict.json" --plan-hash "$ph" >/dev/null 2>&1
  assert_eq 0 "$?" "verdict gate: a schema-valid, plan-bound APPROVE PASSES (C11 pass-through)"

  # ---- run start -> scope-lock compile (real Ring-0 arming; the APPROVE verdict clears the floor) ----
  "$REPO/bin/dmc" run start --plan "$REPO/plan.md" --root "$REPO" >/dev/null 2>&1
  rid=$(cat "$REPO/.harness/runs/current-run-id" 2>/dev/null)
  [ -n "$rid" ] && record PASS "run start: minted run '$rid' (RUNNING)" \
                || { record FAIL "run start: did not arm"; return; }
  python3 "$REPO/bin/lib/dmc-scope-lock.py" --compile --plan "$REPO/plan.md" \
    --landmarks "$REPO/landmarks.json" --run-id "$rid" --root "$REPO" >/dev/null 2>&1
  run_dir="$REPO/.harness/runs/$rid"
  [ -f "$run_dir/scope.lock.json" ] \
    && record PASS "scope-lock compile: immutable scope.lock.json + operative snapshot pinned" \
    || { record FAIL "scope-lock compile failed"; return; }

  # ---- EXECUTE: one benign in-scope edit (src/util.js == the single scope.lock path, AA3) ----
  printf '"use strict";\nmodule.exports = { greet: function (n) { return "hi " + n; } };\n' \
    > "$REPO/src/util.js"
  record PASS "execute: one benign in-scope edit applied to src/util.js"

  # ---- ONE DENIED ATTEMPT PER CANONICAL-FIVE CLASS (value-blind) ----
  denied_five "$rid"

  # ---- acceptance/verify-plan materialized + receipts minted (AA4 five-type-set + resolvable ref) ----
  python3 "$KIT" verify-plan "$run_dir/verify-plan.json" "src/util.js" "CHK-A"
  python3 "$KIT" findings "$run_dir/findings.json"
  python3 "$KIT" goal "$run_dir/goal-ledger.json"
  python3 "$KIT" decision "$run_dir/decision-record.json"
  local h40="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  python3 "$REPO/bin/lib/dmc-evidence-ledger.py" mint --root "$REPO" --run-id "$rid" \
    --check-id CHK-A --evidence-type test-result --artifact-ref ver/report.md \
    --work-id W --plan-hash "$h40" --repo-hash "$h40" --verification-ref ver/report.md >/dev/null 2>&1
  assert_eq 0 "$?" "receipts: mint CHK-A (evidence-type test-result, resolvable verification-ref)"

  # ---- ONE fix-loop attempt (attempt 1 <= bound) ----
  python3 "$REPO/bin/lib/dmc-fixloop.py" append --root "$REPO" --run-id "$rid" \
    --check-id CHK-A --bound 3 --hypothesis "retry once" --files-touched src/util.js >/dev/null 2>&1
  assert_eq 0 "$?" "fix-loop: attempt 1 append (<= bound 3) ACCEPTED"

  # ---- suspend -> stop-gate quick PASS (the designed escape hatch) ----
  "$REPO/bin/dmc" run suspend --root "$REPO" >/dev/null 2>&1
  assert_eq 0 "$?" "suspend: RUNNING -> SUSPENDED"
  "$REPO/bin/dmc" stop-gate quick --root "$REPO" >/dev/null 2>&1
  assert_eq 0 "$?" "stop-gate quick: a SUSPENDED run PASSES (exit 0)"

  # ---- resume -> verification report written (validates) + release approval ----
  "$REPO/bin/dmc" run resume --root "$REPO" >/dev/null 2>&1
  assert_eq 0 "$?" "resume: SUSPENDED -> RUNNING"
  python3 "$KIT" verif "$REPO/.harness/verification/rep.md"
  "$REPO/bin/dmc" validate verification "$REPO/.harness/verification/rep.md" >/dev/null 2>&1
  assert_eq 0 "$?" "verification report validates (dmc validate verification, exit 0)"
  python3 "$REPO/bin/lib/dmc-approvals.py" append --root "$REPO" --run-id "$rid" \
    --gate-kind plan_approval --auth-id wjlee >/dev/null 2>&1
  python3 "$REPO/bin/lib/dmc-approvals.py" append --root "$REPO" --run-id "$rid" \
    --gate-kind release --auth-id wjlee --verification-ref .harness/verification/rep.md >/dev/null 2>&1
  assert_eq 0 "$?" "human-gate: release approval appended (verification_ref -> the VALID report)"

  # ---- git add the scoped modified/new set (AA3: staged set == scope.lock files[]) ----
  git -C "$REPO" add src/util.js

  # ---- dmc gate release --full ⇒ PASS ----
  m9_gate_full_json "$REPO" "$rid"
  assert_eq 0 "$M9_GATE_RC" "gate release --full: exit 0"
  assert_eq PASS "$(m9_overall "$M9_GATE_JSON")" "gate release --full: overall verdict PASS"
  local n
  for n in diff-scope gate-checks receipts findings goal decision approvals chain landmark-flag; do
    assert_ne FAIL "$(m9_subverdict "$M9_GATE_JSON" "$n")" "gate: sub-gate $n not FAIL"
  done

  # ---- human-gate record: the release approval is present + the ledger validates ----
  python3 "$REPO/bin/lib/dmc-approvals.py" --validate "$run_dir/approvals.jsonl" >/dev/null 2>&1
  assert_eq 0 "$?" "human-gate record: approvals.jsonl validates (typed ledger, chain intact)"
  local hasrel; hasrel=$(python3 -c 'import json,sys
n=0
for line in open(sys.argv[1], encoding="utf-8"):
    line=line.strip()
    if not line: continue
    try:
        if json.loads(line).get("gate_kind")=="release": n+=1
    except Exception: pass
print(n)' "$run_dir/approvals.jsonl")
  assert_ne 0 "$hasrel" "human-gate record: a release approval is present in the ledger"

  # ---- LATENCY rows: stop-gate quick AND gate release --quick both measured < 2s ----
  t0=$(python3 -c 'import time; print(time.time())')
  "$REPO/bin/dmc" stop-gate quick --root "$REPO" >/dev/null 2>&1; rc=$?
  t1=$(python3 -c 'import time; print(time.time())')
  assert_lt "$(awk "BEGIN{print $t1-$t0}")" 2.0 "latency: dmc stop-gate quick < 2s (rc=$rc)"

  t0=$(python3 -c 'import time; print(time.time())')
  "$REPO/bin/dmc" gate release --quick --run-id "$rid" --root "$REPO" >/dev/null 2>&1; rc=$?
  t1=$(python3 -c 'import time; print(time.time())')
  assert_lt "$(awk "BEGIN{print $t1-$t0}")" 2.0 "latency: dmc gate release --quick < 2s (rc=$rc)"
}

main() {
  echo "test-e2e-loop.sh :: root=$M9_ROOT"
  m9_capture_before
  e2e
  echo "  -- real-repo cleanliness --"
  m9_assert_repo_untouched
  echo "  ----"
  echo "  RESULT: $PASS PASS / $FAIL FAIL"
  [ "$FAIL" -eq 0 ] && exit 0 || exit 1
}

main
