#!/usr/bin/env bash
# DMC Interop Doc check (v0.4.8) — ADVISORY / READ-ONLY.
#
# Validates docs/INTEROP.md documents the five suggested hook points (each mapped to a real in-repo DMC guard), the
# LazyCodex-style mapping, and the no-runtime-dependency contract. Docs-only milestone; mutates nothing.
#
# Usage:  dmc-v0.4.8-interop-doc-check.sh --self-test
set -u
set -o pipefail
ROOTDIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
I="$ROOTDIR/docs/INTEROP.md"

self_test() {
  local P=0 F=0; ok(){ echo "  PASS $1"; P=$((P+1)); }; no(){ echo "  FAIL $1"; F=$((F+1)); }
  local PRE; PRE="$(git -C "$ROOTDIR" status --porcelain 2>/dev/null | md5)"

  [ -f "$I" ] && ok "AC1 docs/INTEROP.md present" || no "AC1 INTEROP.md missing"

  # AC2 — the five suggested hook points present
  local hp ok2=1
  for hp in 'SessionStart' 'PreToolUse' 'post-edit|PostToolUse' 'PreCommit' 'Stop'; do
    grep -qiE "$hp" "$I" || ok2=0
  done
  [ "$ok2" = 1 ] && ok "AC2 five hook points: SessionStart/PreToolUse/post-edit/PreCommit/Stop present" || no "AC2 a hook point missing"

  # AC3 — each hook point maps to a REAL in-repo guard (the referenced scripts exist)
  local g miss=""
  for g in dmc-v0.4.5-secret-network-live-guard dmc-v0.4.3-scope-overeager-guard dmc-v0.4.4-evidence-harness \
           dmc-v0.4.6-reviewer-loop dmc-v0.4.2-branch-isolation-guard dmc-v0.4.1-goal-plan-compiler; do
    grep -q "$g" "$I" && [ -f "$ROOTDIR/.harness/evidence/$g.sh" ] || miss="$miss $g"
  done
  [ -z "$miss" ] && ok "AC3 hook points map to real in-repo guards (v0.4.1/2/3/4/5/6 referenced + present)" || no "AC3 missing mapping:$miss"

  # AC4 — LazyCodex-style mapping + verified-completion (closure controller) referenced
  { grep -qi 'LazyCodex' "$I" && grep -q 'dmc-v0.3.7-closure-controller' "$I" && grep -qi 'project memory' "$I"; } \
    && ok "AC4 LazyCodex-style mapping (memory/planning/execution/verified-completion) present" || no "AC4 LazyCodex mapping"

  # AC5 — no-runtime-dependency contract + Rule 7 provenance
  { grep -qi 'not a runtime dependenc\|not.*runtime.*depend\|No-runtime-dependency\|does .*not.*require LazyCodex' "$I" \
    && grep -qi 'unverified design signal' "$I" && grep -qi 'rule 7' "$I"; } \
    && ok "AC5 no-runtime-dependency contract + Rule 7 (unverified design signals only)" || no "AC5 dependency/provenance"

  # AC6 — read-only
  [ "$(git -C "$ROOTDIR" status --porcelain 2>/dev/null | md5)" = "$PRE" ] && ok "AC6 read-only: repo byte-unchanged" || no "AC6 repo changed"

  echo "  ---- self-test: PASS=$P FAIL=$F ----"; [ "$F" = 0 ]
}

case "${1:-}" in
  --self-test) echo "==== DMC INTEROP DOC CHECK — SELF-TEST (read-only) ===="; self_test; exit $?;;
  -h|--help) sed -n '2,8p' "$0"; exit 0;;
  *) echo "interop-doc-check: use --self-test" >&2; exit 2;;
esac
