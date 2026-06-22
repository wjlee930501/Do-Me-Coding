# DRAFT PLAN — DMC v0.5.3–v0.5.9 Dynamic Workflow Control Plane

Status: **APPROVED** (Codex adversarial design-critic PASS after Revision 1 — 6/6 REQUIRED addressed, no new blocker;
thread 019eee66). Base main: `ece6a9a`. Branch: `dmc-dynamic-workflow/v0.5.3-v0.5.9`. Operating model: Opus A
(implement/orchestrate) + Opus B (falsify) + Codex (audit). Per-milestone Opus B falsification + Codex release audit
follow implementation; no push / no main / no closure.

## Thesis
Choose the **smallest sufficient workflow** that still closes a task E2E (verified → reviewed → committed → pushed →
closure when applicable). NOT token maximization. Risk facts escalate; absence of risk keeps the lane minimal.

## Shared conventions (every tool)
- **Advisory / read-only / inert unless invoked** (explicit flag dispatcher; no top-level side effects; usage→exit 2).
- **Offline / local / no network / no live call.** Reads **no** env var, `.env`, credential, token, or provider payload.
  Inputs are **explicit task facts via flags/JSON/files only** — never inferred from the environment or by scanning repo
  secrets.
- **Deterministic + env-independent**: same inputs ⇒ byte-identical output; `env -i` + credential-var differential
  byte-identical.
- **No env-controlled hash** (v0.5 REVISE lesson): `repo_hash()` = `git status --porcelain | python3 hashlib.sha256`.
  No `DMC_HASH_CMD`/`HASH_CMD`.
- **Fail-CLOSED parsing** (v0.5.2 lesson): unknown/unparseable/non-canonical danger facts ESCALATE (never silently
  downgrade). Unknown task class ⇒ highest-risk lane.
- **Path-derived secret classification** (v0.5.1 lesson): secret status from the PATH, never a caller-supplied label.
- **Redaction is value-blind, best-effort, NOT a completeness guarantee** — emitted artifacts say "review before commit".
- **`--out` guard** (v0.4.9 hardened): refuse `..`/secret/protected/in-work-tree/symlink/tracked targets; ROOTDIR
  derived from SELFPATH.
- **Structural self-audit** (AUDIT_BLOCK): no `curl/wget/--live/--allow-network/os.environ/getenv/printenv/HASH_CMD/
  ${DMC_*}` in operative source.
- **Self-test proves the real repo is byte-unchanged** (deterministic sha256 PRE==POST).
- **run-mode ≠ provider_target** (v0.3.4 lesson): `mock` is a RUN-MODE, never a provider_target/lane fact.
- **Monotonicity is STRUCTURAL** (Codex-3), not asserted: lane / effort / verification-depth = `max(...)` over all
  contributing facts; required gates and required checks = **unions**; forbidden checks **accumulate**. Never first-match /
  never override-down. Pairwise monotonic fixtures (add each risk fact in turn, assert intensity is non-decreasing) are
  part of every selector / planner self-test.
- **`repo_hash` claims "worktree-status unchanged"** (Codex-A3), not "byte-unchanged"; when a milestone asserts protected
  byte-identity it ALSO runs an explicit `git diff --stat`/name-status protected-path check.

## Lanes (v0.5.3) — least → most intense
`docs-only` < `additive-tooling` < `release-closure` < `recovery-resume` < `protected-surface` <
`secret-network-live-risk`.
- **`provider-adapter` / router / schema / guard / hook / validator / `dmc-glm-smoke` facts ARE protected surface** — any
  such path or task fact forces lane ≥ `protected-surface` (+ human gate + protected-path byte-unchanged checks). There is
  no separate lower-intensity adapter lane (Codex-1/2).
- **Closed fact schema (fail-closed input):** the selector accepts an explicit closed set of task facts. A **missing,
  null, or non-canonical** danger fact (`protected_surface`, `secret_network_live`, `task_class`, changed-path category)
  ⇒ escalate to `secret-network-live-risk` (or BLOCKED). "No risk" means **explicitly-validated no-risk**, never
  "fact omitted" (Codex-1).
- **Unknown task class ⇒ `secret-network-live-risk`** (fail-closed, max).

## Per-milestone scope (additive; protected surface UNTOUCHED)
- **v0.5.3 Dynamic Workflow Selector** — task facts → {lane, required gates, min effort, verification depth}. Composes
  v0.5.2 effort + AUTONOMY gates. `docs/DYNAMIC_WORKFLOW.md` + evidence script + plan + verification.
- **v0.5.4 Workflow State Machine** — allowed/forbidden transitions over DRAFT→CRITIC→APPROVED→START_WORK→VERIFY→
  RELEASE_AUDIT→STAGE→COMMIT→PUSH→CLOSURE→BLOCKED; resume-safe (no stale-gate inference); distinguishes accepted-for-
  review vs published-to-main vs closure-recorded. Validates a transition or a full path; rejects premature DONE / stale
  approval / closure-before-publish.
- **v0.5.5 Verification Planner** — changed-path categories + lane → {required, optional, forbidden checks, reason};
  protected-near-scope ⇒ byte-unchanged checks; artifact-with-text ⇒ leak scans; guard/importer/classifier ⇒ reject-path
  tests; malformed path list ⇒ fail closed.
- **v0.5.6 Review Packet Generator v2** — names-only by default; NO commit-body `%b`; no arbitrary report-path read
  (allowlist); redact/refuse secret-shaped metadata; identifies base/head/file-list/stat/protected-touches/forbidden-
  paths/test-summaries; deterministic.
- **v0.5.7 Resume & Recovery Controller** — git state + run artifacts → next safe action; never push with
  staged/uncommitted; never commit excluded-auto-log/protected; never infer approval from stale run file; dirty-worktree
  classification (safe-auto-log-only vs not).
- **v0.5.8 Dynamic Delegation Harness** — Orchestrator/Implementer/Critic/Release-Gate roles (owns / must-not / outputs);
  critic PASS ≠ release authorization; bounded-batch autonomy encoded; forbids self-approval / ungated push / closure-
  before-publish / secret-env reads / token-max tool expansion; compact handoff prompt; no leaked/proprietary prompt text.
- **v0.5.9 Dynamic Workflow Capstone** — composes v0.5.3–v0.5.8 offline over 7 synthetic scenarios (docs closure; additive
  advisory tool; provider/import adapter; protected-surface proposed change; failed-verification recovery; review-branch
  publication; premature-closure attempt). Asserts E2E-DONE only when all required conditions met; smallest-sufficient +
  monotonic; negative fixtures fail closed; repo byte-unchanged.

## Acceptance gate (per milestone)
Self-test green (real repo byte-unchanged) + Opus B falsification finds no blocker + Codex audit ACCEPT. Blocking classes:
secret leak, env inference, false DONE, under-classified dangerous work, path-allowlist bypass, protected-surface
mutation, advisory-mistaken-for-enforcement, gate confusion, stale-state inference, mock/run-mode category error.

## Revision 1 — Codex critic fixes (incorporated)
- **R4 / v0.5.4 (Codex-4):** every gated transition is bound to **immutable run facts** and refuses on mismatch/missing —
  `run_id`, plan path + content-hash + status, changed-file-set digest, current worktree-status hash, `verification=PASS`
  for **that same head**, an **exact-anchored** review verdict, and the commit hash. A transition whose required facts are
  absent or do not match ⇒ `BLOCKED` (no stale-approval / no false DONE). `critic PASS` is advisory and, by itself, only
  authorizes the next step that **this bounded batch** already authorizes — never push/main/closure.
- **R5 / v0.5.6 (Codex-5):** report reads are restricted to **canonical realpaths under `.harness/verification/*.md`**
  only; symlink / `..` / secret / protected / out-of-tree targets are refused. The packet extracts only **anchored
  metadata fields**, emits **no** command output / free-form summaries, and **structurally bans** commit-body `%b` and the
  content-extraction primitives `patch` / `diff` / `cat-file` / `log -p` / `diff-tree` / `format-patch` / `show <blob>`.
- **R6 / v0.5.7 (Codex-6):** the resume controller **never** emits "safe to commit / safe to push". It emits a
  `needs_human_gate` candidate **bound to the exact staged digest or commit hash**, plus a `blocked_reason`. Absent / stale
  upstream, an unbound approval / review / verification, or any staged-but-uncommitted or protected/auto-log staged change
  ⇒ `BLOCKED`. Local offline git state can never prove a current human gate.
- **A1 / v0.5.9 (Codex-A1):** include explicit mock-category fixtures — **reject `provider_target.type=mock`** (category
  error), while allowing `run_mode=mock` as an offline run-mode under a live-capable provider target only.
- **A2:** v0.5.6 is a **new v2 generator** (additive); the shipped v0.3.6 packet tool is NOT modified.

## Out of scope (forbidden unless a critic-approved DRAFT proves necessity)
Adapters, provider-router, schemas, hooks, guards, validators, `dmc-glm-smoke`, MILESTONES closure, push, main merge.
