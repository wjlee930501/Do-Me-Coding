# Plan: DMC v1 M6 — Hook/Guard Hardening (Ring-1 shims over Ring-0)

Plan ID: dmc-v1-m6-hook-hardening · Date: 2026-07-06 · Format: PLAN_SCHEMA.md
Milestone-scoped plan for master plan §M6 (DMC-T011), extended per the approved direction plan
`.harness/plans/dmc-v0.5-codex-adapter-direction.md` (post-Bash diff guard + semantic
verification cross-checks). **DRAFT** — requires its own critic pass + human gate before any
implementation. This is the FIRST protected-surface milestone: it edits `.claude/hooks/*` and
`.claude/settings.json`, which every prior milestone was forbidden to touch.

## Goal

Turn the six live v0.x hooks into thin, auditable Ring-1 shims over Ring-0 verdict CLIs, close
the audited enforcement bypasses (Bash write bypass, scope self-escalation, fail-open on
missing interpreter, secret-guard wrong keys, unarmed stop gate, `git apply` unblocked), add
the post-Bash diff guard and semantic verification-report cross-checks, and prove the
canonical-five bypass classes (1)(2)(3) are denied while every legitimate operation still
passes — with a tested single-revert rollback to the byte-identical v0.6.5 hook surface.

## User Intent

Classify: **feature** (secondary: refactor — hooks become shims; the enforcement logic moves
to Ring-0).

## Current Repo Findings

- Finding: `scope-guard.sh` matches `Edit|Write` only, reads legacy
  `.harness/runs/current-scope.txt`, auto-allows `.harness/runs` paths (self-escalation), and
  fails OPEN when python3 is missing; Bash-mediated writes bypass scope entirely.
  Source: `.claude/hooks/scope-guard.sh`; master plan §Current Repo Findings (audit §3).
- Finding: `secret-guard.sh` reads `tool_input.file_path`/`glob` but Grep's dir param is
  `path` and Glob's is `pattern`, so secret-targeting calls can be missed; matching is
  case-sensitive.
  Source: `.claude/hooks/secret-guard.sh`; master plan §Assumptions row 2.
- Finding: `stop-verify-gate.sh` is keyword-triggered and existence-only — a FAIL report (or a
  completion phrased without the keywords) satisfies it; it never checks report content,
  receipts, or scope.
  Source: `.claude/hooks/stop-verify-gate.sh`.
- Finding: Ring-0 already ships the primitives the shims need — immutable
  `scope.lock.json` compile + adjudicate (`bin/lib/dmc-scope-lock.py`), typed approvals,
  evidence ledger with `check_id` receipts, run state machine, `dmc validate verification`
  (structural), verdict gate — all currently consumed by nothing at runtime.
  Source: `bin/dmc help`; M4/M5 closure records in `.harness/plans/dmc-v1-runtime-upgrade-handoff.md`.
- Finding: `pre-tool-guard.sh` does not deny `git apply` / `patch`, the documented worker
  no-mutation loophole.
  Source: master plan §Current Repo Findings (audit §3).
- Finding: the master plan requires pre-M6 hooks preserved as committed fixtures BEFORE
  editing, and a single revert commit restoring v0.6.5 hooks+settings byte-identically.
  Source: `.harness/plans/dmc-v1-runtime-upgrade-handoff.md` §Next step.

## Relevant Files

| Path | Reason | Allowed to Edit |
|---|---|---|
| tests/fixtures/hooks-v0.6.5/** (new) | byte-identical pre-M6 hook+settings fixtures, committed BEFORE any hook edit | yes (new) |
| .claude/hooks/pre-tool-guard.sh | shim over Ring-0 Bash classifier; git apply/patch deny; fail-closed-in-active | yes (protected — this milestone's explicit authorization) |
| .claude/hooks/scope-guard.sh | shim over `dmc` scope adjudication vs scope.lock; self-escalation fix | yes (protected — same) |
| .claude/hooks/secret-guard.sh | superset keys (file_path, glob, pattern, path) + case-insensitive | yes (protected — same) |
| .claude/hooks/stop-verify-gate.sh | shim over quick receipt-coverage + semantic report gate; keyword regex removed | yes (protected — same) |
| .claude/hooks/evidence-log.sh | post-Bash diff guard invocation point (PostToolUse Bash) | yes (protected — same) |
| .claude/hooks/dmc-router.sh | only if run-arming requires it; else untouched | yes (protected — same; minimal) |
| .claude/settings.json | matcher/event wiring for the above | yes (protected — same) |
| .claude/hooks/lib/** | shared shim helpers | yes (protected — same) |
| adapters/claude-code/** (new) | Ring-1 adapter home for shim logic shared by hooks | yes (new) |
| bin/dmc, bin/lib/dmc-bash-radius.py (new), bin/lib/dmc-postbash-diff.py (new), bin/lib/dmc-verify-crosscheck.py (new), bin/lib/dmc-stop-gate.py (new) | Ring-0 verdict CLIs the shims call (names indicative; final names bound at implementation) | yes (additive; single-owner rule for bin/dmc) |
| .harness/schemas/*.schema.md (only if a new verdict artifact needs one) | schema additions | yes (additive only) |
| tests/fixtures/m6/** (new) | adversarial + compatibility fixtures | yes (new) |
| .harness/evidence/dmc-v1-m6-*.md, .harness/verification/dmc-v1-m6-*.md | evidence/verification | yes |
| .claude/hooks/worker-result-check.py, .claude/hooks/worker-context-guard.sh | M7's surface | no |
| .claude/workers/providers/** | never | no |
| .claude/skills/**, .claude/agents/** | M5 surface, not this milestone | no |
| .claude/install/** | M8's surface | no |

## Out of Scope

- Worker validator hardening (M7), installer work (M8), CI (M9), Codex adapter (M6.5).
- Any relaxation of an existing deny; any live/network call; any secret access.
- Editing `.harness/evidence/dmc-v0.*` originals or bin/lib copies (mirror-check must stay green).
- Staging/commit/push (separate human gates); `docs/MILESTONES.md`.

## Proposed Changes

- Change: commit pre-M6 fixtures FIRST — byte-copies of all six hooks + settings.json under
  `tests/fixtures/hooks-v0.6.5/`, plus a rollback test proving a single revert commit restores
  the live surface byte-identically.
  Files: tests/fixtures/hooks-v0.6.5/**, tests/fixtures/m6/**
  Rationale: master-plan safeguard; makes the protected-surface edit reversible by
  construction.
- Change: Ring-0 verdict CLIs (additive) — (i) Bash write-radius classifier: classifies a
  candidate Bash command's write radius (deny `git apply`/`patch`; deny/ask redirection,
  `sed -i`, `tee`, `mv`/`cp` into non-scope; fail-closed on unparseable in active mode);
  (ii) post-Bash diff check: `git diff --name-only` + status porcelain vs the compiled
  `scope.lock.json` — out-of-scope change ⇒ verdict BLOCKED with the offending paths; NARROW
  internal exemption (`.harness/evidence/`, `.harness/verification/`, append-only run logs);
  Bash-mediated writes to `scope.lock.json`, `approvals.jsonl`, `run.json` DENIED (state
  mutations only via the `dmc` CLI — canonical fixture (2)); (iii) semantic
  verification-report cross-check: report run-id == active run; Changed Files ⊆ approved
  scope and consistent with `git diff --name-only`; Final Status PASS refused when a required
  verification command is absent/failed or skipped without a recorded reason; (iv) stop-gate
  quick check: receipts ⊇ required checks for the active run + the semantic cross-check —
  state-file-only, <2s budget.
  Files: bin/lib (new modules), bin/dmc (verb registration — single owner)
  Rationale: enforcement logic lives in Ring-0 so M6.5 Codex shims reuse it unchanged.
- Change: hooks become shims — each hook parses tool JSON (superset keys, case-insensitive
  paths), calls the Ring-0 CLI, and translates the verdict to the host deny/ask/allow
  envelope; fail-closed in active mode when the interpreter or CLI is missing (clear
  actionable error), passive/off behavior preserved per `.harness/mode`; stop gate arms from
  run state (no keyword regex); suspended runs do not block stop.
  Files: .claude/hooks/*.sh, .claude/hooks/lib/**, .claude/settings.json, adapters/claude-code/**
  Rationale: audit bypass closure; identical verdicts for both adapters.
- Change: adversarial + compatibility suites — negative controls for canonical five
  (1) Bash-mediated write outside scope, (2) agent edit of its own scope/lock file,
  (3) secret read via Glob `pattern`/case-variant paths, plus `git apply` deny and
  interpreter-absent deny-in-active; a compatibility matrix of legitimate operations
  (in-scope edits, reads, evidence writes, `dmc` CLI state mutations, passive-mode flows)
  that must all still pass.
  Files: tests/fixtures/m6/**, bin/dmc (selftest m6 section)
  Rationale: master plan acceptance; prevents over-blocking regressions.

## Acceptance Criteria

- Criterion: canonical-five fixtures (1)(2)(3) are denied; `git apply`/`patch` denied;
  interpreter-absent in active mode ⇒ deny with actionable error.
  Verification Method: M6 adversarial suite (negative controls), exit 0.
- Criterion: post-Bash out-of-scope change ⇒ run BLOCKED with evidence entry, and stop gate
  refuses completion until resolved; Bash write to scope.lock.json/approvals.jsonl/run.json
  ⇒ DENIED even mid-run.
  Verification Method: dedicated fixtures in the adversarial suite.
- Criterion: semantic cross-check refuses: mismatched run-id, changed-files outside scope,
  PASS with a failed/skipped-without-reason required command.
  Verification Method: refusal fixtures per case, exit codes asserted.
- Criterion: every compatibility-matrix legitimate operation still passes; stop-path quick
  gate under 2s; suspended run does not block stop.
  Verification Method: compatibility suite + latency measurement.
- Criterion: `bash -n` clean on all touched shell files; `bin/dmc selftest --all` equals the
  pinned baseline (802/3/3) + new M6 sections at 0 FAIL; mirror-check green.
  Verification Method: syntax pass + selftest --all vs baseline.
- Criterion: single revert commit restores v0.6.5 hooks+settings byte-identically.
  Verification Method: rollback test against tests/fixtures/hooks-v0.6.5/ (cmp per file).

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Over-blocking legitimate work (classifier false positives) | medium | ask-tier for ambiguous forms; compatibility matrix is a required suite; allowlist file for measured exceptions |
| Fail-closed bricks sessions on hosts missing python3 | medium | actionable error text; passive mode unaffected; doctor check lands in M8 |
| Stop-gate latency or over-blocking | medium | state-file-only quick tier; `dmc run suspend` escape hatch; latency asserted in suite |
| Protected-surface edit regresses an existing guarantee | high | pre-M6 byte fixtures committed first; adversarial suite includes all previously-passing guard tests; single-revert rollback proof |
| Post-Bash guard races (checkpoint diff noise, concurrent edits) | medium | compare against both HEAD and the run checkpoint; BLOCKED is sticky until human/`dmc` resolution — never auto-cleared |
| bin/dmc contention with other milestones | low | single-owner rule: one task registers all new verbs |

## Assumptions

| Assumption | Confidence | How to Verify |
|---|---|---|
| Claude Code hook JSON keys: Glob param `pattern`, Grep dir param `path` | high | verify against harness docs before implementation; shims read a superset regardless |
| Ring-0 M4 primitives (scope.lock, receipts, run state) are sufficient for the shims without schema changes | medium | first implementation task probes; schema additions are authorized additive fallback |
| Hook execution environment provides git + python3 in active installs | medium | fail-closed path covers absence; M8 doctor will pre-check |

## Execution Tasks

- [ ] DMC-T011a: Pre-M6 byte fixtures + rollback test (commit BEFORE any hook edit).
  Files: tests/fixtures/hooks-v0.6.5/**, tests/fixtures/m6/**
  Notes: fixture commit is its own reviewable unit; nothing else in it.
- [ ] DMC-T011b: Ring-0 verdict CLIs (bash radius, post-Bash diff, semantic cross-check,
  stop-gate quick) + selftest sections + schemas if needed.
  Files: bin/lib/*, bin/dmc, .harness/schemas/*
  Notes: additive; single-owner for bin/dmc; negative controls per CLI.
- [ ] DMC-T011c: Hook shims + settings wiring (superset keys, case-insensitive,
  fail-closed-in-active, stop gate armed from run state, post-Bash guard wired to
  PostToolUse Bash).
  Files: .claude/hooks/*, .claude/settings.json, .claude/hooks/lib/**, adapters/claude-code/**
  Notes: protected surface — begins only after T011a is committed.
- [ ] DMC-T011d: Adversarial suite + compatibility matrix + latency assert + rollback proof;
  evidence + verification report.
  Files: tests/fixtures/m6/**, .harness/evidence/dmc-v1-m6-*.md, .harness/verification/dmc-v1-m6-*.md
  Notes: verification report must pass `dmc validate verification`.

## Verification Commands

| Command | Reason | Required |
|---|---|---|
| bash -n .claude/hooks/*.sh adapters/claude-code/**/*.sh | syntax floor | yes |
| bin/dmc selftest --all | pinned baseline 802/3/3 + new sections 0 FAIL | yes |
| bin/dmc mirror-check | copy-routed tools untouched | yes |
| M6 adversarial suite (canonical five (1)(2)(3), git apply, fail-closed, post-Bash, semantic refusals) | bypass closure proof | yes |
| M6 compatibility matrix suite | no over-blocking | yes |
| rollback test vs tests/fixtures/hooks-v0.6.5/ | single-revert byte restore | yes |
| git status --porcelain before/after suites | repo cleanliness | yes |

## Approval Status

Status: DRAFT
Approver: (pending — wjlee, human release gate; critic pass required first)
Approved At: —
