# Plan — v1.0.2 router stabilization: whole-prompt suffix anchor (multi-line defect fix)

Work ID: dmc-v1.0.2-router-anchor

## Goal

Fix the Claude router's multi-line suffix-anchor defect: `.claude/hooks/dmc-router.sh` matches
trigger tokens with line-oriented `grep`/`sed`, so ANY interior line ending with `dmc` /
`dmc-plan` / `dmc-off` routes the whole prompt (observed live twice on 2026-07-09 when pasted
transcripts contained a line-terminal token; scout live-reproduced it in a sandbox). The Codex UPS
shim already has correct whole-string end-of-prompt semantics (Python `re` without MULTILINE) —
this fix RESTORES cross-adapter parity to the documented "suffix-only, exact-token" contract
(`DMC.md:86`), which the current behavior violates for multi-line input. Ships as the first
overnight-envelope cycle (label v1.0.2; no identity sweep — identity stays "Do-Me-Coding v1.0").

## User Intent

bugfix

Overnight autonomy envelope ratified by wjlee (2026-07-09 AskUserQuestion, pre-sleep): three
cycles v1.0.2→v1.0.4 at AUTONOMY.md `autonomous-local-commit` on the dedicated branch
`claude/dmc-v102-v104-overnight`; critic APPROVE mandatory (≤3 rounds else SKIP+record);
independent verifier + committed-replica AND live `selftest --all` legacy 802/3/3 EXACT
mandatory; the router cycle's `.claude/hooks` edit pre-ratified as landmark-authorized with the
G4 `DMC_GATE_PROTECTED` override (v1.0.1 precedent, `.claude/hooks` line dropped only); PUSH /
CI / main-FF are NEVER autonomous — morning human gates (AUTONOMY.md binding).

## Current Repo Findings

(scout lane 2026-07-09, Sonnet explorer; defect live-reproduced)

- Finding: The router matches with `grep -Eqi '(^|[[:space:]])dmc[[:space:]]*$'` and strips with
  line-oriented `sed -E 's/[[:space:]]*[Dd][Mm][Cc]$//'`; even `TRIMMED` uses per-line sed. grep/sed
  anchor `$` per LINE ⇒ interior line-terminal tokens route. Live sandbox repro: prompt
  `"first line dmc\nsecond line, no trigger here"` → router emitted the ultrawork route AND wrote
  the mode file.
  Source: `.claude/hooks/dmc-router.sh:60,67-87`; scout repro transcript.
- Finding: The Codex shim strips with `re.sub(r"\s+$", …)` and matches `(^|\s)dmc\s*$` WITHOUT
  re.MULTILINE — whole-string semantics; the same multi-line prompt does NOT match. The fix is
  one-sided in FILES but parity-RESTORING in BEHAVIOR; the A16 suite gains rows driving BOTH
  adapters on the same multi-line prompts, making the restored parity machine-checked (III.3
  satisfied by the parity suite, not by byte-editing the already-correct shim).
  Source: `adapters/codex/dmc-codex-userpromptsubmit.py:58-76`.
- Finding: NO enforced exact-count assertion exists for test-codex-shims — `bin/dmc`
  `run_m65_suite()` and CI run it pass/fail; the suite gates on its own `FAIL -eq 0`; "99 PASS"
  and "34-row" appear only in historical prose (MILESTONES, v1.0.1 records — append-only, never
  retro-edited).
  Source: `bin/dmc:237-248`; `tests/fixtures/m6.5/test-codex-shims.sh:300-303`; `.github/workflows/dmc-ci.yml:172-173`.
- Finding: New multi-line A16 rows are mechanically possible today: `c_prompt` JSON-encodes via
  python `json.dumps`, so a bash `$'…\n…'` string round-trips as a real multi-line prompt through
  both `claude_run` and `codex_run`.
  Source: `tests/fixtures/m6.5/_m65common.sh:53,66,77,89`.
- Finding: v011-verify (`.harness/evidence/v011-verify.sh`) is a MANUAL known-baseline harness
  (39/2; the 2 FAILs are non-router; NEVER edited, NEVER gated on ALL-PASS). Its 5 router-invariant
  rows (`:59` dmc→ultrawork, `:60` dmc-plan→planning, `:62` negative mid-sentence, `:63`
  env-var-parse literal `DMC_HOOK_INPUT="$INPUT" python3` present, `:67-71` mode-write
  independence) all survive the fix by design — the fix does not touch `json_get`, emit strings,
  or mode writes, and every invariant prompt is single-line.
  Source: `.harness/evidence/v011-verify.sh:59-71`; `.harness/plans/dmc-v1.1-activation-tuning.md:106-111,132`.
- Finding: The frozen `tests/fixtures/hooks-v0.6.5/` router snapshot is pre-M6, already divergent
  from live, and its only comparator (`tests/fixtures/m6/test-rollback.sh`) is UNWIRED from the
  blocking m6-suite — its router row flips red by design (documented at v1.0.1). NOT touched.
  m8 fixtures hash only `.codex/config.toml` foreign-preservation cases — the router is never
  hashed. doctor checks router file EXISTENCE only.
  Source: scout Q3 (quotes `bin/dmc run_m6_suite()`, m8 sha256_of call sites, `dmc-doctor.py:75`).
- Finding: The router's shebang is `#!/usr/bin/env bash`; `[[:space:]]` bracket classes are
  POSIX fnmatch-valid in `case` patterns (the router already uses the class in sed); the v1.0.1
  portability constraint was specifically GNU-sed `s///I` — the fix REMOVES grep/sed from the
  trigger path entirely, going strictly more portable (parameter expansion + `tr` + `case`).
  Source: `.claude/hooks/dmc-router.sh:1,60`; `.harness/verification/dmc-v1.0.1-activation.md:58`.
- Finding: No other file duplicates the trigger regex; all prose descriptions ("suffix-only,
  exact-token") remain accurate — MORE accurate post-fix. The G4 gate-check runner's default
  protected list contains `.claude/hooks` ⇒ the diff trips G4; the envelope pre-ratifies the
  documented `DMC_GATE_PROTECTED` override with ONLY the `.claude/hooks` line dropped (all other
  entries kept verbatim, including the now-inert `dmc-glm-smoke` line); the landmark-flag
  sub-gate's non-degrading FLAG will rise and stay, recorded, never cleared.
  Source: scout Q5; `bin/lib/dmc-v0.2.6-gate-check-runner.sh:21-31`; Constitution V.1–V.3;
  v1.0.1 precedent.

## Relevant Files

| Path | Reason | Allowed to Edit |
|---|---|---|
| `.claude/hooks/dmc-router.sh` | the fix: whole-string trim/match/strip; emit strings BYTE-UNCHANGED | yes |
| `tests/fixtures/m6.5/test-codex-shims.sh` | A16 extension: multi-line parity rows (both adapters) | yes |
| `docs/MILESTONES.md` | ONE v1.0.2 closure entry (append-only) | yes (append) |
| `adapters/codex/dmc-codex-userpromptsubmit.py` | already-correct lockstep counterpart — UNTOUCHED (parity proven by suite) | no |
| `.harness/evidence/v011-verify.sh` | manual known-baseline harness — RUN as proof, never edited | no |
| `tests/fixtures/hooks-v0.6.5/**`, `tests/fixtures/m6/test-rollback.sh` | frozen snapshot + unwired comparator | no |
| `DMC.md`, `CLAUDE.md`, `docs/OMC_COEXISTENCE.md` | prose already correct ("suffix-only"); no edit | no |

## Out of Scope

- Any edit to the Codex shim (its behavior is the parity TARGET), any frozen surface, v011-verify,
  emit-string content, trigger-token precedence, or case-insensitivity semantics.
- Push / CI / main FF (morning human gates — AUTONOMY.md "PUSH and CLOSURE are never autonomous").
- The other two overnight cycles (own plans).

## Proposed Changes

- Change: In `.claude/hooks/dmc-router.sh`, replace the trigger path's line-oriented mechanics
  with whole-string POSIX shell:
  (a) `TRIMMED` via parameter expansion `TRIMMED=${PROMPT%"${PROMPT##*[![:space:]]}"}` (whole-string
  trailing-whitespace strip — newlines included);
  (b) one lowercase copy `LOWER="$(printf '%s' "$TRIMMED" | tr '[:upper:]' '[:lower:]')"`;
  (c) matching via `case "$LOWER" in *[[:space:]]dmc-off|dmc-off) … esac` (same for dmc-plan, dmc;
  precedence order preserved dmc-off > dmc-plan > dmc; exact-token boundary = whitespace-or-start,
  identical to the shim's `(^|\s)`);
  (d) TASK extraction via fixed-length suffix removal on TRIMMED (`${TRIMMED%???}` for dmc, 8 for
  dmc-plan) followed by the same whole-string trailing-strip expansion — case-preserving task text,
  byte-equal to the shim's `re.sub` result for single-line inputs (A16 P-rows assert it);
  (e) emit strings, mode writes, RUN_WARN, json_get (incl. the literal `DMC_HOOK_INPUT="$INPUT"
  python3` the v011 invariant greps) — ALL byte-unchanged;
  (f) header comment gains one line stating the anchor is whole-prompt (multi-line-safe).
  Files: `.claude/hooks/dmc-router.sh`.
  Rationale: root-cause fix (line-oriented tooling), removes the grep/sed dependency from the
  trigger path, restores documented semantics and cross-adapter parity.
- Change: Extend A16 in `tests/fixtures/m6.5/test-codex-shims.sh` with multi-line parity rows
  driven through BOTH adapters on identical prompts: (P-ML1) interior line-terminal token
  `$'refactor this dmc\nand also update docs'` → NO route, NO mode write, both adapters,
  PARITY-equal; (P-ML2) true multi-line suffix `$'first line\nsecond line dmc'` → routes, task
  strips the token only, mode written, PARITY-equal; (P-ML3) interior `dmc-off` line → NO route +
  seeded mode sentinel survives; (P-ML4) token-only final line `$'do the thing\ndmc'` → routes
  (newline is a valid whitespace boundary), PARITY-equal. Fresh per-prompt sandboxes per the
  existing A16 pattern.
  Files: `tests/fixtures/m6.5/test-codex-shims.sh`.
  Rationale: the defect class gets a permanent machine tripwire; parity asserted content-equal.
- Change: Append ONE `docs/MILESTONES.md` entry: "v1.0.2 — router whole-prompt suffix anchor"
  (defect, live observations, fix mechanics, suite extension, overnight-envelope provenance,
  morning-gate pending lines).
  Files: `docs/MILESTONES.md`.

## Acceptance Criteria

- Criterion: Defect closed and parity restored, machine-checked.
  Verification Method: extended `bash tests/fixtures/m6.5/test-codex-shims.sh` → 0 FAIL including
  the new P-ML rows (both adapters, parity-equal); manual repro of the scout's sandbox case →
  router emits NOTHING and writes NO mode file.
- Criterion: Existing behavior byte-stable for single-line prompts.
  Verification Method: all pre-existing A13–A16 rows pass unchanged; emit strings diff-empty
  (`git diff` shows no emit-string hunk); v011-verify run → aggregate 39/2 with the 5 invariant
  router rows green and the SAME 2 known non-router FAILs (never gated ALL-PASS).
- Criterion: No suite/frozen regression.
  Verification Method: `bin/dmc selftest` 0 FAIL; `bin/dmc selftest m65-suite` green;
  `bin/dmc mirror-check` PASS; `bin/dmc linkcheck` clean; hooks-v0.6.5 fixture byte-untouched.
- Criterion: Full gate PASS with the pre-ratified override.
  Verification Method: green set minted on the run binding; `dmc gate release --full` → PASS
  (G4 via `DMC_GATE_PROTECTED` minus the `.claude/hooks` line only; landmark-flag FLAG recorded,
  never cleared).
- Criterion: Frozen baseline intact; LOCAL commit only.
  Verification Method: committed-replica AND live `bin/dmc selftest --all` → legacy **802/3/3
  EXACT**; one commit on `claude/dmc-v102-v104-overnight`; NO push (morning gates: push, CI,
  main FF — recorded as PENDING-BY-ENVELOPE).

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| `case` glob semantics differ from the shim regex on an edge (e.g. tab boundary, token-only prompt) | low | P-ML + existing A16 rows assert content-equality across adapters on every class; executor adds a tab-boundary row if any doubt survives |
| TASK strip byte-diverges from the shim's `re.sub` on odd whitespace | low | fixed-length strip + whole-string trim mirrors `\s*dmc$` exactly for suffix-matched inputs; A16 fingerprint rows compare task segments |
| This session's OWN router changes mid-session | low | the fix only narrows firing; the orchestrating session tolerates either behavior; no reload needed (settings.json untouched, II.6 not implicated) |
| v011 baseline drifts | low | run pre- and post-fix; gate on the 5 invariant rows + the SAME 2 known FAILs; never edit the harness |
| G4 trips on `.claude/hooks` | expected-by-design (low) | envelope-pre-ratified `DMC_GATE_PROTECTED` override, `.claude/hooks` line dropped only (v1.0.1 precedent); landmark-flag stays raised, recorded |

## Assumptions

| Assumption | Confidence | How to Verify |
|---|---|---|
| bash `case` with `[[:space:]]` classes behaves identically on macOS bash 3.2 | high | executor runs the suite on this machine (the target host); pure-POSIX constructs only |
| The envelope satisfies the plan's human-gate requirement | high (ratified verbatim) | recorded in Approval Status; critic adjudicates; SKIP on critic REJECT |

## Execution Tasks

- [ ] DMC-T001: Implement the router fix (Proposed Change 1) + in-place sandbox verification
  (defect repro now negative; single-line cases positive; mode-write matrix).
  Files: `.claude/hooks/dmc-router.sh`.
  Notes: Route: Opus 4.8, synchronous; enforcement landmark.
- [ ] DMC-T002: Extend A16 with the P-ML rows (Proposed Change 2); run the full suite both-adapter
  green; run v011-verify pre/post comparison.
  Files: `tests/fixtures/m6.5/test-codex-shims.sh`.
  Notes: Route: Sonnet 5, synchronous; depends on T001.
- [ ] DMC-T003: MILESTONES v1.0.2 entry; green-set mint; full gate with the pre-ratified override;
  replica + live `--all`; LOCAL commit.
  Files: `docs/MILESTONES.md`.
  Notes: Route: Sonnet 5 for the entry; orchestrator drives gate/commit mechanics.

## Verification Commands

| Command | Reason | Required |
|---|---|---|
| `bash tests/fixtures/m6.5/test-codex-shims.sh` | extended suite 0 FAIL, parity rows green | yes |
| sandbox repro of the multi-line defect prompt | negative now (no emit, no mode write) | yes |
| `bash .harness/evidence/v011-verify.sh` (manual harness, run not edited) | 39/2 with 5 invariant rows green | yes |
| `bin/dmc selftest` + `selftest m65-suite` + `mirror-check` + `linkcheck` | no regression | yes |
| `dmc gate release --full --run-id <run>` | PASS with G4 override + recorded FLAG | yes |
| committed-replica + live `bin/dmc selftest --all` | legacy **802/3/3 EXACT** | yes |
| `git log` on the overnight branch; `git status` clean; NO push | AUTONOMY.md compliance | yes |

## Approval Status

Status: APPROVED
Approver: wjlee (woojin20020@gmail.com)
Approved At: 2026-07-09 (overnight autonomy envelope, AskUserQuestion pre-sleep — cycle menu item
"v1.0.2 라우터 안정화" ratified; G4 override pre-ratified; push/CI/FF reserved to morning gates)
