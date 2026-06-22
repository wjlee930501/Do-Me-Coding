# VERIFICATION — v0.5.5 Verification Planner

Command: `bash .harness/evidence/dmc-v0.5.5-verification-planner.sh --self-test`
Result: **PASS=15 / FAIL=0**, exit 0. Real repo byte-unchanged; offline/local/read-only; no env/credential read; no
network/live call.

## Assertion → requirement map
- AC1 docs-only ⇒ markdown/style + status (no heavy self-test)
- AC2 shell tool ⇒ self-test + structural shell audit
- AC3 schema ⇒ schema validation + protected byte-unchanged
- AC4 provider/import ⇒ schema/result validator + leak scan + reject-path + byte-unchanged
- AC5 guard/hook/validator ⇒ reject-path + byte-unchanged
- AC6 protected_surface flag ⇒ protected byte-unchanged (near-scope)
- AC7 text-bearing artifact ⇒ leak scan required
- AC8 / AC8b malformed or uncategorizable path ⇒ FAIL-CLOSED maximal set (not silently skipped)
- AC9 forbidden_checks always present (no credential read / no live call / no payload print / no auto-apply)
- AC10 union/monotonic: adding a protected path never removes a required check
- AC11 deterministic + env-independent
- AC12 structural audit: no net / env-read / env-hash
- AC13 env-hash injection: hostile `DMC_HASH_CMD` never read/executed
- AC14 read-only: repo byte-unchanged
