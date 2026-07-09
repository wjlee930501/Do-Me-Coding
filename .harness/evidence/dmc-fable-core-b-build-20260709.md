# Build Evidence — fable-core Cycle B: repo-intel scan bounding (dmc-fable-core-b-repointel, v1.1.2)

Date: 2026-07-09 · Branch: `claude/dmc-fable-core` · Envelope: this-session AskUserQuestion
"전체 비준" (A→D-core→C→B; critic-APPROVE-conditional; LOCAL-commit ceiling; push/main a separate
human gate).

## Chain

1. Plan Rev 1 (Fable 5, planner lane) → **critic r1 (Opus, fresh) = REJECT, 2 blockers**
   (`.harness/evidence/dmc-fable-core-b-critic-r1.json`):
   - **B-1**: the zero-drift AC was unachievable — the committed `AGENTS.md` was ALREADY stale
     (missing the D-core recorder landmark; regen = 107 enforcement landmarks, committed = 106).
     An **escaped D-core lockstep** (second one, after INSTALL_MANIFEST), caught by this critic.
   - **B-2**: raw `git check-ignore` would couple output to ambient user/system git config,
     contradicting the module's documented env-independence rule.
2. **Baseline remediation (outside the plan, disclosed): commit `87e76eb`** — deterministic
   `AGENTS.md` regen (diff = the one landmark line + §5 count-parity 106→107); validation set
   green (VALID, 24,232 B, §7@653 < §4@3094, companion pointers, context-audit 7/0, m65 35/0,
   byte-identity).
3. Plan Rev 2 folded B-2 (neutralized invocation: `-c core.excludesFile=/dev/null` + subprocess
   env overriding ONLY `GIT_CONFIG_GLOBAL`/`GIT_CONFIG_SYSTEM`; disclosed `$GIT_DIR/info/exclude`
   residue; amended determinism claim; self-test case (vi) with positive control) + 4 advisories
   (generator-path Unknown disclosure; clean-tree `--all` note; `git_head :92-108` correction;
   measured ≈0.12 s replaces the wrong "3×") → **critic r2 (Opus, fresh) = APPROVE, 0 blockers**
   (`…-b-critic-r2.json`; B-2 neutralization EMPIRICALLY proven in scratch repos by the critic;
   plus the check-ignore-never-reports-tracked-files confirmation strengthening the zero-drift
   rationale). 3 residual doc nits carried as advisories (Risks-table "3×" instance; "5 new
   cases" vs 6; the literal self-test command form) — plan left hash-bound, nits carried to the
   executor prompt + this evidence.
4. **Run `dmc-run-880cb5a91f23`** — `run start` + manual arming (registered run-start defect):
   2-path scope.lock (repo-intel edit/enforcement/landmark_authorized; MILESTONES edit/release/
   landmark_authorized; bounds 2/450/40), `--validate` VALID, live probes deny-rc4/allow-rc0.
5. **Executor (Sonnet)**: baseline pre-check (drift diff empty BEFORE edit) → SKIP_DIRS
   +{target,out,.next,coverage,vendor,.omc} → `filter_ignored()` (batched `check-ignore --stdin
   -z`, neutralized env, newline-path defense, best-effort fallback with exit 0/1=success) →
   monotonic max-files/max-seconds budget, breach ⇒ `die(…,3)` naming bound+flag → CLI flags →
   docstring amendment → +7 self-test assertions (O6–O10, incl. the ambient-neutrality pair with
   positive control) → MILESTONES v1.1.2 entry. Module self-tests 17/0 · 13/0 · 8/0 · 7/0; drift
   diff empty ×3; `bin/dmc selftest` all-0-FAIL; mirror-check PASS; linkcheck clean.
6. **Independent verifier (Opus, fresh) = PASS**
   (`.harness/verification/dmc-run-880cb5a91f23.md`) — four-way plan_hash identity; live
   enforcement probes (incl. an ORGANIC denial of the verifier's own stray `2>/dev/null` — the
   guard proving itself); own mktemp probes for skip-set/caps/determinism/gitignore-retention;
   O7/O9/O10 re-run + source-read for the exclusion/neutrality halves (disclosed method); zero
   drift; scope exact.
7. **Green set minted** (exec lane, disarmed; same learning-(d) recipe as D-core): receipts ×2 +
   coverage verify-plan.json + findings/goal/decision (v0.6.x validators all exit 0) +
   approvals.jsonl (appender, VALID). First gate run honestly recorded **FAIL on gate-checks G2
   only** — the candidate was not yet staged (orchestrator sequencing; D-core had pre-staged).
   Staged the 2 files → re-gate → **PASS (8 PASS + non-degrading landmark FLAG)**. Process slip
   disclosed: one `>/dev/null` redirect used by the minting lane while disarmed (harmless,
   validators correct; discipline reiterated).
8. **Change commit `3121be7`** (2 files, +236/−10). **Clean-tree `--all` confirmation** (post-
   commit, `.codex/config.toml` stashed): `tools=49 PASS=802 FAIL=3 N/A=3` + "PASS aggregate ==
   pinned baseline exactly" + `SELFTEST-ALL RESULT: PASS`, SUITE_RC=0, **zero new FAILs** (the 5
   FAIL-pattern lines = the 3 pinned baseline tool rows + aggregate lines). No manifest-drift
   recurrence (modification-only change, manifest-neutral as planned).

## Registered learnings / open items (user-gated)

- **Escaped-lockstep pattern now has TWO instances** (INSTALL_MANIFEST caught by the m8 suite;
  AGENTS.md caught only by the NEXT cycle's critic). v1.1+ candidate strengthened: wire a
  committed==regenerated pin for BOTH generated artifacts into selftest, so the catch is
  mechanical, not luck.
- Gate sequencing note for the runbook: stage the candidate BEFORE `gate release --full` (G2
  precondition), as D-core did; B's first gate run recorded an honest FAIL for this.
- `run start` arming defect still open (manual procedure used + probe-proven, 3rd consecutive
  cycle).
- Push-gate disclosure flag carried (memo codenames public on merge).

## Commits (LOCAL only — push is a human gate)

- `3121be7` feat(dmc): v1.1.2 repo-intel scan bounding — skip-set, gitignore-aware filter, hard caps
- Records commit (this file + plan Rev 2 + critic r1/r2 + verification report).
