# HANDOFF — dmc-v1-runtime-upgrade (session → session)

Date: 2026-07-07 (rev 5 — M6.5 Codex adapter shipped + CLOSED under the Option A reduced scope) ·
Branch: `claude/dmc-v1-runtime-upgrade-c5uch1`
Session end state: milestone `HEAD` == `origin` == `8a97e43` (pushed, fast-forward, no force; this
handoff lands as the following docs commit). M6.5 CLOSED: live post-commit `bin/dmc selftest --all`
on the real committed tree `8a97e43` exits 0 at legacy `tools=49 / PASS=802 / FAIL=3 / N/A=3` ==
pinned baseline EXACTLY, all new sections 0 FAIL (skills-mirror 7 · agents-md 24 · m65-suite 119 =
65+19+35), `SELFTEST-ALL RESULT: PASS`. Verification chain: critic r1 REJECT (4 blockers) → Rev 2 →
r2 APPROVE → human gate → spike B4 STOP → human gate Option A → build → critic r3 build sign-off
APPROVE → independent verifier ACCEPT (own committed-replica `--all` 802/3/3 EXACT). No M6-style
revert proof was run: M6.5 is additive (the only pre-existing file edited is `bin/dmc`, +50/−1) and
is NOT a protected surface. No active run (pointer cleared; all four run dirs archived SUSPENDED).
Worktree clean except local-only run archives/auto-logs (untracked by policy); `main` untouched
(`main` == `origin/main` == `d0edc48`). Prior state (rev 4): M6 CLOSED at `d721487` with both M6
closure proofs (live `--all` 802/3/3; single-revert restore to pre-M6 `2999870`).

## Resume quickstart (local)

```bash
git fetch origin claude/dmc-v1-runtime-upgrade-c5uch1
git checkout claude/dmc-v1-runtime-upgrade-c5uch1
bin/dmc selftest        # expect 9 sections, 75 PASS / 0 FAIL, exit 0 (fast default — unchanged by M6.5)
bin/dmc selftest --all  # ~10 min; expect legacy 802/3/3 EXACT + run-core 168/0 + loop-core 78/0
                        # + roles 19/0 + verdict-validate 16/0 + verdict-gate 9/0 + delegation 29/0
                        # + linkcheck 17/0 + m6-core 99/0 + m6-suite 104/0 + skills-mirror 7/0
                        # + agents-md 24/0 + m65-suite 119/0 (65+19+35) + mirror (55-file)
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
| **M6.5 Codex adapter (Option A advisory)** | **DONE + CLOSED, pushed** (critic r1 REJECT→r2 APPROVE · spike B4 STOP→Option A human gate · r3 build sign-off APPROVE · independent verifier ACCEPT · live `--all` 802/3/3 + all sections 0 FAIL) | `40ad75a` (spike phase) + `8a97e43` (build, 25 files +3783/−5) | spike findings + STOP/Option A record; adapters/codex ADVISORY shims (4 events + common lib); .codex templates; .agents/skills 5 workflow-skill mirrors + dmc-skills-mirror.py; dmc-agents-md.py + agents-md.schema.md (= /dmc-init-deep generator); bin/dmc verbs agents-md/skills-mirror + selftest sections agents-md/skills-mirror/m65-suite |
| M8, M7, M9, M10 | **NOT STARTED, NOT APPROVED** | — | master plan §Execution Tasks (Rev 3) remaining order: M8→M7→M9→M10 |

Approval state (master plan `## Approval Status`, updated at `40ad75a`): **APPROVED
M2+M3+M4+M5 (M1 retroactively ratified) · M6 and M6.5 each via their own milestone-scoped plans** —
approver wjlee. M6.5 carried TWO recorded human gates: the Rev 2 milestone approval (critic
r1 REJECT→r2 APPROVE chain) and the spike-STOP **Option A** reduced-scope decision (recorded in
`.harness/evidence/dmc-v1-m6.5-spike-stop.md` §Human gate decision). **M8/M7/M9/M10 remain
UNAPPROVED**; each needs its own milestone plan → critic → human gate
(pattern: milestone-scoped plan file, `dmc validate plan` VALID, critic APPROVE, approval record in both plans).
No active run: `.harness/runs/current-*` cleared after M6.5 closure; per-milestone run archives are local-only.
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

## M6.5 closure evidence (compact)

Full reports: `.harness/verification/dmc-v1-m6.5-codex-adapter.md` (milestone, VALID + crosscheck
ACCEPT) + `.harness/verification/dmc-run-8fef31d58eee.md` (spike-phase run, ACCEPT) +
`.harness/evidence/dmc-v1-m6.5-build-20260707.md` (build evidence).

- **Two runs**: `dmc-run-8fef31d58eee` (spike, T011b.1) + `dmc-run-fe05b840460e` (build, 23-entry
  scope.lock, T011b.2–.5); both archived SUSPENDED; pointer cleared at closure.
- **Spike outcome (T011b.1, codex-cli 0.132.0, NO live turn/API key)**: hook firing + decision-envelope
  honoring UNPROVABLE-TURN-FREE (no headless hook surface) ⇒ B4 STOP artifact
  `.harness/evidence/dmc-v1-m6.5-spike-stop.md` → human gate chose **Option A**: ship ADVISORY shims;
  the Codex enforcement boundary is the pre-commit/CI gate; the M6 post-Bash diff guard is the
  PRIMARY Codex safety net; NO enforcement-parity claim. CONFIRMED turn-free: skills discovery,
  trusted-project `.codex` config merge, sandbox modes, AGENTS.md discovery + 32 KiB cap;
  hooks/multi_agent/unified_exec stable+on ([SPIKE-CORRECTED] in CODEX_ADAPTER §1).
- **Critic chain (advisory only, C11)** — `.harness/evidence/dmc-v1-m6.5-critic-verdict-r{1,2,3-buildsignoff}.json`:
  r1 REJECT (B1 task-ID renumber → DMC-T011b.1–.5 · B2 fail-closed negative controls · B3 secret-redaction
  binding · B4 turn-free-proof resolution; plan_hash `9d8562bd…`) → Rev 2 → r2 APPROVE (`b02b1554…`) →
  approval record (run.json binds post-append `8a74a525…`, carry-forward-9 pattern) → r3 build
  sign-off APPROVE (0 blockers).
- **Independent verifier ACCEPT** — own probes + own committed-replica `--all` at 802/3/3 EXACT;
  0 blocking / 2 advisory (static-floor maintenance coupling; model-name scan framing).
- **Disclosed build deviations (all honest, none blocking)**: active-mode fail-closed divergence vs
  Claude fail-open on malformed input (B2 mandate; proven by parity fixtures D11–D15); B2(c) N/A for
  in-process Read/Grep/Glob secret guard; `.codex/hooks.json` wiring shape unproven at 0.132.0
  (documented advisory); MIRRORED_SKILLS = the 5 plan-named workflow skills (worker-bridge skills
  excluded by design); `tool_input` field names TBD (superset read, renamed field ⇒ fail-closed).
- **Live-fire enforcement events THIS session**: scope-guard DENIED the orchestrator's own
  out-of-project memory write mid-run; bash-radius L1 denied `>/dev/null`- and `tee`-to-scratch
  write idioms and `cp`-to-scratch during replica builds (tar-pipe used instead); the stop gate HELD
  a session stop pre-verification (suspend = the designed wait-state); verify-crosscheck REFUSED a
  prose-formatted Run ID + undeclared dirty paths until the report/commit were made honest.

## Next step (M8 — installer `--host`, per Rev 3 order M8→M7→M9→M10)

**M8 needs its own milestone plan → critic → human gate** (M4/M5/M6.5 pattern). It ships what M6.5
built: installer `--host codex|claude|both` generation of the `.codex`/`.agents` wiring + the
host-AGENTS.md generator integration. Pointers: surface the Codex `/hooks` content-hash trust step,
NEVER `--dangerously-bypass-hook-trust`; the `.codex/hooks.json` template shape is UNPROVEN at
0.132.0 (spike could not fire hooks turn-free) — the installer must present it as advisory wiring;
Option B (a one-time, human-run, consented live-turn verification under a NEW gate + own scope)
remains available to upgrade the shims from advisory to verified-enforcing. M9's release/CI gate is
now doubly load-bearing: under Option A it IS the Codex enforcement boundary (currently
documented-only) — build it real there.

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
8. Task-ID namespace collisions RESOLVED at the M6/M6.5 critic passes (verifier advisory finding 6): the M6
   plan renumbered its tasks to `DMC-T011.1–.4` (collision-free vs master §M6.5's `DMC-T011b`), and the M6.5
   plan Rev 2 renumbered `DMC-T012a–e` → `DMC-T011b.1 .. DMC-T011b.5` (sub-numbered under master §M6.5's own
   task `DMC-T011b`), removing the prefix collision with master §M7's `DMC-T012` and aligning the sub-plan to
   its own master task ID. `DMC-T011b.N` was grep-verified unused across `.harness/` and `docs/` before the
   rename. Validators still accept per-plan namespaces; these renames are for cross-plan legibility, applied
   per this carry-forward.
9. Critic R2 verdict for the direction plan binds the PRE-approval Rev 2 bytes (plan_hash `277ee35d…`); the
   current file hashes `a85c12db…` because the approval record was appended after — a naive re-hash "fails" by
   design; the chain (R2 → approval citing 277ee35d → run.json binding a85c12db) is documented in
   `.harness/verification/dmc-run-0e29d09bf3b5.md`.
10. **M6.5 residuals/advisories (disclosed, NONE blocking):** (a) critic-r3 advisory — the Codex
    PostToolUse evidence append truncates an Edit/Write `file_path` to 500 chars WITHOUT `redact()`
    (exact parity with the accepted Claude baseline `evidence-log.sh:73`); the A5 wording in the
    shim docstrings slightly over-claims the path-only deny's coverage — tighten wording and/or
    redact `file_path` + add a token-in-Edit-path fixture in a later hygiene pass; (b) verifier
    advisory — `_FLOORS` in `dmc_codex_common.py` is a faithful REPRODUCTION of the Claude shims'
    static floors, guarded against drift only by the D-series parity fixtures (maintenance
    coupling: a change to `pre-tool-guard.sh` floors must be mirrored or D-series fails); (c) the
    Codex enforcement boundary under Option A is the pre-commit/CI gate, which is currently
    DOCUMENTED-ONLY — M9 must make it real; (d) **Option B** (one-time, human-run, consented
    live-turn verification, NEW gate + own scope) remains available to upgrade the shims to
    verified-enforcing; (e) `.codex/hooks.json` wiring shape + per-tool `tool_input` field names
    remain UNPROVEN at codex-cli 0.132.0 — re-probe at the Option B turn or a newer CLI.
11. **M6 residuals (disclosed, verifier-confirmed real, NONE blocking; verifier ACCEPT flagged 4 as advisory):**
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
11. `517bac0` — handoff rev 4 + session log (M6 closed; next M6.5 critic pass)
12. `40ad75a` — M6.5 spike phase: plan Rev 2 + approval (critic r1→r2), Codex CLI spike, B4 STOP →
    Option A decision, run-8fef31d58eee verification (9 files, +853/−72)
13. `8a97e43` — M6.5 build: advisory Codex shims, skills mirrors, AGENTS.md generator, bin/dmc
    verbs/sections, evidence + verification + r3 sign-off (25 files, +3783/−5)
