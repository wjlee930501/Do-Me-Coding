# VERIFICATION — v0.5.6 Review Packet Generator v2

Command: `bash .harness/evidence/dmc-v0.5.6-review-packet-v2.sh --self-test`
Result: **PASS=17 / FAIL=0**, exit 0. Real repo byte-unchanged (fixture work confined to `$TMPDIR`); offline/local/read-only.

## Design — value-blind by structure (primary C5 defense)
The packet NEVER emits raw caller-controlled basenames or commit subject text. Detection (protected-surface / forbidden /
auto-log / stats / range validation) runs on the RAW path internally, but every EMITTED path is structural —
`<known-dir-bucket-or-[path]>/[name].<known-ext>` — and every commit subject is reduced to `short-SHA + conventional
type-class` (e.g. `fix:` / `feat(dmc):`) or `[subject withheld]`. This is value-blind regardless of secret format; the
`UNSAFE` regex remains only as a defense-in-depth backstop (correctness does not depend on enumerating token prefixes).

## Assertion → requirement map
- AC1 commit subject value-blind (type-class only; subject text + token withheld); commit body (`%b`) never in packet
- AC2 structural paths (`docs/[name].md`); raw basename and file content both absent
- AC3 protected-surface scan (detection on raw; emission value-blind `…/providers/[name].py`)
- AC4 auto-log evidence `.md` flagged excluded (value-blind path)
- AC5 test summary extracted from the allowlisted `.harness/verification` report (anchored counts only)
- AC6 unapproved report path REFUSED (symlink / traversal / non-verification dir / secret-named)
- AC7 structural ban: no `%b` / `--patch` / `log -p` / `diff -p` / `cat-file` / `diff-tree` / `format-patch` /
  `show <blob>` / net / env-hash primitive in the operative source (negative control confirms the ban bites)
- AC8 deterministic + env-independent
- AC9 env-hash injection: hostile `DMC_HASH_CMD` never read/executed
- AC11 secret-shaped basename withheld (`docs/[name].md`); no raw token
- AC14 JWT-shaped basename withheld (structural emission)
- AC15 C5 value-blind: 11 novel/un-enumerated secret shapes (Slack/Stripe live & restricted keys, Stripe webhook & npm &
  SendGrid & Google tokens, 40-hex high-entropy, credential URLs, storage account keys) withheld in paths + subjects
- AC12 invalid base/head ⇒ REFUSED (fail-closed; no empty packet masking the range)
- AC13 / AC13b `--out` fail-closed (new temp file only; existing/symlink/in-tree/system/home/`/etc/passwd` refused)
- AC16 `--out` `.env`-class refusal is case-insensitive (`prod.ENV` / `.ENV.LOCAL` refused like lowercase)
- AC10 read-only: real repo byte-unchanged
