# Plan — fable-core Cycle B (v1.1.2): repo-intel scan bounding (skip-set + gitignore-aware filter + hard caps)

Work ID: dmc-fable-core-b-repointel

## Goal

Bound the repo-intel walk so it is safe on large/messy host repos (memo risk #7, confirmed), with
LOUD refusal instead of silent truncation, and ZERO derived-artifact drift on this repo:

- **B1 — skip-set extension.** `bin/lib/dmc-repo-intel.py` `SKIP_DIRS` (`:31-32`) gains the
  memo-named generated dirs: `target`, `out`, `.next`, `coverage`, `vendor`, plus `.omc` (local
  orchestration state present in DMC-enabled repos, never a landmark source).
- **B2 — gitignore-aware file filter.** After the walk collects candidates, ONE batch
  `git -C <root> check-ignore --stdin` subprocess filters ignored files out (git's own semantics —
  no reimplemented .gitignore parser). Best-effort: no git / not a work-tree ⇒ filter skipped
  (current behavior). **Ambient-config neutralization (critic r1 B-2):** the subprocess is invoked
  with `-c core.excludesFile=/dev/null` AND an environment overriding
  `GIT_CONFIG_GLOBAL=/dev/null` + `GIT_CONFIG_SYSTEM=/dev/null` (a fixed subprocess env — the
  module still READS no ambient env var), so user-global/system git config can never alter the
  output. Honest residue, disclosed: `$GIT_DIR/info/exclude` (repo-local admin state, no config
  knob to disable) still applies — the determinism claim is therefore **"deterministic given the
  tree + the repo's local ignore state; ambient user/system config neutralized"**, and the module
  docstring's env-independence note is amended with this one sentence in the same edit.
- **B3 — hard caps, fail-LOUD.** `walk_files` enforces `--max-files` (default 20000) and
  `--max-seconds` (default 30) bounds; breaching either ⇒ REFUSE (exit 3) with a message naming
  the bound and the flag to raise it. NEVER a silent partial scan (a truncated landmark inventory
  masquerading as complete is the exact "no silent caps" anti-pattern). Disclosed caller nuance
  (critic r1 advisory): the AGENTS.md generator's `run_dmc_json` maps ANY non-zero exit to honest
  `Unknown` fields — so through THAT caller a cap breach degrades to visible Unknowns rather than
  a crash; the loud refusal guarantee holds on the direct `bin/dmc orient/landmarks/depsurface`
  paths. The elapsed-time budget uses a monotonic clock INTERNALLY only — no timing value ever
  lands in output bytes (the no-wall-clock-in-outputs house rule holds).
- **B4 — non-regression pin.** On THIS repo the bounded walk must be a no-op for committed
  artifacts: regenerated `AGENTS.md` byte-identical to the committed file (the generator consumes
  the walk via `dmc-agents-md.py`); `bin/dmc orient/landmarks/depsurface --validate` outputs stay
  VALID. (Ignored-local noise like `.omc/` dropping out of UNcommitted orient output is the
  intended improvement, not drift.) **Baseline dependency (critic r1 B-1, RESOLVED before this
  Rev):** the committed `AGENTS.md` was stale (missing the D-core recorder landmark) — reconciled
  by the disclosed D-core remediation commit `87e76eb` (regen; diff = the one landmark line +
  count-parity 106→107; full validation set green). AC#2's byte-identity diff is achievable as
  written against that baseline; the executor re-confirms the baseline is clean (`diff
  <(bin/dmc agents-md --stdout) AGENTS.md` empty) BEFORE touching repo-intel, and HALTS if not.

## User Intent

hardening (memo risk #7 — "Timeout / scale on big or messy repos", confirmed; v1.0.5 planning
explicitly deferred this as "A4 … changes what the scan walks → could change the derived landmark
set; needs its own verified cycle" — this IS that cycle).

Authorized THIS session by wjlee via AskUserQuestion envelope (2026-07-09): four cycles
A→D-core→C→B ratified "전체 비준" — critic-APPROVE-conditional auto-approval, LOCAL-commit autonomy
ceiling on `claude/dmc-fable-core`, push/main a separate human gate, 2 consecutive critic REJECTs =
halt + report. Critic APPROVE is the mandatory pre-build gate (verdicts at
`.harness/evidence/dmc-fable-core-b-critic-r*.json`).

## Current Repo Findings

(grounded 2026-07-09, this session)

- Finding: `SKIP_DIRS = {".git","node_modules","__pycache__",".venv","venv","dist","build",
  ".pytest_cache",".mypy_cache",".DS_Store"}` (`dmc-repo-intel.py:31-32`); `walk_files`
  (`:111-123`) prunes by that set, skips symlinks + `is_secret_path`, and has NO timeout, NO file
  cap, NO gitignore awareness. Memo lines 11-14 confirmed verbatim.
- Finding: `walk_files` consumers inside the module: `:151` (orient), `:297`, `:390` — all inherit
  the bounds; `bin/lib/dmc-agents-md.py` consumes repo-intel for the landmark derivation, so
  AGENTS.md regen byte-identity is the drift sentinel.
- Finding: the module already shells to git best-effort (`git_head`, `:92-108`, "plain/no-git"
  fallback; critic r1 corrected the earlier `git_meta` name) — B2's check-ignore follows the same
  graceful-degradation pattern.
- Finding (critic r1, empirically cleared): NO frozen v0 fixture or m-suite fixture pins the walk
  on a synthetic tree containing the newly-skipped dirs — the only `target/vendor/.omc/max-files`
  hits are in unrelated subsystems (v0.1.3 installer passive-detection, m8 doctor negcontrols,
  scope-overeager guard, worker-bounds JSON). T001's HALT probe stays as a belt-and-suspenders
  re-check, expected clear.
- Finding (critic r1, measured): `bin/dmc orient` on this repo ≈ 0.12 s over a 4,155-file walk —
  the 30 s default budget is ~250× the measured worst case (not "3×"), and the 20,000-file cap has
  ~5× headroom; neither default bound can fire on this repo.
- Finding (registered gotcha #4 — execution note for the AC): frozen `dmc-v0.6.0-verify.sh` V15
  reads the LIVE `git status`; the isolated-live `selftest --all` AC MUST run on a clean tree
  (stash the pre-existing `.codex/config.toml`; committed-replica/CI is authoritative) or it reads
  801/4/3 for reasons unrelated to this change.
- Finding: `bin/lib/*` is enforcement-class landmark surface → release-gate non-degrading FLAG
  expected; repo-intel is NOT in DEFAULT_PROTECTED (`dmc-v0.2.6-gate-check-runner.sh:22-31` lists
  hooks/workers/schemas only) → NO G4 override needed (v1.0.5-generator precedent).
- Finding: module self-test exists (`python3 bin/lib/dmc-repo-intel.py --self-test` wired into
  `bin/dmc selftest`) — B adds cases there; the recorder is untouched; legacy `--all` unaffected
  (repo-intel is not a legacy v0 tool… NOTE: verify at build whether repo-intel participates in
  any frozen v0 verify fixture; if a frozen fixture pins walk output on a synthetic tree, the new
  SKIP_DIRS entries must not intersect that fixture's dirs — executor probes this FIRST).

## Relevant Files

| Path | Reason | Allowed to Edit |
|---|---|---|
| `bin/lib/dmc-repo-intel.py` | B1+B2+B3 + self-test cases (enforcement-class landmark → FLAG expected, landmark_authorized) | yes |
| `docs/MILESTONES.md` | ONE v1.1.2 entry (append-only) | yes (append) |
| `AGENTS.md`, generator, hooks, schemas, frozen tools, installer | untouched (byte-identity is an AC, not an edit) | no |

## Out of Scope

- Any `dmc-agents-md.py` change (byte-identity proves none is needed).
- Reimplementing .gitignore semantics (git owns them; no-git repos keep today's behavior).
- Landmark-budget/top-N policy, §4 externalization (deferred v1.1+ register).
- Env-var knobs for the caps (flags only — the module reads no env by policy).
- Push / CI / main merge (human gate).

## Proposed Changes

- Change: `bin/lib/dmc-repo-intel.py` — extend SKIP_DIRS (B1); add `filter_ignored(root, paths)`
  batch check-ignore helper (single subprocess with the neutralized invocation per B2 — `-c
  core.excludesFile=/dev/null` + fixed subprocess env `GIT_CONFIG_GLOBAL=/dev/null`
  `GIT_CONFIG_SYSTEM=/dev/null`; newline-delimited stdin; best-effort fallback; paths containing
  newlines excluded defensively) applied inside `walk_files` before return, plus the one-sentence
  docstring amendment disclosing the info/exclude residue (B2); thread `max_files`/`max_seconds`
  (module constants DEFAULT_MAX_FILES=20000 / DEFAULT_MAX_SECONDS=30, CLI flags
  `--max-files/--max-seconds` on the scan verbs) through `walk_files` with a monotonic-clock
  budget check inside the loop — internal only, never emitted in output bytes; breach ⇒
  `die(...,3)` naming bound + flag (B3); add self-test cases: (i) synthetic tree with
  `target/`+`vendor/` pruned; (ii) gitignored file filtered when git present, retained under
  no-git fallback; (iii) max-files breach on a 30-file tree with `--max-files 10` ⇒ exit 3 +
  message; (iv) determinism (two runs byte-identical); (v) existing fixtures unchanged;
  (vi) ambient-config neutrality — a fixture repo plus a temp global excludes file that WOULD
  ignore a candidate ⇒ output byte-identical with and without that global config present (proves
  the neutralization).
  Files: `bin/lib/dmc-repo-intel.py`.
- Change: `docs/MILESTONES.md` — append ONE `## v1.1.2 — repo-intel scan bounding — LOCAL
  (2026-07-09)` entry (what/why, memo risk #7 closure-as-infrastructure, chain,
  push-gate-pending).
  Files: `docs/MILESTONES.md`.

## Acceptance Criteria

- Criterion: bounds + skip-set + filter work.
  Verification Method: module self-test (incl. the 5 new cases) 0 FAIL; manual probes: a temp tree
  with `target/x.py`+`vendor/y.js` excluded from `orient`; `--max-files 10` on a 30-file temp tree
  ⇒ exit 3 with the named bound; a gitignored temp file absent from output when git present.
- Criterion: zero derived-artifact drift on this repo.
  Verification Method: PRE-CHECK first (executor HALTs if the baseline is already dirty):
  `diff <(bin/dmc agents-md --stdout) AGENTS.md` empty BEFORE the change (baseline reconciled by
  `87e76eb`); then AFTER the change the same diff is empty again; `bin/dmc orient --out …` +
  `landmarks`/`depsurface` `--validate` ⇒ VALID; wall-clock of `orient` on this repo < 10s
  (no bound tripped; measured baseline ≈ 0.12 s).
- Criterion: ambient-config neutrality (critic r1 B-2).
  Verification Method: self-test case (vi) passes — with a temp global excludes file that would
  ignore a fixture candidate, output is byte-identical to the no-global-config run; module
  docstring carries the amended determinism sentence.
- Criterion: suites + gate.
  Verification Method: `bin/dmc selftest` 0 FAIL; committed-replica + isolated-live
  `bin/dmc selftest --all` legacy **802/3/3 EXACT** — executed CLEAN-TREE per registered gotcha #4
  (run after the change commit with the pre-existing `.codex/config.toml` stashed; a dirty-tree
  801/4/3 from frozen V15's live-git-status coupling is NOT a regression signal); m-suites green;
  `bin/dmc mirror-check` PASS; `bin/dmc linkcheck` clean; `dmc gate release --full --run-id <run>`
  PASS (FLAG on repo-intel expected; NO G4 override).
- Criterion: scope + autonomy ceiling.
  Verification Method: change-commit `git diff --name-only` == exactly the 2 in-scope files;
  records commit only records; both commits LOCAL on `claude/dmc-fable-core`; NO push;
  `.codex/config.toml` unstaged.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| A frozen v0 fixture pins the current walk on a synthetic tree containing a newly-skipped dir | medium | executor probes frozen fixtures FIRST (grep `target/|vendor/|check-ignore` across `bin/lib/dmc-v0*`); if any collision, HALT and surface (frozen tools never rewritten) |
| check-ignore drops something the landmark set needs on THIS repo | low | AGENTS.md byte-identity AC is blocking; tracked files are never gitignored, and landmarks derive from tracked surfaces |
| Timeout nondeterminism near the bound | low | budget uses a monotonic clock and only REFUSES (never truncates), so outputs are either complete or absent; default 30s is 3× this repo's worst case |
| New flags break existing callers | low | flags optional with defaults; `bin/dmc` dispatch passes argv through unchanged (verify `bin/dmc orient` unchanged signature) |

## Assumptions

| Assumption | Confidence | How to Verify |
|---|---|---|
| No frozen fixture depends on unbounded walk behavior | medium-high | T001 probe before any edit; halt on collision |
| `git check-ignore --stdin` available on the supported git range | high | best-effort fallback covers absence; self-test case (ii) |

## Execution Tasks

- [ ] DMC-T001: probe frozen-fixture collisions (grep across `bin/lib/dmc-v0*` + `tests/fixtures/`
  for walk-pinning); HALT if any. Then implement B1+B2+B3 + the 5 self-test cases; run module
  self-test + `bin/dmc selftest`.
  Files: `bin/lib/dmc-repo-intel.py`.
  Notes: Route: Sonnet 5, synchronous (bounded mechanical change; escalate to Opus if the fixture
  probe finds coupling).
- [ ] DMC-T002: drift + bounds verification (fresh verifier lane) → AGENTS.md byte-identity,
  temp-tree probes, suites, full gate → `.harness/verification/<run-id>.md` + build evidence
  `.harness/evidence/dmc-fable-core-b-build-20260709.md`; MILESTONES v1.1.2 entry; change commit +
  records commit (LOCAL; targeted `git add`; `.codex/config.toml` unstaged).
  Files: `docs/MILESTONES.md` (+ records, scope-exempt).
  Notes: Route: verifier = Opus 4.8 fresh lane (generator-adjacent surface); commits by
  orchestrator under the envelope grant.

## Verification Commands

| Command | Reason | Required |
|---|---|---|
| `python3 bin/lib/dmc-repo-intel.py --self-test` (new cases included) | module floor | yes |
| temp-tree probes (skip-set, check-ignore, `--max-files 10` refuse) | B1-B3 behavior | yes |
| `diff <(bin/dmc agents-md --stdout) AGENTS.md` empty; orient/landmarks/depsurface `--validate` VALID | zero derived drift | yes |
| `bin/dmc selftest`; committed-replica + isolated-live `--all` 802/3/3 EXACT; m-suites; mirror-check; linkcheck | regression floor | yes |
| `dmc gate release --full --run-id <run>` (FLAG expected, no override) | gate | yes |
| `git diff --name-only` per commit; no push | scope + ceiling | yes |

## Approval Status

Status: APPROVED
Approver: wjlee (woojin20020@gmail.com)
Approved At: 2026-07-09 (this-session AskUserQuestion envelope "전체 비준": cycles A→D-core→C→B,
critic-APPROVE-conditional, LOCAL-commit autonomy ceiling on `claude/dmc-fable-core`, push/main a
separate human gate, 2 consecutive critic REJECTs → halt + report). Critic APPROVE is the mandatory
pre-build gate; this plan is not built unless a schema-valid APPROVE verdict binds this file's
sha256 via `bin/dmc verdict gate`.

Revisions: Rev 1 → critic r1 REJECT (2 blockers,
`.harness/evidence/dmc-fable-core-b-critic-r1.json`): B-1 = the zero-drift AC was unachievable —
the committed AGENTS.md baseline was ALREADY stale (missing the D-core recorder landmark; an
escaped D-core lockstep, resolved OUTSIDE this plan by the disclosed remediation commit `87e76eb`
before this Rev; the AC now stands as written with an executor pre-check + HALT). B-2 = raw
`git check-ignore` would couple output to ambient user/system git config, contradicting the
module's env-independence rule — folded as the neutralized invocation (`-c
core.excludesFile=/dev/null` + `GIT_CONFIG_GLOBAL/GIT_CONFIG_SYSTEM=/dev/null` subprocess env),
the disclosed `info/exclude` residue + amended determinism claim, and new self-test case (vi)
proving neutrality. Advisories folded: generator-path Unknown-degradation disclosure; clean-tree
execution note for the 802/3/3 AC (gotcha #4); `git_meta`→`git_head :92-108` correction; the
"3×" claim replaced with the measured ≈0.12 s / ~250× headroom. Re-submitted for a fresh critic
pass (r2).
