# Codex Prompt After Unzip

Paste this into Codex after unzipping this scaffold into the target repository.

```text
You are reviewing and adapting the Do-Me-Coding v0.1 Claude Code Native Pack that has just been added to this repository.

Mission:
Make this scaffold fit the current repo without expanding scope.

Strict constraints:
1. Do not build an independent CLI.
2. Do not build a web app.
3. Do not implement model routing.
4. Do not copy OMO runtime.
5. Do not copy any Claude Fable leaked prompt text.
6. Do not modify product source code.
7. Do not install dependencies.
8. Preserve existing project structure.
9. Keep hooks useful but not brittle.
10. If CLAUDE.md or AGENTS.md already existed before this scaffold, preserve existing repo-specific knowledge and merge Do-Me-Coding rules instead of overwriting blindly.

Tasks:
1. Inspect the repo root.
2. Confirm the Do-Me-Coding file tree exists:
   - .claude/skills/*
   - .claude/agents/*
   - .claude/hooks/*
   - .claude/settings.json
   - .harness/*
   - DMC.md
   - PLAN_SCHEMA.md
   - RUN_SCHEMA.md
   - VERIFICATION_SCHEMA.md
3. Detect package manager and verification commands from package.json, pyproject.toml, Cargo.toml, Makefile, or CI config.
4. Update AGENTS.md placeholders with actual repo facts only.
5. Update DMC.md verification command examples if the repo has clear scripts.
6. Run shell syntax checks on .claude/hooks/*.sh:
   - bash -n .claude/hooks/*.sh
   - shellcheck .claude/hooks/*.sh if shellcheck is installed
7. Do not claim success unless checks were actually run.
8. Print:
   - file tree
   - changed files
   - commands run
   - failures
   - git diff --stat
   - next Claude Code test prompt

Completion rules:
- No verification, no done.
- No accepted file scope, no edit.
- No explicit acceptance criteria, no execution.
- No evidence log, no final completion claim.
```
