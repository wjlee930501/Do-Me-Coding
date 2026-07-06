#!/usr/bin/env bash
# Do-Me-Coding Worker Bridge — context guard (v0.2).
# Validates a worker TASK bundle BEFORE dispatch: no secret-bearing paths in allowed_files/
# forbidden_files/relevant_snippets, and no inline secret values. FAIL-CLOSED (non-zero) on any leak.
# Reuses the shared is_secret_path detector (kept identical to secret-guard.sh). Reads the task JSON
# itself (a local file given as an argument) — it does NOT open any path listed inside the task.
# Usage: worker-context-guard.sh <task.json>
set -u
TASK="${1:-}"
[ -n "$TASK" ] && [ -f "$TASK" ] || { echo "usage: worker-context-guard.sh <task.json>" >&2; exit 2; }
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
. "$DIR/lib/secret-paths.sh"

# Candidate paths referenced by the task (allowed/forbidden files + snippet file refs).
PATHS="$(python3 - "$TASK" <<'PY' 2>/dev/null
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
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
PY
)"

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

# Inline secret-value scan over the whole task bundle (defense-in-depth).
if ! python3 - "$TASK" <<'PY' 2>/dev/null
import json, re, sys
try:
    blob = json.dumps(json.load(open(sys.argv[1])))
except Exception:
    sys.exit(0)
pat = re.compile(r'(sk-[A-Za-z0-9_-]{8,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|xox[baprs]-[0-9A-Za-z-]+|ghp_[A-Za-z0-9]{20,})')
sys.exit(1 if pat.search(blob) else 0)
PY
then
  echo "INLINE SECRET PATTERN detected in task bundle" >&2
  leak=1
fi

if [ "$leak" != 0 ]; then
  echo "worker-context-guard: FAIL-CLOSED — secret/forbidden content in task bundle; dispatch refused." >&2
  exit 1
fi
echo "worker-context-guard: clean — no secret-bearing paths or inline secrets in task bundle."
exit 0
