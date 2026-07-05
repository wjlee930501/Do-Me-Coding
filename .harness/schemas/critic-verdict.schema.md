# dmc.critic-verdict.v1 — Critic Gate verdict artifact (P16)

Emitted by the critic role as a recorded verdict artifact (not chat prose); validator lands in M5.
Fail-closed, value-blind. The runtime enforcement floor stays the hooks.

Makes adversarial plan/diff review a gate with a machine-checkable verdict (v1.0 architecture P16;
FABLE_WORKFLOW_TRANSFER B3/B10). **Invariant C11: the verdict is advisory evidence — it never
flips approval.** Approval is a P17 human-gate record only; a laundered ACCEPT is refused by the
v0.6.5 R12 check.

```json
{
  "schema": "dmc.critic-verdict.v1",
  "work_id": "<canonical subject id>",
  "plan_hash": "<hex >=16>",
  "repo_hash": "<hex >=16>",
  "target_ref": "<plan path or diff ref>",
  "verdict": "APPROVE|REJECT|NEEDS_CLARIFICATION",
  "lenses": ["correctness|scope|security|migration|..."],
  "criteria_checked": [{"criterion_ref": "<ref>", "result": "met|unmet|na", "note": "<advisory>"}],
  "blockers": [{"id": "<blocker id>", "statement": "<what must change>", "evidence_ref": "<ref>"}],
  "advisory": true,
  "context_provenance": "fresh|shared"
}
```

Rules (validator-enforced, fail-closed):
- `schema` exact; subject-binding fields present/non-empty; `target_ref` non-empty.
- `verdict` ∈ {APPROVE, REJECT, NEEDS_CLARIFICATION}. `REJECT` ⇒ `blockers` non-empty (a reject
  with no blocker is refused — no vague rejection). Each blocker carries a non-empty `statement`.
- `advisory` MUST be `true` (C11: the verdict opens no gate). A consumer that treats it as an
  approval is a routing violation.
- `context_provenance` ∈ {fresh, shared}; a binding review requires `fresh` — the author of the
  diff may not emit its own critic verdict (`shared` is flagged, not consumed as independent).
- `lenses` is a non-empty string list; the `security` lens is required when `target_ref` touches
  an `enforcement`-class landmark (P2) — enforced by the consumer.
- `note` fields are advisory free-form (redacted, never gated). Deterministic per input.

Negative controls the M5 validator must REFUSE: `verdict == REJECT` with empty `blockers`;
`advisory != true`; a subject-binding field missing.

Consumers: the plan validator requires a critic-verdict ref before `start-work` (M5); the verdict
feeds the v0.6.5 decision trace as advisory evidence.
