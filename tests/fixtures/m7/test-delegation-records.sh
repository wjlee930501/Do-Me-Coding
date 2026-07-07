#!/usr/bin/env bash
# test-delegation-records.sh — DMC v1 M7 P14 delegation runtime-records controls (append/check).
#
# Nature: ADVERSARIAL/positive test. It exercises the delegation runtime-records pipeline
# (bin/lib/dmc-delegation.py append/check) against a DISPOSABLE fake repo root under mktemp — the
# module's append/check functions take an explicit `root`, so every write lands in the sandbox and
# the LIVE .harness/runs/ (e.g. dmc-run-92b7f126f79d) is NEVER touched. It also drives the real
# `bin/dmc delegation` CLI for the side-effect-free refusals (nonexistent run) to prove the shipped
# verb wiring fails closed without writing the real repo. Rows: genesis + chained append PASS; bad
# prev_hash / nonexistent run / may_mutate-without-resolvable-scope-lock / scope-lock run_id
# mismatch REFUSE; clean check PASS; tampered-middle-line + unvalidated-consumption REFUSE.
#
# Role resolution hits the REAL orchestration/roles.json (read-only subprocess). Never reads .env /
# credentials; never mutates the live repo (porcelain-before/after check); no network / model call.
#
# Usage: test-delegation-records.sh   Run all checks, print RESULT + summary, exit 0/1.

set -u

SELF_DIR=$(cd -- "$(dirname -- "$0")" >/dev/null 2>&1 && pwd -P) || { echo "FATAL: script dir"; exit 2; }
# shellcheck source=_m7common.sh
. "$SELF_DIR/_m7common.sh"

if ! git -C "$M7_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "FATAL: repo root is not a git worktree: $M7_ROOT"; exit 2
fi

SANDBOX=$(mktemp -d "${TMPDIR:-/tmp}/dmc-m7-deleg.XXXXXX") || { echo "FATAL: mktemp"; exit 2; }
cleanup() { rm -rf "$SANDBOX"; }
trap cleanup EXIT

# ---- fixture kit: drives the dmc-delegation.py module against a fake root -----------------------
KIT="$SANDBOX/delegkit.py"
cat > "$KIT" <<'PY'
import hashlib, importlib.util, json, os, sys
sys.dont_write_bytecode = True   # never write __pycache__ under bin/lib when importing the module

def _mod():
    spec = importlib.util.spec_from_file_location("dmc_delegation_kit", os.environ["DELEGMOD"])
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m

BASE = {
    "schema": "dmc.delegation.v1",
    "work_id": "m7-deleg-work",
    "plan_hash": "a" * 16,
    "repo_hash": "b" * 16,
    "delegation_id": "deleg-0001",
    "role": "verifier",
    "capability_class": "deterministic-tool",
    "may_mutate": False,
    "depth": 0,
    "max_depth": 3,
    "artifact_ref": None,
    "artifact_schema": None,
    "validation_verdict": "PENDING",
    "prev_hash": "genesis",
}

def build(ov):
    o = dict(BASE)
    o.update(ov)
    return o

def compact(o):
    return json.dumps(o, sort_keys=True, separators=(",", ":"))

def main():
    m = _mod()
    verb = sys.argv[1]
    if verb == "mkrec":
        ov = json.loads(sys.argv[3]) if len(sys.argv) > 3 else {}
        with open(sys.argv[2], "w", encoding="utf-8") as f:
            json.dump(build(ov), f)
    elif verb == "append":
        ok, reasons = m.append_delegation_record(sys.argv[2], sys.argv[3], sys.argv[4])
        print("OK" if ok else (reasons[0] if reasons else "REFUSED"))
        sys.exit(0 if ok else 3)
    elif verb == "check":
        ok, reasons, count = m.check_delegation_chain(sys.argv[2], sys.argv[3])
        print(("OK %d" % count) if ok else (reasons[0] if reasons else "REFUSED"))
        sys.exit(0 if ok else 3)
    elif verb == "tip":
        print(m._chain_tip_hash(m._delegations_path(sys.argv[2], sys.argv[3])))
    elif verb == "scn-tamper":
        deleg = sys.argv[2]
        l1 = compact(build({"delegation_id": "deleg-t1"}))
        tip1 = hashlib.sha256(l1.encode("utf-8")).hexdigest()
        l2 = compact(build({"delegation_id": "deleg-t2", "prev_hash": tip1}))
        tampered_l1 = compact(build({"delegation_id": "deleg-t1-TAMPERED"}))
        with open(deleg, "w", encoding="utf-8") as f:
            f.write(tampered_l1 + "\n" + l2 + "\n")
    elif verb == "scn-unvalidated":
        uc = build({"delegation_id": "deleg-uc", "artifact_ref": ".harness/artifacts/x.json",
                    "artifact_schema": "dmc.x.v1", "validation_verdict": "PENDING"})
        with open(sys.argv[2], "w", encoding="utf-8") as f:
            f.write(compact(uc) + "\n")

main()
PY

kit() { DELEGMOD="$M7_DELEGLIB" python3 "$KIT" "$@"; }

# run_kit VERB ARGS...  — captures stdout in OUT and exit code in RC.
run_kit() { OUT=$(DELEGMOD="$M7_DELEGLIB" python3 "$KIT" "$@" 2>/dev/null); RC=$?; }

nlines() { [ -f "$1" ] && wc -l < "$1" | tr -d ' ' || printf 0; }

# ---- fake root -----------------------------------------------------------------
ROOT="$SANDBOX/root"
RID="m7-deleg-run"
DELEG="$ROOT/.harness/runs/$RID/delegations.jsonl"
mkdir -p "$ROOT/.harness/runs/$RID"

case_append() {
  echo "  -- append: genesis + chained-2nd PASS; bad prev_hash / scope-lock refusals --"

  kit mkrec "$SANDBOX/rec1.json" '{"delegation_id":"deleg-a1"}'
  run_kit append "$ROOT" "$RID" "$SANDBOX/rec1.json"
  assert_eq 0 "$RC" "D-P1 genesis append onto an absent chain file ACCEPTED"
  assert_eq 1 "$(nlines "$DELEG")" "D-P1b exactly one line written"

  local tip1; tip1=$(kit tip "$ROOT" "$RID")
  kit mkrec "$SANDBOX/rec2.json" "{\"delegation_id\":\"deleg-a2\",\"prev_hash\":\"$tip1\"}"
  run_kit append "$ROOT" "$RID" "$SANDBOX/rec2.json"
  assert_eq 0 "$RC" "D-P2 chained 2nd record (prev_hash = sha256(line1, LF-excluded)) ACCEPTED"
  assert_eq 2 "$(nlines "$DELEG")" "D-P2b two lines after the chained append"

  # bad prev_hash (not the chain tip) -> REFUSE, chain untouched (still 2 lines).
  kit mkrec "$SANDBOX/rec_badprev.json" '{"delegation_id":"deleg-badprev","prev_hash":"ffffffffffffffff"}'
  run_kit append "$ROOT" "$RID" "$SANDBOX/rec_badprev.json"
  assert_eq 3 "$RC" "D-N1 wrong prev_hash REFUSED"
  assert_contains "$OUT" "DELEG-CHAIN-BREAK" "D-N1 reason is DELEG-CHAIN-BREAK"
  assert_eq 2 "$(nlines "$DELEG")" "D-N1b chain untouched after the refusal"

  local tip2; tip2=$(kit tip "$ROOT" "$RID")

  # may_mutate:true whose scope_lock_ref does not resolve -> REFUSE.
  kit mkrec "$SANDBOX/rec_unresolved.json" \
    "{\"delegation_id\":\"deleg-unresolved\",\"role\":\"implementer\",\"capability_class\":\"standard-implementation\",\"may_mutate\":true,\"scope_lock_ref\":\"$SANDBOX/does-not-exist.lock.json\",\"prev_hash\":\"$tip2\"}"
  run_kit append "$ROOT" "$RID" "$SANDBOX/rec_unresolved.json"
  assert_eq 3 "$RC" "D-N3 may_mutate:true + unresolvable scope_lock_ref REFUSED"
  assert_contains "$OUT" "DELEG-SCOPE-LOCK-UNRESOLVED" "D-N3 reason is DELEG-SCOPE-LOCK-UNRESOLVED"

  # may_mutate:true whose scope_lock_ref resolves but run_id mismatches -> REFUSE.
  printf '{"schema":"dmc.scope-lock.v1","run_id":"some-other-run"}' > "$SANDBOX/mismatch.lock.json"
  kit mkrec "$SANDBOX/rec_mismatch.json" \
    "{\"delegation_id\":\"deleg-mismatch\",\"role\":\"implementer\",\"capability_class\":\"standard-implementation\",\"may_mutate\":true,\"scope_lock_ref\":\"$SANDBOX/mismatch.lock.json\",\"prev_hash\":\"$tip2\"}"
  run_kit append "$ROOT" "$RID" "$SANDBOX/rec_mismatch.json"
  assert_eq 3 "$RC" "D-N4 scope_lock_ref resolves but run_id mismatches REFUSED"
  assert_contains "$OUT" "DELEG-SCOPE-LOCK-RUN-MISMATCH" "D-N4 reason is DELEG-SCOPE-LOCK-RUN-MISMATCH"
  assert_eq 2 "$(nlines "$DELEG")" "D-N4b chain still untouched (2 lines) after the mutator refusals"
}

case_nonexistent_run() {
  echo "  -- nonexistent run REFUSED (module fake-root + real bin/dmc CLI, both side-effect-free) --"

  # module path against a run dir that does not exist under the fake root.
  kit mkrec "$SANDBOX/rec_norun.json" '{"delegation_id":"deleg-norun"}'
  run_kit append "$ROOT" "m7-deleg-absent-run" "$SANDBOX/rec_norun.json"
  assert_eq 3 "$RC" "D-N2 nonexistent run directory REFUSED (module)"
  assert_contains "$OUT" "DELEG-NO-RUN" "D-N2 reason is DELEG-NO-RUN"

  # real CLI: append to a run that does not exist under the LIVE repo -> REFUSE, nothing written.
  # (record-positional-first arg order; the module's argparse rejects a positional after --run.)
  "$M7_DMC" delegation append "$SANDBOX/rec_norun.json" --run m7-deleg-nonexistent-xyz >/dev/null 2>&1
  assert_eq 3 "$?" "D-N2c bin/dmc delegation append <rec> --run <nonexistent> REFUSED (real CLI, no write)"

  # real CLI: check a run that does not exist under the LIVE repo -> REFUSE (read-only).
  "$M7_DMC" delegation check --run m7-deleg-nonexistent-xyz >/dev/null 2>&1
  assert_eq 3 "$?" "D-N2d bin/dmc delegation check --run <nonexistent> REFUSED (real CLI, read-only)"
}

case_check() {
  echo "  -- check: clean chain PASS; tampered-line + unvalidated-consumption REFUSE --"

  run_kit check "$ROOT" "$RID"
  assert_eq 0 "$RC" "D-P3 clean 2-record chain PASSES check end-to-end"
  assert_contains "$OUT" "OK 2" "D-P3b check reports 2 records verified"

  # tampered middle line: line2.prev_hash bound to the ORIGINAL line1 bytes; file stores a tampered
  # line1 -> the running hash chain no longer matches -> REFUSE.
  local trid="m7-deleg-tamper"
  mkdir -p "$ROOT/.harness/runs/$trid"
  kit scn-tamper "$ROOT/.harness/runs/$trid/delegations.jsonl"
  run_kit check "$ROOT" "$trid"
  assert_eq 3 "$RC" "D-N5 tampered middle line breaks the hash chain REFUSED"
  assert_contains "$OUT" "DELEG-CHAIN-BREAK" "D-N5 reason is DELEG-CHAIN-BREAK"

  # unvalidated consumption smuggled directly into the file (artifact_ref set, verdict != PASS).
  local urid="m7-deleg-uc"
  mkdir -p "$ROOT/.harness/runs/$urid"
  kit scn-unvalidated "$ROOT/.harness/runs/$urid/delegations.jsonl"
  run_kit check "$ROOT" "$urid"
  assert_eq 3 "$RC" "D-N6 unvalidated-consumption record REFUSED by check"
  assert_contains "$OUT" "DELEG-UNVALIDATED-CONSUMPTION" "D-N6 reason is DELEG-UNVALIDATED-CONSUMPTION"
}

main() {
  echo "test-delegation-records.sh :: root=$M7_ROOT"
  m7_capture_before
  case_append
  case_nonexistent_run
  case_check
  echo "  -- real-repo cleanliness --"
  m7_assert_repo_untouched
  echo "  ----"
  echo "  RESULT: $PASS PASS / $FAIL FAIL"
  [ "$FAIL" -eq 0 ] && exit 0 || exit 1
}

main
