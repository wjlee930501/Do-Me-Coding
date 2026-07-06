#!/usr/bin/env bash
# _m6common.sh — shared helpers for the DMC v1 M6 hook-hardening suites
# (test-adversarial.sh, test-compat.sh, test-e2e-ultrawork.sh).
#
# Nature: TEST SUPPORT. Sourced, never run directly. Provides:
#   - repo-root + PASS/FAIL bookkeeping shared by every suite,
#   - a real-repo porcelain-before/after guard (proves the suites leave the
#     live repo byte-identical — all writes land in mktemp sandboxes),
#   - tool-JSON builders (Bash/Edit/Write/Read/Grep/Glob) + hook drivers that
#     invoke the ACTUAL .claude/hooks/*.sh with a synthetic CLAUDE_PROJECT_DIR,
#   - an `arm_fixture` that arms a disposable repo through the REAL Ring-0 path
#     (`dmc run start` -> `dmc-scope-lock --compile`), so the suites exercise
#     production arming, not a hand-forged lock.
#
# Never reads .env / credentials; never mutates the live repo; no network /
# live / model / API call. Every hook call is pinned to a mktemp project dir.

# Refuse direct execution — this is a library.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  echo "_m6common.sh is a sourced library, not a standalone test" >&2
  exit 2
fi

# ---- repo root + Ring-0 handles ------------------------------------------------
# Resolve from THIS file's location: tests/fixtures/m6/_m6common.sh -> repo root.
_M6_COMMON_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P) \
  || { echo "FATAL: cannot resolve _m6common dir" >&2; exit 2; }
M6_ROOT=$(cd -- "$_M6_COMMON_DIR/../../.." >/dev/null 2>&1 && pwd -P) \
  || { echo "FATAL: cannot resolve repo root" >&2; exit 2; }
M6_DMC="$M6_ROOT/bin/dmc"
M6_HOOKS="$M6_ROOT/.claude/hooks"
M6_SCOPELOCK="$M6_ROOT/bin/lib/dmc-scope-lock.py"

# ---- PASS/FAIL bookkeeping (house style, mirrors test-rollback.sh) -------------
PASS=0; FAIL=0
record() { # record PASS|FAIL DESC
  if [ "$1" = PASS ]; then PASS=$((PASS+1)); printf '  [PASS] %s\n' "$2"
  else FAIL=$((FAIL+1)); printf '  [FAIL] %s\n' "$2"; fi
}
# assert_eq EXPECTED ACTUAL DESC
assert_eq() { [ "$1" = "$2" ] && record PASS "$3" || record FAIL "$3 (want [$1] got [$2])"; }

# ---- real-repo cleanliness guard ----------------------------------------------
# Snapshot the LIVE repo's porcelain at start; re-check at the end. The suites
# must not perturb a single tracked/untracked byte of the real tree.
M6_PORCELAIN_BEFORE=""
m6_capture_before() {
  M6_PORCELAIN_BEFORE=$(git -C "$M6_ROOT" status --porcelain 2>/dev/null)
}
m6_assert_repo_untouched() {
  local after; after=$(git -C "$M6_ROOT" status --porcelain 2>/dev/null)
  [ "$M6_PORCELAIN_BEFORE" = "$after" ] \
    && record PASS "real repo byte-identical: git status --porcelain unchanged by the suite" \
    || record FAIL "real repo CHANGED during the suite (porcelain drift — a write escaped the sandbox)"
}

# ---- JSON + hook drivers -------------------------------------------------------
json_str() { python3 -c 'import json,sys;print(json.dumps(sys.argv[1]))' "$1"; }

bash_input()  { printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$(json_str "$1")"; }
edit_input()  { printf '{"tool_name":"Edit","cwd":%s,"tool_input":{"file_path":%s}}' \
                       "$(json_str "$2")" "$(json_str "$1")"; }
write_input() { printf '{"tool_name":"Write","cwd":%s,"tool_input":{"file_path":%s}}' \
                       "$(json_str "$2")" "$(json_str "$1")"; }
read_input()  { printf '{"tool_name":"Read","tool_input":{"file_path":%s}}' "$(json_str "$1")"; }
glob_input()  { printf '{"tool_name":"Glob","tool_input":{"pattern":%s}}' "$(json_str "$1")"; }
# grep with a directory (path) + a content regex (pattern)
grep_input()  { printf '{"tool_name":"Grep","tool_input":{"pattern":%s,"path":%s}}' \
                       "$(json_str "$1")" "$(json_str "$2")"; }
bash_post_input() { printf '{"tool_name":"Bash","cwd":%s,"tool_input":{"command":%s}}' \
                       "$(json_str "$2")" "$(json_str "$1")"; }

# hook_run HOOK_BASENAME JSON PROJECT_DIR [EXTRA_ENV...]  -> prints hook stdout
# Always pins CLAUDE_PROJECT_DIR so the hook never falls back to the caller's PWD.
hook_run() {
  local hook="$1" json="$2" proj="$3"; shift 3
  printf '%s' "$json" | env "$@" CLAUDE_PROJECT_DIR="$proj" bash "$M6_HOOKS/$hook"
}

# PreToolUse verdict: permissionDecision (deny/ask), or "allow" when stdout empty.
# Tolerant of optional whitespace after the colon: the printf-based hooks emit
# `"permissionDecision":"deny"` while the python-json hooks emit `": "`.
decision_of() {
  local out="$1" d
  d=$(printf '%s' "$out" | sed -n 's/.*"permissionDecision":[[:space:]]*"\([a-z]*\)".*/\1/p')
  [ -n "$d" ] && printf '%s' "$d" || printf 'allow'
}
# Stop / PostToolUse verdict: decision (block), or "pass" when stdout empty.
stop_decision_of() {
  local out="$1" d
  d=$(printf '%s' "$out" | sed -n 's/.*"decision":[[:space:]]*"\([a-z]*\)".*/\1/p')
  [ -n "$d" ] && printf '%s' "$d" || printf 'pass'
}

# ---- fixture builders ----------------------------------------------------------
m6_write_plan() { # FILE PLAN_ID APPROVER
  cat > "$1" <<EOF
# Plan: M6 fixture ($2)

Plan ID: $2

## Goal
g
## User Intent
feature
## Current Repo Findings
- Finding: f
  Source: s
## Relevant Files
| Path | Reason | Allowed to Edit |
|---|---|---|
| src/app.py | r | yes |
## Out of Scope
- x
## Proposed Changes
- Change: c
  Files: src/app.py
  Rationale: r
## Acceptance Criteria
- Criterion: c
  Verification Method: m
## Risks
| Risk | Severity | Mitigation |
|---|---|---|
| r | low | m |
## Assumptions
| Assumption | Confidence | How to Verify |
|---|---|---|
| a | high | v |
## Execution Tasks
- [ ] DMC-T001: t
  Files: src/app.py
  Notes: n
## Verification Commands
| Command | Reason | Required |
|---|---|---|
| c | r | yes |
## Approval Status
Status: APPROVED
Approver: $3
Approved At: 2026-07-06
EOF
}

m6_write_landmarks() { # FILE
  cat > "$1" <<'EOF'
{
  "files": [
    {"path": "src/app.py", "grant": "edit", "landmark_class": "ordinary"},
    {"path": "src/new_mod.py", "grant": "create", "landmark_class": "ordinary"}
  ],
  "bounds": {"max_files": 5, "max_added": 500, "max_deleted": 200, "forbidden_hunk_classes": []}
}
EOF
}

# mk_repo TMP  — a committed git repo baseline (plan + landmarks tracked), UNARMED.
mk_repo() { # TMP [PLAN_ID] [APPROVER]
  local tmp="$1" planid="${2:-dmc-m6-fixture}" approver="${3:-M6-FIXTURE}"
  git init -q "$tmp" || return 1
  git -C "$tmp" config user.email t@example.com
  git -C "$tmp" config user.name "M6 Fixture"
  mkdir -p "$tmp/src"
  printf 'print("app")\n' > "$tmp/src/app.py"
  printf '# fixture repo\n' > "$tmp/README.md"
  printf '.harness/runs/current-*\n' > "$tmp/.gitignore"
  m6_write_plan "$tmp/plan.md" "$planid" "$approver"
  m6_write_landmarks "$tmp/landmarks.json"
  git -C "$tmp" add -A
  git -C "$tmp" commit -q -m baseline
}

# arm_fixture TMP  — arm a committed repo through the REAL Ring-0 path; echoes RID.
# Two-step production arming: `dmc run start` (mints run-id + snapshot.txt) then
# `dmc-scope-lock --compile` (immutable lock + write-once operative snapshot).
arm_fixture() { # TMP [PLAN_ID] [APPROVER]
  local tmp="$1" planid="${2:-dmc-m6-fixture}" approver="${3:-M6-FIXTURE}"
  mk_repo "$tmp" "$planid" "$approver" || return 1
  "$M6_DMC" run start --plan "$tmp/plan.md" --root "$tmp" >/dev/null 2>&1 || return 1
  local rid; rid=$(cat "$tmp/.harness/runs/current-run-id" 2>/dev/null)
  [ -n "$rid" ] || return 1
  python3 "$M6_SCOPELOCK" --compile --plan "$tmp/plan.md" --landmarks "$tmp/landmarks.json" \
    --run-id "$rid" --root "$tmp" >/dev/null 2>&1 || return 1
  [ -f "$tmp/.harness/runs/$rid/scope.lock.json" ] || return 1
  printf '%s' "$rid"
}

# m6_write_pass_report FILE RID  — a crosscheck-passing verification report.
m6_write_pass_report() { # FILE RUN_ID
  cat > "$1" <<EOF
# Verification Report

## Run ID
$2
## Plan
plan.md
## Changed Files
- src/app.py: edited
## Commands Run
| Command | Result | Reason | Output Summary |
|---|---|---|---|
| pytest | PASS | ran | ok |
## Manual Checks
| Check | Result | Notes |
|---|---|---|
| review | PASS | n |
## Scope Review
Result: PASS

Notes:
## Package / Env / Migration Review
Package files changed: no
Env files changed: no
Migration files changed: no

Notes:
## Unresolved Risks
- none
## Final Status
PASS
EOF
}
