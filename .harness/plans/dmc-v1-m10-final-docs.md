# Plan: DMC v1 M10 — Final Docs + v1.0 Identity + Release Checklist (LAST milestone)

Plan ID: dmc-v1-m10-final-docs · Date: 2026-07-08 · Format: PLAN_SCHEMA.md
Milestone-scoped plan for master plan §M10 (task DMC-T016,
`.harness/plans/dmc-v1-runtime-upgrade.md:346-355`; "M10 remains UNAPPROVED (DRAFT)" at :373).
Risk: low (master §M10 header) — docs/identity surface, additive except one append (MILESTONES)
and one wording-only schema bullet.

Task numbering: sub-numbered `DMC-T016.1..6` under master task DMC-T016. The `.N` namespace was
grep-verified collision-free at planning (only the master definition :347 + evidence echoes use the
prefix); re-derive the count at execution rather than trusting a pinned number (critic-r1 AD5).

**Rev 2** — critic r1 (`.harness/evidence/dmc-v1-m10-critic-r1.json`, NEEDS_CLARIFICATION) folded:
BL1 — the product-identity acceptance grep rewritten as a real, provably NON-vacuous check (pipe-free
`-e` patterns; proven NON-empty pre-edit, EMPTY post-edit; fenced verbatim below the Verification
table); BL2 — `docs/NOTION_EXPORT_SUMMARY.md:13` added to T016.1 scope + the archival exclusion
allowlist enumerated with per-file rationale; AD1 — honesty grep expanded to all 7 doctor
FORBIDDEN_CODEX_LEXEMES + CODEX_REQUIRED_SUBSTRINGS assertion; AD2 — readiness-conformance wording
fixed (no `dmc validate release-readiness` verb exists); AD3 — two-branch AGENTS.md acceptance;
AD4 — schema-edit precedent reconciliation; AD5 — stale counts corrected. GATE-DECISIONS remain
surfaced inline (marked **GATE-DECISION**) with a recommendation each; the human release gate
chooses. No edits occur before critic + human gate.

## Goal

Ship the final v1.0 documentation surface and close the master plan: (1) refresh product identity
so no doc claims v0.1 while preserving legitimate feature-provenance/pinned-filename references;
(2) reconcile the M1 design-docs to shipped M2-M9 reality (P20 Codex-Stop-hook cleanup +
Status headers); (3) author three NEW honesty-critical docs (ENFORCEMENT_MATRIX, HONEST_SCOPE,
RELEASE_CHECKLIST) as faithful narrations of already-shipped data (`orchestration/harness-matrix.json`,
the 9-sub-gate composer, the disclosed residual register) with ZERO new over-claims; (4) build the
`.harness/verification/dmc-v1-runtime-upgrade.md` B1-B10 audit-blocker traceability table; (5) append
the human-gated MILESTONES.md v1.0 closure entry; and (6) stand up an M10 release run and prove
`dmc gate release --full --run-id <M10-RID>` PASS — all while keeping the frozen 9-sub-gate composer,
the pinned 802/3/3 legacy baseline, and every self-test section byte/count-unchanged.

## User Intent

docs (final-milestone documentation + identity refresh; the LAST v1.0 milestone). Continue the
approved dmc-v1-runtime-upgrade in the Rev 3 order M9→M10 (handoff :303-312). The user gates
milestone approval, staging, commit, and push; Opus/Sonnet executors implement synchronously; a
non-authoring critic reviews this plan before any edit; an independent verifier validates the build
before closure.

## Current Repo Findings

All findings re-verified live this session (2026-07-08, HEAD `11f26a3` == main, CI GREEN); scout
synthesis treated as verified ground truth.

- Finding: The literal acceptance bar is "no doc claims v0.1" — product-identity claims, NOT every
  v0.x string (feature-provenance tags v0.1.1/v0.1.3/v0.2 and pinned `dmc-v0.*` filenames are legitimate).
  Source: master :354; Lane-1 finding "governing acceptance bar is literal".
- Finding: The 7 product-identity claim sites are live today: `DMC.md:1` "# Do-Me-Coding v0.1",
  `DMC.md:22-23` rules 5/6 (now FALSE — bin/dmc + orchestration/ ship), `DMC.md:178` "## v0.1 Scope"
  (stale Excluded list); `CLAUDE.md:3` "uses Do-Me-Coding v0.1"; `AGENTS.md:7-8` "v0.1 … on git branch
  `dmc-v0.1-scaffold`" (branch FALSE — actual `claude/dmc-v1-runtime-upgrade-c5uch1`); `docs/CONTEXT_MAP.md:1`
  "(v0.4.7)". Verified verbatim this session.
  Source: Lane-1 findings; live `sed` confirmation.
- Finding: `CLAUDE.md` ships byte-for-byte to every host via `.claude/install/dmc-install.sh:404-414`
  (cp for fresh host, marker-wrapped append for existing) — highest-leverage fix; NOT byte-identical to
  DMC.md's parallel prose (edit independently). `AGENTS.md` does NOT ship (INSTALL_MANIFEST "DELIBERATELY
  NOT COPIED") — fix is DMC-repo-internal.
  Source: Lane-1 findings.
- Finding: Three additional SHIPPED docs carry literal v0.1 product claims required by the unqualified
  acceptance bar: `docs/OMC_COEXISTENCE.md:16` "v0.1 protections", `docs/HOST_REPO_ARTIFACT_POLICY.md:1`
  and `docs/HOST_REPO_ADAPTATION_POLICY.md:1` titles "(v0.1.3)". `HOST_REPO_ARTIFACT_POLICY.md:28`
  "v0.1.2 pilot record" is an archival provenance reference → KEEP.
  Source: Lane-1/Lane-2 findings; live grep confirmation.
- Finding (critic-r1 BL2): a FOURTH live product-identity claim exists outside the original scope —
  `docs/NOTION_EXPORT_SUMMARY.md:13` "Do-Me-Coding v0.1 is a Claude Code Native Pack first." Added to
  T016.1. The archival exclusion ALLOWLIST (KEEP, per-file rationale recorded in M10 evidence):
  `docs/DMC_REAL_REPO_PILOT_REPORT.md` (v0.1.2 pilot record — point-in-time report),
  `docs/MILESTONES.md` historical v0.x entries (append-only changelog), `docs/COMPETITIVE_GAP_LEDGER.md`
  (archival analysis), `_DMC_*.md` scaffold titles + `do-me-coding-v0.1-scaffold.zip` (bootstrap
  provenance; hygiene-proposal candidates, not identity claims), pinned `dmc-v0.*` filenames, schema
  `producer_milestone_id` values, and "introduced in v0.x" provenance annotations.
  Source: critic r1 independent grep.
- Finding: `AGENTS.md` is `bin/lib/dmc-agents-md.py`'s output contract, but that verb REFUSES to
  overwrite an existing file (exit 3, :494), emits a host-shaped 10-section Codex-contract doc from
  `dmc orient`/`landmarks`, and its selftest is hermetic on `mktemp` fixtures (:584) — NO CI/selftest
  asserts the repo's own AGENTS.md bytes. It is FABLE B1's own named orientation-drift example
  (`docs/FABLE_WORKFLOW_TRANSFER.md:35-36`).
  Source: direct read of dmc-agents-md.py; Lane-1/Lane-2 findings.
- Finding: `docs/DMC_V1_RUNTIME_ARCHITECTURE.md:355` "Codex has no Stop hook ⇒ release gate runs as a
  pre-commit/CI check instead" (+ :363-364 "codex matrix = pre-commit/CI binding" under-description) is
  master-assigned M10 cleanup (master :173) and is FALSE per `docs/CODEX_ADAPTER.md:58,:100` +
  `orchestration/harness-matrix.json` stop-gate row (advisory Stop-decision:block parity, pre-commit/CI
  backstop). `RUNTIME_ARCHITECTURE.md:3-4` and `ORCHESTRATION_MODEL.md:3` still say "Status: DESIGN …
  gated on the approved plan" though M2-M9 shipped what they describe (F2 precedent bumped CODEX_ADAPTER.md:10).
  `FABLE_WORKFLOW_TRANSFER.md:292-313` "Today in DMC" column is a pre-M2 snapshot now mostly false.
  `ORCHESTRATION_MODEL.md:81-88` §4 under-describes standard-implementation vs `orchestration/models.json`.
  Source: Lane-2 findings.
- Finding: `docs/DMC_V1_ENFORCEMENT_MATRIX.md`, `docs/DMC_V1_HONEST_SCOPE.md`,
  `docs/DMC_V1_RELEASE_CHECKLIST.md`, and `.harness/verification/dmc-v1-runtime-upgrade.md` are all ABSENT
  (correctly — M10 unwritten). `orchestration/harness-matrix.json` self-tags "M10 owns the narrative doc"
  and already holds 8 invariants × 3 harnesses with `honesty_rule`; `dmc doctor` renders it per-host.
  Source: live existence check; Lane-4/Lane-6 findings.
- Finding: The composer `bin/lib/dmc-release-gate.py` reads NO checklist doc today
  (`grep -c checklist` = 0); "consumed by the release gate" is an OUT-OF-BAND binding (doc↔9-sub-gate
  cross-reference asserted in the M10 verification report + the M10 full-gate PASS itself). SUB_GATES is
  frozen at nine (diff-scope, gate-checks, receipts, findings, goal, decision, approvals, chain,
  landmark-flag; :63-64), self-test 39/0. A 10th sub-gate / any composer presence-check BREAKS the frozen
  contract.
  Source: Lane-3 findings.
- Finding: `dmc gate release --full` requires an explicit `--run-id` (no auto-discovery), writes
  `release-readiness.json` WRITE-ONCE (a second run REFUSEs exit 3), and diff-scope adjudicates the
  worktree names only (committed-diff blindness → gate BEFORE committing, or `--base`). No existing run
  carries the green evidence set — M10 must stand up its own run.
  Source: Lane-3 findings.
- Finding: B1-B10 = the pre-v1 AUDIT release blockers (`.harness/plans/dmc-v1-runtime-upgrade-audit.md:270-290`),
  NOT FABLE's B1-B13 behaviors. B6 (version identity) is the one blocker M10 itself closes. Master :133
  names the table home `.harness/verification/dmc-v1-runtime-upgrade.md`.
  Source: live read of audit :266-290; Lane-4/Lane-6 findings.
- Finding: `docs/MILESTONES.md`'s last CLOSED entry is "v0.6.1–v0.6.5 — CLOSED (2026-06-24)"; a
  decomposed-not-built v0.6.6–v0.6.9 governance section + the stale trailing "Next:" pointer follow it
  (critic-r1 AD5 precision). NO v1.0/M1-M10 entry exists; the "Next" mission folded into the v1.1+
  deferred register (`RUNTIME_ARCHITECTURE.md:395`). Master scopes MILESTONES.md as append-only,
  M10-only (master :193).
  Source: Lane-6/Lane-2 findings; critic r1.
- Finding: CF14 (CI-baseline-portability, load-bearing, master :397-409) is an unresolved human decision;
  D1 (~20 frozen tools' bare-BSD-md5 vacuous self-asserts) is a documented HIGH carry-forward. Root cause
  is NAMED-TOOL (v0.2.6 + v0.3.9 cascade + v0.3.1 md5-ordering), NOT brittle runner counts; the only pinned
  number is the maintainer local/committed-replica 802/3/3 (dev-environment-scoped). The authoritative
  real-repo cleanliness guarantee is the non-md5 CI porcelain PRE/MID sandwiches (`dmc-ci.yml:101-102,182-183`),
  NOT the md5 self-checks. `bin/lib/dmc-v0.2-verify.sh:15-17` is the one D1 site masking a security invariant;
  `dmc-v0.4.9-autonomous-dry-run.sh:28-31` HASH_CMD is the future-fix template.
  Source: Lane-5 findings; handoff CF14 :397-409.
- Finding: `release-readiness.schema.md:118-121` M10-extension bullet is M9-reserved wording (composer
  still does NOT read the file); it is a standalone editable contract-class schema (NOT in the 3-schema
  mirror set plan/run/verification). `dmc-ci.yml` header comments (:18-30) + advisory-step comment (:190)
  are comment-only, non-frozen M9 workflow text. PRECEDENT RECONCILIATION (critic-r1 AD4): the
  audit-remediation plan's not-edit list ("no `.harness/schemas/*.md` contract edit", :91/:239) was an
  AUDIT-scope discipline, not a global freeze — this schema is composer-blind, not mirror-pinned, and no
  instance-validator consumes the .md; the M10 edit is constrained to the M10-extension prose bullet
  ONLY, and the verifier diffs the schema for structural/normative deltas (expect none).
  Source: Lane-3/Lane-5 findings; M9 plan CF13d note; critic r1 AD4.

## Relevant Files

| Path | Reason | Allowed to Edit |
|---|---|---|
| DMC.md | identity refresh: title :1, rules 5/6 :22-23, tags :69/:89/:105/:117, "## v0.1 Scope" :178 — landmark_class=protected-dmc-binding (non-ordinary) | yes (T016.1 — SOLE owner) |
| CLAUDE.md | identity refresh :3/:27/:39/:54/:60/:63; ships byte-for-byte (dmc-install.sh:404-414) — landmark protected-dmc-binding (non-ordinary) | yes (T016.1) |
| AGENTS.md | identity + stale-branch fix :7-8; GATE-DECISION regen-vs-hand-edit; NOT shipped | yes (T016.1) |
| docs/CONTEXT_MAP.md | title :1 (v0.4.7→v1.0), :16 CLAUDE.md "user-private" mislabel; KEEP pinned dmc-v0.4.* refs :18/:34 | yes (T016.1) |
| docs/OMC_COEXISTENCE.md | :16 "v0.1 protections" reword (shipped-doc acceptance closure) | yes (T016.1) |
| docs/HOST_REPO_ARTIFACT_POLICY.md | :1 title (v0.1.3); KEEP :28 archival pilot ref | yes (T016.1) |
| docs/HOST_REPO_ADAPTATION_POLICY.md | :1 title (v0.1.3) | yes (T016.1) |
| docs/NOTION_EXPORT_SUMMARY.md | :13 "Do-Me-Coding v0.1 is a Claude Code Native Pack first." — 4th live product-identity claim (critic-r1 BL2) | yes (T016.1) |
| docs/DMC_V1_RUNTIME_ARCHITECTURE.md | P20 :355+:363-364 stale Codex-Stop claim; Status :3-4 DESIGN→IMPLEMENTED | yes (T016.2 — SOLE owner) |
| docs/DMC_V1_ORCHESTRATION_MODEL.md | Status :3 DESIGN→IMPLEMENTED; §4 :81-88 standard-impl under-description | yes (T016.2) |
| docs/FABLE_WORKFLOW_TRANSFER.md | :292-313 "Today in DMC" column relabel as historical pre-build snapshot | yes (T016.2) |
| docs/DMC_V1_ENFORCEMENT_MATRIX.md (NEW) | narrative wrapper over harness-matrix.json + surface tier table | yes (T016.3 — SOLE owner) |
| docs/DMC_V1_HONEST_SCOPE.md (NEW) | 3 named topics + residual register + CF14/D1 sections | yes (T016.3) |
| docs/DMC_V1_RELEASE_CHECKLIST.md (NEW) | row-for-row 9-sub-gate map + P17 human-gate items + CF14 posture | yes (T016.3) |
| .harness/schemas/release-readiness.schema.md | :118-121 bullet reword M9-reserved→M10-realized (contract landmark, authorized HERE; composer still does NOT read the file) | yes (T016.3 — surgical, one bullet) |
| .github/workflows/dmc-ci.yml | comment-only pointer edits :18-30, :190 → HONEST_SCOPE (non-frozen M9 workflow) | yes (T016.3 — comment-only) |
| .harness/verification/dmc-v1-runtime-upgrade.md (NEW) | Audit Blocker B1-B10 traceability table (master :133) | yes (T016.4 — SOLE owner) |
| docs/MILESTONES.md | append-only v1.0 M1-M10 closure entry; reconcile stale "Next:" pointer | yes (T016.5 — append-only, content human-gated) |
| .harness/runs/<M10-RID>/**, .harness/evidence/dmc-v1-m10-*.md, .harness/verification/dmc-v1-m10-release.md (NEW) | M10 release-run artifacts + evidence + verification report (release approval verification_ref target) | yes (T016.6 — run-dir + evidence/verification exemption) |
| .harness/plans/dmc-v1-m10-final-docs.md (this file), .harness/plans/dmc-v1-runtime-upgrade.md §Approval Status | revisions + M10 approval/closure records only | yes (orchestrator lane, gate-driven — explicit scope grant, M7 out-of-lock REFUSE precedent) |
| bin/lib/dmc-release-gate.py | frozen 9-sub-gate composer (39/0) — consumed, NEVER edited | no |
| bin/lib/dmc-v0.*.{sh,py} + .harness/evidence/dmc-v0.*.{sh,py} | mirror-pinned frozen tools (CF1) | no |
| orchestration/harness-matrix.json, models.json, roles.json | narrated/rendered data sources, not edited | no |
| bin/dmc, .claude/install/**, uninstaller, .claude/hooks/**, .claude/settings.json, adapters/** | not this milestone | no |
| INSTALL_MANIFEST.md | content-independent (no ship-surface file added/removed) — VERIFY, do not edit | no |
| .before-dmc trees, _DMC_*.md, do-me-coding-v0.1-scaffold.zip | hygiene PROPOSAL only; NO deletion here | no |

## Out of Scope

- ZERO edits to `bin/lib/dmc-release-gate.py` (frozen 9-sub-gate contract, 39/0) — no 10th sub-gate,
  no checklist presence-check inside the composer (Lane-3 "single biggest M10 trap").
- ALL frozen `bin/lib/dmc-v0.*` + `.harness/evidence/dmc-v0.*` tools in place (CF1; master :192-194);
  the 55-file mirror-check byte-equality stands. NO re-pin of the 802/3/3 baseline.
- Any `.before-dmc`/zip/`_DMC_*.md` stray DELETION (master :97; separate human-gated approval — M10
  only DRAFTS the proposal).
- Installer/uninstaller/doctor code, `.claude/hooks/**`, `.claude/settings.json`, `bin/dmc`, provider
  adapters/router (`.claude/workers/providers/**`, master :192).
- `INSTALL_MANIFEST.md` regeneration — no ship-surface file is added/removed (AGENTS.md + the 4 new
  docs do not ship); verify content-independence, do not edit.
- CF14 option (a) frozen-tool portability hardening + D1 hardening — DOCUMENT only; any code fix is a
  separate post-v1.0 hygiene milestone with GitHub-runner access.
- Any push to main, any live provider call, any closure record before the human gates.

## Proposed Changes

- Change: v1.0 identity refresh (Opus, protected landmarks). Files: DMC.md, CLAUDE.md, AGENTS.md,
  docs/CONTEXT_MAP.md + the 3 shipped docs (OMC_COEXISTENCE.md, HOST_REPO_ARTIFACT_POLICY.md,
  HOST_REPO_ADAPTATION_POLICY.md) + docs/NOTION_EXPORT_SUMMARY.md:13 (critic-r1 BL2). Retitle banners
  to v1.0; rewrite DMC.md rules 5/6 (:22-23, now false) and "## v0.1 Scope" (:178, stale Excluded
  list); fix CONTEXT_MAP.md:16 "user-private" mislabel (CLAUDE.md is git-tracked). Surgical,
  load-bearing-text-preserving edits only. The archival exclusion allowlist (Findings) is recorded
  with per-file rationale in M10 evidence. Rationale: audit B6; master acceptance "no doc claims v0.1".
  - **GATE-DECISION (AGENTS.md method)**: regenerate via `dmc agents-md --out <temp> --root .` then adopt
    vs surgical hand-edit of :7-8. RECOMMEND **regenerate** — it is the exact P1/P2 mechanism FABLE built
    to kill the orientation-drift AGENTS.md itself exemplifies; hand-patching :7-8 leaves the stale
    landmark inventory (:28-39, omits bin/adapters/orchestration/.harness/schemas). Operational caveats:
    the verb refuses in-place overwrite (generate to temp, adopt under scope); it is a STRUCTURAL rewrite
    → generated bytes must pass critic review; blast radius is DMC-repo-internal (AGENTS.md excluded from
    host ship). Fallback: hand-edit if the human prefers preserving the bespoke scaffold narrative.
  - **GATE-DECISION (provenance-tag style, decide once, applied uniformly)**: convert feature-provenance
    tags (v0.1.1/v0.1.3/v0.2 worker-bridge) to explicit "introduced in v0.x" HISTORICAL annotations under
    a v1.0 banner (product identity vs provenance). RECOMMEND **convert-to-historical** (keeps the tags
    truthful without reading as a live v0.1 product claim).
  - **GATE-DECISION (version verb / VERSION file)**: RECOMMEND **NO** — new code surface on the last
    milestone; v1.1 candidate. Doc-prose v1.0 stamp (already in `bin/dmc:2`, INSTALL_MANIFEST.md:1) suffices.
- Change: M1 doc-trio consistency + P20 cleanup (Sonnet). Files: DMC_V1_RUNTIME_ARCHITECTURE.md
  (P20 :355+:363-364 → M6.5/M8 harness-matrix.json reality: advisory Stop-decision:block parity,
  pre-commit/CI backstop; Status :3-4 → "IMPLEMENTED (M2-M9)"), DMC_V1_ORCHESTRATION_MODEL.md (Status
  :3 → IMPLEMENTED; §4 :81-88 standard-impl description reconciled to models.json), FABLE_WORKFLOW_TRANSFER.md
  (:292-313 "Today in DMC" column RELABELED as historical pre-build snapshot + a shipped-state pointer —
  relabel-not-rewrite). Rationale: master :173; F2 precedent; Lane-2.
- Change: three NEW honesty-critical docs (Opus). Files: docs/DMC_V1_ENFORCEMENT_MATRIX.md (narrative
  wrapper over `orchestration/harness-matrix.json` 8 invariants × 3 harnesses + the surface tier table
  ENFORCED-runtime / BLOCKING-at-release / BLOCKING-in-CI / ADVISORY / DOCUMENTED-ONLY; state the
  worker-chain honest tier verbatim from `.claude/skills/dmc-worker-review/SKILL.md:35-38`; reconcile the
  CI blocking count precisely — 15 blocking = 13 substantive + 2 porcelain sandwiches, 1 advisory replay),
  docs/DMC_V1_HONEST_SCOPE.md (the 3 master-named topics — approval provenance-not-authentication;
  redaction known-shapes-only with the EXACT 9-class post-C2 list from `evidence-log.sh:72`; regex
  dep-scan best-effort — + consolidated residual register from handoff items 10-15 + audit DEFER-M10 +
  critic V1/V3; a CF14 CI-tier-baseline section with NAMED-TOOL root-cause wording; a D1 section naming
  `dmc-v0.2-verify.sh:15-17` as the one security-relevant site and `dmc-v0.4.9-…:28-31` HASH_CMD as the
  fix template), docs/DMC_V1_RELEASE_CHECKLIST.md (row-for-row map to the exact 9 composer sub-gates +
  P17 human-gate items + the CF14 posture item). PLUS surgical: release-readiness.schema.md:118-121
  reworded M9-reserved→M10-realized (composer still does NOT read the file); dmc-ci.yml comment-only
  pointers (:18-30, :190) → HONEST_SCOPE. HARD CONSTRAINT: checklist↔SUB_GATES correspondence asserted
  OUT-OF-BAND in the M10 verification report + the full-gate PASS — NO new test/code surface. Rationale:
  master §M10; Lane-3/Lane-4.
  - **GATE-DECISION (CF14)**: RECOMMEND **option (b)** — formalize the advisory tier + a documented
    CI-tier baseline as the accepted v1.0 posture (option (a) = MEDIUM-HIGH risk, violates CF1, blind
    without a runner repro). **GATE-DECISION (D1)**: DOCUMENT, not harden.
- Change: B1-B10 traceability table (Sonnet). File: `.harness/verification/dmc-v1-runtime-upgrade.md`
  (NEW) — titled "Audit Blocker B1-B10" explicitly (NOT FABLE B1-B13), mapping each audit blocker
  (`dmc-v1-runtime-upgrade-audit.md:270-290`) → shipped mechanism → evidence; B6 closes IN M10; B8
  recorded by-design NO-ACTION (deletion out of scope) with the hygiene-proposal pointer; CF14 + D1
  recorded as human-gated dispositions. Rationale: master acceptance :131.
- Change: MILESTONES.md v1.0 closure entry (Sonnet, append-only; content human-gated at the commit
  gate). File: docs/MILESTONES.md — a "## v1.0 — … — CLOSED (date)" entry in the established
  7-subsection format covering M1-M10; reconcile the stale trailing "Next: v0.6.6-v0.6.9" pointer.
  Rationale: master :193, :353.
- Change: M10 release run + full gate (orchestrator lane). Files: `.harness/runs/<M10-RID>/**`,
  `.harness/evidence/dmc-v1-m10-*.md`, `.harness/verification/dmc-v1-m10-release.md`, master §Approval
  Status. Stand up run start → scope.lock compile (landmark_authorized for DMC.md/CLAUDE.md/AGENTS.md/
  CONTEXT_MAP.md) → executors → green evidence set → STAGE exactly scope.lock files → `dmc gate release
  --full` PASS. Rationale: master acceptance "`dmc gate release --full` PASS".
  - **GATE-DECISIONS (dispositions to record)**: (2) `.harness/evidence/dmc-v0.*` originals (55 files/728K)
    → RECOMMEND **KEEP** (M3 rollback guarantee + mirror-check depend on them; deprecation would need a
    mirror-check redesign). (3) Stray-file hygiene → **PROPOSAL DOC ONLY** inside M10 evidence (covers
    _DMC_*.md, do-me-coding-v0.1-scaffold.zip, .before-dmc trees, an untracked run-log .gitignore
    extension); execution needs its own approval.

## Acceptance Criteria

- Criterion: No doc claims v0.1 (product identity) — all 8 identity sites (7 original +
  NOTION_EXPORT_SUMMARY.md:13, critic-r1 BL2) + the 3 shipped docs are refreshed to v1.0; the archival
  exclusion allowlist (Findings — pilot report v0.1.2, MILESTONES historical entries,
  COMPETITIVE_GAP_LEDGER, `_DMC_*` scaffold titles/zip, pinned `dmc-v0.*` filenames,
  `producer_milestone_id`, "introduced in v0.x" annotations) is preserved and recorded with per-file
  rationale.
  Verification Method: the scoped product-identity grep (fenced verbatim under Verification Commands)
  is proven NON-EMPTY on the pre-edit tree and EMPTY on the post-edit tree (critic-r1 BL1 — a vacuous
  check is itself a FAIL); the broad `grep -rIn 'v0\.1'` residual set is hand-reviewed against the
  documented allowlist in M10 evidence, zero unexplained hits.
- Criterion: `AGENTS.md` no longer names a non-existent branch and its landmark inventory reflects real
  HEAD (bin/, adapters/, orchestration/, .harness/schemas present). Two-branch acceptance (critic-r1
  AD3): REGENERATE branch ⇒ `dmc agents-md --validate AGENTS.md` VALID + branch grep empty; HAND-EDIT
  branch ⇒ branch grep empty + landmark-inventory review vs `dmc landmarks` (no --validate coverage —
  the bespoke doc lacks the 10-section contract and --validate would REFUSE by design).
  Verification Method: `grep -n 'dmc-v0.1-scaffold' AGENTS.md` empty; PLUS the ratified branch's check
  above, recorded in M10 evidence.
- Criterion: The B1-B10 traceability table is complete — every audit blocker B1-B10 maps to a closing
  change or an explicit deferred/waived entry; B6 marked closed-in-M10; CF14 + D1 recorded.
  Verification Method: read `.harness/verification/dmc-v1-runtime-upgrade.md`; 10 rows present, each with
  a mechanism + evidence ref; `dmc validate verification` VALID.
- Criterion: `dmc gate release --full --run-id <M10-RID>` ⇒ overall PASS, exit 0; `release-readiness.json`
  conforms to dmc.release-readiness.v1; landmark-flag = FLAG on the identity docs (never fails); no sub-gate FAIL/MISSING.
  Verification Method: run the full gate on the armed+staged M10 run; verdict PASS recorded in evidence.
- Criterion: The release checklist maps row-for-row to the exact 9 composer sub-gates (diff-scope,
  gate-checks, receipts, findings, goal, decision, approvals, chain, landmark-flag) + the P17 human-gate items.
  Verification Method: the checklist↔SUB_GATES correspondence assertion in the M10 verification report
  enumerates exactly the 9 names from `bin/lib/dmc-release-gate.py:63-64`; reviewer confirms 1:1.
- Criterion (honesty): the ENFORCEMENT_MATRIX prints NO forbidden lexeme on any Codex line — ALL 7
  doctor FORBIDDEN_CODEX_LEXEMES (`dmc-doctor.py:86`: enforced, enforce, fires, firing, active,
  guaranteed, runtime-enforced; critic-r1 AD1), word-boundary matched — AND its Codex section carries
  the CODEX_REQUIRED_SUBSTRINGS ("ADVISORY", "pre-commit/CI"); the worker-chain tier is stated verbatim
  from SKILL.md:35-38; the CI blocking count is stated precisely (15 blocking = 13 substantive +
  2 porcelain; 1 advisory).
  Verification Method: word-boundary grep for all 7 lexemes on `/codex/i` lines of the new docs ⇒ empty;
  grep for the 2 required substrings in the Codex section ⇒ present; reviewer diff against
  harness-matrix.json wording + SKILL.md:35-38.
- Criterion (no-regression): frozen composer + legacy baseline byte/count-unchanged.
  Verification Method: `dmc selftest release-gate` 39/0; `dmc mirror-check` PASS; `dmc selftest --all`
  802/3/3 EXACT on the committed replica + post-commit live re-run; fast-default selftest count unchanged;
  `dmc linkcheck` green (all new doc path/verb refs resolve).
- Criterion (no-regression): the release-readiness contract is unchanged by the schema-doc bullet edit
  (wording-only; no normative field/enum/SUB_GATES delta — critic-r1 AD4); INSTALL_MANIFEST
  content-independent (no ship-surface delta).
  Verification Method: readiness conformance is checked INSIDE the composer (no standalone
  `dmc validate release-readiness` verb exists — critic-r1 AD2): `dmc selftest release-gate` 39/0 +
  the M10 gate run's emitted `release-readiness.json` conform; verifier diffs the schema for
  structural/normative deltas (expect none); `dmc selftest m8-suite` unchanged;
  `git diff INSTALL_MANIFEST.md` empty.
- Criterion: CI green on branch after the human push gate.
  Verification Method: `gh run view <id> --json conclusion` = success, recorded in the closure evidence
  (verifiable only post-push).

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Over-claim in a new doc (enforced-class lexeme on a Codex line) ships undetected — hand docs are NOT covered by the doctor negcontrol | high | Mirror `harness-matrix.json`/SKILL.md:35-38 wording exactly; honesty acceptance criterion + explicit codex-line lexeme grep; critic honesty pass |
| AGENTS.md regeneration is a structural rewrite (host-shaped 10-section form replaces bespoke doc) | medium | GATE-DECISION to the human; generated bytes reviewed at critic; refuse-to-overwrite handled via `--out` temp + adopt under scope; AGENTS.md non-shipping limits blast radius |
| Contract-class schema edit (release-readiness.schema.md) disturbs the composer contract | medium | Wording-only single-bullet edit; composer 39/0 + a still-valid readiness instance asserted; landmark authorization recorded in scope.lock |
| Acceptance-vs-scope gap ("no doc claims v0.1" is repo-wide, T016 named only 4 docs) | medium | CLOSED by including the 3 shipped docs + NOTION_EXPORT_SUMMARY.md:13 (critic-r1 BL2) in T016.1 scope AND enumerating the archival exclusion allowlist with per-file rationale |
| landmark-flag FLAG on identity docs misread as a gate failure | low | Pinned semantics: FLAG never degrades the verdict (Lane-3); paths landmark_authorized at scope-compile |
| readiness write-once collision (a second gate run REFUSEs exit 3) | medium | Mint deliberately once per M10 run; gate BEFORE committing (diff-scope committed-diff blindness) or pass `--base` |
| Doc-claim grep false-negative hides a real product claim behind a provenance exclusion | medium | Two-pass: scoped product-identity grep (must be empty) + broad `v0\.1` grep hand-reviewed against a documented allowlist in evidence |
| CF14 masked by weakening M9-built blocking checks | high | Option (b) formalizes advisory tier WITHOUT touching the 13 blocking checks; NAMED-TOOL/root-cause wording, not brittle counts (handoff :409) |
| Folding stray-file deletion into the docs run violates scope discipline | medium | Hygiene is PROPOSAL-ONLY in evidence; execution is a separate human-gated approval (master :97) |

## Assumptions

| Assumption | Confidence | How to Verify |
|---|---|---|
| `orchestration/harness-matrix.json` is the matrix SSoT (self-tagged "M10 owns the narrative doc") — the new ENFORCEMENT_MATRIX narrates, not re-authors | high | Read the JSON provenance block + `dmc doctor` per-host render |
| `AGENTS.md` does not ship to hosts and no CI/selftest asserts its bytes | high | INSTALL_MANIFEST "DELIBERATELY NOT COPIED" list; agents-md selftest is mktemp-hermetic (:584) |
| `.harness/schemas/release-readiness.schema.md` is editable (NOT in the 3-schema mirror set) | high | M9 CF13d note; it is a standalone NEW schema, not a generated mirror |
| The composer stays frozen; "consumed by the release gate" = out-of-band binding | high | `grep -c checklist bin/lib/dmc-release-gate.py` = 0; SUB_GATES fixed at 9 (:63-64) |
| CF14 must be a human decision BEFORE the checklist is finalized | high | Lane-5 risk; the checklist's CI-tier item depends on it |
| Orchestrator/worker split: Opus implements T016.1/T016.3 (identity + honesty docs), Sonnet T016.2/T016.4/T016.5 (mechanical consistency + tables); all subagents `auto` mode, dispatched synchronously; Ring-0 guards enforce independently | high | handoff :303-312; per-task owner labels |

## Execution Tasks

- [ ] DMC-T016.1: v1.0 identity refresh (Opus). Retitle/rewrite the 8 product-identity sites (incl.
  NOTION_EXPORT_SUMMARY.md:13, critic-r1 BL2) + fix the 3 shipped docs + CONTEXT_MAP.md:16 mislabel;
  apply the GATE-DECISIONS (AGENTS.md method, provenance-tag style, version-verb NO) as ratified at
  the gate.
  Files: DMC.md, CLAUDE.md, AGENTS.md, docs/CONTEXT_MAP.md, docs/OMC_COEXISTENCE.md,
  docs/HOST_REPO_ARTIFACT_POLICY.md, docs/HOST_REPO_ADAPTATION_POLICY.md, docs/NOTION_EXPORT_SUMMARY.md.
  Notes: SOLE owner of these files; surgical, load-bearing-text-preserving; DMC.md/CLAUDE.md/AGENTS.md are
  non-ordinary landmarks. No blockedBy.
- [ ] DMC-T016.2: M1 doc-trio consistency + P20 cleanup (Sonnet). P20 Codex-Stop correction; Status
  DESIGN→IMPLEMENTED (2 files); FABLE column relabel; §4 standard-impl reconciliation.
  Files: docs/DMC_V1_RUNTIME_ARCHITECTURE.md, docs/DMC_V1_ORCHESTRATION_MODEL.md, docs/FABLE_WORKFLOW_TRANSFER.md.
  Notes: SOLE owner; relabel-not-rewrite for the FABLE column. No blockedBy.
- [ ] DMC-T016.3: three NEW docs + surgical schema/CI-comment edits (Opus). ENFORCEMENT_MATRIX,
  HONEST_SCOPE, RELEASE_CHECKLIST + release-readiness.schema.md:118-121 reword + dmc-ci.yml comment pointers.
  Files: docs/DMC_V1_ENFORCEMENT_MATRIX.md, docs/DMC_V1_HONEST_SCOPE.md, docs/DMC_V1_RELEASE_CHECKLIST.md,
  .harness/schemas/release-readiness.schema.md, .github/workflows/dmc-ci.yml.
  Notes: SOLE owner; NO composer edit; honesty discipline (no enforced-lexeme on Codex lines); CF14 (b) + D1
  documented. blockedBy none (data sources shipped) but reviewed after T016.2 for consistency.
- [ ] DMC-T016.4: Audit Blocker B1-B10 traceability table (Sonnet). NEW verification file mapping each
  blocker → mechanism → evidence; B6 closed-in-M10; B8 by-design NO-ACTION + pointer; CF14/D1 dispositions.
  Files: .harness/verification/dmc-v1-runtime-upgrade.md.
  Notes: SOLE owner; title "Audit Blocker B1-B10" (NOT FABLE B1-B13). blockedBy T016.1–T016.3 (cites their evidence).
- [ ] DMC-T016.5: MILESTONES.md v1.0 closure entry (Sonnet, append-only). "## v1.0 … CLOSED" 7-subsection
  entry for M1-M10; reconcile the stale "Next:" pointer.
  Files: docs/MILESTONES.md.
  Notes: append-only; content human-gated at the commit gate. blockedBy T016.1–T016.4.
- [ ] DMC-T016.6: M10 release run + full gate (orchestrator lane). run start → scope.lock compile
  (landmark_authorized) → materialize green evidence set (verify-plan.json + receipts + findings.json +
  goal-ledger.json + decision-record.json + approvals.jsonl with a release record whose verification_ref →
  a `dmc validate verification`-VALID `.harness/verification/dmc-v1-m10-release.md`) → STAGE exactly scope
  files → `dmc gate release --full --run-id <M10-RID>` PASS; record dispositions (2)(3); update master
  §Approval Status M10 at closure.
  Files: .harness/runs/<M10-RID>/**, .harness/evidence/dmc-v1-m10-*.md,
  .harness/verification/dmc-v1-m10-release.md, .harness/plans/dmc-v1-runtime-upgrade.md §Approval Status.
  Notes: gate BEFORE committing (readiness write-once; diff-scope committed-diff blindness); FLAG expected on
  identity docs. blockedBy T016.1–T016.5.

## Verification Commands

| Command | Reason | Required |
|---|---|---|
| `dmc linkcheck` | new-doc path/verb refs resolve; no dangling machine-consumable ref | yes |
| VC2 — scoped product-identity grep (fenced verbatim below; critic-r1 BL1 rewrite) ⇒ proven NON-EMPTY pre-edit, EMPTY post-edit | product-identity claim check; a vacuous EMPTY (pattern error) is itself a FAIL; archival allowlist excluded by file | yes |
| VC3 — AGENTS.md check per ratified branch: regenerate ⇒ `dmc agents-md --validate AGENTS.md` VALID; hand-edit ⇒ landmark-inventory review vs `dmc landmarks` (critic-r1 AD3) | AGENTS.md contract/orientation validity | yes |
| VC4 — codex-honesty grep (fenced verbatim below; all 7 doctor lexemes word-boundary + 2 required substrings; critic-r1 AD1) | new docs never over-claim Codex enforcement | yes |
| `dmc selftest` (fast default) | section counts unchanged | yes |
| `dmc selftest m8-suite` · `dmc selftest agents-md` | manifest content-independence + agents-md validator green | yes |
| `dmc selftest release-gate` · `dmc mirror-check` | frozen composer 39/0 + 55-file byte-equality intact | yes |
| `dmc selftest --all` (committed replica, then post-commit live) | legacy 802/3/3 EXACT + every section 0 FAIL (CF1 — never masked) | yes |
| `dmc validate verification .harness/verification/dmc-v1-runtime-upgrade.md` · `dmc validate verification .harness/verification/dmc-v1-m10-release.md` | traceability table + M10 report instance-valid | yes |
| `dmc gate release --full --run-id <M10-RID>` | overall PASS, all 9 sub-gates non-FAIL/non-MISSING, landmark-flag FLAG | yes |
| `git status --porcelain` before/after each suite; `git diff --name-only` vs this plan's allowlist | repo hygiene + scope conformance | yes |
| `gh run view <id> --json conclusion` (post-push) | CI green on branch (the post-push criterion) | yes |

Verbatim command definitions (critic-r1 BL1/AD1 — pipe-free `-e` alternation so the commands are
valid ERE AND markdown-table-safe; run exactly as written):

```sh
# VC2 — scoped product-identity grep. MUST be NON-EMPTY on the pre-edit tree (proves the check
# sees the 8 sites) and EMPTY on the post-edit tree. Archival allowlist excluded by file.
grep -rInE \
  -e '# Do-Me-Coding v0\.1$' \
  -e 'uses Do-Me-Coding v0\.1' \
  -e 'Do-Me-Coding v0\.1 ' \
  -e 'runtime in v0\.1' \
  -e 'clone in v0\.1' \
  -e '## v0\.1 Scope' \
  -e 'Context Map \(v0\.4\.7\)' \
  -e 'dmc-v0\.1-scaffold' \
  -e 'v0\.1 protections' \
  -e 'Policy \(v0\.1\.3\)' \
  --exclude=MILESTONES.md \
  --exclude=DMC_REAL_REPO_PILOT_REPORT.md \
  --exclude=COMPETITIVE_GAP_LEDGER.md \
  --exclude='_DMC_*.md' \
  DMC.md CLAUDE.md AGENTS.md docs/

# VC4 — codex-honesty check on the three NEW docs: (a) no forbidden lexeme on any codex line
# (all 7 doctor lexemes, word-boundary); (b) required substrings present.
grep -inE 'codex' docs/DMC_V1_ENFORCEMENT_MATRIX.md docs/DMC_V1_HONEST_SCOPE.md \
  docs/DMC_V1_RELEASE_CHECKLIST.md \
  | grep -iwE 'enforced|enforce|fires|firing|active|guaranteed|runtime-enforced'
# ⇒ MUST be EMPTY (exit 1)
grep -c 'ADVISORY' docs/DMC_V1_ENFORCEMENT_MATRIX.md      # ⇒ ≥1
grep -c 'pre-commit/CI' docs/DMC_V1_ENFORCEMENT_MATRIX.md  # ⇒ ≥1
```

## Approval Status

Status: APPROVED (Rev 2)
Approver: wjlee (woojin20020@gmail.com) — human plan gate via AskUserQuestion, 2026-07-08
Approved At: 2026-07-08

Gate record (all four questions answered, every recommendation ratified):
1. Plan approved, build start authorized. Defaults ratified: provenance tags → "introduced in
   v0.x" historical annotations; NO `dmc --version` verb in M10 (v1.1 candidate).
2. **CF14 → OPTION (b)**: formalize the advisory tier + a documented CI-tier baseline as the v1.0
   posture (named-tool root-cause wording, no count pins; the 13 blocking checks NEVER weakened).
   **D1 → DOCUMENT, not harden** (frozen-tool fix = separate v1.1+ hygiene plan).
3. **`.harness/evidence/` dmc-v0.* originals (55 files) → KEEP** (originals canonical; M3 rollback
   guarantee + mirror-check depend on them). Decision recorded in the traceability table.
4. **AGENTS.md → REGENERATE** via `dmc agents-md` against real HEAD (temp-generate → adopt under
   scope); generated bytes reviewed at build critic; `--validate` VALID is the acceptance branch.
Stray-file hygiene remains PROPOSAL-ONLY inside M10 evidence (execution = separate approval).

Rev 2.1 (arming correction, 2026-07-08 — administrative, no content/scope-intent change): the
first armed run (dmc-run-e683f0168cfc) hit the v0.2.6 G2↔G3 structural catch-22 — an
`.harness/evidence/` path granted in scope.lock enters the gate-checks allowlist, where G2 demands
it staged while G3 forbids staging evidence. Per the M9 designed green pattern (evidence files are
covered by the scope-guard/diff-scope built-in evidence exemption, never scope.lock grants), the
re-armed run's landmarks drop the single `.harness/evidence/dmc-v1-m10-build-20260708.md` create
grant (20 grants; bounds unchanged). All build edits, checks, and the first run's readiness FAIL
record are preserved in the run archives; nothing was hidden or re-staged to game the gate.

Critic chain: r1 NEEDS_CLARIFICATION (BL1 vacuous grep, BL2 NOTION scope gap;
`.harness/evidence/dmc-v1-m10-critic-r1.json`, Rev 1 hash 0bcc4bdc…) → Rev 2 fold → r2 APPROVE,
0 blockers, 4 low advisories (`.harness/evidence/dmc-v1-m10-critic-r2.json`, Rev 2 pre-approval
hash 3897dd1d…). Critic-r2 advisories carried as MANDATORY build directives: AD-r2-1 (note that
VC4 is word-boundary, stricter-scoped than the doctor's substring model — not byte-identical),
AD-r2-2 (ENFORCEMENT_MATRIX renders one harness per line — no claude enforced-cell sharing a
physical line with a codex cell), AD-r2-3 (allowlist gains an "analytical/historical version-range
references" category: HARNESS_LANDSCAPE_2026.md, HARNESS_BENCHMARK_CARDS_2026.md), AD-r2-4 (VC2
excludes are redundant-but-harmless, not load-bearing).
