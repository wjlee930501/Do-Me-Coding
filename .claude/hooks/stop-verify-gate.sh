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
CWD="$(json_get 'cwd')"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$CWD}"
[ -n "$PROJECT_DIR" ] || PROJECT_DIR="$(pwd)"

# Prevent an infinite stop loop: if we are here because a prior Stop hook already blocked, let it pass.
[ "$STOP_ACTIVE" = "true" ] && exit 0

# The gate arms from RUN STATE, not from completion keywords (the keyword regex is removed): no active
# run => nothing to gate.
RUN_ID_FILE="$PROJECT_DIR/.harness/runs/current-run-id"
[ -f "$RUN_ID_FILE" ] || exit 0
RUN_ID="$(head -n 1 "$RUN_ID_FILE" | tr -cd 'A-Za-z0-9._-')"
[ -n "$RUN_ID" ] || exit 0

block() {
  reason="$1"
  reason_json="$(printf '%s' "$reason" | json_string)"
  printf '{"decision":"block","reason":%s}\n' "$reason_json"
  exit 0
}

# Resolve bin/dmc script-relative (robust to a synthetic CLAUDE_PROJECT_DIR).
DMC_BIN=""
for _cand in "$PROJECT_DIR/bin/dmc" "$(cd "$(dirname "$0")/../.." 2>/dev/null && pwd)/bin/dmc"; do
  [ -n "$_cand" ] && [ -x "$_cand" ] && { DMC_BIN="$_cand"; break; }
done

# Fail-closed: a run is active but the Ring-0 stop gate is unreachable.
if [ -z "$DMC_BIN" ] || ! command -v python3 >/dev/null 2>&1; then
  block "Do-Me-Coding cannot verify completion for active run '$RUN_ID': the Ring-0 stop gate (bin/dmc + python3) is unavailable. Restore it, or suspend the run (dmc run suspend), before claiming completion."
fi

# Pass the verification report if it lives under .harness/verification/<run-id>*.md (the stop gate
# also checks <run-dir>/verification.md itself). The quick gate is state-file-only and stays < 2s.
REPORT_ARG=""
for _r in "$PROJECT_DIR/.harness/verification/$RUN_ID.md" "$PROJECT_DIR/.harness/verification/$RUN_ID"*.md; do
  [ -f "$_r" ] && { REPORT_ARG="$_r"; break; }
done

GATE_ARGS=(stop-gate quick --root "$PROJECT_DIR")
[ -n "$REPORT_ARG" ] && GATE_ARGS+=(--report "$REPORT_ARG")

OUT="$("$DMC_BIN" "${GATE_ARGS[@]}" 2>&1)"
RC=$?

# Exit 0 => pass (SUSPENDED/DONE/covered runs pass). Non-zero (4 hold, or any unexpected status) =>
# hold the stop and surface the reason to the model.
[ "$RC" -eq 0 ] && exit 0
[ -n "$OUT" ] || OUT="stop-gate quick held completion for run '$RUN_ID'"
block "Do-Me-Coding held completion for active run '$RUN_ID': $OUT. Satisfy the required verification/receipts (or run dmc run suspend) before claiming done."
