# Link-check negative fixture — all three dangling classes at once

NOT part of the real scanned surface; consumed only by dmc-orchestration-linkcheck.py --self-test.

## Registry binding

- Role: `ghost-role` in `orchestration/roles.json`.

## Contract I/O

- Consumes (schema-in): `.harness/schemas/ghost.schema.md` (does not exist).
- Emits via `dmc frobnicate` (not a declared verb).

Each of the three dangling references (unknown verb, dangling path, unregistered role) must be
named by the link-check.
