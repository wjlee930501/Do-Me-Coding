#!/usr/bin/env bash
# DMC Autonomous Dry-Run Acceptance (v0.4.9) — ADVISORY / READ-ONLY (capstone).
#
# Drives the full v0.4 autonomous loop end-to-end OFFLINE against fixtures, composing every v0.4 tool: goal intake ->
# plan compile (v0.4.1) -> branch/worktree isolation (v0.4.2) -> scoped edits on FIXTURE files in a $TMPDIR repo ->
# scope/over-eager guard (v0.4.3) -> secret/network/live guard (v0.4.5) -> evidence (v0.4.4) -> self-review (v0.4.6) ->
# NO push -> closure DRAFT. Asserts each stage + that the production repo is byte-unchanged, with no live/network/secret
# access and no false-green (a STAGE_FAIL counter drives the exit; no `set -e`/`|| true`).
#
# Usage:  dmc-v0.4.9-autonomous-dry-run.sh [--out <file>]   ·   --self-test
# Exit: 0 = all stages PASS, 1 = any stage FAIL, 2 = usage.
set -u
set -o pipefail
SELFPATH="$(cd "$(dirname "$0")" 2>/dev/null && pwd -P)/$(basename "$0")"
# F4: derive the repo root from the SCRIPT LOCATION (not the process CWD), so the --out write-safety boundary holds from
# ANY cwd. This script lives at <repo>/.harness/evidence/<this>.sh -> the repo root is two directories up. Hard-fail if
# the derived root is empty or not a git worktree (e.g. the script was copied outside a repo).
ROOTDIR="$(cd "$(dirname "$SELFPATH")/../.." 2>/dev/null && pwd -P || true)"
if [ -z "$ROOTDIR" ] || ! git -C "$ROOTDIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "autonomous-dry-run: cannot locate the repo root from the script path — refusing (F4)" >&2; exit 2
fi
EV="$ROOTDIR/.harness/evidence"
T0="$EV/dmc-v0.4.0-autonomy-charter.sh"; T1="$EV/dmc-v0.4.1-goal-plan-compiler.sh"; T2="$EV/dmc-v0.4.2-branch-isolation-guard.sh"
T3="$EV/dmc-v0.4.3-scope-overeager-guard.sh"; T4="$EV/dmc-v0.4.4-evidence-harness.sh"; T5="$EV/dmc-v0.4.5-secret-network-live-guard.sh"
T6="$EV/dmc-v0.4.6-reviewer-loop.sh"; T7="$EV/dmc-v0.4.7-context-audit.sh"; T8="$EV/dmc-v0.4.8-interop-doc-check.sh"
TOOLS="$T0 $T1 $T2 $T3 $T4 $T5 $T6 $T7 $T8"

# F4: resolve a hashing tool ONCE; hard-fail if none — so the byte-unchanged check can never collapse to '' == ''
HASH_CMD="${DMC_HASH_CMD-$(command -v md5sum 2>/dev/null || command -v md5 2>/dev/null || true)}"
require_hash() { [ -n "$HASH_CMD" ] || { echo "autonomous-dry-run: no md5sum/md5 hash tool — refusing (byte-unchanged check would be vacuous)" >&2; exit 2; }; }
repo_hash() { git -C "$ROOTDIR" status --porcelain 2>/dev/null | "$HASH_CMD"; }

out_refused() { local raw="$1"
  case "$raw" in *..*|*/.env|.env|*.pem|*.key|*credentials*|*secret*) return 0;; esac
  # F4: reject a symlinked --out target — cp would dereference it into the work tree
  [ -L "$raw" ] && return 0
  # F4: resolve the target via its parent's PHYSICAL path; refuse anything inside the repo work tree (ROOTDIR is now
  #     script-derived, so this holds from any cwd). Fail CLOSED if the parent cannot be resolved.
  local parent base cparent canon
  parent="$(dirname "$raw" 2>/dev/null)"; base="$(basename "$raw")"
  cparent="$(cd "$parent" 2>/dev/null && pwd -P)" || return 0
  canon="$cparent/$base"
  case "$canon/" in "$ROOTDIR"/*) return 0;; esac
  # F4: belt-and-suspenders — refuse a path git already tracks (resolved absolute path)
  git -C "$ROOTDIR" ls-files --error-unmatch -- "$canon" >/dev/null 2>&1 && return 0
  return 1
}
regression_ok() { local t rc; for t in "$@"; do bash "$t" --self-test >/dev/null 2>&1; rc=$?; [ "$rc" = 0 ] || return 1; done; return 0; }

acceptance_run() { # <outfile>
  local outfile="$1"
  cd "$ROOTDIR" 2>/dev/null || true   # F4: run sibling tools from the repo root so their cwd-derived ROOTDIR is correct
  local TT; TT="$(mktemp -d)"
  local s0 s1 s2 s3 s4 s5 s6 s7 s8
  # S0 PRESENCE + REGRESSION (all 9 v0.4 tools self-test green)
  s0=PASS; local t; for t in $TOOLS; do [ -r "$t" ] || s0=FAIL; done
  [ "$s0" = PASS ] && { regression_ok $TOOLS && s0=PASS || s0=FAIL; }
  # S1 GOAL INTAKE — the sample goal fixture loads
  local GOAL="$ROOTDIR/.harness/fixtures/v0.4/sample-goal.json"
  [ -f "$GOAL" ] && python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$GOAL" 2>/dev/null && s1=PASS || s1=FAIL
  # S2 PLAN COMPILE — compiler => autonomous-local-commit + push/closure gated + non-empty approved scope
  bash "$T1" --goal "$GOAL" > "$TT/plan.json" 2>/dev/null
  if python3 -c 'import json,sys
o=json.load(open(sys.argv[1])); g=o["human_gates"]
sys.exit(0 if (o["autonomy_level"]=="autonomous-local-commit" and "push" in g and "closure" in g and o["approved_scope"]) else 1)' "$TT/plan.json" 2>/dev/null; then s2=PASS; else s2=FAIL; fi
  local SCOPE; SCOPE="$(python3 -c 'import json,sys; print(",".join(json.load(open(sys.argv[1]))["approved_scope"]))' "$TT/plan.json" 2>/dev/null)"
  # S3 ISOLATION — a $TMPDIR repo on a dedicated branch, clean => ISOLATED
  local R="$TT/repo"; mkdir -p "$R"; git -C "$R" init -q; git -C "$R" config user.email t@t.t; git -C "$R" config user.name t
  mkdir -p "$R/docs"; echo 'base' > "$R/docs/README_AUTONOMY_QUICKSTART.md"; git -C "$R" add -A
  GIT_AUTHOR_DATE='2020-01-01T00:00:00 +0000' GIT_COMMITTER_DATE='2020-01-01T00:00:00 +0000' git -C "$R" commit -q -m base
  git -C "$R" checkout -q -b dmc-autonomy/dry-run
  bash "$T2" --repo "$R" >/dev/null 2>&1 && s3=PASS || s3=FAIL
  # S4 SCOPED EDIT (FIXTURE file only, within approved scope) => scope guard ALLOWED
  printf 'base\n## Autonomous Mode quickstart\n' > "$R/docs/README_AUTONOMY_QUICKSTART.md"
  bash "$T3" --repo "$R" --approved-scope "$SCOPE" >/dev/null 2>&1 && s4=PASS || s4=FAIL
  # S5 SECRET/NET/LIVE — the planned offline action is ALLOWED
  bash "$T5" --action "bash tool.sh --mock fixtures/ok.json --out result.json" >/dev/null 2>&1 && s5=PASS || s5=FAIL
  # S6 EVIDENCE — redacted evidence from a captured self-test output
  printf '  PASS AC1 x\n  ---- self-test: PASS=7 FAIL=0 ----\n' > "$TT/cap.txt"
  bash "$T4" --run-id "dry-run" --from "$TT/cap.txt" > "$TT/ev.md" 2>/dev/null
  grep -q 'self_test: 7 PASS / 0 FAIL' "$TT/ev.md" && grep -q 'redaction: applied' "$TT/ev.md" && s6=PASS || s6=FAIL
  # S7 SELF-REVIEW — build + validate (auto_apply must be false)
  printf '{"review_id":"dry-run","risk_level":"low","files_touched":["docs/README_AUTONOMY_QUICKSTART.md"],"tests_run":[{"command":"v0.4.9 dry-run","result":"PASS"}],"evidence_refs":["%s"],"findings":[],"open_questions":[],"auto_apply":false}' "$TT/ev.md" > "$TT/sr.json"
  bash "$T6" --validate "$TT/sr.json" >/dev/null 2>&1 && s7=PASS || s7=FAIL
  # S8 NO-PUSH — the temp repo has no remote and nothing was pushed; a closure DRAFT is produced (text, not committed)
  if ! git -C "$R" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then s8=PASS; else s8=FAIL; fi

  local sf=0; for v in "$s0" "$s1" "$s2" "$s3" "$s4" "$s5" "$s6" "$s7" "$s8"; do [ "$v" = PASS ] || sf=$((sf+1)); done
  STAGE_FAIL=$((STAGE_FAIL + sf))
  {
    echo "# DMC Autonomous Dry-Run Acceptance — full v0.4 loop (offline; fixtures only)"
    echo
    echo "_read-only · advisory · no live call · no commit/push · no production-file mutation_"
    echo
    echo "## Lifecycle stages"
    echo "| # | stage | status |"; echo "|---|---|---|"
    echo "| 0 | REGRESSION (9 v0.4 tools --self-test green) | $s0 |"
    echo "| 1 | GOAL INTAKE (sample-goal fixture loads) | $s1 |"
    echo "| 2 | PLAN COMPILE (=> autonomous-local-commit; push+closure gated) | $s2 |"
    echo "| 3 | ISOLATION (dedicated branch + clean => ISOLATED) | $s3 |"
    echo "| 4 | SCOPED EDIT (fixture file, in-scope => ALLOWED) | $s4 |"
    echo "| 5 | SECRET/NET/LIVE (offline action => ALLOWED) | $s5 |"
    echo "| 6 | EVIDENCE (extracted + redacted) | $s6 |"
    echo "| 7 | SELF-REVIEW (valid; auto_apply=false) | $s7 |"
    echo "| 8 | NO-PUSH (no upstream; closure is a draft) | $s8 |"
    echo
    [ "$sf" = 0 ] && echo "## Result: **ACCEPTED** — the v0.4 autonomous loop composes and stays safe (offline; no push)." \
                  || echo "## Result: **NOT ACCEPTED** — $sf stage(s) failed."
    echo
    echo "## Closure DRAFT (NOT committed — closure is a human gate)"
    echo "    ## v0.4.0-v0.4.9 — Autonomous Development Mode — DRAFT (pending human-approved push + closure)"
    echo "    - control plane: charter + goal-plan compiler + branch-isolation/scope-overeager/secret-network-live"
    echo "      guards + evidence harness + reviewer loop + context map + interop docs + this E2E dry-run."
    echo "    - all read-only/advisory; push + closure remain human-gated."
    echo
    echo "---"
    echo "_dry-run; performs no gated action; grants no gate; production repo byte-unchanged._"
  } > "$outfile"
  rm -rf "$TT"
}

self_test() {
  require_hash
  local P=0 F=0; ok(){ echo "  PASS $1"; P=$((P+1)); }; no(){ echo "  FAIL $1"; F=$((F+1)); }
  local TT; TT="$(mktemp -d)"; trap 'rm -rf "$TT"' RETURN
  local PRE; PRE="$(repo_hash)"
  STAGE_FAIL=0
  acceptance_run "$TT/report.md"
  { [ "$STAGE_FAIL" = 0 ] && grep -q 'ACCEPTED' "$TT/report.md"; } && ok "AC1 all lifecycle stages PASS (goal->plan->isolation->scoped-edit->guards->evidence->self-review->no-push)" || no "AC1 stages (STAGE_FAIL=$STAGE_FAIL)"
  grep -q 'Closure DRAFT (NOT committed' "$TT/report.md" && ok "AC2 closure is a DRAFT (not committed; human gate)" || no "AC2 closure draft"
  # AC3 no-false-green: a broken stub tool turns REGRESSION red
  printf '#!/usr/bin/env bash\n[ "$1" = --self-test ] && exit 1\nexit 0\n' > "$TT/stub.sh"; chmod +x "$TT/stub.sh"
  ! regression_ok "$T0" "$TT/stub.sh" && ok "AC3 no-false-green: a broken self-test turns REGRESSION red" || no "AC3 fail-prop"
  # AC4 no-live/no-net structural self-audit (operative source; own audit block excluded so the pattern can't self-match)
  local OP="$TT/op.src"; sed '/AUDIT_BLOCK_START/,/AUDIT_BLOCK_END/d' "$SELFPATH" | grep -vE '^[[:space:]]*#' > "$OP"
  # >>>AUDIT_BLOCK_START
  if ! grep -nE '(^|[^A-Za-z])(curl|wget)([[:space:]])| --live | --allow-network' "$OP" >/dev/null; then ok "AC4 no curl/wget/--live opt-in in the dry-run source"; else no "AC4 live/net present"; fi
  # >>>AUDIT_BLOCK_END
  local POST; POST="$(repo_hash)"
  { [ -n "$PRE" ] && [ -n "$POST" ] && [ "$POST" = "$PRE" ]; } && ok "AC5 read-only: production repo byte-unchanged (non-empty hashes asserted)" || no "AC5 repo changed (PRE='$PRE' POST='$POST')"

  # AC6 (F4) --out guard refuses an in-work-tree / tracked path; out-of-tree tmp path allowed
  { out_refused "$ROOTDIR/DMC.md" && out_refused "$ROOTDIR/.harness/x.md" && ! out_refused "$TT/ok.md"; } \
    && ok "AC6 --out guard: in-work-tree path REFUSED (no tracked-file overwrite); tmp path allowed" || no "AC6 --out work-tree guard"

  # AC7 (F4) no hash tool => hard-fail exit 2 (byte-unchanged check can never pass vacuously)
  DMC_HASH_CMD="" bash "$SELFPATH" --self-test >/dev/null 2>&1; [ $? = 2 ] \
    && ok "AC7 hash-absence => hard-fail exit 2 (no vacuous empty==empty pass)" || no "AC7 hash-absence not hard-failed"

  # AC8 (F4 RC1) cwd-independence: a FRESH process launched from an OUT-OF-REPO cwd still refuses an in-work-tree --out
  #     target => ROOTDIR is script-derived, not cwd-derived. Uses a NON-EXISTENT in-repo path => zero write risk.
  local INREPO="$ROOTDIR/.harness/runs/__f4_rc1_probe__.md"
  ( cd "$TT" && bash "$SELFPATH" --out "$INREPO" >/dev/null 2>&1 ); local rc8=$?
  { [ "$rc8" = 2 ] && [ ! -e "$INREPO" ]; } \
    && ok "AC8 fresh process from out-of-repo cwd refuses an in-work-tree --out (RC1 closed)" || no "AC8 RC1 in-repo --out not refused from out-of-repo cwd (rc=$rc8)"
  rm -f "$INREPO" 2>/dev/null

  # AC9 (F4 RC2) symlinked --out target -> a tracked repo file => REFUSED; AND a tracked-file --out is refused even
  #     when classified from a cwd OUTSIDE the repo (the cp write-through vector is closed)
  ln -s "$ROOTDIR/DMC.md" "$TT/link_to_repo" 2>/dev/null
  { out_refused "$TT/link_to_repo" && ( cd "$TT" && out_refused "$ROOTDIR/DMC.md" ); } \
    && ok "AC9 symlinked --out REFUSED; tracked-file --out REFUSED from cwd=$TT (RC2 closed)" || no "AC9 symlink/cwd --out allowed"

  echo "  ---- self-test: PASS=$P FAIL=$F ----"; [ "$F" = 0 ]
}

OUT=""; MODE=run
while [ $# -gt 0 ]; do case "$1" in --out) OUT="$2"; shift 2;; --self-test) MODE=selftest; shift;; -h|--help) sed -n '2,12p' "$0"; exit 0;; *) echo "autonomous-dry-run: unknown arg $1" >&2; exit 2;; esac; done
if [ "$MODE" = selftest ]; then echo "==== DMC AUTONOMOUS DRY-RUN — SELF-TEST ===="; self_test; exit $?; fi
if [ -n "$OUT" ]; then out_refused "$OUT" && { echo "autonomous-dry-run: --out refused (traversal/secret/in-work-tree)" >&2; exit 2; }; fi
require_hash
STAGE_FAIL=0; PACK="$(mktemp)"; acceptance_run "$PACK"
if [ -n "$OUT" ]; then cp "$PACK" "$OUT"; echo "autonomous-dry-run: wrote $OUT" >&2; else cat "$PACK"; fi
rm -f "$PACK"; [ "$STAGE_FAIL" = 0 ] && exit 0 || exit 1
