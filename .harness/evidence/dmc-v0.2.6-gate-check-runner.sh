#!/usr/bin/env bash
# DMC Gate Check Runner (v0.2.6) — READ-ONLY / REPORT-ONLY.
#
# Standardizes DMC's pre-stage / pre-commit / pre-push reviews into one command that INFORMS the human Release Gate
# with a PASS/FAIL summary. It NEVER stages, commits, pushes, mutates files, or grants a gate. The only writes that
# occur anywhere are inside throwaway temp repos created by --self-test (the real/target repo index is never touched).
#
# Usage:
#   dmc-v0.2.6-gate-check-runner.sh --allowlist <file> [--repo <dir>] [--gate stage|commit|push]
#   dmc-v0.2.6-gate-check-runner.sh --self-test
#
# Exit code: 0 = all checks PASS, 1 = at least one FAIL. The exit code is an ADVISORY report signal for the human /
# Codex auditor — it is NOT an action and must never be wired to stage/commit/push/block.
set -u

# Default excluded auto-logged evidence files (overridable via DMC_GATE_EXCLUDED, newline-separated).
DEFAULT_EXCLUDED='.harness/evidence/dmc-v0.2.2-oauth-cli-adapter.md
.harness/evidence/dmc-v0.2.3-provider-routing.md
.harness/evidence/dmc-v0.2.4-provider-contract-tests.md
.harness/evidence/dmc-v0.2.5-agent-operating-handbook.md'
# Default protected paths (overridable via DMC_GATE_PROTECTED, newline-separated).
DEFAULT_PROTECTED='.claude/workers/providers/glm-api
.claude/workers/providers/oauth-cli
.claude/workers/providers/provider-router.py
.claude/workers/providers/ROUTING.md
.claude/hooks
WORKER_TASK_SCHEMA.md
WORKER_RESULT_SCHEMA.md
WORKER_REVIEW_SCHEMA.md
dmc-glm-smoke'

# run_checks <repo> <allowlist-file> <gate> -> prints G1..G6 lines; returns 0 if all PASS else 1. READ-ONLY.
run_checks() {
  local repo="$1" allow_file="$2" gate="$3" fail=0
  local excluded="${DMC_GATE_EXCLUDED:-$DEFAULT_EXCLUDED}"
  local protected="${DMC_GATE_PROTECTED:-$DEFAULT_PROTECTED}"
  local upstream="${DMC_GATE_UPSTREAM:-origin/main}"
  local staged; staged="$(git -C "$repo" diff --cached --name-only)"
  local allow;  allow="$(grep -vE '^\s*(#|$)' "$allow_file" 2>/dev/null || true)"

  # G1 staged ⊆ allowlist
  local extra=""
  while IFS= read -r f; do [ -z "$f" ] && continue; printf '%s\n' "$allow" | grep -qxF "$f" || extra="$extra $f"; done <<< "$staged"
  if [ -z "${extra// /}" ]; then echo "  G1 PASS staged ⊆ allowlist"; else echo "  G1 FAIL staged not in allowlist:$extra"; fail=1; fi

  # G2 allowlist fully staged
  local missing=""
  while IFS= read -r f; do [ -z "$f" ] && continue; printf '%s\n' "$staged" | grep -qxF "$f" || missing="$missing $f"; done <<< "$allow"
  if [ -z "${missing// /}" ]; then echo "  G2 PASS allowlist fully staged"; else echo "  G2 FAIL approved files not staged:$missing"; fail=1; fi

  # G3 no excluded-evidence file staged
  local exhit=""
  while IFS= read -r e; do [ -z "$e" ] && continue; printf '%s\n' "$staged" | grep -qxF "$e" && exhit="$exhit $e"; done <<< "$excluded"
  if [ -z "${exhit// /}" ]; then echo "  G3 PASS no excluded-evidence file staged"; else echo "  G3 FAIL excluded evidence staged:$exhit"; fail=1; fi

  # G4 no protected-path change (staged OR worktree-modified)
  local prothit=""
  while IFS= read -r p; do [ -z "$p" ] && continue
    [ -n "$(git -C "$repo" status --porcelain -- "$p" 2>/dev/null)" ] && prothit="$prothit $p"; done <<< "$protected"
  if [ -z "${prothit// /}" ]; then echo "  G4 PASS no protected-path change"; else echo "  G4 FAIL protected path changed:$prothit"; fail=1; fi

  # G5 git diff --cached --check clean
  if git -C "$repo" diff --cached --check >/dev/null 2>&1; then echo "  G5 PASS diff --cached --check clean"; else echo "  G5 FAIL whitespace/conflict-marker issue in staged diff"; fail=1; fi

  # G6 ahead/behind report (push gate: must not be behind)
  if git -C "$repo" rev-parse "$upstream" >/dev/null 2>&1; then
    local lr; lr="$(git -C "$repo" rev-list --left-right --count "$upstream"...HEAD 2>/dev/null)"
    local behind="${lr%%[	 ]*}" ahead="${lr##*[	 ]}"
    echo "  G6 INFO ahead=$ahead behind=$behind (vs $upstream)"
    if [ "$gate" = push ] && [ "${behind:-0}" != 0 ]; then echo "  G6 FAIL push gate: HEAD is behind $upstream by $behind"; fail=1; fi
  else
    echo "  G6 INFO upstream '$upstream' not found"
    [ "$gate" = push ] && { echo "  G6 FAIL push gate: cannot confirm not-behind (no upstream)"; fail=1; }
  fi
  return $fail
}

gate_report() {
  local repo="$1" allow_file="$2" gate="$3"
  [ -d "$repo/.git" ] || git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || { echo "gate-check: '$repo' is not a git repo" >&2; return 2; }
  [ -f "$allow_file" ] || { echo "gate-check: --allowlist file not found: $allow_file" >&2; return 2; }
  echo "==== DMC GATE CHECK (gate=$gate, repo=$repo) — READ-ONLY / ADVISORY ===="
  run_checks "$repo" "$allow_file" "$gate"; local rc=$?
  echo "==== SUMMARY: $([ $rc = 0 ] && echo 'PASS — all gate checks green (Release Gate may proceed)' || echo 'FAIL — at least one gate check is red (Release Gate review required)') ===="
  echo "NOTE: this runner is advisory and read-only; it stages/commits/pushes nothing and grants no gate."
  return $rc
}

# ---------------------------------------------------------------- self-test (temp-repo only; real repo untouched)
self_test() {
  local P=0 F=0
  ok(){ echo "  PASS $1"; P=$((P+1)); }
  no(){ echo "  FAIL $1"; F=$((F+1)); }
  local TT; TT="$(mktemp -d)"; trap 'rm -rf "$TT"' RETURN
  mkrepo(){ local d="$TT/$1"; mkdir -p "$d"; ( cd "$d" && git init -q && git config user.email t@t && git config user.name t \
    && git commit -q --allow-empty -m init ); echo "$d"; }
  expect(){ # <label> <repo> <allowlist> <gate> <want PASS|FAIL>
    run_checks "$2" "$3" "$4" >/dev/null 2>&1 && local got=PASS || local got=FAIL
    [ "$got" = "$5" ] && ok "$1 ($got)" || no "$1 (got $got want $5)"; }

  # S1 clean: stage exactly allowlist -> PASS
  local r; r="$(mkrepo clean)"; ( cd "$r" && echo a > a.txt && git add a.txt )
  printf '%s\n' 'a.txt' > "$TT/allow1"; expect "G7/S1 clean -> PASS" "$r" "$TT/allow1" commit PASS
  # S2 extra staged file -> G1 FAIL
  ( cd "$r" && echo b > b.txt && git add b.txt ); expect "S2 extra file -> FAIL" "$r" "$TT/allow1" commit FAIL
  # S3 missing approved file -> G2 FAIL
  printf '%s\n' 'a.txt' 'zzz-missing.txt' > "$TT/allow3"; local r3; r3="$(mkrepo miss)"; ( cd "$r3" && echo a > a.txt && git add a.txt )
  expect "S3 missing approved -> FAIL" "$r3" "$TT/allow3" commit FAIL
  # S4 excluded evidence staged -> G3 FAIL
  local r4; r4="$(mkrepo excl)"; ( cd "$r4" && mkdir -p .harness/evidence && echo x > .harness/evidence/dmc-v0.2.2-oauth-cli-adapter.md && git add .harness/evidence/dmc-v0.2.2-oauth-cli-adapter.md )
  printf '%s\n' '.harness/evidence/dmc-v0.2.2-oauth-cli-adapter.md' > "$TT/allow4"  # even if "allowed", excluded list wins
  expect "S4 excluded evidence staged -> FAIL" "$r4" "$TT/allow4" commit FAIL
  # S5 protected path changed -> G4 FAIL
  local r5; r5="$(mkrepo prot)"; ( cd "$r5" && mkdir -p .claude/workers/providers && echo x > .claude/workers/providers/provider-router.py && git add .claude/workers/providers/provider-router.py )
  printf '%s\n' '.claude/workers/providers/provider-router.py' > "$TT/allow5"
  expect "S5 protected path changed -> FAIL" "$r5" "$TT/allow5" commit FAIL
  # S6 whitespace issue -> G5 FAIL
  local r6; r6="$(mkrepo ws)"; ( cd "$r6" && printf 'line with trailing space \n' > w.txt && git add w.txt )
  printf '%s\n' 'w.txt' > "$TT/allow6"; expect "S6 trailing-whitespace -> FAIL" "$r6" "$TT/allow6" commit FAIL
  # S7 push gate behind upstream -> G6 FAIL
  local r7; r7="$(mkrepo push)"; ( cd "$r7" && echo a > a.txt && git add a.txt && git commit -q -m a \
    && git branch up && git checkout -q up && git commit -q --allow-empty -m ahead && git checkout -q main \
    && git branch --set-upstream-to=up main >/dev/null 2>&1 )
  printf '%s\n' > "$TT/allow7"   # empty allowlist; nothing staged
  DMC_GATE_UPSTREAM=up expect "S7 push gate behind upstream -> FAIL" "$r7" "$TT/allow7" push FAIL
  DMC_GATE_UPSTREAM=up expect "S7b commit gate behind upstream -> PASS (behind not fatal off-push)" "$r7" "$TT/allow7" commit PASS

  echo "  ---- self-test: PASS=$P FAIL=$F ----"
  [ "$F" = 0 ]
}

# ---------------------------------------------------------------- arg parsing
ALLOWLIST=""; REPO="."; GATE="commit"; MODE="report"
while [ $# -gt 0 ]; do case "$1" in
  --allowlist) ALLOWLIST="$2"; shift 2;;
  --repo) REPO="$2"; shift 2;;
  --gate) GATE="$2"; shift 2;;
  --self-test) MODE="selftest"; shift;;
  -h|--help) sed -n '2,17p' "$0"; exit 0;;
  *) echo "gate-check: unknown arg $1" >&2; exit 2;;
esac; done

if [ "$MODE" = selftest ]; then
  echo "==== DMC GATE CHECK RUNNER — SELF-TEST (temp-repo only; real repo untouched) ===="
  self_test; exit $?
fi
[ -n "$ALLOWLIST" ] || { echo "gate-check: --allowlist <file> is required for a gate report" >&2; exit 2; }
gate_report "$REPO" "$ALLOWLIST" "$GATE"; exit $?
