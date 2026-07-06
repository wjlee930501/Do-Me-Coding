# Plan: DMC v1.0 M5 — Skills / Subagents / Orchestration Registry

Plan ID: dmc-v1-m5-orchestration · Date: 2026-07-06 · Format: PLAN_SCHEMA.md · Milestone: M5 of `.harness/plans/dmc-v1-runtime-upgrade.md` (master, APPROVED through M4)
Branch: `claude/dmc-v1-runtime-upgrade-c5uch1` @ `8903a67` (M4 shipped: run-core 153/0 · loop-core 78/0 · default 75/0 · `--all` == pinned baseline 802/3/3). Milestone-scoped **DRAFT**; not self-approved; does not amend the master's approval state.

## Goal

Turn the orphaned five-agent surface into a contracted, dispatchable orchestration layer: a single machine-readable role registry (`orchestration/roles.json`, P14 registry), six contract-ized agent prompts (+ new `release-auditor`), the P16 critic-verdict validator and a deterministic verdict-gate, the P14 delegation-record validator, skills bound to the M4 `dmc run start` verb, the three drifted role-list docs collapsed into pointers to the registry, and a deterministic link-check that proves no skill/agent references a nonexistent artifact/verb/role. M5 is the first milestone that edits `.claude/**` — and it edits **skills and agents only**; hooks and settings stay forbidden until M6.

## User Intent

Classify: **feature** (secondary: refactor — contract-izing shipped agent prompts and de-duplicating three role-list docs into registry pointers; docs — the pointer-ization).

## Current Repo Findings

- Finding: the five agents in `.claude/agents/` are 18–22-line role blurbs that reference no schema or artifact and carry write-capable tools; e.g. `.claude/agents/critic.md:1-19` returns prose `APPROVE/REJECT/NEEDS CLARIFICATION` (not a `critic-verdict.json` artifact) and its frontmatter grants `tools: Read, Glob, Grep, Bash` (Bash = write-capable). M5 contract-izes all five + adds `release-auditor.md`.
  Source: `.claude/agents/critic.md:1-19`; `docs/DMC_V1_ORCHESTRATION_MODEL.md:12-32` (audit of the five).
- Finding: the skills are Ring-2 prose that never call the M4 run verbs. `.claude/skills/dmc-start-work/SKILL.md:23-25` writes `.harness/runs/current-run.md`, `current-run-id`, `current-scope.txt` directly (no `dmc run start`); `.claude/skills/dmc-ultrawork/SKILL.md:26-29` says "Run a critic pass" and writes `current-scope.txt` in prose, emitting no `critic-verdict.json` and arming no run-id. M5 binds these to `dmc run start` (M4) + a verdict-gate.
  Source: `.claude/skills/dmc-start-work/SKILL.md:23-25`, `.claude/skills/dmc-ultrawork/SKILL.md:17-33`.
- Finding: M4 shipped the verbs M5 wires — `dmc run start|suspend|resume|status` (`bin/dmc:106-118`) — and the M3 contracts whose validators the master tags for M5: `critic-verdict.schema.md` and `delegation.schema.md` each state "validator lands in M5" (this schema-header declaration is the authorization source for building the delegation validator in M5, distinct from the P14 runtime records the master P-coverage assigns to M7). `bin/dmc` has **no** `verdict`/`delegation`/`roles`/`linkcheck` verb yet (all M5-new).
  Source: `bin/dmc:106-118,157-158`; `.harness/schemas/critic-verdict.schema.md`, `.harness/schemas/delegation.schema.md` (headers).
- Finding: **pointer-ization risk (caution c).** Two of the three docs the master pointer-izes are read at runtime by copy-routed legacy self-tests inside the pinned 802/3/3 baseline. `bin/lib/dmc-v0.2.5-verify.sh:48-56` (H7/H8) requires `docs/DMC_AGENT_HANDOFF.md` to contain the six templates `### critic`/`### start-work`/`### staging-review`/`### commit-review`/`### push-review`/`### milestone-closure` plus the five phrases `DRAFT`, `CLOSURE`, `re-confirm the current gate`, `Never infer a gate`, `Fail-closed checklist` — H7's six + H8's five are the only positive assertions on that doc. `bin/lib/dmc-v0.3.8-delegation-harness.sh:223-228` (AC7) requires `docs/DMC_DELEGATION_HARNESS.md` to contain SIX predicates: `Role-assignment`/`Roles`, `Critic handoff`, `allowed-autonomy`, `run-transcript checklist` (case-insensitive), a gated-stage table row (AC7's fifth predicate — a regex requiring a STAGE action gated to `human`; present at `docs/DMC_DELEGATION_HARNESS.md:49`), and `advisory INPUT` (present at `:57` as "advisory INPUTS"). `docs/DYNAMIC_DELEGATION.md` has NO legacy-self-test dependency. `docs/DMC_OPERATOR_HANDBOOK.md:91` also points at DMC_AGENT_HANDOFF's templates. Gutting either gated doc breaks `selftest --all` (802/3/3) and dangles an inbound doc reference; pointer-ization must be additive and preserve ALL of those substrings.
  Source: `bin/lib/dmc-v0.2.5-verify.sh:48-56`, `bin/lib/dmc-v0.3.8-delegation-harness.sh:223-228` (AC7's six predicates incl. the STAGE-row and `advisory INPUT` greps at :226), `docs/DMC_DELEGATION_HARNESS.md:49,57`, `docs/DMC_OPERATOR_HANDBOOK.md:91` (inbound-reference grep).
- Finding: `orchestration/` does not exist yet; the target taxonomy is fixed by `docs/ORCHESTRATION_TAXONOMY.md` (six roles: Strategic Orchestrator, Implementer, Critic/Falsifier, Release Auditor, Verifier, Human Release Gate; six capability classes: frontier-long-horizon, standard-implementation, cheap-fast, adversarial-review, deterministic-tool, human-only-gate) and the session bindings + `may_mutate` column in `docs/DMC_V1_ORCHESTRATION_MODEL.md:59-74`.
  Source: `docs/ORCHESTRATION_TAXONOMY.md:10-72`, `docs/DMC_V1_ORCHESTRATION_MODEL.md:59-74`; `ls orchestration/` (absent).
- Finding: `orchestration/models.json` (the dated, model-name-bearing lookup, P20) is **M8**, not M5 — master P-coverage map assigns `P20→M8`. M5 creates `roles.json` only; roles.json stays model-name-free (capability classes), model names appearing only in the M8 lookup (anti-goal #7).
  Source: master §Execution Tasks P-coverage (`P19,P20→M8`); `docs/DMC_V1_ORCHESTRATION_MODEL.md:76-99`.

## Relevant Files

| Path | Reason | Allowed to Edit |
|---|---|---|
| orchestration/roles.json (new) | P14 registry — the single 6-role/6-class taxonomy, model-name-free; session binding + capability_class + may_mutate per role | yes (new; M5) |
| bin/lib/dmc-roles.py (new) | roles.json validator (enum/shape/model-name-free) + registry lookup used by the delegation validator and link-check | yes (new; M5) |
| bin/lib/dmc-critic-verdict.py (new) | P16 validator for `critic-verdict.json` per critic-verdict.schema.md | yes (new; M5) |
| bin/lib/dmc-verdict-gate.py (new) | Ring-0 start-work precondition: REFUSE when a required critic-verdict is absent/invalid/plan_hash-mismatched | yes (new; M5) |
| bin/lib/dmc-delegation.py (new) | P14 delegation-record schema validator (role resolves in roles.json); runtime records pipeline deferred to M7 | yes (new; M5) |
| bin/lib/dmc-orchestration-linkcheck.py (new) | deterministic link-check over skills/agents (verbs, artifact paths, role names) | yes (new; M5) |
| bin/dmc | additive `roles`/`verdict`/`delegation`/`linkcheck` verb routing + the four named selftest sections + `--all` wiring — registered SOLELY by T010f (single-owner rule; T010a/b/c ship only their `.py` modules) | yes (additive; M5 — T010f only) |
| .claude/agents/{planner,explorer,critic,executor,verifier}.md | contract-ize: bind a roles.json role, artifact-schema-in/out, tool ceiling, may_mutate; read-only roles drop Bash-write; critic emits critic-verdict.json | yes (M5) |
| .claude/agents/release-auditor.md (new) | the one new agent (read-only; audits release-readiness against the diff; advisory verdict) | yes (new; M5) |
| .claude/skills/dmc-start-work/SKILL.md | call `dmc verdict gate` then `dmc run start` (arm run-id); reference the registry | yes (M5) |
| .claude/skills/dmc-ultrawork/SKILL.md | emit a critic-verdict via the critic role; call `dmc run start` (arm run-id) | yes (M5) |
| .claude/skills/dmc-critic/SKILL.md | emit `critic-verdict.json` (P16) instead of prose-only | yes (M5) |
| docs/DMC_AGENT_HANDOFF.md, docs/DYNAMIC_DELEGATION.md, docs/DMC_DELEGATION_HARNESS.md | additive registry-pointer banner + role-list marked derived; preserve every legacy-self-test-asserted substring (Finding 4) | yes (M5 — additive banner only, no asserted-substring deletion) |
| tests/fixtures/orchestration/** (new) | fixture roles.json consumers, a critic-verdict.json (valid + laundered), a delegation record, a dangling-ref skill for link-check negative controls, and an approved-plan + verdict pair for the arm-run-id pre-run | yes (new; M5) |
| .harness/evidence/dmc-v1-m5-*.md, .harness/verification/dmc-v1-m5-*.md (new) | per-sub-task evidence + milestone verification | yes (M5) |
| orchestration/models.json | P20 model-name lookup — M8, not M5 | no |
| .claude/hooks/*, .claude/settings.json | Ring-1 surface — M6 | no |
| .claude/workers/**, .claude/install/* | worker validators (M7), installer (M8) | no |
| .harness/evidence/dmc-v0.*.{sh,py} originals AND their bin/lib copies | copy-only; any byte change fails the mirror-check | no |
| bin/lib/dmc-run-lifecycle.py and other M4 modules | M4-shipped; M5 wires the run verb from skills, does not edit the tool (keeps run-core 153/0 byte-stable) | no |
| docs/MILESTONES.md, main/master | closure + protected branches (M10, human-gated) | no |

## Out of Scope

- Any `.claude/**` edit other than `.claude/skills/*/SKILL.md` and `.claude/agents/*.md`: hooks, `settings.json`, `.claude/workers/**`, `.claude/install/*` are all forbidden in M5 (M6/M7/M8).
- P14 **runtime records** (dispatch-time `delegations.jsonl` appending, subagent artifact validation-before-consumption enforcement) and P15 (worker apply-authorization chain) — M7. M5 ships the delegation **validator** only.
- `orchestration/models.json` and any model-name lookup (P20) — M8.
- Editing the M4 run-lifecycle tool: M5 calls `dmc run start` from skills but does not modify `bin/lib/dmc-run-lifecycle.py` (preserving run-core 153/0).
- Ring-1 enforcement that a model cannot mutate without arming a run (the Stop/scope hooks) — M6. M5's verdict-gate refusal is Ring-0; the obligation to invoke it is Ring-2 until M6 (disclosed, see Acceptance Criteria).
- Any new `bin/lib/dmc-v0.*` file (would break the legacy mirror-check); any git add/commit/push; any main/master change; live/network/secret paths.

## Proposed Changes

- Change: Role registry. Files: orchestration/roles.json, bin/lib/dmc-roles.py (bin/dmc verb+section wired by T010f). Rationale: one machine-readable taxonomy (P14 registry) faithful to `ORCHESTRATION_TAXONOMY.md`, model-name-free, validated and resolvable by the delegation validator and link-check.
- Change: Critic-verdict validator + verdict-gate (P16). Files: bin/lib/dmc-critic-verdict.py, bin/lib/dmc-verdict-gate.py (bin/dmc verb+section wired by T010f). Rationale: make the critic verdict a schema-checked artifact and give start-work a deterministic Ring-0 refusal when the verdict is missing/invalid (C11: the verdict opens no gate).
- Change: Delegation-record validator (P14 records schema-check). Files: bin/lib/dmc-delegation.py (bin/dmc verb+section wired by T010f). Rationale: enforce delegation.schema.md conformance and role-resolves-in-registry now; defer the runtime records pipeline to M7.
- Change: Six contract-ized agent prompts. Files: .claude/agents/{planner,explorer,critic,executor,verifier}.md + release-auditor.md. Rationale: replace orphaned blurbs with registry-bound contracts (schema-in/out, tool ceiling, may_mutate); only executor is may_mutate under a scope.lock; read-only roles drop Bash-write.
- Change: Skill bindings. Files: .claude/skills/{dmc-start-work,dmc-ultrawork,dmc-critic}/SKILL.md. Rationale: dmc-start-work/dmc-ultrawork call `dmc verdict gate` + `dmc run start` (arm run-id); dmc-critic emits `critic-verdict.json`.
- Change: Doc pointer-ization (additive). Files: docs/{DMC_AGENT_HANDOFF,DYNAMIC_DELEGATION,DMC_DELEGATION_HARNESS}.md. Rationale: collapse three drifted role lists into pointers to `orchestration/roles.json` by prepending a canonical-source banner and marking the role list derived — without deleting any substring the v0.2.5/v0.3.8 self-tests or the operator handbook depend on.
- Change: Link-check verifier + M5 selftest sections. Files: bin/lib/dmc-orchestration-linkcheck.py, bin/dmc, tests/fixtures/orchestration/**. Rationale: deterministic proof that no skill/agent references a nonexistent verb/artifact/role; new sections join `--all` but not the no-arg default.

## Acceptance Criteria

- Criterion: Link check — no skill (`.claude/skills/*/SKILL.md`) or agent (`.claude/agents/*.md`) references a nonexistent `dmc` verb, artifact path, or role name.
  Verification Method: `bin/dmc linkcheck` exits 0 over the real tree; a seeded dangling-ref fixture exits 3 with the offending reference named.
- Criterion: The critic-verdict artifact is schema-valid and gate-safe — a well-formed `critic-verdict.json` ACCEPTs; a `REJECT` with empty `blockers`, `advisory != true`, or a missing subject-binding field is REFUSED.
  Verification Method: `bin/dmc verdict validate <fixture>` (ACCEPT ⇒ 0 / REFUSE ⇒ 3) asserted in the `verdict` selftest section with those negative controls.
- Criterion: Start-work is refused without a critic-verdict ref, with an explicit layer disclosure (carry-forward note 3): the refusal is produced by **Ring-0 `dmc verdict gate`** (deterministic — it validates the referenced `critic-verdict.json` and REFUSES if absent, schema-invalid, or `plan_hash` ≠ the run's), while the **obligation** to invoke the gate before mutating is **Ring-2 skill prose** until M6 wires the Ring-1 Stop/scope hooks. This split is stated verbatim in the M5 evidence.
  Verification Method: `bin/dmc verdict gate` REFUSES (exit 3) on the no-verdict and mismatched-plan_hash fixtures and ACCEPTs on the valid pair; the evidence doc names the enforcing layer for each half.
- Criterion: The ultrawork path arms a run-id — a fixture pre-run of the dmc-ultrawork flow reaches `dmc run start` and creates a `.harness/runs/<run-id>/` (M9 runs the full E2E).
  Verification Method: an M9-scenario pre-run script drives the fixture plan+verdict through `dmc verdict gate` → `dmc run start` and asserts a run-id directory appears (in a tempdir; real repo untouched).
- Criterion: `orchestration/roles.json` and the six contract-ized agent prompts are model-name-free (capability classes only); a seeded model name is caught.
  Verification Method: `grep -RInE 'claude-(opus|sonnet|haiku|fable|mythos)|gpt-[0-9]|codex-[0-9]' orchestration/ .claude/agents/` is empty; the `roles` selftest seeds a model name and asserts the self-scan REFUSES it.
- Criterion: The delegation validator enforces the registry — a delegation record whose `role` is absent from `roles.json`, or `may_mutate: true` without a scope-lock reference, or `depth > max_depth`, is REFUSED.
  Verification Method: `bin/dmc delegation validate <fixture>` negative controls in the `delegation` selftest section.
- Criterion: Doc pointer-ization preserves the legacy baseline — after editing the three docs, `bin/dmc selftest --all` still reproduces legacy `802/3/3` (the v0.2.5 H7/H8 and v0.3.8 AC7 substrings enumerated in Finding 4 remain present), and no inbound doc reference dangles.
  Verification Method: `bin/dmc selftest --all` aggregate unchanged at `802/3/3`; `bin/dmc linkcheck` (extended to the doc pointers) green.
- Criterion: Regression — the no-arg default `bin/dmc selftest` stays **exactly 75/0 exit 0** (M5 sections are named/`--all`-only), and `bin/dmc selftest --all` keeps legacy `802/3/3` + run-core `153/0` + loop-core `78/0` unchanged while additionally running the M5 sections (roles/verdict/delegation/linkcheck), which must PASS for `--all` to exit 0.
  Verification Method: `bin/dmc selftest; echo $?` ⇒ `75 PASS / 0 FAIL` and 0; `bin/dmc selftest --all` ⇒ the four prior subtotals unchanged + M5 sections PASS + `bin/dmc mirror-check` green (no `dmc-v0.*` file added).

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Pointer-izing DMC_AGENT_HANDOFF/DMC_DELEGATION_HARNESS guts substrings the v0.2.5/v0.3.8 legacy self-tests assert, regressing 802/3/3 | high | pointer-ization is additive (banner + role-list marked derived); the exact asserted substrings (Finding 4) are preserved and enumerated in T010e; `selftest --all` == 802/3/3 is a hard acceptance gate |
| M5 is the first `.claude/**` edit — risk of straying into hooks/settings (M6 surface); and of multiple sub-tasks editing `bin/dmc` concurrently | medium | the Relevant Files table names the exact allowed set (`.claude/skills/*/SKILL.md`, `.claude/agents/*.md`); everything else under `.claude/**` is on the not-edit list; the single-owner rule makes T010f the ONLY editor of `bin/dmc` (T010a/b/c ship only `.py` modules), so there is no parallel bin/dmc collision; link-check + `git diff --name-only` scoped review |
| Link-check over prose is non-deterministic / brittle | medium | linkcheck extracts refs by fixed regex (inline-code `dmc <verb>` spans, `orchestration/*.json` and `.harness/schemas/*.schema.md` paths, role names ∈ roles.json) and resolves against a single declared verb source + the filesystem + roles.json; input-only, no network; negative-control fixture proves it can fail |
| Adding M5 validator self-tests to the no-arg default would move the 75/0 number | medium | decision: M5 sections are named + `--all`-only, not the no-arg default (matches the M4 run-core/loop-core precedent); default stays exactly 75/0 |
| A model name leaks into roles.json or an agent contract | medium | self-scan grep over `orchestration/` + `.claude/agents/` in T010a/T010f; capability classes only; model names are M8's models.json |
| Skills reference `dmc run start` but nothing forces traversal in M5 (Ring-1 is M6) | medium | disclosed as an explicit acceptance criterion (Ring-0 refusal vs Ring-2 obligation); no false claim of runtime enforcement is made |
| Contract-izing agents changes tool ceilings and breaks an existing skill dispatch | low | agents are text surfaces; rollback is `git revert`; link-check catches a skill pointing at a now-renamed role/verb |

## Assumptions

| Assumption | Confidence | How to Verify |
|---|---|---|
| roles.json is M5 and models.json is M8 | high | master P-coverage `P20→M8`; orchestration model §4 places model names in the dated lookup |
| The critic-verdict and delegation validators are M5 (their schemas say "validator lands in M5"); the delegation runtime records pipeline is M7 | high | schema headers; master P-coverage `P14(records),P15→M7` |
| `dmc run start` (M4) is a stable arming verb the skills can call unchanged | high | `bin/dmc:106-118`; M5 does not edit the run tool, so run-core stays 153/0 |
| Finding 4 enumerates the complete gated substring set: DMC_AGENT_HANDOFF = H7's six templates + H8's five phrases (the only positive assertions on it); DMC_DELEGATION_HARNESS = AC7's six predicates (four phrases + the STAGE-row regex + `advisory INPUT`); DYNAMIC_DELEGATION has no legacy-self-test dependency | high | read from `dmc-v0.2.5-verify.sh:48-56` and `dmc-v0.3.8-delegation-harness.sh:223-228`; re-confirmed by `selftest --all` == 802/3/3 after the edits |
| No inbound reference to the three docs other than those found (v0.2.5, v0.3.8, operator handbook, plans/audit) | medium | repo-wide inbound grep re-run in T010e before editing; link-check over docs after |
| python3 + git present on the dev/CI host (M5 tools are offline, read-only) | high | already required by M2–M4 tools; `dmc doctor` (M8) will formalize |

## Execution Tasks

REQUIRED-primitive coverage (master M5 row): P14 registry → T010a · P16 (validator + gate) → T010b · P14 delegation validator → T010c · six contract-ized agents (+release-auditor) → T010d · skill bindings + doc pointer-ization → T010e · link-check + regression → T010f. Deferred to M7: P14 runtime records, P15. Deferred to M8: P20 models.json. **Single-owner rule (M4 pattern): `bin/dmc` is edited by T010f ONLY** — T010f registers all four verb routings (roles/verdict/delegation/linkcheck), all four selftest section arms, and the `--all` wiring; T010a/b/c ship only their `.py` modules (+ roles.json for T010a) and are verified standalone via `python3 bin/lib/<module> --self-test`, then aggregated into the named sections at T010f. This removes the parallel bin/dmc collision. Bounded order: **T010a first** (registry everything resolves against) → **T010b, T010c, T010d in parallel** (each ships only its own file(s); no shared bin/dmc edit) → **T010e** (skills call the T010b gate; docs pointer to T010a) → **T010f** (bin/dmc wiring + link-check over all of it + regression). Each sub-task ships its own module self-test and is independently verifiable before T010f aggregates them.

Global not-edit (every sub-task): `.claude/hooks/*`, `.claude/settings.json`, `.claude/workers/**`, `.claude/install/*`, `orchestration/models.json`, M4 run-lifecycle modules, `.harness/evidence/dmc-v0.*` originals + bin/lib copies, `docs/MILESTONES.md`, main/master. No `bin/lib/dmc-v0.*` additions. No git add/commit/push. No live/network/secret paths.

- [ ] DMC-T010a: Role registry + validator (P14 registry). Route: **Opus 4.8** (taxonomy fidelity + model-name-free invariant).
  Files: orchestration/roles.json (new), bin/lib/dmc-roles.py (new). (The `roles` verb + `roles` selftest section are registered by T010f — single-owner rule.)
  **Acceptance:** roles.json encodes the six roles (Strategic Orchestrator, Implementer, Critic/Falsifier, Release Auditor, Verifier, Human Release Gate) each with `session_binding`, `capability_class` ∈ the six-class enum, and `may_mutate` (true only for the executor/Implementer under a scope.lock); `dmc roles validate` checks shape/enum and that no model-name string appears.
  **Verification:** `python3 bin/lib/dmc-roles.py --self-test` (standalone gate; aggregated into `bin/dmc selftest roles` at T010f).
  **Negative controls (must REFUSE):** a `capability_class` outside the six-class enum; a role marked `may_mutate: true` other than the executor; a model-name string anywhere in roles.json.
  **Rollback:** delete the two new files (the `bin/dmc` `roles` arm is reverted by T010f's rollback).
  **Evidence:** .harness/evidence/dmc-v1-m5-roles.md.
  **Not-edit:** global list; no models.json.
  **Risk:** medium — the registry every other sub-task resolves against; keep it faithful to ORCHESTRATION_TAXONOMY.md and model-name-free.

- [ ] DMC-T010b: Critic-verdict validator + verdict-gate (P16). Route: **Opus 4.8** (C11 gate correctness).
  Files: bin/lib/dmc-critic-verdict.py (new), bin/lib/dmc-verdict-gate.py (new). (The `verdict` verb + `verdict` selftest section are registered by T010f — single-owner rule.)
  **Acceptance:** `dmc verdict validate` enforces critic-verdict.schema.md (subject binding, `verdict` enum, `REJECT ⇒ non-empty blockers`, `advisory == true`); `dmc verdict gate --verdict <f> --plan-hash <h>` REFUSES when the verdict is absent, schema-invalid, or `plan_hash`-mismatched, and ACCEPTs the valid pair. The gate opens nothing — it only refuses or passes through (C11).
  **Verification:** `python3 bin/lib/dmc-critic-verdict.py --self-test` and `python3 bin/lib/dmc-verdict-gate.py --self-test` (standalone gates; aggregated into `bin/dmc selftest verdict` at T010f).
  **Negative controls (must REFUSE):** `REJECT` with empty `blockers`; `advisory != true`; a missing subject-binding field; verdict-gate with no verdict; verdict-gate with `plan_hash` ≠ run's.
  **Rollback:** delete the two new files (the `bin/dmc` `verdict` arm is reverted by T010f's rollback).
  **Evidence:** .harness/evidence/dmc-v1-m5-verdict.md.
  **Not-edit:** global list; must not edit the M4 run tool (the gate is a separate precondition module).
  **Risk:** medium — C11: the verdict must never open a gate; the gate must only refuse/pass.

- [ ] DMC-T010c: Delegation-record validator (P14 records schema-check). Route: **Sonnet 5** (mechanical schema check; escalate to Opus if role-resolution proves subtle).
  Files: bin/lib/dmc-delegation.py (new). (The `delegation` verb + `delegation` selftest section are registered by T010f — single-owner rule.)
  **Acceptance:** `dmc delegation validate` enforces delegation.schema.md (subject binding, `capability_class` enum, `role` resolves in `orchestration/roles.json`, `depth ≤ max_depth`, `may_mutate: true` only with a scope-lock reference, `validation_verdict` gating). Runtime records pipeline is explicitly M7.
  **Verification:** `python3 bin/lib/dmc-delegation.py --self-test` (standalone gate; aggregated into `bin/dmc selftest delegation` at T010f).
  **Negative controls (must REFUSE):** a `role` absent from roles.json; `may_mutate: true` with no scope-lock reference; `depth > max_depth`; consumption recorded with `validation_verdict != PASS`.
  **Rollback:** delete the new file (the `bin/dmc` `delegation` arm is reverted by T010f's rollback).
  **Evidence:** .harness/evidence/dmc-v1-m5-delegation.md.
  **Not-edit:** global list; no runtime records (M7).
  **Risk:** low — validator only; depends on T010a's registry for role resolution.

- [ ] DMC-T010d: Six contract-ized agent prompts. Route: **Opus 4.8** (contract fidelity + tool-ceiling correctness).
  Files: .claude/agents/{planner,explorer,critic,executor,verifier}.md (rewrite), .claude/agents/release-auditor.md (new).
  **Acceptance:** each agent prompt binds a roles.json role and declares artifact-schema-in, artifact-schema-out, a tool ceiling, and `may_mutate`; read-only roles (planner/explorer/critic/verifier/release-auditor) drop Bash-write; executor is the only `may_mutate` role and operates only under a scope.lock; critic emits `critic-verdict.json` (P16); release-auditor consumes `release-readiness.json` + the diff and emits an advisory audit verdict.
  **Verification:** `bin/dmc linkcheck` (T010f) finds no dangling artifact/role/verb ref in the six agents; a seeded dangling ref REFUSED.
  **Negative controls (must REFUSE, via link-check):** an agent referencing a nonexistent schema path or a role absent from roles.json.
  **Rollback:** `git revert` (text surfaces only).
  **Evidence:** .harness/evidence/dmc-v1-m5-agents.md.
  **Not-edit:** global list; agents only — no hooks/settings/skills-in-this-task.
  **Risk:** medium — tool ceilings must be right (read-only roles must not carry Bash-write).

- [ ] DMC-T010e: Skill bindings + additive doc pointer-ization. Route: **Opus 4.8** (the 802/3/3-preserving pointer-ization is load-bearing).
  Files: .claude/skills/{dmc-start-work,dmc-ultrawork,dmc-critic}/SKILL.md, docs/{DMC_AGENT_HANDOFF,DYNAMIC_DELEGATION,DMC_DELEGATION_HARNESS}.md.
  **Acceptance:** dmc-start-work and dmc-ultrawork call `dmc verdict gate` then `dmc run start` (arm run-id) and reference the registry; dmc-critic emits `critic-verdict.json`; each of the three docs gains a canonical-source banner pointing to `orchestration/roles.json` with its role list marked derived, while **every** substring enumerated in Finding 4 is preserved verbatim — DMC_AGENT_HANDOFF's six `###` templates + five H8 phrases + the operator-handbook template references, and ALL SIX v0.3.8 AC7 predicates in DMC_DELEGATION_HARNESS including the gated-stage table row (`:49`) and `advisory INPUT` (`:57`). WARNING: the STAGE gated-action TABLE ROW (`DMC_DELEGATION_HARNESS.md:49`) is NOT part of the role list — the "role list marked derived" restructuring must not touch, reword, or delete that row or the other gated-action rows.
  **Verification:** `bin/dmc selftest --all` still `802/3/3`; `bin/dmc linkcheck` green over skills + docs; re-run the inbound-reference grep to confirm no dangling reference.
  **Negative controls (must hold):** in a DISPOSABLE COPY of the repo (tempdir, never the real tree — `git status --porcelain` stays clean), removing any one of the enumerated Finding-4 substrings (each of DMC_AGENT_HANDOFF's eleven and DMC_DELEGATION_HARNESS's six, incl. the STAGE-row regex and `advisory INPUT`) drops the v0.2.5/v0.3.8 subtotal; the pre/post `selftest --all` subtotal diff from that disposable copy is recorded in the evidence doc — proving the guard is real.
  **Rollback:** `git revert` (text surfaces only).
  **Evidence:** .harness/evidence/dmc-v1-m5-skills-docs.md.
  **Not-edit:** global list; skills edited are exactly the three named; no other `.claude/**`.
  **Risk:** high — pointer-ization must not regress 802/3/3; additive banner only.

- [ ] DMC-T010f: Link-check verifier + integration/regression. Route: **Opus 4.8** (deterministic link-check + baseline discipline).
  Files: bin/lib/dmc-orchestration-linkcheck.py (new), bin/dmc (SOLE registrant of ALL M5 bin/dmc changes: the four verb routings `roles`/`verdict`/`delegation`/`linkcheck`, the four named selftest section arms, and the `--all` wiring — added; NOT the no-arg default), tests/fixtures/orchestration/** (new), .harness/verification/dmc-v1-m5-orchestration.md (new), .harness/evidence/dmc-v1-m5-integration.md (new).
  **Acceptance:** `dmc linkcheck` deterministically resolves every skill/agent reference (inline-code `dmc <verb>` against the dispatcher's declared verb set; `orchestration/*.json` and `.harness/schemas/*.schema.md` paths against the filesystem; role names against roles.json) and exits 3 on any dangling ref; the four M5 sections join `--all`; the no-arg default stays exactly 75/0; the ultrawork arm-run-id pre-run passes in a tempdir.
  **Verification:** `bin/dmc linkcheck` ⇒ 0; `bin/dmc selftest; echo $?` ⇒ `75 PASS / 0 FAIL` and 0; `bin/dmc selftest --all` ⇒ legacy `802/3/3` + run-core `153/0` + loop-core `78/0` + roles/verdict/delegation/linkcheck PASS + exit 0; `bin/dmc mirror-check` green; `git status --porcelain` byte-identical before/after the tempdir pre-run.
  **Negative controls (must REFUSE):** a seeded skill referencing `dmc frobnicate`, a nonexistent schema path, or an unregistered role — each named and exit 3.
  **Rollback:** delete the new files + revert the additive `bin/dmc` arms; M4 selftest surface and baselines return byte-identically.
  **Evidence:** .harness/evidence/dmc-v1-m5-integration.md + .harness/verification/dmc-v1-m5-orchestration.md.
  **Not-edit:** global list; must not alter the pinned baseline or the M4 sections.
  **Risk:** medium — link-check determinism + keeping the four M4/M5 subtotals byte-stable.

M5-overall extended block:
**Acceptance:** roles.json registry (model-name-free) + roles validator; critic-verdict validator + Ring-0 verdict-gate (with the Ring-0-refusal / Ring-2-obligation disclosure); delegation validator (runtime records deferred to M7); six contract-ized agents (+release-auditor); dmc-start-work/dmc-ultrawork bound to `dmc run start` + verdict-gate; dmc-critic emits critic-verdict.json; three docs pointer-ized additively with 802/3/3 preserved; `dmc linkcheck` green; default 75/0 exit 0; `--all` == 802/3/3 + run-core 153/0 + loop-core 78/0 + M5 sections PASS.
**Verification:** `bin/dmc linkcheck` + `bin/dmc verdict validate` + `bin/dmc delegation validate` + `bin/dmc roles validate` + `bin/dmc selftest` (75/0) + `bin/dmc selftest --all` (subtotals unchanged + M5 sections PASS) + `bin/dmc mirror-check` + the model-name-free grep + `git status --porcelain` clean.
**Rollback:** additive rollback (dry-run verified in the verification doc) — delete the five new `bin/lib/*.py` modules + `orchestration/roles.json` + fixtures, revert the additive `bin/dmc` arms, and `git revert` the six agent prompts, three skills, and three doc banners; the M4 selftest surface and pinned baseline return byte-identically (nothing consumes M5 artifacts at runtime yet — Ring-1 wiring is M6).
**Evidence:** `.harness/evidence/dmc-v1-m5-*.md`, `.harness/verification/dmc-v1-m5-orchestration.md`.
**Not-edit:** `.claude/hooks/*`, `.claude/settings.json`, `.claude/workers/**`, `.claude/install/*`, `orchestration/models.json`, M4 run modules, `.harness/evidence/dmc-v0.*` originals + copies, `docs/MILESTONES.md`, main/master; no new `bin/lib/dmc-v0.*`; no live/network/secret paths.
**Risk:** medium — first `.claude/**` milestone; contained by the exact allowed-file list, the additive-only pointer-ization, and the byte-stable M4 baselines.

## Verification Commands

| Command | Reason | Required |
|---|---|---|
| bash -n bin/dmc; python3 -m py_compile bin/lib/dmc-roles.py bin/lib/dmc-critic-verdict.py bin/lib/dmc-verdict-gate.py bin/lib/dmc-delegation.py bin/lib/dmc-orchestration-linkcheck.py | syntax floor for new files | yes |
| bin/dmc linkcheck | no skill/agent references a nonexistent verb/artifact/role (+ negative control) | yes |
| bin/dmc selftest roles verdict delegation linkcheck | the four M5 validator sections incl. all negative controls | yes |
| bin/dmc selftest; echo $? | no-arg default stays exactly 75/0 and exit 0 (M5 sections are named/`--all`-only) | yes |
| bin/dmc selftest --all | legacy 802/3/3 + run-core 153/0 + loop-core 78/0 unchanged + M5 sections PASS + exit 0 | yes |
| bin/dmc mirror-check | no `dmc-v0.*` copy added/altered | yes |
| grep -RInE 'claude-(opus\|sonnet\|haiku\|fable\|mythos)\|gpt-[0-9]\|codex-[0-9]' orchestration/ .claude/agents/ | roles.json + agent contracts are model-name-free | yes |
| git status --porcelain (before/after the arm-run-id pre-run) | real repo byte-unchanged (pre-run is tempdir-only) | yes |

## Approval Status

Status: APPROVED
Approver: wjlee (wjlee@motionlabs.kr) — human release gate
Approved At: 2026-07-06

Approval record (verbatim scope of the human gate, 2026-07-06, granted in the local session):
- **M5-only approval**: DMC-T010a–T010f as specified in §Execution Tasks — orchestration/roles.json,
  five new bin/lib modules, bin/dmc additive wiring (T010f sole registrant), the six agent-prompt
  contract-izations (+release-auditor.md new), the three named SKILL.md bindings, the three
  additive doc pointer-izations (17-substring preservation binding), fixtures, M5
  evidence/verification files, local run artifacts.
- **First-`.claude/**`-edit confirmation GRANTED, exactly**: `.claude/skills/{dmc-start-work,
  dmc-ultrawork,dmc-critic}/SKILL.md` + `.claude/agents/*.md` only; hooks/settings.json/
  workers/install remain forbidden (M6/M7/M8).
- **Scoping deferrals CONFIRMED**: orchestration/models.json (P20) → M8; P14 runtime records +
  P15 → M7 (M5 ships registry + validators + verdict-gate only).
- **Explicitly NOT approved**: staging/commit/push (separate human gates), M6+, any hook/
  settings/worker/installer/provider change, edits to dmc-v0.* originals or copies, M4 module
  edits, main/master changes, live calls, secret access.
- Critic provenance: DMC critic (independent, Opus) — Rev 1 NEEDS CLARIFICATION (R1 bin/dmc
  conflict, R2 incomplete AC7 enumeration) → Rev 2 focused re-pass **APPROVE**; critic APPROVE
  is advisory input only (C11); approval granted by the human release gate above.

Milestone-scoped DRAFT for M5; not self-approved; does not alter the master's approval state. Two items for the human gate's attention at approval: (1) M5 is the first milestone to edit `.claude/**` — confirm the exact allowed set (`.claude/skills/*/SKILL.md`, `.claude/agents/*.md` only; hooks/settings/workers/install remain forbidden until M6/M7/M8); (2) confirm the scoping decisions stated in Findings — `models.json`/P20 deferred to M8, and P14 runtime records/P15 deferred to M7 (M5 ships the registry + validators + verdict-gate only). Next gates: DMC critic pass on this draft → human M5 approval → M5 start.
