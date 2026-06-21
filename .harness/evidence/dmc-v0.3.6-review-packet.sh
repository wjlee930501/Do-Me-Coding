#!/usr/bin/env bash
# DMC Review Packet generator (v0.3.6) — ADVISORY / READ-ONLY.
#
# Auto-produces a review packet for a milestone: changeset summary, protected-surface scan, forbidden/secret-file scan,
# verification summary, and residual risks. It RECORDS state for review; it mutates nothing, makes no live call, grants
# no gate. NON-NEGOTIABLE secret protection — it NEVER reads or prints the contents of any secret-bearing file, nor any
# free-form commit-message body:
#   - changeset via names-only git primitives ONLY (show --name-status/--numstat, diff --cached --name-status; never a
#     content-dumping show/diff, never the -p/patch family, never log -p / diff-tree / format-patch / cat-file);
#   - commit info via hash + subject ONLY; the Review-Verdict line is grepped (single-line, anchored); the body is never
#     emitted;
#   - the forbidden/protected scans inventory by FILENAME pattern only — no matched secret file is ever opened;
#   - a --verify-report whose path matches a secret pattern is refused UNREAD.
#
# Usage:  review-packet.sh [--commit <ref>] [--staged] [--repo <dir>] [--verify-report <path>] [--out <file>]
#         review-packet.sh --self-test
# Exit: 0 = packet emitted clean, 3 = packet emitted but FORBIDDEN secret file present in changeset, 2 = usage/refused.
set -u
set -o pipefail
export PYTHONDONTWRITEBYTECODE=1

ROOTDIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SELFPATH="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/$(basename "$0")"

# --- --out write-target guard (v0.3.4/v0.3.5 hardened: refuse ANY `..` component first, then protected/secret/symlink) -
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

# --- secret-FILE pattern set (CLAUDE.md v0.1.3): classify a path by filename only (never open it). `credentials` /
#     `secret` / `service-account` intentionally widen the CLAUDE.md *.json forms (over-inclusive, safe). ---
SECRET_RE='\.pem$|\.key$|id_rsa|id_ed25519|\.p12$|\.pfx$|\.keystore$|credentials|secret|service-account|(^|/)\.npmrc$|(^|/)\.netrc$|(^|/)\.pgpass$|(^|/)\.ssh/|\.aws/credentials'
is_secret_path() { # path -> 0 if it matches a secret pattern (filename only)
  local p="$1"
  case "$p" in *.env|*.env.local|*.env.*) case "$p" in *.example|*.sample|*.template) ;; *) return 0;; esac;; esac
  printf '%s' "$p" | grep -qiE "$SECRET_RE" && return 0
  return 1
}

# --- DMC protected-PATH set: exactly the gate-check DEFAULT_PROTECTED 10 entries (paths, not secret-file patterns) ---
PROTECTED_RE='\.claude/workers/providers/glm-api|\.claude/workers/providers/oauth-cli|\.claude/workers/providers/provider-router\.py|\.claude/workers/providers/ROUTING\.md|\.claude/workers/providers/PROVIDER_CONTRACT\.md|\.claude/hooks|WORKER_TASK_SCHEMA\.md|WORKER_RESULT_SCHEMA\.md|WORKER_REVIEW_SCHEMA\.md|(^|/)dmc-glm-smoke$'

# --- changeset paths (names-only git). prints one path per changed file. ---
changed_paths() { # <repo> <mode:commit|staged> <ref>
  local repo="$1" mode="$2" ref="$3"
  if [ "$mode" = staged ]; then
    git -C "$repo" diff --cached --name-status 2>/dev/null | awk -F'\t' 'NF{print $NF}'
  else
    git -C "$repo" show --name-status --format='' "$ref" 2>/dev/null | awk -F'\t' 'NF{print $NF}'
  fi
}
changed_counts() { # <repo> <mode> <ref> -> "ins del"
  local repo="$1" mode="$2" ref="$3" src
  if [ "$mode" = staged ]; then src="$(git -C "$repo" diff --cached --numstat 2>/dev/null)"
  else src="$(git -C "$repo" show --numstat --format='' "$ref" 2>/dev/null)"; fi
  printf '%s\n' "$src" | awk '$1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+$/ {i+=$1; d+=$2} END{printf "%d %d", i+0, d+0}'
}

# --- verification summary from a verify-report .md (3 cases; real tokens; secret-path refused unread) ---
verify_summary() { # <verify_report_path|"">
  local vr="$1"
  [ -z "$vr" ] && { echo "no verification report provided"; return; }
  if is_secret_path "$vr"; then echo "verify-report path refused (secret-pattern); not read"; return; fi
  [ -f "$vr" ] || { echo "verify-report not found: $vr"; return; }
  local rv count final runid
  rv="$(grep -m1 '^Review-Verdict:' "$vr" 2>/dev/null || true)"
  # prefer the authoritative 'N PASS / M FAIL' self-test count; fall back to a bare 'N/M' only if absent
  count="$(grep -m1 -oE '[0-9]+ PASS / [0-9]+ FAIL' "$vr" 2>/dev/null || true)"
  [ -z "$count" ] && count="$(grep -m1 -oE '[0-9]+/[0-9]+' "$vr" 2>/dev/null || true)"
  final="$(awk '/^## Final Status/{f=1} f && match($0,/\*\*(PASS|FAIL|PARTIAL)\*\*/){print substr($0,RSTART,RLENGTH); exit}' "$vr" 2>/dev/null || true)"
  runid="$(awk '/^## Run ID/{getline; gsub(/^[[:space:]]+|[[:space:]]+$/,""); print; exit}' "$vr" 2>/dev/null || true)"
  [ -n "$rv" ] && echo "$rv" || echo "Review-Verdict: not present"
  echo "counts: ${count:-unknown}"
  echo "final-status: ${final:-unknown}"
  [ -n "$runid" ] && echo "run-id: $runid"
  echo "(self-attested by the report; advisory — not independently re-verified)"
}

# --- build the packet into <outfile>. return 3 if a FORBIDDEN secret file is present in the changeset, else 0. ---
run_packet() { # <outfile> <repo> <mode> <ref> <milestone> <verify_report>
  local outfile="$1" repo="$2" mode="$3" ref="$4" milestone="$5" vr="$6"
  local paths prot fb counts hash subj rvline ahead behind
  paths="$(changed_paths "$repo" "$mode" "$ref")"
  prot="$(printf '%s\n' "$paths" | grep -E "$PROTECTED_RE" 2>/dev/null || true)"
  fb="$(printf '%s\n' "$paths" | while IFS= read -r p; do [ -n "$p" ] && is_secret_path "$p" && printf '%s\n' "$p"; done)"
  counts="$(changed_counts "$repo" "$mode" "$ref")"
  if [ "$mode" = staged ]; then hash="(staged)"; subj="(staged changeset)"; rvline=""
  else
    hash="$(git -C "$repo" show -s --format='%H' "$ref" 2>/dev/null || echo unknown)"
    subj="$(git -C "$repo" show -s --format='%s' "$ref" 2>/dev/null || echo unknown)"
    rvline="$(git -C "$repo" show -s --format='%B' "$ref" 2>/dev/null | grep -m1 '^Review-Verdict:' || true)"
  fi
  ahead="$(git -C "$repo" rev-list --count origin/main..HEAD 2>/dev/null || echo '?')"
  behind="$(git -C "$repo" rev-list --count HEAD..origin/main 2>/dev/null || echo '?')"

  {
    echo "# DMC Review Packet — ${milestone:-$ref}"
    echo
    echo "_read-only · advisory · names-only · executes nothing · grants no gate_"
    echo
    echo "## 1. Changeset summary"
    echo "- ref: \`$hash\`"
    echo "- subject: $subj"
    [ -n "$rvline" ] && echo "- $rvline"
    echo "- files: $(printf '%s\n' "$paths" | grep -c . ) (+${counts%% *} / -${counts##* })"
    echo "- changed paths (names only):"
    printf '%s\n' "$paths" | grep . | sed 's/^/  - /'
    echo
    echo "## 2. Protected surfaces touched (review-required)"
    if [ -n "$prot" ]; then printf '%s\n' "$prot" | sed 's/^/- /'; else echo "none"; fi
    echo
    echo "## 3. Forbidden / secret files (filename-only)"
    if [ -n "$fb" ]; then
      echo "**FORBIDDEN files present — STOP** (filenames only; contents never read):"
      printf '%s\n' "$fb" | sed 's/^/- /'
    else echo "none"; fi
    echo
    echo "## 4. Verification summary (report's own self-attested claims; advisory)"
    verify_summary "$vr" | sed 's/^/- /'
    echo
    echo "## 5. Residual risks"
    echo "- push state: ahead $ahead, behind $behind (vs origin/main)"
    if [ -n "$prot" ]; then echo "- protected surfaces touched: yes (see §2) — confirm authorization in the plan/verify report"; else echo "- protected surfaces touched: none"; fi
    if [ -n "$fb" ]; then echo "- forbidden secret files present: YES — BLOCK (do not stage/commit/push)"; else echo "- forbidden secret files present: none"; fi
    echo "- auto-log evidence: left untracked/excluded by convention"
    echo
    echo "---"
    echo "_read-only/advisory; names-only; no secret content; executes nothing; grants no gate._"
  } > "$outfile"

  [ -n "$fb" ] && return 3 || return 0
}

# ---------------------------------------------------------------- self-test (no in-repo writes; $TMPDIR only)
self_test() {
  local P=0 F=0; ok(){ echo "  PASS $1"; P=$((P+1)); }; no(){ echo "  FAIL $1"; F=$((F+1)); }
  local TT; TT="$(mktemp -d)"; trap 'rm -rf "$TT"' RETURN
  local SENT_FILE="S3CR3T_SENTINEL_$$" SENT_MSG="MSGBODY_SENTINEL_$$" SENT_VR="VR_SENTINEL_$$"

  # AC1 oracle snapshot (real repo) — HEAD + branch + config + porcelain
  local RH RB RC RP
  RH="$(git -C "$ROOTDIR" rev-parse HEAD 2>/dev/null)"; RB="$(git -C "$ROOTDIR" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  RC="$(git -C "$ROOTDIR" config --list 2>/dev/null | md5)"; RP="$(git -C "$ROOTDIR" status --porcelain 2>/dev/null | md5)"

  # fixed temp repo: HEAD touches src/app.js (normal) + provider-router.py (protected) + .env (secret w/ sentinel),
  # commit-message BODY carries a distinct sentinel.
  local R="$TT/repo"; mkdir -p "$R"
  git -C "$R" init -q; git -C "$R" config user.email t@t.t; git -C "$R" config user.name t
  mkdir -p "$R/src" "$R/.claude/workers/providers"
  echo 'console.log(1)' > "$R/src/app.js"
  echo '# protected' > "$R/.claude/workers/providers/provider-router.py"
  printf 'API_KEY=%s\n' "$SENT_FILE" > "$R/.env"
  git -C "$R" add -A
  GIT_AUTHOR_DATE='2020-01-01T00:00:00 +0000' GIT_COMMITTER_DATE='2020-01-01T00:00:00 +0000' \
    git -C "$R" commit -q -m "test commit subject"$'\n\n'"body line with $SENT_MSG embedded"
  local TH TB TC TP
  TH="$(git -C "$R" rev-parse HEAD)"; TB="$(git -C "$R" rev-parse --abbrev-ref HEAD)"
  TC="$(git -C "$R" config --list | md5)"; TP="$(git -C "$R" status --porcelain | md5)"

  # AC2/AC3/AC4 — run packet against the temp repo
  local PK="$TT/pack.md"; run_packet "$PK" "$R" commit HEAD "v0.3.6-test" ""; local rc=$?
  local OUT; OUT="$(cat "$PK")"
  # AC2 channel 1+2: file sentinel + commit-body sentinel never in stdout OR --out
  if ! printf '%s' "$OUT" | grep -Fq "$SENT_FILE" && ! grep -Fq "$SENT_FILE" "$PK" \
     && ! printf '%s' "$OUT" | grep -Fq "$SENT_MSG" && ! grep -Fq "$SENT_MSG" "$PK"; then
    ok "AC2(1,2) file + commit-body sentinels never emitted (stdout AND --out; .env listed by name only)"
  else no "AC2(1,2) a sentinel leaked"; fi
  # AC2 channel 3: secret-pathed --verify-report refused unread
  printf 'TOKEN=%s\n' "$SENT_VR" > "$TT/secret.env"
  local PK3="$TT/pack3.md"; run_packet "$PK3" "$R" commit HEAD "v0.3.6-test" "$TT/secret.env" >/dev/null 2>&1
  if grep -q 'refused (secret-pattern)' "$PK3" && ! grep -Fq "$SENT_VR" "$PK3"; then
    ok "AC2(3) secret-pathed --verify-report refused UNREAD; sentinel never emitted"
  else no "AC2(3) verify-report secret leak/not-refused"; fi
  # AC3 — summary has all 3 names; protected scan flags provider-router.py not src/app.js; forbidden flags .env+STOP
  if printf '%s' "$OUT" | grep -q 'src/app.js' && printf '%s' "$OUT" | grep -q 'provider-router.py' && printf '%s' "$OUT" | grep -q '\.env' \
     && printf '%s' "$OUT" | awk '/## 2\./{s=1} /## 3\./{s=0} s' | grep -q 'provider-router.py' \
     && ! printf '%s' "$OUT" | awk '/## 2\./{s=1} /## 3\./{s=0} s' | grep -q 'src/app.js' \
     && printf '%s' "$OUT" | grep -q 'FORBIDDEN files present — STOP'; then
    ok "AC3 packet correctness: summary 3 names; protected=provider-router.py; forbidden=.env+STOP"
  else no "AC3 packet correctness"; fi
  # AC4 — forbidden present => exit 3 + STOP + residual block
  if [ "$rc" = 3 ] && printf '%s' "$OUT" | grep -q 'forbidden secret files present: YES'; then
    ok "AC4 forbidden STOP: exit==3 + STOP section + residual block"
  else no "AC4 forbidden exit/section (rc=$rc)"; fi
  # AC4 clean arm — a repo with no secret file => exit 0 + forbidden 'none'
  local RC2="$TT/clean"; mkdir -p "$RC2"; git -C "$RC2" init -q; git -C "$RC2" config user.email t@t.t; git -C "$RC2" config user.name t
  echo x > "$RC2/readme.md"; git -C "$RC2" add -A
  GIT_AUTHOR_DATE='2020-01-01T00:00:00 +0000' GIT_COMMITTER_DATE='2020-01-01T00:00:00 +0000' git -C "$RC2" commit -q -m "clean"
  local PKC="$TT/packc.md"; run_packet "$PKC" "$RC2" commit HEAD "clean" ""; local rcc=$?
  if [ "$rcc" = 0 ] && awk '/## 3\./{s=1} /## 4\./{s=0} s' "$PKC" | grep -q '^none$'; then
    ok "AC4 clean arm: exit==0 + forbidden section 'none'"
  else no "AC4 clean arm (rc=$rcc)"; fi

  # AC5 — verify-summary 3 cases (real tokens), using fixture reports
  printf '%s\n' '# Verification Report' 'Review-Verdict: critic=PASS codex=ACCEPT' '## Run ID' 'rid-1' '| x | 16 PASS / 0 FAIL |' '## Final Status' '**PASS** — green' > "$TT/rep_full.md"
  printf '%s\n' '# Verification Report' '## Run ID' 'rid-2' 'result 8/8' '## Final Status' '**PASS** — ok' > "$TT/rep_norv.md"
  local v1 v2 v3
  v1="$(verify_summary "$TT/rep_full.md")"; v2="$(verify_summary "$TT/rep_norv.md")"; v3="$(verify_summary "")"
  if printf '%s' "$v1" | grep -q 'Review-Verdict: critic=PASS codex=ACCEPT' && printf '%s' "$v1" | grep -q '16 PASS / 0 FAIL' && printf '%s' "$v1" | grep -q 'PASS' \
     && printf '%s' "$v2" | grep -q 'Review-Verdict: not present' && printf '%s' "$v2" | grep -q '8/8' \
     && printf '%s' "$v3" | grep -q 'no verification report provided'; then
    ok "AC5 verify-summary: 3 cases (Review-Verdict present / absent / no-report) with real tokens"
  else no "AC5 verify-summary"; fi

  # AC2 STRUCTURAL audit — operative source ONLY (exclude the audit block markers + comments) so the forbidden-primitive
  # patterns below do not self-match. Then assert no content-dumping git primitive is present.
  local OP="$TT/op.src"; sed '/AUDIT_BLOCK_START/,/AUDIT_BLOCK_END/d' "$SELFPATH" | grep -vE '^[[:space:]]*#' > "$OP"
  # >>>AUDIT_BLOCK_START (this block is excluded from $OP so its grep patterns cannot self-match)
  local sa=1
  grep -nE 'format-patch|cat-file|diff-tree' "$OP" >/dev/null && sa=0
  grep -nE '(show|log|diff)[^|]* (-p|--patch)( |$)' "$OP" >/dev/null && sa=0
  grep -n '%b' "$OP" >/dev/null && sa=0                                   # lowercase body format forbidden
  grep -nE 'git( -C [^ ]+| -C "[^"]+")? +show' "$OP" | grep -vE -- '-s|--name-status|--numstat|--stat|--name-only' >/dev/null && sa=0
  grep -nE 'git( -C [^ ]+| -C "[^"]+")? +diff ' "$OP" | grep -vE -- '--name-status|--numstat|--stat|--name-only' >/dev/null && sa=0
  # every %B occurrence must be immediately consumed by the anchored single-line grep
  if grep -n '%B' "$OP" | grep -vq "grep -m1 '\\^Review-Verdict:'"; then sa=0; fi
  grep -nE 'os\.environ|os\.getenv|getenv\(' "$OP" >/dev/null && sa=0
  grep -nE '\$\{?(GLM_API_KEY|DMC_OAUTHCLI_BIN|ANTHROPIC_API_KEY|OPENAI_API_KEY|ZHIPUAI_API_KEY)' "$OP" >/dev/null && sa=0
  [ "$sa" = 1 ] && ok "AC2 STRUCTURAL: no content-dumping git primitive; commit-body format only via anchored grep; no env/cred read" || no "AC2 STRUCTURAL: a forbidden primitive is present"
  # >>>AUDIT_BLOCK_END

  # AC6 — --out guard pinned pairs
  mkdir -p "$TT/sub"
  out_refused "$TT/sub/../benign.json" && out_refused ".env" && out_refused ".claude/hooks/x" \
    && out_refused "provider-router.py" \
    && { ln -sf "$ROOTDIR/.claude/hooks" "$TT/sub/hooks" 2>/dev/null; out_refused "$TT/sub/hooks/x"; } \
    && ! out_refused "$TT/benign.json" && ok "AC6 --out guard: benign-.. + protected/secret/symlink refused, benign allowed" || no "AC6 --out guard"

  # AC1 FINAL — neither the real repo NOR the temp repo mutated (HEAD + branch + config + porcelain pre==post)
  local rh rb rc2 rp th tb tc tp
  rh="$(git -C "$ROOTDIR" rev-parse HEAD)"; rb="$(git -C "$ROOTDIR" rev-parse --abbrev-ref HEAD)"
  rc2="$(git -C "$ROOTDIR" config --list | md5)"; rp="$(git -C "$ROOTDIR" status --porcelain | md5)"
  th="$(git -C "$R" rev-parse HEAD)"; tb="$(git -C "$R" rev-parse --abbrev-ref HEAD)"; tc="$(git -C "$R" config --list | md5)"; tp="$(git -C "$R" status --porcelain | md5)"
  if [ "$RH" = "$rh" ] && [ "$RB" = "$rb" ] && [ "$RC" = "$rc2" ] && [ "$RP" = "$rp" ] \
     && [ "$TH" = "$th" ] && [ "$TB" = "$tb" ] && [ "$TC" = "$tc" ] && [ "$TP" = "$tp" ]; then
    ok "AC1 read-only: real+temp repo HEAD/branch/config/porcelain pre==post (no mutation)"
  else no "AC1 read-only: a repo changed (HEAD/branch/config/porcelain)"; fi

  echo "  ---- self-test: PASS=$P FAIL=$F ----"; [ "$F" = 0 ]
}

# --- args ---
COMMIT=""; STAGED=0; REPO=""; VERIFY=""; OUT=""; MODE=run
while [ $# -gt 0 ]; do case "$1" in
  --commit) COMMIT="$2"; shift 2;; --staged) STAGED=1; shift;; --repo) REPO="$2"; shift 2;;
  --verify-report) VERIFY="$2"; shift 2;; --out) OUT="$2"; shift 2;;
  --self-test) MODE=selftest; shift;; -h|--help) sed -n '2,20p' "$0"; exit 0;;
  *) echo "review-packet: unknown arg $1" >&2; exit 2;;
esac; done

if [ "$MODE" = selftest ]; then
  echo "==== DMC REVIEW PACKET — SELF-TEST (no in-repo writes; \$TMPDIR only) ===="
  self_test; exit $?
fi

REPO="${REPO:-$ROOTDIR}"
[ -d "$REPO/.git" ] || git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1 || { echo "review-packet: --repo is not a git repo: $REPO" >&2; exit 2; }
MODEK=commit; REF="${COMMIT:-HEAD}"; [ "$STAGED" = 1 ] && MODEK=staged
if [ -n "$OUT" ]; then
  if out_refused "$OUT"; then echo "review-packet: --out target is a protected/secret path — REFUSED (writing nothing)" >&2; exit 2; fi
fi
PACK="$(mktemp)"; run_packet "$PACK" "$REPO" "$MODEK" "$REF" "${COMMIT:+commit $COMMIT}" "$VERIFY"; RC=$?
if [ -n "$OUT" ]; then cp "$PACK" "$OUT"; echo "review-packet: wrote $OUT" >&2; else cat "$PACK"; fi
rm -f "$PACK"
exit $RC
