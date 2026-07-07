---
name: dmc-worker-review
description: Orchestrator/critic review of a worker proposal; decide apply/reject. Never mutates the repo.
argument-hint: task_id
disable-model-invocation: true
---

# Do-Me-Coding Worker Review

Review NEVER mutates the repo. Write a record per `WORKER_REVIEW_SCHEMA.md` at
`.harness/workers/reviews/<task_id>.json`.

1. Confirm import checks passed (schema, scope, security, consistency, no-secret, no-disallowed-category;
   `dmc-worker-import` already authored a `dmc.worker-review.v1` record and it PASSED
   `dmc worker review-check`).
2. Optionally run `/dmc-critic` on the proposal.
3. Decide `apply | reject | needs_changes`. `apply` is allowed ONLY when every check passes AND the
   review record's `decision` field is `apply` (every check `PASS`, `reviewer_role` non-mutating).
4. If `apply`: the machine-checked apply chain, in order —
   a. `dmc worker authorize --task <task.json> --result <result.json> --review <review.json>
      --run <RUN_ID>` — emits `dmc.apply-authorization.v1` (append-only). REFUSES unless the review
      record binds to this exact task+result, `decision==apply`, and the hardened
      `worker-result-check.py` ACCEPTs.
   b. `dmc worker apply-check --auth <auth.json> --task <task.json> --result <result.json>
      --review <review.json> [--scope-lock <lock>]` MUST PASS before any repo edit — a missing or
      unauthorized chain means "apply without a chain refused". Only then translate the change into
      scope-guarded `Edit`/`Write` operations under a `/dmc-start-work` scope — set
      `apply_policy=edit_write_only`. NEVER `git apply`/`patch`.
   c. Capture the applied change with `git diff` and run `dmc worker fidelity --result <result.json>
      --applied-diff <diff-file>` — REFUSES unless the applied diff matches the proposed patch at the
      names+hunk-count tier (content equality NOT claimed).
   Apply is FORBIDDEN without a PASSing `dmc worker apply-check`.
5. If `reject`/`needs_changes`: the repo stays unchanged.

HONEST ENFORCEMENT TIER: the review-check → authorize → apply-check → fidelity chain is
skill-mandated procedure, not a Ring-0/1 hook block — nothing in the hook path stops an Edit/Write
that is inside scope.lock but lacks an authorization; the runtime write floor remains scope-lock
adjudication. The chain becomes BLOCKING at the M9 release gate (a run whose applied changes lack an
import/delegation chain is refused).
