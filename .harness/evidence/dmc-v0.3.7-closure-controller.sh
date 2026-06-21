#!/usr/bin/env bash
# DMC Closure Controller (v0.3.7) — ADVISORY / READ-ONLY.
#
# Mechanically judges the 5 DMC closure conditions for a milestone — verified · reviewed · committed · pushed ·
# closure-recorded — each from a concrete signal (MET / NOT-MET, fail-closed), declares E2E-DONE iff all 5 MET, and emits
# an APPEND-ONLY docs/MILESTONES.md closure-entry CANDIDATE. It writes NOTHING (the candidate is text for the human to
# apply), commits/pushes NOTHING, makes no live call, and never reads/prints secret content:
#   - the --verify-report path is refused UNREAD if it matches a secret pattern;
#   - git is read with metadata-only primitives (rev-parse, merge-base, show -s --format='%s'); no content-dumping
#     show/diff, no -p/patch family, no log -p / diff-tree / format-patch / cat-file; the commit body (%b) is never read;
#   - the milestone id is matched as a WHOLE TOKEN (v0.3.7 must not match v0.3.70).
# Fail-closed: any ambiguous/absent signal => NOT-MET (never a false E2E-DONE).
#
# Usage:  closure-controller.sh --milestone <id> --commit <ref> --verify-report <path>
#                               [--milestones-file <path>] [--repo <dir>] [--date <YYYY-MM-DD>] [--out <file>]
#         closure-controller.sh --self-test
# Exit: 0 = E2E-DONE, 1 = NOT DONE (advisory — never wired to commit/push), 2 = usage/refused.
set -u
set -o pipefail
export PYTHONDONTWRITEBYTECODE=1

ROOTDIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SELFPATH="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/$(basename "$0")"

# --- --out write-target guard (v0.3.4/v0.3.5/v0.3.6 hardened: refuse ANY `..` component first, then protected/secret) --
PROT_RE='(^|/)(\.env)(\.|$)|\.pem$|\.key$|id_rsa|id_ed25519|credentials|secret|\.p12$|\.pfx$|\.keystore$|\.claude/hooks|provider-router\.py|/ROUTING\.md$|WORKER_(TASK|RESULT|REVIEW)_SCHEMA\.md|PROVIDER_CONTRACT\.md|workers/providers/(glm-api|oauth-cli)|(^|/)dmc-glm-smoke$'
out_refused() { # path -> 0 if must refuse
  local raw="$1"
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

# --- secret-FILE pattern (for the --verify-report guard): classify by filename only ---
SECRET_RE='\.pem$|\.key$|id_rsa|id_ed25519|\.p12$|\.pfx$|\.keystore$|credentials|secret|service-account|(^|/)\.npmrc$|(^|/)\.netrc$|(^|/)\.pgpass$|(^|/)\.ssh/|\.aws/credentials'
is_secret_path() { local p="$1"
  case "$p" in *.env|*.env.local|*.env.*) case "$p" in *.example|*.sample|*.template) ;; *) return 0;; esac;; esac
  printf '%s' "$p" | grep -qiE "$SECRET_RE" && return 0; return 1; }

# --- condition judges (each echoes MET or NOT-MET; fail-closed) ---
judge_verified() { # <verify_report>
  local vr="$1"
  { [ -z "$vr" ] || is_secret_path "$vr" || [ ! -f "$vr" ]; } && { echo NOT-MET; return; }
  local finalpass countok
  finalpass="$(awk '/^## Final Status/{f=1} f && /\*\*PASS\*\*/{print "1"; exit}' "$vr" 2>/dev/null)"
  # countok = explicit `N PASS / 0 FAIL` OR an EQUAL ratio `N/N` (N>0). A non-equal ratio (e.g. 8/9, 3/4) does NOT count.
  if grep -qE '[0-9]+ PASS / 0 FAIL' "$vr" 2>/dev/null; then countok=1
  elif grep -oE '[0-9]+/[0-9]+' "$vr" 2>/dev/null | awk -F/ '$1==$2 && $1+0>0{f=1} END{exit !f}'; then countok=1; fi
  # fail-closed: ANY failing-count line (N PASS / M>0 FAIL) or a **FAIL** marker anywhere => NOT-MET
  if grep -qE '\*\*FAIL\*\*' "$vr" 2>/dev/null || grep -qE '[1-9][0-9]* FAIL' "$vr" 2>/dev/null; then echo NOT-MET; return; fi
  { [ "$finalpass" = 1 ] && [ "${countok:-}" = 1 ]; } && echo MET || echo NOT-MET
}
judge_reviewed() { # <verify_report>  — single anchored Review-Verdict line only
  local vr="$1"
  { [ -z "$vr" ] || is_secret_path "$vr" || [ ! -f "$vr" ]; } && { echo NOT-MET; return; }
  grep -qE '^Review-Verdict: critic=PASS codex=ACCEPT[[:space:]]*$' "$vr" 2>/dev/null && echo MET || echo NOT-MET
}
judge_committed() { # <repo> <ref>
  git -C "$1" rev-parse --verify "$2^{commit}" >/dev/null 2>&1 && echo MET || echo NOT-MET; }
judge_pushed() { # <repo> <ref>  — last-fetched local origin/main only (no fetch)
  local repo="$1" ref="$2"
  git -C "$repo" rev-parse --verify origin/main >/dev/null 2>&1 || { echo NOT-MET; return; }
  git -C "$repo" merge-base --is-ancestor "$ref" origin/main 2>/dev/null && echo MET || echo NOT-MET; }
judge_closure_recorded() { # <milestones_file> <milestone_id>  — whole-token match (v0.3.7 != v0.3.70)
  local mf="$1" id="$2"
  [ -f "$mf" ] || { echo NOT-MET; return; }
  local esc; esc="$(printf '%s' "$id" | sed 's/[.[\\*^$()+?{|]/\\&/g')"
  grep -qE "(^|[^0-9.])${esc}([^0-9]|$)" "$mf" 2>/dev/null && echo MET || echo NOT-MET; }

# --- run the controller: write the packet to <outfile>; return 0 if E2E-DONE else 1 ---
run_closure() { # <outfile> <repo> <milestone> <ref> <verify_report> <milestones_file> <date>
  local outfile="$1" repo="$2" ms="$3" ref="$4" vr="$5" mf="$6" date="$7"
  local v rv c p cr unmet="" subj rvline count
  v="$(judge_verified "$vr")"; rv="$(judge_reviewed "$vr")"
  c="$(judge_committed "$repo" "$ref")"; p="$(judge_pushed "$repo" "$ref")"
  cr="$(judge_closure_recorded "$mf" "$ms")"
  for kv in "verified:$v" "reviewed:$rv" "committed:$c" "pushed:$p" "closure-recorded:$cr"; do
    [ "${kv##*:}" = "NOT-MET" ] && unmet="$unmet ${kv%%:*}"
  done
  subj="$(git -C "$repo" show -s --format='%s' "$ref" 2>/dev/null || echo '(unknown)')"
  rvline="$( { [ -n "$vr" ] && ! is_secret_path "$vr" && [ -f "$vr" ]; } && grep -m1 '^Review-Verdict:' "$vr" 2>/dev/null || true)"
  count="$( { [ -n "$vr" ] && ! is_secret_path "$vr" && [ -f "$vr" ]; } && { grep -m1 -oE '[0-9]+ PASS / [0-9]+ FAIL' "$vr" 2>/dev/null || grep -m1 -oE '[0-9]+/[0-9]+' "$vr" 2>/dev/null; } || true)"

  {
    echo "# DMC Closure Controller — $ms"
    echo
    echo "_read-only · advisory · judges 5 closure conditions · writes/commits/pushes NOTHING · grants no gate_"
    echo
    echo "## Closure conditions"
    echo "| condition | status |"
    echo "|---|---|"
    echo "| verified | $v |"
    echo "| reviewed | $rv |"
    echo "| committed | $c |"
    echo "| pushed | $p |"
    echo "| closure-recorded | $cr |"
    echo
    echo "## Judgment"
    if [ -z "$unmet" ]; then echo "**E2E-DONE** — all 5 closure conditions MET."
    else echo "**NOT DONE** — unmet:$unmet"; fi
    echo
    echo "## MILESTONES.md closure-entry CANDIDATE (append-only — the tool writes nothing)"
    echo '```markdown'
    echo "## $ms — ${date}"
    echo "- commit: \`$(git -C "$repo" rev-parse --short "$ref" 2>/dev/null || echo unknown)\` — $subj"
    [ -n "$rvline" ] && echo "- $rvline"
    [ -n "$count" ] && echo "- self-test: $count"
    echo "- closure: verified=$v reviewed=$rv committed=$c pushed=$p closure-recorded=$cr"
    echo '```'
    echo
    echo "CANDIDATE — apply by **appending** the block above to \`docs/MILESTONES.md\`; this tool writes nothing,"
    echo "commits nothing, pushes nothing, and grants no gate."
    echo
    echo "---"
    echo "_read-only/advisory; emits a candidate only; never writes MILESTONES.md / commits / pushes; names-only; no secret content._"
  } > "$outfile"

  [ -z "$unmet" ] && return 0 || return 1
}

# ---------------------------------------------------------------- self-test (no in-repo writes; $TMPDIR only)
self_test() {
  local P=0 F=0; ok(){ echo "  PASS $1"; P=$((P+1)); }; no(){ echo "  FAIL $1"; F=$((F+1)); }
  local TT; TT="$(mktemp -d)"; trap 'rm -rf "$TT"' RETURN
  local SENT_MSG="MSGBODY_SENTINEL_$$"

  # real-repo AC1 pre-snapshot (HEAD + branch + config + porcelain + MILESTONES.md md5)
  local RH RB RC RP RM
  RH="$(git -C "$ROOTDIR" rev-parse HEAD 2>/dev/null)"; RB="$(git -C "$ROOTDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  RC="$(git -C "$ROOTDIR" config --list 2>/dev/null | md5)"; RP="$(git -C "$ROOTDIR" status --porcelain 2>/dev/null | md5)"
  RM="$(md5 < "$ROOTDIR/docs/MILESTONES.md" 2>/dev/null || echo none)"

  # fixed temp repo: one commit (body carries a sentinel), origin/main manufactured = HEAD (so pushed=MET)
  local R="$TT/repo"; mkdir -p "$R"; git -C "$R" init -q; git -C "$R" config user.email t@t.t; git -C "$R" config user.name t
  echo x > "$R/f.txt"; git -C "$R" add -A
  GIT_AUTHOR_DATE='2020-01-01T00:00:00 +0000' GIT_COMMITTER_DATE='2020-01-01T00:00:00 +0000' \
    git -C "$R" commit -q -m "milestone commit subject"$'\n\n'"body $SENT_MSG here"
  local HASH; HASH="$(git -C "$R" rev-parse HEAD)"
  git -C "$R" update-ref refs/remotes/origin/main "$HASH"
  local TH TB TC TP
  TH="$(git -C "$R" rev-parse HEAD)"; TB="$(git -C "$R" rev-parse --abbrev-ref HEAD)"; TC="$(git -C "$R" config --list | md5)"; TP="$(git -C "$R" status --porcelain | md5)"

  # fixture verify-reports
  printf '%s\n' '# Verification Report' 'Review-Verdict: critic=PASS codex=ACCEPT' '## Run ID' 'rid' '| x | 16 PASS / 0 FAIL |' '## Final Status' '**PASS** — green' > "$TT/rep_pass.md"
  printf '%s\n' '# Verification Report' 'Review-Verdict: critic=PASS codex=PENDING' '| x | 3 PASS / 2 FAIL |' '## Final Status' '**FAIL**' > "$TT/rep_fail.md"
  printf '%s\n' '# Verification Report' 'Review-Verdict: critic=PASS codex=ACCEPT' '| a | 5 PASS / 0 FAIL |' '| b | 2 PASS / 3 FAIL |' '## Final Status' '**PASS**' > "$TT/rep_mixed.md"
  printf '%s\n' '# Verification Report' 'Review-Verdict: critic=PASS codex=REVISE' 'note: an earlier codex=ACCEPT round occurred' '| x | 9 PASS / 0 FAIL |' '## Final Status' '**PASS**' > "$TT/rep_prose.md"
  printf '%s\n' '# Verification Report' 'Review-Verdict: critic=PASS codex=PENDING' '| x | 9 PASS / 0 FAIL |' '## Final Status' '**PASS**' > "$TT/rep_pending.md"
  printf '%s\n' '# Verification Report' 'Review-Verdict: critic=PASS codex=ACCEPT' '8/8 self-test' '## Final Status' '**PASS**' > "$TT/rep_ratio_ok.md"
  printf '%s\n' '# Verification Report' 'Review-Verdict: critic=PASS codex=ACCEPT' 'ratio 8/9 partial' '## Final Status' '**PASS**' > "$TT/rep_ratio_bad.md"
  printf '%s\n' '# Verification Report' 'Review-Verdict: critic=PASS codex=ACCEPTED' '| x | 9 PASS / 0 FAIL |' '## Final Status' '**PASS**' > "$TT/rep_accepted.md"
  # fixture MILESTONES.md
  printf '%s\n' '## dmc-v0.3.7 — done' > "$TT/ms_present.md"
  printf '%s\n' '## dmc-v0.3.70 — other' > "$TT/ms_prefix.md"

  # AC2 — both polarities + the 3 fail-OPEN negatives
  local a; a=1
  [ "$(judge_verified "$TT/rep_pass.md")" = MET ] || a=0
  [ "$(judge_verified "$TT/rep_fail.md")" = NOT-MET ] || a=0
  [ "$(judge_verified "$TT/rep_mixed.md")" = NOT-MET ] || a=0        # mixed-count fail-OPEN negative
  [ "$(judge_verified "$TT/rep_ratio_ok.md")" = MET ] || a=0         # equal ratio N/N => MET
  [ "$(judge_verified "$TT/rep_ratio_bad.md")" = NOT-MET ] || a=0    # non-equal ratio 8/9 => NOT-MET
  [ "$a" = 1 ] && ok "AC2 verified: PASS=>MET; FAIL/mixed/8-9-ratio=>NOT-MET; equal-ratio 8/8=>MET" || no "AC2 verified"
  a=1
  [ "$(judge_reviewed "$TT/rep_pass.md")" = MET ] || a=0
  [ "$(judge_reviewed "$TT/rep_pending.md")" = NOT-MET ] || a=0
  [ "$(judge_reviewed "$TT/rep_prose.md")" = NOT-MET ] || a=0        # prose-split fail-OPEN negative
  [ "$(judge_reviewed "$TT/rep_accepted.md")" = NOT-MET ] || a=0     # codex=ACCEPTED suffix => NOT-MET (exact-line)
  [ "$a" = 1 ] && ok "AC2 reviewed: exact ACCEPT-line=>MET; PENDING/prose-ACCEPT/ACCEPTED-suffix=>NOT-MET" || no "AC2 reviewed"
  a=1
  [ "$(judge_committed "$R" "$HASH")" = MET ] || a=0
  [ "$(judge_committed "$R" deadbeefdeadbeef)" = NOT-MET ] || a=0
  [ "$a" = 1 ] && ok "AC2 committed: real ref=>MET, bogus ref=>NOT-MET" || no "AC2 committed"
  a=1
  [ "$(judge_pushed "$R" "$HASH")" = MET ] || a=0                    # origin/main manufactured
  local R2="$TT/repo2"; mkdir -p "$R2"; git -C "$R2" init -q; git -C "$R2" config user.email t@t.t; git -C "$R2" config user.name t; echo y>"$R2/g"; git -C "$R2" add -A; GIT_AUTHOR_DATE='2020-01-01T00:00:00 +0000' GIT_COMMITTER_DATE='2020-01-01T00:00:00 +0000' git -C "$R2" commit -q -m c
  [ "$(judge_pushed "$R2" "$(git -C "$R2" rev-parse HEAD)")" = NOT-MET ] || a=0   # no origin/main
  [ "$a" = 1 ] && ok "AC2 pushed: ancestor-of-origin/main=>MET, no-origin/main=>NOT-MET" || no "AC2 pushed"
  a=1
  [ "$(judge_closure_recorded "$TT/ms_present.md" "v0.3.7")" = MET ] || a=0
  [ "$(judge_closure_recorded "$TT/ms_prefix.md" "v0.3.7")" = NOT-MET ] || a=0     # v0.3.70 prefix collision
  [ "$(judge_closure_recorded "$TT/absent.md" "v0.3.7")" = NOT-MET ] || a=0
  [ "$a" = 1 ] && ok "AC2 closure-recorded: present=>MET, v0.3.70-only=>NOT-MET, absent=>NOT-MET" || no "AC2 closure-recorded"

  # AC3 — E2E-DONE iff all 5 (all-MET fixture) + NOT DONE arm
  local PKa="$TT/a.md"; run_closure "$PKa" "$R" "v0.3.7" "$HASH" "$TT/rep_pass.md" "$TT/ms_present.md" "2026-06-21"; local rca=$?
  local PKn="$TT/n.md"; run_closure "$PKn" "$R" "v0.3.7" "$HASH" "$TT/rep_pass.md" "$TT/absent.md" "2026-06-21"; local rcn=$?
  if [ "$rca" = 0 ] && grep -q 'E2E-DONE' "$PKa" && [ "$rcn" = 1 ] && grep -q 'NOT DONE' "$PKn" && grep -q 'closure-recorded' "$PKn"; then
    ok "AC3 E2E-DONE iff all 5: all-MET=>E2E-DONE+exit0; unmet=>NOT DONE+exit1+unmet list"
  else no "AC3 E2E gate (rca=$rca rcn=$rcn)"; fi

  # AC4 — append-only candidate + MILESTONES.md byte-unchanged + body sentinel NOT in candidate
  local MSorig; MSorig="$(md5 < "$TT/ms_present.md")"
  if grep -q 'CANDIDATE — apply by \*\*appending\*\*' "$PKa" && grep -q 'apply by' "$PKa" \
     && [ "$(md5 < "$TT/ms_present.md")" = "$MSorig" ] && ! grep -Fq "$SENT_MSG" "$PKa"; then
    ok "AC4 append-only candidate: labelled, MILESTONES.md byte-unchanged, commit-body sentinel absent"
  else no "AC4 append-only candidate"; fi

  # AC5 — fail-closed triggers
  a=1
  [ "$(judge_verified "")" = NOT-MET ] || a=0
  printf 'TOK=%s\n' "$SENT_MSG" > "$TT/x.env"
  [ "$(judge_verified "$TT/x.env")" = NOT-MET ] || a=0              # secret-pathed verify-report refused
  [ "$(judge_reviewed "")" = NOT-MET ] || a=0
  [ "$(judge_committed "$R" badref)" = NOT-MET ] || a=0
  [ "$(judge_closure_recorded "$TT/absent.md" "v0.3.7")" = NOT-MET ] || a=0
  [ "$a" = 1 ] && ok "AC5 fail-closed: absent/secret verify-report, bogus ref, absent MILESTONES => NOT-MET" || no "AC5 fail-closed"

  # AC7 — structural audit (operative source ONLY; AUDIT_BLOCK + comments excluded so patterns don't self-match)
  local OP="$TT/op.src"; sed '/AUDIT_BLOCK_START/,/AUDIT_BLOCK_END/d' "$SELFPATH" | grep -vE '^[[:space:]]*#' > "$OP"
  # >>>AUDIT_BLOCK_START
  local sa=1
  grep -nE 'format-patch|cat-file|diff-tree' "$OP" >/dev/null && sa=0
  grep -nE '(show|log|diff)[^|]* (-p|--patch)( |$)' "$OP" >/dev/null && sa=0
  grep -n '%b' "$OP" >/dev/null && sa=0
  grep -nE 'git( -C [^ ]+| -C "[^"]+")? +show' "$OP" | grep -vE -- '-s|--name-status|--numstat|--stat|--name-only' >/dev/null && sa=0
  grep -nE 'git( -C [^ ]+| -C "[^"]+")? +diff ' "$OP" | grep -vE -- '--name-status|--numstat|--stat|--name-only' >/dev/null && sa=0
  grep -nE 'os\.environ|os\.getenv|getenv\(' "$OP" >/dev/null && sa=0
  grep -nE '\$\{?(GLM_API_KEY|DMC_OAUTHCLI_BIN|ANTHROPIC_API_KEY|OPENAI_API_KEY|ZHIPUAI_API_KEY)' "$OP" >/dev/null && sa=0
  [ "$sa" = 1 ] && ok "AC7 STRUCTURAL: no content-dumping git primitive; no commit-body read; no env/cred read" || no "AC7 STRUCTURAL: a forbidden primitive is present"
  # >>>AUDIT_BLOCK_END

  # AC6 — --out guard pinned pairs
  mkdir -p "$TT/sub"
  out_refused "$TT/sub/../benign.json" && out_refused ".env" && out_refused ".claude/hooks/x" && out_refused "provider-router.py" \
    && { ln -sf "$ROOTDIR/.claude/hooks" "$TT/sub/hooks" 2>/dev/null; out_refused "$TT/sub/hooks/x"; } \
    && ! out_refused "$TT/benign.json" && ok "AC6 --out guard: benign-.. + protected/secret/symlink refused, benign allowed" || no "AC6 --out guard"

  # AC1 FINAL — real + temp repo unchanged + MILESTONES.md byte-unchanged
  local rh rb rc2 rp rm th tb tc tp
  rh="$(git -C "$ROOTDIR" rev-parse HEAD)"; rb="$(git -C "$ROOTDIR" rev-parse --abbrev-ref HEAD)"; rc2="$(git -C "$ROOTDIR" config --list | md5)"; rp="$(git -C "$ROOTDIR" status --porcelain | md5)"; rm="$(md5 < "$ROOTDIR/docs/MILESTONES.md" 2>/dev/null || echo none)"
  th="$(git -C "$R" rev-parse HEAD)"; tb="$(git -C "$R" rev-parse --abbrev-ref HEAD)"; tc="$(git -C "$R" config --list | md5)"; tp="$(git -C "$R" status --porcelain | md5)"
  if [ "$RH" = "$rh" ] && [ "$RB" = "$rb" ] && [ "$RC" = "$rc2" ] && [ "$RP" = "$rp" ] && [ "$RM" = "$rm" ] \
     && [ "$TH" = "$th" ] && [ "$TB" = "$tb" ] && [ "$TC" = "$tc" ] && [ "$TP" = "$tp" ]; then
    ok "AC1 read-only: real+temp repo HEAD/branch/config/porcelain + MILESTONES.md pre==post (no mutation)"
  else no "AC1 read-only: a repo or MILESTONES.md changed"; fi

  echo "  ---- self-test: PASS=$P FAIL=$F ----"; [ "$F" = 0 ]
}

# --- args ---
MILESTONE=""; COMMIT=""; VERIFY=""; MSFILE=""; REPO=""; DATE=""; OUT=""; MODE=run
while [ $# -gt 0 ]; do case "$1" in
  --milestone) MILESTONE="$2"; shift 2;; --commit) COMMIT="$2"; shift 2;; --verify-report) VERIFY="$2"; shift 2;;
  --milestones-file) MSFILE="$2"; shift 2;; --repo) REPO="$2"; shift 2;; --date) DATE="$2"; shift 2;;
  --out) OUT="$2"; shift 2;; --self-test) MODE=selftest; shift;; -h|--help) sed -n '2,22p' "$0"; exit 0;;
  *) echo "closure-controller: unknown arg $1" >&2; exit 2;;
esac; done

if [ "$MODE" = selftest ]; then
  echo "==== DMC CLOSURE CONTROLLER — SELF-TEST (no in-repo writes; \$TMPDIR only) ===="
  self_test; exit $?
fi

[ -n "$MILESTONE" ] || { echo "closure-controller: --milestone <id> required" >&2; exit 2; }
[ -n "$COMMIT" ] || { echo "closure-controller: --commit <ref> required" >&2; exit 2; }
REPO="${REPO:-$ROOTDIR}"; MSFILE="${MSFILE:-$REPO/docs/MILESTONES.md}"
[ -n "$DATE" ] || DATE="$(date +%Y-%m-%d)"
if [ -n "$OUT" ]; then
  if out_refused "$OUT"; then echo "closure-controller: --out target is a protected/secret path — REFUSED (writing nothing)" >&2; exit 2; fi
fi
PACK="$(mktemp)"; run_closure "$PACK" "$REPO" "$MILESTONE" "$COMMIT" "$VERIFY" "$MSFILE" "$DATE"; RC=$?
if [ -n "$OUT" ]; then cp "$PACK" "$OUT"; echo "closure-controller: wrote $OUT" >&2; else cat "$PACK"; fi
rm -f "$PACK"
exit $RC
