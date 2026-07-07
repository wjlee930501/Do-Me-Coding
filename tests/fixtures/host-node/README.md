# host-app — DMC v1 M9 host-shaped fixture

A minimal, byte-frozen Node project shape used by the DMC v1 M9 release-gate suites
(`tests/fixtures/m9/`). It is the master-named `tests/fixtures/host-node` substrate.

This directory is NEVER armed in place. The M9 suites copy it into a fresh `mktemp`
repo (on top of a copied DMC surface), arm a run there, drive the full loop, and tear
the sandbox down — so this committed tree stays byte-identical (the suites' real-repo
porcelain guard proves it).

Files:
- `package.json` — host manifest (`host-app`); `src/index.js` is the entrypoint.
- `src/index.js`, `src/util.js` — two source files so the E2E's benign in-scope edit
  and a rename row both have material.
- `.gitignore` — a normal Node ignore set.
