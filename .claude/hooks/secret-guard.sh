#!/usr/bin/env bash
set -u
INPUT="$(cat)"

# Do-Me-Coding v0.1.3 secret-read guard (PreToolUse: Read|Grep|Glob).
# Denies tool access to secret-bearing PATHS. Decides by path/glob string ONLY — it never opens
# the target file, so it cannot itself leak secrets. Security floor: enforced in ALL modes
# (active/passive/off), independent of .harness/mode — mirrors pre-tool-guard's Bash secret deny.
# Note (documented residual risk): a broad Grep with no file_path cannot be path-blocked here;
# Grep respects .gitignore so gitignored secrets are skipped, and the CLAUDE.md instruction-level
# rule remains the defense-in-depth layer. Glob does NOT respect .gitignore, so Glob is guarded here.

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
case "$TOOL_NAME" in
  Read|Grep|Glob) ;;
  *) exit 0 ;;
esac

deny() {
  reason="$1"
  reason_json="$(printf '%s' "$reason" | json_string)"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}\n' "$reason_json"
  exit 0
}

# Precise path detector (basename-based). Allow-list wins. Reads no files.
is_secret_path() {
  p="$1"
  [ -n "$p" ] || return 1
  base="${p##*/}"
  # ALLOW (not secrets): example/sample env templates
  case "$base" in
    .env.example|.env.sample|.env.template|.env.dist) return 1 ;;
  esac
  # BLOCK: dot-env family (.env, .env.local, .env.prod.local, .env.production, ...)
  case "$base" in
    .env|.env.*) return 0 ;;
  esac
  # BLOCK: keys / certs / credential files
  case "$base" in
    *.pem|*.key|id_rsa|id_dsa|id_ecdsa|id_ed25519|*.p12|*.pfx|*.keystore|*.jks|.npmrc|.netrc|.pgpass|credentials.json|*service-account*.json) return 0 ;;
  esac
  # BLOCK: secret-typed config files
  case "$base" in
    *secret*.json|*secret*.yaml|*secret*.yml|*secret*.env|*secrets*.json|*secrets*.yaml|*secrets*.yml) return 0 ;;
  esac
  # BLOCK: well-known secret paths
  case "$p" in
    */.ssh/*|*/.aws/credentials|*/.gnupg/*) return 0 ;;
  esac
  return 1
}

# Glob detector: conservative substring scan (Glob does NOT respect .gitignore).
is_secret_glob() {
  g="$1"
  [ -n "$g" ] || return 1
  case "$g" in
    *.example|*.sample|*.template|*.dist) return 1 ;;
  esac
  case "$g" in
    *.env|*.env.*|*.env*|*.pem|*.key|*id_rsa*|*id_ed25519*|*.p12|*.pfx|*.keystore|*.jks|*.npmrc|*credential*|*/.ssh/*|*/.aws/*|*service-account*|*secret*) return 0 ;;
  esac
  return 1
}

FILE_PATH="$(json_get 'tool_input.file_path')"   # Read target; Grep scope
GLOB="$(json_get 'tool_input.glob')"             # Glob pattern

if is_secret_path "$FILE_PATH"; then
  deny "Do-Me-Coding blocked $TOOL_NAME of a secret-bearing path ($FILE_PATH). Reading secrets is off-limits; inventory secret files by filename only."
fi

if is_secret_glob "$GLOB"; then
  deny "Do-Me-Coding blocked a $TOOL_NAME pattern targeting secret-bearing files ($GLOB). Narrow to non-secret paths; do not enumerate secret file contents."
fi

exit 0
