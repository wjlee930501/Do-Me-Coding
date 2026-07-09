#!/usr/bin/env bash
# test-agents-md.sh — DMC v1 M6.5 (DMC-T011b.4) host AGENTS.md generator + validator suite.
#
# Nature: INTEGRATION test for the `dmc agents-md` verb (bin/lib/dmc-agents-md.py) end-to-end
# through bin/dmc. Standalone — no _m65common.sh dependency; owns no files in common with the
# sibling Codex-shim / skills-mirror suites.
#
# Drives the real `dmc agents-md` verb over three synthetic host repos built in mktemp (a node-ish
# repo with package.json, a python-ish repo with pyproject.toml, and an EMPTY repo) and asserts:
#   - all ten CODEX_ADAPTER §5 sections are emitted on each host;
#   - derivable facts render (npm/python package managers, categorized commands) and every
#     non-derivable fact renders literally `Unknown`, aggregated in the section-10 Unknowns list;
#   - the merge policy: a second generate onto an existing AGENTS.md is REFUSED (never overwritten);
#   - the 32 KiB size budget: an oversized synthetic repo warns on stderr (exit 0) and is NOT
#     truncated;
#   - `dmc agents-md --validate` is green on generated output, and REFUSES (negative controls) a
#     file with a section deleted and a file with a guessed-filler placeholder where Unknown belongs.
# Finally it asserts the live repo's `git status --porcelain` is byte-identical before and after
# (every write is confined to mktemp; the real repo is never touched).
#
# Never reads .env / credentials; never mutates the live repo; no network / live / model / API call;
# no subprocess beyond `bin/dmc`, `git status --porcelain`, and coreutils in mktemp sandboxes.
#
# Usage: test-agents-md.sh   Build the fixtures, run the assertions, print PASS/FAIL + summary,
# exit 0 iff all pass.

set -u

SELF_DIR=$(cd -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd -P) || { echo "FATAL: script dir"; exit 2; }
ROOT=$(cd -- "$SELF_DIR/../../.." >/dev/null 2>&1 && pwd -P) || { echo "FATAL: repo root"; exit 2; }
DMC="$ROOT/bin/dmc"

if ! git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "FATAL: repo root is not a git worktree: $ROOT"; exit 2
fi
[ -x "$DMC" ] || [ -f "$DMC" ] || { echo "FATAL: bin/dmc not found: $DMC"; exit 2; }

PASS=0; FAIL=0
record() { # record PASS|FAIL DESC
  if [ "$1" = PASS ]; then PASS=$((PASS+1)); printf '  [PASS] %s\n' "$2"
  else FAIL=$((FAIL+1)); printf '  [FAIL] %s\n' "$2"; fi
}

echo "test-agents-md.sh :: root=$ROOT"
PORCELAIN_BEFORE=$(git -C "$ROOT" status --porcelain 2>/dev/null)

TMP=$(mktemp -d "${TMPDIR:-/tmp}/dmc-agents-md-suite.XXXXXX") || { echo "FATAL: mktemp"; exit 2; }
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

# ---- assertion helpers ---------------------------------------------------------
assert_all_sections() { # LABEL FILE
  local label="$1" file="$2" n missing=0
  for n in 1 2 3 4 5 6 7 8 9 10; do
    grep -qE "^## $n\. " "$file" || missing=$((missing+1))
  done
  [ "$missing" -eq 0 ] && record PASS "$label: all 10 required sections present" \
                       || record FAIL "$label: $missing required section(s) missing"
}
assert_contains() { # LABEL FILE NEEDLE
  grep -qF "$3" "$2" && record PASS "$1" || record FAIL "$1 (missing: $3)"
}
assert_validate_green() { # LABEL FILE
  "$DMC" agents-md --validate "$2" >/dev/null 2>&1 \
    && record PASS "$1" || record FAIL "$1 (validator did not exit 0)"
}

# ---- node-ish host -------------------------------------------------------------
NODE="$TMP/node"; mkdir -p "$NODE/src"
cat > "$NODE/package.json" <<'JSON'
{
  "name": "fixture-node",
  "main": "index.js",
  "scripts": { "test": "jest", "lint": "eslint .", "build": "tsc -b", "typecheck": "tsc --noEmit" }
}
JSON
printf "console.log('fixture');\n" > "$NODE/index.js"
printf "module.exports = 1;\n" > "$NODE/src/app.js"

echo "  -- node-ish host --"
"$DMC" agents-md --root "$NODE" --out "$NODE/AGENTS.md" >/dev/null 2>&1
NODE_RC=$?
[ "$NODE_RC" -eq 0 ] && record PASS "node: generate exits 0" || record FAIL "node: generate exit $NODE_RC"
assert_all_sections "node" "$NODE/AGENTS.md"
assert_contains "node: npm package manager detected" "$NODE/AGENTS.md" "Package manager: npm"
assert_contains "node: test command categorized" "$NODE/AGENTS.md" "Test: \`npm test\`"
assert_contains "node: lint command categorized" "$NODE/AGENTS.md" "Lint: \`npm run lint\`"
assert_contains "node: build command categorized" "$NODE/AGENTS.md" "Build: \`npm run build\`"
assert_contains "node: typecheck command categorized" "$NODE/AGENTS.md" "Typecheck: \`npm run typecheck\`"
assert_validate_green "node: generated doc validates green" "$NODE/AGENTS.md"

# merge policy: a second generate onto the existing AGENTS.md is REFUSED, not overwritten.
REFUSE_ERR="$TMP/node-refuse.err"
"$DMC" agents-md --root "$NODE" --out "$NODE/AGENTS.md" >/dev/null 2>"$REFUSE_ERR"
REFUSE_RC=$?
[ "$REFUSE_RC" -eq 3 ] && record PASS "node: re-generate onto existing AGENTS.md REFUSED (exit 3)" \
                       || record FAIL "node: expected refuse exit 3, got $REFUSE_RC"
grep -qF "refusing to overwrite" "$REFUSE_ERR" \
  && record PASS "node: refusal message names the never-overwrite policy" \
  || record FAIL "node: refusal message missing"

# ---- python-ish host -----------------------------------------------------------
PY="$TMP/py"; mkdir -p "$PY"
cat > "$PY/pyproject.toml" <<'TOML'
[project]
name = "fixture-py"

[tool.pytest.ini_options]
testpaths = ["tests"]
TOML
printf "cffi\n" > "$PY/requirements.txt"
printf "print('fixture')\n" > "$PY/app.py"

echo "  -- python-ish host --"
"$DMC" agents-md --root "$PY" --out "$PY/AGENTS.md" >/dev/null 2>&1
PY_RC=$?
[ "$PY_RC" -eq 0 ] && record PASS "python: generate exits 0" || record FAIL "python: generate exit $PY_RC"
assert_all_sections "python" "$PY/AGENTS.md"
assert_contains "python: python package manager detected" "$PY/AGENTS.md" "Package manager: python"
assert_contains "python: pytest test command detected" "$PY/AGENTS.md" "Test: \`pytest\`"
assert_contains "python: lint renders literally Unknown" "$PY/AGENTS.md" "Lint: Unknown"
assert_contains "python: build renders literally Unknown" "$PY/AGENTS.md" "Build: Unknown"
assert_contains "python: Unknowns list aggregates the lint gap" "$PY/AGENTS.md" \
  "Lint / typecheck / test / build commands: lint"
assert_validate_green "python: generated doc validates green" "$PY/AGENTS.md"

# ---- empty host ----------------------------------------------------------------
EMPTY="$TMP/empty"; mkdir -p "$EMPTY"
printf "just notes\n" > "$EMPTY/notes.txt"

echo "  -- empty host --"
"$DMC" agents-md --root "$EMPTY" --out "$EMPTY/AGENTS.md" >/dev/null 2>&1
EMPTY_RC=$?
[ "$EMPTY_RC" -eq 0 ] && record PASS "empty: generate exits 0" || record FAIL "empty: generate exit $EMPTY_RC"
assert_all_sections "empty" "$EMPTY/AGENTS.md"
assert_contains "empty: package manager renders literally Unknown" "$EMPTY/AGENTS.md" \
  "Package manager: Unknown"
assert_contains "empty: test command renders literally Unknown" "$EMPTY/AGENTS.md" "Test: Unknown"
# landmarks section renders a literal Unknown (no landmark-classified files in an empty repo).
awk '/^## 4\./{f=1;next} /^## 5\./{f=0} f' "$EMPTY/AGENTS.md" | grep -qF -- "- Unknown" \
  && record PASS "empty: architecture landmarks render literally Unknown" \
  || record FAIL "empty: landmarks did not render Unknown"
# the Unknowns list (section 10) aggregates the non-derivable fields. Isolate §10 by its own
# heading and the next EMITTED heading (not §10-terminal), so the check survives section reordering.
awk '/^## [0-9]+\. /{f=($0 ~ /^## 10\. /)} f' "$EMPTY/AGENTS.md" | grep -qF "package manager" \
  && record PASS "empty: section-10 Unknowns list aggregates the package-manager gap" \
  || record FAIL "empty: section-10 Unknowns list did not aggregate"
assert_contains "empty: purpose is never invented (Unknown)" "$EMPTY/AGENTS.md" "Purpose: Unknown"
assert_validate_green "empty: generated doc validates green (Unknown accepted, not filler)" \
  "$EMPTY/AGENTS.md"

# ---- 32 KiB size-budget warn (oversized synthetic input, never truncated) ------
echo "  -- 32 KiB size-budget warn --"
BIG="$TMP/big"; mkdir -p "$BIG/migrations"
i=0
while [ "$i" -lt 700 ]; do
  printf -- "-- migration %d\n" "$i" > "$BIG/migrations/$(printf 'm%04d_change_some_table_name.sql' "$i")"
  i=$((i+1))
done
BIG_ERR="$TMP/big.err"
"$DMC" agents-md --root "$BIG" --out "$BIG/AGENTS.md" >/dev/null 2>"$BIG_ERR"
BIG_RC=$?
[ "$BIG_RC" -eq 0 ] && record PASS "big: oversized generate still exits 0 (warn, not fail)" \
                    || record FAIL "big: expected exit 0, got $BIG_RC"
BIG_BYTES=$(wc -c < "$BIG/AGENTS.md" | tr -d ' ')
[ "$BIG_BYTES" -gt 32768 ] && record PASS "big: output exceeds the 32768-byte budget ($BIG_BYTES bytes)" \
                           || record FAIL "big: output not oversized ($BIG_BYTES bytes)"
grep -qF "project_doc_max_bytes budget" "$BIG_ERR" \
  && record PASS "big: stderr warns about the Codex size budget" \
  || record FAIL "big: size-budget warning missing"
grep -qF "section 4" "$BIG_ERR" && grep -qF "section 7" "$BIG_ERR" \
  && record PASS "big: warning names the sections to externalize (4 and 7)" \
  || record FAIL "big: warning did not name sections to externalize"
SQL_ROWS=$(grep -c "data-surface heuristic" "$BIG/AGENTS.md")
[ "$SQL_ROWS" -eq 700 ] && record PASS "big: NOT truncated — all 700 migration landmarks present" \
                        || record FAIL "big: truncated or miscounted ($SQL_ROWS/700 landmarks)"
assert_validate_green "big: oversized doc still validates green" "$BIG/AGENTS.md"

# ---- validator negative controls ----------------------------------------------
echo "  -- validator negative controls --"
# (a) a section deleted -> REFUSED. Delete §6 by its own heading and the next EMITTED heading
# (whatever number follows), not a hardcoded §7 successor, so the control survives reordering.
CUT="$TMP/cut-AGENTS.md"
awk '/^## [0-9]+\. /{skip=($0 ~ /^## 6\. /)} !skip' "$NODE/AGENTS.md" > "$CUT"
"$DMC" agents-md --validate "$CUT" >/dev/null 2>&1
CUT_RC=$?
[ "$CUT_RC" -eq 3 ] && record PASS "negctl: validator REFUSES a doc with section 6 deleted (exit 3)" \
                    || record FAIL "negctl: expected refuse exit 3 for missing section, got $CUT_RC"
# (b) a guessed-filler placeholder where Unknown belongs -> REFUSED.
FILLED="$TMP/filled-AGENTS.md"
sed 's/Purpose: Unknown/Purpose: TODO write the project purpose/' "$EMPTY/AGENTS.md" > "$FILLED"
"$DMC" agents-md --validate "$FILLED" >/dev/null 2>&1
FILLED_RC=$?
[ "$FILLED_RC" -eq 3 ] && record PASS "negctl: validator REFUSES a guessed-filler placeholder (exit 3)" \
                       || record FAIL "negctl: expected refuse exit 3 for filler, got $FILLED_RC"

# ---- real-repo cleanliness -----------------------------------------------------
echo "  -- real-repo cleanliness --"
PORCELAIN_AFTER=$(git -C "$ROOT" status --porcelain 2>/dev/null)
[ "$PORCELAIN_BEFORE" = "$PORCELAIN_AFTER" ] \
  && record PASS "real repo byte-identical: git status --porcelain unchanged by the suite" \
  || record FAIL "real repo CHANGED during the suite (porcelain drift — a write escaped mktemp)"

echo "  ----"
echo "  RESULT: $PASS PASS / $FAIL FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
