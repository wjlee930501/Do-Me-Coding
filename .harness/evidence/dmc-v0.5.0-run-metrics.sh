#!/usr/bin/env bash
# DMC Run Metrics Ledger (v0.5.0) — ADVISORY / READ-ONLY, local-only, value-blind.
#
# Validates a per-run efficiency record (see .harness/schemas/run-metrics.schema.md) and emits a REDACTED ledger
# artifact that is safe to review and commit. Validation is fail-closed: a missing field, a wrong enum, a non-numeric
# numeric, or inconsistent test counts => REFUSED (non-zero), never emitted. Free-form fields are value-blind-redacted;
# numeric fields are validated so a secret cannot hide in one. Reads ONLY the record it is given (argv/file) — never the
# environment, .env, credentials, provider payloads, or the network. Executes nothing; mutates nothing.
#
# Usage:  dmc-v0.5.0-run-metrics.sh --from <metrics.json> [--out <file>]  |  --validate <metrics.json>  |  --self-test
# Exit: 0 = valid/emitted, 1 = invalid (fail-closed), 2 = usage/refused.
set -u
set -o pipefail
export PYTHONDONTWRITEBYTECODE=1
SELFPATH="$(cd "$(dirname "$0")" 2>/dev/null && pwd -P)/$(basename "$0")"
# repo root from the SCRIPT location (not the process cwd) so --out write-safety holds from any cwd
ROOTDIR="$(cd "$(dirname "$SELFPATH")/../.." 2>/dev/null && pwd -P || true)"
[ -n "$ROOTDIR" ] || ROOTDIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
HASH_CMD="${DMC_HASH_CMD-$(command -v md5sum 2>/dev/null || command -v md5 2>/dev/null || true)}"
repo_hash() { git -C "$ROOTDIR" status --porcelain 2>/dev/null | { [ -n "$HASH_CMD" ] && "$HASH_CMD" || echo NOHASH; }; }

PROT_RE='(^|/)(\.env)(\.|$)|\.pem$|\.key$|id_rsa|id_ed25519|credentials|secret|\.p12$|\.pfx$|\.keystore$|\.claude/hooks|provider-router\.py|PROVIDER_CONTRACT\.md|WORKER_(TASK|RESULT|REVIEW)_SCHEMA\.md'
out_refused() { local raw="$1"
  printf '%s' "$raw" | grep -qE '(^|/)\.\.(/|$)' && return 0
  case "$raw" in *.env|*.env.local|*.env.*) case "$raw" in *.example|*.sample|*.template) ;; *) return 0;; esac;; esac
  printf '%s' "$raw" | grep -qiE "$PROT_RE" && return 0
  [ -L "$raw" ] && return 0                                   # reject symlinked target (cp would dereference into the tree)
  local parent base cparent canon
  parent="$(dirname "$raw" 2>/dev/null)"; base="$(basename "$raw")"
  cparent="$(cd "$parent" 2>/dev/null && pwd -P)" || return 0  # fail closed on unresolved parent
  canon="$cparent/$base"
  printf '%s' "$canon" | grep -qiE "$PROT_RE" && return 0
  case "$canon/" in "$ROOTDIR"/*) return 0;; esac             # refuse anything inside the repo work tree
  git -C "$ROOTDIR" ls-files --error-unmatch -- "$canon" >/dev/null 2>&1 && return 0
  return 1
}

# --- validate (+ optionally emit) a metrics record. Inputs via file ONLY; never the environment. ---
process() { # <mode: validate|emit> <metrics.json>
  python3 - "$1" "$2" <<'PY'
import json,sys,re,math
mode=sys.argv[1]
UNSAFE=re.compile(
  r'sk-[A-Za-z0-9_-]{16,}|AKIA[0-9A-Z]{8,}|(BEGIN|END)[A-Z ]*PRIVATE KEY|xox[baprs]-[A-Za-z0-9-]{6,}'
  r'|gh[opsu]_[A-Za-z0-9]{16,}|github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{16,}|npm_[A-Za-z0-9]{30,}'
  r'|AIza[0-9A-Za-z_-]{20,}|dop_v1_[A-Za-z0-9]{16,}|AccountKey=[A-Za-z0-9+/=]{16,}'
  r'|eyJ[A-Za-z0-9_-]{6,}\.eyJ[A-Za-z0-9_-]{6,}|[Bb]earer\s+[A-Za-z0-9._-]{12,}|ya29\.[A-Za-z0-9._-]{8,}'
  r'|(access_token|refresh_token|id_token)\s*[=:]'
  r'|(password|passwd|api[_-]?key|apikey|client_secret|aws_secret_access_key)\s*[=:]\s*\S{6,}'
  r'|SENTINEL', re.IGNORECASE)
def safe(v):
    s="" if v is None else str(v)
    if UNSAFE.search(s): return "[redacted:unsafe-metadata]"
    return s.replace("\n"," ").replace("\r"," ")   # collapse newlines so a free-form note cannot forge ledger lines
REQ=["run_id","goal_type","mode","effort","context_files_count","estimated_input_tokens","estimated_output_tokens",
     "tool_calls","wall_clock_sec","files_touched","tests_selected","tests_run","tests_passed","tests_failed",
     "review_findings_total","blockers","retry_count","human_gates","outcome","efficiency_notes"]
INT_FIELDS=["context_files_count","estimated_input_tokens","estimated_output_tokens","tool_calls","files_touched",
            "tests_selected","tests_run","tests_passed","tests_failed","review_findings_total","blockers",
            "retry_count","human_gates"]
MODES={"passive","advisory","autonomous-dry-run","autonomous-local-commit","human-gated-push"}
EFFORTS={"light","standard","deep","adversarial"}
OUTCOMES={"completed","blocked","abandoned","partial"}
def is_int(v): return (not isinstance(v,bool)) and isinstance(v,int)
def is_num(v): return (not isinstance(v,bool)) and isinstance(v,(int,float))
try:
    m=json.load(open(sys.argv[2]))
except Exception:
    print("run-metrics: invalid JSON", file=sys.stderr); sys.exit(1)
if not isinstance(m,dict):
    print("run-metrics: record is not an object", file=sys.stderr); sys.exit(1)
errs=[]
for k in REQ:
    if k not in m: errs.append("missing:"+k)
for k in INT_FIELDS:
    if k in m and not (is_int(m[k]) and m[k]>=0): errs.append("bad-int:"+k)
if "wall_clock_sec" in m and not (is_num(m["wall_clock_sec"]) and m["wall_clock_sec"]>=0 and math.isfinite(m["wall_clock_sec"])): errs.append("bad-num:wall_clock_sec")
if m.get("mode") not in MODES: errs.append("bad-mode")
if m.get("effort") not in EFFORTS: errs.append("bad-effort")
if m.get("outcome") not in OUTCOMES: errs.append("bad-outcome")
if not errs and not (m["tests_passed"]+m["tests_failed"] <= m["tests_run"] <= m["tests_selected"]):
    errs.append("inconsistent-test-counts")
if errs:
    print("run-metrics: INVALID ("+",".join(sorted(errs))+")", file=sys.stderr); sys.exit(1)
if mode=="validate":
    print("VALID"); sys.exit(0)
rid=safe(m["run_id"]); gt=safe(m["goal_type"]); notes=safe(m["efficiency_notes"])
out=[
 "# DMC Run Metrics — %s"%rid,
 "- run_id: %s"%rid,
 "- goal_type: %s"%gt,
 "- mode: %s | effort: %s"%(m["mode"],m["effort"]),
 "- context_files_count: %d | estimated_input_tokens: %d | estimated_output_tokens: %d | tool_calls: %d"%(
    m["context_files_count"],m["estimated_input_tokens"],m["estimated_output_tokens"],m["tool_calls"]),
 "- wall_clock_sec: %s | files_touched: %d"%(m["wall_clock_sec"],m["files_touched"]),
 "- tests: selected=%d run=%d passed=%d failed=%d"%(m["tests_selected"],m["tests_run"],m["tests_passed"],m["tests_failed"]),
 "- review_findings_total: %d | blockers: %d | retry_count: %d | human_gates: %d"%(
    m["review_findings_total"],m["blockers"],m["retry_count"],m["human_gates"]),
 "- outcome: %s"%m["outcome"],
 "- efficiency_notes: %s"%notes,
 "- redaction: applied for known token/path/env shapes (value-blind); numeric fields validated; NOT a completeness guarantee — review before commit",
]
print("\n".join(out))
PY
}

# ---------------------------------------------------------------- self-test (fixtures; no network; no env read)
self_test() {
  local P=0 F=0; ok(){ echo "  PASS $1"; P=$((P+1)); }; no(){ echo "  FAIL $1"; F=$((F+1)); }
  local TT; TT="$(mktemp -d)"; trap 'rm -rf "$TT"' RETURN
  local PRE; PRE="$(repo_hash)"

  # valid fixture
  cat > "$TT/ok.json" <<'J'
{"run_id":"run-0001","goal_type":"docs-closure","mode":"human-gated-push","effort":"light",
 "context_files_count":3,"estimated_input_tokens":1200,"estimated_output_tokens":400,"tool_calls":7,
 "wall_clock_sec":42.5,"files_touched":1,"tests_selected":10,"tests_run":10,"tests_passed":10,"tests_failed":0,
 "review_findings_total":0,"blockers":0,"retry_count":0,"human_gates":2,"outcome":"completed","efficiency_notes":"clean"}
J
  # secret-planted fixture (free-form carriers)
  cat > "$TT/leak.json" <<'J'
{"run_id":"ghp_LEAKAAA0123456789ABCDEFGHIJKLMNOP","goal_type":"deploy sk-LEAKKEY0123456789abcdefghijkl now",
 "mode":"advisory","effort":"deep","context_files_count":2,"estimated_input_tokens":900,"estimated_output_tokens":100,
 "tool_calls":4,"wall_clock_sec":12,"files_touched":0,"tests_selected":5,"tests_run":5,"tests_passed":5,"tests_failed":0,
 "review_findings_total":1,"blockers":0,"retry_count":0,"human_gates":1,"outcome":"completed",
 "efficiency_notes":"token ya29.LEAKPROVIDER0123 leaked here"}
J

  local emit; emit="$(process emit "$TT/ok.json")"
  # AC1 schema conformance — emitted artifact has every section
  { printf '%s' "$emit" | grep -q '# DMC Run Metrics' && printf '%s' "$emit" | grep -q '^- mode: human-gated-push | effort: light' \
    && printf '%s' "$emit" | grep -q 'tests: selected=10 run=10 passed=10 failed=0' && printf '%s' "$emit" | grep -q '^- outcome: completed' \
    && printf '%s' "$emit" | grep -q 'redaction: applied'; } && ok "AC1 schema conformance: valid record emits a complete ledger artifact" || no "AC1 schema conformance"

  # AC2 value-blind redaction — planted secret shapes in run_id/goal_type/efficiency_notes NEVER survive
  local leak; leak="$(process emit "$TT/leak.json")"
  ! printf '%s' "$leak" | grep -Eq 'ghp_LEAK|sk-LEAKKEY|ya29\.LEAKPROVIDER' && printf '%s' "$leak" | grep -q 'redacted:unsafe-metadata' \
    && ok "AC2 redaction: token/secret-shaped run_id/goal_type/notes redacted, never re-emitted" || no "AC2 a planted secret survived"

  # AC3 fail-closed validation (invalid records refused, exit 1)
  local r
  python3 -c 'import json; d=json.load(open("'"$TT/ok.json"'")); del d["tool_calls"]; json.dump(d,open("'"$TT/miss.json"'","w"))'
  process validate "$TT/miss.json" >/dev/null 2>&1; [ $? = 1 ] && r=1 || r=0
  python3 -c 'import json; d=json.load(open("'"$TT/ok.json"'")); d["estimated_input_tokens"]="sk-HIDDEN0123456789abcdef"; json.dump(d,open("'"$TT/badnum.json"'","w"))'
  process validate "$TT/badnum.json" >/dev/null 2>&1; [ $? = 1 ] && r=$((r+1)) || r=$r
  python3 -c 'import json; d=json.load(open("'"$TT/ok.json"'")); d["mode"]="bogus"; json.dump(d,open("'"$TT/badmode.json"'","w"))'
  process validate "$TT/badmode.json" >/dev/null 2>&1; [ $? = 1 ] && r=$((r+1)) || r=$r
  python3 -c 'import json; d=json.load(open("'"$TT/ok.json"'")); d["tests_passed"]=99; json.dump(d,open("'"$TT/badcount.json"'","w"))'
  process validate "$TT/badcount.json" >/dev/null 2>&1; [ $? = 1 ] && r=$((r+1)) || r=$r
  [ "$r" = 4 ] && ok "AC3 fail-closed: missing field / secret-in-numeric / bad enum / inconsistent counts all REFUSED (exit 1)" || no "AC3 fail-closed (passes=$r/4)"

  # AC3b a valid record validates VALID (positive control)
  process validate "$TT/ok.json" >/dev/null 2>&1 && ok "AC3b positive control: a valid record => VALID (exit 0)" || no "AC3b valid record rejected"

  # AC4 deterministic + env-independent (no env read): same input byte-identical; env -i + credential-var differential identical
  [ "$(process emit "$TT/ok.json")" = "$emit" ] && local det=1 || local det=0
  local envi; envi="$(env -i PATH="$PATH" HOME="${HOME:-/tmp}" bash "$SELFPATH" --from "$TT/ok.json" 2>/dev/null)"
  local diff_ok=1 v
  for v in GLM_API_KEY ANTHROPIC_API_KEY OPENAI_API_KEY; do
    [ "$(env "$v=sk-ant-api03-XXXXXXXXXXXXXXXXXXXX" bash "$SELFPATH" --from "$TT/ok.json" 2>/dev/null)" = "$emit" ] || diff_ok=0
  done
  { [ "$det" = 1 ] && [ "$envi" = "$emit" ] && [ "$diff_ok" = 1 ]; } && ok "AC4 deterministic + env-independent (env -i + credential-var differential byte-identical)" || no "AC4 non-deterministic/env-dependent"

  # AC5 --out guard — secret/protected/traversal/in-tree/symlink refused; benign tmp allowed
  ln -s "$ROOTDIR/DMC.md" "$TT/link" 2>/dev/null
  { out_refused ".env" && out_refused "x/../y" && out_refused "$ROOTDIR/DMC.md" && out_refused "$TT/link" && ! out_refused "$TT/out.md"; } \
    && ok "AC5 --out guard: .env/traversal/in-tree/symlink REFUSED; out-of-tree tmp allowed" || no "AC5 --out guard"

  # AC6 structural no-net / no-live / no-env-read audit of the operative source (own audit block + comments excluded)
  local OP; OP="$(sed '/AUDIT_BLOCK_START/,/AUDIT_BLOCK_END/d' "$SELFPATH" | grep -vE '^[[:space:]]*#')"
  # >>>AUDIT_BLOCK_START
  ! printf '%s' "$OP" | grep -nE '(^|[^A-Za-z])(curl|wget)([[:space:]])| --live | --allow-network|os\.environ|getenv|printenv' >/dev/null \
    && ok "AC6 no curl/wget/--live/--allow-network and no env-read primitive in the operative source" || no "AC6 net/live/env-read present"
  # >>>AUDIT_BLOCK_END

  # AC8 (HARDENING) broadened redaction: modern token shapes + bare credential key=val are redacted
  cat > "$TT/leak2.json" <<'J'
{"run_id":"r","goal_type":"g","mode":"advisory","effort":"deep","context_files_count":1,"estimated_input_tokens":1,"estimated_output_tokens":1,"tool_calls":1,"wall_clock_sec":1,"files_touched":0,"tests_selected":1,"tests_run":1,"tests_passed":1,"tests_failed":0,"review_findings_total":0,"blockers":0,"retry_count":0,"human_gates":0,"outcome":"completed","efficiency_notes":"github_pat_ABCDEFGHIJKLMNOPQRSTUV glpat-ABCDEFGHIJKLMNOP AIzaABCDEFGHIJKLMNOPQRSTUV AKIAABCDEFGH password=hunter2secret"}
J
  local l2; l2="$(process emit "$TT/leak2.json")"
  { ! printf '%s' "$l2" | grep -Eq 'github_pat_ABCDE|glpat-ABCDE|AIzaABCDE|AKIAABCDEFGH|hunter2secret' && printf '%s' "$l2" | grep -q 'redacted:unsafe-metadata'; } \
    && ok "AC8 broadened redaction: github_pat_/glpat-/AIza/AKIA/password= shapes redacted" || no "AC8 a modern secret shape survived"

  # AC9 (HARDENING) newline collapse: a multi-line note cannot forge a fake ledger line
  python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); d["efficiency_notes"]="benign\n- outcome: FORGED-completed"; json.dump(d,open(sys.argv[2],"w"))' "$TT/ok.json" "$TT/nl.json"
  local nl; nl="$(process emit "$TT/nl.json")"
  { [ "$(printf '%s\n' "$nl" | grep -c '^- outcome:')" = 1 ] && ! printf '%s\n' "$nl" | grep -q '^- outcome: FORGED'; } \
    && ok "AC9 newline collapse: a multi-line note cannot forge a fake ledger line" || no "AC9 markdown injection"

  # AC10 (HARDENING) non-finite wall_clock_sec => fail-closed
  printf '%s' '{"run_id":"r","goal_type":"g","mode":"advisory","effort":"deep","context_files_count":1,"estimated_input_tokens":1,"estimated_output_tokens":1,"tool_calls":1,"wall_clock_sec":Infinity,"files_touched":0,"tests_selected":1,"tests_run":1,"tests_passed":1,"tests_failed":0,"review_findings_total":0,"blockers":0,"retry_count":0,"human_gates":0,"outcome":"completed","efficiency_notes":"x"}' > "$TT/inf.json"
  process validate "$TT/inf.json" >/dev/null 2>&1; [ $? = 1 ] && ok "AC10 non-finite wall_clock_sec => fail-closed (exit 1)" || no "AC10 Infinity accepted"

  # AC7 read-only: repo byte-unchanged
  { [ -n "$PRE" ] && [ "$PRE" != NOHASH ] && [ "$(repo_hash)" = "$PRE" ]; } && ok "AC7 read-only: repo byte-unchanged (non-empty hash)" || no "AC7 repo changed"

  echo "  ---- self-test: PASS=$P FAIL=$F ----"; [ "$F" = 0 ]
}

MODE=""; FROM=""; OUT=""
while [ $# -gt 0 ]; do case "$1" in
  --from) MODE=emit; FROM="$2"; shift 2;;
  --validate) MODE=validate; FROM="$2"; shift 2;;
  --out) OUT="$2"; shift 2;;
  --self-test) MODE=selftest; shift;;
  -h|--help) sed -n '2,9p' "$0"; exit 0;;
  *) echo "run-metrics: unknown arg $1" >&2; exit 2;;
esac; done
if [ "$MODE" = selftest ]; then echo "==== DMC RUN METRICS LEDGER — SELF-TEST ===="; self_test; exit $?; fi
[ -n "$MODE" ] && [ -f "${FROM:-/nonexistent}" ] || { echo "run-metrics: --from <metrics.json> | --validate <metrics.json> | --self-test required" >&2; exit 2; }
if [ "$MODE" = validate ]; then process validate "$FROM"; exit $?; fi
if [ -n "$OUT" ]; then out_refused "$OUT" && { echo "run-metrics: --out protected/secret/in-work-tree — REFUSED" >&2; exit 2; }; process emit "$FROM" > "$OUT"; echo "run-metrics: wrote $OUT" >&2; exit 0; fi
process emit "$FROM"; exit $?
