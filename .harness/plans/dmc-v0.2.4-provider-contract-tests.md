# Do-Me-Coding v0.2.4 — Provider Contract Tests

## Goal

Define a **common provider-adapter contract** and verify that every existing provider satisfies it — `glm-api`
(`api_key`), `oauth-cli` (`oauth_cli`), and the `provider-router` path where relevant. The contract is asserted on
provider **outputs and behavior** (which are provider-agnostic), not on input formats. This is a **test-only, additive**
milestone: it introduces a written contract spec + a cross-provider contract-test harness that **reuses existing mock
fixtures and the existing validator**, and changes NO adapter/schema/hook/guard/router. A provider that violates the
contract is a **finding to report**, never a thing to silently patch under this plan.

## User Intent

test / verification (harden and formalize the cross-provider invariants the per-provider harnesses already imply)

## 1. Problem statement

- Two live providers ship today (`glm-api` v0.2.1/v0.2.1.1, `oauth-cli` v0.2.2) plus a routing layer (v0.2.3). Each has
  its OWN verify harness (`dmc-v0.2.1*-verify.sh`, `dmc-v0.2.2-verify.sh`, `dmc-v0.2.3-verify.sh`) that re-asserts
  overlapping invariants (schema conformance, proposal-only, no leakage, adversarial → REJECT, no mutation).
- Those shared invariants are **implicit and duplicated**, not written down as a single normative contract. When a 3rd
  provider lands (e.g. v0.2.2+ `manual_import`, or a future adapter), there is no one place that says "every provider
  adapter MUST satisfy X," and no one suite that proves all providers satisfy X uniformly.
- The providers differ in input shape (glm-api consumes a provider *response* fixture; oauth-cli consumes a
  `{stdout,stderr}` fixture) but converge on the SAME `WORKER_RESULT_SCHEMA` output and the SAME safety behavior
  (adapter-stamped `credential_exposure=none`/`no_direct_mutation=true`, proposal-only, no leak, validator-gated). That
  convergence is exactly what a **contract** should pin: assert on the uniform output/behavior, tolerate the input
  differences.
- Empirically grounded: `glm-api` stamps `provider_type=api_key`/`provider=glm-api`; `oauth-cli` stamps
  `provider_type=oauth_cli`/`provider=oauth-cli`; both run `worker-context-guard.sh` first and are gated by
  `worker-result-check.py`. Each already owns a contract-equivalent fixture set (success / bad-scope / override-attempt
  / secret-or-token / empty), so the contract suite needs **no new fixtures**.

## 2. Non-goals

- Changing any adapter, schema, hook, validator, guard, or the router (test-only; see §5 — a contract failure is
  reported, not silently fixed).
- Replacing the per-provider harnesses — the contract suite **complements** them: it asserts the COMMON contract across
  all providers; the per-provider harnesses keep their provider-specific depth (e.g. glm-api fenced/finish_reason,
  oauth-cli C1–C4 exec-wrapper/token-guard).
- Adding a new provider or a new fixture format.
- Re-testing the full router matrix (that is v0.2.3's harness) — only the routing-compatibility **slice** that proves
  each provider is reachable via its `provider_target` and yields the same result as direct invocation.
- Any live provider call, network, real credential, or `.env*` access.
- Multi-worker orchestration (v0.3); auto-apply; cost/latency concerns.

## 3. Candidate design

- **A written contract spec** `.claude/workers/providers/PROVIDER_CONTRACT.md` — the normative list of invariants every
  provider adapter MUST satisfy (the dimensions below). This is the reference a future provider is checked against. It
  is explicit (O2) that **adapter-level rejection and validator-level rejection are BOTH valid** so long as no unsafe
  output is ever ACCEPTED — the contract does NOT imply a single universal rejection stage (see C5a).
- **A table-driven cross-provider contract harness** `.harness/evidence/dmc-v0.2.4-provider-contract.sh`. It defines a
  **provider descriptor table** (reusing existing fixtures — no new ones). Note the `exec_timeout` **capability** column
  (C5b): a provider is checked for timeout behavior ONLY if it does process-level execution in mock/offline tests.
  | provider | adapter | success | adversarial-scope | override-attempt | secret/token | empty | expected `provider_type` | route key | `exec_timeout` capability |
  |---|---|---|---|---|---|---|---|---|---|
  | glm-api | `glm-api/glm-api-adapter.py` | `glm-response-success-choices.json` | `glm-response-bad-scope-choices.json` | `glm-response-override-attempt.json` | `glm-response-bad-secret.json` | `glm-response-empty-content.json` | `api_key` | `(api_key, glm-api)` | **N/A (mock)** — timeout is live-network; covered by `dmc-glm-smoke` |
  | oauth-cli | `oauth-cli/oauth-cli-adapter.py` | `cli-response-success.json` | `cli-response-bad-scope.json` | `cli-response-override-attempt.json` | `cli-response-token-leak.json` (+ `cli-response-stderr-token-leak.json`) | `cli-response-empty.json` | `oauth_cli` | `(oauth_cli, oauth-cli)` | **yes** — `fake-cli.py timeout` (offline stub) |
- For EACH provider the harness runs the **same battery** of contract assertions (C1–C10 in §6), invoking each provider
  through its own `--mock` CLI with its own fixtures, but asserting **provider-agnostic** properties on the RESULT and
  behavior. Tasks are built inline (mktemp) with each provider's `provider_target.{type,provider}` and
  `allowed_files=["src/setNames.ts"]` to match the success fixtures.
- **Reuse, don't reinvent:** the harness reuses `worker-result-check.py` for schema/scope/secret validation, the
  committed mock fixtures, and (for oauth-cli's error-shape/timeout slice) the committed `fake-cli.py` stub — all
  offline. The router slice uses `provider-router.py --print-dispatch` + a routed `--mock` run.
- **Contract-failure policy:** if any provider FAILS a contract assertion, the harness records it and the run is
  reported as a **finding** (FAIL). The plan does NOT authorize editing the adapter to make it pass — that would be a
  separate, separately-approved change. (This keeps "test-only" honest.)

## 4. File-level implementation scope

| Path | Change | Edit? |
|---|---|---|
| `.claude/workers/providers/PROVIDER_CONTRACT.md` | NEW — normative provider-adapter contract spec (the contract dimensions C1–C11, with C5 split into C5a/C5b) | yes (new) |
| `.harness/evidence/dmc-v0.2.4-provider-contract.sh` | NEW — table-driven cross-provider contract harness (mock/stub only) | yes (new) |
| `.harness/verification/dmc-v0.2.4-provider-contract-tests.md` | NEW — verification report | yes (new) |
| `INSTALL_MANIFEST.md` / `DMC.md` | edit ONLY to reference the contract doc — additive, if needed | yes (if needed) |
| `.claude/workers/providers/{glm-api,oauth-cli}/*` (adapters + fixtures) | **NO change** — exercised, not modified | no |
| `.claude/workers/providers/provider-router.py`, `ROUTING.md` | **NO change** — exercised via `--print-dispatch`/`--mock` | no |
| `WORKER_*_SCHEMA.md`, `.claude/hooks/*` (guards/validators), `dmc-glm-smoke` | **NO change** | no |

## 5. Safety constraints

- **Test-only / additive** — no adapter/schema/hook/validator/guard/router edit. A contract violation is **reported as
  a finding**, never silently fixed (any fix is a separate approved change).
- **No new fixtures required** — the contract reuses each provider's existing committed fixtures; if a genuinely
  missing contract case is discovered, STOP and re-plan rather than inventing fixtures ad hoc.
- **No live provider call** — every assertion is mock (`--mock`) or offline-stub (oauth-cli `fake-cli.py`); no network,
  no real credential, no token store. The `--live` adapter paths are never invoked against a real provider.
- **No `.env*` / credential / token reads** — the harness reads only committed fixtures + adapter outputs; it asserts
  the ABSENCE of secret/token shapes and never prints any.
- **Proposal-only preserved** — the harness applies nothing, runs no `git apply`, never auto-applies; it only invokes
  adapters in `--mock` (which write only their `--out`) and reads the results.
- **Protected-file non-mutation** — `git diff` over adapters/hooks/schemas/router/`dmc-glm-smoke` must be empty after
  the run (C9).
- **Auto-logged evidence** (`.harness/evidence/dmc-v0.2.4-*` if any auto-log appears) stays **untracked/excluded** at
  staging, consistent with prior milestones.

## 6. Verification matrix (the contract — asserted PER provider, mock/stub only)

| # | Contract invariant | How asserted (each provider) |
|---|---|---|
| C1 | **Worker result schema conformance** | success fixture → result has all required `WORKER_RESULT_SCHEMA` fields; `worker-result-check.py` ACCEPT; `provider_metadata.provider_type` == descriptor's expected (`api_key`/`oauth_cli`); `provider` matches |
| C2 | **Proposal-only behavior** | result `no_direct_mutation == true`; result is a review artifact only (no application step invoked) |
| C3 | **No auto-apply** | adapter source contains no `git apply` / patch-apply invocation; no repo file changes during the run |
| C4 | **No credential/token leakage** | success/override results contain no secret/token shapes (`SECRET_VALUE` + OAuth/JWT/Bearer); the secret/token fixture is REJECTED somewhere in the pipeline (glm: validator REJECT; oauth: adapter redact-and-reject) — no unsafe result ACCEPTED; `credential_exposure == none`. Also (O1) a secret-bearing task **fails closed pre-dispatch** (see C11). |
| C5a | **Rejection-shape (universal)** | Every unsafe / out-of-scope provider output is **rejected by the pipeline before acceptance**: the rejecting stage exits **non-zero** and emits a **stderr diagnostic**, and **no unsafe result is ever ACCEPTED**. The contract is *"no unsafe result ACCEPTED,"* **not** *"no result persisted"* and **not** *"all providers reject at the same stage."* Provider-specific rejection stages are explicitly allowed: oauth-cli's token-guard may reject at the **adapter** level and write no result; glm-api's bad-scope / bad-secret may write an **adapter** result (adapter exit 0) that is then **REJECTED** by `worker-result-check.py` (validator exit non-zero); oauth-cli's scope/secret cases may likewise be validator-level depending on the fixture/path. Asserted per provider via each one's adversarial-scope and secret/token fixtures. |
| C5b | **Timeout (conditional / capability-scoped)** | Applies **only** to providers whose adapter performs **process-level execution** in mock/offline tests (see the `exec_timeout` capability column in the §3 descriptor table). For v0.2.4 that is **oauth-cli** (via `fake-cli.py timeout` → killed + fail-closed). **glm-api = N/A for the mock contract** — its timeout is live-network-path behavior covered by the GLM **live smoke** lane (`dmc-glm-smoke`), not this offline provider contract. Expressed as a descriptor **capability**, not a universal invariant. |
| C6 | **stdout/stderr handling** | with `--out`: result goes to the file + a `wrote result -> path` line on stdout; without `--out`: result JSON on stdout; **no secret/token ever on stdout or stderr**; stderr carries diagnostics only |
| C7 | **Mock-mode determinism** | same provider + same fixture run twice → **byte-identical `--out` file**. Caveat (O3): this holds today because `invocation_id`/`generated_at` are fixture/default-derived in mock; a future provider emitting a **real timestamp / random id** would need a normalization step (e.g. mask those fields) before the byte-identical comparison — noted in `PROVIDER_CONTRACT.md`. |
| C8 | **provider_target routing compatibility** | router selects the provider from `provider_target.{type,provider}` (`--print-dispatch` shows the correct adapter); a routed `--mock` run produces a **byte-identical `--out` JSON file** to direct adapter invocation (R2: compares ONLY the `--out` result file, ONLY in `--mock` mode; does NOT compare stdout/stderr chatter and makes NO live-mode byte-identity claim — live results carry provider-supplied ids/timestamps that legitimately vary; mirrors v0.2.3 V3) |
| C9 | **Protected-file non-mutation** | `git diff --name-only` over adapters/hooks/schemas/router/`dmc-glm-smoke` → empty after the full suite |
| C10 | **No live provider calls** | every case uses `--mock`/offline-stub; assert no network egress path is taken (no `--live` against a real provider); `--print-dispatch` used for routing inspection |
| C11 | **Context-guard fail-closed (O1)** | each provider path invokes `worker-context-guard.sh` **before** provider dispatch; a secret-bearing task (`.env*` in `allowed_files`) is **refused pre-dispatch** (non-zero exit, no payload built, no adapter run) — asserted per provider |

Per-provider expansion: the **universal** dimensions (C1, C2, C3, C4, C5a, C6, C7, C9, C10, C11) run once for `glm-api`
and once for `oauth-cli`; **C5b (timeout)** runs ONLY for providers with the `exec_timeout` capability (oauth-cli; N/A
for glm-api in mock); **C8** runs the router slice for both `(api_key, glm-api)` and `(oauth_cli, oauth-cli)`.
The contract is *"no unsafe result ACCEPTED"* — providers may reject at different stages (adapter vs validator) and
still conform.

## 7. Regression risks

| Risk | Severity | Mitigation |
|---|---|---|
| Contract harness accidentally triggers a live call | high | Mock/stub only; no `--live` against a real provider; `--print-dispatch` for routing; assert no network. |
| Asserting on input format couples the contract to one provider | med | Contract asserts on OUTPUT (`WORKER_RESULT_SCHEMA`) + behavior, not on fixture shape; descriptor table absorbs per-provider input differences. |
| A real contract violation gets silently "fixed" in an adapter | high | §5 policy: violations are REPORTED as findings; no adapter edit under this plan (separate approval required). |
| A universal "error shape" invariant that a provider can't share (fake invariant) | high | C5 split: **C5a** rejection-shape asserts *"no unsafe result ACCEPTED"* (allowing adapter-level OR validator-level rejection, with/without a persisted-then-rejected result) — never "no result persisted"; **C5b** timeout is a capability column (oauth-cli only; glm-api N/A in mock, deferred to `dmc-glm-smoke`). No provider is measured against an invariant it structurally lacks. |
| Harness mutates the repo (temp files, results) | med | Results to mktemp dirs outside the repo; C9 asserts protected files byte-unchanged; no `git add`/apply. |
| New fixtures invented to force a pass | low | §5: reuse existing fixtures only; STOP+re-plan if a case is genuinely missing. |
| Contract doc drifts from harness | low | PROVIDER_CONTRACT.md and the harness share the C1–C10 numbering; verification report cross-references both. |

## 8. Rollback plan

- **Pre-commit:** `git restore` / remove the new files (`PROVIDER_CONTRACT.md`, `dmc-v0.2.4-provider-contract.sh`,
  the verification report) and any additive doc/manifest line. No product code touched → nothing else to undo.
- **Post-commit:** `git revert <v0.2.4-commit-sha>` — additive test/doc only; adapters/router/guards/schemas untouched
  → clean revert; all providers behave exactly as before (the suite only observed them).

## 9. Approval Status

Status: APPROVED
Approver: 대표님
Approved At: 2026-06-21
