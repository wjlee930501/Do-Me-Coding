---
name: dmc-plan-hard
description: Produce a decision-complete implementation plan before code changes.
---
<!-- DMC-HOST-NOTE:BEGIN -->
Host: Codex CLI. This SKILL.md lives at `.agents/skills/dmc-plan-hard/SKILL.md` (discovery
confirmed at codex-cli 0.132.0 per `docs/CODEX_ADAPTER.md`). Frontmatter is Codex-standard
(`name`, `description` only — Codex's skill YAML has no `argument-hint`,
`disable-model-invocation`, or `effort` keys). Invocation is EXPLICIT — run
`$dmc-plan-hard <task description>` or pick `dmc-plan-hard` from `/skills`; Codex never
auto-dispatches a skill (mirrors the Claude Code skill's `disable-model-invocation: true`).
The task description takes the place of `$ARGUMENTS` below.
<!-- DMC-HOST-NOTE:END -->

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
- This skill may write only `.harness/plans/*.md`.
- Product source files must not be edited.
- If the plan cannot be saved, propose it in chat and explain why.
- Relevant files must be based on actual repo inspection.
- Acceptance criteria must be measurable.
- Approval Status must be DRAFT until the user approves.
- Do not implement.
