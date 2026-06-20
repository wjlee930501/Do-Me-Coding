# oauth-cli adapter — CONFIG

Configuration is via environment variables ONLY. **No credential is ever configured here** — the OAuth token is
owned by the external CLI, never by DMC. Never set any secret in the repo, in any committed file, or in `.harness/`.

| Env var | Required | Purpose |
|---|---|---|
| `DMC_OAUTHCLI_BIN` | for `--live` only | **Absolute path** to the local CLI binary. C4-validated: absolute + regular + executable + **non-symlink** + TOCTOU re-check; never a shell string. NOT a credential. |
| `DMC_OAUTHCLI_RUN_SUBCMD` | optional | Subcommand that reads the prompt on stdin and writes the answer to stdout (default `run`). |
| `DMC_OAUTHCLI_AUTH_SUBCMD` | optional | Non-interactive, token-blind auth-status subcommand (default `auth-status`); must emit only an authenticated boolean, never token material. |
| `DMC_OAUTHCLI_TIMEOUT_SECONDS` | optional | Bounded subprocess timeout (default 60); exceeding it → killed + fail-closed. |
| `DMC_OAUTHCLI_MODEL` | optional | Model label recorded in `provider_metadata.model_claimed` (default `oauth-cli-model`). |
| `DMC_FAKECLI_MODE` | tests only | Selects the local fake-CLI stub's behavior in verification (deterministic, non-secret). Absent in production. |

## Safety
- **No OAuth token / credential is ever read, set, printed, logged, or serialized by DMC.** The CLI owns it.
- The child process runs with a **minimal explicit environment** — the full parent env is NOT inherited (no provider
  keys, no repo/DMC secrets leak into the CLI).
- `DMC_OAUTHCLI_BIN` is a path, validated under the C4 trust model; it is never interpreted by a shell (`shell=False`).
- Live mode is multi-gated (see README); default mode is mock / no CLI exec.
