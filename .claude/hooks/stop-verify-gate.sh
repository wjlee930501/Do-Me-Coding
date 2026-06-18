#!/usr/bin/env bash
set -u
INPUT="$(cat)"

# Do-Me-Coding mode gate (v0.1.1): completion gate enforces in active only; pass-through in passive/off.
DMC_MODE_FILE="${CLAUDE_PROJECT_DIR:-$PWD}/.harness/mode"
DMC_MODE="active"
if [ -f "$DMC_MODE_FILE" ]; then
  DMC_MODE="$(head -n1 "$DMC_MODE_FILE" | tr -d '[:space:]' | tr 'A-Z' 'a-z')"
  case "$DMC_MODE" in active|passive|off) ;; *) DMC_MODE="active" ;; esac
fi
[ "$DMC_MODE" = "active" ] || exit 0

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


STOP_ACTIVE="$(json_get 'stop_hook_active')"
LAST_MESSAGE="$(json_get 'last_assistant_message')"
CWD="$(json_get 'cwd')"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$CWD}"

[ "$STOP_ACTIVE" = "true" ] && exit 0
[ -n "$PROJECT_DIR" ] || PROJECT_DIR="$(pwd)"

RUN_ID_FILE="$PROJECT_DIR/.harness/runs/current-run-id"
[ -f "$RUN_ID_FILE" ] || exit 0

RUN_ID="$(head -n 1 "$RUN_ID_FILE" | tr -cd 'A-Za-z0-9._-')"
[ -n "$RUN_ID" ] || exit 0

if ! printf '%s' "$LAST_MESSAGE" | grep -Eiq '(completed|done|implemented|fixed|finished|완료|구현했습니다|고쳤습니다|끝났습니다|수정했습니다|해결했습니다)'; then
  exit 0
fi

if ls "$PROJECT_DIR/.harness/verification/$RUN_ID"* >/dev/null 2>&1; then
  exit 0
fi

reason="Do-Me-Coding verification artifact missing for active run '$RUN_ID'. Run /dmc-verify-hard, write .harness/verification/$RUN_ID.md, and report PASS/FAIL/PARTIAL before claiming completion."
reason_json="$(printf '%s' "$reason" | json_string)"
printf '{"decision":"block","reason":%s}\n' "$reason_json"
exit 0
