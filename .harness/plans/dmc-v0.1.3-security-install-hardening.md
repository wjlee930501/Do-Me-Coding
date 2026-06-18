# Do-Me-Coding v0.1.3 — Security & Install-Surface Hardening

## Goal

Harden DMC before any Worker Bridge / GLM work: (1) extend secret protection from Bash-only to
the Claude Code `Read`/`Grep` tools (or a documented policy fallback), (2) make the install
surface manifest-driven with no dangling doc references, (3) define a host-repo artifact policy,
(4) define a host-repo adaptation policy (no blind AGENTS.md copy), and (5) replace ad-hoc
copy/merge with a manifest-driven installer that has dry-run, collision detection, and rollback.
Derived from the v0.1.2 pilot ("PASS with follow-up gaps").

## User Intent

feature

## Resolved Decisions (pre-critic)

1. **Read/Grep/Glob guard expectation.** Preferred design: IF Claude Code `PreToolUse` can intercept `Read`/`Grep`/`Glob`, implement the **tool-level** secret guard; IF it cannot, fall back to **explicit policy/instruction-level deny rules + installer-generated guardrail docs**. Do NOT assume interception support until verified — the empirical verification (DMC-T001) stays the FIRST execution task and gates which path is built.
2. **Host `.harness` artifact policy.** In a HOST repo, default to **local-only / gitignored** for: `.harness/plans/`, `.harness/evidence/`, `.harness/verification/`, `.harness/runs/`, `.harness/mode`. Committing host `.harness` artifacts is **opt-in only**. The **DMC repo itself** may commit durable plans/evidence/verification (project knowledge); host repos do not by default. The installer adds these host `.gitignore` rules.
3. **Coexistence doc policy.** **Bundle `docs/OMC_COEXISTENCE.md`**; do NOT remove references. The installer / `INSTALL_MANIFEST.md` MUST copy referenced docs whenever an installed host doc references them. **Any dangling reference after install is a FAIL condition.**
4. **Secret-guard false-positive boundary.**
   - **Explicitly ALLOW** (not secrets): `.env.example`, `.env.sample`, and non-secret source files with env-like names (e.g. `environment.ts`) provided they do not contain secret values.
   - **Explicitly BLOCK**: `.env`, `.env.local`, `.env.prod.local`, `.env.production`, private keys, credential files, service-account JSON, and token/key/secret-bearing config files.
   - Tests MUST use synthetic paths and MUST NOT read real secret contents.
5. **Installer default mode.** If OMC/OMO/OMX or any existing agent harness is detected → default install mode **`passive`**. If no other harness is detected → default may be **`active`**. The installer MUST print the chosen mode + rationale, and the user MUST be able to override explicitly.

## Current Repo Findings

- Finding: Hook matchers are `PreToolUse: [Bash, Edit|Write]`, `PostToolUse: [Bash|Edit|Write]`, `UserPromptSubmit`, `Stop`. **No `Read`/`Grep`/`Glob` matcher** → `pre-tool-guard`'s secret deny only covers Bash; Read/Grep of `.env*` is unguarded.
  Source: `python3 -c '...settings.json hooks...'`.
- Finding: `docs/OMC_COEXISTENCE.md` is referenced by **three** installed files — `CLAUDE.md`, `DMC.md`, and `.claude/skills/dmc-off/SKILL.md` — but the v0.1.2 install did NOT copy `docs/` into the host repo → dangling references (broader than first noted).
  Source: `grep -rl 'OMC_COEXISTENCE.md' DMC.md CLAUDE.md .claude`.
- Finding: Install surface = 5 hooks, 9 skills, 5 agents, root `DMC.md`/`*SCHEMA.md`/`CLAUDE.md`/`AGENTS.md`. No host-install manifest exists (`_DMC_MANIFEST.md` is the v0.1 scaffold manifest, not a host-install manifest).
  Source: `ls .claude/*`; `ls INSTALL*` → none.
- Finding: The v0.1.2 pilot installed via ad-hoc `cp`; `AGENTS.md` was deliberately skipped (DMC's describes the DMC repo). Host-repo `.harness` artifact commit-vs-local policy was flagged unresolved.
  Source: `.harness/evidence/dmc-v0.1.2-pilot-phase2a.md`, `docs/COMPETITIVE_GAP_LEDGER.md`.
- Finding: `pre-tool-guard` already treats secret-exposure as catastrophic (enforced in all modes incl. off) for Bash; the Read/Grep guard should match that floor.
  Source: `.claude/hooks/pre-tool-guard.sh` (v0.1.1/0.1.2).

## Relevant Files

| Path | Reason | Allowed to Edit (future approved run) |
|---|---|---|
| `.claude/hooks/secret-guard.sh` | NEW — PreToolUse guard for `Read`/`Grep`/`Glob` against secret-bearing paths | yes (new) |
| `.claude/settings.json` | add a `Read\|Grep\|Glob` PreToolUse matcher → secret-guard.sh (additive) | yes |
| `INSTALL_MANIFEST.md` | NEW — exact host-install surface (source of truth) | yes (new) |
| `.claude/install/dmc-install.sh` | NEW — manifest-driven install/adapt (dry-run, collision detect, merge, rollback) | yes (new) |
| `.claude/install/dmc-uninstall.sh` | NEW — manifest-driven rollback/uninstall | yes (new) |
| `docs/HOST_REPO_ARTIFACT_POLICY.md` | NEW — committed-vs-local-only `.harness` artifacts in host repos | yes (new) |
| `docs/HOST_REPO_ADAPTATION_POLICY.md` | NEW — no blind AGENTS.md copy; merge/preserve host docs | yes (new) |
| `docs/OMC_COEXISTENCE.md` | referenced support doc — must be in the manifest so installs bundle it | no (content) / referenced |
| `DMC.md`, `CLAUDE.md` | document v0.1.3 secret guard + policies; instruction-level secret-read fallback | yes |
| `.claude/skills/dmc-off/SKILL.md` | references OMC_COEXISTENCE.md — validate it resolves post-install (no edit if bundled) | no unless needed |
| `.claude/hooks/{pre-tool-guard,scope-guard,stop-verify-gate,evidence-log}.sh` | read-only — must NOT regress; secret-guard is additive | no |

## Out of Scope — GLM / Worker Bridge (explicit)

- **No GLM 5.2 / multi-model integration.** No model router, provider config, or model selection.
- **No Worker Bridge / worker execution / agent-delegation engine.** Worker Bridge is a **future dependency** (v0.2) that is explicitly BLOCKED until this v0.1.3 hardening lands; this plan only records that dependency, it does not design or build it.
- No changes to existing hook enforcement logic, regexes, or thresholds beyond adding the additive secret-guard.
- No implementation in this plan (planning only).
- Standalone CLI beyond the install/adapt script; web/mobile UI; MCP server.

## Proposed Changes

### Theme 1 — Security / tool-read guard hardening
- New `.claude/hooks/secret-guard.sh`, wired as a `PreToolUse` hook matching `Read|Grep|Glob`. Reads the tool input (`tool_input.file_path` for Read; `tool_input.pattern`/`tool_input.path`/`tool_input.glob` for Grep/Glob) via the fixed env-var JSON parse, and **denies** when the target path or glob matches a secret-bearing pattern. Decision is **path/pattern-based — the hook never opens the file**, so it cannot itself leak secrets.
- **Mode policy:** secret-guard enforces in ALL modes (active/passive/off) — secret exposure is the catastrophic/security floor, consistent with `pre-tool-guard`'s Bash secret deny.
- **Secret-bearing filename patterns (initial set):** `.env`, `.env.*` (e.g. `.env.local`, `.env.prod.local`, `.env.*.local`), `*.pem`, `*.key`, `id_rsa`, `id_ed25519`, `*.p12`, `*.pfx`, `*.keystore`, `*.jks`, `.npmrc`, `.netrc`, `.pgpass`, `**/.aws/credentials`, `**/.ssh/*`, `*service-account*.json`, `*secrets*.{json,yaml,yml,env}`, `credentials.json`. Centralize in one list in the hook (and mirror in DMC.md). The authoritative allow/block boundary — including **ALLOW** `.env.example`/`.env.sample`/non-secret `environment.ts`, and **BLOCK** `.env`/`.env.local`/`.env.prod.local`/`.env.production`/private keys/credential & service-account files — is **Resolved Decision #4**.
- **Fallback (if Claude Code cannot intercept Read/Grep in the target build):** keep the explicit instruction-level rule in `CLAUDE.md` ("no tool may open/print secret-bearing files") and the policy-level operating rule from the v0.1.2 Pilot Security Guardrail. The plan's first execution task is to EMPIRICALLY verify whether `PreToolUse` fires for `Read`/`Grep`; the result selects tool-level vs documented-fallback.
- **Residual coverage limitation (non-blocking, defense-in-depth):** path-targeted `Read`/`Grep`/`Glob` of a secret path is the PRIMARY target and is what secret-guard denies. However, a **broad repo-wide `Grep`/search with no explicit secret path** may still **incidentally surface secret-like lines** if secret files are present and not ignored — the path-based guard cannot catch this. Mitigation (all required): (a) the instruction-level deny layer remains required regardless of tool-level support; (b) secret files SHOULD be gitignored in host repos; (c) the installer should ensure `.env*` and secret-bearing paths are ignored where appropriate (Claude Code's `Grep` generally respects gitignore, reducing incidental exposure); (d) verification uses synthetic paths and MUST NOT read real secret contents. This is a documented residual risk, NOT a blocker for v0.1.3.

### Theme 2 — Install surface / documentation integrity
- New `INSTALL_MANIFEST.md`: the single source of truth listing EXACTLY what DMC copies/merges into a host repo (each hook, each skill, each agent, settings.json [merge], `.harness/` skeleton, schemas, `DMC.md`, `CLAUDE.md`, **`docs/OMC_COEXISTENCE.md`**, and what is deliberately NOT copied — e.g. DMC's `AGENTS.md`).
- Ensure every doc referenced by an installed file is in the manifest (bundle it) — `docs/OMC_COEXISTENCE.md` added so the 3 dangling references resolve. Add a "no dangling references after install" verification.

### Theme 3 — Host-repo artifact policy
- New `docs/HOST_REPO_ARTIFACT_POLICY.md`. Proposed policy: in a HOST repo, DMC's `.harness/{plans,evidence,verification,decisions,memory}` are **local-only by default** (the installer adds them to the host `.gitignore`), because they are DMC working artifacts, not host product. Transient state (`.harness/mode`, `.harness/runs/current-*`, `.harness/evidence/manual-*.md`) remains gitignored as today. Teams may **opt in** to commit specific pilot records. Distinguish: **in the DMC repo itself**, plans/evidence/verification ARE committed (project knowledge); **in a host repo**, they default to local-only.

### Theme 4 — Host-repo adaptation policy
- New `docs/HOST_REPO_ADAPTATION_POLICY.md`: never blind-copy DMC's `AGENTS.md` (repo-specific); generate host-specific `CLAUDE.md`/`AGENTS.md` only when appropriate (e.g. via `/dmc-init-deep`); preserve existing host docs and agent configs (merge/append, never overwrite); the installer must detect and report collisions before writing.

### Theme 5 — Installer / copy discipline
- New `.claude/install/dmc-install.sh` (manifest-driven): reads `INSTALL_MANIFEST.md`; supports `--dry-run` (print planned actions, write nothing); **collision detection** (if a host file exists — `CLAUDE.md`, `AGENTS.md`, `.claude/settings.json`, `.gitignore` — warn and MERGE/skip, never overwrite); merges `settings.json` hook arrays and appends `.gitignore` rules; sets `.harness/mode` to a chosen mode (default `passive` when OMC/OMO/OMX or any agent harness is detected, else may default `active`; prints the chosen mode + rationale; user-overridable — Resolved Decision #5); adds the host `.gitignore` local-only `.harness/*` rules (Resolved Decision #2); prints rollback instructions.
- New `.claude/install/dmc-uninstall.sh`: removes manifest-listed files, restores appended `.gitignore`/settings.json sections, leaves host product untouched.

## Acceptance Criteria

- Criterion: secret-guard denies `Read` of a secret-bearing path and allows a benign path — **without reading any file**.
  Verification Method: `printf '{"tool_name":"Read","tool_input":{"file_path":"/x/.env.local"}}' | secret-guard.sh` → contains `"deny"`; `…/src/app.ts` → 0 bytes. (Path need not exist; decision is pattern-based.)
- Criterion: secret-guard covers the documented pattern set (`.env*`, `*.pem`, `*.key`, `id_rsa`, `.npmrc`, `**/.ssh/*`, service-account/secrets files).
  Verification Method: parametrized deny test over each pattern with synthetic paths (no real secrets).
- Criterion (residual risk acceptance): secret-guard tests MUST include path-targeted `Read`/`Grep`/`Glob` attempts; **broad-search incidental exposure is documented as a residual risk** and covered by the policy/instruction fallback (not by the path guard). No real secret contents may be read during any test.
  Verification Method: path-targeted deny tests present and passing (synthetic paths); the plan's residual-coverage note + instruction-level layer are in place; test evidence contains no secret-file contents.
- Criterion: secret-guard denies in active, passive, AND off (security floor).
  Verification Method: temp `CLAUDE_PROJECT_DIR` with each mode → `.env.local` Read denied in all three.
- Criterion: it is empirically determined whether Claude Code `PreToolUse` intercepts `Read`/`Grep`; the chosen path (tool-level OR documented instruction/policy fallback) is in place.
  Verification Method: live observation/test recorded in the run evidence; if tool-level unavailable, CLAUDE.md instruction-level deny + policy rule present and referenced.
- Criterion: `INSTALL_MANIFEST.md` lists every installed item, and a `--dry-run` install into a temp dir yields **zero dangling references** (every doc referenced by an installed file is in the manifest).
  Verification Method: dry-run into temp; `grep -ro '[A-Za-z0-9_/-]*\.md' installed DMC.md/CLAUDE.md/dmc-off` → each referenced doc present in manifest/temp install.
- Criterion: installer supports `--dry-run` (writes nothing) and collision detection (existing host `CLAUDE.md`/`AGENTS.md`/`settings.json` → warn + merge/skip, never overwrite).
  Verification Method: dry-run prints planned actions only (temp dir unchanged); seed a fake host `CLAUDE.md` → installer reports collision and does not overwrite.
- Criterion: host-repo artifact policy + adaptation policy docs exist and the installer applies them (host `.gitignore` gets `.harness/` working-artifact rules; AGENTS.md not blind-copied).
  Verification Method: docs present (heading grep); dry-run plan shows `.gitignore` additions and AGENTS.md excluded.
- Criterion: existing v0.1 active-mode behavior and the four existing hooks are unchanged (secret-guard is additive).
  Verification Method: re-run the v0.1/v0.1.1 behavioral suite in active mode → identical; `git diff` of the four existing hooks → only unrelated/no change; settings.json diff shows only the added matcher.
- Criterion: no GLM/worker code introduced.
  Verification Method: `grep -niE 'glm|worker[ -]?bridge|worker[ -]?exec' .claude docs *.md` → only doc mentions as future dependency, none in executable code.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Claude Code `PreToolUse` may not intercept `Read`/`Grep` in the target build | high | First execution task verifies this empirically; documented instruction-level + policy fallback if tool-level unavailable (criterion covers both paths). |
| secret-guard false-positives block legitimate reads (e.g. `.env.example`, `environment.ts`) | med | Pattern set excludes `.env.example` and non-secret `env`-named source; allow-list tests; deny only true secret patterns. |
| secret-guard itself reads a secret to decide | high (design) | Decision is path/pattern-based ONLY; the hook never opens the target file; acceptance tests use non-existent synthetic paths. |
| Installer overwrites host docs/config | high | Collision detection + merge/skip; `--dry-run` first; never blind-copy; uninstall script + documented rollback. |
| Adding a Read/Grep guard slows every read | low | Cheap path regex; no file IO. |
| Broad repo-wide Grep/search (no explicit path) incidentally surfaces secret-like lines | med (residual, non-blocking) | Path guard targets explicit secret paths; defense-in-depth via instruction-level deny layer (always required) + secrets gitignored in host repos + installer ensures `.env*`/secret paths ignored (Grep generally respects gitignore). Documented residual risk, not a v0.1.3 blocker. |
| Manifest drifts from actual install surface | med | Single source of truth; verification cross-checks manifest vs `.claude` tree; CI-style check. |
| Scope creep toward Worker Bridge/GLM | med | Explicit out-of-scope; future-dependency note only. |

## Rollback Path

### Pre-commit (DMC repo)
```bash
git restore .claude/settings.json DMC.md CLAUDE.md
rm -f .claude/hooks/secret-guard.sh INSTALL_MANIFEST.md \
      .claude/install/dmc-install.sh .claude/install/dmc-uninstall.sh \
      docs/HOST_REPO_ARTIFACT_POLICY.md docs/HOST_REPO_ADAPTATION_POLICY.md
# (remove empty .claude/install/ dir)
```
### Post-commit (DMC repo)
- `git revert <v0.1.3-commit-sha>`; re-run the v0.1 active-mode regression suite to confirm baseline.
### Host-repo installs done by the new installer
- `.claude/install/dmc-uninstall.sh` removes manifest-listed files and restores appended `.gitignore`/settings.json sections; or, on a throwaway branch, delete the branch / `git revert` the install commit. Host product files are never modified, so rollback is clean.

## Verification Commands

| Command | Reason | Required |
|---|---|---|
| `printf '{"tool_name":"Read","tool_input":{"file_path":"/x/.env.local"}}' \| .claude/hooks/secret-guard.sh \| grep -q '"deny"'` | Read of secret path denied (no file opened) | yes |
| `printf '{"tool_name":"Read","tool_input":{"file_path":"/x/src/app.ts"}}' \| .claude/hooks/secret-guard.sh \| wc -c` → 0 | benign read allowed | yes |
| `printf '{"tool_name":"Read","tool_input":{"file_path":"/x/.env.example"}}' \| .claude/hooks/secret-guard.sh \| wc -c` → 0 | `.env.example` NOT a false positive | yes |
| parametrized deny test over `*.pem`,`*.key`,`id_rsa`,`.npmrc`,`.ssh/*`,service-account paths | pattern coverage | yes |
| secret-guard deny under mode=active/passive/off (temp dir) | security floor in all modes | yes |
| `grep -q 'DMC_HOOK_INPUT="$INPUT" python3' .claude/hooks/secret-guard.sh` | fixed env-var parse (no heredoc regression) | yes |
| dry-run install into temp; cross-check referenced docs vs manifest | zero dangling references | yes |
| seed fake host `CLAUDE.md`; run installer | collision detected, not overwritten | yes |
| `bash -n .claude/hooks/*.sh .claude/install/*.sh` | all scripts parse | yes |
| v0.1 active-mode regression suite | no regression in existing hooks | yes |
| `git diff .claude/settings.json` | only the added Read\|Grep matcher | yes |
| `grep -niE 'glm\|worker[ -]?bridge' .claude` (code) | no GLM/worker code | yes |

## PASS / PARTIAL / FAIL

- **PASS**: Read/Grep secret protection in place — tool-level secret-guard intercepting `Read`/`Grep` on the documented patterns in all modes, OR (if Claude Code cannot intercept) a documented instruction-level + policy fallback verified — with path-based acceptance tests that read no secrets; `INSTALL_MANIFEST.md` complete and a dry-run install yields zero dangling references; host-repo artifact + adaptation policies written and applied by the installer; installer supports dry-run + collision detection + rollback (+ uninstall); existing four hooks and v0.1 active behavior unchanged; no GLM/worker code.
- **PARTIAL**: Core secret protection works but only via the instruction/policy fallback (tool-level unavailable), OR the installer lands without one sub-feature (e.g. collision detection) while manifest + dangling-ref fix + secret-guard are done, OR one policy doc deferred — each gap documented with status.
- **FAIL**: No Read/Grep protection at all (neither tool-level nor documented policy), OR install still produces dangling references, OR the installer overwrites host docs/config, OR an existing hook/protection regressed, OR any GLM/Worker Bridge execution code is added.

## Assumptions

| Assumption | Confidence | How to Verify |
|---|---|---|
| **Open — Claude Code `PreToolUse` can match `Read`/`Grep`/`Glob`.** Determines tool-level vs fallback. | medium | First execution task: wire a matcher and observe whether the hook fires on a Read; record result. |
| Secret-guard should enforce in all modes (security floor) | high | Mirrors v0.1.2 Resolved Decision #3 (secret = catastrophic). |
| Host `.harness` working artifacts default to local-only in host repos | medium | Confirm at approval; policy doc encodes the decision. |
| `docs/OMC_COEXISTENCE.md` should be bundled (not references removed) | high | It is referenced by 3 installed files and is useful guidance. |
| Manifest-driven installer is preferred over ad-hoc cp | high | v0.1.2 friction finding. |

## Execution Tasks

- [ ] DMC-T001: Empirically determine whether `PreToolUse` intercepts `Read`/`Grep`/`Glob`; record result (selects tool-level vs fallback).
- [ ] DMC-T002: Implement `.claude/hooks/secret-guard.sh` (path/pattern-based deny; fixed env-var parse; all-mode floor) + wire matcher in `settings.json`.
- [ ] DMC-T003: Author `INSTALL_MANIFEST.md`; bundle `docs/OMC_COEXISTENCE.md`; ensure zero dangling references.
- [ ] DMC-T004: Write `docs/HOST_REPO_ARTIFACT_POLICY.md` and `docs/HOST_REPO_ADAPTATION_POLICY.md`.
- [ ] DMC-T005: Implement `.claude/install/dmc-install.sh` (manifest-driven; `--dry-run`; collision detection; merge; mode default) + `dmc-uninstall.sh`.
- [ ] DMC-T006: Update `DMC.md`/`CLAUDE.md` (secret-guard + patterns + instruction-level fallback + policy pointers).
- [ ] DMC-T007: Verification — secret-guard tests (no secret reads), dry-run dangling-ref check, collision test, v0.1 regression; write evidence + verification report; status.

## Approval Status

Status: APPROVED
Approver: 대표님
Approved At: 2026-06-19
