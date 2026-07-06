# Plan: DMC v1 M6 — Hook/Guard Hardening (Ring-1 shims over Ring-0)

Plan ID: dmc-v1-m6-hook-hardening · Date: 2026-07-06 · Format: PLAN_SCHEMA.md
Milestone-scoped plan for master plan §M6 (DMC-T011), extended per the approved direction plan
`.harness/plans/dmc-v0.5-codex-adapter-direction.md` (post-Bash diff guard + semantic
verification cross-checks). **DRAFT** — requires its own critic pass + human gate before any
implementation.
**Rev 2** — revised after DMC critic REJECT (R1, persisted at
`.harness/evidence/dmc-v1-m6-critic-verdict-r1.json`). Blockers closed: (B1) fixture set now
covers the ENTIRE pre-M6 `.claude/hooks/` tree incl. `lib/**` + settings.json, bytes pinned to
the pre-M6 HEAD commit; (B2) explicit **shim runtime contract** — the pinned 802/3/3 legacy
baseline EXECUTES the live hooks with behavioral assertions (empty stdout on allow, npm-install
ask, destructive/secret denies, all-modes secret floor, synthetic-`CLAUDE_PROJECT_DIR`
robustness), all six now REQUIRED compatibility-matrix rows; (B3) verdict-gate value
enforcement wired (run-arming refuses a plan-bound REJECT — adds a floor, never opens a gate,
C11 intact); (B4) tasks renumbered DMC-T011.1–.4 (collision with master §M6.5 DMC-T011b
resolved); (B5) BLOCKED specified as a **sidecar marker** `.harness/runs/<run-id>/blocked.json`
(M4 state machine untouched); (B6) unarmed semantics specified (static deny floor always;
scope/diff guards arm only with an active run); (B7) master's ultrawork stop-block E2E
restored as an acceptance criterion. Optional: per-hook mode-floor matrix rows, committed-
replica `--all` note, fixture-byte pinning, `dmc-router.sh` dropped to not-edit. This is the FIRST protected-surface milestone: it edits `.claude/hooks/*` and
`.claude/settings.json`, which every prior milestone was forbidden to touch.
**Rev 3** — mid-run amendment (human-gated 2026-07-06, granted via AskUserQuestion after a
critic delta REVISE→pins-folded cycle): adds the scoped dmc-scope-lock.py compile-site
snapshot refresh + run-state CONTENT tamper detection (write-once operative snapshot in
run.json, `--out` isolation, approvals byte-prefix check), closing the T011.2 handoff
sequencing gap tamper-safely (executor Option A); pins the armed out-of-project Edit/Write
DENY. Scope-lock additions authorized at the same gate: this plan file (amendment apply) +
bin/lib/dmc-scope-lock.py.

## Goal

Turn the six live v0.x hooks into thin, auditable Ring-1 shims over Ring-0 verdict CLIs, close
the audited enforcement bypasses (Bash write bypass, scope self-escalation, fail-open on
missing interpreter, secret-guard wrong keys, unarmed stop gate, `git apply` unblocked), add
the post-Bash diff guard and semantic verification-report cross-checks, and prove the
canonical-five bypass classes (1)(2)(3) are denied while every legitimate operation still
passes — with a tested single-revert rollback to the byte-identical v0.6.5 hook surface.

## User Intent

Classify: **feature** (secondary: refactor — hooks become shims; the enforcement logic moves
to Ring-0).

## Current Repo Findings

- Finding: `scope-guard.sh` matches `Edit|Write` only, reads legacy
  `.harness/runs/current-scope.txt`, auto-allows `.harness/runs` paths (self-escalation), and
  fails OPEN when python3 is missing; Bash-mediated writes bypass scope entirely.
  Source: `.claude/hooks/scope-guard.sh`; master plan §Current Repo Findings (audit §3).
- Finding: `secret-guard.sh` reads `tool_input.file_path`/`glob` but Grep's dir param is
  `path` and Glob's is `pattern`, so secret-targeting calls can be missed; matching is
  case-sensitive.
  Source: `.claude/hooks/secret-guard.sh`; master plan §Assumptions row 2.
- Finding: `stop-verify-gate.sh` is keyword-triggered and existence-only — a FAIL report (or a
  completion phrased without the keywords) satisfies it; it never checks report content,
  receipts, or scope.
  Source: `.claude/hooks/stop-verify-gate.sh`.
- Finding: Ring-0 already ships the primitives the shims need — immutable
  `scope.lock.json` compile + adjudicate (`bin/lib/dmc-scope-lock.py`), typed approvals,
  evidence ledger with `check_id` receipts, run state machine, `dmc validate verification`
  (structural), verdict gate — all currently consumed by nothing at runtime.
  Source: `bin/dmc help`; M4/M5 closure records in `.harness/plans/dmc-v1-runtime-upgrade-handoff.md`.
- Finding: `pre-tool-guard.sh` does not deny `git apply` / `patch`, the documented worker
  no-mutation loophole.
  Source: master plan §Current Repo Findings (audit §3).
- Finding: the master plan requires pre-M6 hooks preserved as committed fixtures BEFORE
  editing, and a single revert commit restoring v0.6.5 hooks+settings byte-identically.
  Source: `.harness/plans/dmc-v1-runtime-upgrade-handoff.md` §Next step.

## Relevant Files

| Path | Reason | Allowed to Edit |
|---|---|---|
| tests/fixtures/hooks-v0.6.5/** (new) | byte-identical fixtures of the ENTIRE pre-M6 `.claude/hooks/` tree (every file, incl. `lib/**` and worker guards) + `.claude/settings.json`, committed BEFORE any hook edit; bytes pinned to the pre-M6 HEAD commit hash recorded in the fixture README | yes (new) |
| .claude/hooks/pre-tool-guard.sh | shim over Ring-0 Bash classifier; git apply/patch deny; fail-closed-in-active | yes (protected — this milestone's explicit authorization) |
| .claude/hooks/scope-guard.sh | shim over `dmc` scope adjudication vs scope.lock; self-escalation fix | yes (protected — same) |
| .claude/hooks/secret-guard.sh | superset keys (file_path, glob, pattern, path) + case-insensitive | yes (protected — same) |
| .claude/hooks/stop-verify-gate.sh | shim over quick receipt-coverage + semantic report gate; keyword regex removed | yes (protected — same) |
| .claude/hooks/evidence-log.sh | post-Bash diff guard invocation point (PostToolUse Bash) | yes (protected — same) |
| .claude/hooks/dmc-router.sh | natural-activation router — NOT edited in M6 (no M6 need identified; any future need = plan rev with justification) | no |
| .claude/settings.json | matcher/event wiring for the above | yes (protected — same) |
| .claude/hooks/lib/** | shared shim helpers | yes (protected — same) |
| adapters/claude-code/** (new) | Ring-1 adapter home for shim logic shared by hooks | yes (new) |
| bin/dmc, bin/lib/dmc-bash-radius.py (new), bin/lib/dmc-postbash-diff.py (new), bin/lib/dmc-verify-crosscheck.py (new), bin/lib/dmc-stop-gate.py (new) | Ring-0 verdict CLIs the shims call (names indicative; final names bound at implementation) | yes (additive; single-owner rule for bin/dmc) |
| bin/lib/dmc-run-lifecycle.py | MINIMAL edit: run-arming consumes the verdict gate and refuses a plan-bound REJECT (B3); BLOCKED sidecar helpers (write/read/resolve `blocked.json`). STATES tuple and run.json schema UNCHANGED; existing run-core self-tests preserved, new ones added | yes (scoped to these two concerns) |
| bin/lib/dmc-scope-lock.py | MINIMAL edit (Rev 3 amendment, human-gated 2026-07-06): inline operative-snapshot refresh at the sanctioned `cmd_compile` lock-write site ONLY — atomically bound to the lock write; NO standalone refresh verb anywhere (laundering-hole prohibition). Compile may gain STRICTER refusals (operative-snapshot-exists / write-once); no loosening. Nothing else in this file changes; adjudicate/seal semantics and existing self-tests untouched except additively | yes (scoped to this one concern) |
| .harness/schemas/*.schema.md (blocked-marker sidecar; any new verdict artifact) | schema additions | yes (additive only) |
| tests/fixtures/m6/** (new) | adversarial + compatibility fixtures | yes (new) |
| .harness/evidence/dmc-v1-m6-*.md, .harness/verification/dmc-v1-m6-*.md | evidence/verification | yes |
| .claude/hooks/worker-result-check.py, .claude/hooks/worker-context-guard.sh | M7's surface | no |
| .claude/workers/providers/** | never | no |
| .claude/skills/**, .claude/agents/** | M5 surface, not this milestone | no |
| .claude/install/** | M8's surface | no |

## Out of Scope

- Worker validator hardening (M7), installer work (M8), CI (M9), Codex adapter (M6.5).
- `dmc-router.sh` (not edited in M6); any M4 state-machine change (STATES tuple, run.json
  schema) — BLOCKED is a sidecar marker, not a state.
- Any relaxation of an existing deny; any live/network call; any secret access.
- Editing `.harness/evidence/dmc-v0.*` originals or bin/lib copies (mirror-check must stay
  green); any masking/"fixing" of the pinned 802/3/3 legacy baseline (carry-forward #1).
- Staging/commit/push (separate human gates); `docs/MILESTONES.md`.

## Proposed Changes

- Change: commit pre-M6 fixtures FIRST — byte-copies of the ENTIRE `.claude/hooks/` tree
  (every file, incl. `lib/**` and the worker guards, since `.claude/hooks/lib/**` is an
  editable row) + `.claude/settings.json` under `tests/fixtures/hooks-v0.6.5/`, with the pre-M6
  HEAD commit hash recorded; the rollback test `cmp`s the WHOLE tree, proving a single revert
  commit restores the live surface byte-identically.
  Files: tests/fixtures/hooks-v0.6.5/**, tests/fixtures/m6/**
  Rationale: master-plan safeguard; makes the protected-surface edit reversible by
  construction with no uncovered path (critic B1).
- Change: Ring-0 verdict CLIs (additive) — (i) Bash write-radius classifier: classifies a
  candidate Bash command's write radius (deny `git apply`/`patch`; deny/ask redirection,
  `sed -i`, `tee`, `mv`/`cp` into non-scope; fail-closed on unparseable in active mode);
  (ii) post-Bash diff check: `git diff --name-only` + status porcelain vs the compiled
  `scope.lock.json` — out-of-scope change ⇒ verdict BLOCKED with the offending paths; NARROW
  internal exemption (`.harness/evidence/`, `.harness/verification/`, append-only run logs);
  Bash-mediated writes to `scope.lock.json`, `approvals.jsonl`, `run.json` DENIED (state
  mutations only via the `dmc` CLI — canonical fixture (2)); (iii) semantic
  verification-report cross-check: report run-id == active run; Changed Files ⊆ approved
  scope and consistent with `git diff --name-only`; Final Status PASS refused when a required
  verification command is absent/failed or skipped without a recorded reason; (iv) stop-gate
  quick check: receipts ⊇ required checks for the active run + the semantic cross-check —
  state-file-only, <2s budget; (v) verdict-gate VALUE enforcement (carry-forward #5, critic
  B3): the run-arming path consumes the verdict gate and REFUSES arming when the plan-bound
  critic verdict is REJECT — a machine floor that never opens a gate (C11: approval remains
  human-only); a NEEDS_CLARIFICATION verdict does NOT refuse arming (the human gate decides,
  as today); negative-control fixture (REJECT verdict ⇒ `dmc run start` refused);
  (vi) BLOCKED mechanism (critic B5): a sidecar marker `.harness/runs/<run-id>/blocked.json`
  (reason, offending paths, created-by check_id) written via the `dmc` CLI by the post-Bash
  guard, consumed by the stop gate (BLOCKED ⇒ stop held), cleared only by an explicit `dmc`
  resolution command — the M4 state machine (STATES tuple) and run.json schema are UNTOUCHED.
  RUN-STATE TAMPER DETECTION (Rev 3 amendment, human-gated; critic delta pins 1–3): path-set
  diffs cannot see an in-place tamper, so `scope.lock.json` is checked by CONTENT comparison
  against an operative-snapshot record. Pins: (P1) the operative-snapshot record is
  **write-once per run** — it is written only by the FIRST sanctioned `cmd_compile` for the
  run; any later compile for that run-id is REFUSED regardless of lock-file existence (closes
  the delete-lock-then-recompile laundering hole; also yields the no-recompile invariant the
  current code lacks). Negative fixtures: delete-then-recompile ⇒ refused; second compile ⇒
  refused. (P2) the refresh fires ONLY when the compile destination equals the active run's
  default lock path — a compile to any `--out` override never touches the operative snapshot
  (fixture: `--out` compile ⇒ snapshot unchanged). (P3) the operative-snapshot record lives
  INSIDE `run.json` (already in the run-state DENY set; dmc-CLI-only writer) as a content-hash
  entry — Bash/Edit writes to it are denied (fixture). Legitimate `dmc` CLI lifecycle writes
  must not trip the guard: `approvals.jsonl` is append-only and hash-chained, so its check is
  "prior snapshot is a byte-PREFIX of current AND the chain validates" — no refresh at the
  append site, no dmc-approvals.py edit expected; if implementation finds that false, the
  executor STOPS and reports for a further amendment instead of improvising. Amendment
  mechanics: for the ACTIVE LEGACY run (current-scope.txt, no compiled lock) a human-gated
  scope update appends to current-scope.txt (the legacy mechanism the guard itself names); in
  the lock world, scope expansion is a NEW prev-chained lock minted under re-approval — never
  an in-place lock edit (the dmc-scope-lock immutability doctrine); fixtures exercise the
  new-lock path. Out-of-project Edit/Write while armed stays DENY (no relaxation of an
  existing deny; scratchpad-class exceptions only via the audited allowlist file, default
  empty; unarmed ⇒ L1 stands down as before) — pinned in the T011.4 matrix.
  ARMING SEMANTICS (critic B6): enforcement is layered — **L0 static deny floor**
  (catastrophic, secret-path, `git apply`/`patch`) applies in ALL states, needs no run and no
  Ring-0 lookup; **L1 dynamic run-scoped verdicts** (write-radius vs scope, post-Bash diff,
  receipt coverage) arm ONLY while a run is active (`current-run-id` present). No active run
  ⇒ L1 stands down (the repo's normal state, the M6 build itself, and OMC coexistence stay
  workable); fail-closed-on-missing-interpreter applies to L1 in active mode with an armed
  run.
  Files: bin/lib (new modules), bin/lib/dmc-run-lifecycle.py (scoped edit per Relevant
  Files), bin/dmc (verb registration — single owner)
  Rationale: enforcement logic lives in Ring-0 so M6.5 Codex shims reuse it unchanged.
- Change: hooks become shims — each hook parses tool JSON (superset keys, case-insensitive
  paths), calls the Ring-0 CLI, and translates the verdict to the host deny/ask/allow
  envelope; stop gate arms from run state (no keyword regex); suspended runs do not block
  stop. **SHIM RUNTIME CONTRACT (critic B2)** — the pinned 802/3/3 legacy baseline EXECUTES
  the live hooks with behavioral assertions; the shims MUST preserve, unmodified: (1) empty
  stdout on allow; (2) ask-tier on `npm install`-class commands; (3) deny on
  destructive-rm-class and dot-env secret-read commands; (4) the secret deny floor in ALL
  modes (active|passive|off); (5) correct behavior under a synthetic `CLAUDE_PROJECT_DIR`
  temp dir with no `bin/dmc` and no `.harness` — Ring-0 CLI resolution is script-relative,
  and when Ring-0 is absent the L0 static floor still fires inline (no dynamic checks to
  arm); (6) fail-closed in active mode when the interpreter is missing AND a run is armed
  (clear actionable error) — passive/off never brick a session (OMC coexistence). All six are
  REQUIRED compatibility-matrix rows; per-hook × per-mode (active/passive/off) expected
  behavior is pinned in the matrix. Carry-forward #1 stands: the baseline is never edited or
  masked to make this pass. Two further shim properties (critic O5/O7): the Edit/Write
  internal-allow list is REPLACED by the same NARROW exemption as the post-Bash guard
  (`.harness/evidence/`, `.harness/verification/`, append-only run logs — the current blanket
  `.harness/runs` + `.harness/decisions` auto-allow at scope-guard.sh:73-78 is removed;
  run-state files mutate only via the `dmc` CLI); and the secret-guard shim preserves the
  path-only property — it decides by path and NEVER opens or reads file contents.
  Files: .claude/hooks/*.sh, .claude/hooks/lib/**, .claude/settings.json, adapters/claude-code/**
  Rationale: audit bypass closure; identical verdicts for both adapters; baseline parity by
  contract, not by luck.
- Change: adversarial + compatibility suites — negative controls for canonical five
  (1) Bash-mediated write outside scope, (2) agent edit of its own scope/lock file,
  (3) secret read via Glob `pattern`/case-variant paths, plus `git apply` deny,
  interpreter-absent deny-in-active (armed run), and verdict-REJECT arming refusal; a
  compatibility matrix of legitimate operations that must all still pass, REQUIRED rows:
  in-scope edits/reads/evidence writes/`dmc` CLI state mutations; the six legacy behavioral
  rows from the shim runtime contract; per-hook × per-mode (active/passive/off) floor rows;
  UNARMED rows (no active run: Bash writes and edits pass L1 untouched, L0 static floor still
  denies catastrophic/secret/`git apply`); untracked-noise rows (critic O6: the post-Bash
  guard snapshots the worktree state at ARMING time and flags only changes introduced after
  it — pre-existing untracked noise such as local run archives never trips BLOCKED; and
  `bin/dmc selftest` under an armed run stays green — self-tests write only to mktemp dirs);
  plus the **ultrawork stop-block E2E** (master §M6
  acceptance, critic B7): fixture transcript arms a run via the ultrawork path (`dmc run
  start` binding shipped in M5), attempts stop with missing receipts/verification ⇒ blocked;
  with receipts + verification ⇒ passes; suspended ⇒ passes. Committed-replica note (carry-
  forward #7): the two working-tree-drift legacy checks FAIL `--all` on a dirty tree — the
  committed-replica `--all` proof + post-commit live re-run remains this milestone's closure
  pattern.
  Files: tests/fixtures/m6/**, bin/dmc (selftest m6 section)
  Rationale: master plan acceptance; prevents over-blocking regressions and baseline drift.

## Acceptance Criteria

- Criterion: canonical-five fixtures (1)(2)(3) are denied; `git apply`/`patch` denied;
  interpreter-absent in active mode (armed run) ⇒ deny with actionable error.
  Verification Method: M6 adversarial suite (negative controls), exit 0.
- Criterion: post-Bash out-of-scope change ⇒ run BLOCKED with evidence entry, and stop gate
  refuses completion until resolved; Bash write to scope.lock.json/approvals.jsonl/run.json
  ⇒ DENIED even mid-run.
  Verification Method: dedicated fixtures in the adversarial suite.
- Criterion: semantic cross-check refuses: mismatched run-id, changed-files outside scope,
  PASS with a failed/skipped-without-reason required command.
  Verification Method: refusal fixtures per case, exit codes asserted.
- Criterion: every compatibility-matrix legitimate operation still passes — including the six
  legacy behavioral rows (empty-stdout-on-allow, npm-install ask, destructive/secret denies,
  all-modes secret floor, synthetic-CLAUDE_PROJECT_DIR robustness) and the per-hook per-mode
  floor rows; stop-path quick gate under 2s; suspended run does not block stop.
  Verification Method: compatibility suite + latency measurement.
- Criterion: with NO active run, the L1 guards stand down (a Bash write and an Edit outside
  any scope both pass) while the L0 static floor still denies catastrophic/secret/`git apply`
  fixtures.
  Verification Method: unarmed fixture pair (positive + negative) in the suite.
- Criterion: a plan-bound critic-verdict REJECT refuses `dmc run start` (arming floor);
  approval remains human-only (no gate opened by any machine verdict).
  Verification Method: negative-control fixture + R12/C11 re-test over the new path.
- Criterion: ultrawork-path stop-block E2E — armed run + missing receipts/verification ⇒ stop
  blocked; receipts + PASS verification ⇒ stop allowed; suspended ⇒ stop allowed.
  Verification Method: E2E fixture transcript in the M6 suite.
- Criterion: `bash -n` clean on all touched shell files; `bin/dmc selftest --all` equals the
  pinned baseline (802/3/3, UNMODIFIED — no masking, carry-forward #1) + new M6 sections at
  0 FAIL; mirror-check green; run-core self-tests all green after the scoped
  dmc-run-lifecycle.py edit.
  Verification Method: syntax pass + selftest --all vs baseline (committed-replica pattern) +
  selftest run-core.
- Criterion: single revert commit restores the pre-M6 `.claude/hooks/` tree (every file,
  incl. `lib/**`) + settings.json byte-identically.
  Verification Method: rollback test — `cmp` over the WHOLE tree against
  tests/fixtures/hooks-v0.6.5/ (pinned to the recorded pre-M6 commit hash).

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Over-blocking legitimate work (classifier false positives) | medium | ask-tier for ambiguous forms; compatibility matrix is a required suite; allowlist file for measured exceptions |
| Fail-closed bricks sessions on hosts missing python3 | medium | actionable error text; passive mode unaffected; doctor check lands in M8 |
| Stop-gate latency or over-blocking | medium | state-file-only quick tier; `dmc run suspend` escape hatch; latency asserted in suite |
| Protected-surface edit regresses an existing guarantee | high | pre-M6 byte fixtures committed first; adversarial suite includes all previously-passing guard tests; single-revert rollback proof |
| Post-Bash guard races (checkpoint diff noise, concurrent edits) | medium | compare against both HEAD and the run checkpoint; BLOCKED is sticky until human/`dmc` resolution — never auto-cleared |
| Shim behavior diverges from the legacy baseline's live-hook behavioral assertions → 802/3/3 unattainable without masking | high | shim runtime contract (six REQUIRED matrix rows); baseline never edited (carry-forward #1); committed-replica `--all` proof + post-commit live re-run as closure condition |
| Scoped dmc-run-lifecycle.py edit regresses M4 run-core | medium | STATES/run.json untouched; existing run-core self-tests must stay green; new tests for arming refusal + blocked sidecar |
| bin/dmc contention with other milestones | low | single-owner rule: one task registers all new verbs |

## Assumptions

| Assumption | Confidence | How to Verify |
|---|---|---|
| Claude Code hook JSON keys: Glob param `pattern`, Grep dir param `path` | high | verify against harness docs before implementation; shims read a superset regardless |
| Ring-0 M4 primitives (scope.lock, receipts, run state) are sufficient for the shims without schema changes | medium | first implementation task probes; schema additions are authorized additive fallback |
| Hook execution environment provides git + python3 in active installs | medium | fail-closed path covers absence; M8 doctor will pre-check |

## Execution Tasks

- [ ] DMC-T011.1: Pre-M6 byte fixtures (ENTIRE .claude/hooks tree incl. lib/** + settings.json,
  pre-M6 commit hash recorded) + whole-tree rollback test (commit BEFORE any hook edit).
  Files: tests/fixtures/hooks-v0.6.5/**, tests/fixtures/m6/**
  Notes: fixture commit is its own reviewable unit; nothing else in it.
- [ ] DMC-T011.2: Ring-0 verdict CLIs (bash radius, post-Bash diff, semantic cross-check,
  stop-gate quick, verdict-REJECT arming refusal, blocked.json sidecar helpers) + selftest
  sections + schemas (blocked-marker; others if needed).
  Files: bin/lib/*, bin/lib/dmc-run-lifecycle.py (scoped), bin/dmc, .harness/schemas/*
  Notes: additive except the scoped run-lifecycle edit (STATES/run.json untouched;
  run-core green); single-owner for bin/dmc; negative controls per CLI.
- [ ] DMC-T011.3: Hook shims + settings wiring (superset keys, case-insensitive, shim runtime
  contract incl. L0 inline static floor + script-relative Ring-0 resolution,
  fail-closed-in-active with armed run, stop gate armed from run state, post-Bash guard wired
  to PostToolUse Bash).
  Files: .claude/hooks/*.sh (except dmc-router.sh), .claude/settings.json,
  .claude/hooks/lib/**, adapters/claude-code/**
  Notes: protected surface — begins only after T011.1 is committed.
- [ ] DMC-T011.4: Adversarial suite + compatibility matrix (legacy behavioral rows, per-mode
  rows, unarmed rows) + ultrawork stop-block E2E + latency assert + whole-tree rollback
  proof; evidence + verification report.
  Files: tests/fixtures/m6/**, .harness/evidence/dmc-v1-m6-*.md, .harness/verification/dmc-v1-m6-*.md
  Notes: verification report must pass `dmc validate verification`; task numbering
  DMC-T011.1–.4 is collision-free vs master §M6.5's DMC-T011b (carry-forward #8).

## Verification Commands

| Command | Reason | Required |
|---|---|---|
| bash -n .claude/hooks/*.sh adapters/claude-code/**/*.sh | syntax floor | yes |
| bin/dmc selftest --all | pinned baseline 802/3/3 + new sections 0 FAIL | yes |
| bin/dmc mirror-check | copy-routed tools untouched | yes |
| M6 adversarial suite (canonical five (1)(2)(3), git apply, fail-closed-armed, post-Bash, semantic refusals, verdict-REJECT arming refusal) | bypass closure proof | yes |
| M6 compatibility matrix suite (incl. six legacy behavioral rows, per-hook per-mode rows, unarmed rows) | no over-blocking; baseline parity | yes |
| ultrawork stop-block E2E fixture | master §M6 acceptance (critic B7) | yes |
| bin/dmc selftest run-core | scoped run-lifecycle edit regression floor | yes |
| python3 -m py_compile on touched bin/lib/*.py | syntax floor (python) | yes |
| rollback test vs tests/fixtures/hooks-v0.6.5/ (WHOLE tree cmp) | single-revert byte restore | yes |
| git status --porcelain before/after suites | repo cleanliness | yes |

## Approval Status

Status: APPROVED
Approver: wjlee (human release gate; granted via AskUserQuestion in the 2026-07-06 session,
option "APPROVED — M6 구현 착수", after the critic chain R1 REJECT (7 blockers) → Rev 2 →
final APPROVE bound to the frozen pre-approval bytes sha256
45c35fe915ab99088f25595b4f370d90f313a33dd70c2cdc81b7131dbaab717b — verdicts persisted at
.harness/evidence/dmc-v1-m6-critic-verdict-r{1,2,3}.json; r3 is the binding artifact)
Approved At: 2026-07-06

Approval record (verbatim scope of the human gate, 2026-07-06):
- **Approved**: DMC-T011.1–.4 exactly as specified in §Execution Tasks, including the
  protected-surface edits this milestone explicitly authorizes (.claude/hooks/*.sh except
  dmc-router.sh, .claude/hooks/lib/**, .claude/settings.json) and the scoped
  bin/lib/dmc-run-lifecycle.py edit.
- **Pre-authorized**: the T011.1 fixture commit (pre-M6 hook-tree bytes ONLY, its own commit,
  nothing else in it) — granted in the same gate.
- **Explicitly NOT approved**: staging/commit/push of the milestone deliverables (separate
  human gates), M6.5+ work, worker-validator/installer/router edits, any live call, any
  secret access, main/master changes, docs/MILESTONES.md.
