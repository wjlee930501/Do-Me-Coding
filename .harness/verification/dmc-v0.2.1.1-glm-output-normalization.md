# Verification Report

## Run ID

dmc-v0.2.1.1-glm-output-normalization

## Plan

`.harness/plans/dmc-v0.2.1.1-glm-output-normalization.md` (APPROVED 2026-06-21, Approver: 대표님) — adapter-only, mock-first, no live call.

## Changed Files

Modified:
- `.claude/workers/providers/glm-api/glm-api-adapter.py` — added `normalize_response()` (+ helpers `_strip_code_fence`, `_first_json_object`, `_parse_content`) and `MAX_CONTENT_LEN`/`CONFIDENCE_VALUES`; wired `normalize_response` before `map_to_result`; added a JSON-only system message to the live request body. `map_to_result` unchanged (still stamps `no_direct_mutation=True` / `credential_exposure="none"`).

New fixtures (`.claude/workers/providers/glm-api/fixtures/`):
- `glm-response-success-choices.json` — live envelope, `content` = bare JSON object.
- `glm-response-fenced-json.json` (C1) — leading prose + ```` ```json ```` fence around the object.
- `glm-response-empty-choices.json` (C2) — `choices: []`.
- `glm-response-missing-choices.json` (C2) — no `choices` key (mock pass-through path).
- `glm-response-malformed-content.json` — non-JSON / unbalanced fragment.
- `glm-response-empty-content.json` — `content` = "".
- `glm-response-bad-scope-choices.json` — parsed `files_changed` out of scope.
- `glm-response-disallowed-category.json` — parsed patch touches `package-lock.json` (lockfile).
- `glm-response-override-attempt.json` — `content` claims `credential_exposure="leaked"` / `no_direct_mutation=false`.
- `glm-response-nonstop-finish.json` — valid JSON but `finish_reason="length"`.
- `glm-response-overlong-content.json` — 10000-char content (> cap 8000).

New evidence:
- `.harness/evidence/dmc-v0.2.1.1-verify.sh` — mock-only verification harness.

Unchanged (verified byte-identical, see below): all `.claude/hooks/*` (validators/guards), `WORKER_*_SCHEMA.md`, `dmc-glm-smoke`.

## Commands Run

| Command | Result | Reason |
|---|---|---|
| `python3 -m py_compile glm-api-adapter.py` | PASS | syntax |
| `bash .harness/evidence/dmc-v0.2.1.1-verify.sh` | **15 PASS / 0 FAIL** | full mock-only suite (NO network) |
| direct validator check on disallowed-category vs lock-allowing task | PASS | `REJECT — disallowed category [lockfile]: package-lock.json` (isolated: file IS in allowed_files, so out-of-scope is not the cause) |
| `git diff --name-only .claude/hooks/ WORKER_*_SCHEMA.md dmc-glm-smoke` | empty | guards/schemas/smoke-runner byte-unchanged |

## Acceptance Criteria — Evidence

| Criterion | Result | Evidence |
|---|---|---|
| Top-level mock backward compatible (no `choices` → pass-through) | PASS | `glm-response-mock.json` → populated summary + ACCEPT |
| `choices[0].message.content` bare JSON populates summary/files_changed/proposed_patch/confidence | PASS | success-choices → `files_changed=['src/setNames.ts']`, summary+patch present, ACCEPT |
| **C1** fenced JSON (prose + fence) populates structured fields | PASS | fenced-json → SAME structured fields, ACCEPT (naive `json.loads` would fail) |
| **C2** empty `choices []` → graceful low-confidence empty, no crash | PASS | exit 0, `files_changed=[]`, `confidence=low`, ACCEPT |
| **C2** missing `choices` key → graceful empty, no crash | PASS | exit 0, `files_changed=[]`, ACCEPT (pass-through branch) |
| Malformed / non-JSON → plain-text fallback to instructions | PASS | `files_changed=[]`, instructions populated, `confidence=low`, ACCEPT |
| Empty content → empty-but-valid | PASS | exit 0, ACCEPT |
| Non-`stop` `finish_reason` → fallback, lower confidence | PASS | nonstop (`length`) → `confidence=low`, `files_changed=[]`, ACCEPT |
| Over-long content bounded | PASS | instructions length 8000 ≤ cap 8000, no crash, ACCEPT |
| Adversarial out-of-scope output → validator REJECT | PASS | bad-scope-choices → REJECT |
| Disallowed-category (lockfile) output → validator REJECT | PASS | `disallowed category [lockfile]` REJECT |
| Adapter-enforced fields not overridable by model | PASS | override-attempt → `credential_exposure=none`, `no_direct_mutation=True`, no `leaked` string in result, ACCEPT |
| `json.loads` only — no eval/exec | PASS | `grep -nE '\beval\(|\bexec\('` → none |
| Schemas/guards/validators/smoke-runner byte-unchanged | PASS | `git diff --name-only` empty |
| No live call in build verification | PASS | every check uses `--mock`; no network |

## Scope Review

Result: PASS. Edits confined to the approved scope (`.claude/workers/providers/glm-api/` adapter + fixtures) plus harness/verification/evidence under `.harness/`. No schema/hook/validator/guard/smoke-runner change. No pokeprice or product-source change.

## Package / Env / Migration Review

Package files changed: no. Env files changed: no — no credentials added; `GLM_API_KEY` not read/printed during build (mock-only). Migration files changed: no.

## Safety Posture

- No live GLM call (mock-only). No `.env*` read/exposure. `GLM_API_KEY` never printed/logged/serialized.
- No `git apply`, no auto-apply of worker output. Worker output remains a proposal validated by `worker-result-check.py`.
- Adapter never reads `credential_exposure`/`no_direct_mutation` from model content; `map_to_result` stamps `none`/`True`.
- The validator remains the load-bearing safety net and still REJECTs out-of-scope / disallowed-category / secret / `files_changed != diff` results (proven against the live-shaped normalized output).

## Notes / Known Nuances

- Shape detection keys on presence of `choices`. A response missing `choices` entirely is indistinguishable from a top-level mock, so it takes the pass-through branch → graceful empty result (`confidence` from `map_to_result` default, not forced `low`), still no crash / ACCEPT. The `choices: []` case takes the live envelope-guard branch and yields the explicit `confidence=low`. Both are safe; documented here for transparency.
- `MAX_CONTENT_LEN = 8000` chars is the documented bound; the JSON happy path for reasonably-sized objects is far under it.

## Final Status

**PASS** — 15/15 mock checks pass; C1 and C2 fully exercised; validator gating and adapter-enforced fields confirmed; guards/schemas/smoke-runner byte-unchanged; no live call. Stopped before commit per instruction.
