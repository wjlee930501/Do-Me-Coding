# Verification Report

## Run ID

dmc-v0.2.2-oauth-cli-adapter

## Plan

`.harness/plans/dmc-v0.2.2-oauth-cli-adapter.md` (APPROVED 2026-06-21, Approver: 대표님) — adapter-only, mock-first, no live provider call.

## Changed Files

New (`.claude/workers/providers/oauth-cli/`):
- `oauth-cli-adapter.py` — the adapter: context-guard first → `build_payload` (secret/token re-assert) → mock/live dispatch → token-guard → `stdout_to_envelope` (C2) → `normalize_response` (ported v0.2.1.1) → `map_to_result` (provider_type=`oauth_cli`, adapter-stamped `credential_exposure=none`/`no_direct_mutation=true`).
- `README.md`, `CONFIG.md` — modes, token-blind credential model, C4 trust model, "DMC never drives login", env-var NAMES (no secrets).
- `fixtures/cli-response-{success,fenced,plain-text,empty,bad-scope,token-leak,stderr-token-leak,override-attempt}.json` — mock CLI-output fixtures (`{"stdout","stderr"}`).
- `fixtures/fake-cli/fake-cli.py` — deterministic local stub (C3) exercising the REAL exec wrapper offline.

New evidence/verification:
- `.harness/evidence/dmc-v0.2.2-verify.sh` — mock + local-stub verification harness.
- `.harness/verification/dmc-v0.2.2-oauth-cli-adapter.md` — this report.

Unchanged (verified byte-identical): all `.claude/hooks/*` (guards/validators), `WORKER_*_SCHEMA.md`, `dmc-glm-smoke`, `.claude/workers/providers/glm-api/*`.

## Commands Run

| Command | Result | Reason |
|---|---|---|
| `python3 -m py_compile` (adapter + stub) | PASS | syntax |
| `bash .harness/evidence/dmc-v0.2.2-verify.sh` | **28 PASS / 0 FAIL** | full mock + local-stub suite (NO external provider, NO network, NO real credential) |

(One transient harness-arithmetic false-positive in the override check — `grep -c … || echo 0` emitted a stray second line — was fixed to `|| true`; it was never an adapter defect: the result already carried `credential_exposure=none`/`no_direct_mutation=True`/no `leaked`.)

## Acceptance Criteria — Evidence

| Criterion | Result | Evidence |
|---|---|---|
| Mock-first; default `--mock` execs no configured CLI | PASS | exec-guard: tripwire `DMC_OAUTHCLI_BIN` never ran in `--mock` |
| Bare-JSON CLI stdout populates summary/files_changed/proposed_patch/confidence (C2 envelope) | PASS | success → `files_changed=['src/setNames.ts']`, summary+patch, ACCEPT |
| Fenced/prose extracted; plain-text/empty fall back safely | PASS | fenced → structured; plain-text → instructions+`confidence=low`; empty → valid, **no AttributeError (C2)** |
| Adversarial stdout cannot bypass the validator | PASS | bad-scope → REJECT |
| **C1** guard catches OAuth/JWT/Bearer shapes `SECRET_VALUE` misses | PASS | unit test: matches JWT/Bearer/Authorization/access·refresh·id_token/`gh[opsu]_`/`ya29.`; excludes `<redacted>` placeholder; clean diff not flagged |
| **C1** stdout AND stderr token material → redact-and-reject before persistence | PASS | stdout-token & stderr-token (SECRET_VALUE-missed JWT) → fail-closed, no token in result |
| Adapter-stamped fields not overridable by CLI | PASS | override-attempt → `credential_exposure=none`, `no_direct_mutation=True`, no `leaked` in result |
| **C3** real exec wrapper exercised offline (stub) | PASS | success→ACCEPT; fenced→ACCEPT; **nonzero-exit→fail-closed**; **timeout→killed+fail-closed**; stdout/stderr-token→redact-reject; unauthenticated→fail-closed BEFORE run |
| **C4** binary trust model / injection-safe | PASS | relative / non-existent / shell-metachar / symlink / directory / non-executable → all refused; `shell=False`; payload via stdin |
| DMC never drives login; fails closed unauthenticated | PASS | stub auth-status=false → fail-closed before run subcommand |
| No `shell=True`, no `git apply` | PASS | grep → none |
| Context-guard fail-closed on secret-bearing task | PASS | `.env.local` in allowed_files → dispatch refused |
| Schemas/guards/validators/glm-api/`dmc-glm-smoke` byte-unchanged | PASS | `git diff --name-only` empty |
| No live provider call in verification | PASS | only the local deterministic stub is exec'd; no network/credential/token store |

## Scope Review

Result: PASS. Edits confined to the approved scope (`.claude/workers/providers/oauth-cli/`) plus harness/verification under `.harness/`. No schema/hook/validator/guard/glm-api/`dmc-glm-smoke` change.

## Package / Env / Migration Review

Package files changed: no. Env files changed: no — no credential introduced; DMC is token-blind (the OAuth token lives in the external CLI). Migration files changed: no.

## Safety Posture

- Mock-first; the only subprocess exercised against `DMC_OAUTHCLI_BIN` is the local deterministic stub — no external provider, no network, no real OAuth credential, no token store.
- DMC never reads/stores/logs/serializes the OAuth token; auth precheck is non-interactive and token-blind; DMC never drives login.
- C1 token-guard (`SECRET_VALUE` + explicit OAuth/JWT/Bearer patterns) over stdout AND stderr redact-and-rejects before persistence; token values never printed. Validator's OAuth-token blind spot documented; adapter guard is the in-scope net.
- C4 subprocess: validated absolute/regular/executable/non-symlink binary (TOCTOU re-check), `shell=False`, payload off-argv (stdin), bounded timeout → fail-closed, non-zero exit → fail-closed, minimal explicit child env.
- Proposal-only: no repo mutation, no `git apply`, no auto-apply; output validated by `worker-result-check.py`.

## Final Status

**PASS** — 28/28 checks pass; C1–C4 fully exercised (incl. the exec wrapper offline via the stub: timeout + non-zero-exit + both token streams + unauthenticated); validator gating and adapter-stamped fields confirmed; protected files byte-unchanged; no live provider call. Stopped before commit per instruction.
