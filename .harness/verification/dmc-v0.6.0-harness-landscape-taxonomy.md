# Verification Report — DMC v0.6.0 Harness Landscape & Orchestration Taxonomy

**Milestone:** v0.6.0 (research / architecture). **This milestone is architecture guidance, not enforcement.**
The deliverables are documents plus one read-only structure-check script; they select no model, open no gate, install no
hook, make no live/network call, and authorize no build. The verifier asserts *structure*, not behavior.

**Verifier:** `.harness/evidence/dmc-v0.6.0-verify.sh`
**Command:** `bash .harness/evidence/dmc-v0.6.0-verify.sh --self-test`
**Mode:** read-only, structure-check only, env-independent, inert unless flag-invoked.

## Result

```
RESULT: 18 PASS / 0 FAIL   (V1–V18, plus checker self-tests ST1–ST3)
repo_hash(before) == repo_hash(after)   → working-tree status + deliverable bytes unchanged (V18; content-sensitive repo_hash)
```

(Counts above are the confirmed result of the `--self-test` run recorded in this milestone's evidence summary.)

## Assertion → requirement map

| ID | Asserts | Backs requirement |
|----|---------|-------------------|
| V1 | landscape + taxonomy + adoption docs exist | deliverables 1, 2, 3 |
| V2 | benchmark cards doc exists | deliverable 4 |
| V3 | source table present (header + ≥1 row) in landscape | plan §4 row1; "source table" |
| V4 | adoption table has pattern/evidence/decision/rationale/risk columns | plan §4.3 Output 4 |
| V5 | model-role taxonomy names all six roles | plan §4.3 Output 1; "role taxonomy complete" |
| V6 | delegation matrix: 7 task classes × 5 columns | plan §4.3 Output 3; "delegation matrix complete" |
| V7 | ≥23 benchmark cards | plan §4.1; "benchmark card count ≥23" |
| V8 | every card carries one valid adopt/adapt/reject/defer decision | plan §4.2; "explicit decisions" |
| V9 | every card has `What DMC already has` + `Gap in DMC` | plan §4.2; "required card fields" |
| V10 | every card carries the no-leaked-prompt attestation | plan §4.2; "required card fields" |
| V11 | DMC vocabulary markers present (lane/gate/evidence/advisory/human-gate) | plan §6 V11; "own-words" |
| V12 | no secret-shaped strings in any deliverable | plan §5; "no secret-shaped strings" |
| V13 | no leaked/transcript markers; no over-long quote block | plan §6 V13; "no leaked/proprietary text" |
| V14 | verify script operative source: no .env read / live / model / network | plan §6 V14; verifier safety |
| V15 | no protected-surface change; tracked changes in-scope | plan §5; "protected surfaces unchanged" |
| V16 | no auto-log `.harness/evidence/*.md` staged | plan §6 V16; evidence-exclusion |
| V17 | this report carries "architecture guidance, not enforcement" | plan §6 V17; disclaimer |
| V18 | working-tree status + deliverable bytes unchanged after `--self-test` (content-sensitive, env-free `repo_hash`) | plan §6 V18; read-only proof |

**Checker self-tests (negative controls):** ST1 card-counter counts headers · ST2 decision-validator rejects a non-enum value · ST3 secret-regex catches a synthetic placeholder. These prove the checker can *fail*, so a PASS is meaningful.

## Mandatory-requirement coverage (from the build brief)

- Research categories A–I covered — landscape doc sections A–I. ✓
- Benchmark card count ≥23 — 23 cards (V7). ✓
- Every card contains all required fields — schema §4.2 fields per card (V8–V10). ✓
- Adoption decision table complete — Output 4 (V4). ✓
- Model role taxonomy complete — Output 1, six roles (V5). ✓
- Capability taxonomy complete — Output 2, six classes + replaceable dated model lookup. ✓
- Delegation matrix complete — Output 3, 7×5 (V6). ✓
- Anti-goals complete — Output 5, ten anti-goals. ✓
- Fugu cards tagged per evidence status — cards 19–23 mark all numbers self-reported/unverified. ✓
- Learned-Orchestrator-vs-Deterministic-Control-Plane discussion present — landscape doc dedicated section. ✓
- No README dumps / no copied prompt bodies / no leaked or proprietary text — own-words; V12/V13 backstops. ✓

## Residual risks / honest limits

- The verifier checks **structure, not semantics**: it confirms fields/markers/tables exist and that no secret-shaped or
  transcript-marker string appears, but it cannot *prove* prose is genuinely own-words or that a description is factually
  correct. Leak-avoidance is enforced primarily at authoring time; V10/V11/V13 are structural backstops, not a guarantee.
- All Sakana Fugu performance numbers are **self-reported / independently-unverified** (~1 day old at authoring); the docs
  tag them accordingly and never rely on them to justify a decision.
- These deliverables are **architecture guidance, not enforcement** — they name v0.6.1–v0.6.9 candidates; each candidate
  still requires its own approved plan and human gate before any build.

**Gate status:** built under the approved (APPROVED) plan scope; **not staged, not committed, not pushed; MILESTONES not
updated; no closure recorded.** Those actions require a separate human gate after review.
