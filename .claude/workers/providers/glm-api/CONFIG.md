# glm-api adapter — CONFIG

Configuration is via environment variables ONLY. **Never set these in the repo, in any committed
file, or in `.harness/`.** Values are read at execution time and never logged/serialized.

| Env var | Required | Purpose |
|---|---|---|
| `GLM_API_KEY` | for `--live` only | API key. Read at runtime; presence-checked non-printing; NEVER printed/logged/stored. |
| `GLM_API_BASE` | optional | Provider base URL override (default: vendor default). |
| `GLM_MODEL` | optional | Model override (default `glm-5.2`). |
| `GLM_API_TIMEOUT_SECONDS` | optional | Request timeout (default 60). |

## Safety
- `GLM_API_KEY` must never appear in logs, task JSON, result JSON, evidence, raw provider logs, or `.harness/`.
- Any live request log omits/redacts the `Authorization` header (the key lives in the header, not the payload).
- Raw provider responses, if stored, are local-only and redacted by default under `.harness/workers/providers/glm-api/` (gitignored).
- Live mode is multi-gated (see README); default mode is mock/no-network.
