# Verification Report

## Run ID

dmc-run-880cb5a91f23

(Run state at verification time: SUSPENDED; scope.lock armed — `.harness/runs/current-run-id` confirms this is the active armed run.)

## Plan

`.harness/plans/dmc-fable-core-b-repointel.md` (Rev 2). Binding independently re-derived:
- `shasum -a 256` of the plan file = `7cca79e5645fcd5390df7aa940a1a8c2532059d1952df1efb0843c33d4136b3b` == run.json `plan_hash` == scope.lock `plan_hash` == critic r2 `plan_hash`. Four-way match.
- `dmc verdict gate --verdict …-b-critic-r2.json --plan-hash 7cca…6b3b` → PASS (critic r2 APPROVE schema-valid + plan-bound; C11 opens no gate).
- scope.lock `files[]` == exactly 2 paths: `bin/lib/dmc-repo-intel.py` (edit / enforcement / landmark_authorized true), `docs/MILESTONES.md` (edit / release / landmark_authorized true). Bounds 2 / 450 / 40; compiled_at_head 87e76eb.

## Changed Files

- `bin/lib/dmc-repo-intel.py`: SKIP_DIRS +{target,out,.next,coverage,vendor,.omc}; `filter_ignored()` batched `git check-ignore --stdin -z` with ambient-config neutralization; `walk_files` monotonic max-files/max-seconds budget with `die(…,3)`; `--max-files`/`--max-seconds` flags; docstring determinism amendment; +7 self-test assertions (O6–O10). (+184 / −10)
- `docs/MILESTONES.md`: one append-only v1.1.2 entry. (+52 / −0)

(Crosscheck note: out-of-band paths present during this cycle — the pre-existing `.codex/config.toml` modification (in the arming `snapshot.txt`; diff still only the pre-existing `model = "gpt-5.5"` block) and untracked governance artifacts (cycle b/c plans under `.harness/plans/`, critic verdicts under the exempt `.harness/evidence/`) — are NOT this run's mutations; the orchestrator sets non-exempt dirt aside via the established `git stash push -u` procedure for the crosscheck run and restores immediately after.)

## Commands Run

| Command | Result | Reason | Output Summary |
|---|---|---|---|
| `shasum -a 256` plan vs run.json/scope.lock/critic-r2 | PASS | run binding | four-way `plan_hash` identity `7cca…6b3b` |
| `dmc validate plan …-b-repointel.md` | PASS | approved-plan instance | VALID (dmc.plan-instance.v1), exit 0 |
| `dmc verdict gate --verdict r2 --plan-hash 7cca…` | PASS | critic APPROVE binding | plan-bound + schema-valid, exit 0 |
| `dmc run status --run-id …` | PASS | run-state | SUSPENDED, active:false, exit 0 |
| `dmc bash-radius --cmd "…> bin/lib/oos-probe.py" --scope-lock …` | PASS | live out-of-scope write probe | deny, tier L1, exit 4 |
| `dmc bash-radius --cmd "…> bin/lib/dmc-repo-intel.py" --scope-lock …` | PASS | live in-scope write probe | allow, tier L1, exit 0 |
| `python3 bin/lib/dmc-repo-intel.py orient --self-test` | PASS | module floor | 17 PASS / 0 FAIL |
| `… landmarks/depsurface/radius --self-test` | PASS | module floor | 13/0 · 8/0 · 7/0 |
| `dmc agents-md --stdout \| diff - AGENTS.md` | PASS | drift sentinel | empty diff, exit 0 |
| `dmc orient/landmarks/depsurface \| … --validate /dev/stdin` | PASS | fresh-artifact validity | all three VALID, exit 0 |
| `time dmc orient` | PASS | budget headroom | 0.158s total, 601 bytes (≪ 10s / 30s / 20000) |
| `dmc selftest` (default set) | PASS | regression floor | orient17 landmarks13 depsurface8 radius7 validate-plan8 validate-run6 validate-verification6 schemas-mirror15 legacy-mirror4 metrics9 — every section 0 FAIL, exit 0 |
| `dmc mirror-check` | PASS | bin/lib↔evidence parity | 55-file set byte-identical, RESULT PASS, exit 0 |
| `dmc linkcheck` | PASS | reference integrity | clean, 24 files scanned, exit 0 |
| `git diff --numstat` / `--cached` / `log -1` | PASS | scope + ceiling | 2 in-scope +.codex; nothing staged; HEAD 87e76eb |
| `grep -n os.environ` module | PASS | env-read discipline | see Manual Checks |

Note: `dmc selftest --all` deliberately NOT run on the live tree — the uncommitted repo-intel edit plus the pre-existing dirty `.codex/config.toml` trip frozen `dmc-v0.6.0-verify.sh` V15's live `git status` read (registered gotcha #4). Clean-tree `--all` 802/3/3 EXACT is the orchestrator's post-commit step (with `.codex/config.toml` stashed) — the D-core-precedent procedure, intentionally out of the verifier's live-tree scope.

## Manual Checks

| Check | Result | Notes |
|---|---|---|
| (a) skip-set prunes target/vendor | PASS | own mktemp tree: target/x.py + vendor/y.js excluded; orient languages = {py:1} (src/keep.py only) |
| (b) --max-files 10 on 30-file tree | PASS | own probe: exit 3, `walk exceeded --max-files=10 (raise the bound with --max-files N)` — names bound + flag |
| (c) --max-seconds 0 | PASS | own probe: exit 3, `walk exceeded --max-seconds=0 (raise the bound with --max-seconds N)` |
| (d) gitignore filter — retention half | PASS | own probes: non-ignored keep.py retained under git AND under no-git fallback (languages {py:1} both) |
| (d) gitignore filter — positive-exclusion half | PASS (via re-run self-test) | freshly re-executed O7 (git present: ignored.txt filtered, kept.txt+.gitignore retained) + O7b (no-git retained); own `.gitignore`-with-pattern fixture not constructible under armed-run write constraints (no redirects / no Write tool), so this half rests on the fresh O7 run + source read of `:672-700` confirming the fixture is genuine — disclosed, not assumed |
| (e) determinism | PASS | own probe: two orient runs byte-identical (sha256 `d96baf16…c896` twice) |
| (f) ambient-config neutrality | PASS | O9 (positive control: RAW check-ignore under simulated ambient global-excludes DOES filter candidate.log — fixture bites) + O10 (module output identical with/without ambient config) pass in the fresh 17/0 run; source spot-read of `filter_ignored` (`:119-152`): `env=dict(os.environ)` then override ONLY `GIT_CONFIG_GLOBAL`/`GIT_CONFIG_SYSTEM`=/dev/null; `-c core.excludesFile=/dev/null`; `-z` NUL stdin + `set(stdout.split("\x00"))`.discard(""); newline paths partitioned out and returned unfiltered; best-effort fallback returns paths unchanged on no-git / exception / returncode∉{0,1} (0=some-ignored, 1=none-ignored both success) |
| Docstring amendment present | PASS | `:11-14` carries the "deterministic given the tree plus the repo's local ignore state … ambient user/system git config is neutralized" sentence |
| No ambient env READS on the output path | PASS | only `dict(os.environ)` at `:137` (subprocess-env construction w/ fixed GIT_CONFIG_* overrides — allowed); `:124` docstring text; `:738/751/753/757/759` hermetic self-test scaffolding (save+restore GIT_CONFIG_GLOBAL). No env value branches generation output |
| MILESTONES entry append-only | PASS | single `## v1.1.2` block at EOF (+52/−0); prior entry unchanged; forward-looking `--all 802/3/3` + `--full` gate claims explicitly attributed to verifier/T002, not claimed done |

## Scope Review

Result: PASS

Notes: `git diff --name-only` = exactly `bin/lib/dmc-repo-intel.py`, `docs/MILESTONES.md`, and pre-existing `.codex/config.toml`. In-scope edit totals 2 files / +236 / −10, within scope.lock bounds 2 / 450 / 40. No frozen v0 tool, hook, schema, installer, generator (`dmc-agents-md.py`), or `AGENTS.md` diff. `.codex/config.toml` is enforcement-class but its change is pre-existing arming-snapshot noise. Live bash-radius probes prove the armed scope-lock adjudicates in-scope→allow(0) / out-of-scope→deny(4); a stray `2>/dev/null` in one of the verifier's own inspection commands was organically denied by the same guard, independently confirming enforcement is live.

## Package / Env / Migration Review

Package files changed: no
Env files changed: no (`.codex/config.toml` is Codex harness config, pre-existing, out-of-band; no `.env*`, no secrets touched)
Migration files changed: no

Notes: One stdlib-only Python module (no new imports beyond already-present `subprocess`/`time`/`os`) plus a docs append. `filter_ignored` shells to `git check-ignore` offline/read-only; no network, no secret read (is_secret_path pre-filter runs before the subprocess).

## Unresolved Risks

- Clean-tree legacy `dmc selftest --all` 802/3/3 EXACT confirmation pending post-commit (D-core precedent): not run on the live tree because the uncommitted edit + dirty `.codex/config.toml` trip frozen V15's live-git-status coupling; orchestrator runs it clean-tree with `.codex/config.toml` stashed after the change commit.
- `dmc gate release --full --run-id …` (FLAG expected on `bin/lib/*`, no `DMC_GATE_PROTECTED` override) NOT run by the verifier — it writes `release-readiness.json`, a mutation outside the read-only verifier ceiling; orchestrator-owned post-commit evidence, same bucket as clean-tree `--all`.
- Open run-start arming defect (manually compensated, probe-proven): run is SUSPENDED yet the guard enforces — verified live via deny-4 / allow-0 bash-radius probes and the organic `2>/dev/null` denial, so the manual arming is functionally effective.
- Push-gate disclosure advisory: the v1.1.2 MILESTONES entry and memo codenames go public on merge; push / main-FF is a separate human gate per the AskUserQuestion envelope (LOCAL-commit autonomy ceiling only).

## Final Status

PASS
