# PLAN — v0.6.5 Decision Traceability Layer + six-question E2E proof (DRAFT)

**Parent roadmap:** `.harness/plans/dmc-v0.6.1-v0.6.5-roadmap.md` (APPROVED). **Branch:** `dmc-control-plane/v0.6.1`.
**Depends on:** v0.6.1.0 contract (`--validate` full record / `--validate-entry decision` / `--validate-entry approval`),
and the artifacts of v0.6.1–v0.6.4 (capability / evidence / finding / goal entries).
**Type:** schema + deterministic decision validator + **the capstone six-question `--answer` composer**. **Additive, advisory,
fail-closed, input-only, read-only**; no protected-surface change, no live/model/API/`.env`/network, no auto-apply.

**Review cadence (2026-06-24):** Codex MCP dropped (slow/flaky); **DMC `critic` (plan) + DMC `verifier` (build) only.**

**Purpose.** Answer **Q5 — "why was this decision made?"** with a documented, linked decision entry, and ship the **mandatory
capstone**: an offline `--answer` that composes a complete trace-linkage record and proves **all six questions Q1–Q6 are
answerable from artifacts alone, with no model memory.** No untraceable approval, no invisible override, no undocumented decision.

---

## 1. Problem statement
A decision ("we shipped X") must be reconstructable from artifacts: what capability did it (Q1), what evidence (Q2), what
findings remain (Q3), what goal authorized it (Q4), why (Q5), who approved release (Q6). v0.6.5 defines the decision entry
(documented rationale + links) and the `--answer` composer that validates a complete trace and emits the six answers — the
roadmap's success metric. If any question is unanswerable from the record, `--answer` REFUSEs.

## 2. Non-goals
- **No** undocumented decision (every decision carries a non-prose `rationale_class`), **no** untraceable approval (every
  approval referenced is a declared `approval` entry in the record), **no** invisible override.
- **No** provider/model/API/network/`.env` read; reads only the record file/stdin; `--validate`/`--answer` call **no git**.
- **Not** verifying human-approval *authenticity* or live-tree anchoring (input-only) — upstream (human Release Gate); v0.6.5
  verifies **shape + completeness + linkage + answerability**.
- **Not** re-implementing the per-fragment checks — it composes via the v0.6.1.0 contract `--validate`.

## 3. Design
### 3.1 Decision entry (a trace-linkage `decision` fragment + v0.6.5-owned fields)
```text
{ "kind":"decision", "id":"<opaque>", "producer_milestone_id":"v0.6.5",
  "rationale_class":"<token_ok>",                                          # WHY (a documented non-prose category)
  "links": { "capability_id":"<token_ok>", "evidence_ids":["<token_ok>",…], "finding_ids":["<token_ok>",…],
             "goal_id":"<token_ok>", "approval_id":"<token_ok>" },          # the rationale chain
  "work_id","plan_hash"(hex≥16),"repo_hash"(hex≥16),"verification_ref" }    # 4 contract binding fields
```
Base entry passes `--validate-entry decision`; `rationale_class`/`links` are v0.6.5-owned. `rationale_class` REQUIRED + `token_ok`.

### 3.2 The capstone — `--answer <full-trace-record>`
Input = a complete trace-linkage record (the v0.6.1.0 shape): `{ subject, registers:{capability, evidence, finding, goal,
decision, approval}, edges }`.
1. **Validate the complete record via the v0.6.1.0 contract `--validate`** (subprocess) — enforces completeness (the five
   answer-bearing registers non-empty), per-entry well-formedness (incl. `approval` is `human-release-gate`, `capability_class`
   ∈ six), global uniqueness, typed edges, cross-subject. If it fails → **REFUSE** (the record isn't a valid complete trace).
2. **Decision linkage (Q5 traceability):** every `decision.rationale_class` is `token_ok` (documented); every id in
   `decision.links` (`capability_id`/`evidence_ids`/`finding_ids`/`goal_id`/`approval_id`) MUST reference a **declared entry of
   the matching register** in the record (no untraceable/dangling link). If any link is unresolved → **REFUSE**.
3. **Answer Q1–Q6 from the record alone** (no model memory):
   - **Q1 capability** = the `capability` register ids (the class that performed the work).
   - **Q2 evidence** = the `evidence` register ids/types.
   - **Q3 findings** = the `finding` register ids/states (may be empty — "none").
   - **Q4 goal** = the `goal` register id (the authorizing goal, a v0.4.1 reference).
   - **Q5 decision** = the `decision` register ids + `rationale_class` (the why).
   - **Q6 approval** = the `approval` register id (the `human-release-gate` authorizer).
4. Emit `{ "verdict":"ANSWERED", "Q1_capability":…, "Q2_evidence":…, "Q3_findings":…, "Q4_goal":…, "Q5_decision":…,
   "Q6_approval":…, "all_answerable":true }`. exit 0. Any unanswerable question → **REFUSE** (exit 1). **This is the mandatory
   six-question E2E proof.**

### 3.3 Sub-commands
- `--validate <decision.json|->` — one decision entry (kind/producer/id/4-binding via shape; `rationale_class` `token_ok`;
  `links` structure with `token_ok` ids). exit 0/1/2.
- `--answer <record.json|-> [--out <file>]` — the capstone composer (§3.2). exit 0 ANSWERED / 1 REFUSE / 2 usage/refused-out.
- `--self-test` — incl. the mandatory E2E: a complete synthetic trace → all six answered; an incomplete/forged/dangling-link
  trace → REFUSE.

### 3.4 Outputs
- `.harness/schemas/decision-trace.schema.md` — decision entry + the `--answer` six-question compose + honest scope.
- `.harness/evidence/dmc-v0.6.5-decision-trace.{py,sh}` — decision validator + `--answer` composer; input-only, env-free,
  no-heredoc/no-temp, dup-key-rejecting, value-blind, write-safe `--out` (reuse v0.6.3/6.4 `out_unsafe`/`vet_out`).
- `.harness/verification/dmc-v0.6.5-decision-traceability.md` — report **recording the six-question E2E proof result** + the
  explicit line that the layer answers Q1–Q6 from artifacts alone, no model memory.

## 4. File scope (additive only): the 3 deliverables + this plan. No other file touched.

## 5. Acceptance criteria (`--self-test`; every negative named)
| ID | Assertion |
|----|-----------|
| D1 | a valid decision entry → VALID; base entry passes contract `--validate-entry decision` (producer v0.6.5). |
| D2 | decision missing/prose `rationale_class` (not `token_ok`) → REJECT (no undocumented decision). |
| D3 | decision `links` missing a required key, or a non-`token_ok` id → REJECT. |
| D4 | **answer: a complete synthetic trace (all six registers, decision links all resolve) → ANSWERED with Q1–Q6 all present** (the mandatory E2E proof). |
| D5 | answer: the record fails the contract `--validate` (a register empty / non-human approval / cross-subject / dangling edge) → REFUSE (each a named negative). |
| D6 | answer: a decision `links.approval_id` (or other link) that references an id NOT declared in the record → REFUSE (untraceable approval / dangling rationale). |
| D7 | answer: Q3 findings empty (no findings) still ANSWERED (Q3 = "none"); but capability/evidence/goal/decision/approval empty → REFUSE (via contract completeness). |
| D8 | duplicate JSON key / secret-shaped string anywhere → REJECT; malformed root → REFUSE. |
| D9 | determinism/env-free: `env -i` + hostile credential var → identical verdict; `--validate`/`--answer` call no git. |
| D10 | read-only: repo byte-unchanged after `--self-test`; `--out` write-safe (core + wrapper). |
| D11 | regression: v0.6.1.0 (26/0) + v0.6.1 (7/0) + v0.6.2 (18/0) + v0.6.3 (25/0) + v0.6.4 (27/0) verifiers still green. |
| Dneg | every negative FAILs for its own reason; positives pass — no false-green. |

## 6. Safety constraints
Additive only; no protected-surface change; no live/model/API/network/`.env`; deterministic + env-independent; value-blind
reject-on-match; duplicate-key rejecting; advisory/fail-closed; inert unless invoked; **no undocumented decision, no
untraceable approval, no invisible override, no answer from model memory**; no-heredoc/no-temp; `--validate`/`--answer` call no
git; `--out` write-safe.

## 7. Regression budget
Before commit: v0.6.1.0 (26/0) + v0.6.1 (7/0) + v0.6.2 (18/0) + v0.6.3 (25/0) + v0.6.4 (27/0) self-tests.

## 8. Rollback
Additive on the feature branch: `git checkout -- <files>` before commit, or revert the additive commit. No protected surface,
no history rewrite, no force.

## 9. Approval status: **DRAFT — route to DMC `critic` (Codex dropped)**
On critic APPROVE (bounded-batch authorization covers approval): build → verify (`--self-test`, incl. the mandatory
six-question E2E proof) → DMC `verifier` audit → commit on `dmc-control-plane/v0.6.1`. Push / main-FF / closure remain
human-gated.
