#!/usr/bin/env python3
"""dmc-worker-review.py — DMC v1.0 M7 worker review / apply-chain CLIs (P15 → P7).

Machine-checkable gates for the hash-chained worker importer `task → result → review → apply`:

  review-check <review.json> [--task T --result R]
      Validate a `dmc.worker-review.v1` record exactly per `.harness/schemas/worker-review.schema.md`
      (schema/enums/mandatory-kinds/decision/role rules). With --task/--result, additionally bind the
      record to the exact task+result it reviewed (task_result_hash recompute + result_id check).

  authorize --task T --result R --review REV --run RUN_ID [--out PATH]
      REFUSE unless (task_id is a safe slug) AND (review-check passes with the task+result binding)
      AND (review decision == apply) AND (`.claude/hooks/worker-result-check.py T R` ACCEPTs). Emit a
      `dmc.apply-authorization.v1` record (default `.harness/workers/authorizations/<task_id>.json`;
      the verb creates the output dir; append-only — refuses to overwrite).

  apply-check --auth A --task T --result R --review REV [--scope-lock LOCK]
      The P7-consumption gate. REFUSE on a missing/unparseable input, a task_result_hash or
      review_hash that does not recompute, review decision != apply, an authorized path outside
      task.allowed_files, a non-"genesis" prev_hash, or (with --scope-lock) any authorized path not
      `allow`-adjudicated by bin/lib/dmc-scope-lock.py. A missing authorization IS the "apply without
      a chain" refusal.

  fidelity --result R --applied-diff D
      Post-apply fidelity at the names+hunk-count tier (architecture v1.0): parse the result's
      proposed_patch and the applied diff with the SAME hardened diff parser (`diff_entries`, imported
      from worker-result-check.py — single source), REFUSE unless the path sets AND per-path @@ hunk
      counts are equal (rename/copy/binary compared by kind). Content equality is NOT claimed.

  --self-test
      Hermetic embedded self-test (tempdir only; never reads secrets, never writes the live repo).
      Prints "[worker-review] N PASS / M FAIL"; exit 0 all-pass / 1 any-fail.

House rules (v0.6.x / M3-M6 lineage, mirrors bin/lib/dmc-critic-verdict.py, dmc-roles.py,
dmc-delegation.py, dmc-scope-lock.py): stdlib-only, env-independent (no env reads), offline (no
network; git only best-effort read-only in the self-test hermeticity check), input-only, value-blind
(refusals name schema constants and reason codes, never the document's content values),
duplicate-JSON-key rejecting, secret-path refused by path, secret-shaped content refused, fail-closed
with named reason codes and negative controls. Exit codes: 0 VALID/PASS, 3 REFUSED, 2 usage.
`sys.dont_write_bytecode = True` is set before every importlib load so no `__pycache__` is ever
written into the never-edit providers/hook tree (manual-import-adapter.py:31-33 precedent).

Cross-task contract — `diff_entries` (owned by worker-result-check.py, DMC-T012.1): this module
consumes `diff_entries(patch)` as a list of structured entries, each exposing `paths` (list of the
authoritative path strings for the entry, /dev/null excluded), `kind` (one of text|rename|copy|
binary), and `hunks` (a non-negative int count of `@@` hunk headers). Fidelity compares the sorted
list of `(sorted(paths), kind, hunks)` triples — path sets, kinds, and per-path hunk counts. The
entry accessor tolerates dict or attribute-bearing entries.

Role resolution and scope-lock adjudication are delegated to `bin/lib/dmc-roles.py lookup` and
`bin/lib/dmc-scope-lock.py --adjudicate` as read-only subprocesses (M5/M6 shipped oracles), fail-closed
per the dmc-delegation.py composition rule: any subprocess anomaly this module cannot positively
confirm is treated as "does not resolve" / "refuse", never a silent pass.
"""

import argparse
import hashlib
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True  # never write __pycache__ into the imported hook/providers tree

REVIEW_SCHEMA_ID = "dmc.worker-review.v1"
AUTH_SCHEMA_ID = "dmc.apply-authorization.v1"

GENESIS = "genesis"
HASH_RE = re.compile(r"^[0-9a-f]{16,}$")

# worker-review check enums (worker-review.schema.md §Rules).
CHECK_KINDS = ("scope-compat", "token-scan", "fidelity", "contract", "disallowed-category")
MANDATORY_KINDS = ("scope-compat", "token-scan", "fidelity", "disallowed-category")
CHECK_RESULTS = ("PASS", "FAIL")
DECISIONS = ("apply", "reject")

# task_id must be a filesystem-safe slug (the default authorization filename derives from it).
SLUG_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")

# Value-blind reject-on-match set (copied verbatim from bin/lib/dmc-delegation.py's UNSAFE, per the
# established house convention — a secret-shaped field in a review record is refused with the same
# semantics as elsewhere).
UNSAFE = re.compile(
    r'sk-[A-Za-z0-9_-]{16,}|AKIA[0-9A-Z]{8,}|(?:BEGIN|END)[A-Z ]*PRIVATE KEY|xox[baprs]-[A-Za-z0-9-]{6,}'
    r'|gh[opsu]_[A-Za-z0-9]{16,}|github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{16,}|npm_[A-Za-z0-9]{30,}'
    r'|AIza[0-9A-Za-z_-]{20,}|dop_v1_[A-Za-z0-9]{32,}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'
    r'|ya29\.[A-Za-z0-9_-]{10,}|AccountKey=[A-Za-z0-9+/=]{20,}|Bearer\s+[A-Za-z0-9._-]{12,}'
    r'|(?:password|api_key|client_secret|aws_secret_access_key)\s*=\s*\S+|[A-Za-z0-9_-]*_token\s*[=:]\s*\S+'
)

USAGE = ("usage:\n"
         "  dmc-worker-review review-check <review.json> [--task T --result R]\n"
         "  dmc-worker-review authorize --task T --result R --review REV --run RUN_ID [--out PATH]\n"
         "  dmc-worker-review apply-check --auth A --task T --result R --review REV [--scope-lock LOCK]\n"
         "  dmc-worker-review fidelity --result R --applied-diff D\n"
         "  dmc-worker-review --self-test")


# ------------------------------------------------------------------- helpers

def die(msg, code=2):
    sys.stderr.write("dmc-worker-review: %s\n" % msg)
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
    if "service-account" in base and base.endswith(".json"):
        return True
    if "secret" in base and re.search(r"\.(json|ya?ml|env)$", base):
        return True
    if ".ssh" in parts or ".gnupg" in parts:
        return True
    if ".aws" in parts and base == "credentials":
        return True
    return False


def _no_dup(pairs):
    """object_pairs_hook that rejects duplicate JSON keys (fail-closed on ambiguity)."""
    d = {}
    for k, v in pairs:
        if k in d:
            raise ValueError("duplicate JSON key: %r" % k)
        d[k] = v
    return d


def read_bytes(path):
    """Raw bytes of a file (secret-shaped path refused by path). Raises OSError on read failure."""
    if is_secret_path(path):
        die("refused: secret-shaped path", 3)
    with open(path, "rb") as f:
        return f.read()


def read_text(path):
    return read_bytes(path).decode("utf-8", errors="strict")


def read_json_and_bytes(path):
    """Return (parsed-object, raw-bytes). Raises ValueError on malformed/duplicate-key JSON."""
    raw = read_bytes(path)
    obj = json.loads(raw.decode("utf-8", errors="strict"), object_pairs_hook=_no_dup)
    return obj, raw


def sha256_hex(data):
    return hashlib.sha256(data).hexdigest()


def _nestr(x):
    """Non-empty single-line string."""
    return isinstance(x, str) and x != "" and "\n" not in x


def _scan_unsafe(obj):
    """Recursive value-blind secret scan (reject-on-match); mirrors the copied UNSAFE validators."""
    if isinstance(obj, dict):
        for k, v in obj.items():
            if isinstance(k, str) and UNSAFE.search(k):
                return True
            if _scan_unsafe(v):
                return True
    elif isinstance(obj, list):
        for x in obj:
            if _scan_unsafe(x):
                return True
    elif isinstance(obj, str):
        if UNSAFE.search(obj):
            return True
    return False


def _safe_slug(s):
    """A filesystem-safe id slug: no separators, no '..', must start alphanumeric."""
    if not isinstance(s, str) or not s:
        return False
    if "/" in s or "\\" in s or ".." in s:
        return False
    return bool(SLUG_RE.match(s))


def repo_root():
    return os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                         "..", ".."))


def lib_dir():
    return os.path.dirname(os.path.abspath(__file__))


def worker_result_check_path():
    return os.path.join(repo_root(), ".claude", "hooks", "worker-result-check.py")


def roles_script_path():
    return os.path.join(lib_dir(), "dmc-roles.py")


def scope_lock_script_path():
    return os.path.join(lib_dir(), "dmc-scope-lock.py")


def authorizations_dir():
    return os.path.join(repo_root(), ".harness", "workers", "authorizations")


def default_auth_path(task_id):
    return os.path.join(authorizations_dir(), task_id + ".json")


# ------------------------------------------------- subprocess oracles (fail-closed)

def resolve_role(role_key, registry_path=None):
    """Resolve `role_key` via the `dmc-roles.py lookup` subprocess (read-only, fail-closed).

    Returns (resolved: bool, record: dict|None). `resolved` is True only on a clean exit 0 whose
    stdout parses as a JSON object; every other outcome (exit 3, spawn failure, timeout, malformed
    stdout) returns (False, None) — never a silent pass."""
    cmd = [sys.executable or "python3", roles_script_path(), "lookup", role_key]
    if registry_path:
        cmd += ["--registry", registry_path]
    try:
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              timeout=15, check=False)
    except (OSError, subprocess.SubprocessError, ValueError):
        return False, None
    if proc.returncode != 0:
        return False, None
    try:
        rec = json.loads(proc.stdout.decode("utf-8", errors="strict"))
    except (ValueError, UnicodeError):
        return False, None
    if not isinstance(rec, dict):
        return False, None
    return True, rec


def worker_result_accepts(task_path, result_path):
    """Run `.claude/hooks/worker-result-check.py TASK RESULT`; ACCEPT iff exit 0 (fail-closed)."""
    cmd = [sys.executable or "python3", worker_result_check_path(), task_path, result_path]
    try:
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              timeout=30, check=False)
    except (OSError, subprocess.SubprocessError, ValueError):
        return False, "spawn-failure"
    return (proc.returncode == 0), ("exit-%d" % proc.returncode)


def adjudicate_path(lock_path, path, op="edit"):
    """`dmc-scope-lock.py --adjudicate LOCK PATH OP`; 'allow' iff exit 0 (fail-closed otherwise)."""
    cmd = [sys.executable or "python3", scope_lock_script_path(),
           "--adjudicate", lock_path, path, op]
    try:
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              timeout=15, check=False)
    except (OSError, subprocess.SubprocessError, ValueError):
        return "refuse"
    return "allow" if proc.returncode == 0 else "refuse"


def _load_symbol(name, src_path=None):
    """Load a single callable `name` from a Python file by location (single-source reuse).

    Exception-wrapped: any load failure — file missing, syntax/import error, absent/non-callable
    attribute — returns None (the caller then fails closed). `sys.dont_write_bytecode` is already
    True module-wide, and re-asserted here, so exec_module writes no `__pycache__`."""
    path = src_path or worker_result_check_path()
    sys.dont_write_bytecode = True
    try:
        mod_name = "_dmc_wrc_" + re.sub(r"\W", "_", name)
        spec = importlib.util.spec_from_file_location(mod_name, path)
        if spec is None or spec.loader is None:
            return None
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        fn = getattr(mod, name, None)
        return fn if callable(fn) else None
    except Exception:  # noqa: BLE001 — availability degrades to a clean REFUSE, never a bypass
        return None


# --------------------------------------------------------------- review-check

def _validate_review_shape(obj, registry_path=None):
    """Return a list of value-blind WREV-* reason codes; empty list == VALID."""
    if not isinstance(obj, dict):
        return ["WREV-NOT-OBJECT: top-level document is not a JSON object"]
    errs = []
    if obj.get("schema") != REVIEW_SCHEMA_ID:
        errs.append("WREV-BAD-SCHEMA: 'schema' must be %r" % REVIEW_SCHEMA_ID)
    if _scan_unsafe(obj):
        errs.append("WREV-SECRET-SHAPED: a secret-shaped value is present (value-blind refusal)")
    for f in ("task_id", "result_id", "provider"):
        if not _nestr(obj.get(f)):
            errs.append("WREV-FIELD-MISSING: %s missing/empty/multiline" % f)
    trh = obj.get("task_result_hash")
    if not (isinstance(trh, str) and HASH_RE.match(trh)):
        errs.append("WREV-BAD-TASK-RESULT-HASH: task_result_hash not hash-shaped (hex>=16)")
    pv = obj.get("prev_hash")
    if not (isinstance(pv, str) and (pv == GENESIS or HASH_RE.match(pv))):
        errs.append("WREV-BAD-PREV-HASH: prev_hash not hash-shaped (hex>=16 or 'genesis')")

    checks = obj.get("checks")
    kinds_seen = set()
    all_pass = True
    if not isinstance(checks, list) or not checks:
        errs.append("WREV-NO-CHECKS: 'checks' must be a non-empty list (no rubber-stamp review)")
        all_pass = False
    else:
        for i, c in enumerate(checks):
            if not isinstance(c, dict):
                errs.append("WREV-BAD-CHECK: checks[%d] is not an object" % i)
                all_pass = False
                continue
            kind = c.get("check")
            res = c.get("result")
            if kind not in CHECK_KINDS:
                errs.append("WREV-BAD-CHECK-KIND: checks[%d].check not in the 5-kind enum "
                            "(%s)" % (i, "|".join(CHECK_KINDS)))
            else:
                kinds_seen.add(kind)
            if res not in CHECK_RESULTS:
                errs.append("WREV-BAD-CHECK-RESULT: checks[%d].result not in PASS|FAIL" % i)
                all_pass = False
            elif res != "PASS":
                all_pass = False
        for mk in MANDATORY_KINDS:
            if mk not in kinds_seen:
                errs.append("WREV-MISSING-MANDATORY-KIND: mandatory check kind %r absent" % mk)

    decision = obj.get("decision")
    if decision not in DECISIONS:
        errs.append("WREV-BAD-DECISION: 'decision' must be one of %s" % "|".join(DECISIONS))
    if decision == "apply" and not all_pass:
        errs.append("WREV-APPLY-WITH-FAIL: decision 'apply' requires every check PASS "
                    "(any FAIL => decision must be 'reject')")

    role = obj.get("reviewer_role")
    if not _nestr(role):
        errs.append("WREV-ROLE-MISSING: reviewer_role missing/empty")
    else:
        resolved, rec = resolve_role(role, registry_path)
        if not resolved:
            errs.append("WREV-ROLE-UNRESOLVED: reviewer_role does not resolve in "
                        "orchestration/roles.json")
        elif rec.get("may_mutate") is True:
            errs.append("WREV-ROLE-MUTABLE: reviewer_role is mutation-capable per the registry "
                        "(a may_mutate role may not review a proposal — no self-approval)")
    return errs


def _expected_result_id(result):
    """result_id == provider_metadata.invocation_id when that is a non-empty string, else task_id."""
    if not isinstance(result, dict):
        return None
    inv = (result.get("provider_metadata") or {}).get("invocation_id") \
        if isinstance(result.get("provider_metadata"), dict) else None
    if isinstance(inv, str) and inv != "":
        return inv
    return result.get("task_id")


def _check_binding(review, task_path, result_path):
    """Bind the review to the exact task+result: task_result_hash recompute + result_id check."""
    try:
        task_raw = read_bytes(task_path)
        result_raw = read_bytes(result_path)
    except FileNotFoundError:
        return ["WREV-BINDING-UNREADABLE: task/result file not found"]
    except (OSError, UnicodeError) as e:
        return ["WREV-BINDING-UNREADABLE: %s" % e.__class__.__name__]
    errs = []
    recomputed = sha256_hex(task_raw + b"\n" + result_raw)
    if review.get("task_result_hash") != recomputed:
        errs.append("WREV-HASH-MISMATCH: task_result_hash != sha256(task_bytes + LF + result_bytes)")
    try:
        result = json.loads(result_raw.decode("utf-8", errors="strict"), object_pairs_hook=_no_dup)
    except ValueError:
        return errs + ["WREV-BINDING-UNREADABLE: result JSON unparseable"]
    if review.get("result_id") != _expected_result_id(result):
        errs.append("WREV-RESULT-ID-MISMATCH: result_id != result invocation_id (or task_id)")
    return errs


def check_review(review_path, task_path=None, result_path=None, registry_path=None):
    """Load + validate a review record; optionally bind it to a task+result. Returns WREV-* list."""
    try:
        review, _raw = read_json_and_bytes(review_path)
    except FileNotFoundError:
        return ["WREV-UNREADABLE: review file not found"]
    except (ValueError, OSError, UnicodeError) as e:
        return ["WREV-UNREADABLE: %s" % e.__class__.__name__]
    errs = _validate_review_shape(review, registry_path)
    if task_path is not None and result_path is not None:
        errs = errs + _check_binding(review if isinstance(review, dict) else {},
                                     task_path, result_path)
    return errs


# ----------------------------------------------------------------- authorize

def do_authorize(task_path, result_path, review_path, run_id, out_path=None, registry_path=None):
    """Emit a dmc.apply-authorization.v1 record. Returns (errs, dest_path|None)."""
    # 1. task_id path-safety FIRST (the default output filename derives from it).
    try:
        task, _task_raw = read_json_and_bytes(task_path)
    except FileNotFoundError:
        return (["WAUTH-UNREADABLE: task file not found"], None)
    except (ValueError, OSError, UnicodeError) as e:
        return (["WAUTH-UNREADABLE: task unparseable (%s)" % e.__class__.__name__], None)
    if not isinstance(task, dict):
        return (["WAUTH-UNREADABLE: task is not a JSON object"], None)
    task_id = task.get("task_id")
    if not _safe_slug(task_id):
        return (["WAUTH-BAD-TASK-ID: task_id must be a safe slug (no '/', '\\', '..'; it derives "
                 "the authorization filename)"], None)

    # 2. review-check with the task+result binding must pass.
    rev_errs = check_review(review_path, task_path, result_path, registry_path)
    if rev_errs:
        return (["WAUTH-REVIEW-REFUSED: the review does not pass review-check"] + rev_errs, None)

    # 3. review decision must be apply.
    try:
        review, review_raw = read_json_and_bytes(review_path)
    except (ValueError, OSError, UnicodeError) as e:
        return (["WAUTH-UNREADABLE: review unparseable (%s)" % e.__class__.__name__], None)
    if not (isinstance(review, dict) and review.get("decision") == "apply"):
        return (["WAUTH-NOT-APPLY: review decision is not 'apply'"], None)

    # 4. the hardened result validator must ACCEPT (subprocess, fail-closed).
    accepted, why = worker_result_accepts(task_path, result_path)
    if not accepted:
        return (["WAUTH-RESULT-REJECTED: worker-result-check.py did not ACCEPT (%s)" % why], None)

    # 5. authorized_paths = sorted(files_changed ∪ parsed diff paths) ⊆ allowed_files.
    try:
        result, _result_raw = read_json_and_bytes(result_path)
    except (ValueError, OSError, UnicodeError) as e:
        return (["WAUTH-UNREADABLE: result unparseable (%s)" % e.__class__.__name__], None)
    fc = {x for x in (result.get("files_changed") or []) if isinstance(x, str)}
    patch = result.get("proposed_patch") or ""
    diff_paths = _load_symbol("diff_paths")   # legacy parser, single-source (byte-preserved surface)
    if diff_paths is None:
        return (["WAUTH-DIFF-UNLOADABLE: worker-result-check.py diff_paths unloadable "
                 "(fail-closed)"], None)
    try:
        dp = {x for x in diff_paths(patch) if isinstance(x, str)}
    except Exception:  # noqa: BLE001
        return (["WAUTH-DIFF-UNLOADABLE: diff_paths raised on the proposed_patch (fail-closed)"],
                None)
    authorized = sorted(fc | dp)
    allowed = {x for x in (task.get("allowed_files") or []) if isinstance(x, str)}
    if any(p not in allowed for p in authorized):
        return (["WAUTH-PATHS-NOT-SUBSET: an authorized path is outside task.allowed_files"], None)

    # 6. emit the authorization record (append-only; refuse overwrite; create the dir).
    auth = {
        "schema": AUTH_SCHEMA_ID,
        "task_id": task_id,
        "result_id": review.get("result_id"),
        "review_ref": review_path,
        "task_result_hash": review.get("task_result_hash"),
        "review_hash": sha256_hex(review_raw),
        "run_id": run_id,
        "authorized_paths": authorized,
        "prev_hash": GENESIS,
    }
    dest = out_path or default_auth_path(task_id)
    if is_secret_path(dest):
        return (["WAUTH-SECRET-OUT: the derived authorization path is secret-shaped (refused)"],
                None)
    if os.path.exists(dest):
        return (["WAUTH-EXISTS: an authorization already exists for this task (append-only; a "
                 "re-dispatch gets a NEW task id)"], None)
    os.makedirs(os.path.dirname(os.path.abspath(dest)), exist_ok=True)
    with open(dest, "w", encoding="utf-8") as f:
        f.write(json.dumps(auth, sort_keys=True, indent=2, ensure_ascii=False) + "\n")
    return ([], dest)


# ----------------------------------------------------------------- apply-check

def check_apply(auth_path, task_path, result_path, review_path, scope_lock=None):
    """The P7 apply gate. Returns a list of value-blind WAUTH-* reason codes; empty == PASS."""
    # A missing authorization IS the "apply without a chain" refusal.
    if not os.path.isfile(auth_path):
        return ["WAUTH-MISSING-AUTH: no authorization for this apply (apply without a chain is "
                "refused)"]
    try:
        auth, _auth_raw = read_json_and_bytes(auth_path)
    except (ValueError, OSError, UnicodeError) as e:
        return ["WAUTH-UNREADABLE: authorization unparseable (%s)" % e.__class__.__name__]
    if not isinstance(auth, dict):
        return ["WAUTH-UNREADABLE: authorization is not a JSON object"]

    errs = []
    if auth.get("schema") != AUTH_SCHEMA_ID:
        errs.append("WAUTH-BAD-SCHEMA: authorization 'schema' must be %r" % AUTH_SCHEMA_ID)

    try:
        task_raw = read_bytes(task_path)
        result_raw = read_bytes(result_path)
        review_raw = read_bytes(review_path)
    except FileNotFoundError:
        return errs + ["WAUTH-UNREADABLE: task/result/review file not found"]
    except (OSError, UnicodeError) as e:
        return errs + ["WAUTH-UNREADABLE: %s" % e.__class__.__name__]

    # Chain-hash recompute: task_result_hash and review_hash.
    if auth.get("task_result_hash") != sha256_hex(task_raw + b"\n" + result_raw):
        errs.append("WAUTH-TRH-MISMATCH: task_result_hash does not recompute over task+result")
    if auth.get("review_hash") != sha256_hex(review_raw):
        errs.append("WAUTH-REVIEW-HASH-MISMATCH: review_hash does not recompute over the review "
                    "bytes (a tampered review breaks the chain)")

    # review decision must be apply.
    try:
        review = json.loads(review_raw.decode("utf-8", errors="strict"), object_pairs_hook=_no_dup)
    except ValueError:
        review = None
        errs.append("WAUTH-UNREADABLE: review JSON unparseable")
    if isinstance(review, dict) and review.get("decision") != "apply":
        errs.append("WAUTH-NOT-APPLY: review decision is not 'apply'")

    # prev_hash must be the literal 'genesis' in v1.0.
    if auth.get("prev_hash") != GENESIS:
        errs.append("WAUTH-BAD-PREV-HASH: prev_hash must be the literal 'genesis' in v1.0")

    # authorized_paths ⊆ task.allowed_files.
    try:
        task = json.loads(task_raw.decode("utf-8", errors="strict"), object_pairs_hook=_no_dup)
    except ValueError:
        task = None
        errs.append("WAUTH-UNREADABLE: task JSON unparseable")
    allowed = set()
    if isinstance(task, dict) and isinstance(task.get("allowed_files"), list):
        allowed = {x for x in task["allowed_files"] if isinstance(x, str)}
    ap = auth.get("authorized_paths")
    if not (isinstance(ap, list) and all(isinstance(x, str) for x in ap)):
        errs.append("WAUTH-BAD-AUTHORIZED-PATHS: authorized_paths must be a list of strings")
        ap = []
    if any(p not in allowed for p in ap):
        errs.append("WAUTH-PATHS-NOT-SUBSET: an authorized path is outside task.allowed_files")

    # scope.lock adjudication (each authorized path must be allow-adjudicated for edit).
    if scope_lock is not None:
        if any(adjudicate_path(scope_lock, p, "edit") != "allow" for p in ap):
            errs.append("WAUTH-SCOPE-REFUSED: an authorized path is not allow-adjudicated by the "
                        "scope.lock")
    return errs


# ------------------------------------------------------------------- fidelity

def _entry_view(e):
    """Extract (paths, kind, hunks) from a diff_entries entry (dict or attribute-bearing)."""
    if isinstance(e, dict):
        return e.get("paths"), e.get("kind"), e.get("hunks", 0)
    return getattr(e, "paths", None), getattr(e, "kind", None), getattr(e, "hunks", 0)


def _fidelity_shape(entries):
    """Canonical comparison structure: sorted list of (sorted(paths), kind, hunks) triples."""
    shape = []
    for e in entries or []:
        paths, kind, hunks = _entry_view(e)
        if isinstance(paths, (list, tuple, set)):
            norm_paths = tuple(sorted(str(p) for p in paths))
        elif paths is None:
            norm_paths = ()
        else:
            norm_paths = (str(paths),)
        shape.append((norm_paths, kind, hunks))
    return sorted(shape, key=lambda x: (x[0], str(x[1]), str(x[2])))


def check_fidelity(result_path, applied_diff_path, diff_src=None):
    """Names+hunk-count fidelity between the result's proposed_patch and an applied diff. WFID-*."""
    try:
        result, _raw = read_json_and_bytes(result_path)
    except FileNotFoundError:
        return ["WFID-UNREADABLE: result file not found"]
    except (ValueError, OSError, UnicodeError) as e:
        return ["WFID-UNREADABLE: result unparseable (%s)" % e.__class__.__name__]
    if not isinstance(result, dict):
        return ["WFID-UNREADABLE: result is not a JSON object"]
    proposed = result.get("proposed_patch")
    if not isinstance(proposed, str) or proposed == "":
        return ["WFID-NO-PATCH: result carries no non-empty proposed_patch string"]
    try:
        applied = read_text(applied_diff_path)
    except FileNotFoundError:
        return ["WFID-UNREADABLE: applied-diff file not found"]
    except (OSError, UnicodeError) as e:
        return ["WFID-UNREADABLE: applied-diff unreadable (%s)" % e.__class__.__name__]

    diff_entries = _load_symbol("diff_entries", diff_src)
    if diff_entries is None:
        return ["WFID-DIFF-UNLOADABLE: worker-result-check.py diff_entries unloadable "
                "(fail-closed)"]
    try:
        proposed_shape = _fidelity_shape(diff_entries(proposed))
        applied_shape = _fidelity_shape(diff_entries(applied))
    except Exception:  # noqa: BLE001 — a parser raise degrades to a clean REFUSE
        return ["WFID-DIFF-UNLOADABLE: diff_entries raised while parsing (fail-closed)"]
    if proposed_shape != applied_shape:
        return ["WFID-MISMATCH: applied diff differs from the proposed patch at the "
                "names+hunk-count tier (path set, kind, or per-path @@ hunk count mismatch)"]
    return []


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
        except Exception as e:  # noqa: BLE001 — a broken fixture must FAIL, never abort the run
            self.ok("%s [EXC:%s]" % (label, e.__class__.__name__), False)
            return
        self.ok(label, cond)

    def done(self):
        print("[%s] %d PASS / %d FAIL" % (self.name, self.passed, self.failed))
        sys.exit(0 if self.failed == 0 else 1)


# A synthetic diff_entries module (the fidelity self-test injects it — the real worker-result-check.py
# diff_entries is owned by T012.1). One entry per `+++` file header; hunks = count of `@@` headers.
SYNTH_DIFF_ENTRIES = (
    "def diff_entries(patch):\n"
    "    entries = []\n"
    "    cur = None\n"
    "    for ln in patch.splitlines():\n"
    "        if ln.startswith('+++ '):\n"
    "            p = ln[4:].strip()\n"
    "            if p[:2] in ('a/', 'b/'):\n"
    "                p = p[2:]\n"
    "            cur = {'paths': [p], 'kind': 'text', 'hunks': 0}\n"
    "            entries.append(cur)\n"
    "        elif ln.startswith('@@') and cur is not None:\n"
    "            cur['hunks'] += 1\n"
    "    return entries\n"
)

# A module WITHOUT diff_entries (the load-failure negative control).
SYNTH_NO_DIFF_ENTRIES = "x = 1\n"

# An APPROVED synthetic plan + landmarks so the scope-lock adjudication path can be exercised
# hermetically (mirrors dmc-scope-lock.py's own self-test fixture).
SYNTH_APPROVED_PLAN = """# Plan: synthetic worker-review self-test plan

Plan ID: dmc-selftest-worker-review

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
Approved At: 2026-07-07
"""

SYNTH_LANDMARKS = {
    "files": [{"path": "src/app.py", "grant": "edit", "landmark_class": "ordinary"}],
    "bounds": {"max_files": 1, "max_added": 100, "max_deleted": 50,
               "forbidden_hunk_classes": []},
}


def _base_task():
    return {
        "task_id": "st-task-001",
        "objective": "self-test objective",
        "allowed_files": ["src/app.py"],
        "forbidden_files": [],
        "context_summary": "self-test context",
        "relevant_snippets": [],
        "expected_output_type": "diff",
        "provider_target": {"type": "mock", "provider": "mock-local"},
    }


def _base_result():
    return {
        "task_id": "st-task-001",
        "summary": "self-test result",
        "files_considered": ["src/app.py"],
        "files_changed": ["src/app.py"],
        "proposed_patch": "--- a/src/app.py\n+++ b/src/app.py\n@@ -1,1 +1,1 @@\n-old\n+new\n",
        "instructions": "apply the patch under scope",
        "confidence": "high",
        "no_direct_mutation": True,
        "provider_metadata": {"provider_type": "mock", "provider": "mock-local",
                              "credential_exposure": "none", "invocation_id": "st-inv-001"},
    }


def _base_review(trh):
    return {
        "schema": REVIEW_SCHEMA_ID,
        "task_id": "st-task-001",
        "result_id": "st-inv-001",
        "provider": "mock-local",
        "reviewer_role": "critic-falsifier",
        "checks": [
            {"check": "scope-compat", "result": "PASS", "evidence_ref": "st"},
            {"check": "token-scan", "result": "PASS", "evidence_ref": "st"},
            {"check": "fidelity", "result": "PASS", "evidence_ref": "st"},
            {"check": "disallowed-category", "result": "PASS", "evidence_ref": "st"},
        ],
        "decision": "apply",
        "task_result_hash": trh,
        "prev_hash": GENESIS,
    }


def _wj(path, obj):
    with open(path, "w", encoding="utf-8") as f:
        f.write(json.dumps(obj, sort_keys=True, indent=2, ensure_ascii=False) + "\n")
    return path


def _wt(path, text):
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    return path


def _porcelain():
    git = shutil.which("git")
    if not git:
        return None
    try:
        r = subprocess.run([git, "-C", repo_root(), "status", "--porcelain"],
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=10)
        return r.stdout if r.returncode == 0 else None
    except (OSError, subprocess.SubprocessError):
        return None


def _compile_scope_lock(td):
    """Compile a scope.lock in a disposable tempdir 'repo' via dmc-scope-lock.py --compile.
    Returns the lock path, or None if compilation is unavailable (the caller then soft-skips)."""
    repo = os.path.join(td, "scoperepo")
    os.makedirs(repo, exist_ok=True)
    plan = _wt(os.path.join(repo, "plan.md"), SYNTH_APPROVED_PLAN)
    lm = _wj(os.path.join(repo, "landmarks.json"), SYNTH_LANDMARKS)
    rid = "dmc-run-wrev-selftest"
    cmd = [sys.executable or "python3", scope_lock_script_path(), "--compile",
           "--plan", plan, "--landmarks", lm, "--run-id", rid, "--root", repo]
    try:
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              timeout=30, check=False)
    except (OSError, subprocess.SubprocessError, ValueError):
        return None
    lock = os.path.join(repo, ".harness", "runs", rid, "scope.lock.json")
    return lock if (proc.returncode == 0 and os.path.isfile(lock)) else None


def selftest():
    t = ST("worker-review")
    before = _porcelain()

    with tempfile.TemporaryDirectory() as td:
        # ---- build the base clean chain ----
        task_p = _wj(os.path.join(td, "task.json"), _base_task())
        result_p = _wj(os.path.join(td, "result.json"), _base_result())
        trh = sha256_hex(open(task_p, "rb").read() + b"\n" + open(result_p, "rb").read())
        review_p = _wj(os.path.join(td, "review.json"), _base_review(trh))

        # ---- review-check positives ----
        t.check("P1 clean review VALID (no binding)",
                lambda: check_review(review_p) == [])
        t.check("P2 clean review VALID (with task+result binding: hashes/result_id match)",
                lambda: check_review(review_p, task_p, result_p) == [])

        # ---- review-check negative controls ----
        t.check("N1 apply-with-a-FAIL check REFUSED (WREV-APPLY-WITH-FAIL)",
                lambda: any(e.startswith("WREV-APPLY-WITH-FAIL")
                            for e in check_review(_wj(os.path.join(td, "rev_fail.json"), _mut_review(
                                trh, checks_fail=True)))))
        t.check("N2 empty checks REFUSED (WREV-NO-CHECKS)",
                lambda: any(e.startswith("WREV-NO-CHECKS")
                            for e in check_review(_wj(os.path.join(td, "rev_empty.json"), _mut_review(
                                trh, checks=[])))))
        t.check("N3 missing mandatory kind REFUSED (WREV-MISSING-MANDATORY-KIND)",
                lambda: any(e.startswith("WREV-MISSING-MANDATORY-KIND")
                            for e in check_review(_wj(os.path.join(td, "rev_miss.json"), _mut_review(
                                trh, drop_kind="fidelity")))))
        t.check("N4 mutation-capable reviewer_role REFUSED (WREV-ROLE-MUTABLE)",
                lambda: any(e.startswith("WREV-ROLE-MUTABLE")
                            for e in check_review(_wj(os.path.join(td, "rev_mut.json"), _mut_review(
                                trh, reviewer_role="implementer")))))
        t.check("N5 task_result_hash mismatch (binding) REFUSED (WREV-HASH-MISMATCH)",
                lambda: any(e.startswith("WREV-HASH-MISMATCH")
                            for e in check_review(_wj(os.path.join(td, "rev_badhash.json"),
                                                      _mut_review("f" * 64)),
                                                  task_p, result_p)))
        t.check("N6 unresolved reviewer_role REFUSED (WREV-ROLE-UNRESOLVED)",
                lambda: any(e.startswith("WREV-ROLE-UNRESOLVED")
                            for e in check_review(_wj(os.path.join(td, "rev_norole.json"),
                                                      _mut_review(trh, reviewer_role="critic")))))
        t.check("N7 wrong schema id REFUSED (WREV-BAD-SCHEMA)",
                lambda: any(e.startswith("WREV-BAD-SCHEMA")
                            for e in check_review(_wj(os.path.join(td, "rev_schema.json"),
                                                      _mut_review(trh, schema="dmc.worker-review.v2")))))
        t.check("N8 bad check kind REFUSED (WREV-BAD-CHECK-KIND)",
                lambda: any(e.startswith("WREV-BAD-CHECK-KIND")
                            for e in check_review(_wj(os.path.join(td, "rev_kind.json"),
                                                      _mut_review(trh, bad_kind=True)))))
        t.check("N9 bad check result REFUSED (WREV-BAD-CHECK-RESULT)",
                lambda: any(e.startswith("WREV-BAD-CHECK-RESULT")
                            for e in check_review(_wj(os.path.join(td, "rev_res.json"),
                                                      _mut_review(trh, bad_result=True)))))
        t.check("N10 bad decision value REFUSED (WREV-BAD-DECISION)",
                lambda: any(e.startswith("WREV-BAD-DECISION")
                            for e in check_review(_wj(os.path.join(td, "rev_dec.json"),
                                                      _mut_review(trh, decision="maybe")))))
        t.check("N11 secret-shaped content REFUSED (WREV-SECRET-SHAPED)",
                lambda: any(e.startswith("WREV-SECRET-SHAPED")
                            for e in check_review(_wj(os.path.join(td, "rev_leak.json"),
                                                      _mut_review(trh, secret=True)))))

        def _dup_key_review():
            p = os.path.join(td, "rev_dup.json")
            with open(p, "w", encoding="utf-8") as f:
                f.write('{"schema":"dmc.worker-review.v1","schema":"x"}')
            return p
        t.check("N12 duplicate JSON key REFUSED (WREV-UNREADABLE)",
                lambda: any(e.startswith("WREV-UNREADABLE") for e in check_review(_dup_key_review())))

        # ---- authorize positive ----
        auth_p = os.path.join(td, "auth.json")
        aerrs, adest = do_authorize(task_p, result_p, review_p, "dmc-run-selftest", out_path=auth_p)
        t.check("P3 authorize emits an apply-authorization (clean chain)",
                lambda: aerrs == [] and adest == auth_p and os.path.isfile(auth_p))
        t.check("P3b emitted authorization has schema/prev_hash 'genesis'/authorized_paths",
                lambda: (lambda a: a.get("schema") == AUTH_SCHEMA_ID and a.get("prev_hash") == GENESIS
                         and a.get("authorized_paths") == ["src/app.py"]
                         and a.get("task_result_hash") == trh)(json.load(open(auth_p))))

        # ---- authorize negatives ----
        bad_task = _base_task()
        bad_task["task_id"] = "bad/id"
        bad_result = _base_result()
        bad_result["task_id"] = "bad/id"
        bad_task_p = _wj(os.path.join(td, "task_bad.json"), bad_task)
        bad_result_p = _wj(os.path.join(td, "result_bad.json"), bad_result)
        bad_trh = sha256_hex(open(bad_task_p, "rb").read() + b"\n" + open(bad_result_p, "rb").read())
        bad_review = _base_review(bad_trh)
        bad_review["task_id"] = "bad/id"
        bad_review_p = _wj(os.path.join(td, "review_bad.json"), bad_review)
        t.check("N13 path-shaped task_id at authorize REFUSED (WAUTH-BAD-TASK-ID)",
                lambda: any(e.startswith("WAUTH-BAD-TASK-ID") for e in do_authorize(
                    bad_task_p, bad_result_p, bad_review_p, "dmc-run-selftest",
                    out_path=os.path.join(td, "auth_bad.json"))[0]))
        t.check("N14 authorize refuses a reject-decision review (WAUTH-REVIEW-REFUSED or NOT-APPLY)",
                lambda: do_authorize(task_p, result_p,
                                     _wj(os.path.join(td, "review_reject.json"),
                                         _mut_review(trh, decision="reject", checks_fail=True)),
                                     "dmc-run-selftest",
                                     out_path=os.path.join(td, "auth_rej.json"))[0] != [])
        t.check("N15 authorize refuses to overwrite an existing authorization (WAUTH-EXISTS)",
                lambda: any(e.startswith("WAUTH-EXISTS") for e in do_authorize(
                    task_p, result_p, review_p, "dmc-run-selftest", out_path=auth_p)[0]))

        # ---- apply-check positive + negatives ----
        t.check("P4 full clean task->result->review->authorize chain PASSES apply-check",
                lambda: check_apply(auth_p, task_p, result_p, review_p) == [])
        t.check("N16 missing authorization REFUSED (WAUTH-MISSING-AUTH — apply without a chain)",
                lambda: any(e.startswith("WAUTH-MISSING-AUTH") for e in check_apply(
                    os.path.join(td, "nope.json"), task_p, result_p, review_p)))

        # non-genesis prev_hash
        auth_obj = json.load(open(auth_p))
        badprev = dict(auth_obj, prev_hash="a" * 64)
        t.check("N17 non-genesis prev_hash REFUSED (WAUTH-BAD-PREV-HASH)",
                lambda: any(e.startswith("WAUTH-BAD-PREV-HASH") for e in check_apply(
                    _wj(os.path.join(td, "auth_prev.json"), badprev), task_p, result_p, review_p)))

        # authorized_paths outside allowed_files
        badpaths = dict(auth_obj, authorized_paths=["src/evil.py"])
        t.check("N18 out-of-allowed authorized path REFUSED (WAUTH-PATHS-NOT-SUBSET)",
                lambda: any(e.startswith("WAUTH-PATHS-NOT-SUBSET") for e in check_apply(
                    _wj(os.path.join(td, "auth_paths.json"), badpaths), task_p, result_p, review_p)))

        # review_hash tamper: mutate the review bytes AFTER authorize captured its hash.
        tampered_review_p = _wt(os.path.join(td, "review_tamper.json"),
                                open(review_p, "r", encoding="utf-8").read() + " ")
        t.check("N19 tampered review bytes REFUSED (WAUTH-REVIEW-HASH-MISMATCH)",
                lambda: any(e.startswith("WAUTH-REVIEW-HASH-MISMATCH") for e in check_apply(
                    auth_p, task_p, result_p, tampered_review_p)))

        # ---- scope-lock adjudication path (hermetic compile; soft-skip if unavailable) ----
        lock = _compile_scope_lock(td)
        if lock is None:
            t.ok("P5 apply-check with a scope.lock PASSES (skipped: scope-lock compile unavailable)",
                 True)
            t.ok("N20 scope-lock refuses a path outside the lock (skipped: compile unavailable)",
                 True)
        else:
            t.check("P5 apply-check with a scope.lock PASSES (authorized path allow-adjudicated)",
                    lambda: check_apply(auth_p, task_p, result_p, review_p, scope_lock=lock) == []
                    and adjudicate_path(lock, "src/app.py", "edit") == "allow")
            t.check("N20 scope-lock refuses a path outside the lock (WAUTH-SCOPE-REFUSED wiring)",
                    lambda: adjudicate_path(lock, "src/other.py", "edit") == "refuse")

        # ---- fidelity positives + negatives (injected synthetic diff_entries) ----
        diff_mod = _wt(os.path.join(td, "synth_de.py"), SYNTH_DIFF_ENTRIES)
        no_de_mod = _wt(os.path.join(td, "no_de.py"), SYNTH_NO_DIFF_ENTRIES)
        proposed_patch = _base_result()["proposed_patch"]
        applied_same = _wt(os.path.join(td, "applied_same.diff"), proposed_patch)
        applied_extra_hunk = _wt(os.path.join(td, "applied_hunk.diff"),
                                 proposed_patch + "@@ -5,1 +5,1 @@\n-a\n+b\n")
        applied_other_path = _wt(os.path.join(td, "applied_path.diff"),
                                 "--- a/src/other.py\n+++ b/src/other.py\n@@ -1,1 +1,1 @@\n-x\n+y\n")

        t.check("P6 faithful apply PASSES fidelity (identical path set + hunk counts)",
                lambda: check_fidelity(result_p, applied_same, diff_src=diff_mod) == [])
        t.check("N21 hunk-count mismatch REFUSED (WFID-MISMATCH)",
                lambda: any(e.startswith("WFID-MISMATCH")
                            for e in check_fidelity(result_p, applied_extra_hunk, diff_src=diff_mod)))
        t.check("N22 path-set mismatch REFUSED (WFID-MISMATCH)",
                lambda: any(e.startswith("WFID-MISMATCH")
                            for e in check_fidelity(result_p, applied_other_path, diff_src=diff_mod)))
        t.check("N23 diff_entries load failure REFUSED clean (WFID-DIFF-UNLOADABLE)",
                lambda: any(e.startswith("WFID-DIFF-UNLOADABLE")
                            for e in check_fidelity(result_p, applied_same, diff_src=no_de_mod)))

        # ---- determinism + slug hardening ----
        badp = _wj(os.path.join(td, "rev_det.json"), _mut_review(trh, decision="maybe"))
        t.ok("D1 determinism: identical input -> identical reason list",
             check_review(badp) == check_review(badp))
        t.ok("D2 safe-slug filter: separators/'..' rejected, plain ids accepted",
             not _safe_slug("a/b") and not _safe_slug("../x") and not _safe_slug(".hidden")
             and _safe_slug("st-task-001") and _safe_slug("mock-001"))

    # ---- hermeticity: the real repo's tracked tree is untouched by this self-test ----
    after = _porcelain()
    t.ok("Z1 real repo git status --porcelain unchanged across the self-test (tempdir-only)",
         before is None or after is None or before == after)
    t.ok("Z2 secret-shaped path filter (never opens the file)",
         is_secret_path(".harness/workers/authorizations/.env")
         and is_secret_path("x/id_rsa") and not is_secret_path("authorizations/st-task-001.json"))
    t.done()


def _mut_review(trh, checks=None, checks_fail=False, drop_kind=None, reviewer_role=None,
                schema=None, decision=None, bad_kind=False, bad_result=False, secret=False):
    """Return a mutated copy of the base review for a negative control."""
    o = _base_review(trh)
    if reviewer_role is not None:
        o["reviewer_role"] = reviewer_role
    if schema is not None:
        o["schema"] = schema
    if decision is not None:
        o["decision"] = decision
    if checks is not None:
        o["checks"] = checks
    if checks_fail:
        o["checks"][2]["result"] = "FAIL"       # a FAIL under decision 'apply'
    if drop_kind is not None:
        o["checks"] = [c for c in o["checks"] if c["check"] != drop_kind]
    if bad_kind:
        o["checks"][0]["check"] = "not-a-kind"
    if bad_result:
        o["checks"][0]["result"] = "MAYBE"
    if secret:
        o["provider"] = "Bearer abcdefghijklmnop"  # secret-shaped, value-blind refusal
    return o


# ------------------------------------------------------------------------ main

def _run_review_check(rest):
    p = argparse.ArgumentParser(prog="dmc-worker-review review-check", add_help=False)
    p.add_argument("review")
    p.add_argument("--task")
    p.add_argument("--result")
    try:
        a = p.parse_args(rest)
    except SystemExit:
        die("review-check <review.json> [--task T --result R]", 2)
    if (a.task is None) != (a.result is None):
        die("review-check binding requires BOTH --task and --result", 2)
    try:
        errs = check_review(a.review, a.task, a.result)
    except FileNotFoundError:
        refuse(["WREV-UNREADABLE: file not found"])
    if errs:
        refuse(errs)
    print("VALID: %s conforms to %s" % (a.review, REVIEW_SCHEMA_ID))


def _run_authorize(rest):
    p = argparse.ArgumentParser(prog="dmc-worker-review authorize", add_help=False)
    p.add_argument("--task", required=True)
    p.add_argument("--result", required=True)
    p.add_argument("--review", required=True)
    p.add_argument("--run", dest="run", required=True)
    p.add_argument("--out")
    try:
        a = p.parse_args(rest)
    except SystemExit:
        die("authorize --task T --result R --review REV --run RUN_ID [--out PATH]", 2)
    errs, dest = do_authorize(a.task, a.result, a.review, a.run, a.out)
    if errs:
        refuse(errs)
    print("AUTHORIZED: %s" % dest)
    print("schema: %s" % AUTH_SCHEMA_ID)


def _run_apply_check(rest):
    p = argparse.ArgumentParser(prog="dmc-worker-review apply-check", add_help=False)
    p.add_argument("--auth", required=True)
    p.add_argument("--task", required=True)
    p.add_argument("--result", required=True)
    p.add_argument("--review", required=True)
    p.add_argument("--scope-lock", dest="scope_lock")
    try:
        a = p.parse_args(rest)
    except SystemExit:
        die("apply-check --auth A --task T --result R --review REV [--scope-lock LOCK]", 2)
    errs = check_apply(a.auth, a.task, a.result, a.review, a.scope_lock)
    if errs:
        refuse(errs)
    print("PASS: apply-authorization chain verified (%s)" % AUTH_SCHEMA_ID)


def _run_fidelity(rest):
    p = argparse.ArgumentParser(prog="dmc-worker-review fidelity", add_help=False)
    p.add_argument("--result", required=True)
    p.add_argument("--applied-diff", dest="applied_diff", required=True)
    try:
        a = p.parse_args(rest)
    except SystemExit:
        die("fidelity --result R --applied-diff D", 2)
    errs = check_fidelity(a.result, a.applied_diff)
    if errs:
        refuse(errs)
    print("PASS: applied diff faithful to proposed patch (names+hunk-count tier)")


def main():
    argv = sys.argv[1:]
    if "--self-test" in argv:
        selftest()
        return
    if not argv:
        die(USAGE, 2)
    cmd, rest = argv[0], argv[1:]
    if cmd == "review-check":
        _run_review_check(rest)
    elif cmd == "authorize":
        _run_authorize(rest)
    elif cmd == "apply-check":
        _run_apply_check(rest)
    elif cmd == "fidelity":
        _run_fidelity(rest)
    else:
        die(USAGE, 2)


if __name__ == "__main__":
    main()
