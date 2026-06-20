# Do-Me-Coding v0.2.1.1 — GLM API Adapter Output Normalization

## Goal

Make the `glm-api` adapter extract a real GLM chat-completion's content
(`choices[0].message.content`) and normalize it into `WORKER_RESULT_SCHEMA` fields — so a successful
live response yields a populated, schema-valid result instead of empty fields. Adapter-only change;
mock-first behavior and every existing safety gate preserved; no schema/guard/validator change
unless proven necessary.

## User Intent

bugfix

## Current Repo Findings

- Finding: the v0.2.1 live smoke succeeded (HTTP 200, validator ACCEPT) but produced an **empty** result — `summary` blank, `files_changed: 0`, no patch.
  Source: `.harness/verification/dmc-v0.2.1-glm-api-adapter.md` + the live-smoke run (`./dmc-glm-smoke`).
- Finding: root cause — `glm-api-adapter.py`'s `map_to_result(task, resp)` reads top-level `resp.get("summary")` / `files_changed` / `proposed_patch`, but a live GLM chat completion puts the model's answer in `resp["choices"][0]["message"]["content"]` (a string), so those top-level keys are absent.
  Source: `.claude/workers/providers/glm-api/glm-api-adapter.py` (`live_call` returns the raw response; `map_to_result` reads top-level fields).
- Finding: MOCK fixtures are authored as already-structured top-level responses (summary/files_changed at top level), so the current mapping works for mocks — normalization must NOT break that path.
  Source: `.claude/workers/providers/glm-api/fixtures/glm-response-mock.json`.
- Finding: `worker-result-check.py` already validates the schema/scope/secret/consistency of whatever the adapter emits; if normalization yields an out-of-scope or unsafe result, the validator REJECTs — so it remains the safety net (no validator change needed).
  Source: `.claude/hooks/worker-result-check.py` (committed `166d0ee`).
- Finding: `WORKER_RESULT_SCHEMA.md` already has `summary`, `files_changed`, `proposed_patch`, `instructions`, `confidence` — no schema field is missing for normalization.
  Source: `WORKER_RESULT_SCHEMA.md`.

## Relevant Files

| Path | Reason | Allowed to Edit (future approved run) |
|---|---|---|
| `.claude/workers/providers/glm-api/glm-api-adapter.py` | add `normalize_response()`; request structured output; plain-text fallback | yes |
| `.claude/workers/providers/glm-api/fixtures/glm-response-success-choices.json` | NEW — live-shaped success fixture (choices[].message.content = JSON) | yes (new) |
| `.claude/workers/providers/glm-api/fixtures/glm-response-fenced-json.json` | NEW (C1) — content = JSON wrapped in a markdown code fence + prose | yes (new) |
| `.claude/workers/providers/glm-api/fixtures/glm-response-empty-choices.json` | NEW (C2) — `choices: []` / missing choices envelope | yes (new) |
| `.claude/workers/providers/glm-api/fixtures/glm-response-malformed-content.json` | NEW — non-JSON / partial content | yes (new) |
| `.claude/workers/providers/glm-api/fixtures/glm-response-empty-content.json` | NEW — empty content | yes (new) |
| `.claude/workers/providers/glm-api/fixtures/glm-response-{bad-scope-choices,disallowed-category,override-attempt,nonstop-finish,overlong-content}.json` | NEW (recommended) — adversarial / robustness fixtures | yes (new) |
| `.claude/workers/providers/glm-api/README.md` / `CONFIG.md` | note structured-output prompting (if needed) | yes (if needed) |
| `WORKER_RESULT_SCHEMA.md` | edit ONLY if a field is genuinely missing (expected: NO change) | yes (if proven) |
| `.claude/hooks/worker-result-check.py`, `worker-context-guard.sh`, guards | read-only — REUSED, not modified (validator stays the safety net) | no |
| `dmc-glm-smoke` | read-only — unchanged (smoke runner) | no |

## Out of Scope

- Any live GLM call during planning or build verification (mock-first; live only by explicit later approval).
- Schema changes (unless a field is genuinely missing — none expected).
- Guard/hook/validator changes (the validator already covers the normalized output).
- OAuth/local-CLI (v0.2.2), multi-worker (v0.3).
- Auto-apply, `git apply`, repo mutation by worker output.
- Credential handling changes (the key path is untouched; normalization is post-response).

## Proposed Changes

### 1. Current failure mode (from the successful live smoke)
`map_to_result` read top-level fields that live GLM responses don't have → schema-valid but empty
result (summary "", files_changed 0, no patch). Round-trip + safety proven; content extraction missing.

### 2. Expected GLM response shape (OpenAI-compatible chat completion)
```json
{ "id": "…", "model": "glm-4.x/glm-5.2", "choices": [
    { "index": 0, "message": { "role": "assistant", "content": "…" }, "finish_reason": "stop" } ],
  "usage": { … } }
```
The model's substantive output is the `content` string.

### 3. Mapping strategy — add `normalize_response(resp)` BEFORE `map_to_result`
- **Shape detection:** if `resp` has a `choices` key → treat as a live GLM response and run the
  **defensive content extraction** below. Else (mock fixture already top-level structured) → pass `resp`
  through unchanged (preserves mock-first).
- **Defensive envelope handling (C2) — must never raise on a malformed/empty live envelope.** Extract
  `content` through a guarded path; ANY of the following degrades to a graceful low-confidence empty/fallback
  result (`summary=""`/best-effort, `files_changed=[]`, `proposed_patch=""`, `confidence="low"`), NOT a crash:
  - `choices` missing, not a list, or empty (`[]`)
  - `choices[0]` missing or not a dict
  - `message` missing or not a dict
  - `content` missing, `null`, non-string, or empty/whitespace
  Implementation: read each level with `.get(...)` + type checks (never bare `resp["choices"][0]…`); wrap the
  whole extraction in a try/except that falls through to the empty/fallback result. No `IndexError`/`KeyError`/
  `TypeError` may escape.
- **Robust content parsing (C1) — `content` is parsed via extraction-then-`json.loads`, not raw `json.loads`.**
  Models commonly wrap JSON in a markdown code fence or add leading/trailing prose, so a naive `json.loads(content)`
  would throw and silently lose valid structured output. Parsing order:
  1. Strip surrounding whitespace.
  2. If the content is wrapped in a markdown code fence (```` ```json … ``` ```` or bare ```` ``` … ``` ````),
     strip the fence markers and parse the inner block.
  3. Else, isolate the **first balanced top-level `{ … }` object** (scan for the first `{`, track brace depth
     respecting JSON string literals/escapes, stop at the matching `}`) to drop leading/trailing prose.
  4. `parsed = json.loads(<isolated candidate>)` — `json.loads` ONLY, **never `eval`/`exec`**.
  - On a successful parse of a JSON **object** → map `summary`, `files_changed`, `proposed_patch`, `confidence`
    from `parsed` (each via `.get` with a safe default; `files_changed` only if it is a list of strings).
  - If no `{ … }` object can be isolated, or `json.loads` raises, or the parse is not a JSON object → **plain-text
    fallback** (§4). Falling back is the ONLY behavior when JSON cannot be isolated/parsed — never partial-trust a
    half-parsed string.
- **`finish_reason` awareness:** read `choices[0].get("finish_reason")`; when it is non-`stop`
  (e.g. `length`, `content_filter`) the content is likely truncated/partial — prefer the plain-text fallback over a
  half-structured parse and set `confidence="low"`.
- **Adapter-enforced fields (never from the model):** `credential_exposure = "none"`; `no_direct_mutation = True`;
  `provider_metadata.provider_type = "api_key"`, `provider = "glm-api"`, `model_claimed = resp.get("model")`,
  `invocation_id = resp.get("id") or "glm-<short>"`. These are stamped by the adapter, NOT trusted from the model.
- **Defense-in-depth:** the normalized result still flows through `worker-result-check.py`, which REJECTs any
  out-of-scope `files_changed`, disallowed category (`.env*`, lockfiles, …), inline secret, or
  `files_changed != diff paths`. The model cannot widen scope or inject secrets past the validator.

### 4. Plain-text (non-JSON) handling
- Request the model (in the live request body) to "return ONLY a JSON object with keys summary,
  files_changed, proposed_patch, confidence; no prose." This makes JSON the happy path.
- Fallback triggers when §3 extraction yields no isolable `{ … }` object, `json.loads` raises, the parse is not a
  JSON object, OR `finish_reason` is non-`stop`. In all of these: treat the whole `content` as analysis/instructions →
  `instructions = content` (clipped), `summary = first non-empty line` (clipped), `files_changed = []`,
  `proposed_patch = ""`, `confidence = "low"`. Still schema-valid and safe (empty file set, no patch).
- An empty/missing-content envelope (§3 C2) produces the same shape with `instructions=""` — graceful, no crash.
- Never `eval`/exec content; only `json.loads` on an isolated candidate. **Bound length:** clip `content`
  (and any derived `instructions`/`summary`) to a fixed maximum (e.g. document the cap) BEFORE parsing/mapping so an
  over-long response cannot blow up memory or downstream checks; clipping must not break the JSON happy path for
  reasonably-sized objects.

### 5. Fixture updates (mock-first, no live call)

**Required fixtures (block the run if absent):**
- `glm-response-success-choices.json` — live-shaped (`choices[0].message.content` = a JSON string of
  `{summary, files_changed:["src/setNames.ts"], proposed_patch:"…", confidence:"high"}`) → normalizes to a
  populated, in-scope result → validator ACCEPT.
- `glm-response-fenced-json.json` (C1) — `content` = the SAME JSON object wrapped in a ```` ```json … ``` ```` markdown
  code fence (optionally with a line of leading prose) → fence/object extraction recovers it → structured fields
  populated (`files_changed=["src/setNames.ts"]`) → validator ACCEPT. Proves naive `json.loads` would have failed
  here but the robust path succeeds.
- `glm-response-empty-choices.json` (C2) — `{"choices": []}` (and/or a sibling with `choices` missing entirely) →
  defensive envelope handling yields a graceful empty low-confidence result (`files_changed=[]`, no patch), NO crash
  → validator ACCEPT.
- `glm-response-malformed-content.json` — `content` = non-JSON / truncated → no `{ … }` isolable → falls back to
  instructions; schema-valid; validator ACCEPT (empty file set).
- `glm-response-empty-content.json` — `content` = "" → empty-but-valid result; validator ACCEPT.

**Recommended adversarial / robustness fixtures:**
- `glm-response-bad-scope-choices.json` — parsed `files_changed` is out-of-scope → emitted result → validator REJECT
  (proves the validator still gates model-supplied content).
- `glm-response-disallowed-category.json` — parsed `proposed_patch`/`files_changed` touches a disallowed category
  (`.env*` or a lockfile) → validator REJECT (closes the "model output can't bypass category constraints" gap).
- `glm-response-override-attempt.json` — `content` claims `credential_exposure="leaked"` / `no_direct_mutation=false`
  → emitted result still forces `credential_exposure="none"` / `no_direct_mutation=true`.
- `glm-response-nonstop-finish.json` — `finish_reason="length"` (or `content_filter`) with partial content →
  safe fallback, `confidence="low"`, validator ACCEPT.
- `glm-response-overlong-content.json` — content far above the bound → clipped/bounded safely, no crash, ACCEPT.

Keep the existing top-level mock fixtures (back-compat: still normalize correctly via pass-through).

### 6. Verification plan
- Mock tests FIRST (no network): run the adapter `--mock` over each new fixture → result; validate each with
  `worker-result-check.py`.
- Assert: success-choices → populated summary + `files_changed=["src/setNames.ts"]` + ACCEPT;
  fenced-json → SAME structured fields recovered + ACCEPT (C1); empty-choices/missing-choices → graceful empty
  low-confidence result, no crash, ACCEPT (C2); malformed → instructions populated, files_changed [], ACCEPT;
  empty-content → ACCEPT (empty-but-valid).
- Assert an adversarial choices fixture whose parsed `files_changed` is out-of-scope → validator REJECT, and a
  disallowed-category (`.env*`/lockfile) parsed patch → validator REJECT (proves the validator still gates
  model-supplied content and category constraints).
- Assert non-stop `finish_reason` → safe fallback + `confidence="low"` + ACCEPT; over-long content → bounded,
  no crash, ACCEPT.
- Existing top-level mock fixture still ACCEPTs (no regression).
- `py_compile` adapter; guards/validator/schemas `git diff` empty.
- NO live call unless explicitly approved later (the `./dmc-glm-smoke` live path is unchanged and exercised
  separately, one request, by the maintainer).

### 7. Safety constraints (reaffirmed)
- No `.env*` read/exposure; key path untouched (normalization is post-response, never sees/prints the key).
- No `git apply`, no auto-apply, no repo mutation by the worker result.
- credential_exposure forced `none`; no_direct_mutation forced `true`; model cannot override.
- Validator remains the gate over the normalized output (scope/secret/consistency/disallowed-category).

### 8. Recommended commit boundary & message
One commit: adapter normalization + the new fixtures listed in §5 + verification harness + plan/evidence/verification.
No schema/guard/validator/smoke-runner files. Suggested message:
`fix(dmc): normalize glm chat-completion content into worker result schema`

## Acceptance Criteria

- Criterion: top-level mock stays backward compatible (no `choices` key → pass-through unchanged).
  Verification: `--mock glm-response-mock.json` → ACCEPT; result identical in shape to pre-change mapping.
- Criterion: `choices[0].message.content` carrying a bare JSON object populates `summary` / `files_changed` / `proposed_patch` / `confidence`.
  Verification: adapter `--mock glm-response-success-choices.json` → non-empty `summary`, `files_changed=["src/setNames.ts"]`, patch present; `worker-result-check.py` ACCEPT.
- Criterion (C1): fenced JSON populates the structured fields (naive `json.loads` would fail; robust extraction succeeds).
  Verification: `--mock glm-response-fenced-json.json` → SAME structured fields as success-choices; ACCEPT.
- Criterion (C1): prose-wrapped JSON extracts the structured fields via first-balanced-object isolation.
  Verification: fixture with leading/trailing prose around the JSON object → structured fields populated; ACCEPT.
- Criterion: malformed / non-JSON content falls back safely to instructions, stays schema-valid.
  Verification: `--mock glm-response-malformed-content.json` → `instructions` populated, `files_changed []`, `confidence="low"`; ACCEPT.
- Criterion (C2): empty/missing `choices` envelope does NOT crash and yields a graceful low-confidence empty result.
  Verification: `--mock glm-response-empty-choices.json` (and a missing-`choices` variant) → exit 0, no traceback, `files_changed []`, no patch; ACCEPT.
- Criterion: empty `content` yields empty-but-valid result.
  Verification: `--mock glm-response-empty-content.json` → ACCEPT (no crash).
- Criterion: non-`stop` `finish_reason` (length/content_filter) lowers confidence or falls back safely.
  Verification: `--mock glm-response-nonstop-finish.json` → fallback, `confidence="low"`, ACCEPT.
- Criterion: over-long content is bounded/truncated safely.
  Verification: `--mock glm-response-overlong-content.json` → bounded, no crash/blowup, ACCEPT.
- Criterion: adversarial parsed outputs are rejected by the validator (model cannot widen scope, inject secrets, or hit a disallowed category).
  Verification: `glm-response-bad-scope-choices.json` → REJECT; `glm-response-disallowed-category.json` (`.env*`/lockfile) → `worker-result-check.py` REJECT.
- Criterion: adapter-enforced fields are never taken from the model.
  Verification: `glm-response-override-attempt.json` claiming `credential_exposure="leaked"` / `no_direct_mutation=false` → emitted result still has `credential_exposure="none"` / `no_direct_mutation=true`.
- Criterion: parsing uses `json.loads` only — never `eval`/`exec`.
  Verification: `grep -nE '\beval\(|\bexec\(' glm-api-adapter.py` → no eval/exec on response content.
- Criterion: existing schemas / guards / validators / smoke runner remain byte-unchanged.
  Verification: `git diff WORKER_*_SCHEMA.md .claude/hooks/ dmc-glm-smoke` → empty.
- Criterion: no live call in build verification.
  Verification: harness uses `--mock` only; no network.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Model returns prose, not JSON | med | Request JSON-only; robust plain-text fallback → instructions; never crash. |
| Model wraps JSON in a markdown fence / adds prose (C1) | high | Strip code fences + isolate first balanced `{ … }` object before `json.loads`; fenced-json fixture asserts recovery. |
| Malformed/empty GLM envelope crashes the adapter (C2) | high | Guarded `.get`/type checks at every level (`choices`/`[0]`/`message`/`content`); try/except → graceful empty result; empty-choices fixture asserts no crash. |
| Truncated content (non-stop `finish_reason`) mis-parsed as structured | med | Read `finish_reason`; non-`stop` → plain-text fallback, `confidence=low`. |
| Malicious/erroneous model output widens scope or injects secrets | high | Adapter forces credential_exposure=none / no_direct_mutation=true; validator REJECTs out-of-scope/secret/disallowed; `files_changed` must equal diff paths. |
| Normalization breaks the mock-first path | med | Shape detection: pass top-level fixtures through unchanged; regression test on existing fixture. |
| Parsing untrusted content unsafely | high | `json.loads` only — never eval/exec; bound content length; catch all exceptions → fallback. |
| Scope creep into schema/guard changes | low | Adapter-only; schema/guard edits forbidden unless proven; acceptance asserts they're unchanged. |
| Accidental live call during build | high | Mock-only verification; live path unchanged + gated; no network in harness. |

## Rollback Path

### Pre-commit
- `git restore .claude/workers/providers/glm-api/glm-api-adapter.py` (+ README/CONFIG if touched)
- `rm -f .claude/workers/providers/glm-api/fixtures/glm-response-{success-choices,fenced-json,empty-choices,missing-choices,malformed-content,empty-content,bad-scope-choices,disallowed-category,override-attempt,nonstop-finish,overlong-content}.json` (the exact new fixture set from §5; `missing-choices` only if added as the empty-choices sibling)
### Post-commit
- `git revert <v0.2.1.1-commit-sha>`; the prior adapter (shallow mapping) returns; mock + safety still pass.
Adapter-only + additive fixtures; guards/validator/schemas untouched → clean rollback.

## Verification Commands

| Command | Reason | Required |
|---|---|---|
| `adapter --mock glm-response-success-choices.json` → populated result; `worker-result-check.py` ACCEPT | live-shape (bare JSON) normalization | yes |
| `adapter --mock glm-response-fenced-json.json` → SAME structured fields; ACCEPT | C1: fenced-JSON extraction | yes |
| `adapter --mock glm-response-empty-choices.json` (+ missing-choices) → no crash, empty result; ACCEPT | C2: defensive envelope | yes |
| `adapter --mock glm-response-malformed-content.json` → instructions populated; ACCEPT | plain-text fallback | yes |
| `adapter --mock glm-response-empty-content.json` → ACCEPT | empty content | yes |
| out-of-scope choices fixture → `worker-result-check.py` REJECT | validator still gates model scope | yes |
| disallowed-category (`.env*`/lockfile) parsed patch → `worker-result-check.py` REJECT | validator gates category | yes |
| `glm-response-override-attempt.json` → emitted result forces `none`/`true` | model can't override adapter-enforced fields | yes |
| `adapter --mock glm-response-nonstop-finish.json` → fallback, `confidence=low`; ACCEPT | finish_reason handling | no |
| `adapter --mock glm-response-overlong-content.json` → bounded, no crash; ACCEPT | length bounding | no |
| `adapter --mock glm-response-mock.json` → ACCEPT | mock-first no regression | yes |
| `grep -nE '\beval\(|\bexec\(' glm-api-adapter.py` → none on content | json.loads only, no eval/exec | yes |
| `git diff WORKER_*_SCHEMA.md .claude/hooks/ dmc-glm-smoke` → empty | no schema/guard/validator/smoke-runner change | yes |
| `python3 -m py_compile glm-api-adapter.py` | syntax | yes |

## PASS / PARTIAL / FAIL

- **PASS**: bare-JSON AND fenced/prose-wrapped (C1) content normalize into populated, in-scope, schema-valid results
  (ACCEPT); malformed/empty content and empty/missing `choices` envelopes (C2) handled gracefully with NO crash;
  non-`stop` finish + over-long content handled safely; the validator still REJECTs out-of-scope/secret/
  disallowed-category model output; adapter-enforced fields can't be overridden by the model; mock-first preserved;
  no schema/guard/validator/smoke-runner change; no live call.
- **PARTIAL**: bare-JSON normalization works but fenced/prose extraction (C1), an envelope guard (C2), or one
  adversarial gate is incomplete — documented.
- **FAIL**: a model-supplied result can bypass the validator (out-of-scope/secret/disallowed-category accepted), the
  adapter trusts model-claimed credential_exposure/no_direct_mutation, a fenced/prose-wrapped JSON object is silently
  lost to fallback (C1 unmet), a malformed/empty envelope crashes the adapter (C2 unmet), `eval`/`exec` is used on
  content, mock-first regresses, a live call is made at build, or guards/schemas/smoke-runner are changed.

## Assumptions

| Assumption | Confidence | How to Verify |
|---|---|---|
| GLM is OpenAI-compatible (`choices[0].message.content`) | high | live-smoke response shape; vendor docs; success-choices fixture mirrors it. |
| Live models commonly fence/prose-wrap JSON | high | C1 robust extraction (fence strip + first balanced object); fenced-json fixture asserts recovery. |
| A live envelope may be empty/partial/malformed | med | C2 defensive `.get`/type guards + try/except; empty-choices fixture asserts no crash. |
| No `WORKER_RESULT_SCHEMA` field is missing for normalization | high | schema already has summary/files_changed/proposed_patch/instructions/confidence. |
| Validator suffices as the safety net over normalized output | high | worker-result-check covers scope/secret/consistency/disallowed-category. |
| Mock-first preserved via shape detection (choices vs top-level) | high | regression test on existing fixture. |

## Execution Tasks

- [ ] DMC-T001: Add `normalize_response()` to the adapter — shape detect (`choices` vs top-level); **defensive envelope extraction (C2)** with `.get`/type guards + try/except so missing/empty `choices`/`message`/`content` degrade to a graceful low-confidence empty result; **robust content parsing (C1)** = strip markdown fences + isolate first balanced `{ … }` object, then `json.loads` on the candidate (json.loads only, never eval/exec); plain-text fallback when no object is isolable/parseable; `finish_reason` non-`stop` → fallback; bound content length.
- [ ] DMC-T002: Force adapter-enforced fields (credential_exposure=none, no_direct_mutation=true) regardless of model output; request JSON-only in the live body.
- [ ] DMC-T003: Add required fixtures (success-choices, **fenced-json (C1)**, **empty-choices/missing-choices (C2)**, malformed-content, empty-content) + recommended adversarial/robustness fixtures (bad-scope, disallowed-category, override-attempt, nonstop-finish, overlong-content).
- [ ] DMC-T004: Verification harness (mock-only) + worker-result-check over all fixtures incl. fenced-json recovery, empty-envelope no-crash, adversarial REJECT (scope + disallowed category), override-attempt, finish_reason, length bound; guards/schemas/smoke-runner byte-unchanged.
- [ ] DMC-T005: README/CONFIG note on structured-output prompting (if needed).
- [ ] DMC-T006: Evidence + verification report. No live call.

## Approval Status

Status: APPROVED
Approver: 대표님
Approved At: 2026-06-21
