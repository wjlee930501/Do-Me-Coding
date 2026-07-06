# DMC v1.0 M4 — Integration, Hermetic Round-Trip, Regression Proof (DMC-T009g)

- run_id: `dmc-v1-m4-20260706`
- date: 2026-07-06
- branch: `claude/dmc-v1-runtime-upgrade-c5uch1`
- plan: `.harness/plans/dmc-v1-m4-run-lifecycle.md` (APPROVED 2026-07-06, approver wjlee) §DMC-T009g
- role: the final M4 sub-task — wire the whole run-lifecycle spine into one integration proof and
  prove the milestone is additive/deletable without moving the pinned regression numbers.
- scope of this task: additive Ring-0 only. Exactly the T009g file set (below). No T009a–f module
  edited; no `dmc-v0.*` original or bin/lib copy touched; no new `bin/lib/dmc-v0.*` filename; no
  `.claude/**`; no schema doc edited; no git add/commit/push; no network; no secret read.

## Files created / modified

| Path | Change | In-scope |
|---|---|---|
| bin/lib/dmc-run-core-selftest.py | new — run-core + loop-core aggregator + hermetic whole-loop round-trip | yes (T009g) |
| bin/dmc | additive — registers `run-core`/`loop-core` as named sections + wires both into `--all`; NOT in the no-arg default | yes (T009g) |
| .harness/verification/dmc-v1-m4-run-lifecycle.md | new — M4 milestone verification report (conforms to VERIFICATION_SCHEMA.md) | yes (T009g) |
| .harness/evidence/dmc-v1-m4-integration.md | new — this evidence write-up | yes (T009g) |

T009g is the SOLE registrant of the `run-core`/`loop-core` selftest section arms (the plan's
sequencing rule so the two `bin/dmc` editors — T009a run verbs, T009g selftest arms — never overlap).

## What the round-trip proves (single tempdir, self-contained git identity)

`dmc-run-core-selftest.py`'s `run-core` section runs the whole M4 spine end-to-end inside one
`tempfile.mkdtemp()` git repo (git initialized + committed with an in-tempdir `user.name`/`user.email`
so a bare CI host needs no ambient git config), then validates every artifact and re-runs the copied
composers. The sequence and its assertions (all PASS):

1. **start** → `run.json` + `current-run-id` pointer; the run validates (RT01–01d); status RUNNING,
   binding hash-shaped.
2. **scope-lock compile `--run run.json`** → `scope.lock.json`; validates; `prev_hash == run.state_hash`
   (chain composes, RT02c); pure `adjudicate` ALLOWs an in-scope edit and REFUSEs an out-of-scope path
   (RT02d).
3. **acceptance compile** → `acceptance.json`; validates; ≥2 content-derived unique check_ids (RT03).
4. **verify-plan compile** → `verify-plan.json` via the copied v0.5.5 planner (reuse-by-invocation);
   validates by re-running the planner with no divergence; `prev_hash == canon_hash(acceptance)` (RT04c).
5. **mint receipts (P10)** → two hash-chained receipts for the coverage check_id; ledger validates
   (chain + receipt-hash cross-check); coverage COVERED for the minted id, NOT-COVERED for an unminted
   one (RT05).
6. **induced check fail → fix-loop counter (P13)** → two appends mint attempts 1→2 for the failing
   `(plan_hash, check_id)`; the log validates (chain + bound→STOP + cross-run counter) (RT06).
7. **checkpoint (P12)** → created only because the referenced check_id has receipt coverage; a
   coverage-less checkpoint is REFUSED (false-green blocked) (RT07).
8. **approvals (P17)** → a pre-verification `plan_approval` (no `verification_ref`) + a post-verification
   `release` (real `verification_ref`); the ledger validates (R12 uniform + chain + post cross-check);
   a laundered `source: codex-accept-…` is REFUSED end-to-end by the local rule (RT08).
9. **suspend** → SUSPENDED, reported not-active (RT09).
10. **resume** → SUSPENDED→RESUMING→RUNNING, active again, chain intact (RT10).
11. **context recovery (P11), clean scenario** → no delta, not halted, `recovery.json` validates by
    re-running the copied v0.5.7 tool with no divergence; a `moved-HEAD` delta with `--reconcile`
    HALTS instead of auto-reconciling (RT11).
12. **composer compatibility** — over the round-trip's own generated artifacts:
    - v0.6.2 `validate` ACCEPTs every minted receipt (RT12);
    - v0.6.2 `gate` ALLOWs the receipt set as a subject-consistent evidence array with a
      verification-report present (RT12b);
    - v0.6.1.0 `validate-entry approval` ACCEPTs each post-verification approval record (RT12c — the
      R12 anti-laundering re-test, same gate as T009c's cross-check);
    - v0.6.5 `validate` ACCEPTs a `decision` record whose links carry the M4 receipt ids +
      post-verification approval id (RT12d — proves the M4 ids are token-compatible with the v0.6.5
      decision-trace register).

Finally the section asserts the REAL repo `git status --porcelain` is byte-identical before/after
(Z1) — all writes were confined to the tempdir.

## Section results (observed)

- `bin/dmc selftest run-core loop-core` ⇒ **run-core 153 PASS / 0 FAIL**, **loop-core 78 PASS / 0
  FAIL**, exit 0.
  - run-core folds the five run-primitive module self-tests (run-lifecycle 22, scope-lock 30,
    approvals 30, evidence-ledger 15, checkpoints 14 = 111) + 5 module-discipline assertions + 42
    round-trip assertions (RT01–RT12d) + Z1 = 153.
  - loop-core folds the four loop-primitive module self-tests (acceptance 18, verify-plan 17, fixloop
    24, context-recovery 14 = 73) + 4 module-discipline assertions + Z1 = 78.
- `bin/dmc selftest; echo $?` ⇒ **9 sections = 75 PASS / 0 FAIL**, exit 0 (unchanged; run-core/loop-core
  are NOT in the no-arg default). Section footers: orient 10, landmarks 11, depsurface 8, radius 7,
  validate-plan 8, validate-run 6, validate-verification 6, schemas-mirror 15, legacy-mirror 4.

## The two `--all` runs (the honest live-drift record + the acceptance evidence)

Per the known live-tree caveat (M3 pattern), `--all` was run twice, in sequence.

- **LIVE tree** (`bin/dmc selftest --all`) ⇒ legacy aggregate **tools=49 PASS=800 FAIL=5 N/A=3**,
  SELFTEST-ALL **FAIL**, rollback-test FAIL, run-core 153/0 + loop-core 78/0 PASS, exit 1. The 5
  FAILs are the 3 pinned upstream FAILs (dmc-v0.1.3, dmc-v0.2.3, dmc-v0.3.2) **plus** two working-
  tree-sensitive FAILs — `dmc-v0.5.9-dynamic-workflow-acceptance.sh` (AC13) and `dmc-v0.6.0-verify.sh`
  (V15) — that trip because the working tree carries three tracked-but-uncommitted mods (master-plan
  approval line, the T009a `bin/dmc` run-verb edit, the T009d `evidence-receipt` `check_id` line).
  SELFTEST-ALL FAIL is **expected** live and is not a defect; run-core/loop-core themselves are green.
- **Committed replica** (rsync of the tree minus `.git` into the scratchpad, `git init/add/commit`,
  then `bin/dmc selftest --all`) ⇒ legacy aggregate **tools=49 PASS=802 FAIL=3 N/A=3** (== the pinned
  M3 baseline, exactly), SELFTEST-ALL **PASS**, rollback-test **PASS** (originals alone reproduce
  802/3/3), run-core 153/0 + loop-core 78/0 PASS, exit 0. This is the acceptance evidence: a clean
  tree means the v0.5.9/v0.6.0 working-tree checks pass and the drift disappears.

## M4-specific rollback dry-run (disposable copy — never the real repo)

In a second scratchpad rsync copy: deleted the ten new M4 modules
(`dmc-{run-lifecycle,scope-lock,approvals,evidence-ledger,checkpoints,acceptance,verify-plan,fixloop,
context-recovery,run-core-selftest}.py`) and reverted `bin/dmc` to its committed form via
`git show HEAD:bin/dmc` (the "git checkout of bin/dmc" equivalent — HEAD carries neither the T009a
run verbs nor the T009g selftest arms, since M4 is uncommitted). Outcome:

- reverted `bin/dmc selftest` ⇒ **75 PASS / 0 FAIL, exit 0** (the M3 default surface, byte-restored);
- reverted `bin/dmc selftest run-core` ⇒ exit 2 (`unknown target` — the section arms are gone);
- reverted `bin/dmc mirror-check` ⇒ PASS (the 55 legacy files + the legacy aggregate logic are intact;
  the M4 additions/deletions do not touch them).

So the whole M4 milestone is additive and deletable: removing the ten `bin/lib/dmc-*.py` files and
reverting the additive `bin/dmc` arms restores the M3 selftest surface (75/0) and the pinned legacy
baseline (802/3/3) with nothing left dangling — nothing consumes M4 artifacts at runtime yet.

## Judgment calls

- **v0.6.5 applied to the round-trip.** The plan/verification-command names three copied composers to
  "run clean over the generated receipts and approval records". v0.6.2 (`validate` each receipt +
  `gate` the receipt set) and v0.6.1.0 (`validate-entry approval` each post-verification record)
  consume the M4 artifacts directly. v0.6.5 `validate` takes a `decision` record (there is no decision
  artifact in M4), so I built a `decision` whose `links.evidence_ids`/`links.approval_id` reference the
  round-trip's actual minted receipt ids + post-verification approval id and validated THAT — the
  meaningful, direct compatibility check that the M4 ids are token-shaped and compose into the v0.6.5
  decision-trace register, without inventing an out-of-scope full trace-linkage record.
- **v0.6.2 `gate` (not only `validate`).** The verification command names the "v0.6.2 evidence-receipt
  gate"; I minted all round-trip receipts with one consistent subject binding and at least one
  `verification-report`, then ran `gate` over them as a completion-claim evidence array → ALLOW. This
  exercises the receipts as a set (subject-consistency + required-evidence), a stronger check than
  per-receipt `validate` alone (which is also run).
- **Round-trip lives in run-core, fan-out split per the plan.** run-core = the five run primitives +
  the round-trip; loop-core = the four loop primitives. The round-trip necessarily exercises the loop
  primitives too, but it is registered under run-core exactly as the plan specifies, so the split stays
  as written.
- **Counts fold, not just pass/fail rollup.** Each folded module's own `X PASS / Y FAIL` footer is
  parsed and added into the section total (plus one module-discipline assertion per module that pins
  `Y == 0` and exit 0), so a regression inside any M4 module surfaces in the section count, not only in
  its exit code. No specific magic number is pinned for run-core/loop-core (unlike the default 75/0 and
  the replica 802/3/3); the contract is all-pass + exit 0.
- **Aggregator is deletable + reuse-by-invocation.** Every M4 module and every copied v0.x validator is
  called as a read-only subprocess (`-B`), never imported, so `dmc-run-core-selftest.py` carries no
  import coupling and is removable in the rollback with nothing left referencing it.

## House-rule conformance

stdlib-only; env-free (no `os.environ`/`getenv`); offline (git confined to the tempdir; no network,
no live provider, no secret read — secret paths are refused by path only); deterministic assertions
(no assertion depends on a wall-clock value or a specific hash literal — only hash SHAPE, status
enums, exit codes, and recomputed chain links); fail-closed (a mid-round-trip exception becomes a FAIL
via `RT99`, never an abort, so the section footer always prints and the exit code is deterministic);
`bash -n bin/dmc` clean; `python3 -m py_compile bin/lib/dmc-*.py` clean; `__pycache__` swept under
`bin/`; no `git add/commit/push`; no `dmc-v0.*` file added or altered (mirror-check PASS).

## Not touched

`bin/lib/dmc-instance-validate.py`, all T009a–f modules and their evidence, the copied `dmc-v0.*`
originals + their bin/lib copies (invoked read-only only), the six M3 schema docs (the authorized
`evidence-receipt` `check_id` edit is T009d's, left as-is), `.claude/**`, `docs/MILESTONES.md`,
main/master. No new `bin/lib/dmc-v0.*` filename. No live/network/secret access.
