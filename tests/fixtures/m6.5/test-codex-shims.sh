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

# --- A16 — UPS cross-adapter parity (v1.0.1 activation tuning) -------------------
# Drives BOTH the REAL Claude router (.claude/hooks/dmc-router.sh via claude_run) AND the Codex UPS
# shim (adapters/codex/dmc-codex-userpromptsubmit.py via codex_run) on the SAME prompts, asserting
# emit CONTENT (not just the additionalContext key), mode-file writes, and cross-adapter equality —
# closing the zero-tripwire UPS parity gap (plan dmc-v1.1-activation-tuning §Proposed Changes T018.2).
# (critic-r1 A2) each prompt case uses a FRESH per-prompt sandbox dir per adapter, and the
# mode-unchanged cases (P3/P5) seed a `passive` sentinel + assert it survives — so no prior write can
# bleed into them. has_context_of() greps only the key name, so these rows grep real content.
echo "== A16. UPS cross-adapter parity (v1.0.1 activation tuning) =="

UW_MARK='Run /dmc-ultrawork for: '
PLAN_MARK='Run /dmc-plan-hard for this task (planning only, no edits): '

# seg_after OUTPUT MARKER -> the routed task text after MARKER, up to the JSON closing quote.
# Shape-robust (critic-r2 A5): literal marker strip + JSON-quote boundary, NOT a grep -v on an
# assumed single-line shape (the Claude emit is even multi-line; the Codex emit is compact). MARKER
# is unquoted in the pattern deliberately — it carries no glob metachar (`* ? [`), so `(`/`)`/`:`/`/`
# match literally; `${rest%%\"*}` strips from the first double-quote.
seg_after() { local rest="${1#*$2}"; printf '%s' "${rest%%\"*}"; }
# new_dir [SEED_MODE] -> fresh sandbox project dir with .harness/ (+ optional seeded mode sentinel).
new_dir() { local d; d=$(mktmp); mkdir -p "$d/.harness"; [ -n "${1:-}" ] && printf '%s\n' "$1" > "$d/.harness/mode"; printf '%s' "$d"; }
mode_of() { if [ -f "$1/.harness/mode" ]; then head -n1 "$1/.harness/mode"; else printf '<absent>'; fi; }
run_router() { case "$1" in
    claude) claude_run dmc-router.sh "$(c_prompt "$3")" "$2" ;;
    codex)  codex_run  "$UPS"        "$(c_prompt "$3")" "$2" ;;
  esac; }
# ups_fingerprint OUTPUT MARKER -> "sig,prio,uw|<taskseg>" over ASCII key substrings only, so the
# router \uXXXX vs Codex ensure_ascii=False em-dash escaping never breaks the parity compare.
ups_fingerprint() { local out="$1" f=""
  printf '%s' "$out" | grep -q 'Okay, Let me do you Coding!' && f="sig"
  printf '%s' "$out" | grep -q 'DMC PRIORITY'                && f="${f:+$f,}prio"
  printf '%s' "$out" | grep -q 'dmc-ultrawork'               && f="${f:+$f,}uw"
  printf '%s|%s' "$f" "$(seg_after "$out" "$2")"; }

# P1 — lowercase 'fix the parser dmc' -> BOTH fire: signature + DMC PRIORITY + dmc-ultrawork; active.
dc=$(new_dir); oc=$(run_router claude "$dc" 'fix the parser dmc'); mc=$(mode_of "$dc")
dx=$(new_dir); ox=$(run_router codex  "$dx" 'fix the parser dmc'); mx=$(mode_of "$dx")
assert_eq 'sig,prio,uw|fix the parser' "$(ups_fingerprint "$oc" "$UW_MARK")" "A16 P1 claude: sig+priority+ultrawork+clean task"
assert_eq 'sig,prio,uw|fix the parser' "$(ups_fingerprint "$ox" "$UW_MARK")" "A16 P1 codex: sig+priority+ultrawork+clean task"
assert_eq "$(ups_fingerprint "$oc" "$UW_MARK")" "$(ups_fingerprint "$ox" "$UW_MARK")" "A16 P1 PARITY: claude additionalContext content == codex"
assert_eq active "$mc" "A16 P1 claude: mode set active"
assert_eq active "$mx" "A16 P1 codex: mode set active"
assert_eq "$mc" "$mx" "A16 P1 PARITY: mode-file write equal across adapters"

# P2 — mixed-case 'please refactor this. DMC' -> BOTH fire; CLEAN task extraction (critic-r2 A5); active.
dc=$(new_dir); oc=$(run_router claude "$dc" 'please refactor this. DMC'); mc=$(mode_of "$dc")
dx=$(new_dir); ox=$(run_router codex  "$dx" 'please refactor this. DMC'); mx=$(mode_of "$dx")
assert_eq 'please refactor this.' "$(seg_after "$oc" "$UW_MARK")" "A16 P2 claude: clean task extraction (no trigger token)"
assert_eq 'please refactor this.' "$(seg_after "$ox" "$UW_MARK")" "A16 P2 codex: clean task extraction (no trigger token)"
printf '%s' "$ox" | grep -q 'refactor this[.] DMC' \
  && record FAIL "A16 P2 codex: trigger token leaked into routed task" \
  || record PASS "A16 P2 codex: NO trigger-token leak (critic-r2 A5 ! grep form)"
assert_eq 'sig,prio,uw|please refactor this.' "$(ups_fingerprint "$oc" "$UW_MARK")" "A16 P2 claude: sig+priority+ultrawork present"
assert_eq 'sig,prio,uw|please refactor this.' "$(ups_fingerprint "$ox" "$UW_MARK")" "A16 P2 codex: sig+priority+ultrawork present"
assert_eq "$(ups_fingerprint "$oc" "$UW_MARK")" "$(ups_fingerprint "$ox" "$UW_MARK")" "A16 P2 PARITY: claude additionalContext content == codex"
assert_eq active "$mc" "A16 P2 claude: mode set active"
assert_eq active "$mx" "A16 P2 codex: mode set active"

# P3 — mid-sentence 'the DMC feature is nice' -> BOTH emit nothing; mode UNCHANGED (passive sentinel).
dc=$(new_dir passive); oc=$(run_router claude "$dc" 'the DMC feature is nice'); mc=$(mode_of "$dc")
dx=$(new_dir passive); ox=$(run_router codex  "$dx" 'the DMC feature is nice'); mx=$(mode_of "$dx")
[ -z "$oc" ] && record PASS "A16 P3 claude: mid-sentence DMC emits nothing" || record FAIL "A16 P3 claude: expected empty emit, got [$oc]"
[ -z "$ox" ] && record PASS "A16 P3 codex: mid-sentence DMC emits nothing"  || record FAIL "A16 P3 codex: expected empty emit, got [$ox]"
assert_eq passive "$mc" "A16 P3 claude: mode UNCHANGED (no spurious write)"
assert_eq passive "$mx" "A16 P3 codex: mode UNCHANGED (no spurious write)"

# P4 — mixed-case 'stand down DMC-OFF' -> BOTH route off; NO signature (greeting is dmc-only).
dc=$(new_dir); oc=$(run_router claude "$dc" 'stand down DMC-OFF'); mc=$(mode_of "$dc")
dx=$(new_dir); ox=$(run_router codex  "$dx" 'stand down DMC-OFF'); mx=$(mode_of "$dx")
assert_eq off "$mc" "A16 P4 claude: mode set off"
assert_eq off "$mx" "A16 P4 codex: mode set off"
printf '%s' "$oc" | grep -q 'mode set to OFF' && record PASS "A16 P4 claude: emit routes to OFF" || record FAIL "A16 P4 claude: OFF routing text absent"
printf '%s' "$ox" | grep -q 'mode set to OFF' && record PASS "A16 P4 codex: emit routes to OFF"  || record FAIL "A16 P4 codex: OFF routing text absent"
printf '%s' "$oc" | grep -q 'Okay, Let me do you Coding!' && record FAIL "A16 P4 claude: OFF route leaked the dmc signature" || record PASS "A16 P4 claude: OFF route carries NO signature"
printf '%s' "$ox" | grep -q 'Okay, Let me do you Coding!' && record FAIL "A16 P4 codex: OFF route leaked the dmc signature"  || record PASS "A16 P4 codex: OFF route carries NO signature"
assert_eq "$mc" "$mx" "A16 P4 PARITY: mode-file write equal across adapters (off)"

# P5 — mixed-case 'design the schema DMC-PLAN' -> BOTH route dmc-plan-hard; mode UNCHANGED; clean task.
dc=$(new_dir passive); oc=$(run_router claude "$dc" 'design the schema DMC-PLAN'); mc=$(mode_of "$dc")
dx=$(new_dir passive); ox=$(run_router codex  "$dx" 'design the schema DMC-PLAN'); mx=$(mode_of "$dx")
printf '%s' "$oc" | grep -q 'dmc-plan-hard' && record PASS "A16 P5 claude: routes to /dmc-plan-hard" || record FAIL "A16 P5 claude: dmc-plan-hard route absent"
printf '%s' "$ox" | grep -q 'dmc-plan-hard' && record PASS "A16 P5 codex: routes to /dmc-plan-hard"  || record FAIL "A16 P5 codex: dmc-plan-hard route absent"
assert_eq 'design the schema' "$(seg_after "$oc" "$PLAN_MARK")" "A16 P5 claude: clean task extraction (no trigger token)"
assert_eq 'design the schema' "$(seg_after "$ox" "$PLAN_MARK")" "A16 P5 codex: clean task extraction (no trigger token)"
assert_eq passive "$mc" "A16 P5 claude: mode UNCHANGED (plan route never writes mode)"
assert_eq passive "$mx" "A16 P5 codex: mode UNCHANGED (plan route never writes mode)"
printf '%s' "$oc" | grep -q 'Okay, Let me do you Coding!' && record FAIL "A16 P5 claude: plan route leaked the dmc signature" || record PASS "A16 P5 claude: plan route carries NO signature"
printf '%s' "$ox" | grep -q 'Okay, Let me do you Coding!' && record FAIL "A16 P5 codex: plan route leaked the dmc signature"  || record PASS "A16 P5 codex: plan route carries NO signature"
assert_eq "$(seg_after "$oc" "$PLAN_MARK")" "$(seg_after "$ox" "$PLAN_MARK")" "A16 P5 PARITY: routed task equal across adapters"

# --- A16 P-ML/P-TO — multi-line suffix-anchor tripwire (dmc-v1.0.2-router-anchor DMC-T001 fix) ---
# The router's trigger anchor is now whole-prompt (multi-line-safe): the token must end the ENTIRE
# prompt, never merely an interior line. These rows drive BOTH adapters on multi-line and
# token-only prompts, making the restored parity machine-checked. Round-trip verified: the JSON
# encoder on both sides collapses a real embedded newline into the same two-character `\n` escape
# before bash ever sees it, so seg_after/ups_fingerprint compare byte-for-byte with no json-aware
# helper needed — a plain assert_eq suffices even for a task segment that spans an embedded newline.

# P-ML1 — interior line-terminal token: the trigger sits at the end of an INTERIOR line, not the
# end of the whole prompt -> BOTH emit nothing; NO mode write (fresh unseeded dirs stay <absent>);
# PARITY asserted explicitly on both has_context_of and mode (critic-r1 advisory 2).
dc=$(new_dir); oc=$(run_router claude "$dc" $'refactor this dmc\nand also update docs'); mc=$(mode_of "$dc")
dx=$(new_dir); ox=$(run_router codex  "$dx" $'refactor this dmc\nand also update docs'); mx=$(mode_of "$dx")
[ -z "$oc" ] && record PASS "A16 P-ML1 claude: interior line-terminal dmc emits nothing" || record FAIL "A16 P-ML1 claude: expected empty emit, got [$oc]"
[ -z "$ox" ] && record PASS "A16 P-ML1 codex: interior line-terminal dmc emits nothing"  || record FAIL "A16 P-ML1 codex: expected empty emit, got [$ox]"
assert_eq '<absent>' "$mc" "A16 P-ML1 claude: NO mode write (fresh dir stays absent)"
assert_eq '<absent>' "$mx" "A16 P-ML1 codex: NO mode write (fresh dir stays absent)"
assert_eq "$(has_context_of "$oc")" "$(has_context_of "$ox")" "A16 P-ML1 PARITY: has_context_of equal across adapters (none)"
assert_eq "$mc" "$mx" "A16 P-ML1 PARITY: mode-file state equal across adapters"

# P-ML2 — true multi-line suffix: the trigger ends the WHOLE prompt, on its last line -> BOTH route
# ultrawork; the routed task segment spans the embedded newline; mode active; PARITY.
dc=$(new_dir); oc=$(run_router claude "$dc" $'first line\nsecond line dmc'); mc=$(mode_of "$dc")
dx=$(new_dir); ox=$(run_router codex  "$dx" $'first line\nsecond line dmc'); mx=$(mode_of "$dx")
assert_eq 'sig,prio,uw|first line\nsecond line' "$(ups_fingerprint "$oc" "$UW_MARK")" "A16 P-ML2 claude: sig+priority+ultrawork+task spanning the embedded newline"
assert_eq 'sig,prio,uw|first line\nsecond line' "$(ups_fingerprint "$ox" "$UW_MARK")" "A16 P-ML2 codex: sig+priority+ultrawork+task spanning the embedded newline"
assert_eq "$(ups_fingerprint "$oc" "$UW_MARK")" "$(ups_fingerprint "$ox" "$UW_MARK")" "A16 P-ML2 PARITY: claude additionalContext content == codex (embedded newline included)"
assert_eq active "$mc" "A16 P-ML2 claude: mode set active"
assert_eq active "$mx" "A16 P-ML2 codex: mode set active"
assert_eq "$mc" "$mx" "A16 P-ML2 PARITY: mode-file write equal across adapters"

# P-ML3 — interior 'dmc-off' line: the trigger sits at the end of an INTERIOR line -> BOTH emit
# nothing; a seeded passive sentinel SURVIVES on both; PARITY asserted explicitly (critic-r1
# advisory 2: a symmetric parity assertion, not just two independent one-sided checks).
dc=$(new_dir passive); oc=$(run_router claude "$dc" $'the dmc-off switch\nis documented here'); mc=$(mode_of "$dc")
dx=$(new_dir passive); ox=$(run_router codex  "$dx" $'the dmc-off switch\nis documented here'); mx=$(mode_of "$dx")
[ -z "$oc" ] && record PASS "A16 P-ML3 claude: interior dmc-off line emits nothing" || record FAIL "A16 P-ML3 claude: expected empty emit, got [$oc]"
[ -z "$ox" ] && record PASS "A16 P-ML3 codex: interior dmc-off line emits nothing"  || record FAIL "A16 P-ML3 codex: expected empty emit, got [$ox]"
assert_eq passive "$mc" "A16 P-ML3 claude: passive sentinel SURVIVES (no spurious off write)"
assert_eq passive "$mx" "A16 P-ML3 codex: passive sentinel SURVIVES (no spurious off write)"
assert_eq "$(has_context_of "$oc")" "$(has_context_of "$ox")" "A16 P-ML3 PARITY: has_context_of equal across adapters (none)"
assert_eq "$mc" "$mx" "A16 P-ML3 PARITY: mode-file state equal across adapters (passive survives)"

# P-ML4 — token-only final line: the last line IS just the token; the newline before it is a valid
# whitespace boundary -> BOTH route ultrawork; task strips to 'do the thing' on both; PARITY.
dc=$(new_dir); oc=$(run_router claude "$dc" $'do the thing\ndmc'); mc=$(mode_of "$dc")
dx=$(new_dir); ox=$(run_router codex  "$dx" $'do the thing\ndmc'); mx=$(mode_of "$dx")
assert_eq 'sig,prio,uw|do the thing' "$(ups_fingerprint "$oc" "$UW_MARK")" "A16 P-ML4 claude: sig+priority+ultrawork+clean task (newline boundary)"
assert_eq 'sig,prio,uw|do the thing' "$(ups_fingerprint "$ox" "$UW_MARK")" "A16 P-ML4 codex: sig+priority+ultrawork+clean task (newline boundary)"
assert_eq "$(ups_fingerprint "$oc" "$UW_MARK")" "$(ups_fingerprint "$ox" "$UW_MARK")" "A16 P-ML4 PARITY: claude additionalContext content == codex"
assert_eq active "$mc" "A16 P-ML4 claude: mode set active"
assert_eq active "$mx" "A16 P-ML4 codex: mode set active"
assert_eq "$mc" "$mx" "A16 P-ML4 PARITY: mode-file write equal across adapters"

# P-TO1 (critic-r1 advisory 1) — bare token-only prompt 'dmc' -> BOTH route ultrawork; mode active;
# EMPTY task (nothing precedes the token); PARITY.
dc=$(new_dir); oc=$(run_router claude "$dc" 'dmc'); mc=$(mode_of "$dc")
dx=$(new_dir); ox=$(run_router codex  "$dx" 'dmc'); mx=$(mode_of "$dx")
assert_eq 'sig,prio,uw|' "$(ups_fingerprint "$oc" "$UW_MARK")" "A16 P-TO1 claude: sig+priority+ultrawork+EMPTY task"
assert_eq 'sig,prio,uw|' "$(ups_fingerprint "$ox" "$UW_MARK")" "A16 P-TO1 codex: sig+priority+ultrawork+EMPTY task"
assert_eq "$(ups_fingerprint "$oc" "$UW_MARK")" "$(ups_fingerprint "$ox" "$UW_MARK")" "A16 P-TO1 PARITY: claude additionalContext content == codex"
assert_eq active "$mc" "A16 P-TO1 claude: mode set active"
assert_eq active "$mx" "A16 P-TO1 codex: mode set active"
assert_eq "$mc" "$mx" "A16 P-TO1 PARITY: mode-file write equal across adapters"

# P-TO2 (critic-r1 advisory 1) — bare token-only prompt 'dmc-plan' -> BOTH route planning; mode
# UNCHANGED (seeded passive sentinel survives, plan route never writes mode); EMPTY task; PARITY.
dc=$(new_dir passive); oc=$(run_router claude "$dc" 'dmc-plan'); mc=$(mode_of "$dc")
dx=$(new_dir passive); ox=$(run_router codex  "$dx" 'dmc-plan'); mx=$(mode_of "$dx")
printf '%s' "$oc" | grep -q 'dmc-plan-hard' && record PASS "A16 P-TO2 claude: routes to /dmc-plan-hard" || record FAIL "A16 P-TO2 claude: dmc-plan-hard route absent"
printf '%s' "$ox" | grep -q 'dmc-plan-hard' && record PASS "A16 P-TO2 codex: routes to /dmc-plan-hard"  || record FAIL "A16 P-TO2 codex: dmc-plan-hard route absent"
assert_eq '' "$(seg_after "$oc" "$PLAN_MARK")" "A16 P-TO2 claude: EMPTY task (nothing precedes the token)"
assert_eq '' "$(seg_after "$ox" "$PLAN_MARK")" "A16 P-TO2 codex: EMPTY task (nothing precedes the token)"
assert_eq passive "$mc" "A16 P-TO2 claude: mode UNCHANGED (seeded sentinel survives)"
assert_eq passive "$mx" "A16 P-TO2 codex: mode UNCHANGED (seeded sentinel survives)"
assert_eq "$(seg_after "$oc" "$PLAN_MARK")" "$(seg_after "$ox" "$PLAN_MARK")" "A16 P-TO2 PARITY: routed task equal across adapters"
assert_eq "$mc" "$mx" "A16 P-TO2 PARITY: mode-file state equal across adapters (passive survives)"

# P-TO3 (critic-r1 advisory 1) — bare token-only prompt 'dmc-off' -> BOTH route off; mode off; PARITY.
dc=$(new_dir); oc=$(run_router claude "$dc" 'dmc-off'); mc=$(mode_of "$dc")
dx=$(new_dir); ox=$(run_router codex  "$dx" 'dmc-off'); mx=$(mode_of "$dx")
printf '%s' "$oc" | grep -q 'mode set to OFF' && record PASS "A16 P-TO3 claude: emit routes to OFF" || record FAIL "A16 P-TO3 claude: OFF routing text absent"
printf '%s' "$ox" | grep -q 'mode set to OFF' && record PASS "A16 P-TO3 codex: emit routes to OFF"  || record FAIL "A16 P-TO3 codex: OFF routing text absent"
assert_eq off "$mc" "A16 P-TO3 claude: mode set off"
assert_eq off "$mx" "A16 P-TO3 codex: mode set off"
assert_eq "$mc" "$mx" "A16 P-TO3 PARITY: mode-file write equal across adapters (off)"
assert_eq "$(has_context_of "$oc")" "$(has_context_of "$ox")" "A16 P-TO3 PARITY: has_context_of equal across adapters (ctx)"

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
