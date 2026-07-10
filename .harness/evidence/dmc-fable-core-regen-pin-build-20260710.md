# Build Evidence — v1.1.4 committed==regen selftest pin (dmc-fable-core-regen-pin)

Date: 2026-07-10 · Branch: `claude/dmc-fable-core` · Base: `bbeb277` · **Final change commit: `f3619e9`** (+218/−2: `bin/dmc` 3/2, `docs/MILESTONES.md` 63/0, `tests/fixtures/m6.5/test-agents-md-drift.sh` 152 new).
Work ID: `dmc-fable-core-regen-pin` · Registered follow-up item 1 of the fable-core envelope · Authorization: standing envelope + user directive 2026-07-10 ("1번은 진행하자") · Autonomy ceiling: LOCAL commit; push/CI/main-FF = human gate (NOT exercised).

## What shipped

Both generated artifacts now carry a permanent committed==regenerated drift pin wired into `bin/dmc selftest` and the BLOCKING CI suites:

- **INSTALL_MANIFEST.md** — already pinned pre-cycle by `tests/fixtures/m8/test-manifest-drift.sh` (m8-suite, blocking CI); re-affirmed green (10/0), byte-untouched. The pivotal planner finding: no new manifest code was needed.
- **AGENTS.md** — the genuine gap. NEW `tests/fixtures/m6.5/test-agents-md-drift.sh` (standalone, hermetic, 9 assertions / 0 FAIL): NAME-PIN (working tree copied INCL `.git` to fixed-basename `$TMP/DMC`; generator titles line 1 by root basename — `dmc-agents-md.py:173`); positive regen==committed byte-for-byte; non-empty guard; one-byte tamper of a COPY caught; section-delete control compares REGEN OUTPUT vs the section-deleted COPY (generator re-emits all 10 sections); porcelain before/after DELTA only. Registered in `run_m65_suite` (`bin/dmc`) → auto-covered by `selftest --all`, `selftest m65-suite`, and the blocking CI m65-suite step with zero workflow edits.

## Chain (three armed runs; two honest failure records preserved; 4 critic rounds)

| Stage | Artifact / evidence |
|---|---|
| Plan (Rev 2 → 4) | `.harness/plans/dmc-fable-core-regen-pin.md` (final sha256 `d0156d70…`, Status APPROVED under the envelope) |
| Critic r1 APPROVE (2 advisories) → r2 re-bind (`0c45ea98…`) | `.harness/evidence/dmc-fable-core-regen-pin-critic-r{1,2}.json` |
| Run 1 `dmc-run-e8b6a347af41` (5-path lock, one-command `--scope-input` arming) → executor → independent verifier PASS | `.harness/verification/dmc-run-e8b6a347af41.md` |
| **Gate 1: honest FAIL — G2** `approved files not staged: AGENTS.md INSTALL_MANIFEST.md`. Root cause: `dmc-release-gate.py:387-416` builds G2's allowlist from ALL scope.lock rows; `dmc-v0.2.6-gate-check-runner.sh:47-50` requires ALL staged → defensive "regenerate-IF-drift" rows are UNSATISFIABLE staging obligations. FAIL readiness preserved | `.harness/runs/dmc-run-e8b6a347af41/release-readiness.json` (FAIL, 8/9 sub-gates PASS) |
| Rev 3 (conditional rows OUT of the lock; drift ⇒ HALT + follow-up scope) → critic r3 APPROVE (`e905ca9c…`, incl. its own r1-endorsement self-correction) | `...-critic-r3.json` |
| Run 2 `dmc-run-4b0202a2f0b7` (3-path lock) → verifier re-issue PASS → **Gate 2: PASS 9/9** | `.harness/verification/dmc-run-4b0202a2f0b7.md`, run-2 `release-readiness.json` (PASS) |
| **Post-gate replica catch (pre-push):** committed-replica `--all` at interim commit `8451cc0` in dir `replica-v114` → rc=1, sole failure = the new pin's positive assertion (`1c1 < # AGENTS.md — DMC`). Root cause `dmc-agents-md.py:173-174` (title = root basename); CI checkout `Do-Me-Coding` would have reddened the BLOCKING m65 step | plan Finding F8; run-2 report Supersession section |
| Rev 4 (in-suite NAME-PIN; generator out of scope; explicitly NOT compare-minus-line-1 / NOT clone-of-HEAD) → critic r4 APPROVE (`d0156d70…`) | `...-critic-r4.json` |
| `git reset --soft bbeb277` (governance-clean amend path for the unpushed local `8451cc0`; candidate re-staged) → Run 3 `dmc-run-af50706d0402` (3-path lock) → executor name-pin fix → verifier delta PASS (one schema re-issue: canonical `Changed Files`/`Manual Checks` restored after the exec lane caught instance-INVALID pre-gate) → **Gate 3: PASS 9/9** (landmark CLEAR — candidate baselined in arming snapshot) | `.harness/verification/dmc-run-af50706d0402.md` (VALID, `dmc.verification-instance.v1`), run-3 `release-readiness.json` (PASS) |
| Change commit | `f3619e9` |

## Final verification (AC closure)

- **AC-1 incl. rename-decoupling + AC-4 (authoritative replica leg):** fresh clone of `f3619e9` into NON-DMC-named dir `replica-v114-final` (remote severed): `selftest --all` → `aggregate: tools=49 PASS=802 FAIL=3 N/A=3` + `PASS aggregate == pinned baseline exactly` + `SELFTEST-ALL RESULT: PASS` + **overall exit 0**; drift suite inside the replica: `RESULT: 9 PASS / 0 FAIL` (name-independence proven — the interim rc=1 at `8451cc0` is resolved).
- AC-2 teeth: one-byte + section-delete negative controls PASS (non-vacuous, falsifier-backed); porcelain hermetic.
- AC-3: m8 `test-manifest-drift.sh` 10/0 re-affirmed; not edited.
- AC-5 neutrality: `agents-md --root . --stdout | diff - AGENTS.md` EMPTY; `dmc-install.sh --emit-manifest | diff - INSTALL_MANIFEST.md` EMPTY (lockstep NO-OP as planned).
- AC-6 CI: blocking `selftest m65-suite` (`dmc-ci.yml:172-173`) auto-covers the suite; `.github/` not in the diff; the name-pin is what keeps this green under CI's `Do-Me-Coding` checkout.
- AC-7: lock == staged == exactly 3; Gate 3 PASS 9/9; no G4 override; commits LOCAL only; `.codex/config.toml` unstaged throughout (stash-danced at each gate, restored).
- Metrics: final ledger row appended for `dmc-run-af50706d0402` (supersedes the premature `dmc-run-4b0202a2f0b7` row recorded pre-replica-catch; ledger is local-untracked).

## Learnings (registered for v1.1+/v1.2 consideration)

1. **G2 semantics:** every scope.lock row is a STAGING OBLIGATION, not mere authorization — defensive/conditional rows are structurally incompatible with `gate release --full`. Norm re-confirmed: locks carry actually-changed files only; conditional response = HALT + follow-up scope. (Caught by the deterministic gate after planner+critic+orchestrator all endorsed the rows — C11 defense-in-depth working.)
2. **Environment-coupling class extended:** beyond V15 tree-coupling, generated-artifact pins can couple to the CHECKOUT DIR NAME (`dmc-agents-md.py` title = root basename). Committed==regen suites must name-pin. Caught ONLY by the committed-replica leg — live-tree lanes are structurally blind (dir is named DMC locally). **Strong empirical support for system-review proposal #1 (committed-replica by default for `--all`).**
3. **Cosmetic dispatch nit:** `bin/dmc run start --help` prints the success-path UNARMED stderr WARNING without starting a run (dispatch-layer wart; no run/pointer created — verified). Candidate for a tiny v1.1+ fix.
4. Armed-guard live-fire: both worker lanes had one probe correctly DENIED (`2>/dev/null` = `>` write target) and retried clean — enforcement live; also fresh friction evidence for system-review proposal #2 (safe-sink allowlist, /dev/* tier).
5. Verification-report re-issues must re-check the canonical `dmc.verification-instance.v1` section set (`VERIF_SECTIONS`, `dmc-instance-validate.py:66-68`) — a restructure dropped two required headers; the exec lane's pre-gate validation caught it cleanly.

## Pending human gates

- `git push -u origin claude/dmc-fable-core` → CI → main FF (NOT executed; LOCAL-commit ceiling honored).
- Decisions surfaced separately: Codex adapter Block C bypass mirror (unblocked by the 5.6 research: `permission_mode` documented with the same enum incl. `bypassPermissions`); system-review 6-item register (esp. #1 committed-replica default, #2 safe-sink allowlist).
