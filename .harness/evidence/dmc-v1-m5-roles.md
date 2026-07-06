# DMC v1.0 M5 — Role registry + validator (DMC-T010a)

- run_id: `dmc-v1-m5-20260706`
- date: 2026-07-06
- branch: `claude/dmc-v1-runtime-upgrade-c5uch1`
- plan: `.harness/plans/dmc-v1-m5-orchestration.md` (APPROVED 2026-07-06, approver wjlee) §DMC-T010a
- primitive: P14 registry — the single machine-readable orchestration taxonomy. The P14 *runtime
  records* pipeline (delegations.jsonl append, consumption enforcement) is out of scope — M7. The
  dated model-name lookup (`orchestration/models.json`, P20) is out of scope — M8.
- faithful to: `docs/ORCHESTRATION_TAXONOMY.md` (Output 1 six roles, Output 2 six capability
  classes) and `docs/DMC_V1_ORCHESTRATION_MODEL.md:59-74` (session bindings + `may_mutate`).
- scope of this task: additive only. Two files created: `orchestration/roles.json` (creating the
  `orchestration/` dir) and `bin/lib/dmc-roles.py`. Per the single-owner rule, `bin/dmc` is NOT
  touched — T010f registers the `roles` verb + selftest section; this module is fully usable
  standalone via `python3 bin/lib/dmc-roles.py`.

## Files created / modified

| Path | Change | In-scope |
|---|---|---|
| orchestration/roles.json | new — the single 6-role / 6-class taxonomy (P14 registry), model-name-free | yes (T010a) |
| bin/lib/dmc-roles.py | new — registry validator (`validate`) + resolution (`lookup`) + hermetic self-test | yes (T010a) |
| .harness/evidence/dmc-v1-m5-roles.md | new — this evidence log | yes (T010a) |

## Registry shape (judgment calls)

- **Schema id / in-tool contract:** `schema: "dmc.roles.v1"` (validated exact). A top-level
  `provenance` object records the canonical source, the two docs it is faithful to, the milestone,
  the model-name-free invariant, C11, and the mutation rule — provenance carried as parseable
  fields (JSON has no comments).
- **Per-role field set:** `id` (stable kebab machine key), `role` (display name), `session_binding`,
  `capability_class` (∈ the six-class enum), `may_mutate` (bool), `mutation_constraint` (the
  scope.lock / read-only / n/a constraint stated *in the record*, per the task), plus advisory
  `must_not` and `outputs` mirrored from the taxonomy. `id` and `role` are both unique.
- **The six roles**, each with its capability class and may_mutate (only the Implementer is `true`):
  | id | role | capability_class | may_mutate |
  |---|---|---|---|
  | strategic-orchestrator | Strategic Orchestrator | frontier-long-horizon | false |
  | implementer | Implementer | standard-implementation | **true** (scope.lock) |
  | critic-falsifier | Critic / Falsifier | adversarial-review | false |
  | release-auditor | Release Auditor | adversarial-review | false |
  | verifier | Verifier | deterministic-tool | false |
  | human-release-gate | Human Release Gate | human-only-gate | false |
- **may_mutate encoding:** a boolean, `true` for exactly one role. The orchestration model lists the
  Strategic Orchestrator's mutation as "via executor path only" and the Human Release Gate's as
  "n/a" — both encode to `may_mutate: false` because neither mutates *directly*; the constraint text
  captures the "delegates to the executor path" / "not applicable" nuance. Top-level
  `mutation_capable_role: "implementer"` names the one legal mutator, cross-checked by the validator.
- **Model-name-free:** capability classes only. The Release Auditor's "external audit (Codex-class)"
  wording from the orchestration-model table was deliberately reworded to "external audit delegate"
  to avoid any model-family token — the registry carries no model name in any field.
- **Lookup interface (documented in the module docstring, kept simple for downstream M5 tools):**
  `python3 bin/lib/dmc-roles.py lookup <role> [--registry PATH]` resolves by exact `id` **or** exact
  display `role` name; on a match it prints the role record as JSON to stdout and exits 0; an unknown
  role (or an unreadable/invalid registry) prints a value-blind `REFUSED:` reason and exits 3. The
  subprocess contract for T010c (delegation validator) and T010f (link-check) is therefore:
  **exit 0 + JSON == resolves; exit 3 == absent/invalid.** A malformed registry fails the lookup
  closed. `--registry` defaults to `orchestration/roles.json` under the repo root.

## Validator design

- House style copied from `bin/lib/dmc-instance-validate.py`: stdlib-only, env-free, offline
  (no network/git), input-only, value-blind reason codes (`ROLES-*` name schema constants/enums,
  never a document value), secret-path refused by path, fail-closed. JSON idioms
  (`object_pairs_hook` duplicate-key rejection, recursive value-blind scan) copied from
  `bin/lib/dmc-v0.6.2-evidence-receipt.py`.
- `validate <path>`: ACCEPT ⇒ exit 0, REFUSE ⇒ exit 3, usage ⇒ exit 2. Checks: `schema` exact;
  whole-document model-name self-scan; `capability_classes` == the six-class enum;
  `mutation_capable_role == "implementer"`; each role's required fields present + single-line;
  `may_mutate` is a bool; `capability_class` ∈ enum; `id`/`role` unique; the six canonical role ids
  present exactly (no drift); only the Implementer may be `may_mutate:true` and it must state a
  scope.lock constraint.
- Model-name detector: `re.compile(r"claude-(?:opus|sonnet|haiku|fable|mythos)|gpt-[0-9]|codex-[0-9]",
  re.IGNORECASE)` — catches at least the plan-mandated patterns, case-insensitive to be stricter
  than the belt-and-suspenders `grep`.

## Verification results

- `python3 -m py_compile bin/lib/dmc-roles.py` ⇒ clean.
- `python3 bin/lib/dmc-roles.py --self-test` ⇒ **`[roles] 19 PASS / 0 FAIL`, exit 0.** All fixtures
  written to `tempfile.TemporaryDirectory()`; the real repo is untouched.
- Positive control: `python3 bin/lib/dmc-roles.py validate orchestration/roles.json` ⇒
  `VALID: orchestration/roles.json conforms to dmc.roles.v1`, exit 0. The self-test's **R0** asserts
  the same real-registry ACCEPT.
- Lookup: `lookup implementer` ⇒ exit 0 + the JSON record (`may_mutate: true`);
  `lookup "Human Release Gate"` ⇒ exit 0, resolves `human-release-gate`;
  `lookup frobnicator` ⇒ `REFUSED: ROLES-UNKNOWN-ROLE`, exit 3.
- Negative controls (each a real REFUSE — exit 3 at the CLI, or a non-empty reason list in-process):
  | Plan §DMC-T010a negative control | Reason code | Self-test |
  |---|---|---|
  | capability_class outside the six-class enum | `ROLES-BAD-CLASS` | R2 |
  | a role other than the Implementer marked may_mutate:true | `ROLES-ILLEGAL-MUTATOR` | R3 |
  | a seeded model-name string (`claude-opus-4-8`, `gpt-5`, `codex-5`) | `ROLES-MODEL-NAME` | R4 (×3) |
  | (extra) duplicate role id | `ROLES-DUP-ID` | R5 |
  | (extra) dropped canonical role | `ROLES-MISSING-ROLE` | R6 |
  | (extra) missing required field | `ROLES-FIELD-MISSING` | R7 |
  | (extra) may_mutate not a bool | `ROLES-MUTATE-NOT-BOOL` | R8 |
  | (extra) mutator without a scope.lock constraint | `ROLES-MUTATOR-NO-SCOPE-LOCK` | R9 |
  | (extra) wrong schema id | `ROLES-BAD-SCHEMA` | R10 |
  | (extra) duplicate JSON key | `ROLES-UNREADABLE` | R11 |
  The three plan-required controls (bad class, illegal mutator, model name) each REFUSE with exit 3
  at the CLI, confirmed directly (a seeded `gpt-5` fixture ⇒ `ROLES-MODEL-NAME`, exit 3).
- Determinism (**R13**): identical input ⇒ identical reason list.
- Model-name-free grep over the real tree:
  `grep -RInE 'claude-(opus|sonnet|haiku|fable|mythos)|gpt-[0-9]|codex-[0-9]' orchestration/` ⇒
  **empty** (the plan-mandated Acceptance grep, `orchestration/ .claude/agents/`, is satisfied for
  the `orchestration/` half this task owns).
- Hermeticity: `git status --porcelain orchestration/ bin/lib/dmc-roles.py` shows only the two new
  untracked paths; `__pycache__` swept under `bin/` (the script is run directly, imports only
  stdlib, so none is produced).

## Hand-off note for the verifier (T010f) — model-name grep scope

`bin/lib/dmc-roles.py` is the **first `bin/` file to contain the model-name literal patterns**,
because a model-name *detector* must name what it detects (exactly as the secret-detectors in
`bin/lib/dmc-v0.6.2-evidence-receipt.py` contain `sk-`/`ghp_` token patterns). Consequence: the
old M4-era **convenience** grep `grep -RInE 'claude-(opus|…)|gpt-[0-9]' bin/` (used in several M4
evidence docs) is **no longer empty** — it now matches this detector file, and only this file
(confirmed: `grep -RIlE … bin/` ⇒ `bin/lib/dmc-roles.py` alone). This is expected and correct, not
a leak. Two facts keep it from being a regression:
1. The **plan-mandated** M5 model-name grep is scoped to `orchestration/ .claude/agents/` (plan
   line 200 / Acceptance line 85) — **not** `bin/` — and that scope is clean.
2. There is **no automated selftest** that greps `bin/` for model names (the M4 `bin/`-wide greps
   live only in evidence write-ups, never in `bin/dmc selftest` code), so `bin/dmc selftest` is
   unaffected.
T010f/verification should keep the model-name grep scoped to `orchestration/ .claude/agents/` per
the plan, or explicitly exempt the single detector file `bin/lib/dmc-roles.py`.

## Rollback

Delete `orchestration/roles.json` and `bin/lib/dmc-roles.py` (and this evidence file); remove the
now-empty `orchestration/` dir if desired. Nothing consumes either at runtime yet — the M3/M4
selftest surface (default 75/0) and the pinned legacy baseline are unchanged. The `bin/dmc` `roles`
arm does not exist yet (T010f owns it).

## Not-edit confirmation

Not touched: `bin/dmc`, any M4 run-lifecycle module, `bin/lib/dmc-instance-validate.py`, the M3
schema docs, `orchestration/models.json` (M8 — does not exist), `.claude/**` (T010d/e own
skills/agents), `.claude/hooks/*`, `.claude/settings.json`, `.claude/workers/**`,
`.claude/install/*`, any `.harness/evidence/dmc-v0.*` original or its bin/lib copy, `docs/**`,
`docs/MILESTONES.md`, main/master. No new `bin/lib/dmc-v0.*` filename. No git add/commit/push. No
live/network/secret paths.
