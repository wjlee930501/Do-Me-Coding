#!/usr/bin/env bash
# test-run-start-arming.sh — standalone hermetic test for `dmc run start --scope-input` (v1.1.3).
#
# Nature: hermetic TEST. NOT wired into `bin/dmc selftest` (keeps Ring-0 untouched; the install-
# wrapper test set the precedent). Every run lands in an mktemp sandbox under $WORK; the live DMC
# repo is only READ. Run:  bash tests/install/test-run-start-arming.sh
#
# Covers plan dmc-fable-core-e-runstart (v1.1.3) Acceptance Criteria:
#   C1 armed happy path — `run start --scope-input <valid>` => exit 0, run RUNNING, scope.lock.json
#      exists + `--validate` ACCEPTs, pointer set, `ARMED:` line; a LIVE bash-radius out-of-scope
#      write probe against the freshly-minted lock => deny rc4 (armed-for-real proof).
#   C2 fail-closed teardown — a malformed scope-input (missing bounds) => exit 3, `REFUSED-ARMING:`
#      on stderr, NO scope.lock.json, run left SUSPENDED (not RUNNING), pointer ABSENT (no residue).
#   C3 back-compat SUCCESS — `run start` WITHOUT --scope-input => stdout + exit code byte-identical
#      to a direct `dmc-run-lifecycle.py start`, plus EXACTLY ONE stderr WARNING line and nothing else.
#   C4 back-compat REFUSE — a DRAFT-plan start => exit code AND both streams byte-identical between
#      bin/dmc and the direct RCORE call (bin/dmc adds nothing on a non-zero RCORE exit).
#   C5 usage text mentions --scope-input.
#   Z  hermetic proof — the real repo `git status --porcelain` is byte-identical before/after.

set -u

REPO="$(cd -- "$(dirname -- "$0")/../.." && pwd)"
DMC="$REPO/bin/dmc"
RCORE="$REPO/bin/lib/dmc-run-lifecycle.py"
SCOPELOCK="$REPO/bin/lib/dmc-scope-lock.py"

[ -x "$DMC" ] || { echo "FATAL: bin/dmc not found or not executable: $DMC" >&2; exit 1; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dmc-arm-test.XXXXXX")"
# Canonicalize (macOS /tmp symlink) so fixture --root values match the tool's resolved paths.
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT

# ---------------------------------------------------------------- assertion helpers
PASS=0
FAIL=0
_pass() { PASS=$((PASS + 1)); printf 'PASS  %s\n' "$1"; }
_fail() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }

assert_eq()   { if [ "$1" = "$2" ]; then _pass "$3"; else _fail "$3 (expected='$1' actual='$2')"; fi; }
assert_ne()   { if [ "$1" != "$2" ]; then _pass "$3"; else _fail "$3 (value='$2' should differ)"; fi; }
assert_contains()   { case "$1" in *"$2"*) _pass "$3" ;; *) _fail "$3 (missing substring: '$2')" ;; esac; }
assert_file()   { if [ -f "$1" ]; then _pass "$2"; else _fail "$2 (missing file: $1)"; fi; }
assert_nofile() { if [ ! -e "$1" ]; then _pass "$2"; else _fail "$2 (unexpected file: $1)"; fi; }

# ---------------------------------------------------------------- fixture builders
# A minimal plan the run core AND the scope-lock compiler both accept: `Status: <status>` +
# a non-empty `Approver:` (the compiler requires an approver reference) + a stable `Plan ID:`.
write_plan() { # dest status
  cat > "$1" <<EOF
# Plan: run-start arming fixture

Plan ID: dmc-fixture-arming

## Approval Status
Status: $2
Approver: FIXTURE
Approved At: 2026-07-10
EOF
}
# A valid landmark scope-input: one in-scope ordinary path + a complete bounds object.
write_scope_valid() { # dest
  cat > "$1" <<'EOF'
{
  "files": [
    {"path": "src/app.py", "grant": "edit", "landmark_class": "ordinary"}
  ],
  "bounds": {"max_files": 1, "max_added": 100, "max_deleted": 20, "forbidden_hunk_classes": []}
}
EOF
}
# A malformed scope-input (missing the required bounds object) -> compile REFUSE.
write_scope_malformed() { # dest
  cat > "$1" <<'EOF'
{
  "files": [
    {"path": "src/app.py", "grant": "edit", "landmark_class": "ordinary"}
  ]
}
EOF
}
# Fresh fixture repo: plan (APPROVED|DRAFT) + valid & malformed scope-inputs + git init (no commit,
# .harness/ gitignored). Two fixtures built identically produce identical repo_hash -> identical
# content-derived run-id -> byte-identical `run start` stdout (the back-compat comparison relies on it).
mkfix() { # dir status
  local d="$1" status="${2:-APPROVED}"
  mkdir -p "$d"
  write_plan "$d/plan.md" "$status"
  write_scope_valid "$d/scope-input.json"
  write_scope_malformed "$d/scope-bad.json"
  printf '.harness/\n' > "$d/.gitignore"
  git init -q "$d" >/dev/null 2>&1 || true
}

echo "test-run-start-arming.sh :: repo=$REPO"
echo "                            work=$WORK"
echo ""

BEFORE="$(git -C "$REPO" status --porcelain 2>/dev/null || true)"

# ================================================================ C1 armed happy path
echo "-- C1: armed happy path (one command arms + validates) --"
FA="$WORK/c1"; mkfix "$FA" APPROVED
C1OUT="$("$DMC" run start --plan "$FA/plan.md" --scope-input "$FA/scope-input.json" --root "$FA" 2>/dev/null)"
C1RC=$?
assert_eq 0 "$C1RC" "C1: armed start exits 0"
assert_contains "$C1OUT" "status: RUNNING" "C1: RCORE start lines flow through (status: RUNNING)"
assert_contains "$C1OUT" "ARMED:" "C1: ARMED: line printed to stdout"
RID="$(head -1 "$FA/.harness/runs/current-run-id" 2>/dev/null || true)"
assert_ne "" "$RID" "C1: run pointer set (run-id present)"
LOCK="$FA/.harness/runs/$RID/scope.lock.json"
assert_file "$LOCK" "C1: scope.lock.json exists at the run's canonical path"
python3 "$SCOPELOCK" --validate "$LOCK" >/dev/null 2>&1
VRC=$?
assert_eq 0 "$VRC" "C1: scope.lock.json --validate ACCEPTs (exit 0)"
STOUT="$("$DMC" run status --root "$FA" 2>/dev/null)"
assert_contains "$STOUT" "status: RUNNING" "C1: run remains RUNNING after arming (not torn down)"
# armed-for-real: an out-of-scope Bash write is DENIED (rc4) against the freshly-minted lock.
"$DMC" bash-radius --cmd 'echo x > outside.txt' --scope-lock "$LOCK" >/dev/null 2>&1
BRC=$?
assert_eq 4 "$BRC" "C1: bash-radius out-of-scope write DENIED (rc4) against the minted lock"

# ================================================================ C2 fail-closed teardown
echo "-- C2: fail-closed teardown (malformed scope-input) --"
FB="$WORK/c2"; mkfix "$FB" APPROVED
"$DMC" run start --plan "$FB/plan.md" --scope-input "$FB/scope-bad.json" --root "$FB" \
  >"$WORK/c2.out" 2>"$WORK/c2.err"
C2RC=$?
assert_eq 3 "$C2RC" "C2: malformed scope-input => exit 3"
assert_contains "$(cat "$WORK/c2.err")" "REFUSED-ARMING:" "C2: REFUSED-ARMING: on stderr"
RUNDIR="$(find "$FB/.harness/runs" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1)"
assert_nofile "$RUNDIR/scope.lock.json" "C2: NO scope.lock.json (nothing half-armed)"
assert_nofile "$FB/.harness/runs/current-run-id" "C2: run pointer ABSENT (torn down)"
RIDB="$(basename "$RUNDIR")"
STOUT2="$("$DMC" run status --root "$FB" --run-id "$RIDB" 2>/dev/null)"
assert_contains "$STOUT2" "status: SUSPENDED" "C2: run left SUSPENDED (not RUNNING)"

# ================================================================ C3 back-compat SUCCESS
echo "-- C3: back-compat SUCCESS (no --scope-input; stdout == direct RCORE + one WARNING) --"
FC="$WORK/c3-dmc";   mkfix "$FC" APPROVED
FD="$WORK/c3-rcore"; mkfix "$FD" APPROVED
"$DMC" run start --plan "$FC/plan.md" --root "$FC" >"$WORK/c3.out" 2>"$WORK/c3.err"
C3RC=$?
python3 "$RCORE" start --plan "$FD/plan.md" --root "$FD" >"$WORK/c3d.out" 2>"$WORK/c3d.err"
C3DRC=$?
assert_eq "$C3DRC" "$C3RC" "C3: exit code identical to direct RCORE start"
assert_eq "$(cat "$WORK/c3d.out")" "$(cat "$WORK/c3.out")" "C3: stdout byte-identical to direct RCORE"
NW="$(grep -c 'WARNING: run started UNARMED' "$WORK/c3.err")"
assert_eq 1 "$NW" "C3: exactly one UNARMED WARNING line on bin/dmc stderr"
assert_eq 1 "$(wc -l < "$WORK/c3.err" | tr -d ' ')" "C3: bin/dmc stderr is exactly one line"
assert_eq "" "$(cat "$WORK/c3d.err")" "C3: direct RCORE stderr empty (bin/dmc adds only the WARNING)"

# ================================================================ C4 back-compat REFUSE
echo "-- C4: back-compat REFUSE (DRAFT plan; both streams byte-identical) --"
FE="$WORK/c4-dmc";   mkfix "$FE" DRAFT
FF="$WORK/c4-rcore"; mkfix "$FF" DRAFT
"$DMC" run start --plan "$FE/plan.md" --root "$FE" >"$WORK/c4.out" 2>"$WORK/c4.err"
C4RC=$?
python3 "$RCORE" start --plan "$FF/plan.md" --root "$FF" >"$WORK/c4d.out" 2>"$WORK/c4d.err"
C4DRC=$?
assert_eq "$C4DRC" "$C4RC" "C4: exit code identical to direct RCORE (DRAFT refuse)"
assert_eq 3 "$C4RC" "C4: DRAFT plan refused exit 3"
assert_eq "$(cat "$WORK/c4d.out")" "$(cat "$WORK/c4.out")" "C4: stdout byte-identical (bin/dmc adds nothing)"
assert_eq "$(cat "$WORK/c4d.err")" "$(cat "$WORK/c4.err")" "C4: stderr byte-identical (bin/dmc adds nothing)"

# ================================================================ C5 usage text
echo "-- C5: usage text mentions --scope-input --"
HOUT="$("$DMC" help 2>/dev/null)"
assert_contains "$HOUT" "--scope-input" "C5: usage documents the --scope-input flag"

# ================================================================ Z hermetic proof
echo "-- Z: hermetic proof --"
AFTER="$(git -C "$REPO" status --porcelain 2>/dev/null || true)"
assert_eq "$BEFORE" "$AFTER" "Z: real repo git status --porcelain byte-identical before/after"

# ---------------------------------------------------------------- summary
echo ""
echo "==== run-start arming test: $PASS passed, $FAIL failed ===="
if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
exit 0
