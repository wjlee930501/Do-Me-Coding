---
name: dmc-worker-cancel
description: Cancel or expire a Worker Bridge task. Never mutates product files.
argument-hint: task_id
disable-model-invocation: true
---

# Do-Me-Coding Worker Cancel

Cancel/expire a task per its `cancellation_policy`:
1. Mark `.harness/workers/tasks/<task_id>.json` cancelled (or move its session state aside under
   `.harness/workers/sessions/<task_id>/`).
2. Do NOT apply any pending result for that task.
3. This only affects worker bridge state under `.harness/workers/`; it never touches product files.
