# Plan: DMC v1.0 Runtime Upgrade — model-independent AI runtime

Plan ID: dmc-v1-runtime-upgrade · Date: 2026-07-05 · Format: PLAN_SCHEMA.md

## Goal

Bring DMC from v0.6.5 to a production-grade **v1.0 model-independent AI runtime**: a portable
Ring-0 core (`bin/dmc` + state + schemas) whose gates fire without being asked, harness adapters
(Claude Code full; Codex minimal; OpenCode stub), a repository-intelligence layer, hardened
enforcement closing the audited bypasses, an orchestration registry binding agents/workers to
capability classes, and a host install that actually ships the control plane.

## User Intent

Classify: **feature** (runtime layer) + **refactor** (relocation/wiring of shipped tools) +
**docs** (v1.0 architecture + release docs). Primary: feature.

## Current Repo Findings

- Finding: only 6 Claude Code hooks enforce anything at runtime; all v0.2.6–v0.6.5 control-plane
  tools are advisory and unwired; zero hooks invoke `.harness/evidence/` validators.
  Source: `.harness/plans/dmc-v1-runtime-upgrade-audit.md` §1, §4.3 (settings.json;
  grep evidence).
- Finding: enforcement bypasses in the wired layer — Bash write bypass of scope, scope
  self-escalation via `.harness/runs` auto-allow, fail-open on missing python3/jq, secret-guard
  reads wrong tool-input keys, `/dmc-ultrawork` never arms the stop gate, `git apply` unblocked.
  Source: audit §3 (scope-guard.sh:58-78, secret-guard.sh:102-103, dmc-ultrawork/SKILL.md:29,
  pre-tool-guard.sh).
- Finding: `worker-result-check.py` accepts JWT-bearing results and rename-diff scope bypasses;
  empty `allowed_files` disables scope; review stage is 100% prose. Source: audit §3
  (empirical), worker-result-check.py:21-34,59-61.
- Finding: host installs are frozen at the v0.1.3 surface; INSTALL_MANIFEST's SSoT claim is
  false; uninstaller gitignore strip is a no-op; CLAUDE.md append non-idempotent.
  Source: audit §10 (INSTALL_MANIFEST.md:3,44-47; dmc-install.sh:106-112;
  dmc-uninstall.sh:38-42).
- Finding: no single entry point, no CI, no plan/run/verification validators, no repository
  intelligence, agents orphaned, three drifted role taxonomies, version identity "v0.1" vs
  v0.6.5 reality, tracked stray backups/zip. Source: audit §4, §5, §11, §12, §13.

## Relevant Files

| Path | Reason | Allowed to Edit |
|---|---|---|
| bin/** (new) | Ring-0 CLI façade + relocated tool routing | yes (new) |
| adapters/** (new) | Ring-1 harness adapters (claude-code, codex, opencode) | yes (new) |
| orchestration/** (new) | roles.json, models.json | yes (new) |
| .claude/hooks/*.sh, .claude/hooks/worker-result-check.py | harden + convert to Ring-1 shims | yes (M5, gated) |
| .claude/settings.json | rewire hooks to shims; add write-radius matcher coverage | yes (M5) |
| .claude/skills/*/SKILL.md | bind skills to `dmc` verbs + role registry | yes (M4) |
| .claude/agents/*.md (+ release-auditor.md new) | contract-ized prompts | yes (M4) |
| .claude/install/dmc-install.sh, dmc-uninstall.sh | P19 fixes + Ring-0 shipping | yes (M7) |
| INSTALL_MANIFEST.md | regenerate from installer (generated section) | yes (M7) |
| .harness/schemas/*.schema.md (new: orientation, landmarks, depsurface, radius, acceptance, scope-lock, fixloop, delegation, critic-verdict, worker-review) | new primitive schemas | yes (M3) |
| PLAN_SCHEMA.md / RUN_SCHEMA.md / VERIFICATION_SCHEMA.md | add validator refs; declare canonical home | yes (M3) |
| DMC.md, CLAUDE.md, AGENTS.md, docs/CONTEXT_MAP.md, docs/MILESTONES.md | v1.0 identity + index refresh; closure | yes (M10) |
| .harness/evidence/dmc-v0.*.{sh,py} | RELOCATION ONLY (bin/lib) with compat shims; no logic edits except named hardening | yes (M3/M5, per-file listed) |
| tests/fixtures/** (new) | fixture repos for P1/P2/P4, install round-trip, E2E dry run | yes (M9) |
| .github/workflows/dmc-ci.yml (new) | run self-tests + new suites | yes (M8) |

## Out of Scope

- Any live provider call, any network call, any credential handling change beyond redaction
  patterns. GLM/OAuth adapters' live paths untouched.
- Cryptographic approval authentication (stays honest-scope-labeled; v1.1+).
- LSP/AST dependency analysis; async worker jobs/retry/cost routing; OpenCode full adapter;
  web/mobile/MCP surfaces.
- Rewriting shipped v0.2.6–v0.6.5 validator logic (relocation + routing + named hardening only).
- Deleting `.before-dmc`/zip strays (proposed as a separate hygiene commit needing explicit human
  approval — history/back-compat decision).
- Any push, any main/master work, any closure entry before human gates.

## Proposed Changes

- Change: Ring-0 `bin/dmc` façade + state root (§0.1–0.4 of architecture doc).
  Files: bin/**, .harness layout. Rationale: single entry point; portability (audit B4, B5).
- Change: repository-intelligence primitives P1/P2/P4/P5 (+P3 schema only).
  Files: bin/, .harness/schemas/. Rationale: audit B10.
- Change: enforcement hardening (P7 scope-lock, Bash write-radius classifier, secret-guard key
  fix + case-insensitivity, fail-closed-in-active on missing interpreter, run-id arming, stop
  gate → P18 quick tier, `git apply`/`patch` deny).
  Files: .claude/hooks/*, settings.json, bin/. Rationale: audit B1, B3.
- Change: worker bridge hardening + review validator + apply authorization chain (P15).
  Files: worker-result-check.py, new bin/worker-review-check, contract suite fixtures.
  Rationale: audit B2.
- Change: orchestration registry + 6 contract-ized agents + skill bindings (P14/P16/P17).
  Files: orchestration/, .claude/agents/, .claude/skills/. Rationale: audit §11.
- Change: install/adaptation upgrade (P19) + doctor; generated manifest.
  Files: .claude/install/*, INSTALL_MANIFEST.md. Rationale: audit B7, §4.4.
- Change: CI + E2E dry-run fixture + release-readiness composition (P18) + v1.0 docs/identity.
  Files: .github/workflows/, tests/fixtures/, docs/. Rationale: audit B3, B4, B6.

## Acceptance Criteria

- Criterion: every audit blocker B1–B10 has a closing change or an explicit deferred/waived
  entry in the release-readiness report.
  Verification Method: traceability table in `.harness/verification/dmc-v1-runtime-upgrade.md`
  mapping B1–B10 → milestone → evidence.
- Criterion: the five empirically-confirmed bypasses (Bash write, scope self-edit, Glob pattern
  secret read, JWT worker result, rename-diff worker result) are denied, each with a permanent
  regression test.
  Verification Method: new adversarial suites exit 0 with those cases as negative controls.
- Criterion: `dmc doctor` + `dmc gate release --quick` run under 2s in a fixture repo; the Stop
  path blocks an uncovered completion on the ultrawork path.
  Verification Method: E2E dry-run suite (M9).
- Criterion: all pre-existing self-tests still pass after relocation (500+ assertions).
  Verification Method: `bin/dmc selftest --all` aggregate run, 0 FAIL.
- Criterion: host install round-trip (install → doctor PASS → uninstall → byte-clean) on 4
  fixture hosts.
  Verification Method: M7 suite.
- Criterion: Ring-0 contains no model-name strings; capability routing byte-identical under
  model-lookup swap.
  Verification Method: extended v0.6.1 self-scan over bin/**.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Relocating .harness/evidence tools breaks sibling-path composition (dmc-v0.6.5-decision-trace.py:23) | high | compat shims at old paths through v1.0; composition tests before/after; per-file move list |
| Fail-closed-in-active bricks sessions on hosts missing python3 | medium | `dmc doctor` at install; adapter emits actionable error; passive mode unaffected |
| Bash write-radius classifier false positives block legitimate commands | medium | ask-tier (not deny) for ambiguous forms in v1.0; allowlist file; measured on E2E fixture |
| Hook latency budget exceeded at Stop (P18 quick) | medium | state-file-only quick tier; benchmark in M9; fallback to receipt-count check |
| Scope: 10 milestones is large; drift risk mid-stream | medium | milestone-per-gate lifecycle; each independently shippable; M1–M3 land value even if later milestones slip |
| Another harness (OMC) coexistence regression | low | passive-mode auto-detect preserved; doctor non-interference check |
| Worker hardening rejects previously-accepted legitimate results | low | fixtures re-run; empty-allowed DENY is announced as breaking in release notes |

## Assumptions

| Assumption | Confidence | How to Verify |
|---|---|---|
| Claude Code hook API (events/JSON) stable for the adapter | high | doctor probes at install |
| Glob tool param is `pattern`, Grep dir param is `path` (secret-guard fix target) | high | verify against harness docs before M5; keep old keys too (superset read) |
| Codex-side minimal binding is feasible via pre-commit/CI (no hook API assumed) | medium | M7 spike task, timeboxed; downgrade to documented-manual if not |
| python3 available on target hosts | medium | doctor check; POSIX-sh fallbacks only for the deny floor |
| No concurrent DMC runs per repo (single run-id) | high | P7 refuses second concurrent lock |

## Execution Tasks

(Each milestone = own approved lifecycle; verify + evidence before the next. Files-not-to-edit
for every milestone unless its list says otherwise: `.claude/workers/providers/**` (adapters/
router), live-path code, `docs/MILESTONES.md` (append-only, M10 only), root schemas outside M3.)

### M1 — Audit + v1.0 architecture docs  [risk: low] — DONE in this session, pending review
- [x] DMC-T001: audit doc. Files: .harness/plans/dmc-v1-runtime-upgrade-audit.md.
- [x] DMC-T002: workflow transfer. Files: docs/FABLE_WORKFLOW_TRANSFER.md.
- [x] DMC-T003: runtime architecture. Files: docs/DMC_V1_RUNTIME_ARCHITECTURE.md.
- [x] DMC-T004: orchestration model. Files: docs/DMC_V1_ORCHESTRATION_MODEL.md.
- Acceptance: docs exist, evidence-cited, cross-referenced. Verification: structural check
  (sections present; cited paths exist). Rollback: revert docs commit. Evidence:
  .harness/evidence/dmc-v1-m1-docs.md. Not-edit: everything else.

### M2 — Repository Intelligence specs + P1/P2 implementation  [risk: low]
- [ ] DMC-T005: orientation.schema.md + landmarks.schema.md + validators. Files:
  .harness/schemas/, bin/lib/.
- [ ] DMC-T006: `dmc orient` (P1), `dmc landmarks` (P2) with fixture-repo self-tests; DMC
  self-scan seeds landmark migration from existing protected lists.
- Acceptance: deterministic at fixed HEAD; negative controls; self-scan classifies
  hooks/schemas/adapters as landmarks. Verification: `bin/dmc selftest orient landmarks`.
  Rollback: delete bin/ additions (additive). Evidence: .harness/evidence/dmc-v1-m2-*.md.

### M3 — Schema upgrades + tool relocation under bin/  [risk: high — compat]
- [ ] DMC-T007: new primitive schemas (depsurface, radius, acceptance, scope-lock, fixloop,
  delegation, critic-verdict, worker-review) + plan/run/verification instance validators;
  canonical-home decision (root files become pointers) + mirror check.
- [ ] DMC-T008: relocate `.harness/evidence/dmc-v0.*.{sh,py}` → bin/lib/ with compat shims;
  re-run all embedded self-tests; `dmc selftest --all` aggregator.
- Acceptance: 500+ legacy assertions 0 FAIL post-move; plan validator refuses a section-missing
  plan (negative control: the v0.5.4 stub plan). Verification: selftest aggregate. Rollback:
  compat shims make revert = delete bin/, restore nothing. Evidence: dmc-v1-m3-*.md.
  Not-edit: tool *logic* (move-only; any logic diff is a REJECT).

### M4 — Skill/subagent updates + orchestration registry  [risk: medium]
- [ ] DMC-T009: orchestration/roles.json + models.json; 6 agent prompts contract-ized
  (+release-auditor); skills bound to `dmc` verbs; `/dmc-ultrawork` creates run-id via
  `dmc run start` (arms the gate); handoff/delegation docs → pointers.
- Acceptance: no skill/agent references a nonexistent artifact path (link check); ultrawork
  E2E arms stop gate. Verification: link-check tool + M9 scenario. Rollback: git revert (text
  surfaces). Evidence: dmc-v1-m4-*.md.

### M5 — Hook/guard hardening (Ring-1 shims)  [risk: high — protected surface]
- [ ] DMC-T010: hooks become shims calling Ring-0 verdict CLIs; scope.lock immutability;
  Bash write-radius classifier (deny `git apply|patch`, redirection/sed -i/tee into non-scope);
  secret-guard superset keys (`pattern`,`path`) + case-insensitive matching; fail-closed-in-
  active on interpreter absence; stop gate → `dmc gate release --quick` (keyword regex removed).
- Acceptance: the 5 audited bypasses denied (regression fixtures); all legacy hook behaviors
  preserved for allowed operations (fixture matrix). Verification: new adversarial hook suite +
  `bash -n` + E2E. Rollback: settings.json + hooks are small; revert commit restores v0.6.5
  behavior. Evidence: dmc-v1-m5-*.md. Explicitly authorized protected-surface edit.

### M6 — Worker/subagent orchestration hardening  [risk: medium]
- [ ] DMC-T011: worker-result-check hardening (token classes, rename/binary diffs,
  empty-allowed⇒DENY, task_id/provider cross-check, presence checks); review validator;
  apply-authorization chain + post-apply fidelity (names+hunk-count); worker-context-guard
  fail-closed on parse error; delegation records + subagent artifact validation.
- Acceptance: JWT/rename/empty-allowed fixtures REJECT; v0.3.3 contract suite still green;
  apply without chain refused by P18. Verification: extended contract suite. Rollback: revert;
  old validator kept as bin/lib compat until v1.0 tag. Evidence: dmc-v1-m6-*.md.

### M7 — Host install/adaptation (P19)  [risk: medium]
- [ ] DMC-T012: installer ships Ring 0+1; generated manifest section; uninstaller strip fixes;
  idempotent CLAUDE.md marker; `dmc doctor`; Codex minimal binding spike (pre-commit/CI).
- Acceptance: 4-fixture round-trip byte-clean; doctor detects missing python3, foreign harness,
  unfired hooks. Verification: install suite. Rollback: installer changes are self-contained.
  Evidence: dmc-v1-m7-*.md.

### M8 — CI + release-readiness gate (P18)  [risk: low]
- [ ] DMC-T013: `dmc gate release` (quick/full) composing v0.2.6/v0.6.2-5 + scope/landmark
  checks; .github/workflows/dmc-ci.yml running selftest --all + suites.
- Acceptance: seeded-gap fixtures each FAIL their sub-gate; CI green on branch. Verification:
  gate self-test + CI run. Rollback: additive. Evidence: dmc-v1-m8-*.md.

### M9 — End-to-end dry run on fixture repo  [risk: low]
- [ ] DMC-T014: full loop on tests/fixtures/host-node: orient→landmarks→plan→critic→approve→
  scope.lock→execute (incl. a denied bypass attempt each class)→receipts→fix-loop→resume→
  release gate→human gate; latency budget measured.
- Acceptance: loop completes; every deny fixture denies; real repo byte-unchanged.
  Verification: e2e script, self-contained. Evidence: dmc-v1-m9-*.md.

### M10 — Final docs + release checklist  [risk: low]
- [ ] DMC-T015: DMC.md/CLAUDE.md/AGENTS.md/CONTEXT_MAP v1.0 identity refresh; enforcement
  matrix doc (per-harness enforced-vs-advisory); honest-scope register; release checklist;
  MILESTONES closure entry (human-gated); stray-file hygiene proposal (separate approval).
- Acceptance: no doc claims v0.1; B1–B10 traceability table complete; checklist consumed by
  release gate. Verification: doc link/claim check + `dmc gate release --full`. Evidence:
  dmc-v1-m10-*.md.

## Verification Commands

| Command | Reason | Required |
|---|---|---|
| bash -n .claude/hooks/*.sh adapters/**/*.sh bin/** (sh files) | syntax floor | yes |
| bin/dmc selftest --all | aggregate legacy + new self-tests, 0 FAIL | yes |
| bin/dmc doctor (repo + fixtures) | wiring/interpreter/enforcement matrix | yes |
| M5 adversarial hook suite | bypass regressions | yes |
| extended v0.3.3 contract suite | worker invariants | yes |
| M7 install round-trip suite | host adaptation | yes |
| M9 e2e dry-run | full-loop proof, repo byte-unchanged | yes |
| git status --porcelain (before/after each suite) | real-repo cleanliness | yes |

## Approval Status

Status: DRAFT
Approver:
Approved At:

(Not self-approved. Next gates: /dmc-critic on this plan → human approval → M2 start. M1's
document deliverables exist in-session and await the same review.)
