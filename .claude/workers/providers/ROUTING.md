# Provider Routing Layer — `provider-router.py` (v0.2.3)

A thin, deterministic router that selects a Worker Bridge provider adapter from the **task bundle** and dispatches to
it **unchanged**. It adds no new network/exec capability and no new trust surface beyond executing one of a few known
adapter scripts. **Mock-first** (default requires `--mock`; live is opt-in and gated by the adapter).

## Routing table

| `provider_target.type` | `provider_target.provider` | Adapter (under `.claude/workers/providers/`) | Live opt-in flag forwarded |
|---|---|---|---|
| `api_key`   | `glm-api`   | `glm-api/glm-api-adapter.py`     | `--allow-network` |
| `oauth_cli` | `oauth-cli` | `oauth-cli/oauth-cli-adapter.py` | `--allow-exec` |
| `manual_import` | `manual-import` | `manual-import/manual-import-adapter.py` | — (no live; input via `--import`) |
| `mock` / empty type | — | (none — refuse) | — |

*`manual_import` routing added in v0.3.2 (standalone pure-validation importer; no live mode).*

## Selection contract — task-only, never env/secret

- Selection is a **pure function of `provider_target.{type,provider}`** read from the task JSON. The router consults
  **nothing else** — not environment variables, not secret/key presence, not model-name heuristics — to pick a provider.
- Matching is **exact** on `(type, provider)`. If `provider` is empty, the route resolves **only** if the type has
  exactly one registered adapter; otherwise the router **refuses** (ambiguous → deterministic error, no guess).
- Unknown `(type, provider)`, missing `provider_target`, or `mock` / empty type → **refuse** with a clear message. No
  adapter is executed on a refusal. (`manual_import` routes to `manual-import` — a standalone validation importer with
  **no live mode**.)

## Dispatch contract

- The registered adapter path is resolved to an **absolute path under** `.claude/workers/providers/` and the router
  **refuses if it is missing or escapes that directory**.
- Dispatch is `subprocess.run([...], shell=False)` — an **argv list**, no shell, no interpolation.
- **Argv hygiene:** only operator-provided paths (`--task`/`--mock`/`--import`/`--out`) and **fixed registry-derived flags** (the
  adapter path + the entry's live opt-in flag) reach the child argv. **No task-derived string** (objective, snippets,
  file lists, provider strings) is ever placed on the command line.
- **Environment passthrough:** the parent environment is passed to the adapter **unchanged** — the adapter, not the
  router, owns all provider credential/env handling (e.g. `GLM_API_KEY`, `DMC_OAUTHCLI_BIN`). The router reads env for
  **nothing** and logs no env values. (oauth-cli's own `minimal_env()` still governs the deeper adapter→CLI hop.)
- **Streams:** adapter stdout/stderr are forwarded transparently; the router persists no raw streams and writes no
  result file — only the adapter writes `--out`.
- **Timeouts:** adapter-owned (`GLM_API_TIMEOUT_SECONDS`, `DMC_OAUTHCLI_TIMEOUT_SECONDS`); the router adds none.

## Live opt-in & cross-flag safety

- On `--live`, the router forwards **only** the selected adapter's registry live flag. A mismatched/cross opt-in flag
  (e.g. `--allow-exec` for `glm-api`) is **refused before dispatch**.
- `manual_import` has **no live mode** (no `live_flag`); `--live` against it is **refused before dispatch**.
- **Input-flag contract (v0.3.2):** the router refuses `--mock` for `manual_import` and `--import` for the network/exec
  providers **before dispatch** (the router owns its input-flag contract; the target adapter's argparse rejection remains
  as defense-in-depth).
- **Defense in depth:** even if the router forwarded the wrong flag, the target adapter's own argparse independently
  rejects an unrecognized flag (`glm-api` ✗ `--allow-exec`; `oauth-cli` ✗ `--allow-network`), so cross-forwarding fails
  closed at the adapter layer too.

## Guard chain (unchanged)

The router does NOT re-implement guards. The selected adapter still runs `worker-context-guard.sh` first (fail-closed),
and the caller still validates the result with `worker-result-check.py` — exactly as without the router. Proposal-only:
no `git apply`, no auto-apply.

## Dry-run (verification)

`--print-dispatch` prints the resolved adapter and the child argv (paths + flags only — no secrets, no task content)
and exits **without** executing the adapter. Used to assert live-flag translation and argv hygiene with no live call.

## Out of scope (v0.2.3)

Multi-worker / fan-out (v0.3); fallback / retry / failover / load / cost routing; auto-apply; any new live capability;
inferring a provider from env/secrets; adapter/schema/guard changes.
