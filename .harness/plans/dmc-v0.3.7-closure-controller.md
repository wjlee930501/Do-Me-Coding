# Plan — dmc-v0.3.7 Closure Controller

Status: APPROVED
Approval Status: APPROVED
Mode: PLAN ONLY until APPROVED. **Additive, read-only** — judges signals + emits a candidate; writes/commits/pushes
nothing and modifies no protected surface.

## Goal
A **read-only** controller that **mechanically judges the 5 DMC closure conditions** for a milestone —
`verified · reviewed · committed · pushed · closure-recorded` — each from a concrete signal (MET / NOT-MET, fail-closed),
declares **E2E-DONE iff all 5 MET**, and emits an **append-only `docs/MILESTONES.md` closure-entry CANDIDATE**. It
**writes nothing** (the candidate is text for the human to apply), **commits/pushes nothing**, makes **no live call**, and
never reads/prints secret content.

## User Intent
v0.3.7 roadmap: "5개 closure 조건을 기계적으로 판정 … MILESTONES.md append-only 후보 … no commit/push." Turn the closure
judgment + the MILESTONES.md entry from hand-work into a deterministic, read-only tool.

## Current Repo Findings
- The 5 closure conditions are the handbook / v0.2.9 STOP definition (`docs/DMC_EFFORT_PROVIDER_POLICY.md:48`):
  verified · reviewed · committed · pushed · closure-recorded.
- Signals available read-only: the verification report (`Review-Verdict:` + `N PASS / M FAIL` + `## Final Status`) gives
  **verified** + **reviewed**; git metadata (`rev-parse --verify`, `merge-base --is-ancestor`, `rev-list --count`) gives
  **committed** + **pushed**; `docs/MILESTONES.md` (grep the milestone id) gives **closure-recorded**.
- `docs/MILESTONES.md` exists with entries **through v0.3.1**; v0.3.2–v0.3.6 are intentionally **not yet recorded** (their
  closures are deferred to post-batch-push) — so for those, `closure-recorded` is legitimately NOT-MET.
- Reuse the v0.3.6 names-only / secret-path discipline: the `--verify-report` path is guarded against secret patterns and
  read with metadata-only git (no content-dumping `show`/`diff`, no `-p`/`log -p`/`diff-tree`/`cat-file`).

## Relevant Files (all additive)
- `docs/DMC_CLOSURE_CONTROLLER.md` — the spec (the 5 conditions + their signals; append-only candidate; read-only).
- `.harness/evidence/dmc-v0.3.7-closure-controller.sh` — the controller (+ `--self-test`).
- `.harness/verification/dmc-v0.3.7-closure-controller.md` — verification report.
- `.harness/plans/dmc-v0.3.7-closure-controller.md` — this plan.

## Out of Scope (with rationale)
- **No write / no commit / no push** — the controller judges + emits a candidate; it never writes `MILESTONES.md`, never
  `git add/commit/push`. The MILESTONES.md candidate is **append-only text** (it never rewrites existing entries).
- **No gate grant** — advisory; E2E-DONE is a *judgment*, not an authorization. The human applies the entry + pushes.
- **No secret content** — the `--verify-report` path is refused unread if it matches a secret pattern; git is read with
  metadata-only primitives; no `.env*`/credential read.
- **No live call / no protected edit** — git-local + file reads only; read-only over all protected surfaces.

## Proposed Changes
### A. `.harness/evidence/dmc-v0.3.7-closure-controller.sh` (new; `--self-test`; `PYTHONDONTWRITEBYTECODE`)
CLI: `dmc-v0.3.7-closure-controller.sh --milestone <id> --commit <ref> --verify-report <path>
[--milestones-file <path>] [--repo <dir>] [--date <YYYY-MM-DD>] [--out <file>]` · `--self-test`. Pipeline (read-only):
1. **verified** — read `--verify-report` (secret-path-guarded, refused unread if secret): MET iff a `## Final Status`
   `**PASS**` marker AND a `[0-9]+ PASS / 0 FAIL` (or `N/N`) count are present **AND** the report contains **no** `**FAIL**`
   marker and **no** `[1-9][0-9]* FAIL` token anywhere (fail-closed: ANY `FAIL>0` anywhere ⇒ NOT-MET — presence-only is
   fail-OPEN on a mixed-count report); else NOT-MET.
2. **reviewed** — evaluate the **single anchored** Review-Verdict line: MET iff
   `grep -E '^Review-Verdict: critic=PASS codex=ACCEPT'` matches that one line; else NOT-MET. (A whole-file two-token
   check is fail-OPEN — narrative prose can mention an earlier `codex=ACCEPT` while the canonical line says
   `codex=REVISE`/`PENDING`; the anchored single-line match avoids it. Reviewed is sourced from the report only — a
   deliberate scope reduction from the v0.3.0 predecessor, which also required `^Status: APPROVED` in the plan.)
3. **committed** — `git -C <repo> rev-parse --verify <ref>^{commit}` resolves: MET; else NOT-MET. (No content read.)
4. **pushed** — `git -C <repo> merge-base --is-ancestor <ref> origin/main` exit 0: MET; if `origin/main` is absent or the
   commit is not an ancestor: NOT-MET (fail-closed). Verified against the **last-fetched local `origin/main`** (no fetch),
   so a remote that advances/rewinds after the last fetch is not reflected.
5. **closure-recorded** — **whole-token** match of the milestone id in `docs/MILESTONES.md` (default `--milestones-file`):
   e.g. `grep -qE '(^|[^0-9.])v0\.3\.7([^0-9]|$)'` (so `v0.3.7` does **not** match `v0.3.70`): MET; else NOT-MET.
6. **Judgment** — `E2E-DONE` iff all 5 MET; else `NOT DONE` + the list of unmet conditions.
7. **MILESTONES.md candidate (append-only)** — emit a markdown closure-entry candidate block (milestone, commit subject
   via `git show -s --format='%s' <ref>` — the `-s` summary form, **never** a bare content-dumping `git show`; the report's
   `Review-Verdict`; count; `--date`) **to append at the end** of `MILESTONES.md` — clearly labelled "CANDIDATE — apply by
   appending; the tool writes nothing." Never the commit body (`%b`).
8. **Emit** the per-condition MET/NOT-MET table + the judgment + the candidate (`--out` guarded, or stdout). Advisory exit:
   `0` E2E-DONE, `1` NOT DONE (informational — never wired to commit/push).

### B. `docs/DMC_CLOSURE_CONTROLLER.md`
The spec: the 5 conditions and their exact signals; fail-closed (ambiguous/absent ⇒ NOT-MET); E2E-DONE iff all 5; the
append-only candidate rule; the read-only/advisory/grants-no-gate + no-secret-content contract.

## Acceptance Criteria (measurable; `--self-test`, offline only; a FIXED $TMPDIR temp git repo)
- **AC1 read-only**: over the whole self-test, `git rev-parse HEAD` + branch + `md5(config --list)` + `status --porcelain`
  pre==post on BOTH the real repo AND the temp repo; `MILESTONES.md` byte-unchanged; the tool writes/commits/pushes
  **nothing**.
- **AC2 5-condition judgment correctness (pinned, both polarities + fail-OPEN negatives)**: in a temp repo with fixture
  verify-reports + a fixture MILESTONES.md, pin both polarities per condition AND the specific fail-OPEN vectors:
  - **verified**: `**PASS**` + `N PASS / 0 FAIL` ⇒ MET; a `**FAIL**`/`N FAIL>0` ⇒ NOT-MET; **mixed-count negative** — a
    report containing BOTH `5 PASS / 0 FAIL` AND `2 PASS / 3 FAIL` ⇒ **NOT-MET** (the presence-only fail-OPEN vector).
  - **reviewed**: anchored line `^Review-Verdict: critic=PASS codex=ACCEPT` ⇒ MET; `codex=PENDING` ⇒ NOT-MET;
    **prose-split negative** — the canonical line `Review-Verdict: critic=PASS codex=REVISE` WITH separate prose elsewhere
    containing `codex=ACCEPT` ⇒ **NOT-MET** (the whole-file substring fail-OPEN vector).
  - **committed**: a real ref ⇒ MET; a bogus ref ⇒ NOT-MET.
  - **pushed**: a commit that is an ancestor of the temp repo's `origin/main` ⇒ MET; a non-ancestor / no `origin/main` ⇒
    NOT-MET.
  - **closure-recorded**: whole-token id present ⇒ MET; absent ⇒ NOT-MET; **prefix-collision negative** — a MILESTONES.md
    whose ONLY matching line is `v0.3.70` ⇒ closure-recorded for `v0.3.7` **NOT-MET** (a naive `grep -q` substring impl
    FAILS this).
- **AC3 E2E-DONE iff all 5**: all-MET fixture ⇒ "E2E-DONE" + advisory exit 0; any-unmet fixture ⇒ "NOT DONE" + the unmet
  list + advisory exit 1. The all-MET temp repo manufactures a **MET `pushed`** by creating an `origin/main` ref (e.g.
  `git update-ref refs/remotes/origin/main <commit>`) of which the fixture commit is an ancestor — NOT relying on the real
  repo's `origin/main`.
- **AC4 append-only candidate**: the emitted candidate is a closure-entry block labelled CANDIDATE/append-only; the
  controller never writes/modifies `MILESTONES.md` (byte-unchanged), never rewrites existing entries, and the candidate
  contains the milestone + commit subject + Review-Verdict (set-membership). **Body sentinel**: a fixture commit whose
  body carries a sentinel ⇒ the sentinel **never** appears in the candidate (`%b` never emitted — mirrors v0.3.6).
- **AC5 fail-closed**: absent/secret-pathed `--verify-report` ⇒ verified+reviewed NOT-MET (refused unread if secret);
  absent `origin/main` ⇒ pushed NOT-MET; absent MILESTONES.md ⇒ closure-recorded NOT-MET; bogus `--commit` ⇒ committed
  NOT-MET. Ambiguity ⇒ NOT-MET (never a false E2E-DONE).
- **AC6 `--out` guard**: refuses protected/secret/traversal(incl benign-resolving `..`)/symlink targets; benign allowed
  (reuse the v0.3.5/v0.3.6 hardened guard).
- **AC7 no secret content**: the `--verify-report` secret-path guard + metadata-only git; a structural audit (its own
  block excluded from the scan, like v0.3.6) that **FAILs** on the same enumerated forbidden primitives as v0.3.6 —
  `format-patch|cat-file|diff-tree`, `(show|log|diff) … -p|--patch`, a bare `git show <ref>` without
  `-s`/`--name-status`/`--name-only`/`--stat`/`--numstat`, lowercase `%b`, and any credential-var read; gate-check green;
  critic + Codex audit → ACCEPT.

## Risks (+ mitigations)
- **R1 false E2E-DONE** (the gravest — would imply done when it isn't) → every condition fail-closed (ambiguous/absent ⇒
  NOT-MET); AC2 pins both polarities; AC3 asserts E2E-DONE iff all 5; AC5 asserts ambiguity never yields E2E-DONE.
- **R2 accidental write/commit/push** → AC1 (rev-parse/branch/config/porcelain pre==post both repos + MILESTONES.md
  byte-unchanged); the tool emits a CANDIDATE only, never `git add/commit/push`, never writes MILESTONES.md.
- **R3 secret leak** → reuse v0.3.6: `--verify-report` secret-path-guarded (refused unread), metadata-only git, no `%b`;
  the structural audit forbids content-dumping primitives.
- **R4 stale closure-recorded match** → grep the milestone id as a **whole token** via the pinned form
  `grep -qE '(^|[^0-9.])v0\.3\.7([^0-9]|$)'` (derived from the `--milestone` id) to avoid the prefix false-positive
  (`v0.3.7` must not match `v0.3.70`); AC2's closure-recorded **prefix-collision negative** fixture proves it.

## Assumptions
- A milestone is closed against a specific commit (`--commit`) with a verification report following the
  `Review-Verdict`/`N PASS / M FAIL`/`## Final Status` convention.
- The self-test temp repo uses pinned author/committer dates; candidate-content assertions use set-membership; the
  `pushed=MET` leg is manufactured in the temp repo via a local `refs/remotes/origin/main` ref (not the real origin/main).
- `pushed` is judged against the **last-fetched local `origin/main`** (the controller never fetches).

## Execution Tasks (after APPROVED)
1. Author `dmc-v0.3.7-closure-controller.sh` (pipeline A1–A8; metadata-only git; `--verify-report` secret-path guard;
   append-only candidate; `--out` hardened guard; whole-token id match; `--self-test` with a fixed temp repo + fixture
   report/MILESTONES.md; PYTHONDONTWRITEBYTECODE).
2. Author `docs/DMC_CLOSURE_CONTROLLER.md` (change B).
3. Run `--self-test` → all PASS (AC2 both polarities; AC3 E2E gate; AC5 fail-closed; AC1 read-only both repos +
   MILESTONES.md unchanged); write the verification report; gate-check; critic; Codex audit; commit on ACCEPT; **no push**.

## Verification Commands
- `bash .harness/evidence/dmc-v0.3.7-closure-controller.sh --self-test`
- a functional run against a committed milestone (e.g. `--milestone dmc-v0.3.6 --commit 4e2c3e7 --verify-report …`) to
  eyeball the judgment (expect pushed=NOT-MET while the stack is unpushed)
- `git status --porcelain` (expect only additive untracked + excluded auto-log); gate-check; then Codex audit.

## Approval Status
**DRAFT (rev 2)** — round-1 panel: no-write/append-only/no-secret **PASS**; closure-judgment **REVISE** + falsifiability
**REVISE**. REQUIRED applied (all confirmed against the real v0.3.6 report): (1) **verified** now requires
FAIL-absence anywhere (closes the mixed-count fail-OPEN ⇒ false E2E-DONE); (2) **reviewed** binds to the single anchored
`^Review-Verdict: critic=PASS codex=ACCEPT` line (closes the prose-split fail-OPEN); (3) **closure-recorded** uses a
**whole-token** id match + an AC2 `v0.3.70` prefix-collision negative; (4) AC2 now pins both polarities + the two
fail-OPEN negatives; (5) AC3 manufactures `pushed=MET` via a temp `origin/main`; (6) AC4 adds a commit-body sentinel;
(7) AC7 enumerates the v0.3.6 forbidden-primitive set; (8) named the `%s` subject as the `-s` summary form; corrected the
v0.3.1-recorded fact. **Round-2 focused re-pass: PASS** (zero remaining_required, zero new_defects;
all three fail-OPEN closures verified against the real v0.3.6 report; the FAIL-absence false-FAIL probe confirmed no
misjudgment — the over-strict edge is fail-closed and endorsed). Next: `/dmc-start-work`. Additive/read-only; no
provider-surface change.
