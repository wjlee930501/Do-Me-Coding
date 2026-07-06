# Link-check negative fixture — unregistered role binding

NOT part of the real scanned surface; consumed only by dmc-orchestration-linkcheck.py --self-test.

## Registry binding

- Role: `frobnicator-nonexistent` in `orchestration/roles.json` (capability class `adversarial-review`).

The bound role id is absent from the registry, so the link-check must REFUSE and name it. The
capability-class token and the registry path are valid and must NOT be flagged.
