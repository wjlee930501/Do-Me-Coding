#!/usr/bin/env bash
# dmc-v0.6.0-verify.sh — read-only structure checker for DMC v0.6.0
# (Harness Landscape & Orchestration Taxonomy).
#
# Nature: ARCHITECTURE GUIDANCE VERIFIER, NOT ENFORCEMENT. Structure-check only.
# Read-only: greps deliverable docs; never writes the repo; never reads .env or
# credentials; makes no network / live / model / API call. Inert unless invoked
# with --verify or --self-test. Deterministic; repo_hash is env-free.
#
# Usage:
#   dmc-v0.6.0-verify.sh --verify      Run structural assertions V1..V17, print table, exit 0/1.
#   dmc-v0.6.0-verify.sh --self-test   Run V1..V17 + V18 (repo byte-unchanged) + checker self-tests.
#   dmc-v0.6.0-verify.sh [-h|--help]   Print usage and exit (inert; no checks run).
#
# Assertions V1..V18 are defined in .harness/plans/dmc-v0.6.0-harness-landscape-taxonomy.md (section 6).

set -u

# --- Root derivation from script location (not CWD); hard-fail if not a git worktree. ---
SELF_DIR=$(cd -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd -P) || { echo "FATAL: cannot resolve script dir"; exit 2; }
ROOT=$(cd -- "$SELF_DIR/../.." >/dev/null 2>&1 && pwd -P) || { echo "FATAL: cannot resolve repo root"; exit 2; }
if ! git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "FATAL: derived root is not a git worktree: $ROOT"; exit 2
fi
SELF_PATH="$SELF_DIR/$(basename -- "$0")"

# --- Deliverable paths (relative to ROOT). ---
LAND="$ROOT/docs/HARNESS_LANDSCAPE_2026.md"
CARDS="$ROOT/docs/HARNESS_BENCHMARK_CARDS_2026.md"
TAX="$ROOT/docs/ORCHESTRATION_TAXONOMY.md"
ADOPT="$ROOT/docs/DMC_ADOPTION_DECISIONS.md"
REPORT="$ROOT/.harness/verification/dmc-v0.6.0-harness-landscape-taxonomy.md"
DOCS_CONTENT="$LAND $CARDS $TAX $ADOPT $REPORT"   # content deliverables (raw-scannable)

PASS=0; FAIL=0
record() { # record PASS|FAIL ID DESC
  if [ "$1" = PASS ]; then PASS=$((PASS+1)); printf '  [PASS] %-4s %s\n' "$2" "$3"
  else FAIL=$((FAIL+1)); printf '  [FAIL] %-4s %s\n' "$2" "$3"; fi
}
ok() { [ "$1" -eq 0 ] && record PASS "$2" "$3" || record FAIL "$2" "$3"; }

# repo_hash: env-free, deterministic, CONTENT-SENSITIVE snapshot. Hashes the
# working-tree status PLUS the bytes of every deliverable + this script, so an
# in-place content edit of an untracked deliverable is detected (porcelain alone
# only reports '?? path' regardless of content).
repo_hash() {
  {
    git -C "$ROOT" status --porcelain
    for f in "$LAND" "$CARDS" "$TAX" "$ADOPT" "$REPORT" "$SELF_PATH"; do
      printf '\n@@ %s\n' "$f"
      [ -f "$f" ] && cat "$f"
    done
  } | python3 -c 'import sys,hashlib; sys.stdout.write(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())'
}

# stripped_self: script source with comments and quoted-string literals removed,
# so the V14/V12 self-audit sees only executable command structure (the secret /
# network / leak pattern literals all live inside quotes and are removed).
stripped_self() {
  sed -e 's/#.*$//' -e "s/'[^']*'//g" -e 's/"[^"]*"//g' "$SELF_PATH"
}

# count helper
cnt() { grep -cE "$1" "$2" 2>/dev/null || true; }

run_assertions() {
  # ---- V1 / V2: deliverables exist ----
  { [ -f "$LAND" ] && [ -f "$TAX" ] && [ -f "$ADOPT" ]; }; ok $? V1 "landscape + taxonomy + adoption docs exist"
  [ -f "$CARDS" ]; ok $? V2 "benchmark cards doc exists"

  # ---- V3: source table in landscape (header + >=1 row) ----
  if grep -qF '## Source table' "$LAND" 2>/dev/null \
     && grep -qE '^\| *Project *\| *Pattern surveyed *\|' "$LAND" 2>/dev/null \
     && [ "$(cnt '^\| ' "$LAND")" -ge 3 ]; then ok 0 V3 "source table present (header + >=1 row)"; else ok 1 V3 "source table present (header + >=1 row)"; fi

  # ---- V4: adoption decision table with columns pattern/evidence/decision/rationale/risk ----
  grep -qE '^\|[[:space:]]*Pattern[[:space:]]*\|.*Evidence.*\|.*Decision.*\|.*Rationale.*\|.*Risk' "$ADOPT" 2>/dev/null
  ok $? V4 "adoption table has pattern/evidence/decision/rationale/risk columns"

  # ---- V5: model-role taxonomy (all six roles named) ----
  local r=0
  for role in '### Strategic Orchestrator' '### Implementer' '### Critic / Falsifier' '### Release Auditor' '### Verifier' '### Human Release Gate'; do
    grep -qF "$role" "$TAX" 2>/dev/null || r=1
  done
  ok $r V5 "model-role taxonomy names all six roles"

  # ---- V6: work-delegation matrix (seven task classes x five columns) ----
  local m=0
  for tc in '`docs-only`' '`additive tool`' '`provider adapter`' '`protected-surface change`' '`security/secret/live risk`' '`release/closure`' '`recovery/resume`'; do
    grep -qF "$tc" "$TAX" 2>/dev/null || m=1
  done
  grep -qE 'Orchestrator class.*Implementer class.*Critic depth.*Verification depth.*Required human gates' "$TAX" 2>/dev/null || m=1
  ok $m V6 "delegation matrix: 7 task classes x 5 columns"

  # ---- V7: >=23 benchmark cards ----
  local cards; cards=$(cnt '^### Card ' "$CARDS")
  [ "$cards" -ge 23 ]; ok $? V7 "benchmark cards >= 23 (found $cards)"

  # ---- V8: every card carries EXACTLY ONE valid adopt/adapt/reject/defer decision (per-card, not file-wide) ----
  local v8out v8cards v8bad
  v8out=$(awk '
    /^### Card /{ if(seen && d!=1) bad++; cards++; seen=1; d=0; next }
    /^- \*\*Decision:\*\*[[:space:]]+(adopt|adapt|reject|defer)[[:space:]]*$/{ d++ }
    END{ if(seen && d!=1) bad++; printf "%d %d", cards, bad+0 }
  ' "$CARDS" 2>/dev/null)
  v8cards=${v8out% *}; v8bad=${v8out#* }
  { [ "${v8cards:-0}" -ge 23 ] && [ "${v8bad:-1}" -eq 0 ]; }; ok $? V8 "every card has exactly one valid decision (cards=${v8cards:-0}, bad=${v8bad:-NA})"

  # ---- V9: every card has 'What DMC already has' + 'Gap in DMC' ----
  local has gap; has=$(cnt '^- \*\*What DMC already has:\*\*' "$CARDS"); gap=$(cnt '^- \*\*Gap in DMC:\*\*' "$CARDS")
  { [ "$has" -ge 23 ] && [ "$gap" -ge 23 ]; }; ok $? V9 "every card has DMC-equivalent + gap ($has/$gap)"

  # ---- V10: every card carries the no-leaked-prompt attestation ----
  local att; att=$(grep -cF 'No leaked prompt body or proprietary text is copied in this card.' "$CARDS" 2>/dev/null || true)
  [ "$att" -ge 23 ]; ok $? V10 "every card carries attestation ($att)"

  # ---- V11: own-words DMC vocabulary markers present ----
  local v=0
  for marker in 'lane' 'gate' 'evidence' 'advisory' 'Release Gate'; do
    grep -rqiF "$marker" $DOCS_CONTENT 2>/dev/null || v=1
  done
  ok $v V11 "DMC vocabulary markers present (lane/gate/evidence/advisory/human-gate)"

  # ---- V12: no secret-shaped strings in any deliverable ----
  local secret_re='eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}|sk-[A-Za-z0-9]{16,}|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{10,}|AIza[0-9A-Za-z_-]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{12,}|ya29\.[A-Za-z0-9_-]{10,}|AccountKey=[A-Za-z0-9+/=]{20,}|[A-Za-z][A-Za-z0-9+.-]*://[^/[:space:]@]+:[^/[:space:]@]+@'
  local s12=0
  grep -EqI "$secret_re" $DOCS_CONTENT 2>/dev/null && s12=1
  stripped_self | grep -EqI "$secret_re" 2>/dev/null && s12=1
  ok $s12 V12 "no secret-shaped strings in any deliverable"

  # ---- V13: no leaked/proprietary/system-prompt body-text markers + no over-long quote block ----
  local leak_re='-----BEGIN|<\|im_start\|>|<\|im_end\|>|^System:|^Human:|^Assistant:|^You are (ChatGPT|Claude)|BEGIN SYSTEM PROMPT|raw provider response|pasted transcript'
  local s13=0
  grep -EqI "$leak_re" $DOCS_CONTENT 2>/dev/null && s13=1
  stripped_self | grep -EqI "$leak_re" 2>/dev/null && s13=1
  # over-long consecutive blockquote run (> 12 lines) in any content deliverable
  local maxq; maxq=$(awk 'FNR==1{c=0} /^>/{c++; if(c>m)m=c; next}{c=0} END{print m+0}' $DOCS_CONTENT 2>/dev/null)
  [ "${maxq:-0}" -gt 12 ] && s13=1
  ok $s13 V13 "no leaked/transcript markers; no over-long quote block (max run ${maxq:-0})"

  # ---- V14: verify script's own operative source has no .env/credential read, no live/model/API, no network ----
  local n14=0
  stripped_self | grep -Eqi '(^|[[:space:];&|(])(curl|wget|nc|ncat|telnet|ssh|scp|sftp|ftp)([[:space:]]|$)' && n14=1
  stripped_self | grep -Eqi '\.env|API_KEY|ANTHROPIC|OPENAI|GLM_API|access_token|refresh_token|/dev/(tcp|udp)/' && n14=1
  ok $n14 V14 "verify script operative source: no .env read / live / model / network"

  # ---- V15: no protected-surface change; tracked changes within allowed scope ----
  local st; st=$(git -C "$ROOT" status --porcelain 2>/dev/null)
  local p15=0
  printf '%s\n' "$st" | grep -E '(^|[[:space:]"])(\.claude/hooks/|\.claude/workers/|provider-router|ROUTING\.md|PROVIDER_CONTRACT\.md|WORKER_[A-Z]+_SCHEMA\.md|secret-guard|pre-tool-guard|dmc-glm-smoke)' >/dev/null 2>&1 && p15=1
  # tracked modifications (codes other than '??') must be within allowed prefixes
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    local code path
    code=${line:0:2}; path=${line:3}
    case "$code" in
      '??') continue ;;  # untracked (new deliverables + pre-existing auto-logs) handled below
    esac
    case "$path" in
      docs/*|.harness/plans/*|.harness/verification/*|.harness/evidence/dmc-v0.6.0-verify.sh|.harness/decisions/dmc-v0.6.0-fugu-benchmark-card.md) : ;;
      *) p15=1 ;;
    esac
  done <<EOF
$st
EOF
  ok $p15 V15 "no protected-surface change; tracked changes in-scope"

  # ---- V16: no auto-log .harness/evidence/*.md staged ----
  git -C "$ROOT" diff --cached --name-only 2>/dev/null | grep -E '^\.harness/evidence/.*\.md$' >/dev/null 2>&1
  if [ $? -eq 0 ]; then ok 1 V16 "no .harness/evidence/*.md staged"; else ok 0 V16 "no .harness/evidence/*.md staged"; fi

  # ---- V17: verification report contains the architecture-guidance disclaimer ----
  grep -qF 'architecture guidance, not enforcement' "$REPORT" 2>/dev/null
  ok $? V17 "verification report carries 'architecture guidance, not enforcement'"
}

self_tests() {
  echo "  -- checker self-tests (negative controls) --"
  local t=0
  # the card counter must count headers
  printf '### Card 01 — x\n### Card 02 — y\n' | grep -cE '^### Card ' | grep -q '^2$' || { echo "  [FAIL] ST1 card-counter"; t=1; }
  # the decision validator must reject a bad decision value
  printf -- '- **Decision:** banana\n' | grep -qE '^- \*\*Decision:\*\*[[:space:]]+(adopt|adapt|reject|defer)[[:space:]]*$' && { echo "  [FAIL] ST2 decision-validator accepted bad value"; t=1; }
  # the secret regex must catch a synthetic non-secret-shaped placeholder
  printf 'AKIAABCDEFGHIJKLMNOP\n' | grep -EqI 'AKIA[0-9A-Z]{12,}' || { echo "  [FAIL] ST3 secret-regex miss"; t=1; }
  [ "$t" -eq 0 ] && echo "  [PASS] ST1-ST3 checker logic verified" || FAIL=$((FAIL+1))
  return $t
}

usage() {
  sed -n '2,16p' "$SELF_PATH" | sed 's/^# \{0,1\}//'
}

main() {
  local mode="${1:-}"
  case "$mode" in
    --verify)
      echo "DMC v0.6.0 structure verification (--verify) :: root=$ROOT"
      run_assertions
      echo "  ----"
      echo "  RESULT: $PASS PASS / $FAIL FAIL"
      [ "$FAIL" -eq 0 ] && exit 0 || exit 1
      ;;
    --self-test)
      echo "DMC v0.6.0 structure verification (--self-test) :: root=$ROOT"
      local h1 h2; h1=$(repo_hash)
      run_assertions
      self_tests || true
      h2=$(repo_hash)
      if [ "$h1" = "$h2" ]; then record PASS V18 "repo byte-unchanged after self-test (read-only)"; else record FAIL V18 "repo CHANGED during self-test"; fi
      echo "  ----"
      echo "  repo_hash(before)=$h1"
      echo "  repo_hash(after) =$h2"
      echo "  RESULT: $PASS PASS / $FAIL FAIL"
      [ "$FAIL" -eq 0 ] && exit 0 || exit 1
      ;;
    -h|--help|"")
      usage
      exit 0
      ;;
    *)
      echo "unknown flag: $mode"; usage; exit 2
      ;;
  esac
}

main "${1:-}"
