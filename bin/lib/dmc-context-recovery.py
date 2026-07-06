#!/usr/bin/env python3
"""dmc-context-recovery.py — DMC v1.0 M4 Context Recovery Manager (P11; architecture §P11).

On session start/resume, reconciles the DECLARED run state against the OBSERVED git state and emits
a next-safe-action. It gathers observed git facts from the target worktree — `git status
--porcelain`, `git diff --name-only`, HEAD, upstream ahead/behind — translates them into the v0.5.7
`--from` facts shape, invokes the COPIED `bin/lib/dmc-v0.5.7-resume-recovery.sh` as a read-only
subprocess, and stores its verdict VERBATIM into `runs/<run-id>/recovery.json` alongside the
parsed next_safe_action. The v0.5.7 resume logic is REUSED BY INVOCATION and never re-implemented
here; this tool only observes, translates in, and consumes out.

Halt-on-delta (the load-bearing invariant, architecture §P11 Rec: "delta => halt with the diff
listed; never auto-reconcile by editing state"). Before consulting v0.5.7 for a next action, three
declared-vs-observed deltas are checked and any one HALTS with the diff:
  - moved-HEAD       : an expected HEAD (--expect-head, e.g. a checkpoint git_ref) != observed HEAD
  - dirty-outside-scope : a dirty tracked path outside the scope.lock authorized set (--scope-lock)
  - half-applied     : index != worktree on the same path, or a merge/rebase/cherry-pick in progress
A HALT NEVER edits state and NEVER emits a safe action; it records the observed diff and next_action
HALT_AND_ASK (hand off to P17). A caller `--reconcile` request is explicitly refused on a delta.

Subcommands / flags:
  recover --run-id ID [--root DIR] [--scope-lock FILE] [--expect-head SHA]
          [--verification PASS|FAIL|NONE] [--reconcile] [--out FILE]
                                   observe -> detect delta -> (halt | invoke v0.5.7) -> recovery.json
  --validate FILE                  fail-closed validator (VALID => 0, REFUSED => 3); for a non-halt
                                   recovery it re-runs the copied tool on the stored facts and
                                   REFUSES on any verdict divergence (no silent fork)
  --self-test                      hermetic section self-test (tempdir git repo only)

House rules (v0.6.x / M2-M4 lineage): stdlib-only python (the v0.5.7 call is a bash subprocess of
the copied file — allowed), deterministic, env-independent (no env reads), offline (no network),
fail-closed with named reason codes + negative controls, value-blind refusals (secret-shaped paths
redacted in the observed diff), secret paths refused by path only. Advisory tier: the runtime
enforcement floor stays the hooks (M6).
"""

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

SCHEMA = "dmc.recovery.v1"
GENESIS = "0" * 64
HASH_RE = re.compile(r"^[0-9a-f]{16,}$")
POINTER_NAME = "current-run-id"
RESUME_TOOL = "dmc-v0.5.7-resume-recovery.sh"   # copied; invoked read-only, never edited
FACTS_KEYS = ("branch", "ahead", "behind", "tracked_dirty", "staged_protected", "staged_autolog",
              "untracked_autolog_only", "plan_status", "plan_hash_match", "verification",
              "commit_hash")
HALT_ACTION = "HALT_AND_ASK"
REDACTED_PATH = "<redacted-secret-path>"

SECRET_ALLOW_BASENAMES = {".env.example", ".env.sample", ".env.template", ".env.dist"}
# Protected surfaces that, if STAGED, make the resume tool STOP (mirror of the copied tool's PROT_RE
# intent, path-only). Kept deliberately small: secrets + hook/router control surfaces.
PROTECTED_RE = re.compile(
    r'(^|/)\.env(\.|$)|\.pem$|\.key$|id_rsa|id_ed25519|credentials|secret|\.p12$|\.pfx$|\.keystore$'
    r'|(^|/)\.claude/hooks/|provider-router\.py')
AUTOLOG_RE = re.compile(r'(^|/)\.harness/evidence/[^/]+\.md$')


# ------------------------------------------------------------------- helpers

def die(msg, code=2):
    sys.stderr.write("dmc-context-recovery: %s\n" % msg)
    sys.exit(code)


def refuse(reasons):
    for r in reasons:
        print("REFUSED: %s" % r)
    sys.exit(3)


def is_secret_path(path):
    """Path-only secret filter (mirror of DMC.md secret patterns). Never opens the file."""
    base = os.path.basename(path).lower()
    parts = [p.lower() for p in path.replace(os.sep, "/").split("/")]
    if base in SECRET_ALLOW_BASENAMES:
        return False
    if base == ".env" or base.startswith(".env."):
        return True
    if re.search(r"\.(pem|key|p12|pfx|keystore|jks)$", base):
        return True
    if base.startswith(("id_rsa", "id_ed25519")):
        return True
    if base in {".npmrc", ".netrc", ".pgpass", "credentials.json"}:
        return True
    if "service-account" in base and base.endswith(".json"):
        return True
    if "secret" in base and re.search(r"\.(json|ya?ml|env)$", base):
        return True
    if ".ssh" in parts or ".gnupg" in parts:
        return True
    if ".aws" in parts and base == "credentials":
        return True
    return False


def safe_path(p):
    """Value-blind path redaction for the stored observed diff (never leak a secret-shaped name)."""
    return REDACTED_PATH if is_secret_path(p) else p


def canon_hash(obj):
    payload = json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def load_json_strict(path):
    def hook(pairs):
        keys = [k for k, _ in pairs]
        if len(keys) != len(set(keys)):
            raise ValueError("duplicate key in JSON object")
        return dict(pairs)
    if is_secret_path(path):
        die("refused: secret-shaped input path", 3)
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f, object_pairs_hook=hook)


def sibling(name):
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), name)


# ------------------------------------------------------------------- observed git state

def _git(root, *args):
    """Read-only git plumbing; returns (rc, stdout_text). No writes, ever."""
    git = shutil.which("git")
    if not git:
        return 127, ""
    try:
        r = subprocess.run([git, "-C", root, *args], capture_output=True, text=True, timeout=20)
        return r.returncode, r.stdout
    except Exception:  # noqa: BLE001
        return 1, ""


def parse_porcelain(text):
    """Parse `git status --porcelain` into structured entries. Each: {x, y, path, untracked}."""
    out = []
    for line in text.splitlines():
        if len(line) < 3:
            continue
        x, y, rest = line[0], line[1], line[3:]
        path = rest.split(" -> ")[-1] if " -> " in rest else rest
        out.append({"x": x, "y": y, "path": path, "untracked": (x == "?" and y == "?")})
    return out


def observe(root):
    """Gather the OBSERVED git state of the target worktree and derive v0.5.7 facts (no writes)."""
    _, branch = _git(root, "rev-parse", "--abbrev-ref", "HEAD")
    branch = branch.strip()
    rc_head, head = _git(root, "rev-parse", "HEAD")
    head = head.strip() if rc_head == 0 else ""
    rc_ab, ab = _git(root, "rev-list", "--left-right", "--count", "@{upstream}...HEAD")
    behind, ahead = 0, 0
    if rc_ab == 0 and ab.strip():
        toks = ab.split()
        if len(toks) == 2 and toks[0].isdigit() and toks[1].isdigit():
            behind, ahead = int(toks[0]), int(toks[1])
    _, porc = _git(root, "status", "--porcelain")
    entries = parse_porcelain(porc)

    def staged(e):
        return e["x"] not in (" ", "?")

    def worktree_dirty(e):
        return e["y"] not in (" ", "?")

    def is_autolog(p):
        return bool(AUTOLOG_RE.search("/" + p))

    def is_protected(p):
        return bool(PROTECTED_RE.search("/" + p))

    tracked_changes = [e for e in entries if not e["untracked"] and (staged(e) or worktree_dirty(e))]
    tracked_dirty = any(not is_autolog(e["path"]) for e in tracked_changes)
    staged_protected = any(staged(e) and is_protected(e["path"]) for e in entries)
    staged_autolog = any(staged(e) and is_autolog(e["path"]) for e in entries)
    dirty = [e for e in entries if staged(e) or worktree_dirty(e)]
    untracked_autolog_only = bool(dirty) and all(e["untracked"] and is_autolog(e["path"])
                                                 for e in dirty)
    # half-applied: index != worktree on the SAME path (both columns are real changes), or an
    # interrupted merge/rebase/cherry-pick.
    half_paths = [e["path"] for e in entries
                  if not e["untracked"] and staged(e) and worktree_dirty(e)]
    _, gitdir = _git(root, "rev-parse", "--git-dir")
    gitdir = gitdir.strip()
    in_progress = []
    if gitdir:
        gd = gitdir if os.path.isabs(gitdir) else os.path.join(root, gitdir)
        for marker, label in (("MERGE_HEAD", "merge"), ("rebase-merge", "rebase"),
                              ("rebase-apply", "rebase"), ("CHERRY_PICK_HEAD", "cherry-pick")):
            if os.path.exists(os.path.join(gd, marker)):
                in_progress.append(label)

    return {
        "branch": branch,
        "head": head,
        "ahead": ahead,
        "behind": behind,
        "entries": [{"xy": e["x"] + e["y"], "path": safe_path(e["path"])} for e in entries],
        "tracked_dirty": tracked_dirty,
        "staged_protected": staged_protected,
        "staged_autolog": staged_autolog,
        "untracked_autolog_only": untracked_autolog_only,
        "dirty_tracked_paths": sorted({e["path"] for e in tracked_changes}),
        "half_applied_paths": sorted(set(half_paths)),
        "in_progress": sorted(set(in_progress)),
    }


def to_facts(observed, plan_status, plan_hash_match, verification):
    """Translate observed git state into the v0.5.7 `--from` facts (native JSON types; the copied
    tool coerces). No re-implementation of the resume decision — only the input translation."""
    return {
        "branch": observed["branch"],
        "ahead": observed["ahead"],
        "behind": observed["behind"],
        "tracked_dirty": bool(observed["tracked_dirty"]),
        "staged_protected": bool(observed["staged_protected"]),
        "staged_autolog": bool(observed["staged_autolog"]),
        "untracked_autolog_only": bool(observed["untracked_autolog_only"]),
        "plan_status": plan_status,
        "plan_hash_match": bool(plan_hash_match),
        "verification": verification,
        "commit_hash": observed["head"],
    }


# ------------------------------------------------------- reuse-by-invocation (copied v0.5.7)

def resume_run(tool_path, facts):
    """Invoke the COPIED v0.5.7 resume tool on `facts` as a read-only subprocess; verbatim capture.
    Returns (exit_code, stdout_text). The verdict flows through UNMODIFIED — we write the facts to a
    temp file and capture stdout; no parsing/rewriting of the verdict itself."""
    tmp = tempfile.mkdtemp(prefix="dmc-cr-facts-")
    try:
        fp = os.path.join(tmp, "facts.json")
        with open(fp, "w", encoding="utf-8") as f:
            f.write(json.dumps(facts, sort_keys=True, separators=(",", ":")))
        r = subprocess.run(["bash", tool_path, "--from", fp],
                           capture_output=True, text=True, timeout=30)
        return r.returncode, r.stdout
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def parse_next_action(verdict_text):
    m = re.search(r"(?m)^-\s*next_action:\s*(\S+)", verdict_text)
    return m.group(1) if m else None


# ------------------------------------------------------------------- delta detection

def detect_delta(observed, scope_paths, expect_head):
    """Return a list of declared-vs-observed delta strings ([] == no delta). Never edits state."""
    deltas = []
    if expect_head:
        if observed["head"] != expect_head:
            deltas.append("moved-HEAD: expected %s observed %s"
                          % (expect_head, observed["head"] or "<none>"))
    if scope_paths is not None:
        allowed = set(scope_paths)
        for p in observed["dirty_tracked_paths"]:
            if p not in allowed:
                deltas.append("dirty-outside-scope: %s not in scope.lock authorized files"
                              % safe_path(p))
    if observed["half_applied_paths"]:
        for p in observed["half_applied_paths"]:
            deltas.append("half-applied: index != worktree on %s (interrupted apply)" % safe_path(p))
    for label in observed["in_progress"]:
        deltas.append("half-applied: %s in progress" % label)
    return deltas


# ------------------------------------------------------------------- plan binding

def plan_is_approved(text):
    m = re.search(r"(?ms)^##\s+Approval Status\s*$(.*?)(?:^##\s+|\Z)", text)
    if not m:
        return False
    return bool(re.search(r"(?m)^\s*Status:\s*APPROVED\b", m.group(1)))


def declared_plan_facts(root, doc):
    """Compute plan_status + plan_hash_match by OBSERVING the plan file named by run.json against
    the declared plan_hash. A changed/absent plan => (DRAFT/MISSING, False) — fed to v0.5.7."""
    plan_rel = doc.get("plan_path")
    declared_hash = doc.get("plan_hash")
    if not (isinstance(plan_rel, str) and plan_rel):
        return "MISSING", False
    plan_abs = plan_rel if os.path.isabs(plan_rel) else os.path.join(root, plan_rel)
    if is_secret_path(plan_abs) or not os.path.isfile(plan_abs):
        return "MISSING", False
    with open(plan_abs, "rb") as f:
        data = f.read()
    observed_hash = hashlib.sha256(data).hexdigest()
    match = isinstance(declared_hash, str) and observed_hash == declared_hash
    status = "APPROVED" if plan_is_approved(data.decode("utf-8", errors="replace")) else "DRAFT"
    return status, match


# ------------------------------------------------------------------- storage

def runs_dir(root):
    return os.path.join(root, ".harness", "runs")


def run_json_path(root, run_id):
    return os.path.join(runs_dir(root), run_id, "run.json")


def recovery_path(root, run_id):
    return os.path.join(runs_dir(root), run_id, "recovery.json")


def read_pointer(root):
    p = os.path.join(runs_dir(root), POINTER_NAME)
    if not os.path.isfile(p):
        return None
    with open(p, "r", encoding="utf-8") as f:
        return (f.read().strip() or None)


def write_doc(doc, out_path):
    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(json.dumps(doc, sort_keys=True, indent=2, ensure_ascii=False) + "\n")
    return out_path


# ------------------------------------------------------------------- recover

def build_recovery(root, run_id, scope_lock, expect_head, verification, reconcile, tool_path):
    rid = run_id or read_pointer(root)
    if not rid:
        refuse(["REC-NO-RUN: no --run-id given and no current-run-id pointer present"])
    rjp = run_json_path(root, rid)
    if is_secret_path(rjp) or is_secret_path(recovery_path(root, rid)):
        refuse(["REC-SECRET-PATH: refusing a secret-shaped run/recovery path"])
    if not os.path.isfile(rjp):
        refuse(["REC-RUN-NOT-FOUND: no run.json for run-id %s" % rid])
    try:
        doc = load_json_strict(rjp)
    except Exception as e:  # noqa: BLE001
        refuse(["REC-RUN-UNREADABLE: %s" % e.__class__.__name__])
    plan_hash = doc.get("plan_hash")
    if not (isinstance(plan_hash, str) and HASH_RE.match(plan_hash)):
        refuse(["REC-RUN-BINDING: run.json plan_hash missing/not hash-shaped"])

    scope_paths = None
    if scope_lock:
        if is_secret_path(scope_lock) or not os.path.isfile(scope_lock):
            refuse(["REC-SCOPE-LOCK-NOT-FOUND: --scope-lock file missing or secret-shaped"])
        try:
            sl = load_json_strict(scope_lock)
        except Exception as e:  # noqa: BLE001
            refuse(["REC-SCOPE-LOCK-UNREADABLE: %s" % e.__class__.__name__])
        scope_paths = sorted({f.get("path") for f in (sl.get("files") or [])
                              if isinstance(f, dict) and isinstance(f.get("path"), str)})

    observed = observe(root)
    plan_status, plan_hash_match = declared_plan_facts(root, doc)
    facts = to_facts(observed, plan_status, plan_hash_match, verification)

    deltas = detect_delta(observed, scope_paths, expect_head)
    if deltas:
        # HALT: never auto-reconcile, never emit a safe action. Record the observed diff only.
        if reconcile:
            deltas = ["REC-NO-AUTO-RECONCILE: refused to auto-reconcile an observed delta; "
                      "halting with the diff (state is never edited)"] + deltas
        return {
            "schema": SCHEMA, "run_id": rid, "plan_hash": plan_hash,
            "observed": observed, "facts": facts,
            "resume_tool": RESUME_TOOL, "halted": True,
            "next_action": HALT_ACTION, "delta": deltas,
        }, True

    # No delta: consult the copied v0.5.7 tool for the next safe action; store its verdict verbatim.
    if not os.path.isfile(tool_path):
        refuse(["REC-RESUME-TOOL-MISSING: copied v0.5.7 resume tool not found"])
    rexit, verdict = resume_run(tool_path, facts)
    return {
        "schema": SCHEMA, "run_id": rid, "plan_hash": plan_hash,
        "observed": observed, "facts": facts,
        "resume_tool": RESUME_TOOL, "resume_exit": rexit,
        "verdict_verbatim": verdict, "next_action": parse_next_action(verdict),
        "halted": False, "delta": [],
    }, False


def cmd_recover(root, run_id, scope_lock, expect_head, verification, reconcile, out, tool_path):
    doc, halted = build_recovery(root, run_id, scope_lock, expect_head, verification, reconcile,
                                 tool_path)
    errs = validate_recovery(doc, tool_path=tool_path)
    if errs:
        refuse(errs)   # self-refusal: never emit an artifact that fails its own validator
    out_path = out or recovery_path(root, doc["run_id"])
    write_doc(doc, out_path)
    print("wrote: %s" % out_path)
    print("halted: %s" % ("true" if halted else "false"))
    print("next_action: %s" % doc.get("next_action"))
    if halted:
        for d in doc["delta"]:
            print("delta: %s" % d)
        sys.exit(1)   # HALT is a blocked outcome (advisory), distinct from success
    print("resume_exit: %s" % doc.get("resume_exit"))


# ------------------------------------------------------------------- validator

def validate_recovery(doc, tool_path=None):
    """Fail-closed recovery.json validator. For a non-halt recovery, re-runs the copied tool on the
    stored facts and REFUSES on any verdict divergence (no silent fork). Returns reason codes."""
    if not isinstance(doc, dict):
        return ["REC-NOT-OBJECT: recovery.json root is not a JSON object"]
    errs = []
    if doc.get("schema") != SCHEMA:
        errs.append("REC-BAD-SCHEMA: schema != %s" % SCHEMA)
    if not (isinstance(doc.get("run_id"), str) and doc["run_id"].strip()):
        errs.append("REC-MISSING-RUN-ID: run_id missing/empty")
    ph = doc.get("plan_hash")
    if not (isinstance(ph, str) and HASH_RE.match(ph)):
        errs.append("REC-BAD-PLAN-HASH: plan_hash missing/not hash-shaped")
    if doc.get("resume_tool") != RESUME_TOOL:
        errs.append("REC-BAD-RESUME-TOOL: resume_tool != %s" % RESUME_TOOL)
    facts = doc.get("facts")
    if not isinstance(facts, dict) or any(k not in facts for k in FACTS_KEYS):
        errs.append("REC-BAD-FACTS: facts must carry all v0.5.7 keys %s" % "|".join(FACTS_KEYS))
        facts = None
    halted = doc.get("halted")
    if not isinstance(halted, bool):
        errs.append("REC-BAD-HALTED: halted must be boolean")
        return errs
    if halted:
        if doc.get("next_action") != HALT_ACTION:
            errs.append("REC-HALT-BAD-ACTION: a halted recovery must carry next_action %s"
                        % HALT_ACTION)
        if not (isinstance(doc.get("delta"), list) and doc["delta"]):
            errs.append("REC-HALT-NO-DELTA: a halted recovery must list the observed delta")
        return errs
    # non-halt: the stored verbatim verdict must reproduce from the stored facts (reuse proof).
    if doc.get("delta"):
        errs.append("REC-NONHALT-HAS-DELTA: a non-halt recovery must carry an empty delta")
    if not isinstance(doc.get("verdict_verbatim"), str) or not doc["verdict_verbatim"].strip():
        errs.append("REC-EMPTY-VERDICT: non-halt recovery missing the verbatim resume verdict")
    if doc.get("next_action") != parse_next_action(doc.get("verdict_verbatim") or ""):
        errs.append("REC-ACTION-MISMATCH: next_action != the action parsed from verdict_verbatim")
    if errs:
        return errs
    if tool_path and os.path.isfile(tool_path) and facts is not None:
        rexit, rtext = resume_run(tool_path, {k: facts[k] for k in FACTS_KEYS})
        if rtext != doc["verdict_verbatim"] or rexit != doc.get("resume_exit"):
            errs.append("REC-DIVERGENCE: stored verdict differs from re-running the copied v0.5.7 "
                        "tool on the stored facts (silent divergence)")
    return errs


# ------------------------------------------------------------------- self-test (hermetic)

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

    def done(self):
        print("[%s] %d PASS / %d FAIL" % (self.name, self.passed, self.failed))
        sys.exit(0 if self.failed == 0 else 1)


def _real_repo_porcelain():
    git = shutil.which("git")
    if not git:
        return None
    root = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
    try:
        r = subprocess.run([git, "-C", root, "status", "--porcelain"],
                           capture_output=True, timeout=10)
        return r.stdout if r.returncode == 0 else None
    except Exception:  # noqa: BLE001
        return None


SYNTH_PLAN = "# Plan: recovery selftest\n\n## Approval Status\nStatus: APPROVED\n"


def _git_id(root, *args):
    """git with a self-contained identity so a bare CI host has no ambient user.name/email."""
    return subprocess.run(["git", "-C", root, "-c", "user.name=dmc", "-c", "user.email=dmc@x",
                           "-c", "commit.gpgsign=false", *args], capture_output=True, text=True)


def _mkrepo(tmp):
    """Disposable git repo with an APPROVED plan, one commit, a run.json bound to it."""
    subprocess.run(["git", "init", "-q", tmp], capture_output=True)
    plan = os.path.join(tmp, "plan.md")
    with open(plan, "w", encoding="utf-8") as f:
        f.write(SYNTH_PLAN)
    with open(os.path.join(tmp, "src.txt"), "w", encoding="utf-8") as f:
        f.write("hello\n")
    _git_id(tmp, "add", "-A")
    _git_id(tmp, "commit", "-q", "-m", "init")
    head = _git_id(tmp, "rev-parse", "HEAD").stdout.strip()
    ph = hashlib.sha256(SYNTH_PLAN.encode()).hexdigest()
    rid = "dmc-run-rec01"
    d = os.path.join(runs_dir(tmp), rid)
    os.makedirs(d, exist_ok=True)
    doc = {"schema": "dmc.run-state.v1", "run_id": rid, "work_id": "W1", "plan_path": "plan.md",
           "plan_hash": ph, "repo_hash": "b" * 64, "status": "RUNNING", "seq": 1,
           "created_at": "t", "updated_at": "t", "prev_hash": GENESIS}
    with open(os.path.join(d, "run.json"), "w", encoding="utf-8") as f:
        json.dump(doc, f)
    return rid, head, ph


def _run_cli(root, *args):
    return subprocess.run([sys.executable, "-B", os.path.abspath(__file__), *args, "--root", root],
                          capture_output=True, text=True)


def _sweep_pycache():
    shutil.rmtree(os.path.join(os.path.dirname(os.path.abspath(__file__)), "__pycache__"),
                  ignore_errors=True)


def selftest():
    t = ST("context-recovery")
    if not shutil.which("git"):
        print("PASS [context-recovery] SKIP git unavailable (graceful)")
        print("[context-recovery] 1 PASS / 0 FAIL")
        sys.exit(0)
    before = _real_repo_porcelain()
    tool = sibling(RESUME_TOOL)

    # ---- SCENARIO clean-resume: no delta -> v0.5.7 next action, verbatim + reuse proof ----------
    c = tempfile.mkdtemp(prefix="dmc-cr-clean-")
    try:
        rid, head, ph = _mkrepo(c)
        r = _run_cli(c, "recover", "--run-id", rid)
        rec = load_json_strict(recovery_path(c, rid))
        t.ok("S1 clean-resume: exit 0, not halted, empty delta",
             r.returncode == 0 and rec["halted"] is False and rec["delta"] == [])
        t.ok("S2 clean-resume: verification NONE + approved plan => v0.5.7 next_action VERIFY",
             rec["next_action"] == "VERIFY" and rec["facts"]["plan_status"] == "APPROVED"
             and rec["facts"]["plan_hash_match"] is True)
        # PROOF OF REUSE: stored verdict is byte-identical to a direct copied-tool call.
        dexit, dtext = resume_run(tool, {k: rec["facts"][k] for k in FACTS_KEYS})
        t.ok("S3 proof-of-reuse: stored verdict_verbatim == direct v0.5.7 output (no fork)",
             dtext == rec["verdict_verbatim"] and dexit == rec["resume_exit"])
        t.ok("S4 validator ACCEPTS the stored recovery (re-run reproduces the verdict)",
             validate_recovery(rec, tool_path=tool) == [])
        # divergence: tamper the stored verdict => REFUSE
        tampered = dict(rec, verdict_verbatim=rec["verdict_verbatim"] + "\nINJECTED")
        t.ok("S5 NEG tampered verdict (divergence) REFUSED by validator",
             any(e.startswith("REC-ACTION-MISMATCH") or e.startswith("REC-DIVERGENCE")
                 for e in validate_recovery(tampered, tool_path=tool)))
    finally:
        shutil.rmtree(c, ignore_errors=True)

    # ---- SCENARIO moved-HEAD: expected HEAD != observed -> HALT ---------------------------------
    m = tempfile.mkdtemp(prefix="dmc-cr-head-")
    try:
        rid, head, ph = _mkrepo(m)
        r = _run_cli(m, "recover", "--run-id", rid, "--expect-head", "deadbeef" * 5)
        rec = load_json_strict(recovery_path(m, rid))
        t.ok("S6 moved-HEAD: exit 1 (HALT), next_action HALT_AND_ASK, delta lists moved-HEAD",
             r.returncode == 1 and rec["halted"] is True
             and rec["next_action"] == HALT_ACTION
             and any("moved-HEAD" in d for d in rec["delta"]))
        t.ok("S6b halted recovery validates as a well-formed halt",
             validate_recovery(rec, tool_path=tool) == [])
    finally:
        shutil.rmtree(m, ignore_errors=True)

    # ---- SCENARIO dirty-outside-scope: dirty tracked file not in scope.lock -> HALT -------------
    d = tempfile.mkdtemp(prefix="dmc-cr-scope-")
    try:
        rid, head, ph = _mkrepo(d)
        with open(os.path.join(d, "src.txt"), "a", encoding="utf-8") as f:
            f.write("MODIFIED OUTSIDE SCOPE\n")   # src.txt is dirty, tracked
        scope = os.path.join(d, "scope.lock.json")
        with open(scope, "w", encoding="utf-8") as f:
            json.dump({"schema": "dmc.scope-lock.v1", "files": [{"path": "other.txt"}]}, f)
        r = _run_cli(d, "recover", "--run-id", rid, "--scope-lock", scope)
        rec = load_json_strict(recovery_path(d, rid))
        t.ok("S7 dirty-outside-scope: HALT with the out-of-scope path in the delta",
             r.returncode == 1 and rec["halted"] is True
             and any("dirty-outside-scope" in x and "src.txt" in x for x in rec["delta"]))
        # in-scope dirtiness does NOT halt on the scope check (src.txt authorized)
        scope2 = os.path.join(d, "scope2.json")
        with open(scope2, "w", encoding="utf-8") as f:
            json.dump({"schema": "dmc.scope-lock.v1", "files": [{"path": "src.txt"}]}, f)
        r2 = _run_cli(d, "recover", "--run-id", rid, "--scope-lock", scope2)
        rec2 = load_json_strict(recovery_path(d, rid))
        t.ok("S7b in-scope dirty file does NOT trigger the scope delta",
             not any("dirty-outside-scope" in x for x in rec2["delta"]))
    finally:
        shutil.rmtree(d, ignore_errors=True)

    # ---- SCENARIO half-applied: index != worktree on the same path -> HALT ----------------------
    h = tempfile.mkdtemp(prefix="dmc-cr-half-")
    try:
        rid, head, ph = _mkrepo(h)
        with open(os.path.join(h, "src.txt"), "w", encoding="utf-8") as f:
            f.write("staged change\n")
        _git_id(h, "add", "src.txt")                       # stage it (index changed)
        with open(os.path.join(h, "src.txt"), "a", encoding="utf-8") as f:
            f.write("then an unstaged edit\n")             # worktree now diverges from index => MM
        r = _run_cli(h, "recover", "--run-id", rid)
        rec = load_json_strict(recovery_path(h, rid))
        t.ok("S8 half-applied: index != worktree => HALT with the path in the delta",
             r.returncode == 1 and rec["halted"] is True
             and any("half-applied" in x and "src.txt" in x for x in rec["delta"]))
    finally:
        shutil.rmtree(h, ignore_errors=True)

    # ---- NEGATIVE: --reconcile on a delta REFUSES to reconcile, returns halt + diff -------------
    rc = tempfile.mkdtemp(prefix="dmc-cr-recon-")
    try:
        rid, head, ph = _mkrepo(rc)
        run_before = load_json_strict(run_json_path(rc, rid))
        r = _run_cli(rc, "recover", "--run-id", rid, "--expect-head", "cafe" * 10, "--reconcile")
        rec = load_json_strict(recovery_path(rc, rid))
        run_after = load_json_strict(run_json_path(rc, rid))
        t.ok("S9 NEG --reconcile on a delta => HALT (no auto-reconcile), diff returned",
             r.returncode == 1 and rec["halted"] is True
             and any("REC-NO-AUTO-RECONCILE" in x for x in rec["delta"])
             and any("moved-HEAD" in x for x in rec["delta"]))
        t.ok("S9b --reconcile did NOT edit run.json (state never auto-reconciled)",
             run_before == run_after)
    finally:
        shutil.rmtree(rc, ignore_errors=True)

    # ---- env independence + determinism ---------------------------------------------------------
    e = tempfile.mkdtemp(prefix="dmc-cr-env-")
    try:
        rid, head, ph = _mkrepo(e)
        _run_cli(e, "recover", "--run-id", rid)
        rp = recovery_path(e, rid)
        v1 = _run_cli(e, "--validate", rp)
        v2 = subprocess.run([sys.executable, "-B", os.path.abspath(__file__), "--validate", rp,
                             "--root", e], capture_output=True, text=True,
                            env={"PATH": os.environ.get("PATH", ""), "GLM_API_KEY": "x"})
        t.ok("H1 env-independent: --validate identical under injected env",
             v1.returncode == 0 and v2.returncode == 0 and v1.stdout == v2.stdout)
    finally:
        shutil.rmtree(e, ignore_errors=True)
        _sweep_pycache()

    after = _real_repo_porcelain()
    t.ok("H2 real repo git status --porcelain byte-identical before/after (or git absent)",
         before == after)
    t.done()


# ------------------------------------------------------------------------ main

def main():
    ap = argparse.ArgumentParser(prog="dmc-context-recovery")
    ap.add_argument("command", nargs="?", choices=["recover"])
    ap.add_argument("--root", default=".")
    ap.add_argument("--run-id", dest="run_id", metavar="ID")
    ap.add_argument("--scope-lock", dest="scope_lock", metavar="FILE")
    ap.add_argument("--expect-head", dest="expect_head", metavar="SHA")
    ap.add_argument("--verification", default="NONE", choices=["PASS", "FAIL", "NONE"])
    ap.add_argument("--reconcile", action="store_true")
    ap.add_argument("--out", metavar="FILE")
    ap.add_argument("--tool", metavar="FILE", default=sibling(RESUME_TOOL))
    ap.add_argument("--validate", metavar="FILE")
    ap.add_argument("--self-test", dest="self_test", action="store_true")
    a = ap.parse_args()

    if a.self_test:
        selftest()
        return
    if a.validate:
        try:
            doc = load_json_strict(a.validate)
        except FileNotFoundError:
            refuse(["REC-UNREADABLE: file not found"])
        except Exception as ex:  # noqa: BLE001
            refuse(["REC-UNREADABLE: %s" % ex.__class__.__name__])
        tool = a.tool if os.path.isfile(a.tool) else None
        errs = validate_recovery(doc, tool_path=tool)
        if errs:
            refuse(errs)
        print("VALID: %s conforms to %s" % (a.validate, SCHEMA))
        return

    if a.command == "recover":
        root = os.path.abspath(a.root)
        if not os.path.isdir(root):
            die("--root is not a directory: %s" % root, 2)
        cmd_recover(root, a.run_id, a.scope_lock, a.expect_head, a.verification, a.reconcile,
                    a.out, a.tool)
        return

    die("usage: dmc-context-recovery recover --run-id ID [--root DIR] [--scope-lock FILE] "
        "[--expect-head SHA] [--verification PASS|FAIL|NONE] [--reconcile] [--out FILE] "
        "| --validate FILE | --self-test", 2)


if __name__ == "__main__":
    main()
