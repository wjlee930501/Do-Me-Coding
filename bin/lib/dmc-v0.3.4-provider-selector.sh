#!/usr/bin/env bash
# DMC Unified Provider Selection Runner (v0.3.4) — ADVISORY / READ-ONLY.
#
# Given a task BUNDLE, recommends ranked provider_target CANDIDATES — moving "which provider" from manual judgment to
# POLICY-based judgment by composing the v0.2.8 task-intake classifier + the v0.2.9 effort/provider policy + the v0.3.2
# router. It RECOMMENDS only. It NEVER:
#   - executes an adapter or makes a live/network/model-API call (optionally runs the router's --print-dispatch, which
#     returns BEFORE any subprocess.run — provider-router.py:130-136 — so it executes nothing);
#   - infers anything from env/secrets: candidates are a pure function of (task JSON + policy) ONLY. The selector reads
#     NO env var and NO .env*/credential file; live providers are proposed as GATED options, never "available because a
#     key is set". (The python helpers read their inputs via argv/files, never os.environ.)
#   - stages / commits / pushes / grants a gate.
# Candidate set = exactly the three REGISTERED provider_targets (mirrors provider-router.py:37-42). `mock` is NOT a
# candidate — it is the default offline RUN-MODE of glm-api/oauth-cli (the router refuses type 'mock',
# provider-router.py:58-59). Offline-first: manual_import (offline-by-construction) ranks above the live-capable
# glm-api/oauth-cli; for the live-capable pair "offline vs live" is a per-candidate run_mode (default mock; --live gated).
# Fail-closed: classifier absent / stop_and_ask=true / protected|credential|live signal => human-gate-required, NO live
# run_mode presented as a no-gate default.
#
# Usage:  selector.sh --task <task.json> [--out <file>] [--dispatch-check]
#         selector.sh --self-test
# Exit: 0 = selection emitted, 2 = usage/refused. (Advisory — the exit code must never be wired to an action.)
set -u
set -o pipefail
export PYTHONDONTWRITEBYTECODE=1

ROOTDIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SELFPATH="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/$(basename "$0")"
# Composed components (plain shell variables — NOT env-overridable from argv; self-test reassigns them internally only).
CLASSIFIER="$ROOTDIR/.harness/evidence/dmc-v0.2.8-task-intake-classifier.sh"
ROUTER="$ROOTDIR/.claude/workers/providers/provider-router.py"

# --- --out write-target guard (verbatim reuse of the v0.2.8 canonicalized guard; refuse protected/secret/traversal) ---
PROT_RE='(^|/)(\.env)(\.|$)|\.pem$|\.key$|id_rsa|id_ed25519|credentials|secret|\.p12$|\.pfx$|\.keystore$|\.claude/hooks|provider-router\.py|/ROUTING\.md$|WORKER_(TASK|RESULT|REVIEW)_SCHEMA\.md|PROVIDER_CONTRACT\.md|workers/providers/(glm-api|oauth-cli)|(^|/)dmc-glm-smoke$'
out_refused() { # path -> 0 if must refuse
  local raw="$1"
  # v0.3.4 hardening (matches the v0.3.1 manual-import adapter): refuse ANY `..` path component outright, BEFORE
  # canonicalization — a benign-RESOLVING `dir/../out.json` must not slip past the protected/secret check.
  printf '%s' "$raw" | grep -qE '(^|/)\.\.(/|$)' && return 0
  printf '%s' "$raw" | grep -qiE "$PROT_RE" && return 0
  case "$raw" in *.env|*.env.local|*.env.*) case "$raw" in *.example|*.sample|*.template) ;; *) return 0;; esac;; esac
  local parent base cparent canon
  parent="$(dirname "$raw")"; base="$(basename "$raw")"
  cparent="$(cd "$parent" 2>/dev/null && pwd -P)" || return 0
  canon="$cparent/$base"
  printf '%s' "$canon" | grep -qiE "$PROT_RE" && return 0
  if [ -L "$raw" ]; then local tgt; tgt="$(readlink -f "$raw" 2>/dev/null)" || return 0; printf '%s' "$tgt" | grep -qiE "$PROT_RE" && return 0; fi
  return 1
}

# --- chokepoint router-dispatch helper: the ONLY place the router is invoked. Hard-codes --print-dispatch; NEVER passes
#     --live/--allow-network/--allow-exec/--mock/--import. The router prints the resolved argv and returns before exec. ---
router_dispatch() { # <task_fixture.json> -> exit 0 if it routes (print-dispatch ok); nonzero otherwise. Executes nothing.
  python3 "$ROUTER" --task "$1" --print-dispatch >/dev/null 2>&1
}

# --- extract the classifier description string from a task bundle (objective + context_summary), via argv (no env) ---
read_desc() { python3 - "$1" <<'PY'
import json,sys
try:
    t=json.load(open(sys.argv[1]))
except Exception:
    print(""); sys.exit(0)
if not isinstance(t,dict): print(""); sys.exit(0)
obj=t.get("objective","") or ""
ctx=t.get("context_summary","") or ""
print((str(obj)+" "+str(ctx)).strip())
PY
}

# --- emit the selection JSON. Inputs via argv/files ONLY (never os.environ). ---
#     args: <task.json> <intake.json|""> <dispatch.json|""> <dispatch_check:0|1> <fail_closed:0|1>
emit_selection() { python3 - "$1" "$2" "$3" "$4" "$5" <<'PY'
import json,sys
def load(p):
    if not p: return {}
    try: return json.load(open(p))
    except Exception: return {}
task=load(sys.argv[1]); intake=load(sys.argv[2]); disp=load(sys.argv[3])
dcheck = sys.argv[4]=="1"; failclosed = sys.argv[5]=="1"
task_id = (task.get("task_id","") or "") if isinstance(task,dict) else ""
hint = task.get("provider_target") if isinstance(task,dict) and isinstance(task.get("provider_target"),dict) else None

if failclosed:
    # classifier unavailable => recommend NOTHING (no live candidate); conservative human gate.
    print(json.dumps({
        "task_id": task_id,
        "provider_target_hint": hint,
        "intake_dimensions": ["unknown-high-ambiguity"],
        "stop_and_ask": True,
        "human_gate_required": True,
        "required_human_gates": ["approval","commit","push","staging"],
        "recommended_model_effort": "Opus; deep (fail-closed)",
        "provider_candidates": [],
        "fail_closed": True,
        "selection_basis": "classifier unavailable => fail-closed; recommend nothing (no live candidate); advisory; grants no gate; executes nothing",
    }, indent=2)); sys.exit(0)

dims = intake.get("dimensions",[]) or []
stop = bool(intake.get("stop_and_ask", True))
gates = intake.get("required_human_gates",[]) or []
depth = intake.get("required_plan_depth","")
me = {"light":"fast/simple OK; light","standard":"Opus; standard","deep":"Opus; deep"}.get(depth, "Opus; deep (fail-closed)")
# classifier sets stop_and_ask=true for every protected/credential/live/high-risk signal; that IS the human-gate driver.
human_gate_required = bool(stop)

# Candidate set = exactly the three registered provider_targets, offline-first.
#   (type, provider, run_mode, rank, rationale)
TARGETS = [
 ("manual_import","manual-import","import-only",1,
  "offline-by-construction (no live_flag; no --mock/--live; human-supplied envelope v1 via --import) — top offline-first rank"),
 ("api_key","glm-api","mock",2,
  "live-capable; default run_mode=mock (offline dry-run); --live is the GATED escalation, never a no-gate default"),
 ("oauth_cli","oauth-cli","mock",3,
  "live-capable; default run_mode=mock (offline dry-run); --live is the GATED escalation, never a no-gate default"),
]
cands=[]
for typ,prov,mode,rank,why in TARGETS:
    g=list(gates)
    if mode=="mock":  # live-capable: the live run_mode always carries the live-call gate (#5) — never a no-gate default
        g=g+["live run_mode -> #5 live-call (gated escalation; never a no-gate default)"]
    c={"type":typ,"provider":prov,"run_mode":mode,"rank":rank,"rationale":why,"gates":g}
    if dcheck:
        c["routes"]= "yes" if disp.get(prov) else "no"
    cands.append(c)

print(json.dumps({
  "task_id": task_id,
  "provider_target_hint": hint,
  "intake_dimensions": dims,
  "stop_and_ask": stop,
  "human_gate_required": human_gate_required,
  "required_human_gates": gates,
  "recommended_model_effort": me,
  "provider_candidates": cands,
  "fail_closed": False,
  "selection_basis": "task + policy (NOT env/secrets); advisory; grants no gate; executes nothing",
}, indent=2))
PY
}

# --- run the selection pipeline for a task bundle -> prints selection JSON to stdout ---
select_for() { # <task.json> <dispatch_check:0|1>
  local taskfile="$1" dcheck="$2"
  local TMP; TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' RETURN
  local intake="" dispatch="" failclosed=0

  # 1. classifier (read-only). Fail-closed if the binary is missing or errors.
  if [ -f "$CLASSIFIER" ]; then
    local desc; desc="$(read_desc "$taskfile")"
    if [ -n "$desc" ] && bash "$CLASSIFIER" --task "$desc" --out "$TMP/intake.json" 2>/dev/null; then
      intake="$TMP/intake.json"
    else
      failclosed=1
    fi
  else
    failclosed=1
  fi

  # 2. optional dispatch-check (mock-only, executes nothing): per-candidate fixture -> chokepoint router_dispatch.
  if [ "$dcheck" = 1 ] && [ "$failclosed" = 0 ]; then
    : > "$TMP/disp.json"
    python3 - "$TMP/disp.json" <<'PY'
import json,sys
json.dump({}, open(sys.argv[1],"w"))
PY
    local typ prov pair
    for pair in "manual_import:manual-import" "api_key:glm-api" "oauth_cli:oauth-cli"; do
      typ="${pair%%:*}"; prov="${pair##*:}"
      printf '{"provider_target":{"type":"%s","provider":"%s"}}\n' "$typ" "$prov" > "$TMP/fix.json"
      if router_dispatch "$TMP/fix.json"; then
        python3 - "$TMP/disp.json" "$prov" 1 <<'PY'
import json,sys
d=json.load(open(sys.argv[1])); d[sys.argv[2]]= sys.argv[3]=="1"; json.dump(d,open(sys.argv[1],"w"))
PY
      else
        python3 - "$TMP/disp.json" "$prov" 0 <<'PY'
import json,sys
d=json.load(open(sys.argv[1])); d[sys.argv[2]]= sys.argv[3]=="1"; json.dump(d,open(sys.argv[1],"w"))
PY
      fi
    done
    dispatch="$TMP/disp.json"
  fi

  # 3. emit
  emit_selection "$taskfile" "$intake" "$dispatch" "$dcheck" "$failclosed"
}

# ---------------------------------------------------------------- self-test (no in-repo writes; $TMPDIR only)
self_test() {
  local P=0 F=0; ok(){ echo "  PASS $1"; P=$((P+1)); }; no(){ echo "  FAIL $1"; F=$((F+1)); }
  local TT; TT="$(mktemp -d)"; trap 'rm -rf "$TT"' RETURN

  # fixtures
  printf '%s' '{"task_id":"docs-1","objective":"update the README handbook onboarding docs","context_summary":"clarify wording"}'    > "$TT/docs.json"
  printf '%s' '{"task_id":"adp-1","objective":"modify the glm-api adapter mapping","context_summary":"protected surface"}'           > "$TT/adapter.json"
  printf '%s' '{"task_id":"live-1","objective":"run a live GLM provider call using the .env credential api key","context_summary":"x"}' > "$TT/live.json"

  # AC3 — boundary tuples pinned inline (a wrong policy mapping FAILS)
  local d_docs d_adp d_live
  d_docs="$(select_for "$TT/docs.json" 0)"
  d_adp="$(select_for "$TT/adapter.json" 0)"
  d_live="$(select_for "$TT/live.json" 0)"
  # (i) docs-only: stop=false, NO #7 gate, manual_import rank1 + glm/oauth mock run_mode ranked offline-first
  printf '%s' "$d_docs" | python3 -c '
import json,sys
o=json.load(sys.stdin); g=o["required_human_gates"]; c={x["provider"]:x for x in o["provider_candidates"]}
assert o["stop_and_ask"] is False, "docs stop"
assert "schema/guard/hook/validator/adapter/router" not in g, "docs has #7"
assert c["manual-import"]["rank"]==1 and c["manual-import"]["run_mode"]=="import-only", "manual rank/mode"
assert c["glm-api"]["run_mode"]=="mock" and c["oauth-cli"]["run_mode"]=="mock", "live-capable mock default"
assert c["manual-import"]["rank"] < c["glm-api"]["rank"] and c["manual-import"]["rank"] < c["oauth-cli"]["rank"], "offline-first"
assert o["human_gate_required"] is False, "docs no human gate"
' && ok "AC3(i) docs-only: stop=false, no #7, manual_import rank1 + live-capable mock, offline-first" || no "AC3(i) docs-only"
  # (ii) adapter/protected: stop=true, human-gate-required, #7 present
  printf '%s' "$d_adp" | python3 -c '
import json,sys
o=json.load(sys.stdin)
assert o["stop_and_ask"] is True, "adapter stop"
assert o["human_gate_required"] is True, "adapter human gate"
assert "schema/guard/hook/validator/adapter/router" in o["required_human_gates"], "adapter #7 missing"
' && ok "AC3(ii) adapter/protected: stop=true, human-gate-required (#7)" || no "AC3(ii) adapter/protected"
  # (iii) live/credential: stop=true, live/credential gate flagged, live candidate carries live run_mode gate (no no-gate default)
  printf '%s' "$d_live" | python3 -c '
import json,sys
o=json.load(sys.stdin); g=o["required_human_gates"]; c={x["provider"]:x for x in o["provider_candidates"]}
assert o["stop_and_ask"] is True, "live stop"
assert ("live-call" in g) or ("credential" in g), "live/credential gate missing"
for p in ("glm-api","oauth-cli"):
    assert any("#5 live-call" in s for s in c[p]["gates"]), "%s live run_mode no-gate default" % p
' && ok "AC3(iii) live/credential: stop=true, #5/#6 flagged, no live-no-gate default" || no "AC3(iii) live/credential"

  # AC1(a) — repo byte-unchanged via git-status md5 pre/post is asserted at the END (M-final). Establish baseline now.
  local PRE; PRE="$SELF_PRESTATUS"

  # AC4 + AC1(b) — chokepoint helper: ALWAYS --print-dispatch, NEVER forbidden flags; behavioral no-exec SENTINEL.
  cat > "$TT/sentinel.py" <<'PY'
import json,sys
argv=sys.argv[1:]
json.dump(argv, open("__ARGVFILE__","w"))
if "--print-dispatch" in argv:
    print(json.dumps({"routes":"yes"})); sys.exit(0)
# would-be EXECUTION path: if the helper ever omits --print-dispatch, this marker proves an adapter could have run.
open("__PWNED__","w").write("x"); sys.exit(0)
PY
  sed -i.bak "s#__ARGVFILE__#$TT/argv.json#; s#__PWNED__#$TT/PWNED#" "$TT/sentinel.py" && rm -f "$TT/sentinel.py.bak"
  printf '%s' '{"provider_target":{"type":"api_key","provider":"glm-api"}}' > "$TT/fix.json"
  local SAVED_ROUTER="$ROUTER"
  ROUTER="$TT/sentinel.py"; router_dispatch "$TT/fix.json" >/dev/null 2>&1; ROUTER="$SAVED_ROUTER"
  if [ ! -e "$TT/PWNED" ] && [ -f "$TT/argv.json" ] \
     && python3 -c '
import json,sys
a=json.load(open(sys.argv[1]))
assert "--print-dispatch" in a, "missing --print-dispatch"
for bad in ("--live","--allow-network","--allow-exec","--mock","--import"):
    assert bad not in a, "forbidden flag "+bad
' "$TT/argv.json"; then
    ok "AC1(b)+AC4 chokepoint: argv always has --print-dispatch, never forbidden flags; no-exec marker never produced"
  else no "AC1(b)+AC4 chokepoint helper (PWNED=$( [ -e "$TT/PWNED" ] && echo yes || echo no))"; fi

  # AC1(b) — REAL router --print-dispatch is genuinely non-exec (routes a valid target, executes nothing, repo unchanged)
  local rmid_pre rmid_post
  rmid_pre="$(git -C "$ROOTDIR" status --porcelain 2>/dev/null | md5)"
  if router_dispatch "$TT/fix.json"; then
    rmid_post="$(git -C "$ROOTDIR" status --porcelain 2>/dev/null | md5)"
    [ "$rmid_pre" = "$rmid_post" ] && ok "AC1(b) real router --print-dispatch routes glm-api + executes nothing (repo unchanged)" || no "AC1(b) real router mutated repo"
  else no "AC1(b) real router --print-dispatch did not route glm-api"; fi

  # AC2 PRIMARY — env -i (empty env; PATH/HOME preserved so python3/bash/git resolve) byte-identical candidate output
  local base envi
  base="$(bash "$SELFPATH" --task "$TT/docs.json")"
  envi="$(env -i PATH="$PATH" HOME="${HOME:-/tmp}" bash "$SELFPATH" --task "$TT/docs.json")"
  [ -n "$base" ] && [ "$base" = "$envi" ] && ok "AC2 PRIMARY env -i: candidate output independent of ALL env (byte-identical)" || no "AC2 env -i differs"

  # AC2 DIFFERENTIAL — per credential-var, across {unset, short-dummy, secret-shaped-realistic, second realistic}
  local diff_ok=1 v val
  for v in GLM_API_KEY DMC_OAUTHCLI_BIN ANTHROPIC_API_KEY OPENAI_API_KEY ZHIPUAI_API_KEY; do
    for val in "x" "sk-ant-api03-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" "ghp_BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"; do
      local got; got="$(env "$v=$val" bash "$SELFPATH" --task "$TT/docs.json")"
      [ "$got" = "$base" ] || { diff_ok=0; break 2; }
    done
  done
  [ "$diff_ok" = 1 ] && ok "AC2 DIFFERENTIAL: 5 credential vars x {unset,dummy,realistic,realistic2} -> byte-identical" || no "AC2 differential leak (var=$v)"

  # AC2 STRUCTURAL / AC1 source — audit CODE positions ONLY: strip comment lines (bash + python `#`) first, so a
  # docstring mention of a forbidden token (e.g. this header's "never os.environ" / "before any subprocess.run") cannot
  # false-fail (the round-1 critic's pattern-string-vs-real-read concern). The selector uses NO credential token even as
  # a pattern string, so comment-stripping is sufficient; the audits' own grep-pattern lines do not self-match because
  # the source writes `os\.`/`subprocess\.` (backslash-dot), which the literal-`.` regexes do not match.
  local STRIP="$TT/stripped.src"; grep -vE '^[[:space:]]*#' "$SELFPATH" > "$STRIP"
  if ! grep -nE 'os\.environ|os\.getenv|getenv\(' "$STRIP" >/dev/null \
     && ! grep -nE '\$\{?(GLM_API_KEY|DMC_OAUTHCLI_BIN|ANTHROPIC_API_KEY|OPENAI_API_KEY|ZHIPUAI_API_KEY)' "$STRIP" >/dev/null; then
    ok "AC2 STRUCTURAL: no environment read (environ/getenv); no credential-var expansion (code positions; no whitelist needed)"
  else no "AC2 STRUCTURAL: an env/credential read is present"; fi
  # AC1 source — no bare adapter/router process-spawn (router reached ONLY via the --print-dispatch chokepoint helper)
  if ! grep -nE 'subprocess\.(run|call|Popen)' "$STRIP" >/dev/null; then
    ok "AC1 source: selector spawns no adapter/router process directly (router reached only via the --print-dispatch chokepoint helper)"
  else no "AC1 source: a bare process-spawn is present in the selector"; fi

  # AC2 — decoy .env in cwd is never opened / leaked
  ( cd "$TT" && printf 'SENTINEL_LEAK_%s\n' "$$" > .env )
  local outd; outd="$( cd "$TT" && bash "$SELFPATH" --task "$TT/docs.json" )"
  ! printf '%s' "$outd" | grep -q 'SENTINEL_LEAK' && ok "AC2 decoy .env: sentinel never read/emitted (no .env access)" || no "AC2 decoy .env leaked"

  # AC4 — --dispatch-check end-to-end annotates the 3 routable candidates routes=yes (real router; executes nothing)
  local dc; dc="$(select_for "$TT/docs.json" 1)"
  printf '%s' "$dc" | python3 -c '
import json,sys
o=json.load(sys.stdin); c={x["provider"]:x for x in o["provider_candidates"]}
for p in ("manual-import","glm-api","oauth-cli"):
    assert c[p].get("routes")=="yes", "%s routes != yes" % p
' && ok "AC4 --dispatch-check: all 3 routable candidates annotated routes=yes (executes nothing)" || no "AC4 dispatch-check"

  # AC5 — fail-closed: classifier absent => fail_closed + NO live candidate (recommend nothing)
  local SAVED_CL="$CLASSIFIER"
  CLASSIFIER="$TT/nonexistent-classifier.sh"
  local fc; fc="$(select_for "$TT/docs.json" 0)"; CLASSIFIER="$SAVED_CL"
  printf '%s' "$fc" | python3 -c '
import json,sys
o=json.load(sys.stdin)
assert o.get("fail_closed") is True, "not fail_closed"
assert o["provider_candidates"]==[], "fail-closed emitted a candidate"
assert o["human_gate_required"] is True and o["stop_and_ask"] is True, "fail-closed not conservative"
' && ok "AC5 fail-closed: classifier absent => recommend nothing (no live candidate), conservative gate" || no "AC5 fail-closed (classifier absent)"

  # AC6 — --out guard: protected/secret/traversal(incl benign-resolving ..)/symlink refused; benign allowed
  mkdir -p "$TT/sub"
  out_refused ".env" && out_refused ".claude/hooks/secret-guard.sh" && out_refused "x/../.claude/workers/providers/glm-api/y" \
    && out_refused "PROVIDER_CONTRACT.md" && out_refused "provider-router.py" \
    && out_refused "$TT/sub/../benign.json" \
    && { mkdir -p "$TT/p"; ln -sf "$ROOTDIR/.claude/hooks" "$TT/p/hooks" 2>/dev/null; out_refused "$TT/p/hooks/x"; } \
    && ! out_refused "$TT/benign.json" && ok "AC6 --out guard: protected/secret/traversal(incl benign ..)/symlink refused, benign allowed" || no "AC6 --out guard"

  # AC1(a) FINAL — the whole self-test mutated nothing in the real repo
  local st; st="$(git -C "$ROOTDIR" status --porcelain 2>/dev/null | md5)"
  [ "$st" = "$PRE" ] && ok "AC1(a) self-test mutated nothing in the real repo (git-status md5 pre==post)" || no "AC1(a) repo changed during self-test"

  echo "  ---- self-test: PASS=$P FAIL=$F ----"; [ "$F" = 0 ]
}

# --- args ---
TASK=""; OUT=""; DCHECK=0; MODE=run
while [ $# -gt 0 ]; do case "$1" in
  --task) TASK="$2"; shift 2;; --out) OUT="$2"; shift 2;; --dispatch-check) DCHECK=1; shift;;
  --self-test) MODE=selftest; shift;; -h|--help) sed -n '2,28p' "$0"; exit 0;;
  *) echo "provider-selector: unknown arg $1" >&2; exit 2;;
esac; done

if [ "$MODE" = selftest ]; then
  echo "==== DMC PROVIDER SELECTION RUNNER — SELF-TEST (no in-repo writes; \$TMPDIR only) ===="
  SELF_PRESTATUS="$(git -C "$ROOTDIR" status --porcelain 2>/dev/null | md5)"
  self_test; exit $?
fi

[ -n "$TASK" ] || { echo "provider-selector: --task <task.json> required" >&2; exit 2; }
[ -f "$TASK" ] || { echo "provider-selector: --task file not found: $TASK" >&2; exit 2; }
if [ -n "$OUT" ]; then
  if out_refused "$OUT"; then echo "provider-selector: --out target is a protected/secret path — REFUSED (writing nothing)" >&2; exit 2; fi
fi

SEL="$(select_for "$TASK" "$DCHECK")"
if [ -n "$OUT" ]; then printf '%s\n' "$SEL" > "$OUT"; echo "provider-selector: wrote $OUT" >&2; else printf '%s\n' "$SEL"; fi
exit 0
