# adapters/claude-code — Ring-1 hook shim layout (M6)

The Claude Code adapter for Do-Me-Coding is the set of PreToolUse / PostToolUse / Stop hooks under
`.claude/hooks/`. As of M6 (hook hardening) these hooks are **thin Ring-1 shims**: they parse the
host tool JSON, ask a Ring-0 verdict CLI, and translate the verdict into the Claude Code
deny / ask / allow envelope. The enforcement logic lives in Ring-0 (`bin/lib/*.py`, driven through
`bin/dmc`) so a second adapter (e.g. the M6.5 Codex shims) can reuse the identical verdicts.

## Enforcement layering

- **L0 — static deny floor.** Catastrophic commands, secret-bearing paths, and `git apply` / `patch`
  application forms are denied **inline in every mode** (active / passive / off), with no run and no
  Ring-0 lookup required. L0 still fires under a synthetic `CLAUDE_PROJECT_DIR` that has no `bin/dmc`.
- **L1 — dynamic run-scoped verdicts.** The Bash write-radius, post-Bash out-of-scope diff, scope-lock
  edit adjudication, and stop-completion coverage arm **only while a run is armed** — defined as
  `current-run-id` present **and** that run dir carrying an immutable `scope.lock.json`. Unarmed
  (the repo's normal state, and this M6 build's own legacy run) ⇒ L1 stands down. In active mode a
  missing interpreter / `bin/dmc` while armed is **fail-closed** (deny / hold with an actionable reason);
  passive and off never brick a session (OMC coexistence).

## Hook ↔ Ring-0 CLI map

| Hook (`.claude/hooks/`) | Event | Ring-0 CLI it calls (when armed) |
|---|---|---|
| `pre-tool-guard.sh` | PreToolUse: Bash | `dmc bash-radius --cmd … --scope-lock …` (0 allow / 3 ask / 4 deny) |
| `scope-guard.sh` | PreToolUse: Edit\|Write | `bin/lib/dmc-scope-lock.py --adjudicate LOCK PATH edit` (armed) / legacy `current-scope.txt` |
| `secret-guard.sh` | PreToolUse: Read\|Grep\|Glob | inline path/glob detectors, superset keys, case-insensitive (no Ring-0 call) |
| `stop-verify-gate.sh` | Stop | `dmc stop-gate quick --root … [--report …]` (0 pass / 4 hold) |
| `evidence-log.sh` | PostToolUse: Bash\|Edit\|Write | `dmc postbash-diff …` ⇒ on out-of-scope, `dmc run block …` |

## Why the shims are self-contained (no shared `common.sh` sourced here)

Each hook fires on every tool call of the live session, including under synthetic-`CLAUDE_PROJECT_DIR`
test harnesses. A shared sourced library would add a resolve-and-source failure mode that could brick
the enforcement surface. The shims therefore keep their (small, duplicated) `json_get` / `json_string`
/ mode-detection / `bin/dmc` resolution inline — matching the pre-M6 house style — and this directory
stays a documentation stub rather than a code dependency of the hooks.
