# Verification Report

## Run ID

dmc-v0.1.1-mode-switch

## Plan

.harness/plans/dmc-v0.1.1-mode-switch-router.md (APPROVED 2026-06-18, Approver: 대표님)

## Changed Files

- .claude/hooks/pre-tool-guard.sh: mode gate + 3-tier policy (active=deny+ask, passive=full deny no ask, off=catastrophic+secret deny only)
- .claude/hooks/scope-guard.sh: mode gate; enforce active only, pass-through passive/off
- .claude/hooks/stop-verify-gate.sh: mode gate; enforce active only
- .claude/hooks/evidence-log.sh: mode gate; log active only
- .claude/hooks/dmc-router.sh: NEW — UserPromptSubmit natural-trigger router (suffix-only/exact, precedence dmc-off>dmc-plan>dmc, env-var parse, writes .harness/mode on dmc/dmc-off, run-in-progress warning)
- .claude/settings.json: NEW UserPromptSubmit → dmc-router.sh (PreToolUse/PostToolUse/Stop unchanged)
- .claude/skills/dmc-on/SKILL.md, dmc-off/SKILL.md, dmc-status/SKILL.md: NEW mode-control skills
- .harness/mode: NEW (gitignored), default `active`
- .gitignore: added `.harness/mode`
- docs/OMC_COEXISTENCE.md: NEW coexistence guidance (modes, natural activation, worktree/branch separation, run-in-progress warning, hook audit, no assumed OMC off switch)
- DMC.md: Modes & Natural Activation section + activation examples
- CLAUDE.md: Mode & Natural Activation Routing rules

Existing six `/dmc-*` skills: UNCHANGED (git confirmed).

## Commands Run

| Command | Result | Reason | Output Summary |
|---|---|---|---|
| `bash .harness/evidence/v011-verify.sh` | PASS | full mode-matrix + router + regression harness | 38 PASS / 1 FAIL where the single FAIL was a harness-script false-negative (ls-based skill presence), corrected below |
| `bash -n` all 5 hooks | PASS | syntax | all OK |
| mode-gate md5 across 4 hooks | PASS | no drift (AC10) | unique count = 1 |
| active: rm-rf→deny, npm→ask, ls→0, scope out→deny/in→0, stop→block, evidence→body | PASS | v0.1 regression unchanged (AC5) | identical to v0.1 |
| passive: rm-rf→deny, `cat .env`→deny, npm→0 (no ask), scope/stop→0, evidence→no file | PASS | deny tier kept, ask + gates down (AC6) | as designed |
| off: rm-rf→deny, push --force→deny, `cat .env`→deny, npm→0, git reset --hard→0 | PASS | catastrophic+secret only; Block B stands down (AC7) | as designed |
| router: `…dmc`→ultrawork, `…dmc-plan`→planning, normal→0, mid-sentence `dmc-off`→0, env-var parse present | PASS | suffix/precedence/negative/no-regression (AC1/AC2) | correct |
| router-write independence: `x dmc`→active, `x dmc-off`→off, `x dmc-plan`→unchanged, normal→no write; dmc-off warns on active run | PASS | mode write reliable, independent of advisory routing | correct |
| settings.json valid JSON + router wired | PASS | additive + valid (AC9) | UserPromptSubmit added; other events intact |
| `git status` existing six skills | PASS | existing commands unbroken (AC9) | unchanged |
| `git check-ignore .harness/mode` ; `.omc/x` | PASS | transient/OMC state ignored (AC11) | both ignored |

## Manual Checks

| Check | Result | Notes |
|---|---|---|
| Live secret-exposure deny works | PASS | During this run the live pre-tool-guard blocked a check command containing `cat .env` — direct proof the secret deny enforces. |
| Changed-file set matches approved scope (14 files) | PASS | Only the planned files changed; no out-of-scope edits. |
| Harness false-negative reconciled | PASS | The `ls -d` skill-presence line mis-counted; replaced with `test -f` (6/6) and `git status` (unchanged) — both pass. |
| Existing six `/dmc-*` skills unmodified | PASS | `git status --short` over the six → empty. |

## Scope Review

Result: PASS

Notes: Approved scope = the 14 files in `.harness/runs/current-scope.txt`. All edits landed inside scope; verification artifacts under `.harness/evidence|verification` (internal allow-list). No product/scaffold file outside scope was modified; existing six skills untouched.

## Package / Env / Migration Review

Package files changed: no
Env files changed: no
Migration files changed: no

Notes: Shell-hook + skill-prompt + docs + gitignore changes only. The router writes `.harness/mode` (gitignored local switch) on exact triggers; the mode-gate adds a single small file read per hook invocation. No dependency/schema/config-system change. `pre-tool-guard` deny-tier coverage in `off` is intentionally reduced (catastrophic + secret only) per Resolved Decision #3; `active` (default) is unchanged from v0.1.

## Unresolved Risks

- Router routing output is `additionalContext` (advisory instruction) — acting on it depends on the model following the injected instruction; the `.harness/mode` write is reliable (tested independently). Documented in the plan's instruction-injector caveat.
- `off` mode intentionally lets damaging-but-not-catastrophic commands (e.g. `git reset --hard`, `DELETE FROM`) through; this is the approved reduced guarantee, mitigated by default-absent = `active`.
- Duplicated mode-gate across 4 hooks (md5-guarded) and a duplicated `json_get` in the router — future shared-helper refactor optional.

## Final Status

PASS
