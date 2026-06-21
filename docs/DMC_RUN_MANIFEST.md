# DMC Run Manifest (v0.2.7)

A **recorder-only / read-only** generator that emits a machine-readable JSON snapshot of a milestone run. It **records
state; it does not grant gates.** It stages/commits/pushes/mutates the real repo **nothing**, makes no live call, and
reads no `.env*`/credentials. `--out` writes only the named manifest file (it never `git add`s it).

Generator: `.harness/evidence/dmc-v0.2.7-run-manifest.sh`

## Usage

```
dmc-v0.2.7-run-manifest.sh --milestone <id> --plan <plan.md> [--allowlist <file>] [--repo <dir>] \
    [--verify-script <path>] [--verify-pass N] [--verify-fail M] [--push-state <s>] [--out <file>]
dmc-v0.2.7-run-manifest.sh --self-test
```

## Manifest fields

| Field | Source | Notes |
|---|---|---|
| `milestone_id` | `--milestone` | the run id |
| `plan_path` | `--plan` | path to the milestone plan |
| `approval_status` | plan `Status:` line (read-only) | e.g. `APPROVED` / `DRAFT` |
| `allowed_files[]` | `--allowlist` file | approved staged set |
| `excluded_files[]` | default (env `DMC_GATE_EXCLUDED`) | auto-logged evidence kept untracked |
| `protected_paths[]` | default (env `DMC_GATE_PROTECTED`) | adapters/router/schemas/hooks/`PROVIDER_CONTRACT.md`/`dmc-glm-smoke` |
| `verification_script` | `--verify-script` | the milestone's verify harness |
| `verification_pass` / `verification_fail` | `--verify-pass` / `--verify-fail` | result counts |
| `gates{approval,staged,commit,push,closure}` | derived (plan + git) / `--push-state` | **descriptive states**, e.g. `push:"deferred"` |
| `commit_hash` | `git rev-parse --short HEAD` (read-only) | |
| `origin_sync{ahead,behind,in_sync}` | `git rev-list --left-right` (read-only) | vs `DMC_GATE_UPSTREAM` (default `origin/main`) |
| `live_calls` | constant `"disallowed"` | offline milestones; only a separately-approved live milestone would record `"used"` |
| `credential_access` | constant `"disallowed"` | never reads `.env*`/credentials |
| `generated_note` | constant | recorder-only disclaimer |

## Recorder-only contract

- **Records state, grants nothing.** `gates{}` are *descriptive strings* (e.g. `push:"deferred"`, `closure:"pending"`).
  Writing a gate state never performs the gate. The manifest is a snapshot for the human Release Gate, the Codex
  auditor, and a future reconciliation audit — never an approval, stage, commit, push, or block.
- **Read-only / no mutation.** The generator issues only read git commands and reads the named plan; `--out` writes one
  manifest file to the operator-named path and does not `git add` it. `--out` **refuses** a protected/secret target
  (canonicalized: protected paths, `.env*`, credentials, plus traversal/symlink) and writes nothing in that case. The
  only writes anywhere are inside `--self-test`'s temp repos.
- **No secrets / no env / no live call.** The manifest holds only ids/paths/counts/booleans/descriptive strings;
  `live_calls` and `credential_access` are recorded `"disallowed"` for these offline milestones and the generator reads
  no `.env*`/credentials and makes no network/live call.
