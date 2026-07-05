# dmc.scope-lock.v1 — Scope Lock artifact (P7)

Compiled by the M4 run-lifecycle core (`dmc run start`) from an APPROVED plan; adjudicated by the
Ring-1 write guards on every mutation. Validator lands in M4 (run-core); this schema is the
contract it will enforce (declared forward dependency, not a hidden gap — mirrors the
`radius.schema.md` pattern). Fail-closed, value-blind: the checker reads structure, never echoes
path contents; the runtime enforcement floor stays the hooks.

Immutable-after-approval compilation of the plan's authorized file scope + minimal-diff bounds
(v1.0 architecture P7/P6; FABLE_WORKFLOW_TRANSFER B4). Every mutation the harness sees is
adjudicated against this file; it is never edited in place — amendment = new plan revision +
re-approval (§0.4 integrity rule).

```json
{
  "schema": "dmc.scope-lock.v1",
  "work_id": "<canonical subject id>",
  "plan_hash": "<hex >=16>",
  "repo_hash": "<hex >=16>",
  "run_id": "<run id>",
  "approved_by": "<human-gate auth id | non-empty>",
  "files": [{"path": "<relpath>", "grant": "edit|create", "landmark_class": "enforcement|contract|release|data|ordinary"}],
  "bounds": {"max_files": <int >=0>, "max_added": <int >=0>, "max_deleted": <int >=0, "forbidden_hunk_classes": ["<class>"]},
  "immutable": true,
  "compiled_at_head": "<commit sha | no-git>",
  "prev_hash": "<hex | genesis>"
}
```

Rules (validator-enforced, fail-closed):
- `schema` exact; the three subject-binding fields (`work_id`, `plan_hash`, `repo_hash`) present
  and non-empty (v0.6.1.0 canonical binding); `approved_by` non-empty (no lock without a human
  approval reference — approval provenance, not authentication, honest-scope label).
- Every `files[].path` is a relative path with no `..`; `grant` ∈ {edit, create}; `landmark_class`
  ∈ the five-class enum. A path carrying a non-`ordinary` landmark class must trace to an explicit
  plan authorization (landmark edits are never implicit — P2/P7 interaction).
- `bounds` ints ≥ 0; `forbidden_hunk_classes` is a (possibly empty) string list. Bounds are the
  P6 minimal-diff envelope enforced at runtime by P7.
- `immutable` must be `true`; `prev_hash` present (hash-chain: tamper is detectable at Ring 0,
  in-place edit denied at Ring 1). Deterministic: sorted keys/lists, byte-identical for identical
  inputs.

Negative controls the M4 validator must REFUSE: missing/empty `approved_by`; a `files[].path` with
`..` or absolute; `immutable != true`; a negative bound; a non-enum `landmark_class`.

Consumers: P6 (bounds), P14 (worker `allowed_files` ⊆ run scope at apply time), P18 (final
`diff --name-only` ⊆ scope, git ground truth). Immutable post-approval per architecture §0.4.
