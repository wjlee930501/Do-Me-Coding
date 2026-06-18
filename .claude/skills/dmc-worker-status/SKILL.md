---
name: dmc-worker-status
description: List Worker Bridge tasks, results, and reviews and their states.
disable-model-invocation: true
---

# Do-Me-Coding Worker Status

Report Worker Bridge state (read-only):
1. Tasks: `ls .harness/workers/tasks/` — id + objective + provider_target.type.
2. Results: `ls .harness/workers/results/` — which tasks have a result.
3. Reviews: `ls .harness/workers/reviews/` — decision per task (apply/reject/needs_changes).
4. Flag any task with no result, any result not yet reviewed, and any review with `decision=apply`
   whose patch has not yet been applied via a scoped `Edit`/`Write` run.

Do not mutate anything.
