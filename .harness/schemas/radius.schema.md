# dmc.radius.v1 — Change Radius prediction (P5)

Produced by `bin/dmc radius`; validated by `bin/dmc radius --validate <file>` (fail-closed;
REFUSED ⇒ exit 3). Advisory tier: the runtime enforcement floor stays the hooks.

Turns depsurface + landmarks + a proposed scope into a blast list whose every entry is bound
to verification checks (v1.0 architecture P5; FABLE_WORKFLOW_TRANSFER B5 — "radius theater"
is schema-refused).

```json
{
  "schema": "dmc.radius.v1",
  "head": "<commit sha | no-git>",
  "scope": ["<relpath>"],
  "entries": [{
    "path": "<relpath>",
    "dependents": ["<relpath>"],
    "dependent_count": <int == len(dependents)>,
    "landmark_class": "enforcement|contract|release|data|ordinary",
    "unscanned": <bool>,
    "check_ids": ["<non-empty check id>"]
  }]
}
```

Rules (validator- and generator-enforced, fail-closed):
- **Every entry MUST carry ≥1 non-empty `check_id`.** A scoped path with no supplied check
  mapping ⇒ the generator REFUSES the whole artifact (exit 3) — it never emits a checkless
  entry. This refusal must never be weakened for testing; self-tests supply *synthetic*
  check-ids instead (critic carry-forward note 2).
- One entry per scope path (no drops, no dups): `entries[].path` set == `scope` set.
- `dependent_count` must equal `len(dependents)`; `landmark_class` ∈ the five-class enum;
  `unscanned: true` required when the path is in the depsurface `unscanned` list
  (radius-unknown escalation).
- All paths relative, no `..`. Deterministic: sorted; byte-identical for identical inputs.

Check-id semantics: in v1.0 check-ids resolve into `acceptance.json` (P8, lands in M4). Until
M4, callers bind them to plan Verification Commands rows; the id namespace is free-form
non-empty strings. Cross-resolution into acceptance.json is enforced by the M4 validator, not
here (declared forward dependency, not a hidden gap).
