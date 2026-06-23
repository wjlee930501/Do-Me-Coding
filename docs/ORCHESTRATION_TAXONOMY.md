# Orchestration Taxonomy

**Milestone:** DMC v0.6.0 — Harness Landscape & Orchestration Taxonomy.
**Nature:** **architecture guidance, not enforcement.** This document defines the orchestration vocabulary the next layer (v0.6.x) will be built against: a model-role taxonomy (Output 1), a capability-class taxonomy (Output 2), and a work-delegation matrix (Output 3). It **describes** DMC's already-shipped lane logic; it adds no new enforcement path.

**Thesis anchor.** Roles, classes, and the delegation matrix all serve one rule: deterministic scripts are the source of truth for gates, a human is the Release Gate for irreversible actions, and any learned/adaptive component is advisory and untrusted-until-inspected — never the thing that opens a gate.

---

## Output 1 — Model role taxonomy

Six roles. Each is defined by what it **owns**, what it **must-not** do, and what it **outputs**. The roles reuse the v0.5.8 delegation vocabulary and the global "authoring and review are separate passes" rule. Capability is assigned per role via the classes in Output 2 — by capability, never by a hard-coded model name.

### Strategic Orchestrator
- **Owns:** decomposing a goal into a plan and lanes; choosing which role/capability class handles each step; sequencing the work.
- **Must-not:** edit product code; approve its own plan; open a release/closure gate; treat its own routing as authoritative for gates (routing that gates is a deterministic script, not the orchestrator's discretion).
- **Outputs:** a plan, a lane assignment, and a delegation handoff — all inspectable artifacts.

### Implementer
- **Owns:** making edits strictly within the approved file scope; producing a diff and the evidence of what ran.
- **Must-not:** plan, approve, verify-and-close its own work, push, or touch the protected surface; expand scope without a new approval.
- **Outputs:** scope-bounded edits + an evidence receipt (what changed, what was run).

### Critic / Falsifier
- **Owns:** adversarially reviewing a plan or a change, trying to refute it; rating findings by severity.
- **Must-not:** edit the artifact it reviews (read-only); grant approval — a critic PASS is advisory input, never a release grant (C11).
- **Outputs:** a verdict (APPROVE / REVISE / REJECT / NEEDS CLARIFICATION) with specific, falsifiable findings.

### Release Auditor
- **Owns:** an independent pre-release audit of a built change against the plan — leak/secret scan, scope/protected-surface check, claim-honesty check.
- **Must-not:** edit the change; self-approve; substitute for the human Release Gate (its ACCEPT is advisory, never the gate itself).
- **Outputs:** an audit verdict + a residual-risk list.

### Verifier
- **Owns:** running the deterministic verification (the structure/self-test checks) and reporting PASS/FAIL against the required criteria.
- **Must-not:** edit code to make a check pass; declare DONE from a model's self-assessment rather than from the deterministic result.
- **Outputs:** a verification report bound to immutable run facts (the v0.5.4 DONE evaluator consumes it).

### Human Release Gate
- **Owns:** authorizing irreversible actions — DRAFT→APPROVED, stage, commit, push, merge, milestone closure.
- **Must-not:** be inferred or automated; a critic/auditor PASS never substitutes for it; approval is never derived from run state.
- **Outputs:** an explicit, recorded authorization (the only thing that may open a release/closure gate).

**Separation invariant.** Authoring roles (Orchestrator, Implementer) and judging roles (Critic/Falsifier, Release Auditor, Verifier) never collapse into one active context, and only the Human Release Gate opens irreversible gates. This is the role-level form of "never self-approve."

---

## Output 2 — Capability class taxonomy

Six classes, **named by capability, never by a hard-coded model name.** Specific model names are illustrative and dated; they live in a separate, replaceable lookup (below) so that model-name rot (regression risk R4) never reaches role or gate logic. Card #22 (Sakana Fugu's swappable, pool-agnostic routing) is the real-world existence proof that model-name-free routing is feasible **without** a learned router — DMC keeps the selection rule a visible deterministic script.

| Capability class | What it is for | Typical role binding |
|------------------|----------------|----------------------|
| `frontier-long-horizon` | long-horizon planning, decomposition, hard reasoning | Strategic Orchestrator |
| `standard-implementation` | routine scope-bounded implementation | Implementer |
| `cheap-fast` | mechanical, high-volume, low-risk steps | Implementer (light lane) |
| `adversarial-review` | refutation, falsification, hostile critique | Critic/Falsifier, Release Auditor |
| `deterministic-tool` | a script/check whose output is reproducible and auditable | Verifier, gate scripts |
| `human-only-gate` | a decision no model may make | Human Release Gate |

**Replaceable model-name lookup (illustrative + dated — NOT load-bearing).** This table is the *only* place model names appear, is explicitly dated, and may be swapped without touching any role/gate logic. Capability class is the durable unit.

| Capability class | Illustrative example (as of 2026-06) |
|------------------|--------------------------------------|
| `frontier-long-horizon` | a current frontier reasoning model |
| `standard-implementation` | a current standard coding model |
| `cheap-fast` | a current small/fast model |
| `adversarial-review` | a current frontier model in a read-only critic role |
| `deterministic-tool` | not a model — a deterministic script (`grep`/`git`/`python3 hashlib`) |
| `human-only-gate` | not a model — a human |

**Rule.** Routing selects a *class* from declared task facts; the class→example mapping is a separate dated lookup. No gate, role contract, or selection script may reference a model name directly.

---

## Output 3 — Work delegation matrix

Rows = task classes; columns = {orchestrator model class, implementer model class, critic depth, verification depth, required human gates}. The matrix **reduces to** DMC's already-shipped lane logic — the v0.5.3 dynamic workflow selector (smallest-sufficient lane from task facts), the v0.5.5 verification planner (required/optional/forbidden checks), and the v0.5.4 state machine (transition + DONE evaluator). It is **descriptive of existing behavior, not a new enforcement path.**

| Task class | Orchestrator class | Implementer class | Critic depth | Verification depth | Required human gates |
|------------|--------------------|--------------------|--------------|--------------------|----------------------|
| `docs-only` | `frontier-long-horizon` (light) | `cheap-fast` / `standard-implementation` | light (single critic) | structure check | commit |
| `additive tool` | `frontier-long-horizon` | `standard-implementation` | standard critic | self-test + structure check | commit, push |
| `provider adapter` | `frontier-long-horizon` | `standard-implementation` | deep critic | contract + self-test, mock-only | commit, push (live path separately gated) |
| `protected-surface change` | `frontier-long-horizon` | `standard-implementation` | deep + adversarial | full + protected-surface diff | explicit approval, commit, push |
| `security/secret/live risk` | `frontier-long-horizon` | `standard-implementation` | adversarial panel | adversarial + secret/network/live audit | explicit approval, commit, push, live opt-in |
| `release/closure` | `frontier-long-horizon` | n/a (no edit) | Release Auditor (independent) | closure-condition check (fail-closed) | **Human Release Gate** (approve, push, closure) |
| `recovery/resume` | `frontier-long-horizon` | `standard-implementation` | standard critic | next-safe-action check (never "safe to push") | commit-bound human gate before any push |

**Reduction notes.**
- *Smallest-sufficient lane* (v0.5.3): `docs-only` gets the lightest column values; risk escalates depth monotonically toward `security/secret/live risk` and `release/closure`.
- *Verification depth* (v0.5.5): each row's verification column is the planner's required-check set for that lane; deeper for protected/secret/live.
- *Gates* (v0.5.4 + C11): push and closure always require the Human Release Gate; a critic/auditor PASS is advisory and never opens them; approval is never inferred from run state.
- *No new path:* every cell names a behavior DMC already ships; the matrix is a readable index over the existing selector/planner/state-machine, not a new runtime.

**Milestone disclaimer:** this taxonomy is **architecture guidance, not enforcement**. It defines vocabulary and describes shipped behavior; it adds no gate, selects no model, and authorizes no build.
