# Plan — dmc-v0.3.8 Autonomous Delegation Harness

Status: APPROVED
Approval Status: APPROVED
Mode: PLAN ONLY until APPROVED. **Additive, read-only** — codifies the delegation process + validates a run against it;
modifies no protected surface.

## Goal
A **harness** that codifies how DMC autonomous delegation runs safely — **role-assignment + critic-handoff templates**, an
**allowed-autonomy vs gated-action matrix** (faithful to the authoritative handbook gate map), and a **run-transcript
checklist** — plus a **read-only validator** that mechanically checks the allowed-autonomy **preconditions** of a milestone
run (plan APPROVED, separate critic PASS, Codex ACCEPT **as an advisory input**, verification PASS) and the **observable
push boundary** (push deferred / approved / UNKNOWN). It **validates only**: performs no action, grants no gate, mutates
nothing, makes no live call, reads no secret content.

## User Intent
v0.3.8 roadmap: "role assignment / critic handoff 템플릿, allowed-autonomy / gated-action 매트릭스, run transcript
checklist." Turn the delegation discipline into an explicit, checkable harness — codifying the **authoritative** gate map,
not a convenience variant.

## Current Repo Findings — the AUTHORITATIVE gate map (must be codified faithfully)
- `docs/DMC_AGENT_HANDOFF.md:8-21` lifecycle gate table: DRAFT(no) → CRITIC(no) → **APPROVED(yes)** → START-WORK(no,
  in-scope) → VERIFY(no) → **STAGE(yes)** → **COMMIT(yes)** → **PUSH(yes)** → **CLOSURE(yes)**.
- `docs/DMC_OPERATOR_HANDBOOK.md:48` Allowed autonomy (no human gate): DRAFT plan, critic, start-work-in-scope, verify.
  `:57-62` Gated actions (require an explicit human gate **EACH time**): `git add`/staging, `git commit`, `git push`,
  protected-surface change, force/history-rewrite. `:43` the human **Release Gate** authorizes staging/commit/push/live/
  protected-change. `:45` hard separation: no self-approval / no self-granted gate.
- `docs/DMC_EFFORT_PROVIDER_POLICY.md:28-30`: a **Codex ACCEPT is an independent advisory audit input feeding the human
  Release Gate, NOT itself one of the nine human gates; an agent never treats a Codex ACCEPT as a granted gate.**
- `docs/DMC_AGENT_HANDOFF.md:23-28` current-gate rule: never infer a gate; an in-progress run is not consent to stage/
  commit/push; if you cannot point to an explicit human grant, stop and ask.
- **Delegated autonomy** (the model the v0.3.x batch ran under): a **recorded standing human delegation** MAY pre-grant
  specific gated actions for a scoped batch (e.g. stage+commit) while push/closure remain per-action gated. This is a
  *recorded human authorization* of those gates — NOT autonomous self-granting.
- Reuse: the v0.3.7 exact-`codex=ACCEPT`-line / equal-ratio / `**FAIL**`-disqualifier judgment forms + the v0.3.6
  names-only / secret-path discipline.

## Relevant Files (all additive)
- `docs/DMC_DELEGATION_HARNESS.md` — roles + critic-handoff templates, the allowed-autonomy/gated-action matrix, the
  run-transcript checklist.
- `.harness/evidence/dmc-v0.3.8-delegation-harness.sh` — the read-only precondition + push-boundary validator (+ `--self-test`).
- `.harness/verification/dmc-v0.3.8-delegation-harness.md` — verification report.
- `.harness/plans/dmc-v0.3.8-delegation-harness.md` — this plan.

## Out of Scope (with rationale)
- **No action / no gate** — the validator judges; it performs no autonomy action and **grants no gate**. It never
  pushes/commits/stages/writes (only a guarded `--out`). Codex ACCEPT is an advisory input it checks for, never a grant it
  issues.
- **No secret content** — the `--plan` AND `--verify-report` paths are refused unread if they match a secret pattern; git
  is metadata-only (`merge-base`, `rev-parse`); no content-dumping git, no `%b`.
- **No live call / no protected edit** — git-local + file reads only; read-only over all protected surfaces.
- **Not an enforcement mechanism** — like the v0.2.9 policy, the matrix/checklist is a behavioral norm; the validator
  reports but cannot prevent a violation; the human Release Gate remains authoritative. The validator does **not** claim
  to verify the human STAGE/COMMIT/CLOSURE gates (those are human-side records) — it verifies the allowed-autonomy
  preconditions and the observable PUSH boundary, and surfaces the gated actions.

## Proposed Changes
### A. `docs/DMC_DELEGATION_HARNESS.md`
1. **Role-assignment template** — Orchestrator (plans, applies REQUIRED), Critic (separate adversarial pass; PASS/REVISE;
   never implements/approves its own work), Implementer (approved scope only), Independent Auditor (Codex; read-only;
   ACCEPT/REVISE/BLOCKED — an advisory input). Hard separation: the role that wrote a thing never approves it.
2. **Critic-handoff template** — the structured dimension-critic shape (dimension, verdict, required_changes[],
   optional[], notes) + the REVISE→fix→re-pass→(human) APPROVED flow.
3. **Allowed-autonomy vs gated-action matrix** (faithful to the handbook):
   - **Allowed (no human gate):** write/revise a DRAFT plan; run a critic panel; apply REQUIRED changes; start-work
     **within the approved scope**; run verification; run the Codex audit + gate-check (**advisory inputs**).
   - **Gated (explicit human gate EACH time, or a recorded standing delegation that pre-grants it):** **APPROVED flip**,
     **STAGE**, **COMMIT**, **PUSH**, **CLOSURE**, live-provider-call, credential/`.env` access, protected-surface change
     beyond the approved scope, history-rewrite/force, external-publish/send.
   - **Codex ACCEPT / gate-check are advisory INPUTS feeding the human Release Gate — never a granted gate.** An agent
     never treats a Codex ACCEPT as authorizing STAGE/COMMIT.
   - **Delegated autonomy:** a recorded standing human delegation may pre-grant specific gated actions for a scoped batch
     (e.g. stage+commit), with push/closure remaining per-action gated.
4. **Run-transcript checklist** — ☐ DRAFT plan; ☐ separate critic PASS; ☐ REQUIRED applied; ☐ **human APPROVED flip** (or
   recorded standing delegation); ☐ approved-scope-only implementation; ☐ verification PASS; ☐ Codex ACCEPT (**advisory
   input**, before the gated transition); ☐ **STAGE under a recorded gate/delegation** (approved files only); ☐ **COMMIT
   under a recorded gate/delegation** (exact message); ☐ **PUSH under a per-action human gate** (or correctly deferred);
   ☐ **CLOSURE under a human gate**.

### B. `.harness/evidence/dmc-v0.3.8-delegation-harness.sh` (new; `--self-test`; `PYTHONDONTWRITEBYTECODE`)
CLI: `dmc-v0.3.8-delegation-harness.sh --milestone <id> --plan <plan.md> --verify-report <report.md> --commit <ref>
[--repo <dir>] [--push-approved] [--out <file>]` · `--self-test`. Read-only checks (fail-closed):
1. **plan-approved** — the `--plan` (secret-path-guarded) has `^Approval Status: APPROVED`.
2. **separate-critic-pass** — the `--verify-report` (secret-path-guarded) `Review-Verdict:` line has `critic=PASS`.
3. **codex-accept-input** — the exact anchored line `^Review-Verdict: critic=PASS codex=ACCEPT[[:space:]]*$` (per v0.3.7).
   **Necessary-but-not-sufficient**: an advisory audit input that must PRECEDE the human stage/commit gate — it does NOT
   by itself authorize commit.
4. **verification-pass** — `## Final Status **PASS**` + an all-pass count (`N PASS / 0 FAIL` or equal `N/N`; no `**FAIL**`/
   `N>0 FAIL`), per the v0.3.7 verified rule.
5. **push-boundary** — `judge_push`: if `<ref>^{commit}` is unresolvable OR local `origin/main` is absent ⇒ **UNKNOWN**
   (fail-closed ⇒ flagged NON-COMPLIANT, never COMPLIANT); else `merge-base --is-ancestor <ref> origin/main` ⇒ **PUSHED**
   (flagged "push performed — requires `--push-approved` / recorded human approval") else **DEFERRED** (compliant — push
   correctly deferred to the human gate). NOTE the polarity is **inverted vs v0.3.7** (there ancestor=MET; here
   ancestor=PUSHED=flagged).
6. **Judgment** — `AUTONOMY-COMPLIANT` iff checks 1–4 PASS **AND** push ∈ {DEFERRED, (PUSHED with `--push-approved`)}; else
   `NON-COMPLIANT` + the failing items. The output **explicitly states** STAGE/COMMIT/CLOSURE are GATED (handbook) and
   their authorization is a recorded human gate or standing delegation that this validator surfaces but does not grant;
   and that Codex ACCEPT is an advisory input. Advisory exit: `0` AUTONOMY-COMPLIANT, `1` NON-COMPLIANT.

## Acceptance Criteria (measurable; `--self-test`, offline only; a FIXED $TMPDIR temp git repo)
- **AC1 read-only**: `git rev-parse HEAD` + branch + `md5(config --list)` + `status --porcelain` pre==post on BOTH the
  real and the temp repo; the validator writes/commits/pushes/stages **nothing**.
- **AC2 check correctness (both polarities, pinned)**: plan-approved (APPROVED⇒PASS, DRAFT⇒FAIL); critic-pass
  (`critic=PASS`⇒PASS, `critic=REVISE`⇒FAIL); codex-accept-input (exact `codex=ACCEPT`⇒PASS, `codex=PENDING` and the
  `codex=ACCEPTED` suffix⇒FAIL); verification-pass (PASS+all-pass⇒PASS, `**FAIL**`/mixed/non-equal-ratio⇒FAIL);
  push-boundary (origin/main present + ref not ancestor ⇒ **DEFERRED**; ref is ancestor ⇒ **PUSHED**; **no local
  origin/main ⇒ UNKNOWN**; **bogus ref ⇒ UNKNOWN**).
- **AC3 AUTONOMY-COMPLIANT iff preconditions + bounded push**: a fully-compliant fixture (APPROVED + critic=PASS
  codex=ACCEPT + Final PASS + DEFERRED push) ⇒ AUTONOMY-COMPLIANT + exit 0; any failing precondition ⇒ NON-COMPLIANT +
  failing list + exit 1; a **PUSHED** commit without `--push-approved` ⇒ NON-COMPLIANT; **PUSHED + `--push-approved`** ⇒
  COMPLIANT.
- **AC4 fail-closed (incl. indeterminate push)**: absent/secret-pathed `--plan` or `--verify-report` ⇒ the dependent
  checks FAIL (never a false COMPLIANT); **no local `origin/main` + a valid ref ⇒ push UNKNOWN ⇒ NON-COMPLIANT** (NOT a
  false COMPLIANT); **a bogus `--commit` ⇒ push UNKNOWN ⇒ NON-COMPLIANT**.
- **AC5 `--out` guard**: refuses protected/secret/traversal(incl benign-resolving `..`)/symlink targets; benign allowed
  (reuse the v0.3.5–v0.3.7 hardened guard).
- **AC6 no secret content (structural audit, enumerated + self-excluded)**: the `--plan`/`--verify-report` secret-path
  guards + metadata-only git; a structural audit — **its own block excluded from the scan (like v0.3.6/v0.3.7) so the
  enumerated pattern strings do not self-match** — that FAILs on the **same enumerated set as v0.3.7 AC7**:
  `format-patch|cat-file|diff-tree`, `(show|log|diff) … -p|--patch`, a bare `git show <ref>` without
  `-s`/`--name-status`/`--name-only`/`--stat`/`--numstat`, lowercase `%b`, and any credential-var read.
- **AC7 doc completeness**: `docs/DMC_DELEGATION_HARNESS.md` contains the 4 sections; the matrix lists
  **STAGE/COMMIT/PUSH/CLOSURE as GATED**, lists `live-provider-call`/`credential` as GATED, lists `Codex ACCEPT` as an
  **advisory input (not a grant)**, and lists DRAFT-plan/critic/start-work-in-scope/verify as ALLOWED.

## Risks (+ mitigations)
- **R1 false COMPLIANT** → every precondition fail-closed; AC2 pins both polarities; AC3 asserts COMPLIANT iff
  preconditions PASS AND push bounded; AC4 asserts absent/secret signals AND the **indeterminate push state (UNKNOWN)**
  never yield COMPLIANT; a PUSHED commit needs `--push-approved`.
- **R2 mis-codified matrix** (the round-1 defect) → the matrix is taken **verbatim from the handbook gate map**
  (HANDOFF:8-21, HANDBOOK:48/57, POLICY:28-30): STAGE/COMMIT/PUSH/CLOSURE GATED; Codex ACCEPT advisory input. AC7 asserts
  this; the validator never treats Codex ACCEPT as authorizing commit.
- **R3 accidental action** → AC1 read-only (both repos pre==post); only reads + a guarded `--out`.
- **R4 secret leak** → `--plan`/`--verify-report` secret-path-guarded; metadata-only git; no `%b`; AC6 enumerated +
  self-excluded structural audit.

## Assumptions
- A milestone run is represented by its plan + verify-report + commit, following the v0.3.x conventions.
- The self-test temp repo uses pinned dates + a manufactured `refs/remotes/origin/main`; assertions use set-membership.

## Execution Tasks (after APPROVED)
1. Author `docs/DMC_DELEGATION_HARNESS.md` (change A — the 4 sections, handbook-faithful matrix).
2. Author `dmc-v0.3.8-delegation-harness.sh` (checks B1–B6 with the `judge_push` DEFERRED/PUSHED/UNKNOWN states;
   `--plan`/`--verify-report` secret-path guards; reuse v0.3.7 forms; `--out` hardened guard; enumerated + self-excluded
   structural audit; `--self-test` with a fixed temp repo + manufactured origin/main; PYTHONDONTWRITEBYTECODE).
3. Run `--self-test` → all PASS (AC2 both polarities incl. push UNKNOWN; AC3 dual exit; AC4 indeterminate-push fail-closed;
   AC1 read-only both repos); write the verification report; gate-check; critic; Codex audit (an advisory input). Commit
   only under a recorded human STAGE/COMMIT gate or standing delegation — a Codex ACCEPT is a **precondition**, not the
   grant; **no push** (push remains a per-action human gate).

## Verification Commands
- `bash .harness/evidence/dmc-v0.3.8-delegation-harness.sh --self-test`
- a functional run against this batch (e.g. `--milestone dmc-v0.3.7 --plan … --verify-report … --commit 8cd3435`) —
  expect AUTONOMY-COMPLIANT (APPROVED + critic=PASS codex=ACCEPT + Final PASS + push DEFERRED)
- `git status --porcelain` (expect only additive untracked + excluded auto-log); gate-check; then Codex audit.

## Approval Status
**APPROVED (rev 2)** — round-1 3-critic panel **REVISE ×3**: the load-bearing fix was a **mis-codified matrix** (I had
`stage`/`commit` as ALLOWED and Codex ACCEPT as granting commit) — corrected to the **handbook gate map**
(STAGE/COMMIT/PUSH/CLOSURE GATED; Codex ACCEPT an advisory input, never a grant); plus the **push-UNKNOWN** fail-closed
state (absent local origin/main OR unresolvable ref ⇒ NON-COMPLIANT) and AC6 enumerated + self-excluded. **Round-2
focused re-pass: PASS** — all 6 REQUIRED resolved; one new_defect (a residual "commit on ACCEPT" phrasing in Execution
Task 3) corrected to "commit only under a recorded human gate/standing delegation; Codex ACCEPT is a precondition, not the
grant." Next: `/dmc-start-work`. Additive/read-only; no provider-surface change.
