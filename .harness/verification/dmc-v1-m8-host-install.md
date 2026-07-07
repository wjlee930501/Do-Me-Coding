# Verification Report

## Run ID

dmc-run-03cba8c2797c

(Milestone verification for DMC v1 §M8 — Host Install / Adaptation (P19 + P20), tasks DMC-T013.1–.5,
run under the armed build run `dmc-run-03cba8c2797c` (SUSPENDED wait-state; 14-file scope.lock compiled
at HEAD `82300bda`). Line 1 above is the bare active run id. This is the implementer's evidence record;
it opens no gate and makes no approval (C11) — completion is the Verifier's call, release the human
gate's. Build evidence sibling: `.harness/evidence/dmc-v1-m8-build-20260707.md`.)

## Plan

.harness/plans/dmc-v1-m8-host-install.md (Rev 3; APPROVED 2026-07-07 by wjlee via AskUserQuestion,
option "승인 — Rev 3 그대로". Critic chain r1 REJECT (5 blockers B1–B5, plan_hash `8dfdcf68…`) → Rev 2 →
r2 REJECT (B1–B5 closed; 1 new blocker B6, plan_hash `4f6a34ed…`) → Rev 3 → r3 APPROVE bound to the
pre-approval bytes sha256 `dd8e23d7246836517103c1e94d949c94132759f6c01b9981d56639137907c24c`; verdicts
persisted at `.harness/evidence/dmc-v1-m8-critic-verdict-r{1,2,3}.json`.)

## Changed Files

- .claude/install/dmc-install.sh: T013.1 — `--host claude|codex|both` ship-surface (Ring-0 + adapters),
  P19 fixes (`${DRY:+}`→`[ "$DRY" = 1 ]`, `eval`-drop argv-safe `act()`, paired HTML/`#` markers),
  provenance receipt + `# DMC-CREATED` sentinel, `.codex` collision policy, `--emit-manifest`; in-lock edit
- .claude/install/dmc-uninstall.sh: T013.2 — marker-bounded `.gitignore`/CLAUDE.md strip (dead-`skip`
  fixed), provenance/receipt-scoped removal, receipt removed LAST, A1 fixed-name fallback, `${DRY:+}` fix,
  worker-context-guard strip; in-lock edit
- INSTALL_MANIFEST.md: T013.1 — regenerated from `--emit-manifest` (byte-equal); full copy tables +
  hand-authored Dangling-reference / DELIBERATELY NOT COPIED sections; in-lock edit
- bin/dmc: T013.3 — SOLE M8 edit: `doctor` verb + guarded `run_m8_suite()` + `doctor`/`m8-suite` selftest
  sections (named-only + under `--all`, never in the no-arg default); in-lock edit
- bin/lib/dmc-doctor.py: T013.3 — offline per-host self-check (Claude synthetic-event probe PROVEN;
  Codex ADVISORY; per-host matrix; host-independent mode); in-lock create
- orchestration/models.json: T013.3 — P20 dated model-binding lookup; SOLE model-name home; display-only,
  no gate consumer; in-lock create
- orchestration/harness-matrix.json: T013.3 — P20 per-harness enforcement matrix; all 8 CODEX_ADAPTER §3
  rows × {claude-code, codex, opencode}; harness-ids only; in-lock create
- tests/fixtures/m8/_m8common.sh: T013.4 — shared M8 suite helpers; in-lock create
- tests/fixtures/m8/test-install-roundtrip.sh: T013.4 — 5-host install→doctor→uninstall→byte-clean +
  Ring-0-omission + single-quote-path + `.codex` provenance arms; in-lock create
- tests/fixtures/m8/test-idempotency.sh: T013.4 — double-install no-op + codex re-affirm; in-lock create
- tests/fixtures/m8/test-doctor-negcontrols.sh: T013.4 — nc1–nc4 doctor falsifiability; in-lock create
- tests/fixtures/m8/test-manifest-drift.sh: T013.4 — `--emit-manifest`==committed + section-deletion
  negative controls; in-lock create

(The two T013.5 deliverables — `.harness/evidence/dmc-v1-m8-build-20260707.md` and this report — plus the
run-dir state and auto-logged evidence ledgers fall under the `.harness/{evidence,verification,runs}/`
internal exemption and are not re-declared here. The two dirty `.harness/plans/*` paths are pre-run
orchestration artifacts outside this build's allowlist — accounted in §Scope Review.)

## Commands Run

| Command | Result | Reason | Output Summary |
|---|---|---|---|
| bash -n dmc-install.sh dmc-uninstall.sh | PASS | shell syntax floor over the two touched installers | clean, exit 0 |
| py_compile bin/lib/dmc-doctor.py (pyc→scratch) | PASS | python syntax floor over the doctor module | OK |
| python3 json.load models.json + harness-matrix.json | PASS | P20 data files parse | both parse OK |
| bin/dmc selftest (fast default) | PASS | no-arg default floor preserved by the bin/dmc edit | 75 PASS / 0 FAIL across 9 sections, exit 0 |
| bin/dmc selftest doctor | PASS | doctor module unit (interpreters, probe, per-shape exit, mode default, real-repo byte-identity) | 24 PASS / 0 FAIL, exit 0 |
| bin/dmc selftest m8-suite | PASS | install round-trip + idempotency + doctor-negcontrols + manifest-drift aggregate | 126 PASS / 0 FAIL (83+17+16+10), exit 0 |
| tests/fixtures/m8/test-install-roundtrip.sh (standalone, bash) | PASS | 5-host install→doctor→uninstall→byte-clean + Ring-0-omission + single-quote-path + created/foreign/sequence `.codex` provenance arms | 83 PASS / 0 FAIL, exit 0 |
| tests/fixtures/m8/test-idempotency.sh (standalone, bash) | PASS | double-install no-op + codex re-affirm (2nd `--host codex` re-affirms, no skip-warn) | 17 PASS / 0 FAIL, exit 0 |
| tests/fixtures/m8/test-doctor-negcontrols.sh (standalone, bash) | PASS | nc1 missing-python3 · nc2 unregistered-hook · nc3 foreign-harness · nc4 seeded-Codex-enforced-line (Codex-scoped grep) + positive controls | 16 PASS / 0 FAIL, exit 0 |
| tests/fixtures/m8/test-manifest-drift.sh (standalone, bash) | PASS | `--emit-manifest`==committed (byte + section-presence) + hand-edit + section-deletion negative controls + dangling-ref scan | 10 PASS / 0 FAIL, exit 0 |
| dmc-install.sh --emit-manifest \| diff INSTALL_MANIFEST.md | PASS | generated manifest is the true SSoT | byte-equal (diff rc=0); `## Dangling-reference rule` + `## DELIBERATELY NOT COPIED` present |
| dmc doctor (real repo) | PASS | per-host honest render: Claude PROVEN + enforced rows, Codex ADVISORY rows, foreign `.omc`→PASSIVE, mode host-independent | Result PASS, exit 0 |
| Codex-scoped honesty control (grep /codex/i) | PASS | (i) ZERO forbidden lexeme `enforced\|enforce\|fires\|firing\|runtime-enforced\|active\|guaranteed` on any Codex line; (ii) Codex wiring row carries ADVISORY + pre-commit/CI | (i) no match; (ii) both substrings present |
| narrow model-version self-scan (bin/ adapters/ .claude/install/ roles.json harness-matrix.json) | PASS | Ring-0 stays model-version-name-free; harness ids claude-code/codex permitted | 1 hit = the enumerated exclusion `bin/lib/dmc-roles.py:394` (selftest fixture); 0 unexplained; models.json out of scan surface by design; seeded `codex-5` token control fires (non-vacuous) |
| no-network/no-bypass grep (.claude/install + bin/lib/dmc-doctor.py) | PASS | zero network/credential/trust-bypass primitive incl. `dangerously-bypass-hook-trust` | no match (rc=1) |
| models.json-consumer grep (bin/ adapters/) | PASS | models.json is display/lookup-only, read by no gate | only dmc-doctor.py reads it (`:256`, display); dmc-roles.py names it in comments/errors (`:8,:71,:182`) but never opens it; adapters/ none |
| bin/dmc mirror-check | PASS | legacy bin/lib ↔ .harness/evidence byte-equality untouched (dmc-doctor.py not in the pinned mirror set) | 55-file set green + no stray dmc-v0.* copies, exit 0 |
| bin/dmc linkcheck | PASS | no dangling dmc-verb / artifact-path / role reference | 24 files scanned, clean, exit 0 |
| committed-replica bin/dmc selftest --all (tar-replica preserving .git history + build committed on top; real repo untouched) | PASS | pinned baseline + all prior sections + new doctor + m8-suite, 0 FAIL (details in Manual Checks) | legacy tools=49 PASS=802 FAIL=3 N/A=3 EXACT; every named section 0 FAIL; SELFTEST-ALL RESULT: PASS, exit 0 |
| git status --porcelain (real repo before/after replica) ; git diff --name-only vs the 14-file lock | PASS | real-repo byte-cleanliness + scope conformance | HEAD unchanged 82300bda; porcelain minus the two authored deliverables byte-identical to the pre-replica baseline; scope conforms (see Scope Review) |

## Manual Checks

| Check | Result | Notes |
|---|---|---|
| Ring 0+1 ship-surface | PASS | dry-run lists `bin/dmc`, `bin/lib/**`, `orchestration/{roles,models,harness-matrix}.json` and (per `--host`) the Codex adapter executables + 5 `.agents/skills/dmc-*` mirrors + `.codex` templates; real `--host claude` install yields a runnable host `bin/dmc`; seeded Ring-0-omission ⇒ doctor non-zero "Ring-0 missing" (roundtrip 83/0) |
| P19 fixes falsified vs pre-fix | PASS | (a) real install prints NO "(dry-run)" while `--dry-run` does; (b) double-install ⇒ exactly ONE CLAUDE.md HTML section + one `# DMC:BEGIN..# DMC:END` block; (c) single-quote-in-path install succeeds post-fix (`act()` argv-passthrough, no `eval`) — the true eval falsifier (idempotency 17/0 + roundtrip 83/0) |
| Byte-clean round-trip (5 fixtures) | PASS | install→uninstall on empty/node (created case) leaves the host tree byte-identical (`git status --porcelain` empty; `diff -r` clean, empty scaffold dirs pruned); existing-claude-settings/existing-OMC/existing-codex (merge/skip, canonical-form) byte-restored; receipt host-local + removed LAST; the pre-fix dead-`skip` and no-CLAUDE.md-removal negative controls assert ZERO residual DMC lines |
| `.codex` provenance coherence | PASS | foreign `.codex` (no sentinel) ⇒ install skip-with-warn, byte-unchanged, uninstall never touches it; fresh→install codex (creates `.codex`, drops `# DMC-CREATED` sentinel, records paths)→install codex again (DMC signal ⇒ idempotent re-affirm, no skip-warn)→uninstall removes DMC's own `.codex`+sentinel+receipt ⇒ byte-clean; foreign-untouched negative control holds |
| doctor honesty (Claude PROVEN / Codex ADVISORY) | PASS | Claude synthetic-event probe reports firing PROVEN + an ENFORCED matrix row; Codex reports config/trust + skills/AGENTS.md discovery + an ADVISORY hook row + pre-commit/CI boundary; matrix per-host (each line one host); mode `active` reported host-independently, never on a Codex line; nc1 missing-python3 FAILs interpreter, nc2 unregistered-hook FLAGS wiring gap, nc3 foreign-harness→passive (advisory, exit 0), nc4 seeded "Codex enforced" line ⇒ scoped grep FAILs (control has teeth) |
| P20 correctness + Ring-0 model-name-free | PASS | harness-matrix.json carries all 8 §3 rows harness-id-only; models.json is the sole model-name carrier (6 capability classes) and read by no gate; narrow-detector self-scan clean modulo the enumerated `dmc-roles.py:394` fixture exclusion; seeded `codex-5` token trips the detector (non-vacuous); models.json excluded from the scan surface by design (carries 6+ model tokens, which is why it is excluded) |
| Full-manifest drift + dangling-reference | PASS | `--emit-manifest`==committed INSTALL_MANIFEST.md byte-for-byte; both hand-authored safety sections present so deletion cannot pass the drift test (the generator re-emits them); dangling-ref scan over the installed ship-surface finds NO shipped file referencing an unbundled `.md` (24 references, provenance exclusions honored; DMC-internal READMEs/evidence not shipped) |
| Codex hook-trust never bypassed | PASS | `dmc-install.sh` source contains ZERO `--dangerously-bypass-hook-trust`; Codex wiring surfaces the manual `/hooks` content-hash trust step + the "firing unproven at codex-cli 0.132.0 / ADVISORY" wording + names the pre-commit/CI gate; Option B referenced as a separate human gate, not invoked |
| No live/network paths, hermetic, fast default | PASS | install/uninstall/doctor sources carry zero network/model/API/credential primitive (word-bounded `nc`, python primitives included); every fixture runs in `mktemp` and each suite re-asserts the real repo `git status --porcelain` byte-identical; fast default still 75/0 |
| A1/A2/A3 dispositions as implemented | PASS | A3 (mandatory): `.codex/.dmc-created` sentinel is committed, NOT in the DMC `.gitignore` block (verified in `print_gitignore_block`), while the receipt IS gitignored; A1: receipt-absent fallback removes the fixed-name Ring-0 surface with a printed honest residual (does not remove `.codex`, cannot disambiguate a host's own `dmc-`-prefixed files); A2: the byte-clean claim is hedged below |
| Committed-replica --all == pinned baseline + new sections | PASS | legacy aggregate EXACTLY tools=49 PASS=802 FAIL=3 N/A=3 (accepted: v0.1.3 GLM-grep, v0.2.3 V5, v0.3.2 AC5) + originals-alone reproduce 802/3/3; run-core 168/0, loop-core 78/0, roles 19/0, verdict-validate 16/0, verdict-gate 9/0, delegation 29/0, linkcheck 17/0, m6-core 99/0 (bash-radius 50 + postbash-diff 25 + verify-crosscheck 13 + stop-gate 11), m6-suite 104/0 (adversarial 38 + compat 45 + e2e-ultrawork 10 + restore 11), skills-mirror 7/0, agents-md 24/0, m65-suite 119/0 (codex-shims 65 + skills-mirror 19 + agents-md 35), NEW doctor 24/0, NEW m8-suite 126/0; mirror-check + rollback + test-restore byte-identical to pinned `2999870`; a whole-log FAIL scan finds zero real FAIL markers; SELFTEST-ALL RESULT: PASS, exit 0 |
| Real repo untouched by replica work | PASS | before: HEAD 82300bda, porcelain-sha `d1484f5c…`; after: HEAD 82300bda unchanged, no `m8-replica`/scratchpad path leaked into the repo, and porcelain excluding the two authored T013.5 deliverables is byte-identical to `d1484f5c…`; replica built by tar pipe into the scratchpad (`.git` preserved so the pinned pre-M6 commit resolves), committed + selftested there only |
| Human gate provenance | PASS | wjlee via AskUserQuestion (Rev 3 milestone approval, "승인 — Rev 3 그대로"); the r3 verdict binds the pre-approval bytes `dd8e23d7…`; the approval record and its advisory disposition (A1/A2/A3) are recorded in the plan §Approval Status |
| Authoring/verification lane separation (C11) | PASS | this report is the implementer's evidence record; it makes no approval and opens no gate; completion is the Verifier's call and release the human gate's |

## Scope Review

Result: PASS

Notes:
All applied edits lie within the `dmc-run-03cba8c2797c` scope.lock (14-file allowlist). `git diff
--name-only` accounting — the five tracked modified files are `.claude/install/dmc-install.sh`,
`.claude/install/dmc-uninstall.sh`, `INSTALL_MANIFEST.md`, `bin/dmc` (all four IN the lock, edit grant),
and `.harness/plans/dmc-v1-runtime-upgrade.md` (the master-plan §Approval-Status pre-run orchestration
edit — OUTSIDE this build's file allowlist by design, a plan artifact not a build output). The in-lock
untracked creates present are `bin/lib/dmc-doctor.py`, `orchestration/{models,harness-matrix}.json`, and
`tests/fixtures/m8/{_m8common,test-install-roundtrip,test-idempotency,test-doctor-negcontrols,
test-manifest-drift}.sh` — all 9 in scope. The two authored T013.5 deliverables complete the 14.

No protected surface was edited: `.claude/hooks/**`, `.claude/settings.json`, worker validators (M7),
and provider adapters were not touched — the installer READS `bin/**`, `adapters/**`, `.agents/**`,
`.codex/**`, and `orchestration/roles.json` as copy SOURCES and edits none of them (assumption verified:
those paths are frozen at HEAD, not in this build's diff). `bin/dmc` carries the milestone's SOLE
`bin/dmc` edit (single-owner rule).

DMC-internal local-only artifacts per policy (crosscheck-exempt `.harness/{evidence,verification,runs}/`):
the four `.harness/runs/dmc-run-*/` state dirs, the auto-logged `.harness/evidence/dmc-run-*.md` ledgers,
the persisted `.harness/evidence/dmc-v1-m8-critic-verdict-r{1,2,3}.json`, and
`.harness/runs/dmc-v1-m{3,4,5}-20260706.md`. Two dirty paths sit OUTSIDE both this build's allowlist AND
the crosscheck's exempt prefixes: `.harness/plans/dmc-v1-runtime-upgrade.md` (master-plan approval update)
and `.harness/plans/dmc-v1-m8-host-install.md` (the approved M8 plan itself) — both pre-run orchestration
artifacts awaiting the phase commit, not build outputs. `verify-crosscheck` flags the first as undeclared
(the refusal recorded in Unresolved Risks); the second is not flagged only because it shares this report's
basename and is self-excluded by the crosscheck — it is equally out-of-lock, not a real declaration.

## Package / Env / Migration Review

Package files changed: no
Env files changed: no
Migration files changed: no

Notes: no dependency manifest, environment file, or DB migration touched. No network / live / model / API
call anywhere in install, uninstall, doctor, or verification (grep-verified). No secret file contents
opened — secret cases decide by path only, and the doctor is offline.

## Unresolved Risks

- A2 hedge (byte-clean scope, recorded honestly): the byte-clean round-trip proves the host WORKING TREE
  is byte-restored for the fixtures (the uncommitted-install case: `git status --porcelain` empty,
  `diff -r` clean). It does NOT claim `git status` is clean in the scenario where a host COMMITTED the DMC
  control plane (`bin/`, `orchestration/`, `.codex`) between install and uninstall — there, uninstall
  removes the now-tracked files and leaves deletions the host must itself commit. Merge byte-restoration
  is likewise canonical-form only: a non-canonical host `settings.json`/`.gitignore` is restored
  SEMANTICALLY (host content preserved, DMC additions removed), not guaranteed byte-identical.
- Codex hook firing + envelope honoring remain UNPROVEN (turn-free unprovable at codex-cli 0.132.0) —
  accepted by design under Option A: the shims are ADVISORY, the pre-commit/CI gate is the Codex
  enforcement boundary, and the M6 post-Bash diff guard is the primary net. doctor reports this honestly;
  making the boundary real is M9; Option B (a consented live-turn verification) is a separate human gate,
  not invoked here.
- `dmc mirror-check` on a host: shipping `bin/lib/**` into a host without the `.harness/evidence`
  originals would fail `mirror-check` there — but mirror-check is a DMC-development/CI invariant, not a
  host gate; host post-install verification is `dmc doctor` + functional smoke, not `--all`. Recorded in
  doctor's scope note and the build evidence.
- verify-crosscheck verdict against the SUSPENDED build run on the not-yet-committed working tree,
  recorded verbatim and NOT gamed (exit 3):
  `REFUSED: CROSSCHECK-UNDECLARED-CHANGED-FILE: a dirty worktree path is not declared under Changed Files
  (.harness/plans/dmc-v1-runtime-upgrade.md)`. The crosscheck's changed-files integrity check exempts only
  `.harness/{evidence,verification,runs}/`, so the dirty `.harness/plans/dmc-v1-runtime-upgrade.md`
  (master-plan §Approval-Status pre-run edit) is flagged as undeclared. The second dirty plan file,
  `.harness/plans/dmc-v1-m8-host-install.md` (the approved M8 plan), is NOT flagged only because it shares
  the basename `dmc-v1-m8-host-install.md` with THIS report and the crosscheck self-excludes any path whose
  basename equals the report's — a benign coincidence of the milestone slug, not a real declaration; it too
  is an out-of-lock pre-run artifact. This single refusal is the designed suspend/wait-state hold (M6/M6.5
  precedent): the plan files are not build outputs and clear at the phase commit, which is a separate human
  release gate explicitly NOT taken here. Declaring them in Changed Files would only convert the refusal to
  CHANGED-FILE-OUT-OF-SCOPE (they are not in the 14-file lock), and committing them is a human gate — so the
  honest disposition is to record the refusal, not defeat it.

## Final Status

PASS — every REQUIRED plan Verification Command passed on independent re-execution: the ship-surface and
P19 fixes are falsified against their pre-fix behavior, the five-fixture install→uninstall round-trip is
byte-clean, the `.codex` provenance sequence is coherent and non-destructive, `dmc doctor` reports each
host honestly (Claude PROVEN / Codex ADVISORY, per-host matrix, host-independent mode, Codex-scoped
forbidden-lexeme control with teeth), the P20 data files are correct and keep Ring-0
model-version-name-free, the generated manifest is byte-equal and deletion-proof, no live/network/secret
path exists, the fast default holds at 75/0, and the committed-replica `selftest --all` reproduces the
pinned baseline (legacy 802/3/3 EXACT) with every prior section plus the new `doctor` (24/0) and
`m8-suite` (126/0) at 0 FAIL and SELFTEST-ALL exit 0. The verify-crosscheck REFUSE on the two
`.harness/plans/*` pre-run artifacts is a disclosed, expected pre-commit hold — recorded verbatim, not
gamed — and does not fail any required plan criterion. The phase commit and release remain the human
gate's call; this report claims neither.
