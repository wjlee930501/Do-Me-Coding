# DMC v0.1.2 Pilot — Phase 1 Compatibility Audit (read-only)

Run ID: dmc-v0.1.2-pilot
Date: 2026-06-19
Pilot repo: pokeprice (/Users/woojinlee/Documents/projects/pokeprice)
Method: read-only; secret files inventoried by filename only (no `.env*` contents read).

## Repo identity
- branch `main`, working tree clean, origin `https://github.com/wjlee930501/pokeprice.git`
- head `5ea18b0`; Node/TypeScript app

## Agent-harness inventory (presence only)
| Surface | Present | Note |
|---|---|---|
| `.claude/`, `.claude/settings.json`, `CLAUDE.md`, `AGENTS.md` | NO | DMC install additive; no local Claude hook/doc collision |
| `.omc/` | YES | project-memory.json, sessions/, state/ |
| `.omo/` | YES | plans/, ulw-loop/ |
| `.omx/` | YES | logs/, metrics.json, state/ |
| OpenCode (`opencode.json`/`.opencode`), `.cursor`, `.continue`, copilot-instructions | NO | — |
| Codex `~/.codex` (user-scope) | YES | user-scoped; not a repo file |

## Hook-event overlap
- No project-scope `.claude/settings.json` in pokeprice → DMC's project-scope hooks would be the only ones at repo level (no local collision).
- OMC/OMO operate at user scope (`~/.claude`); coexistence must still be verified live at install (Phase 2) and is exercisable via `dmc-off` (`.omc/`+`.omo/` present).

## Verification basis
- `package.json` scripts: `test` = `vitest run`, plus `build` → low-risk code task is test-verifiable.

## Docs-only task targets
- `README.md`, `DEPLOY.md`, `docs/` (CURRENT_STATE_AUDIT.md, ENCODER_SWAP.md, ICON_DESIGN_BRIEF.md, recognition-eval-ritual.md, superpowers/, design-assets/).

## Security / secrets posture (filename-only — contents NOT read)
- Secret files present: `.env.example`, `.env.local`, `.env.prod.local`.
- Tracked in git: only `.env.example` (conventional example file — owner should confirm it holds placeholders; NOT read during this pilot). `.env.local` and `.env.prod.local` are **untracked**.
- Ignore status: `.env.local`, `.env.prod.local` are gitignored ✓; `.omc/`, `.omo/`, `.omx/` gitignored ✓.
- **Pilot Security Guardrail honored:** no `.env*` contents were read/grepped/printed.

## Ignore-rule gap for DMC install (Phase 2)
- pokeprice `.gitignore` already covers `.env*` and `.omc`.
- **Missing:** `.harness` rules — `git check-ignore` confirms `.harness/mode`, `.harness/runs/current-*`, `.harness/evidence/manual-*.md` are NOT ignored. DMC install (Phase 2) must add these.

## Phase 1 verdict
- Compatibility: GREEN to pilot. Additive install (no Claude config collision); OMC/OMO present (coexistence test exercisable); test command available; docs targets available.
- Required at Phase 2 install: add `.harness/` transient-ignore rules to pokeprice `.gitignore`; install DMC in `passive`; operate on throwaway branch `dmc-pilot/v0.1.2`.

## STOP — phase gate
Phase 1 ends here. NO install, NO branch, NO pokeprice modification performed. Phase 2 is BLOCKED pending explicit maintainer approval.
