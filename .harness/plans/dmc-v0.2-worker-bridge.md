# Do-Me-Coding v0.2 — Worker Bridge Orchestration (contract & safe local loop)

## Goal

Design a SAFE Worker Bridge contract where Claude/Codex is the **orchestrator** and GLM 5.2 (or
other models) act as **bounded workers** that produce **structured proposals only** — never direct
repo mutations. DMC retains control of scope, security, verification, and evidence. v0.2 delivers
the contract + the local manual review/import loop, validated end-to-end with a **mocked** worker
result. No live model API, no credentials, no automatic apply.

## User Intent

feature

## Core Principle (non-negotiable)

```
Workers do not mutate the repo.
Workers produce structured proposals only.
The orchestrator decides what to apply.
DMC controls scope, security, verification, and evidence.
```

A worker has NO filesystem, git, shell, or network access to the repo. The bridge passes JSON IN
(a clipped, secret-scrubbed task) and JSON OUT (a structured result with a *proposed* patch). The
orchestrator applies anything — through the existing DMC scope gate + verification — by hand.

## User Intent / Scope clarification

v0.2 builds the **contract and the local loop** and proves it with a **mocked worker**. Calling a
real GLM API is a separate, later increment (a thin dispatch adapter); v0.2 adds NO credentials and
makes NO external calls (per constraints). `/dmc-worker-dispatch` in v0.2 targets a local mock or a
hand-run model, writing a result file that the rest of the loop consumes.

## Resolved Decisions (pre-critic)

1. **Mock-only v0.2.** No live GLM API calls, no live provider integration, no API keys, no OAuth, no
   credentials, no external dispatch. v0.2 validates the Worker Bridge contract using **mock / manual-import
   results only**. The API-key GLM adapter is deferred to **v0.2.1**; the OAuth / local-CLI provider adapter
   to **v0.2.2 or later**.
2. **Worker artifact commit policy.** In a HOST repo, default **local-only / gitignored** for
   `.harness/workers/tasks/`, `.harness/workers/results/`, `.harness/workers/reviews/`, and
   `.harness/workers/sessions/`. Commit is **opt-in only**. `sessions/` is **always** local-only. The DMC
   repo may commit only **sanitized fixtures**. Rationale: tasks/results may include code context and must
   not become default repo noise or a privacy risk.
3. **Interchange format = unified diff text.** The proposed patch is unified-diff TEXT (human-reviewable,
   git-compatible); NO structured edit ops in v0.2. `WORKER_RESULT_SCHEMA` includes
   `files_considered`, `files_changed`, `assumptions`, `risks`, `test_suggestions`, `confidence`.
   **Disallowed by default** in a proposed patch: binary patches; lockfile changes; dependency upgrades;
   DB/schema/migration changes; and secret/config/`.env` changes. (Allowed only if `allowed_files`
   explicitly lists them AND the orchestrator approves.)
4. **Apply path = Option A — scope-guarded Edit/Write ONLY.** A worker result may contain a unified diff,
   but in v0.2 the diff is a **review artifact only — not an executable patch**. v0.2 MUST NOT apply worker
   patches with `git apply`, `patch`, or any Bash-based patch application. Worker dispatch, import, and review
   MUST NOT mutate the repo (import stores + validates the result only). If the orchestrator decides to apply
   a proposal, it must **manually translate the change into DMC scope-guarded `Edit`/`Write` operations** —
   `scope-guard.sh` intercepts `Edit`/`Write` and denies any file outside the approved scope. The enforced
   v0.2 apply path is therefore:
   `worker result → orchestrator review → DMC plan/scope → Edit/Write under scope-guard → verification → evidence`.
   `git apply`/`patch` may be considered only in a LATER version, after a dedicated pre-apply diff-path
   validation gate exists. **No new mutation surface in v0.2.** (NOTE: `git apply` is a Bash command and is
   NOT intercepted by scope-guard, which matches `Edit|Write` — hence it is forbidden here.)
5. **Future OAuth / local-CLI provider boundary (design-level only; not built in v0.2) — hard line:** DMC may
   only invoke an **approved local command adapter** in future versions; DMC must NEVER read, store, export,
   inspect, or commit OAuth tokens; never read provider session files; never handle refresh tokens. Provider
   session state remains owned by the provider CLI/app/keychain. DMC receives **structured worker output
   only**. Any such automation must comply with provider terms and product behavior.

**Explicit non-goal (added):** v0.2 must NOT optimize cost / quota / subscription usage. Cost/quota/subscription
strategy comes AFTER provider adapters exist.

## Current Repo Findings

- Finding: v0.1.3 shipped `secret-guard.sh` (path-based Read/Grep/Glob deny; all-mode floor) and `pre-tool-guard.sh` (Bash secret deny). The worker context builder MUST reuse the same secret-path detector so no secret file is ever packaged.
  Source: `.claude/hooks/secret-guard.sh`, committed `4be38ac`.
- Finding: `scope-guard.sh` already enforces an allowed-file scope (`.harness/runs/current-scope.txt`) on Edit/Write; the orchestrator's "apply patch" step reuses this gate — workers never touch files, the orchestrator applies within scope.
  Source: `.claude/hooks/scope-guard.sh`.
- Finding: Schemas follow a stable doc style (`PLAN_SCHEMA.md`, `RUN_SCHEMA.md`, `VERIFICATION_SCHEMA.md`); worker schemas should match that style.
  Source: root `*SCHEMA.md`.
- Finding: `.harness/` has decisions/evidence/memory/plans/runs/schemas/verification; v0.2 adds a `workers/` subtree.
  Source: `ls .harness/`.
- Finding: v0.1.3 host-repo artifact policy defaults DMC working artifacts to local-only in host repos; worker tasks/results/reviews embed code context and should follow (or exceed) that policy.
  Source: `docs/HOST_REPO_ARTIFACT_POLICY.md`.

## Relevant Files

| Path | Reason | Allowed to Edit (future approved run) |
|---|---|---|
| `WORKER_TASK_SCHEMA.md` | NEW — worker task contract | yes (new) |
| `WORKER_RESULT_SCHEMA.md` | NEW — worker result contract | yes (new) |
| `WORKER_REVIEW_SCHEMA.md` | NEW — orchestrator/critic review record | yes (new) |
| `.claude/skills/dmc-worker-plan/SKILL.md` | NEW — author a worker task | yes (new) |
| `.claude/skills/dmc-worker-dispatch/SKILL.md` | NEW — package + hand to worker/mock (no live API in v0.2) | yes (new) |
| `.claude/skills/dmc-worker-import/SKILL.md` | NEW — ingest + validate a worker result | yes (new) |
| `.claude/skills/dmc-worker-review/SKILL.md` | NEW — orchestrator/critic review | yes (new) |
| `.claude/skills/dmc-worker-status/SKILL.md` | NEW — list tasks/results/reviews | yes (new) |
| `.claude/skills/dmc-worker-cancel/SKILL.md` | NEW — cancel/expire a task | yes (new) |
| `.claude/hooks/worker-context-guard.sh` | NEW — validates a task bundle excludes secret/forbidden paths before dispatch | yes (new) |
| `.harness/workers/` (tasks/results/reviews/sessions) | NEW — storage subtree (+ `.gitkeep`) | yes (new) |
| `.gitignore` | add worker local-only rules | yes |
| `INSTALL_MANIFEST.md` | add worker schemas/skills/hook to install surface | yes |
| `DMC.md`, `CLAUDE.md` | document the Worker Bridge contract + the no-mutation rule | yes |
| `.claude/hooks/secret-guard.sh`, `scope-guard.sh` | read-only — REUSED, not modified (no guard weakening) | no |

## Out of Scope (v0.2)

- Autonomous multi-worker execution; worker swarms.
- **Direct GLM/worker repo mutation** (workers never write files/git).
- Background / cloud execution; long-running daemons.
- **Automatic patch application** (every apply is orchestrator-gated + verified).
- Live external GLM API calls; model credentials/secrets; provider config.
- Cost optimization; model-marketplace / dynamic routing.
- Weakening or bypassing any existing guard (secret-guard, scope-guard, stop gate stay intact).

## Proposed Changes

### 1. Worker Task Schema (`WORKER_TASK_SCHEMA.md`)
Fields: `task_id` · `objective` · `allowed_files[]` · `forbidden_files[]` · `context_summary`
(orchestrator-authored prose) · `relevant_snippets[]` (clipped, secret-scrubbed excerpts with file+line refs)
· `expected_output_type` (`unified_diff` | `instructions` | `analysis`) · `security_constraints` (must
include "no secrets; no command execution; no direct repo mutation") · `verification_hints` (tests/commands
the orchestrator will run) · `model_target` (e.g. `glm-5.2`) · `max_context_tokens` / `token_budget` ·
`timeout_seconds` / `cancellation_policy`. PLUS a **`provider_target`** object:
`provider_target.type` (`mock` | `api_key` | `oauth_cli` | `manual_import`) · `provider_target.provider`
· `provider_target.model` · `provider_target.execution_mode` (always `proposal_only`) ·
`provider_target.credential_policy` (always `no_credentials_in_repo`) · `provider_target.secret_policy`
(always `no_secret_context`). Task files live at `.harness/workers/tasks/<task_id>.json`.

### 2. Worker Result Schema (`WORKER_RESULT_SCHEMA.md`)
Fields: `task_id` · `summary` · `files_considered[]` · `files_changed[]` (paths the patch actually
touches) · `proposed_patch` (unified diff TEXT) OR `instructions` · `risks[]` · `assumptions[]` ·
`test_suggestions[]` · `confidence` (0–1 or low/med/high)
· `unresolved_questions[]` · `no_direct_mutation: true` (a required attestation). PLUS a
**`provider_metadata`** object: `provider_metadata.provider_type` · `provider_metadata.provider` ·
`provider_metadata.model_claimed` · `provider_metadata.generated_at` · `provider_metadata.invocation_id`
· `provider_metadata.credential_exposure` (always `none`). Result files live at
`.harness/workers/results/<task_id>.json`. The patch is TEXT — it is NOT applied by the worker or by import.

### 3. Worker Lifecycle
`create task` (`/dmc-worker-plan`) → `dispatch` (`/dmc-worker-dispatch` → mock/hand-run, writes result)
→ `receive/import` (`/dmc-worker-import` validates the result vs schema + security) → `orchestrator review`
(`/dmc-worker-review`) → optional `critic` (`/dmc-critic`) → `apply manually through the DMC scope gate`
(orchestrator opens a scoped run via `/dmc-start-work` and **translates the proposal into scope-guarded
`Edit`/`Write` operations** within `current-scope.txt` — NEVER `git apply`/`patch`) →
`verify` (`/dmc-verify-hard`) → `evidence`. At every step the result can be REJECTED with zero repo changes.

### 4. Commands / Skills
- `/dmc-worker-plan <objective>` — author a task JSON (scope: allowed/forbidden files, budgets).
- `/dmc-worker-dispatch <task_id>` — run `worker-context-guard.sh`, package the bundle, hand to a worker/mock; record a session under `.harness/workers/sessions/`. (No live API in v0.2.)
- `/dmc-worker-import <task_id>` — load a result JSON, validate against `WORKER_RESULT_SCHEMA`, run security/leakage checks.
- `/dmc-worker-review <task_id>` — orchestrator (and optional critic) assess the proposal; write a `WORKER_REVIEW_SCHEMA` record; decide apply/reject.
- `/dmc-worker-status` — list tasks/results/reviews and their states.
- `/dmc-worker-cancel <task_id>` — mark a task cancelled/expired (cancellation policy).

### 5. Storage Layout
```
.harness/workers/tasks/<task_id>.json
.harness/workers/results/<task_id>.json
.harness/workers/reviews/<task_id>.json
.harness/workers/sessions/<task_id>/...   (transient dispatch state)
```
Committed vs local-only: `sessions/` always local-only/transient (gitignored). `tasks/`, `results/`,
`reviews/` default **local-only** in host repos (they embed code context) per the v0.1.3 artifact policy;
in the DMC repo, only sanitized **example/mock** task+result are committed as contract fixtures.

### 6. Model Routing Policy
- Claude/Codex = orchestrator (planning, review, apply, verify, evidence).
- GLM 5.2 = bounded coding-subtask proposer (one task, one result).
- No worker receives secrets, `.env*` contents, or broad repo context by default — **clipped context only**
  (just `relevant_snippets` + `context_summary`, bounded by `max_context_tokens`).

### 7. Security Constraints
- `secret-guard`'s path detector runs in `worker-context-guard.sh` BEFORE packaging: any `allowed_files`/`relevant_snippets` resolving to a secret-bearing path is excluded and the dispatch fails closed.
- **Secret-detector drift note (non-blocking implementation requirement):** `worker-context-guard.sh` must NOT duplicate secret-path logic in a way that can drift from `secret-guard.sh`. Preferred future-safe design: extract a **shared helper `.claude/hooks/lib/secret-paths.sh`** sourced by BOTH `secret-guard.sh` and `worker-context-guard.sh`. If v0.2 does not extract the helper, it MUST include an identity/md5-style verification that the worker-context guard's secret patterns match `secret-guard.sh`'s patterns. This is drift-prevention only — NOT a new credential or provider feature.
- The context builder excludes secret-bearing paths and redacts inline secret-looking values.
- Worker output must NOT execute commands; the result is data only (the orchestrator decides).
- Worker must NOT push/commit/write directly — it has no such access; `no_direct_mutation: true` is attested and re-checked.
- Worker must NOT alter lockfiles/dependencies unless `allowed_files` explicitly lists them.

### 8. Verification Requirements
- Task + result validate against their schemas.
- No forbidden-path leakage: `result.files_considered ⊆ task.allowed_files`; nothing in `forbidden_files`; the proposed patch touches only allowed files.
- No secret content in task or result (scan task bundle + result for secret patterns / `.env*` inclusions).
- A worker result can be rejected with zero repo changes (reject path tested).
- Any orchestrator-applied patch passes the full DMC verification (scope-guard during apply + `/dmc-verify-hard`).

### 9. Mock-driven acceptance
v0.2 is validated with a hand-authored **mock result** (`.harness/workers/results/<mock>.json`) flowing
through import → review → (scoped) apply → verify — proving the contract and security boundaries without
any live model.

## Provider Access Layer

DMC Worker Bridge must NOT assume every worker is reached via a direct API key. Future workers may
be accessed through a **mock provider**, an **API-key provider**, a **subscription OAuth / local CLI
provider**, or a **manual paste/import provider**. v0.2 defines the access *contract*; it implements
none of the live adapters.

### Resolved design
1. **v0.2 remains mock-only.** No live API calls, no OAuth implementation, no credentials, no external
   provider integration.
2. **v0.2 defines provider access contracts for future versions** (the `provider_target` /
   `provider_metadata` schema fields above), so later adapters slot in without changing the core loop.

### Provider types
`mock` · `api_key` · `oauth_cli` · `manual_import`.

### API-key provider principles
- API keys MUST never be committed.
- API keys MUST NOT appear in worker tasks/results/evidence.
- API keys are read only from approved local secret storage or environment **at execution time in
  future versions**.
- **Not implemented in v0.2.**

### Subscription OAuth / local CLI provider principles
- DMC MUST NOT read, store, export, or inspect OAuth tokens.
- DMC MUST NOT read provider session files.
- DMC MUST NOT handle refresh tokens.
- OAuth/session state remains owned by the provider CLI/app/keychain.
- DMC may only call an **approved local command adapter** in future versions; DMC receives **structured
  worker output only**.
- No background daemon or CI use by default.
- Use only when provider terms and product behavior allow automation.
- **Not implemented in v0.2.**

### Manual import provider principles
- The user may paste or import a worker result manually.
- The result MUST still pass `WORKER_RESULT_SCHEMA` validation.
- No direct repo mutation.

### Security requirements (Provider Access Layer)
- No worker task may include secrets, `.env*` contents, credentials, OAuth tokens, API keys, provider
  session files, or production config.
- Provider adapters MUST run **after** `worker-context-guard.sh`.
- Worker output CANNOT be auto-applied.
- The orchestrator must review and apply through the existing DMC scope / security / verification /
  evidence gates.

### Out of scope for v0.2 (Provider Access Layer)
GLM live API adapter · Subscription OAuth adapter · OAuth login flow · credential storage · provider
CLI integration · background worker execution · auto-apply · cost/quota optimization.

### Future version notes
- **v0.2.1** may add an API-key-based GLM adapter.
- **v0.2.2** may add an OAuth / local-CLI provider adapter, if officially supported and safe.
- **v0.3** may add multi-worker orchestration after provider adapters are proven.

## Acceptance Criteria

- Criterion: Task + Result + Review schemas exist and a sample task/result validate against them, INCLUDING `provider_target` (type ∈ {mock,api_key,oauth_cli,manual_import}, `execution_mode=proposal_only`, `credential_policy=no_credentials_in_repo`, `secret_policy=no_secret_context`) and `provider_metadata` (`credential_exposure=none`).
  Verification Method: JSON-Schema-style validation (or a python validator) over the mock task/result → valid; assert the provider invariants; a task with `secret_policy` other than `no_secret_context` or a result with `credential_exposure != none` → FAIL.
- Criterion: provider fields never carry credentials/tokens; v0.2 dispatch is mock/manual only.
  Verification Method: scan task `provider_target` + result `provider_metadata` for key/token/url patterns → none; `provider_target.type` is `mock` or `manual_import` for every v0.2 fixture.
- Criterion: `worker-context-guard.sh` excludes secret-bearing paths and fails closed.
  Verification Method: feed a task whose `allowed_files`/snippets include `/x/.env.local` → guard rejects/strips it (synthetic path; no secret read).
- Criterion: No forbidden-path leakage in a result.
  Verification Method: mock result with a `files_considered`/patch path outside `allowed_files` or inside `forbidden_files` → import flags it FAIL.
- Criterion: Disallowed patch categories are rejected by default (binary, lockfile, dependency upgrade, DB/schema/migration, secret/config/`.env`).
  Verification Method: mock results whose `proposed_patch` touches a lockfile / `*.lock` / `package.json` deps / a `migrations/` or `drizzle` path / a `.env*` / binary diff → import flags FAIL unless `allowed_files` explicitly lists the path AND the orchestrator approves; `files_changed` must equal the paths in the diff.
- Criterion: No secret content in task or result.
  Verification Method: scan mock task + result for secret patterns / `.env*` paths → none; a planted `.env` reference is caught.
- Criterion: A worker result can be REJECTED with zero repo changes.
  Verification Method: run review→reject on the mock; `git status` shows no source changes.
- Criterion: An accepted change is applied ONLY by translating it into scope-guarded `Edit`/`Write` operations and passes verification (Option A). v0.2 forbids Bash-based patch application (`git apply`/`patch`) for worker results; worker diffs are proposals, not executable patches.
  Verification Method: apply the mock change as `Edit`/`Write` within a `/dmc-start-work` scope + `/dmc-verify-hard` → **scope-guard denies any `Edit`/`Write` to a file outside the approved scope** (out-of-scope Edit blocked). `git apply` is NOT relied on (and is forbidden).
- Criterion: A worker result containing an out-of-scope diff is REJECTED before any application; no repo changes occur at import/review time.
  Verification Method: mock result whose `files_changed`/diff paths fall outside `allowed_files` → import/review flags REJECT and `git status --short` shows no changes; if the orchestrator nonetheless tried an out-of-scope `Edit`, scope-guard denies it.
- Criterion: Diff/metadata consistency holds at import/review (before any human application).
  Verification Method: `files_changed` equals the diff's touched paths; touched paths ⊆ `allowed_files`; touched paths ∩ `forbidden_files` = ∅; touched paths include no disallowed category (`.env*`, lockfiles, dependency files, DB/schema/migration, binary, production config) unless explicitly allowed+approved. A violating mock → REJECT.
- Criterion: No v0.2 skill or script applies worker results via `git apply`/`patch`.
  Verification Method: `grep -rnE 'git[[:space:]]+apply|(^|[^a-z])patch[[:space:]]+-' .claude/skills/dmc-worker* .claude/hooks/worker-*` → none (worker diffs are review artifacts only).
- Criterion: Workers cannot mutate the repo (no fs/git/shell access in the contract).
  Verification Method: contract review + the bridge passes only JSON; `no_direct_mutation: true` attested and re-validated.
- Criterion: Existing guards unchanged.
  Verification Method: `git diff` shows no change to `secret-guard.sh`/`scope-guard.sh`/`pre-tool-guard.sh`/`stop-verify-gate.sh`; v0.1.x regression suite passes.
- Criterion: No GLM credentials / no live API call introduced.
  Verification Method: `grep -riE 'api[_-]?key|GLM_.*KEY|http(s)?://' .claude/skills/dmc-worker* .claude/hooks/worker-*` → none; dispatch targets mock/hand-run only.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Secret leakage into a worker task bundle | high | `worker-context-guard.sh` reuses secret-guard's path detector + redaction; fail-closed; no broad context; verification scans task+result. |
| Worker proposes an out-of-scope / forbidden-file patch | high | Import checks `files_considered`/patch paths ⊆ `allowed_files`; apply only via scope-guard; out-of-scope edits blocked. |
| A "proposed patch" gets auto-applied | high | No auto-apply (out of scope); apply is a manual, scope-gated, verified orchestrator step. |
| Scope creep into live GLM integration / credentials | med | v0.2 mock-only; live dispatch adapter is a later increment; no credentials added. |
| Worker output tries to embed shell/command execution | med | Result is data-only; orchestrator never executes worker-provided commands; schema forbids an "execute" field. |
| Worker artifacts (code context) committed into a host repo | med | tasks/results/reviews default local-only (host); sessions always local-only; only sanitized fixtures committed in DMC repo. |
| Existing guards weakened to fit the bridge | high | Guards are REUSED read-only; acceptance asserts they are byte-unchanged. |
| Ad-hoc manual `git apply` outside the Worker Bridge flow is not hook-enforced (no patch-content hook in v0.2) | med (accepted residual) | v0.2 forbids `git apply`/`patch` for worker results (Decision #4); worker diffs are review artifacts only; application goes through scope-guarded `Edit`/`Write`; the no-`git apply` check verifies skills/scripts are clean. **Accepted residual for the mock-only v0.2 release.** A future **Option-B diff-path pre-apply gate** may make `git apply` safe later, but it is explicitly OUT OF SCOPE for v0.2. |

## Rollback Path

### Pre-commit (DMC repo)
- `git restore .gitignore INSTALL_MANIFEST.md DMC.md CLAUDE.md`
- `rm -f WORKER_TASK_SCHEMA.md WORKER_RESULT_SCHEMA.md WORKER_REVIEW_SCHEMA.md .claude/hooks/worker-context-guard.sh`
- `rm -rf .claude/skills/dmc-worker-* .harness/workers/`
### Post-commit
- `git revert <v0.2-commit-sha>`; re-run the v0.1.x regression suite (guards + secret boundary intact).
Worker Bridge adds only new files + additive doc/gitignore/manifest edits; existing guards untouched, so rollback is clean.

## Verification Commands

| Command | Reason | Required |
|---|---|---|
| validate mock task/result vs schemas (python validator) | schema conformance | yes |
| context-guard on task with `/x/.env.local` in allowed_files → excluded/fail-closed | secret exclusion (synthetic) | yes |
| import mock result with out-of-scope patch path → FAIL flagged | forbidden-path leakage | yes |
| scan mock task+result for secret patterns / `.env*` → none; planted ref caught | no secret content | yes |
| review→reject mock; `git status --short` → no source changes | rejectable without mutation | yes |
| apply mock change as `Edit`/`Write` via `/dmc-start-work` scope + `/dmc-verify-hard`; an out-of-scope `Edit` is denied by scope-guard | scope-guarded apply (Option A) + verify | yes |
| mock result with `files_changed` outside `allowed_files` → import/review REJECTS; `git status --short` unchanged | out-of-scope diff rejected before apply, no mutation | yes |
| `grep -rnE 'git[[:space:]]+apply\|patch[[:space:]]+-' .claude/skills/dmc-worker* .claude/hooks/worker-*` → none | no Bash-based patch application of worker results | yes |
| consistency: `files_changed` == diff touched paths; ⊆ `allowed_files`; ∩ `forbidden_files` = ∅; no disallowed category | diff/metadata consistency at import/review | yes |
| `git diff` of the 4 existing guard hooks → empty | guards unchanged | yes |
| `grep -riE 'api[_-]?key|GLM_.*KEY|https?://' .claude/skills/dmc-worker* .claude/hooks/worker-*` → none | no credentials / live API | yes |

## PASS / PARTIAL / FAIL

- **PASS**: task/result/review schemas exist and validate; the local workflow (plan→dispatch(mock)→import→review→scope-gated apply→verify→evidence) runs end-to-end with a **mocked** worker result; security boundaries hold (secret exclusion fail-closed, no forbidden-path leakage, no secret content, no command execution, no direct mutation); a result is rejectable with zero repo changes; an applied patch passes DMC verification; existing guards byte-unchanged; no credentials / live API.
- **PARTIAL**: schemas exist but the dispatch/import/review loop is incomplete, OR the mock end-to-end runs but one security check (e.g. redaction) is deferred — documented.
- **FAIL**: a worker can mutate the repo directly, OR secrets can leak into a task/result, OR scope/security gates are bypassed, OR a patch can auto-apply, OR an existing guard is weakened.

## Assumptions

| Assumption | Confidence | How to Verify |
|---|---|---|
| **Open — v0.2 is mock-only; live GLM dispatch is a later increment.** | high (per constraints) | Confirm at approval; no credentials this release. |
| Worker artifacts default local-only (host); committed only as sanitized fixtures (DMC repo) | medium | Confirm at approval; encoded in `.gitignore` + manifest. |
| Reusing secret-guard's detector in the context builder is sufficient secret exclusion | high | Same patterns; add redaction for inline values. |
| Proposed patch as unified-diff TEXT is the right interchange (vs structured edits) | medium | Confirm at approval; diff is git-applyable and human-reviewable. |
| Apply step routes through existing `/dmc-start-work` scope gate (no new apply path) | high | Reuses scope-guard; no new mutation surface. |

## Execution Tasks

- [ ] DMC-T001: Author `WORKER_TASK_SCHEMA.md`, `WORKER_RESULT_SCHEMA.md`, `WORKER_REVIEW_SCHEMA.md`.
- [ ] DMC-T002: Create `.harness/workers/{tasks,results,reviews,sessions}/` (+.gitkeep); `.gitignore` worker rules.
- [ ] DMC-T003: `worker-context-guard.sh` (reuse secret-guard detector; fail-closed; redaction).
- [ ] DMC-T004: Six `/dmc-worker-*` skills (plan/dispatch/import/review/status/cancel) — mock-targeted dispatch.
- [ ] DMC-T005: A mock task + mock result fixture; run the full local loop incl. scope-gated apply + verify.
- [ ] DMC-T006: Update `INSTALL_MANIFEST.md`, `DMC.md`, `CLAUDE.md` (Worker Bridge contract + no-mutation rule).
- [ ] DMC-T007: Verification (schemas, security, leakage, reject path, apply+verify, guards unchanged, no credentials) + evidence + report.

## Approval Status

Status: APPROVED
Approver: 대표님
Approved At: 2026-06-19
