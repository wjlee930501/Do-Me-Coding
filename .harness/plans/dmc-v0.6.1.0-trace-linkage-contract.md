# PLAN — v0.6.1.0 Trace Linkage Contract (DRAFT, Rev 2)

**Parent roadmap:** `.harness/plans/dmc-v0.6.1-v0.6.5-roadmap.md` (APPROVED Rev 2). **Branch:** `dmc-control-plane/v0.6.1`.
**Type:** foundational schema + deterministic validator milestone. **Additive, advisory, fail-closed, read-only**; no
protected-surface change, no live/model/API call, no `.env`/credential read, no network, no auto-apply.

**Rev 2 (2026-06-23):** incorporated the dual Critic stage (DMC `critic` = NEEDS CLARIFICATION + Codex = REVISE, convergent
core finding). Reworked §3 so **every reference is a typed, subject-bound register entry** and **edges use typed endpoints**,
closing the false-trace-assembly gap (R9). Added per-reference `producer_milestone_id`, global `(kind,id)` uniqueness,
subject-bound + source-constrained `approval_ref` (R12), duplicate-JSON-key rejection, a recursive secret scan, explicit
input-only scoping of staleness (no git in `--validate`), and a regression-budget line. See §10.

**Purpose.** Pin the **canonical subject binding** and the **typed, subject-bound cross-milestone reference contract** so the
later gates (v0.6.1–v0.6.5) compose into one auditable trace, the six-question metric (Q1–Q6) is answerable from artifacts
alone, and a valid-but-unrelated set of IDs **cannot** be assembled into a false trace. Shared dependency of v0.6.1 and
v0.6.2 (roadmap §1), gated first to de-risk R1/R9–R12.

---

## 1. Problem statement
v0.6.1–v0.6.5 each mint local references. Without a contract that binds every artifact to **one canonical subject** and forces
**every reference and every linkage edge** to carry + match that subject, v0.6.5 cannot deterministically reconstruct the
chain and unrelated artifacts could be stitched into a plausible-but-false trace. v0.6.1.0 defines that contract and ships a
deterministic, input-only, fail-closed validator.

## 2. Non-goals
- **Not** implementing any of v0.6.1–v0.6.5 (no router, no evidence/findings/goal/decision gates); **not** minting real IDs.
- **Not** reading the live repo/env to judge a record — the validator reads **only the record it is given** (deterministic,
  env-free, input-only). **`--validate` never calls git.** Current-head *staleness/replay* vs the live tree is **out of scope**
  for this input-only contract and is deferred to the producer validators (6.2+) that run in-context (see §3, Codex finding 4).
- **Not** a runtime/enforcement change — advisory, fail-closed CHECKER; runtime floor stays the hooks.
- **Not** touching any protected surface, provider adapter, router, hook, schema-under-protection, guard, or validator.

## 3. Design
A **trace-linkage record** (one JSON object, `dmc.trace-linkage.v1`) describes one work item's trace: a canonical `subject`,
typed reference `registers` (each entry subject-bound), and typed `edges`. The validator enforces schema + referential
integrity deterministically and input-only.

### 3.1 Record shape
```text
{
  "schema": "dmc.trace-linkage.v1",
  "subject": {                         # the ONE canonical subject of this record (required, all fields)
    "work_id":          "<opaque>",    # value-blind
    "plan_hash":        "<hash-shaped>",
    "milestone_id":     "<this record's milestone, e.g. v0.6.1.0>",
    "repo_hash":        "<hash-shaped>",
    "verification_ref": "<ref-shaped>"
  },
  "registers": {                       # typed reference registers; EACH entry re-binds the subject
    "capability": [ {"kind":"capability_class","id":"<one of the six v0.6.0 classes>","producer_milestone_id":"v0.6.1", <subject-binding>} ],
    "evidence":   [ {"kind":"evidence_receipt","id":"<opaque>","producer_milestone_id":"v0.6.2", <subject-binding>} ],
    "finding":    [ {"kind":"finding","id":"<opaque>","state":"resolved|accepted-risk|deferred|blocked","producer_milestone_id":"v0.6.3", <subject-binding>} ],
    "goal":       [ {"kind":"goal","id":"<preexisting v0.4.1 goal_id>","producer_milestone_id":"v0.4.1", <subject-binding>} ],
    "decision":   [ {"kind":"decision","id":"<opaque>","producer_milestone_id":"v0.6.5", <subject-binding>} ],
    "approval":   [ {"kind":"approval","id":"<opaque>","type":"human-release-gate","source":"human-release-gate:<authorization-id>","producer_milestone_id":"human-release-gate", <subject-binding>} ]
  },
  "edges": [ {"from":{"kind":"<k>","id":"<i>"}, "to":{"kind":"<k>","id":"<i>"}} ]   # typed endpoints
}
```
where `<subject-binding>` on each register entry = its own `work_id`, `plan_hash`, `repo_hash`, `verification_ref`.

**ID shape (not minting):** every `id`/`*_hash`/`*_ref` is an opaque, value-blind token; later producers mint them as a
content hash over the canonical subject + local fields (roadmap §1.1). v0.6.1.0 validates *shape + binding*, not minting.

### 3.2 Validator behaviour (`.harness/evidence/dmc-v0.6.1.0-trace-linkage.sh`)
- `--validate <record.json>` → fail-closed: exit 0 valid, 1 invalid, 2 usage/refused. Reads **only** the file given;
  **never calls git**; env-independent.
- `--self-test` → positive fixture VALID + a negative control for each reject rule (§5 Tneg) + proves repo byte-unchanged.
- Deterministic, env-free; `repo_hash()` (`git status --porcelain | python3 hashlib`, env-free) is used **only inside
  `--self-test`** as the byte-unchanged sentinel — never to judge an input record.
- JSON is parsed with a **duplicate-key-rejecting loader** (`object_pairs_hook`): any duplicate key at any object level →
  REJECT (fail-closed determinism; Codex finding 6).
- **Reject-on-match secret scan** (no sanitized output): any secret-shaped string found by a **recursive** scan over all
  keys, values, nested objects, arrays, `edges[].{from,to}`, and `approval[].{source,id}` → REJECT (reuse the v0.5.0 UNSAFE
  shape set). This validator rejects; it does not emit a redacted artifact.
- `out_refused()` write-safety reused only if an optional `--out` echo is offered (canonicalized; refuse
  protected/in-tree/symlink/`.env`).

## 4. File-level scope (additive only)
| # | File | Contents |
|---|------|----------|
| 1 | `.harness/schemas/trace-linkage.schema.md` | the `dmc.trace-linkage.v1` schema: subject binding + **typed subject-bound registers** + typed edges + the referential-integrity rules (incl. the per-reference re-bind rule) + the **verbatim `kind`→`producer_milestone_id` table** (capability→v0.6.1 · evidence→v0.6.2 · finding→v0.6.3 · goal→v0.4.1 · decision→v0.6.5 · approval→human-release-gate) + the **allowed `approval.source` prefix `human-release-gate:`** + the reject-on-match value-blind note. Cites roadmap §1.1. |
| 2 | `.harness/evidence/dmc-v0.6.1.0-trace-linkage.{sh,py}` | the fail-closed, input-only validator — a thin **no-heredoc** `.sh` wrapper over a `.py` core so it runs in a **no-temp/read-only sandbox** + `--self-test` (in-memory positive fixture + a negative control per reject rule), env-free, duplicate-key-rejecting, recursive value-blind reject. |
| 3 | `.harness/verification/dmc-v0.6.1.0-trace-linkage-contract.md` | verification report (command, PASS/FAIL, assertion→requirement map, "advisory, not enforcement" line). |

Plus this plan file. No other file is touched.

## 5. Acceptance criteria / verification matrix (the validator's `--self-test` asserts these)
| ID | Assertion |
|----|-----------|
| T1 | a well-formed record (subject + ≥1 typed register entry + typed edges + `approval.type=human-release-gate`, all subject-bound) → VALID (exit 0). |
| T2 | a missing/empty subject field (`work_id`/`plan_hash`/`milestone_id`/`repo_hash`/`verification_ref`) → REJECT (R1). |
| T2b | `plan_hash`/`repo_hash` not hash-shaped, or `verification_ref` empty/non-ref-shaped → REJECT (B2). |
| T3 | a register entry whose `work_id` ≠ the subject's `work_id` (cross-subject) → REJECT (R9, the core false-trace defense). |
| T3b | a register entry whose `plan_hash`/`repo_hash`/`verification_ref` ≠ the subject's → REJECT (R9/R10, per-reference re-bind). |
| T4 | internal `repo_hash` inconsistency between subject and any entry/edge → REJECT (internal consistency only; live-head staleness is explicitly out of scope, §2). |
| T5 | a duplicate `(kind,id)` across ALL registers (global namespace) → REJECT (R11; Codex 3). |
| T6 | an edge endpoint `{kind,id}` not declared in the registers (dangling) → REJECT (R9). |
| T6b | an edge endpoint `kind` mismatching the register the `id` lives in (type confusion) → REJECT (Codex 3). |
| T7 | `approval.type` ≠ `human-release-gate` → REJECT (R12). |
| T7b | `approval` from a foreign subject (`work_id` ≠ subject) → REJECT (R9×R12 seam; DMC B3). |
| T7c | `approval.source` not matching the **exact allowed positive namespace prefix `human-release-gate:`** (an allowlist, NOT a denylist) → REJECT — so an arbitrary non-human source (e.g. `codex-accept-…`, a critic id, or any unrecognized string) fails closed (R12 laundering; Codex 5). Negative control: `type=human-release-gate` but `source` arbitrary non-human → REJECT. |
| T8 | a register `producer_milestone_id` not matching the expected producer for its `kind` (e.g. evidence not from v0.6.2) → REJECT (Codex 2). |
| T9 | `capability_class` id not in the six v0.6.0 classes; `finding.state` not in the four states → REJECT. |
| T10 | a secret-shaped string in ANY field (recursive: keys/values/nested/arrays/edges/approval) → REJECT (R6). |
| T11 | a duplicate JSON key at any object level → REJECT (fail-closed determinism; Codex 6). |
| T12 | determinism: `env -i` + a hostile credential var present yields the **same verdict+exit** on the same input (mirrors v0.5.0 AC4 — verdict/exit, not a rich artifact); `--validate` calls no git. |
| T13 | read-only: validator writes nothing to the repo; `repo_hash` before == after `--self-test`. |
| T14 | the schema doc (file #1) names the five subject-binding fields, the six classes, the four finding states, **the per-reference/edge re-bind rule, the `kind`→`producer_milestone_id` table, and the allowed `approval.source` prefix** (structure check; prevents doc↔validator drift). |
| T15 | a record missing any register key, or with an empty answer-bearing register (`capability`/`evidence`/`goal`/`decision`/`approval`), or no approval → REJECT (**completeness**: a VALID record is a complete trace answering Q1/Q2/Q4/Q5/Q6; `finding` may be empty). |
| Tneg | a crafted-bad record for each reject rule (T2–T15) MUST FAIL and the positive fixture MUST PASS — negative controls prove no false-green. |

## 6. Safety constraints
- Additive only (`.harness/{schemas,evidence,verification}/*` + this plan); **no protected-surface change**.
- **No live/model/API call. No network. No `.env`/credential read. `--validate` calls no git.** Reads only the record given.
- Deterministic + env-independent (`env -i` identical verdict). Reject-on-match value-blind (no secret-shaped string survives;
  no sanitized output emitted).
- Advisory/fail-closed, inert unless `--validate`/`--self-test` invoked; asserts only the input record's internal consistency.

## 7. Regression budget (roadmap carry-forward #3)
Re-run every prior v0.6.x-layer verifier on the branch before commit. **As the first milestone in the layer, none exist yet —
budgeted as a no-op; each subsequent milestone adds its predecessors.**

## 8. Regression risks & mitigations
- **R(local)1 — over-coupling to the live repo.** Mitigation: input-only; `--validate` never calls git; integrity is internal
  (entries/edges re-bind the record's own subject); live-head staleness explicitly deferred (§2).
- **R(local)2 — false-green validator.** Mitigation: `Tneg` negative control per reject rule proves it can FAIL.
- **R(local)3 — secret leakage into a trace record.** Mitigation: T10 recursive value-blind reject + the v0.5.0 shape set.
- **R(local)4 — schema↔validator drift.** Mitigation: T14 structure check names the load-bearing re-bind rule in the doc.
- **R(local)5 — parser-dependent acceptance.** Mitigation: T11 duplicate-key-rejecting loader.

## 9. Rollback
Additive on a feature branch: rollback = `git checkout -- <files>` before commit, or revert the single additive commit. No
protected surface, no history rewrite, no force.

## 10. Approval status: **DRAFT (Rev 2) — re-route to Critic ( DMC `critic` + external Codex )**
Rev 2 closes the dual-Critic blocking findings (typed subject-bound registers + typed edges per-reference re-bind [DMC B1 /
Codex 1]; per-reference provenance [Codex 2]; global uniqueness + typed endpoints [Codex 3]; staleness scoped input-only
[Codex 4/7]; subject-bound + source-constrained approval [DMC B3 / Codex 5]; duplicate-key rejection [Codex 6];
`plan_hash`/`verification_ref` integrity [DMC B2]; recursive secret scan; regression-budget line). **Rev 2.1:** `approval.source`
changed from a denylist to a **positive allowlist** (`human-release-gate:` prefix) closing Codex item 5; the producer table +
approval-source prefix are pinned verbatim in the schema doc (T14, DMC non-blocking). Do not build until BOTH the DMC `critic`
and the external Codex audit return ACCEPT — and note the build/commit gates are honored separately under C11 (a critic/Codex
ACCEPT is advisory, never an approval).

**Rev 2.2 (build-audit findings):** the independent multi-lens + Codex *release* audit closed two build findings — (a) the
validator core moved to an adjacent `.py` with a thin no-heredoc `.sh` wrapper and an **in-memory** self-test, so it runs in a
no-temp/read-only sandbox (Codex build-finding 1); (b) added the **completeness rule (T15)** so an empty/approval-less record
is REJECTED rather than VALID — a "valid" trace must answer Q1/Q2/Q4/Q5/Q6 (Codex build-finding 2 / DMC-verifier note). Then build →
verify (`--self-test`) → independent multi-lens audit + Codex release audit (both ACCEPT) → commit on
`dmc-control-plane/v0.6.1`. Push / main-FF / closure remain human-gated.
