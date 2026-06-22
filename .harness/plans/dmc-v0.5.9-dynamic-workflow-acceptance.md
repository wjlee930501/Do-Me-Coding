# PLAN — v0.5.9 Dynamic Workflow Capstone Acceptance Suite (APPROVED)

Parent: batch plan (APPROVED). Additive; no new enforcement hook; protected surface untouched; synthetic fixtures only.

## Goal
Compose v0.5.3–v0.5.8 offline across 7 synthetic scenarios (docs closure; additive advisory tool; provider/import
adapter; protected-surface proposed change; failed-verification recovery; review-branch publication; premature-closure
attempt). Assert E2E-DONE only when all required conditions met; smallest-sufficient; monotonic; negative fixtures fail
closed; mock-category fixtures (`provider_target=mock` rejected, `run_mode=mock` offline allowed); repo byte-unchanged.

## Accepted file scope (additive)
`docs/DYNAMIC_WORKFLOW_ACCEPTANCE.md` · `.harness/evidence/dmc-v0.5.9-dynamic-workflow-acceptance.sh` · this plan ·
`.harness/verification/dmc-v0.5.9-dynamic-workflow-acceptance.md`

## Acceptance criteria
all synthetic scenarios pass; negative fixtures fail closed; no false DONE; no env/secret reads; no protected-surface
mutation; repo byte-unchanged after the test. Self-test (the suite) green.

## Stop conditions
Any false DONE, env/secret read, protected-surface mutation, mock/run-mode category error, or non-monotonic escalation.
