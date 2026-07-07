#!/usr/bin/env bash
# test-install-roundtrip.sh — DMC v1 M8 host-install round-trip proof.
#
# Nature: hermetic TEST. Sources _m8common.sh; every install/uninstall/doctor
# call lands in a mktemp sandbox and the live repo is left byte-identical.
#
# Proves (plan dmc-v1-m8-host-install §Acceptance):
#   - the installer ships Ring-0 (bin/ + orchestration/) + the per-host adapter
#     surface (a --dry-run listing asserts them; per-host gating checked);
#   - for ALL FIVE fixture hosts: install -> `dmc doctor` (PASS, exit honest per
#     host shape) -> uninstall -> BYTE-CLEAN (git porcelain empty + diff -r);
#   - seeded Ring-0 omission => doctor exits non-zero naming Ring-0 missing;
#   - a single-quote-in-path host installs (the true eval-fragility falsifier)
#     and its shipped bin/dmc runs;
#   - the `.codex` provenance mechanism: a DMC-created .codex is fully removed on
#     uninstall; fresh -> install codex -> install codex (re-affirm, NO skip-warn)
#     -> uninstall is byte-clean; a FOREIGN .codex is skip-with-warn'd and stays
#     byte-unchanged through install AND uninstall;
#   - negative controls: ZERO DMC .gitignore lines and NO CLAUDE.md DMC section
#     remain post-uninstall.
#
# Usage: test-install-roundtrip.sh   (prints PASS/FAIL + summary, exits 0/1)

set -u
. "$(cd -- "$(dirname -- "$0")" && pwd)/_m8common.sh"
trap m8_cleanup EXIT

# --- Ring-0 + per-host ship-surface, asserted from a --dry-run listing ----------
arm_dryrun_listing() {
  echo "  -- dry-run ship-surface listing (Ring-0 + per-host gating) --"
  local H DRY_BOTH DRY_CLAUDE
  H=$(m8_mktemp dry); build_host_empty "$H" >/dev/null 2>&1
  DRY_BOTH=$(install_to "$H" --host both --dry-run 2>&1)
  assert_contains "$DRY_BOTH" "ship bin/dmc"                                 "dry-run: lists Ring-0 bin/dmc"
  assert_contains "$DRY_BOTH" "ship bin/lib/dmc-bash-radius.py"              "dry-run: lists a bin/lib/** verdict CLI"
  assert_contains "$DRY_BOTH" "ship orchestration/roles.json"               "dry-run: lists orchestration/roles.json"
  assert_contains "$DRY_BOTH" "ship orchestration/models.json"              "dry-run: lists orchestration/models.json"
  assert_contains "$DRY_BOTH" "ship orchestration/harness-matrix.json"      "dry-run: lists orchestration/harness-matrix.json"
  assert_contains "$DRY_BOTH" "ship adapters/codex/dmc-codex-pretooluse.py" "dry-run (both): lists a Codex adapter executable"
  assert_contains "$DRY_BOTH" "ship .agents/skills/dmc-critic"              "dry-run (both): lists a .agents/skills/dmc-* mirror"
  assert_contains "$DRY_BOTH" "ship .codex/config.toml"                     "dry-run (both): lists the .codex template"
  # Per-host gating: --host claude must NOT ship the Codex adapter surface.
  DRY_CLAUDE=$(install_to "$H" --host claude --dry-run 2>&1)
  assert_contains     "$DRY_CLAUDE" "ship bin/dmc"          "dry-run (claude): still ships Ring-0"
  assert_not_contains "$DRY_CLAUDE" "adapters/codex/"       "dry-run (claude): does NOT ship Codex adapters (per-host gating)"
  assert_not_contains "$DRY_CLAUDE" "ship .codex/"          "dry-run (claude): does NOT ship .codex templates"
}

# --- per-fixture install -> doctor -> uninstall -> byte-clean --------------------
roundtrip_one() { # NAME BUILDER HOSTARG
  local name="$1" builder="$2" hostarg="$3"
  local H PRIS OUT RC DOUT DRC UOUT URC gilines
  H=$(m8_mktemp "rt-$name")
  "$builder" "$H" >/dev/null 2>&1 || { record FAIL "$name: fixture build failed"; return; }
  PRIS=$(snapshot_pristine "$H")

  OUT=$(install_to "$H" --host "$hostarg" 2>&1); RC=$?
  assert_zero "$RC" "$name: install (--host $hostarg) exits 0"
  assert_file "$H/bin/dmc" "$name: Ring-0 bin/dmc shipped"
  assert_file "$H/.harness/install-receipt.json" "$name: install receipt written"

  DOUT=$(doctor_at "$H" 2>&1); DRC=$?
  assert_zero "$DRC" "$name: dmc doctor exits 0 on a well-formed install (honest per host shape)"
  assert_contains "$DOUT" "Result: PASS" "$name: doctor reports PASS"

  UOUT=$(uninstall_from "$H" 2>&1); URC=$?
  assert_zero "$URC" "$name: uninstall exits 0"
  assert_absent "$H/.harness/install-receipt.json" "$name: install receipt removed (last) by uninstall"

  # Negative controls: no DMC residue in merge targets (created => file gone;
  # merged => DMC block stripped) — both must leave ZERO DMC lines / marker.
  if [ -f "$H/.gitignore" ]; then
    gilines=$(grep -cE '# DMC:BEGIN|# DMC:END|\.harness/mode|install-receipt\.json' "$H/.gitignore" || true)
    assert_eq 0 "$gilines" "$name: ZERO DMC .gitignore lines remain post-uninstall (dead-skip bug falsifier)"
  fi
  if [ -f "$H/CLAUDE.md" ]; then
    assert_not_contains "$(cat "$H/CLAUDE.md")" '<!-- DMC:BEGIN -->' \
      "$name: CLAUDE.md DMC section absent post-uninstall (no-de-append bug falsifier)"
  fi

  assert_byte_clean "$H" "$PRIS" "$name"
}

arm_roundtrip_all_hosts() {
  echo "  -- five-fixture round-trip (install -> doctor -> uninstall -> byte-clean) --"
  roundtrip_one empty                    build_host_empty            claude
  roundtrip_one node                     build_host_node             both
  roundtrip_one existing-claude-settings build_host_claude_settings  claude
  roundtrip_one existing-OMC             build_host_omc              claude
  roundtrip_one existing-codex           build_host_codex            codex
}

# --- seeded Ring-0 omission => doctor non-zero naming Ring-0 ---------------------
arm_ring0_omission() {
  echo "  -- seeded Ring-0 omission --"
  local H DOUT DRC
  H=$(m8_mktemp r0); build_host_empty "$H" >/dev/null 2>&1
  install_to "$H" --host claude >/dev/null 2>&1
  rm -rf "$H/bin"   # seed: the unconditionally-shipped Ring-0 is missing
  DOUT=$(doctor_repo_at "$H" 2>&1); DRC=$?
  assert_nonzero "$DRC" "Ring-0 omission: doctor exits non-zero"
  assert_contains "$DOUT" "Ring-0 missing" "Ring-0 omission: doctor names 'Ring-0 missing'"
}

# --- eval-fragility: a single-quote in the host path (the true falsifier) --------
arm_single_quote_path() {
  echo "  -- single-quote-in-path (eval-fragility) --"
  local base H OUT RC hrc
  base=$(m8_mktemp sq)
  H="$base/it's a 'quoted' host"
  mkdir -p "$H"
  build_host_empty "$H" >/dev/null 2>&1 || { record FAIL "single-quote: fixture build failed"; return; }
  OUT=$(install_to "$H" --host claude 2>&1); RC=$?
  assert_zero "$RC" "single-quote-in-path: install exits 0 (act() eval-fragility fixed)"
  assert_file "$H/bin/dmc" "single-quote-in-path: bin/dmc shipped"
  "$H/bin/dmc" help >/dev/null 2>&1; hrc=$?
  assert_zero "$hrc" "single-quote-in-path: the shipped bin/dmc help runs"
}

# --- .codex provenance: a DMC-created .codex is fully removed on uninstall -------
arm_created_codex() {
  echo "  -- created-.codex (DMC-owned) full removal --"
  local H
  H=$(m8_mktemp ccx); build_host_empty "$H" >/dev/null 2>&1
  install_to "$H" --host codex >/dev/null 2>&1
  assert_file "$H/.codex/config.toml" "created-.codex: config.toml created"
  assert_file "$H/.codex/.dmc-created" "created-.codex: provenance sentinel dropped"
  assert_eq "# DMC-CREATED" "$(cat "$H/.codex/.dmc-created" 2>/dev/null)" "created-.codex: sentinel bytes pinned (# DMC-CREATED)"
  uninstall_from "$H" >/dev/null 2>&1
  assert_absent "$H/.codex" "created-.codex: .codex fully removed on uninstall (created-only)"
}

# --- .codex provenance sequence: fresh -> codex -> codex(re-affirm) -> uninstall -
arm_codex_provenance_seq() {
  echo "  -- codex provenance sequence (install -> install -> uninstall) --"
  local H PRIS OUT1 OUT2 cnt
  H=$(m8_mktemp cxseq); build_host_empty "$H" >/dev/null 2>&1
  PRIS=$(snapshot_pristine "$H")
  OUT1=$(install_to "$H" --host codex 2>&1)
  assert_contains "$OUT1" "creating from templates" "codex-seq: install#1 creates .codex (DMC-owned)"
  OUT2=$(install_to "$H" --host codex 2>&1)
  assert_contains     "$OUT2" "idempotent re-affirm" "codex-seq: install#2 re-affirms (DMC signal seen)"
  assert_not_contains "$OUT2" "NOT applied"          "codex-seq: install#2 does NOT skip-warn"
  cnt=$(find "$H/.codex" -name config.toml 2>/dev/null | wc -l | tr -d ' ')
  assert_eq 1 "$cnt" "codex-seq: exactly one .codex/config.toml (no duplication)"
  uninstall_from "$H" >/dev/null 2>&1
  assert_absent "$H/.codex" "codex-seq: DMC-created .codex removed on uninstall"
  assert_byte_clean "$H" "$PRIS" "codex-seq"
}

# --- foreign .codex is never touched (install + uninstall byte-unchanged) --------
arm_foreign_codex_untouched() {
  echo "  -- foreign .codex untouched --"
  local H PRIS FCX0 OUT
  H=$(m8_mktemp fcx); build_host_codex "$H" >/dev/null 2>&1
  PRIS=$(snapshot_pristine "$H")
  FCX0=$(sha256_of "$H/.codex/config.toml")
  OUT=$(install_to "$H" --host codex 2>&1)
  assert_contains "$OUT" "FOREIGN"     "foreign-.codex: install detects a foreign .codex"
  assert_contains "$OUT" "NOT applied" "foreign-.codex: skip-with-warn (Codex wiring NOT applied)"
  assert_eq "$FCX0" "$(sha256_of "$H/.codex/config.toml")" "foreign-.codex: config byte-unchanged after install"
  assert_absent "$H/.codex/.dmc-created" "foreign-.codex: NO DMC sentinel dropped over foreign content"
  uninstall_from "$H" >/dev/null 2>&1
  assert_eq "$FCX0" "$(sha256_of "$H/.codex/config.toml")" "foreign-.codex: config byte-unchanged after uninstall (never in receipt)"
  assert_byte_clean "$H" "$PRIS" "foreign-.codex"
}

main() {
  echo "test-install-roundtrip.sh :: root=$M8_ROOT"
  m8_capture_before
  arm_dryrun_listing
  arm_roundtrip_all_hosts
  arm_ring0_omission
  arm_single_quote_path
  arm_created_codex
  arm_codex_provenance_seq
  arm_foreign_codex_untouched
  m8_assert_repo_untouched
  m8_summary "test-install-roundtrip.sh"
}
main
