---
name: dmc-ultrawork
description: Run a strict Do-Me-Coding workflow with planning, critique, execution, verification, and evidence logging.
argument-hint: task description
disable-model-invocation: true
effort: xhigh
---

# Do-Me-Coding Ultrawork Mode

Task:

```text
$ARGUMENTS
```

ultracode: create a workflow for this task before doing implementation work.

Do not edit files immediately.

## Required Process

1. Restate the user goal in concrete terms.
2. Classify the intent.
3. Inspect the repository enough to identify relevant files and existing patterns.
4. Write or update a plan under `.harness/plans/`.
5. Define acceptance criteria and verification commands.
6. Run a critic pass before implementation.
7. Establish approved file scope and write it to `.harness/runs/current-scope.txt`.
8. Execute task by task.
9. Run verification after meaningful changes.
10. If verification fails, fix and rerun.
11. Save evidence under `.harness/evidence/`.
12. Save verification under `.harness/verification/`.
13. Final response must include status, changed files, verification results, evidence files, unresolved risks, and next action.

## Completion Rule

Never claim done if verification failed, was skipped, or has no written evidence.
