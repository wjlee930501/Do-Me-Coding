# Do-Me-Coding — Host-Repo Adaptation Policy (v1.0; introduced in v0.1.3)

How DMC adapts to an existing host repo WITHOUT overwriting or misdescribing it.

## Never blind-copy `AGENTS.md`
DMC's own `AGENTS.md` describes the DMC scaffold repo (its package manager, structure, risks). Copying
it verbatim into a host repo injects **false project memory**. Therefore:
- The installer **does NOT copy `AGENTS.md`** (see `INSTALL_MANIFEST.md` → "DELIBERATELY NOT COPIED").
- A host-specific `AGENTS.md` should be **generated from host facts** via `/dmc-init-deep`, only when
  the team wants project memory — never auto-imposed.

## Preserve existing host docs and agent configs (merge, never overwrite)
Before writing, the installer performs **collision detection** on:
- `CLAUDE.md` — if present, append a DMC section; never replace the host's content.
- `AGENTS.md` — if present, leave it; do not touch (offer `/dmc-init-deep` to extend).
- `.claude/settings.json` — if present, **merge** DMC hook arrays into the existing events; never replace.
- `.gitignore` — **append** the DMC block; never rewrite.
- Any other host file the manifest would write — if it exists and differs, warn and skip.

On any collision, the installer prints what it found and what it did (merge/skip), and never
destroys host content. `--dry-run` shows the full plan without writing.

## Generate host-specific docs only when appropriate
- `CLAUDE.md`: DMC's is generic operating guidance (modes, routing, rules) and is safe to add/append.
- `AGENTS.md`: host-specific only, via `/dmc-init-deep`; otherwise omitted.

## Mode on install
Default `passive` when another agent harness is detected (`.omc/`, `.omo/`, `.omx/`, `.claude/settings.json`
with non-DMC hooks, OpenCode/Codex/Cursor configs); else `active`. The installer prints the chosen
mode and rationale; the user may override (`--mode active|passive|off`). (Resolved Decision #5.)
