# PLAN — v0.5.4 Workflow State Machine (APPROVED)

Parent: batch plan (APPROVED). Additive; protected surface untouched.

## Goal
Encode allowed/forbidden transitions; bind gated transitions to immutable run facts; resume-safe; evaluate E2E-DONE
distinguishing accepted-for-review / published-to-main / closure-recorded. State-discipline tool, not an enforcement hook.

## Accepted file scope (additive)
`docs/WORKFLOW_STATE_MACHINE.md` · `.harness/evidence/dmc-v0.5.4-workflow-state-machine.sh` · this plan ·
`.harness/verification/dmc-v0.5.4-workflow-state-machine.md`.

## Acceptance criteria
valid path passes; premature DONE rejected; stale approval rejected; PR merged but closure missing ⇒ in progress; closure
recorded but main not published ⇒ invalid; no false E2E-DONE; `critic PASS` never authorizes push/main/closure; missing
binding ⇒ BLOCKED (fail-closed). Self-test green; real repo byte-unchanged.

## Stop conditions
Gate confusion, stale-state inference, false DONE, env inference, secret leak.
