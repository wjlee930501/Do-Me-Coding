# Do-Me-Coding v0.1

Do-Me-Coding is a Claude Code-first execution harness that forces AI coding agents to plan, critique, implement, verify, recover, and report with evidence.

It is not a new coding agent. It is a disciplined operating layer for Claude Code, Codex, and later OpenCode.

## Core Philosophy

```text
Do not just suggest.
Do the work.
Prove the work.
Do not fake completion.
```

## Non-Negotiable Rules

1. No verification, no done.
2. No accepted file scope, no edit.
3. No explicit acceptance criteria, no execution.
4. No evidence log, no final completion claim.
5. No independent runtime in v0.1.
6. No OMO runtime clone in v0.1.
7. No copied leaked prompt text.

## Default Loop

```text
Goal
→ Intent Gate
→ Repo Scan
→ Plan
→ Critic Review
→ File Scope Lock
→ Execute Task
→ Verify
→ Fix Loop
→ Evidence Log
→ Report
→ Continue or Stop
```

## Commands

### `/dmc-ultrawork <task>`

Use for substantial engineering tasks. It forces workflow-style execution with planning, critique, file-scope locking, verification, and evidence.

### `/dmc-plan-hard <task>`

Planning only. No product code edits. May create or update plan files only under `.harness/plans/`.

### `/dmc-critic <plan-path>`

Ruthlessly reviews a plan and returns `APPROVE`, `REJECT`, or `NEEDS CLARIFICATION`.

### `/dmc-start-work <approved-plan-path>`

Executes only an approved plan. Creates run state and approved file scope under `.harness/runs/`.

### `/dmc-verify-hard [run-id or plan-path]`

Runs strict verification and writes a report under `.harness/verification/`.

### `/dmc-init-deep [focus]`

Builds or refreshes `AGENTS.md` project memory from repo facts only.

## Evidence Policy

Evidence files live under:

```text
.harness/evidence/
.harness/verification/
```

Final report format:

```text
Status: PASS | FAIL | PARTIAL

Changed Files:
- path: reason

Verification:
- command: result

Evidence:
- evidence file path
- verification file path

Unresolved Risks:
- risk or none

Next Action:
- one concrete next step
```

## Model / Effort Policy

Recommended daily mode:

```text
/model opus
/effort xhigh
```

Do-Me-Coding does not require `/effort ultracode` globally. The `/dmc-ultrawork` skill includes a prompt-level workflow request using the `ultracode` keyword so strong workflow behavior can be requested while keeping the session on Opus xhigh.

For very large repo-wide audits or migrations, you may still use:

```text
/effort ultracode
```

## v0.1 Scope

Included:
- Claude Code skills
- Claude Code subagents
- Claude Code hooks
- `.harness` evidence and schema structure
- repo operating docs

Excluded:
- independent CLI
- model router
- external GLM/Kimi router
- web UI
- mobile UI
- MCP server
- full OMO fork
