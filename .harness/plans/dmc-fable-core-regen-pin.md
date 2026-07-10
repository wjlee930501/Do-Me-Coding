# Plan — fable-core follow-up (v1.1.4): committed==regenerated selftest pins for the generated artifacts (INSTALL_MANIFEST.md + AGENTS.md)

Work ID: dmc-fable-core-regen-pin

## Goal

Permanently wire a "committed == regenerated" byte-equality self-check for BOTH generated
artifacts into `bin/dmc selftest`, so a future lockstep drift of either escapes NO cycle
(registered follow-up item 1 from the fable-core envelope; candidate label v1.1.4). The defect this
closes: during cycle D-core BOTH lockstep artifacts drifted — `INSTALL_MANIFEST.md` was caught by
the m8 suite, but `AGENTS.md` drift was caught only by a later critic by luck
(`.harness/evidence/dmc-fable-core-e-build-20260710.md` "Registered follow-ups").

Honest scope (the pivotal finding — see Current Repo Findings F1/F2):

- **`INSTALL_MANIFEST.md` is ALREADY permanently pinned.** `tests/fixtures/m8/test-manifest-drift.sh`
  (run by `run_m8_suite` at `bin/dmc:581` under `selftest --all` AND by the BLOCKING CI step
  `bin/dmc selftest m8-suite` at `.github/workflows/dmc-ci.yml:178-179`) does exactly this:
  `dmc-install.sh --emit-manifest` byte-compared (`cmp -s`) against the committed
  `INSTALL_MANIFEST.md`, plus a hand-edit negative control AND a section-delete negative control
  (`tests/fixtures/m8/test-manifest-drift.sh:31-90`). No new code is required for INSTALL_MANIFEST.
- **`AGENTS.md` has NO such pin.** The `agents-md --self-test` (`bin/lib/dmc-agents-md.py:680`)
  exercises the generator against synthetic node/python/empty fixtures + determinism + validator
  negative controls; it NEVER compares the generator's output against the DMC repo's own committed
  `AGENTS.md`. This cycle's net-new work is a hermetic AGENTS.md drift suite that mirrors
  `test-manifest-drift.sh`, wired into the M6.5 suite group (where the `agents-md` module lives).

Net effect: after this cycle, BOTH generated artifacts have a permanent, CI-blocking, selftest-wired
regen-drift pin, each living with its own generator's suite family (INSTALL_MANIFEST -> m8, AGENTS.md
-> m6.5), with a deliberate-drift negative control proving the pin has teeth.

## User Intent

verification

(This is a regression-pin / test-coverage addition. It adds a permanent self-check to the selftest
surface; it introduces NO product-behavior change to any enforced runtime path and does NOT modify
any generator or frozen tool.)

## Current Repo Findings

(grounded 2026-07-10, this session; branch `claude/dmc-fable-core` == `main` == `bbeb277`,
`.harness/mode=active`. Baseline byte-equality VERIFIED live this session: both
`python3 bin/lib/dmc-agents-md.py --root . --stdout | diff - AGENTS.md` and
`bash .claude/install/dmc-install.sh --emit-manifest | diff - INSTALL_MANIFEST.md` are EMPTY —
committed == regenerated for both artifacts at `bbeb277`.)

- Finding F1 (INSTALL_MANIFEST already pinned): `tests/fixtures/m8/test-manifest-drift.sh:31-50`
  (`arm_byte_equality`) does `cmp -s "$emitf" "$M8_MANIFEST"` where `$M8_MANIFEST` is the committed
  `INSTALL_MANIFEST.md` and `$emitf` is `dmc-install.sh --emit-manifest`; `:52-90` add hand-edit +
  section-delete negative controls. It runs under `run_m8_suite` (`bin/dmc:291-301`), which is in
  `selftest --all` (`bin/dmc:581`) and the BLOCKING CI step `selftest m8-suite`
  (`.github/workflows/dmc-ci.yml:178-179`). So the INSTALL_MANIFEST committed==regen pin already
  exists and is enforced.
  Source: `tests/fixtures/m8/test-manifest-drift.sh`, `bin/dmc:291-301,581`, `.github/workflows/dmc-ci.yml:178-179`.
- Finding F2 (AGENTS.md gap): `bin/lib/dmc-agents-md.py:680-834` (`selftest()`) tests the generator
  against `tempfile.mkdtemp()` synthetic repos only; there is NO assertion that
  `agents-md --root <repo> --stdout` equals the repo's own committed `AGENTS.md`. Grep of
  `tests/ .github/ docs/DMC_V1_RELEASE_CHECKLIST.md` for an AGENTS.md drift/byte/diff check returns
  only an unrelated `wc -c` size read (`tests/fixtures/m6.5/test-agents-md.sh:165`). This is the gap.
  Source: `bin/lib/dmc-agents-md.py:680`, grep of tests/.github/.
- Finding F3 (the 802/3/3 aggregate is ONLY the legacy-tool count): `PINNED_BASELINE = {"tools": 49,
  "pass": 802, "fail": 3, "na": 3}` (`bin/lib/dmc-legacy-selftest.py:118`) is the aggregate of the 49
  `dmc-v0.*` legacy tools' internal PASS/FAIL/N-A, printed as `aggregate: tools=49 PASS=802 FAIL=3
  N/A=3` / `SELFTEST-ALL RESULT: PASS`. It is the ONLY code-enforced pinned number. Every repo
  reference (`docs/MILESTONES.md`, `docs/DMC_V1_ENFORCEMENT_MATRIX.md:147`, `docs/DMC_V1_HONEST_SCOPE.md:133`,
  `docs/DMC_CONSTITUTION.md:57` II.2, `docs/DMC_V1_RELEASE_CHECKLIST.md:52`) calls it the "legacy
  `selftest --all` baseline." A NEW suite that is not a `dmc-v0.*` tool does NOT touch this number
  (the mirror stray-guard greps `f.startswith('dmc-v0.')`, so a non-`v0.` name is outside the count —
  the `dmc-metrics-recorder.py` precedent).
  Source: `bin/lib/dmc-legacy-selftest.py:8,118,350-401`; the 802 grep sweep this session.
- Finding F4 (M6.5 suite runner + standalone-test pattern): `run_m65_suite` (`bin/dmc:275-285`) loops
  `for s in test-codex-shims.sh test-skills-mirror.sh test-agents-md.sh`. `test-agents-md.sh` is
  STANDALONE (its own header: "no _m65common.sh dependency"), defines its own `record`/`PASS`/`FAIL`,
  resolves `ROOT=$SELF_DIR/../../..`, drives the real `bin/dmc`, and ends with
  `RESULT: $PASS PASS / $FAIL FAIL` + `exit 0 iff FAIL==0`, wrapped by a `git status --porcelain`
  before/after hermeticity assert. This is the template the new drift suite copies.
  Source: `bin/dmc:275-285`, `tests/fixtures/m6.5/test-agents-md.sh:1-30, tail`.
- Finding F5 (lockstep neutrality — this change does not drift EITHER artifact): `INSTALL_MANIFEST.md`
  enumerates `bin/dmc` (fixed name), `bin/lib/*` (by name via `ring0_lib_list`,
  `.claude/install/dmc-install.sh:60,111`), and `.harness/schemas/*.schema.md` (by name) — it is
  CONTENT-agnostic and does NOT enumerate `tests/fixtures/**` (not shipped). `AGENTS.md` section-4
  landmarks are PATH+CLASS derived from `dmc landmarks`; the only `tests/fixtures/*` landmarks are
  manifest files (`package.json`/`pyproject.toml`, contract-class) — a new `.sh` under
  `tests/fixtures/m6.5/` is NOT a manifest/hook/schema/workflow file, so it is NOT a landmark, and
  editing `bin/dmc` content changes no AGENTS.md-derived fact. The immediately-prior E-cycle
  EMPIRICALLY proved this exact class (it added `tests/install/test-run-start-arming.sh` + edited
  `bin/dmc` and verified `agents-md --stdout | diff - AGENTS.md` EMPTY + m8 manifest-drift green —
  `dmc-fable-core-e-build-20260710.md:34`: "agents-md drift empty; m8 manifest-drift 10/0"). Expectation: NEITHER
  artifact drifts; both are Allowed-to-Edit: no (Rev 3) — if a surprise drift ever appears, the
  response is HALT + a separate follow-up scope, never an in-lock edit (see Risks: G2 treats every
  lock row as a staging obligation).
  Source: `.claude/install/dmc-install.sh:60,111,140`, AGENTS.md section 4, `dmc-fable-core-e-build-20260710.md:34`.
- Finding F6 (comparison base = WORKING TREE, and no new V15-style flake): `test-manifest-drift.sh`
  compares against the ON-DISK committed `INSTALL_MANIFEST.md` (`$M8_MANIFEST`), NOT HEAD. The AGENTS.md
  drift suite must do the same (compare regen output vs the on-disk `AGENTS.md`) because the pin's
  purpose is "what is about to be committed matches its generator" — comparing to HEAD would wrongly
  fail a cycle that legitimately regenerates the artifact before commit. The suite must NOT read `git
  status` as a pass/fail signal (that is the frozen v0.6.0 V15 tree-coupling that makes a DIRTY tree
  read 801/4/3 — `bin/lib/dmc-v0.6.0-verify.sh:147-166`); it only compares file bytes and uses a
  before/after porcelain DELTA for hermeticity (a pre-existing dirty tree cannot fail it). Thus it adds
  NO second tree-coupling flake source.
  Source: `tests/fixtures/m8/test-manifest-drift.sh:33-36`, `bin/lib/dmc-v0.6.0-verify.sh:147-166`.
- Finding F7 (CI auto-covers the new suite; no workflow edit): CI runs `bin/dmc selftest m65-suite`
  as a BLOCKING step (`.github/workflows/dmc-ci.yml:172-173`) — it invokes `run_m65_suite`, which
  iterates the whole M6.5 script list, so a new script added to that loop is picked up with NO CI-file
  edit. The advisory `selftest --all` replay (`:191-194`, `continue-on-error`) also covers it.
  Source: `.github/workflows/dmc-ci.yml:172-173,191-194`.
- Finding F8 (root-basename coupling — caught by the AC-4 committed-replica leg): the generator titles
  AGENTS.md line 1 `# AGENTS.md — <root basename>` (`bin/lib/dmc-agents-md.py:173` "Repo identity — name
  is the directory basename"). A naive regen via `--root "$ROOT"` inherits the REAL checkout dir name, so
  the positive byte-compare FAILS in ANY checkout whose dir name != `DMC`. Evidence: a replica of the first
  built candidate (`8451cc0`, local-only) into a dir named `replica-v114` made `selftest --all` exit 1 with
  the sole failure `[FAIL] positive: committed AGENTS.md differs from regenerated (1c1;< # AGENTS.md — DMC)`.
  Consequence: the BLOCKING CI m65-suite step checks out the repo as `Do-Me-Coding` -> it would go RED on
  push; a live-tree run (dir `DMC`) can never see it. This is the environment-coupled-flake class the suite's
  own no-new-flake constraint targets — tree-decoupled (F6) but still ROOT-NAME-coupled. Fix (Proposed
  Changes): regenerate through a `$TMP/DMC` name-pinned working-tree copy, compare against the real on-disk
  `$COMMITTED`. That the committed-replica AC-4 leg surfaced this pre-push validates replica-based verification.
  Source: `bin/lib/dmc-agents-md.py:173`; replica-v114 `selftest --all` rc=1; `.github/workflows/dmc-ci.yml:172-173`.

## Relevant Files

| Path | Reason | Allowed to Edit |
|---|---|---|
| `tests/fixtures/m6.5/test-agents-md-drift.sh` | NEW standalone hermetic AGENTS.md committed==regen drift suite (positive byte-equality + deliberate-drift negative control + porcelain hermeticity), mirroring `test-manifest-drift.sh` | yes (new file) |
| `bin/dmc` | register `test-agents-md-drift.sh` in the `run_m65_suite` loop (line ~277); update the `selftest m65-suite` usage description (lines ~204-206) to name the new pin (in-file lockstep). Enforcement-class landmark -> non-degrading FLAG expected, landmark_authorized | yes |
| `docs/MILESTONES.md` | append ONE `## v1.1.4` entry (append-only; push-gate-pending line) | yes |
| `INSTALL_MANIFEST.md` | neutrality verified by the `--emit-manifest` diff (Verification Commands, EMPTY per F5); IF drift is ever observed, HALT and open a follow-up scope — do NOT edit under this lock | no |
| `AGENTS.md` | neutrality verified by the `agents-md --stdout` diff (Verification Commands, EMPTY per F5); IF drift is ever observed, HALT and open a follow-up scope — do NOT edit under this lock | no |
| `tests/fixtures/m8/test-manifest-drift.sh` | the existing INSTALL_MANIFEST pin — correct as-is; re-affirmed green, NOT edited | no |
| `bin/lib/dmc-agents-md.py`, `.claude/install/dmc-install.sh`, `bin/lib/dmc-legacy-selftest.py` (PINNED_BASELINE), frozen `dmc-v*` tools, hooks, schemas, `.github/workflows/dmc-ci.yml`, `tests/fixtures/m6.5/_m65common.sh` | generators / frozen surfaces / CI (auto-covers) / suite-common (new test is standalone) — byte-untouched | no |

## Out of Scope

- ANY edit to a generator (`dmc-agents-md.py`, `dmc-install.sh`) — this cycle adds a check, not a
  generator change. Both generators are byte-clean at baseline.
- ANY edit to `bin/lib/dmc-legacy-selftest.py` / `PINNED_BASELINE` — the legacy 802/3/3 aggregate is
  NOT touched and MUST stay EXACT (Constitution II.2 anti-masking).
- ANY edit to `tests/fixtures/m8/test-manifest-drift.sh` — the INSTALL_MANIFEST pin already exists and
  is correct; re-homing it (into a unified "generated-artifact drift" suite) is rejected as a larger,
  riskier refactor that would perturb the m8 suite + CI m8-suite step semantics (surgical-change
  discipline). Each drift test lives with its own generator's suite family.
- ANY edit to `.github/workflows/dmc-ci.yml` — the blocking `selftest m65-suite` step already
  iterates the whole M6.5 script list (F7); the new suite is auto-covered.
- Making `--emit-manifest`/`agents-md` regen MANDATORY at any lifecycle gate, or adding a
  pre-commit hook — out of scope; this is a selftest-time pin only.
- Push / CI / main merge (human gate).

## Proposed Changes

- Change: NEW `tests/fixtures/m6.5/test-agents-md-drift.sh` — a STANDALONE hermetic suite (mirror the
  `test-agents-md.sh` self-contained pattern, F4). It: resolves `ROOT=$SELF_DIR/../../..`,
  `DMC="$ROOT/bin/dmc"`, `COMMITTED="$ROOT/AGENTS.md"`; captures `PORCELAIN_BEFORE`; makes a mktemp
  workdir; then NAME-PINS the root (F8): copies the working tree to `$TMP/DMC` (`cp -R` INCLUDING
  `.git` so repo-intel's `git check-ignore` semantics survive) and regenerates via `"$DMC" agents-md
  --root "$TMP/DMC" --stdout` into `$TMP/regen.md` — the generator titles AGENTS.md line 1
  `# AGENTS.md — <root basename>` (`bin/lib/dmc-agents-md.py:173`), so regenerating from a `DMC`-named
  copy yields the committed `— DMC` title regardless of the real checkout dir name (CI checks out
  `Do-Me-Coding`). The copy exists ONLY to pin the basename; the byte-compare stays against the REAL
  on-disk `$COMMITTED` (working-tree semantics preserved — NOT a clone-of-HEAD, which would compare
  stale bytes and reintroduce tree coupling). Then:
  (1) POSITIVE — `cmp -s "$TMP/regen.md" "$COMMITTED"` PASS (committed == regenerated, byte-for-byte);
  (2) GUARD — `$COMMITTED` exists and is non-empty (so equality cannot be reached vacuously);
  (3) NEGATIVE deliberate-drift — copy `$COMMITTED` to `$TMP/tampered.md`, mutate ONE byte/line in the
  COPY, assert `cmp -s "$TMP/regen.md" "$TMP/tampered.md"` is NON-zero (the check has teeth: a
  one-byte AGENTS.md drift is DETECTED); (4) NEGATIVE section-delete — copy `$COMMITTED` to `$TMP/dropped.md`, delete
  a required `## N.` section from that COPY, and assert `cmp -s "$TMP/regen.md" "$TMP/dropped.md"`
  (REGEN OUTPUT vs the section-deleted COPY, NOT two tampered copies) still FAILS — because the
  generator re-emits all 10 sections, deletion cannot defeat the pin (mirrors
  `test-manifest-drift.sh:85-89`'s "cannot be defeated by deletion because the generator re-emits it"
  semantics); (5) HERMETIC — `git status --porcelain` of the real repo byte-identical
  before/after (all writes confined to mktemp; `$COMMITTED` is READ, never written). Prints
  `RESULT: $PASS PASS / $FAIL FAIL`; `exit 0` iff `FAIL==0`. Header documents: reads no sensitive
  files; no network/live/model/API call; no subprocess beyond `bin/dmc`, `git status --porcelain`, and
  coreutils in mktemp. Comparison base is the WORKING-TREE `AGENTS.md` (F6); the suite never branches
  on `git status` as a pass signal (no V15 coupling).
  Files: `tests/fixtures/m6.5/test-agents-md-drift.sh`.
  Rationale: closes the F2 gap with the established drift-test pattern; the negative control is the
  constraint-#7 deliberate-drift test, self-contained so the executor never has to mutate the real
  AGENTS.md.
- Change: `bin/dmc` — add `test-agents-md-drift.sh` to the `run_m65_suite` loop (`:277`, becomes
  `for s in test-codex-shims.sh test-skills-mirror.sh test-agents-md.sh test-agents-md-drift.sh; do`);
  update the `selftest m65-suite` usage prose (`:204-206`) to name the new committed-AGENTS.md
  regen-drift pin. No other dispatch change. This auto-wires the new suite into `selftest --all`
  (`:579 run_m65_suite`), the named `selftest m65-suite` (`:615`), AND the blocking CI m65-suite step.
  Files: `bin/dmc`.
  Rationale: single insertion point; reuses the guarded-loop pattern (a missing script is rc=1, so the
  pin cannot be silently skipped).
- Change: `docs/MILESTONES.md` — append ONE `## v1.1.4 — committed==regenerated selftest pins for the
  generated artifacts — LOCAL (2026-07-10)` entry: the D-core drift history, the honest scope
  (INSTALL_MANIFEST already pinned in m8; AGENTS.md pin added in m6.5), the new suite's assertion set,
  the "legacy 802/3/3 UNCHANGED" note, verification summary, and a `push/CI/main-FF: human gate` line.
  Files: `docs/MILESTONES.md`.
  Rationale: append-only milestone record; the only documentation touch (no 802/3/3 prose changes
  anywhere else — the number is unchanged).
- Change (contingency — NOT an in-lock edit): the neutrality diffs are expected EMPTY (F5). IF — against
  F5 — the post-change `--emit-manifest`/`agents-md --stdout` regen shows ANY drift, the response is to
  HALT and open a SEPARATE follow-up scope for the drifted artifact — NOT to edit it under this lock.
  Files: none in this lock (`INSTALL_MANIFEST.md`/`AGENTS.md` are Allowed-to-Edit: no).
  Rationale: G2 treats every scope.lock row as a staging obligation (see Risks), so a defensive
  "regenerate-IF-drift" row that legitimately does not fire is structurally incompatible with
  `gate release --full`; conditional-edit authorization therefore lives OUTSIDE the lock, and masking
  by editing the check is never allowed.

## Acceptance Criteria

- Criterion: AGENTS.md committed==regen pin is wired and GREEN (positive).
  Verification Method: `bin/dmc selftest m65-suite` runs `test-agents-md-drift.sh` and every RESULT
  line reports `0 FAIL`; the suite's assertion (1) "committed == regenerated (byte-for-byte)" PASSES;
  `bin/dmc selftest agents-md` (the generator self-test) still PASSES. Rename-decoupling: the suite
  PASSES from a clone/copy whose ROOT BASENAME != `DMC` (re-affirmed in a committed replica, e.g. a dir
  named `replica-v114`) — the `$TMP/DMC` name-pin makes the positive compare dir-name-independent (F8).
- Criterion: the pin has teeth (deliberate-drift NEGATIVE control, constraint #7).
  Verification Method: `test-agents-md-drift.sh`'s assertion (3) shows a one-byte mutation of a COPY of
  AGENTS.md is DETECTED (compare FAILS => recorded PASS "drift caught"), and assertion (4) shows the
  REGEN OUTPUT vs a section-deleted COPY still FAILS (the generator re-emits all 10 sections, so
  deletion cannot defeat the pin). The real repo `git status --porcelain` is byte-identical
  before/after the suite (assertion 5) — the negative controls never touch the tracked AGENTS.md.
- Criterion: INSTALL_MANIFEST committed==regen pin re-affirmed (already-existing).
  Verification Method: `bin/dmc selftest m8-suite` green; `tests/fixtures/m8/test-manifest-drift.sh`
  byte-equality assertion PASS (unchanged; not edited).
- Criterion: the legacy 802/3/3 aggregate is EXACT and UNCHANGED (no masking).
  Verification Method: clean-tree (post-commit or committed-replica; `.codex/config.toml` stashed per
  gotcha #4) `bin/dmc selftest --all` prints `aggregate: tools=49 PASS=802 FAIL=3 N/A=3`,
  `PASS aggregate == pinned baseline exactly`, `SELFTEST-ALL RESULT: PASS`, exit 0. `PINNED_BASELINE`
  in `dmc-legacy-selftest.py` is byte-untouched (not in the diff).
- Criterion: derived artifacts neutral (lockstep irony — this change touched bin/dmc + added a test).
  Verification Method: `bin/dmc agents-md --root . --stdout | diff - AGENTS.md` EMPTY;
  `bash .claude/install/dmc-install.sh --emit-manifest | diff - INSTALL_MANIFEST.md` EMPTY (i.e. the
  new drift suite passes on the real repo AND the manifest suite stays green). If either ever drifts, the
  cycle HALTS and opens a follow-up scope — the artifact is NOT regenerated under this lock.
- Criterion: CI path picks up the new pin with no workflow edit.
  Verification Method: read `.github/workflows/dmc-ci.yml` — the `selftest m65-suite` blocking step
  (`:172-173`) invokes `run_m65_suite`, which now iterates `test-agents-md-drift.sh`; `.github/` is NOT
  in the diff.
- Criterion: scope + gate + ceiling.
  Verification Method: the scope.lock contains EXACTLY the 3 candidate paths
  (`tests/fixtures/m6.5/test-agents-md-drift.sh`, `bin/dmc`, `docs/MILESTONES.md`) AND the staged set ==
  exactly those same 3 paths (G2 stages every lock row — no defensive/no-op rows); green set +
  `bin/dmc gate release --full --run-id <run>` PASS (non-degrading FLAG on `bin/dmc` expected; NO G4
  override — no protected path in scope); commits LOCAL only; `.codex/config.toml` unstaged; no push.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Adding a suite silently changes a pinned count and the green baseline drifts | medium | the ONLY code-enforced pin is legacy 802/3/3 (F3), which counts `dmc-v0.*` tools only; a new `tests/fixtures/m6.5/*.sh` is not a legacy tool -> aggregate UNCHANGED; AC pins `--all` to EXACT 802/3/3; `PINNED_BASELINE` out of scope |
| The new suite introduces an environment-coupled flake (dirty-tree OR checkout-dir-name -> false FAIL) | medium | TREE: compares regen bytes vs the on-disk `AGENTS.md`, never branches on `git status`; porcelain is a before/after DELTA only (F6); no `dmc-v0.6.0`-style scope classification. ROOT NAME: the generator titles AGENTS.md by the root basename (`dmc-agents-md.py:173`), so the suite NAME-PINS the root by regenerating from a `$TMP/DMC` copy — else it reddens any checkout dir != `DMC` incl. CI's `Do-Me-Coding` (F8, caught by the replica leg) |
| This change itself drifts INSTALL_MANIFEST.md or AGENTS.md (the defect class it fixes) | low | F5: manifest is name-based (no `tests/**`, content-agnostic), AGENTS.md landmarks are path+class (a `.sh` is not a landmark); E-cycle empirically proved the same class neutral; both artifacts are Allowed-to-Edit: no (Rev 3) — a drift response is HALT + follow-up scope, never an in-lock edit; the pin's own run is the detector |
| Executor armed-window Bash discipline (no redirects/`python3 -c`/`cp`/`sed -i`) vs the test's own shell | low | the COMMITTED test MAY use redirects/`cp`/heredocs in its own body (like `test-manifest-drift.sh` does); the EXECUTOR authors it via Write (not shell) and runs it via `bash …`/`bin/dmc selftest m65-suite` with NO redirects; the deliberate-drift mutation happens INSIDE the suite (mktemp), so the executor never mutates the tracked AGENTS.md by hand |
| Choosing m6.5 vs a unified drift suite fragments the invariant | low | documented in MILESTONES + this plan: each drift test lives with its generator's suite family (manifest->m8, agents-md->m6.5); re-homing the working manifest test is explicitly out of scope (surgical) |
| G2 treats every scope.lock row as a STAGING OBLIGATION, not mere authorization (Rev 3 learning) | medium | verified: `sg_gate_checks` builds G2's allowlist from ALL scope.lock `files[].path` (`bin/lib/dmc-release-gate.py:387-416`) and the v0.2.6 runner requires it FULLY staged (`bin/lib/dmc-v0.2.6-gate-check-runner.sh:47-50`); B/C-cycle locks are changed-files-only. Defensive/conditional rows are structurally incompatible with `gate release --full` -> conditional-edit authorization lives OUTSIDE the lock (Rev 3 dropped the two artifact rows to Allowed-to-Edit: no) |
| `agents-md --stdout` behaves differently under `--root .` vs an absolute root in the suite | low | the suite passes `--root "$ROOT"` (absolute, resolved from `$SELF_DIR`), matching how `test-agents-md.sh` drives the verb; baseline VERIFIED byte-clean this session with `--root .` |

## Assumptions

| Assumption | Confidence | How to Verify |
|---|---|---|
| `INSTALL_MANIFEST.md` committed==regen is already permanently pinned by `test-manifest-drift.sh` in m8-suite (so no new manifest code is needed) | verified (read `tests/fixtures/m8/test-manifest-drift.sh:31-50` + `bin/dmc:581` + CI `:178-179`) | re-run `bin/dmc selftest m8-suite`; read the byte-equality assertion |
| The legacy 802/3/3 aggregate counts only `dmc-v0.*` tools and a new m6.5 `.sh` does not alter it | verified (`dmc-legacy-selftest.py:118` PINNED_BASELINE + stray-guard `startswith('dmc-v0.')`; `dmc-metrics-recorder.py` precedent) | post-change clean-tree `--all` == 802/3/3 EXACT |
| A new `.sh` under `tests/fixtures/m6.5/` is neither shipped (manifest) nor a landmark (AGENTS.md), and editing `bin/dmc` content changes neither generated artifact | high (F5 + E-cycle empirical precedent) | executor runs the two `diff` commands post-change -> both EMPTY (also the new drift suite + m8 suite green) |
| CI's blocking `selftest m65-suite` step iterates the whole M6.5 dir, so the new script is auto-covered with no workflow edit | verified (`.github/workflows/dmc-ci.yml:172-173` -> `run_m65_suite` loop `bin/dmc:275-285`) | read the CI step; confirm `.github/` absent from the diff |
| Comparing against the working-tree `AGENTS.md` (not HEAD) is correct for the pin | high (matches `test-manifest-drift.sh` reading the on-disk committed manifest) | suite passes on the real byte-clean repo; negative control on a copy still FAILS |
| This cycle is covered by the standing fable-core envelope (registered follow-up item 1) | high (`dmc-fable-core-e-build-20260710.md` "Registered follow-ups"; MEMORY next-session register) | human gate confirms at critic/commit time |

## Execution Tasks

- [ ] DMC-T001: Author `tests/fixtures/m6.5/test-agents-md-drift.sh` (standalone, hermetic; the 5
  assertions in Proposed Changes) via Write. Run it directly (`bash
  tests/fixtures/m6.5/test-agents-md-drift.sh`) and confirm `RESULT: N PASS / 0 FAIL` with the
  positive byte-equality PASS AND the deliberate-drift negative control PASS. Verify the real repo
  `git status --porcelain` shows only the new untracked file (suite itself added nothing tracked).
  Files: `tests/fixtures/m6.5/test-agents-md-drift.sh`.
  Notes: Route: Opus 4.8, synchronous (correctness-critical hermetic test). Executor Bash: no
  redirects / `python3 -c` / `cp` / `sed -i` in the executor's OWN tool calls; the test body owns its
  shell constructs.
- [ ] DMC-T002: Register the suite in `bin/dmc` (`run_m65_suite` loop + `selftest m65-suite` usage
  prose). `bash -n bin/dmc`; run `bin/dmc selftest m65-suite` (all RESULT lines 0 FAIL, includes the
  new pin); run `bin/dmc selftest m8-suite` (INSTALL_MANIFEST pin re-affirmed); run `bin/dmc selftest
  agents-md`. Re-verify derived-artifact neutrality: `bin/dmc agents-md --root . --stdout | diff -
  AGENTS.md` EMPTY and `bash .claude/install/dmc-install.sh --emit-manifest | diff - INSTALL_MANIFEST.md`
  EMPTY (if either is non-empty -> HALT + open a follow-up scope; do NOT edit the artifact under this lock).
  Files: `bin/dmc` (no artifact edit under this lock — a drift => halt + follow-up scope).
  Notes: Route: Opus 4.8, synchronous; depends on T001.
- [ ] DMC-T003: Append the `docs/MILESTONES.md` v1.1.4 entry. Independent verification (fresh Opus
  lane) -> `.harness/verification/<run-id>.md` (own re-run of the drift suite incl. the negative
  control, own clean-tree `--all` 802/3/3 EXACT, own reading of the diff). Green set + `bin/dmc gate
  release --full --run-id <run>` PASS (stage the candidate FIRST — G2). Change commit + records commit
  (LOCAL; targeted `git add`; `.codex/config.toml` unstaged). Build evidence
  `.harness/evidence/dmc-fable-core-regen-pin-build-20260710.md`.
  Files: `docs/MILESTONES.md` (+ records, scope-exempt).
  Notes: Route: verifier Opus 4.8 fresh lane; commits by the orchestrator under the envelope grant;
  push/CI/main-FF remain a human gate.

## Verification Commands

| Command | Reason | Required |
|---|---|---|
| `bash tests/fixtures/m6.5/test-agents-md-drift.sh` | positive byte-equality + deliberate-drift negative control + porcelain hermeticity, standalone | yes |
| `bin/dmc selftest m65-suite` | the new pin is wired into the M6.5 suite (and thereby the blocking CI step) | yes |
| `bin/dmc selftest m8-suite` | INSTALL_MANIFEST committed==regen pin re-affirmed green (already-existing) | yes |
| `bin/dmc agents-md --root . --stdout \| diff - AGENTS.md` (EMPTY) | derived-artifact neutrality for AGENTS.md (and the pin passing on the real repo) | yes |
| `bash .claude/install/dmc-install.sh --emit-manifest \| diff - INSTALL_MANIFEST.md` (EMPTY) | derived-artifact neutrality for INSTALL_MANIFEST | yes |
| clean-tree `bin/dmc selftest --all` == `tools=49 PASS=802 FAIL=3 N/A=3` EXACT (post-commit / committed-replica, `.codex/config.toml` stashed) | legacy baseline unchanged (Constitution II.2, no masking) | yes |
| read `.github/workflows/dmc-ci.yml` `selftest m65-suite` step; confirm `.github/` absent from the diff | CI auto-covers the pin; no workflow edit | yes |
| `bin/dmc verdict gate` binds a schema-valid critic APPROVE to this plan's sha256 before build | critic-APPROVE-conditional envelope gate | yes |
| staged set == in-scope; green set + `bin/dmc gate release --full --run-id <run>` PASS (FLAG, no override); commits LOCAL; no push | gate + autonomy ceiling | yes |

## Approval Status

Status: APPROVED
Approver: human envelope gate (user directive 2026-07-10) + critic r1 APPROVE (dmc-fable-core-regen-pin-critic-r1.json)
Approved At: 2026-07-10

Notes: Planner (Fable 5, read-only planning lane) emits this DRAFT. It is NOT self-approved and opens
NO gate. The mandatory pre-build gate is a fresh-context critic (`/dmc-critic`) returning a
schema-valid APPROVE whose verdict binds THIS file's sha256 via `bin/dmc verdict gate`; the standing
fable-core envelope (critic-APPROVE-conditional, LOCAL-commit ceiling on `claude/dmc-fable-core`,
push/main a separate human gate, 2 consecutive critic REJECTs -> halt + report) governs execution.
Open questions for the critic are listed in the planner's handoff message.
Rev 2: folded critic r1's two advisory nits (F5 citation, section-delete regen-vs-copy semantics); approval flipped under the envelope; re-submitted for critic r2 hash re-bind.
Rev 3: first gate attempt honestly recorded G2 FAIL (approved-but-unstaged `AGENTS.md`/`INSTALL_MANIFEST.md`; release-readiness.json preserved in run `dmc-run-e8b6a347af41` — a superseding armed run re-gates); dropped the two defensive artifact rows to Allowed-to-Edit: no so the lock == exactly the 3 changed paths (conditional-edit authorization lives outside the lock); folded under the standing envelope; Status stays APPROVED (same authorization basis); re-submitted for critic r3 hash re-bind.
Rev 4: a REAL defect in the built candidate — the drift suite was ROOT-NAME-coupled (the generator titles AGENTS.md by the root basename; `dmc-agents-md.py:173`), so a replica under dir `replica-v114` failed the positive assertion and CI (checkout `Do-Me-Coding`) would have gone red on push — caught post-gate, pre-push by the AC-4 committed-replica leg. Fixed in-suite (name-pinned `$TMP/DMC` working-tree copy; generator stays out of scope; NOT a compare-minus-line-1 mask). Commit `8451cc0` (local-only, unpushed) will be AMENDED in place; a superseding armed run re-verifies + re-gates. Status stays APPROVED (same authorization basis, same 3-path lock); re-submitted for critic r4 hash re-bind.
