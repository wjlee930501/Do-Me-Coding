# oauth-cli — Do-Me-Coding Worker Bridge provider adapter (v0.2.2)

Second **live** provider adapter (`provider_target.type=oauth_cli`). Instead of an API key, it obtains a worker
proposal from a **locally-installed, already-authenticated CLI tool** that owns an OAuth/session credential
**outside** the repo. The adapter maps a sanitized DMC worker task → a CLI invocation → a `WORKER_RESULT_SCHEMA`
result. **Mock-first**: default mode runs no subprocess against the configured CLI.

## Modes
- **Default `--mock <fixture>` (no CLI exec):**
  ```
  oauth-cli-adapter.py --task <task.json> --mock fixtures/cli-response-success.json --out <result.json>
  ```
  The fixture represents CLI output: `{"stdout": "...", "stderr": "..."}`.
- **`--live --allow-exec` (strongly opt-in; unexercised by build/CI):** requires ALL primary gates — explicit
  `--live` + explicit `--allow-exec` + a C4-validated `DMC_OAUTHCLI_BIN` + the CLI reporting **authenticated** +
  a context-guard-approved task. A "not in CI" check is best-effort **defense-in-depth only**.

## Credential model — DMC is token-blind
- **DMC never reads, stores, logs, serializes, transmits, or refreshes the OAuth token.** No `*_API_KEY`-style env
  secret is introduced. The external CLI owns the credential entirely (its own keychain/config).
- **DMC never drives login.** The auth precheck is a **non-interactive, token-blind** status subcommand that yields
  only an authenticated boolean. If unauthenticated → **fail-closed**; log in via the CLI's own login **outside DMC**.
- **Token-material guard (C1):** stdout AND stderr are scanned (`SECRET_VALUE` + explicit OAuth/JWT/Bearer/
  `access_token`/`refresh_token`/`id_token`/`gh[opsu]_`/`ya29.` patterns) **before** any persistence/normalization;
  apparent token material → **redact-and-reject** (fail-closed). Token values are never printed. This guard may
  intentionally over-reject legitimate OAuth-related code/docs — an accepted fail-closed trade-off (obvious
  placeholders like `<redacted>`/`***`/`$TOKEN` are excluded). **Note:** `worker-result-check.py` does NOT currently
  backstop OAuth-token shapes, so this adapter guard is the primary in-scope net.

## Subprocess safety (C4 trust model)
`DMC_OAUTHCLI_BIN` is a **trusted local dependency the user configures**, validated to be an **absolute path** to an
**existing, regular, executable, non-symlink** file (resolved target re-checked for TOCTOU). It is invoked with
`shell=False` (always), an **argv list** (never a shell string, no interpolation), the payload on **stdin** (never on
argv), a **bounded timeout** (→ fail-closed), a **minimal explicit child env** (no inherited repo/DMC secrets), and a
**non-zero exit → fail-closed**. DMC does not fetch, install, or auto-discover binaries.

## Safety contract
- Workers PROPOSE only; the adapter NEVER mutates the repo, runs git, or applies patches. The result is a review
  artifact; application happens later via the DMC scope gate (Edit/Write), never `git apply`, never auto-apply.
- `worker-context-guard.sh` runs FIRST (fail-closed). `build_payload` re-asserts the payload is secret/token-free.
- The produced result is validated by `worker-result-check.py` (schema, scope, consistency, disallowed categories).
- Adapter-stamped, never from the CLI: `credential_exposure="none"`, `no_direct_mutation=true`, `provider_type="oauth_cli"`.

## Out of scope (v0.2.2)
Multi-worker (v0.3); auto-apply / `git apply`; broad provider-abstraction rewrite; a live OAuth login/refresh flow
driven by DMC. The `--live --allow-exec` path against a REAL CLI is a separate, later, explicitly-approved manual step.
