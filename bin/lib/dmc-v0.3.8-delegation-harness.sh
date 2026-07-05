#!/usr/bin/env bash
# DMC Autonomous Delegation Harness validator (v0.3.8) — ADVISORY / READ-ONLY.
#
# Mechanically checks a milestone run's ALLOWED-AUTONOMY preconditions (plan APPROVED, separate critic=PASS, Codex ACCEPT
# as an advisory input, verification PASS) and the observable PUSH boundary (DEFERRED / PUSHED / UNKNOWN). It performs no
# action, grants no gate, mutates nothing, makes no live call, and reads no secret content:
#   - the --plan AND --verify-report paths are refused UNREAD if they match a secret pattern;
#   - git is metadata-only (rev-parse, merge-base); no content-dumping show/diff, no -p/patch, no log -p/diff-tree/
#     format-patch/cat-file; no commit body (%b);
#   - STAGE/COMMIT/PUSH/CLOSURE are GATED (handbook); a Codex ACCEPT is an advisory INPUT, never a grant. This validator
#     surfaces the gated actions; it does NOT grant them.
# Fail-closed: any absent/secret/ambiguous signal => the dependent check FAILs / push UNKNOWN => NON-COMPLIANT.
#
# Usage:  delegation-harness.sh --milestone <id> --plan <plan.md> --verify-report <report.md> --commit <ref>
#                               [--repo <dir>] [--push-approved] [--out <file>]
#         delegation-harness.sh --self-test
# Exit: 0 = AUTONOMY-COMPLIANT, 1 = NON-COMPLIANT (advisory — never wired to an action), 2 = usage/refused.
set -u
set -o pipefail
export PYTHONDONTWRITEBYTECODE=1

ROOTDIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SELFPATH="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/$(basename "$0")"

# --- --out write-target guard (v0.3.4–v0.3.7 hardened) ---
PROT_RE='(^|/)(\.env)(\.|$)|\.pem$|\.key$|id_rsa|id_ed25519|credentials|secret|\.p12$|\.pfx$|\.keystore$|\.claude/hooks|provider-router\.py|/ROUTING\.md$|WORKER_(TASK|RESULT|REVIEW)_SCHEMA\.md|PROVIDER_CONTRACT\.md|workers/providers/(glm-api|oauth-cli)|(^|/)dmc-glm-smoke$'
out_refused() { local raw="$1"
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
SECRET_RE='\.pem$|\.key$|id_rsa|id_ed25519|\.p12$|\.pfx$|\.keystore$|credentials|secret|service-account|(^|/)\.npmrc$|(^|/)\.netrc$|(^|/)\.pgpass$|(^|/)\.ssh/|\.aws/credentials'
is_secret_path() { local p="$1"
  case "$p" in *.env|*.env.local|*.env.*) case "$p" in *.example|*.sample|*.template) ;; *) return 0;; esac;; esac
  printf '%s' "$p" | grep -qiE "$SECRET_RE" && return 0; return 1; }

# --- precondition checks (each echoes PASS or FAIL; fail-closed; secret-path-guarded) ---
chk_plan_approved() { local f="$1"
  { [ -z "$f" ] || is_secret_path "$f" || [ ! -f "$f" ]; } && { echo FAIL; return; }
  grep -qE '^Approval Status: APPROVED' "$f" 2>/dev/null && echo PASS || echo FAIL; }
chk_critic_pass() { local f="$1"
  { [ -z "$f" ] || is_secret_path "$f" || [ ! -f "$f" ]; } && { echo FAIL; return; }
  grep -qE '^Review-Verdict: critic=PASS( |$)' "$f" 2>/dev/null && echo PASS || echo FAIL; }
chk_codex_accept() { local f="$1"   # exact canonical line; advisory input, NOT a grant (per v0.3.7)
  { [ -z "$f" ] || is_secret_path "$f" || [ ! -f "$f" ]; } && { echo FAIL; return; }
  grep -qE '^Review-Verdict: critic=PASS codex=ACCEPT[[:space:]]*$' "$f" 2>/dev/null && echo PASS || echo FAIL; }
chk_verification() { local f="$1"   # refines the v0.3.7 verified rule: scope the Final-Status marker to its section and
  # disqualify on a STRUCTURED failing-count line (N PASS / M>0 FAIL) — NOT a bare 'N FAIL' in prose (a real report's
  # AC descriptions legitimately mention failure-count fixtures like '0 FAIL + 3 FAIL').
  { [ -z "$f" ] || is_secret_path "$f" || [ ! -f "$f" ]; } && { echo FAIL; return; }
  local fs countok
  fs="$(awk '/^## Final Status/{s=1} s && match($0,/\*\*(PASS|FAIL|PARTIAL)\*\*/){print substr($0,RSTART+2,RLENGTH-4); exit}' "$f" 2>/dev/null)"
  [ "$fs" = PASS ] || { echo FAIL; return; }
  if grep -qE '[0-9]+ PASS / 0 FAIL' "$f" 2>/dev/null; then countok=1
  elif grep -oE '[0-9]+/[0-9]+' "$f" 2>/dev/null | awk -F/ '$1==$2 && $1+0>0{x=1} END{exit !x}'; then countok=1; fi
  if grep -qE '[0-9]+ PASS / [1-9][0-9]* FAIL' "$f" 2>/dev/null; then echo FAIL; return; fi
  [ "${countok:-}" = 1 ] && echo PASS || echo FAIL; }

# --- push boundary: DEFERRED (compliant) | PUSHED (needs approval) | UNKNOWN (fail-closed). Polarity is INVERTED vs the
#     v0.3.7 closure 'pushed' judge (there ancestor=>MET; here ancestor=>PUSHED=>flagged). ---
judge_push() { local repo="$1" ref="$2"
  git -C "$repo" rev-parse --verify "$ref^{commit}" >/dev/null 2>&1 || { echo UNKNOWN; return; }
  git -C "$repo" rev-parse --verify origin/main >/dev/null 2>&1 || { echo UNKNOWN; return; }
  git -C "$repo" merge-base --is-ancestor "$ref" origin/main 2>/dev/null && echo PUSHED || echo DEFERRED; }

# --- run the validator: write the report to <outfile>; return 0 if AUTONOMY-COMPLIANT else 1 ---
run_harness() { # <outfile> <repo> <milestone> <plan> <report> <ref> <push_approved:0|1>
  local outfile="$1" repo="$2" ms="$3" plan="$4" report="$5" ref="$6" pa="$7"
  local pa_s ca cp cx vf push fail="" pushok
  pa_s="$(chk_plan_approved "$plan")"; cp="$(chk_critic_pass "$report")"; cx="$(chk_codex_accept "$report")"; vf="$(chk_verification "$report")"
  push="$(judge_push "$repo" "$ref")"
  case "$push" in
    DEFERRED) pushok=1;;
    PUSHED)   [ "$pa" = 1 ] && pushok=1 || pushok=0;;
    *)        pushok=0;;
  esac
  for kv in "plan-approved:$pa_s" "separate-critic-pass:$cp" "codex-accept-input:$cx" "verification-pass:$vf"; do
    [ "${kv##*:}" = FAIL ] && fail="$fail ${kv%%:*}"
  done
  [ "$pushok" = 1 ] || fail="$fail push-boundary($push)"

  {
    echo "# DMC Delegation Harness — $ms"
    echo
    echo "_read-only · advisory · validates allowed-autonomy preconditions + the push boundary · grants no gate_"
    echo
    echo "## Allowed-autonomy preconditions"
    echo "| check | status |"
    echo "|---|---|"
    echo "| plan-approved | $pa_s |"
    echo "| separate-critic-pass | $cp |"
    echo "| codex-accept-input (advisory; NOT a grant) | $cx |"
    echo "| verification-pass | $vf |"
    echo
    echo "## Push boundary (a GATED action)"
    case "$push" in
      DEFERRED) echo "- push: **DEFERRED** — correctly deferred to the per-action human gate (compliant).";;
      PUSHED)   if [ "$pa" = 1 ]; then echo "- push: **PUSHED** — recorded human approval supplied (\`--push-approved\`)."
                else echo "- push: **PUSHED** — performed; **requires** a recorded human approval (\`--push-approved\`). NON-COMPLIANT."; fi;;
      *)        echo "- push: **UNKNOWN** — unresolvable ref or absent local \`origin/main\`; fail-closed ⇒ NON-COMPLIANT.";;
    esac
    echo
    echo "## Judgment"
    if [ -z "$fail" ]; then echo "**AUTONOMY-COMPLIANT** — preconditions met; push boundary respected."
    else echo "**NON-COMPLIANT** — failing:$fail"; fi
    echo
    echo "## Gated actions (surfaced, not granted)"
    echo "STAGE, COMMIT, PUSH, CLOSURE are **human-gated** (handbook). Their authorization is a recorded human gate or a"
    echo "standing delegation; a Codex ACCEPT is an **advisory input**, never a grant. This validator confirms the"
    echo "allowed-autonomy preconditions + the push boundary; it does **not** grant STAGE/COMMIT/CLOSURE."
    echo
    echo "---"
    echo "_read-only/advisory; performs no action; grants no gate; metadata-only git; no secret content._"
  } > "$outfile"

  [ -z "$fail" ] && return 0 || return 1
}

# ---------------------------------------------------------------- self-test (no in-repo writes; $TMPDIR only)
self_test() {
  local P=0 F=0; ok(){ echo "  PASS $1"; P=$((P+1)); }; no(){ echo "  FAIL $1"; F=$((F+1)); }
  local TT; TT="$(mktemp -d)"; trap 'rm -rf "$TT"' RETURN

  # real-repo AC1 pre-snapshot
  local RH RB RC RP
  RH="$(git -C "$ROOTDIR" rev-parse HEAD 2>/dev/null)"; RB="$(git -C "$ROOTDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  RC="$(git -C "$ROOTDIR" config --list 2>/dev/null | md5)"; RP="$(git -C "$ROOTDIR" status --porcelain 2>/dev/null | md5)"

  mk(){ git -C "$1" init -q; git -C "$1" config user.email t@t.t; git -C "$1" config user.name t; }
  cm(){ GIT_AUTHOR_DATE='2020-01-01T00:00:00 +0000' GIT_COMMITTER_DATE='2020-01-01T00:00:00 +0000' git -C "$1" commit -q -m "$2"; }
  # R_def: 2 commits, origin/main=commit1 => HEAD(commit2) DEFERRED
  local Rd="$TT/def"; mkdir -p "$Rd"; mk "$Rd"; echo a>"$Rd/f"; git -C "$Rd" add -A; cm "$Rd" c1; local C1; C1="$(git -C "$Rd" rev-parse HEAD)"
  echo b>"$Rd/f"; git -C "$Rd" add -A; cm "$Rd" c2; local C2; C2="$(git -C "$Rd" rev-parse HEAD)"
  git -C "$Rd" update-ref refs/remotes/origin/main "$C1"
  # R_push: 1 commit, origin/main=HEAD => PUSHED
  local Rp="$TT/push"; mkdir -p "$Rp"; mk "$Rp"; echo a>"$Rp/f"; git -C "$Rp" add -A; cm "$Rp" c; local CP; CP="$(git -C "$Rp" rev-parse HEAD)"; git -C "$Rp" update-ref refs/remotes/origin/main "$CP"
  # R_noorigin: 1 commit, no origin/main => UNKNOWN
  local Rn="$TT/noorigin"; mkdir -p "$Rn"; mk "$Rn"; echo a>"$Rn/f"; git -C "$Rn" add -A; cm "$Rn" c; local CN; CN="$(git -C "$Rn" rev-parse HEAD)"

  local TdH TdC TdP; TdH="$(git -C "$Rd" rev-parse HEAD)"; TdC="$(git -C "$Rd" config --list | md5)"; TdP="$(git -C "$Rd" status --porcelain | md5)"

  # fixtures
  printf '%s\n' 'Status: APPROVED' 'Approval Status: APPROVED' > "$TT/plan_ok.md"
  printf '%s\n' 'Status: DRAFT' 'Approval Status: DRAFT' > "$TT/plan_draft.md"
  printf '%s\n' '# Verification Report' 'Review-Verdict: critic=PASS codex=ACCEPT' '| x | 16 PASS / 0 FAIL |' '## Final Status' '**PASS**' > "$TT/rep_ok.md"
  printf '%s\n' '# Verification Report' 'Review-Verdict: critic=REVISE codex=PENDING' '| x | 2 PASS / 1 FAIL |' '## Final Status' '**FAIL**' > "$TT/rep_revise.md"
  printf '%s\n' '# Verification Report' 'Review-Verdict: critic=PASS codex=PENDING' '| x | 9 PASS / 0 FAIL |' '## Final Status' '**PASS**' > "$TT/rep_pending.md"
  printf '%s\n' '# Verification Report' 'Review-Verdict: critic=PASS codex=ACCEPTED' '| x | 9 PASS / 0 FAIL |' '## Final Status' '**PASS**' > "$TT/rep_accepted.md"
  printf '%s\n' '# Verification Report' 'Review-Verdict: critic=PASS codex=ACCEPT' '| x | 1 PASS / 0 FAIL |' '## Final Status' '**FAIL**' > "$TT/rep_finalfail.md"

  # AC2 — both polarities
  local a; a=1
  [ "$(chk_plan_approved "$TT/plan_ok.md")" = PASS ] || a=0
  [ "$(chk_plan_approved "$TT/plan_draft.md")" = FAIL ] || a=0
  [ "$(chk_critic_pass "$TT/rep_ok.md")" = PASS ] || a=0
  [ "$(chk_critic_pass "$TT/rep_revise.md")" = FAIL ] || a=0
  [ "$(chk_codex_accept "$TT/rep_ok.md")" = PASS ] || a=0
  [ "$(chk_codex_accept "$TT/rep_pending.md")" = FAIL ] || a=0
  [ "$(chk_codex_accept "$TT/rep_accepted.md")" = FAIL ] || a=0
  [ "$(chk_verification "$TT/rep_ok.md")" = PASS ] || a=0
  [ "$(chk_verification "$TT/rep_finalfail.md")" = FAIL ] || a=0
  [ "$a" = 1 ] && ok "AC2 preconditions: plan APPROVED/DRAFT, critic PASS/REVISE, codex exact-ACCEPT/PENDING/ACCEPTED, verification PASS/FAIL" || no "AC2 preconditions"

  # AC2 push states
  a=1
  [ "$(judge_push "$Rd" "$C2")" = DEFERRED ] || a=0
  [ "$(judge_push "$Rp" "$CP")" = PUSHED ] || a=0
  [ "$(judge_push "$Rn" "$CN")" = UNKNOWN ] || a=0            # no local origin/main
  [ "$(judge_push "$Rd" deadbeefdeadbeef)" = UNKNOWN ] || a=0 # bogus ref
  [ "$a" = 1 ] && ok "AC2 push-boundary: DEFERRED / PUSHED / UNKNOWN(no-origin) / UNKNOWN(bogus-ref)" || no "AC2 push-boundary"

  # AC3 — COMPLIANT iff preconditions + bounded push
  local PKc="$TT/c.md"; run_harness "$PKc" "$Rd" "v0.3.x" "$TT/plan_ok.md" "$TT/rep_ok.md" "$C2" 0; local rcc=$?
  local PKd="$TT/d.md"; run_harness "$PKd" "$Rd" "v0.3.x" "$TT/plan_draft.md" "$TT/rep_ok.md" "$C2" 0; local rcd=$?
  local PKp="$TT/p.md"; run_harness "$PKp" "$Rp" "v0.3.x" "$TT/plan_ok.md" "$TT/rep_ok.md" "$CP" 0; local rcp=$?
  local PKpa="$TT/pa.md"; run_harness "$PKpa" "$Rp" "v0.3.x" "$TT/plan_ok.md" "$TT/rep_ok.md" "$CP" 1; local rcpa=$?
  if [ "$rcc" = 0 ] && grep -q 'AUTONOMY-COMPLIANT' "$PKc" \
     && [ "$rcd" = 1 ] && grep -q 'NON-COMPLIANT' "$PKd" && grep -q 'plan-approved' "$PKd" \
     && [ "$rcp" = 1 ] && grep -q 'NON-COMPLIANT' "$PKp" \
     && [ "$rcpa" = 0 ] && grep -q 'AUTONOMY-COMPLIANT' "$PKpa"; then
    ok "AC3 COMPLIANT iff preconditions+push: all-ok+DEFERRED=>COMPLIANT; DRAFT=>NON; PUSHED-no-approval=>NON; PUSHED+approved=>COMPLIANT"
  else no "AC3 judgment (rcc=$rcc rcd=$rcd rcp=$rcp rcpa=$rcpa)"; fi

  # AC4 — fail-closed: absent/secret plan|report; UNKNOWN push never COMPLIANT
  a=1
  [ "$(chk_plan_approved "")" = FAIL ] || a=0
  printf 'X=1\n' > "$TT/p.env"; [ "$(chk_plan_approved "$TT/p.env")" = FAIL ] || a=0
  [ "$(chk_codex_accept "")" = FAIL ] || a=0
  local PKu="$TT/u.md"; run_harness "$PKu" "$Rn" "v0.3.x" "$TT/plan_ok.md" "$TT/rep_ok.md" "$CN" 0; local rcu=$?
  [ "$rcu" = 1 ] && grep -q 'UNKNOWN' "$PKu" || a=0          # no-origin => UNKNOWN => NON-COMPLIANT
  local PKb="$TT/b.md"; run_harness "$PKb" "$Rd" "v0.3.x" "$TT/plan_ok.md" "$TT/rep_ok.md" badref 0; local rcb=$?
  [ "$rcb" = 1 ] || a=0                                       # bogus ref => UNKNOWN => NON-COMPLIANT
  [ "$a" = 1 ] && ok "AC4 fail-closed: absent/secret plan|report=>FAIL; UNKNOWN push (no-origin / bogus-ref)=>NON-COMPLIANT" || no "AC4 fail-closed (rcu=$rcu rcb=$rcb)"

  # AC6 — structural audit (operative source ONLY; own block + comments excluded)
  local OP="$TT/op.src"; sed '/AUDIT_BLOCK_START/,/AUDIT_BLOCK_END/d' "$SELFPATH" | grep -vE '^[[:space:]]*#' > "$OP"
  # >>>AUDIT_BLOCK_START
  local sa=1
  grep -nE 'format-patch|cat-file|diff-tree' "$OP" >/dev/null && sa=0
  grep -nE '(show|log|diff)[^|]* (-p|--patch)( |$)' "$OP" >/dev/null && sa=0
  grep -n '%b' "$OP" >/dev/null && sa=0
  grep -nE 'git( -C [^ ]+| -C "[^"]+")? +show' "$OP" | grep -vE -- '-s|--name-status|--numstat|--stat|--name-only' >/dev/null && sa=0
  grep -nE 'git( -C [^ ]+| -C "[^"]+")? +diff ' "$OP" | grep -vE -- '--name-status|--numstat|--stat|--name-only' >/dev/null && sa=0
  grep -nE 'os\.environ|os\.getenv|getenv\(' "$OP" >/dev/null && sa=0
  grep -nE '\$\{?(GLM_API_KEY|DMC_OAUTHCLI_BIN|ANTHROPIC_API_KEY|OPENAI_API_KEY|ZHIPUAI_API_KEY)' "$OP" >/dev/null && sa=0
  [ "$sa" = 1 ] && ok "AC6 STRUCTURAL: no content-dumping git primitive; no commit-body read; no env/cred read" || no "AC6 STRUCTURAL: a forbidden primitive is present"
  # >>>AUDIT_BLOCK_END

  # AC5 — --out guard
  mkdir -p "$TT/sub"
  out_refused "$TT/sub/../benign.json" && out_refused ".env" && out_refused ".claude/hooks/x" && out_refused "provider-router.py" \
    && { ln -sf "$ROOTDIR/.claude/hooks" "$TT/sub/hooks" 2>/dev/null; out_refused "$TT/sub/hooks/x"; } \
    && ! out_refused "$TT/benign.json" && ok "AC5 --out guard: benign-.. + protected/secret/symlink refused, benign allowed" || no "AC5 --out guard"

  # AC7 — doc completeness
  local DOC="$ROOTDIR/docs/DMC_DELEGATION_HARNESS.md"
  if [ -f "$DOC" ] && grep -q 'Role-assignment\|Roles' "$DOC" && grep -q 'Critic handoff' "$DOC" \
     && grep -q 'allowed-autonomy' "$DOC" && grep -qi 'run-transcript checklist' "$DOC" \
     && grep -qE '\*\*STAGE\*\*.*human|STAGE.*\| human' "$DOC" && grep -q 'advisory INPUT' "$DOC"; then
    ok "AC7 doc completeness: 4 sections; STAGE/COMMIT/PUSH/CLOSURE GATED; Codex ACCEPT advisory input"
  else no "AC7 doc completeness"; fi

  # AC1 FINAL — real + temp repo unchanged
  local rh rb rc2 rp tdh tdc tdp
  rh="$(git -C "$ROOTDIR" rev-parse HEAD)"; rb="$(git -C "$ROOTDIR" rev-parse --abbrev-ref HEAD)"; rc2="$(git -C "$ROOTDIR" config --list | md5)"; rp="$(git -C "$ROOTDIR" status --porcelain | md5)"
  tdh="$(git -C "$Rd" rev-parse HEAD)"; tdc="$(git -C "$Rd" config --list | md5)"; tdp="$(git -C "$Rd" status --porcelain | md5)"
  if [ "$RH" = "$rh" ] && [ "$RB" = "$rb" ] && [ "$RC" = "$rc2" ] && [ "$RP" = "$rp" ] \
     && [ "$TdH" = "$tdh" ] && [ "$TdC" = "$tdc" ] && [ "$TdP" = "$tdp" ]; then
    ok "AC1 read-only: real+temp repo HEAD/branch/config/porcelain pre==post (no mutation)"
  else no "AC1 read-only: a repo changed"; fi

  echo "  ---- self-test: PASS=$P FAIL=$F ----"; [ "$F" = 0 ]
}

# --- args ---
MILESTONE=""; PLAN=""; VERIFY=""; COMMIT=""; REPO=""; PUSHOK=0; OUT=""; MODE=run
while [ $# -gt 0 ]; do case "$1" in
  --milestone) MILESTONE="$2"; shift 2;; --plan) PLAN="$2"; shift 2;; --verify-report) VERIFY="$2"; shift 2;;
  --commit) COMMIT="$2"; shift 2;; --repo) REPO="$2"; shift 2;; --push-approved) PUSHOK=1; shift;;
  --out) OUT="$2"; shift 2;; --self-test) MODE=selftest; shift;; -h|--help) sed -n '2,22p' "$0"; exit 0;;
  *) echo "delegation-harness: unknown arg $1" >&2; exit 2;;
esac; done

if [ "$MODE" = selftest ]; then
  echo "==== DMC DELEGATION HARNESS — SELF-TEST (no in-repo writes; \$TMPDIR only) ===="
  self_test; exit $?
fi

[ -n "$MILESTONE" ] || { echo "delegation-harness: --milestone required" >&2; exit 2; }
[ -n "$COMMIT" ] || { echo "delegation-harness: --commit required" >&2; exit 2; }
REPO="${REPO:-$ROOTDIR}"
if [ -n "$OUT" ]; then
  if out_refused "$OUT"; then echo "delegation-harness: --out target is a protected/secret path — REFUSED" >&2; exit 2; fi
fi
PACK="$(mktemp)"; run_harness "$PACK" "$REPO" "$MILESTONE" "$PLAN" "$VERIFY" "$COMMIT" "$PUSHOK"; RC=$?
if [ -n "$OUT" ]; then cp "$PACK" "$OUT"; echo "delegation-harness: wrote $OUT" >&2; else cat "$PACK"; fi
rm -f "$PACK"
exit $RC
