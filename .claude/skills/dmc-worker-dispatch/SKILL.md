---
name: dmc-worker-dispatch
description: Validate + package a worker task and hand it to a mock/manual worker (no live API in v0.2).
argument-hint: task_id
disable-model-invocation: true
---

# Do-Me-Coding Worker Dispatch

Dispatch MUST NOT mutate the repo.

Steps:
1. Run the context guard (fail-closed): `bash .claude/hooks/worker-context-guard.sh .harness/workers/tasks/<task_id>.json`.
   If it exits non-zero (secret/forbidden content), STOP — do not dispatch.
2. v0.2 is mock/manual only: NO live GLM/API call, NO credentials. Either (a) hand the validated task
   bundle to a `manual_import` worker, or (b) use a local mock. Record dispatch state under
   `.harness/workers/sessions/<task_id>/`.
3. The worker returns a result file at `.harness/workers/results/<task_id>.json` (you do not apply it here).

Never call an external provider API, add credentials, or read OAuth/session files.
