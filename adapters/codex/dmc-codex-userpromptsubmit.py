#!/usr/bin/env python3
"""dmc-codex-userpromptsubmit.py — Codex UserPromptSubmit ADVISORY shim (Ring-1).

Parity with `.claude/hooks/dmc-router.sh`: the natural-activation router. Suffix-only, exact
matching, precedence dmc-off > dmc-plan > dmc. Mode-independent (this IS the activation surface);
writes `.harness/mode` ONLY on an exact trigger and emits an `additionalContext` routing hint.

This event is NOT a gate — it has no deny/block envelope. Its fail-safe posture on degenerate input
(unparseable/empty JSON, a missing/renamed prompt field, an absent `.harness/mode`) is therefore
"do nothing": no spurious mode write, no spurious routing — byte-consistent with the Claude router,
which also no-ops. There is no Ring-0 verdict CLI on this path, so B2 case (c) does not apply here.

ADVISORY (Option A): whether Codex honors `additionalContext` is unproven; the routing hint is
advisory and the `.harness/mode` write is the only reliable side effect (it runs in this process).
"""

import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dmc_codex_common as dc  # noqa: E402


def _run_warn(project_dir):
    runs = os.path.join(project_dir, ".harness", "runs")
    try:
        for name in os.listdir(runs):
            if name.startswith("current-"):
                return (" WARNING: a Do-Me-Coding run is in progress (.harness/runs/current-* "
                        "exists). Finish or cancel it — and prefer a separate branch / git worktree "
                        "— before OMC work.")
    except Exception:
        pass
    return ""


def _write_mode(project_dir, value):
    try:
        harness = os.path.join(project_dir, ".harness")
        os.makedirs(harness, exist_ok=True)
        with open(os.path.join(harness, "mode"), "w", encoding="utf-8") as f:
            f.write(value + "\n")
    except Exception:
        pass


def main():
    data, _raw = dc.read_event()
    # Degenerate input (B2 a/b): no prompt to route on -> no-op (fail-safe: grants nothing).
    if data is None:
        sys.exit(0)
    prompt = dc.get_field(data, dc.PROMPT_KEYS)
    if not prompt:
        sys.exit(0)

    project_dir = dc.resolve_project_dir(data)
    trimmed = re.sub(r"\s+$", "", prompt)
    warn = _run_warn(project_dir)

    # 1) dmc-off (exact suffix) — set mode off.
    if re.search(r"(^|\s)dmc-off\s*$", trimmed):
        _write_mode(project_dir, "off")
        dc.ups_context("Do-Me-Coding mode set to OFF (catastrophic + secret-exposure deny only; "
                       "scope/stop/evidence gates stand down). Use /dmc-on to re-enable." + warn)

    # 2) dmc-plan (exact suffix) — planning is read-only, mode unchanged.
    if re.search(r"(^|\s)dmc-plan\s*$", trimmed):
        task = re.sub(r"\s*dmc-plan$", "", trimmed)
        dc.ups_context("Do-Me-Coding planning route requested. Run /dmc-plan-hard for this task "
                       "(planning only, no edits): " + task)

    # 3) dmc (exact suffix) — ultrawork; set mode active for full enforcement.
    if re.search(r"(^|\s)dmc\s*$", trimmed):
        _write_mode(project_dir, "active")
        task = re.sub(r"\s*dmc$", "", trimmed)
        dc.ups_context("Do-Me-Coding ultrawork route requested (mode set ACTIVE — full "
                       "enforcement). Run /dmc-ultrawork for: " + task)

    sys.exit(0)


if __name__ == "__main__":
    main()
