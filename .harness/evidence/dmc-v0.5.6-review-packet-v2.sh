#!/usr/bin/env bash
# DMC Review Packet Generator v2 (v0.5.6) — ADVISORY / READ-ONLY, deterministic, inert unless invoked.
#
# Generates a NAMES-ONLY, secret-safe review packet for a base..head range, by DEFAULT from git METADATA only — never
# file content, never a commit BODY (%b), never a diff/patch. It lists: base/head, the name-status file list, the stat,
# protected-surface touches, forbidden/secret paths, value-blind-redacted commit SUBJECTS (%s), and test summaries
# extracted ONLY from an allowlisted canonical `.harness/verification/*.md` report. Content-extraction primitives
# (commit-body %b, patch/diff -p/cat-file/log -p/diff-tree/format-patch/show <blob>) are structurally absent.
# Reads no env/.env/credential; no network/live call. Advisory only — not an enforcement gate.
#
# Usage: dmc-v0.5.6-review-packet-v2.sh --base <sha> --head <sha> [--repo <dir>] [--verify-report <path>] [--out <file>]
#          | --self-test
# Exit: 0 = packet emitted, 2 = usage/refused (e.g. unapproved report path).
set -u
set -o pipefail
export PYTHONDONTWRITEBYTECODE=1
SELFPATH="$(cd "$(dirname "$0")" 2>/dev/null && pwd -P)/$(basename "$0")"
ROOTDIR="$(cd "$(dirname "$SELFPATH")/../.." 2>/dev/null && pwd -P || true)"
[ -n "$ROOTDIR" ] || ROOTDIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
repo_hash() { git -C "$ROOTDIR" status --porcelain 2>/dev/null | python3 -c 'import hashlib,sys; sys.stdout.write(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())'; }

PROT_RE='(^|/)(\.env)(\.|$)|\.pem$|\.key$|id_rsa|id_ed25519|credentials|secret|\.p12$|\.pfx$|\.keystore$|\.claude/hooks|provider-router\.py'
# --out is FAIL-CLOSED (C7): allow ONLY a NEW (non-existing) file whose canonical parent is a benign temp/work dir OUTSIDE
# the repo. Refuse traversal, .env*/credential/key/token/protected paths, symlinks (target or parent), already-existing
# targets (no overwrite), anything in the repo tree or tracked, system paths, $HOME hidden control files (dotfile basename
# or a .ssh/.config/... control dir), and any parent NOT under an allowlisted temp root. No env var is read. 0=REFUSE,1=ALLOW.
out_refused() { local raw="$1"
  [ -z "$raw" ] && return 0
  printf '%s' "$raw" | grep -qE '(^|/)\.\.(/|$)' && return 0
  case "$raw" in *.env|*.env.local|*.env.*) case "$raw" in *.example|*.sample|*.template) ;; *) return 0;; esac;; esac
  printf '%s' "$raw" | grep -qiE "$PROT_RE" && return 0
  [ -e "$raw" ] && return 0
  [ -L "$raw" ] && return 0
  local parent base cparent canon root croot ok; parent="$(dirname "$raw" 2>/dev/null)"; base="$(basename "$raw")"
  [ -L "$parent" ] && return 0
  cparent="$(cd "$parent" 2>/dev/null && pwd -P)" || return 0; canon="$cparent/$base"
  [ -e "$canon" ] && return 0
  printf '%s' "$canon" | grep -qiE "$PROT_RE" && return 0
  case "$canon/" in "$ROOTDIR"/*) return 0;; esac
  git -C "$ROOTDIR" ls-files --error-unmatch -- "$canon" >/dev/null 2>&1 && return 0
  printf '%s' "$canon" | grep -qE '^/(etc|usr|bin|sbin|System|Library|var/db|var/root|boot|dev|proc)(/|$)|^/private/etc(/|$)' && return 0
  case "$base" in .*) return 0;; esac
  printf '%s' "$canon" | grep -qE '/\.(ssh|config|gnupg|aws|kube|docker)(/|$)|/\.(gitconfig|git-credentials|netrc|npmrc|zshrc|bashrc|profile)$' && return 0
  ok=1
  for root in /tmp /private/tmp /var/folders /private/var/folders /var/tmp /private/var/tmp; do
    croot="$(cd "$root" 2>/dev/null && pwd -P)" || continue
    case "$cparent/" in "$croot"/*) ok=0; break;; esac
  done
  [ "$ok" = 0 ] || return 0
  return 1
}

# --verify-report allowlist: ONLY a canonical, non-symlink, in-tree `.harness/verification/*.md` path is read.
report_ok() { local repo="$1" raw="$2"
  [ -L "$raw" ] && return 1
  printf '%s' "$raw" | grep -qE '(^|/)\.\.(/|$)' && return 1
  case "$raw" in *.md) : ;; *) return 1;; esac
  local parent base cparent canon; parent="$(dirname "$raw" 2>/dev/null)"; base="$(basename "$raw")"
  [ -L "$parent" ] && return 1
  cparent="$(cd "$parent" 2>/dev/null && pwd -P)" || return 1; canon="$cparent/$base"
  local crepo; crepo="$(cd "$repo" 2>/dev/null && pwd -P)" || return 1   # canonicalize repo too (macOS /var -> /private/var)
  case "$canon" in "$crepo"/.harness/verification/*.md) : ;; *) return 1;; esac
  printf '%s' "$canon" | grep -qiE "$PROT_RE" && return 1
  return 0
}

generate() { # <repo> <base> <head> <report|"">
  local repo="$1" base="$2" head="$3" report="$4"
  # fail CLOSED on an invalid/unknown base or head — never emit an empty "(none)" packet that masks a real range (Codex)
  git -C "$repo" rev-parse --verify --quiet "$base^{commit}" >/dev/null 2>&1 || { echo "review-packet: --base is not a valid commit — REFUSED" >&2; return 2; }
  git -C "$repo" rev-parse --verify --quiet "$head^{commit}" >/dev/null 2>&1 || { echo "review-packet: --head is not a valid commit — REFUSED" >&2; return 2; }
  local TMP; TMP="$(mktemp -d)" || { echo "review-packet: mktemp failed" >&2; return 2; }
  git -C "$repo" diff --name-status "$base..$head" > "$TMP/ns" 2>/dev/null
  git -C "$repo" diff --numstat "$base..$head" > "$TMP/numstat" 2>/dev/null
  git -C "$repo" log --no-patch --format='%h %s' "$base..$head" > "$TMP/log" 2>/dev/null   # subject line ONLY (no body)
  local rep="$TMP/empty"; : > "$TMP/empty"
  if [ -n "$report" ]; then
    if report_ok "$repo" "$report"; then cp "$report" "$TMP/rep" 2>/dev/null && rep="$TMP/rep"; else
      echo "review-packet: --verify-report REFUSED (not an allowlisted canonical .harness/verification/*.md realpath)" >&2; rm -rf "$TMP"; return 2; fi
  fi
  python3 - "$base" "$head" "$TMP/ns" "$TMP/numstat" "$TMP/log" "$rep" <<'PY'
import sys,re
base,head,nsf,numf,logf,repf=sys.argv[1:7]
UNSAFE=re.compile(r'sk-[A-Za-z0-9_-]{12,}|AKIA[0-9A-Z]{8,}|gh[opsu]_[A-Za-z0-9]{12,}|github_pat_[A-Za-z0-9_]{12,}|'
                  r'glpat-[A-Za-z0-9_-]{12,}|AIza[0-9A-Za-z_-]{16,}|ya29\.[A-Za-z0-9._-]{8,}|eyJ[A-Za-z0-9_-]{6,}\.eyJ[A-Za-z0-9_-]{6,}|(BEGIN|END)[A-Z ]*PRIVATE KEY|'
                  r'[Bb]earer\s+[A-Za-z0-9._-]{12,}|xox[baprs]-[A-Za-z0-9-]{6,}|(password|passwd|secret|token|api[_-]?key|client_secret)\s*[=:]\s*\S{4,}|'
                  r'[sp]k_(live|test)_[A-Za-z0-9]{10,}|npm_[A-Za-z0-9]{16,}|AccountKey=[A-Za-z0-9+/=]{10,}|[a-z][a-z0-9+.-]*://[^/\s:@]+:[^/\s:@]+@',re.IGNORECASE)
def redact(s):
    s=s.replace("\n"," ").replace("\r"," ")
    return UNSAFE.sub("[redacted]",s)
PROT=re.compile(r'\.claude/workers/providers/|provider-router\.py|(^|/)ROUTING\.md$|PROVIDER_CONTRACT\.md|'
                r'WORKER_(TASK|RESULT|REVIEW)_SCHEMA\.md|\.claude/hooks/|(^|/)dmc-glm-smoke$|\.harness/schemas/.*\.schema\.md$|'
                r'(secret-guard|pre-tool-guard|scope-guard|stop-verify-gate)',re.IGNORECASE)
FORBID=re.compile(r'(^|/)\.env($|\.)|\.pem$|\.key$|id_rsa|id_ed25519|(^|/)credentials|\.aws/credentials|/\.ssh/',re.IGNORECASE)
AUTOLOG=re.compile(r'\.harness/evidence/.*\.md$',re.IGNORECASE)
def rd(p):
    try: return open(p,encoding="utf-8",errors="replace").read()
    except Exception: return ""
ns=[l for l in rd(nsf).splitlines() if l.strip()]
files=[]; prot=[]; forb=[]; autolog=[]
for l in ns:
    parts=l.split("\t")
    if len(parts)<2: continue
    st=parts[0][:1]; path=parts[-1]
    files.append((st,path))
    if FORBID.search(path): forb.append(path)
    elif PROT.search(path): prot.append(path)
    if AUTOLOG.search(path): autolog.append(path)
add=dele=0; nf=0
for l in rd(numf).splitlines():
    c=l.split("\t")
    if len(c)>=2:
        nf+=1
        try: add+=int(c[0])
        except Exception: pass
        try: dele+=int(c[1])
        except Exception: pass
subs=[]
for l in rd(logf).splitlines():
    l=l.strip()
    if not l: continue
    sp=l.split(" ",1); h=sp[0]; sub=sp[1] if len(sp)>1 else ""
    subs.append((h,redact(sub)))
# test summaries — ONLY anchored 'PASS=N FAIL=M' or 'N PASS / M FAIL' lines from the allowlisted report
tests=[]
for l in rd(repf).splitlines():
    m=re.search(r'PASS=(\d+)\s+FAIL=(\d+)',l) or re.search(r'(\d+)\s*PASS\s*/\s*(\d+)\s*FAIL',l)
    if m: tests.append("%s PASS / %s FAIL"%(m.group(1),m.group(2)))
o=["# DMC Review Packet v2 — %s..%s"%(base,head),
   "- base: %s   head: %s"%(base,head),
   "- stat: +%d / -%d across %d files"%(add,dele,nf),
   "- files changed (name-status; names only):"]
# detection runs on the RAW path (above); every EMITTED path is value-blind redacted so a token-shaped filename cannot leak
o += ["  - %s  %s"%(st,redact(p)) for st,p in files] or ["  - (none)"]
o += ["- protected-surface touches:"]; o += ["  - %s"%redact(p) for p in prot] or []; o += (["  - (none)"] if not prot else [])
o += ["- forbidden/secret paths (should be NONE):"]; o += ["  - %s"%redact(p) for p in forb] or []; o += (["  - (none)"] if not forb else [])
o += ["- excluded auto-log evidence (.harness/evidence/*.md — not a review artifact):"]; o += ["  - %s"%redact(p) for p in autolog] or []; o += (["  - (none)"] if not autolog else [])
o += ["- commit subjects (value-blind redacted; NO commit body):"]; o += ["  - %s %s"%(h,s) for h,s in subs] or ["  - (none)"]
o += ["- test summary (from allowlisted .harness/verification report only):"]; o += ["  - %s"%t for t in tests] or ["  - (none)"]
o += ["- advisory: names-only metadata; no file content / no diff / no commit body — review before merge"]
print("\n".join(o))
PY
  rm -rf "$TMP"
}

self_test() {
  local P=0 F=0; ok(){ echo "  PASS $1"; P=$((P+1)); }; no(){ echo "  FAIL $1"; F=$((F+1)); }
  local TT; TT="$(mktemp -d)" || { echo "  FATAL: mktemp -d failed"; return 2; }; [ -d "$TT" ] || { echo "  FATAL: temp dir missing"; return 2; }; trap 'rm -rf "$TT"' RETURN
  local PRE; PRE="$(repo_hash)"
  # build a fixture repo with: a malicious commit subject+body, a protected file, an auto-log .md, a docs file
  local R="$TT/r"; mkdir -p "$R/docs" "$R/.claude/workers/providers/glm-api" "$R/.harness/evidence" "$R/.harness/verification"
  git -C "$R" init -q; git -C "$R" config user.email t@t.t; git -C "$R" config user.name t
  echo base > "$R/docs/a.md"; git -C "$R" add -A; GIT_AUTHOR_DATE='2020-01-01T00:00:00 +0000' GIT_COMMITTER_DATE='2020-01-01T00:00:00 +0000' git -C "$R" commit -q -m base
  local BASE; BASE="$(git -C "$R" rev-parse HEAD)"
  printf 'x\n' > "$R/.claude/workers/providers/glm-api/adapter.py"
  printf 'log\n' > "$R/.harness/evidence/dmc-v0.5.x-foo.md"
  printf 'doc2\n' > "$R/docs/b.md"
  printf 'tok\n' > "$R/docs/sk-ABCDEFGHIJKLMNOP12345.md"   # filename embeds a secret-shaped token (value-blind redaction target)
  printf 'jwt\n' > "$R/docs/jwt-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.md"   # filename embeds a JWT (C5)
  git -C "$R" add -A
  GIT_AUTHOR_DATE='2020-01-02T00:00:00 +0000' GIT_COMMITTER_DATE='2020-01-02T00:00:00 +0000' \
    git -C "$R" commit -q -m "feat: leak ghp_ABCDEFGHIJKLMNOPQRSTUVWX in subject" -m "BODY: secret sk-ABCDEFGHIJKLMNOPQRSTUV must never appear"
  local HEAD; HEAD="$(git -C "$R" rev-parse HEAD)"
  printf '# verification\n- AC1\n  ---- self-test: PASS=7 FAIL=0 ----\n' > "$R/.harness/verification/dmc-v0.5.x-foo.md"

  local pkt; pkt="$(generate "$R" "$BASE" "$HEAD" "")"

  # AC1 malicious commit SUBJECT secret is value-blind redacted; commit BODY never appears at all
  { ! printf '%s' "$pkt" | grep -q 'ghp_ABCDEFGHIJKLMNOPQRSTUVWX' && printf '%s' "$pkt" | grep -q '\[redacted\]' \
    && ! printf '%s' "$pkt" | grep -q 'sk-ABCDEFGHIJKLMNOPQRSTUV' && ! printf '%s' "$pkt" | grep -qi 'BODY:'; } \
    && ok "AC1 commit subject redacted; commit body never in packet" || no "AC1 subject/body leak"
  # AC2 names-only: the packet contains file PATHS but no file CONTENT (the word 'doc2'/'base' content not present)
  { printf '%s' "$pkt" | grep -q 'docs/b.md' && ! printf '%s' "$pkt" | grep -q '^doc2$'; } \
    && ok "AC2 names-only: paths present, file content absent" || no "AC2 content leak"
  # AC3 protected-surface scan works structurally
  printf '%s' "$pkt" | awk '/protected-surface touches:/{f=1;next} /forbidden\/secret/{f=0} f' | grep -q 'adapter.py' \
    && ok "AC3 protected-surface scan lists the provider adapter path" || no "AC3 protected scan"
  # AC4 auto-log evidence .md identified as excluded (not a review artifact)
  printf '%s' "$pkt" | awk '/excluded auto-log/{f=1;next} /commit subjects/{f=0} f' | grep -q 'dmc-v0.5.x-foo.md' \
    && ok "AC4 auto-log evidence .md flagged excluded" || no "AC4 auto-log not excluded"
  # AC5 test summary extracted from the allowlisted report (anchored counts only)
  printf '%s' "$(generate "$R" "$BASE" "$HEAD" "$R/.harness/verification/dmc-v0.5.x-foo.md")" | grep -q '7 PASS / 0 FAIL' \
    && ok "AC5 test summary extracted from allowlisted .harness/verification report" || no "AC5 test summary"
  # AC6 unapproved report path refused: symlink, traversal, out-of-tree, secret-named, non-verification dir
  ln -s "$R/docs/a.md" "$R/.harness/verification/evil.md" 2>/dev/null
  local r1 r2 r3 r4
  generate "$R" "$BASE" "$HEAD" "$R/.harness/verification/evil.md" >/dev/null 2>&1; [ $? = 2 ] && r1=1 || r1=0     # symlink
  generate "$R" "$BASE" "$HEAD" "$R/../etc/passwd" >/dev/null 2>&1; [ $? = 2 ] && r2=1 || r2=0                      # traversal/out-of-tree
  generate "$R" "$BASE" "$HEAD" "$R/docs/a.md" >/dev/null 2>&1; [ $? = 2 ] && r3=1 || r3=0                          # not under verification/
  generate "$R" "$BASE" "$HEAD" "$R/.harness/verification/credentials.md" >/dev/null 2>&1; [ $? = 2 ] && r4=1 || r4=0  # secret-named
  { [ "$r1" = 1 ] && [ "$r2" = 1 ] && [ "$r3" = 1 ] && [ "$r4" = 1 ]; } \
    && ok "AC6 unapproved report path REFUSED (symlink/traversal/non-verification/secret-named)" || no "AC6 report allowlist (r=$r1$r2$r3$r4)"
  # AC7 STRUCTURAL ban: no content-extraction primitive in the operative source
  local OP; OP="$(sed '/AUDIT_BLOCK_START/,/AUDIT_BLOCK_END/d' "$SELFPATH" | grep -vE '^[[:space:]]*#')"
  # >>>AUDIT_BLOCK_START
  ! printf '%s' "$OP" | grep -nE "%b|%B|format-patch|cat-file|diff-tree|--patch|(log|diff)[[:space:]]+-p([[:space:]]|\$)|show[[:space:]]+[0-9a-f]{7,}|(^|[^A-Za-z])(curl|wget)([[:space:]])| --live | --allow-network|os\.environ|getenv|printenv|HASH_CMD|\\\$\{DMC_" >/dev/null \
    && ok "AC7 structural ban: no %b/patch/diff-content/cat-file/show-blob/net/env-hash primitive in operative source" || no "AC7 banned primitive present"
  # >>>AUDIT_BLOCK_END
  # AC8 deterministic + env-independent
  local b1; b1="$(generate "$R" "$BASE" "$HEAD" "")"
  [ "$(generate "$R" "$BASE" "$HEAD" "")" = "$b1" ] && local det=1 || local det=0
  local diff_ok=1 v; for v in GLM_API_KEY ANTHROPIC_API_KEY DMC_PACKET; do [ "$(env "$v=x" bash -c 'true'; generate "$R" "$BASE" "$HEAD" "")" = "$b1" ] || diff_ok=0; done
  { [ "$det" = 1 ] && [ "$diff_ok" = 1 ]; } && ok "AC8 deterministic + env-independent" || no "AC8 non-deterministic/env-dependent"
  # AC9 env-hash injection
  # >>>AUDIT_BLOCK_START  (hostile-input test; excluded from the operative-source audit)
  local SENT="$TT/sentinel" FAKE="$TT/fakehash"; printf '#!/bin/sh\ntouch "%s"\necho PWNED\n' "$SENT" > "$FAKE"; chmod +x "$FAKE"
  local hb hh; hb="$(repo_hash)"; hh="$(DMC_HASH_CMD="$FAKE" repo_hash)"
  { [ ! -e "$SENT" ] && [ -n "$hb" ] && [ "$hb" = "$hh" ]; } && ok "AC9 env-hash injection: hostile DMC_HASH_CMD never read/executed" || no "AC9 env-controlled hash executed"
  # >>>AUDIT_BLOCK_END
  # AC11 (HARDENING / both auditors) a changed-FILE PATH that embeds a secret-shaped token is value-blind redacted
  { ! printf '%s' "$pkt" | grep -q 'sk-ABCDEFGHIJKLMNOP12345' && printf '%s' "$pkt" | grep -q 'docs/\[redacted\].md'; } \
    && ok "AC11 changed file path with secret-shaped token is value-blind redacted in the packet (no metadata leak)" || no "AC11 path token leak"
  # AC14 (HARDENING / C5) a JWT-shaped token (eyJ...eyJ...; a bearer credential) in a changed path is value-blind redacted
  { ! printf '%s' "$pkt" | grep -q 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9' && printf '%s' "$pkt" | grep -q 'docs/jwt-\[redacted\].md'; } \
    && ok "AC14 JWT-shaped token in a changed path is value-blind redacted (C5 regex parity with v0.5.3)" || no "AC14 JWT leak in packet"
  # AC12 (HARDENING / Codex) an invalid base or head fails CLOSED (refused) — never an empty "(none)" packet masking the range
  local rb rh
  generate "$R" "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef" "$HEAD" "" >/dev/null 2>&1; [ $? = 2 ] && rb=1 || rb=0
  generate "$R" "$BASE" "notarealref" "" >/dev/null 2>&1; [ $? = 2 ] && rh=1 || rh=0
  { [ "$rb" = 1 ] && [ "$rh" = 1 ]; } \
    && ok "AC12 invalid base/head => REFUSED (fail-closed, no empty packet masking the range)" || no "AC12 bad range not refused (rb=$rb rh=$rh)"

  # AC13 (HARDENING / C7) --out is FAIL-CLOSED: allow ONLY a NEW file in a benign temp/work dir OUTSIDE the repo
  local C7D="$TT/c7out"; mkdir -p "$C7D"
  local c7_new="$C7D/pkt_new.md" c7_exist="$C7D/pkt_exist.md"; : > "$c7_exist"
  ln -s "$c7_new" "$C7D/pkt_link.md" 2>/dev/null
  local r_new r_exist r_home r_etc r_intree r_sym r_trav r_dot
  out_refused "$c7_new"; r_new=$?
  out_refused "$c7_exist"; r_exist=$?
  out_refused "${HOME:-/root}/.dmc_c7_sentinel.md"; r_home=$?
  out_refused "/etc/passwd"; r_etc=$?
  out_refused "$ROOTDIR/docs/c7_intree.md"; r_intree=$?
  out_refused "$C7D/pkt_link.md"; r_sym=$?
  out_refused "$C7D/../c7out/../x.md"; r_trav=$?
  out_refused "$C7D/.hidden.md"; r_dot=$?
  { [ "$r_new" = 1 ] && [ "$r_exist" = 0 ] && [ "$r_home" = 0 ] && [ "$r_etc" = 0 ] && [ "$r_intree" = 0 ] && [ "$r_sym" = 0 ] && [ "$r_trav" = 0 ] && [ "$r_dot" = 0 ]; } \
    && ok "AC13 C7 --out guard: NEW temp file ALLOWED; existing/home-dotfile/etc-passwd/in-tree/symlink/traversal/dotfile REFUSED" \
    || no "AC13 C7 guard (new=$r_new exist=$r_exist home=$r_home etc=$r_etc intree=$r_intree sym=$r_sym trav=$r_trav dot=$r_dot)"
  # AC13b end-to-end: --out NEW temp path WRITES (exit 0); --out /etc/passwd REFUSED (exit 2, no OS write)
  local c7_e2e="$C7D/e2e.md" rc_e2e rc_etc
  bash "$SELFPATH" --repo "$R" --base "$BASE" --head "$HEAD" --out "$c7_e2e" >/dev/null 2>&1; rc_e2e=$?
  bash "$SELFPATH" --repo "$R" --base "$BASE" --head "$HEAD" --out /etc/passwd >/dev/null 2>&1; rc_etc=$?
  { [ "$rc_e2e" = 0 ] && [ -s "$c7_e2e" ] && [ "$rc_etc" = 2 ]; } \
    && ok "AC13b C7 end-to-end: --out new temp path writes (exit 0); --out /etc/passwd REFUSED by guard (exit 2)" \
    || no "AC13b C7 e2e (rc_e2e=$rc_e2e wrote=$([ -s "$c7_e2e" ] && echo y || echo n) etc=$rc_etc)"

  # AC15 (C5 broadening) Stripe sk_/pk_live_/test_, npm_, embedded-credential URLs, and AccountKey= are redacted in changed
  # PATHS and commit SUBJECTS (the prior prefix allowlist missed these well-known secret formats); names-only stays intact.
  local R2="$TT/r2"; mkdir -p "$R2/docs"
  git -C "$R2" init -q; git -C "$R2" config user.email t@t.t; git -C "$R2" config user.name t
  echo base > "$R2/docs/a.md"; git -C "$R2" add -A; GIT_AUTHOR_DATE='2020-01-01T00:00:00 +0000' GIT_COMMITTER_DATE='2020-01-01T00:00:00 +0000' git -C "$R2" commit -q -m base
  local B2; B2="$(git -C "$R2" rev-parse HEAD)"
  printf 'x\n' > "$R2/docs/synstrp_51HxQ2eLkj8aBcDeFgHiJkLmN.md"
  printf 'x\n' > "$R2/docs/npm_AbCdEf1234567890GhIjKlMnOp.md"
  git -C "$R2" add -A
  GIT_AUTHOR_DATE='2020-01-02T00:00:00 +0000' GIT_COMMITTER_DATE='2020-01-02T00:00:00 +0000' \
    git -C "$R2" commit -q -m "chore: rotate postgres://user:p4ssw0rd@db.host/app and AccountKey=AbCdEf1234567890Xx=="
  local H2; H2="$(git -C "$R2" rev-parse HEAD)"
  local pkt2; pkt2="$(generate "$R2" "$B2" "$H2" "")"
  { ! printf '%s' "$pkt2" | grep -q 'synstrp_51HxQ2eLkj8aBcDeFgHiJkLmN' \
    && ! printf '%s' "$pkt2" | grep -q 'npm_AbCdEf1234567890GhIjKlMnOp' \
    && ! printf '%s' "$pkt2" | grep -q 'p4ssw0rd' \
    && ! printf '%s' "$pkt2" | grep -q 'AccountKey=AbCdEf1234567890Xx' \
    && printf '%s' "$pkt2" | grep -q 'docs/\[redacted\].md' \
    && printf '%s' "$pkt2" | grep -q 'rotate \[redacted\]'; } \
    && ok "AC15 C5 broadening: Stripe synstrp_ / npm_ / credential-URL / AccountKey redacted in paths+subjects (no raw secret); names-only intact" || no "AC15 broadened-secret leak"

  # AC10 read-only: real repo byte-unchanged (fixture work confined to $TMPDIR)
  { [ -n "$PRE" ] && [ "$(repo_hash)" = "$PRE" ]; } && ok "AC10 read-only: real repo byte-unchanged (deterministic sha256)" || no "AC10 repo changed"

  echo "  ---- self-test: PASS=$P FAIL=$F ----"; [ "$F" = 0 ]
}

BASE=""; HEAD=""; REPO=""; REPORT=""; OUT=""; RUN=run
while [ $# -gt 0 ]; do case "$1" in
  --base) BASE="$2"; shift 2;; --head) HEAD="$2"; shift 2;; --repo) REPO="$2"; shift 2;; --verify-report) REPORT="$2"; shift 2;; --out) OUT="$2"; shift 2;;
  --self-test) RUN=selftest; shift;; -h|--help) sed -n '2,12p' "$0"; exit 0;;
  *) echo "review-packet: unknown arg $1" >&2; exit 2;;
esac; done
if [ "$RUN" = selftest ]; then echo "==== DMC REVIEW PACKET v2 — SELF-TEST ===="; self_test; exit $?; fi
REPO="${REPO:-$ROOTDIR}"
[ -n "$BASE" ] && [ -n "$HEAD" ] || { echo "review-packet: --base <sha> --head <sha> required (or --self-test)" >&2; exit 2; }
if [ -n "$OUT" ]; then out_refused "$OUT" && { echo "review-packet: --out REFUSED — must be a NEW file in a temp/work dir outside the repo (not in-tree/tracked/secret/system/home-dotfile/existing)" >&2; exit 2; }; generate "$REPO" "$BASE" "$HEAD" "$REPORT" > "$OUT"; rc=$?; echo "review-packet: wrote $OUT" >&2; exit $rc; fi
generate "$REPO" "$BASE" "$HEAD" "$REPORT"; exit $?
