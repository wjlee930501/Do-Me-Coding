#!/usr/bin/env bash
# Do-Me-Coding host uninstaller (v1.0) — reverses dmc-install.sh; provenance-scoped (M8).
# Usage: dmc-uninstall.sh <host-repo-path> [--dry-run]
# Reads <host>/.harness/install-receipt.json (created_paths/merged_targets) to remove exactly what
# was installed; falls back to fixed-name Ring-0 removal (warned) if the receipt is absent.
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
rmdir_(){ if [ "$DRY" = 1 ]; then say "  [dry-run] rmdir $1 (if empty)"; else rmdir "$HOST/$1" 2>/dev/null && say "  rmdir $1 (empty)"; fi; return 0; }
# strip_markers <file> <begin-marker-line> <end-marker-line>
# Removes every line from an exact BEGIN-marker line through the next exact END-marker line
# (inclusive), plus contiguous blank separator lines immediately before/after the block, and
# byte-preserves everything else including the file's trailing-newline state. Prints REMOVED/NOOP.
strip_markers(){
  python3 - "$1" "$2" "$3" <<'PY'
import sys
path, begin, end = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    text = open(path, 'r').read()
except Exception:
    print('NOOP'); sys.exit(0)
lines = text.splitlines(keepends=True)
def is_blank(s): return s.strip('\r\n') == ''
out = []; removed = False; i = 0; n = len(lines)
while i < n:
    if lines[i].strip() == begin:
        removed = True
        while out and is_blank(out[-1]):
            out.pop()
        j = i + 1
        while j < n and lines[j].strip() != end:
            j += 1
        i = j + 1
        while i < n and is_blank(lines[i]):
            i += 1
        continue
    out.append(lines[i]); i += 1
open(path, 'w').write(''.join(out))
print('REMOVED' if removed else 'NOOP')
PY
}

say "Do-Me-Coding uninstall$( [ "$DRY" = 1 ] && echo ' (DRY-RUN)') from: $HOST"

CLAUDE_BEGIN='<!-- DMC:BEGIN -->'; CLAUDE_END='<!-- DMC:END -->'
GI_BEGIN='# DMC:BEGIN'; GI_END='# DMC:END'
SENTINEL_CONTENT='# DMC-CREATED'
RECEIPT_REL=".harness/install-receipt.json"
RECEIPT_PATH="$HOST/$RECEIPT_REL"

# ---- legacy .claude surface (M6/M6.5-owned; frozen, unconditionally shipped by --host claude) ----
say "Remove DMC-installed .claude surface (host product untouched):"
for h in pre-tool-guard scope-guard stop-verify-gate evidence-log dmc-router secret-guard worker-context-guard; do rm_ ".claude/hooks/$h.sh"; done
rm_ ".claude/hooks/worker-result-check.py"; rm_ ".claude/hooks/lib/secret-paths.sh"
for s in dmc-critic dmc-init-deep dmc-on dmc-off dmc-plan-hard dmc-start-work dmc-status dmc-ultrawork dmc-verify-hard dmc-worker-plan dmc-worker-dispatch dmc-worker-import dmc-worker-review dmc-worker-status dmc-worker-cancel; do rm_ ".claude/skills/$s"; done
for a in critic executor explorer planner verifier; do rm_ ".claude/agents/$a.md"; done
rm_ ".claude/workers/providers/glm-api"
for d in DMC.md PLAN_SCHEMA.md RUN_SCHEMA.md VERIFICATION_SCHEMA.md WORKER_TASK_SCHEMA.md WORKER_RESULT_SCHEMA.md WORKER_REVIEW_SCHEMA.md docs/OMC_COEXISTENCE.md docs/HOST_REPO_ARTIFACT_POLICY.md docs/HOST_REPO_ADAPTATION_POLICY.md .harness/mode; do rm_ "$d"; done

# ---- M8 Ring-0 + adapters/.agents-skills-mirror + .codex: provenance-scoped removal ----
say "Remove DMC-installed Ring-0 / adapter surface (provenance-scoped):"
RECEIPT_PRESENT=0; RECEIPT_VALID=0; CREATED_LIST=""; MERGED_LIST=""
if [ -f "$RECEIPT_PATH" ]; then
  RECEIPT_PRESENT=1
  RECEIPT_DUMP="$(python3 - "$RECEIPT_PATH" <<'PY' 2>/dev/null
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    created = d.get('created_paths') or []
    merged = d.get('merged_targets') or []
    if not isinstance(created, list) or not isinstance(merged, list):
        raise ValueError('bad shape')
except Exception:
    sys.exit(3)
for p in created:
    print('C\t' + str(p))
for p in merged:
    print('M\t' + str(p))
PY
)"
  if [ $? -eq 0 ]; then
    RECEIPT_VALID=1
    CREATED_LIST="$(printf '%s\n' "$RECEIPT_DUMP" | awk -F'\t' '$1=="C"{print $2}')"
    MERGED_LIST="$(printf '%s\n' "$RECEIPT_DUMP" | awk -F'\t' '$1=="M"{print $2}')"
  fi
fi

if [ "$RECEIPT_VALID" = 1 ]; then
  say "  install receipt found — removing recorded created_paths only"
  printf '%s\n' "$CREATED_LIST" | while IFS= read -r p; do
    [ -n "$p" ] || continue
    case "$p" in
      .codex/*|CLAUDE.md|.gitignore|.claude/settings.json) continue ;;
    esac
    rm_ "$p"
  done
else
  if [ "$RECEIPT_PRESENT" = 1 ]; then
    say "  WARNING: install receipt present but malformed/unreadable — falling back to fixed-name Ring-0 removal"
  else
    say "  WARNING: install receipt absent ($RECEIPT_REL not found) — falling back to fixed-name removal of the unconditionally-shipped Ring-0 surface. This fallback does NOT remove .codex (removed only via its .dmc-created sentinel signal) and cannot distinguish a host's own bin/lib or .agents/skills files that happen to share the dmc- naming prefix (documented residual)."
  fi
  rm_ "bin/dmc"
  for f in "$HOST"/bin/lib/dmc-*; do [ -e "$f" ] || continue; rm_ "bin/lib/$(basename "$f")"; done
  for j in roles models harness-matrix; do rm_ "orchestration/$j.json"; done
  rm_ "adapters/codex"
  for s in dmc-critic dmc-plan-hard dmc-start-work dmc-status dmc-verify-hard; do rm_ ".agents/skills/$s"; done
fi

# ---- .codex: signal-gated only (sentinel present, or receipt-recorded); a foreign .codex is never touched ----
CODEX_SIGNAL=0
if [ -f "$HOST/.codex/.dmc-created" ]; then
  SC="$(cat "$HOST/.codex/.dmc-created" 2>/dev/null)"
  [ "$SC" = "$SENTINEL_CONTENT" ] && CODEX_SIGNAL=1
fi
if [ "$RECEIPT_VALID" = 1 ] && printf '%s\n' "$CREATED_LIST" | grep -q '^\.codex/'; then
  CODEX_SIGNAL=1
fi
if [ "$CODEX_SIGNAL" = 1 ]; then
  say "  .codex DMC signal detected — removing DMC-owned .codex files (sentinel removed last)"
  if [ "$RECEIPT_VALID" = 1 ]; then
    printf '%s\n' "$CREATED_LIST" | while IFS= read -r p; do
      case "$p" in
        .codex/.dmc-created) continue ;;
        .codex/*) rm_ "$p" ;;
      esac
    done
  else
    rm_ ".codex/config.toml"
    rm_ ".codex/hooks.json"
  fi
  rm_ ".codex/.dmc-created"
  rmdir_ ".codex"
elif [ -d "$HOST/.codex" ]; then
  say "  .codex present but no DMC signal — leaving untouched (foreign)"
fi

for d in bin/lib bin orchestration adapters/codex adapters .agents/skills .agents; do rmdir_ "$d"; done

# ---- CLAUDE.md: paired HTML markers; created ⇒ remove file, merged ⇒ strip section only ----
say "Restore merge targets (CLAUDE.md / .gitignore / settings.json):"
CLAUDE_CREATED=0
if [ "$RECEIPT_VALID" = 1 ] && printf '%s\n' "$CREATED_LIST" | grep -qxF "CLAUDE.md"; then CLAUDE_CREATED=1; fi
if [ "$CLAUDE_CREATED" = 1 ]; then
  rm_ "CLAUDE.md"
elif [ -f "$HOST/CLAUDE.md" ] && grep -qF "$CLAUDE_BEGIN" "$HOST/CLAUDE.md" 2>/dev/null; then
  if [ "$DRY" = 1 ]; then say "  [dry-run] strip DMC section from CLAUDE.md"; else
    RES="$(strip_markers "$HOST/CLAUDE.md" "$CLAUDE_BEGIN" "$CLAUDE_END")"
    say "  stripped DMC section from CLAUDE.md ($RES)"
    if [ "$RECEIPT_VALID" != 1 ] && ! [ -s "$HOST/CLAUDE.md" ]; then
      say "  NOTE: CLAUDE.md is now empty and no receipt was available to confirm provenance — left in place (honest residual)"
    fi
  fi
fi

GI_CREATED=0
if [ "$RECEIPT_VALID" = 1 ] && printf '%s\n' "$CREATED_LIST" | grep -qxF ".gitignore"; then GI_CREATED=1; fi
if [ "$GI_CREATED" = 1 ]; then
  rm_ ".gitignore"
elif [ -f "$HOST/.gitignore" ] && grep -qF "$GI_BEGIN" "$HOST/.gitignore" 2>/dev/null; then
  if [ "$DRY" = 1 ]; then say "  [dry-run] strip DMC block from .gitignore"; else
    RES="$(strip_markers "$HOST/.gitignore" "$GI_BEGIN" "$GI_END")"
    say "  stripped DMC block from .gitignore ($RES)"
  fi
fi

SETTINGS_CREATED=0
if [ "$RECEIPT_VALID" = 1 ] && printf '%s\n' "$CREATED_LIST" | grep -qxF ".claude/settings.json"; then SETTINGS_CREATED=1; fi
if [ "$SETTINGS_CREATED" = 1 ]; then
  rm_ ".claude/settings.json"
elif [ -f "$HOST/.claude/settings.json" ]; then
  if [ "$DRY" = 1 ]; then say "  [dry-run] strip DMC hook entries from settings.json"; else
    python3 - "$HOST/.claude/settings.json" <<'PY' && say "  stripped DMC hooks from settings.json"
import json, sys
p = sys.argv[1]
try: d = json.load(open(p))
except Exception: sys.exit(0)
def is_dmc(entry):
    return any('/.claude/hooks/' in (hk.get('command', '')) and any(n in hk.get('command', '') for n in
        ['pre-tool-guard', 'scope-guard', 'stop-verify-gate', 'evidence-log', 'dmc-router', 'secret-guard', 'worker-context-guard'])
        for hk in entry.get('hooks', []))
h = d.get('hooks', {})
for ev in list(h.keys()):
    h[ev] = [e for e in h[ev] if not is_dmc(e)]
    if not h[ev]: del h[ev]
if not h and 'hooks' in d: del d['hooks']
json.dump(d, open(p, 'w'), indent=2); open(p, 'a').write('\n')
PY
  fi
fi

# ---- install receipt: removed LAST (a mid-abort re-run is safe — it re-reads the same receipt) ----
if [ -f "$RECEIPT_PATH" ]; then
  rm_ "$RECEIPT_REL"
else
  say "  (no install receipt to remove)"
fi

say ""
if [ "$DRY" = 1 ]; then say "Done (dry-run — nothing written)."; else say "Done."; fi
say "Note: empty .harness/{decisions,evidence,memory,plans,runs,verification,workers} .gitkeep dirs may remain; remove manually if desired."
say "Simplest full rollback for a pilot install: 'git checkout main && git branch -D <pilot-branch>'."
