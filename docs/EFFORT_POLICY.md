# EFFORT_POLICY.md — DMC Effort Controller Policy (v0.5.2)

Spend the **minimum sufficient** reasoning/review effort to complete a task safely. Before an expensive deep/adversarial
cycle, the effort controller (`.harness/evidence/dmc-v0.5.2-effort-controller.sh`) recommends one of four levels from a
deterministic rule set. Advisory only; **inert unless invoked**; reads no env/secrets; makes no network/live call.

## Levels
- **light** — self-test only. (e.g. a docs-only append-only closure.)
- **standard** — self-test + a single critic pass. (e.g. an additive schema/tool with no protected/secret surface.)
- **deep** — self-test + per-finding adversarial verify. (e.g. a guard/harness/safety change, a protected surface, a
  large changeset, or a prior review finding.)
- **adversarial** — multi-agent falsification panel + cross-cutting audit. (e.g. anything touching secret/network/
  live-call surfaces, a security change, or repeated/false-green findings.)

## Inputs
`risk_class` ∈ {docs-only, additive, guard, security, provider, generic} · `files_touched` (int) ·
`protected_surface` (bool) · `secret_network_live` (bool) · `prior_findings` (int) · `test_failures` (int) ·
`human_gate` (bool).

## Deterministic escalation (take the highest level that applies)
- base: `docs-only`→light · `additive`/`generic`→standard · `provider`/`guard`→deep · `security`→adversarial.
- `protected_surface` ⇒ at least **deep**.
- `secret_network_live` ⇒ **adversarial** (provider / live / network / secret surfaces escalate automatically).
- `files_touched` > 25 ⇒ at least **deep**; > 10 ⇒ at least **standard** (over-eager guard).
- exactly one `prior_findings` ⇒ **+1 level**; **≥ 2 (repeated / false-green) ⇒ adversarial** (auto-escalate).
- any `test_failures` ⇒ **+1 level**.

## Outputs
`recommended_effort`, the `reason` (which rules fired), `reviewer_required` (yes when deep+ / prior findings / test
failures), `adversarial_required` (yes when adversarial / secret-network-live / repeated findings), and the
`suggested_verification_depth`. The recommendation is a **pure function of the inputs** — environment variables never alter
it (`env -i` and a credential-var differential are byte-identical). `human_gate` does not change the *effort* level (the
human approval gate is orthogonal to how hard the run reasons/reviews).

## Robustness (fail-closed input handling)
Inputs are parsed **fail-closed**, so a near-miss never silently under-classifies a dangerous surface: `risk_class` is
normalized (trim + lowercase) and an **unrecognized** class escalates to **adversarial** (not downgraded to generic); a
danger boolean (`protected_surface`, `secret_network_live`) treats **anything not explicitly false-y** (`false`/`no`/
`off`/`0`/empty) as **true** (so `on` / `enabled` escalate); and an **unparseable** numeric count (`files_touched`,
`prior_findings`, `test_failures`) escalates rather than defaulting to 0.
