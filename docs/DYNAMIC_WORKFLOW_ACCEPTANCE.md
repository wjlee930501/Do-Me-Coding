# DYNAMIC_WORKFLOW_ACCEPTANCE.md — DMC Dynamic Workflow Capstone (v0.5.9)

Composes the v0.5.3–v0.5.8 Dynamic Workflow layer **offline** over 7 synthetic task classes and proves it selects,
verifies, reviews, and **stops** correctly. No new enforcement hook; no live call; no repo mutation; synthetic fixtures /
`$TMPDIR` only. Run with `--self-test` (the capstone IS the acceptance suite).

## Scenarios
1. **docs closure** — selector ⇒ docs-only/light (smallest sufficient), planner ⇒ markdown checks, full E2E ⇒ DONE.
2. **additive advisory tool** — selector ⇒ additive-tooling, planner ⇒ self-test + structural audit.
3. **provider/import adapter** — selector ⇒ protected-surface/deep, planner ⇒ result-validator + leak scan + reject-path
   + byte-unchanged. **Mock category:** `provider_target=mock` is REJECTED (category error); `run_mode=mock` is allowed
   offline and never lowers the lane.
4. **protected-surface proposed change** — selector ⇒ protected-surface/deep, planner ⇒ protected-path byte-unchanged.
5. **failed-verification recovery** — resume ⇒ STOP, state-machine `VERIFY→RELEASE_AUDIT` BLOCKED on FAIL; PASS proceeds.
6. **review-branch publication** — state-machine `COMMIT→PUSH` allowed with explicit `push_authorized`; resume ⇒ a
   `needs_human_gate` candidate (never an authorization).
7. **premature closure attempt** — `COMMIT→CLOSURE` BLOCKED; closure-before-publish ⇒ INVALID; committed-not-published ⇒
   IN_PROGRESS (no false DONE).

## Invariants asserted
- **E2E-DONE only when all required conditions met** (and a missing condition ⇒ not DONE).
- **Smallest sufficient**: docs-only does not escalate without risk facts.
- **Monotonic**: adding a risk fact escalates the lane.
- **Negative fixtures fail closed**: unknown task_class / missing danger fact ⇒ max lane; `provider_target=mock` rejected.
- **No env/secret reads, no env-controlled hash, no protected-surface mutation, production repo byte-unchanged.**
