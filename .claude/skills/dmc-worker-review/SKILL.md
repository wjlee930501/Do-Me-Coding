---
name: dmc-worker-review
description: Orchestrator/critic review of a worker proposal; decide apply/reject. Never mutates the repo.
argument-hint: task_id
disable-model-invocation: true
---

# Do-Me-Coding Worker Review

Review NEVER mutates the repo. Write a record per `WORKER_REVIEW_SCHEMA.md` at
`.harness/workers/reviews/<task_id>.json`.

1. Confirm import checks passed (schema, scope, security, consistency, no-secret, no-disallowed-category).
2. Optionally run `/dmc-critic` on the proposal.
3. Decide `apply | reject | needs_changes`. `apply` is allowed ONLY when every check passes.
4. If `apply`: application happens ONLY by translating the change into scope-guarded `Edit`/`Write`
   operations under a `/dmc-start-work` scope — set `apply_policy=edit_write_only`. NEVER `git apply`/`patch`.
5. If `reject`/`needs_changes`: the repo stays unchanged.
