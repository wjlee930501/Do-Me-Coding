# DMC Gate Checks (v0.2.6)

A reusable **read-only / report-only** runner that standardizes DMC's pre-stage, pre-commit, and pre-push reviews. It
**informs** the human Release Gate (and the Codex auditor) with a PASS/FAIL summary. It is **advisory**: it stages,
commits, pushes, mutates, and approves **nothing**, and grants **no** gate. (Per the Operator Handbook, enforcement
automation that *blocks* actions is a separate, separately-approved future milestone — this runner only reports.)

Runner: `.harness/evidence/dmc-v0.2.6-gate-check-runner.sh`

## Usage

```
dmc-v0.2.6-gate-check-runner.sh --allowlist <file> [--repo <dir>] [--gate stage|commit|push]
dmc-v0.2.6-gate-check-runner.sh --self-test
```

- `--allowlist <file>` (required for a report): newline-separated approved repo-relative paths — the only files
  expected in the staged set. Lines starting with `#` and blanks are ignored.
- `--repo <dir>` (default `.`): the git repo to inspect (read-only).
- `--gate stage|commit|push` (default `commit`): the push gate additionally requires HEAD to be **not behind** upstream.
  An unrecognized `--gate` value is rejected with a usage error (exit 2) — a typo must not silently downgrade strictness.
- `--self-test`: runs the built-in scenarios in **throwaway temp repos** (the real/target index is never touched).

**Exit code:** `0` = all checks PASS, `1` = at least one FAIL, `2` = usage error. The exit code is an **advisory report
signal** for the human / Codex auditor — it is NOT an action and must never be wired to stage/commit/push/block.

## Checks

| ID | Check | FAIL when |
|---|---|---|
| **G1** | Staged ⊆ allowlist | a staged file is not in the allowlist |
| **G2** | Allowlist fully staged | an approved file is not staged |
| **G3** | No excluded-evidence file staged | an excluded auto-logged evidence file is staged |
| **G4** | No protected-path change | a protected path is staged or worktree-modified |
| **G5** | `git diff --cached --check` clean | trailing whitespace / conflict marker in the staged diff |
| **G6** | Ahead/behind reported (push gate: not behind) | `--gate push` and HEAD is behind upstream (or upstream missing) |

`git diff --cached`, `git diff --cached --check`, `git status --porcelain -- <path>`, `git rev-list --left-right`, and
`git rev-parse` are the only git commands the report path runs — all read-only.

## Default lists (overridable)

- **Excluded auto-logged evidence** (`DMC_GATE_EXCLUDED`, newline-separated):
  `.harness/evidence/dmc-v0.2.{2,3,4,5}-*.md`.
- **Protected paths** (`DMC_GATE_PROTECTED`, newline-separated): `.claude/workers/providers/glm-api`,
  `.../oauth-cli`, `.../provider-router.py`, `.../ROUTING.md`, `.../PROVIDER_CONTRACT.md`, `.claude/hooks`,
  `WORKER_{TASK,RESULT,REVIEW}_SCHEMA.md`, `dmc-glm-smoke`.
- **Upstream** for G6 (`DMC_GATE_UPSTREAM`, default `origin/main`).

## What this runner is NOT

- It does **not** stage, commit, push, reset, `git apply`, delete, or otherwise mutate any real/target repo. The only
  writes anywhere are inside `--self-test`'s temp repos.
- It does **not** grant or block a gate, read `.env*`/credentials, make a live/network call, or handle leaked text.
- It is an **input** to the human Release Gate and the Codex audit — not a substitute for either.
