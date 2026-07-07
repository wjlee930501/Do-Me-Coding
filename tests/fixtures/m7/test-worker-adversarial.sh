#!/usr/bin/env bash
# test-worker-adversarial.sh — DMC v1 M7 worker-validator negative controls (canonical (4)+(5)).
#
# Nature: ADVERSARIAL test. Each case drives the REAL enforcement surface — the live
# .claude/hooks/worker-result-check.py and .claude/hooks/worker-context-guard.sh — with mktemp
# JSON fixtures and asserts a REJECT / fail-closed where the audit demands one, PAIRED with a
# positive control so a blanket-deny cannot pass the suite. It proves canonical class (4)
# (JWT/OAuth/Bearer token material, value-blind), canonical class (5) (rename/copy/binary/
# c-quoted/zero-path diffs), the empty-allowed DENY, the task_id/provider cross-checks with the
# type=="mock" and empty-task-provider carve-outs, the result required-field floor, clean-REJECT
# malformed input, and the context-guard fail-closed property.
#
# Value-blind: token-shaped fixture values are SYNTHETIC (never real credentials), constructed by
# concatenation inside the kit, injected into a benign result field, and NEVER echoed by an
# assertion (only exit codes / verdicts are asserted). Never reads .env / credentials; never
# mutates the live repo (proven by a porcelain-before/after check); no network / live / model call.
#
# Usage: test-worker-adversarial.sh   Run all checks, print RESULT + summary, exit 0/1.

set -u

SELF_DIR=$(cd -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd -P) || { echo "FATAL: script dir"; exit 2; }
# shellcheck source=_m7common.sh
. "$SELF_DIR/_m7common.sh"

if ! git -C "$M7_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "FATAL: repo root is not a git worktree: $M7_ROOT"; exit 2
fi

SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/dmc-m7-adv.XXXXXX") || { echo "FATAL: mktemp"; exit 2; }
cleanup() { rm -rf "$SANDBOX"; }
trap cleanup EXIT

# ---- fixture kit: builds task/result JSON with overrides + synthetic token injection -----------
KIT="$SANDBOX/reskit.py"
cat > "$KIT" <<'PY'
import copy, json, sys

TASK_BASE = {
    "task_id": "m7-adv-001",
    "objective": "o",
    "allowed_files": ["src/app.py"],
    "forbidden_files": ["src/secret.py"],
    "context_summary": "c",
    "relevant_snippets": [],
    "expected_output_type": "diff",
    "provider_target": {"type": "mock", "provider": "mock-local"},
}
RESULT_BASE = {
    "task_id": "m7-adv-001",
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

# SYNTHETIC token-shaped fixtures — never real credentials. Built by concatenation so no complete
# token literal sits in source, and injected only into a benign field for the value-blind scan.
def _tokens():
    return {
        "jwt": "eyJ" + "aGVsbG8xMjM" + "." + "d29ybGRhYmM" + "." + "c2lnMDk4NzY",
        "bearer": "Bearer " + "aBcDeFgHiJkLmNoP",
        "authz": "Authorization: " + "Token0123456789ab",
        "access_token": "access_token=" + "aBcDeF0123456789Gh",
        "gho": "gho_" + "ABCDEFGHIJKLMNOPQRSTUVWZ",
        "ya29": "ya29." + "a0AfH1234567890abcdefGh",
        "sk": "sk-" + "abcdef0123456789ghij",
        "ghp": "ghp_" + "ABCDEFGHIJ0123456789KL",
        "placeholder": "access_token: <redacted>",
    }

def build(base, ov):
    o = copy.deepcopy(base)
    for k, v in ov.items():
        if v == "__DELETE__":
            o.pop(k, None)
        else:
            o[k] = v
    return o

def main():
    kind, outfile = sys.argv[1], sys.argv[2]
    ov = json.loads(sys.argv[3]) if len(sys.argv) > 3 else {}
    inj = ov.pop("_inject", None)
    base = TASK_BASE if kind == "task" else RESULT_BASE
    if inj is not None:
        field = "context_summary" if kind == "task" else "note"
        ov[field] = _tokens()[inj]
    obj = build(base, ov)
    with open(outfile, "w", encoding="utf-8") as f:
        json.dump(obj, f)

main()
PY

mk_task()   { local ov="${2:-}"; [ -n "$ov" ] || ov='{}'; python3 "$KIT" task   "$1" "$ov"; }
mk_result() { local ov="${2:-}"; [ -n "$ov" ] || ov='{}'; python3 "$KIT" result "$1" "$ov"; }

# check_result DESC EXPECTED_RC TASK RESULT  — drive worker-result-check.py, assert exit code.
check_result() {
  local desc="$1" exp="$2" t="$3" r="$4" rc
  python3 "$M7_RESULTCHECK" "$t" "$r" >/dev/null 2>&1; rc=$?
  assert_eq "$exp" "$rc" "$desc"
}

T="$SANDBOX/task.json"
R="$SANDBOX/result.json"

# ============================================================================
# Positive control: the canonical clean mock pair ACCEPTs (no over-blocking).
# ============================================================================
case_baseline() {
  echo "  -- positive control: clean mock task/result ACCEPTs --"
  mk_task "$T"; mk_result "$R"
  check_result "P0 clean mock task/result ACCEPTed (exit 0)" 0 "$T" "$R"
}

# ============================================================================
# Canonical (4): token/secret material in the result bundle -> REJECT (value-blind);
# a PLACEHOLDER-shaped value is NOT flagged (positive control).
# ============================================================================
case_class4() {
  echo "  -- canonical (4): token material REJECT + placeholder ACCEPT + legacy regression --"
  mk_task "$T"
  local cls
  for cls in jwt bearer authz access_token gho ya29; do
    mk_result "$R" "{\"_inject\":\"$cls\"}"
    check_result "c4 OAuth class [$cls] token in result REJECTed (value-blind)" 1 "$T" "$R"
  done
  for cls in sk ghp; do
    mk_result "$R" "{\"_inject\":\"$cls\"}"
    check_result "c4 legacy 5-class regression [$cls] still REJECTed" 1 "$T" "$R"
  done
  # PLACEHOLDER positive control: a <redacted>-shaped value is NOT real token material.
  mk_result "$R" '{"_inject":"placeholder"}'
  check_result "c4 PLACEHOLDER-shaped value ACCEPTed (not flagged — positive control)" 0 "$T" "$R"
}

# ============================================================================
# Canonical (5): rename/copy/binary/c-quoted/zero-path diffs -> REJECT; benign
# in-scope rename ACCEPTs; a space-bearing out-of-scope path is caught, not bypassed.
# ============================================================================
case_class5() {
  echo "  -- canonical (5): rename/copy/binary/c-quote/zero-path diffs --"

  # pure rename touching a FORBIDDEN file (previously zero-path -> vacuous pass).
  mk_task "$T" '{"allowed_files":["src/app.py","src/secret.py"]}'
  mk_result "$R" '{"proposed_patch":"diff --git a/src/app.py b/src/secret.py\nrename from src/app.py\nrename to src/secret.py\n","files_changed":["src/app.py","src/secret.py"]}'
  check_result "c5 pure rename-diff onto a forbidden path REJECTed" 1 "$T" "$R"

  # copy diff touching a FORBIDDEN file.
  mk_result "$R" '{"proposed_patch":"diff --git a/src/app.py b/src/secret.py\ncopy from src/app.py\ncopy to src/secret.py\n","files_changed":["src/app.py","src/secret.py"]}'
  check_result "c5 copy-diff onto a forbidden path REJECTed" 1 "$T" "$R"

  # binary diff (GIT binary patch + Binary files differ) touching an out-of-scope path.
  mk_task "$T"
  mk_result "$R" '{"proposed_patch":"diff --git a/src/data.bin b/src/data.bin\nGIT binary patch\nBinary files a/src/data.bin and b/src/data.bin differ\n","files_changed":["src/data.bin"]}'
  check_result "c5 binary-diff out-of-scope path REJECTed (now parsed, was zero-path)" 1 "$T" "$R"

  # c-quoted diff --git header (git-quoted path) -> refused, never best-effort unquoted.
  mk_result "$R" '{"proposed_patch":"diff --git a/\"src/weird\\tname.py\" b/\"src/weird\\tname.py\"\n@@ -1 +1 @@\n-x\n+y\n","files_changed":[]}'
  check_result "c5 c-quoted diff --git header REJECTed (fail-closed, no unquote)" 1 "$T" "$R"

  # non-empty patch that yields ZERO parsed paths -> unparseable-diff REJECT.
  mk_result "$R" '{"proposed_patch":"some random prose\nnot a diff at all\n","files_changed":[]}'
  check_result "c5 non-empty patch with zero parsed paths REJECTed (unparseable diff)" 1 "$T" "$R"

  # benign in-scope rename ACCEPTs (positive control — no over-blocking).
  mk_task "$T" '{"allowed_files":["src/app.py","src/app_new.py"],"forbidden_files":[]}'
  mk_result "$R" '{"proposed_patch":"diff --git a/src/app.py b/src/app_new.py\nrename from src/app.py\nrename to src/app_new.py\n","files_changed":["src/app.py","src/app_new.py"]}'
  check_result "c5 benign in-scope rename ACCEPTed (positive control)" 0 "$T" "$R"

  # space-bearing path OUT of scope is caught (over-reject acceptable, bypass impossible).
  mk_task "$T"
  mk_result "$R" '{"proposed_patch":"--- a/src/other file.py\n+++ b/src/other file.py\n@@ -1 +1 @@\n-x\n+y\n","files_changed":["src/other file.py"]}'
  check_result "c5 space-bearing out-of-scope path caught, not bypassed" 1 "$T" "$R"
}

# ============================================================================
# Empty / missing allowed_files -> REJECT (with a one-entry ACCEPT positive control).
# ============================================================================
case_empty_allowed() {
  echo "  -- empty/missing allowed_files DENY + one-entry ACCEPT control --"
  mk_result "$R"
  mk_task "$T" '{"allowed_files":[]}'
  check_result "empty allowed_files REJECTed (scope-less task refused)" 1 "$T" "$R"
  mk_task "$T" '{"allowed_files":"__DELETE__"}'
  check_result "missing allowed_files REJECTed" 1 "$T" "$R"
  mk_task "$T"   # one-entry allowed_files (["src/app.py"])
  check_result "one-entry allowed_files ACCEPTed (positive control)" 0 "$T" "$R"
}

# ============================================================================
# task_id + provider cross-checks (with the mock / empty-provider carve-outs) and
# the result required-field floor and malformed-JSON clean REJECT.
# ============================================================================
case_crosschecks() {
  echo "  -- task_id + provider cross-checks (carve-outs) + field floor + malformed --"

  # task_id mismatch (unconditional) -> REJECT.
  mk_task "$T"; mk_result "$R" '{"task_id":"m7-adv-999"}'
  check_result "task_id mismatch REJECTed (unconditional)" 1 "$T" "$R"

  # NON-mock provider type mismatch -> REJECT (negative control).
  mk_task "$T" '{"provider_target":{"type":"api_key","provider":"glm-api"}}'
  mk_result "$R" '{"provider_metadata":{"provider_type":"oauth_cli","provider":"oauth-cli","credential_exposure":"none","invocation_id":"inv-1"}}'
  check_result "non-mock provider_type mismatch REJECTed" 1 "$T" "$R"

  # NON-empty task provider mismatch -> REJECT (type matches, provider differs).
  mk_task "$T" '{"provider_target":{"type":"api_key","provider":"glm-api"}}'
  mk_result "$R" '{"provider_metadata":{"provider_type":"api_key","provider":"some-other-provider","credential_exposure":"none","invocation_id":"inv-1"}}'
  check_result "non-empty-provider mismatch REJECTed" 1 "$T" "$R"

  # type=="mock" carve-out: a mock task served by a foreign adapter -> ACCEPT (positive control).
  mk_task "$T"
  mk_result "$R" '{"provider_metadata":{"provider_type":"api_key","provider":"glm-api","credential_exposure":"none","invocation_id":"inv-1"}}'
  check_result "type==mock carve-out ACCEPTed (mock task + foreign provider, pinned v0.2.1 shape)" 0 "$T" "$R"

  # empty-task-provider (V6) carve-out: route-by-type -> ACCEPT (type equality still holds).
  mk_task "$T" '{"provider_target":{"type":"api_key","provider":""}}'
  mk_result "$R" '{"provider_metadata":{"provider_type":"api_key","provider":"glm-api","credential_exposure":"none","invocation_id":"inv-1"}}'
  check_result "empty-task-provider V6-shape ACCEPTed (type equality only)" 0 "$T" "$R"

  # required-field absence -> REJECT.
  mk_task "$T"; mk_result "$R" '{"instructions":"__DELETE__"}'
  check_result "result missing a required field (instructions) REJECTed" 1 "$T" "$R"

  # malformed result JSON -> clean REJECT (no traceback).
  mk_task "$T"
  printf '{bad json,,,' > "$SANDBOX/bad-result.json"
  local out rc err
  out=$(python3 "$M7_RESULTCHECK" "$T" "$SANDBOX/bad-result.json" 2>"$SANDBOX/err.txt"); rc=$?
  err=$(cat "$SANDBOX/err.txt")
  assert_eq 1 "$rc" "malformed result JSON REJECTed (exit 1)"
  assert_contains "$out" "REJECT" "malformed result prints a clean REJECT verdict"
  assert_not_contains "$err" "Traceback" "malformed result emits NO python traceback (fail-closed)"
}

# ============================================================================
# worker-context-guard.sh fail-closed: malformed task, secret path, token-in-bundle,
# python3-absent (PATH sabotage); a clean task passes.
# ============================================================================
case_context_guard() {
  echo "  -- worker-context-guard.sh fail-closed rows --"
  local rc

  # clean task -> exit 0 (positive control).
  mk_task "$T"
  bash "$M7_CTXGUARD" "$T" >/dev/null 2>&1; rc=$?
  assert_eq 0 "$rc" "context-guard: clean task passes (exit 0)"

  # malformed task JSON -> fail-closed exit 1.
  printf 'not json {' > "$SANDBOX/bad-task.json"
  bash "$M7_CTXGUARD" "$SANDBOX/bad-task.json" >/dev/null 2>&1; rc=$?
  assert_eq 1 "$rc" "context-guard: malformed task JSON fail-closed (exit 1, was silent exit 0)"

  # secret-bearing path in allowed_files -> blocked.
  mk_task "$T" '{"allowed_files":[".env.local"]}'
  bash "$M7_CTXGUARD" "$T" >/dev/null 2>&1; rc=$?
  assert_eq 1 "$rc" "context-guard: secret path in allowed_files blocked (exit 1)"

  # token material inline in the task bundle -> blocked (JWT in context_summary).
  mk_task "$T" '{"_inject":"jwt"}'
  bash "$M7_CTXGUARD" "$T" >/dev/null 2>&1; rc=$?
  assert_eq 1 "$rc" "context-guard: JWT token material in the bundle blocked (exit 1)"

  # python3 absent (PATH sabotage) -> fail-closed (was a silent pass on empty path list).
  mk_task "$T"
  local nopy="$SANDBOX/nopy" bashbin dn gp
  bashbin=$(command -v bash); dn=$(command -v dirname); gp=$(command -v grep)
  mkdir -p "$nopy"
  ln -s "$dn" "$nopy/dirname"; ln -s "$gp" "$nopy/grep"
  env PATH="$nopy" "$bashbin" "$M7_CTXGUARD" "$T" >/dev/null 2>&1; rc=$?
  assert_eq 1 "$rc" "context-guard: python3 absent (PATH sabotage) fail-closed (exit 1)"
}

main() {
  echo "test-worker-adversarial.sh :: root=$M7_ROOT"
  m7_capture_before
  case_baseline
  case_class4
  case_class5
  case_empty_allowed
  case_crosschecks
  case_context_guard
  echo "  -- import discipline + real-repo cleanliness --"
  m7_assert_no_provider_pycache
  m7_assert_repo_untouched
  echo "  ----"
  echo "  RESULT: $PASS PASS / $FAIL FAIL"
  [ "$FAIL" -eq 0 ] && exit 0 || exit 1
}

main
