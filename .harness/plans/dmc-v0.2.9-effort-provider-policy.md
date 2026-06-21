# Do-Me-Coding v0.2.9 — Effort & Provider Policy

## Goal

Write DMC's **model / provider / effort selection policy** so work uses the **smallest sufficient reasoning path**
instead of token maximization: when a fast/simple model suffices, when Opus-class implementation is warranted, when to
invoke Codex release audit, when a separate critic pass is required, when to escalate to a human, and when to **stop**
rather than spend more tokens — plus a task-class → workflow mapping. **Policy/doc only:** it is **guidance (a behavioral
norm), not enforcement**, and changes **no** actual provider-routing behavior, code, or `provider-router.py`. A
read-only structure-check proves the policy is documented, complete, and clean — it does **not** prove compliance.

## User Intent

process / documentation (codify effort/model/provider selection as a behavioral norm) — additive, doc + structure-check.

## 1. Problem statement

- The DMC roadmap's overriding rule is "optimize for E2E completion, not token maximization; smallest workflow that
  closes the milestone safely." But there is no written policy mapping a **task class** → the **effort/model/provider**
  it warrants, nor when to invoke Codex, when a separate critic pass is mandatory, when to escalate, or when to stop.
- Without it, an operator can over-spend (run a deep panel + Opus on a trivial docs edit) or under-spend (skip the
  separate critic / Codex audit on a schema change). v0.2.8 produced a *task-intake classifier* (dimensions + gates);
  v0.2.9 adds the *effort/provider policy* that consumes those classes to **recommend** (not select) the minimal safe
  reasoning path — the human/loop still decides.
- It must be **guidance, not enforcement** (consistent with the handbook): the policy binds by agreement and review,
  not tooling; it changes no routing behavior. Enforcement (auto-selecting a model/provider from the policy) is a
  separate, separately-approved future milestone.

## 2. Non-goals

- **No provider-routing behavior change.** No edit to `provider-router.py`, `ROUTING.md`, adapters, schemas, hooks,
  validators, guards, `dmc-glm-smoke`, or product code. The policy is a doc; it routes nothing.
- **No model-API integration / no LLM call / no live provider call / no network / no `.env*`/credential read.** The
  structure-check is pure read/grep over docs.
- No enforcement automation (a policy-driven auto-router/linter) — separate approved future milestone.
- Not a substitute for the critic, Codex audit, or human gate — it is an *input* that recommends the minimal path; the
  gates remain authoritative.
- No leaked/proprietary/system-prompt text — only structural guidance in DMC's own words.

## 3. Candidate design

### 3.1 `docs/DMC_EFFORT_PROVIDER_POLICY.md` (the policy)
Sections (the required policy content):
- **Nature:** guidance / behavioral norm, **not enforcement**; presence ≠ compliance; enforcement is a future milestone.
- **When a fast/simple model suffices:** low-risk, mechanical, well-specified, docs-only/test-only drafting; reversible;
  no protected surface.
- **When Opus-class implementation is warranted:** protected-surface (adapter/router/schema/guard/hook), safety-critical,
  ambiguous, multi-step, or fail-closed-sensitive work.
- **When to invoke Codex release audit:** **always before a stage/commit/push decision**; mandatory for every milestone.
  (Codex is an **independent advisory audit input feeding the human Release Gate** — NOT itself one of the handbook's
  nine human gates; an agent never treats a Codex ACCEPT as a granted gate.)
- **When a separate critic pass is required:** **always** (separation of duties — author never approves own work); a
  multi-perspective adversarial **panel** for high-risk/ambiguous/protected-surface or under ultracode.
- **When to escalate to a human:** any hard gate (push/live/credential/schema-guard-hook/force/external), any fail-closed
  trigger (scope ambiguity, protected-file diff, credential/live risk, verification FAIL), or task-intake
  `stop_and_ask=true`.
- **When to STOP instead of spending more tokens:** the problem is closed E2E (verified·reviewed·committed·pushed·
  closure-recorded); OR review has converged (diminishing-returns / no new substantive finding); OR blocked on a human
  gate. Token cost is not a goal — "problem closed with the least change that is verifiably correct."
- **Task-class → workflow mapping** (consumes v0.2.8 dimensions + the handbook gate map): one row per class
  {docs-only, test-only, adapter, router, schema/guard, live/credential, release} → {model/effort, plan depth, critic
  (single vs panel), Codex audit (always), required human gates, stop_and_ask}. **Per-row values stay consistent with
  v0.2.8/the handbook:** adapter/router → standard depth + gate #7; schema/guard → deep + gate #7; the live/credential
  row splits its sub-cases (live → gate #5, credential → gate #6) explicitly.
- **Ultracode interaction:** under ultracode, raise *verification/critic depth* (panels, adversarial verify) but keep
  *implementation scope minimal* and all gates intact — depth not scope.

### 3.2 `.harness/evidence/dmc-v0.2.9-effort-provider-policy.sh` (structure-check)
- Read/grep ONLY over `docs/DMC_EFFORT_PROVIDER_POLICY.md`: asserts the required sections exist (the policy areas +
  the 7-class mapping), the **guidance-not-enforcement** statement is present, **own-words authorship** (positive
  DMC-term check), **no secret/token shapes**, and **no leaked/proprietary contamination markers** (generic-only
  denylist, stores zero leaked prose). Asserts protected files byte-unchanged.
- **"No code execution" — precise scope (consistent with v0.2.5):** the check **does NOT execute the product/router/
  adapter under test** and makes **no live / network / model-API call**. It MAY use the benign read-only utilities the
  prior verifiers already use — `grep`, `git diff` (read-only), and `python3 -c` for an in-memory regex scan of the doc
  string (exactly as v0.2.5 H10 / v0.2.8 do). The H5 self-audit denylist forbids the **dangerous classes ONLY** —
  literal needles `--live`, `urllib`/`requests`/`http(s)`, `curl`/`wget`, an `adapter`/`router` `.py` *invocation*, and
  an `.env` *open* — and explicitly NOT the benign `python3`/`grep`/`git` the check relies on. Needles are concatenated
  so the self-audit line never self-matches.
- **Meta-guards (prevent a future no-op gut):** the H5 dangerous-needle denylist and the H2 contamination denylist are
  each asserted **non-empty and concatenation-built**, so a passing run cannot be achieved by silently emptying them.

### 3.3 `.harness/verification/dmc-v0.2.9-effort-provider-policy.md` (report)
- Records the structure-check results and states explicitly that a PASS means the policy is **documented/complete/clean
  and own-words**, NOT that any agent will comply — compliance is unprovable by a structure-check; enforcement is a
  separate future milestone.

## 4. File-level implementation scope

| Path | Change | Edit? |
|---|---|---|
| `docs/DMC_EFFORT_PROVIDER_POLICY.md` | NEW — the policy (guidance, not enforcement) | yes (new) |
| `.harness/evidence/dmc-v0.2.9-effort-provider-policy.sh` | NEW — read-only structure-check | yes (new) |
| `.harness/verification/dmc-v0.2.9-effort-provider-policy.md` | NEW — report | yes (new) |
| `provider-router.py` / `ROUTING.md` / adapters / `WORKER_*_SCHEMA.md` / `.claude/hooks/*` / `dmc-glm-smoke` / product code | **NO change** | no |

## 5. Safety constraints

- **Doc/policy + structure-check only** — no provider-routing behavior change; the structure-check **executes no
  product/router/adapter code** and makes **no model-API/network/live call** and reads **no `.env*`/credentials** (it
  uses only read-only `grep`/`git diff`/`python3 -c` regex over the doc, per the v0.2.5/v0.2.8 precedent).
- **Guidance, not enforcement** — the policy binds by agreement/review, not tooling; it changes no routing. Enforcement
  is a separate approved future milestone. The structure-check proves presence/structure/hygiene, **not compliance**.
- **No leaked/proprietary text** — own-words only; structure-check guards via a positive own-words check + a minimal
  generic contamination denylist that **stores zero leaked prose**; no secret/token shapes in the doc.
- **No protected-surface change** — `git diff` over adapters/router/schemas/hooks/guards/`dmc-glm-smoke` empty.
- **Auto-logged evidence excluded** — `.harness/evidence/dmc-v0.2.9-*` auto-log stays untracked/excluded, with the
  prior excluded files.

## 6. Verification matrix (structure-check; read/grep only, no model API / no live)

| # | Check | Assertion |
|---|---|---|
| P1 | policy doc exists + nature stated | `DMC_EFFORT_PROVIDER_POLICY.md` present; "guidance, not enforcement" + "presence ≠ compliance" present |
| P2 | fast-model criteria present | low-risk/mechanical/docs-test → fast model |
| P3 | Opus-class criteria present | protected-surface/safety-critical/ambiguous → Opus |
| P4 | Codex audit policy present | "always before a stage/commit/push decision" |
| P5 | separate-critic policy present | "always (separation of duties)" + panel for high-risk/ultracode |
| P6 | escalate-to-human policy present | hard gates + fail-closed triggers + stop_and_ask |
| P7 | when-to-stop policy present | E2E-done OR converged OR blocked; token cost not a goal |
| P8 | task-class → workflow mapping present | rows for docs/test/adapter/router/schema-guard/live-credential/release |
| P9 | ultracode interaction present | depth not scope; gates intact |
| H1 | own-words authorship (positive) | DMC-specific terms present (Release Gate, anti-token-max, fail-closed, E2E done, Codex, …) |
| H2 | no leaked/verbatim prose | minimal generic contamination denylist → none; **stores zero reproduced leaked prose** |
| H3 | no secret/token shapes in doc | `SECRET_VALUE` + OAuth/JWT/Bearer scan → none |
| H4 | protected files byte-unchanged | `git diff --name-only` over adapters/router/schemas/hooks/`dmc-glm-smoke` → empty |
| H5 | check is read-only / no dangerous exec / no live | self-audit (concatenated needles): no `--live`/`urllib`/`requests`/`http(s)`/`curl`/`wget`/adapter·router `.py` invocation/`.env` open in the check — benign `python3 -c`/`grep`/`git diff` permitted (it executes no product/router/adapter code, no model-API/network/live call) |
| H6 | self-audit not gutted (meta-guard) | the H5 dangerous-needle denylist AND the H2 contamination denylist are each non-empty and concatenation-built (a passing run can't be reached by emptying them) |

## 7. Regression risks

| Risk | Severity | Mitigation |
|---|---|---|
| Policy mistaken for enforcement / auto-routing | high | §2/§5 + P1: guidance-not-enforcement, presence≠compliance; changes no routing; enforcement deferred to a separate milestone. |
| Doc implies a live/model-API integration | med | §2/§5 + H5: no model-API/network/live; structure-check is read/grep only. |
| Leaked/proprietary text slips in | high | H1 positive own-words + H2 minimal generic denylist storing zero leaked prose; authored in DMC's own words. |
| Scope creep into provider-router/code | low | §2/§4 mark code/router `no change`; H4 byte-unchanged. |
| Policy drifts from the v0.2.8 classes / handbook gates | med | Task-class mapping references the v0.2.8 dimensions + handbook gate map; P8 asserts the 7 classes present. |

## 8. Rollback plan

- **Pre-commit:** `git restore` / remove the new files (policy, structure-check, report). No code/router touched.
- **Post-commit:** `git revert <v0.2.9-commit-sha>` — additive doc + read-only script; adapters/router/guards/schemas
  untouched → clean revert; routing behavior identical (the policy only described intent).

## 9. Approval Status

Status: APPROVED
Approver: 대표님 (delegated semi-autonomous mode — flipped after critic panel PASS)
Approved At: 2026-06-21
