#!/usr/bin/env python3
"""dmc-codex-pretooluse.py — Codex PreToolUse ADVISORY shim (Ring-1).

Translates a Codex PreToolUse event onto the SAME Ring-0 verdict CLIs the Claude PreToolUse shims
call, then emits the Codex PreToolUse decision envelope:
  - Bash        -> pre-tool-guard.sh parity: static mode floors + armed+active `dmc bash-radius`.
  - Edit|Write  -> scope-guard.sh parity: active-only scope-lock adjudication tree.
  - Read|Grep|Glob -> secret-guard.sh parity: path-only secret DENY (a floor in ALL modes).

ADVISORY (Option A): hook firing + envelope honoring are UNPROVEN on Codex 0.132.0; the real
enforcement boundary on a Codex host is the pre-commit/CI gate and the post-Bash diff guard is the
PRIMARY safety net. See dmc_codex_common.py and adapters/codex/README.md.

FAIL-CLOSED (B2): in ACTIVE mode with an ARMED run, degenerate input — (a) unparseable/empty event
JSON, (b) a missing/renamed expected field on a recognized guarded tool, (c) an absent/failed Ring-0
verdict CLI, (d) an absent `.harness/mode` (=> active) — yields a DENY. This HARDENS beyond the
Claude shims, which fail OPEN on (a)/(b). In passive/off, or unarmed, behavior is IDENTICAL to the
Claude side (stand down) so no non-run or stepped-aside session is ever bricked.
"""

import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dmc_codex_common as dc  # noqa: E402


def _fail_closed_active_armed(mode, armed):
    return mode == "active" and armed[0] is not None


def handle_bash(data, project_dir, mode, armed):
    command = dc.get_field(data, dc.CMD_KEYS)
    if not command:
        # B2 (b): a Bash event with no readable command field. Claude fails open (exit 0); we
        # harden to DENY only when active+armed, else stand down.
        if _fail_closed_active_armed(mode, armed):
            dc.pretool_deny("Do-Me-Coding fail-closed (Codex/advisory): a Bash PreToolUse event "
                            "carried no readable command field (renamed/absent) under an armed run; "
                            "cannot classify its write radius. Suspend the run (dmc run suspend) or "
                            "correct the wiring.")
        dc.pretool_allow()

    # Static mode floors (Block A all-modes, Block B not-off, Block C ask active) — parity port.
    verdict, reason = dc.classify_bash_floors(command, mode)
    if verdict == "deny":
        dc.pretool_deny(reason)
    if verdict == "ask":
        # v1.1.5 Block C bypass-awareness (mirror of pre-tool-guard.sh:146-159). Reached ONLY after
        # the deny floors above returned (Block C is the sole ask-scoped floor). When the host reports
        # blanket consent (permission_mode == bypassPermissions EXACTLY), a second DMC ask for the SAME
        # consent is redundant -> advisory stand-down. Any other/absent value falls through to the
        # frozen ask (inert-if-absent). Deny floors never reach here and never stand down.
        if dc.permission_mode(data) == "bypassPermissions":
            dc.pretool_standdown(project_dir, dc.ask_class(command))
        dc.pretool_ask(reason)

    # Block D — L1 dynamic write-radius (armed + active only; Ring-0 owns the verdict).
    if mode == "active" and armed[0] is not None:
        _, _, lock = armed
        dmc = dc.find_dmc(project_dir)
        if not dmc or not shutil.which("python3"):
            dc.pretool_deny("Do-Me-Coding fail-closed (Codex/advisory): run '%s' is armed but the "
                            "Ring-0 write-radius CLI (bin/dmc + python3) is unavailable, so this "
                            "Bash command cannot be adjudicated. Restore bin/dmc/python3 or suspend "
                            "the run (dmc run suspend)." % armed[0])
        rc, radius_reason = dc.call_bash_radius(dmc, command, lock)
        if rc == 0:
            dc.pretool_allow()
        if rc == 3:
            dc.pretool_ask("Do-Me-Coding write-radius asks confirmation: %s" % radius_reason)
        if rc == 4:
            dc.pretool_deny("Do-Me-Coding blocked an out-of-scope or disallowed Bash write: %s"
                            % radius_reason)
        dc.pretool_deny("Do-Me-Coding fail-closed (Codex/advisory): Bash write-radius classifier "
                        "returned status %s. %s" % (rc, radius_reason))
    dc.pretool_allow()


def _rel(project_dir, target):
    try:
        return os.path.relpath(target, project_dir)
    except Exception:
        return target


def handle_edit(data, project_dir, mode, armed):
    # scope-guard.sh enforces in ACTIVE only; pass-through in passive/off.
    if mode != "active":
        dc.pretool_allow()

    file_path = dc.get_field(data, dc.FILE_PATH_KEYS)
    rid, run_dir, lock = armed
    project_dir = os.path.realpath(project_dir)
    runs_base = os.path.realpath(os.path.join(project_dir, ".harness", "runs"))
    scope_file = os.path.join(runs_base, "current-scope.txt")
    legacy = os.path.isfile(scope_file)

    if not file_path:
        # B2 (b): a real Edit/Write with no readable path field. Claude fails open; harden to DENY
        # when armed, else stand down.
        if rid is not None:
            dc.pretool_deny("Do-Me-Coding fail-closed (Codex/advisory): an Edit/Write PreToolUse "
                            "event carried no readable file-path field (renamed/absent) under armed "
                            "run '%s'; cannot adjudicate its scope. Suspend the run or correct the "
                            "wiring." % rid)
        dc.pretool_allow()

    # No run context at all (no lock and no legacy scope file) => nothing to enforce.
    if lock is None and not legacy:
        dc.pretool_allow()

    target = os.path.realpath(file_path if os.path.isabs(file_path)
                              else os.path.join(project_dir, file_path))

    # Out-of-project deny (pinned; only reached in the enforcing state).
    if target != project_dir and not target.startswith(project_dir + os.sep):
        dc.pretool_deny("Do-Me-Coding blocked an Edit/Write to a path outside the project directory "
                        "(%s) while a run/scope is active. Out-of-repo writes are not adjudicable to "
                        "the approved scope; step aside with /dmc-off (or dmc run suspend) for "
                        "out-of-repo edits." % target)

    # Static run-state deny: run pointers + immutable state files mutate only via the dmc CLI.
    if target == runs_base or target.startswith(runs_base + os.sep):
        if target in (os.path.join(runs_base, "current-run-id"),
                      os.path.join(runs_base, "current-scope.txt")):
            dc.pretool_deny("Do-Me-Coding blocked an Edit/Write to run-pointer file %s — run "
                            "pointers mutate only via the dmc CLI, never a direct edit."
                            % _rel(project_dir, target))
        if os.path.basename(target) in dc.RUN_STATE_BASENAMES:
            dc.pretool_deny("Do-Me-Coding blocked an Edit/Write to protected run-state file %s — "
                            "scope.lock/approvals/run/blocked/snapshot mutate only via the dmc CLI "
                            "(an agent may not edit its own lock or snapshot)."
                            % _rel(project_dir, target))

    # Narrow internal exemption: evidence + verification + append-only logs under THIS run dir.
    def _within(base):
        b = os.path.realpath(base)
        return target == b or target.startswith(b + os.sep)

    if _within(os.path.join(project_dir, ".harness", "evidence")):
        dc.pretool_allow()
    if _within(os.path.join(project_dir, ".harness", "verification")):
        dc.pretool_allow()
    if run_dir and _within(run_dir):
        dc.pretool_allow()

    # Armed adjudication: Ring-0 scope-lock owns the verdict; this shim only translates it.
    if lock and os.path.isfile(lock):
        scope_lib = dc.find_scope_lock_lib(project_dir)
        if not scope_lib:
            dc.pretool_deny("Do-Me-Coding fail-closed (Codex/advisory): the run is armed but the "
                            "Ring-0 scope-lock adjudicator (bin/lib/dmc-scope-lock.py) is "
                            "unresolved; the edit cannot be adjudicated. Restore bin/lib or suspend "
                            "the run (dmc run suspend).")
        rc, detail = dc.call_scope_adjudicate(scope_lib, lock, _rel(project_dir, target), "edit")
        if rc == 0:
            dc.pretool_allow()
        dc.pretool_deny("Do-Me-Coding blocked file edit outside the approved scope lock: %s — %s"
                        % (_rel(project_dir, target), detail))

    # Legacy current-scope.txt membership.
    if legacy:
        allowed = []
        try:
            with open(scope_file, "r", encoding="utf-8", errors="replace") as f:
                for raw in f:
                    line = raw.strip()
                    if not line or line.startswith("#") or "=" in line:
                        continue
                    path = os.path.realpath(line if os.path.isabs(line)
                                            else os.path.join(project_dir, line))
                    allowed.append((line, path))
        except Exception:
            allowed = []
        for raw, path in allowed:
            if target == path or target.startswith(path + os.sep):
                dc.pretool_allow()
        dc.pretool_deny("Do-Me-Coding blocked file edit outside approved scope: %s. Update "
                        ".harness/runs/current-scope.txt through an approved plan if this file is "
                        "intended." % _rel(project_dir, target))

    dc.pretool_allow()


def handle_secret(data, tool, project_dir, mode, armed):
    # secret-guard.sh is a SECURITY FLOOR — enforced in ALL modes (active/passive/off).
    file_path = dc.get_field(data, dc.FILE_PATH_KEYS)
    grep_dir = dc.get_field(data, dc.GREP_DIR_KEYS)
    glob = dc.get_field(data, dc.GLOB_KEYS)
    pattern = dc.get_field(data, dc.GREP_PATTERN_KEYS)

    if dc.is_secret_path(file_path):
        dc.pretool_deny("Do-Me-Coding blocked %s of a secret-bearing path (%s). Reading secrets is "
                        "off-limits; inventory secret files by filename only." % (tool, file_path))
    if dc.is_secret_path(grep_dir):
        dc.pretool_deny("Do-Me-Coding blocked %s of a secret-bearing path (%s). Reading secrets is "
                        "off-limits; inventory secret files by filename only." % (tool, grep_dir))
    if dc.is_secret_glob(glob):
        dc.pretool_deny("Do-Me-Coding blocked a %s pattern targeting secret-bearing files (%s). "
                        "Narrow to non-secret paths; do not enumerate secret file contents."
                        % (tool, glob))
    if tool == "Glob" and dc.is_secret_glob(pattern):
        dc.pretool_deny("Do-Me-Coding blocked a %s pattern targeting secret-bearing files (%s). "
                        "Narrow to non-secret paths; do not enumerate secret file contents."
                        % (tool, pattern))

    # B2 (b): a read event whose target field(s) are all renamed/absent. Claude fails open (nothing
    # to path-check); we harden to DENY only when active+armed, else stand down.
    if not (file_path or grep_dir or glob or pattern) and _fail_closed_active_armed(mode, armed):
        dc.pretool_deny("Do-Me-Coding fail-closed (Codex/advisory): a %s PreToolUse event carried "
                        "no readable path/pattern field (renamed/absent) under an armed run; the "
                        "secret-path guard cannot decide. Suspend the run or correct the wiring."
                        % tool)
    dc.pretool_allow()


def main():
    data, _raw = dc.read_event()
    project_dir = dc.resolve_project_dir(data)
    mode = dc.read_mode(project_dir)
    armed = dc.arming(project_dir)

    # B2 (a): unparseable/empty event JSON. Fail-closed in active+armed; stand down otherwise.
    if data is None:
        if _fail_closed_active_armed(mode, armed):
            dc.pretool_deny("Do-Me-Coding fail-closed (Codex/advisory): the PreToolUse event JSON "
                            "was empty or unparseable under an armed run; the operation cannot be "
                            "adjudicated. Suspend the run (dmc run suspend) or correct the wiring.")
        dc.pretool_allow()

    tool = dc.tool_name(data)
    if tool == "Bash":
        handle_bash(data, project_dir, mode, armed)
    elif tool in ("Edit", "Write"):
        handle_edit(data, project_dir, mode, armed)
    elif tool in ("Read", "Grep", "Glob"):
        handle_secret(data, tool, project_dir, mode, armed)
    elif not tool:
        # B2 (b) at the tool-identity level: a guarded surface fired but tool_name is renamed/absent.
        if _fail_closed_active_armed(mode, armed):
            dc.pretool_deny("Do-Me-Coding fail-closed (Codex/advisory): a PreToolUse event carried "
                            "no readable tool name under an armed run; the operation cannot be "
                            "routed to a guard. Suspend the run or correct the wiring.")
        dc.pretool_allow()
    else:
        # A tool DMC does not guard (web fetch, etc.). DMC has no verdict for it — stand down, as the
        # matcher-scoped Claude shims do for a non-matching tool. Never block a non-guarded tool.
        dc.pretool_allow()


if __name__ == "__main__":
    main()
