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

## Secret Protection (v0.1.3) — non-negotiable

NEVER read, grep, print, edit, summarize, quote, copy, or otherwise expose the contents of
secret-bearing files — in ANY mode, via ANY tool (Read, Grep, Glob, Bash, editor):

- `.env`, `.env.local`, `.env.prod.local`, `.env.production`, any `.env*` (EXCEPT `.env.example` / `.env.sample` / `.env.template`)
- private keys / certs (`*.pem`, `*.key`, `id_rsa`, `id_ed25519`, `*.p12`, `*.pfx`, `*.keystore`)
- credential / token files (`.npmrc`, `.netrc`, `.pgpass`, `credentials.json`, `*service-account*.json`, `*secret*` config)
- `**/.ssh/*`, `**/.aws/credentials`

`secret-guard.sh` enforces this for Read/Grep/Glob and `pre-tool-guard.sh` for Bash, but this
instruction-level rule is the defense-in-depth layer and applies even where tool-level enforcement
cannot reach (e.g. a broad `Grep`). Inventory secret files by **filename only**. Treat any
production secret file as completely off-limits.
