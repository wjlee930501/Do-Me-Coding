# DMC Effort & Provider Policy (v0.2.9)

DMC's policy for choosing the **smallest sufficient reasoning path** — model / provider / effort — instead of token
maximization. It **recommends** (does not select); the human and the loop still decide.

## Nature — guidance, not enforcement

- This policy is **guidance (a behavioral norm), NOT an enforcement mechanism.** It binds by agreement and review
  discipline, not tooling. It changes **no** provider-routing behavior and edits **no** code (`provider-router.py`,
  `ROUTING.md`, adapters, schemas, hooks, guards, `dmc-glm-smoke` are untouched).
- The v0.2.9 structure-check proves the policy is **documented, complete, own-words, and clean** — **presence ≠
  compliance.** A passing check does not prove any agent will follow the policy.
- **Enforcement automation** (auto-selecting a model/provider from this policy, a policy linter) is **out of scope** and
  would require a **separate approved future milestone.**
- Optimization target: **E2E done with the least change that is verifiably correct.** Token cost is not a goal.

## When a fast / simple model suffices

Low-risk, mechanical, well-specified, **docs-only / test-only** drafting; reversible edits; no protected surface; clear
acceptance criteria. (A faster model for drafting does not remove any gate — Codex audit + human Release Gate still apply.)

## When Opus-class implementation is warranted

**Protected-surface** work (adapter / router / schema / guard / hook / validator), safety-critical or **fail-closed**-
sensitive logic, ambiguous or multi-step tasks, or anything touching credentials / live paths / destructive operations.

## When to invoke Codex release audit

**Always before a stage / commit / push decision** — mandatory for every milestone. Codex is an **independent advisory
audit input feeding the human Release Gate**, NOT itself one of the handbook's nine human gates; an agent never treats a
Codex ACCEPT as a granted gate.

## When a separate critic pass is required

**Always** — separation of duties: the Orchestrator/author never approves its own work; the Critic is a distinct pass.
Use a **multi-perspective adversarial panel** for high-risk / protected-surface / ambiguous work, and by default under
**ultracode**. Implementation begins only after critic PASS + APPROVED.

## When to escalate to a human

Any **hard gate** (push, live-provider-call, credential, schema/guard/hook/validator/adapter/router change, force/
history-rewrite, external-publish); any **fail-closed** trigger (scope ambiguity, protected-file diff, credential/secret
exposure risk, live-call risk, verification FAIL); or task-intake `stop_and_ask=true`. **Release Gate** decisions are the
human's.

## When to STOP instead of spending more tokens

- The problem is **E2E done** (verified · reviewed · committed · pushed · closure-recorded); OR
- review has **converged** (diminishing returns — no new substantive finding from another pass); OR
- the work is **blocked on a human gate**.

Do not spend more tokens for their own sake; **anti-token-max** — smallest workflow that closes the problem safely.

## Task-class → workflow mapping

(Consumes the v0.2.8 task-intake dimensions + the handbook gate map. Every row also carries the always-on
approval/staging/commit/push gates + Codex audit before stage/commit/push.)

| Task class | model / effort | plan depth | critic | required human gate | stop_and_ask |
|---|---|---|---|---|---|
| docs-only | fast/simple OK | light | single (panel optional) | (always-on only) | no* |
| test-only | fast/simple OK | light | single (panel optional) | (always-on only) | no* |
| adapter | Opus | standard | panel | #7 schema/guard/hook/validator/adapter/router | yes |
| router | Opus | standard | panel | #7 | yes |
| schema/guard | Opus | deep | panel | #7 | yes |
| live/credential | Opus | deep | panel | live → #5 live-call · credential → #6 credential | yes |
| release | (human) | — | — | push (#4) + closure | yes |

`*` docs/test → `stop_and_ask=false` only when no risk/protected-path/gated-action signal is present (per the v0.2.8
classifier's fail-closed rule).

## Ultracode interaction

Under **ultracode**, raise **verification/critic depth** (adversarial panels, multi-perspective verify) — but keep
**implementation scope minimal** and **every gate intact**. Depth, not scope: more review, same minimal footprint, same
human gates. This policy is itself guidance; ultracode does not grant any gate.
