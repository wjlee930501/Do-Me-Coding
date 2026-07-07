#!/usr/bin/env python3
"""dmc-release-gate.py — DMC v1.0 M9 P18 release-verdict composer (`dmc gate release`).

Composes the shipped, mirror-pinned validators into ONE release verdict. It NEVER edits any of
them: every composed tool is invoked read-only as a subprocess, its exit code normalized into a
per-sub-gate verdict, never leaked raw. This module is itself ADVISORY — the composed verdict
informs the human release gate (P17) and the release-auditor agent (M5); it grants nothing.

Subcommands / CLI:
  release --full --run-id RID [--root DIR] [--base SHA] [--out FILE]
      Run the NINE P18 sub-gates over `.harness/runs/<RID>/` and write
      `.harness/runs/<RID>/release-readiness.json` (schema `dmc.release-readiness.v1`; or --out;
      `-` => stdout). Overall verdict: FAIL if any sub-gate FAILs, else PARTIAL if any sub-gate is
      MISSING, else PASS. A landmark FLAG never degrades the verdict. Exit 0 PASS · 1 FAIL/PARTIAL.
  release --quick [--run-id RID | --run DIR | --root DIR] [--report FILE]
      Alias tier: delegates to the SAME logic as `dmc stop-gate quick` by subprocess to
      `bin/lib/dmc-stop-gate.py` (the Ring-1 Stop hook keeps calling `stop-gate quick`; this is the
      architecture-named front door — no logic copy, no drift). EXIT-CODE DIFFERENCE (documented):
      stop-gate emits 0 PASS / 4 HOLD; this alias NORMALIZES that to 0 PASS / 1 HOLD so `--quick`
      and `--full` share one exit convention. (`dmc stop-gate quick` strips the `quick` token in
      bin/dmc; the composed tool itself takes flags only, so this alias passes the flags directly.)
  --self-test
      Hermetic embedded self-test (mktemp roots only; never reads secrets, never writes the live
      repo). Prints "[release-gate] N PASS / M FAIL"; exit 0 all-pass / 1 any-fail.

Exit codes (pinned): 0 overall PASS · 1 overall FAIL or PARTIAL (gate ran; readiness not met) ·
2 usage · 3 REFUSED (structural: unreadable/tampered run state, unknown run, unsafe/existing --out).

The 0/1-vs-3 split maps the two legacy exit conventions the composed tools use (legacy gates 0/1;
M4-M7 modules 0/3): each sub-gate tool's exit is captured and normalized into a per-sub-gate verdict
in the readiness JSON, never surfaced raw.

House rules (v0.6.x / M4-M7 lineage, mirrors bin/lib/dmc-worker-review.py, dmc-delegation.py,
dmc-postbash-diff.py): stdlib-only, env-independent (no env reads), offline (git only best-effort,
read-only, for the worktree ground truth), value-blind reason codes (`RGATE-*` — refusals name the
rule/enum, never document content), duplicate-JSON-key rejecting, secret-shaped paths refused by
path, deterministic per input (no timestamps in the readiness JSON; canonical serialization),
fail-closed with negative controls. `sys.dont_write_bytecode = True` before any subprocess so no
`__pycache__` is written into the composed-tool tree.

Baseline computation (diff-scope) MIRRORS bin/lib/dmc-postbash-diff.py's layer-B sealed-trust
semantics verbatim: run.json's sealed state is validated FIRST (via dmc-run-lifecycle --validate),
and only a valid seal makes its operative_snapshot pins trusted; a run.json seal failure or a
snapshot.txt hash that does not recompute against the run.json `snapshot_sha256` pin POISONS the
baseline and is a structural REFUSE (exit 3) — the untrusted baseline is never diffed.
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

sys.dont_write_bytecode = True  # never write __pycache__ into the composed-tool tree

SCHEMA = "dmc.release-readiness.v1"

# The nine P18 sub-gate names (schema-pinned order for documentation; JSON is canonical/sorted).
SUB_GATES = ("diff-scope", "gate-checks", "receipts", "findings", "goal", "decision",
             "approvals", "chain", "landmark-flag")

# Sub-gate verdict enum + overall verdict enum.
V_PASS, V_FAIL, V_MISSING, V_FLAG = "PASS", "FAIL", "MISSING", "FLAG"
O_PASS, O_FAIL, O_PARTIAL = "PASS", "FAIL", "PARTIAL"

# Composed sibling tools (invoked read-only as subprocesses; never edited/imported).
RUN_LIFECYCLE = "dmc-run-lifecycle.py"
SCOPE_LOCK = "dmc-scope-lock.py"
GATE_CHECK_RUNNER = "dmc-v0.2.6-gate-check-runner.sh"
EVIDENCE_LEDGER = "dmc-evidence-ledger.py"
EVIDENCE_RECEIPT = "dmc-v0.6.2-evidence-receipt.py"
FINDINGS_GATE = "dmc-v0.6.3-findings-gate.py"
GOAL_LEDGER = "dmc-v0.6.4-goal-ledger.py"
DECISION_TRACE = "dmc-v0.6.5-decision-trace.py"
APPROVALS = "dmc-approvals.py"
INSTANCE_VALIDATE = "dmc-instance-validate.py"
DELEGATION = "dmc-delegation.py"
WORKER_REVIEW = "dmc-worker-review.py"
REPO_INTEL = "dmc-repo-intel.py"
STOP_GATE = "dmc-stop-gate.py"

SNAPSHOT_NAME = "snapshot.txt"
SCOPE_LOCK_NAME = "scope.lock.json"
RUN_JSON_NAME = "run.json"
OPERATIVE_KEY = "operative_snapshot"

# Mirror of dmc-postbash-diff.py's exemption prefixes (the run's own evidence + append-only logs).
EXEMPT_PREFIXES = (".harness/evidence/", ".harness/verification/")
RUNS_PREFIX = ".harness/runs/"

# The three post-verification approval kinds whose verification_ref this gate resolves (CF2).
POST_VERIFICATION_KINDS = {"release", "push", "waiver"}


# ------------------------------------------------------------------- structural refusal

class Refuse(Exception):
    """Carries a list of value-blind RGATE-* reason codes for a structural (exit 3) refusal."""

    def __init__(self, reasons):
        super().__init__(reasons[0] if reasons else "REFUSED")
        self.reasons = reasons


def die(msg, code=2):
    sys.stderr.write("dmc-release-gate: %s\n" % msg)
    sys.exit(code)


def refuse(reasons):
    for r in reasons:
        print("REFUSED: %s" % r)
    sys.exit(3)


# ------------------------------------------------------------------- path / secret helpers

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


def safe_repo_rel(path):
    """A safe repo-relative path: non-empty, not absolute, no leading separator, no '..' segment."""
    if not isinstance(path, str) or not path:
        return False
    if os.path.isabs(path):
        return False
    norm = path.replace("\\", "/")
    if norm.startswith("/"):
        return False
    return ".." not in norm.split("/")


def sibling(name):
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), name)


def _no_dup(pairs):
    d = {}
    for k, v in pairs:
        if k in d:
            raise ValueError("duplicate JSON key: %r" % k)
        d[k] = v
    return d


def load_json_strict(path):
    """Duplicate-key-rejecting JSON load. Raises on malformed input."""
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f, object_pairs_hook=_no_dup)


def load_json_safe(path):
    """Best-effort strict load; None on any read/parse failure."""
    try:
        return load_json_strict(path)
    except Exception:  # noqa: BLE001 — a missing/broken input is a soft signal, not a crash
        return None


def sha256_file(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def canon_json(obj):
    """Deterministic, human-readable serialization (sorted keys, 2-space indent, no trailing space)."""
    return json.dumps(obj, sort_keys=True, indent=2, ensure_ascii=False) + "\n"


# ------------------------------------------------------------------- subprocess oracle

def run_tool(args, cwd=None, input_text=None):
    """Invoke a composed tool read-only. Returns (rc, stdout, stderr); rc=None on spawn failure."""
    try:
        proc = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              input=(input_text.encode("utf-8") if input_text is not None else None),
                              cwd=cwd, timeout=120, check=False)
    except (OSError, subprocess.SubprocessError, ValueError):
        return None, "", ""
    return (proc.returncode,
            proc.stdout.decode("utf-8", "replace"),
            proc.stderr.decode("utf-8", "replace"))


def py(tool, *args, input_text=None):
    return run_tool([sys.executable or "python3", "-B", sibling(tool), *args], input_text=input_text)


# ------------------------------------------------------------------- worktree ground truth
# (mirrors dmc-postbash-diff.py verbatim — the two must derive the identical changed-path set)

def _norm(path):
    return path.replace("\\", "/").strip()


def _unquote(path):
    p = path.strip()
    if len(p) >= 2 and p[0] == '"' and p[-1] == '"':
        try:
            return p[1:-1].encode("utf-8").decode("unicode_escape")
        except Exception:
            return p[1:-1]
    return p


def _porcelain_paths(line):
    if len(line) < 4:
        return []
    body = line[3:]
    if " -> " in body:
        return [_unquote(body.split(" -> ", 1)[1])]
    return [_unquote(body)]


def worktree_paths(root):
    """Sorted union of `git status --porcelain -uall` + `git diff --name-only`. git-absent => []."""
    git = shutil.which("git")
    if not git:
        return []
    paths = set()
    r = run_tool([git, "-C", root, "status", "--porcelain", "--untracked-files=all"])
    if r[0] == 0:
        for line in r[1].splitlines():
            if line.strip():
                paths.update(_norm(p) for p in _porcelain_paths(line))
    r2 = run_tool([git, "-C", root, "diff", "--name-only"])
    if r2[0] == 0:
        for line in r2[1].splitlines():
            if line.strip():
                paths.add(_norm(_unquote(line)))
    return sorted(p for p in paths if p)


def base_diff_paths(root, base):
    """`git diff --name-only <base>..HEAD` — the committed-diff union closing worktree blindness."""
    git = shutil.which("git")
    if not git:
        return set()
    r = run_tool([git, "-C", root, "diff", "--name-only", "%s..HEAD" % base])
    if r[0] != 0:
        return set()
    return {_norm(_unquote(x)) for x in r[1].splitlines() if x.strip()}


def parse_snapshot(text):
    """Baseline path set from the paths-only arming snapshot.txt (mirrors dmc-postbash-diff.py)."""
    out = set()
    for line in text.splitlines():
        s = line.rstrip("\n")
        if not s.strip() or s.startswith("#"):
            continue
        if re.match(r"^[ MADRCU?!]{2} ", s):
            out.update(_norm(p) for p in _porcelain_paths(s))
        else:
            out.add(_norm(_unquote(s)))
    return out


# ------------------------------------------------------------------- run-state precondition

def run_state_invalid(run_json_path):
    """True iff dmc-run-lifecycle's sealed-state validator REFUSES run.json (mirror of postbash-diff).
    A sibling-absent / spawn failure degrades to 'not invalid' (best-effort, never a false REFUSE)."""
    tool = sibling(RUN_LIFECYCLE)
    if not os.path.isfile(tool):
        return False
    rc, _o, _e = run_tool([sys.executable or "python3", "-B", tool, "--validate", run_json_path])
    return rc is not None and rc != 0


def read_operative(run_json_path):
    rec = load_json_safe(run_json_path)
    if isinstance(rec, dict) and isinstance(rec.get(OPERATIVE_KEY), dict):
        return rec[OPERATIVE_KEY]
    return None


def compute_new_changes(root, run_dir, base):
    """Return (new_changes, lock_path, lock_tamper) after the sealed-trust integrity gate.

    Raises Refuse (exit 3) on: missing/unreadable run.json, a run.json seal failure, or a
    snapshot.txt that does not recompute against the run.json operative-snapshot pin (a poisoned
    baseline is never diffed). Value-blind. Mirrors dmc-postbash-diff.py layer-B."""
    run_json = os.path.join(run_dir, RUN_JSON_NAME)
    snap = os.path.join(run_dir, SNAPSHOT_NAME)
    lock = os.path.join(run_dir, SCOPE_LOCK_NAME)
    if not os.path.isfile(run_json):
        raise Refuse(["RGATE-RUN-STATE-MISSING: run.json not found for the run"])
    if run_state_invalid(run_json):
        raise Refuse(["RGATE-RUN-STATE-INVALID: run.json failed the sealed-state validator "
                      "(a non-CLI content change / tamper) — baseline not trusted"])
    op = read_operative(run_json)
    ssh = op.get("snapshot_sha256") if isinstance(op, dict) else None
    slh = op.get("scope_lock_sha256") if isinstance(op, dict) else None
    has_snap_pin = isinstance(ssh, str) and bool(ssh)
    has_lock_pin = isinstance(slh, str) and bool(slh)
    if has_snap_pin and (not os.path.isfile(snap) or sha256_file(snap) != ssh):
        raise Refuse(["RGATE-SNAPSHOT-TAMPER: snapshot.txt content differs from the run.json "
                      "operative-snapshot pin (baseline tampered/missing) — never diffed"])
    lock_tamper = has_lock_pin and (not os.path.isfile(lock) or sha256_file(lock) != slh)

    baseline = set()
    if os.path.isfile(snap):
        with open(snap, "r", encoding="utf-8") as f:
            baseline = parse_snapshot(f.read())
    current = set(worktree_paths(root))
    if base:
        current |= base_diff_paths(root, base)
    new_changes = sorted(current - baseline)
    return new_changes, lock, lock_tamper


# ------------------------------------------------------------------- required-check discovery
# (mirrors dmc-stop-gate.py required_checks: verify-plan.json resolved_by, else acceptance.json ids)

def required_checks(run_dir):
    vp = load_json_safe(os.path.join(run_dir, "verify-plan.json"))
    if isinstance(vp, dict) and isinstance(vp.get("coverage"), list):
        ids = set()
        for c in vp["coverage"]:
            if isinstance(c, dict):
                ids.update(i for i in (c.get("resolved_by") or []) if isinstance(i, str) and i)
        if ids:
            return ids, "verify-plan.json"
    acc = load_json_safe(os.path.join(run_dir, "acceptance.json"))
    if isinstance(acc, dict) and isinstance(acc.get("checks"), list):
        ids = {c.get("check_id") for c in acc["checks"]
               if isinstance(c, dict) and isinstance(c.get("check_id"), str) and c.get("check_id")}
        if ids:
            return ids, "acceptance.json"
    return set(), None


# ------------------------------------------------------------------- the nine sub-gates
# each returns {"verdict": ..., "reasons": [...]}.

def _sg(verdict, *reasons):
    return {"verdict": verdict, "reasons": list(reasons)}


def sg_diff_scope(new_changes, lock_path, lock_tamper):
    """diff⊆scope (P7 ground truth, names-only). Each new_change outside evidence/verification/runs
    is adjudicated by dmc-scope-lock --adjudicate; any refusal ⇒ FAIL listing the paths."""
    if lock_tamper:
        return _sg(V_FAIL, "RGATE-SCOPE-LOCK-TAMPER: scope.lock.json content differs from the "
                           "run.json operative-snapshot pin (in-place tamper or missing lock)")
    out_of_scope = []
    for p in new_changes:
        p = _norm(p)
        if p.startswith(EXEMPT_PREFIXES) or p.startswith(RUNS_PREFIX):
            continue                                     # the run's own evidence / append-only logs
        rc, _o, _e = py(SCOPE_LOCK, "--adjudicate", lock_path, p, "edit")
        if rc != 0:                                      # allow=>0, refuse=>3 (normalized here)
            out_of_scope.append(p)
    if out_of_scope:
        return _sg(V_FAIL, "RGATE-DIFF-OUT-OF-SCOPE: change(s) outside the locked scope: %s"
                   % ", ".join(sorted(out_of_scope)))
    return _sg(V_PASS, "RGATE-DIFF-CLEAN: no new out-of-scope change since arming (names-only tier)")


def sg_gate_checks(root, lock_path):
    """gate checks (v0.2.6): materialize a temp allowlist from scope.lock files[].path and run the
    advisory G1-G6 runner (--gate commit). Precondition: the release candidate is STAGED (git add)."""
    lock = load_json_safe(lock_path)
    if not isinstance(lock, dict) or not isinstance(lock.get("files"), list):
        return _sg(V_FAIL, "RGATE-GATE-CHECKS-NO-LOCK: scope.lock.json unreadable / no files[]")
    paths = sorted({e.get("path") for e in lock["files"]
                    if isinstance(e, dict) and isinstance(e.get("path"), str)})
    runner = sibling(GATE_CHECK_RUNNER)
    if not os.path.isfile(runner):
        return _sg(V_FAIL, "RGATE-GATE-CHECKS-UNAVAILABLE: v0.2.6 gate-check runner not found")
    fd, allow = tempfile.mkstemp(prefix="dmc-rgate-allow-", suffix=".txt")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write("\n".join(paths) + ("\n" if paths else ""))
        rc, out, err = run_tool(["bash", runner, "--allowlist", allow, "--repo", root,
                                 "--gate", "commit"])
    finally:
        try:
            os.remove(allow)
        except OSError:
            pass
    if rc == 0:
        return _sg(V_PASS, "RGATE-GATE-CHECKS-PASS: all v0.2.6 gate checks green (advisory)")
    if rc == 1:
        rows = [ln.strip() for ln in out.splitlines() if "FAIL" in ln]
        return _sg(V_FAIL, "RGATE-GATE-CHECKS-FAIL: a v0.2.6 gate check is red (candidate must be "
                           "staged): %s" % ("; ".join(rows) if rows else "see runner output"))
    return _sg(V_FAIL, "RGATE-GATE-CHECKS-ERROR: v0.2.6 runner returned an unexpected exit "
                       "(%s) — normalized to FAIL" % rc)


def sg_receipts(root, run_dir, run_id):
    """receipt coverage (v0.6.2 semantics): required check_ids covered in the evidence ledger,
    ledger chain valid, and every minted receipt file passes the v0.6.2 validator."""
    checks, source = required_checks(run_dir)
    if source is None:
        return _sg(V_MISSING, "RGATE-RECEIPTS-MISSING: no compiled check set (neither "
                              "verify-plan.json nor acceptance.json)")
    rc, _o, _e = py(EVIDENCE_LEDGER, "--validate-ledger", "--root", root, "--run-id", run_id)
    if rc != 0:                                          # 0 VALID, 3 REFUSED (normalized)
        return _sg(V_FAIL, "RGATE-RECEIPTS-LEDGER-INVALID: the evidence ledger failed its "
                           "chain/receipt-hash validation")
    uncovered = []
    for cid in sorted(checks):
        rcc, _o2, _e2 = py(EVIDENCE_LEDGER, "coverage", "--root", root, "--run-id", run_id,
                           "--check-id", cid)
        if rcc != 0:                                     # 0 COVERED, 1 NOT-COVERED, 3 REFUSED
            uncovered.append(cid)
    if uncovered:
        return _sg(V_FAIL, "RGATE-RECEIPTS-UNCOVERED: required check(s) from %s lack a receipt: %s"
                   % (source, ", ".join(uncovered)))
    rdir = os.path.join(run_dir, "receipts")
    bad = []
    if os.path.isdir(rdir):
        for name in sorted(os.listdir(rdir)):
            if not name.endswith(".json") or name == "index.jsonl":
                continue
            rcv, _o3, _e3 = py(EVIDENCE_RECEIPT, "validate", os.path.join(rdir, name))
            if rcv != 0:                                 # 0 valid, 1 invalid (normalized)
                bad.append(name)
    if bad:
        return _sg(V_FAIL, "RGATE-RECEIPTS-BAD: minted receipt(s) fail the v0.6.2 validator: %s"
                   % ", ".join(bad))
    return _sg(V_PASS, "RGATE-RECEIPTS-COVERED: all %d required check(s) from %s are receipt-covered "
                       "and the ledger validates" % (len(checks), source))


def _present_gate(run_dir, filename, tool, verb, code, pass_reason, fail_reason, miss_reason):
    """Generic present⇒gate/trace/answer, absent⇒MISSING helper for the pure-JSON sub-gates."""
    path = os.path.join(run_dir, filename)
    if not os.path.isfile(path):
        return _sg(V_MISSING, miss_reason)
    rc, _o, _e = py(tool, verb, path)
    if rc == code:                                       # 0 ALLOW/ANSWERED
        return _sg(V_PASS, pass_reason)
    return _sg(V_FAIL, fail_reason)


def sg_findings(run_dir):
    return _present_gate(run_dir, "findings.json", FINDINGS_GATE, "gate", 0,
                         "RGATE-FINDINGS-PASS: findings snapshot closure-clean (v0.6.3 gate ALLOW)",
                         "RGATE-FINDINGS-REFUSE: an unresolved/blocked finding crosses release "
                         "(v0.6.3 gate REFUSE)",
                         "RGATE-FINDINGS-MISSING: no findings.json snapshot for this run")


def sg_goal(run_dir):
    return _present_gate(run_dir, "goal-ledger.json", GOAL_LEDGER, "trace", 0,
                         "RGATE-GOAL-PASS: completion traces to an approved goal (v0.6.4 trace ALLOW)",
                         "RGATE-GOAL-REFUSE: a completion does not trace to an approved goal "
                         "(v0.6.4 trace REFUSE)",
                         "RGATE-GOAL-MISSING: no goal-ledger.json for this run")


def sg_decision(run_dir):
    return _present_gate(run_dir, "decision-record.json", DECISION_TRACE, "answer", 0,
                         "RGATE-DECISION-PASS: Q1-Q6 answerable from the record (v0.6.5 ANSWERED)",
                         "RGATE-DECISION-REFUSE: a decision link is unresolved / the record is "
                         "incomplete (v0.6.5 REFUSE)",
                         "RGATE-DECISION-MISSING: no decision-record.json for this run")


def sg_approvals(root, run_dir):
    """typed approvals ledger + CF2 resolution: --validate the ledger, then every release/push/waiver
    record's verification_ref must resolve to a safe, existing, `dmc validate verification`-VALID
    artifact (closes carry-forward #2 — CF2 gets teeth here, presence-only upstream)."""
    ledger = os.path.join(run_dir, "approvals.jsonl")
    if not os.path.isfile(ledger):
        return _sg(V_MISSING, "RGATE-APPROVALS-MISSING: no approvals.jsonl for this run")
    rc, _o, _e = py(APPROVALS, "--validate", ledger)
    if rc != 0:                                          # 0 VALID, 3 REFUSED (normalized)
        return _sg(V_FAIL, "RGATE-APPROVALS-INVALID: approvals.jsonl failed the ledger validator "
                           "(chain / R12 provenance / verification_ref split)")
    unresolved = []
    with open(ledger, "r", encoding="utf-8") as f:
        for raw in f:
            raw = raw.strip()
            if not raw:
                continue
            try:
                rec = json.loads(raw, object_pairs_hook=_no_dup)
            except ValueError:
                return _sg(V_FAIL, "RGATE-APPROVALS-INVALID: a ledger line is not parseable JSON")
            if not isinstance(rec, dict) or rec.get("gate_kind") not in POST_VERIFICATION_KINDS:
                continue
            ref = rec.get("verification_ref")
            if not (safe_repo_rel(ref) and not is_secret_path(ref)):
                unresolved.append(str(ref))
                continue
            target = os.path.join(root, ref)
            if not os.path.isfile(target):
                unresolved.append(ref)
                continue
            rcv, _o2, _e2 = py(INSTANCE_VALIDATE, "verification", "--validate", target)
            if rcv != 0:                                 # 0 VALID, 3 REFUSED (normalized)
                unresolved.append(ref)
    if unresolved:
        return _sg(V_FAIL, "RGATE-VERIFICATION-REF-UNRESOLVED: a release/push/waiver "
                           "verification_ref does not resolve to an existing "
                           "`dmc validate verification`-VALID artifact: %s"
                   % ", ".join(sorted(set(unresolved))))
    return _sg(V_PASS, "RGATE-APPROVALS-PASS: ledger valid + every post-verification "
                       "verification_ref resolves to a VALID artifact (CF2)")


def _run_bound_authorizations(root, run_id):
    """Sorted list of ROOT/.harness/workers/authorizations/*.json whose run_id == run_id."""
    d = os.path.join(root, ".harness", "workers", "authorizations")
    hits = []
    if os.path.isdir(d):
        for name in sorted(os.listdir(d)):
            if not name.endswith(".json"):
                continue
            obj = load_json_safe(os.path.join(d, name))
            if isinstance(obj, dict) and obj.get("run_id") == run_id:
                hits.append(os.path.join(d, name))
    return hits


def sg_chain(root, run_dir, run_id):
    """ACCOUNTABILITY / PROVENANCE tier (M7). Activity-scoped: a run with NO delegated/worker-apply
    activity PASSES with a note (historical runs stay green — the rule refuses runs WHOSE APPLIED
    CHANGES lack a chain, not runs without worker applies). With activity, the delegation chain must
    check and every run-bound authorization must apply-check PASS; any break/missing member ⇒ FAIL."""
    deleg = os.path.join(run_dir, "delegations.jsonl")
    has_deleg = os.path.isfile(deleg)
    auths = _run_bound_authorizations(root, run_id)
    if not has_deleg and not auths:
        return _sg(V_PASS, "RGATE-CHAIN-NO-ACTIVITY: no delegated/worker applies recorded for this "
                           "run (chain-absence blocks only where apply activity exists)")
    reasons = []
    if has_deleg:
        rc, out, _e = py(DELEGATION, "check", "--run", run_id)
        if rc != 0:                                      # 0 PASS, 3 REFUSED (normalized)
            reasons.append("RGATE-CHAIN-DELEG-FAIL: delegations.jsonl failed `dmc delegation "
                           "check` (%s)" % (out.strip().splitlines()[0].strip() if out.strip()
                                            else "chain break / no-chain"))
    workers = os.path.join(root, ".harness", "workers")
    for auth_path in auths:
        auth = load_json_safe(auth_path)
        tid = auth.get("task_id") if isinstance(auth, dict) else None
        if not isinstance(tid, str) or not tid:
            reasons.append("RGATE-CHAIN-MEMBER-MISSING: an authorization carries no task_id")
            continue
        task = os.path.join(workers, "tasks", tid + ".json")
        result = os.path.join(workers, "results", tid + ".json")
        review = os.path.join(workers, "reviews", tid + ".json")
        if not (os.path.isfile(task) and os.path.isfile(result) and os.path.isfile(review)):
            reasons.append("RGATE-CHAIN-MEMBER-MISSING: task/result/review missing for authorized "
                           "task %s (apply without a chain)" % tid)
            continue
        args = ["apply-check", "--auth", auth_path, "--task", task, "--result", result,
                "--review", review]
        lock = os.path.join(run_dir, SCOPE_LOCK_NAME)
        if os.path.isfile(lock):
            args += ["--scope-lock", lock]
        rc, out, _e = py(WORKER_REVIEW, *args)
        if rc != 0:                                      # 0 PASS, 3 REFUSED (normalized)
            reasons.append("RGATE-CHAIN-AUTH-FAIL: `worker apply-check` refused for task %s (%s)"
                           % (tid, out.strip().splitlines()[0].strip() if out.strip() else "refused"))
    if reasons:
        return _sg(V_FAIL, *reasons)
    return _sg(V_PASS, "RGATE-CHAIN-PASS: recorded apply activity has a verified delegation/apply "
                       "chain")


def _run_landmark_paths(root, run_dir):
    """Non-ordinary landmark paths: the run's dmc.landmarks.v1 landmarks.json, else regenerate via
    dmc-repo-intel landmarks --root ROOT. Returns a set of normalized paths."""
    doc = None
    local = os.path.join(run_dir, "landmarks.json")
    cand = load_json_safe(local)
    if isinstance(cand, dict) and isinstance(cand.get("landmarks"), list):
        doc = cand                                       # the repo-intel dmc.landmarks.v1 shape
    if doc is None:
        rc, out, _e = py(REPO_INTEL, "landmarks", "--root", root)
        if rc == 0:
            try:
                doc = json.loads(out)
            except ValueError:
                doc = None
    paths = set()
    if isinstance(doc, dict):
        for m in doc.get("landmarks", []):
            if isinstance(m, dict) and isinstance(m.get("path"), str) and m.get("class") != "ordinary":
                paths.add(_norm(m["path"]))
    return paths


def sg_landmark(root, run_dir, new_changes):
    """landmark diff review flag (P2): new_changes ∩ non-ordinary landmarks ⇒ FLAG (a REVIEW flag
    for the human gate; it NEVER fails the gate — the paths were scope-locked at compile)."""
    marks = _run_landmark_paths(root, run_dir)
    flags = sorted(set(_norm(p) for p in new_changes) & marks)
    if flags:
        return _sg(V_FLAG, "RGATE-LANDMARK-FLAG: new change(s) touch enforcement-class landmark(s) "
                           "(review, not failure): %s" % ", ".join(flags)), flags
    return _sg(V_PASS, "RGATE-LANDMARK-CLEAR: no new change touches a non-ordinary landmark"), []


# ------------------------------------------------------------------- overall verdict + output

def overall_verdict(sub_gates):
    verdicts = [g["verdict"] for g in sub_gates.values()]
    if V_FAIL in verdicts:
        return O_FAIL
    if V_MISSING in verdicts:
        return O_PARTIAL                                 # PARTIAL is NEVER presented as PASS
    return O_PASS                                        # FLAG never degrades the verdict


def out_unsafe(out):
    """House --out path-safety guard (mirrors the v0.6.x tools)."""
    root = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
    if ".." in out.replace("\\", "/").split("/"):
        return True
    if os.path.islink(out):
        return True
    if is_secret_path(out):
        return True
    parent = os.path.dirname(os.path.abspath(out)) or "."
    try:
        cparent = os.path.realpath(parent)
    except Exception:
        return True
    if not os.path.isdir(cparent):
        return True
    low = os.path.join(cparent, os.path.basename(out)).lower()
    return any(p in low for p in (".env", ".pem", ".key", "id_rsa", "id_ed25519", "credentials",
                                  "provider-router"))


def emit_readiness(readiness, dest, run_dir):
    """Write the readiness JSON. dest '-' => stdout (pure JSON). None => default run-dir file.
    Refuses overwrite of an existing file (write-once) and an unsafe --out path."""
    blob = canon_json(readiness)
    if dest == "-":
        sys.stdout.write(blob)
        return
    if dest is None:
        dest = os.path.join(run_dir, "release-readiness.json")
    else:
        if out_unsafe(dest):
            raise Refuse(["RGATE-OUTPUT-UNSAFE: refusing an unsafe --out path"])
    if os.path.exists(dest):
        raise Refuse(["RGATE-OUTPUT-EXISTS: a release-readiness file already exists at %s; the "
                      "readiness artifact is write-once (remove it to re-gate, or use --out -)"
                      % dest])
    with open(dest, "w", encoding="utf-8") as f:
        f.write(blob)
    print("release-readiness: %s" % dest)
    print("verdict: %s" % readiness["verdict"])


# ------------------------------------------------------------------- --full / --quick verbs

def do_full(root, run_id, base, out):
    if not run_id:
        die("release --full requires --run-id RID", 2)
    root = os.path.abspath(root)
    if not os.path.isdir(root):
        die("--root is not a directory: %s" % root, 2)
    run_dir = os.path.join(root, ".harness", "runs", run_id)
    if not os.path.isdir(run_dir):
        raise Refuse(["RGATE-RUN-NOT-FOUND: no run directory for run-id %s" % run_id])

    new_changes, lock_path, lock_tamper = compute_new_changes(root, run_dir, base)

    sub = {}
    sub["diff-scope"] = sg_diff_scope(new_changes, lock_path, lock_tamper)
    sub["gate-checks"] = sg_gate_checks(root, lock_path)
    sub["receipts"] = sg_receipts(root, run_dir, run_id)
    sub["findings"] = sg_findings(run_dir)
    sub["goal"] = sg_goal(run_dir)
    sub["decision"] = sg_decision(run_dir)
    sub["approvals"] = sg_approvals(root, run_dir)
    sub["chain"] = sg_chain(root, run_dir, run_id)
    lm_gate, flags = sg_landmark(root, run_dir, new_changes)
    sub["landmark-flag"] = lm_gate

    verdict = overall_verdict(sub)
    run_rec = load_json_safe(os.path.join(run_dir, RUN_JSON_NAME)) or {}
    plan_hash = run_rec.get("plan_hash") if isinstance(run_rec.get("plan_hash"), str) else ""

    readiness = {
        "schema": SCHEMA,
        "run_id": run_id,
        "plan_hash": plan_hash,
        "sub_gates": sub,
        "flags": flags,
        "verdict": verdict,
    }
    emit_readiness(readiness, out, run_dir)
    sys.exit(0 if verdict == O_PASS else 1)


def do_quick(root, run_id, run_dir_arg, report):
    """Alias to `dmc stop-gate quick` (subprocess). NORMALIZE stop-gate 0 PASS / 4 HOLD => 0 / 1."""
    tool = sibling(STOP_GATE)
    if not os.path.isfile(tool):
        die("composed tool not found: %s" % STOP_GATE, 2)
    args = [sys.executable or "python3", "-B", tool, "--root", os.path.abspath(root)]
    if run_dir_arg:
        args += ["--run", run_dir_arg]
    if run_id:
        args += ["--run-id", run_id]
    if report:
        args += ["--report", report]
    rc, out, err = run_tool(args)
    if out.strip():
        sys.stdout.write(out if out.endswith("\n") else out + "\n")
    if rc == 0:                                          # STOP-PASS
        sys.exit(0)
    if rc == 4:                                          # STOP-HOLD -> normalized FAIL
        sys.exit(1)
    sys.stderr.write(err or "dmc-release-gate: stop-gate returned unexpected exit %s\n" % rc)
    sys.exit(2)


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
        print("[release-gate] %d PASS / %d FAIL" % (self.passed, self.failed))
        sys.exit(0 if self.failed == 0 else 1)


def _repo_root():
    return os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))


def _porcelain():
    git = shutil.which("git")
    if not git:
        return None
    r = run_tool([git, "-C", _repo_root(), "status", "--porcelain"])
    return r[1] if r[0] == 0 else None


ST_H = "a" * 64
ST_BIND = {"work_id": "W1", "plan_hash": ST_H, "repo_hash": ST_H, "verification_ref": "ver/r.md"}

ST_PLAN = """# Plan: synthetic release-gate self-test plan

Plan ID: dmc-selftest-rgate

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
Approved At: 2026-07-08
"""

ST_LANDMARKS = {
    "files": [
        {"path": "src/app.py", "grant": "edit", "landmark_class": "ordinary"},
        {"path": "config.schema.md", "grant": "create", "landmark_class": "contract",
         "landmark_authorized": True},
    ],
    "bounds": {"max_files": 2, "max_added": 200, "max_deleted": 50,
               "forbidden_hunk_classes": []},
}

ST_VERIF = """# Verification Report

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


def _st_approval():
    return {"kind": "approval", "id": "A1", "producer_milestone_id": "human-release-gate",
            "type": "human-release-gate", "source": "human-release-gate:auth1", **ST_BIND}


def _st_findings(blocked=False):
    subj = {"work_id": "W1", "plan_hash": ST_H, "milestone_id": "v0.6.1", "repo_hash": ST_H,
            "verification_ref": "ver/r.md"}
    findings = []
    if blocked:
        findings = [{"kind": "finding", "id": "Fblk", "producer_milestone_id": "v0.6.3",
                     "state": "blocked", "summary_class": "perf-regression", **ST_BIND}]
    return {"subject": subj, "findings": findings}


def _st_goal(broken=False):
    def ent(seq, state, approval=False):
        e = {"entry_kind": "goal_ledger", "producer_milestone_id": "v0.6.4", "goal_id": "g1",
             "seq": seq, "goal_state": state, "scope": "feature-x", "constraints": "no-net",
             "evidence_links": ["evid123456"], "completion_state": "open", **ST_BIND}
        if approval:
            e["approval"] = _st_approval()
        return e
    ledger = [ent(0, "approved", approval=True), ent(1, "in-progress")]
    completion = {"goal_id": ("gX" if broken else "g1"), "completion_state": "done"}
    return {"ledger": ledger, "completion": completion}


def _st_decision(broken=False):
    def e(kind, eid, prod, **x):
        return {"kind": kind, "id": eid, "producer_milestone_id": prod, **ST_BIND, **x}
    dec = {"kind": "decision", "id": "D1", "producer_milestone_id": "v0.6.5",
           "rationale_class": "ship-it",
           "links": {"capability_id": "cheap-fast", "evidence_ids": ["E1"], "finding_ids": ["F1"],
                     "goal_id": "g1", "approval_id": ("A9" if broken else "A1")}, **ST_BIND}
    return {"schema": "dmc.trace-linkage.v1",
            "subject": {"work_id": "W1", "plan_hash": ST_H, "milestone_id": "v0.6.1.0",
                        "repo_hash": ST_H, "verification_ref": "ver/r.md"},
            "registers": {
                "capability": [e("capability_class", "cheap-fast", "v0.6.1")],
                "evidence": [e("evidence_receipt", "E1", "v0.6.2")],
                "finding": [e("finding", "F1", "v0.6.3", state="resolved")],
                "goal": [e("goal", "g1", "v0.4.1")],
                "decision": [dec],
                "approval": [e("approval", "A1", "human-release-gate", type="human-release-gate",
                               source="human-release-gate:auth1")]},
            "edges": [{"from": {"kind": "decision", "id": "D1"},
                       "to": {"kind": "evidence_receipt", "id": "E1"}}]}


def _wt(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    return path


def _wj(path, obj):
    return _wt(path, canon_json(obj))


def _tr(name, *args):
    return run_tool([sys.executable or "python3", "-B", sibling(name), *args])


def _full(root, run_id, *extra):
    r = run_tool([sys.executable or "python3", "-B", os.path.abspath(__file__), "release",
                  "--full", "--run-id", run_id, "--root", root, "--out", "-", *extra])
    rc, out, err = r
    try:
        data = json.loads(out)
    except Exception:  # noqa: BLE001
        data = None
    return rc, data, out, err


def _quick_rc(root, *extra):
    return run_tool([sys.executable or "python3", "-B", os.path.abspath(__file__), "release",
                     "--quick", "--root", root, *extra])[0]


def _sv(data, name):
    return (data or {}).get("sub_gates", {}).get(name, {}).get("verdict")


def selftest():
    t = ST("release-gate")
    before = _porcelain()

    # -- unit: overall-verdict algebra (PARTIAL-never-PASS + FLAG-never-degrades) ------------------
    t.ok("U1 any FAIL dominates -> FAIL",
         overall_verdict({"a": _sg(V_FAIL), "b": _sg(V_MISSING), "c": _sg(V_PASS)}) == O_FAIL)
    t.ok("U2 MISSING (no FAIL) -> PARTIAL (never PASS)",
         overall_verdict({"a": _sg(V_MISSING), "b": _sg(V_PASS)}) == O_PARTIAL)
    t.ok("U3 all PASS -> PASS", overall_verdict({"a": _sg(V_PASS), "b": _sg(V_PASS)}) == O_PASS)
    t.ok("U4 FLAG never degrades a PASS", overall_verdict({"a": _sg(V_FLAG), "b": _sg(V_PASS)}) == O_PASS)
    t.ok("U5 FLAG + MISSING -> PARTIAL", overall_verdict({"a": _sg(V_FLAG), "b": _sg(V_MISSING)}) == O_PARTIAL)

    # -- --quick alias mapping (no git needed): stop-gate 0->0, 4->1 -------------------------------
    q0 = tempfile.mkdtemp(prefix="dmc-rgate-q0-")
    q4 = tempfile.mkdtemp(prefix="dmc-rgate-q4-")
    try:
        os.makedirs(os.path.join(q0, ".harness", "runs"), exist_ok=True)
        t.ok("Q1 --quick over a root with no active run -> stop-gate PASS normalized to exit 0",
             _quick_rc(q0) == 0)
        rd = os.path.join(q4, ".harness", "runs", "dmc-run-q4")
        os.makedirs(rd, exist_ok=True)
        _wj(os.path.join(rd, "run.json"), {"run_id": "dmc-run-q4", "status": "RUNNING"})
        _wt(os.path.join(q4, ".harness", "runs", "current-run-id"), "dmc-run-q4\n")
        _wj(os.path.join(rd, "blocked.json"), {"reason": "out-of-scope write", "paths": ["x"]})
        t.ok("Q2 --quick over a RUNNING+blocked run -> stop-gate HOLD(4) normalized to exit 1",
             _quick_rc(q4) == 1)
    finally:
        shutil.rmtree(q0, ignore_errors=True)
        shutil.rmtree(q4, ignore_errors=True)

    # -- --full end-to-end on a git-armed fixture -------------------------------------------------
    if not shutil.which("git"):
        t.ok("E* --full E2E skipped (git absent — armed-run fixtures unavailable)", True)
    else:
        _selftest_full(t)

    after = _porcelain()
    t.ok("Z1 real repo git status --porcelain byte-identical before/after (or git absent)",
         before == after)
    t.done()


def _selftest_full(t):
    root = tempfile.mkdtemp(prefix="dmc-rgate-full-")
    try:
        run_tool(["git", "-C", root, "init", "-q"])
        run_tool(["git", "-C", root, "config", "user.email", "selftest@example.invalid"])
        run_tool(["git", "-C", root, "config", "user.name", "selftest"])
        _wt(os.path.join(root, "src", "app.py"), "print('base')\n")
        run_tool(["git", "-C", root, "add", "-A"])
        run_tool(["git", "-C", root, "commit", "-qm", "base"])
        plan = _wt(os.path.join(root, "plan.md"), ST_PLAN)
        lm = _wj(os.path.join(root, "landmarks.json"), ST_LANDMARKS)

        rs = _tr(RUN_LIFECYCLE, "start", "--plan", plan, "--root", root)
        pointer = os.path.join(root, ".harness", "runs", "current-run-id")
        if rs[0] != 0 or not os.path.isfile(pointer):
            t.ok("E0 armed fixture: run start (FAILED — cannot build fixture)", False)
            return
        with open(pointer, encoding="utf-8") as f:
            rid = f.read().strip()
        cc = _tr(SCOPE_LOCK, "--compile", "--plan", plan, "--landmarks", lm, "--run-id", rid,
                 "--root", root)
        run_dir = os.path.join(root, ".harness", "runs", rid)
        run_json = os.path.join(run_dir, RUN_JSON_NAME)
        armed_ok = (cc[0] == 0 and OPERATIVE_KEY in (load_json_safe(run_json) or {}))
        t.ok("E0 armed fixture: run start + scope-lock compile records operative_snapshot", armed_ok)
        if not armed_ok:
            return

        # materialize the FULL green path
        _wt(os.path.join(root, "src", "app.py"), "print('edited in scope')\n")   # in-scope change
        _wt(os.path.join(root, "config.schema.md"), "# contract\n")              # in-scope landmark
        _wj(os.path.join(run_dir, "verify-plan.json"),
            {"coverage": [{"path": "src/app.py", "radius_check_ids": ["CHK-A"],
                           "resolved_by": ["CHK-A"]}]})
        _tr(EVIDENCE_LEDGER, "mint", "--root", root, "--run-id", rid, "--check-id", "CHK-A",
            "--evidence-type", "verification-report", "--artifact-ref", "ver/report.md",
            "--work-id", "W", "--plan-hash", "a" * 40, "--repo-hash", "a" * 40,
            "--verification-ref", "ver/report.md")
        _wj(os.path.join(run_dir, "findings.json"), _st_findings())
        _wj(os.path.join(run_dir, "goal-ledger.json"), _st_goal())
        _wj(os.path.join(run_dir, "decision-record.json"), _st_decision())
        _wt(os.path.join(root, ".harness", "verification", "rep.md"), ST_VERIF)
        _tr(APPROVALS, "append", "--root", root, "--run-id", rid, "--gate-kind", "plan_approval",
            "--auth-id", "wjlee")
        _tr(APPROVALS, "append", "--root", root, "--run-id", rid, "--gate-kind", "release",
            "--auth-id", "wjlee", "--verification-ref", ".harness/verification/rep.md")
        run_tool(["git", "-C", root, "add", "config.schema.md", "src/app.py"])   # staged-input precond

        rc, data, out, err = _full(root, rid)
        t.ok("E1 green run -> overall PASS exit 0", rc == 0 and data and data["verdict"] == O_PASS)
        t.ok("E1a readiness conforms (schema/run_id/verdict/9 sub_gates)",
             bool(data) and data.get("schema") == SCHEMA and data.get("run_id") == rid
             and set(data.get("sub_gates", {})) == set(SUB_GATES))
        for name in ("diff-scope", "gate-checks", "receipts", "findings", "goal", "decision",
                     "approvals", "chain"):
            t.ok("E1b sub-gate %s PASS on the green run" % name, _sv(data, name) == V_PASS)
        t.ok("E1c chain PASS-with-note (no worker activity)",
             _sv(data, "chain") == V_PASS
             and any("NO-ACTIVITY" in r for r in data["sub_gates"]["chain"]["reasons"]))
        t.ok("E1d landmark-flag FLAG on the in-scope contract landmark (config.schema.md)",
             _sv(data, "landmark-flag") == V_FLAG and "config.schema.md" in data["flags"])
        t.ok("E1e FLAG does not degrade the overall verdict (still PASS)", data["verdict"] == O_PASS)

        # determinism: two --out - runs byte-identical
        _r1, _d1, out1, _e1 = _full(root, rid)
        _r2, _d2, out2, _e2 = _full(root, rid)
        t.ok("E2 determinism: two --full --out - runs are byte-identical", out1 == out2 and out1)

        # findings MISSING -> PARTIAL (never PASS)
        fpath = os.path.join(run_dir, "findings.json")
        os.rename(fpath, fpath + ".bak")
        rc, data, _o, _e = _full(root, rid)
        t.ok("E3 findings removed -> MISSING sub-gate + overall PARTIAL exit 1",
             rc == 1 and _sv(data, "findings") == V_MISSING and data["verdict"] == O_PARTIAL)
        os.rename(fpath + ".bak", fpath)

        # findings FAIL (blocked finding) -> overall FAIL
        _wj(fpath, _st_findings(blocked=True))
        rc, data, _o, _e = _full(root, rid)
        t.ok("E4 blocked finding -> findings FAIL + overall FAIL exit 1",
             rc == 1 and _sv(data, "findings") == V_FAIL and data["verdict"] == O_FAIL)
        _wj(fpath, _st_findings())

        # goal FAIL (completion not in ledger)  [house 0/3 -> FAIL normalization]
        gpath = os.path.join(run_dir, "goal-ledger.json")
        _wj(gpath, _st_goal(broken=True))
        rc, data, _o, _e = _full(root, rid)
        t.ok("E5 broken goal trace -> goal FAIL (legacy 0/1 REFUSE normalized)",
             _sv(data, "goal") == V_FAIL and rc == 1)
        _wj(gpath, _st_goal())

        # decision FAIL (unresolved approval link)
        dpath = os.path.join(run_dir, "decision-record.json")
        _wj(dpath, _st_decision(broken=True))
        rc, data, _o, _e = _full(root, rid)
        t.ok("E6 unresolved decision link -> decision FAIL", _sv(data, "decision") == V_FAIL)
        _wj(dpath, _st_decision())

        # receipts FAIL (an uncovered required check)
        vpath = os.path.join(run_dir, "verify-plan.json")
        _wj(vpath, {"coverage": [{"path": "src/app.py", "radius_check_ids": ["CHK-A", "CHK-B"],
                                  "resolved_by": ["CHK-A", "CHK-B"]}]})
        rc, data, _o, _e = _full(root, rid)
        t.ok("E7 uncovered required check -> receipts FAIL",
             _sv(data, "receipts") == V_FAIL
             and any("UNCOVERED" in r for r in data["sub_gates"]["receipts"]["reasons"]))
        # receipts MISSING (no compiled check set)
        os.rename(vpath, vpath + ".bak")
        rc, data, _o, _e = _full(root, rid)
        t.ok("E8 no compiled check set -> receipts MISSING + overall PARTIAL",
             _sv(data, "receipts") == V_MISSING and data["verdict"] == O_PARTIAL)
        os.rename(vpath + ".bak", vpath)
        _wj(vpath, {"coverage": [{"path": "src/app.py", "radius_check_ids": ["CHK-A"],
                                  "resolved_by": ["CHK-A"]}]})

        # gate-checks FAIL (release candidate NOT staged) then re-stage
        run_tool(["git", "-C", root, "reset", "-q"])
        rc, data, _o, _e = _full(root, rid)
        t.ok("E9 unstaged candidate -> gate-checks FAIL (v0.2.6 G2 staged-input precondition)",
             _sv(data, "gate-checks") == V_FAIL)
        run_tool(["git", "-C", root, "add", "config.schema.md", "src/app.py"])

        # diff-scope FAIL (an out-of-scope new change)
        evil = os.path.join(root, "src", "evil.py")
        _wt(evil, "x = 1\n")
        rc, data, _o, _e = _full(root, rid)
        t.ok("E10 out-of-scope new change -> diff-scope FAIL naming the path (house 0/3 REFUSE norm)",
             _sv(data, "diff-scope") == V_FAIL
             and any("src/evil.py" in r for r in data["sub_gates"]["diff-scope"]["reasons"]))
        os.remove(evil)

        # approvals CF2: a release verification_ref pointing at a nonexistent file -> approvals FAIL
        _tr(APPROVALS, "append", "--root", root, "--run-id", rid, "--gate-kind", "release",
            "--auth-id", "wjlee", "--verification-ref", ".harness/verification/ghost.md")
        rc, data, _o, _e = _full(root, rid)
        t.ok("E11 CF2: unresolvable verification_ref -> approvals FAIL "
             "(RGATE-VERIFICATION-REF-UNRESOLVED)",
             _sv(data, "approvals") == V_FAIL
             and any("VERIFICATION-REF-UNRESOLVED" in r
                     for r in data["sub_gates"]["approvals"]["reasons"]))

        _selftest_chain(t, root, run_dir, rid)
        _selftest_structural(t, root, run_dir, rid)
    finally:
        shutil.rmtree(root, ignore_errors=True)


def _selftest_chain(t, root, run_dir, rid):
    """Chain sub-gate PASS/FAIL via the run-bound worker-authorization branch (explicit paths)."""
    workers = os.path.join(root, ".harness", "workers")
    tid = "st-task-001"
    task = _wj(os.path.join(workers, "tasks", tid + ".json"),
               {"task_id": tid, "allowed_files": ["src/app.py"]})
    result = _wj(os.path.join(workers, "results", tid + ".json"),
                 {"task_id": tid, "summary": "s"})
    review = _wj(os.path.join(workers, "reviews", tid + ".json"),
                 {"schema": "dmc.worker-review.v1", "task_id": tid, "decision": "apply"})
    with open(task, "rb") as f:
        tb = f.read()
    with open(result, "rb") as f:
        rb = f.read()
    with open(review, "rb") as f:
        vb = f.read()
    trh = hashlib.sha256(tb + b"\n" + rb).hexdigest()
    rvh = hashlib.sha256(vb).hexdigest()
    auth = os.path.join(workers, "authorizations", tid + ".json")
    _wj(auth, {"schema": "dmc.apply-authorization.v1", "task_id": tid, "result_id": tid,
               "review_ref": review, "task_result_hash": trh, "review_hash": rvh, "run_id": rid,
               "authorized_paths": ["src/app.py"], "prev_hash": "genesis"})
    _rc, data, _o, _e = _full(root, rid)
    t.ok("E12 worker-apply activity with a verified authorization -> chain PASS",
         _sv(data, "chain") == V_PASS)
    # tamper the authorization's binding hash -> apply-check REFUSE -> chain FAIL
    _wj(auth, {"schema": "dmc.apply-authorization.v1", "task_id": tid, "result_id": tid,
               "review_ref": review, "task_result_hash": "f" * 64, "review_hash": rvh, "run_id": rid,
               "authorized_paths": ["src/app.py"], "prev_hash": "genesis"})
    _rc, data, _o, _e = _full(root, rid)
    t.ok("E13 tampered authorization (apply without a valid chain) -> chain FAIL",
         _sv(data, "chain") == V_FAIL
         and any("CHAIN-AUTH-FAIL" in r for r in data["sub_gates"]["chain"]["reasons"]))
    # a recorded authorization whose task/result/review members are gone -> chain FAIL
    os.remove(task)
    _rc, data, _o, _e = _full(root, rid)
    t.ok("E14 authorization recorded but chain members missing -> chain FAIL (MEMBER-MISSING)",
         _sv(data, "chain") == V_FAIL
         and any("MEMBER-MISSING" in r for r in data["sub_gates"]["chain"]["reasons"]))
    shutil.rmtree(workers, ignore_errors=True)


def _selftest_structural(t, root, run_dir, rid):
    """Structural REFUSE (exit 3) + overwrite refusal, restoring state between rows."""
    run_json = os.path.join(run_dir, RUN_JSON_NAME)
    snap = os.path.join(run_dir, SNAPSHOT_NAME)

    # run.json tamper -> structural REFUSE exit 3
    with open(run_json, "rb") as f:
        rj = f.read()
    with open(run_json, "a", encoding="utf-8") as f:
        f.write("\n#tamper\n")
    rc, data, out, _e = _full(root, rid)
    t.ok("E15 tampered run.json -> structural REFUSE exit 3 (no readiness emitted)",
         rc == 3 and data is None and "REFUSED" in out and "RUN-STATE-INVALID" in out)
    with open(run_json, "wb") as f:
        f.write(rj)

    # snapshot.txt tamper -> structural REFUSE exit 3 (poisoned baseline never diffed)
    with open(snap, "rb") as f:
        sb = f.read()
    with open(snap, "a", encoding="utf-8") as f:
        f.write("attacker/out-of-scope/path.py\n")
    rc, _d, out, _e = _full(root, rid)
    t.ok("E16 tampered snapshot.txt -> structural REFUSE exit 3 (baseline not trusted)",
         rc == 3 and "SNAPSHOT-TAMPER" in out)
    with open(snap, "wb") as f:
        f.write(sb)

    # unknown run -> structural REFUSE
    rc, _d, out, _e = _full(root, "dmc-run-does-not-exist")
    t.ok("E17 unknown run-id -> structural REFUSE exit 3 (RGATE-RUN-NOT-FOUND)",
         rc == 3 and "RUN-NOT-FOUND" in out)

    # overwrite refusal: write once to an explicit --out, then refuse the second write
    dest = os.path.join(root, "readiness-once.json")
    r1 = run_tool([sys.executable or "python3", "-B", os.path.abspath(__file__), "release",
                   "--full", "--run-id", rid, "--root", root, "--out", dest])
    r2 = run_tool([sys.executable or "python3", "-B", os.path.abspath(__file__), "release",
                   "--full", "--run-id", rid, "--root", root, "--out", dest])
    t.ok("E18 readiness is write-once: first --out writes, second REFUSEs exit 3 (OUTPUT-EXISTS)",
         os.path.isfile(dest) and r2[0] == 3 and "OUTPUT-EXISTS" in (r2[1] + r2[2]))
    os.remove(dest)


# ------------------------------------------------------------------- main

def main():
    argv = sys.argv[1:]
    if "--self-test" in argv:
        selftest()
        return
    ap = argparse.ArgumentParser(prog="dmc-release-gate", add_help=True)
    ap.add_argument("command", nargs="?", choices=["release"])
    ap.add_argument("--full", action="store_true")
    ap.add_argument("--quick", action="store_true")
    ap.add_argument("--run-id", dest="run_id", metavar="RID")
    ap.add_argument("--run", dest="run_dir", metavar="DIR")
    ap.add_argument("--root", default=".")
    ap.add_argument("--base", metavar="SHA")
    ap.add_argument("--out", metavar="FILE")
    ap.add_argument("--report", metavar="FILE")
    a = ap.parse_args(argv)

    if a.command != "release":
        die("usage: release (--full --run-id RID [--root DIR] [--base SHA] [--out FILE] | "
            "--quick [--run-id RID | --run DIR | --root DIR] [--report FILE]) | --self-test", 2)
    if a.full and a.quick:
        die("--full and --quick are mutually exclusive", 2)
    try:
        if a.full:
            do_full(a.root, a.run_id, a.base, a.out)
        elif a.quick:
            do_quick(a.root, a.run_id, a.run_dir, a.report)
        else:
            die("release requires --full or --quick", 2)
    except Refuse as e:
        refuse(e.reasons)


if __name__ == "__main__":
    main()
