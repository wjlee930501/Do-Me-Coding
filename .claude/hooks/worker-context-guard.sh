#!/usr/bin/env bash
# Do-Me-Coding Worker Bridge — context guard (v0.2; M7-hardened).
# Validates a worker TASK bundle BEFORE dispatch: no secret-bearing paths in allowed_files/
# forbidden_files/relevant_snippets, and no inline secret values. FAIL-CLOSED (non-zero) on any leak
# AND on any parse/interpreter/detector-import failure (never a silent exit 0). Reuses the shared
# is_secret_path detector (kept identical to secret-guard.sh) and the shared find_token_material token
# detector (imported EXACTLY from oauth-cli-adapter.py — same single source as worker-result-check.py).
# Reads the task JSON itself (a local file given as an argument) — it does NOT open any path listed
# inside the task.
# Usage: worker-context-guard.sh <task.json>
set -u
TASK="${1:-}"
[ -n "$TASK" ] && [ -f "$TASK" ] || { echo "usage: worker-context-guard.sh <task.json>" >&2; exit 2; }
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
. "$DIR/lib/secret-paths.sh"
OAUTH_SRC="$DIR/../workers/providers/oauth-cli/oauth-cli-adapter.py"

# Candidate paths referenced by the task (allowed/forbidden files + snippet file refs). FAIL-CLOSED:
# a parse failure / non-object task / missing python3 is DISTINGUISHED from "parsed, zero paths" via an
# explicit sentinel line (never 2>/dev/null swallowing).
PATHS_RAW="$(python3 - "$TASK" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    print("__PARSE_FAIL__")
    sys.exit(3)
if not isinstance(d, dict):
    print("__PARSE_FAIL__")
    sys.exit(3)
out = set()
# Only scan paths that are PACKAGED to the worker (allowed_files + snippet refs).
# forbidden_files are exclusions and MAY legitimately name secret paths (e.g. .env.local).
for p in (d.get("allowed_files") or []):
    if isinstance(p, str):
        out.add(p)
for s in (d.get("relevant_snippets") or []):
    if isinstance(s, dict) and isinstance(s.get("file"), str):
        out.add(s["file"])
for p in sorted(out):
    print(p)
print("__PARSE_OK__")
PY
)"
prc=$?
if [ "$prc" != 0 ] || ! printf '%s\n' "$PATHS_RAW" | grep -q '__PARSE_OK__'; then
  echo "worker-context-guard: FAIL-CLOSED — task JSON unparseable, non-object, or python3 unavailable (path-extraction)." >&2
  exit 1
fi
PATHS="$(printf '%s\n' "$PATHS_RAW" | grep -v '__PARSE_OK__')"

leak=0
while IFS= read -r p; do
  [ -n "$p" ] || continue
  if is_secret_path "$p"; then
    echo "SECRET-PATH BLOCKED: $p" >&2
    leak=1
  fi
done <<EOF
$PATHS
EOF

# Inline secret-value scan over the whole task bundle (defense-in-depth). Replaces the old inline
# 5-class regex with the shared find_token_material import (SECRET_VALUE + the six credential-token classes a task must never inline +
# PLACEHOLDER exclusion). FAIL-CLOSED on parse/import/interpreter failure. Value-blind: only detector
# labels are computed; token VALUES are never printed (the guard keeps printing offending PATHS only).
python3 - "$TASK" "$OAUTH_SRC" <<'PY'
import importlib.util, json, sys
sys.dont_write_bytecode = True   # no __pycache__ under the protected providers tree
try:
    spec = importlib.util.spec_from_file_location("dmc_oauth_ctx_guard", sys.argv[2])
    if spec is None or spec.loader is None:
        raise ImportError("no spec/loader for the oauth-cli detector source")
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    find_token_material = m.find_token_material
except Exception:
    print("DETECTOR-IMPORT-FAILED", file=sys.stderr)
    sys.exit(3)
try:
    blob = json.dumps(json.load(open(sys.argv[1])))
except Exception:
    print("TASK-JSON-UNPARSEABLE", file=sys.stderr)
    sys.exit(3)
sys.exit(2 if find_token_material(blob) else 0)
PY
src=$?
case "$src" in
  0) : ;;  # clean
  2) echo "INLINE SECRET PATTERN detected in task bundle" >&2; leak=1 ;;
  *) echo "worker-context-guard: FAIL-CLOSED — inline-secret scan failed (parse/detector-import/python3 unavailable)." >&2; leak=1 ;;
esac

if [ "$leak" != 0 ]; then
  echo "worker-context-guard: FAIL-CLOSED — secret/forbidden content in task bundle; dispatch refused." >&2
  exit 1
fi
echo "worker-context-guard: clean — no secret-bearing paths or inline secrets in task bundle."
exit 0
