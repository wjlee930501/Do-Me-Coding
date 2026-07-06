# dmc.blocked-marker.v1 — BLOCKED sidecar marker (P8/M6 (vi))

A run-scoped **sidecar** that holds a completion claim until a scope/verification problem is
resolved. Written, read, and cleared ONLY through the `dmc run block | blocked-status | unblock`
verbs (M6 `dmc-run-lifecycle.py`). It is **not a run state**: the M4 state machine (`STATES` tuple)
and `run.json` schema (`dmc.run-state.v1`) are UNTOUCHED — BLOCKED lives beside the run record, never
inside it (critic B5). The post-Bash diff guard (`dmc-postbash-diff.py`) requests a block on an
out-of-scope change; the stop gate (`dmc-stop-gate.py`) refuses completion while the marker is
present. The marker is **sticky**: it clears only via an explicit `dmc run unblock`, never
auto-clears.

Location (per run): `.harness/runs/<run-id>/blocked.json` (the live marker) and
`.harness/runs/<run-id>/blocked-resolved.jsonl` (the append-only resolution ledger).

```json
{
  "schema": "dmc.blocked-marker.v1",
  "run_id": "<run id>",
  "reason": "<non-empty human/guard reason>",
  "paths": ["<offending relpath>"],
  "created_by_check": "<check_id | tool id | 'manual'>",
  "created_at": "<UTC ISO-8601>"
}
```

Resolution ledger entry (`blocked-resolved.jsonl`, one compact JSON object per line, append-only):

```json
{"run_id": "<run id>", "resolution": "<how it was resolved>", "resolved_at": "<UTC ISO-8601>", "marker": { ...the resolved blocked.json body... }}
```

Rules (verb-enforced, fail-closed):
- `run block` REFUSES an empty `--reason` (no vague block) and REFUSES a second block while one is
  outstanding (the marker is sticky — resolve it first).
- `blocked-status` exits 0 when clear, 4 when a marker is present (mirrors the stop-gate hold code).
- `run unblock` REFUSES an empty `--resolution` and REFUSES when there is no marker to resolve; on
  success it appends the marker body to `blocked-resolved.jsonl` and removes `blocked.json` — the
  only sanctioned way to clear a block.
- A `blocked.json` that appears as a NEW worktree change (i.e. written out-of-band by Bash rather
  than the `dmc` CLI) is itself DENY-on-change under the post-Bash guard — state mutates only via
  the CLI.
- Value-blind: `paths` are paths only; the marker never inlines file contents or secrets.

Consumers: `dmc-postbash-diff.py` (creates via `run block`), `dmc-stop-gate.py` (holds while
present), `dmc-run-lifecycle.py` (the single writer/reader/clearer). Sidecar-only; the run state
machine never observes it.
