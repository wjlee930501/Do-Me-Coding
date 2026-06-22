#!/usr/bin/env bash
# DMC Effort Controller (v0.5.2) — ADVISORY / READ-ONLY, deterministic, inert unless invoked.
#
# Recommends the minimum sufficient effort level (light / standard / deep / adversarial) for a task from a deterministic
# rule set (see docs/EFFORT_POLICY.md), plus reviewer_required / adversarial_required / suggested verification depth. The
# recommendation is a PURE FUNCTION of the declared inputs — it reads NO environment variable, .env, credential, token, or
# network; it executes nothing and mutates nothing.
#
# Usage:  dmc-v0.5.2-effort-controller.sh --risk-class <c> [--files-touched N] [--protected-surface true|false]
#             [--secret-network-live true|false] [--prior-findings N] [--test-failures N] [--human-gate true|false]
#             [--out <file>]   |   --from <inputs.json> [--out <file>]   |   --self-test
# Exit: 0 = recommendation emitted, 2 = usage/refused.
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

# --- the deterministic rule engine. Inputs come from a JSON file ONLY (argv) — never the environment. ---
decide() { # <inputs.json>
  python3 - "$1" <<'PY'
import json,sys
try:
    inp=json.load(open(sys.argv[1]))
    if not isinstance(inp,dict): raise ValueError
except Exception:
    print("effort-controller: invalid inputs JSON", file=sys.stderr); sys.exit(2)
def b(v):
    # fail-CLOSED: anything NOT explicitly false-y is treated as true, so a danger surface is never silently downgraded
    return str(v).strip().lower() not in ("0","false","no","n","none","off","")
def num(v):
    # parse int, then float->int; return None if unparseable (the caller then fails CLOSED by escalating)
    try: return max(0,int(v))
    except Exception:
        try: return max(0,int(float(v)))
        except Exception: return None
LEVELS=["light","standard","deep","adversarial"]
RISK={"docs-only":0,"additive":1,"generic":1,"provider":2,"guard":2,"security":3}
risk=str(inp.get("risk_class","generic")).strip().lower()
prot=b(inp.get("protected_surface",False)); snl=b(inp.get("secret_network_live",False)); gate=b(inp.get("human_gate",False))
reasons=[]
# fail-CLOSED numeric parsing: an unparseable danger count escalates rather than silently becoming 0
files_n=num(inp.get("files_touched",0)); files = files_n if files_n is not None else 999
find_n=num(inp.get("prior_findings",0));  findings = find_n if find_n is not None else 2
fail_n=num(inp.get("test_failures",0));   failures = fail_n if fail_n is not None else 1
# fail-CLOSED risk_class: an unrecognized class escalates to adversarial (never silently downgraded to generic)
if risk in RISK:
    idx=RISK[risk]; reasons.append("base: risk_class=%s => %s"%(risk,LEVELS[idx]))
else:
    idx=3; reasons.append("base: unrecognized risk_class '%s' => adversarial (fail-closed)"%risk)
if files_n is None: reasons.append("files_touched unparseable => fail-closed escalate")
if find_n is None: reasons.append("prior_findings unparseable => fail-closed adversarial")
if fail_n is None: reasons.append("test_failures unparseable => fail-closed escalate")
if prot and idx<2: idx=2; reasons.append("protected_surface => at least deep")
if snl and idx<3: idx=3; reasons.append("secret/network/live surface => adversarial (auto-escalate)")
if files>25 and idx<2: idx=2; reasons.append("files_touched=%d (>25) => at least deep (over-eager)"%files)
elif files>10 and idx<1: idx=1; reasons.append("files_touched=%d (>10) => at least standard"%files)
if findings>=2 and idx<3: idx=3; reasons.append("repeated review findings (%d>=2) => adversarial (false-green guard)"%findings)
elif findings==1 and idx<3: idx=idx+1; reasons.append("one prior review finding => +1 level")
if failures>0 and idx<3: idx=idx+1; reasons.append("test_failures=%d => +1 level"%failures)
effort=LEVELS[idx]
reviewer = (idx>=2) or findings>0 or failures>0
adversarial = (effort=="adversarial") or snl or findings>=2
DEPTH={"light":"self-test only",
       "standard":"self-test + single critic pass",
       "deep":"self-test + per-finding adversarial verify",
       "adversarial":"multi-agent falsification panel + cross-cutting audit + per-finding refute"}
out=[
 "# DMC Effort Recommendation",
 "- recommended_effort: %s"%effort,
 "- reviewer_required: %s"%("yes" if reviewer else "no"),
 "- adversarial_required: %s"%("yes" if adversarial else "no"),
 "- suggested_verification_depth: %s"%DEPTH[effort],
 "- human_gate: %s (orthogonal — does not change effort level)"%("yes" if gate else "no"),
 "- reason:",
]
out += ["  - %s"%r for r in reasons]
print("\n".join(out))
PY
}

# ---------------------------------------------------------------- self-test (fixtures; deterministic; no env read)
self_test() {
  local P=0 F=0; ok(){ echo "  PASS $1"; P=$((P+1)); }; no(){ echo "  FAIL $1"; F=$((F+1)); }
  local TT; TT="$(mktemp -d)"; trap 'rm -rf "$TT"' RETURN
  local PRE; PRE="$(repo_hash)"
  mk(){ printf '%s' "$1" > "$TT/in.json"; decide "$TT/in.json"; }
  eff(){ mk "$1" | awk -F': ' '/^- recommended_effort:/{print $2}'; }
  rev(){ mk "$1" | awk -F': ' '/^- reviewer_required:/{print $2}'; }
  adv(){ mk "$1" | awk -F': ' '/^- adversarial_required:/{print $2}'; }
  efff(){ bash "$SELFPATH" "$@" 2>/dev/null | awk -F': ' '/^- recommended_effort:/{print $2}'; }   # real flag dispatch
  advf(){ bash "$SELFPATH" "$@" 2>/dev/null | awk -F': ' '/^- adversarial_required:/{print $2}'; }

  # AC1 docs-only append-only closure => light (efficient); reviewer not required
  local D='{"risk_class":"docs-only","files_touched":1,"protected_surface":false,"secret_network_live":false,"prior_findings":0,"test_failures":0,"human_gate":true}'
  { [ "$(eff "$D")" = light ] && [ "$(rev "$D")" = no ] && [ "$(adv "$D")" = no ]; } \
    && ok "AC1 docs-only closure => light, reviewer=no, adversarial=no" || no "AC1 docs-only (eff=$(eff "$D"))"

  # AC2 additive schema/tool => standard
  local A='{"risk_class":"additive","files_touched":2,"protected_surface":false,"secret_network_live":false,"prior_findings":0,"test_failures":0,"human_gate":false}'
  [ "$(eff "$A")" = standard ] && ok "AC2 additive schema/tool => standard" || no "AC2 additive (eff=$(eff "$A"))"

  # AC3 guard touching secret/network/live => adversarial (auto-escalate)
  local G='{"risk_class":"guard","files_touched":1,"protected_surface":true,"secret_network_live":true,"prior_findings":0,"test_failures":0,"human_gate":false}'
  { [ "$(eff "$G")" = adversarial ] && [ "$(rev "$G")" = yes ] && [ "$(adv "$G")" = yes ]; } \
    && ok "AC3 guard + secret/network/live => adversarial, reviewer+adversarial=yes" || no "AC3 guard-snl (eff=$(eff "$G"))"

  # AC4 capstone dry-run touching output-path safety => deep (protected surface, no secret/net)
  local C='{"risk_class":"guard","files_touched":1,"protected_surface":true,"secret_network_live":false,"prior_findings":0,"test_failures":0,"human_gate":false}'
  { [ "$(eff "$C")" = deep ] && [ "$(adv "$C")" = no ]; } \
    && ok "AC4 capstone output-path safety => deep (adversarial=no)" || no "AC4 capstone (eff=$(eff "$C"))"

  # AC5 prior blocker found in review escalates effort vs the same task with no finding
  local B0='{"risk_class":"additive","files_touched":2,"protected_surface":false,"secret_network_live":false,"prior_findings":0,"test_failures":0,"human_gate":false}'
  local B1='{"risk_class":"additive","files_touched":2,"protected_surface":false,"secret_network_live":false,"prior_findings":1,"test_failures":0,"human_gate":false}'
  { [ "$(eff "$B0")" = standard ] && [ "$(eff "$B1")" = deep ] && [ "$(rev "$B1")" = yes ]; } \
    && ok "AC5 prior review finding escalates standard => deep (reviewer=yes)" || no "AC5 finding escalation (b0=$(eff "$B0") b1=$(eff "$B1"))"

  # AC6 repeated/false-green findings (>=2) => adversarial automatically
  local R='{"risk_class":"additive","files_touched":1,"protected_surface":false,"secret_network_live":false,"prior_findings":2,"test_failures":0,"human_gate":false}'
  { [ "$(eff "$R")" = adversarial ] && [ "$(adv "$R")" = yes ]; } \
    && ok "AC6 repeated findings (>=2) => adversarial (false-green guard)" || no "AC6 repeated findings (eff=$(eff "$R"))"

  # AC7 escalation deterministic — same inputs => byte-identical output (10x)
  local det=1 i out0; out0="$(mk "$G")"
  for i in 1 2 3 4 5 6 7 8 9 10; do [ "$(mk "$G")" = "$out0" ] || det=0; done
  [ "$det" = 1 ] && ok "AC7 deterministic: identical inputs => byte-identical recommendation (10x)" || no "AC7 non-deterministic"

  # AC8 env-independent — env -i + credential-var differential do NOT alter the decision
  printf '%s' "$G" > "$TT/g.json"
  local base; base="$(decide "$TT/g.json")"
  local envi; envi="$(env -i PATH="$PATH" HOME="${HOME:-/tmp}" bash "$SELFPATH" --from "$TT/g.json" 2>/dev/null)"
  local diff_ok=1 v
  for v in GLM_API_KEY ANTHROPIC_API_KEY OPENAI_API_KEY DMC_EFFORT; do
    [ "$(env "$v=adversarial-or-sk-ant-XXXX" bash "$SELFPATH" --from "$TT/g.json" 2>/dev/null)" = "$base" ] || diff_ok=0
  done
  { [ "$envi" = "$base" ] && [ "$diff_ok" = 1 ]; } && ok "AC8 env-independent: env -i + credential/effort-var differential byte-identical" || no "AC8 env-dependent"

  # AC9 structural no-net / no-env-read audit (own audit block + comments excluded)
  local OP; OP="$(sed '/AUDIT_BLOCK_START/,/AUDIT_BLOCK_END/d' "$SELFPATH" | grep -vE '^[[:space:]]*#')"
  # >>>AUDIT_BLOCK_START
  ! printf '%s' "$OP" | grep -nE '(^|[^A-Za-z])(curl|wget)([[:space:]])| --live | --allow-network|os\.environ|getenv|printenv|HASH_CMD|\$\{DMC_' >/dev/null \
    && ok "AC9 no curl/wget/--live, no env-read, no env-hash (DMC_HASH_CMD/\${DMC_*}) in the operative source" || no "AC9 net/env-read present"
  # >>>AUDIT_BLOCK_END

  # AC11 (HARDENING) boolean fail-CLOSED: non-canonical truthy danger flags ESCALATE (never silently downgraded)
  { [ "$(efff --risk-class additive --secret-network-live on)" = adversarial ] \
    && [ "$(advf --risk-class additive --secret-network-live enabled)" = yes ] \
    && [ "$(efff --risk-class additive --protected-surface on)" = deep ]; } \
    && ok "AC11 boolean fail-closed: 'on'/'enabled' danger flags escalate (no silent downgrade)" || no "AC11 boolean fail-open"

  # AC12 (HARDENING) risk_class normalized + fail-CLOSED: case-variant and unknown => adversarial, not a downgrade
  { [ "$(efff --risk-class Security)" = adversarial ] && [ "$(efff --risk-class SECURITY)" = adversarial ] \
    && [ "$(efff --risk-class totally-unknown)" = adversarial ]; } \
    && ok "AC12 risk_class normalized+fail-closed: Security/SECURITY/unknown => adversarial" || no "AC12 risk_class fail-open"

  # AC13 (HARDENING) numeric coercion fail-CLOSED: non-int large/odd counts escalate, not silent 0
  { [ "$(efff --risk-class additive --files-touched 1e9)" = deep ] \
    && [ "$(efff --risk-class additive --files-touched 30abc)" = deep ] \
    && [ "$(efff --risk-class additive --prior-findings 2x)" = adversarial ]; } \
    && ok "AC13 numeric fail-closed: unparseable files/findings escalate (not silent 0)" || no "AC13 numeric fail-open"

  # AC14 (HARDENING) DMC_HASH_CMD is neither read nor executed (no env-controlled hash command).
  # >>>AUDIT_BLOCK_START  (hostile-input test; excluded from the operative-source audit)
  local SENT="$TT/sentinel" FAKE="$TT/fakehash"
  printf '#!/bin/sh\ntouch "%s"\necho PWNED\n' "$SENT" > "$FAKE"; chmod +x "$FAKE"
  local hbase hhostile; hbase="$(repo_hash)"; hhostile="$(DMC_HASH_CMD="$FAKE" repo_hash)"
  { [ ! -e "$SENT" ] && [ -n "$hbase" ] && [ "$hbase" = "$hhostile" ]; } \
    && ok "AC14 env-hash injection: hostile DMC_HASH_CMD never read/executed; repo_hash byte-identical" || no "AC14 env-controlled hash executed"
  # >>>AUDIT_BLOCK_END

  # AC10 read-only: repo byte-unchanged
  { [ -n "$PRE" ] && [ "$(repo_hash)" = "$PRE" ]; } && ok "AC10 read-only: repo byte-unchanged (deterministic sha256)" || no "AC10 repo changed"

  echo "  ---- self-test: PASS=$P FAIL=$F ----"; [ "$F" = 0 ]
}

RISK=""; FILES=0; PROT=false; SNL=false; FIND=0; FAIL=0; GATE=false; FROM=""; OUT=""; RUN=run
while [ $# -gt 0 ]; do case "$1" in
  --risk-class) RISK="$2"; shift 2;; --files-touched) FILES="$2"; shift 2;; --protected-surface) PROT="$2"; shift 2;;
  --secret-network-live) SNL="$2"; shift 2;; --prior-findings) FIND="$2"; shift 2;; --test-failures) FAIL="$2"; shift 2;;
  --human-gate) GATE="$2"; shift 2;; --from) FROM="$2"; shift 2;; --out) OUT="$2"; shift 2;;
  --self-test) RUN=selftest; shift;; -h|--help) sed -n '2,12p' "$0"; exit 0;;
  *) echo "effort-controller: unknown arg $1" >&2; exit 2;;
esac; done
if [ "$RUN" = selftest ]; then echo "==== DMC EFFORT CONTROLLER — SELF-TEST ===="; self_test; exit $?; fi
INF=""
if [ -n "$FROM" ]; then [ -f "$FROM" ] || { echo "effort-controller: --from file not found" >&2; exit 2; }; INF="$FROM"
else
  [ -n "$RISK" ] || { echo "effort-controller: --risk-class required (or --from / --self-test)" >&2; exit 2; }
  INF="$(mktemp)"; trap 'rm -f "$INF"' EXIT
  python3 - "$RISK" "$FILES" "$PROT" "$SNL" "$FIND" "$FAIL" "$GATE" > "$INF" <<'PY'
import json,sys
k=["risk_class","files_touched","protected_surface","secret_network_live","prior_findings","test_failures","human_gate"]
print(json.dumps(dict(zip(k,sys.argv[1:8]))))
PY
fi
if [ -n "$OUT" ]; then out_refused "$OUT" && { echo "effort-controller: --out protected/secret/in-work-tree — REFUSED" >&2; exit 2; }; decide "$INF" > "$OUT"; echo "effort-controller: wrote $OUT" >&2; exit 0; fi
decide "$INF"; exit $?
