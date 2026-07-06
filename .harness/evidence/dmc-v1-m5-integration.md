# DMC v1.0 M5 — Link-check + integration / regression (DMC-T010f)

- run_id: `dmc-v1-m5-20260706`
- date: 2026-07-06
- branch: `claude/dmc-v1-runtime-upgrade-c5uch1`
- plan: `.harness/plans/dmc-v1-m5-orchestration.md` (APPROVED 2026-07-06, approver wjlee) §DMC-T010f
- role of this sub-task: the M5 integrator and SOLE registrant of every `bin/dmc` change (single-owner
  rule). It ships the deterministic orchestration link-check, wires the four M5 verbs + four named
  selftest sections + the `--all` composition, commits the fixtures, folds in the arm-run-id pre-run,
  and proves the milestone keeps the M2–M4 baselines byte-stable.

## Files created / modified (exactly the T010f authorized set)

| Path | Change | In-scope |
|---|---|---|
| bin/lib/dmc-orchestration-linkcheck.py | new — deterministic link-check over skills/agents/doc-banners + embedded self-test (negative controls + arm-run-id pre-run) | yes (T010f) |
| bin/dmc | additive — four verb routings (`roles`/`verdict`/`delegation`/`linkcheck`), four named selftest sections, and the `--all` wiring; the no-arg default is untouched (stays 9 sections / 75/0) | yes (T010f, sole registrant) |
| tests/fixtures/orchestration/linkcheck-neg-verb.md · -neg-path.md · -neg-role.md · -neg-all.md · linkcheck-pos.md | new — link-check negative controls (unknown verb / dangling path / unregistered role) + a positive control | yes (T010f) |
| tests/fixtures/orchestration/arm-run/plan.md · critic-verdict.json | new — the approved plan + valid, plan-bound critic-verdict pair driven through the arm-run-id pre-run | yes (T010f) |
| .harness/verification/dmc-v1-m5-orchestration.md | new — the M5 milestone verification report (passes `dmc validate verification`) | yes (T010f) |
| .harness/evidence/dmc-v1-m5-integration.md | new — this evidence log | yes (T010f) |

No T010a–e deliverable (the five `bin/lib` modules, the six agents, three skills, three docs,
`orchestration/roles.json`) was edited; they are consumed only. `bin/dmc` was the single file T010f
edits that T010a–e deliberately left alone.

## The link-check (`bin/lib/dmc-orchestration-linkcheck.py`)

Deterministic, fixed-regex resolution of three reference classes across the real surface
(`.claude/skills/*/SKILL.md`, `.claude/agents/*.md`, and the three registry-pointer docs
DMC_AGENT_HANDOFF / DYNAMIC_DELEGATION / DMC_DELEGATION_HARNESS):

1. **dmc VERBS** — `dmc <verb>` / `bin/dmc <verb>` spans, extracted from markdown code regions only
   (inline `` `...` `` + fenced ```` ``` ```` blocks), resolved against the dispatcher's own declared
   verb set. **The verb set is parsed from `bin/dmc`'s single top-level `case "$cmd" in ... esac`
   block** — the arm patterns at case-depth 1 (nested `case ... in` sub-dispatch is depth-tracked and
   excluded, the `*` wildcard dropped). This makes the dispatcher the ONE source of truth for the
   verb surface: because T010f adds the four M5 arms, the link-check resolves `dmc roles/verdict/
   delegation/linkcheck` automatically. Code-region-only extraction (plus a lowercase-`dmc` match
   with a `[ \t]+` separator) is why prose like "DMC orchestration" in a heading, and inline tokens
   like `dmc.roles.v1` or `dmc-v0.3.8-...`, are NOT misread as verb references.
2. **PATHS** — `orchestration/<name>.json` and `.harness/schemas/<name>.schema.md` references,
   resolved against the filesystem root-relative.
3. **ROLES** — role *bindings* of the form `Role: `<id>`` (the machine-consumable registry binding the
   six agents declare), resolved against `orchestration/roles.json` via the T010a `dmc-roles.py
   lookup` subprocess (exit 0 = resolves, exit 3 = absent). Prose display-name mentions
   ("Implementer", "Critic / Falsifier") in skills/docs are NOT bindings; they point at the
   path-checked registry (class 2) and are intentionally not resolved as role tokens — resolving
   arbitrary bold/inline tokens would false-positive on non-role emphasis like `may_mutate`. This
   scoping is disclosed as a judgment call below.

Exit 0 clean / exit 3 with every dangling ref NAMED (`LINK-UNKNOWN-VERB` / `LINK-DANGLING-PATH` /
`LINK-UNKNOWN-ROLE`; a secret-shaped path ref is refused as `LINK-SECRET-REF` without echo). House
style copied from `bin/lib/dmc-roles.py`: stdlib-only, env-free, offline, input-only, value-blind,
secret-path refused by path, fail-closed. Cross-tool calls (dmc-roles.py lookup, and in the pre-run
`bin/dmc verdict gate` / `run start`) are read-only subprocesses, never imports — the module stays
independently deletable.

## Real-tree link-check result

`bin/dmc linkcheck` ⇒ **`OK: linkcheck clean — 24 file(s) scanned, every dmc-verb / artifact-path /
role reference resolves`, exit 0.** The 24-file surface = the skills + the six agents + the three
pointer docs (+ the other `.claude/skills/*` cards). Every reference resolves:
- verbs seen: `verdict`, `validate`, `run`, `selftest` (agents/skills) + `roles` (doc banners) — all
  in the dispatcher verb set;
- paths seen: `orchestration/roles.json` + the ten `.harness/schemas/*.schema.md` the agents cite —
  all exist;
- role bindings seen: `strategic-orchestrator`, `implementer`, `critic-falsifier`, `release-auditor`,
  `verifier` — all resolve via the registry lookup (`human-release-gate` has no agent, intentionally
  unbound).

## Negative controls (each REFUSED and NAMED)

`bin/dmc selftest linkcheck` ⇒ **`[linkcheck] 17 PASS / 0 FAIL`, exit 0**, exercising:

| Control | Reason code | Named token | Assertion |
|---|---|---|---|
| a skill referencing `dmc frobnicate` | `LINK-UNKNOWN-VERB` | `frobnicate` | L2 |
| a contract citing a nonexistent schema path | `LINK-DANGLING-PATH` | `.harness/schemas/nonexistent.schema.md` | L3 |
| an agent binding an unregistered role | `LINK-UNKNOWN-ROLE` | `frobnicator-nonexistent` | L4 |
| a fixture seeding all three at once | all three | — | L5 |
| a positive fixture (every ref resolves) | (clean) | — | L6 |

Confirmed at the CLI too: `bin/dmc linkcheck --root <tempdir with a dangling skill+agent>` ⇒ each
dangling ref printed `REFUSED: LINK-…` + a stderr summary, **exit 3**. Determinism (L7), the
role-resolver composition against the real registry (L8: real id resolves, fake id does not), and
secret-path refusal (L9) all PASS.

## Arm-run-id pre-run (plan Acceptance Criterion 4)

Folded into the link-check self-test (A0–A3). It drives the committed fixture plan + critic-verdict
through **`bin/dmc verdict gate` → `bin/dmc run start`** inside a disposable tempdir git repo:

- **A0** fixture integrity: the committed `critic-verdict.json`'s `plan_hash` == `sha256(plan.md)` =
  `ef343767…65e038` (recomputed at runtime; the tempdir verdict is regenerated with the runtime hash
  so the pre-run is robust to any later reformat of the fixture plan).
- **A1** `dmc verdict gate --verdict <f> --plan-hash <sha256>` ⇒ PASS (exit 0) on the valid pair;
  **A1b** a mismatched `--plan-hash` (`0…0`) ⇒ REFUSE (exit 3).
- **A2** `dmc run start --plan <tempdir plan> --root <tempdir>` ⇒ exit 0 and a
  `.harness/runs/<run-id>/run.json` directory appears IN THE TEMPDIR (run-id pointer + run.json
  present).
- **A3** the REAL repo `git status --porcelain` is byte-identical before/after the pre-run — the
  scenario is entirely tempdir-confined. (M9 runs the full E2E; M5 proves only that the ultrawork
  path reaches `run start` and arms a run-id.)

## bin/dmc wiring (single-owner; additive)

- Verb routings: `roles` → `dmc-roles.py`; `verdict validate` → `dmc-critic-verdict.py`,
  `verdict gate` → `dmc-verdict-gate.py`; `delegation` → `dmc-delegation.py`; `linkcheck` →
  `dmc-orchestration-linkcheck.py`. Each smoke-tested (roles/verdict validate+gate all exit 0;
  `delegation` with no sub-arg ⇒ usage exit 2).
- Four named selftest sections `roles` / `verdict` (runs BOTH verdict modules) / `delegation` /
  `linkcheck`, wired into `--all` after run-core/loop-core, and reachable by name. Section counts
  (via `bin/dmc selftest roles verdict delegation linkcheck`, exit 0):

  | Section | Footer | Modules folded |
  |---|---|---|
  | roles | `[roles] 19 PASS / 0 FAIL` | dmc-roles.py |
  | verdict | `[verdict-validate] 16 PASS / 0 FAIL` + `[verdict-gate] 9 PASS / 0 FAIL` | dmc-critic-verdict.py + dmc-verdict-gate.py |
  | delegation | `[delegation] 29 PASS / 0 FAIL` | dmc-delegation.py |
  | linkcheck | `[linkcheck] 17 PASS / 0 FAIL` | dmc-orchestration-linkcheck.py |

- The **no-arg default is untouched**: `bin/dmc selftest; echo $?` ⇒ **75 PASS / 0 FAIL
  (10+11+8+7+8+6+6+15+4), exit 0** — the M5 sections are named/`--all`-only, matching the M4
  run-core/loop-core precedent.

## Regression / baseline discipline

- `bash -n bin/dmc` ⇒ clean; `python3 -m py_compile` on all five M5 modules ⇒ clean.
- `bin/dmc mirror-check` ⇒ **PASS** (55/55 byte-identical, "no stray dmc-v0.* copies beyond the
  pinned 55-file set"). The new module is `dmc-orchestration-linkcheck.py` — NOT a `dmc-v0.*`
  filename — so it never enters the mirror set.
- Model-name-free grep `grep -RInE 'claude-(opus|sonnet|haiku|fable|mythos)|gpt-[0-9]|codex-[0-9]'
  orchestration/ .claude/agents/` ⇒ **empty**. (Per the T010a carry-forward, the grep is scoped to
  `orchestration/ + .claude/agents/` per the plan; `bin/lib/dmc-roles.py`,`dmc-critic-verdict.py`, and
  now the link-check do carry model-name/secret DETECTOR patterns and are correctly outside that
  scope — no automated selftest greps `bin/` for model names.)
- **LIVE `bin/dmc selftest --all`** (uncommitted working tree): SELFTEST-ALL FAIL / exit 1 — the
  KNOWN, expected live-tree drift. Legacy aggregate **tools=49 PASS=800 FAIL=5 N/A=3** (drifted from
  the pinned 802/3/3 by exactly two extra FAILs: `dmc-v0.5.9-dynamic-workflow-acceptance.sh` and
  `dmc-v0.6.0-verify.sh` — the same v0.5.9 AC13 + v0.6.0 V15 working-tree class as M3/M4, where the
  pre-M3-vintage checks trip on tracked-but-uncommitted mods; the other three FAILs are the pinned
  upstream baseline anomaly v0.1.3/v0.2.3/v0.3.2). `rollback-test` also FAILs in LIVE for the SAME
  root cause (its originals-alone re-run drifts to 800 too). run-core **153/0** + loop-core **78/0**
  + all four M5 sections PASS even LIVE. Not a defect; disappears on commit; not chased.
- **COMMITTED-REPLICA `bin/dmc selftest --all`** (rsync − .git → git init/add/commit in the
  scratchpad; clean tree): the acceptance evidence — legacy **tools=49 PASS=802 FAIL=3 N/A=3 EXACT**
  (== the pinned baseline; the three FAILs are only v0.1.3/v0.2.3/v0.3.2) + run-core **153/0** +
  loop-core **78/0** + the four M5 sections PASS (`[roles] 19/0`, `[verdict-validate] 16/0`,
  `[verdict-gate] 9/0`, `[delegation] 29/0`, `[linkcheck] 17/0`) + `mirror-check` + `rollback-test`
  **PASS** + **SELFTEST-ALL RESULT: PASS** + **exit 0**.

## Rollback dry-run (disposable copy under the session scratchpad)

A fresh rsync copy (never the real tree): deleted the five M5 `bin/lib` modules + `orchestration/` +
`tests/fixtures/orchestration/`, deleted the new `release-auditor.md`, and reverted `bin/dmc` + the
five tracked agents + three skills + three docs to `HEAD` (pre-M5) via `git show HEAD:<path>`. Result:
- reverted `bin/dmc linkcheck` ⇒ unknown command, **exit 2** (the M5 verbs are gone);
- reverted default `bin/dmc selftest` ⇒ **75 PASS / 0 FAIL, exit 0** — the M2–M4 surface returns
  byte-identically;
- reverted `bin/dmc mirror-check` ⇒ **PASS**.
This confirms M5 is cleanly additive: nothing consumes the M5 artifacts at runtime yet (Ring-1
wiring is M6), so removing them restores the pinned baseline exactly.

## Judgment calls (disclosed)

1. **Verb set = the dispatcher's own case arms.** Rather than hardcode a verb list, the link-check
   parses `bin/dmc`'s top-level `case "$cmd" in` block (depth-tracked). This keeps the checker and
   the dispatcher from ever drifting apart and means the four M5 verbs resolve the moment T010f wires
   them. Documented in the module docstring.
2. **Verb extraction is code-region-scoped** (inline + fenced), not whole-prose, to avoid
   false-positives on the many prose "DMC …" mentions and on schema-id tokens (`dmc.roles.v1`). The
   skills put their verbs in fenced ```` ```text ```` blocks and the agents in inline spans; both are
   covered.
3. **Role resolution is limited to explicit `Role: `<id>`` bindings.** The six agents bind a role id
   this way; skills reference the registry by path (checked) and use display names as prose. Scanning
   arbitrary bold/inline tokens as roles would false-positive on non-role emphasis (`may_mutate`,
   `Ring-0`) and on capability-class tokens on the same line, so the checker resolves only the
   machine-binding cue. The negative-control fixtures use the same cue with a bad value.
4. **Paths resolve root-relative; roles resolve against the installed registry.** `--root` retargets
   the scanned surface and path resolution (used by the CLI negative-control demo), but role lookup
   always uses the real `orchestration/roles.json` via `dmc-roles.py`'s own default — a role's
   existence is a property of the installed registry, not of the scan root.
5. **Arm-run pre-run regenerates `plan_hash` at runtime** (in the tempdir verdict) while asserting the
   committed pair is consistent (A0), so the pre-run cannot silently rot if the fixture plan is later
   reformatted.

## Not-edit confirmation

Not touched: the T010a–e deliverables except `bin/dmc` (the five M5 `bin/lib` modules, six agents,
three skills, three docs, `orchestration/roles.json` — consumed only), any M4 run-lifecycle module,
`bin/lib/dmc-instance-validate.py`, the M3 schema docs, `.claude/hooks/*`, `.claude/settings.json`,
`.claude/workers/**`, `.claude/install/*`, `orchestration/models.json`, any `.harness/evidence/dmc-v0.*`
original or its bin/lib copy, `docs/MILESTONES.md`, main/master. No new `bin/lib/dmc-v0.*` filename.
No git add/commit/push. stdlib-only, env-free, offline, secret-path refusal. `__pycache__` swept.
