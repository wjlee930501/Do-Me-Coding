---
name: dmc-worker-import
description: Ingest + validate a worker result (schema + security). Stores only; never mutates the repo.
argument-hint: task_id
disable-model-invocation: true
---

# Do-Me-Coding Worker Import

Import stores and validates a result ONLY. It MUST NOT mutate the repo.

Validate `.harness/workers/results/<task_id>.json` against `WORKER_RESULT_SCHEMA.md`:
1. `no_direct_mutation == true`; `provider_metadata.credential_exposure == none`.
2. `files_changed` equals the paths touched by `proposed_patch`.
3. `files_changed` ⊆ task `allowed_files`; ∩ `forbidden_files` = ∅.
4. No disallowed category in `files_changed` (`.env*`, lockfiles, dependency files, DB/schema/migration,
   binary, production config) unless explicitly allowed + approved.
5. No secret values anywhere in the result.

Any failure → REJECT (record the reason). Importing NEVER applies the patch. `git apply`/`patch` is
forbidden for worker results — the diff is a review artifact only.
