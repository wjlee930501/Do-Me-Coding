#!/usr/bin/env bash
# DMC v0.6.4 Goal Ledger (wrapper). ADVISORY / READ-ONLY / INPUT-ONLY, fail-closed, append-only/immutable history.
#
# Validates goal-ledger entries and runs the transition/append-only/trace/authorize gates (see
# .harness/schemas/goal-ledger.schema.md). Thin wrapper over the adjacent `dmc-v0.6.4-goal-ledger.py` core: NO here-doc,
# NO temp file. Sub-commands read ONLY the file/stdin and NEVER call git; the only git use is the `--self-test` byte-unchanged
# sentinel. No env/.env/model/network.
#
# Usage:  dmc-v0.6.4-goal-ledger.sh --validate <entry.json|->
#         dmc-v0.6.4-goal-ledger.sh --transition <{from,to}.json|->
#         dmc-v0.6.4-goal-ledger.sh --append-check <{prev,next}.json|-> [--out <file>]
#         dmc-v0.6.4-goal-ledger.sh --trace <{ledger,completion}.json|-> [--out <file>]
#         dmc-v0.6.4-goal-ledger.sh --authorize <{prev,next,completion}.json|-> [--out <file>]
#         dmc-v0.6.4-goal-ledger.sh --self-test   |   [-h|--help]
# Exit:   validate 0 valid/1 invalid; transition 0 legal/1 illegal; gate-likes 0 ALLOW/1 REFUSE; 2 = usage/refused.
set -u
set -o pipefail
export PYTHONDONTWRITEBYTECODE=1
SELFDIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd -P)"
SELFPATH="$SELFDIR/$(basename "$0")"
PYCORE="$SELFDIR/dmc-v0.6.4-goal-ledger.py"
ROOTDIR="$(cd "$SELFDIR/../.." 2>/dev/null && pwd -P || true)"
[ -n "$ROOTDIR" ] || ROOTDIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

repo_hash() { git -C "$ROOTDIR" status --porcelain 2>/dev/null | python3 -c 'import hashlib,sys; sys.stdout.write(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())'; }

PROT_RE='(^|/)(\.env)(\.|$)|\.pem$|\.key$|id_rsa|id_ed25519|credentials|secret|\.p12$|\.pfx$|\.keystore$|\.claude/hooks|provider-router\.py|PROVIDER_CONTRACT\.md|WORKER_(TASK|RESULT|REVIEW)_SCHEMA\.md'
out_refused() { local raw="$1"
  printf '%s' "$raw" | grep -qE '(^|/)\.\.(/|$)' && return 0
  case "$raw" in *.env|*.env.local|*.env.*) case "$raw" in *.example|*.sample|*.template) ;; *) return 0;; esac;; esac
  printf '%s' "$raw" | grep -qiE "$PROT_RE" && return 0
  [ -L "$raw" ] && return 0
  local parent base cparent canon
  parent="$(dirname "$raw" 2>/dev/null)"; base="$(basename "$raw")"
  cparent="$(cd "$parent" 2>/dev/null && pwd -P)" || return 0
  canon="$cparent/$base"
  printf '%s' "$canon" | grep -qiE "$PROT_RE" && return 0
  case "$canon/" in "$ROOTDIR"/*) return 0;; esac
  return 1
}
vet_out() {
  if printf '%s\n' "$@" | grep -qx -- '--out'; then
    local nxt=0 out=""
    for a in "$@"; do if [ "$a" = "--out" ]; then nxt=1; elif [ "$nxt" = 1 ]; then out="$a"; nxt=0; fi; done
    [ -n "$out" ] || { echo "usage: --out needs a path"; exit 2; }
    if out_refused "$out"; then echo "REFUSED: unsafe --out path: $out"; exit 2; fi
  fi
}

usage() { sed -n '2,17p' "$SELFPATH" | sed 's/^# \{0,1\}//'; }
[ -f "$PYCORE" ] || { echo "FATAL: core not found: $PYCORE"; exit 2; }

case "${1:-}" in
  --validate)
    [ $# -ge 2 ] || { echo "usage: --validate <entry.json|->"; exit 2; }
    python3 "$PYCORE" validate "$2"; exit $?
    ;;
  --transition)
    [ $# -ge 2 ] || { echo "usage: --transition <{from,to}.json|->"; exit 2; }
    python3 "$PYCORE" transition "$2"; exit $?
    ;;
  --append-check|--trace|--authorize)
    mode="${1#--}"
    [ $# -ge 2 ] || { echo "usage: --$mode <json|-> [--out <file>]"; exit 2; }
    vet_out "$@"
    shift
    python3 "$PYCORE" "$mode" "$@"; exit $?
    ;;
  --self-test)
    echo "DMC v0.6.4 goal ledger (--self-test) :: root=$ROOTDIR"
    h1="$(repo_hash)"
    python3 "$PYCORE" selftest; rc=$?
    h2="$(repo_hash)"
    if [ "$h1" = "$h2" ]; then echo "  [PASS] G10 repo byte-unchanged after self-test ($h1)"; else echo "  [FAIL] G10 repo CHANGED"; rc=1; fi
    [ "$rc" -eq 0 ] && echo "  RESULT: self-test PASS" || echo "  RESULT: self-test FAIL"
    exit $rc
    ;;
  -h|--help|"")
    usage; exit 0
    ;;
  *)
    echo "unknown flag: $1"; usage; exit 2
    ;;
esac
