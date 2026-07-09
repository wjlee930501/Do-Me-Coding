# Verification Report

## Run ID

dmc-run-17dde24df36f

(SUSPENDED; scope.lock armed and immutable. Independently re-verified against APPROVED plan `.harness/plans/dmc-fable-core-e-runstart.md` Rev 2; no prior report trusted.)

## Plan

`.harness/plans/dmc-fable-core-e-runstart.md` — fable-core Cycle E (v1.1.3): run-start scope arming. Binding chain verified: sha256(plan) = `8c34ebffb761700fa1905c1fd3e302ef70d33f3a9f5cacebb1eac34fbceb6319` == run.json `plan_hash` == scope.lock `plan_hash` == critic r2 `plan_hash`. Critic r1 = NEEDS_CLARIFICATION on Rev 1 (hash `1f0751f8…`, blockers B1 shared-exec unreachability + B2 cwd-relative composition); critic r2 = APPROVE on Rev 2 (hash `8c34ebff…`, 0 blockers), lenses correctness/scope/security. `compiled_at_head` = HEAD `c6ed931`.

## Changed Files

- `bin/dmc`: E1 dispatch composition (SCOPELOCKLIB constant; `start` split into non-exec captured call; --scope-input extraction; --root threading; fail-closed teardown) + E2 warning + usage rewrite. In-scope, edit/enforcement/landmark_authorized.
- `.claude/skills/dmc-start-work/SKILL.md`: E3 step-3 truth repair + scope-input JSON shape + step-4 no-lock-no-edit STOP rule. In-scope, edit/ordinary.
- `.agents/skills/dmc-start-work/SKILL.md`: E3 lockstep mirror (byte-identical change content). In-scope, edit/ordinary.
- `docs/MILESTONES.md`: one appended v1.1.3 entry. In-scope, edit/release/landmark_authorized.
- `tests/install/test-run-start-arming.sh`: E4 standalone hermetic test (24 assertions), untracked. In-scope, create/ordinary.

(Crosscheck note: out-of-band, all correctly outside the scope.lock — `.codex/config.toml` is a pre-existing working-tree modification (model config), unrelated to this cycle, unchanged from its known session-start diff, unstaged; untracked governance records `.harness/plans/dmc-fable-core-e-runstart.md`, `.harness/evidence/dmc-fable-core-e-critic-r1.json`, `.harness/evidence/dmc-fable-core-e-critic-r2.json` are plan/evidence class. Non-exempt out-of-band dirt is set aside via the established `git stash push -u` procedure for the crosscheck run and restored immediately after. No stray files from verifier probes.)

## Commands Run

| Command | Result | Reason | Output Summary |
|---|---|---|---|
| `bash -n bin/dmc` | PASS | syntax floor | SYNTAX-OK |
| `python3 bin/lib/dmc-scope-lock.py --validate <run lock> --root .` | PASS | lock validity | `VALID … conforms to dmc.scope-lock.v1`, rc 0 |
| `bin/dmc bash-radius --cmd 'echo x > /…/OUT_OF_SCOPE_PROBE.txt' --scope-lock <run lock>` | PASS | live deny probe (committed lock) | `deny` / `BASH-L1-OUT-OF-SCOPE`, rc 4 |
| `bin/dmc bash-radius --cmd 'echo x > docs/MILESTONES.md' --scope-lock <run lock>` | PASS | live allow probe (in-scope, relative) | `allow` / `BASH-L1-IN-SCOPE`, rc 0 |
| `bash tests/install/test-run-start-arming.sh` | PASS | E1/E2 behavior matrix + ARMED-for-real (C1 bash-radius deny rc4 on a freshly-minted lock) + fail-closed teardown (C2) + back-compat both-stream byte-identity (C3/C4) + hermetic proof (Z) | 24 passed, 0 failed, exit 0 |
| `bin/dmc run start --plan /nonexistent … --root <mktemp>` vs direct RCORE (verifier's own refuse-path probe) | PASS | independent back-compat refuse-path | stdout byte-identical (`REFUSED: RUN-PLAN-NOT-FOUND…`), both rc 3, both temp roots empty, real pointer untouched |
| `bin/dmc selftest` (no-arg) | PASS | regression floor | every section 0 FAIL; recorder self-test 9/0 (INVALID/REFUSED lines are intentional negative controls) |
| `bin/dmc selftest m6-suite` | PASS | pinned dispatch consumer | 38/45/10/11, all 0 FAIL (incl. adversarial vf-a REJECT-refuses-arming + c1a/c1b armed guard) |
| `bin/dmc selftest m7-suite` | PASS | pinned dispatch consumer | 36/26/23, all 0 FAIL |
| `bin/dmc selftest m9-suite` | PASS | pinned dispatch consumer | 56/35, all 0 FAIL (e2e-loop drives `run start --root`) |
| `bin/dmc skills-mirror` | PASS | E3 lockstep | all 5 skills OK, no extra dmc-* skills, RESULT PASS |
| `bin/dmc agents-md --stdout \| diff - AGENTS.md` | PASS | derived-artifact neutrality | empty diff, rc 0 |
| `bash tests/fixtures/m8/test-manifest-drift.sh` | PASS | manifest neutrality | 10/0 |
| `bin/dmc mirror-check` | PASS | frozen-tool integrity | 55 files byte-identical, no strays, RESULT PASS |
| `bin/dmc linkcheck` | PASS | reference integrity | clean, 24 files scanned |
| `git --no-pager diff --numstat` / `--name-only` / status | PASS | scope + bounds | 5 files, 395 added / 17 deleted; core modules + hooks + frozen tools byte-untouched |

Deliberately NOT run (orchestrator lane, per task): `bin/dmc selftest --all` (clean-tree post-commit — V15 gotcha) and `dmc gate release --full` (staged-set gate). These remain the post-staging orchestrator/gate checks.

## Manual Checks

| Check | Result | Notes |
|---|---|---|
| scope.lock files[] == exactly 5 plan paths with correct grants | PASS | .agents/.claude SKILL edit/ordinary; bin/dmc edit/enforcement/landmark_authorized; MILESTONES edit/release/landmark_authorized; test create/ordinary |
| bounds match plan (5/550/60) | PASS | max_files 5, max_added 550, max_deleted 60 |
| `start` split to non-exec captured call; other run subcommands keep `exec` | PASS | suspend\|resume\|status\|block\|blocked-status\|unblock retain `exec python3 "$RCORE" "$sub" "$@"` verbatim |
| `--scope-input` removed from delegated argv; `--plan`/`--root` noted AND left in | PASS | while-loop: --scope-input consumed (not re-appended); --plan/--root appended to `delegated` |
| rc!=0 path adds nothing to either stream | PASS | `[ "$rc" -eq 0 ] \|\| exit "$rc"` before any bin/dmc output |
| WARNING is success-only, single stderr line | PASS | emitted only after rc==0 && empty scope_input, one `printf … >&2` then exit 0 |
| compile `--out` root-rooted; SCOPELOCKLIB absolute | PASS | `$scope_root/.harness/runs/$run_id/scope.lock.json`; `SCOPELOCKLIB="$HERE/lib/dmc-scope-lock.py"` |
| teardown order: suspend --root FIRST, then pointer rm, then exit 3 | PASS | matches cmd_suspend pointer-resolution requirement (critic r2 security lens) |
| SKILL.md false "mints and arms … locked scope" claim removed (both files) | PASS | `grep "mints and arms"` → no match in either file |
| new command form + scope-input shape + no-lock-no-edit STOP rule present (both) | PASS | `--scope-input` ×3 each; "No accepted file scope, no edit" at .claude:66 / .agents:70 |
| SKILL mirror lockstep | PASS | identical change content; skills-mirror clean |
| out-of-scope core files byte-untouched | PASS | dmc-run-lifecycle.py, dmc-scope-lock.py, .claude/hooks/, settings.json, a frozen dmc-v* tool → empty diff |
| HEAD unchanged; nothing staged; no commit/push | PASS | HEAD c6ed931; all changes unstaged (M/??); verifier is read-only |

## Scope Review

Result: PASS

Notes: `git diff --name-only HEAD` = the 4 tracked in-scope files (`bin/dmc`, both `SKILL.md`, `docs/MILESTONES.md`) plus the out-of-band pre-existing `.codex/config.toml` (unstaged, not in scope.lock, unchanged from its known diff); the new test file is untracked (create grant). Bounds honored: 5 files / 395 added / 17 deleted, within 5/550/60. All core modules, hooks, schemas, and frozen tools byte-untouched. No G4 override present or needed (`.claude/skills` not DEFAULT_PROTECTED); `bin/dmc` enforcement-class FLAG expected at the release gate (non-degrading), consistent with v1.1/v1.1.2 precedent.

## Package / Env / Migration Review

Package files changed: no
Env files changed: no
Migration files changed: no

Notes: No dependency manifests, lockfiles, or migrations touched. No `.env`/secret files read or altered. The only non-source out-of-band file is `.codex/config.toml` (Codex tool config, pre-existing, out-of-scope, unstaged) — surfaced under Changed Files, not part of this candidate.

## Unresolved Risks

- Clean-tree `bin/dmc selftest --all` (expected 802/3/3 EXACT) and `dmc gate release --full --run-id dmc-run-17dde24df36f` (FLAG on `bin/dmc` expected, no G4 override) are still pending — they are the orchestrator's post-staging checks and require the staged candidate + `.codex/config.toml` stashed. Not run here by design (read-only verifier lane).
- The run-start arming defect is now CLOSED at the tool level (the one-command `--scope-input` path arms a validated, immutable lock and denies out-of-scope writes for real). Historical runs that predate this fix remain lockless — an archival fact, no action.
- Push / CI / main-FF remain a separate human gate. This branch (`claude/dmc-fable-core`, post-redaction) is push-ready pending that gate; the standing envelope caps autonomy at LOCAL commit.

## Final Status

PASS
