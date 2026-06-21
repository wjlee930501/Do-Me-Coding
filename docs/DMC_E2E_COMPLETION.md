# DMC E2E Completion Controller (v0.3.0)

A **report-only / read-only** controller that reports whether a milestone satisfies DMC's **E2E-done** definition
(verified · reviewed · committed · pushed · closure-recorded) as **done | in-progress | blocked**. It **reports only** —
it never approves, stages, commits, pushes, or grants/performs a gate; it is **offline** (no `git fetch`), makes no
live/model-API/network call, and reads no `.env*`/credentials.

Controller: `.harness/evidence/dmc-v0.3.0-e2e-completion.sh`

## Usage
```
dmc-v0.3.0-e2e-completion.sh --milestone <id> [--commit <hash>] [--branch <b>] [--repo <dir>] [--out <file>]
dmc-v0.3.0-e2e-completion.sh --self-test
```
Exit: `0` done / `1` in-progress|blocked / `2` usage|refused. **Advisory — the exit code must never be wired to perform
a gate.**

## The five criteria (each `met | unmet | blocked`; cannot-evaluate ⇒ blocked)

| Criterion | met when | blocked when |
|---|---|---|
| **verified** | a `.harness/verification/*<id>*.md` report records `Final Status: PASS` | no report found |
| **reviewed** | the report carries the canonical line `Review-Verdict: critic=PASS codex=ACCEPT` (anchored) AND the plan is `Status: APPROVED` | canonical line absent / not PASS+ACCEPT, or report/plan missing (machine cannot confirm) |
| **committed** | an explicit `--commit` is in `git log`, OR a single unambiguous message-match | `--commit` not in log, or auto-match is absent / non-unique (0 or >1) |
| **pushed** | the committed commit is an **ancestor of** `origin/<branch>` (offline) | `committed` blocked, or `origin/<branch>` ref unresolvable locally |
| **closure-recorded** | a `docs/MILESTONES.md` section for the milestone references the commit (canonical-full-hash compare) | `committed` blocked, or `MILESTONES.md` absent/unreadable |

**Overall (fail-closed precedence):** any criterion `blocked` → **blocked** (cannot-evaluate dominates); else any
`unmet` → **in-progress**; else **done**. The controller **never** reports `done` while any criterion is blocked/unmet.

## Design notes

- **`reviewed` requires a canonical anchored line.** A loose substring grep is unsafe: `ACCEPT` appears pervasively as
  worker-result *mock-test* rows (`… → ACCEPT`) and "critic PASS" appears as self-reported prose (`flipped after critic
  PASS`). So `reviewed=met` requires the exact anchored `^Review-Verdict: critic=PASS codex=ACCEPT` line. **Legacy
  reports without it report `reviewed=blocked`** — the honest "cannot mechanically confirm" answer. Verification reports
  going forward MUST carry this line (this v0.3.0 report does).
- **`pushed` is a documented refinement of the handbook.** The handbook's E2E-done criterion 4 is `HEAD == origin/main`;
  the controller uses **per-commit ancestor-of-`origin/<branch>`** because a closed milestone must stay "pushed" even
  when a later milestone adds unpushed commits (the real state: HEAD ahead of origin). It is evaluated **offline against
  the last-fetched local origin ref** (no `git fetch`) — the report states this stale-ref caveat — and the HEAD
  ahead/behind is reported alongside so the handbook's whole-branch invariant stays visible. (Primitive:
  `merge-base --is-ancestor`, not v0.2.6's `rev-list --left-right`.)
- **Hash normalization.** All commit-hash comparisons are by canonical full hash via `git rev-parse`, so an abbreviated
  `MILESTONES.md` token (`963f25a`) matches a 40-char git hash.
- **Branch resolution.** `--branch <b>` if given, else `origin/main` (matching the v0.2.6 `DMC_GATE_UPSTREAM` prior); an
  absent local `origin/<branch>` ref ⇒ `pushed=blocked`.

## Report-only contract
The controller reports state; it performs/grants no gate, stages/commits/pushes nothing, and is an **input** to the
human Release Gate and the Codex audit — not a substitute. The only write is a canonicalization-guarded `--out` report
file (refuses protected/secret incl. traversal/symlink; never `git add`ed). `--self-test` runs in `mktemp` temp repos
(real repo untouched).
