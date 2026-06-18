#!/usr/bin/env bash
# Do-Me-Coding host uninstaller (v0.1.3) — reverses dmc-install.sh.
# Usage: dmc-uninstall.sh <host-repo-path> [--dry-run]
# Removes DMC-copied files, the appended .gitignore block, and DMC hook entries from settings.json.
# Leaves host product files untouched. For a throwaway-branch install, deleting the branch is simpler.
set -u
HOST=""; DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    -h|--help) sed -n '2,5p' "$0"; exit 0 ;;
    *) HOST="$1" ;;
  esac; shift
done
[ -n "$HOST" ] && [ -d "$HOST" ] || { echo "ERROR: valid host repo path required" >&2; exit 2; }
HOST="$(cd "$HOST" && pwd)"
say(){ printf '%s\n' "$*"; }
rm_(){ if [ "$DRY" = 1 ]; then say "  [dry-run] rm $1"; else rm -rf "$HOST/$1" 2>/dev/null; say "  rm $1"; fi; }

say "Do-Me-Coding uninstall$( [ "$DRY" = 1 ] && echo ' (DRY-RUN)') from: $HOST"
say "Remove DMC-installed files (host product untouched):"
for h in pre-tool-guard scope-guard stop-verify-gate evidence-log dmc-router secret-guard worker-context-guard; do rm_ ".claude/hooks/$h.sh"; done
rm_ ".claude/hooks/worker-result-check.py"; rm_ ".claude/hooks/lib/secret-paths.sh"
for s in dmc-critic dmc-init-deep dmc-on dmc-off dmc-plan-hard dmc-start-work dmc-status dmc-ultrawork dmc-verify-hard dmc-worker-plan dmc-worker-dispatch dmc-worker-import dmc-worker-review dmc-worker-status dmc-worker-cancel; do rm_ ".claude/skills/$s"; done
for a in critic executor explorer planner verifier; do rm_ ".claude/agents/$a.md"; done
for d in DMC.md PLAN_SCHEMA.md RUN_SCHEMA.md VERIFICATION_SCHEMA.md WORKER_TASK_SCHEMA.md WORKER_RESULT_SCHEMA.md WORKER_REVIEW_SCHEMA.md docs/OMC_COEXISTENCE.md docs/HOST_REPO_ARTIFACT_POLICY.md docs/HOST_REPO_ADAPTATION_POLICY.md .harness/mode; do rm_ "$d"; done
say "  (left in place: host CLAUDE.md/settings.json/.gitignore — DMC-appended sections removed below)"

# Remove appended .gitignore block (between the marker and EOF added by installer)
GI_MARK="# Do-Me-Coding transient + working state (host repo: local-only by default)"
if [ -f "$HOST/.gitignore" ] && grep -qF "$GI_MARK" "$HOST/.gitignore"; then
  if [ "$DRY" = 1 ]; then say "  [dry-run] strip DMC .gitignore block"; else
    python3 - "$HOST/.gitignore" "$GI_MARK" <<'PY' && say "  stripped DMC .gitignore block"
import sys
p,mark=sys.argv[1],sys.argv[2]
lines=open(p).read().splitlines()
out=[]; skip=False
for ln in lines:
    if ln.strip()==mark.strip(): skip=True; continue
    out.append(ln)
# also drop trailing DMC lines that followed the marker (.harness/.., .env entries we added)
open(p,"w").write("\n".join(out).rstrip()+"\n")
PY
  fi
fi

# Remove DMC hook entries from settings.json (by command path); drop empty events
if [ -f "$HOST/.claude/settings.json" ]; then
  if [ "$DRY" = 1 ]; then say "  [dry-run] strip DMC hook entries from settings.json"; else
    python3 - "$HOST/.claude/settings.json" <<'PY' && say "  stripped DMC hooks from settings.json"
import json,sys
p=sys.argv[1]
try: d=json.load(open(p))
except Exception: sys.exit(0)
def is_dmc(entry):
    return any('/.claude/hooks/' in (hk.get('command','')) and any(n in hk.get('command','') for n in
        ['pre-tool-guard','scope-guard','stop-verify-gate','evidence-log','dmc-router','secret-guard'])
        for hk in entry.get('hooks',[]))
h=d.get('hooks',{})
for ev in list(h.keys()):
    h[ev]=[e for e in h[ev] if not is_dmc(e)]
    if not h[ev]: del h[ev]
if not h and 'hooks' in d: del d['hooks']
json.dump(d,open(p,'w'),indent=2); open(p,'a').write('\n')
PY
  fi
fi

say "Done${DRY:+ (dry-run)}. Note: empty .claude/.harness dirs may remain; remove manually if desired."
say "Simplest full rollback for a pilot install: 'git checkout main && git branch -D <pilot-branch>'."
