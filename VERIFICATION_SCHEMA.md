<!-- DMC canonical home: VERIFICATION_SCHEMA.md (root). Generated mirror: .harness/schemas/verification.schema.md — edit here; regenerate the mirror; never hand-edit the mirror. -->

# VERIFICATION_SCHEMA.md

Use this format for `.harness/verification/<run-id>.md`.

```text
# Verification Report

## Run ID

## Plan

## Changed Files

- path: reason

## Commands Run

| Command | Result | Reason | Output Summary |
|---|---|---|---|
| command | PASS/FAIL/SKIPPED | reason | summary |

## Manual Checks

| Check | Result | Notes |
|---|---|---|
| check | PASS/FAIL/SKIPPED | notes |

## Scope Review

Result: PASS | FAIL

Notes:

## Package / Env / Migration Review

Package files changed: yes/no
Env files changed: yes/no
Migration files changed: yes/no

Notes:

## Unresolved Risks

- risk or none

## Final Status

PASS | FAIL | PARTIAL
```
