# Plan — dmc-v0.3.3 Three-Provider Contract Expansion

Status: APPROVED
Approval Status: APPROVED
Approved: 2026-06-21 — delegated semi-autonomous mode; Orchestrator flip (8-step process step 3) after critic round-1
(3× REVISE) → round-2 focused re-pass (dim1 PASS, dim3 PASS, dim2 1 blocker) → the `:20` C5b stale line + dim3 success-task
alignment + pinned C3 regex folded in. Independent critic panels, not self-approval. Authorizes exactly the
PROVIDER_CONTRACT.md edit below.
Revision: 3 (round-2 → +PROVIDER_CONTRACT.md:20 C5b enumeration, success-task allowed_files alignment, pinned C3 regex)
Mode: PLAN ONLY until APPROVED. One authorized protected edit (`PROVIDER_CONTRACT.md`); a new contract-test harness; **no
adapter/router/ROUTING.md/schema/hook/dmc-glm-smoke change**.

## Goal
Lock the provider access layer at **"validated by the same contract"**: extend the PROVIDER_CONTRACT C1–C11 battery to
cover **all three** providers — glm-api, oauth-cli, manual-import — **plus the router path**, with **rejection-stage
differences made explicit** and **no pass-by-skip**.

## User Intent
v0.3.3 roadmap: re-validate all providers + router against PROVIDER_CONTRACT; make rejection-stage differences explicit;
fix the access layer at "동일 계약으로 검증된다", not "지원된다".

## Current Repo Findings (verified empirically by the critic)
- `PROVIDER_CONTRACT.md` C1–C11 are output/behavior-based (uniform); C5a explicitly permits different rejection stages.
  manual_import currently **absent** from "providers under contract" (`:7-8`); stale `dmc-v0.2.4-verify.sh` references at
  `:1` (title `(v0.2.4)`), `:4-5` ("Verified offline by …"), `:40` ("Adding a new provider … dmc-v0.2.4-verify.sh").
- `dmc-v0.2.4-verify.sh`: C1–C11 over glm-api+oauth-cli; `descriptor()` + `assert_rejected()` use a **hardcoded `--mock`**
  invocation (`:49`) and a C3 grep `git apply|shell=True` (`:79`); C5b conditional (`exec_timeout` = oauth-cli only).
- manual-import (committed v0.3.1): input `--import` (no `--mock`); **pure-validation, no exec** (C5b N/A, C10 trivially
  holds); **adapter-sole gate** for OAuth-token + strict-envelope; scope/disallowed/sk-class validator-backstopped (in
  code) — but **all current adversarial fixtures reject at the ADAPTER stage** (none exercises the validator backstop;
  `import-bad-scope` touches `package-lock.json` → adapter DISALLOWED). Deterministic sentinels (C7); routed via v0.3.2 (C8).
- **C3 collision (critic-found):** the manual-import adapter docstring contains "never `git apply`" → a naive C3 grep
  FALSE-FAILs manual_import only (same class as the v0.3.1 V11 docstring-grep fix).

## Relevant Files
- `.claude/workers/providers/PROVIDER_CONTRACT.md` — **authorized protected edit** (truthful 3-provider update; ALL stale
  references corrected — see change B).
- `.harness/evidence/dmc-v0.3.3-verify.sh` — unified contract suite over the 3 providers + router (new, additive).
- `.harness/verification/dmc-v0.3.3-three-provider-contract.md` — verification report (new).
- `.harness/plans/dmc-v0.3.3-three-provider-contract.md` — this plan.

## Out of Scope
- No adapter/router/ROUTING.md/schema/hook/dmc-glm-smoke change (suite RE-VALIDATES them read-only; only the
  PROVIDER_CONTRACT.md doc is edited). No new fixtures for glm/oauth; manual_import reuses its v0.3.1 fixtures. No live
  calls; no selection policy (v0.3.4).

## Proposed Changes
### A. `.harness/evidence/dmc-v0.3.3-verify.sh` (new, additive; `PYTHONDONTWRITEBYTECODE=1` to avoid `__pycache__` noise)
A unified contract harness extending the `dmc-v0.2.4` `descriptor()` pattern to a **third provider**, with these
critic-required corrections so manual_import is held to the SAME contract without false pass/fail:
1. **`INPUT_FLAG` per descriptor, used by EVERY per-provider helper** (success path **and** `assert_rejected`, C4, C6, C7,
   C11) — glm/oauth → `--mock`, manual-import → `--import`. (A hardcoded `--mock` would make manual-import argparse-exit-2
   on EVERY case → false "rejected" everywhere. Forbidden.)
2. **Content-sensitivity assertion**: the SUCCESS fixture must be **ACCEPTED** through the same `INPUT_FLAG` path (adapter
   exit 0 + validator ACCEPT), so a flag-misfire cannot masquerade as a rejection. **Each provider's success TASK
   `allowed_files` must cover its SUCCESS fixture's `files_changed`** (manual_import `import-success.json` →
   `files_changed=["src/app.ts"]`, so its task must allow `src/app.ts`) — otherwise the success run scope-rejects and C1
   false-fails.
3. **C3 call-site-only**: match actual exec call sites (`subprocess.*git.*apply` / `os.system` / `shell=True`), NOT
   comment/docstring prose — so the manual-import docstring "never `git apply`" does not trip C3.
4. **manual_import C4 variant**: success-result clean (no secret shapes; `credential_exposure==none`) **and** a raw
   secret/token import REJECTED (adapter exit≠0, **no result file written**) — **no** override-result inspection (manual_import
   has no override-that-yields-a-clean-result; reading an absent `--out` would FAIL spuriously).
5. **manual_import descriptor**: ADAPTER=`manual-import/manual-import-adapter.py`, INPUT_FLAG=`--import`, FXDIR=v0.3.1
   fixtures, SUCCESS=`import-success.json`, adversarial=`import-bad-scope`/`import-secret`/`import-mutation-attempt`/
   `import-extra-fields`/`import-empty`, PTYPE=`manual_import`, PROVIDER=`manual-import`, EXEC_TIMEOUT=`no`.
6. **Rejection-stage table (pinned, explicit)**: print + assert the EXACT stage per adversarial fixture. For manual_import
   **all** listed fixtures reject at **adapter** (exit≠0, no result); the harness asserts `adapter` for those rows (not a
   permissive "adapter OR validator"). Note in the report: the validator backstop exists in code but is **not** the
   demonstrated stage for any current manual_import fixture.
7. **No pass-by-skip**: each provider must hit its EXPECTED **universal** PASS count (C1,C2,C3,C4,C5a,C6,C7,C8,C9,C10,C11 =
   11 universal); **only C5b** may be N/A and only for a non-`exec_timeout` provider (glm-api, manual-import). A universal
   dimension silently downgraded to N/A is a **FAIL**.
8. Run C1–C11 for all three + **C8 routing** (routed-vs-direct `--out` parity via `--print-dispatch`/`--out`, manual_import
   through `--import`). Mock/offline only (glm/oauth fixtures from their dirs; manual_import has no live mode).

### B. `PROVIDER_CONTRACT.md` (truthful 3-provider update — ALL stale references)
- **`:1` title**: `(v0.2.4)` → `(v0.3.3)`.
- **`:4-5`** "Verified offline by `dmc-v0.2.4-verify.sh`" → reference `dmc-v0.3.3-verify.sh` (the 3-provider suite; may note
  v0.2.4 as the original glm/oauth suite).
- **`:7-8` providers-under-contract**: add `manual-import` (`manual_import`).
- **`:40` "Adding a new provider"**: update the `dmc-v0.2.4-verify.sh` reference to `dmc-v0.3.3-verify.sh` (or state both).
- **`:20` C5b clause** ("For v0.2.4 that is oauth-cli … glm-api = N/A"): re-anchor the version (v0.2.4→v0.3.3) **and** add
  **manual-import = N/A** (no exec), so the C5b-N/A set is {glm-api, manual-import} and oauth-cli is the sole `exec_timeout`
  provider. (This was the 5th `v0.2.4` literal — `grep -n v0.2.4 PROVIDER_CONTRACT.md` = lines 1, 5, 20, 40; all now enumerated.)
- Add a short **manual_import profile**: C5b N/A (no exec); C10 trivially holds (no live mode); adapter-sole gate for the
  OAuth-token class + strict-envelope; scope/disallowed/sk-class validator-backstopped in code, though all current fixtures
  reject at the adapter stage (rejection stages legitimately differ — permitted by C5a).

## Acceptance Criteria (measurable; `dmc-v0.3.3-verify.sh`, mock/offline only)
- **AC1 all-three C1–C11, no pass-by-skip**: each of glm-api/oauth-cli/manual-import hits its EXPECTED universal PASS count
  (11 universal dims PASS); C5b PASS for oauth-cli, N/A for glm/manual; **a universal dim marked N/A or any FAIL fails the suite.**
- **AC2 C8 routing all-three**: `--print-dispatch` selects the right adapter and routed `--out` is byte-identical to direct
  for each (manual_import via `--import`, same task+fixture both sides, `cmp -s`).
- **AC3 C5a no-unsafe-ACCEPTED + pinned stage**: every adversarial fixture is rejected before acceptance (adapter exit≠0 OR
  validator REJECT, never both-pass) via the descriptor's `INPUT_FLAG`; the rejection-stage table asserts the **EXACT**
  stage per fixture (all manual_import fixtures → `adapter`), so a stage regression FAILS. The SUCCESS fixture is ACCEPTED
  through the same path (content-sensitivity).
- **AC4 C4 variant**: manual_import success-result has no secret shapes + `credential_exposure==none`, and a raw secret/token
  import is rejected (no result written) — no override-result read.
- **AC5 C9/C10**: protected files byte-unchanged by the run; no `--live`/network/real-credential (mock + offline only).
- **AC6 protected-surface scope**: the only changed tracked file is `PROVIDER_CONTRACT.md`; adapters/router/ROUTING.md/
  schemas/hooks/dmc-glm-smoke byte-unchanged (scoped `git diff`).
- **AC7**: gate-check green with `DMC_GATE_PROTECTED` = DEFAULT minus exactly the `PROVIDER_CONTRACT.md` line (all else
  retained); critic re-pass; Codex audit → ACCEPT before commit.

## Risks (+ mitigations)
- **R1 C3 docstring collision** → C3 grep matches call-sites only (change A3); harness re-checks glm/oauth too.
- **R2 `--mock`-misfire false-pass** → INPUT_FLAG across ALL helpers + content-sensitivity (A1/A2); AC3 enforces.
- **R3 pass-by-skip** → expected-universal-PASS-count assertion (A7/AC1).
- **R4 C4 override inapplicability** → manual_import C4 variant (A4/AC4).
- **R5 doc staleness** → enumerate ALL stale lines (B); AC6 scopes the diff.
- **R6 protected PROVIDER_CONTRACT.md edit** → doc-only; gate-check carve-out names exactly it; Codex audit confirms.

## Rollback Plan
- Delete `dmc-v0.3.3-verify.sh`; `git revert` the PROVIDER_CONTRACT.md doc edit. Additive; no adapter/router/schema impact.

## Execution Tasks (after APPROVED)
1. Author `dmc-v0.3.3-verify.sh` (A1–A8): descriptor for 3 providers, INPUT_FLAG everywhere, content-sensitivity (success
   task allows the success fixture's files_changed), **C3 grep = `grep -nE 'subprocess.*git.*apply|os\.system|shell=True'`**
   (call-sites only — NOT the v0.2.4 `git apply|shell=True` pattern, which false-fails the manual-import docstring),
   manual_import C4 variant, pinned rejection-stage table (all manual_import → adapter), no-pass-by-skip count, C8 routing,
   `PYTHONDONTWRITEBYTECODE`.
2. Run → all PASS (C5b N/A glm/manual only); confirm scoped protected diff = `PROVIDER_CONTRACT.md` only.
3. Edit `PROVIDER_CONTRACT.md` (change B: title, verified-offline line, providers list, adding-a-provider line, profile).
4. Write the verification report (canonical `Review-Verdict:` line + the rejection-stage table); gate-check (carve
   PROVIDER_CONTRACT.md), critic re-pass, Codex audit; commit on ACCEPT; **no push**.

## Verification Commands
- `bash .harness/evidence/dmc-v0.3.3-verify.sh` (expect ALL PASS; C5b N/A glm/manual)
- `git diff --name-only HEAD -- .claude/workers/providers .claude/hooks WORKER_*_SCHEMA.md dmc-glm-smoke` (expect ONLY `PROVIDER_CONTRACT.md`)
- gate-check (DMC_GATE_PROTECTED minus the PROVIDER_CONTRACT.md line); then Codex audit.

## Approval Status
**APPROVED** (2026-06-21, revision 3) — Orchestrator flip after the round-2 focused re-pass (dim1/dim3 PASS; dim2's sole
blocker — the `:20` C5b stale line — folded in). Next: `/dmc-start-work`. The `PROVIDER_CONTRACT.md` edit is authorized by
THIS plan and nothing else on the provider surface; commit only on Codex ACCEPT; push deferred (human gate).
