# Claude Code Instructions — Do-Me-Coding Enabled

This repository uses Do-Me-Coding v0.1.

Before substantial edits:
1. Read `DMC.md`.
2. Use `/dmc-plan-hard` for planning.
3. Use `/dmc-critic` before implementation.
4. Use `/dmc-start-work` only for approved plans.
5. Use `/dmc-verify-hard` before claiming completion.

Non-negotiable rules:
- No verification, no done.
- No accepted file scope, no edit.
- No explicit acceptance criteria, no execution.
- No evidence log, no final completion claim.

For complex work, prefer:

```text
/dmc-ultrawork <task>
```

For normal work, still follow:
plan → scope → execute → verify → evidence.

## Mode & Natural Activation Routing (v0.1.1)

`.harness/mode` controls enforcement: `active` (full), `passive` (deny tier only, gates stand down), `off` (catastrophic + secret-exposure deny only). Absent ⇒ `active`.

Natural-activation triggers (suffix-only, exact; precedence dmc-off > dmc-plan > dmc):

- a request ending with `dmc` → run `/dmc-ultrawork` (mode set `active`).
- a request ending with `dmc-plan` → run `/dmc-plan-hard` (planning only).
- a request ending with `dmc-off` → set mode `off`.

Explicit switches: `/dmc-on [active|passive]`, `/dmc-off`, `/dmc-status`. For OMC in the same repo, see `docs/OMC_COEXISTENCE.md` (prefer a separate branch/worktree; do not assume OMC has a universal off switch).
