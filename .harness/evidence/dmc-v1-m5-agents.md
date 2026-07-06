# Evidence — DMC v1.0 M5 · DMC-T010d: Six contract-ized agent prompts

Sub-task: DMC-T010d (six contract-ized agents + `release-auditor`) under APPROVED plan
`.harness/plans/dmc-v1-m5-orchestration.md`. Branch `claude/dmc-v1-runtime-upgrade-c5uch1`.
Date: 2026-07-06. Route: Opus 4.8.

## Deliverables (files written — exactly these)

- `.claude/agents/planner.md` (rewrite)
- `.claude/agents/explorer.md` (rewrite)
- `.claude/agents/critic.md` (rewrite)
- `.claude/agents/executor.md` (rewrite)
- `.claude/agents/verifier.md` (rewrite)
- `.claude/agents/release-auditor.md` (new)
- `.harness/evidence/dmc-v1-m5-agents.md` (this evidence file)

Nothing else was touched (scope proof below).

## Per-agent contract summary

Each prompt is now a CONTRACT: (a) binds a `orchestration/roles.json` role by id; (b) declares
artifact-schema-IN / artifact-schema-OUT as real paths; (c) declares a tool ceiling consistent
with `may_mutate`; (d) states C11 verbatim-or-stronger where relevant.

| Agent | roles.json role id | Capability class | may_mutate | Schema-IN | Schema-OUT | Tool ceiling |
|---|---|---|---|---|---|---|
| planner | `strategic-orchestrator` | frontier-long-horizon | false | P1–P4 scans (`orientation`/`landmarks`/`depsurface`/`radius`.schema.md) + goal | `plan.schema.md` (via `dmc validate plan`) | Read, Glob, Grep, Bash (read-only) |
| explorer | `strategic-orchestrator` | frontier-long-horizon | false | repo tree + scan request | P1–P4 scan schemas (`orientation`/`landmarks`/`depsurface`/`radius`.schema.md) | Read, Glob, Grep, Bash (read-only) |
| critic | `critic-falsifier` | adversarial-review | false | plan path (`plan.schema.md`) or diff ref | `critic-verdict.json` (`critic-verdict.schema.md`, via `dmc verdict validate`) | Read, Glob, Grep, Bash (read-only) |
| executor | `implementer` | standard-implementation | **true** (scope-locked) | APPROVED `plan.schema.md` + `scope-lock.schema.md` (armed by `dmc run start`) | scope-bounded edits + `evidence-receipt.schema.md` | Read, Glob, Grep, **Edit, Write**, Bash |
| verifier | `verifier` | deterministic-tool | false | `evidence-receipt.schema.md` + `run.schema.md` | `verification.schema.md` (via `dmc validate verification`) | Read, Glob, Grep, Bash (read-only) |
| release-auditor (new) | `release-auditor` | adversarial-review | false | `release-readiness.json` (named input, no schema in M5) + the diff | advisory audit verdict + residual-risk list | Read, Glob, Grep, Bash (read-only) |

C11 verbatim-or-stronger is carried in `critic.md` (verdict `advisory: true`, never opens a gate;
`context_provenance` must be `fresh` — the author may not emit its own verdict; `REJECT` requires
non-empty blockers) and in `release-auditor.md` (ACCEPT is advisory input to the Human Release
Gate, never the gate itself; no self-approval). `executor.md` carries the separation half (does not
plan/approve/verify-and-close its own work). `verifier.md` forbids declaring DONE from a model
self-assessment. `planner.md` forbids approving its own plan or opening a gate.

## Tool-ceiling tension — resolution (disclosed judgment call)

**Tension:** the read-only review roles (critic, verifier) legitimately USE Bash for read-only
empirical verification (running self-tests, `git status`, `dmc validate ...`). Dropping Bash
entirely breaks their verification duty; keeping it unrestricted contradicts "read-only roles must
not carry write-capable tooling."

**Resolution (per `docs/DMC_V1_ORCHESTRATION_MODEL.md` §6/§7):** the model documents exactly this —
"Read-only role writing via Bash → role contracts + Bash write-radius classifier (P7) applied to
subagent sessions" (§6), and §7 states subagent internal tool use is only as constrained as the
harness allows (Ring-1 dependent). So the least-privilege documented compromise is:

1. Read-only roles (planner, explorer, critic, verifier, release-auditor) keep `Bash` **in the
   tool ceiling** but **never carry `Edit`/`Write`**. `Edit`/`Write` are present only on the
   executor.
2. The CONTRACT TEXT of every read-only role binds Bash to **read-only usage only**: no file
   writes, no git-mutating commands, no installs, no `git apply`/`patch`. Each such file states
   explicitly that **Ring-1 enforcement of this read-only-Bash bound (the P7 write-radius
   classifier over subagent sessions) arrives in M6; in M5 it is a Ring-2 contract obligation.**
3. The executor is the ONLY `may_mutate: true` role; its `Edit`/`Write` are bounded by the
   scope.lock and its Bash may run build/test/verify but never pushes and never `git apply`/`patch`
   a worker proposal.

This is a deliberate, disclosed judgment call — not a silent retention of the status quo. The
status-quo files carried Bash with no read-only constraint text and no `may_mutate` declaration;
every file now declares `may_mutate`, the read-only-Bash bound, and the M6 Ring-1 milestone.

## Role-binding judgment calls (disclosed)

- **Two agents bind `strategic-orchestrator`.** roles.json has six roles but there is no dedicated
  "planner" or "explorer" role — planning and repo-inspection are both facets the Strategic
  Orchestrator *owns* (its outputs are "a plan, a lane assignment, a delegation handoff"; it
  "inspects the repo" to decompose). So `planner` binds the orchestrator's plan-authorship facet
  and `explorer` binds its read-only inspection facet. Both are `may_mutate: false`, consistent
  with the role.
- **`human-release-gate` has no agent — correct.** It is human-only by taxonomy; there is no
  subagent for it, which is why six agents map onto five distinct role ids (the sixth role is the
  human gate).
- **`release-readiness.json` is cited as a bare named input, not a schema path.** No
  `.harness/schemas/release-readiness.schema.md` ships in M5, so citing one would dangle the
  T010f link-check. The release-auditor's output (advisory audit verdict + residual-risk list)
  likewise has no M5 schema and is described in prose; the only schema path it cites is
  `scope-lock.schema.md` for the scope/protected-surface check (exists).

## Verification results

**Model-name-free (acceptance criterion):**
```
grep -RInE 'claude-(opus|sonnet|haiku|fable|mythos)|gpt-[0-9]|codex-[0-9]' .claude/agents/
=> (empty)  ·  CLEAN: no model-name strings
```
`model: inherit` (not a model name) is preserved in each frontmatter; bodies use capability
classes only.

**Link-check safety (pre-flight for T010f — every reference resolves):**
- All 10 distinct `.harness/schemas/*.schema.md` paths referenced exist on disk (`critic-verdict`,
  `depsurface`, `evidence-receipt`, `landmarks`, `orientation`, `plan`, `radius`, `run`,
  `scope-lock`, `verification`).
- The one `orchestration/*.json` path referenced (`orchestration/roles.json`) exists.
- All role ids referenced (`strategic-orchestrator`, `implementer`, `critic-falsifier`,
  `release-auditor`, `verifier`) resolve in roles.json; `human-release-gate` intentionally
  unreferenced (no agent).
- All `dmc <verb>` references use real verbs: `run` (M4), `validate` (M3/M4), `verdict` (M5
  T010b/f), `selftest` (existing). No reference to an unregistered verb.

**Frontmatter validity:** each of the six files has exactly one `name:`, `description:`, and
`tools:` key; frontmatter structure (name/description/tools/model/effort/color) preserved and
valid.

**Scope proof (`git status --porcelain`):** the only `.claude/**` changes are the five modified
agent files + the one new `release-auditor.md`; zero `.claude/**` changes outside
`.claude/agents/`. No hooks/settings/skills/workers/install touched. No `bin/**`, no docs, no
schemas edited by this task. No git add/commit/push. No network/secret access.

## Not-edit confirmation

Untouched by T010d: `.claude/hooks/*`, `.claude/settings.json`, `.claude/skills/**` (that is
T010e), `.claude/workers/**`, `.claude/install/*`, `bin/**` (parallel workers own the lib
modules; `bin/dmc` is T010f-only), `docs/**`, `orchestration/roles.json` and `models.json`, all
schemas, main/master.
