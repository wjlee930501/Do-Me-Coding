# hooks-v0.6.5 fixtures — pre-M6 byte-identical snapshot

## Purpose

These fixtures are byte-identical copies of the `.claude/hooks` tree and
`.claude/settings.json` as they existed immediately **before** the M6
(protected surface) plan `dmc-v1-m6-hook-hardening` began editing them.

They exist to satisfy the single-revert rollback guarantee raised in the
M6 critic verdict (findings B1 / O3): if M6's changes to the protected
hook surface ever need to be undone, one revert commit must be able to
restore the live tree to exactly this state — no partial rollback, no
manual reconstruction, no ambiguity about what "pre-M6" looked like.

## Pinned commit

```
299987047e448cff6ea9ddaf8011d66992901003
```

This is the repo `HEAD` at the moment these fixtures were minted, before
any M6 edit landed. Every file under `hooks/` and `settings.json` in this
directory must be byte-for-byte identical to that file as it existed in
the pinned commit.

## Pinning rule

For every fixtured path `<live-path>` (e.g. `.claude/hooks/scope-guard.sh`,
`.claude/settings.json`), the corresponding fixture file must equal:

```
git show 299987047e448cff6ea9ddaf8011d66992901003:<live-path>
```

byte-for-byte. This is what makes the fixtures trustworthy evidence: they
are not merely "a copy someone made," they are provably minted from the
pinned pre-M6 commit itself. A fixture set copied from an already-edited
working tree could not pass this check (finding O3).

## Restore procedure

To roll M6's hook-surface changes back:

1. Produce a single revert commit (or equivalent single commit) that
   restores every live path listed above to its pinned-commit content.
2. Run `tests/fixtures/m6/test-rollback.sh`. Every "live matches fixture"
   check must PASS — this proves the live tree is now cmp-identical to
   this fixture set, i.e. cmp-identical to the pinned pre-M6 commit.
3. Do not consider the rollback complete until the script exits 0.

## Contents

- `hooks/` — byte-exact copy of the pinned commit's `.claude/hooks/` tree,
  including `lib/**`, `worker-context-guard.sh`, and
  `worker-result-check.py`.
- `settings.json` — byte-exact copy of the pinned commit's
  `.claude/settings.json`.

Fixtures are static evidence artifacts; they are read-only inputs to
`tests/fixtures/m6/test-rollback.sh` and must not be edited except to
re-mint them against a newly pinned commit.
