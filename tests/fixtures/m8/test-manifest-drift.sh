#!/usr/bin/env bash
# test-manifest-drift.sh — DMC v1 M8 generated-manifest drift proof.
#
# Nature: hermetic TEST. Sources _m8common.sh; all writes land in mktemp
# sandboxes; the live repo is left byte-identical (the committed
# INSTALL_MANIFEST.md is READ, never written).
#
# Proves (plan §Acceptance — generated manifest):
#   - `dmc-install.sh --emit-manifest` == committed INSTALL_MANIFEST.md
#     BYTE-FOR-BYTE (the SSoT claim is true — the generator is the source);
#   - the emitted manifest CONTAINS the hand-authored `## Dangling-reference
#     rule` and `## DELIBERATELY NOT COPIED` sections (emitted from templated
#     constants), so exact-equality cannot be reached by deleting them;
#   - negative controls in a COPY: a hand-edited copy-table line => the drift
#     check FAILS; DELETING the Dangling-reference section => the drift check
#     STILL FAILS (the generator re-emits it);
#   - the §Dangling-reference rule HOLDS over the expanded ship-surface: after a
#     real install, no shipped file references an unbundled `.md` outside the
#     enumerated DMC-internal provenance set.
#
# Usage: test-manifest-drift.sh   (prints PASS/FAIL + summary, exits 0/1)

set -u
. "$(cd -- "$(dirname -- "$0")" && pwd)/_m8common.sh"
trap m8_cleanup EXIT

M8_WORK=""
_emit_to() { emit_manifest > "$1" 2>/dev/null; }

# --- byte-equality + section presence -------------------------------------------
arm_byte_equality() {
  echo "  -- --emit-manifest == committed INSTALL_MANIFEST.md --"
  M8_WORK=$(m8_mktemp manifest)
  local emitf="$M8_WORK/emit.md"
  _emit_to "$emitf"
  if cmp -s "$emitf" "$M8_MANIFEST"; then
    record PASS "byte-equality: --emit-manifest == committed INSTALL_MANIFEST.md (byte-for-byte)"
  else
    record FAIL "byte-equality: emitted manifest differs from committed ($(diff "$M8_MANIFEST" "$emitf" 2>&1 | head -3 | tr '\n' ';'))"
  fi
  grep -qF '## Dangling-reference rule' "$emitf" \
    && record PASS "section-presence: emitted manifest contains '## Dangling-reference rule'" \
    || record FAIL "section-presence: emitted manifest MISSING '## Dangling-reference rule'"
  grep -qF '## DELIBERATELY NOT COPIED' "$emitf" \
    && record PASS "section-presence: emitted manifest contains '## DELIBERATELY NOT COPIED'" \
    || record FAIL "section-presence: emitted manifest MISSING '## DELIBERATELY NOT COPIED'"
  grep -qF '## Dangling-reference rule' "$M8_MANIFEST" \
    && record PASS "section-presence: committed manifest contains '## Dangling-reference rule'" \
    || record FAIL "section-presence: committed manifest MISSING '## Dangling-reference rule'"
}

# --- negative controls: drift cannot be defeated by edit OR deletion -------------
arm_drift_negcontrols() {
  echo "  -- drift negative controls (hand-edit + section-deletion) --"
  local emitf="$M8_WORK/emit.md" edited="$M8_WORK/edited.md" dropped="$M8_WORK/dropped.md"

  # (a) hand-edited copy-table line in a COPY of the committed manifest.
  cp "$M8_MANIFEST" "$edited"
  python3 - "$edited" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read().replace("- `bin/dmc`", "- `bin/TAMPERED`", 1)
open(p, "w").write(s)
PY
  if cmp -s "$emitf" "$edited"; then
    record FAIL "neg-control (edit): a hand-edited copy-table line was NOT caught (drift toothless)"
  else
    record PASS "neg-control (edit): a hand-edited copy-table line => drift check FAILS (caught)"
  fi

  # (b) DELETE the Dangling-reference section from a COPY — the generator re-emits it.
  cp "$M8_MANIFEST" "$dropped"
  python3 - "$dropped" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
i = s.find("## Dangling-reference rule")
if i != -1:
    s = s[:i]
open(p, "w").write(s)
PY
  grep -qF '## Dangling-reference rule' "$dropped" \
    && record FAIL "neg-control (delete): the section was not actually deleted from the copy" \
    || record PASS "neg-control (delete): Dangling-reference section removed from the copy"
  if cmp -s "$emitf" "$dropped"; then
    record FAIL "neg-control (delete): deleting the safety section defeated the drift check"
  else
    record PASS "neg-control (delete): deleting the Dangling-reference section => drift STILL FAILS (generator re-emits it)"
  fi
}

# --- Dangling-reference rule holds over the real installed surface ---------------
arm_dangling_ref_scan() {
  echo "  -- dangling-reference scan over the installed ship-surface --"
  local H refs ref dangling=0 scanned=0
  H=$(m8_mktemp dref); build_host_empty "$H" >/dev/null 2>&1
  install_to "$H" --host both >/dev/null 2>&1
  # Path-like (contains '/') .md references in the shipped OPERATING surface. A
  # bare basename (SKILL.md, a runtime current-run.md) is a self/runtime reference,
  # not a cross-file operating dependency, so the scan targets path-like refs.
  refs=$(grep -rhoE '[A-Za-z0-9_.-]+/[A-Za-z0-9_./-]*\.md' \
    "$H/adapters" "$H/.agents/skills" "$H/.claude/skills" "$H/.claude/agents" \
    "$H/DMC.md" "$H/CLAUDE.md" 2>/dev/null | sort -u)
  while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    scanned=$((scanned + 1))
    [ -e "$H/$ref" ] && continue                 # resolves to a bundled file
    m8_is_provenance_ref "$ref" && continue      # enumerated DMC-internal provenance exclusion
    dangling=$((dangling + 1))
    record FAIL "dangling-ref: shipped surface references an unbundled .md: $ref"
  done <<EOF
$refs
EOF
  assert_eq 0 "$dangling" "dangling-ref: NO shipped file references an unbundled .md (provenance exclusions honored)"
  [ "$scanned" -gt 0 ] \
    && record PASS "dangling-ref: scan covered $scanned path-like .md references (non-empty surface)" \
    || record FAIL "dangling-ref: scan found NO references — grep/surface broken"
}

main() {
  echo "test-manifest-drift.sh :: root=$M8_ROOT"
  m8_capture_before
  arm_byte_equality
  arm_drift_negcontrols
  arm_dangling_ref_scan
  m8_assert_repo_untouched
  m8_summary "test-manifest-drift.sh"
}
main
