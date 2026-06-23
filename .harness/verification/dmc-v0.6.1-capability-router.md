# Verification Report — DMC v0.6.1 Capability-Class Router

**Milestone:** v0.6.1 (Capability-Class Router) of the v0.6.1–v0.6.5 control-plane layer. **Advisory, not enforcement.**
Schema + one inert, read-only, input-only router/validator; selects no model, opens no gate, calls no provider/model/API,
makes no network/`.env` call, and `--route` never calls git. Answers **Q1 — "what capability performed this work?"**

**Router:** `.harness/evidence/dmc-v0.6.1-capability-router.sh` (wrapper) + `.harness/evidence/dmc-v0.6.1-capability-router.py` (core)
**Command:** `bash .harness/evidence/dmc-v0.6.1-capability-router.sh --self-test`

## Result
```
self-test: 7 PASS / 0 FAIL   (C1 grid · C2/C2b rejects · C3/C4 no-model-name · C5 explanation · C6 fragment + C6neg)
C8 repo byte-unchanged after self-test (sentinel equal before==after)
determinism/env-free: env -i + hostile credential var → identical resolution; --route calls no git
C9 regression: dmc-v0.6.1.0-trace-linkage.sh --self-test → 26/0 (prior-milestone verifier still green)
```

## Assertion → requirement map
| ID | Asserts | Backs |
|----|---------|-------|
| C1 | the 7×5 `(task_class, role)` grid resolves to a valid class, deterministically | routing table (Output 1/2/3) |
| C2 | unknown/missing `task_class`·`role`, malformed/secret subject → REJECT | fail-closed; value-blind |
| C2b | duplicate JSON key → REJECT | no last-key-wins downgrade (Codex finding 3) |
| C3 / C4 | **no model-name token in the routing logic** → model-swap invariance (success condition) | anti-goal #8; R4 |
| C5 | resolution emits a human-readable explanation naming the rule | explainability; no silent switch |
| C6 | emitted `capability_class` fragment passes the v0.6.1.0 contract `--validate-entry capability` | Q1 traceable receipt (carry-forward #1) |
| C6neg | a tampered fragment (wrong producer) → contract REJECT | no false-green |
| C7 | `env -i` + hostile credential var → identical resolution; `--route` calls no git | env-free / input-only |
| C8 | repo byte-unchanged after `--self-test` | read-only |
| C9 | prior-milestone verifier (v0.6.1.0) still 26/0 | regression budget (carry-forward #3) |

## Success condition
"Any model can be swapped without changing orchestration logic" — proven by C3/C4: the routing function resolves
`(task_class, role) → capability_class` and **consults no class→model table** (which lives, dated and illustrative, in the
schema doc only). Swapping that lookup changes nothing in routing.

## Safety posture
- Additive only (`.harness/schemas/capability-routing.schema.md`, `.harness/evidence/dmc-v0.6.1-capability-router.{py,sh}`,
  this report). **No protected-surface change. No live/model/API call. No network. No `.env`/credential read.**
- Deterministic, env-free, input-only (`--route` never calls git), duplicate-key-rejecting, value-blind (reject-on-match),
  no-heredoc/no-temp, fail-closed, inert unless `--route`/`--self-test`. **No learned routing, no dynamic scoring, no silent
  fallback, no model name in routing logic.**

**Gate status:** built + verified on `dmc-control-plane/v0.6.1`. Critic stage: DMC critic APPROVE + Codex REVISE incorporated
(Rev 2). Build audit: **DMC verifier ACCEPT** + **Codex 2 findings fixed & re-verified** — (1) `--route --out` is git-free
(redundant `git ls-files` dropped; git-trap confirms 0 calls); (2) C1 pins the **exact 35-cell** table (a bugged `resolve`
now fails C1); plus a core-side `--out` guard (in-repo/traversal/symlink → REFUSED). **Not pushed; MILESTONES not updated; no
closure.** Push / main-FF / closure remain human gates.
