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

Triggers are **suffix-only, exact-token, and case-insensitive** (the token must end the prompt,
matched regardless of case), so prose that merely mentions `dmc-off` mid-sentence does not fire.
Switch explicitly with `/dmc-on`, `/dmc-off`, `/dmc-status`.

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

## Precedence when both fire

DMC never disables other layers structurally — Claude Code merges hook arrays, so DMC and another
layer's hooks both keep firing. But when the DMC suffix trigger fires, its emitted routing is
authoritative for that turn: the model must follow DMC discipline and not enter OMC/OMO/LazyCodex
modes for that turn. OMC is the observed real same-repo contender (see the audit callout above);
OMO and LazyCodex are comparator patterns, not confirmed same-repo observations. This is
instruction-level best-effort, not a runtime boundary — see `docs/DMC_V1_HONEST_SCOPE.md` for the
disclosed caveat.

## Codex coexistence

DMC also binds to the Codex CLI as a second host harness, so the same coexistence discipline
applies there over a different layering surface.

**Layer model (standing facts, from the official Codex hooks/config reference).** Hook layers
MERGE rather than override: a global `~/.codex/hooks.json` and a per-project `.codex/hooks.json`
both contribute their entries. A per-project `.codex/config.toml` (and its hooks) loads ONLY for
a project the CLI records as trusted. Beyond trust, a non-managed project hook additionally needs
one-time content-hash hook trust — a hook whose content later changes is skipped until
re-trusted (managed/org hooks are exempt). So on a trusted project the global and project hook
layers both dispatch, while an untrusted (or changed-hash) project layer is simply skipped.

> Observed (one machine, one session; codex-cli 0.132.0 + Codex App 26.623.61825, 2026-07-09):
> oh-my-codex (OMX) global hooks and the omo plugin were both live on the host — a real
> same-host contender set beside DMC. OMX injects advisory context and carries no dmc keyword,
> so it does not contend for the suffix trigger. During that session a third-party layer wrote
> `model` / `reasoning` and `multi_agent_v2` fields into the project's `.codex/config.toml`
> mid-session. Treat the project Codex config as a surface OTHER layers write to: keep it out of
> scope.locks unless a plan grants it, and diff it after any foreign-layer session.

> Observed (same session, pinned): at Codex App build 26.623.61825 the Settings → Hooks panel
> did not surface project-level hooks — no trust affordance, so the project hook layer stayed
> dark on that surface — whereas codex-cli 0.132.0's `/hooks` surface listed those hooks and
> trusted them. Trust state is shared through `~/.codex`, so a grant made once via the CLI is
> then seen by later CLI sessions. The coexistence asymmetry: a Codex App session may run with
> the project hook layer dark while the global layers stay live.

The precedence clause above holds on the Codex host too. When the dmc suffix trigger routes on
that host, the UPS shim injects the identical priority context, so the model follows DMC
discipline and does not enter OMX/OMO/LazyCodex modes for that turn. This is the same
instruction-level best-effort, not a runtime boundary — see `docs/DMC_V1_HONEST_SCOPE.md` for
the disclosed caveat.
