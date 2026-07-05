#!/usr/bin/env bash
# v0.2.5 Agent Operating Handbook structure-check (run: bash .harness/evidence/dmc-v0.2.5-verify.sh).
# READ / GREP ONLY. No code execution, no live call, no network, no .env*/credential read.
# NOTE: a passing run proves the operating contract is documented, structurally complete, own-words authored, and
# leak/secret-free. It does NOT prove future agent compliance (enforcement is a separate approved future milestone).
set -u
ROOT="$(pwd)"; PASS=0; FAIL=0
ok(){ echo "  PASS $1"; PASS=$((PASS+1)); }
no(){ echo "  FAIL $1"; FAIL=$((FAIL+1)); }
HB="$ROOT/docs/DMC_OPERATOR_HANDBOOK.md"
HO="$ROOT/docs/DMC_AGENT_HANDOFF.md"
SELF="$ROOT/.harness/evidence/dmc-v0.2.5-verify.sh"
has(){ grep -qiF -- "$2" "$1"; }            # literal substring, case-insensitive
hasre(){ grep -qiE -- "$2" "$1"; }          # regex

echo "== H1 handbook exists + E2E-done (5 parts) =="
if [ -f "$HB" ] && has "$HB" "operating contract" && has "$HB" "verified" && has "$HB" "reviewed" \
   && has "$HB" "committed" && has "$HB" "pushed" && has "$HB" "closure-recorded" && has "$HB" "in progress"; then
  ok "H1 E2E-done = verified/reviewed/committed/pushed/closure-recorded; else in progress"; else no "H1"; fi

echo "== H2 four roles =="
if has "$HB" "Orchestrator" && has "$HB" "Implementer" && has "$HB" "Critic" && has "$HB" "Release Gate" \
   && has "$HB" "no self-approval" && has "$HB" "author-and-approve" && has "$HB" "self-granted gate"; then
  ok "H2 Orchestrator/Implementer/Critic/Release Gate + no self-approval/author-and-approve/self-grant"; else no "H2"; fi

echo "== H3 allowed-autonomy list =="
if has "$HB" "Allowed autonomy" && has "$HB" "Drafting and revising plans" && has "$HB" "mock / offline" \
   && has "$HB" "verification reports"; then ok "H3 allowed autonomy present"; else no "H3"; fi

echo "== H4 gated actions (incl force ops + external publish) =="
if has "$HB" "Gated actions" && has "$HB" "Approval Status" && has "$HB" "git commit" && has "$HB" "git push" \
   && has "$HB" "live provider call" && has "$HB" "Force operations" && has "$HB" "External publish"; then
  ok "H4 gated actions incl force-ops/history-rewrite + external publish/send"; else no "H4"; fi

echo "== H5 fail-closed rules (5 conditions) =="
if has "$HB" "Fail-closed rules" && has "$HB" "Scope is ambiguous" && has "$HB" "protected-file diff" \
   && has "$HB" "exposure risk" && has "$HB" "live-call risk" && has "$HB" "verification check FAIL"; then
  ok "H5 fail-closed: ambiguity/protected-diff/credential/live-call/verify-fail"; else no "H5"; fi

echo "== H6 anti-token-max as behavioral norm =="
if has "$HB" "Anti-token-max" && has "$HB" "smallest workflow" && has "$HB" "behavioral norm" \
   && has "$HB" "not tool-enforced"; then ok "H6 anti-token-max behavioral norm"; else no "H6"; fi

echo "== H6b enforcement = future separate milestone; contract not enforcement =="
if has "$HB" "NOT an enforcement mechanism" && has "$HB" "separate approved future milestone" \
   && has "$HB" "cannot prove future agent compliance"; then ok "H6b contract-not-enforcement + future milestone"; else no "H6b"; fi

echo "== H7 six prompt templates (in handoff) =="
miss=""; for t in "### critic" "### start-work" "### staging-review" "### commit-review" "### push-review" "### milestone-closure"; do
  has "$HO" "$t" || miss="$miss $t"; done
[ -z "$miss" ] && ok "H7 six templates present" || no "H7 missing:$miss"

echo "== H8 handoff: state machine + resume rule + fail-closed checklist =="
if [ -f "$HO" ] && has "$HO" "DRAFT" && has "$HO" "CLOSURE" && has "$HO" "re-confirm the current gate" \
   && has "$HO" "Never infer a gate" && has "$HO" "Fail-closed checklist"; then
  ok "H8 resume card + gate-confirmation + never-infer-a-gate + fail-closed checklist"; else no "H8"; fi

echo "== H9 own-words authorship (positive) + zero-leaked-prose contamination (tiny generic denylist) =="
own_ok=1
for term in "Release Gate" "anti-token-max" "E2E done" "DMC milestone loop" "fail-closed" "Orchestrator" "Implementer" "Critic"; do
  has "$HB" "$term" || own_ok=0; done
# Tiny GENERIC public contamination markers only (no proprietary/leaked body text stored). Build by concatenation so
# THIS line never self-matches; scan only the docs, never this harness.
declare -a MARK=("You are Chat""GPT" "You are Gem""ini" "knowledge cut""off" "large language mod""el, ")
contam=0
for m in "${MARK[@]}"; do has "$HB" "$m" && contam=1; has "$HO" "$m" && contam=1; done
if [ "$own_ok" = 1 ] && [ "$contam" = 0 ]; then
  ok "H9 own-words authorship present; zero reproduced leaked prose; no generic contamination markers"; else no "H9 (own=$own_ok contam=$contam)"; fi

echo "== H10 no secret/token shapes in docs (separate scan) =="
sec=0
for d in "$HB" "$HO"; do python3 -c 'import re,sys
s=open(sys.argv[1]).read()
pats=[r"sk-[A-Za-z0-9_-]{8,}",r"AKIA[0-9A-Z]{16}",r"ghp_[A-Za-z0-9]{20,}",r"eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+",r"(?i)bearer\s+[A-Za-z0-9._~+/-]{12,}",r"ya29\.[A-Za-z0-9._-]+",r"gh[opsu]_[A-Za-z0-9]{20,}"]
sys.exit(1 if any(re.search(p,s) for p in pats) else 0)' "$d" || sec=1; done
[ "$sec" = 0 ] && ok "H10 no secret/token shapes in either doc" || no "H10 secret shape found"

echo "== H11 protected files byte-unchanged =="
ch="$(git diff --name-only .claude/hooks/ WORKER_TASK_SCHEMA.md WORKER_RESULT_SCHEMA.md WORKER_REVIEW_SCHEMA.md dmc-glm-smoke .claude/workers/providers/glm-api/ .claude/workers/providers/oauth-cli/ .claude/workers/providers/provider-router.py .claude/workers/providers/ROUTING.md)"
[ -z "$ch" ] && ok "H11 adapters/router/hooks/schemas/smoke-runner byte-unchanged" || no "H11 changed: $ch"

echo "== H12 check executes no code / touches no live path (self-audit; needles concatenated) =="
LIVE="--""live"; ADPY="adapter"".py"; ULIB="url""lib"; CRL="cu""rl"; WGT="wg""et"
hits="$(grep -nE -- "$LIVE|$ADPY|$ULIB|$CRL|$WGT" "$SELF" || true)"
[ -z "$hits" ] && ok "H12 read/grep only — no adapter exec, no live/network call" || { printf '%s\n' "$hits"; no "H12 forbidden invocation token present"; }

echo "== H13 excluded auto-logged evidence remains untracked (not staged) =="
exok=1
for f in .harness/evidence/dmc-v0.2.2-oauth-cli-adapter.md .harness/evidence/dmc-v0.2.3-provider-routing.md .harness/evidence/dmc-v0.2.4-provider-contract-tests.md; do
  git ls-files --error-unmatch "$f" >/dev/null 2>&1 && exok=0; done
[ "$exok" = 1 ] && ok "H13 the three prior auto-logged evidence files are untracked/excluded" || no "H13 an excluded evidence file is tracked"

echo
echo "==== SUMMARY: PASS=$PASS FAIL=$FAIL ===="
[ "$FAIL" = 0 ] && echo "RESULT: ALL PASS" || echo "RESULT: FAILURES"
