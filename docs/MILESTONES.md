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

## v0.6.0 — Harness Landscape & Orchestration Taxonomy — CLOSED (2026-06-23)

- **Published:** clean **fast-forward** to `origin/main` (`2e3b106..838ba5e`) — **no merge commit, no force, no history
  rewrite** (`2e3b106` remains an ancestor); **local `main` == `origin/main` == `838ba5e`**. **Review branch:**
  `dmc-harness-taxonomy/v0.6.0 @ 838ba5e` (preserved). This closure note is the immediately-following docs commit.
- **Type:** research / architecture / decision-framework milestone — **NOT** an implementation milestone. **Architecture
  guidance, not enforcement.** Additive only: docs + one inert, read-only structure-check script.

### Why v0.6.0 existed
DMC shipped a substantial bounded-agent substrate bottom-up across v0.1–v0.5. The 2026 agent-harness ecosystem had
converged on patterns DMC had partly reinvented and partly missed. v0.6.0 exists to decide — with evidence, in DMC's own
words — which external harness primitives DMC should **adopt / adapt / reject / defer**, and to define the orchestration
taxonomy the next layer (v0.6.x) is built against. It builds none of them.

### What was researched
A desk survey across **research categories A–I**, each a section of the **Harness Landscape**
(`docs/HARNESS_LANDSCAPE_2026.md`): **A** LazyCodex/OmO · **B** Fablize · **C** FableCodex · **D** SuperClaude &
command/mode frameworks · **E** OpenHands/SWE-agent/Aider-class production agents · **F** skill ecosystems · **G**
prompt-leak & hidden-guardrail lessons · **H** DMC current-state comparison · **I** **Sakana Fugu** (launched 2026-06-22;
grounded in ICLR 2026 papers TRINITY 2512.04695 / the Conductor 2512.04388). External descriptions are pattern-level
own-words; **all Sakana Fugu benchmark numbers (incl. 73.7 SWE-Bench Pro) are recorded self-reported /
independently-unverified** and noted as not derived from the grounding papers.

### What DMC decided to adopt
The visible-gate forms of ideas DMC already holds: a systematic investigation protocol, an evidence-receipt stop hook, the
bounded executor and read-only reviewer role contracts, "evidence is untrusted until inspected," skill-registry security /
**no-blind-install**, and the prompt-leak meta-lesson (prefer **visible gates over hidden behavior modification**).

### What DMC decided to reject
The patterns that violate the visibility thesis: **opaque learned routing as the source of truth for gates** (the Fugu
foil), default **telemetry / auto-update**, **unverifiable token-efficiency claims**, and **default network/live access
with opaque autonomous action**. A reject is recorded as carefully as an adopt.

### What DMC deferred
Valuable but out-of-scope-for-a-docs-milestone primitives: **recursive self-delegation** (only behind a hard, deterministic
depth/budget bound), **hash-anchored / LSP / AST-grep edit precision**, and **coverage accounting** (needs a scope model
first).

### Core orchestration conclusion — "Learn suggestions, encode gates."
The **Harness Landscape**'s *Learned Orchestrator vs Deterministic Control Plane* analysis resolves the central question. In
DMC terms: **encode the gates** — every decision that opens a gate, selects a lane, or authorizes an irreversible action
stays a **visible deterministic script** that is the source of truth, with a **human as the Release Gate**. A
learned/adaptive component may **only suggest** — a capability class, a draft delegation — as **advisory input,
untrusted-until-inspected**, and it **never opens a gate** (the C11 separation). DMC does **not** learn the orchestration
that gates irreversible actions; Fugu's genuine benefit (pool-agnostic, model-name-free routing) is captured by the
deterministic **capability-class** abstraction without the opaque learned router.

### Long-term significance
v0.6.0 codifies DMC's identity — role hierarchy, verification philosophy, release-gate philosophy, orchestration
philosophy — as an explicit, **model-agnostic** reference that v0.6.x/v0.7 build against. Capability classes are named by
capability (model names isolated to a dated, replaceable, non-load-bearing lookup), so the taxonomy survives
frontier-model turnover. The **Benchmark Cards** + **Adoption Decisions** form a durable, ADR-style decision record that
preserves the *reasoning*, not just the outcome.

### Deliverables (4 docs + 1 verifier + 1 report; the plan & Fugu research note are supporting inputs)
- `docs/HARNESS_LANDSCAPE_2026.md` — **Harness Landscape**: sections A–I + the source table + the
  Learned-Orchestrator-vs-Deterministic-Control-Plane analysis.
- `docs/HARNESS_BENCHMARK_CARDS_2026.md` — **Benchmark Cards**: **23 cards** (10-field schema each) —
  **adopt 6 · adapt 12 · reject 2 · defer 3**.
- `docs/ORCHESTRATION_TAXONOMY.md` — **Orchestration Taxonomy**: a **6-role taxonomy** (Strategic Orchestrator ·
  Implementer · Critic/Falsifier · Release Auditor · Verifier · Human Release Gate), a **6-class capability taxonomy**
  (frontier-long-horizon · standard-implementation · cheap-fast · adversarial-review · deterministic-tool ·
  human-only-gate) + a dated replaceable model lookup, and a **7×5 work-delegation matrix** that reduces to the shipped
  v0.5.3/0.5.4/0.5.5 lane logic.
- `docs/DMC_ADOPTION_DECISIONS.md` — **Adoption Decisions**: a **29-decision matrix** — **adopt 8 · adapt 14 · reject 4 ·
  defer 3** — plus **10 explicit anti-goals** (incl. "no opaque learned routing as gate authority" and "no self-reported
  benchmark taken as verified").
- `.harness/evidence/dmc-v0.6.0-verify.sh` — read-only, structure-check-only verifier (`--self-test`), env-free
  content-sensitive `repo_hash`.
- `.harness/verification/dmc-v0.6.0-harness-landscape-taxonomy.md` — verification report.

### Verification & review posture
- `dmc-v0.6.0-verify.sh --self-test` → **18 PASS / 0 FAIL** (V1–V18 + checker negative controls ST1–ST3), `repo_hash`
  before==after (real repo byte-unchanged), re-confirmed on published `main`.
- Independent **5-lens release audit → ACCEPT** (leak/secret/own-words · plan-conformance · verify-script soundness ·
  DMC-identity/anti-admiration · scope/safety). A final **independent commit-gate auditor caught 2 decision-tally
  arithmetic errors** (adapt counts), both **fixed and re-verified**. Publication-surface scan: secret-shape and
  leak-marker **clean**.

### Safety posture
- **No runtime behavior changes. No protected-surface changes** (adapters, `provider-router`, schemas, `.claude/hooks/*`,
  guards, validators, `dmc-glm-smoke` byte-unchanged). **No live provider/model/API call. No network. No `.env` /
  credential read.** The verify script is inert unless flag-invoked.
- **Architecture guidance only** — every doc carries the "architecture guidance, not enforcement" disclaimer; the milestone
  selects no model, opens no gate, installs no hook, authorizes no build.
- **Future candidates require separate plans and gates** — each adopt/adapt/defer card names a v0.6.1–v0.6.9 candidate that
  must pass its own approved plan + human gate before any build. Most decisions are `adapt`/`defer`, not "build now".

**Next:** (open) — the harness-landscape & orchestration-taxonomy reference is on `main`; the named v0.6.1–v0.6.9
candidates are **not** started. No further milestone has begun.

## v0.6.1–v0.6.5 — Control-Plane Layer (six-question traceability) — CLOSED (2026-06-24)

### Why this layer existed
v0.6.0 resolved DMC's identity in docs ("learn suggestions, encode gates") but left the **six governance questions**
answerable only by prose and memory. v0.6.1–v0.6.5 turns that identity into **runnable, deterministic gates**: a control
plane that answers, from artifacts alone and with no model memory, the six questions any reviewer must be able to ask of a
completed unit of work.

### What was implemented (additive; one schema + one input-only validator each)
- **v0.6.1.0 Trace Linkage Contract** (`dmc-v0.6.1.0-trace-linkage.{py,sh}` + `schemas/trace-linkage.schema.md`) — the
  foundation: a `dmc.trace-linkage.v1` record with canonical subject-binding + per-reference re-bind, typed subject-bound
  registers, typed non-dangling edges, the verbatim `kind→producer_milestone_id` table, and the positive-allowlist approval
  namespace. The trust root every other tool composes by read-only subprocess.
- **v0.6.1 Capability-Class Router** (Q1) — a pure `(task_class, role) → capability_class` table; model-name-free,
  model-swap-invariant (enforced by a self-scan), no learned routing.
- **v0.6.2 Evidence Receipt Gate** (Q2) — "no receipt → no DONE"; decidable `artifact_ref` (hex≥16 or safe relative path;
  prose/URL/traversal rejected); cross-subject binding.
- **v0.6.3 Findings Gate** (Q3) — finding states {resolved, accepted-risk, deferred, blocked}; refuses a `blocked` finding
  crossing release; append-only with anti-bypass-by-drop; `accepted-risk` requires a contract-valid human approval waiver.
- **v0.6.4 Goal Ledger** (Q4) — an explicit goal state machine with append-only history; a completion must trace to an
  `approved` goal; anti-bypass-by-rewrite.
- **v0.6.5 Decision Traceability Layer** (Q5/Q6 capstone) — `--answer` validates a complete trace-linkage record via the
  contract, resolves every decision link to a declared entry, and answers Q1–Q6 from artifacts alone (the mandatory
  six-question E2E proof).

### What problem was solved — the six-question metric
At v0.6.5, DMC answers deterministically, with no model memory: **Q1** what capability · **Q2** what evidence · **Q3** what
findings · **Q4** what goal · **Q5** why the decision · **Q6** approval provenance (a contract-enforced `human-release-gate`
authorizer). Any unanswerable question → REFUSE.

### Core architectural conclusion — "Artifacts are the source of truth."
Every governance answer is recomputed from inspectable artifacts by a deterministic, env-free, input-only validator — never
from model reasoning, git state, or ambient memory (`--answer` is byte-identical under `env -i`). The contract is the trust
root; the rest compose it by read-only subprocess.

### Governance conclusion — "Learn suggestions, encode gates."
Every gate is an enumerated set / state machine / static table — **no learned gate authority, no autonomous release** (tools
emit only advisory ALLOW/REFUSE/ANSWERED; none merges, pushes, or tags), **no hidden approval path** (a laundered
critic/Codex ACCEPT cannot answer Q6). The C11 separation holds: advisory components may *suggest*; only the human opens the
release gate.

### v0.6.5a hardening — T7d (non-empty approval-id)
A pre-main micro-patch closed a validator-vs-schema gap: the approval check accepted a bare `human-release-gate:` (empty
auth-id). Reject code **T7d** now requires a non-empty, non-whitespace auth-id after the prefix, at **both** record-mode and
entry-mode — hardening v0.6.3 waivers, v0.6.4 goals, and Q6 transitively. Validator strictness only; backward-compatible
(only empty/blank ids newly reject); no charset/length/auth/crypto (those remain v0.6.6+).

### Honest scope — Q6 records provenance, not authentication
Q6 proves a correctly-shaped, subject-bound, linked **human-release-gate** approval **entry exists** — it records approval
**provenance**, not **authentication**. An input-only / no-crypto / no-network validator cannot authenticate a human; the id
after the prefix is self-asserted (`human-release-gate:<id>` still passes). **Approval authenticity and live-tree anchoring
are upstream — the Human Release Gate remains the sole release authority.** Stronger provenance is the v0.6.6+ mission.

### Deliverables (6 tools + 6 schemas + 6 plans + 6 verification reports + 1 roadmap)
- evidence (each `.py` core + `.sh` wrapper): `dmc-v0.6.1.0-trace-linkage` · `dmc-v0.6.1-capability-router` ·
  `dmc-v0.6.2-evidence-receipt` · `dmc-v0.6.3-findings-gate` · `dmc-v0.6.4-goal-ledger` · `dmc-v0.6.5-decision-trace`.
- schemas: trace-linkage · capability-routing · evidence-receipt · findings-register · goal-ledger · decision-trace.
- per-milestone plans + verification reports; `.harness/plans/dmc-v0.6.1-v0.6.5-roadmap.md`.

### Verification & review posture
- Consolidated self-tests **118 PASS / 0 FAIL** (29+7+18+25+27+12), env-free, repo-byte-unchanged, re-confirmed on
  published `main`.
- Per-milestone DMC `critic` (plan) + DMC `verifier` (build); a Publication Surface Audit (**PASS**) + a 7-dimension
  Main-Publication review (**MAIN READY**); the v0.6.5a patch independently **critic-APPROVE + verifier-ACCEPT**. Codex
  dropped mid-layer (slow/flaky) — DMC critic + verifier only thereafter.

### Safety posture
- Additive only; **no protected-surface change** (adapters, `provider-router`, protected schemas, `.claude/hooks/*`, guards,
  validators). **No live provider/model/API call, no network, no `.env`/credential read.** Every tool is input-only,
  env-free, value-blind (reject-on-match), duplicate-key-rejecting, no-heredoc/no-temp, fail-closed, write-safe `--out`, with
  no git on the operative path. Advisory — the runtime enforcement floor stays the hooks.

### Long-term significance
The six-question model is the durable spine future DMC versions build on: capability classes survive frontier-model turnover
(model-name-free) and answers survive provider/workflow change (artifact-derived); the trace-linkage contract is a reusable
provenance primitive. **v0.6.6–v0.6.9 (Governance Hardening) build on this layer additively** — richer approval provenance,
trace-integrity, cross-gate consistency, and an adversarial acceptance suite — without redesign.

**Next:** (open) — v0.6.6–v0.6.9 Governance Hardening is decomposed and DMC-critic-APPROVED but **not** started; each
milestone requires its own approved plan + human gate. No build has begun.

## v1.0 — DMC v1 Runtime Upgrade (M1–M10) — CLOSED (2026-07-08)

- **Published:** `main` == `origin/main` == `11f26a3` immediately pre-M10 (pre-M10 audit + 16-fix remediation
  fast-forwarded onto `main`, unifying the whole v1 stack — no merge commit, no force push, no history rewrite
  anywhere in the M1–M10 arc). M10 — this identity refresh + closure entry — lands as the milestone's own docs
  commit under the same human plan/build/commit/push gate chain every prior milestone used.

### Why this layer existed
v0.1–v0.6.5 shipped a wide advisory rails/control-plane surface but the runtime enforcement floor stayed thin and
the product still called itself "v0.1" everywhere. The v1 Runtime Upgrade
(`.harness/plans/dmc-v1-runtime-upgrade.md`, Rev 3) exists to build the actual bounded-agent runtime — repo
intelligence, run lifecycle, an orchestration registry, a real Ring-0 enforcement floor, worker/delegation
hardening, a release-gate composer + CI, host installation, and finally an honest v1.0 identity — closing the
pre-v1 audit's ten numbered release blockers (B1–B10).

### What was implemented
- **M1** — docs/design trio (`DMC_V1_AUDIT`, `DMC_V1_RUNTIME_ARCHITECTURE`, `DMC_V1_ORCHESTRATION_MODEL`) + the
  master plan, human-ratified as the build's blueprint.
- **M2** — repository intelligence: `dmc orient` (P1), `landmarks` (P2), `depsurface` (P4), `radius` (P5,
  change-radius prediction).
- **M3** — 6 contract schemas + instance validators + a 55-file `bin/lib` copy-routing, pinning legacy
  `selftest --all` at `tools=49 / PASS=802 / FAIL=3 / N/A=3` (3 human-accepted upstream FAILs, never masked).
- **M4** — run-lifecycle core: 8 primitives spanning P7–P13 + P17 (run start, scope.lock, approvals, the evidence
  ledger + receipts, checkpoints, acceptance, verify-plan, fix-loop/recovery).
- **M5** — the orchestration registry (`orchestration/roles.json` + `models.json`), 6 contract-ized agent roles,
  verdict/delegation validators + verdict-gate, 3 skills bound to `dmc run start`.
- **M6** — Ring-0 hook hardening on the PROTECTED SURFACE: hooks rewired as shims over `bin/dmc` verdict CLIs,
  scope.lock adjudication, bash-radius L0/L1 write-scope floors, postbash-diff, verify-crosscheck, and the stop
  gate — scope/stop/secret enforcement went from advisory to live.
- **M6.5 + M8** — the Codex adapter shipped ADVISORY-only shims (Option A; a spike could not prove hook execution
  turn-free at the time), and the host installer began shipping Ring 0+1 to `--host claude|codex|both`; `dmc doctor`
  keeps the honesty split ever since — Claude hook execution is proven by a synthetic probe, the Codex column stays
  ADVISORY only.
- **M7 + M9** — worker/delegation hardening made the apply-authorization chain (review-check → authorize →
  apply-check → fidelity) skill-mandated at runtime (M7, the honest tier — Ring-0/1 does not itself block a
  chain-less Edit/Write); the release-gate composer `dmc gate release --full` (9 sub-gates, 39/0) +
  `.github/workflows/dmc-ci.yml` (13 blocking checks + advisory legacy replay) then made chain-absence BLOCKING
  at release (M9).
- **Pre-M10** — a full-project audit + 16 Tier-1/2/3 fixes across 19 files (`6d571a8`), then the fast-forward main
  unification landing the whole stack on `main` at `11f26a3`.
- **M10** — final docs + the v1.0 identity refresh, three new honesty docs (`DMC_V1_ENFORCEMENT_MATRIX`,
  `DMC_V1_HONEST_SCOPE`, `DMC_V1_RELEASE_CHECKLIST`), the B1–B10 audit-blocker traceability table, and this
  closure entry.

### What problem was solved
DMC went from an advisory rails/control-plane prototype still labeled "v0.1" to a runtime with a real write-scope
enforcement floor, an honest per-harness tier split, an accountable worker-bridge, a single release-readiness
composer + CI boundary, and documentation matching what ships — closing all ten audit blockers B1–B10: nine by
shipped mechanism, one (B8, tracked-backup/zip repo hygiene) by an explicit, human-ratified deferral to a future
cleanup milestone.

### Deliverables
`bin/dmc` (single Ring-0 dispatch entry point); `bin/lib/` primitives (repo-intel, run-lifecycle, orchestration,
hook shims, worker-bridge validators, `dmc-release-gate.py`); `.harness/schemas/` contract set;
`orchestration/{roles,models,harness-matrix}.json`; `.claude/hooks/**` (Ring-0 shims); `adapters/codex/**`
(Option A advisory shims); `.claude/install/**` + uninstaller + `dmc doctor`; `.github/workflows/dmc-ci.yml`;
the 5 M10 identity/honesty docs; `.harness/verification/dmc-v1-runtime-upgrade.md` (B1–B10 traceability).

### Verification & review posture
Every milestone: milestone-scoped plan → non-authoring critic → human plan gate → an armed, scope-locked run with
synchronous Opus/Sonnet executors → independent verifier (own probes + own committed-replica run) →
committed-replica `selftest --all` at 802/3/3 EXACT → human commit gate → live post-commit `--all` re-run at
802/3/3 EXACT as the closure proof. `.github/workflows/dmc-ci.yml` went green on the branch at M9 (Actions run
`28899008386`), carried unchanged into M10.

### Safety posture
CF14 (CI-baseline-portability) is ratified as **option (b)**: the pinned 802/3/3 legacy baseline is a
maintainer-local/committed-replica-scoped dev-environment artifact, formalized as an advisory CI tier alongside a
documented CI-tier baseline — the 13 substantive M9-built blocking checks are never weakened. D1 (~20 frozen
tools' bare-BSD-md5 self-asserts, vacuous on any non-BSD-md5 host) is documented, not hardened, for v1.0 — the one
site masking a security invariant (`bin/lib/dmc-v0.2-verify.sh:15-17`) is named explicitly in
`docs/DMC_V1_HONEST_SCOPE.md`. The frozen `bin/lib/dmc-v0.*` tools + their `.harness/evidence/` originals
(55 files) are KEPT canonical (M3 rollback + mirror-check depend on them). No live provider/model/API call at any
milestone; no `.env*`/credential read; every worker result stays proposal-only (never `git apply`/`patch`).

### Long-term significance
v1.0 is the point where DMC's stated identity and its actual runtime behavior converge: a real Ring-0 write-scope
floor, a per-harness tier split that is never uniform across Claude and Codex (advisory-only on Codex, documented
not claimed), an accountable worker-bridge chain, and a single release-readiness composer any future milestone
must pass. The disclosed-not-hidden posture (CF14, D1, the M7/M9 honest tiers) is the durable pattern: v1.1+ work
extends this floor rather than re-deriving it.

**Next:** v1.1+ deferred register — cryptographic approval authentication (the former v0.6.6 Governance Hardening
mission, folded in per `docs/DMC_V1_RUNTIME_ARCHITECTURE.md`'s Deferred register), worker-bridge expansion, the
P5 change-radius benchmark, the CF14 option-(a) frozen-tool portability hygiene plan, and D1 hardening — per
`docs/DMC_V1_HONEST_SCOPE.md` and the master plan's own Deferred register. **This supersedes the prior trailing
"Next:" pointer immediately above** (v0.6.6–v0.6.9 Governance Hardening, "decomposed and DMC-critic-APPROVED but
not started") — that mission never shipped standalone; it folded into this same v1.1+ register instead.

## v1.0.1 — Natural-Activation Tuning — CLOSED (2026-07-08)

### Why this layer existed
The v1.0 lowercase-only suffix triggers (`dmc` / `dmc-plan` / `dmc-off`) felt mechanical against mixed-case or
non-English-punctuated prompts, and a co-installed orchestration layer (OMC) could fire its own hooks on the same
turn with no structural way to suppress it. `.harness/plans/dmc-v1.1-activation-tuning.md` (Rev 2, task namespace
DMC-T018.*) ratified three activation-UX fixes: case-insensitive triggers, an opening signature line on the `dmc`
route, and an instruction-level DMC-priority clause.

### What was implemented
Case-insensitive suffix triggers landed in strict Claude/Codex lockstep — `.claude/hooks/dmc-router.sh` moved to
`grep -Eqi` matchers, `adapters/codex/dmc-codex-userpromptsubmit.py` to `re.IGNORECASE`, and both sides'
task-extraction strips went case-insensitive via portable char-class sed (`[Dd][Mm][Cc]`) and
`flags=re.IGNORECASE` so a mixed-case trigger no longer leaks into the routed task string. The `dmc`/ultrawork
route now opens every reply with the exact signature `Okay, Let me do you Coding!` (a deliberate Do-Me-Coding
wordplay), reinforced unconditionally in `dmc-ultrawork/SKILL.md` for direct slash invocations. An
instruction-level **DMC PRIORITY** clause asserts DMC's routing is authoritative over any other orchestration
layer whose hooks also fired that turn, documented honestly as instruction-level (not a structural suppression)
in `CLAUDE.md`, DMC.md, and a new `## Precedence when both fire` section in `docs/OMC_COEXISTENCE.md`. A NEW
34-row CI-blocking cross-adapter parity section (A16) was added to the m65-suite, closing the prior zero-tripwire
gap where nothing enforced router/shim parity for natural activation.

### Verification & review posture
Plan → non-authoring critic r1 REJECT (`.harness/evidence/dmc-v1.1-critic-r1.json`) on two empirically proven
gaps — an unsatisfiable no-regression gate against the manual v011 harness, and a mixed-case task-token leak —
folded into Rev 2 → critic r2 APPROVE, 0 blockers (`.harness/evidence/dmc-v1.1-critic-r2.json`) → human plan gate
→ scoped, synchronous Opus/Sonnet build. `bin/dmc selftest m65-suite` cross-adapter parity file:
`test-codex-shims.sh: 99 PASS / 0 FAIL`; the full release gate plus committed-replica and post-commit live
`selftest --all` at the pinned 802/3/3 legacy baseline are recorded in
`.harness/verification/dmc-v1.0.1-activation.md` at closure.

### Safety posture
Suffix-only and mid-sentence-never-fires stayed true throughout (anchor regex preserved under case-folding);
DMC-priority is framed honestly as instruction-level best-effort in `docs/DMC_V1_HONEST_SCOPE.md`'s disclosed-
residual register — Claude Code merges hook arrays from all installed plugins, so no structural suppression lever
exists. All frozen surfaces (the 55-file mirror, the `hooks-v0.6.5` fixture, `bin/lib/dmc-release-gate.py`) stayed
untouched; the known-baseline delta against the manual v011 harness (39/2 on unpatched HEAD) is documented, not
"fixed," per the plan's Rev 2 fold.

**Next:** the DMC constitution refresh (a same-day follow-up cycle); the v1.1+ deferred register from the v1.0
entry above is unchanged by this patch.

## Stray-file hygiene execution (B8 closure) — CLOSED (2026-07-08)

- **What shipped:** the six repo-hygiene strays reserved by audit-blocker B8 — the four `_DMC_*.md` bootstrap
  docs, `do-me-coding-v0.1-scaffold.zip`, and the retired v0.2.1 `dmc-glm-smoke` live smoke runner — were removed
  under a separately-approved hygiene cycle, closing B8's deferred cleanup.
- **Companion edits:** `bin/lib/dmc-repo-intel.py` dropped the `dmc-glm-smoke` `classify_landmark` special-case
  (L1f converted to a negative control asserting its absence); `AGENTS.md` regenerated via `dmc agents-md`; the
  DMC repo's own `.gitignore` extended with the two `dmc-run-*` per-run auto-log patterns (the now-moot scaffold
  zip line dropped); 3 orphan pre-M4 run notes deleted locally per policy.
- **Identity:** no version bump — DMC identity stays v1.0.
- **Verification & review posture:** plan `.harness/plans/dmc-stray-hygiene.md`; non-authoring critic chain r1
  REJECT → r2 REJECT → r3 APPROVE; scope-locked, synchronous execution under run `dmc-run-8f34d637a6f2`.
- **Registered deferral (v1.1+):** `.harness/schemas/landmarks.schema.md:34` still words the seed union as
  including `dmc-glm-smoke` — a live II.5 contract surface deliberately NOT edited in this cycle (schema
  amendments take their own Article III cycle); one-line reword ("historically included …, removed by the
  human-gated hygiene cycle 2026-07-08") registered here for the v1.1+ deferred register.

## Codex App enablement + Option-B live-turn dispatch test — CLOSED (2026-07-09)

- **What shipped:** `adapters/codex/dmc-codex-dispatch-probe.py` (a repo-internal names-only
  diagnostic, NOT shipped — absent from `CODEX_ADAPTERS`) plus an `AGENTS.md` landmark regen,
  commit `34effc7`; probe wiring existed ONLY in a throwaway clone, and the shipped `.codex/`
  templates stayed byte-unchanged all cycle.
- **Option-B execution:** the M6.5-reserved one-time human-run consented live turns (wjlee), on an
  isolated clone (`--no-hardlinks`, remote severed, pointer-free) — an App turn and a CLI contrast
  turn.
- **Result:** at cli 0.132.0 with `/hooks` trust granted, all five wired lifecycle events
  DISPATCHED and both envelope classes were HONORED (deny surfaced + blocked the rm-based probe
  twice with zero execution; the dmc-suffix routing context was applied verbatim incl. the
  signature greeting; the mode-file side effect appeared); the full envelope key-name schema was
  captured, closing the M6.5 field-name gap. At App build 26.623.61825 the Hooks panel does not
  surface project-level hooks — no trust affordance ⇒ hooks skipped ⇒ zero dispatch (machine
  nulls + user + App-log corroborated); Ring-2 (`AGENTS.md` guidance) WAS respected by the App
  session.
- **Posture:** NO promotion (D5) — every documented tier claim stands unchanged; this entry
  records observations only.
- **Registered candidates (v1.1+):** a Claude router multi-line suffix-anchor defect (a
  line-terminal trigger token in pasted multi-line prompts routes the whole message); the App
  hook-trust affordance gap (document CLI-side `/hooks` as the trust path; re-test future App
  builds); a Codex-side coexistence doc incl. the observed foreign-layer clone-config mutation;
  the deny-message "suspend" step-aside wording; `.codex/`'s ordinary classification in repo-intel.
- **Chain:** plan Rev 3; critic r1 NEEDS_CLARIFICATION → r2 REJECT → r3 APPROVE; independent
  verifier PARTIAL → corrections-applied (three factual count/omission defects in the first
  evidence version, corrected with provenance); run `dmc-run-ce3c5ba0d8d7`; evidence
  `.harness/evidence/dmc-codex-app-optionb-20260709.md`.

## v1.0.2 — router whole-prompt suffix anchor (multi-line stabilization) — CLOSED (2026-07-09)

- **Defect:** the Claude router matched trigger tokens with line-oriented grep/sed, so ANY
  interior line ending in a trigger token routed a multi-line prompt (observed live twice on
  2026-07-09 with pasted transcripts; sandbox-reproduced). The Codex UPS shim already had
  whole-string semantics — the documented "suffix-only" contract was violated on the Claude side
  only.
- **Fix:** `.claude/hooks/dmc-router.sh` trigger path rebuilt with whole-string POSIX mechanics
  (parameter-expansion trailing strip, tr lowercase, case-glob arms incl. bare token-only
  alternatives, fixed-length task strip); emit strings/mode writes/env-var parse byte-unchanged;
  grep/sed removed from the trigger path (strictly more portable).
- **Tripwire:** A16 UPS cross-adapter parity extended with 7 multi-line + token-only sub-blocks
  (44 assertions; suite 99→143/0, both adapters driven on identical prompts, parity-equal incl.
  embedded-newline task segments).
- **Baselines:** v011-verify 39/2 with all 5 router-invariant rows green (2 known non-router FAILs
  unchanged, never gated ALL-PASS); frozen hooks-v0.6.5 fixture untouched (its unwired comparator
  stays red by design).
- **Chain:** overnight autonomy envelope (wjlee, pre-sleep AskUserQuestion; AUTONOMY.md
  autonomous-local-commit on the dedicated branch); critic r1 APPROVE first-round (envelope ruled
  III.2(3)-compatible; 36/36 case-glob↔regex byte-parity empirically verified); run
  `dmc-run-c670495342e1`; LOCAL commit only — push/CI/main-FF reserved to the morning human gates.
