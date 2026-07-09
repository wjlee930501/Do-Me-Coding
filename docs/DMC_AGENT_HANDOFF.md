# DMC Agent Handoff

A one-page quick-card for resuming the DMC milestone loop safely. Read this with `DMC_OPERATOR_HANDBOOK.md`.

> **Canonical role taxonomy: `orchestration/roles.json`** (the P14 `dmc.roles.v1` registry) is the
> single machine-readable home for the DMC orchestration roles and capability classes. The role and
> template descriptions in this quick-card are **derived / legacy reference** kept for narrative
> context; if they ever disagree with the registry, the registry wins. Validate it with
> `bin/dmc roles validate`. This banner is additive — the state machine, gate rules, and prompt
> templates below are unchanged.

## Resume quick-card — the state machine

```
DRAFT → CRITIC → APPROVED → START-WORK → VERIFY → STAGE → COMMIT → PUSH → CLOSURE
```

| State | Entry criteria | Exit criteria | Gated? |
|---|---|---|---|
| DRAFT | a task/intent | plan file written, `Approval Status: DRAFT` | no |
| CRITIC | a DRAFT plan | verdict PASS or REVISE (revise loops back) | no |
| APPROVED | critic PASS | human flips `Approval Status: APPROVED` | **yes** |
| START-WORK | APPROVED plan | in-scope files written; run state set | no (within scope) |
| VERIFY | implementation | verification harness/report PASS | no (mock/offline) |
| STAGE | VERIFY PASS | only approved files staged; reviews printed | **yes** |
| COMMIT | staged + reviewed | exact-message commit, clean boundary | **yes** |
| PUSH | commit | `HEAD == origin/main` | **yes** |
| CLOSURE | push | `docs/MILESTONES.md` entry recorded | **yes** (docs commit) |

## Current-gate confirmation rule (read before any gated action)

- On resume, **re-confirm the current gate was actually granted by the human** before taking any gated action.
- **Never infer a gate** from run-state, a previous message, or partially-completed work. An in-progress run is not
  consent to flip approval, stage, commit, push, force-operate, publish, or make a live call.
- If you cannot point to an explicit human grant for the action in front of you, **stop and ask.**

## How to resume mid-loop

1. Read `.harness/runs/current-run.md` (the active run + locked scope) — for context, not for consent.
2. Re-confirm `Approval Status` in the plan; do not proceed past a gate you cannot prove was granted.
3. Re-run the verification harness before claiming any state is complete.
4. Apply the fail-closed rules; surface ambiguity instead of guessing.

## Fail-closed checklist (STOP + report)

scope ambiguous · protected-file diff · credential/secret/token exposure risk · live-call risk without a gate ·
any verification FAIL.

## Runners without subagents — degradation rule (added 2026-07-09)

- The critic and verifier lanes stay **non-authoring and fresh-context** even where subagent spawning is unavailable (Codex App, a bare CLI, a future host): run each pass as a **separate session / separate CLI invocation** whose input is only the artifact paths (the plan, the diff, the run dir) — never the authoring conversation itself.
- If a genuinely fresh, separate context cannot be obtained, **STOP at that gate and surface to the human** (fail-closed; Constitution Art. VIII escalation duty). Self-approval in the authoring context is never a fallback.
- Trajectory rule: forward-looking strategy/trajectory documents live **in the repo** (committed, with a pending-decisions banner while gates are open), never solely in out-of-repo agent memory — memory accelerates a successor; the repo is the **source of truth**.

## Anti-token-max reminder

Smallest workflow that closes the problem E2E. Do not expand scope/files/tools because they are available.

## Reusable prompt templates

Each template states inputs, the gate it serves, fail-closed conditions, and the exact outputs to print. Placeholders
are `<…>`.

### critic
- **Inputs:** `<plan-or-result path>`, focus areas.
- **Serves:** the CRITIC state (no gate; produces a verdict).
- **Do:** review adversarially; empirically verify load-bearing claims; return **PASS** or **REVISE** with critical
  issues first, required vs. optional changes separated. Critic only — no edits, no approval, no implementation.
- **Fail-closed:** if the plan is ambiguous or a claim cannot be verified, say so; do not approve.
- **Outputs:** verdict; critical findings; required changes; optional improvements; final recommendation.

### start-work
- **Inputs:** `<APPROVED plan path>`.
- **Serves:** START-WORK (autonomous within the approved scope only).
- **Do:** confirm `Approval Status: APPROVED`; write run state + locked scope; implement **only in-scope files**; run
  mock/offline verification; write evidence + report.
- **Fail-closed:** if not APPROVED, or a needed file is out of scope, or a protected file would change → STOP + report.
- **Outputs:** changed files; verification results; protected-files-unchanged proof; safe-to-stage yes/no.

### staging-review
- **Inputs:** the approved file list; the excluded-file list.
- **Serves:** STAGE (gated — requires the human's go to stage).
- **Do:** clear run state; `git add` only the approved files; print `--cached --name-only / --stat / --check`; scan for
  forbidden/excluded files; prove protected files byte-unchanged.
- **Fail-closed:** any forbidden/protected file present, or count mismatch → STOP, do not stage further.
- **Outputs:** the five review prints + a safe-to-commit yes/no.

### commit-review
- **Inputs:** the staged set; the exact commit message.
- **Serves:** COMMIT (gated).
- **Do:** print `--cached --name-only / --stat / --check`; confirm excluded files are not staged; commit with the
  **exact** message (no extra trailers); print hash, status, `show --stat HEAD`.
- **Fail-closed:** if an excluded file is staged or the staged set differs from approved → STOP, do not commit.
- **Outputs:** commit hash; post-commit status; `show --stat`.

### push-review
- **Inputs:** the local commit; the target branch.
- **Serves:** PUSH (gated).
- **Do:** print status, `log -1`, branch, ahead/behind; `git push origin <branch>` (never `--force` without a separate
  gate); confirm `HEAD == origin/main`.
- **Fail-closed:** if behind origin, or a non-fast-forward/force would be needed → STOP + report.
- **Outputs:** push result; post-push status; sync confirmation.

### milestone-closure
- **Inputs:** the shipped commit hash(es); the milestone summary.
- **Serves:** CLOSURE (gated — a separate `docs(dmc):` commit).
- **Do:** append a `docs/MILESTONES.md` entry (commit, what shipped, verification result, posture); keep it factual and
  own-words; commit separately from feature code.
- **Fail-closed:** if the milestone is not actually pushed, or facts are unverified → STOP, do not record closure.
- **Outputs:** the milestone entry; its own commit hash.

---

## Session handoff log

> **Where the rev history lives:** revs 1–13 are recorded in
> `.harness/plans/dmc-v1-runtime-upgrade-handoff.md` (session→session narrative log). Rev 14 below is
> the current session record, kept here alongside the quick-card. When they disagree on a fact, the
> machine SSoT (git, `bin/dmc selftest`, `docs/MILESTONES.md`) wins over any prose. Do NOT rewrite or
> delete prior revs — only append the next one.

### Rev 14 — public-adoption session (2026-07-09; origin/main == `aee806b`, LIVE)

**Deploy state (verified against origin, not the briefing):** `origin/main == aee806b` — every commit
below is fast-forwarded onto remote `main` (linear, no force). NOTE the *local* `main` ref is stale at
`d846f0a` (behind 9; cosmetic — `git fetch` not yet pulled into the local ref); the working branch
`claude/dmc-install-wrapper` HEAD == `aee806b` == `origin/main`. `.harness/mode == active`.

#### (A) Work shipped this session — with verified shas

1. **Overnight envelope v1.0.2→v1.0.4** (`510f421` router whole-prompt suffix anchor · `267a65b`
   generator/classification hardening + `.codex` landmark class · `5eea17b` Codex interop/coexistence
   docs) + governance records `5d345b5` (plans, critic verdicts, verifier PASS ×3, per-cycle
   `.harness/evidence/dmc-v1.0.{2,3,4}-build-20260709.md`, handoff rev 13). Each cycle: plan → critic
   APPROVE → scoped sync executors → verifier → replica 802/3/3 EXACT. The live-tree 801/4/3 was
   root-caused to `.harness/mode=passive` standing down the ask-tier (not a defect); active/clean-clone
   = 802/3/3 EXACT.
2. **v1.0.5 — AGENTS.md generator compaction** (`1cdb357` change + `cbcfb2f` records): dedup §5
   re-inline + inventory-last reorder `[1,2,3,6,7,8,9,10,4,5]` + count-parity guard (PC1) in
   `bin/lib/dmc-agents-md.py`. Regenerated `AGENTS.md` 32,490 B → **24,126 B** (≥8 KB under the 32,768
   Codex cap); rules (§7/§9) now physically precede the inventory so a byte-cap truncation drops
   inventory, not rules. Critic r1 REJECT (physical-order-dependent fixtures) → Rev 2 in-scope fixture
   rewrite → r2 APPROVE. This closes the memo §7/§9-Q7 "AGENTS.md quick win" as a shipped standalone
   cycle. Bucket-A learning: deterministic artifact compaction with an objective metric and no
   enforcement change needs no pilot.
3. **PUBLIC BRANDING** (`139ece4`) — the repo's first public-facing surface (README was the **#1 gap**,
   previously absent): `README.md` (install-first, inviolable-loop mermaid, enforcement table,
   `/dmc-*` commands, Constitution links, real CI badge, verified commands only); `docs/index.html`
   GitHub Pages landing ("constitutional engineering", self-contained, dual-theme, no external
   assets / no AI raster art); `docs/assets/dmc-seal.svg`; `docs/.nojekyll`; MIT `LICENSE`
   (© 2026 Woojin Lee). Pages landing served from `main`/`docs` at
   **https://wjlee930501.github.io/Do-Me-Coding/**.
4. **ONE-COMMAND install wrapper** (`590a5a9` `install.sh` + `tests/install/test-install-wrapper.sh`;
   `aee806b` docs lead with `./install.sh`) — root `install.sh`: self-locates → preflight hard-requires
   `python3` (git advisory only) → delegates verbatim `"$@"` to `.claude/install/dmc-install.sh` → runs
   `bin/dmc doctor` inside the target and propagates its exit code → prints resolved `.harness/mode` +
   next steps (`set -eu`, fully quoted, no `eval`). Smoke test 25/25 (standalone, not wired into
   `bin/dmc selftest`). Built via the full dogfooded DMC loop. Preserves the per-repo-copy model — no
   registry, no network.
5. **Strategic refinement memo** `.harness/plans/dmc-refinement-diagnosis-20260709.md` — **UNTRACKED**
   (deliberately not committed; §9 decision questions pending the human gate). The direction document.

#### (B) Direction — the core problem is ADOPTION WITH PROOF (not more enforcement power)

Per the memo: DMC has optimized *internal correctness* (provable against its own 802/3/3 selftest and
gate) but has **zero product-repo evidence** that it improves real work, and its weight is now high
enough that a strict-everywhere posture risks getting it turned off. The next problem is **adoption
with proof**, not power.
- **SHIPPED this session:** one-command install (memo Option-A wrapper) — the friction-lowering
  install path.
- **DEFERRED (needs a model-shift + external-publish decision):** real-package distribution
  (pipx/PyPI native, npx, brew).
- **RECOMMENDED next strategic move (memo §6/§7, still OPEN):** a **measurement-first LITE PILOT on ONE
  product repo** (Product-A / Product-B / Product-C) + **wire the dormant `run-metrics` schema**
  (`.harness/schemas/run-metrics.schema.md` + `bin/lib/dmc-v0.5.0-run-metrics.sh` already exist — it is
  *wiring, not design*) into an append-only, out-of-band JSONL ledger. Floor stays fail-closed (secret
  protection + catastrophic-command deny + scope-lock on consequential writes); everything else goes
  advisory/fail-open and is measured; promote a check to always-on only when the numbers justify the
  friction. Explicitly rejects both "add more gates" and "make DMC light." Memo §9 decision questions
  (pilot repo, sample/duration, floor confirmation, manual-vs-auto tagging, promotion thresholds, Codex
  posture) are unanswered — the memo is untracked pending those human decisions.

#### (C) Philosophy & perspective (why this repo works the way it does)

- **The founding Constitution** (`docs/DMC_CONSTITUTION.md`, Articles I–VIII, ratified law) governs
  repo-internal process. Supremacy is governance/process ONLY — on facts the machine SSoT wins.
  Article VIII binds maintainers of ANY model tier.
- **The inviolable 6-stage loop** — plan → critic → scope → execute → verify → evidence — is the
  non-negotiable essence. The **critic is never skipped** (the 5-stage shorthand never drops it) and
  the **verifier never self-approves** (authoring and review are separate non-authoring lanes).
- **Anti-fake ethos:** *do the work, prove the work, do not fake completion.* "No verification, no
  done" binds harder as capability decreases. Anti-patchwork: no unauthorized/undisclosed masking, no
  fix without a diagnosed root cause, no out-of-scope edit, no unregistered TODO on a shipped surface.
- **Secret discipline (proven live this session):** never handle provider keys. This session **declined
  a temp-API-key offer**, and the secret-guard **blocked a `printenv` presence-check** — both honored,
  neither worked around.
- **Honest-over-impressive (proven live this session):** marketing copy was fact-checked *before*
  publish — caught an **8→9 sub-gate discrepancy** and a **fabricated MIT claim** (gated the MIT wording
  on the `LICENSE` actually being present). During the `install.sh` cycle a scary clean-clone
  **801/4/3** — a **SECOND, distinct incident, NOT the v1.0.4 `mode=passive` case in (A)** — was
  root-caused **live** to a leaked secret env var in the interactive shell poisoning
  `dmc-v0.3.2-verify.sh` **AC4** (proof: router/provider code byte-identical `main`↔branch and AC4
  failed identically on `main`; excluding the leaked var → `802/3/3` EXACT). Diagnosed to the bottom,
  never masked. *(Live-session finding; recorded in agent memory, no committed evidence file — do not
  conflate its `801/4/3` with (A)'s mode-coupling one.)*
- **Division of labor:** Fable 5 orchestrates / plans / reviews / requests gates (never implements);
  Opus 4.8 + Sonnet 5 implement, investigate, and verify in non-authoring lanes.
- **Human-gated deploys:** push is **NEVER autonomous**; never touch `main` without an explicit human
  gate. Autonomous ceiling = local commit on a dedicated branch.

#### (D) Next-task candidates (ranked-ish; all user-gated)

1. **Real-package install** — pipx/PyPI recommended (python-native, matches the runtime); npx to mirror
   LazyCodex; brew for mac. A real feature → needs the full loop. (Model-shift + external-publish call.)
2. **Social-preview / OG image** — the one place an AI-generated image helps; the *user* generates it,
   the repo just references it.
3. **GitHub repo About** — description + website = the Pages URL + topics/tags.
4. **Richer Pages sections / docs site**; optionally a **custom domain**.
5. **The measurement-first pilot + `run-metrics` wiring** (memo §6/§7) — the recommended strategic move.
6. **v1.1+ deferred register** — approval authentication; CF14 option-(a) frozen-tool portability; D1
   md5 hardening (`dmc-v0.2-verify.sh:15-17`); worker-bridge expansion; P5 benchmark; **mode-aware
   selftest expectation** (encode the passive-stand-down 801/4/3 vs active 802/3/3 coupling); the
   constitution HONEST_SCOPE line-pin refresh registered at rev 13.
7. **Local cleanup** — the leaked shell env var is transient (fixed by a fresh shell / `.harness/mode`
   is back to `active`); the uncommitted `.codex/config.toml` `model=gpt-5.5` mod and the untracked
   strategic memo are **the user's call** (revert / commit / leave). Local `main` ref is stale at
   `d846f0a` — a harmless `git fetch`/reset-to-origin fixes it.

#### (E) Resume block for the next session

- **Current remote main:** `origin/main == aee806b` (verify: `git ls-remote origin refs/heads/main`).
  Working branch `claude/dmc-install-wrapper` HEAD == `aee806b`. Local `main` ref stale at `d846f0a`
  (cosmetic).
- **`.harness/mode` state:** `active` (full enforcement).
- **LIVE (on origin/main):** repo `README.md`; GitHub Pages landing at
  **https://wjlee930501.github.io/Do-Me-Coding/**; one-command `./install.sh`; MIT `LICENSE`; v1.0.2–
  v1.0.5 enforcement/generator work; live `selftest --all` baseline 802/3/3 EXACT.
- **PENDING (not started):** the measurement-first lite pilot + `run-metrics` wiring; real-package
  distribution (pipx/PyPI/npx/brew); strategic memo §9 decision questions (memo is UNTRACKED, awaiting
  human answers).
- **Read first:** this handoff (rev 14) + `MEMORY.md` + `docs/DMC_CONSTITUTION.md` before any
  substantial change. Re-confirm every gate was actually granted by the human before any gated action.
