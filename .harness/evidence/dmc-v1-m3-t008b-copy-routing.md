# DMC v1.0 Runtime Upgrade — M3 Copy-Routing + selftest --all + Mirror-Check (DMC-T008b)

- date: 2026-07-06
- branch: `claude/dmc-v1-runtime-upgrade-c5uch1`
- depends on: DMC-T008a baseline pin (`.harness/evidence/dmc-v1-m3-baseline.md`, pinned
  aggregate: 49 tools / 802 PASS / 3 FAIL / 3 N/A)
- scope: `bin/dmc` (routing additions only), `bin/lib/**` (new: copied v0.x tools + aggregator),
  this evidence file. No `.harness/evidence/dmc-v0.*` original was edited. No stage/commit/push.

## What was built

1. **Copy** (not move) of every `.harness/evidence/dmc-v0.*.{sh,py}` file into `bin/lib/` —
   **55 files** (49 `.sh` + **6** `.py` cores; the plan text and DMC-T008a's evidence both said
   "5 .py cores" — that was an undercount by one, corrected here: `dmc-v0.6.1-capability-router.py`,
   `dmc-v0.6.1.0-trace-linkage.py`, `dmc-v0.6.2-evidence-receipt.py`, `dmc-v0.6.3-findings-gate.py`,
   `dmc-v0.6.4-goal-ledger.py`, `dmc-v0.6.5-decision-trace.py` — six, not five. Aggregate PASS/FAIL
   counts in T008a were unaffected by the miscount; only the tool-count-of-py-cores prose was off).
   Copied with `cp -p` (mode/timestamps preserved). Verified byte-identical to source immediately
   after copy via sha256 (55/55 match) before any further work.
2. **`dmc` routing** (`bin/dmc`, additions only — the M2/M3 sections already present from
   DMC-T007 are untouched):
   - `dmc legacy list` — lists the 49 routed tool ids (derived from `bin/lib/dmc-v0.*.sh`).
   - `dmc legacy <tool-id> [args...]` — execs `bash bin/lib/dmc-<tool-id>.sh [args...]`
     (accepts the id with or without the `dmc-`/`.sh` decoration); unknown id -> exit 2.
   - `dmc mirror-check` — bin/lib <-> `.harness/evidence` byte-equality over the 55-file set.
   - `dmc rollback-test` — runs the rollback simulation (see below).
   - `dmc selftest --all` — the M2 sections (orient/landmarks/depsurface/radius) + M3
     validators (validate-plan/run/verification, schemas-mirror) already wired by DMC-T007,
     **plus** all 49 legacy tools' self-tests against the `bin/lib` copies, **plus**
     mirror-check, **plus** rollback-test.
3. **`bin/lib/dmc-legacy-selftest.py`** — the new aggregator/mirror-check/rollback-test module.
   Reused the exact tool partition and summary-line regexes from the T008a baseline pin
   (12 no-flag tools, 37 `--self-test` tools), so a copy run and an originals run are
   apples-to-apples. Offline, no network, no shell=True, no secret read; only ever writes to
   `tempfile.mkdtemp()` (always cleaned up) — never to the real repo outside `bin/lib/`.

Sibling-path composition (plan §M3 note) was verified to keep working: each `.sh` wrapper's
`SELFDIR`/`ROOTDIR` resolution is either (a) `$(pwd)` or `git rev-parse --show-toplevel`
(location-independent — works from `bin/lib` unchanged) or (b) `$(dirname "$0")/../..`
(location-*relative* — and `bin/lib` is two path segments below repo root, exactly like
`.harness/evidence`, so it resolves to the same repo root either way). Confirmed empirically:
`dmc-v0.6.5-decision-trace.sh` (which uses the sibling `.py` pattern) ran correctly from
`bin/lib` and found its co-located `bin/lib/dmc-v0.6.5-decision-trace.py` core.

## Mirror-check result: PASS (55/55 byte-identical), now a fast default `dmc selftest` section
with a negative control

```
dmc mirror-check
... (55 x "PASS byte-identical: <file>") ...
PASS no stray dmc-v0.* copies beyond the pinned 55-file set
RESULT: PASS mirror-check green
```

Every `bin/lib/dmc-v0.*.{sh,py}` file hashes identically to its `.harness/evidence/` source
(sha256, both directions), and `bin/lib/` contains no extra `dmc-v0.*` file beyond the pinned
55. This is the "Not-edit: tool logic (any logic diff fails the mirror-check)" acceptance gate
from the plan, and it is currently green.

Per the refined M3 instructions, the mirror-check is now also registered as a fast **default**
`dmc selftest` section named `legacy-mirror` (not gated behind `--all`), with a negative control
proving it can actually detect drift rather than always reporting green:

```
$ python3 bin/lib/dmc-legacy-selftest.py mirror --self-test
PASS [legacy-mirror] M1 all 55 bin/lib copies byte-identical to their .harness/evidence originals, both directions, no stray dmc-v0.* files
PASS [legacy-mirror] M2 a freshly duplicated, untampered scratch pair reports clean
PASS [legacy-mirror] M3 negative control: a single tampered byte in one scratch bin/lib copy is REFUSED overall and the specific file is named (proves mirror-check can fail, not just always pass)
PASS [legacy-mirror] M4 negative control never touched the real .harness/evidence original
[legacy-mirror] 4 PASS / 0 FAIL
```

M2-M4 run entirely inside a `tempfile.mkdtemp()` scratch pair (both an `evidence/` and a `lib/`
copy of all 55 files, duplicated from the real originals) — the tamper in M3 only ever touches
that disposable copy, and M4 explicitly re-hashes the real original before/after to prove it.

`dmc selftest` (default, no `--all`) is now **75 PASS / 0 FAIL in ~0.8s**: the pre-existing 71
(orient 10, landmarks 11, depsurface 8, radius 7, validate-plan 8, validate-run 6,
validate-verification 6, schemas-mirror 15) plus the new `legacy-mirror` 4. Still fast and
green, per the "default selftest must remain fast" requirement — the heavy 49-tool run and the
rollback-test stay exclusively under `selftest --all`.

## Rollback-test result: split — the safety property holds, the aggregate-reproduction sub-check
does not (see root-cause below, same cause as the `selftest --all` drift)

`dmc rollback-test` copies the real `bin/` into a disposable `tempfile.mkdtemp()` directory,
deletes the 55 legacy copies **there only**, then checks two things against the **real** repo:

1. **`.harness/evidence/dmc-v0.*` originals are byte-unchanged** (55 files re-hashed
   before/after the simulated deletion) — **PASS**. This is the load-bearing safety property:
   the real repo's canonical originals are provably independent of `bin/`, so `rm -rf bin/`
   in the real repo would lose zero legacy-tool functionality (rollback is real, not asserted).
2. **The originals alone still reproduce the pinned T008a baseline exactly** — **FAIL** (see
   below). This sub-check re-runs all 49 originals' self-tests as an extra confidence check;
   it is not what makes rollback safe (safety = property 1, which passed), but it currently
   fails for the same environmental reason `selftest --all`'s own aggregate does.

## `selftest --all` aggregate: currently 800 PASS / 5 FAIL / 3 N/A vs pinned 802/3/3 —
2 extra FAILs, both explained and neither caused by this task's copy/routing work

Full per-tool legacy output matches DMC-T008a's pinned per-tool table **exactly** for 47 of 49
tools, including reproducing the same 3 pre-existing upstream FAILs unchanged
(`dmc-v0.1.3-verify.sh` 44/1, `dmc-v0.2.3-verify.sh` 19/1, `dmc-v0.3.2-verify.sh` 7/1 exit 1).
Two tools now additionally FAIL that were 0-FAIL at the T008a pin:

| Tool | Pinned (T008a) | Now | New FAIL assertion |
|---|---|---|---|
| `dmc-v0.5.9-dynamic-workflow-acceptance.sh` | 15 PASS / 0 FAIL | 14 PASS / 1 FAIL | `AC13 repo/protected changed` |
| `dmc-v0.6.0-verify.sh` | 18 PASS / 0 FAIL | 17 PASS / 1 FAIL | `V15 no protected-surface change; tracked changes in-scope` |

**Root cause (verified, not assumed):** both assertions are pre-M3-vintage "protected surface
drift" detectors that read `git status --porcelain` directly:
- `dmc-v0.5.9` AC13: `git status --porcelain -- .claude .harness/schemas | grep -vE '^\?\?'`
  must be empty (i.e., zero *tracked* modifications under `.claude` or `.harness/schemas`).
- `dmc-v0.6.0` V15: every tracked (non-`??`) modification's path must match a hardcoded
  allowlist of prefixes (`docs/*`, `.harness/plans/*`, `.harness/verification/*`, two named
  files) — `.harness/schemas/*` and root `*_SCHEMA.md` are **not** in that v0.6.0-vintage list.

Right now the working tree has tracked (not `??`) modifications to exactly the files DMC-T007
was approved to edit this milestone: `.harness/schemas/plan.schema.md`,
`.harness/schemas/run.schema.md`, `.harness/schemas/verification.schema.md`, `PLAN_SCHEMA.md`,
`RUN_SCHEMA.md`, `VERIFICATION_SCHEMA.md` (confirmed via `git status --porcelain -- .harness/schemas
PLAN_SCHEMA.md RUN_SCHEMA.md VERIFICATION_SCHEMA.md`, all six show ` M`). These two v0.5.9/v0.6.0
self-tests predate the M3 plan's decision to expand the canonical-editable surface into
`.harness/schemas/*.schema.md` mirrors and root `*_SCHEMA.md` files (plan §M3, DMC-T007) — they
have no way to know that surface is now legitimately in scope, so they flag it as an unexpected
protected-surface change.

**This is confirmed to be an environment/timing artifact, not a copy-routing defect**, by two
independent checks:
- Running the aggregator directly against `.harness/evidence` (the originals, bypassing
  `bin/lib` entirely) reproduces the **identical** 800/5/3 result and the identical 2 new
  FAILs — so `bin/lib`'s copies are not the cause; the live working-tree state is.
- `dmc mirror-check` is 100% green and the "originals byte-unchanged" rollback sub-check is
  PASS — the copy operation itself introduced zero drift.

**Expected resolution:** once the M3 deliverables (DMC-T007's schema edits + this task's
additions) reach a clean/committed state, `git status --porcelain` will no longer show these
tracked modifications and both checks should revert to PASS, restoring the exact 802/3/3
pinned aggregate. Staging/committing is explicitly a separate human gate
(not-edit list: "any push/stage/commit (separate human gates)"), so this task does not (and
per scope, must not) force that resolution itself.

**What I did not do, and why:** I did not edit `dmc-v0.5.9-dynamic-workflow-acceptance.sh` or
`dmc-v0.6.0-verify.sh` to update their protected-surface allowlists (that would be an in-place
edit of a `dmc-v0.*` original — explicitly forbidden, and it would also immediately break the
mirror-check against the `bin/lib` copy unless I edited both, which is still forbidden for the
originals). I did not adjust the pinned-baseline comparison in `dmc-legacy-selftest.py` to
special-case these two tools or silently accept a "one-time known drift" — the aggregator
reports the honest, reproducible number for whatever the working tree looks like at run time,
which is the correct behavior for a drift detector; papering over it would defeat the point of
the exact-baseline acceptance gate.

## Full command outputs (abridged; full logs available on request)

```
$ bin/dmc legacy list | wc -l
49

$ bin/dmc legacy v0.6.0-verify --self-test   # spot-check routing works end-to-end
...
RESULT: 17 PASS / 1 FAIL   (same result running via bin/lib as via .harness/evidence directly)

$ bin/dmc mirror-check
... 55x PASS byte-identical ...
PASS no stray dmc-v0.* copies beyond the pinned 55-file set
RESULT: PASS mirror-check green

$ bin/dmc selftest --all
[orient] 10 PASS / 0 FAIL
[landmarks] 11 PASS / 0 FAIL
[depsurface] 8 PASS / 0 FAIL
[radius] 7 PASS / 0 FAIL
[validate-plan] 8 PASS / 0 FAIL
[validate-run] 6 PASS / 0 FAIL
[validate-verification] 6 PASS / 0 FAIL
[schemas-mirror] 15 PASS / 0 FAIL
== dmc selftest --all : legacy tool aggregate (bin/lib copies) ==
  ... 49 tool lines ...
  -- aggregate: tools=49 PASS=800 FAIL=5 N/A=3 timeouts=0 unparsed=0 --
  FAIL aggregate DRIFTED from pinned baseline {'tools': 49, 'pass': 802, 'fail': 3, 'na': 3}
== mirror-check : bin/lib <-> .harness/evidence byte-equality (55 files) ==
  ... RESULT: PASS mirror-check green
== rollback-test : simulate 'rm -rf bin/' in a disposable temp copy ==
  PASS real .harness/evidence originals byte-unchanged during rollback sim (55 files re-hashed)
  FAIL originals alone do not reproduce the pinned baseline: got tools=49 PASS=800 FAIL=5 N/A=3
  RESULT: FAIL rollback procedure verification failed
==== SELFTEST-ALL RESULT: FAIL ====
```

M2 (orient/landmarks/depsurface/radius) and M3 validator/schemas-mirror sections: all green,
unaffected (65/65 PASS across those eight sections), confirming DMC-T007's work is otherwise
intact and this task did not regress it.

## Repo-cleanliness / scope check

`git status --porcelain` after all of this task's work shows changes only under the approved
scope: `bin/dmc` (modified, routing additions only — diff reviewed, additive), `bin/lib/**`
(55 copied tools + `dmc-legacy-selftest.py`, all new/untracked), and this evidence file (new).
The pre-existing tracked modifications to `.harness/plans/dmc-v1-runtime-upgrade.md`,
`.harness/schemas/{plan,run,verification}.schema.md`, and root `{PLAN,RUN,VERIFICATION}_SCHEMA.md`
belong to the concurrent DMC-T007 task (already completed/reviewed per the shared run-state
ledger), not to this task. No `.harness/evidence/dmc-v0.*` original was touched (verified via
the mirror-check's byte-equality and the rollback-test's explicit before/after re-hash). No
`__pycache__` directory was created (checked via `find . -type d -name __pycache__` after all
runs — none found). No git add/commit/push was performed. No network access. No secret access.

## Open item for the M3 integrated verification / human gate

The `selftest --all` "exact aggregate == pinned baseline" acceptance criterion cannot be
satisfied while `.harness/schemas/*` and root `*_SCHEMA.md` carry tracked, uncommitted M3-scope
edits, because two pre-M3-vintage tools (`dmc-v0.5.9`, `dmc-v0.6.0`) treat that as an
unrecognized protected-surface change. Recommended path (for the M3 verifier / human gate to
decide, not decided unilaterally here): re-run `bin/dmc selftest --all` once the M3 schema
edits are committed (separate human gate) and confirm the aggregate returns to exactly
802 PASS / 3 FAIL / 3 N/A; if it does, this is conclusive proof the 2-FAIL delta was purely the
uncommitted-working-tree artifact described above, not a routing defect.
