# Do-Me-Coding — Provider Adapter Contract (v0.2.4)

The normative contract every Worker Bridge provider adapter MUST satisfy. It is asserted on provider **outputs and
behavior** (uniform across providers), not on input formats (which differ per provider). Verified offline by
`.harness/evidence/dmc-v0.2.4-verify.sh` (mock + local stub only — no live provider call).

Providers under contract: `glm-api` (`api_key`), `oauth-cli` (`oauth_cli`), and the `provider-router` path where
relevant. Adapters differ in input shape — glm-api consumes a provider *response* fixture, oauth-cli consumes a
`{stdout,stderr}` fixture — but converge on the same `WORKER_RESULT_SCHEMA` output and the same safety behavior.

## Contract dimensions

| # | Invariant | Universal? |
|---|---|---|
| **C1** | **Schema conformance + provider_type match.** A success run yields a result with all required `WORKER_RESULT_SCHEMA` fields, validated ACCEPT by `worker-result-check.py`; `provider_metadata.provider_type` equals the provider's declared type and `provider` matches. | universal |
| **C2** | **Proposal-only behavior.** `no_direct_mutation == true`; the result is a review artifact only — no application step is performed by the adapter. | universal |
| **C3** | **No auto-apply / no direct mutation.** The adapter never invokes `git apply` / patch application and writes no repo/product files (only its `--out` artifact). | universal |
| **C4** | **No credential/token leakage.** Success/override results contain no secret/token shapes (`SECRET_VALUE` + OAuth/JWT/Bearer); a secret/token input is REJECTED somewhere in the pipeline (no unsafe result ACCEPTED); `credential_exposure == none`. | universal |
| **C5a** | **Rejection-shape.** Every unsafe / out-of-scope provider output is **rejected by the pipeline before acceptance**; the rejecting stage exits **non-zero** with a **stderr diagnostic**; **no unsafe result is ever ACCEPTED**. The contract is *"no unsafe result ACCEPTED"* — NOT *"no result persisted"* and NOT *"all providers reject at the same stage."* **Both rejection stages are valid:** an **adapter-level** refusal (e.g. oauth-cli token-guard → no result written) and a **validator-level** REJECT (e.g. glm-api bad-scope/bad-secret → an adapter result is written, adapter exit 0, then `worker-result-check.py` REJECTs it) both conform, provided nothing unsafe is ACCEPTED. | universal |
| **C5b** | **Timeout.** Capability-scoped: applies ONLY to providers whose adapter performs **process-level execution** in mock/offline tests (`exec_timeout` capability). For v0.2.4 that is **oauth-cli** (`fake-cli.py timeout` → killed + fail-closed). **glm-api = N/A for the mock contract** — its timeout is live-network-path behavior covered by the GLM live smoke lane (`dmc-glm-smoke`), not this offline contract. N/A is NOT a failure. | conditional |
| **C6** | **stdout/stderr handling.** With `--out`: the result goes to the file plus a `wrote result -> path` line on stdout. Without `--out`: the result JSON is printed to stdout. No secret/token ever appears on stdout or stderr; stderr carries diagnostics only. | universal |
| **C7** | **Mock-mode determinism.** The same provider + same fixture run twice yields a **byte-identical `--out` file**. **Caveat:** this holds today because `invocation_id`/`generated_at` are fixture/default-derived in mock. A future provider emitting a **real timestamp / random id** would need a normalization step (mask those fields) before the byte-identical comparison. | universal (with caveat) |
| **C8** | **provider_target routing compatibility.** The router selects the provider from `provider_target.{type,provider}` (verifiable via `--print-dispatch`), and a routed `--mock` run produces a **byte-identical `--out` JSON file** to direct adapter invocation. Scope: `--out` JSON file only, `--mock` mode only — NOT stdout/stderr, and NO live-mode byte-identity claim (live results carry provider-supplied ids/timestamps that legitimately vary). | universal |
| **C9** | **Protected-file non-mutation.** Running the contract suite mutates no adapter/hook/schema/router/`dmc-glm-smoke` file (`git diff` empty). | universal |
| **C10** | **No live provider calls.** Every contract assertion uses `--mock` or the offline `fake-cli.py` stub; no `--live` against a real provider; no network, no real credential, no token store. | universal |
| **C11** | **Context-guard fail-closed.** Each provider path invokes `worker-context-guard.sh` BEFORE provider dispatch; a secret-bearing task (`.env*` in `allowed_files`) is refused pre-dispatch (non-zero exit, no payload built, no adapter run). | universal |

## Rejection-stage note (C4 / C5a)

The contract deliberately does **not** mandate a single rejection stage. Unsafe output may be caught:
- at the **adapter** (e.g. oauth-cli's token-material guard redacts-and-rejects before writing any result), or
- at the **validator** (`worker-result-check.py` REJECTs an adapter-written result for out-of-scope paths, disallowed
  categories, inline secrets, or `files_changed != diff paths`).

Both are conforming. The only hard requirement is that **no unsafe result is ever ACCEPTED** (adapter exit 0 **and**
validator ACCEPT). A provider that lets an out-of-scope/secret result pass both stages violates the contract.

## Adding a new provider

A new adapter is contract-conformant when `dmc-v0.2.4-verify.sh` passes every universal dimension for it (and C5b iff
it has the `exec_timeout` capability). Reuse the descriptor-table pattern: declare its success / adversarial-scope /
override / secret-or-token / empty fixtures and its expected `provider_type`; the same C1–C11 battery then applies.
If the provider emits non-deterministic id/timestamp fields, add a normalization step before the C7/C8 byte-identical
comparisons (see the C7 caveat).
