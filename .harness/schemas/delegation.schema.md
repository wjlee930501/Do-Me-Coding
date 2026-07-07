# dmc.delegation.v1 — Subagent delegation record (P14)

Appended by the M5 orchestration layer, one JSON object per line (JSONL, append-only,
hash-chained); validator lands in M5. Fail-closed, value-blind. The runtime enforcement floor
stays the hooks.

Binds the role taxonomy to actual dispatch and keeps the orchestrator accountable for every
artifact it consumes (v1.0 architecture P14; `docs/DMC_V1_ORCHESTRATION_MODEL.md` §3/§5). A
delegate's prose is never consumed unvalidated: schema validation precedes consumption.

```json
{
  "schema": "dmc.delegation.v1",
  "work_id": "<canonical subject id>",
  "plan_hash": "<hex >=16>",
  "repo_hash": "<hex >=16>",
  "delegation_id": "<stable id>",
  "role": "<orchestration/roles.json role>",
  "capability_class": "frontier-long-horizon|adversarial-review|standard-implementation|cheap-fast|deterministic-tool|human-only-gate",
  "may_mutate": <bool>,
  "scope_lock_ref": "<path | run-default>",
  "depth": <int >=0>,
  "max_depth": <int >=1>,
  "artifact_ref": "<path to the delegate's artifact | null>",
  "artifact_schema": "<schema id the artifact must validate against | null>",
  "validation_verdict": "PASS|FAIL|PENDING",
  "prev_hash": "<hex | genesis>"
}
```

Rules (validator-enforced, fail-closed):
- `schema` exact; subject-binding fields present/non-empty; `delegation_id` non-empty.
- `role` must resolve in `orchestration/roles.json` (single taxonomy, M5); `capability_class` ∈
  the v0.6.1 enum. `may_mutate: true` is permitted ONLY for the executor role and ONLY under an
  active `scope.lock` — a mutation-capable dispatch without a lock is refused. That active
  `scope.lock` is named by the `scope_lock_ref` field, required whenever `may_mutate: true` (the
  validator has enforced this since M5; this illustration catches up — validator behavior unchanged).
- `depth ≤ max_depth` (deterministic recursion bound, v0.6.0 defer-card condition); over-depth is
  a stop condition.
- Consuming an artifact requires `validation_verdict == PASS`; `FAIL`/`PENDING` artifacts must not
  be consumed (unvalidated-prose consumption is a stop condition). When `artifact_ref` is present,
  `artifact_schema` must name the schema it was validated against.
- Append-only JSONL with `prev_hash`; deterministic per input. Serialization (external chain authors
  MUST reproduce it): each stored line is compact-canonical JSON —
  `json.dumps(sort_keys=True, separators=(",", ":"), ensure_ascii=False)`, UTF-8 — and `prev_hash` is
  the sha256 of the PREVIOUS stored line's exact bytes with the terminating LF EXCLUDED (the newline
  is the JSONL record separator, not part of the hashed record), or the literal `genesis` for the
  first line. Hash the stored canonical serialization, not your submitted bytes.

Negative controls the M5 validator must REFUSE: `may_mutate: true` with no scope-lock reference;
`depth > max_depth`; a `role` absent from the registry; consumption recorded with
`validation_verdict != PASS`.

Consumers: P16 (critic dispatch), P18 release gate (a run whose applied changes lack an
import/delegation chain is refused). Automated multi-agent scheduling is deferred (v1.1).
