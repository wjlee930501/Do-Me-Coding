#!/usr/bin/env bash
# DMC Run Manifest generator (v0.2.7) — RECORDER-ONLY / READ-ONLY.
#
# Emits a machine-readable JSON snapshot of a milestone run (id, plan, approval, scope lists, verification counts,
# gate states, commit hash, origin sync, and the disallowed/used status of live-calls and credential access).
# It RECORDS state; it does NOT grant gates. It stages/commits/pushes/mutates the real repo NOTHING, makes no live
# call, and reads no .env*/credentials. --out writes ONLY the named manifest file (never `git add`).
#
# Usage:
#   dmc-v0.2.7-run-manifest.sh --milestone <id> --plan <plan.md> [--allowlist <file>] [--repo <dir>] \
#       [--verify-script <path>] [--verify-pass N] [--verify-fail M] [--push-state <s>] [--out <file>]
#   dmc-v0.2.7-run-manifest.sh --self-test
set -u

DEFAULT_EXCLUDED='.harness/evidence/dmc-v0.2.2-oauth-cli-adapter.md
.harness/evidence/dmc-v0.2.3-provider-routing.md
.harness/evidence/dmc-v0.2.4-provider-contract-tests.md
.harness/evidence/dmc-v0.2.5-agent-operating-handbook.md
.harness/evidence/dmc-v0.2.6-gate-check-runner.md'
DEFAULT_PROTECTED='.claude/workers/providers/glm-api
.claude/workers/providers/oauth-cli
.claude/workers/providers/provider-router.py
.claude/workers/providers/ROUTING.md
.claude/hooks
WORKER_TASK_SCHEMA.md
WORKER_RESULT_SCHEMA.md
WORKER_REVIEW_SCHEMA.md
dmc-glm-smoke'

# generate <repo> <milestone> <plan> <allowlist|""> <vscript> <vpass> <vfail> <pushstate>  -> JSON on stdout. READ-ONLY.
generate() {
  local repo="$1" ms="$2" plan="$3" allow_file="$4" vscript="$5" vpass="$6" vfail="$7" pushstate="$8"
  local upstream="${DMC_GATE_UPSTREAM:-origin/main}"
  local status="unknown"; [ -f "$plan" ] && status="$(grep -m1 -E '^Status:' "$plan" | sed 's/^Status:[[:space:]]*//' || true)"
  local hash="none"; hash="$(git -C "$repo" rev-parse --short HEAD 2>/dev/null || echo none)"
  local ahead=0 behind=0 insync=true
  if git -C "$repo" rev-parse "$upstream" >/dev/null 2>&1; then
    local lr; lr="$(git -C "$repo" rev-list --left-right --count "$upstream"...HEAD 2>/dev/null)"
    behind="${lr%%[	 ]*}"; ahead="${lr##*[	 ]}"
  fi
  [ "${ahead:-0}" = 0 ] && [ "${behind:-0}" = 0 ] && insync=true || insync=false
  local staged; staged="$(git -C "$repo" diff --cached --name-only 2>/dev/null)"
  local allow=""; [ -n "$allow_file" ] && [ -f "$allow_file" ] && allow="$(grep -vE '^\s*(#|$)' "$allow_file")"

  DMC_M_MS="$ms" DMC_M_PLAN="$plan" DMC_M_STATUS="$status" DMC_M_HASH="$hash" \
  DMC_M_AHEAD="${ahead:-0}" DMC_M_BEHIND="${behind:-0}" DMC_M_INSYNC="$insync" \
  DMC_M_VSCRIPT="$vscript" DMC_M_VPASS="$vpass" DMC_M_VFAIL="$vfail" DMC_M_PUSH="$pushstate" \
  DMC_M_ALLOW="$allow" DMC_M_EXCL="${DMC_GATE_EXCLUDED:-$DEFAULT_EXCLUDED}" DMC_M_PROT="${DMC_GATE_PROTECTED:-$DEFAULT_PROTECTED}" \
  DMC_M_STAGEDN="$(printf '%s' "$staged" | grep -c . || true)" \
  python3 - <<'PY'
import json, os
def lines(v): return [x for x in (os.environ.get(v,"") or "").splitlines() if x.strip()]
def i(v):
    try: return int(os.environ.get(v,"0") or 0)
    except: return 0
status = os.environ.get("DMC_M_STATUS","unknown").strip() or "unknown"
ahead, behind = i("DMC_M_AHEAD"), i("DMC_M_BEHIND")
m = {
  "milestone_id": os.environ.get("DMC_M_MS",""),
  "plan_path": os.environ.get("DMC_M_PLAN",""),
  "approval_status": status,
  "allowed_files": lines("DMC_M_ALLOW"),
  "excluded_files": lines("DMC_M_EXCL"),
  "protected_paths": lines("DMC_M_PROT"),
  "verification_script": os.environ.get("DMC_M_VSCRIPT",""),
  "verification_pass": i("DMC_M_VPASS"),
  "verification_fail": i("DMC_M_VFAIL"),
  "gates": {
    "approval": status,
    "staged": "staged" if i("DMC_M_STAGEDN")>0 else "none",
    "commit": "committed" if os.environ.get("DMC_M_HASH","none") not in ("none","") else "uncommitted",
    "push": os.environ.get("DMC_M_PUSH") or ("in_sync" if ahead==0 and behind==0 else "local-ahead(deferred)"),
    "closure": "pending",
  },
  "commit_hash": os.environ.get("DMC_M_HASH","none"),
  "origin_sync": {"ahead": ahead, "behind": behind, "in_sync": os.environ.get("DMC_M_INSYNC")=="true"},
  "live_calls": "disallowed",
  "credential_access": "disallowed",
  "generated_note": "recorder-only snapshot; records state, grants no gate; no live call, no credential/.env read",
}
print(json.dumps(m, indent=2))
PY
}

# ---------------------------------------------------------------- self-test (temp-repo only; real repo untouched)
self_test() {
  local P=0 F=0; ok(){ echo "  PASS $1"; P=$((P+1)); }; no(){ echo "  FAIL $1"; F=$((F+1)); }
  local TT; TT="$(mktemp -d)"; trap 'rm -rf "$TT"' RETURN
  local r="$TT/repo"; mkdir -p "$r"; ( cd "$r" && git init -q && git config user.email t@t && git config user.name t \
    && echo x > a.txt && git add a.txt && git commit -q -m init )
  printf '%s\n' 'Status: APPROVED' > "$TT/plan.md"
  printf '%s\n' 'a.txt' > "$TT/allow"
  local out; out="$(generate "$r" "v0.2.7-test" "$TT/plan.md" "$TT/allow" "vscript.sh" 10 0 "deferred")"
  # R1 valid JSON
  printf '%s' "$out" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null && ok "R1 manifest is valid JSON" || no "R1 invalid JSON"
  # R2/R3/R4/R5 fields
  printf '%s' "$out" | python3 -c 'import json,sys
m=json.load(sys.stdin)
assert m["approval_status"]=="APPROVED", "R3 status"
assert isinstance(m["allowed_files"],list) and m["allowed_files"]==["a.txt"], "R2 allowed"
assert isinstance(m["verification_pass"],int) and m["verification_pass"]==10, "R2 vpass"
assert m["live_calls"]=="disallowed" and m["credential_access"]=="disallowed", "R5 disallowed"
assert m["commit_hash"]!="none", "R4 hash"
assert m["gates"]["push"]=="deferred", "gate push"
print("ok")' >/dev/null 2>&1 && ok "R2/R3/R4/R5 fields populated + typed + disallowed defaults" || no "R2-R5 fields"
  # R6 no secret shapes in manifest
  printf '%s' "$out" | grep -qE 'sk-[A-Za-z0-9_-]{8,}|AKIA[0-9A-Z]{16}|eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.|BEGIN [A-Z ]*PRIVATE KEY' && no "R6 secret shape in manifest" || ok "R6 no secret/token shapes in manifest"
  # R7 --out writes only the named file, never git add; real index of temp repo unchanged
  local before; before="$(git -C "$r" diff --cached --name-only | wc -l | tr -d ' ')"
  generate "$r" "x" "$TT/plan.md" "$TT/allow" "v" 1 0 "deferred" > "$TT/m.json"
  local after; after="$(git -C "$r" diff --cached --name-only | wc -l | tr -d ' ')"
  [ -f "$TT/m.json" ] && [ "$before" = "$after" ] && ok "R7 --out wrote manifest only; repo index unchanged (no git add)" || no "R7 index changed"
  echo "  ---- self-test: PASS=$P FAIL=$F ----"; [ "$F" = 0 ]
}

# ---------------------------------------------------------------- args
MS=""; PLAN=""; ALLOW=""; REPO="."; VSCRIPT=""; VPASS=0; VFAIL=0; PUSH=""; OUT=""; MODE="gen"
while [ $# -gt 0 ]; do case "$1" in
  --milestone) MS="$2"; shift 2;; --plan) PLAN="$2"; shift 2;; --allowlist) ALLOW="$2"; shift 2;;
  --repo) REPO="$2"; shift 2;; --verify-script) VSCRIPT="$2"; shift 2;; --verify-pass) VPASS="$2"; shift 2;;
  --verify-fail) VFAIL="$2"; shift 2;; --push-state) PUSH="$2"; shift 2;; --out) OUT="$2"; shift 2;;
  --self-test) MODE="selftest"; shift;; -h|--help) sed -n '2,14p' "$0"; exit 0;;
  *) echo "run-manifest: unknown arg $1" >&2; exit 2;;
esac; done

if [ "$MODE" = selftest ]; then
  echo "==== DMC RUN MANIFEST — SELF-TEST (temp-repo only; real repo untouched) ===="
  self_test; exit $?
fi
[ -n "$MS" ] && [ -n "$PLAN" ] || { echo "run-manifest: --milestone and --plan are required" >&2; exit 2; }
if [ -n "$OUT" ]; then generate "$REPO" "$MS" "$PLAN" "$ALLOW" "$VSCRIPT" "$VPASS" "$VFAIL" "$PUSH" > "$OUT"; echo "run-manifest: wrote $OUT" >&2
else generate "$REPO" "$MS" "$PLAN" "$ALLOW" "$VSCRIPT" "$VPASS" "$VFAIL" "$PUSH"; fi
