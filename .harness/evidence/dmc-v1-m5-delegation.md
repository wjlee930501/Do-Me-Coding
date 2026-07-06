# DMC v1.0 M5 — Delegation-record validator (DMC-T010c)

- run_id: `dmc-v1-m5-20260706`
- date: 2026-07-06
- branch: `claude/dmc-v1-runtime-upgrade-c5uch1`
- plan: `.harness/plans/dmc-v1-m5-orchestration.md` (APPROVED 2026-07-06, approver wjlee) §DMC-T010c
- primitive: P14 **records schema-check** — validates a single `dmc.delegation.v1` delegation
  record against `.harness/schemas/delegation.schema.md`. The P14 **runtime records pipeline**
  (dispatch-time `delegations.jsonl` appending, live consumption enforcement) is explicitly out of
  scope for this task — M7 (plan Out of Scope; schema header: "the runtime enforcement floor stays
  the hooks"). This is stated verbatim in the module docstring.
- scope of this task: additive only. One file created: `bin/lib/dmc-delegation.py`. Per the
  single-owner rule, `bin/dmc` is NOT touched — T010f registers the `delegation` verb + selftest
  section; this module is fully usable standalone via `python3 bin/lib/dmc-delegation.py`.

## Files created / modified

| Path | Change | In-scope |
|---|---|---|
| bin/lib/dmc-delegation.py | new — delegation-record schema validator (`validate`) + hermetic self-test | yes (T010c) |
| .harness/evidence/dmc-v1-m5-delegation.md | new — this evidence log | yes (T010c) |

No other path was touched. `bin/dmc`, `orchestration/roles.json`, `bin/lib/dmc-roles.py`, all M4
modules, `.claude/**`, the six M3 schema docs, and every other worker's in-flight file
(`dmc-critic-verdict.py`, `dmc-verdict-gate.py`, the six agent contracts) were read where needed
for context but never written.

## Validator design

- House style copied from `bin/lib/dmc-instance-validate.py` and `bin/lib/dmc-roles.py`:
  stdlib-only, env-free, offline (no network; git invoked only best-effort/read-only for the
  self-test's own hermeticity check, with a no-git fallback matching `bin/lib/dmc-acceptance.py`'s
  `repo_hash()`), input-only, value-blind reason codes (`DELEG-*` name schema constants/enums,
  never a document value), duplicate-JSON-key rejection (`_no_dup` hook, copied idiom), secret-path
  refused by path, and — per the task's house-style-hardening ask — secret-shaped field *content*
  also refused via the `UNSAFE` regex copied verbatim from `bin/lib/dmc-v0.6.1.0-trace-linkage.py`
  (the same copy already reused in `dmc-approvals.py`, `dmc-fixloop.py`, `dmc-v0.6.4-goal-ledger.py`,
  etc.).
- `validate <path> [--registry PATH]`: ACCEPT ⇒ exit 0, REFUSE ⇒ exit 3, usage ⇒ exit 2.
- Reason-code taxonomy (24 distinct `DELEG-*` codes covering every schema rule plus hardening):
  `NOT-OBJECT`, `BAD-SCHEMA`, `SECRET-SHAPED`, `MISSING-BINDING` (work_id), `BAD-HASH`
  (plan_hash/repo_hash), `FIELD-MISSING` (delegation_id, capability_class), `BAD-CLASS`,
  `MUTATE-NOT-BOOL`, `ROLE-MISSING`, `ROLE-UNRESOLVED`, `ILLEGAL-MUTATOR`, `NO-SCOPE-LOCK`,
  `BAD-DEPTH`, `BAD-MAX-DEPTH`, `DEPTH-EXCEEDS-MAX`, `BAD-VERDICT`, `BAD-ARTIFACT-REF`,
  `BAD-ARTIFACT-SCHEMA`, `ARTIFACT-SCHEMA-MISSING`, `ARTIFACT-REF-ORPHAN-SCHEMA`,
  `UNVALIDATED-CONSUMPTION`, `BAD-PREV-HASH`, `UNREADABLE` (parse-level).

## Role resolution — composition with the T010a lookup subprocess

Per the assignment, `bin/lib/dmc-roles.py` (T010a's registry) is consumed **only** as a read-only
subprocess, never re-parsed directly:

```
python3 bin/lib/dmc-roles.py lookup <role> [--registry PATH]
```

`resolve_role()` (in `dmc-delegation.py`) invokes this exact command (resolving the sibling script
by `__file__` location, never by `cwd` or `PATH`; the invoking interpreter is `sys.executable`).
The contract, as documented by T010a and consumed here:

- exit 0 + a JSON object on stdout ⇒ the role resolves; the validator parses that JSON and reads
  its `may_mutate` field directly from the registry's own answer (never a second, independent
  read of `orchestration/roles.json`) to decide whether `may_mutate: true` is legal for the
  resolved role.
- exit 3 (unknown role, or an unreadable/invalid registry) ⇒ does not resolve.

**Failure mode = fail-closed**, verified in two distinct ways in the self-test:

1. **N1** — a role name absent from the real registry (`"frobnicator-nonexistent"`) against the
   real `orchestration/roles.json` ⇒ `DELEG-ROLE-UNRESOLVED`.
2. **N20** — a role name that *would* resolve (`"verifier"`) but with `--registry` pointed at a
   nonexistent path in a tempdir ⇒ still `DELEG-ROLE-UNRESOLVED`. This is the composition-failure
   case distinct from N1: it proves the subprocess boundary itself (spawn success, non-zero exit,
   malformed/absent stdout, timeout — all caught in `resolve_role()`'s `except` clause and the
   `proc.returncode != 0` / JSON-parse-failure checks) degrades to "does not resolve," never to a
   silent pass or an exception that would abort the validator ungracefully.

Both are real subprocess invocations of the actual `dmc-roles.py` script (not a stub/mock), so the
self-test exercises the genuine end-to-end composition, not just the calling module's own logic.

## Judgment call — the scope-lock reference field

`delegation.schema.md`'s illustrative JSON block does not name a distinct field for "an active
scope.lock reference" — the schema's prose rule states only that a mutation-capable dispatch
requires one (`"may_mutate: true is permitted ONLY ... under an active scope.lock"`), and the
schema doc itself is not-edit for this task. This validator names that field `scope_lock_ref` — a
non-null, non-empty string identifying the run's `scope.lock.json` (schema `dmc.scope-lock.v1`;
`bin/lib/dmc-scope-lock.py`'s `REQUIRED_FIELDS` include `run_id` and `state_hash`, the natural
handles such a reference would name) — and requires it (via `_nestr`) whenever `may_mutate: true`.
This is a **schema-shape check only**: it confirms the reference is present and non-empty; it does
not itself open or cross-validate the referenced `scope.lock.json`'s content (that composition is a
runtime, M7 concern, consistent with this task's schema-check-only scope). Documented in the module
docstring; flagged here for T010f/verification attention in case a different field name is later
standardized when the runtime pipeline lands.

## Consumption-gating interpretation

The schema states two related rules without an explicit "this record represents consumption" flag:
"Consuming an artifact requires `validation_verdict == PASS`" and "When `artifact_ref` is present,
`artifact_schema` must name the schema it was validated against." This validator treats **presence
of a non-null `artifact_ref`** as the record documenting an artifact-consumption event, and
therefore requires, whenever `artifact_ref` is non-null: (a) `artifact_schema` also non-null/
non-empty (`DELEG-ARTIFACT-SCHEMA-MISSING` if absent), and (b) `validation_verdict == "PASS"`
(`DELEG-UNVALIDATED-CONSUMPTION` otherwise, covering both the `FAIL` and `PENDING` negative-control
variants). The reverse orphan (`artifact_schema` present, `artifact_ref` null) is also refused
(`DELEG-ARTIFACT-REF-ORPHAN-SCHEMA`) since a schema id with nothing to validate is meaningless. A
record with both fields `null` (e.g. a plain routing/dispatch entry with nothing yet to consume) is
unaffected and free to carry any `validation_verdict`.

## Verification results

- `python3 -m py_compile bin/lib/dmc-delegation.py` ⇒ clean.
- `python3 bin/lib/dmc-delegation.py --self-test` ⇒ **`[delegation] 29 PASS / 0 FAIL`, exit 0.**
  All fixtures written to `tempfile.TemporaryDirectory()`; the real repo is untouched (see N24).
- CLI end-to-end, confirmed directly (not just in-process):
  - a valid record (`role=critic-falsifier`, real registry) ⇒
    `VALID: <path> conforms to dmc.delegation.v1`, **exit 0**.
  - the same record with `role=not-a-real-role` ⇒ `REFUSED: DELEG-ROLE-UNRESOLVED: ...`,
    **exit 3**.
  - `validate` with no path ⇒ usage error, **exit 2**.
  - no subcommand at all ⇒ usage error, **exit 2**.
- Negative controls (each a real REFUSE — exit 3 at the CLI, or a non-empty reason list in-process):

  | Plan §DMC-T010c negative control | Reason code | Self-test |
  |---|---|---|
  | a `role` absent from roles.json | `DELEG-ROLE-UNRESOLVED` | N1 |
  | `may_mutate: true` with no scope-lock reference | `DELEG-NO-SCOPE-LOCK` | N2 |
  | `depth > max_depth` | `DELEG-DEPTH-EXCEEDS-MAX` | N3 |
  | consumption recorded with `validation_verdict != PASS` | `DELEG-UNVALIDATED-CONSUMPTION` | N4 (×2: FAIL, PENDING) |
  | (hardening) missing binding field (work_id) | `DELEG-MISSING-BINDING` | N5 |
  | (hardening) bad enum (capability_class) | `DELEG-BAD-CLASS` | N6 |
  | (hardening) tampered/duplicate JSON key | `DELEG-UNREADABLE` | N7 |
  | (hardening) secret-shaped field content | `DELEG-SECRET-SHAPED` | N8 |
  | (extra) illegal mutator (non-executor role, may_mutate:true) | `DELEG-ILLEGAL-MUTATOR` | N9 |
  | (extra) bad hash shape (plan_hash) | `DELEG-BAD-HASH` | N10 |
  | (extra) bad prev_hash shape | `DELEG-BAD-PREV-HASH` | N11 |
  | (extra) wrong schema id | `DELEG-BAD-SCHEMA` | N12 |
  | (extra) may_mutate not a bool | `DELEG-MUTATE-NOT-BOOL` | N13 |
  | (extra) negative depth | `DELEG-BAD-DEPTH` | N14 |
  | (extra) max_depth < 1 | `DELEG-BAD-MAX-DEPTH` | N15 |
  | (extra) bad validation_verdict value | `DELEG-BAD-VERDICT` | N16 |
  | (extra) artifact_ref without artifact_schema | `DELEG-ARTIFACT-SCHEMA-MISSING` | N17 |
  | (extra) artifact_schema without artifact_ref | `DELEG-ARTIFACT-REF-ORPHAN-SCHEMA` | N18 |
  | (extra) role field missing entirely | `DELEG-ROLE-MISSING` | N19 |
  | (extra) fail-closed on broken registry path | `DELEG-ROLE-UNRESOLVED` | N20 |
  | (extra) top-level non-object document | `DELEG-NOT-OBJECT` | N22 |

  All four plan-mandated negative controls (N1–N4) REFUSE with the expected named reason code.
- Positive controls: D0 (real registry, read-only role) and D1 (real registry, executor role with
  `may_mutate:true` + `scope_lock_ref`) and D2 (a consumption record with `validation_verdict:
  PASS`) all ACCEPT (empty reason list). D3 exercises the full `read_text → parse → validate`
  pipeline via `validate_file()` on a tempdir fixture (not just the in-process dict-level function).
- Determinism (**N21**): identical input ⇒ identical reason list.
- Hermeticity (**N24**): `git status --porcelain` over the real repo root, snapshotted before and
  after the self-test's tempdir-based fixture work, is unchanged (degrades to a no-op pass if `git`
  is unavailable, matching the established no-git-fallback convention). Independently confirmed by
  hand: `git status --porcelain` after the full self-test + CLI run above shows only the two
  files this task creates (`bin/lib/dmc-delegation.py`, this evidence file) plus other workers'
  pre-existing in-flight paths (`dmc-critic-verdict.py`, `dmc-verdict-gate.py`, the agent `.md`
  rewrites, `orchestration/`, `dmc-roles.py`) — nothing this task touches beyond its own two files.
- `__pycache__`: none produced (`find bin -iname __pycache__` empty); the script is run directly
  and imports stdlib only.

## Judgment calls (summary)

1. **`scope_lock_ref` field name** invented for the schema's undocumented scope-lock reference (see
   dedicated section above) — a schema-shape check only, not a cross-validation of the referenced
   lock's content.
2. **Consumption == non-null `artifact_ref`** — chosen interpretation of "consuming an artifact"
   absent an explicit boolean flag in the schema (see dedicated section above).
3. Reused the codebase's standard `HASH_RE = ^[0-9a-f]{16,}$` (lowercase-only hex) for `plan_hash`/
   `repo_hash`/`prev_hash`, matching every other validator in `bin/lib/` rather than inventing a
   case-insensitive variant.
4. Role resolution's registry-mutation-capability check reads `may_mutate` **from the resolved
   role record returned by the lookup subprocess**, not from a hardcoded role id (e.g. not a
   literal `"implementer"` string check) — so the delegation validator stays correct even if the
   registry's mutation-capable role identity ever changes, without needing an edit here.

## Escalation check

Role resolution did **not** prove subtle enough to require escalation to Opus: T010a's lookup
subprocess contract (documented in `bin/lib/dmc-roles.py`'s own docstring) is a clean exit-0-plus-
JSON / exit-3 boundary, and composing against it was mechanical. The one open judgment call (the
scope-lock reference field name) is a schema-shape naming choice within this task's explicit
"judgment calls" reporting channel, not a role-resolution subtlety, and does not touch role
resolution correctness.

## Rollback

Delete `bin/lib/dmc-delegation.py` (and this evidence file). Nothing consumes this module at
runtime yet — the M3/M4 selftest surface (default 75/0) and the pinned legacy baseline are
unchanged. The `bin/dmc` `delegation` arm does not exist yet (T010f owns it).

## Not-edit confirmation

Not touched: `bin/dmc`, `orchestration/roles.json`, `bin/lib/dmc-roles.py` (consumed read-only, via
subprocess only — never opened/parsed directly by this module), any M4 run-lifecycle module,
`bin/lib/dmc-instance-validate.py`, the six M3 schema docs (including
`.harness/schemas/delegation.schema.md` itself), `.claude/**`, `.claude/hooks/*`,
`.claude/settings.json`, `.claude/workers/**`, `.claude/install/*`, `orchestration/models.json`,
any `.harness/evidence/dmc-v0.*` original or its `bin/lib` copy, `docs/**`, `docs/MILESTONES.md`,
main/master, and every other in-flight worker's file (`dmc-critic-verdict.py`,
`dmc-verdict-gate.py`, the six agent contracts under `.claude/agents/`). No new `bin/lib/dmc-v0.*`
filename. No git add/commit/push. No live/network/secret paths. No `__pycache__` produced.
