#!/usr/bin/env bash
# install.sh — Do-Me-Coding one-command install wrapper (v1.0).
#
# Collapses the fresh-install flow (clone -> dmc-install.sh -> cd -> doctor -> check mode) into ONE
# command, and adds the python3 preflight the base installer lacks. It does NOT change DMC's
# per-repo-copy model or the underlying installer: it self-locates, preflights, delegates VERBATIM
# to .claude/install/dmc-install.sh, then (for a real install) runs `bin/dmc doctor` in the target
# and surfaces the doctor's exit code.
#
# Usage:
#   ./install.sh <target-repo-path> [--host claude|codex|both] [--mode active|passive|off] [--dry-run]
#
# The <target-repo-path> must come FIRST and must already exist (the base installer requires it).
# Every flag after it is passed through verbatim to the base installer, which OWNS --host/--mode
# validation. Exit code == the first failing step's code; 0 only on full success.

set -eu

# ---- §0 self-locate + parse target ----------------------------------------------------------
SELF="$(cd "$(dirname "$0")" && pwd)"
INSTALLER="$SELF/.claude/install/dmc-install.sh"

usage() {
  cat >&2 <<EOF
Usage: $0 <target-repo-path> [--host claude|codex|both] [--mode active|passive|off] [--dry-run]
  <target-repo-path> must be the FIRST argument and must already exist.
  All flags are passed through verbatim to .claude/install/dmc-install.sh.
EOF
}

if [ "$#" -eq 0 ]; then
  echo "ERROR: target repo path required." >&2
  usage
  exit 2
fi

# The wrapper contract is target-FIRST: the first argument must be the target, not a flag.
case "$1" in
  -*)
    echo "ERROR: first argument must be the target repo path, not a flag ('$1')." >&2
    usage
    exit 2
    ;;
esac
TARGET="$1"

# Detect --dry-run anywhere in the arg list so §3 verify is skipped when nothing is installed.
DRYRUN=0
for _arg in "$@"; do
  case "$_arg" in
    --dry-run) DRYRUN=1 ;;
  esac
done

# ---- §1 preflight ---------------------------------------------------------------------------
# python3 is a HARD requirement, checked BEFORE touching the target: the base installer writes its
# receipt / merges settings.json with python3, and `dmc doctor` is a python3 program. (bash is
# guaranteed by this wrapper's own shebang.)
if ! command -v python3 >/dev/null 2>&1; then
  cat >&2 <<'EOF'
ERROR: python3 was not found on PATH.
  DMC's installer and `dmc doctor` require python3 (stdlib only; no packages).
  On macOS, install the Command Line Tools:  xcode-select --install
  Then re-run this installer.
EOF
  exit 1
fi
# git is only recommended (for the DMC git-workflow); never a hard gate.
if ! command -v git >/dev/null 2>&1; then
  echo "WARNING: git was not found on PATH — recommended for the DMC git-workflow, but not required for install or doctor." >&2
fi

if [ ! -f "$INSTALLER" ]; then
  echo "ERROR: base installer not found at: $INSTALLER" >&2
  echo "       (run install.sh from a complete DMC checkout)." >&2
  exit 1
fi

# ---- §2 delegate install (verbatim passthrough; surface the installer's exit code) ----------
"$INSTALLER" "$@" || exit $?

# ---- §3 verify (skipped for --dry-run: nothing was installed) -------------------------------
if [ "$DRYRUN" -eq 1 ]; then
  echo ""
  echo "Dry-run complete — nothing was written to '$TARGET'. Re-run without --dry-run to install."
  exit 0
fi

# Resolve the target to an absolute path so a relative <target> can't drift the doctor / report.
TGT="$(cd "$TARGET" && pwd)"
# Run the host self-check exactly as a user would; a doctor DEFECT becomes our exit code.
( cd "$TGT" && bin/dmc doctor ) || exit $?

# ---- §4 report ------------------------------------------------------------------------------
echo ""
echo "Do-Me-Coding is installed and verified in: $TGT"
if [ -f "$TGT/.harness/mode" ]; then
  echo "  DMC mode ($TGT/.harness/mode): $(cat "$TGT/.harness/mode")"
else
  echo "  DMC mode file not found at $TGT/.harness/mode"
fi
echo ""
echo "Next, in Claude Code:"
echo "  1. Open $TGT as your project."
echo "  2. Run  /dmc-status  to confirm enforcement is live."
echo "  3. End any task prompt with  dmc  to route it through /dmc-ultrawork"
echo "     (plan -> critic -> scope -> execute -> verify -> evidence)."
exit 0
