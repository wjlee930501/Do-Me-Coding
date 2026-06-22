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
# --out is FAIL-CLOSED (C7): allow ONLY a NEW (non-existing) file whose canonical parent is a benign temp/work dir OUTSIDE
# the repo. Refuse traversal, .env*/credential/key/token/protected paths, symlinks (target or parent), already-existing
# targets (no overwrite), anything in the repo tree or tracked, system paths, $HOME hidden control files (dotfile basename
# or a .ssh/.config/... control dir), and any parent NOT under an allowlisted temp root. No env var is read. 0=REFUSE,1=ALLOW.
out_refused() { local raw="$1"
  [ -z "$raw" ] && return 0
  printf '%s' "$raw" | grep -qE '(^|/)\.\.(/|$)' && return 0
  # .env-class (case-INSENSITIVE: .env/.ENV/prod.env/prod.ENV/.env.local/.ENV.LOCAL) => REFUSE, except .example/.sample/.template
  printf '%s' "$raw" | grep -qiE '\.env($|\.)' && ! printf '%s' "$raw" | grep -qiE '\.(example|sample|template)$' && return 0
  printf '%s' "$raw" | grep -qiE "$PROT_RE" && return 0
  [ -e "$raw" ] && return 0
  [ -L "$raw" ] && return 0
  local parent base cparent canon root croot ok; parent="$(dirname "$raw" 2>/dev/null)"; base="$(basename "$raw")"
  [ -L "$parent" ] && return 0
  cparent="$(cd "$parent" 2>/dev/null && pwd -P)" || return 0; canon="$cparent/$base"
  [ -e "$canon" ] && return 0
  printf '%s' "$canon" | grep -qiE "$PROT_RE" && return 0
  case "$canon/" in "$ROOTDIR"/*) return 0;; esac
  git -C "$ROOTDIR" ls-files --error-unmatch -- "$canon" >/dev/null 2>&1 && return 0
  printf '%s' "$canon" | grep -qE '^/(etc|usr|bin|sbin|System|Library|var/db|var/root|boot|dev|proc)(/|$)|^/private/etc(/|$)' && return 0
  case "$base" in .*) return 0;; esac
  printf '%s' "$canon" | grep -qE '/\.(ssh|config|gnupg|aws|kube|docker)(/|$)|/\.(gitconfig|git-credentials|netrc|npmrc|zshrc|bashrc|profile)$' && return 0
  ok=1
  for root in /tmp /private/tmp /var/folders /private/var/folders /var/tmp /private/var/tmp; do
    croot="$(cd "$root" 2>/dev/null && pwd -P)" || continue
    case "$cparent/" in "$croot"/*) ok=0; break;; esac
  done
  [ "$ok" = 0 ] || return 0
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
def num(v):
    try: return max(0,int(v))
    except Exception:
        try: return max(0,int(float(v)))
        except Exception: return None
UNSAFE=re.compile(r'sk-[A-Za-z0-9_-]{12,}|AKIA[0-9A-Z]{8,}|gh[opsu]_[A-Za-z0-9]{12,}|github_pat_[A-Za-z0-9_]{12,}|'
                  r'glpat-[A-Za-z0-9_-]{12,}|AIza[0-9A-Za-z_-]{16,}|xox[baprs]-[A-Za-z0-9-]{6,}|ya29\.[A-Za-z0-9._-]{8,}|'
                  r'eyJ[A-Za-z0-9_-]{6,}\.eyJ[A-Za-z0-9_-]{6,}|(BEGIN|END)[A-Z ]*PRIVATE KEY|[Bb]earer\s+[A-Za-z0-9._-]{12,}|'
                  r'(password|passwd|secret|token|api[_-]?key|client_secret)\s*[=:]\s*\S{4,}|/Users/[^/\s]+|/home/[^/\s]+', re.IGNORECASE)
def safe(v):
    s="" if v is None else str(v)
    return "[redacted]" if UNSAFE.search(s) else s.replace("\n"," ").replace("\r"," ")   # value-blind redact echoed caller facts
def dstate(key):
    # tri-state danger fact: 'safe' (EXPLICIT canonical false), 'escalate' (truthy), 'unknown' (missing/non-canonical => fail-closed)
    if key not in f: return 'unknown'
    v=str(f.get(key)).strip().lower()
    if v in ("0","false","no","n","off"): return 'safe'
    if v in ("1","true","yes","y","on","enabled","t"): return 'escalate'
    return 'unknown'
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
    idx=BASE[tc]; reasons.append("task_class=%s => base lane %s"%(safe(tc),LANES[idx]))
else:
    idx=5; reasons.append("task_class is unrecognized/missing => secret-network-live-risk (fail-closed max)")

# provider_target: a provider_target of 'mock' is a CATEGORY ERROR (mock is a run-mode, not a provider target)
pt=str(f.get("provider_target","")).strip().lower()
if pt=="mock":
    print("dynamic-workflow: CATEGORY ERROR — provider_target='mock' (mock is a RUN-MODE, not a provider_target; see v0.3.4)", file=sys.stderr); sys.exit(1)
if pt and idx<4:
    idx=4; reasons.append("a provider_target is present => protected-surface (adapter work is protected)")

# danger booleans — TRI-STATE fail-closed: missing/non-canonical => secret-network-live-risk (max); only EXPLICIT false is safe
ps=dstate("protected_surface"); snl=dstate("secret_network_live")
if ps=='unknown' or snl=='unknown':
    if idx<5: idx=5
    reasons.append("a danger fact (protected_surface/secret_network_live) is missing or non-canonical => secret-network-live-risk (fail-closed: 'no risk' must be EXPLICITLY declared false)")
else:
    if ps=='escalate' and idx<4: idx=4; reasons.append("protected_surface=true => >= protected-surface")
    if snl=='escalate' and idx<5: idx=5; reasons.append("secret_network_live=true => secret-network-live-risk (adversarial)")

# changed paths — a protected path forces protected-surface; a secret path forces secret-network-live-risk
cp=[p for p in str(f.get("changed_paths","")).split(",") if p.strip()]
for p in cp:
    if SECRET_PATH.search(p) and idx<5:
        idx=5; reasons.append("a secret-bearing changed path is present => secret-network-live-risk")
    elif PROT_PATH.search(p) and idx<4:
        idx=4; reasons.append("a changed path touches the protected surface => protected-surface")

# run_mode is INFORMATIONAL only — it NEVER lowers the lane (run-mode != provider_target / != lane fact)
rm=str(f.get("run_mode","")).strip().lower()
if rm: reasons.append("run_mode=%s (informational; does not change the lane)"%(rm if rm in ("mock","live") else "[other]"))

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
if idx>=5: gates += ["live-call gate","network gate","credential-access gate"]
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
  local TT; TT="$(mktemp -d)" || { echo "  FATAL: mktemp -d failed (self-test needs a writable temp dir)"; return 2; }; [ -d "$TT" ] || { echo "  FATAL: temp dir missing"; return 2; }; trap 'rm -rf "$TT"' RETURN
  local PRE; PRE="$(repo_hash)"
  mk(){ printf '%s' "$1" > "$TT/in.json"; decide "$TT/in.json"; }
  lane(){ mk "$1" | awk -F': ' '/^- lane:/{print $2}'; }
  eff(){ mk "$1" | awk -F': ' '/^- min_effort:/{print $2}'; }
  sb(){ printf '{"protected_surface":false,"secret_network_live":false,%s}' "$1"; }   # explicit-safe danger base (low lane requires declaring no-risk)
  laneidx(){ case "$1" in docs-only)echo 0;; additive-tooling)echo 1;; release-closure)echo 2;; recovery-resume)echo 3;; protected-surface)echo 4;; secret-network-live-risk)echo 5;; *)echo -1;; esac; }   # unknown/empty => -1 so a broken result FAILS

  # AC1 docs-only (explicit no-risk) => docs-only / light
  local D; D="$(sb '"task_class":"docs-only"')"
  { [ "$(lane "$D")" = docs-only ] && [ "$(eff "$D")" = light ]; } && ok "AC1 docs-only (explicit no-risk) => docs-only, light (smallest sufficient)" || no "AC1 docs-only (lane=$(lane "$D"))"
  # AC2 additive-tooling => additive-tooling
  [ "$(lane "$(sb '"task_class":"additive-tooling"')")" = additive-tooling ] && ok "AC2 additive-tooling => lane additive-tooling" || no "AC2 additive"
  # AC3 protected_surface=true => protected-surface / deep + gates
  local PS; PS="$(sb '"task_class":"docs-only","protected_surface":true')"
  { [ "$(lane "$PS")" = protected-surface ] && [ "$(eff "$PS")" = deep ] && mk "$PS" | grep -q 'protected-path byte-unchanged check'; } \
    && ok "AC3 protected_surface=true => protected-surface, deep, byte-unchanged gate (anti-downgrade)" || no "AC3 protected"
  # AC4 secret_network_live=true => secret-network-live-risk / adversarial + gates
  local SNL; SNL="$(sb '"task_class":"additive-tooling","secret_network_live":true')"
  { [ "$(lane "$SNL")" = secret-network-live-risk ] && [ "$(eff "$SNL")" = adversarial ] && mk "$SNL" | grep -q 'live-call gate'; } \
    && ok "AC4 secret_network_live=true => secret-network-live-risk, adversarial, live/network/credential gates" || no "AC4 snl"
  # AC5 a protected changed-path forces protected-surface even when task_class=docs-only (anti-downgrade)
  [ "$(lane "$(sb '"task_class":"docs-only","changed_paths":".claude/workers/providers/glm-api/x.py,docs/y.md"')")" = protected-surface ] \
    && ok "AC5 protected changed-path forces protected-surface despite docs-only task_class" || no "AC5 path"
  # AC5b a secret changed-path forces secret-network-live-risk
  [ "$(lane "$(sb '"task_class":"docs-only","changed_paths":".env"')")" = secret-network-live-risk ] && ok "AC5b secret changed-path => secret-network-live-risk" || no "AC5b secret-path"
  # AC6 unknown task_class OR missing danger fact => fail-closed max lane
  { [ "$(lane "$(sb '"task_class":"frobnicate"')")" = secret-network-live-risk ] && [ "$(lane '{"task_class":"docs-only"}')" = secret-network-live-risk ]; } \
    && ok "AC6 unknown task_class OR missing danger fact => secret-network-live-risk (fail-closed)" || no "AC6 not max"
  # AC7 non-canonical danger boolean fails CLOSED (escalates)
  { [ "$(lane "$(sb '"task_class":"additive-tooling","secret_network_live":"on"')")" = secret-network-live-risk ] \
    && [ "$(lane "$(sb '"task_class":"additive-tooling","protected_surface":"enabled"')")" = protected-surface ]; } \
    && ok "AC7 non-canonical danger boolean (on/enabled) fails CLOSED (escalates)" || no "AC7 boolean fail-open"
  # AC8 provider_target=mock => CATEGORY ERROR refused (exit 1); a real provider_target => protected-surface
  bash "$SELFPATH" --task-class docs-only --protected-surface false --secret-network-live false --provider-target mock >/dev/null 2>&1; [ $? = 1 ] && local c1=1 || local c1=0
  [ "$(lane "$(sb '"task_class":"docs-only","provider_target":"glm-api"')")" = protected-surface ] && local c2=1 || local c2=0
  { [ "$c1" = 1 ] && [ "$c2" = 1 ]; } && ok "AC8 provider_target=mock => CATEGORY ERROR (exit 1); real provider_target => protected-surface" || no "AC8 mock/provider (c1=$c1 c2=$c2)"
  # AC9 run_mode=mock does NOT lower the lane (run-mode != lane fact)
  [ "$(lane "$(sb '"task_class":"protected-surface","run_mode":"mock"')")" = protected-surface ] && ok "AC9 run_mode=mock does NOT lower the lane" || no "AC9 run-mode lowered lane"
  # AC10 STRUCTURAL monotonicity: adding each risk fact never lowers the lane index
  local base_idx mono=1 json li
  base_idx="$(laneidx "$(lane "$(sb '"task_class":"docs-only"')")")"
  for add in '"protected_surface":true' '"secret_network_live":true' '"changed_paths":"provider-router.py"' '"provider_target":"glm-api"' '"task_class":"protected-surface"'; do
    json="$(sb "\"task_class\":\"docs-only\",$add")"   # explicit-safe base + the added risk fact (duplicate key => last wins)
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
  # AC15 (HARDENING / Codex-2) fail-closed on a MISSING or non-canonical danger fact => max lane (not fail-open)
  { [ "$(lane '{"task_class":"docs-only","protected_surface":false}')" = secret-network-live-risk ] \
    && [ "$(lane "$(sb '"task_class":"docs-only","protected_surface":"maybe"')")" = secret-network-live-risk ]; } \
    && ok "AC15 missing / non-canonical danger fact => secret-network-live-risk (fail-closed; no fail-open downgrade)" || no "AC15 fail-open on omitted/garbage danger fact"
  # AC16 (HARDENING / Codex-5) secret-shaped caller facts are value-blind redacted in the output (no metadata leak)
  { ! mk '{"task_class":"sk-ABCDEFGHIJKLMNOPQRSTUV","protected_surface":false,"secret_network_live":false}' | grep -q 'sk-ABCDEFGHIJKLMNOPQRSTUV' \
    && ! mk '{"task_class":"docs-only","protected_surface":false,"secret_network_live":false,"provider_target":"ghp_ABCDEFGHIJKLMNOPQRSTUVWX"}' | grep -q 'ghp_ABCDEFGHIJKLMNOPQRSTUVWX'; } \
    && ok "AC16 secret-shaped caller facts (task_class/provider_target) value-blind redacted in output" || no "AC16 metadata leak in reason"

  # AC17 (HARDENING / C7) --out is FAIL-CLOSED: allow ONLY a NEW file in a benign temp/work dir OUTSIDE the repo
  local C7D="$TT/c7out"; mkdir -p "$C7D"
  local c7_new="$C7D/packet_new.md" c7_exist="$C7D/packet_exist.md"; : > "$c7_exist"
  ln -s "$c7_new" "$C7D/packet_link.md" 2>/dev/null
  local r_new r_exist r_home r_etc r_intree r_sym r_trav r_dot
  out_refused "$c7_new"; r_new=$?
  out_refused "$c7_exist"; r_exist=$?
  out_refused "${HOME:-/root}/.dmc_c7_sentinel.md"; r_home=$?     # home dotfile (PATH ONLY; contents never read) => REFUSE
  out_refused "/etc/passwd"; r_etc=$?                              # system path / existing => REFUSE (before any OS write)
  out_refused "$ROOTDIR/docs/c7_intree.md"; r_intree=$?           # inside the repo tree => REFUSE
  out_refused "$C7D/packet_link.md"; r_sym=$?                      # symlink => REFUSE
  out_refused "$C7D/../c7out/../x.md"; r_trav=$?                   # traversal => REFUSE
  out_refused "$C7D/.hidden.md"; r_dot=$?                          # dotfile basename => REFUSE
  { [ "$r_new" = 1 ] && [ "$r_exist" = 0 ] && [ "$r_home" = 0 ] && [ "$r_etc" = 0 ] && [ "$r_intree" = 0 ] && [ "$r_sym" = 0 ] && [ "$r_trav" = 0 ] && [ "$r_dot" = 0 ]; } \
    && ok "AC17 C7 --out guard: NEW temp file ALLOWED; existing/home-dotfile/etc-passwd/in-tree/symlink/traversal/dotfile REFUSED" \
    || no "AC17 C7 guard (new=$r_new exist=$r_exist home=$r_home etc=$r_etc intree=$r_intree sym=$r_sym trav=$r_trav dot=$r_dot)"
  # AC17b end-to-end via the real CLI: --out NEW temp path WRITES (exit 0); --out /etc/passwd REFUSED (exit 2, no OS write)
  local c7_e2e="$C7D/e2e.md" rc_e2e rc_etc
  bash "$SELFPATH" --task-class docs-only --protected-surface false --secret-network-live false --out "$c7_e2e" >/dev/null 2>&1; rc_e2e=$?
  bash "$SELFPATH" --task-class docs-only --protected-surface false --secret-network-live false --out /etc/passwd >/dev/null 2>&1; rc_etc=$?
  { [ "$rc_e2e" = 0 ] && [ -s "$c7_e2e" ] && [ "$rc_etc" = 2 ]; } \
    && ok "AC17b C7 end-to-end: --out new temp path writes (exit 0); --out /etc/passwd REFUSED by guard (exit 2)" \
    || no "AC17b C7 e2e (rc_e2e=$rc_e2e wrote=$([ -s "$c7_e2e" ] && echo y || echo n) etc=$rc_etc)"

  # AC20 (C7 / case-insensitive .env) uppercase/mixed-case .env-class --out paths are refused exactly like lowercase
  local re_up re_lo re_lc re_mix
  out_refused "$C7D/prod.ENV"; re_up=$?
  out_refused "$C7D/.ENV.LOCAL"; re_lo=$?
  out_refused "$C7D/prod.env"; re_lc=$?
  out_refused "$C7D/foo.Env.local"; re_mix=$?
  { [ "$re_up" = 0 ] && [ "$re_lo" = 0 ] && [ "$re_lc" = 0 ] && [ "$re_mix" = 0 ]; } \
    && ok "AC20 C7 .env-class refused case-insensitively (prod.ENV / .ENV.LOCAL / prod.env / foo.Env.local all REFUSED)" || no "AC20 .env case bypass (ENV=$re_up LOCAL=$re_lo env=$re_lc mix=$re_mix)"

  # AC14 read-only: repo byte-unchanged
  { [ -n "$PRE" ] && [ "$(repo_hash)" = "$PRE" ]; } && ok "AC14 read-only: repo byte-unchanged (deterministic sha256)" || no "AC14 repo changed"

  echo "  ---- self-test: PASS=$P FAIL=$F ----"; [ "$F" = 0 ]
}

# danger booleans default to __unset__ (NOT false): omitting one fails CLOSED (escalates). Pass an explicit value to declare.
TC=""; CP=""; PS=__unset__; SNL=__unset__; PT=""; RM=""; FIND=0; FAIL=0; FROM=""; OUT=""; RUN=run
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
if [ -n "$OUT" ]; then out_refused "$OUT" && { echo "dynamic-workflow: --out REFUSED — must be a NEW file in a temp/work dir outside the repo (not in-tree/tracked/secret/system/home-dotfile/existing)" >&2; exit 2; }; decide "$INF" > "$OUT"; rc=$?; echo "dynamic-workflow: wrote $OUT" >&2; exit $rc; fi
decide "$INF"; exit $?
