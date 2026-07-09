# Plan — fable-core Cycle C (v1.1.1): ask-tier bypass-awareness (Block C advisory stand-down under bypassPermissions)

Work ID: dmc-fable-core-c-asktier

## Goal

Remove redundant consent-seeking from the DMC ask-tier WITHOUT weakening any deny floor, any scope
enforcement, or the frozen behavioral baseline:

- **C1 — permission-mode read.** `.claude/hooks/pre-tool-guard.sh` reads the host session's
  `permission_mode` from the PreToolUse hook input (`json_get 'permission_mode'`) — a field the
  hook receives today and currently ignores (verified: zero reads of it anywhere in the hooks).
- **C2 — Block C advisory stand-down under bypass.** In Block C (ask tier, active mode), when the
  matched command is a package/migration/publish/schema pattern AND `permission_mode` is EXACTLY
  `bypassPermissions`, the `ask` is downgraded to an ADVISORY stand-down: exit 0 (allow
  pass-through) + emit a `{"systemMessage": …}` notice naming the matched class + best-effort
  append ONE value-blind line (`<utc-date> <class>` — NEVER the raw command text) to
  `.harness/metrics/ask-tier-advisory.log` (dir gitignored by Cycle D-core; append failure NEVER
  fails the hook). Principle: the ask-tier exists to obtain human consent; `bypassPermissions` is
  the host-native record that the human pre-granted blanket consent for this session — a second
  DMC ask for the SAME consent is redundant friction (the direct source of the "why does DMC keep
  prompting" adoption pain). Deny tiers are NOT consent-seeking and never stand down.
- **Fail-closed default.** `permission_mode` absent, empty, or ANY other value (`default`,
  `acceptEdits`, `plan`, unknown) ⇒ Block C behaves EXACTLY as today (ask fires). This is what
  keeps the frozen baseline green: `bin/lib/dmc-v0.1.3-verify.sh:31` probes the hook with
  `{"tool_input":{"command":"npm install"}}` (no `permission_mode` field) and requires `"ask"` —
  byte-compatible by construction.
- **Explicit non-goals (the moat):** Block A/B deny tiers unchanged in every mode; Block D
  write-radius (rc-3 ask / rc-4 deny) unchanged — write-radius adjudicates SCOPE, not consent, so
  bypass never stands it down; the Block C pattern LIST unchanged (no command added/removed — the
  frozen v0.1.3 fixture pins `npm install` as an ask-class member).

## User Intent

behavioral enforcement change, narrow + additive (memo risk #1 "friction / false-block" mitigation;
the floor/advisory split of memo §6 applied to the ask-tier). The user's Q1 direction this session:
"정말 크리티컬한 경우가 아니거나, 이미 bypass 모드로 실행했다면 ask는 물러나야" — implemented
exactly for the bypass half; the "critical" half stays ask because the frozen baseline pins the
list and the deny floor already owns the truly critical commands.

Authorized THIS session by wjlee via AskUserQuestion envelope (2026-07-09): four cycles
A→D-core→C→B ratified "전체 비준" — critic-APPROVE-conditional auto-approval, LOCAL-commit autonomy
ceiling on `claude/dmc-fable-core`, push/main a separate human gate, 2 consecutive critic REJECTs =
halt + report. The envelope names Cycle C as "ask-tier 재설계: bypass-인식 + Block C 세분화"; the
Block-C-list granularity half was NARROWED during planning to protect the frozen v0.1.3 baseline
(list unchanged; bypass-awareness only) — the critic must confirm this narrowing is sound. Critic
APPROVE is the mandatory pre-build gate (verdicts at
`.harness/evidence/dmc-fable-core-c-critic-r*.json`).

## Current Repo Findings

(grounded 2026-07-09, this session)

- Finding: Block C is `pre-tool-guard.sh:130-135` — fires only when `DMC_MODE=active`; patterns:
  `(npm|pnpm|yarn|bun) publish`, `npm audit fix --force`, `schema push`,
  `migrate (deploy|dev|reset)`, `(npm|pnpm|yarn|bun) install`. `ask()` at `:59-64` emits the
  PreToolUse `permissionDecision:"ask"` envelope.
- Finding: NO hook reads `permission_mode` — `grep -rn permission_mode .claude/hooks/ bin/` = 0
  matches (also confirmed by the session's read-only permission-mechanics investigation, which
  found the field is delivered in the hook input JSON by current Claude Code but never consumed).
  The hook-input reader `json_get` (`:13-36`) already supports top-level keys.
- Finding: the frozen baseline pins Block C behavior for permission-mode-FREE input —
  `bin/lib/dmc-v0.1.3-verify.sh:31`: `printf '{"tool_input":{"command":"npm install"}}' |
  pre-tool-guard.sh | grep -q '"ask"'`. Frozen tools are NEVER rewritten (repo law). A
  fail-closed-default design keeps this probe green; REMOVING install from the list would break it
  permanently — hence the narrowing.
- Finding: `.claude/hooks` IS in the release gate's DEFAULT_PROTECTED set
  (`bin/lib/dmc-v0.2.6-gate-check-runner.sh:22-31`) — gating this cycle requires the G4
  protected-path procedure: landmark-authorized scope.lock + a `DMC_GATE_PROTECTED` override
  (newline list = DEFAULT_PROTECTED minus `.claude/hooks`) supplied at gate time under this
  envelope's human authorization; the non-degrading landmark FLAG cannot and must not be
  suppressed.
- Finding: mode axis vs permission axis are orthogonal today — `.harness/mode=passive` stands the
  whole ask-tier down but ALSO stands down scope-guard/evidence/stop-gate (too coarse to serve as
  the bypass answer); this cycle adds the narrow axis without touching the mode axis.
- Finding: `.harness/metrics/` is created + gitignored by Cycle D-core (sequenced BEFORE this
  cycle on the same branch); the advisory log lands there so it never dirties the tree. If D-core
  were skipped, the log path's parent is still created best-effort by the hook (mkdir -p) and the
  ignore line is a one-line D-core dependency this plan records.
- Finding: hook self-probing is cheap and offline — the hook is a stdin-JSON filter, so every new
  behavior is unit-testable by synthetic envelopes (the v0.1.3 probe pattern), including
  `"permission_mode":"bypassPermissions"` fixtures. LIVE delivery of the field by a real
  bypass-mode session is NOT provable from inside this non-bypass session — the design is
  inert-if-absent, and the evidence records this honestly (no false "live-proven" claim).

## Relevant Files

| Path | Reason | Allowed to Edit |
|---|---|---|
| `.claude/hooks/pre-tool-guard.sh` | C1+C2 — permission_mode read + Block C bypass stand-down (enforcement-class Ring-0 hook, DEFAULT_PROTECTED → landmark_authorized under this envelope; G4 override at gate time) | yes |
| `tests/install/test-ask-tier-bypass.sh` | NEW standalone smoke test (synthetic-envelope fixtures; not wired into selftest — install-wrapper precedent) | yes (new file) |
| `docs/MILESTONES.md` | ONE v1.1.1 entry (append-only) | yes (append) |
| `.claude/install/` hook payload/mirror of `pre-tool-guard.sh` (exact path resolved at T001; only IF such a mirror exists) | keep installer == live hook (never ship a stale guard) | yes (conditional) |
| all other hooks, `bin/`, schemas, frozen `dmc-v*` tools, `AGENTS.md` | untouched | no |

## Out of Scope

- ANY change to Block A/B deny patterns, Block D write-radius, scope-guard, secret-guard,
  evidence-log, stop-verify-gate, or `.harness/mode` semantics.
- ANY change to the Block C pattern list (frozen-baseline pin).
- Downgrading `ask` under `acceptEdits`/allowlist sessions — acceptEdits consents to edits, not to
  arbitrary Bash; the native allowlist is not visible to the hook; only `bypassPermissions` is the
  blanket-consent record. (Registered as a possible v1.2+ question for the pilot's measurement.)
- Any automatic invocation/measurement beyond the one advisory log line.
- Frozen verify scripts and `bin/dmc` (untouched). NOTE the installer-mirror obligation is IN
  scope, not out: if `.claude/install/` ships a byte-copy/payload of `pre-tool-guard.sh`, it MUST
  be synced in this cycle (conditional Relevant-Files row above) — the executor resolves
  existence at T001 and the critic verifies the resolution either way.
- Push / CI / main merge (human gate).

## Proposed Changes

- Change: `.claude/hooks/pre-tool-guard.sh` —
  (1) after `COMMAND` extraction add `PERMISSION_MODE="$(json_get 'permission_mode')"`;
  (2) inside the Block C branch (`:131-135`), when the pattern matches: derive the matched CLASS
  (one of `publish|audit-force|schema-push|migrate|install` via a small case/grep chain — used
  ONLY for the log/notice, never affecting matching); if `[ "$PERMISSION_MODE" = "bypassPermissions" ]`
  → best-effort append `"$(date -u +%Y-%m-%dT%H:%M:%SZ) ask-tier-standdown class=<class>"` to
  `$PTG_PROJECT_DIR/.harness/metrics/ask-tier-advisory.log` (`mkdir -p` the dir; all failures
  swallowed) AND print `{"systemMessage":"DMC advisory: ask-tier stood down under
  bypassPermissions (class: <class>); deny floors remain active."}` then `exit 0`; else `ask` as
  today. NO other block touched; the raw command text never enters the log (value-blind: class +
  timestamp only).
  Files: `.claude/hooks/pre-tool-guard.sh`.
- Change: NEW `tests/install/test-ask-tier-bypass.sh` — standalone offline smoke test (mirrors the
  v0.1.3 probe style; runs the hook from a temp CLAUDE_PROJECT_DIR with `.harness/mode=active`):
  (1) `npm install` + no permission_mode ⇒ `"ask"` (frozen-compat); (2) `npm install` +
  `"permission_mode":"acceptEdits"` ⇒ `"ask"`; (3) `npm install` +
  `"permission_mode":"bypassPermissions"` ⇒ NO `"ask"`, exit 0, systemMessage present, log file
  gains exactly one `class=install` line; (4) `git push --force` +
  `"permission_mode":"bypassPermissions"` ⇒ STILL `"deny"` (floor never stands down); (5) secret
  probe `cat .env` + bypass ⇒ STILL `"deny"`; (6) `migrate reset` + bypass ⇒ stand-down line
  `class=migrate` (consequential class still logged, allowing the pilot to measure whether this
  narrowing was too permissive); (7) mode=passive + no field ⇒ no ask (existing passive semantics
  intact); (8) log-append failure injection (read-only dir) ⇒ hook still exits 0 allowing.
  Files: `tests/install/test-ask-tier-bypass.sh`.
- Change: `docs/MILESTONES.md` — append ONE `## v1.1.1 — ask-tier bypass-awareness — LOCAL
  (2026-07-09)` entry (what/why, the narrowing rationale vs the envelope wording, the honest
  "live bypass delivery not observed in-session; inert-if-absent" line, chain + push-gate-pending).
  Files: `docs/MILESTONES.md`.

## Acceptance Criteria

- Criterion: bypass stand-down works; everything else byte-compatible.
  Verification Method: all 8 smoke-test cases above PASS; additionally the frozen probe replay
  `bash bin/lib/dmc-v0.1.3-verify.sh` → its pre-tool-guard rows ALL PASS under `.harness/mode=active`.
- Criterion: deny floors provably unaffected by bypass.
  Verification Method: smoke cases 4+5 (deny under bypass) PASS; `grep -c 'bypassPermissions'
  .claude/hooks/pre-tool-guard.sh` shows the token appears ONLY inside the Block C branch (no
  deny-tier line references it — proven by line-range inspection in the verification report).
- Criterion: value-blind log.
  Verification Method: smoke case 3's log line matches `^[0-9TZ:-]+ ask-tier-standdown
  class=[a-z-]+$` (no command text); a probe command containing a fake `sk-XXXX` token yields a log
  line WITHOUT that token.
- Criterion: frozen baseline + suites hold.
  Verification Method: `bin/dmc selftest` 0 FAIL; committed-replica AND isolated-live
  `bin/dmc selftest --all` legacy **802/3/3 EXACT** (run with `.harness/mode=active`; the
  mode-coupling gotcha is registered); `bin/dmc mirror-check` PASS; hook-mirror question resolved
  with evidence (mirror synced or proven absent).
- Criterion: G4 protected-path gate discipline.
  Verification Method: `dmc gate release --full --run-id <run>` with `DMC_GATE_PROTECTED` set to
  DEFAULT_PROTECTED-minus-`.claude/hooks` (newline list, constructed in the evidence log verbatim)
  → PASS with the non-degrading landmark FLAG present (never suppressed); the override construction
  + envelope authorization quoted in the build evidence.
- Criterion: scope + autonomy ceiling.
  Verification Method: change-commit `git diff --name-only` == exactly the in-scope files (2 or 3
  with the conditional mirror); records commit only plan/verdicts/verification/evidence; both
  commits LOCAL on `claude/dmc-fable-core`; NO push; `.codex/config.toml` stays unstaged.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| A host that never sends `permission_mode` makes C2 dead code | low | inert-if-absent BY DESIGN (fail-closed to ask); honestly recorded; the advisory log measures real firings for the pilot |
| Stand-down too permissive for `migrate reset` under bypass | medium | bypass = the human's own blanket grant; the deny floor still owns catastrophic forms (`prisma migrate reset` is ALREADY Block A deny — verified `:73`); the advisory log records every stand-down for pilot review; narrowing to consent-redundancy only |
| Hook edit breaks the frozen v0.1.3 rows or the 34-row UPS parity surface | high | fail-closed default preserves permission-mode-free behavior byte-for-byte; frozen verify replay + full `--all` 802/3/3 EXACT are blocking ACs |
| Installer ships a stale hook copy | medium | explicit mirror check task; conditional scope row; mirror-check AC |
| systemMessage JSON malformed breaks the hook envelope | low | reuse the existing `json_string` helper for the message; smoke case asserts parseable output |
| Protected-path gate misuse precedent | medium | G4 override quoted verbatim + envelope authorization cited in evidence; FLAG never suppressed; critic reviews the construction |

## Assumptions

| Assumption | Confidence | How to Verify |
|---|---|---|
| Claude Code delivers `permission_mode` in PreToolUse input on current CLI | medium-high (docs + investigation) | design is inert-if-absent; post-build the user can observe one live stand-down in a bypass session (recorded as pilot follow-up, not an AC) |
| `date -u` + `mkdir -p` available in hook context | high | smoke test runs the real hook binaryless path |
| D-core's `.harness/metrics/` ignore line lands before this cycle | high (sequenced A→D→C→B) | if D-core halted, add the same ignore line IN SCOPE here (conditional, recorded) |

## Execution Tasks

- [ ] DMC-T001: implement the `pre-tool-guard.sh` change (C1+C2) exactly as specified; resolve the
  installer-mirror question (`grep -rn pre-tool-guard .claude/install/ bin/lib/dmc-skills-mirror.py
  bin/lib/dmc-doctor.py`); sync the mirror if one exists.
  Files: `.claude/hooks/pre-tool-guard.sh` (+ conditional mirror path).
  Notes: Route: Opus 4.8, synchronous (Ring-0 guard; deep effort per EFFORT_POLICY).
- [ ] DMC-T002: write + run `tests/install/test-ask-tier-bypass.sh` (8 cases); replay
  `bin/lib/dmc-v0.1.3-verify.sh`; run `bin/dmc selftest`.
  Files: `tests/install/test-ask-tier-bypass.sh`.
  Notes: Route: Opus 4.8, synchronous; depends on T001.
- [ ] DMC-T003: MILESTONES v1.1.1 entry; independent verification (fresh Opus verifier lane) →
  `.harness/verification/<run-id>.md`; build evidence
  `.harness/evidence/dmc-fable-core-c-build-20260709.md` (incl. the G4 override construction +
  isolated-live 802/3/3); full gate with `DMC_GATE_PROTECTED` override; change commit + records
  commit (LOCAL; targeted `git add`; `.codex/config.toml` unstaged).
  Files: `docs/MILESTONES.md` (+ records, scope-exempt).
  Notes: Route: docs Sonnet 5; verifier Opus 4.8 fresh lane; commits by orchestrator under the
  envelope grant.

## Verification Commands

| Command | Reason | Required |
|---|---|---|
| `bash tests/install/test-ask-tier-bypass.sh` (8/8) | C2 behavior matrix incl. floor-never-stands-down | yes |
| `bash bin/lib/dmc-v0.1.3-verify.sh` (mode=active) | frozen baseline byte-compatibility | yes |
| `bin/dmc selftest`; committed-replica + isolated-live `bin/dmc selftest --all` = 802/3/3 EXACT | suite floor + the known mode/env gotchas | yes |
| `bin/dmc mirror-check`; installer-mirror grep evidence | no stale hook copy ships | yes |
| `dmc gate release --full --run-id <run>` + DMC_GATE_PROTECTED override (constructed verbatim in evidence) | G4 protected-path discipline, FLAG present | yes |
| `git diff --name-only` per commit; no push; `.codex/config.toml` unstaged | scope + autonomy ceiling | yes |

## Approval Status

Status: APPROVED
Approver: wjlee (woojin20020@gmail.com)
Approved At: 2026-07-09 (this-session AskUserQuestion envelope "전체 비준": cycles A→D-core→C→B,
critic-APPROVE-conditional, LOCAL-commit autonomy ceiling on `claude/dmc-fable-core`, push/main a
separate human gate, 2 consecutive critic REJECTs → halt + report). The in-plan NARROWING of the
envelope's "Block C 세분화" (list unchanged to protect the frozen baseline; bypass-awareness only)
is disclosed above and stands unless the critic finds it unsound or the user overrides. Critic
APPROVE is the mandatory pre-build gate; this plan is not built unless a schema-valid APPROVE
verdict binds this file's sha256 via `bin/dmc verdict gate`.

Revisions: Rev 1 (initial).
