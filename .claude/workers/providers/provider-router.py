#!/usr/bin/env python3
"""Do-Me-Coding Provider Routing Layer (v0.2.3).

A thin, deterministic router that selects a provider adapter from the task bundle and dispatches to it UNCHANGED.
It adds NO new network/exec capability and NO new trust surface beyond "exec one of a few known adapter scripts".

DESIGN (approved plan .harness/plans/dmc-v0.2.3-provider-routing.md):
- Selection is a pure function of task `provider_target.{type,provider}` ONLY — never env vars / secrets / heuristics.
- Static REGISTRY table keyed by (type, provider). Exact match; empty provider matches only if the type has exactly
  one adapter; unknown / missing / mock / manual_import -> refuse (deterministic, no guess).
- Dispatch contract: the adapter path is resolved to an ABSOLUTE path UNDER the approved providers dir and refused if
  missing or escaping that dir. Dispatch uses subprocess.run([...], shell=False) — argv list, no shell, no interpolation.
- Argv hygiene (O4): only operator-provided paths (--task/--mock/--out) + fixed registry-derived flags reach the child
  argv; NO task-derived string is ever placed on the command line.
- Env passthrough (R1): the parent environment is passed to the adapter UNCHANGED (the adapter owns all credential/env
  handling). The router reads env for NOTHING and logs no env values.
- Streams (O2): adapter stdout/stderr are inherited (forwarded transparently); the router persists no raw streams and
  writes no result file (only the adapter writes --out).
- Timeouts (O3): adapter-owned; the router adds none.
- Live opt-in: forwards ONLY the selected adapter's registry live_flag; a mismatched/cross opt-in flag is refused before
  dispatch (the target adapter's argparse also independently rejects an unrecognized flag — defense in depth).

Usage:
  provider-router.py --task <task.json> --mock <fixture> [--out <result.json>]
  provider-router.py --task <task.json> --live --allow-network [--out ...]   # routes to api_key/glm-api
  provider-router.py --task <task.json> --live --allow-exec    [--out ...]   # routes to oauth_cli/oauth-cli
  provider-router.py --task <task.json> --mock <fixture> --print-dispatch     # dry-run: print argv, do not exec
"""
import argparse, json, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
PROVIDERS_DIR = os.path.realpath(HERE)   # .claude/workers/providers

# Static routing table. Selection is from the task ONLY. Each entry: adapter path (relative to PROVIDERS_DIR) +
# the adapter's own live opt-in flag (the ONLY live flag the router will ever forward for that provider).
REGISTRY = {
    ("api_key",   "glm-api"):   {"adapter": "glm-api/glm-api-adapter.py",     "live_flag": "--allow-network"},
    ("oauth_cli", "oauth-cli"): {"adapter": "oauth-cli/oauth-cli-adapter.py", "live_flag": "--allow-exec"},
}
LIVE_FLAGS = {"--allow-network", "--allow-exec"}   # all known opt-in flags across providers


def die(msg, code=1):
    print(f"provider-router: {msg}", file=sys.stderr)
    sys.exit(code)


def select_entry(task):
    """Deterministic selection from provider_target ONLY (never env/secrets)."""
    pt = task.get("provider_target")
    if not isinstance(pt, dict):
        die("task has no provider_target object — cannot route (refusing)")
    ptype = pt.get("type") or ""
    provider = pt.get("provider") or ""
    if ptype in ("", "mock", "manual_import"):
        die(f"provider_target.type={ptype!r} has no live adapter to route to (refusing)")
    if provider:
        entry = REGISTRY.get((ptype, provider))
        if not entry:
            die(f"no adapter registered for (type={ptype!r}, provider={provider!r}) (refusing)")
        return ptype, provider, entry
    # empty provider: route ONLY if the type has exactly one registered adapter; else ambiguous -> refuse.
    matches = [(k, v) for k, v in REGISTRY.items() if k[0] == ptype]
    if len(matches) != 1:
        die(f"provider_target.provider is empty and type={ptype!r} is ambiguous "
            f"({len(matches)} adapters) — refusing (no guess)")
    (k, entry) = matches[0]
    return ptype, k[1], entry


def resolve_adapter(entry):
    """Dispatch contract: absolute path UNDER PROVIDERS_DIR, existing regular file; refuse otherwise."""
    adapter = os.path.realpath(os.path.join(PROVIDERS_DIR, entry["adapter"]))
    if not (adapter == PROVIDERS_DIR or adapter.startswith(PROVIDERS_DIR + os.sep)):
        die("resolved adapter path escapes the approved providers directory — refusing")
    if not os.path.isfile(adapter):
        die(f"registered adapter file is missing: {entry['adapter']} — refusing")
    return adapter


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--task", required=True)
    ap.add_argument("--mock")
    ap.add_argument("--live", action="store_true")
    ap.add_argument("--allow-network", action="store_true")
    ap.add_argument("--allow-exec", action="store_true")
    ap.add_argument("--out")
    ap.add_argument("--print-dispatch", action="store_true",
                    help="dry-run: print the resolved adapter + child argv and exit; never executes the adapter")
    a = ap.parse_args()

    task = json.load(open(a.task))               # read ONLY for provider_target selection (no env consulted)
    ptype, provider, entry = select_entry(task)
    adapter = resolve_adapter(entry)

    # Build child argv: ONLY operator-provided paths + fixed registry-derived flags. No task-derived strings.
    argv = [sys.executable, adapter, "--task", a.task]
    if a.mock:
        argv += ["--mock", a.mock]
    if a.out:
        argv += ["--out", a.out]
    if a.live:
        required = entry["live_flag"]
        passed = {f for f in LIVE_FLAGS if getattr(a, f.lstrip("-").replace("-", "_"))}
        wrong = passed - {required}
        if wrong:
            die(f"--live for (type={ptype}, provider={provider}) accepts only {required}; "
                f"refusing mismatched opt-in flag(s) {sorted(wrong)}")
        if required not in passed:
            die(f"--live for (type={ptype}, provider={provider}) requires explicit {required}; refusing")
        argv += ["--live", required]

    if a.print_dispatch:
        # argv carries only paths + flags (no secrets, no task content). Safe to print for verification.
        print(json.dumps({"type": ptype, "provider": provider, "adapter": adapter, "argv": argv}, indent=2))
        return

    # Dispatch: shell=False, env passed through UNCHANGED, stdout/stderr inherited (transparent), no capture/persist.
    r = subprocess.run(argv, shell=False)
    sys.exit(r.returncode)


if __name__ == "__main__":
    main()
