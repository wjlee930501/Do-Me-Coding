# RUN_SCHEMA.md

Use this format for `.harness/runs/<run-id>.md`.

```text
# Do-Me-Coding Run

run_id:
active_plan:
status: INIT | RUNNING | BLOCKED | VERIFYING | PASS | FAIL | PARTIAL
started_at:
updated_at:
session_ids:

## Approved File Scope

- path

## Tasks

| ID | Status | Evidence |
|---|---|---|
| DMC-T001 | TODO/DOING/DONE/BLOCKED | path |

## Commands Run

| Command | Result | Evidence |
|---|---|---|
| command | PASS/FAIL/UNKNOWN | path |

## Evidence Files

- path

## Verification Files

- path

## Open Risks

- risk
```
