# Build Evidence — v1.1.7 bash-radius safe-sink allowlist + L1-AMBIGUOUS ask→deny (dmc-v1.1.7-safesink-askdeny)

Date: 2026-07-10 · Branch: `claude/dmc-fable-core` · Base: `d02062c` (v1.1.5+v1.1.6 deployed to main same day) · **Change commit: `4b4d3c6`** (+395/−32: `bin/lib/dmc-bash-radius.py` 150/26, `bin/dmc` 3/1, `docs/DMC_V1_ENFORCEMENT_MATRIX.md` 1/1, `docs/MILESTONES.md` 59/0, `tests/fixtures/m6/test-adversarial.sh` 5/4, `tests/install/test-v1.1.7-safesink-askdeny.sh` 177 new).
Work ID: `dmc-v1.1.7-safesink-askdeny` · Driver: the user's no-prompts/e2e-autonomy directive (2026-07-10), issued after a worker's `2>&1` probe stalled the session for HOURS on an unattended L1-AMBIGUOUS ask confirmation · Authorization: user directives 2026-07-10 ("3번도 착수하자" + the no-prompts directive fixing this exact scope) · Autonomy ceiling: LOCAL commit; **push/CI/main-FF NOT pre-authorized for this cycle — pending the human gate.**

## What shipped

The Block D write-radius classifier no longer emits unattended human-stalling `ask` verdicts:
1. **Safe sinks ALLOW**: `/dev/null`, `/dev/stderr`, `/dev/stdout` (exact-set) + `/dev/fd/<n>` (anchored `^/dev/fd/[0-9]+$`, no prefix matching) classify as no-write.
2. **fd-duplication is not a write**: the split-segments guard keeps `>&`/`N>&` coherent (previously mis-segmented into a dangling empty-target `2>` → ambiguous → ask) and the FDDUP_RE companion in `_redirect_targets` drops ONLY numeric/`-` operands; ANY other `>&`/`N>&` operand surfaces as a real adjudicated file write target (out-of-scope DENY / in-scope ALLOW).
3. **ask→deny**: every residual L1-AMBIGUOUS verdict (python -c / sh -c payloads / $(...) / globs / undecidable idioms) returns DENY exit 4 fail-fast with the fail-closed-reworded BASH-L1-AMBIGUOUS reason. NO-ASK invariant: no L1 input can yield exit 3. Deny floors (L0 git-apply, incl. combined with `2>&1`) and the Block C consent tier untouched. Internal wrapper 'ask' signal CODE kept (funnel integrity — critic-ruled); comments/docstrings clarified to the net armed DENY. Docs in lockstep (ENFORCEMENT_MATRIX, bin/dmc help, module docstrings, the m6 adversarial suite's stale W4 expectation).

## Chain (2 armed runs, 4 critic rounds — the highest-scrutiny cycle of the envelope)

| Stage | Evidence |
|---|---|
| Plan Rev 1 (`020b12c3…`) → **critic r1 REJECT**: two EMPIRICALLY REPRODUCED fail-open holes in the plan-as-written — B1 CRITICAL (`>&FILE` orphaned target → ALLOW-NO-WRITE, worse than today), B2 HIGH (`/dev/fd/` prefix admits traversal), B3 test-adequacy (CI-uninvoked standalone) | `.harness/evidence/dmc-v1.1.7-safesink-critic-r1.json` (conformant REJECT) |
| Rev 2 (`a31d0326…`) folds all three (FDDUP_RE companion adjudication; exact-set + anchored sink; security rows in the CI-covered module selftest) with pre-verified 17-case + 12-case batteries → **r2 APPROVE** (adversarial security table, all cases PASS incl. `&>` tokenization) | `...-critic-r2.json` |
| Orchestrator approval flip → **r3 APPROVE re-bind** with a CRYPTOGRAPHIC single-region delta proof (Rev3 prefix + DRAFT block re-hashes to the r2-approved bytes) | `...-critic-r3.json` |
| Armed run `dmc-run-7020c8701ee9` (5-path) → Opus executor implemented all 5 files (module selftest 95/0, integration 66/0, m65 161/0) then **HALTED CORRECTLY** on an out-of-scope stale assertion — `tests/fixtures/m6/test-adversarial.sh:211` asserting the OLD ask (a bare `assert_eq ask` form that evaded the literal grep) | executor escalation; run dir preserved |
| Rev 3 (`72d9fa17…`): lockstep scope add + SEMANTIC repo sweep (exactly ONE stale external row; every other hit classified) + the sweep-semantically learning → **r4 APPROVE + binding comment ruling** (:75/:426/:378-outcome = clarify to net DENY; the `return "ask", None` signal code IMMUTABLE — changing it would fire the deny branch with a null reason, bypassing the funnel) | `...-critic-r4.json` |
| Superseding run `dmc-run-8345cbf655e6` (6-path) → executor batch (adversarial 4-line flip + ruled comment set) → **independent verifier PASS** — 15-probe adversarial re-run vs the armed lock (raw verdict table in the report; ZERO rc3), funnel-integrity confirmed at source, m6-suite 38/0 | `.harness/verification/dmc-run-8345cbf655e6.md` (schema-VALID) |
| Green set (CHK-V117-CLASSIFIER/SUITES/DOCS) + frozen validators green → **release gate PASS 9/9** (landmark CLEAR — the arm-after-stage snapshot-baselining artifact, documented since v1.1.4; the enforcement diffs were scrutinized by 4 critic rounds + verifier code review instead; no G4) | run dir `release-readiness.json` |
| Change commit `4b4d3c6` → **committed-replica `--all`** (non-DMC-named `replica-v117`, severed): `tools=49 PASS=802 FAIL=3 N/A=3` EXACT + `SELFTEST-ALL RESULT: PASS` + **exit 0**, new security rows green in-replica | background task log |

## Live-fire evidence (production, not tests)

During the build itself, on real armed runs: worker `python3 -c` probes were DENIED fail-fast by the new classifier (BASH-L1-AMBIGUOUS, fail-closed reword reason) across three lanes (executor, planner, verifier), while `>/dev/null 2>&1` redirects were ALLOWED — both halves of the cycle observed working in production. No lane stalled waiting for a human at any point after the change landed in the working tree. The unattended-stall class this cycle exists to kill did not recur.

## Learnings (registered)

1. **Adversarial critic on enforcement changes pays for itself**: r1 reproduced two fail-open holes in the PLAN before a line shipped; the "strictly more fail-closed" framing was invalid-as-written and only restored after the fixes.
2. **Behavioral verdict flips must be swept SEMANTICALLY**: a bare `assert_eq <verdict>` fixture carries no literal token; the executor's correct halt + the one-revision Rev 3 pattern closed it. Recorded in-plan as a standing rule.
3. Funnel integrity as a review lens: internal signal values vs net verdicts are different truths; comments must describe the NET ARMED VERDICT (anti-misleading-docs), code signals stay.
4. The lost-final-message pattern (raw-`{` swallowing + large-message loss) cost multiple round-trips across the session; lane briefs now mandate code-fenced JSON + text-first bodies.

## Pending — THE HUMAN GATE

- `git push` → CI green → main FF for `4b4d3c6` + the records commit: **NOT pre-authorized for v1.1.7** (the prior authorization covered v1.1.5+v1.1.6 only). Awaiting the user's push decision.
- After deployment, the register still holds: --scope-input hard-require decision, §9 pilot decisions, system-review items ③④⑤⑥.
