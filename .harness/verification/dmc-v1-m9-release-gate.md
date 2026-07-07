# Verification Report

## Run ID

dmc-run-25ecbe729a18

## Plan

.harness/plans/dmc-v1-m9-release-gate.md

## Changed Files

- bin/lib/dmc-release-gate.py: NEW P18 full-tier composer (9 sub-gates + --quick alias + --self-test); in scope.lock (create, enforcement, landmark-authorized)
- .harness/schemas/release-readiness.schema.md: NEW dmc.release-readiness.v1 contract; in scope.lock (create, contract, landmark-authorized)
- .harness/schemas/delegation.schema.md: EDIT — two surgical additions (scope_lock_ref illustration + CF13d serialization-disclosure line); in scope.lock (edit, contract, landmark-authorized)
- bin/dmc: EDIT — RGATELIB + gate/release verb arm + M9SUITEDIR/run_m9_suite + release-gate & m9-suite selftest sections + usage(); in scope.lock (edit, enforcement, landmark-authorized)
- .github/workflows/dmc-ci.yml: NEW greenfield CI workflow (Option A enforcement boundary); in scope.lock (create, enforcement, landmark-authorized)
- tests/fixtures/host-node/package.json: NEW inert host-app fixture substrate; in scope.lock (create, contract, landmark-authorized)
- tests/fixtures/host-node/README.md: NEW host fixture; in scope.lock (create, ordinary)
- tests/fixtures/host-node/.gitignore: NEW host fixture; in scope.lock (create, ordinary)
- tests/fixtures/host-node/src/index.js: NEW host fixture source; in scope.lock (create, ordinary)
- tests/fixtures/host-node/src/util.js: NEW host fixture source; in scope.lock (create, ordinary)
- tests/fixtures/m9/_m9common.sh: NEW suite helper; in scope.lock (create, ordinary)
- tests/fixtures/m9/test-release-gate.sh: NEW gate green-path + g1-g12 + alias suite; in scope.lock (create, ordinary)
- tests/fixtures/m9/test-e2e-loop.sh: NEW full-loop E2E suite; in scope.lock (create, ordinary)
- INSTALL_MANIFEST.md: EDIT — regenerated, exactly +2 auto-listed lines (dmc-release-gate.py, release-readiness.schema.md); in scope.lock (edit, ordinary)
- .harness/evidence/dmc-v1-m9-build-20260708.md: NEW build evidence; in scope.lock (create, ordinary)
- .harness/verification/dmc-v1-m9-release-gate.md: this verification report; in scope.lock (create, ordinary)
- .harness/plans/dmc-v1-runtime-upgrade.md: EDIT — out-of-lock orchestrator lane; change is exactly the §Approval Status M9 record (Status line + M9 approval paragraph), no other content

## Commands Run

| Command | Result | Reason | Output Summary |
|---|---|---|---|
| python3 -m py_compile bin/lib/dmc-release-gate.py | PASS | syntax floor | compiled clean |
| bash -n bin/dmc tests/fixtures/m9/*.sh | PASS | syntax floor | bin/dmc + _m9common.sh + test-release-gate.sh + test-e2e-loop.sh all parse |
| python3 yaml.safe_load .github/workflows/dmc-ci.yml | PASS | YAML parse | 10 steps, fetch-depth 0, timeout 25, ubuntu-latest |
| python3 bin/lib/dmc-release-gate.py --self-test | PASS | composer unit rows | 39 PASS / 0 FAIL (U1-U5, Q1-Q2, E0-E18, Z1) |
| bin/dmc selftest release-gate | PASS | new section direct | 39 PASS / 0 FAIL |
| bash tests/fixtures/m9/test-release-gate.sh | PASS | green path + g1-g12 + alias | 56 PASS / 0 FAIL, exit 0 |
| bash tests/fixtures/m9/test-e2e-loop.sh | PASS | full loop + 5 denials + latency | 35 PASS / 0 FAIL, exit 0 |
| bin/dmc selftest m9-suite | PASS | aggregate wrapper | 56/0 + 35/0, exit 0 |
| bin/dmc selftest delegation | PASS | M5/M7 unregressed | 41 PASS / 0 FAIL |
| bin/dmc selftest worker-check | PASS | M7 unregressed | 34 PASS / 0 FAIL |
| bin/dmc selftest m7-suite | PASS | M7 suite unregressed | 85 PASS / 0 FAIL (36+26+23) |
| bin/dmc selftest m8-suite | PASS | manifest drift re-proof | 126 PASS / 0 FAIL (83+17+16+10; drift byte-equality green) |
| bin/dmc selftest | PASS | fast default unchanged | 75 PASS / 0 FAIL across 9 sections |
| bin/dmc mirror-check | PASS | composed tools byte-unchanged | 55-file byte-equality PASS |
| bin/dmc linkcheck | PASS | gate verb resolves | clean, 24 files scanned |
| bin/dmc validate plan .harness/plans/dmc-v1-m9-release-gate.md | PASS | plan instance validity | VALID (dmc.plan-instance.v1) |
| bin/dmc legacy v0.2.6-gate-check-runner --self-test | PASS | composed tool green | PASS=19 FAIL=0 |
| bin/dmc legacy v0.6.{2,3,4,5}-* --self-test | PASS | composed tools green | self-test PASS x4 |
| committed-replica bin/dmc selftest --all | PASS (with disclosed non-defect) | legacy 802/3/3 + section 0 FAIL | only FAIL is .claude/settings.json rollback (squash-replica artifact: pinned commit 2999870 absent); all other sections 0 FAIL |
| CI-workflow AA1 grep (.claude/install + bin/lib/dmc-doctor.py) | PASS | forbidden-lexeme/network empty | grep exit 1 (no match) |
| CI-workflow CF3 model-name grep (scoped) | PASS | model-name literals empty | grep exit 1 (no match) |

## Manual Checks

| Check | Result | Notes |
|---|---|---|
| Diff subset of scope.lock + plan allow-rows | PASS | all 17 substantive changes map to scope.lock files[]; only out-of-lock change (runtime-upgrade.md) is the §Approval Status M9 record, as authorized for the orchestrator lane |
| No frozen surface changed | PASS | git status clean for the 5 mirror-pinned legacy tools, M6 hooks + settings.json, providers, installer/doctor, root WORKER schemas, dmc-run-lifecycle.py; mirror-check byte-equal |
| delegation.schema.md surgical additions | PASS | exactly 2 additions (scope_lock_ref field + serialization/prev_hash disclosure); delegation validator behavior unchanged (41/0) |
| INSTALL_MANIFEST regen | PASS | exactly +2 lines; manifest-drift byte-equality green (10/0) |
| Plan-hash binding | PASS | on-disk plan sha256 = scope.lock plan_hash = run.json plan_hash; no plan drift |
| Independent gate probe (green PASS / seeded FAIL / structural REFUSE) | PASS | fixtures arm own mktemp repos: green 9/9 PASS; g1-g8 each FAIL own sub-gate; g11 tampered run.json -> REFUSE exit 3; g10 MISSING -> PARTIAL exit 1; g12 chain PASS-with-note |
| CF2 verification_ref resolution | PASS | g7 ghost-ref -> approvals FAIL (RGATE-VERIFICATION-REF-UNRESOLVED); green-path resolving ref -> PASS |
| AA1 CI grep byte-exact + scoped + empty today | PASS | dmc-ci.yml step = M8 :507 pattern over .claude/install + bin/lib/dmc-doctor.py only; returns empty |
| AA3 fixture staged-set = scope.lock files[] | PASS | green path stages exactly files[] so v0.2.6 G2 passes; g2 shows gate-checks FAIL on excluded/protected staged path (G2 has teeth) |
| Rollback additivity | PASS | M9 is additive; revert removes new module/schema/workflow/fixtures/registration; only pre-existing behavior-touch is the 2 delegation.schema.md doc additions (revert restores) |

## Scope Review

Result: PASS

Notes: Every substantive change maps to the run scope.lock (.harness/runs/dmc-run-25ecbe729a18/scope.lock.json, 17 files) and the plan §Relevant Files allow-rows. The single out-of-lock modification (.harness/plans/dmc-v1-runtime-upgrade.md) is confined to the §Approval Status M9 record and is the authorized orchestrator/gate lane. No frozen or protected surface changed: the five mirror-pinned legacy tools (mirror-check 55-file byte-equal), the M6 hooks + .claude/settings.json, .claude/workers/providers, installer/uninstaller/doctor code, root WORKER_*_SCHEMA.md, and the M4 dmc-run-lifecycle.py all show no working-tree changes. Untracked harness bookkeeping (critic verdict r1/r2 JSONs referenced by the plan, run directories, prior-milestone run/evidence files) are append-log/planning artifacts, not run-execution source mutations.

## Package / Env / Migration Review

Package files changed: no
Env files changed: no
Migration files changed: no

Notes: No repository dependency manifest, lockfile, environment file, or migration changed. INSTALL_MANIFEST.md is the DMC ship-surface manifest (regenerated +2), not a dependency manifest. tests/fixtures/host-node/package.json is a NEW inert test-fixture substrate (name "host-app", no dependencies, no-op test script) copied into a mktemp repo by the E2E — never a manifest of this repo. No secret/.env file was read or exposed at any point.

## Unresolved Risks

- The "CI green on branch" acceptance criterion is verifiable only after the human push gate (the workflow is inert until pushed); disclosed and accepted in the plan §Approval Status sequencing note. Locally, the workflow parses cleanly, fetch-depth 0 is pinned, and both CI greps (AA1 forbidden-lexeme, CF3 model-name) return empty over their scoped paths today.
- Non-blocking (r3/verifier advisories): the chain sub-gate is an accountability/provenance tier (deleted chain + deleted authorization ⇒ PASS-with-note; mutation floor is diff-scope + Ring-1 postbash), disclosed in the readiness schema and dispositioned at r2/A2; the chain delegations branch resolves the run dir via repo_root() (correct for closure + copy-surface E2E; a --root pass is a hygiene candidate); delegation.schema.md carries three additive text loci (the two-addition framing undersells the may_mutate sentence — content is on-topic and validator-neutral).

## Final Status

PASS
