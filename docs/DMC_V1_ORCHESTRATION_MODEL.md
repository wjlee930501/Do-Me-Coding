# DMC v1.0 Orchestration Model

Status: DESIGN (Phase 3 of dmc-v1-runtime-upgrade; implementation gated on the approved plan).
Companion: `docs/DMC_V1_RUNTIME_ARCHITECTURE.md` (primitives P14/P15/P16/P17/P20),
`docs/ORCHESTRATION_TAXONOMY.md` (v0.6.0 — remains the philosophical reference).
Invariants carried: **C11** (advisory verdicts never open gates), **"learn suggestions, encode
gates"**, **proposal-only externals**, **the orchestrator remains accountable** for everything it
consumes.

---

## 1. Evaluation of the current five agents

Audit facts (see `.harness/plans/dmc-v1-runtime-upgrade-audit.md` §11): the five agents in
`.claude/agents/` are orphaned (no skill dispatches them), their prompts are 8–13-line role
blurbs referencing no schema or artifact path, all read-only roles carry Bash (write-capable in
practice), and they coexist with two other unreconciled role taxonomies.

Verdict per agent:

| Agent | Keep? | v1.0 change |
|---|---|---|
| planner | **keep** | contract-ize: must consume P1/P2 artifacts, emit a PLAN_SCHEMA plan; still no mutation |
| explorer | **keep** | becomes the dispatch surface for P1–P4 scans; read-only enforced by role contract |
| critic | **keep** | must emit `critic-verdict.json` (P16 schema), fresh context, read-only |
| executor | **keep** | the **only** `may_mutate: true` role; operates solely under a scope.lock |
| verifier | **keep** | must emit evidence receipts (P10), never PASS on skipped critical checks — now checkable because receipts are typed |

The five are sufficient as *session roles*. The gaps are not missing personalities — they are
missing **contracts and dispatch**. v1.0 therefore ships a machine-readable role registry
(`orchestration/roles.json`, P14) and rewrites the five agent prompts as bindings of registry
contracts (artifact schema in, artifact schema out, tool ceiling, may_mutate flag).

## 2. Proposed additions (minimal — one new agent, two absorbed)

Candidates from the v1.0 mission, dispositioned:

- **release-manager → ADD as `release-auditor`** (the only new agent). The
  RELEASE_AUDIT state (`docs/WORKFLOW_STATE_MACHINE.md:18`) has no role today; the critic
  reviews *plans*, nobody independently reviews *the built artifact against the release gate*.
  Contract: read-only; consumes `release-readiness.json` + the diff; emits an audit verdict
  artifact (advisory input to the Human Gate, never a grant).
- **repository-intelligence → NOT an agent.** P1–P4 are deterministic tools; the *explorer*
  dispatches and interprets them. A dedicated agent would re-introduce prose where v1.0 just
  built determinism.
- **security-reviewer → NOT a standing agent; a critic lens.** The critic contract gains a
  `lenses` field; `security` lens is mandatory when the diff touches `enforcement`-class
  landmarks (P2). Same falsification posture, no sixth mailbox.
- **migration-reviewer → NOT an agent.** Migrations are a landmark class + a mandatory critic
  lens + disallowed worker category (already in `worker-result-check.py` DISALLOWED).
- **runtime-architect → NOT an agent.** Architecture decisions are plan-level human+critic work;
  an "architect agent" with no gate authority is decoration.
- **adapter-compatibility reviewer → NOT an agent; a test suite.** P19/P20 fixture matrices
  (install round-trip, harness feature matrix) check compatibility deterministically.

Result: **six agents total** (planner, explorer, critic, executor, verifier, release-auditor).
Anything further must displace prose with a contract or it does not ship.

## 3. Role registry (the single taxonomy)

`orchestration/roles.json` reconciles the three drifted taxonomies (agents / delegation-harness
roles / dynamic-delegation roles) by mapping session roles onto the v0.6.0 6-role taxonomy:

| v0.6.0 taxonomy role | Session binding | Capability class (v0.6.1 enum) | may_mutate |
|---|---|---|---|
| Strategic Orchestrator | the main session (not a subagent) | frontier-long-horizon | via executor path only |
| Implementer | executor agent · worker providers | standard-implementation | executor: yes (scope-locked); workers: **never** |
| Critic / Falsifier | critic agent (+ lenses) | adversarial-review | no |
| Release Auditor | release-auditor agent · external audit (Codex-class) | adversarial-review | no |
| Verifier | verifier agent · deterministic tools (`bin/dmc`) | deterministic-tool | no |
| Human Release Gate | human only | human-only-gate | n/a |

`docs/DMC_AGENT_HANDOFF.md` and `docs/DYNAMIC_DELEGATION.md` role lists become pointers to this
registry (audit §5 de-duplication).

## 4. Capability-class model assignment

Gate logic never names models (v0.6.1 self-scan invariant). The **dated, replaceable lookup**
(`orchestration/models.json`, non-load-bearing, v0.6.0 pattern) currently suggests:

| Capability class | Current suggestion (2026-07, replaceable) | Used for |
|---|---|---|
| frontier-long-horizon | Fable-class frontier model | Strategic Orchestrator: decomposition, plan authorship, accountability for all consumed artifacts |
| adversarial-review | Opus-4.8-class high-reliability model, fresh context | critic verdicts, release audits, verifier judgment calls — reliability over speed; MUST NOT share the author's context |
| standard-implementation | Codex-5.5-class / GPT-Sol-class via **worker bridge** | implementation proposals, portability probes, bulk mechanical transforms — always proposal-only |
| cheap-fast | small fast models / mock workers | bounded proposal generation, fixture drafting, large fan-out scans whose outputs are validator-checked |
| deterministic-tool | no model — `bin/dmc` CLIs | every gate verdict, every validation |
| human-only-gate | human | plan approval, scope amendment, bound raise, release, push, live-call, waivers |

Assignment rules:

1. **A verdict that opens nothing may come from anywhere; a verdict that opens a gate comes from
   `deterministic-tool` + `human-only-gate` only.** (C11 restated as a routing rule.)
2. Review roles get **fresh context** and read-only tool ceilings; an orchestrator that wrote the
   diff may not also emit its critic verdict.
3. Implementation goes to the cheapest class whose proposal will survive validation; the
   orchestrator absorbs a unit inline only when delegation overhead exceeds the unit
   (recorded either way in `delegations.jsonl`).
4. Model swap = edit `models.json`; zero Ring-0 change (verified by the self-scan test).

## 5. External models and workers: proposal-only, mechanically

The rule (unchanged in spirit, upgraded in enforcement): **workers and external models produce
proposals only.** Mutation happens exclusively through the scope-locked executor path after the
P15 import gate. v1.0 makes each link mechanical:

```
task (P14 brief, context-guarded)                      worker-context-guard: fail-CLOSED on parse error (fixed)
  → adapter (mock | api_key | oauth_cli | manual_import)   adapter-stamped trust fields (existing)
  → result validation                                  worker-result-check hardened: token-class secrets,
                                                        rename/binary diffs, empty-allowed ⇒ DENY,
                                                        task_id/provider cross-check, field presence
  → review record                                      NEW: review validator; decision=apply requires all-PASS
  → apply authorization                                NEW: hash-chained task→result→review→apply artifact
  → executor Edit/Write under scope.lock               P7: applied paths ⊆ task.allowed_files ∩ run scope;
                                                        `git apply`/`patch` denied at Ring 1 (closes the
                                                        acknowledged v0.2 residual)
  → post-apply fidelity check                          applied diff paths/hunk-count vs proposed_patch
  → receipts (P10) + verification (P9)
```

The orchestrator remains accountable: every consumed worker artifact appears in
`delegations.jsonl` with its validation verdict, and the release gate (P18) refuses a run whose
applied changes lack an import chain.

Codex-class **release audits** (the standing external-review practice in MILESTONES.md) are
delegation, not workers: read-only briefs, verdict artifacts, advisory-only (C11) — recorded in
the same delegation log.

## 6. Orchestration anti-patterns (encoded, not advised)

| Anti-pattern | Mechanical counter |
|---|---|
| Critic verdict flips approval | approval requires P17 record; v0.6.5 R12 check refuses laundered ACCEPTs |
| Delegate prose consumed unvalidated | P14: schema validation precedes consumption; unvalidated artifact is a stop condition |
| Worker diff `git apply`'d | Ring-1 Bash classifier denies `git apply`/`patch` in active mode |
| Read-only role writing via Bash | role contracts + Bash write-radius classifier (P7) applied to subagent sessions |
| Recursive self-delegation runaway | deterministic depth bound in P14 (v0.6.0 defer condition honored) |
| Orphaned agents (today) | skills dispatch by registry role; `dmc doctor` flags contract/prompt drift |

## 7. What stays honest

- Subagent *internal* tool use is only as constrained as the harness allows (Ring-1 dependent;
  P20 doctor matrix says so per harness — loudly, not silently).
- Worker artifact hash-chaining is provenance, not authentication (same honest-scope label as
  Q6).
- The registry governs DMC-driven work; a human bypassing DMC entirely is out of scope by
  design (visible-gate philosophy, not surveillance).
