# Evidence — M2 Auto-log Consistency Fix (documentation-only correction)

Date: 2026-07-05 · Branch: `claude/dmc-v1-runtime-upgrade-c5uch1` · M3: NOT started.

## What was inconsistent

`.harness/evidence/dmc-v1-m2-repo-intel.md` said the auto-logged
`.harness/evidence/dmc-v1-m2.md` was "intentionally left uncommitted per the standing
auto-log exclusion policy" — stale after that file was committed as `eafe062` under the
cloud clean-tree / branch-preservation exception.

## Exact corrections made

1. `.harness/evidence/dmc-v1-m2-repo-intel.md` — stale line corrected with an inline
   correction note; new section added: `## Operational Exception — Auto-log Commit`
   (original policy, actual event with SHA `eafe062`, cloud clean-tree reason,
   dedicated-branch-only scope, main untouched at `d0edc48`, pre-commit content review —
   tool event logs only / 0 secret-shaped strings, no runtime code changed, M3 not started,
   no default future auto-log-commit authorization).
2. `.harness/verification/dmc-v1-m2-repo-intel.md` — Push disclosure addendum: final M2
   branch state includes `.harness/evidence/dmc-v1-m2.md` at `eafe062`; no new risk;
   **Status remains PASS**.
3. This correction note.

## Narrow verification

- Changed files == exactly the two M2 evidence/verification docs + this note
  (`git status --porcelain` before commit).
- M3 not started: no bin/, schema, or runtime change in this correction; no M3 task begun.
- Plan check: `.harness/plans/dmc-v1-runtime-upgrade.md` Approval Status still reads
  "M3+ remain UNAPPROVED (DRAFT)" — unmodified by this correction.
- No hooks/settings/skills/agents/install/workers/providers/adapters/router change
  (no such path in the diff).
- main/master untouched: local `main` == `origin/main` == `d0edc48`.
- No secret read, no live-provider call, no network beyond the branch-preservation push of
  this correction to the same dedicated branch (recorded below).

## Operational Exception — this correction's commit/push

Committed and pushed to `claude/dmc-v1-runtime-upgrade-c5uch1` only, under the same cloud
clean-tree / branch-preservation requirement. SHA visible via
`git log --oneline main..claude/dmc-v1-runtime-upgrade-c5uch1`.
