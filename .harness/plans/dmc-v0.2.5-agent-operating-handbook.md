# Do-Me-Coding v0.2.5 — Agent Operating Handbook

## Goal

Tighten DMC's operating routine so agent workflows optimize for **end-to-end (E2E) problem completion**, not token
maximization. Capture the de-facto milestone loop that produced v0.2.1–v0.2.4 as a written, source-of-truth handbook
plus a concise agent handoff, and add a structure-check that keeps those docs honest. **Docs/process only** — no
product code, no adapter/router/schema/guard/hook change.

## User Intent

process / documentation (formalize role boundaries, gated actions, fail-closed rules, and the anti-token-max routine)

## 1. Problem statement

- DMC has a working but **unwritten** operating loop: DRAFT plan → critic → APPROVED → start-work → verification →
  staging review → commit review → push review → milestone closure. It produced v0.2.2 (`963f25a`), v0.2.3
  (`6fe3015`), and v0.2.4 (`6f2ae4d`), but the routine lives only in conversation memory, not in the repo.
- Without a source-of-truth handbook, an agent (or a new session) can drift: skip a gate, conflate roles (author and
  approve in the same pass), expand scope because more tools/context are available ("token-max"), or take a gated
  action (commit/push/live-call) without the explicit human gate.
- The discipline that DID work — role separation, explicit tool/scope boundaries, state-machine gating, fail-closed on
  ambiguity, and reusable prompt templates — is **structural** and worth writing down as general engineering practice.
  (Structural lessons only; no proprietary/leaked system-prompt text is copied — see §5.)
- Net: we need (a) an **Operator Handbook** that defines roles, autonomy vs. gates, fail-closed rules, the anti-token-
  max rule, and reusable prompt templates; (b) an **Agent Handoff** quick-card for resuming mid-loop; (c) a
  structure-check so the docs can't silently rot.

## 2. Non-goals

- Changing any product code: adapters (`glm-api`, `oauth-cli`), `provider-router.py`, `ROUTING.md`, schemas, hooks,
  validators, guards, `dmc-glm-smoke`. This milestone is docs + a docs-structure check only.
- Adding new enforcement hooks or automating the gates — the handbook **documents** the human-gated loop; it does not
  build new automation. **Enforcement automation (gate-checking hooks/tools, an approval-state machine, a compliance
  linter) is explicitly out of scope for v0.2.5 and would require a separate approved future milestone.** v0.2.5 changes
  who-knows-the-rules, not what-blocks-violations: the rules bind by **agreement and review**, not by tooling, and a
  passing structure-check proves the rules are documented/leak-free, NOT that future agents will comply.
- Copying any leaked/proprietary or third-party system-prompt text verbatim. Only structural lessons are extracted.
- Vendor/competitor tracking as content (e.g. LazyCodex v4.12.1 marketplace-sync is noted only as background context,
  not reproduced).
- Multi-worker orchestration (v0.3); live provider behavior; any credential handling.

## 3. Candidate design

### 3.0 Nature of the handbook (R1 — contract, not enforcement)
- The handbook is an **operating contract, NOT an enforcement mechanism.** It binds agent behavior by **agreement and
  review discipline**, not by tooling. No hook, validator, or script in v0.2.5 forces compliance.
- The v0.2.5 verification (H1–H12) validates only **section presence, structure, and safety hygiene** (own-words
  authorship, no secret shapes, protected-file non-mutation). **A structure-check cannot prove future agent
  compliance.** Passing `dmc-v0.2.5-verify.sh` means the rules are **documented and leak-free** — NOT that future
  agents will obey them.
- **Enforcement automation** (a gate-checking hook, an approval-state machine, a compliance linter, etc.) is
  **explicitly out of scope for v0.2.5** and would require a **separate approved future milestone**.
- Consequently the **anti-token-max rule** (and every other rule here) is a **behavioral norm for DMC operators**, not
  a tool-enforced constraint in v0.2.5 — it is honored by discipline and surfaced in review, not blocked by code.

### 3.1 `docs/DMC_OPERATOR_HANDBOOK.md` (source of truth)
- The handbook opens by stating its own nature per §3.0: **operating contract, not enforcement; presence ≠ compliance.**
- **"E2E done" definition:** a problem is DONE only when it is **verified** (harness/report PASS), **reviewed**
  (critic PASS where applicable; staged-set + protected-file review), **committed** (exact message, clean boundary),
  **pushed** (HEAD == origin/main), and **closure-recorded** (a `docs/MILESTONES.md` entry). Anything short of all five
  is "in progress," not done.
- **Role boundaries (separation of duties):**
  | Role | Owns | Must NOT |
  |---|---|---|
  | **Orchestrator** | reads intent, picks the smallest workflow, sequences gates, routes work, reports status | implement in the same pass it approves; flip approval; commit/push |
  | **Implementer** | drafts plans; under an APPROVED plan, edits only in-scope files; runs mock verification; writes evidence/reports | approve its own plan; touch protected files; commit/push; make live calls |
  | **Critic** | reviews plans/results adversarially; empirically verifies load-bearing claims; returns PASS/REVISE | edit code; approve; implement fixes it recommends (separate pass) |
  | **Release Gate** | the human (대표님) — flips approval, authorizes staging/commit/push/live-call | be assumed; an agent never self-grants a gate |
- **Allowed autonomy (no human gate needed):** plan drafting; critic passes and revision cycles; implementation
  **strictly within an APPROVED file scope**; **mock/offline** verification; evidence/verification-report generation;
  read-only inspection.
- **Gated actions (require an explicit human gate each time):** flipping `Approval Status` to APPROVED; `git add`/
  staging; `git commit`; `git push`; any **live provider call**; any credential-touching behavior; any
  schema/guard/hook/validator/adapter/router change; **(O1) force operations / history rewrite** (`git push --force`,
  `rebase` rewrites, destructive `reset`); **(O1) external publish/send** — any action that sends repo content to a
  third party (remote service, API, message, upload).
- **Fail-closed rules — STOP and report (do not proceed/guess) when:** scope is ambiguous; a protected-file diff is
  detected; a credential/secret/token exposure risk appears; a live-call risk appears without an explicit gate; or any
  verification check FAILs. (Mirrors the existing hooks' fail-closed posture; the handbook makes it a behavioral rule
  even where tooling can't reach.)
- **Anti-token-max rule:** choose the **smallest workflow that closes the problem E2E**. Do not expand scope, add
  files, add abstractions, or invoke more tools/agents merely because more context/tools/budget are available. More
  output ≠ more value; the metric is *problem closed with the least change that is verifiably correct.*
- **Reusable prompt templates** (parameterized skeletons, authored in the handbook — NOT proprietary text): `critic`,
  `start-work`, `staging-review`, `commit-review`, `push-review`, `milestone-closure`. Each template states its inputs,
  the gate it serves, the fail-closed conditions, and the exact outputs to print (e.g. commit-review prints
  `--cached --name-only/--stat/--check` + excluded-file guard before the exact-message commit).

### 3.2 `docs/DMC_AGENT_HANDOFF.md` (quick-card)
- A one-page state-machine card: the loop states (DRAFT → CRITIC → APPROVED → START-WORK → VERIFY → STAGE → COMMIT →
  PUSH → CLOSURE), what each state's entry/exit criteria are, which are gated, and "how to resume mid-loop" (read
  `current-run.md`, re-confirm approval, re-run the verify harness, never assume a prior gate).
- The fail-closed checklist and the anti-token-max rule in <1 screen, so a fresh session can pick up safely.
- **Resume safety rule (O3):** on resume, **re-confirm the current gate was actually granted by the human** before
  taking any gated action. **Never infer a gate** from run-state, a previous message, or partially-completed work — an
  in-progress run is not consent to commit/push/flip-approval/live-call.

### 3.3 `.harness/evidence/dmc-v0.2.5-verify.sh` (docs structure-check, mock/offline)
- Asserts the handbook/handoff **exist** and **contain the required structural sections** (E2E-done definition; the
  four roles; allowed-autonomy list; gated-actions list; fail-closed rules; anti-token-max rule; the six prompt-
  template headings). Pure text/structure checks — no code execution, no live call.
- Asserts **own-words authorship (R2)** — a **positive** check that the docs use DMC-specific terminology and headings
  (e.g. `Release Gate`, `anti-token-max`, `E2E done`, `DMC milestone loop`, `fail-closed`, `Orchestrator`,
  `Implementer`, `Critic`). Their presence is evidence the handbook was authored in DMC's own words, not pasted.
- **H9 stores ZERO reproduced proprietary prose.** Beyond the positive check, it uses only a **minimal generic
  denylist of public proper-nouns / obvious meta-labels** (e.g. competitor/product names, blatant "system prompt"
  contamination markers) — it **must NOT contain** reproduced leaked system-prompt body text, distinctive leaked
  instructions, or long phrase fragments. H9 checks **own-words authorship + obvious contamination markers only**.
- Asserts **no secret/token shapes** in the docs (H10, a separate scan).
- Asserts protected files byte-unchanged after the run.

### 3.4 `.harness/verification/dmc-v0.2.5-agent-operating-handbook.md`
- The verification report (PASS/FAIL of the structure-check + manual review notes). It **must state explicitly (R1)**
  that a PASS means *"the operating contract is documented, structurally complete, own-words authored, and leak/secret
  free"* — and that it **does NOT certify future agent compliance**, which is unprovable by a structure-check and is
  deferred to a separate approved enforcement milestone.

## 4. File-level implementation scope

| Path | Change | Edit? |
|---|---|---|
| `docs/DMC_OPERATOR_HANDBOOK.md` | NEW — roles, autonomy/gates, fail-closed, anti-token-max, prompt templates, E2E-done | yes (new) |
| `docs/DMC_AGENT_HANDOFF.md` | NEW — one-page state-machine + resume quick-card | yes (new) |
| `.harness/evidence/dmc-v0.2.5-verify.sh` | NEW — docs structure-check (mock/offline; no code exec, no live call) | yes (new) |
| `.harness/verification/dmc-v0.2.5-agent-operating-handbook.md` | NEW — verification report | yes (new) |
| `docs/MILESTONES.md` | append a v0.2.5 entry — additive doc (separate `docs(dmc):` step, like prior closures) | yes (if/when closing) |
| adapters / `provider-router.py` / `ROUTING.md` / `WORKER_*_SCHEMA.md` / `.claude/hooks/*` / `dmc-glm-smoke` | **NO change** | no |

## 5. Safety constraints

- **Docs/process only** — no product code touched; the verify harness only reads/greps docs (no code execution, no
  adapter/router invocation, no live call).
- **No leaked/proprietary text** — only structural lessons (role separation, explicit tool/scope boundaries,
  state-machine discipline, fail-closed behavior, source-of-truth docs) are expressed in DMC's own words; the
  structure-check includes a verbatim-leak denylist guard.
- **No `.env*` / credential reads**; the docs contain no secrets; the structure-check scans for and forbids secret/token
  shapes in the docs.
- **No live provider call** anywhere in the plan or the structure-check.
- **Gates remain human-owned** — the handbook codifies that an agent never self-grants approval/staging/commit/push/
  live-call; writing the handbook does not change who holds the gates.
- **Protected-file non-mutation** — `git diff` over adapters/router/schemas/hooks/`dmc-glm-smoke` must be empty.
- **Auto-logged evidence** (`.harness/evidence/dmc-v0.2.5-*` if any auto-log appears) stays untracked/excluded at
  staging, consistent with prior milestones. The three pre-existing auto-logged evidence files also remain
  **untracked/excluded** (O2): `.harness/evidence/dmc-v0.2.2-oauth-cli-adapter.md`,
  `.harness/evidence/dmc-v0.2.3-provider-routing.md`, `.harness/evidence/dmc-v0.2.4-provider-contract-tests.md`.

## 6. Verification matrix (docs structure-check; mock/offline only)

**Preamble (R1):** H1–H12 validate **section presence, structure, and safety hygiene ONLY**. They **cannot prove
future agent compliance** — a passing run means the rules are **documented and leak-free**, not that any agent will
obey them. Enforcement is a separate approved future milestone (§2, §3.0). The check executes **no code** and touches
**no live path** (H12).

| # | Check | Assertion |
|---|---|---|
| H1 | Handbook exists + E2E-done defined | `DMC_OPERATOR_HANDBOOK.md` present; contains the 5-part "E2E done" (verified/reviewed/committed/pushed/closure-recorded) |
| H2 | Four roles defined | Orchestrator, Implementer, Critic, Release Gate each present with owns/must-not boundaries |
| H3 | Allowed-autonomy list present | plan drafting, critic revision, approved-scope implementation, mock verification, report generation |
| H4 | Gated-actions list present | approval flip, staging, commit, push, live call, credential behavior, schema/guard/hook change |
| H5 | Fail-closed rules present | scope ambiguity, protected-file diff, credential-exposure risk, live-call risk, verification failure → STOP+report |
| H6 | Anti-token-max rule present | "smallest workflow that closes E2E; do not expand scope for available context/tools" |
| H7 | Six prompt templates present | critic, start-work, staging-review, commit-review, push-review, milestone-closure headings exist |
| H8 | Handoff quick-card exists | `DMC_AGENT_HANDOFF.md` present; state-machine + resume + fail-closed checklist |
| H9 | Own-words authorship + no contamination (R2) | **Positive:** DMC-specific terms/headings present (`Release Gate`, `anti-token-max`, `E2E done`, `DMC milestone loop`, `fail-closed`, `Orchestrator`, `Implementer`, `Critic`). **Negative:** only a minimal generic proper-noun / meta-label denylist — **stores ZERO reproduced proprietary prose**; no leaked body text, no distinctive leaked instructions, no long phrase fragments |
| H10 | No secret/token shapes in docs | `SECRET_VALUE` + OAuth/JWT/Bearer scan over both docs → none |
| H11 | Protected-file non-mutation | `git diff --name-only` over adapters/router/schemas/hooks/`dmc-glm-smoke` → empty |
| H12 | No live call / no code exec in the check | the harness only reads/greps docs; runs no adapter, makes no network/live call |

## 7. Regression risks

| Risk | Severity | Mitigation |
|---|---|---|
| Handbook drifts from actual practice / rots | med | H1–H8 structure-check keeps required sections present; closure step re-runs the check. |
| Verbatim proprietary/leaked text slips in | high | §5 structural-lessons-only rule + **H9 redesigned (R2): positive own-words check + minimal generic proper-noun denylist that stores ZERO reproduced proprietary prose**; author in DMC's own words. |
| **False confidence: "structure-check passed" misread as "agents will comply"** | high | **R1: handbook is a contract not enforcement; H1–H12 prove presence/structure/hygiene, NOT compliance; §3.0/§6-preamble/§3.4/§2 state this explicitly; enforcement deferred to a separate approved milestone.** |
| Docs imply new automation/enforcement exists | med | §2 non-goal: handbook documents the human-gated loop; it builds no automation; wording says "rule," not "enforced by tool." |
| A secret/example token pasted into a template | high | H10 secret-shape scan over docs; templates use placeholders only. |
| Structure-check accidentally executes code / makes a call | med | H12: read/grep only; no adapter invocation, no `--live`, no network. |
| Scope creep into hooks to "enforce" the handbook | low | §2/§4 mark hooks/code `no change`; H11 asserts byte-unchanged. |

## 8. Rollback plan

- **Pre-commit:** `git restore` / remove the new docs + structure-check + report; nothing else touched (no product
  code) → nothing else to undo.
- **Post-commit:** `git revert <v0.2.5-commit-sha>` — additive docs/check only; adapters/router/guards/schemas
  untouched → clean revert; the operating loop continues to function exactly as before (the handbook only described it).

## 9. Approval Status

Status: APPROVED
Approver: 대표님
Approved At: 2026-06-21
