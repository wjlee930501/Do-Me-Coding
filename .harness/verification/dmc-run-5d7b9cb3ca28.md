# Verification Report

## Run ID

dmc-run-5d7b9cb3ca28

## Plan

.harness/plans/dmc-fable-core-codex-bypass.md (plan_hash 2c9fff0b4a85fe89dee731b3dce62219d080cff9fde7f4fd364207da0a63d273 — independently recomputed on-disk via `shasum -a 256`, byte-equal to run.json plan_hash == scope.lock plan_hash == critic r2 plan_hash). Critic gate: .harness/evidence/dmc-fable-core-codex-bypass-critic-r2.json — schema dmc.critic-verdict.v1, verdict APPROVE, blockers [], context_provenance fresh, lenses correctness/scope/security, plan_hash binds THIS file. compiled_at_head 497ca4b71bc71f39916841e595eb1f95a6e7ece7 == HEAD == branch claude/dmc-fable-core. run.json operative_snapshot.scope_lock_sha256 43f8d741a801a7da41c35e395a886192f4c04b8e0cf4fe60003c1057e9fd349b == on-disk scope.lock.json sha256 (independently recomputed). repo_hash ece5c522…: scope.lock == run.json (consistent); critic repo_hash 497ca4b71bc… == compiled_at_head == HEAD (commit-sha field, consistent).

## Changed Files

- adapters/codex/dmc-codex-pretooluse.py (+7/0): M2 — in `handle_bash`, inside the existing `if verdict == "ask":` branch (reached only AFTER the deny floors returned), 5 comment lines + 2 executable lines: `if dc.permission_mode(data) == "bypassPermissions": dc.pretool_standdown(project_dir, dc.ask_class(command))`, followed by the unchanged `dc.pretool_ask(reason)`. No other branch touched.
- adapters/codex/dmc_codex_common.py (+61/0): M1 — `import time` (stdlib); `PERMISSION_MODE_KEYS = ("permission_mode","permissionMode")` with snake=documented-parity / camel=defensive comment; `permission_mode(data)` = top-level `_ci_get` read; `_ASK_CLASS_RULES` + `ask_class(command)` (publish>audit-force>schema-push>migrate>install); `pretool_standdown(project_dir, cls)` (best-effort value-blind log + byte-identical systemMessage + exit 0).
- tests/fixtures/m6.5/test-codex-shims.sh (+132/0): NEW section F (F1–F8 + F-PAR1/2/3 = 18 assertions; 143→161).
- docs/MILESTONES.md (+77/0): append-only `## v1.1.5` entry (last heading; records descriptive 143→161, "legacy 802/3/3 UNCHANGED", push/CI/main-FF human gate).

Total in-scope +277/0 (7+61+77+132). `.codex/config.toml` (M, unstaged, +4/0) and untracked .harness governance artifacts are pre-existing exempt dirt — no other tracked path changed.

## Commands Run

| Command | Result | Reason | Output Summary |
|---|---|---|---|
| shasum -a 256 plan; compare to run.json/scope.lock/critic r2 | PASS | binding chain | all four == 2c9fff0b…; compiled_at_head 497ca4b == HEAD |
| shasum -a 256 scope.lock.json vs run.json operative_snapshot | PASS | operative snapshot | 43f8d741… == scope_lock_sha256 |
| git diff --numstat (4 in-scope paths) | PASS | scope + bounds | 7/0 + 61/0 + 77/0 + 132/0 = 277/0; within 300/30/4 |
| git diff --numstat (all tracked) | PASS | no stray edits | only the 4 in-scope + exempt .codex/config.toml |
| bash tests/fixtures/m6.5/test-codex-shims.sh | PASS | section F + D-block + porcelain guard | 161 PASS / 0 FAIL, exit 0 |
| bin/dmc selftest m65-suite | PASS | blocking CI path | codex-shims 161/0 · skills-mirror 19/0 · agents-md 35/0 · agents-md-drift 9/0 — every RESULT 0 FAIL, exit 0 |
| grep -n bypassPermissions adapters/codex/*.py | PASS | AC2 no deny-path ref | common.py:56 (keys comment), :483 (standdown docstring), :498 (standdown systemMessage); pretooluse.py:52 (ask-branch comment), :55 (ask-branch compare) — all ask-path/standdown, NONE in a _FLOORS deny entry |
| bin/dmc agents-md --root . --stdout \| diff - AGENTS.md | PASS | AC5 neutrality | EMPTY (exit 0) |
| bash .claude/install/dmc-install.sh --emit-manifest \| diff - INSTALL_MANIFEST.md | PASS | AC5 neutrality | EMPTY (exit 0) |
| git status --porcelain (pre + post battery) | PASS | hermetic | byte-identical before/after; suites left the repo untouched |
| committed-replica + isolated-live bin/dmc selftest --all == 802/3/3 | PENDING | AC6 baseline | NOT run in this lane — live tree carries the uncommitted candidate (dirty-tree misread). Structurally untouched: the 4 edited files are not dmc-v0.* legacy tools (PINNED_BASELINE counts only those). Deferred to orchestrator post-commit. |
| bin/dmc gate release --full --run-id dmc-run-5d7b9cb3ca28 | PENDING | AC7 gate | PENDING-POST-STAGING; expect PASS with non-degrading FLAG on the 2 enforcement .py landmarks, NO G4 override (adapters/codex absent from DEFAULT_PROTECTED). |

## Manual Checks

| Check | Result | Notes |
|---|---|---|
| scope.lock files[] == exactly 4 paths | PASS | pretooluse.py + common.py (enforcement, landmark_authorized:true), MILESTONES.md (release), test-codex-shims.sh (ordinary) |
| bypass branch sits ONLY at verdict=="ask", after deny floors | PASS | pretool_deny() sys.exit(0) precedes the ask branch; _FLOORS has exactly ONE "ask" entry (Block C, scope active) — every other floor is "deny", so "ask" uniquely identifies Block C |
| permission_mode() top-level, exact-literal, inert-if-absent | PASS | `_ci_get(data, KEYS)` reads top-level only (no tool_input fallback, unlike get_field), returns str(v) unchanged, "" when absent ⇒ `== "bypassPermissions"` false ⇒ falls through to pretool_ask |
| ask_class precedence == pre-tool-guard.sh:140-145 | PASS | tuple order publish>audit-force>schema-push>migrate, first-match, else install; regexes mirror :141-144 (`\s+`≡`[[:space:]]+`, IGNORECASE); over `_oneline` (whitespace-collapse) |
| systemMessage byte-identical to pre-tool-guard.sh:156-157 | PASS | "DMC advisory: ask-tier stood down under bypassPermissions (class: %s); deny floors remain active." — string byte-equal (F-PAR1 extracted-string byte-compare also PASS) |
| log line shape == :155, value-blind, best-effort | PASS | "%s ask-tier-standdown class=%s\n" via time.strftime UTC == `date -u +%Y-%m-%dT%H:%M:%SZ`; no command text; makedirs/open/write in try/except: pass; _emit + exit(0) outside try ⇒ always exit 0 |
| PERMISSION_MODE_KEYS comment marks snake=documented / camel=defensive | PASS | common.py:53-58 comment, enum default|acceptEdits|plan|dontAsk|bypassPermissions |
| F4/F5 deny-under-bypass semantics | PASS | git push --force ⇒ Block A deny; cat .env ⇒ secret floor deny — both classify_bash_floors "deny" and exit before the ask branch |
| F7 fresh passive sandbox, no log file | PASS | new_dir passive; asserts rc0, no ask, no systemMessage, `[ ! -f log ]` — bypass never consulted (mode composition) |
| F8 value-blind | PASS | fake sk-FAKE0000NOTAREALKEY in command; asserts STANDDOWN_RE match AND `! grep -q token log` |
| F-PAR1 one shared extractor, cross-adapter byte-compare | PASS | single f_sysmsg_of over BOTH claude_run pre-tool-guard.sh and codex_run; assert_eq extracted strings; both log lines match `^[0-9TZ:-]+ ask-tier-standdown class=install$`; parity rows build snake `permission_mode` at top level |
| MILESTONES v1.1.5 append-only + well-formed | PASS | line 1104 last heading; +77/0 (no deletions); records 143→161 descriptive + 802/3/3 UNCHANGED + human gate |
| import delta | PASS | only `+import time` (stdlib) — no third-party dependency |

## Scope Review

Result: PASS

Notes: Tracked diff is a strict subset of the scope.lock — the 4 in-scope paths exact-match, no extras. Bounds honored (4 files / 277 added / 0 deleted vs 4 / 300 / 30). The two adapters/codex/*.py rows are landmark_authorized:true (enforcement class) → a non-degrading landmark FLAG is expected at the release gate; docs/MILESTONES.md is release class (grant edit, append-only); tests/fixtures/m6.5/test-codex-shims.sh is ordinary. adapters/codex is absent from DEFAULT_PROTECTED, so NO DMC_GATE_PROTECTED / G4 override is needed (matches Finding F8). Staging status: the 4 files are currently UNSTAGED (` M`) — expected pre-commit; the G2 "all staged" obligation is the orchestrator's staging-time step, not yet performed. Untracked .harness/{evidence,plans} and the modified-but-unstaged .codex/config.toml are governance/exempt and outside the diff-scope tier.

## Package / Env / Migration Review

Package files changed: no
Env files changed: no
Migration files changed: no

Notes: Adapter-mirror + fixture + docs cycle. The only import added is Python stdlib `import time`; no dependency manifest (requirements/pyproject/package.json), env var, database migration, or config file is in scope. `.codex/config.toml` is modified but UNSTAGED and is pre-existing exempt dirt, not part of this cycle. No secret-bearing file was read, grepped, or referenced by content; the stand-down log line is value-blind (class + UTC only, proven by F8).

## Unresolved Risks

- Two required post-staging deterministic gates remain PENDING by design (orchestrator lane, not this read-only verifier's remit): (1) committed-replica + isolated-live `bin/dmc selftest --all` == tools=49 PASS=802 FAIL=3 N/A=3 EXACT — deliberately NOT run here because the live tree carries the uncommitted candidate (V15 dirty-tree misread); structurally untouched since the 4 edited files are not dmc-v0.* legacy tools. (2) `bin/dmc gate release --full --run-id dmc-run-5d7b9cb3ca28` — PENDING-POST-STAGING; expected PASS with a non-degrading FLAG on the 2 enforcement .py landmarks and NO G4 override. These are the sole reason for the PARTIAL; both are expected to pass.
- Staging incomplete: the 4 in-scope files are unstaged (pre-commit). The G2 all-staged obligation is the orchestrator's staging step.
- Push / CI / main-FF remain a human gate (autonomy caps at the LOCAL commit on claude/dmc-fable-core).
- Live Codex `permission_mode` delivery is turn-free-unprovable (Option-A ADVISORY posture); inert-if-absent by design — not a verification failure.

## Final Status

PARTIAL

Every check within the independent verifier remit PASSED with zero defects: binding chain (plan/run/lock/critic hashes all bind, compiled_at_head == HEAD), diff scope (exactly the 4 in-scope files, +277/0, within bounds), code review (bypass sits only at the ask verdict after deny floors; top-level exact-literal read; ask_class precedence, systemMessage, and log line byte-faithful to pre-tool-guard.sh; value-blind best-effort log), full test battery (test-codex-shims 161/0, m65-suite all four RESULT lines 0 FAIL, grep confirms the token never touches a deny path, both neutrality diffs EMPTY, porcelain hermetic), section-F semantics (deny-under-bypass, no-log-in-passive, value-blind, single-extractor cross-adapter byte-parity), and derived-artifact neutrality. The verdict is PARTIAL — not PASS — solely because two required deterministic gates (the `--all` 802/3/3 committed-replica/isolated-live baseline and `gate release --full`) are by-design deferred to the post-staging orchestrator lane and were not executed in this read-only lane; per the "no verification, no done" rule I do not mark PASS while required checks remain unrun. No defect, scope violation, deny-floor weakening, secret exposure, or baseline drift was found. Recommended path: stage the 4 files → LOCAL commit → run the two deferred gates (expected PASS) → then the run is DONE-eligible; push/CI/main-FF remain the human gate.
