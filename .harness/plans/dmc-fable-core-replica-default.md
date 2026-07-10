# Plan: v1.1.6 — Committed-Replica Default for `dmc selftest --all` (legacy leg)

## Goal

Make the tree- and mode-coupled portion of `bin/dmc selftest --all` — the single frozen legacy-replay leg at `bin/dmc:565` (`python3 "$LCORE" selftest-all`) — run against a **committed replica of HEAD by default**, so the green baseline (`aggregate: tools=49 PASS=802 FAIL=3 N/A=3`) becomes independent of working-tree dirt and `.harness/mode`. The manual committed-replica + `.codex/config.toml` stash + mode-restore rituals retire. A `--in-place` escape hatch preserves today's working-tree behavior byte-for-byte.

## User Intent

refactor (test-harness hardening; no enforcement-semantics change — bucket-A deterministic-artifact cleanup, per the v1.0.4/v1.0.5 precedent that objective-metric harness changes with no enforcement delta need no pilot)

## Current Repo Findings

- Finding: The `--all` runner replays the frozen legacy leg **in-place** against the live repo at a single call site.
  Source: `bin/dmc:565` (`python3 "$LCORE" selftest-all || rc=1`); it is the ONLY `selftest-all` caller (grep across `bin/`, `.github/`, `docs/`, `tests/`).
- Finding: `selftest-all` has **no `--root` flag** — `repo_root()` is hardcoded to `__file__/../..`, and `run_tool()` runs each legacy tool with `cwd=repo_root()`.
  Source: `bin/lib/dmc-legacy-selftest.py:129-131` (`repo_root()`), `:151-157` (`run_tool` cwd). => the ONLY way to test a replica is to invoke the **replica's own copy** of the script.
- Finding: The tree coupling is V15 in `dmc-v0.6.0-verify.sh`: `git -C "$ROOT" status --porcelain` FAILs on any tracked mod outside a hardcoded allow-list (`docs/*`, `.harness/plans/*`, `.harness/verification/*`, the verify script itself, one decision card). The live dirty `.codex/config.toml` is not in the list => flips `--all` to 801/4/3.
  Source: `bin/lib/dmc-v0.6.0-verify.sh:148-166`.
- Finding: The mode coupling is in `dmc-v0.1.3-verify.sh`: it invokes the live `pre-tool-guard.sh` and asserts an `ask` verdict for `npm install`, which only fires in `active` mode => `passive` flips the leg.
  Source: `bin/lib/dmc-v0.1.3-verify.sh:31`.
- Finding: **Both couplings live inside the same leg** (`selftest-all` runs all 49 legacy tools incl. these two). Redirecting that one leg to a clean committed replica fixes both at once. `.harness/mode` is gitignored, so a clone has no mode file => `active` by default.
  Source: `git check-ignore .harness/mode` (ignored); `dmc-legacy-selftest.py:45-58` (dmc-v0.1.3 is a legacy tool run by the leg).
- Finding: `selftest-all` contains **no mirror-check** — only the 49-tool aggregate + `rollback_test()`. The frozen-mirror integrity check is a **separate leg** (`legacy-mirror`, `bin/dmc:562`, `mirror --self-test`) that stays in-place.
  Source: `dmc-legacy-selftest.py:382-385` (comment: mirror-check not re-run here), `:350-396` (`selftest_all` body); `bin/dmc:562`.
- Finding: The m6/m6.5/m8/m7/m9 suites and the Python core self-tests are hermetic — their `git status --porcelain` uses are BEFORE==AFTER self-checks (prove the suite didn't dirty the repo), and their `.harness/mode` touches are on their own mktemp sandboxes; none assert live-tree cleanliness or read live mode.
  Source: `tests/fixtures/**/_*common.sh` + suite headers (`m6/_m6common.sh:53`, `m6.5/test-agents-md-drift.sh:65,145-146`, `m6/test-compat.sh:64,84,154`).
- Finding: The docs **already** frame the baseline as committed-replica scoped, so this change aligns tool behavior with documented semantics rather than introducing a new claim.
  Source: `docs/DMC_V1_HONEST_SCOPE.md:133` ("the only pinned number, 802/3/3, is maintainer-local / committed-replica scoped"); `docs/DMC_AGENT_HANDOFF.md:222` lists "mode-aware selftest expectation" as a deferred item this cycle resolves.
- Finding: CI runs `bin/dmc selftest --all` as an ADVISORY step (`continue-on-error: true`) on a clean `actions/checkout`, after a blocking MID-sandwich porcelain check.
  Source: `.github/workflows/dmc-ci.yml:181-194`.
- Finding: Clone cost is negligible — `.git` packs to ~990 KiB, 699 tracked files.
  Source: `git count-objects -vH`, `git ls-files | wc -l`.

## Relevant Files

| Path | Reason | Allowed to Edit |
|---|---|---|
| `bin/dmc` | Add the `run_legacy_selftest_all` helper (clone-of-HEAD + severed replica invocation), a `--in-place` pre-scan, redirect line 565 through the helper, add a focused `legacy-all` target, update the `selftest --all` usage text | yes |
| `docs/DMC_V1_HONEST_SCOPE.md` | One clarifying clause at S5: the default `--all` now materializes the committed replica automatically; `--in-place` is the working-tree escape hatch | yes |
| `docs/MILESTONES.md` | Append-one v1.1.6 entry (retires the manual stash/mode-restore ritual; legacy 802/3/3 UNCHANGED) | yes |
| `tests/install/test-selftest-replica-default.sh` | New standalone hermetic test (dispatch-layer feature -> `tests/install/` family, per the `test-run-start-arming.sh` precedent; NOT wired into Ring-0 `selftest`) | yes (new) |
| `bin/lib/dmc-legacy-selftest.py` | READ ONLY — `PINNED_BASELINE` and `repo_root()` are the invocation contract; byte-untouched | no |
| `bin/lib/dmc-v0.6.0-verify.sh`, `dmc-v0.1.3-verify.sh`, all `dmc-v0.*` | READ ONLY — frozen legacy mirrors (bin/lib <-> `.harness/evidence` byte-equality is gated) | no |
| `.github/workflows/dmc-ci.yml` | READ ONLY — advisory `--all` step is strictly better on a clean checkout; no change needed | no |

## Out of Scope

- Editing any frozen `dmc-v0.*` tool, `dmc-legacy-selftest.py`, or `PINNED_BASELINE` — the change lives entirely in the LIVE dispatch layer (`bin/dmc`). The frozen mirrors stay byte-identical (re-verified by the still-live `legacy-mirror` leg at `bin/dmc:562`).
- The CI workflow — the advisory `--all` step keeps working (its clone runs in `$TMPDIR`, not the checkout, so the MID-sandwich porcelain check is unaffected).
- Environment-variable coupling (the leaked provider-key env-var 801/4/3 incident B in the handoff): the replica inherits the parent process env, so this is a shell-hygiene class the replica does NOT and cannot fix. Explicitly not addressed here.
- The AGENTS.md drift suite's working-tree semantics (`dmc-fable-core-regen-pin` deliberately compares the on-disk manifest, NOT clone-of-HEAD) — a different, intentional design; untouched.
- Rewriting historical prose in `MILESTONES.md` / `DMC_AGENT_HANDOFF.md` / frozen plans that describe past committed-replica runs (append-only; never rewrite history).
- `--depth 1` / shallow-clone optimization — clone is already ~1-3 s; kept out to preserve a plain, deterministic `--no-hardlinks` clone matching the proven manual recipe.
- Agent-memory gotcha #4 / mode-coupling note refresh — orchestrator-updated post-ship, not a tracked deliverable.

## Proposed Changes

- Change: Add `run_legacy_selftest_all()` helper in `bin/dmc` (near the `run_m*_suite` helpers, ~line 257).
  Files: `bin/dmc`
  Rationale: Single source of truth for the legacy leg. Behavior:
  1. If `SELFTEST_IN_PLACE=1` (set by `--in-place`): run `python3 "$LCORE" selftest-all` in-place — byte-for-byte today's behavior.
  2. Else (default): require git (`git -C "$HERE/.." rev-parse --is-inside-work-tree`); `REPLICA=$(mktemp -d)`; `git clone --no-hardlinks --quiet "$repo_root" "$REPLICA/repo"`; `git -C "$REPLICA/repo" remote remove origin` (sever write-back); assert `git -C "$REPLICA/repo" rev-parse HEAD` == the source HEAD sha (fail loud on mismatch); `python3 "$REPLICA/repo/bin/lib/dmc-legacy-selftest.py" selftest-all`; capture rc; `trap 'rm -rf "$REPLICA"' ...` cleanup.
  3. Any provisioning failure (no git / clone / mktemp / HEAD mismatch) => print a distinct `FATAL: selftest --all replica provisioning failed: <reason>` to stderr and `return 1`. **Never** fall back to in-place (that would resurrect the flake class).

- Change: Pre-scan the `selftest` args for `--in-place`, set `SELFTEST_IN_PLACE=1`, and filter it out before `--all` detection and the target loop.
  Files: `bin/dmc`
  Rationale: `--in-place` must work for both `selftest --all --in-place` and `selftest legacy-all --in-place` without the target loop mis-parsing it as an unknown target.

- Change: Redirect `bin/dmc:565` from `python3 "$LCORE" selftest-all || rc=1` to `run_legacy_selftest_all || rc=1`.
  Files: `bin/dmc`
  Rationale: The one-line redirect that flips the default. The 802/3/3 aggregate still prints via the replica's unchanged `selftest_all()` output.

- Change: Add a `legacy-all` target to the per-target dispatch loop (`bin/dmc:593-624`) routing through `run_legacy_selftest_all`.
  Files: `bin/dmc`
  Rationale: A focused entry (`dmc selftest legacy-all`) for humans and for the hermetic test to exercise just the leg (~2-3 min) instead of the full ~10-min `--all` battery.

- Change: Update the `selftest --all` usage block (`bin/dmc:241-246`) to note the default committed-replica behavior + `--in-place` hatch; add the `legacy-all` target line.
  Files: `bin/dmc`
  Rationale: Discoverability; keep help text truthful.

- Change: Add one clarifying clause to `docs/DMC_V1_HONEST_SCOPE.md:131-133`.
  Files: `docs/DMC_V1_HONEST_SCOPE.md`
  Rationale: State that the default `--all` now materializes the committed replica automatically (aligning the tool with the already-documented "committed-replica scoped" framing); `--in-place` reproduces the working-tree misread.

- Change: Append one v1.1.6 entry to `docs/MILESTONES.md`.
  Files: `docs/MILESTONES.md`
  Rationale: Record the ritual retirement; assert the legacy 802/3/3 aggregate is UNCHANGED (no masking).

- Change: Add `tests/install/test-selftest-replica-default.sh` (standalone hermetic, mirrors `test-run-start-arming.sh`).
  Files: `tests/install/test-selftest-replica-default.sh`
  Rationale: Prove the default is tree/mode-independent and the hatch is real, without touching the real repo (all mutation in a sandbox clone under mktemp).

## Acceptance Criteria

- Criterion: The replica default is tree-independent, and the tree coupling is real (cheap two-tool FLIP — no full-leg re-run).
  Verification Method: In a sandbox clone with a tracked-file mod in its working tree, drive ONLY the tree-coupled tool `dmc-v0.6.0-verify.sh` (matches T003): run it from the clean committed replica => V15 PASS; run the same tool in-place against the dirty sandbox tree => V15 FAIL. Replica-arm-passes while in-place-arm-flips proves both tree-independence and a genuine coupling, in seconds rather than a ~12-min full-leg run. (test C2)
- Criterion: The replica default is mode-independent, and the mode coupling is real (cheap two-tool FLIP — no full-leg re-run).
  Verification Method: In a sandbox clone with `.harness/mode=passive`, drive ONLY the mode-coupled tool `dmc-v0.1.3-verify.sh` (matches T003): run it from the committed replica (no mode file => active) => the `npm` ask assertion PASSES; run the same tool in-place against the passive sandbox => it FAILS. Replica-passes / in-place-flips proves mode-independence and a genuine coupling, no full-leg re-run. (test C3)
- Criterion: The `--in-place` escape hatch is real and preserves today's working-tree behavior byte-for-byte.
  Verification Method: The in-place arms of C2/C3 ARE the hatch — `--in-place` drives those same two coupled tools (`dmc-v0.6.0-verify.sh`, `dmc-v0.1.3-verify.sh`) against the sandbox working tree, reproducing the coupled FAIL (V15 on the dirty tree; the mode assertion under passive) that the replica default suppresses, confirming `--in-place` targets the working tree. (test C4)
- Criterion: Provisioning failures fail LOUD, never silently fall back to in-place.
  Verification Method: In a sandbox with `.git` removed (or git absent from PATH), default `legacy-all` prints the distinct `FATAL: ... replica provisioning failed` on stderr, rc!=0, and does NOT print 802/3/3. (test C5)
- Criterion: The live mirror integrity check is unweakened.
  Verification Method: `bin/dmc selftest` (no-arg, fast) still runs `legacy-mirror` (`mirror --self-test`) in-place against the live tree — its 4 M1-M4 checks pass; the leg is textually unchanged (diff shows no edit to line 562). (verification cmd)
- Criterion: The real repo is left byte-identical by the new default and by the test.
  Verification Method: `git status --porcelain` byte-identical before/after a default `bin/dmc selftest legacy-all` run and after the full test suite (all writes in mktemp). (test Z)
- Criterion: The legacy 802/3/3 aggregate is EXACT and UNCHANGED (no masking) on a clean committed baseline.
  Verification Method: On a clean committed replica (the new default itself, or a clean checkout), `bin/dmc selftest legacy-all` == `tools=49 PASS=802 FAIL=3 N/A=3` EXACT. (test C1)
- Criterion: Frozen mirrors and PINNED_BASELINE are byte-untouched.
  Verification Method: `git diff --name-only` shows no `bin/lib/dmc-v0.*`, no `dmc-legacy-selftest.py`, no `.harness/evidence/*` change; `bin/dmc mirror-check` clean.
- Criterion: No dangling references introduced.
  Verification Method: `bin/dmc linkcheck` exit 0.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Silent fallback to in-place on a provisioning failure resurrects the flake class | high | Helper returns 1 with a distinct FATAL message; never runs in-place on failure; test C5 asserts this |
| Clone writes back into / dirties the source repo | high | `--no-hardlinks` (copies objects, no source hardlinks) + `remote remove origin` (sever) + writes only to mktemp; test Z asserts source porcelain unchanged |
| Local clone checks out the wrong branch/commit | medium | Helper asserts replica HEAD sha == source HEAD sha, fails loud on mismatch |
| Redirecting the leg weakens the frozen-mirror integrity check | medium | The `legacy-mirror` leg (`bin/dmc:562`) is SEPARATE and stays in-place; only line 565 changes — live bin/lib<->evidence equality still verified every run |
| Temp dir leak on abnormal exit | low | `trap 'rm -rf "$REPLICA"'` on EXIT in the helper |
| Reader assumes the replica default also fixes env-var coupling | low | Residual risk documented + HONEST_SCOPE clause scopes the fix to tree+mode only |
| A future edit adds a live-tree/live-mode read to a non-legacy `--all` leg | low | m-suites verified hermetic today; test C2/C3 pin tree/mode-independence of the aggregate at the leg boundary |

## Assumptions

| Assumption | Confidence | How to Verify |
|---|---|---|
| A local `git clone <path>` checks out the source's currently-checked-out branch HEAD | high | Helper's replica-HEAD==source-HEAD assertion enforces it at runtime; test C1 green confirms |
| `selftest-all` cannot be pointed at a foreign root except by running that root's own copy | high | `dmc-legacy-selftest.py:129-131` — `repo_root()` is `__file__/../..`, no `--root` arg |
| Only the legacy leg is tree/mode-coupled; the rest of `--all` is hermetic | high | Confirmed: m-suite porcelain refs are BEFORE==AFTER self-checks; mode touches are on own sandboxes (grep of `tests/fixtures/**`) |
| Clone overhead is negligible vs the ~2-3 min legacy replay | high | `.git` ~990 KiB packed / 699 files => ~1-3 s clone |
| Adding a `legacy-all` target + `--in-place` flag does not alter the 802/3/3 count | high | The count comes from `selftest_all()` (unchanged); test C1 pins EXACT |
| `git archive` is NOT viable | high | V15 (`dmc-v0.6.0-verify.sh:148`) needs a real `.git` for `git status --porcelain`; archive has none |

## Execution Tasks

- [ ] DMC-T001: Add `run_legacy_selftest_all()` helper + `--in-place` pre-scan in `bin/dmc`; redirect line 565 through it.
  Files: `bin/dmc`
  Notes: Clone-of-HEAD via `git clone --no-hardlinks --quiet` + `remote remove origin` + HEAD-sha assert + trap cleanup; fail-loud, never fall back.
- [ ] DMC-T002: Add the `legacy-all` target to the per-target dispatch loop; update `selftest --all` usage text.
  Files: `bin/dmc`
  Notes: Route through the same helper; honor `--in-place`.
- [ ] DMC-T003: Add `tests/install/test-selftest-replica-default.sh` (C1-C5 + Z).
  Files: `tests/install/test-selftest-replica-default.sh`
  Notes: Sandbox-clone the real repo into mktemp for the negative controls; run the full default leg green at least once (C1); prove the dirty/mode FLIP cheaply on the two coupled tools where a full 49-tool re-run per control is too slow; assert real-repo porcelain unchanged (Z).
- [ ] DMC-T004: Add the HONEST_SCOPE clarifying clause + append the MILESTONES v1.1.6 entry.
  Files: `docs/DMC_V1_HONEST_SCOPE.md`, `docs/MILESTONES.md`
  Notes: "legacy 802/3/3 UNCHANGED"; append-one; no rewrite of historical prose.

## Verification Commands

| Command | Reason | Required |
|---|---|---|
| `bash tests/install/test-selftest-replica-default.sh` | The feature's own hermetic suite (C1-C5 + Z) | yes |
| `bin/dmc selftest legacy-all` | Default replica leg on a clean baseline == 802/3/3 EXACT | yes |
| `bin/dmc selftest legacy-all --in-place` | Escape hatch runs in-place (reproduces today's behavior) | yes |
| `bin/dmc selftest --all` | Full battery still green end-to-end (dominant runtime; committed-replica leg included) | yes |
| `git status --porcelain` (before/after a default leg run) | Real repo byte-identical (hermetic) | yes |
| `bin/dmc mirror-check` | Frozen bin/lib<->evidence mirrors byte-identical (leg 562 unweakened) | yes |
| `git diff --name-only` | No frozen `dmc-v0.*` / `dmc-legacy-selftest.py` / `.harness/evidence` change | yes |
| `bin/dmc linkcheck` | No dangling verb/path/role references | yes |
| `bin/dmc validate plan .harness/plans/dmc-fable-core-replica-default.md` | Plan is schema-valid | yes |

## Approval Status

Status: APPROVED
Approver: human envelope gate (user directive 2026-07-10 "3번도 착수하자") + critic r1 APPROVE (dmc-fable-core-replica-default-critic-r1.json)
Approved At: 2026-07-10

Revisions:
- Rev 2: folded critic r1 advisory nit #1 (AC C2-C4 two-tool FLIP wording, matching T003); approval flipped under the envelope; re-submitted for critic r2 hash re-bind.
