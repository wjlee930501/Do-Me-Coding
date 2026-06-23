# PLAN — v0.6.1 Capability-Class Router (DRAFT, Rev 2)

**Parent roadmap:** `.harness/plans/dmc-v0.6.1-v0.6.5-roadmap.md` (APPROVED). **Branch:** `dmc-control-plane/v0.6.1`.
**Depends on:** v0.6.1.0 Trace Linkage Contract (`.harness/schemas/trace-linkage.schema.md` + `--validate-entry`) — committed.
**Type:** schema + deterministic router/validator. **Additive, advisory, fail-closed, input-only, read-only**; no
protected-surface change, no live/model/API call, no `.env`/credential read, no network, no auto-apply, **no learned routing**.

**Rev 2 (2026-06-23):** incorporated the dual Critic gate (DMC critic APPROVE + Codex REVISE). Fixes: (1) routing is now
`(task_class, role) → capability_class` — Output 3's *orchestrator* column is always `frontier-long-horizon`, so a single
dimension was ambiguous; **role** disambiguates; (2) **task_class + role enums pinned byte-exact** (with the Output-3 label
mapping); (3) **duplicate-JSON-key rejection** on task facts; (4) **C6 validates the emitted fragment via the v0.6.1.0
`--validate-entry`** (not a full record — producers emit fragments); (5) demoted "reduces to v0.5.3" to "same
smallest-sufficient philosophy; authoritative source = Output 1/2/3."

**Purpose.** Answer **Q1 — "what capability performed this work?"** Select one of the six v0.6.0 capability classes from
**declared task facts `(task_class, role)`**, deterministically + visibly + explainably + model-agnostically, and persist a
subject-bound `capability_class` fragment that conforms to the trace-linkage contract. The selection rule is a **visible
deterministic table** — never a learned/dynamic scorer (anti-goal #8). Model names live ONLY in a separate dated lookup the
routing logic never reads.

---

## 1. Problem statement
DMC routing is implicit and model-aware. To survive model turnover (R4) and make Q1 answerable from artifacts, routing must
select a **capability class** (named by capability, never by model) from `(task_class, role)`, emit a human-readable
explanation + an auditable routing record, and persist a subject-bound `capability_class` fragment (v0.6.1.0). The
class→model mapping stays a **separate dated, replaceable lookup** (Output 2) the routing logic never references.

## 2. Non-goals
- **No learned routing / dynamic model scoring** (anti-goal #8); the table is static + visible.
- **No provider/model/API call, no network, no `.env`/credential read**; reads only the declared task-facts file/stdin.
- **No auto-switch / silent fallback** — every resolution is explicit + explained; unknown/missing input → REJECT.
- **No model name in routing logic** (structurally checked).
- **Not** implementing v0.6.2–v0.6.5; mints only a `capability_class` fragment.

## 3. Design
### 3.1 Inputs — declared task facts (one JSON object; input-only; duplicate-key-rejecting load)
```text
{ "task_class": "<one of the 7 pinned below>",
  "role":       "<one of the 5 pinned below>",
  "subject":    { "work_id","plan_hash"(hex≥16),"milestone_id","repo_hash"(hex≥16),"verification_ref" } }
```
**`task_class` enum (7, byte-exact; ⟶ Output-3 row):** `docs-only`(docs-only) · `additive-tool`(additive tool) ·
`provider-adapter`(provider adapter) · `protected-surface-change`(protected-surface change) ·
`security-secret-live-risk`(security/secret/live risk) · `release-closure`(release/closure) ·
`recovery-resume`(recovery/resume).
**`role` enum (5, byte-exact; ⟶ Output-1 role):** `orchestrator`(Strategic Orchestrator) · `implementer`(Implementer) ·
`critic`(Critic/Falsifier & Release Auditor) · `verifier`(Verifier) · `release`(Human Release Gate).
Duplicate JSON keys at any level, missing/unknown `task_class` or `role`, malformed/secret-shaped subject → REJECT.

### 3.2 Deterministic routing table `(task_class, role) → capability_class` (visible, explainable)
Derived from Output 1 (role contracts) + Output 2 (class↔role binding) + Output 3 (matrix):
- `role=orchestrator` → `frontier-long-horizon` (all task classes)
- `role=critic` → `adversarial-review`
- `role=verifier` → `deterministic-tool`
- `role=release` → `human-only-gate`
- `role=implementer` → `cheap-fast` **iff** `task_class=docs-only`, else `standard-implementation`

Only the `implementer` row depends on `task_class` (lighter lane for docs-only); all others are role-determined. Every
resolution names the rule that fired. The table is data; **no model name appears**. (Same smallest-sufficient-lane philosophy
as the v0.5.3 selector; authoritative source = Output 1/2/3, not a byte-reduction of v0.5.3.)

### 3.3 Outputs
- **Capability lookup registry** (`.harness/schemas/capability-routing.schema.md`): the `(task_class, role)→class` table +
  the separate **dated** class→model *illustrative* lookup (clearly non-load-bearing) + the provider-mapping policy
  (class→provider-class, data-only) + the routing-record shape. Cites Output 1/2/3.
- **Routing audit record** (`--out`, guarded): `{ inputs:{task_class, role}, resolved_capability_class, rule_fired,
  explanation, capability_entry }`.
- **Human-readable explanation**: "task_class=<X>, role=<Y> → capability_class=<Z> (rule: <…>); the class→model lookup is a
  separate dated table, not consulted by routing."
- **Persisted `capability_class` fragment** (carry-forward #1): `{kind:"capability_class", id:<Z>, producer_milestone_id:
  "v0.6.1", <subject-binding>}` — a durable, subject-bound Q1 receipt that passes the contract's `--validate-entry capability`.

### 3.4 Router behaviour (`.harness/evidence/dmc-v0.6.1-capability-router.{py,sh}`)
- `--route <facts.json|-> [--out <file>]` → resolve deterministically, print explanation, emit the routing record; fail-closed
  on unknown/missing/duplicate-key/malformed/secret. Reads only the input; **never calls git**; env-free; duplicate-key
  rejecting loader; value-blind reject-on-match on subject/free-form fields (v0.5.0 UNSAFE set); `out_refused()` on `--out`.
- `--self-test` → in-memory controls (below) + repo byte-unchanged; no-heredoc/no-temp `.py` core + thin `.sh` wrapper.

## 4. File scope (additive only)
| # | File | Contents |
|---|------|----------|
| 1 | `.harness/schemas/capability-routing.schema.md` | the `(task_class, role)→class` table + dated class→model lookup + provider-mapping policy + routing-record shape; cites Output 1/2/3. |
| 2 | `.harness/evidence/dmc-v0.6.1-capability-router.{py,sh}` | deterministic router (`--route`/`--self-test`), input-only, env-free, no-heredoc/no-temp, duplicate-key-rejecting, value-blind. |
| 3 | `.harness/verification/dmc-v0.6.1-capability-router.md` | verification report. |

Plus this plan. No other file touched.

## 5. Acceptance criteria (`--self-test`)
| ID | Assertion |
|----|-----------|
| C1 | every `(task_class, role)` over the 7×5 grid resolves to its table class (∈ the six), deterministically. |
| C2 | unknown/missing `task_class` or `role` → REJECT; malformed/secret-shaped subject → REJECT (fail-closed). |
| C2b | duplicate JSON key (e.g. duplicate `task_class`) at any level → REJECT (no last-key-wins downgrade). |
| C3 | **no model-name string in the routing logic** (structural scan of the operative `.py` source). |
| C4 | **model-swap invariance (success condition):** the routing function takes no model input and consults no class→model table — resolution for a given `(task_class, role)` is byte-identical regardless of the dated lookup's contents. |
| C5 | every resolution emits a human-readable explanation naming the rule that fired (no silent switch). |
| C6 | the emitted `capability_class` fragment passes the v0.6.1.0 contract `--validate-entry capability` (subject-bound, producer=v0.6.1, id ∈ six) — invoked in-memory/stdin (no temp). |
| C7 | determinism/env-free: `env -i` + hostile credential var → identical resolution; `--route` calls no git. |
| C8 | read-only: repo byte-unchanged after `--self-test`. |
| C9 | regression (carry-forward #3): `dmc-v0.6.1.0-trace-linkage.sh --self-test` → still 26/0. |
| Cneg | a negative control per reject rule (C2/C2b/C3) FAILs; the positive grid resolves — no false-green. |

## 6. Safety constraints
Additive only; no protected-surface change; no live/model/API/network/`.env`; deterministic + env-independent; value-blind;
advisory/fail-closed; inert unless `--route`/`--self-test`; **no learned routing, no dynamic scoring, no silent fallback, no
model name in routing logic**.

## 7. Regression budget
Before commit: re-run `dmc-v0.6.1.0-trace-linkage.sh --self-test` (expect 26/0).

## 8. Rollback
Additive on the feature branch: `git checkout -- <files>` before commit, or revert the additive commit. No protected surface,
no history rewrite, no force.

## 9. Approval status: **DRAFT (Rev 2) — Critic stage done (critic APPROVE + Codex REVISE incorporated)**
Per the lighter cadence (one critic + one Codex per gate; fix the REVISE, proceed), build now → verify (`--self-test`) →
**one** independent audit round (DMC verifier + Codex) → commit on `dmc-control-plane/v0.6.1`. Push / main-FF / closure remain
human-gated.
