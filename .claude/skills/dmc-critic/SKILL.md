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

Return one status:
- APPROVE
- REJECT
- NEEDS CLARIFICATION

Criteria:
1. Clarity
2. Verification
3. Context
4. Real file references
5. Business logic assumptions
6. Scope control
7. Data/security/migration/package/env risks
8. Rollback path

If rejecting, provide a patch-style checklist of what must change.
