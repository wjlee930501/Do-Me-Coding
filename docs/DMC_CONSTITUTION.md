# DMC Constitution — Repository Governance Law

**Status:** Founding text, ratified 2026-07-08 (docs-only governance commit; no version bump, no
`MILESTONES.md` entry — `.harness/plans/dmc-constitution.md:274-275`).

**This document is REPO-INTERNAL.** It is the top-level GOVERNANCE law for maintaining *this*
Do-Me-Coding repository. It is deliberately NOT shipped to host repos — the installer does not copy
`AGENTS.md` (`.claude/install/dmc-install.sh:373,417`) and `SUPPORT_DOCS`
(`.claude/install/dmc-install.sh:51`) ships only the three host-operating docs — so this file must
never be referenced from a shipped or machine-scanned surface (DMC.md, CLAUDE.md, adapters,
skills, agents), which would trip the dangling-reference rule (`.harness/plans/dmc-constitution.md:57-64`).

## Preamble

A future maintainer session — an Opus 4.8 (or successor) session that does NOT carry the current
orchestrator's context — MUST read this document before making any substantial change to this
repository. When in doubt whether a change is substantial, treat it as substantial and run the full
cycle. This read-before-change duty is discoverable through the repo-internal surfaces AGENTS.md §7
and `docs/CONTEXT_MAP.md`; a host-shipping breadcrumb is a recorded future-amendment candidate, kept
out of CLAUDE.md and DMC.md by the manifest dangling-reference rule (`INSTALL_MANIFEST.md:295-308`).

This constitution does not re-author the rules; it INDEXES and BINDS them (CITE-not-fork). Every
normative clause names its source by path (or path:line). Where a rule's full text lives elsewhere,
this document names the source and defers to it, and NEVER restates it — a second source of truth is
forbidden (`.harness/plans/dmc-constitution.md:101-102`). Where prose here and the machine source of
truth disagree on an enforcement or behavior FACT, the machine source wins (Article VI). Clauses are
numbered (I.1, I.2, …) for citation.

## Article I — Identity & Versioning

I.1 — The project is "Do-Me-Coding v1.0" (`DMC.md:1`): a Claude Code-first execution harness, NOT
an independent agent runtime — `bin/dmc` is a Ring-0 verdict/validation CLI (`DMC.md:22`, Rule 5).

I.2 — Version labels are `vX.Y.Z`, at most two dots. A patch label is legitimate: v1.0.1 was chosen
over the recommended v1.1 at the human gate (`.harness/evidence/dmc-v1.0.1-build-20260708.md:7-8`).

I.3 — Historical and pinned labels are IMMUTABLE and are NEVER rewritten: the
`(v1.0; introduced in v0.x)` provenance-tag style (`DMC.md:69,90,106`) and every past closure entry
in the running, append-only milestone log (`docs/MILESTONES.md:3`). Provenance tags stay
"introduced in v0.x" historical annotations; there is no `dmc --version` verb (a v1.1 candidate,
ratified at `.harness/plans/dmc-v1-m10-final-docs.md:428-429`).

## Article II — Immutable Surfaces

These surfaces MUST NOT be edited, "fixed", re-pinned, or weakened casually. For the BYTE-FROZEN
surfaces (II.1, II.2, II.7 and their class), the ONLY route is a dedicated, human-gated hygiene
milestone — never inside a feature milestone (CF1,
`.harness/plans/dmc-v1-runtime-upgrade-handoff.md:334-335`). The amendable machine surfaces (II.5,
II.6) instead follow their OWN stated procedures — the Article III cycle and a landmark-authorized
scope.lock respectively — as each clause states.

II.1 — The 55-file mirror-pinned `bin/lib/dmc-v0.*` legacy tool set and their
`.harness/evidence/dmc-v0.*` originals — KEEP, ratified at the M10 human gate
(`.harness/plans/dmc-v1-m10-final-docs.md:433`); their byte-equality is the mirror-check invariant
(`.harness/plans/dmc-v1-m10-final-docs.md:174`).

II.2 — The pinned `802/3/3` `selftest --all` baseline. It is NEVER "fixed" or masked inside another
milestone; a re-pin is legitimate ONLY via its own human-gated hygiene plan (CF1,
`.harness/plans/dmc-v1-runtime-upgrade-handoff.md:334-335`).

II.3 — The 9-sub-gate release-composer contract: `SUB_GATES` is frozen at nine names
(`docs/DMC_V1_RELEASE_CHECKLIST.md:9`, mirroring `bin/lib/dmc-release-gate.py:62-64` per
`docs/DMC_V1_RELEASE_CHECKLIST.md:19`). Growing it 9→10 breaks the frozen 39/0 self-test contract
(`docs/DMC_V1_RELEASE_CHECKLIST.md:16-17`).

II.4 — The 13 M9-built CI blocking checks plus the 2 porcelain sandwiches. Per CF14 these are NEVER
weakened (`docs/DMC_V1_HONEST_SCOPE.md:122-129`; `docs/DMC_V1_ENFORCEMENT_MATRIX.md:119`;
`.harness/plans/dmc-v1-runtime-upgrade-handoff.md:415-427`).

II.5 — The machine source of truth, amendable ONLY via the Article III cycle: the orchestration
registries `orchestration/harness-matrix.json`, `orchestration/roles.json`,
`orchestration/models.json`, and, symmetrically, the 28 `.harness/schemas/*.schema.md` contracts.

II.6 — The `.claude/settings.json` hook-registration surface. This is enforcement wiring; a change
requires a landmark-authorized scope.lock, and a NEW registration additionally needs a session
reload (`.harness/plans/dmc-v1-runtime-upgrade-handoff.md:394`; `docs/DMC_V1_HONEST_SCOPE.md:79`).

II.7 — Frozen point-in-time records: the `.before-dmc` restore trees and the hooks-v0.6.5 fixture
(`.harness/plans/dmc-constitution.md:97`); the known-baseline proofs `v011-verify.sh` and
`test-rollback.sh` (`.harness/evidence/dmc-v1.0.1-build-20260708.md:44-46`); and every archived
plan, verification, and milestone entry.

II.8 — The secret-protection rules, in ALL modes and via ALL tools (`DMC.md:90-104`). This is a
floor; Article VII forbids weakening it.

## Article III — How Change Happens

III.1 — Every substantial change follows the loop plan → critic → scope → execute → verify →
evidence, skipping no stage (`DMC.md:26-41`); when in doubt, the change is substantial and the cycle
applies.

III.2 — The stages, in order: (1) a `dmc validate plan`-VALID plan; (2) a NON-AUTHORING critic that
REVISEs until APPROVE; (3) a HUMAN gate (AskUserQuestion) with approvals recorded IN the plan
(`docs/DMC_V1_RELEASE_CHECKLIST.md:42`); (4) a compiled scope.lock, `landmark_authorized` for
enforcement/contract/release classes, and NEVER granting `.harness/evidence` paths — the G2↔G3
evidence-grant catch-22 (`.harness/plans/dmc-v1-runtime-upgrade-handoff.md:14-16`); (5) synchronous
scoped executors, single owner per file; (6) an independent NON-AUTHORING verifier; (7) a critic
build sign-off; (8) a committed-replica plus a live `selftest --all` proving `802/3/3`; (9) human
commit and push gates; (10) CI green (`docs/DMC_V1_RELEASE_CHECKLIST.md:42-46`).

III.3 — Lockstep obligations: the Claude hook and its Codex shim counterpart, and the 3-copy
redaction set, stay byte-parallel (`docs/DMC_V1_HONEST_SCOPE.md:29-30`).

III.4 — CI-freeze clause (RATIFIED, `.harness/plans/dmc-constitution.md:271-273`): main CI red on a
BLOCKING-in-CI check (`docs/DMC_V1_ENFORCEMENT_MATRIX.md:94-120`) ⇒ immediate FREEZE of all other
work plus a dedicated fix-forward milestone; the ADVISORY legacy replay going red does NOT trigger
the freeze — but IS investigated. Masking is forbidden — the same never-mask discipline as CF1/CF14
(`.harness/plans/dmc-v1-runtime-upgrade-handoff.md:427`).

## Article IV — Enforcement Tiers & Honesty

IV.1 — Every enforcement surface is exactly one of five tiers — ENFORCED-runtime /
BLOCKING-at-release / BLOCKING-in-CI / ADVISORY / DOCUMENTED-ONLY
(`docs/DMC_V1_ENFORCEMENT_MATRIX.md:94-120`, definitions `:99-103`).

IV.2 — The honesty-lexeme discipline binds ALL prose, INCLUDING this document: no line matching
`/codex/i` may carry any whole-word marker from the forbidden set defined at
`bin/lib/dmc-doctor.py:86-88`; every such line reads ADVISORY, with pre-commit/CI named as the
backstop.

IV.3 — `docs/DMC_V1_HONEST_SCOPE.md` is the disclosure LEDGER: a newly discovered residual is
APPENDED there, never silently dropped (`docs/DMC_V1_HONEST_SCOPE.md:65-68`).

IV.4 — The DMC-priority-over-other-layers clause is instruction-level best-effort, NOT a runtime
boundary (`docs/DMC_V1_HONEST_SCOPE.md:70-73`).

IV.5 — The doctor honesty split stands: the Claude host path is proven by a live deny-probe; the
Codex host is reported ADVISORY only, with pre-commit/CI as the backstop
(`docs/DMC_V1_ENFORCEMENT_MATRIX.md:118`; `docs/DMC_V1_HONEST_SCOPE.md:103`).

## Article V — Gate Overrides & Escape Hatches

V.1 — The frozen v0.2.6 gate runner exposes three override variables
(`bin/lib/dmc-v0.2.6-gate-check-runner.sh:16,21,36-38`): `DMC_GATE_PROTECTED` (the protected-path
list, `:21`/`:37`), `DMC_GATE_EXCLUDED` (the auto-logged evidence exclusion set, `:16`/`:36`), and
`DMC_GATE_UPSTREAM` (`:38`).

V.2 — ONLY `DMC_GATE_PROTECTED` carries the G4 landmark-authorization guardrail precedent; but the
SAME authorization discipline — a landmark-authorized scope.lock + a human plan gate + a
critic/verifier chain — applies to ANY override that flips a blocking verdict
(`.harness/evidence/dmc-v1.0.1-build-20260708.md:74-77`).

V.3 — The G4 guardrail, verbatim-class
(`.harness/evidence/dmc-v1.0.1-build-20260708.md:74-77`): removing `.claude/hooks` from
`DMC_GATE_PROTECTED` is legitimate ONLY under a landmark-authorized scope.lock + human plan gate +
critic/verifier chain; this record MUST NOT be cited to bypass G4 for an unauthorized hook change;
the independent landmark-flag remains the non-suppressible structural backstop.

V.4 — Readiness removal is write-once: a FAIL `release-readiness.json` is REMOVED to re-gate, and
the FAIL is recorded in evidence prose, not archived as JSON
(`.harness/evidence/dmc-v1.0.1-build-20260708.md:70-73`).

V.5 — The `v011-verify` and `test-rollback` known-baseline deltas are gated on their invariant
rows and never laundered (v011 is `39/2` EXACTLY;
`.harness/evidence/dmc-v1.0.1-build-20260708.md:44-46`).

V.6 — Mode switches (`.harness/mode`) NEVER weaken the destructive / secret-exposure deny floor,
which holds in every mode (`DMC.md:73-75`; `docs/DMC_V1_ENFORCEMENT_MATRIX.md:107`). A mode switch
that stands DOWN gate tiers is a DESIGNED escape hatch bounded by that always-on deny floor (the
modes table, `docs/OMC_COEXISTENCE.md:10-16`), NOT a V.2-governed override of a blocking verdict.
But flipping mode to evade a SPECIFIC pending gate verdict IS a V.2 violation — the authorization
discipline of V.2 governs that act.

## Article VI — Document Precedence

VI.1 — This constitution is supreme on GOVERNANCE and PROCESS ONLY: amendment rules, precedence,
the frozen-surface enumeration (Article II), the change procedure (Article III), and the maintainer
duties and inviolable loop (Article VIII) (`.harness/plans/dmc-constitution.md:156-159`).

VI.2 — On any enforcement or behavior FACT, the machine source of truth wins over ALL prose,
INCLUDING this document (`docs/DMC_V1_ENFORCEMENT_MATRIX.md:9-11`).

VI.3 — The precedence ladder, highest first
(`.harness/plans/dmc-constitution.md:159-163`):

1. This constitution — governance and process only.
2. The machine source of truth for facts — the 28 `.harness/schemas/*.schema.md` contracts and
   `orchestration/{harness-matrix,roles,models}.json`. Intra-rung tiebreak: the schema contracts
   control SHAPE; the registries control INSTANCES and VALUES; on a shape conflict the schema
   controls.
3. `DMC.md` — the 7 non-negotiable rules (`DMC.md:16-24`).
4. `CLAUDE.md` — the shipped host instruction layer.
5. The narrative wrappers — `docs/DMC_V1_ENFORCEMENT_MATRIX.md`, `docs/DMC_V1_HONEST_SCOPE.md`,
   `docs/DMC_V1_RELEASE_CHECKLIST.md`.
6. Handoff and session logs — HISTORY, not law
   (`.harness/plans/dmc-v1-runtime-upgrade-handoff.md`).

## Article VII — Amendment

VII.1 — This constitution changes ONLY via the full Article III cycle plus explicit human
ratification (`.harness/plans/dmc-constitution.md:164-168`).

VII.2 — No amendment may weaken Article II (the immutable surfaces), the secret-protection floor
(II.8, `DMC.md:90-104`), THIS clause together with Article VII's entrenchment itself, Article VI's
precedence rules (`.harness/plans/dmc-constitution.md:159-163`), Article III's human-gate and
non-authoring critic/verifier requirements (`DMC.md:26-41`; `docs/DMC_V1_RELEASE_CHECKLIST.md:42`), or
Article VIII (maintainer duties and the inviolable loop).
An amendment whose EFFECT is to enable any of those weakenings in a later step is itself a weakening
under this clause.

VII.3 — Every amendment APPENDS one entry to the amendment log below — date, ratifying commit, and
a one-line summary. The log is append-only (`.harness/plans/dmc-constitution.md:164-166`).

VII.4 — Every amendment MUST re-run the whole-word honesty-lexeme check (the forbidden-marker set at
`bin/lib/dmc-doctor.py:86-88`) over the amended document before its commit gate; the grep output is
attached as an evidence artifact at that commit gate.

## Article VIII — Maintainer Duties & the Inviolable Loop

VIII.1 — CAPABILITY-INDEPENDENCE. This article binds every maintainer of this repository — human or
model of ANY tier, including a session weaker than the current orchestrator — and grants a
less-capable maintainer NO relaxed path. Capability doubt TIGHTENS the duty rather than loosening
it: the weaker the maintainer, the smaller the permitted step and the sooner the escalation
(`DMC.md:16-24`; Article III; Preamble `:15-18`).

VIII.2 — THE INVIOLABLE LOOP (본질). The canonical loop plan → critic → scope → execute → verify →
evidence IS the essence of DMC — the 6-stage form of Article III.1 (`:88-90`) and DMC.md's Default
Loop, Critic Review stage included (`DMC.md:26-41`); the common 5-stage shorthand is a shorthand
ONLY and NEVER licenses dropping the non-authoring critic stage. No maintenance and no enhancement
may remove, reorder, bypass, weaken, or "temporarily suspend" a stage; speed, simplicity, urgency,
and a capability limit are NEVER valid justifications for skipping one (`DMC.md:18-21`;
Article III.1 `:88-90`).

VIII.3 — ANTI-PATCHWORK (땜질 원천 봉쇄). The following are forbidden AS FIXES — exploratory,
scouting, or spike work that produces plans and analysis rather than shipped edits is not "a fix":
(a) UNAUTHORIZED or UNDISCLOSED symptom suppression or masking of a red check — generalizing CF1 and
the never-mask discipline (Article III.4 `:104-108`; II.2 `:57-59`;
`.harness/plans/dmc-v1-runtime-upgrade-handoff.md:334-335`; CF14/II.4
`docs/DMC_V1_HONEST_SCOPE.md:122-129`) — WITH explicit deference to Article V's bounded escape
hatches: a V.2/V.3 authorized override under a landmark-authorized scope.lock plus a human gate plus
a critic/verifier chain, the V.6 designed mode hatch, and the disclosed III.4 advisory-replay
carve-out plus V.5 known-baseline handling all remain lawful; what is forbidden is masking WITHOUT
that authorization-and-disclosure chain;
(b) any fix landed without a diagnosed root cause recorded in the plan (Article III.1–III.2
`:88-99`);
(c) any edit outside an approved scope.lock (Article III.2 stage (4); `DMC.md:19`);
(d) a "temporary" hack landed without a registered follow-up — an unregistered TODO in
repo-committed shipped or source code or in a governing doc is a violation, while `.harness/**` run
machinery, scratchpads, and exploratory analysis are exempt (IV.3 disclosure ledger
`docs/DMC_V1_HONEST_SCOPE.md:65-68`);
(e) a one-sided edit to a lockstep surface — the Claude hook and its Codex shim counterpart, and the
3-copy redaction set — carrying the Article III.3 lockstep-parity obligation into maintenance, with
no tier claimed for either side (`docs/DMC_V1_HONEST_SCOPE.md:29-30`);
(f) a drive-by change folded into an unrelated scope (Article III.2 stage (5) single-owner and
diff⊆scope discipline).

VIII.4 — ESCALATION DUTY (weaker-model rule). When a maintainer cannot complete ANY stage — diagnose
the fault, author a valid plan, or verify the result — the REQUIRED action is to STOP and surface the
situation to the human gate with an honest statement of the unknown; shipping a partial, unverified,
or best-guess result is a violation, and "no verification, no done" binds HARDER as capability
decreases. The AUTONOMY.md stop-conditions (`AUTONOMY.md:43-58`, schema
`.harness/schemas/autonomy.schema.md`) are BINDING here (`DMC.md:18`; Article III.2 stage (3);
Preamble `:15-18`).

VIII.5 — ENHANCEMENT (고도화) DISCIPLINE. Additions and upgrades follow the SAME cycle as fixes; a new
capability must state which loop invariants it preserves, and a refactor must prove behavior
preservation where a machine suite exists — tests and suites run before and after (II.1 mirror
`:52-55`; II.2 `802/3/3` `:57-59`) — while a docs-only governance change uses the `--all`-SKIP
precedent with a recorded rationale, and byte-frozen surfaces are excluded because refactoring them
is forbidden outright. No enhancement may reduce an existing surface's enforcement tier; a tier
downgrade is Article II / IV human-gated territory (IV.1 `:112-114`; II.3 and II.4).

### Amendment Log

| # | Date | Ratifying commit | Summary |
|---|---|---|---|
| 1 | 2026-07-08 | this commit | Founding text — Articles I–VII |
| 2 | 2026-07-08 | this commit | Article VIII — capability-independent maintainer duties, the inviolable 6-stage loop, anti-patchwork, escalation & enhancement discipline; VII.2 protected set + VI.1 enumeration extended to Art. VIII |
