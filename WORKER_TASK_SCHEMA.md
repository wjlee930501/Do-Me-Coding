# WORKER_TASK_SCHEMA.md

Worker task JSON for `.harness/workers/tasks/<task_id>.json`. The orchestrator authors this; the
worker receives ONLY this bundle (clipped, secret-scrubbed). A worker has no fs/git/shell/network
access to the repo.

```json
{
  "task_id": "string (unique)",
  "objective": "one-sentence goal",
  "allowed_files": ["paths the worker may propose changes to"],
  "forbidden_files": ["paths the worker must not touch"],
  "context_summary": "orchestrator-authored prose context (no secrets)",
  "relevant_snippets": [
    { "file": "path", "start_line": 0, "end_line": 0, "text": "clipped, secret-scrubbed excerpt" }
  ],
  "expected_output_type": "unified_diff | instructions | analysis",
  "security_constraints": "must include: no secrets; no command execution; no direct repo mutation",
  "verification_hints": ["tests/commands the orchestrator will run, e.g. 'vitest run'"],
  "model_target": "e.g. glm-5.2",
  "max_context_tokens": 0,
  "token_budget": 0,
  "timeout_seconds": 0,
  "cancellation_policy": "expire | manual",
  "provider_target": {
    "type": "mock | api_key | oauth_cli | manual_import",
    "provider": "string",
    "model": "string",
    "execution_mode": "proposal_only",
    "credential_policy": "no_credentials_in_repo",
    "secret_policy": "no_secret_context"
  }
}
```

Invariants:
- `provider_target.execution_mode` MUST be `proposal_only`.
- `provider_target.credential_policy` MUST be `no_credentials_in_repo`.
- `provider_target.secret_policy` MUST be `no_secret_context`.
- v0.2: `provider_target.type` ∈ {`mock`, `manual_import`} only (live adapters deferred to v0.2.1+).
- No `allowed_files`/`relevant_snippets` path may be secret-bearing (enforced by `worker-context-guard.sh`, fail-closed).
- No secret VALUES anywhere in the bundle.
