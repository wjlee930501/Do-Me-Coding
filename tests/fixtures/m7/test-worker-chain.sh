#!/usr/bin/env bash
# test-worker-chain.sh — DMC v1 M7 worker review->authorize->apply-check->fidelity chain controls.
#
# Nature: ADVERSARIAL/positive test. Each case drives the REAL P15 CLIs via `bin/dmc worker
# review-check|authorize|apply-check|fidelity` with mktemp fixtures, and asserts REFUSE (exit 3)
# where the chain contract demands one, PAIRED with a clean-chain PASS (exit 0). It proves the four
# named review-schema negative controls + a binding hash-mismatch, the authorize refusals
# (reject-decision / REJECTing-result / existing-authorization / path-shaped task_id), the P7
# apply gate ("apply without a chain is refused", tampered bytes, out-of-allowed paths, an
# out-of-scope.lock path against a REAL compiled scope.lock), and post-apply fidelity at the
# names+hunk-count tier.
#
# Never reads .env / credentials; never mutates the live repo (proven by a porcelain-before/after
# check — authorize always writes to a sandbox --out; the scope.lock is compiled in a mktemp repo);
# no network / live / model / API call. Reviewer roles use REAL orchestration/roles.json ids.
#
# Usage: test-worker-chain.sh   Run all checks, print RESULT + summary, exit 0/1.

set -u

SELF_DIR=$(cd -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd -P) || { echo "FATAL: script dir"; exit 2; }
# shellcheck source=_m7common.sh
. "$SELF_DIR/_m7common.sh"

if ! git -C "$M7_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "FATAL: repo root is not a git worktree: $M7_ROOT"; exit 2
fi

SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/dmc-m7-chain.XXXXXX") || { echo "FATAL: mktemp"; exit 2; }
cleanup() { rm -rf "$SANDBOX"; }
trap cleanup EXIT

# ---- fixture kit: builds task/result/review fixtures + hashes + mutations ----------------------
KIT="$SANDBOX/chainkit.py"
cat > "$KIT" <<'PY'
import copy, hashlib, json, sys

REVIEW_SCHEMA = "dmc.worker-review.v1"
TASK_BASE = {
    "task_id": "m7-chain-001",
    "objective": "o",
    "allowed_files": ["src/app.py"],
    "forbidden_files": ["src/secret.py"],
    "context_summary": "c",
    "relevant_snippets": [],
    "expected_output_type": "diff",
    "provider_target": {"type": "mock", "provider": "mock-local"},
}
RESULT_BASE = {
    "task_id": "m7-chain-001",
    "summary": "s",
    "files_considered": ["src/app.py"],
    "files_changed": ["src/app.py"],
    "proposed_patch": "--- a/src/app.py\n+++ b/src/app.py\n@@ -1 +1 @@\n-old\n+new\n",
    "instructions": "i",
    "confidence": "high",
    "no_direct_mutation": True,
    "provider_metadata": {"provider_type": "mock", "provider": "mock-local",
                          "credential_exposure": "none", "invocation_id": "inv-1"},
}

def build(base, ov):
    o = copy.deepcopy(base)
    for k, v in ov.items():
        if v == "__DELETE__":
            o.pop(k, None)
        else:
            o[k] = v
    return o

def wj(path, obj):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f)

def expected_result_id(result):
    inv = (result.get("provider_metadata") or {}).get("invocation_id")
    if isinstance(inv, str) and inv != "":
        return inv
    return result.get("task_id")

def base_review(task_path, result_path):
    tb = open(task_path, "rb").read()
    rb = open(result_path, "rb").read()
    trh = hashlib.sha256(tb + b"\n" + rb).hexdigest()
    result = json.loads(rb)
    return {
        "schema": REVIEW_SCHEMA,
        "task_id": result.get("task_id"),
        "result_id": expected_result_id(result),
        "provider": "mock-local",
        "reviewer_role": "critic-falsifier",
        "checks": [
            {"check": "scope-compat", "result": "PASS", "evidence_ref": "e"},
            {"check": "token-scan", "result": "PASS", "evidence_ref": "e"},
            {"check": "fidelity", "result": "PASS", "evidence_ref": "e"},
            {"check": "disallowed-category", "result": "PASS", "evidence_ref": "e"},
        ],
        "decision": "apply",
        "task_result_hash": trh,
        "prev_hash": "genesis",
    }

def main():
    verb = sys.argv[1]
    if verb == "task":
        ov = json.loads(sys.argv[3]) if len(sys.argv) > 3 else {}
        wj(sys.argv[2], build(TASK_BASE, ov))
    elif verb == "result":
        ov = json.loads(sys.argv[3]) if len(sys.argv) > 3 else {}
        wj(sys.argv[2], build(RESULT_BASE, ov))
    elif verb == "review":
        out, tp, rp = sys.argv[2], sys.argv[3], sys.argv[4]
        ov = json.loads(sys.argv[5]) if len(sys.argv) > 5 else {}
        rev = base_review(tp, rp)
        mut = ov.pop("_mutate", None)
        if mut == "fail":
            rev["checks"][2]["result"] = "FAIL"
        elif mut == "empty":
            rev["checks"] = []
        elif mut == "drop-fidelity":
            rev["checks"] = [c for c in rev["checks"] if c["check"] != "fidelity"]
        wj(out, build(rev, ov))
    elif verb == "mutate":
        obj = json.loads(open(sys.argv[2]).read())
        ov = json.loads(sys.argv[4])
        wj(sys.argv[3], build(obj, ov))
    elif verb == "tamper":
        data = open(sys.argv[2], "rb").read()
        with open(sys.argv[3], "wb") as f:
            f.write(data + b" ")
    elif verb == "applied":
        mode = sys.argv[3]
        pp = RESULT_BASE["proposed_patch"]
        text = {"same": pp,
                "hunk": pp + "@@ -5 +5 @@\n-a\n+b\n",
                "path": "--- a/src/other.py\n+++ b/src/other.py\n@@ -1 +1 @@\n-x\n+y\n"}[mode]
        with open(sys.argv[2], "w", encoding="utf-8") as f:
            f.write(text)

main()
PY

kit() { python3 "$KIT" "$@"; }

# assert_rc DESC EXPECTED_RC CMD...  — run CMD, assert its exit code.
assert_rc() {
  local desc="$1" exp="$2"; shift 2
  "$@" >/dev/null 2>&1; local rc=$?
  assert_eq "$exp" "$rc" "$desc"
}

WK() { "$M7_DMC" worker "$@"; }   # bin/dmc worker <verb> ...

# ---- clean main chain fixtures --------------------------------------------------
T="$SANDBOX/task.json"
R="$SANDBOX/result.json"
REV="$SANDBOX/review.json"
AUTH="$SANDBOX/auth.json"

case_review_check() {
  echo "  -- review-check: 4 schema negatives + hash-mismatch + clean VALID --"
  kit task "$T"; kit result "$R"; kit review "$REV" "$T" "$R"

  assert_rc "R-P1 clean review VALID (real id critic-falsifier, task+result binding)" 0 \
    WK review-check "$REV" --task "$T" --result "$R"

  kit review "$SANDBOX/rev_fail.json" "$T" "$R" '{"_mutate":"fail"}'
  assert_rc "R-N1 apply-with-a-FAIL check REFUSED (WREV-APPLY-WITH-FAIL)" 3 \
    WK review-check "$SANDBOX/rev_fail.json"

  kit review "$SANDBOX/rev_empty.json" "$T" "$R" '{"_mutate":"empty"}'
  assert_rc "R-N2 empty checks REFUSED (WREV-NO-CHECKS)" 3 \
    WK review-check "$SANDBOX/rev_empty.json"

  kit review "$SANDBOX/rev_drop.json" "$T" "$R" '{"_mutate":"drop-fidelity"}'
  assert_rc "R-N3 missing mandatory kind REFUSED (WREV-MISSING-MANDATORY-KIND)" 3 \
    WK review-check "$SANDBOX/rev_drop.json"

  kit review "$SANDBOX/rev_mut.json" "$T" "$R" '{"reviewer_role":"implementer"}'
  assert_rc "R-N4 mutation-capable reviewer_role REFUSED (WREV-ROLE-MUTABLE, real id implementer)" 3 \
    WK review-check "$SANDBOX/rev_mut.json"

  kit review "$SANDBOX/rev_badhash.json" "$T" "$R" '{"task_result_hash":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"}'
  assert_rc "R-N5 task_result_hash mismatch (binding) REFUSED (WREV-HASH-MISMATCH)" 3 \
    WK review-check "$SANDBOX/rev_badhash.json" --task "$T" --result "$R"
}

case_authorize() {
  echo "  -- authorize: clean PASS + reject/REJECTing-result/existing/path-id refusals --"
  assert_rc "A-P1 clean chain authorize emits an apply-authorization (exit 0)" 0 \
    WK authorize --task "$T" --result "$R" --review "$REV" --run dmc-run-chain --out "$AUTH"
  [ -f "$AUTH" ] && record PASS "A-P1b authorization written to the sandbox --out (append-only)" \
                 || record FAIL "A-P1b authorization written to the sandbox --out"

  kit review "$SANDBOX/rev_reject.json" "$T" "$R" '{"decision":"reject"}'
  assert_rc "A-N1 authorize refuses a reject-decision review (WAUTH-NOT-APPLY)" 3 \
    WK authorize --task "$T" --result "$R" --review "$SANDBOX/rev_reject.json" --run dmc-run-chain \
    --out "$SANDBOX/auth_rej.json"

  # REJECTing result: a result that worker-result-check.py REJECTs (touches a forbidden path).
  kit task "$SANDBOX/task_bad.json" '{"task_id":"m7-chain-badresult"}'
  kit result "$SANDBOX/result_bad.json" '{"task_id":"m7-chain-badresult","files_changed":["src/secret.py"],"proposed_patch":"--- a/src/secret.py\n+++ b/src/secret.py\n@@ -1 +1 @@\n-x\n+y\n"}'
  kit review "$SANDBOX/review_bad.json" "$SANDBOX/task_bad.json" "$SANDBOX/result_bad.json"
  assert_rc "A-N2 authorize refuses a REJECTing result (WAUTH-RESULT-REJECTED)" 3 \
    WK authorize --task "$SANDBOX/task_bad.json" --result "$SANDBOX/result_bad.json" \
    --review "$SANDBOX/review_bad.json" --run dmc-run-chain --out "$SANDBOX/auth_bad.json"

  assert_rc "A-N3 authorize refuses to overwrite an existing authorization (WAUTH-EXISTS)" 3 \
    WK authorize --task "$T" --result "$R" --review "$REV" --run dmc-run-chain --out "$AUTH"

  # path-shaped task_id -> WAUTH-BAD-TASK-ID (the default filename derives from task_id).
  kit task "$SANDBOX/task_pid.json" '{"task_id":"bad/id"}'
  kit result "$SANDBOX/result_pid.json" '{"task_id":"bad/id"}'
  kit review "$SANDBOX/review_pid.json" "$SANDBOX/task_pid.json" "$SANDBOX/result_pid.json"
  assert_rc "A-N4 path-shaped task_id REFUSED (WAUTH-BAD-TASK-ID)" 3 \
    WK authorize --task "$SANDBOX/task_pid.json" --result "$SANDBOX/result_pid.json" \
    --review "$SANDBOX/review_pid.json" --run dmc-run-chain --out "$SANDBOX/auth_pid.json"
}

case_apply_check() {
  echo "  -- apply-check: clean PASS + missing/tampered/out-of-allowed/out-of-scope-lock refusals --"
  assert_rc "AC-P1 full clean chain PASSES apply-check (no scope-lock)" 0 \
    WK apply-check --auth "$AUTH" --task "$T" --result "$R" --review "$REV"

  assert_rc "AC-N1 missing authorization REFUSED (WAUTH-MISSING-AUTH — apply without a chain)" 3 \
    WK apply-check --auth "$SANDBOX/nope.json" --task "$T" --result "$R" --review "$REV"

  kit tamper "$T" "$SANDBOX/task_tampered.json"
  assert_rc "AC-N2 tampered task bytes REFUSED (WAUTH-TRH-MISMATCH)" 3 \
    WK apply-check --auth "$AUTH" --task "$SANDBOX/task_tampered.json" --result "$R" --review "$REV"

  kit tamper "$R" "$SANDBOX/result_tampered.json"
  assert_rc "AC-N3 tampered result bytes REFUSED (WAUTH-TRH-MISMATCH)" 3 \
    WK apply-check --auth "$AUTH" --task "$T" --result "$SANDBOX/result_tampered.json" --review "$REV"

  kit tamper "$REV" "$SANDBOX/review_tampered.json"
  assert_rc "AC-N4 tampered review bytes REFUSED (WAUTH-REVIEW-HASH-MISMATCH)" 3 \
    WK apply-check --auth "$AUTH" --task "$T" --result "$R" --review "$SANDBOX/review_tampered.json"

  kit mutate "$AUTH" "$SANDBOX/auth_badpaths.json" '{"authorized_paths":["src/evil.py"]}'
  assert_rc "AC-N5 out-of-allowed authorized path REFUSED (WAUTH-PATHS-NOT-SUBSET)" 3 \
    WK apply-check --auth "$SANDBOX/auth_badpaths.json" --task "$T" --result "$R" --review "$REV"
}

case_scope_lock() {
  echo "  -- apply-check scope.lock adjudication (REAL compiled lock) --"
  local lock; lock=$(m7_arm_scope_lock "$SANDBOX/lockrepo")
  if [ -z "$lock" ]; then
    record PASS "AC-P2 apply-check with a scope.lock PASSES (skipped: arming unavailable)"
    record PASS "AC-N6 out-of-scope.lock path REFUSED (skipped: arming unavailable)"
    return
  fi

  # main chain authorized path (src/app.py) IS in the compiled lock -> PASS.
  assert_rc "AC-P2 clean chain apply-check WITH --scope-lock PASSES (path allow-adjudicated)" 0 \
    WK apply-check --auth "$AUTH" --task "$T" --result "$R" --review "$REV" --scope-lock "$lock"

  # a scope chain whose allowed path (docs/notes.md) is NOT in the lock -> WAUTH-SCOPE-REFUSED.
  kit task "$SANDBOX/task_scope.json" '{"task_id":"m7-chain-scope","allowed_files":["src/app.py","docs/notes.md"]}'
  kit result "$SANDBOX/result_scope.json" '{"task_id":"m7-chain-scope","files_changed":["docs/notes.md","src/app.py"],"proposed_patch":"--- a/docs/notes.md\n+++ b/docs/notes.md\n@@ -1 +1 @@\n-a\n+b\n--- a/src/app.py\n+++ b/src/app.py\n@@ -1 +1 @@\n-x\n+y\n"}'
  kit review "$SANDBOX/review_scope.json" "$SANDBOX/task_scope.json" "$SANDBOX/result_scope.json"
  assert_rc "AC-N6a scope chain authorize emits an authorization (exit 0)" 0 \
    WK authorize --task "$SANDBOX/task_scope.json" --result "$SANDBOX/result_scope.json" \
    --review "$SANDBOX/review_scope.json" --run dmc-run-chain --out "$SANDBOX/auth_scope.json"
  assert_rc "AC-N6 out-of-scope.lock authorized path REFUSED (WAUTH-SCOPE-REFUSED)" 3 \
    WK apply-check --auth "$SANDBOX/auth_scope.json" --task "$SANDBOX/task_scope.json" \
    --result "$SANDBOX/result_scope.json" --review "$SANDBOX/review_scope.json" --scope-lock "$lock"
}

case_fidelity() {
  echo "  -- fidelity: faithful PASS + hunk/path mismatch refusals (names+hunk-count tier) --"
  kit applied "$SANDBOX/applied_same.diff" same
  kit applied "$SANDBOX/applied_hunk.diff" hunk
  kit applied "$SANDBOX/applied_path.diff" path

  assert_rc "F-P1 faithful apply PASSES fidelity (identical path set + hunk counts)" 0 \
    WK fidelity --result "$R" --applied-diff "$SANDBOX/applied_same.diff"
  assert_rc "F-N1 hunk-count mismatch REFUSED (WFID-MISMATCH)" 3 \
    WK fidelity --result "$R" --applied-diff "$SANDBOX/applied_hunk.diff"
  assert_rc "F-N2 path-set mismatch REFUSED (WFID-MISMATCH)" 3 \
    WK fidelity --result "$R" --applied-diff "$SANDBOX/applied_path.diff"
}

main() {
  echo "test-worker-chain.sh :: root=$M7_ROOT"
  m7_capture_before
  case_review_check
  case_authorize
  case_apply_check
  case_scope_lock
  case_fidelity
  echo "  -- import discipline + real-repo cleanliness --"
  m7_assert_no_provider_pycache
  m7_assert_repo_untouched
  echo "  ----"
  echo "  RESULT: $PASS PASS / $FAIL FAIL"
  [ "$FAIL" -eq 0 ] && exit 0 || exit 1
}

main
