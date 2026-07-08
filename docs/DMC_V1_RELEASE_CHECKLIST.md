# DMC v1.0 Release Checklist

Status: IMPLEMENTED (v1.0, M10). The human-facing mirror of what `dmc gate release --full`
composes, plus the human-gate (P17) items the composer does not and cannot check.

## What "consumed by the release gate" means (out-of-band binding)

The release-gate composer reads NO checklist file: `bin/lib/dmc-release-gate.py` has zero
references to any checklist doc, and `SUB_GATES` is frozen at nine names. So this checklist is
NOT parsed by the gate. Its "consumption" is out-of-band and two-fold:

1. This checklist mirrors the composer's nine sub-gates row-for-row (below), so a human or the
   release-auditor agent can read the emitted `release-readiness.json` against it.
2. Consumption is proven by the M10 milestone's own `dmc gate release --full --run-id <M10-RID>`
   PASS — the checklist is validated by the gate passing on a real armed run, not by the gate
   reading this file. Wiring the composer to read this file would grow `SUB_GATES` 9→10 and break
   the frozen 39/0 self-test contract; that is deliberately NOT done.

## The nine release-gate sub-gates (mirror of `bin/lib/dmc-release-gate.py:62-64`)

| # | Sub-gate | What it verifies | Verdict enum |
|---|---|---|---|
| 1 | `diff-scope` | Every since-arming changed path (worktree `git status --porcelain -uall` ∪ `git diff --name-only`, minus the arming `snapshot.txt`) is in the locked scope, adjudicated path-by-path; evidence/verification/run-dir exempt. | `PASS \| FAIL` |
| 2 | `gate-checks` | The advisory v0.2.6 G1–G6 runner over a temp allowlist built from the scope lock's `files[].path`, with the candidate STAGED. | `PASS \| FAIL` |
| 3 | `receipts` | Required check_ids (verify-plan.json `coverage[].resolved_by`, else acceptance.json) are receipt-covered, the ledger chain validates, every minted receipt passes the v0.6.2 validator. | `PASS \| FAIL \| MISSING` |
| 4 | `findings` | `findings.json` present ⇒ `findings-gate gate` (REFUSE ⇒ FAIL); absent ⇒ MISSING. | `PASS \| FAIL \| MISSING` |
| 5 | `goal` | `goal-ledger.json` present ⇒ `goal-ledger trace` (REFUSE ⇒ FAIL); absent ⇒ MISSING. | `PASS \| FAIL \| MISSING` |
| 6 | `decision` | `decision-record.json` present ⇒ `decision-trace answer` (the Q1–Q6 proof; REFUSE ⇒ FAIL); absent ⇒ MISSING. | `PASS \| FAIL \| MISSING` |
| 7 | `approvals` | `approvals.jsonl` present ⇒ `approvals --validate` + CF2 (every release/push/waiver `verification_ref` resolves to a safe, non-secret, EXISTING, `dmc validate verification`-VALID artifact); absent ⇒ MISSING. | `PASS \| FAIL \| MISSING` |
| 8 | `chain` | Worker-apply activity predicate: with activity, `dmc delegation check` PASS + every run-bound authorization `dmc worker apply-check` PASS; with no activity, PASS-with-note (accountability/provenance tier, not tamper-detection). | `PASS \| FAIL` |
| 9 | `landmark-flag` | New changes intersected with the run's non-ordinary landmarks — a REVIEW flag, never a failure; the paths were already scope-locked / landmark-authorized at compile. | `PASS \| FLAG` |

Overall verdict: `FAIL` if any sub-gate is FAIL; else `PARTIAL` if any is MISSING; else `PASS`.
A `FLAG` never degrades the verdict, and PARTIAL is never presented as PASS. Exit codes:
`0` PASS · `1` FAIL/PARTIAL · `2` usage · `3` structural REFUSE.

## Human release-gate items (P17 — human-recorded, NOT composer-checked)

The composer's `approvals` sub-gate is RUN-scoped; it does not read the master plan, MILESTONES,
or a milestone-closure record. These are the parallel, human-gated obligations:

- [ ] **Plan gate** — the milestone plan is APPROVED by the human (AskUserQuestion), critic chain recorded.
- [ ] **Scope gate** — a scope.lock is compiled and every applied path lies within it; landmark paths are `landmark_authorized` at compile.
- [ ] **Commit gate** — exactly the scope.lock files staged; `dmc gate release --full` run BEFORE committing (readiness is write-once; diff-scope is committed-diff-blind without `--base`).
- [ ] **Push gate** — CI green on the branch after the human authorizes the push (`gh run view <id> --json conclusion` = success).
- [ ] **MILESTONES closure** — the append-only `docs/MILESTONES.md` v1.0 closure entry is recorded (human-gated content).

## CF14 CI-tier baseline posture (v1.0)

- [ ] **CI green == the 13 substantive blocking M9-built checks pass on ubuntu-latest** (plus the
  2 porcelain sandwiches). The legacy `dmc selftest --all` replay is ADVISORY
  (`continue-on-error`) and count-divergent by design; the definitive 802/3/3 proof is the
  maintainer local / committed-replica run, a dev-environment-scoped artifact. Never pin runner
  counts. Root cause and the D1 disposition are documented in `docs/DMC_V1_HONEST_SCOPE.md` §5–§6.

## Residual acceptance

- [ ] **Disclosed residuals accepted** — the M6/M6.5/M7/M8/M9 residual register, the pre-M10
  audit DEFER-M10 backlog, and the CF14 / D1 postures are all recorded and human-accepted as
  non-blocking for v1.0. See `docs/DMC_V1_HONEST_SCOPE.md` for the full register.

## See also

- `docs/DMC_V1_ENFORCEMENT_MATRIX.md` — the per-harness and per-surface enforcement tiers.
- `docs/DMC_V1_HONEST_SCOPE.md` — the disclosed scope and residual register.
- `.harness/schemas/release-readiness.schema.md` — the `dmc.release-readiness.v1` contract.
