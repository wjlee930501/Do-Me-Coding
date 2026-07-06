# DYNAMIC_DELEGATION.md — DMC Dynamic Delegation Harness (v0.5.8)

A delegation **handoff** that tells Opus/Opus exactly what each role may do under semi-autonomous work. Advisory; inert
unless invoked; reads no env/secret; no network/live call. The content is original DMC role text — no leaked/proprietary
prompt text.

> **Canonical role taxonomy: `orchestration/roles.json`** (the P14 `dmc.roles.v1` registry) is the
> single machine-readable home for the DMC orchestration roles and capability classes. The role list
> below is **derived / legacy reference**; if it disagrees with the registry, the registry wins.
> Validate it with `bin/dmc roles validate`. This banner is additive.

## Roles (owns / must-not / outputs)

_Derived / legacy view — canonical source: `orchestration/roles.json` (`dmc.roles.v1`)._

- **Orchestrator** — owns sequencing/scope-control; must NOT self-approve or push/merge/close without a gate, or expand
  tooling to spend context; outputs the per-step decision + handoff.
- **Implementer** — owns the approved-scope edits + self-tests; must NOT edit outside scope, touch the protected surface,
  commit without green tests, or read env/secrets; outputs additive diffs + passing self-tests.
- **Critic** — owns adversarial review/falsification; must NOT author-and-self-approve in one pass or grant a push/release;
  outputs findings + a PASS/REVISE verdict (advisory).
- **Release Gate** — owns the explicit human authorization for stage→commit→push→main→closure; must NOT be satisfied by a
  critic PASS alone, or publish without verification + review; outputs a per-action authorization.

## Gate matrix
plan / critic / implement-approved-scope / verify / release-audit are autonomous under an active bounded batch; local
stage/commit are autonomous only with batch ACTIVE + green tests; **review-branch push, main publish, and milestone
closure are always a HUMAN GATE** (closure only after publication). Live/network/credential/`.env` access is **forbidden**
in every mode.

## Critic PASS ≠ release authorization
A Critic / Codex ACCEPT is advisory; it authorizes only the next step the bounded batch already authorizes. Push, main
publication, and closure are authorized ONLY by the Release Gate (a human).

## Forbidden (every mode)
self-approval · push/main without a gate · closure before publication · reading `.env`/credentials/tokens/secrets or any
live/network/model call · expanding tools/context just to spend tokens · copying leaked/proprietary prompt text.

The tool also emits a **compact handoff prompt** for the role agents. `--batch-authorized true|false` toggles the encoded
autonomy; `--out` is refused for secret/protected/in-work-tree/symlink targets.
