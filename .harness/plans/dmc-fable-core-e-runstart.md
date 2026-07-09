# Plan — fable-core Cycle E (v1.1.3): run-start scope arming — close the documented-but-unimplemented gap

Work ID: dmc-fable-core-e-runstart

## Goal

Close the registered run-start arming defect (discovered by Cycle A's independent verifier;
manually compensated in all four fable-core cycles) so that arming a run's locked scope is a
single, fail-closed, machine-verified step — WITHOUT touching the frozen-ish run-lifecycle core:

- **E1 — `bin/dmc run start --scope-input FILE` (dispatch-level composition).** `bin/dmc`'s `run`
  verb gains an optional `--scope-input FILE` flag consumed at the DISPATCH layer (bash), never
  passed into `dmc-run-lifecycle.py` (which stays byte-untouched). **Dispatch restructuring
  (critic r1 B1):** the current dispatch is a SHARED `exec python3 "$RCORE" "$sub" "$@"`
  (`bin/dmc:375`) across start|suspend|resume|status|block|blocked-status|unblock — `exec` never
  returns, so the `start` subcommand is SPLIT OUT of the shared exec group into a NON-exec
  captured call (`python3 "$RCORE" start <argv-minus-scope-input>; rc=$?`) with stdout/stderr
  flowing through UNMODIFIED (byte-identity preserved); every OTHER run subcommand keeps `exec`
  verbatim. **Root-aware composition (critic r1 B2):** the dispatcher extracts `--scope-input
  FILE`, `--plan FILE`, and `--root DIR` (default `.`) from the start argv (`--scope-input` is
  removed before delegation; `--plan`/`--root` are passed through untouched AND reused); all
  composition paths are rooted at `<root>`: pointer read `<root>/.harness/runs/current-run-id`,
  compile `--out <root>/.harness/runs/<id>/scope.lock.json`, and compile+validate both invoked
  with `--root <root>`; the compiler tool path is ABSOLUTE via the existing `$HERE` pattern —
  a new `SCOPELOCKLIB="$HERE/lib/dmc-scope-lock.py"` constant (never a cwd-relative `bin/lib/…`).
  Flow on `rc==0` AND `--scope-input` present: compile (also `--plan <plan>` `--landmarks <FILE>`
  `--run-id <id>`) → `--validate` → print `ARMED: <root-rooted lock path> (validated)`.
  **Fail-closed:** if compile OR validate fails, the half-armed state is torn down
  deterministically — `python3 "$RCORE" suspend --root <root>` FIRST (the pointer must still
  exist for suspend to resolve the run), THEN pointer removal — and the command exits 3 with a
  `REFUSED-ARMING: <reason>` line on stderr (a run that LOOKS started but has no lock is exactly
  the false-"armed" state this cycle exists to kill).
- **E2 — honest unarmed warning.** `run start` WITHOUT `--scope-input` keeps today's behavior
  byte-compatible (back-compat with every existing caller/fixture) but now prints one stderr
  advisory line: `WARNING: run started UNARMED — no scope.lock; L1 scope enforcement stands down
  (pass --scope-input FILE to arm)`. Advisory only; exit code unchanged. **Success-path only
  (critic r1 advisory):** the WARNING is emitted ONLY when RCORE exits 0 — on ANY non-zero RCORE
  exit (the REFUSE paths) bin/dmc adds NOTHING to either stream (byte-identity on both streams;
  `tests/fixtures/m6/test-adversarial.sh:277` captures the refuse path via `2>&1` and greps the
  reason text).
- **E3 — SKILL.md truth repair.** `.claude/skills/dmc-start-work/SKILL.md` step 3 currently claims
  `run start` "mints and arms the run-id and locked scope" — FALSE today. Rewrite step 3 to the
  new one-command form (`bin/dmc run start --plan <plan> --scope-input <scope-input.json>`),
  document the scope-input JSON shape (files[] path/grant/landmark_class[/landmark_authorized] +
  bounds{max_files,max_added,max_deleted,forbidden_hunk_classes} — the shape all four fable-core
  cycles used), and add the fail-closed rule: **before ANY edit, verify
  `.harness/runs/<run-id>/scope.lock.json` exists AND `dmc-scope-lock.py --validate` ACCEPTs; if
  not → STOP (no accepted file scope, no edit).** Mirror sync (critic r1 resolved the conditional
  to REQUIRED): `.agents/skills/dmc-start-work/SKILL.md` EXISTS (2,577 B) — both SKILL.md files
  are edited in lockstep and `bin/dmc skills-mirror` must report clean.
- **E4 — standalone test + docs.** New `tests/install/test-run-start-arming.sh` (standalone,
  mktemp fixture repo, NOT wired into selftest — install-wrapper precedent): (1) armed happy path
  — start --scope-input valid ⇒ exit 0, RUNNING, scope.lock exists + validates, pointer set,
  `ARMED:` line printed; (2) fail-closed teardown — malformed scope-input (missing bounds) ⇒
  exit 3, `REFUSED-ARMING:` printed, NO scope.lock, run left SUSPENDED (not RUNNING), pointer
  REMOVED (guards stand down cleanly, no false-armed residue); (3) back-compat — start without
  --scope-input ⇒ exit/stdout behavior identical to today plus exactly one stderr WARNING line;
  (4) concurrent-start refusal unchanged (second start while active still REFUSED); (5) usage
  text mentions --scope-input. `docs/MILESTONES.md` gains ONE v1.1.3 entry (append-only,
  push-gate-pending line).

## User Intent

defect fix, user-directed THIS session (2026-07-10): "2. 즉시 수정하여 이번에 반영" — the
run-start arming defect registered in Cycle A's verification
(`.harness/verification/dmc-run-d5f5f66c202d.md`) is to be fixed now, in this envelope, not
deferred to v1.1+.

Authorized under the same session envelope (AskUserQuestion "전체 비준" + the 2026-07-10
follow-up decision): critic-APPROVE-conditional, LOCAL-commit ceiling on `claude/dmc-fable-core`,
push/main a separate human gate, 2 consecutive critic REJECTs → halt + report. Critic APPROVE is
the mandatory pre-build gate (verdicts at `.harness/evidence/dmc-fable-core-e-critic-r*.json`).

## Current Repo Findings

(grounded 2026-07-09/10, this session; branch history redacted+rewritten 2026-07-10 — old shas in
prior records resolve via `.harness/evidence/dmc-fable-core-redaction-20260710.md`)

- Finding (the defect, verifier-root-caused): `bin/dmc run start` → `dmc-run-lifecycle.py
  cmd_start` writes ONLY run.json + snapshot.txt + pointer; it never invokes `dmc-scope-lock.py
  --compile`; no `bin/dmc` verb exposes the compile. `scope-guard.sh`/`pre-tool-guard.sh` define
  ARMED := pointer present AND that run's scope.lock.json exists — so a started-but-lockless run
  runs with L1 scope enforcement STOOD DOWN while looking armed. 4 of 20 historical runs shared
  the gap; all four fable-core cycles compensated manually (compile → validate → deny/allow
  probes), probe-proven each time.
- Finding: the manual procedure this cycle automates is exactly: `dmc-scope-lock.py --compile
  --plan P --landmarks SCOPE_INPUT --run-id ID --out .harness/runs/ID/scope.lock.json` then
  `--validate` (both exit 0 on success; compiler REFUSES a DRAFT plan, a second lock for the same
  run [immutable], and malformed scope-input with named reason codes — `SCOPE-LOCK-LANDMARKS-NO-
  FILES`, `…-NO-BOUNDS`, etc.).
- Finding: `bin/dmc`'s `run` case currently passes argv through to `RCORE` verbatim; the dispatch
  layer already composes multi-step verbs elsewhere (e.g. `metrics`, suite loops) — a bash-level
  composition is in-style. `dmc-run-lifecycle.py` self-tests (run-core S-rows) never invoke
  `bin/dmc`, so a dispatch-layer flag cannot disturb them.
- Finding: `run suspend` + `rm .harness/runs/current-run-id` is the established, session-proven
  teardown (used every cycle); `cmd_resume` does NOT rewrite the pointer (registered learning) —
  the teardown leaves no half-armed residue.
- Finding: `.claude/skills/dmc-start-work/SKILL.md` step 3 makes the false "mints and arms … and
  locked scope" claim (lines ~32-40); the file also documents the OLD manual state ("It replaces
  the old manual authoring…"). `.claude/skills` is NOT in DEFAULT_PROTECTED (only `.claude/hooks`
  + worker providers + schemas' worker files) — no G4 override needed for the skill; `bin/dmc` is
  enforcement-class landmark → expected non-degrading FLAG (v1.1/v1.1.2 precedent).
- Finding (lockstep rules honored): `INSTALL_MANIFEST.md` lists paths only — `bin/dmc` + SKILL.md
  modifications are manifest-neutral, the new tests/ file is not enumerated (C-cycle precedent);
  `AGENTS.md` derives path/class only — modification-neutral (byte-identity AC pins it);
  `.agents/skills` MAY mirror dmc-start-work — executor resolves via `bin/dmc skills-mirror` and
  syncs if mirrored (conditional row).
- Finding (execution notes carried from the envelope): stage the candidate BEFORE
  `gate release --full` (G2); clean-tree `--all` post-commit with `.codex/config.toml` stashed
  (V15 gotcha #4); armed-window Bash discipline for all workers.

## Relevant Files

| Path | Reason | Allowed to Edit |
|---|---|---|
| `bin/dmc` | E1 dispatch composition + E2 warning + usage text (enforcement-class landmark → FLAG expected, landmark_authorized) | yes |
| `.claude/skills/dmc-start-work/SKILL.md` | E3 truth repair + scope-input shape + no-lock-no-edit rule | yes |
| `.agents/skills/dmc-start-work/SKILL.md` (mirror EXISTS — critic r1 confirmed, 2,577 B) | lockstep mirror sync (required) | yes |
| `tests/install/test-run-start-arming.sh` | E4 standalone test (create) | yes (new file) |
| `docs/MILESTONES.md` | ONE v1.1.3 entry (append) | yes |
| `bin/lib/dmc-run-lifecycle.py`, `bin/lib/dmc-scope-lock.py`, hooks, schemas, frozen tools | byte-untouched | no |

## Out of Scope

- ANY change to `dmc-run-lifecycle.py` (core module; the composition lives in the dispatch layer).
- ANY change to `dmc-scope-lock.py`, the hooks, schemas, frozen `dmc-v*` tools, installer.
- Making `--scope-input` MANDATORY (would break existing fixtures/callers; the WARNING + SKILL.md
  mandate is the v1.1.3 posture; hard-require is a v1.2+ candidate after the pilot).
- The handoff quick-card start-work template (docs pass for a future cycle; SKILL.md is the
  operative instruction executors follow).
- Push / CI / main merge (human gate).

## Proposed Changes

- Change: `bin/dmc` — add `SCOPELOCKLIB="$HERE/lib/dmc-scope-lock.py"` beside the existing lib
  constants. In the `run` verb case: SPLIT `start` out of the shared exec group (B1) — for
  `start`, parse the argv copy extracting `--scope-input FILE` (removed before delegation) and
  noting `--plan FILE` + `--root DIR` (default `.`; both left in the delegated argv); run
  `python3 "$RCORE" start <delegated argv>` as a CAPTURED (non-exec) call with both streams
  flowing through untouched; `rc=$?`. All other run subcommands keep the existing `exec` line
  verbatim. Post-delegation branch: rc!=0 ⇒ exit rc silently (nothing added to either stream);
  rc==0 without `--scope-input` ⇒ one E2 WARNING line to stderr, exit 0; rc==0 with
  `--scope-input` ⇒ read `<root>/.harness/runs/current-run-id`, `python3 "$SCOPELOCKLIB"
  --compile --plan <plan> --landmarks <scope-input> --run-id <id> --root <root> --out
  <root>/.harness/runs/<id>/scope.lock.json` then `--validate <that lock> --root <root>`; both
  0 ⇒ print `ARMED: …scope.lock.json (validated)`, exit 0; either non-zero ⇒ stderr
  `REFUSED-ARMING: <reason>`, `python3 "$RCORE" suspend --root <root>` (pointer still present —
  ordering matters), remove `<root>/.harness/runs/current-run-id`, exit 3. Update the usage block
  (`run start` line + the new flag + the ARMED/WARNING semantics).
  Files: `bin/dmc`.
- Change: `.claude/skills/dmc-start-work/SKILL.md` — step 3 rewritten to the one-command armed
  form; scope-input JSON shape documented (with a 5-line example matching the fable-core cycles);
  fail-closed no-lock-no-edit rule added; the false "arms … locked scope" claim removed (the new
  text is true because E1 makes it true). Sync the `.agents/skills` mirror if present.
  Files: `.claude/skills/dmc-start-work/SKILL.md` (+ conditional mirror).
- Change: NEW `tests/install/test-run-start-arming.sh` — the 5 cases in E4, isolated EXACTLY the
  established fixture way (critic r1 B2 pinned it; the CLAUDE_PROJECT_DIR idea was WRONG — neither
  CLI reads it): call the REAL `"$REPO/bin/dmc" run start --plan <fixture plan> --root
  "$FIXTURE"` from any cwd, with all assertions against `<FIXTURE>/.harness/runs/…` (the m6/m7/
  m9 `_mXcommon.sh` pattern); wrap the suite in the house hermetic proof (`git status
  --porcelain` of the real repo byte-identical before/after).
  Files: `tests/install/test-run-start-arming.sh`.
- Change: `docs/MILESTONES.md` — append ONE `## v1.1.3 — run-start scope arming — LOCAL
  (2026-07-10)` entry: the defect history (discovered Cycle A, compensated 4×), what E1-E4 ship,
  verification summary, `push/CI/main-FF: human gate` line.
  Files: `docs/MILESTONES.md`.

## Acceptance Criteria

- Criterion: armed happy path is one command.
  Verification Method: fixture: `bin/dmc run start --plan <approved-plan> --scope-input <valid>`
  ⇒ exit 0; run RUNNING; `.harness/runs/<id>/scope.lock.json` exists; `dmc-scope-lock.py
  --validate` ACCEPT; `ARMED:` line printed; live `bash-radius` out-of-scope probe against the
  new lock ⇒ deny rc4.
- Criterion: fail-closed teardown (no false-armed residue).
  Verification Method: malformed scope-input ⇒ exit 3; `REFUSED-ARMING:` on stderr; no
  scope.lock.json; run status SUSPENDED; pointer file ABSENT.
- Criterion: back-compat byte-compatibility (BOTH paths, critic r1 advisory).
  Verification Method: SUCCESS path — `run start` without the flag ⇒ stdout + exit code identical
  to a direct `python3 bin/lib/dmc-run-lifecycle.py start …` invocation, plus exactly one new
  stderr WARNING line and nothing else. REFUSE path — a start that RCORE refuses (e.g. DRAFT
  plan) ⇒ exit code AND both streams byte-identical to the direct RCORE call (bin/dmc adds
  NOTHING on non-zero rc; `test-adversarial.sh:277`-style `2>&1` capture proves it);
  `run suspend/resume/status/block/unblock` keep the exec delegation verbatim; `bin/dmc selftest`
  every RESULT line 0 FAIL; run-core/loop-core module self-tests green under `--all` (clean-tree,
  post-commit); m6/m7/m9 fixture suites green (their `run start --root` callers are the pinned
  consumers of the changed dispatch).
- Criterion: SKILL.md tells the truth; mirror in lockstep.
  Verification Method: grep the false claim is GONE; the new step-3 command form + scope-input
  shape + no-lock-no-edit STOP rule present; `bin/dmc skills-mirror` clean (mirror synced or
  proven absent).
- Criterion: derived artifacts neutral.
  Verification Method: `bin/dmc agents-md --stdout | diff - AGENTS.md` empty; m8 manifest-drift
  suite green (manifest-neutral change).
- Criterion: test suite + gate + scope + ceiling.
  Verification Method: `bash tests/install/test-run-start-arming.sh` all cases PASS; staged set ==
  exactly the in-scope files; green set + `dmc gate release --full --run-id <run>` PASS (FLAG on
  `bin/dmc` expected; NO G4 override — `.claude/skills` not protected); clean-tree `--all`
  802/3/3 EXACT post-commit; commits LOCAL only; `.codex/config.toml` unstaged.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Dispatch-layer argv surgery breaks an existing `run` caller | medium | only the `start` subcommand path inspects the new flag; all other subcommands delegate verbatim; back-compat AC compares against direct RCORE output; full selftest + run-core/loop-core under `--all` |
| Teardown leaves a half-armed state on a weird failure (compile ok, validate fail) | medium | teardown runs on ANY non-zero step; test case (2) asserts pointer ABSENT + status SUSPENDED + no lock; the immutable-lock compiler refuses overwrite so a stale lock cannot linger silently |
| The fixture test mutates the real repo's run state | medium | fixture uses `--root`/`CLAUDE_PROJECT_DIR` isolation into mktemp; test header documents the mechanism; a `git status --porcelain`-unchanged assertion wraps the suite (hermetic proof, house pattern) |
| SKILL.md/mirror drift | low | skills-mirror check is an AC; conditional scope row |
| This cycle itself must be armed by the OLD manual procedure one last time | low | procedure is session-proven 4×; the new path's own test proves the successor never needs it again |

## Assumptions

| Assumption | Confidence | How to Verify |
|---|---|---|
| `--root` is the sole isolation mechanism for both CLIs (CLAUDE_PROJECT_DIR is NOT read by either — critic r1 corrected the earlier claim) | verified (critic r1 grep) | fixture asserts everything under `<FIXTURE>/.harness/runs/…` |
| No existing fixture asserts run-start stderr is EMPTY on success | verified (critic r1: all success-path callers discard streams; run-core self-tests invoke the module directly, never bin/dmc) | m6/m7/m9 suites green at build time |
| Envelope covers this cycle (user's 2026-07-10 "즉시 수정" directive) | high | recorded this session; halt on critic challenge |

## Execution Tasks

- [ ] DMC-T001: probe stderr-assertion collisions (grep) + `--root` isolation mechanics; implement
  `bin/dmc` E1+E2 + usage; run `bash -n bin/dmc` + targeted manual probes in a mktemp fixture.
  Files: `bin/dmc`.
  Notes: Route: Opus 4.8, synchronous (Ring-0 dispatch; correctness-critical).
- [ ] DMC-T002: SKILL.md truth repair (+ mirror if present); write + run
  `tests/install/test-run-start-arming.sh` (5 cases, hermetic); `bin/dmc selftest`;
  `bin/dmc skills-mirror`; agents-md byte-identity; m8 manifest-drift.
  Files: `.claude/skills/dmc-start-work/SKILL.md` (+ conditional mirror),
  `tests/install/test-run-start-arming.sh`.
  Notes: Route: Opus 4.8, synchronous; depends on T001.
- [ ] DMC-T003: MILESTONES v1.1.3 entry; independent verification (fresh Opus lane) →
  `.harness/verification/<run-id>.md`; green set + gate (stage FIRST); change commit + records
  commit (LOCAL; targeted `git add`; `.codex/config.toml` unstaged); clean-tree `--all` 802/3/3;
  build evidence `.harness/evidence/dmc-fable-core-e-build-20260710.md`.
  Files: `docs/MILESTONES.md` (+ records, scope-exempt).
  Notes: Route: verifier Opus 4.8 fresh lane; commits by orchestrator under the envelope grant.

## Verification Commands

| Command | Reason | Required |
|---|---|---|
| `bash tests/install/test-run-start-arming.sh` (all cases) | E1/E2 behavior matrix + hermetic proof | yes |
| fixture `bash-radius` deny probe against a lock minted BY the new path | armed-for-real proof | yes |
| grep SKILL.md: false claim gone; new form + STOP rule present; `bin/dmc skills-mirror` | E3 truth + lockstep | yes |
| `bin/dmc agents-md --stdout \| diff - AGENTS.md` empty; m8 manifest-drift green | derived-artifact neutrality | yes |
| `bin/dmc selftest`; clean-tree `--all` 802/3/3 EXACT (post-commit, `.codex` stashed); mirror-check; linkcheck | regression floor | yes |
| staged set == in-scope; green set + `dmc gate release --full --run-id <run>` PASS (FLAG, no override) | gate discipline | yes |
| commits LOCAL; no push | autonomy ceiling | yes |

## Approval Status

Status: APPROVED
Approver: wjlee (woojin20020@gmail.com)
Approved At: 2026-07-10 (this-session directive "2. 즉시 수정하여 이번에 반영" under the standing
fable-core envelope: critic-APPROVE-conditional, LOCAL-commit ceiling on `claude/dmc-fable-core`,
push/main a separate human gate, 2 consecutive critic REJECTs → halt + report). Critic APPROVE is
the mandatory pre-build gate; this plan is not built unless a schema-valid APPROVE verdict binds
this file's sha256 via `bin/dmc verdict gate`.

Revisions: Rev 1 → critic r1 NEEDS_CLARIFICATION (2 blockers,
`.harness/evidence/dmc-fable-core-e-critic-r1.json`): B1 = the `run` dispatch is a shared
`exec` (`bin/dmc:375`) that never returns — post-delegation composition was unreachable as
written; Rev 2 splits `start` into a captured non-exec call (streams flow through untouched; all
other subcommands keep exec). B2 = the composition recipe was cwd-relative while every
established caller passes `--root` without cd-ing in — Rev 2 threads `--root` through the pointer
read / compile `--out` / compile+validate, adds the absolute `SCOPELOCKLIB="$HERE/lib/…"`
constant, and rewrites the E4 fixture to the pinned `--root "$FIXTURE"` pattern. Advisories
folded: the false CLAUDE_PROJECT_DIR fallback claim dropped (neither CLI reads it); REFUSE-path
both-streams byte-identity added to the back-compat AC (bin/dmc adds nothing on non-zero rc; E2
WARNING is success-path-only); the `.agents/skills/dmc-start-work/SKILL.md` mirror confirmed to
EXIST → conditional row resolved to required lockstep. Re-submitted for a fresh critic pass (r2).
