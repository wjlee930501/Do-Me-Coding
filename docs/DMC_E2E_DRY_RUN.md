# DMC E2E Dry-Run Acceptance Suite (v0.3.9)

The **capstone** acceptance: a read-only suite that drives the **entire DMC rails loop** end-to-end in one **offline
dry-run** and proves it composes and stays safe — with **no live call, no commit/push, no real-repo mutation, no secret
content, and no false-green**.

Implemented by `.harness/evidence/dmc-v0.3.9-e2e-dry-run.sh`.

## The loop (stages)

| # | stage | tool | assertion |
|---|---|---|---|
| 0 | PRESENCE | (all 7) | every rails tool path exists + is readable (a missing tool is a hard FAIL, never a skip) |
| 1 | REGRESSION | v0.2.6/v0.2.8/v0.3.4–v0.3.8 | each tool's `--self-test` exits 0 (per-tool rc captured + AND'd) |
| 2 | INTAKE | v0.2.8 classifier | a docs-only task ⇒ dimensions + `stop_and_ask=false` |
| 3 | SELECT | v0.3.4 selector | 3 ranked candidates; `manual_import` rank 1; not `fail_closed` |
| 4 | MANIFEST | v0.3.5 manifest | **compose**: `proposed_provider_target` non-null, not `fail_closed`, `(type,provider)` == the selector's rank-1 candidate; `selected_adapter` resolves; 5 closure_criteria |
| 5 | REVIEW | v0.3.6 review-packet | 5 sections; `forbidden=none` on a clean changeset |
| 6 | CLOSURE | v0.3.7 closure-controller | the 5-condition table + the append-only candidate are emitted (asserted on **output**) |
| 7 | DELEGATION | v0.3.8 delegation-harness | **AUTONOMY-COMPLIANT**; push `DEFERRED` |
| 8 | SAFETY | — | real repo byte-unchanged; no live flag; no real-repo git write |

**ACCEPTED iff all stages PASS.** Advisory exit `0` (ACCEPTED) / `1` (NOT ACCEPTED).

## The contract

- **No false-green** (the gravest risk): a broken rail turns the suite red. REGRESSION captures + ANDs each tool's
  `--self-test` exit code (no `|| true`, no discarded-rc); the MANIFEST stage asserts the **positive** compose invariant
  (not the manifest's swallow-and-exit-0 process code); an explicit `STAGE_FAIL` counter drives the exit (**no `set -e`**).
  Two negative meta-fixtures prove the detection logic fails on a red input — a stub whose `--self-test` exits non-zero
  turns REGRESSION red, and a manifest JSON with `proposed_provider_target=null` fails the compose assertion.
- **No live call / no network**: the suite invokes only the tools' offline modes and emits no
  `--live`/`--allow-network`/`--allow-exec`; REGRESSION re-runs each tool's own no-live chokepoint self-test.
- **No commit / no push / no mutation**: all git writes are confined to a `$TMPDIR` temp repo; the real repo is
  byte-unchanged (HEAD + branch + `config --list` + `status --porcelain` pre==post, the POST snapshot after the `--out`
  write).
- **No secret content**: only synthetic non-secret fixtures; the composed tools' secret-path guards stay in force;
  metadata-only git. A structural audit (operative-source-only, AUDIT_BLOCK self-excluded) forbids any content-dumping git
  primitive, `%b`, credential-var read, real-repo git write, or `git push`.

## Wiring notes (why the one temp repo satisfies both closure and delegation)

The temp repo's `origin/main` is **behind HEAD** (present, not an ancestor of HEAD). The closure controller therefore
reports `pushed=NOT-MET` (so it exits 1 / not-E2E-DONE — which is why stage 6 asserts on the emitted **output**, not the
exit code), while the delegation harness reports `push=DEFERRED` ⇒ AUTONOMY-COMPLIANT. The two tools read the same git
state but invert the MET/DEFERRED mapping; one repo state passes both.

## Usage

```
e2e-dry-run.sh [--repo <dir>] [--out <file>]   # emits the acceptance report
e2e-dry-run.sh --self-test                       # full acceptance + the AC meta-fixtures
```

`--out` reuses the hardened guard (refuses protected/secret/symlink and any `..`-component target).
