# Evidence — dmc-v1-m2 (Repository Intelligence P1/P2/P4/P5)

Run: dmc-v1-m2 · Date: 2026-07-05 · Branch: claude/dmc-v1-runtime-upgrade-c5uch1
Authorization: human approval 2026-07-05 (M2 ONLY; recorded in the plan's Approval Status).

## Deliverables

- `bin/dmc` — Ring-0 entry point (M2 surface: orient/landmarks/depsurface/radius/selftest).
- `bin/lib/dmc-repo-intel.py` — deterministic core: generators + fail-closed validators +
  embedded self-tests for all four primitives.
- Schemas: `.harness/schemas/{orientation,landmarks,depsurface,radius}.schema.md`.
- Fixtures: `tests/fixtures/{node,python,empty}` (known import graph, manifests, seeded
  dependent, unscanned-extension file).
- Run state: `.harness/runs/current-run.md`, `current-run-id`, `current-scope.txt`
  (transient, gitignored by `.harness/runs/current-*` rule).
- Plan Approval Status updated to record M1 ratification + M2-only approval (authorized
  pre-run edit per the human gate instruction).

## Verification executed

- `bash -n bin/dmc` + `python3 -m py_compile bin/lib/dmc-repo-intel.py` → SYNTAX-OK.
- `bin/dmc selftest orient landmarks depsurface radius` → **36 PASS / 0 FAIL**
  (orient 10 · landmarks 11 · depsurface 8 · radius 7), incl. negative controls:
  missing-key REFUSED, stale-path REFUSED, seeded fake hook detected, listed-'ordinary'
  REFUSED, broken inbound-inversion REFUSED, missing-attestation REFUSED,
  **missing check_id ⇒ REFUSED exit 3** (refusal not weakened; synthetic check-ids
  CHK-SYNTH-* used on the positive path — critic carry-forward note 2 honored).
- E-checks (mktemp only): **5 PASS / 0 FAIL** — E1 `env -i` byte-identical output;
  E2/E2b/E3 generate→`--out`→`--validate` round-trips VALID for landmarks/depsurface/radius;
  E4 file-based radius refusal exit 3; E5 `--out` refuses an existing target.
- DMC self-scan (L1 block): own hooks/settings ⇒ enforcement, provider router + schemas ⇒
  contract, MILESTONES ⇒ release, dmc-glm-smoke ⇒ enforcement (protected-union seed) —
  the M2 acceptance criterion from the plan.
- Repo cleanliness: `git status --porcelain` shows only in-scope paths (plan, 4 schemas,
  bin/, tests/) + auto-logged `.harness/evidence/dmc-v1-m2.md` from the PostToolUse hook.
  (Correction 2026-07-05: this line originally said the auto-log was "intentionally left
  uncommitted per the standing auto-log exclusion policy" — that became stale when the
  cloud runtime's clean-tree requirement forced its commit; see "Operational Exception —
  Auto-log Commit" below.)

## Total: 41 assertions, 0 FAIL.

## M2 scope compliance

Every edited/created path ∈ `.harness/runs/current-scope.txt` ∪ scope-guard's internal-allow
(`.harness/{runs,evidence,verification}`) ∪ the pre-run plan Approval Status edit explicitly
instructed by the human gate. **No edit** to `.claude/hooks/*`, `.claude/settings.json`,
`.claude/skills/*`, `.claude/agents/*`, `.claude/install/*`, `.claude/workers/providers/**`,
worker validators, installer/uninstaller, adapters/router, live paths, main/master.
Diff is additive except the plan's Approval Status block. M3 NOT started.

## Safety confirmations

No live provider/model/API/network call; no `.env*`/credential/secret read (path-only
exclusion also built into the scanners); self-test/E-check writes under mktemp only;
no history rewrite; no force operations.

## Operational Exception — Cloud Runtime Commit/Push (M2)

The cloud Claude Code stop hook requires committing and pushing session work and the remote
container is ephemeral. Already-authorized M2 work was therefore committed and pushed to the
same dedicated branch `claude/dmc-v1-runtime-upgrade-c5uch1` only (branch-preservation push,
as pre-authorized by the M2 approval's push clause). main/master untouched. This exception
does not authorize any other push.

## Operational Exception — Auto-log Commit

- **Original policy:** hook-auto-generated evidence logs (`.harness/evidence/manual-*` and
  per-run auto-logs like `dmc-v1-m2.md`) are local-only by default (standing auto-log
  exclusion policy; v0.2.6 G3 lineage).
- **Actual event:** `.harness/evidence/dmc-v1-m2.md` was committed (`eafe062`) and pushed.
- **Reason:** the cloud runtime's stop hook requires a clean tree, and the ephemeral remote
  container requires branch preservation of session work.
- **Scope:** dedicated branch only — `claude/dmc-v1-runtime-upgrade-c5uch1`.
- **main/master:** untouched (local `main` == `origin/main` == `d0edc48`).
- **Content review before commit:** inspected — tool event logs only (Write/Bash events with
  redacted commands, 153 lines); **0 secret-shaped strings** (grep for sk-/token/password/
  api-key classes returned zero).
- **Runtime/product/protected-surface code:** unchanged by that commit (single evidence file,
  +153/−0).
- **M3:** not started.
- **Authorization boundary:** this exception does NOT make auto-log commits the default going
  forward. Auto-logs remain local-only by policy; committing one again requires the same
  explicit cloud clean-tree justification, recorded per-instance as an operational exception.
