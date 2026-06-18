# DMC v0.1.2 Pilot — Phase 2A Install/Sanity Evidence

Run ID: dmc-v0.1.2-pilot
Date: 2026-06-19
Pilot repo: pokeprice (/Users/woojinlee/Documents/projects/pokeprice)
Phase: 2A — install-prep only (no docs/code/coexistence tasks).

## Branch
- Created throwaway branch `dmc-pilot/v0.1.2` from clean `main`. Local only — NOT pushed (no upstream).

## Installed (via `cp`/`printf`, not editor tools — DMC scope-guard governs Write/Edit in this session)
- `.claude/hooks/` — 5 hooks (dmc-router, pre-tool-guard, scope-guard, stop-verify-gate, evidence-log)
- `.claude/skills/` — 9 dmc-* skills
- `.claude/agents/` — 5 agents
- `.claude/settings.json` — DMC's (pokeprice had no project `.claude/settings.json`)
- `.harness/` skeleton — decisions/evidence/memory/plans/runs/verification (+.gitkeep), schemas/*.schema.md
- `.harness/mode` = **passive**
- root: `DMC.md`, `PLAN_SCHEMA.md`, `RUN_SCHEMA.md`, `VERIFICATION_SCHEMA.md`, `CLAUDE.md`
- `.gitignore` — appended DMC transient-ignore block (`.harness/mode`, `.harness/runs/current-*`, `.harness/evidence/manual-*.md`)

## Deliberate adaptations (not blind-copy)
- **AGENTS.md NOT copied** — DMC's AGENTS.md describes the DMC scaffold repo; copying it would misdescribe pokeprice. Left absent (can be generated later via `/dmc-init-deep`). Honors "do not overwrite/misdescribe host docs."
- **CLAUDE.md** copied (generic DMC operating + routing guidance, repo-agnostic); pokeprice had none.

## Untouched (verified present, not modified)
- `.omc/`, `.omo/`, `.omx/` — all still present; not read or modified.

## Sanity checks (all PASS)
| Check | Result |
|---|---|
| `git -C pokeprice status --short` | ` M .gitignore` + untracked `.claude/`, `.harness/`, `CLAUDE.md`, `DMC.md`, 3 schemas |
| `git -C pokeprice diff --name-only` | `.gitignore` only (sole tracked change) |
| `git check-ignore .harness/mode` | ignored ✓ |
| `git check-ignore .harness/runs/current-test` | ignored ✓ |
| `git check-ignore .harness/evidence/manual-test.md` | ignored ✓ |
| `.claude/settings.json` valid JSON | ✓ (events: PreToolUse, PostToolUse, UserPromptSubmit, Stop) |
| `bash -n` all 5 hooks | all OK |
| `.harness/mode` | `passive` |

## Hook / OMC / OMO collision
- No project-level hook collision: pokeprice had no prior project `.claude/settings.json`, so the installed one is DMC-only.
- OMC/OMO operate at user scope (`~/.claude`); project-scope DMC hooks coexist. Live coexistence (dual UserPromptSubmit / PreToolUse with OMC/OMO active) is to be exercised in Phase 2B via `dmc-off` — NOT done in 2A.

## Pilot Security Guardrail
- HONORED: no Read/Grep/cat/print of `.env`, `.env.local`, `.env.prod.local`, or any `.env*` contents. Install copied DMC files INTO pokeprice only; secret handling stayed filename-only.

## Phase 2B safety assessment
- SAFE to proceed (pending explicit approval): install is clean and additive, mode is passive (workflow gates stand down, safety deny retained), transient state is gitignored, hooks parse, no collision, guardrail intact. All work remains on throwaway branch `dmc-pilot/v0.1.2` (not pushed).

## Stop
Phase 2A ends here. Phase 2B (docs-only `dmc-plan`, low-risk code `<task> dmc`, `dmc-off` coexistence, final ledger/report) is BLOCKED pending explicit maintainer approval.
