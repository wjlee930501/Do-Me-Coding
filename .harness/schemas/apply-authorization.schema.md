# dmc.apply-authorization.v1 — Worker apply-authorization record (P15 → P7)

Emitted by `dmc worker authorize` and consumed by `dmc worker apply-check` (the P7 apply gate). It is
the hash-chained proof that a worker proposal cleared the `task → result → review` chain and MAY be
translated into scope-guarded Edit/Write operations under the run. Fail-closed, value-blind.

Turns the "apply an accepted proposal" step — a prose `apply_run_id` link today (audit §3) — into a
machine-checkable gate. Workers produce proposals only; mutation happens solely through the
scope-locked executor path AFTER `review-check` PASSES, `worker-result-check.py` ACCEPTs, and this
authorization is emitted (DMC.md Worker Bridge rule). Honest tier: the runtime enforcement floor stays
the scope.lock (Ring-1); this record is the skill-mandated apply chain, BLOCKING at the M9 release
gate (see the M7 plan §5).

```json
{
  "schema": "dmc.apply-authorization.v1",
  "task_id": "<worker task id — a safe slug; the default artifact filename stem>",
  "result_id": "<worker result id: the provider invocation id, else the result's task_id>",
  "review_ref": "<path/ref to the dmc.worker-review.v1 record this authorization rests on>",
  "task_result_hash": "<hex: sha256 over the task bytes, a single LF, and the result bytes>",
  "review_hash": "<hex: sha256 over the review bytes>",
  "run_id": "<the run this apply is authorized under>",
  "authorized_paths": ["<sorted paths, each in task.allowed_files ∩ the run scope>"],
  "prev_hash": "genesis"
}
```

Rules (validator-enforced, fail-closed):
- `schema` exact.
- `task_result_hash` binds the authorization to the exact task+result it authorizes — it is the
  sha256 over the task file bytes, a single `\n` separator byte, and the result file bytes
  (provenance, not authentication). `apply-check` re-reads task+result and recomputes; a mismatch is
  REFUSED. It is the SAME digest the `dmc.worker-review.v1` record carries, so review and
  authorization bind to one identical task+result.
- `review_hash` binds the authorization to the exact review bytes — sha256 over the review file
  bytes. `apply-check` re-reads the review and recomputes; a mismatch is REFUSED (a tampered review
  breaks the chain).
- `authorized_paths` ⊆ `task.allowed_files` ∩ the run's scope. `authorize` derives them from the
  result's `files_changed` ∪ the parsed diff paths and re-checks the subset; `apply-check` re-checks
  the subset and, when a `--scope-lock` is supplied, requires each path to be `allow`-adjudicated by
  `bin/lib/dmc-scope-lock.py --adjudicate LOCK <path> edit` (read-only subprocess, fail-closed).
- `prev_hash` MUST be the literal `"genesis"` in v1.0. Cross-authorization chaining (an
  authorization prev-linked to a prior one) is RESERVED for M9; the field is pinned, not dead weight.
- `task_id` MUST be a safe slug (no `/`, `\`, `..`; the default output path
  `.harness/workers/authorizations/<task_id>.json` derives from it). `authorize` REFUSES a
  path-shaped task id and REFUSES to overwrite an existing authorization (append-only artifact
  family — a re-dispatched task gets a NEW task id per the review record's terminal-REJECT rule).
- Deterministic per input; duplicate-key-rejecting load; secret-shaped paths refused by path.

Negative controls the M7 validator (`dmc worker apply-check`) must REFUSE: a missing authorization at
apply time (apply without a chain); a `task_result_hash` or `review_hash` that does not recompute; a
review whose `decision != apply`; an `authorized_paths` entry outside `task.allowed_files`; an
authorized path outside a supplied scope.lock; a `prev_hash` other than `"genesis"`; and (at
`authorize`) a path-shaped `task_id`.

Consumers: P7 apply gate (`dmc worker apply-check` — applied paths ⊆ `task.allowed_files` ∩ run scope,
chain hashes recompute, scope.lock adjudication). Extends the `dmc.worker-review.v1` review record
(P15) and the `.harness/schemas/scope-lock.schema.md` write floor.

Disclosure (A4): `result_id` is NOT a unique key — adapter-defaulted invocation ids are shared across
results (an adapter may stamp a constant invocation id), so two distinct results can carry the same
`result_id`. Uniqueness of an authorization rests on `task_result_hash` (the task+result byte digest),
never on `result_id`.
