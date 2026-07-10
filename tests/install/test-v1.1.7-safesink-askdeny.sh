#!/usr/bin/env bash
# test-v1.1.7-safesink-askdeny.sh — standalone hermetic INTEGRATION test for the v1.1.7 Bash
# write-radius change (safe-sink allowlist + fd-dup no-write + residual L1-AMBIGUOUS ask->deny).
#
# Nature: hermetic TEST. NOT wired into `bin/dmc selftest` (the CI-covered layer is the MODULE
# self-test in dmc-bash-radius.py; this file is the end-to-end integration layer, following the
# tests/install/ precedent). It mints a REAL armed scope.lock via `dmc run start --scope-input`
# and drives the LIVE `bin/dmc bash-radius` adjudication against it. Every probe is passed as a
# `--cmd` STRING to the classifier — it is NEVER executed — so the whole battery is inert-if-executed.
# The live DMC repo is only READ; all state lands in an mktemp sandbox. Run:
#   bash tests/install/test-v1.1.7-safesink-askdeny.sh
#
# Covers plan dmc-v1.1.7-safesink-askdeny (Rev 2) Acceptance Criteria end-to-end:
#   B1  `>&`/`N>&`/`&>` file targets surface + adjudicate: out-of-scope => DENY, in-scope => ALLOW.
#   fd  fd-duplications (`2>&1`, `>&2`, `2>&-`) carry no write target => ALLOW.
#   B2  safe sinks (/dev/null, /dev/stderr, /dev/stdout, /dev/fd/<n>) => ALLOW; a `/dev/fd` traversal
#       is NOT a sink => adjudicated => DENY.
#   AD  every residual L1-AMBIGUOUS case (python -c / $(...) / glob / directory / tee-no-file /
#       wrapper-exec benign / single-operand mv-cp) => DENY (exit 4), never ASK (exit 3).
#   RS  a run-state write (scope.lock.json) => DENY.  L0  a bare git-apply => L0 DENY.
#   NO-ASK invariant: no probe in the battery returns exit 3.
#   Z   real repo `git status --porcelain` byte-identical before/after (hermetic proof).

set -u

REPO="$(cd -- "$(dirname -- "$0")/../.." && pwd)"
DMC="$REPO/bin/dmc"
SCOPELOCK="$REPO/bin/lib/dmc-scope-lock.py"

[ -x "$DMC" ] || { echo "FATAL: bin/dmc not found or not executable: $DMC" >&2; exit 1; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dmc-v117-test.XXXXXX")"
# Canonicalize (macOS /tmp symlink) so fixture --root values match the tool's resolved paths.
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT

# ---------------------------------------------------------------- assertion helpers
PASS=0
FAIL=0
_pass() { PASS=$((PASS + 1)); printf 'PASS  %s\n' "$1"; }
_fail() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }

assert_eq()       { if [ "$1" = "$2" ]; then _pass "$3"; else _fail "$3 (expected='$1' actual='$2')"; fi; }
assert_ne()       { if [ "$1" != "$2" ]; then _pass "$3"; else _fail "$3 (value='$2' should differ)"; fi; }
assert_contains() { case "$1" in *"$2"*) _pass "$3" ;; *) _fail "$3 (missing substring: '$2')" ;; esac; }
assert_file()     { if [ -f "$1" ]; then _pass "$2"; else _fail "$2 (missing file: $1)"; fi; }

# radius CMD -> sets RC (exit code) and OUT (the one-line JSON verdict). The command is NEVER run.
radius() {
  OUT="$("$DMC" bash-radius --cmd "$1" --scope-lock "$LOCK" 2>/dev/null)"
  RC=$?
}

# ---------------------------------------------------------------- fixture builders (mirror arming test)
write_plan() { # dest
  cat > "$1" <<EOF
# Plan: v1.1.7 safe-sink integration fixture

Plan ID: dmc-fixture-v117

## Approval Status
Status: APPROVED
Approver: FIXTURE
Approved At: 2026-07-10
EOF
}
# A valid landmark scope-input: one in-scope ordinary file (src/app.py, edit) + complete bounds.
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

echo "test-v1.1.7-safesink-askdeny.sh :: repo=$REPO"
echo "                                   work=$WORK"
echo ""

BEFORE="$(git -C "$REPO" status --porcelain 2>/dev/null || true)"

# ================================================================ C0 arm a real run
echo "-- C0: arm a real run (one command mints + validates the scope.lock) --"
FX="$WORK/run"; mkdir -p "$FX"
write_plan "$FX/plan.md"
write_scope_valid "$FX/scope-input.json"
printf '.harness/\n' > "$FX/.gitignore"
git init -q "$FX" >/dev/null 2>&1 || true
AOUT="$("$DMC" run start --plan "$FX/plan.md" --scope-input "$FX/scope-input.json" --root "$FX" 2>/dev/null)"
ARC=$?
assert_eq 0 "$ARC" "C0: armed start exits 0"
assert_contains "$AOUT" "ARMED:" "C0: ARMED: line printed"
RID="$(head -1 "$FX/.harness/runs/current-run-id" 2>/dev/null || true)"
assert_ne "" "$RID" "C0: run pointer set (run-id present)"
LOCK="$FX/.harness/runs/$RID/scope.lock.json"
assert_file "$LOCK" "C0: scope.lock.json exists at the run's canonical path"
python3 "$SCOPELOCK" --validate "$LOCK" >/dev/null 2>&1
assert_eq 0 "$?" "C0: scope.lock.json --validate ACCEPTs"

# ================================================================ P: positives (ALLOW, rc0)
echo "-- P: safe-sink / fd-dup / in-scope probes ALLOW (rc0) --"
for c in \
  'echo hi 2>&1' \
  'echo hi >&2' \
  'echo hi 2>&-' \
  'echo x > /dev/null 2>&1' \
  'echo x 2>/dev/null' \
  'echo x > /dev/stderr' \
  'echo x > /dev/stdout' \
  'echo x > /dev/fd/2' \
  'echo x > src/app.py' \
  'echo ok >& src/app.py'
do
  radius "$c"
  assert_eq 0 "$RC" "P allow (rc0): $c"
  assert_contains "$OUT" '"decision":"allow"' "P decision=allow: $c"
done

# ================================================================ N: negatives (DENY, rc4)
echo "-- N: out-of-scope '>&' / run-state / L0 / traversal probes DENY (rc4) --"
# B1: out-of-scope `>&`/`&>` file targets surface and adjudicate OUT-OF-SCOPE (no orphaned ALLOW).
for c in \
  'echo pwned >& src/other.py' \
  'echo pwned >&src/other.py' \
  'echo x 2>& /tmp/out-of-scope.log' \
  'echo x &> /tmp/out-of-scope.log'
do
  radius "$c"
  assert_eq 4 "$RC" "N B1 deny (rc4): $c"
  assert_contains "$OUT" 'OUT-OF-SCOPE' "N B1 reason OUT-OF-SCOPE: $c"
done
# B2: a /dev/fd traversal is NOT a sink -> adjudicated -> DENY.
radius 'echo x > /dev/fd/../../etc/passwd'
assert_eq 4 "$RC" "N B2 deny (rc4): /dev/fd traversal is not a sink"
# RS: a run-state write is denied outright.
radius 'echo x > scope.lock.json'
assert_eq 4 "$RC" "N RS deny (rc4): run-state write (scope.lock.json)"
assert_contains "$OUT" 'RUN-STATE-WRITE' "N RS reason RUN-STATE-WRITE"
# L0: a bare git-apply is denied at the static floor.
radius 'git apply x.patch'
assert_eq 4 "$RC" "N L0 deny (rc4): bare git apply"
assert_contains "$OUT" '"tier":"L0"' "N L0 tier=L0"

# ================================================================ AD + NO-ASK: former-ask -> DENY, never ASK
echo "-- AD: every residual ambiguous case DENIES (rc4) and NEVER asks (rc!=3) --"
for c in \
  'python3 -c open("src/app.py","w")' \
  'echo x > $(mkfile)' \
  'echo x > src/*.py' \
  'echo x > somedir/' \
  'mv onlyone' \
  'cp onlyfile' \
  'echo x | tee' \
  'sh -c "echo hi"' \
  'xargs echo'
do
  radius "$c"
  assert_eq 4 "$RC" "AD deny (rc4): $c"
  assert_ne 3 "$RC" "NO-ASK (rc!=3): $c"
  assert_contains "$OUT" 'BASH-L1-AMBIGUOUS' "AD reason BASH-L1-AMBIGUOUS: $c"
done

# ================================================================ Z hermetic proof
echo "-- Z: hermetic proof --"
AFTER="$(git -C "$REPO" status --porcelain 2>/dev/null || true)"
assert_eq "$BEFORE" "$AFTER" "Z: real repo git status --porcelain byte-identical before/after"

# ---------------------------------------------------------------- summary
echo ""
echo "==== v1.1.7 safe-sink / ask->deny integration test: $PASS passed, $FAIL failed ===="
if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
exit 0
