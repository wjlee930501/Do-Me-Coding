#!/usr/bin/env python3
"""dmc-agents-md.py — DMC v1 M6.5 (DMC-T011b.4) host AGENTS.md generator + validator.

Emits a host repo's `AGENTS.md` carrying ALL TEN required sections of the Codex adapter's
content contract (`docs/CODEX_ADAPTER.md` §5), from facts derived deterministically from the
repository. Also validates an AGENTS.md against that contract (`--validate FILE`).

NAMING NOTE (A4): this verb IS the generator that `docs/HOST_REPO_ADAPTATION_POLICY.md` calls
`/dmc-init-deep` — one generator behind a skill -> verb layering, not two. There is no separate
`/dmc-init-deep` implementation; the skill invokes this verb.

The Unknown rule (non-negotiable)
---------------------------------
Every fact NOT derivable from the repository is emitted literally as `Unknown` — never a plausible
guess, never invented business logic, commands, or risk notes. Host-derived facts (stack, package
manager, detected commands, landmarks) come from `dmc orient` / `dmc landmarks`; DMC-constant
doctrine (the core loop, the non-negotiable rules, Codex host-invocation, stop conditions) is
emitted as-is because it originates in DMC itself, not in the host repo. Every field that lands as
`Unknown` is also aggregated into section 10 (Explicit Unknowns) for follow-up.

Merge policy (never overwrite; never blind-copy)
------------------------------------------------
Per `docs/HOST_REPO_ADAPTATION_POLICY.md`: DMC's own `AGENTS.md` describes the DMC scaffold repo,
so copying it into a host injects false project memory. This generator NEVER copies an existing
file and NEVER overwrites one: if the output path already exists it refuses with a message (exit 3)
and the caller must choose a different `--out` or remove the file deliberately. `--stdout` prints
without touching the filesystem.

Size budget
-----------
Codex reads `AGENTS.md` up to `project_doc_max_bytes` (default 32768 bytes, spike-confirmed at
codex-cli 0.132.0) and truncates beyond it. This generator NEVER truncates: it emits the full
contract and, when the output exceeds 32768 bytes, prints a stderr warning (exit stays 0) naming
the sections to externalize (the architecture-landmark list and the DMC operating rules are the
usual large sections), so a host can trim/link them by hand rather than have Codex silently drop
the tail.

Inputs are derived by SUBPROCESS to `bin/dmc` (`orient`, `landmarks`) — this module never imports
the repo-intel modules. House rules: python3 stdlib-only, deterministic given a fixed tree
(no timestamps / commit hashes are embedded in the document), env-independent (no env var reads),
offline (no network / model / API call), no `shell=True`. Writes only the requested output path
(or stdout) plus, in `--self-test`, its own disposable `tempfile.mkdtemp()` directories.

Exit contract: generate -> 0 ok (warning on stderr if oversized, still 0) / 3 refused-to-overwrite
/ 2 usage; `--validate` -> 0 VALID / 3 REFUSED / 2 usage; `--self-test` -> 0 all passed / 1 a
failure. No other exit codes are used.
"""

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

DOC_MAX_BYTES = 32768  # Codex project_doc_max_bytes default (spike-confirmed, CODEX_ADAPTER §1).

# Ordered required sections (docs/CODEX_ADAPTER.md §5). Heading form: `## N. Title`.
SECTIONS = [
    (1, "Repo identity"),
    (2, "Stack and package manager"),
    (3, "Lint / typecheck / test / build commands"),
    (4, "Architecture landmarks"),
    (5, "Protected surfaces"),
    (6, "Migration / env / auth / billing risk notes"),
    (7, "DMC operating rules"),
    (8, "Verification commands"),
    (9, "Stop conditions"),
    (10, "Explicit Unknowns"),
]

UNKNOWN = "Unknown"

# Universal DMC-protected secret file patterns (CLAUDE.md §Secret Protection). A repo constant,
# never a guess: these are off-limits on every host regardless of what the repo contains.
SECRET_PATTERNS = [
    "`.env*` (except `.env.example` / `.env.sample` / `.env.template`)",
    "`*.pem`, `*.key`, `id_rsa`, `id_ed25519`, `*.p12`, `*.pfx`, `*.keystore`",
    "`.npmrc`, `.netrc`, `.pgpass`, `credentials.json`, `*service-account*.json`, `*secret*` config",
    "`**/.ssh/*`, `**/.aws/credentials`",
]

# DMC enforcement bindings — editable only through an approved plan scope (CLAUDE.md, DMC.md).
DMC_BINDINGS = ["`.claude/`", "`.agents/`", "`.codex/`", "`bin/dmc`", "`bin/lib/`", "`.harness/`"]

# Companion context docs — the section-7 discoverability pointer is emitted ONLY when ALL THREE of
# these exist as files at the scanned root (atomic all-or-nothing). None of the three ships with an
# install, so on every host the pointer is omitted (no dangling references — the generator's
# facts-driven charter); the DMC repo, the only tree carrying them, gets the native paragraph.
COMPANION_DOCS = ["AUTONOMY.md", "docs/CONTEXT_MAP.md", "docs/DMC_CONSTITUTION.md"]

# Validator refusal heuristics: guessed-looking filler that must have been `Unknown` instead.
# `Unknown` (literal) is ALLOWED and is the sanctioned non-derivable marker. Documented in
# .harness/schemas/agents-md.schema.md and enforced by validate_doc().
FILLER_TOKEN_RE = re.compile(r"\b(?:TODO|TBD|FIXME|WIP|XXX)\b", re.IGNORECASE)
LOREM_RE = re.compile(r"\blorem\b", re.IGNORECASE)
QMARK_RE = re.compile(r"\?\?\?")
# An unfilled angle-bracket template placeholder, e.g. `<name>`, `<fill this in>`. A generated,
# fully-resolved document carries none; `Unknown` has no angle brackets so it is unaffected.
ANGLE_PLACEHOLDER_RE = re.compile(r"<[A-Za-z][^>\n]{0,60}>")

HEADING_RE = re.compile(r"^##\s+(\d+)\.\s+(.+?)\s*$")


# --------------------------------------------------------------------------- repo-fact inputs

def module_dir():
    return os.path.dirname(os.path.abspath(__file__))


def dmc_path():
    """Absolute path to bin/dmc (this module lives at bin/lib/dmc-agents-md.py)."""
    return os.path.normpath(os.path.join(module_dir(), "..", "dmc"))


def run_dmc_json(verb, root):
    """Subprocess `bin/dmc <verb> --root <root>` and parse its JSON stdout; None on any failure
    (missing tool, nonzero exit, unparseable output). The caller degrades the affected facts to
    `Unknown` rather than guessing."""
    dmc = dmc_path()
    argv = [dmc, verb, "--root", root]
    if not os.access(dmc, os.X_OK):
        argv = ["bash"] + argv
    try:
        proc = subprocess.run(argv, capture_output=True, text=True, timeout=120)
    except (OSError, subprocess.SubprocessError):
        return None
    if proc.returncode != 0:
        return None
    try:
        return json.loads(proc.stdout)
    except ValueError:
        return None


# --------------------------------------------------------------------------- fact derivation

def categorize_command(command, source):
    """Map a detected verify command to lint|typecheck|test|build using its `source` metadata
    (the script/target name orient recorded) — a classification of a REAL detected command, never
    an invented one. Returns a category key or None (uncategorized)."""
    s = (source or "").lower()
    if "lint" in s:
        return "lint"
    if "typecheck" in s:
        return "typecheck"
    if "test" in s or "pytest" in s or source in ("Cargo.toml", "go.mod"):
        return "test"
    if "build" in s:
        return "build"
    return None


def companion_docs_present(root):
    """True iff EVERY companion context doc (COMPANION_DOCS) exists as a file at `root` — atomic
    all-or-nothing. A repo-derived fact (never a guess): gates the section-7 pointer paragraph so a
    host lacking these docs emits no dangling references."""
    return all(os.path.isfile(os.path.join(root, rel)) for rel in COMPANION_DOCS)


def derive_facts(root):
    """Return (facts, unknowns). `facts` is a plain dict of derived values; `unknowns` is an
    ordered list of (section-label, field-label) pairs recording every field left `Unknown`."""
    orient = run_dmc_json("orient", root) or {}
    landmarks_doc = run_dmc_json("landmarks", root) or {}
    unknowns = []

    def mark_unknown(section_label, field_label):
        unknowns.append((section_label, field_label))
        return UNKNOWN

    # 1. Repo identity — name is the directory basename (derivable); one-line purpose is not.
    name = os.path.basename(os.path.abspath(root)) or "repository"
    purpose = mark_unknown("Repo identity", "one-line purpose")

    # 2. Stack + package manager.
    languages = orient.get("languages") or {}
    lang_str = ", ".join(sorted(languages)) if languages else mark_unknown(
        "Stack and package manager", "languages")
    managers = orient.get("package_managers") or []
    pm_str = ", ".join(managers) if managers else mark_unknown(
        "Stack and package manager", "package manager")
    frameworks = mark_unknown("Stack and package manager", "frameworks")

    # 3. lint / typecheck / test / build — categorize detected commands via their source.
    verify_commands = orient.get("verify_commands") or []
    categorized = {"lint": None, "typecheck": None, "test": None, "build": None}
    uncategorized = []
    for row in verify_commands:
        cmd = row.get("command") if isinstance(row, dict) else None
        src = row.get("source") if isinstance(row, dict) else None
        if not cmd:
            continue
        cat = categorize_command(cmd, src)
        if cat and categorized[cat] is None:
            categorized[cat] = cmd
        elif cat is None:
            uncategorized.append(cmd)
    commands = {}
    for cat in ("lint", "typecheck", "test", "build"):
        if categorized[cat]:
            commands[cat] = "`%s`" % categorized[cat]
        else:
            commands[cat] = mark_unknown(
                "Lint / typecheck / test / build commands", cat)

    # 4. Architecture landmarks.
    landmarks = landmarks_doc.get("landmarks") or []
    if not landmarks:
        mark_unknown("Architecture landmarks", "key modules / entry points")

    # 5. Protected surfaces — repo-derived enforcement/contract/release landmarks (never Unknown:
    #    the universal secret/binding set always applies).
    protected_landmarks = sorted(
        {m.get("path") for m in landmarks
         if isinstance(m, dict) and m.get("class") in ("enforcement", "contract", "release")
         and m.get("path")})

    # 6. Migration / env / auth / billing — risk judgment, never derivable => Unknown per category.
    risk = {}
    for cat in ("Migration", "Env", "Auth", "Billing"):
        risk[cat] = mark_unknown("Migration / env / auth / billing risk notes", cat.lower())

    # 8. Verification commands — host build/test verification, or Unknown; the DMC gate always applies.
    host_verify = commands["test"] if commands["test"] != UNKNOWN else UNKNOWN
    if host_verify == UNKNOWN:
        mark_unknown("Verification commands", "host build/test verification")

    return {
        "name": name,
        "purpose": purpose,
        "languages": lang_str,
        "package_manager": pm_str,
        "frameworks": frameworks,
        "commands": commands,
        "uncategorized_commands": sorted(set(uncategorized)),
        "landmarks": landmarks,
        "protected_landmarks": protected_landmarks,
        "risk": risk,
        "host_verify": host_verify,
        "companion_docs": companion_docs_present(root),
    }, unknowns


# --------------------------------------------------------------------------- rendering

def _section(num, title, body_lines):
    return ["## %d. %s" % (num, title), ""] + body_lines + [""]


def render_sections(facts, unknowns):
    """Render the ten sections into a single markdown document string."""
    out = [
        "# AGENTS.md — %s" % facts["name"],
        "",
        "Generated by DMC (`dmc agents-md`) from repository-derived facts. Every fact not "
        "derivable from the repository is written literally as `Unknown` — never a guess. See "
        "section 10 for the aggregated Unknowns.",
        "",
    ]

    out += _section(1, "Repo identity", [
        "- Name: %s" % facts["name"],
        "- Purpose: %s" % facts["purpose"],
    ])

    out += _section(2, "Stack and package manager", [
        "- Languages: %s" % facts["languages"],
        "- Package manager: %s" % facts["package_manager"],
        "- Frameworks: %s" % facts["frameworks"],
    ])

    cmd_lines = [
        "- Lint: %s" % facts["commands"]["lint"],
        "- Typecheck: %s" % facts["commands"]["typecheck"],
        "- Test: %s" % facts["commands"]["test"],
        "- Build: %s" % facts["commands"]["build"],
    ]
    if facts["uncategorized_commands"]:
        cmd_lines.append(
            "- Other detected commands (uncategorized): %s"
            % ", ".join("`%s`" % c for c in facts["uncategorized_commands"]))
    out += _section(3, "Lint / typecheck / test / build commands", cmd_lines)

    if facts["landmarks"]:
        lm_lines = ["- `%s` — %s (%s)" % (m.get("path"), m.get("class"), m.get("reason"))
                    for m in facts["landmarks"]]
    else:
        lm_lines = ["- %s" % UNKNOWN]
    out += _section(4, "Architecture landmarks", lm_lines)

    prot_lines = [
        "Never read, edit, or print these (secrets, DMC bindings, generated/vendored surfaces):",
        "",
        "- Secret-bearing files (never open the contents):",
    ]
    prot_lines += ["  - %s" % p for p in SECRET_PATTERNS]
    prot_lines.append("- Version-control internals: `.git/`")
    prot_lines.append(
        "- DMC enforcement bindings (edit only through an approved plan scope): %s"
        % ", ".join(DMC_BINDINGS))
    if facts["protected_landmarks"]:
        prot_lines.append(
            "- Repository enforcement / contract / release landmarks (see section 4): %s"
            % ", ".join("`%s`" % p for p in facts["protected_landmarks"]))
    out += _section(5, "Protected surfaces", prot_lines)

    out += _section(6, "Migration / env / auth / billing risk notes", [
        "- Migration: %s" % facts["risk"]["Migration"],
        "- Env: %s" % facts["risk"]["Env"],
        "- Auth: %s" % facts["risk"]["Auth"],
        "- Billing: %s" % facts["risk"]["Billing"],
    ])

    section7_body = ["Core loop: plan -> scope -> execute -> verify -> evidence."]
    if facts["companion_docs"]:
        # Discoverability pointer — emitted ONLY when all three companion docs exist at the scanned
        # root (facts["companion_docs"]). The 4 lines below are reproduced BYTE-FOR-BYTE from the
        # committed AGENTS.md so a DMC-repo regen is a zero-section-7-hunk; the surrounding blank
        # lines match the committed layout exactly.
        section7_body += [
            "",
            "Companion context docs (discoverability): `AUTONOMY.md` (autonomy charter — levels /",
            "stop-conditions), `docs/CONTEXT_MAP.md` (context-file map: what loads when, single-source",
            "rules), and `docs/DMC_CONSTITUTION.md` (repo-maintenance governance — READ BEFORE any substantial",
            "change; amendment rules within).",
        ]
    section7_body += [
        "",
        "Non-negotiable rules:",
        "",
        "- No verification, no done.",
        "- No accepted file scope, no edit.",
        "- No explicit acceptance criteria, no execution.",
        "- No evidence log, no final completion claim.",
        "",
        "Invoking DMC on this host (Codex is explicit-only):",
        "",
        "- Skills are explicit. Invoke a workflow skill with `$dmc-plan-hard`, `$dmc-critic`, "
        "`$dmc-start-work`, `$dmc-verify-hard`, or `$dmc-status` (or via `/skills`). Codex does "
        "not auto-dispatch skills.",
        "- Subagents are explicit. Invoke a role through its Codex subagent definition (an "
        "`[agents.NAME]` config entry); Codex never spawns subagents automatically. Roles are "
        "capability classes (`orchestration/roles.json`), never model names.",
    ]
    out += _section(7, "DMC operating rules", section7_body)

    out += _section(8, "Verification commands", [
        "- Host build/test verification: %s" % facts["host_verify"],
        "- DMC completion gate (always applies on this host): run `dmc validate verification` on "
        "the run's verification report, then `dmc stop-gate quick` before any completion claim.",
    ])

    out += _section(9, "Stop conditions", [
        "Halt and hand back to the human release gate when:",
        "",
        "- a run is BLOCKED (an out-of-scope write or an unresolved verdict);",
        "- the completion gate is unmet (a missing verification report or evidence receipt);",
        "- a write would fall outside the approved scope lock;",
        "- a secret-bearing file would be read, edited, or printed;",
        "- the work needs a scope change (which requires a new plan revision and re-approval).",
    ])

    if unknowns:
        unk_lines = ["Fields left `Unknown` (not derivable from the repository — resolve and fill in):",
                     ""]
        unk_lines += ["- %s: %s" % (section_label, field_label)
                      for section_label, field_label in unknowns]
    else:
        unk_lines = ["None — every required fact was derivable from the repository."]
    out += _section(10, "Explicit Unknowns", unk_lines)

    text = "\n".join(out).rstrip("\n") + "\n"
    return text


def generate(root):
    """Return (document_text, unknowns) for the repo at `root`."""
    facts, unknowns = derive_facts(root)
    return render_sections(facts, unknowns), unknowns


def oversize_warning(text):
    """Return a stderr warning string if `text` exceeds DOC_MAX_BYTES, else None."""
    n = len(text.encode("utf-8"))
    if n <= DOC_MAX_BYTES:
        return None
    return (
        "warning: generated AGENTS.md is %d bytes, over the Codex project_doc_max_bytes budget "
        "(%d). Codex truncates beyond the cap; this generator never truncates. Externalize the "
        "largest sections into a linked file — typically section 4 (Architecture landmarks) and "
        "section 7 (DMC operating rules) — then trim the AGENTS.md to reference them."
        % (n, DOC_MAX_BYTES))


# --------------------------------------------------------------------------- validator

def split_sections(text):
    """Parse `## N. Title` headings into {num: (title, body)} where body is the text up to the
    next heading. Non-numbered `##`/`#` headings terminate a body but are not themselves sections."""
    lines = text.splitlines()
    sections = {}
    cur_num = None
    cur_title = None
    cur_body = []
    for line in lines:
        m = HEADING_RE.match(line)
        if m:
            if cur_num is not None:
                sections[cur_num] = (cur_title, "\n".join(cur_body))
            cur_num = int(m.group(1))
            cur_title = m.group(2)
            cur_body = []
        elif cur_num is not None:
            # A different (non-numbered) heading ends the current section body.
            if line.startswith("#") and not HEADING_RE.match(line):
                sections[cur_num] = (cur_title, "\n".join(cur_body))
                cur_num = None
                cur_title = None
                cur_body = []
            else:
                cur_body.append(line)
    if cur_num is not None:
        sections[cur_num] = (cur_title, "\n".join(cur_body))
    return sections


def filler_reasons(body):
    """Return a list of guessed-filler reasons found in a section body (empty => clean).
    `Unknown` literal is allowed and is not flagged."""
    reasons = []
    if FILLER_TOKEN_RE.search(body):
        reasons.append("contains an unfinished-filler token (TODO/TBD/FIXME/WIP/XXX)")
    if LOREM_RE.search(body):
        reasons.append("contains lorem placeholder text")
    if QMARK_RE.search(body):
        reasons.append("contains a '???' placeholder")
    if ANGLE_PLACEHOLDER_RE.search(body):
        reasons.append("contains an unfilled <...> template placeholder")
    return reasons


def validate_doc(text):
    """Return (ok, messages) for an AGENTS.md string against the §5 contract."""
    sections = split_sections(text)
    msgs = []
    ok = True
    for num, title in SECTIONS:
        if num not in sections:
            ok = False
            msgs.append("REFUSED: missing required section %d (%s)" % (num, title))
            continue
        found_title, body = sections[num]
        if found_title != title:
            ok = False
            msgs.append("REFUSED: section %d title mismatch (want %r, got %r)"
                        % (num, title, found_title))
        if not body.strip():
            ok = False
            msgs.append("REFUSED: section %d (%s) is empty" % (num, title))
            continue
        for reason in filler_reasons(body):
            ok = False
            msgs.append("REFUSED: section %d (%s) %s" % (num, title, reason))
    if ok:
        msgs.append("VALID: all 10 required sections present, non-empty, and free of guessed "
                    "filler (Unknown accepted)")
    return ok, msgs


# --------------------------------------------------------------------------- CLI: generate

def parse_generate_args(argv):
    root = "."
    out = None
    to_stdout = False
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--root":
            i += 1
            if i >= len(argv):
                return None, "usage: dmc agents-md [--root DIR] [--out FILE | --stdout]"
            root = argv[i]
        elif a == "--out":
            i += 1
            if i >= len(argv):
                return None, "usage: dmc agents-md [--root DIR] [--out FILE | --stdout]"
            out = argv[i]
        elif a == "--stdout":
            to_stdout = True
        else:
            return None, "dmc agents-md: unknown argument: %s" % a
        i += 1
    if out and to_stdout:
        return None, "dmc agents-md: --out and --stdout are mutually exclusive"
    return {"root": root, "out": out, "stdout": to_stdout}, None


def cmd_generate(argv):
    opts, err = parse_generate_args(argv)
    if err:
        print(err, file=sys.stderr)
        return 2
    root = opts["root"]
    if not os.path.isdir(root):
        print("dmc agents-md: --root is not a directory: %s" % root, file=sys.stderr)
        return 2
    text, _ = generate(root)

    if opts["stdout"]:
        sys.stdout.write(text)
        warn = oversize_warning(text)
        if warn:
            print(warn, file=sys.stderr)
        return 0

    out = opts["out"] or os.path.join(root, "AGENTS.md")
    if os.path.exists(out):
        print("dmc agents-md: refusing to overwrite existing file: %s\n"
              "  (host AGENTS.md is preserved, never blind-copied or overwritten; per "
              "docs/HOST_REPO_ADAPTATION_POLICY.md. Choose a different --out or remove it "
              "deliberately.)" % out, file=sys.stderr)
        return 3
    try:
        with open(out, "w", encoding="utf-8") as f:
            f.write(text)
    except OSError as e:
        print("dmc agents-md: cannot write %s: %s" % (out, e), file=sys.stderr)
        return 2
    print("wrote %s (%d bytes)" % (out, len(text.encode("utf-8"))))
    warn = oversize_warning(text)
    if warn:
        print(warn, file=sys.stderr)
    return 0


def cmd_validate(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            text = f.read()
    except OSError as e:
        print("REFUSED: cannot read %s: %s" % (path, e), file=sys.stderr)
        return 3
    ok, msgs = validate_doc(text)
    for m in msgs:
        print(m)
    return 0 if ok else 3


# --------------------------------------------------------------------------- self-test

class ST:
    """Section self-test bookkeeping (same shape as bin/lib's other Ring-0 modules)."""

    def __init__(self, name):
        self.name, self.passed, self.failed = name, 0, 0

    def ok(self, label, cond):
        if cond:
            self.passed += 1
            print("PASS [%s] %s" % (self.name, label))
        else:
            self.failed += 1
            print("FAIL [%s] %s" % (self.name, label))

    def done(self):
        print("[%s] %d PASS / %d FAIL" % (self.name, self.passed, self.failed))
        sys.exit(0 if self.failed == 0 else 1)


def _write(path, text):
    d = os.path.dirname(path)
    if d and not os.path.isdir(d):
        os.makedirs(d)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def _make_node_repo(root):
    _write(os.path.join(root, "package.json"), json.dumps({
        "name": "fixture-node",
        "main": "index.js",
        "scripts": {"test": "jest", "lint": "eslint .", "build": "tsc -b",
                    "typecheck": "tsc --noEmit"},
    }) + "\n")
    _write(os.path.join(root, "index.js"), "console.log('fixture');\n")
    _write(os.path.join(root, "src", "app.js"), "module.exports = 1;\n")


def _make_python_repo(root):
    _write(os.path.join(root, "pyproject.toml"),
           "[project]\nname = \"fixture-py\"\n\n[tool.pytest.ini_options]\n"
           "testpaths = [\"tests\"]\n")
    _write(os.path.join(root, "app.py"), "print('fixture')\n")


def _make_empty_repo(root):
    # A directory with no manifests and no landmark-classified files.
    _write(os.path.join(root, "notes.txt"), "just notes\n")


def _all_headings_present(text):
    sections = split_sections(text)
    return all(num in sections for num, _ in SECTIONS)


def selftest():
    t = ST("agents-md")
    tmp = tempfile.mkdtemp(prefix="dmc-agents-md-selftest-")
    try:
        # --- node fixture: manifest + categorized commands ---
        node = os.path.join(tmp, "node")
        os.makedirs(node)
        _make_node_repo(node)
        node_doc, node_unknowns = generate(node)
        t.ok("N1 node fixture emits all 10 required sections", _all_headings_present(node_doc))
        t.ok("N2 node package manager detected (npm)",
             "Package manager: npm" in node_doc)
        t.ok("N3 node test/lint/build/typecheck commands categorized from sources",
             "Test: `npm test`" in node_doc
             and "Lint: `npm run lint`" in node_doc
             and "Build: `npm run build`" in node_doc
             and "Typecheck: `npm run typecheck`" in node_doc)
        node_ok, _ = validate_doc(node_doc)
        t.ok("N4 generated node doc validates green", node_ok)

        # --- python fixture: partial commands + Unknown categories ---
        py = os.path.join(tmp, "py")
        os.makedirs(py)
        _make_python_repo(py)
        py_doc, py_unknowns = generate(py)
        t.ok("P1 python fixture emits all 10 required sections", _all_headings_present(py_doc))
        t.ok("P2 python package manager detected (python)",
             "Package manager: python" in py_doc)
        t.ok("P3 python test = pytest, lint/typecheck/build render Unknown",
             "Test: `pytest`" in py_doc
             and "Lint: Unknown" in py_doc
             and "Build: Unknown" in py_doc)
        t.ok("P4 python Unknowns aggregated in section 10",
             "Lint / typecheck / test / build commands: lint" in py_doc)
        py_ok, _ = validate_doc(py_doc)
        t.ok("P5 generated python doc validates green", py_ok)

        # --- empty fixture: everything derivable is Unknown ---
        empty = os.path.join(tmp, "empty")
        os.makedirs(empty)
        _make_empty_repo(empty)
        empty_doc, empty_unknowns = generate(empty)
        t.ok("E1 empty fixture emits all 10 required sections", _all_headings_present(empty_doc))
        t.ok("E2 empty fixture package manager + commands render literally Unknown",
             "Package manager: Unknown" in empty_doc
             and "Test: Unknown" in empty_doc)
        t.ok("E3 empty fixture landmarks render literally Unknown",
             "## 4. Architecture landmarks\n\n- Unknown" in empty_doc)
        t.ok("E4 empty fixture Unknowns list is non-empty and names package manager",
             "package manager" in empty_doc.split("## 10.")[-1])
        empty_ok, _ = validate_doc(empty_doc)
        t.ok("E5 generated empty doc validates green (Unknown is accepted, not filler)", empty_ok)

        # --- Unknown rule: no guessed business logic leaked in for the empty repo ---
        t.ok("U1 empty fixture never invents a purpose (purpose is Unknown)",
             "Purpose: Unknown" in empty_doc)

        # --- section-7 companion-docs pointer: presence-gated, atomic all-or-nothing ---
        #     Positive: a fixture carrying all three companion docs (content-free stubs) emits the
        #     discoverability paragraph. Negative: the empty fixture (same base repo, no docs) omits
        #     it entirely — the host-shape proof, since no install ships those docs (critic r1 B1).
        cdocs = os.path.join(tmp, "companion")
        os.makedirs(cdocs)
        _make_empty_repo(cdocs)
        for rel in COMPANION_DOCS:
            _write(os.path.join(cdocs, rel), "")
        cdocs_doc, _ = generate(cdocs)
        t.ok("C1 fixture with all three companion docs emits the section-7 pointer paragraph",
             "Companion context docs" in cdocs_doc)
        t.ok("C2 fixture lacking the companion docs omits the section-7 pointer (host-shape proof)",
             "Companion context docs" not in empty_doc)

        # --- validator negative controls ---
        # (a) missing section
        cut = re.sub(r"## 6\. Migration.*?(?=## 7\.)", "", node_doc, flags=re.S)
        cut_ok, cut_msgs = validate_doc(cut)
        t.ok("V1 validator REFUSES a doc with section 6 deleted (missing section)",
             (not cut_ok) and any("missing required section 6" in m for m in cut_msgs))
        # (b) guessed filler replacing an Unknown
        filled = empty_doc.replace("Purpose: Unknown", "Purpose: TODO write this")
        filled_ok, filled_msgs = validate_doc(filled)
        t.ok("V2 validator REFUSES a guessed-filler placeholder (TODO where Unknown belongs)",
             (not filled_ok) and any("unfinished-filler token" in m for m in filled_msgs))
        # (c) angle-bracket template placeholder
        angled = empty_doc.replace("Purpose: Unknown", "Purpose: <the project purpose>")
        angled_ok, _ = validate_doc(angled)
        t.ok("V3 validator REFUSES an unfilled <...> template placeholder", not angled_ok)
        # (d) empty section body
        emptied = re.sub(r"(## 9\. Stop conditions\n\n).*?(\n## 10\.)", r"\1\2",
                         node_doc, flags=re.S)
        emptied_ok, emptied_msgs = validate_doc(emptied)
        t.ok("V4 validator REFUSES an empty required section body",
             (not emptied_ok) and any("is empty" in m for m in emptied_msgs))

        # --- merge policy: refuse-to-overwrite ---
        target = os.path.join(node, "AGENTS.md")
        rc1 = cmd_generate(["--root", node, "--out", target])
        rc2 = cmd_generate(["--root", node, "--out", target])
        t.ok("M1 first generate to a fresh path succeeds (0); second REFUSES overwrite (3)",
             rc1 == 0 and rc2 == 3)

        # --- size budget: oversized synthetic input warns, never truncates ---
        big = os.path.join(tmp, "big")
        os.makedirs(os.path.join(big, "migrations"))
        for i in range(700):
            _write(os.path.join(big, "migrations", "m%04d_change_some_table_name.sql" % i),
                   "-- migration %d\n" % i)
        big_doc, _ = generate(big)
        warn = oversize_warning(big_doc)
        t.ok("Z1 oversized doc (>32768 bytes) triggers a size-budget warning",
             len(big_doc.encode("utf-8")) > DOC_MAX_BYTES and warn is not None)
        t.ok("Z2 oversized doc is NOT truncated (all 700 migration landmarks present + valid)",
             big_doc.count("data-surface heuristic") == 700 and validate_doc(big_doc)[0])
        t.ok("Z3 size-budget warning names the sections to externalize",
             warn is not None and "section 4" in warn and "section 7" in warn)

        # --- determinism: two generations of the same (untouched) tree are byte-identical.
        #     Use the python fixture, which no earlier step writes into. ---
        again, _ = generate(py)
        t.ok("D1 generation is deterministic (same tree -> byte-identical output)",
             again == py_doc)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    t.done()


# --------------------------------------------------------------------------- main

def main():
    argv = sys.argv[1:]
    if "--self-test" in argv:
        selftest()
        return
    if argv and argv[0] == "--validate":
        if len(argv) < 2:
            print("usage: dmc agents-md --validate FILE", file=sys.stderr)
            sys.exit(2)
        sys.exit(cmd_validate(argv[1]))
    sys.exit(cmd_generate(argv))


if __name__ == "__main__":
    main()
