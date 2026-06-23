# Verification Report — DMC v0.6.1.0 Trace Linkage Contract

**Milestone:** v0.6.1.0 (foundational schema + validator of the v0.6.1–v0.6.5 control-plane layer).
**This milestone is advisory, not enforcement.** It ships a schema + one inert, read-only, **input-only** validator; it
selects no model, opens no gate, calls no provider/model/API, makes no network call, reads no `.env`/credential, and `--validate`
never calls git. The runtime enforcement floor stays the hooks.

**Validator:** `.harness/evidence/dmc-v0.6.1.0-trace-linkage.sh` (thin wrapper) + `.harness/evidence/dmc-v0.6.1.0-trace-linkage.py` (core; no-heredoc, no-temp, in-memory self-test)
**Command:** `bash .harness/evidence/dmc-v0.6.1.0-trace-linkage.sh --self-test`

## Result
```
self-test: 26 PASS / 0 FAIL   (record-level: 1 positive + 18 negative controls incl. completeness; entry-level: 7 fragment controls)
modes: --validate (complete record) · --validate-entry <register-key> (single producer fragment; path "-" = stdin, no temp)
T13 repo byte-unchanged after self-test (sentinel hash equal before==after)
T12 determinism/env-free: env -i + hostile credential var → identical verdict on the same record
--validate makes no git call (git only in the --self-test sentinel + root-detect)
```

## Assertion → requirement map
| ID | Asserts | Backs |
|----|---------|-------|
| T1 | a well-formed, fully subject-bound record → VALID | roadmap §1.1 |
| T2 / T2b | missing subject field / non-hash `plan_hash`·`repo_hash` → REJECT | R1; DMC-critic B2 |
| T3 / T3b / T4 | a register entry whose `work_id`/`plan_hash`/`repo_hash`/`verification_ref` ≠ subject → REJECT | **R9/R10 (false-trace prevention)** |
| T5 | duplicate `(kind,id)` across all registers → REJECT | R11 |
| T6 / T6b | dangling / type-confused edge endpoint → REJECT | R9 |
| T7 / T7b / T7c | approval `type`≠human-release-gate / foreign-subject / `source`∉`human-release-gate:` → REJECT | **R12 (approval-ref laundering)** |
| T8 | `producer_milestone_id` ≠ the pinned kind→producer table → REJECT | Codex finding 2 |
| T9 | `capability_class`∉ six / `finding.state`∉ four → REJECT | taxonomy Output 2 |
| T10 | secret-shaped string anywhere (recursive) → REJECT | R6 (value-blind, reject-on-match) |
| T11 | duplicate JSON key at any object level → REJECT | Codex finding 6 (fail-closed determinism) |
| T12 | `env -i` + hostile credential var → identical verdict; `--validate` calls no git | env-free / input-only |
| T13 | repo byte-unchanged after `--self-test` | read-only |
| T14 | schema doc names the 5 binding fields, 6 classes, 4 states, the re-bind rule, the producer table, the approval prefix | doc↔validator drift |
| T15 | empty/approval-less record (missing register key or empty answer-bearing register) → REJECT | completeness: a VALID record answers Q1/Q2/Q4/Q5/Q6 |
| Tneg | a crafted-bad record per reject rule FAILs and the positive PASSes (the 15 negative controls above) | no false-green |

## Review posture
Plan Critic stage: **DMC `critic` = APPROVE** + **external Codex = ACCEPT** (after REVISE→Rev 2→Rev 2.1, closing the
convergent false-trace-binding + approval-source-laundering findings). Build audit recorded separately.

## Safety posture
- Additive only (`.harness/schemas/trace-linkage.schema.md`, `.harness/evidence/dmc-v0.6.1.0-trace-linkage.sh`, this report).
  **No protected-surface change. No live/model/API call. No network. No `.env`/credential read.**
- Validator is **fail-closed, value-blind (reject-on-match, no sanitized output), input-only**, inert unless
  `--validate`/`--self-test` invoked. Current-head staleness is explicitly out of scope (deferred to producers v0.6.2+).

**Gate status:** built + verified on `dmc-control-plane/v0.6.1`. **Not staged, not committed, not pushed; MILESTONES not
updated; no closure.** Build audit (multi-lens + Codex) precedes any commit; push/main/closure remain human-gated.
