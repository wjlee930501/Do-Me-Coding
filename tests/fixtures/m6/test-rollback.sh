#!/usr/bin/env bash
# test-rollback.sh — pre-M6 hook-surface rollback proof.
#
# Nature: READ-ONLY test. Compares the fixtures in
# tests/fixtures/hooks-v0.6.5/ against (a) the live .claude/hooks tree +
# .claude/settings.json, and (b) the pinned pre-M6 commit
# 299987047e448cff6ea9ddaf8011d66992901003 via `git show`. Never writes
# the repo; never reads .env or credentials; makes no network / live /
# model / API call.
#
# Two things this proves (per plan dmc-v1-m6-hook-hardening critic
# findings B1 / O3):
#   (a) "live matches fixture" — the live tree is byte-identical to the
#       fixtures, i.e. a rollback (or a not-yet-started M6) is intact.
#   (b) "fixture pinned to commit" — the fixtures themselves are minted
#       from the pinned pre-M6 commit, not merely a copy someone made of
#       an already-edited working tree (a self-satisfying fixture set
#       could pass (a) without ever proving what "pre-M6" looked like).
#
# Also verifies completeness: every file present in the pinned commit's
# .claude/hooks tree, plus .claude/settings.json, must have a
# corresponding fixture file.
#
# Usage:
#   test-rollback.sh    Run all checks, print PASS/FAIL + summary, exit 0/1.

set -u

PINNED_HASH="299987047e448cff6ea9ddaf8011d66992901003"

SELF_DIR=$(cd -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd -P) || { echo "FATAL: cannot resolve script dir"; exit 2; }
ROOT=$(cd -- "$SELF_DIR/../../.." >/dev/null 2>&1 && pwd -P) || { echo "FATAL: cannot resolve repo root"; exit 2; }
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

TMP_GIT_SHOW=$(mktemp "${TMPDIR:-/tmp}/dmc-m6-rollback.XXXXXX") || { echo "FATAL: mktemp failed"; exit 2; }
cleanup() { rm -f "$TMP_GIT_SHOW"; }
trap cleanup EXIT

# check_pair FIXTURE_FILE LIVE_PATH GIT_PATH LABEL
# (a) cmp fixture vs live path; (b) cmp fixture vs `git show <pinned>:<git_path>`.
check_pair() {
  local fixture_file="$1" live_path="$2" git_path="$3" label="$4"

  if [ -f "$live_path" ] && cmp -s "$fixture_file" "$live_path"; then
    ok 0 "live matches fixture: $label"
  else
    ok 1 "live matches fixture: $label"
  fi

  : > "$TMP_GIT_SHOW"
  if git -C "$ROOT" show "$PINNED_HASH:$git_path" > "$TMP_GIT_SHOW" 2>/dev/null && cmp -s "$fixture_file" "$TMP_GIT_SHOW"; then
    ok 0 "fixture pinned to commit: $label"
  else
    ok 1 "fixture pinned to commit: $label"
  fi
}

run_checks() {
  echo "  -- pair checks (live vs fixture, fixture vs pinned commit) --"

  local relpath
  while IFS= read -r f; do
    relpath="${f#"$FIXTURE_HOOKS"/}"
    check_pair "$f" "$ROOT/.claude/hooks/$relpath" ".claude/hooks/$relpath" "hooks/$relpath"
  done < <(find "$FIXTURE_HOOKS" -type f | sort)

  check_pair "$FIXTURE_SETTINGS" "$ROOT/.claude/settings.json" ".claude/settings.json" "settings.json"

  echo "  -- completeness (every pinned-commit file has a fixture) --"

  local gitpath fixpath
  while IFS= read -r gitpath; do
    [ -z "$gitpath" ] && continue
    fixpath="$FIXTURE_HOOKS/${gitpath#.claude/hooks/}"
    [ -f "$fixpath" ]; ok $? "completeness: $gitpath fixtured"
  done < <(git -C "$ROOT" ls-tree -r --name-only "$PINNED_HASH" .claude/hooks | sort)

  if git -C "$ROOT" cat-file -e "$PINNED_HASH:.claude/settings.json" 2>/dev/null; then
    [ -f "$FIXTURE_SETTINGS" ]; ok $? "completeness: .claude/settings.json fixtured"
  else
    ok 1 "completeness: .claude/settings.json fixtured (missing from pinned commit — unexpected)"
  fi
}

main() {
  echo "test-rollback.sh :: root=$ROOT pinned=$PINNED_HASH"
  run_checks
  echo "  ----"
  echo "  RESULT: $PASS PASS / $FAIL FAIL"
  [ "$FAIL" -eq 0 ] && exit 0 || exit 1
}

main
