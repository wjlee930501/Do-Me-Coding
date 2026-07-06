# DMC v1.0 M4 — Evidence Ledger + `check_id` Receipts + Checkpoints (DMC-T009d)

- run_id: `dmc-v1-m4-20260706`
- date: 2026-07-06
- branch: `claude/dmc-v1-runtime-upgrade-c5uch1`
- plan: `.harness/plans/dmc-v1-m4-run-lifecycle.md` (APPROVED 2026-07-06, approver wjlee) §DMC-T009d
- primitives: P10 (evidence ledger + `check_id` receipts), P12 (checkpoints)
- scope of this task: additive Ring-0 only. Files created/modified are exactly the T009d set
  (below). `bin/dmc` was not touched (T009g is the sole registrant of selftest section arms).
  `dmc-v0.6.2-evidence-receipt.py` (original and bin/lib copy) was not edited — called read-only,
  as a subprocess, only from the self-test's compatibility control. No other `.harness/evidence/
  dmc-v0.*` tool or copy touched; no `.claude/**`; no new `bin/lib/dmc-v0.*` filename; no git
  add/commit/push; no network; no secret read.

## Files created / modified

| Path | Change | In-scope |
|---|---|---|
| bin/lib/dmc-evidence-ledger.py | new — P10 evidence ledger: mint/coverage verbs, hash-chained JSONL index, value-blind redaction, validator, self-test | yes (T009d) |
| bin/lib/dmc-checkpoints.py | new — P12 checkpoints: create verb (receipt-coverage-gated), validator, self-test | yes (T009d) |
| .harness/schemas/evidence-receipt.schema.md | the one authorized additive edit — optional `check_id` field | yes (T009d — sole schema edit) |
| .harness/evidence/dmc-v1-m4-evidence-checkpoints.md | new — this evidence log | yes (T009d) |

No selftest section arm (`run-core`/`loop-core`) was registered — that is exclusively T009g's.

## Design decisions (judgment calls)

- **Storage layout:** `.harness/runs/<run-id>/receipts/index.jsonl` (single append-only JSONL
  index, one line per minted receipt) + `.harness/runs/<run-id>/receipts/<seq4>-<safe-id>.json`
  (one file per receipt). `.harness/runs/<run-id>/checkpoints.json` is a plain JSON document
  (`{"schema":"dmc.checkpoint.v1","checkpoints":[...]}`) — not JSONL/hash-chained, since only
  receipts were specified as "a single JSONL index" and checkpoints is not among the plan's
  five hash-chained artifacts (scope.lock, acceptance, approvals, receipts, fixloop).
- **Hash chain (receipts index):** each index entry carries `prev_hash`/`entry_hash` using the
  same canonical-hash algorithm as `dmc-run-lifecycle.py` (`sort_keys=True,
  separators=(",", ":")`, sha256 hex) — duplicated locally rather than imported, so this module
  stays independently deletable per the plan's rollback contract. `GENESIS = "0"*64`. The
  validator (a) recomputes each entry's `entry_hash` and rejects a rewritten line, (b) checks
  `prev_hash` linkage and `seq` monotonicity to catch a dropped/reordered line, and (c)
  cross-checks each indexed `receipt_hash` against the actual persisted receipt file content, so
  editing a receipt file post-mint (without touching the index) is also detected.
- **`check_id` — additive-but-locally-required ("post-extension policy"):** the v0.6.2 schema
  treats `check_id` as optional/ignored (backward-compatible with pre-extension receipts), but
  `dmc-evidence-ledger.py`'s own mint policy REFUSES any receipt with no `check_id`
  (`EVID-CHECK-ID-REQUIRED`) — every receipt this ledger mints is check-referable for P12
  coverage and (later, T009f) P13 counters.
- **Value-blind redaction vs. refusal (per the plan's "pick per v0.5.0 pattern and document"):**
  opaque, non-format-constrained fields (`id`, `work_id`, `verification_ref`, `checker`,
  `check_id`) are individually scanned against the same `UNSAFE` shape set used by
  `dmc-v0.6.2-evidence-receipt.py`'s own `scan()` (copied verbatim for detection parity) and a
  match is REDACTED to the fixed placeholder `[redacted:unsafe-metadata]` (the v0.5.0
  `dmc-v0.5.0-run-metrics.sh` pattern) — the raw secret-shaped value is never persisted to disk or
  printed. `artifact_ref` is format-constrained (hash-shaped or a safe relative path per the
  v0.6.2 predicate); redacting it would corrupt that shape into something the v0.6.2 gate would
  itself reject, so a secret-shaped `artifact_ref` REFUSES the mint outright
  (`EVID-SECRET-ARTIFACT-REF`) instead of persisting a broken/laundered receipt. As a final
  safety net the fully-built receipt is re-scanned before being written; a residual match (should
  never trip given the above) also refuses the mint (`EVID-RESIDUAL-SECRET`).
- **Reuse-by-invocation, not import:** `dmc-checkpoints.py` asks `dmc-evidence-ledger.py coverage`
  (subprocess) whether a `check_id` has ledger coverage rather than re-implementing chain
  verification — coverage can never drift from what the ledger itself considers valid, and a
  broken/tampered ledger causes the coverage query to REFUSE (exit 3) rather than silently report
  "not covered", so a corrupted ledger cannot be mistaken for "no evidence yet". `dmc-v0.6.2-
  evidence-receipt.py` is invoked read-only, as a subprocess, ONLY inside the self-test's
  compatibility control (`validate <receipt-file>`) — never on the mint/coverage/create paths.
- **Path safety:** `--run-id` is validated against `^[A-Za-z0-9][A-Za-z0-9._-]*$` plus an explicit
  `".." not in run_id` check before it is used to build any filesystem path, in both modules.
- **Receipt id minting:** `rcpt-<first-16-hex(sha256("<check_id>|<evidence_type>|<artifact_ref>|<seq>"))>`
  — content-derived, deterministic, no wall-clock; an explicit `--id` overrides it (and is itself
  redaction-scanned).
- **git_ref / snapshot_hash (checkpoints):** `git_ref` = best-effort `git rev-parse HEAD`
  (`no-git` fallback); `snapshot_hash` = the established env-free `git status --porcelain | sha256`
  pattern (`no-git` ⇒ `sha256(b"")`), matching `dmc-run-lifecycle.py`'s `repo_hash()`.

## Verification results

- `python3 -m py_compile bin/lib/dmc-evidence-ledger.py bin/lib/dmc-checkpoints.py` ⇒ clean.
- `python3 bin/lib/dmc-evidence-ledger.py --self-test` ⇒ **`[evidence-ledger] 15 PASS / 0 FAIL`, exit 0**.
- `python3 bin/lib/dmc-checkpoints.py --self-test` ⇒ **`[checkpoints] 14 PASS / 0 FAIL`, exit 0**.
- `env -i python3 bin/lib/dmc-evidence-ledger.py --self-test` and the checkpoints equivalent both
  reproduce the identical PASS/FAIL counts and exit 0 (both modules also assert, as their own
  final check, that their own source contains no `os.environ`/`getenv(` usage).
- **Compatibility gate (positive control, E3):** a ledger-minted receipt file, read via
  `python3 dmc-v0.6.2-evidence-receipt.py validate <file>`, ⇒ `VALID` exit 0.
- **Backward-compatibility (manual re-check, this evidence pass):** a synthetic pre-extension
  receipt with no `check_id` at all still ⇒ `VALID` exit 0 under the (untouched) v0.6.2 gate;
  `python3 dmc-v0.6.2-evidence-receipt.py selftest` (unmodified file) ⇒ unchanged
  `18 PASS / 0 FAIL`.
- Negative controls (each asserted in a self-test as a real REFUSE):
  - **receipt with no `check_id`** ⇒ REFUSED exit 3, `EVID-CHECK-ID-REQUIRED` — E6.
  - **checkpoint requested without receipt coverage (false-green)** ⇒ REFUSED exit 3,
    `CKPT-NO-RECEIPT-COVERAGE`; `checkpoints.json` left unchanged — K2/K2b.
  - **secret-shaped value in a receipt** — free-form field (`id`) ⇒ REDACTED to
    `[redacted:unsafe-metadata]`, raw secret absent from the persisted file, mint still succeeds —
    E7; format-constrained field (`artifact_ref`) ⇒ REFUSED exit 3, `EVID-SECRET-ARTIFACT-REF` —
    E8 (documented choice: redact where safe, refuse where redaction would corrupt the field's
    own shape contract).
  - **broken receipt hash-chain** — a rewritten index line ⇒ `EVID-CHAIN-TAMPER` (E9); a dropped
    middle line ⇒ `EVID-CHAIN-BROKEN`/`EVID-CHAIN-SEQ-GAP` (E10); a receipt file edited post-mint
    without touching the index ⇒ `EVID-RECEIPT-HASH-MISMATCH` (E11) — all detected by
    `validate_ledger`.
  - **unsafe `--run-id` (path traversal)** ⇒ REFUSED exit 3 in both modules
    (`EVID-BAD-RUN-ID`/`CKPT-BAD-RUN-ID`) — E12/K9.
  - **checkpoints.json validator**: missing field, empty `check_ids`, wrong `schema`, non-hash
    `snapshot_hash` ⇒ each REFUSED — K4–K7; a valid persisted document ⇒ ACCEPTED — K8.
- Hermeticity: both self-tests capture the real repo `git status --porcelain` before/after —
  byte-identical (all writes confined to `tempfile.mkdtemp()`).
- Regression: `bin/dmc selftest` (no-arg default) ⇒ **75 PASS / 0 FAIL, exit 0** (unchanged —
  run-core/loop-core are not in the default and this task did not touch `bin/dmc`). `bin/dmc
  mirror-check` ⇒ PASS (55/55 byte-identical, no stray `dmc-v0.*`).
- Invariants: `grep -RInE 'claude-(opus|sonnet|haiku|fable|mythos)|gpt-[0-9]' bin/` ⇒ empty
  (Ring-0 model-name-free). No new `bin/lib/dmc-v0.*` file. No `__pycache__` under `bin/` (neither
  module imports the other or is imported anywhere, so none is generated).

## Schema diff (the sole authorized existing-schema edit)

```diff
 { "kind":"evidence_receipt", "id":"<opaque>", "producer_milestone_id":"v0.6.2",
   "work_id":"…","plan_hash":"<hex≥16>","repo_hash":"<hex≥16>","verification_ref":"…",   # the 4 contract binding fields
   "evidence_type":"<one of the 5>", "artifact_ref":"<non-prose ref>",                    # v0.6.2-owned
-  "machine_verifiable": <bool>, "checker":"<id>"|null }                                  # v0.6.2-owned
+  "machine_verifiable": <bool>, "checker":"<id>"|null,                                   # v0.6.2-owned
+  "check_id":"<stable id>"|null }                                                        # M4 additive (P10)
 ```
 **Evidence types (5):** `verification-report` · `test-result` · `artifact-existence` · `review-packet` · `audit-report`.

+**`check_id` (M4/P10, additive).** Optional, backward-compatible reference to the acceptance-compiler
+`check_id` (`.harness/schemas/acceptance.schema.md`) this receipt answers for. The v0.6.2 contract
+above is unchanged and does not read this field (old-shape receipts minted before this extension
+remain valid with no `check_id`); the M4 evidence ledger (`dmc-evidence-ledger.py`) applies its own,
+stricter, ledger-local policy of requiring a non-empty `check_id` on every receipt it mints.
+
```

## Rollback

Delete `bin/lib/dmc-evidence-ledger.py` and `bin/lib/dmc-checkpoints.py`, and revert the single
additive `check_id` block in `.harness/schemas/evidence-receipt.schema.md`. Nothing else
references them (no other file imports either module or reads `check_id`); the M3+T009a/b/c state
is restored byte-identically, and the v0.6.2 gate's own behavior is provably unchanged (its
self-test and a synthetic no-`check_id` receipt both still pass, above).

## Not-edit confirmation

`.claude/**`, `bin/dmc`, `bin/lib/dmc-instance-validate.py`, `bin/lib/dmc-v0.6.2-evidence-receipt.py`
(original and bin/lib copy — invoked read-only via subprocess only, never edited), the other five
M3 schema docs, `docs/MILESTONES.md`, `.harness/evidence/dmc-v0.*` originals + their bin/lib
copies, and main/master were not touched. No other worker's files (`dmc-run-lifecycle.py`,
`dmc-scope-lock.py`, `dmc-approvals.py`, `tests/fixtures/run/**`) were touched. No git
add/commit/push. No live/network/secret paths.
