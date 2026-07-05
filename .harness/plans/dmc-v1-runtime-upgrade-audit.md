# DMC v1.0 Runtime Upgrade — Phase 0 Repository Audit

Date: 2026-07-05
Branch: `claude/dmc-v1-runtime-upgrade-c5uch1` (tip == `origin/main` @ `d0edc48` at audit time)
Mode: audit-only. No product/runtime file was modified to produce this document.
Method: full read of `.claude/settings.json`, all hooks, all 15 skills, all 5 agents, all 3 worker
adapters + router, all 14 `.harness/schemas/*`, root schemas, `DMC.md`/`CLAUDE.md`/`AGENTS.md`/
`AUTONOMY.md`/`INSTALL_MANIFEST.md`, `docs/*`, recent plans/verification reports, plus three offline
empirical validator tests (scratchpad-only; repo left byte-clean). Every claim below carries a file
path; claims marked (empirical) were reproduced by running the cited tool offline.

---

## 1. Current architecture summary

DMC today is **four layers of very different maturity**:

1. **Runtime enforcement (real, wired, Claude-Code-only).** Six hooks in `.claude/settings.json`:
   `pre-tool-guard.sh` (Bash PreToolUse), `scope-guard.sh` (Edit|Write), `secret-guard.sh`
   (Read|Grep|Glob), `evidence-log.sh` (PostToolUse), `dmc-router.sh` (UserPromptSubmit),
   `stop-verify-gate.sh` (Stop). This is the only layer that acts without being asked.
2. **Process definition (prose).** 15 skills (`.claude/skills/*/SKILL.md`), 5 subagents
   (`.claude/agents/*.md`), `DMC.md`, `AUTONOMY.md`, `docs/DMC_OPERATOR_HANDBOOK.md`,
   `docs/WORKFLOW_STATE_MACHINE.md`, etc. Defines plan→critic→scope→execute→verify→evidence.
3. **Advisory control plane (executable but unwired).** ~48 deterministic tools under
   `.harness/evidence/` (v0.2.6 gate checks → v0.6.5 decision trace), 11 newer schemas under
   `.harness/schemas/`. Every one is "advisory / inert unless invoked" by its own header
   (e.g. `docs/WORKFLOW_STATE_MACHINE.md:3`, `.harness/schemas/evidence-receipt.schema.md:57-58`).
   `grep -rn "harness/evidence" .claude/hooks/*` shows **zero hooks invoke any of them**.
4. **Worker bridge (real code, mock-first).** 3 adapters (`glm-api`, `oauth-cli`, `manual-import`)
   + `provider-router.py` + `worker-context-guard.sh` + `worker-result-check.py`, governed by
   `PROVIDER_CONTRACT.md` C1–C11. Proposal-only by design; live paths multi-gated.

The repo's own history (`docs/MILESTONES.md`) shows an exemplary *process* — every milestone has a
plan, critic pass, verification report, and closure note — but the *product* of that process is a
control plane that only runs inside its own self-tests.

## 2. What is already strong

- **The secret floor.** `secret-guard.sh` + `pre-tool-guard.sh` secret tier run in all modes;
  `lib/secret-paths.sh` is byte-identical to the inlined copy (verified by diff;
  `INSTALL_MANIFEST.md:17` claim holds). Path-only decisions — the guard never opens files.
- **oauth-cli adapter security** (`.claude/workers/providers/oauth-cli/oauth-cli-adapter.py`):
  token-material guard over stdout+stderr (lines 37-46, 90-105, 316-317, 350-351), binary trust
  model with TOCTOU re-check (251-270), `shell=False`, payload off-argv, minimal child env,
  fail-closed timeouts. This is the quality bar the rest of the bridge should be held to.
- **manual-import adapter**: rejects adapter-owned fields supplied by humans
  (`manual-import-adapter.py:52-54,160-163`), unknown keys, 1 MiB cap, `--out` write-target guard
  (90-117). Imports oauth-cli's token detectors directly (79-83) — single-source, drift-checked.
- **Adapter-stamped trust fields.** `no_direct_mutation`/`credential_exposure` are stamped by
  adapter code and never read from model output (`glm-api-adapter.py:197,204`;
  fixture `glm-response-override-attempt.json` proves the override is crushed).
- **The v0.6.x trace-linkage design.** Canonical subject binding + referential-integrity + typed
  human-only `approval_ref` (`.harness/schemas/trace-linkage.schema.md`,
  `dmc-v0.6.5-decision-trace.py`) is a genuinely reusable provenance primitive; validators are
  env-free, fail-closed, duplicate-key-rejecting, with negative controls (118 PASS across v0.6.x).
- **Governance philosophy.** "Learn suggestions, encode gates" + C11 approval separation
  (`docs/ORCHESTRATION_TAXONOMY.md`, `docs/DMC_ADOPTION_DECISIONS.md`) is the correct,
  model-independent thesis, and the capability-class abstraction
  (`.harness/schemas/capability-routing.schema.md`, model-name-free by self-scan) is exactly the
  right shape for model independence.
- **Milestone hygiene.** `docs/MILESTONES.md` is accurate and current through v0.6.5; append-only
  closure discipline is real (verified against git history).

## 3. What is fragile

Enforcement layer (each verified at the cited lines):

- **Bash writes bypass scope entirely.** `settings.json:16` matcher is `Edit|Write`; `echo >`,
  `sed -i`, `tee`, `mv` mutate any file. pre-tool-guard has no write-pattern tier.
- **Self-escalation of scope.** `scope-guard.sh:73-78` auto-allows `.harness/{runs,evidence,verification,decisions}`;
  the scope file itself lives at `.harness/runs/current-scope.txt` (:58) — the executor can Write
  its own scope wider without tripping any guard. The Stop gate is likewise self-satisfiable:
  `stop-verify-gate.sh:68` is an existence-only `ls .harness/verification/$RUN_ID*` check, and that
  directory is auto-allowed.
- **Fail-open defaults.** No python3 ⇒ scope-guard allows everything (`scope-guard.sh:62-64`);
  no python3 and no jq ⇒ `json_get` returns empty and every guard silently stands down
  (`pre-tool-guard.sh:13-36` and clones); hook `timeout: 10` in settings.json is fail-open at the
  harness level.
- **secret-guard key mismatch.** It reads only `tool_input.file_path` and `tool_input.glob`
  (`secret-guard.sh:102-103`). The Glob tool's parameter is `pattern`; Grep's directory parameter
  is `path`. `Glob pattern="**/.env*"` is not intercepted. Case-sensitivity: `.ENV`, `x.PEM` pass
  (`is_secret_path` case patterns), while pre-tool-guard greps case-insensitively — inconsistent.
- **pre-tool-guard regex evasions.** `rm -fr` / `rm -r -f` unmatched (:68 matches literal `-rf`);
  `git push -f` unmatched (:73 requires `--force`); `git apply`/`patch` have **no pattern at all**
  despite being the most-repeated prohibition in the docs (acknowledged residual:
  `.harness/verification/dmc-v0.2-worker-bridge.md:67` — still open).
- **The flagship path never arms the completion gate.** `dmc-ultrawork/SKILL.md:29` writes only
  `current-scope.txt`, never `current-run-id`; `stop-verify-gate.sh:58-59` exits early without
  `current-run-id`. A `/dmc-ultrawork` run (also the `dmc` natural-activation target,
  `dmc-router.sh:82-88`) runs with the stop gate disarmed.
- **Stop gate is keyword-gated.** `stop-verify-gate.sh:64` blocks only if the last message matches
  a fixed EN/KO completion-phrase regex; any other phrasing ends the session unverified. A FAIL
  verification report also satisfies the existence check.
- **Mode flip is one prompt away.** Any prompt merely ending in the token `dmc-off` writes `off`
  to `.harness/mode` (`dmc-router.sh:68-71`); `.harness/mode` is protected by nothing.

Worker bridge (empirically confirmed by the audit):

- **worker-result-check.py holes** — (empirical) a result whose `summary` contained a JWT was
  ACCEPTed (its `SECRET_VALUE` at :21-23 lacks JWT/Bearer/ya29/gh[opsu]_ classes — half-admitted
  at `oauth-cli/README.md:27-28`); (empirical) a pure-rename diff touching a *forbidden* file was
  ACCEPTed (`diff_paths` :26-34 parses only `---`/`+++` headers); empty `allowed_files` ⇒ scope
  check skipped entirely (`if allowed and…`, :59-61); no `task_id` cross-check; no required-field
  presence check — "schema conformance" is not what the validator enforces.
- **worker-context-guard.sh fails open on parse error** — both python blocks `sys.exit(0)` on JSON
  parse failure with stderr suppressed (:16-22, :48-53) despite the FAIL-CLOSED banner.
- **Review is 100% prose.** No code validates review records, requires all-checks-pass before
  `decision=apply`, or links a review/task `allowed_files` to `current-scope.txt`. `apply_run_id`
  (`WORKER_REVIEW_SCHEMA.md:22`) is produced and checked by nothing.
- Task-schema fields `timeout_seconds`, `token_budget`, `max_context_tokens`, `cancellation_policy`
  have zero code consumers (grep across adapters/validator).

Install layer:

- **Uninstaller .gitignore strip is a no-op** beyond the marker line — `skip` is set but never
  tested (`dmc-uninstall.sh:38-42`); CLAUDE.md is never de-appended despite :28 claiming so.
- **CLAUDE.md append is not idempotent** (`dmc-install.sh:106-112` — no marker check; re-install
  duplicates the section). Cosmetic: `${DRY:+…}` always expands, so every real install prints
  "(dry-run — nothing written)" (`dmc-install.sh:130`).
- **INSTALL_MANIFEST.md's "single source of truth" claim (:3) is false**: installer copies all 14
  `.harness/schemas/*.schema.md` (manifest lists 3) and the whole providers dir (manifest lists
  glm-api only; oauth-cli/manual-import/router/contract are unlisted).

## 4. What is missing for v1.0

1. **A single entry point.** No `dmc` CLI/runner. Invoking the control plane means knowing ~48
   versioned filenames in `.harness/evidence/` and per-tool flag dialects (`--validate`/`--gate`/
   `--route`/`--answer`/`--transition`/`--done`).
2. **Runtime state.** No persistent lifecycle state exists. `.harness/runs/` holds `.gitkeep`.
   The v0.5.4 state machine validates *caller-supplied* facts JSON (`--facts`,
   `docs/WORKFLOW_STATE_MACHINE.md:12-21`); nothing persists DRAFT→…→CLOSURE across turns. The only
   real runtime state is `current-run-id`/`current-scope.txt`/`current-run.md`, created by prose.
3. **Enforcement wiring for the control plane.** The v0.6.2 evidence-receipt gate is called a
   "completion-block gate" but the actual Stop hook never calls it; `docs/INTEROP.md:15-18`
   *suggests* hook wiring for the v0.4.x guards that was never done.
4. **Host installs of anything post-v0.1.3.** `INSTALL_MANIFEST.md` ships hooks/skills/agents/3
   schemas; `docs/HOST_REPO_ARTIFACT_POLICY.md:14` gitignores `.harness/evidence/` in hosts —
   **a host adopter gets none of the v0.2.6–v0.6.5 control plane.**
5. **Model-independence in fact.** Every mechanical gate lives in Claude Code hook wiring
   (`settings.json`); on Codex/OpenCode the whole system degrades to prose. `DMC.md:5` promises
   Codex/OpenCode; the only Codex artifacts are paste-prompts (`_DMC_CODEX_PROMPT_AFTER_UNZIP.md:3`).
6. **Repository intelligence.** No primitive scans a host repo for architecture landmarks, existing
   patterns, dependency surface, or change radius. `/dmc-init-deep` writes prose AGENTS.md; nothing
   machine-readable, nothing consumed downstream.
7. **Validators for the three core schemas** (plan/run/verification) — none exist, and recent
   plans already deviate (v0.5.4–v0.5.9 plans are ~19-line stubs omitting most PLAN_SCHEMA
   sections).
8. **Orchestration binding.** No skill references any subagent; no doc maps the 5 installed agents
   to the 6-role taxonomy (`docs/ORCHESTRATION_TAXONOMY.md`) or the delegation matrices
   (`docs/DMC_DELEGATION_HARNESS.md:153-159` vs `docs/DYNAMIC_DELEGATION.md:117-125` — three
   unreconciled role sets).
9. **Worker provenance.** No hash chain task→result→review→apply; results are hand-writable JSON;
   the v0.6.1.0 trace-linkage machinery exists for *milestones* but is not applied to *worker
   artifacts*.
10. **CI.** No `.github/workflows/`; 500+ self-test assertions run only when someone runs them.

## 5. What should be removed or simplified

- Tracked strays (all confirmed via `git ls-files`): `.claude.before-dmc/` (16 files),
  `.harness.before-dmc/` (11), `AGENTS.md.before-dmc`, `CLAUDE.md.before-dmc`,
  `do-me-coding-v0.1-scaffold.zip` (41 KB binary), 4 `_DMC_*` bootstrap prompt files.
  `.gitignore:2-3` ignores them but they were committed first — dead ignore rules.
- `dmc-glm-smoke` — macOS-Keychain-only (`dmc-glm-smoke:10,47`) yet listed on every protected-path
  list (`docs/DMC_GATE_CHECKS.md:50`); a platform-specific dev script should not be frozen security
  surface. Move to a tools dir or drop from the protected set.
- Duplicate schema sources: root `*_SCHEMA.md` vs `.harness/schemas/*.schema.md` are byte-identical
  today with no mirror check; both are installed into hosts. Pick one canonical home + a checksum
  check (note `docs/CONTEXT_MAP.md:26` forbids exactly this duplication while :17 blesses it).
- Three competing lifecycle definitions (`DMC.md:28-41` vs `docs/DMC_AGENT_HANDOFF.md:8` vs
  `docs/WORKFLOW_STATE_MACHINE.md:8`) — keep the v0.5.4 one, rewrite the others as pointers.
- Doc sprawl: 37 `docs/` files with frozen version stamps (HANDBOOK v0.2.5, CONTEXT_MAP v0.4.7,
  INTEROP v0.4.8) and no index of what is current.
- Stale `AGENTS.md` — claims branch `dmc-v0.1-scaffold` (:8-9); the exact "false project memory"
  failure `docs/HOST_REPO_ADAPTATION_POLICY.md:5-7` warns about, in DMC's own repo.

## 6. What should remain Claude-specific

- The **hook adapter**: `settings.json` wiring, `hookSpecificOutput.permissionDecision` JSON,
  `stop_hook_active`/`last_assistant_message` stdin fields, `${CLAUDE_PROJECT_DIR}` — this is the
  Claude Code *binding* of DMC's enforcement, and should be explicitly labeled as one adapter among
  several (see §7).
- Skill/agent frontmatter (`disable-model-invocation`, `argument-hint`, `effort`, `$ARGUMENTS`,
  `tools:`) — Claude Code skill packaging.
- `CLAUDE.md` instruction layer and the `/model` `/effort` policy (`DMC.md:162-176`), including the
  `ultracode` keyword in `dmc-ultrawork/SKILL.md:17`.

## 7. What must become model-independent

- **The enforcement contract.** Guard *decisions* (deny/ask/allow + reason) must live in portable
  CLIs (argv/stdin JSON → exit code + JSON verdict), with per-harness thin adapters (Claude hooks
  today; Codex/OpenCode adapters later). The cores are already close: `worker-context-guard.sh`,
  `worker-result-check.py`, all v0.4.x–v0.6.x tools are plain CLIs with zero Claude coupling; the
  six wired hooks need their decision logic extracted from the Claude JSON envelope.
- **Runtime state** (`.harness/runs/*`, mode, autonomy level): file-based, already
  harness-neutral — keep it that way and document it as the interop surface.
- **Schemas and gates**: already model-free (capability classes are model-name-free by self-scan,
  `capability-routing.schema.md:64`).
- **The process itself**: plan/critic/scope/verify/evidence artifacts are markdown/JSON on disk —
  portable by construction; what is missing is a portable *driver* (see primitives, §8).

## 8. Runtime primitives currently implied but not implemented

| Implied by | Missing primitive |
|---|---|
| `AGENTS.md` "Architecture Landmarks" section, `/dmc-init-deep` | Repository orientation / landmark scanner producing a machine-readable map consumed downstream |
| `docs/DMC_TASK_INTAKE.md` risk dims, plan Relevant Files table | Change-radius predictor / dependency surface scanner (nothing computes impact of a proposed scope) |
| `scope-guard` + `dmc-start-work` | Scope *lock* manager — scope exists but is self-editable, Bash-bypassable, and unlinked to worker `allowed_files` |
| PLAN_SCHEMA Acceptance Criteria | Acceptance-criteria compiler → executable verification plan (v0.5.5 planner exists but takes hand-fed facts) |
| `stop-verify-gate` + v0.6.2 receipts | Evidence ledger wired into the stop path (receipt gate exists, unwired) |
| `docs/RESUME_RECOVERY.md` | Context-recovery manager reading *actual* git/run state instead of "declared" facts (`RESUME_RECOVERY.md:88`) |
| `AUTONOMY.md` levels | An autonomy-level state file + anything that reads it (today: no `/dmc-autonomy`, no `.harness/autonomy-level`, zero consumers) |
| `docs/DMC_DELEGATION_HARNESS.md` | Subagent orchestrator binding installed agents to the role taxonomy |
| `WORKER_REVIEW_SCHEMA.md:29` | Worker-proposal importer that mechanically gates apply on validator PASS + review record |
| `docs/DMC_E2E_COMPLETION.md`, closure controller | Release-readiness gate composed of the above, wired to closure |

## 9. Current verification gaps

- Stop gate: keyword-dependent, existence-only, PASS/FAIL-blind, disarmed on the ultrawork path
  (§3). The v0.6.2 receipt gate ("no receipt → no DONE") is never consulted at stop time.
- No plan/run/verification instance validators (§4.7).
- Verification reports are free markdown; nothing checks a report's commands were actually run
  (evidence-log.sh captures Bash events, but nothing cross-references them against the report).
- Self-tests are the only regression net and there is no CI to run them (§4.10).
- (empirical) The validator that guards the only external-content ingestion path
  (worker-result-check.py) accepts JWT-bearing and rename-diff results — the verification story's
  weakest load-bearing wall.

## 10. Current install/adaptation gaps

- Host installs are frozen at v0.1.3 surface (§4.4); manifest is stale vs installer behavior (§3).
- Uninstall leaves `.gitignore` entries, CLAUDE.md sections, and up to 14 copied schemas behind
  (`dmc-uninstall.sh:38-42`; schemas not in the removal list).
- No post-install self-check ("doctor") that the hooks actually fire in the host, that python3/jq
  exist (the fail-open dependency, §3), or that another harness owns the settings file.
- Host adaptation = copy + prose policy; no generated host profile (verify commands, protected
  paths, landmark map) that the runtime then consumes. `AGENTS.md` is the intended carrier but is
  free prose and — in DMC's own repo — stale.

## 11. Current subagent/orchestration gaps

- The 5 agents are orphaned: no skill or doc dispatches them; prompts are 8-13 line role blurbs
  referencing no schema, artifact path, or gate (all 5 files under `.claude/agents/`).
- Read-only agents (planner/explorer/critic/verifier) all carry Bash — write-capable in practice;
  their read-only-ness is prose.
- Three unreconciled role taxonomies (§4.8); no orchestrator/release-auditor agent despite the
  RELEASE_AUDIT state (`docs/WORKFLOW_STATE_MACHINE.md:18`).
- Critic capability duplicated (skill `/dmc-critic` with 8 criteria vs `critic` agent with none)
  with no rule for which to use.
- Worker bridge is synchronous-only (blocking `subprocess.run`, `provider-router.py:136`), no job
  state, no retry/fallback; `.harness/workers/sessions/` referenced by two skills but absent on
  disk (and promised by `INSTALL_MANIFEST.md:80`).

## 12. Current repository intelligence gaps

- No machine-readable repo model at all: no landmark map, no dependency surface, no pattern
  inventory, no protected-path derivation (protected sets are hand-maintained lists duplicated
  across ~6 docs — `docs/DMC_GATE_CHECKS.md:50`, `docs/DYNAMIC_WORKFLOW.md:20-22`, …).
- `/dmc-init-deep` output (AGENTS.md) is unconsumed prose; its staleness in this very repo (§5)
  proves free prose does not survive as project memory.
- Change-radius/regression prediction: nothing exists; the v0.4.3 scope guard is names-only and
  post-hoc, not predictive.
- Context budgeting (`docs/CONTEXT_BUDGET.md`) classifies caller-declared candidates; nothing
  derives candidates from the repo.

## 13. Release blockers for v1.0

Ordered; each cites its section.

1. **B1 — Enforcement holes in the wired layer**: Bash write bypass, scope self-escalation,
   fail-open JSON parsing, secret-guard key mismatch, disarmed ultrawork stop gate (§3). v1.0
   cannot claim "no accepted scope, no edit" while these stand.
2. **B2 — worker-result-check.py holes** (JWT accept, rename-diff bypass, empty-allowed fail-open)
   + `git apply` unblocked in pre-tool-guard (§3, §9). The proposal-only invariant is prose at its
   most critical joint.
3. **B3 — Control plane unwired and uninstalled** (§4.3, §4.4): "no evidence → no done" is
   enforced only by a keyword-gated file-existence check while the purpose-built receipt gate
   idles.
4. **B4 — No single entry point / no CI** (§4.1, §4.10).
5. **B5 — Model independence is aspirational** (§4.5, §7): decision logic embedded in Claude hook
   envelopes; zero non-Claude adapter exists.
6. **B6 — Version identity incoherent**: "v0.1" in DMC.md/CLAUDE.md/AGENTS.md/INSTALL_MANIFEST vs
   v0.6.5 reality (§5); a v1.0 release with v0.1 on the tin is not credible.
7. **B7 — Install/uninstall defects** (§10): manifest false as SSoT, non-idempotent CLAUDE.md
   append, no-op gitignore strip.
8. **B8 — Repo hygiene**: tracked backups/zip/bootstrap prompts (§5).
9. **B9 — Honest-scope debt**: Q6 approval is shape-checked provenance, not authentication
   (`docs/MILESTONES.md` v0.6.x Honest scope); v1.0 messaging must carry this or v0.6.6+ must land.
10. **B10 — No repository-intelligence layer** (§12) — required by the v1.0 definition
    ("repository understanding, architecture preservation, regression prediction").

---

*Prepared as Phase 0 of the dmc-v1-runtime-upgrade session. Companion documents:
`docs/FABLE_WORKFLOW_TRANSFER.md` (Phase 1), `docs/DMC_V1_RUNTIME_ARCHITECTURE.md` (Phase 2),
`docs/DMC_V1_ORCHESTRATION_MODEL.md` (Phase 3), `.harness/plans/dmc-v1-runtime-upgrade.md`
(Phase 4, DRAFT).*
