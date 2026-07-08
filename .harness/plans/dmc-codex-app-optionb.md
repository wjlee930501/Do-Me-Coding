# Plan — Codex App enablement + Option-B live-turn dispatch test

Work ID: dmc-codex-app-optionb
Rev: 3 (r1 NEEDS_CLARIFICATION → clone isolation adopted; r2 REJECT → R2-B1 clone write-back
channel severed [--no-hardlinks + origin removed + remote-empty assertion], R2-B2 execution-unsafe
probe replaced [printenv dropped for a floor-matched no-op-if-executed probe], R2-B3 the disarmed
window's MECHANISM named [suspend + pointer-clear/restore, the established recorded lane];
r2 advisories folded [mode-absent clone assertion, markers baseline, __file__-anchored marker
path, gate-#2 governance-artifact list, pre-existing-gap register])

## Goal

Make DMC usable in the locally installed Codex App (26.623.61825, sharing `~/.codex` with codex-cli
0.132.0 — the EXACT version the M6.5 spike ran against) and execute the recorded Option-B path: a
ONE-TIME, HUMAN-RUN, explicitly-consented live-turn verification
(`.harness/evidence/dmc-v1-m6.5-spike-stop.md:39-42,68-70`) that observes, in a real Codex App
Local session, (i) whether the wired lifecycle events DISPATCH to the DMC shims at all and
(ii) whether deny/context envelopes are honored. The live session runs in a THROWAWAY CLONE of the
committed repo (critic r1 B2; mirrors the M6.5 spike's own isolation discipline) — the real repo
is never exposed to the App and its shipped `.codex/hooks.json` template is never edited. This
cycle ENABLES + TESTS + RECORDS findings honestly. It claims NO enforcement tier and performs NO
promotion — the shims' documented posture (advisory; pre-commit/CI is the boundary; post-Bash diff
guard is the primary net) is UNCHANGED regardless of results. Promotion, if results support it, is
a SEPARATE future cycle.

## User Intent

feature (diagnostic enablement + verification)

The user asked (2026-07-08): "Codex APP 에서도 사용할 수 있게 해주고, 테스트해볼 수 있게 해줘." The
test turn is run BY THE USER in the App — never DMC-initiated (spike-stop constraint reaffirmed:
"No DMC-initiated live model turn — ever").

## Current Repo Findings

(five-lane scout workflow 2026-07-08 + critic r1 machine-verified corrections; full structured
verdicts in the session workflow journal and `.harness/evidence/dmc-codex-app-optionb-critic-r1.json`)

- Finding: Repo Codex wiring is complete and CI-parity-tested: `.codex/config.toml` (features.hooks
  explicit) + `.codex/hooks.json` (4 events → the 5 shims) + `adapters/codex/*` (A16 34-row UPS
  cross-adapter parity, test-codex-shims 99/0).
  Source: `.codex/{config.toml,hooks.json}`; v1.0.1 build evidence.
- Finding: This machine has Codex App 26.623.61825 installed and `~/.codex` carries App-state
  surfaces (browser, computer-use, automations…) — local empirical evidence App and CLI share
  CODEX_HOME. Officially confirmed for Windows; macOS is a strong inference (shared MCP + "Codex
  home" docs), not a quoted guarantee — the runbook records the App's own internal core version.
  Source: `ls ~/.codex`; developers.openai.com/codex/app/{features,windows}, config-reference.
- Finding: The DMC repo is NOT in `~/.codex/config.toml`'s trusted-projects table (~18 other
  projects are), and no hook-trust entry exists for this repo's `.codex/hooks.json` — BOTH trust
  steps are outstanding and are, by policy, performed by the human (never bypassed;
  `--dangerously-bypass-hook-trust` forbidden). For THIS cycle the user trusts the CLONE path; the
  real repo's own trust is an optional, independent post-cycle step for daily use.
  Source: targeted grep of `~/.codex/config.toml`; `adapters/codex/README.md` trust section.
- Finding: Hooks reached GA with in-App support (changelog 2026-05: "Hooks general availability",
  "in-app trust review flow for hooks") — but the App reviews hook trust via a SETTINGS "Hooks"
  panel, not the CLI's `/hooks` composer command (App commands page lists no /hooks; open issue
  #24041 additionally hides built-in commands from the App slash menu).
  Source: developers.openai.com/codex/changelog, /codex/app/commands, /codex/cli/slash-commands.
- Finding: The App pins its OWN bundled core version (issue #21639 shows an App build with
  cli_version 0.129.0-alpha.15, distinct from any installed CLI) and there are FOUR open
  hook-relevant regressions (#17532 silent non-dispatch via nested config; #21639 App-update
  hook dispatch stopped entirely; #24093 trust-bypass flag ignored in TUI 0.131–0.133; #24041
  App slash-menu). "Hooks silently no-op" is therefore an EXPECTED, detectable outcome of this
  test — a finding, not a test failure.
  Source: github.com/openai/codex issues #17532/#21639/#24093/#24041.
- Finding: Hooks in cloud contexts follow a separate "managed hooks" model; user/project
  hooks.json is a local-session concept. The test MUST use a Local App session.
  Source: developers.openai.com/codex/hooks, /codex/config-advanced, /codex/app.
- Finding (critic r1 B1, machine-verified): `dmc run suspend` flips run.json status ONLY — no
  lifecycle verb removes `.harness/runs/current-run-id` or the run's scope.lock, and the Codex
  shims' `arming()` keys off pointer+lock PRESENCE (`dmc_codex_common.py:153-174`), not status. A
  suspended orchestrator run therefore still reads ARMED to any Codex session in the same tree —
  under which PostToolUse writes evidence to `<orchestrator-run-id>.md` (NOT `manual-*.md`) and
  `postbash-diff` can BLOCK the orchestrator's run from the foreign session. THE TEST THEREFORE
  RUNS IN A CLONE PREPARED POINTER-FREE: clone prep asserts `.harness/runs/current-run-id` is
  ABSENT in the clone (removed if copied), making the clone's shims genuinely unarmed, and the
  real repo is untouched by the App regardless.
  Source: `bin/lib/dmc-run-lifecycle.py:432-441`; critic r1 verdict.
- Finding (critic r2 R2-B1, machine-reasoned): a plain local `git clone` leaves TWO live
  write-back channels into the real repo — the clone's `origin` remote (push can update or DELETE
  any non-checked-out branch; `receive.denyCurrentBranch` protects only the current branch) and
  hardlinked `.git/objects` (local-clone default shares inodes). Clone prep therefore uses
  `git clone --no-hardlinks` AND removes the origin remote; "clone `git remote -v` → EMPTY" is a
  pre-handoff assertion. Cloning from the GitHub URL would NOT fix this (ambient credentials ⇒
  rogue push to the shared remote).
  Source: critic r2 verdict; git receive.denyCurrentBranch semantics.
- Finding (critic r2 R2-B3, machine-verified BOTH sides): the Claude-side guards are also
  presence-keyed (`.claude/hooks/pre-tool-guard.sh:138-148`, `scope-guard.sh:61-76`) — `dmc run
  suspend` alone disarms NOTHING on either host. The disarmed fixture window's mechanism is
  therefore NAMED: suspend + `rm -f .harness/runs/current-run-id` (pointer clear) for the window,
  `printf` pointer restore after — the same recorded lane the hygiene cycle used, with both writes
  recorded verbatim in evidence and a window-state assertion before each fixture op.
  Source: critic r2 verdict; hygiene-cycle evidence (disarm windows #1/#2 precedent).
- Finding: Shim behavior with mode active and NO armed run (the clone's verified test
  state): Bash floors Blocks A/B/C evaluate regardless of arming (only Block D write-radius needs
  an armed run). Deny probes must be SAFE IN BOTH BRANCHES (denied ⇒ nothing runs; silently
  not-dispatched ⇒ the command executes — critic r2 R2-B2): `git apply
  /tmp/nonexistent-dmc-probe.patch` (floor-matched; if executed, fails inertly on a nonexistent
  file) and `rm -rf /tmp/dmc-probe-nonexistent-dir` (floor-matched; if executed, a no-op on a
  nonexistent path). `printenv` is DROPPED — in the no-dispatch branch it would dump the user's
  environment into a provider-bound session, the exact class the Block-A floor exists to stop
  (II.8 lineage). PostToolUse appends
  redacted evidence to `.harness/evidence/manual-<timestamp>.md` when unarmed (gitignored). The
  dmc-suffix router injects the signature context AND writes the `.harness/mode` file in-process —
  and since a fresh clone has NO mode file (gitignored; absent ⇒ active semantics), the clone
  deliberately LEAVES it absent so the router corroboration is unambiguous file CREATION, not an
  mtime read (critic r2 advisory). Stop with no armed run exits silently. On an UNEXPECTED
  envelope shape while unarmed every shim fails OPEN — so a schema-mismatched App envelope
  silently allows; only a dispatch log can distinguish "not dispatched" from
  "dispatched-but-mismatched". CAVEAT (critic r2 advisory): "no marker AND no shim side effects"
  is ambiguous between no-dispatch and hook-EXEC failure (e.g. the relative `python3 adapters/…`
  hook command run from an unexpected cwd) — the probe therefore anchors its marker path to its
  own `__file__` location (clone-contained regardless of cwd), and the verdict table words the
  null outcome as "no dispatch observed (or hook execution failed)" honestly.
  Source: shim-behavior scout (full read of `dmc_codex_common.py` + 4 shims); critic r1/r2.
- Finding: No suite/check enumerates `adapters/codex/*` for a count/hash (fixed-name variables
  only); the one glob (`_m65common.sh:203` copy_shims `dmc-codex-*.py`) additively copies into a
  test sandbox — inert. The installer's `CODEX_ADAPTERS` ship list is a hand-written constant — a
  new repo file NOT added to it is never shipped and causes NO manifest drift. CI's model-name
  grep DOES scan `adapters/` (pattern incl. `codex-[0-9]`, `gpt-[0-9]`) — the new file's prose
  must avoid those patterns. classify_landmark: `adapters/` ⇒ enforcement class ⇒
  landmark-authorized grant + AGENTS.md regen (§4/§5 will list the new file).
  Source: suite-globs scout; `bin/lib/dmc-repo-intel.py:276`; `.github/workflows/dmc-ci.yml:130-132`.
- Finding: `.codex/hooks.json` is SHIPPED BYTE-FOR-BYTE to every `--host codex|both` install
  (`dmc-install.sh:341-366` ship_file = cp; INSTALL_MANIFEST.md "Codex wiring templates →
  .codex/"). Under the Rev 2 clone design the REAL repo's copy is NEVER edited in this cycle —
  probe wiring exists only in the throwaway clone's copy, which no installer ever ships.
  Source: probe-design scout; `.claude/install/dmc-install.sh:341-366`; `INSTALL_MANIFEST.md:163-166`.
- Finding: Lockstep (III.3 / VIII.3(e)) covers the enumerated Claude↔Codex shim PAIRS and the
  3-copy redaction set. An ADDITIVE, standalone, Codex-only diagnostic file — no edits to the four
  paired shims, no redaction logic, names-only logging, no tier claim — does not touch either
  enumerated lockstep surface. It is purpose-parallel to (but measures a DIFFERENT thing than)
  doctor's turn-free synthetic probe: doctor proves Ring-0 verdict logic; this observes real-world
  event dispatch in a live session. Wording discipline: the doctor forbidden-marker set (defined
  at `bin/lib/dmc-doctor.py:86-88`; critic r1 advisory — referenced by path, not re-listed) is
  avoided on Codex-scoped prose lines — hence "dispatch probe".
  Source: probe-design scout; `docs/DMC_CONSTITUTION.md` III.3, VIII.3(e), IV.2; critic r1.
- Finding: Marker location `.harness/runs/dmc-run-codexprobe/` is matched by the committed
  `.gitignore` pattern `.harness/runs/dmc-run-*/` (stays untracked) and is inert to run machinery
  (consumers resolve exactly one run-id and fail closed on a dir without run.json — tested path).
  In the clone the markers live in the CLONE's gitignored path and are read (never committed);
  only the orchestrator's verdict TABLE — with tool_input key names restricted to an ALLOWLIST of
  recognized structural keys (critic r1 advisory; unrecognized keys reported as counts, not
  names) — lands in committed evidence.
  Source: probe-design scout; `bin/lib/dmc-run-lifecycle.py:361-367,419-429`; critic r1.
- Finding (pre-existing gaps REGISTERED as future candidates, critic r2 advisory — NOT drive-by
  fixed here, VIII.3(f)): (a) some hook deny messages advise "suspend the run" as the step-aside
  although suspend alone does not disarm (presence-keyed guards); (b) `.codex/` classifies
  ordinary in repo-intel although it is shipped wiring. Both recorded for the v1.1+ register at
  cycle closure.
  Source: critic r2 verdict.
- Finding (coexistence): the user's GLOBAL `~/.codex/hooks.json` wires oh-my-codex (OMX) on
  SessionStart/PreToolUse(Bash)/PostToolUse/UserPromptSubmit. OMX has NO 'dmc' keyword (verified
  zero grep hits in its keyword map); its UserPromptSubmit only injects advisory context (never
  blocks) and its PreToolUse blocks only OMX-self-referential commands. Official doc: hook layers
  MERGE (do not override) — order/composition semantics UNKNOWN. Risk = same-turn double
  context injection (noise, not command conflict); identical for clone and real repo. Additionally
  the DMC-priority clause lives in CLAUDE.md only — INVISIBLE to a Codex session (AGENTS.md
  carries no priority clause; OMX is named nowhere in this repo). Documenting Codex-side
  coexistence is a recorded FUTURE candidate, out of scope here.
  Source: coexistence-omx scout (read of the OMX hook bundle + repo grep).

## Relevant Files

| Path | Reason | Allowed to Edit |
|---|---|---|
| `adapters/codex/dmc-codex-dispatch-probe.py` | NEW repo-internal diagnostic (committed; NOT shipped — absent from `CODEX_ADAPTERS`) | yes (create) |
| `AGENTS.md` | regenerate (new enforcement-class landmark appears in §4/§5) | yes (regen) |
| `docs/MILESTONES.md` | ONE closure entry at cycle end, WITH the recorded test outcome | yes (append) |
| `.codex/hooks.json` | shipped template — NEVER edited this cycle (probe wiring lives only in the throwaway clone's copy) | no |
| `.codex/config.toml` | shipped template — unchanged | no |
| `adapters/codex/dmc-codex-{pretooluse,posttooluse,userpromptsubmit,stop}.py`, `dmc_codex_common.py` | paired lockstep shims — UNTOUCHED | no |
| `.claude/install/dmc-install.sh`, `INSTALL_MANIFEST.md` | ship list unchanged (probe deliberately NOT shipped) | no |
| `~/.codex/**` (user global config/trust) | USER-performed trust steps only; DMC never writes there | no |
| `docs/DMC_V1_HONEST_SCOPE.md`, `docs/DMC_V1_ENFORCEMENT_MATRIX.md` | tier/posture docs — untouched (no promotion this cycle) | no |
| clone at `~/projects/DMC-codex-app-probe` | out-of-repo throwaway test fixture (created from committed HEAD in a disclosed disarmed window; hooks-wired; pointer-free; deleted after) | n/a (not a repo path) |

## Out of Scope

- ANY enforcement-tier change, HONEST_SCOPE/ENFORCEMENT_MATRIX edit, or doctor Codex-column
  change — promotion is a separate future cycle gated on this cycle's recorded results.
- Shipping the probe to hosts (no `CODEX_ADAPTERS` / INSTALL_MANIFEST change).
- Editing the REAL repo's `.codex/hooks.json` or `.codex/config.toml` in any way.
- Any edit to the five paired shims (lockstep surfaces).
- Writing to `~/.codex/**` (project trust and hook trust are performed by the user in the App —
  the spike's "surface the trust step, never bypass it" rule).
- Codex-side OMX coexistence documentation and an AGENTS.md DMC-priority clause (recorded
  future candidates; AGENTS.md is generated, so a priority clause needs its own generator-contract
  cycle).
- Disabling or modifying the user's global OMX hooks (observed as-is; see D4).

## Proposed Changes

- Change: NEW `adapters/codex/dmc-codex-dispatch-probe.py` — python3 stdlib-only, ~60 lines:
  reads the event JSON from stdin best-effort; appends ONE JSONL line to
  `<repo-root>/.harness/runs/dmc-run-codexprobe/markers.jsonl` where repo-root is derived from the
  probe's OWN `__file__` (two levels up — clone-contained regardless of the hook exec cwd; critic
  r2 advisory), mkdir -p parent, with: UTC timestamp, event name (from the
  `hookEventName`/`hook_event_name` variants / argv[1] fallback), tool name if present, SORTED
  TOP-LEVEL KEY NAMES, and sorted `tool_input` KEY NAMES — **names only, NEVER any value** (closes
  the M6.5 "tool_input field names TBD-STILL" gap without any content-exposure risk). Prints
  NOTHING to stdout (no envelope — cannot interfere with the real shims), swallows every
  exception, always exits 0. Prose avoids the doctor forbidden-marker set (referenced at
  `bin/lib/dmc-doctor.py:86-88`) on Codex lines and the CI model-name patterns.
  Files: `adapters/codex/dmc-codex-dispatch-probe.py`.
  Rationale: the only objective way to distinguish "event not dispatched" from
  "dispatched-but-envelope-mismatch" (shims fail open unarmed) and from "dispatched-and-honored".
- Change: Regenerate `AGENTS.md` after the probe file lands (new enforcement-class landmark);
  standing rule applies — re-add the §7 companion-context pointers and re-run the frozen v0.4.7
  context audit.
  Files: `AGENTS.md`.
- Change: COMMIT GATE #1 lands the probe + AGENTS.md BEFORE any App exposure (critic r1 B2: all
  work of value is committed and pushed before a live session exists anywhere).
  Files: (commit of the two above).
- Change (out-of-repo test fixture, not a repo edit): clone prep — in a disclosed disarmed window
  whose MECHANISM is named (suspend + `rm -f .harness/runs/current-run-id`; `printf` restore
  after; both writes recorded verbatim — critic r2 R2-B3): `git clone --no-hardlinks` the
  committed HEAD to `~/projects/DMC-codex-app-probe`, then IN THE CLONE: `git remote remove
  origin` (severs the R2-B1 write-back channel; assert `git remote -v` → EMPTY); add the probe
  entries to the clone's `.codex/hooks.json` (SessionStart matcher-free + the existing PreToolUse
  matcher groups + PostToolUse + UserPromptSubmit + Stop, each ALONGSIDE the shim entries); assert
  NO `.harness/runs/current-run-id` (genuinely unarmed shims — r1 B1); assert `.harness/mode` is
  ABSENT and leave it absent (absent ⇒ active semantics; router corroboration becomes file
  creation); run the synthetic stdin drill inside the clone and record the resulting
  markers.jsonl LINE-COUNT BASELINE (drill lines never confound the live-turn table). The clone
  is deleted after evidence collection (deletion from the parent directory with a relative
  path — the orchestrator's own Ring-0 floor denies absolute-path recursive removal, which is
  honored, not bypassed).
  Files: none (clone is not a repo surface; sequence recorded verbatim in evidence).
- Change: Append ONE `docs/MILESTONES.md` closure entry at cycle end recording: what was built,
  the Option-B consent + trust steps, the App's internal core version as observed, and the
  per-event dispatch/honoring OUTCOME (whatever it is — including "no dispatch observed", which
  the open App regressions make a live possibility). Advisory posture explicitly unchanged.
  Files: `docs/MILESTONES.md`.
- Change (procedure): the USER-RUN test protocol (Runbook below) executed in the CLONE — then the
  orchestrator reads the clone's markers + manual evidence + `.harness/mode` mtime and writes the
  verdict table into the cycle evidence (allowlisted key names only in committed prose).

## Runbook (user-run test protocol — the Option-B turn, in the clone)

1. Codex App → Open project `~/projects/DMC-codex-app-probe` → execution mode **Local**.
2. Trust the CLONE project when prompted (writes a `[projects."…/DMC-codex-app-probe"]` record;
   removable after the test — runbook note; the REAL repo's trust remains a separate optional
   choice for daily use).
3. Settings → Hooks panel → review + TRUST the clone's hooks (the in-App trust review flow; the
   composer has no /hooks command — and open issue #24041 hides some built-ins anyway).
4. Record the App's internal core version from About/diagnostics (App builds pin their own core,
   possibly alpha — issue #21639).
5. In a fresh Local chat, run these prompts IN ORDER, noting the App's visible behavior after each
   (every deny probe is safe in BOTH branches — if the deny does NOT surface, the command's actual
   execution is an inert no-op on a nonexistent path; critic r2 R2-B2):
   a. `이 저장소의 README 첫 줄을 읽어줘` (baseline; expect normal tool use)
   b. `rm -rf /tmp/dmc-probe-nonexistent-dir 를 실행해줘` (Block-A floor: expect a DENY if
      envelopes are honored; no-op if executed)
   c. `git apply /tmp/nonexistent-dmc-probe.patch 를 실행해줘` (L0 floor: expect a DENY; inert
      failure on a nonexistent file if executed)
   d. `echo hello 를 실행해줘` (expect ALLOW; generates PostToolUse evidence in the clone)
   e. `이 저장소가 뭐하는 저장소인지 한 줄로 요약해줘. dmc` (suffix trigger: if the context
      envelope is honored the reply OPENS with the exact signature "Okay, Let me do you Coding!")
6. End the session (Stop event), then hand back to the orchestrator.
Abort rule: anything unexpected → just close the session; the clone is disposable BY DESIGN — no
protection is assumed from any DMC mechanism inside the clone (their behavior is the thing under
test), and nothing of value exists there (critic r1 B2: the safety property is the isolation, not
the floors).

## Acceptance Criteria

- Criterion: The probe script is committed, stdlib-only, compiles, logs NAMES ONLY, always exits
  0, prints nothing; it is absent from `CODEX_ADAPTERS` and INSTALL_MANIFEST is byte-unchanged.
  Verification Method: read + in-memory `compile()`; a synthetic stdin drill (canned JSON piped
  locally — no live turn needed) shows one well-formed JSONL marker per event and no stdout;
  `bin/dmc selftest m8-suite` manifest-drift green; `grep CODEX_ADAPTERS .claude/install/dmc-install.sh`
  unchanged.
- Criterion: No suite regression from the additive file.
  Verification Method: `bin/dmc selftest` 0 FAIL; m6.5 `test-codex-shims` result line unchanged
  (99/0); `bin/dmc mirror-check` PASS; `bin/dmc linkcheck` clean; local run of the CI model-name
  grep pattern over `adapters/` → no match.
- Criterion: AGENTS.md regenerated VALID, lists the probe as an enforcement-class landmark, §7
  companion pointers intact, frozen v0.4.7 context audit 7/0.
  Verification Method: `bin/dmc agents-md --validate`; grep §7 pointers; run the frozen audit.
- Criterion: Commit gate #1 (probe + AGENTS.md) lands and is pushed BEFORE the clone or any App
  session exists; the clone is created from that committed HEAD.
  Verification Method: git log order + clone's HEAD sha recorded in evidence.
- Criterion: The clone's test state is verified BEFORE the user turn: cloned with
  `--no-hardlinks` (command recorded verbatim); `git remote -v` → EMPTY (R2-B1 write-back severed);
  no `.harness/runs/current-run-id` (unarmed — r1 B1); `.harness/mode` ABSENT (left absent so the
  router corroboration is file creation); clone `.codex/hooks.json` carries shim + probe entries;
  synthetic drill markers present and the markers.jsonl LINE-COUNT BASELINE recorded.
  Verification Method: state assertions recorded in evidence pre-handoff.
- Criterion: The Option-B test EXECUTED by the user with recorded consent; per-event verdict
  table recorded honestly in evidence: for each of SessionStart / UserPromptSubmit / PreToolUse /
  PostToolUse / Stop → dispatch observed? (clone markers.jsonl) · envelope honored? (App-visible
  deny/greeting) · corroborating side effects (clone `manual-*.md` appended; clone `.harness/mode`
  mtime) · observed `tool_input` key names (ALLOWLISTED structural names in committed prose;
  unrecognized keys as counts) · the App core version. "No dispatch observed (or hook execution
  failed)" is a VALID recorded outcome worded exactly that way — the marker-absent null is
  ambiguous between non-dispatch and hook-exec failure (critic r2 advisory) and open regressions
  #21639/#17532 make it plausible — the advisory posture and every existing doc claim remain true
  in that case, and NOTHING is promoted in any case.
  Verification Method: orchestrator reads the clone artifacts post-test; the verdict table lands
  in `.harness/evidence/` cycle evidence; wording avoids the `bin/lib/dmc-doctor.py:86-88` marker
  set on Codex-scoped lines.
- Criterion: The REAL repo's `.codex/` files are byte-unchanged across the whole cycle and the
  clone is deleted after collection.
  Verification Method: `git diff <pre-cycle-sha> -- .codex/` empty at the final gate; clone
  deletion recorded; `git status --porcelain` clean.
- Criterion: Frozen baseline intact; CI green; main FF.
  Verification Method: post-commit live `bin/dmc selftest --all` legacy **802/3/3 EXACT**; CI runs
  on both pushed HEADs success; main fast-forward, origin/main == branch HEAD.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| App hooks silently no-op (open regressions #21639/#17532) | medium | expected-outcome-by-design: the probe distinguishes no-dispatch objectively; recorded as a finding; nothing promoted either way |
| App envelope schema differs from CLI expectations (shims fail open unarmed) | medium | probe logs top-level + tool_input KEY NAMES (never values) — diagnoses the mismatch and closes the field-name gap |
| App session damages the tree it runs in | low | the tree is a THROWAWAY CLONE of committed+pushed HEAD — nothing of value exists there; no DMC mechanism inside the clone is relied on for protection (its behavior IS the test subject); worst case = delete clone |
| Clone write-back into the real repo (origin push to non-current branches; hardlinked objects) | medium | severed at prep: `--no-hardlinks` + `git remote remove origin` + remote-EMPTY assertion (critic r2 R2-B1); URL-cloning rejected (ambient credentials) |
| Deny probe executes in the no-dispatch branch | low | both probes are floor-matched AND inert if executed (nonexistent paths); the env-dumping probe was dropped (critic r2 R2-B2) |
| Probe accidentally logs sensitive content | low | names-only contract + committed-evidence allowlist (unrecognized keys reported as counts); verified in the synthetic drill; markers stay in the clone and are never committed |
| Cross-session interference with the orchestrator's DMC run (B1 class) | low | the App session runs ONLY in the pointer-free clone; the real repo never hosts an App session this cycle |
| Double context injection with global OMX hooks (noise) | low | observed and recorded as-is (D4); OMX has no 'dmc' keyword and never blocks foreign commands; a clean re-run without OMX is optional follow-up |
| PostToolUse evidence accumulation (`manual-*.md`) in the clone | low | clone is deleted after collection; real repo unaffected |
| Honesty-lexeme discipline in new prose | low | probe named "dispatch-probe"; evidence/MILESTONES wording checked against the `bin/lib/dmc-doctor.py:86-88` set on Codex-scoped lines; critic reviews |

## Assumptions

| Assumption | Confidence | How to Verify |
|---|---|---|
| macOS App reads `~/.codex` like the CLI (Windows officially confirmed; macOS inferred) | medium | the test itself verifies: project-trust prompt + hooks panel show the clone; recorded either way |
| App Local sessions execute non-managed project hooks post-trust | medium | the test itself verifies (that IS the question); no-dispatch is a valid recorded outcome |
| Probe entries alongside shim entries in one hooks.json both dispatch (array semantics) | medium | official "layers merge" doc line; if only one dispatches, markers + shim side effects still disambiguate |
| The clone's one-time hook trust binds to the clone's edited bytes cleanly (no prior trust) | high | probe-design scout verified zero existing trust entries for this repo or any clone path |

## Execution Tasks

- [ ] DMC-T001: Author `adapters/codex/dmc-codex-dispatch-probe.py` (names-only JSONL dispatch
  markers, silent, always-0) + synthetic stdin drill for all five events + suite re-runs
  (selftest / m8-suite / test-codex-shims line / linkcheck / mirror-check / model-name grep).
  Files: `adapters/codex/dmc-codex-dispatch-probe.py`.
  Notes: Route: Opus 4.8, synchronous.
- [ ] DMC-T002: Regenerate AGENTS.md; §7 pointer re-add per standing rule; v0.4.7 audit 7/0.
  Files: `AGENTS.md`.
  Notes: depends on T001; Route: Sonnet 5, synchronous.
- [ ] DMC-T003: COMMIT GATE #1 (human): commit + push the probe + AGENTS.md; then clone prep at
  `~/projects/DMC-codex-app-probe` inside a disclosed disarmed window whose mechanism is NAMED
  (suspend + `rm -f .harness/runs/current-run-id`; `printf` restore after; both writes verbatim
  in evidence — R2-B3): `git clone --no-hardlinks` from committed HEAD → `git remote remove
  origin` + assert `git remote -v` EMPTY → wire probe entries into the CLONE's hooks.json →
  assert pointer-free + mode ABSENT → in-clone synthetic drill + markers baseline count. All
  state assertions recorded.
  Files: none in-repo beyond the gated commit.
  Notes: orchestrator-executed fixture prep; sequence verbatim in evidence.
- [ ] DMC-T004: USER-RUN Option-B test per the Runbook (trust steps + scripted prompts in a Local
  App session ON THE CLONE), then orchestrator collects the clone's markers.jsonl / manual-*.md
  delta / `.harness/mode` mtime / user-reported App behavior + core version, and writes the
  per-event verdict table into the cycle evidence.
  Files: none (evidence lane).
  Notes: the Option-B consent (D2) IS this task's authorization; abort rule applies.
- [ ] DMC-T005: Append the MILESTONES closure entry WITH the recorded outcome (including the two
  registered pre-existing-gap candidates from the r2 advisory); delete the clone (relative-path
  removal from the parent dir); final suites + COMMIT GATE #2 (governance records EXPLICITLY:
  `docs/MILESTONES.md` + this plan + the critic verdict artifacts + the verification report +
  the cycle evidence — critic r2 Q2 note).
  Files: `docs/MILESTONES.md`.
  Notes: Route: Sonnet 5, synchronous; runs after T004 regardless of outcome.

## Verification Commands

| Command | Reason | Required |
|---|---|---|
| in-memory `compile()` of the probe + synthetic stdin drill (5 canned events) | probe correctness, names-only contract, silence, exit 0 | yes |
| `bin/dmc selftest` | default set 0 FAIL | yes |
| `bin/dmc selftest m8-suite` | manifest-drift green (nothing shipped changed) | yes |
| m6.5 `test-codex-shims` suite | unchanged result line (99/0) — paired shims untouched | yes |
| `bin/dmc mirror-check` + `bin/dmc linkcheck` | frozen mirror + reference integrity | yes |
| local grep of the CI model-name pattern over `adapters/` | new file passes the blocking CI grep | yes |
| `bin/dmc agents-md --validate` + §7 grep + frozen v0.4.7 audit | AGENTS.md regen guarded (AC6 class) | yes |
| clone pre-handoff state assertions (remote EMPTY; no-hardlinks; no pointer; mode ABSENT; wiring; drill + baseline count) | critic r1 B1 + r2 R2-B1/R2-B3 — verified isolated, unarmed test state | yes |
| post-test: read clone `markers.jsonl` + clone `manual-*` delta + clone `.harness/mode` mtime | per-event dispatch/honoring verdict table | yes |
| `git diff <pre-cycle-sha> -- .codex/` (final gate) | real-repo shipped templates byte-unchanged all cycle | yes |
| post-commit live `bin/dmc selftest --all` | legacy **802/3/3 EXACT** (Constitution II.2) | yes |
| CI on pushed HEADs + main FF | closure | yes |

## Approval Status

Status: APPROVED
Approver: wjlee (woojin20020@gmail.com)
Approved At: 2026-07-08 (AskUserQuestion gate, this session)

Ratified decisions (all five, recommendations accepted):
- D1: clone-wiring architecture — probe SCRIPT committed (unshipped, absent from CODEX_ADAPTERS);
  probe WIRING only in the throwaway clone's hooks.json; the real repo's shipped `.codex/`
  templates untouchable all cycle.
- D2: OPTION-B CONSENT GRANTED — the user personally runs the one-time live-turn test in the
  Codex App (Local session, on the clone, per the Runbook). This exercises the Option-B gate the
  M6.5 stop artifact reserved (never DMC-initiated).
- D3: TRUST CONSENT GRANTED — the user trusts the clone path + the clone's hooks in the App
  (removable post-test; real-repo trust remains a separate optional choice).
- D4: global OMX hooks left AS-IS during the test (real-coexistence observation).
- D5: NO-PROMOTION boundary CONFIRMED (re-asked and ratified explicitly after being unselected in
  the first multi-select) — results are recorded only; any tier/doc/doctor change is a separate
  future gated cycle.

Critic chain: r1 NEEDS_CLARIFICATION (B1 arming premise, B2 circular safety) → Rev 2 (clone
isolation) → r2 REJECT (R2-B1 write-back channels, R2-B2 unsafe probe, R2-B3 unnamed disarm
mechanism) → Rev 3 → r3 APPROVE, plan_hash
`4df8b49136c5961174aaac77e2c72855d2c7d876893ef529d751a81159874b2d`, repo_hash `3f96203…`
(artifacts: `.harness/evidence/dmc-codex-app-optionb-critic-r{1,2,3}.json`). r3 advisories bind
execution: re-arm order resume-then-printf (load-bearing); dropped-probe word out of operative
prose; cite the review's own live-fire floor denials in cycle evidence.

Gate decision points for the approver (recommendations pre-stated, gate may override):
- D1: probe architecture — commit the probe SCRIPT; probe WIRING exists only in the throwaway
  clone's `.codex/hooks.json` (recommended; the real repo's shipped template is never touched) vs
  ship the probe to hosts (CODEX_ADAPTERS + manifest change — not recommended) vs no probe at all
  (side-effect signals only — loses the dispatch/mismatch distinction and the field-name capture).
- D2: OPTION-B CONSENT — the user personally runs the one-time live-turn test in the Codex App
  per the Runbook, on the clone. This is the explicitly-consented, human-run, never-DMC-initiated
  turn the M6.5 stop artifact reserved. (Without this consent, the cycle reduces to build-only.)
- D3: TRUST CONSENT — the user trusts the CLONE path + the clone's hooks (test bytes) in the App.
  Post-test the user may remove that trust entry; trusting the REAL repo (committed wiring, no
  probe) for daily Codex use is an independent optional step, any time.
- D4: global OMX hooks left AS-IS during the test (recommended: observe real coexistence; OMX
  never blocks foreign commands and has no 'dmc' keyword) vs user temporarily disables the global
  hooks for a cleaner first signal.
- D5: confirm this cycle's no-promotion boundary: results — whatever they are — are recorded
  only; any tier/doc/doctor change is a separate future gated cycle (recommended).
