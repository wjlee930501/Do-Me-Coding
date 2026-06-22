# VERIFICATION — v0.5.7 Resume / Recovery Controller

Command: `bash .harness/evidence/dmc-v0.5.7-resume-recovery.sh --self-test`
Result: **PASS=13 / FAIL=0**, exit 0. Real repo byte-unchanged; offline/local/read-only; no env/credential; no network/live.

## Assertion → requirement map
- AC1 clean+committed+ahead+verified+approved ⇒ NEEDS_HUMAN_GATE review-push candidate bound to commit (never "safe to push")
- AC2 dirty tracked worktree ⇒ STOP
- AC3 staged auto-log OR staged protected ⇒ STOP (do not commit)
- AC4 dirty only excluded auto-logs ⇒ classified safe (proceeds to gate candidate)
- AC5 behind origin (or unparseable behind) ⇒ STOP (do not push)
- AC6 missing OR stale approval ⇒ PLAN_OR_CRITIC (never infer approval from stale run state)
- AC7 verification FAIL ⇒ STOP
- AC8 approved but unverified ⇒ VERIFY
- AC9 never emits a "safe to push/commit" authorization across the whole decision space
- AC10 deterministic + env-independent
- AC11 structural audit: no net / env-read / env-hash
- AC12 env-hash injection: hostile `DMC_HASH_CMD` never read/executed
- AC13 read-only: repo byte-unchanged
