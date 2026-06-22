#!/usr/bin/env bash
# DMC Dynamic Workflow Selector (v0.5.3) — ADVISORY / READ-ONLY, deterministic, inert unless invoked.
#
# Selects the SMALLEST SUFFICIENT workflow lane from explicit TASK FACTS only (never the environment, never a repo secret
# scan). Emits {lane, required_gates, min_effort, verification_depth, reason}. Fail-CLOSED: missing/non-canonical danger
# facts and unknown task classes escalate to the max lane. STRUCTURAL monotonicity: lane = max over contributing facts,
# gates = union. Distinguishes run-mode (`mock`) from a provider_target (a provider_target of `mock` is a CATEGORY ERROR
# and is refused). Reads no env/.env/credential/token; makes no network/live call; executes nothing; mutates nothing.
# Advisory only — output is a recommendation, NOT an enforcement gate.
#
# Usage: dmc-v0.5.3-dynamic-workflow-selector.sh --task-class <c> [--changed-paths p[,p..]] [--protected-surface b]
#          [--secret-network-live b] [--provider-target <type>] [--run-mode <mock|live>] [--prior-findings N]
#          [--test-failures N] [--out <file>]   |   --from <facts.json>   |   --self-test
# Exit: 0 = recommendation emitted, 1 = category error (e.g. provider_target=mock), 2 = usage/refused.
set -u
set -o pipefail
export PYTHONDONTWRITEBYTECODE=1
SELFPATH="$(cd "$(dirname "$0")" 2>/dev/null && pwd -P)/$(basename "$0")"
ROOTDIR="$(cd "$(dirname "$SELFPATH")/../.." 2>/dev/null && pwd -P || true)"
[ -n "$ROOTDIR" ] || ROOTDIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
# deterministic internal worktree-status hash — reads NO env var and executes NO env-controlled command (python hashlib)
repo_hash() { git -C "$ROOTDIR" status --porcelain 2>/dev/null | python3 -c 'import hashlib,sys; sys.stdout.write(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())'; }

PROT_RE='(^|/)(\.env)(\.|$)|\.pem$|\.key$|id_rsa|id_ed25519|credentials|secret|\.p12$|\.pfx$|\.keystore$|\.claude/hooks|provider-router\.py'
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

decide() { # <facts.json>
  python3 - "$1" <<'PY'
import json,sys,re
try:
    f=json.load(open(sys.argv[1]))
    if not isinstance(f,dict): raise ValueError
except Exception:
    print("dynamic-workflow: invalid facts JSON", file=sys.stderr); sys.exit(2)
def b(v):
    # fail-CLOSED: anything NOT explicitly false-y is treated as true (a danger fact is never silently downgraded)
    return str(v).strip().lower() not in ("0","false","no","n","none","off","")
def num(v):
    try: return max(0,int(v))
    except Exception:
        try: return max(0,int(float(v)))
        except Exception: return None
LANES=["docs-only","additive-tooling","release-closure","recovery-resume","protected-surface","secret-network-live-risk"]
BASE={"docs-only":0,"additive-tooling":1,"release-closure":2,"recovery-resume":3,
      "protected-surface":4,"provider-adapter":4,"secret-network-live-risk":5}
# a changed PATH that touches the protected surface forces protected-surface (adapters/router/schemas/hooks/guards/validators/smoke)
PROT_PATH=re.compile(r'\.claude/workers/providers/|provider-router\.py|(^|/)ROUTING\.md$|PROVIDER_CONTRACT\.md|'
                     r'WORKER_(TASK|RESULT|REVIEW)_SCHEMA\.md|\.claude/hooks/|(^|/)dmc-glm-smoke$|'
                     r'\.harness/schemas/.*\.schema\.md$|(secret-guard|pre-tool-guard|scope-guard|stop-verify-gate)', re.IGNORECASE)
SECRET_PATH=re.compile(r'(^|/)\.env($|\.)|\.pem$|\.key$|id_rsa|id_ed25519|(^|/)credentials|\.aws/credentials|/\.ssh/', re.IGNORECASE)

tc=str(f.get("task_class","")).strip().lower()
reasons=[]
# fail-CLOSED base: unknown/missing/non-canonical task_class => max lane
if tc in BASE:
    idx=BASE[tc]; reasons.append("task_class=%s => base lane %s"%(tc,LANES[idx]))
else:
    idx=5; reasons.append("task_class '%s' unknown/missing => secret-network-live-risk (fail-closed max)"%(tc or "<none>"))

# provider_target: a provider_target of 'mock' is a CATEGORY ERROR (mock is a run-mode, not a provider target)
pt=str(f.get("provider_target","")).strip().lower()
if pt=="mock":
    print("dynamic-workflow: CATEGORY ERROR — provider_target='mock' (mock is a RUN-MODE, not a provider_target; see v0.3.4)", file=sys.stderr); sys.exit(1)
if pt and idx<4:
    idx=4; reasons.append("provider_target='%s' => protected-surface (adapter work is protected)"%pt)

# danger booleans (fail-closed)
if b(f.get("protected_surface",False)) and idx<4:
    idx=4; reasons.append("protected_surface=true => >= protected-surface")
if b(f.get("secret_network_live",False)) and idx<5:
    idx=5; reasons.append("secret_network_live=true => secret-network-live-risk (adversarial)")

# changed paths — a protected path forces protected-surface; a secret path forces secret-network-live-risk
cp=[p for p in str(f.get("changed_paths","")).split(",") if p.strip()]
for p in cp:
    if SECRET_PATH.search(p) and idx<5:
        idx=5; reasons.append("changed path '%s' is secret-bearing => secret-network-live-risk"%p)
    elif PROT_PATH.search(p) and idx<4:
        idx=4; reasons.append("changed path '%s' touches the protected surface => protected-surface"%p)

# run_mode is INFORMATIONAL only — it NEVER lowers the lane (run-mode != provider_target / != lane fact)
rm=str(f.get("run_mode","")).strip().lower()
if rm: reasons.append("run_mode=%s (informational; does not change the lane)"%rm)

lane=LANES[idx]
# min effort from lane, then escalate with prior findings / test failures (fail-closed numeric parsing)
EFF=["light","standard","deep","adversarial"]
LANE_EFF=[0,1,1,1,2,3]   # docs-only->light; additive/release/recovery->standard; protected->deep; snl->adversarial
e=LANE_EFF[idx]
findings=num(f.get("prior_findings",0)); failures=num(f.get("test_failures",0))
if findings is None: findings=2; reasons.append("prior_findings unparseable => fail-closed adversarial")
if failures is None: failures=1; reasons.append("test_failures unparseable => fail-closed escalate")
if findings>=2 and e<3: e=3; reasons.append("repeated findings (>=2) => adversarial")
elif findings==1 and e<3: e=e+1; reasons.append("one prior finding => +1 effort")
if failures>0 and e<3: e=e+1; reasons.append("test failures => +1 effort")
effort=EFF[e]
DEPTH=["markdown/style + status checks","self-test + single critic pass",
       "self-test + protected-path byte-unchanged + per-finding adversarial verify",
       "multi-agent falsification + leak scans + reject-path tests + protected-path byte-unchanged"]
depth=DEPTH[e]
# required gates (UNION) — push + closure always human-gated; protected/secret surfaces add gates
gates=["push (human gate)","closure (human gate)"]
if idx>=4: gates += ["protected-surface human gate","protected-path byte-unchanged check"]
if idx>=5 or b(f.get("secret_network_live",False)): gates += ["live-call gate","network gate","credential-access gate"]
seen=set(); gates=[g for g in gates if not (g in seen or seen.add(g))]

out=["# DMC Dynamic Workflow — lane=%s"%lane,
     "- lane: %s"%lane,
     "- min_effort: %s"%effort,
     "- verification_depth: %s"%depth,
     "- required_gates: %s"%", ".join(gates),
     "- advisory: this is a recommendation, NOT an enforcement gate (the runtime hooks remain the enforcement)",
     "- reason:"]
out += ["  - %s"%r for r in reasons]
print("\n".join(out))
PY
}

self_test() {
  local P=0 F=0; ok(){ echo "  PASS $1"; P=$((P+1)); }; no(){ echo "  FAIL $1"; F=$((F+1)); }
  local TT; TT="$(mktemp -d)"; trap 'rm -rf "$TT"' RETURN
  local PRE; PRE="$(repo_hash)"
  mk(){ printf '%s' "$1" > "$TT/in.json"; decide "$TT/in.json"; }
  lane(){ mk "$1" | awk -F': ' '/^- lane:/{print $2}'; }
  eff(){ mk "$1" | awk -F': ' '/^- min_effort:/{print $2}'; }
  laneidx(){ case "$1" in docs-only)echo 0;; additive-tooling)echo 1;; release-closure)echo 2;; recovery-resume)echo 3;; protected-surface)echo 4;; secret-network-live-risk)echo 5;; *)echo -1;; esac; }   # unknown/empty => -1 so a broken result FAILS

  # AC1 docs-only, no danger => docs-only lane / light
  local D='{"task_class":"docs-only","protected_surface":false,"secret_network_live":false}'
  { [ "$(lane "$D")" = docs-only ] && [ "$(eff "$D")" = light ]; } && ok "AC1 docs-only => lane docs-only, effort light (smallest sufficient)" || no "AC1 docs-only (lane=$(lane "$D"))"
  # AC2 additive-tooling => standard
  [ "$(lane '{"task_class":"additive-tooling"}')" = additive-tooling ] && ok "AC2 additive-tooling => lane additive-tooling" || no "AC2 additive"
  # AC3 protected_surface=true => protected-surface / deep + gates
  local PS='{"task_class":"docs-only","protected_surface":true}'
  { [ "$(lane "$PS")" = protected-surface ] && [ "$(eff "$PS")" = deep ] && mk "$PS" | grep -q 'protected-path byte-unchanged check'; } \
    && ok "AC3 protected_surface=true => protected-surface, deep, byte-unchanged gate (anti-downgrade)" || no "AC3 protected"
  # AC4 secret_network_live => secret-network-live-risk / adversarial + live/network/credential gates
  local SNL='{"task_class":"additive-tooling","secret_network_live":true}'
  { [ "$(lane "$SNL")" = secret-network-live-risk ] && [ "$(eff "$SNL")" = adversarial ] && mk "$SNL" | grep -q 'live-call gate'; } \
    && ok "AC4 secret_network_live => secret-network-live-risk, adversarial, live/network/credential gates" || no "AC4 snl"
  # AC5 a protected changed-path forces protected-surface even when task_class=docs-only (anti-downgrade)
  local CP='{"task_class":"docs-only","changed_paths":".claude/workers/providers/glm-api/x.py,docs/y.md"}'
  [ "$(lane "$CP")" = protected-surface ] && ok "AC5 protected changed-path forces protected-surface despite docs-only task_class" || no "AC5 path (lane=$(lane "$CP"))"
  # AC5b a secret changed-path forces secret-network-live-risk
  [ "$(lane '{"task_class":"docs-only","changed_paths":".env"}')" = secret-network-live-risk ] && ok "AC5b secret changed-path => secret-network-live-risk" || no "AC5b secret-path"
  # AC6 unknown task_class => fail-closed max lane
  { [ "$(lane '{"task_class":"frobnicate"}')" = secret-network-live-risk ] && [ "$(lane '{}')" = secret-network-live-risk ]; } \
    && ok "AC6 unknown/missing task_class => secret-network-live-risk (fail-closed)" || no "AC6 unknown not max"
  # AC7 non-canonical danger boolean fails CLOSED (escalates)
  { [ "$(lane '{"task_class":"additive-tooling","secret_network_live":"on"}')" = secret-network-live-risk ] \
    && [ "$(lane '{"task_class":"additive-tooling","protected_surface":"enabled"}')" = protected-surface ]; } \
    && ok "AC7 non-canonical danger boolean (on/enabled) fails CLOSED (escalates)" || no "AC7 boolean fail-open"
  # AC8 provider_target=mock => CATEGORY ERROR refused (exit 1); a real provider_target => protected-surface
  bash "$SELFPATH" --task-class docs-only --provider-target mock >/dev/null 2>&1; [ $? = 1 ] && local c1=1 || local c1=0
  [ "$(lane '{"task_class":"docs-only","provider_target":"glm-api"}')" = protected-surface ] && local c2=1 || local c2=0
  { [ "$c1" = 1 ] && [ "$c2" = 1 ]; } && ok "AC8 provider_target=mock => CATEGORY ERROR (exit 1); real provider_target => protected-surface" || no "AC8 mock/provider (c1=$c1 c2=$c2)"
  # AC9 run_mode=mock does NOT lower the lane (run-mode != lane fact)
  [ "$(lane '{"task_class":"protected-surface","run_mode":"mock"}')" = protected-surface ] && ok "AC9 run_mode=mock does NOT lower the lane" || no "AC9 run-mode lowered lane"
  # AC10 STRUCTURAL monotonicity: adding each risk fact never lowers the lane index
  local base_idx mono=1 json li
  base_idx="$(laneidx "$(lane '{"task_class":"docs-only"}')")"
  for add in '"protected_surface":true' '"secret_network_live":true' '"changed_paths":"provider-router.py"' '"provider_target":"glm-api"' '"task_class":"protected-surface"'; do
    json="{\"task_class\":\"docs-only\",$add}"   # build in a var first (avoids brace-expansion of {a,b} in nested cmd-subst)
    li="$(laneidx "$(lane "$json")")"
    { [ "$li" -ge 0 ] && [ "$li" -ge "$base_idx" ]; } || mono=0   # li=-1 (broken/empty result) => FAIL, not false-pass
  done
  [ "$mono" = 1 ] && ok "AC10 structural monotonicity: each risk fact never lowers the lane" || no "AC10 non-monotonic"
  # AC11 deterministic + env-independent
  printf '%s' "$D" > "$TT/d.json"
  local b1; b1="$(decide "$TT/d.json")"
  local envi; envi="$(env -i PATH="$PATH" HOME="${HOME:-/tmp}" bash "$SELFPATH" --from "$TT/d.json" 2>/dev/null)"
  local diff_ok=1 v
  for v in GLM_API_KEY ANTHROPIC_API_KEY OPENAI_API_KEY DMC_WORKFLOW; do
    [ "$(env "$v=secret-network-live-risk" bash "$SELFPATH" --from "$TT/d.json" 2>/dev/null)" = "$b1" ] || diff_ok=0
  done
  { [ "$envi" = "$b1" ] && [ "$diff_ok" = 1 ] && [ "$(decide "$TT/d.json")" = "$b1" ]; } && ok "AC11 deterministic + env-independent (env -i + credential differential byte-identical)" || no "AC11 env-dependent"
  # AC12 structural no-net / no-env / no-env-hash audit (own audit block + comments excluded)
  local OP; OP="$(sed '/AUDIT_BLOCK_START/,/AUDIT_BLOCK_END/d' "$SELFPATH" | grep -vE '^[[:space:]]*#')"
  # >>>AUDIT_BLOCK_START
  ! printf '%s' "$OP" | grep -nE '(^|[^A-Za-z])(curl|wget)([[:space:]])| --live | --allow-network|os\.environ|getenv|printenv|HASH_CMD|\$\{DMC_' >/dev/null \
    && ok "AC12 no curl/wget/--live, no env-read, no env-hash (DMC_HASH_CMD/\${DMC_*}) in the operative source" || no "AC12 net/env present"
  # >>>AUDIT_BLOCK_END
  # AC13 env-hash injection: hostile DMC_HASH_CMD never read/executed; repo_hash byte-identical
  # >>>AUDIT_BLOCK_START  (hostile-input test; excluded from the operative-source audit)
  local SENT="$TT/sentinel" FAKE="$TT/fakehash"; printf '#!/bin/sh\ntouch "%s"\necho PWNED\n' "$SENT" > "$FAKE"; chmod +x "$FAKE"
  local hb hh; hb="$(repo_hash)"; hh="$(DMC_HASH_CMD="$FAKE" repo_hash)"
  { [ ! -e "$SENT" ] && [ -n "$hb" ] && [ "$hb" = "$hh" ]; } && ok "AC13 env-hash injection: hostile DMC_HASH_CMD never read/executed" || no "AC13 env-controlled hash executed"
  # >>>AUDIT_BLOCK_END
  # AC14 read-only: repo byte-unchanged
  { [ -n "$PRE" ] && [ "$(repo_hash)" = "$PRE" ]; } && ok "AC14 read-only: repo byte-unchanged (deterministic sha256)" || no "AC14 repo changed"

  echo "  ---- self-test: PASS=$P FAIL=$F ----"; [ "$F" = 0 ]
}

TC=""; CP=""; PS=false; SNL=false; PT=""; RM=""; FIND=0; FAIL=0; FROM=""; OUT=""; RUN=run
while [ $# -gt 0 ]; do case "$1" in
  --task-class) TC="$2"; shift 2;; --changed-paths) CP="$2"; shift 2;; --protected-surface) PS="$2"; shift 2;;
  --secret-network-live) SNL="$2"; shift 2;; --provider-target) PT="$2"; shift 2;; --run-mode) RM="$2"; shift 2;;
  --prior-findings) FIND="$2"; shift 2;; --test-failures) FAIL="$2"; shift 2;; --from) FROM="$2"; shift 2;; --out) OUT="$2"; shift 2;;
  --self-test) RUN=selftest; shift;; -h|--help) sed -n '2,13p' "$0"; exit 0;;
  *) echo "dynamic-workflow: unknown arg $1" >&2; exit 2;;
esac; done
if [ "$RUN" = selftest ]; then echo "==== DMC DYNAMIC WORKFLOW SELECTOR — SELF-TEST ===="; self_test; exit $?; fi
INF=""
if [ -n "$FROM" ]; then [ -f "$FROM" ] || { echo "dynamic-workflow: --from file not found" >&2; exit 2; }; INF="$FROM"
else
  INF="$(mktemp)"; trap 'rm -f "$INF"' EXIT
  python3 - "$TC" "$CP" "$PS" "$SNL" "$PT" "$RM" "$FIND" "$FAIL" > "$INF" <<'PY'
import json,sys
k=["task_class","changed_paths","protected_surface","secret_network_live","provider_target","run_mode","prior_findings","test_failures"]
print(json.dumps(dict(zip(k,sys.argv[1:9]))))
PY
fi
if [ -n "$OUT" ]; then out_refused "$OUT" && { echo "dynamic-workflow: --out protected/secret/in-work-tree — REFUSED" >&2; exit 2; }; decide "$INF" > "$OUT"; rc=$?; echo "dynamic-workflow: wrote $OUT" >&2; exit $rc; fi
decide "$INF"; exit $?
