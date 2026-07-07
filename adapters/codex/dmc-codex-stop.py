#!/usr/bin/env python3
"""dmc-codex-stop.py — Codex Stop ADVISORY shim (Ring-1).

Parity with `.claude/hooks/stop-verify-gate.sh`: in ACTIVE mode, when a run is active, hold
completion via the Ring-0 `dmc stop-gate quick` verdict (receipt coverage + BLOCKED marker +
verification cross-check). Codex has a real Stop hook with `decision:"block"` (corrects the stale
P20 "no Stop hook" assumption); a block injects a synthetic continuation turn.

The gate is STATE-based — the run id comes from `.harness/runs/current-run-id`, not the event — so
this shim reaches parity with the Claude gate on EVERY input, malformed ones included: an unparseable
event still runs the state gate (B2 a), and a missing loop-guard field just proceeds (B2 b). B2 (c):
an absent/failed Ring-0 gate under an active run is a fail-closed BLOCK — identical to the Claude
shim. B2 (d): an absent `.harness/mode` => active.

ADVISORY (Option A): Stop-hook firing/honoring is UNPROVEN on Codex 0.132.0. The pre-commit/CI
release gate is retained as the fallback completion gate on Codex hosts — never claim parity.
"""

import os
import re
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dmc_codex_common as dc  # noqa: E402


def _current_run_id(project_dir):
    """The Stop gate arms on current-run-id presence alone (no scope.lock requirement), mirroring
    stop-verify-gate.sh."""
    rid_file = os.path.join(project_dir, ".harness", "runs", "current-run-id")
    if not os.path.isfile(rid_file):
        return ""
    try:
        with open(rid_file, "r", encoding="utf-8", errors="replace") as f:
            return re.sub(r"[^A-Za-z0-9._-]", "", f.readline().strip())
    except Exception:
        return ""


def _report_for(project_dir, rid):
    vdir = os.path.join(project_dir, ".harness", "verification")
    exact = os.path.join(vdir, rid + ".md")
    if os.path.isfile(exact):
        return exact
    try:
        for name in sorted(os.listdir(vdir)):
            if name.startswith(rid) and name.endswith(".md"):
                return os.path.join(vdir, name)
    except Exception:
        pass
    return None


def main():
    data, _raw = dc.read_event()
    project_dir = dc.resolve_project_dir(data)
    mode = dc.read_mode(project_dir)
    # Completion gate enforces in ACTIVE only; pass-through in passive/off.
    if mode != "active":
        sys.exit(0)

    # Loop guard: if a prior Stop hook already blocked, let this pass (avoid an infinite stop loop).
    if data is not None and dc.stop_hook_active(data):
        sys.exit(0)

    rid = _current_run_id(project_dir)
    if not rid:
        sys.exit(0)   # no active run => nothing to gate

    dmc = dc.find_dmc(project_dir)
    if not dmc or not shutil.which("python3"):
        dc.stop_block("Do-Me-Coding cannot verify completion for active run '%s': the Ring-0 stop "
                      "gate (bin/dmc + python3) is unavailable. Restore it, or suspend the run (dmc "
                      "run suspend), before claiming completion." % rid)

    report = _report_for(project_dir, rid)
    rc, out = dc.call_stop_gate(dmc, project_dir, report)
    if rc == 0:
        sys.exit(0)   # SUSPENDED / DONE / covered runs pass
    if not out:
        out = "stop-gate quick held completion for run '%s'" % rid
    dc.stop_block("Do-Me-Coding held completion for active run '%s': %s. Satisfy the required "
                  "verification/receipts (or run dmc run suspend) before claiming done." % (rid, out))


if __name__ == "__main__":
    main()
