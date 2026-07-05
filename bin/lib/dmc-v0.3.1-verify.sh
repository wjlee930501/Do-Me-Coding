#!/usr/bin/env bash
# v0.3.1 Manual Import Provider — contract verification (run: bash .harness/evidence/dmc-v0.3.1-verify.sh).
# MOCK / OFFLINE ONLY. No external provider, no network, no real credential, no .env*. Standalone adapter (no router).
# V1-V16 per the approved plan; PROVIDER_CONTRACT C5a reject semantics; per-reject-path stdout+stderr leak checks.
set -u
export PYTHONDONTWRITEBYTECODE=1   # never litter __pycache__ (esp. under the protected .claude/hooks) during verification
ROOT="$(pwd)"; PASS=0; FAIL=0
ok(){ echo "    PASS $1"; PASS=$((PASS+1)); }
no(){ echo "    FAIL $1"; FAIL=$((FAIL+1)); }
PROV="$ROOT/.claude/workers/providers"
ADAPTER="$PROV/manual-import/manual-import-adapter.py"
FXDIR="$PROV/manual-import/fixtures"
OAUTH="$PROV/oauth-cli/oauth-cli-adapter.py"
VAL="$ROOT/.claude/hooks/worker-result-check.py"
SELF="$ROOT/.harness/evidence/dmc-v0.3.1-verify.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
ST_PRE="$(git -C "$ROOT" status --porcelain 2>/dev/null | md5)"

md5(){ command md5 2>/dev/null || md5sum; }
field(){ DMC_F="$2" python3 -c 'import json,os,sys
v=json.load(open(sys.argv[1]))
for k in os.environ["DMC_F"].split("."):
    v=v.get(k) if isinstance(v,dict) else None
print(v)' "$1"; }
validate(){ python3 "$VAL" "$1" "$2" >/dev/null 2>&1; }   # rc 0 = ACCEPT
leak_clean(){ # canary stdoutfile stderrfile  -> rc 0 iff canary absent from BOTH
  ! grep -qF -- "$1" "$2" 2>/dev/null && ! grep -qF -- "$1" "$3" 2>/dev/null; }
# adapter-LEVEL reject: exit!=0 with a stderr diagnostic and NO result emitted on stdout. (o/e captured to $T/o,$T/e)
adapter_reject(){ python3 "$ADAPTER" --task "$1" --import "$FXDIR/$2" >"$T/o" 2>"$T/e"; local rc=$?
  [ "$rc" != 0 ] && [ -s "$T/e" ] && [ ! -s "$T/o" ]; }
# C5a: no unsafe artifact ever ACCEPTED — adapter rejects (exit!=0) OR validator REJECTs the written result.
c5a_reject(){ python3 "$ADAPTER" --task "$1" --import "$FXDIR/$2" --out "$T/adv.json" >"$T/o" 2>"$T/e"; local rc=$?
  if [ "$rc" != 0 ]; then [ -s "$T/e" ]; return $?; fi
  validate "$1" "$T/adv.json" && return 1 || return 0; }
mktask(){ # outfile [extra_allowed]
  python3 -c 'import json,sys
allowed=["src/app.ts"]+([sys.argv[2]] if len(sys.argv)>2 else [])
json.dump({"task_id":"mi-contract","objective":"Edit src/app.ts.","allowed_files":allowed,"forbidden_files":["src/secret.ts"],"context_summary":"x","relevant_snippets":[],"expected_output_type":"unified_diff","provider_target":{"type":"manual_import","provider":"manual-import","model":"m","execution_mode":"proposal_only","credential_policy":"no_credentials_in_repo","secret_policy":"no_secret_context"}}, open(sys.argv[1],"w"))' "$@"; }

echo "== syntax =="
python3 -c 'import ast,sys; ast.parse(open(sys.argv[1]).read())' "$ADAPTER" >/dev/null 2>&1 && ok "adapter parses (syntax ok)" || no "adapter syntax"

TASK="$T/task.json"; mktask "$TASK"
SCOPETASK="$T/scopetask.json"; mktask "$SCOPETASK" "package-lock.json"   # allows it past context-guard; DISALLOWED lockfile (V5)
STASK="$T/sectask.json"; mktask "$STASK" "/x/.env.local"                 # secret-bearing task -> context-guard fail-closed (V9)

echo "== V1 valid import accepted + worker-result-check.py ACCEPT =="
python3 "$ADAPTER" --task "$TASK" --import "$FXDIR/import-success.json" --out "$T/r.json" >"$T/o" 2>"$T/e"; rc=$?
miss="$(DMC_R="$T/r.json" python3 -c 'import json,os
r=json.load(open(os.environ["DMC_R"]))
req=["task_id","summary","files_considered","files_changed","proposed_patch","instructions","confidence","no_direct_mutation","provider_metadata"]
pm=r.get("provider_metadata") or {}
print(",".join([k for k in req if k not in r]+["provider_metadata."+k for k in ("provider_type","provider","credential_exposure") if k not in pm]))' 2>/dev/null)"
if [ "$rc" = 0 ] && validate "$TASK" "$T/r.json" && [ -z "$miss" ] \
   && [ "$(field "$T/r.json" provider_metadata.provider_type)" = manual_import ] \
   && [ "$(field "$T/r.json" provider_metadata.provider)" = manual-import ] \
   && [ "$(field "$T/r.json" provider_metadata.credential_exposure)" = none ] \
   && [ "$(field "$T/r.json" no_direct_mutation)" = True ]; then
  ok "V1 valid import ACCEPTed; schema-conformant; provider_type=manual_import; validator ACCEPT"
else no "V1 (rc=$rc miss=$miss)"; fi

echo "== V2 malformed JSON rejected + leak-check =="
adapter_reject "$TASK" import-malformed.json && leak_clean "LEAKCANARY_MALFORMED1" "$T/o" "$T/e" \
  && ok "V2 malformed JSON -> reject (exit!=0), no artifact-body leak on stdout/stderr" || no "V2"

echo "== V3 missing mandatory fields rejected at ADAPTER level + leak-check (incl. empty artifact) =="
if adapter_reject "$TASK" import-missing-fields.json && leak_clean "LEAKCANARY_MISSING1" "$T/o" "$T/e" \
   && adapter_reject "$TASK" import-empty.json; then
  ok "V3 missing-mandatory + empty -> ADAPTER-level reject; leak-clean"; else no "V3"; fi

echo "== V4 unknown/extra field rejected at ADAPTER level + leak-check =="
adapter_reject "$TASK" import-extra-fields.json && leak_clean "LEAKCANARY_EXTRA1_value" "$T/o" "$T/e" \
  && ok "V4 unknown/extra field -> ADAPTER-level reject (strict envelope); leak-clean" || no "V4"

echo "== V5 disallowed-category scope rejected (C5a) + leak-check =="
if c5a_reject "$SCOPETASK" import-bad-scope.json && grep -q 'disallowed-category' "$T/e" \
   && leak_clean "package-lock.json" "$T/o" "$T/e"; then
  ok "V5 disallowed-category path -> rejected (no ACCEPT); branch confirmed; leak-clean"; else no "V5"; fi

echo "== V6 OAuth/JWT/token-like import rejected at ADAPTER level + leak-check =="
adapter_reject "$TASK" import-secret.json && leak_clean "TOKCANARY1" "$T/o" "$T/e" \
  && ok "V6 token-like content -> ADAPTER-level reject (adapter sole gate for OAuth class); no token value leaked" || no "V6"

echo "== V7 direct-mutation / auto-apply attempt rejected (C5a) + leak-check =="
c5a_reject "$TASK" import-mutation-attempt.json && leak_clean "LEAKCANARY_MUT1" "$T/o" "$T/e" \
  && ok "V7 mutation attempt (adapter-owned no_direct_mutation) -> rejected; leak-clean" || no "V7"

echo "== V8 deterministic --out JSON byte-identical (mock/offline; --out only) =="
python3 "$ADAPTER" --task "$TASK" --import "$FXDIR/import-success.json" --out "$T/d1.json" >/dev/null 2>&1
python3 "$ADAPTER" --task "$TASK" --import "$FXDIR/import-success.json" --out "$T/d2.json" >/dev/null 2>&1
cmp -s "$T/d1.json" "$T/d2.json" && ok "V8 deterministic --out (byte-identical; no wall-clock/random)" || no "V8"

echo "== V9 context-guard fail-closed on secret-bearing task (positional invocation) =="
python3 "$ADAPTER" --task "$STASK" --import "$FXDIR/import-success.json" >"$T/o" 2>"$T/e"; crc=$?
[ "$crc" != 0 ] && grep -qi 'context-guard' "$T/e" && ok "V9 secret-bearing task -> context-guard fail-closed" || no "V9 (crc=$crc)"

echo "== V10 no .env*/credential/implicit read (only the DMC_MANUAL_IMPORT_MAX_BYTES size env) =="
envrefs="$(grep -oE 'os\.environ[^A-Za-z0-9_]*(get\()?["'\''][A-Za-z_]+' "$ADAPTER" | grep -oE '[A-Z_]+$' | sort -u | tr '\n' ' ')"
NETN="url""lib"; REQN="requ""ests"; SOCKN="sock""et"; HTTPN="http""x"
if [ "$(echo "$envrefs" | tr -s ' ' | sed 's/ *$//')" = "DMC_MANUAL_IMPORT_MAX_BYTES" ] \
   && ! grep -qE -- "$NETN|$REQN|$SOCKN|$HTTPN" "$ADAPTER"; then
  ok "V10 no implicit/.env/credential read; only env = DMC_MANUAL_IMPORT_MAX_BYTES (size); no network lib"; else no "V10 (env=$envrefs)"; fi

echo "== V11 no live/network/provider-exec path (only the read-only context-guard subprocess) =="
# Audit CODE constructs only (not docstring prose). A git-apply could only occur via a 2nd subprocess.run / os.system —
# both excluded — so the single context-guard subprocess + no-os.system fully covers "no provider/git exec".
SHT="shell""=True"; SYS="os.""system"; NETN="url""lib"; REQN="requ""ests"; SOCKN="sock""et"; HTTPN="http""x"
subn="$(grep -c 'subprocess\.run(' "$ADAPTER")"
if ! grep -qE -- "$SHT|$SYS|$NETN|$REQN|$SOCKN|$HTTPN" "$ADAPTER" \
   && grep -q 'subprocess.run(\["bash", CTX_GUARD' "$ADAPTER" \
   && [ "$subn" = 1 ]; then
  ok "V11 no os.system/shell=True/network; the only subprocess.run targets bash worker-context-guard.sh (read-only)"; else no "V11 (subprocess.run calls=$subn)"; fi

echo "== V12 protected files byte-unchanged =="
ch="$(git -C "$ROOT" diff --name-only -- \
  .claude/hooks/ WORKER_TASK_SCHEMA.md WORKER_RESULT_SCHEMA.md WORKER_REVIEW_SCHEMA.md dmc-glm-smoke \
  .claude/workers/providers/glm-api/ .claude/workers/providers/oauth-cli/ \
  .claude/workers/providers/provider-router.py .claude/workers/providers/ROUTING.md \
  .claude/workers/providers/PROVIDER_CONTRACT.md)"
[ -z "$ch" ] && ok "V12 router/adapters/hooks/schemas/contract/smoke byte-unchanged" || no "V12 changed: $ch"

echo "== V13 --out guard (protected + traversal refused exit 2 + not created; benign writes) =="
rm -f "$T/sub/.claude/hooks/evil" "$T/trav.json" 2>/dev/null
python3 "$ADAPTER" --task "$TASK" --import "$FXDIR/import-success.json" --out "$T/sub/.claude/hooks/evil" >/dev/null 2>"$T/ge"; grc=$?
python3 "$ADAPTER" --task "$TASK" --import "$FXDIR/import-success.json" --out "$T/x/../trav.json" >/dev/null 2>&1; trc=$?
python3 "$ADAPTER" --task "$TASK" --import "$FXDIR/import-success.json" --out "$T/benign.json" >/dev/null 2>&1; brc=$?
if [ "$grc" = 2 ] && [ ! -e "$T/sub/.claude/hooks/evil" ] \
   && [ "$trc" = 2 ] && [ ! -e "$T/trav.json" ] \
   && [ "$brc" = 0 ] && [ -s "$T/benign.json" ]; then
  ok "V13 --out protected + traversal (..) refused (exit 2, not created); benign --out writes"; else no "V13 (grc=$grc trc=$trc brc=$brc)"; fi

echo "== V14 real repo untouched =="
[ "$ST_PRE" = "$(git -C "$ROOT" status --porcelain 2>/dev/null | md5)" ] && ok "V14 real repo byte-identical (writes only under \$TMPDIR)" || no "V14 repo changed during run"

echo "== V15 imported credential_exposure!='none' rejected at ADAPTER level + leak-check =="
adapter_reject "$TASK" import-cred-exposure.json && leak_clean "LEAKCANARY_CRED1" "$T/o" "$T/e" \
  && ok "V15 adapter-owned credential_exposure supplied -> ADAPTER-level reject; leak-clean" || no "V15"

echo "== V16 token-pattern drift check (compare compiled-regex .pattern strings, not object identity) =="
python3 - "$ADAPTER" "$OAUTH" <<'PY' && ok "V16 manual-import OAuth patterns literally identical to oauth-cli OAUTH_TOKEN_PATTERNS" || no "V16 drift"
import importlib.util as u, sys
def load(p, n):
    s = u.spec_from_file_location(n, p); m = u.module_from_spec(s); s.loader.exec_module(m); return m
mi = load(sys.argv[1], "mi"); oc = load(sys.argv[2], "oc")
a = [r.pattern for r in mi.OAUTH_TOKEN_PATTERNS]
b = [r.pattern for r in oc.OAUTH_TOKEN_PATTERNS]
sys.exit(0 if a == b and len(a) >= 6 else 1)
PY

echo
echo "==== SUMMARY: PASS=$PASS FAIL=$FAIL ===="
[ "$FAIL" = 0 ] && echo "RESULT: ALL PASS" || echo "RESULT: FAILURES"
[ "$FAIL" = 0 ]; exit $?
