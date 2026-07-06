# Evidence — DMC v1.0 M4 · T009f: Fix-loop counters (P13) + Context recovery (P11)

Plan: `.harness/plans/dmc-v1-m4-run-lifecycle.md` (APPROVED 2026-07-06) · Run: `dmc-v1-m4-20260706`
Branch: `claude/dmc-v1-runtime-upgrade-c5uch1` · Date: 2026-07-06 · Route: Opus 4.8

## Deliverables (only these + this evidence file)

- `bin/lib/dmc-fixloop.py` (new) — P13 bounded fix-loop counters + fail-closed validator.
- `bin/lib/dmc-context-recovery.py` (new) — P11 observed-git recovery, reuse of the copied v0.5.7
  tool by invocation, halt-on-delta.
- `.harness/evidence/dmc-v1-m4-fixloop-recovery.md` (this file).

Nothing else was created or modified. `bin/dmc` (T009g owns selftest registration), the copied
`dmc-v0.5.7-resume-recovery.sh` (original AND copy), all T009a–e files, and every Not-Edit path are
untouched.

## Self-test results

| Module | Command | Result |
|---|---|---|
| dmc-fixloop.py | `python3 -B bin/lib/dmc-fixloop.py --self-test` | **24 PASS / 0 FAIL**, exit 0 |
| dmc-context-recovery.py | `python3 -B bin/lib/dmc-context-recovery.py --self-test` | **14 PASS / 0 FAIL**, exit 0 |

Both are deterministic (self-test run twice ⇒ identical tally), env-independent (injected env and
`env -i` produce byte-identical `--validate` output), and leave the real repo `git status
--porcelain` byte-unchanged (all fixtures under `tempfile.mkdtemp()`; `__pycache__` swept).

## P13 — dmc-fixloop.py

Appends `runs/<run-id>/fixloop.log.jsonl` per `fixloop.schema.md`: `{schema, plan_hash, check_id,
attempt, hypothesis, files_touched, bound, verdict}` plus the approvals-style hash-chain fields
`{seq, prev_hash, entry_hash}`. `attempt > bound ⇒ verdict STOP` (schema-exact; `attempt == bound`
is the last in-bound attempt and may CONTINUE). `hypothesis` is advisory free-form: secret-shaped
content is value-blind **redacted** at append (`[REDACTED-SECRET]`) and the validator additionally
secret-scans every field fail-closed. `files_touched` are relative paths, no `..`, not absolute.

### Counter-persistence design (judgment call — where the counter lives and why)

Counters key on **`(plan_hash, check_id)`, not run-id**. There is deliberately **no separate mutable
counter index**: the counter's single source of truth is the union of every
`runs/*/fixloop.log.jsonl` that shares the `plan_hash`, aggregated at append/validate time
(`collect_attempts` → `high_water` / `cross_run_reasons`). `append` scans **all** sibling run dirs
(not just the current run's), takes the high-water-mark for `(plan_hash, check_id)`, and mints
`attempt = high-water + 1`. Consequences:
- The counter is plan_hash-scoped and **outlives any single run dir** — a fresh run resumes the same
  check at `high-water+1` (proven: run `fl01` reaches attempt 4, fresh run `fl02` mints attempt 5,
  never 1).
- **Reset gaming is structurally caught.** The cross-run invariant is: per `(plan_hash, check_id)`
  the attempt numbers across all runs must be **unique and contiguous 1..N**. A fresh run re-using a
  recorded attempt collides (duplicate) ⇒ `FIX-RESET-GAMING`; a forged jump ⇒ `FIX-COUNTER-GAP`.
- **One durable log set, no index to desync or launder.** Aggregation is fail-closed: a tampered
  sibling log (`FIX-SIBLING-TAINTED`) refuses the append rather than trusting a corrupt high-water.
- Known bound (out of scope, shared by any file-based store): deleting a run dir discards its
  history. File protection is the hooks' job (M6); the counter logic does not defend deletion.

## P11 — dmc-context-recovery.py

`observe()` gathers OBSERVED git state from the target worktree — `status --porcelain`, upstream
`rev-list --left-right --count`, HEAD, `--git-dir` merge/rebase/cherry-pick markers — with **zero
writes**, and `to_facts()` translates it into the v0.5.7 `--from` facts shape. The copied
`dmc-v0.5.7-resume-recovery.sh` is invoked as a read-only bash subprocess (`resume_run`); its verdict
is stored **verbatim** into `runs/<run-id>/recovery.json` with the parsed `next_action`. No resume
logic is re-implemented.

**Reuse proof (byte-verbatim, divergence REFUSE).** Self-test S3 asserts the stored
`verdict_verbatim` byte-equals a direct `bash dmc-v0.5.7-resume-recovery.sh --from facts.json` call
(same exit). `--validate` re-runs the copied tool on the stored facts and REFUSES on any divergence
(`REC-DIVERGENCE`) — the same reuse-by-invocation contract T009e uses for v0.5.5.

**Halt-on-delta (never auto-reconcile).** Before consulting v0.5.7 for a next action, three
declared-vs-observed deltas HALT with the diff and `next_action = HALT_AND_ASK`, editing no state:
`moved-HEAD` (`--expect-head` ≠ observed HEAD), `dirty-outside-scope` (dirty tracked path outside the
`--scope-lock` authorized set), `half-applied` (index ≠ worktree on a path, or an interrupted
merge/rebase/cherry-pick). A `--reconcile` request on a delta is explicitly refused
(`REC-NO-AUTO-RECONCILE`) and leaves `run.json` byte-identical.

## Negative controls (each a real REFUSE)

| Control | Mechanism | Result |
|---|---|---|
| attempt at/over bound with verdict ≠ STOP | `record_reasons` `FIX-BOUND-NOT-STOP` | REFUSE (N2) |
| attempt < 1 | `record_reasons` `FIX-BAD-ATTEMPT` | REFUSE (N1) |
| counter decreasing for same (plan_hash, check_id) across a fresh run | `cross_run_reasons` `FIX-RESET-GAMING` + append `FIX-CROSS-RUN-TAINTED` + `--validate` exit 3 | REFUSE (N5/N5b/N5c) |
| files_touched entry with `..` (and absolute) | `rel_ok` `FIX-BAD-FILES-TOUCHED` | REFUSE (N3/N3b) |
| within-file counter decrease | `validate_log` `FIX-LINE-n-COUNTER-DECREASE` | REFUSE (N4) |
| tampered own-log (append-only chain) | `validate_log` `FIX-LINE-0-TAMPER` + append `FIX-LOG-TAINTED` | REFUSE (N6/N6b) |
| P11 `--reconcile` on an observed delta | halt + diff, `REC-NO-AUTO-RECONCILE`, state unchanged | HALT not reconcile (S9/S9b) |

## P11 scenario matrix

| Scenario | Setup | Outcome |
|---|---|---|
| clean-resume | clean tree, HEAD matches, approved plan, verification NONE | no delta ⇒ v0.5.7 `next_action VERIFY`, exit 0 (S1/S2) |
| dirty-outside-scope | tracked `src.txt` dirty, scope.lock authorizes only `other.txt` | HALT, delta lists `src.txt` (S7); in-scope dirty does not halt (S7b) |
| moved-HEAD | `--expect-head` ≠ observed HEAD | HALT `moved-HEAD`, exit 1 (S6) |
| half-applied | `src.txt` staged then edited (index ≠ worktree, "MM") | HALT `half-applied` with the path (S8) |

## Verification commands run

- `python3 -m py_compile bin/lib/dmc-fixloop.py bin/lib/dmc-context-recovery.py` ⇒ OK.
- `python3 -B bin/lib/dmc-fixloop.py --self-test` ⇒ 24/0, exit 0.
- `python3 -B bin/lib/dmc-context-recovery.py --self-test` ⇒ 14/0, exit 0.
- `bin/dmc mirror-check` ⇒ PASS (copied `dmc-v0.5.7-resume-recovery.sh` byte-identical to original).
- `bash bin/lib/dmc-v0.5.7-resume-recovery.sh --self-test` ⇒ 18/0 (interface unchanged; invoked, not edited).
- `grep -RInE 'claude-(opus|sonnet|haiku|fable|mythos)|gpt-[0-9]'` over both files ⇒ empty (Ring-0 model-name-free).
- `git status --porcelain` ⇒ only the two new `bin/lib/dmc-*.py` files added by T009f; no `__pycache__`;
  `dmc-v0.5.7-resume-recovery.sh` original and copy unchanged.

## Not touched

`bin/dmc`, `bin/lib/dmc-v0.5.7-resume-recovery.sh` (original + copy), `bin/lib/dmc-instance-validate.py`,
all T009a–e modules, `.claude/**`, the six M3 schema docs, `docs/MILESTONES.md`, main/master. No
`bin/lib/dmc-v0.*` added. No git add/commit/push. No live/network/secret access.
