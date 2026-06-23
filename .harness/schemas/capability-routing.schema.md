# capability-routing.schema.md

The capability-class routing contract (DMC v0.6.1). Additive; advisory; **input-only**; **deterministic**; **model-agnostic**.
Routing selects one of the six v0.6.0 capability classes from `(task_class, role)` — **never a model name, never learned**.
Answers **Q1 — "what capability performed this work?"** and persists a subject-bound `capability_class` fragment that conforms
to the trace-linkage contract (`.harness/schemas/trace-linkage.schema.md`, `--validate-entry capability`). Cites
`docs/ORCHESTRATION_TAXONOMY.md` Output 1 (roles) / Output 2 (classes) / Output 3 (matrix).

## Inputs — task facts
```text
{ "task_class": "<7 below>", "role": "<5 below>",
  "subject": { "work_id","plan_hash"(hex≥16),"milestone_id","repo_hash"(hex≥16),"verification_ref" } }
```
**`task_class` (7, byte-exact ⟶ Output-3 row):** `docs-only` ⟶ docs-only · `additive-tool` ⟶ additive tool ·
`provider-adapter` ⟶ provider adapter · `protected-surface-change` ⟶ protected-surface change ·
`security-secret-live-risk` ⟶ security/secret/live risk · `release-closure` ⟶ release/closure ·
`recovery-resume` ⟶ recovery/resume.
**`role` (5, byte-exact ⟶ Output-1 role):** `orchestrator` ⟶ Strategic Orchestrator · `implementer` ⟶ Implementer ·
`critic` ⟶ Critic/Falsifier & Release Auditor · `verifier` ⟶ Verifier · `release` ⟶ Human Release Gate.

## Routing table `(task_class, role) → capability_class` (the visible, deterministic rule)
| role | capability_class | rule |
|------|------------------|------|
| `orchestrator` | `frontier-long-horizon` | role-determined (all task classes) |
| `implementer` | `cheap-fast` if `task_class=docs-only`, else `standard-implementation` | the one task-class-dependent row (light lane for docs) |
| `critic` | `adversarial-review` | role-determined |
| `verifier` | `deterministic-tool` | role-determined |
| `release` | `human-only-gate` | role-determined |

Only the `implementer` row depends on `task_class`; all others are role-determined. The table is **data with no model name**.
Same smallest-sufficient-lane philosophy as the v0.5.3 selector; authoritative source = Output 1/2/3 (not a byte-reduction).

## Dated class → model illustrative lookup (NON-LOAD-BEARING; routing never reads this)
**Illustrative + dated (as of 2026-06); swapping it changes nothing in routing** (model-swap invariance). Lives in this doc
only — the router `.py` does not import or read it.

| capability_class | illustrative example (2026-06) |
|------------------|--------------------------------|
| `frontier-long-horizon` | a current frontier reasoning model |
| `standard-implementation` | a current standard coding model |
| `cheap-fast` | a current small/fast model |
| `adversarial-review` | a current frontier model in a read-only critic role |
| `deterministic-tool` | not a model — a deterministic script |
| `human-only-gate` | not a model — a human |

## Provider-mapping policy (class → provider-class; data-only, deterministic)
A capability class maps to a *provider class* (not a provider/model name): `deterministic-tool`/`human-only-gate` need no
provider; the model-bearing classes resolve to a provider class via the existing deterministic provider router (v0.2.3) — the
mapping is data, env-free, with no model name in selection logic.

## Routing record (emitted)
```text
{ "inputs": {"task_class","role"}, "resolved_capability_class": "<one of six>", "rule_fired": "<text>",
  "explanation": "<human-readable sentence naming the rule>",
  "capability_entry": {"kind":"capability_class","id":"<class>","producer_milestone_id":"v0.6.1", <subject-binding>} }
```
The `capability_entry` is a trace-linkage **fragment** (passes `--validate-entry capability`): subject-bound, producer=v0.6.1,
id ∈ the six classes.

## Invariants
Deterministic (same facts → byte-identical record); **env-independent** (`env -i` identical; no `.env`/credential/network);
**input-only** (`--route` reads only the facts file/stdin, **never calls git**, never reads a model table); duplicate-JSON-key
rejecting; **value-blind reject-on-match** (no secret-shaped string survives); **no learned routing, no dynamic scoring, no
silent fallback, no model name in routing logic**. Advisory / fail-closed; the runtime enforcement floor stays the hooks.
