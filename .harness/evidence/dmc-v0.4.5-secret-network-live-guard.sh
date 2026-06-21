#!/usr/bin/env bash
# DMC Secret / Network / Live-call Guard (v0.4.5) — ADVISORY / READ-ONLY, fail-closed, STATIC.
#
# Statically classifies a CANDIDATE action (a command string or a script's text) — it NEVER executes it — as ALLOWED
# (offline/safe) or BLOCKED. BLOCKED when the action would: read a secret-bearing path, make a live-provider call
# (--live/--allow-network/--allow-exec), or reach the network (curl/wget/nc/ssh/requests/urllib/...). Complements the
# runtime hooks (secret-guard.sh / pre-tool-guard.sh) with a pre-flight static check for autonomous-run actions. No
# network, no credential access, no execution.
#
# Usage:  secret-network-live-guard.sh --action "<command>"   |   --file <script>   |   --self-test
# Exit: 0 = ALLOWED, 1 = BLOCKED, 2 = usage.
set -u
set -o pipefail
SELFPATH="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/$(basename "$0")"
ROOTDIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

SECRET_PATH_RE='(^|[^A-Za-z0-9_.-])(\.env)([.][A-Za-z0-9_]+)*|\.pem([^A-Za-z]|$)|\.key([^A-Za-z]|$)|id_rsa|id_ed25519|\.p12|\.pfx|\.keystore|(^|/)credentials([^A-Za-z]|$)|/\.ssh/|\.aws/credentials|(^|/)\.npmrc|(^|/)\.netrc|(^|/)\.pgpass|service-account'
READ_VERB_RE='(^|[^A-Za-z])(cat|less|more|head|tail|grep|egrep|fgrep|awk|sed|read|open|xxd|od|strings|hexdump|tac|nl|cut|base64)([[:space:]])|(^|[[:space:]])source[[:space:]]|(^|[[:space:]])\.[[:space:]]|<[[:space:]]*[^<]'
ENV_DUMP_RE='(^|[;&|[:space:]])printenv([[:space:]]|$|\|)|(^|[;&|[:space:]])env([[:space:]]*$|[[:space:]]*\|)|export[[:space:]]+-p'
LIVE_RE='(--live|--allow-network|--allow-exec)'
NET_RE='(^|[^A-Za-z])(curl|wget|ncat|nc|scp|rsync|sftp|telnet|ftp|ssh)([[:space:]])|requests\.(get|post|put|patch|delete|head|request)|urllib\.(request|urlopen)|urlopen[[:space:]]*\(|http\.client|httpx[.(]|socket\.connect|fetch[[:space:]]*\(|axios\.|nc[[:space:]]+-'

classify() { # <action-text-file>  -> echoes verdict; return 0 ALLOWED / 1 BLOCKED
  local f="$1" txt stripped; txt="$(cat "$f" 2>/dev/null)"
  if printf '%s' "$txt" | grep -qE -- "$LIVE_RE"; then echo "BLOCKED:live-call (--live/--allow-network/--allow-exec opt-in present)"; return 1; fi
  if printf '%s' "$txt" | grep -qiE -- "$NET_RE"; then echo "BLOCKED:network (a network tool / client invocation present)"; return 1; fi
  if printf '%s' "$txt" | grep -qiE -- "$ENV_DUMP_RE"; then echo "BLOCKED:secret-read (env dump — printenv/env/export -p exposes credential vars)"; return 1; fi
  # secret-read: strip allowed template tokens (.env.example/.sample/.template) FIRST, then require a remaining secret
  # path token AND a read/access verb (fail-closed: a real .env read is not masked by a template token elsewhere).
  stripped="$(printf '%s' "$txt" | sed -E 's/[^[:space:]]*\.env\.(example|sample|template)[^[:space:]]*//g')"
  if printf '%s' "$stripped" | grep -qiE -- "$SECRET_PATH_RE" && printf '%s' "$txt" | grep -qE -- "$READ_VERB_RE"; then
    echo "BLOCKED:secret-read (a secret-bearing path is read/accessed)"; return 1
  fi
  echo "ALLOWED:offline/no-secret/no-network"; return 0
}

# ---------------------------------------------------------------- self-test (fixtures; no execution; no network)
self_test() {
  local P=0 F=0; ok(){ echo "  PASS $1"; P=$((P+1)); }; no(){ echo "  FAIL $1"; F=$((F+1)); }
  local TT; TT="$(mktemp -d)"; trap 'rm -rf "$TT"' RETURN
  local PRE; PRE="$(git -C "$ROOTDIR" status --porcelain 2>/dev/null | md5)"
  chk(){ printf '%s' "$2" > "$TT/a"; classify "$TT/a" >/dev/null; local rc=$?; [ "$rc" = "$3" ] && ok "$1" || no "$1 (rc=$rc want=$3)"; }

  # --- TRUE-POSITIVES: must BLOCK (rc 1) ---
  chk "TP1 cat .env => secret-read BLOCKED"                 'cat .env'                                              1
  chk "TP2 source /app/.env.production => secret-read"      'source /app/.env.production'                            1
  chk "TP3 grep KEY ~/.aws/credentials => secret-read"     'grep API_KEY ~/.aws/credentials'                        1
  chk "TP4 head server.key => secret-read"                 'head -5 server.key'                                     1
  chk "TP5 < .env redirect => secret-read"                 'while read l; do :; done < .env'                        1
  chk "TP6 --live --allow-network => live-call"            'bash adapter.sh --live --allow-network fixtures/x'      1
  chk "TP7 curl https => network"                          'curl -s https://api.example.com/v1/chat'               1
  chk "TP8 python requests.get => network"                 'python3 -c "import requests; requests.get(u)"'          1
  chk "TP9 wget http => network"                           'wget http://example.com/file -O out'                   1
  chk "TP10 printenv (env dump) => secret-read"            'printenv | grep KEY'                                    1

  # --- FALSE-POSITIVES: must ALLOW (rc 0) ---
  chk "FP1 cat .env.example => allowed (template)"         'cat .env.example'                                       0
  chk "FP2 cat README.md => allowed"                       'cat README.md'                                          0
  chk "FP3 --mock fixture => allowed (offline)"            'bash adapter.sh --mock fixtures/ok.json --out r.json'   0
  chk "FP4 echo mentions .env => allowed (no read-verb)"   'echo "see .env for config notes"'                       0
  chk "FP5 comment with a URL => allowed (no net tool)"    '# fetch the docs at https://example.com/guide'          0
  chk "FP6 grep src file => allowed (no secret token)"     'grep -n pattern src/app.js'                             0
  chk "FP7 cp .env.sample => allowed (template)"           'cp .env.sample .env.local.notes'                        0
  chk "FP8 git diff => allowed"                            'git diff --cached --name-only'                          0

  # AC read-only: repo byte-unchanged
  [ "$(git -C "$ROOTDIR" status --porcelain 2>/dev/null | md5)" = "$PRE" ] && ok "AC read-only: repo byte-unchanged (no execution/network)" || no "AC repo changed"

  echo "  ---- self-test: PASS=$P FAIL=$F ----"; [ "$F" = 0 ]
}

ACTION=""; FILE=""; MODE=run
while [ $# -gt 0 ]; do case "$1" in
  --action) ACTION="$2"; shift 2;; --file) FILE="$2"; shift 2;; --self-test) MODE=selftest; shift;;
  -h|--help) sed -n '2,12p' "$0"; exit 0;; *) echo "secret-network-live-guard: unknown arg $1" >&2; exit 2;;
esac; done
if [ "$MODE" = selftest ]; then echo "==== DMC SECRET/NETWORK/LIVE GUARD — SELF-TEST ===="; self_test; exit $?; fi
TMPF="$(mktemp)"; trap 'rm -f "$TMPF"' EXIT
if [ -n "$ACTION" ]; then printf '%s' "$ACTION" > "$TMPF"
elif [ -n "$FILE" ] && [ -f "$FILE" ]; then cp "$FILE" "$TMPF"
else echo "secret-network-live-guard: --action <cmd> or --file <script> required" >&2; exit 2; fi
classify "$TMPF"; exit $?
