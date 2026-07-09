# Build Evidence — fable-core Cycle D-core: v1.1 measurement layer (dmc-fable-core-d-runmetrics)

Date: 2026-07-09 · Branch: `claude/dmc-fable-core` · Envelope: this-session AskUserQuestion
"전체 비준" (A→D-core→C→B; critic-APPROVE-conditional; LOCAL-commit ceiling; push/main a separate
human gate).

## Chain

1. Plan Rev 1 (Fable 5, planner lane) → **critic r1 (Opus, fresh) = NEEDS_CLARIFICATION** — 2
   required AC-precision fixes: REQ field-count off-by-one (19→**20**), AC5 vacuous-pass
   (ledger-out-of-git passable with a silently-broken default write)
   (`.harness/evidence/dmc-fable-core-d-critic-r1.json`).
2. Plan Rev 2 folded both + 2 recommendations (default-ledger ALLOW vs `--ledger`-override
   `out_refused` split; AUDIT_BLOCK structural offline self-audit AC) → **critic r2 (Opus, fresh)
   = APPROVE, 0 blockers** (`.harness/evidence/dmc-fable-core-d-critic-r2.json`).
   `verdict validate` VALID ×2; `verdict gate` PASS (plan-bound, plan_hash `a3159043…`).
3. **Run `dmc-run-c78c84750bcc`** — `run start` + **manual arming** per the registered run-start
   defect (scope-input authored from the plan table → `dmc-scope-lock.py --compile` → `--validate`
   VALID → live probes: out-of-scope Bash write deny rc4 / in-scope adjudicate ALLOW). 5-path lock,
   bounds 5/700/40, landmark_authorized on `bin/dmc` (enforcement) + `docs/MILESTONES.md` (release).
4. **Executor (Opus)** built the recorder (554 lines) + `bin/dmc` verbs + docs/ignore under the
   armed window. One in-build fix: the AC5 self-audit initially matched its own PASS-message token
   list → moved inside the AUDIT_BLOCK sentinel (the frozen family's own pattern); recorder
   self-test 9/0. All in-mandate suites green (selftest all-modules 0 FAIL incl. recorder,
   mirror-check PASS + no stray dmc-v0.*, linkcheck clean, effort 14/0 / course 20/0 through the
   new verbs, docs-only→light byte-identical to direct lib invocation).
5. **AC7 default-path probe (orchestrator, post-suspend):** `bin/dmc metrics record --from
   .harness/evidence/dmc-fable-core-d-record-probe.json` → exit 0; `.harness/metrics/ledger.jsonl`
   exists, 1 line, all 20 REQ fields, redacted-clean; `git status` clean of `.harness/metrics`
   (ignore line effective); rollup row_count 1. **The first real ledger row is this run's own
   metrics** — the measurement layer measured its own build.
6. **Independent verifier (Opus, fresh) = PARTIAL** (`.harness/verification/dmc-run-c78c84750bcc.md`)
   — every substantive AC PASS on independent re-run; sole gap: dirty-tree `selftest --all` read
   **801/4/3** vs pinned 802/3/3. Root-caused (not a defect, not change-caused): frozen
   `dmc-v0.6.0-verify.sh` **V15 reads the LIVE `git status --porcelain`** and FAILs on tracked
   modifications outside docs/plans/verification — the PRE-EXISTING `.codex/config.toml` alone
   trips it; v0.6.0 byte-unchanged. Registered as the **THIRD environmental selftest gotcha**
   (after mode-coupling and env-var-leak): working-tree-diff coupling.
7. **Green set minted** (handoff learning-(d) recipe, disarmed window): receipts ×5
   (`dmc-evidence-ledger mint`, machine-verifiable checkers) + coverage-shape `verify-plan.json` +
   `findings.json` (v0.6.3 gate ALLOW) + `goal-ledger.json` (v0.6.4 trace ALLOW) +
   `decision-record.json` (v0.6.5 answer ANSWERED) + `approvals.jsonl` (appender-bound,
   plan_approval + release, validate VALID). Disclosed deviation: `dmc-verify-plan.py compile` NOT
   used — it requires an acceptance/radius upstream chain that the established v1.0.5 recipe also
   did not preserve; the hand-authored coverage shape is the proven form the gate's
   `required_checks()` reads. **`dmc gate release --full` = PASS** — 8 PASS + non-degrading
   landmark FLAG (bin/dmc, recorder, MILESTONES), no `DMC_GATE_PROTECTED` override (none of the
   paths in DEFAULT_PROTECTED).
8. **Change commit `109fed8`** (5 files, +697/−2). **Clean-tree confirmation** (verifier's
   prescribed action; `.codex/config.toml` stashed): legacy aggregate
   `tools=49 PASS=802 FAIL=3 N/A=3` + **"PASS aggregate == pinned baseline exactly"** — the
   dirty-tree 801/4/3 closed exactly as root-caused.
9. **Lockstep completion `4c4bf4b`:** the clean-tree `--all` surfaced ONE real FAIL — m8
   `test-manifest-drift.sh` 9/1: the emitted install manifest lists
   `bin/lib/dmc-metrics-recorder.py`, the committed `INSTALL_MANIFEST.md` predated it (a
   one-sided-lockstep state the anti-patchwork rules forbid). Root cause: **plan omission** — the
   Relevant Files table missed the generated manifest. Fix: deterministic regen via
   `.claude/install/dmc-install.sh --emit-manifest` (diff = exactly the one recorder line); m8
   suite green after (manifest-drift 10/0, install-roundtrip 83/0, idempotency 17/0,
   doctor-negcontrols 16/0). Committed as a disclosed companion fix.

## Registered learnings / open items (user-gated)

- **4th selftest gotcha registered:** frozen v0.6.0 V15 couples `--all` to the live working tree —
  any tracked modification outside docs/plans/verification reads as 801/4/3. Clean tree/CI
  authoritative. (v1.1+ candidate: mode/tree-aware selftest expectation, already registered.)
- **Plan-authoring rule:** any plan that adds/removes a shipped `bin/`/`bin/lib/`/hook file MUST
  include `INSTALL_MANIFEST.md` (generated lockstep artifact) in its Relevant Files. This cycle
  missed it; caught by the suite, fixed by regen.
- **`run start` arming defect still open** (manual compile procedure used and probe-proven for
  this run; fix cycle vs v1.1+ = user's call).
- **Push-gate disclosure flag carried:** strategy memo product codenames (Product-A / Product-B /
  Product-C) become public on merge to main — conscious ratification required at the push gate.

## Commits (LOCAL only — push is a human gate)

- `109fed8` feat(dmc): v1.1 measurement layer — run-metrics recorder + effort/course reachability
- `4c4bf4b` fix(dmc): regenerate INSTALL_MANIFEST — ship the v1.1 metrics recorder
- Records commit (this file + plan + verdicts + probe record + verification report).
