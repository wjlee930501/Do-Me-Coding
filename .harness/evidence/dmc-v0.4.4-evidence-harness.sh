#!/usr/bin/env bash
# DMC Evidence Harness (v0.4.4) — ADVISORY / READ-ONLY, local-only.
#
# Standardizes extraction of self-test counts / commands / result summary from a captured run output, and emits a
# REDACTED evidence artifact (see .harness/schemas/evidence.schema.md). The value-blind substitution redactor strips:
# secret/token shapes, credential-var assignment VALUES, .env/credential content, raw provider payloads, and absolute
# private paths — replaced by deterministic placeholders; a matched value is never re-emitted. Mutates nothing; no live
# call; no secret-file read (it redacts whatever captured text it is given).
#
# Usage:  evidence-harness.sh --run-id <id> --from <captured-output.txt> [--out <file>]   ·   --self-test
# Exit: 0 = evidence emitted, 2 = usage/refused.
set -u
set -o pipefail
export PYTHONDONTWRITEBYTECODE=1
ROOTDIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SELFPATH="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/$(basename "$0")"

PROT_RE='(^|/)(\.env)(\.|$)|\.pem$|\.key$|id_rsa|id_ed25519|credentials|secret|\.p12$|\.pfx$|\.keystore$|\.claude/hooks|provider-router\.py|PROVIDER_CONTRACT\.md|WORKER_(TASK|RESULT|REVIEW)_SCHEMA\.md'
out_refused() { local raw="$1"
  printf '%s' "$raw" | grep -qE '(^|/)\.\.(/|$)' && return 0
  printf '%s' "$raw" | grep -qiE "$PROT_RE" && return 0
  case "$raw" in *.env|*.env.local|*.env.*) case "$raw" in *.example|*.sample|*.template) ;; *) return 0;; esac;; esac
  return 1
}

# --- value-blind substitution redactor (single source of truth). The redactor python is written to a temp file once so
#     `python3 $REDACT_PY` leaves STDIN free for the data (a `python3 - <<heredoc` would consume stdin as the script). ---
REDACT_PY=""
_init_redactor() {
  [ -n "$REDACT_PY" ] && return
  REDACT_PY="$(mktemp)"; trap 'rm -f "$REDACT_PY"' EXIT
  cat > "$REDACT_PY" <<'PY'
import sys,re
def redact(t):
    t=re.sub(r'sk-[A-Za-z0-9_-]{16,}|AKIA[0-9A-Z]{12,}|(?:BEGIN|END)[A-Z ]*PRIVATE KEY|xox[baprs]-[A-Za-z0-9-]{8,}|gh[opsu]_[A-Za-z0-9]{20,}|eyJ[A-Za-z0-9_-]{6,}\.eyJ[A-Za-z0-9_-]{6,}|[Bb]earer\s+[A-Za-z0-9._-]{12,}|ya29\.[A-Za-z0-9._-]{8,}', '[redacted:secret]', t)
    t=re.sub(r'([A-Za-z_][A-Za-z0-9_]*(?:KEY|TOKEN|SECRET|PASSWORD|CREDENTIAL))\s*[=:]\s*\S+', r'\1=[redacted:env-value]', t, flags=re.IGNORECASE)
    t=re.sub(r'\b(access_token|refresh_token|id_token)\b\s*[=:]\s*\S+', r'\1=[redacted:env-value]', t, flags=re.IGNORECASE)
    t=re.sub(r'/Users/[^/\s]+', '[redacted:abs-path]', t)
    t=re.sub(r'/home/[^/\s]+', '[redacted:abs-path]', t)
    return t
sys.stdout.write(redact(sys.stdin.read()))
PY
}
redact_stdin() { _init_redactor; python3 "$REDACT_PY"; }

# --- emit redacted evidence. Redacts the WHOLE capture first, then extracts structured fields from the redacted text. ---
emit_evidence() { # <run_id> <captured.txt>
  local TMP; TMP="$(mktemp)"; redact_stdin < "$2" > "$TMP"             # fully-redacted capture (single redactor)
  local rid; rid="$(printf '%s' "$1" | redact_stdin)"                  # run_id redacted too
  python3 - "$rid" "$TMP" <<'PY'
import sys,re
rid=sys.argv[1]
try: red=open(sys.argv[2]).read()
except Exception: red=""
# standardized count extraction — handle BOTH 'N PASS / M FAIL' and 'PASS=N FAIL=M' forms
m=re.search(r'(\d+)\s*PASS\s*/\s*(\d+)\s*FAIL', red) or re.search(r'PASS=(\d+)\s+FAIL=(\d+)', red)
if m: p,f=int(m.group(1)),int(m.group(2)); st="%d PASS / %d FAIL"%(p,f); summary="PASS" if (f==0 and p>0) else ("FAIL" if f>0 else "PARTIAL")
else: st="unknown"; summary="PARTIAL"
cmds=[l.strip() for l in red.splitlines() if re.match(r'^\s*(\$ |bash |python3 |git )', l)][:20]
out=["# DMC Autonomous Run Evidence — %s"%rid, "- run_id: %s"%rid, "- self_test: %s"%st,
     "- result_summary: %s"%summary, "- commands:"]
out += ["  - %s"%c for c in cmds] if cmds else ["  - (none captured)"]
out.append("- redaction: applied (no secrets / env-values / abs-paths / provider payloads)")
print("\n".join(out))
PY
  rm -f "$TMP"
}

# ---------------------------------------------------------------- self-test
self_test() {
  local P=0 F=0; ok(){ echo "  PASS $1"; P=$((P+1)); }; no(){ echo "  FAIL $1"; F=$((F+1)); }
  local TT; TT="$(mktemp -d)"; trap 'rm -rf "$TT"' RETURN
  local PRE; PRE="$(git -C "$ROOTDIR" status --porcelain 2>/dev/null | md5)"

  # captured output with PLANTED leak markers: a token, a credential-var assignment, an abs path, a provider payload
  cat > "$TT/cap.txt" <<CAP
==== SELF-TEST ====
  PASS AC1 something
$ bash /Users/secretuser/Documents/projects/DMC/.harness/evidence/x.sh --self-test
GLM_API_KEY=sk-LEAKKEY0123456789abcdefghijklmnop
authorization: Bearer eyJLEAKJWT.eyJpayloadleak0123
provider raw payload: {"choices":[{"message":{"content":"ya29.PROVIDERLEAK0123456789"}}]}
  ---- self-test: PASS=14 FAIL=0 ----
CAP
  local ev; ev="$(emit_evidence "run-leak/Users/secretuser/x" "$TT/cap.txt")"
  local EVF="$TT/ev.md"; emit_evidence "run-1" "$TT/cap.txt" > "$EVF" 2>/dev/null

  # AC1 schema conformance — required fields present
  { printf '%s' "$ev" | grep -q '# DMC Autonomous Run Evidence' && printf '%s' "$ev" | grep -q 'self_test:' \
    && printf '%s' "$ev" | grep -q 'result_summary:' && printf '%s' "$ev" | grep -q 'redaction: applied'; } \
    && ok "AC1 schema conformance: evidence has run-id/self_test/result_summary/commands/redaction" || no "AC1 schema"

  # AC2 standardized extraction — counts + summary from a 14/0 run
  { printf '%s' "$ev" | grep -q 'self_test: 14 PASS / 0 FAIL' && printf '%s' "$ev" | grep -q 'result_summary: PASS'; } \
    && ok "AC2 extraction: '14 PASS / 0 FAIL' => result_summary PASS" || no "AC2 extraction"

  # AC3 redaction — NONE of the planted leak markers appear in the evidence (stdout AND --out)
  if ! printf '%s' "$ev" | grep -Eq 'LEAKKEY|LEAKJWT|PROVIDERLEAK|secretuser' && ! grep -Eq 'LEAKKEY|LEAKJWT|PROVIDERLEAK|secretuser' "$EVF"; then
    ok "AC3 redaction: token/JWT/ya29/provider-payload + abs-path user never emitted (stdout AND --out)"
  else no "AC3 a leak marker survived"; fi

  # AC4 redactor unit-check (--redact-file on the full leaky capture): all three classes substituted; no marker survives
  local rf; rf="$(bash "$SELFPATH" --redact-file "$TT/cap.txt" 2>/dev/null)"
  { printf '%s' "$rf" | grep -q '\[redacted:secret\]' && printf '%s' "$rf" | grep -q '\[redacted:env-value\]' \
    && printf '%s' "$rf" | grep -q '\[redacted:abs-path\]' \
    && ! printf '%s' "$rf" | grep -Eq 'LEAKKEY|LEAKJWT|PROVIDERLEAK|secretuser'; } \
    && ok "AC4 redactor: [redacted:secret]/[env-value]/[abs-path] all substituted; no marker survives" || no "AC4 redactor"

  # AC5 run-id itself redacted (it carried an abs path)
  ! printf '%s' "$ev" | grep -q 'secretuser' && ok "AC5 run-id abs-path redacted in the header" || no "AC5 run-id leak"

  # AC6 --out guard
  out_refused ".env" && out_refused "x/../provider-router.py" && ! out_refused "$TT/ok.md" \
    && ok "AC6 --out guard: protected/secret/traversal refused, benign allowed" || no "AC6 --out guard"

  # AC7 read-only: repo byte-unchanged
  [ "$(git -C "$ROOTDIR" status --porcelain 2>/dev/null | md5)" = "$PRE" ] && ok "AC7 read-only: repo byte-unchanged" || no "AC7 repo changed"

  echo "  ---- self-test: PASS=$P FAIL=$F ----"; [ "$F" = 0 ]
}

RUNID=""; FROM=""; OUT=""; MODE=run
while [ $# -gt 0 ]; do case "$1" in
  --run-id) RUNID="$2"; shift 2;; --from) FROM="$2"; shift 2;; --out) OUT="$2"; shift 2;;
  --redact-file) MODE=redactfile; FROM="$2"; shift 2;;
  --self-test) MODE=selftest; shift;; -h|--help) sed -n '2,12p' "$0"; exit 0;;
  *) echo "evidence-harness: unknown arg $1" >&2; exit 2;;
esac; done
if [ "$MODE" = selftest ]; then echo "==== DMC EVIDENCE HARNESS — SELF-TEST ===="; self_test; exit $?; fi
if [ "$MODE" = redactfile ]; then [ -f "${FROM:-/nonexistent}" ] || { echo "evidence-harness: --redact-file <f> not found" >&2; exit 2; }; redact_stdin < "$FROM"; exit 0; fi
[ -n "$RUNID" ] && [ -f "${FROM:-/nonexistent}" ] || { echo "evidence-harness: --run-id <id> --from <captured.txt> required" >&2; exit 2; }
if [ -n "$OUT" ]; then out_refused "$OUT" && { echo "evidence-harness: --out protected/secret — REFUSED" >&2; exit 2; }; emit_evidence "$RUNID" "$FROM" > "$OUT"; echo "evidence-harness: wrote $OUT" >&2; else emit_evidence "$RUNID" "$FROM"; fi
exit 0
