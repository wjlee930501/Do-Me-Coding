# Plan — fable-core follow-up (v1.1.5): Codex adapter Block C bypass-awareness mirror

Work ID: dmc-fable-core-codex-bypass

## Goal

Port the v1.1.1 ask-tier bypass-awareness (`.claude/hooks/pre-tool-guard.sh:135-161`) into the Codex adapter's Block C Python mirror so the ADVISORY mirror's ask-tier behavior matches the Claude-side pre-tool-guard under a host-attested `bypassPermissions` mode — WITHOUT weakening any deny floor, scope enforcement, cross-adapter verdict parity, or the frozen baseline:

- **M1 — permission-mode read.** `adapters/codex/dmc_codex_common.py` gains `PERMISSION_MODE_KEYS` + a top-level reader (the module currently has ZERO permission-mode handling — `grep -rn permission_mode adapters/` = 0).
- **M2 — Block C advisory stand-down under bypass.** In `dmc-codex-pretooluse.py handle_bash`, at the Block C `ask` verdict ONLY (reached only AFTER the deny floors have already returned), when `permission_mode` is EXACTLY `bypassPermissions`, downgrade the `ask` to an advisory stand-down: emit `{"systemMessage": …}` (byte-identical string to the Claude side) + best-effort append ONE value-blind class/timestamp line to `.harness/metrics/ask-tier-advisory.log` (NEVER the command text) + exit 0. Deny tiers are NOT consent-seeking and never stand down.
- **M3 — inert-if-absent fail-closed default.** `permission_mode` absent, empty, or ANY other value (`default`, `acceptEdits`, `plan`, unknown) ⇒ Block C behaves EXACTLY as today (ask fires), byte-identical outputs. The Option-A ADVISORY posture is unchanged: honoring of the stand-down envelope on a Codex host is turn-free-unprovable, so the stand-down inherits the same advisory status as every other envelope the shim emits — NO enforcement-parity claim is added.
- **Non-goals (the moat):** Block A/B deny floors (`_FLOORS` scope `all`/`not-off`) unchanged in every mode; Block D write-radius (`bin/dmc bash-radius`) unchanged — it adjudicates SCOPE not consent, so bypass never stands it down; the Block C ask pattern LIST unchanged (no command added/removed); Read/Grep/Glob secret guard + Edit/Write scope guard untouched.

## User Intent

feature

(A narrow, additive cross-adapter parity port of an already-shipped Claude-side behavior. It mirrors a behavioral enforcement change into the ADVISORY Codex adapter; it introduces no new enforced runtime path on the Claude side and does not modify any generator, frozen tool, or the legacy baseline.)

## Current Repo Findings

(grounded 2026-07-10, this session; branch `claude/dmc-fable-core` == HEAD `497ca4b`, `.harness/mode=active`)

- Finding F1 (Claude-side reference to mirror): `.claude/hooks/pre-tool-guard.sh:135-161` is the v1.1.1 Block C. It fires only when `DMC_MODE=active`; after the ask-class match it derives `PTG_ASK_CLASS` (`:140-145`, precedence publish → audit-force → schema-push → migrate → install-fallback); if `PERMISSION_MODE = bypassPermissions` (`:152`) it `mkdir -p .harness/metrics`, appends `"$(date -u +%Y-%m-%dT%H:%M:%SZ) ask-tier-standdown class=<class>"` (`:155`), emits `{"systemMessage":"DMC advisory: ask-tier stood down under bypassPermissions (class: <class>); deny floors remain active."}` (`:156-157`) and `exit 0`; every other value falls through to the unchanged `ask` (`:160`). `PERMISSION_MODE` is read at `:55` (`json_get 'permission_mode'`).
  Source: `.claude/hooks/pre-tool-guard.sh:55,135-161`.
- Finding F2 (Codex mirror gap): `adapters/codex/dmc_codex_common.py` defines `CMD_KEYS/FILE_PATH_KEYS/GREP_*_KEYS/GLOB_KEYS/PROMPT_KEYS` (`:46-52`) but NO `PERMISSION_MODE_KEYS`; `_FLOORS` (`:266-301`) has the Block C ask entry (last row, scope `active`, regex identical to `pre-tool-guard.sh:137`); `classify_bash_floors` (`:304-315`) returns `("ask", reason)` for it. `dmc-codex-pretooluse.py handle_bash` (`:33-71`) calls `classify_bash_floors` then `dc.pretool_ask(reason)` on the ask verdict — with NO bypass-awareness. Because Block C is the ONLY `ask`-scoped floor, a returned verdict of `"ask"` UNIQUELY identifies the Block C match (the point at which bypass-awareness attaches). `grep -rn permission_mode adapters/` = 0.
  Source: `adapters/codex/dmc_codex_common.py:46-52,266-315`; `adapters/codex/dmc-codex-pretooluse.py:45-51`; grep.
- Finding F3 (deny floors already fire first — bypass cannot reach them): in `handle_bash`, `classify_bash_floors` returns `"deny"` for Block A/B BEFORE the `"ask"` branch, and `dc.pretool_deny(reason)` exits. `git push --force`, `cat .env`, `prisma migrate reset`, `git apply` etc. are Block A (`scope="all"`) and return `deny` before Block C is considered. So the stand-down at the ask branch is structurally unreachable for any deny command.
  Source: `adapters/codex/dmc-codex-pretooluse.py:46-50`; `dmc_codex_common.py:266-315`.
- Finding F4 (mode composition is automatic): the Block C `_FLOORS` entry is `scope="active"`, so `classify_bash_floors` returns `(None,None)` for an install command in passive/off ⇒ `handle_bash` falls to Block D (armed+active only, skipped) ⇒ `pretool_allow()`. Thus the `"ask"` verdict — and therefore the new bypass path — is reachable ONLY in active mode, exactly like `pre-tool-guard.sh` (Block C `[ "$DMC_MODE" = active ]`). Bypass-awareness needs no extra mode gate; it inherits active-only from the ask verdict. Arming is irrelevant to Block C on both sides (it precedes Block D).
  Source: `dmc_codex_common.py:308-315`; `pre-tool-guard.sh:136`.
- Finding F5 (the parity suite lives in test-codex-shims.sh, and NO existing assertion carries permission_mode): `tests/fixtures/m6.5/test-codex-shims.sh` section D drives BOTH the REAL Claude hook (`claude_run`) and the Codex shim (`codex_run`) on identical JSON (`parity_pre`, 143 assertions total incl. A16 UPS parity). D9 (`:333`) is `bash ask-tier (npm install left-pad)` — parity `ask==ask`. The event builders in `_m65common.sh:55-74` (`c_bash` etc.) emit NO `permission_mode` field. Therefore adding inert-if-absent bypass-awareness changes NO existing assertion: D9 and every c_* row still produce today's verdict. The new behavior needs NEW coverage, not a lockstep edit of existing rows.
  Source: `tests/fixtures/m6.5/test-codex-shims.sh:38-49,315-333`; `_m65common.sh:55-74`.
- Finding F6 (the suite count is NOT code-pinned): `run_m65_suite` (`bin/dmc:276-286`) runs each suite with `bash "$s" || rc=1` — EXIT CODE only, no count assertion (confirmed by `dmc-v1.0.2-router-anchor.md:44` "NO enforced exact-count assertion exists for test-codex-shims"). The ONLY code-enforced count is legacy `PINNED_BASELINE={tools:49,pass:802,fail:3,na:3}` (`bin/lib/dmc-legacy-selftest.py:118`), which counts ONLY `dmc-v0.*` `.sh/.py` tools (`:208` `f.startswith("dmc-v0.")`). `dmc_codex_common.py`, `dmc-codex-pretooluse.py`, and `test-codex-shims.sh` are NOT `dmc-v0.*` ⇒ 802/3/3 is untouched. The `143` figure appears only as frozen prose in `docs/MILESTONES.md` + `.harness/plans/*` + `.harness/evidence/*` (never retro-edited). So adding a section F (143 → N) breaks no pin; the v1.1.5 MILESTONES entry records the new N.
  Source: `bin/dmc:276-286`; `bin/lib/dmc-legacy-selftest.py:118,208`; `dmc-v1.0.2-router-anchor.md:44`.
- Finding F7 (both edited .py files are enforcement LANDMARKS + manifest-listed, but content-edit-neutral): `AGENTS.md:183,186` list `adapters/codex/dmc-codex-pretooluse.py` and `dmc_codex_common.py` as `enforcement (enforcement-surface heuristic / dmc-protected-union)` — PATH + CLASS + heuristic-name only, NO content-derived field (no hash/line-count). `INSTALL_MANIFEST.md:151-152` + `.claude/install/dmc-install.sh:44` (`CODEX_ADAPTERS="dmc_codex_common.py dmc-codex-pretooluse.py …"`) enumerate them BY NAME; the installer ships by `ship_file` byte-copy (`:370`), NOT an embedded payload — so there is NO separate installer-mirror to sync (unlike the v1.1.1 pre-tool-guard mirror question), and a content edit changes neither generated artifact. The regen-pin E-cycle empirically proved a content edit to a listed enforcement landmark (`bin/dmc`) leaves `agents-md --stdout | diff - AGENTS.md` EMPTY (`dmc-fable-core-e-build-20260710.md:34`). Expectation: both neutrality diffs EMPTY; both artifacts Allowed-to-Edit: NO — a surprise drift ⇒ HALT + follow-up scope, NEVER an in-lock edit (G2 staging obligation).
  Source: `AGENTS.md:183,186`; `INSTALL_MANIFEST.md:151-152`; `.claude/install/dmc-install.sh:44,370`; `dmc-fable-core-regen-pin.md` F5.
- Finding F8 (no G4 / DMC_GATE_PROTECTED override needed): `DEFAULT_PROTECTED` (`bin/lib/dmc-v0.2.6-gate-check-runner.sh:22-31`) is `{.claude/workers/providers/*, .claude/hooks, WORKER_*_SCHEMA.md, dmc-glm-smoke}` — it does NOT include `adapters/` or `adapters/codex`. So editing the codex `.py` files does NOT trip G4. This differs from v1.1.1 (which touched `.claude/hooks` and needed the G4 override). The two files are landmarks (non-degrading informational FLAG at gate; `landmark_authorized` in the scope.lock rows) but NOT gate-protected. Clean gate, no env override.
  Source: `bin/lib/dmc-v0.2.6-gate-check-runner.sh:22-31,63-67`.
- Finding F9 (exact-literal compare survives the superset reader): `_ci_get` (`dmc_codex_common.py:85-98`) lowercases KEYS for lookup but returns `str(v)` UNCHANGED, so a value of `"bypassPermissions"` compares byte-exact against the literal; absent ⇒ `""` ⇒ falls through to ask (inert-if-absent). `redact()` (`:179-212`) is byte-parity-locked to `evidence-log.sh` — but the stand-down log line is value-blind (class + timestamp only, no payload), so no secret can reach it and redaction is not even exercised on that line.
  Source: `dmc_codex_common.py:85-98,179-212`.

## Relevant Files

| Path | Reason | Allowed to Edit |
|---|---|---|
| `adapters/codex/dmc_codex_common.py` | M1 — add `PERMISSION_MODE_KEYS`, `permission_mode(data)` (top-level reader, mirrors `json_get 'permission_mode'`), `ask_class(command)` (mirrors `PTG_ASK_CLASS` precedence), `pretool_standdown(project_dir, cls)` (value-blind log + `{"systemMessage":…}` + exit 0), + one stdlib time import. Enforcement landmark (dmc-protected-union) → non-degrading FLAG expected, `landmark_authorized` in the lock; NOT DEFAULT_PROTECTED (no G4). | yes |
| `adapters/codex/dmc-codex-pretooluse.py` | M2 — in `handle_bash`, at the `verdict == "ask"` branch (Block C, after deny floors returned), if `dc.permission_mode(data) == "bypassPermissions"` → `dc.pretool_standdown(project_dir, dc.ask_class(command))`; else `dc.pretool_ask(reason)` as today. ~3 lines. Same landmark class / FLAG / `landmark_authorized`; no G4. | yes |
| `tests/fixtures/m6.5/test-codex-shims.sh` | NEW section F — mirror of `tests/install/test-ask-tier-bypass.sh` for the Codex shim + cross-adapter parity (see Proposed Changes). NOT a landmark, NOT shipped. | yes |
| `docs/MILESTONES.md` | append ONE `## v1.1.5` entry (append-only). | yes (append) |
| `INSTALL_MANIFEST.md` | neutrality VERIFIED by `--emit-manifest` diff (name-based, content-agnostic, F7); IF drift ever appears ⇒ HALT + follow-up scope, do NOT edit under this lock. | no |
| `AGENTS.md` | neutrality VERIFIED by `agents-md --stdout` diff (path+class, F7); same HALT rule. | no |
| `tests/fixtures/m6.5/_m65common.sh` | UNCHANGED — section F builds bypass envelopes INLINE via the already-exported `json_str`; keeps the shared helper (and its own landmark-neutrality) untouched. | no |
| frozen `dmc-v*` tools, `bin/lib/dmc-legacy-selftest.py` (PINNED_BASELINE), other hooks/adapters, `.github/workflows/dmc-ci.yml` (auto-covers via `selftest m65-suite`) | out of scope / auto-covered / frozen | no |

## Out of Scope

- ANY change to Block A/B deny patterns, Block D write-radius (`bash-radius`), scope-guard, secret-guard, redaction, evidence-log, stop/diff guard, or `.harness/mode` semantics — on either adapter.
- ANY change to the Block C ask pattern LIST (`_FLOORS` last row / `pre-tool-guard.sh:137`).
- ANY change to `.claude/hooks/pre-tool-guard.sh` — the Claude side already shipped v1.1.1; this cycle only mirrors it into the Codex adapter.
- Downgrading `ask` under `acceptEdits`/allowlist — only the exact literal `bypassPermissions` stands down (same narrowing as v1.1.1; registered as a possible v1.2+ pilot question).
- `_m65common.sh` edits, a standalone `tests/install/test-codex-ask-tier-bypass.sh`, or re-homing any suite (see the Proposed-Changes rationale for choosing in-suite section F).
- `bin/lib/dmc-legacy-selftest.py` / PINNED_BASELINE (802/3/3 stays EXACT), `.github/workflows/dmc-ci.yml` (blocking `selftest m65-suite` already iterates the whole M6.5 list — auto-covers).
- Push / CI / main merge (human gate).

## Proposed Changes

- Change: `adapters/codex/dmc_codex_common.py` — add (byte-faithful to `pre-tool-guard.sh:140-160`):
  (1) `PERMISSION_MODE_KEYS = ("permission_mode", "permissionMode")` — documented Codex `permission_mode` field leads (enum identical to Claude Code: default|acceptEdits|plan|dontAsk|bypassPermissions), camelCase as the sole defensive candidate per the superset house rule.
  (2) `permission_mode(data)` → `_ci_get(data, PERMISSION_MODE_KEYS)` (TOP-LEVEL only, mirroring `json_get 'permission_mode'`; returns "" when absent).
  (3) `ask_class(command)` → over `_oneline(command)`, return `publish` if `(npm|pnpm|yarn|bun)\s+publish`, elif `audit-force` if `npm\s+audit\s+fix\s+--force`, elif `schema-push` if `schema\s+push`, elif `migrate` if `migrate\s+(deploy|dev|reset)`, else `install` — EXACT precedence + fallback of `PTG_ASK_CLASS`.
  (4) `pretool_standdown(project_dir, cls)` → best-effort (`try/except: pass`) `os.makedirs(<project_dir>/.harness/metrics, exist_ok=True)` then append one line `"<UTC %Y-%m-%dT%H:%M:%SZ> ask-tier-standdown class=<cls>\n"` to `ask-tier-advisory.log`; then `_emit({"systemMessage": "DMC advisory: ask-tier stood down under bypassPermissions (class: %s); deny floors remain active." % cls})`; `sys.exit(0)`. Add `import datetime` (or `time`) — stdlib, house-rule compliant. Optional one-line code comment at `PERMISSION_MODE_KEYS` citing the now-documented enum + Option-A inert-if-absent posture; the module docstring's ADVISORY framing needs NO change.
  Files: `adapters/codex/dmc_codex_common.py`.
  Rationale: mirror logic + emitter live beside the existing `tool_name`/`event_cwd`/`pretool_ask` so the shim stays a thin router; pure functions are unit-parity-testable.
- Change: `adapters/codex/dmc-codex-pretooluse.py` — in `handle_bash`, replace the `if verdict == "ask": dc.pretool_ask(reason)` block (`:50-51`) with:
  `if verdict == "ask":` → `if dc.permission_mode(data) == "bypassPermissions": dc.pretool_standdown(project_dir, dc.ask_class(command))` → `dc.pretool_ask(reason)`. No other branch touched. Deny floors (`:47-48`) still return first; Block D (`:52-71`) unchanged.
  Files: `adapters/codex/dmc-codex-pretooluse.py`.
  Rationale: attaches bypass-awareness at the unique Block C ask point; inert-if-absent (no field ⇒ `pretool_ask` as today).
- Change: `tests/fixtures/m6.5/test-codex-shims.sh` — append a `== F. ask-tier bypass-awareness (v1.1.5) ==` section (fresh unarmed active sandboxes via the existing `new_dir active`; bypass envelopes built INLINE with the sourced `json_str`; a local `cbp() { printf '{"tool_name":"Bash","tool_input":{"command":%s},"permission_mode":%s}' "$(json_str "$1")" "$(json_str "$2")"; }` and inline `grep -q '"systemMessage"'`). Rows:
  - F1 codex: `npm install`, no permission_mode ⇒ `ask` (inert-if-absent / frozen-compat).
  - F2 codex: `npm install` + `acceptEdits` ⇒ `ask`.
  - F3 codex: `npm install` + `bypassPermissions` ⇒ stand-down: no `ask`, rc 0, `systemMessage` present + JSON-parseable, EXACTLY one log line matching `^[0-9TZ:-]+ ask-tier-standdown class=install$`.
  - F4 codex: `git push --force` + `bypassPermissions` ⇒ still `deny` (Block A floor never stands down).
  - F5 codex: `cat .env` + `bypassPermissions` ⇒ still `deny` (secret floor).
  - F6 codex: `sqlx migrate reset` + `bypassPermissions` ⇒ stand-down `class=migrate`.
  - F7 codex: mode=passive + `bypassPermissions` ⇒ no `ask`, no `systemMessage`, NO log file (passive stands the ask-tier down; bypass never consulted — proves mode composition).
  - F8 codex value-blind negctl: bypass with a fake `sk-FAKE…` token in the command ⇒ log records `class=install` only, token ABSENT.
  - F-PAR1 cross-adapter (SEPARATE active sandboxes per adapter): drive `claude_run pre-tool-guard.sh` AND `codex_run "$PRE"` on the SAME `npm install`+bypass envelope; assert both no-`ask`, both `systemMessage` present, the two EXTRACTED systemMessage strings byte-EQUAL, and both log lines match `^[0-9TZ:-]+ ask-tier-standdown class=install$` (redaction/log-shape parity, requirement (c)). Compare EXTRACTED message text, not raw envelope bytes.
  - F-PAR2 cross-adapter: `git push --force`+bypass ⇒ claude `deny` == codex `deny`.
  - F-PAR3 cross-adapter inert-if-absent: `npm install` no-pm ⇒ claude `ask` == codex `ask` (explicit reaffirmation of the D9 class).
  Files: `tests/fixtures/m6.5/test-codex-shims.sh`.
  Rationale (in-suite vs standalone — the one judgment call): the behavior IS a cross-adapter parity property and the parity harness (`claude_run`+`codex_run` on identical JSON) already lives here (F5). Crucially, `test-codex-shims.sh` runs under `run_m65_suite`, a BLOCKING CI step (`.github/workflows/dmc-ci.yml:172-173`) — and per the module's own contract the Codex adapter's real enforcement boundary IS the CI/pre-commit gate, so the bypass mirror MUST be CI-covered. The Claude sibling `test-ask-tier-bypass.sh` is a manual smoke test NOT wired to CI; an equivalent Codex standalone would leave the mirror CI-uncovered — rejected for that reason. In-suite extension perturbs no code-enforced count (F6).
- Change: `docs/MILESTONES.md` — append ONE `## v1.1.5 — Codex adapter Block C bypass-awareness mirror — LOCAL (2026-07-10)` entry: what/why, the byte-faithful mirror of v1.1.1, the honest "live Codex `permission_mode` delivery is turn-free-unprovable; inert-if-absent" line, the new section F assertion set + the descriptive `test-codex-shims.sh` 143→N count, the "legacy 802/3/3 UNCHANGED" note, and a `push/CI/main-FF: human gate` line.
  Files: `docs/MILESTONES.md`.

## Acceptance Criteria

- Criterion: bypass stand-down works in the Codex mirror; everything else byte-compatible.
  Verification Method: section F codex rows F1–F8 PASS; F3 asserts no-`ask` + rc 0 + parseable `systemMessage` + exactly one value-blind `class=install` line.
- Criterion: deny floors provably unaffected by bypass.
  Verification Method: F4 + F5 (deny under bypass) PASS; `grep -n bypassPermissions adapters/codex/*.py` shows the token ONLY in the pretooluse Block C ask path + the common.py standdown emitter/keys — NO deny-path reference (line-range inspection in the verification report).
- Criterion: value-blind + cross-adapter log/systemMessage parity.
  Verification Method: F3/F8 log line matches `^[0-9TZ:-]+ ask-tier-standdown class=[a-z-]+$` (no command text); F-PAR1 asserts the Codex systemMessage string byte-equals the Claude side and both log lines share the same shape.
- Criterion: no existing cross-adapter assertion regressed.
  Verification Method: `bash tests/fixtures/m6.5/test-codex-shims.sh` 0 FAIL (D9 + all c_* rows unchanged; section F green); `bin/dmc selftest m65-suite` 0 FAIL; real-repo porcelain guard (`m65_assert_repo_untouched`) PASS.
- Criterion: inert-if-absent frozen baseline holds.
  Verification Method: F1/F2 PASS; `bin/dmc selftest` 0 FAIL; committed-replica AND isolated-live `bin/dmc selftest --all` = `tools=49 PASS=802 FAIL=3 N/A=3` EXACT (run under `.harness/mode=active`; mode-coupling + `.codex/config.toml`-stash gotchas registered).
- Criterion: derived-artifact neutrality (both edited files are enforcement landmarks + manifest-listed).
  Verification Method: `bin/dmc agents-md --root . --stdout | diff - AGENTS.md` EMPTY; `bash .claude/install/dmc-install.sh --emit-manifest | diff - INSTALL_MANIFEST.md` EMPTY. Drift ⇒ HALT + follow-up scope, never an in-lock artifact edit (G2).
- Criterion: scope + gate + ceiling.
  Verification Method: scope.lock == EXACTLY the 4 changed paths, ALL staged (G2), `landmark_authorized: true` on the two `.py` rows; green set + `bin/dmc gate release --full --run-id <run>` PASS with the non-degrading FLAG on the two enforcement landmarks and NO `DMC_GATE_PROTECTED` override (adapters/codex absent from DEFAULT_PROTECTED — F8); `git diff --name-only` per commit == the in-scope files; commits LOCAL on `claude/dmc-fable-core`; `.codex/config.toml` unstaged; NO push.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| A Codex host that never delivers `permission_mode` makes M2 dead code | low | inert-if-absent BY DESIGN (fail-closed to ask); the field is now officially documented (enum identical to Claude); live delivery is turn-free-unprovable, consistent with the shim's standing Option-A ADVISORY posture; honestly recorded in evidence |
| Mirror diverges from the Claude side (systemMessage / log-line / class precedence) breaking parity | medium | F-PAR1 byte-compares the extracted systemMessage + log-line shape across adapters; the exact strings + precedence (publish>audit-force>schema-push>migrate>install) are pinned in this plan from `pre-tool-guard.sh:141-160` |
| Bypass wrongly stands a deny down under some ordering | high (if wrong) | the standdown sits at the `ask` verdict branch, reached ONLY after `classify_bash_floors` returns `deny` and exits (F3); Block C is the sole ask-scoped floor; F4/F5 assert deny-under-bypass; grep-AC proves the token never appears in a deny path |
| Adding section F changes the descriptive 143 count, mistaken for a broken pin | low | `run_m65_suite` is exit-code only (F6); the sole code-enforced count is legacy 802/3/3 (dmc-v0.* only); MILESTONES v1.1.5 records the new N; historical 143 refs are frozen prose, never retro-edited |
| Editing two enforcement LANDMARK files drifts AGENTS.md / INSTALL_MANIFEST | low | both are path+class (AGENTS) / name (manifest) derived, content-agnostic (F7); regen-pin E-cycle empirically proved a content edit to a listed enforcement landmark is neutral; neutrality is a blocking AC; drift ⇒ HALT + follow-up scope |
| Executor armed-window Bash discipline vs the test's own shell constructs | low | the COMMITTED test MAY use redirects/heredocs/`json_str` in its body; the EXECUTOR authors it via Write and runs it via `bash …` / `bin/dmc selftest m65-suite` with NO `>` / `python3 -c` / `sh -c` / `cp` / `mv` / `tee` / `sed -i` in its own tool calls |

## Assumptions

| Assumption | Confidence | How to Verify |
|---|---|---|
| Codex delivers `permission_mode` (bypass enum) in the PreToolUse event on a real bypass turn | medium (now documented; live delivery turn-free-unprovable, Option-A) | design is inert-if-absent; a post-build live observation is a pilot follow-up, NOT an AC |
| `_ci_get` returns the value unchanged so the exact-literal `== "bypassPermissions"` compare holds | high | `dmc_codex_common.py:85-98` lowercases KEYS only, returns `str(v)`; F3 exercises it |
| `_m65common.sh` need not change (inline bypass builder via `json_str`) | high | `json_str` is exported by the sourced common (`_m65common.sh:53`); section F builds envelopes inline |
| No G4 / `DMC_GATE_PROTECTED` override needed | verified | `adapters/codex` absent from `DEFAULT_PROTECTED` (`dmc-v0.2.6-gate-check-runner.sh:22-31`); gate produces FLAG only |
| This cycle is covered by the standing fable-core envelope (registered follow-up item 2, user "2번도 적용하자" 2026-07-10) | high | human gate confirms at critic/commit time |

## Execution Tasks

- [ ] DMC-T001: Implement the `dmc_codex_common.py` additions (M1: `PERMISSION_MODE_KEYS`, `permission_mode`, `ask_class`, `pretool_standdown`, stdlib time import) exactly as specified. `python3 -c` sanity is the executor's own call — instead verify via the section-F suite in T002. `bash -n` N/A (python); a `python3 -m py_compile` may be run by the suite/verifier, not as a raw executor `-c`.
  Files: `adapters/codex/dmc_codex_common.py`.
  Notes: Route Opus 4.8, synchronous (Ring-1 enforcement-adjacent mirror; deep effort).
- [ ] DMC-T002: Wire M2 into `dmc-codex-pretooluse.py handle_bash`; author section F in `test-codex-shims.sh` (F1–F8 + F-PAR1/2/3). Run `bash tests/fixtures/m6.5/test-codex-shims.sh` (0 FAIL, incl. section F + the porcelain guard) and `bin/dmc selftest m65-suite` (0 FAIL).
  Files: `adapters/codex/dmc-codex-pretooluse.py`, `tests/fixtures/m6.5/test-codex-shims.sh`.
  Notes: Route Opus 4.8, synchronous; depends on T001. Executor Bash discipline as in Risks.
- [ ] DMC-T003: Append the `docs/MILESTONES.md` v1.1.5 entry. Re-verify derived-artifact neutrality (both diffs EMPTY; drift ⇒ HALT + follow-up scope, no in-lock artifact edit). Independent verification (fresh Opus verifier lane) → `.harness/verification/<run-id>.md` (own re-run of section F incl. F4/F5 deny-under-bypass + F-PAR1 parity; own committed-replica/isolated-live `--all` 802/3/3 EXACT; own grep-AC line-range read). Green set + `bin/dmc gate release --full --run-id <run>` PASS (FLAG on the two landmarks, no override). Change commit + records commit (LOCAL; targeted `git add`; `.codex/config.toml` unstaged). Build evidence `.harness/evidence/dmc-fable-core-codex-bypass-build-20260710.md`.
  Files: `docs/MILESTONES.md` (+ records/verification/evidence, scope-exempt).
  Notes: Route docs Sonnet 5; verifier Opus 4.8 fresh lane; commits by the orchestrator under the envelope grant; push/CI/main-FF remain a human gate.

## Verification Commands

| Command | Reason | Required |
|---|---|---|
| `bash tests/fixtures/m6.5/test-codex-shims.sh` | section F (bypass mirror + cross-adapter parity) + unchanged D-block + porcelain guard, 0 FAIL | yes |
| `bin/dmc selftest m65-suite` | the new coverage rides the BLOCKING CI path (`run_m65_suite`) | yes |
| `grep -n bypassPermissions adapters/codex/*.py` | token appears ONLY in the Block C ask path + standdown emitter/keys (no deny-path reference) | yes |
| `bin/dmc agents-md --root . --stdout \| diff - AGENTS.md` (EMPTY) | AGENTS.md landmark neutrality (both .py already listed by path+class) | yes |
| `bash .claude/install/dmc-install.sh --emit-manifest \| diff - INSTALL_MANIFEST.md` (EMPTY) | INSTALL_MANIFEST neutrality (name-based) | yes |
| committed-replica + isolated-live `bin/dmc selftest --all` == `tools=49 PASS=802 FAIL=3 N/A=3` EXACT (`.harness/mode=active`, `.codex/config.toml` stashed) | legacy baseline unchanged (Constitution II.2, no masking) | yes |
| `bin/dmc selftest` 0 FAIL | full suite floor | yes |
| `bin/dmc verdict gate` binds a schema-valid critic APPROVE to this plan's sha256 before build | critic-APPROVE-conditional envelope gate | yes |
| staged set == in-scope 4 paths; green set + `bin/dmc gate release --full --run-id <run>` PASS (FLAG on 2 landmarks, NO override); commits LOCAL; `.codex/config.toml` unstaged; no push | gate + autonomy ceiling | yes |

## Approval Status

Status: APPROVED
Approver: human envelope gate (user directive 2026-07-10 "2번도 적용하자") + critic r1 APPROVE (dmc-fable-core-codex-bypass-critic-r1.json)
Approved At: 2026-07-10

Notes: Planner (read-only planning lane) emits this DRAFT. It is NOT self-approved and opens NO gate. The mandatory pre-build gate is a fresh-context critic (`/dmc-critic`) returning a schema-valid APPROVE whose verdict binds THIS file's sha256 via `bin/dmc verdict gate`; the standing fable-core envelope (critic-APPROVE-conditional, LOCAL-commit ceiling on `claude/dmc-fable-core`, push/main a separate human gate, 2 consecutive critic REJECTs → halt + report) governs execution. Open questions for the critic are in the planner handoff.
Revisions: Rev 1 (initial). Rev 2: approval flipped under the envelope after critic r1 APPROVE (0 blockers; 3 executor-level advisories carried in the executor brief); flip applied by the orchestrator lane (the read-only planner correctly declined to self-approve its own artifact); re-submitted for critic r2 hash re-bind.
