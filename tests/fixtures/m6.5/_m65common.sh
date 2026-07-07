#!/usr/bin/env bash
# _m65common.sh — shared helpers for the DMC v1 M6.5 Codex-adapter suites
# (test-codex-shims.sh; also usable by the sibling skills-mirror / agents-md suites).
#
# Nature: TEST SUPPORT. Sourced, never run directly. Provides:
#   - repo-root + PASS/FAIL bookkeeping + a real-repo porcelain-before/after guard,
#   - Codex event-JSON builders (Bash/Edit/Write/Read/Grep/Glob + malformed variants),
#   - drivers for BOTH the ADVISORY Codex shims (adapters/codex/*.py) AND the REAL
#     Claude hooks (.claude/hooks/*.sh) with a synthetic CLAUDE_PROJECT_DIR, so the
#     cross-adapter verdict-parity checks compare two live adapters on one input,
#   - an `arm_fixture` that arms a disposable repo through the REAL Ring-0 path
#     (`dmc run start` -> `dmc-scope-lock --compile`), production arming not a forgery.
#
# Never reads .env / credentials; never mutates the live repo; no network / live /
# model / API call. Every shim call is pinned to a mktemp project dir.

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  echo "_m65common.sh is a sourced library, not a standalone test" >&2
  exit 2
fi

# ---- repo root + Ring-0/adapter handles ----------------------------------------
_M65_COMMON_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P) \
  || { echo "FATAL: cannot resolve _m65common dir" >&2; exit 2; }
M65_ROOT=$(cd -- "$_M65_COMMON_DIR/../../.." >/dev/null 2>&1 && pwd -P) \
  || { echo "FATAL: cannot resolve repo root" >&2; exit 2; }
M65_DMC="$M65_ROOT/bin/dmc"
M65_HOOKS="$M65_ROOT/.claude/hooks"
M65_SCOPELOCK="$M65_ROOT/bin/lib/dmc-scope-lock.py"
M65_CODEX="$M65_ROOT/adapters/codex"

# ---- PASS/FAIL bookkeeping (house style, mirrors _m6common.sh) ------------------
PASS=0; FAIL=0
record() { # record PASS|FAIL DESC
  if [ "$1" = PASS ]; then PASS=$((PASS+1)); printf '  [PASS] %s\n' "$2"
  else FAIL=$((FAIL+1)); printf '  [FAIL] %s\n' "$2"; fi
}
assert_eq() { [ "$1" = "$2" ] && record PASS "$3" || record FAIL "$3 (want [$1] got [$2])"; }

# ---- real-repo cleanliness guard ----------------------------------------------
M65_PORCELAIN_BEFORE=""
m65_capture_before() { M65_PORCELAIN_BEFORE=$(git -C "$M65_ROOT" status --porcelain 2>/dev/null); }
m65_assert_repo_untouched() {
  local after; after=$(git -C "$M65_ROOT" status --porcelain 2>/dev/null)
  [ "$M65_PORCELAIN_BEFORE" = "$after" ] \
    && record PASS "real repo byte-identical: git status --porcelain unchanged by the suite" \
    || record FAIL "real repo CHANGED during the suite (porcelain drift — a write escaped the sandbox)"
}

# ---- Codex event-JSON builders -------------------------------------------------
# Codex payload superset: {tool_name, tool_input:{...}, cwd}. The shims read a superset of candidate
# key names; the happy-path builders use the documented leading names (command/file_path/glob/pattern).
json_str() { python3 -c 'import json,sys;print(json.dumps(sys.argv[1]))' "$1"; }

c_bash()  { printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$(json_str "$1")"; }
c_bash_cwd() { printf '{"tool_name":"Bash","cwd":%s,"tool_input":{"command":%s}}' \
                     "$(json_str "$2")" "$(json_str "$1")"; }
c_edit()  { printf '{"tool_name":"Edit","cwd":%s,"tool_input":{"file_path":%s}}' \
                   "$(json_str "$2")" "$(json_str "$1")"; }
c_write() { printf '{"tool_name":"Write","cwd":%s,"tool_input":{"file_path":%s}}' \
                   "$(json_str "$2")" "$(json_str "$1")"; }
c_read()  { printf '{"tool_name":"Read","tool_input":{"file_path":%s}}' "$(json_str "$1")"; }
c_glob()  { printf '{"tool_name":"Glob","tool_input":{"pattern":%s}}' "$(json_str "$1")"; }
c_grep()  { printf '{"tool_name":"Grep","tool_input":{"pattern":%s,"path":%s}}' \
                   "$(json_str "$1")" "$(json_str "$2")"; }
c_prompt(){ printf '{"prompt":%s}' "$(json_str "$1")"; }

# Malformed variants (B2). Renamed keys are deliberately OUTSIDE the shim's candidate superset.
c_empty()        { printf ''; }
c_garbage()      { printf 'not-json{{{ %s' "$1"; }
c_bash_renamed() { printf '{"tool_name":"Bash","tool_input":{"zzz_cmd":%s}}' "$(json_str "$1")"; }
c_edit_renamed() { printf '{"tool_name":"Edit","tool_input":{"zzz_path":%s}}' "$(json_str "$1")"; }
c_read_renamed() { printf '{"tool_name":"Read","tool_input":{"zzz_path":%s}}' "$(json_str "$1")"; }
c_notool()       { printf '{"tool_input":{"command":%s}}' "$(json_str "$1")"; }

# ---- drivers -------------------------------------------------------------------
# codex_run SHIM_BASENAME JSON PROJECT_DIR   -> ADVISORY Codex shim stdout (real repo Ring-0 resolved).
codex_run() {
  local shim="$1" json="$2" proj="$3"
  printf '%s' "$json" | env CLAUDE_PROJECT_DIR="$proj" python3 "$M65_CODEX/$shim"
}
# codex_run_at SANDBOX_ROOT SHIM JSON PROJECT_DIR  -> run a COPY of the shim whose script-root is
# SANDBOX_ROOT (used for the B2 (c) "Ring-0 CLI absent" controls: a sandbox with no bin/dmc).
codex_run_at() {
  local root="$1" shim="$2" json="$3" proj="$4"
  printf '%s' "$json" | env CLAUDE_PROJECT_DIR="$proj" python3 "$root/adapters/codex/$shim"
}
# claude_run HOOK_BASENAME JSON PROJECT_DIR  -> REAL Claude hook stdout (parity reference).
claude_run() {
  local hook="$1" json="$2" proj="$3"
  printf '%s' "$json" | env CLAUDE_PROJECT_DIR="$proj" bash "$M65_HOOKS/$hook"
}

# Decision extractors (whitespace-tolerant; mirror _m6common.sh).
decision_of() {
  local d; d=$(printf '%s' "$1" | sed -n 's/.*"permissionDecision":[[:space:]]*"\([a-z]*\)".*/\1/p')
  [ -n "$d" ] && printf '%s' "$d" || printf 'allow'
}
stop_decision_of() {
  local d; d=$(printf '%s' "$1" | sed -n 's/.*"decision":[[:space:]]*"\([a-z]*\)".*/\1/p')
  [ -n "$d" ] && printf '%s' "$d" || printf 'pass'
}
has_context_of() { printf '%s' "$1" | grep -q 'additionalContext' && printf 'ctx' || printf 'none'; }

# ---- fixture builders ----------------------------------------------------------
m65_write_plan() { # FILE PLAN_ID APPROVER
  cat > "$1" <<EOF
# Plan: M6.5 fixture ($2)

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

m65_write_landmarks() { # FILE
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

mk_repo() { # TMP [PLAN_ID] [APPROVER]  — committed git repo baseline, UNARMED.
  local tmp="$1" planid="${2:-dmc-m65-fixture}" approver="${3:-M65-FIXTURE}"
  git init -q "$tmp" || return 1
  git -C "$tmp" config user.email t@example.com
  git -C "$tmp" config user.name "M65 Fixture"
  mkdir -p "$tmp/src"
  printf 'print("app")\n' > "$tmp/src/app.py"
  printf '# fixture repo\n' > "$tmp/README.md"
  printf '.harness/runs/current-*\n' > "$tmp/.gitignore"
  m65_write_plan "$tmp/plan.md" "$planid" "$approver"
  m65_write_landmarks "$tmp/landmarks.json"
  git -C "$tmp" add -A
  git -C "$tmp" commit -q -m baseline
}

arm_fixture() { # TMP  — arm a committed repo through the REAL Ring-0 path; echoes RID.
  local tmp="$1" planid="${2:-dmc-m65-fixture}" approver="${3:-M65-FIXTURE}"
  mk_repo "$tmp" "$planid" "$approver" || return 1
  "$M65_DMC" run start --plan "$tmp/plan.md" --root "$tmp" >/dev/null 2>&1 || return 1
  local rid; rid=$(cat "$tmp/.harness/runs/current-run-id" 2>/dev/null)
  [ -n "$rid" ] || return 1
  python3 "$M65_SCOPELOCK" --compile --plan "$tmp/plan.md" --landmarks "$tmp/landmarks.json" \
    --run-id "$rid" --root "$tmp" >/dev/null 2>&1 || return 1
  [ -f "$tmp/.harness/runs/$rid/scope.lock.json" ] || return 1
  printf '%s' "$rid"
}

set_mode() { # PROJECT_DIR MODE
  mkdir -p "$1/.harness"; printf '%s\n' "$2" > "$1/.harness/mode"
}

# copy_shims SANDBOX_ROOT  — copy the adapter into a sandbox whose script-root has NO bin/dmc, so
# find_dmc()/find_scope_lock_lib() resolve to None (true "Ring-0 CLI absent" for the B2 (c) controls).
copy_shims() {
  mkdir -p "$1/adapters/codex"
  cp "$M65_CODEX/dmc_codex_common.py" "$1/adapters/codex/"
  cp "$M65_CODEX"/dmc-codex-*.py "$1/adapters/codex/"
}

# The canonical evidence-log.sh redact() transform, invoked directly for the B3 redaction-parity check.
evidence_log_redact() {
  sed -E 's/(sk-[A-Za-z0-9_-]{8,})/[REDACTED_API_KEY]/g; s/(password|secret|token|api[_-]?key)=([^[:space:]]+)/\1=[REDACTED]/gi'
}
