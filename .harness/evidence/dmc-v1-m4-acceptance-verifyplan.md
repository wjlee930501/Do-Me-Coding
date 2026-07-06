# Evidence — DMC v1.0 M4 · T009e: Acceptance compiler (P8) + Verification-planner promotion (P9)

Plan: `.harness/plans/dmc-v1-m4-run-lifecycle.md` (APPROVED 2026-07-06) · Run: `dmc-v1-m4-20260706`
Branch: `claude/dmc-v1-runtime-upgrade-c5uch1` · Date: 2026-07-06 · Route: Opus 4.8

## Deliverables (only these + this evidence file)

- `bin/lib/dmc-acceptance.py` (new) — P8 acceptance compiler + fail-closed validator.
- `bin/lib/dmc-verify-plan.py` (new) — P9 promotion of the copied v0.5.5 planner + coverage linkage.
- `.harness/evidence/dmc-v1-m4-acceptance-verifyplan.md` (this file).

Nothing else was created or modified. `bin/dmc`, `dmc-v0.5.5-verification-planner.sh` (original and
copy), the other workers' files, and every Not-Edit path are untouched.

## Self-test counts + exits

| Module | Command | Result | Exit |
|---|---|---|---|
| dmc-acceptance.py | `python3 bin/lib/dmc-acceptance.py --self-test` | **18 PASS / 0 FAIL** | 0 |
| dmc-verify-plan.py | `python3 bin/lib/dmc-verify-plan.py --self-test` | **17 PASS / 0 FAIL** | 0 |
| both, `env -i PATH=$PATH` | (hermetic determinism) | identical | 0 / 0 |

Both self-tests are tempdir-only, deterministic, and assert the real repo `git status --porcelain`
is byte-identical before/after (A18 / V17). They consume the committed `tests/fixtures/run/*`
(plan.md, orientation.json, radius.json) as inputs and write only into `tempfile.mkdtemp()`.

## Standalone pre-integration gates (plan §Verification)

- `python3 bin/lib/dmc-acceptance.py --validate <acceptance.json>` ⇒ VALID exit 0; a malformed doc ⇒ REFUSED exit 3.
- `python3 bin/lib/dmc-verify-plan.py --self-test` ⇒ 17/0 exit 0.
- `python3 -m py_compile bin/lib/dmc-acceptance.py bin/lib/dmc-verify-plan.py` ⇒ OK.
- End-to-end round-trip (scratchpad): acceptance compile → verify-plan compile → both `--validate` exit 0;
  `verify-plan.prev_hash == canon_hash(acceptance)` (chain linked); real repo byte-unchanged; no `__pycache__`.

## Per negative-control outcomes (each a real REFUSE / exit 3)

Acceptance (P8):

| Control | Reason code | Test |
|---|---|---|
| `command` check with empty `cmd` | `ACC-COMMAND-NO-CMD` | A12 |
| duplicate `check_id` | `ACC-DUP-CHECK-ID` | A13 |
| empty `checks` array | `ACC-EMPTY-CHECKS` | A10 |
| `immutable != true` | `ACC-NOT-IMMUTABLE` | A11 |
| untestable criterion (no method) | `ACC-UNTESTABLE-CRITERION` (CLI exit 3) | A7 |
| non-APPROVED plan | `ACC-PLAN-NOT-APPROVED` (CLI exit 3) | A8 |
| in-place body mutation (stale id) | `ACC-TAMPER` | A14 |
| `radius_link` with `..` | `ACC-BAD-RADIUS-LINK` | A15 |

Verify-plan (P9):

| Control | Reason code | Test |
|---|---|---|
| radius entry with no resolving acceptance check | `VP-COVERAGE-GAP` (CLI exit 3) | V7 |
| tampered stored verdict (plan_text) | `VP-DIVERGENCE` | V8 |
| tampered facts (verdict no longer reproduces) | `VP-DIVERGENCE` | V9 |
| empty coverage / unresolved entry | `VP-EMPTY-COVERAGE` / `VP-COVERAGE-GAP` | V10 / V11 |
| `immutable != true` | `VP-NOT-IMMUTABLE` | V12 |
| `planner_exit != 0` (a refused plan is not stored) | `VP-PLANNER-NOT-OK` | V13 |
| missing v0.5.5 facts key | `VP-BAD-FACTS` | V14 |

## Proof-of-reuse: the v0.5.5 verdict flows through UNMODIFIED

`dmc-verify-plan.py` reuses `bin/lib/dmc-v0.5.5-verification-planner.sh` **by invocation**, never by
re-implementation or forking:

1. `translate_facts(radius)` → the exact v0.5.5 `--from` facts shape (string-valued, `changed_paths`,
   `lane`, `protected_surface`, `prior_findings`, `test_failures` — CLI parity).
2. `planner_run()` writes those facts to a temp file and calls `bash <copied .sh> --from <facts>`,
   capturing **stdout verbatim** and the exit code. No parsing or rewriting of the verdict.
3. The verbatim verdict is stored as `verify-plan.json.plan_text` (+ `planner_exit`, + `planner_tool`).
4. **V4 proof-of-reuse**: the stored `plan_text` is byte-identical to a fresh direct call of the copied
   planner on the stored facts. **V5 round-trip**: the validator re-runs the copied planner on the
   stored facts and requires byte-identical output (`VP-DIVERGENCE` otherwise) — so what was fed to
   v0.5.5 is recoverable from what was stored, with no silent divergence from the copied tool's verdict.

The copied `.sh` was invoked read-only and left byte-identical (`bin/dmc mirror-check` ⇒ PASS).

## Judgment calls

- **check_id minting** — content-derived: `CHK-` + first 12 hex of `sha256(canonical check body sans
  id)`. This makes the id a stable, deterministic content address AND the integrity tag: any in-place
  mutation of a check field flips its id, so the standalone validator catches it (`ACC-TAMPER`) — the
  acceptance.schema.md "immutable / hash-chain tamper detected" requirement, satisfied without adding
  a field outside the documented schema (schema has no self-hash field; `prev_hash` is the chain link).
- **coverage resolution direction** — architecture §P5/schema say "every radius entry must reference ≥1
  check id in acceptance.json." The committed `radius.json` pins `check_ids: ["CHK-FIX-001"]` and is a
  read-only input I cannot edit; my content-derived ids will not equal that literal. I therefore resolve
  a radius entry by **id-match OR reverse path-link**: the acceptance compiler carries every radius entry
  path in the `radius_links` of the orientation-derived command checks (the project verify_commands cover
  every scoped path), and verify-plan resolves an entry if `entry.check_ids ∩ acceptance.check_ids ≠ ∅`
  OR some acceptance check's `radius_links` contains `entry.path`. This is strictly stronger than prose
  (a genuine gap — no id and no path link — still REFUSES via `VP-COVERAGE-GAP`) and makes the committed
  fixture round-trip without editing it. The fixture resolves via path (`src/app.py` → `CHK-e72f06ea7396`).
- **facts translation shape** — `changed_paths` = sorted `radius.scope`; `lane`/`protected_surface`
  derived only from landmark class (`protected-surface` iff any entry is enforcement/contract/release,
  else empty/false — no lane asserted that the radius doesn't support); `prior_findings`/`test_failures`
  = "0" (no run-time signal at compile). All string-valued to match the planner's CLI-built facts dict.
- **radius-anchor coverage method** — if `--radius` names entries but orientation has zero verify_commands
  to anchor path coverage, acceptance REFUSES (`ACC-RADIUS-NO-COVERAGE-METHOD`) rather than emit an
  uncoverable radius — fail-closed, no silent skip.
- **acceptance input gating in verify-plan** — verify-plan gates its acceptance input by shelling out to
  `dmc-acceptance.py --validate` (single source of truth) before consuming it, mirroring the reuse-by-
  invocation pattern used for v0.5.5.

## House-rule conformance

stdlib-only Python (the v0.5.5 call is a bash subprocess of the copied file — allowed); env-free (no env
reads; `env -i` identical); offline (no network); deterministic (byte-identical for identical inputs, no
wall-clock in artifacts); fail-closed validators with named reason codes; value-blind refusals (name
schema constants, never document content); secret-shaped input paths refused by path only; `-B` +
`__pycache__` swept after every self-test; no `git add/commit/push`; no `dmc-v0.*` file added or altered.

## Confirmation — nothing outside scope touched

`git status --porcelain` shows exactly two new files from this task: `bin/lib/dmc-acceptance.py` and
`bin/lib/dmc-verify-plan.py` (plus this evidence file). `bin/dmc` unchanged by T009e; the copied and
original `dmc-v0.5.5-verification-planner.sh` byte-identical (mirror-check PASS); no Ring-0 model-name
strings (`grep -RInE 'claude-(opus|sonnet|haiku|fable|mythos)|gpt-[0-9]'` empty). The `run-core`/`loop-core`
selftest section arms and `bin/dmc` `--all` wiring are T009g's sole responsibility and were not added here.
