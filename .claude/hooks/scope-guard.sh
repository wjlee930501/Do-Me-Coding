#!/usr/bin/env bash
set -u
INPUT="$(cat)"

# Do-Me-Coding mode gate (v0.1.1): scope lock enforces in active only; pass-through in passive/off.
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
FILE_PATH="$(json_get 'tool_input.file_path')"
CWD="$(json_get 'cwd')"

[ "$TOOL_NAME" = "Edit" ] || [ "$TOOL_NAME" = "Write" ] || exit 0
[ -n "$FILE_PATH" ] || exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$CWD}"
[ -n "$PROJECT_DIR" ] || PROJECT_DIR="$(pwd)"

RUNS_DIR="$PROJECT_DIR/.harness/runs"
RUN_ID_FILE="$RUNS_DIR/current-run-id"
SCOPE_FILE="$RUNS_DIR/current-scope.txt"

RUN_ID=""
if [ -f "$RUN_ID_FILE" ]; then
  RUN_ID="$(head -n 1 "$RUN_ID_FILE" | tr -cd 'A-Za-z0-9._-')"
fi

RUN_DIR=""
LOCK=""
if [ -n "$RUN_ID" ]; then
  RUN_DIR="$RUNS_DIR/$RUN_ID"
  LOCK="$RUN_DIR/scope.lock.json"
fi

# ARMED := current-run-id present AND that run carries an immutable scope.lock.json (L1 adjudication).
# Otherwise the shim falls back to the legacy current-scope.txt membership check (today's live state).
ARMED=0
if [ -n "$LOCK" ] && [ -f "$LOCK" ]; then
  ARMED=1
fi

# No run context at all (no scope.lock and no legacy scope file) => nothing to enforce.
if [ "$ARMED" -eq 0 ] && [ ! -f "$SCOPE_FILE" ]; then
  exit 0
fi

# Interpreter policy: fail-CLOSED when armed (a lock exists but cannot be adjudicated); keep the
# legacy fail-OPEN for the unarmed/no-python path (baseline compatibility — v0.1 behavior).
if ! command -v python3 >/dev/null 2>&1; then
  if [ "$ARMED" -eq 1 ]; then
    reason="Do-Me-Coding fail-closed: run '$RUN_ID' is armed (scope.lock.json present) but python3 is unavailable to adjudicate the edit. Install python3 or suspend the run (dmc run suspend)."
    reason_json="$(printf '%s' "$reason" | json_string)"
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}\n' "$reason_json"
  fi
  exit 0
fi

# Resolve the Ring-0 scope-lock adjudicator (armed path only), script-relative + robust to a
# synthetic CLAUDE_PROJECT_DIR.
SL_SCRIPT=""
if [ "$ARMED" -eq 1 ]; then
  for _cand in "$PROJECT_DIR/bin/lib/dmc-scope-lock.py" "$(cd "$(dirname "$0")/../.." 2>/dev/null && pwd)/bin/lib/dmc-scope-lock.py"; do
    [ -n "$_cand" ] && [ -f "$_cand" ] && { SL_SCRIPT="$_cand"; break; }
  done
fi

python3 - "$PROJECT_DIR" "$FILE_PATH" "$RUN_DIR" "$LOCK" "$SCOPE_FILE" "$SL_SCRIPT" <<'PY'
import os, sys, json, subprocess

project_dir, file_path, run_dir, lock_path, scope_file, sl_script = sys.argv[1:7]
project_dir = os.path.realpath(project_dir)
target = os.path.realpath(file_path if os.path.isabs(file_path) else os.path.join(project_dir, file_path))
runs_base = os.path.realpath(os.path.join(project_dir, ".harness", "runs"))

def rel(p):
    try:
        return os.path.relpath(p, project_dir)
    except Exception:
        return p

def deny(reason):
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse",
        "permissionDecision": "deny", "permissionDecisionReason": reason}}, ensure_ascii=False))
    sys.exit(0)

# --- Out-of-project deny (PINNED, never a relaxation of an existing deny). ---
# A realpath NOT under the project dir is denied while a run is armed or a legacy scope file is
# present (this block is only reached in that enforcing state — the shell exits 0 earlier when
# unarmed with no scope file, so UNARMED out-of-repo writes stand down). Out-of-repo targets
# (~/.claude/settings.json, shell rc files, sibling checkouts) are real armed-run attack surfaces and
# are never in an approved in-repo scope. realpath already resolved symlinks: a symlink INTO the repo
# becomes an in-repo target adjudicated normally below; a link pointing OUT resolves out-of-project
# and is denied here. Measured scratchpad-class exceptions would be config-only (a documented
# allowlist, default empty), never a code default — none is implemented here, so the rule is strict deny.
if target != project_dir and not target.startswith(project_dir + os.sep):
    deny("Do-Me-Coding blocked an Edit/Write to a path outside the project directory (" + target
         + ") while a run/scope is active. Out-of-repo writes are not adjudicable to the approved "
         "scope; step aside with /dmc-off (or dmc run suspend) for out-of-repo edits.")

# --- Static run-state deny: run pointers + immutable state files mutate ONLY via the dmc CLI. ---
# Canonical bypass (2): an agent may not Edit/Write its own scope.lock (nor approvals/run/blocked);
# snapshot.txt is run state too (a forged operative snapshot would launder lock tamper + pre-seed the
# post-Bash baseline), so it is denied like the others.
RUN_STATE_BASENAMES = {"scope.lock.json", "approvals.jsonl", "run.json", "blocked.json", "snapshot.txt"}
if target == runs_base or target.startswith(runs_base + os.sep):
    if target in (os.path.join(runs_base, "current-run-id"), os.path.join(runs_base, "current-scope.txt")):
        deny("Do-Me-Coding blocked an Edit/Write to run-pointer file " + rel(target)
             + " — run pointers mutate only via the dmc CLI, never a direct edit.")
    if os.path.basename(target) in RUN_STATE_BASENAMES:
        deny("Do-Me-Coding blocked an Edit/Write to protected run-state file " + rel(target)
             + " — scope.lock/approvals/run/blocked/snapshot mutate only via the dmc CLI (an agent may not edit its own lock or snapshot).")

# --- Narrow internal exemption: evidence + verification + append-only logs under THIS run dir. ---
# (Replaces the old blanket .harness/runs + .harness/decisions auto-allow; run-state files above
#  are already denied, so what remains here are append-only logs like the evidence ledger.)
def _within(base):
    b = os.path.realpath(base)
    return target == b or target.startswith(b + os.sep)

if _within(os.path.join(project_dir, ".harness", "evidence")):
    sys.exit(0)
if _within(os.path.join(project_dir, ".harness", "verification")):
    sys.exit(0)
if run_dir and _within(run_dir):
    sys.exit(0)

# --- Adjudication ---
if lock_path and os.path.isfile(lock_path):
    # ARMED: Ring-0 scope-lock adjudication owns the verdict; this shim only translates it.
    if not sl_script or not os.path.isfile(sl_script):
        deny("Do-Me-Coding fail-closed: the run is armed but the Ring-0 scope-lock adjudicator "
             "(bin/lib/dmc-scope-lock.py) is unresolved; the edit cannot be adjudicated. "
             "Restore bin/lib or suspend the run (dmc run suspend).")
    try:
        r = subprocess.run([sys.executable, "-B", sl_script, "--adjudicate", lock_path, rel(target), "edit"],
                           capture_output=True, text=True, timeout=20)
    except Exception:
        deny("Do-Me-Coding fail-closed: the scope-lock adjudicator could not be executed for "
             + rel(target) + ".")
    if r.returncode == 0:
        sys.exit(0)
    detail = (r.stdout or "").strip() or "scope-lock adjudication refused the edit"
    deny("Do-Me-Coding blocked file edit outside the approved scope lock: " + rel(target) + " — " + detail)

# LEGACY: current-scope.txt membership (behavior preserved; only the internal-allow list narrowed).
if scope_file and os.path.isfile(scope_file):
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
    deny("Do-Me-Coding blocked file edit outside approved scope: " + rel(target)
         + ". Update .harness/runs/current-scope.txt through an approved plan if this file is intended.")

# Neither an armed lock nor a legacy scope file applies: nothing to enforce.
sys.exit(0)
PY
