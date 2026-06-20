# Do-Me-Coding v0.2.2 — OAuth / Local-CLI Worker Provider Adapter

## Goal

Add a second **live** Worker Bridge provider adapter, `provider_target.type=oauth_cli`, that obtains a worker
proposal from a **locally-installed, already-authenticated CLI tool** (which owns an OAuth/session credential
outside the repo) instead of from an API key. The adapter shells out to a **validated local binary under the C4
trust model**, feeds it a sanitized task payload, captures its stdout, and normalizes that into a
`WORKER_RESULT_SCHEMA` result.
**Mock-first** (default makes no subprocess call), additive/adapter-only, every existing safety gate preserved,
and — because a CLI tool holds the credential — **DMC never reads, stores, drives, or transmits the OAuth token**.

## User Intent

feature (next provider in the Provider Access Layer: `mock` | `api_key` | `oauth_cli` | `manual_import`)

## Current Repo Findings

- Finding: `oauth_cli` is ALREADY a declared `provider_target.type` value — no schema change is required to add it.
  Source: `WORKER_TASK_SCHEMA.md:26` (`"type": "mock | api_key | oauth_cli | manual_import"`).
- Finding: the roadmap already assigns OAuth/local-CLI to v0.2.2+. The api_key adapter explicitly excludes it.
  Source: `DMC.md:127` (Provider Access Layer; "OAuth/local-CLI → v0.2.2+"), `.claude/workers/providers/glm-api/README.md:27-28`.
- Finding: the proven adapter pattern to mirror is glm-api (v0.2.1 + v0.2.1.1): context-guard FIRST (fail-closed) →
  build sanitized payload → multi-gated live path → `normalize_response()` → `map_to_result()` →
  validated by `worker-result-check.py`. credential_exposure/no_direct_mutation are adapter-stamped, never trusted.
  Source: `.claude/workers/providers/glm-api/glm-api-adapter.py` (committed `1c3e294`).
- Finding: v0.2.1.1 normalization (`_strip_code_fence`, `_first_json_object`, `_parse_content`, `normalize_response`,
  `MAX_CONTENT_LEN=8000`) already solves "tool emits text / fenced JSON / prose / empty → schema-valid result." A
  local CLI's stdout has the SAME shape problem, so the same normalization is reused (adapter-local, self-contained).
  Source: `.claude/workers/providers/glm-api/glm-api-adapter.py` (normalize helpers).
- Finding: `worker-context-guard.sh` (fail-closed pre-dispatch) and `worker-result-check.py` (import validation:
  scope/secret/consistency/disallowed-category) are reusable AS-IS over any adapter's output — they are the safety net.
  Source: `.claude/hooks/worker-context-guard.sh`, `.claude/hooks/worker-result-check.py` (committed `166d0ee`).
- Finding: glm-api's key model (env var, non-printing, redacted header) is NOT reused — `oauth_cli` has no API key in
  env; the credential lives inside the external CLI's own store. The NEW risk is **executing a local binary**, not key
  leakage. This shifts the threat model from "don't leak the key" to "don't execute untrusted/injected commands and
  don't ingest token material from CLI output."
  Source: `.claude/workers/providers/glm-api/CONFIG.md` (env-var key model — intentionally not carried over).

## Relevant Files

| Path | Reason | Allowed to Edit (future approved run) |
|---|---|---|
| `.claude/workers/providers/oauth-cli/oauth-cli-adapter.py` | NEW — the adapter (mock-first; path-validated trusted subprocess; normalize; map) | yes (new) |
| `.claude/workers/providers/oauth-cli/README.md` | NEW — modes + safety contract + "DMC never drives login" | yes (new) |
| `.claude/workers/providers/oauth-cli/CONFIG.md` | NEW — config env-var NAMES (C4-validated binary path, timeout); no secrets | yes (new) |
| `.claude/workers/providers/oauth-cli/fixtures/*.json` | NEW — mock CLI-stdout fixtures (see §7a) | yes (new) |
| `.claude/workers/providers/oauth-cli/fixtures/fake-cli/fake-cli.py` | NEW (C3) — deterministic local stub exercising the real exec wrapper (no live provider) | yes (new) |
| `.harness/evidence/dmc-v0.2.2-verify.sh` | NEW — mock-only verification harness | yes (new) |
| `.harness/verification/dmc-v0.2.2-oauth-cli-adapter.md` | NEW — verification report | yes (new) |
| `INSTALL_MANIFEST.md`, `.claude/install/dmc-install.sh` / `dmc-uninstall.sh` | edit ONLY if installer must wire the new provider dir (mirror glm-api wiring) — additive | yes (if needed) |
| `DMC.md` / `CLAUDE.md` | edit ONLY to note oauth_cli is now a live provider + its credential policy — additive doc | yes (if needed) |
| `WORKER_TASK_SCHEMA.md`, `WORKER_RESULT_SCHEMA.md`, `WORKER_REVIEW_SCHEMA.md` | NO change (oauth_cli already declared; result shape unchanged) | no (expected) |
| `.claude/hooks/*` (guards/validators), `dmc-glm-smoke`, glm-api adapter | read-only — REUSED, not modified | no |

## Out of Scope

- Multi-worker orchestration / fan-out (v0.3).
- Automatic patch application / `git apply` / auto-apply of worker output (always proposal-only).
- Broad provider-abstraction rewrite or a shared `providers/_lib` extraction (normalization is duplicated
  adapter-local for now; refactor deferred).
- A live OAuth login/refresh flow driven BY DMC — DMC never authenticates, never opens a browser, never reads/writes
  the token. The user logs into the external CLI separately, outside DMC. Live exec is opt-in and deferred to an
  explicit later approval (this plan ships mock-first; no live CLI call during planning or build).
- Background daemon, CI automation, cost/quota optimization.
- Changes to schemas/guards/validators/`dmc-glm-smoke` (none expected; the validator gates scope/diff/disallowed/
  mutation over the output). NOTE: the validator's inline-secret scan does NOT cover OAuth-token shapes — strengthening
  `worker-result-check.py`'s detector for JWT/Bearer/OAuth tokens is a recommended **future v0.2.x defense-in-depth**
  item, explicitly OUT OF SCOPE here (this adapter-only plan mitigates via the C1 adapter token-guard instead).
- Editing `WORKER_TASK_SCHEMA.md` (incl. its stale historical "v0.2: type ∈ {mock, manual_import} only" note on
  line 40) — left as historical documentation; NOT edited in this scope (`oauth_cli` is already a declared type).

## Proposed Changes

### 1. Why v0.2.2 exists after the GLM API adapter
The api_key adapter (v0.2.1) covers providers reached by a raw HTTP key. Many capable coding models are reachable
only through an **authenticated local CLI** (OAuth/device-login/session), where the user has already logged in and
the token is held by that CLI — not available (and not desirable) as a repo/env secret. v0.2.2 lets DMC use such a
provider for worker proposals **without DMC ever touching the credential**, while keeping the same
propose→decide→verify discipline.

### 2. Target local-CLI / OAuth provider assumptions
- A CLI binary is installed locally and **already authenticated** by the user out-of-band (its own `login`).
- The CLI exposes a **non-interactive** "run a prompt" subcommand that reads a prompt (stdin or a temp file) and
  writes the model's answer to **stdout**; and a **non-interactive auth-status** subcommand that reports
  authenticated yes/no WITHOUT printing token material and WITHOUT triggering a login.
- The CLI does NOT require network creds from DMC; it manages its own session/token in its own store (keychain/config).
- Assumed honest-but-unsanitized output: stdout may be plain text, JSON, fenced JSON, prose-wrapped JSON, empty, or
  truncated — handled by the reused normalization.

### 3. Credential handling model (the core difference vs api_key)
- **DMC never reads, stores, logs, serializes, transmits, or refreshes the OAuth token.** No `*_API_KEY`-style env
  secret is introduced. The external CLI owns the credential entirely.
- Before any live "run", the adapter performs a **non-interactive auth precheck** (the CLI's status subcommand) and
  parses only an authenticated boolean. If unauthenticated/expired → **fail-closed** with guidance to run the CLI's
  own login OUTSIDE DMC. DMC never drives the login flow.
- **Token-material guard (C1) — the existing `SECRET_VALUE` detector is NOT sufficient for OAuth/CLI output.**
  Empirically, the committed `SECRET_VALUE` regex (`sk-`, `ghp_`, `AKIA…`, PEM, `xox…`) MISSES the token shapes a
  local OAuth CLI actually emits. The adapter MUST add an explicit OAuth/bearer/JWT token detector (in addition to,
  not instead of, `SECRET_VALUE`) covering at minimum:
  - JWT-like tokens: `eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+` (access_token / id_token)
  - Bearer tokens: `(?i)bearer\s+[A-Za-z0-9._~+/-]+=*`
  - Authorization headers: `(?i)authorization\s*:\s*\S+`
  - `access_token`, `refresh_token`, `id_token` in any `key: value` / `key=value` / JSON form: `(?i)(access_token|refresh_token|id_token)["'\s:=]+\S+`
  - GitHub tokens: `gh[opsu]_[A-Za-z0-9]{20,}` (covers `gho_`, `ghp_`, `ghs_`, `ghu_`)
  - Google OAuth tokens: `ya29\.[A-Za-z0-9._-]+`
  - any other CLI stdout/stderr containing token-like material (defense-in-depth catch-all alongside the above).
  The adapter scans BOTH stdout AND stderr with this combined detector BEFORE storing/normalizing; **any apparent
  token/secret → redact-and-reject (fail-closed) before result persistence** — the raw output is never written to the
  result, evidence, or `.harness/` un-redacted. Raw CLI output, if stored at all, is local-only/gitignored and redacted.
- **Accepted false-positive trade-off (fail-closed by default):** these patterns can intentionally **over-reject**
  legitimate OAuth-related code or documentation a worker might propose (e.g. prose containing "bearer …", or a snippet
  documenting `{"access_token": "<redacted>"}`). For v0.2.2 this over-rejection is an **accepted fail-closed trade-off**
  — rejecting a legitimate proposal never leaks a credential, and the user can re-run. The implementation MAY reduce
  false positives with a **value-side secret-likeness heuristic** (length/entropy/charset of the value after the key),
  and SHOULD then treat obvious placeholders — `<redacted>`, `***`, `$TOKEN`, `$ACCESS_TOKEN`, `<...>`, and example-only
  dummy values — as NOT real token material. **The default requirement is not weakened either way:** real-looking
  JWT / Bearer / `access_token` / `refresh_token` / `id_token` / GitHub (`gh[opsu]_…`) / Google (`ya29.…`) token
  material MUST redact-and-reject before persistence.
- **Why this guard is load-bearing:** `worker-result-check.py`'s inline-secret scan uses the SAME `SECRET_VALUE`
  regex, so the **validator does NOT currently backstop OAuth-token shapes** (a JWT in `instructions`/`summary` would
  pass validation). Therefore the **oauth-cli adapter token-guard is the PRIMARY in-scope safety net** against OAuth
  token leakage; it must be comprehensive. (Strengthening the validator's detector is noted as a future
  defense-in-depth item in Out of Scope — not changed by this adapter-only plan.)
- Config env vars name only the **binary location (validated by the C4 trust model) and timeout** — never a
  credential (see CONFIG.md).

### 4. Adapter input/output contract
- **Input:** the standard sanitized `WORKER_TASK_SCHEMA` bundle (same as glm-api). `worker-context-guard.sh` runs
  FIRST (fail-closed). `build_payload()` reuses glm-api's sanitization (objective, context_summary, clipped
  `relevant_snippets`, allowed/forbidden file NAME lists, model) and re-asserts no secret VALUE in the payload.
- **CLI invocation (live):** `subprocess.run([BIN, <subcmd>, <flags…>], input=<payload JSON>, capture_output=True,
  text=True, timeout=…, shell=False)` — **argv list, `shell=False` ALWAYS, never a shell string, no shell
  interpolation**; the payload goes via **stdin or a temp file**, NEVER interpolated into argv; no untrusted task
  content placed on the command line. A bounded timeout kills a hung CLI (→ fail-closed). A non-zero CLI exit →
  fail-closed (no partial result trusted). The child runs with a **minimal environment** (an explicit minimal env;
  do NOT export repo/DMC secrets or inherit the full parent environment).
- **`DMC_OAUTHCLI_BIN` trust model (C4):** the binary is a **trusted local dependency the user configures**, validated
  to be:
  - an **absolute path** only (reject relative paths and bare names),
  - an **existing regular file** that is **executable** (reject directories, devices, missing paths),
  - **not a symlink** (reject symlinks; resolve and re-check to mitigate TOCTOU as far as practical — validate the
    final resolved target, and re-validate immediately before exec),
  - **never an arbitrary shell string** (no metacharacters, no `;|&$<>()` etc.; the value is an argv[0] path, not a
    command line).
  Trust assumption (documented in README/CONFIG): the configured CLI is the user's own authenticated tool on their own
  machine — DMC trusts it as a local dependency but still constrains *how* it is invoked (path validation + `shell=False`
  + off-argv payload + timeout + minimal env). DMC does not fetch, install, or auto-discover binaries.
- **Output (C2) — exact normalization reuse (CLI stdout is a STRING, not a GLM `choices` envelope):** feeding raw
  stdout directly to `normalize_response()` would be a bug — `normalize_response(resp)` short-circuits on
  `not isinstance(resp, dict) or "choices" not in resp` and returns the input unchanged, so a stdout string would pass
  through and then `map_to_result(task, <str>)` would call `<str>.get(...)` → AttributeError crash. **Chosen approach
  (preferred): wrap stdout in a synthetic GLM-shaped envelope** before reuse:
  ```python
  envelope = {"choices": [{"message": {"content": cli_stdout}, "finish_reason": "stop"}]}
  norm = normalize_response(envelope)   # reuses fence-strip + first-balanced-object + json.loads-only + fallback + bound
  result = map_to_result(task, norm)
  ```
  This reuses the PROVEN v0.2.1.1 path verbatim (fence-strip, first-balanced-object, `json.loads` only / never eval/exec,
  defensive empty/missing handling, `MAX_CONTENT_LEN` bound, plain-text fallback) with zero new parsing logic. Order:
  `CLI stdout → token-guard scan (C1) → synthetic-envelope wrap → normalize_response() → map_to_result()`. The
  token-guard runs FIRST so token material never reaches the parser/result.
- **Modes:** `--mock <fixture>` (default; NO subprocess) reads a fixture representing CLI stdout and normalizes it.
  `--live --allow-exec` (strongly opt-in) is the only path that executes the CLI.

### 5. How worker output maps to WORKER_RESULT_SCHEMA
- Identical mapping to glm-api: `summary`, `files_considered`, `files_changed`, `proposed_patch`, `instructions`,
  `confidence` come from the parsed/normalized stdout; everything else defaults safely.
- **Adapter-stamped, never from the model/CLI:** `no_direct_mutation=True`; `provider_metadata.credential_exposure="none"`;
  `provider_type="oauth_cli"`; `provider="oauth-cli"`; `model_claimed` from the task/config; `invocation_id` adapter-generated.
- The result is a PROPOSAL only; it is then validated by `worker-result-check.py` (scope ⊆ allowed_files, ∩ forbidden=∅,
  files_changed==diff paths, no disallowed category, no inline secret). The CLI cannot widen scope or inject secrets past it.

### 6. Safety gates
- **Scope guard:** unchanged. The adapter never applies anything; an accepted proposal is later realized via
  scope-guarded `Edit`/`Write` under a `/dmc-start-work` scope — never `git apply`, never auto-apply.
- **Secret guard / context-guard:** `worker-context-guard.sh` runs FIRST (fail-closed) on the task bundle (reused
  unchanged); `secret-guard.sh` continues to protect `.env*`/credential paths from Read/Grep/Glob.
- **No mutation:** pure transform; writes ONLY the local-only `--out` result artifact. `git status` clean before/after.
- **No git apply / no auto-apply:** asserted; README forbids; only proposal-only output.
- **NEW — subprocess-execution safety (C4):** absolute-path, non-symlink, regular+executable binary (validated, with
  TOCTOU re-check before exec); `shell=False` always; argv list; payload via stdin/temp (never argv); bounded timeout
  (→ fail-closed); minimal explicit child env; stdout/stderr bounded; non-zero CLI exit → fail-closed.
- **NEW — token-material guard (C1):** stdout AND stderr scanned with `SECRET_VALUE` **PLUS the explicit OAuth/bearer/
  JWT patterns in §3** before persistence/normalization; apparent token/secret → **redact-and-reject before result
  persistence**. The `SECRET_VALUE` regex alone MISSES OAuth shapes (empirically verified), and the validator shares
  that blind spot — so this adapter guard is the primary in-scope net for OAuth tokens. DMC never reads the OAuth
  token; the auth precheck is a non-interactive, token-blind status subcommand (live-path only; mocked in the harness).

### 7. Mock fixtures + fake-CLI stub (mock-first; NO live provider)

**(a) `--mock` stdout fixtures** — each represents **CLI stdout** for the toy task (normalized via the synthetic-
envelope path of §4-C2):
- `cli-response-success.json` — stdout = bare JSON object → populated in-scope result → validator ACCEPT.
- `cli-response-fenced.json` — stdout = prose + ```` ```json ```` fenced object → extracted → ACCEPT.
- `cli-response-plain-text.json` — stdout = prose, no JSON → plain-text fallback (instructions), `confidence=low`, ACCEPT.
- `cli-response-empty.json` — stdout = "" → empty-but-valid result, no crash, ACCEPT (also proves no string `.get` crash, C2).
- `cli-response-bad-scope.json` — parsed `files_changed` out of scope → validator REJECT.
- `cli-response-token-leak.json` (C1) — stdout contains a **JWT/Bearer-style token that `SECRET_VALUE` MISSES**
  (e.g. `Bearer eyJhbGciOi…fake.jwt.sig` or `access_token=ya29.fake…`) → token-guard redact-and-reject. Using a
  SECRET_VALUE-missed shape is mandatory so the test proves the NEW detector, not the old one.
- `cli-response-stderr-token-leak.json` (C1) — token-like material on **stderr** (clean stdout) → still redact-and-reject
  (proves both streams are scanned).
- `cli-response-override-attempt.json` — stdout claims `credential_exposure="leaked"`/`no_direct_mutation=false`
  → adapter still stamps `none`/`true`.

**(b) Local fake-CLI stub (C3) — exercises the REAL exec wrapper without any live provider.** Commit a tiny
deterministic stub script (e.g. `fixtures/fake-cli/fake-cli.py`) under the provider's fixture/test dir; the harness
points `DMC_OAUTHCLI_BIN` at it (absolute path) to drive the live wrapper offline. Required stub modes (selected via an
arg/env the stub reads):
- **success** — prints well-formed JSON to stdout, exit 0 → normalized, ACCEPT.
- **fenced/prose** — prints fenced/prose stdout → extracted/fallback.
- **nonzero-exit** — exits non-zero → adapter **fail-closed** (no partial result trusted).
- **timeout** — sleeps past the bounded timeout → adapter **kills + fail-closed**.
- **stdout-token** — prints a JWT/Bearer token to stdout → **redact-and-reject**.
- **stderr-token** — prints a token to stderr → **redact-and-reject**.
- **auth-unauthenticated** — auth-status subcommand reports not-authenticated → adapter **fail-closed BEFORE** the run
  subcommand (DMC never drives login).
- (binary-resolution negatives are tested by pointing at a relative path / symlink / non-exec / missing target → refused.)

**This is still NO live provider call:** the stub is a deterministic local script — no external provider, no real OAuth
credential, no network, no token store. It exercises only DMC's own subprocess wrapper logic.

### 8. Verification plan (mock-only / local-stub-only, NO live provider)
- `python3 -m py_compile oauth-cli-adapter.py`.
- **`--mock` stdout fixtures (§7a):** run adapter `--mock` over each → result; validate with `worker-result-check.py`.
  Assert success/fenced → populated structured fields + ACCEPT; plain-text/empty → safe fallback + ACCEPT; **empty stdout
  produces a valid result and does NOT raise AttributeError (C2 string-`.get` crash guard)**; bad-scope → REJECT;
  stdout-token-leak (JWT/Bearer, SECRET_VALUE-missed) → redacted/rejected, no token in result/evidence; stderr-token-leak
  → redacted/rejected; override-attempt → emitted `credential_exposure=none`/`no_direct_mutation=true`.
- **Token-detector unit test (C1):** assert the adapter guard MATCHES each shape `SECRET_VALUE` misses — JWT `eyJ…`,
  `Bearer …`, `Authorization:`, `access_token`/`refresh_token`/`id_token`, `gho_`/`ghu_`/`ghp_`/`ghs_`, `ya29.` — i.e.
  the guard is strictly stronger than `SECRET_VALUE`.
- **Fake-CLI stub, real exec wrapper (§7b, C3):** point `DMC_OAUTHCLI_BIN` at the committed local stub and run the live
  wrapper offline. Assert: success → normalized + ACCEPT; nonzero-exit → fail-closed; timeout → killed + fail-closed;
  stdout-token / stderr-token → redact-and-reject; auth-unauthenticated → fail-closed BEFORE the run subcommand.
- **Binary-resolution negatives (C4):** relative path / bare name / symlink / directory / non-executable / non-existent /
  shell-metachar value → refused.
- Assert **mock mode performs NO subprocess** and makes no network call (exec-guard); `grep` confirms `shell=False` and
  no `shell=True`, no `git apply` in the adapter.
- Assert context-guard fail-closed on a secret-bearing task (`.env*` in allowed_files).
- Assert guards/validator/schemas/`dmc-glm-smoke`/glm-api-adapter byte-unchanged (`git diff --name-only` empty).
- **NO live provider call anywhere** — the only subprocess exercised is the deterministic local stub (no external
  provider, no real OAuth credential, no network, no token store). The `--live --allow-exec` path against a REAL CLI is a
  separate, later, explicitly-approved manual step (analogous to `dmc-glm-smoke`).

### 9. Rollback path
**Pre-commit:** `git restore`/remove the new provider dir
`.claude/workers/providers/oauth-cli/` (adapter + README/CONFIG + fixtures), the verify harness, and any additive
installer/doc lines. **Post-commit:** `git revert <v0.2.2-commit-sha>` — additive adapter + fixtures only;
guards/validator/schemas untouched → clean revert; existing providers (mock/api_key) unaffected.

### 10. Commit boundary & suggested message
One commit: new `oauth-cli` provider (adapter + README + CONFIG + fixtures) + verify harness + verification report
+ plan, and ONLY-IF-NEEDED additive installer/doc wiring. **No** schema/guard/validator/`dmc-glm-smoke`/glm-api
changes. Suggested message:
`feat(dmc): add oauth-cli worker provider adapter (mock-first)`

### 11. Out of scope (restated for the commit)
Multi-worker orchestration (v0.3); automatic patch application/auto-apply; broad provider-abstraction rewrite or
shared-lib extraction; live OAuth flow / DMC-driven login (live exec deferred to explicit later approval).

## Acceptance Criteria

- Criterion: `oauth_cli` adapter exists and is mock-first (default `--mock` performs no subprocess and no network).
  Verification: `--mock cli-response-success.json` → result; no process spawned (exec-guard test passes).
- Criterion: CLI stdout (bare JSON) populates summary/files_changed/proposed_patch/confidence; validator ACCEPT.
  Verification: `--mock cli-response-success.json` → populated, in-scope; `worker-result-check.py` ACCEPT.
- Criterion: fenced/prose-wrapped stdout is extracted (reused normalization); plain-text/empty fall back safely.
  Verification: fenced → structured fields; plain-text → instructions+`confidence=low`; empty → no crash; all ACCEPT.
- Criterion: adversarial stdout cannot bypass the validator (out-of-scope/secret/disallowed-category).
  Verification: `cli-response-bad-scope.json` → REJECT.
- Criterion (C1): the adapter token-guard catches OAuth/bearer/JWT shapes that `SECRET_VALUE` MISSES.
  Verification: unit test — guard matches JWT `eyJ…`, `Bearer …`, `Authorization:`, `access_token`/`refresh_token`/`id_token`, `gh[opsu]_…`, `ya29.…`; `SECRET_VALUE` alone does not.
- Criterion (C1): token material in stdout OR stderr is never persisted; apparent token → redact-and-reject before result write.
  Verification: `cli-response-token-leak.json` (JWT/Bearer, SECRET_VALUE-missed) AND `cli-response-stderr-token-leak.json` → adapter refuses/redacts; no token string in result/evidence.
- Criterion (C2): raw CLI stdout cannot cause an AttributeError / string `.get` crash.
  Verification: `cli-response-empty.json` and a plain-string stdout → adapter produces a valid result (synthetic-envelope path), exit 0, no traceback.
- Criterion (C3): the real exec wrapper is exercised offline via the local stub for nonzero-exit and timeout.
  Verification: stub `nonzero-exit` → fail-closed; stub `timeout` (sleep past bound) → killed + fail-closed; stub `success` → normalized + ACCEPT.
- Criterion: DMC never drives login and fails closed when unauthenticated.
  Verification: stub/`cli-auth-unauthenticated` auth-status = not authenticated → fail-closed before any run subcommand; clear non-interactive message.
- Criterion: adapter-stamped fields cannot be overridden by CLI output.
  Verification: override-attempt fixture → emitted `credential_exposure="none"`, `no_direct_mutation=true`.
- Criterion (C4): subprocess invocation is injection-safe and the binary trust model holds.
  Verification: relative/bare-name/symlink/directory/non-executable/non-existent/shell-metachar binary value → refused; `grep` confirms `shell=False` and no `shell=True`; payload passed via stdin/temp, never argv.
- Criterion: no repo mutation, no `git apply`, no auto-apply.
  Verification: `git status` clean before/after mock run; grep adapter for `git apply`/`shell=True` → none.
- Criterion: schemas/guards/validators/`dmc-glm-smoke`/glm-api-adapter byte-unchanged.
  Verification: `git diff --name-only .claude/hooks/ WORKER_*_SCHEMA.md dmc-glm-smoke .claude/workers/providers/glm-api/` → empty.
- Criterion: no live CLI call in build verification.
  Verification: harness uses `--mock` only; exec-guard proves no subprocess.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Executing a local binary = arbitrary-command surface | high | C4 trust model: absolute-path + regular + executable + non-symlink (TOCTOU re-check) binary; `shell=False`; argv list; payload via stdin/temp (never argv); bounded timeout(→fail-closed); minimal explicit child env; non-zero exit fail-closed. |
| CLI prints token/secret material in stdout/stderr | high | C1 token-guard = `SECRET_VALUE` + explicit OAuth/bearer/JWT patterns (the regex alone MISSES OAuth shapes, empirically); scans BOTH streams before persistence; redact-and-reject; raw output local-only/gitignored; DMC never reads the token store. **Validator does NOT backstop OAuth tokens → adapter guard is the primary net.** |
| Reusing normalize_response on raw stdout string crashes (string `.get`) | high | C2: wrap stdout in a synthetic `{"choices":[{"message":{"content":…}}]}` envelope before `normalize_response`; empty/plain-string fixtures assert no AttributeError. |
| Exec wrapper (timeout / non-zero exit / streams) ships untested by a stdout-only harness | high | C3: committed local fake-CLI stub drives the REAL wrapper offline (success/fenced/nonzero-exit/timeout/stdout-token/stderr-token/unauthenticated); no live provider/credential/network. |
| Adapter accidentally triggers an interactive OAuth login | med | Auth precheck uses the CLI's non-interactive status subcommand only; never invokes login; unauthenticated → fail-closed with guidance. |
| Malicious/erroneous CLI output widens scope or injects secrets | high | Adapter stamps credential_exposure=none/no_direct_mutation=true; `worker-result-check.py` REJECTs out-of-scope/secret/disallowed; files_changed must equal diff paths. |
| Normalization drift vs glm-api (duplicated logic) | med | Duplicate the PROVEN v0.2.1.1 helpers verbatim; mirror the same fixtures; note future shared-lib extraction is out of scope. |
| Mock path accidentally execs the CLI | med | Exec-guard test asserts zero subprocess in `--mock`; default mode has no exec code path. |
| Scope creep into schema/guard changes | low | oauth_cli already in schema; adapter-only; acceptance asserts guards/schemas unchanged. |
| Accidental live exec during build/CI | high | Live requires `--live --allow-exec` + auth-OK + not-CI; mock-only verification; a real CLI smoke is a separate later approved step. |

## Assumptions

| Assumption | Confidence | How to Verify |
|---|---|---|
| `oauth_cli` needs no schema change (already a declared type) | high | `WORKER_TASK_SCHEMA.md:26`. |
| Target CLI has non-interactive "run" + "auth status" subcommands writing to stdout | med | Confirm against the specific CLI's docs before live exec (planning makes no live call). |
| The CLI owns the OAuth token; DMC need never read it | high | Design constraint; auth precheck parses only a boolean; token-guard rejects token-bearing output. |
| Reused v0.2.1.1 normalization suffices for CLI stdout (via synthetic envelope, C2) | high | Same text/JSON/fenced/empty shapes; envelope-wrap reuses the proven path; empty/plain-string fixtures assert no crash. |
| `worker-result-check.py` suffices as the safety net over CLI output | high (scope) / **low (OAuth secrets)** | Gates scope/diff/disallowed/mutation (provider-agnostic). Does NOT cover OAuth-token shapes → C1 adapter guard is the in-scope net for tokens. |

## Execution Tasks

- [ ] DMC-T001: Scaffold `.claude/workers/providers/oauth-cli/` (adapter skeleton mirroring glm-api: context-guard
      first, build_payload, mock/live dispatch, map_to_result with provider_type=oauth_cli, adapter-stamped fields).
- [ ] DMC-T002 (C2): Port the v0.2.1.1 helpers (`_strip_code_fence`, `_first_json_object`, `_parse_content`,
      `normalize_response`, `MAX_CONTENT_LEN`) adapter-local; normalize CLI stdout by **wrapping it in a synthetic
      `{"choices":[{"message":{"content": stdout},"finish_reason":"stop"}]}` envelope** before `normalize_response`
      (never feed a raw string to `normalize_response`/`map_to_result`).
- [ ] DMC-T003 (C4): Implement the live path — non-interactive token-blind auth precheck; binary resolution
      (absolute + regular + executable + non-symlink + TOCTOU re-check; reject relative/bare/metachar/dir/non-exec/
      missing); `subprocess.run` argv + `shell=False` + stdin/temp payload + bounded timeout(→fail-closed) +
      non-zero-exit(→fail-closed) + minimal explicit env; gated behind `--live --allow-exec` + auth-OK + not-CI.
- [ ] DMC-T004 (C1): Token-material guard = `SECRET_VALUE` + explicit OAuth/bearer/JWT patterns (JWT `eyJ…`, `Bearer`,
      `Authorization:`, `access_token`/`refresh_token`/`id_token`, `gh[opsu]_…`, `ya29.…`) over stdout AND stderr;
      redact-and-reject before any persistence; raw-output local-only/gitignored.
- [ ] DMC-T005: README.md + CONFIG.md (modes, "DMC never drives login", `DMC_OAUTHCLI_BIN` trust model, env-var NAMES
      for binary/timeout — no secrets).
- [ ] DMC-T006: Mock stdout fixtures (§7a) incl. JWT/Bearer stdout token-leak + stderr token-leak + override-attempt,
      AND the committed local **fake-CLI stub** (§7b, C3) with all required modes.
- [ ] DMC-T007: `.harness/evidence/dmc-v0.2.2-verify.sh` covering all acceptance criteria — `--mock` fixtures,
      **token-detector unit test (C1)**, **stub-driven exec-wrapper tests incl. timeout + non-zero-exit (C3)**,
      binary-resolution negatives (C4), exec-guard, context-guard fail-closed, byte-unchanged checks. No live provider.
- [ ] DMC-T008: ONLY-IF-NEEDED additive installer/doc wiring (mirror glm-api); verification report; evidence. No live call.

## Verification Commands

| Command | Reason | Required |
|---|---|---|
| `python3 -m py_compile oauth-cli-adapter.py` | syntax | yes |
| `adapter --mock cli-response-success.json` → populated; `worker-result-check.py` ACCEPT | bare-JSON normalization | yes |
| `adapter --mock cli-response-fenced.json` → structured fields; ACCEPT | fenced extraction | yes |
| `adapter --mock cli-response-plain-text.json` → instructions, `confidence=low`; ACCEPT | plain-text fallback | yes |
| `adapter --mock cli-response-empty.json` → no crash; ACCEPT | empty stdout | yes |
| `adapter --mock cli-response-bad-scope.json` → `worker-result-check.py` REJECT | validator gates output | yes |
| `adapter --mock cli-response-token-leak.json` (JWT/Bearer) → redact/reject; no token in result | C1 token-guard (SECRET_VALUE-missed shape) | yes |
| `adapter --mock cli-response-stderr-token-leak.json` → redact/reject | C1 stderr stream scanned | yes |
| token-detector unit test: guard matches JWT/Bearer/Authorization/access_token/refresh_token/id_token/gh[opsu]_/ya29. | C1 guard strictly ⊃ SECRET_VALUE | yes |
| `adapter --mock cli-response-empty.json` / plain string → valid result, no AttributeError | C2 no string `.get` crash | yes |
| stub `success` (via `DMC_OAUTHCLI_BIN`) → normalized; ACCEPT | C3 real exec wrapper, offline | yes |
| stub `nonzero-exit` → fail-closed | C3 non-zero exit handling | yes |
| stub `timeout` (sleep past bound) → killed + fail-closed | C3 timeout handling | yes |
| stub `stdout-token` / `stderr-token` → redact-and-reject | C3 token-guard over real streams | yes |
| stub `auth-unauthenticated` → fail-closed BEFORE run subcommand | DMC never drives login | yes |
| override-attempt fixture → emitted `credential_exposure=none`/`no_direct_mutation=true` | adapter-stamped fields | yes |
| relative/bare/symlink/dir/non-exec/non-existent/metachar binary → refused | C4 injection-safe exec + trust model | yes |
| `grep -nE 'shell=True|git[[:space:]]+apply' oauth-cli-adapter.py` → none | no shell/no git apply | yes |
| exec-guard: `--mock` spawns no subprocess | mock-first, no live exec | yes |
| context-guard fail-closed on `.env*`-bearing task | secret context refused pre-dispatch | yes |
| `git diff --name-only .claude/hooks/ WORKER_*_SCHEMA.md dmc-glm-smoke .claude/workers/providers/glm-api/` → empty | guards/schemas/glm-api/smoke-runner unchanged | yes |

## PASS / PARTIAL / FAIL

- **PASS**: mock-first oauth_cli adapter normalizes CLI stdout (bare/fenced/prose/empty) into in-scope schema-valid
  results via the synthetic-envelope path (C2, no string-`.get` crash) (ACCEPT); validator still REJECTs adversarial
  output; the C1 token-guard catches OAuth/JWT/Bearer shapes `SECRET_VALUE` misses on BOTH streams and redacts-and-
  rejects before persistence; the real exec wrapper is proven offline via the local stub incl. timeout + non-zero-exit
  (C3); DMC never drives login and fails closed unauthenticated; binary resolution is injection-safe (C4); adapter-
  stamped fields can't be overridden; no mutation/`git apply`/auto-apply; schemas/guards/validators/`dmc-glm-smoke`/
  glm-api byte-unchanged; no live provider call.
- **PARTIAL**: normalization/mapping works but one safety gate (C1 OAuth-token detection, C3 stub exec coverage incl.
  timeout/non-zero-exit, C4 binary trust model, or unauthenticated fail-closed) is incomplete — documented.
- **FAIL**: an OAuth/JWT/Bearer token in stdout/stderr is persisted (C1 unmet), raw stdout crashes the adapter (C2
  unmet), the exec wrapper's timeout/non-zero-exit path is unverified (C3 unmet), CLI output bypasses the validator,
  DMC drives an interactive login, the subprocess path is shell-injectable, mock mode execs a CLI, a live provider call
  happens at build, or guards/schemas/glm-api are changed.

## Approval Status

Status: APPROVED
Approver: 대표님
Approved At: 2026-06-21
