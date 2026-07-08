# DMC Constitution — Single Top-Level Governance Document

**Rev 2** — critic r1 NEEDS_CLARIFICATION (`.harness/evidence/dmc-constitution-critic-r1.json`,
Rev 1 hash `c3bd1190…`) folded: **B1** Art. VI precedence rescoped — constitutional supremacy
covers GOVERNANCE/PROCESS only (amendment, precedence, frozen-surface enumeration, change
procedure); enforcement/behavior FACTS defer to the machine SSoT (schemas + orchestration/*.json,
now in the ladder); **B2** Art. V enumerates the FULL `DMC_GATE_*` override surface
(PROTECTED / EXCLUDED / UPSTREAM — only PROTECTED carries the G4 landmark-authorization guardrail;
the same authorization discipline applies to any override that flips a blocking verdict);
**B3** Art. II gains the 13 M9-built CI blocking checks + porcelain sandwiches (CF14 "NEVER
weakened"), the orchestration registries (machine SSoT — amended only via the Art. III cycle), and
the `.claude/settings.json` hook-registration surface (enforcement wiring — landmark-authorized
scope required). Advisories folded: A1 (Art. VII REQUIRES the whole-word codex-lexeme check re-run
on every amendment), A2 (AC3 grep adds `.agents/skills`), A3 (NEW cite-density AC — every
normative clause carries an inline source path). Cite fix: the 55-file KEEP ratification cites the
M10 gate record, not handoff :9.

## Goal

Author `docs/DMC_CONSTITUTION.md`: a strict, single, top-level governance document that a future
maintainer model (an Opus 4.8 session without the current orchestrator's context) MUST consult
before fixing errors or making changes to this repository. It codifies what may NEVER change, how
change happens, document precedence, and how the constitution itself is amended — consolidating the
today-distributed "constitution" (DMC.md 7 rules, the enforcement matrix, honest-scope register,
release checklist, carry-forwards) into one authoritative, discoverable index of law vs. history.

## User Intent

docs (wjlee directive 2026-07-08: "헌법도 오늘 작업해서 써서 넣자" — write the constitution in
today, as the same-day follow-up to the v1.0.1 activation tuning).

## Current Repo Findings

- The governing rules are today DISTRIBUTED with no single entry point: 7 non-negotiables live in
  `DMC.md:16-24`; secret-protection in `DMC.md:90-104`; the residual/CF14/D1 disclosure ledger in
  `docs/DMC_V1_HONEST_SCOPE.md` (§4 :65-121, §5 CF14 :122-129, §6 D1 :131-149); the 5-tier surface
  taxonomy + Codex honesty rule in `docs/DMC_V1_ENFORCEMENT_MATRIX.md:13-25,94-120`; the 9-sub-gate
  composer mirror + human-gate items in `docs/DMC_V1_RELEASE_CHECKLIST.md:19-46`; the load-bearing
  carry-forwards in `.harness/plans/dmc-v1-runtime-upgrade-handoff.md:332-427`.
  Source: the files above.
- The G4 override GUARDRAIL precedent is recorded but not yet elevated to law: removing
  `.claude/hooks` from `DMC_GATE_PROTECTED` is legitimate ONLY under a landmark-authorized
  scope.lock + human plan gate + critic/verifier chain, and the independent landmark-flag is the
  structural backstop that the override cannot suppress.
  Source: `.harness/evidence/dmc-v1.0.1-build-20260708.md:70-77`.
- The "NEVER grant `.harness/evidence` paths in scope.lock" lesson (the M10 G2↔G3 evidence-grant
  catch-22) is recorded as a session correction, not codified.
  Source: `.harness/plans/dmc-v1-runtime-upgrade-handoff.md:16`; `.../dmc-v1.0.1-build-20260708.md:52-53`.
- CF1 discipline (never "fix"/mask the pinned 802/3/3 baseline inside a feature milestone — only a
  separate human-gated hygiene milestone) and CF14 (the baseline is a macOS-dev artifact; 13
  M9-built blocking checks NEVER weakened) are the exact frozen-surface invariants.
  Source: handoff `:334-335` (CF1), `:415-427` (CF14); `HONEST_SCOPE.md:122-129`.
- The codex-honesty lexeme discipline is machine-enforced: no `/codex/i` line may carry
  `enforced|enforce|fires|firing|runtime-enforced|active|guaranteed`; Codex prose must carry
  `ADVISORY` + `pre-commit/CI`.
  Source: `bin/lib/dmc-doctor.py:86-88`.
- SHIPPING/DISCOVERABILITY (decisive): AGENTS.md is deliberately NOT installed
  (`.claude/install/dmc-install.sh:373,417`); `docs/CONTEXT_MAP.md` is NOT shipped (`SUPPORT_DOCS`
  = the 3 host-operating docs only, `dmc-install.sh:51`). The dangling-reference scan greps only
  `DMC.md`, `CLAUDE.md`, `adapters/`, `.claude/skills`, `.claude/agents`
  (`tests/fixtures/m8/test-manifest-drift.sh:99-101`; rule `INSTALL_MANIFEST.md:295-308`). Therefore
  a pointer to a repo-internal `docs/DMC_CONSTITUTION.md` from AGENTS.md or CONTEXT_MAP.md ships
  nothing and trips no manifest rule; a pointer from DMC.md/CLAUDE.md/skills/agents WOULD.
  Source: the files above.
- The linkcheck scan surface is `.claude/skills/*/SKILL.md`, `.claude/agents/*.md`, and 3 pointer
  docs (`bin/lib/dmc-orchestration-linkcheck.py:219-222`) — it does NOT scan AGENTS.md,
  CONTEXT_MAP.md, or the new constitution, so no machine-consumable-ref regression is introduced;
  linkcheck is still run to confirm no regression.
  Source: `bin/lib/dmc-orchestration-linkcheck.py:219-222`.
- `dmc agents-md --validate` is STRUCTURAL only (10 sections present/non-empty/titled/filler-free,
  `bin/lib/dmc-agents-md.py:417-442`); the §7 companion-docs line is a HAND-MAINTAINED addendum that
  regeneration drops (the v0.4.7 AC6 pointer-loss catch, handoff rev 9 `:16`), so an additive
  pointer edit is the established AC6 pattern. AC6 greps AUTONOMY.md + CONTEXT_MAP.md presence
  (`bin/lib/dmc-v0.4.7-context-audit.sh:52-53`); those tokens must be PRESERVED.
  Source: `AGENTS.md:237-239`; `bin/lib/dmc-agents-md.py:417-442`; `bin/lib/dmc-v0.4.7-context-audit.sh:52-56`.
- Task-ID namespace: `DMC-T018` is the highest master-sequence ID; `DMC-T019` is unused
  (`grep DMC-T019` empty). `DMC-T101-105` is the separate v0.5-direction plan namespace.
  Source: repo grep.

## Relevant Files

| Path | Reason | Allowed to Edit |
|---|---|---|
| docs/DMC_CONSTITUTION.md | NEW — the constitution (Art. I–VII) | yes (create) |
| AGENTS.md | §7 companion-docs line — add repo-internal governance pointer (v0.4.7 AC6 pattern) | yes |
| docs/CONTEXT_MAP.md | Operating-contracts table — add one "repo-maintenance governance" row | yes |
| .harness/verification/dmc-constitution.md | NEW — verifier report for this run | yes (create, verifier lane) |
| DMC.md, CLAUDE.md | Shipped host layer — MUST NOT reference the constitution (dangling-ref rule) | no |
| docs/DMC_V1_HONEST_SCOPE.md / ENFORCEMENT_MATRIX.md / RELEASE_CHECKLIST.md | Cited AS SOURCES; unchanged | no |
| .harness/plans/dmc-v1-runtime-upgrade-handoff.md | Cited carry-forward source; unchanged | no |
| bin/lib/**, .claude/hooks/**, INSTALL_MANIFEST.md, .github/workflows/dmc-ci.yml | Frozen enforcement/contract/release surfaces | no |

## Out of Scope

- Any enforcement/behavior change: hooks, installer, manifest, release gate, schemas, CI, doctor.
- The 55-file mirror-pinned frozen surface, `.harness/evidence/dmc-v0.*` originals, the 802/3/3
  baseline, the 9-sub-gate composer, `.before-dmc` trees, the hooks-v0.6.5 fixture (all read-only).
- Any DMC.md / CLAUDE.md / skill / agent / adapter reference to the constitution (would ship / trip
  the dangling-ref rule).
- A version bump and a MILESTONES.md entry (docs-only governance commit — see gate decision (d)).
- Amending, restating, or re-authoring any existing rule text; the constitution CITES sources, it
  does not fork them (a second source-of-truth is forbidden).

## Proposed Changes

- Change: Create `docs/DMC_CONSTITUTION.md` with numbered ARTICLES. The executor writes full prose;
  the decision-complete outline is:
  - **Art. I — Identity & versioning.** Do-Me-Coding v1.x (`DMC.md:1`); `vX.Y.Z`, max two dots;
    patch labels legitimate (v1.0.1 chosen over v1.1 at the human gate, `dmc-v1.0.1-build:8`);
    historical/pinned labels (past MILESTONES entries, `(v1.0; introduced in v0.x)` provenance tags)
    are IMMUTABLE — never rewritten.
  - **Art. II — Immutable surfaces (enumerate).** The 55-file mirror-pinned `dmc-v0.*` tool set +
    their `.harness/evidence/` originals [KEEP, ratified at the M10 gate —
    `.harness/plans/dmc-v1-m10-final-docs.md` §Approval Status]; the 802/3/3 pinned baseline
    [never masked / never re-pinned except via its own human-gated hygiene milestone — CF1,
    handoff `:334-335`]; the 9-sub-gate composer contract [`SUB_GATES` frozen at nine,
    `RELEASE_CHECKLIST.md:10-17`]; **(critic-B3)** the 13 M9-built CI blocking checks + the 2
    porcelain sandwiches [`dmc-ci.yml`; CF14: NEVER weakened, `HONEST_SCOPE.md:122-129`]; the
    orchestration registries [`orchestration/{harness-matrix,roles,models}.json` — machine SSoT,
    amended only via the Art. III cycle] and, symmetrically, the 28 `.harness/schemas/*.schema.md`
    contracts [machine SSoT, same amendability terms — r2-A7]; the `.claude/settings.json`
    hook-registration surface
    [enforcement wiring — changes require a landmark-authorized scope.lock]; `.before-dmc` restore
    trees; the hooks-v0.6.5 fixture; frozen point-in-time records [`v011-verify.sh`,
    `test-rollback.sh`, past MILESTONES entries, archived plans/verifications]; the
    secret-protection rules [all modes, all tools, `DMC.md:90-104`].
  - **Art. III — How change happens (the invariant cycle).** plan [`dmc validate plan` VALID] →
    NON-AUTHORING critic [REVISE until APPROVE] → HUMAN gate [AskUserQuestion; approvals recorded IN
    the plan] → scope.lock [`landmark_authorized` for enforcement/contract/release classes; NEVER
    grant `.harness/evidence` paths, handoff `:16`] → synchronous scoped executors [single-owner per
    file] → independent NON-AUTHORING verifier → critic build sign-off → committed-replica + live
    `selftest --all` [802/3/3] → human commit/push gates → CI green. Lockstep obligations: the
    Claude hook ↔ Codex shim pairing and the 3-copy redaction set stay byte-parallel
    (`HONEST_SCOPE.md:29-30`). **Clause (gate (a)):** main CI red ⇒ FREEZE + a dedicated fix-forward
    milestone; never masked, never weakened.
  - **Art. IV — Enforcement tiers & honesty.** The 5-tier taxonomy (ENFORCED-runtime /
    BLOCKING-at-release / BLOCKING-in-CI / ADVISORY / DOCUMENTED-ONLY, `ENFORCEMENT_MATRIX.md:94-120`);
    the codex-lexeme rule applies to ALL prose incl. this doc (`dmc-doctor.py:86-88`);
    `HONEST_SCOPE.md` is the disclosure LEDGER — a new residual is appended there, never silently
    dropped; DMC-priority is instruction-level best-effort, not a runtime boundary; the doctor
    honesty split (Claude proven / Codex ADVISORY) stands.
  - **Art. V — Gate overrides & escape hatches.** **(critic-B2)** The FULL `DMC_GATE_*` override
    surface of the frozen v0.2.6 runner is enumerated (`dmc-v0.2.6-gate-check-runner.sh:16,21,36-38`):
    `DMC_GATE_PROTECTED` (protected-path list), `DMC_GATE_EXCLUDED` (excluded auto-logged evidence
    set), `DMC_GATE_UPSTREAM` — ONLY `DMC_GATE_PROTECTED` carries the G4 landmark-authorization
    guardrail precedent, and the SAME authorization discipline (landmark-authorized scope.lock +
    human plan gate + critic/verifier chain) applies to ANY override that flips a blocking verdict.
    The G4 guardrail VERBATIM (`dmc-v1.0.1-build:70-77`): legitimate ONLY under landmark-authorized
    scope.lock + human plan gate + critic/verifier chain; the independent landmark-flag is the
    non-suppressible structural backstop; this record MUST NOT be cited to bypass G4 for an
    unauthorized hook change. The write-once readiness-removal discipline (a FAIL readiness is
    REMOVED to re-gate; the FAIL sequence is recorded in evidence prose, `dmc-v1.0.1-build:70-73`).
    The `v011-verify` / `test-rollback` known-baseline deltas (gate on invariant rows, never
    launder — v011 39/2, `dmc-v1.0.1-build:44-46`). Mode switches (`.harness/mode`) NEVER weaken
    the Block-A / L0 floors.
  - **Art. VI — Document precedence (critic-B1 rescoped).** The constitution's supremacy covers
    GOVERNANCE and PROCESS ONLY — amendment rules, precedence, the frozen-surface enumeration, and
    the change procedure. For enforcement/behavior FACTS the machine SSoT wins over ALL prose,
    including this document (`ENFORCEMENT_MATRIX.md:9-11`). Ladder: (governance/process)
    Constitution → (machine SSoT for facts) `.harness/schemas/*` contracts (28) +
    `orchestration/{harness-matrix,roles,models}.json` → `DMC.md` non-negotiables → `CLAUDE.md`
    (host layer) → ENFORCEMENT_MATRIX / HONEST_SCOPE / RELEASE_CHECKLIST (narrative) → handoff &
    session logs (HISTORY, not law).
  - **Art. VII — Amendment.** The constitution changes ONLY via the full Art. III cycle + explicit
    human ratification; NO amendment may weaken Art. II or the secret-protection floor; each
    amendment APPENDS to an in-document amendment log (date, ratifying commit, one-line summary);
    **(critic-A1)** every amendment MUST re-run the whole-word codex-lexeme check
    (`dmc-doctor.py:86-88` set) over the amended document before its commit gate.
  Files: docs/DMC_CONSTITUTION.md
  Rationale: one authoritative, discoverable entry point so a fresh maintainer model consults law
  before touching frozen surfaces.
- Change: Add ONE repo-internal-governance pointer to the AGENTS.md §7 companion-docs line
  (additive; AUTONOMY.md + CONTEXT_MAP.md tokens preserved for AC6).
  Files: AGENTS.md
  Rationale: discoverability from non-shipped project memory (the v0.4.7 AC6 pattern).
- Change: Add ONE row to the CONTEXT_MAP.md operating-contracts table — concern
  "repo-maintenance governance / amendment" → canonical source `docs/DMC_CONSTITUTION.md`.
  Files: docs/CONTEXT_MAP.md
  Rationale: repo-internal pointer index; not shipped, so no manifest/linkcheck impact.
- GATE-DECISIONS to surface at the human gate (recommendations): **(a)** add a "main CI red =
  freeze + fix-forward milestone" clause to Art. III — RECOMMEND YES. **(b)** scope: REPO-INTERNAL
  (recommended) vs host-shipped — RECOMMEND repo-internal (it governs maintaining THIS repo).
  **(c)** discoverability pointer set — AGENTS.md companion line + one CONTEXT_MAP row, NOT
  DMC.md/CLAUDE.md/skills (manifest-verified safe). **(d)** release label — docs-only governance
  commit, NO version bump, NO MILESTONES entry (RECOMMENDED) vs fold under v1.0.1 closure docs.

## Acceptance Criteria

- Criterion: `docs/DMC_CONSTITUTION.md` exists with Articles I–VII, each numbered and non-empty,
  and an in-document amendment log stub (Art. VII).
  Verification Method: `grep -nE '^## (Article|Art\.) (I|II|III|IV|V|VI|VII)\b' docs/DMC_CONSTITUTION.md` shows 7; amendment-log heading present.
- Criterion: Every enforced-class lexeme on a `/codex/i` line is absent in the new doc (VC4/codex
  honesty discipline holds in constitution prose).
  Verification Method: `grep -niE 'codex' docs/DMC_CONSTITUTION.md` then confirm no matched line contains `enforced|enforce|fires|firing|runtime-enforced|active|guaranteed` (whole-word), per `dmc-doctor.py:86-88`.
- Criterion: The constitution is NOT referenced from any shipped surface (DMC.md, CLAUDE.md,
  adapters/, .agents/skills, .claude/skills, .claude/agents — the REAL dangling-ref scan surface,
  critic-A2).
  Verification Method: `grep -rl 'DMC_CONSTITUTION' DMC.md CLAUDE.md adapters .agents/skills .claude/skills .claude/agents` returns empty.
- Criterion (critic-A3, cite-density): every normative clause in the constitution carries an
  inline source path (CITE-not-fork is verifiable, not aspirational).
  Verification Method: reviewer pass over the doc — each Article's normative statements name their
  source file (path or path:line); the verifier's report records the check; zero uncited normative
  clauses.
- Criterion: AGENTS.md still passes structural validation and v0.4.7 AC6 (AUTONOMY.md +
  CONTEXT_MAP.md pointers intact) after the additive edit.
  Verification Method: `dmc agents-md --validate AGENTS.md` = VALID; `bash bin/lib/dmc-v0.4.7-context-audit.sh --self-test` = 7/0.
- Criterion: The manifest ship-surface is content-independent of this change (no new shipped file,
  no dangling reference).
  Verification Method: `dmc selftest m8-suite` green (incl. the dangling-ref scan).
- Criterion: No enforcement/frozen-surface regression.
  Verification Method: `dmc selftest` (default) 0 FAIL; `dmc mirror-check` PASS; `dmc linkcheck` clean; live `selftest --all` = 802/3/3 ONLY IF any non-doc file is touched (docs-only ⇒ record rationale that the frozen surface is untouched).

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| A constitution reference leaks into a shipped file (DMC.md/CLAUDE.md/skill) and trips the dangling-ref rule | medium | Out-of-scope-locked; AC3 grep asserts empty; m8-suite dangling-ref scan is CI-blocking |
| AGENTS.md edit flagged as guessed "filler" or drops the AC6 pointers | medium | Additive one-line pointer; keep AUTONOMY.md + CONTEXT_MAP.md tokens; `agents-md --validate` + AC6 re-run |
| A codex-lexeme (`active`/`enforced`) slips into constitution prose on a Codex line | medium | VC4-style grep AC; phrase Codex mentions as ADVISORY + pre-commit/CI |
| The constitution restates a rule and silently forks a second source-of-truth | medium | Art. VI precedence + CITE-not-fork discipline; constitution links to sources, never re-authors them |
| CONTEXT_MAP.md edit breaks the AC1/AC2 non-conflict/orthogonality checks | low | Add one additive row only; run v0.4.7 audit (7/0) |

## Assumptions

| Assumption | Confidence | How to Verify |
|---|---|---|
| Constitution is repo-internal (governs maintaining THIS repo, not host operation) | high | Gate decision (b); confirmed by shipping analysis (`dmc-install.sh:51,373,417`) |
| AGENTS.md + CONTEXT_MAP.md are non-shipped, so pointers never dangle | high | `dmc-install.sh:51,417`; `test-manifest-drift.sh:99-101` |
| Docs-only commit ⇒ no live `--all` needed (frozen surface untouched) | high | Scope lock excludes all non-doc files; live `--all` run only if that holds false |
| DMC-T019 is the free master-sequence task ID | high | `grep DMC-T019` empty |

## Execution Tasks

- [ ] DMC-T019.1: Author `docs/DMC_CONSTITUTION.md` Articles I–VII per the decision-complete outline (incl. gate-(a) CI-freeze clause and the G4 guardrail verbatim).
  Files: docs/DMC_CONSTITUTION.md
  Notes: CITE sources by path; do NOT restate/fork rule text; keep every Codex mention ADVISORY (VC4).
- [ ] DMC-T019.2: Add the repo-internal-governance pointer to the AGENTS.md §7 companion-docs line (additive; preserve AUTONOMY.md + CONTEXT_MAP.md).
  Files: AGENTS.md
  Notes: single line; re-run `agents-md --validate` + v0.4.7 AC6.
- [ ] DMC-T019.3: Add one operating-contracts row (repo-maintenance governance → `docs/DMC_CONSTITUTION.md`) to CONTEXT_MAP.md.
  Files: docs/CONTEXT_MAP.md
  Notes: additive row only; no mode/level redefinition.
- [ ] DMC-T019.4: (verifier lane) Author `.harness/verification/dmc-constitution.md` recording the AC evidence.
  Files: .harness/verification/dmc-constitution.md
  Notes: non-authoring verifier; independent of the authoring lane.

## Verification Commands

| Command | Reason | Required |
|---|---|---|
| `grep -nE '^## (Article\|Art\.) ' docs/DMC_CONSTITUTION.md` | Articles I–VII present | yes |
| `grep -niE 'codex' docs/DMC_CONSTITUTION.md` + whole-word lexeme check on matched lines | VC4 codex-lexeme discipline (expect no forbidden word) | yes |
| `grep -rl 'DMC_CONSTITUTION' DMC.md CLAUDE.md adapters .agents/skills .claude/skills .claude/agents` | No shipped-surface reference — full 6-surface scan (expect empty; r2-A5) | yes |
| `dmc agents-md --validate AGENTS.md` | AGENTS.md still VALID after pointer edit | yes |
| `bash bin/lib/dmc-v0.4.7-context-audit.sh --self-test` | Context audit 7/0 (AC6 pointers intact) | yes |
| `dmc selftest m8-suite` | Manifest content-independence + dangling-ref scan | yes |
| `dmc selftest` | Default suite 0 FAIL | yes |
| `dmc mirror-check` | Frozen 55-file mirror intact | yes |
| `dmc linkcheck` | No machine-consumable-ref regression | yes |
| `dmc selftest --all` (live) | 802/3/3 — ONLY if any non-doc file is touched; else document rationale | no |

## Approval Status

Status: APPROVED (Rev 2)
Approver: wjlee (woojin20020@gmail.com) — human plan gate via AskUserQuestion, 2026-07-08
Approved At: 2026-07-08

Gate record (all three questions answered):
1. Plan approved, authoring start authorized (defaults ratified: repo-internal scope — host
   non-shipping, manifest-impact-verified; AGENTS.md + CONTEXT_MAP pointer set).
2. **CI-freeze clause → INCLUDED** in Art. III: "main CI red ⇒ immediate FREEZE of all other
   work + a dedicated fix-forward milestone; masking forbidden" — explicitly ratified as new
   policy.
3. **Release handling → docs-only commit, NO version bump, NO MILESTONES entry**; the v1.0.1
   closure evidence lines ride the same commit.

Critic chain: r1 NEEDS_CLARIFICATION (B1 precedence circularity, B2 override-surface gap,
B3 immutable-enumeration gap; `.harness/evidence/dmc-constitution-critic-r1.json`, Rev 1 hash
`c3bd1190…`) → Rev 2 fold → r2 APPROVE, 0 blockers (`.harness/evidence/
dmc-constitution-critic-r2.json`, Rev 2 hash `7e4eb33c…`; its A5/A6/A7 polish advisories folded
pre-approval). Build directives: CITE-not-fork with the cite-density AC; VC4 codex-lexeme
discipline over the whole document; Art. VII carries the amendment-time lexeme re-run duty.
