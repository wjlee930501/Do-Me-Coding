# Plan: DMC v1.1 — Natural-Activation Tuning (case-insensitive trigger + signature + DMC-priority)

Plan ID: dmc-v1.1-activation-tuning · Date: 2026-07-08 · Format: dmc.plan-instance.v1
First post-v1.0 feature milestone (HEAD `186ed8c` == main, v1.0 complete). Task namespace `DMC-T018.*`
grep-verified collision-free (T016=M10, T017=`dmc-v1-audit-remediation.md`; re-derive the count at
execution rather than trusting a pinned number). Risk: **low** — small diff (2 enforcement hooks +
1 CI-wired test + 5 doc/skill files), additive; the frozen 802/3/3 surface does not exercise the router.

**Rev 2** — critic r1 REJECT (`.harness/evidence/dmc-v1.1-critic-r1.json`, Rev 1 hash `1f5ec5a3…`)
folded: **B1** — the v011-verify gate was UNSATISFIABLE (the manual harness already fails 2
pre-existing non-router rows on untouched HEAD: `v011:31` stale active-stop-block vs the evolved
stop-verify-gate, `v011:77` hardcoded 6-skills count vs 15 skill dirs) → the gate now asserts ONLY
the five router-invariant rows, with the 2 pre-existing failures recorded as a documented
known-baseline delta (mirroring the test-rollback treatment); **B2** — case-insensitivity extended
to the TASK-EXTRACTION strips (router sed `:77/:86`, shim re.sub `:69/:76` — previously
matcher-only, leaking the trigger token into the routed task for mixed-case prompts) via PORTABLE
character-class patterns (BSD sed has no `s///I`): `[Dd][Mm][Cc]` / `[Dd][Mm][Cc]-[Pp][Ll][Aa][Nn]`
on the bash side, `flags=re.IGNORECASE` on both `re.sub` calls on the shim side, plus NEW
clean-extraction probes (LP1 + m65 rows). Advisories folded: A1 (SKILL.md signature line is
UNCONDITIONAL — covers direct `/dmc-ultrawork` invocations too), A2 (m65 parity rows use FRESH
per-prompt sandbox dirs — no mode-file bleed into the CI-blocking suite), A3 (HONEST_SCOPE caveat
anchored in the disclosed-residual-register section), A4 (adapters/{codex,claude-code}/README.md
listed verified-no-edit).

## Goal

Land three ratified activation-tuning behaviors in strict Claude/Codex lockstep: (1) make the
natural-activation suffix triggers **case-insensitive** so a prompt ending "…해줘. DMC" fires, while
suffix-only + mid-sentence-never-fires stays true; (2) on the `dmc`/ultrawork route, prepend the
exact signature instruction so the reply opens with `Okay, Let me do you Coding!`; (3) assert
instruction-level **DMC PRIORITY** in the dmc-route emit so DMC's routing is authoritative for that
turn over any other orchestration layer (OMC/OMO/LazyCodex) whose hooks fired the same turn — framed
honestly as instruction-level, since Claude Code merges hook arrays and no structural suppression
lever exists (scout lane 3). Ship the matching doc/skill wording, close the zero-tripwire UPS parity
gap with new CI-blocking coverage, and keep the frozen composer, the 802/3/3 legacy baseline, and
every existing self-test section byte/count-unchanged.

## User Intent

feature (activation tuning; first post-v1.0 milestone). User directives ratified by wjlee
(2026-07-08): case-insensitive suffix trigger, the exact `Okay, Let me do you Coding!` signature on
`dmc` activation (deliberate Do-Me-Coding wordplay — never "corrected"), and DMC-priority-on-fire.
The user gates plan approval, scope, commit, and push; a non-authoring critic reviews this plan
before any edit; Opus/Sonnet executors implement synchronously; an independent verifier validates
before closure. No edit occurs before critic + human gate.

## Current Repo Findings

All findings re-verified live this session (HEAD `186ed8c`); scout lanes 1–3 treated as verified
ground truth.

- The router matcher block is lowercase-only: `grep -Eq '(^|[[:space:]])dmc-off[[:space:]]*$'` at
  `.claude/hooks/dmc-router.sh:68`, `dmc-plan` at `:76`, `dmc` at `:83`. `emit()` is `:54-57`; the
  dmc-branch emit at `:87` carries the substring `dmc-ultrawork`, the dmc-plan emit at `:78` carries
  `dmc-plan-hard`. Header prose `:5-6`; JSON-parser line `:14` = `DMC_HOOK_INPUT="$INPUT" python3`.
- The Codex shim is an **independent** Python reimplementation (not a shared Ring-0 call):
  `re.search(r"(^|\s)dmc-off\s*$", trimmed)` at `adapters/codex/dmc-codex-userpromptsubmit.py:62`,
  dmc-plan `:68`, dmc `:74` — **no** `re.IGNORECASE`; docstring `:4-6` claims parity; emits via
  `dc.ups_context()` at `:64-65` (off), `:70-71` (plan), `:77-78` (dmc).
- Four surfaces assert Claude/Codex parity for natural-activation and become FALSE if only one side
  is patched: `docs/CODEX_ADAPTER.md:47-48,57,101`, `docs/DMC_V1_ENFORCEMENT_MATRIX.md:63-66`, and
  `orchestration/harness-matrix.json` natural-activation.codex ("no material residual gap",
  matrix line 55). No existing test enforces cross-file parity (scout lane 3).
- Landmark classes (live `bin/dmc landmarks`): `.claude/hooks/dmc-router.sh` = **enforcement**,
  `adapters/codex/dmc-codex-userpromptsubmit.py` = **enforcement** (both need `landmark_authorized`);
  `docs/MILESTONES.md` = **release**; DMC.md, CLAUDE.md, OMC_COEXISTENCE.md, DMC_V1_HONEST_SCOPE.md,
  the SKILL.md files, and `tests/fixtures/m6.5/test-codex-shims.sh` = **ordinary**.
- No frozen/CI test executes or byte-pins the **live** router: the 55-file 802/3/3 mirror is
  `dmc-v0.*` under `bin/lib`↔`.harness/evidence` only (`bin/lib/dmc-legacy-selftest.py:9,112,180`);
  the router is not a member. CI blocking steps check router **presence/registration** only, never
  bytes/behavior (`dmc doctor`, `dmc-ci.yml:113-114`). `tests/fixtures/m6/test-restore.sh:59,71`
  overlays the **frozen fixture** router — unaffected iff that fixture stays byte-frozen.
- `dmc selftest m65-suite` **is CI-BLOCKING** (`.github/workflows/dmc-ci.yml:172-173`) and runs
  `test-codex-shims.sh` (`bin/dmc:239`). Today its UPS section A13–A15 (`test-codex-shims.sh:67-75`)
  drives ONLY the Codex shim in isolation and asserts mode value + `has_context_of()` — a bare
  `additionalContext`-key grep (`_m65common.sh:103`), **zero** emit-content and **zero** cross-adapter
  parity. Helpers `codex_run` (`_m65common.sh:78`) and `claude_run` (`:89`) both exist.
- The only router **behavioral** harness is `.harness/evidence/v011-verify.sh` (`router()` `:13`;
  rows `:59,60,62,63,67-71`) — manual, **unwired** to CI/mirror, lowercase-only. It pins the
  invariants: emit substrings `dmc-ultrawork`/`dmc-plan-hard` (`:59-60`), mid-sentence negative
  (`:62`), parser line 14 (`:63`), mode-file writes (`:67-71`).
- `tests/fixtures/m6/test-rollback.sh` byte-pins the live router to pre-M6 commit `299987` (`:57,64,
  75-78`) but is **not wired** to any suite/CI (`bin/dmc:224` omits it); already 7/9-broken on main.
  Editing the router flips its router row red **by design** (drift-detector), zero gate consequence.
- The frozen fixture `tests/fixtures/hooks-v0.6.5/hooks/dmc-router.sh` MUST stay at pre-M6 bytes —
  updating it breaks the BLOCKING m6-suite via `test-restore.sh` (scout lane 1 must-do).
- Doc wording: `DMC.md:85`, `CLAUDE.md:31`, `docs/OMC_COEXISTENCE.md:24` all say "suffix-only and
  exact" (reads case-sensitive). `CLAUDE.md:33-35` ships verbatim into host CLAUDE.md
  (`INSTALL_MANIFEST.md:221,231`). `OMC_COEXISTENCE.md:61-64` holds the "> Observed:" OMC-re-arm
  callout — the natural home for a precedence section. Folding the DMC-PRIORITY detail into the
  already-bundled OMC_COEXISTENCE.md keeps CLAUDE.md/DMC.md refs (`:37`/`:87`) inside the
  dangling-reference rule (`INSTALL_MANIFEST.md:295-301`) with **no** manifest edit.
- `.claude/settings.json` UserPromptSubmit has a single DMC hook; no OMC hook is registered in-repo;
  Claude Code merges hook arrays from plugins → no suppression/ordering lever → DMC-PRIORITY is
  necessarily instruction-level best-effort (scout lane 3).
- OPERATIONAL (this repo's armed-run guards, empirically established): LP1 live probes use `mktemp`
  out-of-repo writes and stdout discards — they MUST run in the DISARMED verify phase (run
  suspended + pointer cleared), and cleanup uses `python3 shutil.rmtree`, never `rm -rf` (L0 floor).
- (critic-r1 B2) The TASK-EXTRACTION strips are case-sensitive today and MUST change with the
  matchers: router `sed -E 's/[[:space:]]*dmc-plan$//'` at `:77` and `s/[[:space:]]*dmc$//` at
  `:86`; shim `re.sub(r"\s*dmc-plan$", …)` at `:69` and `re.sub(r"\s*dmc$", …)` at `:76`. A
  matcher-only change would fire on "…해줘. DMC" but leak " DMC" into the routed task string —
  symmetric across adapters, so parity-equality checks alone cannot catch it. PORTABILITY: BSD/macOS
  sed has no `s///I` flag → use character-class patterns (`[Dd][Mm][Cc]`,
  `[Dd][Mm][Cc]-[Pp][Ll][Aa][Nn]`); python adds `flags=re.IGNORECASE`.
- (critic-r1 B1) `.harness/evidence/v011-verify.sh` on untouched HEAD `186ed8c` already reports
  `PASS=39 FAIL=2` — the 2 failures are PRE-EXISTING and non-router (`v011:31` "active stop block"
  stale vs the evolved stop-verify-gate; `v011:77` hardcoded "6 existing skills" vs 15 skill dirs
  today). The no-regression gate therefore asserts the FIVE router-invariant rows only
  (`:59/:60/:62/:63/:67-71`); the 2 pre-existing failures are recorded as a known-baseline delta
  in the verification report — never "fixed" here (v011 is a no-edit manual record).
- (critic-r1 A4) `adapters/codex/README.md` + `adapters/claude-code/README.md` verified NO-EDIT:
  their "router"/"case-insensitive" mentions are generic or unrelated to trigger case-sensitivity.

## Relevant Files

| Path | Reason | Allowed to Edit |
|---|---|---|
| .claude/hooks/dmc-router.sh | T018.1 — case-insensitive matcher `:68/:76/:83`; dmc-branch emit `:87` gains signature + DMC-PRIORITY; header `:5-6`; keep `dmc-ultrawork`/`dmc-plan-hard` substrings + parser line `:14` byte-untouched. **enforcement → landmark_authorized** | yes |
| adapters/codex/dmc-codex-userpromptsubmit.py | T018.1 — mirror EVERYTHING: `re.IGNORECASE` at `:62/:68/:74`, same emit additions on dmc branch, docstring `:4-6`. **enforcement → landmark_authorized** | yes |
| tests/fixtures/m6.5/test-codex-shims.sh | T018.2 — NEW CI-blocking UPS parity section (drives both hosts, asserts emit content, closes the zero-tripwire gap). ordinary | yes |
| DMC.md | T018.3 — `:77-85` mixed-case example + "suffix-only, exact-token, case-insensitive". ordinary | yes |
| CLAUDE.md | T018.3 — `:31-35` same rewording + DMC-PRIORITY rule; ships verbatim to hosts (`INSTALL_MANIFEST.md:221,231`). ordinary | yes |
| docs/OMC_COEXISTENCE.md | T018.3 — `:24` wording + NEW `## Precedence when both fire` anchored at `:61-64`. ordinary | yes |
| .claude/skills/dmc-ultrawork/SKILL.md | T018.3 — short post-frontmatter line: natural-trigger invocations open with the exact signature. ordinary | yes |
| docs/DMC_V1_HONEST_SCOPE.md | T018.3 — ONE caveat line: DMC-priority is instruction-level best-effort, not a runtime boundary. ordinary | yes |
| docs/MILESTONES.md | T018.4 — append-only v1.0.1 closure entry (label per the gate; content human-gated). **release → landmark_authorized** | yes |
| .harness/verification/dmc-v1.0.1-activation.md (NEW) | T018.5 — verification report (create grant; NEVER an `.harness/evidence/` grant — M10 G2/G3 catch-22 lesson; v1.0.1 label per the gate) | yes |
| .harness/plans/dmc-v1.1-activation-tuning.md (this file) | revisions + approval/closure records only (orchestrator lane, gate-driven) | yes |
| tests/fixtures/hooks-v0.6.5/hooks/dmc-router.sh | frozen pre-M6 fixture — editing it breaks BLOCKING m6-suite | no |
| tests/fixtures/m6/test-rollback.sh | unwired manual proof; router row flips red by design — DOCUMENT | no |
| .harness/evidence/v011-verify.sh | manual regression harness — RUN as no-regression proof, do NOT edit | no |
| orchestration/harness-matrix.json, docs/CODEX_ADAPTER.md, docs/DMC_V1_ENFORCEMENT_MATRIX.md | parity claims stay TRUE **because** T018.1 is lockstep — VERIFY, do not edit | no |
| bin/lib/dmc-v0.*.{sh,py} + .harness/evidence/dmc-v0.*.{sh,py}, bin/lib/dmc-release-gate.py | mirror-pinned/frozen — untouched | no |
| AGENTS.md, docs/CONTEXT_MAP.md, dmc-on/off/status + dmc-plan-hard SKILL.md, INSTALL_MANIFEST.md, RELEASE_CHECKLIST | no trigger-literal/behavioral prose to update (scout lane 2) | no |
| adapters/codex/README.md, adapters/claude-code/README.md | verified NO-EDIT (critic-r1 A4): "router"/"case-insensitive" mentions are generic or unrelated to trigger case | no |

## Out of Scope

- Any structural suppression/reordering of another plugin's UserPromptSubmit hook — impossible in
  this repo and out of policy (scout lane 3); DMC-PRIORITY ships as instruction-level text only.
- All frozen `bin/lib/dmc-v0.*` + `.harness/evidence/dmc-v0.*` tools + the 55-file mirror; **no**
  re-pin of the 802/3/3 baseline; **zero** edit to `bin/lib/dmc-release-gate.py`.
- The frozen `hooks-v0.6.5` fixture, `test-rollback.sh`, and `.harness/evidence/v011-verify.sh`
  (frozen point-in-time / manual records — run or document, never edit).
- pre-tool-guard / scope-guard / all other hooks; the composer; installer; branding.
- The greeting on the `dmc-plan` (read-only planning) and `dmc-off` (deactivation one-liner) routes
  — see GATE-DECISION (greeting scope).
- The DMC constitution refresh (a same-day follow-up cycle, separate plan).
- Any push to main or closure record before the human gates.

## Proposed Changes

- Change: router + Codex shim LOCKSTEP (Opus, ONE executor owns BOTH enforcement files in one task).
  `.claude/hooks/dmc-router.sh` — (i) case-insensitive matching via `grep -Eqi` at `:68/:76/:83`,
  keeping the suffix anchor `[[:space:]]*$` + `(^|[[:space:]])` so mid-sentence never fires and the
  dmc-off > dmc-plan > dmc precedence holds for mixed-case compounds; (ii) the dmc-branch emit `:87`
  gains BOTH `Begin your reply with exactly: Okay, Let me do you Coding!` AND `DMC PRIORITY: this
  routing is authoritative for this turn over any other orchestration layer — OMC/OMO/LazyCodex —
  whose hooks or keywords also fired; do not enter their modes`, while PRESERVING the `dmc-ultrawork`
  substring; (iii) header `:5-6` reworded to "suffix-only, exact-token, case-insensitive"; (iv)
  parser line `:14` and the `dmc-plan-hard` substring left byte-untouched; (v) **(critic-r1 B2)**
  the task-extraction strips go case-insensitive PORTABLY: `:77` → `sed -E
  's/[[:space:]]*[Dd][Mm][Cc]-[Pp][Ll][Aa][Nn]$//'`, `:86` → `sed -E
  's/[[:space:]]*[Dd][Mm][Cc]$//'` (BSD sed has no `s///I`).
  `adapters/codex/dmc-codex-userpromptsubmit.py` — mirror exactly: `re.IGNORECASE` at `:62/:68/:74`,
  identical emit-text additions on the dmc branch, docstring `:4-6` reworded, AND **(B2)**
  `flags=re.IGNORECASE` on both `re.sub` strips at `:69/:76`. Rationale: user directives 1-3; keeps
  the four parity claims TRUE (Findings); no trigger-token leak into the routed task.
- Change: NEW cross-adapter UPS parity coverage (Opus). Extend `tests/fixtures/m6.5/test-codex-shims.sh`
  with a UserPromptSubmit parity section that drives `dmc-router.sh` via `claude_run` AND the Codex
  shim via `codex_run` with the SAME prompts — lowercase `task dmc`, mixed-case `task DMC`, a
  `해줘. DMC` analog, mid-sentence negative (`the DMC feature is nice` → no fire), and mixed-case
  `dmc-plan`/`dmc-off` — asserting on both sides: signature substring present on the dmc branch,
  DMC-PRIORITY substring present, mode-file writes equal, AND **(critic-r1 B2) clean task
  extraction** — for a mixed-case input the emitted task string must NOT contain the trigger token
  (e.g. `refactor this. DMC` routes as `refactor this.`). Because `has_context_of()` only greps the
  key name (`_m65common.sh:103`), the new rows grep **actual content substrings**. **(critic-r1 A2)
  every new prompt case uses a FRESH per-prompt sandbox dir (or explicit mode reset)** — A13-A15
  reuse one dir, and a prior dmc/off mode write would bleed into the dmc-plan (mode-unchanged) case,
  making the CI-blocking row flaky. Rationale: closes the zero-tripwire UPS gap (scout lane 3);
  makes the parity CI-blocking.
- Change: docs + skill lockstep (Sonnet). `DMC.md:77-85` (mixed-case example + rewording),
  `CLAUDE.md:31-35` (rewording + the DMC-PRIORITY rule — highest leverage, ships verbatim to hosts),
  `docs/OMC_COEXISTENCE.md:24` wording + NEW `## Precedence when both fire` anchored at `:61-64`
  (name OMC as the observed real contender; OMO/LazyCodex as comparator patterns),
  `.claude/skills/dmc-ultrawork/SKILL.md` (**critic-r1 A1: UNCONDITIONAL** post-frontmatter line —
  "When this skill runs, open the reply with the exact line: Okay, Let me do you Coding!" — so a
  direct `/dmc-ultrawork` slash invocation, which produces no router emit, also carries the
  signature), `docs/DMC_V1_HONEST_SCOPE.md` (ONE caveat: DMC-priority is instruction-level
  best-effort, not a runtime boundary — **critic-r1 A3: anchored in the disclosed-residual-register
  section**). Rationale: keep prose in lockstep with behavior; honesty discipline.
- Change: MILESTONES.md v1.1 append (Sonnet, at closure) — short entry in the established format.
- Change: orchestrator-lane run + verification report (T018.5) — run start → scope.lock compile
  (`landmark_authorized` for the 2 enforcement files + release-class MILESTONES.md; create grant for
  the verification report) → executors → no-regression sweep → `.harness/verification/dmc-v1.1-activation.md`.
- **GATE-DECISION (greeting scope)**: signature line on the `dmc`/ultrawork route ONLY. RECOMMEND
  **YES-only-dmc** — `dmc-plan` is read-only planning and `dmc-off` is a deactivation one-liner; a
  greeting there is noise. (If the human wants it on all three, `dmc-plan-hard/SKILL.md` +
  `dmc-off/SKILL.md` + the two other emit branches must also change.)
- **GATE-DECISION (version label)**: RECOMMEND **v1.1** (feature release; convention max vX.Y.Z) over
  v1.0.1 — new activation behavior, not a patch.
- **GATE-DECISION (release gate)**: whether to also run `dmc gate release --full` for this tuning
  milestone. RECOMMEND **run it** — the diff touches two enforcement-class landmarks, exactly where a
  full gate adds assurance; acceptable to rely on the enumerated selftest + probe + CI bar given the
  small diff. Either way the m65-suite parity rows and live probes are mandatory.

## Acceptance Criteria

- Criterion: Case-insensitive suffix fires on both hosts (`task DMC`, `해줘. DMC` analog, `DMC-OFF`,
  `DMC-PLAN`); mid-sentence still never fires; AND (critic-r1 B2) task extraction is CLEAN — the
  routed task string never contains the trigger token, mixed-case included.
  Verification Method: live router probes (LP1, fenced below) assert mixed-case fires + `the DMC
  feature is nice` yields 0 bytes + the mixed-case emit does NOT contain the trailing ` DMC` token
  in its task segment; the new m65-suite rows assert the same on `dmc-router.sh` (claude_run) AND
  the Codex shim (codex_run); `bin/dmc selftest m65-suite` 0 FAIL.
- Criterion: The `dmc`/ultrawork emit opens the reply with the exact bytes `Okay, Let me do you Coding!`
  on both hosts; `dmc-ultrawork/SKILL.md` carries the reinforcement line.
  Verification Method: `grep -q 'Okay, Let me do you Coding!'` on the router emit + Codex emit (LP1 +
  m65 rows); grep the SKILL.md line.
- Criterion: DMC-PRIORITY clause present in the dmc-route emit on both hosts AND in the host-shipped
  CLAUDE.md block; `## Precedence when both fire` exists in OMC_COEXISTENCE.md.
  Verification Method: `grep -q 'DMC PRIORITY'` on both emits (LP1 + m65 rows); grep CLAUDE.md +
  OMC_COEXISTENCE.md.
- Criterion: Cross-host parity preserved — router and Codex shim are lockstep, so the four parity
  claims (`harness-matrix.json` line 55, `CODEX_ADAPTER.md:47-48,57,101`, `ENFORCEMENT_MATRIX.md:63-66`)
  stay TRUE with no edit to those files.
  Verification Method: new m65-suite parity rows assert mode-file equality + emit-content substrings
  equal across both adapters (0 FAIL); `git diff` on the four parity surfaces empty.
- Criterion (no-regression, critic-r1 B1 rewording): the FIVE router-invariant rows of the manual
  harness hold — emit tokens `dmc-ultrawork` (`v011:59`) / `dmc-plan-hard` (`:60`), mid-sentence
  negative (`:62`), parser line 14 (`:63`), mode writes (`:67-71`) — and the harness reports NO NEW
  failures beyond the 2 pre-existing non-router rows (`v011:31` stale stop-block, `v011:77`
  6-skills hardcode) already failing on untouched HEAD `186ed8c` (documented known-baseline delta;
  v011 itself is never edited).
  Verification Method: `bash .harness/evidence/v011-verify.sh` ⇒ the 5 invariant rows PASS and
  FAIL-count == 2 with exactly those two row names; `bash -n` on the router; `python3 -m py_compile`
  on the shim.
- Criterion (no-regression): frozen surface byte/count-unchanged.
  Verification Method: `bin/dmc selftest --all` 802/3/3 EXACT (committed replica + post-commit live);
  `bin/dmc mirror-check` PASS; `bin/dmc selftest m6-suite` green (test-restore uses the frozen
  fixture); `git diff tests/fixtures/hooks-v0.6.5/hooks/dmc-router.sh` empty; fast-default selftest
  count unchanged; `bin/dmc linkcheck` green.
- Criterion: HONEST_SCOPE carries the instruction-level-not-runtime caveat; INSTALL_MANIFEST
  content-independent (no ship-surface file added/removed).
  Verification Method: grep the caveat line; `git diff INSTALL_MANIFEST.md` empty.
- Criterion: CI green on branch after the human push gate.
  Verification Method: `gh run view <id> --json conclusion` = success (post-push only).

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| One-sided edit (only bash OR only Codex) silently falsifies the four parity claims — no existing test catches it | high | T018.1 makes it ONE executor / ONE task over BOTH enforcement files; T018.2 adds the CI-blocking cross-adapter parity rows that did not exist |
| Signature/priority text displaces the `dmc-ultrawork`/`dmc-plan-hard` substrings → v011 rows `:59-60` silently red | medium | Append/wrap, never replace those tokens; v011-verify.sh run as a mandatory no-regression gate; explicit AC |
| Case-folding accidentally makes mid-sentence fire (anchor dropped) | medium | Keep `[[:space:]]*$` / `\s*$`; LP1 + m65 negative rows assert `the DMC feature is nice` → 0 bytes |
| Editing the frozen `hooks-v0.6.5` fixture "to stay in sync" turns BLOCKING m6-suite red via test-restore | high | Fixture is explicitly no-edit; m6-suite green + `git diff` on the fixture empty are ACs |
| `test-rollback.sh` router row flips red after the edit and is later mistaken for a regression | low | Unwired manual proof (bin/dmc:224 omits it); DOCUMENT the expected drift in the evidence log, do not fix |
| DMC-PRIORITY read as a hard runtime guarantee | medium | HONEST_SCOPE caveat + "instruction-level" framing in the emit/CLAUDE.md/OMC_COEXISTENCE.md prose (scout lane 3) |
| Host propagation ships new Ring-0 emit text with no automated behavioral gate on hosts | low | m65-suite + LP1 prove behavior in-repo; doctor presence check unchanged; emit is advisory additionalContext |

## Assumptions

| Assumption | Confidence | How to Verify |
|---|---|---|
| Router + Codex shim are enforcement-class landmarks needing `landmark_authorized`; docs/skills/test are ordinary; MILESTONES.md is release-class | high | live `bin/dmc landmarks` (this session) |
| `m65-suite` is CI-blocking and includes `test-codex-shims.sh` | high | `.github/workflows/dmc-ci.yml:172-173`; `bin/dmc:239` |
| The live router is outside the frozen 802/3/3 mirror — editing it cannot change the baseline | high | `dmc-legacy-selftest.py:9,112,180`; scout lane 1 verdict |
| Folding DMC-PRIORITY into the already-bundled OMC_COEXISTENCE.md needs no INSTALL_MANIFEST edit | high | `INSTALL_MANIFEST.md:295-301`; CLAUDE.md:37 / DMC.md:87 already reference it |
| `has_context_of()` greps only the key name, so new rows must grep content substrings | high | `_m65common.sh:103` |
| Orchestrator/worker split: Opus implements T018.1/T018.2 (enforcement + parity test), Sonnet T018.3/T018.4 (docs + append); all subagents `auto` mode, dispatched synchronously; Ring-0 guards enforce independently | high | per-task owner labels; project memory |

## Execution Tasks

- [ ] DMC-T018.1: Router + Codex shim LOCKSTEP (Opus, ONE executor owns BOTH). Case-insensitive
  `grep -Eqi` / `re.IGNORECASE` matchers AND (B2) case-insensitive task-extraction strips
  (portable char-class sed `:77/:86`; `flags=re.IGNORECASE` on re.sub `:69/:76`); dmc-branch emit
  gains the exact signature + DMC-PRIORITY clause; headers/docstring reworded; PRESERVE
  `dmc-ultrawork`/`dmc-plan-hard` substrings, parser line `:14`, and the suffix anchor.
  Files: `.claude/hooks/dmc-router.sh`, `adapters/codex/dmc-codex-userpromptsubmit.py`.
  Notes: both enforcement → `landmark_authorized`; no blockedBy.
- [ ] DMC-T018.2: NEW CI-blocking UPS cross-adapter parity section (Opus). Drive both hosts with the
  same prompts (lowercase/mixed-case/`해줘. DMC` analog/mid-sentence negative/mixed-case compounds);
  assert signature + DMC-PRIORITY substrings + mode-file equality + (B2) CLEAN task extraction
  (mixed-case emit's task segment carries no trigger token) on both. File:
  `tests/fixtures/m6.5/test-codex-shims.sh`. Notes: content-substring greps (not `has_context_of`);
  (A2) FRESH per-prompt sandbox dirs — no mode-file bleed; blockedBy T018.1.
- [ ] DMC-T018.3: Docs + skill lockstep (Sonnet). DMC.md `:77-85`, CLAUDE.md `:31-35`,
  OMC_COEXISTENCE.md `:24` + NEW `## Precedence when both fire` at `:61-64`, dmc-ultrawork/SKILL.md
  signature line, DMC_V1_HONEST_SCOPE.md caveat. Notes: name OMC as observed contender; no blockedBy.
- [ ] DMC-T018.4: MILESTONES.md v1.0.1 closure entry (Sonnet, append-only, content human-gated at
  the commit gate; label per the gate). File: `docs/MILESTONES.md` (release → `landmark_authorized`).
  blockedBy T018.1-T018.3.
- [ ] DMC-T018.5: Orchestrator-lane run + verification report. run start → scope.lock compile
  (`landmark_authorized`: the 2 enforcement hooks + MILESTONES.md; create grant:
  `.harness/verification/dmc-v1.0.1-activation.md`) → materialize evidence (built-in exemption, never a
  scope.lock grant) → no-regression sweep → verification report; document the expected `test-rollback.sh`
  router-row drift + the matcher/strip boundary-asymmetry note (r2-A6). Full release gate per the
  ratified GATE-DECISION (green evidence set → `dmc gate release --full` PASS 9/9). blockedBy T018.1-T018.4.

## Verification Commands

| Command | Reason | Required |
|---|---|---|
| `bash -n .claude/hooks/dmc-router.sh` · `python3 -m py_compile adapters/codex/dmc-codex-userpromptsubmit.py` | syntax valid on both edited enforcement files | yes |
| LP1 — live router probes (fenced below; run in the DISARMED verify phase — run suspended + pointer cleared, per this repo's armed-guard constraints) | mixed-case fires, mid-sentence 0 bytes, signature + DMC-PRIORITY present, mode writes | yes |
| `bin/dmc selftest m65-suite` | NEW cross-adapter UPS parity rows present, 0 FAIL (CI-blocking) | yes |
| `bin/dmc selftest` (fast default) · `bin/dmc selftest m6-suite` | section counts unchanged; m6-suite green (test-restore uses the frozen fixture) | yes |
| `bash .harness/evidence/v011-verify.sh` | (critic-r1 B1) the FIVE router-invariant rows PASS (`dmc-ultrawork`/`dmc-plan-hard` tokens, mid-sentence negative, parser line 14, mode writes) AND FAIL-count == 2 with exactly the pre-existing non-router rows (`v011:31` stop-block, `v011:77` skills-count) — known-baseline delta, v011 never edited | yes |
| `bin/dmc mirror-check` · `bin/dmc linkcheck` | 55-file byte-equality intact; all doc refs resolve | yes |
| `bin/dmc selftest --all` (committed replica, then post-commit live) | legacy 802/3/3 EXACT + every section 0 FAIL (CF1 — never masked; router proven outside the frozen surface) | yes |
| `git diff --name-only` vs this plan's allowlist; `git diff tests/fixtures/hooks-v0.6.5/hooks/dmc-router.sh INSTALL_MANIFEST.md orchestration/harness-matrix.json docs/CODEX_ADAPTER.md` (empty) | scope conformance; frozen fixture, manifest, and parity surfaces untouched | yes |
| `gh run view <id> --json conclusion` (post-push) | CI green on branch | yes |

```sh
# LP1 — live router probes. Runs in the DISARMED verify phase (suspend + pointer cleared).
# Temp CLAUDE_PROJECT_DIR so the real repo mode/state is untouched. Guard-safe: no rm -rf
# (python shutil.rmtree), no discard-redirects (capture to a variable instead).
R=.claude/hooks/dmc-router.sh; T=$(mktemp -d); mkdir -p "$T/.harness/runs"
run(){ printf '{"prompt":"%s","cwd":"%s"}' "$1" "$T" | CLAUDE_PROJECT_DIR="$T" bash "$R"; }
run 'fix the parser dmc' | grep -q 'Okay, Let me do you Coding!'     # signature present
run 'fix the parser dmc' | grep -q 'DMC PRIORITY'                    # priority present
run 'fix the parser dmc' | grep -q 'dmc-ultrawork'                   # invariant substring kept
python3 -c "import os; p='$T/.harness/mode'; os.path.exists(p) and os.remove(p)"
OUT=$(run 'fix the parser dmc'); [ "$(cat "$T/.harness/mode")" = active ]
run 'please refactor this. DMC' | grep -q 'dmc-ultrawork'            # mixed-case suffix fires
OUT=$(run 'please refactor this. DMC')                               # (B2) clean task extraction:
printf '%s' "$OUT" | grep -q 'refactor this\.'                       #   task text present…
printf '%s' "$OUT" | grep -vq 'refactor this\. DMC'                  #   …WITHOUT the trigger token
run 'stand down DMC-OFF' | grep -q 'mode set to OFF'; [ "$(cat "$T/.harness/mode")" = off ]
[ "$(run 'the DMC feature is nice' | wc -c | tr -d ' ')" = 0 ]       # mid-sentence never fires
python3 -c "import shutil; shutil.rmtree('$T')"
```

## Approval Status

Status: APPROVED (Rev 2)
Approver: wjlee (woojin20020@gmail.com) — human plan gate via AskUserQuestion, 2026-07-08
Approved At: 2026-07-08

Gate record (all four questions answered):
1. Plan approved, build start authorized.
2. **Greeting scope → dmc(ultrawork)-ONLY** (ratified as recommended): the signature fires on the
   natural `dmc` trigger and on direct `/dmc-ultrawork` invocations (unconditional SKILL.md line);
   dmc-plan/dmc-off stay greeting-free.
3. **Release label → v1.0.1 (patch)** — the human chose v1.0.1 over the recommended v1.1. All
   NEW artifacts and version references use v1.0.1 (MILESTONES entry, verification report
   `.harness/verification/dmc-v1.0.1-activation.md`, evidence prose). NAMING NOTE: this plan
   file/work_id (`dmc-v1.1-activation-tuning`) is a drafting-time artifact identifier bound into
   the critic-verdict chain (r1/r2 target_ref + hashes) — it is NOT a version claim and is not
   renamed; the ratified release label is v1.0.1.
4. **Full release gate → YES**: `dmc gate release --full` runs on this milestone's release run
   with the M10-pattern green evidence set; PASS 9/9 is an acceptance condition.

Critic chain: r1 REJECT (B1 unsatisfiable v011 gate, B2 task-token leak;
`.harness/evidence/dmc-v1.1-critic-r1.json`, Rev 1 hash `1f5ec5a3…`) → Rev 2 fold → r2 APPROVE,
0 blockers, 2 info advisories (`.harness/evidence/dmc-v1.1-critic-r2.json`, Rev 2 pre-approval
hash `dc3e5f48…`). Critic-r2 advisories carried as MANDATORY build directives: A5 (the codex-side
clean-extraction test row uses a shape-robust assertion — extract the task segment and assert
equality, or `! grep -q <token>` — never a shape-fragile `grep -v` on assumed single-line output),
A6 (the verification report notes the pre-existing matcher/strip boundary asymmetry so a future
maintainer does not "tighten" the strip regex and change extraction).
