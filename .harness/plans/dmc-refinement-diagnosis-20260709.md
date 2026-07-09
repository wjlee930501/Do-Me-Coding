# DMC Refinement Diagnosis

_Strategic memo — 2026-07-09. Analysis only; no implementation. Empirical claims were fact-checked
by a read-only investigation of the tree (2026-07-09); confirmed numbers are inline below._

> **Status update (2026-07-09, post-v1.0.5 — appended by fable-core Cycle A; original analysis below is unmodified):**
> - RESOLVED-STALE: the AGENTS.md grounded facts (lines below citing 32,490 bytes / 278 B under the cap / list emitted twice) and risk #6 predate v1.0.5 (`1cdb357` + records `cbcfb2f`), which shipped the §5 dedup + inventory-last reorder + count-parity guard. `AGENTS.md` is 24,126 bytes today (8,642 B headroom under the 32,768 Codex cap). §7's "optional quick win" (Q7) is therefore ALREADY SHIPPED as a standalone cycle.
> - All other grounded facts were re-verified current on 2026-07-09: the repo-intel walk is still unbounded, run-metrics is still dormant/unwired, the installer is still full-only.
> - **The §9 decision questions remain PENDING a human gate** — tracking this memo in git does NOT answer them.
> - The 2026-07-09 ratified fable-core envelope addresses §7-1 (run-metrics wiring = Cycle D-core), risk #7 (repo-intel bounding = Cycle B), and risk #1 friction (ask-tier bypass-awareness = Cycle C) as infrastructure; pilot EXECUTION stays behind §9.

**Grounded facts (verified 2026-07-09):**
- `AGENTS.md` = **287 lines / 32,490 bytes — 278 bytes under Codex's 32,768-byte cap.** ~71% is
  landmark inventory, ~11% behavioral rules. The ~104-path landmark list is emitted **twice** (§4
  bullets + §5 line 226 re-inlines it as one 8.5 KB line) — that duplicate is what pushes it to the
  cliff. Generator: `bin/lib/dmc-agents-md.py` inlines the list; it does not externalize.
- Repo-intel scan (`bin/lib/dmc-repo-intel.py`, `os.walk`) has a **fixed** skip set
  (`.git/node_modules/__pycache__/.venv/venv/dist/build/...`) — misses `target/ out/ .next/
  coverage/ vendor/`, does not read `.gitignore`, and has **no timeout and no file cap**. The
  git-based post-Bash diff guards do have 10–30 s timeouts but no ignore list of their own.
- **No product-work outcome telemetry exists** — BUT a dormant, unwired `v0.5.0 run-metrics` schema
  (`.harness/schemas/run-metrics.schema.md` + validator `bin/lib/dmc-v0.5.0-run-metrics.sh`) already
  defines the outcome fields (`wall_clock_sec`, `files_touched`, `tests_run/passed/failed`,
  `retry_count`, `human_gates`, `blockers`, `outcome ∈ {completed,blocked,abandoned,partial}`).
  Nothing observes a run or appends a ledger. So the measurement milestone is **wiring, not design.**
- Installer (`.claude/install/dmc-install.sh`) is **full-only** (~120+ files, merges into up to 4
  host files); **no lite/partial/profile path**. Only enforcement axis is `active/passive/off`; a
  per-run `effort ∈ {light,standard,deep,adversarial}` selector exists (natural hook for
  "deep-only ceremony").

## 1. Current Situation

DMC started as a Claude-Code-first execution harness aimed at one failure: agents claiming a job is
done when it is not (fake completion, scope creep, Bash-mediated writes, unverified changes). It has
grown into a three-ring system: a deterministic control plane (`bin/dmc`, `bin/lib/*`, `.harness`
schemas/state), host adapters (Claude Code + Codex), and model guidance (`CLAUDE.md`, `AGENTS.md`,
skills, agent prompts). It now has scope locking, post-Bash diff detection, verification crosscheck,
a stop gate, evidence receipts, a release gate, a CI boundary, an installer, a doctor, a
worker/delegation review chain, a written constitution, and release discipline.

That is real strength: the enforcement floor is deterministic, the core loop
(plan→critic→scope→execute→verify→evidence) is non-negotiable, and nothing grades its own homework.

It is also the source of the risk. DMC has optimized **internal correctness** — provable against its
own 802/3/3 selftest and its own gate — but has **zero evidence** that it improves real product-repo
work, and its weight is now high enough that a strict-everywhere posture will get it turned off. The
system is validated against itself, not against the job.

## 2. Core Problem

**The next problem is not power — it is adoption with proof.** DMC must show, with hard-to-fake
measurement, that it improves real work in a product repo (Product-A / Product-B / Product-C) at a
friction level low enough that a busy engineer leaves it on — before it adds one more gate.

## 3. Risk Register

Ordered by how directly each one leads to DMC being bypassed, turned off, or causing harm.

| # | Risk | Severity | Why it matters in Product-A / Product-B / Product-C | Signal it is happening | Mitigation |
|---|------|----------|-----------------------------------------------|------------------------|------------|
| 1 | **Product-repo friction / false-block** (over-governance + false positives) | **Critical** | A messy mid-refactor state in Product-A trips scope-lock or the stop gate; the engineer can't ship a hotfix; one bad block and DMC gets set to `off` permanently — all value lost | Manual overrides; `.harness/mode` flipped to off/passive by hand; "just turn it off" moments; tasks slower with DMC than without | Deep-task-only ceremony; **fail-open advisory** for heuristic checks in host repos; hard floor stays fail-closed; measure false-block rate |
| 2 | **Measurement gap / no ROI proof** | **Critical** | You cannot justify any friction on Product-B work if you can't answer "did DMC reduce failed attempts / diff bloat / regressions?" — without data, abandonment is rational | Nobody can point to a number showing DMC helped; decisions made on vibes | Measurement-first pilot; out-of-band outcome log before any new gate |
| 3 | **Codex honesty** | **High** | If docs imply Codex hook dispatch is a real boundary when the App host doesn't reliably dispatch project hooks, you will trust a boundary that isn't there on Codex-driven Product-C work | Docs assert host-level guarantees for Codex without a dated per-host proof | Keep the honest posture; CI + release gate are the real cross-host boundary; per-host proof required before any stronger claim |
| 4 | **Over-governance / ceremony cost** | **High** | Constitution + full 6-stage loop on a two-line fix in Product-B is pure tax; correct-but-slow gets routed around | A trivial change requires plan+critic+scope+evidence; you stop reaching for DMC on small work | Deep-only ceremony; lite host profile; core loop scales down for small diffs |
| 5 | **False-green (regression to prompt pack)** | **High** | This is the original disease. Go too light and an agent "finishes" a Product-A auth change with no verification and no evidence | Completion claimed with no evidence receipt; verify step skipped | verify + evidence stay non-negotiable in core; in lite, at minimum an advisory nudge that is itself measured |
| 6 | **AGENTS.md bloat** | **High (confirmed)** | Codex leans on AGENTS.md; it is already **287 lines / 32,490 B — 278 B under the 32,768 cap**, ~71% inventory / ~11% rules, with the landmark path list printed **twice**. One more repo, one more landmark, and Codex truncation eats the operating rules on Product-C | At the byte cap now; behavioral rules buried below 200+ lines of paths | De-duplicate §4/§5 (the list is emitted twice); externalize inventory to a separate generated artifact; keep AGENTS.md compact & behavior-first. Cheap, pilot-independent |
| 7 | **Timeout / scale on big or messy repos (confirmed)** | **Medium-High** | Repo-intel `os.walk` has a fixed skip set (misses `target/ out/ .next/ coverage/ vendor/`), reads no `.gitignore`, and has **no timeout / no file cap** — on a 10k-file Product-A tree it walks unbounded and feeds the AGENTS.md bloat; the git diff guards time out (10–30 s) rather than bound partial scans | Slow `dmc orient`/`agents-md`; guard timeouts; generated dirs in the landmark list | `.gitignore`-aware ignore, hard timeout, max-file cap on the walk; measure on the real repo |
| 8 | **Standing-goal cost** | **Medium** | "Re-verify everything forever" is expensive and noisy; daily full re-verification of Product-C flows will burn budget and get muted | Verification runs that nobody reads; budget spent on re-proving stable things | Tier it: critical daily invariants / weekly product flows / release-time checks |
| 9 | **Trust-ledger-as-authority** | **Medium** | A model that aced easy docs tasks must never earn autonomy over auth, billing, migrations, prod config, or release in Product-C | Pass-rate used as a gate/permission, not just a routing hint | Trust ledger is a **routing signal only**, never gate authority; sensitive domains always human-gated |
| 10 | **Under-enforcement** | **Medium** | Twin of #5: strip too much and scope creep / Bash writes return | Edits outside intended scope land unnoticed | Keep scope-lock + secret/catastrophic deny as the fail-closed floor even in lite |
| 11 | **Worker-bridge distraction** | **Low-Medium** | Time spent adding providers/multi-worker is time not spent on host adoption — the actual bottleneck | Roadmap energy on worker features while no product repo uses DMC | Freeze worker expansion; it stays mock-only review-artifact until adoption is proven |
| 12 | **Cron / standing autonomy over-reach** | **Low-Medium** | Copying "heartbeat/cron autonomy" wholesale means unattended actions with no human gate — directly against AUTONOMY.md | Scheduled jobs taking mutating/push actions without a gate | Autonomy stays human-gated; any heartbeat is advisory re-verification only, opt-in, bounded |

## 4. External Lessons

Principle throughout: **learn suggestions, encode gates. Prompt text is not the product.**

### Opus-like-Fable guide

- **Adopt** — "laws not tips", "nothing grades its own homework", "conductor/worker/verifier/
  deterministic-gate separation". DMC already embodies these (constitution + non-authoring
  critic/verifier lanes + release gate). Keep; do not dilute.
- **Adapt** — "nothing that passed once goes unwatched" (standing goals). Valuable but must be
  **tiered and measured**, not always-on-everything (risk 8). Also "budget controls" — cheap and
  worth adopting as a real primitive.
- **Adapt, bounded** — "trust ledger". Useful as a **routing** signal; must never become gate
  authority (risk 9).
- **Defer** — cron/heartbeat re-verification loops. Only after measurement, only advisory, only
  opt-in. Do not import cron-driven autonomy now.
- **Reject** — the prompt-pack framing. DMC's moat is visible artifacts + deterministic checks, not
  a better prompt. Anything that lives only as instruction text is not a DMC feature.

### Fablize

- **Adopt** — **measurement-first promotion.** This is the centerpiece: no check goes always-on
  until measured. Directly fixes risk 2.
- **Adopt** — **deep-task-only stop gate.** Full ceremony triggers on deep/consequential tasks, not
  every edit. Directly fixes risks 1 and 4 for host repos.
- **Adopt** — **lightweight plugin UX / lite install** for host repos. The adoption enabler.
- **Adapt** — **fail-open vs fail-closed**, split by layer. The hard floor (secrets, catastrophic
  commands, scope-lock writes) stays **fail-closed, non-negotiable**. Heuristic/advisory checks
  (diff-size nudges, verification reminders) go **fail-open** in host repos so a false positive
  never blocks legitimate work. This split is the single most important design decision.
- **Adapt** — out-of-band outcome tracking → this IS the measurement layer. Adopt the tracking;
  keep it lightweight.
- **Defer** — the elaborate goals/stories framework. Take the measurement, leave the ceremony.
- **Reject (as a model for DMC)** — Fablize's overall lightness as an end state. DMC's Ring-0
  control plane, scope lock, diff guard, verification crosscheck, release gate, and CI boundary are
  the reason it exists; going light everywhere throws away the moat (risks 5, 10). Fablize is
  correct **pressure**, not a **template**.

## 5. Strategic Options

**Option A — Harden internal enforcement further** (more gates, more constitution).
- Optimizes: internal correctness / completeness of the DMC repo itself.
- Risks: over-governance, still zero product ROI, accelerates bypass.
- Validated by: nothing external — only self-consistency.
- Killed by: any host-repo friction data at all. **Reject as next step.**

**Option B — Go light toward a Fablize-like prompt pack.**
- Optimizes: adoption, low friction.
- Risks: under-enforcement, regression to the exact fake-completion problem DMC exists to solve.
- Validated by: adoption numbers.
- Killed by: return of scope creep / unverified completion. **Reject — discards the moat.**

**Option C — Measurement-first lite pilot on ONE product repo. (RECOMMENDED)**
- Optimizes: real evidence + adoption at low risk. Hard floor stays fail-closed; everything else is
  advisory and instrumented.
- Risks: pilot shows no measurable benefit (which is itself a valuable, cheap answer).
- Validated by: measured drop in failed attempts / diff bloat / regressions / human interventions,
  with a low false-block rate.
- Killed by: no measurable improvement, or unacceptable false blocks even in advisory mode.

**Option D — Codex adapter hardening first.**
- Optimizes: Codex honesty (risk 3); establishes CI + release gate as the honest cross-host layer.
- Risks: solves a narrower slice than adoption; alone it doesn't produce ROI evidence.
- Best treated as a **constraint folded into C**, not a standalone thrust: the pilot repo is partly
  Codex/LazyCodex-driven, so honest Codex posture is part of the pilot, not a separate project.

## 6. Recommendation

**Option C, with D folded in as a constraint.**

Run a **measurement-first lite pilot in exactly one product repo.** Install a small footprint that
keeps the fail-closed floor (secret protection, catastrophic-command deny, scope-lock on
consequential writes) and makes everything else — the core-loop ceremony, diff nudges, verification
reminders — **advisory and fail-open**, while instrumenting real outcomes out of band. Promote any
advisory check to always-on **only** when the measurement shows it catches real problems without an
unacceptable false-block rate.

Why this is the best next step:
- It attacks the two Critical risks (friction/false-block, measurement gap) directly and attacks the
  rest as side effects.
- It cannot regress into a prompt pack: the floor stays deterministic and fail-closed.
- It produces the one thing DMC has never had — **product-repo evidence** — and it does so cheaply.
- It keeps every core invariant intact (plan/critic/scope/execute/verify/evidence/stop-continue);
  it changes only *when* the heavy stages fire and *whether* heuristic checks block or just record.
- It keeps Codex claims honest: in the pilot, CI + the release gate are the real cross-host boundary,
  and host-level Codex hook behavior is recorded, not asserted.

This is explicitly **not** "add more gates" and **not** "make DMC light." It is "prove the gates you
have are worth their friction, on real work, before touching the design again."

## 7. Smallest Next Milestone

**A measurement-only pilot on one repo, run for a bounded set of real tasks — producing a data file,
not documentation.**

Candidate artifacts (candidates, not commandments):

1. **Wire the dormant `run-metrics` schema into an append-only ledger.** The schema and validator
   already exist (`.harness/schemas/run-metrics.schema.md`, `bin/lib/dmc-v0.5.0-run-metrics.sh`)
   with the right fields; nothing observes a run or appends. The milestone is a thin recorder that
   emits one validated row per real task to an append-only JSONL ledger, out of band so it can't
   inflate its own numbers. **This is wiring, not design** — the cheapest high-value move here.
2. **A lite host profile** — a small install footprint = fail-closed floor + advisory core-loop
   nudges + the recorder. No always-on scope-lock-blocking or stop-gate-blocking; those run in
   record-only mode during the pilot. (Net-new: the installer is full-only today.)
3. **A weekly rollup** turning the ledger into the section-6b metrics.

**Optional pilot-independent quick win (gate it, don't skip the loop):** the confirmed AGENTS.md
duplicate — §4 emits the ~104-path list as bullets and §5:226 re-inlines the entire list as one
8.5 KB line, together ~71% of the doc, at the Codex byte cap. Fixing the generator to emit the list
once (and/or externalize §4) is a small, self-contained change that removes a real Codex-truncation
risk today, independent of the pilot. It is still a shipped-surface code change, so it runs through
a normal (small) plan→critic→scope→execute→verify→evidence cycle with a human gate — not a drive-by.

It must produce evidence, not prose. If the honest answer after N tasks is "no measurable benefit,"
that is a successful, cheap milestone — it saves you from over-investing.

## 6b. What to measure before promoting any gate to always-on (hard-to-fake metrics)

A gate graduates from advisory → always-on only if, over the pilot sample:

- **Catch rate**: it flagged real problems (confirmed by an independent check or a human), not noise.
- **False-block rate**: below an agreed threshold (define it *now*, section 9, to prevent post-hoc
  rationalization).
- **Diff discipline**: smaller diffs / fewer out-of-scope hunks on DMC-tagged tasks vs untagged.
- **Attempt reduction**: fewer failed attempts / retries to green.
- **Regression delta**: fewer post-merge regressions on DMC-tagged work.
- **Intervention delta**: fewer human rescues.
- **Time cost**: wall-clock overhead per task stays within an agreed budget.

Anti-fake properties: outcomes recorded out of band (not by the agent claiming success); compared
against a control (untagged tasks or pre-pilot baseline); false-block rate weighed equally with
catch rate so a gate can't "win" by blocking everything.

## 8. Non-Goals (do NOT do next)

- **Do not add new gates** to the DMC repo.
- **Do not do a full DMC install** into Product-A / Product-B / Product-C.
- **Do not expand the worker bridge** or add providers (stays mock-only review artifact).
- **Do not build cron / heartbeat autonomy.** Autonomy stays human-gated.
- **Do not claim Codex runtime parity** with Claude Code. CI + release gate remain the honest layer.
- **Do not build a matrix of 5 profiles.** At most one new thing: a pilot/lite profile. The
  `active/passive/off` mode axis already exists and is enough for enforcement intensity.
- **Do not make the trust ledger a gate authority.**
- **Do not verify-everything-daily.** Tier standing goals if/when they're built at all.
- **Do not grow the constitution** to cover the pilot. The pilot is an experiment, not law.

## 9. Decision Questions for the Human Gate

1. **Pilot repo**: which one — Product-A, Product-B, or Product-C? (Pick highest Claude-Code + Codex
   traffic × lowest blast radius. My default guess absent input: Product-B, but you decide.)
2. **Sample & duration**: how many real tasks / how many days constitute a valid pilot before we
   read the numbers?
3. **Floor confirmation**: agree the fail-closed floor in the pilot = secret protection +
   catastrophic-command deny + scope-lock on consequential writes only, and everything else is
   advisory/fail-open? (My recommendation: yes.)
4. **Outcome recording**: is manual/semi-manual tagging of outcomes acceptable to start (cheaper,
   faster), or must recording be automatic from day one (harder to fake, higher build cost)?
5. **Promotion thresholds**: what false-block rate and what catch/attempt/regression deltas would
   justify promoting a check to always-on? (Set the numbers before the pilot, not after.)
6. **Codex posture**: accept that during the pilot, CI + the release gate are the real cross-host
   boundary and Codex host-hook behavior is *recorded, not claimed*?
7. **AGENTS.md quick win**: run the generator de-dup fix now as a standalone small cycle (removes a
   confirmed at-the-cap Codex-truncation risk), or fold it into the pilot's lite-profile work?

---

_Bottom line: DMC is strong and honest internally, and unproven externally. The next move is a small,
fail-open, instrumented pilot on one real repo — evidence before more architecture. Reject both
"more gates" and "go light"; both skip the missing step, which is proof._
