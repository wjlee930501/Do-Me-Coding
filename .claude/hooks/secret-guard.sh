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

# Superset tool_input keys (robust to harness key drift). PATH/GLOB-STRING decisions ONLY — this
# guard never opens or reads the target, so it cannot itself leak a secret. Matching is
# case-insensitive: a lowercased COPY is fed to the detectors, whose bodies stay byte-identical to
# lib/secret-paths.sh (md5-identity check). The original value is shown in the deny reason.
FILE_PATH="$(json_get 'tool_input.file_path')"         # Read target
PATH_DIR="$(json_get 'tool_input.path')"               # Grep/Glob search directory
GLOB="$(json_get 'tool_input.glob')"                   # Glob pattern (this harness' key)
PATTERN="$(json_get 'tool_input.pattern')"             # Glob pattern (other harness' key) / Grep regex

lower() { printf '%s' "$1" | tr 'A-Z' 'a-z'; }

# Path-shaped keys -> path detector (case-insensitive). file_path/path both select a concrete file or
# directory, so a path-block is correct and precise. (Notebook tools are intentionally not covered:
# the tool-name gate + settings matcher are Read|Grep|Glob, and settings.json wiring is out of M6 scope.)
for _spec in "file_path=$FILE_PATH" "path=$PATH_DIR"; do
  _key="${_spec%%=*}"; _val="${_spec#*=}"
  [ -n "$_val" ] || continue
  if is_secret_path "$(lower "$_val")"; then
    deny "Do-Me-Coding blocked $TOOL_NAME of a secret-bearing path ($_val via $_key). Reading secrets is off-limits; inventory secret files by filename only."
  fi
done

# Glob-shaped keys -> glob detector (case-insensitive). `glob` is always a path glob. `pattern` is a
# path glob ONLY under Glob; under Grep it is a content regex, so it is NOT glob-checked there (that
# would deny legitimate code searches for words like "secret"). Grep's directory (path) is covered above.
if is_secret_glob "$(lower "$GLOB")"; then
  deny "Do-Me-Coding blocked a $TOOL_NAME pattern targeting secret-bearing files ($GLOB). Narrow to non-secret paths; do not enumerate secret file contents."
fi
if [ "$TOOL_NAME" = "Glob" ] && is_secret_glob "$(lower "$PATTERN")"; then
  deny "Do-Me-Coding blocked a $TOOL_NAME pattern targeting secret-bearing files ($PATTERN). Narrow to non-secret paths; do not enumerate secret file contents."
fi

exit 0
