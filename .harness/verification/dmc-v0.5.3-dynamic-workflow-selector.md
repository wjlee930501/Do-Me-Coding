# VERIFICATION — v0.5.3 Dynamic Workflow Selector

Command: `bash .harness/evidence/dmc-v0.5.3-dynamic-workflow-selector.sh --self-test`
Result: **PASS=15 / FAIL=0**, exit 0. Real repo byte-unchanged (deterministic sha256 PRE==POST). Offline/local/read-only;
no env/`.env`/credential read; no network/live call.

## Assertion → requirement map
| AC | Proves |
|---|---|
| AC1 | docs-only ⇒ lane docs-only, effort light (smallest sufficient) |
| AC2 | additive-tooling ⇒ lane additive-tooling |
| AC3 | protected_surface=true ⇒ protected-surface, deep, byte-unchanged gate (anti-downgrade) |
| AC4 | secret_network_live ⇒ secret-network-live-risk, adversarial, live/network/credential gates |
| AC5 | a protected changed-path forces protected-surface despite a docs-only task_class |
| AC5b | a secret changed-path forces secret-network-live-risk |
| AC6 | unknown / missing task_class ⇒ secret-network-live-risk (fail-closed max) |
| AC7 | non-canonical danger booleans (`on`/`enabled`) fail CLOSED (escalate) |
| AC8 | `provider_target=mock` ⇒ category-error refusal (exit 1); a real provider_target ⇒ protected-surface |
| AC9 | `run_mode=mock` does NOT lower the lane (run-mode ≠ provider_target/lane fact) |
| AC10 | STRUCTURAL monotonicity — adding each risk fact never lowers the lane (a broken/empty result FAILS, not passes) |
| AC11 | deterministic + env-independent (`env -i` + credential/workflow-var differential byte-identical) |
| AC12 | structural audit: no curl/wget/--live/env-read/env-hash (`DMC_HASH_CMD`/`${DMC_*}`) in operative source |
| AC13 | env-hash injection: a hostile `DMC_HASH_CMD` is never read/executed; `repo_hash` byte-identical |
| AC14 | read-only: real repo byte-unchanged (deterministic sha256) |

## Adversarial note (self-caught during implementation)
AC10 initially **false-greened**: a nested `"$(lane "{...,$add}")"` triggered bash brace-expansion of `{a,b}`, splitting
the JSON so `decide` returned empty and `laneidx ""`→9 ≥ base passed vacuously. Fixed by building the JSON in a variable
first (no brace expansion) and making `laneidx` return `-1` for unknown/empty so a broken result FAILS. AC10 now exercises
real monotonicity (0 invalid-JSON errors).
