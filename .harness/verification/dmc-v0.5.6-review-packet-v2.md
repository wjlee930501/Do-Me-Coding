# VERIFICATION — v0.5.6 Review Packet Generator v2

Command: `bash .harness/evidence/dmc-v0.5.6-review-packet-v2.sh --self-test`
Result: **PASS=10 / FAIL=0**, exit 0. Real repo byte-unchanged (fixture work confined to `$TMPDIR`); offline/local/read-only.

## Assertion → requirement map
- AC1 malicious commit subject value-blind redacted; commit body (`%b`) never in packet
- AC2 names-only: paths present, file content absent
- AC3 protected-surface scan lists the provider adapter path
- AC4 auto-log evidence `.md` flagged excluded
- AC5 test summary extracted from the allowlisted `.harness/verification` report (anchored counts only)
- AC6 unapproved report path REFUSED (symlink / traversal / non-verification dir / secret-named)
- AC7 structural ban: no `%b` / `--patch` / `log -p` / `diff -p` / `cat-file` / `diff-tree` / `format-patch` /
  `show <blob>` / net / env-hash primitive in the operative source (negative control confirms the ban bites)
- AC8 deterministic + env-independent
- AC9 env-hash injection: hostile `DMC_HASH_CMD` never read/executed
- AC10 read-only: real repo byte-unchanged
