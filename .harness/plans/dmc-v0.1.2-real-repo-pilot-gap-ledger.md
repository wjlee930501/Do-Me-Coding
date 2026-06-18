# Do-Me-Coding v0.1.2 — Real-Repo Pilot & Competitive Gap Ledger

## Goal

Pilot the published DMC v0.1.1 harness in ONE real existing repository, exercise its
natural-activation / mode / coexistence behavior on three small real tasks, and produce a
measurable friction/gap ledger (DMC vs LazyCodex, OMO, OpenCode, Codex, and Claude Code's own
harness) — all BEFORE adding GLM 5.2 / multi-model worker orchestration. This is an
evaluation pilot, not a feature build.

## User Intent

investigation

## Pilot Repo (Selected)

- **Pilot repo:** pokeprice
- **Remote URL:** https://github.com/wjlee930501/pokeprice.git
- **Local path:** `/Users/woojinlee/Documents/projects/pokeprice` (found locally; origin matches)
- **Risk class:** low-risk / non-production
- **State at selection (read-only audit, 2026-06-19):** branch `main`, working tree clean; Node/TypeScript app (`package.json`, `pnpm-lock.yaml`, vite/vitest, drizzle); `README.md` + `docs/` present; `api/`, `client/`, `server/`, `services/`, `shared/` source dirs.
- **Pre-existing agent harnesses:** `.omc/` PRESENT, `.omo/` PRESENT, `.omx/` present — so the OMC/OMO coexistence test IS exercisable. `.claude/`, `CLAUDE.md`, `AGENTS.md` are ABSENT (DMC install is additive there → low collision risk on those surfaces; the hook-event merge audit still applies if OMC wired Claude Code hooks).
- **Secrets present:** `.env.example`, `.env.local`, `.env.prod.local` at root — security/secrets posture is directly testable. **Important — do not rely on DMC's guard here:** DMC v0.1.1 blocks Bash-based secret reads (e.g. `cat .env`), but it does NOT block the Claude Code `Read`/`Grep` tools against `.env*` (the guard matches only `Bash`/`Edit`/`Write`). Pilot safety therefore relies on the explicit operating rule in "Pilot Security Guardrail" below — no tool may open or print secret-bearing files. `.env.prod.local` is production secret material and is completely off-limits; audit by filename/structure only.
- **Why chosen:**
  - real codebase (not a toy scaffold)
  - low-risk / non-production toy-product repo
  - suitable for a docs-only task (`README.md` + `docs/`)
  - suitable for a low-risk code task (TS app with `vitest` for verification)
  - already runs OMC + OMO → ideal to test DMC vs LazyCodex / OMO friction and coexistence BEFORE MotionLabs production repos

## Preliminary Pilot Tasks

1. **Docs-only task via `dmc-plan`** — inspect `README.md` / `docs/` guide docs, propose ONE small documentation improvement (e.g. clarify a setup or scan step); NO product source modification. Confirm `dmc-plan` routes to planning-only and produces a plan with zero edits.
2. **Low-risk code task via `<task> dmc`** — after the audit, choose ONE small, reversible improvement (a comment, a constant, or a single test assertion); MUST avoid broad refactors; MUST include verification (lint/typecheck/`vitest` as available) and an evidence log; MUST be `git revert`/`restore`-able.
3. **OMC coexistence test via `dmc-off`** — `.omc/` and `.omo/` are present, so this IS exercised: append `dmc-off`, confirm DMC steps aside (catastrophic + secret-exposure deny only) while an OMC/OMO action runs, confirm no DMC scope/stop interference, then re-enable with `/dmc-on`. (Record "not exercised" only if, contrary to this audit, no OMC/OMO is active at run time.)

## Resolved Decisions (v0.1.2, pre-critic)

1. **Report location — this DMC repo only.** The two deliverables live ONLY here:
   `docs/COMPETITIVE_GAP_LEDGER.md` and `docs/DMC_REAL_REPO_PILOT_REPORT.md`. Do NOT write any pilot
   report docs into pokeprice during v0.1.2. Rationale: these are DMC evaluation artifacts, not
   pokeprice product docs — keep the host repo clean.
2. **Initial DMC install mode for pokeprice = `passive`.** Because pokeprice already has `.omc/`,
   `.omo/`, `.omx/`, DMC is installed starting in `passive` (set `.harness/mode` = passive at install).
   Passive preserves the safety deny behavior (catastrophic + secret-exposure) while standing down the
   scope/stop/evidence workflow gates so OMC/OMO are not disrupted. The `<task> dmc` pilot must verify
   that natural activation can move DMC into `active` execution when explicitly requested (router writes
   `active`), and `dmc-off` must be tested for OMC/OMO coexistence.
3. **Low-risk code task — selected after the pre-install audit.** The candidate must be: small,
   reversible, easy to verify with existing tests, and preferably test-only or a tiny non-critical code
   improvement. **Explicitly avoid:** broad refactors; DB/schema/drizzle migration files;
   any file that loads or references `process.env`; any file that imports or configures dotenv;
   config loaders; auth/secrets/env handling; deployment/production config; price-calculation core
   logic; large UI redesigns; dependency upgrades.
4. **Rollback / branch strategy — throwaway branch, never main.** Before installing DMC, create
   `dmc-pilot/v0.1.2` in pokeprice and run the entire pilot there. Do NOT run on pokeprice `main`. Do NOT
   push the pilot branch unless explicitly approved later. Rollback: `git restore` / `git clean` within
   the pilot branch, or delete the throwaway branch and return to `main`.

## Pilot Security Guardrail (MANDATORY — all phases)

Applies during every phase: pre-install audit, DMC install/adapt, docs-only task, low-risk code
task, OMC/OMO coexistence test, and report writing.

**Why an operating rule (not a hook):** DMC v0.1.1 blocks Bash-based secret reads (`cat .env`,
`printenv`), but it does NOT block the Claude Code `Read`/`Grep` tools against secret files (the
guard matches only `Bash`/`Edit`/`Write`). So tool-level enforcement is unavailable in v0.1.1 and
the pilot must enforce this by explicit rule.

**Rule — no tool may read, grep, print, edit, summarize, quote, copy, or otherwise expose the
contents of:**
- `.env`, `.env.local`, `.env.prod.local`, or any `.env*` file
- any file likely to contain secrets, tokens, credentials, private keys, API keys, or production configuration

**Allowed:**
- filename-only inventory via `ls`, `find`, or `git status`
- structural confirmation that such files exist
- checking `.gitignore` patterns without opening secret file contents

**Forbidden:**
- `Read` tool on `.env*`
- `Grep` tool against `.env*`
- Bash commands that print `.env*`
- editor operations on `.env*`
- `sed`/`awk`/`head`/`tail`/`cat`/`less`/`more` on `.env*`

**Enforcement:** any attempt to inspect `.env*` (or other secret-bearing) file contents is a FAIL
for the pilot. `.env.prod.local` (production) is entirely off-limits — may be referenced by
filename only.

## Next-Version Note (NOT part of v0.1.2)

- **Candidate:** DMC v0.1.3.
- **Feature:** expand secret protection beyond Bash — add `Read`/`Grep` path guardrails where
  Claude Code hook coverage allows it, or, if tool-level enforcement is unavailable, add explicit
  policy/instruction-level deny patterns. This pilot only *records* the gap (see the ledger's
  Security/secrets posture row); it does not implement the guard.

## Current Repo Findings

- Finding: v0.1.1 is published on `main` at `c68218e` with 9 skills (dmc-critic, dmc-init-deep, dmc-on, dmc-off, dmc-status, dmc-plan-hard, dmc-start-work, dmc-ultrawork, dmc-verify-hard), 5 hooks (dmc-router, pre-tool-guard, scope-guard, stop-verify-gate, evidence-log), 5 agents, schemas, and `docs/OMC_COEXISTENCE.md`.
  Source: `git log -1`; `ls .claude/skills .claude/hooks .claude/agents docs`.
- Finding: There is NO installer script. Installing DMC into a host repo = copy `.claude/{skills/dmc-*,agents,hooks}` + `.harness/` skeleton + `DMC.md`/`*SCHEMA.md`, **merge** `.claude/settings.json` hook arrays, and **merge (never blind-overwrite)** `CLAUDE.md`/`AGENTS.md`.
  Source: `ls *.sh install*` → none.
- Finding: DMC wires four hook events: `PreToolUse`, `PostToolUse`, `UserPromptSubmit`, `Stop`. A host repo (esp. one with OMC) likely has its own entries on these events; Claude Code merges arrays, so the audit must confirm coexistence (DMC router exits 0 on non-trigger prompts).
  Source: `settings.json` hooks keys.
- Finding: `.omc/`, `.harness/runs/current-*`, `.harness/evidence/manual-*.md`, and `.harness/mode` are gitignored in DMC; the host repo's `.gitignore` must gain the same rules.
  Source: `.gitignore` (v0.1.1).
- Finding: Neither `docs/COMPETITIVE_GAP_LEDGER.md` nor `docs/DMC_REAL_REPO_PILOT_REPORT.md` exists yet — both are new deliverables of this pilot.
  Source: `ls docs/` → absent.
- Finding (decision needed): No pilot repo is chosen yet. Repo selection is an input the maintainer must supply at approval (see Assumptions / Open Decision).

## Relevant Files

| Path | Reason | Allowed to Edit (future approved run) |
|---|---|---|
| `docs/COMPETITIVE_GAP_LEDGER.md` | NEW — competitive gap ledger (13 categories) — deliverable in THIS repo | yes (new) |
| `docs/DMC_REAL_REPO_PILOT_REPORT.md` | NEW — pilot run report (audit + 3 tasks + verdict) — deliverable in THIS repo | yes (new) |
| `.harness/plans/dmc-v0.1.2-real-repo-pilot-gap-ledger.md` | this plan | n/a |
| `<pilot-repo>/**` | The external host repo where DMC is installed and the 3 tasks run | out-of-scope for THIS repo; governed by the host repo's own rules |
| DMC v0.1.1 installable surface (`.claude/`, `.harness/`, `DMC.md`, schemas) | read-only source copied into the pilot repo; NOT modified here | no |

Note: the two report docs land in THIS DMC repo's `docs/` (they are DMC project knowledge). All hands-on pilot edits happen in the separate `<pilot-repo>` and are not changes to this repo's product source.

## Out of Scope

- Implementing anything now (plan only).
- Modifying DMC product source (hooks/skills/settings) — the pilot copies v0.1.1 as-is into the host repo.
- GLM 5.2 / any multi-model integration; any worker/agent execution engine (explicitly deferred — this pilot only *assesses readiness*).
- Blindly overwriting the pilot repo's existing `CLAUDE.md`/`AGENTS.md`/`settings.json` — merge only.
- Disabling OMC/OMO or assuming a universal off switch.
- Committing anything in the pilot repo without that repo's own review.

## Proposed Changes

- Change: Produce `docs/COMPETITIVE_GAP_LEDGER.md` — a table over the 13 categories below, each row scoring DMC vs LazyCodex / OMO / OpenCode / Codex / Claude-native, with a concrete observation from the pilot, a severity (low/med/high), and a "next-version candidate" note. No code conclusions invented — every row cites a pilot observation or an explicit "not exercised."
  Files: `docs/COMPETITIVE_GAP_LEDGER.md`
  Rationale: Captures where DMC differs/falls short before investing in automation.
- Change: Produce `docs/DMC_REAL_REPO_PILOT_REPORT.md` — pilot identity (repo, commit, date), pre-install compatibility audit results, install/adapt steps actually taken, the three task runs (commands, observations, evidence pointers), coexistence test result, and a PASS/FAIL/PARTIAL verdict.
  Files: `docs/DMC_REAL_REPO_PILOT_REPORT.md`
  Rationale: Reproducible record of the pilot.
- Change: No other changes to this repo.

### Pilot procedure (executed in `<pilot-repo>`, recorded in the report)

1. **Choose one real repo** by the selection criteria (Assumptions). Record name, language/stack, size, and whether OMC/OMO/OpenCode/Codex configs are present.
2. **Pre-install compatibility audit** (read-only): inventory existing agent configs — `.claude/` (settings.json hooks, CLAUDE.md, skills), `.omc/`, OMO artifacts, OpenCode (`opencode.json`/`.opencode/`), Codex (`AGENTS.md`, `~/.codex`), and any `.cursor`/`.continue`. Capture conflicts on the four hook events.
3. **Identify existing OMC/OMO/OpenCode/Codex/Claude config files** and note overlaps (esp. UserPromptSubmit & PreToolUse).
4. **Verify ignore rules**: confirm (or add) `.omc/`, `.harness/runs/current-*`, `.harness/evidence/manual-*.md`, `.harness/mode` in the host `.gitignore`; confirm none are tracked.
5. **Install/adapt DMC**: copy the v0.1.1 surface; MERGE settings.json hook arrays (append DMC entries, keep host's); MERGE CLAUDE.md/AGENTS.md (append a DMC section, never overwrite). Start in `passive` or `off` if the host already runs OMC.
6. **Docs-only task via `dmc-plan`**: pick a trivial docs change (e.g. a README typo/clarification); run `<task> dmc-plan` → confirm it routes to planning-only and produces a plan with no edits.
7. **Low-risk code task via `<task> dmc`**: pick a tiny, reversible code change (e.g. a comment, a constant rename, a test assertion); run `<task> dmc` → confirm activation, scope lock, verification, evidence.
8. **OMC coexistence test via `dmc-off`**: append `dmc-off`, confirm DMC steps aside (catastrophic+secret deny only), run a trivial OMC action (or simulate), confirm no DMC interference; re-enable with `/dmc-on`.
9. **Produce `docs/COMPETITIVE_GAP_LEDGER.md`** from observations.
10. **Produce `docs/DMC_REAL_REPO_PILOT_REPORT.md`** with the verdict.

### Gap ledger categories (13 — each scored DMC vs competitors, with pilot observation + severity)

Activation UX · State management · Plan quality · Execution control · Scope control ·
Stop/verification behavior · Evidence quality · Rollback · OMC coexistence ·
Multi-model readiness · Worker delegation readiness · Security/secrets posture · Developer friction.

The **Security/secrets posture** row MUST document the v0.1.1 guard gap: DMC blocks Bash-based secret reads only, and does NOT guard Read/Grep access to `.env*` — naming the v0.1.3 candidate (Read/Grep guardrails or policy-level deny) from the Next-Version Note.

## Acceptance Criteria

- Criterion: Exactly one pilot repo is chosen and characterized (name, stack, size, pre-existing agent configs).
  Verification Method: report's "Pilot Identity" section is populated; repo path recorded.
- Criterion: Pre-install audit enumerates existing `.claude`/`.omc`/OMO/OpenCode/Codex config and hook-event overlaps.
  Verification Method: report's "Compatibility Audit" table lists each surface as present/absent with conflict notes.
- Criterion: Ignore rules verified — `.omc/`, `.harness/runs/current-*`, `.harness/evidence/manual-*.md`, `.harness/mode` ignored and untracked in the pilot repo.
  Verification Method: `git -C <pilot-repo> check-ignore` for each → matches; `git -C <pilot-repo> ls-files` shows none tracked.
- Criterion: DMC installed without overwriting host docs — host `CLAUDE.md`/`AGENTS.md`/`settings.json` preserved (DMC appended/merged).
  Verification Method: `git -C <pilot-repo> diff` shows additive merges only; pre/post hashes of host-original sections unchanged.
- Criterion: Docs-only `dmc-plan` task routes to planning-only and makes zero file edits.
  Verification Method: a plan artifact produced; `git -C <pilot-repo> status` shows no source edits from that task.
- Criterion: Low-risk `<task> dmc` task activates, scopes, verifies, and logs evidence; change is reversible.
  Verification Method: `.harness/mode` flips active; scope file written; verification report present; `git revert`/`restore` restores cleanly.
- Criterion: `dmc-off` coexistence test shows DMC non-interfering (catastrophic+secret deny only) while an OMC/other action runs.
  Verification Method: with mode off, a benign host action proceeds without DMC scope/stop blocking; `cat .env`/`rm -rf /` still denied.
- Criterion: `docs/COMPETITIVE_GAP_LEDGER.md` exists with all 13 categories populated (observation + severity + competitor comparison), no fabricated claims (unexercised items marked).
  Verification Method: heading/row grep → 13 categories; each row has a pilot observation or explicit "not exercised."
- Criterion: `docs/DMC_REAL_REPO_PILOT_REPORT.md` exists with audit + 3 task runs + coexistence + PASS/FAIL/PARTIAL verdict.
  Verification Method: section grep; verdict line present.
- Criterion: No changes to this repo beyond the two docs; no GLM/worker code added.
  Verification Method: `git status --porcelain` lists only the two `docs/*.md` (+ this plan); grep for "GLM"/worker-exec → none in code.
- Criterion (security): the pilot transcript/evidence contains NO `.env*` file contents.
  Verification Method: review pilot evidence/transcript — no env-file contents present; `.env.prod.local` referenced by filename only.
- Criterion (security): the low-risk code task touched no file that references `process.env`, dotenv, or production config.
  Verification Method: the chosen file is confirmed (by filename/structure) not to import/load env or secrets; `git -C <pilot-repo> diff` over the task shows only the non-secret target file.
- Criterion (security): any attempt to inspect `.env*` (or other secret-bearing) contents during the pilot is treated as FAIL.
  Verification Method: Pilot Security Guardrail honored in all phases; a single secret-content access flips the verdict to FAIL.
- Criterion: the gap ledger includes a Security/secrets posture row documenting the Read/Grep guard gap (Bash-only deny in v0.1.1) and the v0.1.3 candidate.
  Verification Method: `grep -i 'Security/secrets'` in `docs/COMPETITIVE_GAP_LEDGER.md` → row present, names the Read/Grep gap.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Installing DMC breaks the host repo's existing agent setup (hook collisions) | high | Pre-install audit first; merge (never overwrite) settings.json/CLAUDE.md; start in `passive` (Resolved Decision #2); run entirely on throwaway branch `dmc-pilot/v0.1.2`, never on `main` (Resolved Decision #4) for instant rollback. |
| DMC hooks block or disrupt the host repo's real workflow during the pilot | medium | Run the code task on a throwaway branch; `dmc-off` available; document any block as a friction-ledger entry rather than forcing through. |
| Pilot observations are anecdotal / not measurable | medium | Each ledger row requires a concrete observation (command + outcome) or explicit "not exercised"; severity rubric defined up front. |
| Competitor comparisons (LazyCodex/OMO/OpenCode/Codex) made from assumption, not evidence | medium | Mark comparison cells as "observed" vs "from docs" vs "unknown"; do not fabricate competitor behavior. |
| Secret exposure during the pilot — esp. `.env.prod.local` (production) — via Read/Grep, which DMC v0.1.1 does NOT guard | high | DMC's secret deny is **Bash-only** and does not protect Read/Grep; rely on the explicit "Pilot Security Guardrail" operating rule (no tool may read/grep/print any `.env*` or secret-bearing file); inventory by filename only; any attempt to inspect `.env*` contents is treated as FAIL. |
| Pilot repo choice creates scope creep / large diff | medium | Constrain to ONE repo and three SMALL tasks; out-of-scope guard. |
| Reports drift toward proposing GLM/worker features (out of scope) | low | Ledger may NOTE readiness gaps but must not design integrations; "Multi-model/Worker readiness" rows are assessment-only. |

## Assumptions

| Assumption | Confidence | How to Verify |
|---|---|---|
| Pilot repo = **pokeprice** at `/Users/woojinlee/Documents/projects/pokeprice` (origin matches) — RESOLVED | RESOLVED | Found locally; branch `main`, clean tree; OMC + OMO present; see "Pilot Repo (Selected)". |
| The two reports belong in THIS DMC repo's `docs/` (DMC project knowledge), not the pilot repo | medium | Confirm at approval; alternative is to also drop a copy in the pilot repo. |
| Claude Code merges hook arrays so DMC + host hooks coexist | high | Observed OMC + DMC coexistence this session; verify in the pilot audit. |
| The pilot is partly human-in-the-loop (choosing repo, judging friction) | high | Inherent to a pilot; report records human observations alongside command evidence. |
| GLM 5.2 / worker orchestration explicitly deferred | high | Out of Scope; ledger only assesses readiness. |

## Execution Tasks

- [ ] DMC-T001: Select + characterize the pilot repo (record identity).
- [ ] DMC-T002: Pre-install compatibility audit (read-only inventory of `.claude`/`.omc`/OMO/OpenCode/Codex + hook-event overlaps). **Secrets handling:** inventory `.env*` files by filename ONLY; do not read or grep their contents; record only presence/absence + risk class; treat `.env.prod.local` as production secret material and completely off-limits (per Pilot Security Guardrail).
- [ ] DMC-T003: Verify/add ignore rules in the pilot repo; confirm nothing tracked.
- [ ] DMC-T004: In pokeprice, create throwaway branch `dmc-pilot/v0.1.2` from `main` FIRST (never run on main). Then install/adapt DMC v0.1.1 (copy + MERGE settings/CLAUDE/AGENTS), and set `.harness/mode` = **passive** at install (OMC/OMO present). Do not push the branch.
- [ ] DMC-T005: Docs-only task via `dmc-plan` (planning-only, zero edits).
- [ ] DMC-T006: Low-risk code task via `<task> dmc` (activate → scope → verify → evidence → revert-check).
- [ ] DMC-T007: OMC coexistence test via `dmc-off` (non-interference + safety floor) then `/dmc-on`.
- [ ] DMC-T008: Write `docs/COMPETITIVE_GAP_LEDGER.md` (13 categories).
- [ ] DMC-T009: Write `docs/DMC_REAL_REPO_PILOT_REPORT.md` (audit + tasks + verdict).
- [ ] DMC-T010: Verification + evidence for THIS repo's deliverables; final status.

## Verification Commands

| Command | Reason | Required |
|---|---|---|
| `test -f docs/COMPETITIVE_GAP_LEDGER.md && grep -c '^' docs/COMPETITIVE_GAP_LEDGER.md` | ledger exists | yes |
| `for c in "Activation UX" "State management" "Plan quality" "Execution control" "Scope control" "Stop/verification" "Evidence quality" "Rollback" "OMC coexistence" "Multi-model" "Worker delegation" "Security/secrets" "Developer friction"; do grep -q "$c" docs/COMPETITIVE_GAP_LEDGER.md || echo "MISSING: $c"; done` | all 13 categories present | yes |
| `test -f docs/DMC_REAL_REPO_PILOT_REPORT.md && grep -Eq 'PASS\|FAIL\|PARTIAL' docs/DMC_REAL_REPO_PILOT_REPORT.md` | report + verdict present | yes |
| `grep -niE 'glm\|worker[ -]exec' .claude docs -r` → none in code | no premature GLM/worker code | yes |
| `git -C <pilot-repo> check-ignore .omc/x .harness/mode .harness/runs/current-x` | pilot ignore rules active | yes |
| `git -C <pilot-repo> status --short` after `dmc-plan` task | docs-only/planning made no source edits | yes |
| `git -C <pilot-repo> diff` over host CLAUDE.md/AGENTS.md/settings.json | merges additive, host content preserved | yes |
| `git status --porcelain` (this repo) | only the two docs (+ plan) changed here | yes |

## PASS / FAIL / PARTIAL

- **PASS**: One pilot repo selected + characterized; compatibility audit completed with conflicts documented; ignore rules verified; DMC installed via merge without overwriting host docs; all three tasks run as designed (dmc-plan = planning-only/no edits; `<task> dmc` = activate→scope→verify→evidence→reversible; `dmc-off` = non-interfering with safety floor intact); both docs produced with all 13 ledger categories populated by concrete observations and a clear verdict; no GLM/worker code added; this repo changed only by the two docs.
- **PARTIAL**: Pilot ran and both docs produced, but one task was blocked or skipped, ≥1 ledger category is "not exercised," or a coexistence/merge conflict was found and documented-but-unresolved. Verdict states exactly what is incomplete and why.
- **FAIL**: DMC could not be installed/activated in the pilot repo, OR installing it overwrote/broke host config, OR a hook disrupted the host workflow without a usable `dmc-off`, OR no ledger/report produced, OR **any `.env*` (or other secret-bearing) file contents were inspected/printed during the pilot** (Pilot Security Guardrail breach — automatic FAIL). Verdict captures the failure and the rollback taken.

## Approval Status

Status: APPROVED
Approver: 대표님
Approved At: 2026-06-19
