#!/usr/bin/env bash
# DMC Workflow State Machine (v0.5.4) — ADVISORY / READ-ONLY, deterministic, inert unless invoked.
#
# A STATE-DISCIPLINE tool (NOT an enforcement hook). Validates a single transition or a full path across
# DRAFT/CRITIC/APPROVED/START_WORK/VERIFY/RELEASE_AUDIT/STAGE/COMMIT/PUSH/CLOSURE/BLOCKED, and evaluates E2E-DONE. Every
# gated transition is bound to IMMUTABLE run facts (plan status+hash-match, run_id-match, verification PASS @ matching head,
# release-audit ACCEPT, staged-digest-match, no-protected/auto-log-staged, commit-present, explicit push/closure
# authorization). Missing/mismatched facts ⇒ BLOCKED (fail-closed). `critic PASS` is advisory and never authorizes
# push/main/closure. Reads no env/.env/credential; no network/live call; resume-safe (never infers a gate from stale state).
#
# Usage: dmc-v0.5.4-workflow-state-machine.sh --transition --from <S> --to <S> --facts <json>
#          | --done --facts <json>  | --self-test
# Exit: 0 = ALLOWED / DONE, 1 = BLOCKED / NOT-DONE, 2 = usage.
set -u
set -o pipefail
export PYTHONDONTWRITEBYTECODE=1
SELFPATH="$(cd "$(dirname "$0")" 2>/dev/null && pwd -P)/$(basename "$0")"
ROOTDIR="$(cd "$(dirname "$SELFPATH")/../.." 2>/dev/null && pwd -P || true)"
[ -n "$ROOTDIR" ] || ROOTDIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
# deterministic internal worktree-status hash — reads NO env var and executes NO env-controlled command (python hashlib)
repo_hash() { git -C "$ROOTDIR" status --porcelain 2>/dev/null | python3 -c 'import hashlib,sys; sys.stdout.write(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())'; }

engine() { # <mode: transition|done> <from|-> <to|-> <facts.json>
  python3 - "$@" <<'PY'
import json,sys
mode=sys.argv[1]; frm=sys.argv[2]; to=sys.argv[3]
try:
    F=json.load(open(sys.argv[4]))
    if not isinstance(F,dict): raise ValueError
except Exception:
    print("state-machine: invalid facts JSON", file=sys.stderr); sys.exit(2)
STATES={"DRAFT","CRITIC","APPROVED","START_WORK","VERIFY","RELEASE_AUDIT","STAGE","COMMIT","PUSH","CLOSURE","BLOCKED"}
def istrue(k): return str(F.get(k,"")).strip().lower() in ("1","true","yes")     # missing => False (fail-closed)
def isfalse_required(k): return str(F.get(k,"__MISSING__")).strip().lower() in ("0","false","no")  # must be EXPLICITLY false
def eq(k,v): return str(F.get(k,"")).strip().upper()==v
# allowed (from,to) -> list of predicate checks; a missing/mismatched fact fails the predicate (=> BLOCKED)
def chk_true(k): return ("true",k)
def chk_false(k): return ("false",k)   # requires an EXPLICIT false fact (fail-closed: missing != false)
def chk_eq(k,v): return ("eq",k,v)
T={
 ("DRAFT","CRITIC"):[],
 ("CRITIC","DRAFT"):[],                                  # REVISE
 ("CRITIC","APPROVED"):[chk_eq("critic","PASS")],
 ("APPROVED","START_WORK"):[chk_eq("plan_status","APPROVED"),chk_true("plan_hash_match"),chk_true("run_id_match")],
 ("START_WORK","VERIFY"):[chk_true("run_id_match")],
 ("VERIFY","RELEASE_AUDIT"):[chk_eq("verification","PASS"),chk_true("verification_head_match")],
 ("RELEASE_AUDIT","STAGE"):[chk_eq("release_audit","ACCEPT")],
 ("STAGE","COMMIT"):[chk_true("staged_digest_match"),chk_false("protected_staged"),chk_false("autolog_staged")],
 ("COMMIT","PUSH"):[chk_true("commit_present"),chk_false("staged_dirty"),chk_true("push_authorized")],
 ("PUSH","CLOSURE"):[chk_true("published"),chk_true("closure_authorized")],
}
def passes(pred):
    t=pred[0]
    if t=="true": return istrue(pred[1])
    if t=="false": return isfalse_required(pred[1])
    if t=="eq": return eq(pred[1],pred[2])
    return False
if mode=="transition":
    if frm not in STATES or to not in STATES:
        print("state-machine: BLOCKED — unknown state", file=sys.stderr); sys.exit(1)
    if to=="BLOCKED":
        print("ALLOWED: any -> BLOCKED (fail transition)"); sys.exit(0)
    if (frm,to) not in T:
        print("BLOCKED: %s -> %s is not an allowed transition (forbidden / out-of-order)"%(frm,to)); sys.exit(1)
    fails=[p for p in T[(frm,to)] if not passes(p)]
    if fails:
        print("BLOCKED: %s -> %s — unmet/missing bindings: %s"%(frm,to,", ".join("%s"%(p[1:],) for p in fails))); sys.exit(1)
    print("ALLOWED: %s -> %s (all immutable bindings satisfied)"%(frm,to)); sys.exit(0)
# done evaluator: distinguishes accepted-for-review vs published-to-main vs closure-recorded; bound to IMMUTABLE run facts
req_main = not isfalse_required("requires_main")        # default TRUE unless explicitly false (fail-closed)
req_clo  = not isfalse_required("requires_closure")
# IMMUTABLE bindings required for ANY DONE — stale/unbound facts can never be promoted to DONE (Codex-R4 / mid-batch #3)
bindings_ok = istrue("run_id_match") and istrue("plan_hash_match") and istrue("verification_head_match")
if istrue("closure_recorded") and req_main and not istrue("published_to_main"):
    print("INVALID: closure_recorded but main not published"); sys.exit(1)
need=[eq("verification","PASS"),eq("release_audit","ACCEPT"),istrue("commit_present"),bindings_ok]
if req_main: need.append(istrue("published_to_main"))
if req_clo:  need.append(istrue("closure_recorded") and istrue("closure_authorized"))
if all(need):
    print("DONE: all required gates + immutable bindings satisfied (verified@head, reviewed, committed%s%s)"%(", published" if req_main else "", ", closed" if req_clo else "")); sys.exit(0)
if not bindings_ok:
    print("IN_PROGRESS: immutable bindings (run_id/plan_hash/verification_head match) missing or stale — cannot be DONE"); sys.exit(1)
if istrue("published_to_main") and req_clo and not istrue("closure_recorded"):
    print("IN_PROGRESS: published to main but closure not recorded"); sys.exit(1)
print("IN_PROGRESS: not all required gates met (no false E2E-DONE)"); sys.exit(1)
PY
}

self_test() {
  local P=0 F=0; ok(){ echo "  PASS $1"; P=$((P+1)); }; no(){ echo "  FAIL $1"; F=$((F+1)); }
  local TT; TT="$(mktemp -d)" || { echo "  FATAL: mktemp -d failed"; return 2; }; [ -d "$TT" ] || { echo "  FATAL: temp dir missing"; return 2; }; trap 'rm -rf "$TT"' RETURN
  local PRE; PRE="$(repo_hash)"
  J(){ printf '%s' "$1" > "$TT/f.json"; }
  trans(){ J "$3"; engine transition "$1" "$2" "$TT/f.json" >/dev/null 2>&1; echo $?; }   # 0=ALLOWED 1=BLOCKED
  done_st(){ J "$1"; engine done - - "$TT/f.json" 2>/dev/null; }

  local GOOD='{"critic":"PASS","plan_status":"APPROVED","plan_hash_match":true,"run_id_match":true,"verification":"PASS","verification_head_match":true,"release_audit":"ACCEPT","staged_digest_match":true,"protected_staged":false,"autolog_staged":false,"commit_present":true,"staged_dirty":false,"push_authorized":true,"published":true,"closure_authorized":true}'

  # AC1 a valid milestone path passes end-to-end
  local path_ok=1 a b
  set -- DRAFT CRITIC APPROVED START_WORK VERIFY RELEASE_AUDIT STAGE COMMIT PUSH CLOSURE
  a="$1"; shift
  for b in "$@"; do [ "$(trans "$a" "$b" "$GOOD")" = 0 ] || path_ok=0; a="$b"; done
  [ "$path_ok" = 1 ] && ok "AC1 valid milestone path DRAFT..CLOSURE all ALLOWED" || no "AC1 valid path blocked"

  # AC2 DRAFT -> START_WORK (skip approval) => BLOCKED
  [ "$(trans DRAFT START_WORK "$GOOD")" = 1 ] && ok "AC2 DRAFT->START_WORK (no approval) => BLOCKED" || no "AC2 premature implement"
  # AC3 stale approval (plan_hash_match=false) => BLOCKED
  [ "$(trans APPROVED START_WORK '{"plan_status":"APPROVED","plan_hash_match":false,"run_id_match":true}')" = 1 ] \
    && ok "AC3 stale approval (plan_hash mismatch) => BLOCKED" || no "AC3 stale approval allowed"
  # AC3b missing binding (run_id_match absent) => BLOCKED (fail-closed)
  [ "$(trans APPROVED START_WORK '{"plan_status":"APPROVED","plan_hash_match":true}')" = 1 ] \
    && ok "AC3b missing run_id_match binding => BLOCKED (fail-closed)" || no "AC3b missing binding allowed"
  # AC4 COMMIT -> CLOSURE (skip PUSH) => BLOCKED (premature DONE / out of order)
  [ "$(trans COMMIT CLOSURE "$GOOD")" = 1 ] && ok "AC4 COMMIT->CLOSURE (skip PUSH) => BLOCKED" || no "AC4 closure skips push"
  # AC5 critic PASS does NOT authorize PUSH (gate confusion): CRITIC->PUSH => BLOCKED
  [ "$(trans CRITIC PUSH "$GOOD")" = 1 ] && ok "AC5 CRITIC->PUSH => BLOCKED (critic PASS is advisory, not a push gate)" || no "AC5 critic authorizes push"
  # AC5b COMMIT->PUSH without push_authorized => BLOCKED; with it => ALLOWED
  { [ "$(trans COMMIT PUSH '{"commit_present":true,"staged_dirty":false,"push_authorized":false}')" = 1 ] \
    && [ "$(trans COMMIT PUSH '{"commit_present":true,"staged_dirty":false,"push_authorized":true}')" = 0 ]; } \
    && ok "AC5b PUSH gated on explicit push_authorized (not critic/audit)" || no "AC5b push gate"
  # AC6 STAGE->COMMIT blocked if protected or auto-log staged
  { [ "$(trans STAGE COMMIT '{"staged_digest_match":true,"protected_staged":true,"autolog_staged":false}')" = 1 ] \
    && [ "$(trans STAGE COMMIT '{"staged_digest_match":true,"protected_staged":false,"autolog_staged":true}')" = 1 ]; } \
    && ok "AC6 STAGE->COMMIT BLOCKED when protected/auto-log staged" || no "AC6 bad stage allowed"
  # AC7 VERIFY->RELEASE_AUDIT blocked on verification FAIL or head mismatch
  { [ "$(trans VERIFY RELEASE_AUDIT '{"verification":"FAIL","verification_head_match":true}')" = 1 ] \
    && [ "$(trans VERIFY RELEASE_AUDIT '{"verification":"PASS","verification_head_match":false}')" = 1 ]; } \
    && ok "AC7 VERIFY->RELEASE_AUDIT BLOCKED on FAIL or stale head" || no "AC7 bad verify allowed"

  # AC8 done: premature DONE rejected (only committed, not published/closed) => IN_PROGRESS (exit 1)
  local prem; prem="$(done_st '{"verification":"PASS","release_audit":"ACCEPT","commit_present":true,"published_to_main":false,"closure_recorded":false}')"
  printf '%s' "$prem" | grep -q '^IN_PROGRESS' && ok "AC8 premature DONE rejected => IN_PROGRESS (committed, not published/closed)" || no "AC8 premature DONE ($prem)"
  # AC9 PR merged (published) but closure missing => IN_PROGRESS
  local m; m="$(done_st '{"verification":"PASS","release_audit":"ACCEPT","commit_present":true,"published_to_main":true,"closure_recorded":false}')"
  printf '%s' "$m" | grep -q 'IN_PROGRESS' && ok "AC9 published-to-main but closure missing => IN_PROGRESS" || no "AC9 ($m)"
  # AC10 closure recorded but main NOT published => INVALID
  local inv; inv="$(done_st '{"verification":"PASS","release_audit":"ACCEPT","commit_present":true,"published_to_main":false,"closure_recorded":true}')"
  printf '%s' "$inv" | grep -q '^INVALID' && ok "AC10 closure recorded but main not published => INVALID" || no "AC10 ($inv)"
  # AC11 full E2E + immutable bindings satisfied => DONE
  local d; d="$(done_st '{"verification":"PASS","release_audit":"ACCEPT","commit_present":true,"published_to_main":true,"closure_recorded":true,"closure_authorized":true,"run_id_match":true,"plan_hash_match":true,"verification_head_match":true}')"
  printf '%s' "$d" | grep -q '^DONE' && ok "AC11 all required gates + immutable bindings met => DONE (no false DONE elsewhere)" || no "AC11 ($d)"
  # AC11b review-only task (requires_main/closure=false) with bindings => DONE at commit
  local rv; rv="$(done_st '{"verification":"PASS","release_audit":"ACCEPT","commit_present":true,"requires_main":false,"requires_closure":false,"run_id_match":true,"plan_hash_match":true,"verification_head_match":true}')"
  printf '%s' "$rv" | grep -q '^DONE' && ok "AC11b review-only (requires_main/closure=false) => DONE at commit" || no "AC11b ($rv)"
  # AC11c (HARDENING / Codex #3) stale/unbound facts with ALL outcome flags true => NOT DONE (no false E2E-DONE from stale state)
  local stale; stale="$(done_st '{"verification":"PASS","release_audit":"ACCEPT","commit_present":true,"published_to_main":true,"closure_recorded":true,"closure_authorized":true,"run_id_match":false,"plan_hash_match":false,"verification_head_match":false}')"
  printf '%s' "$stale" | grep -q 'IN_PROGRESS' && ok "AC11c stale/unbound bindings (run_id/plan_hash/head mismatch) => IN_PROGRESS, never DONE" || no "AC11c stale promoted to DONE ($stale)"

  # AC12 deterministic + env-independent
  J "$GOOD"; local o1; o1="$(engine transition COMMIT PUSH "$TT/f.json" 2>/dev/null)"
  local envi; envi="$(env -i PATH="$PATH" HOME="${HOME:-/tmp}" bash "$SELFPATH" --transition --from COMMIT --to PUSH --facts "$TT/f.json" 2>/dev/null)"
  local diff_ok=1 v
  for v in GLM_API_KEY ANTHROPIC_API_KEY DMC_STATE; do
    [ "$(env "$v=ALLOWED" bash "$SELFPATH" --transition --from COMMIT --to PUSH --facts "$TT/f.json" 2>/dev/null)" = "$o1" ] || diff_ok=0
  done
  { [ "$envi" = "$o1" ] && [ "$diff_ok" = 1 ]; } && ok "AC12 deterministic + env-independent (env -i + credential differential byte-identical)" || no "AC12 env-dependent"
  # AC13 structural no-net/no-env/no-env-hash audit
  local OP; OP="$(sed '/AUDIT_BLOCK_START/,/AUDIT_BLOCK_END/d' "$SELFPATH" | grep -vE '^[[:space:]]*#')"
  # >>>AUDIT_BLOCK_START
  ! printf '%s' "$OP" | grep -nE '(^|[^A-Za-z])(curl|wget)([[:space:]])| --live | --allow-network|os\.environ|getenv|printenv|HASH_CMD|\$\{DMC_' >/dev/null \
    && ok "AC13 no curl/wget/--live, no env-read, no env-hash in the operative source" || no "AC13 net/env present"
  # >>>AUDIT_BLOCK_END
  # AC14 env-hash injection
  # >>>AUDIT_BLOCK_START  (hostile-input test; excluded from the operative-source audit)
  local SENT="$TT/sentinel" FAKE="$TT/fakehash"; printf '#!/bin/sh\ntouch "%s"\necho PWNED\n' "$SENT" > "$FAKE"; chmod +x "$FAKE"
  local hb hh; hb="$(repo_hash)"; hh="$(DMC_HASH_CMD="$FAKE" repo_hash)"
  { [ ! -e "$SENT" ] && [ -n "$hb" ] && [ "$hb" = "$hh" ]; } && ok "AC14 env-hash injection: hostile DMC_HASH_CMD never read/executed" || no "AC14 env-controlled hash executed"
  # >>>AUDIT_BLOCK_END
  # AC15 read-only: repo byte-unchanged
  { [ -n "$PRE" ] && [ "$(repo_hash)" = "$PRE" ]; } && ok "AC15 read-only: repo byte-unchanged (deterministic sha256)" || no "AC15 repo changed"

  echo "  ---- self-test: PASS=$P FAIL=$F ----"; [ "$F" = 0 ]
}

MODE=""; FROM="-"; TO="-"; FACTS=""
while [ $# -gt 0 ]; do case "$1" in
  --transition) MODE=transition; shift;; --done) MODE=done; shift;;
  --from) FROM="$2"; shift 2;; --to) TO="$2"; shift 2;; --facts) FACTS="$2"; shift 2;;
  --self-test) MODE=selftest; shift;; -h|--help) sed -n '2,12p' "$0"; exit 0;;
  *) echo "state-machine: unknown arg $1" >&2; exit 2;;
esac; done
if [ "$MODE" = selftest ]; then echo "==== DMC WORKFLOW STATE MACHINE — SELF-TEST ===="; self_test; exit $?; fi
[ -n "$MODE" ] && [ -f "${FACTS:-/nonexistent}" ] || { echo "state-machine: --transition --from S --to S --facts <json> | --done --facts <json> | --self-test" >&2; exit 2; }
engine "$MODE" "$FROM" "$TO" "$FACTS"; exit $?
