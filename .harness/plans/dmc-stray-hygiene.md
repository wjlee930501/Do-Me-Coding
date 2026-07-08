# Plan — Stray-file hygiene execution (the B8 "separately-approved cleanup milestone")

Work ID: dmc-stray-hygiene
Rev: 3 (r1 REJECT → BL-INVENTORY/BL-AC1 fixed; r2 REJECT → BL-R2-AC1-SELF residual class (g) added,
BL-R2-G4-WORDING corrected to the machine-verified flag mechanism; r2 advisories D6/row-split/D5-nit folded)

## Goal

Execute the stray-file hygiene proposal drafted at `.harness/evidence/dmc-v1-m10-build-20260708.md:76-93`
(categories 1 and 3; category 2 `.before-dmc` trees stay KEEP per Constitution II.7): remove the six
tracked stray files — five v0.1-bootstrap doc/zip artifacts plus `dmc-glm-smoke`, the retired v0.2.1
live GLM smoke runner (5275-byte executable; NOT a v0.1 artifact) — with their required companion
edits, extend the DMC repo's own `.gitignore` so per-run auto-logs can never be captured by
`git add -A`, and delete the three orphaned local run notes. This is the "future, separately-approved
cleanup milestone" that audit-blocker B8 (`.harness/verification/dmc-v1-runtime-upgrade.md:67`) and M10
(`.harness/plans/dmc-v1-m10-final-docs.md:175-176`) explicitly reserved — this plan plus its human gate
exercises that reserved approval.

## User Intent

cleanup

The user selected the hygiene item from the rev 10 deferred register (2026-07-08 AskUserQuestion,
"잡파일 위생 실행 (빠른 안건)"). Constitution Art. III applies in full: plan → critic → human gate →
scope.lock → execute → verify → evidence.

## Current Repo Findings

(10-scout read-only workflow, 2026-07-08; full structured verdicts in the session workflow journal)

- Finding: All 6 category-1 candidates are git-tracked. `do-me-coding-v0.1-scaffold.zip` (41KB) is
  ALREADY in `.gitignore` (line 4) yet still tracked — gitignore never untracks.
  Source: `git ls-files` + `.gitignore:4`.
- Finding: `_DMC_CODEX_IMPLEMENT_FROM_SCRATCH_PROMPT.md`, `_DMC_CODEX_PROMPT_AFTER_UNZIP.md`,
  `_DMC_IMPORT_GUIDE.md`, `_DMC_MANIFEST.md`, `do-me-coding-v0.1-scaffold.zip` have ZERO functional
  references: no hit in `bin/`, `tests/`, `.claude/install/*.sh` (beyond a static heredoc prose line),
  `.github/workflows/dmc-ci.yml`, `AGENTS.md`, or the linkcheck 24-file scanned set. All remaining
  hits are historical prose in `.harness/` records (frozen; never edited) plus cross-references among
  the strays themselves.
  Source: per-candidate `git grep -F` scans; `bin/lib/dmc-orchestration-linkcheck.py:218-227`.
- Finding: `dmc-glm-smoke` is LOAD-BEARING in current (non-frozen) code:
  `bin/lib/dmc-repo-intel.py:278` hardcodes `rel == "dmc-glm-smoke"` in `classify_landmark()`
  ("enforcement" bucket) and `:614` asserts `L1f self-scan: dmc-glm-smoke in protected union` against
  a LIVE `os.walk` of the repo. Bare `git rm dmc-glm-smoke` flips `dmc selftest landmarks` (in the
  default no-arg selftest set AND `--all`) from green to 1 FAIL.
  Source: `bin/lib/dmc-repo-intel.py:278,614`; live `bin/dmc selftest landmarks` run.
- Finding: ~20 frozen `dmc-v0.2.x–v0.4.x` verify scripts name `dmc-glm-smoke` only inside
  `PROT_RE`/git-diff pathspecs (uncommitted-mutation detectors). They inspect `git diff`, not file
  existence — after a COMMITTED removal on a clean tree they cannot fail retroactively. Pre-commit
  live-tree runs would see the in-flight deletion; verification therefore uses the established
  committed-replica + post-commit-live recipe (M9/M10 pattern).
  Source: `bin/lib/dmc-v0.2.1.1-verify.sh:100` + shared PROT_RE across the series.
- Finding: The committed `AGENTS.md` lists `dmc-glm-smoke — enforcement` in its §4 landmarks list.
  The generator (`bin/lib/dmc-agents-md.py`) derives everything live from `dmc orient`/`dmc landmarks`
  subprocess calls; no automated check catches a stale committed copy — regeneration after removal is
  mandatory-by-plan, not gate-enforced. Known regression class: a prior regen dropped the §7
  companion-context pointers and only the frozen v0.4.7 AC6 audit caught it.
  Source: `AGENTS.md` §4; `bin/lib/dmc-agents-md.py:38-39`; handoff rev 9 (AC6 catch).
- Finding: The two proposed `.gitignore` patterns match ZERO tracked files (`git ls-files` empty for
  both; `.harness/runs/` tracks only `.gitkeep`), and the producers are live wired-in machinery
  (`.claude/hooks/evidence-log.sh` PostToolUse hook → `.harness/evidence/$RUN_ID.md`;
  `bin/lib/dmc-run-lifecycle.py` `mint_run_id()` → `.harness/runs/dmc-run-<hex12>/`), so the ignore is
  durable policy per `docs/HOST_REPO_ARTIFACT_POLICY.md`. No gate reads these paths from git: all
  consumers use disk `open()`, and `dmc-release-gate.py`/`dmc-verify-crosscheck.py` already hardcode
  `EXEMPT_PREFIXES = ('.harness/evidence/', '.harness/verification/', '.harness/runs/')`.
  Source: gitignore-patterns scout; `.claude/settings.json:44`; `bin/lib/dmc-run-lifecycle.py:182-185`.
- Finding: The installer's host `.gitignore` block (`print_gitignore_block()`,
  `.claude/install/dmc-install.sh:64-86`) already ignores `.harness/evidence/` and `.harness/runs/`
  WHOLESALE for hosts and is a manifest-drift-tested generated surface — no parity edit is needed or
  wanted there.
  Source: `.claude/install/dmc-install.sh:64-86`; `tests/fixtures/m8/test-manifest-drift.sh`.
- Finding: The 3 orphan notes `.harness/runs/dmc-v1-m{3,4,5}-20260706.md` are untracked pre-M4-era
  run-state records whose every fact (commits, per-task self-test counts, scope lists, model routing,
  verifier verdicts, open risks) is line-by-line duplicated in tracked surfaces (`docs/MILESTONES.md`,
  handoff, tracked `.harness/evidence/dmc-v1-m{3,4,5}-*.md`, tracked
  `.harness/verification/dmc-v1-m{3,4,5}-*.md`). Handoff Carry-forward 6 records the local-only policy
  they violate by lingering. Neither proposed gitignore pattern covers them (basename mismatch).
  Source: orphan-content scout line-by-line cross-check.
- Finding: `_DMC_IMPORT_GUIDE.md:16` documents `unzip do-me-coding-v0.1-scaffold.zip -d .` and `:28`
  points at `_DMC_CODEX_PROMPT_AFTER_UNZIP.md` — keeping the guide while removing its targets leaves
  dangling instructions; the four `_DMC_*.md` + zip form one referential cluster.
  Source: `_DMC_IMPORT_GUIDE.md:16,28`; `_DMC_MANIFEST.md:34-35`.
- Finding: `INSTALL_MANIFEST.md:289` / `.claude/install/dmc-install.sh:190` mention `_DMC_*.md` only
  as static heredoc prose under "DELIBERATELY NOT COPIED" — a policy statement that stays true (and
  byte-stable for the drift test) whether or not any matching file exists. Deliberate NO-EDIT.
  Source: `tests/fixtures/m8/test-manifest-drift.sh` (byte-equality only; no existence checks).
- Finding (critic r1 BL-INVENTORY; orchestrator re-verified by whole-tree grep): after removal,
  `dmc-glm-smoke` remains referenced on these NON-frozen surfaces, every one inert w.r.t. file
  existence — DISCLOSED RESIDUALS, deliberate NO-EDIT:
  (a) `.claude/workers/providers/PROVIDER_CONTRACT.md:28` (C5b prose: glm-api live-timeout "covered
  by dmc-glm-smoke" — historical capability note) and `:32` (C9: protected-file non-mutation list —
  `git diff` over a nonexistent path is empty; check stays green);
  (b) `.claude/workers/providers/manual-import/manual-import-adapter.py:92` — `PROT_RE` regex matched
  against changed-path INPUT, never against the filesystem;
  (c) 7 `docs/*.md` prose mentions (`DMC_GATE_CHECKS.md:50`, `DMC_PROVIDER_SELECTION.md:15`,
  `DMC_RUN_MANIFEST.md:26`, `DMC_EFFORT_PROVIDER_POLICY.md:10`, `DYNAMIC_WORKFLOW.md:20`,
  `FABLE_WORKFLOW_TRANSFER.md:59`, `REVIEW_PACKET_V2.md`) — all describe protected-path LISTS or
  historical milestone facts; several mirror the frozen v0.2.6 runner's default `DMC_GATE_PROTECTED`
  value, which VI.2 forbids "correcting" in prose;
  (d) `docs/MILESTONES.md` historical entries (I.3 immutable);
  (e) ~25 frozen `bin/lib/dmc-v0.*` PROT_RE/pathspec listings (II.1 — untouchable, inert by design);
  (f) `AGENTS.md:207,224` — the ONLY existence-derived surface; handled by the DMC-T003 regeneration;
  (g) THIS CYCLE'S OWN governance artifacts — this plan, the critic verdicts
  `.harness/evidence/dmc-stray-hygiene-critic-r*.json`, the verification report, and the closure
  evidence — which name `dmc-glm-smoke` by necessity and are committed per established practice
  (critic r2 BL-R2-AC1-SELF).
  Rationale for NO-EDIT of (a)–(e): a stale entry in a protective LIST is harmless (it can only
  over-protect), while trimming protective lists would weaken guard surfaces for zero functional gain.
  Source: `git grep -nF dmc-glm-smoke` whole tree, 2026-07-08; critic r1/r2 verdict artifacts.
- Finding (orchestrator, post-r1): the frozen v0.2.6 gate-check runner's DEFAULT protected list
  includes `dmc-glm-smoke` (`docs/DMC_RUN_MANIFEST.md:26`; `bin/lib/dmc-v0.2.6-gate-check-runner.sh:21,37`),
  so this run's deletion diff WILL trip the G4 protected-path check — the same collision class as
  v1.0.1's authorized `.claude/hooks` edit. The lawful route is Constitution V.1–V.3: exercise the
  documented `DMC_GATE_PROTECTED` override for the gated run with ONLY `dmc-glm-smoke` dropped
  (every other entry kept), under this plan's landmark-authorized scope.lock + human plan gate +
  critic/verifier chain (v1.0.1 precedent, `.harness/evidence/dmc-v1.0.1-build-20260708.md:74-77`).
  Separately and machine-verified (critic r2, VI.2): the release composer's landmark-flag sub-gate
  (`bin/lib/dmc-release-gate.py:617-636`) reads NO scope.lock grant and cannot be pre-cleared — it
  WILL raise `RGATE-LANDMARK-FLAG` on this landmark-touching change and the flag REMAINS raised,
  harmlessly, because "FLAG never degrades the verdict" is frozen composer design (`:14`, self-test
  U4). The flag is recorded in evidence as-is; NO attempt is made to clear or suppress it
  (VIII.3(a)).
  Source: Constitution Art. V; `bin/lib/dmc-release-gate.py:617-636`; v1.0.1 build evidence.

## Relevant Files

| Path | Reason | Allowed to Edit |
|---|---|---|
| `_DMC_CODEX_IMPLEMENT_FROM_SCRATCH_PROMPT.md` | bootstrap stray — `git rm` | yes (delete) |
| `_DMC_CODEX_PROMPT_AFTER_UNZIP.md` | bootstrap stray — `git rm` | yes (delete) |
| `_DMC_IMPORT_GUIDE.md` | bootstrap stray — `git rm` (recommended; gate may KEEP for provenance) | yes (delete) |
| `_DMC_MANIFEST.md` | bootstrap stray — `git rm` (B8 reserved approval exercised by this gate) | yes (delete) |
| `do-me-coding-v0.1-scaffold.zip` | bootstrap stray — `git rm` (41KB binary; already gitignored) | yes (delete) |
| `dmc-glm-smoke` | bootstrap stray — `git rm` WITH repo-intel companion edit | yes (delete) |
| `bin/lib/dmc-repo-intel.py` | companion edit: drop glm-smoke special-case + convert L1f to negative-control | yes |
| `.gitignore` | +2 run-residue patterns; −1 moot zip line | yes |
| `AGENTS.md` | regenerate via `dmc agents-md` after landmark change | yes (regen) |
| `docs/MILESTONES.md` | append one hygiene closure entry (append-only log) | yes (append) |
| `.harness/runs/dmc-v1-m3-20260706.md` | orphan local note — delete (untracked; not a git op) | yes (delete, local) |
| `.harness/runs/dmc-v1-m4-20260706.md` | orphan local note — delete (untracked; not a git op) | yes (delete, local) |
| `.harness/runs/dmc-v1-m5-20260706.md` | orphan local note — delete (untracked; not a git op) | yes (delete, local) |
| `.claude/install/dmc-install.sh` | heredoc `_DMC_*.md` prose stays (drift-tested surface) | no |
| `INSTALL_MANIFEST.md` | mirrors the heredoc; byte-stable — deliberate NO-EDIT | no |
| `*.before-dmc` trees | Constitution II.7 frozen — category 2 KEEP | no |
| `bin/lib/dmc-v0.*` + `.harness/evidence/dmc-v0.*` | Constitution II.1 mirror-frozen | no |
| `.harness/evidence/dmc-run-*.md`, `.harness/runs/dmc-run-*/` | run residue — stays on disk, becomes ignored | no |

## Out of Scope

- `.before-dmc` snapshot trees (proposal category 2 — KEEP until the M3 rollback guarantee is retired;
  Constitution II.7).
- The installer host `.gitignore` block and `INSTALL_MANIFEST.md` (frozen drift-tested generated
  surface; host block already broader than the repo patterns).
- Any edit to frozen `bin/lib/dmc-v0.*` tools, `.harness/evidence/dmc-v0.*` originals, schemas,
  orchestration registries, hooks, or `.claude/settings.json`.
- Deleting the untracked `.harness/evidence/dmc-run-*.md` / `.harness/runs/dmc-run-*/` residue
  (they become gitignored and stay on disk; deletion was never proposed).
- Any version-identity bump (project stays "Do-Me-Coding v1.0"; this ships as a no-version hygiene
  commit — the M10 proposal's phrase "a v1.1 hygiene commit" reads as "in the v1.1 era").
- Re-pinning or "fixing" the 802/3/3 baseline (Constitution II.2 — this plan must leave it EXACT).
- Editing ANY of the disclosed inert `dmc-glm-smoke` residual surfaces (provider contract C5b/C9,
  manual-import PROT_RE, the 7 docs prose mentions, MILESTONES history, frozen v0.x PROT_REs) —
  protective-list entries over-protect harmlessly; trimming them would weaken guard surfaces
  (see Findings; VI.2 forbids prose "corrections" of frozen-runner facts).

## Proposed Changes

- Change: Remove the five-doc bootstrap cluster: `git rm` the four `_DMC_*.md` files +
  `do-me-coding-v0.1-scaffold.zip`; drop the now-moot `do-me-coding-v0.1-scaffold.zip` line from
  `.gitignore`.
  Files: the five strays, `.gitignore`.
  Rationale: zero functional references (scout-proven); cluster removal avoids dangling
  cross-references; provenance survives in git history; B8's reserved human gate is this plan's gate.
- Change: Remove `dmc-glm-smoke` with its companion edit in the SAME commit:
  `bin/lib/dmc-repo-intel.py` — (a) drop `or rel == "dmc-glm-smoke"` from `classify_landmark()`
  (:278); (b) convert the L1f assertion (:614) to a negative control
  (`t.ok("L1f self-scan: dmc-glm-smoke correctly absent", "dmc-glm-smoke" not in cls)`) so the check
  count stays stable and the removal is itself asserted.
  Files: `dmc-glm-smoke`, `bin/lib/dmc-repo-intel.py`.
  Rationale: root-caused load-bearing references (VIII.3(b) satisfied); a bare removal would red the
  default selftest — forbidden masking territory; the negative control makes the new state
  self-verifying.
- Change: Regenerate `AGENTS.md` (`bin/dmc agents-md`) after the landmark change; diff-check that the
  §7 companion-context pointers (AUTONOMY.md + docs/CONTEXT_MAP.md) survive regeneration.
  Files: `AGENTS.md`.
  Rationale: committed copy otherwise silently lists a deleted landmark; the AC6 pointer-loss
  regression class is guarded by an explicit diff-check + the frozen v0.4.7 audit.
- Change: Extend the DMC repo `.gitignore` with `.harness/evidence/dmc-run-*.md` and
  `.harness/runs/dmc-run-*/` (new "Do-Me-Coding per-run auto-logs" stanza).
  Files: `.gitignore`.
  Rationale: durable policy (producers are live machinery); `git add -A` can no longer capture
  per-run noise; zero tracked matches so nothing untracks; gates read disk only.
- Change: Append one closure entry to `docs/MILESTONES.md` recording the hygiene execution and its
  B8 lineage.
  Files: `docs/MILESTONES.md`.
  Rationale: append-only traceability (Constitution I.3); B8 anticipated a recorded closure.
- Change: Delete the three orphan local notes `.harness/runs/dmc-v1-m{3,4,5}-20260706.md`
  (untracked; plain `rm`, evidence-logged).
  Files: the three orphans.
  Rationale: content fully duplicated in tracked surfaces (scout line-by-line cross-check);
  lingering violates the recorded local-only policy (Carry-forward 6).

## Acceptance Criteria

- Criterion: The six strays are gone from git tracking and disk. For the FIVE doc/zip strays,
  `git grep` per basename returns only historical `.harness/` prose + the installer/manifest heredoc
  line. For `dmc-glm-smoke`, `git grep` returns ONLY the enumerated inert residuals (the Findings
  list: provider-contract C5b/C9, manual-import PROT_RE, the 7 docs prose mentions, MILESTONES
  history, frozen v0.x PROT_REs, and this cycle's own governance artifacts — class (g)) — none of
  which keys on file existence — and the regenerated AGENTS.md contains zero `dmc-glm-smoke`
  occurrences.
  Verification Method: `git ls-files | grep -E '_DMC_|scaffold\.zip|dmc-glm-smoke'` → empty;
  whole-tree `git grep -nF dmc-glm-smoke` diffed against the Findings enumeration classes (a)–(g)
  (no NEW class); negative-proof greps recorded in evidence.
- Criterion: Default selftest stays green with the landmarks negative control in force.
  Verification Method: `bin/dmc selftest` → 0 FAIL; `bin/dmc selftest landmarks` → 0 FAIL with the
  renamed L1f negative-control row visibly PASSing.
- Criterion: No frozen-surface drift.
  Verification Method: `bin/dmc mirror-check` → PASS (55 byte-identical); no diff under
  `bin/lib/dmc-v0.*`, `.harness/evidence/dmc-v0.*`, `*.before-dmc`.
- Criterion: AGENTS.md regenerated, valid, and pointer-complete.
  Verification Method: `bin/dmc agents-md --validate` → VALID; regenerated §4 lists no
  `dmc-glm-smoke`; §7 still points at `AUTONOMY.md` + `docs/CONTEXT_MAP.md`; frozen
  `dmc-v0.4.7-context-audit` → 7/0 and `dmc-v0.4.9` stage-0 REGRESSION green on the committed replica
  or live post-commit tree.
- Criterion: Linkcheck unaffected.
  Verification Method: `bin/dmc linkcheck` → clean (24 files, 0 findings).
- Criterion: The pinned legacy baseline survives EXACTLY (Constitution II.2).
  Verification Method: committed-replica `bin/dmc selftest --all` → the known /tmp-clone baseline;
  post-commit LIVE dev-tree `bin/dmc selftest --all` → legacy **802/3/3 EXACT**, exit 0.
- Criterion: After the gitignore extension, per-run residue no longer surfaces.
  Verification Method: `git status --porcelain` on the post-commit tree → empty (15 evidence
  auto-logs + 15 run dirs no longer listed; 3 orphans deleted).
- Criterion: CI green on the pushed HEAD; main fast-forwarded.
  Verification Method: dmc-ci Actions run concludes success (all blocking steps); `git push origin
  <branch>:main` fast-forward; origin/main == branch HEAD.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| repo-intel companion edit misses a live glm-smoke reference | low | whole-tree reference inventory now in Findings (critic r1 BL-INVENTORY closed); executor re-greps `dmc-glm-smoke` across the WHOLE tree (frozen surfaces excluded from edit, not from the grep) and diffs against the Findings enumeration before hand-back; negative-control L1f asserts absence at selftest time |
| G4 protected-path check trips on the dmc-glm-smoke deletion (expected, by design) | low | NOT a failure — documented V.1–V.3 override: `DMC_GATE_PROTECTED` minus `dmc-glm-smoke` only, all other entries kept, under landmark-authorized scope.lock + human gate + critic/verifier chain (v1.0.1 precedent); the separate landmark-flag sub-gate WILL raise its non-degrading `RGATE-LANDMARK-FLAG` and it stays raised — recorded, never cleared |
| AGENTS.md regen drops §7 pointers again (AC6 class) | medium | explicit post-regen diff-check in the task + frozen v0.4.7 audit re-run as AC |
| frozen v0.x verify tools flag the in-flight deletion on a dirty pre-commit tree | low | established M9/M10 recipe: committed-replica + post-commit live verification; no pre-commit `--all` gating |
| landmark protected-union shrinks (enforcement surface removed) | low | the surface being "protected" was the stray file itself; removal eliminates the object, not a tier (VIII.5 note); landmark-authorized scope.lock + human gate + critic/verifier chain per Art. V discipline |
| gitignore patterns hide a future DELIBERATE evidence deliverable | low | patterns are `dmc-run-*` shaped only; curated `dmc-v1-*`/named evidence stays visible; policy documented in the MILESTONES entry |
| orphan deletion loses unrecorded facts | low | scout cross-checked line-by-line against 4 tracked surface classes; deletion evidence quotes the cross-check |

## Assumptions

| Assumption | Confidence | How to Verify |
|---|---|---|
| `git rm` of single tracked files passes Ring-0 (not catastrophic-destructive class) | medium | attempt under the armed run; on deny → STOP and escalate per VIII.4 (no bypass) |
| the L1f negative-control edit keeps the landmarks self-test count stable | high | run `bin/dmc selftest landmarks` immediately after the edit |
| no tracked file matches the two new gitignore patterns | high | re-run `git ls-files` for both patterns pre-commit |
| the drift-tested INSTALL_MANIFEST prose needs no edit | high | `bin/dmc selftest m8-suite` manifest-drift fixture green post-change |

## Execution Tasks

- [ ] DMC-T001: Remove the five-doc bootstrap cluster + `.gitignore` edit (−1 moot zip line, +2
  run-residue patterns, one new commented stanza).
  Files: `_DMC_CODEX_IMPLEMENT_FROM_SCRATCH_PROMPT.md`, `_DMC_CODEX_PROMPT_AFTER_UNZIP.md`,
  `_DMC_IMPORT_GUIDE.md`, `_DMC_MANIFEST.md`, `do-me-coding-v0.1-scaffold.zip`, `.gitignore`.
  Notes: `git rm --` per file; Route: Sonnet 5, synchronous.
- [ ] DMC-T002: Remove `dmc-glm-smoke` + companion `bin/lib/dmc-repo-intel.py` edit (classify_landmark
  special-case drop at :278; L1f → negative control at :614-615). Afterward re-grep `dmc-glm-smoke`
  across the WHOLE tree and confirm the surviving set matches the Findings enumeration exactly
  (no new class; frozen surfaces excluded from edit, included in the grep).
  Files: `dmc-glm-smoke`, `bin/lib/dmc-repo-intel.py`.
  Notes: Route: Opus 4.8, synchronous; run `bin/dmc selftest landmarks` before hand-back.
- [ ] DMC-T003: Regenerate `AGENTS.md`; diff-check §7 companion-context pointers survive; append the
  hygiene closure entry to `docs/MILESTONES.md`.
  Files: `AGENTS.md`, `docs/MILESTONES.md`.
  Notes: depends on DMC-T002; Route: Sonnet 5, synchronous; `bin/dmc agents-md --validate` → VALID.
- [ ] DMC-T004: Delete the three orphan local notes (untracked; plain `rm`, logged in run evidence).
  Files: `.harness/runs/dmc-v1-m3-20260706.md`, `.harness/runs/dmc-v1-m4-20260706.md`,
  `.harness/runs/dmc-v1-m5-20260706.md`.
  Notes: local-only op; Route: orchestrator-supervised executor step within DMC-T001's session.

## Verification Commands

| Command | Reason | Required |
|---|---|---|
| `bin/dmc selftest` | default set 0 FAIL incl. landmarks negative control | yes |
| `bin/dmc selftest landmarks` | L1f negative-control row PASS | yes |
| `bin/dmc mirror-check` | 55-file frozen mirror intact | yes |
| `bin/dmc linkcheck` | 24-file scan clean | yes |
| `bin/dmc agents-md --validate` | regenerated AGENTS.md structurally VALID | yes |
| `bin/dmc selftest m8-suite` | manifest-drift fixture green (installer prose untouched) | yes |
| committed-replica `bin/dmc selftest --all` | known clone baseline; no new FAIL class | yes |
| post-commit live `bin/dmc selftest --all` | legacy **802/3/3 EXACT**, exit 0 (Constitution II.2) | yes |
| `git status --porcelain` (post-commit) | empty — residue ignored, orphans gone | yes |
| `git ls-files \| grep -E '_DMC_\|scaffold\.zip\|dmc-glm-smoke'` | negative proof of untracking | yes |
| whole-tree `git grep -nF dmc-glm-smoke` vs Findings enumeration | residuals match the disclosed inert set, no new class | yes |
| `dmc gate release --full --run-id <run>` | 9/9 sub-gates PASS. Two distinct mechanisms: G4 FAILs on the deletion and is re-gated ONLY via the D6-ratified `DMC_GATE_PROTECTED` override (dmc-glm-smoke dropped, all else kept); the landmark-flag sub-gate raises its non-degrading FLAG, which needs nothing and is recorded as-is | yes |
| dmc-ci Actions run on pushed HEAD | all blocking steps green | yes |

## Approval Status

Status: APPROVED
Approver: wjlee (woojin20020@gmail.com)
Approved At: 2026-07-08 (AskUserQuestion gate, this session)

Ratified decisions (all six, recommendations accepted verbatim):
- D1: remove ALL five doc/zip strays including `_DMC_IMPORT_GUIDE.md`.
- D2: INCLUDE the `dmc-glm-smoke` removal + `bin/lib/dmc-repo-intel.py` companion edit + AGENTS.md regen.
- D3: append the MILESTONES.md closure entry.
- D4: delete the 3 orphan local notes.
- D5: no-version-label chore commit; identity stays "Do-Me-Coding v1.0".
- D6: the G4 `DMC_GATE_PROTECTED` override is RATIFIED for this run — env value = the frozen
  v0.2.6 runner's `DEFAULT_PROTECTED` entries verbatim, newline-separated, dropping ONLY the
  `dmc-glm-smoke` line (critic r3 advisory 3); the landmark-flag sub-gate's non-degrading FLAG is
  expected, recorded, never cleared.

Critic chain: r1 REJECT (BL-INVENTORY, BL-AC1) → Rev 2 → r2 REJECT (BL-R2-AC1-SELF,
BL-R2-G4-WORDING) → Rev 3 → r3 APPROVE, plan_hash
`563d3f634bd249ffadc99394698d5ae83939ba3d633c2ad8193b1917947f01bd`, repo_hash `046090f…`
(artifacts: `.harness/evidence/dmc-stray-hygiene-critic-r{1,2,3}.json`).

Gate addendum (2026-07-08, mid-run, DMC-T002 executor escalation — recorded on the established
§Approval-Status orchestrator lane, M7/M8/M10 precedent; scope-guard's live denial of this edit
under the armed run was honored, the edit made only after `run suspend` + pointer clear, run then
resumed — sequence recorded verbatim in the closure evidence): residual class (h) RATIFIED by
wjlee via AskUserQuestion — `.harness/` frozen historical records (archived plans, evidence,
verification `.md`/`.json`/`.sh`, INCLUDING the II.1 mirror's `.harness/evidence/dmc-v0.*`
originals whose PROT_RE listings twin class (e)'s `bin/lib` copies) plus the illustrative prose
comment at `.harness/schemas/landmarks.schema.md:34` — all inert w.r.t. file existence, all
deliberate NO-EDIT (frozen surfaces are uneditable outright; II.7/II.1). AC1's grep-diff therefore
reads "classes (a)–(h) (no NEW class)". The DMC-T002 executor correctly refused to
self-reclassify and escalated (VIII.4).

Scope-stage note (Art. III.2 stage 4): the compiled scope.lock MUST set `landmark_authorized: true` —
the grant set touches enforcement-class landmarks (`bin/lib/dmc-repo-intel.py`, `dmc-glm-smoke`) and a
release-class landmark (`docs/MILESTONES.md`); `.harness/evidence` paths are NEVER granted (G2↔G3
catch-22).

Gate decision points for the approver (recommendations pre-stated, gate may override):
- D1: remove ALL five doc/zip strays including `_DMC_IMPORT_GUIDE.md` (recommended) vs KEEP the guide
  for provenance (then its :16/:28 pointers dangle — not recommended).
- D2: include the `dmc-glm-smoke` removal + repo-intel companion edit (recommended) vs defer it to its
  own cycle (then category 1 stays half-done and AGENTS.md keeps listing it).
- D3: append the MILESTONES.md closure entry (recommended) vs docs-silent commit.
- D4: delete the 3 orphan local notes (recommended; scout-proven duplication) vs leave untracked.
- D5 (critic r1 AD-version): version disposition of the hygiene commit — no-version-label chore commit
  (RECOMMENDED; identity stays "Do-Me-Coding v1.0"; note this commit carries a code edit and runs the
  full suites, so it is NOT the docs-only class) vs a `v1.0.2` patch label (identity-sweep overhead)
  vs `v1.1` (implies feature scope this plan does not carry). The M10 phrase "a v1.1 hygiene commit"
  is evidence-rung history (VI.3 rung 6), not a binding label decision — the gate decides.
- D6 (critic r2): explicitly ratify the G4 `DMC_GATE_PROTECTED` override for this run — the env-var
  route documented at Constitution V.1–V.3, exercised with ONLY `dmc-glm-smoke` dropped and every
  other protected entry kept — so the approval record covers the blocking-verdict flip itself, not
  merely the plan as a whole. (The landmark-flag sub-gate is a separate mechanism: its non-degrading
  FLAG rises regardless and is recorded, never cleared.)
