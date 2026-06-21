# Verification Report

Review-Verdict: critic=PASS codex=ACCEPT

(critic=PASS via the 3-round independent critic loop on the plan, R1–R7 resolved. codex=ACCEPT via the Codex Independent
Release Audit of this implementation (thread 019eea04): REVISE → fix (`--out` `..` traversal refusal + V13 assertion) →
ACCEPT; safe-to-stage/commit yes, safe-to-push no.)

## Run ID
dmc-v0.3.1-manual-import-provider

## Plan
`.harness/plans/dmc-v0.3.1-manual-import-provider.md` (Status: APPROVED, revision 3). Approved after a 3-round
independent critic panel (round-1 REVISE R1–R7 → round-2 REVISE R5(a) → round-3 resolved) + human Release Gate flip.
Additive, standalone; router-deferral and schema-no-change critic-accepted.

## Changed Files (all ADDITIVE — no existing/tracked file modified)
- `.claude/workers/providers/manual-import/manual-import-adapter.py` — standalone pure-validation importer.
- `.claude/workers/providers/manual-import/README.md`, `CONFIG.md` — provider docs (envelope v1, parity boundary,
  credential_exposure scoping, "not a human-approval bypass", `DMC_MANUAL_IMPORT_MAX_BYTES`).
- `.claude/workers/providers/manual-import/fixtures/` — 9 synthetic fixtures (fake-only; no real creds / provider output).
- `.harness/evidence/dmc-v0.3.1-verify.sh` — V1–V16 verification harness.
- `.harness/verification/dmc-v0.3.1-manual-import-provider.md` — this report.
- `.harness/plans/dmc-v0.3.1-manual-import-provider.md` — the approved plan.

Unchanged (byte-identical): `provider-router.py`, `ROUTING.md`, `PROVIDER_CONTRACT.md`, `WORKER_*_SCHEMA.md`,
`.claude/hooks/*` (incl. `worker-context-guard.sh` + `worker-result-check.py` — invoked, never edited), glm-api /
oauth-cli adapters, `dmc-glm-smoke`.

## What shipped
`provider_target.type=manual_import`: a standalone, pure-validation importer of a manually-supplied provider-like loose
artifact ("manual-import envelope v1"). NO live/network/credential/provider-subprocess (only the read-only positional
`worker-context-guard.sh`); NO auto-apply; NO schema change; NO router integration (router still refuses `manual_import`).
Pipeline: `--out` guard → positional context-guard → size-bounded read (`--import <file|->`) → **pre-stamp raw secret/
OAuth-token scan (real credential gate)** → strict envelope v1 (adapter-owned & unknown fields rejected) → scope /
disallowed-category → normalize + **deterministic** stamps → emit. Token detectors are **shared-source imports** of the
exact `oauth-cli OAUTH_TOKEN_PATTERNS`/`SECRET_VALUE`/`find_token_material` + the validator's `DISALLOWED`/`diff_paths`
(no re-derived subset; drift-checked by V16). Reject diagnostics are generic/leak-clean.

## Commands Run
| Command | Result |
|---|---|
| `bash .harness/evidence/dmc-v0.3.1-verify.sh` | **17 PASS / 0 FAIL**, exit 0 |
| `worker-result-check.py <task> <V1-result>` | ACCEPT (dogfooded inside V1) |
| `git diff` over the protected surface | empty (byte-unchanged) |
| `git status --porcelain` md5 before/after the run | identical (writes only under `$TMPDIR`) |

## Verification matrix — evidence (17 PASS / 0 FAIL)
- **V1** valid envelope → ACCEPT, schema-conformant, `provider_type=manual_import`, validator ACCEPT.
- **V2** malformed JSON → reject + leak-clean. **V3** missing-mandatory + empty → **adapter-level** reject + leak-clean.
  **V4** unknown/extra field → **adapter-level** reject (strict envelope) + leak-clean.
- **V5** disallowed-category (`package-lock.json`) → C5a rejected, branch confirmed, leak-clean. **V6** OAuth/token-shaped
  content → **adapter-level** reject (adapter sole gate; no token value leaked). **V7** mutation attempt → C5a rejected + leak-clean.
- **V8** deterministic `--out` byte-identical (no wall-clock/random). **V9** secret-bearing task → context-guard fail-closed.
- **V10** no `.env`/credential/implicit read (only `DMC_MANUAL_IMPORT_MAX_BYTES`; no network lib). **V11** only the
  context-guard `subprocess.run`; no `os.system`/`shell=True`/network. **V12** protected files byte-unchanged.
- **V13** `--out` protected target refused (exit 2, not created); benign writes. **V14** real repo byte-identical.
- **V15** imported `credential_exposure!="none"` → **adapter-level** reject + leak-clean. **V16** adapter OAuth patterns
  literally identical to `oauth-cli OAUTH_TOKEN_PATTERNS` (`.pattern`-string compare).

## Safety Posture
No live/network/model-API call; no `.env*`/credential read; no auto-apply / `git apply` / repo write beyond a guarded
`--out`. Imported content untrusted; adapter-owned fields rejected if supplied; the real credential gate is the pre-stamp
raw scan; `credential_exposure="none"` is DMC-handling-scoped only. Adapter at-least-as-strict as `worker-result-check.py`
+ adapter-only superset (OAuth-token class + strict envelope are adapter-sole). Deterministic stamps; leak-clean
diagnostics; no `__pycache__` artifacts (`sys.dont_write_bytecode` + `PYTHONDONTWRITEBYTECODE`). Protected surface
byte-unchanged; router untouched. All fixtures synthetic/fake-only.

## Final Status
**PASS** — 17/17 verification assertions green (V1–V16 + syntax), exit 0; additive-only; protected surface
byte-unchanged; real repo untouched. **Codex Independent Release Audit: ACCEPT** (after the `--out` `..`-traversal fix +
V13 assertion; re-verified 17/17). Staged the approved additive set, gate-check green, committed; **push deferred** to
the human gate.
