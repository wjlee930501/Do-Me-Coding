#!/usr/bin/env bash
# Do-Me-Coding host installer (v1.0) — ships Ring-0 (bin/ + orchestration/) and the Ring-1 adapters.
# Usage: dmc-install.sh <host-repo-path> [--host claude|codex|both] [--dry-run] [--mode active|passive|off]
#        dmc-install.sh --emit-manifest        # print the generated INSTALL_MANIFEST.md (no host needed)
# Copies the DMC control plane into a host repo, MERGES settings.json/.gitignore/CLAUDE.md (never
# overwrites, paired markers), records provenance (install receipt + `.codex` sentinel), and prints
# rollback instructions. `--host` defaults to `claude` (today's Claude adapter behavior).
set -u

SRC="$(cd "$(dirname "$0")/../.." && pwd)"   # DMC repo root (this script: <root>/.claude/install/)
NL='
'
HOST=""; DRY=0; MODE=""; HOST_KIND="claude"; EMIT=0
usage(){ sed -n '2,7p' "$0"; }
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --mode) shift; MODE="${1:-}" ;;
    --host) shift; HOST_KIND="${1:-}" ;;
    --emit-manifest) EMIT=1 ;;
    -h|--help) usage; exit 0 ;;
    *) [ -z "$HOST" ] && HOST="$1" || { echo "unexpected arg: $1" >&2; exit 2; } ;;
  esac
  shift
done
case "$HOST_KIND" in claude|codex|both) ;; *) echo "ERROR: bad --host '$HOST_KIND' (want claude|codex|both)" >&2; exit 2 ;; esac

# ============================================================================
# Ship-surface copy lists — the SINGLE SOURCE for both install and --emit-manifest.
# ============================================================================
# Ring-0 (ALL hosts). `dmc-doctor.py` (M8 T013.3) is forward-referenced so the generated manifest is
# byte-stable across the concurrent M8 build; the real copy tolerates its absence during that window.
RING0_LIB_FWD="dmc-doctor.py"
ORCH_FILES="roles.json models.json harness-matrix.json"   # models/harness-matrix land via T013.3 (forward-ref)

# Claude Code adapter (--host claude|both) — the existing surface (behavior unchanged).
HOOKS="pre-tool-guard.sh scope-guard.sh stop-verify-gate.sh evidence-log.sh dmc-router.sh secret-guard.sh worker-context-guard.sh"
HOOK_EXTRA="worker-result-check.py"
HOOK_LIB="secret-paths.sh"
SKILLS="dmc-critic dmc-init-deep dmc-on dmc-off dmc-plan-hard dmc-start-work dmc-status dmc-ultrawork dmc-verify-hard dmc-worker-plan dmc-worker-dispatch dmc-worker-import dmc-worker-review dmc-worker-status dmc-worker-cancel"
AGENTS="critic.md executor.md explorer.md planner.md verifier.md"

# Codex adapter (--host codex|both) — M6.5 surface; the DMC-internal README is deliberately NOT shipped.
CODEX_ADAPTERS="dmc_codex_common.py dmc-codex-pretooluse.py dmc-codex-posttooluse.py dmc-codex-userpromptsubmit.py dmc-codex-stop.py"
CODEX_SKILLS="dmc-critic dmc-plan-hard dmc-start-work dmc-status dmc-verify-hard"
CODEX_WIRING="config.toml hooks.json"

# Common operating surface (ALL hosts).
HARNESS_DIRS="decisions evidence memory plans runs verification workers/tasks workers/results workers/reviews workers/sessions"
ROOT_DOCS="DMC.md PLAN_SCHEMA.md RUN_SCHEMA.md VERIFICATION_SCHEMA.md WORKER_TASK_SCHEMA.md WORKER_RESULT_SCHEMA.md WORKER_REVIEW_SCHEMA.md"
SUPPORT_DOCS="OMC_COEXISTENCE.md HOST_REPO_ARTIFACT_POLICY.md HOST_REPO_ADAPTATION_POLICY.md"

# Provenance (host-side artifacts written by the installer; consumed by dmc-uninstall.sh).
SENTINEL_CONTENT='# DMC-CREATED'
RECEIPT_REL=".harness/install-receipt.json"
CLAUDE_BEGIN='<!-- DMC:BEGIN -->'; CLAUDE_END='<!-- DMC:END -->'
GI_BEGIN='# DMC:BEGIN'

# List helpers (deterministic, LC_ALL=C-sorted) — shared by install + manifest.
ring0_lib_list(){ { ls "$SRC/bin/lib" 2>/dev/null; printf '%s\n' $RING0_LIB_FWD; } | LC_ALL=C sort -u; }
schema_list(){ for f in "$SRC/.harness/schemas/"*.schema.md; do [ -e "$f" ] && basename "$f"; done | LC_ALL=C sort; }
providers_list(){ for p in "$SRC/.claude/workers/providers/"*; do [ -e "$p" ] || continue; b="$(basename "$p")"; if [ -d "$p" ]; then echo "$b/"; else echo "$b"; fi; done | LC_ALL=C sort; }

# The DMC `.gitignore` block (with paired markers) — single source for the append AND the manifest.
print_gitignore_block(){
  cat <<'GIB'
# DMC:BEGIN
# Do-Me-Coding transient + working state (host repo: local-only by default)
.harness/mode
.harness/runs/current-*
.harness/evidence/manual-*.md
.harness/plans/
.harness/evidence/
.harness/verification/
.harness/runs/
.harness/install-receipt.json
# Worker Bridge artifacts (host: local-only by default; commit opt-in)
.harness/workers/tasks/
.harness/workers/results/
.harness/workers/reviews/
.harness/workers/sessions/
.harness/workers/providers/
# Do-Me-Coding: keep secret files out of search/commit (defense-in-depth)
.env
.env.*
!.env.example
!.env.sample
# DMC:END
GIB
}

# ============================================================================
# --emit-manifest — regenerate INSTALL_MANIFEST.md from the copy lists above plus the
# templated constant sections below. Deletion of a safety section cannot pass the drift test
# because the generator re-emits it. Needs SRC only (no host).
# ============================================================================
emit_manifest(){
  cat <<'EOF'
# Do-Me-Coding — Host Install Manifest (v1.0 — generated)

GENERATED by `dmc-install.sh --emit-manifest`; do not hand-edit — re-run the generator after any
ship-surface change (drift is caught by `tests/fixtures/m8/test-manifest-drift.sh`). Single source of
truth for what `dmc-install.sh` copies/merges into a HOST repository, organized by `--host` target.
Every host-operating doc referenced by an installed file resolves to a bundled file (see the
Dangling-reference rule); DMC-internal provenance references are deliberately not shipped.
EOF

  printf '%s\n' "" "## COPY — Ring-0 control plane (ALL hosts)" ""
  printf '%s\n' "### \`bin/\` → \`<host>/bin/\`"
  printf '%s\n' "- \`bin/dmc\`"
  ring0_lib_list | while IFS= read -r f; do printf '%s\n' "- \`bin/lib/$f\`"; done
  printf '%s\n' "" "### \`orchestration/\` → \`<host>/orchestration/\`  (roles.json committed; models.json + harness-matrix.json land via M8 T013.3)"
  for j in $ORCH_FILES; do printf '%s\n' "- \`orchestration/$j\`"; done

  printf '%s\n' "" "## COPY — Claude Code adapter (\`--host claude|both\`, default)" ""
  printf '%s\n' "### Hooks → \`.claude/hooks/\`"
  for h in $HOOKS; do printf '%s\n' "- \`$h\`"; done
  printf '%s\n' "- \`$HOOK_EXTRA\`" "- \`lib/$HOOK_LIB\`"
  printf '%s\n' "" "### Skills → \`.claude/skills/\`"
  for s in $SKILLS; do printf '%s\n' "- \`$s/SKILL.md\`"; done
  printf '%s\n' "" "### Agents → \`.claude/agents/\`"
  for a in $AGENTS; do printf '%s\n' "- \`$a\`"; done
  printf '%s\n' "" "### Provider adapters → \`.claude/workers/providers/\`  (entire tree, copied recursively; mock-first — no live/network call in build/CI)"
  providers_list | while IFS= read -r p; do printf '%s\n' "- \`$p\`"; done

  printf '%s\n' "" "## COPY — Codex adapter (\`--host codex|both\`) — ADVISORY (M6.5 Option A)" ""
  printf '%s\n' "### Adapter executables → \`adapters/codex/\`"
  for c in $CODEX_ADAPTERS; do printf '%s\n' "- \`$c\`"; done
  printf '%s\n' "" "### Workflow-skill mirrors → \`.agents/skills/\`  (the 5 M6.5 skills-mirror set, NOT 1:1 with .claude/skills)"
  for s in $CODEX_SKILLS; do printf '%s\n' "- \`$s/SKILL.md\`"; done
  printf '%s\n' "" "### Codex wiring templates → \`.codex/\`"
  for w in $CODEX_WIRING; do printf '%s\n' "- \`$w\`"; done
  printf '%s\n' "- \`.dmc-created\`  (provenance sentinel; dropped only when DMC creates \`.codex\`; content \`# DMC-CREATED\`; committed, never gitignored)"

  printf '%s\n' "" "## COPY — common operating docs / harness (ALL hosts)" ""
  printf '%s\n' "### Harness skeleton → \`.harness/\`"
  for d in $HARNESS_DIRS; do printf '%s\n' "- \`$d/.gitkeep\`"; done
  printf '%s\n' "- \`mode\`  (written by installer: \`passive\` if another harness detected, else \`active\`)"
  printf '%s\n' "" "### Schemas → \`.harness/schemas/\`  (all \`*.schema.md\`)"
  schema_list | while IFS= read -r sc; do printf '%s\n' "- \`$sc\`"; done
  printf '%s\n' "" "### Root operating docs / schemas"
  for d in $ROOT_DOCS; do printf '%s\n' "- \`$d\`"; done
  printf '%s\n' "- \`CLAUDE.md\`   (MERGE/append if the host has one, paired markers, never blind-overwrite)"
  printf '%s\n' "" "### Referenced support docs (bundled — resolves dangling references)"
  for sd in $SUPPORT_DOCS; do printf '%s\n' "- \`docs/$sd\`"; done

  cat <<'EOF'

## MERGE (never overwrite; collision-detected)
- `.claude/settings.json` — merge DMC hook arrays into any existing host file (host entries kept).
- `.gitignore` — append the DMC block below, wrapped in `# DMC:BEGIN` … `# DMC:END` (idempotent).
- `CLAUDE.md` — append the DMC section wrapped in `<!-- DMC:BEGIN -->` … `<!-- DMC:END -->` if the
  host already has one (idempotent: skipped when the BEGIN marker is present). A freshly created
  `CLAUDE.md` / `.gitignore` / `.claude/settings.json` is recorded in the install receipt's
  `created_paths` (removed whole on uninstall); a merged one is recorded in `merged_targets` (only the
  marked block is stripped on uninstall).

## Provenance — install receipt + `.codex` sentinel
- `.harness/install-receipt.json` — rewritten deterministically each install run:
  `{"created_paths":[...],"merged_targets":[...]}`. `created_paths` lists every path DMC CREATED
  (`bin/dmc`, each shipped `bin/lib/*`, `orchestration/*.json`, the Codex adapter files,
  `.agents/skills/dmc-*`, `.codex/*` incl. the sentinel, and any of `CLAUDE.md` / `.gitignore` /
  `.claude/settings.json` DMC created from scratch); `merged_targets` lists files DMC appended-into.
  The receipt is HOST-LOCAL (added to the DMC `.gitignore` block) and removed LAST by the uninstaller.
  Fixed-name fallback when the receipt is absent (what the uninstaller removes): `bin/dmc`,
  `bin/lib/dmc-*`, `orchestration/{roles,models,harness-matrix}.json`, `adapters/codex/*`,
  `.agents/skills/{dmc-critic,dmc-plan-hard,dmc-start-work,dmc-status,dmc-verify-hard}`.
- `.codex/.dmc-created` — provenance sentinel (exact content `# DMC-CREATED`) dropped ONLY when the
  installer creates `.codex` from templates on a host that had none. COMMITTED alongside `.codex`
  (NEVER gitignored) so provenance survives a fresh clone. A pre-existing `.codex` WITHOUT this signal
  is FOREIGN ⇒ skip-with-warn (never overwritten); WITH it ⇒ DMC-owned ⇒ idempotent re-affirm.
EOF

  printf '%s\n' "" "## \`.gitignore\` block appended to the host" '```'
  print_gitignore_block
  printf '%s\n' '```' "(Committing host \`.harness\` working artifacts is opt-in; teams may un-ignore specific records.)"

  cat <<'EOF'

## DELIBERATELY NOT COPIED
- `AGENTS.md` — DMC's own describes the DMC scaffold repo and would inject false project memory into a
  host (`docs/HOST_REPO_ADAPTATION_POLICY.md`). Generate a host-specific one with `dmc agents-md` when
  wanted; never auto-imposed.
- `adapters/codex/README.md` and any `adapters/*/README.md` — DMC-internal adapter documentation. They
  cite DMC working artifacts (`docs/CODEX_ADAPTER.md`, `.harness/evidence/dmc-v1-m6.5-spike-*.md`) that
  are NOT shipped. Host Codex operating guidance comes from a generated `AGENTS.md` + the bundled
  `docs/HOST_REPO_ADAPTATION_POLICY.md`, never from these READMEs.
- DMC project-knowledge / design docs: `docs/NOTION_EXPORT_SUMMARY.md`, `docs/SOURCE_URLS.md`,
  `docs/COMPETITIVE_GAP_LEDGER.md`, `docs/DMC_REAL_REPO_PILOT_REPORT.md`, `docs/CODEX_ADAPTER.md`,
  `docs/DMC_V1_RUNTIME_ARCHITECTURE.md`, `INSTALL_MANIFEST.md`, `_DMC_*.md`  (note: `docs/OMC_COEXISTENCE.md`
  and `docs/HOST_REPO_*.md` ARE bundled — installed `DMC.md` references them).
- DMC working artifacts: `.harness/plans/*`, `.harness/evidence/*`, `.harness/verification/*`,
  `.harness/decisions/*`, `.harness/memory/*`, `.harness/runs/*` (host gets an empty skeleton only).
- `.claude/install/*` (the installer / uninstaller scripts themselves).

## Dangling-reference rule
After a (dry-run) install, every `*.md` path an installed file references AS A HOST-OPERATING
DEPENDENCY must resolve to a bundled file:
- support docs referenced by installed `DMC.md` / `CLAUDE.md` — `docs/OMC_COEXISTENCE.md`,
  `docs/HOST_REPO_ARTIFACT_POLICY.md`, `docs/HOST_REPO_ADAPTATION_POLICY.md` — ARE bundled;
- schema / doc references from installed workflow skills — `PLAN_SCHEMA.md` and
  `.harness/schemas/*.schema.md` (e.g. `critic-verdict.schema.md`) — ARE bundled (every `*.schema.md`
  ships).
DMC-INTERNAL PROVENANCE references are deliberately NOT shipped and are NOT operating dependencies:
the shipped Codex adapter executables/templates and workflow-skill mirrors cite `docs/CODEX_ADAPTER.md`,
`.harness/evidence/dmc-v1-m6.5-spike-*.md`, and `adapters/codex/README.md` only as provenance
breadcrumbs (why the code is shaped this way). A host never navigates to them; Codex operating guidance
is the generated `AGENTS.md` + bundled `HOST_REPO_ADAPTATION_POLICY.md`. The scan FAILS only on an
unresolved reference OUTSIDE this enumerated DMC-internal provenance set.
EOF
}

if [ "$EMIT" = 1 ]; then emit_manifest; exit 0; fi

# ============================================================================
# Install path — from here a host is required.
# ============================================================================
[ -n "$HOST" ] || { echo "ERROR: host repo path required" >&2; exit 2; }
[ -d "$HOST" ] || { echo "ERROR: host path not found: $HOST" >&2; exit 2; }
HOST="$(cd "$HOST" && pwd)"

say(){ printf '%s\n' "$*"; }
# act <label> <cmd> [args...] — runs argv directly (no eval); safe for host paths with spaces,
# single-quotes, or shell metacharacters. Prints the label; warns on failure without aborting.
act(){ _l="$1"; shift; if [ "$DRY" = 1 ]; then say "  [dry-run] $_l"; return 0; fi; if "$@"; then say "  $_l"; else say "  ! FAILED: $_l" >&2; return 1; fi; }
mk_gitkeep(){ mkdir -p "$1" && touch "$1/.gitkeep"; }
write_line(){ printf '%s\n' "$1" > "$2"; }

# Provenance accumulators (host-relative paths). Sorted/uniqued when the receipt is written.
CREATED=''; MERGED=''
record_created(){ CREATED="${CREATED}${1}${NL}"; }
record_merged(){ MERGED="${MERGED}${1}${NL}"; }

# Prior-receipt classification: on a re-install, a merge target (CLAUDE.md/.gitignore/settings.json)
# that DMC created from scratch must stay classified `created` (removed whole on uninstall), and a
# merged one must stay `merged` (only the marked block stripped). We read the previous run's receipt
# so an idempotent re-run preserves that distinction instead of downgrading created->merged.
PRIOR_CREATED=''
if [ -f "$HOST/$RECEIPT_REL" ]; then
  PRIOR_CREATED="$(python3 - "$HOST/$RECEIPT_REL" <<'PY'
import json,sys
try: c=json.load(open(sys.argv[1])).get('created_paths') or []
except Exception: c=[]
print("\n".join(str(x) for x in c))
PY
)"
fi
was_created(){ printf '%s\n' "$PRIOR_CREATED" | grep -qxF "$1"; }

# ship_file <src-abs> <host-rel> — copy one M8 Ring-0/adapter file and record it in created_paths.
ship_file(){
  _src="$1"; _rel="$2"
  if [ "$DRY" = 1 ]; then say "  [dry-run] ship $_rel"; return 0; fi
  if [ ! -e "$_src" ]; then say "  ! source absent (tolerated this build window): $_rel" >&2; return 0; fi
  _dst="$HOST/$_rel"
  mkdir -p "$(dirname "$_dst")" && cp "$_src" "$_dst" && { record_created "$_rel"; say "  ship $_rel"; }
}
# ship_dir <src-abs-dir> <host-rel-dir> — copy one M8 directory (e.g. a skill mirror) and record it.
ship_dir(){
  _src="$1"; _rel="$2"
  if [ "$DRY" = 1 ]; then say "  [dry-run] ship $_rel/"; return 0; fi
  if [ ! -d "$_src" ]; then say "  ! source dir absent (tolerated this build window): $_rel" >&2; return 0; fi
  _dst="$HOST/$_rel"
  mkdir -p "$(dirname "$_dst")" && cp -R "$_src" "$_dst" && { record_created "$_rel"; say "  ship $_rel/"; }
}

# ---- mode detection (Resolved Decision #5) ----
detect_other_harness(){
  for m in .omc .omo .omx .opencode opencode.json .cursor .continue; do [ -e "$HOST/$m" ] && return 0; done
  if [ -f "$HOST/.claude/settings.json" ] && ! grep -q 'dmc-router.sh\|pre-tool-guard.sh' "$HOST/.claude/settings.json" 2>/dev/null; then return 0; fi
  return 1
}
if [ -z "$MODE" ]; then
  if detect_other_harness; then MODE="passive"; RATIONALE="another agent harness detected (.omc/.omo/.omx/opencode/cursor/non-DMC hooks)"; else MODE="active"; RATIONALE="no other harness detected"; fi
else RATIONALE="explicit --mode"; fi
case "$MODE" in active|passive|off) ;; *) echo "ERROR: bad --mode $MODE" >&2; exit 2 ;; esac

if [ "$DRY" = 1 ]; then say "Do-Me-Coding install (DRY-RUN)"; else say "Do-Me-Coding install"; fi
say "  source : $SRC"
say "  host   : $HOST"
say "  target : --host $HOST_KIND"
say "  mode   : $MODE  ($RATIONALE)"
say ""

# ---- collision detection (never overwrite; merge/skip) ----
say "Collision detection:"
for f in CLAUDE.md AGENTS.md .claude/settings.json .gitignore; do
  if [ -e "$HOST/$f" ]; then say "  EXISTS: $f -> will MERGE/append or SKIP (never overwrite)"; else say "  absent: $f -> safe to create"; fi
done
say ""

# ---- Ring-0 control plane (ALL hosts): bin/ + orchestration/ ----
say "Install Ring-0 control plane (bin/ + orchestration/):"
ship_file "$SRC/bin/dmc" "bin/dmc"
for f in $(ring0_lib_list); do ship_file "$SRC/bin/lib/$f" "bin/lib/$f"; done
for j in $ORCH_FILES; do ship_file "$SRC/orchestration/$j" "orchestration/$j"; done

# ---- Claude Code adapter (--host claude|both) ----
if [ "$HOST_KIND" = claude ] || [ "$HOST_KIND" = both ]; then
  say "Install Claude Code adapter (.claude surface):"
  act "mkdir .claude/{hooks,skills,agents}" mkdir -p "$HOST/.claude/hooks" "$HOST/.claude/skills" "$HOST/.claude/agents"
  for h in $HOOKS; do act "hook $h" cp "$SRC/.claude/hooks/$h" "$HOST/.claude/hooks/"; done
  act "hook tool $HOOK_EXTRA" cp "$SRC/.claude/hooks/$HOOK_EXTRA" "$HOST/.claude/hooks/"
  act "mkdir .claude/hooks/lib" mkdir -p "$HOST/.claude/hooks/lib"
  act "hook lib/$HOOK_LIB" cp "$SRC/.claude/hooks/lib/$HOOK_LIB" "$HOST/.claude/hooks/lib/"
  for s in $SKILLS; do act "skill $s" cp -R "$SRC/.claude/skills/$s" "$HOST/.claude/skills/"; done
  if [ -d "$SRC/.claude/workers/providers" ]; then
    act "mkdir .claude/workers" mkdir -p "$HOST/.claude/workers"
    act "provider adapters .claude/workers/providers/" cp -R "$SRC/.claude/workers/providers" "$HOST/.claude/workers/"
    # The whole providers tree is DMC-created; record it so uninstall removes it all (the uninstaller's
    # fixed-name list only names glm-api). Recorded as the dir so a host's own .claude/workers stays.
    [ "$DRY" = 1 ] || record_created ".claude/workers/providers"
  fi
  for a in $AGENTS; do act "agent $a" cp "$SRC/.claude/agents/$a" "$HOST/.claude/agents/"; done

  # settings.json: copy if absent (record created); else python-merge DMC hooks (record merged)
  if [ ! -f "$HOST/.claude/settings.json" ]; then
    act "settings.json (new)" cp "$SRC/.claude/settings.json" "$HOST/.claude/settings.json"
    [ "$DRY" = 1 ] || record_created ".claude/settings.json"
  else
    if [ "$DRY" = 1 ]; then say "  [dry-run] MERGE DMC hook entries into existing .claude/settings.json (keep host entries)"; else
      if was_created ".claude/settings.json"; then record_created ".claude/settings.json"; else record_merged ".claude/settings.json"; fi
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
fi

# ---- Codex adapter (--host codex|both) — ADVISORY (M6.5 Option A) ----
install_codex_wiring(){
  _sentinel="$HOST/.codex/.dmc-created"
  _cfg="$HOST/.codex/config.toml"; _hooks="$HOST/.codex/hooks.json"
  _signal=0
  if [ -f "$_sentinel" ] && [ "$(cat "$_sentinel" 2>/dev/null)" = "$SENTINEL_CONTENT" ]; then _signal=1; fi
  if [ -e "$_cfg" ] || [ -e "$_hooks" ]; then
    if [ "$_signal" = 1 ]; then
      say "  .codex: DMC-owned (sentinel present) -> idempotent re-affirm (no overwrite warning)"
      ship_file "$SRC/.codex/config.toml" ".codex/config.toml"
      ship_file "$SRC/.codex/hooks.json" ".codex/hooks.json"
      if [ "$DRY" = 1 ]; then say "  [dry-run] re-affirm .codex/.dmc-created"; else
        printf '%s\n' "$SENTINEL_CONTENT" > "$_sentinel"; record_created ".codex/.dmc-created"; say "  re-affirm .codex/.dmc-created"
      fi
    else
      say "  .codex: EXISTS without DMC signal -> FOREIGN. Skipping Codex wiring (never overwrite)."
      say "         DMC Codex hook wiring was NOT applied. To adopt it, manually merge"
      say "         .codex/config.toml + .codex/hooks.json (see docs/HOST_REPO_ADAPTATION_POLICY.md)."
    fi
  else
    say "  .codex: creating from templates (DMC-owned) + dropping provenance sentinel"
    ship_file "$SRC/.codex/config.toml" ".codex/config.toml"
    ship_file "$SRC/.codex/hooks.json" ".codex/hooks.json"
    if [ "$DRY" = 1 ]; then say "  [dry-run] drop .codex/.dmc-created ($SENTINEL_CONTENT)"; else
      mkdir -p "$HOST/.codex" && printf '%s\n' "$SENTINEL_CONTENT" > "$_sentinel" && { record_created ".codex/.dmc-created"; say "  drop .codex/.dmc-created"; }
    fi
  fi
}
if [ "$HOST_KIND" = codex ] || [ "$HOST_KIND" = both ]; then
  say "Install Codex adapter (ADVISORY shims — see notice below):"
  for c in $CODEX_ADAPTERS; do ship_file "$SRC/adapters/codex/$c" "adapters/codex/$c"; done
  for s in $CODEX_SKILLS; do ship_dir "$SRC/.agents/skills/$s" ".agents/skills/$s"; done
  install_codex_wiring
  say "  NOTE: DMC's own AGENTS.md is NOT copied (would misdescribe a host). To generate host-specific"
  say "        Codex operating guidance, run:  dmc agents-md   (offered, never auto-imposed)."
  say ""
  say "  Codex wiring is ADVISORY (human gate Option A, codex-cli 0.132.0):"
  say "    - Hook firing and decision-envelope honoring are UNPROVEN turn-free; these shims are NOT a"
  say "      runtime enforcement boundary. The enforcement boundary on a Codex host is the pre-commit/CI"
  say "      gate; the M6 post-Bash diff guard is the primary safety net."
  say "    - Required trust step (never bypassed): in Codex, run the one-time /hooks content-hash trust"
  say "      for .codex/hooks.json and mark the project trusted so .codex/config.toml is honored. DMC"
  say "      never bypasses Codex hook trust."
  say "    - Option B (a human-run, consented live-turn verification to promote these shims to"
  say "      enforcing) is a SEPARATE human gate, not invoked by this installer."
fi

# ---- harness skeleton + schemas + mode (ALL hosts) ----
# The .gitkeep skeleton and the schema files are DMC-created; record them in the receipt so the
# uninstaller removes them (they are not in its fixed-name legacy list), leaving only empty dirs.
say "Install .harness skeleton + schemas:"
for d in $HARNESS_DIRS; do act ".harness/$d" mk_gitkeep "$HOST/.harness/$d"; [ "$DRY" = 1 ] || record_created ".harness/$d/.gitkeep"; done
act "mkdir .harness/schemas" mkdir -p "$HOST/.harness/schemas"
for sc in $(schema_list); do act "schema $sc" cp "$SRC/.harness/schemas/$sc" "$HOST/.harness/schemas/"; [ "$DRY" = 1 ] || record_created ".harness/schemas/$sc"; done
act ".harness/mode=$MODE" write_line "$MODE" "$HOST/.harness/mode"

# ---- root docs + bundled support docs (fix dangling refs) (ALL hosts) ----
say "Install docs/schemas:"
for d in $ROOT_DOCS; do act "$d" cp "$SRC/$d" "$HOST/$d"; done
act "mkdir docs" mkdir -p "$HOST/docs"
for sd in $SUPPORT_DOCS; do act "docs/$sd (bundled support doc)" cp "$SRC/docs/$sd" "$HOST/docs/"; done

# CLAUDE.md: create if absent (record created); else append the DMC section between paired HTML
# markers, idempotently (record merged). Skip when the BEGIN marker is already present.
if [ ! -f "$HOST/CLAUDE.md" ]; then
  act "CLAUDE.md (new)" cp "$SRC/CLAUDE.md" "$HOST/CLAUDE.md"
  [ "$DRY" = 1 ] || record_created "CLAUDE.md"
elif grep -qF "$CLAUDE_BEGIN" "$HOST/CLAUDE.md" 2>/dev/null || was_created "CLAUDE.md"; then
  # DMC content already here (paired marker present, or DMC created this file per the prior receipt) -> idempotent skip.
  say "  CLAUDE.md: DMC content already present (skip)"
  [ "$DRY" = 1 ] || { if was_created "CLAUDE.md"; then record_created "CLAUDE.md"; else record_merged "CLAUDE.md"; fi; }
else
  if [ "$DRY" = 1 ]; then say "  [dry-run] append DMC section to existing CLAUDE.md (paired markers, preserve host content)"; else
    { printf '\n%s\n' "$CLAUDE_BEGIN"; cat "$SRC/CLAUDE.md"; printf '%s\n' "$CLAUDE_END"; } >> "$HOST/CLAUDE.md"
    record_merged "CLAUDE.md"; say "  appended DMC section to existing CLAUDE.md"
  fi
fi
say "  (AGENTS.md deliberately NOT installed — host-specific; use 'dmc agents-md' / /dmc-init-deep)"

# ---- .gitignore block (paired markers; host artifacts local-only + secret ignore) (ALL hosts) ----
if [ ! -f "$HOST/.gitignore" ]; then
  if [ "$DRY" = 1 ]; then say "  [dry-run] create .gitignore with DMC block (# DMC:BEGIN..# DMC:END)"; else
    print_gitignore_block > "$HOST/.gitignore"; record_created ".gitignore"; say "  created .gitignore with DMC block"
  fi
elif grep -qF "$GI_BEGIN" "$HOST/.gitignore" 2>/dev/null || was_created ".gitignore"; then
  say ".gitignore: DMC block already present (skip)"
  [ "$DRY" = 1 ] || { if was_created ".gitignore"; then record_created ".gitignore"; else record_merged ".gitignore"; fi; }
else
  if [ "$DRY" = 1 ]; then say "  [dry-run] append DMC .gitignore block (# DMC:BEGIN..# DMC:END)"; else
    { printf '\n'; print_gitignore_block; } >> "$HOST/.gitignore"; record_merged ".gitignore"; say "  appended DMC .gitignore block"
  fi
fi

# ---- install receipt (host-local provenance; gitignored; removed LAST by the uninstaller) ----
if [ "$DRY" = 1 ]; then
  say "  [dry-run] write $RECEIPT_REL (created_paths + merged_targets)"
else
  DMC_CREATED="$CREATED" DMC_MERGED="$MERGED" python3 - "$HOST/$RECEIPT_REL" <<'PY' && say "  wrote $RECEIPT_REL"
import json,os,sys
path=sys.argv[1]
def lines(k): return sorted({l for l in os.environ.get(k,"").splitlines() if l.strip()})
os.makedirs(os.path.dirname(path),exist_ok=True)
with open(path,"w") as f:
    json.dump({"created_paths":lines("DMC_CREATED"),"merged_targets":lines("DMC_MERGED")},f,indent=2,sort_keys=True)
    f.write("\n")
PY
fi

say ""
if [ "$DRY" = 1 ]; then say "Done (dry-run — nothing written)."; else say "Done."; fi
say "Mode: $MODE. Override with --mode active|passive|off. Host target: --host $HOST_KIND."
say "Rollback: run .claude/install/dmc-uninstall.sh '$HOST'  (or, on a throwaway branch, 'git checkout main && git branch -D <pilot-branch>')."
