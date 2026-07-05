#!/usr/bin/env bash
# v0.3.3 Three-Provider Contract Expansion — unified PROVIDER_CONTRACT C1-C11 over glm-api + oauth-cli + manual-import (+ router).
# MOCK / OFFLINE ONLY. No external provider, no network, no real credential, no .env*. Rejection stages made EXPLICIT + PINNED.
set -u
export PYTHONDONTWRITEBYTECODE=1
ROOT="$(pwd)"; PASS=0; FAIL=0; NAC=0
ok(){ echo "    PASS $1"; PASS=$((PASS+1)); }
no(){ echo "    FAIL $1"; FAIL=$((FAIL+1)); }
na(){ echo "    N/A  $1"; NAC=$((NAC+1)); }
PROV="$ROOT/.claude/workers/providers"
VAL="$ROOT/.claude/hooks/worker-result-check.py"
ROUTER="$PROV/provider-router.py"
STUB="$PROV/oauth-cli/fixtures/fake-cli/fake-cli.py"
SELF="$ROOT/.harness/evidence/dmc-v0.3.3-verify.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
NOCI="env -u CI -u GITHUB_ACTIONS -u GITLAB_CI -u BUILDKITE -u JENKINS_URL"

descriptor(){ case "$1" in
  glm-api)   ADAPTER="$PROV/glm-api/glm-api-adapter.py"; FXDIR="$PROV/glm-api/fixtures"; INPUT_FLAG="--mock"
    SUCCESS=glm-response-success-choices.json; OVERRIDE=glm-response-override-attempt.json; SECRET_FX=glm-response-bad-secret.json
    ADV="glm-response-bad-scope-choices.json glm-response-bad-secret.json"; STAGES="validator validator"
    PTYPE=api_key; PROVIDER=glm-api; EXEC_TIMEOUT=no; ALLOWED=src/setNames.ts ;;
  oauth-cli) ADAPTER="$PROV/oauth-cli/oauth-cli-adapter.py"; FXDIR="$PROV/oauth-cli/fixtures"; INPUT_FLAG="--mock"
    SUCCESS=cli-response-success.json; OVERRIDE=cli-response-override-attempt.json; SECRET_FX=cli-response-token-leak.json
    ADV="cli-response-bad-scope.json cli-response-token-leak.json"; STAGES="validator adapter"
    PTYPE=oauth_cli; PROVIDER=oauth-cli; EXEC_TIMEOUT=yes; ALLOWED=src/setNames.ts ;;
  manual-import) ADAPTER="$PROV/manual-import/manual-import-adapter.py"; FXDIR="$PROV/manual-import/fixtures"; INPUT_FLAG="--import"
    SUCCESS=import-success.json; OVERRIDE=""; SECRET_FX=import-secret.json
    ADV="import-bad-scope.json import-secret.json import-mutation-attempt.json import-extra-fields.json import-empty.json"
    STAGES="adapter adapter adapter adapter adapter"
    PTYPE=manual_import; PROVIDER=manual-import; EXEC_TIMEOUT=no; ALLOWED=src/app.ts ;;
esac; }

mktask(){ # outfile type provider allowed
  python3 -c 'import json,sys
json.dump({"task_id":"c-"+sys.argv[2],"objective":"x","allowed_files":[sys.argv[4]],"forbidden_files":["src/secrets.ts"],"context_summary":"x","relevant_snippets":[],"expected_output_type":"unified_diff","provider_target":{"type":sys.argv[2],"provider":sys.argv[3],"model":"m","execution_mode":"proposal_only","credential_policy":"no_credentials_in_repo","secret_policy":"no_secret_context"}}, open(sys.argv[1],"w"))' "$@"; }
field(){ DMC_F="$2" python3 -c 'import json,os,sys
v=json.load(open(sys.argv[1]))
for k in os.environ["DMC_F"].split("."):
    v=v.get(k) if isinstance(v,dict) else None
print(v)' "$1"; }
validate(){ python3 "$VAL" "$1" "$2" >/dev/null 2>&1; }   # rc 0 = ACCEPT
has_secret(){ python3 -c 'import re,sys
s=open(sys.argv[1]).read()
pats=[r"sk-[A-Za-z0-9_-]{8,}",r"AKIA[0-9A-Z]{16}",r"ghp_[A-Za-z0-9]{20,}",r"eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+",r"(?i)bearer\s+[A-Za-z0-9._~+/-]{12,}",r"ya29\.[A-Za-z0-9._-]+",r"gh[opsu]_[A-Za-z0-9]{20,}"]
sys.exit(0 if any(re.search(p,s) for p in pats) else 1)' "$1"; }   # rc 0 = secret found
# C5a helper: returns 0 if rejected with NO unsafe ACCEPTED; sets REJ_STAGE=adapter|validator. Uses the provider INPUT_FLAG.
assert_rejected(){ # task fixture
  python3 "$ADAPTER" --task "$1" "$INPUT_FLAG" "$FXDIR/$2" --out "$T/adv.json" >"$T/ao" 2>"$T/ae"; local arc=$?
  if [ "$arc" != 0 ]; then [ -s "$T/ae" ] && { REJ_STAGE=adapter; return 0; } || return 1; fi
  validate "$1" "$T/adv.json" && return 1 || { REJ_STAGE=validator; return 0; }
}

echo "== rejection-stage table (explicit; pinned per fixture) =="
for P in glm-api oauth-cli manual-import; do
  echo "== provider: $P =="
  descriptor "$P"
  TASK="$T/task-$P.json"; mktask "$TASK" "$PTYPE" "$PROVIDER" "$ALLOWED"
  python3 "$ADAPTER" --task "$TASK" "$INPUT_FLAG" "$FXDIR/$SUCCESS" --out "$T/r.json" >"$T/out" 2>"$T/err"; rc=$?
  univ=0   # per-provider universal PASS count (expect 9: C1,C2,C3,C4,C5a,C6,C7,C8,C11)

  # C1 schema conformance + provider_type match + validator ACCEPT (content-sensitivity: success ACCEPTED via INPUT_FLAG)
  miss="$(DMC_R="$T/r.json" python3 -c 'import json,os
try: r=json.load(open(os.environ["DMC_R"]))
except Exception: print("NO_RESULT"); raise SystemExit
req=["task_id","summary","files_considered","files_changed","proposed_patch","instructions","confidence","no_direct_mutation","provider_metadata"]
pm=r.get("provider_metadata") or {}
print(",".join([k for k in req if k not in r]+["provider_metadata."+k for k in ("provider_type","provider","credential_exposure") if k not in pm]))' 2>/dev/null)"
  if [ "$rc" = 0 ] && validate "$TASK" "$T/r.json" && [ -z "$miss" ] \
     && [ "$(field "$T/r.json" provider_metadata.provider_type)" = "$PTYPE" ] \
     && [ "$(field "$T/r.json" provider_metadata.provider)" = "$PROVIDER" ]; then ok "C1 $P success ACCEPTED + schema + provider_type=$PTYPE"; univ=$((univ+1)); else no "C1 $P (rc=$rc miss=$miss)"; fi

  # C2 proposal-only
  [ "$(field "$T/r.json" no_direct_mutation)" = "True" ] && { ok "C2 $P no_direct_mutation=true"; univ=$((univ+1)); } || no "C2 $P"

  # C3 no auto-apply (CALL-SITE grep only — NOT the v0.2.4 'git apply|shell=True' which false-fails the manual-import docstring)
  grep -nE 'subprocess.*git.*apply|os\.system|shell=True' "$ADAPTER" >/dev/null 2>&1 && no "C3 $P git-apply/os.system/shell=True call site" || { ok "C3 $P no auto-apply call site"; univ=$((univ+1)); }

  # C4 no credential leakage — per-provider variant
  if [ -n "$OVERRIDE" ]; then
    python3 "$ADAPTER" --task "$TASK" "$INPUT_FLAG" "$FXDIR/$OVERRIDE" --out "$T/ro.json" >/dev/null 2>&1
    if ! has_secret "$T/r.json" && [ "$(field "$T/r.json" provider_metadata.credential_exposure)" = none ] \
       && [ "$(field "$T/ro.json" provider_metadata.credential_exposure)" = none ] && assert_rejected "$TASK" "$SECRET_FX"; then
      ok "C4 $P success clean; override->credential_exposure=none; secret input rejected"; univ=$((univ+1)); else no "C4 $P"; fi
  else
    # manual_import variant: no override-result; success clean + raw-secret import rejected (no result written)
    if ! has_secret "$T/r.json" && [ "$(field "$T/r.json" provider_metadata.credential_exposure)" = none ] \
       && assert_rejected "$TASK" "$SECRET_FX" && [ "$REJ_STAGE" = adapter ]; then
      ok "C4 $P success clean; raw-secret import rejected at adapter (no override-result read)"; univ=$((univ+1)); else no "C4 $P"; fi
  fi

  # C5a every adversarial rejected (no unsafe ACCEPTED) at the PINNED stage
  set -- $ADV; advs=("$@"); set -- $STAGES; stgs=("$@"); c5a=1; tbl=""
  for i in "${!advs[@]}"; do
    if assert_rejected "$TASK" "${advs[$i]}"; then
      tbl="$tbl ${advs[$i]%%.json}=$REJ_STAGE"
      [ "$REJ_STAGE" = "${stgs[$i]}" ] || { c5a=0; tbl="$tbl(EXPECTED:${stgs[$i]})"; }
    else c5a=0; tbl="$tbl ${advs[$i]%%.json}=ACCEPTED!"; fi
  done
  echo "      stages:$tbl"
  [ "$c5a" = 1 ] && { ok "C5a $P all adversarial rejected at pinned stage (no unsafe ACCEPTED)"; univ=$((univ+1)); } || no "C5a $P ($tbl)"

  # C5b timeout (conditional — only exec_timeout providers)
  if [ "$EXEC_TIMEOUT" = yes ]; then
    $NOCI DMC_OAUTHCLI_BIN="$STUB" DMC_FAKECLI_MODE=timeout DMC_OAUTHCLI_TIMEOUT_SECONDS=2 python3 "$ADAPTER" --task "$TASK" --live --allow-exec >/dev/null 2>"$T/terr"; trc=$?
    [ "$trc" != 0 ] && grep -qi 'timeout' "$T/terr" && ok "C5b $P timeout -> killed + fail-closed" || no "C5b $P (trc=$trc)"
  else
    na "C5b $P N/A (no exec_timeout capability)"
  fi

  # C6 stdout/stderr handling (success): --out 'wrote result' line; bare JSON without --out; no secret on streams
  python3 "$ADAPTER" --task "$TASK" "$INPUT_FLAG" "$FXDIR/$SUCCESS" >"$T/so.json" 2>"$T/se"
  if grep -q 'wrote result ->' "$T/out" && python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$T/so.json" 2>/dev/null \
     && ! has_secret "$T/so.json" && ! has_secret "$T/se" && ! has_secret "$T/err"; then ok "C6 $P stdout/stderr clean; --out line; bare JSON"; univ=$((univ+1)); else no "C6 $P"; fi

  # C7 mock-mode determinism (byte-identical --out)
  python3 "$ADAPTER" --task "$TASK" "$INPUT_FLAG" "$FXDIR/$SUCCESS" --out "$T/d1.json" >/dev/null 2>&1
  python3 "$ADAPTER" --task "$TASK" "$INPUT_FLAG" "$FXDIR/$SUCCESS" --out "$T/d2.json" >/dev/null 2>&1
  cmp -s "$T/d1.json" "$T/d2.json" && { ok "C7 $P determinism (byte-identical --out)"; univ=$((univ+1)); } || no "C7 $P"

  # C8 routing compatibility: --print-dispatch selects this adapter; routed --out == direct --out
  sel="$(python3 "$ROUTER" --task "$TASK" "$INPUT_FLAG" "$FXDIR/$SUCCESS" --print-dispatch 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["adapter"])')"
  python3 "$ROUTER"  --task "$TASK" "$INPUT_FLAG" "$FXDIR/$SUCCESS" --out "$T/route.json" >/dev/null 2>&1
  python3 "$ADAPTER" --task "$TASK" "$INPUT_FLAG" "$FXDIR/$SUCCESS" --out "$T/direct.json" >/dev/null 2>&1
  if [ "${sel##*/}" = "${ADAPTER##*/}" ] && cmp -s "$T/route.json" "$T/direct.json"; then ok "C8 $P router selects + routed==direct"; univ=$((univ+1)); else no "C8 $P (sel=$sel)"; fi

  # C11 context-guard fail-closed on secret-bearing task
  STASK="$T/sectask-$P.json"; mktask "$STASK" "$PTYPE" "$PROVIDER" "/x/.env.local"
  python3 "$ADAPTER" --task "$STASK" "$INPUT_FLAG" "$FXDIR/$SUCCESS" >/dev/null 2>"$T/cerr"; crc=$?
  [ "$crc" != 0 ] && grep -qi 'context-guard' "$T/cerr" && { ok "C11 $P context-guard fail-closed"; univ=$((univ+1)); } || no "C11 $P (crc=$crc)"

  # no-pass-by-skip: every per-provider UNIVERSAL dim (9) must PASS; a universal dim downgraded to N/A => FAIL
  [ "$univ" = 9 ] && ok "$P universal-PASS-count = 9/9 (no pass-by-skip)" || no "$P universal-PASS-count = $univ/9 (a universal dim was skipped/failed)"
done

echo "== suite-wide =="
# C9 protected-file non-mutation
ch="$(git -C "$ROOT" diff --name-only -- .claude/hooks/ WORKER_TASK_SCHEMA.md WORKER_RESULT_SCHEMA.md WORKER_REVIEW_SCHEMA.md dmc-glm-smoke .claude/workers/providers/glm-api/ .claude/workers/providers/oauth-cli/ .claude/workers/providers/manual-import/ .claude/workers/providers/provider-router.py .claude/workers/providers/ROUTING.md)"
[ -z "$ch" ] && ok "C9 adapters/router/ROUTING/hooks/schemas/smoke byte-unchanged" || no "C9 changed: $ch"
# C10 no live provider calls (self-audit; needles concatenated so these audit lines never self-match)
LV="--""live"; KEY="GLM_API""_KEY"; BINEQ="DMC_OAUTHCLI""_BIN="
nonstub="$(grep -nE -- "$LV" "$SELF" | grep -v "${BINEQ}\"\$STUB\"" || true)"
[ -z "$nonstub" ] && ok "C10 only live-mode invocation targets the offline stub (no real provider)" || { printf '%s\n' "$nonstub"; no "C10 a non-stub live call exists"; }
grep -q "$KEY" "$SELF" && no "C10 harness references a real GLM key" || ok "C10 no real GLM key / glm never invoked live"

echo
echo "==== SUMMARY: PASS=$PASS FAIL=$FAIL N/A=$NAC ===="
[ "$FAIL" = 0 ] && echo "RESULT: ALL PASS" || echo "RESULT: FAILURES"
[ "$FAIL" = 0 ]; exit $?
