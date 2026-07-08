# Do-Me-Coding v1.0

Do-Me-Coding is a Claude Code-first execution harness that forces AI coding agents to plan, critique, implement, verify, recover, and report with evidence.

It is not a new coding agent. It is a disciplined operating layer for Claude Code, Codex, and later OpenCode.

## Core Philosophy

```text
Do not just suggest.
Do the work.
Prove the work.
Do not fake completion.
```

## Non-Negotiable Rules

1. No verification, no done.
2. No accepted file scope, no edit.
3. No explicit acceptance criteria, no execution.
4. No evidence log, no final completion claim.
5. No independent agent runtime — DMC runs inside host harnesses (Claude Code enforced; Codex advisory); `bin/dmc` is a Ring-0 verdict/validation CLI, not an agent runtime.
6. No OMO runtime clone.
7. No copied leaked prompt text.

## Default Loop

```text
Goal
→ Intent Gate
→ Repo Scan
→ Plan
→ Critic Review
→ File Scope Lock
→ Execute Task
→ Verify
→ Fix Loop
→ Evidence Log
→ Report
→ Continue or Stop
```

## Commands

### `/dmc-ultrawork <task>`

Use for substantial engineering tasks. It forces workflow-style execution with planning, critique, file-scope locking, verification, and evidence.

### `/dmc-plan-hard <task>`

Planning only. No product code edits. May create or update plan files only under `.harness/plans/`.

### `/dmc-critic <plan-path>`

Ruthlessly reviews a plan and returns `APPROVE`, `REJECT`, or `NEEDS CLARIFICATION`.

### `/dmc-start-work <approved-plan-path>`

Executes only an approved plan. Creates run state and approved file scope under `.harness/runs/`.

### `/dmc-verify-hard [run-id or plan-path]`

Runs strict verification and writes a report under `.harness/verification/`.

### `/dmc-init-deep [focus]`

Builds or refreshes `AGENTS.md` project memory from repo facts only.

## Modes & Natural Activation (v1.0; introduced in v0.1.1)

Do-Me-Coding has a mode switch in `.harness/mode` (gitignored; absent means `active`):

- **active** — full enforcement (destructive + secret deny, `ask` prompts, scope lock, stop/verify gate, evidence logging).
- **passive** — full destructive + secret-exposure deny remain; `ask` prompts and scope/stop/evidence gates stand down (less intrusive while OMC drives).
- **off** — catastrophic-destructive + secret-exposure deny only; everything else passes through. Not fully inert.

### Natural activation (append a trigger to a request)

```text
<task> dmc        # route to /dmc-ultrawork and set mode active
<task> dmc-plan   # route to /dmc-plan-hard (planning only; mode unchanged)
dmc-off           # set mode off (for OMC coexistence)
```

Triggers are suffix-only and exact (the token must end the prompt). Switch explicitly with `/dmc-on [active|passive]`, `/dmc-off`, `/dmc-status`.

See `docs/OMC_COEXISTENCE.md` for running OMC in the same repo (separate branch/worktree, run-in-progress warning, no assumed OMC off switch).

## Secret Protection (v1.0; introduced in v0.1.3)

DMC denies access to secret-bearing files at two layers:

1. **Bash** — `pre-tool-guard.sh` denies `cat .env`, `printenv`, etc. (all modes; security floor).
2. **Read / Grep / Glob** — `secret-guard.sh` (PreToolUse matcher `Read|Grep|Glob`) denies tool access to secret-bearing **paths**, deciding by path only (it never opens files). Enforced in **all modes**.

Secret-bearing patterns: `.env`, `.env.*` (e.g. `.env.local`, `.env.prod.local`, `.env.production`),
`*.pem`, `*.key`, `id_rsa`/`id_ed25519`, `*.p12`/`*.pfx`/`*.keystore`/`*.jks`, `.npmrc`/`.netrc`/`.pgpass`,
`credentials.json`, `*service-account*.json`, `*secret*.{json,yaml,yml,env}`, `**/.ssh/*`, `**/.aws/credentials`.
**Allowed (not secrets):** `.env.example`, `.env.sample`, `.env.template`, and non-secret source files with env-like names.

Defense-in-depth: a broad `Grep` with no path can't be path-blocked, but Grep respects `.gitignore`
(gitignored secrets are skipped) and the CLAUDE.md instruction-level rule remains required. `Glob`
does NOT respect `.gitignore`, so `secret-guard` also blocks secret-targeting glob patterns.

## Install & Host Adaptation (v1.0; introduced in v0.1.3)

DMC installs into host repos via a manifest-driven installer, not ad-hoc copy:

- `INSTALL_MANIFEST.md` — exact host-install surface (and what is deliberately NOT copied).
- `.claude/install/dmc-install.sh` — `--dry-run`, default-mode detection (passive when another harness
  is present, else active; overridable `--mode`), collision detection (merge/append/skip, never overwrite),
  bundles referenced docs (`docs/OMC_COEXISTENCE.md` → no dangling references), appends the host `.gitignore`.
- `.claude/install/dmc-uninstall.sh` — reverses the install.
- `docs/HOST_REPO_ARTIFACT_POLICY.md` — host `.harness` plans/evidence/verification default to local-only (commit opt-in); the DMC repo itself commits durable artifacts.
- `docs/HOST_REPO_ADAPTATION_POLICY.md` — never blind-copy `AGENTS.md`; merge/preserve host docs; generate host-specific docs only via `/dmc-init-deep`.

## Worker Bridge (v1.0; introduced in v0.2, mock-only)

Claude/Codex orchestrates; bounded workers (e.g. GLM 5.2) produce **structured proposals only** —
they never mutate the repo. The worker bridge is **mock-only** (introduced in v0.2): no live API, no credentials, no auto-apply.

- Schemas: `WORKER_TASK_SCHEMA.md`, `WORKER_RESULT_SCHEMA.md`, `WORKER_REVIEW_SCHEMA.md`.
- Skills: `/dmc-worker-plan`, `-dispatch`, `-import`, `-review`, `-status`, `-cancel`.
- `worker-context-guard.sh` validates a task bundle before dispatch (fail-closed on any secret/forbidden path); `worker-result-check.py` validates a result at import/review.
- **No-mutation rule:** a worker diff is a **review artifact only**. DMC does NOT apply worker patches with `git apply`/`patch`. If accepted, the orchestrator translates the change into scope-guarded `Edit`/`Write` under a `/dmc-start-work` scope → verify → evidence.
- Storage `.harness/workers/{tasks,results,reviews,sessions}/` — local-only by default in host repos (commit opt-in). Workers receive clipped, secret-scrubbed context only; no `.env*`/credentials/OAuth tokens.
- Provider Access Layer: `mock` | `api_key` | `oauth_cli` | `manual_import` — all four ship in v1.0 (`mock`/`manual_import` introduced in v0.2, the `api_key` `glm-api` adapter in v0.2.1, `oauth_cli` in v0.2.2).
- **`glm-api` adapter** (introduced in v0.2.1; `.claude/workers/providers/glm-api/`, `provider_target.type=api_key`): mock-first — default `--mock`/no-network; `--live` is multi-gated (`--live` + `--allow-network` + `GLM_API_KEY` env + not-CI). Key read from env ONLY, non-printing, never serialized into logs/results/evidence/`.harness/`; Authorization header redacted; raw provider responses local-only. Output is still validated by `worker-result-check.py`. See `.claude/workers/providers/glm-api/README.md` + `CONFIG.md`.

## Evidence Policy

Evidence files live under:

```text
.harness/evidence/
.harness/verification/
```

Final report format:

```text
Status: PASS | FAIL | PARTIAL

Changed Files:
- path: reason

Verification:
- command: result

Evidence:
- evidence file path
- verification file path

Unresolved Risks:
- risk or none

Next Action:
- one concrete next step
```

## Model / Effort Policy

Recommended daily mode:

```text
/model opus
/effort xhigh
```

Do-Me-Coding does not require `/effort ultracode` globally. The `/dmc-ultrawork` skill includes a prompt-level workflow request using the `ultracode` keyword so strong workflow behavior can be requested while keeping the session on Opus xhigh.

For very large repo-wide audits or migrations, you may still use:

```text
/effort ultracode
```

## v1.0 Scope

Included:
- `bin/dmc` Ring-0 verdict/validation CLI + `bin/lib` verdict tools
- `orchestration/` registries (`roles.json`, `models.json`, `harness-matrix.json`)
- `.harness` schemas + gates (evidence, verification, release readiness)
- worker adapters (`mock`, `manual-import`, `glm-api` mock-first, `oauth-cli`)
- Claude Code hooks (enforced) + Codex Option-A shims (advisory)
- installer / uninstaller + `dmc doctor`
- release gate + CI

Excluded:
- web UI
- mobile UI
- MCP server
- live provider calls by default (mock-first)
- independent agent runtime
- full OMO fork
- cryptographic approval authentication (v1.1+)
