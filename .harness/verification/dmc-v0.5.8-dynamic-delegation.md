# VERIFICATION — v0.5.8 Dynamic Delegation Harness

Command: `bash .harness/evidence/dmc-v0.5.8-dynamic-delegation.sh --self-test`
Result: **PASS=12 / FAIL=0**, exit 0. Real repo byte-unchanged; offline/local/read-only; no env/credential; no network/live.

## Assertion → requirement map
- AC1 handoff includes all four roles (Orchestrator/Implementer/Critic/Release Gate)
- AC2 push/main/closure are HUMAN GATE (never autonomous, even with batch ACTIVE)
- AC3 critic/Codex ACCEPT is advisory, never a push grant
- AC4 forbidden list: self-approval / ungated push-main / closure-before-publish / secret-env read / token-max
- AC5 / AC5b bounded-batch autonomy encoded; local stage/commit gated on batch ACTIVE + green tests; batch=OFF reflected
- AC6 compact handoff prompt present
- AC7 no secret-shaped text / no leaked-prompt markers in the handoff
- AC8 deterministic + env-independent
- AC9 structural audit: no net / env-read / env-hash
- AC10 env-hash injection: hostile `DMC_HASH_CMD` never read/executed
- AC11 read-only: repo byte-unchanged
