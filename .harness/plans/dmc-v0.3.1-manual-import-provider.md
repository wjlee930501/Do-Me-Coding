# Plan — dmc-v0.3.1 Manual Import Provider

Status: APPROVED
Approval Status: APPROVED
Approved: 2026-06-21 — human Release Gate flip (delegated semi-autonomous mode) after the 3-round independent critic loop
(round-1 REVISE R1–R7 → round-2 REVISE R5(a) only → round-3 applied R5(a) verbatim + cosmetic nits; no remaining REQUIRED
blocker). Router-deferral + schema-no-change critic-accepted. Independent critic panels, not self-approval.
Revision: 3 (round-2 critic re-pass = PASS×3 / REVISE×1 → applied the R5(a) V15 leak-check one-liner + cosmetic citation
nits; round-1 R1–R7 + router-deferral + schema-no-change remain resolved/accepted)
Mode: PLAN ONLY — no implementation, no staging/commit/push. Grounded by a read-only exploration of the existing
provider adapters, router, result schema, validator hook, and verify harnesses (citations inline).

## Goal
Add a **manual_import** Worker-Bridge provider: a safe, additive, **pure-validation** local adapter that accepts a
**manually-supplied, provider-like** proposal artifact, validates it fail-closed, and emits a normalized
`WORKER_RESULT_SCHEMA` result — **with no live call, no credentials, and no auto-apply**. It fills the last open slot in
the provider access layer (`manual_import` deferred since v0.2.3) without touching the protected provider surface.

## User Intent
Let DMC ingest a worker proposal produced **out-of-band** (any tool/model the operator ran themselves) through a
**trust-minimized local ingestion lane** that holds it to **at least** the safety bar of provider output, so an imported
proposal is never more trusted than a provider-generated one and E2E completion can proceed offline without a live call.

## 1. Problem Statement
- **Why manual_import exists.** The provider access layer has `mock`, `api_key` (glm-api), `oauth_cli` (oauth-cli), and a
  routing layer, but no sanctioned way to bring an externally-generated worker proposal into the bridge. `provider-router.py`
  explicitly **refuses** `type=manual_import` today (provider-router.py:55-56). The alternatives are unsafe (hand-editing a
  result, bypassing validation).
- **Gap it fills.** A *governed import lane* for human-supplied proposals that still enforces shape + the safety battery
  (proposal-only, scope, secret-rejection, disallowed-categories) — at least as strict as what `worker-result-check.py`
  enforces on provider output (see §3 for the exact parity boundary).
- **How it supports E2E completion without a live call.** A proposal obtained anywhere is **imported offline**; DMC never
  makes the provider call — it only **validates and normalizes**. Zero network/credential dependency, consistent with the
  mock-first posture of every prior milestone.

## 2. Non-Goals (explicit)
- **No live provider call** (no "live" mode exists). · **No credential/env inference** (no `.env*`/credential read; no
  `--allow-network`/`--allow-exec`). · **No auto-apply** — the normalized result is a **review artifact only**; the adapter
  never runs `git apply`, writes product/repo files, or applies a patch (application stays a later scope-guarded,
  human-gated `Edit`/`Write`). · **No schema change** (output conforms to existing `WORKER_RESULT_SCHEMA`; proven in §6).
  Should an unavoidable need surface, it is escalated to critic review and the plan revised — **never** bent silently. ·
  **No fallback/load/cost routing.** · **No raw provider-response persistence** beyond explicitly-approved **synthetic mock
  fixtures** under `fixtures/`. · **No hidden trust in arbitrary imported files** — every import is **untrusted input**,
  validated fail-closed. · **No router modification** (router integration OUT OF SCOPE — §3).

## 3. Candidate Design

### 3.1 Nature
manual_import is a **pure-validation importer** — no external invocation. Its only subprocess is the mandatory
**read-only** context-guard, invoked **positionally**: `worker-context-guard.sh <task.json>` (`shell=False`) — matching the
shipped adapters (glm-api-adapter.py:43 runs `subprocess.run(["bash", CTX_GUARD, task_path], …)`; the guard is positional,
not `--task`). Non-zero ⇒ `die()` (fail-closed).

### 3.2 Files / Identity / CLI
- Adapter: `.claude/workers/providers/manual-import/manual-import-adapter.py` (executable Python 3, single `main()`).
- Identity (adapter-stamped, never read from import): `provider_type="manual_import"`, `provider="manual-import"`.
- CLI: `manual-import-adapter.py --task <task.json> --import <artifact.json|-> [--out <result.json>]` — **no `--mock`, no
  `--live`, no `--allow-*`, no credential/env knob.** `--import -` reads the artifact from stdin (kept; see §5 for why it is
  safe given the per-reject-path leak checks). With `--out`: write the normalized result + a `wrote result -> <path>` line on
  stdout; without `--out`: print the result JSON to stdout. No imported content value ever appears on stdout/stderr;
  `die(msg)` is diagnostic-only and **never interpolates artifact content**.

### 3.3 Accepted input envelope — **"manual-import envelope v1"** (R1)
The import is a **provider-like loose artifact** — explicitly **NOT** an already-normalized `WORKER_RESULT_SCHEMA` result,
and **NOT** arbitrary JSON. The human supplies **only** the proposal-substance fields below; the adapter **owns** (derives /
stamps) all identity, provenance, and safety-invariant fields. **`WORKER_RESULT_SCHEMA` defines MUST-hold invariants
(`no_direct_mutation==true`; `provider_metadata.credential_exposure=="none"`; `files_changed==touched paths`) — it is NOT a
complete required/optional field partition** (WORKER_RESULT_SCHEMA.md:32-41), so the mandatory-in-import set is enumerated
here rather than inferred from "required fields".

**Field-disposition table (envelope v1):**

| Field | Disposition |
|---|---|
| `summary` | **HUMAN-supplied — mandatory** |
| `files_changed` | **HUMAN-supplied — mandatory** (array of repo-relative paths) |
| `proposed_patch` | **HUMAN-supplied — mandatory** (unified-diff text; may be `""` iff `instructions` non-empty) |
| `confidence` | **HUMAN-supplied — mandatory** (`low\|med\|high`) |
| `instructions` | HUMAN-supplied — optional (mandatory iff `proposed_patch==""`) |
| `files_considered`, `risks`, `assumptions`, `test_suggestions`, `unresolved_questions` | HUMAN-supplied — optional; adapter defaults each to `[]` |
| `task_id` | **ADAPTER-derived** from `--task`; **REJECT if present in import** |
| `no_direct_mutation` | **ADAPTER-stamped `true`**; **REJECT if present in import** |
| `provider_metadata` (whole object, incl. `provider_type`, `provider`, `model_claimed`, `generated_at`, `invocation_id`, `credential_exposure`) | **ADAPTER-stamped**; **REJECT if present in import** |
| any other / unknown key | **REJECTED** (strict allowlist envelope) |

**Strict envelope, deliberately divergent from glm-api's lenient `normalize_response`/`.get(default)` model
(glm-api-adapter.py:120-206), and the divergence is intentional:** the import is fully-untrusted human input, so a strict
allowlist (reject unknown keys; reject any adapter-owned field if supplied) is safer than lenient defaulting that could mask
an injected field or a human-asserted provenance/safety claim. **Imported `provider_metadata` / `generated_at` /
`invocation_id` / `credential_exposure` / `no_direct_mutation` / `task_id` are REJECTED if supplied — never silently
trusted or overwritten** (a human cannot assert their own provenance or safety invariants).

### 3.4 Pipeline (fail-closed at each step; any failure ⇒ exit non-zero, write nothing)
1. **Context guard first** — `worker-context-guard.sh <task.json>` (positional, `shell=False`); non-zero ⇒ `die()`.
2. **Parse** the import as JSON (`json.loads` only — never `eval`/`exec`); parse failure ⇒ reject. (Bounded by a
   max-artifact-size cap — see §5.)
3. **Strict envelope check (adapter-only guard)** — exactly the enumerated mandatory-in-import fields present with correct
   types; reject any **adapter-owned** field if supplied; reject any **unknown** key. (This is stricter than
   `worker-result-check.py`, which performs no required/unknown-field check — §3.6.)
4. **Proposal-only** — adapter stamps `no_direct_mutation=true`; reject any embedded apply/mutation directive in the import.
5. **Raw secret/token scan (the real credential gate, pre-stamp) — R3** — over the **entire raw import**, run the
   `worker-result-check.py` `SECRET_VALUE` set **and** the **exact** `oauth-cli` `OAUTH_TOKEN_PATTERNS` list (JWT/`Bearer`/
   `Authorization:`-header/`ya29.`/`access_token`/`refresh_token`/`id_token`/`gh[opsu]_`); any match ⇒ **reject** (never redact-and-emit). The
   adapter is the **sole** gate for the OAuth-token class (§3.6).
6. **Patch/scope consistency** — parse `proposed_patch` (unified diff), assert `files_changed`==touched paths;
   `files_changed ⊆ allowed_files`, `files_changed ∩ forbidden_files == ∅`; reject any disallowed-category path (`.env*`,
   lockfiles, dependency manifests, migrations, binary, production-config).
7. **Normalize + stamp** — build the `WORKER_RESULT_SCHEMA` result from the human fields + adapter-owned stamps:
   `task_id` (from `--task`), `no_direct_mutation=true`, `provider_metadata{provider_type="manual_import",
   provider="manual-import", model_claimed="unknown", generated_at=<deterministic sentinel>, invocation_id=<deterministic>,
   credential_exposure="none"}`. **Determinism (R6):** `generated_at`/`invocation_id` are **deterministic** — a fixed
   sentinel (e.g. `generated_at="1970-01-01T00:00:00Z"`, mirroring glm-api-adapter.py:202-203) or content-hash-derived;
   **wall-clock and randomness are forbidden** in this offline adapter.
8. **Emit** to `--out`/stdout. Downstream, `worker-result-check.py` re-validates as a **backstop** for the checks it covers
   (§3.6).

### 3.5 Credential gate (R3)
Because step 7 always stamps `credential_exposure="none"`, the **downstream** `worker-result-check.py` `credential_exposure`
check (worker-result-check.py:47) is **not** the real credential gate — a naive stamp would *launder* a credential-bearing
import. The **real credential gate is the step-5 full raw-import secret/token scan (pre-stamp)**. `credential_exposure="none"`
describes **only DMC's own handling** (DMC made no call, used no credentials) **after** the raw import has passed scanning;
a credential-bearing import is **rejected at step 5, before any result is constructed** — never stamped clean.

### 3.6 Guard parity boundary (R2) — explicit, no overclaim
The manual-import adapter is **at least as strict as `worker-result-check.py`, and adds adapter-only superset guards.** It is
**not** an "identical second gate", and the validator is **not** a universal backstop. Precisely:
- **`worker-result-check.py` backstops** (the validator independently rejects these on the written result): scope
  (`files_changed ⊆ allowed`, `∩ forbidden=∅`), disallowed-category paths, the **sk-class** `SECRET_VALUE` set
  (worker-result-check.py:21-23 = `sk-`/`AKIA`/`BEGIN PRIVATE KEY`/`xox`/`ghp_`), `no_direct_mutation==true`,
  `credential_exposure=="none"`, and final schema-acceptance behavior.
- **The adapter is the SOLE gate** (no validator backstop) for: (a) **OAuth-token-class leaks** — JWT/`Bearer`/
  `Authorization:`-header/`ya29.`/`access_token`/`refresh_token`/`id_token`/`gh[opsu]_` — which live **only** in
  `oauth-cli-adapter.py` `OAUTH_TOKEN_PATTERNS` (:37-44), **not** in the validator's `SECRET_VALUE`; and (b) **strict-shape / unknown-field /
  missing-mandatory-field** envelope validation, which the validator does not perform (all `.get(default)`, no
  `additionalProperties:false`). The adapter **MUST reuse the exact `oauth-cli` `OAUTH_TOKEN_PATTERNS` list** (not a
  re-derived subset) — verified for drift by V16.

### 3.7 Router integration — OUT OF SCOPE (decided, grounded; critic-ACCEPTED)
Building this adapter requires **no** change to `provider-router.py`. Justification: (a) **standalone capability is shown by
the adapter's self-contained flow** — parse → positional context-guard → strict-envelope + safety validation → normalized
emit → consumed directly by `worker-result-check.py` (which takes `task`+`result` positionally, no router) — **not** by
PROVIDER_CONTRACT C8 (C8 concerns router/direct byte-identity in `--mock` mode and presumes REGISTRY membership, which
manual_import deliberately lacks); (b) `provider-router.py` is a **protected file** whose REGISTRY (:36-39) holds only
glm-api/oauth-cli and **refuses** `manual_import` (:55-56) — editing it expands scope into routing and triggers a
protected-surface critic gate; (c) routing `manual_import` is a **separable concern** deferred since v0.2.3. **Therefore
v0.3.1 builds and contract-tests the adapter standalone and does NOT edit `provider-router.py`/`ROUTING.md`.** REGISTRY
wiring of `(manual_import, manual-import)` — and reconciling the `--import` CLI vs the router's `--mock` forwarding — is
deferred to a **separate routing milestone (≈v0.3.2)** with its own plan + human gate + protected-file critic review.

## 4. File-Level Scope (all additive)
New files only:
- `.claude/workers/providers/manual-import/manual-import-adapter.py`
- `.claude/workers/providers/manual-import/README.md` — provider type; the import lane; **envelope v1** + field-disposition;
  the guard-parity boundary; **"`credential_exposure=\"none\"` is scoped to DMC's own handling, not full-lineage
  provenance"**; **"manual_import is a trust-minimized local ingestion lane validating a defined contract — NOT a
  human-approval bypass"** (application stays a later scope-guarded human-gated Edit/Write).
- `.claude/workers/providers/manual-import/CONFIG.md` — config table: **no credential, no `.env`, no network required**;
  the only knob is `DMC_MANUAL_IMPORT_MAX_BYTES` (optional max-artifact-size bound, default e.g. 1 MiB) + the same scoping
  note on `credential_exposure`.
- `.claude/workers/providers/manual-import/fixtures/` — synthetic JSON fixtures (fake-only; no real creds / no real provider
  output): `import-success.json`, `import-malformed.json`, `import-missing-fields.json`, `import-extra-fields.json`
  (valid mandatory set **plus** an unknown/adapter-owned key), `import-bad-scope.json` (exercises a **disallowed-category**
  path, not only allowed/forbidden), `import-secret.json` (synthetic token shape, incl. an OAuth/JWT shape), `import-cred-exposure.json`
  (supplies `provider_metadata.credential_exposure!="none"` — an adapter-owned field), `import-mutation-attempt.json`
  (apply directive / `no_direct_mutation` supplied), `import-empty.json`.
- `.harness/evidence/dmc-v0.3.1-verify.sh` — the verification harness (mock/offline; C1–C11 + C5a battery).
- `.harness/verification/dmc-v0.3.1-manual-import-provider.md` — the verification report (carries `Review-Verdict: …`).
- `.harness/plans/dmc-v0.3.1-manual-import-provider.md` — this plan.

**NOT touched (protected surface):** `provider-router.py`, `ROUTING.md`, `PROVIDER_CONTRACT.md`,
`WORKER_{TASK,RESULT,REVIEW}_SCHEMA.md`, `.claude/hooks/*` (incl. `worker-context-guard.sh`, `worker-result-check.py` —
**invoked, never edited**), `dmc-glm-smoke`, the glm-api / oauth-cli adapters. Auto-logged `.harness/evidence/dmc-v0.3.1-*.md`
stays untracked/excluded (enforced by the v0.2.6 G3 `.harness/evidence/*.md` pattern).

## 5. Safety Constraints
No live/network/model-API call. · No `.env*`/credential read. · Secret/token-shaped content ⇒ **reject** (never
echo/redact-and-emit). · No auto-apply / `git apply` / repo write beyond `--out`. · **Imported content is untrusted** —
validated fail-closed before any acceptance; **adapter-owned fields rejected if supplied**. · `shell=False` for the lone
read-only context-guard subprocess (positional); content off argv; `json.loads` only. · **Bounded input:** reject imports
larger than `DMC_MANUAL_IMPORT_MAX_BYTES` (default ~1 MiB) **before** parse/scan — DoS/log-amplification hygiene on untrusted
input (mirrors glm-api `MAX_CONTENT_LEN`). · **Leak-clean diagnostics (R5):** on **every** reject path, stdout **and**
stderr must contain no value-substring of the imported artifact — this is what makes `--import -` (stdin) safe to keep. ·
No protected-surface mutation. · The adapter's acceptance is **necessary-but-not-sufficient**: the result must also pass
`worker-result-check.py` for the checks that hook covers (§3.6).

## 6. Schema-No-Change (R-confirmed; critic-ACCEPTED)
No schema change. `WORKER_RESULT_SCHEMA.md:22` already lists `manual_import` as a first-class `provider_type` enum member;
`provider` is a free string (`manual-import` legal); `credential_exposure="none"` is used for its literal meaning (no
credential exposure in **this adapter's** handling) — no field is bent to encode provenance. `model_claimed="unknown"` is an
honest free-string value. The stop-and-replan commitment (§2) stands; since no bend is required, it is belt-and-suspenders.

## 7. Verification Matrix (`.harness/evidence/dmc-v0.3.1-verify.sh`, mock/offline only; mirrors dmc-v0.2.4 C1–C11 + C5a)
Standard preamble (`MOCK-ONLY` guard lines, `ROOT`/`PASS`/`FAIL`/`ok()`/`no()`, `mktemp -d` + trap, CI-env unset
`env -u CI -u GITHUB_ACTIONS …`); SUMMARY line; exit 0 iff `FAIL==0`. **`rejected()` helper mirrors dmc-v0.2.4-verify.sh:49-51
and enforces PROVIDER_CONTRACT C5a — an unsafe fixture passes ONLY if NO ACCEPT occurs: the adapter rejects (exit≠0, no
result written) OR `worker-result-check.py` REJECTs the written result. No unsafe artifact is ever ACCEPTED.** Every reject
row additionally **leak-checks** stdout+stderr (R5).

- **V1 valid import ACCEPTs** — `import-success.json` (envelope v1) ⇒ adapter exit 0, normalized result written, **and**
  `worker-result-check.py` ACCEPTs it (and accepts `provider_type="manual_import"` per schema enum).
- **V2 malformed JSON** — `import-malformed.json` ⇒ adapter rejects (exit≠0, no result); **leak-check** stdout+stderr.
- **V3 missing mandatory-in-import field / empty** — `import-missing-fields.json`, `import-empty.json` ⇒ **ADAPTER-level
  non-zero exit** (adapter-only strict-envelope guard); **leak-check**.
- **V4 unknown/extra OR adapter-owned field supplied** — `import-extra-fields.json` ⇒ **ADAPTER-level non-zero exit**
  (adapter-only strict-envelope guard; reverting the strict check ⇒ this row fails); **leak-check**.
- **V5 unsafe scope / disallowed-category** — `import-bad-scope.json` (hits a **disallowed-category** path) ⇒ C5a: adapter
  rejects OR `worker-result-check.py` REJECTs; **leak-check**.
- **V6 token/secret content** — `import-secret.json` (incl. an **OAuth/JWT** shape) ⇒ **ADAPTER-level non-zero exit** (the
  adapter is the SOLE gate for the OAuth-token class — the validator misses it); assert the JWT/`ya29.`/`Bearer` shape is
  rejected by the **adapter**; **leak-check** (no token VALUE on stdout/stderr).
- **V7 mutation / auto-apply attempt** — `import-mutation-attempt.json` (apply directive / `no_direct_mutation` supplied) ⇒
  C5a (adapter rejects, or validator REJECTs on `no_direct_mutation`); **leak-check**.
- **V8 deterministic** — same fixture ⇒ **byte-identical `--out` JSON** across runs (compares the normalized `--out` result
  only, **not** stdout/stderr); relies on the deterministic stamps (R6).
- **V9 no `.env*` access** — context-guard fails closed if the task `allowed_files` contains an `.env*` path; the adapter
  opens no `.env`.
- **V10 no live/network/exec** — static + runtime: no network/subprocess except the read-only positional context-guard
  (`shell=False`).
- **V11 protected files byte-unchanged** — `git diff --name-only` over `.claude/hooks/`, `WORKER_*_SCHEMA.md`, `dmc-glm-smoke`,
  glm-api/, oauth-cli/, `provider-router.py`, `ROUTING.md`, `PROVIDER_CONTRACT.md` ⇒ empty.
- **V12 `--out` guard** — the canonicalized `out_refused` guard is enforced **inside the adapter, before the write/truncate**
  (a deliberately stronger behavior than glm/oauth); refuses protected/secret/traversal/symlink `--out`; benign path writes
  valid JSON.
- **V13 real-repo untouched** — `git status --porcelain` md5 unchanged after the run (temp-only writes).
- **V14 router N/A (deferral, not a fake test)** — assert standalone invocation produces a valid result with **no**
  `provider-router.py` involvement, **and** `worker-result-check.py` is invoked **directly** on the standalone output (the
  validator second-gate is the only shared-guard touchpoint and is exercised standalone).
- **V15 imported `credential_exposure!="none"` rejected** — `import-cred-exposure.json` ⇒ **ADAPTER-level non-zero exit**
  (adapter-owned field supplied; rejected by the strict-envelope guard, parallel to V4) — locks the honesty invariant under
  test; **leak-check** stdout+stderr (no value-substring of the imported artifact).
- **V16 token-regex drift-check** — assert the adapter's OAuth-token pattern list is **literally identical** to
  `oauth-cli` `OAUTH_TOKEN_PATTERNS` (shared-source or copied-with-explicit-drift-check; compare compiled-regex `.pattern`
  strings, **not** object identity), preventing the two adapter-level token gates from diverging.

## 8. Regression Risks (+ mitigations)
- **Trusting arbitrary imported files** → strict allowlist envelope v1; adapter-owned fields rejected if supplied; full
  safety battery fail-closed; adapter acceptance ≠ final acceptance (must also pass `worker-result-check.py` for its checks).
- **Leaking manually-supplied raw content** → secret/token-shaped content ⇒ reject (not redact-and-print); `die()`/stderr
  never interpolate artifact content; **every reject path leak-checked (V2–V7,V15)**; only the normalized result is emitted.
- **Side channel around provider guards** → the import lane is **at least as strict as** the validator and a **superset**;
  the OAuth-token class and strict-shape are adapter-sole-gate (explicitly stated, not claimed as validator-backstopped),
  and reused-exact `OAUTH_TOKEN_PATTERNS` (V16) prevents a weaker re-derived scan.
- **Credential laundering via the `none` stamp** → real gate is the pre-stamp raw scan (§3.5); credential-bearing import
  rejected before result construction (V6/V15).
- **Schema drift** → no schema change; strict envelope; unknown/adapter-owned/missing fields ⇒ reject.
- **Router ambiguity** → router untouched; no REGISTRY entry; no selection ambiguity introduced; wiring is a later gated
  milestone.
- **False confidence from fixture-only tests** → acknowledged: verification is **offline/fixture-only by design**; it proves
  the **validation logic against a defined contract (envelope v1 + safety battery)**, **not** the semantic truth/correctness
  of the human's proposal, and is **not** a human-approval bypass. README states this explicitly.

## 9. Rollback Plan
- **Additive removal** — delete `.claude/workers/providers/manual-import/` + `.harness/evidence/dmc-v0.3.1-verify.sh`; no
  existing file is modified, so removal is clean with zero schema/guard/router impact.
- **If committed** — single additive-commit `git revert`; no history rewrite, no protected-surface ripple; the router still
  refuses `manual_import` exactly as today until the separate routing milestone wires it.

## Execution Tasks (for the eventual /dmc-start-work — NOT executed now)
1. Author `manual-import-adapter.py` (size-bound → positional context-guard → parse → strict envelope v1 → proposal-only →
   pre-stamp raw secret/OAuth-token scan → patch/scope/disallowed → normalize + deterministic stamps → emit; `--task`/
   `--import`/`--out`; in-adapter `out_refused`; `die()` hygiene; reuse exact `oauth-cli` `OAUTH_TOKEN_PATTERNS`).
2. Author README.md + CONFIG.md (envelope v1 + field-disposition; parity boundary; `credential_exposure` scoping note;
   "not a human-approval bypass"; `DMC_MANUAL_IMPORT_MAX_BYTES`).
3. Author the 9 synthetic fixtures (fake-only).
4. Author `dmc-v0.3.1-verify.sh` (V1–V16; `rejected()` C5a helper; per-reject-path leak checks; protected-files guard;
   CI-env unset; temp isolation).
5. Run `bash .harness/evidence/dmc-v0.3.1-verify.sh` → all PASS / 0 FAIL; confirm protected files byte-unchanged; write the
   verification report with the canonical `Review-Verdict:` line; run the v0.2.6 gate-check on the additive set.

## Verification Commands
- `bash .harness/evidence/dmc-v0.3.1-verify.sh` (expect ALL PASS / 0 FAIL; protected files byte-unchanged)
- `git diff --name-only` over the protected surface (expect empty)
- `python3 .claude/hooks/worker-result-check.py <task.json> <V1-result.json>` (expect ACCEPT)
- gate-check runner on the additive staged set; then critic + Codex Independent Release Audit before any commit.

## Open Questions for Critic / Human (flag before APPROVED)
- Confirm the `--import` CLI (vs the router's `--mock` forwarding) is acceptable given router deferral — the future routing
  milestone must reconcile the forwarding shape.
- Confirm the envelope-v1 mandatory set `{summary, files_changed, proposed_patch|instructions, confidence}` is the intended
  minimum (vs. requiring more/less proposal substance).
- Confirm `DMC_MANUAL_IMPORT_MAX_BYTES` default (~1 MiB) is acceptable.
- Confirm the fixture set covers the intended threat model (add cases if the critic identifies a missed rejection path).

## Approval Status
**APPROVED** (2026-06-21, revision 3) — human Release Gate flip after the 3-round independent critic loop (round-1 REVISE
R1–R7 → round-2 REVISE R5(a) only → round-3 applied R5(a) verbatim + cosmetic nits; no remaining REQUIRED blocker).
Router-deferral and schema-no-change critic-accepted. **Next gate: `/dmc-start-work`** (additive scope under §4 only;
protected provider surface untouched). No implementation performed under this approval flip.
