# PLAN — v0.6.2 Evidence Receipt Gate (DRAFT, Rev 2)

**Parent roadmap:** `.harness/plans/dmc-v0.6.1-v0.6.5-roadmap.md` (APPROVED). **Branch:** `dmc-control-plane/v0.6.1`.
**Depends on:** v0.6.1.0 Trace Linkage Contract (`--validate-entry evidence`) — committed `4dbb5c5`.
**Type:** schema + deterministic validator + completion-block gate. **Additive, advisory, fail-closed, input-only,
read-only**; no protected-surface change, no live/model/API call, no `.env`/credential read, no network, no auto-apply.

**Rev 2 (2026-06-23):** incorporated the dual Critic gate (DMC critic NEEDS-CLARIFICATION + Codex REVISE, convergent).
Fixes: (B1) gate subject-match requires **all four** binding fields (`work_id`,`plan_hash`,`repo_hash`,`verification_ref`),
not two; (B2) **R10 honestly scoped** — `--gate` is input-only/no-git, so it defeats *receipt-vs-claim cross-subject reuse*;
**live-tree/live-head replay anchoring is upstream (goal/plan + human Release Gate + v0.6.5 composer), not claimed here**;
(B3) **`artifact_ref` is a decidable predicate** (hex≥16 OR safe relative-path regex), not "looks like prose"; (4) **`--gate`
`--out` + verdict JSON defined** with core+wrapper write-safety; (5) **negatives split one-per-reject-subrule** with asserted
reason. The v0.6.1.0 contract validates only the base `evidence` entry (kind/producer/id/binding) — v0.6.2 OWNS the
`evidence_type`/`artifact_ref`/`machine_verifiable`/`checker` checks.

**Purpose.** Answer **Q2 — "what evidence supports completion?"** and enforce **"no evidence → no completion."** Agent
prose/summary/self-report is **never** evidence. DONE is REFUSED unless a present, inspectable (non-prose artifact ref),
subject-consistent evidence receipt of the required type exists.

---

## 1. Problem statement
False E2E completion happens when an agent's prose ("done, tests pass") is taken as truth. v0.6.2 gates completion on
**inspectable evidence receipts** — each referencing a concrete, decidably-non-prose artifact (path/hash), carrying the
trace-linkage subject binding, of an allowed type — and refuses DONE without the required evidence.

## 2. Non-goals
- **Not** trusting model prose, summaries, or self-reported completion — ever.
- **No** provider/model/API/network/`.env` read; reads only the receipt/claim file or stdin; **`--validate`/`--gate` call no git**.
- **Not** opening/executing artifacts (input-only): "inspectable" = the receipt carries a concrete non-prose ref a reviewer
  or named checker can later open; v0.6.2 validates the *receipt shape + the claim's internal consistency*, not by running it.
- **Not** anchoring the subject to the live tree (input-only): live-head/replay-vs-live anchoring is upstream (goal/plan +
  human Release Gate + the v0.6.5 composer), consistent with the contract's "staleness vs live tree out of scope" note.
- **Not** implementing v0.6.3–v0.6.5; mints only `evidence_receipt` fragments.

## 3. Design
### 3.1 Evidence receipt (a trace-linkage `evidence` fragment + v0.6.2-owned fields)
```text
{ "kind":"evidence_receipt", "id":"<opaque>", "producer_milestone_id":"v0.6.2",
  "work_id","plan_hash"(hex≥16),"repo_hash"(hex≥16),"verification_ref",   # the 4 binding fields the contract requires
  "evidence_type":"<verification-report|test-result|artifact-existence|review-packet|audit-report>",  # v0.6.2-owned
  "artifact_ref":"<non-prose ref>", "machine_verifiable":<bool>, "checker":"<id>"|null }              # v0.6.2-owned
```
**Allowed evidence types (5):** `verification-report` · `test-result` · `artifact-existence` · `review-packet` · `audit-report`.
**`artifact_ref` — decidable non-prose predicate (B3):** VALID iff single-line, non-empty, no whitespace/control char, and
either **hash-shaped** `^[0-9a-f]{16,}$` **or** **safe-relative-path** `^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)+$` (≥1 `/`, safe
chars only; **rejects** absolute paths, `..`, `~`, `://`/URL schemes, backslashes, shell metacharacters, and bare tokens like
`done`/`tests-pass` that have no `/` and aren't hex). **`machine_verifiable:true` ⇒ `checker` non-empty.** The base entry
(kind/producer/id/4-binding) passes the v0.6.1.0 contract `--validate-entry evidence`; the type/ref/checker rules are
**v0.6.2's own** (the contract ignores them).

### 3.2 Completion-block gate
Input:
```text
{ "subject": { work_id, plan_hash(hex≥16), milestone_id, repo_hash(hex≥16), verification_ref },
  "completion_claim": { "done_requested": true, "claimed_by":"<role>" },
  "evidence": [ <evidence_receipt>, ... ] }      # any prose/summary/notes field is IGNORED, never evidence
```
**Gate rule (fail-closed):** verdict = **ALLOW** iff ALL hold, else **REFUSE** —
(a) `evidence` is a non-empty array; (b) **every** receipt is well-formed (§3.1) AND its four binding fields
(`work_id`,`plan_hash`,`repo_hash`,`verification_ref`) **exactly equal the claim subject's** (receipt-vs-claim consistency;
a mismatch on ANY field → REFUSE → defeats cross-subject reuse); (c) the **required type** `verification-report` is present
(no DONE without deterministic verification — the other four types are *additive* evidence, never a substitute);
(d) every `machine_verifiable:true` receipt names a `checker`. **A claim with no evidence, or only prose/summary, → REFUSE.**
**R10 scope:** this is *receipt-vs-claim* consistency only; the gate is input-only (no git) and does **not** anchor the claim
subject to the live tree — that is upstream (goal/plan + human Release Gate + v0.6.5 composer).
Output (stdout, or `--out`): `{ "verdict":"ALLOW|REFUSE", "reason":"<rule>", "subject":{…}, "required_present":{"verification-report":bool},
"evidence_answering_Q2":[{evidence_type,id,artifact_ref,machine_verifiable}], "n_receipts":<int> }`. The gate records its
verdict; it never grants DONE on prose.

### 3.3 CLI / outputs
- `--validate <receipt.json|->` — one evidence receipt (§3.1). exit 0 valid / 1 invalid / 2 usage.
- `--gate <claim.json|-> [--out <file>]` — the completion gate; verdict JSON to stdout (or `--out`); exit 0 = ALLOW, 1 = REFUSE,
  2 = usage/refused-out. `--out` is write-safe in **both** core and wrapper (in-repo/traversal/symlink/protected → REFUSED).
- `--self-test` — in-memory controls (§5) + repo byte-unchanged.

## 4. File scope (additive only)
| # | File | Contents |
|---|------|----------|
| 1 | `.harness/schemas/evidence-receipt.schema.md` | receipt shape + 5 types + the decidable `artifact_ref` predicate + the gate rule + R10 scope + append-only note; cites trace-linkage. |
| 2 | `.harness/evidence/dmc-v0.6.2-evidence-receipt.{py,sh}` | validator + completion gate (`--validate`/`--gate`/`--self-test`), input-only, env-free, no-heredoc/no-temp, dup-key-rejecting, value-blind, write-safe `--out`. |
| 3 | `.harness/verification/dmc-v0.6.2-evidence-receipt-gate.md` | verification report. |

Plus this plan. No other file touched.

## 5. Acceptance criteria (`--self-test`; every negative named, one per reject subrule, asserts its reject reason)
| ID | Assertion |
|----|-----------|
| E1 | a well-formed receipt of EACH of the 5 types (4-binding, valid `artifact_ref`) → VALID; and passes contract `--validate-entry evidence`. |
| E2a | `artifact_ref` bare token (`done`, `tests-pass`: no `/`, not hex) → REJECT. |
| E2b | `artifact_ref` with whitespace / a sentence → REJECT. |
| E2c | `artifact_ref` absolute / `..` / `~` / `://` / backslash / shell-metachar → REJECT. |
| E2d | missing `artifact_ref`, or unknown `evidence_type` → REJECT. |
| E3 | `machine_verifiable:true` with no/empty `checker` → REJECT. |
| E4a | gate: `evidence:[]` (empty) → REFUSE. |
| E4b | gate: claim with only a prose `summary`/`notes`, no `evidence` array → REFUSE. |
| E5 | gate: evidence present but NO `verification-report` type → REFUSE (required type missing). |
| E6a–d | gate: a receipt mismatching the claim subject on `work_id` (E6a) / `plan_hash` (E6b) / `repo_hash` (E6c) / `verification_ref` (E6d) → REFUSE (each a distinct negative). |
| E7 | gate: ≥1 valid `verification-report` + all receipts well-formed + 4-field subject-matching → **ALLOW**; verdict JSON lists the Q2 evidence. |
| E8a | duplicate JSON key anywhere → REJECT. |
| E8b | secret-shaped string anywhere → REJECT (value-blind). |
| E8c | malformed gate root / `evidence` not an array / an invalid receipt inside an otherwise-valid claim → REJECT/REFUSE. |
| E9 | determinism/env-free: `env -i` + hostile credential var → identical verdict; `--validate`/`--gate` call no git. |
| E10 | read-only: repo byte-unchanged after `--self-test`; `--out` write-safe (in-repo/traversal/symlink → REFUSED, core + wrapper). |
| E11 | regression: `dmc-v0.6.1.0-trace-linkage.sh --self-test` (26/0) + `dmc-v0.6.1-capability-router.sh --self-test` (7/0) still green. |
| Eneg | every negative above FAILs **for its own reason** (assert the reject category), positives pass — no false-green. |

## 6. Safety constraints
Additive only; no protected-surface change; no live/model/API/network/`.env`; deterministic + env-independent; value-blind
reject-on-match; duplicate-key rejecting; advisory/fail-closed; inert unless invoked; **never trusts prose/summary/self-report**;
no-heredoc/no-temp; `--validate`/`--gate` call no git; `--out` write-safe (core + wrapper).

## 7. Regression budget
Before commit: `dmc-v0.6.1.0-trace-linkage.sh --self-test` (26/0) + `dmc-v0.6.1-capability-router.sh --self-test` (7/0).

## 8. Rollback
Additive on the feature branch: `git checkout -- <files>` before commit, or revert the additive commit. No protected surface,
no history rewrite, no force.

## 9. Approval status: **DRAFT (Rev 2) — Critic stage done (critic + Codex incorporated)**
Per the lighter cadence (one critic + one Codex per gate; fix the REVISE, proceed), build now → verify (`--self-test`) → one
audit round (DMC verifier + Codex) → commit on `dmc-control-plane/v0.6.1`. Push / main-FF / closure remain human-gated.
