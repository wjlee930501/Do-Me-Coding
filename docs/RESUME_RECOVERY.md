# RESUME_RECOVERY.md — DMC Resume / Recovery Controller (v0.5.7)

"Wake up and continue safely." Given declared git-state + run facts, recommend the **next safe action** after an
interruption. Advisory; inert unless invoked; reads no env/secret; no network/live call. **Resume-safe:** it never infers
a gate from stale run state, and it **never emits "safe to commit/push"** — at most a `needs_human_gate` candidate bound to
the exact commit hash.

## Inputs
`branch` · `ahead` / `behind` (vs origin) · `tracked_dirty` · `staged_protected` · `staged_autolog` ·
`untracked_autolog_only` · `plan_status` · `plan_hash_match` · `verification` (PASS/FAIL/NONE) · `commit_hash`.

## Decision (ordered, fail-closed — most-blocking first)
1. `verification=FAIL` ⇒ **STOP**.
2. a **protected** file staged ⇒ **STOP** (needs an approved plan + gate).
3. an excluded **auto-log** staged ⇒ **STOP** (unstage; not committable).
4. **dirty tracked** worktree ⇒ **STOP** (commit/review first; never push with uncommitted changes).
5. **behind origin** (or unparseable ahead/behind) ⇒ **STOP** (reconcile; do not push).
6. plan **not APPROVED** or **stale** (`plan_hash_match` false) ⇒ **PLAN_OR_CRITIC** (never implement; never infer
   approval from stale run state).
7. approved but `verification=NONE` ⇒ **VERIFY**.
8. clean + committed + `ahead>0` + `verification=PASS` + approved ⇒ **NEEDS_HUMAN_GATE** — a *candidate* for a
   review-branch push **bound to the commit hash**. This is **not** an authorization.

Dirty-only-excluded-auto-logs is classified **safe** (treated as clean). The output always notes that it never authorizes
a push/commit — the actual push/commit/closure remain separate explicit human gates.
