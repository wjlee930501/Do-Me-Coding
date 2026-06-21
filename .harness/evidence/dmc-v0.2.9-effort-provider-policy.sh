#!/usr/bin/env bash
# v0.2.9 Effort & Provider Policy structure-check (run: bash .harness/evidence/dmc-v0.2.9-effort-provider-policy.sh).
# READ / GREP ONLY over the policy doc. Executes NO product/router/adapter code; NO model-API/network/live call; reads
# NO .env*/credentials. Uses only read-only grep / git diff / python3 -c (in-memory regex), per the v0.2.5/v0.2.8
# precedent. A PASS proves the policy is documented/complete/own-words/clean — NOT that any agent will comply.
set -u
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
DOC="$ROOT/docs/DMC_EFFORT_PROVIDER_POLICY.md"
SELF="$ROOT/.harness/evidence/dmc-v0.2.9-effort-provider-policy.sh"
PASS=0; FAIL=0
ok(){ echo "  PASS $1"; PASS=$((PASS+1)); }
no(){ echo "  FAIL $1"; FAIL=$((FAIL+1)); }
has(){ grep -qiF -- "$2" "$1"; }

[ -f "$DOC" ] || { echo "structure-check: policy doc missing: $DOC" >&2; exit 1; }

echo "== P1 policy doc exists + nature (guidance not enforcement; presence != compliance) =="
if has "$DOC" "guidance" && has "$DOC" "NOT an enforcement" && has "$DOC" "presence" && has "$DOC" "compliance" && has "$DOC" "separate approved future milestone"; then
  ok "P1 nature: guidance-not-enforcement + presence!=compliance + enforcement=future"; else no "P1"; fi

echo "== P2 fast-model criteria =="
has "$DOC" "fast / simple model" && has "$DOC" "docs-only / test-only" && ok "P2 fast-model criteria present" || no "P2"
echo "== P3 Opus-class criteria =="
has "$DOC" "Opus-class" && has "$DOC" "protected-surface" && ok "P3 Opus criteria present" || no "P3"
echo "== P4 Codex audit policy =="
has "$DOC" "Codex release audit" && has "$DOC" "before a stage / commit / push decision" && has "$DOC" "audit input feeding" && ok "P4 Codex audit policy present" || no "P4"
echo "== P5 separate-critic policy =="
has "$DOC" "separate critic pass" && has "$DOC" "separation of duties" && has "$DOC" "adversarial panel" && ok "P5 separate-critic policy present" || no "P5"
echo "== P6 escalate-to-human policy =="
has "$DOC" "escalate to a human" && has "$DOC" "hard gate" && has "$DOC" "fail-closed" && ok "P6 escalate policy present" || no "P6"
echo "== P7 when-to-STOP policy =="
has "$DOC" "STOP instead of spending more tokens" && has "$DOC" "E2E done" && has "$DOC" "converged" && has "$DOC" "anti-token-max" && ok "P7 stop policy present" || no "P7"
echo "== P8 task-class -> workflow mapping (7 classes) =="
miss=""; for c in "docs-only" "test-only" "adapter" "router" "schema/guard" "live/credential" "release"; do has "$DOC" "$c" || miss="$miss $c"; done
[ -z "$miss" ] && ok "P8 7-class mapping present" || no "P8 missing:$miss"
echo "== P9 ultracode interaction (depth not scope) =="
has "$DOC" "Ultracode interaction" && has "$DOC" "Depth, not scope" && ok "P9 ultracode interaction present" || no "P9"

echo "== H1 own-words authorship (positive) =="
own=1; for t in "Release Gate" "anti-token-max" "fail-closed" "E2E done" "Codex" "Orchestrator"; do has "$DOC" "$t" || own=0; done
[ "$own" = 1 ] && ok "H1 own-words DMC terms present" || no "H1"

echo "== H2 no leaked/proprietary contamination (zero stored leaked prose) =="
# Generic public system-prompt contamination markers, built by concatenation so THIS line never self-matches; scan DOC only.
declare -a MARK=("You are Chat""GPT" "You are Gem""ini" "knowledge cut""off" "large language mod""el, ")
contam=0; for m in "${MARK[@]}"; do has "$DOC" "$m" && contam=1; done
[ "$contam" = 0 ] && ok "H2 no contamination markers; doc stores zero reproduced leaked prose" || no "H2 contamination found"

echo "== H3 no secret/token shapes in doc (separate scan) =="
python3 -c 'import re,sys
s=open(sys.argv[1]).read()
pats=[r"sk-[A-Za-z0-9_-]{8,}",r"AKIA[0-9A-Z]{16}",r"ghp_[A-Za-z0-9]{20,}",r"eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+",r"(?i)bearer\s+[A-Za-z0-9._~+/-]{12,}",r"ya29\.[A-Za-z0-9._-]+"]
sys.exit(1 if any(re.search(p,s) for p in pats) else 0)' "$DOC" && ok "H3 no secret/token shapes in doc" || no "H3 secret shape found"

echo "== H4 protected files byte-unchanged =="
ch="$(git -C "$ROOT" diff --name-only -- .claude/workers/providers/provider-router.py .claude/workers/providers/ROUTING.md .claude/workers/providers/PROVIDER_CONTRACT.md .claude/workers/providers/glm-api .claude/workers/providers/oauth-cli .claude/hooks WORKER_TASK_SCHEMA.md WORKER_RESULT_SCHEMA.md WORKER_REVIEW_SCHEMA.md dmc-glm-smoke)"
[ -z "$ch" ] && ok "H4 router/adapters/hooks/schemas/smoke-runner byte-unchanged" || no "H4 changed: $ch"

echo "== H5 self-audit: no dangerous exec/live/network/.env-open in the check (needles concatenated) =="
LIVE="--""live"; ULIB="url""lib"; REQ="requ""ests"; CRL="cu""rl"; WGT="wg""et"; ENVOPEN="(cat|source|<|open)[^|]*\.""env"
APX="python3[^|]*(adapter|router)[^|]*\.""py"
hits="$(grep -nE -- "$LIVE|$ULIB|$REQ|$CRL|$WGT|$APX|$ENVOPEN" "$SELF" || true)"
[ -z "$hits" ] && ok "H5 read-only — no dangerous exec/live/network/.env-open (benign python3/grep/git permitted)" || { printf '%s\n' "$hits"; no "H5 dangerous token present"; }

echo "== H6 meta-guard: self-audit denylists non-empty + concatenation-built (not gutted) =="
# H5 dangerous needles and H2 markers must be non-empty and built split-literal.
[ "${#MARK[@]}" -ge 1 ] && grep -q 'You are Chat""GPT' "$SELF" && grep -q '"--""live"' "$SELF" && ok "H6 denylists non-empty + concatenation-built" || no "H6 meta-guard"

echo
echo "==== SUMMARY: PASS=$PASS FAIL=$FAIL ===="
[ "$FAIL" = 0 ] && echo "RESULT: ALL PASS" || echo "RESULT: FAILURES"
[ "$FAIL" = 0 ]; exit $?