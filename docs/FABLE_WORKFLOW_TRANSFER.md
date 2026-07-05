# FABLE_WORKFLOW_TRANSFER — Observable Long-Horizon Engineering Behaviors as Runtime Primitives

Status: v1.0 design input (Phase 1 of the dmc-v1-runtime-upgrade session).
Scope discipline: this document records **externally observable working patterns** of a strong
frontier coding agent operating long-horizon tasks. It contains no model internals, no hidden
reasoning, no proprietary prompt text (DMC.md Rule 7). Every behavior is stated as an
input→action→artifact contract that **any** strong model (Claude, Codex/GPT, Gemini, OpenCode,
future models) can be held to by a deterministic runtime. The claim is never "the model is smart";
the claim is always: **"this observable behavior can be enforced by this runtime primitive."**

Primitive names (P-numbers) refer to `docs/DMC_V1_RUNTIME_ARCHITECTURE.md`.

Format per behavior:
**Trigger · Input · Runtime state required · Action · Output artifact · Verification · Failure
mode · Recovery · Exit condition · → Enforcing primitive.**

---

## B1. Orientation before opinion (unfamiliar-repo entry)

Observable pattern: before proposing any change, the agent enumerates the tree, reads the operating
docs (README/CLAUDE.md/AGENTS.md equivalents), identifies the build/test entry points, and states
what it found *with paths* before stating what it will do.

- **Trigger:** task start in a repo with no fresh orientation artifact.
- **Input:** repo tree, top-level docs, manifests (package.json/pyproject/Makefile/CI config).
- **Runtime state required:** none (this creates the first state).
- **Action:** bounded scan (file listing, manifest parse, doc headers) — no product-file edits.
- **Output artifact:** a machine-readable orientation map (`.harness/repo/orientation.json`):
  languages, package managers, verify commands, entry points, doc roots, freshness stamp
  (HEAD commit).
- **Verification:** every path in the map exists; verify commands are syntactically runnable;
  map freshness == current HEAD or explicitly stale-flagged.
- **Failure mode:** speculation — describing files that don't exist, or reusing a stale map after
  history moved (DMC's own `AGENTS.md:8-9` names a branch that no longer exists — the exact
  failure).
- **Recovery:** invalidate map on HEAD mismatch; re-scan; never patch a stale map by memory.
- **Exit condition:** orientation map exists, fresh, and cited by the plan.
- **→ Enforced by P1 Repository Orientation Primitive** (planning gate refuses a plan whose
  Current Repo Findings cite no fresh orientation map).

## B2. Landmark identification (what must not break)

Observable pattern: the agent distinguishes load-bearing surfaces (schemas, routers, guards, public
APIs, migration dirs) from ordinary code, and treats the former with an explicit "authorized edit
or hands off" posture.

- **Trigger:** orientation complete; before scope selection.
- **Input:** orientation map + heuristics (config/schema/security/CI paths, export surfaces) +
  host-declared protected paths.
- **Runtime state required:** orientation map.
- **Action:** classify paths into landmark classes (enforcement, contract, release, data,
  ordinary).
- **Output artifact:** `.harness/repo/landmarks.json` — the single generated source that replaces
  today's ~6 hand-maintained protected-path lists (`docs/DMC_GATE_CHECKS.md:50` etc.).
- **Verification:** deterministic re-run reproduces the map byte-identically at the same HEAD;
  negative control: a seeded fake landmark must be detected.
- **Failure mode:** landmark drift — lists maintained by hand in prose diverge from the tree
  (already happened: `dmc-glm-smoke` frozen into protected lists; manifest drift §3/§5 of the
  audit).
- **Recovery:** regenerate on HEAD change; diff old→new landmark sets and surface removals loudly.
- **Exit condition:** landmarks.json fresh; scope proposals are checked against it.
- **→ Enforced by P2 Architecture Landmark Scanner** feeding P7 Scope Lock and P5 Change Radius.

## B3. Pattern inference before invention

Observable pattern: before writing new code, the agent finds 2–3 existing analogues in the repo
(how errors are wrapped, how tests are named, how adapters are registered) and imitates them,
citing the exemplar paths, rather than importing an outside idiom.

- **Trigger:** plan proposes a new file or new construct.
- **Input:** landmark map + targeted searches for the construct class.
- **Runtime state required:** orientation map.
- **Action:** record exemplar paths per proposed construct.
- **Output artifact:** "Pattern exemplars" table in the plan (exemplar path → convention followed).
- **Verification:** exemplar paths exist; critic checks the diff against the cited convention.
- **Failure mode:** convention fork — a second way of doing X enters the repo (DMC example: three
  competing lifecycle definitions, audit §5).
- **Recovery:** critic REJECT with the exemplar cited; rewrite to match or explicitly justify a
  new convention in the plan.
- **Exit condition:** every new construct in the diff has an exemplar or an approved exception.
- **→ Enforced by P3 Existing Pattern Extractor** + P16 Critic Gate (exemplar table is a required
  plan section).

## B4. Minimal scope, declared before edit

Observable pattern: the agent names the exact files it intends to touch *before* touching them,
keeps the list small, and treats scope growth as an event requiring re-approval — not something
that silently happens.

- **Trigger:** plan approval.
- **Input:** plan Relevant Files table; landmarks.json.
- **Runtime state required:** approved plan reference.
- **Action:** compile the allowed-edit set; lock it.
- **Output artifact:** `.harness/runs/<run>/scope.lock.json` (hash-bound to the plan; not
  self-editable — unlike today's `current-scope.txt`, audit §3 self-escalation).
- **Verification:** every mutation (Edit/Write **and Bash-mediated writes**) checked ⊆ scope;
  scope-file mutation itself requires the human gate.
- **Failure mode:** over-eager edits; scope widened by the executor mid-run (currently possible:
  `scope-guard.sh:73-78`).
- **Recovery:** deny + STOP; the run halts with a scope-violation record; widening = plan
  amendment + re-approval.
- **Exit condition:** run diff ⊆ locked scope, verified from `git diff --name-only`, not from the
  agent's claim.
- **→ Enforced by P7 Scope Lock Manager** (with the Bash write-radius check from P5).

## B5. Regression radius stated before the change

Observable pattern: before editing shared code, the agent enumerates who else uses it (grep for
importers/callers) and says which behaviors could regress and how it will detect that.

- **Trigger:** plan drafting; any edit touching a file with >1 inbound reference or a landmark.
- **Input:** dependency surface (imports/includes/references) of the proposed scope.
- **Runtime state required:** orientation + landmarks.
- **Action:** compute inbound-reference counts for scoped files; list affected surfaces.
- **Output artifact:** "Change Radius" section of the plan: per file — dependents count, affected
  landmark classes, predicted regression checks.
- **Verification:** the verification plan (B8) must contain at least one check per predicted
  radius entry; verifier fails a run whose radius entries have no corresponding check.
- **Failure mode:** local fix, remote break; or radius theater (a list nobody verifies).
- **Recovery:** on a verification failure in a radius area, the failure is mapped back to the
  radius entry and the fix loop targets it — not a whack-a-mole rerun.
- **Exit condition:** all radius-linked checks PASS.
- **→ Enforced by P4 Dependency Surface Scanner + P5 Change Radius Predictor + P9 Verification
  Planner** (schema-linked: radius entries carry check IDs).

## B6. Rewrite avoidance (edit the seam, not the file)

Observable pattern: the agent prefers the smallest diff that satisfies the acceptance criteria;
whole-file rewrites, drive-by refactors, and unrelated formatting churn are absent from its diffs
unless the plan says otherwise.

- **Trigger:** execution.
- **Input:** locked scope + acceptance criteria.
- **Runtime state required:** scope.lock.
- **Action:** implement; the runtime measures, per file: lines changed vs file size, deletion
  ratio, out-of-criteria hunks.
- **Output artifact:** diff-stat record attached to run state.
- **Verification:** bounds from the plan (declared max files / max lines / deletion cap — already
  a stop condition in `AUTONOMY.md:56` item 9, currently unenforced at runtime).
- **Failure mode:** over-eager rewrite passing scope check because the *file* was in scope.
- **Recovery:** deny-and-halt at threshold; the human decides amend-plan vs revert.
- **Exit condition:** diff within declared bounds or bounds explicitly re-approved.
- **→ Enforced by P6 Minimal Diff Planner** (plan-declared bounds) + P7 (runtime bound check).

## B7. Acceptance criteria compiled into runnable checks

Observable pattern: "done" is defined before work starts, as concrete observable outcomes; each
criterion is paired at plan time with the exact command or inspection that will prove it.

- **Trigger:** plan drafting.
- **Input:** goal + user intent + repo verify commands (from orientation map).
- **Runtime state required:** orientation map.
- **Action:** compile each criterion into {check-id, command|inspection, expected result,
  machine-checkable: yes/no}.
- **Output artifact:** `acceptance.json` bound to the plan hash.
- **Verification:** plan validator refuses criteria with no method; verifier consumes check IDs.
- **Failure mode:** vibes-done ("should work now"); criteria that cannot fail.
- **Recovery:** critic REJECT (criterion untestable) → rewrite.
- **Exit condition:** all checks enumerated, each falsifiable.
- **→ Enforced by P8 Acceptance Criteria Compiler** feeding P9 Verification Planner and P10
  Evidence Ledger.

## B8. Verification is executed, observed, and quoted — never asserted

Observable pattern: the agent runs the checks, pastes actual command output (or the failure), and
reports FAIL honestly. Completion claims cite artifacts, not confidence.

- **Trigger:** end of each execution task; before any completion claim.
- **Input:** acceptance.json + change-radius checks.
- **Runtime state required:** run state, evidence ledger open.
- **Action:** execute checks; capture exit codes and bounded output into the ledger.
- **Output artifact:** evidence receipts (`.harness/schemas/evidence-receipt.schema.md` shape) —
  one per check, artifact-ref'd, subject-bound.
- **Verification:** the stop gate consults the receipt gate (v0.6.2 tool — today unwired, audit
  §9): no receipt set covering all required checks ⇒ completion blocked regardless of the
  message's wording (removing the keyword-regex dependence of `stop-verify-gate.sh:64`).
- **Failure mode:** fake-green (claiming done without running checks); keyword-dodged stop gate;
  FAIL report satisfying an existence-only check (all current, audit §3/§9).
- **Recovery:** blocked stop returns the missing check list; the run continues in the fix loop.
- **Exit condition:** receipt coverage == required check set, all PASS or human-waived.
- **→ Enforced by P10 Evidence Ledger + P18 Release Readiness Gate** (receipt-gate wired into the
  stop path).

## B9. Failed verification triggers diagnosis, not thrash

Observable pattern: on a red check, the agent reads the failure output, states a cause hypothesis,
makes one targeted change, and re-runs the *failing* check first — it does not shotgun-edit or
silently switch goals. After N failed cycles it stops and reports honestly.

- **Trigger:** any check FAIL.
- **Input:** failure output; change radius map; run history.
- **Runtime state required:** run state with per-check attempt counters.
- **Action:** record {check-id, attempt, hypothesis, files touched} per cycle.
- **Output artifact:** fix-loop log in run state.
- **Failure mode:** thrash (many files churned per attempt), goal drift (criteria quietly
  weakened), infinite loop.
- **Verification:** attempt counter bound (plan-declared, default small); criteria are immutable
  once approved (any weakening = plan amendment).
- **Recovery:** at the bound → STOP with a structured failure report (what failed, hypotheses
  tried, best known state, revert path).
- **Exit condition:** check green, or bounded stop with report.
- **→ Enforced by P13 Regression Suspicion Engine** (maps failures to radius entries) + P12
  Checkpoint Manager (known-good revert points) + P9 (immutable check set).

## B10. Stop-and-ask on genuine ambiguity; proceed on reversible defaults

Observable pattern: the agent distinguishes decisions that change scope, safety, acceptance, or
release semantics (asks, with the ambiguity stated crisply) from reversible implementation details
(picks the convention-consistent default and records it).

- **Trigger:** any decision point during plan or execution.
- **Input:** the decision, its blast class (from landmarks + radius).
- **Runtime state required:** plan + landmarks.
- **Action:** classify: {reversible-in-scope → decide & record} vs {scope/safety/release →
  halt & ask}.
- **Output artifact:** decision records (`decision-trace.schema.md` shape) — either
  "auto-decided, rationale, reversible" or "escalated, question, options".
- **Verification:** decision trace validator (v0.6.5) — every landmark-touching decision must
  link to an approval; auto-decided entries must be non-landmark.
- **Failure mode:** asking about everything (stall) or asking about nothing (silent scope creep).
- **Recovery:** critic audits the decision trace; misclassified decisions become findings.
- **Exit condition:** no unlinked landmark decision at release time.
- **→ Enforced by P17 Human Gate** (typed escalation) + P16 Critic Gate (trace audit), using the
  existing v0.6.5 decision-trace validator.

## B11. Long-horizon continuity via durable artifacts, not memory

Observable pattern: across interruptions/compaction/session restarts, the agent re-derives where it
was from files on disk (plan, run state, evidence, git status) and continues — it does not trust
remembered state, and its first post-resume act is a state audit.

- **Trigger:** session start with `.harness/runs/<run>/` present; or post-compaction marker.
- **Input:** run state, scope.lock, evidence ledger, `git status`/`git diff` **actual** output.
- **Runtime state required:** everything B1–B9 wrote (this is why they write files).
- **Action:** reconcile declared state vs observed git state; compute next safe action
  (the v0.5.7 tool's logic — but fed observed facts, not caller-declared ones,
  fixing `docs/RESUME_RECOVERY.md:88`).
- **Output artifact:** resume report appended to run state.
- **Failure mode:** continuing from remembered-but-stale state; double-applying work; losing the
  fix-loop counter.
- **Recovery:** on irreconcilable state → checkpoint restore (P12) or halt-and-ask.
- **Exit condition:** declared == observed, run continues; else halted with the delta.
- **→ Enforced by P11 Context Recovery Manager + P12 Checkpoint Manager.**

## B12. Delegation with retained accountability

Observable pattern: the agent hands subagents *bounded, self-contained* briefs (inputs, expected
artifact, constraints), treats their output as untrusted proposals to be checked, and never lets a
delegate's claim substitute for its own verification. Implementation work and orchestration
decisions are visibly separated.

- **Trigger:** task decomposition yields independent units, or an independent-judgment role
  (critic/verifier) is required.
- **Input:** unit brief; role contract (allowed tools, artifact schema).
- **Runtime state required:** run state; role registry.
- **Action:** dispatch with role contract; on return, validate the artifact against its schema
  before consuming it.
- **Output artifact:** delegation record {role, brief hash, artifact ref, validation verdict}.
- **Verification:** artifact schema validation is mechanical (the worker path already has
  `worker-result-check.py`; subagent outputs currently have nothing — audit §11).
- **Failure mode:** trusting delegate prose; delegate mutating the repo (only the executor role
  may mutate, and only under scope.lock); orchestrator implementing while orchestrating (loses
  the independent-review property).
- **Recovery:** invalid artifact → reject & re-dispatch or absorb the unit inline; mutation by a
  non-executor role → stop condition.
- **Exit condition:** every consumed delegate artifact carries a validation verdict.
- **→ Enforced by P14 Subagent Orchestrator + P15 Worker Proposal Importer.**

## B13. Release readiness as a composed checklist, not a feeling

Observable pattern: before declaring a milestone shippable the agent walks a fixed list — diff ⊆
scope, checks green, findings dispositioned, docs updated, evidence linked, approval recorded —
and blocks itself on any gap.

- **Trigger:** completion claim / closure request.
- **Input:** all run artifacts.
- **Runtime state required:** full run state.
- **Action:** compose the existing deterministic gates (v0.6.2 receipts, v0.6.3 findings, v0.6.4
  goal, v0.6.5 trace, v0.2.6 gate checks) into one verdict.
- **Output artifact:** release-readiness report (PASS/FAIL per gate + overall).
- **Verification:** each sub-gate is an existing fail-closed validator with negative controls.
- **Failure mode:** gates exist but idle (today's state, audit §4.3); partial-green shipped as
  green.
- **Recovery:** FAIL lists the gap; work resumes; the human gate sees the composed report, never
  a summary sentence.
- **Exit condition:** composed PASS + human release approval (typed, Q6).
- **→ Enforced by P18 Release Readiness Gate + P17 Human Gate.**

---

## Transfer table (behavior → primitive → exists today?)

| Behavior | Primitive | Today in DMC |
|---|---|---|
| B1 orientation | P1 | prose only (`/dmc-init-deep` → free-text AGENTS.md, stale in own repo) |
| B2 landmarks | P2 | hand-maintained lists ×6 docs, drifting |
| B3 pattern reuse | P3 | absent |
| B4 scope lock | P7 | `current-scope.txt` — self-editable, Bash-bypassable |
| B5 change radius | P4+P5 | absent |
| B6 minimal diff | P6 | AUTONOMY stop-condition prose; v0.4.3 advisory tool, unwired |
| B7 criteria→checks | P8 | PLAN_SCHEMA prose section, no validator |
| B8 evidence-gated done | P10+P18 | v0.6.2 gate exists, unwired; stop gate keyword-based |
| B9 bounded fix loop | P13+P12 | absent |
| B10 typed escalation | P17+P16 | human gate prose + v0.6.5 trace validator (unwired) |
| B11 durable resume | P11+P12 | v0.5.7 tool takes *declared* facts; nothing reads real state |
| B12 accountable delegation | P14+P15 | worker path half-coded; subagents orphaned |
| B13 composed release gate | P18 | closure controller + v0.6 gates exist, never composed/wired |

The pattern of the table is the audit's central finding restated: **DMC has already built most of
the checkers; what v1.0 must build is the spine that makes the behaviors non-optional** — state
that persists, gates that fire without being asked, and a portable driver so the same discipline
binds any model.
