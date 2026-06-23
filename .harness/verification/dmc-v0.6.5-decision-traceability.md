# Verification Report — DMC v0.6.5 Decision Traceability (capstone)

**Milestone:** v0.6.5 (Decision Traceability Layer) — the **capstone** of the v0.6.1–v0.6.5 control-plane layer. **Advisory,
not enforcement.** Schema + one inert, read-only, input-only decision validator + the six-question `--answer` composer; selects
no model, opens no live gate, calls no provider/model/API/network/`.env`, and `--validate`/`--answer` call no git. Answers
**Q5 — "why was this decision made?"** and ships the mandatory six-question E2E proof.

**Tool:** `.harness/evidence/dmc-v0.6.5-decision-trace.sh` (wrapper) + `.harness/evidence/dmc-v0.6.5-decision-trace.py` (core)
**Command:** `bash .harness/evidence/dmc-v0.6.5-decision-trace.sh --self-test`
**Review cadence:** Codex MCP dropped (slow/flaky); DMC `critic` (plan, APPROVE) + DMC `verifier` (build).

## Result — including the MANDATORY six-question E2E proof
```
self-test: 12 PASS / 0 FAIL   (D1 decision validate + contract · D2/D3 rationale/links · D4 E2E proof ·
                               D5 incomplete→REFUSE · D6 untraceable-link→REFUSE · D7 findings-empty→ANSWERED/cap-empty→REFUSE · D8)
D10 repo byte-unchanged after self-test (sentinel equal before==after)
```
**THE LAYER ANSWERS Q1–Q6 FROM ARTIFACTS ALONE, WITH NO MODEL MEMORY.** A live `--answer` on a complete trace returns:
- **Q1 (what capability)** = the `capability` register class (e.g. `frontier-long-horizon`) — v0.6.1
- **Q2 (what evidence)** = the `evidence` register ids — v0.6.2
- **Q3 (what findings remain)** = the `finding` register ids/states (or `"none"`) — v0.6.3
- **Q4 (what goal authorized)** = the `goal` register id (a v0.4.1 reference) — v0.6.4
- **Q5 (why)** = the `decision` register id + `rationale_class` — v0.6.5
- **Q6 (who approved release)** = the `approval` register id (a contract-enforced `human-release-gate` authorizer) — human gate
Any unanswerable question → `--answer` REFUSE. **The critical success metric of the roadmap is met at v0.6.5.**

## Assertion → requirement map
| ID | Asserts | Backs |
|----|---------|-------|
| D1 | a valid decision entry → VALID; base entry passes contract `--validate-entry decision` (producer v0.6.5) | Q5; contract fit |
| D2 | missing/prose `rationale_class` → REJECT | no undocumented decision |
| D3 | `links` missing a required key / non-token id → REJECT | rationale chain shape |
| D4 | **complete synthetic trace → ANSWERED with Q1–Q6 all present** | the mandatory six-question E2E proof |
| D5 | record fails the contract `--validate` (empty register, etc.) → REFUSE | completeness (contract-enforced) |
| D6 | a `decision.links.*` id not declared in the record → REFUSE | no untraceable approval / dangling rationale |
| D7 | findings empty → ANSWERED (Q3="none"); capability empty → REFUSE | valid-empty vs required-non-empty |
| D8 | duplicate JSON key / secret-shaped / malformed root → REJECT/REFUSE | fail-closed; value-blind |
| D9 | `env -i` + hostile credential var → identical verdict; `--validate`/`--answer` call no git | env-free / input-only |
| D10 | repo byte-unchanged after `--self-test`; `--out` write-safe (core + wrapper) | read-only |
| D11 | v0.6.1.0 (26/0) + v0.6.1 (7/0) + v0.6.2 (18/0) + v0.6.3 (25/0) + v0.6.4 (27/0) verifiers still green | regression budget |

## Honest scope
Input-only (no git): verifies decision *shape*, record *completeness* (via the committed contract), decision *link
resolution*, and *answerability*. It does **not** verify a human approval's *authenticity* or live-tree anchoring — upstream
(human Release Gate). Q6's approval is nonetheless guaranteed to be a `human-release-gate` entry (the contract rejects any other
`approval.type`/`source`), so a laundered critic/Codex ACCEPT cannot answer Q6.

## Safety posture
- Additive only (`.harness/schemas/decision-trace.schema.md`, `.harness/evidence/dmc-v0.6.5-decision-trace.{py,sh}`, this
  report). **No protected-surface change. No live/model/API call. No network. No `.env`/credential read.**
- Deterministic, env-free, input-only (no git), duplicate-key-rejecting, value-blind (reject-on-match), no-heredoc/no-temp,
  fail-closed, inert unless invoked, write-safe `--out`. **No undocumented decision, no untraceable approval, no invisible
  override, no answer from model memory.**

**Gate status:** built + verified on `dmc-control-plane/v0.6.1`. Critic stage: DMC critic APPROVE. Build audit recorded
separately. **Not pushed; MILESTONES not updated; no closure.** Push / main-FF / closure remain human gates.
