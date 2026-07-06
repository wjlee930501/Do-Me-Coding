#!/usr/bin/env python3
"""dmc-scope-lock.py — DMC v1.0 M4 constructive Scope Lock compiler + adjudicator (P7c; §P7/§P6/§0.4).

Compiles an APPROVED plan + a landmark-annotated scope input into an immutable, hash-chained
`scope.lock.json` (schema `dmc.scope-lock.v1`, contract `.harness/schemas/scope-lock.schema.md`),
and exposes a PURE per-mutation adjudication verdict (allow/refuse) for the Ring-1 write guards.

M4 ships only the P7 *constructive* half: the compiler, the fail-closed validator, and the pure
`adjudicate(lock, path, op)` verdict. The P7 *enforcement* half (the Bash write-radius classifier,
`git apply`/`patch` deny, fail-closed-in-active hook wiring) lands in M6 — this module never mutates
the filesystem outside its own compile output and never itself blocks a write.

Subcommands:
  --compile --plan FILE --landmarks FILE [--run FILE | --run-id ID] [--prev HASH] [--root DIR]
            [--out FILE]                 compile the immutable lock (refuses a DRAFT plan; refuses a
                                         second lock for the same run — immutable §0.4)
  --validate FILE                        fail-closed lock validator (ACCEPT=>0, REFUSED=>3)
  --adjudicate LOCK PATH OP              pure verdict for one mutation (allow=>0, refuse=>3)
  --self-test                            hermetic section self-test (tempdir only)

House rules (v0.6.x / M2-M4 lineage): stdlib-only, deterministic (sorted keys/lists, content-derived
hashes, never wall-clock), env-independent (no env reads; git is best-effort with a no-git fallback),
offline, fail-closed validators with named value-blind reason codes and negative controls,
secret-bearing paths refused by path only. The canonicalization (`canon_hash`/`seal`/`GENESIS`) is
copied verbatim from the T009a run-lifecycle core so the run -> scope-lock -> ... hash chain composes.
Advisory tier: the runtime enforcement floor stays the hooks (M6).
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

SCHEMA = "dmc.scope-lock.v1"
GENESIS = "0" * 64          # chain root; hash-shaped so prev_hash is uniformly hash-shaped
HASH_RE = re.compile(r"^[0-9a-f]{16,}$")
LANDMARK_CLASSES = ["enforcement", "contract", "release", "data", "ordinary"]
GRANTS = ["edit", "create"]
OPS = ["edit", "create"]
BOUND_INTS = ["max_files", "max_added", "max_deleted"]
REQUIRED_FIELDS = ["schema", "work_id", "plan_hash", "repo_hash", "run_id", "approved_by",
                   "files", "bounds", "immutable", "compiled_at_head", "prev_hash", "state_hash"]

SECRET_ALLOW_BASENAMES = {".env.example", ".env.sample", ".env.template", ".env.dist"}


# ------------------------------------------------------------------- helpers

def die(msg, code=2):
    sys.stderr.write("dmc-scope-lock: %s\n" % msg)
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


def canon_hash(obj):
    """Shared canonical serialization hash: sorted keys, compact separators, UTF-8, sha256 hex."""
    payload = json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def seal(body):
    """Return a new record with state_hash = canon_hash(body-without-state_hash) (immutable seal)."""
    core = {k: v for k, v in body.items() if k != "state_hash"}
    return dict(core, state_hash=canon_hash(core))


def load_json_strict(path):
    """Duplicate-key-rejecting JSON load."""
    def hook(pairs):
        keys = [k for k, _ in pairs]
        if len(keys) != len(set(keys)):
            raise ValueError("duplicate key in JSON object")
        return dict(pairs)
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f, object_pairs_hook=hook)


def read_bytes(path):
    if is_secret_path(path):
        die("refused: secret-shaped path", 3)
    with open(path, "rb") as f:
        return f.read()


def read_text(path):
    return read_bytes(path).decode("utf-8", errors="strict")


def _path_is_safe(path):
    """Relative path with no `..` component and no leading separator (value-blind structural test)."""
    if not isinstance(path, str) or not path:
        return False
    if os.path.isabs(path):
        return False
    norm = path.replace("\\", "/")
    if norm.startswith("/"):
        return False
    return ".." not in norm.split("/")


# ------------------------------------------------------------ plan / git inputs

def plan_is_approved(text):
    """Fail-closed: the plan's Approval Status section must carry `Status: APPROVED`."""
    m = re.search(r"(?ms)^##\s+Approval Status\s*$(.*?)(?:^##\s+|\Z)", text)
    if not m:
        return False
    return bool(re.search(r"(?m)^\s*Status:\s*APPROVED\b", m.group(1)))


def extract_approver(text):
    """Read the human-gate auth reference from the plan's `Approver:` line (approval provenance,
    not authentication — the honest-scope label)."""
    m = re.search(r"(?ms)^##\s+Approval Status\s*$(.*?)(?:^##\s+|\Z)", text)
    if not m:
        return ""
    am = re.search(r"(?m)^\s*Approver:\s*(.+?)\s*$", m.group(1))
    return am.group(1).strip() if am else ""


def derive_work_id(text, path):
    m = re.search(r"(?m)^\s*Plan ID:\s*([A-Za-z0-9._-]+)", text)
    if m:
        return m.group(1)
    stem = os.path.splitext(os.path.basename(path))[0]
    return "work-" + re.sub(r"[^A-Za-z0-9._-]", "-", stem)


def plan_hash(path):
    return hashlib.sha256(read_bytes(path)).hexdigest()


def repo_hash(root):
    """Env-free `git status --porcelain | sha256` (established pattern); no-git => sha256(b'')."""
    git = shutil.which("git")
    data = b""
    if git:
        try:
            r = subprocess.run([git, "-C", root, "status", "--porcelain"],
                               capture_output=True, timeout=10)
            if r.returncode == 0:
                data = r.stdout
        except Exception:
            data = b""
    return hashlib.sha256(data).hexdigest()


def head_sha(root):
    """Best-effort `git rev-parse HEAD`; no-git / no-commit => the literal 'no-git'."""
    git = shutil.which("git")
    if git:
        try:
            r = subprocess.run([git, "-C", root, "rev-parse", "HEAD"],
                               capture_output=True, timeout=10)
            if r.returncode == 0:
                return r.stdout.decode("utf-8", "strict").strip()
        except Exception:
            pass
    return "no-git"


# ----------------------------------------------------------------- validator

def _validate_file_entry(entry):
    errs = []
    if not isinstance(entry, dict):
        return ["SCOPE-LOCK-FILE-NOT-OBJECT: a files[] entry is not a JSON object"]
    for k in ("path", "grant", "landmark_class"):
        if k not in entry:
            errs.append("SCOPE-LOCK-FILE-MISSING-FIELD: %s" % k)
    if errs:
        return errs
    if not _path_is_safe(entry["path"]):
        errs.append("SCOPE-LOCK-BAD-PATH: files[].path is absolute, empty, or contains '..'")
    elif is_secret_path(entry["path"]):
        errs.append("SCOPE-LOCK-SECRET-PATH: a scoped path is secret-shaped (refused by path)")
    if entry["grant"] not in GRANTS:
        errs.append("SCOPE-LOCK-BAD-GRANT: grant not in %s" % "|".join(GRANTS))
    lc = entry["landmark_class"]
    if lc not in LANDMARK_CLASSES:
        errs.append("SCOPE-LOCK-BAD-LANDMARK-CLASS: landmark_class not in %s"
                    % "|".join(LANDMARK_CLASSES))
    elif lc != "ordinary" and entry.get("landmark_authorized") is not True:
        errs.append("SCOPE-LOCK-LANDMARK-UNAUTHORIZED: a non-ordinary landmark_class requires an "
                    "explicit plan authorization (landmark edits are never implicit)")
    return errs


def _validate_bounds(bounds):
    errs = []
    if not isinstance(bounds, dict):
        return ["SCOPE-LOCK-BOUNDS-NOT-OBJECT: bounds must be a JSON object"]
    for k in BOUND_INTS:
        if k not in bounds:
            errs.append("SCOPE-LOCK-BOUNDS-MISSING: %s" % k)
            continue
        v = bounds[k]
        if isinstance(v, bool) or not isinstance(v, int) or v < 0:
            errs.append("SCOPE-LOCK-BAD-BOUND: %s must be a non-negative integer" % k)
    fhc = bounds.get("forbidden_hunk_classes")
    if not isinstance(fhc, list) or not all(isinstance(x, str) for x in fhc):
        errs.append("SCOPE-LOCK-BAD-FORBIDDEN-HUNKS: forbidden_hunk_classes must be a list of "
                    "strings")
    return errs


def validate_lock(doc):
    """Fail-closed scope.lock validator. Returns a list of named value-blind reason codes
    ([] == ACCEPT). Structure only — never echoes a scoped path's content."""
    if not isinstance(doc, dict):
        return ["SCOPE-LOCK-NOT-OBJECT: scope.lock root is not a JSON object"]
    errs = []
    for k in REQUIRED_FIELDS:
        if k not in doc:
            errs.append("SCOPE-LOCK-MISSING-FIELD: %s" % k)
    if errs:
        return errs
    if doc["schema"] != SCHEMA:
        errs.append("SCOPE-LOCK-BAD-SCHEMA: schema != %s" % SCHEMA)
    for b in ("work_id", "run_id"):
        if not (isinstance(doc[b], str) and doc[b].strip()):
            errs.append("SCOPE-LOCK-EMPTY-BINDING: %s must be a non-empty string" % b)
    if not (isinstance(doc["approved_by"], str) and doc["approved_by"].strip()):
        errs.append("SCOPE-LOCK-EMPTY-APPROVED-BY: approved_by must be a non-empty human-gate "
                    "auth reference (no lock without an approval reference)")
    for hk in ("plan_hash", "repo_hash"):
        if not (isinstance(doc[hk], str) and HASH_RE.match(doc[hk])):
            errs.append("SCOPE-LOCK-BAD-HASH: %s not hash-shaped" % hk)
    if not isinstance(doc["files"], list):
        errs.append("SCOPE-LOCK-FILES-NOT-LIST: files must be a JSON list")
    else:
        for entry in doc["files"]:
            errs.extend(_validate_file_entry(entry))
    errs.extend(_validate_bounds(doc["bounds"]))
    if doc["immutable"] is not True:
        errs.append("SCOPE-LOCK-NOT-IMMUTABLE: immutable must be boolean true")
    if not (isinstance(doc["compiled_at_head"], str) and doc["compiled_at_head"]):
        errs.append("SCOPE-LOCK-BAD-HEAD: compiled_at_head must be a non-empty string")
    if not (isinstance(doc["prev_hash"], str) and HASH_RE.match(doc["prev_hash"])):
        errs.append("SCOPE-LOCK-BAD-PREV-HASH: prev_hash not hash-shaped (hex>=16 or genesis)")
    if errs:
        return errs
    # Tamper detection LAST: a well-formed but in-place-edited lock has a stale state_hash (§0.4).
    if not (isinstance(doc["state_hash"], str) and HASH_RE.match(doc["state_hash"])):
        return ["SCOPE-LOCK-BAD-STATE-HASH: state_hash not hash-shaped"]
    core = {k: v for k, v in doc.items() if k != "state_hash"}
    if canon_hash(core) != doc["state_hash"]:
        return ["SCOPE-LOCK-TAMPER: state_hash != recomputed canonical hash (in-place edit "
                "detected at Ring 0)"]
    return []


# ---------------------------------------------------------------- adjudication

def adjudicate(lock, path, op):
    """PURE per-mutation verdict. Returns (verdict, reason) with verdict in {allow, refuse}.

    No filesystem access, no mutation — the Ring-1 write guards call this and act on the verdict
    (wired in M6). Fail-closed: an invalid lock, an unsafe/secret path, an out-of-scope path, or an
    ungranted op all yield 'refuse'.
    """
    errs = validate_lock(lock)
    if errs:
        return "refuse", "SCOPE-LOCK-INVALID-LOCK: %s" % errs[0]
    if op not in OPS:
        return "refuse", "SCOPE-LOCK-BAD-OP: op not in %s" % "|".join(OPS)
    if not _path_is_safe(path):
        return "refuse", "SCOPE-LOCK-BAD-PATH: mutation path is absolute, empty, or contains '..'"
    if is_secret_path(path):
        return "refuse", "SCOPE-LOCK-SECRET-PATH: mutation path is secret-shaped (refused by path)"
    norm = path.replace("\\", "/")
    for entry in lock["files"]:
        if entry["path"].replace("\\", "/") == norm:
            # grant 'create' subsumes 'edit' (a newly-created file may then be edited within scope);
            # grant 'edit' permits edits only.
            allowed = {"edit"} if entry["grant"] == "edit" else {"create", "edit"}
            if op in allowed:
                return "allow", "SCOPE-LOCK-ALLOW: path in locked scope, op granted"
            return "refuse", "SCOPE-LOCK-OP-NOT-GRANTED: path in scope but the op is not granted"
    return "refuse", "SCOPE-LOCK-PATH-NOT-IN-SCOPE: mutation path is not in the locked scope"


# ------------------------------------------------------------------- compiler

def runs_dir(root):
    return os.path.join(root, ".harness", "runs")


def default_lock_path(root, run_id):
    return os.path.join(runs_dir(root), run_id, "scope.lock.json")


def _resolve_chain(root, run_id_override, run_path, prev_override):
    """Resolve (prev_hash, run_id) so the lock chains onto the T009a run-state (or GENESIS)."""
    if run_path:
        if not os.path.isfile(run_path):
            refuse(["SCOPE-LOCK-RUN-NOT-FOUND: --run file does not exist"])
        try:
            run = load_json_strict(run_path)
        except Exception as e:
            refuse(["SCOPE-LOCK-RUN-UNREADABLE: %s" % e.__class__.__name__])
        sh = run.get("state_hash") if isinstance(run, dict) else None
        if not (isinstance(sh, str) and HASH_RE.match(sh)):
            refuse(["SCOPE-LOCK-RUN-NO-STATE-HASH: --run carries no hash-shaped state_hash to "
                    "chain onto"])
        rid = run_id_override or (run.get("run_id") if isinstance(run, dict) else None)
        prev = prev_override or sh
    else:
        rid = run_id_override
        prev = prev_override or GENESIS
    if not (isinstance(rid, str) and rid.strip()):
        refuse(["SCOPE-LOCK-NO-RUN-ID: provide --run-id or a --run file carrying run_id"])
    if not (isinstance(prev, str) and HASH_RE.match(prev)):
        refuse(["SCOPE-LOCK-BAD-PREV: --prev must be hash-shaped (hex>=16 or genesis)"])
    return prev, rid


def cmd_compile(root, plan_path, landmarks_path, run_id_override, run_path, prev_override, out_path):
    if not os.path.isfile(plan_path):
        refuse(["SCOPE-LOCK-PLAN-NOT-FOUND: plan file does not exist"])
    text = read_text(plan_path)
    if not plan_is_approved(text):
        refuse(["SCOPE-LOCK-PLAN-NOT-APPROVED: plan Approval Status is not 'Status: APPROVED'"])
    approver = extract_approver(text)
    if not approver:
        refuse(["SCOPE-LOCK-NO-APPROVER: plan Approval Status carries no non-empty 'Approver:'"])

    if not os.path.isfile(landmarks_path):
        refuse(["SCOPE-LOCK-LANDMARKS-NOT-FOUND: landmarks input does not exist"])
    try:
        scope_in = load_json_strict(landmarks_path)
    except Exception as e:
        refuse(["SCOPE-LOCK-LANDMARKS-UNREADABLE: %s" % e.__class__.__name__])
    if not isinstance(scope_in, dict):
        refuse(["SCOPE-LOCK-LANDMARKS-NOT-OBJECT: landmarks input root is not a JSON object"])
    files_in = scope_in.get("files")
    bounds_in = scope_in.get("bounds")
    if not isinstance(files_in, list):
        refuse(["SCOPE-LOCK-LANDMARKS-NO-FILES: landmarks input lacks a files[] list"])
    if not isinstance(bounds_in, dict):
        refuse(["SCOPE-LOCK-LANDMARKS-NO-BOUNDS: landmarks input lacks a bounds object"])

    # Normalize files[] to the minimal schema keys; carry landmark_authorized only on non-ordinary
    # entries (the explicit landmark-edit authorization the schema requires).
    files = []
    for entry in files_in:
        if not isinstance(entry, dict):
            refuse(["SCOPE-LOCK-FILE-NOT-OBJECT: a landmarks files[] entry is not an object"])
        norm = {"path": entry.get("path"), "grant": entry.get("grant"),
                "landmark_class": entry.get("landmark_class")}
        if norm["landmark_class"] != "ordinary" and entry.get("landmark_authorized") is True:
            norm["landmark_authorized"] = True
        files.append(norm)
    files.sort(key=lambda e: ((e.get("path") or ""), (e.get("grant") or "")))

    fhc = bounds_in.get("forbidden_hunk_classes", [])
    if isinstance(fhc, list) and all(isinstance(x, str) for x in fhc):
        fhc = sorted(fhc)
    bounds = {
        "max_files": bounds_in.get("max_files"),
        "max_added": bounds_in.get("max_added"),
        "max_deleted": bounds_in.get("max_deleted"),
        "forbidden_hunk_classes": fhc,
    }

    prev, run_id = _resolve_chain(root, run_id_override, run_path, prev_override)
    body = {
        "schema": SCHEMA,
        "work_id": derive_work_id(text, plan_path),
        "plan_hash": plan_hash(plan_path),
        "repo_hash": repo_hash(root),
        "run_id": run_id,
        "approved_by": approver,
        "files": files,
        "bounds": bounds,
        "immutable": True,
        "compiled_at_head": head_sha(root),
        "prev_hash": prev,
    }
    lock = seal(body)

    errs = validate_lock(lock)
    if errs:
        refuse(errs)   # fail-closed: never emit a non-conforming lock

    dest = out_path or default_lock_path(root, run_id)
    # Immutable §0.4: a second lock for the same run is refused — amendment = new plan revision +
    # re-approval, never an in-place edit / overwrite.
    if os.path.exists(dest):
        refuse(["SCOPE-LOCK-EXISTS: a scope.lock already exists for this run; the lock is immutable "
                "(amendment = new plan revision + re-approval, never in-place edit)"])
    os.makedirs(os.path.dirname(os.path.abspath(dest)), exist_ok=True)
    with open(dest, "w", encoding="utf-8") as f:
        f.write(json.dumps(lock, sort_keys=True, indent=2, ensure_ascii=False) + "\n")
    print("run_id: %s" % run_id)
    print("scope_lock: %s" % dest)
    print("immutable: true")
    print("state_hash: %s" % lock["state_hash"][:16])


# ------------------------------------------------------------------- self-test

SYNTH_APPROVED_PLAN = """# Plan: synthetic scope-lock self-test plan

Plan ID: dmc-selftest-scope

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
Status: APPROVED
Approver: SYNTHETIC-FIXTURE
Approved At: 2026-07-06
"""

SYNTH_DRAFT_PLAN = SYNTH_APPROVED_PLAN.replace("Status: APPROVED", "Status: DRAFT")

SYNTH_LANDMARKS = {
    "files": [
        {"path": "src/app.py", "grant": "edit", "landmark_class": "ordinary"},
        {"path": "src/new_mod.py", "grant": "create", "landmark_class": "ordinary"},
        {"path": "bin/dmc", "grant": "edit", "landmark_class": "enforcement",
         "landmark_authorized": True},
    ],
    "bounds": {"max_files": 3, "max_added": 200, "max_deleted": 50,
               "forbidden_hunk_classes": ["format-churn"]},
}


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
    """Best-effort `git status --porcelain` of the real repo; None if git is unavailable."""
    git = shutil.which("git")
    if not git:
        return None
    root = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
    try:
        r = subprocess.run([git, "-C", root, "status", "--porcelain"],
                           capture_output=True, timeout=10)
        return r.stdout if r.returncode == 0 else None
    except Exception:
        return None


def _mkfixture(plan_text=SYNTH_APPROVED_PLAN, landmarks=SYNTH_LANDMARKS):
    """Disposable tempdir 'repo' with an APPROVED plan + a landmarks/scope input; best-effort
    git init (graceful no-git). Self-contained: no commit, so no git identity is required."""
    tmp = tempfile.mkdtemp(prefix="dmc-scope-")
    plan = os.path.join(tmp, "plan.md")
    with open(plan, "w", encoding="utf-8") as f:
        f.write(plan_text)
    lm = os.path.join(tmp, "landmarks.json")
    with open(lm, "w", encoding="utf-8") as f:
        f.write(json.dumps(landmarks, sort_keys=True, indent=2) + "\n")
    git = shutil.which("git")
    if git:
        try:
            subprocess.run([git, "init", "-q", tmp], capture_output=True, timeout=10)
        except Exception:
            pass
    return tmp, plan, lm


def _run_cli(*args, env=None):
    """Invoke this module as a subprocess for real exit-code assertions."""
    return subprocess.run([sys.executable, os.path.abspath(__file__), *args],
                          capture_output=True, text=True, env=env)


def selftest():
    t = ST("scope-lock")
    before = _real_repo_porcelain()

    tmp_a, plan_a, lm_a = _mkfixture()
    tmp_b, plan_b, lm_b = _mkfixture()          # identical inputs -> determinism check
    tmp_draft, plan_d, lm_d = _mkfixture(SYNTH_DRAFT_PLAN)
    tmp_run = tempfile.mkdtemp(prefix="dmc-scope-run-")
    RID = "dmc-run-fixture"
    try:
        lock_a = default_lock_path(tmp_a, RID)
        r1 = _run_cli("--compile", "--plan", plan_a, "--landmarks", lm_a,
                      "--run-id", RID, "--root", tmp_a)
        doc_a = load_json_strict(lock_a) if os.path.isfile(lock_a) else None
        t.ok("C1 compile exit 0 + writes scope.lock.json",
             r1.returncode == 0 and doc_a is not None)
        t.ok("C1b compiled lock validates (schema/binding/files/bounds/chain)",
             doc_a is not None and validate_lock(doc_a) == [])
        t.ok("C1c immutable:true, schema pinned, prev_hash GENESIS (no --run), approved_by carried",
             doc_a is not None and doc_a["immutable"] is True and doc_a["schema"] == SCHEMA
             and doc_a["prev_hash"] == GENESIS and doc_a["approved_by"] == "SYNTHETIC-FIXTURE"
             and doc_a["work_id"] == "dmc-selftest-scope")
        t.ok("C1d non-ordinary landmark entry carries explicit landmark_authorized; files sorted",
             doc_a is not None
             and any(e["landmark_class"] == "enforcement" and e.get("landmark_authorized") is True
                     for e in doc_a["files"])
             and doc_a["files"] == sorted(doc_a["files"],
                                          key=lambda e: (e["path"], e["grant"])))

        # -- determinism: identical inputs -> byte-identical lock ----------------------
        _run_cli("--compile", "--plan", plan_b, "--landmarks", lm_b, "--run-id", RID,
                 "--root", tmp_b)
        lock_b = default_lock_path(tmp_b, RID)
        t.check("C2 determinism: identical inputs yield byte-identical scope.lock.json",
                lambda: open(lock_a, "rb").read() == open(lock_b, "rb").read())

        # -- env-independence: the pure surface is identical under a scrubbed env ------
        scrubbed = {"PATH": os.environ.get("PATH", "")}
        v_full = _run_cli("--validate", lock_a)
        v_scrub = _run_cli("--validate", lock_a, env=scrubbed)
        t.ok("C3 env -i identical: --validate output + exit invariant under scrubbed env",
             v_full.returncode == 0 and v_scrub.returncode == 0
             and v_full.stdout == v_scrub.stdout)
        adj_full = _run_cli("--adjudicate", lock_a, "src/app.py", "edit")
        adj_scrub = _run_cli("--adjudicate", lock_a, "src/app.py", "edit", env=scrubbed)
        t.ok("C3b env -i identical: --adjudicate output + exit invariant under scrubbed env",
             adj_full.returncode == 0 and adj_full.stdout == adj_scrub.stdout
             and adj_scrub.returncode == 0)

        # -- NEGATIVE: concurrent second lock for the same run is REFUSED (immutable) ---
        r_dup = _run_cli("--compile", "--plan", plan_a, "--landmarks", lm_a, "--run-id", RID,
                         "--root", tmp_a)
        t.ok("C4 NEG concurrent-second-lock: a second lock for the run REFUSED exit 3",
             r_dup.returncode == 3 and "SCOPE-LOCK-EXISTS" in r_dup.stdout)

        # -- NEGATIVE: compile on a DRAFT plan is REFUSED ------------------------------
        r_draft = _run_cli("--compile", "--plan", plan_d, "--landmarks", lm_d, "--run-id", RID,
                           "--root", tmp_draft)
        t.ok("C5 NEG compile refuses a non-APPROVED (DRAFT) plan exit 3",
             r_draft.returncode == 3 and "SCOPE-LOCK-PLAN-NOT-APPROVED" in r_draft.stdout)

        # -- chain composition with a T009a-canonical run.json -------------------------
        run_rec = seal({
            "schema": "dmc.run-state.v1", "run_id": "dmc-run-compose", "work_id": "w",
            "plan_path": "plan.md", "plan_hash": "a" * 64, "repo_hash": "b" * 64,
            "status": "RUNNING", "seq": 1, "created_at": "2026-07-06T00:00:00Z",
            "updated_at": "2026-07-06T00:00:00Z", "prev_hash": "c" * 64,
        })
        run_json = os.path.join(tmp_run, "run.json")
        with open(run_json, "w", encoding="utf-8") as f:
            f.write(json.dumps(run_rec, sort_keys=True, indent=2) + "\n")
        r_chain = _run_cli("--compile", "--plan", plan_a, "--landmarks", lm_a, "--run", run_json,
                           "--root", tmp_run)
        lock_c = default_lock_path(tmp_run, "dmc-run-compose")
        doc_c = load_json_strict(lock_c) if os.path.isfile(lock_c) else None
        t.ok("C6 compile --run chains prev_hash onto the run state_hash (chain composes)",
             r_chain.returncode == 0 and doc_c is not None
             and doc_c["prev_hash"] == run_rec["state_hash"]
             and doc_c["run_id"] == "dmc-run-compose" and validate_lock(doc_c) == [])

        # -- adjudication verdicts (pure) ---------------------------------------------
        t.ok("C7 adjudicate ALLOW: edit an in-scope ordinary path",
             adjudicate(doc_a, "src/app.py", "edit")[0] == "allow")
        t.ok("C7b adjudicate ALLOW: create an in-scope create-grant path",
             adjudicate(doc_a, "src/new_mod.py", "create")[0] == "allow")
        t.ok("C7c adjudicate REFUSE: path not in the locked scope",
             adjudicate(doc_a, "src/other.py", "edit") == (
                 "refuse", "SCOPE-LOCK-PATH-NOT-IN-SCOPE: mutation path is not in the locked scope"))
        t.ok("C7d adjudicate REFUSE: op not granted (create on an edit-only grant)",
             adjudicate(doc_a, "src/app.py", "create")[0] == "refuse"
             and "OP-NOT-GRANTED" in adjudicate(doc_a, "src/app.py", "create")[1])
        t.ok("C7e adjudicate REFUSE: a `..` traversal path",
             adjudicate(doc_a, "../escape.py", "edit")[0] == "refuse")
        t.ok("C7f adjudicate REFUSE: a secret-shaped path (refused by path)",
             adjudicate(doc_a, ".env", "edit") == (
                 "refuse", "SCOPE-LOCK-SECRET-PATH: mutation path is secret-shaped (refused by "
                           "path)"))
        adj_out = _run_cli("--adjudicate", lock_a, "src/other.py", "edit")
        t.ok("C7g adjudicate CLI: an out-of-scope mutation exits 3 (deny)",
             adj_out.returncode == 3 and "REFUSE" in adj_out.stdout)

        # -- validator negative controls (craft from the valid compiled lock) ---------
        t.ok("N0 the valid compiled lock ACCEPTS (baseline)", validate_lock(doc_a) == [])

        no_appr = seal({k: v for k, v in doc_a.items() if k != "state_hash"} | {"approved_by": ""})
        t.ok("N1 NEG missing/empty approved_by REFUSED",
             any(e.startswith("SCOPE-LOCK-EMPTY-APPROVED-BY") for e in validate_lock(no_appr)))

        bad_dotdot = dict(doc_a)
        bad_dotdot_files = [dict(e) for e in doc_a["files"]]
        bad_dotdot_files[0] = dict(bad_dotdot_files[0], path="../escape.py")
        bad_dotdot = seal({k: v for k, v in doc_a.items() if k != "state_hash"}
                          | {"files": bad_dotdot_files})
        t.ok("N2 NEG a files[].path with '..' REFUSED",
             any(e.startswith("SCOPE-LOCK-BAD-PATH") for e in validate_lock(bad_dotdot)))
        abs_files = [dict(e) for e in doc_a["files"]]
        abs_files[0] = dict(abs_files[0], path="/etc/passwd")
        bad_abs = seal({k: v for k, v in doc_a.items() if k != "state_hash"} | {"files": abs_files})
        t.ok("N2b NEG an absolute files[].path REFUSED",
             any(e.startswith("SCOPE-LOCK-BAD-PATH") for e in validate_lock(bad_abs)))

        not_immut = seal({k: v for k, v in doc_a.items() if k != "state_hash"}
                         | {"immutable": False})
        t.ok("N3 NEG immutable != true REFUSED",
             any(e.startswith("SCOPE-LOCK-NOT-IMMUTABLE") for e in validate_lock(not_immut)))

        neg_bound = seal({k: v for k, v in doc_a.items() if k != "state_hash"}
                         | {"bounds": dict(doc_a["bounds"], max_added=-1)})
        t.ok("N4 NEG a negative bound REFUSED",
             any(e.startswith("SCOPE-LOCK-BAD-BOUND") for e in validate_lock(neg_bound)))

        bad_class_files = [dict(e) for e in doc_a["files"]]
        bad_class_files[0] = dict(bad_class_files[0], landmark_class="wobble")
        bad_class = seal({k: v for k, v in doc_a.items() if k != "state_hash"}
                         | {"files": bad_class_files})
        t.ok("N5 NEG a non-enum landmark_class REFUSED",
             any(e.startswith("SCOPE-LOCK-BAD-LANDMARK-CLASS") for e in validate_lock(bad_class)))

        unauth_files = [dict(e) for e in doc_a["files"]]
        unauth_files[0] = {"path": "bin/hook.sh", "grant": "edit", "landmark_class": "enforcement"}
        unauth = seal({k: v for k, v in doc_a.items() if k != "state_hash"}
                      | {"files": unauth_files})
        t.ok("N6 NEG a non-ordinary landmark path with no plan authorization REFUSED",
             any(e.startswith("SCOPE-LOCK-LANDMARK-UNAUTHORIZED") for e in validate_lock(unauth)))

        tampered = dict(doc_a, immutable=True, files=list(doc_a["files"]))
        tampered["approved_by"] = "attacker"     # in-place edit WITHOUT re-sealing -> stale hash
        t.ok("N7 NEG in-place edit (stale state_hash) REFUSED as tamper",
             any(e.startswith("SCOPE-LOCK-TAMPER") for e in validate_lock(tampered)))

        broken_prev = seal({k: v for k, v in doc_a.items() if k != "state_hash"}
                           | {"prev_hash": "not-a-hash"})
        t.ok("N8 NEG a broken prev_hash REFUSED",
             any(e.startswith("SCOPE-LOCK-BAD-PREV-HASH") for e in validate_lock(broken_prev)))

        # -- CLI validate exit codes ---------------------------------------------------
        rv = _run_cli("--validate", lock_a)
        t.ok("N9 --validate ACCEPTs the compiled lock (exit 0)",
             rv.returncode == 0 and "VALID" in rv.stdout)
        bad_path = os.path.join(tmp_run, "tampered.json")
        with open(bad_path, "w", encoding="utf-8") as f:
            f.write(json.dumps(tampered, sort_keys=True, indent=2) + "\n")
        rvb = _run_cli("--validate", bad_path)
        t.ok("N9b --validate REFUSEs a tampered lock (exit 3)",
             rvb.returncode == 3 and "SCOPE-LOCK-TAMPER" in rvb.stdout)
    finally:
        for d in (tmp_a, tmp_b, tmp_draft, tmp_run):
            shutil.rmtree(d, ignore_errors=True)

    after = _real_repo_porcelain()
    t.ok("Z1 real repo git status --porcelain byte-identical before/after (or git absent)",
         before == after)
    t.done()


# ------------------------------------------------------------------------ main

def main():
    ap = argparse.ArgumentParser(prog="dmc-scope-lock")
    ap.add_argument("--compile", action="store_true")
    ap.add_argument("--plan", metavar="FILE")
    ap.add_argument("--landmarks", metavar="FILE")
    ap.add_argument("--run", dest="run", metavar="FILE")
    ap.add_argument("--run-id", dest="run_id", metavar="ID")
    ap.add_argument("--prev", dest="prev", metavar="HASH")
    ap.add_argument("--root", default=".")
    ap.add_argument("--out", metavar="FILE")
    ap.add_argument("--validate", metavar="FILE")
    ap.add_argument("--adjudicate", nargs=3, metavar=("LOCK", "PATH", "OP"))
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args()

    if a.self_test:
        selftest()
        return

    if a.validate:
        try:
            doc = load_json_strict(a.validate)
        except FileNotFoundError:
            refuse(["SCOPE-LOCK-UNREADABLE: file not found"])
        except Exception as e:
            refuse(["SCOPE-LOCK-UNREADABLE: %s" % e.__class__.__name__])
        errs = validate_lock(doc)
        if errs:
            refuse(errs)
        print("VALID: %s conforms to %s" % (a.validate, SCHEMA))
        return

    if a.adjudicate:
        lock_path, path, op = a.adjudicate
        try:
            lock = load_json_strict(lock_path)
        except FileNotFoundError:
            print("REFUSE: SCOPE-LOCK-UNREADABLE: lock file not found")
            sys.exit(3)
        except Exception as e:
            print("REFUSE: SCOPE-LOCK-UNREADABLE: %s" % e.__class__.__name__)
            sys.exit(3)
        verdict, reason = adjudicate(lock, path, op)
        print("%s: %s" % (verdict.upper(), reason))
        sys.exit(0 if verdict == "allow" else 3)

    if a.compile:
        if not a.plan or not a.landmarks:
            die("--compile requires --plan FILE and --landmarks FILE", 2)
        root = os.path.abspath(a.root)
        if not os.path.isdir(root):
            die("--root is not a directory: %s" % root, 2)
        cmd_compile(root, a.plan, a.landmarks, a.run_id, a.run, a.prev, a.out)
        return

    die("usage: dmc-scope-lock (--compile --plan FILE --landmarks FILE [--run FILE | --run-id ID] "
        "[--prev HASH] [--root DIR] [--out FILE]) | --validate FILE | "
        "--adjudicate LOCK PATH OP | --self-test", 2)


if __name__ == "__main__":
    main()
