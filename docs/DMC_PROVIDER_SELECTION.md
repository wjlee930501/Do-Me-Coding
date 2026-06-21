# DMC Provider Selection Policy (v0.3.4)

DMC's policy for moving **"which provider to use"** from manual judgment to **policy-based** judgment. It **recommends**
ranked provider candidates — it does **not** select, execute, or grant a gate. The human and the loop still decide.

Implemented by the advisory runner `.harness/evidence/dmc-v0.3.4-provider-selector.sh`, which composes the v0.2.8
task-intake classifier + the v0.2.9 effort/provider policy + the v0.3.2 router. It is **additive and read-only** over all
three — it edits none of them.

## Nature — guidance, not enforcement

- Like the v0.2.9 effort/provider policy, this is **guidance (a behavioral norm), NOT an enforcement mechanism.** The
  runner is advisory: its exit code must never be wired to select, execute, stage, commit, push, or grant a gate.
- It changes **no** provider-routing behavior and edits **no** code (`provider-router.py`, `ROUTING.md`, adapters,
  schemas, hooks, guards, `dmc-glm-smoke`, the v0.2.8 classifier, the v0.2.9 policy are untouched).
- **Enforcement automation** (auto-dispatching the selected provider) is **out of scope** and would require a separate
  approved future milestone.

## The candidate set — exactly the three registered provider_targets

Candidates are exactly the three `(type, provider)` pairs the router REGISTRY can route to
(`provider-router.py:37-42`):

| rank | type | provider | run_mode | why this rank |
|---|---|---|---|---|
| 1 | `manual_import` | `manual-import` | `import-only` | **offline-by-construction**: no `live_flag`, no `--mock`/`--live`; a human-supplied envelope v1 via `--import`. The only genuinely offline target. |
| 2 | `api_key` | `glm-api` | `mock` (default) | **live-capable**, recommended in the offline `mock` run-mode; `--live` is the gated escalation. |
| 3 | `oauth_cli` | `oauth-cli` | `mock` (default) | **live-capable**, recommended in the offline `mock` run-mode; `--live` is the gated escalation. |

### `mock` is a run-mode, NOT a candidate

`mock` is **not** a provider_target. It is the default offline **run-mode** of the glm-api/oauth-cli adapters
(`--mock <fixture>`) — an execution-mode axis orthogonal to provider selection. The router **refuses** type `mock`
(`provider-router.py:58-59`). So for the live-capable pair, **"offline vs live" is a `run_mode` of the *same* provider**
(default `mock`; `--live` gated), **not** a separate `mock` provider. `manual_import` has no `mock`/`live` axis at all
(it consumes only `--import`); its `run_mode` is `import-only`.

## Offline-first ranking (anti-token-max)

Consistent with the v0.2.9 anti-token-max posture (smallest sufficient path): rank the **offline-by-construction**
`manual_import` above the **live-capable** `glm-api`/`oauth-cli`, and for the live-capable pair default the recommended
`run_mode` to `mock`. A live run is an **escalation**, never the default.

## No env / secret inference — non-negotiable

Candidates are a function of the **task + policy ONLY**. The selector:

- reads **no** environment variable and **no** `.env*`/credential file;
- proposes a live provider only as a **gated option** — **never** "available because a key is set";
- is therefore **byte-identical** in output whether or not `GLM_API_KEY`/`DMC_OAUTHCLI_BIN`/any credential var is set
  (proven under `env -i` and a multi-var/multi-value differential in the runner self-test).

## Fail-closed

If the v0.2.8 classifier is **absent** (or errors), the selector **recommends nothing** — it emits an empty candidate
list with `fail_closed: true`, `stop_and_ask: true`, `human_gate_required: true`, and **no live candidate**.

If `stop_and_ask=true` or a protected / credential / live signal is present, the output flags **human-gate-required**;
the live-capable candidates always carry the live-call gate (**#5**) on their live `run_mode` — a live `run_mode` is
**never** presented as a no-gate default. Gate numbering follows the handbook + the v0.2.9 policy table
(`docs/DMC_EFFORT_PROVIDER_POLICY.md:59-67`): `#4` push, `#5` live-call, `#6` credential,
`#7` schema/guard/hook/validator/adapter/router.

## Executes nothing — dispatch-check is print-only

With `--dispatch-check`, the selector annotates each candidate `routes: yes/no` by invoking the router's
`--print-dispatch` through a **single chokepoint helper**. That helper hard-codes `--print-dispatch` (the router returns
**before** any `subprocess.run` — `provider-router.py:130-136`) and **never** passes
`--live`/`--allow-network`/`--allow-exec`/`--mock`/`--import` to the router. No adapter is ever executed; no live or
network call is ever made.

## Output shape

```json
{
  "task_id": "...",
  "provider_target_hint": null,
  "intake_dimensions": ["..."],
  "stop_and_ask": false,
  "human_gate_required": false,
  "required_human_gates": ["approval", "commit", "push", "staging"],
  "recommended_model_effort": "fast/simple OK; light",
  "provider_candidates": [
    {"type": "manual_import", "provider": "manual-import", "run_mode": "import-only", "rank": 1, "rationale": "...", "gates": ["..."], "routes": "yes"}
  ],
  "fail_closed": false,
  "selection_basis": "task + policy (NOT env/secrets); advisory; grants no gate; executes nothing"
}
```

The `selection_basis` string is the contract restated in every result: **task + policy, not env/secrets; advisory;
grants no gate; executes nothing.**
