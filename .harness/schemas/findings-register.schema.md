# findings-register.schema.md

The findings register + release-gate contract (DMC v0.6.3). Additive; advisory; **input-only**; **fail-closed**. Answers
**Q3 — "what findings remain?"** and ensures **no unresolved finding crosses a release gate invisibly.** A finding is a
trace-linkage `finding` fragment (`--validate-entry finding`) + v0.6.3-owned fields.

## Predicates (decidable; pinned)
- **`token_ok(s)`** := single-line, non-empty, `^[A-Za-z0-9._-]+$`, length ≤ 128. A category/owner/target token. (Sibling of,
  not equal to, v0.6.2's `artifact_ref_ok`, which requires `/` or hex.)
- **`ref_ok(s)`** := `token_ok(s)` (an `evidence_receipt_id`) OR a v0.6.2-style safe path / hex hash. **Shape-only** — that it
  links a *real* receipt is the v0.6.5 composer's job.

## Finding
```text
{ "kind":"finding", "id":"<opaque>", "producer_milestone_id":"v0.6.3",
  "state":"resolved|accepted-risk|deferred|blocked",
  "work_id","plan_hash"(hex≥16),"repo_hash"(hex≥16),"verification_ref",   # 4 contract binding fields
  "summary_class":"<token_ok>",                                           # REQUIRED, all states (the "what")
  "evidence_ref":"<ref_ok>",                                              # REQUIRED iff resolved
  "waiver": { "approval": <approval entry> },                             # REQUIRED iff accepted-risk
  "owner":"<token_ok>","target":"<token_ok>","release_policy":"<token_ok>" }   # REQUIRED iff deferred
```
The base entry passes `--validate-entry finding`; the rest are v0.6.3-owned.

## Pass/fail matrix (release) — enforced at `--validate` AND `--gate`
| state | release | requires (besides `summary_class`, always) |
|-------|---------|--------------------------------------------|
| `resolved` | PASS | `evidence_ref` (`ref_ok`) |
| `accepted-risk` | PASS | `waiver.approval` passes `--validate-entry approval` AND is subject-consistent (4 binding == finding) — *human authenticity is upstream* |
| `deferred` | PASS | `owner` + `target` + `release_policy` (all `token_ok`) |
| `blocked` | **FAIL** | never crosses a release gate |
| unknown/missing | **FAIL** | fail-closed |

## Sub-commands
- `--validate <finding|->` — one finding (well-formedness + state requirement).
- `--gate <{subject, findings:[…]}>` — snapshot closure: ALLOW iff every finding is subject-consistent (4 binding == subject's
  corresponding 4 of 5) and release-PASS; empty findings → ALLOW (no findings is a valid Q3 answer); a stateless finding → REFUSE.
- `--append-check <{prev, next}>` — ALLOW iff every `prev` id is in `next` with **canonical-JSON-identical** content (no drop,
  no state/content rewrite), only additions; **duplicate finding ids → REFUSE**.
- `--release <{subject, prev, next}>` — **the authoritative release decision** = `append-check(prev,next)` AND
  `gate({subject, findings:next})`. Prevents bypass-by-drop (dropping a prior `blocked` finding then gating only `next`).

## Invariants
Deterministic; **env-independent** (no `.env`/credential/network); **input-only** (all sub-commands call **no git**);
**duplicate-JSON-key rejecting**; **value-blind reject-on-match** over every input (incl. `prev`/`next`); `--out` write-safe
(in-repo/traversal/symlink/protected → REFUSED, core + wrapper). Append identity = `json.dumps(sort_keys=True,
separators=(',',':'))` per `id`. Advisory / fail-closed; **no silent/dropped finding, no hidden/unshaped waiver, no unknown
state, no state rewrite**; the runtime enforcement floor stays the hooks.
