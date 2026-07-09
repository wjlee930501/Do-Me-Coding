#!/usr/bin/env bash
# test-install-wrapper.sh — standalone smoke test for the root install.sh wrapper.
#
# Nature: hermetic TEST. NOT wired into `bin/dmc selftest` (keeps Ring-0 untouched). Every install
# lands in an mktemp sandbox under $WORK; the live DMC repo is only READ (installer copies FROM it,
# doctor reads the target). Run:  bash tests/install/test-install-wrapper.sh
#
# Covers the wrapper plan's acceptance criteria (Rev 2 §Acceptance):
#   AC1  real install --host claude into a pre-created dir -> doctor PASS, exit 0, mode printed
#   AC2  --dry-run into an empty dir -> writes nothing, exit 0, doctor NOT run
#   AC3a python3 hidden from PATH -> non-zero + names python3 + no partial install
#   AC3b git hidden but python3 present -> still installs + doctor PASS (git only warns)
#   AC4  bad --host xxx -> base installer's exit 2 surfaced (end-to-end `|| exit $?` propagation)
#   AC5  absolute path from a different cwd -> still resolves + doctor PASS, exit 0
#   AC6  doctor-fail propagation (see the AC6 block for why it's proven via the condition + AC4)
#   AC9  second run is idempotent -> exit 0

set -u

REPO="$(cd -- "$(dirname -- "$0")/../.." && pwd)"
WRAPPER="$REPO/install.sh"

if [ ! -x "$WRAPPER" ]; then
  echo "FATAL: wrapper not found or not executable: $WRAPPER" >&2
  exit 1
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dmc-wrap-test.XXXXXX")"
# Canonicalize so the wrapper's `cd && pwd`-resolved TGT matches our paths (macOS /tmp symlink etc.).
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT

# ---------------------------------------------------------------- assertion helpers
PASS=0
FAIL=0
_pass() { PASS=$((PASS + 1)); printf 'PASS  %s\n' "$1"; }
_fail() { FAIL=$((FAIL + 1)); printf 'FAIL  %s\n' "$1"; }

assert_eq() { # expected actual label
  if [ "$1" = "$2" ]; then _pass "$3"; else _fail "$3 (expected='$1' actual='$2')"; fi
}
assert_ne() { # unexpected actual label
  if [ "$1" != "$2" ]; then _pass "$3"; else _fail "$3 (value='$2' should differ from '$1')"; fi
}
assert_contains() { # haystack needle label
  case "$1" in *"$2"*) _pass "$3" ;; *) _fail "$3 (missing substring: '$2')" ;; esac
}
assert_not_contains() { # haystack needle label
  case "$1" in *"$2"*) _fail "$3 (unexpected substring: '$2')" ;; *) _pass "$3" ;; esac
}
assert_empty_dir() { # dir label
  if [ -z "$(find "$1" -mindepth 1 2>/dev/null | head -n 1)" ]; then
    _pass "$2"
  else
    _fail "$2 (dir not empty: $1)"
  fi
}

# ---------------------------------------------------------------- runners
# Run the wrapper under the ambient PATH; capture combined output + exit code into OUT / RC.
run_wrapper() { OUT="$("$WRAPPER" "$@" 2>&1)"; RC=$?; }

# Run the wrapper under a RESTRICTED PATH (first arg), the rest passed to the wrapper. WRAPPER is
# absolute so it needs no PATH lookup; its `#!/usr/bin/env bash` shebang finds bash via the restricted PATH.
run_wrapper_with_path() {
  local pathval="$1"; shift
  OUT="$( ( PATH="$pathval"; export PATH; "$WRAPPER" "$@" ) 2>&1 )"; RC=$?
}

# Build a PATH directory that symlinks every tool the flow needs EXCEPT the named one, so a single
# binary can be hidden while bash/env/cp/python3/... stay reachable (dropping a whole PATH dir would
# also hide coreutils and break the run for the wrong reason).
NEEDED_TOOLS="env sh bash dirname basename cat sed grep egrep fgrep ls sort uniq mkdir touch cp rm mv find pwd printf awk head tail tr wc cut chmod ln readlink stat mktemp date true false test expr python3 git"
make_shim_without() { # hidden_tool shim_dir
  local hide="$1" shim="$2" t p
  mkdir -p "$shim"
  for t in $NEEDED_TOOLS; do
    [ "$t" = "$hide" ] && continue
    p="$(command -v "$t" 2>/dev/null || true)"
    case "$p" in /*) ln -sf "$p" "$shim/$t" ;; esac
  done
}

echo "test-install-wrapper.sh :: repo=$REPO"
echo "                          work=$WORK"
echo ""

# ================================================================ AC1
echo "-- AC1: real install --host claude --"
A1="$WORK/a1"; mkdir -p "$A1"
run_wrapper "$A1" --host claude
assert_eq 0 "$RC" "AC1: real install --host claude exits 0"
assert_contains "$OUT" "Result: PASS" "AC1: doctor reports PASS"
assert_contains "$OUT" ".harness/mode):" "AC1: wrapper prints the target mode line"
assert_contains "$OUT" "/dmc-status" "AC1: wrapper prints next-steps hint"
assert_eq "active" "$(cat "$A1/.harness/mode" 2>/dev/null || true)" "AC1: installed .harness/mode is active"
assert_contains "$OUT" "$A1" "AC1: mode/report line names the absolute target path"

# ================================================================ AC2
echo "-- AC2: --dry-run writes nothing, no doctor --"
A2="$WORK/a2"; mkdir -p "$A2"
run_wrapper "$A2" --host both --dry-run
assert_eq 0 "$RC" "AC2: --dry-run exits 0"
assert_empty_dir "$A2" "AC2: --dry-run writes nothing (target still empty)"
assert_not_contains "$OUT" "Result: PASS" "AC2: doctor NOT run on --dry-run"
assert_contains "$OUT" "Dry-run complete" "AC2: wrapper reports dry-run without verifying"

# ================================================================ AC3a
echo "-- AC3a: python3 hidden from PATH --"
SHIM_NOPY="$WORK/shim-nopy"
make_shim_without python3 "$SHIM_NOPY"
A3A="$WORK/a3a"; mkdir -p "$A3A"
run_wrapper_with_path "$SHIM_NOPY" "$A3A" --host claude
assert_ne 0 "$RC" "AC3a: python3 missing -> non-zero exit"
assert_contains "$OUT" "python3" "AC3a: error names python3"
assert_empty_dir "$A3A" "AC3a: no partial install (target still empty)"

# ================================================================ AC3b
echo "-- AC3b: git hidden but python3 present --"
SHIM_NOGIT="$WORK/shim-nogit"
make_shim_without git "$SHIM_NOGIT"
A3B="$WORK/a3b"; mkdir -p "$A3B"
run_wrapper_with_path "$SHIM_NOGIT" "$A3B" --host claude
assert_eq 0 "$RC" "AC3b: git missing + python3 present -> still installs, exit 0"
assert_contains "$OUT" "Result: PASS" "AC3b: doctor PASS with git absent"
assert_contains "$OUT" "WARNING: git" "AC3b: wrapper warns about missing git"

# ================================================================ AC4
echo "-- AC4: bad --host surfaced --"
A4="$WORK/a4"; mkdir -p "$A4"
run_wrapper "$A4" --host xxx
assert_eq 2 "$RC" "AC4: bad --host xxx surfaces the base installer's exit 2 (end-to-end || exit \$?)"
assert_empty_dir "$A4" "AC4: bad --host -> no partial install"

# ================================================================ AC5
echo "-- AC5: absolute path from a different cwd --"
A5="$WORK/a5"; mkdir -p "$A5"
OTHERCWD="$WORK/elsewhere"; mkdir -p "$OTHERCWD"
OUT="$( ( cd "$OTHERCWD" && "$WRAPPER" "$A5" --host claude ) 2>&1 )"; RC=$?
assert_eq 0 "$RC" "AC5: absolute path from a different cwd exits 0"
assert_contains "$OUT" "Result: PASS" "AC5: doctor PASS via absolute path from foreign cwd"

# ================================================================ AC6
echo "-- AC6: doctor-fail propagation --"
# The single-shot wrapper always RE-SHIPS Ring-0 before doctoring (the install is idempotent and
# self-heals), so a clean install cannot be made to fail doctor THROUGH one wrapper invocation.
# We therefore prove the two halves separately:
#   (1) the doctor-fail CONDITION the wrapper forwards — doctor exits non-zero, naming Ring-0; and
#   (2) the wrapper surfaces ANY non-zero step via the exact `( cd "$TGT" && bin/dmc doctor ) || exit $?`
#       construct, which is identical to the `"$INSTALLER" "$@" || exit $?` path AC4 proves
#       end-to-end (base-installer exit 2 surfaced as the wrapper's exit 2). No faked wrapper exit.
A6="$WORK/a6"; mkdir -p "$A6"
run_wrapper "$A6" --host claude
assert_eq 0 "$RC" "AC6 setup: fresh install exits 0"
rm -f "$A6/bin/lib/dmc-bash-radius.py"   # seed a Ring-0 omission (verdict CLI gone)
DOUT="$( ( cd "$A6" && bin/dmc doctor ) 2>&1 )"; DRC=$?
assert_ne 0 "$DRC" "AC6: doctor exits non-zero on Ring-0 omission (the code the wrapper forwards)"
assert_contains "$DOUT" "Ring-0 missing" "AC6: doctor names 'Ring-0 missing'"

# ================================================================ AC9
echo "-- AC9: idempotent second run --"
run_wrapper "$A1" --host claude
assert_eq 0 "$RC" "AC9: second install into the same target (idempotent) exits 0"
assert_contains "$OUT" "Result: PASS" "AC9: idempotent re-run still doctors PASS"

# ---------------------------------------------------------------- summary
echo ""
echo "==== install.sh wrapper smoke test: $PASS passed, $FAIL failed ===="
if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
exit 0
