#!/usr/bin/env bash
# test-selftest-replica-default.sh — standalone hermetic test for the v1.1.6 committed-replica
# default of the `dmc selftest --all` legacy leg (`run_legacy_selftest_all` in bin/dmc).
#
# Nature: hermetic TEST. NOT wired into `bin/dmc selftest` (Ring-0 stays untouched; the
# install-wrapper / run-start-arming tests set the precedent). Every sandbox lands in an mktemp
# dir under $WORK; the live DMC repo is only READ (and asserted byte-identical by Z).
# Run:  bash tests/install/test-selftest-replica-default.sh
#
# Covers plan dmc-fable-core-replica-default (v1.1.6) Acceptance Criteria:
#   C1 default `selftest legacy-all` green ONCE on a DIRTY-tree + passive-mode sandbox, asserting
#      the aggregate `tools=49 PASS=802 FAIL=3 N/A=3` EXACT + PASS + rc 0 (tree+mode independence
#      in one shot — the whole point).
#   C2 two-tool FLIP for the TREE coupling: drive ONLY dmc-v0.6.0-verify.sh — V15 PASS from the
#      clean committed replica vs V15 FAIL --in-place on the dirty working tree.
#   C3 two-tool FLIP for the MODE coupling: drive ONLY dmc-v0.1.3-verify.sh — the `npm` ask
#      assertion PASSES from the replica (no mode file => active) vs FAILS --in-place under passive.
#   C4 the --in-place hatch: the in-place arms of C2/C3 reproduce the coupled FAIL the default
#      suppresses; plus a cheap flag-plumbing assertion that the pre-scan consumes --in-place.
#   C5 fail-loud: a broken clone precondition (non-git source) => distinct FATAL + nonzero, and
#      NEVER a silent fallback to the in-place leg (no 802 aggregate, no leg RESULT).
#   Z  hermetic proof — the real repo `git status --porcelain` is byte-identical before/after.
#
# ENV DISCIPLINE: pre-tool-guard.sh reads ${CLAUDE_PROJECT_DIR:-$PWD}/.harness/mode. This suite
# UNSETs CLAUDE_PROJECT_DIR so the guard falls back to $PWD (the per-tool cwd), faithfully modeling
# the clean CI / maintainer shell the committed-replica default targets. The replica-inherits-parent-
# env class is explicitly OUT OF SCOPE for v1.1.6 (a shell-hygiene class the replica cannot fix).

set -u
unset CLAUDE_PROJECT_DIR

REPO="$(cd -- "$(dirname -- "$0")/../.." && pwd)"
DMC="$REPO/bin/dmc"

[ -x "$DMC" ] || { echo "FATAL: bin/dmc not found or not executable: $DMC" >&2; exit 1; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dmc-replica-test.XXXXXX")"
WORK="$(cd "$WORK" && pwd)"    # canonicalize (macOS /tmp symlink)
trap 'rm -rf "$WORK"' EXIT

# ---------------------------------------------------------------- assertion helpers
PASS=0
FAIL=0
_pass() { PASS=$((PASS + 1)); printf 'PASS  %s\n' "$1"; }
_fail() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }
assert_eq()       { if [ "$1" = "$2" ]; then _pass "$3"; else _fail "$3 (expected='$1' actual='$2')"; fi; }
assert_ne()       { if [ "$1" != "$2" ]; then _pass "$3"; else _fail "$3 (value='$2' should differ)"; fi; }
assert_contains() { case "$1" in *"$2"*) _pass "$3" ;; *) _fail "$3 (missing substring: '$2')" ;; esac; }
assert_absent()   { case "$1" in *"$2"*) _fail "$3 (unexpected substring: '$2')" ;; *) _pass "$3" ;; esac; }

# ---------------------------------------------------------------- sandbox builders
# A full clone of the real repo's HEAD, then OVERLAY the working-tree bin/dmc (the change under
# test is uncommitted in the real repo) and commit it — so the replica the helper clones from HEAD
# actually contains run_legacy_selftest_all. Only bin/dmc is overlaid; the frozen v0.* tools are
# unchanged by this cycle, so their HEAD copies are already correct.
build_sandbox() { # dest
  git clone --no-hardlinks --quiet "$REPO" "$1" || return 1
  cp "$REPO/bin/dmc" "$1/bin/dmc"
  git -C "$1" add -A >/dev/null 2>&1 || return 1
  git -C "$1" -c user.email=dmc-test@example.invalid -c user.name=dmc-test \
    commit -q -m "test: overlay working-tree bin/dmc (change under test)" >/dev/null 2>&1 || return 1
}

echo "test-selftest-replica-default.sh :: repo=$REPO"
echo "                                    work=$WORK"
echo ""

BEFORE="$(git -C "$REPO" status --porcelain 2>/dev/null || true)"

# Sandbox SB: dirty (a tracked, non-allow-listed file) + passive mode — the adversarial tree.
SB="$WORK/sandbox"
build_sandbox "$SB" || { echo "FATAL: could not build sandbox" >&2; exit 1; }
printf '\n<!-- replica-default test dirt (tracked, outside the V15 allow-list) -->\n' >> "$SB/README.md"
mkdir -p "$SB/.harness"; printf 'passive\n' > "$SB/.harness/mode"

# Replica RP: a clean committed clone of SB's HEAD — what the default materializes (clean tree,
# no .harness/mode => active). Serves BOTH the C2 tree arm and the C3 mode arm.
RP="$WORK/replica"
git clone --no-hardlinks --quiet "$SB" "$RP"
git -C "$RP" remote remove origin >/dev/null 2>&1

# ================================================================ C5 fail-loud (fast; run early)
echo "-- C5: fail-loud provisioning failure, no silent in-place fallback --"
NG="$WORK/nongit"                       # a non-git dir under mktemp (outside any git work tree)
mkdir -p "$NG/bin/lib"
cp "$REPO/bin/dmc" "$NG/bin/dmc"; chmod +x "$NG/bin/dmc"
C5OUT="$("$NG/bin/dmc" selftest legacy-all 2>&1)"; C5RC=$?
assert_ne 0 "$C5RC" "C5: fail-loud exits nonzero (no silent success)"
assert_contains "$C5OUT" "FATAL: selftest --all replica provisioning failed" "C5: distinct FATAL message on the broken precondition"
assert_absent "$C5OUT" "PASS=802" "C5: no 802 aggregate printed (never fell back to in-place)"
assert_absent "$C5OUT" "SELFTEST-ALL RESULT" "C5: legacy leg never ran (no in-place fallback)"

# ================================================================ C2 tree-coupling two-tool FLIP
echo "-- C2: tree coupling FLIP (dmc-v0.6.0-verify.sh V15: replica PASS vs in-place FAIL) --"
V15_RP="$(bash "$RP/bin/lib/dmc-v0.6.0-verify.sh" --verify 2>&1 | grep -F 'V15' | head -1)"
V15_SB="$(bash "$SB/bin/lib/dmc-v0.6.0-verify.sh" --verify 2>&1 | grep -F 'V15' | head -1)"
assert_contains "$V15_RP" "[PASS]" "C2 replica: V15 PASSES on the clean committed replica (tree-independent)"
assert_contains "$V15_SB" "[FAIL]" "C2 in-place: V15 FAILS on the dirty working tree (coupling is real; = the hatch)"

# ================================================================ C3 mode-coupling two-tool FLIP
echo "-- C3: mode coupling FLIP (dmc-v0.1.3-verify.sh npm ask: replica active PASS vs in-place passive FAIL) --"
NPM_RP="$( (cd "$RP" && bash "$RP/bin/lib/dmc-v0.1.3-verify.sh" 2>&1) | grep -F 'pre-tool-guard npm ask' | head -1)"
NPM_SB="$( (cd "$SB" && bash "$SB/bin/lib/dmc-v0.1.3-verify.sh" 2>&1) | grep -F 'pre-tool-guard npm ask' | head -1)"
assert_contains "$NPM_RP" "PASS" "C3 replica: npm ask PASSES (no mode file => active; mode-independent)"
assert_contains "$NPM_SB" "FAIL" "C3 in-place: npm ask FAILS under passive (coupling is real; = the hatch)"

# ================================================================ C4 --in-place flag plumbing (cheap)
# The full-leg in-place belt (~10 min) is deliberately OMITTED to keep the suite within its runtime
# budget; the C2/C3 in-place arms above ARE the hatch reproduction. This cheap probe pins that the
# pre-scan actually consumes --in-place (routing it to SELFTEST_IN_PLACE) rather than treating it as
# a target: a stripped flag leaves 'badtarget' as the unknown target, not '--in-place'.
echo "-- C4: --in-place flag plumbing (pre-scan consumes the flag) --"
C4OUT="$("$DMC" selftest --in-place badtarget 2>&1)"
assert_contains "$C4OUT" "unknown target: badtarget" "C4: pre-scan leaves 'badtarget' (flag consumed, not mis-parsed as a target)"
assert_absent   "$C4OUT" "unknown target: --in-place" "C4: --in-place is NEVER treated as a target"

# ================================================================ C1 default green on the adversarial tree
# The dominant cost (~10 min): the full 49-tool legacy leg, run via the committed-replica DEFAULT
# against the DIRTY + passive SB sandbox. A clean 802/3/3 here proves tree- AND mode-independence.
echo "-- C1: default legacy-all green on a dirty + passive sandbox (~10 min; run and wait) --"
C1OUT="$("$SB/bin/dmc" selftest legacy-all 2>&1)"; C1RC=$?
assert_eq 0 "$C1RC" "C1: default legacy-all exits 0 despite dirty tree + passive mode"
assert_contains "$C1OUT" "aggregate: tools=49 PASS=802 FAIL=3 N/A=3 timeouts=" "C1: aggregate EXACT tools=49 PASS=802 FAIL=3 N/A=3"
assert_contains "$C1OUT" "PASS aggregate == pinned baseline exactly" "C1: aggregate == pinned baseline verdict"
assert_contains "$C1OUT" "SELFTEST-ALL RESULT: PASS" "C1: SELFTEST-ALL RESULT PASS"

# ================================================================ Z hermetic proof
echo "-- Z: hermetic proof (real repo untouched) --"
AFTER="$(git -C "$REPO" status --porcelain 2>/dev/null || true)"
assert_eq "$BEFORE" "$AFTER" "Z: real repo git status --porcelain byte-identical before/after"

# ---------------------------------------------------------------- summary
echo ""
echo "==== selftest replica-default test: $PASS passed, $FAIL failed ===="
if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
exit 0
