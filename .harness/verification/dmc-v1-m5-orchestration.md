# Verification Report

## Run ID

dmc-v1-m5-20260706 · sub-task DMC-T010f (M5 integration: bin/dmc wiring + orchestration link-check +
arm-run-id pre-run + regression proof). Branch `claude/dmc-v1-runtime-upgrade-c5uch1`. Date
2026-07-06. Format: VERIFICATION_SCHEMA.md.

## Plan

`.harness/plans/dmc-v1-m5-orchestration.md` (APPROVED 2026-07-06, approver wjlee) — §DMC-T010f,
M5-overall extended block, §Acceptance Criteria, §Verification Commands. This report covers the final
M5 sub-task: the deterministic link-check, the single-owner additive `bin/dmc` wiring of the four M5
verbs + four named selftest sections + `--all` composition, the committed fixtures, the arm-run-id
pre-run, and the whole-milestone regression + rollback proof. It does not alter the master plan's
approval state.

## Changed Files

- bin/lib/dmc-orchestration-linkcheck.py: new — deterministic orchestration link-check over
  `.claude/skills/*/SKILL.md` + `.claude/agents/*.md` + the three registry-pointer docs (verbs vs the
  dispatcher's own case-arm set; `orchestration/*.json` + `.harness/schemas/*.schema.md` paths vs the
  filesystem; `Role: `<id>`` bindings vs roles.json via the dmc-roles.py lookup subprocess). Embedded
  `--self-test` with the negative controls and the arm-run-id pre-run.
- bin/dmc: additive only, and the SOLE M5 edit to this file (single-owner rule) — four verb routings
  (`roles`/`verdict`/`delegation`/`linkcheck`), four named selftest sections, and the `--all` wiring
  after run-core/loop-core. The no-arg default is untouched (stays exactly 9 sections / 75/0).
- tests/fixtures/orchestration/{linkcheck-neg-verb,linkcheck-neg-path,linkcheck-neg-role,
  linkcheck-neg-all,linkcheck-pos}.md: new — the link-check negative + positive control fixtures.
- tests/fixtures/orchestration/arm-run/{plan.md,critic-verdict.json}: new — the approved plan + valid
  plan-bound critic-verdict pair for the arm-run-id pre-run.
- .harness/verification/dmc-v1-m5-orchestration.md: new — this milestone verification report.
- .harness/evidence/dmc-v1-m5-integration.md: new — the T010f evidence write-up.

## Commands Run

| Command | Result | Reason | Output Summary |
|---|---|---|---|
| bash -n bin/dmc | PASS | syntax floor for the edited entry point | clean |
| python3 -m py_compile bin/lib/dmc-{roles,critic-verdict,verdict-gate,delegation,orchestration-linkcheck}.py | PASS | syntax floor for all five M5 modules | clean (pycache swept) |
| bin/dmc linkcheck | PASS | no skill/agent/doc-banner references a nonexistent verb/artifact/role | `OK: linkcheck clean — 24 file(s) scanned`; exit 0 |
| bin/dmc linkcheck --root <tempdir with dangling skill+agent> | PASS | negative control at the CLI | each dangling ref printed `REFUSED: LINK-…` and named; exit 3 |
| bin/dmc selftest roles verdict delegation linkcheck | PASS | the four M5 validator sections incl. all negative controls + arm-run-id pre-run | roles 19/0; verdict-validate 16/0; verdict-gate 9/0; delegation 29/0; linkcheck 17/0; exit 0 |
| bin/dmc selftest; echo $? | PASS | the no-arg default must stay exactly 75/0 (M5 sections are named/--all-only) | 9 sections = 10+11+8+7+8+6+6+15+4 = 75 PASS / 0 FAIL; exit 0 |
| bin/dmc selftest --all (LIVE tree) | FAIL | expected live-tree drift — see Manual Checks + Unresolved Risks | legacy tools=49 PASS=800 FAIL=5 N/A=3; run-core 153/0 + loop-core 78/0 + the four M5 sections PASS; rollback-test FAIL (same cause); SELFTEST-ALL FAIL; exit 1 (known, expected while M5 is uncommitted) |
| bin/dmc selftest --all (committed replica) | PASS | acceptance evidence (M3/M4 precedent: a fully-committed replica) | legacy tools=49 PASS=802 FAIL=3 N/A=3 (== pinned baseline); run-core 153/0 + loop-core 78/0 + roles 19/0 + verdict-validate 16/0 + verdict-gate 9/0 + delegation 29/0 + linkcheck 17/0; rollback-test PASS; SELFTEST-ALL PASS; exit 0 |
| bin/dmc mirror-check | PASS | no dmc-v0.* copy added or altered by the M5 additions | 55/55 byte-identical; "no stray dmc-v0.* copies beyond the pinned 55-file set" |
| grep -RInE 'claude-(opus\|sonnet\|haiku\|fable\|mythos)\|gpt-[0-9]\|codex-[0-9]' orchestration/ .claude/agents/ | PASS | roles.json + agent contracts are model-name-free | empty |
| bin/dmc verdict validate / gate; roles validate / lookup; delegation (routing smoke) | PASS | the new verbs route to the T010a/b/c modules | roles validate + lookup exit 0; verdict validate + gate exit 0; delegation no-arg ⇒ usage exit 2 |
| git status --porcelain (real repo, before/after the arm-run-id pre-run) | PASS | the pre-run is tempdir-only; the real repo must be byte-unchanged | identical (linkcheck self-test A3; confirmed no stray files after all --all / replica / rollback runs) |

## Manual Checks

| Check | Result | Notes |
|---|---|---|
| Real-tree link-check clean | PASS | 24 files scanned; every `dmc <verb>` resolves against the dispatcher case-arm set, every `orchestration/*.json` + `.harness/schemas/*.schema.md` path exists, every `Role: `<id>`` binding resolves in roles.json |
| Link-check negative controls fire and NAME the ref | PASS | `dmc frobnicate` ⇒ LINK-UNKNOWN-VERB; nonexistent schema ⇒ LINK-DANGLING-PATH; unregistered role ⇒ LINK-UNKNOWN-ROLE; combined fixture names all three; positive fixture clean (L2–L6); CLI exit 3 confirmed |
| Verb set derived from the dispatcher itself | PASS | `dispatcher_verbs()` parses bin/dmc's single top-level `case "$cmd" in` block (depth-tracked); L0 asserts it includes roles/verdict/delegation/linkcheck + the core verbs, so checker and dispatcher cannot drift apart |
| Arm-run-id pre-run reaches `run start` and arms a run-id (tempdir) | PASS | A0 fixture integrity (verdict.plan_hash == sha256 plan); A1 gate PASS on the valid pair; A1b gate REFUSE on mismatched plan_hash; A2 `.harness/runs/<run-id>/run.json` appears in the tempdir; A3 REAL repo porcelain byte-identical before/after |
| No-arg default selftest surface unchanged | PASS | exactly the same 9 sections and 75/0 exit 0 as M3/M4; the four M5 sections join only named use + `--all` |
| Committed-replica --all reproduces the pinned baseline + M5 sections | PASS | legacy 802/3/3 EXACT (the 3 FAILs are only v0.1.3/v0.2.3/v0.3.2) + run-core 153/0 + loop-core 78/0 + roles/verdict/delegation/linkcheck PASS + rollback-test PASS + SELFTEST-ALL PASS + exit 0 |
| Rollback dry-run (disposable copy: delete the 5 M5 modules + orchestration/ + fixtures; `git show HEAD:` revert bin/dmc + 5 agents + 3 skills + 3 docs; delete release-auditor.md) | PASS | reverted default selftest = 75 PASS / 0 FAIL exit 0; reverted `bin/dmc linkcheck` ⇒ unknown command exit 2; mirror-check PASS — M5 is cleanly additive/removable |
| Model-name-free invariant | PASS | grep over `orchestration/ + .claude/agents/` empty; scope kept off `bin/` per the T010a detector-file carry-forward (no selftest greps bin/ for model names) |

## Scope Review

Result: PASS

Notes: T010f wrote only its authorized files — `bin/lib/dmc-orchestration-linkcheck.py` (new),
`bin/dmc` (additive four verb routings + four named selftest sections + `--all` wiring; the no-arg
default untouched), `tests/fixtures/orchestration/**` (five link-check fixtures + the arm-run
plan+verdict pair), and the two report files (this report + `.harness/evidence/dmc-v1-m5-integration.md`).
No T010a–e deliverable was edited: the five M5 `bin/lib` modules, the six agents, the three skills,
the three docs, and `orchestration/roles.json` were consumed only (`bin/dmc` is the one file the
single-owner rule reserved for T010f). Not touched: any M4 run-lifecycle module,
`bin/lib/dmc-instance-validate.py`, the copied `dmc-v0.*` originals + their bin/lib copies, the six M3
schema docs, `.claude/hooks/*`, `.claude/settings.json`, `.claude/workers/**`, `.claude/install/*`,
`orchestration/models.json`, `docs/MILESTONES.md`, and main/master. No new `bin/lib/dmc-v0.*`
filename. No git add/commit/push. stdlib-only, env-free (no env reads), offline, secret-path refusal.
No `__pycache__` under `bin/`.

## Package / Env / Migration Review

Package files changed: no
Env files changed: no
Migration files changed: no

Notes: T010f is additive Ring-0 tooling + test fixtures + reports only — no dependency manifest, no
`.env*`, no schema/migration file was touched. No secret path was read, printed, or written; the
link-check and its self-test refuse secret-shaped paths by shape without echoing them.

## Unresolved Risks

- LIVE `bin/dmc selftest --all` returns exit 1 / SELFTEST-ALL FAIL while M5 is uncommitted. This is
  the known, expected live-tree caveat, NOT a defect: the working tree carries tracked-but-uncommitted
  mods (the master-plan approval line, the T010d/e agent/skill/doc edits, and this sub-task's `bin/dmc`
  edit), which trip the pre-M3-vintage v0.5.9 (AC13) and v0.6.0 (V15) working-tree checks — exactly the
  two EXTRA FAILs observed (LIVE legacy = 800/5/3: the 3 pinned upstream FAILs v0.1.3/v0.2.3/v0.3.2
  PLUS dmc-v0.5.9-dynamic-workflow-acceptance.sh and dmc-v0.6.0-verify.sh). The same root cause makes
  the LIVE `rollback-test` FAIL (its originals-alone re-run drifts to 800 too). The committed replica
  (clean tree) restores the pinned 802/3/3 + all M5 sections PASS + rollback-test PASS + SELFTEST-ALL
  PASS + exit 0 and is the acceptance evidence, per the M3/M4 precedent. Resolution: none needed
  pre-commit; the drift disappears once the M5 commit lands.
- The three pinned upstream FAILs (dmc-v0.1.3, dmc-v0.2.3, dmc-v0.3.2 = 3 FAIL) are the accepted M3
  baseline anomaly; the committed replica reproduces 802/3/3 exactly and does not mask or "fix" them.
- Ring-1 enforcement disclosure (carried from T010b/e, not a defect): the verdict-gate refusal is
  Ring-0 (deterministic), but the OBLIGATION to invoke it before mutating is Ring-2 skill prose until
  M6 wires the Stop/scope hooks. M5 makes no claim of runtime traversal enforcement; the link-check
  proves reference integrity, not runtime gating.
- The four M5 selftest sections are heavy-ish (the linkcheck section shells out to dmc-roles.py and,
  in the pre-run, to bin/dmc verdict gate + run start over a tempdir git repo). By the M4
  default-selftest policy they run only when explicitly named and under `--all`, never in the fast
  no-arg default — so the default regression number stays 75/0 for M6+.

## Final Status

PASS
