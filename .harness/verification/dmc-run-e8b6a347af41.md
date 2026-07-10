# Verification Report

## Run ID

dmc-run-e8b6a347af41

(SUSPENDED; scope.lock armed and immutable. Independently re-verified against APPROVED plan `.harness/plans/dmc-fable-core-regen-pin.md` Rev 2; no implementer transcript trusted — every command re-run in a fresh read-only lane.)

## Plan

`.harness/plans/dmc-fable-core-regen-pin.md` — fable-core follow-up (v1.1.4): committed==regenerated selftest pins for the generated artifacts (INSTALL_MANIFEST.md + AGENTS.md). Binding chain independently verified:

- `shasum -a 256` of the plan = `0c45ea98f6c3ba1913fc3cf748963f11b9f8945796aea277ccefcbf9d6af8e49`
- == `run.json` `plan_hash` (`0c45ea98…`) ✓
- == `scope.lock.json` `plan_hash` (`0c45ea98…`) ✓
- == critic r2 `plan_hash` (`0c45ea98…`) ✓ — verdict `APPROVE`, `lenses` [correctness, scope, security], `advisory: true`, `context_provenance: "fresh"`, `blockers: []`.
- critic r1 = APPROVE (superseded by r2's hash re-bind after two advisory nits folded: F5 citation + section-delete regen-vs-copy semantics).
- scope.lock `compiled_at_head` = `bbeb27702d23892a0482127996552f393b1fddad` == current HEAD == critic r2 `repo_hash` ✓.
- Operative-snapshot integrity: computed `scope.lock.json` sha256 = `bc83911db7759d0db…` == `run.json` `operative_snapshot.scope_lock_sha256` ✓; computed `snapshot.txt` sha256 = `08f3360aa12d4ca27…` == `operative_snapshot.snapshot_sha256` ✓.

## Changed Files

- `bin/dmc` (+3/−2): `test-agents-md-drift.sh` appended to the `run_m65_suite` loop; `selftest m65-suite` usage prose names the new committed==regenerated AGENTS.md regen-drift pin. In-scope, edit / enforcement class / `landmark_authorized: true`.
- `docs/MILESTONES.md` (+63/−0, pure append): one `## v1.1.4` entry. In-scope, edit / release class / `landmark_authorized: true`.
- `tests/fixtures/m6.5/test-agents-md-drift.sh` (NEW, 130 lines, untracked): standalone hermetic AGENTS.md committed==regen drift suite. In-scope, create / ordinary.
- `AGENTS.md`, `INSTALL_MANIFEST.md`: in scope as defensive "regenerate-IF-drift" rows — NOT touched (no drift; both neutrality diffs EMPTY). Correct NO-OP per F5.

(Crosscheck note: out-of-band and correctly outside the scope.lock — `.codex/config.toml` (+4/−0) is a pre-existing working-tree model-config modification, unrelated to this cycle, unstaged, exempt. Untracked governance records `.harness/plans/dmc-fable-core-regen-pin.md` and `.harness/evidence/dmc-fable-core-regen-pin-critic-r{1,2}.json` are plan/evidence class. No stray files from verifier probes — porcelain byte-identical before vs after the entire battery.)

## Commands Run

| Command | Result | Reason | Output Summary |
|---|---|---|---|
| `bash -n bin/dmc` | PASS | syntax floor | `SYNTAX-OK` |
| `bash tests/fixtures/m6.5/test-agents-md-drift.sh` | PASS | positive byte-equality + both negative controls + porcelain hermeticity, standalone | `RESULT: 8 PASS / 0 FAIL`, exit 0 |
| `bin/dmc selftest m65-suite` | PASS | new pin wired into M6.5 group (and thereby the blocking CI step) | `test-codex-shims.sh 143/0`, `test-skills-mirror.sh 19/0`, `test-agents-md.sh 35/0`, `test-agents-md-drift.sh 8/0`; EXIT=0 |
| `bin/dmc selftest m8-suite` | PASS | INSTALL_MANIFEST committed==regen pin re-affirmed (already-existing, unedited) | `test-install-roundtrip.sh 83/0`, `test-idempotency.sh 17/0`, `test-doctor-negcontrols.sh 16/0`, `test-manifest-drift.sh 10/0` (byte-equality PASS); EXIT=0 |
| `bin/dmc selftest agents-md` | PASS | generator self-test still green | `[agents-md] 27 PASS / 0 FAIL`, EXIT=0 |
| `bin/dmc agents-md --root . --stdout \| diff - AGENTS.md` | PASS | AGENTS.md derived-artifact neutrality | `AGENTS-NEUTRAL-EMPTY rc=0` (empty diff) |
| `bash .claude/install/dmc-install.sh --emit-manifest \| diff - INSTALL_MANIFEST.md` | PASS | INSTALL_MANIFEST derived-artifact neutrality | `MANIFEST-NEUTRAL-EMPTY rc=0` (empty diff) |
| `git diff --name-only HEAD` / `--numstat` | PASS | scope + bounds | `.codex/config.toml` (exempt), `bin/dmc` (3/2), `docs/MILESTONES.md` (63/0); no frozen/pinned surface present |
| `git status --porcelain` (before vs after battery) | PASS | hermeticity-in-situ | byte-identical: same 3× ` M` + 4× `??` lines pre/post — verifier runs mutated nothing |
| read `.github/workflows/dmc-ci.yml` | PASS | CI auto-covers the pin, no workflow edit | `dmc selftest m65-suite` BLOCKING at `:172-173` (no `continue-on-error`, before the porcelain MID-sandwich); `selftest --all` ADVISORY at `:191-194`; `.github/` absent from diff |

Deliberately NOT run in this read-only lane (orchestrator/gate lane, per plan Verification Commands + prior-cycle house format): clean-tree `bin/dmc selftest --all` (the live tree is legitimately dirty with the uncommitted candidate + `.codex/config.toml`; running `--all` on a dirty tree trips the frozen v0.6.0 V15 tree-coupling and misreads 801/4/3 — a known false signal, not a regression) and `bin/dmc gate release --full` (staged-set gate). These are the post-commit / committed-replica and post-staging checks — see the AC table's PENDING rows.

## Manual Checks

| Check | Result | Notes |
|---|---|---|
| scope.lock `files[]` == exactly the 5 plan paths with correct grants | PASS | AGENTS.md + INSTALL_MANIFEST.md edit/ordinary; bin/dmc edit/enforcement/`landmark_authorized`; docs/MILESTONES.md edit/release/`landmark_authorized`; test create/ordinary |
| bounds match plan (5 files / 500 added / 60 deleted) | PASS | candidate = 3 files, ~196 added (bin/dmc 3 + MILESTONES 63 + new test 130) / 2 deleted — within 5/500/60 |
| `bin/dmc` delta is exactly the loop token + usage prose | PASS | `for s in … test-agents-md.sh test-agents-md-drift.sh;` added; usage line names the "committed==regenerated AGENTS.md regen-drift pin"; no other dispatch change |
| new suite = 5 assertions matching the plan | PASS | (1) positive `cmp -s REGEN COMMITTED`; (2) non-empty guard `[ -s COMMITTED ]`; (3) one-byte tamper of a COPY caught (regen-vs-copy FAILS, with an inert-control falsifier); (4) section-delete control compares REGEN OUTPUT vs the section-deleted COPY (critic-tightened) + a grep falsifier proving the section was really removed; (5) porcelain before/after DELTA only |
| all suite writes confined to mktemp; tracked AGENTS.md read-only | PASS | `TMP=$(mktemp -d …)`; REGEN/REGEN_ERR/TAMPERED/DROPPED all under `$TMP`; `$COMMITTED` only read by `cmp`/`sed`/`awk`; `trap cleanup EXIT` |
| suite never branches on `git status` as a pass signal (no V15 coupling) | PASS | porcelain used only as a before/after equality DELTA; comparison base is the working-tree `AGENTS.md`, not HEAD |
| header documents no sensitive reads / no network / bounded subprocess set | PASS | lines 31-32: "Never reads .env / credentials", "no network / live / model / API call", "no subprocess beyond bin/dmc, git status --porcelain, and coreutils in mktemp" |
| PINNED_BASELINE (`bin/lib/dmc-legacy-selftest.py`) byte-untouched | PASS | absent from `git diff --name-only` |
| no frozen `dmc-v0.*` tool, generator (`dmc-agents-md.py`, `dmc-install.sh`), `.github/`, or `tests/fixtures/m8/test-manifest-drift.sh` in the diff | PASS | frozen/pinned grep of the diff = `NONE-OF-FROZEN-OR-PINNED-IN-DIFF` |
| HEAD unchanged; nothing staged; no commit/push | PASS | HEAD `bbeb2770`; `git diff --cached --name-only` empty; verifier is read-only |

## Scope Review

Result: PASS

Notes: `git diff --name-only HEAD` = `bin/dmc` + `docs/MILESTONES.md` (tracked in-scope) plus the exempt out-of-band `.codex/config.toml`; the new test file is untracked (create grant). AGENTS.md / INSTALL_MANIFEST.md carried defensive regenerate-if-drift grants but were correctly NOT modified (no drift — F5 held, matching the E-cycle empirical precedent). Bounds honored: 3 files / ~196 added / 2 deleted, within 5/500/60. `.codex/config.toml` is not in the scope.lock and is unstaged. No G4 override present or needed (no DEFAULT_PROTECTED path in scope); `bin/dmc` enforcement-class FLAG is expected at the release gate (non-degrading), consistent with v1.1/v1.1.2/v1.1.3 precedent.

## Package / Env / Migration Review

Package files changed: no
Env files changed: no
Migration files changed: no

Notes: No dependency manifests, lockfiles, or migrations touched. No `.env`/secret file read or altered. The only non-source out-of-band file is `.codex/config.toml` (Codex tool config, pre-existing, out-of-scope, unstaged), surfaced under Changed Files, not part of this candidate.

## Acceptance Criteria Coverage

| # | Criterion | Observed Evidence | Verdict |
|---|---|---|---|
| 1 | AGENTS.md committed==regen pin wired and GREEN (positive) | `selftest m65-suite` runs `test-agents-md-drift.sh` all `0 FAIL`; assertion (1) "committed == regenerated (byte-for-byte)" PASS; `selftest agents-md` = 27/0 | MET |
| 2 | Pin has teeth (negative controls, constraint #7) | assertion (3) one-byte mutation of a COPY DETECTED (regen-vs-copy FAILS → PASS); assertion (4) regen-vs-section-deleted-COPY still FAILS → PASS (generator re-emits all sections; both the grep-removal falsifier and the cmp both PASS, so non-vacuous); assertion (5) real-repo porcelain byte-identical before/after | MET |
| 3 | INSTALL_MANIFEST committed==regen re-affirmed (already-existing) | `selftest m8-suite` green; `test-manifest-drift.sh` 10/0 with byte-equality assertion PASS (unchanged, not edited) | MET |
| 4 | Legacy 802/3/3 aggregate EXACT and UNCHANGED (no masking) | `PINNED_BASELINE` in `dmc-legacy-selftest.py` byte-untouched (absent from diff). The clean-tree `selftest --all` == `tools=49 PASS=802 FAIL=3 N/A=3` number is deferred: live tree is legitimately dirty (uncommitted candidate + `.codex/config.toml`) and `--all` on a dirty tree misreads via the V15 tree-coupling gotcha | PENDING-POST-COMMIT (orchestrator: committed-replica or post-commit clean tree with `.codex/config.toml` stashed; record in build evidence). PINNED_BASELINE-untouched portion MET |
| 5 | Derived artifacts neutral (lockstep irony) | `agents-md --root . --stdout \| diff - AGENTS.md` EMPTY (rc 0); `dmc-install.sh --emit-manifest \| diff - INSTALL_MANIFEST.md` EMPTY (rc 0) — NEITHER artifact drifted; conditional lockstep regen was a confirmed NO-OP | MET |
| 6 | CI picks up the new pin, no workflow edit | `.github/workflows/dmc-ci.yml:172-173` blocking `selftest m65-suite` invokes `run_m65_suite`, which now iterates `test-agents-md-drift.sh`; `.github/` absent from the diff | MET |
| 7 | Scope + gate + ceiling | scope.lock = exactly the 5 in-scope paths; candidate == new test + `bin/dmc` + `docs/MILESTONES.md` (AGENTS.md/INSTALL_MANIFEST untouched, no drift); bounds honored; no G4 override; nothing staged/committed/pushed. `dmc gate release --full --run-id dmc-run-e8b6a347af41` (FLAG on `bin/dmc` expected, non-degrading; no override) is the orchestrator's staged-set check | PENDING-POST-STAGING (gate is orchestrator lane). Scope + ceiling portion MET |

## Unresolved Risks

- Clean-tree `bin/dmc selftest --all` == `tools=49 PASS=802 FAIL=3 N/A=3` EXACT (AC #4) is PENDING-POST-COMMIT — it must be run as a committed-replica or on a clean post-commit tree with `.codex/config.toml` stashed (dirty-tree V15 gotcha), then recorded in the build evidence. Not run here by design (read-only verifier lane; the live tree carries the uncommitted candidate).
- `bin/dmc gate release --full --run-id dmc-run-e8b6a347af41` (AC #7) is PENDING-POST-STAGING — the staged candidate must be assembled first (G2: stage before gate), with `.codex/config.toml` left unstaged. Expected: PASS with a non-degrading enforcement-class FLAG on `bin/dmc`, no G4 override.
- Push / CI / main-FF remain a separate human gate. The standing fable-core envelope caps autonomy at LOCAL commit on `claude/dmc-fable-core`.

## Final Status

PASS — with AC #4 (`--all` 802/3/3 EXACT) marked PENDING-POST-COMMIT and AC #7 (release gate) marked PENDING-POST-STAGING, both deferred to the orchestrator lane exactly per the plan's own wording and the immediately-prior E-cycle house format. Every check available to the read-only verifier lane is GREEN; no critical verification failed. The two PENDING rows are structural (they require staging/commit the verifier must not perform), not skipped verifier obligations.
