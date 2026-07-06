# Link-check positive fixture — every reference resolves

NOT part of the real scanned surface; consumed only by dmc-orchestration-linkcheck.py --self-test.

## Registry binding

- Role: `implementer` in `orchestration/roles.json` (capability class `standard-implementation`).

## Contract I/O

- Consumes (schema-in): `.harness/schemas/plan.schema.md` and `.harness/schemas/scope-lock.schema.md`.
- Emits (schema-out): `.harness/schemas/evidence-receipt.schema.md`.

Armed by `dmc run start`; the verdict is validated by `dmc verdict validate`; the registry is
validated by `bin/dmc roles validate`. Every dmc-verb, artifact-path, and role reference here
resolves, so the link-check must report this fixture CLEAN.
