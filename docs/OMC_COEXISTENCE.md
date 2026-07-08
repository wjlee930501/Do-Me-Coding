# Do-Me-Coding ↔ OMC Coexistence

Do-Me-Coding (DMC) and oh-my-claudecode (OMC) both integrate through the same Claude Code
surfaces (skills, `UserPromptSubmit` hooks, `PreToolUse` advisories, project state). They can
run in the same repo, but they can contend. DMC **never disables OMC** — it steps aside via its
own `.harness/mode` switch.

## Modes

| Mode | pre-tool-guard | scope / stop / evidence | When to use |
|------|----------------|--------------------------|-------------|
| `active` | full deny + `ask` prompts | enforced | DMC is driving the work |
| `passive` | full destructive + secret deny (no `ask`) | stand down | OMC is driving; keep the safety net |
| `off` | catastrophic + secret-exposure deny only | stand down | OMC experiments; minimal interference |

`.harness/mode` is gitignored and local; **absent means `active`** (so DMC protections are preserved on clean clones).

## Natural activation

- `<task> dmc` → routes to `/dmc-ultrawork` and sets mode `active`.
- `<task> dmc-plan` → routes to `/dmc-plan-hard` (planning only; mode unchanged).
- `<anything> dmc-off` → sets mode `off`.

Triggers are **suffix-only and exact** (the token must end the prompt), so prose that merely
mentions `dmc-off` mid-sentence does not fire. Switch explicitly with `/dmc-on`, `/dmc-off`,
`/dmc-status`.

## Running OMC in the same repo

1. **Prefer isolation.** Run OMC experiments in a separate branch or a dedicated git worktree so
   the two harnesses do not contend in one working tree:
   ```bash
   git worktree add ../omc-experiments -b omc-experiments
   cd ../omc-experiments   # run OMC here; DMC's .harness/mode does not follow the worktree
   ```
2. **If you must share one tree**, set DMC aside first: `/dmc-off` (or append `dmc-off` to a
   request). Catastrophic + secret-exposure protection still applies.
3. **Finish DMC runs first.** Before OMC work, if `.harness/runs/current-*` exists a DMC run is in
   progress — `/dmc-status` will warn. Finish or cancel it so the scope lock and stop gate do not
   fight OMC's edits.

## No universal OMC off switch

Do not assume OMC can be globally disabled. OMC exposes only env-level kill switches
(`DISABLE_OMC`, `OMC_SKIP_HOOKS`) and the optional `/oh-my-claudecode:cancel` command (available
only when the OMC plugin is installed) to exit OMC modes like ultrawork. DMC must coexist
regardless: it relies solely on `.harness/mode`, never on turning OMC off.

## Hook coexistence audit

Claude Code merges hook arrays, so DMC and OMC hooks both fire on shared events
(`UserPromptSubmit`, `PreToolUse`). Audit checklist:

- Both hooks fire and neither swallows the other's output (the DMC router exits 0 — no output —
  on any prompt without an exact `dmc`/`dmc-plan`/`dmc-off` suffix).
- `python3 -m json.tool .claude/settings.json` is valid and lists both DMC and any OMC hook
  entries.
- `.omc/` remains gitignored; DMC `.harness/runs/current-*`, `.harness/evidence/manual-*.md`, and
  `.harness/mode` remain gitignored.

> Observed: during DMC planning sessions, OMC ultrawork has re-armed via its own
> `UserPromptSubmit` magic-keyword injection and its Stop hook fired repeatedly. Treat dual
> `UserPromptSubmit` coexistence as real, and use `/oh-my-claudecode:cancel` (if present) to exit
> OMC modes cleanly when finished.
