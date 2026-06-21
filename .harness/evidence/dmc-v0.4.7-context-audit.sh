#!/usr/bin/env bash
# DMC Context Audit (v0.4.7) — ADVISORY / READ-ONLY.
#
# Audits the operating-context files for bloat / duplication / conflicting mode instructions, and verifies the compact
# context map (docs/CONTEXT_MAP.md) exists and is the single-source pointer index. No edits; mutates nothing.
#
# Usage:  dmc-v0.4.7-context-audit.sh --self-test
set -u
set -o pipefail
ROOTDIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CM="$ROOTDIR/docs/CONTEXT_MAP.md"; A="$ROOTDIR/AUTONOMY.md"; D="$ROOTDIR/DMC.md"; AG="$ROOTDIR/AGENTS.md"
BLOAT=400   # a context file beyond this many lines is a bloat smell

self_test() {
  local P=0 F=0; ok(){ echo "  PASS $1"; P=$((P+1)); }; no(){ echo "  FAIL $1"; F=$((F+1)); }
  local PRE; PRE="$(git -C "$ROOTDIR" status --porcelain 2>/dev/null | md5)"

  # AC1 — context map present + indexes each contract
  if [ -f "$CM" ] && grep -q 'DMC.md' "$CM" && grep -q 'AUTONOMY.md' "$CM" && grep -q 'AGENTS.md' "$CM" \
     && grep -qi 'schema' "$CM" && grep -qi 'guard' "$CM"; then
    ok "AC1 CONTEXT_MAP.md present + indexes DMC.md/AUTONOMY.md/AGENTS.md/schemas/guards"
  else no "AC1 context map incomplete"; fi

  # AC2 — no conflicting mode instructions: autonomy declared orthogonal to active/passive/off; modes NOT redefined
  if grep -qi 'orthogonal' "$CM" && grep -qi 'orthogonal' "$A" \
     && grep -qiE 'active/passive/off|active.*passive.*off' "$A"; then
    ok "AC2 non-conflict: autonomy level orthogonal to enforcement mode (modes not redefined)"
  else no "AC2 conflict / orthogonality not declared"; fi

  # AC3 — configuration-smell checklist present (all key items)
  local sm ok3=1
  for sm in 'No duplication' 'No conflict' 'mode redefinition' 'compact' 'Single source' 'Provenance' 'Additive'; do
    grep -qi "$sm" "$CM" || ok3=0
  done
  [ "$ok3" = 1 ] && ok "AC3 configuration-smell checklist present (duplication/conflict/mode/compact/single-source/provenance/additive)" || no "AC3 smell checklist incomplete"

  # AC4 — conciseness: no context file exceeds the bloat bound
  local bloated="" f n
  for f in "$D" "$A" "$AG" "$CM" "$ROOTDIR/CLAUDE.md"; do
    [ -f "$f" ] || continue; n="$(wc -l < "$f")"; [ "$n" -gt "$BLOAT" ] 2>/dev/null && bloated="$bloated $(basename "$f")=$n"
  done
  [ -z "$bloated" ] && ok "AC4 conciseness: every context file <= $BLOAT lines (no bloat)" || no "AC4 bloat:$bloated"

  # AC5 — single-source of secret patterns: AUTONOMY.md REFERENCES DMC.md secret protection, does NOT re-list the full
  #       pattern set (a duplication smell = the cert/key extensions copied in)
  if grep -qi 'Secret Protection' "$A" && grep -q 'DMC.md' "$A" \
     && ! grep -qE '\.p12|\.pfx|\.keystore|\.npmrc|\.netrc|\.pgpass' "$A"; then
    ok "AC5 single-source: AUTONOMY.md references DMC.md secret protection (no duplicated pattern list)"
  else no "AC5 secret patterns duplicated in AUTONOMY.md"; fi

  # AC6 — discoverability: AGENTS.md points to AUTONOMY.md + the context map
  { grep -q 'AUTONOMY.md' "$AG" && grep -q 'CONTEXT_MAP.md' "$AG"; } \
    && ok "AC6 discoverability: AGENTS.md points to AUTONOMY.md + docs/CONTEXT_MAP.md" || no "AC6 AGENTS.md missing pointer"

  # AC7 — read-only
  [ "$(git -C "$ROOTDIR" status --porcelain 2>/dev/null | md5)" = "$PRE" ] && ok "AC7 read-only: repo byte-unchanged" || no "AC7 repo changed"

  echo "  ---- self-test: PASS=$P FAIL=$F ----"; [ "$F" = 0 ]
}

case "${1:-}" in
  --self-test) echo "==== DMC CONTEXT AUDIT — SELF-TEST (read-only) ===="; self_test; exit $?;;
  -h|--help) sed -n '2,8p' "$0"; exit 0;;
  *) echo "context-audit: use --self-test" >&2; exit 2;;
esac
