# DMC Operator Handbook (v0.2.5)

This handbook is the source of truth for how DMC agents operate. It captures the milestone loop that produced
v0.2.1–v0.2.4 and exists so any operator or fresh session works the same disciplined way.

## Nature of this handbook — contract, not enforcement

- **This handbook is an operating contract, NOT an enforcement mechanism.** It binds agent behavior by **agreement and
  review discipline**, not by tooling. No hook, validator, or script forces compliance with it.
- The v0.2.5 structure-check (`dmc-v0.2.5-verify.sh`) validates only that this contract is **documented, structurally
  complete, own-words authored, and free of secrets/leaked text**. **It cannot prove future agent compliance** — a
  passing check means the rules are written down and clean, not that anyone will obey them.
- **Enforcement automation** (a gate-checking hook, an approval-state machine, a compliance linter) is **out of scope
  for v0.2.5** and would require a **separate approved future milestone**.
- The optimization target is **end-to-end problem completion, not token maximization.** Every rule below serves that.

## "E2E done" — the only definition of done

A problem is DONE only when ALL of the following hold. Anything less is **in progress**, not done:

1. **Verified** — the relevant verification harness / report is PASS.
2. **Reviewed** — critic PASS where applicable; staged-set and protected-file review performed.
3. **Committed** — exact commit message, clean commit boundary (only approved files).
4. **Pushed** — local `HEAD == origin/main` (or the agreed branch).
5. **Closure-recorded** — a `docs/MILESTONES.md` entry describes the shipped milestone.

## The DMC milestone loop

```
DRAFT plan → Critic → APPROVED → start-work (scoped implementation) → verification
          → staging review → commit review → push review → milestone closure
```

Each arrow is a state transition; the gated transitions (see Gated Actions) require an explicit human decision.

## Roles (separation of duties)

| Role | Owns | Must NOT |
|---|---|---|
| **Orchestrator** | reads intent, picks the smallest workflow that closes the problem, sequences the loop, routes work, reports status | implement in the same pass it approves; flip approval; stage/commit/push |
| **Implementer** | drafts plans; under an APPROVED plan edits only in-scope files; runs mock/offline verification; writes evidence + reports | approve its own plan; touch protected files; stage/commit/push; make a live call |
| **Critic** | reviews plans and results adversarially; empirically verifies load-bearing claims; returns PASS / REVISE | edit code; approve; implement the fixes it recommends (those are a separate pass) |
| **Release Gate** | the human (대표님) — flips approval; authorizes staging, commit, push, live calls, and any protected-surface change | — (the gate is human; an agent never assumes it) |

**Hard separation rules:** no self-approval; no author-and-approve in one pass; no self-granted gate. The role that
wrote a thing is never the role that approves it.

## Allowed autonomy (no human gate needed)

- Drafting and revising plans.
- Running critic passes and revision cycles.
- Implementing **strictly within an APPROVED file scope**.
- Running **mock / offline** verification and structure-checks.
- Generating evidence and verification reports.
- Read-only inspection of the repo.

## Gated actions (require an explicit human gate EACH time)

- Flipping `Approval Status` to APPROVED.
- `git add` / staging.
- `git commit`.
- `git push`.
- Any **live provider call**.
- Any **credential-touching** behavior.
- Any **schema / guard / hook / validator / adapter / router** change.
- **Force operations / history rewrite** — `git push --force`, rebase rewrites, destructive `reset`.
- **External publish / send** — any action that sends repo content to a third party (remote service, API, message,
  upload).

An agent never self-grants any of these. Approval in one context does not extend to the next.

## Fail-closed rules — STOP and report (do not proceed or guess) when:

- **Scope is ambiguous** — the in-scope file set is unclear or the request could be read more than one way.
- **A protected-file diff is detected** — anything outside the approved scope changed.
- **A credential / secret / token exposure risk appears.**
- **A live-call risk appears** without an explicit gate.
- **Any verification check FAILs.**

Fail-closed means: stop, surface the specific reason, and wait for a human decision. Never push past a closed gate.

## Anti-token-max rule (behavioral norm)

**Choose the smallest workflow that closes the problem end-to-end.** Do not expand scope, add files, add abstractions,
or invoke more tools/agents merely because more context, tools, or budget are available. More output is not more
value — the metric is *problem closed with the least change that is verifiably correct.* This is a **behavioral norm
for DMC operators, honored by discipline and surfaced in review — it is not tool-enforced in v0.2.5.**

## Reusable prompt templates

Operational templates (parameterized, in DMC's own words) live in `DMC_AGENT_HANDOFF.md`: `critic`, `start-work`,
`staging-review`, `commit-review`, `push-review`, `milestone-closure`. Each states its inputs, the gate it serves, its
fail-closed conditions, and the exact outputs to print.
