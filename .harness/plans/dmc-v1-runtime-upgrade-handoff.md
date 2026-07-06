# HANDOFF — dmc-v1-runtime-upgrade (session → session)

Date: 2026-07-06 (rev 4 — M6 protected-surface hardening shipped + CLOSED) · Branch: `claude/dmc-v1-runtime-upgrade-c5uch1`
Session end state: `HEAD` == `origin/claude/dmc-v1-runtime-upgrade-c5uch1` == `d721487` (pushed, fast-forward, no
force). M6 CLOSED with **both** closure proofs — (1) live `bin/dmc selftest --all` exit 0 at 802/3/3 EXACT
(originals alone still reproduce the pinned baseline), and (2) single-revert byte-identical restore (`git revert
d721487` in a scratch worktree restores `.claude/hooks/**` + `.claude/settings.json` byte-for-byte to pre-M6
`2999870` and removes the M6 additions). Worktree clean except local-only run archives/auto-logs
(`.harness/runs/**`, `.harness/evidence/dmc-run-*.md`, untracked by policy); `main` untouched
(`main` == `origin/main` == `d0edc48`).

## Resume quickstart (local)

```bash
git fetch origin claude/dmc-v1-runtime-upgrade-c5uch1
git checkout claude/dmc-v1-runtime-upgrade-c5uch1
bin/dmc selftest        # expect 9 sections, 75 PASS / 0 FAIL, exit 0 (fast default)
bin/dmc selftest --all  # ~10 min; expect legacy 802/3/3 EXACT + run-core 168/0 + loop-core 78/0
                        # + roles 19/0 + verdict-validate 16/0 + verdict-gate 9/0 + delegation 29/0
                        # + linkcheck 17/0 + m6-core 99/0 + m6-suite 104/0 + mirror (55-file)
                        # + rollback PASS + SELFTEST-ALL PASS + exit 0
bin/dmc help            # M2–M6 command surface (orient/landmarks/depsurface/radius · validate ·
                        # legacy/mirror-check/rollback-test · run · roles/verdict/delegation/linkcheck ·
                        # bash-radius/postbash-diff/verify-crosscheck/stop-gate · run block|blocked-status|unblock)
```

## Where things stand

| Milestone | State | Commit(s) | Key artifacts |
|---|---|---|---|
| M1 docs (Phase 0–4) | DONE + human-ratified | 1c139fb..cf30720 | audit / architecture / orchestration docs, plan Rev 2 |
| M2 repo intelligence | DONE (41/0) | 116db38 | bin/dmc, dmc-repo-intel.py, 4 schemas |
| M3 schemas + validators + copy-routing | DONE, pushed | `1b9a4c3` + fix `3b2d1c4` | 6 schemas, dmc-instance-validate.py, 55 bin/lib copies, selftest --all, pinned baseline 802/3/3 |
| M4 run-lifecycle core (8 primitives) | DONE, pushed | `8903a67` | 10 modules (run/scope-lock/approvals+R12/evidence+check_id/checkpoints/acceptance/verify-plan/fixloop/recovery), run-core 153/0 + loop-core 78/0 |
| M5 orchestration registry | DONE, pushed | `9ec5055` | orchestration/roles.json, 6 contract-ized agents (+release-auditor), verdict/delegation validators + verdict-gate, 3 skills bound to `dmc run start`, linkcheck, 3 docs additively pointer-ized (17 gated substrings preserved) |
| v0.5 direction re-alignment (run dmc-run-0e29d09bf3b5) | DONE, pushed | `1b276f3` | direction plan APPROVED+executed: master plan **Rev 3** (M6.5 Codex Adapter inserted; order M6→M6.5→M8→M7→M9→M10; M6 gains post-Bash diff guard + semantic verify cross-checks; Deferred register: worker-bridge expansion, P5 benchmark), docs/CODEX_ADAPTER.md, DRAFT plans dmc-v1-m6-hook-hardening + dmc-v1-m6.5-codex-adapter |
| **M6 hook/guard hardening (PROTECTED SURFACE)** | **DONE, pushed** (critic r1 REJECT→r5 APPROVE · independent verifier ACCEPT · committed-replica --all 802/3/3) | `192dce6` (T011.1 fixtures) + `d721487` (T011.2–.4) | hooks→shims over Ring-0; 4 new bin/lib verdict CLIs (bash-radius L0+L1/postbash-diff/verify-crosscheck/stop-gate); Rev 3 Option A run.json-anchored tamper detection; verdict-gate REJECT arming floor; blocked.json sidecar; 5 M6 suites (m6-core 99/0 · m6-suite 104/0); adapters/claude-code/README |
| M6.5–M10 | **NOT STARTED, NOT APPROVED** (M6.5 has an authored DRAFT plan; its critic pass was deferred until M6 shipped — now unblocked) | — | master plan §Execution Tasks (Rev 3): M6.5→M8→M7→M9→M10 |

Approval state (master plan `## Approval Status`): **APPROVED M2+M3+M4+M5 (M1 retroactively ratified)** —
approver wjlee; M6 approved via its own milestone plan (initial gate + mid-run Rev 3 amendment gate).
**M6.5+ remain UNAPPROVED**; each needs its own milestone plan → critic → human gate
(M4/M5 pattern: milestone-scoped plan file, `dmc validate plan` VALID, critic APPROVE, approval record in both plans).
No active run: `.harness/runs/current-*` cleared after M6 closure; per-milestone run archives are local-only.
**M6 wired Ring-0 into the live enforcement floor** — the six hooks are now shims over `bin/dmc`
verdict CLIs; scope/stop/secret enforcement is no longer advisory. `.claude/settings.json` was NOT
changed (all five hooks were already registered); new hook registrations would need a session reload.

## M6 closure evidence (compact)

Full reports: `.harness/verification/dmc-v1-m6-hook-hardening.md` + `.harness/verification/dmc-run-53553ac50a20.md`.

- **Closure proof 1 (live `--all`)** — post-commit `bin/dmc selftest --all` on the real committed tree `d721487`
  exits 0 at legacy `tools=49 / PASS=802 / FAIL=3 / N/A=3` == pinned baseline EXACTLY (the 3 accepted FAILs are
  v0.1.3 GLM-grep · v0.2.3 V5 · v0.3.2 AC5); "originals alone still reproduce 802/3/3".
- **Closure proof 2 (single-revert restore)** — in a scratch git worktree (real repo untouched) `git revert d721487`
  restores `.claude/hooks/**` + `.claude/settings.json` byte-identical to pre-M6 `2999870` and removes the M6
  additions (e.g. `bin/lib/dmc-bash-radius.py` gone). NOTE: `tests/fixtures/m6/test-rollback.sh` run in-place reads
  25/5 **by design** (its "live matches fixture" rows now compare the committed M6 shims against the pre-M6 fixtures);
  the operative proof is the scratch-worktree revert above.
- **Critic chain (advisory only, C11)** — r1 REJECT (7 blockers B1–B7, plan_hash `06cd9495`) → Rev 2 → r2 APPROVE
  (`968cd191`, intermediate) → r3 APPROVE (`45c35fe9`, gated bytes) → approval record → human-gated Rev 3 amendment →
  r4 APPROVE (`8ce3c1c3`) → r5 build sign-off;
  persisted at `.harness/evidence/dmc-v1-m6-critic-verdict-r{1,2,3,4,5-buildsignoff}.json`.
- **Independent verifier (agent m6-verifier)** — ACCEPT: 0 blocking / 4 advisory (own probes + own committed-replica `--all`).
- **Green on the committed tree** — m6-core 99/0 (bash-radius 50 · postbash-diff 25 · verify-crosscheck 13 ·
  stop-gate 11) · m6-suite 104/0 (adversarial 38 · compat 45 · e2e-ultrawork 10 · restore 11) · run-core 168/0 ·
  mirror-check green (55-file byte-equality) · fast default 75/0.
- **Human gates honored (all via AskUserQuestion, approver wjlee)** — v0.5 direction plan · M6 milestone approval +
  T011.1 fixture-commit pre-auth · mid-run Rev 3 amendment · M6 staging/commit/push.

## Working pattern that shipped M3–M5 (keep it)

Orchestrator (human-gated) + worker agents (Opus 4.8 complex / Sonnet 5 mechanical) + independent non-authoring
critic (plan stage) and verifier (build stage) + committed-replica `--all` proof + post-commit live re-run as the
closure condition. Single-owner rule for `bin/dmc` (one sub-task registers all verbs/sections). Human gates every
time for: milestone approval, staging, commit, push. Evidence/verification per milestone; verification reports must
pass `dmc validate verification`.

## Next step (critic pass + human gate first)

**M6.5 — Codex Adapter** (DRAFT plan `.harness/plans/dmc-v1-m6.5-codex-adapter.md`, schema-VALID; NOT a
protected surface). M6 shipped, so the shim interfaces are now frozen — the deferred critic pass is UNBLOCKED.
Next action: critic pass on the M6.5 plan → human gate → implement. Its Ring-0 verdict-CLI surface to bind
onto (frozen at M6 closure `d721487`): `dmc bash-radius`, `dmc postbash-diff`, `dmc verify-crosscheck`,
`dmc stop-gate quick`, `dmc run block|blocked-status|unblock`, plus the existing `dmc verdict gate`,
`dmc run start` (arming floor), and the scope-lock/adjudicate path. Spike-first —
re-prove the web-verified 2026-07-06 Codex surface on a local CLI before any build (Codex hooks are officially
"a guardrail, not a complete enforcement boundary", so the post-Bash diff guard + release gate stay load-bearing);
installer/`--host` generation stays in M8. Design authority: `docs/CODEX_ADAPTER.md`. Execution order (Rev 3):
M6 → M6.5 → M8 → M7 → M9 → M10.

## Carry-forwards (do not lose)

1. 3 pinned upstream FAILs (v0.1.3 "GLM/worker code found" · v0.2.3 "V5 mock" · v0.3.2 "AC5") are HUMAN-ACCEPTED
   baseline (802/3/3); never "fix" or mask them inside another milestone — separate hygiene plan if ever.
2. M9 release gate MUST resolve approval `verification_ref` → artifact (M4's gate is presence-only by design;
   the honest-scope note is recorded in dmc-v1-m4 evidence + verification).
3. M9 CI model-name grep must scope to `orchestration/ .claude/agents/` or exempt `bin/lib/dmc-roles.py`
   (it legitimately carries detector patterns).
4. linkcheck covers machine-consumable refs only (code-span verbs / path literals / `Role:` bindings) —
   documented judgment call; prose-embedded dangling refs are unchecked.
5. verdict-gate is value-blind (C11): a plan-bound REJECT passes the *gate*; content judgment is the human's.
   **RESOLVED at M6** — `dmc run start` now adds a value floor (RUN-VERDICT-REJECT rc=3) that refuses to *arm a run*
   on a plan-bound critic REJECT (NEEDS_CLARIFICATION still arms); this only ADDS a floor, never opens the gate (C11 intact).
6. Auto-log local-only policy stands: `.harness/evidence/*.md` deliberate deliverables are committed;
   run archives under `.harness/runs/` stay local.
7. The two working-tree-drift legacy checks (v0.5.9 AC13 / v0.6.0 V15) FAIL `--all` whenever tracked files are
   modified uncommitted — expected artifact class; the committed-replica proof + post-commit re-run is the pattern.
8. Task-ID namespaces collide across plans (master §M6.5 `DMC-T011b` vs M6-plan `DMC-T011b`; M6.5-plan
   `DMC-T012a–e` vs master §M7 `DMC-T012`) — validators accept per-plan namespaces; renumber at the M6/M6.5
   critic passes (verifier advisory finding 6).
9. Critic R2 verdict for the direction plan binds the PRE-approval Rev 2 bytes (plan_hash `277ee35d…`); the
   current file hashes `a85c12db…` because the approval record was appended after — a naive re-hash "fails" by
   design; the chain (R2 → approval citing 277ee35d → run.json binding a85c12db) is documented in
   `.harness/verification/dmc-run-0e29d09bf3b5.md`.
10. **M6 residuals (disclosed, verifier-confirmed real, NONE blocking; verifier ACCEPT flagged 4 as advisory):**
    (a) a broad `Grep` with no path can still read secret-file CONTENTS in a non-secret dir (pre-M6 residual,
    unchanged by M6); (b) run-id-armed-without-lock window — the stop gate arms on current-run-id but the write
    guards need the compiled `scope.lock`, so edits between `run start` and scope-compile fall to the legacy path;
    (c) evidence-log "run is now BLOCKED" wording over-claims if the marker write fails (the stop gate fail-closes
    independently, so enforcement is intact); (d) `.claude/settings.json` registration unchanged ⇒ any NEW hook
    registration needs a session reload; (e) the operative snapshot is pinned-not-recaptured by design and the
    bash-radius deny-message enumerates 4 basenames though `snapshot.txt` is enforced (cosmetic).

## Branch commit log (oldest → newest, all beyond `main` @ `d0edc48`)

1. `1c139fb`..`cf30720` — M1/M2 + cloud handoff (see git log)
2. `1b9a4c3` — M3: 6 schemas, instance validators, legacy copy-routing (74 files)
3. `3b2d1c4` — M3 follow-up fix: hermetic self-tests + evidence transcript refresh
4. `8903a67` — M4: run-lifecycle core, 8 primitives (25 files)
5. `9ec5055` — M5: orchestration registry, agents, validators, skill bindings, linkcheck (35 files)
6. `1c672a0` — handoff rev 2 (M3–M5 shipped, next M6)
7. `1b276f3` — v0.5 direction re-alignment: master plan Rev 3 (M6.5 Codex Adapter), CODEX_ADAPTER design,
   M6/M6.5 DRAFT plans, direction evidence/verification (10 files, +1273/−11)
8. `2999870` — handoff rev 3 (direction shipped, next M6 critic pass)
9. `192dce6` — M6 T011.1 pre-M6 hook-tree byte fixtures + rollback test (12 files)
10. `d721487` — M6 T011.2–.4: hooks→shims, 4 Ring-0 verdict CLIs, Rev 3 Option A tamper detection,
    5 suites, evidence + verification (28 files, +5243/−107)
