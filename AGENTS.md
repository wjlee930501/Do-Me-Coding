# AGENTS.md — Project Memory for Do-Me-Coding

This file is the cross-agent project memory root. It is intentionally concise.

## Repo Overview

This sandbox repository contains the Do-Me-Coding v0.1 Claude Code Native Pack
scaffold on git branch `dmc-v0.1-scaffold`. It is an operating harness for
Claude Code/Codex-style coding work, not a standalone product application.

Visible top-level contents include Do-Me-Coding docs and schemas, `.claude/`
runtime configuration, `.harness/` workflow/evidence directories, `docs/`
source notes, and local import backup artifacts ending in `.before-dmc`.

## Package Manager

No package manager is detectable in this sandbox repo. No `package.json`,
package lockfile, `pyproject.toml`, `Cargo.toml`, `Makefile`, or CI workflow
was found under the inspected repository depth.

## Verification Commands

- lint: Unknown in this sandbox repo; no lint tool config was detected.
- typecheck: Unknown in this sandbox repo; no typed product project was detected.
- test: `bash -n .claude/hooks/*.sh`
- build: Unknown in this sandbox repo; no build system was detected.

## Architecture Landmarks

- `.claude/settings.json`: Claude Code hook wiring.
- `.claude/hooks/`: shell hooks for pre-tool guard, scope guard, evidence logging, and stop verification.
- `.claude/skills/`: Do-Me-Coding Claude Code skill prompts.
- `.claude/agents/`: planner, explorer, executor, verifier, and critic subagent prompts.
- `.harness/`: workflow state, evidence, verification, plans, runs, decisions, memory, and schema mirrors.
- `DMC.md`: project operating guide for Do-Me-Coding.
- `AUTONOMY.md`: autonomous-mode charter (v0.4 levels/stop-conditions); `docs/CONTEXT_MAP.md`: compact single-source context map.
- `PLAN_SCHEMA.md`, `RUN_SCHEMA.md`, `VERIFICATION_SCHEMA.md`: root schema documentation.
- `docs/`: source URL and Notion export reference notes.
- `*.before-dmc`: local import backup artifacts retained for reference.

## Do-Me-Coding Operating Rules

1. Do not edit before a plan for substantial work.
2. Do not execute outside approved file scope.
3. Do not claim completion without verification.
4. Do not hide failed commands.
5. Record evidence under `.harness/evidence/`.
6. Record verification under `.harness/verification/`.
7. If business logic is unknown, mark it unknown instead of guessing.

## Risk Areas

- No product migrations, auth, billing, production data, deployment code, or package-management workflow is visible in this sandbox repo.
- Unknown in this sandbox repo: target product architecture, target verification commands, and any repo-specific business logic outside this scaffold.
- Claude Code hooks can block tool use or stop completion if evidence and verification expectations are not met.
- `.before-dmc` backup artifacts are present and should not be treated as active runtime files unless intentionally restored.
- macOS `.DS_Store` files were tracked previously; `.gitignore` now contains `.DS_Store` and `**/.DS_Store`.

## Unknowns

- Unknown in this sandbox repo: target product package manager.
- Unknown in this sandbox repo: target product lint, typecheck, test, and build commands.
- Unknown in this sandbox repo: target product architecture and business logic.
