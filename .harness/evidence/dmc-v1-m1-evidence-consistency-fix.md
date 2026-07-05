# Evidence — M1 Evidence Consistency Fix (documentation-only correction)

Date: 2026-07-05 · Branch: `claude/dmc-v1-runtime-upgrade-c5uch1` · M2: NOT started.

## What was inconsistent

`.harness/evidence/dmc-v1-m1-docs.md` stated "No push" while
`.harness/verification/dmc-v1-runtime-upgrade-m1.md` and the actual remote branch state showed
three commits pushed to the dedicated branch (branch-preservation push required by the cloud
Claude Code stop hook / ephemeral container).

## Exact corrections made

1. `.harness/evidence/dmc-v1-m1-docs.md` — the "No push" safety line corrected (with an inline
   correction note) and a new section added:
   `## Operational Exception — Cloud Runtime Commit/Push` (rule vs event, reason, scope =
   dedicated branch only, branch name, main untouched, runtime code unchanged, plan DRAFT,
   M2 not started, no future-push authorization beyond cloud branch-preservation).
2. `.harness/verification/dmc-v1-runtime-upgrade-m1.md` — Evidence section: complete branch
   commit list recorded (`1c139fb`, `4ab5c03`, `5b71595` + this fix commit).
3. `.harness/plans/dmc-v1-runtime-upgrade.md` — ratification-scope note added under Approval
   Status: M1 retroactive ratification covers document creation and the branch-preservation
   push only; it does not approve M2+, protected-surface edits, runtime code changes, or
   future push. **Status remains DRAFT (unchanged).**

## Narrow verification

- Changed files == exactly the three M1 evidence/verification/plan docs + this note
  (`git status --porcelain` before commit showed only those paths).
- Plan still contains `Status: DRAFT` (grep-verified).
- `main` untouched: local `main` == `origin/main` == `d0edc48`
  (`git rev-parse main origin/main`); all work commits are `main..branch` only.
- No runtime/product code changed: hooks, adapters, router, schemas, skills, agents,
  installer byte-unchanged (no such path in the diff).
- No secret read, no live-provider call, no network access beyond the git push to the
  dedicated branch.

## Commit

The fix itself is committed on the dedicated branch under the same cloud branch-preservation
exception (SHA recorded in the commit that adds this file; visible via
`git log --oneline main..claude/dmc-v1-runtime-upgrade-c5uch1`).
