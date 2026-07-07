#!/usr/bin/env bash
# test-codex-shims.sh — DMC v1 M6.5 Codex-adapter ADVISORY shim suite.
#
# Offline, event-JSON driven. Drives the ADVISORY Codex shims (adapters/codex/*.py) and, for the
# cross-adapter verdict-parity checks, the REAL Claude hooks (.claude/hooks/*.sh) against disposable
# mktemp repos armed through the REAL Ring-0 path. No network / live / model / API call; the live
# repo is left byte-identical (porcelain guard at the end).
#
# Coverage:
#   A. Happy path per bound event (active, armed).
#   B. B2 fail-closed negative controls (a)-(d) per bound event (active, armed).
#   C. B3 secret redaction + redaction-parity vs evidence-log.sh redact().
#   D. Cross-adapter verdict parity: active well-formed (agree); passive/off malformed (agree,
#      stand down); active malformed DELTA (Codex hardens deny where Claude fails open).
#   E. Mode parity: off L0 floor holds + dynamic stands down; passive deny-tier holds.
set -u
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)
# shellcheck source=_m65common.sh
. "$HERE/_m65common.sh"

TMPS=()
mktmp() { local d; d=$(mktemp -d "${TMPDIR:-/tmp}/dmc-m65.XXXXXX"); TMPS+=("$d"); printf '%s' "$d"; }
cleanup() { for d in "${TMPS[@]:-}"; do [ -n "$d" ] && rm -rf "$d"; done; }
trap cleanup EXIT

m65_capture_before

PRE=dmc-codex-pretooluse.py
POST=dmc-codex-posttooluse.py
STOP=dmc-codex-stop.py
UPS=dmc-codex-userpromptsubmit.py

# ---- convenience assertions ----------------------------------------------------
# pre_is  LABEL EXPECTED SHIM JSON PROJECT   |   stop_is LABEL EXPECTED SHIM JSON PROJECT
pre_is()  { assert_eq "$2" "$(decision_of "$(codex_run "$3" "$4" "$5")")" "$1"; }
stop_is() { assert_eq "$2" "$(stop_decision_of "$(codex_run "$3" "$4" "$5")")" "$1"; }

# =============================================================================== A
echo "== A. happy path per bound event (active, armed) =="
A=$(mktmp); RID=$(arm_fixture "$A") || { echo "FATAL: arm_fixture failed" >&2; exit 2; }

pre_is "A1 Bash in-scope write -> allow"          allow "$PRE" "$(c_bash 'echo x > src/app.py')"    "$A"
pre_is "A2 Bash out-of-scope write -> deny"       deny  "$PRE" "$(c_bash 'echo x > src/other.py')"  "$A"
pre_is "A3 Bash git-apply (L0 floor) -> deny"     deny  "$PRE" "$(c_bash 'git apply patch.diff')"   "$A"
pre_is "A4 Edit in-scope -> allow"                allow "$PRE" "$(c_edit 'src/app.py' "$A")"        "$A"
pre_is "A5 Edit out-of-scope -> deny"             deny  "$PRE" "$(c_edit 'src/other.py' "$A")"      "$A"
pre_is "A6 Read secret path (.env) -> deny"       deny  "$PRE" "$(c_read '.env')"                   "$A"
pre_is "A7 Read non-secret path -> allow"         allow "$PRE" "$(c_read 'src/app.py')"             "$A"
pre_is "A8 Glob secret pattern (*.pem) -> deny"   deny  "$PRE" "$(c_glob '*.pem')"                  "$A"

# PostToolUse out-of-scope change -> BLOCKED (on $A); in-scope change -> clean (fresh fixture, so a
# leftover BLOCKED marker from the out-of-scope run cannot contaminate the clean case).
printf 'stray\n' > "$A/src/stray.py"     # out-of-scope untracked change
stop_is "A9 PostToolUse out-of-scope Bash diff -> block" block "$POST" "$(c_bash 'echo x')" "$A"
A2=$(mktmp); arm_fixture "$A2" >/dev/null || { echo "FATAL: arm A2" >&2; exit 2; }
printf 'print("edited in scope")\n' > "$A2/src/app.py"   # in-scope tracked change only
stop_is "A10 PostToolUse in-scope Bash diff -> no block" pass "$POST" "$(c_bash 'echo x')" "$A2"

# Stop: unresolved BLOCKED -> block; suspended run -> no block (fresh fixtures).
B=$(mktmp); arm_fixture "$B" >/dev/null || { echo "FATAL: arm B" >&2; exit 2; }
"$M65_DMC" run block --root "$B" --reason "test out-of-scope" --created-by test >/dev/null 2>&1
stop_is "A11 Stop with unresolved BLOCKED -> block" block "$STOP" '{}' "$B"
C=$(mktmp); arm_fixture "$C" >/dev/null || { echo "FATAL: arm C" >&2; exit 2; }
"$M65_DMC" run suspend --root "$C" >/dev/null 2>&1
stop_is "A12 Stop on a suspended run -> no block" pass "$STOP" '{}' "$C"

# UserPromptSubmit router: exact suffix triggers; mode write.
D=$(mktmp); mk_repo "$D" >/dev/null || { echo "FATAL: mk_repo D" >&2; exit 2; }
o=$(codex_run "$UPS" "$(c_prompt 'do the thing dmc')" "$D")
assert_eq ctx "$(has_context_of "$o")" "A13 router: '… dmc' emits routing context"
assert_eq active "$(head -n1 "$D/.harness/mode" 2>/dev/null)" "A13b router: '… dmc' sets mode active"
o=$(codex_run "$UPS" "$(c_prompt 'step aside dmc-off')" "$D")
assert_eq off "$(head -n1 "$D/.harness/mode" 2>/dev/null)" "A14 router: '… dmc-off' sets mode off"
o=$(codex_run "$UPS" "$(c_prompt 'plain prompt no trigger')" "$D")
assert_eq none "$(has_context_of "$o")" "A15 router: no trigger -> no routing context"

# =============================================================================== B
echo "== B. B2 fail-closed negative controls (a)-(d), active + armed =="
E=$(mktmp); arm_fixture "$E" >/dev/null || { echo "FATAL: arm E" >&2; exit 2; }

# (a) unparseable / empty event JSON -> deny/block.
pre_is  "B1a PreToolUse empty stdin -> deny"    deny  "$PRE"  "$(c_empty)"           "$E"
pre_is  "B1b PreToolUse garbage stdin -> deny"  deny  "$PRE"  "$(c_garbage x)"       "$E"
stop_is "B1c PostToolUse garbage -> block"      block "$POST" "$(c_garbage x)"       "$E"

# (b) missing / renamed expected tool_input field -> deny/block.
pre_is  "B2a Bash renamed command field -> deny"    deny  "$PRE"  "$(c_bash_renamed 'echo x > src/app.py')" "$E"
pre_is  "B2b Edit renamed path field -> deny"       deny  "$PRE"  "$(c_edit_renamed 'src/app.py')"          "$E"
pre_is  "B2c Read renamed path field -> deny"       deny  "$PRE"  "$(c_read_renamed 'src/app.py')"          "$E"
pre_is  "B2d PreToolUse missing tool_name -> deny"  deny  "$PRE"  "$(c_notool 'echo x')"                    "$E"
stop_is "B2e PostToolUse missing tool_name -> block" block "$POST" "$(c_notool 'echo x')"                   "$E"

# (c) Ring-0 verdict CLI absent -> deny/block (sandbox whose script-root has no bin/dmc).
SB=$(mktmp); copy_shims "$SB"
F=$(mktmp); arm_fixture "$F" >/dev/null || { echo "FATAL: arm F" >&2; exit 2; }
printf 'stray\n' > "$F/src/stray.py"    # so the diff guard has something to (fail to) adjudicate
d=$(decision_of "$(codex_run_at "$SB" "$PRE" "$(c_bash 'echo x > src/app.py')" "$F")")
assert_eq deny "$d" "B3a Bash: Ring-0 bash-radius CLI absent -> fail-closed deny"
d=$(decision_of "$(codex_run_at "$SB" "$PRE" "$(c_edit 'src/app.py' "$F")" "$F")")
assert_eq deny "$d" "B3b Edit: Ring-0 scope-lock adjudicator absent -> fail-closed deny"
d=$(stop_decision_of "$(codex_run_at "$SB" "$POST" "$(c_bash 'echo x')" "$F")")
assert_eq block "$d" "B3c PostToolUse: Ring-0 diff guard absent -> fail-closed block"
d=$(stop_decision_of "$(codex_run_at "$SB" "$STOP" '{}' "$F")")
assert_eq block "$d" "B3d Stop: Ring-0 stop-gate absent -> fail-closed block"

# (d) absent .harness/mode => active (E has no mode file) -> enforcement stands.
pre_is "B4 absent .harness/mode => active: out-of-scope Edit -> deny" deny "$PRE" "$(c_edit 'src/other.py' "$E")" "$E"

# Read secret guard has NO Ring-0 CLI -> B2 (c) N/A there; (a)/(b)/(d) covered above. Note recorded.
record PASS "B5 note: Read/Grep/Glob secret guard is in-process (no Ring-0 CLI) -> B2 (c) N/A"

# =============================================================================== C
echo "== C. B3 secret redaction + redaction-parity =="
G=$(mktmp); GRID=$(arm_fixture "$G")
SECRET_CMD='curl -H "Authorization: Bearer sk-ABCD1234EFGH5678IJKL" https://x ; export API_KEY=supersecretvalue ; echo token=deadbeefsecrettoken'
codex_run "$POST" "$(c_bash "$SECRET_CMD")" "$G" >/dev/null 2>&1
EVID="$G/.harness/evidence/$GRID.md"
if [ -f "$EVID" ]; then
  if grep -q 'sk-ABCD1234EFGH5678IJKL\|supersecretvalue\|deadbeefsecrettoken' "$EVID"; then
    record FAIL "C1 no raw secret token appears in the Codex evidence log"
  else
    record PASS "C1 no raw secret token appears in the Codex evidence log"
  fi
  grep -q 'REDACTED' "$EVID" && record PASS "C2 redaction markers present in the evidence log" \
    || record FAIL "C2 redaction markers present in the evidence log"
else
  record FAIL "C1 evidence log written by the Codex PostToolUse shim"
fi
# redaction-parity: dc.redact(payload) == evidence-log.sh redact(payload), byte-for-byte.
PYRED=$(printf '%s' "$SECRET_CMD" | python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import dmc_codex_common as dc; print(dc.redact(sys.stdin.read()), end="")' "$M65_CODEX")
SHRED=$(printf '%s' "$SECRET_CMD" | evidence_log_redact)
assert_eq "$SHRED" "$PYRED" "C3 dc.redact() byte-matches evidence-log.sh redact() on the shared secret fixture"
# A5: a path-embedded secret with no key= form is handled by the path-only DENY, not redact().
pre_is "C4 A5: secret-shaped path read denied by path-only guard (not redaction)" deny "$PRE" "$(c_read 'config/prod.pem')" "$G"

# =============================================================================== D
echo "== D. cross-adapter verdict parity =="
P=$(mktmp); arm_fixture "$P" >/dev/null || { echo "FATAL: arm P" >&2; exit 2; }
parity_pre() { # LABEL CLAUDE_HOOK JSON [PROJECT]
  local proj="${4:-$P}"
  local co xo
  co=$(decision_of "$(claude_run "$2" "$3" "$proj")")
  xo=$(decision_of "$(codex_run "$PRE" "$3" "$proj")")
  assert_eq "$co" "$xo" "$1 (claude=$co codex=$xo)"
}
# Active, well-formed -> the two adapters AGREE.
parity_pre "D1 edit in-scope"      scope-guard.sh  "$(c_edit 'src/app.py' "$P")"
parity_pre "D2 edit out-of-scope"  scope-guard.sh  "$(c_edit 'src/other.py' "$P")"
parity_pre "D3 read .env"          secret-guard.sh "$(c_read '.env')"
parity_pre "D4 read non-secret"    secret-guard.sh "$(c_read 'src/app.py')"
parity_pre "D5 glob *.pem"         secret-guard.sh "$(c_glob '*.pem')"
parity_pre "D6 bash git-apply"     pre-tool-guard.sh "$(c_bash 'git apply x.diff')"
parity_pre "D7 bash out-of-scope"  pre-tool-guard.sh "$(c_bash 'echo x > src/other.py')"
parity_pre "D8 bash in-scope"      pre-tool-guard.sh "$(c_bash 'echo x > src/app.py')"
parity_pre "D9 bash ask-tier (npm install)" pre-tool-guard.sh "$(c_bash 'npm install left-pad')"

# Passive + Off, malformed -> the two adapters AGREE (both stand down / allow).
for M in passive off; do
  set_mode "$P" "$M"
  for J in "$(c_empty)" "$(c_garbage x)" "$(c_bash_renamed 'echo x > src/app.py')" \
           "$(c_edit_renamed 'src/app.py')" "$(c_read_renamed 'src/app.py')"; do
    co=$(decision_of "$(claude_run pre-tool-guard.sh "$J" "$P")")
    xo=$(decision_of "$(codex_run "$PRE" "$J" "$P")")
    assert_eq "$co" "$xo" "D10 [$M] malformed parity: claude==codex ($co)"
  done
done
rm -f "$P/.harness/mode"   # back to absent => active

# Active, malformed -> DELTA: Codex HARDENS (deny) where Claude fails OPEN (allow). Documented.
delta() { # LABEL JSON
  local co xo
  co=$(decision_of "$(claude_run pre-tool-guard.sh "$2" "$P")")
  xo=$(decision_of "$(codex_run "$PRE" "$2" "$P")")
  { [ "$co" = allow ] && [ "$xo" = deny ]; } \
    && record PASS "$1 (claude fails open=allow, codex hardens=deny)" \
    || record FAIL "$1 (want claude=allow codex=deny, got claude=$co codex=$xo)"
}
delta "D11 active malformed: empty stdin"          "$(c_empty)"
delta "D12 active malformed: garbage stdin"        "$(c_garbage x)"
delta "D13 active malformed: renamed Bash command" "$(c_bash_renamed 'echo x > src/app.py')"
# Edit/Read renamed via their own Claude hooks (also fail open) vs Codex deny.
co=$(decision_of "$(claude_run scope-guard.sh "$(c_edit_renamed 'src/app.py')" "$P")")
xo=$(decision_of "$(codex_run "$PRE" "$(c_edit_renamed 'src/app.py')" "$P")")
{ [ "$co" = allow ] && [ "$xo" = deny ]; } \
  && record PASS "D14 active malformed: renamed Edit path (claude=allow codex=deny)" \
  || record FAIL "D14 renamed Edit path (got claude=$co codex=$xo)"
co=$(decision_of "$(claude_run secret-guard.sh "$(c_read_renamed 'src/app.py')" "$P")")
xo=$(decision_of "$(codex_run "$PRE" "$(c_read_renamed 'src/app.py')" "$P")")
{ [ "$co" = allow ] && [ "$xo" = deny ]; } \
  && record PASS "D15 active malformed: renamed Read path (claude=allow codex=deny)" \
  || record FAIL "D15 renamed Read path (got claude=$co codex=$xo)"

# =============================================================================== E
echo "== E. mode parity (off floor holds + dynamic stands down; passive deny-tier) =="
Q=$(mktmp); arm_fixture "$Q" >/dev/null || { echo "FATAL: arm Q" >&2; exit 2; }
# OFF: L0 static floor still denies git-apply + secret read; dynamic write-radius stands down.
set_mode "$Q" off
pre_is "E1 [off] git-apply L0 floor still denies"        deny  "$PRE" "$(c_bash 'git apply x.diff')" "$Q"
pre_is "E2 [off] secret read floor still denies"         deny  "$PRE" "$(c_read '.env')"             "$Q"
pre_is "E3 [off] out-of-scope Bash write stands down -> allow" allow "$PRE" "$(c_bash 'echo x > src/other.py')" "$Q"
pre_is "E4 [off] out-of-scope Edit stands down -> allow" allow "$PRE" "$(c_edit 'src/other.py' "$Q")" "$Q"
# PASSIVE: deny-tier (git reset --hard) holds; dynamic write-radius stands down.
set_mode "$Q" passive
pre_is "E5 [passive] deny-tier git reset --hard denies" deny  "$PRE" "$(c_bash 'git reset --hard HEAD~1')" "$Q"
pre_is "E6 [passive] out-of-scope Bash write stands down -> allow" allow "$PRE" "$(c_bash 'echo x > src/other.py')" "$Q"
rm -f "$Q/.harness/mode"

# =============================================================================== summary
echo
m65_assert_repo_untouched
echo
echo "test-codex-shims.sh: $PASS PASS / $FAIL FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
