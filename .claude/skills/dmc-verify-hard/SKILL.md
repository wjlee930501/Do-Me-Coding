---
name: dmc-verify-hard
description: Strictly verify implementation before completion.
argument-hint: optional run id or plan path
disable-model-invocation: true
effort: xhigh
---

# Do-Me-Coding Verify Hard

Target:

```text
$ARGUMENTS
```

Run strict verification.

Checklist:
1. Inspect git diff.
2. Identify package manager.
3. Run lint if available.
4. Run typecheck if available.
5. Run tests if available.
6. Run build if available and reasonable.
7. Check changed files against approved scope.
8. Check package, env, migration, and config changes.
9. Record failed commands exactly.
10. Write `.harness/verification/<run-id>.md`.

Final status: PASS | FAIL | PARTIAL.

Never mark PASS if critical verification failed or was not run.
