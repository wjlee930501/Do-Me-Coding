# DMC v1.0 M4 — Run-Lifecycle State Machine (DMC-T009a)

- run_id: `dmc-v1-m4-20260706`
- date: 2026-07-06
- branch: `claude/dmc-v1-runtime-upgrade-c5uch1`
- plan: `.harness/plans/dmc-v1-m4-run-lifecycle.md` (APPROVED 2026-07-06, approver wjlee) §DMC-T009a
- primitive: P-run (architecture §0.3 machine run-state, §0.4 hash-chain + concurrency)
- scope of this task: additive Ring-0 only. Files created/modified are exactly the T009a set
  (below). No `.harness/evidence/dmc-v0.*` tool or its bin/lib copy was touched; no schema doc
  edited; no `.claude/**`; no `bin/lib/dmc-v0.*` filename added; no git add/commit/push; no
  network; no secret read.

## Files created / modified

| Path | Change | In-scope |
|---|---|---|
| bin/lib/dmc-run-lifecycle.py | new — run-lifecycle state machine + validator + self-test | yes (T009a) |
| bin/dmc | additive `run start\|suspend\|resume\|status` verb routing + M4 usage block only | yes (T009a) |
| tests/fixtures/run/plan.md | new — APPROVED synthetic fixture plan (shared by M4 sub-tasks) | yes (T009a) |
| tests/fixtures/run/orientation.json | new — `dmc.orientation.v1` fixture | yes (T009a) |
| tests/fixtures/run/radius.json | new — `dmc.radius.v1` fixture | yes (T009a) |
| .harness/evidence/dmc-v1-m4-run-lifecycle.md | new — this evidence log | yes (T009a) |

No selftest section arm (`run-core`/`loop-core`) was registered — that is exclusively T009g's.

## Design decisions (judgment calls)

- **run.json field set / in-tool contract `dmc.run-state.v1`** (no schema doc, per the M4
  approval): `schema, run_id, work_id, plan_path, plan_hash, repo_hash, status, seq,
  created_at, updated_at, prev_hash, state_hash`. The subject binding uses the v0.6.1.0 triple
  (`work_id`, `plan_hash`, `repo_hash`); `plan_hash`/`repo_hash` are `HASH_RE`-shaped
  (`^[0-9a-f]{16,}$`, sha256 hex here) so downstream trace/receipt tools compose over it.
- **Hash-chain + tamper evidence (§0.4):** each transition writes a new record whose `prev_hash`
  links to the prior record's `state_hash`; `state_hash = sha256(canonical(record − state_hash))`
  with the shared canonical serializer (sorted keys, compact separators, UTF-8). The validator
  recomputes `state_hash` and REFUSES on mismatch (tamper). `GENESIS = "0"*64` is the chain root
  (hash-shaped, so `prev_hash` is uniformly hash-shaped); seq-0 requires GENESIS, seq>0 forbids it.
- **run-id minting scheme:** `dmc-run-<first-12-hex(sha256("<work_id>|<plan_hash>|<repo_hash>"))>`
  — content-derived, deterministic, no wall-clock/randomness. Identical content ⇒ identical id
  (asserted). `repo_hash` uses the established env-free `git status --porcelain | sha256` pattern
  with a `no-git` fallback (`sha256(b"")`), so ids stay deterministic under `env -i`.
- **Timestamps:** `created_at`/`updated_at` read the system clock at runtime (ISO-8601 UTC), but
  every self-test assertion depends only on hash SHAPE / status enum / exit code — never on a
  clock value — so the suite is deterministic across runs and under `env -i`.
- **State machine:** states `INIT, RUNNING, SUSPENDED, RESUMING, DONE`; edges
  `INIT→RUNNING`, `RUNNING→{SUSPENDED,DONE}`, `SUSPENDED→RESUMING`, `RESUMING→RUNNING`; DONE
  terminal. `start` mints the INIT genesis then arms `INIT→RUNNING` (persisted status RUNNING,
  seq 1). `resume` walks `SUSPENDED→RESUMING→RUNNING`. Active set (blocks a second `start`) =
  `{INIT, RUNNING, RESUMING}`; SUSPENDED and DONE do not present as active (plan criterion 3).
- **Pointer file:** `.harness/runs/current-run-id` (matches the gitignored `.harness/runs/current-*`
  glob ⇒ local-only; a real invocation does not dirty the tree). The self-test never writes here —
  all fixture I/O is under `tempfile.mkdtemp()`.

## Verification results

- `python3 -m py_compile bin/lib/dmc-run-lifecycle.py` ⇒ clean; `bash -n bin/dmc` ⇒ clean.
- `python3 bin/lib/dmc-run-lifecycle.py --self-test` ⇒ **`[run-lifecycle] 22 PASS / 0 FAIL`, exit 0**.
  - Deterministic: two consecutive runs print an identical footer.
  - `env -i python3 bin/lib/dmc-run-lifecycle.py --self-test` ⇒ 22 PASS / 0 FAIL, exit 0 (git absent → no-git repo_hash fallback).
- Negative controls (each asserted in the self-test as a real exit-3 / REFUSE):
  - **second `start` while active ⇒ REFUSED exit 3** (`RUN-CONCURRENT-LOCK`) — S5.
  - **invalid transition (`resume` a RUNNING run) ⇒ REFUSED exit 3** (`RUN-INVALID-TRANSITION`) — S9.
  - **malformed run.json** — missing binding field (`RUN-STATE-MISSING-FIELD`, S10), bad status
    enum (`RUN-STATE-BAD-STATUS`, S10b), broken prev_hash (`RUN-STATE-BAD-PREV-HASH`, S10c),
    tampered body / stale state_hash (`RUN-STATE-TAMPER`, S10d) — all REFUSED.
  - **non-APPROVED (DRAFT) plan ⇒ `start` REFUSED exit 3** (`RUN-PLAN-NOT-APPROVED`) — S6.
- Hermeticity (S12): real repo `git status --porcelain` captured before/after the self-test is
  byte-identical (all writes confined to mkdtemp).
- Regression after the `bin/dmc` edit: `bin/dmc selftest` ⇒ 9 sections =
  `10+11+8+7+8+6+6+15+4 = 75 PASS / 0 FAIL`, exit 0 (unchanged; run-core/loop-core NOT in the
  default). `bin/dmc mirror-check` ⇒ PASS (55/55 byte-identical, no stray `dmc-v0.*`).
- Invariants: `grep -RInE 'claude-(opus|sonnet|haiku|fable|mythos)|gpt-[0-9]' bin/` ⇒ empty
  (Ring-0 model-name-free). No new `bin/lib/dmc-v0.*` file. `__pycache__` swept under `bin/`.
- Fixtures validate against the shipped M2/M3 validators: `dmc validate plan
  tests/fixtures/run/plan.md`, `dmc orient --validate tests/fixtures/run/orientation.json`,
  `dmc radius --validate tests/fixtures/run/radius.json` all ⇒ VALID exit 0.

## Rollback

Delete `bin/lib/dmc-run-lifecycle.py` and `tests/fixtures/run/`, and revert the additive
`bin/dmc` arms (the `RCORE` var, the `run)` case, and the M4 usage block). Nothing else references
them; the M3 selftest surface (default 75/0) is restored byte-identically.

## Not-edit confirmation

`.claude/**`, `bin/lib/dmc-instance-validate.py`, the six M3 schema docs, `docs/MILESTONES.md`,
`.harness/evidence/dmc-v0.*` originals + their bin/lib copies, and main/master were not touched.
No git add/commit/push. No live/network/secret paths.
