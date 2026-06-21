#!/usr/bin/env bash
# DMC Execution Manifest v2 generator (v0.3.5) — ADVISORY / READ-ONLY.
#
# From a task BUNDLE, emits a SINGLE forward-looking Execution Manifest (v2) binding everything needed to execute a
# milestone safely: task, proposed provider_target, selected adapter, verification expectations, required human gates,
# and closure criteria. It composes the v0.3.4 provider selector (which composes the v0.2.8 classifier + v0.2.9 policy +
# the router). It has NO execution side effects:
#   - executes no adapter and makes no live/network call (the ONLY router call is a single --print-dispatch chokepoint,
#     which the router answers BEFORE any process spawn — provider-router.py:133 returns before :136);
#   - infers nothing from env/secrets: the manifest is a pure function of (task + policy), inherited from the v0.3.4
#     selector; this generator reads NO env var and NO .env*/credential file (python helpers read inputs via argv/files);
#   - embeds NO git hash / ahead-count / wall-clock (that is the v0.2.7 v1 RUN RECORDER's lane) — v2 is forward-looking
#     and deterministic;
#   - selects/stages/commits/pushes NOTHING and grants no gate.
# Gating: low-risk => executable_default true; high-risk (human_gate_required) => still proposes the offline-first
# manual_import but executable_default false (gated); classifier-absent/fail-closed => proposed null, blocked true,
# recommend nothing.
#
# Usage:  manifest.sh --task <task.json> [--milestone <id>] [--verify-script <path>] [--out <file>]
#         manifest.sh --self-test
# Exit: 0 = manifest emitted, 2 = usage/refused. (Advisory — the exit code must never be wired to an action.)
set -u
set -o pipefail
export PYTHONDONTWRITEBYTECODE=1

ROOTDIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SELFPATH="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/$(basename "$0")"
# Composed components (plain shell variables — NOT env/argv-overridable; the self-test reassigns them internally only).
SELECTOR="$ROOTDIR/.harness/evidence/dmc-v0.3.4-provider-selector.sh"
ROUTER="$ROOTDIR/.claude/workers/providers/provider-router.py"

# --- --out write-target guard (v0.3.4 hardened: refuse ANY `..` component first, then protected/secret/symlink) ---
PROT_RE='(^|/)(\.env)(\.|$)|\.pem$|\.key$|id_rsa|id_ed25519|credentials|secret|\.p12$|\.pfx$|\.keystore$|\.claude/hooks|provider-router\.py|/ROUTING\.md$|WORKER_(TASK|RESULT|REVIEW)_SCHEMA\.md|PROVIDER_CONTRACT\.md|workers/providers/(glm-api|oauth-cli)|(^|/)dmc-glm-smoke$'
out_refused() { # path -> 0 if must refuse
  local raw="$1"
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

# --- single router chokepoint: hard-codes --print-dispatch; NEVER passes --live/--allow-network/--allow-exec/--mock/
#     --import. Prints the raw --print-dispatch JSON ({type,provider,adapter,argv}) on stdout. Executes nothing. ---
router_print_dispatch() { # <task_fixture.json> -> the --print-dispatch JSON (exit reflects the router)
  python3 "$ROUTER" --task "$1" --print-dispatch
}

# --- assemble the manifest. Inputs via argv/files ONLY (never the environment). ---
#     args: <task.json> <selection.json|""> <adapter.txt|""> <verify_script|""> <milestone|""> <selector_present:0|1>
emit_manifest() { python3 - "$1" "$2" "$3" "$4" "$5" "$6" <<'PY'
import json,sys
def load(p):
    if not p: return {}
    try: return json.load(open(p))
    except Exception: return {}
task=load(sys.argv[1])
sel = load(sys.argv[2]) if sys.argv[2] else {}
adapter=""
if sys.argv[3]:
    try: adapter=open(sys.argv[3]).read().strip()
    except Exception: adapter=""
verify_script=sys.argv[4] or ""
milestone=sys.argv[5] or ""
selector_present = sys.argv[6]=="1"

task_id=(task.get("task_id","") or "") if isinstance(task,dict) else ""
hint = task.get("provider_target") if isinstance(task,dict) and isinstance(task.get("provider_target"),dict) else None
if not milestone: milestone = task_id or "unspecified"

cands = sel.get("provider_candidates",[]) if isinstance(sel,dict) else []
fail_closed = (not selector_present) or bool(sel.get("fail_closed", True)) or (len(cands)==0)
human_gate_required = bool(sel.get("human_gate_required", True))
gates = sel.get("required_human_gates",[]) if isinstance(sel,dict) else []

if fail_closed:
    proposed=None; selected_adapter=None; executable_default=False; blocked=True; human_gate_required=True
else:
    top = sorted(cands, key=lambda c: c.get("rank",99))[0]           # rank 1 = offline-first manual_import
    proposed = {"type":top.get("type"),"provider":top.get("provider"),"run_mode":top.get("run_mode")}
    selected_adapter = adapter or None
    blocked=False
    executable_default = (not human_gate_required)                   # gated high-risk => false; low-risk => true

manifest={
  "manifest_version":"v2",
  "milestone":milestone,
  "task":{
    "task_id":task_id,
    "objective":(task.get("objective","") if isinstance(task,dict) else ""),
    "context_summary":(task.get("context_summary","") if isinstance(task,dict) else ""),
    "provider_target_hint":hint,
  },
  "selection": sel if sel else {"fail_closed":True},
  "proposed_provider_target": proposed,
  "selected_adapter": selected_adapter,
  "executable_default": executable_default,
  "blocked": blocked,
  "human_gate_required": human_gate_required,
  "verification_expectations":{
    "self_test_or_harness": verify_script if verify_script else "verification required",
    "must_pass": True,
    "gate_check": "required (stage/commit/push)",
    "codex_audit": "required before stage/commit/push",
  },
  "required_human_gates": gates,
  "closure_criteria": ["verified","reviewed","committed","pushed","closure-recorded"],
  "side_effects": "none (read-only; executes nothing; grants no gate)",
  "basis": "composed from the v0.3.4 selector (task+policy, NOT env/secrets); advisory; grants no gate; executes nothing",
}
print(json.dumps(manifest, indent=2))
PY
}

# --- generate the v2 manifest for a task bundle -> prints manifest JSON to stdout ---
generate_manifest() { # <task.json> <verify_script|""> <milestone|"">
  local taskfile="$1" vscript="$2" milestone="$3"
  local TMP; TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' RETURN
  local selpresent=0 selfile="" adapterfile=""

  # 1. selection via the v0.3.4 selector (read-only). Selector absent => fail-closed; selector error => empty selection.
  if [ -f "$SELECTOR" ]; then
    selpresent=1
    if bash "$SELECTOR" --task "$taskfile" > "$TMP/sel.json" 2>/dev/null; then selfile="$TMP/sel.json"; else selfile=""; fi
  fi

  # 2. selected_adapter via ONE --print-dispatch chokepoint, only for a non-fail-closed rank-1 candidate.
  if [ -n "$selfile" ]; then
    local prov; prov="$(python3 - "$selfile" <<'PY'
import json,sys
try:
    s=json.load(open(sys.argv[1])); c=s.get("provider_candidates",[])
    if c and not s.get("fail_closed",False):
        top=sorted(c,key=lambda x:x.get("rank",99))[0]
        print("%s|%s"%(top.get("type",""),top.get("provider","")))
except Exception: pass
PY
)"
    if [ -n "$prov" ]; then
      local t="${prov%%|*}" p="${prov##*|}"
      printf '{"provider_target":{"type":"%s","provider":"%s"}}\n' "$t" "$p" > "$TMP/fix.json"
      router_print_dispatch "$TMP/fix.json" 2>/dev/null | python3 -c 'import json,sys
try: sys.stdout.write(json.load(sys.stdin).get("adapter","") or "")
except Exception: pass' > "$TMP/adapter.txt"
      adapterfile="$TMP/adapter.txt"
    fi
  fi

  # 3. emit
  emit_manifest "$taskfile" "$selfile" "$adapterfile" "$vscript" "$milestone" "$selpresent"
}

# ---------------------------------------------------------------- self-test (no in-repo writes; $TMPDIR only)
self_test() {
  local P=0 F=0; ok(){ echo "  PASS $1"; P=$((P+1)); }; no(){ echo "  FAIL $1"; F=$((F+1)); }
  local TT; TT="$(mktemp -d)"; trap 'rm -rf "$TT"' RETURN
  local PRE; PRE="$SELF_PRESTATUS"

  # fixtures
  printf '%s' '{"task_id":"docs-1","objective":"update the README handbook onboarding docs","context_summary":"clarify wording"}'    > "$TT/docs.json"
  printf '%s' '{"task_id":"adp-1","objective":"modify the glm-api adapter mapping","context_summary":"protected surface"}'           > "$TT/adapter.json"
  printf '%s' '{"task_id":"live-1","objective":"run a live GLM provider call using the .env credential api key","context_summary":"x"}' > "$TT/live.json"
  local AD='.claude/workers/providers/manual-import/manual-import-adapter.py'

  local m_docs m_adp m_live
  m_docs="$(generate_manifest "$TT/docs.json" "" "")"
  m_adp="$(generate_manifest "$TT/adapter.json" "" "")"
  m_live="$(generate_manifest "$TT/live.json" ".harness/evidence/dmc-v0.3.5-execution-manifest.sh" "")"

  # AC3(i) docs-only — pinned tuple
  printf '%s' "$m_docs" | python3 -c '
import json,sys
o=json.load(sys.stdin); p=o["proposed_provider_target"]
assert o["manifest_version"]=="v2"
assert p["type"]=="manual_import" and p["provider"]=="manual-import" and p["run_mode"]=="import-only", "proposed"
assert o["selected_adapter"] and o["selected_adapter"].endswith(sys.argv[1]), "adapter path"
assert o["human_gate_required"] is False and o["executable_default"] is True and o["blocked"] is False, "gating"
assert "schema/guard/hook/validator/adapter/router" not in o["required_human_gates"], "docs has #7"
' "$AD" && ok "AC3(i) docs-only: proposed=manual_import import-only, adapter pinned, executable_default=true, no #7" || no "AC3(i) docs-only"
  # AC3(ii) adapter-protected — proposed NOT null, gated, #7
  printf '%s' "$m_adp" | python3 -c '
import json,sys
o=json.load(sys.stdin); p=o["proposed_provider_target"]
assert p is not None and p["type"]=="manual_import", "proposed not null"
assert o["human_gate_required"] is True and o["executable_default"] is False and o["blocked"] is False, "gating"
assert "schema/guard/hook/validator/adapter/router" in o["required_human_gates"], "#7 missing"
' && ok "AC3(ii) adapter-protected: proposed=manual_import (NOT null), gated (exec_default=false), #7 present" || no "AC3(ii) adapter-protected"
  # AC3(iii) live-credential — gated, #5 on live candidates, proposed offline-first
  printf '%s' "$m_live" | python3 -c '
import json,sys
o=json.load(sys.stdin); c={x["provider"]:x for x in o["selection"]["provider_candidates"]}
assert o["human_gate_required"] is True and o["executable_default"] is False, "gating"
assert o["proposed_provider_target"]["type"]=="manual_import", "offline-first proposed"
for q in ("glm-api","oauth-cli"):
    assert any("#5 live-call" in s for s in c[q]["gates"]), "%s no live #5" % q
' && ok "AC3(iii) live-credential: gated, #5 on live candidates, proposed offline-first" || no "AC3(iii) live-credential"

  # AC4 — selected_adapter equals the --print-dispatch adapter realpath; chokepoint argv hard-coded + behavioral sentinel
  printf '%s' "$m_docs" | python3 -c '
import json,sys,os
o=json.load(sys.stdin); a=o["selected_adapter"]
assert a and a.endswith(sys.argv[1]) and os.path.isabs(a), "adapter realpath"
' "$AD" && ok "AC4 selected_adapter = router --print-dispatch adapter realpath (manual-import-adapter.py)" || no "AC4 adapter path"
  cat > "$TT/sentinel.py" <<'PY'
import json,sys
argv=sys.argv[1:]
json.dump(argv, open("__ARGVFILE__","w"))
if "--print-dispatch" in argv:
    print(json.dumps({"type":"manual_import","provider":"manual-import","adapter":"/x/manual-import-adapter.py","argv":[]})); sys.exit(0)
open("__PWNED__","w").write("x"); sys.exit(0)
PY
  sed -i.bak "s#__ARGVFILE__#$TT/argv.json#; s#__PWNED__#$TT/PWNED#" "$TT/sentinel.py" && rm -f "$TT/sentinel.py.bak"
  printf '%s' '{"provider_target":{"type":"manual_import","provider":"manual-import"}}' > "$TT/fix.json"
  local SAVED_ROUTER="$ROUTER"
  ROUTER="$TT/sentinel.py"; router_print_dispatch "$TT/fix.json" >/dev/null 2>&1; ROUTER="$SAVED_ROUTER"
  if [ ! -e "$TT/PWNED" ] && [ -f "$TT/argv.json" ] && python3 -c '
import json,sys
a=json.load(open(sys.argv[1]))
assert "--print-dispatch" in a, "missing --print-dispatch"
for bad in ("--live","--allow-network","--allow-exec","--mock","--import"):
    assert bad not in a, "forbidden flag "+bad
' "$TT/argv.json"; then
    ok "AC1(b)+AC4 chokepoint: argv always --print-dispatch, never forbidden flags; no-exec marker never produced"
  else no "AC1(b)+AC4 chokepoint (PWNED=$( [ -e "$TT/PWNED" ] && echo yes || echo no))"; fi

  # AC1(b) — real router --print-dispatch routes manual_import + executes nothing (repo unchanged across the call)
  local rp rq
  rp="$(git -C "$ROOTDIR" status --porcelain 2>/dev/null | md5)"
  router_print_dispatch "$TT/fix.json" >/dev/null 2>&1
  rq="$(git -C "$ROOTDIR" status --porcelain 2>/dev/null | md5)"
  [ "$rp" = "$rq" ] && ok "AC1(b) real router --print-dispatch executes nothing (repo unchanged)" || no "AC1(b) real router mutated repo"

  # AC2 PRIMARY — env -i (PATH/HOME preserved) byte-identical manifest
  local base envi
  base="$(bash "$SELFPATH" --task "$TT/docs.json")"
  envi="$(env -i PATH="$PATH" HOME="${HOME:-/tmp}" bash "$SELFPATH" --task "$TT/docs.json")"
  [ -n "$base" ] && [ "$base" = "$envi" ] && ok "AC2 PRIMARY env -i: manifest independent of ALL env (byte-identical)" || no "AC2 env -i differs"
  # AC2 DIFFERENTIAL — per credential-var across {dummy, realistic, realistic2}
  local diff_ok=1 v val
  for v in GLM_API_KEY DMC_OAUTHCLI_BIN ANTHROPIC_API_KEY OPENAI_API_KEY ZHIPUAI_API_KEY; do
    for val in "x" "sk-ant-api03-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" "ghp_BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB"; do
      local got; got="$(env "$v=$val" bash "$SELFPATH" --task "$TT/docs.json")"
      [ "$got" = "$base" ] || { diff_ok=0; break 2; }
    done
  done
  [ "$diff_ok" = 1 ] && ok "AC2 DIFFERENTIAL: 5 credential vars x {dummy,realistic,realistic2} -> byte-identical" || no "AC2 differential leak (var=$v)"
  # AC2 STRUCTURAL — audit CODE positions only (comment-stripped); generator source has no environment read / no cred expansion
  local STRIP="$TT/stripped.src"; grep -vE '^[[:space:]]*#' "$SELFPATH" > "$STRIP"
  if ! grep -nE 'os\.environ|os\.getenv|getenv\(' "$STRIP" >/dev/null \
     && ! grep -nE '\$\{?(GLM_API_KEY|DMC_OAUTHCLI_BIN|ANTHROPIC_API_KEY|OPENAI_API_KEY|ZHIPUAI_API_KEY)' "$STRIP" >/dev/null; then
    ok "AC2 STRUCTURAL: generator source has no environment read (environ/getenv); no credential-var expansion"
  else no "AC2 STRUCTURAL: an env/credential read is present"; fi
  if ! grep -nE 'subprocess\.(run|call|Popen)' "$STRIP" >/dev/null; then
    ok "AC1 source: generator spawns no adapter/router process via a python process-spawn (router reached only via --print-dispatch)"
  else no "AC1 source: a bare process-spawn is present in the generator"; fi
  # AC2 decoy .env in cwd never read/leaked
  ( cd "$TT" && printf 'SENTINEL_LEAK_%s\n' "$$" > .env )
  local outd; outd="$( cd "$TT" && bash "$SELFPATH" --task "$TT/docs.json" )"
  ! printf '%s' "$outd" | grep -q 'SENTINEL_LEAK' && ok "AC2 decoy .env: sentinel never read/emitted" || no "AC2 decoy .env leaked"

  # AC5 — fail-closed: a fail_closed selector (stub) => proposed null, blocked, no executable default
  cat > "$TT/stub-selector.sh" <<'PY'
#!/usr/bin/env bash
echo '{"fail_closed":true,"provider_candidates":[],"stop_and_ask":true,"human_gate_required":true,"required_human_gates":["approval","commit","push","staging"]}'
PY
  chmod +x "$TT/stub-selector.sh"
  local SAVED_SEL="$SELECTOR"
  SELECTOR="$TT/stub-selector.sh"; local fc; fc="$(generate_manifest "$TT/docs.json" "" "")"; SELECTOR="$SAVED_SEL"
  printf '%s' "$fc" | python3 -c '
import json,sys
o=json.load(sys.stdin)
assert o["proposed_provider_target"] is None and o["selected_adapter"] is None, "not null"
assert o["blocked"] is True and o["human_gate_required"] is True and o["executable_default"] is False, "not conservative"
' && ok "AC5 fail-closed: selector fail_closed => proposed null, blocked, no executable default" || no "AC5 fail-closed"
  # AC5b — selector binary absent => fail-closed too
  SELECTOR="$TT/nonexistent-selector.sh"; local fc2; fc2="$(generate_manifest "$TT/docs.json" "" "")"; SELECTOR="$SAVED_SEL"
  printf '%s' "$fc2" | python3 -c '
import json,sys
o=json.load(sys.stdin)
assert o["proposed_provider_target"] is None and o["blocked"] is True, "selector-absent not fail-closed"
' && ok "AC5b fail-closed: selector binary absent => proposed null, blocked" || no "AC5b selector-absent"

  # AC6 — closure + verification completeness
  printf '%s' "$m_live" | python3 -c '
import json,sys
o=json.load(sys.stdin)
assert o["closure_criteria"]==["verified","reviewed","committed","pushed","closure-recorded"], "closure 5"
ve=o["verification_expectations"]
assert ve["self_test_or_harness"] and ve["must_pass"] is True and ve["gate_check"] and ve["codex_audit"], "verification expectations"
' && ok "AC6 completeness: 5 closure_criteria + verification_expectations (script,must_pass,gate_check,codex_audit)" || no "AC6 completeness"

  # AC7 — --out guard: protected/secret/traversal(incl benign ..)/symlink refused; benign allowed
  mkdir -p "$TT/sub"
  out_refused ".env" && out_refused ".claude/hooks/secret-guard.sh" && out_refused "x/../.claude/workers/providers/glm-api/y" \
    && out_refused "PROVIDER_CONTRACT.md" && out_refused "provider-router.py" \
    && out_refused "$TT/sub/../benign.json" \
    && { ln -sf "$ROOTDIR/.claude/hooks" "$TT/sub/hooks" 2>/dev/null; out_refused "$TT/sub/hooks/x"; } \
    && ! out_refused "$TT/benign.json" && ok "AC7 --out guard: protected/secret/traversal(incl benign ..)/symlink refused, benign allowed" || no "AC7 --out guard"

  # AC1(a) FINAL — the whole self-test mutated nothing in the real repo
  local st; st="$(git -C "$ROOTDIR" status --porcelain 2>/dev/null | md5)"
  [ "$st" = "$PRE" ] && ok "AC1(a) self-test mutated nothing in the real repo (git-status md5 pre==post)" || no "AC1(a) repo changed during self-test"

  echo "  ---- self-test: PASS=$P FAIL=$F ----"; [ "$F" = 0 ]
}

# --- args ---
TASK=""; OUT=""; MILESTONE=""; VSCRIPT=""; MODE=run
while [ $# -gt 0 ]; do case "$1" in
  --task) TASK="$2"; shift 2;; --milestone) MILESTONE="$2"; shift 2;; --verify-script) VSCRIPT="$2"; shift 2;;
  --out) OUT="$2"; shift 2;; --self-test) MODE=selftest; shift;; -h|--help) sed -n '2,26p' "$0"; exit 0;;
  *) echo "execution-manifest: unknown arg $1" >&2; exit 2;;
esac; done

if [ "$MODE" = selftest ]; then
  echo "==== DMC EXECUTION MANIFEST v2 — SELF-TEST (no in-repo writes; \$TMPDIR only) ===="
  SELF_PRESTATUS="$(git -C "$ROOTDIR" status --porcelain 2>/dev/null | md5)"
  self_test; exit $?
fi

[ -n "$TASK" ] || { echo "execution-manifest: --task <task.json> required" >&2; exit 2; }
[ -f "$TASK" ] || { echo "execution-manifest: --task file not found: $TASK" >&2; exit 2; }
if [ -n "$OUT" ]; then
  if out_refused "$OUT"; then echo "execution-manifest: --out target is a protected/secret path — REFUSED (writing nothing)" >&2; exit 2; fi
fi

MAN="$(generate_manifest "$TASK" "$VSCRIPT" "$MILESTONE")"
if [ -n "$OUT" ]; then printf '%s\n' "$MAN" > "$OUT"; echo "execution-manifest: wrote $OUT" >&2; else printf '%s\n' "$MAN"; fi
exit 0
