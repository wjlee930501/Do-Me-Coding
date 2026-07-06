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
6. Dispatch the **critic agent** (its contract is `.claude/agents/critic.md`; the **Critic /
   Falsifier** role in `orchestration/roles.json`) for a fresh-context adversarial pass. It emits a
   `critic-verdict.json` artifact conforming to `.harness/schemas/critic-verdict.schema.md` — not
   prose-only.
7. Gate on that verdict, then arm the run (machine run-state is owned by the M4 run verb):

   ```text
   bin/dmc verdict gate --verdict <critic-verdict.json> --plan-hash <sha256 of the plan file>
   bin/dmc run start --plan <approved plan path>
   ```

   The gate REFUSES (exit 3) on an absent / schema-invalid / `plan_hash`-mismatched verdict — on
   REFUSE, stop and arm no run. `bin/dmc run start` mints the run-id and locked scope under
   `.harness/runs/<run-id>/`, replacing the old hand-written `current-scope.txt`.
8. Execute task by task (the **Implementer** lane — the only `may_mutate` role, inside the armed scope).
9. Run verification after meaningful changes.
10. If verification fails, fix and rerun.
11. Save evidence under `.harness/evidence/`.
12. Save verification under `.harness/verification/`.
13. Final response must include status, changed files, verification results, evidence files, unresolved risks, and next action.

> **Layer disclosure.** The verdict-gate refusal in step 7 is **Ring-0** (deterministic,
> fail-closed); the obligation to invoke it before mutating is **Ring-2 skill prose** until M6 wires
> the Ring-1 Stop/scope hooks.

## Completion Rule

Never claim done if verification failed, was skipped, or has no written evidence.
