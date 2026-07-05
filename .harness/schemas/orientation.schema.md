# dmc.orientation.v1 — Repository Orientation artifact (P1)

Produced by `bin/dmc orient` (core: `bin/lib/dmc-repo-intel.py`). Validated by
`bin/dmc orient --validate <file>` (fail-closed; REFUSED ⇒ exit 3). Advisory tier: the runtime
enforcement floor stays the hooks.

Machine-readable map a plan's Current Repo Findings must cite (v1.0 architecture P1;
FABLE_WORKFLOW_TRANSFER B1). Deterministic at a fixed HEAD: no wall-clock timestamps, sorted
keys/lists; `head_time` is the HEAD **commit** time, not generation time.

```json
{
  "schema": "dmc.orientation.v1",
  "root_kind": "git | plain",
  "head": "<commit sha | no-git>",
  "head_time": "<HEAD committer date ISO-8601 | no-git>",
  "languages": {"<ext>": <file count>},
  "manifests": ["<relative path>"],
  "package_managers": ["npm | python | cargo | go | make"],
  "verify_commands": [{"command": "<cmd>", "source": "<manifest>:<field> | <path>"}],
  "entrypoints": [{"path_or_module": "<str>", "source": "<manifest>:<field>"}],
  "doc_roots": ["<relative path>"],
  "unknowns": ["<explicit unknown statement>"]
}
```

Rules (validator-enforced):
- `schema` must be exactly `dmc.orientation.v1`; all keys above required (arrays may be empty).
- `root_kind` ∈ {git, plain}; `head`/`head_time` are `no-git` iff root_kind is `plain`.
- Every `verify_commands[].source` and `entrypoints[].source` must name its evidence — no
  evidence, no entry (AGENTS.md Rule 7: unknown is marked unknown, in `unknowns`).
- Secret-bearing paths are never opened during generation (path-only exclusion mirroring
  DMC.md §Secret Protection); they never appear in any field.
- With `--root`, listed `manifests`/`doc_roots` must exist under the root (stale map ⇒ REFUSED).

Freshness: consumers must refuse an orientation whose `head` ≠ current HEAD unless explicitly
marked stale-accepted (plan-time rule; enforced by the M4+ plan validator, not here).
