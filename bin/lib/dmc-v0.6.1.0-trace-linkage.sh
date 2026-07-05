#!/usr/bin/env bash
# DMC v0.6.1.0 Trace Linkage Contract validator (wrapper). ADVISORY / READ-ONLY / INPUT-ONLY, fail-closed, value-blind.
#
# Validates a `dmc.trace-linkage.v1` record (see .harness/schemas/trace-linkage.schema.md) for schema + referential
# integrity, so the v0.6.1-v0.6.5 trace composes and a false trace cannot be assembled from valid-but-unrelated IDs.
# Thin wrapper over the adjacent `dmc-v0.6.1.0-trace-linkage.py` core: NO here-doc, NO temp file, so it runs in a
# read-only / no-temp sandbox. `--validate` reads ONLY the record file given and NEVER calls git; the only git use is the
# `--self-test` byte-unchanged sentinel. Never reads the environment, .env, credentials, or the network.
#
# Usage:  dmc-v0.6.1.0-trace-linkage.sh --validate <record.json>   |   --validate-entry <register-key> <entry.json>
#         |   --self-test   |   [-h|--help]      (path "-" reads stdin; no temp file)
# Exit:   0 = valid, 1 = invalid (fail-closed), 2 = usage/refused.
set -u
set -o pipefail
export PYTHONDONTWRITEBYTECODE=1
SELFDIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd -P)"
SELFPATH="$SELFDIR/$(basename "$0")"
PYCORE="$SELFDIR/dmc-v0.6.1.0-trace-linkage.py"
ROOTDIR="$(cd "$SELFDIR/../.." 2>/dev/null && pwd -P || true)"
[ -n "$ROOTDIR" ] || ROOTDIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# env-free worktree-status hash — used ONLY by --self-test as the byte-unchanged sentinel (python -c, no temp/heredoc)
repo_hash() { git -C "$ROOTDIR" status --porcelain 2>/dev/null | python3 -c 'import hashlib,sys; sys.stdout.write(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())'; }

usage() { sed -n '2,13p' "$SELFPATH" | sed 's/^# \{0,1\}//'; }

[ -f "$PYCORE" ] || { echo "FATAL: core not found: $PYCORE"; exit 2; }

case "${1:-}" in
  --validate)
    [ $# -ge 2 ] || { echo "usage: --validate <record.json>"; exit 2; }
    python3 "$PYCORE" validate "$2"; exit $?
    ;;
  --validate-entry)
    [ $# -ge 3 ] || { echo "usage: --validate-entry <register-key> <entry.json>"; exit 2; }
    python3 "$PYCORE" validate-entry "$2" "$3"; exit $?
    ;;
  --self-test)
    echo "DMC v0.6.1.0 trace-linkage validator (--self-test) :: root=$ROOTDIR"
    h1="$(repo_hash)"
    python3 "$PYCORE" selftest; rc=$?
    h2="$(repo_hash)"
    if [ "$h1" = "$h2" ]; then echo "  [PASS] T13  repo byte-unchanged after self-test ($h1)"; else echo "  [FAIL] T13  repo CHANGED"; rc=1; fi
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
