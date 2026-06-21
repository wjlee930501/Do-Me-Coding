# DMC Closure Controller (v0.3.7)

A **read-only** controller that **mechanically judges the 5 DMC closure conditions** for a milestone and emits an
**append-only `docs/MILESTONES.md` closure-entry candidate**. It **writes nothing**, **commits/pushes nothing**, makes
**no live call**, never reads/prints secret content, and **grants no gate** — `E2E-DONE` is a *judgment*, not an
authorization.

Implemented by `.harness/evidence/dmc-v0.3.7-closure-controller.sh`.

## The 5 closure conditions (and their signals)

The handbook / v0.2.9 STOP definition (`docs/DMC_EFFORT_PROVIDER_POLICY.md:48`):

| condition | MET signal (else NOT-MET, fail-closed) |
|---|---|
| **verified** | the `--verify-report` has a `## Final Status` `**PASS**` marker AND a `N PASS / 0 FAIL` (or an **equal** ratio `N/N`, N>0 — a non-equal ratio like `8/9` does **not** count) AND **no** `**FAIL**` marker and **no** `N>0 FAIL` token anywhere |
| **reviewed** | the **exact** canonical line `^Review-Verdict: critic=PASS codex=ACCEPT$` (trailing whitespace only — `codex=ACCEPTED` or extra trailing text does **not** match) |
| **committed** | `git rev-parse --verify <ref>^{commit}` resolves |
| **pushed** | `git merge-base --is-ancestor <ref> origin/main` (the last-fetched local `origin/main`; no fetch) |
| **closure-recorded** | a **whole-token** match of the milestone id in `docs/MILESTONES.md` (`v0.3.7` ≠ `v0.3.70`) |

**E2E-DONE iff all 5 MET.** Advisory exit `0` (E2E-DONE) / `1` (NOT DONE) — never wired to commit/push.

## Fail-closed (no false E2E-DONE)

Every condition is fail-closed: any ambiguous or absent signal ⇒ NOT-MET. Two specific fail-OPEN vectors are closed:

- **verified** is **not** presence-only — a mixed-count report (`5 PASS / 0 FAIL` AND `2 PASS / 3 FAIL`) is NOT-MET (the
  `3 FAIL` token disqualifies it). The `N>0 FAIL`/`**FAIL**` disqualifier errs strict (fail-closed) over a false DONE.
- **reviewed** binds to the **single anchored** Review-Verdict line — narrative prose elsewhere mentioning an earlier
  `codex=ACCEPT` does not flip a canonical `codex=REVISE`/`PENDING` to MET.

## No write / append-only / no secret content

- **Writes nothing**: the MILESTONES.md candidate is **text to append** — the controller never writes/modifies
  `MILESTONES.md`, never rewrites existing entries, never `git add/commit/push`.
- **No secret content**: the `--verify-report` path is **refused unread** if it matches a secret pattern; git is read with
  **metadata-only** primitives (`rev-parse`, `merge-base`, `show -s --format='%s'`) — no content-dumping `show`/`diff`,
  no `-p`/patch family, no `log -p`/`diff-tree`/`format-patch`/`cat-file`; the commit **body (`%b`) is never read** (only
  the subject `%s`).

## Usage

```
closure-controller.sh --milestone <id> --commit <ref> --verify-report <path> \
    [--milestones-file <path>] [--repo <dir>] [--date <YYYY-MM-DD>] [--out <file>]
closure-controller.sh --self-test
```

`--out` reuses the v0.3.4–v0.3.6 hardened guard (refuses protected/secret/symlink and any `..`-component target).
