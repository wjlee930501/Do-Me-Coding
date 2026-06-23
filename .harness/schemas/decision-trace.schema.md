# decision-trace.schema.md

The decision-traceability contract (DMC v0.6.5 — the capstone). Additive; advisory; **input-only**; **fail-closed**. Answers
**Q5 — "why was this decision made?"** and ships the **mandatory six-question E2E proof**: `--answer` composes a complete
trace-linkage record and proves **Q1–Q6 are answerable from artifacts alone, no model memory.** No undocumented decision, no
untraceable approval, no invisible override.

## Decision entry (a trace-linkage `decision` fragment + v0.6.5-owned fields)
```text
{ "kind":"decision", "id":"<opaque>", "producer_milestone_id":"v0.6.5",
  "rationale_class":"<token_ok>",                       # WHY (a documented non-prose category) — REQUIRED
  "links": { "capability_id":"<token_ok>", "evidence_ids":["<token_ok>",…], "finding_ids":["<token_ok>",…],
             "goal_id":"<token_ok>", "approval_id":"<token_ok>" },   # the rationale chain — all 5 keys REQUIRED
  "work_id","plan_hash"(hex≥16),"repo_hash"(hex≥16),"verification_ref" }
```
Base entry passes `--validate-entry decision`; `rationale_class`/`links` are v0.6.5-owned (the contract ignores them).

## The capstone — `--answer <full-trace-record>`
Input = a complete trace-linkage record (`{subject, registers:{capability,evidence,finding,goal,decision,approval}, edges}`).
1. **Contract `--validate`** (subprocess) — enforces the 5 answer-bearing registers non-empty, per-entry well-formedness
   (approval is `human-release-gate`, capability ∈ six classes), global uniqueness, typed edges, cross-subject. Fails → REFUSE.
2. **Decision linkage** — every `decision.rationale_class` is `token_ok`; every id in `decision.links` resolves to a **declared
   entry of the matching register** (`capability_id`→capability ids · `evidence_ids`→evidence ids · `finding_ids`→finding ids ·
   `goal_id`→goal ids · `approval_id`→approval ids). Any unresolved link → REFUSE (no untraceable approval / dangling rationale).
3. **Answer Q1–Q6 from the record alone:** Q1 capability ids · Q2 evidence ids · Q3 finding ids/states (may be "none") ·
   Q4 goal id · Q5 decision ids + `rationale_class` · Q6 approval id (the human-release-gate approver). Emit
   `{verdict:ANSWERED, Q1_capability,…,Q6_approval, all_answerable:true}` (exit 0); any unanswerable → REFUSE (exit 1).

## Sub-commands
- `--validate <decision|->` — one decision entry (shape + `rationale_class` `token_ok` + `links` structure).
- `--answer <record|-> [--out f]` — the capstone six-question composer.

## Invariants
Deterministic; **env-independent** (no `.env`/credential/network); **input-only** (`--validate`/`--answer` call **no git**);
duplicate-JSON-key rejecting; value-blind reject-on-match; `--out` write-safe (in-repo/traversal/symlink/protected → REFUSED,
core + wrapper). Advisory / fail-closed; **no undocumented decision, no untraceable approval, no invisible override, no answer
from model memory**. Honest scope: approval *authenticity* + live-tree anchoring are upstream (human Release Gate). The runtime
enforcement floor stays the hooks.
