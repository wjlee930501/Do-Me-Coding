# WORKER_RESULT_SCHEMA.md

Worker result JSON for `.harness/workers/results/<task_id>.json`. The worker produces a structured
PROPOSAL only. `proposed_patch` is unified-diff TEXT — a review artifact, NOT applied by the worker
or by import. Application (if any) happens later via scope-guarded `Edit`/`Write` (never `git apply`).

```json
{
  "task_id": "string (matches the task)",
  "summary": "what the proposal does",
  "files_considered": ["paths the worker looked at"],
  "files_changed": ["paths the proposed_patch actually touches"],
  "proposed_patch": "unified diff TEXT (or empty if instructions)",
  "instructions": "natural-language change steps (alternative to proposed_patch)",
  "risks": ["..."],
  "assumptions": ["..."],
  "test_suggestions": ["..."],
  "confidence": "low | med | high (or 0..1)",
  "unresolved_questions": ["..."],
  "no_direct_mutation": true,
  "provider_metadata": {
    "provider_type": "mock | api_key | oauth_cli | manual_import",
    "provider": "string",
    "model_claimed": "string",
    "generated_at": "ISO-8601",
    "invocation_id": "string",
    "credential_exposure": "none"
  }
}
```

Invariants (validated at import/review, BEFORE any human application):
- `no_direct_mutation` MUST be `true`.
- `provider_metadata.credential_exposure` MUST be `none`.
- `files_changed` MUST equal the paths actually touched by `proposed_patch`.
- `files_changed` ⊆ task `allowed_files`; `files_changed` ∩ task `forbidden_files` = ∅.
- `files_changed` MUST NOT include disallowed categories unless explicitly allowed + approved:
  `.env*`, lockfiles (`*.lock`, `package-lock.json`, `pnpm-lock.yaml`), dependency files,
  DB/schema/migration files (`migrations/`, `drizzle`), binary files, production config.
- No secret VALUES anywhere in the result.
- A result failing any invariant is REJECTED with zero repo changes.
