# Plan — fable-core Cycle D-core (v1.1): run-metrics recorder wiring + effort/course CLI reachability

Work ID: dmc-fable-core-d-runmetrics

## Goal

Wire the dormant measurement layer into a usable, opt-in, ADVISORY surface — the memo §7-1 move
("this is wiring, not design") — WITHOUT any enforcement/floor/ceremony change:

- **D1 — metrics recorder (`bin/dmc metrics`).** New `bin/lib/dmc-metrics-recorder.py` +
  `bin/dmc metrics record|rollup|self-test` dispatch. `record --from <record.json>` validates the
  record via the FROZEN v0.5.0 validator (`bin/lib/dmc-v0.5.0-run-metrics.sh --validate`; never
  reimplement its rules), extracts the redacted free-form values from the frozen tool's
  deterministic emit (`--from` markdown lines), and APPENDS one compact JSONL row to the
  append-only local ledger `.harness/metrics/ledger.jsonl` (create-if-missing; refuse symlink
  ledger; append-only — never rewrite/truncate; refuse on validator non-zero). Redaction parity is
  inherited from the frozen tool, not duplicated. Ledger-path safety (critic r1 clarity note): the
  DEFAULT in-tree path `.harness/metrics/ledger.jsonl` is special-cased ALLOW (it is the designed
  destination; the frozen tools' `out_refused` would refuse ALL in-tree paths and must NOT be
  applied to it); ONLY a `--ledger` override path goes through the `out_refused`-style fail-closed
  check (refuse traversal/secret-shaped/symlink/system paths; permit repo-external temp paths for
  self-tests).
- **D2 — rollup.** `bin/dmc metrics rollup` reads the ledger JSONL and prints (stdout only) a
  deterministic aggregate: row count; counts by `outcome`, `effort`, `mode`; totals of
  `retry_count`/`human_gates`/`blockers`/`review_findings_total`; tests aggregate
  (selected/run/passed/failed sums); wall-clock sum + median. This is the §6b metrics skeleton —
  catch-rate/false-block classification stays a pilot-time human tagging concern, NOT built here.
- **D3 — effort/course CLI reachability.** `bin/dmc effort …` and `bin/dmc course …` pass argv
  through to the existing frozen advisory tools `bin/lib/dmc-v0.5.2-effort-controller.sh` and
  `bin/lib/dmc-v0.5.3-dynamic-workflow-selector.sh` (exit codes propagate). Today they are
  invocable only by full path — this makes the already-built light/standard/deep/adversarial
  course selection reachable from the Ring-0 CLI. No behavior change inside the frozen tools.
- **D4 — docs + hygiene.** `.gitignore` gains `.harness/metrics/` (ledger is out-of-band,
  local-only; a rollup is committed deliberately by a human if ever). `docs/DMC_OPERATOR_HANDBOOK.md`
  gains one short "Measuring a run (advisory, opt-in)" section: recommend course before a run
  (`dmc effort` / `dmc course`), record one row per real task after it (`dmc metrics record`),
  read `dmc metrics rollup` weekly. `docs/MILESTONES.md` gains ONE v1.1 entry (append-only,
  push-gate-pending line included).

Everything is additive + advisory: the enforcement floor (hooks, scope-lock, stop-gate, release
gate) is untouched; nothing invokes the recorder automatically; no gate reads the ledger
(anti-fake: the ledger measures, it never grades).

## User Intent

feature (measurement-layer wiring — the strategic memo's recommended smallest milestone §7-1 +
§7-3, scoped to infrastructure; pilot EXECUTION stays behind memo §9).

Authorized THIS session by wjlee via AskUserQuestion envelope (2026-07-09): four cycles
A→D-core→C→B ratified as "전체 비준" — critic-APPROVE-conditional auto-approval per cycle, autonomy
through the LOCAL commit gate on `claude/dmc-fable-core`, push/main a separate human gate, 2
consecutive critic REJECTs = halt the cycle + report. Critic APPROVE is the mandatory pre-build
gate (verdicts at `.harness/evidence/dmc-fable-core-d-critic-r*.json`, `bin/dmc verdict validate`
+ `bin/dmc verdict gate` binding before arming).

## Current Repo Findings

(grounded 2026-07-09, this session)

- Finding: run-metrics is dormant-but-complete — schema `.harness/schemas/run-metrics.schema.md`
  (**20** required fields per the frozen validator's REQ set (`dmc-v0.5.0-run-metrics.sh:55-57`;
  critic r1 corrected an earlier 19-count) incl. `effort ∈ {light,standard,deep,adversarial}`,
  `outcome`, consistency rule `tests_passed+tests_failed ≤ tests_run ≤ tests_selected`) + frozen validator/emitter
  `bin/lib/dmc-v0.5.0-run-metrics.sh` (`--from <json> [--out]` = validate+emit redacted markdown;
  `--validate <json>` = validate only; fail-closed; value-blind redaction with
  `[redacted:unsafe-metadata]`; env-independent — its own self-test proves `env -i` byte-identity).
  Zero callers anywhere in `bin/dmc` / run lifecycle / stop-gate; no ledger appender exists.
- Finding: the effort/course selectors are dormant-but-complete — `bin/lib/dmc-v0.5.2-effort-
  controller.sh` (deterministic rule set per `docs/EFFORT_POLICY.md`: docs-only→light … security→
  adversarial, escalations for protected surface/secret-live/files>25/prior findings/test failures)
  and `bin/lib/dmc-v0.5.3-dynamic-workflow-selector.sh` (emits {lane, required_gates, min_effort,
  verification_depth, reason}; fail-closed to the max lane on unknown facts). Both ADVISORY /
  READ-ONLY / "inert unless invoked" — and nothing in the loop invokes them. Frozen copies also
  exist under `.harness/evidence/` (the `EFFORT_POLICY.md` path pointer is valid).
- Finding: the frozen v0.5.0 emit is deterministically parseable — line format
  `# DMC Run Metrics — <rid>`, `- mode: <m> | effort: <e>`, `- wall_clock_sec: … | files_touched:
  …`, `- tests: selected=… run=… passed=… failed=…`, `- outcome: …`, `- efficiency_notes: …`
  (verified against the tool's own self-test fixtures at lines 115-133 and emit builder ~89-100).
- Finding: `bin/dmc` dispatch pattern = lib-path constants at top + verb cases; `run` / `verdict` /
  `stop-gate` verbs show the shape a new `metrics|effort|course` verb follows. `bin/dmc` and
  `bin/lib/*` are enforcement-class landmarks → the release gate raises its non-degrading FLAG on
  them (expected; same as v1.0.5's generator edit; NOT in DEFAULT_PROTECTED).
- Finding: selftest layering — `bin/dmc selftest --all` legacy aggregate is pinned **802/3/3
  EXACT** over the 49 frozen v0 tools (memory + MILESTONES); a NEW module (the recorder) is not a
  legacy v0 tool, so `--all`'s legacy count MUST stay 802/3/3; the basic `bin/dmc selftest` module
  list grows by the recorder's self-test (counts grow, 0 FAIL required) following the existing
  module-wiring pattern in `bin/dmc`.
- Finding: `.gitignore` already carries the local-only pattern family (`.harness/runs/current-*`,
  `.harness/evidence/dmc-run-*.md`, `.harness/mode`); `.harness/metrics/` does not exist yet and is
  not ignored — D4 adds the ignore line BEFORE the first ledger write so the tree never dirties.
- Finding: scope-guard exempts `.harness/evidence/` + `.harness/verification/` during armed runs
  (`.claude/hooks/scope-guard.sh:154-163`) — cycle records need no scope entries. The ledger dir
  `.harness/metrics/` is NOT exempt — but no armed-run write to it happens in this cycle: the AC
  probe writes a ledger row only AFTER the run suspends (post-suspend verification step), or under
  a temp `--root`-style path if the recorder supports an explicit `--ledger` override (design
  latitude: give `record` an optional `--ledger <path>` with the same fail-closed write-safety
  posture as the frozen tools' `--out`, so self-tests never touch the real ledger).
- Finding: `.harness/mode` = active; run pointer free after Cycle A suspends; branch
  `claude/dmc-fable-core`.

## Relevant Files

| Path | Reason | Allowed to Edit |
|---|---|---|
| `bin/lib/dmc-metrics-recorder.py` | NEW — recorder + rollup + self-test (D1/D2) | yes (new file) |
| `bin/dmc` | dispatch: `metrics`, `effort`, `course` verbs + selftest module wiring + usage text (D1/D3) | yes (enforcement-class landmark → gate FLAG expected) |
| `.gitignore` | add `.harness/metrics/` (D4) | yes (append one line) |
| `docs/DMC_OPERATOR_HANDBOOK.md` | one "Measuring a run" section (D4) | yes (additive) |
| `docs/MILESTONES.md` | ONE v1.1 entry (D4) | yes (append) |
| frozen tools `bin/lib/dmc-v0.5.*.sh`, hooks, schemas, installer, `AGENTS.md` generator | untouched | no |

## Out of Scope

- ANY change inside the frozen v0.5.x tools, the schema doc, hooks, stop/release gates, run
  lifecycle (`dmc-run-lifecycle.py` / `run.json` fields), installer, or AGENTS.md generator.
- Automatic recording (a hook/stop-gate that emits rows) — pilot-gated (memo §9 Q4 manual-vs-auto
  is an open human decision; this cycle ships the manual/opt-in path only).
- Any gate/verdict READING the ledger (trust-ledger-as-authority is memo risk #9 / non-goal).
- catch-rate / false-block tagging semantics (pilot-time human tagging).
- A lite install profile / host-repo posture change (memo §7-2 stays pilot work).
- Push / CI / main merge (human gate).

## Proposed Changes

- Change: NEW `bin/lib/dmc-metrics-recorder.py` — posture header mirroring the frozen family
  (advisory, offline, no env/секret/network read, executes only the frozen validator); verbs:
  - `record --from <record.json> [--ledger <path>]`: run frozen `--validate` (subprocess, path
    pinned to `bin/lib/dmc-v0.5.0-run-metrics.sh` relative to self); non-zero ⇒ REFUSE (propagate
    stderr, no append). On PASS run frozen `--from` emit, parse the deterministic redacted lines
    (`run_id`, `goal_type`, `efficiency_notes` redacted values; numerics/enums from the validated
    input), append ONE compact sorted-key JSON line to the ledger (default
    `.harness/metrics/ledger.jsonl`; mkdir -p the dir; open append-mode; REFUSE if ledger path is a
    symlink or not under the repo root unless `--ledger` passes the fail-closed write-safety check
    modeled on the frozen tools' `out_refused`).
  - `rollup [--ledger <path>]`: stdout-only deterministic aggregate (counts by outcome/effort/mode;
    sums of retry/human_gates/blockers/findings; tests sums; wall-clock sum+median; malformed lines
    counted + reported as `skipped_malformed`, never crash).
  - `--self-test`: fixtures in a mktemp dir — valid row appends + is valid JSON + JSONL grows by
    exactly 1; leak fixture (planted `ghp_`/`sk-`/`ya29.` shapes, reusing the frozen tool's own
    fixture shapes) ⇒ appended row carries `[redacted:unsafe-metadata]` and the raw secret shape
    NEVER appears in the ledger bytes; invalid record ⇒ REFUSED + ledger byte-identical
    (append-only proof); rollup over 3 fixture rows = exact expected aggregate; symlink ledger ⇒
    REFUSED; determinism (two identical runs ⇒ identical rollup bytes).
  Files: `bin/lib/dmc-metrics-recorder.py`.
- Change: `bin/dmc` — add `METRICSLIB="$HERE/lib/dmc-metrics-recorder.py"`; verb cases `metrics`
  (record/rollup/self-test), `effort` (exec `bin/lib/dmc-v0.5.2-effort-controller.sh "$@"`),
  `course` (exec `bin/lib/dmc-v0.5.3-dynamic-workflow-selector.sh "$@"`); usage text for the three;
  wire recorder self-test into the `selftest` module list following the existing module pattern.
  Files: `bin/dmc`.
- Change: `.gitignore` — append under the existing DMC local-only block:
  `# Do-Me-Coding run-metrics ledger (out-of-band, local-only by policy)` + `.harness/metrics/`.
  Files: `.gitignore`.
- Change: `docs/DMC_OPERATOR_HANDBOOK.md` — one additive section "Measuring a run (advisory,
  opt-in)": course-before / record-after / rollup-weekly, the three commands, the anti-fake note
  (no gate reads the ledger; outcome rows are the pilot's data product; §9 decisions pending).
  Files: `docs/DMC_OPERATOR_HANDBOOK.md`.
- Change: `docs/MILESTONES.md` — append `## v1.1 — measurement layer wiring (run-metrics recorder +
  effort/course reachability) — LOCAL (2026-07-09)` entry: what/why (memo §7-1), the chain
  (plan/critic/verifier/evidence paths), verification results, "push/CI/main-FF pending the human
  gate" line.
  Files: `docs/MILESTONES.md`.

## Acceptance Criteria

- Criterion: E2E record path works and is honest.
  Verification Method: a valid fixture record via `bin/dmc metrics record --from <f> --ledger
  <tmp>` ⇒ exit 0, ledger has exactly 1 valid-JSON line carrying ALL schema-required fields (the
  frozen validator's full REQ set — 20 keys; count-checked against the REQ array, not a literal);
  re-running appends (2 lines, first byte-identical). Invalid record (missing field / bad enum /
  inconsistent tests) ⇒ non-zero, ledger byte-identical.
- Criterion: redaction parity with the frozen tool.
  Verification Method: leak fixture ⇒ ledger line contains `[redacted:unsafe-metadata]`; `grep -c
  'ghp_\|sk-LEAK\|ya29\.' <ledger>` = 0.
- Criterion: rollup correct + deterministic.
  Verification Method: 3-row fixture ledger ⇒ rollup shows row_count=3 and the exact expected
  per-outcome/effort counts + sums; two runs byte-identical; a malformed 4th line ⇒
  `skipped_malformed: 1`, still exit 0.
- Criterion: effort/course reachable through the CLI, behavior unchanged.
  Verification Method: `bin/dmc effort --self-test` and `bin/dmc course --self-test` exit 0 with
  the frozen tools' own PASS output; `bin/dmc effort --risk-class docs-only` ⇒ recommends `light`
  (byte-comparable to invoking the lib script directly); frozen tool files byte-unchanged
  (`git diff --name-only` excludes them).
- Criterion: offline posture machine-proven (critic r1 recommendation — new enforcement-class file).
  Verification Method: structural self-audit mirroring the frozen family's AC6 pattern — grep the
  recorder's operative source (comments/docstrings excluded) for `os.environ` / `getenv` /
  `socket` / `urllib` / `requests` / `curl` / `wget` / `--live` ⇒ 0 matches; the only subprocess
  target is the pinned frozen validator path. Included as a self-test assertion so it holds on
  every future run, not just this build.
- Criterion: module self-test wired; suite floor holds.
  Verification Method: `bin/dmc metrics self-test` 0 FAIL; `bin/dmc selftest` 0 FAIL (module list
  now includes the recorder); legacy `bin/dmc selftest --all` = **802/3/3 EXACT** (recorder is not
  a legacy v0 tool; count unchanged); `bin/dmc linkcheck` clean; `bin/dmc mirror-check` PASS.
- Criterion: default-path record WORKS and the ledger stays out of git (anti-vacuous, critic r1).
  Verification Method: after the post-suspend real-path probe: (1) the `bin/dmc metrics record`
  invocation (default ledger path) exits 0; (2) `test -f .harness/metrics/ledger.jsonl` succeeds
  AND the file has ≥ 1 line (the write REALLY happened — a silently-refused default write must
  FAIL this AC, not pass it); (3) `git status --short` shows NO `.harness/metrics` entry (ignore
  line effective). All three must hold together.
- Criterion: full gate + scope + autonomy ceiling.
  Verification Method: `dmc gate release --full --run-id <run>` PASS (non-degrading FLAG on
  `bin/dmc`/new lib expected; no DMC_GATE_PROTECTED override); change-commit `git diff --name-only`
  == exactly the 5 in-scope files; records commit only plans/evidence/verification; both commits
  LOCAL on `claude/dmc-fable-core`; NO push.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Parsing the frozen emit drifts if the frozen format ever changes | low-medium | frozen tools are immutable by policy (never rewritten); recorder self-test pins the parse against the frozen tool's real output, so any drift fails loudly |
| Ledger append during an armed run muddies the postbash-diff snapshot | medium | real-path probe ordered post-suspend. (Rationale per critic r1: bash-radius would NOT deny the command anyway — `bin/dmc metrics record …` carries no write-idiom token and scope-guard adjudicates only Edit/Write tools; the ordering protects snapshot integrity, it is not denial-avoidance.) |
| New verbs read as enforcement growth | low | posture headers + handbook section say ADVISORY/opt-in; no hook, no gate, no automatic invocation; floor untouched |
| Secret smuggled via record file | low | frozen validator refuses secret-shaped numerics; free-form fields pass the frozen redactor; recorder never reads env/network; AC2 leak probe |
| `--all` legacy count drifts | low | recorder deliberately NOT registered as a legacy v0 tool; AC pins 802/3/3 EXACT |

## Assumptions

| Assumption | Confidence | How to Verify |
|---|---|---|
| Frozen v0.5.0 `--validate` mode exists and exits non-zero on invalid | high (usage line read) | probe at build start; if `--validate` differs, use `--from` to a rejected-emit and rely on exit code |
| A new bin/dmc verb does not disturb the m6/m7/m8/m9 suites | high | full suite run at build |
| Envelope covers this cycle (D-core = infrastructure only) | high | recorded this session; halt on critic challenge |

## Execution Tasks

- [ ] DMC-T001: implement `bin/lib/dmc-metrics-recorder.py` (record/rollup/self-test per Proposed
  Changes) + `bin/dmc` dispatch (`metrics`/`effort`/`course` + usage + selftest module wiring).
  Run: recorder self-test, `bin/dmc selftest`, `bin/dmc effort --self-test`, `bin/dmc course
  --self-test` → all 0 FAIL.
  Files: `bin/lib/dmc-metrics-recorder.py`, `bin/dmc`.
  Notes: Route: Opus 4.8, synchronous (Ring-0 CLI + new module; correctness-critical).
- [ ] DMC-T002: `.gitignore` line + `docs/DMC_OPERATOR_HANDBOOK.md` section + `docs/MILESTONES.md`
  v1.1 entry.
  Files: `.gitignore`, `docs/DMC_OPERATOR_HANDBOOK.md`, `docs/MILESTONES.md`.
  Notes: Route: Sonnet 5, synchronous; depends on T001 (records the verified facts).
- [ ] DMC-T003: independent verification (fresh verifier lane) → `.harness/verification/<run-id>.md`
  + build evidence `.harness/evidence/dmc-fable-core-d-build-20260709.md`; post-suspend real-path
  ledger probe + gitignore AC; full gate run; then change commit + records commit (LOCAL only).
  Files: (records paths — scope-exempt).
  Notes: Route: verifier = Opus 4.8 fresh lane (deep effort per EFFORT_POLICY — enforcement-class
  landmark touched); commits by orchestrator under the envelope's local-commit grant.

## Verification Commands

| Command | Reason | Required |
|---|---|---|
| `bin/dmc metrics record --from <ok.json> --ledger <tmp>` ×2; `--from <bad.json>`; `--from <leak.json>` | E2E append-only + refuse + redaction ACs | yes |
| `bin/dmc metrics rollup --ledger <fixture>` ×2 + malformed-line probe | rollup determinism + robustness | yes |
| `bin/dmc effort --self-test`; `bin/dmc course --self-test`; `bin/dmc effort --risk-class docs-only` | D3 reachability, frozen behavior unchanged | yes |
| `bin/dmc metrics self-test`; `bin/dmc selftest`; `bin/dmc selftest --all` (legacy 802/3/3 EXACT); m-suites; `mirror-check`; `linkcheck` | module + regression floor | yes |
| post-suspend real record probe + `git status --short` (no `.harness/metrics`) | gitignore effective | yes |
| `dmc gate release --full --run-id <run>` | full gate PASS (+expected FLAG) | yes |
| `git diff --name-only` per commit; `git log`; no push | scope + autonomy ceiling | yes |

## Approval Status

Status: APPROVED
Approver: wjlee (woojin20020@gmail.com)
Approved At: 2026-07-09 (this-session AskUserQuestion envelope "전체 비준": cycles A→D-core→C→B,
critic-APPROVE-conditional, LOCAL-commit autonomy ceiling on `claude/dmc-fable-core`, push/main a
separate human gate, 2 consecutive critic REJECTs → halt + report). Critic APPROVE is the mandatory
pre-build gate; this plan is not built unless a schema-valid APPROVE verdict binds this file's
sha256 via `bin/dmc verdict gate`.

Revisions: Rev 1 → critic r1 NEEDS_CLARIFICATION (0 blockers, 2 required AC-precision fixes;
`.harness/evidence/dmc-fable-core-d-critic-r1.json`): (i) field-count off-by-one — the frozen
validator REQ set has **20** keys, plan said 19 (fixed in Findings + AC1, now count-agnostic
against the REQ array); (ii) AC5 vacuous-pass — the ledger-out-of-git AC could pass with a
silently-broken default write (fixed: AC now also requires exit 0 + `test -f` + ≥1 line). Rev 2
also folds both recommendations: D1 default-ledger ALLOW vs `--ledger`-override `out_refused`
clarification, and a structural no-env/no-network self-audit AC (frozen-family AC6 mirror); plus
the post-suspend-ordering rationale (snapshot integrity, not denial-avoidance). Re-submitted for a
fresh critic pass (r2).
