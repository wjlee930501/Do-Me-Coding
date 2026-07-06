# Link-check negative fixture — unknown dmc verb

NOT part of the real scanned surface; consumed only by dmc-orchestration-linkcheck.py --self-test.

Run `dmc frobnicate --now` to do the thing — this verb is deliberately NOT declared in bin/dmc, so
the link-check must REFUSE and name it. For contrast this fixture also uses a valid verb
`dmc run start` and a valid path `orchestration/roles.json`, which must NOT be flagged.
