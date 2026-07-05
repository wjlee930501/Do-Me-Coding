# dmc.acceptance.v1 — Acceptance Criteria compiler artifact (P8)

Compiled by the M4 run-lifecycle core from an APPROVED plan's Acceptance Criteria + the
orientation `verify_commands`; validator lands in M4. Fail-closed, value-blind: it refuses
untestable criteria rather than passing prose through. The runtime enforcement floor stays the
hooks.

Turns each acceptance criterion into a machine-referable check with an explicit verification
method (v1.0 architecture P8; FABLE_WORKFLOW_TRANSFER B7). "Make it work" is not a criterion — a
check with no `cmd`/`inspection`/`question` is schema-refused. Immutable after plan approval
(subject-bound, §0.4).

```json
{
  "schema": "dmc.acceptance.v1",
  "work_id": "<canonical subject id>",
  "plan_hash": "<hex >=16>",
  "repo_hash": "<hex >=16>",
  "checks": [{
    "check_id": "<stable unique id>",
    "kind": "command|inspection|human",
    "criterion_ref": "<plan Acceptance Criteria reference>",
    "cmd": "<shell command | null>",
    "expect": "<decidable expected-outcome predicate | null>",
    "question": "<named human question | null>",
    "radius_links": ["<radius entry path or check ref>"]
  }],
  "immutable": true,
  "prev_hash": "<hex | genesis>"
}
```

Rules (validator-enforced, fail-closed):
- `schema` exact; subject-binding fields present/non-empty; `checks` non-empty.
- `check_id` unique across the artifact and stable (P10 receipts and P13 counters reference it);
  no duplicate ids.
- `kind` ∈ {command, inspection, human}. `command` ⇒ `cmd` non-empty; `inspection` ⇒ `expect`
  non-empty; `human` ⇒ `question` non-empty. A check lacking its kind's method is REFUSED
  (untestable-criterion refusal — never weakened for testing; self-tests supply synthetic checks).
- `human`-kind checks surface on the release report for the Human Gate (they are bounded escape
  hatches, not silent passes).
- `radius_links` entries are relative paths / check refs with no `..`; every P5 radius entry must
  in turn reference ≥1 `check_id` here (cross-resolution enforced by the M4 validator).
- `immutable` must be `true`; deterministic (sorted, byte-identical for identical inputs).

Negative controls the M4 validator must REFUSE: a `command` check with empty `cmd`; a duplicate
`check_id`; an empty `checks` array; `immutable != true`.

Consumers: P9 (verification planner ordering), P10 (evidence receipts by `check_id`), P13
(per-check attempt counters), P18 (coverage == verify-plan).
