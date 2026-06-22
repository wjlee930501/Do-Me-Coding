# run-metrics.schema.md

The per-run efficiency record emitted by the v0.5.0 Run Metrics Ledger. Additive; advisory; local-only; **value-blind**.
It captures the cost / efficiency profile of one DMC run so runs can be measured and optimized. It records **no** provider
payloads, `.env` / credential contents, tokens, or absolute private paths: free-form fields are value-blind-redacted and
numeric fields are validated (a secret cannot hide in a numeric field).

```text
{
  "run_id":                  "<id>",            # free-form -> redacted if token/secret-shaped
  "goal_type":               "<type>",          # free-form -> redacted if token/secret-shaped
  "mode":                    "passive | advisory | autonomous-dry-run | autonomous-local-commit | human-gated-push",
  "effort":                  "light | standard | deep | adversarial",
  "context_files_count":     <int >= 0>,
  "estimated_input_tokens":  <int >= 0>,
  "estimated_output_tokens": <int >= 0>,
  "tool_calls":              <int >= 0>,
  "wall_clock_sec":          <number >= 0>,
  "files_touched":           <int >= 0>,        # a COUNT, never a path list (no absolute-path leak)
  "tests_selected":          <int >= 0>,
  "tests_run":               <int >= 0>,
  "tests_passed":            <int >= 0>,
  "tests_failed":            <int >= 0>,
  "review_findings_total":   <int >= 0>,
  "blockers":                <int >= 0>,
  "retry_count":             <int >= 0>,
  "human_gates":             <int >= 0>,        # count of human gates crossed (push / closure / live-call / ...)
  "outcome":                 "completed | blocked | abandoned | partial",
  "efficiency_notes":        "<free-form>"      # free-form -> redacted if token/secret-shaped
}
```

Validation is **fail-closed** — an invalid record is REFUSED (non-zero exit), never emitted:

- every field above is present;
- `mode` ∈ the five autonomy levels (`AUTONOMY.md`); `effort` ∈ {light, standard, deep, adversarial};
  `outcome` ∈ {completed, blocked, abandoned, partial};
- every numeric field is a number ≥ 0 (the count fields are integers) — **a secret-shaped string in a numeric field fails
  validation**, so a secret cannot be smuggled through a numeric field;
- consistency: `tests_passed + tests_failed ≤ tests_run ≤ tests_selected`.

Redaction: the free-form fields (`run_id`, `goal_type`, `efficiency_notes`) pass through the value-blind sanitizer — a
matched value becomes `[redacted:unsafe-metadata]` and is **never re-emitted**. Covered shapes include `sk-` / `AKIA` /
PEM keys / `gh[opsu]_` / `github_pat_` / `glpat-` / `npm_` / `AIza` / `dop_v1_` / `xox*` / JWT / `Bearer` / `ya29.` /
`AccountKey=` / OAuth `*_token` / bare `password=` / `api_key=` / `client_secret=` / `aws_secret_access_key=`. This is
**best-effort, not a completeness guarantee** (split or novel-prefix secrets can still evade — review before commit).
Newlines in free-form fields are collapsed to spaces so a note cannot forge fake ledger lines. The enum fields are validated against a fixed set, so a secret-shaped value there fails closed rather than
leaking. The emitted ledger artifact is therefore safe to review and commit. The tool reads **only** the metrics record it
is given (argv / file); it never reads the environment, `.env`, credentials, provider payloads, or the network.
