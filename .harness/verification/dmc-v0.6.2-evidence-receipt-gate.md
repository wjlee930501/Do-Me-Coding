# Verification Report — DMC v0.6.2 Evidence Receipt Gate

**Milestone:** v0.6.2 (Evidence Receipt Gate) of the v0.6.1–v0.6.5 control-plane layer. **Advisory, not enforcement.**
Schema + one inert, read-only, input-only validator + completion-block gate; selects no model, opens no live gate, calls no
provider/model/API/network/`.env`, and `--validate`/`--gate` never call git. Answers **Q2 — "what evidence supports
completion?"** and enforces **"no evidence → no completion."**

**Tool:** `.harness/evidence/dmc-v0.6.2-evidence-receipt.sh` (wrapper) + `.harness/evidence/dmc-v0.6.2-evidence-receipt.py` (core)
**Command:** `bash .harness/evidence/dmc-v0.6.2-evidence-receipt.sh --self-test`

## Result
```
self-test: 18 PASS / 0 FAIL   (E1 5 types+contract · E2a–d artifact_ref · E3 checker · E4a/E4b no-evidence/prose ·
                               E5 required-type · E6×4 per-field subject mismatch · E7 ALLOW · E8a/b/c · Cneg)
E10 repo byte-unchanged after self-test (sentinel equal before==after)
gate ALLOW on a valid verification-report (verdict lists the Q2 evidence); gate REFUSE on prose-only / no-evidence
--gate --out in-tree → REFUSED (exit 2, 0 files); env -i + hostile credential var → identical verdict; --validate/--gate call no git
E11 regression: v0.6.1.0 (26/0) + v0.6.1 (7/0) verifiers still green
```

## Assertion → requirement map
| ID | Asserts | Backs |
|----|---------|-------|
| E1 | each of the 5 evidence types validates; base entry passes contract `--validate-entry evidence` | Q2; contract fit |
| E2a–d | `artifact_ref` decidable non-prose predicate (bare token / sentence / absolute·`..`·`~`·URL·backslash·metachar / missing·bad-type → REJECT) | "prose is not evidence" (B3) |
| E3 | `machine_verifiable:true` without `checker` → REJECT | machine-verifiable discipline |
| E4a/E4b | gate: empty evidence / prose-only → REFUSE | **no evidence → no completion** |
| E5 | gate: no `verification-report` → REFUSE | required type (No verification, no done) |
| E6×4 | gate: receipt mismatching the claim subject on `work_id`/`plan_hash`/`repo_hash`/`verification_ref` → REFUSE | 4-field subject consistency (B1); receipt-vs-claim reuse defense |
| E7 | gate: valid verification-report + all receipts subject-matching → ALLOW (verdict lists Q2 evidence) | the positive path |
| E8a/b/c | duplicate JSON key / secret-shaped / malformed-root·non-array·invalid-receipt → REJECT/REFUSE | fail-closed; value-blind |
| E9 | `env -i` + hostile credential var → identical verdict; `--validate`/`--gate` call no git | env-free / input-only |
| E10 | repo byte-unchanged after `--self-test`; `--out` write-safe (core + wrapper) | read-only |
| E11 | v0.6.1.0 (26/0) + v0.6.1 (7/0) verifiers still green | regression budget |

## R10 scope (honest)
The gate is **input-only (no git)** — it enforces *receipt-vs-claim* subject consistency (all four binding fields), defeating
cross-subject/stale-receipt reuse. It does **not** anchor the claim subject to the live tree; live-head/replay-vs-live
anchoring is upstream (goal/plan + human Release Gate + the v0.6.5 composer), consistent with the contract's
"staleness vs live tree out of scope" note.

## Safety posture
- Additive only (`.harness/schemas/evidence-receipt.schema.md`, `.harness/evidence/dmc-v0.6.2-evidence-receipt.{py,sh}`,
  this report). **No protected-surface change. No live/model/API call. No network. No `.env`/credential read.**
- Deterministic, env-free, input-only (`--validate`/`--gate` call no git), duplicate-key-rejecting, value-blind
  (reject-on-match), no-heredoc/no-temp, fail-closed, inert unless invoked, write-safe `--out` (core + wrapper).
  **Never trusts prose/summary/self-report.**

**Gate status:** built + verified on `dmc-control-plane/v0.6.1`. Critic stage: DMC critic + Codex REVISE incorporated (Rev 2:
4-field subject match, decidable `artifact_ref`, honest R10 scope, split negatives, `--out` defined). Build audit recorded
separately. **Not pushed; MILESTONES not updated; no closure.** Push / main-FF / closure remain human gates.
