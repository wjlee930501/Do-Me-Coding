# Verification Report

## Run ID

dmc-run-ea8cac7f910b

(state: SUSPENDED; scope.lock armed; HEAD 49a0786; verified at pre-staging / pre-commit)

## Plan

`.harness/plans/dmc-fable-core-c-asktier.md` (Rev 1, APPROVED). Binding confirmed: `shasum -a 256` of the plan = `9a706fdff837d3df04696aa83ad61563a72520bf98cc3d5562324479f551242a`, byte-equal to `run.json.plan_hash`, `scope.lock.json.plan_hash`, and the critic r1 `plan_hash` (`.harness/evidence/dmc-fable-core-c-critic-r1.json`, verdict APPROVE, 0 blockers). `scope.lock.json` is `immutable:true`, `compiled_at_head` = HEAD `49a0786`, `files[]` = exactly the 3 expected paths with correct grants/classes (`.claude/hooks/pre-tool-guard.sh` edit/enforcement/landmark_authorized; `docs/MILESTONES.md` edit/release/landmark_authorized; `tests/install/test-ask-tier-bypass.sh` create/ordinary), bounds `max_files=3 / max_added=450 / max_deleted=20`.

## Changed Files

- `.claude/hooks/pre-tool-guard.sh`: C1 permission-mode read + C2 Block C bypass stand-down (in scope, edit grant).
- `docs/MILESTONES.md`: v1.1.1 entry, append-only (in scope, edit grant).
- `tests/install/test-ask-tier-bypass.sh`: new standalone smoke test, untracked (in scope, create grant).

(Crosscheck note: out-of-band, NOT part of this change's commit — `.codex/config.toml` is pre-existing unstaged (+4 lines, out-of-band, must stay unstaged). Untracked records `.harness/plans/dmc-fable-core-c-asktier.md` and `.harness/evidence/dmc-fable-core-c-critic-r1.json` are the plan + critic verdict (records, land in the separate records commit). Orchestrator staging adds ONLY the 3 scoped files; non-exempt out-of-band dirt is set aside via the established `git stash push -u` procedure for the crosscheck run and restored immediately after.)

## Commands Run

| Command | Result | Reason | Output Summary |
|---|---|---|---|
| `shasum -a 256 <plan>` vs run.json/scope.lock/critic plan_hash | PASS | run binding | all four = `9a706f…1242a` |
| `bash -n .claude/hooks/pre-tool-guard.sh` | PASS | syntax | clean |
| `git diff -- .claude/hooks/pre-tool-guard.sh` | PASS | change correctness | 2 hunks only: C1 insert after COMMAND extraction; C2 inside Block C branch |
| `bash tests/install/test-ask-tier-bypass.sh` | PASS | behavior matrix | 9 passed / 0 failed (8 plan cases + value-blind negctl) |
| manual replay: `npm install`+bypass (fresh mktemp, no mode file) | PASS | case 3, own envelope | rc0, `{"systemMessage":…}` parseable, no ask, exactly 1 log line `… ask-tier-standdown class=install` |
| manual replay: `npm install`+no permission_mode | PASS | fail-closed default | rc0, `"permissionDecision":"ask"`, no `.harness/metrics` dir created |
| manual replay: `git push --force`+bypass | PASS | case 4 deny | deny fired (intercepted at the verifier's own armed Block A floor; inner-hook deny proven by smoke case 4) |
| manual replay: `cat .env`+bypass | PASS | case 5 deny | deny fired (Block A secret floor; inner-hook deny proven by smoke case 5) |
| `bash bin/lib/dmc-v0.1.3-verify.sh` (mode=active) | PASS (rows) | frozen byte-compat | 43 PASS / 2 FAIL — 4 pre-tool-guard behavior rows (`rm-rf deny`, `cat .env deny`, `npm ask`, `benign 0`) ALL PASS; FAILs classified below |
| `bash .harness/evidence/v011-verify.sh` | PASS | UPS parity baseline | 39 PASS / 2 FAIL EXACT registered baseline; `T009 mode-gate md5 unique=1` PASS; active/passive/off npm rows PASS |
| `bin/dmc selftest` | PASS | suite floor | every section 0 FAIL (orient 17, landmarks 13, depsurface 8, radius 7, validate-plan 8, validate-run 6, validate-verification 6, schemas-mirror 15, legacy-mirror 4, recorder 9 — all /0) |
| `bin/dmc mirror-check` | PASS | no stale frozen copy | 55/55 byte-identical, no stray `dmc-v0.*` (frozen fixture hooks-v0.6.5 untouched) |
| `bin/dmc linkcheck` | PASS | reference integrity | clean, 24 files scanned |
| `bin/dmc bash-radius --cmd 'ls -la' / 'touch docs/MILESTONES.md'` | PASS | live allow probe | both `decision:allow`, rc0 |
| out-of-scope write (`… >/dev/null`) under armed run | PASS | live deny probe | `BASH-L1-OUT-OF-SCOPE … adjudicates OUTSIDE the locked scope` (rc4) from the same Ring-0 classifier |
| `git diff --name-only` / `--numstat` | PASS | scope + bounds | 3 in-scope files; +27/+72 tracked, new test 159 lines; 0 deletions |

Classification of the two `dmc-v0.1.3-verify.sh` FAILs (both expected, neither caused by this change): (1) `existing hooks changed: pre-tool-guard.sh` — the working-tree-vs-committed byte compare, expected because the hook edit is uncommitted (it IS this cycle's edit); (2) `GLM/worker code found` — a pre-existing frozen check that predates the v0.2 worker bridge; all matches are worker-bridge guard/installer/manifest files, none of which appear in `git status` (unmodified). The two `v011-verify.sh` FAILs (`active stop block`, `6 existing skills present`) are the registered non-all-pass baseline rows, unrelated to Block C.

## Manual Checks

| Check | Result | Notes |
|---|---|---|
| C1 placement below COMMAND extraction | PASS | `PERMISSION_MODE` at :55, after COMMAND (:49-50), before `deny()` (:57) |
| mode preamble :5-11 byte-untouched | PASS | not in either diff hunk; `T009 mode-gate md5 unique=1` PASS confirms |
| `bypassPermissions` only in Block C | PASS | 4 occurrences: :54 + :146 comments, :152 sole functional equality, :156 message string — all inside Block C (:135-162); no deny-tier line references it |
| Block A/B/D + ask()/deny() helpers untouched | PASS | diff is exactly 2 hunks; Blocks A (:73-126), B (:128-133), D (:164-195) and helpers unchanged |
| else path = byte-identical frozen ask | PASS | :160 ask line appears as unchanged diff context |
| Block C pattern list unchanged | PASS | :137 grep pattern is unchanged context (narrowing honored — no command added/removed) |
| disclosed redirect-order deviation correctness | PASS | `2>/dev/null >> file \|\| true` is genuinely correct and strictly better than the literal `>> file 2>/dev/null`: shell applies redirections left-to-right, so stderr must be pointed at /dev/null BEFORE the append open is attempted for a read-only-dir open error to be swallowed; the literal order would leak that diagnostic. No `set -e` (only `set -u`) + `\|\| true` ⇒ control reaches `exit 0`; smoke case 8 empirically confirms rc0 + systemMessage + no ask under a read-only metrics dir |
| value-blind log | PASS | case 3 line matches `^…Z ask-tier-standdown class=install$`; negctl proves a fake `sk-…` token in the command never enters the log |
| deny floors unaffected by bypass | PASS | smoke cases 4/5 + the verifier's own armed-floor interceptions |
| installer-mirror resolved | PASS | `dmc-install.sh` path-copies the live hook (no embedded payload to sync); `mirror-check` PASS; critic r1 confirms |
| adapters/codex unchanged | PASS/NOTE | `adapters/codex/dmc_codex_common.py` exists and is unmodified — the Block-C Python mirror deliberately NOT updated (registered follow-up, not a silent patch) |
| MILESTONES v1.1.1 entry | PASS | append-only; ordering parenthetical, disclosed narrowing, inert-if-absent posture, Codex-divergence note, and push-gate line all present |

## Scope Review

Result: PASS

Notes: The change touches exactly the 3 scoped files (`.claude/hooks/pre-tool-guard.sh`, `docs/MILESTONES.md`, `tests/install/test-ask-tier-bypass.sh`). Bounds satisfied: 3 files ≤ 3; added 27 (hook) + 72 (MILESTONES) + 159 (new test) = 258 ≤ 450; 0 deletions ≤ 20. No change to any other hook, frozen `dmc-v*` tool, `.harness/schemas/`, `bin/lib/`, `AGENTS.md`, or the Codex adapter. `.codex/config.toml` (pre-existing, unstaged, out-of-band) and the untracked plan + critic-verdict records are correctly outside the change commit. No staging, commit, or push performed; HEAD remains `49a0786`.

## Package / Env / Migration Review

Package files changed: no
Env files changed: no
Migration files changed: no

Notes: The change adds ask-tier awareness of package/migration/publish/schema COMMANDS but edits no package manifests, lockfiles, `.env*` files, or migration files. The advisory log is value-blind (class + UTC timestamp only; command text and any secret-shaped token never recorded — verified by the negative control).

## Unresolved Risks

- (a) Clean-tree `dmc selftest --all` (legacy 802/3/3 EXACT) and the `--full` release gate with the `DMC_GATE_PROTECTED` override (DEFAULT_PROTECTED minus `.claude/hooks`, non-degrading landmark FLAG never suppressed) are PENDING and assigned to the orchestrator post-staging/commit — not run here by design (dirty tree would misread `--all`; `.claude/hooks` is DEFAULT_PROTECTED so the gate needs the G4 override at commit time).
- (b) Run-start arming defect: the run was armed via a manually-compensated procedure (4th cycle occurrence); compensation is probe-proven here (scope.lock immutable/hash-matched; live allow-rc0 / deny-rc4 classifier probes fire correctly).
- (c) Push-gate disclosure (advisory): the MILESTONES entry and plan carry internal codenames, and this branch becomes public on merge — push/CI/main-FF remain a human gate.
- (d) Codex-adapter Block C divergence: `adapters/codex/dmc_codex_common.py` does not yet carry bypass-awareness; registered as a v1.2+ decision, surfaced not silently patched.
- (e) Live `bypassPermissions` delivery by a real bypass-mode session is NOT observed from inside this non-bypass session; the C2 branch is inert-if-absent by design and the evidence makes no false "live-proven" claim.

## Final Status

PASS
