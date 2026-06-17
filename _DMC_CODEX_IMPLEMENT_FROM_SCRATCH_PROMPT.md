# Codex Prompt: Generate Do-Me-Coding v0.1 From Scratch

Use this only if you do not unzip the scaffold and want Codex to create the same structure itself.

```text
You are implementing Do-Me-Coding v0.1 for this repository.

Mission:
Create a Claude Code Native Pack that forces disciplined AI coding workflows: plan, critique, execute, verify, evidence log, and final report.

Important constraints:
1. Do not build an independent CLI.
2. Do not build a web app.
3. Do not implement model routing.
4. Do not copy OMO runtime.
5. Do not copy any Claude Fable leaked prompt text.
6. Do not modify product source code unless explicitly required for scaffold integration.
7. Only create docs, Claude Code skills, Claude Code subagents, hooks, and .harness schemas/directories.
8. Preserve existing project structure.
9. Keep all scripts readable and easy to audit.
10. If existing CLAUDE.md or AGENTS.md exists, merge instead of overwriting.

Create this file tree at repo root:

.claude/
  skills/
    dmc-ultrawork/SKILL.md
    dmc-plan-hard/SKILL.md
    dmc-critic/SKILL.md
    dmc-start-work/SKILL.md
    dmc-verify-hard/SKILL.md
    dmc-init-deep/SKILL.md
  agents/
    planner.md
    critic.md
    explorer.md
    executor.md
    verifier.md
  hooks/
    pre-tool-guard.sh
    scope-guard.sh
    evidence-log.sh
    stop-verify-gate.sh
  settings.json
.harness/
  plans/.gitkeep
  runs/.gitkeep
  evidence/.gitkeep
  verification/.gitkeep
  decisions/.gitkeep
  memory/.gitkeep
  schemas/
    plan.schema.md
    run.schema.md
    verification.schema.md
DMC.md
PLAN_SCHEMA.md
RUN_SCHEMA.md
VERIFICATION_SCHEMA.md
AGENTS.md
CLAUDE.md

Core behavior:
- /dmc-ultrawork should force a workflow-style process using the word ultracode in the instruction body, but keep effort as xhigh in frontmatter.
- /dmc-plan-hard must not edit product code. It writes or proposes a plan under .harness/plans.
- /dmc-critic reviews a plan with ruthless criteria.
- /dmc-start-work executes only approved plans and only within approved file scope.
- /dmc-verify-hard runs verification and writes evidence under .harness/verification.
- /dmc-init-deep creates or updates AGENTS.md style project memory after reading the repo.

After creating files:
1. Print the created file tree.
2. Summarize every created file.
3. Run bash -n on hook scripts.
4. Run shellcheck if available.
5. Run git diff --stat.
6. Do not claim full success unless files are actually created.
```
