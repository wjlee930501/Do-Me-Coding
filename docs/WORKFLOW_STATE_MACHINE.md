# WORKFLOW_STATE_MACHINE.md — DMC Workflow State Machine (v0.5.4)

A **state-discipline** tool (NOT an enforcement hook) for the DMC milestone lifecycle. Validates a single transition or a
full path, and evaluates E2E-DONE. Advisory; inert unless invoked; reads no env/`.env`/secret; no network/live call;
**resume-safe** (never infers a gate from stale run state).

## States
`DRAFT → CRITIC → APPROVED → START_WORK → VERIFY → RELEASE_AUDIT → STAGE → COMMIT → PUSH → CLOSURE`, plus `BLOCKED`
(reachable from any state on a failed precondition).

## Immutable-fact binding (Codex-R4)
Every **gated** transition requires matching, present facts — a missing or mismatched fact ⇒ `BLOCKED` (fail-closed):
- `APPROVED→START_WORK`: `plan_status=APPROVED` ∧ `plan_hash_match` ∧ `run_id_match` (stale approval ⇒ BLOCKED).
- `VERIFY→RELEASE_AUDIT`: `verification=PASS` ∧ `verification_head_match` (verify must be for *this* head).
- `RELEASE_AUDIT→STAGE`: `release_audit=ACCEPT`.
- `STAGE→COMMIT`: `staged_digest_match` ∧ **not** `protected_staged` ∧ **not** `autolog_staged`.
- `COMMIT→PUSH`: `commit_present` ∧ **not** `staged_dirty` ∧ `push_authorized` (an *explicit* human/batch gate).
- `PUSH→CLOSURE`: `published` ∧ `closure_authorized`.

## Forbidden / out-of-order (all ⇒ BLOCKED)
`DRAFT→START_WORK` (no approval) · `COMMIT→CLOSURE` (skip PUSH) · `CRITIC→PUSH` and any other skip. **`critic PASS` is
advisory** — it authorizes only `CRITIC→APPROVED`, never push/main/closure (no gate confusion).

## E2E-DONE (`--done`)
Distinguishes **accepted-for-review** vs **published-to-main** vs **closure-recorded**. `DONE` only when all *required*
gates are met (`verification=PASS`, `release_audit=ACCEPT`, `commit_present`, and — unless explicitly relaxed via
`requires_main=false`/`requires_closure=false` — `published_to_main` and `closure_recorded`). `closure_recorded` without
`published_to_main` ⇒ **INVALID**; published-but-not-closed ⇒ **IN_PROGRESS**. No false E2E-DONE.

## Usage
`--transition --from <S> --to <S> --facts <json>` (exit 0=ALLOWED, 1=BLOCKED) · `--done --facts <json>`
(exit 0=DONE, 1=IN_PROGRESS/INVALID).
