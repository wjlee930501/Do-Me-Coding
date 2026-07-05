# DMC v1.0 Runtime Upgrade — M3 Baseline Pin (DMC-T008a)

- run_id: `dmc-v1-m3-20260706`
- date: 2026-07-06
- branch: `claude/dmc-v1-runtime-upgrade-c5uch1`
- HEAD commit: `cf3072088b860e1bd1d59cf0d2dbc4813009a278`
- purpose: pin the exact self-test baseline of every legacy DMC v0.x tool **before** any
  copy-routing (DMC-T008b) happens. Per plan §M3 (DMC-T008 first sub-step): "the aggregate
  must equal that count with 0 FAIL" is DMC-T008b's target against **this** pinned baseline —
  see Anomalies below for the 3 pre-existing FAILs this baseline actually contains.
- scope of this file: read-only. No `.harness/evidence/dmc-v0.*` tool was edited. No other
  file in the repo was created, edited, or deleted. No git add/commit/push. No network access.

## Methodology

- Enumerated every `.harness/evidence/dmc-v0.*.sh` script matching the glob (49 total, verified
  via `ls .harness/evidence/dmc-v0.*.sh | wc -l`).
- Determined each tool's self-test invocation by reading its usage comment / argument-parsing
  `case` statement (no blind flag guessing):
  - 12 tools take **no flag** — the script's usage comment says `run: bash <script>` and the
    whole script body is the self-test (no `case "$1"` dispatch at all): v0.1.3, v0.2, v0.2.1,
    v0.2.1.1, v0.2.2, v0.2.3, v0.2.4, v0.2.5, v0.2.9, v0.3.1, v0.3.2, v0.3.3.
  - 37 tools support `--self-test` as a dispatched case arm (confirmed via
    `grep -o '"\?--self-test"\?)'` matching a real case-statement entry in all 37, not just a
    comment).
- The 5 `dmc-v0.6.*.py` cores (`dmc-v0.6.1.0-trace-linkage.py`, `dmc-v0.6.2-evidence-receipt.py`,
  `dmc-v0.6.3-findings-gate.py`, `dmc-v0.6.4-goal-ledger.py`, `dmc-v0.6.5-decision-trace.py`)
  were **not** invoked directly. Their owning `.sh` wrapper's `--self-test` arm internally runs
  `python3 "$PYCORE" selftest`, so running the wrapper self-test exercises the Python core too
  (verified in each wrapper's source, e.g. `dmc-v0.6.2-evidence-receipt.sh:61`).
- Each command was run once via `bash <script> [--self-test]` from the repo root, through a
  Python subprocess wrapper (`timeout` is not installed on this host) with a 90s timeout. No
  tool timed out; no tool hung.
- PASS/FAIL/N/A were parsed from each tool's own printed summary line (format varies by tool
  generation: `SUMMARY: PASS=x FAIL=y`, `self-test: PASS=x FAIL=y`, `self-test: x PASS / y FAIL`,
  `RESULT: x PASS / y FAIL`) — not inferred from exit code, since two of the anomaly tools below
  report FAIL in their summary while still exiting 0.

## Per-tool results

| # | Tool | Invocation | PASS | FAIL | N/A | Exit | Elapsed(s) |
|---|---|---|---|---|---|---|---|
| 1 | `dmc-v0.1.3-verify.sh` | `bash .harness/evidence/dmc-v0.1.3-verify.sh` | 44 | 1 | 0 | 0 | 2.76 |
| 2 | `dmc-v0.2-verify.sh` | `bash .harness/evidence/dmc-v0.2-verify.sh` | 23 | 0 | 0 | 0 | 1.06 |
| 3 | `dmc-v0.2.1-verify.sh` | `bash .harness/evidence/dmc-v0.2.1-verify.sh` | 19 | 0 | 0 | 0 | 0.98 |
| 4 | `dmc-v0.2.1.1-verify.sh` | `bash .harness/evidence/dmc-v0.2.1.1-verify.sh` | 15 | 0 | 0 | 0 | 1.82 |
| 5 | `dmc-v0.2.2-verify.sh` | `bash .harness/evidence/dmc-v0.2.2-verify.sh` | 28 | 0 | 0 | 0 | 5.43 |
| 6 | `dmc-v0.2.3-verify.sh` | `bash .harness/evidence/dmc-v0.2.3-verify.sh` | 19 | 1 | 0 | 0 | 1.51 |
| 7 | `dmc-v0.2.4-verify.sh` | `bash .harness/evidence/dmc-v0.2.4-verify.sh` | 23 | 0 | 1 | 0 | 5.07 |
| 8 | `dmc-v0.2.5-verify.sh` | `bash .harness/evidence/dmc-v0.2.5-verify.sh` | 14 | 0 | 0 | 0 | 0.18 |
| 9 | `dmc-v0.2.9-effort-provider-policy.sh` | `bash .harness/evidence/dmc-v0.2.9-effort-provider-policy.sh` | 15 | 0 | 0 | 0 | 0.10 |
| 10 | `dmc-v0.3.1-verify.sh` | `bash .harness/evidence/dmc-v0.3.1-verify.sh` | 17 | 0 | 0 | 0 | 1.55 |
| 11 | `dmc-v0.3.2-verify.sh` | `bash .harness/evidence/dmc-v0.3.2-verify.sh` | 7 | 1 | 0 | 1 | 1.27 |
| 12 | `dmc-v0.3.3-verify.sh` | `bash .harness/evidence/dmc-v0.3.3-verify.sh` | 34 | 0 | 2 | 0 | 6.44 |
| 13 | `dmc-v0.2.6-gate-check-runner.sh` | `bash .harness/evidence/dmc-v0.2.6-gate-check-runner.sh --self-test` | 19 | 0 | 0 | 0 | 2.75 |
| 14 | `dmc-v0.2.7-run-manifest.sh` | `bash .harness/evidence/dmc-v0.2.7-run-manifest.sh --self-test` | 8 | 0 | 0 | 0 | 0.42 |
| 15 | `dmc-v0.2.8-task-intake-classifier.sh` | `bash .harness/evidence/dmc-v0.2.8-task-intake-classifier.sh --self-test` | 33 | 0 | 0 | 0 | 1.13 |
| 16 | `dmc-v0.3.0-e2e-completion.sh` | `bash .harness/evidence/dmc-v0.3.0-e2e-completion.sh --self-test` | 16 | 0 | 0 | 0 | 1.86 |
| 17 | `dmc-v0.3.4-provider-selector.sh` | `bash .harness/evidence/dmc-v0.3.4-provider-selector.sh --self-test` | 14 | 0 | 0 | 0 | 3.28 |
| 18 | `dmc-v0.3.5-execution-manifest.sh` | `bash .harness/evidence/dmc-v0.3.5-execution-manifest.sh --self-test` | 17 | 0 | 0 | 0 | 5.88 |
| 19 | `dmc-v0.3.6-review-packet.sh` | `bash .harness/evidence/dmc-v0.3.6-review-packet.sh --self-test` | 10 | 0 | 0 | 0 | 0.73 |
| 20 | `dmc-v0.3.7-closure-controller.sh` | `bash .harness/evidence/dmc-v0.3.7-closure-controller.sh --self-test` | 12 | 0 | 0 | 0 | 0.70 |
| 21 | `dmc-v0.3.8-delegation-harness.sh` | `bash .harness/evidence/dmc-v0.3.8-delegation-harness.sh --self-test` | 8 | 0 | 0 | 0 | 0.74 |
| 22 | `dmc-v0.3.9-e2e-dry-run.sh` | `bash .harness/evidence/dmc-v0.3.9-e2e-dry-run.sh --self-test` | 5 | 0 | 0 | 0 | 17.73 |
| 23 | `dmc-v0.4.0-autonomy-charter.sh` | `bash .harness/evidence/dmc-v0.4.0-autonomy-charter.sh --self-test` | 8 | 0 | 0 | 0 | 0.08 |
| 24 | `dmc-v0.4.1-goal-plan-compiler.sh` | `bash .harness/evidence/dmc-v0.4.1-goal-plan-compiler.sh --self-test` | 7 | 0 | 0 | 0 | 1.30 |
| 25 | `dmc-v0.4.2-branch-isolation-guard.sh` | `bash .harness/evidence/dmc-v0.4.2-branch-isolation-guard.sh --self-test` | 8 | 0 | 0 | 0 | 0.47 |
| 26 | `dmc-v0.4.3-scope-overeager-guard.sh` | `bash .harness/evidence/dmc-v0.4.3-scope-overeager-guard.sh --self-test` | 14 | 0 | 0 | 0 | 1.09 |
| 27 | `dmc-v0.4.4-evidence-harness.sh` | `bash .harness/evidence/dmc-v0.4.4-evidence-harness.sh --self-test` | 9 | 0 | 0 | 0 | 0.33 |
| 28 | `dmc-v0.4.5-secret-network-live-guard.sh` | `bash .harness/evidence/dmc-v0.4.5-secret-network-live-guard.sh --self-test` | 21 | 0 | 0 | 0 | 0.23 |
| 29 | `dmc-v0.4.6-reviewer-loop.sh` | `bash .harness/evidence/dmc-v0.4.6-reviewer-loop.sh --self-test` | 8 | 0 | 0 | 0 | 0.23 |
| 30 | `dmc-v0.4.7-context-audit.sh` | `bash .harness/evidence/dmc-v0.4.7-context-audit.sh --self-test` | 7 | 0 | 0 | 0 | 0.07 |
| 31 | `dmc-v0.4.8-interop-doc-check.sh` | `bash .harness/evidence/dmc-v0.4.8-interop-doc-check.sh --self-test` | 6 | 0 | 0 | 0 | 0.06 |
| 32 | `dmc-v0.4.9-autonomous-dry-run.sh` | `bash .harness/evidence/dmc-v0.4.9-autonomous-dry-run.sh --self-test` | 9 | 0 | 0 | 0 | 4.66 |
| 33 | `dmc-v0.5.0-run-metrics.sh` | `bash .harness/evidence/dmc-v0.5.0-run-metrics.sh --self-test` | 12 | 0 | 0 | 0 | 0.77 |
| 34 | `dmc-v0.5.1-context-budgeter.sh` | `bash .harness/evidence/dmc-v0.5.1-context-budgeter.sh --self-test` | 10 | 0 | 0 | 0 | 0.51 |
| 35 | `dmc-v0.5.2-effort-controller.sh` | `bash .harness/evidence/dmc-v0.5.2-effort-controller.sh --self-test` | 14 | 0 | 0 | 0 | 1.70 |
| 36 | `dmc-v0.5.3-dynamic-workflow-selector.sh` | `bash .harness/evidence/dmc-v0.5.3-dynamic-workflow-selector.sh --self-test` | 20 | 0 | 0 | 0 | 1.54 |
| 37 | `dmc-v0.5.4-workflow-state-machine.sh` | `bash .harness/evidence/dmc-v0.5.4-workflow-state-machine.sh --self-test` | 22 | 0 | 0 | 0 | 1.18 |
| 38 | `dmc-v0.5.5-verification-planner.sh` | `bash .harness/evidence/dmc-v0.5.5-verification-planner.sh --self-test` | 22 | 0 | 0 | 0 | 1.53 |
| 39 | `dmc-v0.5.6-review-packet-v2.sh` | `bash .harness/evidence/dmc-v0.5.6-review-packet-v2.sh --self-test` | 17 | 0 | 0 | 0 | 1.41 |
| 40 | `dmc-v0.5.7-resume-recovery.sh` | `bash .harness/evidence/dmc-v0.5.7-resume-recovery.sh --self-test` | 18 | 0 | 0 | 0 | 1.10 |
| 41 | `dmc-v0.5.8-dynamic-delegation.sh` | `bash .harness/evidence/dmc-v0.5.8-dynamic-delegation.sh --self-test` | 19 | 0 | 0 | 0 | 0.43 |
| 42 | `dmc-v0.5.9-dynamic-workflow-acceptance.sh` | `bash .harness/evidence/dmc-v0.5.9-dynamic-workflow-acceptance.sh --self-test` | 15 | 0 | 0 | 0 | 8.24 |
| 43 | `dmc-v0.6.0-verify.sh` | `bash .harness/evidence/dmc-v0.6.0-verify.sh --self-test` | 18 | 0 | 0 | 0 | 0.17 |
| 44 | `dmc-v0.6.1-capability-router.sh` (+ `.py` core) | `bash .harness/evidence/dmc-v0.6.1-capability-router.sh --self-test` | 7 | 0 | 0 | 0 | 0.13 |
| 45 | `dmc-v0.6.1.0-trace-linkage.sh` (+ `.py` core) | `bash .harness/evidence/dmc-v0.6.1.0-trace-linkage.sh --self-test` | 29 | 0 | 0 | 0 | 0.09 |
| 46 | `dmc-v0.6.2-evidence-receipt.sh` (+ `.py` core) | `bash .harness/evidence/dmc-v0.6.2-evidence-receipt.sh --self-test` | 18 | 0 | 0 | 0 | 0.13 |
| 47 | `dmc-v0.6.3-findings-gate.sh` (+ `.py` core) | `bash .harness/evidence/dmc-v0.6.3-findings-gate.sh --self-test` | 25 | 0 | 0 | 0 | 0.23 |
| 48 | `dmc-v0.6.4-goal-ledger.sh` (+ `.py` core) | `bash .harness/evidence/dmc-v0.6.4-goal-ledger.sh --self-test` | 27 | 0 | 0 | 0 | 0.41 |
| 49 | `dmc-v0.6.5-decision-trace.sh` (+ `.py` core) | `bash .harness/evidence/dmc-v0.6.5-decision-trace.sh --self-test` | 12 | 0 | 0 | 0 | 0.28 |

## Aggregate (pinned baseline)

```
tools=49  PASS=802  FAIL=3  N/A=3  timeouts=0  hangs=0
```

This aggregate — **49 tools, 802 PASS, 3 FAIL, 3 N/A** — is the exact pinned baseline that
`bin/dmc selftest --all` must reproduce byte-for-byte after DMC-T008b's copy-routing, per plan
§M3 acceptance ("aggregate == pinned baseline, 0 FAIL, in both trees"). See Anomalies: this
baseline is **not** itself 0-FAIL, so DMC-T008b's "0 FAIL" acceptance target and this baseline's
"3 pre-existing FAIL" reality need reconciliation by whoever owns DMC-T008b/M3 sign-off — this
task's scope is pin-and-report only, not remediation.

## Anomalies

No tool lacked a self-test invocation, timed out, or hung. All 49 tools ran to completion on
the first attempt. Three tools report pre-existing FAIL assertions in their own summary output
(none introduced or caused by this baseline-pin run — these are the tool's existing, as-shipped
self-test result):

1. **`dmc-v0.1.3-verify.sh`** — `FAIL GLM/worker code found` (1 of 45 assertions). Exit code 0
   despite the reported FAIL (the script's own exit-code logic does not gate on this assertion).
2. **`dmc-v0.2.3-verify.sh`** — `FAIL V5 mock (1)` under the "V5: mock / missing
   provider_target -> refuse" check (1 of 20 assertions). Exit code 0 despite the reported FAIL.
3. **`dmc-v0.3.2-verify.sh`** — `FAIL AC5 (nochange='' changed='')` under "AC5 protected surface
   scoped (only router + ROUTING.md changed; rest byte-unchanged)" (1 of 8 assertions). This one
   also exits 1 (consistent with its FAIL).

Additionally, two tools report **N/A** (not-applicable, not failing) assertions that are
intentional per their own comments, not anomalies:
- `dmc-v0.2.4-verify.sh`: 1 N/A — `C5b timeout N/A (mock) for glm-api — live-network; covered by
  dmc-glm-smoke`.
- `dmc-v0.3.3-verify.sh`: 2 N/A — `C5b glm-api N/A (no exec_timeout capability)` and
  `C5b manual-import N/A (no exec_timeout capability)`.

No tool's self-test flag was guessed; every invocation above was confirmed by reading the
target script's usage comment and/or `case` statement before running it. No `.harness/evidence/
dmc-v0.*` file, and no other repo file, was mutated by any of these 49 runs (see git-status
proof below). No `__pycache__` directory was found anywhere in the repo after the runs (checked
via `find . -type d -name __pycache__`), so none required deletion.

## Repo-cleanliness proof

`git status --porcelain` captured before running any tool (start of this task) and again after
all 49 runs completed (end of this task), from repo root:

**Before:**
```
 M .harness/plans/dmc-v1-runtime-upgrade.md
```

**After:**
```
 M .harness/plans/dmc-v1-runtime-upgrade.md
```

Byte-identical. The one modified entry (`.harness/plans/dmc-v1-runtime-upgrade.md`) pre-dates
this task (already modified when this task began, owned by the concurrent DMC-T007 task per the
shared task list) and was not touched by this baseline-pin work. No new, deleted, or additionally
modified paths appeared as a result of running any of the 49 self-tests.
