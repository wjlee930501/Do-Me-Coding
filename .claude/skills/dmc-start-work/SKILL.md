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
3. Arm the run — mint the run-state AND compile the immutable scope lock in ONE fail-closed step
   (the machine run-state is owned by the M4 run verb, not hand-authored):

   ```text
   bin/dmc run start --plan <approved plan path> --scope-input <scope-input.json>
   ```

   This mints the run-id under `.harness/runs/<run-id>/`, then compiles + validates the immutable
   `scope.lock.json` from the plan and the landmark scope-input (it still refuses unless the plan is
   `APPROVED`). On success it prints `ARMED: <lock> (validated)`. If the compile or validate step
   fails it prints `REFUSED-ARMING:`, tears the half-armed run down (suspend + drop the run
   pointer), and exits 3 — a run that looks started but carries no validated lock never survives.
   This replaces the old manual authoring of `current-run.md`, `current-run-id`, and
   `current-scope.txt`; the run verb now owns that machine state.

   The `--scope-input` file is the landmark-annotated scope the lock is compiled from:

   ```json
   {
     "files": [
       {"path": "src/app.py", "grant": "edit", "landmark_class": "ordinary"},
       {"path": "bin/dmc", "grant": "edit", "landmark_class": "enforcement", "landmark_authorized": true}
     ],
     "bounds": {"max_files": 2, "max_added": 200, "max_deleted": 50, "forbidden_hunk_classes": []}
   }
   ```

   Each `files[]` entry is `{path, grant: edit|create, landmark_class}`; a non-`ordinary`
   `landmark_class` (`enforcement` / `contract` / `release` / `data`) additionally requires
   `landmark_authorized: true`, an explicit plan authorization that is never implicit. `bounds`
   caps `max_files` / `max_added` / `max_deleted` and lists any `forbidden_hunk_classes`.

   Running `run start` WITHOUT `--scope-input` still starts the run but arms NO lock: it prints a
   `WARNING: run started UNARMED` and L1 scope enforcement stands down. Do not execute an unarmed run.
4. No accepted file scope, no edit. Before ANY edit, confirm the run is armed — the lock exists AND
   validates:

   ```text
   python3 bin/lib/dmc-scope-lock.py --validate .harness/runs/<run-id>/scope.lock.json
   ```

   If `.harness/runs/<run-id>/scope.lock.json` is absent, or `--validate` does not ACCEPT (exit 0):
   **STOP — the run is not armed; no edit happens.**
5. Restate the task list.

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
