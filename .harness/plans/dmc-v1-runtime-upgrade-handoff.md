# HANDOFF — dmc-v1-runtime-upgrade (session → session)

Date: 2026-07-06 (rev 3 — direction re-alignment shipped after M3–M5) · Branch: `claude/dmc-v1-runtime-upgrade-c5uch1`
Session end state: worktree clean except local-only run archives/auto-logs (`.harness/runs/**`,
`.harness/evidence/dmc-run-*.md`, untracked by policy); `main` untouched (`main` == `origin/main` == `d0edc48`).

## Resume quickstart (local)

```bash
git fetch origin claude/dmc-v1-runtime-upgrade-c5uch1
git checkout claude/dmc-v1-runtime-upgrade-c5uch1
bin/dmc selftest        # expect 9 sections, 75 PASS / 0 FAIL, exit 0 (fast default)
bin/dmc selftest --all  # ~10 min; expect legacy 802/3/3 EXACT + run-core 153/0 + loop-core 78/0
                        # + roles 19/0 + verdict-validate 16/0 + verdict-gate 9/0 + delegation 29/0
                        # + linkcheck 17/0 + mirror + rollback PASS + SELFTEST-ALL PASS + exit 0
bin/dmc help            # M2–M5 command surface (orient/landmarks/depsurface/radius · validate ·
                        # legacy/mirror-check/rollback-test · run · roles/verdict/delegation/linkcheck)
```

## Where things stand

| Milestone | State | Commit(s) | Key artifacts |
|---|---|---|---|
| M1 docs (Phase 0–4) | DONE + human-ratified | 1c139fb..cf30720 | audit / architecture / orchestration docs, plan Rev 2 |
| M2 repo intelligence | DONE (41/0) | 116db38 | bin/dmc, dmc-repo-intel.py, 4 schemas |
| M3 schemas + validators + copy-routing | DONE, pushed | `1b9a4c3` + fix `3b2d1c4` | 6 schemas, dmc-instance-validate.py, 55 bin/lib copies, selftest --all, pinned baseline 802/3/3 |
| M4 run-lifecycle core (8 primitives) | DONE, pushed | `8903a67` | 10 modules (run/scope-lock/approvals+R12/evidence+check_id/checkpoints/acceptance/verify-plan/fixloop/recovery), run-core 153/0 + loop-core 78/0 |
| M5 orchestration registry | DONE, pushed | `9ec5055` | orchestration/roles.json, 6 contract-ized agents (+release-auditor), verdict/delegation validators + verdict-gate, 3 skills bound to `dmc run start`, linkcheck, 3 docs additively pointer-ized (17 gated substrings preserved) |
| v0.5 direction re-alignment (run dmc-run-0e29d09bf3b5) | DONE (critic R2 PASS · verifier ACCEPT · verification PASS) | `1b276f3` | direction plan APPROVED+executed: master plan **Rev 3** (M6.5 Codex Adapter inserted; order M6→M6.5→M8→M7→M9→M10; M6 gains post-Bash diff guard + semantic verify cross-checks; Deferred register: worker-bridge expansion, P5 benchmark), docs/CODEX_ADAPTER.md, DRAFT plans dmc-v1-m6-hook-hardening + dmc-v1-m6.5-codex-adapter |
| M6–M10 | **NOT STARTED, NOT APPROVED** (M6 + M6.5 have authored DRAFT plans awaiting critic + gate) | — | master plan §Execution Tasks M6–M10 (Rev 3) |

Approval state (master plan `## Approval Status`): **APPROVED M2+M3+M4+M5 (M1 retroactively ratified)** —
approver wjlee. **M6+ remain UNAPPROVED**; each needs its own milestone plan → critic → human gate
(M4/M5 pattern: milestone-scoped plan file, `dmc validate plan` VALID, critic APPROVE, approval record in both plans).
No active run: `.harness/runs/current-*` cleared after M5 closure; per-milestone run archives are local-only.

## Working pattern that shipped M3–M5 (keep it)

Orchestrator (human-gated) + worker agents (Opus 4.8 complex / Sonnet 5 mechanical) + independent non-authoring
critic (plan stage) and verifier (build stage) + committed-replica `--all` proof + post-commit live re-run as the
closure condition. Single-owner rule for `bin/dmc` (one sub-task registers all verbs/sections). Human gates every
time for: milestone approval, staging, commit, push. Evidence/verification per milestone; verification reports must
pass `dmc validate verification`.

## Next step (critic pass + human gate first)

**M6 — Hook/guard hardening (DMC-T011): THE PROTECTED-SURFACE MILESTONE** (.claude/hooks/*, settings.json —
first edit of the enforcement floor). Its milestone plan is ALREADY AUTHORED as DRAFT:
`.harness/plans/dmc-v1-m6-hook-hardening.md` (schema-VALID) — next action is its critic pass, then the human
gate. Scope per master plan Rev 3: hooks become shims over Ring-0 verdict CLIs; Bash write-radius classifier
(deny `git apply`/`patch`); **post-Bash diff guard** (changed files vs scope.lock; NARROW exemption — Bash
writes to scope.lock.json/approvals.jsonl/run.json DENIED); **semantic verification cross-checks** (run-id
match, files⊆scope+git-consistent, PASS-refusal on failed/unexcused-skipped required checks); secret-guard
superset keys + case-insensitivity; fail-closed-in-active; stop gate → receipt-coverage; canonical-five
fixtures (1)(2)(3); pre-M6 hooks byte-preserved as committed fixtures BEFORE editing; single revert commit
restores v0.6.5 hooks+settings byte-identically; compatibility matrix so legitimate ops still pass.

After M6: **M6.5 — Codex Adapter** (DRAFT plan `.harness/plans/dmc-v1-m6.5-codex-adapter.md`; its critic pass
is deliberately deferred until M6 ships because the shim interfaces freeze at M6 closure; spike-first —
re-prove the web-verified 2026-07-06 Codex surface on a local CLI before any build; installer `--host` stays
M8). Design authority: `docs/CODEX_ADAPTER.md`. Execution order (Rev 3): M6 → M6.5 → M8 → M7 → M9 → M10.

## Carry-forwards (do not lose)

1. 3 pinned upstream FAILs (v0.1.3 "GLM/worker code found" · v0.2.3 "V5 mock" · v0.3.2 "AC5") are HUMAN-ACCEPTED
   baseline (802/3/3); never "fix" or mask them inside another milestone — separate hygiene plan if ever.
2. M9 release gate MUST resolve approval `verification_ref` → artifact (M4's gate is presence-only by design;
   the honest-scope note is recorded in dmc-v1-m4 evidence + verification).
3. M9 CI model-name grep must scope to `orchestration/ .claude/agents/` or exempt `bin/lib/dmc-roles.py`
   (it legitimately carries detector patterns).
4. linkcheck covers machine-consumable refs only (code-span verbs / path literals / `Role:` bindings) —
   documented judgment call; prose-embedded dangling refs are unchecked.
5. verdict-gate is value-blind (C11): a plan-bound REJECT passes the gate; content judgment is the human's.
   No machine check blocks a REJECT until M6 Ring-1 wiring — that wiring is M6's job.
6. Auto-log local-only policy stands: `.harness/evidence/*.md` deliberate deliverables are committed;
   run archives under `.harness/runs/` stay local.
7. The two working-tree-drift legacy checks (v0.5.9 AC13 / v0.6.0 V15) FAIL `--all` whenever tracked files are
   modified uncommitted — expected artifact class; the committed-replica proof + post-commit re-run is the pattern.
8. Task-ID namespaces collide across plans (master §M6.5 `DMC-T011b` vs M6-plan `DMC-T011b`; M6.5-plan
   `DMC-T012a–e` vs master §M7 `DMC-T012`) — validators accept per-plan namespaces; renumber at the M6/M6.5
   critic passes (verifier advisory finding 6).
9. Critic R2 verdict for the direction plan binds the PRE-approval Rev 2 bytes (plan_hash `277ee35d…`); the
   current file hashes `a85c12db…` because the approval record was appended after — a naive re-hash "fails" by
   design; the chain (R2 → approval citing 277ee35d → run.json binding a85c12db) is documented in
   `.harness/verification/dmc-run-0e29d09bf3b5.md`.

## Branch commit log (oldest → newest, all beyond `main` @ `d0edc48`)

1. `1c139fb`..`cf30720` — M1/M2 + cloud handoff (see git log)
2. `1b9a4c3` — M3: 6 schemas, instance validators, legacy copy-routing (74 files)
3. `3b2d1c4` — M3 follow-up fix: hermetic self-tests + evidence transcript refresh
4. `8903a67` — M4: run-lifecycle core, 8 primitives (25 files)
5. `9ec5055` — M5: orchestration registry, agents, validators, skill bindings, linkcheck (35 files)
6. `1c672a0` — handoff rev 2 (M3–M5 shipped, next M6)
7. `1b276f3` — v0.5 direction re-alignment: master plan Rev 3 (M6.5 Codex Adapter), CODEX_ADAPTER design,
   M6/M6.5 DRAFT plans, direction evidence/verification (10 files, +1273/−11)
