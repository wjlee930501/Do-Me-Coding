#!/usr/bin/env bash
# _m9common.sh — shared helpers for the DMC v1 M9 release-gate suites
# (test-release-gate.sh, test-e2e-loop.sh).
#
# Nature: TEST SUPPORT. Sourced, never run directly. Provides:
#   - repo-root resolution + PASS/FAIL bookkeeping (record/assert_* house style,
#     mirrors _m6common.sh / _m7common.sh / _m8common.sh),
#   - a real-repo porcelain-before/after guard (proves the suites leave the LIVE
#     repo byte-identical — every write lands in a mktemp sandbox),
#   - m9_mktemp + an EXIT-trap cleanup for tracked sandboxes,
#   - copy_surface: copies the DMC surface (bin + .claude + orchestration +
#     .harness/schemas + PLAN/RUN/VERIFICATION_SCHEMA.md) into a mktemp repo and
#     OVERLAYS tests/fixtures/host-node — so the COPIED $REPO/bin/lib tools resolve
#     their own root to $REPO (delegation/worker default paths + schema resolution
#     all land inside the sandbox), and the committed host-node tree is never armed
#     in place,
#   - a real Ring-0 arming path (`dmc run start` -> `dmc-scope-lock.py --compile`),
#   - the PreToolUse/Stop hook JSON drivers used by the E2E denied-attempt rows,
#   - a python "kit" that materializes the schema-valid release artifacts the gate
#     reads (verify-plan / findings / goal-ledger / decision-record / verification
#     report / worker task+result+review / delegation record / critic verdict) in
#     the exact shapes the shipped dmc-release-gate.py self-test proves green.
#
# The armed sandbox git-ignores `.harness/` so the run-state + append-only worker
# and delegation logs never surface as out-of-scope worktree changes (they are read
# by path, not by git). Never reads .env / credentials; never mutates the live repo;
# no network / live / model / API call. Self-set git identity (a bare CI host needs
# no ambient user.name/email).

# Refuse direct execution — this is a library.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  echo "_m9common.sh is a sourced library, not a standalone test" >&2
  exit 2
fi

# ---- repo root + surface handles ----------------------------------------------
_M9_COMMON_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P) \
  || { echo "FATAL: cannot resolve _m9common dir" >&2; exit 2; }
M9_ROOT=$(cd -- "$_M9_COMMON_DIR/../../.." >/dev/null 2>&1 && pwd -P) \
  || { echo "FATAL: cannot resolve repo root" >&2; exit 2; }
M9_HOSTNODE="$M9_ROOT/tests/fixtures/host-node"

# ---- PASS/FAIL bookkeeping (house style) --------------------------------------
PASS=0; FAIL=0
record() { # record PASS|FAIL DESC
  if [ "$1" = PASS ]; then PASS=$((PASS+1)); printf '  [PASS] %s\n' "$2"
  else FAIL=$((FAIL+1)); printf '  [FAIL] %s\n' "$2"; fi
}
assert_eq()  { [ "$1" = "$2" ] && record PASS "$3" || record FAIL "$3 (want [$1] got [$2])"; }
assert_ne()  { [ "$1" != "$2" ] && record PASS "$3" || record FAIL "$3 (unwanted [$1])"; }
assert_contains()     { case "$1" in *"$2"*) record PASS "$3" ;; *) record FAIL "$3 (missing [$2])" ;; esac; }
assert_not_contains() { case "$1" in *"$2"*) record FAIL "$3 (found [$2])" ;; *) record PASS "$3" ;; esac; }
assert_lt() { # NUM LIMIT DESC  — integer/float "<" via awk (portable)
  if awk "BEGIN{exit !($1 < $2)}"; then record PASS "$3 (measured $1 < $2)"
  else record FAIL "$3 (measured $1 NOT < $2)"; fi
}

# ---- real-repo cleanliness guard (mirrors _m6common.sh) -----------------------
M9_PORCELAIN_BEFORE=""
m9_capture_before() { M9_PORCELAIN_BEFORE=$(git -C "$M9_ROOT" status --porcelain 2>/dev/null); }
m9_assert_repo_untouched() {
  local after; after=$(git -C "$M9_ROOT" status --porcelain 2>/dev/null)
  [ "$M9_PORCELAIN_BEFORE" = "$after" ] \
    && record PASS "real repo byte-identical: git status --porcelain unchanged by the suite" \
    || record FAIL "real repo CHANGED during the suite (porcelain drift — a write escaped the sandbox)"
}

# ---- sandbox tracking ---------------------------------------------------------
_M9_TMPS=()
m9_mktemp() { # PREFIX -> fresh mktemp -d path (tracked for cleanup)
  local d; d=$(mktemp -d "${TMPDIR:-/tmp}/dmc-m9-${1:-t}.XXXXXX") \
    || { echo "FATAL: mktemp failed" >&2; exit 2; }
  _M9_TMPS+=("$d"); printf '%s' "$d"
}
m9_cleanup() { local d; for d in "${_M9_TMPS[@]:-}"; do [ -n "$d" ] && rm -rf "$d"; done; }

# ---- JSON + hook drivers (mirror _m6common.sh; drive the COPIED hooks) ---------
json_str() { python3 -c 'import json,sys;print(json.dumps(sys.argv[1]))' "$1"; }
bash_input()  { printf '{"tool_name":"Bash","tool_input":{"command":%s}}' "$(json_str "$1")"; }
edit_input()  { printf '{"tool_name":"Edit","cwd":%s,"tool_input":{"file_path":%s}}' \
                       "$(json_str "$2")" "$(json_str "$1")"; }
glob_input()  { printf '{"tool_name":"Glob","tool_input":{"pattern":%s}}' "$(json_str "$1")"; }
read_input()  { printf '{"tool_name":"Read","tool_input":{"file_path":%s}}' "$(json_str "$1")"; }
grep_input()  { printf '{"tool_name":"Grep","tool_input":{"pattern":%s,"path":%s}}' \
                       "$(json_str "$1")" "$(json_str "$2")"; }
# hook_run HOOK_BASENAME JSON PROJECT_DIR -> prints hook stdout (COPIED hook under PROJECT_DIR)
hook_run() {
  local hook="$1" json="$2" proj="$3"
  printf '%s' "$json" | CLAUDE_PROJECT_DIR="$proj" bash "$proj/.claude/hooks/$hook"
}
decision_of() {
  local out="$1" d
  d=$(printf '%s' "$out" | sed -n 's/.*"permissionDecision":[[:space:]]*"\([a-z]*\)".*/\1/p')
  [ -n "$d" ] && printf '%s' "$d" || printf 'allow'
}
stop_decision_of() {
  local out="$1" d
  d=$(printf '%s' "$out" | sed -n 's/.*"decision":[[:space:]]*"\([a-z]*\)".*/\1/p')
  [ -n "$d" ] && printf '%s' "$d" || printf 'pass'
}

# ---- plan / landmarks writers -------------------------------------------------
# Ordinary profile: two ordinary src grants (src/index.js + src/util.js). The
# scope.lock files[] is exactly the landmarks files[] (normalized/sorted), so the
# green path stages EXACTLY these two paths (AA3: files[] == modified/new set;
# v0.2.6 G2 is cached-diff). Both ordinary => the landmark-flag sub-gate is empty.
m9_write_plan() { # FILE ROW1 ROW2  (ROWn = "path|reason")
  local f="$1"
  cat > "$f" <<EOF
# Plan: M9 host-node fixture

Plan ID: dmc-m9-host-node

## Goal
Exercise the P18 release gate on a host-shaped repo.
## User Intent
feature
## Current Repo Findings
- Finding: f
  Source: s
## Relevant Files
| Path | Reason | Allowed to Edit |
|---|---|---|
| ${2%%|*} | ${2##*|} | yes |
| ${3%%|*} | ${3##*|} | yes |
## Out of Scope
- x
## Proposed Changes
- Change: c
  Files: ${2%%|*}
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
  Files: ${2%%|*}
  Notes: n
## Verification Commands
| Command | Reason | Required |
|---|---|---|
| c | r | yes |
## Approval Status
Status: APPROVED
Approver: M9-FIXTURE
Approved At: 2026-07-08
EOF
}

m9_write_landmarks_ordinary() { # FILE
  cat > "$1" <<'EOF'
{
  "files": [
    {"path": "src/index.js", "grant": "edit", "landmark_class": "ordinary"},
    {"path": "src/util.js", "grant": "edit", "landmark_class": "ordinary"}
  ],
  "bounds": {"max_files": 5, "max_added": 500, "max_deleted": 200, "forbidden_hunk_classes": []}
}
EOF
}

# Single profile (E2E "one benign in-scope edit"): grant exactly ONE ordinary src path, so the
# loop's single edit + `git add` == the scope.lock files[] set (AA3, v0.2.6 G2 cached-diff).
m9_write_landmarks_single() { # FILE
  cat > "$1" <<'EOF'
{
  "files": [
    {"path": "src/util.js", "grant": "edit", "landmark_class": "ordinary"}
  ],
  "bounds": {"max_files": 5, "max_added": 500, "max_deleted": 200, "forbidden_hunk_classes": []}
}
EOF
}

# Contract profile (g9 FLAG row): one ordinary src grant + one CONTRACT landmark
# (config.schema.md — repo-intel classifies *.schema.md as contract). A new change
# on config.schema.md fires the landmark-flag REVIEW flag WITHOUT failing the gate.
m9_write_landmarks_contract() { # FILE
  cat > "$1" <<'EOF'
{
  "files": [
    {"path": "src/index.js", "grant": "edit", "landmark_class": "ordinary"},
    {"path": "config.schema.md", "grant": "create", "landmark_class": "contract", "landmark_authorized": true}
  ],
  "bounds": {"max_files": 5, "max_added": 500, "max_deleted": 200, "forbidden_hunk_classes": []}
}
EOF
}

# ---- copy_surface + setup + arm -----------------------------------------------
copy_surface() { # REPO — copy the DMC surface + overlay host-node
  local repo="$1" d f
  mkdir -p "$repo"
  for d in bin .claude orchestration .harness/schemas; do
    if [ -e "$M9_ROOT/$d" ]; then
      mkdir -p "$repo/$(dirname "$d")"
      cp -R "$M9_ROOT/$d" "$repo/$d"
    fi
  done
  for f in PLAN_SCHEMA.md RUN_SCHEMA.md VERIFICATION_SCHEMA.md; do
    [ -f "$M9_ROOT/$f" ] && cp "$M9_ROOT/$f" "$repo/$f"
  done
  cp -R "$M9_HOSTNODE/." "$repo/"
}

# m9_setup_repo REPO [PROFILE=ordinary|contract] — copied surface + host-node
# overlay + plan/landmarks + committed baseline. `.harness/` is git-ignored in the
# armed sandbox (run-state + append-only logs read by path, never by git).
m9_setup_repo() {
  local repo="$1" profile="${2:-ordinary}"
  copy_surface "$repo"
  git init -q "$repo"
  git -C "$repo" config user.email m9@example.com
  git -C "$repo" config user.name "M9 Fixture"
  printf 'node_modules\ndist\n.harness/\n' > "$repo/.gitignore"
  if [ "$profile" = contract ]; then
    m9_write_plan "$repo/plan.md" "src/index.js|entry" "config.schema.md|contract"
    m9_write_landmarks_contract "$repo/landmarks.json"
  elif [ "$profile" = single ]; then
    m9_write_plan "$repo/plan.md" "src/util.js|util" "src/util.js|util"
    m9_write_landmarks_single "$repo/landmarks.json"
  else
    m9_write_plan "$repo/plan.md" "src/index.js|entry" "src/util.js|util"
    m9_write_landmarks_ordinary "$repo/landmarks.json"
  fi
  git -C "$repo" add -A
  git -C "$repo" commit -q -m baseline
}

# m9_arm REPO -> echoes RID (empty on failure). Real Ring-0 two-step arming.
m9_arm() {
  local repo="$1" rid
  "$repo/bin/dmc" run start --plan "$repo/plan.md" --root "$repo" >/dev/null 2>&1 || return 1
  rid=$(cat "$repo/.harness/runs/current-run-id" 2>/dev/null)
  [ -n "$rid" ] || return 1
  python3 "$repo/bin/lib/dmc-scope-lock.py" --compile --plan "$repo/plan.md" \
    --landmarks "$repo/landmarks.json" --run-id "$rid" --root "$repo" >/dev/null 2>&1 || return 1
  [ -f "$repo/.harness/runs/$rid/scope.lock.json" ] || return 1
  printf '%s' "$rid"
}

# m9_setup_arm REPO [PROFILE] -> echoes RID (setup + arm in one step).
m9_setup_arm() { m9_setup_repo "$1" "${2:-ordinary}" || return 1; m9_arm "$1"; }

# ---- python kit ---------------------------------------------------------------
# Emit the JSON builder to PATH (kept OUTSIDE the armed repo so it never surfaces
# as a worktree change). Mirrors the shipped dmc-release-gate.py self-test shapes
# (_st_findings/_st_goal/_st_decision/ST_VERIF) + the M7 worker chain builders +
# the M6 critic-verdict builder.
m9_write_kit() { # PATH
  cat > "$1" <<'PY'
import copy, hashlib, importlib.util, json, os, sys
sys.dont_write_bytecode = True

H = "a" * 64
BIND = {"work_id": "W1", "plan_hash": H, "repo_hash": H, "verification_ref": "ver/r.md"}

def wj(path, obj):
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, sort_keys=True)

def approval():
    return {"kind": "approval", "id": "A1", "producer_milestone_id": "human-release-gate",
            "type": "human-release-gate", "source": "human-release-gate:auth1", **BIND}

def findings(blocked=False):
    subj = {"work_id": "W1", "plan_hash": H, "milestone_id": "v0.6.1", "repo_hash": H,
            "verification_ref": "ver/r.md"}
    fs = []
    if blocked:
        fs = [{"kind": "finding", "id": "Fblk", "producer_milestone_id": "v0.6.3",
               "state": "blocked", "summary_class": "perf-regression", **BIND}]
    return {"subject": subj, "findings": fs}

def goal(broken=False):
    def ent(seq, state, appr=False):
        e = {"entry_kind": "goal_ledger", "producer_milestone_id": "v0.6.4", "goal_id": "g1",
             "seq": seq, "goal_state": state, "scope": "feature-x", "constraints": "no-net",
             "evidence_links": ["evid123456"], "completion_state": "open", **BIND}
        if appr:
            e["approval"] = approval()
        return e
    ledger = [ent(0, "approved", appr=True), ent(1, "in-progress")]
    completion = {"goal_id": ("gX" if broken else "g1"), "completion_state": "done"}
    return {"ledger": ledger, "completion": completion}

def decision(broken=False):
    def e(kind, eid, prod, **x):
        return {"kind": kind, "id": eid, "producer_milestone_id": prod, **BIND, **x}
    dec = {"kind": "decision", "id": "D1", "producer_milestone_id": "v0.6.5",
           "rationale_class": "ship-it",
           "links": {"capability_id": "cheap-fast", "evidence_ids": ["E1"], "finding_ids": ["F1"],
                     "goal_id": "g1", "approval_id": ("A9" if broken else "A1")}, **BIND}
    return {"schema": "dmc.trace-linkage.v1",
            "subject": {"work_id": "W1", "plan_hash": H, "milestone_id": "v0.6.1.0",
                        "repo_hash": H, "verification_ref": "ver/r.md"},
            "registers": {
                "capability": [e("capability_class", "cheap-fast", "v0.6.1")],
                "evidence": [e("evidence_receipt", "E1", "v0.6.2")],
                "finding": [e("finding", "F1", "v0.6.3", state="resolved")],
                "goal": [e("goal", "g1", "v0.4.1")],
                "decision": [dec],
                "approval": [e("approval", "A1", "human-release-gate", type="human-release-gate",
                               source="human-release-gate:auth1")]},
            "edges": [{"from": {"kind": "decision", "id": "D1"},
                       "to": {"kind": "evidence_receipt", "id": "E1"}}]}

VERIF = """# Verification Report

## Run ID
r
## Plan
p
## Changed Files
- p: reason
## Commands Run
| Command | Result | Reason | Output Summary |
|---|---|---|---|
| c | PASS | r | s |
## Manual Checks
| Check | Result | Notes |
|---|---|---|
| c | PASS | n |
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
"""

# ---- M7 worker chain builders (mock, clean) ----
def wtask(tid, path):
    return {"task_id": tid, "objective": "o", "allowed_files": [path],
            "forbidden_files": ["src/secret.py"], "context_summary": "c",
            "relevant_snippets": [], "expected_output_type": "diff",
            "provider_target": {"type": "mock", "provider": "mock-local"}}

def wresult(tid, path, inject=None, rename_forbidden=False):
    if rename_forbidden:
        patch = ("diff --git a/%s b/src/secret.py\nrename from %s\nrename to src/secret.py\n"
                 % (path, path))
        changed = [path, "src/secret.py"]
    else:
        patch = "--- a/%s\n+++ b/%s\n@@ -1 +1 @@\n-old\n+new\n" % (path, path)
        changed = [path]
    r = {"task_id": tid, "summary": "s", "files_considered": [path], "files_changed": changed,
         "proposed_patch": patch, "instructions": "i", "confidence": "high",
         "no_direct_mutation": True,
         "provider_metadata": {"provider_type": "mock", "provider": "mock-local",
                               "credential_exposure": "none", "invocation_id": "inv-1"}}
    if inject == "jwt":
        # SYNTHETIC token-shaped value (never a real credential), built by concatenation and
        # injected into a benign field only. Asserted value-blind (exit code only).
        r["note"] = "eyJ" + "aGVsbG8xMjM" + "." + "d29ybGRhYmM" + "." + "c2lnMDk4NzY"
    return r

def wreview(task_path, result_path):
    tb = open(task_path, "rb").read()
    rb = open(result_path, "rb").read()
    trh = hashlib.sha256(tb + b"\n" + rb).hexdigest()
    result = json.loads(rb)
    inv = (result.get("provider_metadata") or {}).get("invocation_id")
    rid_ = inv if isinstance(inv, str) and inv else result.get("task_id")
    return {"schema": "dmc.worker-review.v1", "task_id": result.get("task_id"), "result_id": rid_,
            "provider": "mock-local", "reviewer_role": "critic-falsifier",
            "checks": [{"check": "scope-compat", "result": "PASS", "evidence_ref": "e"},
                       {"check": "token-scan", "result": "PASS", "evidence_ref": "e"},
                       {"check": "fidelity", "result": "PASS", "evidence_ref": "e"},
                       {"check": "disallowed-category", "result": "PASS", "evidence_ref": "e"}],
            "decision": "apply", "task_result_hash": trh, "prev_hash": "genesis"}

def deleg():
    return {"schema": "dmc.delegation.v1", "work_id": "m9-deleg-work",
            "plan_hash": "a" * 16, "repo_hash": "b" * 16, "delegation_id": "deleg-0001",
            "role": "verifier", "capability_class": "deterministic-tool", "may_mutate": False,
            "depth": 0, "max_depth": 3, "artifact_ref": None, "artifact_schema": None,
            "validation_verdict": "PENDING", "prev_hash": "genesis"}

def critic_verdict(repo, plan, verdict_str):
    spec = importlib.util.spec_from_file_location(
        "rl", os.path.join(repo, "bin", "lib", "dmc-run-lifecycle.py"))
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    text = open(plan, encoding="utf-8").read()
    return {"schema": "dmc.critic-verdict.v1", "work_id": m.derive_work_id(text, plan),
            "plan_hash": m.plan_hash(plan), "repo_hash": "b" * 40, "target_ref": "plan.md",
            "verdict": verdict_str, "lenses": ["scope"], "advisory": True,
            "context_provenance": "fresh",
            "blockers": ([{"id": "B1", "statement": "must fix X"}] if verdict_str == "REJECT" else [])}

def main():
    v = sys.argv[1]
    if v == "verify-plan":
        out, path = sys.argv[2], sys.argv[3]
        ids = sys.argv[4:] or ["CHK-A"]
        wj(out, {"coverage": [{"path": path, "radius_check_ids": ids, "resolved_by": ids}]})
    elif v == "findings":
        wj(sys.argv[2], findings(blocked=(len(sys.argv) > 3 and sys.argv[3] == "blocked")))
    elif v == "goal":
        wj(sys.argv[2], goal(broken=(len(sys.argv) > 3 and sys.argv[3] == "broken")))
    elif v == "decision":
        wj(sys.argv[2], decision(broken=(len(sys.argv) > 3 and sys.argv[3] == "broken")))
    elif v == "verif":
        os.makedirs(os.path.dirname(os.path.abspath(sys.argv[2])), exist_ok=True)
        open(sys.argv[2], "w", encoding="utf-8").write(VERIF)
    elif v == "wtask":
        wj(sys.argv[2], wtask(sys.argv[3], sys.argv[4]))
    elif v == "wresult":
        inject = sys.argv[5] if len(sys.argv) > 5 and sys.argv[5] else None
        rf = len(sys.argv) > 6 and sys.argv[6] == "rename-forbidden"
        wj(sys.argv[2], wresult(sys.argv[3], sys.argv[4], inject=inject, rename_forbidden=rf))
    elif v == "wreview":
        wj(sys.argv[2], wreview(sys.argv[3], sys.argv[4]))
    elif v == "deleg":
        wj(sys.argv[2], deleg())
    elif v == "verdict":
        obj = critic_verdict(sys.argv[3], sys.argv[4], sys.argv[5])
        wj(sys.argv[2], obj)
        print(obj["plan_hash"])   # emit the plan_hash so the caller can bind `verdict gate --plan-hash`
    else:
        sys.stderr.write("m9kit: unknown verb %s\n" % v); sys.exit(2)

main()
PY
}

# ---- release-artifact materialization -----------------------------------------
# m9_base_artifacts REPO RID KIT — write the all-PASS base the release gate reads
# (verify-plan CHK-A, findings clean, goal approved->done, decision Q1-Q6, one minted
# CHK-A receipt, a VALID verification report, plan_approval + a release approval whose
# verification_ref resolves). NO worker activity (chain PASSES with the no-activity
# note). All artifacts land under .harness/ (git-ignored / diff-scope exempt).
m9_base_artifacts() { # REPO RID KIT
  local repo="$1" rid="$2" kit="$3"
  local run_dir="$repo/.harness/runs/$rid"
  python3 "$kit" verify-plan "$run_dir/verify-plan.json" "src/index.js" "CHK-A"
  python3 "$kit" findings "$run_dir/findings.json"
  python3 "$kit" goal "$run_dir/goal-ledger.json"
  python3 "$kit" decision "$run_dir/decision-record.json"
  local h40="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"   # 40-hex placeholder (mint records it verbatim)
  python3 "$repo/bin/lib/dmc-evidence-ledger.py" mint --root "$repo" --run-id "$rid" \
    --check-id CHK-A --evidence-type verification-report --artifact-ref ver/report.md \
    --work-id W --plan-hash "$h40" --repo-hash "$h40" --verification-ref ver/report.md >/dev/null 2>&1
  python3 "$kit" verif "$repo/.harness/verification/rep.md"
  python3 "$repo/bin/lib/dmc-approvals.py" append --root "$repo" --run-id "$rid" \
    --gate-kind plan_approval --auth-id wjlee >/dev/null 2>&1
  python3 "$repo/bin/lib/dmc-approvals.py" append --root "$repo" --run-id "$rid" \
    --gate-kind release --auth-id wjlee \
    --verification-ref .harness/verification/rep.md >/dev/null 2>&1
}

# m9_add_worker_chain REPO RID KIT TID — a verified worker apply chain the release
# gate's chain sub-gate resolves: task/result/review at the canonical worker paths,
# a real `dmc worker authorize --out` authorization (run-bound), and a genesis
# delegations.jsonl entry. Worker path is src/util.js (in the ordinary scope.lock).
m9_add_worker_chain() { # REPO RID KIT TID
  local repo="$1" rid="$2" kit="$3" tid="$4"
  local wk="$repo/.harness/workers"
  local task="$wk/tasks/$tid.json" result="$wk/results/$tid.json" review="$wk/reviews/$tid.json"
  local auth="$wk/authorizations/$tid.json"
  mkdir -p "$wk/tasks" "$wk/results" "$wk/reviews" "$wk/authorizations"
  python3 "$kit" wtask "$task" "$tid" "src/util.js"
  python3 "$kit" wresult "$result" "$tid" "src/util.js"
  python3 "$kit" wreview "$review" "$task" "$result"
  python3 "$repo/bin/lib/dmc-worker-review.py" authorize --task "$task" --result "$result" \
    --review "$review" --run "$rid" --out "$auth" >/dev/null 2>&1
  local rec="$repo/.harness/m9-deleg-rec.json"
  python3 "$kit" deleg "$rec"
  python3 "$repo/bin/lib/dmc-delegation.py" append "$rec" --run "$rid" >/dev/null 2>&1
  rm -f "$rec"
}

# ---- release-gate invocation helpers ------------------------------------------
# m9_gate_full_json REPO RID [EXTRA...] — run `dmc gate release --full --out -`;
# sets M9_GATE_RC + M9_GATE_JSON (stdout). Uses the COPIED bin/dmc so every composed
# tool resolves its own root to $REPO.
m9_gate_full_json() {
  local repo="$1" rid="$2"; shift 2
  M9_GATE_JSON=$("$repo/bin/dmc" gate release --full --run-id "$rid" --root "$repo" --out - "$@" 2>/dev/null)
  M9_GATE_RC=$?
}
# m9_gate_full_capture REPO RID [EXTRA...] — like above but keeps stdout+stderr in
# M9_GATE_OUT (for structural-REFUSE rows where no JSON is emitted).
m9_gate_full_capture() {
  local repo="$1" rid="$2"; shift 2
  M9_GATE_OUT=$("$repo/bin/dmc" gate release --full --run-id "$rid" --root "$repo" --out - "$@" 2>&1)
  M9_GATE_RC=$?
}
# m9_subverdict JSON NAME -> prints the named sub-gate verdict (or empty).
m9_subverdict() {
  printf '%s' "$1" | python3 -c 'import json,sys
try:
    d=json.load(sys.stdin)
    print(d.get("sub_gates",{}).get(sys.argv[1],{}).get("verdict",""))
except Exception:
    print("")' "$2"
}
# m9_overall JSON -> prints the overall verdict.
m9_overall() {
  printf '%s' "$1" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("verdict",""))
except Exception: print("")'
}
# m9_reasons_of JSON NAME -> prints the joined reasons of the named sub-gate.
m9_reasons_of() {
  printf '%s' "$1" | python3 -c 'import json,sys
try:
    d=json.load(sys.stdin)
    print(" ".join(d.get("sub_gates",{}).get(sys.argv[1],{}).get("reasons",[])))
except Exception:
    print("")' "$2"
}
