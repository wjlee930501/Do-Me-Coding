# Build Evidence — fable-core Cycle E: run-start scope arming (dmc-fable-core-e-runstart, v1.1.3)

Date: 2026-07-10 · Branch: `claude/dmc-fable-core` (post-redaction history; old shas resolve via
`.harness/evidence/dmc-fable-core-redaction-20260710.md`) · Authorization: user directive
2026-07-10 ("2. 즉시 수정하여 이번에 반영") under the standing fable-core envelope
(critic-APPROVE-conditional; LOCAL-commit ceiling; push/main a separate human gate).

## Chain

1. Plan Rev 1 (Fable 5, planner lane) → **critic r1 (Opus, fresh) = NEEDS_CLARIFICATION, 2
   blockers** (`.harness/evidence/dmc-fable-core-e-critic-r1.json`): **B1** — the `run` dispatch
   is a SHARED `exec` that never returns, so the plan's post-delegation composition was
   unreachable as written; **B2** — the composition recipe was cwd-relative while every
   established caller passes `--root` without cd-ing in (real-repo contamination risk). Plus 3
   advisories (drop the false CLAUDE_PROJECT_DIR claim; refuse-path both-streams byte-identity;
   the `.agents/skills` mirror EXISTS → required lockstep).
2. Plan Rev 2 folded all five → **critic r2 (Opus, fresh) = APPROVE, 0 blockers**
   (`…-e-critic-r2.json`) — r2 additionally adjudicated the `--validate --root` question
   (parsed-and-ignored, harmless) and verified the explicit `--out` equals `default_lock_path`
   so the operative snapshot records (armed-for-real).
3. **Run `dmc-run-17dde24df36f`** — manual arming (THE LAST CYCLE TO NEED IT): 5-path lock
   (bin/dmc enforcement/landmark_authorized; both SKILL.md; the new test; MILESTONES release),
   bounds 5/550/60, `--validate` VALID, probes deny-rc4/allow-rc0.
4. **Executor (Opus)**: `SCOPELOCKLIB` constant; `start` split out of the shared exec group into
   a captured non-exec call (streams untouched; other 6 subcommands keep exec verbatim);
   `--scope-input` consumed at dispatch; `--plan`/`--root` threaded (pointer read, compile
   `--out`, validate all root-rooted); fail-closed teardown (suspend BEFORE pointer removal,
   exit 3 `REFUSED-ARMING:`); success-only single stderr `WARNING` on unarmed starts; both
   SKILL.md files truth-repaired in lockstep (the false "mints and arms … locked scope" claim
   GONE; scope-input shape + no-accepted-scope-no-edit STOP rule added); hermetic 24-assertion
   test (armed-for-real live deny-rc4 probe on a freshly minted lock; teardown residue checks;
   both-stream back-compat byte-identity). All green: 24/0; selftest all-0-FAIL; pinned consumer
   suites m6 38/45/10/11, m7 36/26/23, m9 56/35 (all /0); skills-mirror PASS; agents-md drift
   empty; m8 manifest-drift 10/0; mirror-check PASS; linkcheck clean. Zero deviations.
5. **Independent verifier (Opus, fresh) = PASS**
   (`.harness/verification/dmc-run-17dde24df36f.md`) — own refuse-path byte-identity cross-check,
   own live probes, full diff reading confirming every Rev 2 mechanism, suites re-run.
6. **Green set minted** (4th and final mint): receipts ×3 + coverage verify-plan.json +
   findings/goal/decision (v0.6.x validators exit 0) + approvals (VALID). **Gate PASS** — 8 PASS
   + non-degrading landmark FLAG (bin/dmc, MILESTONES); NO G4 override (`.claude/skills` not
   protected). Candidate staged BEFORE the gate (B-cycle learning applied).
7. **Change commit `944a2ba`** (5 files, +395/−17). **Clean-tree confirmation on a COMMITTED
   REPLICA** (clone --no-hardlinks of HEAD, remote severed — the live-tree stash run was killed
   by a timeout mid-suite with no aggregate emitted; the stash was restored intact and the
   replica pattern used instead, which is the stronger form): aggregate
   `tools=49 PASS=802 FAIL=3 N/A=3` + "PASS aggregate == pinned baseline exactly" +
   `SELFTEST-ALL RESULT: PASS`, SUITE_RC=0, zero new FAILs.

## What this closes

The **run-start arming defect** (registered by Cycle A's verifier; manually compensated in
cycles A/D-core/B/C) is CLOSED at the tool level: `bin/dmc run start --plan P --scope-input S`
arms a validated, immutable, root-rooted scope.lock in one command, and a failed arming can no
longer leave a false-armed run (deterministic teardown). The skill doc now tells the truth and
mandates the armed form + a no-lock-no-edit STOP check. Historical lockless runs remain an
archival fact.

## Registered follow-ups (user-gated, next session)

- committed==regenerated selftest pins for the generated artifacts (INSTALL_MANIFEST, AGENTS.md).
- Codex adapter Block C bypass divergence (v1.2+).
- Consider hard-requiring `--scope-input` (v1.2+, post-pilot).

## Commits (LOCAL only — push is a human gate)

- `944a2ba` feat(dmc): v1.1.3 run-start scope arming — one-command armed start, fail-closed teardown
- Records commit (this file + plan Rev 2 + critic r1/r2 + verification report).
