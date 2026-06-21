# Do-Me-Coding v0.2.7 — Run Manifest

## Goal

Add a **report-only** generator that emits a machine-readable **run manifest** recording the state and scope of a DMC
milestone run (id, plan, approval, scope lists, verification counts, gate states, commit/sync, and the disallowed/used
status of live-calls and credential access). The manifest **records state; it does not grant gates.** It mutates no
real repo, stages/commits/pushes nothing, makes no live call, and reads no `.env*`/credentials.

## User Intent

tooling / process (a structured, auditable snapshot per milestone) — additive, doc + read-only generator script.

## 1. Problem statement

- Each DMC milestone produces the same facts (plan path, approval status, approved/excluded/protected file sets,
  verification script + PASS/FAIL counts, gate states, commit hash, origin sync, "no live call / no credential" posture)
  but they live **scattered across prose** in plans and verification reports. There is no single **machine-readable**
  record per run.
- The human Release Gate, the Codex auditor, and a future reconciliation audit (Fable) would benefit from one
  structured manifest per milestone — easy to diff, grep, and verify — instead of re-deriving facts from prose.
- It must be a **pure recorder**: deriving/reporting state only, never approving, staging, committing, pushing, or
  granting any gate (consistent with the handbook's "operating contract, not enforcement").

## 2. Non-goals

- **No gate granting / no automation of gates.** The manifest records gate *states* (e.g. `approval: APPROVED`,
  `push: deferred`); it never flips approval, stages, commits, pushes, or authorizes anything.
- No product/adapter/router/schema/hook/validator/guard/`dmc-glm-smoke` change.
- No live provider call, no `.env*`/credential read, no network, no leaked-text handling.
- Not a replacement for the gate-check runner (v0.2.6) or the verification reports — it *summarizes* them.
- No mutation of the real repo: the generator writes only the manifest artifact to stdout or an operator-chosen
  `--out` path (the operator decides whether/where to keep it; the generator itself stages/commits nothing).

## 3. Candidate design

### 3.1 `.harness/evidence/dmc-v0.2.7-run-manifest.sh` (the generator)
- **Invocation:** `dmc-v0.2.7-run-manifest.sh --milestone <id> --plan <plan.md> [--allowlist <file>] [--repo <dir>] [--out <file>]`
- **Reads (read-only):** the plan file (for `Status:`/approval), `git -C <repo>` read commands (HEAD hash, ahead/behind
  vs upstream, staged set), and operator-supplied inputs (allowlist, verification counts via `--verify-pass N
  --verify-fail M` or parsed from the named verification report).
- **Emits** a JSON manifest (stdout by default, or `--out <file>`) with fields:
  `milestone_id, plan_path, approval_status, allowed_files[], excluded_files[], protected_paths[],
  verification_script, verification_pass, verification_fail, gates{approval,staged,commit,push,closure},
  commit_hash, origin_sync{ahead,behind,in_sync}, live_calls:"disallowed|used", credential_access:"disallowed|used",
  generated_note`. Booleans/strings only; no secrets, no env values.
- **Hard recorder semantics:** the generator NEVER stages/commits/pushes/mutates the real repo. `--out` writes ONLY the
  manifest file to the path the operator names (it does not `git add` it). Default excluded/protected lists mirror the
  v0.2.6 runner (overridable via the same env vars).
- **`--self-test`:** builds a throwaway temp repo + synthetic plan/inputs, generates a manifest, and asserts the JSON is
  valid and the fields are populated correctly — without touching the real repo (mirrors the v0.2.6 self-test pattern).

### 3.2 `docs/DMC_RUN_MANIFEST.md` (the spec)
- Defines every manifest field, its source, and the **recorder-only contract** (records state, grants no gate). Documents
  that `live_calls` and `credential_access` are recorded as **`disallowed`** by default for these offline milestones and
  would only read `used` if a separately-approved live/credential milestone explicitly set it.

### 3.3 `.harness/templates/run-manifest.example.json` (OPTIONAL — only if approved)
- A minimal example manifest. **Deferred by default** (anti-token-max): the spec's field table is sufficient. Include
  ONLY if the critic/human deems an example necessary; otherwise omit.

### 3.4 `.harness/verification/dmc-v0.2.7-run-manifest.md` (report)
- Records `--self-test` results, JSON-validity check, the recorder-only proof (no real-repo mutation, no
  stage/commit/push), and protected-file byte-unchanged.

## 4. File-level implementation scope

| Path | Change | Edit? |
|---|---|---|
| `docs/DMC_RUN_MANIFEST.md` | NEW — manifest spec + recorder-only contract | yes (new) |
| `.harness/evidence/dmc-v0.2.7-run-manifest.sh` | NEW — read-only manifest generator (+ `--self-test`) | yes (new) |
| `.harness/verification/dmc-v0.2.7-run-manifest.md` | NEW — verification report | yes (new) |
| `.harness/templates/run-manifest.example.json` | NEW — **optional, only if approved**; else omitted | yes (if approved) |
| adapters / `provider-router.py` / `ROUTING.md` / `WORKER_*_SCHEMA.md` / `.claude/hooks/*` / `dmc-glm-smoke` / product code | **NO change** | no |

## 5. Safety constraints

- **Recorder / read-only / report-only** — the generator issues only read git commands + reads the named plan/report;
  it stages/commits/pushes/mutates the real repo **nothing** and grants no gate.
- **Real repo index untouched** — any staging in `--self-test` is temp-repo-only; `--out` writes a single manifest file
  to an operator-named path and does not `git add` it.
- **No live call / no `.env*` / no credentials / no network / no leaked text** — none read or invoked; the manifest
  records `live_calls:disallowed`, `credential_access:disallowed` for these offline milestones and contains no secret/
  env values.
- **No protected-surface change** — adapters/router/schemas/hooks/guards/`dmc-glm-smoke` untouched; `git diff` over them
  empty after this milestone.
- **Records state, grants nothing** — `gates{}` are descriptive strings (e.g. `push:"deferred"`); writing them never
  performs the gate.
- **Auto-logged evidence excluded** — `.harness/evidence/dmc-v0.2.7-*` auto-log (if any) stays untracked/excluded, as
  do the prior excluded evidence files.

## 6. Verification matrix (`--self-test` + checks; read-only, temp-repo-only)

| # | Check | Assertion |
|---|---|---|
| R1 | Manifest is valid JSON | generated output parses as JSON (e.g. `python3 -c json.load`) |
| R2 | Required fields present + typed | all fields populated; lists are arrays; counts are ints; gate/live/credential are strings |
| R3 | approval_status read from plan | a synthetic plan with `Status: APPROVED` → manifest `approval_status=APPROVED` |
| R4 | commit_hash + origin_sync from git | temp repo HEAD hash matches; ahead/behind ints reported |
| R5 | live_calls/credential_access default disallowed | offline run → both `disallowed`; no env/secret value anywhere in manifest |
| R6 | No secret/token shapes in manifest | scan output → none |
| R7 | Recorder mutates nothing | real repo `git status` byte-identical before/after; temp repos removed; `--out` writes only the named file, never `git add` |
| R8 | No stage/commit/push/destructive in generator | `grep`: no `git add`/`commit`/`push`/`reset --hard`/`apply` against a non-temp target; no `--live`, no network tool |
| R9 | Protected files byte-unchanged | `git diff --name-only` over adapters/router/schemas/hooks/`dmc-glm-smoke` → empty |
| R10 | No live call / no `.env*` read | generator reads no `.env*`, makes no network/live call |

## 7. Regression risks

| Risk | Severity | Mitigation |
|---|---|---|
| Generator mutates/stages/commits the real repo | high | Read-only git only; `--out` writes one file, no `git add`; R7/R8 assert; self-test temp-repo-only. |
| Manifest mistaken for a gate grant | med | §2/§5 + spec: descriptive states only; writing a gate state never performs it. |
| Secret/env value leaks into the manifest | high | Manifest records only booleans/strings/paths/counts; R5/R6 scan; never reads `.env*`/credentials. |
| Self-test leaks temp repos / touches real worktree | med | `mktemp -d` + cleanup; R7 verifies real status unchanged. |
| Optional template file adds scope | low | Template deferred unless explicitly approved (§3.3); anti-token-max. |

## 8. Rollback plan

- **Pre-commit:** `git restore` / remove the new files (spec, generator, report; template if added). No product code
  touched → nothing else to undo.
- **Post-commit:** `git revert <v0.2.7-commit-sha>` — additive doc + read-only script only; adapters/router/guards/
  schemas untouched → clean revert.

## 9. Approval Status

Status: APPROVED
Approver: 대표님 (delegated semi-autonomous mode — flipped after critic PASS)
Approved At: 2026-06-21
