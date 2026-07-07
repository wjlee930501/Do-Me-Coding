#!/usr/bin/env python3
"""dmc-doctor.py — DMC v1.0 M8 host self-check (`dmc doctor`; P19 post-install self-check).

A fast (<2s), OFFLINE, deterministic verb that reports, per detected host, whether the DMC control
plane is present and wired — and reports each host's enforcement HONESTLY. It never claims a
guarantee a host does not give.

What it reports (per the M8 plan / docs/CODEX_ADAPTER.md §3):
  1. Interpreters — python3 + bash (required), jq (optional). A missing required interpreter is a
     DEFECT.
  2. Ring-0 — `<root>/bin/dmc` + `<root>/bin/lib/<verdict-cli>` present. Absent Ring-0 is a DEFECT
     ("Ring-0 missing").
  3. Claude Code host — hook registration in `.claude/settings.json` PLUS a SYNTHETIC-EVENT FIRING
     PROBE: feed a canned PreToolUse Bash event (a `git apply` form the Ring-0 L0 floor ALWAYS
     denies, turn-free) to the Ring-0 verdict CLI and observe the deny/allow envelope. A correct
     deny envelope ⇒ firing PROVEN (empirical, not asserted). A core DMC hook present on disk but
     unregistered ⇒ a wiring-gap DEFECT.
  4. Codex host — `.codex/config.toml` / `.codex/hooks.json` presence + trust-state signals +
     turn-free-confirmed surfaces (skills discovery, AGENTS.md discovery). The Codex hook wiring is
     reported ADVISORY and names the pre-commit/CI gate as the safety backstop. It NEVER prints an
     enforced-class claim on any Codex line (M6.5 spike: hook execution + envelope honoring are
     UNPROVABLE turn-free at the codex CLI; the human gate chose the advisory-shim Option A).
  5. Foreign harness — a non-DMC agent harness (.omc/.opencode/.cursor/…) ⇒ a non-interference /
     passive recommendation (advisory, never a defect).
  6. The enforcement matrix from orchestration/harness-matrix.json, rendered PER-HOST — each
     physical output line is about exactly ONE host, and the DMC mode is reported HOST-INDEPENDENTLY
     (the mode word never shares a Codex line). These two rendering rules keep the /codex/i-scoped
     honesty control (test-doctor-negcontrols.sh) fail-closed-sound.

It may DISPLAY orchestration/models.json (dated model-binding lookup) but reads it for display only —
no gate/verdict/routing decision consults it.

House rules (v0.6.x / M2–M6 lineage): stdlib-only, offline (no network, no live/model/API call, no
credential read), deterministic (no wall-clock on the decision path), value-blind on secrets
(never opens a secret-shaped file), fail-closed with a non-zero exit on a real defect. The runtime
enforcement floor stays the hooks; this is a self-CHECK, not an enforcement surface.

Exit: 0 == healthy (advisories allowed), 1 == a real defect (missing interpreter / Ring-0 absent /
wiring gap / firing probe not proven), 2 == usage error.
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile

EXIT_OK = 0
EXIT_DEFECT = 1
EXIT_USAGE = 2

# Interpreters. python3 + bash are the Ring-0 floor; jq is a convenience only.
REQUIRED_INTERPRETERS = ("python3", "bash")
OPTIONAL_INTERPRETERS = ("jq",)

# Ring-0 handles resolved under <root>/bin.
RING0_ENTRY = os.path.join("bin", "dmc")
RING0_VERDICT_CLI = os.path.join("bin", "lib", "dmc-bash-radius.py")

# The synthetic PreToolUse events for the firing probe. The deny event is a `git apply` form the
# Ring-0 L0 static floor denies ALWAYS (no run, no scope lock, no live turn); the allow event is a
# benign read. The paths are never executed — the verdict CLI only CLASSIFIES the command string.
PROBE_DENY_EVENT = {"tool_name": "Bash",
                    "tool_input": {"command": "git apply /tmp/dmc-doctor-probe.patch"}}
PROBE_ALLOW_EVENT = {"tool_name": "Bash", "tool_input": {"command": "echo dmc-doctor-probe"}}
# dmc-bash-radius exit contract: 0 allow · 4 deny.
RING0_EXIT_ALLOW = 0
RING0_EXIT_DENY = 4

# Core Claude hooks that MUST be registered in settings.json when present on disk (settings.json
# §hooks). The worker-bridge hooks are wired differently (via skills), so they are not in this set.
CORE_CLAUDE_HOOKS = ("pre-tool-guard.sh", "scope-guard.sh", "secret-guard.sh",
                     "evidence-log.sh", "dmc-router.sh", "stop-verify-gate.sh")

# Foreign (non-DMC) agent-harness markers (mirrors the installer's detect_other_harness set).
FOREIGN_MARKERS = (".omc", ".omo", ".omx", ".opencode", "opencode.json", ".cursor", ".continue")

# The three host harnesses the enforcement matrix covers.
HARNESS_IDS = ("claude-code", "codex", "opencode")

# --- Codex-scoped honesty control (also enforced by tests/fixtures/m8/test-doctor-negcontrols.sh).
# NO output line matching /codex/i may contain any of these lexemes; the Codex section MUST contain
# every required substring. The doctor's own --self-test asserts both directions (nc4).
FORBIDDEN_CODEX_LEXEMES = ("enforced", "enforce", "fires", "firing", "runtime-enforced",
                           "active", "guaranteed")
CODEX_REQUIRED_SUBSTRINGS = ("ADVISORY", "pre-commit/CI")


# ------------------------------------------------------------------- paths

def module_dir():
    return os.path.dirname(os.path.abspath(__file__))


def default_root():
    """The repo that ships this doctor: two levels up from bin/lib/. `--root` overrides it."""
    return os.path.normpath(os.path.join(module_dir(), "..", ".."))


def _read_json(path):
    """Parse a JSON file; return None on any read/parse error (fail-soft for a display/probe path)."""
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError, UnicodeError):
        return None


# ------------------------------------------------------------------- probes

def probe_interpreters(which=shutil.which):
    """Resolve required + optional interpreters. `which` is injectable for the missing-python3
    negative control (nc1). A missing REQUIRED interpreter is a defect."""
    required = [{"name": n, "path": which(n), "present": bool(which(n))}
                for n in REQUIRED_INTERPRETERS]
    optional = [{"name": n, "path": which(n), "present": bool(which(n))}
                for n in OPTIONAL_INTERPRETERS]
    missing = [r["name"] for r in required if not r["present"]]
    return {"required": required, "optional": optional,
            "missing": missing, "defect": bool(missing)}


def probe_ring0(root):
    """Ring-0 presence: the entry point + the verdict CLI the firing probe drives. Absent ⇒ defect."""
    entry = os.path.join(root, RING0_ENTRY)
    cli = os.path.join(root, RING0_VERDICT_CLI)
    entry_present = os.path.isfile(entry)
    cli_present = os.path.isfile(cli)
    return {"entry": entry, "entry_present": entry_present,
            "verdict_cli": cli, "verdict_cli_present": cli_present,
            "defect": not (entry_present and cli_present)}


def _run_ring0(verdict_cli, event, runner):
    """Feed a synthetic event JSON to the Ring-0 verdict CLI on stdin; return (rc, decision)."""
    try:
        r = runner([sys.executable, "-B", verdict_cli],
                   input=json.dumps(event), capture_output=True, text=True, timeout=15)
    except (OSError, subprocess.SubprocessError):
        return None, None
    decision = None
    out = (r.stdout or "").strip()
    if out:
        try:
            decision = json.loads(out.splitlines()[-1]).get("decision")
        except ValueError:
            decision = None
    return r.returncode, decision


def firing_probe(verdict_cli, runner=subprocess.run):
    """Synthetic-event firing probe. Drives the Ring-0 verdict CLI with a known-DENY event and a
    benign ALLOW event; PROVEN iff both envelopes come back correct. Turn-free, offline."""
    if not verdict_cli or not os.path.isfile(verdict_cli):
        return {"probed": False, "proven": False,
                "detail": "Ring-0 verdict CLI absent — firing not probed"}
    deny_rc, deny_dec = _run_ring0(verdict_cli, PROBE_DENY_EVENT, runner)
    allow_rc, allow_dec = _run_ring0(verdict_cli, PROBE_ALLOW_EVENT, runner)
    proven = (deny_rc == RING0_EXIT_DENY and deny_dec == "deny"
              and allow_rc == RING0_EXIT_ALLOW and allow_dec == "allow")
    return {"probed": True, "proven": proven,
            "deny_rc": deny_rc, "allow_rc": allow_rc,
            "detail": ("git-apply PreToolUse => deny envelope; benign => allow envelope"
                       if proven else "envelope mismatch — Ring-0 verdict CLI did not respond as expected")}


def claude_registered_hooks(settings_obj):
    """Return the set of hook basenames referenced by any command string in settings.json §hooks."""
    found = set()
    if not isinstance(settings_obj, dict):
        return found
    hooks = settings_obj.get("hooks")
    if not isinstance(hooks, dict):
        return found
    for entries in hooks.values():
        if not isinstance(entries, list):
            continue
        for entry in entries:
            for h in (entry.get("hooks", []) if isinstance(entry, dict) else []):
                cmd = h.get("command") if isinstance(h, dict) else None
                if not isinstance(cmd, str):
                    continue
                for name in CORE_CLAUDE_HOOKS:
                    if name in cmd:
                        found.add(name)
    return found


def probe_claude_host(root):
    """Detect + assess a Claude Code host. A core hook present on disk but unregistered in
    settings.json (or settings.json missing while hooks are present) ⇒ a wiring-gap defect."""
    hooks_dir = os.path.join(root, ".claude", "hooks")
    settings_path = os.path.join(root, ".claude", "settings.json")
    settings_present = os.path.isfile(settings_path)
    on_disk = [h for h in CORE_CLAUDE_HOOKS if os.path.isfile(os.path.join(hooks_dir, h))]
    present = settings_present or bool(on_disk)
    if not present:
        return None
    registered = claude_registered_hooks(_read_json(settings_path)) if settings_present else set()
    unregistered = [h for h in on_disk if h not in registered]
    wiring_gap = bool(unregistered) or (bool(on_disk) and not settings_present)
    return {"present": True, "settings_present": settings_present, "settings_path": settings_path,
            "hooks_on_disk": on_disk, "registered": sorted(registered),
            "unregistered": unregistered, "wiring_gap": wiring_gap}


def probe_codex_host(root):
    """Detect + assess a Codex host. Turn-free signals only: config/hooks presence, skills discovery
    (.agents/skills), AGENTS.md discovery. NEVER asserts hook execution."""
    codex_dir = os.path.join(root, ".codex")
    config = os.path.join(codex_dir, "config.toml")
    hooks = os.path.join(codex_dir, "hooks.json")
    config_present = os.path.isfile(config)
    hooks_present = os.path.isfile(hooks)
    if not (config_present or hooks_present):
        return None
    skills_dir = os.path.join(root, ".agents", "skills")
    skills = []
    if os.path.isdir(skills_dir):
        skills = sorted(n for n in os.listdir(skills_dir)
                        if os.path.isdir(os.path.join(skills_dir, n)))
    return {"present": True, "config_present": config_present, "hooks_present": hooks_present,
            "skills": skills, "agents_md_present": os.path.isfile(os.path.join(root, "AGENTS.md"))}


def detect_foreign_harness(root):
    """A non-DMC agent harness present (mirrors dmc-install.sh detect_other_harness)."""
    markers = [m for m in FOREIGN_MARKERS if os.path.exists(os.path.join(root, m))]
    settings = os.path.join(root, ".claude", "settings.json")
    if os.path.isfile(settings):
        obj = _read_json(settings)
        if isinstance(obj, dict) and not claude_registered_hooks(obj):
            markers.append(".claude/settings.json (no DMC hooks)")
    return {"found": bool(markers), "markers": markers}


def read_mode(root):
    """The DMC mode, read host-independently from .harness/mode (absent ⇒ active by default)."""
    try:
        with open(os.path.join(root, ".harness", "mode"), "r", encoding="utf-8") as f:
            val = f.read().strip()
        return val if val in ("active", "passive", "off") else "active"
    except (OSError, UnicodeError):
        return "active"


def load_matrix(root):
    """The per-harness enforcement matrix data file (display/render source)."""
    return _read_json(os.path.join(root, "orchestration", "harness-matrix.json"))


def load_models(root):
    """The dated model-binding lookup — DISPLAY ONLY. No decision here reads its values."""
    return _read_json(os.path.join(root, "orchestration", "models.json"))


# ------------------------------------------------------------------- report

def build_report(root, which=shutil.which, runner=subprocess.run):
    """Assemble the full structured report + the defect list. Pure w.r.t. injected which/runner."""
    interpreters = probe_interpreters(which=which)
    ring0 = probe_ring0(root)
    claude = probe_claude_host(root)
    codex = probe_codex_host(root)
    foreign = detect_foreign_harness(root)
    firing = None
    if claude and not ring0["defect"]:
        firing = firing_probe(ring0["verdict_cli"], runner=runner)
    if claude is not None:
        claude["firing"] = firing

    defects = []
    if interpreters["defect"]:
        defects.append("missing required interpreter(s): " + ", ".join(interpreters["missing"]))
    if ring0["defect"]:
        defects.append("Ring-0 missing (bin/dmc or bin/lib/dmc-bash-radius.py absent)")
    if claude and claude["wiring_gap"]:
        defects.append("Claude hook wiring gap: core hook(s) present on disk but unregistered: "
                       + ", ".join(claude["unregistered"] or ["<no settings.json>"]))
    if firing and firing["probed"] and not firing["proven"]:
        defects.append("Claude synthetic-event firing probe did not return the expected envelope")

    return {"root": root, "mode": read_mode(root), "interpreters": interpreters, "ring0": ring0,
            "claude": claude, "codex": codex, "foreign": foreign,
            "matrix": load_matrix(root), "models": load_models(root),
            "defects": defects, "exit_code": EXIT_DEFECT if defects else EXIT_OK}


# ------------------------------------------------------------------- render

def _matrix_lines_for_host(matrix, host):
    """One physical line per invariant, EACH prefixed with `host` so the /codex/i honesty grep sees
    every codex line and no other host's line. Returns [] if the matrix is unavailable."""
    lines = []
    if not isinstance(matrix, dict):
        return lines
    for inv in matrix.get("invariants", []):
        if not isinstance(inv, dict):
            continue
        cell = inv.get(host, "(no data)")
        lines.append("  %s  %s: %s" % (host, inv.get("id", "?"), cell))
    return lines


def render(report):
    """Render the human report. Rendering invariants: (a) each physical line is about exactly ONE
    host; (b) the DMC mode is on its own host-independent line; (c) every Codex line contains the
    token `codex` and no forbidden lexeme, and the Codex section carries ADVISORY + pre-commit/CI."""
    L = []
    L.append("DMC doctor — host self-check")
    L.append("Root: %s" % report["root"])
    # (b) host-independent mode line — never on a host section.
    L.append("DMC mode: %s (host-independent; source: .harness/mode, absent => active)"
             % report["mode"])
    L.append("")

    # 1. Interpreters
    L.append("Interpreters:")
    for r in report["interpreters"]["required"]:
        L.append("  %s: %s" % (r["name"], r["path"] if r["present"] else "MISSING (required)"))
    for r in report["interpreters"]["optional"]:
        L.append("  %s: %s" % (r["name"], r["path"] if r["present"] else "absent (optional)"))
    L.append("")

    # 2. Ring-0
    rg = report["ring0"]
    L.append("Ring-0 control plane:")
    L.append("  bin/dmc: %s" % ("present" if rg["entry_present"] else "MISSING"))
    L.append("  verdict CLI (bin/lib/dmc-bash-radius.py): %s"
             % ("present" if rg["verdict_cli_present"] else "MISSING"))
    L.append("")

    # 3. Claude host
    c = report["claude"]
    if c:
        L.append("Host: claude-code")
        L.append("  claude-code settings.json: %s"
                 % ("present" if c["settings_present"] else "ABSENT"))
        L.append("  claude-code hooks registered: %s"
                 % (", ".join(c["registered"]) if c["registered"] else "(none)"))
        if c["wiring_gap"]:
            L.append("  claude-code WIRING GAP: unregistered core hook(s): %s"
                     % ", ".join(c["unregistered"] or ["<no settings.json>"]))
        f = c.get("firing")
        if f and f["probed"]:
            L.append("  claude-code synthetic-event probe: %s (%s)"
                     % ("PROVEN" if f["proven"] else "NOT PROVEN", f["detail"]))
        elif f:
            L.append("  claude-code synthetic-event probe: %s" % f["detail"])
        for ln in _matrix_lines_for_host(report["matrix"], "claude-code"):
            L.append(ln)
        L.append("")

    # 4. Codex host — ADVISORY only; every line names `codex`, none carries a forbidden lexeme.
    cx = report["codex"]
    if cx:
        L.append("Host: codex")
        # The one line that carries the two required substrings (ADVISORY + pre-commit/CI).
        L.append("  Codex hook wiring: ADVISORY — safety backstop is the pre-commit/CI gate "
                 "(hook execution UNPROVEN at the M6.5 spike; DMC surfaces the /hooks trust step "
                 "and never bypasses it).")
        L.append("  codex config (.codex/config.toml): %s"
                 % ("present" if cx["config_present"] else "absent"))
        L.append("  codex hooks (.codex/hooks.json): %s"
                 % ("present" if cx["hooks_present"] else "absent"))
        L.append("  codex trust: per-project config merged only for a TRUSTED project; hooks gated "
                 "by a one-time /hooks content-hash trust step (surface, never bypass).")
        L.append("  codex skills discovery (.agents/skills): %s (turn-free confirmed)"
                 % (", ".join(cx["skills"]) if cx["skills"] else "(none)"))
        L.append("  codex AGENTS.md discovery: %s (turn-free confirmed)"
                 % ("present" if cx["agents_md_present"] else "absent"))
        for ln in _matrix_lines_for_host(report["matrix"], "codex"):
            L.append(ln)
        L.append("")

    # 5. Foreign harness (advisory)
    fh = report["foreign"]
    if fh["found"]:
        L.append("Foreign harness detected: %s" % ", ".join(fh["markers"]))
        L.append("  recommendation: run DMC in PASSIVE mode (deny tier only) for non-interference; "
                 "prefer a separate branch/worktree (docs/OMC_COEXISTENCE.md).")
        L.append("")

    # 6. Model bindings (display only)
    m = report["models"]
    if isinstance(m, dict):
        classes = list((m.get("bindings") or {}).keys())
        L.append("Model bindings: orchestration/models.json present (as-of %s; display/lookup only, "
                 "read by no gate). Capability classes: %s"
                 % (m.get("as_of", "?"), ", ".join(classes) if classes else "(none)"))
        L.append("")

    # Verdict
    if report["defects"]:
        L.append("Result: DEFECT")
        for d in report["defects"]:
            L.append("  - %s" % d)
    else:
        L.append("Result: PASS (no defect; advisories above are informational)")
    return L


# ------------------------- Codex-scoped honesty control (shared with the negcontrol suite) ---------

def codex_lines(lines):
    """Every rendered line matching /codex/i — the honesty control's scope."""
    return [ln for ln in lines if "codex" in ln.lower()]


def codex_forbidden_hits(clines):
    """(line, lexeme) pairs where a Codex line carries a forbidden enforced-class lexeme."""
    hits = []
    for ln in clines:
        low = ln.lower()
        for lex in FORBIDDEN_CODEX_LEXEMES:
            if lex in low:
                hits.append((ln, lex))
    return hits


def codex_required_present(clines):
    """True iff the Codex section carries every required honest substring (ADVISORY + pre-commit/CI)."""
    low = "\n".join(clines).lower()
    return all(req.lower() in low for req in CODEX_REQUIRED_SUBSTRINGS)


def distinct_host_ids_on_line(line):
    """The set of distinct harness ids named on a single line (they are mutually non-overlapping
    substrings, so a plain substring count is unambiguous)."""
    return {h for h in HARNESS_IDS if h in line}


# ------------------------------------------------------------------- self-test

class ST:
    def __init__(self, name):
        self.name, self.passed, self.failed = name, 0, 0

    def ok(self, label, cond):
        if cond:
            self.passed += 1
            print("PASS [%s] %s" % (self.name, label))
        else:
            self.failed += 1
            print("FAIL [%s] %s" % (self.name, label))

    def check(self, label, thunk):
        try:
            cond = bool(thunk())
        except Exception as e:  # noqa: BLE001 — a broken fixture must FAIL, never abort the section
            self.ok("%s [EXC:%s]" % (label, e.__class__.__name__), False)
            return
        self.ok(label, cond)

    def done(self):
        print("[%s] %d PASS / %d FAIL" % (self.name, self.passed, self.failed))
        sys.exit(0 if self.failed == 0 else 1)


def _real_repo_porcelain():
    git = shutil.which("git")
    if not git:
        return None
    root = default_root()
    try:
        r = subprocess.run([git, "-C", root, "status", "--porcelain"],
                           capture_output=True, timeout=10)
        return r.stdout if r.returncode == 0 else None
    except (OSError, subprocess.SubprocessError):
        return None


def _mk_claude_fixture(td, register):
    """A minimal Claude host fixture: pre-tool-guard.sh on disk; settings.json registers it iff
    `register`. Used by the wiring-gap negative control (nc2)."""
    hooks = os.path.join(td, ".claude", "hooks")
    os.makedirs(hooks)
    with open(os.path.join(hooks, "pre-tool-guard.sh"), "w", encoding="utf-8") as f:
        f.write("#!/usr/bin/env bash\nexit 0\n")
    settings = {"hooks": {"PreToolUse": [{"matcher": "Bash", "hooks": [
        {"type": "command",
         "command": ("${CLAUDE_PROJECT_DIR}/.claude/hooks/pre-tool-guard.sh" if register
                     else "${CLAUDE_PROJECT_DIR}/.claude/hooks/some-other-hook.sh")}]}]}}
    with open(os.path.join(td, ".claude", "settings.json"), "w", encoding="utf-8") as f:
        json.dump(settings, f)


def selftest():
    t = ST("doctor")
    before = _real_repo_porcelain()

    # --- P0 positive control: the REAL shipping repo is a healthy dual host ----------------------
    root = default_root()
    report = build_report(root)
    lines = render(report)
    t.ok("P0 real repo: required interpreters present (no interpreter defect)",
         not report["interpreters"]["defect"])
    t.ok("P0 real repo: Ring-0 present", not report["ring0"]["defect"])
    t.ok("P0 real repo: Claude host detected + no wiring gap",
         report["claude"] is not None and not report["claude"]["wiring_gap"])
    t.ok("P0 real repo: Claude synthetic-event firing PROVEN",
         report["claude"] and report["claude"]["firing"]["proven"])
    t.ok("P0 real repo: Codex host detected", report["codex"] is not None)
    t.ok("P0 real repo: overall PASS (foreign harness is advisory, not a defect)",
         report["exit_code"] == EXIT_OK)

    # --- P1 render honesty (positive direction) --------------------------------------------------
    clines = codex_lines(lines)
    t.ok("P1 Codex lines are present in the render", len(clines) > 0)
    t.ok("P1 NO forbidden enforced-class lexeme on any Codex line",
         codex_forbidden_hits(clines) == [])
    t.ok("P1 Codex section carries the required ADVISORY + pre-commit/CI substrings",
         codex_required_present(clines))
    t.ok("P1 the mode word 'active' never appears on a Codex line (host-independent mode)",
         not any("active" in ln.lower() for ln in clines))
    t.ok("P1 every rendered line names at most ONE host (per-host rendering)",
         all(len(distinct_host_ids_on_line(ln)) <= 1 for ln in lines))
    t.ok("P1 the matrix renders all 8 invariants for both hosts",
         len(_matrix_lines_for_host(report["matrix"], "claude-code")) == 8
         and len(_matrix_lines_for_host(report["matrix"], "codex")) == 8)

    # --- nc1 negative control: simulated-missing python3 ⇒ interpreter defect ---------------------
    def fake_which(name):
        return None if name == "python3" else "/usr/bin/%s" % name
    interp = probe_interpreters(which=fake_which)
    t.ok("nc1 missing python3 => interpreter defect flagged",
         interp["defect"] and "python3" in interp["missing"])
    rep_nc1 = build_report(root, which=fake_which)
    t.ok("nc1 missing python3 => overall exit is DEFECT",
         rep_nc1["exit_code"] == EXIT_DEFECT)

    # --- nc4 negative control: a seeded 'Codex enforced' line trips the scoped grep ---------------
    poisoned = list(clines) + ["  codex hooks: enforced and firing at runtime (SEEDED DEFECT)"]
    t.ok("nc4 clean Codex lines pass the scoped forbidden-lexeme grep",
         codex_forbidden_hits(clines) == [])
    t.ok("nc4 seeded 'Codex enforced/firing' line => scoped grep FAILS (has teeth)",
         len(codex_forbidden_hits(poisoned)) >= 1)

    with tempfile.TemporaryDirectory(prefix="dmc-doctor-") as td:
        # --- nc2 wiring gap: core hook on disk but unregistered ----------------------------------
        gap = os.path.join(td, "gap")
        _mk_claude_fixture(gap, register=False)
        ch_gap = probe_claude_host(gap)
        t.ok("nc2 unregistered core hook => wiring gap flagged",
             ch_gap is not None and ch_gap["wiring_gap"]
             and "pre-tool-guard.sh" in ch_gap["unregistered"])
        okdir = os.path.join(td, "ok")
        _mk_claude_fixture(okdir, register=True)
        ch_ok = probe_claude_host(okdir)
        t.ok("nc2 registered core hook => NO wiring gap",
             ch_ok is not None and not ch_ok["wiring_gap"])

        # --- nc3 foreign harness detection -------------------------------------------------------
        foreign_dir = os.path.join(td, "foreign")
        os.makedirs(os.path.join(foreign_dir, ".omc"))
        fh = detect_foreign_harness(foreign_dir)
        t.ok("nc3 foreign harness (.omc) => detected with a non-interference recommendation",
             fh["found"] and ".omc" in fh["markers"])
        clean_dir = os.path.join(td, "clean")
        os.makedirs(clean_dir)
        t.ok("nc3 clean tree => no foreign harness",
             not detect_foreign_harness(clean_dir)["found"])

        # --- firing probe: absent verdict CLI => not proven --------------------------------------
        fp_absent = firing_probe(os.path.join(td, "nope", "dmc-bash-radius.py"))
        t.ok("firing probe: absent verdict CLI => probed=False, proven=False",
             not fp_absent["probed"] and not fp_absent["proven"])

        # --- Ring-0 missing => defect (the seeded-omission control's core assertion) -------------
        bare = os.path.join(td, "bare")
        os.makedirs(bare)
        t.ok("Ring-0 absent tree => probe_ring0 defect",
             probe_ring0(bare)["defect"])

    # --- mode: absent .harness/mode defaults to active, host-independently -----------------------
    t.ok("mode default is 'active' when .harness/mode is absent",
         read_mode(os.path.join(tempfile.gettempdir(), "dmc-doctor-no-such-root")) == "active")

    after = _real_repo_porcelain()
    t.ok("Z1 real repo git status --porcelain byte-identical before/after (or git absent)",
         before == after)
    t.done()


# ------------------------------------------------------------------------ main

def main():
    ap = argparse.ArgumentParser(prog="dmc-doctor", add_help=True,
                                 description="DMC host self-check (dmc doctor).")
    ap.add_argument("--root", metavar="DIR", help="host repo root to check (default: this repo)")
    ap.add_argument("--self-test", action="store_true", help="run the embedded module self-test")
    a = ap.parse_args()

    if a.self_test:
        selftest()
        return

    root = os.path.abspath(a.root) if a.root else default_root()
    if not os.path.isdir(root):
        sys.stderr.write("dmc-doctor: root not found: %s\n" % root)
        sys.exit(EXIT_USAGE)
    report = build_report(root)
    for ln in render(report):
        print(ln)
    sys.exit(report["exit_code"])


if __name__ == "__main__":
    main()
