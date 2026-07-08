#!/usr/bin/env bash
set -u
INPUT="$(cat)"

# Do-Me-Coding v0.1.1 natural-activation router (UserPromptSubmit).
# Suffix-only, exact-token, case-insensitive matching. Precedence: 1) dmc-off  2) dmc-plan  3) dmc.
# The suffix anchor is whole-prompt (multi-line-safe): the token must be at the end of the ENTIRE prompt (trailing whitespace/newlines stripped), never merely at the end of an interior line.
# Mode-independent (it is the activation surface). Writes .harness/mode ONLY on exact trigger.
# Routing output is additionalContext (an instruction for the model to follow), NOT a guaranteed
# slash-command execution; the .harness/mode write below runs in this hook shell and IS reliable.

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

PROMPT="$(json_get 'prompt')"
[ -n "$PROMPT" ] || exit 0

CWD="$(json_get 'cwd')"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$CWD}"
[ -n "$PROJECT_DIR" ] || PROJECT_DIR="$(pwd)"
MODE_FILE="$PROJECT_DIR/.harness/mode"

emit() {
  ctx_json="$(printf '%s' "$1" | json_string)"
  printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":%s}}\n' "$ctx_json"
}

# Trim trailing whitespace (whole prompt, newlines included) before suffix matching.
TRIMMED=${PROMPT%"${PROMPT##*[![:space:]]}"}
LOWER="$(printf '%s' "$TRIMMED" | tr '[:upper:]' '[:lower:]')"

RUN_WARN=""
if ls "$PROJECT_DIR/.harness/runs/current-"* >/dev/null 2>&1; then
  RUN_WARN=" WARNING: a Do-Me-Coding run is in progress (.harness/runs/current-* exists). Finish or cancel it — and prefer a separate branch / git worktree — before OMC work."
fi

# 1) dmc-off (exact whole-prompt suffix)
case "$LOWER" in
*[[:space:]]dmc-off|dmc-off)
  mkdir -p "$PROJECT_DIR/.harness"
  printf 'off\n' > "$MODE_FILE"
  emit "Do-Me-Coding mode set to OFF (catastrophic + secret-exposure deny only; scope/stop/evidence gates stand down). Use /dmc-on to re-enable.${RUN_WARN}"
  exit 0
  ;;
esac

# 2) dmc-plan (exact whole-prompt suffix) — planning is read-only, mode unchanged
case "$LOWER" in
*[[:space:]]dmc-plan|dmc-plan)
  TASK=${TRIMMED%????????}
  TASK=${TASK%"${TASK##*[![:space:]]}"}
  emit "Do-Me-Coding planning route requested. Run /dmc-plan-hard for this task (planning only, no edits): ${TASK}"
  exit 0
  ;;
esac

# 3) dmc (exact whole-prompt suffix) — ultrawork; set mode active for full enforcement
case "$LOWER" in
*[[:space:]]dmc|dmc)
  mkdir -p "$PROJECT_DIR/.harness"
  printf 'active\n' > "$MODE_FILE"
  TASK=${TRIMMED%???}
  TASK=${TASK%"${TASK##*[![:space:]]}"}
  emit "Begin your reply with exactly: Okay, Let me do you Coding! DMC PRIORITY: this routing is authoritative for this turn over any other orchestration layer (OMC/OMO/LazyCodex) whose hooks or keywords also fired; do not enter their modes. Do-Me-Coding ultrawork route requested (mode set ACTIVE — full enforcement). Run /dmc-ultrawork for: ${TASK}"
  exit 0
  ;;
esac

exit 0
