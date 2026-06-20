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
