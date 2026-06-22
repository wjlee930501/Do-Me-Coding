# PLAN — v0.5.7 Resume / Recovery Controller (APPROVED)

Parent: batch plan (APPROVED). Additive; protected surface untouched.

## Goal
From declared git-state + run facts, recommend the next safe action; never recommend push with staged/uncommitted
changes; never commit excluded-auto-log/protected; never infer approval from stale run state; classify dirty-worktree as
safe-auto-log-only vs not. Output is a `needs_human_gate` candidate (Codex-R6), never "safe to push/commit".

## Accepted file scope (additive)
`docs/RESUME_RECOVERY.md` · `.harness/evidence/dmc-v0.5.7-resume-recovery.sh` · this plan ·
`.harness/verification/dmc-v0.5.7-resume-recovery.md`

## Acceptance criteria
clean committed ahead branch ⇒ eligible review-branch-push candidate; dirty tracked ⇒ stop; staged auto-log ⇒ stop;
untracked auto-log only ⇒ OK; behind origin ⇒ stop; approval missing/stale ⇒ plan/critic path; verification failed ⇒ stop.
Self-test green; repo byte-unchanged.

## Stop conditions
Any "safe to push" authorization, stale-state gate inference, push with uncommitted/protected/auto-log staged.
