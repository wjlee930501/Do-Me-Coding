# Verification Report

## Run ID

fix-hook-json-helper

## Plan

.harness/plans/fix-hook-json-helper.md (APPROVED 2026-06-18, Approver: 대표님)

## Changed Files

- .claude/hooks/pre-tool-guard.sh: json_get python3 branch — read payload from $DMC_HOOK_INPUT env var instead of heredoc-shadowed stdin
- .claude/hooks/scope-guard.sh: same json_get fix (line-57 argv block and json_string untouched)
- .claude/hooks/stop-verify-gate.sh: same json_get fix
- .claude/hooks/evidence-log.sh: same json_get fix

Each file changed by exactly 3 lines (command prefix, `import json, os, sys`, `json.loads(os.environ.get("DMC_HOOK_INPUT", ""))`). Total diff: 4 files, 12 insertions, 12 deletions.

## Commands Run

| Command | Result | Reason | Output Summary |
|---|---|---|---|
| `git diff --stat -- .claude/hooks/` | PASS | Scope/size check (T009a) | 4 files changed, 12 ins / 12 del — exactly 3 lines/file |
| `bash -n .claude/hooks/*.sh` | PASS | Syntax intact (T005) | all four OK |
| `printf '{"tool_input":{"command":"rm -rf /"}}' \| pre-tool-guard.sh` | PASS | Destructive deny restored (T006) | output contains `"permissionDecision":"deny"` |
| `printf '{"tool_input":{"command":"npm install"}}' \| pre-tool-guard.sh` | PASS | Package ask restored (T006) | output contains `"permissionDecision":"ask"` |
| `printf '{"tool_input":{"command":"ls"}}' \| pre-tool-guard.sh \| wc -c` | PASS | Benign passes silently (T006) | 0 bytes |
| scope-guard temp-dir harness (scope=`src/`) | PASS | File-scope lock restored (T006) | out-of-scope→deny; `src/x.ts`→0; `.harness/evidence/x.md`→0 |
| stop-verify-gate temp-dir harness | PASS | Completion gate restored (T006) | missing verification→block; present→0 bytes |
| evidence-log temp-dir harness | PASS | Evidence body restored (T006) | `### … Bash` entry + command text present |
| jq-fallback sandbox test (`/bin/bash -c` resolver) | PASS | jq branch genuinely exercised (T007) | `python3-absent`, `grep-ok`, `jq_deny_OK`, `jq_ask_OK`, benign 0 |
| `printf '' \| pre-tool-guard.sh \| wc -c` ; `printf 'not json' \| …` | PASS | No-payload / malformed degrade safely (T008) | 0 bytes, exit 0 for both |
| `for f in .claude/hooks/*.sh; do awk '/json_get\(\)/,/^}/' "$f" \| md5; done \| sort -u \| wc -l` | PASS | Four copies stay identical (T009b) | unique md5 count = 1 |
| `git status --porcelain -- .claude/hooks/` | PASS | Only the four hooks changed | 4 × ` M` hook entries, nothing else |

## Manual Checks

| Check | Result | Notes |
|---|---|---|
| Diff touches only json_get python3-branch lines | PASS | No change to jq branch, json_string (line 32), or scope-guard argv block (line 57) |
| Live in-production evidence logging | PASS | Auto run-evidence `.harness/evidence/fix-hook-json-helper.md` now records full Bash event bodies + the Edit event (was empty pre-fix) |
| Heredoc body remains column-0 | PASS | Only the documented 3 lines changed; heredoc indentation preserved |
| DMC.md / dmc-plan-hard SKILL.md untouched this run | PASS | Pre-existing working-tree changes (mtime 14:01:29), not modified during execution |

## Scope Review

Result: PASS

Notes: Approved scope = the four `.claude/hooks/*.sh` files (`.harness/runs/current-scope.txt`). All edits landed inside that scope; verification artifacts written only under `.harness/evidence|verification|runs` (internal allow-list). No product/scaffold file outside scope was modified.

## Package / Env / Migration Review

Package files changed: no
Env files changed: no
Migration files changed: no

Notes: Pure shell-hook text fix. The fix introduces a process-scoped env var `DMC_HOOK_INPUT` set inline only for the single `python3` invocation inside `json_get`; it is not exported to the shell and carries the same payload that previously flowed through stdin. No dependency, schema, or configuration change.

## Unresolved Risks

- none (fix validated on both the python3 and jq branches; behavior identical to intended gate decisions).
- Note (informational, out of scope): the four hooks still embed four duplicated copies of `json_get`; a future refactor to a single sourced helper would reduce drift risk. The md5-identity check guards against drift for now.

## Final Status

PASS
