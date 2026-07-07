#!/usr/bin/env python3
"""dmc-skills-mirror.py — DMC v1 M6.5 (DMC-T011b.3) Codex/Claude skill mirror-drift check.

Compares each Codex-bound DMC workflow skill (`.agents/skills/dmc-<name>/SKILL.md`) against its
Claude Code counterpart (`.claude/skills/dmc-<name>/SKILL.md`) so the two skill surfaces cannot
silently diverge on the operative instructions that drive the `dmc` verbs (M3 mirror pattern:
`bin/lib/dmc-instance-validate.py`'s schema-mirror header-strip compare;
`bin/lib/dmc-legacy-selftest.py`'s bin/lib<->.harness/evidence byte-mirror).

Mirrored-skill scope (deliberate, not a glob of every `.claude/skills/dmc-*`)
------------------------------------------------------------------------------
`.claude/skills/` holds MANY `dmc-*` skills (as of this writing: dmc-critic, dmc-init-deep,
dmc-off, dmc-on, dmc-plan-hard, dmc-start-work, dmc-status, dmc-ultrawork,
dmc-worker-{cancel,dispatch,import,plan,review,status}). The M6.5 plan's Proposed Changes bind
ONLY the five core workflow verbs to `.agents/skills/` in this milestone:
dmc-plan-hard, dmc-critic, dmc-start-work, dmc-verify-hard, dmc-status. The rest are OUT OF
SCOPE here by design (worker-bridge skills are a separate, frozen surface per `DMC.md` §Worker
Bridge / M7; mode-switch and other skills are simply not part of this milestone's file
allowlist) — not silently skipped. MIRRORED_SKILLS below is that explicit, documented set; a
literal `dmc-*` glob would misreport all ten out-of-scope skills as "missing on Codex" and turn
a legitimate, deliberate gap into a false red.

Normalization (the documented rule under which the two payloads must be byte-identical)
------------------------------------------------------------------------------------------
  1. Strip the file's own YAML frontmatter (a `---\\n...\\n---\\n` block at the very start of
     the file). The two hosts intentionally carry DIFFERENT frontmatter — Claude:
     `name`, `description`, `argument-hint`, `disable-model-invocation`, `effort`, and
     sometimes `disallowed-tools`; Codex: `name`, `description` only, per the confirmed
     `.agents/skills/<name>/SKILL.md` standard in `docs/CODEX_ADAPTER.md` §1. Frontmatter is
     discarded entirely before comparison, on both sides, always.
  2. On what remains, strip ONE marked host-specific header block, if and only if it is the
     first thing present: a block opening with the exact line `<!-- DMC-HOST-NOTE:BEGIN -->`
     and closing with the exact line `<!-- DMC-HOST-NOTE:END -->` (both marker lines included
     in what is stripped). This is where a skill file may explain host-specific mechanics
     (Codex's explicit-only invocation, Codex's narrower frontmatter, a field Codex has no
     equivalent for) without touching the shared operative instructions. A BEGIN marker found
     with no matching END is left UNSTRIPPED — it fails CLOSED into a reported DRIFT rather
     than being silently treated as "no block present".
  3. Strip leading blank lines from what remains (a cosmetic side effect of steps 1-2, not a
     content difference — both a header-less file and a header-stripped file start clean).
The result is the skill's "operative payload". Two mirrored files pass the check iff their
operative payloads are byte-identical. The Claude-side files carry no host-note block today, so
step 2 is a no-op there; that is expected, not a bug.

Modes
-----
  (default / --check)  one-shot report over MIRRORED_SKILLS: prints one `OK: dmc-<name>` or
                        `DRIFT: dmc-<name> — <reason>` line per name, plus a check for any
                        UNEXPECTED extra `dmc-*` directory under `.agents/skills/` that is not
                        in MIRRORED_SKILLS (nothing else should be populating that tree in this
                        milestone). Exit 0 iff every mirrored name is OK and there is no
                        unexpected extra; exit 1 otherwise.
  --self-test           hermetic self-test (its own `mktemp` fixtures only): a synthetic
                        clean-mirror pair passes; a seeded one-byte drift in a mirrored payload
                        is refused with the offending skill named; a missing counterpart is
                        refused; an unterminated host-note marker fails closed; a real-repo
                        check is also asserted (so a broken normalize() surfaces here too), but
                        every NEGATIVE control uses only disposable temp files and never
                        modifies the real repo (checked by hash before/after). Exit 0 iff every
                        assertion passes, else 1.

Exit contract: 0 = clean / all self-test assertions passed; 1 = drift found, an unexpected extra
skill found, or a self-test assertion failed. No other exit codes are used by this module.

House rules: stdlib-only, deterministic, env-independent (no env var reads), offline (no
network, no subprocess at all), reads only files under this repo plus its own disposable
`tempfile.mkdtemp()` directories (always cleaned up). No `shell=True`.
"""

import os
import re
import shutil
import sys
import tempfile

HOST_NOTE_BEGIN = "<!-- DMC-HOST-NOTE:BEGIN -->"
HOST_NOTE_END = "<!-- DMC-HOST-NOTE:END -->"

FRONTMATTER_CLOSE_RE = re.compile(r"\n---\n")

# The explicit, milestone-scoped mirror set (see module docstring for why this is not a glob).
MIRRORED_SKILLS = [
    "dmc-plan-hard",
    "dmc-critic",
    "dmc-start-work",
    "dmc-verify-hard",
    "dmc-status",
]


def repo_root():
    return os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))


def claude_skills_dir(root=None):
    return os.path.join(root or repo_root(), ".claude", "skills")


def agents_skills_dir(root=None):
    return os.path.join(root or repo_root(), ".agents", "skills")


def strip_frontmatter(text):
    """Drop a leading `---\\n...\\n---\\n` YAML frontmatter block, if present."""
    if not text.startswith("---\n"):
        return text
    m = FRONTMATTER_CLOSE_RE.search(text, 4)
    if not m:
        return text
    return text[m.end():]


def strip_host_note(text):
    """Drop one leading `<!-- DMC-HOST-NOTE:BEGIN/END -->` block, if it is the first thing
    present. A BEGIN with no matching END is left untouched (fails closed into a drift)."""
    if not text.startswith(HOST_NOTE_BEGIN):
        return text
    end_idx = text.find(HOST_NOTE_END)
    if end_idx == -1:
        return text
    return text[end_idx + len(HOST_NOTE_END):]


def normalize_payload(text):
    """The documented normalization: frontmatter-strip, then host-note-strip, then a leading
    blank-line trim. See the module docstring for the full rule."""
    return strip_host_note(strip_frontmatter(text)).lstrip("\n")


def read_text(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def compare_pair(claude_dir, agents_dir, name):
    """(ok, reason) for one dmc-<name> skill pair."""
    claude_path = os.path.join(claude_dir, name, "SKILL.md")
    agents_path = os.path.join(agents_dir, name, "SKILL.md")
    claude_present = os.path.isfile(claude_path)
    agents_present = os.path.isfile(agents_path)
    if not claude_present and not agents_present:
        return False, "neither side has %s/SKILL.md" % name
    if not claude_present:
        return False, "missing %s" % claude_path
    if not agents_present:
        return False, "missing %s" % agents_path
    try:
        claude_payload = normalize_payload(read_text(claude_path))
    except (OSError, UnicodeDecodeError) as e:
        return False, "cannot read %s: %s" % (claude_path, e)
    try:
        agents_payload = normalize_payload(read_text(agents_path))
    except (OSError, UnicodeDecodeError) as e:
        return False, "cannot read %s: %s" % (agents_path, e)
    if claude_payload != agents_payload:
        return False, ("normalized operative payload differs (byte-compare after frontmatter "
                        "+ host-note strip)")
    return True, "ok"


def find_unexpected_extras(agents_dir, mirrored_names):
    """dmc-* directories under agents_dir that are not in mirrored_names — nothing else should
    be populating .agents/skills/ in this milestone (single-owner file grants)."""
    if not os.path.isdir(agents_dir):
        return []
    return sorted(
        entry for entry in os.listdir(agents_dir)
        if entry.startswith("dmc-")
        and os.path.isdir(os.path.join(agents_dir, entry))
        and entry not in mirrored_names
    )


def mirror_check(claude_dir=None, agents_dir=None, mirrored_names=None):
    """(ok, lines) over the mirrored-skill set."""
    root = repo_root()
    claude_dir = claude_dir or claude_skills_dir(root)
    agents_dir = agents_dir or agents_skills_dir(root)
    names = mirrored_names if mirrored_names is not None else MIRRORED_SKILLS
    lines = []
    ok = True
    for name in names:
        pair_ok, reason = compare_pair(claude_dir, agents_dir, name)
        if pair_ok:
            lines.append("OK: %s" % name)
        else:
            ok = False
            lines.append("DRIFT: %s — %s" % (name, reason))

    extras = find_unexpected_extras(agents_dir, names)
    if extras:
        ok = False
        lines.append("FAIL unexpected extra dmc-* skill(s) under %s not in the mirrored set: %s"
                      % (agents_dir, ", ".join(extras)))
    else:
        lines.append("PASS no unexpected extra dmc-* skills under %s" % agents_dir)

    return ok, lines


# --------------------------------------------------------------------------- self-test

class ST:
    """Section self-test bookkeeping (same shape as bin/lib's other M3-pattern modules)."""

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


FIXTURE_CLAUDE = (
    "---\n"
    "name: dmc-selftest-fixture\n"
    "description: synthetic fixture, never a real dmc verb.\n"
    "disable-model-invocation: true\n"
    "---\n"
    "\n"
    "# Do-Me-Coding Selftest Fixture\n"
    "\n"
    "Body line one.\n"
    "Body line two.\n"
)

FIXTURE_AGENTS_CLEAN = (
    "---\n"
    "name: dmc-selftest-fixture\n"
    "description: synthetic fixture, never a real dmc verb.\n"
    "---\n"
    + HOST_NOTE_BEGIN + "\n"
    "Host-specific note text that legitimately differs by host.\n"
    + HOST_NOTE_END + "\n"
    "\n"
    "# Do-Me-Coding Selftest Fixture\n"
    "\n"
    "Body line one.\n"
    "Body line two.\n"
)

# Same as FIXTURE_AGENTS_CLEAN but the BEGIN marker's matching END was dropped, leaving an
# unterminated host-note block (used by the M4 fail-closed negative control below).
FIXTURE_AGENTS_UNTERMINATED = FIXTURE_AGENTS_CLEAN.replace(HOST_NOTE_END + "\n", "")


def _write_pair(tmp, tag, name, claude_text, agents_text):
    claude_dir = os.path.join(tmp, "%s-claude" % tag)
    agents_dir = os.path.join(tmp, "%s-agents" % tag)
    os.makedirs(os.path.join(claude_dir, name))
    os.makedirs(os.path.join(agents_dir, name))
    with open(os.path.join(claude_dir, name, "SKILL.md"), "w", encoding="utf-8") as f:
        f.write(claude_text)
    with open(os.path.join(agents_dir, name, "SKILL.md"), "w", encoding="utf-8") as f:
        f.write(agents_text)
    return claude_dir, agents_dir


def _hash_real_skill_files(root):
    """path -> content for every real MIRRORED_SKILLS SKILL.md that currently exists, used to
    prove the self-test's negative controls never touch the real repo."""
    snapshot = {}
    for base in (claude_skills_dir(root), agents_skills_dir(root)):
        for name in MIRRORED_SKILLS:
            p = os.path.join(base, name, "SKILL.md")
            if os.path.isfile(p):
                snapshot[p] = read_text(p)
    return snapshot


def selftest():
    t = ST("skills-mirror")
    root = repo_root()

    # 1. Real repo check is informational here (the shell fixture asserts it authoritatively
    #    for CI); still exercised so a broken normalize() surfaces immediately, not just in the
    #    shell test.
    real_ok, real_lines = mirror_check()
    t.ok("real .claude/skills <-> .agents/skills mirrored-set all OK (%d checked)"
         % len(MIRRORED_SKILLS), real_ok)
    if not real_ok:
        for line in real_lines:
            print("  [context] %s" % line)

    pre_snapshot = _hash_real_skill_files(root)

    tmp = tempfile.mkdtemp(prefix="dmc-skills-mirror-negctl-")
    try:
        # 2. Clean synthetic pair (different frontmatter + a host-note block on the Codex side)
        #    reports OK — proves the normalization (not merely an exact byte-compare) is what
        #    runs.
        name = "dmc-selftest-fixture"
        clean_claude, clean_agents = _write_pair(
            tmp, "clean", name, FIXTURE_CLAUDE, FIXTURE_AGENTS_CLEAN)
        clean_ok, clean_lines = mirror_check(clean_claude, clean_agents, mirrored_names=[name])
        t.ok("M1 synthetic clean pair (differing frontmatter + Codex host-note block) reports OK",
             clean_ok and clean_lines[0] == "OK: %s" % name)

        # 3. One-byte drift in a mirrored payload is REFUSED, and the skill is named.
        tampered_agents = os.path.join(tmp, "tampered-agents")
        shutil.copytree(clean_agents, tampered_agents)
        tampered_file = os.path.join(tampered_agents, name, "SKILL.md")
        with open(tampered_file, "a", encoding="utf-8") as f:
            f.write("X")
        tampered_ok, tampered_lines = mirror_check(
            clean_claude, tampered_agents, mirrored_names=[name])
        t.ok("M2 negative control: one-byte drift in a mirrored payload is REFUSED and the "
             "skill is named",
             (not tampered_ok)
             and any(line.startswith("DRIFT: %s" % name) for line in tampered_lines))

        # 4. A missing counterpart (Codex side absent) is REFUSED and named.
        empty_agents = os.path.join(tmp, "empty-agents")
        os.makedirs(empty_agents)
        missing_ok, missing_lines = mirror_check(
            clean_claude, empty_agents, mirrored_names=[name])
        t.ok("M3 negative control: a missing Codex-side counterpart is REFUSED and named",
             (not missing_ok)
             and any(("DRIFT: %s" % name) in line and "missing" in line and "SKILL.md" in line
                     for line in missing_lines))

        # 5. An unterminated DMC-HOST-NOTE:BEGIN marker fails CLOSED (reported as drift, never
        #    silently treated as "no host block").
        unterminated_claude, unterminated_agents = _write_pair(
            tmp, "unterminated", name, FIXTURE_CLAUDE, FIXTURE_AGENTS_UNTERMINATED)
        unterminated_ok, unterminated_lines = mirror_check(
            unterminated_claude, unterminated_agents, mirrored_names=[name])
        t.ok("M4 negative control: an unterminated DMC-HOST-NOTE:BEGIN marker fails CLOSED "
             "(reported as drift, not silently treated as absent)",
             (not unterminated_ok)
             and any(line.startswith("DRIFT: %s" % name) for line in unterminated_lines))

        # 6. An unexpected extra dmc-* directory under the (scoped) agents side is REFUSED.
        extra_agents = os.path.join(tmp, "extra-agents")
        os.makedirs(os.path.join(extra_agents, name))
        with open(os.path.join(extra_agents, name, "SKILL.md"), "w", encoding="utf-8") as f:
            f.write(FIXTURE_AGENTS_CLEAN)
        os.makedirs(os.path.join(extra_agents, "dmc-unexpected"))
        with open(os.path.join(extra_agents, "dmc-unexpected", "SKILL.md"), "w",
                  encoding="utf-8") as f:
            f.write(FIXTURE_AGENTS_CLEAN)
        extra_ok, extra_lines = mirror_check(clean_claude, extra_agents, mirrored_names=[name])
        t.ok("M5 negative control: an unexpected extra dmc-* dir under the Codex skills tree "
             "is REFUSED and named",
             (not extra_ok)
             and any("dmc-unexpected" in line for line in extra_lines))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    # 7. None of the above ever touched the real repo files.
    post_snapshot = _hash_real_skill_files(root)
    t.ok("M6 negative controls never touched the real repo (pre/post content identical)",
         pre_snapshot == post_snapshot)

    t.done()


# ------------------------------------------------------------------------------- main

def main():
    if "--self-test" in sys.argv[1:]:
        selftest()
        return
    ok, lines = mirror_check()
    for line in lines:
        print(line)
    print("RESULT: %s" % ("PASS skills-mirror green" if ok else "FAIL skills-mirror red"))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
