#!/usr/bin/env bash
set -u
INPUT="$(cat)"

# Do-Me-Coding mode gate (v0.1.1): active | passive | off. Absent => active (backward compatible).
DMC_MODE_FILE="${CLAUDE_PROJECT_DIR:-$PWD}/.harness/mode"
DMC_MODE="active"
if [ -f "$DMC_MODE_FILE" ]; then
  DMC_MODE="$(head -n1 "$DMC_MODE_FILE" | tr -d '[:space:]' | tr 'A-Z' 'a-z')"
  case "$DMC_MODE" in active|passive|off) ;; *) DMC_MODE="active" ;; esac
fi

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

# Block A — catastrophic destructive (enforced in ALL modes: active, passive, off)
if printf '%s' "$CMD_ONE_LINE" | grep -Eiq 'sudo[[:space:]]+rm[[:space:]]+-rf|git[[:space:]]+push[[:space:]].*--force|prisma[[:space:]]+migrate[[:space:]]+reset|rails[[:space:]]+db:drop|python[[:space:]]+manage\.py[[:space:]]+flush|kubectl[[:space:]]+delete|terraform[[:space:]]+destroy'; then
  deny "Do-Me-Coding blocked a high-risk destructive command. Create an approved plan and request explicit human approval."
fi

# Block A — secret exposure (treated as catastrophic; enforced in ALL modes including off)
if printf '%s' "$CMD_ONE_LINE" | grep -Eiq '(^|[;&|[:space:]])(printenv|cat[[:space:]]+\.env|cat[[:space:]]+.*\.env|cat[[:space:]]+~/.ssh|cat[[:space:]]+~/.aws)'; then
  deny "Do-Me-Coding blocked a command that may expose secrets. Use targeted, redacted inspection instead."
fi

# Block A — catastrophic database (enforced in ALL modes)
if printf '%s' "$CMD_ONE_LINE" | grep -Eiq '(DROP[[:space:]]+DATABASE|TRUNCATE[[:space:]]+TABLE)'; then
  deny "Do-Me-Coding blocked a catastrophic database command. Require explicit approval and rollback plan."
fi

# Block B — full deny tier (enforced in active and passive; stands down in off)
if [ "$DMC_MODE" != "off" ]; then
  if printf '%s' "$CMD_ONE_LINE" | grep -Eiq 'git[[:space:]]+reset[[:space:]]+--hard|(DELETE[[:space:]]+FROM)'; then
    deny "Do-Me-Coding blocked a destructive command (use /dmc-off only when intentionally stepping aside). Require explicit approval."
  fi
fi

# Block C — ask tier (active mode only; less intrusive in passive/off)
if [ "$DMC_MODE" = "active" ]; then
  if printf '%s' "$CMD_ONE_LINE" | grep -Eiq '(npm|pnpm|yarn|bun)[[:space:]]+publish|npm[[:space:]]+audit[[:space:]]+fix[[:space:]]+--force|schema[[:space:]]+push|migrate[[:space:]]+(deploy|dev|reset)|npm[[:space:]]+install|pnpm[[:space:]]+install|yarn[[:space:]]+install|bun[[:space:]]+install'; then
    ask "Do-Me-Coding detected a package, migration, publish, or schema-changing command. Confirm this is intended."
  fi
fi

exit 0
