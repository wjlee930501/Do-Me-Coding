# Plan: M5 arm-run-id pre-run synthetic fixture (not a real plan)

Plan ID: dmc-m5-armrun-fixture

Synthetic fixture consumed only by the T010f arm-run-id pre-run (dmc-orchestration-linkcheck.py
--self-test). Authorizes nothing at runtime; drives verdict-gate -> run start in a disposable tempdir.

## Goal
Prove the ultrawork/start-work path reaches `dmc run start` and arms a run-id from an approved plan.
## User Intent
feature
## Current Repo Findings
- Finding: the pre-run needs one APPROVED plan to mint a run from.
  Source: .harness/plans/dmc-v1-m5-orchestration.md
## Relevant Files
| Path | Reason | Allowed to Edit |
|---|---|---|
| src/app.py | fixture scope | yes (fixture) |
## Out of Scope
- Any real repository change; this fixture authorizes nothing at runtime.
## Proposed Changes
- Change: none (fixture only).
  Files: src/app.py
  Rationale: a fixture plan carries the plan shape without proposing real work.
## Acceptance Criteria
- Criterion: the verdict gate passes the fixture plan+verdict pair.
  Verification Method: `bin/dmc verdict gate --verdict <f> --plan-hash <h>` exits 0.
- Criterion: run start arms a run-id from this approved plan.
  Verification Method: `bin/dmc run start --plan plan.md` exits 0 and creates .harness/runs/<run-id>/.
## Risks
| Risk | Severity | Mitigation |
|---|---|---|
| a fixture is mistaken for a real plan | low | title + preamble mark it SYNTHETIC |
## Assumptions
| Assumption | Confidence | How to Verify |
|---|---|---|
| the M4 run verb + M5 verdict gate interfaces are stable | high | this pre-run |
## Execution Tasks
- [ ] DMC-T001: fixture-only; no execution.
  Files: src/app.py
  Notes: synthetic; present so the plan carries a well-formed Execution Tasks section.
## Verification Commands
| Command | Reason | Required |
|---|---|---|
| bin/dmc validate plan plan.md | fixture plan stays schema-valid | yes |
## Approval Status
Status: APPROVED
Approver: SYNTHETIC-FIXTURE (not a human release gate; fixture-only, authorizes nothing)
Approved At: 2026-07-06
