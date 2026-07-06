# Verification Report

## Run ID

dmc-v1-m4-20260706 · sub-task DMC-T009g (M4 integration, hermetic round-trip, regression proof).
Branch `claude/dmc-v1-runtime-upgrade-c5uch1`. Date 2026-07-06. Format: VERIFICATION_SCHEMA.md.

## Plan

`.harness/plans/dmc-v1-m4-run-lifecycle.md` (APPROVED 2026-07-06, approver wjlee) — §DMC-T009g,
M4-overall extended block, §Acceptance Criteria, §Verification Commands. This report covers the
final M4 sub-task: the run-core/loop-core self-test aggregator + the whole-loop hermetic round-trip
+ the additive `bin/dmc` wiring + the regression + rollback proof for the whole milestone.

## Changed Files

- bin/lib/dmc-run-core-selftest.py: new — run-core + loop-core section aggregator; fans out to the
  ten M4 module self-tests and runs the whole-loop hermetic tempdir round-trip; re-runs the copied
  v0.6.2 / v0.6.5 / v0.6.1.0 validators over the generated receipts + post-verification approvals.
- bin/dmc: additive only — registers `run-core` and `loop-core` as NAMED selftest sections and
  wires both into `--all`; NOT added to the no-arg default (which stays exactly 9 sections / 75/0).
  (The pre-existing ` M bin/dmc` in the tree is T009a's run-verb edit; T009g's edit is additive on
  top of it.)
- .harness/verification/dmc-v1-m4-run-lifecycle.md: new — this milestone verification report.
- .harness/evidence/dmc-v1-m4-integration.md: new — the T009g evidence write-up.

## Commands Run

| Command | Result | Reason | Output Summary |
|---|---|---|---|
| bash -n bin/dmc | PASS | syntax floor for the edited entry point | clean |
| python3 -m py_compile bin/lib/dmc-*.py | PASS | syntax floor for all M4 + the new module | clean (pycache swept) |
| bin/dmc selftest run-core loop-core | PASS | M4 primitive self-tests + the integration round-trip + all negative controls | run-core 153 PASS / 0 FAIL; loop-core 78 PASS / 0 FAIL; exit 0 |
| bin/dmc selftest; echo $? | PASS | the no-arg default must stay exactly 75/0 (run-core/loop-core are NOT in the default) | 9 sections = 10+11+8+7+8+6+6+15+4 = 75 PASS / 0 FAIL; exit 0 |
| bin/dmc selftest --all (LIVE tree) | FAIL | expected live-tree drift — see Manual Checks + Unresolved Risks | legacy tools=49 PASS=800 FAIL=5 N/A=3; SELFTEST-ALL FAIL; run-core 153/0 + loop-core 78/0 PASS; exit 1 (known, expected while M4 is uncommitted) |
| bin/dmc selftest --all (committed replica) | PASS | acceptance evidence (M3 precedent: a fully-committed replica) | legacy tools=49 PASS=802 FAIL=3 N/A=3 (== pinned baseline); SELFTEST-ALL PASS; rollback-test PASS; run-core 153/0 + loop-core 78/0 PASS; exit 0 |
| bin/dmc mirror-check | PASS | no dmc-v0.* copy added or altered by the M4 additions | 55/55 byte-identical both directions; no stray dmc-v0.* |
| copied v0.6.2 gate + validate, v0.6.5 validate, v0.6.1.0 validate-entry approval over the round-trip receipts + post-verification approval records | PASS | composer / anti-laundering (R12) compatibility (Acceptance 6/7) | all ACCEPT — RT12 (v0.6.2 validate each receipt), RT12b (v0.6.2 gate ALLOW), RT12c (v0.6.1.0 approval), RT12d (v0.6.5 decision) |
| grep -RInE 'claude-(opus\|sonnet\|haiku\|fable\|mythos)\|gpt-[0-9]' bin/ | PASS | Ring-0 model-name-free invariant | empty |
| git status --porcelain (real repo, before/after the round-trip) | PASS | the round-trip is tempdir-only; the real repo must be byte-unchanged | identical (round-trip Z1 assertion; confirmed no stray files after all --all / replica / rollback runs) |

## Manual Checks

| Check | Result | Notes |
|---|---|---|
| No-arg default selftest surface unchanged | PASS | exactly the same 9 sections and 75/0 exit 0 as M3; run-core/loop-core join only named use + --all |
| run-core / loop-core are named/--all-only, not in the default | PASS | bin/dmc named-branch case + the two explicit --all invocations; the default `set --` list is untouched |
| Whole-loop round-trip runs in one tempdir git repo (self-contained identity) | PASS | start→scope-lock→acceptance→verify-plan→mint receipts→induced fail→fix-loop increment→checkpoint→suspend→resume→context-recover; every step exit 0 |
| Every generated artifact validates against its own validator | PASS | run.json, scope.lock.json, acceptance.json, verify-plan.json, receipts index, fixloop.log.jsonl, checkpoints.json, approvals.jsonl, recovery.json — all VALID (RT01c–RT11b) |
| Hash-chain composition across artifacts | PASS | scope-lock.prev_hash == run.state_hash (RT02c); verify-plan.prev_hash == canon_hash(acceptance) (RT04c) |
| Negative controls fire inside the round-trip | PASS | out-of-scope adjudicate REFUSE (RT02d), NOT-COVERED coverage + false-green checkpoint REFUSED (RT05c/RT07c), laundered approval source REFUSED (RT08c), moved-HEAD HALT-not-reconcile (RT11c) |
| M4-specific rollback dry-run (disposable copy: delete the 10 new modules + `git show HEAD:bin/dmc`) | PASS | reverted default selftest = 75 PASS / 0 FAIL exit 0; reverted bin/dmc rejects `selftest run-core` (exit 2, unknown target); mirror-check PASS (legacy aggregate logic intact) |
| Committed-replica --all is the acceptance evidence (LIVE --all FAIL is expected) | PASS | replica clean tree ⇒ v0.5.9/v0.6.0 working-tree checks pass ⇒ 802/3/3 + SELFTEST-ALL PASS + exit 0 |

## Scope Review

Result: PASS

Notes: T009g wrote only its authorized files — `bin/lib/dmc-run-core-selftest.py` (new), `bin/dmc`
(additive `run-core`/`loop-core` section arms + `--all` wiring; the no-arg default untouched), and
the two report files (this report + `.harness/evidence/dmc-v1-m4-integration.md`). No T009a–f module
was edited; `dmc-instance-validate.py`, the copied `dmc-v0.*` originals + their bin/lib copies, the
six M3 schema docs (the authorized `evidence-receipt` `check_id` edit is T009d's, left as-is),
`.claude/**`, `docs/MILESTONES.md`, and main/master were not touched. No new `bin/lib/dmc-v0.*`
filename. No git add/commit/push. stdlib-only, env-free (no env reads), offline, secret-path refusal.
`git status --porcelain` shows exactly T009g's two code-surface entries (` M bin/dmc`, `?? bin/lib/
dmc-run-core-selftest.py`) plus this run's two report files; every other listed path belongs to a
prior sub-task. No `__pycache__` under `bin/`.

## Package / Env / Migration Review

Package files changed: no
Env files changed: no
Migration files changed: no

Notes: T009g is additive Ring-0 test/aggregation tooling only — no dependency manifest, no `.env*`,
no schema/migration file was touched (the sole M4 schema edit, `evidence-receipt.schema.md`
`check_id`, is T009d's and predates this sub-task). No secret path was read, printed, or written.

## Unresolved Risks

- LIVE `bin/dmc selftest --all` returns exit 1 / SELFTEST-ALL FAIL while M4 is uncommitted. This is
  the known, expected live-tree caveat, NOT a defect: the working tree carries three tracked-but-
  uncommitted mods (the master-plan approval line in `.harness/plans/dmc-v1-runtime-upgrade.md`, the
  T009a run-verb edit in `bin/dmc`, and the T009d `check_id` line in `evidence-receipt.schema.md`),
  which trip the pre-M3-vintage v0.5.9 (AC13) and v0.6.0 (V15) working-tree checks — exactly the two
  EXTRA FAILs observed (LIVE legacy = 800/5/3: the 3 pinned upstream FAILs dmc-v0.1.3/v0.2.3/v0.3.2
  PLUS dmc-v0.5.9-dynamic-workflow-acceptance.sh and dmc-v0.6.0-verify.sh). The committed replica
  (clean tree) restores the pinned 802/3/3 + SELFTEST-ALL PASS + exit 0 and is the acceptance
  evidence, per the M3 precedent. Resolution: none needed pre-commit; the drift disappears once the
  M4 commit lands.
- The three pinned upstream FAILs (dmc-v0.1.3, dmc-v0.2.3, dmc-v0.3.2 = 3 FAIL) are the accepted M3
  baseline anomaly; T009g reproduces 802/3/3 exactly and does not mask or "fix" them.
- `run-core`/`loop-core` are heavy (tempdir git + shell-outs to v0.5.5/v0.5.7 + three copied
  validators). By the M4 default-selftest policy they run only when explicitly named and under
  `--all`, never in the fast no-arg default — so the default regression number stays stable for M5+.

## Final Status

PASS
