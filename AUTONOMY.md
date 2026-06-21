# AUTONOMY.md — Do-Me-Coding Autonomous Development Mode (v0.4.0)

The charter for running DMC as a **conservative, safety-first autonomous development mode**. It defines the **autonomy
levels**, the allowed/blocked actions per level, and the stop conditions. It is **additive** and **does not change** any
existing behavior, hook, or schema.

## Relationship to existing modes (non-conflicting)

The **autonomy level** (this file) is **orthogonal** to the DMC **enforcement mode** in `.harness/mode`
(`active`/`passive`/`off` — see `DMC.md`):

- `.harness/mode` decides **how strictly the hooks enforce** (secret/destructive deny, scope/stop/evidence gates).
- The **autonomy level** decides **how much the agent does on its own** before a human gate.

The two compose. **The enforcement floor always applies at every autonomy level**: secret-bearing reads and
catastrophic-destructive operations are denied in all modes (`DMC.md` §Secret Protection), and the non-negotiable rules
(`DMC.md` §Non-Negotiable Rules, incl. **Rule 7 — no copied leaked prompt text**) hold regardless of level. Autonomy
**never** raises the enforcement floor or grants a human gate.

## Autonomy levels (least → most autonomous)

| level | the agent MAY (allowed) | the agent MUST NOT (blocked) |
|---|---|---|
| **passive** | observe, read non-secret files, run the read-only advisory rails (selection/manifest/review/closure/delegation) | edit any file; create branches; run tests that write; commit |
| **advisory** | + write/revise plans under `.harness/plans/`; produce critiques/proposals; emit candidates | edit product/source/protected files; stage; commit; push |
| **autonomous-dry-run** | + run the full loop against **fixtures / `$TMPDIR` only**; generate evidence | touch any tracked product file; the real repo must stay byte-unchanged; commit; push |
| **autonomous-local-commit** | + edit **approved-scope** files on a **dedicated isolated branch/worktree**; run verification; **commit locally** after tests pass | push; edit on `main`/`master` (except an approved append-only closure); touch protected surfaces beyond the approved scope; delete/modify a prior review branch |
| **human-gated-push** | nothing new autonomously — this is the **gate**, not a grant | push, live-provider-call, credential/secret access, protected-surface change beyond scope, history-rewrite/force, external-publish, closure-commit — **each requires an explicit human gate, every time** |

Every level inherits the blocks of the levels below it. The **default** level for an unattended run is
`autonomous-dry-run` (fixtures only). `autonomous-local-commit` requires an explicitly-scoped approved plan + an isolated
branch. **PUSH and CLOSURE are never autonomous** — they are always `human-gated-push`.

## Always-blocked (every level, non-negotiable)

- read/print/grep/serialize the contents of any secret-bearing file (`.env*` except `.example/.sample/.template`,
  keys/certs, credential/token files — `DMC.md` §Secret Protection).
- live provider call / network / model-API call (mock/offline only).
- `git push --force`, history rewrite, branch deletion, force operations.
- modifying a prior published milestone entry (append-only closure only) or a prior review branch.
- copying leaked/proprietary prompt text (`DMC.md` Rule 7); leak discussions are **unverified design signals only**.

## Stop conditions (fail-closed — halt the autonomous run and ask)

Halt immediately and surface to the human when any holds:

1. **dirty worktree** at run start (uncommitted tracked changes outside the approved scope).
2. **branch is `main`/`master`** and the run is not an explicitly-approved append-only closure.
3. **scope violation** — an edit/diff outside the approved file scope (incl. a deletion or broad rewrite).
4. **protected-surface diff** — a change to an adapter/router/schema/hook/guard beyond an authorized, planned edit.
5. **secret / credential / token exposure risk** — a secret-bearing path is read, or a secret-shaped value would be
   emitted.
6. **live-call / network risk** — any code path would reach a live provider or the network.
7. **verification FAIL** — a self-test/verification harness does not pass.
8. **ambiguity** — the goal, scope, or acceptance criteria are unclear (do not guess — `AGENTS.md` Rule 7).
9. **over-eager signal** — touched-file count, deletion count, or diff size exceeds the plan's declared bound.

A stop condition is **fail-closed**: when uncertain, stop. Static/diff/evidence guards (v0.4.2–v0.4.5) enforce these
mechanically — **prompt discipline alone is not relied upon.**

## Provenance & design signals

DMC's autonomous mode is informed by **labeled, unverified design signals only** — tool-schema rigor, explicit
verification rules, incident-driven safety rails, and clear source/provenance labeling (general patterns), and
project-memory / planning / verified-completion harness ideas. **No leaked or proprietary prompt text is copied**
(`DMC.md` Rule 7). Claude Code hooks/subagents/plugins are **interoperability targets, not runtime dependencies**
(see v0.4.8).

## Machine-readable

The autonomy levels + stop conditions are mirrored for tooling at `.harness/schemas/autonomy.schema.md`.
