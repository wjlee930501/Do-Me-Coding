# Do-Me-Coding v0.2.3 — Provider Routing Layer

## Goal

Add a thin, deterministic **provider router** so a DMC worker dispatch can select the correct provider adapter from
the task bundle — starting with `glm-api` (`api_key`) and `oauth-cli` (`oauth_cli`) — **without** changing either
adapter, any schema, or any guard, and **without** inferring the provider from secrets or environment. The router
wraps the existing adapters; it adds no new network/exec capability and preserves each adapter's exact behavior,
gates, and mock-first defaults.

## User Intent

feature (Provider Access Layer: add explicit routing across the already-shipped adapters)

## 1. Problem statement

- Today each adapter is invoked by its own path (`glm-api-adapter.py`, `oauth-cli-adapter.py`). The orchestrator must
  hardcode which script to run for a given task; there is no single deterministic entry point that maps a task to an
  adapter.
- Both adapters already share a near-identical CLI surface — `--task`, `--mock`, `--live`, `--out` — differing only in
  the **live opt-in flag** (`glm-api` uses `--allow-network`; `oauth-cli` uses `--allow-exec`). That divergence makes a
  naive "forward all flags" wrapper unsafe (argparse would reject an unknown flag).
- The task bundle already carries `provider_target.type` ∈ {`mock`,`api_key`,`oauth_cli`,`manual_import`} and a
  `provider` string (`WORKER_TASK_SCHEMA.md:25-32`). That is the natural, explicit, secret-free routing key — but
  nothing consumes it yet.
- As providers grow, selection logic risks leaking into ad-hoc scripts or (worse) inferring a provider from env vars /
  presence of a key. We want one table-driven router that selects **only** from the task's `provider_target`.

## 2. Non-goals

- Multi-worker orchestration / parallel fan-out (v0.3).
- Provider **fallback / retry / failover / load-balancing / cost or latency routing** — routing is a pure 1:1 lookup.
- Automatic patch application / `git apply` / auto-apply (always proposal-only).
- Any NEW live capability — the router never makes a network/exec call itself; it only execs an adapter, which keeps
  its own multi-gated live path.
- Inferring the provider from secrets, environment variables, presence of a key, or model-name heuristics.
- Changing `glm-api` (v0.2.1/v0.2.1.1) or `oauth-cli` (v0.2.2) adapter behavior in any way.
- Schema / hook / validator / guard changes (see §5; none expected).
- A shared provider-abstraction rewrite or a `providers/_lib` extraction.

## 3. Candidate design

- **New thin router** `.claude/workers/providers/provider-router.py`. It:
  1. Loads `--task <task.json>` and reads ONLY `provider_target.type` and `provider_target.provider` (deterministic,
     explicit, from the task bundle — never from env/secrets).
  2. Looks up a **static REGISTRY table** keyed by `(type, provider)`:
     ```python
     REGISTRY = {
       ("api_key",  "glm-api"):   {"adapter": "glm-api/glm-api-adapter.py",   "live_flag": "--allow-network"},
       ("oauth_cli","oauth-cli"): {"adapter": "oauth-cli/oauth-cli-adapter.py","live_flag": "--allow-exec"},
     }
     ```
     Matching is exact on `(type, provider)`. If `provider` is empty, match succeeds ONLY if the `type` has exactly one
     registered adapter; otherwise **refuse** (ambiguous → deterministic error, no guess). Unknown `(type, provider)`,
     missing `provider_target`, or `manual_import`/`mock` (no live adapter) → **refuse** with a clear message.
     **Dispatch contract:** each registry adapter path is resolved to an **absolute path under the approved providers
     directory** (`.claude/workers/providers/`) and the router **refuses if the resolved adapter file is missing**
     (or escapes that directory) — the router never execs a path outside the approved provider tree.
  3. Dispatches by **`subprocess.run([...], shell=False)`** to the selected adapter, forwarding ONLY a known, explicit
     flag set: `--task` (the same path), `--mock <fixture>` if given, `--out <path>` if given, and — for `--live` — the
     adapter-correct `live_flag` from the registry (`--allow-network` for glm-api, `--allow-exec` for oauth-cli). A
     `--live` request for one provider never forwards the other provider's opt-in flag. Unknown/mismatched flags are
     rejected before dispatch.
     - **Cross-flag backstop (O1, empirically verified):** even if the router had a bug and forwarded the wrong opt-in
       flag, each adapter's own argparse **independently rejects** an unrecognized flag (`glm-api` rejects
       `--allow-exec`; `oauth-cli` rejects `--allow-network`, both exiting non-zero). So cross-forwarding **fails
       closed** at the adapter layer regardless of the router — a second, independent line of defense behind the
       router's per-entry `live_flag` selection.
  4. Returns the adapter's exit code and stdout/stderr unchanged. The router writes no result itself; the adapter still
     writes `--out`. The router performs **no** token/secret handling and **no** repo mutation.
- **Environment passthrough policy (R1):** the router passes the **parent environment through to the selected adapter
  unchanged** (default `subprocess.run` inheritance) — the adapter, not the router, owns ALL provider credential/env
  handling (e.g. glm-api reads `GLM_API_KEY`/`GLM_API_BASE`; oauth-cli reads `DMC_OAUTHCLI_BIN`). The router itself
  reads env vars for **nothing** — not for provider selection, credential discovery, routing, logging, or inference —
  and **never logs env values**. Selection is a pure function of `provider_target` only (see V7). Stripping or
  sanitizing the child env is explicitly NOT done, since that would break the adapters' own gated live paths.
  oauth-cli's own `minimal_env()` still governs the **adapter→CLI** hop and is unaffected by this router→adapter
  passthrough (it operates one level deeper, inside the adapter).
- **Argv hygiene (O4):** the router places on the child argv ONLY operator-provided paths (`--task`/`--mock`/`--out`
  values, passed through verbatim from the router's own CLI) and **fixed, registry-derived flags** (the adapter path
  and the entry's `live_flag`). **No task-derived string** (objective, snippets, file lists, provider strings, etc.)
  is ever placed on the child command line. Dispatch uses `subprocess.run([...], shell=False)` — argv list, no shell,
  no interpolation.
- **Stream handling (O2):** the router forwards adapter stdout/stderr **transparently** to its own stdout/stderr and
  **persists no raw streams** (it writes no file; only the adapter writes `--out`). Adapter diagnostics on stderr are
  already secret-safe (glm-api redacts; oauth-cli's die messages omit token material), so transparent passthrough
  introduces no new leak surface.
- **Timeout ownership (O3):** timeouts are **adapter-owned** (`GLM_API_TIMEOUT_SECONDS`, `DMC_OAUTHCLI_TIMEOUT_SECONDS`);
  a routed child self-terminates. This plan does NOT add a router-level timeout. (If one is ever added, it must be a
  **defense-in-depth ceiling ABOVE** the adapter-owned timeouts, never a replacement for them.)
- **Guard chain preserved by delegation:** the router does NOT re-implement guards. The selected adapter still runs
  `worker-context-guard.sh` FIRST (fail-closed) and the caller still validates the result with `worker-result-check.py`,
  exactly as today. The router adds zero new trust surface beyond "exec one of two known adapter scripts."
- **Mock-first preserved:** router default requires `--mock` (no live). `--live` is opt-in and only ever forwards the
  single correct adapter opt-in flag; the adapter's own gates (`--allow-network`/`--allow-exec` + key/auth + not-CI)
  still apply unchanged.
- **Determinism/testability:** selection is a pure function of `(type, provider)` → registry entry; identical inputs
  always select the identical adapter+flag. The router can be unit-tested without any provider call.

## 4. File-level implementation scope

| Path | Change | Edit? |
|---|---|---|
| `.claude/workers/providers/provider-router.py` | NEW — table-driven router (load task → registry lookup → `shell=False` dispatch) | yes (new) |
| `.claude/workers/providers/ROUTING.md` | NEW — the routing table + "selection is task-only, never env/secret" contract | yes (new) |
| `.harness/evidence/dmc-v0.2.3-verify.sh` | NEW — mock-only verification harness | yes (new) |
| `.harness/verification/dmc-v0.2.3-provider-routing.md` | NEW — verification report | yes (new) |
| `INSTALL_MANIFEST.md`, `.claude/install/dmc-install.sh` / `dmc-uninstall.sh` | edit ONLY if the installer must wire the router (mirror provider wiring) — additive | yes (if needed) |
| `DMC.md` / `CLAUDE.md` | edit ONLY to note the router entry point — additive doc | yes (if needed) |
| `.claude/workers/providers/glm-api/glm-api-adapter.py` | **NO change** — wrapped, not modified (preserve v0.2.1.x) | no |
| `.claude/workers/providers/oauth-cli/oauth-cli-adapter.py` | **NO change** — wrapped, not modified (preserve v0.2.2 mock-first) | no |
| `WORKER_*_SCHEMA.md`, `.claude/hooks/*` (guards/validators), `dmc-glm-smoke` | **NO change** (routing key already in schema; guard chain delegated) | no |

## 5. Safety constraints

- **No schema change** — `provider_target.type` and `.provider` already exist (`WORKER_TASK_SCHEMA.md:25-32`); the
  registry lives in router code. (If, during implementation, a schema field proves genuinely missing, STOP and
  re-plan — do not edit a schema silently.)
- **No hook/validator/guard change** — the router delegates to the adapter (which runs `worker-context-guard.sh`) and
  leaves `worker-result-check.py` validation to the caller, exactly as today.
- **Selection is task-only** — the router reads `provider_target` from the task JSON and NOTHING else for selection;
  it must NOT consult env vars, secret presence, or model heuristics to pick a provider.
- **Env passthrough, not env reading (R1)** — the router passes the parent env through to the adapter UNCHANGED so the
  adapter's own gated live path works; the router reads env for nothing and logs no env values. Stripping the child
  env is explicitly not done. (oauth-cli's `minimal_env()` still governs the deeper adapter→CLI hop.)
- **Argv hygiene (O4)** — only operator-provided paths + fixed registry-derived flags reach the child argv; no
  task-derived string is ever placed on the command line; `shell=False` always.
- **Streams not persisted (O2)** — adapter stdout/stderr forwarded transparently; the router writes no raw-stream file.
- **Timeouts adapter-owned (O3)** — no router-level timeout in this plan; if ever added it is a ceiling above (never a
  replacement for) the adapter-owned timeouts.
- **No live provider call** in planning or build verification — all routing tests use `--mock`; the router adds no
  network/exec of its own. A live routed call is a separate, later, explicitly-approved step.
- **No `.env*` reads** anywhere in the plan, tests, or router; no credential/token printed, logged, or serialized.
- **Proposal-only preserved** — router never applies output, never runs `git apply`, never auto-applies; `shell=False`
  always, argv list, no shell interpolation; the router writes no repo files (only the adapter's `--out`).
- **Adapter behavior preserved** — glm-api and oauth-cli are invoked unchanged; a routed `--mock` run must produce a
  byte-identical `--out` JSON file (mock mode) to invoking the adapter directly with the same flags (regression
  assertion V3 in §6; stdout/stderr chatter and live mode are out of scope for this invariant).

## 6. Verification matrix (mock-only, NO live provider)

| # | Scenario | Expectation |
|---|---|---|
| V1 | task `type=api_key, provider=glm-api` + `--mock <glm fixture>` | routes to glm-api adapter; `worker-result-check.py` ACCEPT |
| V2 | task `type=oauth_cli, provider=oauth-cli` + `--mock <oauth fixture>` | routes to oauth-cli adapter; ACCEPT |
| V3 | routed `--mock` result vs direct adapter `--mock` result (same task/fixture) | **byte-identical `--out` JSON file** (R2: compares ONLY the `--out` result file, ONLY in `--mock` mode; does NOT compare stdout/stderr chatter and makes NO live-mode byte-identity claim — live results carry provider-supplied ids/timestamps that legitimately vary) |
| V4 | unknown `(type, provider)` (e.g. `api_key/unknown`) | deterministic refuse; no adapter executed; clear message |
| V5 | missing `provider_target` / `manual_import` / `mock`-only type | refuse (no live adapter); no adapter executed |
| V6 | empty `provider` with a single-adapter type vs multi-adapter type | single → routes; ambiguous → refuse |
| V7 | route **selection** independent of environment | set bogus `GLM_API_KEY`/`DMC_OAUTHCLI_BIN`/other env → the SELECTED route is unchanged (proves selection is task-only). NOTE: this asserts env values do not affect **route selection** — it does NOT mean the child env is stripped; the parent env is still passed through to the adapter unchanged (R1). |
| V8 | live-flag translation | `--live` for api_key forwards `--allow-network` only; for oauth_cli forwards `--allow-exec` only; cross-flag never forwarded (asserted by inspecting the forwarded argv in a dispatch dry-run / echo shim — still NO live call) |
| V8b | cross-flag adapter backstop (O1) | a deliberately mis-forwarded opt-in flag is independently rejected by the target adapter's argparse (`glm-api`✗`--allow-exec`, `oauth-cli`✗`--allow-network`), non-zero exit — verified WITHOUT a live call |
| V14 | env passthrough (R1) | a routed `--mock` run with a benign marker env var set in the parent is observable to the child adapter (passthrough works), while route selection is unchanged (V7); router emits no env values in its own logs |
| V9 | `--out` / `--mock` forwarding | adapter receives and honors them; result written to the given path |
| V10 | injection-safety (O4) | `grep -nE 'shell=True\|git[[:space:]]+apply'` router → none; dispatch uses an argv list; assert NO task-derived string (objective/snippets/file lists/provider strings) appears on the child argv — only operator-provided `--task`/`--mock`/`--out` paths + fixed registry-derived flags |
| V15 | stream handling (O2) | router forwards adapter stdout/stderr transparently and persists no raw stream file (router writes nothing but the adapter's `--out`) |
| V11 | no mutation | `git status` clean before/after a routed mock run |
| V12 | protected files byte-unchanged | `git diff --name-only` over adapters/hooks/schemas/`dmc-glm-smoke` → empty |
| V13 | no `.env*` read; no token/secret printed | harness asserts no `.env*` access and no secret-shaped output |

(V8's live-flag translation is validated WITHOUT a live call — e.g. the router prints/var-dumps the argv it WOULD
exec, or dispatches to a no-op echo shim — so the correct opt-in flag is proven without `--allow-network`/`--allow-exec`
ever reaching a real provider.)

## 7. Regression risks

| Risk | Severity | Mitigation |
|---|---|---|
| Flag forwarding alters adapter behavior | high | Forward only an explicit known flag set; V3 asserts routed result is byte-identical to direct invocation. |
| Router defaults to live / breaks mock-first | high | Default requires `--mock`; `--live` opt-in only; adapter gates unchanged. |
| Cross-provider opt-in flag forwarded (e.g. `--allow-exec` to glm-api) | high | Registry carries each adapter's `live_flag`; only that flag is forwarded; V8 asserts. |
| Selection silently infers from env/secret | high | Selection reads ONLY `provider_target`; V7 proves env-independence. |
| Router strips/sanitizes child env → adapter live path breaks (can't read `GLM_API_KEY`/`DMC_OAUTHCLI_BIN`) | med | R1: parent env passed through unchanged; V14 proves passthrough; V7 keeps selection env-independent. |
| Task-derived string lands on child argv (injection / leakage) | high | O4: only operator paths + fixed flags on argv, `shell=False`; V10 asserts. |
| Double context-guard changes error semantics | med | Router delegates the guard to the adapter (runs once); router adds no guard. |
| `shell=True` / injection via task-derived strings | high | `shell=False`, argv list, no task content on argv; V10 asserts. |
| Adapter path drift / wrong adapter executed | med | Static registry with absolute-resolved adapter paths under the providers dir; refuse if the resolved adapter file is missing. |
| Scope creep into schema/guard/adapter edits | med | §4 marks them `no`; V12 asserts byte-unchanged. |

## 8. Rollback plan

- **Pre-commit:** remove the new router files (`provider-router.py`, `ROUTING.md`), the verify harness, and any
  additive installer/doc lines via `git restore` / `rm`. Adapters are untouched, so direct invocation still works.
- **Post-commit:** `git revert <v0.2.3-commit-sha>` — additive router only; guards/validator/schemas/adapters
  untouched → clean revert; both providers remain individually invocable exactly as before.

## 9. Approval Status

Status: APPROVED
Approver: 대표님
Approved At: 2026-06-21
