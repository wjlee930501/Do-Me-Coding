# Plan — Constitution Amendment No. 2: Article VIII (Maintainer Duties & the Inviolable Loop)

**Rev 2** — critic r1 NEEDS_CLARIFICATION (`.harness/evidence/dmc-constitution-amend2-critic-r1.json`,
Rev 1 hash `74f0f914…`) folded: **B1** — VIII.2 now entrenches the CANONICAL 6-stage loop
**plan → critic → scope → execute → verify → evidence** (the critic stage was missing from the
5-stage shorthand; a critic-less loop as "essence" would collide with III.1 and the
VII.2-protected non-authoring-critic requirement); **B2** — VIII.3(a) forbids UNAUTHORIZED or
UNDISCLOSED masking only, explicitly deferring to Article V's bounded escape hatches (V.2/V.3
authorized overrides, V.6 mode hatch) and the disclosed III.4 advisory-replay carve-out + V.5
known-baseline handling (no intra-constitutional contradiction). Advisories folded: A1 (the
"forbidden as FIXES" qualifier is explicit in the article text), A2 (the TODO rule is scoped to
repo-committed shipped/source surfaces; `.harness/**` run machinery, scratchpads, and exploratory
analysis are exempt), A3 (GATE-DECISION: VIII.4 names `AUTONOMY.md` stop-conditions as BINDING —
recommend YES, schema-backed; BIND, never restate), A4 (VIII.3e framed as a lockstep-parity
obligation, no enforcement-tier claim on the Codex host), A5 (GATE-DECISION: the VI.1 touch is a
NAMED human decision — recommend INCLUDE), A6 (VIII.5 behavior-preservation proof applies where a
machine suite exists; docs use the --all-SKIP precedent; byte-frozen surfaces excluded — refactor
forbidden outright), A7 (T020.5/.6 run as an independent fresh-context verifier lane; the VERIFIER
captures the VII.4 lexeme evidence).

## Goal

Amend `docs/DMC_CONSTITUTION.md` (currently Articles I–VII, 211 lines, founding text ratified 2026-07-08 at HEAD `ccffc38`) to add **Article VIII — Maintainer Duties & the Inviolable Loop**, extend Article VII.2's entrenched protected set to include Article VIII, and append Amendment Log entry No. 2 — the first exercise of the constitution's own Article VII amendment procedure. This is a docs-only governance change: no version bump, no `MILESTONES.md` entry (founding-text precedent, `docs/DMC_CONSTITUTION.md:3-4`).

## User Intent

wjlee (2026-07-08, verbatim): the constitution must ALSO bind every future maintainer REGARDLESS of model-capability tier (weaker-than-current-orchestrator included); guarantee the essence / unique loop (본질과 고유의 루프) survives both maintenance (유지보수) AND enhancement (고도화); and STRUCTURALLY block ad-hoc patch-work (주먹구구식 땜질) development at the source (원천 봉쇄). Article VIII encodes these as binding maintainer duties, not aspirations.

## Current Repo Findings

- **Article count = 7** — headings verified via `grep -cE '^## Article '` at `:29/:43/:86/:110/:131/:164/:188`. Adding VIII → 8.
- **VII.2** (`:193-198`) protected set: Article II, secret floor II.8, VII.2-itself + Art. VII entrenchment, Art. VI precedence, Art. III human-gate + non-authoring critic/verifier. Trailing **effect-clause** `:197-198` ("An amendment whose EFFECT is to enable any of those weakenings in a later step is itself a weakening") already generalizes over any added member.
- **VII.4** (`:203-205`): every amendment re-runs the whole-word honesty-lexeme check (forbidden set `bin/lib/dmc-doctor.py:86-88` = enforced/enforce/fires/firing/runtime-enforced/active/guaranteed) over the amended doc; grep output attached as evidence at the commit gate.
- **Amendment Log**: `### Amendment Log` (h3) at `:207`, table `:209-211`, founding row #1 (`2026-07-08 | this commit | Founding text`) at `:211`.
- **Loop sources**: DMC.md non-negotiables 1–4 (`:18-21`), Default Loop (`:26-41`); Art. III.1 loop (`:88-90`); AGENTS.md §7 core loop (`:235`).
- **Anti-patchwork source material**: III.4 never-mask (`:104-108`), CF1 (II.2, `handoff:334-335`), CF14/II.4 never-weaken (`HONEST_SCOPE:122-129`), IV.3 residual ledger (`HONEST_SCOPE:65-68`), III.3 + HONEST_SCOPE lockstep (redaction 3-copy set `HONEST_SCOPE:29-30`), scope discipline III.2 stage (4)-(5).
- **Escalation source**: non-negotiable rule 1 (`DMC.md:18`), III.2 stage (3) human gate, Preamble read-before-change / when-in-doubt-substantial (`:15-18`), AUTONOMY.md stop-conditions (per AGENTS.md §7 `:237`).
- **Live-checked baselines** (read-only, on current bytes): lexeme grep over the doc → **EMPTY (exit 1)**; 6-surface reverse-ref `grep -rl 'DMC_CONSTITUTION' DMC.md CLAUDE.md adapters .agents/skills .claude/skills .claude/agents` → **EMPTY (exit 1)**; AGENTS.md §7 (`:239`) and CONTEXT_MAP row (`:19`) already point at the **document** (not its article list) — **NO update needed**.
- Latest task namespace on plans is DMC-T019 (the founding constitution plan) → this amendment = **DMC-T020**.

## Relevant Files

| Path | Reason | Allowed to Edit |
|---|---|---|
| docs/DMC_CONSTITUTION.md | insert Article VIII; extend VII.2; (recommended) one-clause VI.1 touch; append Log row #2 | yes (edit) |
| .harness/verification/dmc-constitution-amend2.md | verifier lane — full AC battery + the **VII.4 lexeme-grep output as a fenced block** (this report IS the VII.4 evidence artifact) | yes (create) |

Scope.lock = **2 grants** (edit + verifier-lane create), NOT `landmark_authorized` (no enforcement/contract/release file touched), and **NO `.harness/evidence` grant** (G2↔G3 catch-22, III.2 stage 4). Human-gated per VII.1.

## Out of Scope

- `AGENTS.md §7` and `docs/CONTEXT_MAP.md:19` — already point at the document; **no change** (would risk the reverse-ref rule if article-list-specific).
- `DMC.md`, `CLAUDE.md`, `adapters/`, `.agents/skills`, `.claude/skills`, `.claude/agents` — the 6-surface reverse-ref set MUST stay EMPTY; MUST NOT reference the constitution.
- Any machine SSoT (28 schemas, 3 registries), hooks, installer, gate runner, CI — untouched (keeps the `--all` SKIP valid).
- Version bump / `MILESTONES.md` entry — none (docs-only governance).
- Promoting the Amendment Log h3→h2 — deferred (keep minimal); Article VIII is inserted immediately BEFORE the log block so the log remains the document-closing appendix.

## Proposed Changes

**1. Insert Article VIII** between VII.4 (`:205`) and `### Amendment Log` (`:207`). Five clauses, each cite-dense (BIND existing sources; re-author nothing — Preamble `:22-25` no-second-source rule):

- **VIII.1 CAPABILITY-INDEPENDENCE** — binds every maintainer, human or model of ANY tier; a less-capable maintainer gets NO relaxed path; capability doubt TIGHTENS duty (weaker maintainer ⇒ smaller permitted step). Cite `DMC.md:16-24`, Art. III, Preamble `:15-18`.
- **VIII.2 THE INVIOLABLE LOOP (본질)** — **(critic-B1)** the CANONICAL loop
  **plan → critic → scope → execute → verify → evidence** IS the essence of DMC (the 6-stage form
  of Art. III.1 `:88-90` and DMC.md's Default Loop incl. Critic Review `:26-41`; the common
  5-stage shorthand is a shorthand ONLY and never licenses dropping the non-authoring critic
  stage); no maintenance/enhancement may remove, reorder, bypass, weaken, or "temporarily
  suspend" a stage; speed/simplicity/urgency/capability-limit are NEVER valid skip
  justifications. Cite `DMC.md:26-41`, `DMC.md:18-21`, Art. III.1 (`:88-90`).
- **VIII.3 ANTI-PATCHWORK (땜질 원천 봉쇄)** — forbidden **as FIXES** (critic-A1 — exploratory/
  scouting/spike work that produces plans and analysis, not shipped edits, is not "a fix"):
  (a) **(critic-B2)** UNAUTHORIZED or UNDISCLOSED symptom suppression / masking of a red check —
  this generalizes CF1 + never-masked (Art. III.4 `:104-108`, II.2, `handoff:334-335`, CF14/II.4
  `HONEST_SCOPE:122-129`) and EXPLICITLY DEFERS to Article V's bounded escape hatches: a V.2/V.3
  authorized override under a landmark-authorized scope.lock + human gate + critic/verifier
  chain, the V.6 designed mode hatch, and the disclosed III.4 advisory-replay carve-out + V.5
  known-baseline handling remain lawful — what is forbidden is masking WITHOUT that
  authorization-and-disclosure chain; (b) any FIX without a diagnosed root cause recorded in the
  plan (Art. III.1–III.2); (c) any edit outside an approved scope.lock (III.2 stage 4,
  `DMC.md:19`); (d) "temporary" hacks without a registered follow-up — **(critic-A2)** scoped to
  repo-committed shipped/source surfaces (an unregistered TODO **in shipped/source code or
  governing docs** is a violation; `.harness/**` run machinery, scratchpads, and exploratory
  analysis are exempt) (IV.3 ledger `HONEST_SCOPE:65-68`); (e) one-sided edits to lockstep
  surfaces — Claude hook ↔ Codex shim, the 3-copy redaction set — **(critic-A4)** framed as the
  III.3-style lockstep-parity obligation with no enforcement-tier claim (Art. III.3,
  `HONEST_SCOPE:29-30`); (f) drive-by changes folded into an unrelated scope (III.2 stage 5
  single-owner + diff⊆scope discipline).
- **VIII.4 ESCALATION DUTY (weaker-model rule)** — when a maintainer cannot complete ANY stage
  (diagnose, author a valid plan, or verify), the REQUIRED action is STOP + surface to the human
  gate with an honest statement of the unknown; shipping partial/unverified/best-guess =
  violation; "no verification, no done" binds HARDER as capability decreases. **(critic-A3,
  GATE-DECISION)** `AUTONOMY.md` stop-conditions are named as BINDING (recommend YES —
  schema-backed via `.harness/schemas/autonomy.schema.md`; BIND, never restate). Cite
  `DMC.md:18`, III.2 stage (3), `AUTONOMY.md:43-58`, Preamble `:15-18`.
- **VIII.5 ENHANCEMENT (고도화) DISCIPLINE** — additions/upgrades follow the SAME cycle as fixes;
  a new capability must state which loop invariants it preserves; refactors prove behavior
  preservation **(critic-A6: where a machine suite exists** — tests/suites before-and-after,
  II.1 mirror `:52-55`, II.2 `802/3/3` `:57-59`; docs-only governance changes use the --all-SKIP
  precedent with recorded rationale; byte-frozen surfaces are excluded because refactoring them
  is forbidden outright**)**; no enhancement may reduce an existing surface's enforcement tier
  (tier downgrades = Art. II/IV territory, human-gated — IV.1 `:112-114`, II.3/II.4).

**2. Extend VII.2** (`:193-196`) — add "Article VIII (maintainer duties & the inviolable loop)" to the protected enumeration. Leave the effect-clause (`:197-198`) verbatim; it then ranges over VIII automatically. This is net-STRENGTHENING (adds a protection), weakens nothing — VII.2 forbids only weakening.

**3. VI.1 touch** (`:166-168`) — **(critic-A5, GATE-DECISION for the HUMAN)**: name Article VIII
inside the governance-supremacy enumeration, foreclosing a future "the inviolable loop is a
behavior FACT the machine SSoT overrides via VI.2" reading. One additive clause. RECOMMEND
**INCLUDE** (the critic concurs: sound, not scope-creep); include-vs-drop is ratified at the
human gate, never left to critic/executor discretion.

**4. Amendment Log row #2** (`:211+`) — `| 2 | 2026-07-08 | this commit | Article VIII — capability-independent maintainer duties, the inviolable loop, anti-patchwork, escalation & enhancement discipline; VII.2 protected set extended to Art. VIII |`. Row #1 left byte-identical (append-only, VII.3).

**Article VII compliance (explicit):** VII.1 — this plan runs the full Art. III cycle + human ratification. VII.2 — the amendment ADDS Article VIII and EXTENDS the protected set; it weakens no protected clause and its effect enables no later weakening. VII.3 — appends exactly one Log entry, row #1 untouched. VII.4 — scheduled: the lexeme re-run over the amended doc with grep output captured in the verification report at the commit gate (T020.6).

## Acceptance Criteria

- Criterion: Article count is now 8; heading `## Article VIII — Maintainer Duties & the Inviolable Loop` present.
  Verification Method: `grep -cE '^## Article ' docs/DMC_CONSTITUTION.md` → `8`; heading grep matches.
- Criterion: VIII.1–VIII.5 are cite-dense; zero uncited normative sentences; no new second-source-of-truth.
  Verification Method: full read of Article VIII — every clause names ≥1 inline path/path:line into DMC.md / Art. II–IV / HONEST_SCOPE / handoff / AUTONOMY.md; verifier confirms BIND-not-restate.
- Criterion: VII.2 protected set includes Article VIII; effect-clause `:197-198` intact and composing.
  Verification Method: grep VII.2 shows "Article VIII" in the enumeration; manual read confirms "any of those weakenings" now ranges over VIII; effect-clause byte-unchanged.
- Criterion: Amendment Log entry No. 2 present; row #1 byte-unchanged.
  Verification Method: `grep -nE '^\| 2 \|' docs/DMC_CONSTITUTION.md` shows `2026-07-08 | this commit | …`; `git diff` shows founding row untouched.
- Criterion (VII.4): lexeme grep EMPTY, output captured as evidence.
  Verification Method: `grep -niE 'codex' docs/DMC_CONSTITUTION.md` then whole-word grep for the `dmc-doctor.py:86-88` set on matched lines → empty (exit 1); codex-line count 3→4 (VIII.3e adds one), all lexeme-free; fenced output block present in `.harness/verification/dmc-constitution-amend2.md`.
- Criterion: 6-surface reverse-ref still EMPTY.
  Verification Method: `grep -rl 'DMC_CONSTITUTION' DMC.md CLAUDE.md adapters .agents/skills .claude/skills .claude/agents` → empty (exit 1).
- Criterion: context-audit unchanged.
  Verification Method: `bin/dmc agents-md --validate AGENTS.md` → VALID (10 sections); `bash bin/lib/dmc-v0.4.7-context-audit.sh --self-test` → 7 / 0.
- Criterion: no enforcement regression.
  Verification Method: `bin/dmc selftest m8-suite` (dangling-ref green), default `bin/dmc selftest`, `bin/dmc mirror-check` (55/55), `bin/dmc linkcheck` (clean) all green.
- Criterion: docs-only `--all` SKIP justified.
  Verification Method: `git diff --numstat` touches only `docs/DMC_CONSTITUTION.md` (+ verifier-lane create); no frozen/enforcement/contract/registry/hook/schema file; mirror-check 55/55 corroborates; `selftest --all` (802/3/3) SKIPPED.
- Criterion: scope discipline holds.
  Verification Method: `git status --porcelain` diff ⊆ 2-grant scope.lock; no `.harness/evidence` grant; remaining dirt is exempt `.harness/**` run machinery.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| IV.2 lexeme trap: VIII.3(e) is the one Article VIII line matching `/codex/i` — it MUST carry zero forbidden lexemes | medium | VII.4 grep gate (T020.6) + verifier check; executor keeps the codex mention on a lexeme-free sentence |
| Second-source-of-truth (Preamble :22-25): VIII must BIND existing rules, not author new ones | medium | Every clause cites a source; verifier confirms no restated machine fact |
| VI.1 touch judged scope-creep | low | Optional T020.3; drop if the critic rules against — the amendment stands without it |
| Amendment Log heading level (h3) debate | low | Deferred; log stays the closing appendix; a promotion is a separate future touch |
| CI green post-push | low | Observable post-push only; all local CI-equivalent gates re-run green first |

## Assumptions

| Assumption | Confidence | How to Verify |
|---|---|---|
| Ratifying-commit label = "this commit" (founding-row convention) | high | docs/DMC_CONSTITUTION.md:211 |
| Article VIII inserted between VII.4 (`:205`) and the log (`:207`); log remains closing appendix | high | live read |
| Scope.lock = 2 grants, no landmark authorization, no evidence grant | high | grants file at compile |
| Task namespace DMC-T020 free | high | repo grep |
| No file outside the constitution + the verification report is required | high | Findings (AGENTS/CONTEXT_MAP point at the document) |

## Execution Tasks

- [ ] DMC-T020.1: Insert `## Article VIII — Maintainer Duties & the Inviolable Loop` (VIII.1–VIII.5, cite-dense per Proposed Changes) between `:205` and `:207`. Files: docs/DMC_CONSTITUTION.md
- [ ] DMC-T020.2: Extend VII.2 enumeration (`:193-196`) to name Article VIII; leave effect-clause (`:197-198`) verbatim. Files: docs/DMC_CONSTITUTION.md
- [ ] DMC-T020.3: (recommended) Add Article VIII to VI.1 governance-supremacy enumeration (`:166-168`), one additive clause. Files: docs/DMC_CONSTITUTION.md
- [ ] DMC-T020.4: Append Amendment Log row #2 (`:211+`); leave row #1 byte-identical. Files: docs/DMC_CONSTITUTION.md
- [ ] DMC-T020.5: (verify lane — critic-A7: an INDEPENDENT fresh-context non-authoring verifier,
  never the plan author or executor) Author `.harness/verification/dmc-constitution-amend2.md` —
  full AC battery result. Files: .harness/verification/dmc-constitution-amend2.md
- [ ] DMC-T020.6: (verify lane, VII.4 — the VERIFIER, not the author, captures this evidence) Run
  the honesty-lexeme grep over the amended doc and paste its output as a fenced block inside the
  verification report; confirm EMPTY. Files: .harness/verification/dmc-constitution-amend2.md

## Verification Commands

| Command | Expect | Blocking |
|---|---|---|
| `grep -cE '^## Article ' docs/DMC_CONSTITUTION.md` | `8` | yes |
| `grep -nE '^\| 2 \|' docs/DMC_CONSTITUTION.md` | Log row #2 (2026-07-08 / this commit) | yes |
| `grep -niE 'codex' docs/DMC_CONSTITUTION.md` + whole-word lexeme check (`dmc-doctor.py:86-88`) on matched lines | no forbidden lexeme (VII.4; output → report) | yes |
| `grep -rl 'DMC_CONSTITUTION' DMC.md CLAUDE.md adapters .agents/skills .claude/skills .claude/agents` | empty (exit 1) | yes |
| `bin/dmc agents-md --validate AGENTS.md` | VALID | yes |
| `bash bin/lib/dmc-v0.4.7-context-audit.sh --self-test` | 7 / 0 | yes |
| `bin/dmc selftest m8-suite` | green; dangling-ref clean | yes |
| `bin/dmc selftest` / `bin/dmc mirror-check` / `bin/dmc linkcheck` | green / 55·55 / clean | yes |
| `bin/dmc selftest --all` | SKIPPED — docs-only, no frozen surface touched | rationale |
| `git status --porcelain` + `git diff --numstat` | diff ⊆ 2-grant scope; only the constitution file (+ verifier create) | yes |

## Approval Status

Status: APPROVED (Rev 2)
Approver: wjlee (woojin20020@gmail.com) — human plan gate via AskUserQuestion, 2026-07-08
Approved At: 2026-07-08

Gate record (all three questions answered — this IS the VII.1 human ratification for the
amendment's plan stage; final ratification of the amended text occurs at the commit gate):
1. Plan approved, amendment start authorized (Art. VII procedure in force).
2. **VIII.4 → AUTONOMY.md stop-conditions named BINDING** (schema-backed via
   `.harness/schemas/autonomy.schema.md`; BIND, never restate).
3. **VI.1 touch → INCLUDED** (Art. VIII named in the governance-supremacy enumeration).

Critic chain: r1 NEEDS_CLARIFICATION (B1 critic-less loop entrenchment, B2 Art. V collision;
`.harness/evidence/dmc-constitution-amend2-critic-r1.json`, Rev 1 hash `74f0f914…`) → Rev 2 fold →
r2 APPROVE, 0 blockers (`.harness/evidence/dmc-constitution-amend2-critic-r2.json`, Rev 2 hash
`fd286f0f…`). Build directives: r2-A8 (the fresh-context verifier explicitly records the
cite-density/BIND-not-restate manual judgment), r2-A9 (verifier sanity-reads the final VIII.3(a)
prose — it must not soften into a general masking license).
