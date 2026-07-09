# Build Evidence — fable-core Cycle C: ask-tier bypass-awareness (dmc-fable-core-c-asktier, v1.1.1)

Date: 2026-07-09/10 · Branch: `claude/dmc-fable-core` · Envelope: this-session AskUserQuestion
"전체 비준" (A→D-core→C→B; critic-APPROVE-conditional; LOCAL-commit ceiling; push/main a separate
human gate). Motivation: memo risk #1 (friction/false-block) — this session's OWN multi-minute
permission-prompt stalls, with zero remote-control visibility, were the live incident data.

## Chain

1. Plan Rev 1 (Fable 5, planner lane) — the envelope's "Block C 세분화" half NARROWED to
   bypass-awareness only (the frozen `dmc-v0.1.3-verify.sh:31` npm-install⇒ask pin forbids list
   changes; narrowing disclosed in the plan's User Intent + Approval Status for the human gate).
2. **Critic r1 (Opus, fresh) = APPROVE, 0 blockers**
   (`.harness/evidence/dmc-fable-core-c-critic-r1.json`) — every load-bearing claim empirically
   verified: exact-equality boundary; host-attested trust model (permission_mode is constructed by
   the host, not model-forgeable); installer PATH-COPIES the live hook (no mirror sync);
   INSTALL_MANIFEST filename-only + tests/ not enumerated (no manifest regen); G4 override recipe
   confirmed against gate-runner code. 3 optional recommendations (R1 dirty-tree `--all` note,
   R2 preamble-placement constraint, R3 json_string reuse) — all carried into the build.
3. **Run `dmc-run-ea8cac7f910b`** — `run start` + manual arming (4th cycle under the registered
   run-start defect): 3-path scope.lock (hook edit/enforcement/landmark_authorized; new test
   create/ordinary; MILESTONES edit/release/landmark_authorized; bounds 3/450/20), `--validate`
   VALID, live probes deny-rc4/allow-rc0.
4. **Executor (Opus)**: C1 `PERMISSION_MODE="$(json_get 'permission_mode')"` below the COMMAND
   extraction (md5-pinned mode preamble byte-untouched — R2 honored); C2 Block-C-branch-only
   stand-down (class derivation publish|audit-force|schema-push|migrate|install; exact
   `bypassPermissions` equality; best-effort value-blind log line; json_string systemMessage — R3
   honored; exit 0; else the byte-identical frozen ask). ONE disclosed micro-deviation:
   `2>/dev/null >> file || true` ordering (stderr silenced BEFORE the append-open so a read-only-
   dir error is swallowed) — verifier confirmed strictly correct vs the literal spec order.
   NEW `tests/install/test-ask-tier-bypass.sh` (8 cases + value-blind negctl) → **9/9**.
   Frozen replays honest: v0.1.3 = 43/2 live-tree (4 behavior rows PASS; the 2 FAILs = the
   uncommitted-hook byte-compare + the pre-existing GLM/worker row); v011 UPS parity = **39/2
   EXACT registered baseline** incl. `T009 mode-gate md5 unique=1`. Suites 0 FAIL. Surfaced (not
   silently patched): `adapters/codex/dmc_codex_common.py` mirrors Block C in Python and does NOT
   carry bypass-awareness — registered v1.2+ decision.
5. **Independent verifier (Opus, fresh) = PASS**
   (`.harness/verification/dmc-run-ea8cac7f910b.md`) — own fresh-sandbox envelope replays (bypass
   stand-down + one-line log; fail-closed ask without the field; deny floors under bypass); diff
   surgical (2 hunks; `bypassPermissions` functional equality only inside Block C); redirect-order
   deviation adjudicated correct; value-blind negctl; scope exact.
6. **Green set minted** (exec lane, disarmed; third mint of the session): receipts ×3 + coverage
   verify-plan.json + findings/goal/decision (v0.6.x validators exit 0) + approvals.jsonl (VALID).
   **Gate PASS via the G4 protected-path override** — `.claude/hooks` IS in DEFAULT_PROTECTED, so
   `DMC_GATE_PROTECTED` was set to the 9 remaining DEFAULT_PROTECTED lines (`.claude/hooks`
   dropped; string recorded verbatim in the minting report; never persisted to any file); result
   8 PASS + non-degrading landmark FLAG (`.claude/hooks/pre-tool-guard.sh`, `docs/MILESTONES.md`)
   — FLAG recorded, never suppressed. No redirect slips this round.
7. **Change commit `36cf6b3`** (3 files, +258/−0). **Clean-tree `--all` confirmation** (post-
   commit, `.codex/config.toml` stashed): `tools=49 PASS=802 FAIL=3 N/A=3` + "PASS aggregate ==
   pinned baseline exactly" + `SELFTEST-ALL RESULT: PASS`, SUITE_RC=0, zero new FAILs —
   **v0.1.3 back to its 44/1 baseline** (hook byte-compare passes post-commit; the fail-closed
   default preserved the `npm ask` row), exactly as predicted.

## Honest-posture lines (carried to the push gate)

- Live `bypassPermissions` delivery by a real bypass-mode session was NOT observed from inside
  this non-bypass session; the C2 branch is **inert-if-absent** by design. First live observation
  is a pilot follow-up, not a claim.
- The advisory log (`.harness/metrics/ask-tier-advisory.log`, gitignored) is the measurement
  surface: every stand-down is recorded (class + UTC only) so the pilot can judge whether the
  bypass stand-down was too permissive (e.g. `migrate` class) — memo §6b discipline.
- Codex-adapter Block C divergence registered (v1.2+ decision): the Python mirror still asks.
- Push-gate disclosure flag carried (memo codenames + this branch public on merge).

## Commits (LOCAL only — push is a human gate)

- `36cf6b3` feat(dmc): v1.1.1 ask-tier bypass-awareness — Block C stands down under bypassPermissions
- Records commit (this file + plan + critic r1 + verification report).
