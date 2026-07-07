#!/usr/bin/env bash
# _m8common.sh — shared helpers for the DMC v1 M8 host-install suites
# (test-install-roundtrip.sh, test-idempotency.sh, test-doctor-negcontrols.sh,
#  test-manifest-drift.sh).
#
# Nature: TEST SUPPORT. Sourced, never run directly. Provides:
#   - repo-root + installer/uninstaller/doctor/manifest handles,
#   - PASS/FAIL bookkeeping (record/assert_* house style, mirrors _m6common.sh),
#   - a real-repo porcelain-before/after guard (proves the suites leave the live
#     repo byte-identical — every write lands in a mktemp sandbox),
#   - the FIVE fixture host-tree builders (empty, node, existing-claude-settings,
#     existing-OMC, existing-codex) materialized at RUNTIME into mktemp sandboxes
#     (M6/M6.5 heredoc precedent — canonical-form merge targets so the DMC
#     append->strip round-trip is byte-exact); existing-codex carries a
#     pre-existing .codex/config.toml WITHOUT the DMC sentinel = FOREIGN,
#   - install/uninstall/doctor drivers + a byte-clean assertion (git porcelain
#     empty AND diff -r after pruning the empty scaffold dirs the uninstaller
#     honestly leaves behind) + the Codex-scoped forbidden-lexeme grep.
#
# Never reads .env / credentials; never mutates the live repo; no network / live /
# model / API call. Every install/doctor call is pinned to a mktemp sandbox.

# Refuse direct execution — this is a library.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  echo "_m8common.sh is a sourced library, not a standalone test" >&2
  exit 2
fi

# ---- repo root + control-plane handles -----------------------------------------
_M8_COMMON_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P) \
  || { echo "FATAL: cannot resolve _m8common dir" >&2; exit 2; }
M8_ROOT=$(cd -- "$_M8_COMMON_DIR/../../.." >/dev/null 2>&1 && pwd -P) \
  || { echo "FATAL: cannot resolve repo root" >&2; exit 2; }
M8_INSTALL="$M8_ROOT/.claude/install/dmc-install.sh"
M8_UNINSTALL="$M8_ROOT/.claude/install/dmc-uninstall.sh"
M8_DMC="$M8_ROOT/bin/dmc"
M8_DOCTORLIB="$M8_ROOT/bin/lib/dmc-doctor.py"
M8_MANIFEST="$M8_ROOT/INSTALL_MANIFEST.md"

# The Codex-scoped honesty control lexemes (identical set to dmc-doctor.py /
# the M8 plan §Acceptance): NO /codex/i line may carry any of these.
M8_FORBIDDEN_LEXEMES='enforced|enforce|fires|firing|runtime-enforced|active|guaranteed'
# The enumerated DMC-INTERNAL PROVENANCE exclusions (INSTALL_MANIFEST.md
# §Dangling-reference rule): shipped files may cite these as breadcrumbs; they are
# never operating dependencies and are deliberately NOT bundled.
m8_is_provenance_ref() { # REF -> 0 if in the enumerated exclusion set
  case "$1" in
    docs/CODEX_ADAPTER.md|adapters/codex/README.md|.harness/evidence/dmc-v1-m6.5-spike-*) return 0 ;;
    *) return 1 ;;
  esac
}

# ---- PASS/FAIL bookkeeping (house style) ---------------------------------------
PASS=0; FAIL=0
record() { # record PASS|FAIL DESC
  if [ "$1" = PASS ]; then PASS=$((PASS+1)); printf '  [PASS] %s\n' "$2"
  else FAIL=$((FAIL+1)); printf '  [FAIL] %s\n' "$2"; fi
}
assert_eq()  { [ "$1" = "$2" ] && record PASS "$3" || record FAIL "$3 (want [$1] got [$2])"; }
assert_zero()    { [ "$1" -eq 0 ] && record PASS "$2" || record FAIL "$2 (rc=$1, wanted 0)"; }
assert_nonzero() { [ "$1" -ne 0 ] && record PASS "$2" || record FAIL "$2 (rc=$1, wanted non-zero)"; }
assert_contains()     { case "$1" in *"$2"*) record PASS "$3" ;; *) record FAIL "$3 (missing [$2])" ;; esac; }
assert_not_contains() { case "$1" in *"$2"*) record FAIL "$3 (found [$2])" ;; *) record PASS "$3" ;; esac; }
assert_file()   { [ -e "$1" ] && record PASS "$2" || record FAIL "$2 (absent: $1)"; }
assert_absent() { [ -e "$1" ] && record FAIL "$2 (present: $1)" || record PASS "$2"; }
assert_same_sha() { # F1 F2 DESC
  local a b; a=$(sha256_of "$1"); b=$(sha256_of "$2")
  [ -n "$a" ] && [ "$a" = "$b" ] && record PASS "$3" || record FAIL "$3 (sha differ / missing)"
}

# ---- portable helpers ----------------------------------------------------------
sha256_of() { # FILE -> hex digest ('' if missing)
  [ -f "$1" ] || { printf ''; return 0; }
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

# Sandbox tracking: every m8_mktemp path is torn down by m8_cleanup (EXIT trap).
_M8_TMPS=()
m8_mktemp() { # PREFIX -> fresh mktemp -d path (tracked for cleanup)
  local d; d=$(mktemp -d "${TMPDIR:-/tmp}/dmc-m8-${1:-t}.XXXXXX") \
    || { echo "FATAL: mktemp failed" >&2; exit 2; }
  _M8_TMPS+=("$d"); printf '%s' "$d"
}
m8_cleanup() { local d; for d in "${_M8_TMPS[@]:-}"; do [ -n "$d" ] && rm -rf "$d"; done; }

# ---- real-repo cleanliness guard (mirrors _m6common.sh) ------------------------
M8_PORCELAIN_BEFORE=""
m8_capture_before() { M8_PORCELAIN_BEFORE=$(git -C "$M8_ROOT" status --porcelain 2>/dev/null); }
m8_assert_repo_untouched() {
  local after; after=$(git -C "$M8_ROOT" status --porcelain 2>/dev/null)
  [ "$M8_PORCELAIN_BEFORE" = "$after" ] \
    && record PASS "real repo byte-identical: git status --porcelain unchanged by the suite" \
    || record FAIL "real repo CHANGED during the suite (porcelain drift — a write escaped the sandbox)"
}

# ---- fixture host-tree builders ------------------------------------------------
# Every builder mints a committed git repo (byte-clean baseline for porcelain +
# diff -r). Merge targets are written in DMC-canonical JSON (python json.dumps
# indent=2 + trailing "\n"), which is exactly what the uninstaller re-serializes,
# so the append->strip round-trip is byte-exact (plan §Risks: canonical-form).
_git_baseline() { # DIR
  git init -q "$1" || return 1
  git -C "$1" config user.email m8@example.com
  git -C "$1" config user.name "M8 Fixture"
}
_git_commit() { git -C "$1" add -A && git -C "$1" commit -q -m baseline; }

build_host_empty() { # DIR  — bare host, only a README.
  _git_baseline "$1" || return 1
  printf '# empty host fixture\n' > "$1/README.md"
  _git_commit "$1"
}

build_host_node() { # DIR  — a Node project (package.json + node .gitignore).
  _git_baseline "$1" || return 1
  printf '# node host fixture\n' > "$1/README.md"
  printf '{\n  "name": "host-app",\n  "version": "1.0.0"\n}\n' > "$1/package.json"
  printf 'node_modules\ndist\n' > "$1/.gitignore"
  _git_commit "$1"
}

build_host_claude_settings() { # DIR — canonical settings.json w/ a NON-DMC hook + host CLAUDE.md/.gitignore.
  _git_baseline "$1" || return 1
  printf '# claude-settings host fixture\n' > "$1/README.md"
  mkdir -p "$1/.claude"
  python3 - "$1/.claude/settings.json" <<'PY'
import json, sys
obj = {"hooks": {"PreToolUse": [
    {"matcher": "Bash", "hooks": [
        {"type": "command",
         "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/host-own-hook.sh"}]}]}}
open(sys.argv[1], "w").write(json.dumps(obj, indent=2) + "\n")
PY
  printf '# Host Project\n\nHost-authored guidance. Do not clobber.\n' > "$1/CLAUDE.md"
  printf 'node_modules\n*.log\n' > "$1/.gitignore"
  _git_commit "$1"
}

build_host_omc() { # DIR — a foreign agent harness (.omc marker) present.
  _git_baseline "$1" || return 1
  printf '# omc host fixture\n' > "$1/README.md"
  mkdir -p "$1/.omc"
  printf 'foreign-harness-state\n' > "$1/.omc/state"
  _git_commit "$1"
}

build_host_codex() { # DIR — a pre-existing FOREIGN .codex (no DMC sentinel).
  _git_baseline "$1" || return 1
  printf '# codex host fixture\n' > "$1/README.md"
  mkdir -p "$1/.codex"
  printf 'sandbox_mode = "read-only"\n# host-authored codex config (foreign to DMC)\n' \
    > "$1/.codex/config.toml"
  _git_commit "$1"
}

# ---- drivers -------------------------------------------------------------------
# Output is returned on stdout; callers capture with OUT=$(install_to ... 2>&1); RC=$?
install_to()     { bash "$M8_INSTALL" "$@"; }
uninstall_from() { bash "$M8_UNINSTALL" "$@"; }
# doctor_at HOST: the HOST's own installed doctor (proves shipped Ring-0 executes).
doctor_at()      { "$1/bin/dmc" doctor --root "$1"; }
# doctor_repo_at HOST: the REPO's doctor against a host root (for the Ring-0-omission
# arm, where the host's own bin/ was seeded-removed).
doctor_repo_at() { python3 "$M8_DOCTORLIB" --root "$1"; }
emit_manifest()  { bash "$M8_INSTALL" --emit-manifest; }

# ---- byte-clean assertion ------------------------------------------------------
# The uninstaller restores every FILE byte-identically but honestly leaves empty
# scaffold dirs (its own closing note). git tracks no empty dir, so porcelain is
# the tracked-content proof; for the file-level diff we prune empty dirs from a
# COPY of the host and diff that against the pristine snapshot.
_prune_empty_dirs() { # DIR — remove empty subdirs bottom-up (never DIR itself, never .git)
  local i
  for i in 1 2 3 4 5; do
    find "$1" -depth -mindepth 1 -type d -empty -not -path '*/.git/*' -exec rmdir {} + 2>/dev/null || true
  done
}
snapshot_pristine() { # SRC -> path to a pristine copy (tracked for cleanup)
  local dst; dst=$(m8_mktemp pristine)
  cp -R "$1/." "$dst/"
  printf '%s' "$dst"
}
assert_byte_clean() { # HOST PRISTINE LABEL
  local host="$1" pristine="$2" label="$3" por cmp
  por=$(git -C "$host" status --porcelain 2>/dev/null)
  [ -z "$por" ] && record PASS "$label: git status --porcelain empty (tracked byte-clean)" \
                || record FAIL "$label: porcelain NOT empty after uninstall ([$por])"
  cmp=$(m8_mktemp cmp); rm -rf "$cmp"; cp -R "$host" "$cmp"
  _prune_empty_dirs "$cmp"
  if diff -r --exclude=.git "$pristine" "$cmp" >/dev/null 2>&1; then
    record PASS "$label: diff -r byte-identical to pristine (empty scaffold dirs pruned)"
  else
    record FAIL "$label: diff -r differs from pristine ($(diff -r --exclude=.git "$pristine" "$cmp" 2>&1 | head -3 | tr '\n' ';'))"
  fi
}

# ---- Codex-scoped honesty control ----------------------------------------------
# Extract /codex/i lines from a doctor render (given as a string) and count
# forbidden-lexeme hits. 0 on well-formed output; >=1 proves the control has teeth.
codex_forbidden_hit_count() { # OUTPUT_STRING -> integer
  printf '%s\n' "$1" | grep -i 'codex' | grep -icE "$M8_FORBIDDEN_LEXEMES"
}
codex_lines_of()      { printf '%s\n' "$1" | grep -i 'codex'; }

# ---- suite footer --------------------------------------------------------------
m8_summary() { # SUITE_NAME
  echo "  ----"
  echo "  $1 RESULT: $PASS PASS / $FAIL FAIL"
  [ "$FAIL" -eq 0 ] && exit 0 || exit 1
}
