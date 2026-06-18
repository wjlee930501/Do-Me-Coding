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
FILE_PATH="$(json_get 'tool_input.file_path')"
CWD="$(json_get 'cwd')"

[ "$TOOL_NAME" = "Edit" ] || [ "$TOOL_NAME" = "Write" ] || exit 0
[ -n "$FILE_PATH" ] || exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$CWD}"
SCOPE_FILE="$PROJECT_DIR/.harness/runs/current-scope.txt"

[ -f "$SCOPE_FILE" ] || exit 0

if ! command -v python3 >/dev/null 2>&1; then
  exit 0
fi

python3 - "$PROJECT_DIR" "$FILE_PATH" "$SCOPE_FILE" <<'PY'
import os, sys, json

project_dir, file_path, scope_file = sys.argv[1:4]
project_dir = os.path.realpath(project_dir)
target = os.path.realpath(file_path if os.path.isabs(file_path) else os.path.join(project_dir, file_path))

internal_allow = [
    ".harness/evidence",
    ".harness/verification",
    ".harness/runs",
    ".harness/decisions",
]
for rel in internal_allow:
    base = os.path.realpath(os.path.join(project_dir, rel))
    if target == base or target.startswith(base + os.sep):
        sys.exit(0)

allowed = []
with open(scope_file, "r", encoding="utf-8") as f:
    for raw in f:
        line = raw.strip()
        if not line or line.startswith("#") or "=" in line:
            continue
        path = os.path.realpath(line if os.path.isabs(line) else os.path.join(project_dir, line))
        allowed.append((line, path))

for raw, path in allowed:
    if raw.endswith("/") and (target == path or target.startswith(path + os.sep)):
        sys.exit(0)
    if target == path or target.startswith(path + os.sep):
        sys.exit(0)

reason = "Do-Me-Coding blocked file edit outside approved scope: " + os.path.relpath(target, project_dir) + ". Update .harness/runs/current-scope.txt through an approved plan if this file is intended."
print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": reason
    }
}, ensure_ascii=False))
PY
