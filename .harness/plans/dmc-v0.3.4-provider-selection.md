# Plan — dmc-v0.3.4 Unified Provider Selection Runner

Status: APPROVED
Approval Status: APPROVED
Mode: PLAN ONLY until APPROVED. **Additive, read-only** — no protected-surface edit (it READS the v0.2.8 classifier,
v0.2.9 policy, and the router, and modifies none of them).

## Goal
A **read-only, advisory** selector that takes a task bundle and produces ranked **`provider_target` candidates** —
moving "which provider to use" from manual judgment to **policy-based** judgment — by composing the v0.2.8 task-intake
classifier + the v0.2.9 effort/provider policy + the v0.3.2 router. It **executes nothing** (or mock-only
`--print-dispatch`), **infers nothing from env/secrets**, and **grants no gate**.

## User Intent
v0.3.4 roadmap: "task_intake + effort/provider policy + provider-router를 연결하는 read-only selector … task bundle을 받아
provider_target 후보 산출 … 실행은 하지 않거나 mock-only dispatch … env/secret 기반 추론 금지 … 수동 판단에서 정책 기반
판단으로 이동."

## Current Repo Findings
- `dmc-v0.2.8-task-intake-classifier.sh` classifies a task **description** → risk dimensions, required human gates,
  `stop_and_ask` (fail-closed). Advisory.
- `docs/DMC_EFFORT_PROVIDER_POLICY.md` maps task-class → model/effort/plan-depth/critic/gate/`stop_and_ask` (guidance, not
  enforcement). It does **not** map to a specific provider adapter (that axis is new here).
- `provider-router.py` REGISTRY (post-v0.3.2): `api_key/glm-api`, `oauth_cli/oauth-cli`, `manual_import/manual-import`;
  refuses `""`/`mock`. `--print-dispatch` validates routing offline (no exec).

## Relevant Files (all additive)
- `docs/DMC_PROVIDER_SELECTION.md` — the selection spec (provider-candidate ranking policy; read-only/advisory contract).
- `.harness/evidence/dmc-v0.3.4-provider-selector.sh` — the selector tool (+ `--self-test`).
- `.harness/verification/dmc-v0.3.4-provider-selection.md` — verification report.
- `.harness/plans/dmc-v0.3.4-provider-selection.md` — this plan.

## Out of Scope (with rationale)
- **No execution / no live call** — the selector recommends; it never runs an adapter (optionally only the router's
  `--print-dispatch`, which executes nothing). No `--live`/network/model-API.
- **No env/secret inference** — candidates are a function of the **task + policy ONLY**; the selector does NOT read/check
  `GLM_API_KEY`/`DMC_OAUTHCLI_BIN`/`.env*` or any credential to decide availability (it proposes live providers as
  **gated options**, never "available because a key is set").
- **No adapter/router/schema/hook/policy/classifier edit** — read-only over all of them.
- **No actual selection/commitment** — output is a ranked **candidate** list; the human/loop chooses (anti-token-max:
  smallest sufficient provider).

## Proposed Changes
### A. `.harness/evidence/dmc-v0.3.4-provider-selector.sh` (new; `--self-test`; `PYTHONDONTWRITEBYTECODE`)
CLI: `dmc-v0.3.4-provider-selector.sh --task <task.json> [--out <file>] [--dispatch-check]` · `--self-test`.
Pipeline (read-only):
1. **Read** the task bundle (`--task`); extract `objective` + `context_summary` (+ any `provider_target` hint).
2. **Intake** — invoke `dmc-v0.2.8-task-intake-classifier.sh --task "<objective+context>"` (read-only) → dimensions,
   required human gates, `stop_and_ask`. (Reuse, not re-derive.)
3. **Policy** — map the task class to model/effort/plan-depth/critic per `DMC_EFFORT_PROVIDER_POLICY.md` (the always-on
   gates + Codex-audit-before-stage/commit/push).
4. **Provider-candidate ranking (the new policy, defined in §B):** the candidate set is exactly the three **registered
   `provider_target`s** — `manual_import/manual-import`, `api_key/glm-api`, `oauth_cli/oauth-cli` (router REGISTRY,
   provider-router.py:38-41). **`mock` is NOT a candidate** — it is the default offline **run-mode** of the glm-api/
   oauth-cli adapters (`--mock <fixture>`), an execution-mode axis orthogonal to provider selection; the router refuses
   type `mock` (provider-router.py:58-59). Rank **offline-first**: `manual_import` (the only **offline-by-construction**
   target — no `live_flag`, no `--mock`/`--live`, only `--import`) ranks **above** the live-capable `glm-api` and
   `oauth-cli`. Each live-capable candidate carries a **`run_mode`**: default **`mock`** (the recommended offline dry-run)
   with **`live` as the gated escalation** (live gate #5 + the always-on gates); `manual_import` carries
   `run_mode: import-only`. Ranking is a function of the task + policy **ONLY** — **never** env/secret presence.
   Fail-closed: if `stop_and_ask=true` or a protected/credential/live signal is present, the output flags
   **human-gate-required** and does not present a live `run_mode` as a no-gate default.
5. **Dispatch-check (optional, mock-only)** — with `--dispatch-check`, for each candidate in the routable set
   `{manual-import, glm-api, oauth-cli}` synthesize a per-candidate task fixture (`provider_target = candidate`) in
   `$TMPDIR` and run `provider-router.py --print-dispatch` (which returns BEFORE any `subprocess.run` —
   provider-router.py:130-136, executes nothing) to confirm it routes; annotate `routes: yes/no`. A single **chokepoint
   helper** builds every router argv and **hard-codes `--print-dispatch`** (no code path omits it) and **never** passes
   `--live`/`--allow-network`/`--allow-exec`/`--mock`/`--import` to the router.
6. **Emit** JSON (`--out` guarded, or stdout): `{task_id, intake_dimensions, stop_and_ask, required_human_gates,
   recommended_model_effort, provider_candidates:[{type, provider, run_mode, rank, rationale, gates, routes?}],
   selection_basis: "task + policy (NOT env/secrets); advisory; grants no gate; executes nothing"}`.
Advisory/read-only: performs/grants no gate; the exit code is informational, never wired to select/execute.

### B. `docs/DMC_PROVIDER_SELECTION.md`
The provider-candidate ranking policy: the candidate set is the **three registered `provider_target`s**;
**offline-first** means `manual_import` (offline-by-construction) ranks above the live-capable `glm-api`/`oauth-cli`, and
for the live-capable pair "offline vs live" is a **`run_mode`** of the *same* provider — default `mock` run-mode,
`--live` as the **gated** escalation — **not** a separate `mock` provider. Also: the **no-env/secret-inference** rule
(live providers are proposed as **gated options**, never "available because a key is set"), the
**read-only/advisory/executes-nothing** contract, and the fail-closed rule (stop_and_ask/protected/live/credential
signal ⇒ human-gate-required, no live-`run_mode` default).

## Acceptance Criteria (measurable; `--self-test`, offline only)
- **AC1 read-only/advisory + no-exec (falsifiable mechanism named)**: the self-test (a) snapshots `git status --porcelain
  | md5` pre/post and asserts byte-equality (the established repo-unchanged pattern — dmc-v0.3.0-e2e-completion.sh:171,
  dmc-v0.2.7-run-manifest.sh:148), AND (b) proves **no adapter executed** behaviorally: `--dispatch-check` is run against a
  **sentinel adapter** whose only effect would be to create a marker file, and the self-test asserts the marker is
  **never** produced (router `--print-dispatch` returns before `subprocess.run`, provider-router.py:130-136). A structural
  source audit additionally asserts the selector contains **no** bare router/adapter `subprocess.run` lacking
  `--print-dispatch`. It stages/commits/executes-an-adapter/grants-a-gate **nothing**.
- **AC2 no env/secret inference (static primary proof + strengthened differential)**: PRIMARY — the candidate JSON
  produced under `env -i` (empty environment) is **byte-identical** to the full-environment run (the computation is a pure
  function of the task JSON + policy doc, independent of ALL env). DIFFERENTIAL — across `{unset, short-dummy,
  secret-shaped-realistic, a second distinct realistic}` values for a representative credential-var set (`GLM_API_KEY`,
  `DMC_OAUTHCLI_BIN`, `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `ZHIPUAI_API_KEY`) the candidate output is byte-identical
  (catches value-dependent and different-variable leaks). STRUCTURAL — a source audit asserts the selector contains **no**
  `os.environ`/`os.getenv`/`dict(os.environ)` read, no `open()` of an `.env*`/credential path, and no env-inheriting
  credential subprocess, in any **code** position (pattern *string literals* — e.g. matching task text the way the v0.2.8
  classifier does at line 33 — are allowed; reads are not). The tool opens no `.env*`/credential file (a decoy `.env`
  placed in cwd is never opened).
- **AC3 candidate correctness (boundary tuples pinned inline)**: the self-test pins the boundary expectations from
  `docs/DMC_EFFORT_PROVIDER_POLICY.md:64-72`, so a wrong mapping FAILS: (i) **docs-only** → `manual_import` + the
  live-capable pair in **`mock` run_mode** ranked offline-first, **no** gate #7, `stop_and_ask=false`; (ii) **adapter/
  protected** → **human-gate-required** (gate #7), `stop_and_ask=true`; (iii) **live/credential** → live `run_mode`
  flagged with gate #5/#6, **no** live-no-gate default, `stop_and_ask=true`.
- **AC4 dispatch-check mock-only (per-candidate fixture + exec mechanism named)**: `--dispatch-check` synthesizes a
  per-candidate task fixture (`provider_target = candidate`) in `$TMPDIR` and annotates each candidate in the routable set
  `{manual-import, glm-api, oauth-cli}` via the chokepoint helper's `--print-dispatch` call (router returns before
  `subprocess.run`, provider-router.py:130-136 — executes nothing); the self-test asserts the helper's emitted argv
  **always** contains `--print-dispatch` and **never** `--live`/`--allow-network`/`--allow-exec`/`--mock`/`--import`,
  across all candidate types. No-adapter-exec is covered by the AC1 sentinel. No `--live`/network.
- **AC5 fail-closed**: a `stop_and_ask=true` / protected / live / credential task yields `human-gate-required` and never
  presents a live provider as a no-gate default; unknown/ambiguous → conservative (stop_and_ask propagated).
- **AC6 `--out` guard**: refuses a protected/secret/traversal/symlink `--out` target (reuse the canonicalized guard).
- **AC7**: gate-check green (additive; no protected change); critic + Codex audit → ACCEPT before commit.

## Risks (+ mitigations)
- **R1 env/secret inference creep** → AC2's **`env -i` static proof** (output independent of ALL env) is the primary
  control, backed by the multi-var/multi-value differential and a **structural** source audit (forbid `os.environ`/
  `os.getenv`/`dict(os.environ)` reads, `.env*`/credential `open()`, env-inheriting credential subprocess in code
  positions; pattern *string literals* allowed). A substring grep alone is insufficient (it cannot tell a benign pattern
  string from a real read), so the structural assertion + `env -i` differential replace it.
- **R2 accidental execution** → a **single chokepoint helper** builds every router argv and hard-codes `--print-dispatch`
  (no code path omits it); AC1's **behavioral sentinel** (marker-file never produced) proves no adapter ran — not a grep
  alone, which cannot prove a runtime-present `--print-dispatch`. The selector never passes
  `--live`/`--allow-network`/`--allow-exec`/`--mock`/`--import` to the router.
- **R3 over-claiming "decides"** → output is a candidate LIST; the doc + JSON `selection_basis` state advisory/grants-no-gate.
- **R4 classifier coupling** → invoke the committed v0.2.8 classifier read-only; if absent, fail-closed (recommend
  nothing — self-test asserts: classifier binary missing ⇒ **no live candidate** emitted).

## Rollback Plan
- Delete the 2 new files (selector + doc) + the harness; additive, no protected/adapter/router/policy impact.

## Execution Tasks (after APPROVED)
1. Author `dmc-v0.3.4-provider-selector.sh` (pipeline A1–A6; three-candidate model with `run_mode`; single
   `--print-dispatch` chokepoint helper; `--out` guard; `--self-test`; PYTHONDONTWRITEBYTECODE).
2. Author `docs/DMC_PROVIDER_SELECTION.md` (change B).
3. Run `--self-test` → all PASS (incl. AC2 `env -i` byte-identity + multi-var/value differential + structural no-env-read
   audit; AC1 git-status md5 pre/post + no-exec sentinel; AC3 pinned boundary tuples; AC4 chokepoint-argv assertion);
   write the verification report; gate-check; critic; Codex audit; commit on ACCEPT; **no push**.

## Verification Commands
- `bash .harness/evidence/dmc-v0.3.4-provider-selector.sh --self-test`
- `git status --porcelain` (expect only additive untracked + excluded auto-log)
- gate-check runner (additive set); then Codex audit.

## Approval Status
**APPROVED (rev 2)** — round-1 adversarial panel (selection-policy + no-env/no-exec + AC-falsifiability) returned
**REVISE**; all REQUIRED changes applied: (1) **mock category error** fixed — `mock` is a glm-api/oauth-cli **run-mode**,
not a `provider_target`; candidate set is the three registered targets with a `run_mode` field; (2) AC2 strengthened to
an `env -i` static proof + multi-var/value differential + structural no-env-read audit; (3) AC1/AC4 no-exec given named
mechanisms (git-status md5 pre/post + behavioral sentinel + single `--print-dispatch` chokepoint); (4) AC3 boundary
tuples pinned inline. **Round-2 focused re-pass: PASS / PASS** (both dimensions — mock-reframe coherence + AC
falsifiability — zero remaining_required, zero new_defects; all cited repo mechanisms cross-checked). Implementation
note carried to executor: reference the full path `.claude/workers/providers/provider-router.py` in the chokepoint
helper. Next: `/dmc-start-work`. Additive/read-only; no provider-surface change.
