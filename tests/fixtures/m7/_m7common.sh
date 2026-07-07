#!/usr/bin/env bash
# _m7common.sh — shared helpers for the DMC v1 M7 worker/delegation-hardening suites
# (test-worker-adversarial.sh, test-worker-chain.sh, test-delegation-records.sh).
#
# Nature: TEST SUPPORT. Sourced, never run directly. Provides:
#   - repo-root + Ring-0/worker handles resolved from THIS file's location,
#   - PASS/FAIL bookkeeping (record/assert_* house style, mirrors _m6common.sh),
#   - a real-repo porcelain-before/after guard (proves the suites leave the live
#     repo byte-identical — every write lands in a mktemp sandbox),
#   - a "no new __pycache__ under the never-edit providers tree" assertion (the
#     negative control for the mandated sys.dont_write_bytecode import discipline),
#   - an `m7_arm_scope_lock` that arms a disposable committed repo through the REAL
#     Ring-0 path (`dmc run start` -> `dmc-scope-lock.py --compile`) so the chain
#     suite exercises a production-compiled scope.lock, never a hand-forged one.
#
# Never reads .env / credentials; never mutates the live repo; no network / live /
# model / API call. Every worker/scope-lock call is pinned to a mktemp sandbox.

# Refuse direct execution — this is a library.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  echo "_m7common.sh is a sourced library, not a standalone test" >&2
  exit 2
fi

# ---- repo root + control-plane handles -----------------------------------------
# Resolve from THIS file's location: tests/fixtures/m7/_m7common.sh -> repo root.
_M7_COMMON_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P) \
  || { echo "FATAL: cannot resolve _m7common dir" >&2; exit 2; }
M7_ROOT=$(cd -- "$_M7_COMMON_DIR/../../.." >/dev/null 2>&1 && pwd -P) \
  || { echo "FATAL: cannot resolve repo root" >&2; exit 2; }
M7_DMC="$M7_ROOT/bin/dmc"
M7_HOOKS="$M7_ROOT/.claude/hooks"
M7_RESULTCHECK="$M7_HOOKS/worker-result-check.py"
M7_CTXGUARD="$M7_HOOKS/worker-context-guard.sh"
M7_PROVIDERS="$M7_ROOT/.claude/workers/providers"
M7_SCOPELOCK="$M7_ROOT/bin/lib/dmc-scope-lock.py"
M7_DELEGLIB="$M7_ROOT/bin/lib/dmc-delegation.py"

# ---- PASS/FAIL bookkeeping (house style, mirrors _m6common.sh) ------------------
PASS=0; FAIL=0
record() { # record PASS|FAIL DESC
  if [ "$1" = PASS ]; then PASS=$((PASS+1)); printf '  [PASS] %s\n' "$2"
  else FAIL=$((FAIL+1)); printf '  [FAIL] %s\n' "$2"; fi
}
# assert_eq EXPECTED ACTUAL DESC
assert_eq() { [ "$1" = "$2" ] && record PASS "$3" || record FAIL "$3 (want [$1] got [$2])"; }
# assert_contains HAYSTACK NEEDLE DESC
assert_contains()     { case "$1" in *"$2"*) record PASS "$3" ;; *) record FAIL "$3 (missing [$2])" ;; esac; }
# assert_not_contains HAYSTACK NEEDLE DESC
assert_not_contains() { case "$1" in *"$2"*) record FAIL "$3 (found [$2])" ;; *) record PASS "$3" ;; esac; }

# ---- real-repo cleanliness guard (mirrors _m6common.sh) ------------------------
M7_PORCELAIN_BEFORE=""
m7_capture_before() { M7_PORCELAIN_BEFORE=$(git -C "$M7_ROOT" status --porcelain 2>/dev/null); }
m7_assert_repo_untouched() {
  local after; after=$(git -C "$M7_ROOT" status --porcelain 2>/dev/null)
  [ "$M7_PORCELAIN_BEFORE" = "$after" ] \
    && record PASS "real repo byte-identical: git status --porcelain unchanged by the suite" \
    || record FAIL "real repo CHANGED during the suite (porcelain drift — a write escaped the sandbox)"
}

# ---- no-__pycache__ under the never-edit providers tree ------------------------
# The two validators + the review CLI import the shared token detectors from the
# providers tree via importlib with sys.dont_write_bytecode=True; a stray
# __pycache__ there would be an import-discipline regression (and would also trip
# the porcelain guard). Assert none appears after the runs.
m7_assert_no_provider_pycache() {
  local hits; hits=$(find "$M7_PROVIDERS" -type d -name __pycache__ 2>/dev/null | wc -l | tr -d ' ')
  assert_eq 0 "$hits" "no __pycache__ written under .claude/workers/providers/ (dont_write_bytecode honored)"
}

# ---- disposable armed-repo builder (real Ring-0 path; writes only in TMP) -------
_m7_write_plan() { # FILE PLAN_ID
  cat > "$1" <<EOF
# Plan: M7 fixture ($2)

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
Approver: M7-FIXTURE
Approved At: 2026-07-07
EOF
}

_m7_write_landmarks() { # FILE
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

# m7_arm_scope_lock TMP — mint a committed repo, arm it through the REAL Ring-0 path,
# and echo the compiled scope.lock.json path (empty on failure). All writes land in TMP.
m7_arm_scope_lock() { # TMP
  local tmp="$1" rid
  git init -q "$tmp" 2>/dev/null || return 1
  git -C "$tmp" config user.email m7@example.com
  git -C "$tmp" config user.name "M7 Fixture"
  mkdir -p "$tmp/src"
  printf 'print("app")\n' > "$tmp/src/app.py"
  printf '# fixture repo\n' > "$tmp/README.md"
  printf '.harness/runs/current-*\n' > "$tmp/.gitignore"
  _m7_write_plan "$tmp/plan.md" "dmc-m7-chain"
  _m7_write_landmarks "$tmp/landmarks.json"
  git -C "$tmp" add -A
  git -C "$tmp" commit -q -m baseline 2>/dev/null || return 1
  "$M7_DMC" run start --plan "$tmp/plan.md" --root "$tmp" >/dev/null 2>&1 || return 1
  rid=$(cat "$tmp/.harness/runs/current-run-id" 2>/dev/null)
  [ -n "$rid" ] || return 1
  python3 "$M7_SCOPELOCK" --compile --plan "$tmp/plan.md" --landmarks "$tmp/landmarks.json" \
    --run-id "$rid" --root "$tmp" >/dev/null 2>&1 || return 1
  local lock="$tmp/.harness/runs/$rid/scope.lock.json"
  [ -f "$lock" ] || return 1
  printf '%s' "$lock"
}
