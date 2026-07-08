# Plan — v1.0.4 Codex interop & coexistence documentation (Option-B observations recorded into the operating docs)

Work ID: dmc-v1.0.4-codex-coexistence-docs

## Goal

Close the four documentation gaps the Option-B cycle registered, WITHOUT any tier change: (1) a
Codex-side coexistence section in the SHIPPED `docs/OMC_COEXISTENCE.md` (oh-my-codex/OMX and the
omo plugin are named nowhere in-repo although both are live global-hook contenders on this very
machine; the observed foreign-layer mutation of a project `.codex/config.toml` mid-session is a
recorded fact with no doc home); (2) an Option-B observations addendum in the repo-internal
`docs/CODEX_ADAPTER.md` (the design authority still carries claims the 2026-07-09 live turns
superseded — notably the "tool_input field names TBD-STILL" bullet); (3) the IV.3 ledger append
in `docs/DMC_V1_HONEST_SCOPE.md` (the disclosure ledger must record the observed-on-cli status,
the App-surface trust-affordance gap, and the dated closure of the M6.5 item-10(e) premise —
posture and every tier claim UNCHANGED, per the ratified D5 no-promotion boundary); (4) the
MILESTONES v1.0.4 entry. Label v1.0.4; identity stays "Do-Me-Coding v1.0". This is the third and
final overnight-envelope cycle.

## User Intent

docs

Overnight autonomy envelope ratified by wjlee (2026-07-09 AskUserQuestion, pre-sleep; ruled
III.2(3)-compatible by the v1.0.2 critic r1; recorded in full in the v1.0.2 plan §User Intent):
cycle menu item "v1.0.4 Codex 연동·공존 문서화" ratified by name — OMC_COEXISTENCE Codex section
(incl. the observed foreign-layer config mutation), CODEX_ADAPTER App observations + envelope
schema + CLI /hooks trust path, HONEST_SCOPE disclosure append (no promotion, lexeme discipline).
AUTONOMY.md autonomous-local-commit on `claude/dmc-v102-v104-overnight`; critic APPROVE mandatory;
independent verifier + replica/live 802/3/3 mandatory (envelope binds even for a docs cycle);
LOCAL commit only — push/CI/main-FF are morning human gates.

## Current Repo Findings

(scout lane 2026-07-09, Sonnet explorer; all quotes machine-verified)

- Finding: `docs/OMC_COEXISTENCE.md` IS SHIPPED (`SUPPORT_DOCS`, `dmc-install.sh:50-51,400`), so
  the dangling-reference discipline (`INSTALL_MANIFEST.md:295-309`) binds new content: NO new
  host-operating dependency on `.harness/evidence/*` or `docs/DMC_V1_HONEST_SCOPE.md` (which does
  NOT ship). The doc's OWN precedent at `:72-74` ("see `docs/DMC_V1_HONEST_SCOPE.md` for the
  disclosed caveat") is the permitted provenance-breadcrumb pattern — new references MUST mirror
  it (breadcrumb a host never navigates to), never a hard dependency.
  Source: `.claude/install/dmc-install.sh:50-51,184-209,400`; `INSTALL_MANIFEST.md:283-309`.
- Finding: `docs/OMC_COEXISTENCE.md` (74 lines) has ZERO Codex mentions; its section order ends
  with `## Hook coexistence audit` (with an "> Observed:" callout idiom at :61-64) and
  `## Precedence when both fire` (:66-74, the v1.0.1 precedence clause: instruction-level
  best-effort, not a runtime boundary). A new `## Codex coexistence` section lands after it,
  extending — not duplicating — the precedence framing.
  Source: scout Q2 (full-file read).
- Finding: `docs/CODEX_ADAPTER.md` is NOT shipped (named in "DELIBERATELY NOT COPIED",
  `INSTALL_MANIFEST.md:283-290`) — no host dangling-reference exposure. Its M6.5 spike addendum is
  the final section (:172-225) with an established tag vocabulary (VERIFIED-OFFICIAL / SECONDARY /
  UNVERIFIED-ASSUMPTION legend at :16; inline `[SPIKE-CORRECTED 2026-07-06: …]` /
  `[SPIKE-CONFIRMED 2026-07-06 turn-free: …]` tags). An Option-B addendum lands after :225 with a
  parallel, non-overlapping tag family (`[OPTION-B-OBSERVED 2026-07-09: …]`), and the now-stale
  "tool_input field names" claim (~:212 region) gets an INLINE dated tag pointing at the captured
  schema rather than being silently rewritten.
  Source: scout Q2; `docs/CODEX_ADAPTER.md:16,26-28,172-225`.
- Finding: `docs/DMC_V1_HONEST_SCOPE.md` is NOT shipped. The IV.3 ledger append point is §4
  "Disclosed residual register" (:65-68); the new disclosure must stay consistent with the §4
  DMC-priority caveat (:70-73, "instruction-level best-effort … NOT a runtime boundary") and the
  M6.5 item-10 sub-bullets (:82-87), of which (e) ("`.codex/hooks.json` wiring shape + per-tool
  `tool_input` field names remain UNPROVEN … re-probe at an Option-B turn or a newer CLI") is now
  factually superseded — the honest form is a dated closure sub-note under that bullet (append,
  never silently drop) plus the new register entries.
  Source: scout Q3; `docs/DMC_V1_HONEST_SCOPE.md:65-87`.
- Finding: The doctor forbidden-marker set (`bin/lib/dmc-doctor.py:86-88`) has NO machine
  enforcement over `docs/*.md` (doctor self-test scans its OWN output; CI's CF3/AA1 greps scope
  to code/install paths, `dmc-ci.yml:125-152`) — the /codex/i-line word discipline is voluntary
  convention here, honored anyway ("dispatch observed", "honored in the observed session";
  never the forbidden whole words on codex-matching lines).
  Source: scout Q3-Q4 (quotes).
- Finding: None of the three docs is in linkcheck's 24-file scanned set — edits cannot trip it.
  Source: `bin/lib/dmc-orchestration-linkcheck.py:59-63,218-227`.
- Finding: The facts to record, with anchors the new prose cites and must not contradict:
  `docs/MILESTONES.md:667-694` (Option-B entry: cli 0.132.0 all-five-events dispatch + both
  envelope classes honored in the observed session; App 26.623 zero dispatch, no trust affordance
  for project hooks; Ring-2 respected; D5 no-promotion) and the handoff rev 12 block (envelope
  key-name schema; the foreign-layer LazyCodex/OMO mutation of the clone's `.codex/config.toml`,
  real repo byte-unchanged; the "observed-on-cli posture upgrade" is a REGISTERED FUTURE
  promotion candidate — this cycle documents, never promotes).
  Source: scout Q5 (verbatim quotes + anchors).

## Relevant Files

| Path | Reason | Allowed to Edit |
|---|---|---|
| `docs/OMC_COEXISTENCE.md` | SHIPPED support doc — new `## Codex coexistence` section (breadcrumb-pattern references only) | yes |
| `docs/CODEX_ADAPTER.md` | repo-internal design authority — Option-B addendum + inline dated tag on the superseded bullet | yes |
| `docs/DMC_V1_HONEST_SCOPE.md` | IV.3 ledger append (§4 entries + dated closure sub-note under item-10(e)) | yes |
| `docs/MILESTONES.md` | ONE v1.0.4 closure entry (append-only) | yes (append) |
| `docs/DMC_V1_ENFORCEMENT_MATRIX.md`, `bin/lib/dmc-doctor.py`, shims, installer | NO tier/posture/code change (D5) | no |
| `.harness/evidence/*`, frozen surfaces | referenced as breadcrumbs only where permitted; never edited | no |

## Out of Scope

- ANY enforcement-tier or posture change (ENFORCEMENT_MATRIX, doctor wording, shim docstrings) —
  the observed-on-cli promotion is a registered FUTURE cycle.
- Any code edit; any AGENTS.md change (generated; its DMC-priority clause is a registered
  candidate needing a generator-contract cycle).
- Editing the installer, INSTALL_MANIFEST, or the shipped `.codex/` templates.
- Push / CI / main FF (morning gates).

## Proposed Changes

- Change: `docs/OMC_COEXISTENCE.md` — append `## Codex coexistence` after the precedence section:
  (a) names oh-my-codex (OMX) and the omo plugin as OBSERVED global-hook contenders on a real
  Codex host (`~/.codex/hooks.json` global wiring; hook layers MERGE per the official model, so
  global and trusted project hooks both dispatch); (b) the trust prerequisite: project-level
  `.codex/hooks.json` needs one-time content-hash hook trust — granted via the CLI /hooks surface
  (trust state shared through `~/.codex`); an App build was observed NOT to surface project hooks
  for trust (so a Codex App session may run with the project hook layer dark while global layers
  stay live — coexistence asymmetry); (c) the OBSERVED foreign-layer fact: during a live session a
  third-party layer mutated the project's `.codex/config.toml` (model/reasoning +
  `multi_agent_v2` fields) — treat project Codex config as a surface other layers write to;
  keep it out of scope.locks unless granted, and diff it after foreign sessions; (d) precedence:
  the SAME instruction-level DMC-priority applies when the dmc suffix trigger routes on the Codex
  host (the UPS shim injects the identical priority context) — best-effort, not a runtime
  boundary, mirroring the existing clause and its breadcrumb reference verbatim-pattern.
  Files: `docs/OMC_COEXISTENCE.md`.
  Rationale: the shipped coexistence doc finally covers the second host; every claim is an
  in-repo recorded observation with a breadcrumb-lawful reference shape.
- Change: `docs/CODEX_ADAPTER.md` — new final section `## Option-B addendum — consented live-turn
  observations (cli 0.132.0 + App 26.623, 2026-07-09)` using an `[OPTION-B-OBSERVED 2026-07-09]`
  tag family: per-event dispatch observed 5/5 with both envelope classes honored in that session
  (deny surfaced and stopped the probe twice; routing context applied verbatim; mode-file side
  effect); the captured envelope top-level key-name schema (names only) and Bash
  `tool_input=["command"]`; the session's tool taxonomy surfaced everything as Bash/unified-exec
  (Edit/Read matcher groups received zero events); the App findings (no project-hook trust
  affordance in the Hooks panel → project layer skipped; global/plugin layers listed; Ring-2
  AGENTS.md guidance respected); the trust path (CLI /hooks; shared `~/.codex` state); posture
  line: observations only — the adapter remains ADVISORY with pre-commit/CI as the boundary, and
  any posture upgrade is a registered future gate. PLUS the inline dated tag on the superseded
  "tool_input field names" bullet in the spike addendum pointing forward to the new section.
  Files: `docs/CODEX_ADAPTER.md`.
- Change: `docs/DMC_V1_HONEST_SCOPE.md` — §4 register APPEND: (i) Option-B observed-on-cli record
  (one consented session, dated; tier claims unchanged; promotion = registered candidate);
  (ii) the App-surface trust-affordance gap (project hooks cannot be trust-armed from the
  observed App build; the CLI /hooks path is the workaround; re-test future builds);
  (iii) a dated closure sub-note under M6.5 item-10(e): the per-tool `tool_input` field-name
  premise is closed by the captured schema (anchor: the Option-B evidence + MILESTONES entry) —
  the original bullet text stays (append-never-drop).
  Files: `docs/DMC_V1_HONEST_SCOPE.md`.
- Change: Append ONE `docs/MILESTONES.md` entry: `## v1.0.4 — Codex interop & coexistence
  documentation — CLOSED (2026-07-09)` (what/where, the no-promotion boundary restated, the
  chain, morning-gate pending lines).
  Files: `docs/MILESTONES.md`.

## Acceptance Criteria

- Criterion: The shipped doc stays dangling-reference lawful.
  Verification Method: every new reference in `docs/OMC_COEXISTENCE.md` either resolves to a
  BUNDLED file or mirrors the `:72-74` breadcrumb pattern; a dry-run install scan
  (`bash .claude/install/dmc-install.sh <tmp-host> --host both --dry-run` + the m8 drift/dangling
  fixtures) stays green: `bin/dmc selftest m8-suite` → 0 FAIL.
- Criterion: The three doc updates record ONLY observations — zero tier-claim drift.
  Verification Method: `git diff` shows no edit to ENFORCEMENT_MATRIX/doctor/shims/installer;
  the added lines carry no forbidden whole word on any /codex/i line (grep the added lines with
  the `bin/lib/dmc-doctor.py:86-88` set); the HONEST_SCOPE §4 caveat (:70-73) and item-10 bullets
  remain present (append-only diff shape: additions + the one inline dated tag, no deletions of
  ledger lines).
- Criterion: Facts match the record.
  Verification Method: every factual claim in the new prose is checkable against
  `docs/MILESTONES.md:667-694` and the Option-B evidence; the superseded-bullet tag points at the
  new addendum; no contradiction with the §4 DMC-priority caveat.
- Criterion: No suite regression.
  Verification Method: `bin/dmc selftest` 0 FAIL; `bin/dmc selftest m65-suite` green;
  `bin/dmc selftest m8-suite` 0 FAIL; `bin/dmc mirror-check` PASS; `bin/dmc linkcheck` clean;
  `bash tests/fixtures/m6.5/test-codex-shims.sh` 143/0.
- Criterion: Full gate PASS; frozen baseline intact; LOCAL commit only.
  Verification Method: green set + `dmc gate release --full` → PASS (landmark FLAG expected on
  MILESTONES; no G4 override — docs paths are not in DEFAULT_PROTECTED); committed-replica AND
  live `selftest --all` → legacy **802/3/3 EXACT**; one LOCAL commit; push/CI/FF
  PENDING-BY-ENVELOPE.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| A new reference in the SHIPPED doc dangles on hosts | medium | breadcrumb-pattern rule in the AC + m8-suite dry-run scan green; the executor mirrors the existing :72-74 shape verbatim |
| Prose drifts into tier claims (promotion by wording) | medium | observed-status vocabulary mandated; lexeme grep on added lines; critic + verifier check against D5 |
| HONEST_SCOPE edit accidentally rewrites ledger history | low | append + one inline dated tag only; diff shape asserted (no deletions of existing ledger lines) |
| Facts contradict the Option-B record | low | anchors mandated; verifier cross-reads MILESTONES + evidence |

## Assumptions

| Assumption | Confidence | How to Verify |
|---|---|---|
| m8 dangling scan covers the shipped support docs' reference health | medium | run m8-suite; if its scan scope excludes OMC_COEXISTENCE content, the breadcrumb-pattern AC still binds via critic/verifier reading |
| The envelope covers this docs cycle (ratified by name) | high | carried ruling; SKIP on critic REJECT |

## Execution Tasks

- [ ] DMC-T001: `docs/OMC_COEXISTENCE.md` Codex section + `docs/CODEX_ADAPTER.md` Option-B
  addendum + inline dated tag (both docs in one lane — same fact base).
  Files: `docs/OMC_COEXISTENCE.md`, `docs/CODEX_ADAPTER.md`.
  Notes: Route: Opus 4.8, synchronous (wording-discipline-critical).
- [ ] DMC-T002: `docs/DMC_V1_HONEST_SCOPE.md` §4 register append + item-10(e) dated closure
  sub-note.
  Files: `docs/DMC_V1_HONEST_SCOPE.md`.
  Notes: Route: Opus 4.8, synchronous (ledger discipline).
- [ ] DMC-T003: MILESTONES v1.0.4 entry + suite runs.
  Files: `docs/MILESTONES.md`.
  Notes: Route: Sonnet 5, synchronous; depends on T001+T002.

## Verification Commands

| Command | Reason | Required |
|---|---|---|
| `bin/dmc selftest m8-suite` | shipped-doc reference health (drift/dangling fixtures) green | yes |
| lexeme grep of ALL added lines vs the doctor set | no forbidden whole word on /codex/i lines | yes |
| diff-shape assertion on HONEST_SCOPE (append + 1 inline tag; no ledger-line deletions) | IV.3 append-never-drop | yes |
| `bin/dmc selftest` + `m65-suite` + `mirror-check` + `linkcheck` + `test-codex-shims.sh` | regression floor (143/0 holds) | yes |
| `dmc gate release --full --run-id <run>` | PASS; FLAG on MILESTONES; no override | yes |
| committed-replica + live `bin/dmc selftest --all` | legacy **802/3/3 EXACT** | yes |
| LOCAL commit; no push | AUTONOMY.md compliance | yes |

## Approval Status

Status: APPROVED
Approver: wjlee (woojin20020@gmail.com)
Approved At: 2026-07-09 (overnight autonomy envelope, AskUserQuestion pre-sleep — cycle menu item
"v1.0.4 Codex 연동·공존 문서화" ratified by name; envelope ruled III.2(3)-compatible by the v1.0.2
critic r1 adjudication; push/CI/FF reserved to morning gates)
