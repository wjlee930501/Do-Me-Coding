#!/usr/bin/env bash
# DMC Context Budgeter (v0.5.1) — ADVISORY / READ-ONLY, inert unless invoked.
#
# Classifies candidate context files into tiers (required / useful / optional / forbidden / excluded) for a given goal,
# estimates the context weight (line count of the loaded set), and reports loudly when a budget is exceeded. See
# docs/CONTEXT_BUDGET.md. Secret-bearing files are classified FORBIDDEN and their contents are NEVER read; requesting one
# in --touched is REFUSED. Reads no .env / credentials / tokens / provider payloads and makes no network/live call.
#
# Usage:  dmc-v0.5.1-context-budgeter.sh --goal-type <t> [--touched p[,p..]] [--milestone-range r] [--mode m]
#             [--map <repo-map.json>] [--budget N] [--out <file>]   ·   --self-test
# Exit: 0 = within budget, 1 = forbidden path requested (refused), 2 = usage, 3 = budget EXCEEDED (report still emitted).
set -u
set -o pipefail
export PYTHONDONTWRITEBYTECODE=1
SELFPATH="$(cd "$(dirname "$0")" 2>/dev/null && pwd -P)/$(basename "$0")"
ROOTDIR="$(cd "$(dirname "$SELFPATH")/../.." 2>/dev/null && pwd -P || true)"
[ -n "$ROOTDIR" ] || ROOTDIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
# deterministic internal worktree-status hash — reads NO env var and executes NO env-controlled command (python hashlib)
repo_hash() { git -C "$ROOTDIR" status --porcelain 2>/dev/null | python3 -c 'import hashlib,sys; sys.stdout.write(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())'; }

SECRET_NAME_RE='(^|/)\.env($|\.)|\.pem$|\.key$|id_rsa|id_ed25519|(^|/)credentials|\.p12$|\.pfx$|\.keystore$|(^|/)\.npmrc$|(^|/)\.netrc$|(^|/)\.pgpass$|/\.ssh/|\.aws/credentials|(^|/)[^/]*secret[^/]*\.(json|ya?ml|txt|cfg|conf|ini|env)$'
PROT_RE='(^|/)(\.env)(\.|$)|\.pem$|\.key$|id_rsa|id_ed25519|credentials|secret|\.p12$|\.pfx$|\.keystore$|\.claude/hooks|provider-router\.py'
is_secret_name() { # path -> 0 if secret (but allow .env.example/.sample/.template)
  local p="$1"
  case "$p" in *.example|*.sample|*.template) return 1;; esac
  printf '%s' "$p" | grep -qiE "$SECRET_NAME_RE"
}
out_refused() { local raw="$1"
  printf '%s' "$raw" | grep -qE '(^|/)\.\.(/|$)' && return 0
  case "$raw" in *.env|*.env.local|*.env.*) case "$raw" in *.example|*.sample|*.template) ;; *) return 0;; esac;; esac
  printf '%s' "$raw" | grep -qiE "$PROT_RE" && return 0
  [ -L "$raw" ] && return 0
  local parent base cparent canon
  parent="$(dirname "$raw" 2>/dev/null)"; base="$(basename "$raw")"
  cparent="$(cd "$parent" 2>/dev/null && pwd -P)" || return 0
  canon="$cparent/$base"
  printf '%s' "$canon" | grep -qiE "$PROT_RE" && return 0
  case "$canon/" in "$ROOTDIR"/*) return 0;; esac
  git -C "$ROOTDIR" ls-files --error-unmatch -- "$canon" >/dev/null 2>&1 && return 0
  return 1
}

# --- build the default repo-map (names + wc -l weight; NEVER reads a forbidden file's content) ---
default_map() {
  python3 - "$ROOTDIR" <<'PY'
import os,sys,json
root=sys.argv[1]
# (path, category) catalog of key context files; weight via wc -l, skipping any forbidden/secret file.
CAT=[("DMC.md","operating-guide"),("AUTONOMY.md","autonomy-charter"),("AGENTS.md","project-memory"),
     ("docs/CONTEXT_MAP.md","context-map"),("docs/MILESTONES.md","milestone-history"),("docs/INTEROP.md","interop-doc"),
     ("docs/CONTEXT_BUDGET.md","interop-doc"),("docs/EFFORT_POLICY.md","interop-doc"),
     ("docs/REVIEW_HANDOFF_TEMPLATE.md","interop-doc"),
     (".harness/schemas/autonomy.schema.md","schema"),(".harness/schemas/goal-plan.schema.md","schema"),
     (".harness/schemas/evidence.schema.md","schema"),(".harness/schemas/self-review.schema.md","schema"),
     (".harness/schemas/run-metrics.schema.md","schema"),
     (".harness/evidence/dmc-v0.4.3-scope-overeager-guard.sh","guard-script"),
     (".harness/evidence/dmc-v0.4.5-secret-network-live-guard.sh","guard-script"),
     (".harness/evidence/dmc-v0.4.9-autonomous-dry-run.sh","guard-script")]
def wc(p):
    try:
        with open(os.path.join(root,p),encoding="utf-8",errors="replace") as f:
            return sum(1 for _ in f)
    except Exception:
        return 0
files=[]
for p,c in CAT:
    if os.path.exists(os.path.join(root,p)):
        files.append({"path":p,"category":c,"lines":(0 if c=="secret" else wc(p))})
print(json.dumps({"files":files}))
PY
}

classify() { # <goal_type> <touched_csv> <milestone_range> <mode> <budget> <map.json>
  python3 - "$@" <<'PY'
import json,sys,re
goal,touched_csv,mrange,mode,budget,mapf=sys.argv[1:7]
budget=int(budget)
touched=set(p for p in touched_csv.split(",") if p)
m=json.load(open(mapf)); files=m.get("files",[])
# path-derived secret check (mirror of the bash SECRET_NAME_RE) — a secret PATH is forbidden regardless of map category
SECRET_RE=re.compile(r'(^|/)\.env($|\.)|\.pem$|\.key$|id_rsa|id_ed25519|(^|/)credentials|\.p12$|\.pfx$|\.keystore$|(^|/)\.npmrc$|(^|/)\.netrc$|(^|/)\.pgpass$|/\.ssh/|\.aws/credentials|(^|/)[^/]*secret[^/]*\.(json|ya?ml|txt|cfg|conf|ini|env)$', re.IGNORECASE)
def is_secret_path(p):
    pl=str(p).lower()
    if pl.endswith((".example",".sample",".template")): return False
    return bool(SECRET_RE.search(str(p)))
SAFE_GOALS={"docs-closure","schema-additive","guard-hardening","security","provider-change","capstone-safety","generic"}
AUTONOMY_GOALS={"guard-hardening","security","provider-change","capstone-safety"}
def tier_of(f):
    p,c,ln=f["path"],f.get("category","other"),f.get("lines",0)
    if c=="secret" or is_secret_path(p):
        return ("forbidden","secret-bearing — never loaded (path-derived; map category ignored)")
    if p in touched:
        return ("required","in the run's touched scope")
    if c=="operating-guide":
        return ("required","operating guide + non-negotiable secret/safety rules (always required)")
    if c=="autonomy-charter":
        if goal in AUTONOMY_GOALS: return ("required","autonomy levels + stop conditions (guard/security/provider work)")
        return ("excluded","autonomy charter not needed for this goal")
    if c=="context-map":
        return ("useful","single-source pointer index (cheaper than loading every doc)")
    if c=="project-memory":
        return ("optional","pointer only — rules live in DMC.md (single-source; avoid duplicate instructions)")
    if c=="milestone-history":
        if goal=="docs-closure": return ("required","the closure entry is appended here")
        if mrange: return ("useful","explicit --milestone-range requested")
        return ("excluded","stale milestone history — not in scope")
    if c=="schema":
        if goal in ("schema-additive","guard-hardening","security","provider-change","capstone-safety"):
            return ("useful","compact schema — prefer over long prose")
        return ("optional","schema not central to this goal")
    if c=="guard-script":
        if goal in ("guard-hardening","security","capstone-safety"): return ("useful","related guard (compact, executable)")
        return ("optional","guard not central to this goal")
    if c=="interop-doc":
        return ("excluded","long prose doc — prefer schemas/evidence scripts; load only if directly relevant")
    return ("optional","related")
tiers={"required":[],"useful":[],"optional":[],"forbidden":[],"excluded":[]}
for f in files:
    t,reason=tier_of(f)
    tiers[t].append((f["path"],f.get("lines",0),reason))
loaded=tiers["required"]+tiers["useful"]
weight=sum(ln for _,ln,_ in loaded)
over = weight>budget
out=[]
out.append("# DMC Context Budget — goal=%s mode=%s"%(goal,(mode or "-")))
if goal not in SAFE_GOALS: out.append("_note: unrecognized goal-type '%s' — using generic tiering_"%goal)
for t in ("required","useful","optional","excluded","forbidden"):
    out.append("")
    out.append("## %s (%d)"%(t,len(tiers[t])))
    if not tiers[t]: out.append("- (none)")
    for p,ln,reason in sorted(tiers[t]):
        if t in ("required","useful"): out.append("- %s  [%d lines]  — %s"%(p,ln,reason))
        else: out.append("- %s  — %s"%(p,reason))
out.append("")
out.append("## weight")
out.append("- loaded (required+useful): %d files, %d lines"%(len(loaded),weight))
out.append("- budget: %d lines"%budget)
if over:
    out.append("")
    out.append("## WARNING: context budget exceeded — %d lines loaded > %d budget (trim 'useful'/'optional' before run)"%(weight,budget))
print("\n".join(out))
sys.exit(3 if over else 0)
PY
}

# ---------------------------------------------------------------- self-test (fixture map; no fs/secret read; no network)
self_test() {
  local P=0 F=0; ok(){ echo "  PASS $1"; P=$((P+1)); }; no(){ echo "  FAIL $1"; F=$((F+1)); }
  local TT; TT="$(mktemp -d)"; trap 'rm -rf "$TT"' RETURN
  local PRE; PRE="$(repo_hash)"
  cat > "$TT/map.json" <<'J'
{"files":[
 {"path":"DMC.md","category":"operating-guide","lines":200},
 {"path":"AUTONOMY.md","category":"autonomy-charter","lines":71},
 {"path":"AGENTS.md","category":"project-memory","lines":60},
 {"path":"docs/CONTEXT_MAP.md","category":"context-map","lines":35},
 {"path":"docs/MILESTONES.md","category":"milestone-history","lines":242},
 {"path":"docs/INTEROP.md","category":"interop-doc","lines":45},
 {"path":".harness/schemas/run-metrics.schema.md","category":"schema","lines":40},
 {"path":".harness/evidence/dmc-v0.4.5-secret-network-live-guard.sh","category":"guard-script","lines":83},
 {"path":".env","category":"secret","lines":0}
]}
J
  local G; G="$TT/map.json"
  run(){ classify "$1" "$2" "$3" "$4" "$5" "$G"; }   # goal touched range mode budget

  # AC1 v0.4-style safety work: DMC.md + AUTONOMY.md + the touched guard are REQUIRED; .env is FORBIDDEN (never loaded)
  local r1; r1="$(run guard-hardening ".harness/evidence/dmc-v0.4.5-secret-network-live-guard.sh" "" active 800)"
  { printf '%s' "$r1" | awk '/^## required/{f=1} /^## useful/{f=0} f' | grep -q 'DMC.md' \
    && printf '%s' "$r1" | awk '/^## required/{f=1} /^## useful/{f=0} f' | grep -q 'AUTONOMY.md' \
    && printf '%s' "$r1" | awk '/^## required/{f=1} /^## useful/{f=0} f' | grep -q 'dmc-v0.4.5-secret-network-live-guard.sh' \
    && printf '%s' "$r1" | awk '/^## forbidden/{f=1} f' | grep -q '.env'; } \
    && ok "AC1 guard-hardening: DMC.md + AUTONOMY.md + touched guard REQUIRED; .env FORBIDDEN" || no "AC1 required set wrong"

  # AC2 unrelated long prose excluded with a reason
  printf '%s' "$r1" | awk '/^## excluded/{f=1} /^## forbidden/{f=0} f' | grep -q 'INTEROP.md.*long prose' \
    && ok "AC2 unrelated long prose (INTEROP.md) EXCLUDED with reason" || no "AC2 prose not excluded"

  # AC3 forbidden path requested in --touched => REFUSED (exit 1) — via the real dispatch
  bash "$SELFPATH" --goal-type generic --touched ".env" --map "$G" >/dev/null 2>&1; [ $? = 1 ] \
    && ok "AC3 forbidden path in --touched => REFUSED (exit 1)" || no "AC3 secret not refused"

  # AC4 budget overflow reported loudly (WARNING line) AND signaled (exit 3), not silently ignored
  local r4 rc4; r4="$(run guard-hardening ".harness/evidence/dmc-v0.4.5-secret-network-live-guard.sh" "" active 50)"; rc4=$?
  { printf '%s' "$r4" | grep -q '## WARNING: context budget exceeded' && [ "$rc4" = 3 ]; } \
    && ok "AC4 budget overflow REPORTED (WARNING line) + signaled (exit 3)" || no "AC4 overflow silent (rc=$rc4)"

  # AC5 'schemas/evidence before long prose': for schema-additive, the schema is useful while INTEROP prose is excluded
  local r5; r5="$(run schema-additive "" "" active 800)"
  { printf '%s' "$r5" | awk '/^## useful/{f=1} /^## optional/{f=0} f' | grep -q 'run-metrics.schema.md' \
    && printf '%s' "$r5" | awk '/^## excluded/{f=1} /^## forbidden/{f=0} f' | grep -q 'INTEROP.md'; } \
    && ok "AC5 schemas/evidence preferred: schema USEFUL, long prose EXCLUDED" || no "AC5 schema/prose ordering"

  # AC6 deterministic + env-independent (real-script invocations, identical flags; env -i + credential differential)
  local base; base="$(bash "$SELFPATH" --goal-type docs-closure --budget 800 --map "$G" 2>/dev/null)"
  [ "$(bash "$SELFPATH" --goal-type docs-closure --budget 800 --map "$G" 2>/dev/null)" = "$base" ] && local det=1 || local det=0
  local envi; envi="$(env -i PATH="$PATH" HOME="${HOME:-/tmp}" bash "$SELFPATH" --goal-type docs-closure --budget 800 --map "$G" 2>/dev/null)"
  local diff_ok=1 v
  for v in GLM_API_KEY ANTHROPIC_API_KEY OPENAI_API_KEY; do
    [ "$(env "$v=sk-ant-api03-XXXXXXXXXXXX" bash "$SELFPATH" --goal-type docs-closure --budget 800 --map "$G" 2>/dev/null)" = "$base" ] || diff_ok=0
  done
  { [ "$det" = 1 ] && [ "$envi" = "$base" ] && [ "$diff_ok" = 1 ]; } && ok "AC6 deterministic + env-independent" || no "AC6 non-deterministic/env-dependent"

  # AC7 structural no-net / no-secret-read audit (own audit block + comments excluded)
  local OP; OP="$(sed '/AUDIT_BLOCK_START/,/AUDIT_BLOCK_END/d' "$SELFPATH" | grep -vE '^[[:space:]]*#')"
  # >>>AUDIT_BLOCK_START
  ! printf '%s' "$OP" | grep -nE '(^|[^A-Za-z])(curl|wget)([[:space:]])| --live | --allow-network|os\.environ|getenv|printenv|(cat|less|head|tail)[[:space:]]+[^|]*\.env|HASH_CMD|\$\{DMC_' >/dev/null \
    && ok "AC7 no curl/wget/--live, no .env-read, no env-hash (DMC_HASH_CMD/\${DMC_*}) in the operative source" || no "AC7 net/secret-read present"
  # >>>AUDIT_BLOCK_END

  # AC9 (HARDENING) map-injection: a mislabeled secret file is FORCED to forbidden by PATH, never loaded
  cat > "$TT/evil.json" <<'J'
{"files":[
 {"path":"DMC.md","category":"operating-guide","lines":200},
 {"path":".env","category":"operating-guide","lines":500},
 {"path":"deploy/prod.key","category":"schema","lines":80},
 {"path":"id_rsa","category":"context-map","lines":40}
]}
J
  local rE; rE="$(classify docs-closure "" "" active 99999 "$TT/evil.json")"
  { printf '%s' "$rE" | awk '/^## forbidden/{f=1} f' | grep -qF '.env' \
    && printf '%s' "$rE" | awk '/^## forbidden/{f=1} f' | grep -qF 'prod.key' \
    && printf '%s' "$rE" | awk '/^## forbidden/{f=1} f' | grep -qF 'id_rsa' \
    && ! printf '%s' "$rE" | awk '/^## required/{f=1} /^## useful/{f=0} f' | grep -qE '\.env|prod\.key|id_rsa' \
    && ! printf '%s' "$rE" | awk '/^## useful/{f=1} /^## optional/{f=0} f' | grep -qE '\.env|prod\.key|id_rsa'; } \
    && ok "AC9 map-injection: mislabeled secret paths FORCED forbidden (path-derived), never in loaded tiers" || no "AC9 mislabeled secret loaded"

  # AC10 (HARDENING) DMC_HASH_CMD is neither read nor executed (no env-controlled hash command).
  # >>>AUDIT_BLOCK_START  (hostile-input test; excluded from the operative-source audit)
  local SENT="$TT/sentinel" FAKE="$TT/fakehash"
  printf '#!/bin/sh\ntouch "%s"\necho PWNED\n' "$SENT" > "$FAKE"; chmod +x "$FAKE"
  local hbase hhostile; hbase="$(repo_hash)"; hhostile="$(DMC_HASH_CMD="$FAKE" repo_hash)"
  { [ ! -e "$SENT" ] && [ -n "$hbase" ] && [ "$hbase" = "$hhostile" ]; } \
    && ok "AC10 env-hash injection: hostile DMC_HASH_CMD never read/executed; repo_hash byte-identical" || no "AC10 env-controlled hash executed"
  # >>>AUDIT_BLOCK_END

  # AC8 read-only: repo byte-unchanged
  { [ -n "$PRE" ] && [ "$(repo_hash)" = "$PRE" ]; } && ok "AC8 read-only: repo byte-unchanged (deterministic sha256)" || no "AC8 repo changed"

  echo "  ---- self-test: PASS=$P FAIL=$F ----"; [ "$F" = 0 ]
}

GOAL=""; TOUCHED=""; MRANGE=""; MODE=""; MAP=""; BUDGET=800; OUT=""; RUN=run
while [ $# -gt 0 ]; do case "$1" in
  --goal-type) GOAL="$2"; shift 2;; --touched) TOUCHED="$2"; shift 2;; --milestone-range) MRANGE="$2"; shift 2;;
  --mode) MODE="$2"; shift 2;; --map) MAP="$2"; shift 2;; --budget) BUDGET="$2"; shift 2;; --out) OUT="$2"; shift 2;;
  --self-test) RUN=selftest; shift;; -h|--help) sed -n '2,11p' "$0"; exit 0;;
  *) echo "context-budgeter: unknown arg $1" >&2; exit 2;;
esac; done
if [ "$RUN" = selftest ]; then echo "==== DMC CONTEXT BUDGETER — SELF-TEST ===="; self_test; exit $?; fi
[ -n "$GOAL" ] || { echo "context-budgeter: --goal-type required (or --self-test)" >&2; exit 2; }
# refuse a forbidden/secret path requested in --touched (you cannot scope a run to a secret file)
OLDIFS="$IFS"; IFS=','; for t in $TOUCHED; do [ -z "$t" ] && continue; if is_secret_name "$t"; then IFS="$OLDIFS"; echo "context-budgeter: forbidden/secret path in --touched ('$t') — REFUSED" >&2; exit 1; fi; done; IFS="$OLDIFS"
[ -z "$BUDGET" ] && BUDGET=800
case "$BUDGET" in ''|*[!0-9]*) echo "context-budgeter: --budget must be a non-negative integer" >&2; exit 2;; esac
MAPFILE="$MAP"
if [ -z "$MAPFILE" ]; then MAPFILE="$(mktemp)"; trap 'rm -f "$MAPFILE"' EXIT; default_map > "$MAPFILE"; fi
[ -f "$MAPFILE" ] || { echo "context-budgeter: --map file not found" >&2; exit 2; }
if [ -n "$OUT" ]; then
  out_refused "$OUT" && { echo "context-budgeter: --out protected/secret/in-work-tree — REFUSED" >&2; exit 2; }
  REPORT="$(classify "$GOAL" "$TOUCHED" "$MRANGE" "$MODE" "$BUDGET" "$MAPFILE")"; rc=$?
  printf '%s\n' "$REPORT" > "$OUT"; echo "context-budgeter: wrote $OUT" >&2; exit $rc
fi
classify "$GOAL" "$TOUCHED" "$MRANGE" "$MODE" "$BUDGET" "$MAPFILE"; exit $?
