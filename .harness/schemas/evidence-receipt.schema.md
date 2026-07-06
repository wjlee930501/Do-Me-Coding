# evidence-receipt.schema.md

The evidence-receipt + completion-block-gate contract (DMC v0.6.2). Additive; advisory; **input-only**; **fail-closed**.
Enforces **"no evidence → no completion"** and answers **Q2 — "what evidence supports completion?"** An agent's
prose/summary/self-report is **never** evidence. A receipt is a trace-linkage `evidence` fragment
(`.harness/schemas/trace-linkage.schema.md`, `--validate-entry evidence`) plus v0.6.2-owned fields.

## Evidence receipt
```text
{ "kind":"evidence_receipt", "id":"<opaque>", "producer_milestone_id":"v0.6.2",
  "work_id":"…","plan_hash":"<hex≥16>","repo_hash":"<hex≥16>","verification_ref":"…",   # the 4 contract binding fields
  "evidence_type":"<one of the 5>", "artifact_ref":"<non-prose ref>",                    # v0.6.2-owned
  "machine_verifiable": <bool>, "checker":"<id>"|null,                                   # v0.6.2-owned
  "check_id":"<stable id>"|null }                                                        # M4 additive (P10)
```
**Evidence types (5):** `verification-report` · `test-result` · `artifact-existence` · `review-packet` · `audit-report`.

**`check_id` (M4/P10, additive).** Optional, backward-compatible reference to the acceptance-compiler
`check_id` (`.harness/schemas/acceptance.schema.md`) this receipt answers for. The v0.6.2 contract
above is unchanged and does not read this field (old-shape receipts minted before this extension
remain valid with no `check_id`); the M4 evidence ledger (`dmc-evidence-ledger.py`) applies its own,
stricter, ledger-local policy of requiring a non-empty `check_id` on every receipt it mints.

**`artifact_ref` — decidable non-prose predicate.** VALID iff single-line, non-empty, no whitespace/control char, and either
- **hash-shaped** `^[0-9a-f]{16,}$`, OR
- **safe relative path** `^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)+$` (≥1 `/`, safe chars) **and no `..` path component**.

REJECTED: bare tokens (`done`, `tests-pass` — no `/`, not hex), sentences/whitespace, absolute paths, `..`, `~`, `://`/URL
schemes, backslashes, shell metacharacters. **`machine_verifiable:true` ⇒ `checker` non-empty.** The base entry
(kind/producer/id/4-binding) passes the v0.6.1.0 contract; the **type / artifact_ref / checker rules are v0.6.2's own** (the
contract ignores those fields).

## Completion-block gate
Input: `{ "subject": {5 binding fields}, "completion_claim": {"done_requested":true,"claimed_by":"…"}, "evidence":[<receipt>…] }`
(any `summary`/`notes`/prose field is **ignored** — never evidence).

**Verdict = ALLOW iff ALL hold, else REFUSE (fail-closed):**
1. `evidence` is a non-empty array;
2. every receipt is well-formed AND its four binding fields (`work_id`,`plan_hash`,`repo_hash`,`verification_ref`) **exactly
   equal the claim subject's** — any mismatch → REFUSE (defeats receipt-vs-claim cross-subject reuse);
3. the required type **`verification-report` is present** (no DONE without deterministic verification; the other four types are
   *additive* evidence, never a substitute);
4. every `machine_verifiable:true` receipt names a `checker`.

A claim with no evidence, only prose/summary, malformed root, `evidence` not an array, or any invalid receipt → **REFUSE**.

**R10 scope (honest):** the gate is **input-only and calls no git**, so it enforces *receipt-vs-claim* subject consistency
only; it does **not** anchor the claim subject to the live tree. Live-head / replay-vs-live-tree anchoring is upstream — the
goal/plan, the human Release Gate, and the v0.6.5 composer — consistent with the contract's "staleness vs live tree out of
scope" note.

**Verdict record (stdout or `--out`):**
```text
{ "verdict":"ALLOW|REFUSE", "reason":"<rule>", "subject":{…}, "required_present":{"verification-report":bool},
  "evidence_answering_Q2":[{"evidence_type","id","artifact_ref","machine_verifiable"}], "n_receipts":<int> }
```
The gate records its verdict; it never grants DONE on prose.

## Append-only / invariants
Receipts are **immutable once minted**; a stale receipt (subject ≠ claim) is rejected, so it cannot be reused for a new
completion. Deterministic (same input → same verdict); **env-independent** (`env -i` identical; no `.env`/credential/network);
**input-only** (`--validate`/`--gate` read only the file/stdin, **never call git**); **duplicate-JSON-key rejecting**;
**value-blind reject-on-match** (no secret-shaped string survives); `--out` write-safe (in-repo/traversal/symlink/protected →
REFUSED, core + wrapper). Advisory / fail-closed; **never trusts prose/summary/self-report**; the runtime enforcement floor
stays the hooks.
