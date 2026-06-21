# Verification Report

Review-Verdict: critic=PASS codex=ACCEPT

(critic=PASS via the round-1 4-critic panel (dim2 PASS) + round-2 focused re-pass (3× PASS) + 2 refinements.
codex=ACCEPT via the Codex Independent Release Audit (thread 019eea04) — one optional taken (refreshed the router module
docstring); safe-to-stage/commit yes, safe-to-push no.)

## Run ID
dmc-v0.3.2-manual-import-router-wiring

## Plan
`.harness/plans/dmc-v0.3.2-manual-import-router-wiring.md` (Status: APPROVED, rev 3). Authorizes exactly the
`provider-router.py` + `ROUTING.md` edits — nothing else on the provider surface.

## Changed Files
- `.claude/workers/providers/provider-router.py` — **authorized protected edit**: REGISTRY entry `(manual_import,
  manual-import)` with `live_flag=None`; refusal tuple `("", "mock")`; `--import` arg + `allow_abbrev=False`; no-live guard
  (before `required = entry["live_flag"]`); router-side cross-flag rejection (`--mock`@manual_import / `--import`@others).
- `.claude/workers/providers/ROUTING.md` — **authorized protected edit**: routing-table row + refuse-list + argv-hygiene
  (`--import`) + cross-flag section + v0.3.2 note (kept truthful vs the new routing behavior).
- `.harness/evidence/dmc-v0.3.2-verify.sh` — routing verification harness (new).
- `.harness/verification/dmc-v0.3.2-manual-import-router-wiring.md` — this report.
- `.harness/plans/dmc-v0.3.2-manual-import-router-wiring.md` — the approved plan.

Unchanged (byte-identical): manual-import / glm-api / oauth-cli adapters, `WORKER_*_SCHEMA.md`, `.claude/hooks/*`,
`PROVIDER_CONTRACT.md`, `dmc-glm-smoke`. The manual-import **adapter** is dispatched unchanged.

## What shipped
manual_import is now **routable**: the router selects `manual-import-adapter.py` from `provider_target` and dispatches it
**unchanged**, forwarding `--import`/`--out` (never `--mock`, never a live flag). It adds **no** new trust/network/exec —
`shell=False`, argv hygiene preserved (no task-derived string on argv), `--print-dispatch` prints paths+flags only. No
schema change; no adapter change; the router still refuses `""`/`mock`.

## Commands Run
| Command | Result |
|---|---|
| `bash .harness/evidence/dmc-v0.3.2-verify.sh` | **8 PASS / 0 FAIL**, exit 0 |
| scoped `git diff --name-only` over the protected set | only `provider-router.py` + `ROUTING.md` (rest byte-unchanged) |

## Verification matrix (8 PASS / 0 FAIL)
- **AC1** manual_import `--print-dispatch` → `manual-import-adapter.py`; argv has `--import`, no `--mock`/`--live`.
- **AC2** routed `--out` **byte-identical** to direct (same task + `import-success.json`; deterministic sentinels).
- **AC3** manual_import `--live` → refused with **"live not supported"** (the no-live guard, not "requires explicit None").
- **AC3b** `--import`@glm-api and `--mock`@manual_import → **router** `die()` pre-exec (exit 1, `provider-router:` prefix —
  distinct from the adapter-argparse exit-2 backstop).
- **AC4** no regression: glm-api/oauth-cli dispatch + routed-vs-direct parity (mock) unchanged; `""`/`mock` still refuse;
  **live-flag translation** intact (glm `--allow-network` only, oauth `--allow-exec` only, cross opt-in refused).
- **AC5** only `provider-router.py` + `ROUTING.md` changed (tracked); adapters/schemas/hooks/contract/smoke byte-unchanged.
- **AC6** dispatch `shell=False`; no network lib; no `shell=True`; execs only a registered adapter.

## Safety Posture
Two authorized protected edits (router + ROUTING.md), both verified; everything else on the provider surface byte-unchanged.
No live/network/credential/model-API call; mock/offline only. Router adds no trust beyond exec-one-registered-adapter; the
manual_import path has no live mode and the router refuses `--live`/`--mock` for it pre-exec. ROUTING.md kept truthful.
No `__pycache__` artifacts (`PYTHONDONTWRITEBYTECODE`).

## Final Status
**PASS** — 8/8 verification assertions green; only the two authorized protected files changed; manual-import adapter
dispatched unchanged. **Codex Independent Release Audit: ACCEPT.** Staged the approved set (gate-check carving exactly
`provider-router.py` + `ROUTING.md` from the protected list for this milestone), committed; **push deferred** to the human gate.
