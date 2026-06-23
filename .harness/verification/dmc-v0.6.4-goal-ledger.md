# Verification Report — DMC v0.6.4 Goal Ledger

**Milestone:** v0.6.4 (Goal Ledger) of the v0.6.1–v0.6.5 control-plane layer. **Advisory, not enforcement.** Schema + one
inert, read-only, input-only validator + state-machine + append-only/trace/authorize gates; selects no model, opens no live
gate, calls no provider/model/API/network/`.env`, and all sub-commands call no git. Answers **Q4 — "what goal authorized the
work?"**

**Tool:** `.harness/evidence/dmc-v0.6.4-goal-ledger.sh` (wrapper) + `.harness/evidence/dmc-v0.6.4-goal-ledger.py` (core)
**Command:** `bash .harness/evidence/dmc-v0.6.4-goal-ledger.sh --self-test`
**Review cadence:** Codex MCP dropped (slow/flaky); DMC `critic` (plan) + DMC `verifier` (build).

## Result
```
self-test: 27 PASS / 0 FAIL
G10 repo byte-unchanged after self-test (sentinel equal before==after)
G7b authorize anti-bypass: a `next` ledger that rewrites/drops a prior (goal_id,seq) so bare --trace would ALLOW → --authorize REFUSE
--authorize --out in-tree → REFUSED (exit 2, 0 files); G11 regression: v0.6.1.0 26/0 + v0.6.1 7/0 + v0.6.2 18/0 + v0.6.3 25/0 green
```

## Assertion → requirement map
| ID | Asserts | Backs |
|----|---------|-------|
| G1 | 6-state ledger entries validate; an `approved` entry's embedded `approval` passes contract `--validate-entry approval` | Q4; contract fit (entry is producer=v0.6.4, `goal_id` a bare v0.4.1 ref) |
| G2 | unknown `goal_state` / non-int·negative `seq` / missing entry_kind·producer·binding → REJECT | well-formed entry |
| G3 | `approved` without a valid subject-consistent human-release-gate `approval` → REJECT (non-human / bad source / foreign / missing) | no forged approval |
| G4 | prose/whitespace `scope`/`constraints`/`goal_id`, non-`ref_ok` `evidence_links` → REJECT | decidable predicates |
| G5 | every legal transition → exit 0; illegal (incl. `proposed→completed`, `proposed→in-progress`, terminal re-entry `completed→*`/`abandoned→*`) → exit 1 | state machine |
| G6 | append-check: delete / rewrite / duplicate `(goal_id,seq)` → REFUSE; reorder-identical / pure-addition → ALLOW | **immutable history** |
| G7 | trace: goal not in ledger / never approved (full-history) / abandoned latest / duplicate `(goal_id,seq)` → REFUSE; in-progress + prior approved → ALLOW (lists authorizing goal = Q4 answer) | completion-traces-to-goal |
| G7b | **`--authorize` = append-check(prev→next) AND trace(next): refuses bypass-by-rewrite** (bare `--trace(next)` would ALLOW) | the authoritative anti-bypass decision |
| G8 | duplicate JSON key / secret-shaped / malformed-root·non-array → REJECT/REFUSE | fail-closed; value-blind |
| G9 | `env -i` + hostile credential var → identical verdict; all sub-commands call no git | env-free / input-only |
| G10 | repo byte-unchanged after `--self-test`; `--out` write-safe (core + wrapper) | read-only |
| G11 | v0.6.1.0 (26/0) + v0.6.1 (7/0) + v0.6.2 (18/0) + v0.6.3 (25/0) verifiers still green | regression budget |

## Honest scope
Input-only (no git): verifies entry *shape*, *state-machine legality*, *append-only immutability*, and *completion-traces-to-
an-approved-goal*. It does **not** verify a human approval's *authenticity* or that an `evidence_link` resolves — upstream
(human Release Gate + v0.6.5 composer).

## Safety posture
- Additive only (`.harness/schemas/goal-ledger.schema.md`, `.harness/evidence/dmc-v0.6.4-goal-ledger.{py,sh}`, this report).
  **No protected-surface change. No live/model/API call. No network. No `.env`/credential read.**
- Deterministic, env-free, input-only (no git), duplicate-key-rejecting, value-blind (reject-on-match incl. ledger arrays),
  no-heredoc/no-temp, fail-closed, inert unless invoked, write-safe `--out`. **No goal rewrite, no retroactive state change, no
  history deletion, no completion without an approved goal.**

**Gate status:** built + verified on `dmc-control-plane/v0.6.1`. Critic stage: DMC critic REVISE incorporated (Rev 2: coupled
`--authorize`, full-history approved scan, `goal_id`-is-a-reference fix, terminal-state tests). Build audit recorded
separately. **Not pushed; MILESTONES not updated; no closure.** Push / main-FF / closure remain human gates.
