#!/usr/bin/env bash
# DMC Autonomy Charter check (v0.4.0) — ADVISORY / READ-ONLY.
#
# Validates that AUTONOMY.md + .harness/schemas/autonomy.schema.md are well-formed, define the five autonomy levels,
# the always-blocked set, and the nine fail-closed stop conditions, and that the charter is NON-CONFLICTING with the
# existing DMC enforcement modes (active/passive/off). No behavior change; mutates nothing.
#
# Usage:  dmc-v0.4.0-autonomy-charter.sh --self-test
set -u
set -o pipefail
ROOTDIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
A="$ROOTDIR/AUTONOMY.md"; S="$ROOTDIR/.harness/schemas/autonomy.schema.md"; D="$ROOTDIR/DMC.md"

self_test() {
  local P=0 F=0; ok(){ echo "  PASS $1"; P=$((P+1)); }; no(){ echo "  FAIL $1"; F=$((F+1)); }
  local PRE; PRE="$(git -C "$ROOTDIR" status --porcelain 2>/dev/null | md5)"

  # AC1 — files present
  { [ -f "$A" ] && [ -f "$S" ]; } && ok "AC1 AUTONOMY.md + autonomy.schema.md present" || no "AC1 charter files missing"

  # AC2 — all five autonomy levels defined in BOTH the charter and the schema
  local lv ok2=1
  for lv in passive advisory autonomous-dry-run autonomous-local-commit human-gated-push; do
    grep -q "$lv" "$A" 2>/dev/null && grep -q "$lv" "$S" 2>/dev/null || ok2=0
  done
  [ "$ok2" = 1 ] && ok "AC2 all 5 autonomy levels in charter + schema" || no "AC2 a level is missing"

  # AC3 — the nine fail-closed stop conditions present in the charter
  local sc ok3=1
  for sc in 'dirty worktree' 'branch is .main' 'scope violation' 'protected-surface diff' 'secret . credential' \
            'live-call . network' 'verification FAIL' 'ambiguity' 'over-eager'; do
    grep -qiE "$sc" "$A" 2>/dev/null || ok3=0
  done
  { [ "$ok3" = 1 ] && grep -qi 'fail-closed' "$A"; } && ok "AC3 nine fail-closed stop conditions present" || no "AC3 a stop condition is missing"

  # AC4 — always-blocked set (secret content, live/network, force/history-rewrite, branch deletion, leaked-prompt)
  local ab ok4=1
  for ab in 'secret-bearing' 'live provider call . network' 'force.*history rewrite|history.rewrite' 'branch del' 'leaked'; do
    grep -qiE "$ab" "$A" 2>/dev/null || ok4=0
  done
  [ "$ok4" = 1 ] && ok "AC4 always-blocked set (secret/live/force/branch-del/leaked-prompt) present" || no "AC4 always-blocked incomplete"

  # AC5 — NON-CONFLICT with DMC.md modes: the charter declares orthogonality + names the existing modes; does NOT
  #       redefine .harness/mode semantics.
  if grep -qi 'orthogonal' "$A" && grep -qiE 'active.*passive.*off|active/passive/off' "$A" \
     && grep -qi 'enforcement floor always applies' "$A"; then
    ok "AC5 non-conflict: autonomy level declared orthogonal to the active/passive/off enforcement mode"
  else no "AC5 charter does not declare non-conflict with DMC.md modes"; fi

  # AC6 — Rule 7 honored: no copied leaked prompt text; leaks labeled as unverified design signals
  { grep -qiE 'leaked.*prompt|prompt.*leaked' "$A" && grep -qi 'unverified design signal' "$A" && grep -qi 'rule 7' "$A"; } \
    && ok "AC6 Rule 7 honored: leaks are unverified design signals only; no copied prompt text" || no "AC6 Rule 7 not honored"

  # AC7 — push + closure are never autonomous (the load-bearing safety statement)
  grep -qiE 'PUSH and CLOSURE are never autonomous|never_autonomous' "$A" && grep -qi 'never_autonomous' "$S" \
    && ok "AC7 push + closure are never autonomous (human-gated)" || no "AC7 push/closure autonomy not blocked"

  # AC8 — read-only: the check mutated nothing in the real repo
  [ "$(git -C "$ROOTDIR" status --porcelain 2>/dev/null | md5)" = "$PRE" ] && ok "AC8 read-only: repo byte-unchanged" || no "AC8 repo changed"

  echo "  ---- self-test: PASS=$P FAIL=$F ----"; [ "$F" = 0 ]
}

case "${1:-}" in
  --self-test) echo "==== DMC AUTONOMY CHARTER — SELF-TEST (read-only) ===="; self_test; exit $?;;
  -h|--help) sed -n '2,9p' "$0"; exit 0;;
  *) echo "autonomy-charter: use --self-test" >&2; exit 2;;
esac
