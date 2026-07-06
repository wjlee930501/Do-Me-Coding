# Evidence — dmc-v0.5-codex-adapter-direction (run dmc-run-0e29d09bf3b5)

Date: 2026-07-06 · Branch: `claude/dmc-v1-runtime-upgrade-c5uch1` (HEAD `1c672a0` throughout;
nothing staged/committed/pushed — those are separate human gates).

## Lifecycle record (state machine)

1. **DRAFT** — plan authored by the orchestrator (Fable) from: (i) an Opus 4.8 read-only
   architecture/gap survey of the repo, (ii) a Sonnet 5 web research pass over official Codex
   CLI docs (developers.openai.com/codex, raw-HTML verified 2026-07-06), (iii) direct reads of
   the master plan, handoff, MILESTONES, schemas.
2. **CRITIC** — non-authoring DMC critic agent (fresh context):
   - R1 verdict REJECT/REVISE — 3 blockers (B1 post-Bash exemption too broad; B2 missing
     master-plan authorization bookkeeping; B3 M7-after-M8 manifest drift) + 4 optional.
     Persisted: `.harness/evidence/dmc-v0.5-direction-critic-verdict-r1.json`
     (`dmc verdict validate` VALID).
   - Rev 2 closed B1–B3 + O1–O4.
   - R2 focused re-pass verdict **PASS** (0 blockers), bound to Rev 2 bytes
     (plan_hash `277ee35de6dac36af66518ede477212ad1cd81181270c9d3606978f5e732b3cd` ==
     `shasum -a 256` of the plan at approval time). Persisted:
     `.harness/evidence/dmc-v0.5-direction-critic-verdict-r2.json` (VALID).
3. **APPROVED** — human release gate: wjlee, via AskUserQuestion in-session, option
   "APPROVED — 실행 착수", 2026-07-06. Approval record + explicit not-approved list written
   into the plan's `## Approval Status`.
4. **START-WORK** — `bin/dmc run start --plan .harness/plans/dmc-v0.5-codex-adapter-direction.md
   --work-id dmc-v0.5-direction` → `run_id: dmc-run-0e29d09bf3b5`, `status: RUNNING`, exit 0.
   Scope written to `.harness/runs/current-scope.txt` from the plan's Relevant Files.
   **Disclosed scope addition (harness bookkeeping):** `.harness/verification/
   dmc-run-0e29d09bf3b5.md` appended after run start because `VERIFICATION_SCHEMA.md` names
   `<run-id>.md` as the canonical verification artifact and the stop gate requires that exact
   path; recorded here and in the report's Scope Review. No product/code path was added.
5. **EXECUTE** — task record below.
6. **VERIFY** — interim PARTIAL report while executors ran (honest non-completion), then
   mechanical re-verification of all worker claims by the orchestrator + an independent
   non-authoring verifier pass; final report at `.harness/verification/dmc-run-0e29d09bf3b5.md`
   (mirrored at `.harness/verification/dmc-v0.5-codex-adapter-direction.md`).

## Execution record (who did what)

| Task | Owner | Result |
|---|---|---|
| DMC-T101 master plan Rev 3 amendment (items a–f) | executor subagent (Opus 4.8) | done — 1 file, +71/−11; approval block byte-identical (cmp exit 0); `dmc validate plan` VALID |
| DMC-T102 docs/CODEX_ADAPTER.md | executor subagent (Opus 4.8) | done — 169 lines, 5 components + spike open-questions; linkcheck exit 0; zero model-name literals (density preferred over the ~250-line guidance; accepted) |
| DMC-T103 M6 milestone plan (DRAFT) | orchestrator (planning role) | done — `dmc validate plan` VALID |
| DMC-T104 M6.5 milestone plan (DRAFT) | orchestrator (planning role) | done — `dmc validate plan` VALID |
| DMC-T105 evidence + verification | orchestrator | this file + final report |

## Verification command log (orchestrator re-runs, not worker claims)

| Command | Result |
|---|---|
| `bin/dmc validate plan` × 4 (direction / master Rev 3 / m6 / m6.5) | VALID, exit 0 each |
| approval-block byte-compare (`git show HEAD:… | sed -n '/^## Approval Status/,$p'` vs working, `cmp`) | BYTE-IDENTICAL |
| Rev 3 marker greps (M6.5 section · Deferred register · P21→M6.5 ×2 · DMC-T013 replacement · narrow-exemption DENIED · old spike line count 0) | all as expected |
| `bin/dmc verdict validate` (r1, r2) | VALID, exit 0 each |
| plan_hash binding (shasum vs r2 verdict) | match `277ee35d…` |
| `bin/dmc linkcheck` | exit 0 |
| `bin/dmc selftest` (default 9 sections) | 75 PASS / 0 FAIL, exit 0 |
| `git status --porcelain` / `git diff --name-only` | only allowlisted paths modified/created; `.harness/runs/**` + auto-logged `.harness/evidence/dmc-run-*.md` are DMC-internal local-only per policy |
| CODEX_ADAPTER content checks (5 `##` components, re-verify banner, "guardrail" honesty fact, Unknown rule, trust-bypass warning, `grep -cE 'gpt-5\.[0-9]'` = 0) | all present / clean |
| independent verifier pass (non-authoring) | **ACCEPT** — 0 blocking / 8 advisory findings (naming reconciliation actioned; hash-chain, policy classifications, task-ID + wording nits recorded in the final report's Unresolved Risks) |
| `bin/dmc validate verification` (run-id report + plan-named mirror) | VALID × 2, exit 0 |

## Safety confirmations

No live/network provider call by DMC tooling (web research ran in a read-only research
subagent against public official docs only); no secret/credential/`.env` access; no protected
surface touched (`.claude/**`, `bin/**`, `orchestration/**`, `.harness/schemas/**` byte-
unchanged vs HEAD); no stage/commit/push; no `docs/MILESTONES.md` entry (closure is a later
human gate); worker outputs were review-verified and never applied via `git apply`/`patch`
(text authored in-scope by scope-guarded executors).

## Commit-intent note (for the staging gate)

Deliberate deliverables of this run (candidates for staging, human-gated):
plan (direction) · master plan Rev 3 · docs/CODEX_ADAPTER.md · m6 + m6.5 plans · this evidence
file · critic verdicts r1/r2 · final verification report(s). Local-only by policy: run dir
`.harness/runs/dmc-run-0e29d09bf3b5/`, `current-scope.txt`, auto-logged
`.harness/evidence/dmc-run-0e29d09bf3b5.md`, per-milestone run archives.
