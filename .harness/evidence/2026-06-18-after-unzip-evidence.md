# Evidence: Codex Prompt After Unzip

Date: 2026-06-18

Accepted File Scope:
- `AGENTS.md`
- `DMC.md`
- `.harness/evidence/2026-06-18-after-unzip-evidence.md`
- `.harness/verification/2026-06-18-after-unzip-verification.md`

Task Source:
- `_DMC_CODEX_PROMPT_AFTER_UNZIP.md`

Observed File Tree:
- `.claude/settings.json`
- `.claude/agents/explorer.md`
- `.claude/agents/executor.md`
- `.claude/agents/verifier.md`
- `.claude/agents/critic.md`
- `.claude/agents/planner.md`
- `.claude/hooks/stop-verify-gate.sh`
- `.claude/hooks/evidence-log.sh`
- `.claude/hooks/scope-guard.sh`
- `.claude/hooks/pre-tool-guard.sh`
- `.claude/skills/dmc-init-deep/SKILL.md`
- `.claude/skills/dmc-ultrawork/SKILL.md`
- `.claude/skills/dmc-critic/SKILL.md`
- `.claude/skills/dmc-verify-hard/SKILL.md`
- `.claude/skills/dmc-start-work/SKILL.md`
- `.claude/skills/dmc-plan-hard/SKILL.md`
- `.harness/evidence/.gitkeep`
- `.harness/plans/.gitkeep`
- `.harness/runs/.gitkeep`
- `.harness/verification/.gitkeep`
- `.harness/schemas/plan.schema.md`
- `.harness/schemas/run.schema.md`
- `.harness/schemas/verification.schema.md`
- `DMC.md`
- `PLAN_SCHEMA.md`
- `RUN_SCHEMA.md`
- `VERIFICATION_SCHEMA.md`

Commands Run:
- `pwd`
- `ls`
- `sed -n '1,260p' _DMC_CODEX_PROMPT_AFTER_UNZIP.md`
- `git status --short`
- `ls -la`
- `find . -maxdepth 3 -print`
- `rg --files --hidden`
- `sed -n '1,260p' AGENTS.md`
- `sed -n '1,260p' DMC.md`
- `sed -n '1,260p' CLAUDE.md`
- `find . -maxdepth 4 -name package.json -print`
- `find . -maxdepth 4 -name package-lock.json -print`
- `find . -maxdepth 4 -name pnpm-lock.yaml -print`
- `find . -maxdepth 4 -name yarn.lock -print`
- `find . -maxdepth 4 -name pyproject.toml -print`
- `find . -maxdepth 4 -name Cargo.toml -print`
- `find . -maxdepth 4 -name Makefile -print`
- `find . -maxdepth 4 -type f -path './.github/workflows/*' -print`
- `sed -n '1,220p' .claude/settings.json`
- `bash -n .claude/hooks/*.sh`
- `command -v shellcheck`
- `git diff --stat`
- `sed -n '1,260p' AGENTS.md`
- `sed -n '1,260p' DMC.md`
- `sed -n '1,260p' .harness/evidence/2026-06-18-after-unzip-evidence.md`
- `sed -n '1,220p' .harness/verification/2026-06-18-after-unzip-verification.md`

Failures:
- `omo sparkshell ...` commands failed because this environment's `omo` binary does not expose a `sparkshell` command.
- `git status --short` failed because `/Users/woojinlee/Documents/projects/DMC` is not a git repository.
- `command -v shellcheck` returned no path, so `shellcheck` was not run.
- `git diff --stat` failed because `/Users/woojinlee/Documents/projects/DMC` is not a git repository.

Git Diff Stat:
- unavailable; `git diff --stat` returned "Not a git repository."

Changes Made:
- Replaced `AGENTS.md` placeholders with observed scaffold facts.
- Added scaffold-local verification examples to `DMC.md`.
- Added evidence and verification records under `.harness/`.

Next Claude Code Test Prompt:

```text
/dmc-ultrawork Inspect this repository, confirm the Do-Me-Coding scaffold is wired correctly, run the available verification checks, and write evidence under .harness/.
```

## Rerun After Git Initialization

Date: 2026-06-18

Scope:
- No unzip performed.
- No scaffold files overwritten.
- Only `.harness` evidence and verification logs were updated.

Commands Run:
- `bash -n .claude/hooks/*.sh`
- `find . -maxdepth 3 -print`
- `rg TODO AGENTS.md DMC.md`
- `git status --short`
- `git diff --stat`
- `git ls-files .harness/evidence .harness/verification`
- `sed -n '1,260p' .harness/evidence/2026-06-18-after-unzip-evidence.md`
- `sed -n '1,260p' .harness/verification/2026-06-18-after-unzip-verification.md`
- `sed -n '1,220p' AGENTS.md`

Results:
- `bash -n .claude/hooks/*.sh`: passed.
- `find . -maxdepth 3 -print`: passed.
- `rg TODO AGENTS.md DMC.md`: failed the TODO check; `AGENTS.md` still contains scaffold placeholders.
- `git status --short`: passed with no output before this log update.
- `git diff --stat`: passed with no output before this log update.

Failure Details:
- `AGENTS.md` contains TODO placeholders for repo overview, package manager, verification commands, architecture landmarks, and risk areas.

Runtime Readiness:
- Not ready for Claude Code runtime testing until the `AGENTS.md` placeholders are resolved or explicitly accepted as intentionally pending.

## Initialization Placeholder Resolution

Date: 2026-06-18

Scope:
- Removed tracked macOS metadata files from the repository with commit `62c2937`.
- Updated `AGENTS.md` initialization placeholders with facts visible in this sandbox repo.
- Confirmed `.gitignore` contains `.DS_Store` and `**/.DS_Store`; no duplicate entries were added.
- No unzip performed.
- No product source code modified.
- No scaffold runtime files overwritten.

Commands Run:
- `git status --short`
- `git ls-files '*DS_Store'`
- `find . -name .DS_Store -print`
- `sed -n '1,220p' .gitignore`
- `sed -n '1,240p' AGENTS.md`
- `sed -n '1,260p' DMC.md`
- `rg --files --hidden`
- `find . -maxdepth 4 -name package.json -print`
- `find . -maxdepth 4 -name pyproject.toml -print`
- `find . -maxdepth 4 -name Cargo.toml -print`
- `find . -maxdepth 4 -name Makefile -print`
- `find . -maxdepth 4 -type f -path './.github/workflows/*' -print`
- `git add -u -- .DS_Store .claude.before-dmc/.DS_Store .claude.before-dmc/skills/.DS_Store .claude/.DS_Store .claude/skills/.DS_Store .harness.before-dmc/.DS_Store .harness/.DS_Store`
- `git diff --cached --name-status`
- `git commit -m "Remove tracked macOS metadata"`
- `git branch --show-current`
- `git log -1 --oneline`
- `bash -n .claude/hooks/*.sh`
- `rg TODO AGENTS.md DMC.md`
- `find . -name .DS_Store -print -delete`

Results:
- Tracked `.DS_Store` files were removed in commit `62c2937 Remove tracked macOS metadata`.
- `AGENTS.md` no longer contains TODO placeholders.
- Hook syntax check passed.
- `rg TODO AGENTS.md DMC.md` returned no matches.
- `.gitignore` contains `.DS_Store` and `**/.DS_Store`.

Notes:
- `find . -name .DS_Store -print -delete` deleted ignored `.DS_Store` files outside `.git/`.
- Deleting `.git/.DS_Store` and `.git/logs/.DS_Store` failed with "Operation not permitted" because this sandbox grants read-only access to `.git/`; these files are not repository content and do not appear in git status or git diff.
