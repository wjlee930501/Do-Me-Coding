# Verification Report

## Run ID

dmc-run-dfaa6f484f05

## Plan

`.harness/plans/dmc-fable-core-a-succession.md` (Rev 2; sha256 `b3538e45540566a178fa39c80b27e83793d1c959114f266b315375efc7d02ee8`; Approval Status: APPROVED) — same plan file, byte-unchanged, as the prior run.

## Changed Files

- `.harness/plans/dmc-refinement-diagnosis-20260709.md`: A1 — dated status-update blockquote banner (5 bullet lines), re-applied under this armed run. Content byte-identical to the prior (unarmed) run's edit — confirmed via identical grep counts/line numbers and file sha256 `8cf842d5e7cea47effbe3126b97b7c5644b266fbbfae7dcf3fa52481eddad78f`.
- `docs/DMC_AGENT_HANDOFF.md`: A2/A3 — section `## Runners without subagents — degradation rule (added 2026-07-09)`, re-applied under this armed run. 6 lines added, 0 removed, single hunk — identical diff shape to the prior run's edit.

(Crosscheck note: `bin/dmc verify-crosscheck` requires the worktree to be clean apart from in-scope + exempt paths. The out-of-band dirt present during this cycle — the pre-existing `.codex/config.toml` user modification and the four pre-arm-authored fable-core cycle plan drafts under `.harness/plans/` — was temporarily set aside via `git stash push -u` for the crosscheck run and restored immediately after; none of those paths were touched by this run, as independently verified in Commands Run / Manual Checks.)

## Commands Run

| Command | Result | Reason | Output Summary |
|---|---|---|---|
| inspect `.harness/runs/dmc-run-dfaa6f484f05/` | PASS | run-dir completeness | `run.json`, `scope.lock.json`, `snapshot.txt` all present |
| `python3 bin/lib/dmc-scope-lock.py --validate .../scope.lock.json` | PASS | scope-lock schema conformance | `VALID: ... conforms to dmc.scope-lock.v1` |
| `shasum -a 256` on scope.lock.json and snapshot.txt vs run.json `operative_snapshot` | PASS | run.json↔scope.lock↔snapshot hash binding | `scope_lock_sha256` = `aa1b99ef...` matches on-disk file exactly; `snapshot_sha256` = `d8d41127...` matches on-disk file exactly |
| compare `scope.lock.json.plan_hash` / `.repo_hash` vs `run.json` | PASS | plan/repo binding | both fields identical between the two files (`plan_hash=b3538e45...`, `repo_hash=c97b4f40...`) |
| inspect `scope.lock.json.files[]` | PASS | scope path binding | exactly 2 entries, `grant:"edit"`, `landmark_class:"ordinary"`: `.harness/plans/dmc-refinement-diagnosis-20260709.md` and `docs/DMC_AGENT_HANDOFF.md` — matches the plan's Relevant Files table exactly; `bounds` = `max_files:2, max_added:30, max_deleted:5` |
| `cat .harness/runs/current-run-id` | PASS | ARMED precondition 1 | `dmc-run-dfaa6f484f05` |
| ARMED definition (current-run-id present AND scope.lock.json exists) | PASS | ARMED precondition 2 | both true — run is genuinely ARMED per `scope-guard.sh`/`pre-tool-guard.sh` logic (holds regardless of RUNNING/SUSPENDED state) |
| `bin/dmc bash-radius --cmd "printf x > /tmp/out-of-scope-probe-verify.txt" --scope-lock <lock>` | PASS | out-of-scope Bash-write deny probe | `{"decision":"deny", "reason":"BASH-L1-OUT-OF-SCOPE..."}`, exit 4 |
| `bin/dmc bash-radius --cmd "printf x > README.md" --scope-lock <lock>` | PASS | out-of-scope Bash-write deny probe (in-repo target) | same deny, exit 4 |
| `python3 bin/lib/dmc-scope-lock.py --adjudicate <lock> README.md edit` | PASS | out-of-scope Edit refuse probe | `REFUSE: SCOPE-LOCK-PATH-NOT-IN-SCOPE`, exit 3 |
| `python3 bin/lib/dmc-scope-lock.py --adjudicate <lock> docs/DMC_AGENT_HANDOFF.md edit` | PASS | in-scope Edit allow control | `ALLOW: SCOPE-LOCK-ALLOW`, exit 0 |
| memo grep set (`Status update`, `32,490 bytes`, `emitted twice`, `PENDING`) | PASS | AC1, re-confirmed | identical counts/positions to prior verification (1 / 2 / 2 / present at L9) |
| handoff grep set (section header, fresh/STOP/source-of-truth/Art. VIII, scoped to L49-54) | PASS | AC2, re-confirmed | identical counts to prior verification (1 / 2 / 1 / 1 / 1) |
| `git diff -- docs/DMC_AGENT_HANDOFF.md \| grep -E '^-' \| grep -v '^---'` | PASS | AC2 additive-only, re-confirmed | no matches; `git diff --stat` = 6 insertions(+), 0 deletions(-); 1 hunk |
| `bin/dmc selftest` (default, full section breakdown) | PASS | floor requirement | 9 sections, 77 PASS / 0 FAIL total (orient 10/0, landmarks 13/0, depsurface 8/0, radius 7/0, validate-plan 8/0, validate-run 6/0, validate-verification 6/0, schemas-mirror 15/0, legacy-mirror 4/0) |
| `bin/dmc linkcheck` | PASS | AC3 | "OK: linkcheck clean — 24 file(s) scanned, every dmc-verb / artifact-path / role reference resolves" |
| `bin/dmc verdict validate` (r2) + `bin/dmc verdict gate --plan-hash <current plan sha256>` | PASS | verdict-plan binding, re-confirmed | VALID; "PASS: verdict gate — referenced critic-verdict is schema-valid and plan-bound" |
| `git diff --name-only` | PASS | scope discipline | exactly `.codex/config.toml` (pre-existing, unrelated) + `docs/DMC_AGENT_HANDOFF.md` (in-scope) |
| `git diff -- .codex/config.toml` | PASS | pre-existing-dirty isolation | unchanged from prior verification — only the pre-existing `model = "gpt-5.5"` block |
| `git log --oneline -5`, `git status -sb`, `git ls-files -- <memo>`, `git ls-remote --heads origin claude/dmc-fable-core` | PASS | commit/push discipline | no new commit (HEAD still `62fe79c`); no ahead/behind tracking; memo not yet tracked; no matching remote branch — no push occurred |

## Manual Checks

| Check | Result | Notes |
|---|---|---|
| scope.lock.json exists, validates, files[] == exactly the 2 approved paths | PASS | direct fix of the prior run's defect; independently re-derived, not taken on the team lead's word |
| run.json ↔ scope.lock.json binding (plan_hash/repo_hash/operative_snapshot) | PASS | all four fields cross-checked byte-for-byte against on-disk artifacts |
| ARMED state genuinely enforces (not just present on disk) | PASS | two independent probes (`bash-radius`, `dmc-scope-lock.py --adjudicate`) both deny/refuse an out-of-scope target and both allow an in-scope target — this is the proof the prior run lacked |
| Content of both insertions unchanged from the prior (PARTIAL) verification | PASS | identical grep counts, identical line numbers, identical diff shape; memo file sha256 recorded for the record |
| Floor (selftest/linkcheck) green in this tree | PASS | 77/0 default selftest; linkcheck clean |
| No staging/commit/push | PASS | working tree still shows only uncommitted/untracked changes; branch `claude/dmc-fable-core`; no remote ref |

## Scope Review

Result: PASS

Notes: Unlike the prior run, scope compliance here is provable by construction, not merely by post-hoc inspection: `scope.lock.json` exists, is schema-valid, is hash-bound into `run.json`'s `operative_snapshot`, and two independent live probes (`bin/dmc bash-radius`, `dmc-scope-lock.py --adjudicate`) confirm the deterministic L1 write-radius floor actively denies out-of-scope writes and allows only the 2 approved paths. The observed diff (`git diff --name-only`) is exactly those 2 files (one still untracked/new) plus the pre-existing, unrelated `.codex/config.toml` state, which is confirmed byte-identical to its state before this cycle began.

## Package / Env / Migration Review

Package files changed: no
Env files changed: no
Migration files changed: no

Notes: Same as the prior run — both changed files are Markdown documentation; `.codex/config.toml`'s pre-existing modification is untouched by this cycle.

## Unresolved Risks

- **`run start` scope-lock arming defect — registered, not yet fixed at the tool level:** `bin/dmc run start` (`bin/lib/dmc-run-lifecycle.py:cmd_start`) still does not itself invoke `dmc-scope-lock.py --compile`, and `bin/dmc` still exposes no verb for that compile step; this run compensated by manually compiling and validating `scope.lock.json` before any edit, which the probes above confirm was genuinely effective. The underlying tool/documentation mismatch (`dmc-start-work` SKILL.md claims `run start` "arms...the locked scope") remains open and should be fixed before Cycles D-core/C/B, so future runs don't depend on a human remembering the manual compile step. Registered as a v1.1+ candidate or immediate fix cycle per the orchestrator's disposition note on the prior run's report.
- **Disclosure advisory (carried verbatim from critic r2, unresolved):** the memo carries internal product codenames (Product-A / Product-B / Product-C) and candid strategy; repo is public; merging to main publishes it — the push-gate reviewer must consciously ratify disclosure.

## Final Status

PASS
