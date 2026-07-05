# HANDOFF — dmc-v1-runtime-upgrade (cloud session → local session)

Date: 2026-07-05 · Branch: `claude/dmc-v1-runtime-upgrade-c5uch1`
Cloud session end state: worktree clean; local == origin on this branch; `main` untouched
(`main` == `origin/main` == `d0edc48`).

## Resume quickstart (local)

```bash
git fetch origin claude/dmc-v1-runtime-upgrade-c5uch1
git checkout claude/dmc-v1-runtime-upgrade-c5uch1
bin/dmc selftest                 # expect 36 PASS / 0 FAIL (orient 10 · landmarks 11 · depsurface 8 · radius 7)
bin/dmc help                     # M2 command surface
```

## Where things stand

| Milestone | State | Key artifact |
|---|---|---|
| M1 docs (Phase 0–4) | DONE + human-ratified | audit / FABLE_WORKFLOW_TRANSFER / DMC_V1_RUNTIME_ARCHITECTURE / DMC_V1_ORCHESTRATION_MODEL / plan Rev 2 |
| M2 Repository Intelligence P1/P2/P4/P5 | DONE, verified PASS (41/0) | `bin/dmc`, `bin/lib/dmc-repo-intel.py`, 4 schemas, `tests/fixtures/*` |
| M3+ | **NOT STARTED, NOT APPROVED** | plan §Execution Tasks M3–M10 |

Approval state (plan `## Approval Status`): **APPROVED (M2 ONLY; M1 retroactively ratified)**
— approver wjlee, 2026-07-05. M3+ remain UNAPPROVED; each needs its own human gate.
No active run: `.harness/runs/current-*` cleared after M2 closure.

## Branch commit log (oldest → newest, all beyond `main` @ `d0edc48`)

1. `1c139fb` — Phase 0–4 deliverables (audit, transfer, architecture, orchestration, DRAFT plan)
2. `4ab5c03` — plan Rev 2 (critic REJECT blockers 1–5 closed, items 6–11 addressed)
3. `5b71595` — M1 verification report (PASS; critic REJECT→Rev 2→APPROVE recorded)
4. `1fc679c` — M1 evidence consistency fix (cloud commit/push exception recorded)
5. `116db38` — **M2 implementation** (P1/P2/P4/P5 + schemas + fixtures; selftest 36/0 + E-checks 5/0)
6. `eafe062` — M2 auto-logged evidence committed (cloud clean-tree exception; content-reviewed)
7. `6d3240b` — M2 auto-log consistency fix (exception recorded in evidence/verification)

## Read-first map for the local session

- Plan (single source of truth for scope/status): `.harness/plans/dmc-v1-runtime-upgrade.md`
- Audit (why each milestone exists): `.harness/plans/dmc-v1-runtime-upgrade-audit.md`
- Architecture (P1–P20 contracts): `docs/DMC_V1_RUNTIME_ARCHITECTURE.md`
- Orchestration (roles/capability classes): `docs/DMC_V1_ORCHESTRATION_MODEL.md`
- M2 evidence/verification: `.harness/{evidence,verification}/dmc-v1-m2-repo-intel.md`
- Operational exceptions (cloud push / auto-log): recorded inside the M1/M2 evidence files.

## Next step (requires human approval first)

**M3 — Schema upgrades + tool copy-routing + instance validators** (plan DMC-T007/T008):
new schemas (acceptance, scope-lock, fixloop, delegation, critic-verdict, worker-review),
plan/run/verification instance validators, baseline pin → copy `.harness/evidence/dmc-v0.*`
into `bin/lib/` with routing + mirror-check (copy-then-shim; originals stay canonical).
Lifecycle per plan: approve M3 scope → `.harness/runs/current-*` 생성 → implement →
`bin/dmc selftest --all` == pinned baseline → evidence → verification → gate.

## Carry-forward notes (do not lose)

1. (critic) M6/M7 regression fixtures for pre-hardening hooks/validator must live under an
   already-authorized surface (`bin/**` or `adapters/**`); record location in evidence.
2. (critic) M2 radius self-tests use synthetic check-ids — when M4 lands acceptance.json,
   wire cross-resolution WITHOUT weakening the ≥1-check-id refusal (already honored in M2).
3. (critic) M5 evidence must state which layer produces the "start-work refused without
   critic-verdict" refusal (Ring-2 skill text vs `dmc run start`), since Ring-1 hardening
   arrives only in M6.
4. Auto-log commits are NOT the default: local sessions revert to the standing local-only
   auto-log policy (the cloud clean-tree exception does not carry over).
5. `bin/lib/__pycache__` must never be committed (created by py_compile; delete before
   staging — the repo `.gitignore` does not cover it yet; adding that line is an M3+ hygiene
   candidate, not yet approved).
