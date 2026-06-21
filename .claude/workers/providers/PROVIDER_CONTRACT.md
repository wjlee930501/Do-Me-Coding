# Do-Me-Coding — Provider Adapter Contract (v0.3.3)

The normative contract every Worker Bridge provider adapter MUST satisfy. It is asserted on provider **outputs and
behavior** (uniform across providers), not on input formats (which differ per provider). Verified offline by
`.harness/evidence/dmc-v0.3.3-verify.sh` — the unified three-provider suite (`dmc-v0.2.4-verify.sh` remains the original
glm-api/oauth-cli suite); mock + local stub only — no live provider call.

Providers under contract: `glm-api` (`api_key`), `oauth-cli` (`oauth_cli`), `manual-import` (`manual_import`), and the
`provider-router` path. Adapters differ in input shape — glm-api consumes a provider *response* fixture, oauth-cli a
`{stdout,stderr}` fixture, manual-import a manually-supplied *envelope v1* artifact (`--import`) — but converge on the same
`WORKER_RESULT_SCHEMA` output and the same safety behavior.

**manual_import profile (v0.3.3):** a **pure-validation** importer — **no live mode**, so **C5b is N/A** and **C10
trivially holds**. Its OAuth-token-class + strict-envelope checks are **adapter-sole gates** (the validator covers
neither), while scope / disallowed-category / sk-class-secret are **validator-backstopped in code**. All current
manual_import adversarial fixtures reject at the **adapter** stage (the validator backstop exists but is not the
demonstrated stage) — a legitimate rejection-stage difference permitted by C5a.

## Contract dimensions

| # | Invariant | Universal? |
|---|---|---|
| **C1** | **Schema conformance + provider_type match.** A success run yields a result with all required `WORKER_RESULT_SCHEMA` fields, validated ACCEPT by `worker-result-check.py`; `provider_metadata.provider_type` equals the provider's declared type and `provider` matches. | universal |
| **C2** | **Proposal-only behavior.** `no_direct_mutation == true`; the result is a review artifact only — no application step is performed by the adapter. | universal |
| **C3** | **No auto-apply / no direct mutation.** The adapter never invokes `git apply` / patch application and writes no repo/product files (only its `--out` artifact). | universal |
| **C4** | **No credential/token leakage.** Success/override results contain no secret/token shapes (`SECRET_VALUE` + OAuth/JWT/Bearer); a secret/token input is REJECTED somewhere in the pipeline (no unsafe result ACCEPTED); `credential_exposure == none`. | universal |
| **C5a** | **Rejection-shape.** Every unsafe / out-of-scope provider output is **rejected by the pipeline before acceptance**; the rejecting stage exits **non-zero** with a **stderr diagnostic**; **no unsafe result is ever ACCEPTED**. The contract is *"no unsafe result ACCEPTED"* — NOT *"no result persisted"* and NOT *"all providers reject at the same stage."* **Both rejection stages are valid:** an **adapter-level** refusal (e.g. oauth-cli token-guard → no result written) and a **validator-level** REJECT (e.g. glm-api bad-scope/bad-secret → an adapter result is written, adapter exit 0, then `worker-result-check.py` REJECTs it) both conform, provided nothing unsafe is ACCEPTED. | universal |
| **C5b** | **Timeout.** Capability-scoped: applies ONLY to providers whose adapter performs **process-level execution** in mock/offline tests (`exec_timeout` capability). For v0.3.3 the sole `exec_timeout` provider is **oauth-cli** (`fake-cli.py timeout` → killed + fail-closed). **glm-api and manual-import = N/A** for the mock contract (glm-api's timeout is live-network behavior covered by `dmc-glm-smoke`; manual-import performs no process execution). N/A is NOT a failure. | conditional |
| **C6** | **stdout/stderr handling.** With `--out`: the result goes to the file plus a `wrote result -> path` line on stdout. Without `--out`: the result JSON is printed to stdout. No secret/token ever appears on stdout or stderr; stderr carries diagnostics only. | universal |
| **C7** | **Mock-mode determinism.** The same provider + same fixture run twice yields a **byte-identical `--out` file**. **Caveat:** this holds today because `invocation_id`/`generated_at` are fixture/default-derived in mock. A future provider emitting a **real timestamp / random id** would need a normalization step (mask those fields) before the byte-identical comparison. | universal (with caveat) |
| **C8** | **provider_target routing compatibility.** The router selects the provider from `provider_target.{type,provider}` (verifiable via `--print-dispatch`), and a routed offline run via the provider's input flag (`--mock` for glm-api/oauth-cli, `--import` for manual-import) produces a **byte-identical `--out` JSON file** to direct adapter invocation. Scope: `--out` JSON file only, offline mode only — NOT stdout/stderr, and NO live-mode byte-identity claim (live results carry provider-supplied ids/timestamps that legitimately vary). | universal |
| **C9** | **Protected-file non-mutation.** Running the contract suite mutates no adapter/hook/schema/router/`dmc-glm-smoke` file (`git diff` empty). | universal |
| **C10** | **No live provider calls.** Every contract assertion uses the provider's offline input (`--mock` for glm-api/oauth-cli, `--import` for manual-import) or the offline `fake-cli.py` stub; no `--live` against a real provider; no network, no real credential, no token store. | universal |
| **C11** | **Context-guard fail-closed.** Each provider path invokes `worker-context-guard.sh` BEFORE provider dispatch; a secret-bearing task (`.env*` in `allowed_files`) is refused pre-dispatch (non-zero exit, no payload built, no adapter run). | universal |

## Rejection-stage note (C4 / C5a)

The contract deliberately does **not** mandate a single rejection stage. Unsafe output may be caught:
- at the **adapter** (e.g. oauth-cli's token-material guard redacts-and-rejects before writing any result), or
- at the **validator** (`worker-result-check.py` REJECTs an adapter-written result for out-of-scope paths, disallowed
  categories, inline secrets, or `files_changed != diff paths`).

Both are conforming. The only hard requirement is that **no unsafe result is ever ACCEPTED** (adapter exit 0 **and**
validator ACCEPT). A provider that lets an out-of-scope/secret result pass both stages violates the contract.

## Adding a new provider

A new adapter is contract-conformant when `dmc-v0.3.3-verify.sh` (the unified three-provider suite) passes every universal
dimension for it (and C5b iff it has the `exec_timeout` capability). Reuse the descriptor-table pattern: declare its
`INPUT_FLAG`, success / adversarial / (optional override) / secret-or-token fixtures, expected `provider_type`, and the
expected per-fixture rejection **stage**; the same C1–C11 battery then applies (a no-live, pure-validation provider takes
C5b N/A and threads its own `INPUT_FLAG` through every helper, as manual-import does).
If the provider emits non-deterministic id/timestamp fields, add a normalization step before the C7/C8 byte-identical
comparisons (see the C7 caveat).
