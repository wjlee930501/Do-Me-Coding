# Harness Landscape 2026

**Milestone:** DMC v0.6.0 — Harness Landscape & Orchestration Taxonomy.
**Nature:** **architecture guidance, not enforcement.** This document surveys the 2026 agent-harness landscape and records, for each category, the structural pattern (in DMC's own words), an `adopt / adapt / reject / defer` decision, the DMC rationale, and the risk. It is the research backing for the benchmark cards (`HARNESS_BENCHMARK_CARDS_2026.md`), the taxonomy (`ORCHESTRATION_TAXONOMY.md`), and the adoption decisions (`DMC_ADOPTION_DECISIONS.md`).

**Discipline.** Structural lessons only, own words. No leaked, proprietary, or system-prompt text is reproduced; no README is dumped; external projects are described at the *pattern* level, not by asserting unverifiable internal facts. DMC identity takes precedence over ecosystem trends: a fashionable pattern is recorded as a `reject` as carefully as a useful one is recorded as an `adopt`. This is not admiration-driven documentation — the goal is a decision matrix, not praise.

**Operating thesis.** DMC is a *visible control plane for bounded AI agents*: deterministic scripts are the source of truth for gates; a human is the Release Gate for irreversible actions; frontier models may orchestrate and cheaper/specialist models may implement; nothing load-bearing is hidden.

Categories map 1:1 to the sections below: **A** LazyCodex/OmO · **B** Fablize · **C** FableCodex · **D** SuperClaude & command/mode frameworks · **E** OpenHands/SWE-agent/Aider-class production agents · **F** Skill ecosystems · **G** Prompt-leak & hidden-guardrail lessons · **H** DMC current-state comparison · **I** Sakana Fugu.

---

## A. LazyCodex / oh-my-openagent (OmO)

**Structural pattern (own words).** A discipline layer over a coding agent: named roles (executor, read-only reviewer), lifecycle hook points, evidence receipts at stop time, routing by *model category* rather than model name, and high-throughput "keep working" loop modes. The value is in making discipline mechanical — a stop hook that wants an evidence receipt, a reviewer that cannot edit — rather than relying on the model to behave.

**Decision:** **adapt** (evidence receipts, role separation, lifecycle hooks, model-category routing) · **reject** (auto-unbounded loops, default telemetry / auto-update).

**Rationale.** Evidence-receipt-or-no-close, read-only review, and capability-class routing are the *visible-gate* forms of ideas DMC already holds; DMC adapts them as named primitives (cards 06–12, 22). The loop-until-done behavior and default telemetry/auto-update are rejected: an open-ended drive and silent self-modification are exactly the hidden behavior the visibility thesis forbids (card 14).

**Risk.** The temptation is to import the throughput loop wholesale and inherit unbounded cost and runaway autonomy. Mitigation: every adopted primitive must reduce to a deterministic, bounded gate with the human Release Gate intact.

## B. Fablize

**Structural pattern (own words).** A capability-vs-procedure discipline: separate *what the agent can do* from *the fixed steps it must follow*, ground completion in multi-criterion verification, prevent early stop, and run a systematic investigation protocol before proposing fixes. Discipline is carried by the procedure layer so capability stays flexible without overriding the steps.

**Decision:** **adopt** (systematic investigation protocol) · **adapt** (capability/procedure boundary, multi-criterion verification, early-stop prevention, per-task discipline routing).

**Rationale.** These converge with DMC's default loop and verification planner (cards 01–05). DMC adapts them but insists the anti-early-stop mechanism be a **visible bounded gate**, never hidden "keep going" pressure — the same outcome, achieved without magic.

**Risk.** Early-stop prevention misread as an auto-loop becomes a DMC anti-goal. Mitigation: completion binds to a deterministic verification report, not a model's self-assessment.

## C. FableCodex

**Structural pattern (own words).** Local, durable state for an agent effort: a goal ledger that records goals and their status, a findings gate that blocks progress while defects are open, coverage accounting for what is done versus left, and a refusal to claim a hidden runtime. The emphasis is on state the user can read.

**Decision:** **adapt** (goal ledger, findings gate) · **defer** (coverage accounting) · the no-hidden-runtime stance is **adopted** as standing principle.

**Rationale.** A *visible* goal ledger and a fail-closed findings gate are DMC-shaped — state the user can see, the opposite of implicit internal state (cards 15–16). Coverage accounting needs a scope model first, so it is deferred (card 17). "No hidden runtime claim" is already a DMC rule and is reinforced.

**Risk.** A ledger or coverage number that drifts from reality gives false confidence. Mitigation: derive ledger state from immutable run facts (as the v0.5.4 state machine does); don't ship a metric that can be gamed.

## D. SuperClaude & command/mode frameworks

**Structural pattern (own words).** A vocabulary of slash-commands and modes plus specialist agents and MCP integrations, often paired with token-efficiency claims. The useful core is a *small, legible* command/mode vocabulary and clear specialist separation; the hazard is mode sprawl and efficiency claims that cannot be checked.

**Decision:** **adapt** (a small legible command/mode vocabulary; specialist separation) · **reject** (unverifiable token-efficiency claims, mode sprawl).

**Rationale.** DMC already exposes a small command set (`/dmc-plan-hard`, `/dmc-critic`, `/dmc-start-work`, `/dmc-verify-hard`) and specialist agents (planner/critic/executor/verifier); a legible vocabulary is on-thesis. Unverifiable efficiency claims are rejected — every efficiency claim DMC makes must be backed by a deterministic check or marked `unverified` (R6).

**Risk.** Command/mode growth erodes legibility. Mitigation: keep the vocabulary minimal and map each command to a gate, not a feature.

## E. OpenHands / SWE-agent / Aider-class production agents

**Structural pattern (own words).** Production coding agents that run an LLM against a real repo with an execution loop, often inside a sandbox/runtime with some isolation, multi-LLM routing, and reviewability of the actions taken. The strengths are sandboxing/runtime isolation and the ability to review what was done; the hazards are default network/live access and opaque autonomous action.

**Decision:** **adapt** (sandboxing / runtime isolation, action reviewability) · **reject** (default network/live access, opaque autonomous action).

**Rationale.** Isolation and reviewability map onto DMC's branch/worktree isolation guard (v0.4.2) and the review packet (v0.5.6); DMC adapts them. Default live/network access and opaque action are rejected — DMC is mock-first, offline-by-default, with live paths multi-gated and proposal-only worker output.

**Risk.** Importing a "just let it run against the repo with network" posture would breach the secret-protection floor and the no-live-by-default rule. Mitigation: keep execution scope-locked, offline by default, and every live path human-gated.

## F. Skill ecosystems (AGENTS.md / SKILL.md / MCP registries)

**Structural pattern (own words).** Skills and tools described declaratively and distributed through registries/marketplaces, selected on demand by relevance. The useful core is the declarative contract and retrieval-by-relevance; the hazard is a supply-chain surface — blind install of unsigned, unsandboxed, unread third-party behavior.

**Decision:** **adopt** (declarative skill contracts, retrieval-by-relevance, **no blind install** as a security posture).

**Rationale.** DMC does not currently consume external skills, so the high-value adoption here is the *posture*: if DMC ever adds a skill mechanism, it must use declarative contracts and forbid blind marketplace install (card 18). This guards against the landscape's most dangerous temptation — executing unvetted code.

**Risk.** Blind install is a code-execution and exfiltration risk. Mitigation: the explicit "no unsigned/unsandboxed skill, no blind install" anti-goal.

## G. Prompt-leak & hidden-guardrail lessons

**Structural pattern (own words).** Across the ecosystem, system prompts and hidden guardrails sometimes leak. The **only** thing recorded here is the *structural meta-lesson*: hidden guardrails create unverifiable trust — a user cannot audit a control they cannot see, and a leaked prompt is both a confidentiality failure and evidence that hidden behavior was load-bearing. This section stores **zero** leaked content.

**Decision:** **adopt** the meta-lesson: prefer **visible gates over hidden behavior modification**; **reject** prompt-leak mimicry as a strategy.

**Rationale.** This is the philosophical spine of DMC. A gate the user can read and a script the user can run are auditable; a hidden instruction is not. DMC therefore puts its discipline in inspectable scripts and docs, not in concealed prompt text — and never copies another system's leaked text (a standing safety constraint, backstopped by the per-card attestation and the verify script's structural checks).

**Risk.** The risk is twofold: reproducing leaked text (a confidentiality and legal hazard) and being seduced into building hidden guardrails for short-term control. Mitigation: own-words rule, no-copy attestation on every card, and the visibility thesis as a hard constraint.

## H. DMC current-state comparison

**Structural pattern (own words).** A map of DMC v0.1–v0.5 against the external-harness categories (A–F and I), separating *already-covered* capabilities, *missing* capabilities, and *dangerous temptations to reject*. This grounds every adoption decision in what DMC has already proved rather than in admiration for another tool.

**Already covered (converged):** scope-locked execution and an executor role (card 07); read-only review (card 08); per-task discipline routing (card 05); orchestrator-owned-but-separate verification (card 20); deterministic capability/provider routing and model-name-free classes (cards 19/22); branch/worktree isolation and review packets (category E); manifest-driven, telemetry-free install (category A reject).

**Missing (candidate adopt/adapt):** an evidence-receipt stop hook (card 06); a named "untrusted until inspected" principle (card 09); a test-relevance review criterion (card 10); a durable visible goal ledger (card 15); a findings gate (card 16); a documented lifecycle hook-point map (card 12).

**Dangerous temptations (reject/defer):** learned routing as gate authority (card 19, reject); recursive self-delegation without bounds (card 21, defer); default telemetry/auto-update (card 14, reject); unbounded loop modes (category A reject); coverage metrics that can be gamed (card 17, defer); edit-precision tooling outside this milestone's scope (card 13, defer).

**Decision:** **adapt** — H is descriptive; it produces no new mechanism, only the grounding for the other sections' decisions.

**Rationale.** DMC's adoption decisions are credible only because most of the landscape's safe primitives are already shipped; the genuine new value is a handful of *visible* additions and a clear list of rejections.

**Risk.** Over-claiming "already done" could mask a real gap. Mitigation: each "covered" item points at a specific shipped artifact; each "missing" item points at a specific card.

## I. Sakana Fugu (learned orchestration-as-a-model)

**Structural pattern (own words).** Sakana Fugu (launched 2026-06-22) packages a multi-agent system *as a single model*: a learned orchestrator LLM that selects, delegates to, verifies, and synthesizes a swappable pool of other frontier models (including recursive calls to itself) behind one OpenAI-compatible endpoint, so "the complexity never reaches the caller's code." It is grounded in two ICLR 2026 Sakana papers — **TRINITY** (`2512.04695`, a ~0.6B coordinator + ~10K head optimized by the sep-CMA-ES evolution strategy, assigning Thinker/Worker/Verifier roles) and **the Conductor** (`2512.04388`, a 7B RL-trained model that designs agent communication topologies and per-worker instructions over randomized pools). Headline performance (e.g. Fugu Ultra **73.7 SWE-Bench Pro**) is **self-reported / independently-unverified**, and the 73.7 figure is provably **not** from the grounding papers (which report ~3% gains on LiveCodeBench/GPQA/AIME25, zero SWE-Bench references).

**Decision:** **reject** opaque learned routing as the source of truth for gates (cards 19, 21) · **adapt** capability-class/swappable-pool routing (22), orchestrator-owned-but-separate verification (20), single-endpoint facade (23) · **defer** recursive self-delegation behind hard bounds (21).

**Rationale.** Fugu is the precise **visibility-axis foil** to DMC (see the dedicated discussion below). It shares DMC's structural insight — frontier orchestrates, others implement — but places the source of truth inside a hidden, learned, non-deterministic model, where DMC places it in visible deterministic scripts. The extractable, non-magical primitives (capability-class routing, separate verification, a thin facade) are adapted; the learned router as gate authority is rejected; recursion is deferred behind a deterministic depth/budget bound.

**Risk.** The dual risk is (a) admiring the benchmark numbers and importing the opaque router — which would make DMC's gates irreproducible — and (b) treating self-reported scores as fact. Mitigation: cards 19–23 tag every number unverified, and the anti-goals forbid both opaque learned routing as gate authority and self-reported-benchmark-as-verified.

---

## The central question — Learned Orchestrator vs Deterministic Control Plane

> The goal is **not** to decide whether Fugu is good. The goal is to decide whether DMC should **learn** orchestration, **encode** orchestration, or **combine both**. Fugu is the comparison input; DMC's identity is the deciding criterion.

**Two poles.**

- **Learned orchestrator (Fugu pole).** Orchestration *is* a model. A small network, trained by evolution or RL, decides routing, delegation, verification, and synthesis. Strengths: adaptivity to arbitrary pools, ergonomic single endpoint, and (claimed) frontier-level results. Cost: the decision procedure is **non-deterministic and non-auditable** — you cannot read it, diff it, or prove why a gate opened, and trust rests on benchmark scores rather than inspection.
- **Deterministic control plane (DMC pole).** Orchestration is *encoded* in visible scripts and gates. Strengths: every routing/gate decision is reproducible (`env -i` byte-identical), auditable, and human-gated at the Release Gate. Cost: less automatic adaptivity — a human or a script must encode the routing rule.

**Where each is right.** Independent evidence supports the deterministic pole *in DMC's regime*: the Azure agent-design-patterns guidance names "using nondeterministic patterns for inherently deterministic workflows" as an antipattern and prescribes orchestrator-owned verification plus mandatory human gates for sensitive operations; a controlled COBOL-to-Python study found that deterministic orchestration "improves worst-case robustness and reduces variability across runs" within a structured-validation regime. **Honesty bound:** that same study's stronger claims — general accuracy-parity and a large token-cost reduction — were adversarially refuted and are **not** relied on here; the defensible claim is only the narrower robustness/variability result in a structured-validation regime. So "deterministic is free" is **not** asserted; "deterministic is auditable and robust where the workflow is inherently deterministic" is.

**DMC's answer: encode the gates, optionally learn the suggestions — never let learning be the gate.**

1. **Encode (load-bearing).** Every decision that opens a gate, selects a lane, or authorizes an irreversible action stays a **deterministic, visible script**. This is non-negotiable and is the source of truth (anti-goal: no opaque learned routing as gate authority).
2. **Combine (advisory only).** A learned/adaptive component may *suggest* — propose a capability class, draft a delegation, rank candidate providers — but its output is a **review input**, untrusted until inspected (card 09), and it can never be the thing that opens a gate. This is the bounded "combine both": learning informs, encoding decides.
3. **Do not learn the orchestration itself.** DMC does not adopt a learned router as the control plane, because a control plane whose decisions cannot be audited cannot be a control plane in DMC's sense. The capability-class abstraction (card 22) captures Fugu's genuine benefit — pool-agnostic, model-name-free routing — *without* the learned, opaque part.

**One-line resolution.** DMC **encodes** orchestration and may **combine** a learned advisor in a strictly advisory, untrusted-until-inspected role; it does **not learn** the orchestration that gates irreversible actions. The deterministic control plane is the spine; any learned component is a guest that never holds the keys.

---

## Source table

Each row records the project, the pattern surveyed, the public source class (official page, peer-reviewed paper, reputable press, or DMC's own prior artifact), and the no-leak note. No leaked or proprietary text is reproduced; external descriptions are pattern-level and own-words.

| Project | Pattern surveyed | Public source / own-prior-artifact | No-leak note |
|---------|------------------|-------------------------------------|--------------|
| LazyCodex | discipline roles, evidence receipts, lifecycle hooks, model-category routing | public project descriptions (pattern level) | own-words; no README/prompt text reproduced |
| oh-my-openagent (OmO) | bounded team/critic panel, lifecycle hooks, edit-precision, telemetry/auto-update | public project descriptions (pattern level) | own-words; no README/prompt text reproduced |
| Fablize | capability/procedure boundary, multi-criterion verification, early-stop prevention, systematic investigation | public project descriptions (pattern level) | own-words; structural lesson only |
| FableCodex | goal ledger, findings gate, coverage accounting, no-hidden-runtime | public project descriptions (pattern level) | own-words; structural lesson only |
| SuperClaude & command/mode frameworks | command/mode vocabulary, specialist separation, token-efficiency claims | public project descriptions (pattern level) | own-words; efficiency claims marked unverified |
| OpenHands / SWE-agent / Aider | sandboxing/runtime isolation, multi-LLM routing, reviewability | public open-source project descriptions (pattern level) | own-words; no code/prompt reproduced |
| Skill ecosystems (AGENTS.md / SKILL.md / MCP) | declarative skill contracts, registry security, blind-install hazard | public ecosystem conventions (pattern level) | own-words; structural lesson only |
| Prompt-leak & hidden-guardrail lessons | meta-lesson: hidden guardrails create unverifiable trust | the structural meta-lesson only | **zero leaked content stored** |
| Sakana Fugu | learned orchestration-as-a-model, swappable pool, recursive self-delegation, single facade | sakana.ai/fugu, sakana.ai/fugu-release, github.com/SakanaAI/fugu (primary); reputable press (corroboration) | own-words; benchmark numbers tagged self-reported/unverified |
| TRINITY (Sakana) | evolved coordinator (sep-CMA-ES), Thinker/Worker/Verifier roles | arXiv `2512.04695` (peer-reviewed, ICLR 2026) | own-words paraphrase of abstract-level facts |
| the Conductor (Sakana) | RL-trained topology/instruction design over randomized pools | arXiv `2512.04388` (peer-reviewed, ICLR 2026) | own-words paraphrase of abstract-level facts |
| Deterministic-vs-agentic control (independent) | deterministic orchestration robustness/variability (structured-validation regime) | arXiv `2605.09894`; Microsoft Azure AI agent design patterns | own-words; refuted stronger claims excluded |
| DMC (own prior artifacts) | scope lock, gates, routing, manifests, verification planner, review packet, resume controller | DMC v0.1–v0.5 (this repo) | own artifacts; no external text |

**Milestone disclaimer:** this document is **architecture guidance, not enforcement**. It selects no model, opens no gate, and authorizes no build; it produces the decision matrix that names v0.6.1–v0.6.9 candidates.
