# Plan — dmc-v0.3.9 E2E Dry-Run Acceptance Suite

Status: APPROVED
Approval Status: APPROVED
Mode: PLAN ONLY until APPROVED. **Additive, read-only** — drives the rails loop in a dry-run; modifies no protected
surface and performs no gated action.

## Goal
A **read-only E2E acceptance suite** that drives the **entire DMC rails loop** end-to-end in a single **offline dry-run**:
task-intake (v0.2.8) → provider selection (v0.3.4) → execution manifest (v0.3.5) → review packet (v0.3.6) → closure
judgment (v0.3.7) → delegation compliance (v0.3.8), plus the gate-check (v0.2.6). It asserts each stage produces the
expected output, that the stages **compose** (the selector's rank-1 candidate is the manifest's proposed target), and that
every rails tool's `--self-test` is green — with **NO live call, NO network, NO commit/push, NO real-repo mutation, NO
secret content**, and **no false-green** (a broken rail turns the suite red).

## User Intent
v0.3.9 roadmap: "full DMC loop dry-run, no live call, no commit/push." The capstone acceptance: prove the whole read-only
rails loop composes and stays safe, end-to-end, in one offline run.

## Current Repo Findings
- The committed rails tools (all read-only, each ending `self_test; exit $?` so a failed self-test exits non-zero):
  `dmc-v0.2.6-gate-check-runner.sh`, `dmc-v0.2.8-task-intake-classifier.sh`, `dmc-v0.3.4-provider-selector.sh`,
  `dmc-v0.3.5-execution-manifest.sh`, `dmc-v0.3.6-review-packet.sh`, `dmc-v0.3.7-closure-controller.sh`,
  `dmc-v0.3.8-delegation-harness.sh`.
- **CLI shapes (verified):** classifier `--task "<desc-string>"`; selector/manifest `--task <task.json>` (a FILE);
  review-packet `--commit/--staged --repo --verify-report`; closure-controller `--milestone/--commit/--verify-report/
  --milestones-file/--repo`; delegation-harness `--milestone/--plan/--verify-report/--commit/--repo`.
- **`--repo` default is `ROOTDIR` (the REAL repo)** for review/closure/delegation — the suite MUST pass
  `--repo <$TMPDIR-repo>` on those stages or they read the real repo (breaking isolation/determinism).
- **closure-controller exits 1 when not E2E-DONE**; a bare `$TMPDIR` commit has no `origin/main`. The suite uses a temp
  repo with `origin/main` **behind HEAD** (present, not an ancestor of HEAD) ⇒ closure `pushed=NOT-MET` (assert on the
  emitted 5-condition table + candidate, **not** the exit code) AND delegation `push=DEFERRED` (compliant) — one shared
  repo state satisfies both stages despite their inverted push polarity.
- **Masked-failure caution:** the manifest swallows a broken selector's non-zero exit (`if bash "$SELECTOR" … ; then …
  else selfile=""`) and exits 0; so the compose stage must assert the **positive** invariant, not the manifest exit code.
- Reuse the v0.3.6/v0.3.7 names-only / secret-path discipline, the AUDIT_BLOCK-self-excluded structural audit, and the
  `--out` hardened guard.

## Relevant Files (all additive)
- `docs/DMC_E2E_DRY_RUN.md` — the acceptance-suite spec (the loop stages; the dry-run/no-action contract).
- `.harness/evidence/dmc-v0.3.9-e2e-dry-run.sh` — the E2E acceptance suite (+ `--self-test`).
- `.harness/verification/dmc-v0.3.9-e2e-dry-run.md` — verification report.
- `.harness/plans/dmc-v0.3.9-e2e-dry-run.md` — this plan.

## Out of Scope (with rationale)
- **No live call / no network** — invokes only the read-only rails tools in their offline modes; emits no
  `--live`/`--allow-network`/`--allow-exec`; REGRESSION re-runs each tool's own no-live chokepoint self-test.
- **No commit / no push / no mutation** — performs no gated action; the real repo is byte-unchanged across the whole
  suite; all git writes land in a `$TMPDIR` temp repo.
- **No secret content** — only synthetic non-secret fixtures; the composed tools' secret-path guards stay in force;
  metadata-only git.
- **No new capability / no protected edit** — read-only over all composed tools; re-runs their self-tests, modifies none.

## Proposed Changes
### A. `.harness/evidence/dmc-v0.3.9-e2e-dry-run.sh` (new; `--self-test`; `PYTHONDONTWRITEBYTECODE`; **no `set -e`** — an
explicit `STAGE_FAIL` counter drives the exit, never an implicit `set -e` or `|| true`)
CLI: `dmc-v0.3.9-e2e-dry-run.sh [--repo <dir>] [--out <file>]` · `--self-test`. Stages (read-only; offline; `$TMPDIR`
fixtures; each records pass/fail into `STAGE_FAIL`):
0. **PRESENCE** — assert each of the 7 tool paths EXISTS + is readable; a missing/absent tool is a **hard FAIL** (never a
   skip-pass).
1. **REGRESSION** — for each of the 7 tools, run `bash <tool> --self-test`, **capture its exit code into a per-tool rc**,
   and AND them; **any non-zero ⇒ REGRESSION FAIL** (no `|| true`, no discarded-rc command substitution).
2. **INTAKE** — run the classifier on the synthetic task's `objective` string; assert dimensions + `stop_and_ask=false`
   for a docs-only task.
3. **SELECT** — run the selector on the synthetic `task.json`; assert 3 ranked candidates, `manual_import` rank 1, not
   `fail_closed`.
4. **MANIFEST (compose)** — run the manifest on the same `task.json`; assert the **positive compose invariant**:
   `proposed_provider_target` is non-null, **NOT `fail_closed`**, and its `(type,provider)` **equals the selector's rank-1
   candidate**; `selected_adapter` ends with the manual-import adapter; all 5 `closure_criteria` present. (A swallowed
   selector failure ⇒ proposed=null ⇒ this assertion FAILs — the masked-failure path is closed.)
5. **REVIEW** — build a `$TMPDIR` temp-repo clean commit; run review-packet `--repo <tmp> --commit HEAD --verify-report
   <synthetic>`; assert the 5 sections + `forbidden = none`.
6. **CLOSURE** — run closure-controller `--repo <tmp> --milestone … --commit HEAD --verify-report <synthetic>
   --milestones-file <synthetic>`; assert (on the **emitted output**, not the exit code) the 5-condition table + the
   append-only candidate block.
7. **DELEGATION** — run delegation-harness `--repo <tmp> --milestone … --plan <APPROVED-fixture> --verify-report
   <synthetic> --commit HEAD`; assert **AUTONOMY-COMPLIANT** (push `DEFERRED`, since `origin/main` is behind HEAD).
8. **SAFETY** — assert (a) the **real repo is byte-unchanged** (HEAD + branch + `md5(config --list)` + `status
   --porcelain`) — the POST snapshot taken **after** all stages incl. the `--out` write; this is itself a FAIL-able stage;
   (b) a structural self-audit (operative-source-only, AUDIT_BLOCK self-excluded) forbids the suite emitting
   `--live`/`--allow-network`/`--allow-exec` and forbids `git (add|commit|push)` outside the `$TMPDIR` helper.
9. **Emit** the acceptance report (stage table + the compose assertion + the safety attestation; `--out` guarded, or
   stdout). Exit `0` iff `STAGE_FAIL == 0`, else `1`.

### B. `docs/DMC_E2E_DRY_RUN.md`
The acceptance-suite spec: the loop stages; the **compose** assertion (select → manifest); the
**dry-run / no-live / no-commit-push / no-mutation / no-secret / no-false-green** contract; how to read the report.

## Acceptance Criteria (measurable; `--self-test`, offline only)
- **AC1 read-only / no mutation (fail-able)**: the real repo is byte-unchanged (HEAD + branch + `md5(config --list)` +
  `status --porcelain` pre==post) across the **whole** suite, the POST snapshot **after** the `--out` write; this check is
  a FAIL-able stage that contributes to the exit code. All git writes are confined to `$TMPDIR`.
- **AC2 all stages pass (the loop composes)**: PRESENCE + REGRESSION (7 tools self-test exit 0, per-tool rc AND'd) +
  INTAKE + SELECT + MANIFEST + REVIEW + CLOSURE + DELEGATION all PASS; the **compose** invariant holds — the selector's
  rank-1 `(type,provider)` equals the manifest's `proposed_provider_target`, which is non-null and not `fail_closed`.
- **AC3 no live call / no network (two layers)**: (1) a structural **operative-source-only** self-audit (AUDIT_BLOCK
  self-excluded, comment-stripped) asserts the suite emits **no** `--live`/`--allow-network`/`--allow-exec`; (2) every
  composed invocation is named with its **offline mode**, and REGRESSION re-runs the v0.3.4/v0.3.5 tools' own no-live
  argv-chokepoint self-tests — so no stage can smuggle a live flag.
- **AC4 no false-green (fail-propagation, falsifiable by negative meta-fixtures)**: (a) a stub tool whose `--self-test`
  exits non-zero turns REGRESSION red + the suite exits 1; (b) a manifest JSON with `proposed_provider_target=null` (or
  `≠` the selector's rank-1) **fails** the compose assertion. Both negatives are exercised in the self-test, proving a
  broken rail cannot yield a green suite; the suite uses no `|| true`/`|| :`/discarded-rc around any composed invocation
  (asserted by the structural self-audit).
- **AC5 no secret content (enumerated + self-excluded)**: only synthetic non-secret fixtures; the composed tools'
  secret-path guards remain in force; a structural audit — **its own block excluded from the scan (comment-stripped,
  operative-source-only) so the pattern strings do not self-match**, exactly as v0.3.6:216-219 / v0.3.7:216 — FAILs on the
  v0.3.7 enumerated set (`format-patch|cat-file|diff-tree`, `(show|log|diff) … -p|--patch`, a bare `git show <ref>`
  without `-s`/`--name-status`/`--name-only`/`--stat`/`--numstat`, lowercase `%b`, credential-var read).
- **AC6 `--out` guard**: refuses protected/secret/traversal(incl benign-resolving `..`)/symlink targets; benign allowed
  (reuse the hardened guard).
- **AC7**: gate-check green (additive; no protected change); critic + Codex audit → ACCEPT before commit.

## Risks (+ mitigations)
- **R1 false-green acceptance (the gravest)** → AC4: REGRESSION captures + ANDs per-tool rc (no masking); the MANIFEST
  stage asserts the **positive** compose invariant (not the swallow-and-exit-0 manifest rc); two negative meta-fixtures
  (broken self-test + null proposed-target) prove the suite's detection logic FAILs on a red rail; `STAGE_FAIL` drives the
  exit (no `set -e`/`|| true`); a missing tool is a hard FAIL (PRESENCE).
- **R2 accidental live call / mutation** → AC1 real-repo byte-unchanged (POST after the `--out` write); AC3 two-layer
  no-live (source audit + composed-tool chokepoint); all git writes under `$TMPDIR`; the structural audit forbids
  `git (add|commit|push)` outside the temp helper.
- **R3 secret leak** → only synthetic non-secret fixtures; composed tools' secret-path guards in force; AC5 enumerated +
  **self-excluded** structural audit; metadata-only git.
- **R4 brittle composition** → the compose invariant is structural (selector rank-1 == manifest proposed target), reusing
  each tool's already-verified JSON; REGRESSION re-runs the tools' self-tests; the temp repo's `origin/main`-behind-HEAD
  state satisfies both closure (assert-on-output) and delegation (DEFERRED) despite their inverted push polarity.

## Assumptions
- The committed rails tools (v0.2.6/v0.2.8/v0.3.4–v0.3.8) are present and self-test-green.
- The synthetic task bundle is `{objective, context_summary, task_id}`; all fixtures + temp repos are created in
  `$TMPDIR`.

## Execution Tasks (after APPROVED)
1. Author `dmc-v0.3.9-e2e-dry-run.sh` (stages 0–9; `STAGE_FAIL` counter, no `set -e`/`|| true`; `--repo <tmp>` on
   stages 5/6/7; positive compose invariant; closure asserted on output; `origin/main`-behind-HEAD temp repo; AC4 two
   negative meta-fixtures; `--out` hardened guard; operative-source-only no-live + no-secret + no-git-write structural
   audits; `--self-test`; PYTHONDONTWRITEBYTECODE).
2. Author `docs/DMC_E2E_DRY_RUN.md` (change B).
3. Run `--self-test` → all stages PASS (AC2 compose; AC4 fail-propagation negatives; AC1 real-repo-unchanged; AC3/AC5
   self-excluded audits); write the verification report; gate-check; critic; Codex audit. Commit only under the recorded
   standing delegation (a Codex ACCEPT is a precondition, not the grant); **no push**.

## Approval Status
**APPROVED (rev 2)** — round-1 panel: compose-correctness **PASS** (all CLIs verified against the real parsers; compose
assertion sound); fail-propagation **REVISE** + safety **REVISE**. REQUIRED applied: (1) **masked-failure closed** — the
MANIFEST stage asserts the **positive** compose invariant (proposed non-null, not fail_closed, == selector rank-1), not
the swallow-and-exit-0 manifest rc; (2) REGRESSION captures + ANDs per-tool rc; (3) **no `set -e`** + a `STAGE_FAIL`
counter; (4) AC4 two **negative meta-fixtures** (broken self-test ⇒ REGRESSION red; null proposed-target ⇒ compose FAIL);
(5) AC3/AC5 audits made **operative-source-only / AUDIT_BLOCK self-excluded**; AC3 two-layer; (6) wiring: `--repo <tmp>`
on stages 5/6/7, closure asserted on **output**, `origin/main`-behind-HEAD so closure + delegation both pass. **Round-2
focused re-pass: PASS** (zero remaining_required; two minor implementation cautions — synthetic verify-report carries
critic=PASS/codex=ACCEPT + passing-count, plan fixture carries APPROVED, AC4 stub written to `$TMPDIR` — folded into the
implementation). Next: `/dmc-start-work`. Additive/read-only; no provider-surface change.
