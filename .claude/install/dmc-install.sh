#!/usr/bin/env bash
# Do-Me-Coding host installer (v0.1.3) — manifest-driven (see INSTALL_MANIFEST.md).
# Usage: dmc-install.sh <host-repo-path> [--dry-run] [--mode active|passive|off]
# Copies the DMC surface into a host repo, MERGES settings.json/.gitignore/CLAUDE.md (never
# overwrites), detects collisions, picks a default mode, and prints rollback instructions.
set -u

SRC="$(cd "$(dirname "$0")/../.." && pwd)"   # DMC repo root (this script: <root>/.claude/install/)
HOST=""; DRY=0; MODE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --mode) shift; MODE="${1:-}" ;;
    -h|--help) sed -n '2,5p' "$0"; exit 0 ;;
    *) [ -z "$HOST" ] && HOST="$1" || { echo "unexpected arg: $1" >&2; exit 2; } ;;
  esac
  shift
done
[ -n "$HOST" ] || { echo "ERROR: host repo path required" >&2; exit 2; }
[ -d "$HOST" ] || { echo "ERROR: host path not found: $HOST" >&2; exit 2; }
HOST="$(cd "$HOST" && pwd)"

say(){ printf '%s\n' "$*"; }
act(){ if [ "$DRY" = 1 ]; then say "  [dry-run] $*"; else eval "$2"; say "  $1"; fi; }
# act <label> <command-string>

HOOKS="pre-tool-guard.sh scope-guard.sh stop-verify-gate.sh evidence-log.sh dmc-router.sh secret-guard.sh worker-context-guard.sh"
HOOK_EXTRA="worker-result-check.py"                 # extra hook-dir tool (non-.sh)
HOOK_LIB="secret-paths.sh"                          # .claude/hooks/lib/
SKILLS="dmc-critic dmc-init-deep dmc-on dmc-off dmc-plan-hard dmc-start-work dmc-status dmc-ultrawork dmc-verify-hard dmc-worker-plan dmc-worker-dispatch dmc-worker-import dmc-worker-review dmc-worker-status dmc-worker-cancel"
AGENTS="critic.md executor.md explorer.md planner.md verifier.md"
HARNESS_DIRS="decisions evidence memory plans runs verification workers/tasks workers/results workers/reviews workers/sessions"
ROOT_DOCS="DMC.md PLAN_SCHEMA.md RUN_SCHEMA.md VERIFICATION_SCHEMA.md WORKER_TASK_SCHEMA.md WORKER_RESULT_SCHEMA.md WORKER_REVIEW_SCHEMA.md"

# ---- mode detection (Resolved Decision #5) ----
detect_other_harness(){
  for m in .omc .omo .omx .opencode opencode.json .cursor .continue; do [ -e "$HOST/$m" ] && return 0; done
  # non-DMC project settings.json with hooks not pointing at DMC
  if [ -f "$HOST/.claude/settings.json" ] && ! grep -q 'dmc-router.sh\|pre-tool-guard.sh' "$HOST/.claude/settings.json" 2>/dev/null; then return 0; fi
  return 1
}
if [ -z "$MODE" ]; then
  if detect_other_harness; then MODE="passive"; RATIONALE="another agent harness detected (.omc/.omo/.omx/opencode/cursor/non-DMC hooks)"; else MODE="active"; RATIONALE="no other harness detected"; fi
else RATIONALE="explicit --mode"; fi
case "$MODE" in active|passive|off) ;; *) echo "ERROR: bad --mode $MODE" >&2; exit 2 ;; esac

say "Do-Me-Coding install $( [ "$DRY" = 1 ] && echo '(DRY-RUN)')"
say "  source : $SRC"
say "  host   : $HOST"
say "  mode   : $MODE  ($RATIONALE)"
say ""

# ---- collision detection (never overwrite; merge/skip) ----
say "Collision detection:"
for f in CLAUDE.md AGENTS.md .claude/settings.json .gitignore; do
  if [ -e "$HOST/$f" ]; then say "  EXISTS: $f -> will MERGE/append or SKIP (never overwrite)"; else say "  absent: $f -> safe to create"; fi
done
say ""

# ---- copy hooks/skills/agents ----
say "Install .claude surface:"
act "mkdir .claude/{hooks,skills,agents}" "mkdir -p '$HOST/.claude/hooks' '$HOST/.claude/skills' '$HOST/.claude/agents'"
for h in $HOOKS; do act "hook $h" "cp '$SRC/.claude/hooks/$h' '$HOST/.claude/hooks/'"; done
act "hook tool $HOOK_EXTRA" "cp '$SRC/.claude/hooks/$HOOK_EXTRA' '$HOST/.claude/hooks/'"
act "hook lib/$HOOK_LIB" "mkdir -p '$HOST/.claude/hooks/lib' && cp '$SRC/.claude/hooks/lib/$HOOK_LIB' '$HOST/.claude/hooks/lib/'"
for s in $SKILLS; do act "skill $s" "cp -R '$SRC/.claude/skills/$s' '$HOST/.claude/skills/'"; done
for a in $AGENTS; do act "agent $a" "cp '$SRC/.claude/agents/$a' '$HOST/.claude/agents/'"; done

# settings.json: copy if absent; else python-merge DMC hooks (never overwrite host hooks)
if [ ! -f "$HOST/.claude/settings.json" ]; then
  act "settings.json (new)" "cp '$SRC/.claude/settings.json' '$HOST/.claude/settings.json'"
else
  if [ "$DRY" = 1 ]; then say "  [dry-run] MERGE DMC hook entries into existing .claude/settings.json (keep host entries)"; else
    DMC_SRC="$SRC" python3 - "$HOST/.claude/settings.json" "$SRC/.claude/settings.json" <<'PY' && say "  merged DMC hooks into existing settings.json"
import json,sys
host_p,dmc_p=sys.argv[1],sys.argv[2]
host=json.load(open(host_p)); dmc=json.load(open(dmc_p))
hh=host.setdefault("hooks",{})
for ev,entries in dmc.get("hooks",{}).items():
    cur=hh.setdefault(ev,[])
    have=json.dumps(cur)
    for e in entries:
        if json.dumps(e) not in have:
            cur.append(e)
json.dump(host,open(host_p,"w"),indent=2); open(host_p,"a").write("\n")
PY
  fi
fi

# ---- harness skeleton + schemas + mode ----
say "Install .harness skeleton:"
for d in $HARNESS_DIRS; do act ".harness/$d" "mkdir -p '$HOST/.harness/$d' && touch '$HOST/.harness/$d/.gitkeep'"; done
act ".harness/schemas" "mkdir -p '$HOST/.harness/schemas' && cp '$SRC/.harness/schemas/'*.schema.md '$HOST/.harness/schemas/'"
act ".harness/mode=$MODE" "printf '%s\n' '$MODE' > '$HOST/.harness/mode'"

# ---- root docs + bundled support docs (fix dangling refs) ----
say "Install docs/schemas:"
for d in $ROOT_DOCS; do act "$d" "cp '$SRC/$d' '$HOST/$d'"; done
for sd in OMC_COEXISTENCE.md HOST_REPO_ARTIFACT_POLICY.md HOST_REPO_ADAPTATION_POLICY.md; do
  act "docs/$sd (bundled support doc)" "mkdir -p '$HOST/docs' && cp '$SRC/docs/$sd' '$HOST/docs/'"
done
# CLAUDE.md: create if absent, else append a DMC section (collision-safe)
if [ ! -f "$HOST/CLAUDE.md" ]; then
  act "CLAUDE.md (new)" "cp '$SRC/CLAUDE.md' '$HOST/CLAUDE.md'"
else
  if [ "$DRY" = 1 ]; then say "  [dry-run] append DMC section to existing CLAUDE.md (preserve host content)"; else
    { printf '\n\n<!-- Do-Me-Coding (appended by dmc-install) -->\n'; cat "$SRC/CLAUDE.md"; } >> "$HOST/CLAUDE.md"; say "  appended DMC section to existing CLAUDE.md"
  fi
fi
say "  (AGENTS.md deliberately NOT installed — host-specific; use /dmc-init-deep)"

# ---- .gitignore block (host artifacts local-only + secret ignore) ----
GI_MARK="# Do-Me-Coding transient + working state (host repo: local-only by default)"
if [ -f "$HOST/.gitignore" ] && grep -qF "$GI_MARK" "$HOST/.gitignore" 2>/dev/null; then
  say ".gitignore: DMC block already present (skip)"
else
  if [ "$DRY" = 1 ]; then say "  [dry-run] append DMC .gitignore block (host .harness local-only + .env* ignore)"; else
    { printf '\n%s\n' "$GI_MARK";
      printf '%s\n' ".harness/mode" ".harness/runs/current-*" ".harness/evidence/manual-*.md" ".harness/plans/" ".harness/evidence/" ".harness/verification/" ".harness/runs/";
      printf '%s\n' "# Worker Bridge artifacts (host: local-only by default; commit opt-in)" ".harness/workers/tasks/" ".harness/workers/results/" ".harness/workers/reviews/" ".harness/workers/sessions/";
      printf '%s\n' "# Do-Me-Coding: keep secret files out of search/commit (defense-in-depth)" ".env" ".env.*" "!.env.example" "!.env.sample";
    } >> "$HOST/.gitignore"; say "  appended DMC .gitignore block"
  fi
fi

say ""
say "Done${DRY:+ (dry-run — nothing written)}."
say "Mode: $MODE. Override with --mode active|passive|off."
say "Rollback: run .claude/install/dmc-uninstall.sh '$HOST'  (or, if on a throwaway branch, 'git checkout main && git branch -D <pilot-branch>')."
