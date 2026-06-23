# PLAN — v0.6.0 Harness Landscape & Orchestration Taxonomy (DRAFT)

**Type:** research / market / architecture milestone. **NOT an implementation milestone.** No product code, no tools, no
hooks, no provider/live routing. Deliverables are **docs + one read-only structure-check script**. Everything additive;
protected surface untouched; auto-log `.harness/evidence/*.md` stays untracked/excluded.

**Operating thesis (the decision this milestone must justify):** DMC builds a *visible control plane for bounded AI agents*,
not a token-max engine and not a hidden-prompt mimic. One E2E workflow the user can see; an explicit role hierarchy,
permissions, gates, evidence, and rollback in the repo; frontier models may orchestrate and cheaper/specialized models may
implement; **deterministic scripts remain the source of truth for gates; a human remains the Release Gate for irreversible
actions.** v0.6.0 produces the research-backed adoption decision matrix that names which primitives become v0.6.1–v0.6.9
candidates — it does not build them.

---

## 1. Problem statement

DMC has shipped a substantial bounded-agent substrate (v0.1–v0.5): provider access layer, manual import, provider
routing/contracts, gate runners, run manifests, task intake, effort/provider policy, review packet, resume/recovery, and a
dynamic-workflow acceptance capstone. These are individually sound but were built bottom-up. The surrounding 2026 agent-harness
ecosystem (discipline-agent frameworks, multi-role orchestrators, skill/MCP ecosystems, production coding agents) has
converged on patterns DMC has *partially* reinvented and *partially* missed. Without a deliberate landscape audit, DMC risks
(a) re-deriving primitives others have already validated, (b) adopting fashionable-but-dangerous patterns (auto-unbounded
loops, token-max, hidden behavior modification, blind skill installs), and (c) hard-coding today's model names as if they
were permanent truth. **The problem:** decide, with evidence and in DMC's own words, which external harness primitives DMC
should adopt / adapt / reject / defer, and define the orchestration taxonomy (roles, capability classes, delegation matrix)
that the next layer (v0.6.x) will be built against.

## 2. Non-goals

- **Not** implementing any benchmarked mechanism in v0.6.0 (no goal ledger, findings gate, lifecycle hooks, team mode, etc.).
- **Not** installing, running, or invoking LazyCodex / oh-my-openagent / Fablize / FableCodex / SuperClaude / OpenHands /
  SWE-agent / Aider / **Sakana Fugu (no Fugu API call, no live orchestration, no provider-key use)**, or any skill/MCP,
  during this milestone.
- **Not** copying, storing, quoting, or paraphrasing-at-phrase-length any leaked proprietary or system-prompt text. Structural
  lessons only, in DMC's own words.
- **Not** adding hooks, adapters, provider/live routing, or model-name hardcoding.
- **Not** chasing token-max, hidden prompt magic, or prompt-leak mimicry as a strategy.
- **Not** a final commitment to build everything surveyed — the output is a *decision matrix*, and most cards may be `defer`.

## 3. Candidate research design

Desk research only, from publicly available descriptions / open-source repos / the author's own prior DMC artifacts. Every
finding is recorded as a *structural pattern in DMC's own words* + a decision. No mechanism is executed. Each research
category below produces an `adopt / adapt / reject / defer` stance plus the DMC rationale. The categories map 1:1 to sections
in `docs/HARNESS_LANDSCAPE_2026.md`.

- **A. LazyCodex / oh-my-openagent (OmO):** discipline agents; lifecycle hooks; evidence receipts; model-category routing;
  ultrawork / loop behavior. *Adopt-lens:* evidence receipts, read-only reviewer separation, model-category routing.
  *Reject-lens:* auto-unbounded loops, telemetry/auto-update by default.
- **B. Fablize:** capability-vs-procedure separation; verification grounding; multi-story completion; early-stop prevention;
  systematic investigation. *Adopt-lens:* capability/procedure boundary, verification grounding, early-stop prevention.
  *Reject-lens:* any hidden "keep going" pressure that isn't a visible, bounded gate.
- **C. FableCodex:** goal ledger; findings gate; local state; coverage accounting; no-hidden-runtime-claim. *Adopt-lens:*
  goal ledger, findings gate, coverage accounting. *Reject-lens:* implicit state the user can't see.
- **D. SuperClaude & command/mode frameworks:** command taxonomy; specialist agents; modes; MCP integrations;
  token-efficiency claims. *Adopt-lens:* a small, legible command/mode vocabulary; specialist separation. *Reject-lens:*
  unverifiable token-efficiency claims, mode sprawl.
- **E. OpenHands / SWE-agent / Aider-like production agents:** sandboxing; lifecycle control; multi-LLM routing; runtime
  isolation; reviewability. *Adopt-lens:* sandboxing/runtime isolation, reviewability. *Reject-lens:* default network/live
  access, opaque autonomous action.
- **F. Skill ecosystems (AGENTS.md / SKILL.md / MCPs / registries):** skill registry/marketplace; skill security; skill
  selection/retrieval. *Adopt-lens:* declarative skill contracts, retrieval-by-relevance. *Reject-lens:* blind
  marketplace install, unsigned/unsandboxed skills.
- **G. Prompt-leak & hidden-guardrail lessons:** do **not** copy leaked text; summarize only the *structural* lesson; note
  the false-confidence risk of hidden prompts; prefer **visible gates over hidden behavior modification**. This section
  stores zero leaked content — only the meta-lesson that hidden guardrails create unverifiable trust.
- **H. DMC current-state comparison:** map DMC v0.5 against the external-harness categories (A–F and I); list already-covered capabilities, missing capabilities, and
  *dangerous temptations to reject*. This grounds every adoption decision in what DMC already proved.
- **I. Sakana Fugu (learned orchestration-as-a-model):** Sakana AI's Fugu (launched 2026-06-22) — a learned orchestrator
  LLM (grounded in ICLR 2026 papers TRINITY `2512.04695` / the Conductor `2512.04388`) that hides model selection,
  delegation, verification, and synthesis inside one OpenAI-compatible model. *Adopt/adapt-lens:* capability-class /
  swappable-pool routing, orchestrator-owned (but separate, deterministic) verification, single-facade ergonomics.
  *Reject-lens:* **opaque learned routing as the source of truth for gates** (the precise visibility-axis foil to DMC);
  self-reported, independently-unverified benchmark claims taken as fact; unbounded recursive self-delegation. Structural,
  own-words only; **no Fugu API call** (see §2). Pre-critic research note: `.harness/decisions/dmc-v0.6.0-fugu-benchmark-card.md`.

## 4. File-level implementation scope (deliverables — built ONLY after critic PASS + APPROVED)

Accepted additive file scope for the *future* implementation step (none created in this DRAFT step):

| # | File | Contents (spec) |
|---|------|-----------------|
| 1 | `docs/HARNESS_LANDSCAPE_2026.md` | Sections A–I above (I = Sakana Fugu); for each, the structural pattern (own words) + adopt/adapt/reject/defer + rationale + risk. Ends with the **source table** (project · pattern · public source/own-prior-artifact · note that no leaked text is reproduced). |
| 2 | `docs/ORCHESTRATION_TAXONOMY.md` | Taxonomy outputs 1–3 (below): model-role taxonomy, capability-class taxonomy, work-delegation matrix. |
| 3 | `docs/DMC_ADOPTION_DECISIONS.md` | Taxonomy output 4 (adoption decision table across every surveyed harness) + taxonomy output 5 (explicit anti-goals). |
| 4 | `docs/HARNESS_BENCHMARK_CARDS_2026.md` | The ≥23 benchmark cards (§4.1), each in the fixed card schema (§4.2) — incl. Sakana Fugu cards **#19–#23**. The concrete, testable primitive-extraction layer. |
| 5 | `.harness/evidence/dmc-v0.6.0-verify.sh` | Read-only, structure-check-only script with embedded `--self-test`; verifies all the structural assertions in §6. Inert unless flag-invoked; deterministic; env-free `repo_hash`; no network/live/`.env`. |
| 6 | `.harness/verification/dmc-v0.6.0-harness-landscape-taxonomy.md` | Verification report: command, PASS/FAIL counts, assertion→requirement map, and an explicit line that **this milestone is architecture guidance, not enforcement**. |

Plus this plan file (`.harness/plans/dmc-v0.6.0-harness-landscape-taxonomy.md`) — the only file touched in the DRAFT step.

### 4.1 Required benchmark cards (≥23) — for `docs/HARNESS_BENCHMARK_CARDS_2026.md`

Each is a concrete, testable harness *primitive* (not a project summary). The implementation step fills each card per §4.2.

1. **Fablize — capability/procedure boundary**
2. **Fablize — multi-story verification gate**
3. **Fablize — early-stop prevention hook**
4. **Fablize — systematic investigation protocol**
5. **Fablize — per-task discipline router**
6. **LazyCodex — evidence-receipt stop hook**
7. **LazyCodex — executor role contract**
8. **LazyCodex — read-only code-reviewer contract**
9. **LazyCodex — evidence-is-untrusted-until-inspected**
10. **LazyCodex — test-relevance / anti-slop review**
11. **OmO — bounded Team Mode / hostile critic panel**
12. **OmO — lifecycle hooks**
13. **OmO — hash-anchored edit / LSP / AST-grep as a future edit-precision layer**
14. **OmO — telemetry / auto-update as reject-by-default for DMC**
15. **FableCodex — goal ledger**
16. **FableCodex — findings gate**
17. **FableCodex — coverage accounting**
18. **Skill ecosystem — skill-registry security & no-blind-install**
19. **Sakana Fugu — learned model-orchestration / capability-routing** (REJECT as gate source-of-truth; ADAPT capability-class only)
20. **Sakana Fugu — verification-&-synthesis as the orchestrator's responsibility** (ADAPT; keep as a separate deterministic pass)
21. **Sakana Fugu — recursive self-delegation** (DEFER/REJECT-by-default; only behind hard deterministic depth/budget bounds)
22. **Sakana Fugu — swappable model pool / capability-class abstraction** (ADAPT — strongest extractable primitive; reinforces Output 2)
23. **Sakana Fugu — single-endpoint OpenAI-compatible facade** (ADAPT optional; facade must not hide routing from gate logs)

(More cards are allowed; 23 is the floor. Each maps to a DMC-equivalent or an explicit rejection reason. Cards #19–#23 derive
from the pre-critic Fugu research note `.harness/decisions/dmc-v0.6.0-fugu-benchmark-card.md`; **all Fugu benchmark numbers are
recorded as self-reported / independently-unverified** — the 73.7 SWE-Bench Pro figure is provably NOT from the grounding papers.)

### 4.2 Benchmark card schema (every card MUST contain all fields)

- **Source project** (named harness/project)
- **Observed mechanism** (the primitive, in DMC's own words — no leaked/proprietary text)
- **What DMC already has** (the existing v0.1–v0.5 artifact, or "none")
- **Gap in DMC** (precise, or "none")
- **Decision:** `adopt | adapt | reject | defer`
- **Rationale** (why, tied to the operating thesis)
- **Risk** (what could go wrong if adopted/rejected)
- **Verification strategy** (how a future deterministic check would prove it works)
- **Candidate future milestone** (`v0.6.x` / `defer` / `none`)
- **Attestation:** "No leaked prompt body or proprietary text is copied in this card."

### 4.3 Taxonomy outputs (for deliverables 2 & 3)

**Output 1 — Model role taxonomy:** Strategic Orchestrator · Implementer · Critic/Falsifier · Release Auditor · Verifier ·
Human Release Gate. (Each defined by *owns / must-not / outputs*, reusing the v0.5.8 delegation vocabulary.)

**Output 2 — Capability class taxonomy:** `frontier-long-horizon` · `standard-implementation` · `cheap-fast` ·
`adversarial-review` · `deterministic-tool` · `human-only-gate`. Classes are **named by capability, never by a hard-coded model
name** (model names are illustrative + dated, mapped via a separate, replaceable lookup). Card #22 (Fugu's swappable-pool,
pool-agnostic routing) is the real-world existence proof that model-name-free routing is feasible **without** a learned router —
DMC keeps the selection rule a visible deterministic script.

**Output 3 — Work delegation matrix:** rows = task classes {`docs-only`, `additive tool`, `provider adapter`,
`protected-surface change`, `security/secret/live risk`, `release/closure`, `recovery/resume`}; columns = {orchestrator model
class, implementer model class, critic depth, verification depth, required human gates}. The matrix must reduce to DMC's
already-shipped lane logic (v0.5.3 selector / v0.5.5 planner / v0.5.4 state machine) — i.e. it *describes* existing behavior,
not a new enforcement path.

**Output 4 — Adoption decision table:** one row per surveyed harness/project: pattern · evidence/source · `adopt/adapt/reject/defer`
· DMC rationale · risk · future-milestone candidate.

**Output 5 — Explicit anti-goals:** no leaked-prompt reproduction · no hidden prompt magic · no auto-unbounded ultrawork ·
no skill-marketplace blind install · no live/model call by default · no push/closure automation without a human gate · no
model-name hardcoding as permanent truth · **no opaque learned routing as the source of truth for gates (the Fugu foil)** ·
**no self-reported benchmark taken as verified**.

## 5. Safety constraints

- **No product code / protected surface change:** no adapters, `provider-router.py`, `ROUTING.md`, `PROVIDER_CONTRACT.md`,
  schemas, `.claude/hooks/*`, guards, validators, `dmc-glm-smoke`. v0.6.0 touches only `docs/*`, `.harness/plans/*`,
  `.harness/verification/*`, and one additive read-only `.harness/evidence/*.sh`.
- **No leaked/proprietary/system-prompt text** anywhere in any deliverable; structural lessons only, own words; no long
  phrase fragments; every benchmark card carries the no-copy attestation.
- **No secret-shaped strings** in any doc or fixture (no provider-key shapes, no JWTs, no credential URLs, no raw responses).
- **No `.env*` / credential reads. No live provider/model/API call. No network call.**
- **No hooks installed, no live routing added, no model name treated as permanent truth.**
- The verify script is **read-only and structure-check-only**, inert unless `--self-test`/flag-invoked, deterministic,
  env-independent, `repo_hash` env-free (`git status --porcelain | python3 hashlib.sha256`), and proves the real repo is
  byte-unchanged.
- Auto-log `.harness/evidence/*.md` remains untracked/excluded; never staged.

## 6. Verification matrix (`.harness/evidence/dmc-v0.6.0-verify.sh` structure-checks)

Read-only, structure-only. Each row = one assertion the verify script must make.

| ID | Assertion |
|----|-----------|
| V1 | `docs/HARNESS_LANDSCAPE_2026.md`, `docs/ORCHESTRATION_TAXONOMY.md`, `docs/DMC_ADOPTION_DECISIONS.md` all exist |
| V2 | `docs/HARNESS_BENCHMARK_CARDS_2026.md` exists |
| V3 | A **source table** exists in the landscape doc (header + ≥1 row) |
| V4 | An **adoption decision table** exists with the columns pattern/evidence/decision/rationale/risk |
| V5 | The **model-role taxonomy** exists (all six roles named) |
| V6 | The **work-delegation matrix** exists (all seven task classes × the five columns) |
| V7 | **≥23 benchmark cards** exist (count distinct card headers) |
| V8 | **Every card carries a `adopt`/`adapt`/`reject`/`defer` decision** (one per card) |
| V9 | **Every card has a DMC-equivalent line or an explicit rejection reason** (`What DMC already has` / `Gap` populated) |
| V10 | **Every card carries the no-leaked-prompt attestation line** |
| V11 | **Own-words DMC terminology present** (DMC vocabulary markers — lane / gate / evidence / advisory / human-gate — appear) |
| V12 | **No secret-shaped strings** in any deliverable (provider-key, JWT, embedded-credential-URL, and storage-account-key shapes all absent) |
| V13 | **No leaked/proprietary/system-prompt body text** heuristic: no over-long verbatim-looking quoted block flagged by the curated structural check; no "raw response" / pasted-transcript markers |
| V14 | **No `.env*`/credential read, no live/model/API call, no network** in the verify script's own operative source (structural audit) |
| V15 | **No code/protected-surface change** introduced by the milestone (the changed-path set is docs/plan/verification/this-verify-sh only) |
| V16 | **No auto-log `.harness/evidence/*.md` staged** (the only `.harness/evidence/*` artifact is this `.sh`) |
| V17 | The verification report contains the explicit line **"architecture guidance, not enforcement"** |
| V18 | Read-only: real repo byte-unchanged after `--self-test` (deterministic `repo_hash`) |

Note on V13: the verify cannot truly *detect* "leaked" text; it asserts the **absence of pasted-transcript/raw-response
markers and over-long unattributed quote blocks**, and the **presence of the per-card attestation + own-words markers**.
Leak-avoidance is enforced primarily at authoring time by the safety constraints, with V10/V11/V13 as structural backstops.

## 7. Regression risks

- **R1 — accidental leak reproduction.** Mitigation: own-words rule, per-card attestation, V10/V13 structural backstops,
  authoring discipline; the docs describe *mechanisms*, never quote prompt bodies.
- **R2 — secret-shaped fixture creep** (a "card" embedding an illustrative key shape). Mitigation: V12 + the standing DMC
  secret-protection rule; use clearly-non-secret placeholders only.
- **R3 — scope creep into implementation.** Mitigation: §2 non-goals; this milestone ships only docs + one read-only
  structure check; every card decision is `adopt/adapt/reject/defer`, not "build now".
- **R4 — model-name rot.** Mitigation: capability classes are the durable unit; specific model names are illustrative/dated
  and isolated to a replaceable lookup; V11 checks capability-vocabulary, not model strings.
- **R5 — taxonomy drifting from shipped behavior.** Mitigation: Output 3 must *reduce to* the v0.5.3/0.5.4/0.5.5 lane logic;
  the delegation matrix is descriptive of existing gates, not a new enforcement surface.
- **R6 — over-claiming token-efficiency / "hidden runtime" benefits** from surveyed projects. Mitigation: every efficiency
  claim is marked `unverified` unless a deterministic check is named; anti-goal #2 (no hidden prompt magic) is explicit.

## 8. Rollback plan

- The DRAFT step touches exactly one new file (`.harness/plans/dmc-v0.6.0-harness-landscape-taxonomy.md`); rollback = delete
  the untracked plan file (no commit, no push).
- The implementation step (post-approval) is additive docs + one read-only script on a feature branch; rollback = drop the
  branch / `git checkout -- <files>` before commit, or revert the single additive commit after. No protected surface, no
  history rewrite, no force; nothing is irreversible. The review packet (v0.5.6) and resume controller (v0.5.7) apply.
- Because v0.6.0 changes no runtime behavior (docs + inert script), there is no operational rollback surface beyond file
  removal.

## 9. Approval Status: **APPROVED — build deferred**

**Revision 2 (2026-06-23):** folded in **Sakana Fugu** — added research category **I**, benchmark cards **#19–#23**, the
Output-2 existence-proof note, two Output-5 anti-goals ("no opaque learned routing as gate authority," "no self-reported
benchmark taken as verified"), and raised the card floor **≥18 → ≥23** (deliverable §4 row 4, §4.1 heading + floor note, and V7 updated). Source: pre-critic
research note `.harness/decisions/dmc-v0.6.0-fugu-benchmark-card.md`. This revision **resets the gate** — the plan returns to
`/dmc-critic` before any build.

**Critic re-pass (2026-06-23):** the `critic` agent returned **APPROVE** — 0 blocking findings (internal consistency,
scope-non-creep, schema completeness, claim honesty, leak/secret safety, thesis fit, and no-regression all PASS); 2 cosmetic
nits applied (category-H comparison range A–F→"A–F and I"; revision-note audit trail).

**Approval (2026-06-23, human Release Gate per C11):** the human explicitly authorized **DRAFT → APPROVED** — approval is
**never** inferred from a critic PASS alone. **Build is deliberately deferred to a separate, focused session.**

Next action (when the build session begins): `/dmc-start-work` builds the §4 deliverables (4 docs + the read-only
`.harness/evidence/dmc-v0.6.0-verify.sh` + the verification report) under the accepted additive scope, then verify (V1–V18)
→ evidence → commit. **No push / no closure without further human gates.**
