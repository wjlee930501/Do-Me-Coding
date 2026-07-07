#!/usr/bin/env bash
# test-doctor-negcontrols.sh — DMC v1 M8 `dmc doctor` falsifiability suite.
#
# Nature: hermetic TEST. Sources _m8common.sh; all writes land in mktemp
# sandboxes; the live repo is left byte-identical.
#
# Proves each `dmc doctor` claim is FALSIFIABLE (plan §Acceptance — doctor):
#   nc1  simulated-missing python3 (PATH-shim; doctor invoked via an absolute
#        python3 while python3 is absent from PATH) => the interpreter check
#        FAILS and doctor exits non-zero;
#   nc2  a core hook present on disk but UNREGISTERED in settings.json => doctor
#        FLAGS the wiring gap and exits non-zero;
#   nc3  a foreign harness (.omc) present => doctor reports non-interference /
#        passive (advisory — NOT a defect, exit 0);
#   nc4  a seeded "Codex hooks enforced/firing" line => the Codex-SCOPED
#        forbidden-lexeme grep FAILS (the honesty control has teeth);
#   P    positive control: the REAL doctor render's /codex/i lines carry ZERO
#        forbidden lexeme AND contain ADVISORY + pre-commit/CI, and no `active`
#        mode word rides a Codex line (host-independent mode).
#
# Usage: test-doctor-negcontrols.sh   (prints PASS/FAIL + summary, exits 0/1)

set -u
. "$(cd -- "$(dirname -- "$0")" && pwd)/_m8common.sh"
trap m8_cleanup EXIT

# --- nc1: simulated-missing python3 via a PATH shim -----------------------------
arm_nc1_missing_python3() {
  echo "  -- nc1 simulated-missing python3 (PATH shim) --"
  local H PY BASH JQ SHIM OUT RC
  H=$(m8_mktemp nc1); build_host_empty "$H" >/dev/null 2>&1
  install_to "$H" --host claude >/dev/null 2>&1   # Ring-0 present so the ONLY defect is the interpreter
  PY=$(command -v python3); BASH=$(command -v bash); JQ=$(command -v jq || true)
  SHIM=$(m8_mktemp shim)
  ln -s "$BASH" "$SHIM/bash"
  [ -n "$JQ" ] && ln -s "$JQ" "$SHIM/jq"
  # Invoke the doctor by ABSOLUTE python3, but with a PATH that lacks python3, so
  # shutil.which('python3') resolves to None inside the (still-running) doctor.
  OUT=$(env PATH="$SHIM" "$PY" "$M8_DOCTORLIB" --root "$H" 2>&1); RC=$?
  assert_nonzero "$RC" "nc1: doctor exits non-zero when python3 is missing from PATH"
  assert_contains "$OUT" "missing required interpreter(s): python3" "nc1: doctor names the missing python3 interpreter defect"
  assert_not_contains "$OUT" "Ring-0 missing" "nc1: the ONLY defect is the interpreter (Ring-0 was installed)"
}

# --- nc2: core hook on disk but unregistered => wiring gap -----------------------
arm_nc2_wiring_gap() {
  echo "  -- nc2 unregistered core hook => wiring gap --"
  local H OUT RC
  H=$(m8_mktemp nc2); build_host_empty "$H" >/dev/null 2>&1
  install_to "$H" --host claude >/dev/null 2>&1
  # Rewrite settings.json to register a NON-core hook only; the 6 core hooks stay on disk.
  python3 - "$H/.claude/settings.json" <<'PY'
import json, sys
obj = {"hooks": {"PreToolUse": [
    {"matcher": "Bash", "hooks": [
        {"type": "command",
         "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/host-own-hook.sh"}]}]}}
open(sys.argv[1], "w").write(json.dumps(obj, indent=2) + "\n")
PY
  OUT=$(doctor_at "$H" 2>&1); RC=$?
  assert_nonzero "$RC" "nc2: doctor exits non-zero on an unregistered core hook"
  assert_contains "$OUT" "WIRING GAP" "nc2: doctor FLAGS the wiring gap"
  assert_contains "$OUT" "pre-tool-guard.sh" "nc2: the wiring gap names the unregistered core hook"
}

# --- nc3: foreign harness => non-interference / passive (advisory) ---------------
arm_nc3_foreign_harness() {
  echo "  -- nc3 foreign harness (.omc) => non-interference --"
  local H OUT RC
  H=$(m8_mktemp nc3); build_host_omc "$H" >/dev/null 2>&1
  install_to "$H" --host claude >/dev/null 2>&1
  OUT=$(doctor_at "$H" 2>&1); RC=$?
  assert_zero "$RC" "nc3: a foreign harness is ADVISORY, not a defect (doctor exits 0)"
  assert_contains "$OUT" "Foreign harness detected" "nc3: doctor detects the foreign harness"
  assert_contains "$OUT" ".omc" "nc3: doctor names the .omc marker"
  assert_contains "$OUT" "non-interference" "nc3: doctor recommends non-interference / passive"
}

# --- nc4 + positive control: the Codex-scoped forbidden-lexeme grep --------------
arm_nc4_codex_honesty() {
  echo "  -- nc4 Codex-scoped forbidden-lexeme grep + positive control --"
  local H OUT POISONED clines
  H=$(m8_mktemp nc4); build_host_empty "$H" >/dev/null 2>&1
  install_to "$H" --host both >/dev/null 2>&1
  OUT=$(doctor_at "$H" 2>&1)
  clines=$(codex_lines_of "$OUT")

  # Positive control: the real render is honest.
  assert_eq 0 "$(codex_forbidden_hit_count "$OUT")" \
    "P: real doctor /codex/i lines carry ZERO forbidden enforced-class lexeme"
  assert_contains "$clines" "ADVISORY"      "P: the Codex section carries ADVISORY"
  assert_contains "$clines" "pre-commit/CI" "P: the Codex section names the pre-commit/CI backstop"
  assert_not_contains "$clines" "active"    "P: no 'active' mode word rides a Codex line (host-independent mode)"

  # nc4: seed a forbidden 'Codex enforced/firing' line — the scoped grep must trip.
  POISONED="$OUT"$'\n'"  codex hooks: enforced and firing at runtime (SEEDED DEFECT)"
  local hits; hits=$(codex_forbidden_hit_count "$POISONED")
  [ "$hits" -ge 1 ] \
    && record PASS "nc4: a seeded 'Codex enforced/firing' line => scoped grep FAILS (control has teeth)" \
    || record FAIL "nc4: seeded Codex-enforced line did NOT trip the scoped grep (control is toothless)"
}

main() {
  echo "test-doctor-negcontrols.sh :: root=$M8_ROOT"
  m8_capture_before
  arm_nc1_missing_python3
  arm_nc2_wiring_gap
  arm_nc3_foreign_harness
  arm_nc4_codex_honesty
  m8_assert_repo_untouched
  m8_summary "test-doctor-negcontrols.sh"
}
main
