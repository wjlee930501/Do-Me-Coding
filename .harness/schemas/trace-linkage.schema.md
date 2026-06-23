# trace-linkage.schema.md

The `dmc.trace-linkage.v1` record — the foundational **Trace Linkage Contract** (DMC v0.6.1.0). Additive; advisory;
**input-only**; **value-blind (reject-on-match)**. It binds one work item's whole trace to a single canonical subject so the
v0.6.1–v0.6.5 gates compose into one auditable chain and the six-question metric (Q1–Q6) is answerable from artifacts alone —
and so a valid-but-unrelated set of IDs **cannot** be assembled into a false trace. Defines + validates *shape and binding*,
not minting (producers mint IDs later). See roadmap `.harness/plans/dmc-v0.6.1-v0.6.5-roadmap.md` §1.1.

```text
{
  "schema": "dmc.trace-linkage.v1",
  "subject": {                          # the ONE canonical subject of this record (required; all five fields)
    "work_id":          "<opaque>",     # value-blind
    "plan_hash":        "<hash-shaped>",# hex, >=16
    "milestone_id":     "<this record's milestone, e.g. v0.6.1.0>",
    "repo_hash":        "<hash-shaped>",# hex, >=16
    "verification_ref": "<ref-shaped>"  # non-empty, single-line
  },
  "registers": {                        # typed reference registers; EACH entry re-binds the subject
    "capability": [ {"kind":"capability_class","id":"<one of the six classes>","producer_milestone_id":"v0.6.1", <subject-binding>} ],
    "evidence":   [ {"kind":"evidence_receipt","id":"<opaque>","producer_milestone_id":"v0.6.2", <subject-binding>} ],
    "finding":    [ {"kind":"finding","id":"<opaque>","state":"<one of the four states>","producer_milestone_id":"v0.6.3", <subject-binding>} ],
    "goal":       [ {"kind":"goal","id":"<preexisting v0.4.1 goal_id>","producer_milestone_id":"v0.4.1", <subject-binding>} ],
    "decision":   [ {"kind":"decision","id":"<opaque>","producer_milestone_id":"v0.6.5", <subject-binding>} ],
    "approval":   [ {"kind":"approval","id":"<opaque>","type":"human-release-gate","source":"human-release-gate:<auth-id>","producer_milestone_id":"human-release-gate", <subject-binding>} ]
  },
  "edges": [ {"from":{"kind":"<entry-kind>","id":"<i>"}, "to":{"kind":"<entry-kind>","id":"<i>"}} ]
}
```
`<subject-binding>` on every register entry = its own `work_id`, `plan_hash`, `repo_hash`, `verification_ref`.

## Subject-binding fields (all five required, non-empty)
`work_id` · `plan_hash` (hex ≥16) · `milestone_id` · `repo_hash` (hex ≥16) · `verification_ref` (non-empty, single-line).

## Capability classes (the six, from `docs/ORCHESTRATION_TAXONOMY.md` Output 2)
`frontier-long-horizon` · `standard-implementation` · `cheap-fast` · `adversarial-review` · `deterministic-tool` ·
`human-only-gate`. (`capability_class.id` MUST be one of these.)

## Finding states (the four)
`resolved` · `accepted-risk` · `deferred` · `blocked`. (`finding.state` MUST be one of these.)

## `kind` → `producer_milestone_id` table (verbatim; the validator hardcodes this — must not drift)
| register | entry `kind` | required `producer_milestone_id` |
|----------|--------------|----------------------------------|
| capability | `capability_class` | `v0.6.1` |
| evidence | `evidence_receipt` | `v0.6.2` |
| finding | `finding` | `v0.6.3` |
| goal | `goal` | `v0.4.1` (preexisting goal-plan ref — syntactic only here) |
| decision | `decision` | `v0.6.5` |
| approval | `approval` | `human-release-gate` |

## Allowed `approval.source` namespace (positive allowlist, NOT a denylist)
`approval.source` MUST match the exact prefix **`human-release-gate:`**. Any other source — an arbitrary non-human string, a
critic/Codex/plan ACCEPT id, or any unrecognized value — is REJECTED (R12; a critic/Codex ACCEPT is advisory, never an
approval). `approval.type` MUST be `human-release-gate`, and the approval entry MUST re-bind the subject.

## Referential-integrity rules (the load-bearing per-reference / per-edge re-bind rule)
1. **Per-reference re-bind (R9/R10):** every register entry's `work_id`/`plan_hash`/`repo_hash`/`verification_ref` MUST equal
   the subject's. A cross-subject or mismatched-binding entry → REJECT (this is what prevents false-trace assembly).
2. **Global uniqueness (R11):** `(entry-kind, id)` MUST be unique across ALL registers.
3. **Typed edges (R9):** every `edges[].{from,to}` is `{kind,id}`; both endpoints MUST be a declared `(kind,id)` in the
   registers (no dangling), and the endpoint `kind` MUST match the register the `id` lives in (no type confusion).
4. **Producer provenance:** every entry's `producer_milestone_id` MUST match the table above for its `kind`.
5. **Completeness (a VALID record is a COMPLETE trace):** all six register keys MUST be present; the five answer-bearing
   registers (`capability`, `evidence`, `goal`, `decision`, `approval`) MUST be **non-empty** so Q1/Q2/Q4/Q5/Q6 are
   answerable; `finding` may be empty ("no findings" is a valid Q3 answer). An empty or approval-less record → REJECT.

## Validation modes (record vs entry)
A producer milestone (v0.6.1–v0.6.5) mints **one register entry** (a fragment), not a complete trace. So the validator has two
modes: **record-level** (`--validate`) checks a COMPLETE trace — rules 1–5 + edges + cross-subject; **entry-level**
(`--validate-entry <register-key>`) checks a single entry's **well-formedness** (kind / producer / id / enum / binding-fields
present + hash-shaped / approval type+source / no-secret / no-duplicate-JSON-key). Cross-subject, completeness, and edges stay
**record-level** (composed + validated by v0.6.5). A path of `-` reads stdin (no temp file).

## Value-blind (reject-on-match; no sanitized output)
A **recursive** scan over all keys, values, nested objects, arrays, `edges[].{from,to}`, and `approval[].{source,id}`. Any
secret-shaped string (the v0.5.0 UNSAFE shape set — `sk-`/`AKIA`/PEM/`gh[opsu]_`/`github_pat_`/`glpat-`/`npm_`/`AIza`/
`dop_v1_`/`xox*`/JWT/`Bearer`/`ya29.`/`AccountKey=`/OAuth `*_token`/bare `password=`/`api_key=`/`client_secret=`) → REJECT.
This validator **rejects on match**; it emits no sanitized artifact. Best-effort, not a completeness guarantee — review before
commit.

## Invariants
Deterministic (same record → same verdict, byte-identical); **env-independent** (`env -i` + hostile credential var → same
verdict; reads no `.env`/credential/network); **input-only** (`--validate` reads ONLY the record file and **never calls
git**). JSON is parsed with a **duplicate-key-rejecting loader** (any duplicate key at any object level → REJECT). Current-head
*staleness/replay* vs the live tree is **out of scope** here (deferred to the producer validators v0.6.2+); this contract
checks only the record's **internal** subject consistency. Advisory / fail-closed; the runtime enforcement floor stays the
hooks.
