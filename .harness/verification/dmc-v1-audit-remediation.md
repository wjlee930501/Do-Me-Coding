# Verification Report

## Run ID

`dmc-run-ef893d0c4857` (SUSPENDED for the verify phase; gates down). Work: `dmc-v1-audit-remediation`.
scope.lock `dmc.scope-lock.v1`, `immutable: true`, compiled at HEAD `9ae8682`, plan_hash
`b252f7cd…`, approved by wjlee (human scope gate, Tier 1+2+3, AskUserQuestion 2026-07-08).
Independent non-authoring verifier lane (did not author the plan or the edits).

## Plan

`.harness/plans/dmc-v1-audit-remediation.md` (Rev 2, APPROVED; plan_hash matches scope.lock).
Audit source: `.harness/evidence/dmc-v1-audit-20260708.md`. Critic r1 (plan) APPROVE
`.harness/evidence/dmc-v1-audit-remediation-critic-r1.json`; critic r2 (build sign-off) APPROVE
`.harness/evidence/dmc-v1-audit-remediation-critic-r2.json`.

## Changed Files

19 tracked files changed vs HEAD; identical to the 19 edit-grant source paths in scope.lock (the 2
create-grant artifacts — the build evidence and this report — are untracked build/verification
outputs, not code). Bounds: +142 / −27, well under max_added 3000 / max_deleted 300; 19 ≤ max_files 21.

- `.claude/agents/{critic,explorer,planner,verifier,release-auditor}.md` (F1)
- `.claude/hooks/evidence-log.sh` (C2, A3), `.claude/hooks/pre-tool-guard.sh` (C1)
- `.claude/install/dmc-install.sh` (G1), `INSTALL_MANIFEST.md` (G1)
- `.github/workflows/dmc-ci.yml` (E2, F7, F8), `.gitignore` (G2)
- `adapters/codex/dmc_codex_common.py` (C2), `tests/fixtures/m6.5/_m65common.sh` (C2)
- `bin/dmc` (D7), `bin/lib/dmc-delegation.py` (B1, B2), `bin/lib/dmc-legacy-selftest.py` (D4)
- `docs/CODEX_ADAPTER.md` (F2), `docs/DMC_AGENT_HANDOFF.md` (F6), `orchestration/roles.json` (E4)

## Commands Run

| Command | Result | Reason | Output Summary |
|---|---|---|---|
| git diff --name-only HEAD | PASS | Diff ⊆ scope | 19 files, exactly == scope.lock edit-grant set; no unlisted/out-of-scope file |
| git diff --numstat HEAD | PASS | Bounds | +142 / −27 (limits 3000 / 300); 19 ≤ 21 files |
| bin/dmc selftest delegation | PASS | B1/B2 no regression | 43 PASS / 0 FAIL (41 base + service-account + `..`-traversal rows) |
| ac4_probe.py | PASS | AC4 security proof | C1 deny 8/8, C1 allow 6/6 (no over-block), C2 redaction 6/6 |
| bin/dmc selftest m65-suite | PASS | C2 3-copy lockstep | 35 PASS / 0 FAIL incl. C3 redaction-parity |
| bin/dmc selftest m8-suite | PASS | G1 manifest == emitter | manifest-drift 10 PASS / 0 FAIL (byte-equality green after regen) |
| bin/dmc selftest m6-suite | PASS | C1/C2/A3 hooks no regression | 104 PASS / 0 FAIL (38+45+10+11) |
| bin/dmc selftest m7-suite | PASS | no regression | 85 PASS / 0 FAIL |
| bin/dmc mirror-check | PASS | Frozen legacy intact | 55 pinned tools byte-identical; no stray copies |
| bin/dmc linkcheck | PASS | Ref integrity | clean, 24 files scanned |
| bin/dmc selftest (default) | PASS | fast tier no regression | 75 PASS / 0 FAIL (9 sections) |

## Manual Checks

| Check | Result | Notes |
|---|---|---|
| B1 service-account branch == sibling | PASS | byte-identical to dmc-approvals.py form |
| B2 rejects `..` segments only, not absolute | PASS | segment-split; absolute refs still resolve; delegation A3/A7/A8 green |
| C1 broadened denylist, no over-block | PASS | verb+secret-operand anchor; AC4 deny 8/8, allow 8/8 |
| C1 L0 floors byte-UNCHANGED | PASS | single-hunk diff; rm-rf/catastrophic/git-apply/patch floors outside the hunk |
| C2 redaction in all THREE copies, identical | PASS | evidence-log.sh sed == _m65common.sh sed byte-identical; codex copy re-equivalent; m65 C3 green |
| A3 fail-closed branch present | PASS | detector exit ∉ {0,4} → dmc run block (sticky BLOCKED marker) |
| D4 KEPT `--check` (not removed) | PASS | retained + documented as default-mirror alias; mirror-check green |
| D7 bin/dmc legacy cd | PASS | cd to repo root in the legacy dispatch; single +1 line |
| E2 CF3 grep scans .harness/schemas | PASS | path appended; zero forbidden model literals there → no CI regression |
| F7 m6/m65/m7/m8 promoted to BLOCKING | PASS | four discrete blocking steps before the advisory --all; advisory tail unchanged |
| F8 dead adapters/codex/*.sh glob dropped | PASS | removed from bash -n list (dir has only .py) |
| E4/F1×5/F2/F6/G2 docs+gitignore | PASS | session_binding reworded; "arrives in M6"→"since M6" ×5; CODEX_ADAPTER reframed; title tag dropped; secret-class .gitignore block added |
| G1 installer AGENTS= + manifest +1 | PASS | release-auditor.md shipped; manifest diff = +1; m8 manifest-drift green |
| Frozen surface untouched | PASS | no bin/lib/dmc-v0.*, no .before-dmc, no schema contract in the diff |

## Scope Review

Result: PASS. `git diff --name-only HEAD` equals the scope.lock edit-grant source set exactly (19
tracked files) — no changed-but-unlisted file, no out-of-scope file. Bounds respected (+142/−27
under 3000/300; 19 ≤ 21). No frozen-surface, `.before-dmc`, or schema-contract file in the diff.
Every hunk traces to a specific gated audit finding; the two mandatory critic advisories are
honored in-diff (A1 3-copy redaction lockstep; A2 `--check` kept as an alias, never removed).

## Package / Env / Migration Review

- Package files changed: no — no dependency manifest/lockfile in the diff. INSTALL_MANIFEST.md and
  roles.json are ship-surface/config, not dependency manifests.
- Env files changed: no — the `.gitignore` additions are ignore PATTERNS; no actual environment
  file was read, added, or modified. No secret was read or exposed at any point.
- Migration files changed: no.

## Unresolved Risks

- AC3 (committed-replica `selftest --all` = 802/3/3 EXACT): a committed clone in `/tmp` reproduces
  801/4, and a PRISTINE HEAD clone (no audit changes) reproduces the SAME 801/4 — the single extra
  FAIL is `dmc-v0.3.2 AC4` (a routed-vs-direct `cmp` parity that is clone-environment-sensitive, the
  same macOS-dev-pinned-baseline class documented at M9 Carry-forward 14), NOT a regression from
  this change (delta vs pristine clone = 0). The DEFINITIVE frozen-baseline proof is the LIVE
  post-commit `selftest --all` on the real dev tree (M9 pattern), recorded in the build evidence.
- AC5 (CI green post-push): a future GitHub Actions outcome. The F7 change promotes m6/m65/m7/m8 to
  blocking; each is green locally. Workflow-file-only fix-forward authority applies if a runner
  surprise appears.

## Final Status

PASS — every fix present and matching its audit finding; diff ⊆ scope with bounds respected; the L0
catastrophic/git-apply floors byte-unchanged; C1 empirically proven (deny 8/8, allow 8/8, no
over-block); C2 redaction identical across all three copies; delegation 43/0, m6 104/0, m7 85/0,
m8 manifest-drift green, m65 35/0 (C3 parity), mirror-check green, linkcheck clean, default 75/0.
The committed-replica extra-FAIL is a clone-environment artifact (delta vs pristine = 0); the live
post-commit `--all` is the frozen-baseline proof of record. AC5 (CI-green) is the post-push criterion.
