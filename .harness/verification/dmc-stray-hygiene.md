# Verification Report

## Run ID

dmc-run-8f34d637a6f2 (status SUSPENDED, seq 5; pointer cleared — governance window). Independent
non-authoring verifier; the verifier wrote none of the work under review.

## Plan

`.harness/plans/dmc-stray-hygiene.md` (Rev 3 + ratified Approval-Status/Gate addendum).
Operative critic verdict: **r4 APPROVE** (`.harness/evidence/dmc-stray-hygiene-critic-r4.json`),
which supersedes r3 for hash coherence. `plan_hash = sha256(raw plan bytes)` computed live =
`4bbeeb2090991b99f791e0589f9e59ac878b705c7eaba9e855cb7c9634f61604`, byte-for-byte equal to the r4
verdict's `plan_hash` — so r4 is bound to the exact current plan bytes. (scope.lock/run.json remain
bound to the arming-time `plan_hash 316cf9de…`; see Manual Checks for adjudication.)

## Changed Files

All ten changed TRACKED paths are within the 10-entry scope.lock `files[]` (exact 1:1 cover).

- `_DMC_CODEX_IMPLEMENT_FROM_SCRATCH_PROMPT.md`: staged deletion (bootstrap stray; scope.lock grant)
- `_DMC_CODEX_PROMPT_AFTER_UNZIP.md`: staged deletion (bootstrap stray; scope.lock grant)
- `_DMC_IMPORT_GUIDE.md`: staged deletion (bootstrap stray; D1 remove-all; scope.lock grant)
- `_DMC_MANIFEST.md`: staged deletion (bootstrap stray; scope.lock grant)
- `do-me-coding-v0.1-scaffold.zip`: staged deletion (41092-byte binary; scope.lock grant)
- `dmc-glm-smoke`: staged deletion (retired v0.2.1 runner; enforcement landmark; landmark_authorized grant)
- `bin/lib/dmc-repo-intel.py`: modified (companion edit — classify_landmark :278 special-case drop; L1f :614-615 → negative control; landmark_authorized enforcement grant)
- `.gitignore`: modified (−1 moot zip line, +2 dmc-run-* patterns + stanza; ordinary grant)
- `AGENTS.md`: modified (regenerated; glm-smoke landmark removed §4 + §5; ordinary grant)
- `docs/MILESTONES.md`: modified (append-only B8 closure entry; landmark_authorized release grant)

Untracked (known exempt-prefix governance lane, NOT in scope.lock, correctly out-of-lock):
this plan, critic r1–r4 JSONs, this report, and the 3 orphan notes
`.harness/runs/dmc-v1-m{3,4,5}-20260706.md` (still present + untracked; D4 deletes them at closure — NOT yet done).

## Commands Run

| Command | Result | Reason | Output Summary |
|---|---|---|---|
| `git status --porcelain` + `git diff --cached/--stat` | PASS | diff-in-scope | 6 staged deletions + 4 working-tree mods; 10 distinct tracked paths, all in scope.lock |
| `bin/dmc selftest` (default) | PASS | AC2 | validate-run 6/0, validate-verification 6/0, schemas-mirror 15/0, legacy-mirror 4/0; 0 FAIL overall |
| `bin/dmc selftest landmarks` | PASS | AC2 | 11 PASS / 0 FAIL; L1f row reads "dmc-glm-smoke correctly absent" (negative control PASSing) |
| `bin/dmc mirror-check` | PASS | AC3 | RESULT PASS; 55 byte-identical; "no stray dmc-v0.* copies beyond the pinned 55-file set" |
| `bin/dmc linkcheck` | PASS | AC5 | clean — 24 files scanned, every dmc-verb/artifact-path/role resolves |
| `bin/dmc agents-md --validate AGENTS.md` | PASS | AC4 | VALID: all 10 required sections present, non-empty, no guessed filler |
| `bin/dmc selftest m8-suite` | PASS | manifest-drift | doctor-negcontrols 16/0; manifest-drift 10/0 (INSTALL_MANIFEST byte-equal; installer prose untouched) |
| `bash bin/lib/dmc-v0.4.7-context-audit.sh --self-test` | PASS | AC4 | self-test PASS=7 FAIL=0; AC6 confirms AGENTS.md points to AUTONOMY.md + docs/CONTEXT_MAP.md |
| `git ls-files \| grep -E '_DMC_\|scaffold\.zip\|dmc-glm-smoke'` | PASS | AC1 | empty (exit 1) — no stray remains git-tracked |
| `git grep -nF dmc-glm-smoke` (whole tree) | PASS | AC1 | 188 tracked hits / 107 files; all classify into (a)–(h) + disclosed repo-intel negative control; AGENTS.md = 0 |
| `grep -c dmc-glm-smoke AGENTS.md` | PASS | AC4 | 0 |
| `git check-ignore -v <run-residue>` + porcelain scan | PASS | AC7 | dmc-run-*.md / dmc-run-*/ ignored via .gitignore:19,20; 0 dmc-run-* in porcelain; curated dmc-v1-* NOT ignored |
| `python3 bin/lib/dmc-scope-lock.py --validate <lock>` | PASS | scope integrity | VALID: conforms to dmc.scope-lock.v1 |
| committed-replica + post-commit-live `bin/dmc selftest --all` (802/3/3) | SKIPPED | AC6 | PENDING-BY-DESIGN — post-commit only; work is staged/working-tree, not committed |
| `dmc-ci` Actions + `git push …:main` fast-forward | SKIPPED | AC8 | PENDING-BY-DESIGN — post-commit/post-push only |

## Manual Checks

| Check | Result | Notes |
|---|---|---|
| Diff subset of scope.lock files[] | PASS | 10 changed tracked paths == the 10 scope.lock entries, exact 1:1; no out-of-scope tracked change |
| scope.lock file immutability | PASS | `shasum -a256 scope.lock.json` = `6d4321ce3c6a55b1ae81ee16d576cbf047285992d1046aa45c487679c9077b65` == run.json `operative_snapshot.scope_lock_sha256`; resumed run carries the SAME scope.lock (no mid-run widening) |
| scope.lock state_hash unchanged | PASS | state_hash field = `f0d7cf85345ed9b390…` (matches recorded `f0d7cf85345ed9b3` at compile) |
| scope.lock landmark_authorized present | PASS | true on `bin/lib/dmc-repo-intel.py` (enforcement), `dmc-glm-smoke` (enforcement), `docs/MILESTONES.md` (release); no `.harness/evidence` grant (G2-G3 catch-22 respected) |
| Suspend-window attestation | PASS | current plan bytes hash == r4 plan_hash `4bbeeb20…`; r4 (context_provenance fresh, verdict APPROVE, blockers []) is bound to the exact current bytes and independently attests the +27-line delta (327 to 354) is EXACTLY the Approval Status block; r3-quoted body line-refs still resolve unchanged in the current file — Findings class (g) at :103-106, AC1 inert-set at :207-211, Verification-Method at :212-214, G4 mechanism at :117-122 — while only Approval-Status-internal refs shifted (r3 D6 :322-326 to now :350-354). Difference from r3-reviewed body is confined to the Approval Status section. |
| plan_hash divergence scope.lock/run.json vs current plan | PASS (expected/lawful) | scope.lock + run.json bound to arming-time `plan_hash 316cf9de…`; current plan = `4bbeeb20…`. Signature of the lawful mid-run class-(h) addendum (disarm-edit-rearm, human-ratified BEFORE edit, guard denial honored per r4). Addendum changed no scope (file list + bounds unchanged); r4 re-binds the critic verdict to the new bytes so the chain's GATE-PLAN-HASH-MISMATCH check clears. Not a violation. |
| AC1 residual classification (no NEW undisclosed class) | PASS | 188 tracked hits fully accounted: (a) PROVIDER_CONTRACT.md 2 lines/1 file; (b) manual-import-adapter.py PROT_RE 1/1; (c) 7 docs prose 7/7; (d) MILESTONES history 6 lines (:22,50,90,151,335,428); (g) MILESTONES new closure entry 3 lines (:653,655,663); (e) frozen bin/lib/dmc-v0.* 30/25; (f) AGENTS.md 0 (regenerated); repo-intel.py negative control 2 lines (:614-615, this-cycle companion edit disclosed in Proposed Changes :176-178); (h) landmarks.schema.md:34 =1, .harness/evidence/dmc-v0.* mirror originals 30/25, .harness/evidence archived records 5/5, .harness/plans archived 67/19, .harness/verification archived 34/21. Sum = 188 exact. No undisclosed surviving reference. |
| AGENTS.md section-7 pointers survived regen (AC6-class guard) | PASS | `AUTONOMY.md` + `docs/CONTEXT_MAP.md` present at AGENTS.md:236-237; diff removed only the glm-smoke landmark from section 4 and its token from section 5 |
| MILESTONES II.5 deferral registered (r4 ADVISORY 1) | PASS | closure entry carries "Registered deferral (v1.1+)" bullet: landmarks.schema.md:34 is a LIVE II.5 contract surface deliberately NOT edited (distinct from frozen blanket); one-line reword registered for v1.1+ |
| Orphan notes m3/m4/m5 current state | INFO | present + untracked; D4 deletes at closure (post-commit) — not yet executed; correct for a suspended pre-commit state |
| Bounds arithmetic | PASS | files 10/10 (at limit); added 25/120 (gitignore 4 + AGENTS 1 + repo-intel 3 + MILESTONES 17; staged deletions add 0); deleted 331/600 (staged text 325 = 78+55+34+38+120; working-tree 6 = gitignore 1 + AGENTS 2 + repo-intel 3); binary zip shows numstat `-/-` -> 1 file, 0 lines |
| No frozen-surface drift | PASS | porcelain shows nothing under bin/lib/dmc-v0.*, .harness/evidence/dmc-v0.*, *.before-dmc, schemas/hooks/settings/router |
| repo-intel.py edit is exactly the two planned changes | PASS | diff = drop `or rel == "dmc-glm-smoke"` at classify_landmark :278 + L1f :614-615 flipped to `"dmc-glm-smoke" not in cls` negative control; nothing else touched |

## Scope Review

Result: PASS

Notes:
Every changed TRACKED path (10) is inside the 10-entry scope.lock `files[]` with an exact 1:1
correspondence — six staged deletions plus four working-tree modifications, no out-of-scope tracked
edit. The three landmark-class edits (`bin/lib/dmc-repo-intel.py`, `dmc-glm-smoke`,
`docs/MILESTONES.md`) each carry `landmark_authorized: true`; no `.harness/evidence` path is granted.
The scope.lock validates (dmc.scope-lock.v1), its on-disk sha256 equals the run.json operative
snapshot (same immutable lock across the suspend/resume), and its state_hash matches the value
recorded at compile. Untracked `.harness/{plans,evidence,runs}` governance artifacts (this plan,
critic r1–r4, this report, the 3 orphan notes) are the known exempt-prefix lane and are correctly
absent from the lock.

## Package / Env / Migration Review

Package files changed: no
Env files changed: no
Migration files changed: no

Notes:
No dependency manifests (`tests/fixtures/*/package.json`, `pyproject.toml`) were touched. No
environment-configuration or protected-config file was read, edited, or referenced, and none changed.
No database/migration files exist or changed. `.gitignore` changed (config only): it removes a moot
archive-zip line and adds two `dmc-run-*` ignore patterns that match zero tracked files (verified) —
no runtime or build effect.

## Unresolved Risks

- AC6 (legacy **802/3/3 EXACT** on committed-replica + post-commit live tree) and AC8 (dmc-ci green
  on pushed HEAD, main fast-forward) are PENDING-BY-DESIGN: they are structurally unrunnable until
  the work is committed/pushed. They must be executed at closure BEFORE the run is declared DONE —
  this PASS does not attest them.
- G4 `DMC_GATE_PROTECTED` override (D6) and the non-degrading `RGATE-LANDMARK-FLAG` are exercised at
  the release-gate step (`dmc gate release --full`), which runs at commit/closure — recorded/never
  cleared per plan; not yet observed by this report (post-commit gate step).
- D4 orphan-note deletion + the final "empty porcelain" state remain closure steps (post-commit).
- Minor disclosure nit (non-blocking): the MILESTONES closure entry records the critic chain as
  "r1 to r2 to r3" and does not mention the r4 re-binding verdict; substance is unchanged (r4
  supersedes r3 solely for hash coherence). AC1 body text still reads "(a)-(g)" while the ratified
  addendum reads "(a)-(h)"; adjudicated here per the addendum's (a)-(h) reading, as r4 ADVISORY 3 directs.

## Final Status

PASS

Scope: every non-pending acceptance criterion is met with reproduced evidence — AC1 (six strays
untracked; residuals fully classified, no NEW undisclosed class; AGENTS.md=0), AC2 (selftest 0 FAIL;
landmarks 11/0 with the L1f negative control), AC3 (mirror-check PASS 55; no frozen drift), AC4
(agents-md VALID; section-7 pointers intact; context-audit 7/0), AC5 (linkcheck clean 24), AC7
(gitignore effect; 0 dmc-run-* in porcelain; curated evidence still visible), m8-suite (0 FAIL) —
plus scope subset of scope.lock, scope.lock immutable + valid, bounds within limits, and the
suspend-window plan integrity attested against the operative r4 verdict. AC6 and AC8 remain
PENDING-BY-DESIGN (post-commit) and are NOT attested by this report; the run may not be declared DONE
until they pass at closure.
