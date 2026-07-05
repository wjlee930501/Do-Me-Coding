# dmc.depsurface.v1 — Dependency Surface map (P4, regex tier)

Produced by `bin/dmc depsurface`; validated by `bin/dmc depsurface --validate <file>`
(fail-closed; REFUSED ⇒ exit 3). Advisory tier: the runtime enforcement floor stays the hooks.

Inbound/outbound reference map for change-radius prediction (v1.0 architecture P4;
FABLE_WORKFLOW_TRANSFER B5). **Regex tier — best-effort, known-shapes-only, not a
completeness guarantee** (v0.4.4 honesty pattern): static import/require/source forms in
py/js/ts/sh only; dynamic imports are invisible. AST/LSP tier is deferred (v0.6.0 defer card).

```json
{
  "schema": "dmc.depsurface.v1",
  "head": "<commit sha | no-git>",
  "note": "regex tier; known-shapes-only; not a completeness guarantee",
  "files": {"<relpath>": {"lang": "py|js|sh",
                           "imports_internal": ["<relpath resolved inside root>"],
                           "imports_external": ["<raw unresolved specifier>"]}},
  "inbound": {"<relpath>": ["<dependent relpath>"]},
  "unscanned": ["<relpath with unrecognized extension>"]
}
```

Rules (validator-enforced):
- `schema` exact; all keys required; `note` must carry the non-completeness attestation.
- Every `imports_internal` target and every `inbound` key/value is a relative path with no
  `..`; `inbound` must be the exact inversion of `imports_internal` (cross-checked).
- `unscanned` paths must not appear in `files` (a path is scanned or labeled, never both).
- Deterministic: sorted keys/lists; byte-identical at the same tree.
- Secret-bearing paths are excluded by path (never opened, never listed).

Consumer contract: P5 must treat a scoped path appearing in `unscanned` as **radius-unknown**
(escalates review depth rather than silently reporting zero dependents).
