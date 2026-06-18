# Do-Me-Coding — Host-Repo Artifact Policy (v0.1.3)

When DMC is installed into a HOST repository, its `.harness/` artifacts are **working artifacts of
the DMC tool**, not host product. They default to **local-only / gitignored**; committing is opt-in.

## Default (host repo)

| Artifact | Default | Rationale |
|---|---|---|
| `.harness/mode` | gitignored (local) | per-developer/session switch |
| `.harness/runs/current-*` | gitignored (local) | transient run state |
| `.harness/evidence/manual-*.md` | gitignored (local) | hook fallback noise |
| `.harness/plans/` | **gitignored (local)** | DMC working plans, not host product |
| `.harness/evidence/` | **gitignored (local)** | DMC evidence, not host product |
| `.harness/verification/` | **gitignored (local)** | DMC verification, not host product |
| `.harness/runs/` | **gitignored (local)** | DMC run state |
| `.harness/schemas/`, `.harness/*/.gitkeep` | committed | static skeleton, harmless |

The installer appends these rules to the host `.gitignore` (see `INSTALL_MANIFEST.md`).

## Opt-in to commit
A host team that wants a durable pilot/audit record may **un-ignore specific files** (e.g. a single
verification report) by adding a negation rule (`!.harness/verification/<name>.md`) or removing the
relevant ignore line. This is a deliberate, per-file choice — never the default.

## DMC repo vs host repo (the key distinction)
- **In the DMC repo itself**, durable `plans/`, `evidence/`, `verification/` ARE committed — they
  are DMC project knowledge (e.g. the v0.1.2 pilot record).
- **In a host repo**, the same directories default to local-only — they are DMC *tooling output*
  about the host, not the host's own deliverables.

This separation keeps host repos clean and prevents DMC's internal bookkeeping from polluting a
product repo's history.
