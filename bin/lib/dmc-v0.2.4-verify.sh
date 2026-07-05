#!/usr/bin/env bash
# v0.2.4 Provider Contract Tests (run: bash .harness/evidence/dmc-v0.2.4-verify.sh).
# Cross-provider contract C1–C11 over glm-api + oauth-cli (+ router slice). MOCK + OFFLINE-STUB ONLY.
# No external provider, no network, no real credential, no .env*. Reuses existing fixtures (no new ones).
set -u
ROOT="$(pwd)"; PASS=0; FAIL=0; NAC=0
ok(){ echo "    PASS $1"; PASS=$((PASS+1)); }
no(){ echo "    FAIL $1"; FAIL=$((FAIL+1)); }
na(){ echo "    N/A  $1"; NAC=$((NAC+1)); }
PROV="$ROOT/.claude/workers/providers"
VAL="$ROOT/.claude/hooks/worker-result-check.py"
ROUTER="$PROV/provider-router.py"
STUB="$PROV/oauth-cli/fixtures/fake-cli/fake-cli.py"
SELF="$ROOT/.harness/evidence/dmc-v0.2.4-verify.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
NOCI="env -u CI -u GITHUB_ACTIONS -u GITLAB_CI -u BUILDKITE -u JENKINS_URL"

descriptor(){ case "$1" in
  glm-api)   ADAPTER="$PROV/glm-api/glm-api-adapter.py"; FXDIR="$PROV/glm-api/fixtures"
    SUCCESS=glm-response-success-choices.json; BADSCOPE=glm-response-bad-scope-choices.json
    OVERRIDE=glm-response-override-attempt.json; SECRET=glm-response-bad-secret.json
    EMPTY=glm-response-empty-content.json; PTYPE=api_key; PROVIDER=glm-api; EXEC_TIMEOUT=no ;;
  oauth-cli) ADAPTER="$PROV/oauth-cli/oauth-cli-adapter.py"; FXDIR="$PROV/oauth-cli/fixtures"
    SUCCESS=cli-response-success.json; BADSCOPE=cli-response-bad-scope.json
    OVERRIDE=cli-response-override-attempt.json; SECRET=cli-response-token-leak.json
    EMPTY=cli-response-empty.json; PTYPE=oauth_cli; PROVIDER=oauth-cli; EXEC_TIMEOUT=yes ;;
esac; }

mktask(){ # outfile type provider [extra_allowed]
  python3 -c 'import json,sys
allowed=["src/setNames.ts"]+([sys.argv[4]] if len(sys.argv)>4 else [])
json.dump({"task_id":"contract-"+sys.argv[2],"objective":"Add Pikachu to src/setNames.ts.","allowed_files":allowed,"forbidden_files":["src/secrets.ts"],"context_summary":"x","relevant_snippets":[],"expected_output_type":"unified_diff","provider_target":{"type":sys.argv[2],"provider":sys.argv[3],"model":"m","execution_mode":"proposal_only","credential_policy":"no_credentials_in_repo","secret_policy":"no_secret_context"}}, open(sys.argv[1],"w"))' "$@"; }

field(){ DMC_F="$2" python3 -c 'import json,os,sys
r=json.load(open(sys.argv[1])); v=r
for k in os.environ["DMC_F"].split("."):
    v=v.get(k) if isinstance(v,dict) else None
print(v)' "$1"; }

has_secret(){ python3 -c 'import re,sys
s=open(sys.argv[1]).read()
pats=[r"sk-[A-Za-z0-9_-]{8,}",r"AKIA[0-9A-Z]{16}",r"ghp_[A-Za-z0-9]{20,}",r"eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+",r"(?i)bearer\s+[A-Za-z0-9._~+/-]{12,}",r"ya29\.[A-Za-z0-9._-]+",r"gh[opsu]_[A-Za-z0-9]{20,}"]
sys.exit(0 if any(re.search(p,s) for p in pats) else 1)' "$1"; }   # rc 0 = secret found

validate(){ python3 "$VAL" "$1" "$2" >/dev/null 2>&1; }   # rc 0 = ACCEPT

# rejected somewhere with no unsafe result ACCEPTED. rc 0 = properly rejected.
assert_rejected(){ # task fixture
  python3 "$ADAPTER" --task "$1" --mock "$FXDIR/$2" --out "$T/adv.json" >"$T/aout" 2>"$T/aerr"; local arc=$?
  if [ "$arc" != 0 ]; then [ -s "$T/aerr" ] && return 0 || return 1; fi   # adapter-level reject (+diagnostic)
  validate "$1" "$T/adv.json" && return 1 || return 0                      # else must be validator REJECT
}

echo "== syntax =="
python3 -m py_compile "$ROUTER" >/dev/null 2>&1 && ok "router compiles" || no "router compile"

for P in glm-api oauth-cli; do
  echo "== provider: $P =="
  descriptor "$P"
  TASK="$T/task-$P.json"; mktask "$TASK" "$PTYPE" "$PROVIDER"
  python3 "$ADAPTER" --task "$TASK" --mock "$FXDIR/$SUCCESS" --out "$T/r.json" >"$T/out" 2>"$T/err"; rc=$?

  # C1 schema conformance + provider_type match
  miss="$(DMC_R="$T/r.json" python3 -c 'import json,os
r=json.load(open(os.environ["DMC_R"]))
req=["task_id","summary","files_considered","files_changed","proposed_patch","instructions","confidence","no_direct_mutation","provider_metadata"]
pm=r.get("provider_metadata") or {}
miss=[k for k in req if k not in r]+["provider_metadata."+k for k in ("provider_type","provider","credential_exposure") if k not in pm]
print(",".join(miss))')"
  if [ "$rc" = 0 ] && validate "$TASK" "$T/r.json" && [ -z "$miss" ] \
     && [ "$(field "$T/r.json" provider_metadata.provider_type)" = "$PTYPE" ] \
     && [ "$(field "$T/r.json" provider_metadata.provider)" = "$PROVIDER" ]; then
    ok "C1 schema conformance + provider_type=$PTYPE/$PROVIDER + ACCEPT"; else no "C1 ($P rc=$rc miss=$miss)"; fi

  # C2 proposal-only
  [ "$(field "$T/r.json" no_direct_mutation)" = "True" ] && ok "C2 no_direct_mutation=true" || no "C2 ($P)"

  # C3 no auto-apply / no git apply in adapter + writes only --out
  grep -nE 'git[[:space:]]+apply|shell=True' "$ADAPTER" >/dev/null 2>&1 && no "C3 git apply/shell=True in adapter" || ok "C3 no git apply / no shell=True in adapter"

  # C4 no leakage: success result clean; override forces credential_exposure=none; secret input rejected
  python3 "$ADAPTER" --task "$TASK" --mock "$FXDIR/$OVERRIDE" --out "$T/ro.json" >/dev/null 2>&1
  if ! has_secret "$T/r.json" && [ "$(field "$T/r.json" provider_metadata.credential_exposure)" = "none" ] \
     && [ "$(field "$T/ro.json" provider_metadata.credential_exposure)" = "none" ] && assert_rejected "$TASK" "$SECRET"; then
    ok "C4 no secret in result; credential_exposure=none; secret input rejected"; else no "C4 ($P)"; fi

  # C5a rejection-shape: adversarial-scope + secret both rejected (adapter- OR validator-level), none ACCEPTED
  if assert_rejected "$TASK" "$BADSCOPE" && assert_rejected "$TASK" "$SECRET"; then
    ok "C5a unsafe outputs rejected before acceptance (no unsafe result ACCEPTED)"; else no "C5a ($P)"; fi

  # C5b timeout (capability-scoped)
  if [ "$EXEC_TIMEOUT" = yes ]; then
    $NOCI DMC_OAUTHCLI_BIN="$STUB" DMC_FAKECLI_MODE=timeout DMC_OAUTHCLI_TIMEOUT_SECONDS=2 python3 "$ADAPTER" --task "$TASK" --live --allow-exec >/dev/null 2>"$T/terr"; trc=$?
    [ "$trc" != 0 ] && grep -qi 'timeout' "$T/terr" && ok "C5b timeout -> killed + fail-closed (offline stub)" || no "C5b ($P trc=$trc)"
  else
    na "C5b timeout N/A (mock) for $P — live-network; covered by dmc-glm-smoke"
  fi

  # C6 stdout/stderr handling
  grep -q 'wrote result ->' "$T/out" || no "C6 --out missing 'wrote result' line ($P)"
  python3 "$ADAPTER" --task "$TASK" --mock "$FXDIR/$SUCCESS" >"$T/so.json" 2>"$T/se"
  if grep -q 'wrote result ->' "$T/out" && python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$T/so.json" 2>/dev/null \
     && ! has_secret "$T/so.json" && ! has_secret "$T/se" && ! has_secret "$T/err"; then
    ok "C6 --out line on stdout; bare JSON without --out; no secret on stdout/stderr"; else no "C6 ($P)"; fi

  # C7 mock-mode determinism
  python3 "$ADAPTER" --task "$TASK" --mock "$FXDIR/$SUCCESS" --out "$T/d1.json" >/dev/null 2>&1
  python3 "$ADAPTER" --task "$TASK" --mock "$FXDIR/$SUCCESS" --out "$T/d2.json" >/dev/null 2>&1
  cmp -s "$T/d1.json" "$T/d2.json" && ok "C7 mock-mode determinism (byte-identical --out)" || no "C7 ($P)"

  # C8 routing compatibility: --print-dispatch selects this adapter; routed --out == direct --out (mock)
  sel="$(python3 "$ROUTER" --task "$TASK" --mock "$FXDIR/$SUCCESS" --print-dispatch 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["adapter"])')"
  python3 "$ROUTER"  --task "$TASK" --mock "$FXDIR/$SUCCESS" --out "$T/route.json" >/dev/null 2>&1
  python3 "$ADAPTER" --task "$TASK" --mock "$FXDIR/$SUCCESS" --out "$T/direct.json" >/dev/null 2>&1
  if [ "${sel##*/}" = "${ADAPTER##*/}" ] && cmp -s "$T/route.json" "$T/direct.json"; then
    ok "C8 router selects $P; routed --out JSON byte-identical to direct (mock)"; else no "C8 ($P sel=$sel)"; fi

  # C11 context-guard fail-closed on secret-bearing task
  STASK="$T/sectask-$P.json"; mktask "$STASK" "$PTYPE" "$PROVIDER" "/x/.env.local"
  python3 "$ADAPTER" --task "$STASK" --mock "$FXDIR/$SUCCESS" >/dev/null 2>"$T/cerr"; crc=$?
  [ "$crc" != 0 ] && grep -qi 'context-guard' "$T/cerr" && ok "C11 secret-bearing task -> context-guard fail-closed" || no "C11 ($P crc=$crc)"
done

echo "== suite-wide =="
# C9 protected-file non-mutation
ch="$(git diff --name-only .claude/hooks/ WORKER_TASK_SCHEMA.md WORKER_RESULT_SCHEMA.md WORKER_REVIEW_SCHEMA.md dmc-glm-smoke .claude/workers/providers/glm-api/ .claude/workers/providers/oauth-cli/ .claude/workers/providers/provider-router.py)"
[ -z "$ch" ] && ok "C9 adapters/router/hooks/schemas/smoke-runner byte-unchanged" || no "C9 changed: $ch"

# C10 no live provider calls (self-audit). Needles are concatenated at runtime so THESE audit lines never self-match;
# only genuine invocation lines (e.g. the C5b stub call) can match.
LV="--""live"; KEY="GLM_API""_KEY"; BINEQ="DMC_OAUTHCLI""_BIN="
nonstub="$(grep -nE -- "$LV" "$SELF" | grep -v "${BINEQ}\"\$STUB\"" || true)"
[ -z "$nonstub" ] && ok "C10 the only live-mode invocation targets the offline stub (no real provider)" || { printf '%s\n' "$nonstub"; no "C10 a non-stub live-mode call exists"; }
grep -q "$KEY" "$SELF" && no "C10 harness references a real GLM key" || ok "C10 no real GLM key / glm-api never invoked in live mode"

echo
echo "==== SUMMARY: PASS=$PASS FAIL=$FAIL N/A=$NAC ===="
[ "$FAIL" = 0 ] && echo "RESULT: ALL PASS" || echo "RESULT: FAILURES"
