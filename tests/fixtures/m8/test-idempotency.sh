#!/usr/bin/env bash
# test-idempotency.sh — DMC v1 M8 install idempotency + real/dry-run proof.
#
# Nature: hermetic TEST. Sources _m8common.sh; all writes land in mktemp
# sandboxes; the live repo is left byte-identical.
#
# Proves (plan dmc-v1-m8-host-install §Acceptance — P19 idempotency):
#   - a DOUBLE install is a no-op: exactly ONE CLAUDE.md `<!-- DMC:BEGIN -->`
#     marker section, exactly ONE `# DMC:BEGIN` .gitignore block, and the DMC
#     settings.json hooks appear exactly once (no duplication) — and a single
#     uninstall after a double install still byte-restores the host;
#   - the install-receipt CLASSIFICATION is preserved across a re-install: a
#     merge target DMC CREATED from scratch stays `created` (removed whole on
#     uninstall) and a merged-into one stays `merged` (only the block stripped);
#   - the codex re-affirm case: a second `--host codex` install re-affirms
#     (idempotent), it does NOT skip-warn, and never duplicates .codex content;
#   - the `${DRY:+}` fix: a REAL install prints NO "(dry-run" text while a
#     `--dry-run` install does (falsifies the audited cosmetic bug).
#
# Usage: test-idempotency.sh   (prints PASS/FAIL + summary, exits 0/1)

set -u
. "$(cd -- "$(dirname -- "$0")" && pwd)/_m8common.sh"
trap m8_cleanup EXIT

# --- double install is a no-op over MERGE targets + reversible ------------------
arm_double_install_merge() {
  echo "  -- double install no-op (merge targets) --"
  local H PRIS bcount ecount gcount scount
  H=$(m8_mktemp idem-merge); build_host_claude_settings "$H" >/dev/null 2>&1
  PRIS=$(snapshot_pristine "$H")

  install_to "$H" --host claude >/dev/null 2>&1
  install_to "$H" --host claude >/dev/null 2>&1   # second install must not duplicate

  bcount=$(grep -cF '<!-- DMC:BEGIN -->' "$H/CLAUDE.md" || true)
  ecount=$(grep -cF '<!-- DMC:END -->'   "$H/CLAUDE.md" || true)
  gcount=$(grep -cF '# DMC:BEGIN'        "$H/.gitignore" || true)
  scount=$(grep -cF 'pre-tool-guard.sh'  "$H/.claude/settings.json" || true)
  assert_eq 1 "$bcount" "double-install: exactly ONE CLAUDE.md DMC:BEGIN marker"
  assert_eq 1 "$ecount" "double-install: exactly ONE CLAUDE.md DMC:END marker"
  assert_eq 1 "$gcount" "double-install: exactly ONE .gitignore # DMC:BEGIN block"
  assert_eq 1 "$scount" "double-install: DMC settings.json hook merged exactly once (no dup)"

  uninstall_from "$H" >/dev/null 2>&1
  assert_byte_clean "$H" "$PRIS" "double-install-then-uninstall"
}

# --- receipt classification preserved across re-install -------------------------
arm_receipt_classification() {
  echo "  -- receipt classification preserved across re-install --"
  # node fixture: DMC CREATES CLAUDE.md + settings.json (host had none), MERGES .gitignore.
  local H created merged
  H=$(m8_mktemp idem-class); build_host_node "$H" >/dev/null 2>&1
  install_to "$H" --host claude >/dev/null 2>&1
  install_to "$H" --host claude >/dev/null 2>&1   # re-install must not downgrade created->merged

  created=$(python3 -c 'import json,sys;print("\n".join(json.load(open(sys.argv[1]))["created_paths"]))' \
            "$H/.harness/install-receipt.json" 2>/dev/null)
  merged=$(python3 -c 'import json,sys;print("\n".join(json.load(open(sys.argv[1]))["merged_targets"]))' \
            "$H/.harness/install-receipt.json" 2>/dev/null)
  assert_contains "$created" "CLAUDE.md"              "classification: DMC-created CLAUDE.md STAYS created after re-install"
  assert_contains "$created" ".claude/settings.json" "classification: DMC-created settings.json STAYS created after re-install"
  assert_contains "$merged"  ".gitignore"            "classification: merged-into .gitignore STAYS merged after re-install"
  assert_not_contains "$merged" "CLAUDE.md"          "classification: created CLAUDE.md NOT downgraded to merged"
}

# --- codex re-affirm (idempotent second --host codex) ---------------------------
arm_codex_reaffirm() {
  echo "  -- codex re-affirm (second --host codex) --"
  local H OUT2 s0 s1 cnt
  H=$(m8_mktemp idem-codex); build_host_empty "$H" >/dev/null 2>&1
  install_to "$H" --host codex >/dev/null 2>&1
  s0=$(sha256_of "$H/.codex/config.toml")
  OUT2=$(install_to "$H" --host codex 2>&1)
  s1=$(sha256_of "$H/.codex/config.toml")
  assert_contains     "$OUT2" "idempotent re-affirm" "codex re-affirm: second install re-affirms (DMC signal)"
  assert_not_contains "$OUT2" "NOT applied"          "codex re-affirm: no misleading skip-with-warn on a DMC-owned .codex"
  assert_eq "$s0" "$s1" "codex re-affirm: .codex/config.toml byte-stable across re-affirm"
  cnt=$(find "$H/.codex" -name config.toml 2>/dev/null | wc -l | tr -d ' ')
  assert_eq 1 "$cnt" "codex re-affirm: exactly one .codex/config.toml (no duplication)"
}

# --- real vs dry-run text (the ${DRY:+} cosmetic-bug falsifier) ------------------
arm_real_vs_dryrun() {
  echo "  -- real vs dry-run text --"
  local H DRY REAL
  H=$(m8_mktemp idem-dry); build_host_empty "$H" >/dev/null 2>&1
  DRY=$(install_to "$H" --host claude --dry-run 2>&1)
  assert_contains "$DRY" "(dry-run" "dry-run: prints '(dry-run' text"
  REAL=$(install_to "$H" --host claude 2>&1)
  assert_not_contains "$REAL" "(dry-run" "real install: prints NO '(dry-run' text (\${DRY:+} bug fixed)"
}

main() {
  echo "test-idempotency.sh :: root=$M8_ROOT"
  m8_capture_before
  arm_double_install_merge
  arm_receipt_classification
  arm_codex_reaffirm
  arm_real_vs_dryrun
  m8_assert_repo_untouched
  m8_summary "test-idempotency.sh"
}
main
