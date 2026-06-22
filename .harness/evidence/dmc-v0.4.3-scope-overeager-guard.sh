#!/usr/bin/env bash
# DMC Scope / Over-eager Guard (v0.4.3) — ADVISORY / READ-ONLY, fail-closed.
#
# Classifies a changeset against an active plan's approved scope + over-eager bounds as ALLOWED / SUSPICIOUS / BLOCKED.
# Over-eager agent behavior is a first-class failure mode: this is a static/diff guard, NOT prompt discipline. It uses
# names-only / --numstat git (no content dump) for classification; for the branch-mutation scan it greps the diff
# quietly (value-blind — never echoes a matched line); the output is paths + counts + classifications ONLY.
#
# BLOCKED on: a path outside the approved scope; a deletion outside scope; a protected-surface change not authorized;
#   a published-milestone-entry mutation (docs/MILESTONES.md with deletions == not append-only); a branch/review-branch
#   mutation attempt added in a script; or an over-eager bound exceeded (files / deletions / total diff lines).
#
# Usage:  scope-overeager-guard.sh [--repo <dir>] [--staged] --approved-scope <p[,p...]>
#             [--authorized-protected <p[,p...]>] [--max-files N] [--max-deletions N] [--max-lines N] [--closure]   ·   --self-test
# Exit: 0 = ALLOWED (no blocks), 1 = BLOCKED, 2 = usage.
set -u
set -o pipefail
ROOTDIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SELFPATH="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/$(basename "$0")"
PROTECTED_RE='\.claude/workers/providers/(glm-api|oauth-cli|manual-import)|provider-router\.py|/ROUTING\.md$|PROVIDER_CONTRACT\.md|WORKER_(TASK|RESULT|REVIEW)_SCHEMA\.md|\.claude/hooks|(^|/)dmc-glm-smoke$'
DANGER_GIT_RE='push[[:space:]]+(-f|--force)|push[[:space:]]+--force-with-lease|branch[[:space:]]+(-D|--delete|-d)|push[[:space:]]+[^[:space:]]*[[:space:]]*:[^[:space:]]|update-ref[[:space:]]+-d|reflog[[:space:]]+expire|filter-branch|filter-repo|push[[:space:]].*review/|push[[:space:]].*[[:space:]](-f|--force|--force-with-lease)([[:space:]]|$)|push[[:space:]].*\\[[:space:]]*$'

inscope() { # <path> <scope_csv> -> 0 if path is within an approved-scope entry (exact or dir-prefix)
  local p="$1" scope="$2" e OLDIFS="$IFS"; IFS=','
  for e in $scope; do e="${e%/}"; [ -z "$e" ] && continue; case "$p" in "$e"|"$e"/*) IFS="$OLDIFS"; return 0;; esac; done
  IFS="$OLDIFS"; return 1
}

run_guard() { # <repo> <staged:0|1> <scope> <auth_protected> <maxf> <maxd> <maxl> <closure:0|1>
  local repo="$1" staged="$2" scope="$3" authp="$4" maxf="$5" maxd="$6" maxl="$7" cl="$8"
  local DIFF=(git -C "$repo" diff); [ "$staged" = 1 ] && DIFF=(git -C "$repo" diff --cached)
  local ns; ns="$("${DIFF[@]}" --numstat 2>/dev/null)"
  local nstat; nstat="$("${DIFF[@]}" --name-status 2>/dev/null)"
  local nfiles add del; nfiles="$(printf '%s\n' "$ns" | grep -c .)"
  add="$(printf '%s\n' "$ns" | awk '$1 ~ /^[0-9]+$/{a+=$1} END{print a+0}')"
  del="$(printf '%s\n' "$ns" | awk '$2 ~ /^[0-9]+$/{d+=$2} END{print d+0}')"
  local total=$((add+del))
  local blocked="" susp="" allowed=0

  # per-file classification (names-only; never print diff content)
  local line status path
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    status="$(printf '%s' "$line" | awk '{print $1}')"
    path="$(printf '%s' "$line" | sed 's/^[A-Z][0-9]*[[:space:]]*//; s/^.* -> //')"
    if printf '%s' "$path" | grep -qE "$PROTECTED_RE"; then
      if inscope "$path" "$authp"; then susp="$susp protected-authorized:$path"
      else blocked="$blocked protected-unauthorized:$path"; fi
      continue
    fi
    case "$status" in
      D*) inscope "$path" "$scope" && allowed=$((allowed+1)) || blocked="$blocked deletion-outside-scope:$path";;
      *)  inscope "$path" "$scope" && allowed=$((allowed+1)) || blocked="$blocked outside-scope:$path";;
    esac
  done <<EOF
$nstat
EOF

  # published-milestone-entry mutation: docs/MILESTONES.md must be append-only (0 deletions) unless --closure
  local msdel; msdel="$("${DIFF[@]}" --numstat -- docs/MILESTONES.md 2>/dev/null | awk '$2 ~ /^[0-9]+$/{d+=$2} END{print d+0}')"
  if [ "${msdel:-0}" -gt 0 ] 2>/dev/null && [ "$cl" != 1 ]; then blocked="$blocked milestones-entry-mutated(non-append-only)"; fi

  # branch/review-branch mutation attempt added in a changed script (value-blind: grep -q, never echo the line)
  if "${DIFF[@]}" 2>/dev/null | grep -E '^\+' | grep -qE "$DANGER_GIT_RE"; then
    blocked="$blocked branch-mutation-attempt-in-diff"
  fi

  # over-eager bounds
  [ "${nfiles:-0}" -gt "$maxf" ] 2>/dev/null && blocked="$blocked over-bound:files=$nfiles>$maxf"
  [ "${del:-0}" -gt "$maxd" ] 2>/dev/null && blocked="$blocked over-bound:deletions=$del>$maxd"
  [ "${total:-0}" -gt "$maxl" ] 2>/dev/null && susp="$susp broad-rewrite:lines=$total>$maxl"

  echo "# DMC Scope / Over-eager Guard"
  echo "- changeset: files=$nfiles (+$add / -$del), total=$total"
  echo "- bounds: max-files=$maxf max-deletions=$maxd max-lines=$maxl ; closure=$cl"
  echo "- allowed (in-scope, within bounds): $allowed file(s)"
  [ -n "$susp" ] && echo "- SUSPICIOUS:$susp" || echo "- suspicious: none"
  [ -n "$blocked" ] && echo "- BLOCKED:$blocked" || echo "- blocked: none"
  if [ -z "$blocked" ]; then echo "## Verdict: **ALLOWED**$( [ -n "$susp" ] && echo ' (with SUSPICIOUS warnings — human review advised)' )"; return 0
  else echo "## Verdict: **BLOCKED** — fail-closed; halt and ask."; return 1; fi
}

# ---------------------------------------------------------------- self-test (temp repo; $TMPDIR)
self_test() {
  local P=0 F=0; ok(){ echo "  PASS $1"; P=$((P+1)); }; no(){ echo "  FAIL $1"; F=$((F+1)); }
  local TT; TT="$(mktemp -d)"; trap 'rm -rf "$TT"' RETURN
  local PRE; PRE="$(git -C "$ROOTDIR" status --porcelain 2>/dev/null | md5)"
  local R="$TT/r"; mkdir -p "$R/src" "$R/docs"; git -C "$R" init -q; git -C "$R" config user.email t@t.t; git -C "$R" config user.name t
  printf 'a\nb\nc\n' > "$R/src/app.js"; printf 'x\n' > "$R/src/other.js"; printf 'line\n' > "$R/docs/keep.md"
  printf '# Milestones\n\n## v1 done\n' > "$R/docs/MILESTONES.md"; mkdir -p "$R/.claude/workers/providers"; printf 'r\n' > "$R/.claude/workers/providers/provider-router.py"
  git -C "$R" add -A; GIT_AUTHOR_DATE='2020-01-01T00:00:00 +0000' GIT_COMMITTER_DATE='2020-01-01T00:00:00 +0000' git -C "$R" commit -q -m base
  local SCOPE="src/app.js,docs/MILESTONES.md"

  # AC1 in-scope edit within bounds => ALLOWED (exit 0)
  printf 'a\nb\nc\nd\n' > "$R/src/app.js"
  run_guard "$R" 0 "$SCOPE" "" 25 200 800 0 >/dev/null; [ $? = 0 ] && ok "AC1 in-scope edit within bounds => ALLOWED" || no "AC1 in-scope not allowed"
  git -C "$R" checkout -q -- .

  # AC2 unrelated file (outside scope) touched => BLOCKED
  printf 'x\ny\n' > "$R/src/other.js"
  run_guard "$R" 0 "$SCOPE" "" 25 200 800 0 >/dev/null; [ $? = 1 ] && ok "AC2 unrelated file outside scope => BLOCKED" || no "AC2 not blocked"
  git -C "$R" checkout -q -- .

  # AC3 deletion outside allowed scope => BLOCKED
  git -C "$R" rm -q docs/keep.md
  run_guard "$R" 1 "$SCOPE" "" 25 200 800 0 >/dev/null; [ $? = 1 ] && ok "AC3 deletion outside scope => BLOCKED" || no "AC3 deletion not blocked"
  git -C "$R" reset -q --hard 2>/dev/null

  # AC4 broad rewrite within scope => ALLOWED but SUSPICIOUS (low max-lines bound)
  seq 1 50 > "$R/src/app.js"
  local out; out="$(run_guard "$R" 0 "$SCOPE" "" 25 200 5 0)"; local rc=$?
  { [ $rc = 0 ] && printf '%s' "$out" | grep -q 'SUSPICIOUS:.*broad-rewrite'; } && ok "AC4 broad rewrite within scope => ALLOWED + SUSPICIOUS(broad-rewrite)" || no "AC4 broad-rewrite not flagged"
  git -C "$R" checkout -q -- .

  # AC5 published-milestone-entry mutation (deletion in MILESTONES.md) => BLOCKED; append-only => ALLOWED
  printf '# Milestones\n\n## v1 DONE-edited\n' > "$R/docs/MILESTONES.md"   # mutates an existing line (deletion)
  run_guard "$R" 0 "$SCOPE" "" 25 200 800 0 >/dev/null; local m1=$?
  git -C "$R" checkout -q -- docs/MILESTONES.md
  printf '# Milestones\n\n## v1 done\n\n## v2 done\n' > "$R/docs/MILESTONES.md"   # append-only
  run_guard "$R" 0 "$SCOPE" "" 25 200 800 0 >/dev/null; local m2=$?
  { [ $m1 = 1 ] && [ $m2 = 0 ]; } && ok "AC5 MILESTONES.md mutated => BLOCKED; append-only => ALLOWED" || no "AC5 milestones append-only (m1=$m1 m2=$m2)"
  git -C "$R" checkout -q -- docs/MILESTONES.md

  # AC6 protected-surface change: unauthorized => BLOCKED; authorized (in --authorized-protected) => SUSPICIOUS not blocked
  printf 'r\nchanged\n' > "$R/.claude/workers/providers/provider-router.py"
  run_guard "$R" 0 "$SCOPE" "" 25 200 800 0 >/dev/null; local p1=$?
  run_guard "$R" 0 "$SCOPE" ".claude/workers/providers/provider-router.py" 25 200 800 0 >/dev/null; local p2=$?
  { [ $p1 = 1 ] && [ $p2 = 0 ]; } && ok "AC6 protected change: unauthorized=>BLOCKED, authorized=>allowed(SUSPICIOUS)" || no "AC6 protected (p1=$p1 p2=$p2)"
  git -C "$R" checkout -q -- .

  # AC7 branch/review-branch mutation attempt added in a script => BLOCKED (value-blind scan)
  printf 'a\nb\nc\ngit push --force origin review/some-branch\n' > "$R/src/app.js"
  run_guard "$R" 0 "$SCOPE" "" 25 200 800 0 >/dev/null; [ $? = 1 ] && ok "AC7 branch-mutation attempt (force push / review/) in diff => BLOCKED" || no "AC7 branch-mutation not blocked"
  git -C "$R" checkout -q -- .

  # AC8 over-eager file-count bound exceeded => BLOCKED
  local i; for i in $(seq 1 30); do echo x > "$R/src/f$i.js"; done; git -C "$R" add -A
  run_guard "$R" 1 "src/" "" 25 200 100000 0 >/dev/null; [ $? = 1 ] && ok "AC8 over-eager: file-count bound exceeded => BLOCKED" || no "AC8 file-count not blocked"
  git -C "$R" reset -q --hard 2>/dev/null

  # AC10 (F5) force flag AFTER refspec => BLOCKED (not just adjacent to 'push')
  printf 'a\nb\nc\ngit push origin main --force\n' > "$R/src/app.js"
  run_guard "$R" 0 "$SCOPE" "" 25 200 800 0 >/dev/null; [ $? = 1 ] && ok "AC10 force flag after refspec (git push origin main --force) => BLOCKED" || no "AC10 force-after-refspec not blocked"
  git -C "$R" checkout -q -- .

  # AC11 (F5) --force-with-lease after refspec => BLOCKED
  printf 'a\nb\nc\ngit push origin review/foo --force-with-lease\n' > "$R/src/app.js"
  run_guard "$R" 0 "$SCOPE" "" 25 200 800 0 >/dev/null; [ $? = 1 ] && ok "AC11 --force-with-lease after refspec => BLOCKED" || no "AC11 force-with-lease not blocked"
  git -C "$R" checkout -q -- .

  # AC12 (F5) git push split across a line-continuation => BLOCKED
  printf 'a\nb\nc\ngit push \\\n  --force origin main\n' > "$R/src/app.js"
  run_guard "$R" 0 "$SCOPE" "" 25 200 800 0 >/dev/null; [ $? = 1 ] && ok "AC12 git push line-continuation (push \\ + --force) => BLOCKED" || no "AC12 line-continuation not blocked"
  git -C "$R" checkout -q -- .

  # AC13 (F7) trailing-slash scope entry normalized => in-scope edit ALLOWED
  printf 'a\nb\nc\nd\n' > "$R/src/app.js"
  run_guard "$R" 0 "src/" "" 25 200 800 0 >/dev/null; [ $? = 0 ] && ok "AC13 trailing-slash scope 'src/' => in-scope edit ALLOWED" || no "AC13 trailing-slash wrongly blocked"
  git -C "$R" checkout -q -- .

  # AC14 (F7) MILESTONES.md mutation WITH --closure => ALLOWED (closure append/edit authorized)
  printf '# Milestones\n\n## v1 DONE-edited\n' > "$R/docs/MILESTONES.md"
  run_guard "$R" 0 "$SCOPE" "" 25 200 800 1 >/dev/null; [ $? = 0 ] && ok "AC14 MILESTONES.md mutation under --closure => ALLOWED" || no "AC14 --closure not honored"
  git -C "$R" checkout -q -- docs/MILESTONES.md

  # AC9 read-only: real repo byte-unchanged
  [ "$(git -C "$ROOTDIR" status --porcelain 2>/dev/null | md5)" = "$PRE" ] && ok "AC9 read-only: real repo byte-unchanged" || no "AC9 repo changed"

  echo "  ---- self-test: PASS=$P FAIL=$F ----"; [ "$F" = 0 ]
}

REPO=""; STAGED=0; SCOPE=""; AUTHP=""; MAXF=25; MAXD=200; MAXL=800; CL=0; MODE=run
while [ $# -gt 0 ]; do case "$1" in
  --repo) REPO="$2"; shift 2;; --staged) STAGED=1; shift;; --approved-scope) SCOPE="$2"; shift 2;;
  --authorized-protected) AUTHP="$2"; shift 2;; --max-files) MAXF="$2"; shift 2;; --max-deletions) MAXD="$2"; shift 2;;
  --max-lines) MAXL="$2"; shift 2;; --closure) CL=1; shift;; --self-test) MODE=selftest; shift;;
  -h|--help) sed -n '2,14p' "$0"; exit 0;; *) echo "scope-overeager-guard: unknown arg $1" >&2; exit 2;;
esac; done
if [ "$MODE" = selftest ]; then echo "==== DMC SCOPE / OVER-EAGER GUARD — SELF-TEST ===="; self_test; exit $?; fi
REPO="${REPO:-$ROOTDIR}"
[ -n "$SCOPE" ] || { echo "scope-overeager-guard: --approved-scope required" >&2; exit 2; }
run_guard "$REPO" "$STAGED" "$SCOPE" "$AUTHP" "$MAXF" "$MAXD" "$MAXL" "$CL"; exit $?
