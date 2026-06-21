#!/usr/bin/env bash
# DMC E2E Completion Controller (v0.3.0) — REPORT-ONLY / READ-ONLY.
#
# Reports whether a milestone satisfies E2E-done (verified · reviewed · committed · pushed · closure-recorded) as
# done | in-progress | blocked. FAIL-CLOSED: any criterion that cannot be evaluated => blocked (never silently done).
# It reports only — never approves/stages/commits/pushes/grants a gate; offline (no git fetch); no live/model-API call;
# no .env*/credential read. The only write is a canonicalization-guarded --out file (never git add'ed).
#
# Usage:  dmc-v0.3.0-e2e-completion.sh --milestone <id> [--commit <hash>] [--branch <b>] [--repo <dir>] [--out <file>]
#         dmc-v0.3.0-e2e-completion.sh --self-test
# Exit: 0 done / 1 in-progress|blocked / 2 usage|refused. (Advisory — never wire to perform a gate.)
set -u
set -o pipefail

# --- --out write-target guard (canonicalized; reused from v0.2.8) ---
PROT_RE='(^|/)(\.env)(\.|$)|\.pem$|\.key$|id_rsa|id_ed25519|credentials|secret|\.p12$|\.pfx$|\.keystore$|\.claude/hooks|provider-router\.py|/ROUTING\.md$|WORKER_(TASK|RESULT|REVIEW)_SCHEMA\.md|PROVIDER_CONTRACT\.md|workers/providers/(glm-api|oauth-cli)|(^|/)dmc-glm-smoke$'
out_refused() { local raw="$1" parent base cparent canon
  printf '%s' "$raw" | grep -qiE "$PROT_RE" && return 0
  case "$raw" in *.env|*.env.*) case "$raw" in *.example|*.sample|*.template) ;; *) return 0;; esac;; esac
  parent="$(dirname "$raw")"; base="$(basename "$raw")"
  cparent="$(cd "$parent" 2>/dev/null && pwd -P)" || return 0
  canon="$cparent/$base"; printf '%s' "$canon" | grep -qiE "$PROT_RE" && return 0
  if [ -L "$raw" ]; then local t; t="$(readlink -f "$raw" 2>/dev/null)" || return 0; printf '%s' "$t" | grep -qiE "$PROT_RE" && return 0; fi
  return 1
}

rp(){ git -C "$1" rev-parse --verify --quiet "$2^{commit}" 2>/dev/null; }   # canonical full hash or empty

# evaluate <repo> <ms> <commit_arg> <branch_arg> -> sets V R C P CL OVERALL HEAD AHEAD BEHIND COMMIT_FULL
evaluate() {
  local repo="$1" ms="$2" carg="$3" barg="$4"
  local vrep plan branch
  branch="${barg:-main}"
  # verified
  vrep="$(ls "$repo"/.harness/verification/*"$ms"*.md 2>/dev/null | head -1)"
  if [ -z "$vrep" ]; then V=blocked
  elif grep -qiE 'Final Status\**:? *\**PASS|RESULT: ALL PASS|^\*\*PASS\*\*' "$vrep"; then V=met
  else V=unmet; fi
  # reviewed: canonical anchored verdict line + APPROVED plan
  plan="$(ls "$repo"/.harness/plans/*"$ms"*.md 2>/dev/null | head -1)"
  if [ -n "$vrep" ] && grep -qE '^Review-Verdict: critic=PASS codex=ACCEPT' "$vrep" \
       && [ -n "$plan" ] && grep -qE '^Status: APPROVED' "$plan"; then R=met
  else R=blocked; fi   # loose/mock/prose/missing canonical line => cannot confirm => blocked
  # committed
  COMMIT_FULL=""
  if [ -n "$carg" ]; then
    COMMIT_FULL="$(rp "$repo" "$carg")"; [ -n "$COMMIT_FULL" ] && C=met || C=blocked
  else
    local hits n; hits="$(git -C "$repo" log --grep="$ms" --format='%H' 2>/dev/null)"; n="$(printf '%s' "$hits" | grep -c .)"
    if [ "$n" = 1 ]; then COMMIT_FULL="$hits"; C=met; else C=blocked; fi   # 0 or >1 => blocked
  fi
  # pushed (offline; resolved origin/<branch>; cascade on committed-blocked)
  AHEAD=0; BEHIND=0
  if [ "$C" != met ]; then P=blocked
  elif ! rp "$repo" "origin/$branch" >/dev/null; then P=blocked   # unresolvable origin ref
  else
    if git -C "$repo" merge-base --is-ancestor "$COMMIT_FULL" "origin/$branch" 2>/dev/null; then P=met; else P=unmet; fi
    local lr; lr="$(git -C "$repo" rev-list --left-right --count "origin/$branch"...HEAD 2>/dev/null || echo '0	0')"
    BEHIND="${lr%%[	 ]*}"; AHEAD="${lr##*[	 ]}"
  fi
  # closure-recorded
  local mfile="$repo/docs/MILESTONES.md"
  if [ "$C" != met ]; then CL=blocked
  elif [ ! -r "$mfile" ]; then CL=blocked   # absent/unreadable => blocked
  else
    CL=unmet
    # extract the milestone's section (heading containing its version token, or the id) -> next "## " heading
    local ver key block tok
    ver="$(printf '%s' "$ms" | grep -oE 'v?[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)"
    for key in "$ver" "$ms"; do
      [ -z "$key" ] && continue
      block="$(awk -v k="$key" 'BEGIN{IGNORECASE=1}/^## /{inb=(index(tolower($0),tolower(k))>0)} inb' "$mfile")"
      [ -n "$block" ] || continue
      for tok in $(printf '%s' "$block" | grep -oE '[0-9a-f]{7,40}' | sort -u); do
        local f; f="$(rp "$repo" "$tok")"; [ "$f" = "$COMMIT_FULL" ] && { CL=met; break 2; }
      done
    done
  fi
  HEAD="$(git -C "$repo" rev-parse --short HEAD 2>/dev/null || echo none)"
  # overall (fail-closed precedence)
  if printf '%s\n' "$V" "$R" "$C" "$P" "$CL" | grep -q blocked; then OVERALL=blocked
  elif printf '%s\n' "$V" "$R" "$C" "$P" "$CL" | grep -q unmet; then OVERALL=in-progress
  else OVERALL=done; fi
}

emit() {
  local missing=""
  for kv in "verified:$V" "reviewed:$R" "committed:$C" "pushed:$P" "closure-recorded:$CL"; do
    case "${kv#*:}" in met) ;; *) missing="$missing ${kv%%:*}(${kv#*:})";; esac; done
  echo "==== DMC E2E COMPLETION — REPORT-ONLY (reports state; grants/performs no gate) ===="
  echo "  milestone        : $MS"
  echo "  overall          : $OVERALL"
  echo "  verified         : $V"
  echo "  reviewed         : $R"
  echo "  committed        : $C  (commit=${COMMIT_FULL:0:7})"
  echo "  pushed           : $P  (offline: vs last-fetched local origin/${BRANCH:-main}; not network-verified)"
  echo "  closure-recorded : $CL"
  echo "  missing/blocked  : ${missing:-none}"
  echo "  HEAD             : $HEAD"
  echo "  origin_sync      : ahead=$AHEAD behind=$BEHIND in_sync=$([ "${AHEAD:-0}" = 0 ] && [ "${BEHIND:-0}" = 0 ] && echo true || echo false)"
  echo "  excluded_evidence: auto-logged .harness/evidence/dmc-*-*.md are untracked (expected)"
  echo "NOTE: report-only; the human Release Gate + Codex audit remain authoritative."
}

# ------------------------------------------------------- self-test (temp repos; real repo untouched)
self_test() {
  local P_=0 F_=0; ok(){ echo "  PASS $1"; P_=$((P_+1)); }; no(){ echo "  FAIL $1"; F_=$((F_+1)); }
  local TT; TT="$(mktemp -d)"; trap 'rm -rf "$TT"' RETURN
  # mkrepo helpers create a temp repo with controllable E2E state
  newrepo(){ local d="$TT/$1"; mkdir -p "$d/.harness/verification" "$d/.harness/plans" "$d/docs"
    ( cd "$d" && git init -q && git config user.email t@t && git config user.name t && git commit -q --allow-empty -m base ); echo "$d"; }
  add_verif(){ printf 'Final Status: PASS\n' > "$1/.harness/verification/dmc-$2.md"; }   # $1 repo $2 ms
  add_review(){ printf 'Review-Verdict: critic=PASS codex=ACCEPT\n' >> "$1/.harness/verification/dmc-$2.md"; }
  add_loose_review(){ printf 'mock response -> ... -> ACCEPT\n(APPROVED, flipped after critic PASS)\n' >> "$1/.harness/verification/dmc-$2.md"; }
  add_plan(){ printf 'Status: APPROVED\n' > "$1/.harness/plans/dmc-$2.md"; }
  add_commit(){ ( cd "$1" && echo x >> f.txt && git add f.txt && git commit -q -m "feat $2 milestone" ); git -C "$1" rev-parse HEAD; }
  set_origin(){ git -C "$1" update-ref "refs/remotes/origin/main" "$2"; }   # offline origin ref
  add_closure(){ printf '## %s CLOSED\n- Commit: `%s`\n' "$2" "$3" >> "$1/docs/MILESTONES.md"; }
  run(){ MS="$3"; BRANCH=main; evaluate "$1" "$3" "${4:-}" ""; }

  local r c
  # E1 none
  r="$(newrepo e1)"; run "" "" foo "" 2>/dev/null; evaluate "$r" foo "" ""; [ "$OVERALL" = blocked ] && [ "$V" = blocked ] && ok "E1 none -> blocked" || no "E1 ($OVERALL/$V)"
  # E2 committed, NOT pushed
  r="$(newrepo e2)"; add_verif "$r" foo; add_review "$r" foo; add_plan "$r" foo; c="$(add_commit "$r" foo)"; set_origin "$r" "$(git -C "$r" rev-parse "$c"^)"; printf '## bar CLOSED\n- Commit: `0000000`\n' > "$r/docs/MILESTONES.md"
  evaluate "$r" foo "" ""; [ "$OVERALL" = in-progress ] && [ "$P" = unmet ] && [ "$CL" = unmet ] && ok "E2 committed not pushed -> in-progress (P=unmet)" || no "E2 ($OVERALL P=$P CL=$CL)"
  # E3 pushed, present-but-no-foo-entry closure
  r="$(newrepo e3)"; add_verif "$r" foo; add_review "$r" foo; add_plan "$r" foo; c="$(add_commit "$r" foo)"; set_origin "$r" "$c"; printf '## bar CLOSED\n- Commit: `0000000`\n' > "$r/docs/MILESTONES.md"
  evaluate "$r" foo "" ""; [ "$OVERALL" = in-progress ] && [ "$P" = met ] && [ "$CL" = unmet ] && ok "E3 pushed no closure -> in-progress (P=met CL=unmet)" || no "E3 ($OVERALL P=$P CL=$CL)"
  # E4 fully done (abbrev closure hash)
  r="$(newrepo e4)"; add_verif "$r" foo; add_review "$r" foo; add_plan "$r" foo; c="$(add_commit "$r" foo)"; set_origin "$r" "$c"; add_closure "$r" foo "${c:0:7}"
  evaluate "$r" foo "" ""; [ "$OVERALL" = done ] && ok "E4 fully done (abbrev closure hash matched)" || no "E4 ($OVERALL V=$V R=$R C=$C P=$P CL=$CL)"
  # E5 fields present
  MS=foo BRANCH=main; out="$(emit)"; printf '%s' "$out" | grep -q 'origin_sync' && printf '%s' "$out" | grep -q 'HEAD' && printf '%s' "$out" | grep -q 'excluded_evidence' && ok "E5 report fields present" || no "E5 fields"
  # E6 unresolvable origin -> pushed blocked
  r="$(newrepo e6)"; add_verif "$r" foo; add_review "$r" foo; add_plan "$r" foo; c="$(add_commit "$r" foo)"
  evaluate "$r" foo "" ""; [ "$P" = blocked ] && [ "$OVERALL" = blocked ] && ok "E6 no origin ref -> pushed=blocked -> blocked" || no "E6 (P=$P $OVERALL)"
  # E7 reviewed isolated (pushed met via origin, but no canonical review line)
  r="$(newrepo e7)"; add_verif "$r" foo; add_plan "$r" foo; c="$(add_commit "$r" foo)"; set_origin "$r" "$c"; add_closure "$r" foo "$c"
  evaluate "$r" foo "" ""; [ "$R" = blocked ] && [ "$P" = met ] && [ "$OVERALL" = blocked ] && ok "E7 reviewed isolated -> reviewed=blocked (P=met)" || no "E7 (R=$R P=$P $OVERALL)"
  # E10 loose review markers only -> blocked
  r="$(newrepo e10)"; add_verif "$r" foo; add_loose_review "$r" foo; add_plan "$r" foo; c="$(add_commit "$r" foo)"; set_origin "$r" "$c"
  evaluate "$r" foo "" ""; [ "$R" = blocked ] && ok "E10 loose mock-ACCEPT/prose -> reviewed=blocked" || no "E10 (R=$R)"
  # E11 closure file absent -> blocked
  r="$(newrepo e11)"; add_verif "$r" foo; add_review "$r" foo; add_plan "$r" foo; c="$(add_commit "$r" foo)"; set_origin "$r" "$c"; rm -f "$r/docs/MILESTONES.md"
  evaluate "$r" foo "" ""; [ "$CL" = blocked ] && [ "$OVERALL" = blocked ] && ok "E11 MILESTONES absent -> closure=blocked" || no "E11 (CL=$CL $OVERALL)"
  # E12 abbrev<->full hash normalization (closure abbrev, --commit full)
  r="$(newrepo e12)"; add_verif "$r" foo; add_review "$r" foo; add_plan "$r" foo; c="$(add_commit "$r" foo)"; set_origin "$r" "$c"; add_closure "$r" foo "${c:0:7}"
  evaluate "$r" foo "$c" ""; [ "$CL" = met ] && [ "$C" = met ] && ok "E12 abbrev<->full hash normalized -> closure=met" || no "E12 (CL=$CL C=$C)"
  # E8 ambiguous auto-match (>1) -> committed blocked
  r="$(newrepo e8)"; add_verif "$r" foo; add_review "$r" foo; add_plan "$r" foo
  ( cd "$r" && echo a>>f && git add f && git commit -q -m "feat foo milestone one"; echo b>>f && git add f && git commit -q -m "feat foo milestone two" )
  evaluate "$r" foo "" ""; [ "$C" = blocked ] && [ "$OVERALL" = blocked ] && ok "E8 ambiguous(>1) -> committed=blocked" || no "E8 (C=$C $OVERALL)"
  # E9 --commit not in log -> committed blocked
  r="$(newrepo e9)"; add_verif "$r" foo; add_review "$r" foo; add_plan "$r" foo; add_commit "$r" foo >/dev/null
  evaluate "$r" foo "0000000000000000000000000000000000000000" ""; [ "$C" = blocked ] && ok "E9 --commit not in log -> committed=blocked" || no "E9 (C=$C)"
  # M3 --out guard
  out_refused ".env" && out_refused ".claude/hooks/secret-guard.sh" && out_refused "x/../.claude/hooks/secret-guard.sh" \
    && out_refused ".claude/workers/providers/oauth-cli/x" && out_refused "PROVIDER_CONTRACT.md" && ! out_refused "$TT/benign.json" \
    && ok "M3 --out guard: protected/secret/traversal refused, benign allowed" || no "M3 --out guard"
  # M-F2 (F2) --out actually writes the report (byte-equal to stdout); protected --out refused + file not created
  local rf cf so fo
  rf="$(newrepo f2)"; add_verif "$rf" foo; add_review "$rf" foo; add_plan "$rf" foo; cf="$(add_commit "$rf" foo)"; set_origin "$rf" "$cf"; add_closure "$rf" foo "${cf:0:7}"
  so="$(bash "$0" --milestone foo --repo "$rf" --commit "$cf" 2>/dev/null)"
  bash "$0" --milestone foo --repo "$rf" --commit "$cf" --out "$TT/f2.out" >/dev/null 2>&1
  fo="$(cat "$TT/f2.out" 2>/dev/null)"
  { [ -f "$TT/f2.out" ] && [ -n "$so" ] && [ "$so" = "$fo" ]; } && ok "M-F2 (F2) --out file byte-equal to stdout report" || no "M-F2 (F2) --out not written / mismatch"
  bash "$0" --milestone foo --repo "$rf" --commit "$cf" --out "$TT/sub/.claude/hooks/evil" >/dev/null 2>&1; local rcf2=$?
  { [ "$rcf2" = 2 ] && [ ! -e "$TT/sub/.claude/hooks/evil" ]; } && ok "M-F2neg (F2) protected --out refused (exit 2, not created)" || no "M-F2neg (F2) rc=$rcf2"
  # M1/M5 real repo untouched
  [ "$ST_PRE" = "$(git -C "$ROOTDIR" status --porcelain 2>/dev/null | md5)" ] && ok "M1/M5 real repo byte-identical (self-test mutated nothing)" || no "M1/M5 repo changed"
  echo "  ---- self-test: PASS=$P_ FAIL=$F_ ----"; [ "$F_" = 0 ]
}

ROOTDIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
MS=""; COMMITARG=""; BRANCH=""; REPO="."; OUT=""; MODE=run
while [ $# -gt 0 ]; do case "$1" in
  --milestone) MS="$2"; shift 2;; --commit) COMMITARG="$2"; shift 2;; --branch) BRANCH="$2"; shift 2;;
  --repo) REPO="$2"; shift 2;; --out) OUT="$2"; shift 2;; --self-test) MODE=selftest; shift;;
  -h|--help) sed -n '2,12p' "$0"; exit 0;; *) echo "e2e: unknown arg $1" >&2; exit 2;;
esac; done

if [ "$MODE" = selftest ]; then
  echo "==== DMC E2E COMPLETION CONTROLLER — SELF-TEST (temp repos; real repo untouched) ===="
  ST_PRE="$(git -C "$ROOTDIR" status --porcelain 2>/dev/null | md5)"; self_test; exit $?
fi
[ -n "$MS" ] || { echo "e2e: --milestone <id> required" >&2; exit 2; }
if [ -n "$OUT" ] && out_refused "$OUT"; then echo "e2e: --out target is protected/secret — REFUSED (writing nothing)" >&2; exit 2; fi
evaluate "$REPO" "$MS" "$COMMITARG" "$BRANCH"
# F2: when --out is set (and the guard above passed), write the report there; the wrote-notice goes to stderr so the
# file's bytes equal the stdout report. The default (no --out) path keeps emitting to stdout.
if [ -n "$OUT" ]; then emit > "$OUT"; echo "e2e: wrote $OUT" >&2; else emit; fi
[ "$OVERALL" = done ]; exit $?