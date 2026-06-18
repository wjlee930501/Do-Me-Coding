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


TOOL_NAME="$(json_get 'tool_name')"
CWD="$(json_get 'cwd')"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$CWD}"
[ -n "$PROJECT_DIR" ] || PROJECT_DIR="$(pwd)"

mkdir -p "$PROJECT_DIR/.harness/evidence" "$PROJECT_DIR/.harness/runs"

RUN_ID_FILE="$PROJECT_DIR/.harness/runs/current-run-id"
if [ -f "$RUN_ID_FILE" ]; then
  RUN_ID="$(head -n 1 "$RUN_ID_FILE" | tr -cd 'A-Za-z0-9._-')"
fi
if [ -z "${RUN_ID:-}" ]; then
  RUN_ID="manual-$(date +%Y%m%d-%H%M%S)"
fi

EVIDENCE_FILE="$PROJECT_DIR/.harness/evidence/$RUN_ID.md"
TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

redact() {
  sed -E 's/(sk-[A-Za-z0-9_-]{8,})/[REDACTED_API_KEY]/g; s/(password|secret|token|api[_-]?key)=([^[:space:]]+)/\1=[REDACTED]/gi'
}

COMMAND="$(json_get 'tool_input.command' | redact | cut -c 1-500)"
FILE_PATH="$(json_get 'tool_input.file_path' | cut -c 1-500)"

if [ ! -f "$EVIDENCE_FILE" ]; then
  {
    echo "# Evidence Log"
    echo
    echo "Run ID: $RUN_ID"
    echo "Started: $TIMESTAMP"
    echo
    echo "## Tool Events"
    echo
  } > "$EVIDENCE_FILE"
fi

case "$TOOL_NAME" in
  Bash)
    {
      echo "### $TIMESTAMP Bash"
      echo
      echo '```bash'
      printf '%s\n' "$COMMAND"
      echo '```'
      echo
    } >> "$EVIDENCE_FILE"
    ;;
  Edit|Write)
    {
      echo "### $TIMESTAMP $TOOL_NAME"
      echo
      echo "File: $FILE_PATH"
      echo
    } >> "$EVIDENCE_FILE"
    ;;
esac

exit 0
