# VERIFICATION — v0.5.9 Dynamic Workflow Capstone Acceptance Suite

Command: `bash .harness/evidence/dmc-v0.5.9-dynamic-workflow-acceptance.sh --self-test`
Result: **PASS=14 / FAIL=0**, exit 0. Real repo byte-unchanged; offline/local/read-only; no env/credential; no
network/live; synthetic fixtures / `$TMPDIR` only.

## Assertion → requirement map
- AC0 REGRESSION: all six v0.5.3–v0.5.8 tools `--self-test` green (compose)
- S1 docs closure: docs-only/light + markdown verification + full E2E ⇒ DONE
- S2 additive advisory tool: additive-tooling + shell self-test verification
- S3 provider adapter: protected-surface/deep + provider verification; `provider_target=mock` REJECTED; `run_mode=mock` allowed offline
- S4 protected-surface change: protected-surface/deep + protected-path byte-unchanged
- S5 failed-verification recovery: resume STOP + state-machine BLOCKED on FAIL; PASS proceeds after fix
- S6 review-branch publication: COMMIT→PUSH allowed w/ explicit authorization; resume ⇒ needs_human_gate candidate
- S7 premature closure: COMMIT→CLOSURE BLOCKED; closure-before-publish INVALID; committed-not-published IN_PROGRESS
- AC8 E2E-DONE only when all conditions met (no false DONE)
- AC9 smallest sufficient (docs-only stays docs-only) + monotonic (risk fact escalates)
- AC10 negative fixtures fail CLOSED (unknown task_class / missing danger fact ⇒ max)
- AC11 structural audit: no net / env-read / env-hash / live in capstone source
- AC12 env-hash injection: hostile `DMC_HASH_CMD` never read/executed
- AC13 no protected-surface mutation; production repo byte-unchanged after full compose
