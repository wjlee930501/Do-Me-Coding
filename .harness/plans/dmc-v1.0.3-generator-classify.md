# Plan — v1.0.3 generator & classification hardening (root-cause the §7 regen loss; .codex classification; registered schema reword)

Work ID: dmc-v1.0.3-generator-classify
Rev: 2 (critic r1 REJECT → B1 fixed: §7 emission is PRESENCE-GATED so the shipped generator adds
nothing on hosts lacking the companion docs — dangling-reference discipline preserved; negative +
positive module-selftest rows added; r1 advisories 1–5 folded)

## Goal

Three registered stabilization/universality items, one cycle: (1) make `bin/lib/dmc-agents-md.py`
emit the §7 "Companion context docs" pointer paragraph NATIVELY — the regeneration has dropped the
hand-added paragraph THREE times (M10, hygiene cycle, Option-B cycle), each time caught only by
the standing hand-re-add rule + the frozen v0.4.7 AC6 audit; this removes the regression class at
its root cause. (2) Add a `.codex/` rule to `classify_landmark()` in `bin/lib/dmc-repo-intel.py`
— shipped Codex wiring currently classifies `ordinary` although `.claude/settings.json` (its
structural twin) is `enforcement` and `.codex/` is already one of the six protected bindings in
the generator's `DMC_BINDINGS`; post-change, future scope.locks touching `.codex/` require
explicit landmark authorization. (3) Execute the REGISTERED deferral (MILESTONES hygiene entry):
reword `.harness/schemas/landmarks.schema.md:33-34`'s stale seed-union prose (still names the
removed `dmc-glm-smoke`). Label v1.0.3; identity stays "Do-Me-Coding v1.0".

## User Intent

refactor (stabilization/universality hardening; one bugfix-class root-cause, one classification
gap, one registered doc-contract reword)

Overnight autonomy envelope ratified by wjlee (2026-07-09 AskUserQuestion, pre-sleep; recorded in
full in `.harness/plans/dmc-v1.0.2-router-anchor.md` §User Intent and ruled III.2(3)-compatible by
the v1.0.2 critic r1): cycle menu item "v1.0.3 생성기·분류 견고화" ratified by name — generator §7
native emission + `.codex` classification + the landmarks.schema.md:34 registered reword.
AUTONOMY.md autonomous-local-commit on `claude/dmc-v102-v104-overnight`; critic APPROVE mandatory
(≤3 rounds else SKIP); independent verifier + replica/live 802/3/3 mandatory; LOCAL commit only —
push/CI/main-FF are morning human gates.

## Current Repo Findings

(scout lane 2026-07-09, Sonnet explorer; all quotes machine-verified)

- Finding: §7 is built by `render_sections()` (`bin/lib/dmc-agents-md.py:302-320`) as a HARDCODED
  list of lines — the generator emits NO companion-docs paragraph; the committed AGENTS.md carries
  it only as a hand-insert (the 3×-reproduced loss). Hardcoded-prose precedent exists in the same
  module (§9 stop-conditions block, `SECRET_PATTERNS`, `DMC_BINDINGS`). Minimal edit: insert the
  paragraph lines between `"Core loop: …"` and `"Non-negotiable rules:"` in the `_section(7, …)`
  call.
  Source: `bin/lib/dmc-agents-md.py:302-320,17,77-85,328-336`.
- Finding: The exact committed paragraph (AGENTS.md:237-240) must be reproduced byte-identically.
  CAUTION (critic r1 advisory 1): the wrap points quoted in any prose — including THIS plan — are
  not authoritative; committed line 239 ends "…READ BEFORE any substantial" and line 240 is
  "change; amendment rules within)." with NO trailing spaces (od -c verified by the critic). The
  executor MUST take the 4-element line split from the committed file bytes, never from a plan
  quote. The zero-§7-hunk AC is the backstop.
  Source: `AGENTS.md:237-240`; critic r1 verdict.
- Finding (critic r1 B1 — the load-bearing constraint): `bin/lib/dmc-agents-md.py` SHIPS to hosts
  (`dmc-install.sh:295` ships every `bin/lib/*` file), while NONE of the three companion docs
  ships (`SUPPORT_DOCS` = the three HOST_REPO/OMC docs; no `AUTONOMY.md` / `docs/CONTEXT_MAP.md` /
  `docs/DMC_CONSTITUTION.md`). An UNCONDITIONAL §7 paragraph would make every host-generated
  AGENTS.md dangle-reference three nonexistent files — violating the generator's own
  facts-not-guesses charter, the INSTALL_MANIFEST dangling-reference discipline, and the
  Constitution Preamble's recorded decision that a host-shipping constitution breadcrumb is a
  future-amendment candidate DELIBERATELY not shipped — with ZERO machine tripwire (the m8
  dangling scan excludes bin/lib; linkcheck and test-agents-md.sh never inspect §7). The emission
  is therefore PRESENCE-GATED (see Proposed Changes).
  Source: critic r1 verdict; `.claude/install/dmc-install.sh:295`; `tests/fixtures/m8/test-manifest-drift.sh:101-103`.
- Finding: NO validation surface constrains §7 prose: `validate_doc()`/`agents-md.schema.md` check
  section presence/non-empty/filler-tokens only; `tests/fixtures/m6.5/test-agents-md.sh` (24/0)
  never inspects §7 body (its only §7 reference is an awk section-cut for a §6 negative control);
  the module selftest has no §7-content row. The frozen v0.4.7 AC6 substring-greps `AUTONOMY.md` +
  `CONTEXT_MAP.md` anywhere in AGENTS.md — natively-emitted pointers satisfy it PERMANENTLY.
  Source: scout Q2 (quotes); `.harness/evidence/dmc-v0.4.7-context-audit.sh:51-53`.
- Finding: `classify_landmark()` (`bin/lib/dmc-repo-intel.py:272-291`) has no `.codex/` rule —
  `.codex/config.toml`/`.codex/hooks.json` classify ordinary and are absent from AGENTS.md §4/§5
  today. The DMC repo's `.codex/` tracks exactly those 2 files (no `.dmc-created` — host-install
  only). `selftest_landmarks()` has 11 rows incl. the L1f negative control; a new positive row
  (L1g: `.codex/config.toml` → enforcement) makes 12. The release-gate `ST_LANDMARKS` fixture is a
  static hand-built dict — unaffected. `dmc-scope-lock.py:231` then REFUSES future `.codex/`
  grants lacking `landmark_authorized: true` (the desired hardening). Class choice `enforcement`
  matches `.claude/settings.json`'s treatment and the `DMC_BINDINGS` protected-bindings constant.
  Source: `bin/lib/dmc-repo-intel.py:272-291,600-634`; `bin/lib/dmc-release-gate.py:835`;
  `bin/lib/dmc-scope-lock.py:231`; `bin/lib/dmc-agents-md.py:85`.
- Finding: `.harness/schemas/landmarks.schema.md` is NOT a generated mirror — the mirror set is
  exactly {plan, run, verification} (`bin/lib/dmc-instance-validate.py` MIRRORS dict); no root
  LANDMARKS_SCHEMA.md exists; the file is its own canonical home, directly editable in an Art. III
  cycle (II.5 lane — this plan + envelope + critic + verifier IS that cycle; the item was ratified
  BY NAME in the envelope menu). Current lines 33-34: "The seed union includes the historical DMC
  protected set (hooks, settings, providers, install, `dmc-glm-smoke`) so no legacy-protected path
  silently declassifies (audit §5 note)." The registered deferral (docs/MILESTONES.md:662)
  prescribes the reword: "historically included …, removed by the human-gated hygiene cycle
  2026-07-08".
  Source: scout Q4; `docs/MILESTONES.md:662`.
- Finding: No CI step, doc, or fixture asserts on §7 text, classify results, or the schema line;
  the only other `dmc-glm-smoke` classify-path mentions are frozen v0.x historical scripts
  (must-not-edit, out of scope). AGENTS.md must be REGENERATED in this cycle (its §4/§5 gain the
  2 `.codex` rows; §7 must show a ZERO diff — proving native emission reproduces the hand-added
  bytes). This cycle's diff touches NO path in the frozen v0.2.6 gate runner's DEFAULT_PROTECTED
  list — NO G4 override is needed (unlike v1.0.1/v1.0.2).
  Source: scout Q5; `bin/lib/dmc-v0.2.6-gate-check-runner.sh:22-31`.

## Relevant Files

| Path | Reason | Allowed to Edit |
|---|---|---|
| `bin/lib/dmc-agents-md.py` | §7 native paragraph emission (4 lines in the `_section(7,…)` list) | yes |
| `bin/lib/dmc-repo-intel.py` | `.codex/` → enforcement rule + new L1g selftest row | yes |
| `.harness/schemas/landmarks.schema.md` | registered one-line seed-union reword (canonical, not a mirror) | yes |
| `AGENTS.md` | regenerate (§4/§5 +2 `.codex` rows; §7 diff MUST be zero) | yes (regen) |
| `docs/MILESTONES.md` | ONE v1.0.3 closure entry (append-only) | yes (append) |
| `tests/fixtures/m6.5/test-agents-md.sh` | unaffected per scout — no edit | no |
| `bin/lib/dmc-release-gate.py`, frozen v0.x tools, `.before-dmc` | untouched | no |

## Out of Scope

- Any AGENTS.md DMC-priority clause (registered future candidate — not in the ratified menu).
- Any change to the five-class enum, the landmarks JSON shape, or validate_landmarks.
- Editing frozen v0.x scripts that mention dmc-glm-smoke historically.
- Push / CI / main FF (morning gates); the other overnight cycles.

## Proposed Changes

- Change: `bin/lib/dmc-agents-md.py` — the §7 companion-docs paragraph is emitted
  PRESENCE-GATED: a small helper checks the SCANNED ROOT for ALL THREE companion docs
  (`AUTONOMY.md`, `docs/CONTEXT_MAP.md`, `docs/DMC_CONSTITUTION.md`; os.path.isfile, atomic
  all-or-nothing); when present, the `_section(7, …)` list includes the committed paragraph's 4
  lines VERBATIM (line split taken from the committed AGENTS.md bytes — critic advisory 1);
  when any is absent (every host install), the paragraph is omitted entirely — host output
  unchanged, no dangling references. PLUS two new module-selftest rows: a POSITIVE row (a tmp
  fixture carrying the three docs → generated §7 contains the paragraph) and a NEGATIVE row (a
  fixture without them → paragraph absent; the host-shape proof). Module selftest 24/0 → 26/0
  (no exact-count assertion exists; `bin/dmc selftest` gates on 0 FAIL).
  Files: `bin/lib/dmc-agents-md.py`.
  Rationale: root cause retired IN THE DMC REPO (the only place the docs exist) while the shipped
  generator stays honest on hosts (critic r1 B1); the presence check is the generator's native
  facts-driven idiom.
- Change: `bin/lib/dmc-repo-intel.py` — add `or rel.startswith(".codex/")` to the enforcement
  branch of `classify_landmark()` (keeping the reason string unchanged) + add selftest rows L1g
  asserting BOTH tracked `.codex` files (`config.toml` AND `hooks.json`) classify enforcement
  (11→13 rows; critic advisory 2).
  Files: `bin/lib/dmc-repo-intel.py`.
  Rationale: shipped wiring gets landmark protection; future `.codex/` edits need explicit
  landmark authorization in scope.locks; closes the registered classification gap.
- Change: `.harness/schemas/landmarks.schema.md:33-34` seed-union bullet reworded per the
  registered deferral: the set is described as "historically included" with `dmc-glm-smoke` noted
  as "removed by the human-gated hygiene cycle 2026-07-08" — same bullet shape, no rule-semantics
  change (the validator enforces shape/enum only, not this prose).
  Files: `.harness/schemas/landmarks.schema.md`.
- Change: Regenerate `AGENTS.md` via `bin/dmc agents-md --stdout` + Write (generator refuses
  in-place): expected diff = EXACTLY the 2 new `.codex` rows in §4 and the §5 enumeration —
  and NO §7 hunk (native emission reproduces the committed paragraph byte-identically; this
  assertion IS the root-cause proof).
  Files: `AGENTS.md`.
- Change: Append ONE `docs/MILESTONES.md` v1.0.3 closure entry (defect class retired, `.codex`
  classification, schema reword execution — closing that registered deferral, envelope
  provenance, morning-gate pending lines).
  Files: `docs/MILESTONES.md`.

## Acceptance Criteria

- Criterion: §7 regen-loss class retired at root cause — IN THIS REPO ONLY (hosts unchanged).
  Verification Method: fresh `bin/dmc agents-md --stdout` (DMC repo) contains the paragraph
  WITHOUT any hand edit; regenerated AGENTS.md diff shows NO §7 hunk; the NEGATIVE module-selftest
  row proves a doc-less fixture's output OMITS the paragraph (host-shape proof); frozen
  `bash .harness/evidence/dmc-v0.4.7-context-audit.sh --self-test` → 7/0;
  `bin/dmc agents-md --validate AGENTS.md` → VALID; module selftest 26/0;
  `bash tests/fixtures/m6.5/test-agents-md.sh` → 24/0 unchanged (file not edited).
- Criterion: `.codex/` classified enforcement, machine-checked end-to-end.
  Verification Method: `bin/dmc selftest landmarks` → 13/0 with the new L1g rows (BOTH files)
  PASSing and L1f (glm-smoke absent) still green; regenerated AGENTS.md §4 lists
  `.codex/config.toml` + `.codex/hooks.json` as enforcement and §5 includes both; a sandbox
  scope-lock drill whose landmarks input is generated by the LIVE classifier (`dmc landmarks`,
  not hand-declared — critic advisory 3) REFUSES an unauthorized `.codex/hooks.json` grant
  (SCOPE-LOCK-LANDMARK-UNAUTHORIZED), proving rule→map→refusal end-to-end.
- Criterion: Registered schema reword executed exactly.
  Verification Method: one-bullet diff in `.harness/schemas/landmarks.schema.md`; wording carries
  "historically included" + "removed by the human-gated hygiene cycle 2026-07-08";
  `bin/dmc landmarks --validate` self-surface unaffected (run `bin/dmc selftest landmarks`);
  schemas-mirror selftest 15/0 (file is not in the mirror set); `bin/dmc linkcheck` clean.
- Criterion: No suite/frozen regression.
  Verification Method: `bin/dmc selftest` 0 FAIL; `bin/dmc selftest m65-suite` green;
  `bin/dmc mirror-check` PASS; `bash tests/fixtures/m6.5/test-codex-shims.sh` 143/0 (v1.0.2
  baseline holds).
- Criterion: Full gate PASS; frozen baseline intact; LOCAL commit only.
  Verification Method: green set + `dmc gate release --full` → PASS (landmark FLAG expected on
  the bin/lib + schema + MILESTONES paths; NO G4 override needed — no DEFAULT_PROTECTED path in
  the diff); committed-replica AND live `bin/dmc selftest --all` → legacy **802/3/3 EXACT**; one
  LOCAL commit on the overnight branch; push/CI/FF PENDING-BY-ENVELOPE.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Generator line-joining renders the paragraph with different wrap bytes than the hand-added copy | medium | executor diff-proves byte-identity on regen (the AC); if the generator's renderer joins lines differently, match the list-element boundaries to the committed wrap points exactly |
| `.codex` classification surprises a future cycle (unexpected landmark_authorized requirement) | low | that is the intended hardening; MILESTONES entry announces it; scope-lock REFUSE message is explicit |
| Schema prose reword drifts from the registered wording | low | MILESTONES:662 prescribes it; critic checks verbatim |
| AGENTS.md regen introduces unrelated churn | low | diff must be exactly §4/§5 rows (+2) with zero §7 hunk; verifier asserts |

## Assumptions

| Assumption | Confidence | How to Verify |
|---|---|---|
| The generator's `_section` renderer joins list lines 1:1 (no re-wrapping) | high | read `_section`; drill one regen and diff |
| The envelope covers a II.5 contract-surface amendment (schema reword ratified by name) | high | critic adjudicates; SKIP on REJECT |

## Execution Tasks

- [ ] DMC-T001: Generator §7 PRESENCE-GATED emission (paragraph bytes from the committed file;
  all-three-docs check) + the positive/negative module-selftest rows (24→26) + regen
  byte-identity proof + AC6/validate/fixture-suite runs.
  Files: `bin/lib/dmc-agents-md.py`.
  Notes: Route: Opus 4.8, synchronous.
- [ ] DMC-T002: `.codex/` classification + L1g rows (both files, 11→13) + landmarks selftest 13/0
  + live-classifier-fed scope-lock REFUSE drill (sandbox).
  Files: `bin/lib/dmc-repo-intel.py`.
  Notes: Route: Opus 4.8, synchronous.
- [ ] DMC-T003: Schema reword (registered wording) + AGENTS.md regen (after T001+T002; §7
  zero-hunk + §4/§5 +2 rows) + MILESTONES v1.0.3 entry.
  Files: `.harness/schemas/landmarks.schema.md`, `AGENTS.md`, `docs/MILESTONES.md`.
  Notes: Route: Sonnet 5, synchronous; depends on T001+T002.

## Verification Commands

| Command | Reason | Required |
|---|---|---|
| fresh `bin/dmc agents-md --stdout` contains the paragraph; regen diff has no §7 hunk; NEGATIVE fixture row omits it | root-cause proof + host-shape proof (r1 B1) | yes |
| `bash .harness/evidence/dmc-v0.4.7-context-audit.sh --self-test` | frozen AC6 7/0, natively satisfied | yes |
| `bin/dmc agents-md --validate AGENTS.md` + `bash tests/fixtures/m6.5/test-agents-md.sh` | VALID + 24/0 | yes |
| `bin/dmc selftest landmarks` | 13/0 (L1g both files, L1f still green) | yes |
| sandbox scope-lock compile, landmarks input from the LIVE classifier, unauthorized `.codex` entry | REFUSES end-to-end (hardening proof) | yes |
| `bin/dmc selftest` + `m65-suite` + `mirror-check` + `linkcheck` + `test-codex-shims.sh` | no regression (143/0 holds) | yes |
| `dmc gate release --full --run-id <run>` | PASS, FLAG recorded, NO override needed | yes |
| committed-replica + live `bin/dmc selftest --all` | legacy **802/3/3 EXACT** | yes |
| LOCAL commit; no push | AUTONOMY.md compliance | yes |

## Approval Status

Status: APPROVED
Approver: wjlee (woojin20020@gmail.com)
Approved At: 2026-07-09 (overnight autonomy envelope, AskUserQuestion pre-sleep — cycle menu item
"v1.0.3 생성기·분류 견고화" ratified by name incl. the landmarks.schema.md:34 reword; envelope ruled
III.2(3)-compatible by the v1.0.2 critic r1 adjudication; push/CI/FF reserved to morning gates)
