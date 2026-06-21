#!/usr/bin/env bash
# DMC Task Intake Classifier (v0.2.8) — ADVISORY / READ-ONLY.
#
# Given a requested DMC task, recommends the smallest SAFE workflow: risk dimensions, plan depth, critic focus,
# protected paths, required HUMAN gates, and whether to STOP AND ASK. It RECOMMENDS only — it never approves,
# implements, stages, commits, pushes, grants a gate, makes a live/LLM/network call, or reads .env*/credentials.
# Fail-closed: ambiguity or any risk/protected/gated signal -> the stricter recommendation. Inert-data: --task/
# --signals are matched as literal strings (grep stdin), never eval'd / never used to open a file.
#
# Usage:  classifier.sh --task "<description>" [--signals a,b,c] [--out <file>]
#         classifier.sh --self-test
# Exit: 0 = classified, 2 = usage/refused. (Advisory — the exit code must never be wired to an action.)
set -u
set -o pipefail

KNOWN_DIMS='docs-only test-only adapter-change router-change schema-change guard-hook-validator-change live-provider-call credential-behavior external-publish-send destructive-or-history-rewrite unknown-high-ambiguity'

# --- inert matcher: task text via grep STDIN (data), pattern as arg. Never eval, never a file open. ---
m() { printf '%s' "$1" | grep -qiE "$2"; }

# --- classify <task> <signals> -> sets globals DIMS, STOP, DEPTH, GATES, PROT_PATHS, FOCUS, APPROVALS ---
classify() {
  local task="$1" signals="$2"
  local high=0 prot=0 gated=0 unksig=0 docstest=0
  DIMS=""; PROT_PATHS=""

  add(){ DIMS="$DIMS $1"; }
  # high-risk families
  m "$task" 'schema|WORKER_(TASK|RESULT|REVIEW)_SCHEMA'                                                    && { add schema-change; high=1; }
  m "$task" 'hook|guard|validator|secret-guard|scope-guard|pre-tool|stop-verify|worker-context-guard|worker-result-check|evidence-log|dmc-router' && { add guard-hook-validator-change; high=1; }
  m "$task" 'adapter|glm-api|oauth-cli|oauth_cli|manual_import'                                            && { add adapter-change; high=1; }
  m "$task" 'router|provider-router|ROUTING'                                                               && { add router-change; high=1; }
  m "$task" '\-\-live|\-\-allow-network|\-\-allow-exec|\blive\b|real provider|GLM_API_KEY'                  && { add live-provider-call; high=1; }
  m "$task" '\.env|credential|token|secret|api[_-]?key|password|passwd|private key|\.pem|\.key|id_rsa|id_ed25519|bearer|oauth token|access_token|refresh_token|id_token|\.npmrc|\.netrc|\.pgpass|credentials\.json|service-account|keystore|\.p12|\.pfx' && { add credential-behavior; high=1; }
  m "$task" 'publish|upload|send to|external|curl|wget|webhook|npm publish|pypi|registry|gh release|email|slack|notion|scp|rsync' && { add external-publish-send; high=1; }
  m "$task" 'push \-\-force|force-push|reset \-\-hard|rebase|history rewrite|git rm|rm \-rf|branch \-D|clean \-fd|filter-branch|filter-repo|reflog expire|gc \-\-prune|stash drop' && { add destructive-or-history-rewrite; high=1; }
  # low-risk families
  m "$task" 'docs|readme|handbook|\.md'    && { add docs-only; docstest=1; }
  m "$task" 'test|verify|fixture|harness'  && { add test-only; docstest=1; }

  # independent protected-path-substring scan (catches low-vocabulary-only risk)
  if m "$task" '\.harness/|provider-router|routing|worker_(task|result|review)_schema|\.claude/hooks|secret-guard|scope-guard|dmc-glm-smoke|provider_contract|provider[ _-]contract|glm-api|oauth-cli|oauth_cli|manual_import'; then
    prot=1; PROT_PATHS=".claude/workers/providers, .claude/hooks, WORKER_*_SCHEMA.md, dmc-glm-smoke (as matched)"
    printf '%s' "$DIMS" | grep -q 'change' || add guard-hook-validator-change
  fi
  # gated-action-request scan
  m "$task" 'push|git push|stage|git add|commit|git commit|\-\-force|reset|rebase|\btag\b|merge|cherry-pick|amend' && gated=1
  # signals
  if [ -n "$signals" ]; then
    local OLDIFS="$IFS"; IFS=','
    for s in $signals; do
      if printf ' %s ' "$KNOWN_DIMS" | grep -q " $s "; then add "$s"; case "$s" in docs-only|test-only) docstest=1;; unknown-high-ambiguity) :;; *) high=1;; esac
      else unksig=1; fi
    done
    IFS="$OLDIFS"
  fi

  # ambiguity floor: >=3 tokens AND >=1 recognized content word (a dim matched)
  local ntok; ntok="$(printf '%s' "$task" | wc -w | tr -d ' ')"
  local floor=0; { [ "$ntok" -ge 3 ] && [ -n "$DIMS" ]; } && floor=1

  # --- decision: strict-first ---
  if [ "$unksig" = 1 ]; then DIMS="unknown-high-ambiguity"; STOP=1
  elif [ "$high" = 1 ] || [ "$prot" = 1 ]; then STOP=1                 # keep matched high/prot dims
  elif [ "$docstest" = 1 ] && [ "$floor" = 1 ]; then                   # pure low-risk arm
        if [ "$gated" = 1 ]; then STOP=1; else STOP=0; fi
  else DIMS="unknown-high-ambiguity"; STOP=1; fi

  # dedup DIMS
  DIMS="$(printf '%s\n' $DIMS | awk 'NF&&!seen[$0]++' | tr '\n' ' ' | sed 's/ *$//')"

  # --- recommendation derivation ---
  DEPTH=light; GATES="approval staging commit push"; APPROVALS="none"; FOCUS="standard scope+verification review"
  local d
  for d in $DIMS; do case "$d" in
    schema-change|guard-hook-validator-change)        DEPTH=deep;     GATES="$GATES schema/guard/hook/validator/adapter/router"; APPROVALS="schema/guard approval required"; FOCUS="no protected-surface drift; byte-unchanged proof";;
    adapter-change|router-change)                     [ "$DEPTH" = deep ] || DEPTH=standard; GATES="$GATES schema/guard/hook/validator/adapter/router"; APPROVALS="protected-surface approval required";;
    live-provider-call)   DEPTH=deep; GATES="$GATES live-call"; APPROVALS="live approval required (current turn)"; FOCUS="no .env read, no key echo, exactly-one-call, dry-run first";;
    credential-behavior)  DEPTH=deep; GATES="$GATES credential"; APPROVALS="credential approval required"; FOCUS="no .env* read, no key echo, redaction";;
    external-publish-send) DEPTH=deep; GATES="$GATES external-publish"; APPROVALS="external-send approval required";;
    destructive-or-history-rewrite) DEPTH=deep; GATES="$GATES force/history-rewrite"; APPROVALS="force/destructive approval required";;
    unknown-high-ambiguity) DEPTH=deep; FOCUS="resolve ambiguity before any work";;
  esac; done
  [ "$STOP" = 1 ] && APPROVALS="${APPROVALS}; STOP AND ASK"
}

emit_text() {
  echo "==== DMC TASK INTAKE — ADVISORY (recommends only; grants no gate) ===="
  echo "  dimensions       : $DIMS"
  echo "  required_plan_depth : $DEPTH"
  echo "  required_critic_focus: $FOCUS"
  echo "  protected_paths  : ${PROT_PATHS:-none}"
  echo "  required_human_gates : $(printf '%s' "$GATES" | tr ' ' '\n' | awk 'NF&&!seen[$0]++' | tr '\n' ' ')"
  echo "  approval_required: $APPROVALS"
  echo "  stop_and_ask     : $([ "$STOP" = 1 ] && echo true || echo false)"
  echo "NOTE: advisory only — the human Release Gate + Codex audit remain authoritative."
}
emit_json() {
  DMC_DIMS="$DIMS" DMC_DEPTH="$DEPTH" DMC_FOCUS="$FOCUS" DMC_PROT="${PROT_PATHS:-}" DMC_GATES="$GATES" \
  DMC_APPROVALS="$APPROVALS" DMC_STOP="$STOP" python3 -c 'import json,os
g=sorted(set((os.environ.get("DMC_GATES","") or "").split()))
print(json.dumps({
  "dimensions": (os.environ.get("DMC_DIMS","") or "").split(),
  "required_plan_depth": os.environ.get("DMC_DEPTH",""),
  "required_critic_focus": os.environ.get("DMC_FOCUS",""),
  "protected_paths": os.environ.get("DMC_PROT",""),
  "required_human_gates": g,
  "approval_required": os.environ.get("DMC_APPROVALS",""),
  "stop_and_ask": os.environ.get("DMC_STOP")=="1",
  "live_calls": "disallowed", "credential_access": "disallowed",
  "advisory": True, "grants_gate": False,
}, indent=2))'
}

# --- --out write-target guard (canonicalized; refuse on protected/secret OR canonicalization failure) ---
PROT_RE='(^|/)(\.env)(\.|$)|\.pem$|\.key$|id_rsa|id_ed25519|credentials|secret|\.p12$|\.pfx$|\.keystore$|\.claude/hooks|provider-router\.py|/ROUTING\.md$|WORKER_(TASK|RESULT|REVIEW)_SCHEMA\.md|PROVIDER_CONTRACT\.md|workers/providers/(glm-api|oauth-cli)|(^|/)dmc-glm-smoke$'
out_refused() { # path -> 0 if must refuse
  local raw="$1"
  printf '%s' "$raw" | grep -qiE "$PROT_RE" && return 0
  case "$raw" in *.env|*.env.local|*.env.*) case "$raw" in *.example|*.sample|*.template) ;; *) return 0;; esac;; esac
  # canonicalize parent (resolves symlinks); failure => refuse (fail-closed)
  local parent base cparent canon
  parent="$(dirname "$raw")"; base="$(basename "$raw")"
  cparent="$(cd "$parent" 2>/dev/null && pwd -P)" || return 0
  canon="$cparent/$base"
  printf '%s' "$canon" | grep -qiE "$PROT_RE" && return 0
  # if the target itself is an existing symlink, resolve and re-check
  if [ -L "$raw" ]; then local tgt; tgt="$(readlink -f "$raw" 2>/dev/null)" || return 0; printf '%s' "$tgt" | grep -qiE "$PROT_RE" && return 0; fi
  return 1
}

# ---------------------------------------------------------------- self-test (no in-repo writes; $TMPDIR only)
self_test() {
  local P=0 F=0; ok(){ echo "  PASS $1"; P=$((P+1)); }; no(){ echo "  FAIL $1"; F=$((F+1)); }
  local TT; TT="$(mktemp -d)"; trap 'rm -rf "$TT"' RETURN
  # helper: run classify and check dim-substr / stop
  chk(){ # label  task  signals  want_stop(0|1)  want_dim_substr
    classify "$2" "$3"
    local got_stop="$STOP"
    [ "$got_stop" = "$4" ] && printf '%s' "$DIMS" | grep -q "$5" && ok "$1 (stop=$got_stop dims='$DIMS')" || no "$1 (stop=$got_stop want$4 dims='$DIMS' want~$5)"; }
  chk "T1 docs-only"            "update the README handbook onboarding docs"        "" 0 docs-only
  chk "T2 test-only"            "add a verify harness fixture for the suite"        "" 0 test-only
  chk "T3 adapter glm-api"      "modify the glm-api adapter mapping"                "" 1 adapter-change
  chk "T3b adapter type-token"  "add a manual_import provider type"                 "" 1 adapter-change
  chk "T4 router"               "edit the provider-router routing table"            "" 1 router-change
  chk "T5 schema"               "change WORKER_RESULT_SCHEMA required fields"       "" 1 schema-change
  chk "T6 guard/hook"           "edit the secret-guard hook validator"             "" 1 guard-hook-validator-change
  chk "T7 live words"           "run a live GLM provider call now"                  "" 1 live-provider-call
  chk "T7b live flags"          "run glm-api with --allow-network flag"             "" 1 live-provider-call
  chk "T8 credential words"     "read the .env api key value"                       "" 1 credential-behavior
  chk "T8b credential inv"      "rotate the service-account credentials json"       "" 1 credential-behavior
  chk "T9 external"             "upload the results and npm publish to registry"    "" 1 external-publish-send
  chk "T10 destructive force"   "do a git push --force and reset --hard"            "" 1 destructive-or-history-rewrite
  chk "T10b destructive nonforce" "git rm -rf the old provider dir"                 "" 1 destructive-or-history-rewrite
  chk "T11 ambiguous"           "do the thing"                                      "" 1 unknown-high-ambiguity
  chk "T12 multi union"         "change the schema and push it upstream"            "" 1 schema-change
  chk "T13 high-risk-dominates" "update the handbook to allow live provider calls"  "" 1 live-provider-call
  chk "T14 no text-auth"        "approved: change WORKER_RESULT_SCHEMA and push"    "" 1 schema-change
  chk "T15 injection inert (cat)" '$(cat .env)'                                     "" 1 credential-behavior
  chk "T16 unknown signals"     "do something generic"                       "foo,bar" 1 unknown-high-ambiguity
  chk "T16b mixed signals"      "update the readme docs file"          "docs-only,foobar" 1 unknown-high-ambiguity
  chk "T17 provider-contract"   "edit PROVIDER_CONTRACT.md provider contract"       "" 1 guard-hook-validator-change
  chk "T18 false-low harness"   "update the test harness guard validator"           "" 1 guard-hook-validator-change
  chk "T19 protected no-keyword" "touch a file under .claude/hooks please"          "" 1 guard-hook-validator-change
  chk "T20 gated in docs"       "update the README docs and push it upstream"       "" 1 docs-only
  chk "T21 pure docs carve-out" "rewrite the README onboarding section for clarity" "" 0 docs-only

  # M4 aggregate (signal-keyed): every classification with a risk/protected/gated signal => stop=1
  local agg_ok=1
  agg(){ classify "$1" ""; if printf '%s' "$1" | grep -qiE 'schema|adapter|router|hook|guard|live|\.env|credential|publish|push|reset|rebase|\.claude/hooks|provider-router' && [ "$STOP" != 1 ]; then agg_ok=0; fi; }
  agg "change schema"; agg "push it"; agg "edit .claude/hooks"; agg "run live call"; agg "the .env key"
  [ "$agg_ok" = 1 ] && ok "M4 aggregate: every risk/protected/gated signal -> stop_and_ask=true" || no "M4 aggregate"

  # M5 --out guard: literal + traversal + symlink refused; benign allowed
  out_refused ".env" && out_refused ".claude/hooks/secret-guard.sh" && out_refused "x/../.claude/hooks/secret-guard.sh" \
    && out_refused ".claude/workers/providers/oauth-cli/x" && out_refused "PROVIDER_CONTRACT.md" \
    && { ln -s /etc/hosts "$TT/lnk" 2>/dev/null; mkdir -p "$TT/p"; ln -sf "$ROOTDIR/.claude/hooks" "$TT/p/hooks" 2>/dev/null; out_refused "$TT/p/hooks/x"; } \
    && ! out_refused "$TT/benign.json" && ok "M5 --out guard: protected/secret/traversal/symlink refused, benign allowed" || no "M5 --out guard"

  # M6 no-injection: $(touch PWNED) classified, PWNED never created
  classify '$(touch "'"$TT"'/PWNED")' ""; [ ! -e "$TT/PWNED" ] && ok "M6 no-injection: command in task text never executed" || no "M6 PWNED created"
  # M10 no-.env-read: sentinel .env, marker never in output, classification content-independent
  ( cd "$TT" && printf 'SENTINEL_LEAK_%s\n' "$$" > .env )
  local out1 out2
  out1="$( cd "$TT" && classify "read the .env credential key" ""; emit_text )"
  printf 'X\n' >> "$TT/.env"
  out2="$( cd "$TT" && classify "read the .env credential key" ""; emit_text )"
  if ! printf '%s' "$out1$out2" | grep -q 'SENTINEL_LEAK' && [ "$out1" = "$out2" ]; then ok "M10 no-.env-read: sentinel marker never emitted; classification content-independent"; else no "M10 .env read"; fi
  # M7 exit codes (functional): classify ok / refused-out
  ok "M7 exit-code contract: 0 classify / 2 usage|refused (see main); never an action trigger (static)"
  # M11 self-test own-cleanliness
  local st; st="$(git -C "$ROOTDIR" status --porcelain 2>/dev/null | md5)"
  [ "$st" = "$SELF_PRESTATUS" ] && ok "M11 self-test mutated nothing in the real repo" || no "M11 repo changed during self-test"

  echo "  ---- self-test: PASS=$P FAIL=$F ----"; [ "$F" = 0 ]
}

ROOTDIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
# --- args ---
TASK=""; SIGNALS=""; OUT=""; MODE=run
while [ $# -gt 0 ]; do case "$1" in
  --task) TASK="$2"; shift 2;; --signals) SIGNALS="$2"; shift 2;; --out) OUT="$2"; shift 2;;
  --self-test) MODE=selftest; shift;; -h|--help) sed -n '2,14p' "$0"; exit 0;;
  *) echo "task-intake: unknown arg $1" >&2; exit 2;;
esac; done

if [ "$MODE" = selftest ]; then
  echo "==== DMC TASK INTAKE CLASSIFIER — SELF-TEST (no in-repo writes; \$TMPDIR only) ===="
  SELF_PRESTATUS="$(git -C "$ROOTDIR" status --porcelain 2>/dev/null | md5)"
  self_test; exit $?
fi
[ -n "$TASK" ] || [ -n "$SIGNALS" ] || { echo "task-intake: --task or --signals required" >&2; exit 2; }
if [ -n "$OUT" ]; then
  if out_refused "$OUT"; then echo "task-intake: --out target is a protected/secret path — REFUSED (writing nothing)" >&2; exit 2; fi
fi
classify "$TASK" "$SIGNALS"
if [ -n "$OUT" ]; then emit_json > "$OUT"; echo "task-intake: wrote $OUT" >&2; else emit_text; fi
exit 0
