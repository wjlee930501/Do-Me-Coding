# Verification Report

## Run ID

`dmc-run-313080b9af69` — work labeled **v1.0.1** (Natural-Activation Tuning). Non-authoring independent verifier lane; read-only; runs disarmed. scope.lock: `.harness/runs/dmc-run-313080b9af69/scope.lock.json` (10 grants, `immutable: true`, compiled at HEAD `186ed8c`).

## Plan

`.harness/plans/dmc-v1.1-activation-tuning.md` — Rev 2 **APPROVED** (wjlee, 2026-07-08). Gate ratified: greeting = dmc(ultrawork)-only; release label = **v1.0.1** (patch, human overrode the recommended v1.1); full release gate = YES. Critic chain: r1 REJECT (B1 unsatisfiable v011 gate, B2 task-token leak) → Rev 2 fold → r2 APPROVE, 0 blockers, 2 info advisories (A5, A6) carried as build directives. Verified against `.harness/evidence/dmc-v1.1-critic-r{1,2}.json`.

## Changed Files

9 tracked modifications, all within scope grants. Totals **177 added / 20 deleted / 9 files** — within bounds (≤450 / ≤80 / ≤10).

| File | +/- | scope grant | landmark |
|---|---|---|---|
| `.claude/hooks/dmc-router.sh` | 7 / 7 | edit | enforcement (authorized) |
| `adapters/codex/dmc-codex-userpromptsubmit.py` | 11 / 8 | edit | enforcement (authorized) |
| `docs/MILESTONES.md` | 42 / 0 | edit | release (authorized) |
| `tests/fixtures/m6.5/test-codex-shims.sh` | 90 / 0 | edit | ordinary |
| `docs/OMC_COEXISTENCE.md` | 13 / 3 | edit | ordinary |
| `CLAUDE.md` | 5 / 1 | edit | ordinary |
| `docs/DMC_V1_HONEST_SCOPE.md` | 5 / 0 | edit | ordinary |
| `DMC.md` | 2 / 1 | edit | ordinary |
| `.claude/skills/dmc-ultrawork/SKILL.md` | 2 / 0 | edit | ordinary |

The 10th grant (`.harness/verification/dmc-v1.0.1-activation.md`, `create`) is this report, persisted by the orchestrator. All untracked additions sit under exempt `.harness/` dirs — built-in materialization exemptions, not scope violations.

## Commands Run

| Command | Result | Reason | Output Summary |
|---|---|---|---|
| `git status --porcelain` · `git diff --numstat HEAD` | PASS | diff-vs-scope + bounds | 9 tracked mods, 177/20; all in-grant |
| `bash -n .claude/hooks/dmc-router.sh` | PASS | syntax | OK |
| `python3 -m py_compile adapters/codex/dmc-codex-userpromptsubmit.py` | PASS | syntax | OK |
| LP1 live router probes (mktemp sandbox, shutil.rmtree cleanup) | PASS | behavior | 13 PASS / 0 FAIL |
| Codex shim direct probes (same prompts, stdin JSON event) | PASS | behavior parity | 12 PASS / 0 FAIL; P2 task segment = 'please refactor this.' (clean) |
| `bin/dmc selftest m65-suite` | PASS | CI-blocking suite | every section 0 FAIL; A16 parity present (34 rows); test-codex-shims.sh 99 PASS / 0 FAIL |
| `bin/dmc selftest` (fast default) | PASS | no regression | every section 0 FAIL |
| `bin/dmc selftest m6-suite` | PASS | frozen-fixture restore path | every section 0 FAIL |
| `bin/dmc mirror-check` | PASS | frozen legacy | 55-file byte-equality intact |
| `bin/dmc linkcheck` | PASS | ref integrity | 24 files scanned, all refs resolve |
| `bash .harness/evidence/v011-verify.sh` | PASS (per B1-reworded gate) | manual-harness invariants | PASS=39 FAIL=2 — the two named pre-existing rows only |
| `git diff HEAD -- <frozen fixture + 4 parity surfaces>` | PASS | untouched surfaces | empty (all UNCHANGED) |
| `bin/dmc selftest --all` | NOT RUN | deferred to orchestrator replica/live per task instruction | — |

## Manual Checks

| Check | Result | Notes |
|---|---|---|
| Matcher lockstep (a) | PASS | Router `grep -Eq`→`grep -Eqi` at :68/:76/:83; shim `flags=re.IGNORECASE` at :62/:68/:74. Anchors byte-unchanged on both. |
| Strip lockstep (b) | PASS | Router sed → portable char-class `[Dd][Mm][Cc]-[Pp][Ll][Aa][Nn]` (:77), `[Dd][Mm][Cc]` (:86); shim re.sub gains `flags=re.IGNORECASE` at :69/:76. |
| Emit shared-prefix equivalence (c) | PASS | Assembled the split shim literals; the dmc-branch prefix is byte-identical to the router's string (signature sentence + DMC PRIORITY sentence + ultrawork route + task last). |
| Parser line byte-untouched (d) | PASS | `DMC_HOOK_INPUT="$INPUT" python3` at router :14 outside every diff hunk. |
| dmc-off / dmc-plan emits unchanged (e) | PASS | Greeting is dmc(ultrawork)-only — A16 P4/P5 + LP1 confirm OFF/plan routes carry no signature. |
| v011 known-baseline delta | PASS (documented) | 39/2; the 5 router-invariant rows PASS; the 2 FAILs are exactly the pre-existing non-router rows `active stop block` (v011:31) + `6 existing skills present` (v011:77) — failing identically on unpatched HEAD. v011 never edited. |
| test-rollback router-row drift | EXPECTED (documented) | test-rollback.sh byte-pins the live router to pre-M6 `299987`; the router row flips red BY DESIGN (drift-detector). Unwired (bin/dmc:224 omits it), zero gate consequence, must NOT be "fixed". |
| r2-A6 matcher/strip boundary asymmetry | NOTED (documented) | Case-insensitivity is reached by two mechanisms in the router: matcher via `grep -Eqi`, strip via explicit char-classes (BSD sed has no `s///I`). The char-classes are LOAD-BEARING — a future maintainer who "tightens" the strip back to plain `dmc`/`dmc-plan` would silently re-introduce the mixed-case task-token leak. The shim is symmetric (re.IGNORECASE both). |
| Docs wording landed | PASS | CLAUDE.md (case-insensitive + DMC PRIORITY block), DMC.md (mixed-case example `리팩터링 해줘. DMC`), OMC_COEXISTENCE.md (reworded + `## Precedence when both fire`, instruction-level best-effort framing). |
| SKILL.md unconditional signature | PASS | "When this skill runs, open the reply with the exact line: Okay, Let me do you Coding! — then proceed." — covers direct `/dmc-ultrawork`. |
| HONEST_SCOPE caveat in §4 | PASS | instruction-level-not-runtime caveat inside `## 4. Disclosed residual register`. |
| MILESTONES pure append + v1.0.1 header | PASS | numstat 42/0; `## v1.0.1 — Natural-Activation Tuning — CLOSED (2026-07-08)`. |
| Frozen fixture + parity surfaces unchanged | PASS | git diff empty for hooks-v0.6.5 fixture, INSTALL_MANIFEST.md, harness-matrix.json, CODEX_ADAPTER.md, ENFORCEMENT_MATRIX.md — parity preserved by lockstep, not doc edits. |

## Scope Review

Result: PASS

Notes: All 9 tracked modifications map 1:1 to edit grants in the immutable scope.lock; the two enforcement-class landmarks and the release-class MILESTONES.md carry `landmark_authorized: true`. No out-of-grant tracked file was touched. Untracked additions are confined to exempt `.harness/` subtrees. Bounds satisfied: 177 ≤ 450 added, 20 ≤ 80 deleted, 9 ≤ 10 files.

## Package / Env / Migration Review

Package files changed: no
Env files changed: no
Migration files changed: no

Notes: No dependency/lockfile/config surface touched. The router remains POSIX-shell + BSD-portable char-class sed; the shim remains Python stdlib-only (re), offline. No `.env*`, credential, or secret file was read, printed, or altered. INSTALL_MANIFEST.md byte-unchanged (no ship-surface delta).

## Unresolved Risks

- Post-report release-gate artifacts (by design): `dmc gate release --full` (target 9/9), the committed-replica + post-commit live `selftest --all` at the pinned 802/3/3 baseline, and branch CI green are minted by the orchestrator lane AFTER this report. This report certifies the enforcement/behavior/scope/doc surface; those gates remain acceptance conditions still to be recorded.
- DMC-PRIORITY is instruction-level best-effort, not a runtime boundary: Claude Code merges hook arrays; DMC has no structural lever to suppress another plugin's hooks. Disclosed honestly in CLAUDE.md, OMC_COEXISTENCE.md, and HONEST_SCOPE §4 — known, non-blocking residual.
- Host propagation has no automated on-host behavioral gate: in-repo proof is m65-suite A16 (CI-blocking) + LP1/shim probes; the emit is advisory additionalContext. Low severity.

## Final Status

PASS

Both enforcement adapters are in verified byte-lockstep (case-insensitive matchers with unchanged anchors, portable case-insensitive strips, identical shared emit prefix, untouched parser line, unchanged OFF/plan emits). Behavior re-verified independently on both hosts (router 13/0, shim 12/0) with clean mixed-case task extraction and mid-sentence-never-fires intact. All required suites green (m65 with the 34-row A16 parity + test-codex-shims 99/0, default, m6, mirror-check, linkcheck); the v011 gate lands at exactly 39 PASS / 2 FAIL with only the two named pre-existing rows. Docs, skill signature, HONEST_SCOPE §4 caveat, and the append-only v1.0.1 MILESTONES header all landed; the frozen fixture and all four parity surfaces are byte-unchanged. Diff is within scope and bounds. The expected test-rollback router-row drift and the r2-A6 boundary asymmetry are documented above. The residual selftest --all / full release gate / CI steps are explicitly delegated to the orchestrator lane.
