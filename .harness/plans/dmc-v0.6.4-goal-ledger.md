# PLAN — v0.6.4 Goal Ledger (DRAFT)

**Parent roadmap:** `.harness/plans/dmc-v0.6.1-v0.6.5-roadmap.md` (APPROVED). **Branch:** `dmc-control-plane/v0.6.1`.
**Depends on:** v0.6.1.0 contract (`--validate-entry goal` / `--validate-entry approval`); `goal_id` is a **preexisting v0.4.1
goal-plan** reference (the contract binds `goal` entries to producer `v0.4.1`).
**Type:** schema + deterministic validator + state-machine + append-only ledger + completion-traces-to-goal check. **Additive,
advisory, fail-closed, input-only, read-only**; no protected-surface change, no live/model/API/`.env`/network, no auto-apply.

**Review cadence (2026-06-24):** Codex MCP dropped (slow/flaky); **DMC `critic` (plan) + DMC `verifier` (build) only.**

**Rev 2 (2026-06-24):** incorporated the DMC critic REVISE. Fixes: (B1) added the coupled authoritative **`--authorize` =
append-check(prev→next) AND trace(next, completion)** so a completion can't be authorized against a rewritten/truncated
ledger that bare `--trace` would accept (mirrors v0.6.3 `--release`); `--trace` itself rejects duplicate `(goal_id,seq)`;
the approved-in-history check is a **full-history scan**; (B2) the ledger entry is `producer=v0.6.4`/`entry_kind=goal_ledger`
carrying a **bare `goal_id` reference** (NOT a contract `goal` entry — G1 corrected); terminal-state transitions tested;
reuse v0.6.3 `out_unsafe` verbatim.

**Purpose.** Answer **Q4 — "what goal authorized the work?"** Make goals **persistent + auditable** with an **append-only,
immutable-history** ledger and a goal **state machine**, so **every completion traces to an authorized goal** and goals can't
drift, be rewritten, or have history deleted.

---

## 1. Problem statement
Agent memory is unreliable; goals drift, get silently re-scoped, or completions appear with no authorizing goal. v0.6.4 records
each goal's state as **append-only ledger entries** (immutable history), validates **legal state transitions**, and refuses a
completion that does not trace to an **approved** goal in the ledger.

## 2. Non-goals
- **No** goal rewrite, **no** retroactive state change, **no** history deletion.
- **No** provider/model/API/network/`.env` read; reads only the input file/stdin; all sub-commands call **no git**.
- **Not** verifying that a human truly approved (authenticity) or that an evidence link resolves — those are upstream (human
  Release Gate + v0.6.5 composer); v0.6.4 verifies **shape + state-machine legality + append-only + subject-consistency**.
- **Not** implementing v0.6.5; the `goal_id` is a preexisting v0.4.1 reference (not minted here).

## 3. Design
### 3.1 Goal ledger entry (keyed by `(goal_id, seq)`; producer v0.6.4; references a v0.4.1 `goal_id`)
```text
{ "entry_kind":"goal_ledger", "producer_milestone_id":"v0.6.4",
  "goal_id":"<token_ok; a preexisting v0.4.1 goal-plan id>", "seq": <int ≥ 0>,   # (goal_id, seq) is the immutable key
  "goal_state":"proposed|approved|in-progress|completed|blocked|abandoned",
  "scope":"<token_ok>", "constraints":"<token_ok>",                              # what + bounds (non-prose tokens)
  "approval": <approval entry> | null,                                          # REQUIRED iff goal_state=approved (human gate)
  "evidence_links":[ "<ref_ok>", … ],                                           # links to evidence (shape-only)
  "completion_state":"open|done",
  "work_id","plan_hash"(hex≥16),"repo_hash"(hex≥16),"verification_ref" }        # 4 contract binding fields
```
`token_ok`/`ref_ok` are the v0.6.3 decidable predicates. The `approval` (when present) passes `--validate-entry approval` and
is subject-consistent.

### 3.2 Goal state machine (legal transitions)
`proposed → approved | abandoned` · `approved → in-progress | abandoned` · `in-progress → completed | blocked | abandoned` ·
`blocked → in-progress | abandoned` · `completed`/`abandoned` = terminal (**any outgoing transition from them is illegal**). A
`completed`/`in-progress` latest state requires the goal's **full history** (all seq for that `goal_id`) to contain an
`approved` entry — a **history scan**, independent of the immediate transition edge (no completion/progress without a prior
approval somewhere in history).

### 3.3 Sub-commands
- `--validate <entry.json|->` → one ledger entry (entry_kind, producer, goal_id `token_ok`, seq int≥0, goal_state ∈ 6,
  fields, `approval` valid when state=approved). exit 0/1/2.
- `--transition <{from, to}>` → is the goal-state transition legal (§3.2)? exit 0 legal / 1 illegal.
- `--append-check <{prev, next}>` → the ledger is **append-only**: every `prev` entry (keyed `(goal_id, seq)`) is in `next`
  with **canonical-JSON-identical** content (no rewrite/delete of history), only additions; **duplicate `(goal_id, seq)` →
  REFUSE**. exit 0/1.
- `--trace <{ledger:[…], completion:{goal_id, completion_state}}>` → **every completion traces to a goal**: REJECT a ledger
  with duplicate `(goal_id, seq)` (so "latest" is well-defined within `--trace` alone); the completion's `goal_id` MUST exist
  in the ledger; the goal's **full history** MUST contain an `approved` entry; its **latest state** (highest `seq`) must
  legally support completion (`in-progress`/`approved` → `completed` legal); else **REFUSE**. exit 0 ALLOW / 1 REFUSE.
- `--authorize <{prev, next, completion}>` → **the authoritative anti-bypass decision** = `append-check(prev,next)` ALLOW
  **AND** `trace(next, completion)` ALLOW. Either fails → REFUSE — prevents authorizing a completion against a
  rewritten/truncated ledger that bare `--trace` would accept (mirrors v0.6.3 `--release`). `--out` optional, write-safe.
- `--self-test`. (`--out` write-safety reuses the v0.6.3 `out_unsafe`/`vet_out` semantics verbatim, core + wrapper.)

### 3.4 Outputs
- `.harness/schemas/goal-ledger.schema.md` — entry shape + state machine + append-only + trace rule + honest scope.
- `.harness/evidence/dmc-v0.6.4-goal-ledger.{py,sh}` — validator + transition + append-check + trace; input-only, env-free,
  no-heredoc/no-temp, dup-key-rejecting, value-blind, write-safe `--out`.
- `.harness/verification/dmc-v0.6.4-goal-ledger.md` — report.

## 4. File scope (additive only): the 3 deliverables + this plan. No other file touched.

## 5. Acceptance criteria (`--self-test`; every negative named)
| ID | Assertion |
|----|-----------|
| G1 | a valid ledger entry in representative states → VALID; the embedded `approval` (when `goal_state=approved`) passes contract `--validate-entry approval`. (The entry is `producer=v0.6.4`/`entry_kind=goal_ledger`; `goal_id` is a **bare v0.4.1 reference**, NOT a contract `goal` entry — not re-validated here.) |
| G2 | unknown/missing `goal_state` → REJECT; non-int/negative `seq` → REJECT; missing entry_kind/producer/binding → REJECT. |
| G3 | `goal_state=approved` without a valid subject-consistent `approval` (contract `--validate-entry approval`) → REJECT (non-human / bad source / foreign-subject / missing — named negatives). |
| G4 | prose/whitespace `scope`/`constraints`/`goal_id` (not `token_ok`) → REJECT; non-`ref_ok` `evidence_links` entry → REJECT. |
| G5 | transition: every legal §3.2 transition → exit 0; every illegal one → exit 1 — incl. `proposed→completed`, `proposed→in-progress`, and **terminal re-entry** `completed→*` / `abandoned→*` (any outgoing). |
| G6 | append-check: rewrite/delete a prior `(goal_id,seq)` → REFUSE; duplicate `(goal_id,seq)` → REFUSE; canonical-reorder identical → ALLOW; pure additions → ALLOW. |
| G7 | trace: completion `goal_id` NOT in ledger → REFUSE; goal present but never `approved` (full-history) → REFUSE; goal `abandoned`/`blocked` latest → REFUSE (illegal→completed); duplicate `(goal_id,seq)` in the traced ledger → REFUSE; goal `in-progress` with prior `approved` → ALLOW (lists the authorizing goal = Q4 answer). |
| G7b | **authorize anti-bypass:** a `next` ledger that rewrites/drops a prior `(goal_id,seq)` so that bare `--trace(next)` would ALLOW → `--authorize` REFUSEs (append-check catches it). The F9-analogue control. |
| G8 | duplicate JSON key / secret-shaped string anywhere (incl. ledger arrays) → REJECT; malformed root / `ledger` not array → REFUSE. |
| G9 | determinism/env-free: `env -i` + hostile credential var → identical verdict; all sub-commands call no git. |
| G10 | read-only: repo byte-unchanged after `--self-test`; `--out` write-safe (core + wrapper). |
| G11 | regression: v0.6.1.0 (26/0) + v0.6.1 (7/0) + v0.6.2 (18/0) + v0.6.3 (25/0) verifiers still green. |
| Gneg | every negative FAILs for its own reason; positives pass — no false-green. |

## 6. Safety constraints
Additive only; no protected-surface change; no live/model/API/network/`.env`; deterministic + env-independent; value-blind
reject-on-match (every sub-command); duplicate-key rejecting; advisory/fail-closed; inert unless invoked; **no goal rewrite, no
retroactive state change, no history deletion, no completion without an approved goal**; no-heredoc/no-temp; all sub-commands
call no git; `--out` write-safe.

## 7. Regression budget
Before commit: v0.6.1.0 (26/0) + v0.6.1 (7/0) + v0.6.2 (18/0) + v0.6.3 (25/0) self-tests.

## 8. Rollback
Additive on the feature branch: `git checkout -- <files>` before commit, or revert the additive commit. No protected surface,
no history rewrite, no force.

## 9. Approval status: **DRAFT — route to DMC `critic` (Codex dropped)**
On critic APPROVE (bounded-batch authorization covers approval): build → verify (`--self-test`) → DMC `verifier` audit →
commit on `dmc-control-plane/v0.6.1`. Push / main-FF / closure remain human-gated.
