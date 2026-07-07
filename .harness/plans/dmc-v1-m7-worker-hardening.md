# Plan: DMC v1 M7 — Worker/Delegation Hardening (P15 + P14 records)

Plan ID: dmc-v1-m7-worker-hardening · Date: 2026-07-07 · Format: PLAN_SCHEMA.md
Milestone-scoped plan for master plan §M7 (task DMC-T012, `.harness/plans/dmc-v1-runtime-upgrade.md`
L308–322; Rev 3 execution order M6→M6.5→M8→M7→M9→M10 — M7 runs AFTER M8, so the
INSTALL_MANIFEST re-proof obligation applies: the M8 installer already ships the pre-M7
validators, an accepted interim risk per master risk row L165).

Risk: medium — **PROTECTED SURFACE** (worker validators under `.claude/hooks/`), explicitly
authorized for this milestone by master §M7 and the master Relevant-Files row L74. Heavy critic
rotation expected (M6-grade, per handoff §Next step).

**Rev 2** — revised after DMC critic r1 REJECT (persisted at
`.harness/evidence/dmc-v1-m7-critic-verdict-r1.json`; bound plan_hash `6081ab7b…7206`,
repo_hash `0ac72b8e…`). Surgical amendments only. Blockers closed:
(B1) the unconditional provider/type cross-checks and the `provider_target.provider`
non-empty task floor would have flipped pinned legacy ACCEPT rows to FAIL
(v0.2-verify:36 · v0.2.1-verify:17-18 · every v0.2.1.1 accept() row · v0.2.3 V6) — replaced
with COMPATIBILITY-VERIFIED semantics: the `type == "mock"` legacy carve-out and the
empty-task-provider routing carve-out, each with positive AND negative fixture controls
(full caller sweep recorded in §Current Repo Findings; every legacy VAL caller re-verified
against the new floors this session);
(B2) `manual-import-adapter.py:85` also dynamically imports `diff_paths` — the preserved-API
constraint now pins `diff_paths(patch) -> set[str]` VERBATIM (byte-identical body, legacy
semantics) and the hardened parsing moves to a NEW `diff_entries()` function, so the
never-edit manual-import surface is provably unaffected.
Advisories folded: (A1) fixture `reviewer_role` values pinned to real registry ids;
(A2) `sys.dont_write_bytecode = True` mandated before every importlib load;
(A3) `authorize` creates its output directory; host-policy divergence disclosed as an
M9/M10 follow-up; (A4) both chain-hash rules pinned exactly (line bytes EXCLUDING the
terminating LF; apply-authorization `prev_hash` MUST be `"genesis"` in v1.0);
(A5) honest enforcement-tier sentence added (skill-mandated chain, scope-lock floor);
(A6) diff-parser path-source precedence pinned + space-bearing-path fixture row;
(A7) gate-scope disclosure line added to §Approval Status.

Task numbering: sub-numbered `DMC-T012.1 .. DMC-T012.6` under master task DMC-T012.
`grep -rnE "DMC-T012\.[0-9]" .harness/ docs/` returned ZERO hits before authoring this plan
(verified 2026-07-07; carry-forward #8 pattern). The burned `DMC-T012a–e` letter-suffix
namespace (renumbered away by the M6.5 critic) is NOT reused; it persists only in immutable
records.

## Goal

Close the worker-bridge half of the audited bypass surface: make the two v0.2-era worker
validators (`.claude/hooks/worker-result-check.py`, `.claude/hooks/worker-context-guard.sh`)
deny the canonical-five classes (4) and (5) plus the empty-allowed bypass; make the
worker review stage machine-checkable (`dmc worker review-check` implementing the
already-committed `dmc.worker-review.v1` contract); implement the hash-chained
apply-authorization consumed by P7 at apply, with post-apply fidelity at the names+hunk-count
tier; ship the P14 delegation runtime-records pipeline deferred by M5; and re-prove the M8
INSTALL_MANIFEST after the validators change. All while keeping the pinned legacy baseline
802/3/3 EXACT and the v0.3.3 three-provider contract suite green UNCHANGED (34/0/2).

## User Intent

Continue the approved dmc-v1-runtime-upgrade in the Rev 3 order: M7 is the next unstarted,
unapproved milestone (handoff rev 6 §Next step). The user gates milestone approval, staging,
commit, and push; workers implement; a non-authoring critic reviews this plan before any edit;
an independent verifier validates the build before closure.

## Current Repo Findings

All findings re-verified live this session (2026-07-07, HEAD `0ac72b8`):

- **Canonical-five (4)(5) + empty-allowed are the M7 remainder.** Master enumeration at
  `dmc-v1-runtime-upgrade.md:134-141`: (4) worker result carrying a JWT-class token,
  (5) worker rename-diff touching a forbidden file. M6 closed (1)(2)(3) (its adversarial suite
  38/0); the master evidence table row L365 pins M7's suite = "(4)(5) + empty-allowed +
  v0.3.3 green".
- **Class (4) gap confirmed**: `worker-result-check.py:21-23` SECRET_VALUE covers only 5
  classes (`sk-`, `AKIA`, PEM, `xox[baprs]-`, `ghp_`). No JWT (`eyJ…`), no Bearer, no
  `authorization:`, no `access_token/refresh_token/id_token` kv, no `gh[osu]_`, no `ya29.`.
  The identical narrow pattern sits inline in `worker-context-guard.sh:54`.
- **Canonical detector source**: `.claude/workers/providers/oauth-cli/oauth-cli-adapter.py`
  — `SECRET_VALUE` (:32-34), `OAUTH_TOKEN_PATTERNS` (:37-44, six classes),
  `PLACEHOLDER` false-positive suppressor (:46), `find_token_material()` value-blind
  labels-only scanner (:90-105). Single-source reuse precedent:
  `manual-import-adapter.py:66-84` dynamically imports these via
  `importlib.util.spec_from_file_location`, fail-closed, with the comment "Shared-source
  EXACT reuse (no re-derived subset)". The same `_load()` also imports `DISALLOWED` FROM
  `worker-result-check.py` — an API-compatibility constraint on M7's edit.
- **Class (5) gap confirmed**: `worker-result-check.py:26-34` `diff_paths()` parses only
  `---`/`+++` lines. Pure rename diffs (`diff --git` + `rename from/to`, no `---/+++`),
  copy diffs (`copy from/to`), and binary diffs (`Binary files … differ` / `GIT binary
  patch`) contribute ZERO paths; with `files_changed` omitted, `:56` (`dp != fc`) also
  passes vacuously.
- **Empty-allowed fail-open confirmed**: `:59` `if allowed and p not in allowed` — empty or
  missing `allowed_files` skips the scope check for every path.
- **No task_id/provider cross-check, no required-field presence check** anywhere in
  `worker-result-check.py` (result.task_id never compared to task.task_id;
  `provider_metadata.provider/provider_type` never compared to `task.provider_target`).
- **worker-context-guard fail-OPEN on parse error**: both embedded python blocks
  (`worker-context-guard.sh:18-21`, `:50-55`) do `except Exception: sys.exit(0)` under
  `2>/dev/null`; the first block's `PATHS="$(python3 … 2>/dev/null)"` also passes silently
  if python3 is absent (empty path list ⇒ "clean").
- **Review contract already committed (M5)**: `.harness/schemas/worker-review.schema.md`
  (`dmc.worker-review.v1`) fully specs `dmc worker review-check`: mandatory check kinds
  `scope-compat`, `token-scan`, `fidelity`, `disallowed-category` (`contract` is a legal
  kind but not mandatory); `decision == apply` ⇒ every check PASS; `reviewer_role` must be
  `may_mutate: false`; empty `checks` REFUSED; `task_result_hash` + `prev_hash` chain
  fields; four named negative controls (:37-39). The legacy root `WORKER_REVIEW_SCHEMA.md`
  (v0.2, prose-checks object, `apply_run_id`) is a DIFFERENT, frozen contract — not edited.
- **apply_authorization has zero implementation**: the string appears only in
  docs/plans/schemas (`docs/DMC_V1_RUNTIME_ARCHITECTURE.md:272-289` — P15 Out =
  `apply_authorization.json` "consumed by P7 during apply: applied paths ⊆
  task.allowed_files ∩ run scope"; fidelity "names + hunk-count tier in v1.0"). No code, no
  schema file, no instance. `.harness/workers/reviews/` contains only `.gitkeep` (reviews
  are 100% prose today).
- **Delegation records runtime deferred to M7 by M5**: `bin/lib/dmc-delegation.py:9-14`
  docstring — "the delegation runtime records pipeline — appending `delegations.jsonl` at
  dispatch time, enforcing validate-before-consumption live during a run — is out of scope
  and lands in M7". `main()` choices=["validate"] only; selftest section `delegation`
  29/0. Known judgment call at :44-53: `scope_lock_ref` is presence-checked only —
  content cross-validation named "a runtime (M7) concern".
- **bin/dmc has NO `worker` verb**; single top-level `case` at `bin/dmc:206` is the verb
  source of truth (linkcheck auto-derives verbs from it,
  `dmc-orchestration-linkcheck.py:121-152`). Suite-runner precedent: `M8SUITEDIR` +
  guarded `run_m8_suite()` (`bin/dmc:187-201`); selftest sections are registered in BOTH
  the `--all` block (:316-348) and the named-target block (:350-381); the no-arg default
  (9 sections, 75/0) is frozen.
- **v0.3.3 constraints**: `bin/lib/dmc-v0.3.3-verify.sh` runs `worker-result-check.py` as
  its validator stage; pinned baseline row = 34 PASS / 0 FAIL / 2 N/A inside the legacy
  aggregate 49 tools / 802/3/3 EXACT (`.harness/evidence/dmc-v1-m3-baseline.md`). Its C9
  (:137-139) requires `.claude/hooks/` + `WORKER_{TASK,RESULT,REVIEW}_SCHEMA.md` +
  providers WORKING-TREE-UNCHANGED — M7 edits must be committed before the legacy chain
  runs green (carry-forward #7 replica pattern). Its synthesized tasks ALWAYS carry one
  allowed_files entry (`dmc-v0.3.3-verify.sh:36`) and the minimal task fields
  {task_id, objective, allowed_files, forbidden_files, context_summary, relevant_snippets,
  expected_output_type, provider_target{…}} — the task-side floor pinned below is exactly
  compatible. `bin/lib/dmc-v0.2.1-verify.sh:58-60` byte-pins both validators via
  `git diff --name-only` — same commit-first consequence.
- **INSTALL_MANIFEST mechanics**: manifest is name-only (no hashes) generated by
  `.claude/install/dmc-install.sh --emit-manifest` (stdout); `bin/lib` and
  `.harness/schemas/*.schema.md` are auto-listed (LC_ALL=C sorted), `.claude/hooks` is a
  HARDCODED list (:37-39). Content-only edits to the two validators do NOT drift the
  manifest; NEW bin/lib or schema files DO ⇒ regen + commit required, then
  `tests/fixtures/m8/test-manifest-drift.sh` (byte-equality emit-vs-committed) is clean
  again. The M8 uninstaller already strips worker-context-guard (rm loop :63, `is_dmc()`
  :188-191) and `worker-result-check.py` (:64); `dmc doctor` deliberately excludes the
  worker validators (`dmc-doctor.py:72-75`). M7 therefore makes NO installer/uninstaller/
  doctor code edits.
- **Pre-M7 rollback fixture already exists**: `tests/fixtures/hooks-v0.6.5/hooks/
  {worker-result-check.py,worker-context-guard.sh}` verified BYTE-IDENTICAL to the live
  files this session (`cmp` clean; the two files are untouched since v0.2). Master §M7
  rollback ("pre-M7 validator retained as fixture") is satisfied by citing this existing
  committed fixture — no new fixture commit is needed (M6-T011.1-style pre-commit not
  required for M7).
- **Skills wiring today**: `dmc-worker-dispatch/SKILL.md:13` already runs
  worker-context-guard fail-closed; `dmc-worker-review/SKILL.md` step 4 applies accepted
  proposals by hand under `/dmc-start-work` with only a prose `apply_run_id` link — no
  machine gate. Worker-bridge skills are EXCLUDED from the M6.5 `.agents/skills` mirror by
  design (no mirror updates needed).
- **linkcheck**: `worker-review.schema.md:3` already names `dmc worker review-check` in a
  code span; linkcheck is green today (17/0) and the new `worker` verb arm keeps it green.
- **Legacy VAL-caller sweep (Rev 2, exhaustive — every bin/lib script invoking
  worker-result-check.py, re-verified this session)**: the committed task
  `.harness/workers/tasks/mock-001.json` declares `provider_target.type="mock"`,
  `provider="mock-local"`, while the glm adapter unconditionally stamps
  `provider_type="api_key"`, `provider="glm-api"` (`glm-api-adapter.py:198-201`);
  `dmc-v0.2-verify.sh:35-36` (mock-001 task + committed mock-001 result — result carries
  the full C1 floor and matching `type/provider`, verified), `dmc-v0.2.1-verify.sh:10,17-18`
  and every `dmc-v0.2.1.1-verify.sh` `accept()` row (glm results vs the mock-001 task)
  expect ACCEPT — so provider cross-checks MUST be skipped for `type=="mock"` tasks.
  `dmc-v0.2.3-verify.sh:26,54-58` V6 builds an `api_key` task with `provider=""` and
  expects ACCEPT after routing — so provider equality MUST be skipped when the task's
  provider is empty (type equality still holds there: `api_key==api_key`). All other
  callers construct matching pairs: v0.2.2 (`oauth_cli/oauth-cli`, :19-20; its `sectask`
  :105-106 never reaches the validator — context-guard refuses dispatch),
  v0.2.4 (`api_key/glm-api`, `oauth_cli/oauth-cli`, :22-26,57),
  v0.3.1 (`manual_import/manual-import`, :35-43),
  v0.3.3 (all three, :22-31,55); v0.2.3's `nopt.json` (no provider_target, empty
  allowed_files) is refused at the ROUTER stage (V5, :52) and never reaches the validator.
  All tasks in ACCEPT rows carry non-empty `allowed_files`; all adapter/committed results
  in ACCEPT rows carry the C1 floor keys and a task-matching `task_id`.
- **manual-import dynamic-import surface (Rev 2)**: `manual-import-adapter.py:85` imports
  `diff_paths` in addition to `DISALLOWED` (:84) — BOTH are preserved-API constraints on
  the T012.1 edit. `manual-import-adapter.py:31-33` also sets
  `sys.dont_write_bytecode = True` before its importlib loads, with the explicit comment
  that shared-detector imports must not write `__pycache__` — the same guard is mandated
  for every new importlib site in M7.
- **Registry ids (Rev 2)**: `orchestration/roles.json` role ids are
  `strategic-orchestrator, implementer, critic-falsifier, release-auditor, verifier,
  human-release-gate` — the `worker-review.schema.md:17` examples (`critic|release-auditor`)
  are partly illustrative (`critic` does not resolve); fixtures must use real ids.
- **Host install surface for the new artifact family (Rev 2)**: `dmc-install.sh:49`
  HARNESS_DIRS creates `workers/{tasks,results,reviews,sessions}` but NOT
  `workers/authorizations`, and the emitted host `.gitignore` block (:77-82) local-onlys
  the sibling worker dirs but not `authorizations` — installer is frozen for M7, so the
  `authorize` verb must create its own output directory and the host-policy divergence is
  a disclosed M9/M10 follow-up.

## Relevant Files

| Path | Reason | Allowed to Edit |
|---|---|---|
| .claude/hooks/worker-result-check.py | class (4)(5) + empty-allowed + cross-checks + required-field hardening | yes (T012.1 — SOLE owner; PROTECTED, authorized by master §M7 / row L74) |
| .claude/hooks/worker-context-guard.sh | fail-closed on parse error + imported token classes | yes (T012.1 — SOLE owner; PROTECTED, same authorization) |
| bin/lib/dmc-worker-review.py (NEW) | review-check / authorize / apply-check / fidelity CLIs + self-test | yes (T012.2 — SOLE owner) |
| .harness/schemas/apply-authorization.schema.md (NEW) | dmc.apply-authorization.v1 contract | yes (T012.2) |
| .harness/workers/authorizations/.gitkeep (NEW) | authorization artifact directory | yes (T012.2) |
| bin/lib/dmc-delegation.py | append/check runtime-records verbs (P14 records) | yes (T012.3 — SOLE owner; existing validate + 29 selftest rows preserved) |
| bin/dmc | `worker` + `delegation append/check` verb arms, usage(), M7SUITEDIR + run_m7_suite(), selftest sections worker-check + m7-suite in --all + named blocks | yes (T012.4 — SOLE owner of bin/dmc) |
| .claude/skills/dmc-worker-review/SKILL.md | wire review-check → authorize → apply-check → fidelity into the apply flow | yes (T012.4) |
| .claude/skills/dmc-worker-import/SKILL.md | wire hardened result-check + review-check into import | yes (T012.4) |
| tests/fixtures/m7/** (NEW) | M7 adversarial/chain/records suite (_m7common.sh + 3 test scripts) | yes (T012.5 — SOLE owner) |
| INSTALL_MANIFEST.md | regenerated via `--emit-manifest` after new bin/lib + schema files land | yes (T012.6 — regen-only, never hand-edited) |
| .harness/evidence/dmc-v1-m7-*.md, .harness/verification/dmc-v1-m7-worker-hardening.md | evidence + verification report | yes (T012.6) |
| .harness/plans/dmc-v1-m7-worker-hardening.md (this file), .harness/plans/dmc-v1-runtime-upgrade.md §Approval Status | revisions + approval records only | yes (orchestrator lane, gate-driven) |
| .claude/hooks/{pre-tool-guard,scope-guard,secret-guard,evidence-log,dmc-router,stop-verify-gate}.sh, .claude/hooks/lib/secret-paths.sh, .claude/settings.json | M6 hook surface — FROZEN (master §M7 Not-edit) | no |
| .claude/workers/providers/** (adapters, router, fixtures) | never edited in any milestone (master L92); read/import-only | no |
| .claude/install/dmc-install.sh, dmc-uninstall.sh, bin/lib/dmc-doctor.py | M8 surface; manifest REGEN reads the installer, never edits it | no |
| WORKER_TASK_SCHEMA.md, WORKER_RESULT_SCHEMA.md, WORKER_REVIEW_SCHEMA.md (root) | legacy v0.2 contracts, C9 byte-pinned; the v1 review contract lives in .harness/schemas/ | no |
| .harness/schemas/worker-review.schema.md | already-committed M5 contract — implemented, not modified | no |
| tests/fixtures/{m6,m6.5,m8,hooks-v0.6.5}/**, .agents/skills/** | other milestones' fixtures/mirrors | no |
| orchestration/roles.json, bin/lib/dmc-roles.py, bin/lib/dmc-scope-lock.py | read-only lookups/adjudication consumed by new CLIs | no |

## Out of Scope

- Provider adapters, provider router, provider fixtures — never edited (master L92); M7
  IMPORTS from oauth-cli-adapter.py read-only at runtime.
- The M6 hook surface and `.claude/settings.json` (no new hook registrations; the two
  worker validators are skill-wired, not settings-registered — no session reload needed).
- Installer/uninstaller/doctor code (M8 surface; handoff: "must not double-touch the
  installer surface beyond the manifest re-run").
- Root `WORKER_*_SCHEMA.md` edits (legacy v0.2 contracts stay frozen; C9 pins them).
- P14 automated multi-agent scheduling (architecture defers it beyond v1.0); M7 ships
  records + validation, invoked by the orchestrator/skills, not a scheduler.
- M9 release-gate composition and CI (consumes M7's chain checks later); Option B Codex
  live verification; M10 docs.
- The 3 pinned legacy FAILs (carry-forward #1) — untouched.
- No enforcement-parity claim for Codex: worker validators ship to hosts, but the Codex
  boundary remains the pre-commit/CI gate under Option A (M6.5 record); M7 does not extend
  any parity claim.

## Proposed Changes

### 1. `worker-result-check.py` hardening (T012.1 — protected surface)

Decision-complete design, preserving the CLI contract (`worker-result-check.py <task.json>
<result.json>`, stdout `ACCEPT`/`REJECT` + reason bullets, exit 0/1, usage exit 2) and the
FULL manual-import dynamic-import surface (`manual-import-adapter.py:84-85`): the
module-level `DISALLOWED` name+shape (list of `(compiled_regex, label)`) AND
`diff_paths(patch) -> set[str]` — name, arity, return shape, and legacy semantics all
preserved VERBATIM (byte-identical function body). The hardened parsing lives in a NEW
function (below), never in a mutation of `diff_paths`' contract:

- **Token classes — single-source import (no re-derived subset).** Load `SECRET_VALUE`,
  `OAUTH_TOKEN_PATTERNS`, `PLACEHOLDER`, `find_token_material` from
  `.claude/workers/providers/oauth-cli/oauth-cli-adapter.py` via
  `importlib.util.spec_from_file_location`, path resolved relative to the validator's own
  `__file__` (`../workers/providers/oauth-cli/oauth-cli-adapter.py`), mirroring the
  manual-import precedent. Load failure ⇒ clean `REJECT` exit 1 with reason
  `detector source missing/unloadable (fail-closed)` — availability degrades, never
  enforcement. The scan runs `find_token_material(json.dumps(task), json.dumps(result))` —
  value-blind labels only (token VALUES never printed), PLACEHOLDER spans excluded. The
  local 5-class `SECRET_VALUE` literal is REPLACED by the imported one (drift-proof; the
  local copy's only consumer was this file's own scan). Every importlib site (here, the
  context-guard heredocs, and dmc-worker-review.py) sets `sys.dont_write_bytecode = True`
  BEFORE loading, per the `manual-import-adapter.py:31-33` precedent — no `__pycache__`
  may ever be written into the never-edit providers tree (the suites' porcelain guard is
  the negative control).
- **Diff parsing — extended, fail-closed, in a NEW function.** `diff_paths()` is preserved
  verbatim (legacy `---`/`+++` semantics — the manual-import import surface). A NEW
  `diff_entries(patch)` returns structured entries (`path(s)`, `kind ∈ {text, rename,
  copy, binary}`, per-path `@@` hunk count) and is the ONLY parser the hardened validator
  flow and the T012.2 `fidelity` verb use (fidelity imports it via the same importlib
  pattern — single source). It recognizes: `---`/`+++` paths, `rename from/to <path>`,
  `copy from/to <path>`, `Binary files a/X and b/Y differ`, `GIT binary patch` sections,
  and `diff --git a/X b/Y` headers; `/dev/null` excluded. Path-source precedence (pinned):
  `---`/`+++`, `rename from/to`, and `copy from/to` lines are the AUTHORITATIVE path
  sources; the `diff --git` header is used ONLY for binary/zero-path detection and
  c-quote refusal, never as a path source when an authoritative source exists (git does
  not c-quote space-bearing paths, so header splitting is heuristic there — the
  authoritative-source rule plus the `dp != fc` equality check keeps space-path handling
  fail-closed: over-reject, never bypass; a space-bearing-path fixture row is mandatory).
  Fail-closed rules: (a) a non-empty `proposed_patch` that yields ZERO parsed paths ⇒
  REJECT (`unparseable diff`); (b) any `diff --git` line containing a `"` (git c-quoted
  path — newline/non-ASCII/quote characters) ⇒ REJECT (`c-quoted path refused`) rather
  than a best-effort unquote. Honest tier: no c-quote unescaping is attempted in v1.0.
- **Empty-allowed ⇒ DENY.** `task.allowed_files` missing, non-list, or empty ⇒ REJECT
  (`empty allowed_files: scope-less worker tasks are refused`). BREAKING for analysis-only
  flows (must now enumerate the files under analysis); recorded for the M10 release notes
  per master risk row L164.
- **Task-side floor** (compatibility-verified against every legacy VAL caller, Rev 2):
  `task_id` non-empty; `allowed_files` non-empty list; `provider_target` present with
  non-empty `type` ⇒ else REJECT. `provider_target.provider` is NOT floor-required and MAY
  be empty (the v0.2.3 V6 "route by type" shape) — an empty task provider only skips the
  provider-equality cross-check below, it never weakens the scope/secret/category checks.
- **Result-side required-field presence** (key-presence; the proven v0.3.3 C1 floor):
  `task_id, summary, files_considered, files_changed, proposed_patch, instructions,
  confidence, no_direct_mutation, provider_metadata.{provider_type, provider,
  credential_exposure}` ⇒ missing key REJECT. Remaining WORKER_RESULT_SCHEMA keys
  (`risks, assumptions, test_suggestions, unresolved_questions`, metadata extras) absent ⇒
  stderr warning only (disclosed tier — keeps v0.3.3 success fixtures ACCEPT).
- **Cross-checks** (Rev 2 — compatibility-verified semantics, provenance-consistency tier,
  NOT authentication: `provider_metadata` is worker-supplied):
  `result.task_id == task.task_id` — UNCONDITIONAL, mismatch ⇒ REJECT.
  Provider cross-checks are SKIPPED entirely when `task.provider_target.type == "mock"`
  (the v0.2 mock-flow legacy: a mock task may be served by any adapter in mock mode —
  exactly what the pinned v0.2.1/v0.2.1.1 rows do; disclosed carve-out). Otherwise:
  `result.provider_metadata.provider_type == task.provider_target.type` ⇒ else REJECT;
  and when `task.provider_target.provider` is non-empty,
  `result.provider_metadata.provider == task.provider_target.provider` ⇒ else REJECT
  (empty task provider = "route by type", v0.2.3 V6 — provider equality skipped,
  type equality still enforced). Negative controls: a NON-mock type mismatch REJECTs and a
  non-empty-provider mismatch REJECTs (fixture rows); positive controls: the mock
  carve-out ACCEPT and the V6-shape ACCEPT (fixture rows). The carve-outs gate ONLY the
  provider-identity consistency checks — token scan, scope, category, diff, and field
  floors remain unconditional.
- **Fail-closed input handling**: malformed/unreadable task or result JSON ⇒ clean REJECT
  exit 1 with reason (no traceback); duplicate-key JSON refused (object_pairs_hook, same
  convention as `dmc-critic-verdict.py`).

### 2. `worker-context-guard.sh` fail-closed (T012.1)

- Both embedded python blocks restructured to capture their exit status; ANY failure —
  JSON parse error, missing file, python3 absent, detector-import failure — ⇒
  `FAIL-CLOSED` message on stderr + exit 1 (today: silent exit 0). The path-extraction
  block distinguishes "parsed, zero paths" (legal) from "failed to parse" (refuse) via an
  explicit sentinel line protocol instead of `2>/dev/null` swallowing.
- The inline 5-class token regex (:54) is replaced by the same importlib load of
  `find_token_material` (SECRET_VALUE + OAUTH_TOKEN_PATTERNS + PLACEHOLDER exclusion) —
  same single source, same value-blind output (labels only; the guard keeps printing
  offending PATHS, never values).
- `is_secret_path` sourcing from `lib/secret-paths.sh` unchanged (M6-frozen file, not
  edited).

### 3. NEW `bin/lib/dmc-worker-review.py` (T012.2) — P15 review/chain CLIs

One module, four sub-verbs, validate-family conventions (exit 0 VALID/PASS · 3 REFUSED ·
2 usage; deterministic; value-blind; duplicate-key-rejecting JSON; secret-shaped path
refusal as in `dmc-instance-validate.py`):

- **`review-check <review.json> [--task T --result R]`** — validates a
  `dmc.worker-review.v1` record exactly per `.harness/schemas/worker-review.schema.md`:
  schema string exact; `task_id`/`result_id`/`provider` non-empty; `task_result_hash` hex
  ≥16; `prev_hash` hex≥16 or `genesis`; `checks` non-empty, every `check` ∈ the 5-kind
  enum, every `result` ∈ {PASS, FAIL}, mandatory kinds {scope-compat, token-scan,
  fidelity, disallowed-category} all present; `decision` ∈ {apply, reject};
  `decision==apply` ⇒ all PASS; `reviewer_role` resolved via read-only subprocess
  `bin/lib/dmc-roles.py lookup` (fail-closed, M5 delegation precedent) and must be
  `may_mutate: false`. The registry is AUTHORITATIVE for role ids: fixtures use real ids
  (`critic-falsifier`, `release-auditor`, `verifier`) — the schema's `:17` example string
  `critic|release-auditor` is partly illustrative (`critic` does not resolve in
  `orchestration/roles.json`); disclosed, schema file NOT edited (Rev 2/A1). With
  `--task/--result`: recompute
  `task_result_hash = sha256(task_file_bytes + b"\n" + result_file_bytes)` and require
  equality; `result_id` must equal `result.provider_metadata.invocation_id` when that is a
  non-empty string, else `result.task_id`. Reason codes `WREV-*`.
- **`authorize --task T --result R --review REV --run RUN_ID [--out PATH]`** — REFUSES
  unless review-check passes on REV with `--task/--result` binding AND `decision==apply`
  AND the hardened result validator (`worker-result-check.py`, invoked as a subprocess)
  ACCEPTs (task, result). Emits `dmc.apply-authorization.v1` (default
  `.harness/workers/authorizations/<task_id>.json`; the verb CREATES the output directory
  if absent — required on hosts, whose installer HARNESS_DIRS predates this family;
  Rev 2/A3): `{schema, task_id, result_id, review_ref, task_result_hash,
  review_hash = sha256(review bytes), run_id, authorized_paths, prev_hash}` where
  `authorized_paths` = the result's files_changed ∪ parsed diff paths, re-checked ⊆
  `task.allowed_files`. `prev_hash` MUST be the literal `"genesis"` in v1.0
  (validator-enforced by review-check/apply-check; cross-authorization chaining is
  RESERVED for M9 — the field is pinned, not dead weight; Rev 2/A4b). Refuses to
  overwrite an existing authorization (append-only artifact family; a re-dispatched task
  gets a NEW task id per the review schema's terminal-REJECT rule, so no legitimate flow
  needs an overwrite). Host-policy divergence disclosed: on installed hosts the
  `authorizations/` dir is not yet in the installer's HARNESS_DIRS/.gitignore local-only
  block (installer frozen for M7) — recorded as an M9/M10 follow-up carry-forward.
- **`apply-check --auth A --task T --result R --review REV [--scope-lock LOCK]`** — the
  P7-consumption gate. REFUSES if: any input missing/unparseable; `task_result_hash` or
  `review_hash` do not recompute; review `decision != apply`; `authorized_paths` ⊄
  `task.allowed_files`; or, when `--scope-lock` is given, any authorized path is not
  adjudicated writable by `bin/lib/dmc-scope-lock.py --adjudicate LOCK <path> edit`
  (read-only subprocess). A missing/absent authorization file IS the "apply without chain
  refused" acceptance behavior. Reason codes `WAUTH-*`.
- **`fidelity --result R --applied-diff D`** — post-apply fidelity, names+hunk-count tier
  (v1.0, architecture :284-285): parse `proposed_patch` and the applied diff with the SAME
  hardened parser; REFUSE unless path sets are equal and per-path `@@` hunk counts are
  equal (rename/copy/binary entries compared by kind, not content). Content equality is
  explicitly NOT claimed.
- **`--self-test`** — positives + every negative control named in the schema (:37-39) and
  in §Acceptance below.

### 4. `bin/lib/dmc-delegation.py` runtime records (T012.3 — P14 records)

Existing `validate` verb and its 29 selftest rows preserved byte-for-byte in behavior; two
new verbs:

- **`append --run RUN_ID RECORD.json`** — full `validate_delegation()` first (fail-closed);
  then chain-append to `.harness/runs/<RUN_ID>/delegations.jsonl`: the record's
  `prev_hash` must equal the sha256 of the previous record's exact line bytes EXCLUDING
  the terminating LF (the newline is the JSONL separator, never part of the hashed record
  — pinned so externally-authored records can compute it; Rev 2/A4a), or `genesis` when
  the file is absent/empty; the run directory must already exist (REFUSE otherwise —
  records bind to real runs). Additionally closes the module's documented M7 judgment call (:44-53): for
  `may_mutate: true` records, `scope_lock_ref` must resolve to an existing, parseable
  scope.lock whose `run_id` matches `--run` (content tier: existence + parse + run_id
  binding; deeper semantic equivalence stays a disclosed non-goal).
- **`check --run RUN_ID`** — re-validates every line, re-verifies the hash chain
  end-to-end, and enforces validate-before-consumption: any record carrying `artifact_ref`
  must have `validation_verdict == PASS` (schema rule, now enforced across the whole
  file), else REFUSE with the existing `DELEG-UNVALIDATED-CONSUMPTION` code.
- Self-test extended with append/check positive + negative rows (existing 29 stay green;
  new total pinned in the section output, expected ≥ 40).

### 5. `bin/dmc` registration (T012.4 — single owner)

- New lib var (`WORKERREVLIB`) + new top-level `worker)` case arm with nested
  `review-check|authorize|apply-check|fidelity` (mirrors the `verdict` arm shape);
  `delegation` arm extended to pass `append`/`check` through to the module.
- `M7SUITEDIR="$HERE/../tests/fixtures/m7"` + guarded `run_m7_suite()` (missing script ⇒
  rc=1, M8 precedent) looping `test-worker-adversarial.sh test-worker-chain.sh
  test-delegation-records.sh`.
- Selftest sections: `worker-check` (= `python3 "$WORKERREVLIB" --self-test`) and
  `m7-suite` registered in BOTH the `--all` block and the named-target block; the no-arg
  default 9 sections stay frozen (75/0). usage() heredoc gains the worker verbs, the two
  sections, and the delegation sub-verbs; the `bin/dmc:69-70` "runtime records pipeline is
  M7" help note is updated to name the shipped verbs.
- Skills wiring: `dmc-worker-import/SKILL.md` requires `dmc worker review-check` (record
  authored at review) after the hardened result-check; `dmc-worker-review/SKILL.md` step 4
  becomes: review record (v1) → `dmc worker authorize` → scope-guarded Edit/Write apply
  under the run → `git diff` capture → `dmc worker fidelity`; apply is FORBIDDEN without a
  PASSing `apply-check` (the machine gate replacing the prose-only `apply_run_id` link).
  Legacy prose reviews remain readable history; new applies require the v1 chain.
  HONEST ENFORCEMENT TIER (Rev 2/A5): the chain requirement at apply time is
  skill-mandated procedure — the `apply-check` CLI is invoked by the skill flow, and
  NOTHING in the Ring-0/1 hook path blocks an Edit/Write that is inside scope.lock but
  lacks an authorization; the runtime write floor remains scope-lock adjudication. The
  chain becomes BLOCKING at the M9 release gate (a run whose applied changes lack an
  import/delegation chain is refused — delegation.schema.md consumers note). This tier
  statement is an input to the M10 enforcement matrix; no stronger claim is made.

### 6. `tests/fixtures/m7/` suite (T012.5)

`_m7common.sh` (M6/M8 helper conventions: repo-root resolution, `record`/`assert_eq`,
porcelain before/after guard, mktemp sandbox + trap cleanup, never reads secret files,
never mutates the live repo, no network/live calls) + three scripts:

- **`test-worker-adversarial.sh`** — canonical (4): JWT-bearing result REJECT (labels
  only, value never echoed); Bearer/`authorization:`/`access_token` kv/`gh[osu]_`/`ya29.`
  rows; PLACEHOLDER positive control (`{"access_token": "<redacted>"}` docs ACCEPT);
  legacy 5-class regression rows. Canonical (5): pure rename-diff touching a forbidden
  file REJECT; copy-diff REJECT; binary-diff (`GIT binary patch` + `Binary files differ`)
  REJECT; c-quoted `diff --git` REJECT; non-empty-patch-zero-paths REJECT; benign rename
  within allowed_files ACCEPT (no over-blocking); space-bearing-path row (authoritative
  path sources parse it; over-reject acceptable, bypass impossible — Rev 2/A6).
  Empty-allowed REJECT (+ missing allowed_files REJECT + one-entry allowed ACCEPT
  control). task_id mismatch REJECT; provider cross-check rows (Rev 2/B1): non-mock
  type-mismatch REJECT, non-empty-provider mismatch REJECT, `type=="mock"` carve-out
  ACCEPT (mock task + foreign-provider result, the pinned v0.2.1 shape), V6-shape ACCEPT
  (empty task provider + matching type); required-field-absence REJECTs;
  malformed-JSON clean REJECT (no traceback); no `__pycache__` appears under
  `.claude/workers/providers/**` after any row (porcelain guard, Rev 2/A2);
  context-guard rows: malformed task ⇒ exit 1 FAIL-CLOSED, clean task ⇒ exit 0, secret
  path still blocked, JWT-in-bundle now blocked, `PATH` sabotage (python3 absent) ⇒
  fail-closed.
- **`test-worker-chain.sh`** — review-check: 4 schema negative controls (apply-with-FAIL,
  empty checks, missing mandatory kind, mutation-capable reviewer_role) + hash-mismatch
  REFUSE + clean review VALID; authorize: refuses on reject-decision/REJECTing-result/
  existing-authorization; apply-check: missing auth REFUSED ("apply without chain
  refused"), tampered task/result/review bytes REFUSED (hash recompute), path outside
  allowed REFUSED, path outside a compiled scope.lock REFUSED (arm a disposable mktemp
  repo through the real `dmc run start` path, M6 `arm_fixture` precedent), full clean
  chain PASS; fidelity: hunk-count mismatch REFUSED, path-set mismatch REFUSED, faithful
  apply PASS.
- **`test-delegation-records.sh`** — append genesis + chained second record PASS; bad
  prev_hash REFUSED; nonexistent run REFUSED; may_mutate-without-resolvable-scope-lock
  REFUSED; scope-lock run_id mismatch REFUSED; check over a clean file PASS; tampered
  middle line ⇒ check REFUSED; unvalidated-consumption REFUSED.

### 7. Manifest re-proof + evidence (T012.6)

- `bash .claude/install/dmc-install.sh --emit-manifest > INSTALL_MANIFEST.md` (regen-only;
  the new `bin/lib/dmc-worker-review.py` and `.harness/schemas/
  apply-authorization.schema.md` auto-appear in the sorted listings; the hook entries are
  name-only and unchanged) → commit → `bin/dmc selftest m8-suite` clean (126/0, incl.
  manifest-drift byte-equality re-proof).
- Evidence `.harness/evidence/dmc-v1-m7-build-20260707.md` + verification report
  `.harness/verification/dmc-v1-m7-worker-hardening.md` passing
  `dmc validate verification`.

## Acceptance Criteria

- Criterion: canonical class (4) — a worker result carrying a JWT-class token (and each of
  the six imported OAuth classes) is REJECTed by `worker-result-check.py`, value-blind;
  placeholder-shaped values are NOT flagged.
  Verification Method: `bash tests/fixtures/m7/test-worker-adversarial.sh` class-4 rows all
  PASS, exit 0.
- Criterion: canonical class (5) — rename/copy/binary/c-quoted/zero-path diffs touching
  forbidden or out-of-scope files are REJECTed; a benign in-scope rename is ACCEPTed.
  Verification Method: same script, class-5 rows all PASS, exit 0.
- Criterion: empty or missing `allowed_files` ⇒ REJECT (with ACCEPT positive control).
  Verification Method: same script, empty-allowed rows PASS, exit 0.
- Criterion: task_id cross-check (unconditional) and provider cross-checks (with the
  `type=="mock"` and empty-task-provider carve-outs, positive AND negative controls) and
  result required-field presence enforced; malformed JSON ⇒ clean REJECT;
  `worker-context-guard.sh` fail-closed on parse error, python3 absence, and
  token-material in the bundle.
  Verification Method: same script, cross-check/carve-out/fail-closed rows PASS, exit 0.
- Criterion: every legacy VAL caller's pinned expectation survives the hardened validator
  (v0.2-verify mock-001 ACCEPT; v0.2.1/v0.2.1.1 glm-vs-mock-001 ACCEPT rows; v0.2.3 V6
  empty-provider ACCEPT; v0.2.2/v0.2.4/v0.3.1/v0.3.3 matching-pair rows; all REJECT rows
  still REJECT).
  Verification Method: the legacy aggregate 802/3/3 EXACT criterion below (these rows are
  inside it), plus `bin/dmc legacy v0.2.1-verify` and `v0.2.3-verify` run individually
  during build (0 FAIL each).
- Criterion: `dmc worker review-check` REFUSES all four schema negative controls and
  hash-mismatched records; validates a clean record.
  Verification Method: `bash tests/fixtures/m7/test-worker-chain.sh` review rows PASS,
  exit 0; `python3 bin/lib/dmc-worker-review.py --self-test` 0 FAIL.
- Criterion: apply WITHOUT a chain is refused — `apply-check` REFUSES on missing
  authorization, tampered bytes (hash recompute), out-of-allowed paths, out-of-scope.lock
  paths; a clean task→result→review→authorize chain PASSes.
  Verification Method: same script, chain rows PASS, exit 0.
- Criterion: post-apply fidelity at names+hunk-count tier — mismatches REFUSED, faithful
  apply PASSes.
  Verification Method: same script, fidelity rows PASS, exit 0.
- Criterion: delegation runtime records — chained append/check with all negative controls
  (bad prev_hash, tampered line, nonexistent run, unresolvable/mismatched scope_lock_ref,
  unvalidated consumption) REFUSED; clean chains PASS; existing `delegation` section rows
  remain green.
  Verification Method: `bash tests/fixtures/m7/test-delegation-records.sh` exit 0;
  `bin/dmc selftest delegation` 0 FAIL.
- Criterion: v0.3.3 three-provider contract suite green UNCHANGED — 34 PASS / 0 FAIL /
  2 N/A at the pinned rejection stages, on the committed tree.
  Verification Method: `bin/dmc legacy v0.3.3-verify` on the committed replica, counts
  EXACT vs `.harness/evidence/dmc-v1-m3-baseline.md` row.
- Criterion: legacy aggregate EXACT — 49 tools / 802 PASS / 3 FAIL / 3 N/A; all selftest
  sections 0 FAIL including NEW `worker-check` + `m7-suite`; fast default stays 75/0;
  mirror-check green (55-file set unchanged — the new module is not a legacy copy);
  linkcheck green with the new `worker` verb.
  Verification Method: `bin/dmc selftest --all` exit 0 on a committed replica, then
  live post-commit re-run (closure condition).
- Criterion: INSTALL_MANIFEST re-proven — regenerated manifest committed; drift re-run
  clean; installer/uninstaller/doctor code byte-unchanged.
  Verification Method: `bin/dmc selftest m8-suite` 126/0; `git diff --name-only` over
  `.claude/install/ bin/lib/dmc-doctor.py` empty.
- Criterion: rollback — a single `git revert` of the M7 commit restores both validators to
  their pre-M7 bytes and removes the additions; the retained pre-M7 fixture equals the
  pre-M7 live bytes.
  Verification Method: scratch-worktree revert (M6 closure-proof-2 pattern) + `cmp`
  live-pre-revert vs `tests/fixtures/hooks-v0.6.5/hooks/*` recorded in evidence (fixture
  == pre-M7 bytes verified pre-edit in this plan).
- Criterion: suites leave the real repo byte-untouched.
  Verification Method: `git status --porcelain` identical before/after each suite (helper
  assert in `_m7common.sh`).

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Broadened `authorization:`/Bearer patterns over-match prose in legitimate results | medium | EXACT import of the oauth-cli patterns + PLACEHOLDER exclusion (accepted fail-closed trade-off, v0.2.2 plan §3 precedent); build verifies every v0.3.3 success fixture + mock-001 still ACCEPT before commit |
| empty-allowed DENY breaks previously-legal analysis-only tasks | low | Breaking change recorded for M10 release notes (master risk L164); v0.3.3 synthesized tasks verified non-empty (`dmc-v0.3.3-verify.sh:36`) |
| Detector-source import fails on a host (moved/partial install) | low | Installer ships providers on every install (manifest COPY section); failure mode is REJECT (fail-closed availability hit, never a bypass) |
| v0.3.3 pinned stages/counts drift from validator changes | medium | C9 requires commit-first; committed-replica `--all` run before the commit is finalized (carry-forward #7); pinned row asserted EXACT |
| `DISALLOWED`/`diff_paths` API break for manual-import's dynamic import | low | BOTH pinned as explicit T012.1 constraints (diff_paths byte-identical; hardened parse in new `diff_entries`); v0.3.3 exercises the manual-import path |
| Provider carve-outs read as weakening | — | Carve-outs gate provider-identity consistency ONLY (provenance tier, worker-supplied metadata); token/scope/category/diff/field floors unconditional; negative controls prove non-mock mismatches REJECT |
| importlib load writes `__pycache__` into providers tree | low | `sys.dont_write_bytecode = True` mandated at every import site (manual-import :31-33 precedent); suites' porcelain guard is the negative control |
| Working-tree-drift legacy FAILs during build (v0.2.1 byte-pin, v0.5.9/v0.6.0) | expected | Carry-forward #7: committed-replica proof + post-commit live re-run |
| New verb/section registration conflicts | low | T012.4 is the SOLE bin/dmc owner (M3–M8 single-owner rule) |
| Hash chains read as authentication | — | Disclosed: provenance-not-authentication tier, same as run.json/scope-lock chains (M4 honest-scope note) |
| tests/fixtures/m6/test-rollback.sh live-vs-fixture rows change | expected | Script is not in any suite loop (M6 closure note: in-place 25/5 by design); no refresh — documented in evidence |

## Assumptions

- The worker validators stay skill-wired (not settings-registered) — no session reload is
  needed for M7 (`dmc doctor` and `.claude/settings.json` unchanged).
- `.harness/workers/reviews/` remains the home of v1 review records
  (`<task_id>.json`); authorizations land in the new sibling `authorizations/`.
- `bin/lib/dmc-roles.py lookup` and `bin/lib/dmc-scope-lock.py --adjudicate` remain
  stable read-only oracles for the new CLIs (M5/M6 shipped surfaces).
- Orchestrator/worker split per handoff: Fable 5 directs; Opus 4.8 implements the
  protected/security-critical tasks (T012.1, T012.2, T012.5), Sonnet 5 the mechanical ones
  (T012.3, T012.4, T012.6); all subagents `auto` permission mode; Ring-0 guards enforce
  independently.
- Codex-side behavior of the shipped validators stays ADVISORY under Option A; nothing in
  M7 claims otherwise.

## Execution Tasks

- [ ] DMC-T012.1: Harden `worker-result-check.py` (imported token classes, extended
  fail-closed diff parsing, empty-allowed DENY, task/provider cross-checks, required-field
  floor, clean-REJECT input handling, `DISALLOWED` API preserved) and make
  `worker-context-guard.sh` fail-closed (parse/interpreter/import failures) with the same
  imported token classes.
  Files: .claude/hooks/worker-result-check.py, .claude/hooks/worker-context-guard.sh.
  Notes: SOLE owner of the protected surface; every v0.3.3 success fixture + mock-001 must
  still ACCEPT locally before handoff. No blockedBy.
- [ ] DMC-T012.2: New `bin/lib/dmc-worker-review.py` (review-check / authorize /
  apply-check / fidelity + --self-test) + `.harness/schemas/apply-authorization.schema.md`
  + `.harness/workers/authorizations/.gitkeep`.
  Files: bin/lib/dmc-worker-review.py, .harness/schemas/apply-authorization.schema.md,
  .harness/workers/authorizations/.gitkeep.
  Notes: SOLE owner; implements the committed worker-review.schema.md contract verbatim.
  No blockedBy.
- [ ] DMC-T012.3: `dmc-delegation.py` append/check runtime-records verbs + scope_lock_ref
  content tier + extended self-test (existing 29 rows preserved).
  Files: bin/lib/dmc-delegation.py.
  Notes: SOLE owner. No blockedBy.
- [ ] DMC-T012.4: bin/dmc registration (worker verb arm, delegation pass-through,
  M7SUITEDIR + run_m7_suite, worker-check + m7-suite sections in --all + named blocks,
  usage()) + skills wiring (dmc-worker-review, dmc-worker-import).
  Files: bin/dmc, .claude/skills/dmc-worker-review/SKILL.md,
  .claude/skills/dmc-worker-import/SKILL.md.
  Notes: SOLE bin/dmc owner. blockedBy T012.1, T012.2, T012.3 (registers their surfaces).
- [ ] DMC-T012.5: `tests/fixtures/m7/` suite (_m7common.sh, test-worker-adversarial.sh,
  test-worker-chain.sh, test-delegation-records.sh) per §Proposed Changes 6.
  Files: tests/fixtures/m7/**.
  Notes: SOLE owner; porcelain-untouched guard mandatory. blockedBy T012.1–.4.
- [ ] DMC-T012.6: INSTALL_MANIFEST regen + m8-suite drift re-run + committed-replica
  `selftest --all` proof + evidence `.harness/evidence/dmc-v1-m7-build-20260707.md` +
  verification report `.harness/verification/dmc-v1-m7-worker-hardening.md` (must pass
  `dmc validate verification`).
  Files: INSTALL_MANIFEST.md, .harness/evidence/dmc-v1-m7-*.md,
  .harness/verification/dmc-v1-m7-worker-hardening.md.
  Notes: blockedBy T012.1–.5.

## Verification Commands

| Command | Reason | Required |
|---|---|---|
| bash -n .claude/hooks/worker-context-guard.sh tests/fixtures/m7/*.sh | shell syntax floor | yes |
| python3 -m py_compile .claude/hooks/worker-result-check.py bin/lib/dmc-worker-review.py bin/lib/dmc-delegation.py | python syntax floor | yes |
| bin/dmc selftest | fast default unchanged (9 sections, 75/0) | yes |
| bin/dmc selftest --all | legacy 802/3/3 EXACT + every section 0 FAIL (incl. worker-check, m7-suite) — committed replica, then post-commit live | yes |
| bin/dmc legacy v0.3.3-verify | pinned 34/0/2, stages unchanged | yes |
| bin/dmc selftest worker-check · bin/dmc selftest m7-suite | new sections directly | yes |
| bin/dmc selftest m8-suite | manifest drift re-proof (126/0) post-regen | yes |
| bash .claude/install/dmc-install.sh --emit-manifest \| cmp - INSTALL_MANIFEST.md | regen byte-equality | yes |
| cmp tests/fixtures/hooks-v0.6.5/hooks/worker-result-check.py .claude/hooks/worker-result-check.py (pre-edit) → recorded; scratch-worktree revert proof (post-commit) | rollback evidence | yes |
| bin/dmc linkcheck · bin/dmc mirror-check | verb refs resolve; 55-file mirror intact | yes |
| bin/dmc validate plan .harness/plans/dmc-v1-m7-worker-hardening.md · dmc validate verification .harness/verification/dmc-v1-m7-worker-hardening.md | instance validity | yes |
| git status --porcelain before/after each suite · git diff --name-only vs this plan's allowlist | repo hygiene + scope conformance | yes |

## Approval Status

Status: APPROVED
Approver: wjlee (human release gate; granted via AskUserQuestion in the 2026-07-07
session, option "승인 (권장)", after the critic chain r1 REJECT (B1 legacy-baseline
compatibility · B2 diff_paths import surface; bound plan_hash `6081ab7b…7206`) → Rev 2 →
r2 APPROVE bound to the frozen pre-approval bytes sha256
`dd3a19939c47af9a179eaed4da5567679ccc5d2e5652f0a6b6bfeb788834141f` — verdicts persisted at
`.harness/evidence/dmc-v1-m7-critic-verdict-r{1,2}.json`; r2 is the binding artifact;
`dmc verdict validate` VALID ×2 and `dmc verdict gate --plan-hash dd3a1993…` PASS
pre-gate)
Approved At: 2026-07-07

Approval record (verbatim scope of the human gate, 2026-07-07):
- **Approved**: DMC-T012.1 – DMC-T012.6 exactly as specified in §Execution Tasks,
  including the PROTECTED-SURFACE edits to `.claude/hooks/worker-result-check.py` and
  `.claude/hooks/worker-context-guard.sh` (master §M7 authorization), the new
  `bin/lib/dmc-worker-review.py` + `.harness/schemas/apply-authorization.schema.md` +
  `.harness/workers/authorizations/`, the `dmc-delegation.py` runtime-records verbs, the
  bin/dmc registration + worker-skill wiring, the `tests/fixtures/m7/` suite, and the
  INSTALL_MANIFEST regen.
- **Advisory disposition (r2 advisories, recorded at the gate)**:
  A1 — task_id path-safety at `authorize` (refuse path separators and `..` components in
  the derived output path; negative fixture row) = **MANDATORY implementation directive**;
  A2 — exception-wrapped oauth-detector importlib load (CLI path ⇒ clean REJECT exit 1;
  manual-import `_load` keeps dying fail-closed exit 2; C7 byte-determinism of
  manual-import preserved) = **MANDATORY implementation directive**;
  A3 — add `bin/dmc legacy v0.2.1.1-verify` to the individually-run-during-build list =
  build directive;
  A4 — result_id non-uniqueness disclosure line in the NEW apply-authorization schema
  (uniqueness rests on task_result_hash) = accepted.
- **Gate-scope note (Rev 2/A7)**: the `.claude/skills/*/SKILL.md` master row is
  milestone-tagged M5 and `.harness/workers/authorizations/` has no master row — both
  edits are authorized by THIS gate (M6.5/M8 precedent).
- **Explicitly NOT approved**: staging, commit, push (separate human gates); edits to any
  frozen surface (M6 hooks + settings.json, `.claude/workers/providers/**`,
  installer/uninstaller/doctor code, root WORKER_* schemas, worker-review.schema.md,
  other milestones' fixtures); any live provider call.
- Hash note (carry-forward #9): appending this record changes the plan file's hash by
  design — the r2 verdict binds the pre-approval bytes `dd3a1993…7206`, this record cites
  that hash, and run.json will bind the post-append bytes.
