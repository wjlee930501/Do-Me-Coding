# dmc.fixloop.v1 — Regression Suspicion / bounded fix-loop record (P13)

Appended by the M4 fix-loop engine, one JSON object per line (JSONL, append-only, hash-chained);
validator lands in M4. Fail-closed, value-blind. The runtime enforcement floor stays the hooks.

Maps a failing check to its fix attempts and enforces the bounded loop (v1.0 architecture P13;
FABLE_WORKFLOW_TRANSFER B9). Counters bind to `plan_hash`, **not** `run_id`, so a fresh run cannot
launder a counter back to zero (counter-reset gaming is refused).

```json
{
  "schema": "dmc.fixloop.v1",
  "plan_hash": "<hex >=16>",
  "check_id": "<id from acceptance.json>",
  "attempt": <int >=1>,
  "hypothesis": "<advisory free-text — redacted, never gated>",
  "files_touched": ["<relpath>"],
  "bound": <int >=1>,
  "verdict": "CONTINUE|STOP",
  "prev_hash": "<hex | genesis>"
}
```

Rules (validator-enforced, fail-closed):
- `schema` exact; `plan_hash` present/non-empty; `check_id` non-empty; `attempt` an integer ≥ 1,
  monotonic per `(plan_hash, check_id)` (no reset across runs — subject-bound).
- `bound` an integer ≥ 1; `attempt > bound` ⇒ `verdict` MUST be `STOP` (the bounded loop halts and
  hands off to P12 restore + P17 structured failure report). `verdict` ∈ {CONTINUE, STOP}.
- `files_touched` are relative paths, no `..`.
- `hypothesis` is **advisory free-form metadata**: quality is never gated, and the producer must
  redact it (no secrets, no `.env` values) — the validator treats it value-blind and never trusts
  it as evidence (advisory-rail redaction discipline).
- Append-only JSONL; each line carries `prev_hash` (hash-chain). Deterministic per input.

Negative controls the M4 validator must REFUSE: `attempt` at/over `bound` with `verdict` other than
`STOP`; `attempt < 1`; a counter that decreases for the same `(plan_hash, check_id)`; a
`files_touched` entry with `..`.

Consumers: P12 (restore suggestion at bound), P17 (structured failure report), v0.6.3 findings
register (unpredicted regressions).
