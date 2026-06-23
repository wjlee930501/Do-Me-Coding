# goal-ledger.schema.md

The goal-ledger contract (DMC v0.6.4). Additive; advisory; **input-only**; **fail-closed**; **append-only / immutable
history**. Answers **Q4 — "what goal authorized the work?"** so **every completion traces to an approved goal** and goals can't
drift, be rewritten, or have history deleted. `goal_id` is a **preexisting v0.4.1 goal-plan reference** (the ledger ENTRY is a
v0.6.4 record, not a contract `goal` register entry).

## Predicates
`token_ok` / `ref_ok` are the v0.6.3 decidable predicates (token: `^[A-Za-z0-9._-]+$`, ≤128, no whitespace).

## Goal ledger entry — keyed by `(goal_id, seq)` (immutable)
```text
{ "entry_kind":"goal_ledger", "producer_milestone_id":"v0.6.4",
  "goal_id":"<token_ok; a v0.4.1 goal-plan id>", "seq": <int ≥ 0>,
  "goal_state":"proposed|approved|in-progress|completed|blocked|abandoned",
  "scope":"<token_ok>", "constraints":"<token_ok>",
  "approval": <approval entry> | null,            # REQUIRED iff goal_state=approved (passes --validate-entry approval, subject-consistent)
  "evidence_links":[ "<ref_ok>", … ],
  "completion_state":"open|done",
  "work_id","plan_hash"(hex≥16),"repo_hash"(hex≥16),"verification_ref" }   # 4 contract binding fields
```

## Goal state machine
`proposed → approved | abandoned` · `approved → in-progress | abandoned` · `in-progress → completed | blocked | abandoned` ·
`blocked → in-progress | abandoned` · `completed` / `abandoned` = **terminal** (no outgoing). A `completed`/`in-progress`
latest state requires the goal's **full history** to contain an `approved` entry (history scan, not just the immediate edge).

## Sub-commands
- `--validate <entry|->` — one ledger entry (shape + state requirements + approval via contract when approved).
- `--transition <{from,to}>` — legal goal-state transition? (terminal re-entry illegal).
- `--append-check <{prev,next}>` — **append-only**: every `prev` `(goal_id,seq)` present in `next` **canonical-JSON-identical**
  (no rewrite/delete); duplicate `(goal_id,seq)` → REFUSE; only additions.
- `--trace <{ledger, completion:{goal_id,completion_state}}>` — **every completion traces to a goal**: rejects duplicate
  `(goal_id,seq)`; the completion `goal_id` must be in the ledger; its **full history** must contain an `approved` entry; its
  **latest** (highest `seq`) state must legally support completion; else REFUSE.
- `--authorize <{prev,next,completion}>` — **authoritative anti-bypass** = `append-check(prev,next)` AND `trace(next,completion)`.
  Prevents authorizing a completion against a rewritten/truncated ledger that bare `--trace` would accept (mirrors v0.6.3
  `--release`).

## Invariants
Deterministic; **env-independent** (no `.env`/credential/network); **input-only** (all sub-commands call **no git**);
**duplicate-JSON-key rejecting**; **value-blind reject-on-match** over every input (incl. ledger arrays); `--out` write-safe
(in-repo/traversal/symlink/protected → REFUSED, core + wrapper). Append identity = `json.dumps(sort_keys=True,
separators=(',',':'))` per `(goal_id,seq)`. Advisory / fail-closed; **no goal rewrite, no retroactive state change, no history
deletion, no completion without an approved goal**. Honest scope: human approval *authenticity* and evidence-link *existence*
are upstream (human Release Gate + v0.6.5 composer). The runtime enforcement floor stays the hooks.
