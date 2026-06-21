# Do-Me-Coding v0.2.6 — Gate Check Runner

## Goal

Add a reusable, **read-only / report-only** Gate Check Runner so the staging / commit / push reviews that DMC has
performed ad-hoc become a single standardized command. It **informs** the human Release Gate with a PASS/FAIL summary;
it **never** stages, commits, pushes, mutates files, or grants a gate. Enforcement-adjacent in spirit, but strictly an
observer — consistent with the handbook's "operating contract, not enforcement" stance.

## User Intent

tooling / process (standardize the review gates; reduce dependence on ad-hoc prompt discipline) — additive, docs+script.

## 1. Problem statement

- The staging/commit/push reviews that produced v0.2.1–v0.2.5 were driven by **ad-hoc prompt discipline**: each turn
  re-typed `git diff --cached --name-only/--stat/--check`, a forbidden-file scan, an excluded-evidence spot-check, a
  protected-file byte-unchanged check, and an ahead/behind read. That is correct but **non-standardized and easy to
  drift** (a check skipped, a path list mistyped).
- The v0.2.5 handbook codified the *rules* but explicitly is **not** enforcement. There is no single read-only command
  a human Release Gate can run to get a consistent gate report before deciding to stage/commit/push.
- We want a **read-only runner** that takes an explicit approved-file allowlist and emits the standard gate report —
  **without** acting on the repo. It must remain an observer: it can fail-closed-*report*, but it never decides.

## 2. Non-goals

- **No enforcement / no acting:** the runner never stages, commits, pushes, mutates files, rewrites history, or grants
  a gate. It is read-only and report-only. (Enforcement automation that *blocks* actions remains a separate,
  separately-approved future milestone, per the handbook.)
- No changes to product code, adapters, `provider-router.py`, schemas, `.claude/hooks/*`, validators, guards, or
  `dmc-glm-smoke`.
- No live provider call, no `.env*`/credential read, no network, no leaked/proprietary text handling.
- Not a replacement for the human gate or for Codex audit — it is an input to them, not a substitute.
- Not a git hook install (that would be enforcement; out of scope).

## 3. Candidate design

### 3.1 `.harness/evidence/dmc-v0.2.6-gate-check-runner.sh` (the runner)
- **Invocation:** `dmc-v0.2.6-gate-check-runner.sh --allowlist <file> [--repo <dir>] [--gate stage|commit|push] [--self-test]`
  - `--allowlist <file>`: newline-separated list of approved repo-relative paths (the only files expected in the
    staged set). **Required** for a gate report.
  - `--repo <dir>`: the git repo to inspect (default: cwd). Lets the self-test point at throwaway temp repos so the
    **real repo index is never touched**.
  - `--gate`: which gate's expectations to apply (push additionally requires not-behind-origin).
- **Reads only** (no writes, no `add`/`commit`/`push`/`reset`/`apply`): `git -C <repo> diff --cached --name-only`,
  `git -C <repo> diff --cached --check`, `git -C <repo> status --porcelain -- <protected paths>`,
  `git -C <repo> rev-list --left-right --count <upstream>...HEAD`.
- **Checks reported (G1–G6, below)** → a structured **PASS / FAIL summary** + per-check lines. Exit 0 = all PASS,
  exit 1 = at least one FAIL. The non-zero exit is a *report signal for the human/Codex*, NOT an action.
- **Default lists (overridable):** excluded-evidence list = the four `.harness/evidence/dmc-v0.2.{2,3,4,5}-*.md`
  auto-logged files; protected paths = `.claude/workers/providers/glm-api`, `.../oauth-cli`, `provider-router.py`,
  `ROUTING.md`, `.claude/hooks/`, `WORKER_*_SCHEMA.md`, `dmc-glm-smoke`.
- **`--self-test`:** builds throwaway temp git repos (`mktemp -d`, `git init`), stages **synthetic** files in *those*
  repos only, runs the runner against each, and asserts the expected PASS/FAIL per scenario. This verifies the runner
  **without staging anything in the real repo** and with no network/live call.

### 3.2 `docs/DMC_GATE_CHECKS.md` (the spec)
- Defines each gate check (G1–G6), the inputs (allowlist, gate), the PASS/FAIL semantics, and — emphatically — that the
  runner is **read-only and advisory**: it *informs* the Release Gate and Codex audit; it never stages/commits/pushes/
  mutates/approves. Documents the default excluded-evidence and protected-path lists and how to override them.

### 3.3 `.harness/verification/dmc-v0.2.6-gate-check-runner.md` (report)
- Records the `--self-test` results (PASS/FAIL per scenario) and the protected-file byte-unchanged proof for this run,
  and states explicitly that the runner performed no staging/commit/push and touched no real-repo index.

## 4. File-level implementation scope

| Path | Change | Edit? |
|---|---|---|
| `docs/DMC_GATE_CHECKS.md` | NEW — gate-check spec; read-only/advisory contract | yes (new) |
| `.harness/evidence/dmc-v0.2.6-gate-check-runner.sh` | NEW — the read-only runner (+ `--self-test`) | yes (new) |
| `.harness/verification/dmc-v0.2.6-gate-check-runner.md` | NEW — verification report | yes (new) |
| adapters / `provider-router.py` / `ROUTING.md` / `WORKER_*_SCHEMA.md` / `.claude/hooks/*` / `dmc-glm-smoke` / product code | **NO change** | no |

## 5. Safety constraints

- **Read-only / report-only** — the runner issues only read git commands; it performs no `add`/`commit`/`push`/`reset`/
  `apply`/`rm`/file-write against any repo. It grants no gate and approves nothing.
- **Real repo index untouched** — the only staging that occurs anywhere is inside throwaway temp repos created by
  `--self-test`; the real DMC index/worktree is never modified.
- **No live call / no `.env*` / no credentials / no network / no leaked text** — none are read, invoked, or handled.
- **No protected-surface change** — adapters/router/schemas/hooks/guards/`dmc-glm-smoke` are not touched; the runner
  only *reads* their paths' status. `git diff` over them must be empty after this milestone (verified).
- **Auto-logged evidence excluded** — `.harness/evidence/dmc-v0.2.6-*` (if any auto-log appears) stays untracked/
  excluded at staging, as do the four prior excluded evidence files.
- **Advisory only** — a FAIL/non-zero exit is a report for the human Release Gate and Codex auditor; it is not, and must
  not be wired as, an action or a block.

## 6. Verification matrix (runner `--self-test`; read-only, temp-repo-only, no real-index touch)

| # | Gate check (in the runner) | Self-test assertion |
|---|---|---|
| G1 | **Staged ⊆ allowlist** | temp repo: stage exactly the allowlist → PASS; stage an extra file → FAIL naming the extra |
| G2 | **Allowlist fully staged** (no missing approved files) | stage a subset of the allowlist → FAIL naming the missing |
| G3 | **No excluded-evidence file staged** | stage an excluded `dmc-v0.2.x-*.md` → FAIL naming it |
| G4 | **No protected-path change** | stage/modify a protected path (e.g. a fake `provider-router.py`) → FAIL naming it |
| G5 | **`git diff --cached --check` clean** | stage a file with a trailing-whitespace/conflict marker → FAIL |
| G6 | **Ahead/behind reported; push-gate not-behind** | report ahead/behind ints; `--gate push` while behind upstream → FAIL |
| G7 | **All-clean case** | stage exactly the allowlist, no protected/excluded/whitespace issues → overall **PASS**, exit 0 |
| M1 | **Runner mutates nothing** | after every self-test scenario, the **real** repo `git status --porcelain` is unchanged; temp repos are removed |
| M2 | **No act/grant tokens** | `grep` the runner: no `git add `/`commit`/`push`/`reset --hard`/`apply` against a non-temp target; no `--live`, no network tool |
| M3 | **Protected files byte-unchanged** | `git diff --name-only` over adapters/router/schemas/hooks/`dmc-glm-smoke` → empty after the run |

## 7. Regression risks

| Risk | Severity | Mitigation |
|---|---|---|
| Runner accidentally stages/commits/pushes the real repo | high | Read-only command set only; M1 asserts real index unchanged; M2 greps for forbidden action tokens; self-test staging is temp-repo-only via `--repo`. |
| Runner is mistaken for enforcement / wired to block | med | §2/§5 + `DMC_GATE_CHECKS.md` state it is advisory/read-only; exit code is a report signal, not an action. |
| Self-test leaks temp repos or touches real worktree | med | `mktemp -d` + trap cleanup; `--repo` isolates; M1 verifies real status unchanged. |
| Default protected/excluded lists drift from reality | low | Lists documented in `DMC_GATE_CHECKS.md`, overridable; mirror the lists this session has used. |
| Scope creep into installing a git hook | low | §2 non-goal: no hook install; additive script/doc only; M3 byte-unchanged. |

## 8. Rollback plan

- **Pre-commit:** `git restore` / remove the three new files (`DMC_GATE_CHECKS.md`, the runner, the report). No product
  code touched → nothing else to undo.
- **Post-commit:** `git revert <v0.2.6-commit-sha>` — additive doc + read-only script only; adapters/router/guards/
  schemas untouched → clean revert; the manual review flow continues to work exactly as before.

## 9. Approval Status

Status: APPROVED
Approver: 대표님 (delegated semi-autonomous mode — flipped after critic PASS)
Approved At: 2026-06-21
