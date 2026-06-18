# Verification Report

## Run ID

dmc-v0.1.3-hardening

## Plan

.harness/plans/dmc-v0.1.3-security-install-hardening.md (APPROVED 2026-06-19, Approver: 대표님)

## Changed Files

New:
- .claude/hooks/secret-guard.sh — PreToolUse Read|Grep|Glob secret guard (path-based deny; never opens files; all-mode floor)
- INSTALL_MANIFEST.md — host-install source of truth
- .claude/install/dmc-install.sh — manifest-driven installer (--dry-run, mode detection, collision detection, merge, rollback)
- .claude/install/dmc-uninstall.sh — reverses install
- docs/HOST_REPO_ARTIFACT_POLICY.md — host .harness artifacts local-only by default
- docs/HOST_REPO_ADAPTATION_POLICY.md — no blind AGENTS.md copy; merge/preserve host docs

Modified:
- .claude/settings.json — added PreToolUse matcher `Read|Grep|Glob` → secret-guard.sh (other events untouched)
- DMC.md — Secret Protection + Install & Host Adaptation sections
- CLAUDE.md — instruction-level secret-read deny (defense-in-depth)

Unchanged (verified): the four existing hooks (pre-tool-guard, scope-guard, stop-verify-gate, evidence-log), all skills.

## Commands Run

| Command | Result | Reason | Output Summary |
|---|---|---|---|
| claude-code-guide agent query (DMC-T001) | PASS | capability check | PreToolUse CAN match Read/Grep/Glob; deny works; settings reload immediate; Grep respects .gitignore, Glob does not |
| LIVE: Read tool on synthetic `.env.local` probe | PASS | empirical tool-level confirmation | DENIED in-session by secret-guard (settings reloaded live) |
| `bash .harness/evidence/dmc-v0.1.3-verify.sh` | PASS | full suite | 44 PASS / 0 FAIL (after fixing a dangling-ref regression — see Manual Checks) |
| `bash -n` all 6 hooks + 2 installers | PASS | syntax | all OK |
| secret-guard Read deny (12 secret paths) / allow (5 non-secrets) | PASS | boundary | denies `.env*`/keys/creds/ssh/aws; allows `.env.example`/`.env.sample`/`environment.ts`/`app.ts`/`README.md` |
| secret-guard Glob deny `**/.env*` / allow `src/**/*.ts` | PASS | glob guard | correct |
| secret-guard mode-independence (active/passive/off) | PASS | security floor | denies in all 3 modes |
| pre-tool-guard rm-rf/cat .env/npm/benign (active) | PASS | v0.1 regression | deny/deny/ask/0 — unchanged |
| 4 existing hooks `git diff` | PASS | no regression | byte-unchanged this run |
| settings.json valid + 3 PreToolUse matchers + secret-guard wired | PASS | additive | only the matcher added |
| installer real-install temp: clean→active, secret-guard installed, AGENTS.md absent, zero dangling refs, `.omc`→passive | PASS | install discipline + dangling-ref | all correct after fix |
| `grep glm/worker-bridge` in code | PASS | scope | none (only future-dependency mentions) |

## Manual Checks

| Check | Result | Notes |
|---|---|---|
| DMC-T001 tool-level interception (live) | PASS | Read of `.env.local` denied in-session — tool-level guard is functional, NOT just documented. Instruction-level layer kept for defense-in-depth (broad Grep). |
| Dangling-ref FAIL condition works | PASS | T006 DMC.md edit introduced refs to HOST_REPO_*.md; the verification's dangling-ref check FAILED, exposing it; fixed by bundling those 2 docs; re-verified zero dangling refs. (Fix-loop demonstrated.) |
| Secret boundary reads no secrets | PASS | All tests use synthetic paths; the guard decides by path only and never opens files. |
| Existing four hooks + skills unchanged | PASS | Only additive secret-guard + settings matcher + docs. |

## Scope Review

Result: PASS

Notes: Edits confined to the 9 approved-scope files (`.harness/runs/current-scope.txt`) + verification artifacts under `.harness/`. No pokeprice changes. No GLM/Worker Bridge code.

## Package / Env / Migration Review

Package files changed: no
Env files changed: no (and the new guard exists specifically to prevent secret-env reads; no secret contents accessed)
Migration files changed: no

Notes: Shell hook + installer + docs only. secret-guard is mode-independent (security floor). Installer is manifest-driven with dry-run/collision/rollback.

## Unresolved Risks

- Residual: a broad `Grep` with no `file_path` is not path-blockable; mitigated by Grep respecting `.gitignore` + the CLAUDE.md instruction-level deny (documented in the plan; non-blocking).
- Glob does not respect `.gitignore`; secret-guard blocks secret-targeting glob patterns to compensate.
- Worker Bridge / GLM remain out of scope (future v0.2 dependency), now unblocked by this hardening.

## Final Status

PASS
