#!/usr/bin/env bash
# DMC E2E Dry-Run Acceptance Suite (v0.3.9) — ADVISORY / READ-ONLY (capstone).
#
# Drives the entire DMC rails loop end-to-end in a single OFFLINE dry-run: task-intake (v0.2.8) -> provider selection
# (v0.3.4) -> execution manifest (v0.3.5) -> review packet (v0.3.6) -> closure judgment (v0.3.7) -> delegation compliance
# (v0.3.8), plus the gate-check (v0.2.6). It asserts each stage's output, that the stages COMPOSE (selector rank-1 ==
# manifest proposed target), and that every rail's --self-test is green — with NO live call, NO network, NO commit/push,
# NO real-repo mutation, NO secret content, and NO false-green (a broken rail turns the suite red).
#
# NOTE: deliberately NO `set -e` — an explicit STAGE_FAIL counter drives the exit (no implicit error-exit / no `|| true`).
#
# Usage:  e2e-dry-run.sh [--repo <dir>] [--out <file>]   (emits the acceptance report)
#         e2e-dry-run.sh --self-test                       (full acceptance + AC meta-fixtures)
# Exit: 0 = all stages PASS, 1 = any stage FAIL, 2 = usage/refused.
set -u
set -o pipefail
export PYTHONDONTWRITEBYTECODE=1

ROOTDIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SELFPATH="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/$(basename "$0")"
EV="$ROOTDIR/.harness/evidence"
T26="$EV/dmc-v0.2.6-gate-check-runner.sh"; T28="$EV/dmc-v0.2.8-task-intake-classifier.sh"
T34="$EV/dmc-v0.3.4-provider-selector.sh"; T35="$EV/dmc-v0.3.5-execution-manifest.sh"
T36="$EV/dmc-v0.3.6-review-packet.sh"; T37="$EV/dmc-v0.3.7-closure-controller.sh"; T38="$EV/dmc-v0.3.8-delegation-harness.sh"
TOOLS="$T26 $T28 $T34 $T35 $T36 $T37 $T38"

# --- --out write-target guard (v0.3.4–v0.3.8 hardened) ---
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

# --- fail-propagation helpers (also used as AC4 negative meta-fixtures) ---
regression_ok() { local t rc; for t in "$@"; do bash "$t" --self-test >/dev/null 2>&1; rc=$?; [ "$rc" = 0 ] || return 1; done; return 0; }
compose_ok() { # <sel.json> <man.json> -> 0 iff proposed non-null, NOT fail_closed, ==selector rank-1
  python3 - "$1" "$2" <<'PY'
import json,sys
try: s=json.load(open(sys.argv[1])); m=json.load(open(sys.argv[2]))
except Exception: sys.exit(1)
if m.get("fail_closed"): sys.exit(1)
p=m.get("proposed_provider_target")
if not p: sys.exit(1)
c=s.get("provider_candidates",[])
if not c: sys.exit(1)
top=sorted(c,key=lambda x:x.get("rank",99))[0]
sys.exit(0 if (p.get("type")==top.get("type") and p.get("provider")==top.get("provider")) else 1)
PY
}

# --- build the $TMPDIR synthetic fixtures + temp repo (origin/main BEHIND HEAD) ---
mk_fixtures() { # <dir>
  local d="$1"
  printf '%s' '{"task_id":"e2e-1","objective":"update the README onboarding docs for clarity","context_summary":"docs-only pass"}' > "$d/task.json"
  printf '%s\n' '# Verification Report' 'Review-Verdict: critic=PASS codex=ACCEPT' '| x | 9 PASS / 0 FAIL |' '## Final Status' '**PASS** — green' > "$d/rep.md"
  printf '%s\n' 'Status: APPROVED' 'Approval Status: APPROVED' > "$d/plan.md"
  printf '%s\n' '## dmc-e2e — recorded' > "$d/ms.md"
  local R="$d/repo"; mkdir -p "$R/src"; git -C "$R" init -q; git -C "$R" config user.email t@t.t; git -C "$R" config user.name t
  echo 'console.log(1)' > "$R/src/app.js"; git -C "$R" add -A
  GIT_AUTHOR_DATE='2020-01-01T00:00:00 +0000' GIT_COMMITTER_DATE='2020-01-01T00:00:00 +0000' git -C "$R" commit -q -m c1
  local C1; C1="$(git -C "$R" rev-parse HEAD)"
  echo 'console.log(2)' > "$R/src/app.js"; git -C "$R" add -A
  GIT_AUTHOR_DATE='2020-01-02T00:00:00 +0000' GIT_COMMITTER_DATE='2020-01-02T00:00:00 +0000' git -C "$R" commit -q -m c2
  git -C "$R" update-ref refs/remotes/origin/main "$C1"   # origin/main BEHIND HEAD
}

# --- run stages 0-8; populate STAGE_FAIL; emit the acceptance report to <outfile> ---
acceptance_run() { # <outfile>
  local outfile="$1"
  local TT; TT="$(mktemp -d)"; mk_fixtures "$TT"; local R="$TT/repo"
  local s0 s1 s2 s3 s4 s5 s6 s7
  # S0 PRESENCE
  s0=PASS; local t; for t in $TOOLS; do [ -r "$t" ] || s0=FAIL; done
  # S1 REGRESSION (per-tool rc AND, no masking)
  if [ "$s0" = PASS ] && regression_ok $TOOLS; then s1=PASS; else s1=FAIL; fi
  # S2 INTAKE
  local desc; desc="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["objective"])' "$TT/task.json" 2>/dev/null)"
  bash "$T28" --task "$desc" --out "$TT/intake.json" >/dev/null 2>&1
  if python3 -c 'import json,sys; o=json.load(open(sys.argv[1])); sys.exit(0 if (o["dimensions"] and o["stop_and_ask"] is False) else 1)' "$TT/intake.json" 2>/dev/null; then s2=PASS; else s2=FAIL; fi
  # S3 SELECT
  bash "$T34" --task "$TT/task.json" > "$TT/sel.json" 2>/dev/null
  if python3 -c 'import json,sys; o=json.load(open(sys.argv[1])); c={x["provider"]:x for x in o["provider_candidates"]}; sys.exit(0 if (len(o["provider_candidates"])==3 and c["manual-import"]["rank"]==1 and not o.get("fail_closed")) else 1)' "$TT/sel.json" 2>/dev/null; then s3=PASS; else s3=FAIL; fi
  # S4 MANIFEST (positive compose invariant — NOT the manifest exit code)
  bash "$T35" --task "$TT/task.json" > "$TT/man.json" 2>/dev/null
  if compose_ok "$TT/sel.json" "$TT/man.json" \
     && python3 -c 'import json,sys; m=json.load(open(sys.argv[1])); a=m.get("selected_adapter") or ""; cc=m.get("closure_criteria",[]); sys.exit(0 if (a.endswith("manual-import/manual-import-adapter.py") and len(cc)==5) else 1)' "$TT/man.json" 2>/dev/null; then s4=PASS; else s4=FAIL; fi
  # S5 REVIEW (--repo tmp; clean changeset => forbidden none)
  bash "$T36" --repo "$R" --commit HEAD --verify-report "$TT/rep.md" > "$TT/review.md" 2>/dev/null
  if grep -q '## 1. Changeset summary' "$TT/review.md" && grep -q '## 5. Residual risks' "$TT/review.md" \
     && awk '/## 3\./{s=1} /## 4\./{s=0} s' "$TT/review.md" | grep -q '^none$'; then s5=PASS; else s5=FAIL; fi
  # S6 CLOSURE (--repo tmp; assert on EMITTED OUTPUT, not exit code)
  bash "$T37" --repo "$R" --milestone dmc-e2e --commit HEAD --verify-report "$TT/rep.md" --milestones-file "$TT/ms.md" > "$TT/closure.md" 2>/dev/null
  if grep -q '## Closure conditions' "$TT/closure.md" && grep -q 'closure-entry CANDIDATE' "$TT/closure.md"; then s6=PASS; else s6=FAIL; fi
  # S7 DELEGATION (--repo tmp; origin/main behind HEAD => push DEFERRED => AUTONOMY-COMPLIANT)
  bash "$T38" --repo "$R" --milestone dmc-e2e --plan "$TT/plan.md" --verify-report "$TT/rep.md" --commit HEAD > "$TT/deleg.md" 2>/dev/null
  if grep -q 'AUTONOMY-COMPLIANT' "$TT/deleg.md" && grep -q 'DEFERRED' "$TT/deleg.md"; then s7=PASS; else s7=FAIL; fi

  local sf=0; for v in "$s0" "$s1" "$s2" "$s3" "$s4" "$s5" "$s6" "$s7"; do [ "$v" = PASS ] || sf=$((sf+1)); done
  STAGE_FAIL=$((STAGE_FAIL + sf))

  {
    echo "# DMC E2E Dry-Run Acceptance — full rails loop (offline)"
    echo
    echo "_read-only · advisory · no live call · no commit/push · no real-repo mutation · no secret content_"
    echo
    echo "## Loop stages"
    echo "| # | stage | status |"
    echo "|---|---|---|"
    echo "| 0 | PRESENCE (7 rails tools present) | $s0 |"
    echo "| 1 | REGRESSION (7 tools --self-test green) | $s1 |"
    echo "| 2 | INTAKE (classifier: docs-only ⇒ stop_and_ask=false) | $s2 |"
    echo "| 3 | SELECT (3 candidates; manual_import rank 1) | $s3 |"
    echo "| 4 | MANIFEST (compose: selector rank-1 == proposed target) | $s4 |"
    echo "| 5 | REVIEW (5 sections; forbidden=none) | $s5 |"
    echo "| 6 | CLOSURE (5-condition table + candidate emitted) | $s6 |"
    echo "| 7 | DELEGATION (AUTONOMY-COMPLIANT; push DEFERRED) | $s7 |"
    echo
    if [ "$sf" = 0 ]; then echo "## Result: **ACCEPTED** — the full read-only rails loop composes and stays safe."
    else echo "## Result: **NOT ACCEPTED** — $sf stage(s) failed."; fi
    echo
    echo "## Safety attestation"
    echo "- composed only offline tool modes; no live/network/exec opt-in flag reached any tool; no network."
    echo "- all git writes confined to \$TMPDIR; the real repo is byte-unchanged."
    echo "- only synthetic non-secret fixtures; the composed tools' secret-path guards stay in force."
    echo
    echo "---"
    echo "_read-only/advisory; dry-run; performs no gated action; grants no gate._"
  } > "$outfile"
  rm -rf "$TT"
}

# ---------------------------------------------------------------- self-test (full acceptance + AC meta-fixtures)
self_test() {
  local P=0 F=0; ok(){ echo "  PASS $1"; P=$((P+1)); }; no(){ echo "  FAIL $1"; F=$((F+1)); }
  local TT; TT="$(mktemp -d)"; trap 'rm -rf "$TT"' RETURN
  # AC1 pre-snapshot
  local RH RB RC RP; RH="$(git -C "$ROOTDIR" rev-parse HEAD)"; RB="$(git -C "$ROOTDIR" rev-parse --abbrev-ref HEAD)"
  RC="$(git -C "$ROOTDIR" config --list | md5)"; RP="$(git -C "$ROOTDIR" status --porcelain | md5)"

  # AC2 — run the full acceptance; every stage must PASS (STAGE_FAIL stays 0)
  STAGE_FAIL=0
  acceptance_run "$TT/report.md"
  [ "$STAGE_FAIL" = 0 ] && grep -q 'ACCEPTED' "$TT/report.md" && ok "AC2 all stages PASS (loop composes: PRESENCE/REGRESSION/INTAKE/SELECT/MANIFEST/REVIEW/CLOSURE/DELEGATION)" || no "AC2 stages (STAGE_FAIL=$STAGE_FAIL)"

  # AC4 — no false-green: negative meta-fixtures
  cat > "$TT/stub.sh" <<'PY'
#!/usr/bin/env bash
[ "$1" = --self-test ] && exit 1
exit 0
PY
  chmod +x "$TT/stub.sh"
  mk_fixtures "$TT"   # for a real sel.json to pair against the bad manifest
  bash "$T34" --task "$TT/task.json" > "$TT/sel.json" 2>/dev/null
  printf '%s' '{"proposed_provider_target":null,"fail_closed":true,"provider_candidates":[]}' > "$TT/man_bad.json"
  if ! regression_ok "$T28" "$TT/stub.sh" && ! compose_ok "$TT/sel.json" "$TT/man_bad.json"; then
    ok "AC4 no false-green: stub self-test(exit 1)=>REGRESSION red; manifest proposed=null=>compose FAILs"
  else no "AC4 fail-propagation"; fi

  # AC3 + AC5 + no-git-write — structural audit (operative source ONLY; own block + comments excluded)
  local OP="$TT/op.src"; sed '/AUDIT_BLOCK_START/,/AUDIT_BLOCK_END/d' "$SELFPATH" | grep -vE '^[[:space:]]*#' > "$OP"
  # >>>AUDIT_BLOCK_START
  local sa=1
  # AC3 no-live: the suite passes no live flag to any tool
  grep -nE '\-\-live|\-\-allow-network|\-\-allow-exec' "$OP" >/dev/null && sa=0
  # AC5 no-secret: v0.3.7 enumerated content-dumping set
  grep -nE 'format-patch|cat-file|diff-tree' "$OP" >/dev/null && sa=0
  grep -nE '(show|log|diff)[^|]* (-p|--patch)( |$)' "$OP" >/dev/null && sa=0
  grep -n '%b' "$OP" >/dev/null && sa=0
  grep -nE 'git( -C [^ ]+| -C "[^"]+")? +show' "$OP" | grep -vE -- '-s|--name-status|--numstat|--stat|--name-only' >/dev/null && sa=0
  grep -nE 'os\.environ|os\.getenv|getenv\(' "$OP" >/dev/null && sa=0
  grep -nE '\$\{?(GLM_API_KEY|DMC_OAUTHCLI_BIN|ANTHROPIC_API_KEY|OPENAI_API_KEY|ZHIPUAI_API_KEY)' "$OP" >/dev/null && sa=0
  # no real-repo git write: every add|commit|update-ref is -C <tmp>; NO push anywhere
  grep -nE 'git (add|commit|update-ref)' "$OP" | grep -vE 'git -C' >/dev/null && sa=0
  grep -nE 'git( -C [^ ]+| -C "[^"]+")? +push' "$OP" >/dev/null && sa=0
  [ "$sa" = 1 ] && ok "AC3/AC5 STRUCTURAL: no --live; no content-dumping git/%b/cred-read; no real-repo git write; no push" || no "AC3/AC5 STRUCTURAL"
  # >>>AUDIT_BLOCK_END

  # AC6 — --out guard
  mkdir -p "$TT/sub"
  out_refused "$TT/sub/../benign.json" && out_refused ".env" && out_refused ".claude/hooks/x" && out_refused "provider-router.py" \
    && { ln -sf "$ROOTDIR/.claude/hooks" "$TT/sub/hooks" 2>/dev/null; out_refused "$TT/sub/hooks/x"; } \
    && ! out_refused "$TT/benign.json" && ok "AC6 --out guard: benign-.. + protected/secret/symlink refused, benign allowed" || no "AC6 --out guard"

  # AC1 FINAL — the real repo is byte-unchanged across the whole suite (POST after all stages + the --out write)
  local rh rb rc2 rp; rh="$(git -C "$ROOTDIR" rev-parse HEAD)"; rb="$(git -C "$ROOTDIR" rev-parse --abbrev-ref HEAD)"; rc2="$(git -C "$ROOTDIR" config --list | md5)"; rp="$(git -C "$ROOTDIR" status --porcelain | md5)"
  { [ "$RH" = "$rh" ] && [ "$RB" = "$rb" ] && [ "$RC" = "$rc2" ] && [ "$RP" = "$rp" ]; } && ok "AC1 read-only: real repo HEAD/branch/config/porcelain pre==post (no mutation)" || no "AC1 read-only: real repo changed"

  echo "  ---- self-test: PASS=$P FAIL=$F ----"; [ "$F" = 0 ]
}

# --- args ---
REPO=""; OUT=""; MODE=run
while [ $# -gt 0 ]; do case "$1" in
  --repo) REPO="$2"; shift 2;; --out) OUT="$2"; shift 2;; --self-test) MODE=selftest; shift;;
  -h|--help) sed -n '2,20p' "$0"; exit 0;; *) echo "e2e-dry-run: unknown arg $1" >&2; exit 2;;
esac; done

if [ "$MODE" = selftest ]; then
  echo "==== DMC E2E DRY-RUN ACCEPTANCE — SELF-TEST (no in-repo writes; \$TMPDIR only) ===="
  self_test; exit $?
fi

if [ -n "$OUT" ]; then
  if out_refused "$OUT"; then echo "e2e-dry-run: --out target is a protected/secret path — REFUSED" >&2; exit 2; fi
fi
STAGE_FAIL=0
PACK="$(mktemp)"; acceptance_run "$PACK"
if [ -n "$OUT" ]; then cp "$PACK" "$OUT"; echo "e2e-dry-run: wrote $OUT" >&2; else cat "$PACK"; fi
rm -f "$PACK"
[ "$STAGE_FAIL" = 0 ] && exit 0 || exit 1
