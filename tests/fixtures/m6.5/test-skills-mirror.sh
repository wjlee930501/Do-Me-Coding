#!/usr/bin/env bash
# test-skills-mirror.sh — DMC v1 M6.5 (DMC-T011b.3) skills mirror/drift-check suite.
#
# Nature: INTEGRATION test for bin/lib/dmc-skills-mirror.py. Standalone — no shared
# tests/fixtures/m6.5/_m65common.sh dependency; this suite and T011b.2's Codex-shim suite own
# no files in common and may be authored concurrently.
#
# Runs the module's default (`--check`) mode against the REAL repo (expect green: the five
# milestone-scoped mirrored dmc-* skills all match under the module's documented
# frontmatter+host-note-strip normalization), then the module's `--self-test` mode (expect its
# own hermetic negative controls — one-byte drift, missing counterpart, unterminated host-note
# marker, unexpected extra skill — to all pass), then asserts the live repo's
# `git status --porcelain` is byte-identical before and after (the module's self-test claims to
# never touch the real repo; this suite verifies that claim externally too).
#
# Never reads .env / credentials; never mutates the live repo; no network / live / model / API
# call; no subprocess beyond `python3 bin/lib/dmc-skills-mirror.py` and `git status --porcelain`.
#
# Usage: test-skills-mirror.sh   Run both module modes, print PASS/FAIL + summary, exit 0/1.

set -u

SELF_DIR=$(cd -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd -P) || { echo "FATAL: script dir"; exit 2; }
ROOT=$(cd -- "$SELF_DIR/../../.." >/dev/null 2>&1 && pwd -P) || { echo "FATAL: repo root"; exit 2; }
MODULE="$ROOT/bin/lib/dmc-skills-mirror.py"

if ! git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "FATAL: repo root is not a git worktree: $ROOT"; exit 2
fi
[ -f "$MODULE" ] || { echo "FATAL: module not found: $MODULE"; exit 2; }

PASS=0; FAIL=0
record() { # record PASS|FAIL DESC
  if [ "$1" = PASS ]; then PASS=$((PASS+1)); printf '  [PASS] %s\n' "$2"
  else FAIL=$((FAIL+1)); printf '  [FAIL] %s\n' "$2"; fi
}

echo "test-skills-mirror.sh :: root=$ROOT"

PORCELAIN_BEFORE=$(git -C "$ROOT" status --porcelain 2>/dev/null)

echo "  -- check mode against the real repo (expect green) --"
CHECK_OUT=$(python3 "$MODULE" 2>&1); CHECK_RC=$?
printf '%s\n' "$CHECK_OUT" | sed 's/^/    /'
[ "$CHECK_RC" -eq 0 ] && record PASS "check mode: exit 0 (real repo mirrored-skill set green)" \
                       || record FAIL "check mode: exit $CHECK_RC (expected 0 — see output above)"
printf '%s\n' "$CHECK_OUT" | grep -qF 'RESULT: PASS skills-mirror green' \
  && record PASS "check mode: prints the PASS result line" \
  || record FAIL "check mode: missing the PASS result line"
for name in dmc-plan-hard dmc-critic dmc-start-work dmc-verify-hard dmc-status; do
  printf '%s\n' "$CHECK_OUT" | grep -qF "OK: $name" \
    && record PASS "check mode: $name reports OK" \
    || record FAIL "check mode: $name did not report OK"
done
printf '%s\n' "$CHECK_OUT" | grep -qF 'no unexpected extra dmc-* skills' \
  && record PASS "check mode: no unexpected extra dmc-* skills under .agents/skills" \
  || record FAIL "check mode: missing the no-extra-skills confirmation line"

echo "  -- self-test mode (module's own hermetic negative controls) --"
SELFTEST_OUT=$(python3 "$MODULE" --self-test 2>&1); SELFTEST_RC=$?
printf '%s\n' "$SELFTEST_OUT" | sed 's/^/    /'
[ "$SELFTEST_RC" -eq 0 ] && record PASS "self-test mode: exit 0 (all internal assertions passed)" \
                          || record FAIL "self-test mode: exit $SELFTEST_RC (expected 0 — see output above)"
SELFTEST_INTERNAL_FAILS=$(printf '%s\n' "$SELFTEST_OUT" | grep -c '^FAIL ')
[ "$SELFTEST_INTERNAL_FAILS" -eq 0 ] && record PASS "self-test mode: no internal [FAIL] lines emitted" \
                                       || record FAIL "self-test mode: $SELFTEST_INTERNAL_FAILS internal FAIL line(s) (see output above)"
printf '%s\n' "$SELFTEST_OUT" | grep -qE '^\[skills-mirror\] [0-9]+ PASS / 0 FAIL$' \
  && record PASS "self-test mode: prints the [skills-mirror] N PASS / 0 FAIL footer" \
  || record FAIL "self-test mode: missing the 0-FAIL footer line"

# Each of the module's own named assertions must be PRESENT and PASS (fixed-string match on
# the exact label text the module prints — see bin/lib/dmc-skills-mirror.py's selftest()).
while IFS= read -r label; do
  printf '%s\n' "$SELFTEST_OUT" | grep -qF "PASS [skills-mirror] $label" \
    && record PASS "self-test assertion present and PASS — $label" \
    || record FAIL "self-test assertion missing or not PASS — $label"
done <<'LABELS'
real .claude/skills <-> .agents/skills mirrored-set all OK (5 checked)
M1 synthetic clean pair (differing frontmatter + Codex host-note block) reports OK
M2 negative control: one-byte drift in a mirrored payload is REFUSED and the skill is named
M3 negative control: a missing Codex-side counterpart is REFUSED and named
M4 negative control: an unterminated DMC-HOST-NOTE:BEGIN marker fails CLOSED (reported as drift, not silently treated as absent)
M5 negative control: an unexpected extra dmc-* dir under the Codex skills tree is REFUSED and named
M6 negative controls never touched the real repo (pre/post content identical)
LABELS

echo "  -- real-repo cleanliness --"
PORCELAIN_AFTER=$(git -C "$ROOT" status --porcelain 2>/dev/null)
[ "$PORCELAIN_BEFORE" = "$PORCELAIN_AFTER" ] \
  && record PASS "real repo byte-identical: git status --porcelain unchanged by the suite" \
  || record FAIL "real repo CHANGED during the suite (porcelain drift — a write escaped the module's sandboxing)"

echo "  ----"
echo "  RESULT: $PASS PASS / $FAIL FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
