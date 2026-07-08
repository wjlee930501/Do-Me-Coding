# Do-Me-Coding Research Vault Summary

This scaffold reflects the Notion research vault created for:

- LazyCodex
- OMO / Oh My OpenAgent
- Claude Dynamic Workflow
- Claude Code Skills / Hooks / Subagents / Agent SDK
- Public Claude Fable Prompt reference artifacts

## Key Design Decision

Do-Me-Coding v1.0 is a Claude Code Native Pack first.

Its founding (v0.1) design decision intentionally avoided:
- independent CLI
- web UI
- model router
- full OMO runtime clone
- copied prompt leak content

## Translation Map

LazyCodex:
- `/init-deep` → `/dmc-init-deep`
- `$ulw-plan` → `/dmc-plan-hard`
- `$start-work` → `/dmc-start-work`
- `$ulw-loop` → `/dmc-ultrawork` in v0.1, possible `/dmc-loop-until-verified` in v0.2

OMO:
- IntentGate → DMC intent classification
- Prometheus → planner
- Metis → critic gap analysis checklist
- Momus → critic
- Atlas → start-work execution
- Boulder → `.harness/runs/`

Claude Dynamic Workflow:
- prompt-level `ultracode` keyword → `/dmc-ultrawork`
- session-level `/effort ultracode` → optional for massive work only

Fable Prompt public references:
- Use only for prompt architecture patterns.
- Do not copy source prompt text.
