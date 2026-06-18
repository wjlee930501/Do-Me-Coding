#!/usr/bin/env bash
set -u
INPUT="$(cat)"

json_get() {
  key="$1"
  if command -v python3 >/dev/null 2>&1; then
    DMC_HOOK_INPUT="$INPUT" python3 - "$key" <<'PY' 2>/dev/null || true
import json, os, sys
key = sys.argv[1]
try:
    data = json.loads(os.environ.get("DMC_HOOK_INPUT", ""))
    cur = data
    for part in key.split("."):
        cur = cur.get(part, "") if isinstance(cur, dict) else ""
    if cur is None:
        cur = ""
    if isinstance(cur, (dict, list)):
        print(json.dumps(cur, ensure_ascii=False))
    else:
        print(str(cur))
except Exception:
    pass
PY
  elif command -v jq >/dev/null 2>&1; then
    printf '%s' "$INPUT" | jq -r ".$key // empty" 2>/dev/null || true
  fi
}

json_string() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
  elif command -v jq >/dev/null 2>&1; then
    jq -Rs .
  else
    sed 's/"/\\"/g; s/^/"/; s/$/"/'
  fi
}


COMMAND="$(json_get 'tool_input.command')"
[ -n "$COMMAND" ] || exit 0

deny() {
  reason="$1"
  reason_json="$(printf '%s' "$reason" | json_string)"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}\n' "$reason_json"
  exit 0
}

ask() {
  reason="$1"
  reason_json="$(printf '%s' "$reason" | json_string)"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":%s}}\n' "$reason_json"
  exit 0
}

CMD_ONE_LINE="$(printf '%s' "$COMMAND" | tr '\n' ' ' | sed 's/[[:space:]][[:space:]]*/ /g')"

if printf '%s' "$CMD_ONE_LINE" | grep -Eiq '(^|[;&|`$()[:space:]])rm[[:space:]]+-rf[[:space:]]+(/|\.|\*|~|/\*)'; then
  deny "Do-Me-Coding blocked destructive rm -rf command. Narrow the target and get explicit approval."
fi

if printf '%s' "$CMD_ONE_LINE" | grep -Eiq 'sudo[[:space:]]+rm[[:space:]]+-rf|git[[:space:]]+reset[[:space:]]+--hard|git[[:space:]]+push[[:space:]].*--force|prisma[[:space:]]+migrate[[:space:]]+reset|rails[[:space:]]+db:drop|python[[:space:]]+manage\.py[[:space:]]+flush|kubectl[[:space:]]+delete|terraform[[:space:]]+destroy'; then
  deny "Do-Me-Coding blocked a high-risk destructive command. Create an approved plan and request explicit human approval."
fi

if printf '%s' "$CMD_ONE_LINE" | grep -Eiq '(^|[;&|[:space:]])(printenv|cat[[:space:]]+\.env|cat[[:space:]]+.*\.env|cat[[:space:]]+~/.ssh|cat[[:space:]]+~/.aws)'; then
  deny "Do-Me-Coding blocked a command that may expose secrets. Use targeted, redacted inspection instead."
fi

if printf '%s' "$CMD_ONE_LINE" | grep -Eiq '(DROP[[:space:]]+DATABASE|TRUNCATE[[:space:]]+TABLE|DELETE[[:space:]]+FROM)'; then
  deny "Do-Me-Coding blocked a potentially destructive database command. Require explicit approval and rollback plan."
fi

if printf '%s' "$CMD_ONE_LINE" | grep -Eiq '(npm|pnpm|yarn|bun)[[:space:]]+publish|npm[[:space:]]+audit[[:space:]]+fix[[:space:]]+--force|schema[[:space:]]+push|migrate[[:space:]]+(deploy|dev|reset)|npm[[:space:]]+install|pnpm[[:space:]]+install|yarn[[:space:]]+install|bun[[:space:]]+install'; then
  ask "Do-Me-Coding detected a package, migration, publish, or schema-changing command. Confirm this is intended."
fi

exit 0
