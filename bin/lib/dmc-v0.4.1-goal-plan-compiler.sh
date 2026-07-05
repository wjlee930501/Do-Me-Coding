#!/usr/bin/env bash
# DMC Goal-to-Plan Compiler (v0.4.1) — ADVISORY / READ-ONLY, deterministic, mock-first.
#
# Compiles a human GOAL bundle into a deterministic DMC run-plan (see .harness/schemas/goal-plan.schema.md) by composing
# the v0.2.8 task-intake classifier (read-only) + the v0.4.0 autonomy levels. It:
#   - is DETERMINISTIC (same goal -> byte-identical plan) and env-independent (reads NO env var / .env / credential);
#   - caps the autonomy level by risk (high-risk -> advisory; ambiguous -> autonomous-dry-run; low-risk ->
#     autonomous-local-commit) and ALWAYS keeps push + closure + live-call + credential-access human-gated;
#   - redacts token/secret-shaped goal text (value-blind, same sanitizer as v0.3.9.1);
#   - executes nothing, stages/commits/pushes nothing, grants no gate.
#
# Usage:  goal-plan-compiler.sh --goal <goal.json> [--out <file>]   ·   --self-test
# Exit: 0 = plan emitted, 2 = usage/refused.
set -u
set -o pipefail
export PYTHONDONTWRITEBYTECODE=1
ROOTDIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SELFPATH="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/$(basename "$0")"
CLASSIFIER="$ROOTDIR/.harness/evidence/dmc-v0.2.8-task-intake-classifier.sh"

# --- --out guard (v0.3.x hardened: refuse any `..`, then protected/secret/symlink) ---
PROT_RE='(^|/)(\.env)(\.|$)|\.pem$|\.key$|id_rsa|id_ed25519|credentials|secret|\.p12$|\.pfx$|\.keystore$|\.claude/hooks|provider-router\.py|/ROUTING\.md$|WORKER_(TASK|RESULT|REVIEW)_SCHEMA\.md|PROVIDER_CONTRACT\.md|workers/providers/(glm-api|oauth-cli)|(^|/)dmc-glm-smoke$'
out_refused() { local raw="$1"
  printf '%s' "$raw" | grep -qE '(^|/)\.\.(/|$)' && return 0
  printf '%s' "$raw" | grep -qiE "$PROT_RE" && return 0
  case "$raw" in *.env|*.env.local|*.env.*) case "$raw" in *.example|*.sample|*.template) ;; *) return 0;; esac;; esac
  local parent base cparent canon
  parent="$(dirname "$raw")"; base="$(basename "$raw")"
  cparent="$(cd "$parent" 2>/dev/null && pwd -P)" || return 0; canon="$cparent/$base"
  printf '%s' "$canon" | grep -qiE "$PROT_RE" && return 0
  if [ -L "$raw" ]; then local tgt; tgt="$(readlink -f "$raw" 2>/dev/null)" || return 0; printf '%s' "$tgt" | grep -qiE "$PROT_RE" && return 0; fi
  return 1
}

# --- compile a goal bundle into a run-plan JSON (inputs via argv/files ONLY; never the environment) ---
compile() { # <goal.json> <intake.json|"">
  python3 - "$1" "$2" <<'PY'
import json,sys,re
UNSAFE=re.compile(r'sk-[A-Za-z0-9_-]{16,}|AKIA[0-9A-Z]{12,}|(BEGIN|END)[A-Z ]*PRIVATE KEY|xox[baprs]-[A-Za-z0-9-]{8,}|gh[opsu]_[A-Za-z0-9]{20,}|eyJ[A-Za-z0-9_-]{6,}\.eyJ[A-Za-z0-9_-]{6,}|[Bb]earer\s+[A-Za-z0-9._-]{12,}|ya29\.[A-Za-z0-9._-]{8,}|(access_token|refresh_token|id_token)\s*[=:]|SENTINEL', re.IGNORECASE)
def safe(v):
    s="" if v is None else str(v)
    return "[redacted:unsafe-metadata]" if UNSAFE.search(s) else v
def load(p):
    if not p: return {}
    try: return json.load(open(p))
    except Exception: return {}
goal=load(sys.argv[1]); intake=load(sys.argv[2]) if sys.argv[2] else {}
goal_id = goal.get("goal_id","") if isinstance(goal,dict) else ""
objective = goal.get("objective","") if isinstance(goal,dict) else ""
declared = goal.get("declared_scope",[]) if isinstance(goal,dict) and isinstance(goal.get("declared_scope"),list) else []

dims = intake.get("dimensions",[]) or []
stop = bool(intake.get("stop_and_ask", True))
gates = intake.get("required_human_gates",[]) or []

HIGH = {"schema-change","guard-hook-validator-change","adapter-change","router-change","live-provider-call",
        "credential-behavior","external-publish-send","destructive-or-history-rewrite","unknown-high-ambiguity"}
LOW  = {"docs-only","test-only"}
has_high = bool(set(dims) & HIGH)
is_low   = bool(set(dims) & LOW) and not has_high

# autonomy level (fail-closed): high-risk/stop => advisory; clean low-risk => autonomous-local-commit; else dry-run
if has_high or stop:
    level = "advisory"
elif is_low:
    level = "autonomous-local-commit"
else:
    level = "autonomous-dry-run"

# human gates — ALWAYS push + closure; + live/credential if implicated (never autonomous regardless of level)
hg = ["push","closure"]
if "live-provider-call" in dims: hg.append("live-provider-call")
if "credential-behavior" in dims: hg.append("credential-access")
hg = sorted(set(hg))

# approved scope: only meaningful at autonomous-local-commit AND when declared; else no autonomous edit
approved = [safe(p) for p in declared] if level=="autonomous-local-commit" else []
edit_permitted = (level=="autonomous-local-commit" and len(approved)>0)

plan={
  "goal_plan_version":"v0.4",
  "goal_id": safe(goal_id),
  "objective": safe(objective),
  "intake": {"dimensions":dims, "stop_and_ask":stop, "required_human_gates":gates},
  "autonomy_level": level,
  "approved_scope": approved,
  "autonomous_edit_permitted": edit_permitted,
  "human_gates": hg,
  "acceptance_criteria": ["verification harness must PASS (offline self-test)",
                          "Codex/Kim release audit ACCEPT before stage/commit",
                          "approved-scope-only diff; no protected-surface change beyond plan"],
  "stop_conditions": ["dirty-worktree","branch-is-main-outside-closure","scope-violation","protected-surface-diff",
                      "secret-or-credential-exposure","live-call-or-network","verification-fail","ambiguity",
                      "over-eager-bound-exceeded"],
  "basis": "deterministic; mock-first; from goal + v0.2.8 policy ONLY (not env/secrets); preserves human gates",
}
print(json.dumps(plan, indent=2))
PY
}

generate_plan() { # <goal.json>
  local goalfile="$1"; local TMP; TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' RETURN
  local intake=""
  if [ -f "$CLASSIFIER" ]; then
    local obj; obj="$(python3 -c 'import json,sys
try:
    t=json.load(open(sys.argv[1])); print((str(t.get("objective","") or "")+" "+str(t.get("context","") or "")).strip())
except Exception: print("")' "$goalfile")"
    if [ -n "$obj" ] && bash "$CLASSIFIER" --task "$obj" --out "$TMP/intake.json" 2>/dev/null; then intake="$TMP/intake.json"; fi
  fi
  compile "$goalfile" "$intake"
}

# ---------------------------------------------------------------- self-test
self_test() {
  local P=0 F=0; ok(){ echo "  PASS $1"; P=$((P+1)); }; no(){ echo "  FAIL $1"; F=$((F+1)); }
  local TT; TT="$(mktemp -d)"; trap 'rm -rf "$TT"' RETURN
  local PRE; PRE="$(git -C "$ROOTDIR" status --porcelain 2>/dev/null | md5)"

  # fixtures: one sample low-risk autonomous run + a high-risk + a token-shaped goal
  printf '%s' '{"goal_id":"g-docs","objective":"update the README onboarding docs","declared_scope":["docs/README.md"]}' > "$TT/low.json"
  printf '%s' '{"goal_id":"g-adp","objective":"modify the glm-api adapter mapping and run a live provider call with the .env credential","declared_scope":[".claude/workers/providers/glm-api/glm-api-adapter.py"]}' > "$TT/high.json"
  printf '%s' '{"goal_id":"ghp_GOALLEAK0123456789ABCDEFGHIJ","objective":"deploy with sk-OBJLEAK0123456789abcdefghijklmnop now"}' > "$TT/tok.json"
  cp "$TT/low.json" "$ROOTDIR/.harness/runs/.gitkeep.tmp" 2>/dev/null; rm -f "$ROOTDIR/.harness/runs/.gitkeep.tmp" 2>/dev/null

  local low high tok
  low="$(generate_plan "$TT/low.json")"; high="$(generate_plan "$TT/high.json")"; tok="$(generate_plan "$TT/tok.json")"

  # AC1 schema conformance — required fields present
  printf '%s' "$low" | python3 -c 'import json,sys; o=json.load(sys.stdin); [o[k] for k in ("goal_plan_version","goal_id","objective","intake","autonomy_level","approved_scope","autonomous_edit_permitted","human_gates","acceptance_criteria","stop_conditions","basis")]; sys.exit(0)' \
    && ok "AC1 schema conformance: all run-plan fields present" || no "AC1 schema conformance"

  # AC2 deterministic — same goal twice => byte-identical
  [ "$(generate_plan "$TT/low.json")" = "$low" ] && ok "AC2 deterministic: same goal => byte-identical plan" || no "AC2 non-deterministic"

  # AC3 env-independent — env -i (PATH/HOME) byte-identical + credential-var differential
  local envi; envi="$(env -i PATH="$PATH" HOME="${HOME:-/tmp}" bash "$SELFPATH" --compile "$TT/low.json" 2>/dev/null)"
  local diff_ok=1 v
  for v in GLM_API_KEY ANTHROPIC_API_KEY OPENAI_API_KEY; do
    [ "$(env "$v=sk-ant-api03-XXXXXXXXXXXXXXXXXXXXXXXX" bash "$SELFPATH" --compile "$TT/low.json" 2>/dev/null)" = "$low" ] || diff_ok=0
  done
  { [ "$envi" = "$low" ] && [ "$diff_ok" = 1 ]; } && ok "AC3 env-independent: env -i + credential-var differential byte-identical" || no "AC3 env-dependence"

  # AC4 risk->autonomy mapping (fail-closed): low-risk=>autonomous-local-commit; high-risk=>advisory
  printf '%s' "$low" | python3 -c 'import json,sys; o=json.load(sys.stdin); sys.exit(0 if o["autonomy_level"]=="autonomous-local-commit" and o["autonomous_edit_permitted"] is True else 1)' \
    && printf '%s' "$high" | python3 -c 'import json,sys; o=json.load(sys.stdin); sys.exit(0 if o["autonomy_level"]=="advisory" and o["autonomous_edit_permitted"] is False else 1)' \
    && ok "AC4 risk->autonomy: low-risk=>autonomous-local-commit(edit ok); high-risk=>advisory(no autonomous edit)" || no "AC4 autonomy mapping"

  # AC5 human gates ALWAYS include push + closure; high-risk live/credential => those gated too
  printf '%s' "$low" | python3 -c 'import json,sys; g=json.load(sys.stdin)["human_gates"]; sys.exit(0 if "push" in g and "closure" in g else 1)' \
    && printf '%s' "$high" | python3 -c 'import json,sys; g=json.load(sys.stdin)["human_gates"]; sys.exit(0 if all(x in g for x in ("push","closure","live-provider-call","credential-access")) else 1)' \
    && ok "AC5 human gates: push+closure always; live+credential gated on the high-risk goal" || no "AC5 human gates"

  # AC6 secret-shaped goal text redacted (goal_id + objective), value-blind
  printf '%s' "$tok" | python3 -c 'import json,sys; o=json.load(sys.stdin); s=json.dumps(o); sys.exit(0 if ("GOALLEAK" not in s and "OBJLEAK" not in s and "redacted:unsafe-metadata" in s) else 1)' \
    && ok "AC6 value-blind redaction: token-shaped goal_id/objective never emitted" || no "AC6 redaction leaked"

  # AC7 read-only: repo byte-unchanged
  [ "$(git -C "$ROOTDIR" status --porcelain 2>/dev/null | md5)" = "$PRE" ] && ok "AC7 read-only: repo byte-unchanged" || no "AC7 repo changed"

  echo "  ---- self-test: PASS=$P FAIL=$F ----"; [ "$F" = 0 ]
}

case "${1:-}" in
  --self-test) echo "==== DMC GOAL-PLAN COMPILER — SELF-TEST ===="; self_test; exit $?;;
  --compile) [ -f "${2:-}" ] || { echo "goal-plan-compiler: --compile <goal.json> not found" >&2; exit 2; }; generate_plan "$2"; exit 0;;
  --goal)
    GOAL="${2:-}"; OUT=""; shift 2 2>/dev/null || true
    while [ $# -gt 0 ]; do case "$1" in --out) OUT="$2"; shift 2;; *) shift;; esac; done
    [ -f "$GOAL" ] || { echo "goal-plan-compiler: --goal <goal.json> not found" >&2; exit 2; }
    if [ -n "$OUT" ]; then out_refused "$OUT" && { echo "goal-plan-compiler: --out protected/secret — REFUSED" >&2; exit 2; }; generate_plan "$GOAL" > "$OUT"; echo "goal-plan-compiler: wrote $OUT" >&2; else generate_plan "$GOAL"; fi
    exit 0;;
  -h|--help) sed -n '2,13p' "$0"; exit 0;;
  *) echo "goal-plan-compiler: use --goal <goal.json> [--out <file>] or --self-test" >&2; exit 2;;
esac
