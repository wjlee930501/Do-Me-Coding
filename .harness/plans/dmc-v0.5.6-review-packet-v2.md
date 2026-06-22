# PLAN — v0.5.6 Review Packet Generator v2 (APPROVED)

Parent: batch plan (APPROVED). Additive; **new v2 generator** — the shipped v0.3.6 packet tool is NOT modified.

## Goal
Names-only, secret-safe review packet from git metadata only; no commit-body `%b`; allowlisted verification-report reads;
value-blind redacted subjects; identify base/head, file list, stat, protected-surface touches, forbidden paths, test
summaries — without printing raw provider/user artifacts.

## Accepted file scope (additive)
`docs/REVIEW_PACKET_V2.md` · `.harness/evidence/dmc-v0.5.6-review-packet-v2.sh` · this plan ·
`.harness/verification/dmc-v0.5.6-review-packet-v2.md`

## Acceptance criteria
malicious commit subject/body cannot leak; free-form metadata redacted; unapproved report path refused; auto-log evidence
excluded; protected-surface scan works structurally; output deterministic; content-extraction primitives structurally
banned (with a negative control). Self-test green; real repo byte-unchanged.

## Stop conditions
Any commit-body/content leak, report-path allowlist bypass, secret-shaped metadata leak, protected-surface mutation.
