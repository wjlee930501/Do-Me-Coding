# Redaction Record — pre-publication codename generalization (2026-07-10)

## What and why

Before any push of the (never-pushed, local-only) branch `claude/dmc-fable-core`, the user
directed (2026-07-10 human gate): internal product codenames must not reach the public
repository; the strategy documents must read as a universal project. This was the disclosure
item both critics had flagged for the push gate.

Because the codenames lived in COMMIT HISTORY (file blobs and one commit message), editing the
working tree alone would still publish them via the pushed history. The branch had never been
pushed anywhere, so the lawful remedy was a local history rewrite — no force-push, no shared
state touched, no remote ref ever carried the originals.

## What was done

`git filter-branch` (tree-filter + msg-filter) over `aee806b..HEAD` (11 commits), replacing the
three internal codenames with the neutral labels **Product-A / Product-B / Product-C** in every
file blob and commit message. `.codex/config.toml` (pre-existing local dirt) was stashed across
the operation and restored. Backup refs (`refs/original/*`) were deleted after verification.

## Machine verification (post-rewrite)

- `git log aee806b..HEAD -p | grep -cE '<the three original tokens>'` → **0** (all trees/patches)
- `git log aee806b..HEAD --format=%B | grep -cE '…'` → **0** (all messages)
- `git rev-list --count aee806b..HEAD` → **11** (structure preserved; no commit dropped/squashed)
- `git diff <old-head> <new-head> --stat` → exactly the 7 known files, 21 replacement-only line
  pairs (+21/−21); no other content difference between the pre- and post-rewrite trees
- `bin/dmc selftest` → 0 FAIL; `bin/dmc linkcheck` → clean, 24 files

## SHA mapping (old → new)

| Old | New | Subject |
|---|---|---|
| 62fe79c | c6903d9 | docs(dmc): agent handoff rev 14 — public-adoption session record |
| 82a2030 | 4a7ad1e | docs(dmc): succession repair — track strategy memo + no-subagent degradation rule |
| 3e0caf1 | 20d741c | docs(dmc): fable-core cycle A governance records (dual-run verification) |
| 109fed8 | 3a68b9c | feat(dmc): v1.1 measurement layer — run-metrics recorder + effort/course reachability |
| 4c4bf4b | caa2f3f | fix(dmc): regenerate INSTALL_MANIFEST — ship the v1.1 metrics recorder |
| 30b9475 | b64c1f9 | docs(dmc): fable-core cycle D-core governance records (v1.1 measurement layer) |
| 87e76eb | 6b100d9 | fix(dmc): regenerate AGENTS.md — list the v1.1 metrics recorder landmark |
| 3121be7 | baa35f9 | feat(dmc): v1.1.2 repo-intel scan bounding — skip-set, gitignore-aware filter, hard caps |
| 49a0786 | 6e56c12 | docs(dmc): fable-core cycle B governance records (repo-intel bounding) |
| 36cf6b3 | a9c8809 | feat(dmc): v1.1.1 ask-tier bypass-awareness — Block C stands down under bypassPermissions |
| 092049d | 02a489b | docs(dmc): fable-core cycle C governance records (ask-tier bypass-awareness) |

Any OLD sha appearing in the governance records committed BEFORE this rewrite (plans, build
evidence, verification reports, MILESTONES entries) refers to the pre-rewrite identity of the
SAME change; resolve it through this table. Old shas no longer exist as refs in this repository.

## Governance note

This is a user-directed, fully disclosed pre-publication redaction of never-published local
history — recorded here as its own commit rather than silently folded. The rewrite changed no
code, no test, no enforcement surface: the post-rewrite tree is byte-identical to the
pre-rewrite tree except the 21 replacement lines, and the full suite floor re-verified green.
The original (pre-redaction) blobs exist nowhere but this machine's reflog, which is never
pushed.
