# AGENTS.md — Project Memory for Do-Me-Coding

This file is the cross-agent project memory root. It is intentionally concise.

## Repo Overview

This directory is the Do-Me-Coding v0.1 scaffold root. It contains a
Claude Code-first execution harness, not a product application.

Primary contents:
- Claude Code skills, subagents, hooks, and settings under `.claude/`.
- Harness state directories under `.harness/`.
- Operating docs and schemas at the repo root.
- Import/reference docs under `docs/`.

## Package Manager

No package manager is detected in this unpacked scaffold. No `package.json`,
lockfile, `pyproject.toml`, `Cargo.toml`, `Makefile`, or CI workflow was found.

## Verification Commands

- lint: `shellcheck .claude/hooks/*.sh` if `shellcheck` is installed
- typecheck: not applicable; no typed source project detected
- test: `bash -n .claude/hooks/*.sh`
- build: not applicable; no build system detected

## Architecture Landmarks

- `.claude/skills/`: Claude Code slash-command skill definitions.
- `.claude/agents/`: planner, explorer, executor, verifier, and critic subagent prompts.
- `.claude/hooks/`: pre-tool, scope guard, evidence log, and stop verification hooks.
- `.claude/settings.json`: Claude Code hook wiring.
- `.harness/evidence/`: evidence logs for completed work.
- `.harness/verification/`: verification reports.
- `.harness/plans/`, `.harness/runs/`, `.harness/decisions/`, `.harness/memory/`: workflow state directories.
- `PLAN_SCHEMA.md`, `RUN_SCHEMA.md`, `VERIFICATION_SCHEMA.md`: root schema references mirrored under `.harness/schemas/`.

## Do-Me-Coding Operating Rules

1. Do not edit before a plan for substantial work.
2. Do not execute outside approved file scope.
3. Do not claim completion without verification.
4. Do not hide failed commands.
5. Record evidence under `.harness/evidence/`.
6. Record verification under `.harness/verification/`.
7. If business logic is unknown, mark it unknown instead of guessing.

## Risk Areas

- No product migrations, auth, billing, production data, or deployment code is present in this scaffold.
- The directory is not currently a git repository, so git status and diff commands are unavailable until imported into a target repo.
- Importing into a real repo can create merge risk for pre-existing `AGENTS.md`, `CLAUDE.md`, `.claude/`, or `.harness/` content.
- Claude hooks can block or require evidence for tool use; keep them useful but avoid brittle project-specific assumptions.
- Package-management risks are target-repo specific because no package manager is present here.

## Unknowns

- Target repository product architecture is unknown because this directory is only the scaffold package.
- Target repository package manager and verification commands are unknown until the scaffold is imported there.
- Target repository repo-specific `AGENTS.md` or `CLAUDE.md` knowledge is unknown.
