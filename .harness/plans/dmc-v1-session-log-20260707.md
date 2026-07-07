# SESSION LOG — 2026-07-06/07 · dmc-v1-runtime-upgrade (M6.5)

Branch: `claude/dmc-v1-runtime-upgrade-c5uch1` · milestone `HEAD` == `origin` == `8a97e43`
(pushed, fast-forward, no force; the handoff-rev-5 docs commit follows) · `main` untouched.

**One-line summary:** Ran the deferred M6.5 critic pass (r1 REJECT → Rev 2 → r2 APPROVE), got the
human milestone gate, executed the spike (B4 STOP: hook firing/envelopes UNPROVABLE-TURN-FREE at
codex-cli 0.132.0) → human gate chose **Option A (advisory shims)** → built T011b.2–.5 with
parallel executors → critic r3 build sign-off APPROVE + independent verifier ACCEPT → shipped in
two gated commits (`40ad75a` spike phase · `8a97e43` build) → CLOSED with the live post-commit
`--all` at 802/3/3 EXACT + all sections 0 FAIL.

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

## 5. Next-session start checklist (copy-pasteable)

```bash
# 1. sync
git fetch origin claude/dmc-v1-runtime-upgrade-c5uch1
git checkout claude/dmc-v1-runtime-upgrade-c5uch1
git log --oneline -3        # expect the handoff-rev-5 docs commit atop 8a97e43

# 2. sanity (fast)
bin/dmc selftest            # expect 9 sections, 75 PASS / 0 FAIL, exit 0 (unchanged by M6.5)
bin/dmc selftest m65-suite  # expect 119/0 (codex-shims 65 + skills-mirror 19 + agents-md 35)
```

3. Read, in order: handoff (rev 5) → this log → master plan Rev 3 §M8 → `docs/CODEX_ADAPTER.md`
   (incl. spike addendum) → `adapters/codex/README.md` (Option A boundary wording).
4. **Next action (single): author the M8 milestone plan** (installer `--host codex|claude|both`) →
   `dmc validate plan` → critic pass → wjlee human gate. Remaining order: M8 → M7 → M9 → M10.
5. M8 must-carry constraints: surface the Codex `/hooks` trust step (never
   `--dangerously-bypass-hook-trust`); `.codex/hooks.json` shape is UNPROVEN at 0.132.0 — installer
   presents it as advisory wiring; M9 must make the pre-commit/CI gate REAL (it is the Codex
   enforcement boundary under Option A, currently documented-only); Option B live-turn upgrade
   path stays human-gated.

## 6. Open / deferred register

- Worker-Bridge expansion · P5 real-repo A/B benchmark — deferred, re-entry post-M9 (unchanged).
- M6.5 advisories (carry-forward #10 in handoff rev 5): Edit-path redact wording/fixture;
  `_FLOORS` parity-fixture maintenance coupling; pre-commit/CI gate documented-only until M9;
  Option B available; hooks.json shape + tool_input field names unproven at 0.132.0.
- M6 residuals (carry-forward #11) — unchanged from rev 4.
