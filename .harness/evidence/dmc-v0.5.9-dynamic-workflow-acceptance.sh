#!/usr/bin/env bash
# DMC Dynamic Workflow Capstone Acceptance Suite (v0.5.9) — ADVISORY / READ-ONLY (capstone).
#
# Composes the v0.5.3–v0.5.8 Dynamic Workflow layer OFFLINE over 7 synthetic task classes and proves it selects, verifies,
# reviews, and STOPS correctly. No new enforcement hook; no live call; no repo mutation; synthetic fixtures / $TMPDIR only.
# Asserts E2E-DONE only when ALL required conditions are met, that the SMALLEST sufficient workflow is chosen (docs-only
# does not escalate without risk facts), that risk escalation is monotonic, that negative fixtures fail closed, and that
# the production repo stays byte-unchanged. Includes the mock-category fixture (provider_target=mock rejected; run_mode=mock
# allowed offline). Reads no env/.env/secret; no network.
#
# Usage: dmc-v0.5.9-dynamic-workflow-acceptance.sh [--out <file>]  |  --self-test
# Exit: 0 = all scenarios accepted, 1 = a scenario FAILED, 2 = usage.
set -u
set -o pipefail
export PYTHONDONTWRITEBYTECODE=1
SELFPATH="$(cd "$(dirname "$0")" 2>/dev/null && pwd -P)/$(basename "$0")"
ROOTDIR="$(cd "$(dirname "$SELFPATH")/../.." 2>/dev/null && pwd -P || true)"
[ -n "$ROOTDIR" ] || ROOTDIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
EV="$ROOTDIR/.harness/evidence"
T3="$EV/dmc-v0.5.3-dynamic-workflow-selector.sh"; T4="$EV/dmc-v0.5.4-workflow-state-machine.sh"
T5="$EV/dmc-v0.5.5-verification-planner.sh"; T6="$EV/dmc-v0.5.6-review-packet-v2.sh"
T7="$EV/dmc-v0.5.7-resume-recovery.sh"; T8="$EV/dmc-v0.5.8-dynamic-delegation.sh"
TOOLS="$T3 $T4 $T5 $T6 $T7 $T8"
repo_hash() { git -C "$ROOTDIR" status --porcelain 2>/dev/null | python3 -c 'import hashlib,sys; sys.stdout.write(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())'; }

self_test() {
  set +B   # disable brace expansion — JSON {"a":..,"b":..} literals must be passed verbatim, not expanded to "a b"
  local P=0 F=0; ok(){ echo "  PASS $1"; P=$((P+1)); }; no(){ echo "  FAIL $1"; F=$((F+1)); }
  local TT; TT="$(mktemp -d)" || { echo "  FATAL: mktemp -d failed"; return 2; }; [ -d "$TT" ] || { echo "  FATAL: temp dir missing"; return 2; }; trap 'rm -rf "$TT"' RETURN
  local PRE; PRE="$(repo_hash)"
  jf(){ printf '%s' "$2" > "$TT/$1.json"; echo "$TT/$1.json"; }
  sel(){ bash "$T3" --from "$(jf s "$1")" 2>/dev/null | awk -F': ' '/^- lane:/{print $2}'; }
  seff(){ bash "$T3" --from "$(jf s "$1")" 2>/dev/null | awk -F': ' '/^- min_effort:/{print $2}'; }
  selrc(){ bash "$T3" --from "$(jf s "$1")" >/dev/null 2>&1; echo $?; }
  vpln(){ bash "$T5" --from "$(jf v "$1")" 2>/dev/null; }
  smt(){ bash "$T4" --transition --from "$1" --to "$2" --facts "$(jf m "$3")" >/dev/null 2>&1; echo $?; }
  smd(){ bash "$T4" --done --facts "$(jf d "$1")" 2>/dev/null || true; }   # --done exits 1 for INVALID/IN_PROGRESS; keep stdout, drop exit (pipefail-safe)
  rra(){ bash "$T7" --from "$(jf r "$1")" 2>/dev/null | awk -F': ' '/^- next_action:/{print $2}'; }
  SAFE='"protected_surface":false,"secret_network_live":false'

  # AC0 REGRESSION — all six v0.5.3-v0.5.8 tools self-test green (compose)
  local reg=1 t; for t in $TOOLS; do bash "$t" --self-test >/dev/null 2>&1 || reg=0; done
  [ "$reg" = 1 ] && ok "AC0 REGRESSION: all six v0.5.3-v0.5.8 tools --self-test green" || no "AC0 a sub-tool self-test failed"

  # S1 docs closure — smallest sufficient: docs-only lane/light; planner docs checks; full E2E => DONE
  { [ "$(sel "{$SAFE,\"task_class\":\"docs-only\"}")" = docs-only ] && [ "$(seff "{$SAFE,\"task_class\":\"docs-only\"}")" = light ] \
    && vpln '{"lane":"docs-only","changed_paths":"docs/MILESTONES.md"}' | awk '/required_checks:/{f=1;next}/optional/{f=0}f' | grep -qi 'markdown' \
    && smd '{"verification":"PASS","release_audit":"ACCEPT","commit_present":true,"published_to_main":true,"closure_recorded":true,"closure_authorized":true,"run_id_match":true,"plan_hash_match":true,"verification_head_match":true}' | grep -q '^DONE'; } \
    && ok "S1 docs closure: docs-only/light + markdown verification + full E2E => DONE" || no "S1 docs closure"

  # S2 additive advisory tool — additive-tooling/standard; planner shell self-test
  { [ "$(sel "{$SAFE,\"task_class\":\"additive-tooling\"}")" = additive-tooling ] \
    && vpln '{"lane":"additive-tooling","changed_paths":".harness/evidence/dmc-v0.5.x-foo.sh"}' | grep -qi 'self-test'; } \
    && ok "S2 additive advisory tool: additive-tooling lane + shell self-test verification" || no "S2 additive tool"

  # S3 provider/import adapter — protected-surface/deep; planner result-validator+leak+reject+byte-unchanged; MOCK category
  { [ "$(sel "{$SAFE,\"task_class\":\"provider-adapter\"}")" = protected-surface ] && [ "$(seff "{$SAFE,\"task_class\":\"provider-adapter\"}")" = deep ] \
    && vpln '{"lane":"protected-surface","changed_paths":".claude/workers/providers/glm-api/x.py"}' | grep -qi 'result validator' \
    && [ "$(selrc "{$SAFE,\"task_class\":\"docs-only\",\"provider_target\":\"mock\"}")" = 1 ] \
    && [ "$(sel "{$SAFE,\"task_class\":\"protected-surface\",\"run_mode\":\"mock\"}")" = protected-surface ]; } \
    && ok "S3 provider adapter: protected-surface/deep + provider verification; provider_target=mock REJECTED; run_mode=mock allowed offline" || no "S3 provider/mock"

  # S4 protected-surface proposed change — protected-surface/deep + byte-unchanged check
  { [ "$(sel "{\"task_class\":\"docs-only\",\"protected_surface\":true,\"secret_network_live\":false}")" = protected-surface ] \
    && vpln '{"lane":"protected-surface","protected_surface":true,"changed_paths":"docs/x.md"}' | grep -qi 'byte-unchanged'; } \
    && ok "S4 protected-surface proposed change: protected-surface/deep + protected-path byte-unchanged check" || no "S4 protected-surface"

  # S5 failed verification recovery — resume STOP; state-machine VERIFY blocked on FAIL; after fix PASS proceeds
  { [ "$(rra '{"verification":"FAIL","ahead":1,"plan_status":"APPROVED","plan_hash_match":true}')" = STOP ] \
    && [ "$(smt VERIFY RELEASE_AUDIT '{"verification":"FAIL","verification_head_match":true}')" = 1 ] \
    && [ "$(smt VERIFY RELEASE_AUDIT '{"verification":"PASS","verification_head_match":true}')" = 0 ]; } \
    && ok "S5 failed-verification recovery: resume STOP + state-machine BLOCKED on FAIL; PASS proceeds after fix" || no "S5 recovery"

  # S6 review branch publication — COMMIT->PUSH(authorized) ALLOWED; resume => needs_human_gate candidate (not authorization)
  { [ "$(smt COMMIT PUSH '{"commit_present":true,"staged_dirty":false,"push_authorized":true}')" = 0 ] \
    && [ "$(rra '{"branch":"dmc-x","ahead":3,"behind":0,"tracked_dirty":false,"plan_status":"APPROVED","plan_hash_match":true,"verification":"PASS","commit_hash":"abc"}')" = NEEDS_HUMAN_GATE ]; } \
    && ok "S6 review-branch publication: COMMIT->PUSH allowed w/ explicit authorization; resume => needs_human_gate candidate" || no "S6 review publication"

  # S7 premature closure attempt — COMMIT->CLOSURE blocked; closure-before-publish INVALID; committed-not-published IN_PROGRESS
  { [ "$(smt COMMIT CLOSURE '{"commit_present":true,"published":true,"closure_authorized":true}')" = 1 ] \
    && smd '{"verification":"PASS","release_audit":"ACCEPT","commit_present":true,"published_to_main":false,"closure_recorded":true,"run_id_match":true,"plan_hash_match":true,"verification_head_match":true}' | grep -q '^INVALID' \
    && smd '{"verification":"PASS","release_audit":"ACCEPT","commit_present":true,"published_to_main":false,"closure_recorded":false,"run_id_match":true,"plan_hash_match":true,"verification_head_match":true}' | grep -q 'IN_PROGRESS'; } \
    && ok "S7 premature closure: COMMIT->CLOSURE BLOCKED; closure-before-publish INVALID; committed-not-published IN_PROGRESS" || no "S7 premature closure"

  # AC8 E2E-DONE only when ALL required conditions met (no false DONE)
  { smd '{"verification":"PASS","release_audit":"ACCEPT","commit_present":true,"published_to_main":true,"closure_recorded":true,"closure_authorized":true,"run_id_match":true,"plan_hash_match":true,"verification_head_match":true}' | grep -q '^DONE' \
    && ! smd '{"verification":"PASS","release_audit":"ACCEPT","commit_present":true,"published_to_main":true,"closure_recorded":false,"run_id_match":true,"plan_hash_match":true,"verification_head_match":true}' | grep -q '^DONE'; } \
    && ok "AC8 E2E-DONE only when all conditions met; a missing condition => not DONE" || no "AC8 false DONE"

  # AC9 smallest sufficient + monotonic — docs-only does NOT escalate; adding a risk fact raises the lane
  local li_docs li_prot
  li_docs="$(sel "{$SAFE,\"task_class\":\"docs-only\"}")"; li_prot="$(sel '{"task_class":"docs-only","protected_surface":true,"secret_network_live":false}')"
  { [ "$li_docs" = docs-only ] && [ "$li_prot" = protected-surface ]; } \
    && ok "AC9 smallest sufficient (docs-only stays docs-only) + monotonic (adding a risk fact escalates the lane)" || no "AC9 escalation/monotonicity"

  # AC10 negative fixtures fail CLOSED — unknown task_class => max; missing danger fact => max
  { [ "$(sel "{$SAFE,\"task_class\":\"frobnicate\"}")" = secret-network-live-risk ] \
    && [ "$(sel '{"task_class":"docs-only"}')" = secret-network-live-risk ]; } \
    && ok "AC10 negative fixtures fail CLOSED: unknown task_class / missing danger fact => secret-network-live-risk" || no "AC10 fail-open"

  # AC11 structural audit (capstone source: no net/env/env-hash/live)
  local OP; OP="$(sed '/AUDIT_BLOCK_START/,/AUDIT_BLOCK_END/d' "$SELFPATH" | grep -vE '^[[:space:]]*#')"
  # >>>AUDIT_BLOCK_START
  ! printf '%s' "$OP" | grep -nE '(^|[^A-Za-z])(curl|wget)([[:space:]])| --live | --allow-network|os\.environ|getenv|printenv|HASH_CMD|\$\{DMC_' >/dev/null \
    && ok "AC11 no net/env-read/env-hash/live in capstone operative source" || no "AC11 net/env present"
  # >>>AUDIT_BLOCK_END
  # AC12 env-hash injection
  # >>>AUDIT_BLOCK_START  (hostile-input test; excluded from the operative-source audit)
  local SENT="$TT/sentinel" FAKE="$TT/fakehash"; printf '#!/bin/sh\ntouch "%s"\necho PWNED\n' "$SENT" > "$FAKE"; chmod +x "$FAKE"
  local hb hh; hb="$(repo_hash)"; hh="$(DMC_HASH_CMD="$FAKE" repo_hash)"
  { [ ! -e "$SENT" ] && [ -n "$hb" ] && [ "$hb" = "$hh" ]; } && ok "AC12 env-hash injection: hostile DMC_HASH_CMD never read/executed" || no "AC12 env-controlled hash executed"
  # >>>AUDIT_BLOCK_END
  # AC13 no protected-surface mutation + production repo byte-unchanged
  local protdiff; protdiff="$(git -C "$ROOTDIR" status --porcelain -- .claude .harness/schemas 2>/dev/null | grep -vE '^\?\?' | wc -l | tr -d ' ')"
  { [ "$protdiff" = 0 ] && [ -n "$PRE" ] && [ "$(repo_hash)" = "$PRE" ]; } \
    && ok "AC13 no protected-surface mutation; production repo byte-unchanged after full compose" || no "AC13 repo/protected changed"

  echo "  ---- self-test: PASS=$P FAIL=$F ----"; [ "$F" = 0 ]
}

OUT=""; RUN=run
while [ $# -gt 0 ]; do case "$1" in --out) OUT="$2"; shift 2;; --self-test) RUN=selftest; shift;; -h|--help) sed -n '2,12p' "$0"; exit 0;; *) echo "acceptance: unknown arg $1" >&2; exit 2;; esac; done
if [ "$RUN" = selftest ]; then echo "==== DMC DYNAMIC WORKFLOW CAPSTONE — ACCEPTANCE SUITE ===="; self_test; exit $?; fi
echo "dynamic-workflow-acceptance: use --self-test (this capstone IS the acceptance suite)" >&2; exit 2
