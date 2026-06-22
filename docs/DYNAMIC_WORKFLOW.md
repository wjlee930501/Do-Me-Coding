# DYNAMIC_WORKFLOW.md — DMC Dynamic Workflow Selector (v0.5.3)

Choose the **smallest sufficient workflow lane** from explicit task facts — not from model appetite. The selector
(`.harness/evidence/dmc-v0.5.3-dynamic-workflow-selector.sh`) maps declared facts to a lane + required gates + minimum
effort + verification depth. Advisory only; **inert unless invoked**; reads no env/`.env`/secret; makes no network/live
call; **this is a recommendation, NOT an enforcement gate** (the runtime hooks remain the enforcement).

## Lanes (least → most intense)
`docs-only` < `additive-tooling` < `release-closure` < `recovery-resume` < `protected-surface` <
`secret-network-live-risk`.

## Inputs (explicit task facts — closed schema)
`task_class` · `changed_paths` (csv) · `protected_surface` (bool) · `secret_network_live` (bool) · `provider_target`
(type) · `run_mode` (`mock`|`live`, informational) · `prior_findings` (int) · `test_failures` (int). Provide facts via
flags or `--from <facts.json>`.

## Rules (fail-closed, structural)
- **Unknown / missing / non-canonical task_class or danger fact ⇒ `secret-network-live-risk`** (max). "No risk" means an
  *explicitly-validated* safe fact, never an omitted one.
- **Provider-adapter / router / schema / guard / hook / validator / `dmc-glm-smoke` facts are PROTECTED SURFACE** — any
  such `provider_target` or `changed_paths` entry forces lane ≥ `protected-surface` (+ human gate + protected-path
  byte-unchanged check). A secret-bearing `changed_paths` entry forces `secret-network-live-risk`.
- **`run_mode=mock` is informational and never lowers the lane.** A `provider_target` of `mock` is a **category error**
  (mock is a run-mode, not a provider target — the v0.3.4 mistake) and is **refused** (exit 1).
- **Structural monotonicity:** lane / effort / verification-depth = `max(...)`; required gates = **union**. Adding a risk
  fact never lowers intensity.
- Non-canonical danger booleans (`on`/`enabled`/garbage) fail **closed** (escalate).

## Output
`lane`, `min_effort` (light/standard/deep/adversarial), `verification_depth`, `required_gates` (push + closure always
human-gated; protected/secret surfaces add gates), and a `reason` trace. `push`, `main`-merge, and `closure` are **always**
human gates regardless of lane.
