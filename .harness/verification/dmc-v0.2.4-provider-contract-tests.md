# Verification Report

## Run ID

dmc-v0.2.4-provider-contract-tests

## Plan

`.harness/plans/dmc-v0.2.4-provider-contract-tests.md` (APPROVED 2026-06-21, Approver: 대표님) — test/doc only, additive, mock + offline-stub, no live provider call.

## Changed Files

New:
- `.claude/workers/providers/PROVIDER_CONTRACT.md` — normative provider-adapter contract spec (dimensions C1–C11, C5 split into C5a/C5b), with rejection-stage and determinism caveats.
- `.harness/evidence/dmc-v0.2.4-verify.sh` — table-driven cross-provider contract harness (mock + offline stub; reuses existing fixtures, no new ones).
- `.harness/verification/dmc-v0.2.4-provider-contract-tests.md` — this report.

Unchanged (verified byte-identical): both adapters (`glm-api`, `oauth-cli`), `provider-router.py`, `ROUTING.md`, all `.claude/hooks/*`, `WORKER_*_SCHEMA.md`, `dmc-glm-smoke`. No new fixtures.

## Commands Run

| Command | Result |
|---|---|
| `bash .harness/evidence/dmc-v0.2.4-verify.sh` | **23 PASS / 0 FAIL / 1 N/A** (mock + offline stub; no external provider, no network, no real credential, no `.env*`) |

Note: two transient FAILs during development were **harness self-audit bugs in C10** (the audit grepped its own source; the grep-pattern/message strings matched themselves, and a `\`-continued line split the stub binding from `--live`). Fixed by joining the C5b call to one line and constructing the C10 needles by concatenation + rewording messages. Never an adapter or contract violation.

## Contract Results — per provider

| Dim | glm-api | oauth-cli |
|---|---|---|
| C1 schema conformance + provider_type match | PASS (`api_key`/`glm-api`, ACCEPT) | PASS (`oauth_cli`/`oauth-cli`, ACCEPT) |
| C2 proposal-only (`no_direct_mutation=true`) | PASS | PASS |
| C3 no auto-apply / no `git apply` / no `shell=True` | PASS | PASS |
| C4 no credential/token leakage; secret input rejected; `credential_exposure=none` | PASS | PASS |
| C5a rejection-shape (no unsafe result ACCEPTED) | PASS (validator REJECT) | PASS (adapter redact-reject + validator REJECT) |
| C5b timeout (capability-scoped) | **N/A (mock)** — live-network; covered by `dmc-glm-smoke` | PASS (`fake-cli.py timeout` → killed + fail-closed) |
| C6 stdout/stderr handling; no secret on either stream | PASS | PASS |
| C7 mock-mode determinism (byte-identical `--out`) | PASS | PASS |
| C8 routing compatibility (`--print-dispatch` + routed `--out` == direct `--out`, mock) | PASS | PASS |
| C11 context-guard fail-closed on secret-bearing task | PASS | PASS |

Suite-wide:
- **C9 protected-file non-mutation** — PASS (`git diff` empty over adapters/router/hooks/schemas/`dmc-glm-smoke`).
- **C10 no live provider calls** — PASS (self-audit: the only live-mode invocation targets the offline stub; no real GLM key referenced; glm-api never invoked in live mode).

## Key contract findings (honest asymmetries)

- **Rejection stage differs legitimately and both conform (C4/C5a):** glm-api's bad-scope/bad-secret fixtures are
  caught at the **validator** (adapter exit 0, result written, `worker-result-check.py` REJECT); oauth-cli's token-leak
  is caught at the **adapter** (token-guard, non-zero exit, no result). The contract asserts *"no unsafe result
  ACCEPTED,"* not a uniform stage — both pass.
- **C5b is capability-scoped, not universal:** glm-api has no process-level timeout in mock (its timeout is a
  live-network concern, exercised by `dmc-glm-smoke`), so C5b is **N/A** for it — recorded as N/A, NOT a failure.

## Scope Review

Result: PASS. Edits confined to the one approved scoped file (`PROVIDER_CONTRACT.md`) plus harness/report under
`.harness/`. No adapter/router/schema/hook/validator/guard/`dmc-glm-smoke` change. No new fixtures.

## Package / Env / Migration Review

Package files changed: no. Env files changed: no — the suite reads only committed fixtures + outputs; no credential
introduced or read. Migration files changed: no.

## Safety Posture

- Mock + offline-stub only; no live provider call, no network, no real credential, no `.env*` read.
- Reused existing fixtures only (no new committed fixtures).
- Proposal-only preserved; the harness applies nothing, runs no `git apply`, mutates no protected file (C9).
- A contract violation would be reported as a finding; none found — all providers conform.

## Final Status

**PASS** — 23/23 applicable contract checks pass across glm-api and oauth-cli (C5b correctly N/A for glm-api in mock);
protected files byte-unchanged; no live provider call. Stopped before commit per instruction.
