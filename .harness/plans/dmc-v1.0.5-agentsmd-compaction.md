# Plan — v1.0.5 AGENTS.md generator compaction (dedup §5 re-inline + rules-first reorder + subset-parity selftest)

Work ID: dmc-v1.0.5-agentsmd-compaction

## Goal

Reduce the generated `AGENTS.md`'s Codex host-truncation risk at its root, as a DETERMINISTIC
artifact-compaction change with an objective machine-checkable success metric (no behavioral/
enforcement change, so no measurement pilot needed). Two edits IN THE GENERATOR
(`bin/lib/dmc-agents-md.py`) so the fix reaches host repos, not just this repo's own file:

- **A1 — dedup §5**: the §5 "Protected surfaces" render re-inlines the full protected-class
  landmark path list a SECOND time (already tagged "(see section 4)") as an ~8.5 KB comma-joined
  blob. Replace that enumeration with a compact cross-reference (keep the "(see section 4)" pointer
  and a class-count), keeping §5's secret-pattern bullets + bindings line so §5 stays non-empty and
  VALID. Reclaims ~8.5 KB — takes the current fragile 278 B under-cap margin to multiple KB.
- **A2 — inventory-last reorder**: relocate §4 (landmark inventory) and §5 (protected surfaces) to
  the END of the emitted document (after §10), keeping ALL sections' numeric labels and keeping
  every OTHER section in numeric order → final emitted order **[1,2,3,6,7,8,9,10,4,5]**. This puts
  the behavioral rules (§7 operating rules, §9 stop conditions) and all operational sections
  physically BEFORE the big inventory, so a host-side truncation past the byte cap drops the
  inventory tail, not the rules. Chosen over "move §7/§9 up" because it (a) keeps §6→§7 adjacency,
  (b) leaves 1,2,3,6,7,8,9,10 contiguous & in-order (no jumble; resolves the §8-orphan advisory),
  and (c) still satisfies §7<§4 and §9<§4. The validator is order-independent (`split_sections`
  keys by number), so this is VALID. (Defense-in-depth: measured, the rules are not truncated today
  — this hardens the fragile margin for larger host repos.)
- **A2-guard (BLOCKING, critic r1 B1)**: the reorder breaks negative-control TEST FIXTURES that
  hardcode physical section order — V1 (`dmc-agents-md.py:683`, deletes §6 via `(?=## 7\.)`), V4
  (`:697-698`), and `tests/fixtures/m6.5/test-agents-md.sh:182` (awk). These MUST be rewritten to be
  physical-order-INDEPENDENT (locate a section by its own heading + the immediately-following
  emitted heading via `split_sections`/`HEADING_RE` offsets, never a hardcoded `## N.` successor).
  In scope: `bin/lib/dmc-agents-md.py` + `tests/fixtures/m6.5/test-agents-md.sh`.
- **Guard**: add a COUNT-parity selftest — the rendered §5 per-class counts (enforcement / contract
  / release) equal the derived §4 per-class counts — so the compacted §5 can never carry a wrong or
  off-by-one count. (NOT subset-parity: §5 ⊆ §4 is true by construction — a tautology — per critic
  r1 advisory.)

Regenerate the committed `AGENTS.md` so artifact == generator output. Label v1.0.5; identity stays
"Do-Me-Coding v1.0".

## User Intent

feature (generator hardening / artifact compaction)

Authorized THIS session by wjlee via AskUserQuestion (2026-07-09): from the lightweighting-strategy
synthesis the user chose "A1 + A2 함께" (dedup §5 + rules-first reorder) to run as a formal DMC
cycle. This is NOT under the overnight envelope (that closed at v1.0.4); it is a fresh, separately
authorized increment. Autonomy for this cycle mirrors the ratified pattern: autonomous through the
LOCAL commit gate on this dedicated branch; push / CI / main-FF remain a human gate. Critic APPROVE
is mandatory before any build; independent verifier + committed-replica/live 802/3/3 mandatory.

## Current Repo Findings

(grounded by the lightweighting-strategy workflow, 2026-07-09; all quotes machine-verified against
the tree — re-verify at build time)

- Finding: the generator NEVER truncates — `oversize_warning()` (`bin/lib/dmc-agents-md.py:384-394`)
  only prints a stderr suggestion when the doc exceeds `DOC_MAX_BYTES=32768` (:57); exit stays 0.
  The ACTUAL truncator is the Codex host (`project_doc_max_bytes` default 32768). Committed
  `AGENTS.md` = 32,490 B / ~287 lines — 278 B under the cap.
- Finding: the §5 duplication is a SINGLE append at `dmc-agents-md.py:303-306`
  (`"- Repository enforcement / contract / release landmarks (see section 4): %s" % ", ".join(...)`)
  over `protected_landmarks` derived at `:215-218` (sorted set of §4 paths whose class ∈
  {enforcement, contract, release}). In the committed file this is `AGENTS.md:226`, one line of
  8,489 B (~26% of the whole doc). §5 also renders secret-pattern bullets (`:294-298`) + a bindings
  line (`:300-302`) that keep it non-empty regardless.
- Finding: behavioral rules §7 (`AGENTS.md:235`) and §9 (`:261`) sit AFTER the §4 inventory
  (`:23-213`) and §5 (`:226`). Measured rule-anchor byte offsets 30,473 / 31,385 — under the 32,768
  cap today (rules not truncated NOW), but any host that grows §4 breaches the cap and eats rules
  first.
- Finding: the validator is ORDER-INDEPENDENT — `split_sections` (`:399-426`) builds a dict keyed by
  section number; `validate_doc` (`:444-469`) checks only membership + the pinned title per number +
  non-empty + no filler. Physical reorder keeping numeric labels PASSES. RENUMBERING (making §7
  become §4) is REJECTED by the title-to-number pin (`SECTIONS`, `:60-71`) — so reorder must move
  physical position only, never the numbers.
- Finding: NO consumer reads the committed `AGENTS.md` §4/§5 CONTENT. No gate runs
  `agents-md --validate` on the committed file (the full/release gate runs `agents-md --self-test`
  on FIXTURES, `bin/dmc:501`); byte-identity of committed==regenerated was a one-time manual critic
  proof, never an automated gate. `bin/lib/dmc-repo-intel.py:213` and the context-budgeter read
  `AGENTS.md` by filename/`wc -l` only, never parse §4/§5.
- Finding: the frozen AC6 audit `bin/lib/dmc-v0.4.7-context-audit.sh:52-53` (LIVE gate) greps
  `AGENTS.md` for `AUTONOMY.md` and `CONTEXT_MAP.md` — those strings live in §7
  (`AGENTS.md:239-242`), NOT §4/§5. Reorder/dedup MUST keep the §7 companion-docs pointer intact
  (this pointer has been lost in past regenerations — standing risk).
- Finding (CORRECTED by critic r1 B1 — the load-bearing catch): the module selftest's
  NEGATIVE-CONTROL fixtures HARDCODE physical section order. V1 (`bin/lib/dmc-agents-md.py:683`)
  deletes §6 with `re.sub(r"## 6\. Migration.*?(?=## 7\.)", ...)` — it assumes §7 physically follows
  §6; V4 (`:697-698`) deletes §4/§5/§6/§8; `tests/fixtures/m6.5/test-agents-md.sh:182` uses an awk
  over section order. Any reorder that changes an assumed adjacency flips these negative controls
  (critic reproduced: V1 "removed §6" = False under a reordered doc). The inventory-last order
  [1,2,3,6,7,8,9,10,4,5] PRESERVES §6→§7 but changes §3→§6 (was §3→§4) and §10→§4 (was §10-last) — so
  the fixtures MUST be made order-independent regardless. The POSITIVE assertions
  (`test-agents-md.sh:173` grep -c §4 rows == 700; heading-membership Z2/Z3/N1/P1/E1/E3) are
  order-independent and §4-content-scoped → unaffected by the §5-only dedup or the relocation.
- Finding: the §5 count-parity guard is the RIGHT guard (not subset): `protected_landmarks` is a
  filtered subset of §4 BY CONSTRUCTION (`:215-218`), so "§5 ⊆ §4" is a tautology; a per-class COUNT
  equality (rendered §5 counts == derived §4 counts) is what actually catches a wrong/off-by-one
  compacted count.
- Finding (critic r1): `bin/lib/dmc-agents-md.py` is NOT in the release-gate DEFAULT_PROTECTED set
  (`bin/lib/dmc-v0.2.6-gate-check-runner.sh:22-31`) — so NO `DMC_GATE_PROTECTED` override is needed;
  the earlier plan over-claimed that risk. The gate still raises the non-degrading landmark FLAG on
  the enforcement-class generator path.

## Relevant Files

| Path | Reason | Allowed to Edit |
|---|---|---|
| `bin/lib/dmc-agents-md.py` | generator — A1 dedup §5 render (`:303-306`), A2 reorder emission (keep numeric labels), + new subset-parity selftest | yes (enforcement-class Ring-0 landmark → landmark_authorized) |
| `AGENTS.md` | regenerated artifact so committed == generator output | yes |
| `tests/fixtures/m6.5/test-agents-md.sh` | update ONLY a §5 assertion that legitimately changes under dedup; add parity coverage if that is where it belongs | yes (conditional) |
| `docs/MILESTONES.md` | ONE v1.0.5 closure entry (append-only) | yes (append) |
| enforcement floor, shims, installer, other Ring-0 tools, `.harness/schemas/*` | NO behavioral/gate/floor/schema change | no |

## Out of Scope

- Any enforcement-boundary, gate, floor, or `when-gates-fire` change — this is artifact compaction
  only (bucket A; the behavioral lightweightings are pilot-gated bucket B).
- §4 externalization (A3), the generator landmark-budget/top-N policy, and repo-intel scan-bounding
  (A4) — deferred: A3 is higher-cost (touches generator fixture selftests) and A4 was found
  MIS-bucketed by the strategy workflow (it changes what the scan walks → could change the derived
  landmark set; needs its own verified cycle).
- RENUMBERING any section (validator forbids).
- Any change to §7's companion-docs pointer content (AC6 must survive verbatim).
- The strategic memo (`.harness/plans/dmc-refinement-diagnosis-20260709.md`) — stays untracked;
  its pilot decisions are separate.
- Push / CI / main-FF (human gate).

## Proposed Changes

- Change: `bin/lib/dmc-agents-md.py` §5 render (`:303-306`) — replace the full
  `", ".join(protected_landmarks)` enumeration with a compact form: the "(see section 4)"
  cross-reference plus a class count (e.g. "N enforcement / M contract / K release landmarks — see
  section 4"). Keep the secret-pattern bullets and bindings line untouched so §5 stays non-empty and
  VALID.
  Files: `bin/lib/dmc-agents-md.py`.
- Change: `bin/lib/dmc-agents-md.py` emit order — relocate the §4 and §5 section emission to AFTER
  §10 (final emitted order [1,2,3,6,7,8,9,10,4,5]), keeping every section's numeric label and pinned
  title/body. Only §4/§5 move; 1,2,3,6,7,8,9,10 stay contiguous & in numeric order.
  Files: `bin/lib/dmc-agents-md.py`.
- Change (BLOCKING fix, critic r1 B1): rewrite the physical-order-dependent NEGATIVE-CONTROL fixtures
  so each locates its target section by that section's own heading and the immediately-following
  EMITTED heading (via `split_sections`/`HEADING_RE` offsets), never a hardcoded `## N.` successor —
  V1 (`dmc-agents-md.py:683`), V4 (`:697-698`), and `tests/fixtures/m6.5/test-agents-md.sh:182`. No
  assertion is weakened; only the fixture CONSTRUCTION becomes order-independent.
  Files: `bin/lib/dmc-agents-md.py`, `tests/fixtures/m6.5/test-agents-md.sh`.
- Change: `bin/lib/dmc-agents-md.py` module selftest — add a COUNT-parity assertion: rendered §5
  per-class counts (enforcement / contract / release) == derived §4 per-class counts. Bump the
  module selftest count.
  Files: `bin/lib/dmc-agents-md.py`.
- Change: regenerate `AGENTS.md` via `bin/dmc agents-md --stdout` compared to / written to the
  committed file, confirming byte-identity of committed == regenerated.
  Files: `AGENTS.md`.
- Change: append ONE `docs/MILESTONES.md` entry `## v1.0.5 — AGENTS.md generator compaction —
  CLOSED (2026-07-09)` (what/where, the bucket-A rationale, the chain, push-gate pending line).
  Files: `docs/MILESTONES.md`.

## Acceptance Criteria

- Criterion: byte margin restored.
  Verification Method: regenerated `AGENTS.md` `wc -c` < 28672 (≥ 4 KB margin under 32768; expect
  ~24 KB after the 8,489 B §5 blob is removed).
- Criterion: rules physically precede the inventory.
  Verification Method: `grep -b '^## 7\.' AGENTS.md` byte offset < `grep -b '^## 4\.' AGENTS.md`
  byte offset; likewise `## 9.` before `## 4.`.
- Criterion: document stays VALID.
  Verification Method: `bin/dmc agents-md --validate AGENTS.md` → VALID (all 10 sections present,
  pinned titles, non-empty, no filler tokens).
- Criterion: AC6 companion-docs pointer survives.
  Verification Method: `grep -c 'AUTONOMY.md' AGENTS.md` ≥ 1 AND `grep -c 'CONTEXT_MAP.md' AGENTS.md`
  ≥ 1 (both in §7); `bash bin/lib/dmc-v0.4.7-context-audit.sh` → 0 FAIL.
- Criterion: dedup is guarded by count-parity; negative controls survive the reorder.
  Verification Method: the new COUNT-parity assertion (§5 per-class counts == §4 per-class counts) is
  present and passes; the rewritten order-independent V1/V4/awk negative controls still FAIL on their
  intended defect; module selftest (`python3 bin/lib/dmc-agents-md.py --self-test` or the wired verb)
  0 FAIL under the [1,2,3,6,7,8,9,10,4,5] emission.
- Criterion: artifact == generator output.
  Verification Method: `bin/dmc agents-md --stdout` is byte-identical to committed `AGENTS.md`.
- Criterion: no suite regression.
  Verification Method: `bin/dmc selftest` 0 FAIL; the m6.5 agents-md suite +
  `tests/fixtures/m6.5/test-agents-md.sh` green; `bin/dmc selftest m65-suite` green;
  `bin/dmc mirror-check` PASS; `bin/dmc linkcheck` clean.
- Criterion: full gate PASS; frozen baseline intact; LOCAL commit only.
  Verification Method: green set + `dmc gate release --full --run-id <run>` → PASS (non-degrading
  landmark FLAG expected on `bin/lib/dmc-agents-md.py`; NO `DMC_GATE_PROTECTED` override — the
  generator is NOT in DEFAULT_PROTECTED, critic r1 confirmed); committed-replica AND live
  `bin/dmc selftest --all` → legacy **802/3/3 EXACT** (the generator is not among the 49 legacy
  tools, so the count is unaffected); one LOCAL commit; push/CI/FF a human gate.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Reorder flips physical-order-dependent negative-control fixtures (critic r1 B1, PROVEN) | high | in-scope rewrite of V1/V4/`test-agents-md.sh:182` to locate sections by emitted-order offsets; AC requires the rewritten controls still FAIL on their intended defect AND module selftest 0 FAIL under the reordered emission |
| Dedup carries a wrong/off-by-one compacted count | medium | new COUNT-parity selftest (§5 per-class counts == §4 per-class counts); a silent DROP is impossible anyway — every §5 path stays in §4 with its class |
| AC6 §7 companion-docs pointer lost on regeneration (recurred at M10, hygiene) | medium | AC criterion + `dmc-v0.4.7-context-audit.sh` 0 FAIL; executor re-adds if the regen drops it |
| Reordered artifact reads out of numeric sequence (jumble) | low | inventory-last [1,2,3,6,7,8,9,10,4,5] keeps 1,2,3,6,7,8,9,10 contiguous & in order — only §4/§5 relocate; documented as the intended order |

## Assumptions

| Assumption | Confidence | How to Verify |
|---|---|---|
| Physical reorder keeping numeric labels passes validate + selftest | high | `agents-md --validate` + module selftest at build time |
| No consumer parses committed §4/§5 content | high | workflow grounding; re-grep for readers of AGENTS.md §4/§5 at build |
| The user's AskUserQuestion choice authorizes this cycle's scope | high | recorded this session; SKIP on critic REJECT |

## Execution Tasks

- [ ] DMC-T001: `bin/lib/dmc-agents-md.py` — A1 dedup §5 render (`:303-306`) + A2 inventory-last
  emit order [1,2,3,6,7,8,9,10,4,5] (keep numeric labels) + COUNT-parity selftest assertion +
  rewrite the physical-order-dependent negative controls (V1 `:683`, V4 `:697-698`, and
  `tests/fixtures/m6.5/test-agents-md.sh:182`) to be emitted-order-independent. Run
  `python3 bin/lib/dmc-agents-md.py --self-test` + `bin/dmc selftest m65-suite` → 0 FAIL under the
  reordered emission.
  Files: `bin/lib/dmc-agents-md.py`, `tests/fixtures/m6.5/test-agents-md.sh`.
  Notes: Route: Opus 4.8, synchronous (generator logic + fixtures + selftest; correctness-critical).
- [ ] DMC-T002: regenerate `AGENTS.md`; confirm artifact==generator byte-identity, `wc -c` < 28672,
  §7/§9 byte offsets < §4 offset, and AC6 companion-docs pointer survives (`dmc-v0.4.7-context-audit`
  0 FAIL).
  Files: `AGENTS.md`.
  Notes: Route: Opus 4.8, synchronous; depends on T001.
- [ ] DMC-T003: MILESTONES v1.0.5 entry + suite runs.
  Files: `docs/MILESTONES.md`.
  Notes: Route: Sonnet 5, synchronous; depends on T001+T002.

## Verification Commands

| Command | Reason | Required |
|---|---|---|
| `wc -c AGENTS.md` | byte margin < 28672 restored | yes |
| `grep -b '^## 7\.' AGENTS.md` vs `grep -b '^## 4\.' AGENTS.md` | rules physically precede inventory | yes |
| `bin/dmc agents-md --validate AGENTS.md` | doc VALID | yes |
| `bash bin/lib/dmc-v0.4.7-context-audit.sh` | AC6 companion-docs pointer survives (0 FAIL) | yes |
| `bin/dmc agents-md --stdout` == `AGENTS.md` | artifact == generator output | yes |
| module selftest incl. subset-parity assertion | dedup guarded, 0 FAIL | yes |
| `bin/dmc selftest` + m65-suite + agents-md fixture + `mirror-check` + `linkcheck` | regression floor | yes |
| `dmc gate release --full --run-id <run>` | PASS; FLAG on the generator; minimal override only if DEFAULT_PROTECTED | yes |
| committed-replica + live `bin/dmc selftest --all` | legacy **802/3/3 EXACT** | yes |
| LOCAL commit; no push | autonomy compliance; push is a human gate | yes |

## Approval Status

Status: APPROVED
Approver: wjlee (woojin20020@gmail.com)
Approved At: 2026-07-09 (this-session AskUserQuestion — lightweighting synthesis; user chose
"A1 + A2 함께" to run as a formal DMC cycle; autonomous through the LOCAL commit gate on
`claude/dmc-v105-agentsmd-compaction`; push/CI/main-FF reserved to a human gate). Critic APPROVE is
the mandatory pre-build gate (verdict recorded under `.harness/evidence/dmc-v1.0.5-critic-r*.json`).

Revisions: Rev 1 → critic r1 REJECT (1 blocking, `dmc-v1.0.5-critic-r1.json`): B1 = A2's reorder
breaks physical-order-dependent negative-control fixtures (V1/V4/awk) that the plan never scoped.
Rev 2 folds the fix: A2 reframed as inventory-last [1,2,3,6,7,8,9,10,4,5]; the fixture rewrite is now
in-scope work (T001); subset-parity → COUNT-parity; DEFAULT_PROTECTED override dropped (confirmed not
protected). Re-submitted for a fresh critic pass (r2).
