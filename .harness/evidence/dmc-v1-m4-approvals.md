# DMC v1.0 M4 — Typed Approvals Ledger + R12 Anti-Laundering (DMC-T009c)

- run_id: `dmc-v1-m4-20260706`
- date: 2026-07-06
- branch: `claude/dmc-v1-runtime-upgrade-c5uch1`
- plan: `.harness/plans/dmc-v1-m4-run-lifecycle.md` (APPROVED 2026-07-06, approver wjlee) §DMC-T009c
- primitive: P17 (typed approvals) + R12 (anti-laundering provenance predicate)
- scope of this task: additive Ring-0 only — exactly the T009c file set below. No `bin/dmc` edit;
  no `.claude/**`; no schema doc edited; no `dmc-v0.*` original or bin/lib copy touched; no
  `bin/lib/dmc-v0.*` filename added; no git add/commit/push; no network; no secret read.

## Files created / modified

| Path | Change | In-scope |
|---|---|---|
| bin/lib/dmc-approvals.py | new — typed approvals ledger, local R12/7-enum rule, copied-validator cross-check, hash-chain, self-test | yes (T009c) |
| .harness/evidence/dmc-v1-m4-approvals.md | new — this evidence log | yes (T009c) |

No selftest section arm was registered (that is exclusively T009g). `bin/dmc` was NOT touched
(the ` M bin/dmc` in the working tree is T009a's pre-existing additive run-verb edit).

## Design decisions (judgment calls)

- **Record field set (in-tool contract; no new schema doc, per M4 approval — approvals reuse
  `trace-linkage.schema.md`).** Each `approvals.jsonl` line is a sealed `approval`-kind entry:
  `kind="approval"`, `id` (auto `approval-<seq>-<gate_kind>` unless `--id`), fixed provenance
  `producer_milestone_id = type = "human-release-gate"` and `source = "human-release-gate:<auth-id>"`,
  the subject binding `work_id` + hash-shaped `plan_hash`/`repo_hash` (read from the run's
  `run.json`), the NEW local field `gate_kind` ∈ the seven, `seq`, `prev_hash`, `created_at`, and
  the sealed `entry_hash`. The seven kinds live in `gate_kind`, NOT in `type` — the copied
  v0.6.1.0 validator pins `type`/`producer_milestone_id` to the literal `human-release-gate`, so it
  cannot carry them. The extra fields (`gate_kind`/`seq`/`prev_hash`/`entry_hash`/`created_at`) are
  ignored by the copied validator's `validate_entry` (it checks only the required approval fields),
  so a post-verification record still passes it byte-for-byte — proven by the positive cross-check.
- **Chaining design (append-only, tamper-evident).** `entry_hash = sha256(canonical(record −
  entry_hash))` using the SAME canonicalizer as `dmc-run-lifecycle.py` (sorted keys, compact
  separators, UTF-8) so every M4 artifact chains under one rule; `prev_hash` links to the prior
  line's `entry_hash`; `seq` is the line index; genesis is `seq 0` + `prev_hash = "0"*64`. The
  ledger validator recomputes `entry_hash` (a **rewritten** line ⇒ `TAMPER`), checks `seq ==
  position` and `prev_hash == prior entry_hash` (a **dropped/reordered** line ⇒ `BAD-SEQ` +
  `CHAIN-BREAK`). `append` first re-validates the existing chain and refuses to extend a tainted
  ledger (append-only guard) — a refused append writes nothing (asserted C6: ledger stays 3 lines).
- **Two gates, R12 uniform across all seven kinds.** The local rule (T009c-owned) re-enforces the
  R12 provenance predicate with byte-identical semantics to the copied validator (`nestr(source)` +
  `startswith("human-release-gate:")` + non-empty auth-id after `.strip()` + `type ==
  producer_milestone_id == "human-release-gate"`) for EVERY record, plus the 7-enum on `gate_kind`,
  the binding shape/vs-run check, and a value-blind secret scan (UNSAFE set copied verbatim). The
  **split**: post-verification kinds (release/push/waiver) must carry a real `verification_ref` and
  are ADDITIONALLY cross-checked by invoking `bin/lib/dmc-v0.6.1.0-trace-linkage.py validate-entry
  approval` as a read-only stdin subprocess (fail-closed at both append and validate);
  pre-verification kinds (plan_approval/scope_amendment/bound_raise/live_call) must OMIT
  `verification_ref` (the copied validator unconditionally requires one, so it is inapplicable) and
  are gated by the local rule only. A pre-verification record carrying ANY `verification_ref` is
  REFUSED. `append` builds `source` as `prefix + auth-id`, so a laundered source can never be minted
  by this tool — the laundered-source negative is therefore a validator-level control (a crafted
  record), matching the plan.
- **Decoupling from siblings.** `append`/`--validate` read only the three binding fields from
  `run.json` (they do NOT re-run T009a's run-state validator, and never invoke `dmc-run-lifecycle.py`
  or any other worker's module), so T009c is independently verifiable. The only subprocess is the
  copied v0.6.1.0 validator (read-only, over stdin — no temp file, no git, no network).
- **Determinism / env-freedom.** No env reads; binding/run-id come from `run.json`, never wall-clock
  (`created_at` is written but no assertion depends on its value), so the self-test footer is
  identical across runs and under `env -i`. All fixture I/O is under `tempfile.mkdtemp()`.

## Verification results

- `python3 -m py_compile bin/lib/dmc-approvals.py` ⇒ clean.
- `python3 bin/lib/dmc-approvals.py --self-test` ⇒ **`[approvals] 30 PASS / 0 FAIL`, exit 0**.
  - Deterministic: two consecutive runs print an identical footer (`30 PASS / 0 FAIL`).
  - `env -i python3 bin/lib/dmc-approvals.py --self-test` ⇒ 30 PASS / 0 FAIL, exit 0.
- **Positive controls:**
  - P1/P2/P2b append round-trip: plan_approval (pre, no `verification_ref`), release + push (post,
    real `verification_ref`) each exit 0 and grow the ledger 1→2→3 lines.
  - P3 `--validate` whole ledger exit 0 (chain intact + post-verification cross-check).
  - **P4 POSITIVE cross-check** — the copied `dmc-v0.6.1.0-trace-linkage.py validate-entry approval`
    ACCEPTs a release record (exit 0), i.e. the record passes BOTH the local rule AND the copied
    validator. Independently reproduced outside the self-test: `... validate-entry approval -` over a
    real appended release line prints `VALID`, exit 0.
  - P5/P5b local rule ACCEPTs the sealed release record and a valid pre record.
- **Negative controls (each a real REFUSE):**
  - N1 laundered `source: codex-accept-123` on a **pre** kind ⇒ `APPROVAL-BAD-SOURCE` (R12 re-test).
  - N2 laundered `source: codex-accept-123` on a **post** kind ⇒ `APPROVAL-BAD-SOURCE` by the local
    rule; **N2b** the copied `validate-entry approval` ALSO rejects it (T7c) — laundering blocked at
    both gates.
  - N3 empty auth-id (`source: "human-release-gate:"`) ⇒ `APPROVAL-EMPTY-AUTH-ID`.
  - N4 `type` ≠ `human-release-gate` ⇒ `APPROVAL-BAD-TYPE`.
  - N5 `producer_milestone_id` ≠ `human-release-gate` ⇒ `APPROVAL-BAD-PRODUCER`.
  - N6 unknown `gate_kind: rubber_stamp` ⇒ `APPROVAL-UNKNOWN-GATE-KIND`.
  - N7 missing `gate_kind` ⇒ `APPROVAL-MISSING-GATE-KIND`.
  - N8 subject-binding mismatch vs the run (`work_id`) ⇒ `APPROVAL-SUBJECT-MISMATCH`.
  - N9 pre-verification kind carrying a placeholder `verification_ref` ⇒
    `APPROVAL-UNEXPECTED-VERIFICATION-REF`.
  - N10 post-verification kind missing `verification_ref` ⇒ `APPROVAL-MISSING-VERIFICATION-REF`.
  - N11 value-blind: secret-shaped auth-id ⇒ `APPROVAL-SECRET-SHAPED` (reject-on-match).
  - N12 rewritten prior line ⇒ `APPROVAL-LINE-0-TAMPER` (append-only chain).
  - N13/N13b dropped middle line ⇒ `APPROVAL-LINE-1-BAD-SEQ` + `APPROVAL-LINE-1-CHAIN-BREAK`.
  - **End-to-end via the `append` CLI (real exit 3, fail-closed, nothing written):** C1 unknown
    gate_kind, C2 empty auth-id, C3 pre-kind + `verification_ref`, C4 post-kind without
    `verification_ref`, C5 missing run; C6 asserts the ledger stays exactly 3 lines after all
    refused appends (append-only, no partial write).
- **Hermeticity (H1):** the real repo `git status --porcelain` captured before/after the self-test
  is byte-identical (all writes confined to `mkdtemp()`).
- **Invariants:** `grep -RInE 'claude-(opus|sonnet|haiku|fable|mythos)|gpt-[0-9]'
  bin/lib/dmc-approvals.py` ⇒ empty (Ring-0 model-name-free). No new `bin/lib/dmc-v0.*` filename.
  `__pycache__` swept under `bin/`. Working tree adds only `bin/lib/dmc-approvals.py` (plus this
  evidence file); `bin/dmc` and `bin/lib/dmc-v0.6.1.0-trace-linkage.py` are untouched by this task.

## Rollback

Delete `bin/lib/dmc-approvals.py` (and this evidence file). Nothing references them; no `bin/dmc`
arm or schema line was added by T009c, so the M3 selftest surface and the pinned baseline are
unaffected.

## Not-edit confirmation

`.claude/**`, `bin/dmc`, `bin/lib/dmc-instance-validate.py`, the copied `dmc-v0.*` originals + their
bin/lib copies (incl. `dmc-v0.6.1.0-trace-linkage.py`, invoked read-only only), the M3 schema docs,
`docs/MILESTONES.md`, other workers' in-flight files, and main/master were not touched. No git
add/commit/push. No live/network/secret paths.

## Postscript — 2026-07-06 (independent-verifier honest-scope note, wording-only fix)

The M4 independent verifier accepted T009c (V1–V8 ACCEPT, 0 blockers) but flagged an honest-scope
overclaim: the post-verification `verification_ref` gate is **presence-only** (`nestr()` — non-empty
single-line string), so a placeholder like `TODO`/`none`/a fake ref passes. No ref→artifact
resolution happens in M4; that is the M9 release gate's obligation (carry-forward), consistent with
this module's declared provenance-not-authentication scope. Behavior is correct; only the wording
overclaimed. Fix applied pre-commit: every docstring/comment/reason-message/self-test-label that said
a "real" `verification_ref` now reads "non-empty verification_ref (presence-only; ref→artifact
resolution is enforced by the M9 release gate, not here)". Zero behavior change — no logic, no reason
CODES, no self-test assertion semantics altered; the diff is comments/strings only. Re-verified:
`python3 -B bin/lib/dmc-approvals.py --self-test` ⇒ `[approvals] 30 PASS / 0 FAIL`, exit 0.
