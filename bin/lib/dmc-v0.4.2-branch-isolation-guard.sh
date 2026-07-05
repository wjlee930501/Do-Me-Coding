#!/usr/bin/env bash
# DMC Branch / Worktree Isolation Guard (v0.4.2) — ADVISORY / READ-ONLY, fail-closed.
#
# Verifies an autonomous run is isolated BEFORE any edit: on a dedicated branch (not main/master) unless an explicit
# closure run, on a non-detached HEAD, with a clean worktree (or dirty only within the approved scope). Metadata-only
# git (rev-parse / symbolic-ref / status --porcelain / rev-list); NO destructive command; writes/commits/pushes nothing.
#
# Usage:  branch-isolation-guard.sh [--repo <dir>] [--closure] [--approved-scope <path[,path...]>]   ·   --self-test
# Exit: 0 = ISOLATED (safe to proceed), 1 = BLOCKED (a stop condition holds), 2 = usage.
set -u
set -o pipefail
ROOTDIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SELFPATH="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/$(basename "$0")"
PROTECTED_BRANCHES='^(main|master)$'

# --- checks (each echoes PASS or BLOCK:<reason>; metadata-only git) ---
chk_branch() { # <repo> <closure:0|1>
  local repo="$1" cl="$2" br
  br="$(git -C "$repo" symbolic-ref --quiet --short HEAD 2>/dev/null)"
  [ -n "$br" ] || { echo "BLOCK:detached-HEAD (no branch to commit to safely)"; return; }
  if printf '%s' "$br" | grep -qE "$PROTECTED_BRANCHES"; then
    [ "$cl" = 1 ] && echo "PASS:on $br (closure run — append-only edit permitted)" \
                  || echo "BLOCK:branch-is-$br-outside-closure (autonomous edits on a protected branch are blocked)"
  else
    echo "PASS:on dedicated branch '$br'"
  fi
}
chk_worktree() { # <repo> <approved_scope_csv>
  local repo="$1" scope="$2" dirty
  # tracked, not-untracked changes only (?? excluded): M/A/D/R/C/U in either column
  dirty="$(git -C "$repo" status --porcelain --untracked-files=no 2>/dev/null)"
  [ -z "$dirty" ] && { echo "PASS:clean worktree"; return; }
  if [ -n "$scope" ]; then
    # every dirty path must be within the approved scope; else BLOCK (do not echo the path content)
    local bad=0 line p IFS_OLD="$IFS"
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      p="$(printf '%s' "$line" | sed 's/^...//; s/^.* -> //')"   # strip XY status; take rename target
      printf '%s,' "$scope" | grep -qF "$(printf '%s' "$p")," || bad=1
    done <<EOF
$dirty
EOF
    IFS="$IFS_OLD"
    [ "$bad" = 0 ] && echo "PASS:dirty only within approved scope" || echo "BLOCK:dirty-worktree-outside-approved-scope"
  else
    echo "BLOCK:dirty-worktree (uncommitted tracked changes at run start)"
  fi
}

run_guard() { # <repo> <closure:0|1> <approved_scope_csv>  -> prints verdict; return 0 if ISOLATED else 1
  local repo="$1" cl="$2" scope="$3" b w blocked=""
  b="$(chk_branch "$repo" "$cl")"; w="$(chk_worktree "$repo" "$scope")"
  local wt; wt="$(git -C "$repo" rev-parse --is-inside-work-tree 2>/dev/null || echo false)"
  case "$b" in BLOCK:*) blocked="$blocked branch";; esac
  case "$w" in BLOCK:*) blocked="$blocked worktree";; esac
  echo "# DMC Branch/Worktree Isolation Guard"
  echo "- branch:   $(printf '%s' "$b" | sed 's/^PASS://; s/^BLOCK://')"
  echo "- worktree: $(printf '%s' "$w" | sed 's/^PASS://; s/^BLOCK://')"
  echo "- inside-work-tree: $wt"
  if [ -z "$blocked" ]; then echo "## Verdict: **ISOLATED** — safe to proceed."; return 0
  else echo "## Verdict: **BLOCKED** —$blocked stop condition(s); halt and ask."; return 1; fi
}

# ---------------------------------------------------------------- self-test (temp repos; $TMPDIR; no destructive git)
self_test() {
  local P=0 F=0; ok(){ echo "  PASS $1"; P=$((P+1)); }; no(){ echo "  FAIL $1"; F=$((F+1)); }
  local TT; TT="$(mktemp -d)"; trap 'rm -rf "$TT"' RETURN
  local PRE; PRE="$(git -C "$ROOTDIR" status --porcelain 2>/dev/null | md5)"
  mk(){ git -C "$1" init -q; git -C "$1" config user.email t@t.t; git -C "$1" config user.name t; echo base > "$1/f"; git -C "$1" add -A; GIT_AUTHOR_DATE='2020-01-01T00:00:00 +0000' GIT_COMMITTER_DATE='2020-01-01T00:00:00 +0000' git -C "$1" commit -q -m base; }

  # R1: on main + clean => BLOCK (branch-is-main)
  local R1="$TT/r1"; mkdir -p "$R1"; mk "$R1"; git -C "$R1" branch -M main
  run_guard "$R1" 0 "" >/dev/null; [ $? = 1 ] && ok "AC1 on main + clean => BLOCKED (autonomous edit on main blocked)" || no "AC1 main not blocked"
  # R1b: on main + --closure => ISOLATED (closure append-only allowed)
  run_guard "$R1" 1 "" >/dev/null; [ $? = 0 ] && ok "AC2 on main + closure => ISOLATED (append-only closure permitted)" || no "AC2 closure not allowed"

  # R2: dedicated branch + clean => ISOLATED
  local R2="$TT/r2"; mkdir -p "$R2"; mk "$R2"; git -C "$R2" checkout -q -b dmc-autonomy/run-1
  run_guard "$R2" 0 "" >/dev/null; [ $? = 0 ] && ok "AC3 dedicated branch + clean => ISOLATED" || no "AC3 dedicated clean not isolated"

  # R3: dedicated branch + DIRTY (tracked change) => BLOCK (dirty-worktree)
  echo changed > "$R2/f"
  run_guard "$R2" 0 "" >/dev/null; [ $? = 1 ] && ok "AC4 dedicated branch + dirty (no scope) => BLOCKED (dirty-worktree)" || no "AC4 dirty not blocked"
  # R3b: same dirty BUT 'f' is within the approved scope => ISOLATED
  run_guard "$R2" 0 "f" >/dev/null; [ $? = 0 ] && ok "AC5 dirty only within approved scope => ISOLATED" || no "AC5 scoped-dirty blocked"
  # R3c: dirty file OUTSIDE the approved scope => BLOCK
  run_guard "$R2" 0 "other.txt" >/dev/null; [ $? = 1 ] && ok "AC6 dirty outside approved scope => BLOCKED" || no "AC6 out-of-scope dirty not blocked"
  git -C "$R2" checkout -q -- f   # restore (local, non-destructive to history)

  # R4: detached HEAD => BLOCK (no branch to commit to)
  local R4="$TT/r4"; mkdir -p "$R4"; mk "$R4"; echo two > "$R4/f"; git -C "$R4" add -A; GIT_AUTHOR_DATE='2020-01-02T00:00:00 +0000' GIT_COMMITTER_DATE='2020-01-02T00:00:00 +0000' git -C "$R4" commit -q -m two
  git -C "$R4" checkout -q --detach HEAD~1
  run_guard "$R4" 0 "" >/dev/null; [ $? = 1 ] && ok "AC7 detached HEAD => BLOCKED" || no "AC7 detached not blocked"

  # AC8 read-only / no destructive git: the real repo is byte-unchanged
  [ "$(git -C "$ROOTDIR" status --porcelain 2>/dev/null | md5)" = "$PRE" ] && ok "AC8 read-only: real repo byte-unchanged (no destructive git)" || no "AC8 repo changed"

  echo "  ---- self-test: PASS=$P FAIL=$F ----"; [ "$F" = 0 ]
}

REPO=""; CLOSURE=0; SCOPE=""; MODE=run
while [ $# -gt 0 ]; do case "$1" in
  --repo) REPO="$2"; shift 2;; --closure) CLOSURE=1; shift;; --approved-scope) SCOPE="$2"; shift 2;;
  --self-test) MODE=selftest; shift;; -h|--help) sed -n '2,9p' "$0"; exit 0;;
  *) echo "branch-isolation-guard: unknown arg $1" >&2; exit 2;;
esac; done
if [ "$MODE" = selftest ]; then echo "==== DMC BRANCH/WORKTREE ISOLATION GUARD — SELF-TEST ===="; self_test; exit $?; fi
REPO="${REPO:-$ROOTDIR}"
run_guard "$REPO" "$CLOSURE" "$SCOPE"; exit $?
