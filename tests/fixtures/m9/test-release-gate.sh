#!/usr/bin/env bash
# test-release-gate.sh — DMC v1 M9 P18 release-gate composition controls (master §M9 acceptance).
#
# Nature: END-TO-END/adversarial. It arms disposable host-node-shaped repos through the REAL Ring-0
# path on a COPIED DMC surface (so every composed sub-gate tool resolves its own root to the
# sandbox), materializes a fully-green release run, and asserts `dmc gate release --full` ⇒ verdict
# PASS exit 0 with all NINE P18 sub-gates PASS and the readiness JSON conforming to
# dmc.release-readiness.v1. It then drives SEEDED-GAP rows g1-g12 — each on a fresh armed copy — that
# each FAIL their OWN sub-gate (or the disclosed MISSING/REFUSE tier), plus the `--quick` alias rows
# with a measured <2s latency budget.
#
# AA3 (human-gate directive): the green path stages EXACTLY the scope.lock files[] set (v0.2.6 G2 is
# cached-diff), so files[] == the modified/new set. AA4: every `dmc-evidence-ledger.py mint` uses an
# --evidence-type in the five-type set with a resolvable --verification-ref.
#
# Value-blind: the class-4 token fixture is SYNTHETIC (concatenated, never a real credential) and is
# never echoed by an assertion. Never reads .env / credentials; never mutates the live repo (proven
# by a porcelain-before/after check); no network / live / model / API call.
#
# Usage: test-release-gate.sh   Run all checks, print RESULT + summary, exit 0/1.

set -u

SELF_DIR=$(cd -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd -P) || { echo "FATAL: script dir"; exit 2; }
# shellcheck source=_m9common.sh
. "$SELF_DIR/_m9common.sh"

if ! git -C "$M9_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "FATAL: repo root is not a git worktree: $M9_ROOT"; exit 2
fi

SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/dmc-m9-gate.XXXXXX") || { echo "FATAL: mktemp"; exit 2; }
cleanup() { rm -rf "$SANDBOX"; m9_cleanup; }
trap cleanup EXIT

KIT="$SANDBOX/m9kit.py"
m9_write_kit "$KIT"

# ---- shared benign in-scope edit + stage (ordinary profile) --------------------
# Edits EXACTLY the two ordinary scope.lock paths (AA3) with whitespace-clean content and stages
# them, so gate-checks G1 (staged ⊆ allowlist) + G2 (allowlist fully staged) + G5 (whitespace) pass.
m9_edit_and_stage_ordinary() { # REPO
  local repo="$1"
  printf '"use strict";\nconsole.log("edited index");\n' > "$repo/src/index.js"
  printf '"use strict";\nmodule.exports = { greet: function (n) { return "hi " + n; } };\n' > "$repo/src/util.js"
  git -C "$repo" add src/index.js src/util.js
}

# m9_green_base REPO -> echoes RID. Fresh armed ordinary repo + all-PASS base artifacts (no worker
# chain: chain PASSES with the no-activity note) + the benign in-scope edit staged. Overall PASS.
m9_green_base() {
  local repo="$1" rid
  rid=$(m9_setup_arm "$repo" ordinary) || return 1
  m9_base_artifacts "$repo" "$rid" "$KIT"
  m9_edit_and_stage_ordinary "$repo"
  printf '%s' "$rid"
}

# ============================================================================
# GREEN PATH — a fully-materialized release run (WITH a verified worker apply chain).
# ============================================================================
case_green() {
  echo "  -- green path: fully-materialized release run -> PASS, 9/9 sub-gates --"
  local repo="$SANDBOX/green" rid
  rid=$(m9_setup_arm "$repo" ordinary) || { record FAIL "green arm"; return; }
  m9_base_artifacts "$repo" "$rid" "$KIT"
  m9_add_worker_chain "$repo" "$rid" "$KIT" "m9-green-001"
  m9_edit_and_stage_ordinary "$repo"

  m9_gate_full_json "$repo" "$rid"
  assert_eq 0 "$M9_GATE_RC" "green: dmc gate release --full exit 0"
  assert_eq PASS "$(m9_overall "$M9_GATE_JSON")" "green: overall verdict PASS"

  local ok; ok=$(printf '%s' "$M9_GATE_JSON" | python3 -c 'import json,sys
want={"diff-scope","gate-checks","receipts","findings","goal","decision","approvals","chain","landmark-flag"}
try:
    d=json.load(sys.stdin)
    print("yes" if d.get("schema")=="dmc.release-readiness.v1" and d.get("run_id") and set(d.get("sub_gates",{}))==want else "no")
except Exception:
    print("no")')
  assert_eq yes "$ok" "green: readiness conforms to dmc.release-readiness.v1 (run_id + 9 named sub_gates)"

  local n
  for n in diff-scope gate-checks receipts findings goal decision approvals chain; do
    assert_eq PASS "$(m9_subverdict "$M9_GATE_JSON" "$n")" "green: sub-gate $n PASS"
  done
  assert_eq PASS "$(m9_subverdict "$M9_GATE_JSON" landmark-flag)" "green: landmark-flag PASS (no non-ordinary change)"

  local flags; flags=$(printf '%s' "$M9_GATE_JSON" \
    | python3 -c 'import json,sys
try: print(len(json.load(sys.stdin).get("flags",[])))
except Exception: print(-1)')
  assert_eq 0 "$flags" "green: landmark flags[] empty"
  assert_contains "$(m9_reasons_of "$M9_GATE_JSON" chain)" "CHAIN-PASS" \
    "green: chain PASS via a verified delegation/apply chain (worker activity present)"
}

# ============================================================================
# SEEDED GAPS g1-g12 — each on a fresh armed copy, each FAILing its OWN sub-gate
# (or the disclosed MISSING/REFUSE/PASS-with-note tier).
# ============================================================================

# g1 out-of-scope new_change -> diff-scope FAIL naming the path.
case_g1() {
  echo "  -- g1 out-of-scope new change -> diff-scope FAIL --"
  local repo="$SANDBOX/g1" rid; rid=$(m9_green_base "$repo") || { record FAIL "g1 base"; return; }
  printf 'var x = 1;\n' > "$repo/src/evil.js"     # untracked, NOT in scope, NOT staged
  m9_gate_full_json "$repo" "$rid"
  assert_eq FAIL "$(m9_subverdict "$M9_GATE_JSON" diff-scope)" "g1 diff-scope FAIL"
  assert_contains "$(m9_reasons_of "$M9_GATE_JSON" diff-scope)" "src/evil.js" "g1 diff-scope names src/evil.js"
  assert_eq FAIL "$(m9_overall "$M9_GATE_JSON")" "g1 overall FAIL"
  assert_eq 1 "$M9_GATE_RC" "g1 exit 1"
}

# g2 staged excluded-evidence auto-log -> gate-checks FAIL (candidate staging violation).
case_g2() {
  echo "  -- g2 staged excluded-evidence -> gate-checks FAIL --"
  local repo="$SANDBOX/g2" rid; rid=$(m9_green_base "$repo") || { record FAIL "g2 base"; return; }
  mkdir -p "$repo/.harness/evidence"
  printf '# seeded auto-log\n' > "$repo/.harness/evidence/dmc-v0.9.9-seeded.md"
  git -C "$repo" add -f .harness/evidence/dmc-v0.9.9-seeded.md   # .harness is git-ignored; force-stage
  m9_gate_full_json "$repo" "$rid"
  assert_eq FAIL "$(m9_subverdict "$M9_GATE_JSON" gate-checks)" "g2 gate-checks FAIL"
  assert_eq PASS "$(m9_subverdict "$M9_GATE_JSON" diff-scope)" "g2 diff-scope still PASS (evidence path is exempt)"
  assert_eq FAIL "$(m9_overall "$M9_GATE_JSON")" "g2 overall FAIL"
}

# g3 one uncovered required check_id -> receipts FAIL.
case_g3() {
  echo "  -- g3 uncovered check_id -> receipts FAIL --"
  local repo="$SANDBOX/g3" rid; rid=$(m9_green_base "$repo") || { record FAIL "g3 base"; return; }
  python3 "$KIT" verify-plan "$repo/.harness/runs/$rid/verify-plan.json" "src/index.js" "CHK-A" "CHK-B"
  m9_gate_full_json "$repo" "$rid"
  assert_eq FAIL "$(m9_subverdict "$M9_GATE_JSON" receipts)" "g3 receipts FAIL"
  assert_contains "$(m9_reasons_of "$M9_GATE_JSON" receipts)" "UNCOVERED" "g3 receipts reason names UNCOVERED"
  assert_eq FAIL "$(m9_overall "$M9_GATE_JSON")" "g3 overall FAIL"
}

# g4 an open (blocked) finding -> findings FAIL.
case_g4() {
  echo "  -- g4 open finding -> findings FAIL --"
  local repo="$SANDBOX/g4" rid; rid=$(m9_green_base "$repo") || { record FAIL "g4 base"; return; }
  python3 "$KIT" findings "$repo/.harness/runs/$rid/findings.json" blocked
  m9_gate_full_json "$repo" "$rid"
  assert_eq FAIL "$(m9_subverdict "$M9_GATE_JSON" findings)" "g4 findings FAIL"
  assert_eq FAIL "$(m9_overall "$M9_GATE_JSON")" "g4 overall FAIL"
}

# g5 completion without an approved goal -> goal FAIL.
case_g5() {
  echo "  -- g5 completion without approved goal -> goal FAIL --"
  local repo="$SANDBOX/g5" rid; rid=$(m9_green_base "$repo") || { record FAIL "g5 base"; return; }
  python3 "$KIT" goal "$repo/.harness/runs/$rid/goal-ledger.json" broken
  m9_gate_full_json "$repo" "$rid"
  assert_eq FAIL "$(m9_subverdict "$M9_GATE_JSON" goal)" "g5 goal FAIL"
  assert_eq FAIL "$(m9_overall "$M9_GATE_JSON")" "g5 overall FAIL"
}

# g6 unresolvable decision link -> decision FAIL.
case_g6() {
  echo "  -- g6 unresolvable decision link -> decision FAIL --"
  local repo="$SANDBOX/g6" rid; rid=$(m9_green_base "$repo") || { record FAIL "g6 base"; return; }
  python3 "$KIT" decision "$repo/.harness/runs/$rid/decision-record.json" broken
  m9_gate_full_json "$repo" "$rid"
  assert_eq FAIL "$(m9_subverdict "$M9_GATE_JSON" decision)" "g6 decision FAIL"
  assert_eq FAIL "$(m9_overall "$M9_GATE_JSON")" "g6 overall FAIL"
}

# g7 release approval verification_ref -> nonexistent file -> approvals FAIL (CF2 teeth).
case_g7() {
  echo "  -- g7 unresolvable release verification_ref -> approvals FAIL (CF2) --"
  local repo="$SANDBOX/g7" rid; rid=$(m9_green_base "$repo") || { record FAIL "g7 base"; return; }
  python3 "$repo/bin/lib/dmc-approvals.py" append --root "$repo" --run-id "$rid" \
    --gate-kind release --auth-id wjlee --verification-ref .harness/verification/ghost.md >/dev/null 2>&1
  m9_gate_full_json "$repo" "$rid"
  assert_eq FAIL "$(m9_subverdict "$M9_GATE_JSON" approvals)" "g7 approvals FAIL"
  assert_contains "$(m9_reasons_of "$M9_GATE_JSON" approvals)" "VERIFICATION-REF-UNRESOLVED" \
    "g7 approvals reason is RGATE-VERIFICATION-REF-UNRESOLVED"
  assert_eq FAIL "$(m9_overall "$M9_GATE_JSON")" "g7 overall FAIL"
}

# g8 worker-apply activity: tampered delegations chain -> chain FAIL, AND an authorization whose
# chain members are gone -> chain FAIL (apply without a chain refused at release).
case_g8() {
  echo "  -- g8 worker-apply chain FAIL (tampered delegation + missing chain member) --"
  # (a) tampered delegations chain -> `dmc delegation check` DELEG-CHAIN-BREAK -> chain FAIL.
  local repo="$SANDBOX/g8a" rid; rid=$(m9_green_base "$repo") || { record FAIL "g8a base"; return; }
  m9_add_worker_chain "$repo" "$rid" "$KIT" "m9-g8a-001"
  # append a second, non-chained record (wrong prev_hash) directly (bypassing the append guard).
  python3 - "$repo/.harness/runs/$rid/delegations.jsonl" <<'PY'
import json, sys
rec = {"schema": "dmc.delegation.v1", "work_id": "m9-deleg-work", "plan_hash": "a" * 16,
       "repo_hash": "b" * 16, "delegation_id": "deleg-break", "role": "verifier",
       "capability_class": "deterministic-tool", "may_mutate": False, "depth": 0, "max_depth": 3,
       "artifact_ref": None, "artifact_schema": None, "validation_verdict": "PENDING",
       "prev_hash": "f" * 64}
with open(sys.argv[1], "a", encoding="utf-8") as f:
    f.write(json.dumps(rec, sort_keys=True, separators=(",", ":")) + "\n")
PY
  m9_gate_full_json "$repo" "$rid"
  assert_eq FAIL "$(m9_subverdict "$M9_GATE_JSON" chain)" "g8a tampered delegations chain -> chain FAIL"
  assert_contains "$(m9_reasons_of "$M9_GATE_JSON" chain)" "DELEG" "g8a chain reason surfaces a DELEG chain break"
  assert_eq FAIL "$(m9_overall "$M9_GATE_JSON")" "g8a overall FAIL"

  # (b) authorization present but its task/result/review members deleted -> apply-without-a-chain.
  local repo2="$SANDBOX/g8b" rid2; rid2=$(m9_green_base "$repo2") || { record FAIL "g8b base"; return; }
  m9_add_worker_chain "$repo2" "$rid2" "$KIT" "m9-g8b-001"
  rm -f "$repo2/.harness/workers/tasks/m9-g8b-001.json"   # chain member gone; authorization remains
  m9_gate_full_json "$repo2" "$rid2"
  assert_eq FAIL "$(m9_subverdict "$M9_GATE_JSON" chain)" "g8b authorization without chain members -> chain FAIL"
  assert_contains "$(m9_reasons_of "$M9_GATE_JSON" chain)" "MEMBER-MISSING" \
    "g8b chain reason is RGATE-CHAIN-MEMBER-MISSING (apply without a chain refused)"

  # direct WAUTH-MISSING-AUTH floor (the M7 apply gate): apply-check on a deleted authorization.
  rm -f "$repo2/.harness/workers/authorizations/m9-g8b-001.json"
  "$repo2/bin/dmc" worker apply-check --auth "$repo2/.harness/workers/authorizations/m9-g8b-001.json" \
    --task /dev/null --result /dev/null --review /dev/null >/dev/null 2>&1
  assert_eq 3 "$?" "g8c direct apply-check on a MISSING authorization REFUSED (WAUTH-MISSING-AUTH floor)"
}

# g9 new_change on an enforcement/contract-class landmark -> FLAG fires, verdict STAYS PASS.
case_g9() {
  echo "  -- g9 landmark-flag fires without failing the verdict --"
  local repo="$SANDBOX/g9" rid; rid=$(m9_setup_arm "$repo" contract) || { record FAIL "g9 arm"; return; }
  m9_base_artifacts "$repo" "$rid" "$KIT"
  # in-scope change to the ordinary src + create the CONTRACT landmark (config.schema.md); stage both
  printf '"use strict";\nconsole.log("edited index");\n' > "$repo/src/index.js"
  printf '# contract\n' > "$repo/config.schema.md"
  git -C "$repo" add src/index.js config.schema.md
  m9_gate_full_json "$repo" "$rid"
  assert_eq FLAG "$(m9_subverdict "$M9_GATE_JSON" landmark-flag)" "g9 landmark-flag FLAG"
  assert_contains "$(m9_reasons_of "$M9_GATE_JSON" landmark-flag)" "config.schema.md" \
    "g9 landmark-flag names config.schema.md"
  assert_eq PASS "$(m9_overall "$M9_GATE_JSON")" "g9 overall verdict STAYS PASS (flag != fail)"
  assert_eq 0 "$M9_GATE_RC" "g9 exit 0 (FLAG never degrades the verdict)"
}

# g10 MISSING input (findings.json removed) -> overall PARTIAL exit 1 (never presented as PASS).
case_g10() {
  echo "  -- g10 MISSING input -> PARTIAL exit 1 --"
  local repo="$SANDBOX/g10" rid; rid=$(m9_green_base "$repo") || { record FAIL "g10 base"; return; }
  rm -f "$repo/.harness/runs/$rid/findings.json"
  m9_gate_full_json "$repo" "$rid"
  assert_eq MISSING "$(m9_subverdict "$M9_GATE_JSON" findings)" "g10 findings MISSING"
  assert_eq PARTIAL "$(m9_overall "$M9_GATE_JSON")" "g10 overall PARTIAL (never PASS)"
  assert_eq 1 "$M9_GATE_RC" "g10 exit 1"
}

# g11 tampered run.json -> structural REFUSE exit 3 (no readiness emitted).
case_g11() {
  echo "  -- g11 tampered run state -> structural REFUSE exit 3 --"
  local repo="$SANDBOX/g11" rid; rid=$(m9_green_base "$repo") || { record FAIL "g11 base"; return; }
  printf '\n#tamper\n' >> "$repo/.harness/runs/$rid/run.json"
  m9_gate_full_capture "$repo" "$rid"
  assert_eq 3 "$M9_GATE_RC" "g11 structural REFUSE exit 3"
  assert_contains "$M9_GATE_OUT" "REFUSED" "g11 prints a REFUSED verdict"
  assert_contains "$M9_GATE_OUT" "RUN-STATE-INVALID" "g11 reason is RGATE-RUN-STATE-INVALID"
}

# g12 no-worker-activity run -> chain PASS with the disclosed note (the predicate row).
case_g12() {
  echo "  -- g12 no-worker-activity -> chain PASS-with-note --"
  local repo="$SANDBOX/g12" rid; rid=$(m9_green_base "$repo") || { record FAIL "g12 base"; return; }
  m9_gate_full_json "$repo" "$rid"
  assert_eq PASS "$(m9_subverdict "$M9_GATE_JSON" chain)" "g12 chain PASS (no delegated/worker applies)"
  assert_contains "$(m9_reasons_of "$M9_GATE_JSON" chain)" "NO-ACTIVITY" "g12 chain carries the NO-ACTIVITY note"
  assert_eq PASS "$(m9_overall "$M9_GATE_JSON")" "g12 overall PASS"
}

# ============================================================================
# --quick alias tier: a faithful stop-gate alias (0 PASS / 4 HOLD -> 0 / 1) with a <2s budget.
# ============================================================================
case_quick_alias() {
  echo "  -- --quick alias rows (faithful stop-gate mapping + <2s latency) --"
  local repo="$SANDBOX/quick" rid; rid=$(m9_setup_arm "$repo" ordinary) || { record FAIL "quick arm"; return; }
  local run_dir="$repo/.harness/runs/$rid"

  # HELD: a RUNNING run with a blocked sidecar -> stop-gate HOLD(4) normalized to exit 1.
  printf '{"reason":"out-of-scope write","paths":["x"]}' > "$run_dir/blocked.json"
  "$repo/bin/dmc" gate release --quick --run-id "$rid" --root "$repo" >/dev/null 2>&1
  assert_eq 1 "$?" "alias: --quick over a blocked RUNNING run -> HOLD normalized to exit 1"
  rm -f "$run_dir/blocked.json"

  # PASS: a SUSPENDED run -> stop-gate PASS(0) normalized to exit 0; latency measured < 2s.
  "$repo/bin/dmc" run suspend --root "$repo" >/dev/null 2>&1
  local t0 t1 rc
  t0=$(python3 -c 'import time; print(time.time())')
  "$repo/bin/dmc" gate release --quick --run-id "$rid" --root "$repo" >/dev/null 2>&1; rc=$?
  t1=$(python3 -c 'import time; print(time.time())')
  assert_eq 0 "$rc" "alias: --quick over a SUSPENDED run -> PASS normalized to exit 0"
  assert_lt "$(awk "BEGIN{print $t1-$t0}")" 2.0 "alias: --quick latency budget"
}

main() {
  echo "test-release-gate.sh :: root=$M9_ROOT"
  m9_capture_before
  case_green
  case_g1; case_g2; case_g3; case_g4; case_g5; case_g6; case_g7; case_g8
  case_g9; case_g10; case_g11; case_g12
  case_quick_alias
  echo "  -- real-repo cleanliness --"
  m9_assert_repo_untouched
  echo "  ----"
  echo "  RESULT: $PASS PASS / $FAIL FAIL"
  [ "$FAIL" -eq 0 ] && exit 0 || exit 1
}

main
