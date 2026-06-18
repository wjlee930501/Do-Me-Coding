# Fix Shared Hook JSON Parsing Helper

## Goal

Repair the `json_get` helper that is duplicated, byte-identical, in all four
Do-Me-Coding Claude Code hooks so that it actually extracts fields from the hook
payload when `python3` is the available parser. Today the python3 branch returns
an empty string for every key, which silently disables all four hooks
(destructive-command guard, file-scope lock, stop/verify gate, evidence logging)
on any machine where `python3` is present. After the fix, all four hooks must
enforce their intended behavior, verified by dynamic behavioral tests — not just
`bash -n`.

## User Intent

bugfix

## Current Repo Findings

- Finding: `json_get()` is identical across all four hooks (md5 `0decaa1caf7c30feece34c2ff5c1a478` for the `json_get(){…}` block in each).
  Source: `for f in .claude/hooks/*.sh; do awk '/json_get\(\)/,/^}/' "$f" | md5; done`
- Finding: The python3 branch is `printf '%s' "$INPUT" | python3 - "$key" <<'PY' … PY`. `python3 -` reads its program from stdin, and the `<<'PY'` heredoc is the last stdin redirection, so it overrides the pipe. `json.load(sys.stdin)` then reads the already-consumed heredoc (EOF) → exception → prints nothing.
  Source: `.claude/hooks/*.sh` lines 5-28; reproduction below.
- Finding: Direct reproduction — python3 branch returns empty, jq branch returns the value:
  `python3 branch result: []` vs `jq branch result: [rm -rf /]`.
  Source: faithful `json_get` repro harness over `{"tool_input":{"command":"rm -rf /"}}`.
- Finding: Because `python3` is present here (`/opt/homebrew/bin/python3`), every hook takes the broken branch. Observed effects (synthetic-payload tests):
  - `pre-tool-guard.sh`: `rm -rf /`, `git reset --hard`, `cat .env`, `DROP DATABASE x`, `npm install` → 0 bytes output each (never deny/ask).
  - `scope-guard.sh`: out-of-scope Write with active scope `src/` → 0 bytes (never denies); it exits early at line 45 because `TOOL_NAME` is empty.
  - `stop-verify-gate.sh`: completion claim + active run + no verification file → 0 bytes (never blocks); empty `LAST_MESSAGE` fails the grep at line 55.
  - `evidence-log.sh`: writes the file header but the `## Tool Events` body stays empty because `TOOL_NAME` is empty → the `case` matches nothing (root cause of the previously observed empty-body evidence files).
  Source: dynamic hook tests in temp `CLAUDE_PROJECT_DIR` dirs.
- Finding: `json_string()` (line 32) already uses the correct `python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'` pattern (program from `-c`, data from the pipe) and works correctly. It is NOT part of this defect.
  Source: `grep -n 'python3 -c' .claude/hooks/*.sh`; repro `printf 'a"b' | python3 -c …` → `"a\"b"`.
- Finding: `scope-guard.sh` line 57 `python3 - "$PROJECT_DIR" "$FILE_PATH" "$SCOPE_FILE" <<'PY'` reads its inputs from `argv` (not stdin JSON), so its heredoc-as-program is correct. It MUST NOT be changed.
  Source: `.claude/hooks/scope-guard.sh` lines 57-98.
- Finding: Required tooling present: `bash`, `python3`, `jq`, `git`. `shellcheck` is absent.
  Source: `command -v` probe.

## Relevant Files

| Path | Reason | Allowed to Edit |
|---|---|---|
| `.claude/hooks/pre-tool-guard.sh` | Contains the broken `json_get`; patch its python3 branch | yes |
| `.claude/hooks/scope-guard.sh` | Contains the broken `json_get` (top); patch python3 branch ONLY — do not touch the line-57 argv-based block | yes |
| `.claude/hooks/stop-verify-gate.sh` | Contains the broken `json_get`; patch its python3 branch | yes |
| `.claude/hooks/evidence-log.sh` | Contains the broken `json_get`; patch its python3 branch | yes |
| `.claude/settings.json` | Read-only: confirms which hooks are wired; no change | no |
| `.harness/runs/` | Temp behavioral tests use throwaway dirs, never the real scope/run files | no |
| `.harness/evidence/` | Verification evidence output | yes |
| `.harness/verification/` | Verification report output | yes |

## Out of Scope

- Changing `json_string()` — it already works.
- Changing the `scope-guard.sh` argv-based python block at line 57.
- Altering any hook's enforcement logic, regexes, allow-lists, or thresholds — only the JSON-extraction mechanism changes; observable gate decisions must stay the same once inputs are parsed.
- Refactoring the four duplicated helpers into a single sourced library (considered; rejected as out-of-scope structural change — see Risks). The patch keeps four identical copies.
- Editing skills, agents, schemas, docs, `settings.json`, or any product/scaffold file other than the four hooks.
- Installing tooling (e.g. `shellcheck`).
- Touching `.before-dmc` backups, the scaffold zip, or `.omc/` runtime state.

## Proposed Changes

- Change: In each of the four hooks, replace the broken `json_get` python3 branch so the payload reaches `json.loads` via an environment variable (keeping the readable multi-line heredoc program on stdin). The jq fallback stays unchanged.
  Files: `.claude/hooks/pre-tool-guard.sh`, `.claude/hooks/scope-guard.sh`, `.claude/hooks/stop-verify-gate.sh`, `.claude/hooks/evidence-log.sh`
  Rationale: Frees stdin for the heredoc program while still delivering `$INPUT` to Python. Minimal, identical edit; preserves readability and the existing python3-first ordering.

  Exact target replacement (applied identically in all four files):

  Before:
  ```bash
      printf '%s' "$INPUT" | python3 - "$key" <<'PY' 2>/dev/null || true
  import json, sys
  key = sys.argv[1]
  try:
      data = json.load(sys.stdin)
      cur = data
  ```
  After:
  ```bash
      DMC_HOOK_INPUT="$INPUT" python3 - "$key" <<'PY' 2>/dev/null || true
  import json, os, sys
  key = sys.argv[1]
  try:
      data = json.loads(os.environ.get("DMC_HOOK_INPUT", ""))
      cur = data
  ```
  (Only these lines change inside `json_get`; the `for part…`, `print`, `except`, and `PY` lines stay byte-identical. The `elif jq` branch is untouched.)

  Heredoc fidelity note (MANDATORY for the executor):
  - In the real hook files the heredoc body (`import …` through `except:`/`pass`) sits at **column 0** — these are regular `<<'PY'` heredocs, not `<<-` indented heredocs. The Before/After examples above are shown indented only for readability inside this Markdown plan.
  - Do NOT copy the visually indented plan examples literally. Edit the real files in place and preserve their existing column-0 indentation exactly. Adding leading whitespace to the heredoc body would change the program text the shell feeds to Python and can break it.
  - The ONLY intended line-level changes inside `json_get` are:
    a) command prefix: `printf '%s' "$INPUT" | python3 - "$key" <<'PY' …` → `DMC_HOOK_INPUT="$INPUT" python3 - "$key" <<'PY' …` (replace the piped-JSON-into-python-heredoc form with the env-var-JSON form).
    b) import line: `import json, sys` → `import json, os, sys` (add `os`).
    c) JSON load line: `data = json.load(sys.stdin)` → `data = json.loads(os.environ.get("DMC_HOOK_INPUT", ""))` (read JSON from the env var).
  - Everything else inside the helper — including the `for part`, `if cur is None`, `if isinstance(...)`, `print(...)`, `except Exception:`, `pass`, the `PY` terminator, and the `elif command -v jq` branch — must remain byte-identical.

- Change: No new files, no removed files, no logic/threshold changes.
  Files: none
  Rationale: Surgical fix per the defect.

- Change: Rollback path for the four hook edits.
  Files: `.claude/hooks/pre-tool-guard.sh`, `.claude/hooks/scope-guard.sh`, `.claude/hooks/stop-verify-gate.sh`, `.claude/hooks/evidence-log.sh`
  Rationale: The four hooks are currently clean in `git status`, so the edits are fully reversible from the index. To revert, run (only **before** the change is committed):
  ```bash
  git restore .claude/hooks/pre-tool-guard.sh .claude/hooks/scope-guard.sh .claude/hooks/stop-verify-gate.sh .claude/hooks/evidence-log.sh
  ```
  If the change has already been committed, this `git restore` is not the correct rollback; use `git revert <commit>` on the fix commit instead. Behavioral test artifacts under `.harness/evidence|verification` and any temp sandbox dirs are independent of the hook files and need no rollback.

## Acceptance Criteria

- Criterion: After the fix, `json_get 'tool_input.command'` returns the command string via the python3 branch (python3 present).
  Verification Method: source-equivalent repro harness prints `[rm -rf /]`, not `[]`.
- Criterion: `pre-tool-guard.sh` denies a destructive command.
  Verification Method: `printf '{"tool_input":{"command":"rm -rf /"}}' | .claude/hooks/pre-tool-guard.sh` output contains `"permissionDecision":"deny"`.
- Criterion: `pre-tool-guard.sh` asks on a package command.
  Verification Method: `printf '{"tool_input":{"command":"npm install"}}' | …/pre-tool-guard.sh` output contains `"permissionDecision":"ask"`.
- Criterion: `pre-tool-guard.sh` passes a benign command silently.
  Verification Method: `printf '{"tool_input":{"command":"ls"}}' | …/pre-tool-guard.sh | wc -c` equals 0.
- Criterion: `scope-guard.sh` denies an out-of-scope edit and allows an in-scope edit and a `.harness/evidence` edit (active scope `src/`).
  Verification Method: temp-`CLAUDE_PROJECT_DIR` harness: Write `other/x.ts` → output contains `"deny"`; Write `src/x.ts` → 0 bytes; Write `.harness/evidence/x.md` → 0 bytes.
- Criterion: `stop-verify-gate.sh` blocks on completion-claim + active run + missing verification, and passes when a verification file exists.
  Verification Method: temp-dir harness: missing file → output contains `"decision":"block"`; with `.harness/verification/RUN-X.md` present → 0 bytes.
- Criterion: `evidence-log.sh` records the actual tool event body.
  Verification Method: temp-dir harness with a Bash payload → the written evidence file's `## Tool Events` section contains a `### … Bash` entry and the command text.
- Criterion: All four hooks still pass syntax check.
  Verification Method: `bash -n .claude/hooks/*.sh` → exit 0 for each.
- Criterion: Behavior is correct under the jq fallback too (python3 genuinely absent).
  Verification Method: Build a temporary sandbox PATH that contains ONLY the tools the hook needs and NO python3, **resolve those tool paths through a clean non-interactive `/bin/bash -c` subshell** (see the tool-shadowing note below), assert python3 is unresolvable AND a representative external tool (`grep`) actually runs inside it, then run the hook through it and assert the jq branch produces the same decisions. Note: a plain `PATH=/usr/bin` does NOT work on macOS because `/usr/bin/python3` exists alongside `/usr/bin/jq`; the sandbox must be a fresh dir of symlinks. Concretely:
  ```bash
  SBX="$(mktemp -d)"
  # Resolve REAL binary paths in a clean bash subshell so interactive-shell function/
  # alias shadows (e.g. `grep`) do not produce self-referential symlinks:
  /bin/bash -c 'for t in bash jq sed grep tr cat wc head date mkdir; do
    p="$(command -v "$t")"; [ -n "$p" ] && [ -x "$p" ] && ln -sf "$p" "'"$SBX"'/"; done'
  # Guard 1) Prove python3 is NOT resolvable in the sandbox (must print: python3-absent)
  env -i PATH="$SBX" HOME="$HOME" bash -c 'command -v python3 >/dev/null 2>&1 && echo python3-PRESENT || echo python3-absent'
  # Guard 2) Prove a representative external tool actually runs in the sandbox (must print: grep-ok)
  printf 'x\n' | env -i PATH="$SBX" HOME="$HOME" bash -c 'grep x' >/dev/null 2>&1 && echo grep-ok || echo grep-MISSING
  # 1) jq-branch deny
  printf '{"tool_input":{"command":"rm -rf /"}}' | env -i PATH="$SBX" HOME="$HOME" bash .claude/hooks/pre-tool-guard.sh | grep -q '"deny"' && echo JQ_DENY_OK
  # 2) jq-branch ask
  printf '{"tool_input":{"command":"npm install"}}' | env -i PATH="$SBX" HOME="$HOME" bash .claude/hooks/pre-tool-guard.sh | grep -q '"ask"' && echo JQ_ASK_OK
  # 3) jq-branch benign (expect 0)
  printf '{"tool_input":{"command":"ls"}}' | env -i PATH="$SBX" HOME="$HOME" bash .claude/hooks/pre-tool-guard.sh | wc -c
  rm -rf "$SBX"
  ```
  Pass condition (ALL must hold): `python3-absent` appears; `grep-ok` appears; the dangerous payload prints `JQ_DENY_OK`; the `npm install` payload prints `JQ_ASK_OK`; the benign `ls` payload prints byte count `0`. If `python3-PRESENT` or `grep-MISSING` ever appears, the test is invalid and must be repaired before trusting any deny/ask/benign result (a missing in-sandbox tool causes the hook to fail internally and produce a false negative).

  Tool-shadowing note: interactive shells (e.g. zsh/bash with the Claude shell snapshot) may shadow common tools such as `grep` with functions or aliases, so the current shell's `command -v grep` can return a bare word instead of a path — `ln -sf` on that yields a broken self-referential symlink. Sandbox binaries must therefore be resolved through a clean non-interactive `/bin/bash -c` resolver (which does not source interactive snapshots), NOT through the executor's current shell.
- Criterion: No-payload / empty input degrades to empty output without crashing (both branches).
  Verification Method: `printf '' | .claude/hooks/pre-tool-guard.sh | wc -c` equals 0 and exit status is 0 (python3 branch: `json.loads("")` raises, caught by `except`, prints nothing → `COMMAND` empty → hook exits 0). Repeat through the sandbox PATH above to cover the jq branch (`jq` on empty input also yields empty). Also confirm a malformed-but-present payload `printf 'not json' | .claude/hooks/pre-tool-guard.sh | wc -c` equals 0 with exit 0.
- Criterion: Only the four hook files changed; no other file modified.
  Verification Method: `git status --porcelain` lists only the four `.claude/hooks/*.sh` (plus `.harness/evidence|verification` artifacts); `git diff` touches only `json_get` python3-branch lines.
- Criterion: The four `json_get` blocks remain identical to each other after the edit.
  Verification Method: `for f in .claude/hooks/*.sh; do awk '/json_get\(\)/,/^}/' "$f" | md5; done` → all four md5s equal.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Heredoc/quoting edit breaks shell parsing | medium | Run `bash -n` on all four files after each edit; run the full behavioral suite. |
| Edit accidentally alters `scope-guard.sh` line-57 argv block or `json_string` | medium | Scope the edit to the `json_get` function only; re-verify line 57 and line 32 unchanged via `git diff`; confirm scope-guard still allows in-scope writes. |
| Env-var approach leaks `$INPUT` (may contain secrets) into the environment | low | `DMC_HOOK_INPUT` is set inline only for the single `python3` invocation (process-scoped), not exported globally; it is the same data already flowing through stdin today. |
| Four copies drift after manual editing | low | Acceptance criterion asserts all four `json_get` md5s remain equal. |
| Target machine lacks both python3 and jq | low | `json_get` already returns empty in that case (pre-existing); out of scope; document as unchanged. |
| `shellcheck` unavailable limits static analysis | low | Rely on `bash -n` plus behavioral tests. |

## Assumptions

| Assumption | Confidence | How to Verify |
|---|---|---|
| All four `json_get` blocks are byte-identical, so one patch applies to all | high | md5 check already run — all four equal. |
| `json_string` and the scope-guard argv python block are correct and out of scope | high | Inspected; `json_string` repro passes; line 57 reads argv not stdin. |
| `python3` accepts an inline `VAR=val python3 …` env assignment and `os.environ` read | high | Standard POSIX shell + CPython behavior; covered by the behavioral tests. |
| Fixing JSON extraction restores the originally intended gate decisions (regexes/thresholds already correct) | medium | Behavioral acceptance tests assert each gate's expected decision. |
| Writing under `.harness/plans|evidence|verification` is permitted and not product source | high | scope-guard allow-lists those dirs; skill saves plans there. |

## Execution Tasks

- [ ] DMC-T001: Patch `json_get` python3 branch in `pre-tool-guard.sh` (env-var approach).
  Files: `.claude/hooks/pre-tool-guard.sh`
  Notes: change only the two lines shown; leave jq branch intact.
- [ ] DMC-T002: Apply the identical patch to `scope-guard.sh` `json_get` ONLY.
  Files: `.claude/hooks/scope-guard.sh`
  Notes: do not touch line-57 argv block or `json_string`.
- [ ] DMC-T003: Apply the identical patch to `stop-verify-gate.sh`.
  Files: `.claude/hooks/stop-verify-gate.sh`
- [ ] DMC-T004: Apply the identical patch to `evidence-log.sh`.
  Files: `.claude/hooks/evidence-log.sh`
- [ ] DMC-T005: Run `bash -n` on all four hooks; confirm exit 0.
  Files: read-only
- [ ] DMC-T006: Run behavioral suite (pre-tool-guard deny/ask/benign; scope-guard in/out; stop-gate block/pass; evidence-log body) in temp dirs.
  Files: temp dirs + `.harness/evidence`
- [ ] DMC-T007: Run the sandbox-PATH jq-fallback test (exact block in the jq-fallback Acceptance Criterion). Build a `mktemp -d` PATH of symlinks (bash, jq, sed, grep, tr, cat, wc, head, date, mkdir) with NO python3, **resolving tool paths via a clean `/bin/bash -c` subshell**; assert the `python3-absent` and `grep-ok` guards both hold; then run pre-tool-guard deny/ask/benign through `env -i PATH="$SBX" …`.
  Files: temp sandbox dir only
  Notes: do NOT resolve paths with the current shell's `command -v` (interactive shells may shadow `grep` etc. as functions → broken self-symlinks → false negatives); do NOT use `PATH=/usr/bin` (`/usr/bin/python3` exists on macOS and would invalidate the test).
- [ ] DMC-T008: Run the no-payload / malformed-input checks (`printf '' | …` and `printf 'not json' | …` → 0 bytes, exit 0) on the python3 branch and through the sandbox PATH for the jq branch.
  Files: read-only (+ temp sandbox dir)
- [ ] DMC-T009: Confirm four `json_get` md5s remain equal and `git diff` touches only python3-branch lines of the four hooks.
  Files: read-only
- [ ] DMC-T010: Write `.harness/evidence/<run-id>.md` and `.harness/verification/<run-id>.md` with exact outputs and PASS/FAIL/PARTIAL.
  Files: `.harness/evidence/`, `.harness/verification/`
- [ ] DMC-T011 (rollback, only if a step fails before commit): `git restore` the four hook files to abandon the change cleanly.
  Files: `.claude/hooks/*.sh`
  Notes: applies only pre-commit; post-commit use `git revert` instead.

## Verification Commands

| Command | Reason | Required |
|---|---|---|
| `bash -n .claude/hooks/pre-tool-guard.sh .claude/hooks/scope-guard.sh .claude/hooks/stop-verify-gate.sh .claude/hooks/evidence-log.sh` | Syntax intact after edits | yes |
| `printf '{"tool_input":{"command":"rm -rf /"}}' \| .claude/hooks/pre-tool-guard.sh \| grep -q '"deny"'` | Destructive deny restored | yes |
| `printf '{"tool_input":{"command":"npm install"}}' \| .claude/hooks/pre-tool-guard.sh \| grep -q '"ask"'` | Package ask restored | yes |
| `printf '{"tool_input":{"command":"ls"}}' \| .claude/hooks/pre-tool-guard.sh \| wc -c` → 0 | Benign passes silently | yes |
| scope-guard temp-dir harness (deny `other/x.ts`; allow `src/x.ts`, `.harness/evidence/x.md`) | File-scope lock restored | yes |
| stop-verify-gate temp-dir harness (block missing verification; pass when present) | Completion gate restored | yes |
| evidence-log temp-dir harness (assert `### … Bash` event body) | Evidence body restored | yes |
| Sandbox-PATH jq test (resolver via clean `/bin/bash -c`): `SBX=$(mktemp -d); /bin/bash -c 'for t in bash jq sed grep tr cat wc head date mkdir; do p="$(command -v "$t")"; [ -n "$p" ] && [ -x "$p" ] && ln -sf "$p" "'"$SBX"'/"; done'` then assert `python3-absent` and `grep-ok` guards, run pre-tool-guard deny/ask/benign via `env -i PATH="$SBX" HOME="$HOME" bash .claude/hooks/pre-tool-guard.sh`; `rm -rf "$SBX"`. Full block in the jq-fallback Acceptance Criterion. | jq fallback genuinely exercised (must see `python3-absent` AND `grep-ok`; `command -v`-based resolver and `PATH=/usr/bin` are both invalid — see tool-shadowing note) | yes |
| `printf '' \| .claude/hooks/pre-tool-guard.sh \| wc -c` → 0 (exit 0); `printf 'not json' \| .claude/hooks/pre-tool-guard.sh \| wc -c` → 0 | No-payload / malformed input degrades to empty output, no crash | yes |
| `for f in .claude/hooks/*.sh; do awk '/json_get\(\)/,/^}/' "$f" \| md5; done \| sort -u \| wc -l` → 1 | Four copies stay identical | yes |
| `git status --porcelain` | Only the four hooks (+ harness artifacts) changed | yes |

## Approval Status

Status: APPROVED
Approver: 대표님
Approved At: 2026-06-18
