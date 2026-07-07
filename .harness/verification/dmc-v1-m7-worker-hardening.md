# Verification Report

## Run ID

dmc-run-92b7f126f79d

## Plan

.harness/plans/dmc-v1-m7-worker-hardening.md

## Changed Files

- .claude/hooks/worker-result-check.py: T012.1 — class (4)(5) + empty-allowed DENY, task_id/provider cross-checks, required-field floor, clean-REJECT input handling; `DISALLOWED`/`diff_paths` API preserved verbatim, hardened parse in new `diff_entries` (scope.lock: edit, enforcement)
- .claude/hooks/worker-context-guard.sh: T012.1 — fail-closed on JSON-parse / missing-file / python3-absent / detector-import failure; imported OAuth token classes (scope.lock: edit, enforcement)
- bin/lib/dmc-worker-review.py: T012.2 NEW — review-check / authorize / apply-check / fidelity + --self-test; dmc.worker-review.v1 + apply-authorization chain (scope.lock: create, enforcement)
- .harness/schemas/apply-authorization.schema.md: T012.2 NEW — dmc.apply-authorization.v1 contract (scope.lock: create, contract)
- .harness/workers/authorizations/.gitkeep: T012.2 NEW — authorization artifact directory (scope.lock: create)
- bin/lib/dmc-delegation.py: T012.3 — append/check runtime-records verbs + scope_lock_ref content tier; existing 29 validate rows preserved (scope.lock: edit, enforcement)
- bin/dmc: T012.4 — worker verb arm, delegation append/check pass-through, M7SUITEDIR + run_m7_suite, worker-check + m7-suite sections in --all and named blocks (scope.lock: edit, enforcement)
- .claude/skills/dmc-worker-import/SKILL.md: T012.4 — hardened result-check + review-check wiring (scope.lock: edit)
- .claude/skills/dmc-worker-review/SKILL.md: T012.4 — review -> authorize -> apply-check -> fidelity apply-flow wiring (scope.lock: edit)
- tests/fixtures/m7/_m7common.sh: T012.5 NEW — suite helpers, porcelain-untouched guard (scope.lock: create)
- tests/fixtures/m7/test-worker-adversarial.sh: T012.5 NEW — canonical (4)(5) + empty-allowed + cross-check + carve-out + context-guard rows (scope.lock: create)
- tests/fixtures/m7/test-worker-chain.sh: T012.5 NEW — review-check / authorize / apply-check / fidelity chain (scope.lock: create)
- tests/fixtures/m7/test-delegation-records.sh: T012.5 NEW — delegation append/check chain (scope.lock: create)
- INSTALL_MANIFEST.md: T012.6 — regen-only via --emit-manifest; exactly +2 lines (dmc-worker-review.py, apply-authorization.schema.md) (scope.lock: edit)
- .harness/evidence/dmc-v1-m7-build-20260707.md: T012.6 NEW — build evidence receipt (scope.lock: create)
- .harness/plans/dmc-v1-runtime-upgrade.md: orchestrator lane — §Approval Status M7 approval record only (+7/-3); authorized by plan §Relevant Files row (gate-driven orchestrator lane, outside scope.lock by design)

## Commands Run

| Command | Result | Reason | Output Summary |
|---|---|---|---|
| python3 -m py_compile worker-result-check.py dmc-worker-review.py dmc-delegation.py | PASS | python syntax floor | PYCOMPILE_OK, exit 0 |
| bash -n worker-context-guard.sh + 4 m7 fixtures | PASS | shell syntax floor | BASHN_OK, exit 0 |
| bin/dmc selftest worker-check | PASS | P15 review/chain CLIs | 34 PASS / 0 FAIL |
| bin/dmc selftest delegation | PASS | P14 records + existing validate | 41 PASS / 0 FAIL |
| bin/dmc selftest m7-suite | PASS | adversarial + chain + records | 36 + 26 + 23 = 85 PASS / 0 FAIL, exit 0 |
| bin/dmc selftest m8-suite | PASS | manifest-drift re-proof post-regen | 83 + 17 + 16 + 10 = 126 PASS / 0 FAIL |
| bin/dmc selftest roles | PASS | regression check | 19 PASS / 0 FAIL |
| bin/dmc selftest verdict | PASS | regression check | validate 16/0 + gate 9/0 = 25 PASS / 0 FAIL |
| bin/dmc selftest linkcheck | PASS | regression check | 17 PASS / 0 FAIL |
| bin/dmc selftest skills-mirror | PASS | regression check | 7 PASS / 0 FAIL |
| bin/dmc selftest agents-md | PASS | regression check | 24 PASS / 0 FAIL |
| bin/dmc linkcheck | PASS | new worker verb resolves | clean — 24 files scanned, all refs resolve |
| bin/dmc mirror-check | PASS | 55-file legacy mirror intact | all 55 byte-identical, no stray copies |
| bin/dmc validate plan dmc-v1-m7-worker-hardening.md | PASS | plan instance validity | VALID: conforms to dmc.plan-instance.v1 |
| bin/dmc legacy v0.2-verify | PASS | false-positive resolution check | SUMMARY: PASS=23 FAIL=0, ALL PASS |
| bin/dmc legacy v0.2.1-verify | FAIL(drift) | working-tree byte-pin over uncommitted M7 hooks | 17/2; both FAILs name worker-context-guard.sh + worker-result-check.py (git-diff drift) |
| bin/dmc legacy v0.2.1.1-verify | FAIL(drift) | working-tree byte-pin | 14/1; byte-pin FAIL over the two M7 validators; all mock-vs-glm ACCEPT/REJECT rows PASS |
| bin/dmc legacy v0.2.3-verify | FAIL(drift+pinned) | byte-pin drift + pinned V5 | 17/3; drift over the two M7 validators + pinned "V5 mock (1)" (provider ROUTER test, no M7 file) |
| bin/dmc legacy v0.3.3-verify | FAIL(drift) | C9 byte-pin over .claude/hooks | 33/1/2; sole FAIL C9 names the two M7 validators; all 3x9 provider rows PASS; both N/A pre-existing |
| committed-replica bin/dmc selftest --all (orchestrator) | PASS | 802/3/3 EXACT proof pre-commit | tools=49 PASS=802 FAIL=3 N/A=3, SELFTEST-ALL RESULT: PASS |
| git diff --numstat / status --porcelain | PASS | diff-scope enumeration | ~2957 added / 79 deleted / 17 scoped files (within 6000/400/18) |

## Manual Checks

| Check | Result | Notes |
|---|---|---|
| Diff subset of scope.lock (17-file lock) | PASS | Every implementer code/content change is a scope.lock file; enumerated via git status --porcelain and cross-checked against .harness/runs/dmc-run-92b7f126f79d/scope.lock.json |
| Master-plan edit is approval-record only | PASS | git diff dmc-v1-runtime-upgrade.md = §Approval Status M7 record only (+7/-3); orchestrator lane |
| No frozen surface changed | PASS | M6 hooks + settings.json, .claude/workers/providers/**, installer/uninstaller/doctor, root WORKER_*_SCHEMA.md, worker-review.schema.md all absent from git status |
| Canonical class (4) JWT REJECT + <redacted> ACCEPT | PASS | test-worker-adversarial.sh (live 36/0): jwt/bearer/authz/access_token/gho/ya29 REJECT value-blind, PLACEHOLDER `<redacted>` ACCEPT, legacy 5-class regression REJECT |
| Canonical class (5) rename->forbidden REJECT + benign in-scope rename ACCEPT | PASS | live suite: pure rename / copy / binary / c-quoted / zero-path REJECT; benign in-scope rename ACCEPT; space-bearing out-of-scope caught |
| empty-allowed REJECT; task_id mismatch REJECT; type==mock carve-out ACCEPT; mock-001 pair ACCEPT | PASS | live suite rows all PASS; mock-001 ACCEPT re-confirmed |
| Preserved API: DISALLOWED + diff_paths + diff_entries | PASS | manual-import-adapter.py:80/84/85 imports DISALLOWED + diff_paths from worker-result-check.py; diff_entries loaded by dmc-worker-review.py fidelity verb |
| Committed-replica selftest --all | ACCEPTED(recorded) | Verifier bash radius denies out-of-scope copytree/git-commit; accept orchestrator proof: legacy tools=49 PASS=802 FAIL=3 N/A=3 EXACT + SELFTEST-ALL PASS. Corroborated: M3 baseline pins the same 3 FAILs (v0.1.3 GLM-grep, v0.2.3 V5, v0.3.2 AC5) |
| Rollback settings.json replica FAIL = non-defect | CONCUR | test-restore.sh cmp's .claude/settings.json against the pinned pre-M6 commit 2999870, absent in a single-commit squash replica; M7 changed neither settings.json nor rollback machinery (tests/fixtures/m6/) |

## Scope Review

Result: PASS

Notes: All 16 implementer code/content changes are authorized by scope.lock (compiled at HEAD 0ac72b8, plan_hash 5a34d58c…, run_id dmc-run-92b7f126f79d). The one changed file outside scope.lock — .harness/plans/dmc-v1-runtime-upgrade.md — carries only the §Approval Status M7 record and is authorized by the plan's §Relevant Files row (gate-driven orchestrator lane, outside the implementer write floor by design). No frozen surface (M6 hooks + settings.json, .claude/workers/providers/**, installer/uninstaller/doctor code, root WORKER_*_SCHEMA.md, worker-review.schema.md) appears in the diff. Bounds respected: ~2957 added / 79 deleted / 17 scoped files vs scope.lock max_added 6000 / max_deleted 400 / max_files 18. Untracked run-lifecycle, evidence, plan, and r1/r2/r3 critic-verdict artifacts are orchestrator/critic-lane files outside the implementer scope.lock by design; the pre-existing prior-run untracked artifacts predate M7.

## Package / Env / Migration Review

Package files changed: no
Env files changed: no
Migration files changed: no

Notes: No dependency manifest, lockfile, .env*, or migration/SQL file is in the diff. INSTALL_MANIFEST.md is a DMC name-only ship manifest (not a dependency manifest); its only change is the regen-only +2 lines (bin/lib/dmc-worker-review.py, apply-authorization.schema.md), byte-equality re-proven live by m8-suite test-manifest-drift.sh (10/0). Installer/uninstaller/doctor code byte-unchanged.

## Unresolved Risks

- Non-blocking: apply-check enforcement is skill-mandated procedure, not Ring-0/1-enforced at Edit/Write time; the runtime write floor remains scope.lock adjudication. Disclosed by the plan (Rev 2/A5); becomes blocking at the M9 release gate.
- Non-blocking: the build evidence battery table shows the transient v0.2-verify "22 PASS / 1 FAIL" cell; resolution to 23/0 (behavior-preserving, addendum) is confirmed by this session's live re-run but recorded below its own table row.
- Non-blocking / deferred by design: definitive legacy 802/3/3-EXACT + rollback-PASS closure is the post-commit live selftest --all on the real repo (full history with the M6 commit present) — a human-gated post-commit step, not an M7 build deliverable. The committed-replica proof (single-commit squash) legitimately cannot reproduce the pinned settings.json restore.
- Advisory (build sign-off / verifier): inert SECRET_VALUE/PLACEHOLDER module bindings in worker-result-check.py (harmless); the v0.2-verify grep brittleness (M9/M10 hardening candidate); a delegation-chain external-serialization disclosure line for M9 consumers.

## Final Status

PASS
