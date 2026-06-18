# Do-Me-Coding — Host Install Manifest (v0.1.3)

Single source of truth for what `dmc-install.sh` copies/merges into a HOST repository.
Every doc referenced by an installed file MUST be listed here (no dangling references after install).

## COPY (verbatim into host repo)

### Hooks → `.claude/hooks/`
- `pre-tool-guard.sh`
- `scope-guard.sh`
- `stop-verify-gate.sh`
- `evidence-log.sh`
- `dmc-router.sh`
- `secret-guard.sh`   # v0.1.3 — Read/Grep/Glob secret guard
- `worker-context-guard.sh`   # v0.2 — Worker Bridge task-bundle secret/forbidden guard (fail-closed)
- `worker-result-check.py`    # v0.2 — Worker result validator (import/review checks)
- `lib/secret-paths.sh`       # v0.2 — shared is_secret_path detector (md5-identical to secret-guard.sh)

### Skills → `.claude/skills/`
- `dmc-critic/SKILL.md`
- `dmc-init-deep/SKILL.md`
- `dmc-on/SKILL.md`
- `dmc-off/SKILL.md`
- `dmc-plan-hard/SKILL.md`
- `dmc-start-work/SKILL.md`
- `dmc-status/SKILL.md`
- `dmc-ultrawork/SKILL.md`
- `dmc-verify-hard/SKILL.md`
- `dmc-worker-plan/SKILL.md`     # v0.2 Worker Bridge
- `dmc-worker-dispatch/SKILL.md`
- `dmc-worker-import/SKILL.md`
- `dmc-worker-review/SKILL.md`
- `dmc-worker-status/SKILL.md`
- `dmc-worker-cancel/SKILL.md`

### Agents → `.claude/agents/`
- `critic.md`, `executor.md`, `explorer.md`, `planner.md`, `verifier.md`

### Provider adapters → `.claude/workers/providers/`   # v0.2.1 Worker Bridge live providers
- `glm-api/glm-api-adapter.py`, `glm-api/README.md`, `glm-api/CONFIG.md`, `glm-api/fixtures/*.json`
  (mock-first; `--live` is multi-gated and unexercised by build/CI; reads `GLM_API_KEY` from env only)

### Harness skeleton → `.harness/`
- `decisions/.gitkeep`, `evidence/.gitkeep`, `memory/.gitkeep`, `plans/.gitkeep`, `runs/.gitkeep`, `verification/.gitkeep`
- `workers/tasks/.gitkeep`, `workers/results/.gitkeep`, `workers/reviews/.gitkeep`, `workers/sessions/.gitkeep`   # v0.2 Worker Bridge (artifacts local-only in host)
- `schemas/plan.schema.md`, `schemas/run.schema.md`, `schemas/verification.schema.md`
- `mode`  # written by installer: `passive` if another harness detected, else `active` (Resolved Decision #5)

### Root operating docs / schemas
- `DMC.md`
- `PLAN_SCHEMA.md`, `RUN_SCHEMA.md`, `VERIFICATION_SCHEMA.md`
- `WORKER_TASK_SCHEMA.md`, `WORKER_RESULT_SCHEMA.md`, `WORKER_REVIEW_SCHEMA.md`   # v0.2 Worker Bridge
- `CLAUDE.md`   # MERGE/append if host has one (collision-detected), never blind-overwrite

### Referenced support docs (MUST be bundled — fixes dangling references)
- `docs/OMC_COEXISTENCE.md`            # referenced by DMC.md, CLAUDE.md, .claude/skills/dmc-off/SKILL.md
- `docs/HOST_REPO_ARTIFACT_POLICY.md`  # referenced by DMC.md
- `docs/HOST_REPO_ADAPTATION_POLICY.md`# referenced by DMC.md

## MERGE (never overwrite; collision-detected)
- `.claude/settings.json` — merge DMC hook arrays into any existing host file
- `.gitignore` — append the DMC block (see below)
- `CLAUDE.md` — append a DMC section if the host already has one

## DELIBERATELY NOT COPIED
- `AGENTS.md` — DMC's describes the DMC repo; would misdescribe a host (Resolved Decision: HOST_REPO_ADAPTATION_POLICY). Generate host-specific via `/dmc-init-deep` if wanted.
- DMC project knowledge docs: `docs/NOTION_EXPORT_SUMMARY.md`, `docs/SOURCE_URLS.md`, `docs/COMPETITIVE_GAP_LEDGER.md`, `docs/DMC_REAL_REPO_PILOT_REPORT.md`, `INSTALL_MANIFEST.md`, `_DMC_*.md`  (note: `docs/HOST_REPO_*.md` ARE bundled — they are referenced by installed `DMC.md`)
- DMC working artifacts: `.harness/plans/*`, `.harness/evidence/*`, `.harness/verification/*`, `.harness/decisions/*`, `.harness/memory/*` (host gets an empty skeleton only)
- `.claude/install/*` (the installer scripts themselves)

## `.gitignore` block appended to the host (Resolved Decision #2 — host artifacts local-only)
```
# Do-Me-Coding transient + working state (host repo: local-only by default)
.harness/mode
.harness/runs/current-*
.harness/evidence/manual-*.md
.harness/plans/
.harness/evidence/
.harness/verification/
.harness/runs/
# Worker Bridge artifacts (host: local-only by default; commit opt-in)
.harness/workers/tasks/
.harness/workers/results/
.harness/workers/reviews/
.harness/workers/sessions/
.harness/workers/providers/
# Do-Me-Coding: keep secret files out of search/commit (defense-in-depth)
.env
.env.*
!.env.example
!.env.sample
```
(Committing host `.harness` working artifacts is opt-in; teams may un-ignore specific records.)

## Dangling-reference rule
After a (dry-run) install, every `*.md` path referenced by an installed file must resolve to a
bundled file. `docs/OMC_COEXISTENCE.md` is the only such referenced support doc and IS bundled.
Any unresolved reference is a FAIL.
