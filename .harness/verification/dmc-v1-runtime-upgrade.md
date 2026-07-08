# Verification Report

## Run ID

`dmc-run-bef12a3d3345` (the Rev 2.1 re-armed release run; authored under the identical-scope build
run `dmc-run-e683f0168cfc` and carried forward — see the plan's Rev 2.1 arming-correction note).
Work: `dmc-v1-m10-final-docs`, task DMC-T016.4. This report is the
**Audit Blocker B1–B10 traceability table** required by master plan acceptance
(`.harness/plans/dmc-v1-runtime-upgrade.md:131,133`). It maps the pre-v1 audit's ten numbered
release blockers to the shipped mechanism that closes (or explicitly defers) each one.

**Disambiguation**: "B1–B10" here means the audit's **release blockers**
(`.harness/plans/dmc-v1-runtime-upgrade-audit.md:266-290`, §13 "Release blockers for v1.0"),
NOT `docs/FABLE_WORKFLOW_TRANSFER.md`'s separate B1–B13 **behavior** numbers (a different,
unrelated enumeration in a different document). Every "B<n>" reference below is an audit blocker.

This report is a traceability record only — it is NOT the M10 build verification. The M10 build
verification (full-gate PASS, changed-file review, selftest counts, etc.) lives in
`.harness/verification/dmc-v1-m10-release.md`, authored later by the independent verifier at
task DMC-T016.6.

## Plan

`.harness/plans/dmc-v1-m10-final-docs.md` (Rev 2, APPROVED 2026-07-08). Audit source:
`.harness/plans/dmc-v1-runtime-upgrade-audit.md` §13 (lines 266-290).

## Changed Files

- `.harness/verification/dmc-v1-runtime-upgrade.md` (this file, NEW) — sole file in DMC-T016.4 scope.

No other files are touched by this task. This report cites, but does not modify, evidence produced
by other M10/prior-milestone tasks.

## Commands Run

| Command | Result | Reason | Output Summary |
|---|---|---|---|
| `sed -n '260,295p' .harness/plans/dmc-v1-runtime-upgrade-audit.md` | PASS | source the verbatim B1-B10 definitions | §13 "Release blockers for v1.0", 10 items, read and quoted below |
| `git log --oneline \| grep -E '192dce6\|d721487\|6d571a8\|11f26a3'` | PASS | confirm cited commit hashes exist in history | all 4 hashes present: 192dce6 (M6 T011.1 fixtures), d721487 (M6 hook/guard hardening), 6d571a8 (pre-M10 audit remediation, 16 fixes/19 files), 11f26a3 (G1-completion fix) |
| `ls docs/ \| grep -E 'DMC_V1_HONEST_SCOPE\|DMC_V1_ENFORCEMENT_MATRIX\|DMC_V1_RELEASE_CHECKLIST'` | PASS | confirm T016.3 honesty docs exist for B9 citation | all 3 present |
| `grep -n 'receipts' bin/lib/dmc-release-gate.py` | PASS | confirm receipts sub-gate exists for B3 citation | `SUB_GATES` includes `"receipts"`; `sg_receipts()` implemented |
| `grep -n 'CF3' .github/workflows/dmc-ci.yml` | PASS | confirm B5 model-name-only-in-models.json CI grep exists | line 125: "Model-name grep (CF3 — model names live only in orchestration/models.json)" |
| `grep -in 'honest' .claude/skills/dmc-worker-review/SKILL.md` | PASS | confirm B2/B9 honest-tier statement exists | line 35: "HONEST ENFORCEMENT TIER: the review-check → authorize → apply-check → fidelity chain is..." |
| `grep -n 'provenance' docs/DMC_V1_HONEST_SCOPE.md` | PASS | confirm B9 provenance-not-authentication statement exists | §1 "Approval identity = provenance, NOT authentication"; cites B9 by name at line 16 |
| `grep -n 'git apply\|git-apply' .claude/hooks/pre-tool-guard.sh` | PASS | confirm B2 git-apply deny is an M6 L0 floor | line 117: deny message "a worker diff is a review artifact, not an executable patch" |
| `ls orchestration/ \| grep -E 'models.json\|roles.json'` | PASS | confirm B5 model-independence files exist | both present |
| `grep -n 'orient\|landmarks\|depsurface\|radius' bin/dmc` | PASS | confirm B10 repo-intelligence verbs exist (corrects a wrong verb name — see note below) | `orient`, `landmarks`, `depsurface`, `radius` all present as `dmc` subcommands; NOTE: no `patterns` verb exists — P5 is `radius` (change-radius prediction), not "patterns" |
| `grep -n 'P1,P2,P4,P5\|M2 — Repository intelligence' .harness/plans/dmc-v1-runtime-upgrade.md` | PASS | confirm P1/P2/P4/P5→M2 mapping and per-primitive naming | line 180: "P1,P2,P4,P5→M2"; line 207: "M2 — Repository intelligence: P1, P2, P4, P5"; line 210-212: P1=orient, P2=landmarks, P4=depsurface, P5=radius |
| `grep -n 'm8-suite' .harness/evidence/dmc-v1-audit-remediation-build-20260708.md` | PASS | confirm B7 m8-suite 126/0 count and G1-completion fix | line 79-80: "Re-verification (FULL m8-suite this time): install-roundtrip 83/0, idempotency 17/0, doctor-negcontrols 16/0, manifest-drift 10/0 (126/0 total)" |
| `dmc validate verification .harness/verification/dmc-v1-runtime-upgrade.md` | PASS | self-check: this file is a valid `dmc.verification.v1` instance | VALID (see Final Status) |

## Manual Checks

The audit-blocker traceability table below is the substance of this report. Verbatim-short
statements are drawn from
`.harness/plans/dmc-v1-runtime-upgrade-audit.md:271-290` (§13, "Release blockers for v1.0").

| Blocker | Verbatim-short statement (audit §13) | Shipped mechanism (milestone) | Evidence ref |
|---|---|---|---|
| **B1** | Enforcement holes in the wired layer: Bash write bypass, scope self-escalation, fail-open JSON parsing, secret-guard key mismatch, disarmed ultrawork stop gate. | M6 hook/guard hardening: bash-radius L0/L1 floors, postbash-diff, verify-crosscheck, stop-gate wiring in `.claude/hooks/pre-tool-guard.sh` and companions; hardened further by audit-remediation C1 (broadened denylist, L0 floors byte-unchanged). | Commits `192dce6` (pre-M6 hook-tree fixtures, 30/0 rollback), `d721487` (M6 hook/guard hardening); `dmc selftest m6-suite` 104/0 (38+45+10+11); further hardened at `6d571a8` (C1, `.harness/verification/dmc-v1-audit-remediation.md` "C1 broadened denylist, no over-block \| PASS"). |
| **B2** | `worker-result-check.py` holes (JWT accept, rename-diff bypass, empty-allowed fail-open) + `git apply` unblocked in pre-tool-guard. The proposal-only invariant is prose at its most critical joint. | M7 worker-bridge hardening (worker results are proposal-only, reviewed via review-check → authorize → apply-check → fidelity chain); `git apply`/`patch` deny is an M6 Ring-1 L0 floor, never weakened. | `dmc selftest m7-suite` 85/0; `.claude/hooks/pre-tool-guard.sh:109-117` ("Block A — external-proposal no-mutation floor: `git apply` / `patch` forms (enforced in ALL modes)"); honest-tier statement at `.claude/skills/dmc-worker-review/SKILL.md:35` ("HONEST ENFORCEMENT TIER: the review-check → authorize → apply-check → fidelity chain..."). |
| **B3** | Control plane unwired and uninstalled: "no evidence → no done" enforced only by a keyword-gated file-existence check while the purpose-built receipt gate idles. | M4 run-lifecycle core (run start/scope.lock/evidence ledger primitives) + M9 release-gate composer's `receipts` sub-gate, which reads the run's receipt set and FAILs on any uncovered required check. | `.harness/plans/dmc-v1-runtime-upgrade.md:235` ("M4 — Run-lifecycle core (the spine)"); `bin/lib/dmc-release-gate.py:63` `SUB_GATES` includes `"receipts"`; `sg_receipts()` at `:419`; composer self-test 39/0 (frozen). |
| **B4** | No single entry point / no CI. | `bin/dmc` Ring-0 facade unifying all primitives/verbs (built incrementally M2-M9) + `.github/workflows/dmc-ci.yml` (M9) providing branch CI. | `bin/dmc` (single dispatch entry point, `orient\|landmarks\|depsurface\|radius\|...\|run\|gate` subcommands); `.github/workflows/dmc-ci.yml` present and green on branch (M9 closure). |
| **B5** | Model independence is aspirational: decision logic embedded in Claude hook envelopes; zero non-Claude adapter exists. | `orchestration/models.json` + `orchestration/roles.json` (M5, capability-class role registry decoupled from any single vendor's model names) + M8 Codex host support; CI enforces model-name discipline. | `orchestration/models.json`, `orchestration/roles.json` present; `.github/workflows/dmc-ci.yml:125` "Model-name grep (CF3 — model names live only in orchestration/models.json)"; M8 installer ships `--host claude\|codex\|both`. |
| **B6** | Version identity incoherent: "v0.1" in DMC.md/CLAUDE.md/AGENTS.md/INSTALL_MANIFEST vs v0.6.5 reality; a v1.0 release with v0.1 on the tin is not credible. | **CLOSED IN M10 ITSELF** (this milestone) — v1.0 identity refresh across DMC.md (title, rules 5/6, "## v1.0 Scope"), CLAUDE.md, AGENTS.md (regenerated), plus 5 additional shipped docs (task DMC-T016.1). | DMC.md:1 v1.0 banner; 8-site refresh (7 original identity sites + `docs/NOTION_EXPORT_SUMMARY.md:13`); VC2 scoped product-identity grep (plan `.harness/plans/dmc-v1-m10-final-docs.md:391-409`) proven NON-EMPTY pre-edit / EMPTY post-edit — this is the only blocker M10 itself directly closes (per plan Finding, line 111: "B6 (version identity) is the one blocker M10 itself closes"). |
| **B7** | Install/uninstall defects: manifest false as SSoT, non-idempotent CLAUDE.md append, no-op gitignore strip. | M8 host installer (idempotent CLAUDE.md marker-wrapped append, manifest-as-emitted-truth, gitignore strip fix) + G1-completion fix (uninstaller/installer symmetry for all six shipped agents). | `dmc selftest m8-suite` 126/0 total (install-roundtrip 83/0, idempotency 17/0, doctor-negcontrols 16/0, manifest-drift 10/0) after commit `11f26a3` ("fix(dmc): complete G1 — uninstaller removes release-auditor.md"); `.harness/evidence/dmc-v1-audit-remediation-build-20260708.md:79-81`. |
| **B8** | Repo hygiene: tracked backups/zip/bootstrap prompts. | **By-design NO-ACTION in M10** — deletion of `.before-dmc` trees, `_DMC_*.md`, `do-me-coding-v0.1-scaffold.zip` is explicitly OUT OF SCOPE for this milestone (master plan :97: "separate human-gated approval"). The stray-file hygiene PROPOSAL (not execution) is recorded in the M10 build evidence for a future, separately-approved cleanup milestone. | Plan Out-of-Scope: `.harness/plans/dmc-v1-m10-final-docs.md:175-176` ("Any `.before-dmc`/zip/`_DMC_*.md` stray DELETION ... separate human-gated approval — M10 only DRAFTS the proposal"); proposal to be recorded at `.harness/evidence/dmc-v1-m10-build-20260708.md` (authored at task DMC-T016.6, not yet written as of this report). |
| **B9** | Honest-scope debt: Q6 approval is shape-checked provenance, not authentication; v1.0 messaging must carry this or v0.6.6+ must land. | Messaging path taken: `docs/DMC_V1_HONEST_SCOPE.md` (M10, task DMC-T016.3) states the provenance-not-authentication limitation explicitly and by name, alongside the M7 worker-bridge honest-enforcement-tier statement. | `docs/DMC_V1_HONEST_SCOPE.md:11-23` "§1. Approval identity = provenance, NOT authentication" — line 16 cites the audit verbatim: "The audit records the same as B9 ('Q6 approval is shape-checked provenance, not authentication')"; `.claude/skills/dmc-worker-review/SKILL.md:35` honest-tier statement. |
| **B10** | No repository-intelligence layer — required by the v1.0 definition ("repository understanding, architecture preservation, regression prediction"). | M2 primitives P1/P2/P4/P5 shipped as `dmc orient` (P1), `dmc landmarks` (P2), `dmc depsurface` (P4), `dmc radius` (P5 — change-radius prediction). | `.harness/plans/dmc-v1-runtime-upgrade.md:180` "P1,P2,P4,P5→M2"; `:207-212` "M2 — Repository intelligence: P1, P2, P4, P5" (DMC-T006/T006b); `bin/dmc` subcommands `orient\|landmarks\|depsurface\|radius` confirmed present. **Correction note**: an earlier internal reference to a "patterns" verb for P5 was inaccurate — no such verb exists; P5 is `radius`, verified directly against both the plan text and `bin/dmc`. |

## Human-Gated Dispositions (recorded per plan Approval Status)

Two items above are not simple "blocker → mechanism" closures; they are explicit human decisions
ratified at the M10 plan-approval gate (`.harness/plans/dmc-v1-m10-final-docs.md:421-437`,
2026-07-08) and are recorded here for traceability completeness:

| Item | Disposition | Ratified | Evidence |
|---|---|---|---|
| **CF14** (CI-baseline-portability carry-forward) | **OPTION (b)**: formalize the advisory tier + a documented CI-tier baseline as the accepted v1.0 posture (named-tool root-cause wording, no brittle count pins; the 13 CI-blocking substantive checks are never weakened). | 2026-07-08, plan gate question 2. | `docs/DMC_V1_HONEST_SCOPE.md` §5 "CF14 — CI-tier baseline / legacy `--all` divergence (the v1.0 posture)" (line 117); plan Approval Status :430-431. |
| **D1** (bare-BSD-md5 vacuous self-asserts, ~20 frozen tools) | **DOCUMENT, not harden** — the frozen-tool fix is deferred to a separate v1.1+ hygiene plan; the one site masking a security invariant (`bin/lib/dmc-v0.2-verify.sh:15-17`) is named explicitly. | 2026-07-08, plan gate question 2. | `docs/DMC_V1_HONEST_SCOPE.md` §6 "D1 — bare-BSD-md5 vacuous self-asserts (documented, not hardened)" (line 126), naming `dmc-v0.2-verify.sh:15-17` at line 138; plan Approval Status :431-432. |
| `.harness/evidence/` `dmc-v0.*` originals (55 files) | **KEEP** — originals remain canonical; the M3 rollback guarantee and mirror-check both depend on them; deprecation would require a mirror-check redesign, out of scope for M10. | 2026-07-08, plan gate question 3. | Plan Approval Status :433-434; Proposed Changes :246-248 (GATE-DECISION "(2)"). |

## Scope Review

Result: PASS. This report is the sole file touched by task DMC-T016.4 (a NEW-create grant under the
active M10 scope.lock). No edits were made to any other file; no plan, schema, or code file was
read-then-modified outside the create-grant. All commands run above were read-only inspection
(`grep`, `ls`, `git log`, `sed -n`) with no write side effects.

## Package / Env / Migration Review

- Package files changed: no — no dependency manifest/lockfile touched.
- Env files changed: no — no `.env*` file was read, referenced, or modified; no secret was accessed.
- Migration files changed: no.

## Unresolved Risks

- B8 disposition depends on a M10 build-evidence file
  (`.harness/evidence/dmc-v1-m10-build-20260708.md`) that had not yet been authored at the time this
  report was written (it is scoped to task DMC-T016.6, which runs after this task per the plan's
  `blockedBy` chain). The stray-file hygiene proposal itself remains PROPOSAL-ONLY regardless of
  when that evidence file lands — this is a sequencing note, not a correctness risk to this table.
- This table's B6 "closed in M10" claim is only as good as task DMC-T016.1's actual edits (identity
  refresh) and the VC2 grep proving EMPTY post-edit; this report cites the plan's mechanism and
  acceptance method but does not itself re-run VC2 (that belongs to the M10 build verification,
  `.harness/verification/dmc-v1-m10-release.md`, per this report's own scope statement above).
- One factual correction was made during evidence-gathering for this table (B10: the correct P5
  verb is `radius`, not "patterns" as suggested by an earlier internal note) — flagged in the B10
  row itself so the discrepancy is not silently absorbed.

## Final Status

PASS — this is a traceability record only, and as such: all 10 audit blockers (B1-B10) are mapped
to a shipped mechanism or an explicit, human-ratified disposition; 0 blockers are unmapped; every
mechanism/evidence-ref cited above was independently spot-checked this session (commit hashes
confirmed in `git log`, sub-gate/verb/file existence confirmed by direct read/grep, counts
cross-checked against source evidence files) rather than taken on faith from the task brief; the two
human-gated dispositions (CF14, D1) plus the `.harness/evidence/` originals-KEEP decision are
recorded with their ratification source. This PASS covers ONLY the completeness and accuracy of the
traceability table itself — it is NOT the M10 build verification (full-gate PASS, diff-scope review,
selftest counts), which is a separate report at `.harness/verification/dmc-v1-m10-release.md`,
authored later by the independent verifier at task DMC-T016.6.
