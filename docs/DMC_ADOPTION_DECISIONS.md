# DMC Adoption Decisions

**Milestone:** DMC v0.6.0 — Harness Landscape & Orchestration Taxonomy.
**Nature:** **architecture guidance, not enforcement.** This document is the consolidated decision matrix (Output 4) plus DMC's explicit anti-goals (Output 5). It names which surveyed primitives become v0.6.1–v0.6.9 candidates and which are rejected; it builds nothing. Full per-primitive detail is in `HARNESS_BENCHMARK_CARDS_2026.md`; the survey rationale is in `HARNESS_LANDSCAPE_2026.md`.

**Decision discipline.** DMC identity takes precedence over ecosystem trends. A `reject` is recorded as carefully as an `adopt`. Every efficiency or performance claim is `unverified` unless a deterministic check is named. No leaked, proprietary, or system-prompt text is reproduced. All Sakana Fugu benchmark numbers are self-reported / independently-unverified.

---

## Output 4 — Adoption decision table

Columns: **Pattern** · **Evidence/source** · **Decision** · **Rationale** · **Risk** · **Future-milestone candidate**. Decision ∈ `adopt | adapt | reject | defer`.

| Pattern | Evidence/source | Decision | Rationale | Risk | Future-milestone candidate |
|---------|-----------------|----------|-----------|------|----------------------------|
| Fablize — capability/procedure boundary | Fablize (pattern-level) | adapt | names DMC's "procedure deterministic, capability swappable" axis; maps to lane logic | becomes an unused abstraction if not tied to existing lanes | v0.6.x (docs) |
| Fablize — multi-criterion verification gate | Fablize (pattern-level) | adapt | = v0.5.5 planner with union/monotonic required checks | criterion sprawl | v0.6.x |
| Fablize — early-stop prevention | Fablize (pattern-level) | adapt | keep outcome, require a *visible bounded gate* not hidden pressure | misread as an auto-loop (anti-goal) | v0.6.x |
| Fablize — systematic investigation protocol | Fablize (pattern-level) | adopt | pure discipline, no hidden behavior; aligns with evidence-first | ceremony on trivial tasks (effort controller mitigates) | v0.6.x (docs) |
| Fablize — per-task discipline router | Fablize (pattern-level) | adapt | already shipped as v0.5.3 selector / v0.5.2 effort controller | router-vs-gate drift (R5) | none (shipped) |
| LazyCodex — evidence-receipt stop hook | LazyCodex (pattern-level) | adopt | mechanical form of "no evidence, no completion claim" | advisory-only hook gives false assurance; keep fail-closed | v0.6.x |
| LazyCodex — executor role contract | LazyCodex (pattern-level) | adopt | = scope-locked `executor` + worker no-mutation rule | role bleed (self-approval) | none (shipped) |
| LazyCodex — read-only reviewer contract | LazyCodex (pattern-level) | adopt | = read-only `critic`/`verifier`; authoring/review separation | reviewer with write access collapses separation | none (shipped) |
| LazyCodex — evidence untrusted until inspected | LazyCodex (pattern-level) | adopt | epistemic core of DMC evidence policy; foil to Fugu's internal trust | low (inspection cost only) | v0.6.x (docs) |
| LazyCodex — test-relevance / anti-slop review | LazyCodex (pattern-level) | adapt | named reviewer criterion against false-green | over-strict relevance rejecting valid tests; keep advisory | v0.6.x |
| OmO — bounded team / hostile critic panel | oh-my-openagent (pattern-level) | adapt | raises confidence on high-risk lanes; "bounded" is the constraint | unbounded cost or approval-laundering quorum (C11) | v0.6.x |
| OmO — lifecycle hooks | oh-my-openagent (pattern-level); DMC INTEROP.md | adapt | how DMC's visible enforcement is wired; document the hook map | hook sprawl / silent behavior change | v0.6.x (docs) |
| OmO — hash-anchored / LSP / AST-grep edit precision | oh-my-openagent (pattern-level) | defer | valuable but an implementation-layer capability outside docs-only scope | premature tool/runtime surface (§2) | defer (v0.6.x impl) |
| OmO — telemetry / auto-update by default | oh-my-openagent (pattern-level) | reject | hidden behavior change + data egress; violates visibility thesis | the risk is in *not* rejecting | none (reject) |
| FableCodex — goal ledger | FableCodex (pattern-level) | adapt | a *visible* ledger is on-thesis; opposite of implicit state | ledger drift from reality; bind to run facts | v0.6.x |
| FableCodex — findings gate | FableCodex (pattern-level) | adapt | natural fail-closed addition to gate-check family | auto-waiver defeats it; waivers must be explicit | v0.6.x |
| FableCodex — coverage accounting | FableCodex (pattern-level) | defer | needs a scope model first; a gameable metric is worse than none | false confidence from "touched ≠ correct" | defer (v0.6.x) |
| Skill ecosystem — registry security & no-blind-install | AGENTS.md/SKILL.md/MCP conventions | adopt | adopt the *posture*: declarative contracts, no blind install | blind install = code-exec/exfiltration risk | v0.6.x (policy) |
| SuperClaude — small command/mode vocabulary | SuperClaude & mode frameworks (pattern-level) | adapt | DMC already exposes a small command set + specialist agents | mode sprawl erodes legibility | v0.6.x |
| SuperClaude — token-efficiency claims | SuperClaude & mode frameworks (pattern-level) | reject | unverifiable efficiency claims taken as fact | over-claiming (R6); mark unverified | none (reject) |
| OpenHands/SWE-agent/Aider — sandbox/runtime isolation + reviewability | public OSS projects (pattern-level) | adapt | maps to v0.4.2 isolation guard + v0.5.6 review packet | importing default network/live access | v0.6.x |
| OpenHands/SWE-agent/Aider — default network/live + opaque action | public OSS projects (pattern-level) | reject | breaches secret floor & no-live-by-default | data egress, unaudited action | none (reject) |
| Prompt-leak — hidden-guardrail meta-lesson | structural meta-lesson only (zero leaked content) | adopt | prefer visible gates over hidden behavior modification | reproducing leaked text; building hidden guardrails | v0.6.x (principle) |
| Fugu — learned model-orchestration as gate authority | sakana.ai/fugu; arXiv 2512.04695 / 2512.04388; Azure patterns | reject | non-deterministic, non-auditable router cannot be the source of truth for gates | irreproducible, un-gatekeepable gates | none (reject as gate authority) |
| Fugu — verification-&-synthesis as orchestrator responsibility | sakana.ai/fugu; Azure patterns | adapt | orchestrator-owned verification is sound; keep it a *separate* deterministic pass | folding verification invisibly into a model | none (shipped) |
| Fugu — recursive self-delegation | sakana.ai/fugu; the Conductor (2512.04388) | defer | reconsider only behind a hard deterministic depth/budget bound | unbounded cost/latency, runaway autonomy | defer (bounded-recursion contract) |
| Fugu — swappable pool / capability-class abstraction | sakana.ai/fugu; the Conductor (2512.04388) | adapt | strongest extractable primitive; pool-agnostic routing *without* a learned router | model-name rot if names leak into logic (R4) | v0.6.x (capability-class lookup) |
| Fugu — single-endpoint OpenAI-compatible facade | sakana.ai/fugu; github.com/SakanaAI/fugu | adapt | ergonomic facade orthogonal to gating | facade hiding routing provenance; log resolved class+provider | v0.6.x (optional) |
| Deterministic control plane (robustness/variability) | arXiv 2605.09894 (narrow claim); Azure AI agent design patterns | adopt | independent support for encoded gates in a structured-validation regime | over-generalizing; refuted stronger claims excluded | none (validates current design) |

**Decision tally:** adopt ×8 · adapt ×14 · reject ×4 · defer ×3 (29 rows over the surveyed patterns). The matrix is dominated by `adapt`/`defer`, consistent with the non-goal that v0.6.0 is a decision matrix, not a build order.

**Excluded (honesty note).** Two stronger claims from arXiv 2605.09894 — that deterministic orchestration reaches general accuracy parity, and that it cuts token cost by a large factor — were adversarially refuted and are **not** relied on. DMC does not claim "determinism is free" or "determinism is cheaper"; only the narrower robustness/variability result in a structured-validation regime is cited.

---

## Output 5 — Explicit anti-goals

DMC will **not** do the following. Each is a standing constraint, not a preference:

1. **No leaked-prompt reproduction.** No copying, storing, quoting, or phrase-length paraphrasing of leaked proprietary or system-prompt text. Structural lessons only, in DMC's own words.
2. **No hidden prompt magic.** Discipline lives in inspectable scripts and docs, never in concealed prompt behavior the user cannot audit.
3. **No auto-unbounded ultrawork.** No open-ended "keep going" loop without a deterministic, bounded gate and a human Release Gate.
4. **No skill-marketplace blind install.** No execution of unsigned/unsandboxed/unread third-party skills; skills (if ever adopted) use declarative contracts.
5. **No live/model call by default.** Mock-first, offline-by-default; every live provider/model/API path is multi-gated and opt-in.
6. **No push/closure automation without a human gate.** Stage, commit, push, merge, and milestone closure require the Human Release Gate; never inferred from a critic/auditor PASS or from run state (C11).
7. **No model-name hardcoding as permanent truth.** Capability classes are the durable unit; model names are illustrative, dated, and isolated to a replaceable lookup.
8. **No opaque learned routing as the source of truth for gates (the Fugu foil).** A learned/adaptive component may suggest, but it is advisory and untrusted-until-inspected; it never opens a gate.
9. **No self-reported benchmark taken as verified.** Vendor performance numbers are tagged self-reported/unverified until independently replicated; they never justify a design decision on their own.
10. **No telemetry / silent auto-update by default.** No background data egress or self-modification the user did not explicitly enable.

**Milestone disclaimer:** this document is **architecture guidance, not enforcement**. It records decisions and constraints; it selects no model, opens no gate, and authorizes no build. The decisions name candidates for v0.6.1–v0.6.9, each of which requires its own approved plan and human gate before any build.
