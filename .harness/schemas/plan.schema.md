# PLAN_SCHEMA.md

Use this format for `.harness/plans/<plan-id>.md`.

```text
# Plan Title

## Goal

## User Intent

Classify as one:
research | investigation | bugfix | feature | refactor | cleanup | migration | docs | verification

## Current Repo Findings

- Finding:
  Source:

## Relevant Files

| Path | Reason | Allowed to Edit |
|---|---|---|
| path | reason | yes/no |

## Out of Scope

- item

## Proposed Changes

- Change:
  Files:
  Rationale:

## Acceptance Criteria

- Criterion:
  Verification Method:

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| risk | low/medium/high | mitigation |

## Assumptions

| Assumption | Confidence | How to Verify |
|---|---|---|
| assumption | low/medium/high | method |

## Execution Tasks

- [ ] DMC-T001:
  Files:
  Notes:

## Verification Commands

| Command | Reason | Required |
|---|---|---|
| command | reason | yes/no |

## Approval Status

Status: DRAFT | APPROVED | REJECTED
Approver:
Approved At:
```
