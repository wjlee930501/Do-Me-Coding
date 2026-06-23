# Verification Report — DMC v0.6.3 Findings Gate

**Milestone:** v0.6.3 (Findings Gate) of the v0.6.1–v0.6.5 control-plane layer. **Advisory, not enforcement.** Schema + one
inert, read-only, input-only validator + closure/append-only/release gates; selects no model, opens no live gate, calls no
provider/model/API/network/`.env`, and all sub-commands call no git. Answers **Q3 — "what findings remain?"** and ensures **no
unresolved finding crosses a release gate invisibly.**

**Tool:** `.harness/evidence/dmc-v0.6.3-findings-gate.sh` (wrapper) + `.harness/evidence/dmc-v0.6.3-findings-gate.py` (core)
**Command:** `bash .harness/evidence/dmc-v0.6.3-findings-gate.sh --self-test`

## Result
```
self-test: 25 PASS / 0 FAIL
F12 repo byte-unchanged after self-test (sentinel equal before==after)
F9 release anti-bypass: dropping a prior blocked finding then gating `next` → REFUSE (append-check coupled to closure)
--release --out in-tree → REFUSED (exit 2, 0 files); F13 regression: v0.6.1.0 26/0 + v0.6.1 7/0 + v0.6.2 18/0 green
```

## Assertion → requirement map
| ID | Asserts | Backs |
|----|---------|-------|
| F1 / F1neg | 4 states validate + base entry passes contract `--validate-entry finding`; contract rejects producer≠v0.6.3 | Q3; contract fit |
| F2 | unknown/missing `state` → REJECT | no stateless finding |
| F3a–e | resolved⇒`evidence_ref`; accepted-risk⇒`waiver.approval` passes `--validate-entry approval` + subject-consistent (non-human type / bad source / foreign-subject / missing waiver → REJECT); deferred⇒owner+target+release_policy | pass/fail matrix; **no hidden waiver** |
| F4 | missing/prose/`/`-path/whitespace `summary_class` → REJECT (`token_ok`) | the "what" is always present + decidable |
| F5 | gate: `blocked` or unknown finding → REFUSE | blocked never crosses |
| F6 | gate: finding's 4 binding fields ≠ subject → REFUSE | subject consistency |
| F7 | gate: all-PASS → ALLOW (lists remaining = Q3 answer); empty findings → ALLOW | positive + valid-empty |
| F8a–d | append-check: drop → REFUSE; state/content rewrite → REFUSE; reorder/identical → ALLOW; duplicate id → REFUSE; pure additions → ALLOW | **no drop / no silent rewrite** (canonical-JSON per id) |
| F9 | **`--release` = append-check(prev→next) AND gate(next): refuses bypass-by-drop** (gate(next) alone would ALLOW) | the authoritative anti-invisible-finding decision |
| F10 | duplicate JSON key / secret-shaped / malformed-root·non-array → REJECT/REFUSE | fail-closed; value-blind |
| F11 | `env -i` + hostile credential var → identical verdict; all sub-commands call no git | env-free / input-only |
| F12 | repo byte-unchanged after `--self-test`; `--out` write-safe (core + wrapper) | read-only |
| F13 | v0.6.1.0 (26/0) + v0.6.1 (7/0) + v0.6.2 (18/0) verifiers still green | regression budget |

## Honest scope
The gate is **input-only (no git)**: it verifies finding *shape*, *state requirements*, *subject-consistency*, and
*append-only* (no drop/rewrite). It does **not** verify a human waiver's *authenticity* or that an `evidence_ref` links a real
receipt — those are upstream (human Release Gate + v0.6.5 composer), consistent with the contract's "out of scope" note.

## Safety posture
- Additive only (`.harness/schemas/findings-register.schema.md`, `.harness/evidence/dmc-v0.6.3-findings-gate.{py,sh}`, this
  report). **No protected-surface change. No live/model/API call. No network. No `.env`/credential read.**
- Deterministic, env-free, input-only (all sub-commands call no git), duplicate-key-rejecting, value-blind (reject-on-match
  over every input incl. `prev`/`next`), no-heredoc/no-temp, fail-closed, inert unless invoked, write-safe `--out`.
  **No silent/dropped finding, no hidden waiver, no unknown state, no state rewrite.**

**Gate status:** built + verified on `dmc-control-plane/v0.6.1`. Critic stage: DMC critic + Codex REVISE incorporated (Rev 2:
`--release` coupling, contract-verified waiver, enforced `summary_class`, canonical-JSON append identity, `token_ok` predicate).
Build audit recorded separately. **Not pushed; MILESTONES not updated; no closure.** Push / main-FF / closure remain human gates.
