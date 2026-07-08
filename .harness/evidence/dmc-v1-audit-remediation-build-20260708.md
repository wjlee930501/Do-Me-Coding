# Build Evidence — DMC v1 Audit Remediation (2026-07-08)

Run `dmc-run-ef893d0c4857` (scope.lock 21 files, state_hash `9ffd9500`, operative_snapshot sealed).
Plan `.harness/plans/dmc-v1-audit-remediation.md` Rev 2 (plan_hash `b252f7cd…`), APPROVED (wjlee
Tier 1+2+3 scope gate + critic r1 APPROVE). Source audit: `.harness/evidence/dmc-v1-audit-20260708.md`.

## What shipped (16 fixes across 19 files)

6 synchronous scoped executors (Opus ×3 on delegation/hooks/installer, Sonnet ×3 on CI/docs/bin-dmc),
single-owner per file:

- **AR-T1** `bin/lib/dmc-delegation.py` — B1 (service-account branch, byte-identical to the 10 sibling
  tools) + B2 (`..`-segment traversal guard in `resolve_scope_lock_ref`, absolute refs preserved) +2
  self-test rows → 43/0.
- **AR-T2** (PROTECTED M6 + parity) `pre-tool-guard.sh` C1 (secret-read denylist broadened to
  cat/head/tail/grep/base64/cp/… with a REQUIRED secret operand; L0 catastrophic/git-apply floors
  byte-unchanged; `.env.example/.sample/.template` exempted), `evidence-log.sh` C2 (redaction extended:
  AWS/JWT/Slack/GitHub/Google/PEM/Authorization classes) + A3 (fail-closed on detector exit ∉{0,4} →
  `dmc run block`), and the redaction lockstep applied IDENTICALLY to `adapters/codex/dmc_codex_common.py`
  + `tests/fixtures/m6.5/_m65common.sh` (critic-A1).
- **AR-T3** `.github/workflows/dmc-ci.yml` — E2 (+.harness/schemas in CF3 grep), F8 (dropped dead
  adapters/codex/*.sh glob), F7 (m6/m65/m7/m8-suite promoted to individual BLOCKING steps; advisory
  --all tail unchanged).
- **AR-T4** roles.json E4 + 5 agent files F1 ("arrives in M6"→"enforced since M6") + CODEX_ADAPTER.md
  F2 + DMC_AGENT_HANDOFF.md F6 + `.gitignore` G2 (secret-class patterns) + dmc-legacy-selftest.py D4
  (--check KEPT as documented alias, critic-A2).
- **AR-T5** `bin/dmc` — D7 (cd to repo root in the `legacy)` dispatch).
- **AR-T6** `.claude/install/dmc-install.sh` + `INSTALL_MANIFEST.md` — G1 (ship the 6th canonical agent
  release-auditor.md; manifest +1, emitter byte-identical).

## Verification (all on the working tree, non-authoring verifier + critic r2 both concur)

| Check | Result |
|---|---|
| diff ⊆ scope | PASS — 19 tracked files == scope.lock edit set; +142/−27 (bounds 3000/300); 19 ≤ 21 |
| default selftest | 75/0 (9 sections) |
| delegation | 43/0 (+2 rows) |
| m6-suite (hooks C1/C2/A3) | 104/0 (38+45+10+11) |
| m65-suite (C3 redaction parity — A1 lockstep) | 35/0 |
| m7-suite | 85/0 |
| m8-suite (G1 manifest-drift byte-equality) | 10/0 (drift) — --emit-manifest == committed |
| m9-suite | 91/0 |
| release-gate | 39/0 |
| mirror-check (frozen legacy byte-unchanged) | PASS |
| linkcheck | clean, 24 files |
| AC4 security probes (value-blind, live guard) | C1 deny 8/8, C1 allow 8/8 (no over-block, .env.example allowed), C2 redaction 6/6 |
| critic r2 build sign-off | APPROVE, 0 blockers, 3 low advisories |
| independent verifier | Final Status PASS |

## AC3 — committed-replica `selftest --all` + the clone-environment artifact

A committed replica (HEAD clone + the 19 changes committed) run of `selftest --all` in `/tmp` reports
`aggregate: tools=49 PASS=801 FAIL=4 N/A=3` (v0.1.3, v0.2.3, v0.3.2×2). A PRISTINE HEAD clone with NO
audit changes reports the SAME `dmc-v0.3.2 = 6 PASS / 2 FAIL` — the single extra FAIL beyond the pinned
802/3/3 is `dmc-v0.3.2 AC4` (a routed-vs-direct `cmp` parity that is clone-environment-sensitive). This
is NOT a regression from this change: the delta between the pristine clone and the audit-remediation
replica is ZERO, and it is the same macOS-dev-pinned-baseline class documented at M9 Carry-forward 14
(the 802/3/3 baseline reproduces exactly only on the real dev tree, not in a `/tmp` clone). The
DEFINITIVE frozen-baseline proof is therefore the LIVE post-commit `selftest --all` on the real dev
tree (M9 closure pattern) — recorded at closure below.

## Live post-commit `selftest --all` (frozen-baseline proof of record)

_To be recorded after the human commit gate + push (M9 pattern: the real dev tree reproduces 802/3/3
EXACT; the /tmp clone does not, per the artifact above)._

## Advisories carried (non-blocking)

critic-r2 V1 (delegation traversal reason-code imprecision), V2 (evidence artifacts written
post-signoff — this file), V3 (C1 key/cert operand substring over-match — acceptable). All disclosed;
none blocking.
