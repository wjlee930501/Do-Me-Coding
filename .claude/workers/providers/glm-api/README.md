# glm-api — Do-Me-Coding Worker Bridge provider adapter (v0.2.1)

First **live** provider adapter (`provider_target.type=api_key`, model GLM 5.2/configurable). It maps a
sanitized DMC worker task → a GLM request → a `WORKER_RESULT_SCHEMA` result. **Mock-first**: default mode
makes no network call.

## Modes
- **Default `--mock <fixture>` (no network):**
  ```
  glm-api-adapter.py --task <task.json> --mock fixtures/glm-response-mock.json --out <result.json>
  ```
- **`--live` (strongly opt-in; unexercised by build/CI):** requires ALL primary gates — explicit `--live`
  + explicit `--allow-network` + `GLM_API_KEY` present + a context-guard-approved payload. A "not in CI"
  check is best-effort **defense-in-depth only**, never the sole guard.

## Safety contract
- Workers PROPOSE only; the adapter NEVER mutates the repo, runs git, or applies patches. The result is a
  review artifact; application happens later via the DMC scope gate (Edit/Write), never `git apply`.
- `worker-context-guard.sh` runs FIRST (fail-closed) — secret-bearing paths/inline secrets in the task →
  dispatch refused. Security model: **reject unsafe context, do not redact**. The payload builder also
  re-asserts the final payload is secret-free.
- `GLM_API_KEY` read from env only; non-printing presence check; never serialized into logs/results/evidence.
- The produced result is validated by `worker-result-check.py` at import (schema, scope, consistency,
  disallowed categories, no secret) — the adapter's output is not trusted blindly.

## Out of scope (v0.2.1)
OAuth / local-CLI provider (v0.2.2+), multi-worker (v0.3), background daemon, CI automation, auto-apply,
cost/quota optimization. No OAuth/session/token handling here.
