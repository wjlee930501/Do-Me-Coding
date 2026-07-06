# Link-check negative fixture — dangling artifact path

NOT part of the real scanned surface; consumed only by dmc-orchestration-linkcheck.py --self-test.

This contract claims to consume `.harness/schemas/nonexistent.schema.md`, which does not exist on
disk, so the link-check must REFUSE and name the dangling path. A valid path
`.harness/schemas/plan.schema.md` is present too and must NOT be flagged.
