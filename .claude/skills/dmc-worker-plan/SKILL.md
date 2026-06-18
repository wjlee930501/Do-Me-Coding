---
name: dmc-worker-plan
description: Author a bounded Worker Bridge task (mock-only in v0.2) — clipped, secret-scrubbed.
argument-hint: objective
disable-model-invocation: true
---

# Do-Me-Coding Worker Plan

Author a worker task per `WORKER_TASK_SCHEMA.md` at `.harness/workers/tasks/<task_id>.json`.

Rules:
1. Define `allowed_files` and `forbidden_files` tightly (least privilege).
2. `context_summary` + `relevant_snippets` only — NO broad repo dump, NO secrets.
3. No `allowed_files`/snippet path may be secret-bearing (`.env*`, keys, credentials, etc.).
4. Set `provider_target.execution_mode=proposal_only`, `credential_policy=no_credentials_in_repo`,
   `secret_policy=no_secret_context`. In v0.2, `provider_target.type` is `mock` or `manual_import` only.
5. The worker proposes only; it never mutates the repo. Record `verification_hints` (e.g. `vitest run`).

Do not dispatch here — that is `/dmc-worker-dispatch`.
