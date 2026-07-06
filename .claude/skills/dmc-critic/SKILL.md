---
name: dmc-critic
description: Ruthlessly review a Do-Me-Coding plan for ambiguity, missing acceptance criteria, unsafe scope, and weak verification.
argument-hint: path to plan
disable-model-invocation: true
effort: xhigh
disallowed-tools: Edit, Write
---

# Do-Me-Coding Critic

Plan path:

```text
$ARGUMENTS
```

Run a fresh-context adversarial pass as the **Critic / Falsifier** role
(`orchestration/roles.json`). The critic is read-only and advisory — it reviews, it never edits the
plan it reviews and never grants approval (invariant C11: a verdict opens no gate).

## Emit a `critic-verdict.json` artifact (not prose-only)

Emit a verdict artifact conforming to `.harness/schemas/critic-verdict.schema.md`, shaped like:

```json
{
  "schema": "dmc.critic-verdict.v1",
  "work_id": "<canonical subject id>",
  "plan_hash": "<hex >=16>",
  "repo_hash": "<hex >=16>",
  "target_ref": "<plan path or diff ref>",
  "verdict": "APPROVE|REJECT|NEEDS_CLARIFICATION",
  "lenses": ["correctness", "scope", "security"],
  "criteria_checked": [{"criterion_ref": "<ref>", "result": "met|unmet|na", "note": "<advisory>"}],
  "blockers": [{"id": "<id>", "statement": "<what must change>", "evidence_ref": "<ref>"}],
  "advisory": true,
  "context_provenance": "fresh"
}
```

Validate it with `bin/dmc verdict validate <critic-verdict.json>` (exit 0 = schema-valid, exit 3 =
refused). A `REJECT` MUST carry non-empty `blockers`; `advisory` MUST be `true`. Because the critic
is read-only, the caller persists the emitted artifact for validation.

Alongside the artifact, print a human-facing prose summary judged against these criteria:
1. Clarity
2. Verification
3. Context
4. Real file references
5. Business logic assumptions
6. Scope control
7. Data/security/migration/package/env risks
8. Rollback path

If the verdict is `REJECT` or `NEEDS_CLARIFICATION`, the prose summary carries a patch-style
checklist of what must change (mirrored in the artifact's `blockers`).
