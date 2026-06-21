# DMC External Review Handoff Template (Codex / Kim)

A compact, copy-pasteable prompt for handing an autonomous-run's self-review to an **independent** external reviewer
(Codex / Kim). The reviewer is **read-only and advisory**: it returns ACCEPT / REVISE / BLOCKED + findings; its output is
**never auto-applied** (accepted findings become a new scope-guarded plan). The v0.4.6 validator can emit a populated
copy of this template from a self-review artifact (`--handoff`).

```text
DMC Independent Review — <review_id> (STATIC, read-only).

You are the independent release auditor. Read-only sandbox; do not edit, do not push, do not read .env*/credentials.

CONTEXT
- run / milestone: <review_id>
- risk level (self-assessed): <risk_level>
- files touched: <files_touched>
- tests run: <tests_run, command : result>
- evidence: <evidence_refs>
- self-review findings: <findings>
- open questions: <open_questions>

Adversarially verify (hardest invariants first):
1. scope: every changed line traces to the approved plan; no out-of-scope / protected-surface edit; no over-eager rewrite.
2. safety: no secret/.env/credential read; no live/network call; no force/history-rewrite; no branch deletion.
3. correctness: the tests genuinely falsify the claims (no vacuous/over-claimed PASS); evidence is redacted.
4. the open questions are resolved or explicitly deferred.

Output EXACTLY:
- Verdict: ACCEPT / REVISE / BLOCKED
- safe-to-stage: yes/no · safe-to-commit: yes/no · safe-to-push: yes/no   (push is ALWAYS a human gate)
- If REVISE/BLOCKED: numbered REQUIRED fixes with file:line.
- Confirm whether any protected surface is modified (expect: none).

NOTE — your output is advisory. DMC does NOT auto-apply it; accepted findings become a new scope-guarded plan.
```
