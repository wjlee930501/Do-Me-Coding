#!/usr/bin/env python3
# dmc-codex-dispatch-probe.py — REPO-INTERNAL diagnostic (NOT a shim, NOT shipped).
#
# For the one-time, human-run Option-B live-turn observation: RECORDS that a
# wired lifecycle event was OBSERVED to dispatch to the DMC shims, as metadata.
# It writes NO envelope (nothing to stdout/stderr), so it can never influence any
# tool decision — a purely passive marker writer. It is deliberately ABSENT from
# the installer's CODEX_ADAPTERS list, so no host install ever carries it.
#
# Privacy contract: logs metadata NAMES only — an event label, a tool label, the
# sorted top-level key names, and the sorted tool_input key names — and NEVER any
# payload VALUE (no command text, no file paths, no prompt text). One JSONL line
# is appended per call; on any error it stays silent and exits 0.

import json
import sys
import os
import datetime


def _ci_get(mapping, *names):
    """Case-insensitive lookup over a dict's string keys; first hit wins."""
    lowered = {}
    for key, value in mapping.items():
        if isinstance(key, str):
            lowered.setdefault(key.lower(), value)
    for name in names:
        if name.lower() in lowered:
            return lowered[name.lower()]
    return None


def main():
    try:
        raw = sys.stdin.read()
    except Exception:
        raw = ""
    data = None
    try:
        parsed = json.loads(raw) if raw.strip() else None
        if isinstance(parsed, dict):
            data = parsed
    except Exception:
        data = None
    argv_label = sys.argv[1] if len(sys.argv) > 1 else None
    event = None
    tool = None
    top_keys = []
    tool_input_keys = None
    if data is not None:
        event = _ci_get(data, "hook_event_name", "hookEventName", "event")
        tool = _ci_get(data, "tool_name", "toolName", "tool", "name")
        top_keys = sorted(k for k in data.keys() if isinstance(k, str))
        tool_input = _ci_get(data, "tool_input", "toolInput")
        if isinstance(tool_input, dict):
            tool_input_keys = sorted(k for k in tool_input.keys() if isinstance(k, str))
    if not event:
        event = argv_label if argv_label else "unknown"
    record = {
        "ts": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "argv_label": argv_label,
        "event": event,
        "tool": tool,
        "top_keys": top_keys,
        "tool_input_keys": tool_input_keys,
    }
    here = os.path.dirname(os.path.abspath(__file__))          # <repo>/adapters/codex
    repo_root = os.path.abspath(os.path.join(here, os.pardir, os.pardir))
    marker_dir = os.path.join(repo_root, ".harness", "runs", "dmc-run-codexprobe")
    os.makedirs(marker_dir, exist_ok=True)
    with open(os.path.join(marker_dir, "markers.jsonl"), "a", encoding="utf-8") as fh:
        fh.write(json.dumps(record, ensure_ascii=False) + "\n")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
    sys.exit(0)
