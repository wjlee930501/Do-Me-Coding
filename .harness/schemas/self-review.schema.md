# self-review.schema.md

The self-review artifact an autonomous run produces before the human/external-review gate (v0.4.6). JSON.

```text
{
  "review_id":      "<run/milestone id>",
  "risk_level":     "low | medium | high",
  "files_touched":  ["path", ...],
  "tests_run":      [ {"command": "...", "result": "..."}, ... ],
  "evidence_refs":  [".harness/evidence/...", ".harness/verification/...", ...],
  "findings":       [ {"severity": "info|low|medium|high", "title": "...", "detail": "..."}, ... ],
  "open_questions": ["...", ...],
  "auto_apply":     false      # MUST be false — reviewer output is advisory; it is NEVER auto-applied
}
```

Rules: `risk_level` ∈ {low,medium,high}; `auto_apply` MUST be `false` (a validator BLOCKS `true`); `files_touched`,
`tests_run`, `evidence_refs`, `findings`, `open_questions` are lists. The reviewer (self or external Codex/Kim) produces
findings only — the orchestrator translates accepted findings into scope-guarded edits under a new approved plan; it does
not apply reviewer output directly.
