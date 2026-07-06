#!/usr/bin/env python3
"""dmc-acceptance.py — DMC v1.0 M4 Acceptance Criteria compiler (P8; architecture §P8).

Compiles an APPROVED plan's Acceptance Criteria + the orientation `verify_commands` into
`runs/<run-id>/acceptance.json` (schema `dmc.acceptance.v1`, see acceptance.schema.md). Each
criterion becomes a machine-referable check with an explicit verification method; a criterion
with no extractable method is REFUSED (untestable-criterion refusal — never a silent skip). The
artifact is immutable post-approval and deterministic (byte-identical for identical inputs).

Subcommands:
  compile --plan FILE --orientation FILE [--radius FILE] (--out-dir DIR | --run-id ID [--root DIR])
          [--work-id ID] [--prev-hash HEX]         compile + write acceptance.json (REFUSES unless
                                                    the plan is APPROVED; REFUSES untestable criteria)
  --validate FILE                                   fail-closed validator (VALID=>0, REFUSED=>3)
  --self-test                                       hermetic section self-test (tempdir only)

House rules (v0.6.x / M2-M4 lineage): stdlib-only, deterministic (content-derived check_ids, no
wall-clock, sorted-key canonical hashing), env-independent (no env reads; git is best-effort with a
no-git fallback), offline (no network), fail-closed validators with named reason codes and negative
controls, value-blind refusals (name schema constants/enums, never document content), secret-bearing
paths refused by path only. Advisory tier: the runtime enforcement floor stays the hooks (M6).
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

SCHEMA = "dmc.acceptance.v1"
KINDS = ("command", "inspection", "human")
GENESIS = "0" * 64
HASH_RE = re.compile(r"^[0-9a-f]{16,}$")
CID_PREFIX = "CHK-"

SECRET_ALLOW_BASENAMES = {".env.example", ".env.sample", ".env.template", ".env.dist"}


# ------------------------------------------------------------------- helpers

def die(msg, code=2):
    sys.stderr.write("dmc-acceptance: %s\n" % msg)
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
        die("refused: secret-shaped input path", 3)
    with open(path, "rb") as f:
        return f.read()


def read_text(path):
    return read_bytes(path).decode("utf-8", errors="strict")


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


def plan_hash(path):
    return hashlib.sha256(read_bytes(path)).hexdigest()


def plan_is_approved(text):
    """Fail-closed: the plan's Approval Status section must carry `Status: APPROVED`."""
    m = re.search(r"(?ms)^##\s+Approval Status\s*$(.*?)(?:^##\s+|\Z)", text)
    if not m:
        return False
    return bool(re.search(r"(?m)^\s*Status:\s*APPROVED\b", m.group(1)))


def derive_work_id(text, path):
    m = re.search(r"(?m)^\s*Plan ID:\s*([A-Za-z0-9._-]+)", text)
    if m:
        return m.group(1)
    stem = os.path.splitext(os.path.basename(path))[0]
    return "work-" + re.sub(r"[^A-Za-z0-9._-]", "-", stem)


# --------------------------------------------------------------- plan parsing

def section_body(text, name):
    """Return the body text of the exact `## <name>` h2 section, or '' if absent."""
    m = re.search(r"(?ms)^##\s+%s\s*$(.*?)(?:^##\s+|\Z)" % re.escape(name), text)
    return m.group(1) if m else ""


def parse_criteria(text):
    """Parse the Acceptance Criteria section into ordered (criterion, method) pairs.

    A criterion block starts at `- Criterion:` and its method is the first
    `Verification Method:` line before the next `- Criterion:` (multi-line criterion text joined).
    """
    body = section_body(text, "Acceptance Criteria")
    pairs = []
    cur_crit = None
    cur_method = None
    for raw in body.splitlines():
        line = raw.rstrip()
        mcrit = re.match(r"^\s*-\s*Criterion:\s*(.*)$", line)
        mmeth = re.match(r"^\s*Verification Method:\s*(.*)$", line)
        if mcrit:
            if cur_crit is not None:
                pairs.append((cur_crit.strip(), (cur_method or "").strip()))
            cur_crit = mcrit.group(1)
            cur_method = None
        elif mmeth and cur_crit is not None and cur_method is None:
            cur_method = mmeth.group(1)
        elif cur_crit is not None and cur_method is None and line.strip():
            # continuation of the criterion text (before its method line)
            cur_crit += " " + line.strip()
    if cur_crit is not None:
        pairs.append((cur_crit.strip(), (cur_method or "").strip()))
    return pairs


def is_command_like(s):
    """A backticked span is treated as a runnable command by leading-token shape."""
    s = s.strip()
    if re.match(r"^(bin/|\./|python3?\b|bash\b|sh\b|git\b|grep\b|make\b|npm\b|node\b|"
                r"cargo\b|go\b|pytest\b|py_compile\b|test\b|true$|false$|echo\b|\[)", s):
        return True
    return bool(re.match(r"^[\w./\-]+/\S", s))


def classify_method(method):
    """Map a Verification Method to (kind, cmd, expect, question) or None if untestable.

    Explicit `command:|inspection:|human:` tags win; otherwise a backticked command => command,
    a human/manual marker => human, a decidable-predicate marker => inspection; else untestable.
    """
    m = (method or "").strip()
    if not m:
        return None
    tag = re.match(r"(?i)^(command|inspection|human)\s*:\s*(.+)$", m)
    if tag:
        kind = tag.group(1).lower()
        rest = tag.group(2).strip()
        if not rest:
            return None
        if kind == "command":
            bt = re.findall(r"`([^`]+)`", rest)
            cmd = next((b.strip() for b in bt if b.strip()), rest)
            return ("command", cmd, None, None) if cmd else None
        if kind == "inspection":
            return ("inspection", None, rest, None)
        return ("human", None, None, rest)
    for span in re.findall(r"`([^`]+)`", m):
        s = span.strip()
        if s and is_command_like(s):
            return ("command", s, None, None)
    if re.search(r"(?i)\b(human gate|human release|human|manual(ly)?)\b", m):
        return ("human", None, None, m)
    if re.search(r"(?i)(byte-?unchanged|exits?\s*\d|exit\s*code|==|!=|\bempty\b|\bpresent\b|"
                 r"\babsent\b|\bVALID\b|\bREFUSE|\bPASS\b|\bFAIL\b|\bgreen\b|\bcontains\b)", m):
        return ("inspection", None, m, None)
    return None


# ---------------------------------------------------------------- check model

def make_check(kind, criterion_ref, cmd, expect, question, radius_links):
    """Build a check with a content-derived, stable, unique check_id.

    check_id = CID_PREFIX + canon_hash(body-sans-id)[:12] — so any in-place mutation of a check
    field flips its id and the validator's tamper check catches it (acceptance.schema.md §immutable).
    """
    body = {
        "kind": kind,
        "criterion_ref": criterion_ref,
        "cmd": cmd,
        "expect": expect,
        "question": question,
        "radius_links": sorted(set(radius_links)),
    }
    return dict(body, check_id=CID_PREFIX + canon_hash(body)[:12])


def recompute_check_id(check):
    body = {k: check[k] for k in ("kind", "criterion_ref", "cmd", "expect", "question",
                                  "radius_links") if k in check}
    return CID_PREFIX + canon_hash(body)[:12]


def compile_acceptance(plan_path, orientation_path, radius_path, root, work_id_override,
                       prev_hash):
    """Compile plan criteria + orientation verify_commands (+ radius links) into a doc; fail-closed."""
    if not os.path.isfile(plan_path):
        refuse(["ACC-PLAN-NOT-FOUND: plan file does not exist"])
    if not os.path.isfile(orientation_path):
        refuse(["ACC-ORIENTATION-NOT-FOUND: orientation file does not exist"])
    text = read_text(plan_path)
    if not plan_is_approved(text):
        refuse(["ACC-PLAN-NOT-APPROVED: plan Approval Status is not 'Status: APPROVED'"])

    try:
        orient = load_json_strict(orientation_path)
    except Exception as e:
        refuse(["ACC-ORIENTATION-UNREADABLE: %s" % e.__class__.__name__])
    if not isinstance(orient, dict):
        refuse(["ACC-ORIENTATION-NOT-OBJECT: orientation root is not a JSON object"])

    radius_paths = []
    if radius_path:
        if not os.path.isfile(radius_path):
            refuse(["ACC-RADIUS-NOT-FOUND: radius file does not exist"])
        try:
            radius = load_json_strict(radius_path)
        except Exception as e:
            refuse(["ACC-RADIUS-UNREADABLE: %s" % e.__class__.__name__])
        for ent in (radius.get("entries") or []):
            p = ent.get("path")
            if isinstance(p, str) and p:
                radius_paths.append(p)
        radius_paths = sorted(set(radius_paths))
        for p in radius_paths:
            if ".." in p.split("/") or p.startswith("/"):
                refuse(["ACC-BAD-RADIUS-LINK: radius entry path is absolute or contains '..'"])

    checks = []

    # (1) orientation verify_commands => command checks; they carry the radius entry paths as
    # radius_links (project verification covers every scoped path — path-based coverage anchor).
    verify_cmds = orient.get("verify_commands") or []
    orient_cmd_count = 0
    for i, vc in enumerate(verify_cmds):
        if not isinstance(vc, dict):
            continue
        cmd = vc.get("command")
        if not (isinstance(cmd, str) and cmd.strip()):
            continue
        src = vc.get("source") or ("orientation:verify_commands[%d]" % i)
        checks.append(make_check("command", "orientation:%s" % src, cmd.strip(),
                                 None, None, radius_paths))
        orient_cmd_count += 1

    # (2) plan Acceptance Criteria => checks by kind; an untestable criterion is REFUSED.
    criteria = parse_criteria(text)
    if not criteria:
        refuse(["ACC-NO-CRITERIA: plan Acceptance Criteria section has no '- Criterion:' entries"])
    for i, (crit, method) in enumerate(criteria):
        cls = classify_method(method)
        if cls is None:
            refuse(["ACC-UNTESTABLE-CRITERION: criterion #%d has no extractable "
                    "command/inspection/human method (untestable => refused, never skipped)" % (i + 1)])
        kind, cmd, expect, question = cls
        checks.append(make_check(kind, "plan:AcceptanceCriteria[%d]" % (i + 1),
                                  cmd, expect, question, []))

    # (3) fail-closed: radius entries present but no verification method to anchor their coverage.
    if radius_paths and orient_cmd_count == 0:
        refuse(["ACC-RADIUS-NO-COVERAGE-METHOD: radius entries present but no orientation "
                "verify_command exists to anchor path coverage"])

    # de-duplicate identical checks (same content-derived id), then sort deterministically.
    dedup = {c["check_id"]: c for c in checks}
    checks = sorted(dedup.values(), key=lambda c: c["check_id"])

    doc = {
        "schema": SCHEMA,
        "work_id": work_id_override or derive_work_id(text, plan_path),
        "plan_hash": plan_hash(plan_path),
        "repo_hash": repo_hash(root),
        "checks": checks,
        "immutable": True,
        "prev_hash": prev_hash or GENESIS,
    }
    errs = validate_acceptance(doc)
    if errs:
        refuse(errs)   # self-refusal: never emit an artifact that fails its own validator
    return doc


# ----------------------------------------------------------------- validator

def validate_acceptance(doc):
    """Fail-closed acceptance.json validator. Returns a list of reason codes ([] == VALID)."""
    if not isinstance(doc, dict):
        return ["ACC-NOT-OBJECT: acceptance.json root is not a JSON object"]
    errs = []
    if doc.get("schema") != SCHEMA:
        errs.append("ACC-BAD-SCHEMA: schema != %s" % SCHEMA)
    for k in ("work_id",):
        if not (isinstance(doc.get(k), str) and doc[k].strip()):
            errs.append("ACC-MISSING-BINDING: %s missing/empty" % k)
    for hk in ("plan_hash", "repo_hash"):
        if not (isinstance(doc.get(hk), str) and HASH_RE.match(doc.get(hk, ""))):
            errs.append("ACC-BAD-HASH: %s not hash-shaped" % hk)
    if doc.get("immutable") is not True:
        errs.append("ACC-NOT-IMMUTABLE: immutable must be boolean true")
    pv = doc.get("prev_hash")
    if not (isinstance(pv, str) and (pv == GENESIS or HASH_RE.match(pv))):
        errs.append("ACC-BAD-PREV-HASH: prev_hash not hash-shaped (hex>=16 or genesis)")
    checks = doc.get("checks")
    if not isinstance(checks, list) or not checks:
        errs.append("ACC-EMPTY-CHECKS: checks must be a non-empty array")
        return errs
    seen = set()
    for idx, c in enumerate(checks):
        tag = "checks[%d]" % idx
        if not isinstance(c, dict):
            errs.append("ACC-CHECK-NOT-OBJECT: %s is not an object" % tag)
            continue
        cid = c.get("check_id")
        if not (isinstance(cid, str) and cid.strip()):
            errs.append("ACC-CHECK-NO-ID: %s check_id missing/empty" % tag)
        else:
            if cid in seen:
                errs.append("ACC-DUP-CHECK-ID: %s duplicate check_id" % tag)
            seen.add(cid)
        kind = c.get("kind")
        if kind not in KINDS:
            errs.append("ACC-BAD-KIND: %s kind not in %s" % (tag, "|".join(KINDS)))
        else:
            if kind == "command" and not (isinstance(c.get("cmd"), str) and c["cmd"].strip()):
                errs.append("ACC-COMMAND-NO-CMD: %s command check has empty cmd" % tag)
            if kind == "inspection" and not (isinstance(c.get("expect"), str) and c["expect"].strip()):
                errs.append("ACC-INSPECTION-NO-EXPECT: %s inspection check has empty expect" % tag)
            if kind == "human" and not (isinstance(c.get("question"), str) and c["question"].strip()):
                errs.append("ACC-HUMAN-NO-QUESTION: %s human check has empty question" % tag)
        if not (isinstance(c.get("criterion_ref"), str) and c["criterion_ref"].strip()):
            errs.append("ACC-NO-CRITERION-REF: %s criterion_ref missing/empty" % tag)
        rl = c.get("radius_links")
        if not isinstance(rl, list):
            errs.append("ACC-BAD-RADIUS-LINKS: %s radius_links not a list" % tag)
        else:
            for link in rl:
                if not isinstance(link, str) or not link:
                    errs.append("ACC-BAD-RADIUS-LINK: %s empty/non-string radius link" % tag)
                elif link.startswith("/") or ".." in link.split("/"):
                    errs.append("ACC-BAD-RADIUS-LINK: %s absolute or '..' radius link" % tag)
        # tamper: the content-derived id must equal the recomputed canonical id.
        if isinstance(cid, str) and kind in KINDS and isinstance(rl, list):
            if recompute_check_id(c) != cid:
                errs.append("ACC-TAMPER: %s check_id != recomputed canonical id (in-place mutation)" % tag)
    return errs


# ------------------------------------------------------------------ storage

def write_doc(doc, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, "acceptance.json")
    with open(path, "w", encoding="utf-8") as f:
        f.write(json.dumps(doc, sort_keys=True, indent=2, ensure_ascii=False) + "\n")
    return path


# ------------------------------------------------------------------ self-test

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


def _fixtures_dir():
    return os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                         "..", "..", "tests", "fixtures", "run"))


def _real_repo_porcelain():
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


def _run_cli(*args):
    return subprocess.run([sys.executable, "-B", os.path.abspath(__file__), *args],
                          capture_output=True, text=True)


def selftest():
    t = ST("acceptance")
    before = _real_repo_porcelain()
    fx = _fixtures_dir()
    plan = os.path.join(fx, "plan.md")
    orient = os.path.join(fx, "orientation.json")
    radius = os.path.join(fx, "radius.json")
    tmp = tempfile.mkdtemp(prefix="dmc-acc-")
    try:
        # -- compile the committed fixture (command criteria + orientation + radius) -----------
        doc = compile_acceptance(plan, orient, radius, tmp, None, None)
        t.ok("A1 compile emits a valid acceptance.json from the committed fixture",
             validate_acceptance(doc) == [] and doc["schema"] == SCHEMA)
        t.ok("A2 checks non-empty, ids unique + content-derived",
             len(doc["checks"]) >= 1
             and len({c["check_id"] for c in doc["checks"]}) == len(doc["checks"])
             and all(c["check_id"] == recompute_check_id(c) for c in doc["checks"]))
        t.ok("A3 command criteria classified as command with a cmd",
             any(c["kind"] == "command" and c["cmd"] for c in doc["checks"]))
        t.ok("A4 radius entry path carried as a radius_link (path-based coverage anchor)",
             any("src/app.py" in c["radius_links"] for c in doc["checks"]))
        t.ok("A5 deterministic: identical inputs => byte-identical artifact",
             json.dumps(compile_acceptance(plan, orient, radius, tmp, None, None), sort_keys=True)
             == json.dumps(doc, sort_keys=True))

        # -- inspection + human kinds via synthetic explicit-tagged criteria -------------------
        syn = _synthetic_plan([
            ("cmd crit", "`bin/dmc selftest` exits 0"),
            ("insp crit", "inspection: the output byte-unchanged and grep result empty"),
            ("human crit", "human: has the release gate signed off?"),
        ])
        synplan = os.path.join(tmp, "syn.md")
        with open(synplan, "w", encoding="utf-8") as f:
            f.write(syn)
        sdoc = compile_acceptance(synplan, orient, None, tmp, None, None)
        kinds = {c["kind"] for c in sdoc["checks"]}
        t.ok("A6 all three kinds representable (command|inspection|human)",
             {"command", "inspection", "human"} <= kinds and validate_acceptance(sdoc) == [])

        # -- NEGATIVE: untestable criterion (no method) is REFUSED -----------------------------
        badplan = os.path.join(tmp, "bad.md")
        with open(badplan, "w", encoding="utf-8") as f:
            f.write(_synthetic_plan([("make it work", "it should just work nicely")]))
        r_bad = _run_cli("compile", "--plan", badplan, "--orientation", orient,
                         "--out-dir", os.path.join(tmp, "o1"))
        t.ok("A7 NEG untestable criterion (no extractable method) REFUSED exit 3",
             r_bad.returncode == 3 and "ACC-UNTESTABLE-CRITERION" in r_bad.stdout)

        # -- NEGATIVE: non-APPROVED plan is REFUSED --------------------------------------------
        draftplan = os.path.join(tmp, "draft.md")
        with open(draftplan, "w", encoding="utf-8") as f:
            f.write(syn.replace("Status: APPROVED", "Status: DRAFT"))
        r_draft = _run_cli("compile", "--plan", draftplan, "--orientation", orient,
                           "--out-dir", os.path.join(tmp, "o2"))
        t.ok("A8 NEG non-APPROVED plan REFUSED exit 3",
             r_draft.returncode == 3 and "ACC-PLAN-NOT-APPROVED" in r_draft.stdout)

        # -- validator negative controls (hand-crafted invalid docs) ---------------------------
        valid = doc
        t.ok("A9 validator ACCEPTS the compiled artifact", validate_acceptance(valid) == [])
        empty = dict(valid, checks=[])
        t.ok("A10 NEG empty checks array REFUSED",
             any(e.startswith("ACC-EMPTY-CHECKS") for e in validate_acceptance(empty)))
        notimm = dict(valid, immutable=False)
        t.ok("A11 NEG immutable != true REFUSED",
             any(e.startswith("ACC-NOT-IMMUTABLE") for e in validate_acceptance(notimm)))
        emptycmd = _mutate_first(valid, "command", cmd="")
        t.ok("A12 NEG command check with empty cmd REFUSED",
             emptycmd is not None
             and any(e.startswith("ACC-COMMAND-NO-CMD") for e in validate_acceptance(emptycmd)))
        dup = dict(valid, checks=list(valid["checks"]) + [dict(valid["checks"][0])])
        t.ok("A13 NEG duplicate check_id REFUSED",
             any(e.startswith("ACC-DUP-CHECK-ID") for e in validate_acceptance(dup)))
        tampered = _mutate_first(valid, None, criterion_ref="TAMPERED-REF")
        t.ok("A14 NEG in-place body mutation (stale check_id) REFUSED",
             any(e.startswith("ACC-TAMPER") for e in validate_acceptance(tampered)))
        trav = _mutate_first(valid, None, radius_links=["../escape"])
        t.ok("A15 NEG radius_link with '..' REFUSED",
             any(e.startswith("ACC-BAD-RADIUS-LINK") for e in validate_acceptance(trav)))

        # -- end-to-end exit-code contract via the CLI validator -------------------------------
        good_path = write_doc(valid, os.path.join(tmp, "good"))
        r_ok = _run_cli("--validate", good_path)
        bad_doc_path = os.path.join(tmp, "bad.json")
        with open(bad_doc_path, "w", encoding="utf-8") as f:
            f.write(json.dumps(empty))
        r_no = _run_cli("--validate", bad_doc_path)
        t.ok("A16 CLI --validate: valid=>0, invalid=>3",
             r_ok.returncode == 0 and r_no.returncode == 3)

        # -- env independence: identical output under a hostile env ----------------------------
        r_env = subprocess.run([sys.executable, "-B", os.path.abspath(__file__),
                                "--validate", good_path],
                               capture_output=True, text=True,
                               env={"PATH": os.environ.get("PATH", ""),
                                    "GLM_API_KEY": "x", "DMC_VERIFY": "y"})
        t.ok("A17 env-independent: --validate identical under injected env",
             r_env.returncode == 0 and r_env.stdout == r_ok.stdout)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
        _sweep_pycache()

    after = _real_repo_porcelain()
    t.ok("A18 real repo git status --porcelain byte-identical before/after (or git absent)",
         before == after)
    t.done()


def _synthetic_plan(criteria):
    lines = ["- Criterion: %s\n  Verification Method: %s" % (c, m) for c, m in criteria]
    return (
        "# Plan: synthetic acceptance self-test plan\n\nPlan ID: dmc-selftest-acc\n\n"
        "## Goal\ng\n## User Intent\nfeature\n## Current Repo Findings\n- Finding: f\n  Source: s\n"
        "## Relevant Files\n| Path | Reason | Allowed to Edit |\n|---|---|---|\n| p | r | yes |\n"
        "## Out of Scope\n- x\n## Proposed Changes\n- Change: c\n  Files: p\n  Rationale: r\n"
        "## Acceptance Criteria\n" + "\n".join(lines) + "\n"
        "## Risks\n| Risk | Severity | Mitigation |\n|---|---|---|\n| r | low | m |\n"
        "## Assumptions\n| Assumption | Confidence | How to Verify |\n|---|---|---|\n| a | high | v |\n"
        "## Execution Tasks\n- [ ] DMC-T001: t\n  Files: p\n  Notes: n\n"
        "## Verification Commands\n| Command | Reason | Required |\n|---|---|---|\n| c | r | yes |\n"
        "## Approval Status\nStatus: APPROVED\nApprover: SYNTHETIC-FIXTURE\nApproved At: 2026-07-06\n"
    )


def _mutate_first(doc, kind, **fields):
    """Return a copy of doc with the first check of `kind` (any if None) mutated (id NOT recomputed)."""
    checks = [dict(c) for c in doc["checks"]]
    for c in checks:
        if kind is None or c["kind"] == kind:
            c.update(fields)
            return dict(doc, checks=checks)
    return None


def _sweep_pycache():
    d = os.path.join(os.path.dirname(os.path.abspath(__file__)), "__pycache__")
    shutil.rmtree(d, ignore_errors=True)


# ------------------------------------------------------------------------ main

def main():
    ap = argparse.ArgumentParser(prog="dmc-acceptance")
    ap.add_argument("command", nargs="?", choices=["compile"])
    ap.add_argument("--plan", metavar="FILE")
    ap.add_argument("--orientation", metavar="FILE")
    ap.add_argument("--radius", metavar="FILE")
    ap.add_argument("--out-dir", dest="out_dir", metavar="DIR")
    ap.add_argument("--root", default=".")
    ap.add_argument("--run-id", dest="run_id", metavar="ID")
    ap.add_argument("--work-id", dest="work_id", metavar="ID")
    ap.add_argument("--prev-hash", dest="prev_hash", metavar="HEX")
    ap.add_argument("--validate", metavar="FILE")
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args()

    if a.self_test:
        selftest()
        return

    if a.validate:
        try:
            doc = load_json_strict(a.validate)
        except FileNotFoundError:
            refuse(["ACC-UNREADABLE: file not found"])
        except Exception as e:
            refuse(["ACC-UNREADABLE: %s" % e.__class__.__name__])
        errs = validate_acceptance(doc)
        if errs:
            refuse(errs)
        print("VALID: %s conforms to %s" % (a.validate, SCHEMA))
        return

    if a.command == "compile":
        if not (a.plan and a.orientation):
            die("compile requires --plan FILE and --orientation FILE", 2)
        root = os.path.abspath(a.root)
        if a.out_dir:
            out_dir = os.path.abspath(a.out_dir)
        elif a.run_id:
            out_dir = os.path.join(root, ".harness", "runs", a.run_id)
        else:
            die("compile requires --out-dir DIR or --run-id ID", 2)
        doc = compile_acceptance(a.plan, a.orientation, a.radius, root, a.work_id, a.prev_hash)
        path = write_doc(doc, out_dir)
        print("wrote: %s" % path)
        print("checks: %d" % len(doc["checks"]))
        return

    die("usage: dmc-acceptance (compile --plan FILE --orientation FILE [--radius FILE] "
        "(--out-dir DIR | --run-id ID)) | --validate FILE | --self-test", 2)


if __name__ == "__main__":
    main()
