# Verification Report

## Run ID

dmc-run-ce3c5ba0d8d7 (work-id dmc-codex-app-optionb) — SUSPENDED, run pointer cleared
(governance window). Verifier: independent, non-authoring; wrote none of the build/fixture/evidence.

## Plan

.harness/plans/dmc-codex-app-optionb.md — Rev 3, APPROVED (wjlee). Critic chain r1
NEEDS_CLARIFICATION -> r2 REJECT -> r3 APPROVE (three critic JSONs on disk, `dmc validate plan`
VALID). This cycle is a diagnostic enablement + recorded live-turn observation that claims NO
enforcement tier and performs NO promotion.

## Changed Files

- adapters/codex/dmc-codex-dispatch-probe.py: NEW repo-internal dispatch marker (committed 34effc7,
  create grant, enforcement landmark) — stdlib-only, names-only, silent, exit-0; deliberately NOT
  shipped (absent from the installer ship list).
- AGENTS.md: regenerated (new enforcement-class landmark appears in section 4 / section 5); the
  section-7 companion pointers were re-added (the standing pointer-loss regression, reproduced and
  caught in-task per the evidence).
- docs/MILESTONES.md: GRANTED in scope.lock (edit, release landmark) but UNUSED at 34effc7 — the
  T005 closure entry is pending-by-design; the granted-but-unused entry is expected.

## Commands Run

| Command | Result | Reason | Output Summary |
|---|---|---|---|
| in-memory compile() of the probe (copied to a scratch tree) | PASS | probe correctness | COMPILE OK |
| 5-event synthetic stdin drill against the probe copy | PASS | names-only / silence / exit-0 contract | 5 markers, every event rc=0, stdout_len=0, stderr_len=0 |
| value-leak scan of the drill markers (seeded SECRET-* values) | PASS | no payload value serialized | all seeded values 0 hits; only key NAMES stored |
| bin/dmc selftest (default set) | PASS | no regression from the additive file | exit 0; every suite 0 FAIL (orient 10, landmarks 11, depsurface 8, radius 7, validate-plan 8, validate-run 6, validate-verification 6, schemas-mirror 15, legacy-mirror 4) |
| bin/dmc selftest m8-suite (manifest drift) | PASS | unshipped probe -> no drift | test-manifest-drift 10 PASS / 0 FAIL |
| bash tests/fixtures/m6.5/test-codex-shims.sh | PASS | paired shims untouched | 99 PASS / 0 FAIL; real repo byte-identical |
| bin/dmc mirror-check | PASS | frozen mirror integrity | 55-file set byte-identical; RESULT PASS |
| bin/dmc linkcheck | PASS | reference integrity | clean; 24 files scanned |
| CI model-name grep over adapters/ | PASS | new file passes the blocking grep | no match |
| CI model-name grep (full CI form, all scanned dirs) | PASS | belt-and-suspenders | empty |
| bin/dmc agents-md --validate AGENTS.md | PASS | AGENTS regen guarded | VALID: 10 required sections |
| section-7 companion-pointer grep on AGENTS.md | PASS | pointers intact | AUTONOMY.md + docs/CONTEXT_MAP.md present |
| bash bin/lib/dmc-v0.4.7-context-audit.sh --self-test | PASS | frozen context audit | PASS=7 FAIL=0; repo byte-unchanged |
| grep CODEX_ADAPTERS .claude/install/dmc-install.sh | PASS | probe not shipped | ship list = 5 shims; probe absent (0 hits) |
| bin/dmc validate plan | PASS | plan conforms | VALID dmc.plan-instance.v1 |
| lexeme-discipline grep on the new evidence file (doctor 86-88 set) | PASS | honesty wording | CLEAN: no line matching the Codex token carries a forbidden whole-word lexeme |
| git diff 3f96203 -- .codex/ | PASS | real repo shipped templates byte-unchanged | empty |
| no-promotion diff (HONEST_SCOPE, ENFORCEMENT_MATRIX, doctor, 5 shims, install, manifest) | PASS | boundary held | 0 diff lines each vs 3f96203 |
| git merge-base --is-ancestor 34effc7 origin/branch | PASS | committed+pushed before any live session | ancestor: yes |
| bin/dmc validate run (against run.json) | N/A | wrong artifact type | REFUSED (run.json is a machine state file; the validate-run target expects a run REPORT doc — not a failure) |

## Manual Checks

| Check | Result | Notes |
|---|---|---|
| Probe is stdlib-only, names-only, silent, always exit 0 | PASS | imports json/sys/os/datetime only; logs event/tool labels + SORTED top-level key names + sorted tool_input key names, NEVER any value; no stdout/stderr writes; main wrapped in try/except, sys.exit(0) unconditional |
| Scope: 34effc7 changed files subset of scope.lock files[] | PASS | changed = {AGENTS.md, probe}; granted = {AGENTS.md, probe, docs/MILESTONES.md}; MILESTONES granted-but-unused (T005 pending) |
| Scope bounds respected | PASS | max_files 3 (2 used), max_added 150 (82 added), max_deleted 30 (1 deleted), forbidden_hunk_classes empty |
| scope.lock state_hash matches evidence | PASS | 9524bdb4e4095931... on both; immutable:true; prev_hash chain intact |
| Probe listed in AGENTS.md section 4 + section 5 | PASS | line 119 (section 4 enforcement landmark) + line 224 (section 5 protected union) |
| git status shows ONLY governance artifacts | PASS | plan + 3 critic JSONs + new evidence file (this report adds one more, by design) |
| Clone: remote -v EMPTY | PASS | R2-B1 write-back channel severed |
| Clone: HEAD == 34effc7 | PASS | 34effc7553398df45030ce6952c9c9f384d693b0 |
| Clone: current-run-id ABSENT (unarmed shims) | PASS | pointer-free per r1-B1 |
| Clone: .harness/mode present with full-standing token | PASS | 7-byte mode file, mtime 15:44 UTC — corroborates the in-process router file-CREATION side effect |
| Clone: probe wiring present only in clone hooks.json | PASS | 7 probe references in clone hooks.json; 0 in the real repo's committed hooks.json |
| Clone: markers.jsonl total line count | PASS | 23 lines = 2 baseline (drill) + 21 live |
| Clone: NO payload VALUE in any marker line | PASS | seeded/live-value grep (nonexistent, dmc-probe, README, tmp, the Korean summary word, recursive-remove text, patch-apply text) all 0; only key NAME 'command' appears; distinct tool_input_keys = {('command',)} |
| Clone: manual-*.md count = 4, benign command lines (no secrets) | PASS | 4 files holding 7 Bash tool-event entries total (doc-read commands: sed/find/rg over docs); no secret values |
| Envelope-schema section vs raw top_keys | PASS | every per-event top-level and tool_input key-name claim matches the markers exactly (turn_id on all but SessionStart; source/prompt/tool_response/stop_hook_active/last_assistant_message as stated; Bash tool_input = command) |
| PreToolUse markers all tool=Bash; Edit/Write + Read/Grep/Glob matcher groups got zero events | PASS | confirmed — all 10 PreToolUse markers carry tool=Bash |
| Trust records in ~/.codex/config.toml (clone project) | PASS | [projects."...DMC-codex-app-probe"] trust_level = "trusted" present |
| hooks.state clone entries present NOW | PASS-with-correction | 13 [hooks.state] entries for the clone hooks.json (2 post_tool_use + 6 pre_tool_use + 1 session_start + 2 stop + 2 user_prompt_submit); evidence prose says "14" — 14 is the TOTAL clone-path line count (13 hooks.state + 1 projects trust header), not the hooks.state entry count |
| hooks.state ABSENT after the App phase (RESULT 1 root cause) | USER+LOG-CORROBORATED | cannot be machine-reproduced now (the later CLI phase populated the 13 entries); accepted on the evidence narrative + the user-held App log, not re-observed |
| Per-event verdict table vs raw live markers | FAIL (one cell) | live distribution = SessionStart 1, UserPromptSubmit 2, PreToolUse 9, PostToolUse 7, Stop 2 (sum 21); the evidence table prints PostToolUse = 8 (its own row-sum is 22, one over the stated 21 live lines). Actual PostToolUse = 7. The table's own narrative ("recursive-remove probe blocked TWICE, zero execution") is CONSISTENT with 7: 9 PreToolUse minus 2 honored denies = 7 completed = 7 PostToolUse. So 8 is a transcription error; 7 is correct |

## Scope Review

Result: PASS

Notes: The committed change at 34effc7 touches exactly two of the three scope.lock-granted paths
(AGENTS.md, the probe); docs/MILESTONES.md remains a granted-but-unused entry pending the T005
closure edit. Bounds and forbidden-hunk-classes are respected. scope.lock is immutable with an
intact prev_hash chain and its state_hash matches the evidence. No out-of-scope file was touched.
The real repo's shipped Codex templates and both tier docs and the doctor are byte-unchanged vs the
compiled-at head 3f96203 — the no-promotion boundary held exactly.

## Package / Env / Migration Review

Package files changed: no
Env files changed: no
Migration files changed: no

Notes: The only committed code artifact is a stdlib-only, non-shipped diagnostic script; no
dependency, manifest, environment, or migration surface was altered. No secret-bearing file was
read, printed, or serialized at any point (marker contract is names-only; verified by an
independent seeded drill and by a value-leak scan of the live markers).

## Unresolved Risks

- EVIDENCE INACCURACY (must be corrected at the T005 closure edit, before commit gate #2): the
  RESULT-2 per-event table lists PostToolUse = 8; the raw live markers show 7 (and the manual
  evidence holds exactly 7 tool-event entries). Correct the cell to 7. Low functional impact (the
  finding "all five events dispatched; deny + context envelopes honored" is unchanged), but this is
  the very artifact whose honesty is the cycle's deliverable, so the count should be fixed.
- EVIDENCE IMPRECISION (correct at closure): "[hooks.state] now carries 14 clone-path entries" —
  the hooks.state entry count is 13; 14 is the total clone-path line count including the one
  projects-trust header. Re-word to "13 hooks.state entries (14 clone-path lines total, incl. the
  project-trust header)".
- EVIDENCE OMISSION (register as a coexistence observation): during the live turns a third-party
  Codex orchestration layer (LazyCodex/OMO) MUTATED the throwaway clone's .codex/config.toml
  (added model/reasoning settings + a multi_agent_v2 block, self-annotated "Managed by LazyCodex").
  The Fixture narrative and the coexistence notes cover the global OMX hooks only, not this
  clone-local project-config mutation. Real-repo impact: NONE (the real .codex/config.toml is
  byte-unchanged vs 3f96203, machine-verified). Worth one line in the closure record.
- PENDING-BY-DESIGN (AC8 + closure lane, not evaluable at the verifier stage): legacy
  `bin/dmc selftest --all` 802/3/3, CI on the pushed heads, main fast-forward, the T005 MILESTONES
  closure entry, clone deletion (the evidence explicitly holds the clone until the verifier finishes
  reading the fixture artifacts — its continued presence on disk is expected), and commit gate #2
  for the governance records all remain open. These are the remaining DONE conditions.

## Final Status

PARTIAL
