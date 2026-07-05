# dmc.landmarks.v1 — Architecture Landmark map (P2)

Produced by `bin/dmc landmarks`; validated by `bin/dmc landmarks --validate <file>`
(fail-closed; REFUSED ⇒ exit 3). Advisory tier: the runtime enforcement floor stays the hooks.

Replaces hand-maintained protected-path prose lists with one generated artifact (v1.0
architecture P2; audit §12). Only non-`ordinary` paths are emitted.

```json
{
  "schema": "dmc.landmarks.v1",
  "head": "<commit sha | no-git>",
  "seed": "heuristics+dmc-protected-union-v1",
  "classes": ["enforcement", "contract", "release", "data", "ordinary"],
  "landmarks": [{"path": "<relative path>", "class": "<class>", "reason": "<heuristic id>"}]
}
```

Class semantics:
- **enforcement** — code that gates behavior: hooks, hook wiring/settings, guards, CI
  workflows, installers, the `dmc` runtime itself, harness adapters.
- **contract** — machine-consumed interfaces: `*.schema.md` / `*_SCHEMA.md`, provider
  contract/router surface, package manifests and lockfiles.
- **release** — release/closure records: `docs/MILESTONES.md`, CHANGELOG*, VERSION.
- **data** — irreversible-data surfaces: migrations, `*.sql`, prisma/drizzle.
- **ordinary** — everything else (never listed; implied default).

Rules (validator-enforced):
- `schema` exact; `classes` must equal the five-class enum verbatim; every `landmarks[].class`
  ∈ enum and ≠ `ordinary`; paths relative, unique, no `..`; every entry carries a non-empty
  `reason`.
- Deterministic: same tree ⇒ byte-identical output (sorted by path).
- The seed union includes the historical DMC protected set (hooks, settings, providers,
  install, `dmc-glm-smoke`) so no legacy-protected path silently declassifies (audit §5 note).

Consumers: P5 radius (landmark class per scoped path), P7 scope lock (landmark edits require
explicit plan authorization), P16 critic, P18 release gate — wired in their own milestones.
