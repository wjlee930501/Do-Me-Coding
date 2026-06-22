#!/usr/bin/env bash
# DMC Resume / Recovery Controller (v0.5.7) — ADVISORY / READ-ONLY, deterministic, inert unless invoked.
#
# Given declared git-state + run facts, determines the NEXT SAFE ACTION after an interruption. It NEVER emits "safe to
# commit/push" — at most it surfaces a `needs_human_gate` CANDIDATE bound to the exact commit hash; the actual push/commit
# is always a separate human gate (Codex-R6). Fail-CLOSED: a dirty tracked worktree, a staged protected/auto-log file, a
# local branch behind origin, a failed verification, or a missing/stale plan approval ⇒ STOP (never push, never infer a
# gate from stale state). Dirty-only-excluded-auto-logs is classified safe. Reads no env/.env/credential; no network/live.
#
# Usage: dmc-v0.5.7-resume-recovery.sh [--branch b] [--ahead N] [--behind N] [--tracked-dirty bool]
#          [--staged-protected bool] [--staged-autolog bool] [--untracked-autolog-only bool] [--plan-status S]
#          [--plan-hash-match bool] [--verification PASS|FAIL|NONE] [--commit-hash sha] [--out file]
#          | --from <facts.json> | --self-test
# Exit: 0 = action emitted, 1 = STOP/blocked, 2 = usage/refused.
set -u
set -o pipefail
export PYTHONDONTWRITEBYTECODE=1
SELFPATH="$(cd "$(dirname "$0")" 2>/dev/null && pwd -P)/$(basename "$0")"
ROOTDIR="$(cd "$(dirname "$SELFPATH")/../.." 2>/dev/null && pwd -P || true)"
[ -n "$ROOTDIR" ] || ROOTDIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
repo_hash() { git -C "$ROOTDIR" status --porcelain 2>/dev/null | python3 -c 'import hashlib,sys; sys.stdout.write(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())'; }

PROT_RE='(^|/)(\.env)(\.|$)|\.pem$|\.key$|id_rsa|id_ed25519|credentials|secret|\.p12$|\.pfx$|\.keystore$|\.claude/hooks|provider-router\.py'
out_refused() { local raw="$1"
  printf '%s' "$raw" | grep -qE '(^|/)\.\.(/|$)' && return 0
  case "$raw" in *.env|*.env.local|*.env.*) case "$raw" in *.example|*.sample|*.template) ;; *) return 0;; esac;; esac
  printf '%s' "$raw" | grep -qiE "$PROT_RE" && return 0
  [ -L "$raw" ] && return 0
  local parent base cparent canon; parent="$(dirname "$raw" 2>/dev/null)"; base="$(basename "$raw")"
  cparent="$(cd "$parent" 2>/dev/null && pwd -P)" || return 0; canon="$cparent/$base"
  printf '%s' "$canon" | grep -qiE "$PROT_RE" && return 0
  case "$canon/" in "$ROOTDIR"/*) return 0;; esac
  git -C "$ROOTDIR" ls-files --error-unmatch -- "$canon" >/dev/null 2>&1 && return 0
  return 1
}

decide() { # <facts.json>
  python3 - "$1" <<'PY'
import json,sys
try:
    F=json.load(open(sys.argv[1]))
    if not isinstance(F,dict): raise ValueError
except Exception:
    print("resume-recovery: invalid facts JSON", file=sys.stderr); sys.exit(2)
def b_true(k): return str(F.get(k,"")).strip().lower() in ("1","true","yes","on","enabled","y")
def b_falseexplicit(k): return str(F.get(k,"__MISSING__")).strip().lower() in ("0","false","no","off")
def num(v):
    try: return int(v)
    except Exception:
        try: return int(float(v))
        except Exception: return None
branch=str(F.get("branch","")).strip()
ahead=num(F.get("ahead",0)); behind=num(F.get("behind",0))
veri=str(F.get("verification","NONE")).strip().upper()
plan=str(F.get("plan_status","")).strip().upper()
commit=str(F.get("commit_hash","")).strip()
# fail-closed numerics: unparseable ahead/behind => treat as "unknown / behind>0" (stop)
behind_unknown = behind is None; ahead_unknown = ahead is None
behind = 999 if behind_unknown else behind
ahead = 0 if ahead_unknown else ahead
def emit(action, gate, reason, code):
    out=["# DMC Resume / Recovery — next safe action",
         "- branch: %s   ahead: %s   behind: %s"%(branch or "-", ("?" if ahead_unknown else ahead), ("?" if behind_unknown else behind)),
         "- next_action: %s"%action,
         "- gate: %s"%gate,
         "- blocked_reason: %s"%(reason or "none"),
         "- note: this NEVER authorizes a push/commit — it surfaces a candidate that REQUIRES a separate explicit human gate"]
    print("\n".join(out)); sys.exit(code)
# ordered, fail-closed: most-blocking first
if veri=="FAIL":
    emit("STOP","none","verification FAILED — fix and re-verify before any further step",1)
if b_true("staged_protected"):
    emit("STOP","none","a PROTECTED file is staged — unstage; protected-surface work needs an approved plan + human gate",1)
if b_true("staged_autolog"):
    emit("STOP","none","an excluded auto-log (.harness/evidence/*.md) is staged — unstage it (not a committable artifact)",1)
if b_true("tracked_dirty"):
    emit("STOP","none","dirty tracked worktree (uncommitted tracked changes) — commit/review first; NEVER push with uncommitted changes",1)
if behind>0:
    emit("STOP","none","local branch is %s behind origin — reconcile first; do NOT push"%("?" if behind_unknown else behind),1)
if plan!="APPROVED" or not b_true("plan_hash_match"):
    emit("PLAN_OR_CRITIC","none","plan approval missing or STALE (plan_status=%s, hash_match=%s) — go to plan/critic, NOT implementation; never infer approval from stale run state"%(plan or "<none>", b_true("plan_hash_match")),1)
if veri=="NONE":
    emit("VERIFY","none","approved but unverified — run the verification harness for the current head",1)
# clean, committed, ahead, verified, approved => a needs_human_gate CANDIDATE (never an authorization)
if veri=="PASS" and ahead>0 and not ahead_unknown:
    emit("NEEDS_HUMAN_GATE","needs_human_gate: candidate for review-branch push (bound to commit %s)"%(commit or "<unknown>"),
         "none — clean, verified, approved, ahead of origin; awaiting an explicit human push gate",0)
emit("IN_PROGRESS","none","nothing safe to advance autonomously (no work staged/ahead, or facts incomplete)",1)
PY
}

self_test() {
  local P=0 F=0; ok(){ echo "  PASS $1"; P=$((P+1)); }; no(){ echo "  FAIL $1"; F=$((F+1)); }
  local TT; TT="$(mktemp -d)" || { echo "  FATAL: mktemp -d failed"; return 2; }; [ -d "$TT" ] || { echo "  FATAL: temp dir missing"; return 2; }; trap 'rm -rf "$TT"' RETURN
  local PRE; PRE="$(repo_hash)"
  d(){ printf '%s' "$1" > "$TT/f.json"; decide "$TT/f.json"; }
  act(){ d "$1" | awk -F': ' '/^- next_action:/{print $2}'; }
  CLEAN='{"branch":"dmc-x/v","ahead":3,"behind":0,"tracked_dirty":false,"staged_protected":false,"staged_autolog":false,"plan_status":"APPROVED","plan_hash_match":true,"verification":"PASS","commit_hash":"abc1234"}'

  # AC1 clean+committed+ahead+verified+approved => NEEDS_HUMAN_GATE review-push candidate (NOT "safe to push")
  { [ "$(act "$CLEAN")" = NEEDS_HUMAN_GATE ] && d "$CLEAN" | grep -q 'candidate for review-branch push (bound to commit abc1234)' \
    && ! d "$CLEAN" | grep -qiE 'safe to (push|commit)'; } \
    && ok "AC1 clean ahead verified approved => needs_human_gate review-push candidate (bound to commit; never 'safe to push')" || no "AC1 ($(act "$CLEAN"))"
  # AC2 dirty tracked file => STOP
  [ "$(act '{"tracked_dirty":true,"ahead":1,"verification":"PASS","plan_status":"APPROVED","plan_hash_match":true}')" = STOP ] \
    && ok "AC2 dirty tracked worktree => STOP (never push with uncommitted changes)" || no "AC2 dirty not stopped"
  # AC3 staged auto-log => STOP; AC3b staged protected => STOP
  { [ "$(act '{"staged_autolog":true,"ahead":1,"verification":"PASS","plan_status":"APPROVED","plan_hash_match":true}')" = STOP ] \
    && [ "$(act '{"staged_protected":true,"ahead":1,"verification":"PASS","plan_status":"APPROVED","plan_hash_match":true}')" = STOP ]; } \
    && ok "AC3 staged auto-log OR staged protected => STOP (do not commit)" || no "AC3 bad-staged not stopped"
  # AC4 untracked auto-log only (tracked_dirty false) => proceeds (not stopped on dirtiness)
  [ "$(act '{"untracked_autolog_only":true,"tracked_dirty":false,"ahead":2,"verification":"PASS","plan_status":"APPROVED","plan_hash_match":true,"commit_hash":"d"}')" = NEEDS_HUMAN_GATE ] \
    && ok "AC4 dirty only excluded auto-logs => classified safe (proceeds to gate candidate)" || no "AC4 autolog-only blocked"
  # AC5 local behind origin => STOP
  { [ "$(act '{"behind":2,"ahead":1,"verification":"PASS","plan_status":"APPROVED","plan_hash_match":true}')" = STOP ] \
    && [ "$(act '{"behind":"weird","ahead":1,"verification":"PASS","plan_status":"APPROVED","plan_hash_match":true}')" = STOP ]; } \
    && ok "AC5 behind origin (or unparseable behind) => STOP (do not push)" || no "AC5 behind not stopped"
  # AC6 approval missing => PLAN_OR_CRITIC (not implement); AC6b stale approval => PLAN_OR_CRITIC
  { [ "$(act '{"plan_status":"DRAFT","plan_hash_match":true,"ahead":1,"verification":"PASS"}')" = PLAN_OR_CRITIC ] \
    && [ "$(act '{"plan_status":"APPROVED","plan_hash_match":false,"ahead":1,"verification":"PASS"}')" = PLAN_OR_CRITIC ]; } \
    && ok "AC6 missing OR stale approval => PLAN_OR_CRITIC (never infer approval from stale run state)" || no "AC6 approval inference"
  # AC7 verification FAIL => STOP
  [ "$(act '{"verification":"FAIL","ahead":1,"plan_status":"APPROVED","plan_hash_match":true}')" = STOP ] \
    && ok "AC7 verification FAIL => STOP" || no "AC7 fail not stopped"
  # AC8 verification NONE (approved) => VERIFY
  [ "$(act '{"verification":"NONE","ahead":1,"plan_status":"APPROVED","plan_hash_match":true}')" = VERIFY ] \
    && ok "AC8 approved but unverified => VERIFY" || no "AC8 verify path"
  # AC9 NEVER emits a 'safe to commit/push' authorization across the whole decision space
  local leaked=0 fx
  for fx in "$CLEAN" '{"tracked_dirty":true}' '{"verification":"FAIL"}' '{"plan_status":"DRAFT"}' '{"behind":2}' '{"staged_protected":true}' '{"verification":"NONE","plan_status":"APPROVED","plan_hash_match":true,"ahead":1}'; do
    d "$fx" 2>/dev/null | grep -qiE 'safe to (push|commit)|you may (push|commit)|authorized to (push|commit)' && leaked=1
  done
  [ "$leaked" = 0 ] && ok "AC9 never emits a 'safe to push/commit' authorization (only needs_human_gate candidates)" || no "AC9 authorization phrasing leaked"
  # AC10 deterministic + env-independent
  printf '%s' "$CLEAN" > "$TT/c.json"; local b1; b1="$(decide "$TT/c.json")"
  local envi; envi="$(env -i PATH="$PATH" HOME="${HOME:-/tmp}" bash "$SELFPATH" --from "$TT/c.json" 2>/dev/null)"
  local diff_ok=1 v; for v in GLM_API_KEY ANTHROPIC_API_KEY DMC_RESUME; do [ "$(env "$v=NEEDS_HUMAN_GATE" bash "$SELFPATH" --from "$TT/c.json" 2>/dev/null)" = "$b1" ] || diff_ok=0; done
  { [ "$envi" = "$b1" ] && [ "$diff_ok" = 1 ]; } && ok "AC10 deterministic + env-independent" || no "AC10 env-dependent"
  # AC11 structural audit
  local OP; OP="$(sed '/AUDIT_BLOCK_START/,/AUDIT_BLOCK_END/d' "$SELFPATH" | grep -vE '^[[:space:]]*#')"
  # >>>AUDIT_BLOCK_START
  ! printf '%s' "$OP" | grep -nE '(^|[^A-Za-z])(curl|wget)([[:space:]])| --live | --allow-network|os\.environ|getenv|printenv|HASH_CMD|\$\{DMC_' >/dev/null \
    && ok "AC11 no net/env-read/env-hash in operative source" || no "AC11 net/env present"
  # >>>AUDIT_BLOCK_END
  # AC12 env-hash injection
  # >>>AUDIT_BLOCK_START  (hostile-input test; excluded from the operative-source audit)
  local SENT="$TT/sentinel" FAKE="$TT/fakehash"; printf '#!/bin/sh\ntouch "%s"\necho PWNED\n' "$SENT" > "$FAKE"; chmod +x "$FAKE"
  local hb hh; hb="$(repo_hash)"; hh="$(DMC_HASH_CMD="$FAKE" repo_hash)"
  { [ ! -e "$SENT" ] && [ -n "$hb" ] && [ "$hb" = "$hh" ]; } && ok "AC12 env-hash injection: hostile DMC_HASH_CMD never read/executed" || no "AC12 env-controlled hash executed"
  # >>>AUDIT_BLOCK_END
  # AC13 read-only
  { [ -n "$PRE" ] && [ "$(repo_hash)" = "$PRE" ]; } && ok "AC13 read-only: repo byte-unchanged (deterministic sha256)" || no "AC13 repo changed"

  echo "  ---- self-test: PASS=$P FAIL=$F ----"; [ "$F" = 0 ]
}

BR=""; AH=0; BE=0; TD=false; SP=false; SA=false; UAO=false; PSTAT=""; PHM=false; VER="NONE"; CH=""; FROM=""; OUT=""; RUN=run
while [ $# -gt 0 ]; do case "$1" in
  --branch) BR="$2"; shift 2;; --ahead) AH="$2"; shift 2;; --behind) BE="$2"; shift 2;; --tracked-dirty) TD="$2"; shift 2;;
  --staged-protected) SP="$2"; shift 2;; --staged-autolog) SA="$2"; shift 2;; --untracked-autolog-only) UAO="$2"; shift 2;;
  --plan-status) PSTAT="$2"; shift 2;; --plan-hash-match) PHM="$2"; shift 2;; --verification) VER="$2"; shift 2;; --commit-hash) CH="$2"; shift 2;;
  --from) FROM="$2"; shift 2;; --out) OUT="$2"; shift 2;; --self-test) RUN=selftest; shift;; -h|--help) sed -n '2,13p' "$0"; exit 0;;
  *) echo "resume-recovery: unknown arg $1" >&2; exit 2;;
esac; done
if [ "$RUN" = selftest ]; then echo "==== DMC RESUME / RECOVERY — SELF-TEST ===="; self_test; exit $?; fi
INF=""
if [ -n "$FROM" ]; then [ -f "$FROM" ] || { echo "resume-recovery: --from file not found" >&2; exit 2; }; INF="$FROM"
else
  INF="$(mktemp)"; trap 'rm -f "$INF"' EXIT
  python3 - "$BR" "$AH" "$BE" "$TD" "$SP" "$SA" "$UAO" "$PSTAT" "$PHM" "$VER" "$CH" > "$INF" <<'PY'
import json,sys
k=["branch","ahead","behind","tracked_dirty","staged_protected","staged_autolog","untracked_autolog_only","plan_status","plan_hash_match","verification","commit_hash"]
print(json.dumps(dict(zip(k,sys.argv[1:12]))))
PY
fi
if [ -n "$OUT" ]; then out_refused "$OUT" && { echo "resume-recovery: --out protected/secret/in-work-tree — REFUSED" >&2; exit 2; }; decide "$INF" > "$OUT"; rc=$?; echo "resume-recovery: wrote $OUT" >&2; exit $rc; fi
decide "$INF"; exit $?
