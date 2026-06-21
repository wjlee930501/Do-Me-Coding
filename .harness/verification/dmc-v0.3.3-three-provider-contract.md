# Verification Report

Review-Verdict: critic=PASS codex=ACCEPT

(critic=PASS via the round-1 3-critic panel + round-2 focused re-pass. codex=ACCEPT via the Codex Independent Release Audit
(thread 019eea04): REVISE→fix (C8/C10 `--mock`-only → per-provider INPUT_FLAG)→ACCEPT; safe-to-stage/commit yes, push no.)

## Run ID
dmc-v0.3.3-three-provider-contract

## Plan
`.harness/plans/dmc-v0.3.3-three-provider-contract.md` (Status: APPROVED, rev 3). Authorizes exactly the
`PROVIDER_CONTRACT.md` doc edit; the rest is additive (a new contract-test harness + this report).

## Changed Files
- `.claude/workers/providers/PROVIDER_CONTRACT.md` — **authorized protected edit** (truthful 3-provider update: title
  v0.2.4→v0.3.3; "Verified offline by" → dmc-v0.3.3; providers-under-contract += manual-import + profile note; C5b clause
  re-anchored + manual-import N/A; "Adding a new provider" → dmc-v0.3.3 + INPUT_FLAG/stage guidance). One intentional
  `dmc-v0.2.4-verify.sh` reference retained (the original glm/oauth suite).
- `.harness/evidence/dmc-v0.3.3-verify.sh` — unified contract suite (new).
- `.harness/verification/dmc-v0.3.3-three-provider-contract.md` — this report.
- `.harness/plans/dmc-v0.3.3-three-provider-contract.md` — the approved plan.

Unchanged (byte-identical): glm-api / oauth-cli / manual-import adapters, `provider-router.py`, `ROUTING.md`,
`WORKER_*_SCHEMA.md`, `.claude/hooks/*`, `dmc-glm-smoke`. The suite is read-only over the providers.

## What shipped
A unified PROVIDER_CONTRACT **C1–C11** suite over **all three** providers (glm-api, oauth-cli, manual-import) **+ the
router path**, with each provider's **INPUT_FLAG** threaded through every helper (so a `--mock` misfire cannot false-pass),
a per-provider **rejection-stage table (pinned)**, the manual_import **C4 variant** (no override-result read), a
**call-site-only C3** grep (no docstring false-fail), and a **no-pass-by-skip** universal-count check. The provider access
layer is now **validated by the same contract**, not merely "supported".

## Commands Run
| Command | Result |
|---|---|
| `bash .harness/evidence/dmc-v0.3.3-verify.sh` | **34 PASS / 0 FAIL / 2 N/A**, exit 0 |
| scoped `git diff --name-only` over the protected set | only `PROVIDER_CONTRACT.md` |

## Rejection-stage table (explicit — the "rejection-stage 차이 명시" deliverable)
| Provider | adversarial fixture → stage |
|---|---|
| glm-api | bad-scope → **validator** · bad-secret → **validator** |
| oauth-cli | bad-scope → **validator** · token-leak → **adapter** (token-guard) |
| manual-import | bad-scope · secret · mutation-attempt · extra-fields · empty → **all adapter** (validator backstop in-code, not the demonstrated stage) |

Pinned per fixture; a stage regression fails the suite. The C5a invariant ("no unsafe result ever ACCEPTED") holds across all.

## Verification matrix (34 PASS / 0 FAIL / 2 N/A)
- **Per provider (9 universal PASS each, no pass-by-skip):** C1 schema+provider_type+validator-ACCEPT (success accepted via
  INPUT_FLAG) · C2 proposal-only · C3 no-auto-apply (call-site) · C4 credential (variant per provider) · C5a pinned-stage
  rejection · C6 stdout/stderr · C7 determinism · C8 routed==direct · C11 context-guard fail-closed.
- **C5b** PASS for oauth-cli (exec_timeout); **N/A** for glm-api + manual-import (no exec — correct, not a skip).
- **Suite-wide:** C9 protected byte-unchanged (by the run); C10 no live calls (self-audit, offline stub only).

## Safety Posture
One authorized protected edit (PROVIDER_CONTRACT.md doc); adapters/router/ROUTING.md/schemas/hooks/dmc-glm-smoke
byte-unchanged. Mock/offline only; no live/network/credential/model-API call. manual-import has no live mode. No
`__pycache__` artifacts (`PYTHONDONTWRITEBYTECODE`).

## Final Status
**PASS** — 34/34 assertions green (2 legitimate C5b N/A); rejection-stage differences pinned + documented; only the
authorized PROVIDER_CONTRACT.md doc changed. **Codex Independent Release Audit: ACCEPT** (after the C8/C10 INPUT_FLAG
doc fix). Staged the approved set (gate-check carving exactly `PROVIDER_CONTRACT.md`), committed; **push deferred** to the human gate.
