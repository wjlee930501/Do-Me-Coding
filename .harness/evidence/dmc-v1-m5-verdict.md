# DMC v1.0 M5 — Critic-verdict validator + verdict-gate (DMC-T010b)

- run_id: `dmc-v1-m5-20260706`
- date: 2026-07-06
- branch: `claude/dmc-v1-runtime-upgrade-c5uch1`
- plan: `.harness/plans/dmc-v1-m5-orchestration.md` (APPROVED 2026-07-06, approver wjlee) §DMC-T010b
- primitive: P16 — the critic verdict as a machine-checkable artifact (`dmc-critic-verdict.py`) and
  a deterministic Ring-0 start-work precondition (`dmc-verdict-gate.py`). Implements the M3 contract
  `.harness/schemas/critic-verdict.schema.md` ("validator lands in M5").
- invariant: **C11** — the verdict is advisory evidence, never a grant. The validator refuses
  `advisory != true`; the gate opens nothing (refuse or pass-through only) and is value-blind on the
  verdict decision.
- scope of this task: additive only, two new `bin/lib` modules + this evidence log. Per the
  single-owner rule, `bin/dmc` is NOT touched — T010f registers the `verdict` verb + selftest
  section; both modules are fully usable standalone via `python3 bin/lib/<module>`.

## Files created

| Path | Change | In-scope |
|---|---|---|
| bin/lib/dmc-critic-verdict.py | new — P16 `validate <path>` validator + hermetic `--self-test` | yes (T010b) |
| bin/lib/dmc-verdict-gate.py | new — Ring-0 `gate --verdict <f> --plan-hash <h>` + hermetic `--self-test` | yes (T010b) |
| .harness/evidence/dmc-v1-m5-verdict.md | new — this evidence log | yes (T010b) |

## Validator design (`dmc-critic-verdict.py`)

- House style copied from `bin/lib/dmc-roles.py` / `bin/lib/dmc-instance-validate.py`: stdlib-only,
  env-free, offline (no network/git), input-only, value-blind `VERDICT-*` reason codes (name schema
  constants/enums, never a document value), `object_pairs_hook` duplicate-JSON-key rejection,
  secret-path refused by path, fail-closed. `validate <path>` ⇒ ACCEPT exit 0 / REFUSE exit 3 /
  usage exit 2.
- Enforced per `critic-verdict.schema.md`:
  - `schema` exact `dmc.critic-verdict.v1`.
  - **Subject binding:** `work_id` + `target_ref` non-empty single-line; `plan_hash` / `repo_hash`
    hash-shaped via `HASH_RE = ^[0-9a-f]{16,}$` (the same shape the M4 run-lifecycle uses for
    `<hex >=16>`).
  - **`verdict` enum** ∈ {APPROVE, REJECT, NEEDS_CLARIFICATION}.
  - **`REJECT ⇒ non-empty blockers`**, and every blocker is an object with a non-empty `id` and a
    non-empty `statement` (no vague blocker / no vague rejection).
  - **`advisory == true`** (boolean, strict — `is not True`), enforcing C11.
  - **Author-role sanity:** `context_provenance` ∈ {fresh, shared} (both are valid recorded values;
    see the fresh-vs-shared judgment call below).
  - `lenses` is a non-empty list of non-empty strings.
  - `criteria_checked` (if present) is a list of objects each with `criterion_ref` non-empty and
    `result` ∈ {met, unmet, na}.

## Gate design (`dmc-verdict-gate.py`)

- `gate --verdict <file> --plan-hash <hex>` ⇒ REFUSE exit 3 / PASS-THROUGH exit 0 / usage exit 2.
  **The gate opens nothing (C11):** its only outcomes are refuse or pass-through; it writes,
  approves, and mutates nothing (self-test G8 asserts the tempdir listing is byte-identical
  before/after a gate call).
- Refusal conditions (the three the plan enumerates + hardening):
  - `GATE-VERDICT-ABSENT` — no file at the referenced path.
  - `GATE-VERDICT-INVALID` — the verdict fails `dmc-critic-verdict validate`, invoked as a
    **read-only subprocess** (`[sys.executable, <sibling>, "validate", path]`), not an import — so
    the validator stays independently deletable (plan preference). A non-3 non-0 validator exit is
    caught fail-closed as `GATE-VALIDATOR-ERROR`.
  - `GATE-PLAN-HASH-MISMATCH` — the verdict's embedded `plan_hash` ≠ the caller-supplied
    `--plan-hash` (binding failure).
  - hardening: `GATE-SECRET-PATH` (secret-shaped verdict path, refused without opening),
    `GATE-BAD-PLAN-HASH-ARG` (malformed `--plan-hash`), `GATE-VERDICT-BAD-HASH` (embedded hash not
    hash-shaped), `GATE-VERDICT-UNREADABLE`.
- **Value-blind on the decision (C11, load-bearing):** the gate proves only that an independent
  critic reviewed THIS plan (present + schema-valid + plan-bound). A well-formed, plan-bound
  `REJECT` PASSES exactly like an `APPROVE` (self-test G1) — the gate never reads the verdict value
  as an approval. Approval is a P17 human-gate record; refusing to start work on a REJECTed plan is
  the Ring-1 wiring's job (M6), not this Ring-0 binding gate.

## Layer disclosure (plan Acceptance Criterion 3 / carry-forward note 3)

The **refusal** is produced by **Ring-0 `dmc verdict gate`** — deterministic: it validates the
referenced `critic-verdict.json` and REFUSES if absent, schema-invalid, or `plan_hash` ≠ the run's.
The **obligation** to invoke the gate before mutating is **Ring-2 skill prose** (dmc-start-work /
dmc-ultrawork, wired in T010e) until **M6** wires the Ring-1 Stop/scope hooks. No claim of runtime
traversal enforcement is made in M5.

## Judgment calls

- **Validator vs gate CLI shape.** Validator mirrors `dmc-roles.py`: positional `validate <path>`
  + `--self-test`. Gate takes the plan's verbatim shape `gate --verdict <f> --plan-hash <h>`
  (positional `gate` optional; `--self-test` alternative). Both keep exit codes 0/3/2 consistent
  with the M3/M4 tools so T010f can aggregate them into `bin/dmc selftest verdict` unchanged.
- **`verdict` field set vs schema.** I enforced every rule the schema states as validator-enforced
  and fail-closed (§Rules lines 27–37): schema-exact, subject binding, verdict enum, REJECT⇒blockers
  (+ non-empty blocker statement), advisory==true, context_provenance enum, non-empty `lenses`.
  `criteria_checked` is shape-checked when present. The schema's **`security`-lens-when-touching-an-
  enforcement-landmark** rule is explicitly "enforced by the consumer" (it needs the P2 landmark
  set), so it is deliberately NOT in this value-blind validator — it belongs to the Ring-1 consumer
  (M6). `note` fields are treated as advisory free-form and never inspected for value (only the
  secret-material hardening scan, which returns a bool and never emits the match).
- **fresh vs shared (binding independence).** The schema says a *binding* review requires `fresh`
  and that `shared` is "flagged, not consumed as independent" — and that this, like the security
  lens, is "enforced by the consumer." I therefore (a) make the **validator** accept both {fresh,
  shared} as structurally valid enum values (a `shared` verdict is a well-formed artifact), and
  (b) keep the **gate** to exactly the three plan-enumerated refusals so a plan-bound "valid pair"
  passes as the plan requires. Enforcing `fresh`-independence at the point of *consumption* is the
  Ring-1 concern (M6). This is flagged so T010e/T010f know the gate is intentionally not a
  fresh-vs-shared filter.
- **Secret-material hardening.** Added a conservative, high-precision, value-blind content scan
  (PEM private-key header, `AKIA…`, `gh[pousr]_…`, `xox[baprs]-…`, `sk-…`) so a credential inlined
  into an advisory artifact is refused (`VERDICT-SECRET-CONTENT`) without ever printing the match —
  the same posture as the existing `bin/lib` secret detectors.

## Verification results

- `python3 -m py_compile bin/lib/dmc-critic-verdict.py bin/lib/dmc-verdict-gate.py` ⇒ clean.
- `python3 bin/lib/dmc-critic-verdict.py --self-test` ⇒ **`[verdict-validate] 16 PASS / 0 FAIL`,
  exit 0.**
- `python3 bin/lib/dmc-verdict-gate.py --self-test` ⇒ **`[verdict-gate] 9 PASS / 0 FAIL`, exit 0.**
  (The gate self-test shells out to the sibling validator, exercising the real subprocess path.)
- CLI exit-code contract confirmed directly:
  - `validate <valid>` ⇒ `VALID: … conforms to dmc.critic-verdict.v1`, exit 0.
  - `validate <REJECT-empty-blockers>` ⇒ `REFUSED: VERDICT-REJECT-NO-BLOCKERS`, exit 3.
  - `gate` valid pair ⇒ `PASS: verdict gate — … (C11: no gate opened…)`, exit 0.
  - `gate` plan_hash mismatch ⇒ `REFUSED: GATE-PLAN-HASH-MISMATCH`, exit 3.
  - `gate` absent verdict ⇒ `REFUSED: GATE-VERDICT-ABSENT`, exit 3.
  - `gate --verdict` without `--plan-hash` ⇒ usage error, exit 2.
- All fixtures are written to `tempfile.TemporaryDirectory()`; the real repo is untouched.

## Negative controls (each a real REFUSE — exit 3 at the CLI / non-empty reason list in-process)

| Plan §DMC-T010b negative control | Reason code | Self-test |
|---|---|---|
| REJECT with empty `blockers` | `VERDICT-REJECT-NO-BLOCKERS` | C2 |
| `advisory != true` (C11) | `VERDICT-NOT-ADVISORY` | C3 |
| a missing subject-binding field (`work_id`) | `VERDICT-FIELD-MISSING` | C4 |
| verdict-gate with no verdict file | `GATE-VERDICT-ABSENT` | G2 |
| verdict-gate with mismatched `plan_hash` | `GATE-PLAN-HASH-MISMATCH` | G3 |
| (hardening) subject `plan_hash` not hash-shaped | `VERDICT-BAD-HASH` | C5 |
| (hardening) unknown `verdict` value | `VERDICT-BAD-VERDICT` | C6 |
| (hardening) `context_provenance` outside enum | `VERDICT-BAD-PROVENANCE` | C7 |
| (hardening) empty `lenses` | `VERDICT-BAD-LENSES` | C8 |
| (hardening) blocker with empty `statement` | `VERDICT-BLOCKER-BAD` | C9 |
| (hardening) wrong `schema` id | `VERDICT-BAD-SCHEMA` | C10 |
| (hardening) `criteria_checked[].result` outside enum | `VERDICT-CRITERIA-BAD` | C11 |
| (hardening) duplicate JSON key (tamper/ambiguity) | `VERDICT-UNREADABLE` | C12 |
| (hardening) secret-shaped content inline | `VERDICT-SECRET-CONTENT` | C13 |
| (hardening) gate: schema-invalid verdict via subprocess | `GATE-VERDICT-INVALID` | G4 |
| (hardening) gate: malformed `--plan-hash` arg | `GATE-BAD-PLAN-HASH-ARG` | G5 |
| (hardening) gate: secret-shaped verdict path | `GATE-SECRET-PATH` | G7 |

Positive controls: valid APPROVE ACCEPTED (C0); well-formed REJECT-with-blocker ACCEPTED (C1);
valid pair PASSES the gate (G0); plan-bound REJECT PASSES the gate (G1, the C11 value-blind proof).
Determinism asserted for both modules (C14 / G6). Secret-path filter asserted (C15 / G7). The gate
writes nothing (G8).

## Hand-off note for the verifier (T010f)

- **Aggregation:** the `verdict` selftest section should call `python3 bin/lib/dmc-critic-verdict.py
  --self-test` (16/0) and `python3 bin/lib/dmc-verdict-gate.py --self-test` (9/0), and the `dmc
  verdict validate` / `dmc verdict gate` verbs should route to `validate <path>` and
  `gate --verdict <f> --plan-hash <h>` respectively. Neither module reads argv[0]/`bin/dmc`; both
  compute paths from `__file__`, so the gate finds the validator sibling regardless of cwd.
- **Secret-detector literals in `bin/`.** `dmc-critic-verdict.py` carries secret-material detector
  patterns (a PEM header string, `AKIA…`, `sk-…`, `gh[pousr]_…`, `xox[baprs]-…`), exactly as ~10
  existing `bin/lib` modules already do (e.g. `dmc-v0.6.2-evidence-receipt.py`) with the legacy
  baseline green. The source contains **no** real-token-shaped literal (patterns are bracketed or,
  in the self-test, split via concatenation — confirmed by a one-token grep returning empty), so a
  content secret-scan will not flag it. This is expected, not a leak.
- The plan-mandated **model-name-free** grep (`orchestration/ .claude/agents/`) does not cover
  `bin/`; neither module contains any model-name token (grep clean).

## Rollback

Delete `bin/lib/dmc-critic-verdict.py`, `bin/lib/dmc-verdict-gate.py`, and this evidence file.
Nothing consumes either at runtime yet — the M3/M4 selftest surface (default 75/0) and the pinned
legacy baseline are unchanged. The `bin/dmc` `verdict` arm does not exist yet (T010f owns it).

## Not-edit confirmation

Not touched: `bin/dmc`, any M4 run-lifecycle module, `bin/lib/dmc-instance-validate.py`,
`bin/lib/dmc-roles.py` (T010a), `bin/lib/dmc-delegation.py` (T010c), the M3 schema docs,
`orchestration/**` (T010a), `.claude/**` (T010d/e own agents/skills), `.claude/hooks/*`,
`.claude/settings.json`, `.claude/workers/**`, `.claude/install/*`, any `.harness/evidence/dmc-v0.*`
original or its bin/lib copy, `docs/**`, `docs/MILESTONES.md`, main/master. No new
`bin/lib/dmc-v0.*` filename. No git add/commit/push. No live/network/secret paths. `git
status --porcelain` shows only my two new `bin/lib/*.py` paths (plus this evidence file) as mine;
`__pycache__` swept.
