# VERIFICATION — v0.5.4 Workflow State Machine

Command: `bash .harness/evidence/dmc-v0.5.4-workflow-state-machine.sh --self-test`
Result: **PASS=18 / FAIL=0**, exit 0. Real repo byte-unchanged; offline/local/read-only; no env/`.env`/credential; no
network/live call.

## Assertion → requirement map
| AC | Proves |
|---|---|
| AC1 | valid milestone path DRAFT..CLOSURE all ALLOWED |
| AC2 | DRAFT→START_WORK (no approval) ⇒ BLOCKED (no implement-without-approval) |
| AC3 / AC3b | stale approval (plan_hash mismatch) and a missing binding ⇒ BLOCKED (fail-closed) |
| AC4 | COMMIT→CLOSURE (skip PUSH) ⇒ BLOCKED |
| AC5 / AC5b | `critic PASS` does NOT authorize PUSH; PUSH gated on explicit `push_authorized` |
| AC6 | STAGE→COMMIT BLOCKED when protected/auto-log staged |
| AC7 | VERIFY→RELEASE_AUDIT BLOCKED on verification FAIL or stale head |
| AC8 | premature DONE rejected ⇒ IN_PROGRESS |
| AC9 | published-to-main but closure missing ⇒ IN_PROGRESS |
| AC10 | closure recorded but main not published ⇒ INVALID |
| AC11 / AC11b | full E2E ⇒ DONE; review-only (requires_main/closure=false) ⇒ DONE at commit (no false DONE) |
| AC12 | deterministic + env-independent (`env -i` + credential differential byte-identical) |
| AC13 | structural audit: no net / env-read / env-hash in operative source |
| AC14 | env-hash injection: hostile `DMC_HASH_CMD` never read/executed |
| AC15 | read-only: real repo byte-unchanged (deterministic sha256) |
