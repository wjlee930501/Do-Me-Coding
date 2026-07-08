# DMC Agent Handoff

A one-page quick-card for resuming the DMC milestone loop safely. Read this with `DMC_OPERATOR_HANDBOOK.md`.

> **Canonical role taxonomy: `orchestration/roles.json`** (the P14 `dmc.roles.v1` registry) is the
> single machine-readable home for the DMC orchestration roles and capability classes. The role and
> template descriptions in this quick-card are **derived / legacy reference** kept for narrative
> context; if they ever disagree with the registry, the registry wins. Validate it with
> `bin/dmc roles validate`. This banner is additive — the state machine, gate rules, and prompt
> templates below are unchanged.

## Resume quick-card — the state machine

```
DRAFT → CRITIC → APPROVED → START-WORK → VERIFY → STAGE → COMMIT → PUSH → CLOSURE
```

| State | Entry criteria | Exit criteria | Gated? |
|---|---|---|---|
| DRAFT | a task/intent | plan file written, `Approval Status: DRAFT` | no |
| CRITIC | a DRAFT plan | verdict PASS or REVISE (revise loops back) | no |
| APPROVED | critic PASS | human flips `Approval Status: APPROVED` | **yes** |
| START-WORK | APPROVED plan | in-scope files written; run state set | no (within scope) |
| VERIFY | implementation | verification harness/report PASS | no (mock/offline) |
| STAGE | VERIFY PASS | only approved files staged; reviews printed | **yes** |
| COMMIT | staged + reviewed | exact-message commit, clean boundary | **yes** |
| PUSH | commit | `HEAD == origin/main` | **yes** |
| CLOSURE | push | `docs/MILESTONES.md` entry recorded | **yes** (docs commit) |

## Current-gate confirmation rule (read before any gated action)

- On resume, **re-confirm the current gate was actually granted by the human** before taking any gated action.
- **Never infer a gate** from run-state, a previous message, or partially-completed work. An in-progress run is not
  consent to flip approval, stage, commit, push, force-operate, publish, or make a live call.
- If you cannot point to an explicit human grant for the action in front of you, **stop and ask.**

## How to resume mid-loop

1. Read `.harness/runs/current-run.md` (the active run + locked scope) — for context, not for consent.
2. Re-confirm `Approval Status` in the plan; do not proceed past a gate you cannot prove was granted.
3. Re-run the verification harness before claiming any state is complete.
4. Apply the fail-closed rules; surface ambiguity instead of guessing.

## Fail-closed checklist (STOP + report)

scope ambiguous · protected-file diff · credential/secret/token exposure risk · live-call risk without a gate ·
any verification FAIL.

## Anti-token-max reminder

Smallest workflow that closes the problem E2E. Do not expand scope/files/tools because they are available.

## Reusable prompt templates

Each template states inputs, the gate it serves, fail-closed conditions, and the exact outputs to print. Placeholders
are `<…>`.

### critic
- **Inputs:** `<plan-or-result path>`, focus areas.
- **Serves:** the CRITIC state (no gate; produces a verdict).
- **Do:** review adversarially; empirically verify load-bearing claims; return **PASS** or **REVISE** with critical
  issues first, required vs. optional changes separated. Critic only — no edits, no approval, no implementation.
- **Fail-closed:** if the plan is ambiguous or a claim cannot be verified, say so; do not approve.
- **Outputs:** verdict; critical findings; required changes; optional improvements; final recommendation.

### start-work
- **Inputs:** `<APPROVED plan path>`.
- **Serves:** START-WORK (autonomous within the approved scope only).
- **Do:** confirm `Approval Status: APPROVED`; write run state + locked scope; implement **only in-scope files**; run
  mock/offline verification; write evidence + report.
- **Fail-closed:** if not APPROVED, or a needed file is out of scope, or a protected file would change → STOP + report.
- **Outputs:** changed files; verification results; protected-files-unchanged proof; safe-to-stage yes/no.

### staging-review
- **Inputs:** the approved file list; the excluded-file list.
- **Serves:** STAGE (gated — requires the human's go to stage).
- **Do:** clear run state; `git add` only the approved files; print `--cached --name-only / --stat / --check`; scan for
  forbidden/excluded files; prove protected files byte-unchanged.
- **Fail-closed:** any forbidden/protected file present, or count mismatch → STOP, do not stage further.
- **Outputs:** the five review prints + a safe-to-commit yes/no.

### commit-review
- **Inputs:** the staged set; the exact commit message.
- **Serves:** COMMIT (gated).
- **Do:** print `--cached --name-only / --stat / --check`; confirm excluded files are not staged; commit with the
  **exact** message (no extra trailers); print hash, status, `show --stat HEAD`.
- **Fail-closed:** if an excluded file is staged or the staged set differs from approved → STOP, do not commit.
- **Outputs:** commit hash; post-commit status; `show --stat`.

### push-review
- **Inputs:** the local commit; the target branch.
- **Serves:** PUSH (gated).
- **Do:** print status, `log -1`, branch, ahead/behind; `git push origin <branch>` (never `--force` without a separate
  gate); confirm `HEAD == origin/main`.
- **Fail-closed:** if behind origin, or a non-fast-forward/force would be needed → STOP + report.
- **Outputs:** push result; post-push status; sync confirmation.

### milestone-closure
- **Inputs:** the shipped commit hash(es); the milestone summary.
- **Serves:** CLOSURE (gated — a separate `docs(dmc):` commit).
- **Do:** append a `docs/MILESTONES.md` entry (commit, what shipped, verification result, posture); keep it factual and
  own-words; commit separately from feature code.
- **Fail-closed:** if the milestone is not actually pushed, or facts are unverified → STOP, do not record closure.
- **Outputs:** the milestone entry; its own commit hash.
