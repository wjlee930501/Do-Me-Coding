# RESEARCH NOTE — Sakana Fugu as a DMC v0.6.0 Benchmark Subject (DRAFT)

**Status:** DRAFT research artifact. **NOT** a v0.6.0 deliverable, **NOT** committed, **NOT** approved.
Exploratory input gathered *before* `/dmc-critic` on the v0.6.0 plan, to decide whether Sakana Fugu should be
folded into `docs/HARNESS_LANDSCAPE_2026.md` (a new Section I) and `docs/HARNESS_BENCHMARK_CARDS_2026.md`
(cards #19–#23). If accepted, this becomes a plan revision under `/dmc-plan-hard`, re-critic, then build.

**Method:** desk research only (deep-research harness, 19 sources, 92 claims, 25 adversarially verified — 23 confirmed /
2 killed). No mechanism executed, no live call, no network beyond read-only fetch. No leaked/proprietary/system-prompt
text. All quotes are short public-page / arXiv-abstract fragments with attribution.

**Date context:** Fugu launched 2026-06-22; this note written 2026-06-23 (~1 day old — everything is provisional).

---

## 0. TL;DR

Sakana Fugu is **the precise philosophical foil to DMC on the visibility axis.** Both see the same structure ("frontier
models orchestrate, cheaper/specialist models implement"), but they put the **source of truth** in opposite places:

- **Fugu:** a *hidden, learned, non-deterministic* router (an LLM trained by evolution/RL) IS the orchestration. The
  multi-agent complexity "never reaches your code." Trust comes from benchmark scores.
- **DMC:** *visible, deterministic scripts* are the source of truth for gates; a human is the Release Gate. Trust comes
  from auditable evidence.

That contrast makes Fugu a high-value v0.6.0 entry: it yields one clear **REJECT** (opaque learned routing as gate
authority — the core foil) and three clean **ADAPT**s (capability-class routing, orchestrator-owned-but-separate
verification, OpenAI-compatible facade), plus one **DEFER** (recursive self-delegation, only behind hard bounds).

---

## 1. What Fugu actually is — VERIFIED (high confidence, primary-sourced)

A **learned orchestrator LLM**, not a single trained frontier model. It is "itself a language model trained to call
various LLMs in an agent pool, including instances of itself recursively," managing **model selection, delegation,
verification, and synthesis internally** behind **one OpenAI-compatible endpoint** (Chat Completions + Responses). The
agent pool includes GPT-5.5, Claude Opus 4.8, Gemini 3.1 Pro, plus open-source models; an operator can opt providers out
of the **base Fugu** pool (the **Fugu Ultra** pool is fixed).

- Two variants: **Fugu** (balanced latency/quality default) · **Fugu Ultra** (max accuracy, more agents, slower).
- Even skeptics ("it's just a router/wrapper") *confirm the architecture* and contest only its significance.
- Availability stated as global except EU/EEA (per brief; **not** independently confirmed in surviving claims).

*Sources:* sakana.ai/fugu-release, github.com/SakanaAI/fugu, sakana.ai/fugu (primary); the-decoder, marktechpost (press).

## 2. The method — TRINITY + the Conductor — VERIFIED (arXiv full-text via pdftotext)

Fugu is **grounded in** two ICLR 2026 Sakana papers (the production model is asserted to be "grounded in," not proven to
*be*, these exact checkpoints):

- **TRINITY** (arXiv **2512.04695**): a **~0.6B-param coordinator + ~10K-param head**, optimized by an **evolution
  strategy (sep-CMA-ES)** explicitly chosen over RL / imitation-learning / random-search. At each turn the coordinator
  assigns one of three roles — **Thinker / Worker / Verifier** — to a selected LLM, "offloading complex skill acquisition
  from the coordinator itself." Reports 86.2% LiveCodeBench.
- **The Conductor** (arXiv **2512.04388**): a **7B model trained with RL (GRPO)** that "learns not only to design targeted
  communication topologies … but also to prompt engineer focused instructions to the LLMs," over **randomized/swappable
  pools** ("adapts to arbitrary sets of open- and closed-source agents"). Self-selection "gives rise to **recursive
  topologies**." Reports GPQA-Diamond 87.5; SOTA LiveCodeBench.

**Why this matters for DMC:** these are concrete, peer-reviewed prior-art for a **learned, non-deterministic orchestration
router** — the exact primitive DMC must decide to adapt or reject.

## 3. Performance claims — VERIFIED-AS-CLAIMED, UNVERIFIED-INDEPENDENTLY

| Benchmark | base Fugu | Fugu Ultra | Baselines (provider-reported) |
|-----------|-----------|-----------|-------------------------------|
| SWE-Bench Pro | 59.0 | **73.7** | Opus 4.8 69.2 · GPT-5.5 58.6 · Gemini 3.1 Pro 54.2 |

- **Tag: VERIFIED that the numbers are claimed** (match sakana.ai/fugu verbatim) — **UNVERIFIED independently.** Baselines
  are provider-reported, scaffolded with `mini-swe-agent`; as of 2026-06-23 **no third party has re-run the tasks, no
  per-task grid, no eval harness released** (the-decoder / MarkTechPost / VentureBeat all add this caveat).
- **Not** claimed to beat Fable 5 (80.0 on the page). The release-page *body* shows no inline numbers (scores live in
  images); plain-text numbers render only on the sakana.ai/fugu technical page.
- **PROVENANCE GAP (verified):** the 73.7 figure is **NOT** from the grounding papers. The Conductor paper has **zero**
  SWE-Bench references and reports **~3% absolute gains** on LiveCodeBench/GPQA/AIME25 (framed as "generational-scale,"
  mirroring o3→GPT-5). The headline product number is severed from the peer-reviewed substrate.

## 4. Export-control / vendor-lock-in framing — DISPUTED

Primary verbatim: "an underlying pool of entirely swappable agents. If a single provider restricts access, Fugu
dynamically routes around the disruption … frontier capability without the risk of export controls" (motivated by export
controls on Anthropic's Fable/Mythos). **The framing is real and primary-sourced; its truth is disputed:** independent
critics note "resilience is not independence — the pool is still US-controlled frontier models (Opus/GPT/Gemini-class)."
Swappability is operator-controlled for base Fugu; **Ultra's pool is fixed.**

---

## 5. DMC framing — the visibility-axis foil + adopt/adapt/reject/defer

DMC thesis (from `DMC.md`): *visible deterministic scripts are the source of truth for gates; a human is the Release
Gate; anti-goals = no token-max, no hidden prompt magic, no opaque autonomous action.* Fugu inverts the source-of-truth.

### Candidate benchmark cards (v0.6.0 §4.2 schema) — Fugu primitives (a)–(e)

#### Card #19 — Fugu: learned model-orchestration / capability-routing
- **Source project:** Sakana Fugu (TRINITY sep-CMA-ES coordinator; Conductor RL/GRPO router).
- **Observed mechanism:** a small LLM, optimized by evolution/RL, decides per-task which model plays which role — a
  *learned, non-deterministic* routing function.
- **What DMC already has:** deterministic provider-routing scripts (v0.2.3) + model-name-free capability classes; pure-
  function selection from `provider_target` (no env/secret/heuristic).
- **Gap in DMC:** no learned/adaptive selection (by design).
- **Decision:** **REJECT** learned routing *as gate source-of-truth*; **ADAPT** only the capability-class abstraction.
- **Rationale:** a learned router is non-deterministic and non-auditable — directly violates "deterministic scripts are
  the source of truth for gates." Supported independently: Azure design-patterns guide flags "nondeterministic patterns
  for inherently deterministic workflows" as an explicit **antipattern**; the COBOL study found deterministic
  orchestration "improves worst-case robustness and reduces variability" *within structured-validation regimes*.
- **Risk:** if adopted, gates become irreproducible, opaque, un-gatekeepable (catastrophic for DMC's whole value prop).
- **Verification strategy:** a deterministic check that the resolved route is a pure function of declared task facts
  (`env -i` byte-identity, already DMC's v0.3.4 pattern).
- **Candidate milestone:** none (reject) / capability-class half → see Card #22.
- **Attestation:** No leaked prompt body or proprietary text is copied in this card.

#### Card #20 — Fugu: verification-&-synthesis as the orchestrator's responsibility
- **Observed mechanism:** TRINITY assigns an explicit **Verifier** role; Fugu "manages … verification … internally."
- **What DMC already has:** `/dmc-verify-hard`, gate-check-runner (v0.2.6), verifier-owned approval, v0.5.5 verification
  planner — "No verification, no done."
- **Gap in DMC:** minimal.
- **Decision:** **ADAPT.**
- **Rationale:** orchestrator-owned verification is sound and independently prescribed (Azure: "the orchestrator or
  receiving agent should check output quality and either retry, request clarification, or halt"). **DMC's twist holds:**
  verification stays a *separate, deterministic pass* — never folded invisibly into a learned model.
- **Risk:** low.
- **Verification strategy:** existing self-test harness pattern; assert verification is a distinct artifact, not implicit.
- **Candidate milestone:** already shipped; reaffirm in taxonomy.
- **Attestation:** No leaked prompt body or proprietary text is copied in this card.

#### Card #21 — Fugu: recursive self-delegation
- **Observed mechanism:** Fugu calls instances of itself; Conductor self-selection "gives rise to recursive topologies."
- **What DMC already has:** bounded worker-bridge proposals (workers never mutate the repo; scope-locked execution).
- **Gap in DMC:** no recursion (by design).
- **Decision:** **DEFER / REJECT-by-default.**
- **Rationale:** recursion multiplies opacity, latency, and cost and conflicts with bounded, scope-locked execution.
  Only reconsider if a **deterministic depth/budget bound** is enforced and visible.
- **Risk:** unbounded cost/latency, runaway autonomy (a named DMC anti-goal).
- **Verification strategy:** a hard, declared depth+token bound checked deterministically before any nested dispatch.
- **Candidate milestone:** defer (behind a bounded-recursion contract) — open question Q4.
- **Attestation:** No leaked prompt body or proprietary text is copied in this card.

#### Card #22 — Fugu: swappable model pool / capability-class abstraction
- **Observed mechanism:** routes over a swappable pool; Conductor "adapts to arbitrary sets of open- and closed-source
  agents."
- **What DMC already has:** model-name-free capability classes + effort/provider policy (v0.2.9); 3 real provider adapters
  + router + contract.
- **Gap in DMC:** smaller than Fugu's — no *dynamic* routing (but DMC doesn't want dynamic; it wants declarative).
- **Decision:** **ADAPT** — *the strongest extractable primitive.*
- **Rationale:** capability-class routing decouples DMC from vendor lock-in **without** a learned router — the selection
  rule stays a deterministic, visible script. Conductor's pool-agnosticism validates the abstraction's feasibility. This
  is exactly DMC's v0.6.0 Output 2 (capability classes named by capability, never by hard-coded model name).
- **Risk:** low; keep selection deterministic; isolate model names to a replaceable dated lookup.
- **Verification strategy:** assert capability→provider lookup is data-only and env-free; no model-name strings in logic.
- **Candidate milestone:** v0.6.x (formalize capability-class lookup) — the natural successor primitive.
- **Attestation:** No leaked prompt body or proprietary text is copied in this card.

#### Card #23 — Fugu: single-endpoint OpenAI-compatible facade
- **Observed mechanism:** the whole multi-agent system is exposed as one OpenAI-compatible model (Chat Completions +
  Responses).
- **What DMC already has:** provider adapters (glm-api mock-first, oauth-cli, manual-import) behind a router.
- **Gap in DMC:** no single unified facade.
- **Decision:** **ADAPT (optional).**
- **Rationale:** a single facade improves ergonomics and is orthogonal to gating — *as long as the facade does NOT hide
  routing decisions from the deterministic gate logs.*
- **Risk:** a facade could mask provenance → mitigate by logging the resolved capability class/provider on every call.
- **Verification strategy:** assert every facade call emits a provenance line (resolved class + provider) to the run log.
- **Candidate milestone:** v0.6.x (optional, low priority).
- **Attestation:** No leaked prompt body or proprietary text is copied in this card.

### Reject-vs-adapt summary
- **REJECT:** opaque learned routing as source-of-truth for gates (the core foil).
- **ADAPT:** capability-class routing (#22), orchestrator-owned-but-separate verification (#20), OpenAI-compatible facade (#23).
- **DEFER:** recursive self-delegation (#21) behind hard deterministic bounds.

---

## 6. Independent corroboration for DMC's thesis (with honest limits)

- **COBOL→Python study** (arXiv **2605.09894**, Bucknell/Astrio): holding models/prompts/tools constant and varying only
  execution control, deterministic orchestration "**improves worst-case robustness and reduces performance variability
  across runs**" on NIST COBOL85 (~382 programs). **CAVEAT:** domain-specific; the paper disclaims universal
  generalization.
- **HONESTY FLAG — two stronger versions of this study's claims were REFUTED 0-3 in verification and are excluded:**
  (i) deterministic orchestration achieves *general* accuracy-parity with agentic orchestration, and (ii) deterministic
  orchestration is *3.5× cheaper* in tokens. **Do NOT cite "determinism is free" or "determinism is 3.5× cheaper."** The
  defensible claim is only the narrower robustness/variability result within a structured-validation regime.
- **Azure AI agent design patterns guide** (Microsoft Learn): deterministic-vs-dynamic is a core design axis; mandatory
  human-in-the-loop gates "make the orchestration synchronous … approval is required only for sensitive operations" —
  operationalizing DMC's "human is the Release Gate."

---

## 7. Open questions

1. Will any third party independently replicate Fugu Ultra's 73.7 SWE-Bench Pro (per-task grid / neutral scaffold)?
2. What is Fugu's real latency and per-request cost overhead from multi-model orchestration + recursive self-calls vs.
   calling the single best frontier model directly? (the "is no-vendor-lock-in real?" critique)
3. Is production Fugu literally the TRINITY/Conductor checkpoints, a scaled successor, or only "grounded in" that research
   — and what produces the 73.7 number if not those papers' methods?
4. Can DMC define a deterministic, auditable **capability-class router** (Card #22) that captures the swappable-pool
   benefit while keeping selection a visible script — and what bounded depth/budget contract makes recursive
   self-delegation (Card #21) acceptable rather than rejected outright?

---

## 8. How this folds into v0.6.0 (proposed, not yet done)

- `docs/HARNESS_LANDSCAPE_2026.md` → add **Section I — Sakana Fugu (learned orchestration-as-a-model)**: structural
  pattern in DMC's own words + adopt/adapt/reject/defer + the visibility-axis foil framing.
- `docs/HARNESS_BENCHMARK_CARDS_2026.md` → add **cards #19–#23** above (floor rises from ≥18 to ≥23).
- `docs/DMC_ADOPTION_DECISIONS.md` → add the Fugu rows; reinforce **Output 5 anti-goal**: "no opaque learned routing as
  gate authority."
- `docs/ORCHESTRATION_TAXONOMY.md` → Card #22 directly strengthens **Output 2 (capability-class taxonomy)** with a real-
  world existence proof of pool-agnostic routing.
- Plan §4.1 floor + §6 verify assertions (V7 "≥18 cards") would update to ≥23.

**Doing this = a v0.6.0 plan revision** → re-run `/dmc-critic` on the revised DRAFT before any build. This note changes
nothing in the committed plan yet.

---

## 9. Sources

**Primary:** sakana.ai/fugu-release · sakana.ai/fugu · github.com/SakanaAI/fugu · arXiv 2512.04695 (TRINITY) ·
arXiv 2512.04388 (the Conductor) · arXiv 2605.09894 (COBOL study) · learn.microsoft.com Azure AI agent design patterns.

**Reputable press (corroboration):** the-decoder.com · marktechpost.com · venturebeat.com · asia.nikkei.com ·
artificialintelligence-news.com · seekingalpha.com · gigazine.net.

**Treated as low-trust / not relied on:** sakanafugu.com · coursiv.io · digitalapplied.com · buildfastwithai.com.

**Attestation:** No leaked prompt body, system-prompt text, proprietary text, or secret-shaped string is reproduced in
this note. All performance numbers are tagged self-reported / independently-unverified.
