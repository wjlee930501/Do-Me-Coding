# autonomy.schema.md

Machine-readable mirror of `AUTONOMY.md` (v0.4.0) for tooling. Tools consume the level + stop-condition **keys** below;
the normative prose is in `AUTONOMY.md`. Additive; changes no behavior.

## Autonomy levels (ordered least → most autonomous)

```text
levels:
  - key: passive               # observe + read-only advisory rails only
  - key: advisory              # + plans/critiques/proposals; no file/source edit
  - key: autonomous-dry-run    # + full loop on fixtures/$TMPDIR only; real repo byte-unchanged   [DEFAULT unattended]
  - key: autonomous-local-commit  # + approved-scope edits on an isolated branch; local commit after tests pass; NO push
  - key: human-gated-push      # the gate: push/live/secret/protected-beyond-scope/closure require an explicit human gate
default_unattended: autonomous-dry-run
never_autonomous: [push, closure, live-provider-call, credential-access, force/history-rewrite, branch-deletion]
```

## Stop conditions (fail-closed keys; v0.4.2–v0.4.5 enforce mechanically)

```text
stop_conditions:
  - dirty-worktree
  - branch-is-main-outside-closure
  - scope-violation
  - protected-surface-diff
  - secret-or-credential-exposure
  - live-call-or-network
  - verification-fail
  - ambiguity
  - over-eager-bound-exceeded
fail_closed: true   # when uncertain, stop
```

## Always-blocked (every level)

```text
always_blocked:
  - secret-bearing-file-content-access
  - live/network/model-API call
  - force-push / history-rewrite / branch-deletion
  - published-milestone-entry-mutation (append-only closure only)
  - prior-review-branch-mutation
  - copied-leaked-prompt-text   # DMC.md Rule 7
```
