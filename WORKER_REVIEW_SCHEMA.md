# WORKER_REVIEW_SCHEMA.md

Orchestrator (and optional critic) review record for `.harness/workers/reviews/<task_id>.json`.
Review NEVER mutates the repo. It records the decision and the gate results.

```json
{
  "task_id": "string",
  "reviewer": "orchestrator | critic | human",
  "reviewed_at": "ISO-8601",
  "decision": "apply | reject | needs_changes",
  "checks": {
    "schema_valid": true,
    "scope_check": "pass | fail",
    "security_check": "pass | fail",
    "consistency_check": "pass | fail",
    "no_secret_content": "pass | fail",
    "disallowed_category": "pass | fail"
  },
  "notes": "rationale; what must change if needs_changes/reject",
  "apply_policy": "edit_write_only",
  "apply_run_id": "DMC run id of the scoped apply (only if decision=apply); else null"
}
```

Invariants:
- `apply_policy` MUST be `edit_write_only` — application happens through scope-guarded `Edit`/`Write`,
  never `git apply`/`patch`.
- `decision=apply` is permitted ONLY when every `checks.*` is pass/true.
- A `reject` / `needs_changes` review leaves the repo unchanged.
