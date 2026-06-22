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

## v0.4.0–v0.4.9 — Autonomous Development Mode (control plane) — CLOSED (2026-06-22)

- **Published:** fast-forwarded to `origin/main` (`8dc5b59..58cdbc5`); local `main` == `origin/main` == `58cdbc5`. Main
  publication is **complete** (fast-forward only). The whole stack is **additive vs the previous `main`**: **22 files,
  +1524 / −0**. Shipped as a delegated, batch-reviewed stack with a multi-round independent falsification review.
- **Review branch:** `review/dmc-v0.4.0-v0.4.9-autonomy` (head `58cdbc5`) — retained (not deleted). Prior
  `review/dmc-v0.3.1-v0.3.9-stack` preserved, untouched, @ `5aecdbc`.
- **What shipped** (every component is **advisory / read-only** — none stages, commits, pushes, grants a gate, makes a
  live/network call, or mutates the provider surface; all writes are canonicalization-guarded `--out` files or `mktemp`
  self-test repos; the autonomy stack is **inert unless explicitly invoked** by flag):
  - **v0.4.0 Autonomy Charter** — `AUTONOMY.md` + `.harness/schemas/autonomy.schema.md`: five autonomy levels (passive →
    advisory → autonomous-dry-run → autonomous-local-commit → human-gated-push), per-level allowed/blocked actions, an
    always-blocked set, and nine fail-closed stop conditions; orthogonal to the `.harness/mode` enforcement floor.
    **8 PASS / 0 FAIL.**
  - **v0.4.1 Goal-to-Plan Compiler** — deterministic, env-independent (`env -i` + credential-var differential
    byte-identical) goal→run-plan compiler that always keeps push + closure + live-call + credential human-gated and
    value-blind-redacts token-shaped goal text. **7 PASS / 0 FAIL.**
  - **v0.4.2 Branch / Worktree Isolation Guard** — metadata-only git; blocks main/master outside closure, detached HEAD,
    and a dirty worktree (or dirty-outside-approved-scope) before any edit. **8 PASS / 0 FAIL.**
  - **v0.4.3 Scope / Over-eager Guard** — names-only/`--numstat`, value-blind protected-surface diff classifier
    (allowed/suspicious/blocked) covering out-of-scope edits, out-of-scope deletions, broad rewrites, non-append
    `MILESTONES.md` mutation, branch/review-branch mutation attempts, and over-eager file/deletion/line bounds.
    **14 PASS / 0 FAIL.**
  - **v0.4.4 Evidence Harness** — standardized self-test count/command/result extraction with a value-blind redactor and
    an honest, non-absolute attestation (known shapes only; not a completeness guarantee). **9 PASS / 0 FAIL.**
  - **v0.4.5 Secret / Network / Live-call Guard** — fail-closed STATIC classifier of candidate command text (never
    executes it) for secret-path reads, live-provider opt-in flags, and network tools incl. `/dev/(tcp|udp)/`.
    **21 PASS / 0 FAIL.**
  - **v0.4.6 Reviewer Loop** — self-review artifact (findings/risk/files/tests/evidence/open-questions) that is **never
    auto-applied**, plus a Codex/Kim external-review handoff template. **8 PASS / 0 FAIL.**
  - **v0.4.7 Context Map** — `docs/CONTEXT_MAP.md` single-source pointer index + configuration-smell checklist; one
    minimal +1-line `AGENTS.md` discoverability pointer (no rule duplication, no conflicting mode instructions).
    **7 PASS / 0 FAIL.**
  - **v0.4.8 LazyCodex / Claude Code Interop** — `docs/INTEROP.md` mapping DMC to Claude Code hooks/subagents/plugins +
    LazyCodex-style workflows with five suggested hook points; **no runtime dependency**. **6 PASS / 0 FAIL.**
  - **v0.4.9 Autonomous Dry-Run Capstone** — composes the full v0.4 loop offline in a `$TMPDIR` repo (goal → plan →
    isolation → scoped fixture edit → guards → evidence → self-review → no-push → closure DRAFT), asserting the
    production repo stays byte-unchanged with no false-green. **9 PASS / 0 FAIL.**
- **Review & hardening** (independent, falsification-focused, multi-round):
  - **Full v0.4 suite: 10/10 green · 97 assertions, 0 FAIL** (8+7+8+14+9+21+8+7+6+9), all exit 0 — re-confirmed on
    published `main`.
  - **F1 redaction attestation fixed** (v0.4.4 + `evidence.schema.md`): the unconditional "no secrets / env-values /
    abs-paths / provider payloads" claim was the sole MAIN gate; replaced with an honest known-shapes-only / "not a
    completeness guarantee — review before commit" attestation, and the redactor broadened (bare `password=`/`token=`/
    `secret=` fragments, provider-payload content fields, `C:\Users\` paths).
  - **F3 `/dev/tcp` `/dev/udp` detection added** (v0.4.5): bash pseudo-device exfil now classifies BLOCKED.
  - **F4 output-path guard fixed at BOTH root causes** (v0.4.9): RC1 — `ROOTDIR` now derives from the script location
    (`SELFPATH`), not the process CWD, with a hard-fail if the derived root is not a git worktree; RC2 — `out_refused`
    rejects symlinked targets, fails closed on an unresolved parent, and explicitly rejects git-tracked paths. Verified
    refused from the repo CWD **and** from `/tmp`; self-test passes from both; production repo byte-unchanged.
  - **F5 force-push detection hardened** (v0.4.3): force flags after the refspec and `git push` line-continuations now
    BLOCKED.
  - **F7 scope / closure cleanup** (v0.4.3): trailing-slash scope entries normalized (no prefix-confusion); `--closure`
    wired to the `MILESTONES.md` append-only rule (and properly narrow — does not bypass scope/branch guards).
- **Safety confirmations:** **no force push** (every publish a fast-forward — the v0.4 stack on `8dc5b59`, then
  `1a793f0`, `58cdbc5`, and `8dc5b59..58cdbc5` to `main`); **no branch deletion**; **no live provider call**; **no
  `.env` / credential / token / secret read**; **no network/model-API call** beyond approved git fetch/push; and **no
  milestone closure recorded before this explicit gate**.
- **Known advisory notes** (honestly disclosed, non-blocking — each is an *advisory* pre-flight backstopped by the
  runtime hooks `secret-guard.sh` / `pre-tool-guard.sh`, and DMC never autonomously pushes):
  - the **scope/over-eager guard is content-blind** — manually copied protected logic placed at a benign in-scope path
    is not detected by a names-only diff; out-of-band content review remains required;
  - the **static secret/network/live classifier is advisory** — interpreter/flag/indirection reads and `+refspec` /
    `--force-with-lease=` force forms can evade the static text scan; the fail-closed runtime guards are the load-bearing
    enforcement;
  - **evidence redaction is for known shapes only** and is **not a completeness guarantee** — a human must review an
    artifact before committing it.
- **Intentionally not committed:** the untracked auto-logged evidence files `.harness/evidence/dmc-v0.2.*.md` /
  `dmc-v0.3.*.md` (the v0.2.6 G3 `.harness/evidence/*.md` pattern excludes these structurally); the v0.4 stack uses the
  embedded `--self-test` harnesses as its evidence (no separate `.md` artifacts).
- **Closure statement:** the **v0.4.0–v0.4.9 lifecycle is closed end-to-end after this entry** — plan → scope → isolated
  branch → scoped additive edits → evidence → independent review → human-gated review-branch push → human-gated
  fast-forward to `main` → this append-only closure note. Pending commit/push approval (drafted, not yet committed).

**Next:** (open) — the autonomous-development control plane is shipped on `main` and externally accepted; no further
milestone has begun. Activating any autonomy level beyond `autonomous-dry-run` for real work remains a separate,
explicitly-scoped human gate.

## v0.5.0–v0.5.2 — Performance & Efficiency Control Plane — CLOSED (2026-06-22)

- **Published:** fast-forwarded to `origin/main` (`464bf33..cce9e31`); local `main` == `origin/main` == `cce9e31`. Main
  publication **complete** (fast-forward only, no merge commit). The whole stack is **additive vs the previous `main`**:
  **6 files, +806 / −0**. Where DMC v0.4 made autonomous development *safe*, v0.5 makes it *measurable & efficient*.
- **Review branch:** `review/dmc-v0.5.0-v0.5.2` (head `cce9e31`) — retained (not deleted). Prior review branches
  preserved: `review/dmc-v0.4.0-v0.4.9-autonomy` @ `58cdbc5`, `review/dmc-v0.3.1-v0.3.9-stack` @ `5aecdbc`.
- **What shipped** (every tool is **advisory / read-only**, **inert unless explicitly invoked** by flag — none stages,
  commits, pushes, grants a gate, mutates the provider surface, reads the environment / `.env` / credentials, or makes a
  network/live call; all writes are canonicalization-guarded `--out` files or `mktemp` self-test repos):
  - **v0.5.0 Run Metrics Ledger** (`52c924b`) — `.harness/evidence/dmc-v0.5.0-run-metrics.sh` +
    `.harness/schemas/run-metrics.schema.md`: validates a per-run efficiency record (run_id / goal_type / mode / effort /
    token+tool+wall-clock counts / test counts / findings / blockers / retries / human_gates / outcome / notes) and emits
    a **redacted** ledger artifact. Fail-closed validation (missing field / non-numeric numeric / bad enum / inconsistent
    test counts ⇒ REFUSED); value-blind free-form redaction. **12 PASS / 0 FAIL.**
  - **v0.5.1 Context Budgeter** (`49a872d`) — `.harness/evidence/dmc-v0.5.1-context-budgeter.sh` +
    `docs/CONTEXT_BUDGET.md`: classifies candidate context into tiers (required / useful / optional / forbidden /
    excluded) per goal, estimates context weight, and reports budget overflow loudly (WARNING + exit 3). Secret-bearing
    files are **path-derived forbidden** (never loaded / never read). **10 PASS / 0 FAIL.**
  - **v0.5.2 Effort Controller** (`30b6495`) — `.harness/evidence/dmc-v0.5.2-effort-controller.sh` +
    `docs/EFFORT_POLICY.md`: recommends the minimum sufficient effort (light / standard / deep / adversarial) +
    reviewer/adversarial flags + verification depth — docs-only ⇒ light; guard/safety/protected ⇒ deep; secret/network/
    live or security ⇒ adversarial; repeated findings ⇒ adversarial. **14 PASS / 0 FAIL.**
  - **Hardening** (`e06eb31`) — closed the Opus adversarial pass's two HIGH findings + the disclosed MEDIUM/LOW notes
    (see below), each with a regression test.
  - **REVISE fix** (`cce9e31`) — removed the env-controlled hash command (`DMC_HASH_CMD`) from all three scripts;
    `repo_hash` is now a deterministic internal `git status --porcelain | python3 hashlib.sha256` with **no env read**,
    regression-tested (a hostile `DMC_HASH_CMD` is never read/executed) and caught by a tightened structural audit.
- **Verification posture:** **36 self-test assertions, 0 FAIL** across the three tools (12 + 10 + 14), all exit 0 —
  re-confirmed on published `main`. **Offline / read-only / env-independent**: self-tests run only in `mktemp` temp repos /
  fixtures (real repo byte-identical); `env -i` + credential-var differential byte-identical. **No live provider call; no
  `.env*` / credential read; no network / model-API call.** The stack passed an Opus implementer pass + an Opus
  adversarial verification pass + an external review.
- **Review findings closed:**
  - **v0.5.1 map-injection** (HIGH) — `tier_of()` now derives `forbidden` from the **path** (mirror of the secret-name
    patterns), so a mislabeled `--map` category can no longer route a secret file into the loaded tiers.
  - **v0.5.2 fail-open risk parsing** (HIGH) — inputs parse **fail-closed**: a non-false-y danger boolean escalates, an
    unrecognized/case-variant `risk_class` ⇒ adversarial, and an unparseable count escalates.
  - **v0.5.0 redactor blind spots** (MEDIUM) — value-blind `UNSAFE` set broadened (`github_pat_` / `glpat-` / `npm_` /
    `AIza` / `dop_v1_` / `AccountKey=` / short-`AKIA` / bare `password=` / `api_key=` / `client_secret=`).
  - **v0.5.0 markdown injection / `Infinity`** (LOW) — newlines collapsed in free-form fields; non-finite
    `wall_clock_sec` rejected.
  - **External review blocker** — `DMC_HASH_CMD` / env-controlled hash command removed and regression-tested (`cce9e31`).
- **Safety confirmations:** **additive-only** over prior `main` (`+806 / −0`, 6 new files); **advisory/read-only** tools;
  **inert unless invoked**; **no force push** (every publish a fast-forward); **no branch deletion**; **no live
  provider/model/API call**; **no `.env*` / credential read**; auto-log `.harness/evidence/*.md` remain
  **untracked/excluded**.
- **Remaining caveat:** the v0.5 controls are **advisory, not enforcement** — they classify/recommend; the runtime hooks
  `secret-guard.sh` / `pre-tool-guard.sh` remain the real enforcement. Redaction is **best-effort, not a completeness
  guarantee** — a split or novel-prefix secret can still evade; a human must review an emitted ledger before committing it.

**Next:** (open) — the performance/efficiency control plane is shipped on `main`; **v0.5.3 or v0.6.0 should be separately
planned (not started here)**. No further milestone has begun.

## v0.5.3–v0.5.9 — Dynamic Workflow Control Plane — CLOSED (2026-06-22)

- **Published `main`:** `4fa230d` · **base before stack:** `ece6a9a` · **review branch:**
  `review/dmc-v0.5.3-v0.5.9-dynamic-workflow @ 4fa230d` (preserved).
- **Publication:** clean **fast-forward** to `main` (`ece6a9a..4fa230d`) — **no merge commit, no force push, no history
  rewrite** (`ece6a9a` remains an ancestor of `main`).
- **Scope shipped** (seven additive, advisory/read-only tools under `.harness/evidence/`, each with an embedded `--self-test`):
  - **v0.5.3 Dynamic Workflow Selector** — smallest-sufficient lane from explicit task facts; fail-closed on missing/non-canonical
    danger facts; `provider_target=mock` is a category error; `run_mode=mock` is informational and never lowers the lane.
  - **v0.5.4 Workflow State Machine** — transition validator + E2E-`DONE` evaluator bound to immutable run facts; every verdict
    carries an in-output advisory disclaimer.
  - **v0.5.5 Verification Planner** — minimal-sufficient required/optional/forbidden checks; union/monotonic; lane displayed
    canonical-only.
  - **v0.5.6 Review Packet Generator v2** — names-only review packet from git metadata; **value-blind by structure** (paths
    `<bucket>/[name].<ext>`, subjects reduced to a conventional type-class or `[subject withheld]`); no body / no diff.
  - **v0.5.7 Resume Recovery Controller** — next-safe-action after interruption; never "safe to push" — only a commit-bound
    `needs_human_gate` candidate; fail-closed.
  - **v0.5.8 Dynamic Delegation Harness** — 4-role handoff + gate matrix; critic PASS is advisory, never a release grant;
    push/main/closure stay human-gated even under an ACTIVE bounded batch.
  - **v0.5.9 Dynamic Workflow Acceptance Suite** — capstone composing v0.5.3–v0.5.8 offline over 7 synthetic scenarios.
- **Quality bar:** **7/7 self-tests green — 133 PASS / 0 FAIL** (20 + 22 + 22 + 17 + 18 + 19 + 15), all exit 0, re-confirmed on
  published `main`. **C1–C11 adversarial invariants HOLD** (independent multi-agent falsification, all high-confidence).
- **Important resolved findings (REVISE cycle):**
  - **C11 (approval-gate separation)** — `CRITIC→APPROVED` no longer flips on critic PASS alone; an explicit
    `approval_authorized` fact (human Release Gate or active bounded-batch scope) is required; approval is never inferred from
    run state.
  - **C5 (lane leak, v0.5.5)** — the displayed lane is **canonical-only / value-blind**: an unrecognized/token-shaped lane
    renders as `[unrecognized]`, never echoed raw.
  - **C5 (review packet, v0.5.6)** — re-architected to emit **structural value-blind metadata only** (raw basenames + subject
    text withheld), defeating arbitrary novel secret shapes rather than enumerating token prefixes.
  - **C7 (`--out` path guard)** — refuses existing / system / in-tree / tracked / home-dotfile / symlink (target & parent) /
    traversal targets, and the `.env`-class refusal is **case-insensitive** (`.env` / `.ENV` / `prod.ENV` / `.ENV.LOCAL`).
  - **GitHub Push Protection** — the blocked push was resolved by **scrubbing synthetic provider-shaped fixture literals from
    the local-only commits** (after the published review head) via a non-force, FF-preserving rewrite; **no GitHub unblock URL
    and no Push-Protection override were used**.
- **Safety posture:** **additive** dynamic-workflow artifacts only (`+2392 / −0`, 29 files over the prior `main`);
  **advisory / read-only**, inert unless explicitly invoked; **no live provider/model/API call**; **no `.env*` / credential
  read**; **no protected-surface mutation** (no adapter / provider-router / schema / hook / guard / validator / `dmc-glm-smoke`
  change); auto-log `.harness/evidence/*.md` remain **untracked / excluded**; `repo_hash` is env-free
  (`git status --porcelain | python3 hashlib.sha256`).
- **Remaining caveat:** these v0.5.3–v0.5.9 controls are **advisory, not enforcement** — they select / validate / recommend;
  the runtime hooks `secret-guard.sh` / `pre-tool-guard.sh` remain the real enforcement. Value-blind emission is structural and
  strong, but a human must still review an emitted packet before acting on it.
- **Gate status:** review branch **preserved** (`@ 4fa230d`); closure **recorded by this docs commit**; **next work not
  started**.

**Next:** (open) — the Dynamic Workflow Control Plane is shipped on `main`; **v0.6.0 (or the next milestone) should be
separately planned (not started here)**. No further milestone has begun.
