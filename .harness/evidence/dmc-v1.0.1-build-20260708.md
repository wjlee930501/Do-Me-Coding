# Build Evidence — DMC v1.0.1: Natural-Activation Tuning (2026-07-08)

Run `dmc-run-313080b9af69` (10-grant scope.lock, state_hash `c85ff88a…`, immutable, compiled at
HEAD `186ed8c`). Plan `.harness/plans/dmc-v1.1-activation-tuning.md` Rev 2 APPROVED (plan_hash
`3bfa1f27…`; critic r1 REJECT [B1 unsatisfiable v011 gate + B2 task-token leak — both empirically
proven] → Rev 2 fold → r2 APPROVE 0 blockers; human gate 2026-07-08: greeting=dmc-only, release
label=**v1.0.1** [human chose patch over the recommended v1.1 — plan filename/work_id
`dmc-v1.1-activation-tuning` is a drafting-time identifier, not a version claim], full gate=YES).

## What shipped (DMC-T018.1–.5)

4 synchronous scoped executors (Opus: T018.1 lockstep + T018.2 parity test; Sonnet: T018.3 docs +
T018.4 MILESTONES) + the orchestrator lane (T018.5):

- **T018.1 (Opus)** — router + Codex shim LOCKSTEP: case-insensitive matchers (`grep -Eqi` /
  `re.IGNORECASE`, anchors byte-unchanged → mid-sentence never fires), case-insensitive
  task-extraction strips (portable char-class sed `[Dd][Mm][Cc]` — BSD sed has no `s///I`;
  `flags=re.IGNORECASE` on both re.sub), the dmc-branch emit gains the exact signature
  `Okay, Let me do you Coding!` + the DMC PRIORITY clause (OMC/OMO/LazyCodex named) with a
  BYTE-IDENTICAL shared prefix across both adapters (verifier-assembled and confirmed); parser
  line :14 + dmc-off/dmc-plan emits untouched (greeting dmc-only per the gate).
- **T018.2 (Opus)** — NEW `A16 — UPS cross-adapter parity` section in
  tests/fixtures/m6.5/test-codex-shims.sh: **34 rows** driving BOTH hosts with the same prompts
  (lowercase / mixed-case / `해줘. DMC` shape / mid-sentence negative / DMC-OFF / DMC-PLAN),
  asserting emit CONTENT (signature, priority, route tokens), CLEAN task extraction (r2-A5
  shape-robust extract+equality + `! grep` no-leak), mode-file writes, and cross-adapter content
  parity; FRESH per-prompt sandboxes + seeded-sentinel survival for the mode-unchanged cases
  (r1-A2). Closes the zero-tripwire UPS parity gap — now CI-BLOCKING via m65-suite.
- **T018.3 (Sonnet)** — DMC.md (case-insensitive wording + mixed-case example), CLAUDE.md
  (wording + DMC-PRIORITY paragraph — ships verbatim to hosts), OMC_COEXISTENCE.md (wording +
  NEW `## Precedence when both fire` anchored at the Observed callout), dmc-ultrawork/SKILL.md
  (UNCONDITIONAL signature line — covers direct `/dmc-ultrawork`), DMC_V1_HONEST_SCOPE.md §4
  (DMC-priority = instruction-level best-effort, not a runtime boundary).
- **T018.4 (Sonnet)** — MILESTONES.md `## v1.0.1 — Natural-Activation Tuning — CLOSED
  (2026-07-08)` (42+/0− pure append).

## Verification (non-authoring verifier PASS — `.harness/verification/dmc-v1.0.1-activation.md`)

LP1 live router probes **10/10** (orchestrator) + **13/0** (verifier) — signature/priority/clean
extraction/mode writes/mid-sentence negative; Codex shim direct probes **12/0**;
m65-suite green with test-codex-shims **99/0** (65 pre-existing + 34 A16); default selftest 0
FAIL; m6-suite green (frozen fixture untouched); mirror-check PASS; linkcheck clean;
v011-verify **39/2 EXACTLY** — the 2 FAILs are the pre-existing non-router rows (`active stop
block` v011:31, `6 existing skills present` v011:77), identical on unpatched HEAD (critic-B1
known-baseline delta; v011 never edited). Diff 9 tracked files +177/−20 ⊆ 10-grant scope.
Expected `test-rollback.sh` router-row drift documented (unwired pre-M6 manual proof).
r2-A6 note recorded: the strip char-classes are LOAD-BEARING (do not "tighten" them back).

## Full release gate (ratified GATE-DECISION)

Green evidence set minted (verify-plan + 3 receipts CHK-V101-{LOCKSTEP,PARITY,DOCS} +
findings/goal/decision + approvals: plan_approval + release with verification_ref → the VALID
verifier report); 10 staged == scope.lock set (evidence files unstaged — M10 G2/G3 lesson).

**FIRST gate run: FAIL on gate-checks G4 "protected path changed: .claude/hooks"** — the frozen
v0.2.6 commit gate's DEFAULT protected list includes `.claude/hooks`, and this is the first full
gate ever run over an authorized hook change (M6 predates the composer; M10 touched no hook).
Disposition: the v0.2.6 tool's own DESIGNED override was used —
`DMC_GATE_PROTECTED` (documented at dmc-v0.2.6-gate-check-runner.sh:21 and docs/DMC_GATE_CHECKS.md)
set to the default list MINUS `.claude/hooks` ONLY (all 9 other protected entries kept: glm-api,
oauth-cli, provider-router, ROUTING/PROVIDER_CONTRACT, 3 worker schemas, dmc-glm-smoke). The hook
change's authorization chain: human-gated plan + scope.lock `landmark_authorized` on both
enforcement-class files + critic r1/r2 + independent verifier PASS. No frozen tool was edited; the
override is env-scoped to the single gate invocation. Re-run:

**`dmc gate release --full --run-id dmc-run-313080b9af69` → verdict PASS, exit 0 — 9/9 sub-gates
(gate-checks PASS under the documented override), landmark-flag = FLAG on exactly the 3 authorized
landmarks (router, shim, MILESTONES) — review markers, never failures.**

Disclosure completeness (critic-r3 A7/A8): (A7) `release-readiness.json` is WRITE-ONCE — the first
G4-FAIL readiness was REMOVED to re-gate and is NOT archived as a JSON; this prose section is the
record of that FAIL (the material fact — enforcement landmarks changed and require review — is
independently preserved in the PASS readiness's landmark-flag, which `DMC_GATE_PROTECTED` cannot
suppress: sg_landmark derives FLAGs without consulting it). (A8) PRECEDENT GUARDRAIL: removing
`.claude/hooks` from `DMC_GATE_PROTECTED` is legitimate ONLY under a landmark-authorized scope.lock
+ human plan gate + critic/verifier chain, as here — this record MUST NOT be cited to bypass G4
for an unauthorized hook change; the independent landmark-flag remains the structural backstop.

## Closure verdicts

- Independent verifier: `.harness/verification/dmc-v1.0.1-activation.md` — Final Status PASS.
- Critic r3 build sign-off: `.harness/evidence/dmc-v1.0.1-critic-r3.json`.
- Committed-replica `selftest --all`: `aggregate: tools=49 PASS=801 FAIL=4 N/A=3` — EXACTLY the
  documented /tmp-clone baseline (pinned v0.1.3×1 + v0.2.3×1 + v0.3.2 AC5, plus the v0.3.2 AC4
  clone-environment artifact; pristine-clone delta = ZERO). The v1.0.1 changes add no legacy
  regression — as scout lane 1 predicted (the router is outside the 55-file frozen mirror).
- Live post-commit `selftest --all` (commit `f819fa3`, real dev tree): `aggregate: tools=49
  PASS=802 FAIL=3 N/A=3` — **legacy 802/3/3 EXACT**, `SELFTEST-ALL RESULT: PASS`, exit 0. The
  frozen baseline is intact through v1.0.1 (CF1 honored; the router edit proven outside the
  frozen surface, exactly as scout lane 1 predicted).
- CI: Actions run `28928976825` on commit `f819fa3` — **conclusion=success** (all 15 blocking
  steps green incl. m65-suite with the new A16 parity rows).
- main unification: fast-forwarded `186ed8c..f819fa3` (ff-safety pre-checked); origin/main ==
  local main == branch HEAD == `f819fa3`. **v1.0.1 complete and unified on main.**
