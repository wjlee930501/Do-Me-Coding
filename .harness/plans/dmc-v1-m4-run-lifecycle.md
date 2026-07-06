# Plan: DMC v1.0 M4 — Run-Lifecycle Core (the spine)

Plan ID: dmc-v1-m4-run-lifecycle · Date: 2026-07-06 · Format: PLAN_SCHEMA.md · Milestone: M4 of `.harness/plans/dmc-v1-runtime-upgrade.md` (master, APPROVED through M3)
Branch: `claude/dmc-v1-runtime-upgrade-c5uch1` @ `3b2d1c4` (M3 shipped + the pre-M4 validate-run hermeticity fix cited in Finding 2). This is a milestone-scoped **DRAFT** execution plan; it does not amend the master's approval state and is not self-approved.

## Goal

Implement the eight run-lifecycle primitives the master assigns to M4 — **P7c (constructive scope-lock), P8, P9, P10, P11, P12, P13, P17** — as additive Ring-0 `bin/**` modules that make the plan→execute→verify loop a persisted, hash-chained, tamper-evident state machine instead of prose. M4 is the spine that later milestones (M5 skill wiring, M6 hook enforcement, M9 E2E) plug into; in M4 itself nothing consumes these artifacts at runtime yet, so the whole milestone is additive and deletable.

## User Intent

Classify: **feature** (secondary: refactor — promotion/wiring of already-shipped v0.5.5/v0.5.7 logic behind new run-fed interfaces; the sole existing-artifact edit is the authorized `evidence-receipt.schema.md` `check_id` extension).

## Current Repo Findings

- Finding: M3 shipped the M4 contracts as forward-declared schemas — `scope-lock.schema.md`, `acceptance.schema.md`, `fixloop.schema.md` each state "validator lands in M4". M4 implements those validators plus the run/approval/evidence/checkpoint/recovery tools.
  Source: `.harness/schemas/{scope-lock,acceptance,fixloop}.schema.md` (headers).
- Finding: the earlier `validate-run` hermeticity defect (it hard-read the gitignored `.harness/runs/current-run.md`, crashing the default selftest to exit 1) is **already FIXED pre-M4** by commit `3b2d1c4` ("fix(dmc): make instance-validator self-tests hermetic + refresh t008b evidence transcript"): `selftest_run` is now fully synthetic (SYNTH_RUN + a U2 extra-section case; no gitignored-state read), and a new `ST.check` wrapper turns any fixture exception into a graceful FAIL so the section footer always prints. Default `bin/dmc selftest` is **75/0 exit 0 on a clean checkout today**, in both run-state-present and -absent conditions; the master's "75/0" target is therefore already met. M4 does **not** re-touch this file.
  Source: commit `3b2d1c4`; `bin/lib/dmc-instance-validate.py:312-320` (ST.check), `:433-454` (synthetic selftest_run); orchestrator-verified `selftest --all` fix-inclusive replica ⇒ 802/3/3 + SELFTEST-ALL PASS + exit 0.
- Finding: all five reuse targets are already copy-routed into `bin/lib/` by M3 (`dmc-v0.5.5-verification-planner.sh`, `dmc-v0.5.7-resume-recovery.sh`, `dmc-v0.6.1.0-trace-linkage.py`, `dmc-v0.6.2-evidence-receipt.py`, `dmc-v0.6.5-decision-trace.py`). Their interfaces: v0.5.5 and v0.5.7 both accept `--from <facts.json>`; v0.6.1.0 exposes `validate-entry approval <path>` which enforces the `human-release-gate:` source prefix + non-empty auth-id (T7c/T7d) — the R12 anti-laundering predicate M4 re-tests — but also pins `type` AND `producer_milestone_id` to the exact literal `human-release-gate` (T7/T8) and unconditionally requires a non-empty `verification_ref` (binding loop). It therefore cannot carry the seven gate kinds in `type`, does not itself check a gate-kind enum, and is inapplicable to pre-verification approvals — see the T009c contract and the approvals reuse-contract Risks row.
  Source: `bin/lib/dmc-v0.6.1.0-trace-linkage.py:142-160` (validate_entry: T7/T8 literals at :149,:157; binding loop with verification_ref at :150-151; T7c/T7d at :158-159); `dmc-v0.5.5-verification-planner.sh:11`, `dmc-v0.5.7-resume-recovery.sh:10-13`.
- Finding: the legacy mirror-check refuses any `bin/lib/dmc-v0.*` file outside the pinned 55-file set (`ALL_LEGACY_FILES`), so M4's new modules must not be named `dmc-v0.*`; they must **call** the existing copies, never add new ones.
  Source: `bin/lib/dmc-legacy-selftest.py:112,205-215`.
- Finding: the master's §Relevant Files authorizes new `.harness/schemas/*.schema.md` only for the six M3 schemas (shipped) plus the `evidence-receipt` `check_id` extension. It does **not** authorize dedicated schema docs for run.json / approvals.jsonl / checkpoints.json / verify-plan.json. Those must be in-tool contracts; approvals reuse the existing `trace-linkage.schema.md` `approval` entry shape.
  Source: master plan §Relevant Files (`.harness/schemas/*.schema.md (new: … existing: evidence-receipt check_id extension)`); architecture §P17 (approvals are trace-linkage `approval` entries).
- Finding: the human-facing run doc (`RUN_SCHEMA.md` → `.harness/runs/<run-id>.md`) and the machine run-state (`architecture §0.3` → `.harness/runs/<run-id>/run.json`) are two distinct artifacts. M4 produces the machine `run.json`; the human run-doc/`current-run.md` is created by the M5 `dmc-start-work` skill. The earlier `validate-run` dependency on that human doc was already removed pre-M4 (Finding 2, commit `3b2d1c4`), so M4 touches neither the human run-doc surface nor the instance validator.
  Source: `RUN_SCHEMA.md` vs `docs/DMC_V1_RUNTIME_ARCHITECTURE.md §0.3`; `.claude/skills/dmc-start-work/SKILL.md:23-24`.
- Finding: the pinned legacy baseline carries 3 accepted pre-existing upstream FAILs (`dmc-v0.1.3`, `dmc-v0.2.3`, `dmc-v0.3.2`); M4 must reproduce `802/3/3` exactly and must not mask or "fix" those FAILs.
  Source: `.harness/evidence/dmc-v1-m3-baseline.md` (Anomalies).

## Relevant Files

| Path | Reason | Allowed to Edit |
|---|---|---|
| bin/lib/dmc-run-lifecycle.py (new) | P-run: run.json + INIT/RUNNING/SUSPENDED/RESUMING/DONE state machine; start/suspend/resume/status; concurrent-lock refusal; suspend-not-block-stop | yes (new; M4) |
| bin/lib/dmc-scope-lock.py (new) | P7c: compile APPROVED plan → scope.lock.json; immutable + hash-chain tamper detection; per-mutation adjudication verdict; validator per scope-lock.schema.md | yes (new; M4) |
| bin/lib/dmc-approvals.py (new) | P17: approvals.jsonl with a local `gate_kind` ∈ {plan_approval/scope_amendment/bound_raise/release/push/live_call/waiver}; R12 provenance enforced locally for all kinds + copied `validate-entry approval` cross-check on post-verification kinds | yes (new; M4) |
| bin/lib/dmc-evidence-ledger.py (new) | P10: append-only, hash-chained receipts with the new `check_id` field; value-blind redaction; single JSONL index | yes (new; M4) |
| bin/lib/dmc-checkpoints.py (new) | P12: named git-ref + state-snapshot-hash checkpoints; refuses checkpoint on a false-green (no receipt coverage) | yes (new; M4) |
| bin/lib/dmc-acceptance.py (new) | P8: compile plan Acceptance Criteria + orientation verify_commands → acceptance.json; refuse untestable criteria; validator per acceptance.schema.md | yes (new; M4) |
| bin/lib/dmc-verify-plan.py (new) | P9: translate acceptance.json + radius.json → v0.5.5 facts, call the copied v0.5.5 planner, emit verify-plan.json; coverage linkage checks | yes (new; M4) |
| bin/lib/dmc-fixloop.py (new) | P13: fixloop.log.jsonl counters bound to plan_hash; bound→STOP verdict; validator per fixloop.schema.md | yes (new; M4) |
| bin/lib/dmc-context-recovery.py (new) | P11: gather OBSERVED git state → v0.5.7 facts, call the copied v0.5.7 tool, emit next-safe-action; halt on declared-vs-observed delta | yes (new; M4) |
| bin/lib/dmc-run-core-selftest.py (new) | run-core + loop-core self-test aggregator (hermetic; tempdir fixtures), and re-runs v0.6.2/v0.6.5/v0.6.1.0 validators over generated artifacts | yes (new; M4) |
| bin/dmc | additive `run` verb routing + `selftest run-core loop-core` section arms (named + `--all`; not in the no-arg default) | yes (additive; M4) |
| bin/lib/dmc-instance-validate.py | validate-run self-test already made hermetic pre-M4 (commit 3b2d1c4); M4 does not touch it | no |
| .harness/schemas/evidence-receipt.schema.md | the ONE authorized existing-schema edit: additive `check_id` field for P10 receipts | yes (M4 — sole schema edit) |
| tests/fixtures/run/** (new) | fixture APPROVED plan, radius.json, orientation.json for the hermetic tempdir round-trip | yes (new; M4) |
| .harness/evidence/dmc-v1-m4-*.md, .harness/verification/dmc-v1-m4-*.md (new) | per-sub-task evidence + milestone verification | yes (M4) |
| .harness/runs/** | run artifacts written by the fixture round-trip (local-only; `current-*` gitignored) | yes (local run artifacts only) |
| .claude/** (hooks, skills, settings, agents, install, workers) | M5/M6/M7 surfaces | no |
| .harness/evidence/dmc-v0.*.{sh,py} originals AND their bin/lib copies | copy-only; any byte change fails the mirror-check | no |
| .harness/schemas/{scope-lock,acceptance,fixloop,radius,delegation,critic-verdict,worker-review}.schema.md | consumed as contracts; not edited in M4 | no |
| docs/MILESTONES.md, main/master | closure + protected branches (M10, human-gated) | no |

## Out of Scope

- P7 **enforcement** half (Bash write-radius classifier, `git apply`/`patch` deny, fail-closed-in-active) — M6. M4 ships only P7 **constructive** (compile the lock + a pure adjudication verdict function); no hook wiring.
- Any edit under `.claude/**` (hooks, skills, settings.json, agents, install, workers/providers), the Stop-hook wiring, and the human run-doc/`dmc-start-work` creation of `current-run.md` — M5/M6.
- New `.harness/schemas/*.schema.md` files for run.json / approvals.jsonl / checkpoints.json / verify-plan.json (not master-authorized; in-tool contracts instead). Adding them would require a scope amendment.
- Any change to the 49 legacy tools, their bin/lib copies, or the pinned `802/3/3` baseline; any "fix" of the 3 accepted upstream FAILs.
- Live provider calls, network, secret reads/writes, credential handling; cryptographic approval authentication (P17 keeps the honest provenance-not-authentication label, v1.1+).
- Automated multi-agent scheduling (P14 records), worker apply-authorization (P15), critic-verdict validator (P16) — M5/M7.
- Any git add/commit/push, any main/master change, any closure entry.

## Proposed Changes

- Change: Run-lifecycle state machine. Files: bin/lib/dmc-run-lifecycle.py, bin/dmc. Rationale: `dmc run start` mints the run-id and `runs/<run-id>/run.json`, arming the loop and enforcing the "one concurrent run per repo" assumption (master §Assumptions); `suspend` sets SUSPENDED without blocking session stop (critic item 10).
- Change: Scope-lock compiler (P7c). Files: bin/lib/dmc-scope-lock.py. Rationale: compile the APPROVED plan's authorized scope + P6 bounds into an immutable, hash-chained `scope.lock.json`; tamper is detectable at Ring 0; a second concurrent lock is refused (architecture §0.4).
- Change: Typed approvals + R12 (P17). Files: bin/lib/dmc-approvals.py. Rationale: append-only `approvals.jsonl` of human-release-gate-provenance records carrying a local `gate_kind` (the seven gate kinds); a local rule enforces the 7-enum + R12 provenance for every kind, and the copied v0.6.1.0 `validate-entry approval` cross-checks post-verification kinds — so a critic/verifier/Codex ACCEPT can never be laundered into an approval, and pre-verification kinds don't need a bogus `verification_ref`.
- Change: Evidence ledger + `check_id` receipts (P10). Files: bin/lib/dmc-evidence-ledger.py, .harness/schemas/evidence-receipt.schema.md. Rationale: append-only hash-chained receipts referencing acceptance `check_id`s; the schema gains the one authorized additive field.
- Change: Checkpoints (P12). Files: bin/lib/dmc-checkpoints.py. Rationale: named git-ref + snapshot-hash known-good points that refuse creation without receipt coverage (no false-green checkpoint).
- Change: Loop primitives P8/P9/P13/P11. Files: bin/lib/dmc-acceptance.py, dmc-verify-plan.py, dmc-fixloop.py, dmc-context-recovery.py. Rationale: acceptance compiler refuses untestable criteria; P9 promotes v0.5.5 by feeding it acceptance+radius; fix-loop counters bind plan_hash so a fresh run cannot launder them; P11 promotes v0.5.7 by feeding it OBSERVED git state and halts on delta.
- Change: Hermetic run-core/loop-core self-tests (new sections). Files: bin/lib/dmc-run-core-selftest.py, bin/dmc, tests/fixtures/run/**. Rationale: `bin/dmc selftest run-core loop-core` proves the round-trip in a tempdir. **Decision (default-selftest policy):** run-core/loop-core run only when explicitly named and under `bin/dmc selftest --all`; they do **not** join the no-arg default, which stays exactly 75/0 exit 0 — the round-trip shells out to v0.5.5/v0.5.7 + three validators + git in a tempdir, so it belongs in the heavy `--all` tier (the same fast-default / heavy-`--all` split M3 used for the 49-tool aggregate), keeping the default fast and its regression number stable for M5+.

## Acceptance Criteria

- Criterion: Full state-file round-trip on a fixture run — start → scope-lock → acceptance/verify-plan checks → receipts → induced check fail → fix-loop counter increment → checkpoint → suspend → resume → context-recover — completes and every artifact validates against its contract.
  Verification Method: `bin/dmc selftest run-core loop-core` exits 0; the round-trip runs in a tempdir and leaves the real repo `git status --porcelain` byte-unchanged (captured before/after).
- Criterion: `scope.lock.json` and `acceptance.json` are immutable post-approval and hash-chain tamper is detected; an in-place mutation attempt and a broken `prev_hash` are both REFUSED.
  Verification Method: negative-control assertions in the scope-lock and acceptance validators (tampered body ⇒ exit 3), asserted by `bin/dmc selftest run-core`.
- Criterion: A second `dmc run start` while a run is active (not SUSPENDED) is REFUSED (concurrent-lock refusal); a SUSPENDED run reports status SUSPENDED and does not present as active.
  Verification Method: run-core self-test concurrent-start negative control + suspend/resume status assertions.
- Criterion: Approval laundering is refused (R12 re-test) — for every gate kind, an approval record whose `source` is not `human-release-gate:<non-empty>` (e.g. `codex-accept-…`), or whose auth-id is empty, or whose `type` ≠ `human-release-gate`, is REFUSED; and an unknown/missing `gate_kind` is REFUSED.
  Verification Method: `bin/dmc selftest run-core` approvals section asserts REFUSE via dmc-approvals.py's local rule (uniform R12 provenance + the 7-enum) on the laundered/empty/untyped/unknown-kind fixtures, and additionally cross-checks a post-verification (release) fixture through the copied `bin/lib/dmc-v0.6.1.0-trace-linkage.py validate-entry approval` (which also REFUSES the laundered source via T7c).
- Criterion: Fix-loop counters bind `plan_hash` (not run-id): `attempt > bound` forces `verdict: STOP`; a counter that decreases for the same `(plan_hash, check_id)` across a fresh run is REFUSED.
  Verification Method: fixloop validator negative controls in `bin/dmc selftest loop-core`.
- Criterion: P11 context recovery uses OBSERVED git state and halts (never auto-reconciles) on a declared-vs-observed delta, emitting a next-safe-action.
  Verification Method: loop-core self-test scenarios (clean-resume, dirty-outside-scope, moved-HEAD, half-applied) each produce the expected action / halt.
- Criterion: The M4 artifacts remain compatible with the shipped composers — v0.6.2 evidence-receipt gate, v0.6.5 decision-trace, and v0.6.1.0 trace-linkage validators run clean over the generated receipts and the post-verification approval records (release/push/waiver, which carry a real `verification_ref`); pre-verification approvals are validated by the T009c local rule only.
  Verification Method: `bin/dmc-run-core-selftest` re-runs those three copied validators over the round-trip receipts + post-verification approval records; all ACCEPT.
- Criterion: Regression — the no-arg default `bin/dmc selftest` stays **exactly 75/0 and exits 0** on a clean checkout (M4 adds run-core/loop-core as named/`--all`-only sections, not to the default), and `bin/dmc selftest --all` keeps the pinned legacy aggregate at **802/3/3** with mirror-check + rollback green while additionally running run-core + loop-core (which must PASS for `--all` to exit 0).
  Verification Method: `bin/dmc selftest; echo $?` ⇒ `75 PASS / 0 FAIL` and exit 0; `bin/dmc selftest --all` ⇒ legacy `tools=49 PASS=802 FAIL=3 N/A=3` + run-core/loop-core PASS + legacy-mirror + rollback PASS + exit 0.
- Criterion: Additive-only — Ring-0 contains no model-name strings; no `bin/lib/dmc-v0.*` file is added or altered; deleting the M4 additions restores the M3 state.
  Verification Method: `grep -RInE 'claude-(opus|sonnet|haiku|fable|mythos)|gpt-[0-9]' bin/` empty; `bin/dmc mirror-check` green; the rollback dry-run in the M4 verification doc.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| M4 is the largest milestone (8 primitives) — breadth risks an unbounded diff | medium | seven sub-tasks, disjoint except that `bin/dmc` is edited by both T009a (run verbs) and T009g (selftest section arms + `--all` wiring), sequenced T009a→…→T009g so the edits never overlap; each sub-task has its own validator + hermetic self-test; bounded order T009a → {b,c,d,e} parallel → f → g; each independently verifiable before integration |
| Re-touching the now-hermetic `validate-run` self-test (fixed pre-M4 in 3b2d1c4) would risk re-introducing the exit-1 crash | low | `bin/lib/dmc-instance-validate.py` is on M4's not-edit list; M4 adds run-core/loop-core as separate sections and never modifies validate-run |
| A new module accidentally named `dmc-v0.*` (or a byte-touch to a copy) breaks legacy-mirror | medium | naming convention `dmc-<primitive>.py` (no `v0.`); M4 CALLS copies, never re-copies or edits them; `bin/dmc mirror-check` in every sub-task's verification |
| P9/P11 promotion drifts from v0.5.5/v0.5.7 behavior when fed run-derived facts | medium | reuse by invocation (translate → call the copied tool → consume its verdict), not by re-implementation; linkage tests assert the translated facts round-trip; no logic fork |
| Receipts with the new `check_id` field break the v0.6.2 gate / v0.6.5 trace | medium | `check_id` is additive and ignored by the existing v0.6.2 rules; acceptance criterion re-runs both validators over M4 receipts as a gate |
| Suspend logic blocks session stop (critic item 10 regression) | medium | SUSPENDED is an explicit non-active state; run-core exposes `dmc run status` reporting it; the actual Stop-hook non-block wiring is deferred to M6 and only the state contract is asserted here |
| Fixture round-trip mutates the real repo / `.harness/runs` | low | round-trip runs entirely under `tempfile.mkdtemp()` like the M3 legacy/mirror tests; before/after `git status --porcelain` asserted identical |
| Concurrent DMC runs violate the single-run assumption | low | `dmc run start` refuses a second active lock; asserted by a negative control |
| Approvals reuse-contract mismatch: the copied `validate-entry approval` pins `type`/`producer_milestone_id` to the literal `human-release-gate` and unconditionally requires `verification_ref`, so it cannot carry the seven gate kinds nor validate pre-verification approvals | medium | the seven kinds live in a local `gate_kind` field validated by dmc-approvals.py's own rule (which also re-enforces the identical R12 provenance for every kind); the copied validator is applied only to post-verification kinds (release/push/waiver) that carry a real `verification_ref` — R12 is enforced uniformly, not weakened |
| tempdir round-trip flakiness — `git init` / `user.name` / `user.email` / `commit` in the disposable fixture repo can fail on a bare CI host | medium | the run-core selftest sets a self-contained git identity in the tempdir (`git -c user.name=… -c user.email=…`) and skips gracefully with a named FAIL if git is unavailable; no dependency on the caller's git config |
| hash-chain canonicalization must be identical across the five chained artifacts (scope.lock, acceptance, approvals, receipts, fixloop) or `prev_hash` links diverge | medium | one shared canonical-serialization helper (sorted keys, fixed separators, UTF-8, trailing-newline policy) is used by every M4 writer and validator; a round-trip test asserts recompute-equals-stored on each artifact |

## Assumptions

| Assumption | Confidence | How to Verify |
|---|---|---|
| run-core/loop-core belong in the heavy tier (named + `--all`), so the no-arg default stays 75/0 | high | matches the M3 fast-default / `--all`-heavy split; `bin/dmc selftest` measured at 75/0 exit 0 |
| run.json / approvals.jsonl / checkpoints.json / verify-plan.json as in-tool contracts (no new schema docs) is within master authorization | high | master §Relevant Files authorizes new schema docs only for the six M3 schemas + evidence-receipt extension; approvals reuse trace-linkage.schema.md |
| The reuse targets' `--from facts.json` interfaces are stable enough to drive from run artifacts | high | interfaces read from source (v0.5.5:11, v0.5.7:10-13); linkage tests pin the translation |
| python3 + git present on the dev/CI host (M4 tools are offline, read-git-only) | high | already required by M2/M3 tools; `dmc doctor` (M8) will formalize |
| Default `bin/dmc selftest` is 75/0 exit 0 as of commit 3b2d1c4 (validate-run now fully synthetic) | high | run `bin/dmc selftest; echo $?` on a clean checkout |
| No M4 artifact needs a live provider or secret | high | all inputs are the plan file, git state, and prior run artifacts; secret paths refused by the shared path filter |

## Execution Tasks

REQUIRED-primitive coverage (master M4 row): P7c → T009b · P8 → T009e · P9 → T009e · P10 → T009d · P11 → T009f · P12 → T009d · P13 → T009f · P17 → T009c. Integration/regression → T009g. Bounded order: **T009a first** (all artifacts live under its run dir) → **T009b, T009c, T009d, T009e in parallel** (file-disjoint, each fixture-testable) → **T009f** (depends on acceptance+radius+scope for realistic fixtures) → **T009g** (integration + regression). Each sub-task ships its own validator + hermetic self-test, so it is independently verifiable before integration.

Global not-edit (every sub-task): `.claude/**`, `.harness/evidence/dmc-v0.*` originals and their bin/lib copies, the six M3 schema docs (except the authorized `evidence-receipt` edit), `docs/MILESTONES.md`, main/master. No `bin/lib/dmc-v0.*` additions. No git add/commit/push. No live/network/secret paths.

- [ ] DMC-T009a: Run-lifecycle state machine + hermetic run fixtures. Route: **Opus 4.8** (state machine + concurrency + suspend invariant).
  Files: bin/lib/dmc-run-lifecycle.py (new), bin/dmc (additive `run start|suspend|resume|status` verb routing only — the `run-core`/`loop-core` selftest section arms are registered solely by T009g), tests/fixtures/run/** (new: APPROVED plan, orientation.json, radius.json).
  **Acceptance:** `dmc run start` writes `runs/<run-id>/run.json` (schema id, work_id/plan_hash/repo_hash, status, timestamps, prev_hash) + a run-id pointer; transitions INIT→RUNNING→SUSPENDED→RESUMING→RUNNING→DONE are enforced; `run status` reports SUSPENDED distinctly from active.
  **Verification:** `python3 bin/lib/dmc-run-lifecycle.py --self-test` exits 0 (this task's assertions run standalone and are also aggregated into T009g's `run-core` section).
  **Negative controls (must REFUSE):** a second `run start` while a run is active (concurrent-lock refusal); an invalid transition (e.g. `resume` a non-suspended run); a malformed `run.json` (missing binding field / bad status).
  **Rollback:** delete the new file + revert the additive `bin/dmc` arms; nothing else references them.
  **Evidence:** .harness/evidence/dmc-v1-m4-run-lifecycle.md.
  **Not-edit:** everything in the global list; no Stop-hook wiring (M6).
  **Risk:** medium — the fixture set other sub-tasks depend on; keep it minimal and committed under tests/fixtures/run/.

- [ ] DMC-T009b: Scope-lock compiler + adjudication verdict (P7c). Route: **Opus 4.8** (security-critical immutability/hash-chain).
  Files: bin/lib/dmc-scope-lock.py (new).
  **Acceptance:** compiles an APPROVED plan (by plan_hash) + landmarks into `scope.lock.json` conforming to `scope-lock.schema.md` (files[] grants, P6 bounds, immutable:true, prev_hash); exposes a pure `adjudicate(path, op)` verdict fn (verdict-only, no FS mutation — the Ring-1 wiring is M6); detects hash-chain tamper.
  **Verification:** `python3 bin/lib/dmc-scope-lock.py --validate <fixture>` (ACCEPT⇒0 / REFUSE⇒3) — the standalone pre-integration gate; assertions additionally aggregated into T009g's `run-core` section (available once T009g registers it).
  **Negative controls (must REFUSE):** missing/empty `approved_by`; a `files[].path` with `..` or absolute; `immutable != true`; a negative bound; a non-enum `landmark_class`; a non-`ordinary` landmark path with no plan authorization; an in-place edit (prev_hash mismatch).
  **Rollback:** delete the new file.
  **Evidence:** .harness/evidence/dmc-v1-m4-scope-lock.md.
  **Not-edit:** global list; must not touch the Bash write-radius classifier (M6).
  **Risk:** medium — immutability + concurrent-lock are the load-bearing invariants; assert both as negative controls.

- [ ] DMC-T009c: Typed approvals ledger + R12 anti-laundering (P17). Route: **Opus 4.8** (R12 correctness).
  Files: bin/lib/dmc-approvals.py (new).
  **Acceptance:** appends `approval`-kind trace-linkage records to `runs/<run-id>/approvals.jsonl` with the fixed provenance fields `type = producer_milestone_id = human-release-gate` and `source = human-release-gate:<non-empty auth-id>` (R12), the subject binding (`work_id` + hash-shaped `plan_hash`/`repo_hash`), and a NEW local field `gate_kind` ∈ {plan_approval, scope_amendment, bound_raise, release, push, live_call, waiver} carrying the seven gate kinds (they do NOT live in `type`, which the copied validator pins to the literal). dmc-approvals.py's own validator (a new local rule, T009c-owned) enforces the 7-enum on `gate_kind` (rejecting unknown/missing) AND re-enforces the identical R12 provenance predicate for every record, so R12 holds uniformly across all seven kinds. Post-verification kinds (release/push/waiver) additionally carry a real `verification_ref` and are cross-checked through the copied `bin/lib/dmc-v0.6.1.0-trace-linkage.py validate-entry approval`; pre-verification kinds (plan_approval/scope_amendment/bound_raise/live_call) legitimately omit `verification_ref` and are gated by the local rule only (the copied validator unconditionally requires a non-empty `verification_ref` at `dmc-v0.6.1.0-trace-linkage.py:150-151`, so it is inapplicable to them).
  **Verification:** `python3 bin/lib/dmc-approvals.py --self-test` — the standalone pre-integration gate; additionally aggregated into T009g's `run-core` approvals section.
  **Negative controls (must REFUSE):** `source` not prefixed `human-release-gate:` (e.g. `codex-accept-123`) — the R12 re-test, enforced by the local rule for every kind; empty auth-id after the prefix; `type` ≠ `human-release-gate`; an unknown or missing `gate_kind` (e.g. `gate_kind: rubber_stamp`); a record whose subject binding differs from the run; a pre-verification record (e.g. plan_approval) carrying a placeholder `verification_ref` instead of omitting it. (Positive control: a release-kind record with a real `verification_ref` additionally PASSES the copied `validate-entry approval`.)
  **Rollback:** delete the new file.
  **Evidence:** .harness/evidence/dmc-v1-m4-approvals.md.
  **Not-edit:** global list; approvals reuse trace-linkage.schema.md — add no new schema doc.
  **Risk:** medium — C11/R12 is the anti-laundering invariant; the local rule enforces R12 provenance for all seven kinds (identical predicate to the copied validator) and the copied `validate-entry approval` cross-checks the post-verification kinds, so no kind is gated by prose.

- [ ] DMC-T009d: Evidence ledger + `check_id` receipts (P10) + checkpoints (P12). Route: **Sonnet 5** (mechanical over shipped v0.6.2 shape; escalate to Opus if the ledger index concurrency proves nontrivial).
  Files: bin/lib/dmc-evidence-ledger.py (new), bin/lib/dmc-checkpoints.py (new), .harness/schemas/evidence-receipt.schema.md (authorized additive `check_id` field).
  **Acceptance:** the ledger mints append-only, hash-chained receipts (v0.6.2 evidence-receipt shape + additive `check_id` referencing acceptance.json) into `runs/<run-id>/receipts/` with a single JSONL index; value-blind redaction of any secret-shaped value; checkpoints record `{name, git_ref, snapshot_hash}` into `checkpoints.json` only when the referenced checks have receipt coverage.
  **Verification:** `python3 bin/lib/dmc-evidence-ledger.py --self-test` and `python3 bin/lib/dmc-checkpoints.py --self-test` — the standalone pre-integration gates; the copied `bin/lib/dmc-v0.6.2-evidence-receipt.py` gate ACCEPTs the minted receipts (compatibility gate); additionally aggregated into T009g's `run-core` section.
  **Negative controls (must REFUSE):** a receipt with no `check_id` (post-extension); a checkpoint requested without receipt coverage (false-green); a secret-shaped value in a receipt (redaction/refusal); a broken receipt hash-chain.
  **Rollback:** delete the two new files; revert the single additive schema line.
  **Evidence:** .harness/evidence/dmc-v1-m4-evidence-checkpoints.md.
  **Not-edit:** global list; must not edit `dmc-v0.6.2-evidence-receipt.py` (original or copy) — extend via the new ledger only.
  **Risk:** medium — the `check_id` extension must stay backward-compatible with the v0.6.2 gate; the compatibility re-run is the guard.

- [ ] DMC-T009e: Acceptance compiler (P8) + verification-planner promotion (P9). Route: **Opus 4.8** (P9 promotion + coverage linkage).
  Files: bin/lib/dmc-acceptance.py (new), bin/lib/dmc-verify-plan.py (new).
  **Acceptance:** acceptance compiler turns plan Acceptance Criteria + orientation verify_commands into `acceptance.json` per `acceptance.schema.md` (kind command|inspection|human, unique stable check_ids, radius cross-links); P9 translates acceptance+radius into v0.5.5 `--from` facts, invokes the copied `bin/lib/dmc-v0.5.5-verification-planner.sh`, and emits `verify-plan.json`; every radius entry resolves to ≥1 acceptance check_id.
  **Verification:** `python3 bin/lib/dmc-acceptance.py --validate <fixture>` and `python3 bin/lib/dmc-verify-plan.py --self-test` — the standalone pre-integration gates; additionally aggregated into T009g's `loop-core` section.
  **Negative controls (must REFUSE):** a `command` check with empty `cmd`; a duplicate `check_id`; an empty `checks` array; `immutable != true`; a radius entry with no resolving acceptance check (coverage gap).
  **Rollback:** delete the two new files.
  **Evidence:** .harness/evidence/dmc-v1-m4-acceptance-verifyplan.md.
  **Not-edit:** global list; reuse v0.5.5 by invocation, never re-implement or re-copy.
  **Risk:** medium — P9 must not fork v0.5.5 logic; assert the translated facts round-trip.

- [ ] DMC-T009f: Fix-loop counters (P13) + context recovery (P11). Route: **Opus 4.8** (counter binding + observed-git reconciliation).
  Files: bin/lib/dmc-fixloop.py (new), bin/lib/dmc-context-recovery.py (new).
  **Acceptance:** fix-loop appends `fixloop.log.jsonl` per `fixloop.schema.md` with counters keyed on `(plan_hash, check_id)` and `attempt > bound ⇒ verdict STOP`; P11 gathers OBSERVED `git status`/`diff --name-only`/HEAD, translates to v0.5.7 facts, invokes the copied `bin/lib/dmc-v0.5.7-resume-recovery.sh`, and emits a next-safe-action; a declared-vs-observed delta halts (never auto-reconciles).
  **Verification:** `python3 bin/lib/dmc-fixloop.py --validate <fixture>` and `python3 bin/lib/dmc-context-recovery.py --self-test` — the standalone pre-integration gates; additionally aggregated into T009g's `loop-core` section.
  **Negative controls (must REFUSE):** `attempt` at/over `bound` with verdict ≠ STOP; `attempt < 1`; a counter that decreases for the same `(plan_hash, check_id)` across a fresh run (reset gaming); a `files_touched` entry with `..`; a P11 attempt to auto-reconcile on an observed delta (must return halt + the diff instead).
  **Rollback:** delete the two new files.
  **Evidence:** .harness/evidence/dmc-v1-m4-fixloop-recovery.md.
  **Not-edit:** global list; reuse v0.5.7 by invocation.
  **Risk:** medium — counter subject-binding is the anti-gaming invariant; P11 must feed observed (not declared) facts.

- [ ] DMC-T009g: Integration, hermetic round-trip, and regression proof. Route: **Opus 4.8** (whole-loop integration + baseline discipline).
  Files: bin/lib/dmc-run-core-selftest.py (new), bin/dmc (SOLE registrant of the `run-core` and `loop-core` selftest section arms — both fan out to the sub-tasks' module self-tests + the round-trip; wired into `--all` but NOT the no-arg default), .harness/verification/dmc-v1-m4-run-lifecycle.md (new), .harness/evidence/dmc-v1-m4-integration.md (new).
  **Acceptance:** a single tempdir round-trip exercises start→lock→checks→receipts→fail→counter→checkpoint→suspend→resume→recover and validates every artifact; the copied v0.6.2/v0.6.5/v0.6.1.0 validators ACCEPT the generated receipts/approvals; run-core/loop-core are wired as named/`--all`-only sections; the no-arg default `bin/dmc selftest` stays exactly 75/0 exit 0; `bin/dmc selftest --all` keeps the legacy aggregate at 802/3/3 (mirror-check + rollback green) and additionally runs run-core/loop-core (PASS).
  **Verification:** `bin/dmc selftest run-core loop-core` ⇒ 0; `bin/dmc selftest; echo $?` ⇒ `75 PASS / 0 FAIL` and 0; `bin/dmc selftest --all` ⇒ legacy `tools=49 PASS=802 FAIL=3 N/A=3` + run-core/loop-core PASS + exit 0; `bin/dmc mirror-check` green; `git status --porcelain` byte-identical before/after the round-trip; plus an M4-specific rollback dry-run (in a disposable copy) that removes the ten new modules + reverts the `bin/dmc` arms and confirms the default selftest returns to 75/0 exit 0 and `--all` to 802/3/3 — recorded in the verification doc.
  **Rollback:** delete the new files and revert the additive `bin/dmc` arms (`run-core`/`loop-core` sections + their `--all` wiring); M3 state restored.
  **Evidence:** .harness/evidence/dmc-v1-m4-integration.md + .harness/verification/dmc-v1-m4-run-lifecycle.md.
  **Not-edit:** global list; must not "fix" the 3 accepted upstream FAILs or alter the pinned baseline.
  **Risk:** low — integration only; the default selftest already sits at 75/0 (3b2d1c4), so this task adds coverage without moving the default regression number.

M4-overall extended block:
**Acceptance:** all eight primitives (P7c/P8/P9/P10/P11/P12/P13/P17) implemented additively with fail-closed validators; the full round-trip passes; scope.lock/acceptance immutable with hash-chain tamper detection; concurrent-lock and approval-laundering (R12) refused; fix-loop counters plan_hash-bound; P11 observed-git recovery halts on delta; no-arg default selftest stays 75/0 exit 0 (run-core/loop-core are named/`--all`-only); legacy `--all` aggregate stays 802/3/3 with run-core/loop-core additionally PASS.
**Verification:** `bin/dmc selftest run-core loop-core` + `bin/dmc selftest` (no-arg default stays 75/0 exit 0) + `bin/dmc selftest --all` (legacy 802/3/3 + run-core/loop-core PASS) + `bin/dmc mirror-check` + v0.6.2/v0.6.5/v0.6.1.0 re-run over M4 artifacts + `git status --porcelain` clean.
**Rollback:** additive rollback (dry-run verified in the M4 verification doc, not by the M3 rm-rf-bin automated test) — delete the ten new `bin/lib/dmc-*.py` files, revert the additive `bin/dmc` arms (run verbs + `run-core`/`loop-core` sections incl. `--all` wiring) and the one-line schema `check_id` addition; the M3 selftest surface (default 75/0) and the pinned legacy baseline (802/3/3) return byte-identically, since nothing consumes M4 artifacts at runtime yet.
**Evidence:** `.harness/evidence/dmc-v1-m4-*.md`, `.harness/verification/dmc-v1-m4-run-lifecycle.md`.
**Not-edit:** `.claude/**` (hooks, skills, settings.json, agents, install, workers), `.harness/evidence/dmc-v0.*` originals + copies, the six M3 schema docs (except the evidence-receipt `check_id` edit), `docs/MILESTONES.md`, main/master; no new `bin/lib/dmc-v0.*`; no live/network/secret paths.
**Risk:** medium — largest milestone; contained by seven independently-verifiable sub-tasks (disjoint except `bin/dmc`, edited by T009a and T009g in sequence) + a rollback dry-run (see Rollback).

## Verification Commands

| Command | Reason | Required |
|---|---|---|
| bash -n bin/dmc; python3 -m py_compile bin/lib/dmc-*.py | syntax floor for new + edited files | yes |
| bin/dmc selftest run-core loop-core | M4 primitive self-tests incl. round-trip + all negative controls | yes |
| bin/dmc selftest; echo $? | no-arg default stays exactly 75/0 and exit 0 (run-core/loop-core are not in the default) | yes |
| bin/dmc selftest --all | legacy aggregate unchanged (tools=49 PASS=802 FAIL=3 N/A=3) + mirror + rollback PASS, and run-core/loop-core additionally run + PASS (exit 0) | yes |
| bin/dmc mirror-check | no `dmc-v0.*` copy added/altered (byte-equality of the 55-file set) | yes |
| python3 bin/lib/dmc-v0.6.2-evidence-receipt.py gate + dmc-v0.6.5-decision-trace.py + dmc-v0.6.1.0-trace-linkage.py validate-entry approval over the round-trip receipts + post-verification approval records (release/push/waiver; pre-verification kinds are gated by the T009c local rule only) | composer/anti-laundering compatibility (R12 re-test) | yes |
| grep -RInE 'claude-(opus\|sonnet\|haiku\|fable\|mythos)\|gpt-[0-9]' bin/ | Ring-0 model-name-free invariant | yes |
| git status --porcelain (before/after the round-trip) | real repo byte-unchanged (round-trip is tempdir-only) | yes |

## Approval Status

Status: APPROVED
Approver: wjlee (wjlee@motionlabs.kr) — human release gate
Approved At: 2026-07-06

Approval record (verbatim scope of the human gate, 2026-07-06, granted in the local session):
- **M4-only approval**: DMC-T009a–T009g as specified in §Execution Tasks — additive `bin/**`
  modules, `tests/fixtures/run/**`, the single authorized `evidence-receipt.schema.md`
  `check_id` addition, M4 evidence/verification files, local run artifacts under
  `.harness/runs/`.
- **In-tool-contracts reading CONFIRMED** by the human gate: run.json / approvals.jsonl /
  checkpoints.json / verify-plan.json carry in-tool contracts (no new
  `.harness/schemas/*.schema.md` docs).
- **Explicitly NOT approved**: staging/commit/push (each a separate human gate), M5+, any
  `.claude/**` / worker-validator / installer / protected-surface change, edits to
  `dmc-v0.*` originals or their bin/lib copies, main/master changes, live calls, secret access.
- Critic provenance: DMC critic (independent, Opus) — Rev 2 NEEDS CLARIFICATION (R1) →
  Rev 3 focused re-pass **APPROVE**; critic APPROVE is advisory input only (C11); this
  approval was granted by the human release gate above.

This is a milestone-scoped DRAFT for M4 of the master plan; it is not self-approved and does not alter the master's approval state. One item needs the human gate's explicit attention at approval: (1) confirmation that run.json / approvals.jsonl / checkpoints.json / verify-plan.json as in-tool contracts (no new `.harness/schemas/*.schema.md` docs) is within M4 authorization. (The earlier `validate-run` hermeticity concern is moot — fixed pre-M4 by commit 3b2d1c4; default selftest is 75/0 exit 0 today.) Next gates: DMC critic pass on this draft → human M4 approval → M4 start.
