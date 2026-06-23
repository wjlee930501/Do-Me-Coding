# Harness Benchmark Cards 2026

**Milestone:** DMC v0.6.0 — Harness Landscape & Orchestration Taxonomy.
**Nature:** architecture guidance, not enforcement. Each card extracts ONE concrete harness *primitive* from the 2026 agent-harness landscape and records a DMC decision against it. No card is a build order; a card's decision is `adopt | adapt | reject | defer`.

**Reading discipline.** Every mechanism is stated as a *structural pattern in DMC's own words*. No leaked, proprietary, or system-prompt text is reproduced; no project README is dumped. External-project descriptions are kept at the pattern level — DMC does not assert unverifiable internal facts about another project. All Sakana Fugu performance numbers are recorded **self-reported / independently-unverified** (see cards 19–23 and the research note `.harness/decisions/dmc-v0.6.0-fugu-benchmark-card.md`).

**Card schema (every card carries all ten fields):** Source project · Observed mechanism · What DMC already has · Gap in DMC · Decision · Rationale · Risk · Verification strategy · Candidate future milestone · Attestation.

**Operating thesis the decisions answer to:** DMC is a *visible control plane for bounded AI agents* — deterministic scripts are the source of truth for gates, a human is the Release Gate for irreversible actions, frontier models may orchestrate and cheaper/specialist models may implement, and nothing load-bearing is hidden.

Cards: **23** (floor ≥23). Fablize 01–05 · LazyCodex 06–10 · OmO 11–14 · FableCodex 15–17 · Skill ecosystem 18 · Sakana Fugu 19–23.

---

### Card 01 — Fablize: capability/procedure boundary
- **Source project:** Fablize
- **Observed mechanism:** A separation between *capabilities* (what an agent is able to do) and *procedures* (the fixed, ordered steps it must follow). Discipline is carried by the procedure; flexibility lives in the capability. The two are kept in different layers so that "be smart" never overrides "follow the steps."
- **What DMC already has:** The default loop (Goal → Intent Gate → Plan → Critic → Scope Lock → Execute → Verify → Evidence) is a procedure layer; capability lives in the model/agent choice. The v0.5.3 selector and v0.5.4 state machine already encode procedure as deterministic lane logic.
- **Gap in DMC:** The boundary is implicit in the loop rather than named as a first-class concept in the taxonomy.
- **Decision:** adapt
- **Rationale:** Naming the boundary makes DMC's "procedure is deterministic, capability is swappable" stance explicit, which is the same axis as the capability-class taxonomy (Output 2) — procedures are gates/scripts, capabilities are model classes.
- **Risk:** If overstated, the boundary becomes a new abstraction nobody maintains; mitigation is to map it onto existing lane logic, not invent a parallel layer.
- **Verification strategy:** A deterministic check that the procedure (lane) is selected from declared task facts only (`env -i` byte-identity, already the v0.3.4/v0.5.3 pattern) — capability choice never alters the gate set.
- **Candidate future milestone:** v0.6.x (taxonomy reaffirmation; no new runtime)
- **Attestation:** No leaked prompt body or proprietary text is copied in this card.

### Card 02 — Fablize: multi-story / multi-criterion verification gate
- **Source project:** Fablize
- **Observed mechanism:** Completion is gated on satisfying multiple independent acceptance criteria at once ("every story passes"), not a single happy-path check, so partial work cannot self-report as done.
- **What DMC already has:** `/dmc-verify-hard` + the v0.5.5 verification planner emit a required/optional/forbidden check set per lane; "No verification, no done" is a non-negotiable rule.
- **Gap in DMC:** The planner already supports multiple required checks; the gap is only making "all required criteria, not just one" an explicit, named property.
- **Decision:** adapt
- **Rationale:** Multi-criterion gating is exactly DMC's verification planner with the union/monotonic property; adopting the framing strengthens the existing gate rather than adding a mechanism.
- **Risk:** Criterion sprawl (too many low-value checks) slows the loop; mitigation is the planner's "minimal-sufficient" rule.
- **Verification strategy:** Assert the verification report enumerates ≥1 required criterion per lane and that completion requires all required criteria PASS (the v0.5.4 DONE evaluator already binds to immutable run facts).
- **Candidate future milestone:** v0.6.x
- **Attestation:** No leaked prompt body or proprietary text is copied in this card.

### Card 03 — Fablize: early-stop prevention
- **Source project:** Fablize
- **Observed mechanism:** A guard against an agent declaring completion before the work is actually finished — pressure to "keep going until the criteria are met."
- **What DMC already has:** The stop/verify gate and evidence-log requirement; an unverified claim of done is rejected by the gate.
- **Gap in DMC:** None of substance — DMC already prevents early stop via a *visible* gate.
- **Decision:** adapt
- **Rationale:** DMC keeps the *outcome* (don't stop early) but insists the mechanism be a **visible, bounded gate**, never hidden "keep going" pressure baked into a prompt. This is the visibility-axis discipline applied to a useful idea.
- **Risk:** Misadapted, early-stop prevention becomes an auto-unbounded loop (a DMC anti-goal); mitigation is that the gate is a deterministic check with a human Release Gate, not an open-ended drive.
- **Verification strategy:** Assert completion is bound to the verification report's required-criteria result (deterministic), not to a model's self-assessment.
- **Candidate future milestone:** v0.6.x
- **Attestation:** No leaked prompt body or proprietary text is copied in this card.

### Card 04 — Fablize: systematic investigation protocol
- **Source project:** Fablize
- **Observed mechanism:** A repeatable investigation discipline — reproduce, isolate, form competing hypotheses, gather evidence — applied before proposing a fix, rather than guessing.
- **What DMC already has:** The Repo Scan step and evidence-first principle; the tracer/debugger discipline is available to delegated agents.
- **Gap in DMC:** DMC has the principle but no named, checklist-shaped investigation protocol in the docs.
- **Decision:** adopt
- **Rationale:** A systematic-investigation checklist is pure discipline with no hidden behavior, fully aligned with "evidence over assumptions"; it is cheap to adopt and improves debugging lanes.
- **Risk:** Low; the only risk is ceremony on trivial tasks, mitigated by the effort controller (light lane skips it).
- **Verification strategy:** Documentation-level check that the debugging lane references reproduce → isolate → hypothesize → evidence; no runtime assertion required.
- **Candidate future milestone:** v0.6.x (docs)
- **Attestation:** No leaked prompt body or proprietary text is copied in this card.

### Card 05 — Fablize: per-task discipline router
- **Source project:** Fablize
- **Observed mechanism:** Routing the *amount* of discipline (depth of plan/verify/review) to the task's risk and size, instead of one fixed ceremony for everything.
- **What DMC already has:** The v0.5.3 dynamic workflow selector and v0.5.2 effort controller already pick the smallest-sufficient lane from task facts.
- **Gap in DMC:** None material — DMC shipped this.
- **Decision:** adapt
- **Rationale:** This primitive is already DMC behavior; the card records it as *converged* with the landscape and reaffirms it in the delegation matrix (Output 3).
- **Risk:** Drift between the router's lanes and the actual gate set; mitigation is R5 (taxonomy must reduce to shipped lane logic).
- **Verification strategy:** Assert the delegation matrix rows reduce to the v0.5.3 selector / v0.5.5 planner / v0.5.4 state machine (descriptive, not a new path).
- **Candidate future milestone:** none (shipped)
- **Attestation:** No leaked prompt body or proprietary text is copied in this card.

### Card 06 — LazyCodex: evidence-receipt stop hook
- **Source project:** LazyCodex
- **Observed mechanism:** A stop/finish hook that refuses to let a task close unless an evidence receipt (what ran, what passed) is present — completion produces a checkable artifact.
- **What DMC already has:** The evidence-log requirement and the final report format (Status / Changed Files / Verification / Evidence); the v0.5.0 run-metrics ledger.
- **Gap in DMC:** DMC's evidence is required by rule and by the report format, but there is no *hook* that mechanically blocks closure on a missing receipt.
- **Decision:** adopt
- **Rationale:** An evidence-receipt-or-no-close hook is the mechanical form of "No evidence log, no final completion claim" — a visible gate, not hidden behavior, squarely on-thesis.
- **Risk:** A hook that is advisory-only gives false assurance; mitigation is to keep it fail-closed and to state clearly it is a backstop to the human Release Gate, not a replacement.
- **Verification strategy:** A future deterministic check that a closure candidate references an existing evidence/verification artifact path (the v0.3.7 closure controller already approximates this).
- **Candidate future milestone:** v0.6.x
- **Attestation:** No leaked prompt body or proprietary text is copied in this card.

### Card 07 — LazyCodex: executor role contract
- **Source project:** LazyCodex
- **Observed mechanism:** A narrowly-scoped implementer role whose contract is "edit only within the approved scope, then hand back" — the executor does not plan, approve, or close.
- **What DMC already has:** The `executor` subagent and the file-scope lock; the worker-bridge rule that workers produce proposals and never mutate the repo.
- **Gap in DMC:** None material — DMC's executor contract and scope lock already encode this.
- **Decision:** adopt
- **Rationale:** A bounded executor role is exactly DMC's scope-locked execution; recording it as converged keeps the role taxonomy honest (Output 1 Implementer).
- **Risk:** Role bleed (executor self-approving) — already mitigated by DMC's "never self-approve in the same context" rule.
- **Verification strategy:** Assert the role taxonomy defines Implementer with `must-not: approve / close / push`.
- **Candidate future milestone:** none (shipped)
- **Attestation:** No leaked prompt body or proprietary text is copied in this card.

### Card 08 — LazyCodex: read-only code-reviewer contract
- **Source project:** LazyCodex
- **Observed mechanism:** A reviewer role that is strictly read-only — it can read, run checks, and judge, but cannot edit the code it reviews, keeping authoring and review in separate lanes.
- **What DMC already has:** The `critic` and `verifier` agents are read-only (Read/Glob/Grep/Bash); the global rule "keep authoring and review as separate passes."
- **Gap in DMC:** None material.
- **Decision:** adopt
- **Rationale:** Read-only review is a core DMC discipline (this very milestone used a separate `critic` agent that could not edit the plan); recording it reinforces Output 1's Critic/Falsifier and Release Auditor roles.
- **Risk:** A reviewer with write access could "fix and approve," collapsing the separation; mitigation is the read-only tool grant.
- **Verification strategy:** Assert the role taxonomy marks Critic/Falsifier and Release Auditor as read-only (no Edit/Write).
- **Candidate future milestone:** none (shipped)
- **Attestation:** No leaked prompt body or proprietary text is copied in this card.

### Card 09 — LazyCodex: evidence-is-untrusted-until-inspected
- **Source project:** LazyCodex
- **Observed mechanism:** Treating an agent-produced artifact (a diff, a test log, a "done" claim) as a *review input*, not a trusted fact, until a separate pass inspects it.
- **What DMC already has:** The worker-bridge no-mutation rule (a worker diff is a review artifact, not an executable patch); the redaction caveat that emitted artifacts are "not a completeness guarantee — review before commit."
- **Gap in DMC:** DMC applies this to worker diffs and evidence redaction but does not state it as a single named principle.
- **Decision:** adopt
- **Rationale:** "Untrusted until inspected" is the epistemic core of DMC's evidence policy and the foil to Fugu's "trust the orchestrator's internal verification"; naming it strengthens the whole control plane.
- **Risk:** Low; the only cost is the inspection pass, which DMC already requires.
- **Verification strategy:** Assert the adoption-decisions doc names "evidence untrusted until inspected" as a standing principle.
- **Candidate future milestone:** v0.6.x (docs)
- **Attestation:** No leaked prompt body or proprietary text is copied in this card.

### Card 10 — LazyCodex: test-relevance / anti-slop review
- **Source project:** LazyCodex
- **Observed mechanism:** A review step that checks whether tests actually exercise the changed behavior (relevance), rejecting padding or assertion-free "slop" that inflates the count without proving anything.
- **What DMC already has:** The verifier discipline and the honest-attestation rule (known-shapes-only, not a completeness guarantee).
- **Gap in DMC:** No explicit test-relevance check in the review lane.
- **Decision:** adapt
- **Rationale:** A test-relevance check is a high-value, low-magic addition to the review lane that defends against false-green; DMC adapts it as a *named reviewer criterion*, not a hidden heuristic.
- **Risk:** Over-strict relevance scoring could reject valid tests; mitigation is to keep it advisory input to a human/critic, not an auto-reject gate.
- **Verification strategy:** A future reviewer checklist item asserting changed symbols appear in the added/modified tests (a names-level check, no execution).
- **Candidate future milestone:** v0.6.x
- **Attestation:** No leaked prompt body or proprietary text is copied in this card.

### Card 11 — OmO: bounded Team Mode / hostile critic panel
- **Source project:** oh-my-openagent (OmO)
- **Observed mechanism:** Running several agents on a shared task — including adversarial critics whose job is to refute — under an explicit coordination boundary, rather than one agent acting alone.
- **What DMC already has:** The `critic` gate and the v0.5.8 dynamic delegation harness (role/critic handoff matrix); this milestone's plan passed an adversarial critic pass.
- **Gap in DMC:** DMC uses a single critic gate; it has no formal *bounded* multi-critic panel with a refute-by-default contract.
- **Decision:** adapt
- **Rationale:** A bounded hostile-critic panel raises confidence on high-risk lanes, and "bounded" is the key DMC constraint — a fixed roster and a deterministic stop, never an open-ended swarm.
- **Risk:** Panels can become unbounded cost or a quorum that launders approval; mitigation is a fixed panel size and the rule that critic PASS is advisory, never a release grant (C11).
- **Verification strategy:** Assert any panel is bounded (declared roster + deterministic stop) and that its verdict is advisory input to the human Release Gate.
- **Candidate future milestone:** v0.6.x
- **Attestation:** No leaked prompt body or proprietary text is copied in this card.

### Card 12 — OmO: lifecycle hooks
- **Source project:** oh-my-openagent (OmO)
- **Observed mechanism:** Hook points at defined lifecycle moments (before a tool runs, after a stop) where policy can intercept, deny, or annotate an action.
- **What DMC already has:** `secret-guard.sh` (Read/Grep/Glob) and `pre-tool-guard.sh` (Bash) are PreToolUse hooks; the mode switch governs enforcement.
- **Gap in DMC:** DMC's hooks are focused on secret/destructive denial; it has not enumerated a fuller lifecycle hook map (e.g., a post-stop evidence hook — see Card 06).
- **Decision:** adapt
- **Rationale:** Lifecycle hooks are how DMC's *visible* enforcement is wired; documenting the hook-point map (and where new gates could attach) is on-thesis, provided every hook is fail-closed and inspectable.
- **Risk:** Hook sprawl or a hook that silently modifies behavior; mitigation is that hooks deny/annotate visibly and are listed in the context map.
- **Verification strategy:** A docs-level map of hook points; existence-only — this milestone installs no hook (§5).
- **Candidate future milestone:** v0.6.x (docs; INTEROP.md already maps Claude Code hook points)
- **Attestation:** No leaked prompt body or proprietary text is copied in this card.

### Card 13 — OmO: hash-anchored edit / LSP / AST-grep edit-precision layer
- **Source project:** oh-my-openagent (OmO)
- **Observed mechanism:** Editing code through structure-aware tools (hash-anchored edits, language-server symbols, AST-grep) so that a change targets a precise node and fails loudly if the anchor moved, instead of fuzzy text replacement.
- **What DMC already has:** Scope-guarded `Edit`/`Write` under an approved file scope; no structure-aware edit layer.
- **Gap in DMC:** No AST/LSP/hash-anchored edit precision — DMC edits are text-level within a locked scope.
- **Decision:** defer
- **Rationale:** Edit-precision is genuinely valuable but is an *implementation-layer* capability outside v0.6.0's docs-only scope; it is recorded as a future candidate, not built now.
- **Risk:** Adopting prematurely adds tool/runtime surface (against §2); deferring risks slower, coarser edits — an acceptable trade for a research milestone.
- **Verification strategy:** When built, a deterministic check that an anchored edit aborts on anchor drift (no silent mis-edit).
- **Candidate future milestone:** defer (v0.6.x implementation candidate)
- **Attestation:** No leaked prompt body or proprietary text is copied in this card.

### Card 14 — OmO: telemetry / auto-update as reject-by-default
- **Source project:** oh-my-openagent (OmO)
- **Observed mechanism:** Background telemetry and automatic self-update enabled by default, so the tool changes its own behavior and phones home without an explicit per-run decision.
- **What DMC already has:** No telemetry, no auto-update; install is manifest-driven and collision-safe; the host-artifact policy keeps artifacts local by default.
- **Gap in DMC:** None — DMC deliberately omits these.
- **Decision:** reject
- **Rationale:** Default telemetry and silent auto-update are hidden behavior changes the user cannot see, a direct violation of the visibility thesis; rejecting is recorded as carefully as any adoption.
- **Risk:** The risk is in *not* rejecting — unverifiable behavior drift and data egress; explicit rejection removes the temptation.
- **Verification strategy:** Assert the anti-goals list names "no telemetry / no silent auto-update by default" and that no deliverable adds a network call.
- **Candidate future milestone:** none (explicit reject)
- **Attestation:** No leaked prompt body or proprietary text is copied in this card.

### Card 15 — FableCodex: goal ledger
- **Source project:** FableCodex
- **Observed mechanism:** A persistent, inspectable ledger of goals and their state (open / in-progress / done) that survives across steps, so progress is a visible record rather than in-context memory.
- **What DMC already has:** The v0.2.7 run manifest and v0.3.5 execution manifest record a run's task → provider → verification → gates → closure; the v0.5.0 metrics ledger records outcomes.
- **Gap in DMC:** DMC's manifests are per-run snapshots; there is no single durable, human-readable goal ledger spanning a multi-goal effort.
- **Decision:** adapt
- **Rationale:** A *visible* goal ledger is exactly DMC's stance — state the user can see — and is the opposite of Fugu's implicit internal state; DMC adapts it as an additive, inspectable artifact, never hidden runtime state.
- **Risk:** A ledger that drifts from reality is worse than none; mitigation is to derive it from immutable run facts (as the v0.5.4 state machine does).
- **Verification strategy:** Assert the ledger is a plain, readable artifact bound to run facts, with no field the user cannot inspect.
- **Candidate future milestone:** v0.6.x
- **Attestation:** No leaked prompt body or proprietary text is copied in this card.

### Card 16 — FableCodex: findings gate
- **Source project:** FableCodex
- **Observed mechanism:** A gate that blocks progress while unresolved findings (open defects, unmet criteria) remain, forcing them to be addressed or explicitly accepted before moving on.
- **What DMC already has:** The v0.2.6 gate-check runner (G1–G6) and the v0.3.7 closure controller mechanically judge closure conditions and fail closed.
- **Gap in DMC:** DMC gates on staged/scope/protected/evidence conditions; it has no explicit "open findings must be zero or waived" gate.
- **Decision:** adapt
- **Rationale:** A findings gate is a natural, visible addition to DMC's gate-check family and complements the reviewer loop; it stays deterministic and fail-closed.
- **Risk:** A findings gate that auto-waives defeats itself; mitigation is that any waiver is an explicit, logged human decision.
- **Verification strategy:** A future gate-check that closure is refused while any finding is marked open and unwaived.
- **Candidate future milestone:** v0.6.x
- **Attestation:** No leaked prompt body or proprietary text is copied in this card.

### Card 17 — FableCodex: coverage accounting
- **Source project:** FableCodex
- **Observed mechanism:** Tracking which parts of the intended scope have actually been touched/verified, so "what is left" is accounted for rather than assumed complete.
- **What DMC already has:** The v0.5.1 context budgeter classifies context tiers; verification planner lists required checks; no explicit scope-coverage accounting.
- **Gap in DMC:** No mechanism that maps "intended scope" to "verified scope" and reports the remainder.
- **Decision:** defer
- **Rationale:** Coverage accounting is valuable but needs a scope model to measure against; it is recorded as a future candidate rather than built in a docs-only milestone.
- **Risk:** Premature coverage metrics can be gamed (touched ≠ correct); deferring avoids a false-confidence number.
- **Verification strategy:** When built, a deterministic diff of declared-scope vs verified-scope paths.
- **Candidate future milestone:** defer (v0.6.x candidate)
- **Attestation:** No leaked prompt body or proprietary text is copied in this card.

### Card 18 — Skill ecosystem: skill-registry security & no-blind-install
- **Source project:** Skill ecosystems (AGENTS.md / SKILL.md / MCP registries)
- **Observed mechanism:** Skills/tools distributed through registries or marketplaces, selected and installed on demand — convenient, but a supply-chain surface if installed unsigned, unsandboxed, or unread.
- **What DMC already has:** Manifest-driven install with collision detection (merge/append/skip, never overwrite); the secret-protection floor; no marketplace dependency.
- **Gap in DMC:** DMC does not consume external skills, so it has no skill-vetting contract — a gap only if DMC ever adopts a skill mechanism.
- **Decision:** adopt
- **Rationale:** Adopt the *security posture* — declarative skill contracts, retrieval-by-relevance, and **no blind install** — as a standing anti-goal; this guards DMC against the most dangerous landscape temptation (executing unvetted third-party behavior).
- **Risk:** Blind install of an unsandboxed skill is a code-execution and exfiltration risk; the explicit "no blind install" rule removes it.
- **Verification strategy:** Assert the anti-goals name "no skill-marketplace blind install / no unsigned-unsandboxed skill execution."
- **Candidate future milestone:** v0.6.x (policy; only if a skill mechanism is ever proposed)
- **Attestation:** No leaked prompt body or proprietary text is copied in this card.

### Card 19 — Sakana Fugu: learned model-orchestration / capability-routing
- **Source project:** Sakana Fugu (grounded in ICLR 2026 papers TRINITY `2512.04695` / the Conductor `2512.04388`)
- **Observed mechanism:** A small model, optimized by evolution (TRINITY's sep-CMA-ES coordinator) or RL (the Conductor), *learns* which model plays which role per task — a learned, non-deterministic routing function presented as a single endpoint. Reported benchmark figures (e.g. Fugu Ultra 73.7 SWE-Bench Pro) are **self-reported / independently-unverified** and are **not** from the grounding papers.
- **What DMC already has:** Deterministic provider-routing scripts (v0.2.3) selecting from declared `provider_target` facts only (no env/secret/heuristic); model-name-free capability classes (Output 2).
- **Gap in DMC:** No learned/adaptive selection — by design.
- **Decision:** reject
- **Rationale:** Reject a learned router *as the source of truth for gates*: it is non-deterministic and non-auditable, the direct opposite of "deterministic scripts are the source of truth." (DMC still *adapts* the capability-class abstraction — see Card 22.) Independently, the Azure orchestration-patterns guidance flags using nondeterministic patterns for inherently deterministic workflows as an antipattern.
- **Risk:** Adopting learned routing as gate authority would make gates irreproducible and un-gatekeepable — catastrophic for DMC's value. The opposite risk (rejecting) is only slower adaptivity, which DMC accepts.
- **Verification strategy:** Assert the resolved route is a pure function of declared task facts (`env -i` byte-identity); no model call participates in gate selection.
- **Candidate future milestone:** none (reject as gate authority; capability-class half tracked in Card 22)
- **Attestation:** No leaked prompt body or proprietary text is copied in this card.

### Card 20 — Sakana Fugu: verification-&-synthesis as the orchestrator's responsibility
- **Source project:** Sakana Fugu (TRINITY's explicit Verifier role; Fugu "manages verification internally")
- **Observed mechanism:** The orchestrator owns verifying and synthesizing worker outputs before returning a result, rather than handing unverified output downstream.
- **What DMC already has:** `/dmc-verify-hard`, the v0.2.6 gate-check runner, the v0.5.5 verification planner, and verifier-owned approval — "No verification, no done."
- **Gap in DMC:** Minimal.
- **Decision:** adapt
- **Rationale:** Orchestrator-owned verification is sound and independently prescribed (Azure: the orchestrator/receiving agent should check output quality and retry, clarify, or halt). DMC keeps its twist: verification is a **separate, deterministic, inspectable pass**, never folded invisibly into a learned model.
- **Risk:** Low — provided verification stays a distinct artifact, not an opaque internal step the user cannot read.
- **Verification strategy:** Assert verification produces a distinct report (the v0.5.4 DONE evaluator binds to it), not an implicit orchestrator claim.
- **Candidate future milestone:** none (shipped; reaffirmed in taxonomy)
- **Attestation:** No leaked prompt body or proprietary text is copied in this card.

### Card 21 — Sakana Fugu: recursive self-delegation
- **Source project:** Sakana Fugu (calls instances of itself; the Conductor's self-selection "gives rise to recursive topologies")
- **Observed mechanism:** The orchestrator can dispatch to instances of itself, producing recursive delegation trees that expand depth dynamically.
- **What DMC already has:** Bounded worker-bridge proposals (workers never mutate the repo); scope-locked, single-level execution.
- **Gap in DMC:** No recursion — by design.
- **Decision:** defer
- **Rationale:** Defer / reject-by-default: recursion multiplies opacity, latency, and cost and conflicts with bounded, scope-locked execution. Reconsider only behind a **hard, declared, deterministic depth/budget bound** that is visible before any nested dispatch.
- **Risk:** Unbounded cost/latency and runaway autonomy — a named DMC anti-goal; the bound is the precondition for ever moving this off `defer`.
- **Verification strategy:** A deterministic depth+token bound checked before any nested dispatch; refuse on exceed.
- **Candidate future milestone:** defer (behind a bounded-recursion contract)
- **Attestation:** No leaked prompt body or proprietary text is copied in this card.

### Card 22 — Sakana Fugu: swappable model pool / capability-class abstraction
- **Source project:** Sakana Fugu (routes over a swappable pool; the Conductor "adapts to arbitrary sets of open- and closed-source agents")
- **Observed mechanism:** Routing happens over a pool of interchangeable models referenced by *role/capability*, not by hard-coded identity, so the pool can be swapped without rewriting the router.
- **What DMC already has:** Model-name-free capability classes + v0.2.9 effort/provider policy; three real provider adapters behind a deterministic router and contract.
- **Gap in DMC:** Smaller than Fugu's — DMC's routing is declarative, not dynamic, and DMC *wants* it declarative.
- **Decision:** adapt
- **Rationale:** The strongest extractable primitive: capability-class routing decouples DMC from vendor lock-in **without** a learned router — the selection rule stays a visible deterministic script. Fugu's pool-agnosticism is the real-world existence proof that model-name-free routing is feasible (Output 2).
- **Risk:** Low; keep selection deterministic and isolate model names to a separate, dated, replaceable lookup so model-name rot (R4) never reaches gate logic.
- **Verification strategy:** Assert the capability→provider lookup is data-only and env-free, and that no model-name string appears in selection logic.
- **Candidate future milestone:** v0.6.x (formalize the capability-class lookup)
- **Attestation:** No leaked prompt body or proprietary text is copied in this card.

### Card 23 — Sakana Fugu: single-endpoint OpenAI-compatible facade
- **Source project:** Sakana Fugu (the multi-agent system exposed as one OpenAI-compatible model — Chat Completions + Responses)
- **Observed mechanism:** A whole multi-agent system presented behind one standard chat endpoint, so callers integrate it like any single model.
- **What DMC already has:** Provider adapters (glm-api mock-first, oauth-cli, manual-import) behind a deterministic router; no single unified facade.
- **Gap in DMC:** No single facade over the adapters.
- **Decision:** adapt
- **Rationale:** Adapt optionally: a single facade is an ergonomic convenience orthogonal to gating — **as long as it does not hide the routing decision from the deterministic gate logs.** The facade must remain a thin surface over visible routing, never a place where provenance disappears.
- **Risk:** A facade can mask which provider/class actually served a call; mitigation is to log the resolved capability class + provider on every facade call.
- **Verification strategy:** Assert every facade call emits a provenance line (resolved class + provider) to the run log.
- **Candidate future milestone:** v0.6.x (optional, low priority)
- **Attestation:** No leaked prompt body or proprietary text is copied in this card.

---

## Card index & decisions (summary)

| # | Primitive | Decision |
|---|-----------|----------|
| 01 | Fablize — capability/procedure boundary | adapt |
| 02 | Fablize — multi-criterion verification gate | adapt |
| 03 | Fablize — early-stop prevention | adapt |
| 04 | Fablize — systematic investigation protocol | adopt |
| 05 | Fablize — per-task discipline router | adapt |
| 06 | LazyCodex — evidence-receipt stop hook | adopt |
| 07 | LazyCodex — executor role contract | adopt |
| 08 | LazyCodex — read-only code-reviewer contract | adopt |
| 09 | LazyCodex — evidence-untrusted-until-inspected | adopt |
| 10 | LazyCodex — test-relevance / anti-slop review | adapt |
| 11 | OmO — bounded Team Mode / hostile critic panel | adapt |
| 12 | OmO — lifecycle hooks | adapt |
| 13 | OmO — hash-anchored / LSP / AST-grep edit precision | defer |
| 14 | OmO — telemetry / auto-update by default | reject |
| 15 | FableCodex — goal ledger | adapt |
| 16 | FableCodex — findings gate | adapt |
| 17 | FableCodex — coverage accounting | defer |
| 18 | Skill ecosystem — registry security & no-blind-install | adopt |
| 19 | Fugu — learned model-orchestration / capability-routing | reject |
| 20 | Fugu — verification-&-synthesis as orchestrator responsibility | adapt |
| 21 | Fugu — recursive self-delegation | defer |
| 22 | Fugu — swappable pool / capability-class abstraction | adapt |
| 23 | Fugu — single-endpoint OpenAI-compatible facade | adapt |

**Tally:** adopt ×6 · adapt ×12 · reject ×2 · defer ×3 (23 cards). Most decisions are `adapt`/`defer`, consistent with the plan's non-goal that v0.6.0 is a decision matrix, not a build order.

**Milestone disclaimer:** these cards are **architecture guidance, not enforcement**. No card authorizes building anything; each names a DMC-equivalent or an explicit rejection reason. All Sakana Fugu benchmark numbers are self-reported and independently unverified.
