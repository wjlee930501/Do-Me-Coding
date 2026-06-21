# manual-import provider (v0.3.1)

A **standalone, pure-validation importer** for `provider_target.type = manual_import`. It ingests a manually-supplied,
provider-like **loose** proposal artifact ("manual-import envelope v1"), validates it **fail-closed**, and emits a
normalized `WORKER_RESULT_SCHEMA` result. It is **not** a network/exec provider: no live mode, no credentials, no
network, no provider subprocess (the only subprocess is the read-only `worker-context-guard.sh` on the task).

```
manual-import-adapter.py --task <task.json> --import <artifact.json|-> [--out <result.json>]
```
Exit: `0` accepted · `1` rejected (fail-closed) · `2` usage / `--out` refused. With `--out` the normalized result is
written there (+ a `wrote result -> …` line on stdout); without it, the result prints to stdout. There is **no `--live`,
`--allow-network`, or `--allow-exec`** — manual_import has nothing to call.

## When to use it
A worker proposal produced **out-of-band** (any tool/model the operator ran themselves) is brought into the bridge
through the **same** guarded validation a provider's output faces — so an imported proposal is **never more trusted**
than a provider-generated one, and E2E completion can proceed **offline** with no live provider call.

## manual-import envelope v1 (the accepted input)
The import is a **provider-like loose artifact** — **not** an already-normalized `WORKER_RESULT_SCHEMA` result, and
**not** arbitrary JSON. The human supplies **only** the proposal-substance fields; the adapter **owns** (stamps) every
identity/provenance/safety field. `WORKER_RESULT_SCHEMA` defines MUST-invariants, not a complete required/optional
partition, so the mandatory-in-import set is enumerated here.

| Field | Disposition |
|---|---|
| `summary` · `files_changed` · `confidence` (`low\|med\|high`) | **human — mandatory** |
| `proposed_patch` **or** `instructions` (≥1 non-empty) | **human — mandatory** |
| `files_considered` · `risks` · `assumptions` · `test_suggestions` · `unresolved_questions` · `instructions` | human — optional (default `[]`/empty) |
| `task_id` · `no_direct_mutation` · `provider_metadata` (`provider_type`,`provider`,`model_claimed`,`generated_at`,`invocation_id`,`credential_exposure`) | **adapter-stamped — REJECTED if supplied** |
| any other / unknown key | **REJECTED** (strict allowlist envelope) |

A human cannot assert their own provenance or safety invariants: supplying any adapter-owned field, or any unknown key,
is a fail-closed rejection. `generated_at`/`invocation_id` are deterministic sentinels (no wall-clock/random).

## Safety contract
- **Untrusted input.** Every artifact is validated fail-closed; nothing is trusted because a human supplied it.
- **Real credential gate = the pre-stamp raw scan.** The entire raw import is scanned for secret/token material
  (the **exact** `oauth-cli` `OAUTH_TOKEN_PATTERNS` — JWT/Bearer/`Authorization:`/`ya29.`/`access_token`/`gh[opsu]_` —
  plus the sk-class `SECRET_VALUE`) **before** any result is constructed; a match is **rejected** (never redacted-and-
  emitted). `credential_exposure="none"` describes **only DMC's own handling** after that scan passes — **not** the
  unknown upstream tool the human used (no full-lineage provenance is claimed).
- **No auto-apply.** The result is a review artifact (`no_direct_mutation=true`); `proposed_patch` is unified-diff TEXT,
  never applied. Application happens later via scope-guarded `Edit`/`Write`, never `git apply`.
- **Guard parity.** The adapter is **at least as strict as** `worker-result-check.py`, plus adapter-only superset guards:
  the OAuth-token class and the strict envelope shape are **adapter-sole** gates (the validator covers neither); scope /
  disallowed-category / sk-class-secret / `no_direct_mutation` are also validator-backstopped. Token detectors are
  **reused** (shared-source import) from `oauth-cli-adapter.py` — the exact list, not a re-derived subset.
- **Leak-clean.** Reject diagnostics never echo any value/key/path from the imported artifact. `--out` writes only the
  normalized result; a protected/secret `--out` target is refused (canonicalized guard).

## What this is — and is NOT
manual_import is a **trust-minimized local ingestion lane** that validates a **defined contract** (envelope + safety
battery) — **not** the semantic truth/correctness of the proposal, and **NOT a human-approval bypass.** Acceptance by
this adapter is necessary-but-not-sufficient; the result still passes `worker-result-check.py` and the human Release Gate.

## Out of scope (v0.3.1)
- **No router integration.** `provider-router.py` still refuses `manual_import`; this adapter runs **standalone**. Wiring
  `(manual_import, manual-import)` into the router REGISTRY is a separate, separately-approved routing milestone.
- **No schema change**, no credential/network/live path, no protected-surface change.
