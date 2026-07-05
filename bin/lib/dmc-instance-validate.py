#!/usr/bin/env python3
"""dmc-instance-validate.py — DMC v1.0 M3 instance validators + schema-mirror check.

Validates a concrete plan / run / verification *instance* document against its root schema
(PLAN_SCHEMA.md / RUN_SCHEMA.md / VERIFICATION_SCHEMA.md), and checks the generated
`.harness/schemas/{plan,run,verification}.schema.md` mirrors against those canonical roots.

Subcommands:
  plan|run|verification --validate FILE   fail-closed instance validator (ACCEPT=>0, REFUSED=>3)
  plan|run|verification --self-test        section self-test (prints "[name] N PASS / M FAIL")
  mirror --check                           all three mirrors == canonical modulo generated header
  mirror --write                           (re)generate the three mirror files from the roots
  mirror --self-test                       mirror check + tamper negative control

House rules (v0.6.x / M2 lineage): deterministic, env-independent (no env reads), offline (no
network, no git), input-only (reads only the named file), value-blind (refusals name schema
constants and reason codes — never the document's content values), secret-path refused by path,
fail-closed with named reason codes and negative controls. Advisory tier: the runtime enforcement
floor stays the hooks.
"""

import argparse
import os
import re
import sys
import tempfile

# Instance-document schema ids (the artifact these validators certify).
SCHEMA_IDS = {
    "plan": "dmc.plan-instance.v1",
    "run": "dmc.run-instance.v1",
    "verification": "dmc.verification-instance.v1",
}

# name -> (canonical root file, generated mirror path) — both repo-root-relative.
MIRRORS = {
    "plan": ("PLAN_SCHEMA.md", ".harness/schemas/plan.schema.md"),
    "run": ("RUN_SCHEMA.md", ".harness/schemas/run.schema.md"),
    "verification": ("VERIFICATION_SCHEMA.md", ".harness/schemas/verification.schema.md"),
}


def gen_header(root_name):
    """The single generated-mirror header line (stripped for the byte-compare)."""
    return ("<!-- GENERATED MIRROR — canonical home: %s; do not edit by hand. "
            "Regenerate from the canonical root. -->" % root_name)


def canonical_home_marker(root_name):
    return "DMC canonical home: %s (root)." % root_name


# ---- required structure per root schema (exact h2 section headers) ----------

PLAN_SECTIONS = ["Goal", "User Intent", "Current Repo Findings", "Relevant Files",
                 "Out of Scope", "Proposed Changes", "Acceptance Criteria", "Risks",
                 "Assumptions", "Execution Tasks", "Verification Commands", "Approval Status"]

RUN_TITLE = "Do-Me-Coding Run"
RUN_FIELDS = ["run_id", "active_plan", "status", "started_at", "updated_at", "session_ids"]
RUN_STATUS = ["INIT", "RUNNING", "BLOCKED", "VERIFYING", "PASS", "FAIL", "PARTIAL"]
RUN_SECTIONS = ["Approved File Scope", "Tasks", "Commands Run", "Evidence Files",
                "Verification Files", "Open Risks"]

VERIF_TITLE = "Verification Report"
VERIF_SECTIONS = ["Run ID", "Plan", "Changed Files", "Commands Run", "Manual Checks",
                  "Scope Review", "Package / Env / Migration Review", "Unresolved Risks",
                  "Final Status"]
VERIF_PEM_LINES = ["Package files changed:", "Env files changed:", "Migration files changed:"]


# ------------------------------------------------------------------- helpers

def die(msg, code=2):
    sys.stderr.write("dmc-instance-validate: %s\n" % msg)
    sys.exit(code)


def refuse(reasons):
    for r in reasons:
        print("REFUSED: %s" % r)
    sys.exit(3)


def is_secret_path(path):
    """Path-only secret filter (mirror of DMC.md secret patterns). Never opens the file."""
    base = os.path.basename(path).lower()
    parts = [p.lower() for p in path.replace(os.sep, "/").split("/")]
    if base in {".env.example", ".env.sample", ".env.template", ".env.dist"}:
        return False
    if base == ".env" or base.startswith(".env."):
        return True
    if re.search(r"\.(pem|key|p12|pfx|keystore|jks)$", base):
        return True
    if base.startswith(("id_rsa", "id_ed25519")):
        return True
    if base in {".npmrc", ".netrc", ".pgpass", "credentials.json"}:
        return True
    if "secret" in base and re.search(r"\.(json|ya?ml|env)$", base):
        return True
    if ".ssh" in parts or ".gnupg" in parts:
        return True
    if ".aws" in parts and base == "credentials":
        return True
    return False


def read_text(path):
    if is_secret_path(path):
        die("refused: secret-shaped target path", 3)
    with open(path, "r", encoding="utf-8", errors="strict") as f:
        return f.read()


def parse_doc(text):
    """Fence-aware markdown parse.

    Returns (title, preamble_lines, sections) where sections maps an exact h2 header string
    to its body lines (everything up to the next h2, h3+ included). Headers inside ``` fences
    are treated as body, not structure.
    """
    title = None
    preamble = []
    sections = {}
    order = []
    cur = None
    in_fence = False
    for line in text.splitlines():
        stripped = line.lstrip()
        if stripped.startswith("```"):
            in_fence = not in_fence
            (preamble if cur is None else sections[cur]).append(line)
            continue
        if not in_fence and line.startswith("## "):
            cur = line[3:].strip()
            if cur not in sections:
                sections[cur] = []
                order.append(cur)
            continue
        if not in_fence and title is None and line.startswith("# "):
            title = line[2:].strip()
            continue
        (preamble if cur is None else sections[cur]).append(line)
    return title, preamble, sections


# --------------------------------------------------------------- validate: plan

def validate_plan(text):
    errs = []
    if not text.strip():
        return ["PLAN-UNREADABLE: empty document"]
    title, _preamble, sections = parse_doc(text)
    if not title:
        errs.append("PLAN-NO-TITLE: no top-level '# ' title line")
    for name in PLAN_SECTIONS:
        if name not in sections:
            errs.append("PLAN-MISSING-SECTION: %s" % name)
    # Content checks only when the section exists (missing already reported above).
    rf = "\n".join(sections.get("Relevant Files", []))
    if "Relevant Files" in sections and "Allowed to Edit" not in rf:
        errs.append("PLAN-RELEVANT-FILES-NO-TABLE: 'Allowed to Edit' column absent")
    ac = "\n".join(sections.get("Acceptance Criteria", []))
    if "Acceptance Criteria" in sections:
        if "Criterion:" not in ac:
            errs.append("PLAN-ACCEPTANCE-NO-CRITERION: no 'Criterion:' entry")
        if "Verification Method:" not in ac:
            errs.append("PLAN-ACCEPTANCE-NO-METHOD: no 'Verification Method:' entry")
    if "Execution Tasks" in sections:
        # Accept both the plain PLAN_SCHEMA task shape and the extended per-milestone block
        # ({Acceptance, Verification, Rollback, Evidence, Not-edit, Risk}) — only >=1 task id
        # checkbox is required.
        et = "\n".join(sections["Execution Tasks"])
        if not re.search(r"(?m)^\s*-\s*\[[ xX]\]\s*DMC-T\d+", et):
            errs.append("PLAN-NO-TASKS: no '- [ ] DMC-T<n>' task entry")
    if "Approval Status" in sections:
        ap = "\n".join(sections["Approval Status"])
        if not re.search(r"(?m)^\s*Status:\s*(DRAFT|APPROVED|REJECTED)\b", ap):
            errs.append("PLAN-APPROVAL-NO-STATUS: no 'Status: DRAFT|APPROVED|REJECTED' line")
    return errs


# ---------------------------------------------------------------- validate: run

def validate_run(text):
    errs = []
    if not text.strip():
        return ["RUN-UNREADABLE: empty document"]
    title, preamble, sections = parse_doc(text)
    if title != RUN_TITLE:
        errs.append("RUN-NO-TITLE: title must be '# %s'" % RUN_TITLE)
    pre = "\n".join(preamble)
    for field in RUN_FIELDS:
        if not re.search(r"(?m)^\s*%s:" % re.escape(field), pre):
            errs.append("RUN-MISSING-FIELD: %s" % field)
    m = re.search(r"(?m)^\s*status:\s*(\S+)", pre)
    if m and m.group(1) not in RUN_STATUS:
        errs.append("RUN-BAD-STATUS: status not in %s" % "|".join(RUN_STATUS))
    for name in RUN_SECTIONS:
        if name not in sections:
            errs.append("RUN-MISSING-SECTION: %s" % name)
    return errs


# ------------------------------------------------------- validate: verification

def validate_verification(text):
    errs = []
    if not text.strip():
        return ["VERIF-UNREADABLE: empty document"]
    title, _preamble, sections = parse_doc(text)
    if title != VERIF_TITLE:
        errs.append("VERIF-NO-TITLE: title must be '# %s'" % VERIF_TITLE)
    for name in VERIF_SECTIONS:
        if name not in sections:
            errs.append("VERIF-MISSING-SECTION: %s" % name)
    if "Scope Review" in sections:
        sr = "\n".join(sections["Scope Review"])
        if not re.search(r"(?m)^\s*Result:\s*(PASS|FAIL)\b", sr):
            errs.append("VERIF-SCOPE-NO-RESULT: Scope Review lacks 'Result: PASS|FAIL'")
    pem_name = "Package / Env / Migration Review"
    if pem_name in sections:
        pem = "\n".join(sections[pem_name])
        for lead in VERIF_PEM_LINES:
            if lead not in pem:
                errs.append("VERIF-PEM-INCOMPLETE: missing '%s' line" % lead)
    if "Final Status" in sections:
        fs = "\n".join(sections["Final Status"])
        if not re.search(r"(?m)^\s*(PASS|FAIL|PARTIAL)\b", fs):
            errs.append("VERIF-NO-FINAL-STATUS: no PASS|FAIL|PARTIAL verdict")
    return errs


VALIDATORS = {"plan": validate_plan, "run": validate_run,
              "verification": validate_verification}


# ---------------------------------------------------------------- schema mirror

def repo_root():
    return os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                         "..", ".."))


def compare_mirror(mirror_text, root_text, root_name):
    """Mirror == canonical content modulo the one generated-header line. (ok, reason)."""
    header = gen_header(root_name)
    if not mirror_text.startswith(header + "\n"):
        return False, "generated-header line missing/altered"
    body = mirror_text.split("\n", 1)[1]
    if body != root_text:
        return False, "mirror body != canonical root (byte-compare after header strip)"
    if canonical_home_marker(root_name) not in root_text:
        return False, "canonical root lacks its canonical-home declaration"
    return True, "ok"


def expected_mirror_text(name):
    root_name, _mirror_rel = MIRRORS[name]
    root_text = read_text(os.path.join(repo_root(), root_name))
    return gen_header(root_name) + "\n" + root_text


def mirror_status(name):
    root_name, mirror_rel = MIRRORS[name]
    root = repo_root()
    root_text = read_text(os.path.join(root, root_name))
    try:
        mirror_text = read_text(os.path.join(root, mirror_rel))
    except FileNotFoundError:
        return False, "mirror file absent: %s" % mirror_rel
    return compare_mirror(mirror_text, root_text, root_name)


def mirror_write():
    root = repo_root()
    written = []
    for name in ("plan", "run", "verification"):
        _root_name, mirror_rel = MIRRORS[name]
        dest = os.path.join(root, mirror_rel)
        with open(dest, "w", encoding="utf-8") as f:
            f.write(expected_mirror_text(name))
        written.append(mirror_rel)
    return written


def mirror_check_cli():
    errs = []
    for name in ("plan", "run", "verification"):
        ok, reason = mirror_status(name)
        if not ok:
            errs.append("MIRROR-DRIFT: %s — %s" % (name, reason))
    if errs:
        refuse(errs)
    print("VALID: plan/run/verification mirrors match their canonical roots")


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
        """Run thunk()->bool, turning any exception (e.g. a missing/unreadable fixture) into a
        graceful FAIL. Keeps a broken fixture from aborting the section before its footer."""
        try:
            cond = bool(thunk())
        except Exception as e:  # noqa: BLE001 — a broken fixture must FAIL, never abort the run
            self.ok("%s [EXC:%s]" % (label, e.__class__.__name__), False)
            return
        self.ok(label, cond)

    def done(self):
        print("[%s] %d PASS / %d FAIL" % (self.name, self.passed, self.failed))
        sys.exit(0 if self.failed == 0 else 1)


def _plans_dir():
    return os.path.join(repo_root(), ".harness", "plans")


SYNTH_PLAN = """# Plan: synthetic self-test plan

## Goal
g
## User Intent
feature
## Current Repo Findings
- Finding: f
  Source: s
## Relevant Files
| Path | Reason | Allowed to Edit |
|---|---|---|
| p | r | yes |
## Out of Scope
- x
## Proposed Changes
- Change: c
  Files: p
  Rationale: r
## Acceptance Criteria
- Criterion: c
  Verification Method: m
## Risks
| Risk | Severity | Mitigation |
|---|---|---|
| r | low | m |
## Assumptions
| Assumption | Confidence | How to Verify |
|---|---|---|
| a | high | v |
## Execution Tasks
- [ ] DMC-T001: t
  Files: p
  Notes: n
## Verification Commands
| Command | Reason | Required |
|---|---|---|
| c | r | yes |
## Approval Status
Status: DRAFT
Approver:
Approved At:
"""


def selftest_plan():
    t = ST("validate-plan")
    pd = _plans_dir()
    # P1/P2 reference the two tracked canonical plans (present in any clone); reads are guarded so
    # a missing/renamed plan FAILs loudly instead of aborting the section.
    rev2_path = os.path.join(pd, "dmc-v1-runtime-upgrade.md")
    stub_path = os.path.join(pd, "dmc-v0.5.4-workflow-state-machine.md")
    t.check("P1 Rev 2 runtime-upgrade plan ACCEPTED (incl. extended milestone block)",
            lambda: validate_plan(read_text(rev2_path)) == [])
    t.check("P2 negative control: v0.5.4 stub plan REFUSED",
            lambda: validate_plan(read_text(stub_path)) != [])
    t.check("P2b stub refusal names a missing required section",
            lambda: any(e.startswith("PLAN-MISSING-SECTION:")
                        for e in validate_plan(read_text(stub_path))))
    t.ok("P3 synthetic minimal plan ACCEPTED", validate_plan(SYNTH_PLAN) == [])
    no_approval = SYNTH_PLAN.replace("## Approval Status\n", "")
    t.ok("P4 negative control: missing '## Approval Status' REFUSED",
         any(e == "PLAN-MISSING-SECTION: Approval Status"
             for e in validate_plan(no_approval)))
    no_method = SYNTH_PLAN.replace("  Verification Method: m\n", "")
    t.ok("P5 negative control: acceptance without Verification Method REFUSED",
         any(e.startswith("PLAN-ACCEPTANCE-NO-METHOD") for e in validate_plan(no_method)))
    no_task = SYNTH_PLAN.replace("- [ ] DMC-T001: t", "- a prose task")
    t.ok("P6 negative control: no DMC-T task checkbox REFUSED",
         any(e.startswith("PLAN-NO-TASKS") for e in validate_plan(no_task)))
    t.ok("P7 determinism", validate_plan(SYNTH_PLAN) == validate_plan(SYNTH_PLAN))
    t.done()


SYNTH_RUN = """# Do-Me-Coding Run

run_id: synth-run
active_plan: .harness/plans/x.md
status: RUNNING
started_at: 2026-07-06
updated_at: 2026-07-06
session_ids: s1

## Approved File Scope
- p
## Tasks
| ID | Status | Evidence |
|---|---|---|
| DMC-T001 | DOING | e |
## Commands Run
| Command | Result | Evidence |
|---|---|---|
| c | PASS | e |
## Evidence Files
- e
## Verification Files
- v
## Open Risks
- r
"""


def selftest_run():
    # Fully synthetic: no dependency on `.harness/runs/current-run.md` (gitignored, local-only,
    # absent in a fresh clone / CI). The old real-instance coverage — a run carrying extra
    # non-required sections — is preserved by U2 below.
    t = ST("validate-run")
    t.ok("U1 synthetic minimal run ACCEPTED", validate_run(SYNTH_RUN) == [])
    extra = SYNTH_RUN + "## Not-Edit (fail-closed outside scope)\n- x\n"
    t.ok("U2 run with an extra non-required section ACCEPTED (extras tolerated)",
         validate_run(extra) == [])
    no_status = SYNTH_RUN.replace("status: RUNNING\n", "")
    t.ok("U3 negative control: missing status field REFUSED",
         any(e == "RUN-MISSING-FIELD: status" for e in validate_run(no_status)))
    bad_status = SYNTH_RUN.replace("status: RUNNING", "status: WOBBLING")
    t.ok("U4 negative control: bad status value REFUSED",
         any(e.startswith("RUN-BAD-STATUS") for e in validate_run(bad_status)))
    no_section = SYNTH_RUN.replace("## Open Risks\n- r\n", "")
    t.ok("U5 negative control: missing '## Open Risks' section REFUSED",
         any(e == "RUN-MISSING-SECTION: Open Risks" for e in validate_run(no_section)))
    bad_title = SYNTH_RUN.replace("# Do-Me-Coding Run", "# Something Else")
    t.ok("U6 negative control: wrong title REFUSED",
         any(e.startswith("RUN-NO-TITLE") for e in validate_run(bad_title)))
    t.done()


SYNTH_VERIF = """# Verification Report

## Run ID
r
## Plan
p
## Changed Files
- p: reason
## Commands Run
| Command | Result | Reason | Output Summary |
|---|---|---|---|
| c | PASS | r | s |
## Manual Checks
| Check | Result | Notes |
|---|---|---|
| c | PASS | n |
## Scope Review
Result: PASS

Notes:
## Package / Env / Migration Review
Package files changed: no
Env files changed: no
Migration files changed: no

Notes:
## Unresolved Risks
- none
## Final Status
PASS
"""


def selftest_verification():
    t = ST("validate-verification")
    # V1 references a tracked verification report (present in any clone); read is guarded so a
    # missing/renamed file FAILs loudly instead of aborting the section.
    v_path = os.path.join(repo_root(), ".harness", "verification", "dmc-v0.2-worker-bridge.md")
    t.check("V1 dmc-v0.2-worker-bridge.md ACCEPTED",
            lambda: validate_verification(read_text(v_path)) == [])
    t.ok("V2 synthetic minimal verification ACCEPTED", validate_verification(SYNTH_VERIF) == [])
    no_final = SYNTH_VERIF.replace("## Final Status\nPASS\n", "")
    t.ok("V3 negative control: missing '## Final Status' REFUSED",
         any(e == "VERIF-MISSING-SECTION: Final Status"
             for e in validate_verification(no_final)))
    no_result = SYNTH_VERIF.replace("Result: PASS\n", "")
    t.ok("V4 negative control: Scope Review without Result REFUSED",
         any(e.startswith("VERIF-SCOPE-NO-RESULT") for e in validate_verification(no_result)))
    no_pem = SYNTH_VERIF.replace("Env files changed: no\n", "")
    t.ok("V5 negative control: incomplete Package/Env/Migration REFUSED",
         any(e.startswith("VERIF-PEM-INCOMPLETE") for e in validate_verification(no_pem)))
    empty_final = SYNTH_VERIF.replace("## Final Status\nPASS\n", "## Final Status\n\n")
    t.ok("V6 negative control: empty Final Status REFUSED",
         any(e.startswith("VERIF-NO-FINAL-STATUS")
             for e in validate_verification(empty_final)))
    t.done()


def _root_text(name):
    root_name, _ = MIRRORS[name]
    return root_name, read_text(os.path.join(repo_root(), root_name))


def selftest_mirror():
    # All reads (tracked root schemas + generated mirrors) go through graceful `check`, so a
    # missing/renamed root or mirror FAILs loudly instead of aborting before the footer.
    t = ST("schemas-mirror")
    for name in ("plan", "run", "verification"):
        t.check("M-%s on-disk mirror == canonical modulo header" % name,
                lambda n=name: mirror_status(n)[0])

    def reconstructed_ok(n):
        root_name, root_text = _root_text(n)
        return compare_mirror(gen_header(root_name) + "\n" + root_text, root_text, root_name)[0]

    def tampered_refused(n):
        root_name, root_text = _root_text(n)
        return not compare_mirror(gen_header(root_name) + "\n" + root_text + "DRIFT\n",
                                  root_text, root_name)[0]

    def header_refused(n):
        root_name, root_text = _root_text(n)
        return not compare_mirror(root_text, root_text, root_name)[0]

    def declares_home(n):
        root_name, root_text = _root_text(n)
        return canonical_home_marker(root_name) in root_text

    for name in ("plan", "run", "verification"):
        t.check("M-%s reconstructed mirror validates" % name,
                lambda n=name: reconstructed_ok(n))
        t.check("M-%s negative control: tampered body REFUSED" % name,
                lambda n=name: tampered_refused(n))
        t.check("M-%s negative control: missing generated header REFUSED" % name,
                lambda n=name: header_refused(n))
    for name in ("plan", "run", "verification"):
        t.check("M-%s root declares canonical home" % name,
                lambda n=name: declares_home(n))
    t.done()


SELFTESTS = {"plan": selftest_plan, "run": selftest_run,
             "verification": selftest_verification, "mirror": selftest_mirror}


# ------------------------------------------------------------------------ main

def main():
    ap = argparse.ArgumentParser(prog="dmc-instance-validate")
    ap.add_argument("command", choices=["plan", "run", "verification", "mirror"])
    ap.add_argument("--validate", metavar="FILE")
    ap.add_argument("--self-test", action="store_true")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--write", action="store_true")
    a = ap.parse_args()

    if a.self_test:
        SELFTESTS[a.command]()
        return

    if a.command == "mirror":
        if a.write:
            for rel in mirror_write():
                print("wrote %s" % rel)
            return
        # default / --check
        mirror_check_cli()
        return

    if not a.validate:
        die("%s requires --validate FILE (or --self-test)" % a.command, 2)
    try:
        text = read_text(a.validate)
    except FileNotFoundError:
        refuse(["%s-UNREADABLE: file not found" % a.command.upper()[:5]])
    except (OSError, UnicodeError) as e:
        refuse(["%s-UNREADABLE: %s" % (a.command.upper()[:5], e.__class__.__name__)])
    errs = VALIDATORS[a.command](text)
    if errs:
        refuse(errs)
    print("VALID: %s conforms to %s" % (a.validate, SCHEMA_IDS[a.command]))


if __name__ == "__main__":
    main()
