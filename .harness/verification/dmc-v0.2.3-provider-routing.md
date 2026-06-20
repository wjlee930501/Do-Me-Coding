# Verification Report

## Run ID

dmc-v0.2.3-provider-routing

## Plan

`.harness/plans/dmc-v0.2.3-provider-routing.md` (APPROVED 2026-06-21, Approver: 대표님) — additive router, mock-first, no live provider call.

## Changed Files

New:
- `.claude/workers/providers/provider-router.py` — thin, table-driven router: task-only selection (`provider_target.{type,provider}`) → static REGISTRY → adapter resolved absolute under the providers dir → `subprocess.run([...], shell=False)` dispatch; env passthrough (R1); argv hygiene (O4); per-entry `live_flag` with mismatch refusal; `--print-dispatch` dry-run.
- `.claude/workers/providers/ROUTING.md` — routing table + task-only selection contract + dispatch/env/stream/timeout/cross-flag policy.
- `.harness/evidence/dmc-v0.2.3-verify.sh` — mock + local-stub verification harness.
- `.harness/verification/dmc-v0.2.3-provider-routing.md` — this report.

Unchanged (verified byte-identical): both adapters (`glm-api/glm-api-adapter.py`, `oauth-cli/oauth-cli-adapter.py`), all `.claude/hooks/*`, `WORKER_*_SCHEMA.md`, `dmc-glm-smoke`.

## Commands Run

| Command | Result |
|---|---|
| `python3 -m py_compile provider-router.py` | PASS |
| `bash .harness/evidence/dmc-v0.2.3-verify.sh` | **20 PASS / 0 FAIL** (mock + offline-stub; no external provider, no network, no real credential) |

## Verification Matrix — Evidence

| # | Scenario | Result |
|---|---|---|
| V1 | route `api_key/glm-api` `--mock` → glm adapter | PASS (ACCEPT) |
| V2 | route `oauth_cli/oauth-cli` `--mock` → oauth adapter | PASS (ACCEPT) |
| V3 | routed `--out` JSON byte-identical to direct adapter `--out` (mock) | PASS (`cmp` identical) |
| V4 | unknown `(type,provider)` | PASS — refuse, no adapter exec |
| V5 | `mock` type / missing `provider_target` | PASS — refuse (both) |
| V6 | empty provider, single-adapter type | PASS — deterministic route to glm-api |
| V7 | route **selection** independent of env (bogus `GLM_API_KEY`/`DMC_OAUTHCLI_BIN`/`FOO`) | PASS — selection unchanged |
| V8 | live-flag translation (print-dispatch, no live) | PASS — glm-api forwards `--allow-network` only; oauth-cli `--allow-exec` only; cross-flag refused before dispatch |
| V8b | adapter-layer cross-flag backstop | PASS — glm-api argparse rejects `--allow-exec` |
| V14 | env passthrough router→adapter (offline stub) | PASS — parent `DMC_FAKECLI_MODE=nonzero-exit` reached child → fail-closed (proves not stripped); success-mode positive control → ACCEPT |
| V10/O4 | argv hygiene; no `shell=True`/`git apply` | PASS — no task-derived string on child argv; none found |
| V11 | no repo mutation during routed run | PASS — adapters/hooks clean |
| V15/O2 | router persists no raw stream/result file | PASS — router has no `open(...,'w')` |
| V12 | protected files byte-unchanged | PASS — `git diff --name-only` empty over adapters/hooks/schemas/smoke-runner |

Notes:
- The "empty provider, >1 adapter → refuse" branch is unreachable with the current registry (each type has exactly one
  adapter); it is covered by code review of `select_entry()`. V6 exercises the single-adapter resolution path; V4/V5
  exercise the refuse paths.
- V14 uses the committed v0.2.2 fake-CLI stub via `DMC_OAUTHCLI_BIN` — a deterministic local script, NOT a provider:
  no external provider, no real OAuth credential, no network.

## Scope Review

Result: PASS. Edits confined to the two approved new files (`provider-router.py`, `ROUTING.md`) plus harness/report
under `.harness/`. No adapter/schema/hook/validator/guard/`dmc-glm-smoke` change.

## Package / Env / Migration Review

Package files changed: no. Env files changed: no — the router reads env for nothing and introduces no credential.
Migration files changed: no.

## Safety Posture

- Selection is task-only (V7); env passed through unchanged so adapters' own gated live paths still work (V14); router
  reads/logs no env values.
- Mock-first; no live provider call — the only subprocess exercised against a real binary is the offline fake-CLI stub.
- `shell=False`, argv list, no task-derived strings on argv (V10/O4); router writes no file, persists no streams (V15/O2).
- Cross-flag forwarding refused at the router (V8) and independently at the adapter argparse (V8b).
- Guard chain unchanged: the routed adapter runs `worker-context-guard.sh` first; results validated by
  `worker-result-check.py`. Proposal-only — no `git apply`, no auto-apply.

## Final Status

**PASS** — 20/20 checks pass; deterministic task-only routing, byte-identical mock parity (V3), env passthrough without
stripping (V14), cross-flag safety at two layers (V8/V8b), argv/stream hygiene; protected files byte-unchanged; no live
provider call. Stopped before commit per instruction.
