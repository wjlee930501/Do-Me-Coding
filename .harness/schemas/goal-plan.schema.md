# goal-plan.schema.md

The deterministic run-plan emitted by the v0.4.1 Goal-to-Plan Compiler. Additive; advisory; mock-first.

```text
goal_plan:
  goal_id:                       # from the goal bundle (free-form -> redacted if token-shaped)
  objective:                     # free-form -> redacted if token-shaped
  intake:                        # from the v0.2.8 classifier (read-only)
    dimensions: [..]
    stop_and_ask: bool
    required_human_gates: [..]
  autonomy_level:                # capped by risk: high-risk -> advisory; ambiguous -> autonomous-dry-run;
                                 #   low-risk -> autonomous-local-commit (NEVER push/closure autonomously)
  approved_scope: [paths]        # declared file scope (empty => no autonomous edit permitted)
  human_gates: [..]              # always includes push + closure; + live-provider-call / credential-access if implicated
  acceptance_criteria: [..]      # verification harness must pass; named expectations
  stop_conditions: [..]          # the nine fail-closed keys (autonomy.schema.md)
  basis: "deterministic; mock-first; from goal + v0.2.8 policy ONLY (not env/secrets); preserves human gates"
```

Invariants: deterministic (same goal -> byte-identical plan), env-independent (no `.env`/credential read), and
**push + closure + live-call + credential-access are always human-gated regardless of autonomy level**.
