# dmc.worker-review.v1 — Worker proposal review record (P15)

Emitted by the review role and checked by the NEW review validator (`dmc worker review-check`,
lands in M7). Fail-closed, value-blind. The runtime enforcement floor stays the hooks.

Turns the worker review stage — 100% prose today (audit §3) — into a machine-checkable gate in
the hash-chained `task → result → review → apply` importer (v1.0 architecture P15;
`docs/DMC_V1_ORCHESTRATION_MODEL.md` §5). Workers produce proposals only; mutation happens solely
through the scope-locked executor path after this review PASSES (DMC.md Worker Bridge rule).

```json
{
  "schema": "dmc.worker-review.v1",
  "task_id": "<worker task id>",
  "result_id": "<worker result id>",
  "provider": "<adapter/provider id>",
  "reviewer_role": "<read-only review role: critic|release-auditor>",
  "checks": [{"check": "scope-compat|token-scan|fidelity|contract|disallowed-category", "result": "PASS|FAIL", "evidence_ref": "<ref>"}],
  "decision": "apply|reject",
  "task_result_hash": "<hex chain over task+result>",
  "prev_hash": "<hex | genesis>"
}
```

Rules (validator-enforced, fail-closed):
- `schema` exact; `task_id`, `result_id`, `provider` non-empty; `task_result_hash` present
  (hash-chain binds review to the exact task+result it reviewed — provenance, not authentication).
- `reviewer_role` must be a `may_mutate: false` review role (an implementer may not review its own
  proposal — no self-approval).
- `checks` is non-empty and must include the mandatory kinds `scope-compat`, `token-scan`,
  `fidelity`, `disallowed-category`; each `result` ∈ {PASS, FAIL}. An empty `checks` array is
  REFUSED (no rubber-stamp review).
- `decision == apply` ⇒ **every** `checks[].result == PASS`. Any `FAIL` ⇒ `decision` must be
  `reject` (fail-closed; a REJECT is terminal for that result — re-dispatch needs a new task id).
- Deterministic per input; duplicate-key-rejecting load.

Negative controls the M7 validator must REFUSE: `decision == apply` with any `check.result ==
FAIL`; an empty `checks` array; a missing mandatory check kind; a `reviewer_role` that is
mutation-capable.

Consumers: P15 import gate (apply-authorization requires review PASS), P7 (applied paths ⊆
`task.allowed_files` ∩ run scope at apply). Extends the v0.3.3 worker contract suite.
