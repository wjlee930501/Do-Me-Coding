# Verification Report

## Run ID

dmc-run-c78c84750bcc

## Plan

`.harness/plans/dmc-fable-core-d-runmetrics.md` (Rev 2; APPROVED). Binding independently re-verified:
plan sha256 `a315904385fa85d22d692d907b134c8096b6fe29143f8744250f7792e3b5035b` == run.json `plan_hash`
== scope.lock `plan_hash` == critic r2 `plan_hash`. Critic chain: r1 NEEDS_CLARIFICATION → r2 APPROVE
(both r1 fixes confirmed folded: field-count 19→20 count-agnostic; AC5 vacuous-pass closed).
scope.lock sha256 `91d152000f3da88fa9f7a9587c8c9331725947bd6064bbe9124912c83cb57d64` == run.json
`operative_snapshot.scope_lock_sha256`; `compiled_at_head 3e0caf1b…` == HEAD `3e0caf1` on
`claude/dmc-fable-core`. scope.lock files[] = exactly 5 with correct grants: `.gitignore`
(edit/ordinary), `bin/dmc` (edit/enforcement/landmark_authorized), `bin/lib/dmc-metrics-recorder.py`
(create/ordinary), `docs/DMC_OPERATOR_HANDBOOK.md` (edit/ordinary), `docs/MILESTONES.md`
(edit/release/landmark_authorized).

## Changed Files

- .gitignore: adds `.harness/metrics/` (D4)
- bin/dmc: metrics/effort/course verbs + usage + recorder wired into selftest module list (D1/D3)
- bin/lib/dmc-metrics-recorder.py: NEW recorder/rollup/self-test, untracked/create (D1/D2)
- docs/DMC_OPERATOR_HANDBOOK.md: "Measuring a run (advisory, opt-in)" section (D4)
- docs/MILESTONES.md: one v1.1 entry (D4)

(Crosscheck note: out-of-band dirty paths present during this cycle — the pre-existing
`.codex/config.toml` modification (in this run's snapshot.txt; diff is only the `model = "gpt-5.5"`
block) and untracked governance artifacts (`.harness/plans/dmc-fable-core-b-repointel.md`,
`.harness/plans/dmc-fable-core-c-asktier.md`, `.harness/evidence/dmc-fable-core-d-critic-r1.json`,
`.harness/evidence/dmc-fable-core-d-critic-r2.json`,
`.harness/evidence/dmc-fable-core-d-record-probe.json`) — are NOT this run's mutations and are set
aside via the Cycle-A `git stash push -u` procedure for the crosscheck run, restored immediately
after; independently verified untouched in Commands Run / Manual Checks.)

## Commands Run

| Command | Result | Reason | Output Summary |
|---|---|---|---|
| `dmc-scope-lock.py --validate <lock>` | PASS | lock schema | `VALID … conforms to dmc.scope-lock.v1` |
| `--adjudicate <lock> bin/dmc edit` / `… recorder.py create` | PASS | in-scope allow controls | both `ALLOW` rc0 |
| `--adjudicate <lock> dmc-v0.5.0-run-metrics.sh edit` | PASS | frozen tool out-of-scope | `REFUSE: PATH-NOT-IN-SCOPE` rc3 |
| `dmc bash-radius --scope-lock <lock> --cmd 'cp … dmc-v0.5.0-run-metrics.sh'` | PASS | armed deny probe | `deny` rc4 L1-OUT-OF-SCOPE |
| `dmc bash-radius … --cmd 'cp … bin/dmc'` | PASS | armed allow probe | `allow` rc0 L1-IN-SCOPE |
| `dmc metrics record --from <probe> --ledger <tmp>` ×2 | PASS | AC1 append-only | exit 0 ×2; 2 lines; `sort -u`=1 (byte-identical); rollup row_count 2 skipped 0 |
| `dmc metrics record --from run.json --ledger <tmp>` (invalid) | PASS | AC1 fail-closed refuse | frozen `INVALID`, exit 1, ledger 0 lines |
| `dmc-metrics-recorder.py --self-test` | PASS | module floor | 9 PASS / 0 FAIL |
| `dmc metrics rollup` (DEFAULT ledger) | PASS | AC7 live row | row_count 1, skipped 0, matches probe |
| grep operative source env/net tokens | PASS | AC5 offline posture | `os.environ`=0; socket/urllib/getenv/requests ONLY at lines 473/476 inside AUDIT_BLOCK (markers 472/479) |
| `dmc effort --self-test` / `dmc course --self-test` | PASS | AC4 reachability | 14/0 and 20/0 |
| `dmc effort --risk-class docs-only` vs direct lib | PASS | AC4 behavior unchanged | `diff` IDENTICAL; `light` |
| `dmc selftest` | PASS | suite floor | every module 0 FAIL + recorder 9/0 |
| `dmc mirror-check` | PASS | frozen mirror | `no stray dmc-v0.* copies beyond the pinned 55-file set` |
| `dmc linkcheck` | PASS | reference integrity | `clean — 24 file(s) scanned` |
| `dmc selftest --all` | FAIL | pinned legacy baseline | 801 PASS / 4 FAIL / 3 N/A vs pinned {49,802,3,3} — root-caused below, environmental |
| `git diff --name-only` / `--cached` | PASS | scope + staging discipline | 4 edits + pre-existing `.codex/config.toml`; new `.py` untracked; nothing staged |

### `selftest --all` exact numbers and root cause

`-- aggregate: tools=49 PASS=801 FAIL=4 N/A=3 timeouts=0 unparsed=0 --` vs pinned {49,802,3,3}.
Four tools show FAIL=1: v0.1.3 (44/1/0), v0.2.3 (19/1/0), v0.3.2 (7/1/0), v0.6.0 (17/1/0).
v0.1.3/v0.2.3/v0.3.2 MATCH `.harness/evidence/dmc-v1-m3-baseline.md` exactly (the 3 expected
pre-existing FAILs). v0.6.0 drifted 18/0 → 17/1 — the sole -1 PASS/+1 FAIL. Neither registered
gotcha applies (`.harness/mode`=active; v0.3.2 matches baseline). Root cause:
`dmc-v0.6.0-verify.sh` V15 reads the LIVE `git status --porcelain` (line 148) and FAILs on any
tracked modification outside `docs/*` / `.harness/plans|verification/*`. The dirty working tree —
including the PRE-EXISTING `.codex/config.toml` (alone sufficient to trip V15) plus this run's
in-scope `.gitignore`/`bin/dmc` — trips it. v0.6.0 is byte-unchanged; the drift is decoupled from
the D-core change; 802/3/3 holds on a clean/committed tree (CI authoritative). A THIRD,
previously-unregistered environmental sensitivity (working-tree diff coupling).

## Manual Checks

| Check | Result | Notes |
|---|---|---|
| AC1 E2E record honest | PASS | valid→exit0, 1 valid-JSON line, all 20 REQ fields; re-run→2 lines first byte-identical; invalid→exit1, ledger byte-identical |
| AC2 redaction parity | PASS | `[redacted:unsafe-metadata]` present; 0 raw ghp_/sk-/ya29. shapes; real default-ledger efficiency_notes redacted |
| AC3 rollup correct/deterministic/robust | PASS | exact 3-row aggregate; two runs byte-identical; malformed → `skipped_malformed: 1`, exit 0 |
| AC4 effort/course reachable, frozen behavior unchanged | PASS | 14/0 & 20/0 via dispatch; docs-only→light byte-identical to direct lib; frozen files byte-unchanged |
| AC5 offline posture machine-proven | PASS | self-audit assertion passes; independent grep: env/net tokens only inside AUDIT_BLOCK; sole subprocess = pinned frozen validator |
| AC6 module wired + suite floor | PARTIAL | recorder 9/0, `dmc selftest` all-0-FAIL, mirror-check PASS, linkcheck clean — but `--all` 801/4/3 (environmental, root-caused above; clean-tree confirmation required) |
| AC7 default-path record + gitignore | PASS | exit 0; ledger exists, 1 line, 20 fields, redacted-clean; `git status` no `.harness/metrics`; `check-ignore` confirms; rollup row_count 1; probe matches row |
| AC8 gate readiness + autonomy ceiling | PARTIAL/deferred | release gate deferred to orchestrator (staged set); DEFAULT_PROTECTED excludes all touched paths (no override); non-degrading FLAG expected; nothing staged; NO push; HEAD `3e0caf1` |

## Scope Review

Result: PASS

Notes: Tracked diff = 4 in-scope edits + pre-existing `.codex/config.toml`; 5th file untracked
(create). No frozen-tool/hook/schema/installer/AGENTS diff. Within scope.lock bounds (files≤5,
added≤700, deleted≤40). Scope compliance provable by construction (validated lock + live deny/allow
probes) — the standard the Cycle-A remediation established.

## Package / Env / Migration Review

Package files changed: no
Env files changed: no
Migration files changed: no

Notes: `.gitignore` adds an ignore pattern only; no `.env*` touched. Purely additive advisory
infrastructure; no state/runtime/dependency surface.

## Unresolved Risks

- `selftest --all` 801/4/3 vs pinned 802/3/3 — fully root-caused to `dmc-v0.6.0-verify.sh` V15
  working-tree coupling; NOT a defect, NOT change-caused (pre-existing `.codex/config.toml` alone
  trips it); frozen tool byte-unchanged. Action: confirm 802/3/3 on the clean/committed tree (the
  Cycle-A stash + change-commit path provides it; CI authoritative). Register as the THIRD
  environmental gotcha (mode-coupling, env-var leak, working-tree diff) — v1.1+ candidate:
  mode/tree-aware selftest expectation.
- Open `run start` arming defect (compensated manually this run; registered v1.1+). Note:
  `run.json.status=SUSPENDED` yet `current-run-id` still points at the run and keeps bash-radius
  armed — suspend does not disarm (consistent with Cycle-A observation).
- Push-gate disclosure advisory: strategic-memo codenames + cycle plan names become public on merge
  to main; the human push gate must consciously ratify disclosure.

## Final Status

PARTIAL

---

_Orchestrator disposition note (2026-07-09, appended at persist time): PARTIAL accepted as the
honest record of the dirty-tree `--all` reading. Per the verifier's prescribed action, the
orchestrator ran the clean-tree confirmation AFTER the change commit (out-of-band paths stashed):
result recorded in `.harness/evidence/dmc-fable-core-d-build-20260709.md`. 802/3/3 EXACT on the
clean tree ⇒ AC6 closes green and the cycle ships; any other reading ⇒ halt + investigate before
commit finalization._
