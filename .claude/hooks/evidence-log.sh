#!/usr/bin/env bash
set -u
INPUT="$(cat)"

# Do-Me-Coding mode gate (v0.1.1): evidence logging in active only; no-op in passive/off.
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

# --- M6 post-Bash out-of-scope diff guard (PostToolUse, Bash tool, armed run only) ---
# Logging above is never gated by this; a guard failure must NEVER break the tool flow. PostToolUse
# cannot deny retroactively — an out-of-scope change records a sticky BLOCKED marker (via the dmc CLI)
# and emits feedback; the actual hold lands at the stop gate. Armed := run-id + this run's
# scope.lock.json + arming snapshot.txt all present (the repo's normal unarmed state skips this).
if [ "$TOOL_NAME" = "Bash" ] && [ -f "$RUN_ID_FILE" ]; then
  EL_RUN_ID="$(head -n 1 "$RUN_ID_FILE" | tr -cd 'A-Za-z0-9._-')"
  EL_LOCK="$PROJECT_DIR/.harness/runs/$EL_RUN_ID/scope.lock.json"
  EL_SNAP="$PROJECT_DIR/.harness/runs/$EL_RUN_ID/snapshot.txt"
  if [ -n "$EL_RUN_ID" ] && [ -f "$EL_LOCK" ] && [ -f "$EL_SNAP" ] && command -v python3 >/dev/null 2>&1; then
    EL_DMC=""
    for _cand in "$PROJECT_DIR/bin/dmc" "$(cd "$(dirname "$0")/../.." 2>/dev/null && pwd)/bin/dmc"; do
      [ -n "$_cand" ] && [ -x "$_cand" ] && { EL_DMC="$_cand"; break; }
    done
    if [ -n "$EL_DMC" ]; then
      EL_OUT="$("$EL_DMC" postbash-diff --scope-lock "$EL_LOCK" --snapshot "$EL_SNAP" --root "$PROJECT_DIR" 2>/dev/null)"
      EL_RC=$?
      if [ "$EL_RC" -eq 4 ]; then
        EL_REASON="$(printf '%s' "$EL_OUT" | sed -n 's/.*"reason":"\([^"]*\)".*/\1/p')"
        [ -n "$EL_REASON" ] || EL_REASON="post-Bash out-of-scope change detected"
        EL_PATHS="$(printf '%s' "$EL_OUT" | sed -n 's/.*"blocked_paths":\[\([^]]*\)\].*/\1/p' | tr -d '"' | tr ',' ' ')"
        # Sticky BLOCKED marker via the dmc CLI, scoped to THIS run (--root, not cwd — the hook's cwd
        # is the parent session's, not necessarily PROJECT_DIR). Idempotent: a pre-existing marker is fine.
        # shellcheck disable=SC2086
        "$EL_DMC" run block --root "$PROJECT_DIR" --reason "$EL_REASON" ${EL_PATHS:+--paths $EL_PATHS} --created-by dmc-postbash-diff >/dev/null 2>&1 || true
        fb="Do-Me-Coding post-Bash guard: an out-of-scope change was recorded and run '$EL_RUN_ID' is now BLOCKED ($EL_REASON${EL_PATHS:+ — paths:$EL_PATHS}). Revert the stray change; completion is held until you resolve it with dmc run unblock."
        fb_json="$(printf '%s' "$fb" | json_string)"
        printf '{"decision":"block","reason":%s}\n' "$fb_json"
        exit 0
      fi
    fi
  fi
fi

exit 0
