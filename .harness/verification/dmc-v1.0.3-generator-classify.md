# Verification Report

## Run ID

dmc-run-c9a159039747 (SUSPENDED; pointer cleared). Branch `claude/dmc-v102-v104-overnight`, HEAD `510f421a9ab1385fb02c56cac7453c8e2b91bf06` == scope.lock `compiled_at_head`.

## Plan

`.harness/plans/dmc-v1.0.3-generator-classify.md` Rev 2 (critic r1 REJECT -> r2 APPROVE -> r3 APPROVE). plan_hash `9ce2f17a679a8e4c798b39e9335058b57f97b6dbba75dbd78058e6d96f2ed775` == run.json plan_hash == live file sha256 == critic r2/r3 plan_hash.

## Changed Files

- `.harness/schemas/landmarks.schema.md`: one-bullet seed-union reword (+3/-2)
- `AGENTS.md`: regen — §4 +2 `.codex` rows, §5 enumeration +2 (+3/-1); NO §7 hunk
- `bin/lib/dmc-agents-md.py`: presence-gated §7 companion-docs emission + C1/C2 selftest rows (+45/-3)
- `bin/lib/dmc-repo-intel.py`: `.codex/` -> enforcement rule + L1g rows (+5/-1)
- `docs/MILESTONES.md`: one appended v1.0.3 closure entry (+21/-0)

## Commands Run

| Command | Result | Reason | Output Summary |
|---|---|---|---|
| `bin/dmc agents-md --stdout` + diff vs AGENTS.md | PASS | root-cause proof | substring present; byte-identical (empty diff); both .codex rows in §4/§5 |
| host-shape drill (mktemp: absent / present / 2-of-3) | PASS | host honesty + atomic gate | absent OMITS; present EMITS; 2-of-3 OMITS |
| `python3 bin/lib/dmc-agents-md.py --self-test` | PASS | module selftest | 26 PASS / 0 FAIL (C1 emit, C2 host-shape omit) |
| `bash .harness/evidence/dmc-v0.4.7-context-audit.sh --self-test` | PASS | frozen AC6 | 7/0; AC6 discoverability PASS; AC7 repo byte-unchanged |
| `bin/dmc agents-md --validate AGENTS.md` | PASS | doc contract | VALID: 10 sections present/non-empty/no filler |
| `bash tests/fixtures/m6.5/test-agents-md.sh` | PASS | fixture suite | 35 PASS / 0 FAIL; file not in diff; real-repo byte-identical |
| `bin/dmc selftest landmarks` | PASS | .codex classification | 13/0; L1g both files enforcement; L1f green |
| `bin/dmc landmarks` (count) | PASS | live map | total 189; `.codex/config.toml`+`.codex/hooks.json` enforcement |
| scope-lock drill (live-classifier-fed, unauth vs auth) | PASS | rule->map->refusal | unauth REFUSED SCOPE-LOCK-LANDMARK-UNAUTHORIZED (exit 3, no lock); auth VALID |
| schema reword lexeme check | PASS | registered deferral | "historically included" + "removed by the human-gated hygiene cycle 2026-07-08" present |
| `bin/dmc selftest schemas-mirror` | PASS | mirror set | 15/0 |
| `bin/dmc mirror-check` | PASS | frozen mirror | PASS; 55-file set byte-identical |
| `bin/dmc linkcheck` | PASS | reference integrity | clean; 24 files scanned |
| `bash tests/fixtures/m6.5/test-codex-shims.sh` | PASS | baseline | 143/0 |
| `bin/dmc selftest` (full) | PASS | regression floor | rc=0; 77 PASS / 0 FAIL across 9 core suites |
| `bin/dmc selftest m65-suite` | PASS | m6.5 aggregate | rc=0; codex-shims 143/0, skills-mirror 7/0, agents-md 35/0 |
| DEFAULT_PROTECTED overlap check | PASS | no G4 override | no changed file under any frozen protected prefix |
| `dmc gate release --full` | SKIPPED | PENDING-BY-ENVELOPE | morning human gate |
| committed-replica + live `selftest --all` 802/3/3 | SKIPPED | PENDING-BY-ENVELOPE | needs the post-report LOCAL commit; morning gate |

## Manual Checks

| Check | Result | Notes |
|---|---|---|
| Diff subset of the 5 scope.lock paths | PASS | exactly the 5 authorized paths modified |
| Bounds vs numstat | PASS | 5 files (<=5), +77 (<=120), -7 (<=40) |
| scope.lock validator | PASS | VALID / untampered; state_hash `7006d2bedff5b2ef` |
| lock + snapshot sha256 vs run.json | PASS | both MATCH operative_snapshot |
| Untracked files | PASS | governance artifacts only (evidence/plans/verification) |
| §7 zero-hunk | PASS | AGENTS.md diff confined to §4/§5 |
| MILESTONES append-only | PASS | `@@ -716,0 +717,21 @@`; no 4-segment version label |
| Critic chain | PASS | r1 REJECT (Rev1) -> r2/r3 APPROVE (Rev2, hash-bound) |
| AUTONOMY branch/push | PASS | dedicated branch; not on origin; build uncommitted |

## Scope Review

Result: PASS

Notes: Working-tree diff == exactly the five scope.lock-authorized paths; no out-of-scope file touched. Bounds respected (5/120/40 vs 5/77/7). scope.lock VALID and untampered (recomputed state_hash matches). Untracked entries are governance artifacts only. Verifier drills wrote to an ephemeral scratchpad only — repo confirmed unmutated (`git status --porcelain` shows only the 5 M files + governance ?? files).

## Package / Env / Migration Review

Package files changed: no
Env files changed: no
Migration files changed: no

Notes: No dependency, environment, or migration surface touched; the two Python edits use already-imported stdlib `os` only (no new imports/deps).

## Unresolved Risks

- Release-readiness (plan AC4 full gate + live legacy 802/3/3) is not yet demonstrated; deferred to the post-report LOCAL commit and the morning human gates by the ratified overnight envelope (PENDING-BY-ENVELOPE, not a verification failure).

## Final Status

PASS

Pre-commit build certification: all runnable, in-scope verification commands PASS; scope/bounds/immutable-binding/regression floor all green. The following remain PENDING-BY-ENVELOPE and are NOT part of this pre-commit PASS: green set, `dmc gate release --full`, the one LOCAL commit, committed-replica + live `selftest --all` 802/3/3, and push/CI/main-FF (morning human gates).
