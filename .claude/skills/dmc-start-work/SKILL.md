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

Execute only an approved plan. Role dispatch follows the registry in
`orchestration/roles.json`: this skill runs the **Implementer** lane — the only
`may_mutate` role, and only under the scope armed below.

## Ring-0 preconditions (run these before any edit)

1. Read the plan; confirm `Approval Status` is `APPROVED`. If not approved, stop and ask for approval.
2. Run the critic-verdict gate — the Ring-0 refusal that must pass before any run is armed:

   ```text
   bin/dmc verdict gate --verdict <critic-verdict.json> --plan-hash <sha256 of the plan file>
   ```

   The gate REFUSES (exit 3) when the referenced `critic-verdict.json` is absent, schema-invalid,
   or its `plan_hash` does not bind this plan. On REFUSE: **stop — no run is armed, no edit happens.**
3. Arm the run — the machine run-state is owned by the M4 run verb, not hand-authored:

   ```text
   bin/dmc run start --plan <approved plan path>
   ```

   This mints and arms the run-id and locked scope under `.harness/runs/<run-id>/` (it also refuses
   unless the plan is `APPROVED`). It replaces the old manual authoring of `current-run.md`,
   `current-run-id`, and `current-scope.txt` — the run verb now owns that machine state.
4. Restate the task list.

> **Layer disclosure (carry-forward note 3).** The *refusal* in step 2 is **Ring-0** — `dmc verdict
> gate` is deterministic and fail-closed. The *obligation* to invoke the gate before mutating is
> **Ring-2 skill prose** until M6 wires the Ring-1 Stop/scope hooks.

During execution:
- Work task by task.
- Modify only files inside the armed scope (the Implementer stays inside the scope lock).
- Keep diffs small.
- Record commands and observations.
- Run relevant verification after meaningful changes.

After execution:
- Run `/dmc-verify-hard`.
- Write final evidence.
- Report PASS, FAIL, or PARTIAL.

No verification report means no done.
