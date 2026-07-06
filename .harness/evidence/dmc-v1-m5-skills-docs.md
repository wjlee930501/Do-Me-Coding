# Evidence — DMC-T010e: Skill bindings + additive doc pointer-ization (M5)

Plan: `.harness/plans/dmc-v1-m5-orchestration.md` (APPROVED 2026-07-06) · Run: `dmc-v1-m5-20260706`
Task: DMC-T010e · Route: Opus 4.8 · Date: 2026-07-06

## Scope delivered (exactly 6 files + this evidence)

| File | Change | Kind |
|---|---|---|
| `.claude/skills/dmc-start-work/SKILL.md` | body bound to Ring-0: verify APPROVED → `dmc verdict gate` (REFUSE ⇒ stop) → `dmc run start` (arms run-id); registry-referenced; Ring-0/Ring-2 disclosure | body only |
| `.claude/skills/dmc-ultrawork/SKILL.md` | critic step dispatches the critic AGENT to emit `critic-verdict.json`, then `dmc verdict gate` → `dmc run start` | body only |
| `.claude/skills/dmc-critic/SKILL.md` | emits a schema-conforming `critic-verdict.json` artifact (validated by `dmc verdict validate`) + prose summary, instead of prose-only | body only |
| `docs/DMC_AGENT_HANDOFF.md` | additive canonical-source banner | +7 / −0 |
| `docs/DYNAMIC_DELEGATION.md` | additive banner + `## Roles` derived-marker | +8 / −0 |
| `docs/DMC_DELEGATION_HARNESS.md` | additive banner + `## 1. Roles` derived-marker | +8 / −0 |

Frontmatter of all three skills is intact (line 1 `---`, `name:` present, closing fence present) —
bodies only were edited.

## (a) Both-tool baseline reproduced (fast targeted check)

Real tree, before edits → after edits:

| Tool | Command | Before | After |
|---|---|---|---|
| v0.2.5 handbook/handoff | `bash bin/lib/dmc-v0.2.5-verify.sh` | PASS=14 FAIL=0, exit 0 | **PASS=14 FAIL=0, exit 0** |
| v0.3.8 delegation-harness | `bash bin/lib/dmc-v0.3.8-delegation-harness.sh --self-test` | PASS=8 FAIL=0, exit 0 | **PASS=8 FAIL=0, exit 0** |

Both reproduce their pinned baseline counts. (Full `bin/dmc selftest --all` == 802/3/3 runs at T010f.)

## (b) 17-substring negative control (disposable copy only)

Method: `tar`-copied the working tree (incl. these edits) into a fresh git repo under the session
scratchpad (`.../scratchpad/neg-control-copy`, never the real tree). For each gated substring, removed
it (case-matching each tool's own grep flags — case-insensitive for v0.2.5 `has()`; case-sensitive
except `run-transcript checklist` for v0.3.8 AC7), re-ran the owning tool, then `git checkout`-restored.
Copy baseline before any removal: v0.2.5 = 14/0, v0.3.8 = 8/0.

### DMC_AGENT_HANDOFF.md → `dmc-v0.2.5-verify.sh` (baseline PASS=14)

| # | substring removed | guard | result |
|---|---|---|---|
| 1 | `### critic` | H7 template | PASS=13 FAIL=1 |
| 2 | `### start-work` | H7 template | PASS=13 FAIL=1 |
| 3 | `### staging-review` | H7 template | PASS=13 FAIL=1 |
| 4 | `### commit-review` | H7 template | PASS=13 FAIL=1 |
| 5 | `### push-review` | H7 template | PASS=13 FAIL=1 |
| 6 | `### milestone-closure` | H7 template | PASS=13 FAIL=1 |
| 7 | `DRAFT` | H8 | PASS=13 FAIL=1 |
| 8 | `CLOSURE` | H8 | PASS=12 FAIL=2 (see note) |
| 9 | `re-confirm the current gate` | H8 | PASS=13 FAIL=1 |
| 10 | `Never infer a gate` | H8 | PASS=13 FAIL=1 |
| 11 | `Fail-closed checklist` | H8 | PASS=13 FAIL=1 |

Note (#8): H8's check is `has "$HO" "CLOSURE"` = `grep -qiF` (case-insensitive). The only way to
falsify it is to remove every case-insensitive `closure`, which also deletes the `### milestone-closure`
H7 template — so both H7 and H8 fail (14→12). Honest double-coverage; the guard on CLOSURE is real (and
doubly protective). All others are a clean single-predicate drop (14→13).

### DMC_DELEGATION_HARNESS.md → `dmc-v0.3.8-delegation-harness.sh --self-test` (baseline PASS=8)

| # | substring removed | AC7 predicate | result |
|---|---|---|---|
| 12 | `Roles` (`Role-assignment\|Roles`) | §1 heading | PASS=7 FAIL=1 |
| 13 | `Critic handoff` | §2 heading | PASS=7 FAIL=1 |
| 14 | `allowed-autonomy` | intro + validator | PASS=7 FAIL=1 |
| 15 | `run-transcript checklist` (case-insensitive) | intro + §4 | PASS=7 FAIL=1 |
| 16 | `**STAGE** … human` gated-action row (regex `\*\*STAGE\*\*.*human\|STAGE.*\| human`) | §3 matrix | PASS=7 FAIL=1 |
| 17 | `advisory INPUT` | §3 blockquote | PASS=7 FAIL=1 |

Every one of the 17 drops the owning tool's subtotal. After restore, the pristine copy passes again
(v0.2.5 = 14/0, v0.3.8 = 8/0), confirming the drops were caused solely by the removals.

Guard-shadowing check: the banner I added to DMC_DELEGATION_HARNESS was reworded to duplicate **none**
of the six AC7 substrings (removed an earlier draft that echoed `allowed-autonomy`, `STAGE`,
`run-transcript checklist`), so no banner text can shadow-satisfy an AC7 predicate and mask a deletion.
The negative-control drops above confirm the guard still binds the original §1–§4 content.

## (c) Inbound-reference grep

Re-ran the repo-wide inbound grep for the three doc names. All three files still exist (only banners
were added — no rename/move/delete), so **no inbound reference dangles**. The pre-existing line-range
cross-references (e.g. `DMC_AGENT_HANDOFF.md:8-21` in `DMC_DELEGATION_HARNESS.md:34` and in plans) are
now a few lines lower but do not dangle; the two legacy self-tests assert by **substring**, not by line
number, so the small line shift is inert.

## Per-doc diff summary (additive banner + derived-marker only)

- `docs/DMC_AGENT_HANDOFF.md`: **+7 / −0** — one 6-line canonical-source banner after the lead
  paragraph. State machine, gate rules, and all six `###` templates + five H8 phrases untouched.
- `docs/DYNAMIC_DELEGATION.md`: **+8 / −0** — banner after the intro + a one-line derived-marker under
  `## Roles (owns / must-not / outputs)`. (No legacy self-test binds this doc.)
- `docs/DMC_DELEGATION_HARNESS.md`: **+8 / −0** — banner after the intro + a one-line derived-marker
  under `## 1. Roles (separation of duties)`. The heading text, the §3 STAGE/COMMIT/PUSH/CLOSURE
  gated-action rows, and `advisory INPUTS` (§3) are byte-untouched.

Zero deletions in all three docs (`git diff --numstat`).

## Judgment calls (disclosed)

1. **dmc-critic emits the artifact as structured output, frontmatter unchanged.** The skill keeps
   `disallowed-tools: Edit, Write`; the critic is `may_mutate: false` in `orchestration/roles.json`
   ("read-only; a critic verdict is advisory input"). So the schema-conforming `critic-verdict.json` is
   emitted as the critic's structured output and persisted/validated by the caller — mirroring the v0.2
   rule that read-only producers emit proposals and never mutate. This keeps frontmatter intact while
   satisfying "emit `critic-verdict.json`, not prose-only."
2. **Machine run-state now owned by `dmc run start`.** dmc-start-work's old steps 4–6 (hand-writing
   `current-run.md`, `current-run-id`, `current-scope.txt`) were replaced by `bin/dmc run start --plan`
   (M4), which mints + arms the run-id and locked scope under `.harness/runs/<run-id>/`. Same for
   dmc-ultrawork's old `current-scope.txt` step.
3. **Verbs referenced as they WILL exist at T010f.** The skills/docs reference `bin/dmc verdict gate`,
   `bin/dmc verdict validate`, and `bin/dmc roles validate`. `dmc run` already exists (M4); the
   `verdict`/`roles` verbs are registered by T010f — per plan, link-check resolves them at integration.
4. **Ring-0 / Ring-2 disclosure carried verbatim** in both dmc-start-work and dmc-ultrawork: the
   verdict-gate *refusal* is Ring-0 (deterministic, fail-closed); the *obligation* to invoke it before
   mutating is Ring-2 skill prose until M6 wires the Ring-1 Stop/scope hooks.
5. **Exact canonical role names** used in the skills ("Implementer", "Critic / Falsifier") to keep
   link-check role resolution against `orchestration/roles.json` green.

## Confirmation — nothing else touched

- `git status --porcelain` on the real tree lists only the 6 T010e files among this task's changes; the
  other modified/untracked entries are prior sub-tasks' artifacts (T010a–d agents, `bin/lib/*.py`,
  `orchestration/`, evidence), not mine.
- No temp/scratch artifact leaked into the real tree (`neg-control-copy` lives only under the session
  scratchpad). No `.orig`, no `__pycache__`.
- Not edited: any other `.claude/**` (hooks/settings/agents/workers/install), `bin/**`,
  `orchestration/`, schemas, MILESTONES, main/master. No git add/commit/push. No network/secret paths.
