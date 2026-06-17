---
name: dmc-start-work
description: Execute an approved Do-Me-Coding plan with scope lock, evidence logging, and verification.
argument-hint: path to approved plan
disable-model-invocation: true
effort: xhigh
---

# Do-Me-Coding Start Work

Approved plan path:

```text
$ARGUMENTS
```

Execute only an approved plan.

Before editing:
1. Read the plan.
2. Confirm `Approval Status` is `APPROVED`.
3. If not approved, stop and ask for approval.
4. Create or update `.harness/runs/current-run.md`.
5. Write active run id to `.harness/runs/current-run-id`.
6. Write approved file scope to `.harness/runs/current-scope.txt`.
7. Restate the task list.

During execution:
- Work task by task.
- Modify only approved files.
- Keep diffs small.
- Record commands and observations.
- Run relevant verification after meaningful changes.

After execution:
- Run `/dmc-verify-hard`.
- Write final evidence.
- Report PASS, FAIL, or PARTIAL.

No verification report means no done.
