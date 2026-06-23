# ROADMAP DECOMPOSITION — DMC v0.6.1–v0.6.5 Control-Plane Layer (DRAFT)

**Status:** DRAFT roadmap-decomposition. **NOT** an implementation plan for any single milestone, **NOT** approved, **NOT**
committed. First action of the v0.6.1–v0.6.5 roadmap. Each milestone below still requires its **own** full lifecycle
(Plan → Critic [+ Codex] → Approval → Build → Verify → Audit [+ Codex release audit] → Commit → Publish → Main → Closure).
This document only decomposes.

**Rev 2 (2026-06-23):** incorporated an **external Codex audit (verdict REVISE)** — added the foundational **v0.6.1.0 Trace
Linkage Contract** milestone (canonical subject binding), resolved a dependency-graph contradiction and a latent 6.2↔6.4
cycle, made the six-question E2E proof **mandatory in v0.6.5**, added a findings-gate pass/fail matrix, typed `approval_ref`
as a human-release authorization only, and added risks R9–R12. See §7.

**Anchored to v0.6.0 (`ded4636` on `main`).** Core conclusion carried forward: **"Learn suggestions, encode gates."** The
objective is **not** automation. The objective is **explicit orchestration · evidence-backed completion · deterministic
gatekeeping · human release authority.** DMC remains *a visible control plane for bounded AI agents*; never optimize for
autonomy at the expense of visibility.

---

## 0. What this layer must achieve — the six-question metric

At v0.6.5, DMC must answer these **deterministically, without relying on model memory.** Each question maps to one milestone:

| # | Question | Answered by | Capability class involved |
|---|----------|-------------|---------------------------|
| Q1 | What capability performed this work? | **v0.6.1** Capability-Class Router | (the router itself) |
| Q2 | What evidence supports completion? | **v0.6.2** Evidence Receipt Gate | `deterministic-tool` |
| Q3 | What findings remain? | **v0.6.3** Findings Gate | `deterministic-tool` |
| Q4 | What goal authorized the work? | **v0.6.4** Goal Ledger | `deterministic-tool` |
| Q5 | Why was the decision made? | **v0.6.5** Decision Traceability Layer | `deterministic-tool` |
| Q6 | Who approved release? | existing **Human Release Gate** (v0.4 charter / C11), **traced by v0.6.5** via a typed `approval_ref` | `human-only-gate` |

Q6 needs **no new milestone** — the Human Release Gate already exists and is mandatory; v0.6.5 makes its authorization
*traceable* through a typed `approval_ref` (a human release authorization only — never a critic/Codex/plan ACCEPT; see R12).
If the chain Q1→Q6 cannot be reconstructed from artifacts alone, the roadmap is incomplete.

---

## 1. Milestone dependency graph

Each milestone is an **additive, advisory/deterministic** tool-set (schema + collector/registry + validator + fail-closed
gate-checker + read-only verifier with `--self-test`), in the shipped v0.2.6 / v0.3.7 / v0.5.x style. No milestone mutates a
protected surface, calls a provider/model, reads `.env`, or auto-applies/releases.

```
              v0.6.0  (taxonomy: capability classes, roles, anti-goals)  [DONE @ ded4636]
                 │
                 ▼
         v0.6.1.0  Trace Linkage Contract   (shared schema: canonical subject binding + all cross-milestone IDs)
                 │
     ┌───────────┴───────────────┐
     ▼                           ▼
 v0.6.1                      v0.6.2
 Capability-Class Router     Evidence Receipt Gate
 (depends on 6.1.0)          (spine; depends on 6.1.0; records a PREEXISTING goal_id from v0.4.1, NOT 6.4)
     │                           │
     │                           ▼
     │                       v0.6.3
     │                       Findings Gate    (finding resolution is evidence-backed → needs 6.2)
     │                           │
     │                           ▼
     │                       v0.6.4
     │                       Goal Ledger       (OWNS goal_state; aggregates evidence + findings → needs 6.2, 6.3)
     │                           │
     └───────────┬───────────────┘
                 ▼
             v0.6.5
             Decision Traceability Layer
             (capstone: links capability + evidence + finding + goal + verification + approval + release
              → needs 6.1, 6.2, 6.3, 6.4 + the existing Human Release Gate)
```

**Edges:** `6.0→6.1.0`, `6.1.0→6.1`, `6.1.0→6.2`, `6.2→6.3`, `6.2→6.4`, `6.3→6.4`, `{6.1,6.2,6.3,6.4}→6.5`.
**Foundational root:** **v0.6.1.0** (the Trace Linkage Contract) — both 6.1 and 6.2 depend on it; gated independently.
**Acyclicity:** the present `6.2→6.4` edge means **6.4 depends on 6.2** (the ledger aggregates evidence). The potential cycle
would be the reverse — 6.2 depending on 6.4 — and there is **no `6.4→6.2` edge**: 6.2 records only a **preexisting** `goal_id`
(the **v0.4.1 goal-plan** schema) while 6.4 *owns/validates* `goal_state`, so **6.2 does not depend on 6.4**. The graph is a
DAG (no cycle).
**Capstone:** v0.6.5 depends transitively on all.

### 1.1 Trace Linkage Contract — v0.6.1.0 (foundational shared schema; pinned BEFORE 6.1/6.2 build)
The six-question metric only works if artifacts share **stable IDs bound to one canonical subject**, so v0.6.5 can chain them
and **cannot** assemble valid-but-unrelated IDs into a false trace. This is the top architectural risk (R1/R9) and is its own
independently-gated milestone (`.harness/schemas/trace-linkage.schema.md`), depended on by both 6.1 and 6.2.

**Canonical subject binding (every artifact carries it; every linkage edge must bind the SAME subject):**
- `work_id` / `run_id` — the canonical work item this artifact belongs to.
- `plan_hash` — hash of the approved plan authorizing the work.
- `milestone_id` — which milestone produced the artifact.
- `repo_hash` / `commit` — head / working-tree binding (env-free, like the v0.6.0 `repo_hash`).
- `verification_ref` — hash/path of the verification report for the work.

**Cross-milestone IDs (each opaque, value-blind, env-free; each edge re-binds the canonical subject):**
- `capability_class` (enum from v0.6.0 Output 2) — emitted by 6.1.
- `evidence_receipt_id` — minted by 6.2; referenced by 6.3 (finding→evidence), 6.4 (goal→evidence), 6.5 (decision→evidence).
- `goal_id` — a **preexisting** reference to the existing **v0.4.1 goal-plan** schema; **6.2 records only the syntactic
  reference**, **6.4 owns/validates `goal_state`** (this separation keeps 6.2 independent of 6.4 — no cycle).
- `finding_id` + `finding_state ∈ {resolved, accepted-risk, deferred, blocked}` — 6.3; referenced by 6.4, 6.5.
- `decision_id` — 6.5.
- `approval_ref` — a **typed Human Release Gate authorization** (an explicit human release authorization — **never** a
  critic/Codex ACCEPT or a plan approval); consumed by 6.5 to answer Q6.

**Referential-integrity rule:** every linkage (decision→evidence→finding→goal→verification→approval→release) must resolve to
artifacts sharing the same `work_id` + compatible `repo_hash`; a dangling, duplicate, cross-subject, or stale link is a
**FAIL** (R9–R12). IDs are minted deterministically (content hash over the canonical subject + local fields), never reused.

---

## 2. Risk analysis

### Cross-cutting risks
- **R1 — schema drift / non-composing IDs (HIGH).** Without the §1.1 contract, v0.6.5 cannot trace Q1→Q6. *Mitigation:* the
  contract is its own first milestone (v0.6.1.0); every later verifier asserts conformance.
- **R2 — gate becomes hidden enforcement, not visible gate (HIGH, identity risk).** *Mitigation:* each gate is a
  **deterministic, fail-closed CHECKER** the v0.5.4 DONE-evaluator and the human Release Gate honor — it reports PASS/FAIL on
  inspectable artifacts; it never silently blocks or auto-acts. The runtime enforcement floor stays the hooks.
- **R3 — learned-routing temptation (HIGH, anti-goal #8).** *Mitigation:* routing is a pure function of declared task facts
  (`env -i` byte-identity); no model call; no dynamic scoring; restated + verifier-checked per milestone.
- **R4 — scope creep into runtime / protected surface (HIGH).** *Mitigation:* additive only
  (`docs/*`, `.harness/{schemas,evidence,verification}/*`); no protected-surface edit; no live/model/network/`.env`;
  no auto-apply; v0.4.3 scope guard + v0.4.5 secret/network/live guard discipline.
- **R5 — append-only / immutability not enforced (MED).** 6.4 & 6.5 must be append-only (MILESTONES-style). *Mitigation:*
  append-only validator with negative controls per milestone.
- **R6 — secret-shaped / value leakage into ledgers & traces (MED).** *Mitigation:* reuse v0.5.0 value-blind redactor;
  verifiers assert no secret-shaped strings (v0.6.0 V12 pattern).
- **R7 — false-green gates (MED).** *Mitigation:* every verifier ships negative controls / self-tests (v0.6.0 ST pattern)
  proving it can FAIL.
- **R8 — "machine-verifiable where possible" over-promised (LOW/MED).** *Mitigation:* 6.2 classifies evidence as
  machine-verifiable vs human-attested, with an honest "known-shapes-only, not a completeness guarantee" attestation (v0.4.4).
- **R9 — referential-integrity / false-trace assembly (HIGH).** Valid IDs from unrelated artifacts stitched into a false
  trace. *Mitigation:* §1.1 canonical subject binding; every edge re-binds the same `work_id`+`repo_hash`; v0.6.5 verifier
  FAILs any cross-subject or dangling link.
- **R10 — stale-artifact replay (MED).** An old evidence receipt / approval reused for a new completion. *Mitigation:* bind
  `repo_hash`/`commit` + `verification_ref` to the current work; the gate rejects an artifact whose subject binding ≠ the
  current `work_id`/head.
- **R11 — duplicate ID collision (MED).** Two artifacts mint the same ID. *Mitigation:* content-hash minting over the
  canonical subject + local fields; per-register uniqueness asserted.
- **R12 — approval-ref laundering (HIGH, identity risk).** A critic/Codex/plan ACCEPT passed off as a release approval.
  *Mitigation:* `approval_ref` is a typed Human Release Gate authorization only; 6.5 FAILs any `approval_ref` not of that
  type — an internal/external audit ACCEPT is advisory input, never an approval (C11).

### Per-milestone signature risks
- **v0.6.1.0:** an under-specified subject binding that still allows a false trace (R9) — the schema must make every edge
  re-bind the subject, not merely carry an ID.
- **v0.6.1:** masking provenance behind a facade (carry Card-23 mitigation: log resolved class+provider); model-name leakage
  into routing logic (R3).
- **v0.6.2:** trusting model prose / self-reported completion — the validator must reject prose-only and require an
  inspectable artifact path; receipt records only a *syntactic* `goal_id` (no 6.4 dependency).
- **v0.6.3:** silent/dropped findings — assert `findings_in == findings_classified`; enforce the §4 pass/fail matrix; waivers
  explicit + human-attributed via `approval_ref`.
- **v0.6.4:** goal drift / retroactive edit — immutable append-only history is load-bearing.
- **v0.6.5:** untraceable approval / invisible override — FAIL on any approval lacking a typed Human-Release-Gate
  `approval_ref` (R12), or any cross-subject link (R9).

---

## 3. Recommended implementation order

**Primary order `6.1.0 → 6.1 → 6.2 → 6.3 → 6.4 → 6.5`** — a valid topological sort of §1, matching the six-question build-up:

0. **v0.6.1.0 Trace Linkage Contract first** — the foundational shared schema (§1.1) both 6.1 and 6.2 depend on; gated
   independently so the canonical subject binding + IDs are reviewed before any producer is built. De-risks R1/R9–R12.
1. **v0.6.1** — capability-class registry + router; depends on 6.1.0. Simplest producer; sets the layer's conventions.
2. **v0.6.2** — the **evidence spine**; mints `evidence_receipt_id`; records a preexisting `goal_id` (v0.4.1), not 6.4.
3. **v0.6.3** — findings reference evidence (needs 6.2).
4. **v0.6.4** — goals aggregate evidence + findings; owns `goal_state` (needs 6.2, 6.3).
5. **v0.6.5** — capstone; links all + the existing approval/release gate; **its success gate MUST include the mandatory
   offline six-question proof** (below).

**Six-question proof is MANDATORY in v0.6.5** (not optional, not deferred): v0.6.5's success gate runs an offline compose over
synthetic scenarios proving Q1–Q6 are answerable from artifacts alone with **no model memory** — the critical metric is met
*at v0.6.5*. An **optional v0.6.6** may only *harden / regression-test* that suite; it may **not** be the first milestone to
prove the metric.

**Parallelism note:** with 6.1.0 extracted, 6.1 and 6.2 depend only on 6.1.0 and are independent of each other (could swap);
DMC executes one milestone at a time regardless.

---

## 4. Verification strategy

**Per-milestone (uniform pattern, reused from v0.6.0):** one additive, read-only, env-free, deterministic verifier with an
embedded `--self-test`, inert unless flag-invoked, content-sensitive `repo_hash` (real repo byte-unchanged), with negative
controls (ST-style) proving the checker can FAIL. Each asserts its milestone's **success condition**:

| Milestone | Key deterministic assertions (the success condition made testable) |
|-----------|---------------------------------------------------------------------|
| v0.6.1.0 | the schema defines the canonical subject binding (`work_id`/`run_id`, `plan_hash`, `milestone_id`, `repo_hash`/commit, `verification_ref`) + all cross-milestone IDs; minting is deterministic + value-blind; a referential-integrity check FAILs on dangling / duplicate / cross-subject / stale links. |
| v0.6.1 | route = pure function of declared task facts → capability class (`env -i` byte-identical); **no model-name string in routing logic**; human-readable route explanation emitted; **swapping the model lookup leaves routing logic byte-identical** (success condition); resolved class+provider logged for provenance. |
| v0.6.2 | DONE/E2E-complete is **refused** unless an evidence receipt is present + inspectable (artifact path resolves) + traceable (binds the canonical subject + a syntactic `goal_id`); evidence-type validation (machine-verifiable vs human-attested tagged); prose-only / self-reported completion → REJECT. |
| v0.6.3 | every finding carries a state ∈ {resolved, accepted-risk, deferred, blocked}; **`findings_in == findings_classified`** (no drop/dup); unknown/missing → FAIL. **Release pass/fail matrix:** `resolved` requires a linked `evidence_receipt_id`; `accepted-risk` requires an explicit human waiver bound to an `approval_ref`; `deferred` requires owner + target + explicit release policy; **`blocked` fails release**. Negative controls: dropped, duplicated, state-changed, and waiverless findings each FAIL. |
| v0.6.4 | ledger is **append-only** (rewrite / delete / retroactive-edit → FAIL, MILESTONES-style, hash-chained); every completion references a valid `goal_id`; 6.4 owns `goal_state`; immutable history. |
| v0.6.5 | every major action has a complete chain decision→evidence→finding→goal→verification→approval→release, **all edges binding the same `work_id`+`repo_hash`** (R9); **no approval without a typed Human-Release-Gate `approval_ref`** (R12); **MANDATORY: Q1–Q6 answerable from the trace alone, proven by the offline compose suite** (the critical metric, met at v0.6.5). |

**Roadmap-level acceptance:** the §0 six-question metric is the global gate, proven **mandatorily at v0.6.5** by an offline
compose over synthetic scenarios (Q1–Q6 answerable from artifacts alone, no model memory). An optional v0.6.6 only
hardens / regression-tests it. Each milestone also re-runs every prior milestone's verifier on its published `main`
(regression).

**Independent review (incl. external Codex audit — standing DMC method):** each milestone keeps authoring and review in
separate lanes. The **Critic** stage runs the DMC `critic` agent **and** an external **Codex plan-review**. The **Audit**
stage runs an independent multi-lens release audit on the build (v0.6.0 pattern) **plus an external Codex release audit** —
**both must return ACCEPT before commit**, mirroring every shipped v0.2–v0.5 stack (each passed an independent Codex/Kim
release audit before publication, recorded in `docs/MILESTONES.md`). Codex is invoked at *each* gate where an external check
adds confidence (plan-review and pre-commit release audit), **never as a release grant** — its ACCEPT is advisory input to the
Human Release Gate (C11). The critic + Codex for *this roadmap* should specifically stress-test §1.1 (linkage contract),
R1/R2/R3/R9/R12, and the §3 order.

---

## 5. Recommended milestone boundaries

- **Make the Trace Linkage Contract its own independently-gated milestone, v0.6.1.0** (`.harness/schemas/trace-linkage.schema.md`),
  depended on by both 6.1 and 6.2. It carries the canonical subject binding (§1.1) + the referential-integrity rule. This is
  the boundary refinement that de-risks R1/R9–R12; without it the milestones don't compose and a false trace is assemblable.
- **Keep the 5 primary milestones (6.1–6.5).** Each delivers one of the six answers and one coherent tool-set; each is
  independently shippable and independently gated. No milestone bundles two concerns.
- **The six-question E2E proof is MANDATORY in v0.6.5** (§3/§4), not optional. An **optional v0.6.6** may only
  harden / regression-test that suite (consistent with v0.3.9 / v0.5.9), never be the first to prove the metric.
- **Do not create a milestone for Q6 (approval).** The Human Release Gate already exists (v0.4 charter, C11); v0.6.5 traces it
  **via a typed `approval_ref` that is a human release authorization only — never a critic/Codex/plan ACCEPT** (R12). An
  "approval milestone" would duplicate shipped enforcement.
- **Each milestone deliverable set (boundary template):** `<schema>.md` · `<collector|registry|ledger>.sh` (writes only
  canonicalized `--out`, never the repo) · `<validator>.{sh,py}` (fail-closed) · `<gate-checker>.sh` (advisory, composes with
  the v0.5.4 DONE-evaluator) · `<verify>.sh --self-test` · `<verification>.md`. All additive; protected surface untouched.

---

## 6. Global rules (carried into every milestone plan)

Never modify (unless explicitly approved per-milestone): protected surfaces, provider adapters, `provider-router`,
`.claude/hooks/*`, schemas under protection, guards, validators. **No live provider calls. No model API calls. No `.env` /
credential access. No auto-apply. No autonomous release / push / closure.** The **Human Release Gate remains mandatory**, and
`approval_ref` (Q6) is *only* a human release authorization. v0.6.0 anti-goals (esp. *no opaque learned routing as gate
authority*, *no self-reported benchmark as verified*) carry forward. Every milestone is **advisory/deterministic, fail-closed,
inert-unless-invoked**, like v0.1–v0.5. Every milestone's Critic and Audit gates include an **external Codex pass** (ACCEPT
required before commit; advisory, never a grant).

---

## 7. Approval status: **APPROVED (Rev 2)** — Critic stage complete (Codex ACCEPT + DMC critic APPROVE); bounded-batch human authorization

**Rev 2 changes** (from the Codex REVISE, 2026-06-23): (1) added the foundational **v0.6.1.0 Trace Linkage Contract**
milestone, resolving the dependency-graph contradiction and the latent 6.2↔6.4 cycle (6.2 records a *preexisting* `goal_id`;
6.4 owns `goal_state`); (2) strengthened §1.1 with a **canonical subject binding** so the six-question trace cannot be forged
from unrelated IDs; (3) made the **six-question E2E proof mandatory in v0.6.5** (optional v0.6.6 = hardening only); (4) added a
**findings-gate pass/fail matrix** + negative controls (§4); (5) typed `approval_ref` as a **human release authorization
only** (R12); (6) added risks **R9–R12**.

**Critic stage COMPLETE (2026-06-23):** external **Codex audit = ACCEPT** (REVISE → fixed 5 blockers → REVISE (1 graph-wording
bug) → fixed → ACCEPT; Codex thread `019ef2df…`) **and** DMC `critic` agent = **APPROVE** (0 blockers, all 6 lenses PASS;
independently verified `goal_id` is a preexisting v0.4.1 field, so the 6.2↔6.4 cycle-break is real). **Approved under
bounded-batch human authorization** — the user authorized autonomous continuation under the established DMC patterns; C11 is
satisfied by an explicit bounded-batch scope, not inferred from a critic PASS.

**Carry-forward refinements for downstream milestone plans (DMC critic, non-blocking):** (1) **v0.6.1** must persist a durable
per-work `capability_class` artifact bound to the canonical subject (Q1 needs a traceable receipt, not a transient compute);
(2) **v0.6.2 / v0.6.3** registers (`evidence_receipt_id` / `finding_id`) should be append-only too, anchoring stale-replay
rejection (R10); (3) the "re-run every prior verifier on `main`" regression promise must be explicitly budgeted in each
milestone plan.

**Next:** execute **v0.6.1.0 (Trace Linkage Contract)** under its own full lifecycle on branch `dmc-control-plane/v0.6.1`. No
stage bypassed; **no commit without the internal audit AND the external Codex audit both at ACCEPT**; push / main-FF / closure
follow the established human-gated pattern.
