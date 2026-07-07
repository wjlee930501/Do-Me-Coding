#!/usr/bin/env python3
"""dmc-codex-posttooluse.py — Codex PostToolUse ADVISORY shim (Ring-1).

Parity with `.claude/hooks/evidence-log.sh`: in ACTIVE mode, append a REDACTED evidence entry, and
for a Bash tool on an armed run run the Ring-0 `dmc postbash-diff` guard — the M6 out-of-scope
change detector that is the PRIMARY Codex safety net (PreToolUse is non-airtight because
`unified_exec` is stable+on). A PostToolUse cannot undo an applied effect; an out-of-scope change
records a sticky BLOCKED marker (`dmc run block`) and emits a `decision:"block"` continuation, and
the actual hold lands at the Stop gate + the pre-commit/CI release gate.

ADVISORY (Option A): whether Codex PostToolUse fires for `unified_exec` writes is UNPROVABLE
turn-free (spike §D) — the guard runs at Stop + the pre-commit gate as the recorded scoped
degradation. No enforcement-parity claim on Codex.

B3 secret redaction: the command is passed through the IDENTICAL `redact()` transform as
evidence-log.sh BEFORE it reaches the evidence file — no raw `sk-…` key or `token=/password=` form
is ever written. A5: path-embedded secrets are handled by the PreToolUse path-only deny, not here.
"""

import datetime
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dmc_codex_common as dc  # noqa: E402


def _timestamp():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def append_evidence(project_dir, rid, tool, command, file_path):
    """Best-effort append to `.harness/evidence/<run-id>.md`; NEVER blocks the tool flow, NEVER
    raises. Command is redacted + truncated exactly as evidence-log.sh does."""
    try:
        ev_dir = os.path.join(project_dir, ".harness", "evidence")
        os.makedirs(ev_dir, exist_ok=True)
        run_id = rid or ("manual-" + datetime.datetime.now().strftime("%Y%m%d-%H%M%S"))
        path = os.path.join(ev_dir, run_id + ".md")
        ts = _timestamp()
        if not os.path.isfile(path):
            with open(path, "w", encoding="utf-8") as f:
                f.write("# Evidence Log\n\nRun ID: %s\nStarted: %s\n\n## Tool Events\n\n"
                        % (run_id, ts))
        with open(path, "a", encoding="utf-8") as f:
            if tool == "Bash":
                red = dc.redact(command)[:500]
                f.write("### %s Bash\n\n```bash\n%s\n```\n\n" % (ts, red))
            elif tool in ("Edit", "Write"):
                f.write("### %s %s\n\nFile: %s\n\n" % (ts, tool, file_path[:500]))
    except Exception:
        pass


def main():
    data, _raw = dc.read_event()
    project_dir = dc.resolve_project_dir(data)
    mode = dc.read_mode(project_dir)
    rid, run_dir, lock = dc.arming(project_dir)
    armed_active = mode == "active" and rid is not None

    # B2 (a): unparseable/empty event JSON. Fail-closed BLOCK in active+armed; pass otherwise.
    if data is None:
        if armed_active:
            dc.stop_block("Do-Me-Coding fail-closed (Codex/advisory): a PostToolUse event JSON was "
                          "empty or unparseable under an armed run; an out-of-scope change cannot be "
                          "ruled out. Completion is held — verify the tree (git status) and suspend "
                          "or resolve the run.")
        sys.exit(0)

    # evidence-log.sh runs in ACTIVE only; pass-through in passive/off.
    if mode != "active":
        sys.exit(0)

    tool = dc.tool_name(data)
    command = dc.get_field(data, dc.CMD_KEYS)
    file_path = dc.get_field(data, dc.FILE_PATH_KEYS)

    # B2 (b): tool identity renamed/absent under an armed run — cannot tell whether a Bash write
    # happened, so the diff guard cannot run. Claude fails open; harden to BLOCK when armed.
    if not tool:
        if rid is not None:
            dc.stop_block("Do-Me-Coding fail-closed (Codex/advisory): a PostToolUse event carried "
                          "no readable tool name under armed run '%s'; an out-of-scope change cannot "
                          "be ruled out. Completion is held — verify the tree and resolve the run."
                          % rid)
        sys.exit(0)

    append_evidence(project_dir, rid, tool, command, file_path)

    # Post-Bash out-of-scope diff guard (Bash + armed-for-diff only). armed-for-diff mirrors
    # evidence-log.sh: run-id + this run's scope.lock.json + arming snapshot.txt all present.
    if tool == "Bash" and rid is not None:
        snapshot = os.path.join(run_dir, "snapshot.txt")
        if not (lock and os.path.isfile(lock) and os.path.isfile(snapshot)):
            sys.exit(0)   # not armed for the diff guard (parity: evidence-log skips)
        dmc = dc.find_dmc(project_dir)
        if not dmc or not shutil.which("python3"):
            # B2 (c): Ring-0 diff guard unreachable under an armed run — fail-closed BLOCK (Claude's
            # evidence-log skips here; this HARDENS beyond it).
            dc.stop_block("Do-Me-Coding fail-closed (Codex/advisory): run '%s' is armed but the "
                          "Ring-0 post-Bash diff guard (bin/dmc + python3) is unavailable, so an "
                          "out-of-scope Bash write cannot be ruled out. Completion is held — restore "
                          "bin/dmc/python3 or suspend the run." % rid)
        rc, reason, blocked_paths = dc.call_postbash_diff(dmc, lock, snapshot, project_dir)
        if rc == 0:
            sys.exit(0)
        if rc == 4:
            dc.run_block_marker(dmc, project_dir, reason, blocked_paths)
            paths_note = (" — paths: " + " ".join(blocked_paths)) if blocked_paths else ""
            dc.stop_block("Do-Me-Coding post-Bash guard: an out-of-scope change was recorded and run "
                          "'%s' is now BLOCKED (%s%s). Revert the stray change; completion is held "
                          "until you resolve it with dmc run unblock." % (rid, reason, paths_note))
        # Unexpected exit under an armed run — fail-closed BLOCK (B2 c).
        dc.stop_block("Do-Me-Coding fail-closed (Codex/advisory): the post-Bash diff guard returned "
                      "status %s for armed run '%s'; an out-of-scope change cannot be ruled out. "
                      "Completion is held — verify the tree and resolve the run." % (rc, rid))

    sys.exit(0)


if __name__ == "__main__":
    main()
