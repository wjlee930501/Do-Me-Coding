# Do-Me-Coding v0.2.1 — GLM API Adapter (first live provider, mock-first)

## Goal

Plan the first LIVE Worker Bridge provider adapter: `glm-api` (provider type `api_key`, model GLM 5.2
or configurable). It maps a sanitized DMC worker task → a GLM request → a `WORKER_RESULT_SCHEMA`
result. v0.2.1 is **mock-first**: the adapter is built and verified against a **fake provider response
fixture** with NO network call at the approval/build stage. The Worker Bridge invariants from v0.2 hold
unchanged: workers propose only, never mutate the repo, no `git apply`, application goes through the
DMC scope/security/verification/evidence gates.

## User Intent

feature

## Version Boundary

- **v0.2.1** = API-key GLM adapter (this plan).
- **v0.2.2** = OAuth / local-CLI adapter (NOT here).
- **v0.3** = multi-worker orchestration (NOT here).

## Resolved Decisions (pre-critic)

1. **Credential source (env vars; named, never set).** `GLM_API_KEY` (required for future live mode);
   optional `GLM_API_BASE` (provider base URL), `GLM_MODEL` (model override), `GLM_API_TIMEOUT_SECONDS`
   (timeout). Presence checks are **non-printing**; keys are NEVER serialized into worker
   tasks/results/evidence/logs or anything under `.harness/`. A missing key returns a clear error WITHOUT
   printing the value.
2. **Adapter language & home (Python).** Source (committed): `.claude/workers/providers/glm-api/` —
   `glm-api-adapter.py`, `README.md`, `CONFIG.md`, `fixtures/`. Runtime/local-only data:
   `.harness/workers/providers/glm-api/`. `.claude/workers/providers/` is the committed adapter source;
   `.harness/workers/providers/` is local-only runtime state.
3. **Mock-first PASS.** v0.2.1 reaches PASS with NO live GLM network call. Load-bearing verification is
   mock/stub based: sanitized task-payload fixture → fake GLM response fixture →
   response-to-`WORKER_RESULT_SCHEMA` mapping → `worker-result-check` validation → no-secret-payload
   validation → no-repo-mutation validation. No live network call required for build/CI/release verification.
4. **Live mode policy.** A `--live` path ships in v0.2.1 but is **strongly opt-in and unexercised by
   CI/build**. Default mode is `--mock` / no-network. Live execution requires the PRIMARY gates: explicit
   `--live`; explicit `--allow-network` (or equivalent confirmation); `GLM_API_KEY` present; and a
   `worker-context-guard`-approved payload. A "not in CI" check is **best-effort defense-in-depth ONLY and
   must never be the sole live-mode guard.** Live mode must not print credentials, must send only
   context-guard-approved payloads, and must return structured output validated before import. A
   real GLM smoke test is a SEPARATE manual step AFTER v0.2.1 build verification — not a PASS requirement.
5. **Schema frozen by default.** Keep `WORKER_TASK_SCHEMA.md` and `WORKER_RESULT_SCHEMA.md` unchanged
   (`provider_target.type=api_key` already exists). If implementation discovers a genuinely missing field,
   any change must be **additive only and separately justified** — never a provider-specific convenience tweak.
6. **OAuth boundary.** Subscription OAuth / local-CLI provider is **OUT of scope for v0.2.1** (planned for
   v0.2.2 or later). Do NOT mix OAuth/session/token handling into the GLM API adapter.
7. **No mutation / no apply (reaffirmed from v0.2).** The adapter does not mutate the repo; no `git apply`,
   no patch application, no auto-apply; the worker result is proposal-only. Application, if any, happens
   later through the DMC scope/security/verification/evidence gates (Option A: Edit/Write under scope-guard).

## Current Repo Findings

- Finding: `WORKER_TASK_SCHEMA.md` already supports `provider_target.type=api_key`; no schema change is strictly required (provider_metadata already has `credential_exposure=none`).
  Source: `grep api_key WORKER_TASK_SCHEMA.md`.
- Finding: Reusable safety components are committed: `worker-context-guard.sh` (fail-closed task-bundle secret guard), `worker-result-check.py` (result validator), `lib/secret-paths.sh` (shared detector). The adapter REUSES these — it does not re-implement secret logic.
  Source: `.claude/hooks/worker-*`, `lib/secret-paths.sh` (commit `166d0ee`).
- Finding: `.claude/workers/` does not exist yet; v0.2.1 introduces `.claude/workers/providers/glm-api/` for adapter code and `.harness/workers/providers/glm-api/` for local-only data.
  Source: `ls .claude/workers` → absent.
- Finding: v0.2 host artifact policy makes worker tasks/results/sessions local-only in host repos; live provider responses (which may embed private context) must follow the same (or stricter) policy.
  Source: `docs/HOST_REPO_ARTIFACT_POLICY.md`.

## Relevant Files

| Path | Reason | Allowed to Edit (future approved run) |
|---|---|---|
| `.claude/workers/providers/glm-api/README.md` | NEW — adapter overview, usage, safety | yes (new) |
| `.claude/workers/providers/glm-api/glm-api-adapter.py` | NEW — adapter (mock + live modes; reads key from env only) | yes (new) |
| `.claude/workers/providers/glm-api/CONFIG.md` | NEW — env var name, model config, no secrets | yes (new) |
| `.claude/workers/providers/glm-api/fixtures/glm-response-mock.json` | NEW — fake provider response fixture (sanitized) | yes (new) |
| `.harness/workers/providers/glm-api/` | NEW — local-only adapter runtime data (gitignored) | yes (new) |
| `.gitignore` | add `.harness/workers/providers/` local-only rule | yes |
| `INSTALL_MANIFEST.md` | add the adapter to the install surface | yes |
| `DMC.md`, `CLAUDE.md` | document the glm-api adapter + credential policy | yes |
| `WORKER_TASK_SCHEMA.md` / `WORKER_RESULT_SCHEMA.md` | edit ONLY if necessary (expected: no change) | yes (if needed) |
| `.claude/hooks/{worker-context-guard.sh,worker-result-check.py,lib/secret-paths.sh}` | read-only — REUSED, not modified (no guard weakening) | no |
| `.claude/skills/dmc-worker-dispatch/SKILL.md` | read-only this release unless a one-line `glm-api` pointer is added | no (unless needed) |

## 1. Provider Adapter Boundary

- Adapter name: **`glm-api`**. Provider type: **`api_key`**. Model target: **GLM 5.2** (configurable via `CONFIG.md` / env, e.g. `GLM_MODEL`).
- `execution_mode = proposal_only`; **no direct repo mutation; no auto-apply**.
- The adapter's OUTPUT must conform to `WORKER_RESULT_SCHEMA.md` (validated by `worker-result-check.py` at import).
- The adapter is a pure transform: sanitized task JSON IN → GLM request → GLM response → result JSON OUT. It has no fs-write/git/shell access to the repo.

## 2. Credential Policy

- **No API keys in the repo**, in worker tasks/results/evidence, in logs, or anywhere under `.harness/`.
- The future implementation reads the key ONLY from an approved local secret source or environment
  variable. **Env vars (named, NOT set here): `GLM_API_KEY`** (required for live); optional `GLM_API_BASE`,
  `GLM_MODEL`, `GLM_API_TIMEOUT_SECONDS`.
- **Key presence check must be non-printing:** e.g. `[ -n "${GLM_API_KEY:-}" ]` / `os.environ.get("GLM_API_KEY")`
  — never echo, log, or write the value. Missing key → a clear error that does NOT print any secret.
- The key is never serialized into the request log, the result, the session record, or evidence. Only a
  boolean "key present" and a non-secret `invocation_id` may be recorded.
- **Authorization logging:** any live request log MUST omit or redact the `Authorization` header (the key
  lives in the header, not the payload). The API key must NEVER appear in logs, task JSON, result JSON,
  evidence, or raw provider logs. Raw provider responses, if stored at all, are **local-only and redacted by
  default** under `.harness/workers/providers/glm-api/` (gitignored).

## 3. Dispatch Flow (future; designed here)

1. DMC produces the task JSON (`/dmc-worker-plan`). `provider_target.type=api_key`, `provider=glm-api`, `model=glm-5.2`.
2. `/dmc-worker-dispatch glm-api <task_id>` runs **`worker-context-guard.sh` FIRST** (fail-closed): no
   secret-bearing path in the bundle; clipped, explicit context only.
3. The adapter builds a **sanitized request payload** from the validated task — objective, `context_summary`,
   the `relevant_snippets` (validated by `worker-context-guard`; unsafe snippets are **rejected fail-closed,
   not redacted**), and the allowed/forbidden file **name lists** (no file contents beyond the clipped
   snippets). **Security model: reject unsafe context, do not rely on after-the-fact redaction.** The payload
   builder MUST itself assert the final payload is secret-free (re-check, not assume snippets are sanitized);
   NO secrets, NO `.env*`, NO broad repo context.
4. (Live mode, opt-in, key required) the adapter calls GLM and receives a response. (v0.2.1 build/verify uses the MOCK fixture, no network.)
5. The adapter maps the response → `WORKER_RESULT_SCHEMA` (incl. `files_changed`, `no_direct_mutation=true`, `provider_metadata.credential_exposure=none`) and writes `.harness/workers/results/<task_id>.json`.
6. `/dmc-worker-import` runs `worker-result-check.py` (schema + scope + consistency + disallowed-category + no-secret). Failures REJECT with zero repo changes.

## 4. Storage

- Live provider tasks/results remain **local-only by default** (gitignored). `.harness/workers/providers/glm-api/`
  (raw request/response logs, redacted) is **always local-only**. Sessions always local-only.
- **No raw provider response with private context is committed by default.** Only a **sanitized example**
  (the mock fixture) is committed in the DMC repo as a contract example.
- Add `.harness/workers/providers/` to the DMC `.gitignore` and the installer's host `.gitignore` block.

## 5. Adapter Files (proposed)

- `.claude/workers/providers/glm-api/glm-api-adapter.py` — **default mode = `--mock`/no-network**. `--live`
  requires the PRIMARY gates: explicit `--live` + explicit `--allow-network` (or equivalent) + `GLM_API_KEY`
  present + a context-guard-approved payload. The **"not in CI" check is best-effort defense-in-depth ONLY —
  never the sole live-mode guard.** Reuses no secret logic of its own beyond calling the committed guards.
  Reads key via env only; non-printing presence check; key never serialized/logged.
- `.claude/workers/providers/glm-api/README.md`, `CONFIG.md` — usage, env var names (not values), model config, safety.
- `.claude/workers/providers/glm-api/fixtures/glm-response-mock.json` — sanitized fake response for mock-first tests.
- `.harness/workers/providers/glm-api/` — local-only runtime dir.

## 6. Safety Tests (acceptance)

- Missing `GLM_API_KEY` → clear error, **no secret printed** (and no value present to print).
- A fake key value is **never echoed/logged/written** (grep the adapter's outputs/logs → no key substring).
- Secret-bearing paths **cannot enter the request payload** (context-guard fail-closed; payload builder excludes them).
- `.env*` contents **cannot enter the request payload** (no file-content inclusion beyond clipped, scrubbed snippets).
- A worker result with `credential_exposure != none` → **rejected** (`worker-result-check.py`).
- A worker result touching out-of-scope files → **rejected**.
- **No repo mutation** during dispatch/import/review (`git status` unchanged).
- **No `git apply`/`patch`** application anywhere in the adapter or skills.

## 7. Mock-First Adapter Test

- Use `fixtures/glm-response-mock.json` (a fake GLM response) BEFORE any live call.
- Validate the mapping fake-response → `WORKER_RESULT_SCHEMA` (then `worker-result-check.py` ACCEPTs it for an in-scope mock task).
- **No network call at the v0.2.1 plan-approval / build-verification stage.** Live mode is a separate, key-gated, opt-in action exercised only by a user with a real key — not by the build/CI.

## Acceptance Criteria

- Criterion: Missing key handled non-printing. Verification: run adapter `--live` with `GLM_API_KEY` unset → clear error, exit non-zero, output contains no secret; `[ -n "${GLM_API_KEY:-}" ]` style check only.
- Criterion: No key value ever emitted. Verification: run mock mode with a fabricated `GLM_API_KEY=FAKE-do-not-use`; grep adapter stdout/stderr/logs/result/session → the fake value never appears.
- Criterion: Sanitized payload excludes secrets. Verification: a task with a secret path / `.env*` snippet is blocked by `worker-context-guard.sh` before the adapter builds a payload; the built payload contains no secret path/content.
- Criterion: Mock response → schema mapping valid. Verification: `glm-api-adapter.py --mock fixtures/glm-response-mock.json --task <mock-task>` → a `WORKER_RESULT_SCHEMA`-valid result; `worker-result-check.py` ACCEPTs it.
- Criterion: Unsafe results rejected. Verification: fixtures producing `credential_exposure!=none` / out-of-scope `files_changed` → `worker-result-check.py` REJECT.
- Criterion: Live mode is multi-gated and default-safe. Verification: default invocation runs `--mock`/no-network; `--live` WITHOUT `--allow-network`, or without `GLM_API_KEY`, or under a detected CI env → refuses with a clear non-secret error and makes NO network call. (No live call exercised in build/CI verification.)
- Criterion: No mutation / no git apply. Verification: `git status` unchanged after a full mock dispatch→import→review; `grep 'git apply'` in adapter/skills → none (or forbidding context only).
- Criterion: No credentials in repo/.harness/evidence. Verification: `grep -riE 'GLM_API_KEY=|sk-|api[_-]?key.*[:=]' .claude .harness` → only env-var NAME references, no values.
- Criterion: Existing guards + worker contract unchanged. Verification: `git diff` of the v0.2 guards/schemas/validator → empty (adapter is additive).

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| API key leaks into logs/results/evidence | high | Read from env only; non-printing presence check; key never serialized; grep-for-key test; raw logs local-only + redacted. |
| Secret/`.env*` context enters the GLM request payload | high | `worker-context-guard.sh` runs FIRST (fail-closed); payload builder includes only clipped, scrubbed snippets + file-name lists; acceptance test asserts no secret in payload. |
| A live call happens during build/CI | high | Mock-first; live mode is opt-in + key-gated; v0.2.1 verification uses the fixture only; no network at approval/build. |
| Adapter mutates the repo or applies a patch | high | Adapter is a pure transform (no fs-write/git); Option-A apply (Edit/Write via scope gate) unchanged; no `git apply`. |
| Raw provider response with private context committed | med | `.harness/workers/providers/` local-only; only the sanitized mock fixture committed. |
| Scope creep into OAuth/CLI/live-routing | med | Explicit out-of-scope; v0.2.2 boundary. |
| Existing guards weakened to fit the adapter | high | Guards REUSED read-only; acceptance asserts byte-unchanged. |

## Rollback Path

### Pre-commit (DMC repo)
- `git restore .gitignore INSTALL_MANIFEST.md DMC.md CLAUDE.md` (and worker schemas if touched)
- `rm -rf .claude/workers/providers/glm-api .harness/workers/providers`
### Post-commit
- `git revert <v0.2.1-commit-sha>`; re-run the v0.2 + v0.1.x regression (guards/contract intact).
Additive only (new adapter dir + doc/gitignore/manifest edits); existing guards/contract untouched → clean rollback.

## Verification Commands

| Command | Reason | Required |
|---|---|---|
| `GLM_API_KEY= .../glm-api-adapter.py --live ... 2>&1` → clear error, no secret, exit≠0 | non-printing missing-key error | yes |
| `GLM_API_KEY=FAKE-do-not-use .../glm-api-adapter.py --mock fixtures/glm-response-mock.json ...; grep -r 'FAKE-do-not-use' <outputs/logs/result/session>` → none | key value never emitted | yes |
| task with `.env*`/secret snippet → `worker-context-guard.sh` blocks; built payload has no secret | payload secret exclusion | yes |
| `glm-api-adapter.py --mock fixtures/glm-response-mock.json --task <mock> ` → result; `worker-result-check.py <task> <result>` → ACCEPT | mock mapping + schema | yes |
| adversarial mock fixtures (credential_exposure≠none / out-of-scope) → `worker-result-check.py` REJECT | unsafe-result rejection | yes |
| `git status --short` unchanged after mock dispatch→import→review; `grep -rnE 'git[[:space:]]+apply' .claude/workers .claude/skills/dmc-worker*` → none/forbidding | no mutation / no git apply | yes |
| `grep -riE 'GLM_API_KEY[[:space:]]*=[[:space:]]*[^$]|sk-[A-Za-z0-9]' .claude .harness` → none (only env NAME refs) | no credentials in repo | yes |
| `git diff` of v0.2 guards/schemas/validator → empty | guards/contract unchanged | yes |

## PASS / PARTIAL / FAIL

- **PASS**: the adapter contract, credential policy (env-only, non-printing), mock response→schema mapping,
  no-secret payload validation, and `WORKER_RESULT_SCHEMA` validation are implemented and verified **without
  exposing credentials** and **without any live call**; existing guards/contract byte-unchanged; no mutation; no `git apply`.
- **PARTIAL**: the adapter skeleton + mock mapping exist, but one live-safe validation is incomplete (e.g. payload-exclusion test or key-leak grep deferred) — documented.
- **FAIL**: credentials leak (key in repo/logs/result/evidence), the worker mutates the repo, secrets enter the
  payload/result/evidence, a live call is made at build stage, or scope/security gates are bypassed.

## Out of Scope (v0.2.1)

Subscription OAuth · local CLI provider · background daemon · CI automation · multi-worker orchestration ·
cost/quota optimization · auto-apply · direct GLM repo mutation. (No live GLM call, no credentials added in this plan.)

## Assumptions

| Assumption | Confidence | How to Verify |
|---|---|---|
| `provider_target=api_key` needs no schema change | high | Schema already lists `api_key`; mock fixture validates. |
| Env var `GLM_API_KEY` (+ optional `GLM_API_BASE`/`GLM_MODEL`) is the credential source | high (named, not set) | Documented in CONFIG.md; never set in repo. |
| Mock-first (no network at build/approval) is acceptable for v0.2.1 PASS | high | Constraints forbid GLM calls; fixture-based verification. |
| `.claude/workers/providers/` is the adapter home; `.harness/workers/providers/` is local-only data | medium | Confirm at approval; encoded in gitignore + manifest. |
| Reusing committed guards (no re-implementation) is sufficient | high | context-guard + result-check already cover secret/scope/consistency. |

## Execution Tasks

- [ ] DMC-T001: Author `glm-api/CONFIG.md` + `README.md` (env var names, model, safety; no secrets).
- [ ] DMC-T002: Implement `glm-api-adapter.py` — `--mock` (no network) + `--live` (opt-in, env-key, non-printing); sanitized payload builder reusing `worker-context-guard.sh`; response→`WORKER_RESULT_SCHEMA` mapping.
- [ ] DMC-T003: `fixtures/glm-response-mock.json` (+ adversarial fixtures for reject tests).
- [ ] DMC-T004: `.gitignore` + `INSTALL_MANIFEST.md` + installer host-ignore for `.harness/workers/providers/`; create local-only dir.
- [ ] DMC-T005: Update `DMC.md` + `CLAUDE.md` (glm-api adapter + credential policy + no-leak rule).
- [ ] DMC-T006: Verification (safety tests, mock mapping, no-credential grep, no-mutation, guards unchanged) + evidence + report. NO live call.

## Approval Status

Status: APPROVED
Approver: 대표님
Approved At: 2026-06-19
