# Build Evidence — fable-core Cycle A: succession repair (dmc-fable-core-a-succession)

Date: 2026-07-09 · Branch: `claude/dmc-fable-core` (base `62fe79c`) · Envelope: this-session
AskUserQuestion "전체 비준" (cycles A→D-core→C→B; critic-APPROVE-conditional; LOCAL-commit autonomy
ceiling; push/main a separate human gate).

## Chain

1. Plan Rev 1 authored (Fable 5, orchestrator/planner lane) →
   **critic r1 (Opus, fresh) = NEEDS_CLARIFICATION** — blocker B1 grep-case contradiction
   (`.harness/evidence/dmc-fable-core-a-critic-r1.json`, plan_hash `fb1ee8c0…`).
2. Plan Rev 2 folded B1 + 3 advisories → **critic r2 (Opus, fresh) = APPROVE, 0 blockers**
   (`.harness/evidence/dmc-fable-core-a-critic-r2.json`, plan_hash `b3538e45…`).
   `bin/dmc verdict validate` VALID ×2; `bin/dmc verdict gate` PASS (plan-bound).
3. **Run 1 `dmc-run-d5f5f66c202d`** — `bin/dmc run start` → executor (Sonnet) applied both edits →
   independent verifier (Sonnet, fresh) = **PARTIAL**: content/ACs all PASS, but the verifier
   DISCOVERED the run was never scope-lock-armed — `scope.lock.json` absent; root cause:
   `bin/dmc run start` (`dmc-run-lifecycle.py:cmd_start`) writes only run.json+snapshot.txt and
   never invokes `dmc-scope-lock.py --compile`, contradicting `dmc-start-work` SKILL.md step 3;
   no `bin/dmc` verb exposes the compile. Report preserved:
   `.harness/verification/dmc-run-d5f5f66c202d.md`.
4. **Remediation (honest, by construction — no retroactive lock, no masking):** both edits
   reverted (memo banner removed, handoff `git checkout`); **run 2 `dmc-run-dfaa6f484f05`**
   started; scope-input authored from the plan's Relevant Files (2 files, ordinary class, bounds
   2/30/5); `dmc-scope-lock.py --compile` + `--validate` VALID; **live probes proved enforcement**
   (bash-radius out-of-scope write → deny rc4; adjudicate out-of-scope → REFUSE / in-scope →
   ALLOW); executor re-applied the identical edits under live enforcement.
5. Independent verifier re-verification = **PASS** (`.harness/verification/dmc-run-dfaa6f484f05.md`)
   — scope proven by construction; selftest 77/0; linkcheck clean; no push.

## Defect registered (open, user-gated)

**`run start` does not arm the scope lock** despite the skill doc claiming it does; 4 of 20
historical runs on disk share the gap. Options for the human gate: (a) immediate small fix cycle
(make `cmd_start` compile the lock from a plan-derived scope input, or add a `bin/dmc scope
compile` verb + fix SKILL.md), or (b) register for v1.1+. Until fixed, the established manual
procedure is: `run start` → author scope-input JSON from the plan table → `dmc-scope-lock.py
--compile` → `--validate` → deny/allow probes → only then spawn the executor. (Applied for the
remaining envelope cycles D-core/C/B.)

## Live friction incident (pilot-relevant data)

During this cycle the user reported a multi-minute stall from a Bash permission prompt: an armed
run's Block D write-radius classifies undecidable command shapes (`python3 -c`, `sh -c` wrappers,
redirects) as ASK (rc 3), and hook `ask` decisions prompt the human even for subagents in auto
mode. Recorded as a real false-block-class data point for the memo §6b measurement (Block D
posture itself is deliberately unchanged — scope moat). Operational mitigation adopted: worker
Bash-shape discipline (no `python3 -c`/wrappers/redirects during armed windows), minimal armed
windows, disarm between cycles.

## Push-gate disclosure flag (critic r2 advisory — MUST be consciously ratified at push)

The now-tracked strategy memo names internal product codenames (Product-A / Product-B / Product-C) and
candid strategic assessments; this repository is public (GitHub Pages live). Merging this branch
to main PUBLISHES that content. The push-gate reviewer must explicitly ratify the disclosure (or
request redaction before push).

## Commits (LOCAL only)

- Change commit: `.harness/plans/dmc-refinement-diagnosis-20260709.md` (tracked+banner) +
  `docs/DMC_AGENT_HANDOFF.md` (no-subagent degradation rule section).
- Records commit: plan Rev 2, critic r1/r2 verdicts, BOTH verification reports, this evidence.
- Staging: targeted `git add` only; `.codex/config.toml` (pre-existing dirty) and the other
  untracked cycle plans (d-runmetrics / c-asktier / b-repointel) deliberately NOT staged here.
