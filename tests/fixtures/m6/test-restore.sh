#!/usr/bin/env bash
# test-restore.sh — DMC v1 M6 pre-commit RESTORE proof.
#
# Nature: READ-ONLY test. Proves the committed fixtures under
# tests/fixtures/hooks-v0.6.5/ can restore the pre-M6 hook surface with one
# action. In a TEMP COPY of the live .claude/ tree it OVERLAYS the fixtures
# (hooks/* -> .claude/hooks/, settings.json -> .claude/settings.json) and then
# `cmp`s every restored file against `git show <pinned>:<path>` — the pinned
# pre-M6 commit 299987047e448cff6ea9ddaf8011d66992901003. Byte-identity for
# every pinned file demonstrates the restore is exact.
#
# Scope note (honest): an OVERLAY copies bytes but does not DELETE M6-added
# files, so this suite also enumerates any file the M6 edits ADDED to
# .claude/hooks (a real single-revert commit would remove them). The full
# single-REVERT-commit form of the proof — which also removes additions and
# leaves the live tree byte-identical to the pinned commit — re-runs at the
# closure gate POST-COMMIT (see test-rollback.sh, run against the committed
# tree).
#
# Never reads .env / credentials; never mutates the live repo; no network /
# live / model / API call. All work is in a mktemp copy.
#
# Usage: test-restore.sh   Run all checks, print PASS/FAIL + summary, exit 0/1.

set -u

PINNED_HASH="299987047e448cff6ea9ddaf8011d66992901003"

SELF_DIR=$(cd -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd -P) || { echo "FATAL: script dir"; exit 2; }
ROOT=$(cd -- "$SELF_DIR/../../.." >/dev/null 2>&1 && pwd -P) || { echo "FATAL: repo root"; exit 2; }
if ! git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "FATAL: derived root is not a git worktree: $ROOT"; exit 2
fi

FIXTURE_DIR="$ROOT/tests/fixtures/hooks-v0.6.5"
FIXTURE_HOOKS="$FIXTURE_DIR/hooks"
FIXTURE_SETTINGS="$FIXTURE_DIR/settings.json"

PASS=0; FAIL=0
record() { # record PASS|FAIL DESC
  if [ "$1" = PASS ]; then PASS=$((PASS+1)); printf '  [PASS] %s\n' "$2"
  else FAIL=$((FAIL+1)); printf '  [FAIL] %s\n' "$2"; fi
}
ok() { [ "$1" -eq 0 ] && record PASS "$2" || record FAIL "$2"; }

SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/dmc-m6-restore.XXXXXX") || { echo "FATAL: mktemp"; exit 2; }
TMP_GIT_SHOW=$(mktemp "${TMPDIR:-/tmp}/dmc-m6-restore-show.XXXXXX") || { echo "FATAL: mktemp"; exit 2; }
cleanup() { rm -rf "$SANDBOX"; rm -f "$TMP_GIT_SHOW"; }
trap cleanup EXIT

main() {
  echo "test-restore.sh :: root=$ROOT pinned=$PINNED_HASH"

  # ---- 1. build a temp copy of the live .claude tree, then OVERLAY the fixtures (the restore) ----
  local work="$SANDBOX/repo"
  mkdir -p "$work"
  cp -R "$ROOT/.claude" "$work/.claude"
  # OVERLAY: this is the exact "restore" action a maintainer performs.
  cp -R "$FIXTURE_HOOKS/." "$work/.claude/hooks/"
  cp "$FIXTURE_SETTINGS" "$work/.claude/settings.json"

  echo "  -- restored-file byte-identity vs the pinned pre-M6 commit --"
  # ---- 2. every file the pinned commit carried under .claude/hooks must, after overlay, be
  #         byte-identical to `git show <pinned>:<path>`. ----
  local gitpath rel restored
  while IFS= read -r gitpath; do
    [ -z "$gitpath" ] && continue
    rel="${gitpath#.claude/}"
    restored="$work/.claude/$rel"
    : > "$TMP_GIT_SHOW"
    if [ -f "$restored" ] \
       && git -C "$ROOT" show "$PINNED_HASH:$gitpath" > "$TMP_GIT_SHOW" 2>/dev/null \
       && cmp -s "$restored" "$TMP_GIT_SHOW"; then
      ok 0 "restored byte-identical to pinned: $gitpath"
    else
      ok 1 "restored byte-identical to pinned: $gitpath"
    fi
  done < <(git -C "$ROOT" ls-tree -r --name-only "$PINNED_HASH" .claude/hooks | sort)

  # settings.json
  : > "$TMP_GIT_SHOW"
  if [ -f "$work/.claude/settings.json" ] \
     && git -C "$ROOT" show "$PINNED_HASH:.claude/settings.json" > "$TMP_GIT_SHOW" 2>/dev/null \
     && cmp -s "$work/.claude/settings.json" "$TMP_GIT_SHOW"; then
    ok 0 "restored byte-identical to pinned: .claude/settings.json"
  else
    ok 1 "restored byte-identical to pinned: .claude/settings.json"
  fi

  # ---- 3. honest extra-file report: any file M6 ADDED under .claude/hooks that the pinned
  #         commit did not carry (an overlay leaves these; a single-revert commit removes them). ----
  echo "  -- M6-added files under .claude/hooks (removed only by the single-revert commit) --"
  local pinned_list added=0 livepath rel2
  pinned_list=$(git -C "$ROOT" ls-tree -r --name-only "$PINNED_HASH" .claude/hooks | sort)
  while IFS= read -r livepath; do
    [ -z "$livepath" ] && continue
    rel2="${livepath#"$ROOT"/}"
    if ! printf '%s\n' "$pinned_list" | grep -qxF "$rel2"; then
      printf '    + %s (M6 addition — not in the pinned tree)\n' "$rel2"
      added=$((added+1))
    fi
  done < <(find "$ROOT/.claude/hooks" -type f | sort)
  if [ "$added" -eq 0 ]; then
    record PASS "no M6-added files under .claude/hooks — overlay restore is already complete (no deletions needed)"
  else
    record PASS "$added M6-added file(s) enumerated — the single-revert commit removes them (re-proven post-commit by test-rollback.sh)"
  fi

  echo "  ----"
  echo "  NOTE: this is the pre-commit OVERLAY proof (byte-identity of every restored file)."
  echo "        The single-REVERT-commit proof (which also deletes M6 additions and leaves the"
  echo "        live tree byte-identical to $PINNED_HASH) re-runs at the closure gate post-commit"
  echo "        via test-rollback.sh."
  echo "  RESULT: $PASS PASS / $FAIL FAIL"
  [ "$FAIL" -eq 0 ] && exit 0 || exit 1
}

main
