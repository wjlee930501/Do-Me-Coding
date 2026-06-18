# Do-Me-Coding v0.1.1 — Natural Activation & OMC Coexistence Mode

## Goal

Make Do-Me-Coding activate naturally like LazyCodex `ulw`: a natural-language request that
**ends with `dmc`** routes into DMC ultrawork behavior; **ends with `dmc-plan`** routes into
planning-only; and a request **containing `dmc-off`** turns DMC off. Add a `.harness/mode`
switch (`active` | `passive` | `off`), mode-aware hooks, `/dmc-on` `/dmc-off` `/dmc-status`
skills, and OMC coexistence guidance (separate branch/worktree, run-in-progress warning) — all
without breaking existing `/dmc-*` commands or removing current protections, and without
assuming OMC has a global off switch.

## User Intent

feature

## Resolved Decisions

These were open design choices; now settled (input from the maintainer, pre-critic):

1. **`.harness/mode` is gitignored, not committed.** It is transient/local switch state (same class as run state). Default-when-absent = `active`, preserving v0.1 protections on clean clones.
2. **The router may write `.harness/mode` — for explicit trigger tokens only.** The shell hook writes the file directly (a reliable side effect) only when an exact trigger suffix matches; it never writes on non-trigger prompts.
3. **`off` mode is catastrophic-deny-only, and secret exposure counts as catastrophic — NOT fully inert.** `off` is "non-interfering except catastrophic/security-deny": a minimal block remains while everything else passes through. The retained off-mode deny set is:
   - **Destructive:** `rm -rf /|~|*|.`, `sudo rm -rf`, `git push --force`, `terraform destroy`, `kubectl delete`, `DROP DATABASE`/`TRUNCATE TABLE`, `prisma migrate reset`, `rails db:drop`, `python manage.py flush`.
   - **Secret exposure (treated as catastrophic):** `cat .env` (and `cat *.env`), `cat ~/.ssh`, `cat ~/.aws`, `printenv`, and similarly obvious secret-read commands.
   Everything outside this set (e.g. `npm install`, normal edits, scope/stop/evidence flow) passes through untouched in `off`.

## Critic-Facing Requirements

The critic must hold this plan to the following, in addition to the schema sections:

- **Router is an instruction injector, not a guaranteed executor.** Treat the router's routing output (`additionalContext` telling Claude to invoke `/dmc-ultrawork` or `/dmc-plan-hard`) as an *instruction the model is asked to follow* — NOT a guaranteed slash-command execution — unless `UserPromptSubmit` command execution / additionalContext behavior is explicitly verified in this Claude Code build. The router's own file writes (`.harness/mode`) run in the hook shell and are reliable; the *routing* is advisory until verified. Implementation and acceptance tests must distinguish these two.
- **Trigger precedence (exactly):** 1) `dmc-off`  2) `dmc-plan`  3) `dmc`. Evaluate in this order and stop at the first match.
- **Trigger matching is suffix-only and exact.** A trigger fires ONLY when the trimmed prompt *ends with* the exact standalone token (preceded by start-of-string or whitespace, followed only by optional trailing whitespace). No substring/"contains" matching — `dmc-off` must also be suffix-matched. This avoids accidental activation from prose that merely mentions the token mid-sentence (e.g. "the dmc-off switch is documented …" must NOT trigger).
- **v0.1 active-mode behavior must remain byte-for-byte unchanged and be regression-tested.** `active` (and absent mode file) must reproduce today's hook decisions exactly; the verification suite must include a full v0.1 regression in active mode.
- **OMC coexistence risk is real and observed.** During this very planning session, OMC ultrawork *re-armed* via its own `UserPromptSubmit` magic-keyword injection and a Stop hook fired repeatedly. The plan must treat dual-`UserPromptSubmit` coexistence as a first-class risk, not hypothetical.
- **Include worktree/branch separation guidance** for running OMC experiments isolated from DMC (so the two harnesses do not contend in one working tree).
- **`/oh-my-claudecode:cancel` is an OPTIONAL cleanup command** to mention only when the OMC plugin is present (it cleanly exits OMC modes like ultrawork). Do NOT assume OMC has a universal off switch; DMC steps aside via its own `.harness/mode` regardless of OMC.

## Current Repo Findings

- Finding: `.claude/settings.json` wires only `PreToolUse`, `PostToolUse`, `Stop`. No `UserPromptSubmit` hook — a natural-trigger router is purely additive there.
  Source: `python3 -c 'import json;print(list(json.load(open(".claude/settings.json"))["hooks"].keys()))'`.
- Finding: All four hooks share an identical head (`#!/usr/bin/env bash` / `set -u` / `INPUT="$(cat)"`); a mode gate can be inserted uniformly right after `set -u`.
  Source: `sed -n '1,4p' .claude/hooks/*.sh`.
- Finding: The shared `json_get` helper is fixed (env-var form `DMC_HOOK_INPUT="$INPUT" python3`). Any new router reading the prompt MUST use this form, not the old heredoc-on-stdin form.
  Source: committed fix `2458afc` (`57e1bcd` on main).
- Finding: Six skills must keep working unchanged: dmc-critic, dmc-init-deep, dmc-plan-hard, dmc-start-work, dmc-ultrawork, dmc-verify-hard.
  Source: `ls .claude/skills/`.
- Finding: `pre-tool-guard.sh` already separates a `deny` tier (rm -rf, high-risk destructive, secret reads, DB-destructive) from an `ask` tier (package/migration/publish) — a natural basis for per-mode tiering.
  Source: `.claude/hooks/pre-tool-guard.sh` lines 60-78.
- Finding: `.gitignore` already ignores `.harness/runs/current-*`, `.harness/evidence/manual-*.md`, `.omc/`. The mode file should follow the same transient-state-ignored pattern.
  Source: `cat .gitignore`.
- Finding: OMC integrates through the same surfaces (its own skills, `UserPromptSubmit` magic-keyword injection — observed `[MAGIC KEYWORD: ULTRAWORK]` this session, PreToolUse advisories, `.omc/` state) and exposes only `DISABLE_OMC` / `OMC_SKIP_HOOKS` env vars — no universal off switch.
  Source: user global CLAUDE.md; observed UserPromptSubmit injection this session.
- Finding: DMC run state lives at `.harness/runs/current-run-id` / `current-scope.txt`; their presence means a DMC run is in progress (relevant to the OMC coexistence warning).
  Source: `.claude/hooks/{scope-guard,stop-verify-gate}.sh`.

## Relevant Files

| Path | Reason | Allowed to Edit (future approved run) |
|---|---|---|
| `.claude/hooks/pre-tool-guard.sh` | 3-tier mode policy (active=deny+ask, passive=deny, off=catastrophic-only) | yes |
| `.claude/hooks/scope-guard.sh` | mode gate: enforce active; pass-through passive/off | yes |
| `.claude/hooks/stop-verify-gate.sh` | mode gate: enforce active; pass-through passive/off | yes |
| `.claude/hooks/evidence-log.sh` | mode gate: log active; no-op passive/off | yes |
| `.claude/hooks/dmc-router.sh` | NEW — UserPromptSubmit natural-trigger router (suffix `dmc`/`dmc-plan`, contains `dmc-off`) | yes (new) |
| `.claude/settings.json` | add `UserPromptSubmit` → dmc-router.sh (additive) | yes |
| `.claude/skills/dmc-on/SKILL.md` | NEW — set mode active (or `passive`) | yes (new) |
| `.claude/skills/dmc-off/SKILL.md` | NEW — set mode off + run-in-progress warning | yes (new) |
| `.claude/skills/dmc-status/SKILL.md` | NEW — report mode + active-run state | yes (new) |
| `.harness/mode` | NEW — single line `active`/`passive`/`off` (gitignored, transient) | yes (new) |
| `.gitignore` | add `.harness/mode` | yes |
| `docs/OMC_COEXISTENCE.md` | NEW — coexistence + branch/worktree guidance + run-in-progress warning | yes (new) |
| `DMC.md` | activation examples (`<task> dmc`, `<task> dmc-plan`, `dmc-off`) + mode model | yes |
| `CLAUDE.md` | routing rules + mode model | yes |
| `.claude/skills/*/SKILL.md` (existing 6) | read-only — must keep working | no |

## Out of Scope

- Implementing anything now (plan only).
- Modifying/disabling OMC, its skills, hooks, or `.omc/`; assuming an OMC global off switch.
- Weakening protections in `active` (default) mode.
- Changing the six existing `/dmc-*` skills.
- Standalone CLI / model router / web/mobile UI / MCP server.

## Proposed Changes

### A. Natural-trigger router (Feature 1) — `.claude/hooks/dmc-router.sh` + settings wiring

New `UserPromptSubmit` hook. Reads `prompt` via the FIXED env-var JSON parse, trims trailing whitespace, and matches **suffix-only and exact** in this fixed precedence (stop at first match):

1. Trimmed prompt ends with the exact token `dmc-off` (`(^|[[:space:]])dmc-off[[:space:]]*$`) → write `off` to `.harness/mode`; emit additionalContext confirming DMC is off; **if `.harness/runs/current-*` exists, warn** that a DMC run is in progress. (Suffix-only — prose merely mentioning `dmc-off` mid-sentence must NOT trigger.)
2. Else trimmed prompt ends with ` dmc-plan` (`(^|[[:space:]])dmc-plan[[:space:]]*$`) → emit additionalContext: route to `/dmc-plan-hard` with the task = prompt minus the trailing token. (Mode left unchanged — planning is read-only.)
3. Else trimmed prompt ends with ` dmc` (`(^|[[:space:]])dmc[[:space:]]*$`) → write `active` to `.harness/mode`; emit additionalContext: route to `/dmc-ultrawork` with task = prompt minus the trailing token.
4. Else exit 0 (pass-through; never touches OMC's own UserPromptSubmit injection).

Notes:
- **Precedence (fixed): 1) `dmc-off`  2) `dmc-plan`  3) `dmc`** — evaluate in this order, stop at first match (so "… dmc-plan" never mis-routes to ultrawork, and "… dmc-off" never matches the bare `dmc`).
- **Matching is suffix-only and exact** (standalone token at end of trimmed prompt); no substring matching, to prevent accidental activation.
- The router is **mode-independent** (it is the activation surface, so it must work even when mode is `off`). It only ever emits/writes on these explicit trigger suffixes.
- **Instruction-injector caveat:** the *routing* output is `additionalContext` — an instruction the model is asked to follow, NOT a guaranteed slash-command execution. Treat it as advisory unless `UserPromptSubmit` additionalContext/command-execution behavior is explicitly verified in this Claude Code build. The router's `.harness/mode` writes run in the hook shell and ARE reliable; keep the two concerns separate in implementation and tests. Output shape: `{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"…"}}`.
- Rationale for the router writing `.harness/mode` (Resolved Decision #2): the LazyCodex-style goal requires "append `dmc` and it just works" — but only on exact trigger tokens.

### B. Mode-aware hooks (Feature 4) — shared mode gate + per-hook policy

Add an identical mode-gate block to the top of each of the four existing hooks (after `set -u`):
```bash
DMC_MODE_FILE="${CLAUDE_PROJECT_DIR:-$PWD}/.harness/mode"
DMC_MODE="active"   # default when absent → backward compatible; existing installs keep full protection
if [ -f "$DMC_MODE_FILE" ]; then
  DMC_MODE="$(head -n1 "$DMC_MODE_FILE" | tr -d '[:space:]' | tr 'A-Z' 'a-z')"
  case "$DMC_MODE" in active|passive|off) ;; *) DMC_MODE="active" ;; esac
fi
```
Per-hook policy:
- `pre-tool-guard.sh` (3 tiers): `active` = deny tier + ask tier (today's behavior). `passive` = full deny tier only (destructive AND secret-exposure denies remain; drop the `ask` prompts → less intrusive). `off` = catastrophic/security-deny subset only — the destructive set (`rm -rf /|~|*|.`, `sudo rm -rf`, `git push --force`, `terraform destroy`, `kubectl delete`, `DROP DATABASE`/`TRUNCATE TABLE`, `prisma migrate reset`, `rails db:drop`, `python manage.py flush`) **plus the secret-exposure set** (`cat .env`/`cat *.env`, `cat ~/.ssh`, `cat ~/.aws`, `printenv`, similar secret reads); everything else passes through. `off` is "non-interfering except catastrophic/security-deny," NOT fully inert.
- `scope-guard.sh`: `active` enforce (deny out-of-scope); `passive`/`off` → exit 0 (pass-through).
- `stop-verify-gate.sh`: `active` enforce (block); `passive`/`off` → exit 0.
- `evidence-log.sh`: `active` log; `passive`/`off` → exit 0 (also removes manual-* clutter during OMC work).

Mode matrix:
| Hook | active | passive | off |
|---|---|---|---|
| pre-tool-guard | deny + ask | full deny (destructive + secret), no ask | catastrophic + secret-exposure deny only |
| scope-guard | enforce | pass-through | pass-through |
| stop-verify-gate | enforce | pass-through | pass-through |
| evidence-log | log | no-op | no-op |
| dmc-router | always evaluates triggers (mode-independent) |

### C. Mode state (Feature 2) — `.harness/mode`

Single line: `active` | `passive` | `off`. Gitignored (transient/local switch, like run state); absent → treated as `active`. Written by the router and by the on/off skills.

### D. Skills (Feature 3) — `/dmc-on`, `/dmc-off`, `/dmc-status`

- `/dmc-on [active|passive]` → write chosen mode (default `active`) to `.harness/mode`; echo result.
- `/dmc-off` → write `off`; **if `.harness/runs/current-*` exists, warn** about the in-progress run before switching.
- `/dmc-status` → print current mode (or "active (default, no mode file)") and whether a DMC run is active (`.harness/runs/current-run-id`), with a note to finish/cancel it before OMC work.
All three: `disable-model-invocation: true`, no destructive tools, single-write mechanism.

### E. OMC coexistence (Feature 5) — `docs/OMC_COEXISTENCE.md`

- `.omc/` stays gitignored (already true).
- DMC never disables OMC (no assumed global off switch) — it steps aside via `.harness/mode`.
- **Separation guidance:** run OMC experiments in a dedicated `git worktree` or separate branch so DMC and OMC don't contend in one working tree; example `git worktree add ../omc-experiments` flow.
- **Run-in-progress warning:** before OMC usage, if `.harness/runs/current-*` exists, warn (surfaced by `/dmc-status`, `/dmc-off`, and the router's `dmc-off` path).
- Hook coexistence audit: both DMC and OMC hooks fire on shared events; verify neither swallows the other's output and the DMC router only emits on its tokens.

### F. Documentation (Feature 6) — `DMC.md`, `CLAUDE.md`

- `DMC.md`: activation examples — `<task> dmc`, `<task> dmc-plan`, `dmc-off`; the active/passive/off model; `/dmc-on|off|status`.
- `CLAUDE.md`: routing rules (suffix precedence, mode behavior) + OMC coexistence pointer.

## Acceptance Criteria

- Criterion: Router routes by exact-suffix precedence (dmc-off > dmc-plan > dmc) and passes through otherwise.
  Verification Method: `printf '{"prompt":"fix the parser dmc"}' | dmc-router.sh` → additionalContext referencing `/dmc-ultrawork`; `"… dmc-plan"` → `/dmc-plan-hard`; `"… dmc-off"` (ends with token) → off + (warning if run active); `"normal request"` → 0 bytes; `"… dmc-plan"` never routes to ultrawork; **negative: `"the dmc-off switch is documented here"` (mid-sentence) → 0 bytes (no trigger)**.
- Criterion: Router uses the fixed env-var parse (no heredoc regression) and strips the trigger token from the routed task.
  Verification Method: `grep -q 'DMC_HOOK_INPUT="$INPUT" python3' .claude/hooks/dmc-router.sh`; routed task excludes the trailing `dmc`/`dmc-plan`.
- Criterion: `dmc` suffix sets `.harness/mode=active`; `dmc-off` sets `off`.
  Verification Method: run router on each; read `.harness/mode` in a temp project dir.
- Criterion: `.harness/mode` accepts only active|passive|off; garbage/absent → active.
  Verification Method: feed each value via temp `CLAUDE_PROJECT_DIR`; assert effective mode.
- Criterion: active (and absent) reproduces today's v0.1 hook behavior exactly.
  Verification Method: full v0.1 behavioral suite with mode=active and no mode file → identical results.
- Criterion: passive keeps destructive deny, drops `ask`, and makes scope/stop/evidence pass-through.
  Verification Method: temp harness: `rm -rf /`→deny; `npm install`→0 bytes (no ask); out-of-scope write→0 bytes; stop w/o verification→0 bytes; evidence→no file.
- Criterion: off blocks catastrophic AND secret-exposure commands only; everything else passes (NOT fully inert).
  Verification Method: temp harness (mode=off): `rm -rf /`→deny; `git push --force`→deny; **`cat .env`→deny** (secret-exposure retained); `printenv`→deny; `npm install`→0 bytes (pass-through); out-of-scope write→0 bytes; benign→0 bytes.
- Criterion: passive and off tiers stay distinct.
  Verification Method: mode=passive → `rm -rf /`→deny, `cat .env`→deny, `npm install`→0 bytes (deny tier kept, ask tier dropped). mode=off → same denies for catastrophic+secret, but `npm install`→0 bytes; off's deny set is the subset, passive keeps the full deny tier.
- Criterion: Router `.harness/mode` writes work independently of advisory `additionalContext` routing.
  Verification Method: in a temp `CLAUDE_PROJECT_DIR`, run the router on each prompt and read the written `.harness/mode` regardless of whether the routing context is acted on — `"<task> dmc"`→`active`; `"<task> dmc-plan"`→mode unchanged per policy (planning is read-only; leaves prior mode, default active); `"<task> dmc-off"`→`off`; `"normal prompt"`→no write (mode file unchanged/absent).
- Criterion: `/dmc-on|off|status` exist with valid frontmatter and set/report mode; `/dmc-off` and `/dmc-status` warn when `.harness/runs/current-*` exists.
  Verification Method: skills have `name:`+`description:`; following them sets/reads the file; warning text present when a temp `current-run-id` exists.
- Criterion: existing six `/dmc-*` skills unchanged; settings.json valid JSON with only an added UserPromptSubmit entry.
  Verification Method: `git diff --name-only` over the six → empty; `python3 -m json.tool`; diff shows only the added block.
- Criterion: mode-gate block byte-identical across the four hooks.
  Verification Method: extract gate block per hook; md5 unique count = 1.
- Criterion: `.harness/mode` gitignored; `.omc/` stays ignored.
  Verification Method: `git check-ignore .harness/mode` and `git check-ignore .omc/x` both match.
- Criterion: `docs/OMC_COEXISTENCE.md` includes worktree/branch separation + run-in-progress warning + audit sections.
  Verification Method: file present; heading grep.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Suffix matching mis-fires (e.g. a sentence legitimately ending in the word "dmc", or `dmc-plan` matching `dmc`) | medium | Word-boundary regex; check `dmc-plan` before `dmc`; require token at end with only trailing whitespace; document the convention; router only routes (reversible), never edits files. |
| Router writing `.harness/mode` is a side effect on matched prompts | medium | Only fires on explicit `dmc`/`dmc-off` tokens; mode is gitignored/transient; `/dmc-status` shows current mode; documented behavior. |
| `off` lets damaging-but-not-catastrophic commands through (reduced guarantee) | medium (by design) | Resolved Decision #3: off keeps BOTH catastrophic-destructive AND secret-exposure denies (secret leakage treated as catastrophic); only the lower-severity ask tier and workflow gates stand down. Default-absent stays `active` (full protection); off-mode reduced guarantee is documented in DMC.md/coexistence doc. |
| Default-absent = active surprises an OMC repo with enforcement | medium | Honors "don't remove protections"; coexistence doc instructs `dmc-off`/worktree before OMC work. |
| New UserPromptSubmit router collides with OMC's UserPromptSubmit injection | medium | Router exits 0 on non-trigger prompts (no output); coexistence audit verifies both fire. |
| Mode-gate edits accidentally change existing enforcement logic | high | Gate prepended only after `set -u`; re-run full v0.1 suite in active mode for identical results; md5-identity on gate block; do not touch json_get/json_string/argv block. |
| Router reintroduces heredoc-on-stdin parser bug | medium | Mandate env-var form; acceptance test asserts prompt parses under python3. |
| Duplicated gate/policy blocks drift across hooks | low | md5-identity acceptance check; note future shared-helper refactor (deferred to stay surgical). |
| DMC run left active when user switches to OMC | medium | Run-in-progress warning in `/dmc-off`, `/dmc-status`, and router `dmc-off` path; worktree separation guidance. |

## Assumptions

| Assumption | Confidence | How to Verify |
|---|---|---|
| Claude Code merges hook arrays so DMC + OMC hooks coexist on shared events | high | Observed OMC UserPromptSubmit injection alongside DMC hooks this session. |
| UserPromptSubmit additionalContext is the right routing mechanism | high | Mirrors OMC's own `[MAGIC KEYWORD: ULTRAWORK]` injection. |
| `.harness/mode` transient/gitignored, default active | RESOLVED | Resolved Decision #1 (gitignored, not committed). |
| Router may write `.harness/mode` on exact trigger tokens | RESOLVED | Resolved Decision #2 (writes only on exact suffix triggers). |
| off = catastrophic-deny-only | RESOLVED | Resolved Decision #3 (catastrophic-only, not fully inert). |
| Routing via additionalContext is advisory unless UserPromptSubmit execution verified | medium | Critic-Facing Requirement: treat router as instruction injector; verify build behavior. |
| No universal OMC off switch beyond env vars | high | User global config lists only `DISABLE_OMC`/`OMC_SKIP_HOOKS`. |

## Execution Tasks

- [ ] DMC-T001: Add the mode-gate block to the four hooks (identical, after `set -u`).
  Files: `.claude/hooks/{pre-tool-guard,scope-guard,stop-verify-gate,evidence-log}.sh`
  Notes: don't touch json_get/json_string/scope-guard argv block.
- [ ] DMC-T002: Implement the 3-tier policy in `pre-tool-guard.sh` (split deny tier into full vs catastrophic subset; gate `ask` tier to active only).
  Files: `.claude/hooks/pre-tool-guard.sh`
- [ ] DMC-T003: Create `.claude/hooks/dmc-router.sh` (env-var parse; suffix/contains precedence; writes mode for `dmc`/`dmc-off`; run-in-progress warning).
  Files: `.claude/hooks/dmc-router.sh`
- [ ] DMC-T004: Wire `UserPromptSubmit` → dmc-router.sh in `settings.json` (additive).
  Files: `.claude/settings.json`
- [ ] DMC-T005: Create `/dmc-on`, `/dmc-off`, `/dmc-status` skills (with run-in-progress warning in off/status).
  Files: `.claude/skills/dmc-on|dmc-off|dmc-status/SKILL.md`
- [ ] DMC-T006: Add `.harness/mode` default + `.gitignore` rule.
  Files: `.harness/mode`, `.gitignore`
- [ ] DMC-T007: Write `docs/OMC_COEXISTENCE.md` (worktree/branch separation, run-in-progress warning, audit); update `DMC.md` + `CLAUDE.md`.
  Files: `docs/OMC_COEXISTENCE.md`, `DMC.md`, `CLAUDE.md`
- [ ] DMC-T008: Verification — mode matrix + router + regression suite; write evidence + verification report.
  Files: `.harness/evidence/`, `.harness/verification/`

## Verification Commands

| Command | Reason | Required |
|---|---|---|
| `printf '{"prompt":"fix the parser dmc"}' \| .claude/hooks/dmc-router.sh \| grep -q dmc-ultrawork` | `dmc` suffix → ultrawork (AC1) | yes |
| `printf '{"prompt":"design the schema dmc-plan"}' \| .claude/hooks/dmc-router.sh \| grep -q dmc-plan-hard` | `dmc-plan` suffix → planning, not ultrawork (AC1) | yes |
| `printf '{"prompt":"stand down dmc-off"}' \| .claude/hooks/dmc-router.sh` then read temp `.harness/mode` → `off` | `dmc-off` exact suffix → off (AC1/AC3) | yes |
| `printf '{"prompt":"the dmc-off switch is documented here"}' \| .claude/hooks/dmc-router.sh \| wc -c` → 0 | mid-sentence mention must NOT trigger (suffix-only/exact) | yes |
| `printf '{"prompt":"just a normal request"}' \| .claude/hooks/dmc-router.sh \| wc -c` → 0 | pass-through (AC1) | yes |
| `grep -q 'DMC_HOOK_INPUT="$INPUT" python3' .claude/hooks/dmc-router.sh` | no parser regression (AC2) | yes |
| mode-matrix temp harness: active = today's suite; passive = full deny (destructive+secret), no ask, gates pass-through; off = catastrophic+secret deny only | mode policy (AC5/6/7) | yes |
| `printf '{"tool_input":{"command":"rm -rf /"}}' \| .claude/hooks/pre-tool-guard.sh` (mode=off) → deny | off blocks catastrophic-destructive (AC7) | yes |
| `printf '{"tool_input":{"command":"git push --force origin main"}}' \| .claude/hooks/pre-tool-guard.sh` (mode=off) → deny | off blocks catastrophic (AC7) | yes |
| `printf '{"tool_input":{"command":"cat .env"}}' \| .claude/hooks/pre-tool-guard.sh` (mode=off) → deny | off retains secret-exposure deny (AC7 / Decision #3) | yes |
| `printf '{"tool_input":{"command":"npm install"}}' \| .claude/hooks/pre-tool-guard.sh` (mode=off) → 0 bytes | off passes through non-catastrophic (AC7) | yes |
| `printf '{"tool_input":{"command":"cat .env"}}' \| .claude/hooks/pre-tool-guard.sh` (mode=passive) → deny ; `npm install` (mode=passive) → 0 bytes | passive keeps full deny tier, drops `ask` (AC6); distinct from off subset | yes |
| Router-write independence (temp `CLAUDE_PROJECT_DIR`): `"x dmc"`→mode `active`; `"x dmc-off"`→mode `off`; `"x dmc-plan"`→mode unchanged (default active); `"normal"`→no write | mode write works independent of advisory routing (AC: router-write) | yes |
| `/dmc-status` with temp `.harness/runs/current-run-id` present → warning text | run-in-progress warning (AC8) | yes |
| `git diff --name-only` over the six existing skills → empty | existing commands unbroken (AC9) | yes |
| `python3 -m json.tool .claude/settings.json` ; diff shows only added UserPromptSubmit | settings additive + valid (AC9) | yes |
| mode-gate block md5 across four hooks → unique count 1 | no gate drift (AC10) | yes |
| `git check-ignore .harness/mode` ; `git check-ignore .omc/x` | transient/OMC state ignored (AC11) | yes |
| `bash -n .claude/hooks/*.sh` | all hooks (incl. router) parse | yes |

## Rollback Path

### Pre-commit (changes not yet committed)
1. Restore the modified tracked files:
   ```bash
   git restore .claude/hooks/pre-tool-guard.sh .claude/hooks/scope-guard.sh \
               .claude/hooks/evidence-log.sh .claude/hooks/stop-verify-gate.sh \
               .claude/settings.json .gitignore DMC.md CLAUDE.md
   ```
2. Remove the newly added files:
   ```bash
   rm -f .claude/hooks/dmc-router.sh \
         .claude/skills/dmc-on/SKILL.md .claude/skills/dmc-off/SKILL.md .claude/skills/dmc-status/SKILL.md \
         docs/OMC_COEXISTENCE.md
   ```
   (Also remove the now-empty `.claude/skills/dmc-on|dmc-off|dmc-status/` directories.)
3. Remove or empty `.harness/mode` so behavior falls back to default `active`:
   ```bash
   rm -f .harness/mode
   ```

### Post-commit (v0.1.1 already committed)
1. Revert the v0.1.1 commit:
   ```bash
   git revert <v0.1.1-commit-sha>
   ```
2. Confirm DMC v0.1 `active`-mode behavior is fully restored by re-running the existing active-mode regression suite (the v0.1 behavioral checks: pre-tool-guard deny/ask/benign; scope in/out; stop block/pass; evidence body) — all must pass as on `main` before v0.1.1.

Notes: the four hook edits and `settings.json`/`.gitignore`/doc edits are reversible from git; the router, skills, coexistence doc, and `.harness/mode` are new (untracked until staged) and removable. Restoring default-active means protections return to the v0.1 baseline.

## Approval Status

Status: APPROVED
Approver: 대표님
Approved At: 2026-06-18
