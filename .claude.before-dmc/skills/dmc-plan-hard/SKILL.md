---
name: dmc-plan-hard
description: Produce a decision-complete implementation plan before code changes.
argument-hint: task description
disable-model-invocation: true
effort: xhigh
disallowed-tools: Edit, Write
---

# Do-Me-Coding Plan Hard

Task:

```text
$ARGUMENTS
```

You are planning only. Do not edit product code.

Create a plan using `PLAN_SCHEMA.md` and save or propose it under:

```text
.harness/plans/<short-task-slug>.md
```

Required sections:
- Goal
- User Intent
- Current Repo Findings
- Relevant Files
- Out of Scope
- Proposed Changes
- Acceptance Criteria
- Risks
- Assumptions
- Execution Tasks
- Verification Commands
- Approval Status

Rules:
- Relevant files must be based on actual repo inspection.
- Acceptance criteria must be measurable.
- Approval Status must be DRAFT until the user approves.
- Do not implement.
