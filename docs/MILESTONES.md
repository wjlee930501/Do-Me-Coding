# Do-Me-Coding — Milestone Closure Notes

A running, append-only log of shipped DMC milestones. One short entry per release.

## v0.2.2 — OAuth / Local-CLI Worker Provider Adapter — CLOSED (2026-06-21)

- **Commit:** `963f25a` (pushed to `origin/main`; local HEAD == origin/main).
- **What shipped:** a second live Worker Bridge provider, `provider_target.type=oauth_cli`, that obtains a worker
  proposal from a locally-installed, already-authenticated CLI tool (which owns the OAuth/session credential
  **outside** DMC). Adapter-only/additive: `.claude/workers/providers/oauth-cli/` (adapter + README + CONFIG + 8 mock
  fixtures + a deterministic local fake-CLI stub).
- **Verification:** `.harness/evidence/dmc-v0.2.2-verify.sh` → **28 PASS / 0 FAIL** (mock + local-stub only).
  - C1 token-material guard (`SECRET_VALUE` + explicit OAuth/JWT/Bearer/`access_token`/`refresh_token`/`id_token`/
    `gh[opsu]_`/`ya29.`) over stdout AND stderr → redact-and-reject before persistence.
  - C2 synthetic `choices` envelope before `normalize_response` → no raw-string crash.
  - C3 fake-CLI stub exercises the REAL exec wrapper offline (success/fenced/non-zero-exit/timeout/stdout-token/
    stderr-token/unauthenticated).
  - C4 `DMC_OAUTHCLI_BIN` trust model (absolute / regular / executable / non-symlink / TOCTOU re-check; `shell=False`;
    payload off-argv; bounded timeout; minimal child env).
- **Safety posture:** mock-first; **no live provider call**; DMC is token-blind (never reads/stores/logs the OAuth
  token); no credentials / `.env*` / raw provider responses / temp result artifacts committed; proposal-only (no
  `git apply`, no auto-apply). Protected files (hooks, schemas, validators, guards, GLM adapter, `dmc-glm-smoke`)
  verified byte-unchanged.
- **Intentionally not committed:** the untracked auto-logged evidence file
  `.harness/evidence/dmc-v0.2.2-oauth-cli-adapter.md` (excluded by design).
- **Provider Access Layer status:** `mock` ✓ · `api_key` (glm-api, v0.2.1 + v0.2.1.1) ✓ · `oauth_cli` (oauth-cli,
  v0.2.2) ✓ · `manual_import` (deferred).

**Next (now shipped):** v0.2.3 Provider Routing Layer — see entry below.

## v0.2.3 — Provider Routing Layer — CLOSED (2026-06-21)

- **Commit:** `6fe3015` (pushed to `origin/main`; local HEAD == origin/main).
- **What shipped:** a thin, additive **provider router** (`.claude/workers/providers/provider-router.py` + `ROUTING.md`)
  that selects a provider adapter from the task bundle and dispatches to it **unchanged** — starting with `glm-api`
  (`api_key`) and `oauth-cli` (`oauth_cli`). No schema/adapter/hook/validator/guard change; the adapters are wrapped,
  not modified.
- **Design:** selection is a pure function of `provider_target.{type,provider}` (a static registry) — **never** from
  env/secrets/heuristics. Dispatch is `subprocess.run([...], shell=False)` with the adapter resolved to an absolute
  path under the providers dir; per-entry live opt-in flag (`--allow-network` for glm-api, `--allow-exec` for oauth-cli)
  with cross-flag refusal at the router and an independent argparse backstop at the adapter.
- **Verification:** `.harness/evidence/dmc-v0.2.3-verify.sh` → **20 PASS / 0 FAIL** (mock + offline-stub only).
  - Deterministic task-only routing (V1/V2); refuse on unknown/`mock`/missing (V4/V5).
  - Routed `--out` JSON **byte-identical** to direct adapter invocation in mock mode (V3).
  - Route selection env-independent (V7); env **passthrough** without stripping so adapter live paths still work (V14).
  - Cross-flag safety at two layers (V8 router refusal, V8b adapter argparse); argv/stream hygiene; no `shell=True`/
    `git apply` (V10/V15).
- **Safety posture:** mock-first; **no live provider call** (only the deterministic offline fake-CLI stub exercised);
  no credentials / `.env*` / raw provider responses / temp result artifacts committed; proposal-only (no `git apply`,
  no auto-apply). Protected files (both adapters, hooks, schemas, validators, guards, `dmc-glm-smoke`) verified
  byte-unchanged.
- **Intentionally not committed:** the untracked auto-logged evidence file
  `.harness/evidence/dmc-v0.2.3-provider-routing.md` (excluded by design).
- **Provider Access Layer status:** `mock` ✓ · `api_key` (glm-api) ✓ · `oauth_cli` (oauth-cli) ✓ · routing layer ✓ ·
  `manual_import` (deferred).

**Next:** v0.3 multi-worker orchestration (planned).

## v0.2.6–v0.3.0 — DMC Operating Rails (read-only gate / manifest / intake / policy / E2E tooling) — CLOSED (2026-06-21)

- **Published:** fast-forwarded to `origin/main` (`37ef16c..d4142e9`); local `main` == `origin/main` == `d4142e9`.
  Shipped as a delegated, batch-reviewed stack; external review (Codex/Kim) → **ACCEPT** after the PR #2 fix commit.
- **Review branch / PR:** `review/dmc-v0.2.6-v0.3.0-stack` (head `d4142e9`); **PR #2** merged via fast-forward
  (2026-06-21), closure note recorded on the PR. Review branch retained (not deleted).
- **What shipped** (every tool is **advisory / read-only** — none stages, commits, pushes, grants a gate, or mutates the
  provider surface; the only writes are canonicalization-guarded `--out` files and `mktemp` self-test repos):
  - **v0.2.6 Gate Check Runner** (`f8eb277`) — `dmc-v0.2.6-gate-check-runner.sh` + `docs/DMC_GATE_CHECKS.md`. Read-only
    PASS/FAIL gate report: G1 staged⊆allowlist · G2 allowlist staged · G3 no excluded-evidence (now a `.harness/evidence/
    *.md` **pattern** rule) · G4 no protected-path change · G5 whitespace · G6 ahead/behind. Self-test **19 PASS / 0 FAIL**.
  - **v0.2.7 Run Manifest Generator** (`6fba01d`) — recorder-only JSON snapshot of a milestone run; guarded `--out`.
    Self-test **8 PASS / 0 FAIL**.
  - **v0.2.8 Task Intake Classifier** (`f31cc9a`) — advisory, **fail-closed** classifier (risk dimensions, required human
    gates, stop_and_ask); inert-data matching, canonicalized `--out` guard. Self-test **33 PASS / 0 FAIL**.
  - **v0.2.9 Effort & Provider Policy** (`0468aa6`) — **guidance, not enforcement** policy doc + read-only structure-check
    **15 PASS / 0 FAIL**; changes no routing, edits no code.
  - **v0.3.0 E2E Completion Controller** (`532b0ce`) — report-only, **fail-closed** reporter of E2E-done
    (verified · reviewed · committed · pushed · closure-recorded); **offline** (no `git fetch`). Self-test **16 PASS / 0 FAIL**.
  - **v0.3.0.1 Rails Hardening** (`0bbeea9`) — cross-tool consistency fixes from a Codex holistic deep re-review + 3
    adversarial critic rounds: F1 v0.2.7 `--out` guard, F2 v0.3.0 `--out` write, F3 v0.2.6 `--gate` enum, F4a–f
    `PROVIDER_CONTRACT.md` added to all six protected-set enumerations.
  - **Rails hardening / PR #2 review fix** (`d4142e9`) — G3 now pattern-excludes any `.harness/evidence/*.md` auto-log
    (structural rule, never stale per-milestone) while keeping `.sh` tools and `.harness/verification/*.md` stage-able;
    +3 falsifiable self-tests (Codex PR #2 REVISE → ACCEPT).
- **Verification posture:** **91 self-test / structure-check assertions, 0 FAIL** across the five tools (19 + 8 + 33 + 16 +
  15), all exit 0 — re-confirmed on published `main`. **Offline / mock / read-only** where applicable; self-tests run only
  in `mktemp` temp repos (real repo byte-identical). **No live provider call; no `.env*` / credential read; no network /
  model-API call.** Each milestone passed a separate critic pass + an independent Codex release audit (ACCEPT) before
  commit; the stack then passed an external holistic Codex review (ACCEPT after `d4142e9`).
- **Protected surface:** byte-unchanged across the whole stack — adapters, `provider-router.py`, `ROUTING.md`,
  `PROVIDER_CONTRACT.md`, `WORKER_*_SCHEMA.md`, `.claude/hooks/*`, `dmc-glm-smoke` (F4 only *references* these paths in
  deny-lists; it never edits them).
- **Intentionally not committed:** the untracked auto-logged evidence files `.harness/evidence/dmc-v0.2.{6,7,8,9}-*.md`,
  `dmc-v0.3.0-*.md`, `dmc-v0.3.0.1-*.md` (excluded by design — the v0.2.6 G3 `.harness/evidence/*.md` pattern now enforces
  this structurally even if a file is accidentally allowlisted).
- **Provider / agent rail status after v0.3.0:** provider access layer unchanged from v0.2.3 — `mock` ✓ · `api_key`
  (glm-api) ✓ · `oauth_cli` (oauth-cli) ✓ · routing ✓ · `manual_import` deferred. New **operating-rails layer** (read-only
  gate / manifest / intake / policy / E2E tooling) ✓. No provider-feature milestone has begun.
- **Note:** v0.2.4–v0.2.5 closure entries are not in this log — a separate, pre-existing backfill, out of scope for this entry.

**Next:** v0.3.1 Manual Import Provider (planned; touches the provider surface — requires an explicitly-scoped approved
plan + human gate before it begins).

## v0.3.1–v0.3.9 — Manual-Import Provider + Advisory Rails Loop (selection · manifest · review · closure · delegation · E2E) — CLOSED (2026-06-22)

- **Published:** fast-forwarded to `origin/main` (`00a3480..5aecdbc`); local `main` == `origin/main` == `5aecdbc`.
  Shipped as a delegated, batch-reviewed stack; external review (Codex/Kim) → **ACCEPT** at `5aecdbc` (after the
  metadata-redaction hardening fix). `origin/main` and `origin/review/dmc-v0.3.1-v0.3.9-stack` point to the same commit.
- **Review branch:** `review/dmc-v0.3.1-v0.3.9-stack` (head `5aecdbc`) — retained (not deleted).
- **What shipped** (each milestone: DRAFT plan → adversarial critic panel (REVISE→fix→focused re-pass PASS) → human
  APPROVED → approved-scope-only implementation → self-test → independent Codex release audit (ACCEPT) → commit; push +
  this closure are the human gates):
  - **v0.3.1 Manual Import Provider** (`a28f37e`) — standalone pure-validation `manual_import` importer ("manual-import
    envelope v1" → normalized `WORKER_RESULT_SCHEMA`, fail-closed; OAuth/token/secret guard semantics reused from
    oauth-cli; deterministic stamps). Additive adapter + fixtures. Self-test **17 PASS / 0 FAIL**.
  - **v0.3.2 Manual Import Router Wiring** (`4c2963c`) — registers `(manual_import, manual-import)` in `provider-router.py`
    + `ROUTING.md`; no-live guard (no `live_flag`); router-side cross-flag refusal. Verification **8 PASS / 0 FAIL**.
  - **v0.3.3 Three-Provider Contract** (`b7ba433`) — unified `PROVIDER_CONTRACT` C1–C11 suite over glm-api / oauth-cli /
    manual-import **+ the router path**, per-provider input-flag threading + pinned rejection stages (authorized
    `PROVIDER_CONTRACT.md` doc edit). **34 PASS / 0 FAIL**.
  - **v0.3.4 Provider Selection Runner** (`241f012`) — read-only/advisory ranked `provider_target` candidates
    (offline-first; `mock` is a run-mode, not a candidate; **no env/secret inference** — `env -i` byte-identical;
    executes nothing). Self-test **14 PASS / 0 FAIL**.
  - **v0.3.5 Execution Manifest v2** (`96f912e`) — forward-looking manifest binding task → proposed provider_target →
    selected adapter → verification expectations → gates → closure criteria; executes nothing; no env inference.
    Self-test **17 PASS / 0 FAIL** (incl. the v0.3.9.1 metadata-redaction test).
  - **v0.3.6 Review Packet Generator** (`4e2c3e7`) — names-only review pack (changeset · protected scan · forbidden/secret
    scan · verification summary · residual risks); load-bearing **secret protection** (no file content / commit body /
    secret-pathed report). Self-test **10 PASS / 0 FAIL** (incl. v0.3.9.1 metadata redaction).
  - **v0.3.7 Closure Controller** (`8cd3435`) — mechanically judges the 5 closure conditions, emits an **append-only**
    `MILESTONES.md` candidate (writes nothing); **fail-closed** (no false E2E-DONE). Self-test **12 PASS / 0 FAIL** (incl.
    v0.3.9.1 metadata redaction). *(This very entry was prepared with that controller's discipline.)*
  - **v0.3.8 Autonomous Delegation Harness** (`7012cb7`) — handbook-faithful allowed-autonomy / gated-action matrix
    (STAGE/COMMIT/PUSH/CLOSURE gated; Codex ACCEPT is an advisory input, never a grant) + role/critic-handoff templates +
    run-transcript checklist + a read-only compliance validator. Self-test **8 PASS / 0 FAIL**.
  - **v0.3.9 E2E Dry-Run Acceptance Suite** (`abe11cc`) — capstone: drives the full rails loop offline (regression →
    intake → select → manifest → review → closure → delegation), asserts the **compose** invariant and **no false-green**;
    no live / commit / push / real-repo mutation. Self-test **5 PASS / 0 FAIL** (8/8 stages ACCEPTED).
  - **v0.3.9.1 Metadata-Redaction Hardening** (`5aecdbc`) — closes the external review's REVISE on **free-form metadata
    carriers**: a value-blind sanitizer added to the v0.3.5 / v0.3.6 / v0.3.7 advisory tools redacts token/secret-shaped
    free-form fields (commit subject, `Review-Verdict:` line, Run ID, task `objective`/`context_summary`/`task_id`/hint —
    recursively over hint keys+values) to `[redacted:unsafe-metadata]` and **never re-emits a matched value**; pure regex,
    so determinism / `env -i` byte-identity is preserved. Adversarial verification panel + Codex audit → **ACCEPT**.
- **Verification posture:** **125 self-test / contract assertions, 0 FAIL** across the batch (17 + 8 + 34 + 14 + 17 + 10 +
  12 + 8 + 5), all exit 0 — re-confirmed on published `main`. Each milestone passed a separate adversarial critic pass +
  an independent Codex release audit (ACCEPT) before commit; the hardening also passed an adversarial verification panel +
  Codex ACCEPT; the whole stack then passed an external holistic Codex/Kim review → **ACCEPT** at `5aecdbc`.
  **Offline / mock / read-only**: self-tests run only in `mktemp` temp repos (real repo byte-identical). **No live
  provider call; no `.env*` / credential read; no network / model-API call** (verified across this session's work).
- **Protected surface:** byte-unchanged across the batch **except the authorized edits** — `provider-router.py` +
  `ROUTING.md` (v0.3.2 manual_import wiring) and `PROVIDER_CONTRACT.md` (v0.3.3 doc). The glm-api / oauth-cli adapters,
  `WORKER_*_SCHEMA.md`, `.claude/hooks/*`, validators/guards, `dmc-glm-smoke`, and the handbooks are byte-unchanged. The
  v0.3.4–v0.3.9 milestones + the v0.3.9.1 hardening are fully **additive** (no protected edit).
- **Intentionally not committed:** the untracked auto-logged evidence files `.harness/evidence/dmc-v0.3.{1..9}-*.md`
  (excluded by design — the v0.2.6 G3 `.harness/evidence/*.md` pattern enforces this structurally).
- **GLM normalization note (provenance, not a v0.3.x deliverable):** the GLM chat-completion normalization fix
  (`1c3e294`, "normalize glm chat-completion content into worker result schema") is a **pre-existing earlier glm-api
  milestone** (v0.2.1.x), already in published history at/before `00a3480`; the glm-api adapter is **byte-unchanged**
  across the v0.3.1–v0.3.9 batch. Recorded here only for traceability.
- **Provider Access Layer status:** `mock` ✓ · `api_key` (glm-api) ✓ · `oauth_cli` (oauth-cli) ✓ · `manual_import`
  (manual-import) ✓ + routed under contract ✓ — the **provider-access layer is now complete across all three real
  providers**. New **advisory rails loop** (selection → manifest → review → closure → delegation → E2E) ✓, all read-only.

**Next:** (open) — provider-access layer complete and the read-only advisory rails loop is shipped + externally accepted;
no further milestone has begun.
