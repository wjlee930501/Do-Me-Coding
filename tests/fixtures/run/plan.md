# Plan: SYNTHETIC M4 run-lifecycle fixture (not a real plan)

Plan ID: dmc-fixture-run · Fixture: yes (synthetic; tests/fixtures/run/) · Format: PLAN_SCHEMA.md

This is a **synthetic fixture** consumed by the M4 run-lifecycle self-tests (T009a) and the
sibling sub-task fixtures (T009b–g). It exists only to give `dmc run start` an APPROVED plan to
mint a run from and to give the hermetic tempdir round-trip a structurally-valid plan. It grants
no real authorization and is never executed against the live repo.

## Goal

Provide a minimal, structurally-valid, APPROVED plan for the M4 hermetic run-lifecycle fixtures.

## User Intent

Classify: **feature** (test fixture supporting the M4 run-lifecycle state machine).

## Current Repo Findings

- Finding: the M4 sub-tasks need one shared APPROVED plan to drive `dmc run start` in a tempdir.
  Source: .harness/plans/dmc-v1-m4-run-lifecycle.md (T009a deliverable 3).

## Relevant Files

| Path | Reason | Allowed to Edit |
|---|---|---|
| tests/fixtures/run/plan.md | this synthetic fixture plan | yes (fixture) |
| tests/fixtures/run/orientation.json | fixture orientation artifact | yes (fixture) |
| tests/fixtures/run/radius.json | fixture radius artifact | yes (fixture) |

## Out of Scope

- Any real repository change; this fixture authorizes nothing at runtime.

## Proposed Changes

- Change: none (fixture only).
  Files: tests/fixtures/run/plan.md
  Rationale: a fixture plan carries the plan shape without proposing real work.

## Acceptance Criteria

- Criterion: `dmc validate plan tests/fixtures/run/plan.md` ACCEPTS this plan.
  Verification Method: `bin/dmc validate plan tests/fixtures/run/plan.md` exits 0.
- Criterion: `dmc run start` mints a run when pointed at this APPROVED fixture plan.
  Verification Method: `python3 bin/lib/dmc-run-lifecycle.py --self-test` exits 0.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| a fixture is mistaken for a real plan | low | title + preamble mark it SYNTHETIC; authorizes nothing |

## Assumptions

| Assumption | Confidence | How to Verify |
|---|---|---|
| the M2 plan validator shape is stable | high | `bin/dmc validate plan` on this file |

## Execution Tasks

- [ ] DMC-T001: fixture-only; no execution.
  Files: tests/fixtures/run/plan.md
  Notes: synthetic; present so the plan carries a well-formed Execution Tasks section.

## Verification Commands

| Command | Reason | Required |
|---|---|---|
| bin/dmc validate plan tests/fixtures/run/plan.md | fixture plan stays schema-valid | yes |

## Approval Status

Status: APPROVED
Approver: SYNTHETIC-FIXTURE (not a human release gate; fixture-only, authorizes nothing)
Approved At: 2026-07-06
