#!/usr/bin/env bash
# test-agents-md-drift.sh — DMC v1 M6.5 committed==regenerated AGENTS.md drift pin.
#
# Nature: hermetic TEST. Proves the repo's own committed AGENTS.md is byte-for-byte what
# `dmc agents-md --root <repo> --stdout` regenerates, so a future lockstep drift of the
# generated AGENTS.md (the cycle-D-core defect class, where INSTALL_MANIFEST drift was
# caught by the m8 suite but AGENTS.md drift escaped to a later critic by luck) escapes no
# cycle. Mirrors the INSTALL_MANIFEST pin in tests/fixtures/m8/test-manifest-drift.sh, homed
# with its own generator's suite family (agents-md -> M6.5). Standalone — no _m65common.sh
# dependency; owns its own record/PASS/FAIL, resolves ROOT=$SELF_DIR/../../.., drives the
# real bin/dmc.
#
# Asserts:
#   (1) POSITIVE — regen (`dmc agents-md --root <name-pinned DMC copy> --stdout`) == committed
#       AGENTS.md BYTE-FOR-BYTE (committed == regenerated; the artifact is its generator's output);
#   (2) GUARD — committed AGENTS.md exists and is non-empty (equality cannot pass vacuously);
#   (3) NEGATIVE (one-byte) — a one-byte mutation of a COPY of AGENTS.md is DETECTED (regen
#       vs the tampered copy FAILS): the pin has teeth;
#   (4) NEGATIVE (section-delete) — deleting a required `## N.` section from a COPY still
#       FAILS against the REGEN OUTPUT (the generator re-emits all ten sections, so deletion
#       cannot defeat the pin), mirroring test-manifest-drift.sh's re-emit semantics — this
#       compares the regen output to the section-deleted copy, NOT two tampered copies;
#   (5) HERMETIC — the live repo `git status --porcelain` is byte-identical before/after (a
#       DELTA check, never a pass/fail signal on tree state itself): every write is confined
#       to mktemp; the tracked AGENTS.md is READ, never written.
#
# NAME-PIN (F8): the generator titles AGENTS.md line 1 `# AGENTS.md — <root basename>`
# (bin/lib/dmc-agents-md.py:173), so a naive regen via `--root "$ROOT"` inherits the real
# checkout dir name and the positive byte-compare FAILS in ANY checkout dir != DMC (e.g. CI
# checks out `Do-Me-Coding` and the blocking m65-suite step would go red on push). The suite
# copies the working tree — INCLUDING .git, so repo-intel's `git check-ignore` parity survives —
# into a fixed-basename `$TMP/DMC` and regenerates from THAT, pinning the title to `— DMC`
# regardless of the real checkout dir name. The binary under test stays the repo's own bin/dmc;
# only `--root` is the name-pinned copy; this is a name pin, NOT a compare-minus-line-1 mask.
#
# Comparison base is the WORKING-TREE AGENTS.md (what is about to be committed matches its
# generator), never HEAD; the suite never branches on `git status` as a pass signal (no
# frozen-v0.6.0 tree-coupling flake — a pre-existing dirty tree cannot fail it).
#
# Never reads .env / credentials; never mutates the live repo; no network / live / model /
# API call; no subprocess beyond `bin/dmc`, `git status --porcelain`, and coreutils (incl.
# `cp -R` for the name-pin working-tree copy) in mktemp.
#
# Usage: test-agents-md-drift.sh   (prints PASS/FAIL + summary, exits 0 iff FAIL==0)

set -u

SELF_DIR=$(cd -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd -P) || { echo "FATAL: script dir"; exit 2; }
ROOT=$(cd -- "$SELF_DIR/../../.." >/dev/null 2>&1 && pwd -P) || { echo "FATAL: repo root"; exit 2; }
DMC="$ROOT/bin/dmc"
COMMITTED="$ROOT/AGENTS.md"

if ! git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "FATAL: repo root is not a git worktree: $ROOT"; exit 2
fi
[ -x "$DMC" ] || [ -f "$DMC" ] || { echo "FATAL: bin/dmc not found: $DMC"; exit 2; }

PASS=0; FAIL=0
record() { # record PASS|FAIL DESC
  if [ "$1" = PASS ]; then PASS=$((PASS+1)); printf '  [PASS] %s\n' "$2"
  else FAIL=$((FAIL+1)); printf '  [FAIL] %s\n' "$2"; fi
}

echo "test-agents-md-drift.sh :: root=$ROOT"
PORCELAIN_BEFORE=$(git -C "$ROOT" status --porcelain 2>/dev/null)

TMP=$(mktemp -d "${TMPDIR:-/tmp}/dmc-agents-md-drift.XXXXXX") || { echo "FATAL: mktemp"; exit 2; }
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

REGEN="$TMP/regen.md"
REGEN_ERR="$TMP/regen.err"

# ---- (2) GUARD: committed AGENTS.md exists and is non-empty --------------------
echo "  -- guard: committed AGENTS.md present --"
[ -s "$COMMITTED" ] \
  && record PASS "guard: committed AGENTS.md exists and is non-empty" \
  || record FAIL "guard: committed AGENTS.md missing or empty ($COMMITTED)"

# ---- NAME-PIN the root (F8): copy the working tree to a fixed-basename $TMP/DMC ---
# The generator titles AGENTS.md line 1 `# AGENTS.md — <root basename>`
# (bin/lib/dmc-agents-md.py:173). Regenerating from a `DMC`-named copy pins the title to
# `— DMC` (the committed value) regardless of the real checkout dir name (CI checks out
# `Do-Me-Coding`). Copy INCLUDING .git so repo-intel's `git check-ignore` parity survives.
echo "  -- name-pin: copy working tree to fixed-basename DMC dir (incl. .git) --"
PINNED="$TMP/DMC"
cp -R "$ROOT" "$PINNED"
{ [ -d "$PINNED" ] && [ -s "$PINNED/AGENTS.md" ] && [ -d "$PINNED/.git" ]; } \
  && record PASS "name-pin: working-tree copy at DMC-named dir incl. .git (check-ignore parity)" \
  || record FAIL "name-pin: DMC-named copy missing AGENTS.md or .git"

# ---- regenerate from the name-pinned copy (into mktemp; the tracked file is untouched)-
echo "  -- regenerate via dmc agents-md --root <name-pinned DMC copy> --stdout --"
"$DMC" agents-md --root "$PINNED" --stdout > "$REGEN" 2>"$REGEN_ERR"
REGEN_RC=$?
[ "$REGEN_RC" -eq 0 ] \
  && record PASS "regen: dmc agents-md --root <name-pinned copy> --stdout exits 0" \
  || record FAIL "regen: generator exit $REGEN_RC ($(head -1 "$REGEN_ERR" 2>/dev/null))"
[ -s "$REGEN" ] \
  && record PASS "regen: regenerated output is non-empty" \
  || record FAIL "regen: regenerated output is empty"

# ---- (1) POSITIVE: committed == regenerated, byte-for-byte ---------------------
echo "  -- positive: committed == regenerated --"
if cmp -s "$REGEN" "$COMMITTED"; then
  record PASS "positive: committed AGENTS.md == regenerated (byte-for-byte)"
else
  record FAIL "positive: committed AGENTS.md differs from regenerated ($(diff "$COMMITTED" "$REGEN" 2>&1 | head -3 | tr '\n' ';'))"
fi

# ---- (3) NEGATIVE (one-byte drift): a one-byte mutation of a COPY is caught -----
echo "  -- negative control: one-byte drift --"
TAMPERED="$TMP/tampered.md"
sed '1s/$/X/' "$COMMITTED" > "$TAMPERED"   # append one sentinel byte to line 1 of the COPY
if cmp -s "$COMMITTED" "$TAMPERED"; then
  record FAIL "neg-control (1-byte): the mutation did not alter the copy (control inert)"
elif cmp -s "$REGEN" "$TAMPERED"; then
  record FAIL "neg-control (1-byte): a one-byte AGENTS.md drift was NOT caught (pin toothless)"
else
  record PASS "neg-control (1-byte): a one-byte drift of a COPY => regen-vs-copy FAILS (caught)"
fi

# ---- (4) NEGATIVE (section-delete): deleting a `## N.` section still fails ------
# Delete section `## 6. ` from a COPY by its own heading and the next EMITTED heading
# (whatever number physically follows — AGENTS.md sections are not in monotonic physical
# order), then compare the REGEN OUTPUT (not a second tampered copy) to the section-deleted
# copy: the generator re-emits all ten sections, so deletion cannot defeat the pin (mirrors
# test-manifest-drift.sh's "cannot be defeated by deletion because the generator re-emits it").
echo "  -- negative control: section deletion --"
DROPPED="$TMP/dropped.md"
awk '/^## [0-9]+\. /{skip=($0 ~ /^## 6\. /)} !skip' "$COMMITTED" > "$DROPPED"
if grep -qE '^## 6\. ' "$DROPPED"; then
  record FAIL "neg-control (delete): section '## 6.' was not actually removed from the copy"
else
  record PASS "neg-control (delete): section '## 6.' removed from the copy"
fi
if cmp -s "$REGEN" "$DROPPED"; then
  record FAIL "neg-control (delete): a section-deleted AGENTS.md defeated the pin"
else
  record PASS "neg-control (delete): regen-vs-section-deleted-copy FAILS (generator re-emits all sections)"
fi

# ---- (5) HERMETIC: the live repo is byte-identical before/after ----------------
echo "  -- hermetic: real-repo cleanliness --"
PORCELAIN_AFTER=$(git -C "$ROOT" status --porcelain 2>/dev/null)
[ "$PORCELAIN_BEFORE" = "$PORCELAIN_AFTER" ] \
  && record PASS "hermetic: git status --porcelain unchanged by the suite (all writes in mktemp)" \
  || record FAIL "hermetic: real repo CHANGED during the suite (porcelain drift — a write escaped mktemp)"

echo "  ----"
echo "  RESULT: $PASS PASS / $FAIL FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
