# PLAN — v0.5.3 Dynamic Workflow Selector (APPROVED)

Parent: `.harness/plans/dmc-v0.5.3-v0.5.9-batch-plan.md` (APPROVED after Codex critic PASS, Revision 1). Scope is
**additive**; protected surface untouched.

## Goal
Select the smallest sufficient workflow lane from explicit task facts; fail-closed on unknown/danger; structural
monotonicity; distinguish run-mode from provider_target.

## Accepted file scope (additive only)
- `docs/DYNAMIC_WORKFLOW.md`
- `.harness/evidence/dmc-v0.5.3-dynamic-workflow-selector.sh`
- `.harness/plans/dmc-v0.5.3-dynamic-workflow-selector.md` (this file)
- `.harness/verification/dmc-v0.5.3-dynamic-workflow-selector.md`

## Acceptance criteria
docs-only ⇒ light; protected-surface ⇒ deep + byte-unchanged gate; secret/network/live ⇒ adversarial; unknown task class
⇒ fail-closed max; env vars do not affect classification; monotonicity (adding risk never lowers intensity);
`provider_target=mock` ⇒ category-error refusal; `run_mode=mock` never lowers the lane. Self-test green; real repo
byte-unchanged.

## Design (key decisions, from batch plan)
Closed fact schema; `max`/union merge; provider-adapter facts ⇒ protected-surface; deterministic env-free `repo_hash`
(`git status --porcelain | python3 hashlib.sha256`); fail-closed boolean/numeric parsing; structural self-audit
(no net/env/env-hash). Output explicitly labelled advisory, not enforcement.

## Stop conditions
Any secret leak, env inference, false intensity downgrade, mock/run-mode category error, or protected-surface mutation.
