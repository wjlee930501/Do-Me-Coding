# Plan — G1 completion: uninstaller agent-removal symmetry

Work ID: dmc-v1-audit-remediation-g1fix

## Goal

Restore install/uninstall symmetry for the 6th canonical agent `release-auditor.md`: the uninstaller
must remove every agent the installer ships, so a full install→doctor→uninstall round-trip returns
the host byte-clean.

## User Intent

The user approved (2026-07-08 AskUserQuestion) completing the already-approved G1 fix with the
one-line uninstaller change, then re-verifying the FULL m8-suite (not just manifest-drift), re-pushing,
and confirming CI green before the main merge.

## Current Repo Findings

- `.claude/install/dmc-install.sh:41` `AGENTS="critic.md executor.md explorer.md planner.md
  release-auditor.md verifier.md"` — G1 shipped the 6th agent, and `:314` copies all six via `act`.
- `act()` (`:225`) does NOT call `record_created`, so agents are NEVER recorded in the install
  receipt's `created_paths` (empirically confirmed: receipt lists zero agents).
- Therefore agents are removed ONLY by the uninstaller's unconditional fixed-name list
  `.claude/install/dmc-uninstall.sh:66` `for a in critic executor explorer planner verifier; do rm_ ...`
  — which lists FIVE agents and omits `release-auditor`.
- Empirical: after install→uninstall, `.claude/agents/release-auditor.md` remains and `.claude/` is not
  removed → m8-suite install-roundtrip 75/8 FAIL (5 fixtures) + idempotency 15/2 FAIL, reproduced both
  locally and on the ubuntu CI runner (the F7 blocking m8-suite step is red on commit 6d571a8).
- Frozen legacy baseline is intact: live post-commit `selftest --all` = legacy 802/3/3 EXACT.

## Relevant Files

Allowed to Edit:
- `.claude/install/dmc-uninstall.sh` — add `release-auditor` to the fixed-name agent-removal list at :66.

## Out of Scope

- `.claude/install/dmc-install.sh` (already correct — ships 6 agents).
- `INSTALL_MANIFEST.md` (already lists 6 agents — G1).
- The `act()` receipt-recording behavior (a broader design change; not needed — the fixed-name list is
  the intended agent-removal path).
- All frozen legacy tools, schemas, and `.before-dmc` snapshots.

## Proposed Changes

Edit `.claude/install/dmc-uninstall.sh:66`, inserting `release-auditor` into the loop so the six-name
removal list matches the installer's `AGENTS`:
`for a in critic executor explorer planner release-auditor verifier; do rm_ ".claude/agents/$a.md"; done`

## Acceptance Criteria

- Criterion: Install/uninstall symmetry restored. Verification Method: a temp `--host claude` install
  then uninstall leaves no `.claude/agents/release-auditor.md` and no residual `.claude/`.
- Criterion: FULL m8-suite green. Verification Method: `bin/dmc selftest m8-suite` reports 0 FAIL across
  ALL four fixtures (install-roundtrip, idempotency, doctor-negcontrols, manifest-drift).
- Criterion: No regression elsewhere. Verification Method: `bin/dmc selftest` default 0 FAIL,
  `bin/dmc mirror-check` green, live `selftest --all` legacy 802/3/3 EXACT.
- Criterion: CI green post-push. Verification Method: the dmc-ci run on the new HEAD concludes success
  with the m8-suite blocking step passing.

## Risks

- Low. A one-token addition to an existing shell loop; `rm_` is idempotent (`rm -rf … 2>/dev/null`), so
  removing a possibly-absent path is safe. No frozen surface touched.

## Assumptions

- `release-auditor.md` is the only agent added by G1 (confirmed against the installer AGENTS list).
- The fixed-name list at :66 is the sole agent-removal path (confirmed: receipt records no agents).

## Execution Tasks

- [ ] DMC-T1: Add `release-auditor` to `.claude/install/dmc-uninstall.sh:66`. Files: `.claude/install/dmc-uninstall.sh`.

## Verification Commands

- `bin/dmc selftest m8-suite` → expect 0 FAIL (all four fixtures)
- temp install→uninstall round-trip → expect byte-clean, no release-auditor.md leftover
- `bin/dmc selftest` (default) → 0 FAIL; `bin/dmc mirror-check` → green
- `bin/dmc selftest --all` (live) → legacy 802/3/3 EXACT

## Approval Status

Status: APPROVED
Approver: wjlee (woojin20020@gmail.com)
