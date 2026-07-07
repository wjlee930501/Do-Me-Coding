# SESSION LOG — 2026-07-06/07 · dmc-v1-runtime-upgrade (M6.5 + M8)

Branch: `claude/dmc-v1-runtime-upgrade-c5uch1` · milestone `HEAD` == `origin` == `39c420e`
(pushed, fast-forward, no force; the handoff-rev-6 docs commit follows) · `main` untouched.

**One-line summary:** ONE session closed TWO milestones. M6.5: deferred critic pass (r1 REJECT →
Rev 2 → r2 APPROVE) → human gate → spike (B4 STOP: hook firing/envelopes UNPROVABLE-TURN-FREE at
codex-cli 0.132.0) → human gate chose **Option A (advisory shims)** → build → r3 sign-off +
verifier ACCEPT → `40ad75a`+`8a97e43`, closed at live `--all` 802/3/3. Then M8: plan authored →
critic r1 REJECT(5) → Rev 2 → r2 REJECT(new B6 `.codex` provenance) → Rev 3 (receipt+sentinel) →
r3 APPROVE → human gate (A1/A2/A3 dispositions; A3 MANDATORY) → parallel build T013.1–.5 →
r4 build sign-off APPROVE + verifier ACCEPT (both replicas 802/3/3 EXACT) → `39c420e`, closed at
live `--all` 802/3/3 EXACT + doctor 24/0 + m8-suite 126/0, post-commit crosscheck ACCEPT +
stop-gate STOP-PASS.

> Reconstruction aid only. Canonical resume doc: `.harness/plans/dmc-v1-runtime-upgrade-handoff.md`
> (rev 5). Full M6.5 reports: `.harness/verification/dmc-v1-m6.5-codex-adapter.md`,
> `.harness/verification/dmc-run-8fef31d58eee.md`, `.harness/evidence/dmc-v1-m6.5-build-20260707.md`.

## 1. What shipped

- `40ad75a` — spike phase (9 files, +853/−72): plan Rev 2 (blockers B1–B4 + advisories A1/A3/A4
  closed; tasks renumbered DMC-T011b.1–.5) + approval records (both plans) + handoff CF8 rename
  record + critic verdicts r1/r2 + spike findings + B4 STOP artifact with the recorded Option A
  decision + spike-run verification report (crosscheck ACCEPT post-commit).
- `8a97e43` — build (25 files, +3783/−5): adapters/codex ADVISORY shims (4 events + common lib;
  fail-closed a–d in active; redact() parity; NO enforcement-parity claim), .codex templates,
  .agents/skills 5 workflow-skill mirrors + dmc-skills-mirror.py (one-byte drift REFUSED),
  dmc-agents-md.py + agents-md.schema.md (Unknown rule; refuse-overwrite; 32 KiB warn;
  = /dmc-init-deep), bin/dmc single-owner edit (verbs agents-md/skills-mirror; selftest sections
  agents-md 24/0 · skills-mirror 7/0 · m65-suite 119/0; fast default preserved 75/0), build
  evidence + milestone verification report (VALID · crosscheck ACCEPT · A3 degraded-invariant
  substrings) + critic r3 build sign-off APPROVE.

## 2. The verification story

Non-authoring lanes end to end: planner (Opus) authored Rev 2; critic (fresh, Opus) judged r1/r2/r3
with sha256-bound plan_hash each round; executors (Opus×3, Sonnet×1) built under two armed runs
(spike lock = 3 files; build lock = 23 entries incl. the landmark-authorized `bin/dmc` edit);
an independent verifier (Opus) re-derived every count with its own probes + its own
committed-replica `--all` (802/3/3 EXACT). Closure proof: live post-commit `--all` on `8a97e43`,
exit 0, `SELFTEST-ALL RESULT: PASS`, aggregate `tools=49 PASS=802 FAIL=3 N/A=3` == pinned baseline.

## 3. Live-fire enforcement events (guards vs the orchestrator itself)

- scope-guard **DENIED the orchestrator's own out-of-project memory write** while armed
  (deny honored; the write was deferred to post-closure, not bypassed).
- bash-radius L1 **denied `>/dev/null` and `tee`-to-scratch redirects and `cp`-to-scratch** while
  armed (replica builds switched to a tar pipe; classification probed via `dmc bash-radius --cmd`
  before acting).
- The **stop gate HELD a session stop** with no verification report; `dmc run suspend` used as the
  designed wait-state (pointer + lock stay armed over working executors).
- **verify-crosscheck REFUSED** the spike-run report until (a) the Run ID line was the bare token,
  (b) prose bullets left Changed Files, and (c) the phase commit cleared pre-run tracked edits —
  then ACCEPT. The gate shaped the record; the record was never shaped around the gate.

## 4. Process learnings / corrections (honest)

- A `tail -40` pipe on the first live `--all` discarded the aggregate proof lines — re-ran with
  full capture; the closure numbers are from the second, fully-logged run.
- A transient API outage killed both build executors mid-flight; both were resumed via mailbox
  with context intact (T011b.2 reconciled its 3 partial files; T011b.3 restarted clean).
- The m65-suite wiring instruction initially didn't land (agent idled without executing);
  re-instructed and then verified empirically — file-state, not agent claims, was the arbiter.
- The B2 fail-closed mandate vs byte-parity-on-malformed clause conflict was resolved by the build
  toward FAIL-CLOSED, disclosed, fixture-proven (D11–D15), and ratified by critic r3's adjudication.
- User directive adopted mid-session: all subagents now spawn with permission mode `auto`
  (bash prompts suppressed); DMC Ring-0 guards enforce independently of harness permission mode.

## 4b. M8 addendum (same session, after the rev-5 handoff commit)

- **Cycle**: plan authored (planner lane) → critic r1 REJECT (5 blockers: unpinned detector regex ·
  invalid `.gitignore` HTML markers · self-contradictory doctor honesty grep · undefined `.codex`
  collision · manifest deletion loophole) → Rev 2 → r2 REJECT (B1–B5 confirmed closed; NEW B6:
  `.codex` created-only removal unimplementable without provenance under install→install→uninstall)
  → Rev 3 (host-side receipt `.harness/install-receipt.json` + sentinel `# DMC-CREATED`) →
  r3 APPROVE → human gate (advisory dispositions A1 fallback / A2 porcelain hedge / **A3
  sentinel-never-gitignored MANDATORY**) → T013.1/.2/.3 built in PARALLEL (installer+manifest ·
  uninstaller · doctor+P20+bin/dmc — pinned byte contracts kept the writer/stripper lanes
  coherent) → T013.4 five-fixture suite 126/0 (zero real defects found in .1–.3) → T013.5
  evidence/verification (replica `--all` 802/3/3; honest pre-commit crosscheck REFUSE recorded
  verbatim) → r4 build sign-off APPROVE + independent verifier ACCEPT (own replica 802/3/3;
  5 advisories) → commit gate → `39c420e` → live `--all` closure proof + post-commit crosscheck
  ACCEPT + stop-gate STOP-PASS.
- **Live-fire this cycle**: bash-radius fail-closed BLOCKED an unparseable heredoc (verdict
  persisted via the exempt Write path instead — guard honored, not fought); `tee`/`>`-to-scratch
  denials continued to shape replica technique (tar-pipe + in-replica commit, .git INCLUDED after
  a `not a tree object` lesson).
- **Notable engineering outcomes**: hosts finally receive Ring-0 (`bin/`) — the audited
  "hosts get v0.1.3 forever" defect class is closed; install→uninstall is byte-clean on five host
  shapes; `.codex` provenance survives re-install; `dmc doctor` operationalizes the M6.5 honesty
  split (Claude PROVEN by synthetic-event probe / Codex ADVISORY, grep-enforced).

## 5. Next-session start checklist (copy-pasteable)

```bash
# 1. sync
git fetch origin claude/dmc-v1-runtime-upgrade-c5uch1
git checkout claude/dmc-v1-runtime-upgrade-c5uch1
git log --oneline -3        # expect the handoff-rev-6 docs commit atop 39c420e

# 2. sanity (fast)
bin/dmc selftest            # expect 9 sections, 75 PASS / 0 FAIL, exit 0 (unchanged by M6.5/M8)
bin/dmc selftest m8-suite   # expect 126/0 (roundtrip 83 + idempotency 17 + negcontrols 16 + drift 10)
bin/dmc doctor              # host self-check: Claude PROVEN / Codex ADVISORY / OMC passive advice
```

3. Read, in order: handoff (rev 6) → this log → master plan Rev 3 §M7 (DMC-T012, protected
   surface) → `.claude/hooks/worker-result-check.py` + `worker-context-guard.sh` (the surface M7
   hardens) → `docs/DMC_DELEGATION_HARNESS.md` pointers.
4. **Next action (single): author the M7 milestone plan** (worker/delegation hardening) →
   `dmc validate plan` → critic pass (HEAVY rotation — protected surface, M6-grade) → wjlee human
   gate. Remaining order: M7 → M9 → M10.
5. M7 must-carry constraints: protected-surface tag (worker validators under `.claude/hooks/`);
   M7 regenerates the INSTALL_MANIFEST worker-validator entries via `dmc-install.sh
   --emit-manifest` re-run + post-M7 drift re-run (M8's generator is list-driven — expected
   re-run, recorded); do not double-touch the M8 installer surface beyond that; provider
   adapters/router stay never-edit; task IDs sub-numbered under DMC-T012 (grep first); M9
   afterward makes the pre-commit/CI gate real (the Codex enforcement boundary under Option A).

## 6. Open / deferred register

- Worker-Bridge expansion · P5 real-repo A/B benchmark — deferred, re-entry post-M9 (unchanged).
- M6.5 advisories (carry-forward #10 in handoff rev 5): Edit-path redact wording/fixture;
  `_FLOORS` parity-fixture maintenance coupling; pre-commit/CI gate documented-only until M9;
  Option B available; hooks.json shape + tool_input field names unproven at 0.132.0.
- M6 residuals (carry-forward #11) — unchanged from rev 4.
