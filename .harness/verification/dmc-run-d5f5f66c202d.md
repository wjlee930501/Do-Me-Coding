# Verification Report

## Run ID

dmc-run-d5f5f66c202d

## Plan

`.harness/plans/dmc-fable-core-a-succession.md` (Rev 2; sha256 `b3538e45540566a178fa39c80b27e83793d1c959114f266b315375efc7d02ee8`; Approval Status: APPROVED)

## Changed Files

- `.harness/plans/dmc-refinement-diagnosis-20260709.md`: A1 — new tracked file (still `??` pending stage), dated status-update blockquote banner (5 bullet lines) inserted directly after the H1 title + wrapped intro paragraph (lines 1-4); all original prose below (lines 12-70+) verified present and byte-unmodified by content-presence check (file is new/untracked so a diff-based purity check is inapplicable — content-presence greps are the correct proxy, per critic r2's own reasoning, independently confirmed).
- `docs/DMC_AGENT_HANDOFF.md`: A2/A3 — new section `## Runners without subagents — degradation rule (added 2026-07-09)` inserted between "Fail-closed checklist" (L44) and "Anti-token-max reminder" (L55), 6 lines added, 0 removed, single diff hunk.

## Commands Run

| Command | Result | Reason | Output Summary |
|---|---|---|---|
| `shasum -a 256 .harness/plans/dmc-fable-core-a-succession.md` | PASS | plan_hash binding | `b3538e45...` matches run.json `plan_hash` and critic r2 `plan_hash` exactly |
| `grep -c 'Status update (2026-07-09' <memo>` | PASS | AC1 | = 1 |
| `grep -c '32,490 bytes' <memo>` | PASS | AC1 | = 2 (banner + original L13) |
| `grep -c 'emitted twice' <memo>` | PASS | AC1 | = 2 (banner + original risk-#6 unbolded occurrence at L66; the bolded L14 occurrence "emitted **twice**" correctly does NOT match, confirming original text is untouched) |
| `grep -n 'PENDING' <memo>` | PASS | AC1 | banner L9 contains "§9 decision questions remain PENDING a human gate" |
| `git ls-files -- <memo>` | PASS (expected empty) | AC1 | empty — memo correctly not yet staged/committed (staging is a later T003 step) |
| `grep -c '^## Runners without subagents' docs/DMC_AGENT_HANDOFF.md` | PASS | AC2 | = 1 |
| section-scoped `grep -ci 'fresh'` | PASS | AC2 | = 2 |
| section-scoped `grep -ci 'stop'` | PASS | AC2 | = 1 |
| section-scoped `grep -ci 'source of truth'` | PASS | AC2 | = 1 |
| section-scoped `grep -c 'Art. VIII'` | PASS | AC2 | = 1 |
| `git diff -- docs/DMC_AGENT_HANDOFF.md \| grep -E '^-' \| grep -v '^---'` | PASS | AC2 additive-only | no matches (zero removed lines); `git diff --stat` confirms 6 insertions(+), 0 deletions(-); 1 hunk |
| `bin/dmc selftest` (default) | PASS | plan's literal floor requirement | 31 PASS / 0 FAIL (validate-run 6/0, validate-verification 6/0, schemas-mirror 15/0, legacy-mirror 4/0) |
| `bin/dmc selftest --all` | PASS | deeper diligence beyond plan's literal ask | completed clean, 0 FAIL anywhere observed, `git status --porcelain` unchanged by the suite (hermetic run confirmed) |
| `bin/dmc linkcheck` | PASS | AC3 | "OK: linkcheck clean — 24 file(s) scanned, every dmc-verb / artifact-path / role reference resolves" |
| `bin/dmc verdict validate` (r1, r2) | PASS | verdict schema conformance | both `VALID … conforms to dmc.critic-verdict.v1` |
| `bin/dmc verdict gate --plan-hash <current plan sha256> --verdict r2` | PASS | verdict-plan binding | "PASS: verdict gate — referenced critic-verdict is schema-valid and plan-bound" |
| `git diff --name-only` (tracked working tree) | PASS | AC4 scope | exactly `.codex/config.toml` (pre-existing unrelated) + `docs/DMC_AGENT_HANDOFF.md` (in-scope) |
| `git diff -- .codex/config.toml` | PASS | pre-existing-dirty isolation | contains only `model = "gpt-5.5"` + 3 sibling config lines — identical to the pre-existing dirty state noted in the plan's T003 staging warning; NOT touched by this run |
| `git log --oneline -5` / `git status -sb` | PASS | commit/push discipline | no new commit yet for this cycle (expected — commits happen post-verification); branch `claude/dmc-fable-core`; no `origin/claude/dmc-fable-core` remote ref exists — no push occurred |
| `find .harness/runs -iname '*scope*'` + inspect `.harness/runs/dmc-run-d5f5f66c202d/` | FAIL | run-arming / scope-lock verification | `scope.lock.json` does not exist for this run (only `run.json` + `snapshot.txt` present); `.harness/runs/current-scope.txt` (legacy fallback) also absent |

## Manual Checks

| Check | Result | Notes |
|---|---|---|
| plan_hash / repo_hash consistency (run.json vs plan vs critic r2) | PASS | all three bind to the same sha256 |
| Plan Approval Status = APPROVED | PASS | verified in plan file body |
| scope.lock.json exists and paths == exactly the 2 approved files | FAIL | file does not exist at all for this run — cannot verify path-level scope binding because the artifact was never produced |
| Run was actually "armed" (deterministic scope-lock enforcement active during execution) | FAIL | traced root cause in code: `bin/lib/dmc-run-lifecycle.py:cmd_start` (the implementation of `bin/dmc run start`) only writes `run.json` + `snapshot.txt` — it never calls `dmc-scope-lock.py --compile`, despite `.claude/skills/dmc-start-work/SKILL.md` step 3 claiming `run start` "mints and arms the run-id **and locked scope**." `bin/dmc` exposes no verb at all to compile a scope.lock.json (`dmc-scope-lock.py --compile` is only reachable by invoking the library script directly). Confirmed by reading `.claude/hooks/scope-guard.sh` and `.claude/hooks/pre-tool-guard.sh`: both define ARMED := current-run-id present AND that run's `scope.lock.json` exists; when unarmed (this run's actual state — `current-run-id` is set but `scope.lock.json`/`current-scope.txt` are both absent), the L1 scope-write-radius adjudication stands down entirely (`exit 0` / allow) for every Edit/Write and every Bash-mediated write, for the whole execution window. L0 floors (catastrophic/secret/`git apply`) are unconditional and still applied, but the specific 2-file scope constraint was never mechanically enforced — compliance was achieved by executor discipline, not by DMC's own deterministic gate. 16 of 20 runs on disk do carry a `scope.lock.json`; 4 do not (this one plus 3 earlier ones, all also SUSPENDED) — so this is a real, if not unprecedented, gap for this specific run. |
| Outcome-level scope compliance (post-hoc inspection of the actual diff) | PASS | despite the enforcement gap above, the actual observed changes are exactly and only the 2 approved files; no drift, no out-of-scope edits detected by independent inspection |
| Memo original prose preservation (untracked file, content-presence proxy) | PASS | read lines 1-70 directly; all stale grounded-fact lines (L13, L66) present verbatim, banner (L6-10) is a pure prepend |
| No secrets/credentials touched | PASS | both changed files are prose docs; no `.env`/key/credential patterns present |

## Scope Review

Result: PARTIAL (outcome PASS, enforcement-mechanism FAIL — see Manual Checks)

Notes: The actual file changes are exactly and only the 2 files the plan's Relevant Files table authorizes (`.harness/plans/dmc-refinement-diagnosis-20260709.md`, `docs/DMC_AGENT_HANDOFF.md`), confirmed independently via `git diff --name-only`, `git status --short`, and direct content inspection — this holds. However, the run's `scope.lock.json` was never compiled, so DMC's own deterministic Ring-0/Ring-1 scope-enforcement mechanism (`scope-guard.sh`, `pre-tool-guard.sh` → `bin/dmc bash-radius`) was inactive for the entire execution window; the scope discipline observed here is provable only by post-hoc inspection, not by construction. This is a genuine gap relative to CLAUDE.md's own non-negotiable rule ("No accepted file scope, no edit") and the plan's own text ("bound via `bin/dmc verdict gate` before any run is armed" — the run was in fact never armed in the scope-lock sense).

## Package / Env / Migration Review

Package files changed: no
Env files changed: no
Migration files changed: no

Notes: Both changed files are Markdown documentation. No `package.json`/lockfiles, no `.env*`, no schema/migration files touched. `.codex/config.toml`'s modification is pre-existing and unrelated to this cycle (confirmed byte-identical diff to the pre-run state described in the plan's own T003 staging warning).

## Unresolved Risks

- **Scope-lock arming defect (compensated by a post-hoc control):** `scope.lock.json` was never compiled for run `dmc-run-d5f5f66c202d` — root-caused to `bin/dmc run start` (`bin/lib/dmc-run-lifecycle.py:cmd_start`) never invoking `dmc-scope-lock.py --compile`, and no `bin/dmc` verb exposing that compile step at all, so the deterministic L1 scope-write-radius floor stood down for the whole execution window. Compensating control applied THIS verification: independent post-hoc inspection of `git diff --name-only` / `git status --short` / per-file diff content proves the actual edits landed exactly and only inside the approved 2-file scope with zero drift — so the outcome is scope-clean, but only by inspection, not by machine construction. Recommend fixing `run start` (or the `dmc-start-work` SKILL.md claim that contradicts it) before Cycles D-core/C/B rely on the same false "armed" assumption.
- **Disclosure advisory (carried verbatim from critic r2, unresolved):** the memo carries internal product codenames (Product-A / Product-B / Product-C) and candid strategy; repo is public; merging to main publishes it — the push-gate reviewer must consciously ratify disclosure.

## Final Status

PARTIAL

---

_Orchestrator disposition note (2026-07-09, appended at persist time): this PARTIAL is accepted as
the honest record of run dmc-run-d5f5f66c202d and is NOT the basis for staging. Remediation chosen:
revert both edits, start a FRESH run under the same APPROVED plan + critic r2 verdict, compile and
validate `scope.lock.json` BEFORE any edit (the step `run start` was documented-but-not-implemented
to do), re-apply the identical edits under live enforcement, and re-verify. The re-run's report is
`.harness/verification/<new-run-id>.md`; the `run start` arming defect + SKILL.md mismatch is
registered for the human gate (v1.1+ candidate or immediate fix cycle — user's call)._
