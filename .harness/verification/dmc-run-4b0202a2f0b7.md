# Verification Report

## Run ID

dmc-run-4b0202a2f0b7

(SUSPENDED; scope.lock armed and immutable. Supersedes dmc-run-e8b6a347af41 for gating with a corrected 3-path lock. Independently re-verified against APPROVED plan `.harness/plans/dmc-fable-core-regen-pin.md` Rev 3; no implementer transcript trusted — binding re-checked and the key suites re-run in a fresh read-only lane. The built candidate is byte-unchanged from the original run, so the full battery recorded there remains valid and is carried forward below.)

## Plan

`.harness/plans/dmc-fable-core-regen-pin.md` — fable-core follow-up (v1.1.4): committed==regenerated selftest pins for the generated artifacts. Binding chain independently verified (Rev 3):

- `shasum -a 256` of the plan = `e905ca9c7610709d7a9d337f5f74c4a06ba57d8f1fd12c95a2583d750fbfd38f`
- == `run.json` `plan_hash` (`e905ca9c…`) ✓
- == `scope.lock.json` `plan_hash` (`e905ca9c…`) ✓
- == critic r3 `plan_hash` (`e905ca9c…`) ✓ — verdict `APPROVE`, `lenses` [correctness, scope, security], `advisory: true`, `context_provenance: "fresh"`, `blockers: []`. (r2 `0c45ea98…` correctly superseded by the hash re-bind.)
- scope.lock `compiled_at_head` = `bbeb27702d23892a0482127996552f393b1fddad` == current HEAD == critic r3 `repo_hash` ✓.
- Operative-snapshot integrity: computed `scope.lock.json` sha256 = `fac0fcfc10aee99f2…` == `run.json` `operative_snapshot.scope_lock_sha256` ✓; computed `snapshot.txt` sha256 = `f0c0bcdf7112d8f8f…` == `operative_snapshot.snapshot_sha256` ✓.
- scope.lock `files[]` == EXACTLY the 3 candidate paths: `bin/dmc` (edit / enforcement / `landmark_authorized: true`), `docs/MILESTONES.md` (edit / release / `landmark_authorized: true`), `tests/fixtures/m6.5/test-agents-md-drift.sh` (create / ordinary). The two Rev-2 defensive "regenerate-IF-drift" rows (AGENTS.md, INSTALL_MANIFEST.md) are GONE from the lock. Bounds: `max_files 3`, `max_added 500`, `max_deleted 60`.
- run.json/scope.lock `repo_hash` = `dbe90b7f78c5cadd7…` (arming-time content hash of the now-staged tree; both artifacts agree — internally consistent; distinct from the git HEAD commit `bbeb277`, as expected).

## Supersession

- **Original run `dmc-run-e8b6a347af41` gate FAILED at G2, honestly recorded.** The preserved `.harness/runs/dmc-run-e8b6a347af41/release-readiness.json` records overall `verdict: "FAIL"`, driven solely by sub-gate `gate-checks` = `FAIL`: `"RGATE-GATE-CHECKS-FAIL … G2 FAIL approved files not staged: AGENTS.md INSTALL_MANIFEST.md; ==== SUMMARY: FAIL …"`. Every other sub-gate PASSED (approvals, chain, decision, diff-scope, findings, goal, receipts) and `landmark-flag` = `FLAG` on `bin/dmc` + `docs/MILESTONES.md`. That record binds the Rev-2 `plan_hash 0c45ea98…`. This is a Constitution-compliant honest FAIL record — the deterministic gate correctly caught a plan defect the advisory critic had endorsed (defense-in-depth working as designed; no masking, no edit-to-pass).
- **Root cause.** `sg_gate_checks` (`bin/lib/dmc-release-gate.py:393-394`) builds G2's allowlist from ALL `scope.lock files[].path`; the v0.2.6 runner G2 (`bin/lib/dmc-v0.2.6-gate-check-runner.sh:47-50`) FAILs unless every allowlist path is staged. The two never-firing regenerate-IF-drift rows were unsatisfiable staging obligations — they never drift, so they can never be staged, so G2 could never pass while they sat in the lock. (Source refs per critic r3; consistent with the FAIL reason string and the readiness artifact.)
- **Rev 3 fix.** The two conditional-edit rows were moved OUT of the lock: on drift the response is now HALT + open a follow-up scope (never a silent in-lock regen). The neutrality diffs remain REQUIRED verification commands, so drift DETECTION is fully preserved — only the RESPONSE changed from regenerate-in-lockstep to escalate-not-edit, which is strictly stricter. With the lock == exactly the 3 changed paths, G1 (staged ⊆ allowlist) and G2 (allowlist fully staged) are both satisfiable. Critic r3 also re-verified the fix is not a one-sided-lockstep or scope-expansion (it NARROWS 5→3, a strict subset of the already-authorized scope — no new human authorization required).
- **This run supersedes the original for gating.** Critic r3 APPROVE re-bound the plan to `e905ca9c…`; run `dmc-run-4b0202a2f0b7` was armed with the corrected 3-path lock. The built candidate is UNCHANGED between the two runs (identical staged numstat; same working-tree edits at HEAD `bbeb277`), so the verification battery below carries forward unchanged and was re-affirmed on the current staged tree.

## Changed Files

- `bin/dmc` (+3/−2, STAGED): `test-agents-md-drift.sh` appended to the `run_m65_suite` loop; `selftest m65-suite` usage prose names the new committed==regenerated AGENTS.md regen-drift pin. In-scope, edit / enforcement / `landmark_authorized`.
- `docs/MILESTONES.md` (+63/−0 pure append, STAGED): one `## v1.1.4` entry. In-scope, edit / release / `landmark_authorized`.
- `tests/fixtures/m6.5/test-agents-md-drift.sh` (NEW, 130 lines, STAGED as add): standalone hermetic AGENTS.md committed==regen drift suite. In-scope, create / ordinary.

(Crosscheck note: out-of-band and correctly OUTSIDE the lock and the staged set — `.codex/config.toml` (pre-existing model-config edit, unstaged, exempt) and the governance/evidence records `.harness/plans/dmc-fable-core-regen-pin.md`, `.harness/evidence/dmc-fable-core-regen-pin-critic-r{1,2,3}.json`, the prior verification report `.harness/verification/dmc-run-e8b6a347af41.md`, and the preserved `release-readiness.json` under the original run dir. None are staged; the staged set is exactly the 3 candidate paths.)

## Commands Run

| Command | Result | Reason | Output Summary |
|---|---|---|---|
| `git diff --cached --name-only` | PASS | staged set == exactly the 3 lock paths | `bin/dmc`, `docs/MILESTONES.md`, `tests/fixtures/m6.5/test-agents-md-drift.sh` |
| `git diff --cached --numstat` | PASS | candidate bytes unchanged since the original battery | `bin/dmc 3/2`, `docs/MILESTONES.md 63/0`, `test-agents-md-drift.sh 130/0` |
| `bash tests/fixtures/m6.5/test-agents-md-drift.sh` (re-affirm) | PASS | positive byte-equality + both negative controls + porcelain hermeticity | `RESULT: 8 PASS / 0 FAIL`, exit 0 |
| `bin/dmc selftest m65-suite` (re-affirm) | PASS | new pin wired into M6.5 group + blocking CI step | `M65-EXIT=0`; line-anchored actual `[FAIL]` records = 0; RESULT lines `test-codex-shims.sh 143/0`, `test-skills-mirror.sh 19/0` (+ `[skills-mirror] 7/0`), `test-agents-md.sh 35/0`, `test-agents-md-drift.sh 8/0` (the single `[FAIL]` substring is the benign PASS line "no internal [FAIL] lines emitted") |
| `bin/dmc agents-md --root . --stdout \| diff - AGENTS.md` | PASS | AGENTS.md derived-artifact neutrality (Rev 3 keeps this REQUIRED) | `AGENTS-NEUTRAL-EMPTY` (empty diff) |
| `bash .claude/install/dmc-install.sh --emit-manifest \| diff - INSTALL_MANIFEST.md` | PASS | INSTALL_MANIFEST neutrality (Rev 3 keeps this REQUIRED) | `MANIFEST-NEUTRAL-EMPTY` (empty diff) |
| `git rev-parse HEAD` | PASS | HEAD == compiled_at_head | `bbeb27702d23892a0482127996552f393b1fddad` |
| read `.harness/runs/dmc-run-e8b6a347af41/release-readiness.json` | PASS | supersession evidence | overall `FAIL`; `gate-checks FAIL` (G2 unstaged AGENTS.md/INSTALL_MANIFEST.md); all other sub-gates PASS; `landmark-flag FLAG` |

Full battery from the original run (unchanged candidate — carried forward): `bash -n bin/dmc` = `SYNTAX-OK`; `selftest m8-suite` = `test-install-roundtrip.sh 83/0`, `test-idempotency.sh 17/0`, `test-doctor-negcontrols.sh 16/0`, `test-manifest-drift.sh 10/0` (INSTALL_MANIFEST byte-equality pin re-affirmed); `selftest agents-md` = 27/0; CI read `.github/workflows/dmc-ci.yml` = blocking `selftest m65-suite` at `:172-173`, advisory `selftest --all` at `:191-194`, `.github/` absent from diff; porcelain hermeticity-in-situ held across the original battery.

Deliberately NOT run in this read-only lane (orchestrator/gate lane): clean-tree `bin/dmc selftest --all` (V15 dirty-tree misread — the live tree carries the staged candidate) and `bin/dmc gate release --full --run-id dmc-run-4b0202a2f0b7` (the gate's own re-run) — see the AC table PENDING rows.

## Manual Checks

| Check | Result | Notes |
|---|---|---|
| scope.lock `files[]` == exactly 3 paths, correct grants (Rev 3) | PASS | bin/dmc edit/enforcement/`landmark_authorized`; docs/MILESTONES.md edit/release/`landmark_authorized`; test create/ordinary; the two regenerate-IF-drift rows removed |
| staged set == the same 3 lock paths | PASS | `git diff --cached --name-only` == the 3; nothing else staged; `.codex/config.toml` unstaged |
| bounds match plan (3 files / 500 added / 60 deleted) | PASS | candidate = 3 files, 196 added (3+63+130) / 2 deleted — within 3/500/60 |
| candidate bytes unchanged vs original run | PASS | staged numstat identical to the original battery observation; suites re-run green |
| G2 precondition now satisfiable | PASS | allowlist (3 lock paths) == staged set (3) ⇒ G1 subset + G2 fully-staged both hold |
| PINNED_BASELINE (`dmc-legacy-selftest.py`) byte-untouched | PASS | not in the staged set or diff |
| no frozen `dmc-v0.*` tool / generator / `.github/` / m8 manifest test in the candidate | PASS | staged set is exactly the 3 in-scope paths |
| HEAD unchanged; verifier read-only | PASS | HEAD `bbeb2770`; no commit/push; I staged nothing (orchestrator staged the candidate) |

## Scope Review

Result: PASS

Notes: staged set == the exact 3 in-scope paths; lock == the same 3 (Rev 3 narrowed 5→3). AGENTS.md/INSTALL_MANIFEST.md are no longer in the lock — their neutrality is still verified as REQUIRED commands (both diffs EMPTY), with drift now escalating to HALT + follow-up scope rather than an in-lock regen. Bounds honored (3/196/2 within 3/500/60). No G4 override present or needed (no DEFAULT_PROTECTED path in scope). `bin/dmc` + `docs/MILESTONES.md` are enforcement/release-class landmarks → non-degrading FLAG expected at the gate (matches the original run's `landmark-flag FLAG`), consistent with prior-cycle precedent.

## Package / Env / Migration Review

Package files changed: no
Env files changed: no
Migration files changed: no

Notes: No dependency manifests, lockfiles, or migrations touched. No `.env`/secret file read or altered. The only non-source out-of-band file is `.codex/config.toml` (pre-existing, out-of-scope, unstaged).

## Acceptance Criteria Coverage

| # | Criterion | Observed Evidence | Verdict |
|---|---|---|---|
| 1 | AGENTS.md committed==regen pin wired and GREEN (positive) | `selftest m65-suite` runs `test-agents-md-drift.sh` all `0 FAIL`; assertion (1) byte-equality PASS; `selftest agents-md` 27/0 | MET |
| 2 | Pin has teeth (negative controls, constraint #7) | assertion (3) one-byte-of-a-COPY caught; assertion (4) regen-vs-section-deleted-COPY still FAILS (generator re-emits all sections; grep-removal falsifier + cmp both PASS → non-vacuous); assertion (5) porcelain byte-identical before/after | MET |
| 3 | INSTALL_MANIFEST committed==regen re-affirmed (already-existing) | `selftest m8-suite` green; `test-manifest-drift.sh` 10/0 byte-equality PASS (unchanged, not edited) | MET |
| 4 | Legacy 802/3/3 aggregate EXACT and UNCHANGED (no masking) | `PINNED_BASELINE` byte-untouched (not in candidate). Clean-tree `selftest --all` == `tools=49 PASS=802 FAIL=3 N/A=3` deferred (live tree carries the staged candidate → V15 dirty-tree misread) | PENDING-POST-COMMIT (orchestrator: committed-replica / clean post-commit tree with `.codex/config.toml` stashed; record in build evidence). PINNED_BASELINE-untouched portion MET |
| 5 | Derived artifacts neutral | `agents-md --root . --stdout \| diff - AGENTS.md` EMPTY; `--emit-manifest \| diff - INSTALL_MANIFEST.md` EMPTY — neither artifact drifted (Rev 3: on drift ⇒ HALT + follow-up scope, not in-lock regen) | MET |
| 6 | CI picks up the new pin, no workflow edit | `.github/workflows/dmc-ci.yml:172-173` blocking `selftest m65-suite` iterates `run_m65_suite` (now incl. the drift suite); `.github/` not in the candidate | MET |
| 7 | Scope + gate + ceiling (Rev 3 wording) | scope.lock `files[]` == EXACTLY the 3 changed paths AND staged set == the same 3 (both VERIFIED) — the original run's G2-unsatisfiable-obligation is resolved by construction; bounds honored; no G4 override; nothing committed/pushed. `dmc gate release --full --run-id dmc-run-4b0202a2f0b7` (expect PASS; non-degrading FLAG on bin/dmc + docs/MILESTONES.md; no override) is the orchestrator's staged-set re-run | Scope/lock/staged precondition MET; gate execution PENDING-POST-STAGING (orchestrator lane) |

## Unresolved Risks

- Clean-tree `bin/dmc selftest --all` == `802/3/3` EXACT (AC #4) is PENDING-POST-COMMIT — committed-replica or clean post-commit tree with `.codex/config.toml` stashed (dirty-tree V15 gotcha), recorded in build evidence. Not run here (read-only lane; the live tree carries the staged candidate).
- `bin/dmc gate release --full --run-id dmc-run-4b0202a2f0b7` (AC #7) is PENDING-POST-STAGING — the precondition that failed the original run (lock == staged == exactly 3) is now satisfied, so G2 is expected to PASS; the gate re-run is the orchestrator's step. Expected overall PASS with a non-degrading FLAG on the two landmarks, no G4 override.
- The original run `dmc-run-e8b6a347af41` retains its honest `release-readiness.json` FAIL artifact (preserved, not deleted) — correct governance record of the superseded attempt.
- Push / CI / main-FF remain a separate human gate; the standing fable-core envelope caps autonomy at LOCAL commit on `claude/dmc-fable-core`.

## Final Status

PASS — bound to `dmc-run-4b0202a2f0b7`. AC #4 (`--all` 802/3/3 EXACT) is PENDING-POST-COMMIT and AC #7's gate re-run is PENDING-POST-STAGING (its scope/lock/staged precondition is now MET, resolving the original run's G2 blocker by construction). Every check available to the read-only verifier lane is GREEN; no critical verification failed; the superseded run's G2 FAIL is honestly preserved.
