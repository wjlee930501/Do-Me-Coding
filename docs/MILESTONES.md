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

## v1.0.3 — generator & classification hardening — CLOSED (2026-07-09)

- **§7 native emission:** the companion-docs paragraph is now emitted natively by the generator
  (`bin/lib/dmc-agents-md.py`), PRESENCE-GATED on the three companion docs (`AUTONOMY.md`,
  `docs/CONTEXT_MAP.md`, `docs/DMC_CONSTITUTION.md`) so host-generated output gains nothing absent
  them — closing the dangling-reference discipline gap; the 3×-reproduced regen-loss class and its
  hand-re-add standing rule RETIRE. Module selftest 24→26 with a host-shape negative row.
- **`.codex/` classification:** `bin/lib/dmc-repo-intel.py` now classifies `.codex/config.toml`
  and `.codex/hooks.json` as enforcement in repo-intel (landmarks 187→189; selftest 11→13 incl.
  both-file L1g rows); future scope.locks touching `.codex/` REFUSE without explicit landmark
  authorization — end-to-end drill proven.
- **Registered deferral closed:** the `.harness/schemas/landmarks.schema.md` seed-union reword
  registered at the stray-hygiene closure (docs/MILESTONES.md:662) is EXECUTED, closing that
  v1.1+ deferral.
- **AGENTS.md regen:** regenerated via `dmc agents-md` — §4 gains the two `.codex/` rows and §5's
  enumeration gains both paths; §7 reproduces the committed companion-docs paragraph
  byte-identically (native emission, no hand-fix needed).
- **Chain:** overnight envelope; critic r1 REJECT (a host dangling-reference catch) → Rev 2 folded
  in the presence-gate → critic r2 APPROVE; scope-locked, synchronous execution under run
  `dmc-run-c9a159039747`; LOCAL commit only, morning gates pending.

## v1.0.4 — Codex interop & coexistence documentation — CLOSED (2026-07-09)

- **What shipped:** the SHIPPED `docs/OMC_COEXISTENCE.md` gained a `## Codex coexistence` section
  (layer-merge standing facts; observed contenders OMX + omo in dated pinned "Observed" callouts;
  the observed foreign-layer write into a project `.codex/config.toml`; the trust asymmetry at App
  build 26.623.61825 vs cli 0.132.0; precedence extended instruction-level with the single blessed
  HONEST_SCOPE breadcrumb — dangling-reference law honored, 1 non-bundled ref total).
- The repo-internal `docs/CODEX_ADAPTER.md` gained the `[OPTION-B-OBSERVED 2026-07-09]` addendum
  (5/5 dispatch markers + both envelope classes honored in the one consented session; captured
  envelope key-name schema; Bash-only tool taxonomy; App findings; CLI /hooks trust path) + an
  inline dated closure tag on the superseded spike-addendum field-names bullet.
- `docs/DMC_V1_HONEST_SCOPE.md` §4: v1.0.4 register subsection appended (observed-on-cli record +
  App trust-affordance gap, both OBSERVATION-ONLY with the D5 no-change line) + a compact dated
  closure sub-note under M6.5 item-10(e). Append-only +5/-0.
- **Constitution line-pin drift** (record for a future constitution-hygiene amendment):
  HONEST_SCOPE grew 149→154 lines; the constitution's pins into this file shift — `:103`→`:104`
  (+1), `:122-129`→`:127-134` (+5); `:79`, `:29-30`, `:65-68`, `:70-73` unchanged. IV.3's own
  append duty makes this drift unavoidable; refresh the pins in the next constitution amendment.
- **Posture:** NO tier/posture/code change (D5) — observations recorded into the operating docs
  only.
- **Chain:** overnight envelope (third and final cycle); critic r1 APPROVE first round
  (dangling-law + promotion-line + IV.3 rulings); run `dmc-run-9885068dc4d9`; LOCAL commit only,
  morning gates pending.

## v1.0.5 — AGENTS.md generator compaction — CLOSED (2026-07-09)

- **What/where (two generator edits + two guards, all in `bin/lib/dmc-agents-md.py`):**
  - **A1 dedup §5:** the §5 "Protected surfaces" render re-inlined the full protected-class
    landmark path list a SECOND time (~8.5 KB comma-joined blob, already tagged "(see section 4)").
    Replaced with a COMPACT cross-reference — the "(see section 4)" pointer plus a per-class count
    (`N enforcement / M contract / K release landmarks.`). §5's secret-pattern bullets + bindings
    line are untouched, so §5 stays non-empty and VALID.
  - **A2 inventory-last reorder:** emission order is now **[1,2,3,6,7,8,9,10,4,5]** — §4
    (Architecture landmarks) and §5 (Protected surfaces) relocate to the tail, after §10. Every
    section keeps its pinned numeric label + title; only §4/§5 move (1,2,3,6,7,8,9,10 stay
    contiguous & in numeric order). The behavioral rules (§7) and stop conditions (§9) now sit
    physically before the big inventory, so a host truncating past its byte cap drops the inventory
    tail, not the rules. Validator is order-independent (`split_sections` keys by number) → VALID.
  - **Count-parity guard (PC1):** a new module selftest parses §5's rendered per-class counts and
    compares them to counts re-derived straight from the RENDERED §4 landmark list (not from the
    same `facts` object) — a wrong/off-by-one compacted §5 count can no longer pass. Module
    selftest 26 → 27.
  - **Fixture order-independence (critic r1 B1, BLOCKING):** every physical-order-dependent
    negative control was rewritten to locate its target section by that section's OWN heading and
    the next EMITTED heading (`_section_span`/`HEADING_RE` offsets, last-emitted → slice to EOF),
    never a hardcoded `## N.` successor — `dmc-agents-md.py` V1 (delete §6), V4 (blank §9), E4
    (isolate §10), and `tests/fixtures/m6.5/test-agents-md.sh` awk §6-delete + awk §10-aggregation.
    Each control still FAILS on its intended defect; no assertion weakened.
- **Artifact regen:** committed `AGENTS.md` regenerated via `dmc agents-md` — 32,490 B → **24,126 B**
  (~8.4 KB reclaimed, now ≥8 KB under the 32,768 Codex cap); `agents-md --stdout` byte-identical to
  the committed file; §7 (offset 653) and §9 (1965) now precede §4 (3094); `--validate` VALID; AC6
  companion-docs pointer (`AUTONOMY.md` + `docs/CONTEXT_MAP.md`) survives —
  `dmc-v0.4.7-context-audit.sh --self-test` 7/0.
- **Bucket-A rationale:** deterministic artifact compaction only — NO enforcement/gate/floor/
  `when-gates-fire`/schema change. The generator is not among the 49 legacy tools nor in the
  release-gate DEFAULT_PROTECTED set, so no `DMC_GATE_PROTECTED` override; a non-degrading landmark
  FLAG on the enforcement-class generator path is expected. Suites green: agents-md module 27/0,
  m65-suite (codex-shims 143/0 · skills-mirror 19/0 · agents-md 35/0), fast `selftest` all-green,
  `mirror-check` PASS (generator not in the pinned 55-file mirror set), `linkcheck` clean.
- **Chain:** authorized this session by wjlee (AskUserQuestion — lightweighting synthesis, "A1 + A2
  함께"); critic r1 REJECT (B1: A2 breaks physical-order-dependent negative controls) → Rev 2
  (inventory-last reframing + in-scope fixture rewrite + subset→count parity + dropped the
  over-claimed DEFAULT_PROTECTED override) → critic r2 APPROVE; run `dmc-run-02ba039531cf`; scope
  locked to the 4 files; LOCAL commit only. **push/CI/main-FF: human gate.**

## v1.1 — measurement layer wiring (run-metrics recorder + effort/course reachability) — LOCAL (2026-07-09)

- **What/why (memo §7-1 "wiring, not design"):** the run-metrics stack was dormant-but-complete —
  a frozen validator/redactor (`dmc-v0.5.0-run-metrics.sh`) and two frozen advisory selectors
  (effort `v0.5.2`, course `v0.5.3`) existed with ZERO callers. This cycle makes them reachable
  and opt-in WITHOUT any enforcement/floor/ceremony change. Everything is additive + advisory;
  nothing invokes the recorder automatically and **no gate reads the ledger** (it measures, it
  never grades).
- **What/where (one new module + four in-scope edits):**
  - **New `bin/lib/dmc-metrics-recorder.py`** — `record --from <record.json> [--ledger <path>]`
    DELEGATES all validation + secret redaction to the frozen v0.5.0 tool (never re-implements
    those rules), parses the redacted free-form values from the frozen emit, and appends ONE
    compact sorted-key JSONL row to the append-only local ledger. Fail-closed: a validator non-zero
    => no append; the default in-tree ledger `.harness/metrics/ledger.jsonl` is the only in-tree
    ALLOW (mkdir-on-write, symlink-refused), while any `--ledger` override runs an `out_refused`-
    style guard (traversal/secret/symlink/in-tree REFUSED; repo-external temp permitted for
    self-tests). `rollup [--ledger]` prints a deterministic stdout aggregate (counts by
    outcome/effort/mode; retry/human-gate/blocker/finding + tests sums; wall-clock sum+median;
    malformed lines counted as `skipped_malformed`, never fatal). Offline posture is machine-proven
    by a structural self-audit assertion mirroring the frozen family's AC6 (no env-read/socket/
    urllib/requests/curl/wget/--live in the operative source; sole subprocess target is the pinned
    frozen validator).
  - **`bin/dmc`** — `metrics` (record/rollup/self-test), `effort` (argv pass-through to
    `v0.5.2`), and `course` (argv pass-through to `v0.5.3`) verbs + usage text; the recorder
    self-test is wired into the `selftest` module list (no-arg default AND `--all`).
  - **`.gitignore`** — `.harness/metrics/` (ledger is out-of-band, local-only by policy).
  - **`docs/DMC_OPERATOR_HANDBOOK.md`** — one additive "Measuring a run (advisory, opt-in)"
    section: course-before / record-after / rollup-weekly, with the anti-fake note that no gate
    reads the ledger and that catch-rate/false-block tagging + manual-vs-auto recording are pending
    §9 pilot decisions.
- **Verification (implementer lane; independent verifier + release gate pending T003):** recorder
  module self-test **9/0** (direct file run AND via `dmc metrics self-test` dispatch); `dmc effort
  --self-test` **14/0**; `dmc course --self-test` **20/0**; `dmc effort --risk-class docs-only` =>
  `light`; `dmc metrics rollup` on the empty default ledger => `row_count: 0` (no write); `dmc
  selftest` every section 0 FAIL (orient 10 · landmarks 13 · depsurface 8 · radius 7 · plan 8 · run
  6 · verification 6 · schemas-mirror 15 · legacy-mirror 55/55 · recorder 9); `dmc mirror-check`
  PASS (recorder is NOT one of the pinned 55 legacy copies — no stray `dmc-v0.*` guard trip); `dmc
  linkcheck` clean (24 files). Legacy `dmc selftest --all` = **802/3/3 EXACT** and the `--full`
  release gate are the independent verifier's checks (T003).
- **Landmark FLAG posture:** `bin/dmc` + the new `bin/lib/*` module are enforcement-class landmarks,
  so the release gate raises its non-degrading landmark FLAG on them (expected; NO
  `DMC_GATE_PROTECTED` override — same posture as v1.0.5's generator edit; the recorder is not among
  the 49 legacy tools nor in the release-gate DEFAULT_PROTECTED set).
- **Chain:** authorized this session by wjlee (AskUserQuestion envelope "전체 비준": cycles
  A→D-core→C→B, critic-APPROVE-conditional, LOCAL-commit autonomy ceiling); plan
  `.harness/plans/dmc-fable-core-d-runmetrics.md`; critic r1 NEEDS_CLARIFICATION (20-key REQ
  off-by-one + AC5 vacuous-pass) => Rev 2 (default-ledger ALLOW vs override `out_refused`
  clarification + structural offline self-audit AC) => critic r2 APPROVE; run
  `dmc-run-c78c84750bcc` armed with scope.lock over the 5 in-scope paths. **push/CI/main-FF:
  human gate.**

## v1.1.2 — repo-intel scan bounding — LOCAL (2026-07-09)

- **What/why (memo risk #7 "Timeout / scale on big or messy repos", closure-as-infrastructure):**
  `bin/lib/dmc-repo-intel.py`'s walk had no timeout, no file cap, and no gitignore awareness —
  v1.0.5 planning explicitly deferred this hardening as its own verified cycle. This cycle bounds
  the walk with LOUD refusal instead of silent truncation, on a repo that already carries zero
  derived-artifact drift.
- **What/where (one module, three changes):**
  - **B1 skip-set extension:** `SKIP_DIRS` (`:36-38`) gains `target`, `out`, `.next`, `coverage`,
    `vendor`, `.omc` alongside the existing generated-dir set.
  - **B2 gitignore-aware filter:** a new `filter_ignored(root, paths)` (`:119`) runs ONE batched
    `git check-ignore --stdin -z` subprocess inside `walk_files`, applied before the final sort.
    Best-effort (no git / not a work-tree / subprocess error => unchanged, today's behavior).
    Ambient-config neutralized: `-c core.excludesFile=/dev/null` plus a subprocess env
    overriding only `GIT_CONFIG_GLOBAL`/`GIT_CONFIG_SYSTEM` to `/dev/null` (PATH/HOME etc.
    inherited from `os.environ`) — disclosed residue: `$GIT_DIR/info/exclude` still applies, so
    the determinism claim is "deterministic given the tree + the repo's local ignore state;
    ambient user/system config neutralized" (module docstring amended with this sentence).
  - **B3 hard caps, fail-LOUD:** `DEFAULT_MAX_FILES=20000` / `DEFAULT_MAX_SECONDS=30`, threaded
    through `walk_files` (`:155`) and `gen_orient`/`gen_landmarks`/`gen_depsurface`, exposed as
    `--max-files`/`--max-seconds` on the `orient`/`landmarks`/`depsurface` verbs. A monotonic
    clock budgets the loop INTERNALLY only (no timing value lands in output bytes); breach =>
    `die(...)` exit 3 naming the bound and the flag to raise it. Never a silent partial scan.
  - **Self-test:** 7 new `orient` cases (O6–O10, `:653-767`) — skip-set pruning + determinism,
    gitignore-aware filter + no-work-tree fallback, `--max-files` breach naming the bound, and
    ambient-config neutrality with a POSITIVE CONTROL (a raw, non-neutralized `check-ignore` call
    under a simulated ambient global config IS shown to filter the candidate, proving the fixture
    bites, before asserting the module's neutralized path is byte-identical with/without that
    ambient config present).
- **Verification (implementer lane; independent verifier + release gate pending T002):** module
  self-test orient **17/0** (landmarks 13/0 · depsurface 8/0 · radius 7/0, all pre-existing cases
  still passing unmodified); `bin/dmc selftest` (default suite) 0 FAIL across every section; `diff
  <(bin/dmc agents-md --stdout) AGENTS.md` empty both before and after the change (zero derived
  drift, baseline reconciled by `87e76eb`); `orient`/`landmarks`/`depsurface --validate` all VALID;
  `bin/dmc orient` wall-clock ≈0.16s (well under the 30s default budget, matching the measured
  ≈0.12s baseline); `mirror-check` PASS; `linkcheck` clean (24 files); manual temp-tree probes
  confirm `target/`+`vendor/` pruning, gitignore-aware filtering, and `--max-files 10`/
  `--max-seconds 0` both breaching exit 3 with the bound named in the message. Legacy `dmc
  selftest --all` **802/3/3 EXACT** (clean-tree per registered gotcha #4) and the `--full` release
  gate (FLAG expected on `bin/lib/*`, no `DMC_GATE_PROTECTED` override) are the independent
  verifier's checks (T002).
- **Chain:** authorized this session by wjlee (AskUserQuestion envelope "전체 비준": cycles
  A→D-core→C→B, critic-APPROVE-conditional, LOCAL-commit autonomy ceiling on
  `claude/dmc-fable-core`); plan `.harness/plans/dmc-fable-core-b-repointel.md`; critic r1 REJECT
  (2 blockers, `.harness/evidence/dmc-fable-core-b-critic-r1.json`): B-1 the committed `AGENTS.md`
  baseline was already stale (missing the D-core recorder landmark), resolved outside this plan by
  the disclosed remediation commit `87e76eb` before Rev 2; B-2 raw `check-ignore` would have
  coupled output to ambient git config, folded as the neutralized invocation + disclosed
  `info/exclude` residue + case (vi) proving neutrality => critic r2 APPROVE; run
  `dmc-run-880cb5a91f23` armed with scope.lock over the 2 in-scope paths. **push/CI/main-FF: human
  gate.**

## v1.1.1 — ask-tier bypass-awareness — LOCAL (2026-07-09)

_(Numbered before v1.1.2 by plan sequence; built after it — cycle C followed cycle B in this
session's A→D-core→C→B run order.)_

- **What/why (memo risk #1 "friction / false-block"):** the direct source of the "why does DMC
  keep prompting" adoption pain is the ask tier re-seeking consent the human already granted. This
  session hit that live: benign package/read commands stalled on a DMC `ask` even though the host
  was already running with blanket consent. `bypassPermissions` is the host-native record that the
  human pre-granted blanket consent for the whole session, so a second DMC ask for the SAME consent
  is redundant. This cycle downgrades ONLY that redundant ask to an advisory stand-down; the memo
  §6 floor/advisory split applied to the ask tier. **Deny floors are not consent-seeking and never
  stand down.**
- **What/where (`pre-tool-guard.sh`, two additive touches — no other block changed):**
  - **C1 permission-mode read:** `PERMISSION_MODE="$(json_get 'permission_mode')"` added right
    after the `COMMAND` extraction (a PreToolUse-input field current Claude Code delivers but the
    hooks ignored until now). Empty/absent when a host omits it.
  - **C2 Block C bypass stand-down:** when the ask pattern matches AND `PERMISSION_MODE` is EXACTLY
    `bypassPermissions`, the ask is downgraded — the matched class (`publish|audit-force|
    schema-push|migrate|install`, derived for the notice/log ONLY, never affecting matching) is
    appended as ONE value-blind line (`<utc> ask-tier-standdown class=<class>`, NEVER the command
    text) to `.harness/metrics/ask-tier-advisory.log`, a `{"systemMessage":…}` advisory (built via
    the existing `json_string` helper so the class can never malform the envelope) is emitted, and
    the hook `exit 0`s (allow pass-through). Every log failure is swallowed (`mkdir -p … || true`,
    stderr suppressed before the append) so the hook always exits 0. Any OTHER permission_mode value
    (absent, empty, `default`, `acceptEdits`, `plan`, unknown) falls through to the byte-identical
    frozen ask.
- **Disclosed narrowing (surfaced for the human gate):** the authorizing envelope named cycle C as
  "ask-tier 재설계: bypass-인식 + Block C 세분화". The **Block-C-list granularity half was NARROWED
  during planning to bypass-awareness only** — the Block C pattern LIST is unchanged (no command
  added/removed). Rationale: the frozen `bin/lib/dmc-v0.1.3-verify.sh` probes the hook with a
  permission-mode-free `npm install` and REQUIRES `"ask"`; removing/re-slicing the list would break
  that frozen baseline permanently. The fail-closed default keeps the list-level behavior
  byte-identical; only the bypass axis is new. `acceptEdits`/native-allowlist sessions are
  deliberately NOT stood down (acceptEdits consents to edits, not arbitrary Bash; the allowlist is
  invisible to the hook) — registered as a v1.2+ pilot question.
- **Honest posture (inert-if-absent):** live `bypassPermissions` delivery by a real bypass-mode
  session is NOT provable from inside this non-bypass session — the branch is dead code until a host
  actually sends the field, and the evidence records no false "live-proven" claim. The advisory log
  is the pilot's measurement of real firings (including consequential classes like `migrate`) so the
  narrowing can be reviewed against data rather than asserted safe.
- **Verification (implementer lane; independent verifier + release gate pending T003):** new
  standalone smoke test `tests/install/test-ask-tier-bypass.sh` **9/0** (8 plan cases + a value-blind
  negative control: frozen-compat ask with no field / with `acceptEdits`; bypass stand-down with a
  single `class=install` log line + parseable `systemMessage` + rc0; `git push --force` and `cat .env`
  STILL deny under bypass; non-prisma `migrate reset` logs `class=migrate`; `mode=passive` ask
  stand-down intact; read-only metrics dir still exits 0; a fake `sk-…` token in the command never
  enters the log). `bash -n pre-tool-guard.sh` PASS after every edit. Frozen `bin/lib/dmc-v0.1.3-verify.sh`
  (mode=active): the four pre-tool-guard behavior rows PASS (`npm ask`, `rm-rf deny`, `cat .env deny`,
  `benign 0`) — the two suite FAILs are the pre-commit `existing hooks changed: pre-tool-guard.sh`
  byte-compare (expected: this edit is uncommitted) and the anachronistic `GLM/worker code found`
  row (a committed-tree condition — that frozen check predates the v0.2 worker bridge; not touched by
  this change). A16/UPS parity `.harness/evidence/v011-verify.sh` = **39/2 EXACT** registered baseline
  with `T009 mode-gate md5 unique=1` PASS (the md5-pinned mode preamble is untouched) and `active npm
  ask` / `passive npm pass` / `off npm pass` all PASS; the two baseline FAILs (`active stop block`,
  `6 existing skills present`) are the known non-all-pass rows, unrelated to Block C. `bin/dmc
  selftest` every section 0 FAIL; `bin/dmc linkcheck` clean (24 files); `bin/dmc mirror-check` PASS
  (the live hook is not one of the 55 pinned legacy copies). Installer-mirror question resolved:
  `dmc-install.sh:302` path-copies the live hook (`cp "$SRC/.claude/hooks/$h"`) — no embedded payload
  to sync. Legacy `dmc selftest --all` = **802/3/3 EXACT** (committed-replica + isolated-live) and the
  `--full` release gate with the `DMC_GATE_PROTECTED` override (DEFAULT_PROTECTED minus `.claude/hooks`,
  non-degrading landmark FLAG never suppressed) are the independent verifier's checks (T003).
- **Divergence surfaced for the verifier:** `adapters/codex/dmc_codex_common.py` mirrors the Block C
  ask floor in Python for the Codex host but is OUT OF SCOPE this cycle, so it does NOT yet carry
  bypass-awareness — recorded here for a follow-up decision, not silently patched.
- **Chain:** authorized this session by wjlee (AskUserQuestion envelope "전체 비준": cycles
  A→D-core→C→B, critic-APPROVE-conditional, LOCAL-commit autonomy ceiling on `claude/dmc-fable-core`);
  plan `.harness/plans/dmc-fable-core-c-asktier.md` (Rev 1); critic r1 APPROVE, 0 blockers
  (`.harness/evidence/dmc-fable-core-c-critic-r1.json`); run `dmc-run-ea8cac7f910b` armed with
  scope.lock over the in-scope files; independent verifier + `--full` gate pending. **push/CI/main-FF:
  human gate.**

## v1.1.3 — run-start scope arming — LOCAL (2026-07-10)

- **The defect (verifier-discovered, compensated 4×):** `bin/dmc run start` minted a run (run.json +
  snapshot.txt + pointer) but never compiled the scope.lock — no `bin/dmc` verb exposed the
  `dmc-scope-lock.py --compile` step. Because the hooks define ARMED := pointer present AND that run's
  `scope.lock.json` exists, a started-but-lockless run ran with L1 scope enforcement STOOD DOWN while
  looking armed. Cycle A's independent verifier root-caused it; all four fable-core cycles armed by
  hand (compile → validate → deny/allow probes) as a manual compensation. This cycle automates that
  procedure into one fail-closed command, without touching the run-lifecycle core.
- **What ships (E1–E4):**
  - **E1 — `bin/dmc run start --scope-input FILE` (dispatch-level composition).** The `run` verb's
    shared `exec python3 "$RCORE" "$sub"` group is SPLIT: `start` becomes a CAPTURED (non-exec) call
    whose stdout/stderr flow through untouched, so control returns for the compose; every other run
    subcommand keeps `exec` verbatim. The dispatcher extracts `--scope-input` (removed before
    delegation), notes `--plan`/`--root` (left in, default root `.`), and — on a zero RCORE exit WITH
    `--scope-input` — reads the pointer, then `dmc-scope-lock.py --compile … --root <root> --out
    <root>/.harness/runs/<id>/scope.lock.json` and `--validate`. Both zero ⇒ prints `ARMED: <lock>
    (validated)`. The compiler tool path is absolute via the existing `$HERE` pattern
    (`SCOPELOCKLIB="$HERE/lib/dmc-scope-lock.py"`); `dmc-run-lifecycle.py` and `dmc-scope-lock.py`
    stay byte-untouched.
  - **Fail-closed teardown.** If compile OR validate fails, the half-armed state is torn down
    deterministically — `run suspend --root <root>` FIRST (the pointer must still exist for suspend to
    resolve the run), THEN pointer removal — and the command exits 3 with `REFUSED-ARMING: <reason>`
    on stderr. A run that looks started but carries no validated lock never survives.
  - **E2 — honest unarmed warning.** `run start` WITHOUT `--scope-input` stays byte-compatible with
    every existing caller/fixture (success-path stdout + exit identical to a direct RCORE start) but
    now prints ONE stderr line `WARNING: run started UNARMED — no scope.lock; L1 scope enforcement
    stands down (pass --scope-input FILE to arm)`. Success-path only: on any non-zero RCORE exit
    (the refuse paths) bin/dmc adds NOTHING to either stream (byte-identity on both).
  - **E3 — SKILL.md truth repair.** `.claude/skills/dmc-start-work/SKILL.md` step 3 dropped the false
    "mints and arms the run-id and locked scope" claim (true today ONLY via the new form): the
    canonical command is now `bin/dmc run start --plan <plan> --scope-input <scope-input.json>`, the
    scope-input JSON shape is documented with an example, and a fail-closed **no accepted file scope,
    no edit** rule was added (before ANY edit, verify `.harness/runs/<id>/scope.lock.json` exists AND
    `dmc-scope-lock.py --validate` ACCEPTs, else STOP). The `.agents/skills` Codex mirror was edited in
    lockstep — `bin/dmc skills-mirror` reports clean.
  - **E4 — standalone test + this entry.** New `tests/install/test-run-start-arming.sh` (hermetic
    mktemp fixtures, `--root` isolation, NOT wired into selftest — install-wrapper precedent).
- **Verification (implementer lane; independent verifier + release gate pending T003):**
  `bash tests/install/test-run-start-arming.sh` **24/0** — C1 armed happy path (exit 0, RUNNING,
  scope.lock exists + `--validate` ACCEPTs, pointer set, `ARMED:` line, a LIVE `bash-radius`
  out-of-scope write probe against the minted lock ⇒ deny rc4); C2 fail-closed teardown (malformed
  scope-input ⇒ exit 3, `REFUSED-ARMING:`, no scope.lock, run SUSPENDED, pointer ABSENT); C3
  back-compat SUCCESS (stdout + exit byte-identical to a direct RCORE start + exactly one WARNING
  line); C4 back-compat REFUSE (DRAFT plan ⇒ exit + both streams byte-identical, bin/dmc adds
  nothing); C5 usage mentions `--scope-input`; Z real-repo hermetic proof. `bash -n bin/dmc` clean
  after every edit. `bin/dmc selftest` (no-arg) every section 0 FAIL. The three pinned consumers of
  the changed `run` dispatch: `m6-suite` **104/0** (38+45+10+11 — incl. `test-adversarial.sh` vf-a's
  REFUSE-path byte-identity capture and `test-e2e-ultrawork.sh`'s real `run start`), `m7-suite`
  **85/0** (36+26+23), `m9-suite` **91/0** (56+35 — the whole-loop E2E drives `run start --root`).
  `bin/dmc skills-mirror` clean; `bin/dmc agents-md --stdout | diff - AGENTS.md` empty (derived
  artifact neutral); `tests/fixtures/m8/test-manifest-drift.sh` **10/0** (manifest-neutral change);
  `bin/dmc linkcheck` clean (24 files); `bin/dmc mirror-check` PASS (55 files). Independent verifier
  (fresh lane), `dmc gate release --full` (FLAG on `bin/dmc` expected; NO G4 override — `.claude/skills`
  is not protected), and clean-tree `selftest --all` are the verifier's checks (T003).
- **Chain:** authorized this session by wjlee (the standing fable-core envelope + the 2026-07-10
  directive "2. 즉시 수정하여 이번에 반영"): critic-APPROVE-conditional, LOCAL-commit autonomy ceiling on
  `claude/dmc-fable-core`. Plan `.harness/plans/dmc-fable-core-e-runstart.md` (Rev 2 — critic r1
  NEEDS_CLARIFICATION on the shared-`exec` unreachability [B1] + cwd-relative composition [B2] →
  split-start + `--root`-threaded Rev 2 → critic r2 APPROVE, 0 blockers). **push/CI/main-FF: human
  gate.**

## v1.1.4 — committed==regenerated selftest pins for the generated artifacts — LOCAL (2026-07-10)

- **The defect (cycle-D-core, caught-by-luck):** DMC ships two GENERATED artifacts —
  `INSTALL_MANIFEST.md` (from `.claude/install/dmc-install.sh --emit-manifest`) and `AGENTS.md` (from
  `dmc agents-md`). During cycle D-core BOTH drifted out of lockstep with their generators;
  `INSTALL_MANIFEST.md` drift was caught by the m8 suite's byte-equality pin, but `AGENTS.md` drift
  had NO selftest pin and escaped to a later critic by luck
  (`.harness/evidence/dmc-fable-core-e-build-20260710.md` "Registered follow-ups", item 1). This cycle
  makes an AGENTS.md committed==regenerated drift escape no cycle.
- **Honest scope (the pivotal finding):** `INSTALL_MANIFEST.md` is ALREADY permanently pinned —
  `tests/fixtures/m8/test-manifest-drift.sh` (run under `run_m8_suite` + the BLOCKING CI `selftest
  m8-suite` step) `cmp -s`-compares `--emit-manifest` against the committed manifest with hand-edit +
  section-delete negative controls; NO new manifest code was needed. The net-new work is the AGENTS.md
  side: a hermetic drift suite homed with its OWN generator's suite family (agents-md → M6.5, mirroring
  manifest → M8). Re-homing the working manifest test into a unified drift suite was explicitly rejected
  as an out-of-scope refactor (surgical discipline); each drift test lives with its generator.
- **What ships:**
  - **New `tests/fixtures/m6.5/test-agents-md-drift.sh`** — STANDALONE hermetic suite (no
    `_m65common.sh` dependency; own `record`/PASS/FAIL; `ROOT=$SELF_DIR/../../..`; drives the real
    `bin/dmc`). Five assertions: (1) POSITIVE — `dmc agents-md --root ROOT --stdout` == the committed
    `AGENTS.md` BYTE-FOR-BYTE; (2) GUARD — the committed `AGENTS.md` exists and is non-empty (equality
    cannot pass vacuously); (3) NEGATIVE one-byte — a one-byte mutation of a COPY is DETECTED (regen vs
    the tampered copy FAILS: the pin has teeth); (4) NEGATIVE section-delete — deleting a required
    `## N.` section from a COPY still FAILS against the REGEN OUTPUT (not two tampered copies — the
    generator re-emits all ten sections, so deletion cannot defeat the pin, mirroring
    `test-manifest-drift.sh`'s re-emit semantics); (5) HERMETIC — the live repo `git status --porcelain`
    is byte-identical before/after (a DELTA check, never a pass/fail signal on tree state itself; all
    writes confined to mktemp; the tracked `AGENTS.md` is READ, never written). Comparison base is the
    WORKING-TREE `AGENTS.md` (what is about to be committed matches its generator), never HEAD; the
    suite never branches on `git status` as a pass signal, so it adds NO second frozen-v0.6.0
    tree-coupling flake source.
  - **`bin/dmc`** — `test-agents-md-drift.sh` added to the `run_m65_suite` loop and the `selftest
    m65-suite` usage prose names the new committed==regenerated AGENTS.md regen-drift pin. No other
    dispatch change; this auto-wires the pin into `selftest --all`, the named `selftest m65-suite`, AND
    the blocking CI `selftest m65-suite` step (which iterates the whole M6.5 script list — no workflow
    edit; `.github/` is not in the diff).
- **The legacy 802/3/3 aggregate is UNCHANGED:** the ONLY code-enforced pin (`PINNED_BASELINE` in
  `dmc-legacy-selftest.py`) counts `dmc-v0.*` legacy tools only; a new `tests/fixtures/m6.5/*.sh` is not
  a legacy tool, so the aggregate is untouched (the `dmc-metrics-recorder.py` precedent).
  `PINNED_BASELINE` is byte-untouched (out of scope); clean-tree `selftest --all` == `tools=49 PASS=802
  FAIL=3 N/A=3` EXACT re-affirmation is the independent verifier's check.
- **Verification (implementer lane; independent verifier + release gate pending T003):** `bash
  tests/fixtures/m6.5/test-agents-md-drift.sh` **8/0** (positive byte-equality + both negative controls
  + porcelain hermeticity). `bash -n bin/dmc` clean after the edits. `bin/dmc selftest m65-suite` all
  four RESULT lines 0 FAIL — `test-codex-shims.sh` **143/0**, `test-skills-mirror.sh` **19/0**,
  `test-agents-md.sh` **35/0**, `test-agents-md-drift.sh` **8/0**. `bin/dmc selftest m8-suite` re-affirms
  the INSTALL_MANIFEST pin — `test-install-roundtrip.sh` **83/0**, `test-idempotency.sh` **17/0**,
  `test-doctor-negcontrols.sh` **16/0**, `test-manifest-drift.sh` **10/0** (byte-equality PASS,
  unchanged). `bin/dmc selftest agents-md` **27/0** (generator self-test still green). Derived-artifact
  neutrality (the lockstep irony — this change touched `bin/dmc` + added a test): `bin/dmc agents-md
  --root . --stdout | diff - AGENTS.md` EMPTY and `bash .claude/install/dmc-install.sh --emit-manifest |
  diff - INSTALL_MANIFEST.md` EMPTY — NEITHER generated artifact drifted, so the conditional lockstep
  regen was a confirmed NO-OP (F5 held; the immediately-prior E-cycle empirically proved the same
  class). Clean-tree `selftest --all` == 802/3/3 EXACT, an own re-run of the drift suite incl. the
  negative controls, and `dmc gate release --full` (non-degrading FLAG on `bin/dmc` expected; NO G4
  override — no protected path in scope) are the independent verifier's checks (T003).
- **Chain:** authorized this session by wjlee (the standing fable-core envelope + the 2026-07-10
  next-session register item 1 "committed==regen 셀프테스트 핀"): critic-APPROVE-conditional, LOCAL-commit
  autonomy ceiling on `claude/dmc-fable-core`. Plan `.harness/plans/dmc-fable-core-regen-pin.md` (Rev 2
  — critic r1 APPROVE folding two advisory nits: the F5 citation + the section-delete regen-vs-copy
  semantics → critic r2 hash re-bind); run `dmc-run-e8b6a347af41` armed with scope.lock over the
  in-scope files. **push/CI/main-FF: human gate.**

## v1.1.5 — Codex adapter Block C bypass-awareness mirror — LOCAL (2026-07-10)

- **What/why (cross-adapter parity port of v1.1.1):** v1.1.1 shipped ask-tier bypass-awareness on the
  Claude side (`pre-tool-guard.sh`) and explicitly surfaced the Codex mirror as an open divergence —
  `adapters/codex/dmc_codex_common.py` reproduced the Block C ask floor but carried NO bypass-awareness
  ("recorded here for a follow-up decision, not silently patched"). This cycle closes that divergence:
  the ADVISORY Codex Block C now matches the Claude side under a host-attested `bypassPermissions`
  mode, so a package/migration/publish command the human already blanket-consented to stops drawing a
  redundant second `ask` on a Codex host too. **Deny floors are not consent-seeking and never stand
  down** — only the redundant Block C ask is downgraded.
- **What/where (two additive `.py` touches + a new test section — no other block changed):**
  - **M1 `dmc_codex_common.py`:** `PERMISSION_MODE_KEYS = ("permission_mode", "permissionMode")`
    (snake `permission_mode` is the DOCUMENTED parity key — exactly what `json_get 'permission_mode'`
    reads; camelCase is a defensive-only Codex-schema candidate); `permission_mode(data)` reads it at
    the event TOP level ONLY (mirrors the Claude top-level read; "" when absent); `ask_class(command)`
    mirrors `PTG_ASK_CLASS`'s exact precedence + fallback (`publish` > `audit-force` > `schema-push` >
    `migrate` > `install`); `pretool_standdown(project_dir, cls)` best-effort appends ONE value-blind
    line (`<utc> ask-tier-standdown class=<cls>`, class + timestamp only, NEVER the command text) to
    `.harness/metrics/ask-tier-advisory.log`, emits the byte-identical `{"systemMessage":…}` advisory,
    and exits 0 (allow pass-through), swallowing every log failure. One stdlib `import time` added.
  - **M2 `dmc-codex-pretooluse.py handle_bash`:** at the Block C `verdict == "ask"` branch ONLY
    (reached only AFTER the deny floors above have returned — Block C is the sole `ask`-scoped floor),
    when `permission_mode(data) == "bypassPermissions"` EXACTLY, downgrade to `pretool_standdown`;
    every other/absent value falls through to the byte-identical `pretool_ask`. Block D write-radius,
    the Edit/Write scope tree, and the Read/Grep/Glob secret floor are all untouched.
- **The moat (deny floors + scope provably unaffected):** Block A/B deny floors (scope `all` /
  `not-off`) are unchanged in every mode; the Block D dynamic write-radius (`bash-radius`) is
  unchanged — it adjudicates SCOPE not consent, so bypass never stands it down; the Block C ask
  pattern LIST is unchanged (no command added/removed). grep-AC: `grep -n bypassPermissions
  adapters/codex/*.py` shows the token ONLY in the pretooluse Block C ask branch + the `common.py`
  stand-down emitter/keys/docstring — NO deny-path reference. `git push --force` and `cat .env` STILL
  deny under bypass (they are Block A floors that return before Block C is ever considered).
- **Honest posture (inert-if-absent) — the standing Option-A ADVISORY caveat:** live delivery of
  `bypassPermissions` by a real Codex bypass-mode session is NOT provable from inside this session —
  it is **turn-free-unprovable**, exactly like whether the Codex hooks FIRE and whether these shims'
  envelopes are HONORED at all (codex-cli 0.132.0 spike). The stand-down inherits the same ADVISORY
  status as every other envelope the shim emits; **no enforcement-parity claim is added.** The branch
  is inert-if-absent (absent/empty/`default`/`acceptEdits`/`plan`/unknown ⇒ the frozen ask fires,
  byte-identical) — dead code until a host actually sends the field, and the evidence records no false
  "live-proven" claim. The advisory log is the pilot's measurement of real firings (incl. consequential
  classes like `migrate`). `acceptEdits`/native-allowlist sessions are deliberately NOT stood down
  (same narrowing as v1.1.1; a registered v1.2+ pilot question).
- **Verification (implementer lane; independent verifier + release gate pending T003):** `bash
  tests/fixtures/m6.5/test-codex-shims.sh` **161/0** — the new `== F. ask-tier bypass-awareness
  (v1.1.5) ==` section (F1 inert-if-absent ask; F2 `acceptEdits` ⇒ ask; F3 `npm install` + bypass ⇒
  stand-down with no ask, rc0, a parseable `systemMessage`, and exactly one value-blind `class=install`
  log line; F4/F5 `git push --force` / `cat .env` STILL deny under bypass; F6 non-prisma `sqlx migrate
  reset` logs `class=migrate`; F7 mode=passive + bypass ⇒ no ask, no `systemMessage`, NO log file via a
  fresh passive sandbox — mode composition; F8 a fake `sk-…` token in the command never enters the log;
  F-PAR1 cross-adapter — the REAL Claude hook and the Codex shim on one bypass envelope both stand
  down, their EXTRACTED `systemMessage` strings byte-EQUAL via ONE shared extractor, both log lines
  share the `class=install` shape; F-PAR2 deny-under-bypass parity; F-PAR3 inert-if-absent ask parity)
  plus the unchanged D-block and the real-repo porcelain guard (`git status --porcelain` byte-identical
  before/after). `bin/dmc selftest m65-suite` all green — `test-codex-shims.sh` **161/0**,
  `test-skills-mirror.sh` **19/0**, `test-agents-md.sh` **35/0**, `test-agents-md-drift.sh` **9/0**.
  Derived-artifact neutrality (both edited `.py` files are enforcement landmarks listed by path+class in
  `AGENTS.md` and by name in `INSTALL_MANIFEST.md`, content-agnostic): `bin/dmc agents-md --root .
  --stdout | diff - AGENTS.md` EMPTY and `bash .claude/install/dmc-install.sh --emit-manifest | diff -
  INSTALL_MANIFEST.md` EMPTY — NEITHER generated artifact drifted.
- **The legacy 802/3/3 aggregate is UNCHANGED, count 143→161 is descriptive only:** `run_m65_suite`
  asserts EXIT CODE only (no code-enforced count), so the +18 section-F assertions (143 → 161) break
  no pin; the ONLY code-enforced count is legacy `PINNED_BASELINE` (`dmc-legacy-selftest.py`, `dmc-v0.*`
  tools only) — `test-codex-shims.sh` is not a legacy tool, so 802/3/3 is untouched. The prior `143`
  figure survives as frozen prose in earlier records (never retro-edited); this entry records the new
  `161`. Committed-replica + isolated-live `bin/dmc selftest --all` == `tools=49 PASS=802 FAIL=3 N/A=3`
  EXACT and `bin/dmc gate release --full` (non-degrading FLAG on the two enforcement landmarks, NO
  `DMC_GATE_PROTECTED` override — `adapters/codex` is absent from `DEFAULT_PROTECTED`) are the
  independent verifier's checks (T003).
- **Chain:** authorized this session by wjlee (the standing fable-core envelope + the 2026-07-10
  next-session register item 2 "Codex 어댑터 bypass 반영", "2번도 적용하자"): critic-APPROVE-conditional,
  LOCAL-commit autonomy ceiling on `claude/dmc-fable-core`. Plan
  `.harness/plans/dmc-fable-core-codex-bypass.md` (Rev 2 — critic r1 APPROVE, 0 blockers, three
  executor advisories folded into the build brief: ONE shared `systemMessage` extractor for F-PAR1,
  the snake-vs-camelCase parity comment on `PERMISSION_MODE_KEYS`, and a fresh passive sandbox for the
  F7 no-log assertion → critic r2 hash re-bind); run `dmc-run-5d7b9cb3ca28` armed with scope.lock over
  the four in-scope files. **push/CI/main-FF: human gate.**
