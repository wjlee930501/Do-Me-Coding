# Plan — dmc-v0.3.5 Execution Manifest v2

Status: APPROVED
Approval Status: APPROVED
Mode: PLAN ONLY until APPROVED. **Additive, read-only** — composes the v0.3.4 selector (+ the v0.3.2 router
`--print-dispatch`) and modifies no protected surface.

## Goal
A **read-only** generator that, from a task bundle, emits a **single Execution Manifest (v2)** binding everything needed
to execute a milestone safely — **task · proposed provider_target · selected adapter · verification expectations ·
required human gates · closure criteria** — as a forward-looking, decision-complete artifact. It composes the v0.3.4
provider selector (which itself composes the v0.2.8 classifier + v0.2.9 policy + the router). It has **no execution side
effects**: it executes no adapter, makes no live/network call, infers nothing from env/secrets, and grants no gate.

## User Intent
v0.3.5 roadmap: "단일 manifest (task, provider_target, selected adapter, verification expectations, gates, closure
criteria) … no execution side effects." A single artifact that ties the chosen provider + verification + gates + closure
together so the loop/human has one decision-complete object before acting.

## Current Repo Findings
- `dmc-v0.2.7-run-manifest.sh` (v1) is a **post-hoc RUN RECORDER**: it snapshots a *completed* run (commit hash, verify
  pass/fail counts, origin sync, push state). v0.3.5 v2 is **forward-looking** and distinct — it binds what *will* be
  executed, before execution; it is NOT a git-state snapshot.
- `dmc-v0.3.4-provider-selector.sh` (committed 241f012) emits ranked `provider_target` candidates with `run_mode`,
  `required_human_gates`, `stop_and_ask`, `human_gate_required`, `fail_closed` — read-only/advisory, no env inference,
  executes nothing. v2 reuses it as the selection source.
- `provider-router.py --print-dispatch` resolves the adapter path for a `provider_target` and returns BEFORE
  `subprocess.run` (provider-router.py:130-136) — the no-exec way to learn the "selected adapter".
- The closure vocabulary (verified · reviewed · committed · pushed · closure-recorded) is the handbook / v0.2.9 STOP
  definition (`docs/DMC_EFFORT_PROVIDER_POLICY.md:48`).

## Relevant Files (all additive)
- `docs/DMC_EXECUTION_MANIFEST.md` — the v2 manifest spec (fields; read-only/advisory/no-side-effects contract).
- `.harness/evidence/dmc-v0.3.5-execution-manifest.sh` — the generator (+ `--self-test`).
- `.harness/verification/dmc-v0.3.5-execution-manifest.md` — verification report.
- `.harness/plans/dmc-v0.3.5-execution-manifest.md` — this plan.

## Out of Scope (with rationale)
- **No execution / no live call** — the generator composes the v0.3.4 selector (read-only) and at most the router
  `--print-dispatch` (executes nothing). It runs no adapter. No `--live`/network/model-API.
- **No env/secret inference** — the manifest is a function of the **task + policy ONLY** (inherited from the v0.3.4
  selector); the generator reads no env var and no `.env*`/credential file. Determinism: the manifest embeds **no** git
  hash / ahead-count / wall-clock (that is v1's job) — it is forward-looking and env/git-state-independent.
- **No gate grant / no commitment** — the manifest is a *proposal* binding; closure criteria are EXPECTATIONS (not
  asserted-as-met); the proposed target is the offline-first top-ranked candidate, which the human/loop may override.
- **No protected/adapter/router/schema/hook/policy/classifier/selector edit** — read-only over all of them.

## Proposed Changes
### A. `.harness/evidence/dmc-v0.3.5-execution-manifest.sh` (new; `--self-test`; `PYTHONDONTWRITEBYTECODE`)
CLI: `dmc-v0.3.5-execution-manifest.sh --task <task.json> [--milestone <id>] [--verify-script <path>] [--out <file>]`
· `--self-test`. Pipeline (read-only):
1. **Read** the task bundle (`--task`): `objective`, `context_summary`, `task_id`, optional `provider_target` hint.
2. **Select** — invoke `dmc-v0.3.4-provider-selector.sh --task <task.json>` (read-only) → the full selection object
   (candidates, gates, `stop_and_ask`, `human_gate_required`, `fail_closed`). Reuse, not re-derive.
3. **Proposed target + selected adapter** — the **top-ranked** candidate (rank 1 = `manual_import`, offline-first) is the
   `proposed_provider_target` (with its `run_mode`); resolve its **`selected_adapter`** via the **chokepoint** router
   `--print-dispatch` (the `adapter` field of the print-dispatch JSON; executes nothing; never passes
   `--live`/`--allow-network`/`--allow-exec`/`--mock`/`--import`). Exactly **ONE** `--print-dispatch` call (for the
   manual_import target) — **not** the selector's 3-provider dispatch loop; manual_import `--print-dispatch` is
   intentionally **input-less** (the router returns at :133 before the `subprocess.run` at :136, and does not require
   `--import` on that path). A `provider_target` hint that differs is recorded under `provider_target_hint` with a note
   (if live-capable ⇒ requires the live gate #5) — it does **not** silently become the proposal.
4. **Verification expectations** — record: the named `--verify-script` (or `"verification required"`), `must_pass: true`,
   `gate_check: required (stage/commit/push)`, `codex_audit: required before stage/commit/push`.
5. **Gates + closure** — `required_human_gates` from the selection; `closure_criteria: [verified, reviewed, committed,
   pushed, closure-recorded]` (expectations).
6. **Gating vs fail-closed** (distinct states):
   - **fail-closed** (selector `fail_closed` / no candidates ⇒ classifier absent): `proposed_provider_target=null`,
     `selected_adapter=null`, `blocked: true`, `human_gate_required: true`, `executable_default: false` — recommend
     nothing.
   - **gated** (non-fail-closed but `human_gate_required` ⇒ high-risk: adapter/protected/live/credential): the manifest
     STILL proposes the **offline-first** top-ranked `manual_import` (the safest target) with its `selected_adapter`, but
     sets `executable_default: false` (the proposal requires the human gate before execution) and surfaces the gates;
     `blocked: false` (the selector returned candidates). It never presents a live provider as a no-gate default.
   - **low-risk** (docs/test, `human_gate_required=false`): `executable_default: true` under the always-on gates.
7. **Emit** JSON (`--out` guarded, or stdout): `{manifest_version:"v2", milestone, task, selection, proposed_provider_
   target, selected_adapter, executable_default, blocked, human_gate_required, verification_expectations,
   required_human_gates, closure_criteria, side_effects:"none …", basis:"composed from the v0.3.4 selector (task+policy,
   NOT env/secrets); advisory; grants no gate; executes nothing"}`.
Advisory/read-only: performs/grants no gate; the exit code is informational, never wired to execute.

### B. `docs/DMC_EXECUTION_MANIFEST.md`
The v2 manifest spec: the field list + meaning; v2 (forward-looking) vs v1 (run recorder); the offline-first proposed
target rule; the **no-execution / no-env-inference / grants-no-gate** contract; closure criteria as expectations;
fail-closed behavior.

## Acceptance Criteria (measurable; `--self-test`, offline only)
- **AC1 read-only + no-exec (named mechanism)**: self-test (a) git-status `md5` pre/post over the whole run (real repo
  byte-unchanged); (b) behavioral **sentinel** — the only router call is `--print-dispatch`, run against a marker-creating
  sentinel router that **never** fires the marker; (c) source audit finds **no** bare adapter/router process-spawn.
- **AC2 no env/secret inference**: PRIMARY — the manifest under `env -i` (PATH/HOME only) is **byte-identical** to the
  full-env run; DIFFERENTIAL — byte-identical across 5 credential vars (`GLM_API_KEY`, `DMC_OAUTHCLI_BIN`,
  `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `ZHIPUAI_API_KEY`) × {unset, dummy, realistic, second realistic} (mirrors the
  v0.3.4 selector); STRUCTURAL — an audit of **the generator's own source** (comment-stripped, code positions) finds
  **no** `os.environ`/`os.getenv` read and **no** credential-var expansion (it does NOT grep the transitively-composed
  classifier, whose `DMC_*` self-export unmarshalling is legitimate); a decoy `.env` is never read. (Helpers read inputs
  via argv/files, never the env.)
- **AC3 manifest correctness (boundary tuples pinned inline)** — the self-test pins, per case, the concrete expected
  values so a wrong mapping FAILS:
  - **(i) docs-only** ⇒ `proposed_provider_target.type=manual_import` / `.provider=manual-import`, `run_mode=import-only`,
    `selected_adapter` ends with `.claude/workers/providers/manual-import/manual-import-adapter.py`,
    `human_gate_required=false`, `executable_default=true`, `blocked=false`, no `#7` gate.
  - **(ii) adapter-protected** ⇒ `proposed_provider_target=manual_import` (offline-first, **NOT null** — the selector
    returned candidates), `human_gate_required=true`, `executable_default=false`, `blocked=false`, and
    `required_human_gates` contains `schema/guard/hook/validator/adapter/router` (#7).
  - **(iii) live-credential** ⇒ `human_gate_required=true`, `executable_default=false`; the embedded `selection`'s
    glm-api/oauth-cli candidates carry the live `#5 live-call` gate (no live-no-gate default); the proposed target remains
    the offline-first `manual_import`.
- **AC4 selected-adapter via print-dispatch only (pinned)**: `selected_adapter` equals the `adapter` field of the router
  `--print-dispatch` JSON (provider-router.py:132, emitted **before** the `subprocess.run` at :136 — executes nothing),
  resolving to a realpath ending `.claude/workers/providers/manual-import/manual-import-adapter.py` (REGISTRY
  provider-router.py:41). A **single** chokepoint helper builds the router argv and **always** includes `--print-dispatch`
  and **never** `--live`/`--allow-network`/`--allow-exec`/`--mock`/`--import`; the self-test asserts the emitted argv.
- **AC5 fail-closed**: classifier absent (selector fail-closed) ⇒ `proposed_provider_target=null`,
  `selected_adapter=null`, `blocked=true`, `human_gate_required=true`, `executable_default=false`, no executable default.
- **AC6 closure + verification completeness**: `closure_criteria` contains all 5 — `verified`, `reviewed`, `committed`,
  `pushed`, `closure-recorded` (dropping any FAILS); `verification_expectations` names the verify-script (or "required"),
  `must_pass:true`, `gate_check` (stage/commit/push), and `codex_audit` (before stage/commit/push).
- **AC7 `--out` guard**: refuses protected/secret/traversal(incl benign-resolving `..`)/symlink targets; benign allowed
  (reuse the v0.3.4 hardened guard). Plus: gate-check green (additive); critic + Codex audit → ACCEPT before commit.

## Risks (+ mitigations)
- **R1 env/secret inference creep** → AC2 `env -i` byte-identity + structural audit (no env read / no credential-var
  expansion in code positions); the generator delegates selection to the v0.3.4 selector, which is already proven
  env-independent.
- **R2 accidental execution** → the only router call is the `--print-dispatch` chokepoint (no exec); AC1 sentinel +
  no-bare-spawn audit; the generator runs the v0.3.4 selector (no-exec) and never an adapter.
- **R3 over-claiming "decides"** → the manifest is a *proposal*; closure criteria are expectations; `side_effects:"none"`
  + `basis` state advisory/grants-no-gate; the proposed target is overridable.
- **R4 v1/v2 confusion** → the doc + `manifest_version:"v2"` state v2 is forward-looking (no git-state snapshot), v1
  records a completed run; the generator embeds no git hash / ahead-count / wall-clock (determinism + clarity).
- **R5 selector coupling** → invoke the committed v0.3.4 selector read-only; if it is absent/errs, fail-closed (emit a
  blocked manifest; recommend nothing).

## Assumptions
- The v0.3.4 selector + the v0.3.2 router + the v0.2.8 classifier are present and committed (they are: 241f012 / prior).
- A task bundle is `{objective, context_summary?, task_id?, provider_target?}` (same envelope the v0.3.4 selector reads).

## Execution Tasks (after APPROVED)
1. Author `dmc-v0.3.5-execution-manifest.sh` (pipeline A1–A7; single `--print-dispatch` chokepoint; `--out` hardened
   guard; `--self-test`; PYTHONDONTWRITEBYTECODE; full paths to the v0.3.4 selector + the router).
2. Author `docs/DMC_EXECUTION_MANIFEST.md` (change B).
3. Run `--self-test` → all PASS (AC1 md5+sentinel; AC2 env -i + structural; AC3 boundary tuples; AC4 chokepoint argv;
   AC5 fail-closed; AC6 closure/verification completeness; AC7 hardened `--out` guard); write the verification report;
   gate-check; critic; Codex audit; commit on ACCEPT; **no push**.

## Verification Commands
- `bash .harness/evidence/dmc-v0.3.5-execution-manifest.sh --self-test`
- a functional run `--task <task.json>` (+ a high-risk fixture) to eyeball the bound manifest
- `git status --porcelain` (expect only additive untracked + excluded auto-log); gate-check runner; then Codex audit.

## Approval Status
**DRAFT (rev 2)** — round-1 panel: v2-vs-v1-design **PASS**, no-env/no-exec **PASS** (critic re-ran the v0.3.4 selector
self-test live, 14/14, confirming invariants survive composition), AC-falsifiability **REVISE**. REQUIRED applied:
(1) **AC3 boundary tuples now pinned inline** per case (docs-only / adapter-protected / live-credential), resolving the
gating semantics — the manifest **always** proposes the offline-first `manual_import` when the selector returns
candidates; `executable_default:false` marks a **gated** high-risk proposal, while `proposed=null`/`blocked:true` is
reserved for **fail-closed** (classifier absent); (2) **AC4 pins** the `selected_adapter` realpath +
`--print-dispatch`-only chokepoint argv. Cheap optionals folded: AC2 differential clause, inline 5 closure names, the
:133-before-:136 citation, generator-only structural-audit scope. **Round-2 focused re-pass: PASS** (zero
remaining_required, zero new_defects — gating semantics coherent, AC3/AC4 pinned/falsifiable, no determinism/no-env
regression; all cited repo mechanisms cross-checked). Next: `/dmc-start-work`. Additive/read-only; no provider-surface
change.
