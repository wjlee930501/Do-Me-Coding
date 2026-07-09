# Plan — fable-core Cycle A: succession repair (strategy memo tracked + no-subagent fallback)

Work ID: dmc-fable-core-a-succession

## Goal

Close the three succession gaps found by the 2026-07-09 orchestration audit (read-only, two-lane:
permission-mechanics + weight/essence/maintainability), as a DOCS-ONLY change — no code, no
enforcement, no schema, no generated-artifact change:

- **A1 — track the strategic memo with a dated status banner.** The forward-looking strategy
  document `.harness/plans/dmc-refinement-diagnosis-20260709.md` is UNTRACKED (`git status` `??`) —
  a fresh clone loses the entire "what's next" (risk register, pilot recommendation, §9 decision
  questions). Additionally two of its grounded facts are now STALE (superseded by v1.0.5
  `1cdb357`): memo lines 7-10 and risk #6 (line 60) still claim `AGENTS.md` = 32,490 B / 278 B
  under the Codex cap / list emitted twice — the file is **24,126 B today** (verified `wc -c`,
  2026-07-09) with the §5 dedup + inventory-last reorder + count-parity guard shipped. Fix by
  PREPENDING one dated status-update banner (blockquote) directly under the memo's header line —
  the original prose below stays byte-identical (append-style correction, never rewrite dated
  analysis) — then `git add` the file so it ships in this cycle's commit.
- **A2 — no-subagent degradation rule in the handoff.** `docs/DMC_AGENT_HANDOFF.md` structurally
  assumes subagent spawning (fresh-context critic/verifier lanes per `orchestration/roles.json`),
  but documents NO procedure for a runner that cannot spawn subagents (Codex App, bare CLI, a
  future host). Add one compact section to the quick-card: on such hosts the critic/verifier passes
  MUST still be non-authoring fresh contexts (a separate session/CLI invocation reading only the
  artifact paths); if a separate context is impossible, STOP at the gate and surface to the human
  (fail-closed, Art. VIII escalation duty) — never self-approve in the authoring context.
- **A3 — trajectory-lives-in-the-repo rule.** Same handoff section carries the practice rule:
  forward-looking strategy/trajectory documents are committed to the repo (with a
  pending-decisions banner when gates are open), never kept solely in out-of-repo agent memory —
  agent memory is an accelerator, not the source of truth.

## User Intent

docs / succession hardening ("Fable 5 구독 종료 전 핵심 최적화 코어" 지시의 1번 사이클).

Authorized THIS session by wjlee via AskUserQuestion envelope (2026-07-09): four cycles
A→D-core→C→B ratified as "전체 비준" — critic-APPROVE-conditional auto-approval per cycle,
autonomy through the LOCAL commit gate on the dedicated branch `claude/dmc-fable-core`, push /
main merge reserved to a separate human gate, two consecutive critic REJECTs = halt the cycle and
report. Critic APPROVE is the mandatory pre-build gate for this plan (verdict persisted under
`.harness/evidence/dmc-fable-core-a-critic-r*.json`, validated via `bin/dmc verdict validate`,
bound via `bin/dmc verdict gate` before any run is armed).

## Current Repo Findings

(grounded 2026-07-09, this session)

- Finding: memo is untracked — `git status --short` shows
  `?? .harness/plans/dmc-refinement-diagnosis-20260709.md`; handoff rev 14 (D)(5) records it as
  "deliberately not committed; §9 decision questions pending". The user's envelope ratification
  supersedes the tracking decision; **§9 itself remains UNANSWERED** and the banner must say so —
  tracking the memo does not answer its decision questions.
- Finding: stale memo facts — memo lines 7-10 ("32,490 bytes — 278 bytes under", "~71% is landmark
  inventory", "emitted twice") and risk #6 line 60 (same claims) predate v1.0.5. Actual:
  `wc -c AGENTS.md` = **24,126** (8,642 B headroom); v1.0.5 (`1cdb357` change + `cbcfb2f` records)
  shipped dedup §5 + inventory-last [1,2,3,6,7,8,9,10,4,5] + count-parity guard. Memo §7's
  "optional quick win" (Q7) is therefore ALREADY SHIPPED as a standalone cycle.
- Finding: every OTHER memo grounded-fact was re-verified current by the 2026-07-09 audit:
  repo-intel walk still unbounded (`bin/lib/dmc-repo-intel.py:111-123`, no timeout/cap/gitignore),
  run-metrics still dormant (schema + validator exist, zero callers, no ledger appender), installer
  still full-only. The banner corrects ONLY the AGENTS.md facts.
- Finding: handoff contains zero occurrences of a no-subagent procedure (`grep -c "no-subagent\|
  without subagent"` = 0); the roles registry (`orchestration/roles.json`) requires fresh-context
  non-authoring critic/verifier lanes; `docs/DMC_CONSTITUTION.md` Art. VIII imposes the escalation
  duty ("the weaker the maintainer, the smaller the permitted step and the sooner the escalation").
- Finding: the handoff's own log rule ("Do NOT rewrite or delete prior revs — only append", line
  113-114) and the roles banner ("This banner is additive — the state machine, gate rules, and
  prompt templates below are unchanged") permit ADDITIVE quick-card sections; A2/A3 add one section
  and modify no existing template, state-machine row, or rev.
- Finding: scope-guard exempts `.harness/evidence/` and `.harness/verification/` writes during an
  armed run (`.claude/hooks/scope-guard.sh:154-163`), so this cycle's records need no scope
  entries; the two content files below are the entire mutation scope.
- Finding: `.harness/mode` = `active`; no active run (`bin/dmc run status` → RUN-NO-ACTIVE);
  branch `claude/dmc-fable-core` created at `62fe79c` (= handoff rev 14 commit).

## Relevant Files

| Path | Reason | Allowed to Edit |
|---|---|---|
| `.harness/plans/dmc-refinement-diagnosis-20260709.md` | A1 — prepend dated status banner; file becomes tracked in this cycle's commit | yes |
| `docs/DMC_AGENT_HANDOFF.md` | A2/A3 — add one additive quick-card section (no-subagent degradation + trajectory rule) | yes |

## Out of Scope

- Answering ANY memo §9 decision question (pilot repo, sample, thresholds, tagging, Codex posture)
  — those remain a human gate; the banner states this explicitly.
- Any code, enforcement, hook, gate, schema, installer, or generated-artifact
  (`AGENTS.md`/repo-intel) change — Cycles B/C/D-core own those.
- Rewriting ANY existing memo prose below the banner (append-style correction only) or ANY
  existing handoff rev/template/state-machine content (additive section only).
- `docs/MILESTONES.md` — docs-only cycle, follows the rev-14-commit precedent (no milestone entry;
  the envelope's closure record lands at session end).
- `docs/DMC_CONSTITUTION.md` (memo non-goal: the pilot/experiment layer never grows the
  constitution).
- Push / CI / main merge (human gate).

## Proposed Changes

- Change: `.harness/plans/dmc-refinement-diagnosis-20260709.md` — insert, directly after the H1
  title line and its `_Strategic memo …_` intro line, ONE blockquote banner:
  `> **Status update (2026-07-09, post-v1.0.5 — appended by fable-core Cycle A; original analysis
  below is unmodified):**` followed by 4-5 bullet lines: (1) risk #6 / grounded-fact AGENTS.md
  claims are RESOLVED-STALE — v1.0.5 (`1cdb357`) shipped dedup+reorder+count-parity; `AGENTS.md`
  now 24,126 B (8,642 B headroom); §7's Q7 quick win = SHIPPED standalone; (2) all other grounded
  facts re-verified current 2026-07-09 (repo-intel unbounded, run-metrics dormant, installer
  full-only); (3) **§9 decision questions remain PENDING a human gate** — tracking this memo does
  not answer them; (4) the 2026-07-09 ratified fable-core envelope addresses §7-1 (run-metrics
  wiring = Cycle D-core), risk #7 (repo-intel bounding = Cycle B), and risk #1 friction (ask-tier
  granularity = Cycle C) as infrastructure, leaving pilot execution to §9.
  Files: `.harness/plans/dmc-refinement-diagnosis-20260709.md`.
- Change: `docs/DMC_AGENT_HANDOFF.md` — add one section titled
  `## Runners without subagents — degradation rule (added 2026-07-09)` positioned after the
  "Fail-closed checklist" section and before "Anti-token-max reminder": (a) the critic and
  verifier lanes stay NON-AUTHORING and FRESH-CONTEXT even where subagent spawning is unavailable
  — run each as a separate session/CLI invocation whose input is only the artifact paths (plan,
  diff, run dir), never the authoring conversation; (b) if a genuinely separate context cannot be
  obtained, STOP at that gate and surface to the human (fail-closed; Constitution Art. VIII
  escalation duty) — self-approval in the authoring context is never a fallback; (c) trajectory
  rule: forward-looking strategy/trajectory documents live IN the repo (committed, with a
  pending-decisions banner while gates are open), never solely in out-of-repo agent memory — memory
  accelerates a successor, the repo is the source of truth.
  Files: `docs/DMC_AGENT_HANDOFF.md`.

## Acceptance Criteria

- Criterion: memo banner present, original prose preserved, file tracked.
  Verification Method: `grep -c 'Status update (2026-07-09' <memo>` = 1 AND the pre-existing stale
  lines still present verbatim below it (`grep -c '32,490 bytes' <memo>` ≥ 1 AND
  `grep -c 'emitted twice' <memo>` ≥ 1 — both line-7 and risk-#6 stale blocks preserved, corrected
  only by the banner) AND banner contains "PENDING" for §9 AND after the change commit
  `git ls-files` lists the memo.
- Criterion: handoff gains exactly one additive section; nothing existing changes.
  Verification Method: `grep -c '^## Runners without subagents' docs/DMC_AGENT_HANDOFF.md` = 1;
  section body greps (case-insensitive): `grep -ci 'fresh'` ≥ 1 AND `grep -ci 'STOP'` ≥ 1 AND
  `grep -c 'Art. VIII'` ≥ 1 AND `grep -ci 'source of truth'` ≥ 1 (all scoped to the new section's
  line range); `git diff <change-commit>^..<change-commit> -- docs/DMC_AGENT_HANDOFF.md` shows NO
  `-` lines except the `---` file header (pure insertion; space-prefixed context lines are
  expected and fine); rev-14 block byte-unchanged.
- Criterion: docs floor green.
  Verification Method: `bin/dmc selftest` → 0 FAIL; `bin/dmc linkcheck` → clean (no broken
  references introduced).
- Criterion: scope discipline + autonomy ceiling.
  Verification Method: `git diff --name-only` across the change commit == exactly the 2 in-scope
  files; the records commit adds only `.harness/plans/dmc-fable-core-a-succession.md` +
  `.harness/evidence/dmc-fable-core-a-*` + `.harness/verification/<run-id>.md`; both commits LOCAL
  on `claude/dmc-fable-core`; NO push.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Tracking the memo read as answering §9 | low | banner states §9 PENDING explicitly; Out of Scope pins it |
| Banner edit accidentally rewrites original memo prose | low | append-style: single blockquote insertion; AC greps prove original stale lines still present |
| Handoff edit collides with additive-only log rule | low | one new section; AC diff-check proves additions-only |
| Docs drift (handoff vs memo vs MILESTONES) | low | banner cross-references v1.0.5 shas recorded in MILESTONES; linkcheck green |

## Assumptions

| Assumption | Confidence | How to Verify |
|---|---|---|
| Envelope ratification covers tracking the memo (supersedes rev-14 "user's call") | high | recorded this session (AskUserQuestion 전체 비준); halt on critic challenge |
| Docs-only change cannot move selftest counts | high | `bin/dmc selftest` at build time |

## Execution Tasks

- [ ] DMC-T001: memo — insert the dated status banner (A1) exactly as specified in Proposed
  Changes; verify greps.
  Files: `.harness/plans/dmc-refinement-diagnosis-20260709.md`.
  Notes: Route: Sonnet 5, synchronous (docs edit, additive).
- [ ] DMC-T002: handoff — add the `## Runners without subagents — degradation rule` section
  (A2+A3) exactly as specified; verify greps + additions-only diff.
  Files: `docs/DMC_AGENT_HANDOFF.md`.
  Notes: Route: Sonnet 5, synchronous (docs edit, additive).
- [ ] DMC-T003: run verification (independent verifier lane) → `.harness/verification/<run-id>.md`;
  write build evidence `.harness/evidence/dmc-fable-core-a-build-20260709.md`; then change commit +
  records commit (LOCAL only).
  Files: (records paths — scope-exempt).
  Notes: Route: verifier = Sonnet 5 fresh lane, non-authoring; commits executed by orchestrator
  post-verification under the envelope's local-commit grant. STAGING WARNING (critic r1 advisory):
  the working tree carries a pre-existing, unrelated ` M .codex/config.toml` — stage with TARGETED
  `git add <path> <path>` only (never `-A`/`-u`/`.`); `.codex/config.toml` must remain unstaged in
  both commits.

## Verification Commands

| Command | Reason | Required |
|---|---|---|
| `grep -c 'Status update (2026-07-09' <memo>` = 1; `grep -c '32,490 bytes' <memo>` ≥ 1; `grep -c 'emitted twice' <memo>` ≥ 1; banner grep 'PENDING' | A1 correctness: banner added, BOTH stale blocks preserved, §9 pending stated | yes |
| `grep -c '^## Runners without subagents' docs/DMC_AGENT_HANDOFF.md` = 1 + case-insensitive body greps (`grep -ci` fresh/stop/source of truth; `grep -c 'Art. VIII'`) | A2/A3 present | yes |
| change-commit diff on handoff: NO `-` lines except the `---` file header; rev-14 block unchanged | additive-only rule honored (pure insertion) | yes |
| `bin/dmc selftest` 0 FAIL | regression floor (docs cannot regress code, prove it anyway) | yes |
| `bin/dmc linkcheck` clean | no broken doc references | yes |
| `git diff --name-only` per commit == approved sets; `git log` shows 2 LOCAL commits; no push | scope + autonomy ceiling | yes |

## Approval Status

Status: APPROVED
Approver: wjlee (woojin20020@gmail.com)
Approved At: 2026-07-09 (this-session AskUserQuestion envelope "전체 비준": cycles A→D-core→C→B,
critic-APPROVE-conditional, LOCAL-commit autonomy ceiling on `claude/dmc-fable-core`, push/main a
separate human gate, 2 consecutive critic REJECTs → halt + report). Critic APPROVE is the mandatory
pre-build gate; this plan is not built unless a schema-valid APPROVE verdict binds this file's
sha256 via `bin/dmc verdict gate`.

Revisions: Rev 1 → critic r1 NEEDS_CLARIFICATION (1 blocker,
`.harness/evidence/dmc-fable-core-a-critic-r1.json`): B1 = AC2's case-sensitive `grep 'fresh'`
contradicts the specified uppercase 'FRESH-CONTEXT' body text (a faithful build fails its own AC).
Rev 2 folds the fix: AC2 body greps made case-insensitive (`grep -ci`); additive-only check
restated as "no `-` lines except the `---` file header"; AC1 gains the risk-#6 'emitted twice'
history-preservation grep; T003 gains the targeted-`git add` staging warning (pre-existing dirty
`.codex/config.toml` stays unstaged). Re-submitted for a fresh critic pass (r2).
