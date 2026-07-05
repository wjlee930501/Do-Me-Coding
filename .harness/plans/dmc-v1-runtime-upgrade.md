# Plan: DMC v1.0 Runtime Upgrade — model-independent AI runtime

Plan ID: dmc-v1-runtime-upgrade · Date: 2026-07-05 · Format: PLAN_SCHEMA.md
**Rev 2** — revised after DMC critic REJECT (same session). Blockers closed: (1) every REQUIRED
primitive now has an owning task (P-coverage map in §Execution Tasks); (2) Relevant Files table
authorizes all planned edits incl. M1 deliverables and pointer-ized docs; (3) milestone tags
reconciled (hooks: M6+M7, fixtures: M2/M8/M9; M7 carries the protected-surface tag); (4) M3
rollback re-specified as **copy-then-shim** with a tested procedure; (5) run-lifecycle core (M4)
now precedes skill wiring (M5). Non-blocking items 6–11 also addressed inline.
Format note (critic item 11): Execution Tasks extend the schema's `Notes:` field into a
per-milestone block {Acceptance, Verification, Rollback, Evidence, Not-edit, Risk}; the M3 plan
validator MUST accept this extension.

## Goal

Bring DMC from v0.6.5 to a production-grade **v1.0 model-independent AI runtime**: a portable
Ring-0 core (`bin/dmc` + state + schemas) whose gates fire without being asked, harness adapters
(Claude Code full; Codex minimal; OpenCode stub), a repository-intelligence layer, hardened
enforcement closing the audited bypasses, an orchestration registry binding agents/workers to
capability classes, and a host install that actually ships the control plane.

## User Intent

Classify: **feature** (secondary aspects: refactor — relocation/wiring of shipped tools;
docs — v1.0 architecture and release docs).

## Current Repo Findings

- Finding: only 6 Claude Code hooks enforce anything at runtime; all v0.2.6–v0.6.5 control-plane
  tools are advisory and unwired; zero hooks invoke `.harness/evidence/` validators.
  Source: `.harness/plans/dmc-v1-runtime-upgrade-audit.md` §1, §4.3 (settings.json; grep
  evidence).
- Finding: enforcement bypasses in the wired layer — Bash write bypass of scope, scope
  self-escalation via `.harness/runs` auto-allow, fail-open on missing python3/jq, secret-guard
  reads wrong tool-input keys, `/dmc-ultrawork` never arms the stop gate, `git apply` unblocked.
  Source: audit §3 (scope-guard.sh:58-78, secret-guard.sh:102-103, dmc-ultrawork/SKILL.md:29,
  pre-tool-guard.sh). Critic re-verified 9/9 citations (critic verdict, this session).
- Finding: `worker-result-check.py` accepts JWT-bearing results and rename-diff scope bypasses;
  empty `allowed_files` disables scope; review stage is 100% prose. Source: audit §3
  (empirical), worker-result-check.py:21-34,59-61.
- Finding: host installs are frozen at the v0.1.3 surface; INSTALL_MANIFEST's SSoT claim is
  false; uninstaller gitignore strip is a no-op; CLAUDE.md append non-idempotent.
  Source: audit §10 (INSTALL_MANIFEST.md:3,44-47; dmc-install.sh:106-112;
  dmc-uninstall.sh:34-44).
- Finding: no single entry point, no CI, no plan/run/verification validators, no repository
  intelligence, agents orphaned, three drifted role taxonomies, version identity "v0.1" vs
  v0.6.5 reality, tracked stray backups/zip. Source: audit §4, §5, §11, §12, §13.

## Relevant Files

| Path | Reason | Allowed to Edit |
|---|---|---|
| bin/** (new) | Ring-0 CLI façade + relocated-tool routing | yes (new; M2–M9) |
| adapters/** (new) | Ring-1 harness adapters (claude-code, codex, opencode) | yes (new; M6, M8) |
| orchestration/** (new) | roles.json, models.json | yes (new; M5, M8) |
| tests/fixtures/** (new) | fixture repos (M2 intelligence, M8 install hosts, M9 E2E) | yes (new; M2/M8/M9) |
| .harness/plans/dmc-v1-runtime-upgrade*.md | this plan + audit (M1 deliverables) | yes (M1) |
| docs/FABLE_WORKFLOW_TRANSFER.md, docs/DMC_V1_RUNTIME_ARCHITECTURE.md, docs/DMC_V1_ORCHESTRATION_MODEL.md | M1 deliverables; consistency edits when plan revs | yes (M1, M10) |
| .harness/evidence/dmc-v1-*.md, .harness/verification/dmc-v1-*.md | per-milestone evidence/verification | yes (all milestones) |
| .claude/hooks/*.sh, .claude/settings.json | Ring-1 shims + hardening | yes (M6 — protected, gated) |
| .claude/hooks/worker-result-check.py, .claude/hooks/worker-context-guard.sh | worker validator hardening | yes (M7 — protected, gated) |
| .claude/skills/*/SKILL.md | bind skills to `dmc` verbs + role registry | yes (M5) |
| .claude/agents/*.md (+ release-auditor.md new) | contract-ized prompts | yes (M5) |
| docs/DMC_AGENT_HANDOFF.md, docs/DYNAMIC_DELEGATION.md, docs/DMC_DELEGATION_HARNESS.md | become pointers to orchestration/roles.json | yes (M5) |
| .claude/install/dmc-install.sh, dmc-uninstall.sh | P19 fixes + Ring-0 shipping | yes (M8) |
| INSTALL_MANIFEST.md | regenerated-from-installer section | yes (M8) |
| .harness/schemas/*.schema.md (new: orientation, landmarks, depsurface, radius, acceptance, scope-lock, fixloop, delegation, critic-verdict, worker-review; existing: evidence-receipt check_id extension) | primitive schemas | yes (M3; evidence-receipt extension M4) |
| PLAN_SCHEMA.md / RUN_SCHEMA.md / VERIFICATION_SCHEMA.md (+ .harness/schemas mirrors) | validator refs; canonical-home declaration + mirror check | yes (M3) |
| .github/workflows/dmc-ci.yml (new) | CI running selftest + suites | yes (M9) |
| docs/DMC_V1_ENFORCEMENT_MATRIX.md, docs/DMC_V1_RELEASE_CHECKLIST.md, docs/DMC_V1_HONEST_SCOPE.md (new) | M10 release docs | yes (M10) |
| DMC.md, CLAUDE.md, AGENTS.md, docs/CONTEXT_MAP.md | v1.0 identity refresh | yes (M10) |
| docs/MILESTONES.md | append-only closure entry | yes (M10, human-gated) |
| .harness/evidence/dmc-v0.*.{sh,py} | **copy** sources for bin/lib (originals untouched until M10 deprecation decision) | copy-only (M3); no in-place edit |

## Out of Scope

- Any live provider call, any network call, any credential handling change beyond redaction
  patterns. GLM/OAuth adapters' live paths untouched.
- `.claude/workers/providers/**` (adapters, router, contract) — no edits in any milestone.
- Cryptographic approval authentication (honest-scope-labeled; v1.1+).
- LSP/AST dependency analysis; async worker jobs/retry/cost routing; OpenCode full adapter;
  web/mobile/MCP surfaces.
- Rewriting shipped v0.2.6–v0.6.5 validator logic (copy + route + named hardening only).
- Deleting `.before-dmc`/zip strays (separate hygiene proposal, own human approval).
- Any push to main/master, any closure entry before human gates.

## Proposed Changes

- Change: Ring-0 `bin/dmc` façade + state root. Files: bin/**. Rationale: single entry point;
  portability (audit B4, B5).
- Change: repository-intelligence primitives P1/P2/P4/P5 (P3 schema only, tool deferred).
  Files: bin/, .harness/schemas/, tests/fixtures/. Rationale: audit B10.
- Change: run-lifecycle core — P7 constructive (run start, scope-lock compile), P8, P9, P10,
  P11, P12, P13, P17. Files: bin/, .harness/schemas/. Rationale: the spine that makes behaviors
  non-optional (FABLE_WORKFLOW_TRANSFER conclusion).
- Change: enforcement hardening — P7 enforcement half (Bash write-radius classifier incl.
  `git apply`/`patch` deny), P6 bounds wiring, secret-guard superset keys + case-insensitivity,
  fail-closed-in-active, stop gate → receipt-coverage quick check. Files: .claude/hooks/*,
  settings.json, adapters/claude-code/. Rationale: audit B1, B3.
- Change: worker bridge hardening + review validator + apply-authorization chain (P15) +
  delegation records (P14). Files: .claude/hooks/worker-*, bin/. Rationale: audit B2.
- Change: orchestration registry + 6 contract-ized agents + skill bindings (P14/P16).
  Files: orchestration/, .claude/agents/, .claude/skills/, pointer-ized delegation docs.
  Rationale: audit §11.
- Change: install/adaptation upgrade (P19) + doctor + P20 matrices; generated manifest.
  Files: .claude/install/*, INSTALL_MANIFEST.md, adapters/. Rationale: audit B7, §4.4.
- Change: CI + release-readiness composition (P18 full) + E2E dry run + v1.0 docs/identity.
  Files: .github/workflows/, tests/fixtures/, docs/. Rationale: audit B3, B4, B6.

## Acceptance Criteria

- Criterion: every audit blocker B1–B10 has a closing change or an explicit deferred/waived
  entry in the release-readiness report.
  Verification Method: traceability table in `.harness/verification/dmc-v1-runtime-upgrade.md`.
- Criterion: the **canonical five bypass regressions** are denied, each with a permanent
  negative-control fixture: (1) Bash-mediated write outside scope, (2) agent edit of its own
  scope/lock file, (3) secret read via Glob `pattern` (and case-variant paths), (4) worker
  result carrying a JWT-class token, (5) worker rename-diff touching a forbidden file.
  (The audit's further findings — fail-open interpreter, run-id arming, `git apply` deny,
  empty-allowed deny — are covered by their milestones' own criteria below.)
  Verification Method: adversarial suites exit 0 with these as negative controls.
- Criterion: `dmc doctor` and the Stop-path quick gate run under 2s in a fixture repo; the Stop
  path blocks an uncovered completion on the ultrawork path; a run explicitly suspended via
  `dmc run suspend` does NOT block session stop (critic item 10).
  Verification Method: M9 E2E suite incl. latency measurement and the suspend scenario.
- Criterion: all pre-existing self-tests pass after copy-routing, against an **exact pinned
  baseline**: M3's first task records the per-tool assertion count into
  `.harness/evidence/dmc-v1-m3-baseline.md`; the aggregate must equal that count with 0 FAIL.
  Verification Method: `bin/dmc selftest --all` vs baseline.
- Criterion: host install round-trip (install → doctor PASS → uninstall → byte-clean) on 4
  fixture hosts. Verification Method: M8 suite.
- Criterion: Ring-0 contains no model-name strings; capability routing byte-identical under
  model-lookup swap. Verification Method: extended v0.6.1 self-scan over bin/**.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| bin/lib copies drift from `.harness/evidence/` originals during M3–M9 | high | copy-then-shim with a **mirror-check test** (byte-equality bin/lib vs originals) in CI; originals remain canonical until the M10 deprecation decision |
| Fail-closed-in-active bricks sessions on hosts missing python3 | medium | `dmc doctor` at install; adapter emits actionable error; passive mode unaffected |
| Bash write-radius classifier false positives | medium | ask-tier (not deny) for ambiguous forms in v1.0; allowlist file; measured on E2E fixture |
| Stop-path quick gate latency or over-blocking | medium | state-file-only quick tier; `dmc run suspend` escape hatch; benchmark in M9 |
| M4 is the largest milestone (8 primitives) | medium | all additive bin/ work, uniform validator pattern, two independently-verifiable tasks; no protected surface touched |
| Another harness (OMC) coexistence regression | low | passive-mode auto-detect preserved; doctor non-interference check |
| Worker hardening rejects previously-accepted legitimate results | low | fixtures re-run; empty-allowed DENY announced as breaking in release notes |

## Assumptions

| Assumption | Confidence | How to Verify |
|---|---|---|
| Claude Code hook API (events/JSON) stable for the adapter | high | doctor probes at install |
| Glob tool param is `pattern`, Grep dir param is `path` | high | verify against harness docs before M6; guard reads a **superset** of keys either way |
| Codex minimal binding feasible via pre-commit/CI | medium | M8 spike, timeboxed; downgrade to documented-manual if not |
| python3 available on target hosts | medium | doctor check; POSIX-sh deny floor as fallback |
| No concurrent DMC runs per repo | high | P7 refuses a second concurrent lock |

## Execution Tasks

REQUIRED-primitive coverage map (critic blocker 1):
P1,P2,P4,P5→M2 · P3(schema only),relocation→M3 · P7c,P8,P9,P10,P11,P12,P13,P17→M4 ·
P14(registry),P16→M5 · P6,P7e,P10(feeder),P18(quick)→M6 · P14(records),P15→M7 · P19,P20→M8 ·
P18(full),CI→M9 · docs/identity→M10. Deferred (consistent with architecture §4): P3 tool,
AST/LSP tier, approval auth, patch-content fidelity beyond names+hunk-count, async workers,
OpenCode full adapter.

Global not-edit for every milestone unless its own list authorizes it:
`.claude/workers/providers/**`, live-path code, `docs/MILESTONES.md` (M10 only, append-only),
`.harness/evidence/dmc-v0.*` in place (copy-only per M3).

### M1 — Audit + v1.0 architecture docs  [risk: low] — executed this session, DRAFT-stage
- [x] DMC-T001: audit → .harness/plans/dmc-v1-runtime-upgrade-audit.md
- [x] DMC-T002: docs/FABLE_WORKFLOW_TRANSFER.md
- [x] DMC-T003: docs/DMC_V1_RUNTIME_ARCHITECTURE.md
- [x] DMC-T004: docs/DMC_V1_ORCHESTRATION_MODEL.md
- Note (critic item 6): M1 ran before plan approval — docs-only, disclosed. **The human gate is
  asked to ratify M1 retroactively when approving this plan**; rejection = revise/delete docs.
- Acceptance: docs exist, evidence-cited, cross-consistent. Verification: structural checker
  (86 PASS / 0 FAIL this session) + DMC critic pass (verdict recorded; Rev 2 = its blockers
  closed). Rollback: revert the docs commit. Evidence: .harness/evidence/dmc-v1-m1-docs.md.

### M2 — Repository intelligence: P1, P2, P4, P5  [risk: low]
- [ ] DMC-T005: orientation/landmarks/depsurface/radius schemas + validators (negative controls).
  Files: .harness/schemas/{orientation,landmarks,depsurface,radius}.schema.md, bin/lib/.
- [ ] DMC-T006: `dmc orient` (P1) + `dmc landmarks` (P2); landmark seed = union of existing
  protected lists; DMC self-scan classifies own hooks/schemas/adapters as landmarks.
- [ ] DMC-T006b: `dmc depsurface` (P4, regex tier, unscanned-labeled) + `dmc radius` (P5;
  every radius entry must carry ≥1 check-id — schema-refused otherwise).
  Files: bin/, tests/fixtures/{node,python,empty}/.
- Acceptance: deterministic at fixed HEAD; seeded fake landmark + seeded dependent detected.
  Verification: `bin/dmc selftest orient landmarks depsurface radius`. Rollback: delete bin/
  additions (additive). Evidence: dmc-v1-m2-*.md. Not-edit: hooks, skills, install.

### M3 — Schema upgrades + tool copy-routing + instance validators  [risk: high — drift]
- [ ] DMC-T007: remaining new schemas (acceptance, scope-lock, fixloop, delegation,
  critic-verdict, worker-review) + **plan/run/verification instance validators**; canonical-home
  declaration (root `*_SCHEMA.md` canonical; `.harness/schemas/` mirrors carry a generated
  header) + mirror-check test. Negative control: the v0.5.4 stub plan must be refused; **this
  Rev 2 plan must be accepted** (incl. the extended milestone-block format).
- [ ] DMC-T008: **baseline pin first** — record exact per-tool self-test assertion counts →
  .harness/evidence/dmc-v1-m3-baseline.md. Then **copy** `.harness/evidence/dmc-v0.*.{sh,py}` →
  bin/lib/ + `dmc` routing + `dmc selftest --all` aggregator + bin↔original mirror-check.
  Originals stay in place and canonical; sibling-path composition (e.g.
  dmc-v0.6.5-decision-trace.py:23) keeps working in both trees.
- Acceptance: aggregate == pinned baseline, 0 FAIL, in both trees; mirror-check green.
  Verification: selftest + mirror-check. **Rollback: delete bin/ — originals were never moved
  or edited; rollback procedure itself is tested in the M3 suite** (critic blocker 4).
  Evidence: dmc-v1-m3-*.md. Not-edit: tool logic (any logic diff fails the mirror-check).

### M4 — Run-lifecycle core (the spine)  [risk: medium — largest milestone, additive only]
- [ ] DMC-T009: run/scope/approval core — `dmc run start|suspend|resume|status` writing
  `runs/<run>/run.json` + run-id; scope-lock compiler (P7 constructive) from an APPROVED plan
  (hash-bound, immutable, concurrent-lock refusal); typed approvals `approvals.jsonl` (P17,
  v0.6.5 namespace); evidence ledger core + `check_id` receipt extension (P10); checkpoints
  (P12).
- [ ] DMC-T009b: loop primitives — acceptance compiler (P8), verification planner promotion
  (P9: consumes acceptance+radius, reusing v0.5.5 logic via bin/lib), fix-loop counters + bound
  + STOP verdict (P13, counters bound to plan_hash), context recovery on observed git state
  (P11, next-safe-action).
- Acceptance: full state-file round-trip on a fixture run (start→lock→checks→receipts→fail→
  counter→checkpoint→suspend→resume→recover); scope.lock/acceptance immutable post-approval
  (hash-chain detects tamper); approval laundering refused (R12 re-test).
  Verification: `bin/dmc selftest run-core loop-core` + v0.6.x validators re-run over the new
  artifacts. Rollback: delete bin/ additions (additive; nothing consumes them yet).
  Evidence: dmc-v1-m4-*.md. Not-edit: hooks, skills, settings.json.

### M5 — Skills/subagents/orchestration registry  [risk: medium]
- [ ] DMC-T010: orchestration/roles.json (single taxonomy) + 6 contract-ized agent prompts
  (+release-auditor, P16 critic-verdict artifact contract); skills bound to `dmc` verbs;
  `/dmc-ultrawork` and `/dmc-start-work` call `dmc run start` (arms the gate — depends on M4,
  now satisfied); DMC_AGENT_HANDOFF/DYNAMIC_DELEGATION/DMC_DELEGATION_HARNESS role lists →
  pointers to the registry.
- Acceptance: link check — no skill/agent references a nonexistent artifact/verb; ultrawork
  fixture transcript arms run-id; critic verdict artifact schema-valid; start-work refused
  without a critic-verdict ref. Verification: link-check + M9 scenario pre-run. Rollback: git
  revert (text surfaces only). Evidence: dmc-v1-m5-*.md. Not-edit: hooks, settings.json.

### M6 — Hook/guard hardening (Ring-1 shims)  [risk: high — **protected surface, explicitly authorized for this milestone**]
- [ ] DMC-T011: hooks become shims over Ring-0 verdict CLIs; scope.lock + approvals immutability
  at Ring 1; Bash write-radius classifier (deny `git apply`/`patch`; deny/ask redirection,
  `sed -i`, `tee`, `mv`/`cp` into non-scope; fail-closed on unparseable in active); secret-guard
  superset keys (`file_path`,`glob`,`pattern`,`path`) + case-insensitive matching;
  fail-closed-in-active on missing interpreter; stop gate → quick coverage check (receipts ⊇
  required checks; keyword regex removed; suspended runs don't block); P6 bounds enforcement
  (v0.4.3 logic via bin/lib).
- Acceptance: canonical-five fixtures (1)(2)(3) denied + `git apply` denied + interpreter-absent
  ⇒ deny-in-active; all legitimate-operation fixtures still allowed (compatibility matrix);
  stop-block E2E on ultrawork path. Verification: adversarial hook suite + `bash -n` + matrix.
  Rollback: single revert commit restores v0.6.5 hooks+settings byte-identically (kept as
  fixtures for the test). Evidence: dmc-v1-m6-*.md.
- Not-edit: worker-result-check.py, worker-context-guard.sh (M7's surface).

### M7 — Worker/delegation hardening  [risk: medium — **protected surface (worker validators), explicitly authorized for this milestone**]
- [ ] DMC-T012: worker-result-check hardening (token classes imported from oauth-cli detectors;
  rename/copy/binary diff parsing; empty-allowed ⇒ DENY; task_id/provider cross-check;
  required-field presence); worker-context-guard fail-closed on parse error; NEW review
  validator (`dmc worker review-check`); hash-chained apply-authorization consumed by P7 at
  apply; post-apply fidelity (names+hunk-count); delegation records + subagent artifact
  validation (P14 records).
- Acceptance: canonical-five fixtures (4)(5) + empty-allowed REJECT; v0.3.3 contract suite green
  unchanged; apply without chain refused. Verification: extended contract suite. Rollback:
  revert commit; pre-M7 validator retained as fixture. Evidence: dmc-v1-m7-*.md.
  Not-edit: provider adapters/router (never), M6 hook surface.

### M8 — Host install/adaptation (P19 + P20)  [risk: medium]
- [ ] DMC-T013: installer ships Ring 0+1 (bin/, adapters/, schemas, orchestration/); generated
  manifest section (INSTALL_MANIFEST regenerated-from-installer, drift-tested); uninstaller
  strip fixes (gitignore skip bug, CLAUDE.md marker section removal); idempotent marker-based
  CLAUDE.md append; `${DRY:+}`/eval-quoting fixes; `dmc doctor` (interpreters, hook firing,
  foreign-harness detection, enforcement matrix print); P20 models.json + harness feature
  matrix; Codex minimal binding spike (pre-commit/CI; timeboxed).
- Acceptance: 4-fixture round-trip byte-clean (empty, node, existing-claude-settings,
  existing-OMC); double-install idempotent; doctor catches seeded defects. Verification: M8
  install suite. Rollback: installer self-contained; revert commit. Evidence: dmc-v1-m8-*.md.

### M9 — Release gate composition + CI + E2E dry run  [risk: low]
- [ ] DMC-T014: `dmc gate release --full` composing v0.2.6/v0.6.2-5 + diff⊆scope (git ground
  truth) + landmark-diff flag + delegation/import-chain checks; .github/workflows/dmc-ci.yml
  (selftest --all vs baseline, mirror-check, adversarial suites, install suite).
- [ ] DMC-T015: E2E dry run on tests/fixtures/host-node: orient→landmarks→plan→critic→approve→
  run start→execute (one denied attempt per canonical-five class)→receipts→fix-loop→suspend/
  resume→release gate→human-gate record; latency budget measured (<2s quick tier).
- Acceptance: seeded-gap fixtures each FAIL their sub-gate; loop completes; real repo
  byte-unchanged; CI green on branch. Verification: gate self-test + e2e script + CI run.
  Rollback: additive. Evidence: dmc-v1-m9-*.md.

### M10 — Final docs + release checklist  [risk: low]
- [ ] DMC-T016: DMC.md/CLAUDE.md/AGENTS.md/CONTEXT_MAP v1.0 identity refresh; NEW
  docs/DMC_V1_ENFORCEMENT_MATRIX.md (per-harness enforced-vs-advisory),
  docs/DMC_V1_HONEST_SCOPE.md (approval-provenance-not-authentication, redaction
  known-shapes-only, regex-dep-scan best-effort), docs/DMC_V1_RELEASE_CHECKLIST.md (consumed by
  the release gate); B1–B10 traceability table; decision on deprecating `.harness/evidence/`
  tool copies (originals) — human-gated; stray-file hygiene proposal (separate approval);
  MILESTONES closure entry (human-gated).
- Acceptance: no doc claims v0.1; traceability complete; `dmc gate release --full` PASS.
  Verification: doc link/claim check + full gate. Evidence: dmc-v1-m10-*.md.

## Verification Commands

| Command | Reason | Required |
|---|---|---|
| bash -n .claude/hooks/*.sh adapters/**/*.sh (+ sh under bin/) | syntax floor | yes |
| bin/dmc selftest --all (vs pinned M3 baseline) | legacy+new self-tests, exact-count 0 FAIL | yes |
| bin/dmc doctor (repo + fixtures) | wiring/interpreter/enforcement matrix | yes |
| M6 adversarial hook suite | canonical-five (1)(2)(3) + git-apply + fail-closed regressions | yes |
| M7 extended contract suite | canonical-five (4)(5) + empty-allowed + v0.3.3 green | yes |
| M8 install round-trip suite | host adaptation | yes |
| M9 e2e dry-run + latency | full-loop proof, repo byte-unchanged, <2s quick tier | yes |
| git status --porcelain before/after each suite | real-repo cleanliness | yes |

## Approval Status

Status: APPROVED (M2 ONLY; M1 retroactively ratified) — M3+ remain UNAPPROVED (DRAFT)
Approver: wjlee (wjlee@motionlabs.kr) — human release gate
Approved At: 2026-07-05

Approval record (verbatim scope of the human gate, 2026-07-05):
- **M1 retroactive ratification** covers: Phase 0–4 document deliverables, M1
  evidence/verification artifacts, the cloud-runtime branch-preservation commit/push to
  `claude/dmc-v1-runtime-upgrade-c5uch1`, and the M1 evidence consistency correction.
- **M2-only approval**: Repository Intelligence P1/P2/P4/P5 — orientation/landmarks/
  depsurface/radius schemas + validators, `dmc orient|landmarks|depsurface|radius`, additive
  bin/lib files for M2 only, tests/fixtures for M2 only, M2 evidence/verification files.
- **Explicitly NOT approved**: full v1.0 implementation, M3+, protected-surface edits, hook
  changes, worker-validator changes, installer changes, runtime hardening beyond M2, future
  push (cloud branch-preservation exception only), live provider calls, secret access,
  main/master changes.
- **M2 must not edit**: `.claude/hooks/*`, `.claude/settings.json`, `.claude/skills/*`,
  `.claude/agents/*`, `.claude/install/*`, `.claude/workers/providers/**`, worker validators,
  installer/uninstaller, provider adapters/router, live provider paths, main/master.

(Rev 2 after DMC critic REJECT — blockers 1–5 closed, items 6–11 addressed. Not self-approved.
Next gates: critic re-pass on Rev 2 → human approval, which also ratifies M1 retroactively →
M2 start.)

Ratification-scope note: M1 retroactive ratification covers document creation and the
cloud-runtime branch-preservation push only. It does not approve M2+ implementation,
protected-surface edits, runtime code changes, or future push.
