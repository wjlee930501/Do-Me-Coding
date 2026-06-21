# Verification Report

## Run ID
dmc-v0.2.9-effort-provider-policy

## Plan
`.harness/plans/dmc-v0.2.9-effort-provider-policy.md` (APPROVED 2026-06-21, delegated semi-autonomous mode, after a critic panel PASS) — policy doc + read-only structure-check, additive, no provider-routing change.

## What a PASS means (and does NOT mean)
Passing `dmc-v0.2.9-effort-provider-policy.sh` proves the policy is **documented, structurally complete, own-words
authored, and free of secrets/leaked prose**, and that no protected/routing surface changed. It does **NOT** prove any
agent will comply — the policy is **guidance, not enforcement**; compliance is unprovable by a structure-check;
enforcement (policy-driven auto-routing) is a separate approved future milestone.

## Changed Files
New (3 tracked deliverables):
- `docs/DMC_EFFORT_PROVIDER_POLICY.md` — the effort/model/provider policy (guidance, not enforcement).
- `.harness/evidence/dmc-v0.2.9-effort-provider-policy.sh` — read-only structure-check.
- `.harness/verification/dmc-v0.2.9-effort-provider-policy.md` — this report.

Unchanged (byte-identical): `provider-router.py`, `ROUTING.md`, adapters, `WORKER_*_SCHEMA.md`, `.claude/hooks/*`, `dmc-glm-smoke`.

## Critic process
Adversarial critic panel (6 dimensions): **round 1 = 5 PASS / 1 REVISE**. The one REVISE (verification-sufficiency) was a
precise internal-consistency wording fix — "no code execution" vs the check's legitimate `python3 -c` static scan;
clarified the scope (no product/router/adapter exec, no live/network/model-API; benign `grep`/`git`/`python3 -c`
permitted) + added the H6 meta-guard. Faster convergence than v0.2.8 because the plan pre-empted the known patterns
(contract-not-enforcement, anti-token-max, read-only, own-words).

## Commands Run
| Command | Result |
|---|---|
| `bash dmc-v0.2.9-effort-provider-policy.sh` | **15 PASS / 0 FAIL**, exit 0 |

(One transient FAIL during build was a doc line-wrap — "advisory"/"audit input" split across lines so a `grep -F`
single-line match missed; fixed by matching a single-line phrase. The script also now exits non-zero on FAIL.)

## Structure-check results
| Check | Result |
|---|---|
| P1 nature: guidance-not-enforcement + presence≠compliance + enforcement=future | PASS |
| P2 fast-model criteria · P3 Opus criteria | PASS |
| P4 Codex audit (always before stage/commit/push; advisory input to human Release Gate) | PASS |
| P5 separate-critic (always; panel) · P6 escalate-to-human (hard gates + fail-closed) | PASS |
| P7 when-to-STOP (E2E done / converged / blocked; anti-token-max) | PASS |
| P8 task-class→workflow mapping (7 classes) · P9 ultracode (depth not scope) | PASS |
| H1 own-words authorship | PASS |
| H2 no leaked/proprietary prose (zero stored; generic denylist, concatenation-built) | PASS |
| H3 no secret/token shapes (separate scan) | PASS |
| H4 protected files byte-unchanged (router/adapters/hooks/schemas/smoke-runner) | PASS |
| H5 read-only self-audit (no dangerous exec/live/network/.env-open; benign python3/grep/git permitted) | PASS |
| H6 meta-guard: self-audit + contamination denylists non-empty + concatenation-built | PASS |

## Safety Posture
Policy/doc + read-only structure-check; the policy changes no provider-routing behavior/code; the check executes no
product/router/adapter code, makes no model-API/network/live call, reads no `.env*`/credentials, and writes nothing.
Guidance not enforcement; presence ≠ compliance. Protected files byte-unchanged. No leaked text. The auto-logged
`.harness/evidence/dmc-v0.2.9-effort-provider-policy.md` stays untracked/excluded.

## Final Status
**PASS** — structure-check 15/15; the policy is documented, complete, own-words, and clean; provider-routing surface
byte-unchanged; no live call / no credential read. Stopped before commit pending Codex audit, then staging review, then
commit; **push deferred** to the human's batch review.
