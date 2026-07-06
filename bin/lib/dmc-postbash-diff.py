#!/usr/bin/env python3
"""dmc-postbash-diff.py — DMC v1.0 M6 post-Bash out-of-scope change detector (§M6 (ii)).

Runs AFTER a `Bash` tool call (wired to PostToolUse Bash in evidence-log.sh). It compares the
worktree's CURRENT changed-file set against a baseline SNAPSHOT taken at run arming and reports a
BLOCKED verdict for any NEW change that falls outside the compiled scope lock — the enforcement
that catches a Bash-mediated write the pre-tool classifier could not decide statically.

Two layers run every call:

(A) PATH DIFF — each NEW-changed path (current worktree change-set minus the arming snapshot) is
    adjudicated: `.harness/evidence/`|`.harness/verification/` ⇒ EXEMPT (the run's own evidence);
    `.harness/runs/` append-only logs ⇒ EXEMPT; `blocked.json` ⇒ BLOCKED (deny-on-change, run-state
    mutates only via the dmc CLI); inside the scope lock (dmc-scope-lock, reuse-by-subprocess) ⇒
    EXEMPT; otherwise ⇒ BLOCKED (out-of-scope change).

(B) RUN-STATE INTEGRITY — CONTENT/validator checks that run ALWAYS, keyed off the run dir (`dirname`
    of the scope lock), because in the real repo `.harness/runs/` is gitignored so a path diff alone
    cannot see an in-place tamper (M6 Rev 3, human-gated 2026-07-06; pins P1–P3). run.json is the
    dmc-CLI-only, hash-sealed ROOT OF TRUST, so it is checked FIRST and its pins gate everything else:
      - run.json        ⇒ dmc-run-lifecycle's sealed-state validator. A non-CLI content change breaks
        the seal ⇒ BLOCKED; a legitimate CLI transition re-seals and passes. Only after it validates
        is its operative-snapshot record {scope_lock_sha256, snapshot_sha256} trusted.
      - snapshot.txt    ⇒ re-hash and compare to run.json's snapshot_sha256. A mismatch (an appended
        baseline path line to launder an out-of-scope write, or any edit) — or the pin present but the
        file missing — ⇒ BLOCKED, and the forged baseline is NEVER diffed. This closes the
        unprotected-baseline laundering vector; the human-readable hash comment in snapshot.txt is not
        load-bearing.
      - scope.lock.json ⇒ re-hash and compare to run.json's scope_lock_sha256. Mismatch/missing — or,
        when no record exists, an unsanctioned appearance since arming — ⇒ BLOCKED.
      - approvals.jsonl ⇒ dmc-approvals' append-only hash-chain validator (the "prior snapshot is a
        byte-PREFIX of current" property the chain guarantees). A rewrite of an earlier record breaks
        the chain ⇒ BLOCKED; a legitimate append validates. No refresh at the append site.
    Layer B siblings are reused read-only (no edit to dmc-approvals.py / dmc-run-lifecycle.py); an
    absent sibling degrades to skip (best-effort, like git-absent), never a false BLOCKED.

Pre-existing untracked noise present in the snapshot never trips (only changes introduced AFTER
arming are considered), but only once the baseline's integrity is proven. git-absent ⇒ an empty path
diff (layer B still runs).

Inputs:  --scope-lock FILE  --snapshot FILE  [--root DIR]
Output:  one line of JSON — {"decision","reason","blocked_paths":[...],"new_changes":[...]}
Exit:    0 clean · 4 blocked  (usage error ⇒ 2)

House rules (v0.6.x / M2-M6 lineage): stdlib-only, deterministic, env-independent (no env reads),
offline (git is a best-effort read-only ground-truth query), fail-closed, value-blind (paths only,
never file contents), secret paths refused by path. Reuse-by-invocation: dmc-scope-lock adjudication
is a read-only subprocess so the modules stay independently deletable.
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

EXIT_CLEAN = 0
EXIT_BLOCKED = 4

# blocked.json is the only run-state basename still adjudicated by the path-diff layer; the other
# four (scope.lock.json / run.json / approvals.jsonl / snapshot.txt) are intercepted by the always-on
# integrity layer, so they are excluded from the path-diff deny.
RUN_STATE_BASENAMES = {"blocked.json"}
SNAPSHOT_NAME = "snapshot.txt"
INTEGRITY_BASENAMES = {"scope.lock.json", "run.json", "approvals.jsonl", SNAPSHOT_NAME}
SCOPE_LOCK_NAME = "dmc-scope-lock.py"
RUN_LIFECYCLE_NAME = "dmc-run-lifecycle.py"
APPROVALS_NAME = "dmc-approvals.py"
EXEMPT_PREFIXES = (".harness/evidence/", ".harness/verification/")
RUNS_PREFIX = ".harness/runs/"
# The write-once operative-snapshot record lives INSIDE run.json (dmc-scope-lock.py cmd_compile writes
# it; no standalone refresh verb exists — laundering-hole prohibition) and pins content hashes of BOTH
# scope.lock.json and the arming snapshot.txt. Because run.json is the dmc-CLI-only, hash-sealed root
# of trust (validated first here), those pins let this detector prove neither the lock NOR the baseline
# snapshot was tampered before it trusts snapshot.txt's path-set — closing both the in-place lock
# tamper and the "append a path line to launder an out-of-scope write" baseline attack.
OPERATIVE_KEY = "operative_snapshot"


# ------------------------------------------------------------------- helpers

def die(msg, code=2):
    sys.stderr.write("dmc-postbash-diff: %s\n" % msg)
    sys.exit(code)


def sibling(name):
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), name)


def emit(decision, reason, blocked_paths, new_changes):
    out = {"decision": decision, "reason": reason,
           "blocked_paths": sorted(set(blocked_paths)), "new_changes": sorted(set(new_changes))}
    print(json.dumps(out, sort_keys=True, separators=(",", ":"), ensure_ascii=False))
    sys.exit(EXIT_CLEAN if decision == "clean" else EXIT_BLOCKED)


def _norm(path):
    return path.replace("\\", "/").strip()


def _unquote(path):
    """git may C-quote a path containing special chars (surrounding double quotes)."""
    p = path.strip()
    if len(p) >= 2 and p[0] == '"' and p[-1] == '"':
        try:
            return p[1:-1].encode("utf-8").decode("unicode_escape")
        except Exception:
            return p[1:-1]
    return p


def _porcelain_paths(line):
    """Extract path(s) from one `git status --porcelain` line (handles rename `old -> new`)."""
    # Format: 'XY <path>' (2 status chars, a space, then the path). Untracked: '?? <path>'.
    if len(line) < 4:
        return []
    body = line[3:]
    if " -> " in body:
        return [_unquote(body.split(" -> ", 1)[1])]     # the rename destination is the change
    return [_unquote(body)]


def worktree_paths(root):
    """Sorted union of changed paths from `git status --porcelain` + `git diff --name-only`.

    The canonical changed-file set both this detector and the arming snapshot derive from — so the
    two agree exactly. git-absent / non-repo ⇒ empty set (clean).
    """
    git = shutil.which("git")
    if not git:
        return []
    paths = set()
    try:
        r = subprocess.run([git, "-C", root, "status", "--porcelain", "--untracked-files=all"],
                           capture_output=True, text=True, timeout=15)
        if r.returncode == 0:
            for line in r.stdout.splitlines():
                if line.strip():
                    paths.update(_norm(p) for p in _porcelain_paths(line))
    except Exception:
        pass
    try:
        r2 = subprocess.run([git, "-C", root, "diff", "--name-only"],
                            capture_output=True, text=True, timeout=15)
        if r2.returncode == 0:
            for line in r2.stdout.splitlines():
                if line.strip():
                    paths.update([_norm(_unquote(line))])
    except Exception:
        pass
    return sorted(p for p in paths if p)


def parse_snapshot(text):
    """Return the baseline path set from the paths-only arming snapshot.txt. Tolerates plain path
    lines AND raw porcelain lines; `#` metadata lines are ignored (the operative snapshot now lives
    in run.json, not on a snapshot metadata line)."""
    out = set()
    for line in text.splitlines():
        s = line.rstrip("\n")
        if not s.strip() or s.startswith("#"):
            continue
        # A raw porcelain line begins with two status chars + a space; strip that prefix.
        if re.match(r"^[ MADRCU?!]{2} ", s):
            out.update(_norm(p) for p in _porcelain_paths(s))
        else:
            out.add(_norm(_unquote(s)))
    return out


def _sha256_file(path):
    import hashlib
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


def _read_operative_snapshot(run_json_path):
    """The write-once operative-snapshot record {scope_lock_sha256, snapshot_sha256} from run.json, or
    None if absent / unreadable. The caller trusts this ONLY after run.json's own seal validates
    (_run_state_invalid), so a laundering attempt that rewrites the entry is caught there first."""
    if not os.path.isfile(run_json_path):
        return None
    try:
        with open(run_json_path, "r", encoding="utf-8") as f:
            rec = json.load(f)
    except Exception:
        return None
    if isinstance(rec, dict) and isinstance(rec.get(OPERATIVE_KEY), dict):
        return rec[OPERATIVE_KEY]
    return None


def _run_state_invalid(run_json_path):
    """True iff dmc-run-lifecycle's sealed-state validator REFUSES run.json (a non-CLI content change
    breaks the seal). Sibling absent / OS error ⇒ skip (best-effort, like git-absent) — never a
    false BLOCKED."""
    tool = sibling(RUN_LIFECYCLE_NAME)
    if not os.path.isfile(tool):
        return False
    try:
        r = subprocess.run([sys.executable, "-B", tool, "--validate", run_json_path],
                           capture_output=True, text=True, timeout=15)
    except OSError:
        return False
    return r.returncode != 0


def _approvals_chain_invalid(approvals_path):
    """True iff dmc-approvals' fail-closed ledger validator REFUSES approvals.jsonl (append-only
    hash-chain broken — a rewrite of an earlier record, not a legitimate append). Sibling absent /
    OS error ⇒ skip (allow) — no dmc-approvals.py edit, reuse-by-subprocess only."""
    tool = sibling(APPROVALS_NAME)
    if not os.path.isfile(tool):
        return False
    try:
        r = subprocess.run([sys.executable, "-B", tool, "--validate", approvals_path],
                           capture_output=True, text=True, timeout=15)
    except OSError:
        return False
    return r.returncode != 0


def _adjudicate(scope_lock_path, path):
    """True iff dmc-scope-lock adjudicates `path` ALLOW (op=edit). Reuse-by-subprocess."""
    tool = sibling(SCOPE_LOCK_NAME)
    if not os.path.isfile(tool):
        return False
    try:
        r = subprocess.run([sys.executable, "-B", tool, "--adjudicate", scope_lock_path,
                            path, "edit"], capture_output=True, text=True, timeout=15)
    except OSError:
        return False
    return r.returncode == 0


def classify_change(scope_lock_path, path):
    """Return 'exempt' or 'blocked:<reason-tag>' for one NEW-changed path (ordered rules)."""
    p = _norm(path)
    base = os.path.basename(p)
    if base in RUN_STATE_BASENAMES:
        return "blocked:run-state"
    if p.startswith(EXEMPT_PREFIXES):
        return "exempt"
    if p.startswith(RUNS_PREFIX):
        return "exempt"
    if _adjudicate(scope_lock_path, p):
        return "exempt"
    return "blocked:out-of-scope"


def detect(root, scope_lock_path, snapshot_path):
    run_dir = os.path.dirname(os.path.abspath(scope_lock_path))
    run_json = os.path.join(run_dir, "run.json")
    approvals = os.path.join(run_dir, "approvals.jsonl")
    lock_rel = _norm(os.path.relpath(scope_lock_path, root))
    snap_rel = _norm(os.path.relpath(snapshot_path, root))
    rj_rel = _norm(os.path.relpath(run_json, root))

    # ---- ROOT OF TRUST: validate run.json's seal FIRST; only a valid seal makes its pins trusted ---
    run_tamper = os.path.isfile(run_json) and _run_state_invalid(run_json)
    op = None if run_tamper else _read_operative_snapshot(run_json)
    slh = op.get("scope_lock_sha256") if isinstance(op, dict) else None
    ssh = op.get("snapshot_sha256") if isinstance(op, dict) else None
    has_lock_pin = isinstance(slh, str) and bool(slh)
    has_snap_pin = isinstance(ssh, str) and bool(ssh)

    # Usage error (exit 2) ONLY when there is no pin to enforce (genuinely unarmed / misconfigured).
    # When a pin exists, a missing file is a TAMPER (deletion) — denied below, never a silent exit-2.
    if not os.path.isfile(scope_lock_path) and not has_lock_pin:
        die("scope lock not found: %s" % scope_lock_path, 2)
    if not os.path.isfile(snapshot_path) and not has_snap_pin:
        die("arming snapshot not found: %s (was the run armed?)" % snapshot_path, 2)

    # ---- BASELINE-INTEGRITY GATE (P3): prove snapshot.txt + scope.lock.json against the run.json pins
    lock_tamper = has_lock_pin and (not os.path.isfile(scope_lock_path)
                                    or _sha256_file(scope_lock_path) != slh)
    snap_tamper = has_snap_pin and (not os.path.isfile(snapshot_path)
                                    or _sha256_file(snapshot_path) != ssh)

    # A tampered run.json or a forged/missing arming baseline POISONS the diff — DENY without ever
    # parsing the untrusted baseline (a laundered path line must not be honored as pre-existing noise).
    if run_tamper or snap_tamper:
        hits, parts = [], []
        if run_tamper:
            hits.append(rj_rel)
            parts.append("run.json failed the sealed-state validator (a non-CLI content change)")
        if snap_tamper:
            hits.append(snap_rel)
            parts.append("snapshot.txt content differs from the run.json operative-snapshot pin "
                         "(baseline tampered/missing) — the arming baseline is not trusted")
        if lock_tamper:
            hits.append(lock_rel)
            parts.append("scope.lock.json content differs from the run.json operative-snapshot pin")
        emit("blocked", "POSTBASH-BLOCKED: " + "; ".join(parts), hits, [])

    # ---- baseline integrity proven -> path diff (layer A) + remaining integrity checks -------------
    with open(snapshot_path, "r", encoding="utf-8") as f:
        baseline = parse_snapshot(f.read())
    current = set(worktree_paths(root))
    new_changes = sorted(current - baseline)     # only changes introduced AFTER arming

    state_hits, oos_hits = [], []
    for p in new_changes:
        if os.path.basename(p) in INTEGRITY_BASENAMES:
            continue                                  # decided by the integrity layer (always-on)
        verdict = classify_change(scope_lock_path, p)
        if verdict == "blocked:run-state":
            state_hits.append(p)                      # blocked.json out-of-band
        elif verdict == "blocked:out-of-scope":
            oos_hits.append(p)

    # scope.lock.json: a pinned-and-tampered lock (snapshot intact) is a hit; with NO pin, a lock that
    # appeared since arming is an unsanctioned lock.
    if op is not None:
        if lock_tamper and lock_rel not in state_hits:
            state_hits.append(lock_rel)
    elif lock_rel in new_changes:
        lock_tamper = True
        if lock_rel not in state_hits:
            state_hits.append(lock_rel)

    approvals_tamper = os.path.isfile(approvals) and _approvals_chain_invalid(approvals)
    if approvals_tamper:
        ap_rel = _norm(os.path.relpath(approvals, root))
        if ap_rel not in state_hits:
            state_hits.append(ap_rel)

    if state_hits or oos_hits:
        parts = []
        if lock_tamper:
            parts.append("scope.lock.json content differs from the run.json operative-snapshot pin "
                         "(in-place tamper or unsanctioned lock)")
        if approvals_tamper:
            parts.append("approvals.jsonl failed the append-only hash-chain validator")
        if any(os.path.basename(p) == "blocked.json" for p in state_hits):
            parts.append("run-state file(s) changed by Bash (deny-on-change; mutate only via the "
                         "dmc CLI)")
        if oos_hits:
            parts.append("change(s) outside the locked scope")
        emit("blocked", "POSTBASH-BLOCKED: " + "; ".join(parts),
             state_hits + oos_hits, new_changes)
    emit("clean", "POSTBASH-CLEAN: no new out-of-scope change since arming", [], new_changes)


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
    root = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
    try:
        r = subprocess.run([git, "-C", root, "status", "--porcelain"], capture_output=True, timeout=10)
        return r.stdout if r.returncode == 0 else None
    except Exception:
        return None


# Reuse the sibling's canonical seal so the fixture lock validates under the adjudicator.
def _canon_hash(obj):
    payload = json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    import hashlib
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def _fixture_lock(tmp, run_id="dmc-run-fixture"):
    body = {
        "schema": "dmc.scope-lock.v1", "work_id": "dmc-postbash-selftest",
        "plan_hash": "a" * 40, "repo_hash": "b" * 40, "run_id": run_id,
        "approved_by": "SYNTHETIC-FIXTURE",
        "files": [{"path": "src/app.py", "grant": "edit", "landmark_class": "ordinary"}],
        "bounds": {"max_files": 3, "max_added": 200, "max_deleted": 50,
                   "forbidden_hunk_classes": []},
        "immutable": True, "compiled_at_head": "no-git", "prev_hash": "0" * 64,
    }
    core = {k: v for k, v in body.items() if k != "state_hash"}
    lock = dict(core, state_hash=_canon_hash(core))
    p = os.path.join(tmp, ".harness", "runs", run_id, "scope.lock.json")
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w", encoding="utf-8") as f:
        f.write(json.dumps(lock, sort_keys=True, indent=2) + "\n")
    return p


def _git(root, *args):
    return subprocess.run(["git", "-C", root, *args], capture_output=True, text=True, timeout=30)


def _write(root, rel, text):
    p = os.path.join(root, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w", encoding="utf-8") as f:
        f.write(text)
    return p


def _run_cli(root, lock, snap):
    return subprocess.run([sys.executable, "-B", os.path.abspath(__file__),
                           "--root", root, "--scope-lock", lock, "--snapshot", snap],
                          capture_output=True, text=True)


def selftest():
    t = ST("postbash-diff")
    before = _real_repo_porcelain()
    if not shutil.which("git"):
        t.ok("G0 git present (skipped: git absent — detector degrades to clean)", True)
        t.done()
        return

    tmp = tempfile.mkdtemp(prefix="dmc-postbash-")
    try:
        _git(tmp, "init", "-q")
        _git(tmp, "config", "user.email", "selftest@example.invalid")
        _git(tmp, "config", "user.name", "selftest")
        _write(tmp, "src/app.py", "print('base')\n")
        _write(tmp, ".gitignore", "\n")
        _git(tmp, "add", "-A")
        _git(tmp, "commit", "-qm", "base")
        lock = _fixture_lock(tmp)

        # Pre-existing untracked noise present at arming (must never trip).
        _write(tmp, "local-archive.txt", "noise\n")
        snap_paths = sorted(set(worktree_paths(tmp)))    # baseline includes the scope.lock + noise
        snap = os.path.join(tmp, ".harness", "runs", "dmc-run-fixture", "snapshot.txt")
        with open(snap, "w", encoding="utf-8") as f:
            f.write("\n".join(snap_paths) + "\n")

        # C0 clean baseline: nothing new since arming.
        r = _run_cli(tmp, lock, snap)
        t.ok("C0 clean: no new change since arming", r.returncode == EXIT_CLEAN
             and json.loads(r.stdout)["decision"] == "clean")

        # C1 pre-existing noise stays clean even though it is out-of-scope (it is in the snapshot).
        t.check("C1 pre-existing untracked noise never trips",
                lambda: "local-archive.txt" not in json.loads(_run_cli(tmp, lock, snap).stdout)
                ["blocked_paths"])

        # C2 in-scope modification ⇒ clean.
        _write(tmp, "src/app.py", "print('edited in scope')\n")
        r = _run_cli(tmp, lock, snap)
        t.ok("C2 clean: in-scope file modified", r.returncode == EXIT_CLEAN)
        _write(tmp, "src/app.py", "print('base')\n")   # restore for isolation

        # C3 out-of-scope NEW file ⇒ BLOCKED.
        oos = _write(tmp, "src/other.py", "x\n")
        r = _run_cli(tmp, lock, snap)
        t.ok("C3 blocked: out-of-scope new file",
             r.returncode == EXIT_BLOCKED and "src/other.py" in json.loads(r.stdout)["blocked_paths"])
        os.remove(oos)

        # C4 run.json changed by Bash ⇒ BLOCKED (layer B: fails the sealed-state validator).
        rs = _write(tmp, ".harness/runs/dmc-run-fixture/run.json", "{}\n")
        r = _run_cli(tmp, lock, snap)
        t.ok("C4 blocked: run.json created out-of-band (sealed-state validator refuses)",
             r.returncode == EXIT_BLOCKED
             and any(p.endswith("run.json") for p in json.loads(r.stdout)["blocked_paths"]))
        os.remove(rs)

        # C4b blocked.json out-of-band ⇒ BLOCKED.
        bj = _write(tmp, ".harness/runs/dmc-run-fixture/blocked.json", "{}\n")
        r = _run_cli(tmp, lock, snap)
        t.ok("C4b blocked: blocked.json created out-of-band (deny-on-change)",
             r.returncode == EXIT_BLOCKED)
        os.remove(bj)

        # C5 evidence exemption ⇒ clean.
        ev = _write(tmp, ".harness/evidence/dmc-v1-m6-note.md", "e\n")
        r = _run_cli(tmp, lock, snap)
        t.ok("C5 clean: .harness/evidence/ change exempt", r.returncode == EXIT_CLEAN)
        os.remove(ev)

        # C6 verification exemption ⇒ clean.
        vf = _write(tmp, ".harness/verification/dmc-v1-m6-report.md", "v\n")
        r = _run_cli(tmp, lock, snap)
        t.ok("C6 clean: .harness/verification/ change exempt", r.returncode == EXIT_CLEAN)
        os.remove(vf)

        # C7 append-only run log exemption (a receipt index, NOT a state file) ⇒ clean.
        rl = _write(tmp, ".harness/runs/dmc-run-fixture/receipts/index.jsonl", "{}\n")
        r = _run_cli(tmp, lock, snap)
        t.ok("C7 clean: append-only run log under the run dir exempt", r.returncode == EXIT_CLEAN)
        os.remove(rl)

        # C8 determinism.
        _write(tmp, "src/other.py", "x\n")
        a = _run_cli(tmp, lock, snap)
        b = _run_cli(tmp, lock, snap)
        t.ok("C8 determinism: identical worktree => identical verdict",
             a.stdout == b.stdout and a.returncode == b.returncode)

        # C9 missing snapshot ⇒ usage error (exit 2), never a silent clean.
        r = subprocess.run([sys.executable, "-B", os.path.abspath(__file__), "--root", tmp,
                            "--scope-lock", lock, "--snapshot", os.path.join(tmp, "nope.txt")],
                           capture_output=True, text=True)
        t.ok("C9 missing arming snapshot ⇒ usage error exit 2", r.returncode == 2)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    # ---- R: run.json operative-snapshot end-to-end (M6 Rev 3 P1/P2/P3; real armed flow) ----------
    # A fresh armed repo: `run start` mints run.json + the paths-only arming snapshot; the sanctioned
    # compile records operative_snapshot{scope_lock_sha256, snapshot_sha256} INTO run.json (re-sealing
    # it). Ra passing also proves the scope-lock reseal interoperates with run-lifecycle's sealed-state
    # validator. Covers (v) legit clean, (iii) lock tamper, (ii) snapshot-baseline tamper, (i) forged
    # snapshot line, (iv) suspend/resume preservation, (f) run.json tamper, approvals append/chain, and
    # the compile write-once refusals (c)(d)(e).
    runlc, scloc, appr = sibling(RUN_LIFECYCLE_NAME), sibling(SCOPE_LOCK_NAME), sibling(APPROVALS_NAME)
    if not (shutil.which("git") and os.path.isfile(runlc) and os.path.isfile(scloc)):
        t.ok("R* armed-flow end-to-end skipped (git or run-lifecycle/scope-lock sibling absent)", True)
    else:
        def _tool(tool, *args):
            return subprocess.run([sys.executable, "-B", tool, *args], capture_output=True, text=True)

        tmp2 = tempfile.mkdtemp(prefix="dmc-postbash-armed-")
        try:
            _git(tmp2, "init", "-q")
            _git(tmp2, "config", "user.email", "selftest@example.invalid")
            _git(tmp2, "config", "user.name", "selftest")
            _write(tmp2, "src/app.py", "print('base')\n")
            _git(tmp2, "add", "-A")
            _git(tmp2, "commit", "-qm", "base")
            plan = _write(tmp2, "plan.md",
                          "# Plan: postbash armed fixture\n\n## Relevant Files\n"
                          "| Path | Reason | Allowed to Edit |\n|---|---|---|\n"
                          "| src/app.py | r | yes |\n\n## Approval Status\n"
                          "Status: APPROVED\nApprover: selftest\n")
            lm = _write(tmp2, "landmarks.json", json.dumps(
                {"files": [{"path": "src/app.py", "grant": "edit", "landmark_class": "ordinary"}],
                 "bounds": {"max_files": 3, "max_added": 200, "max_deleted": 50,
                            "forbidden_hunk_classes": []}}))

            rs = _tool(runlc, "start", "--plan", plan, "--work-id", "w", "--root", tmp2)
            rid = open(os.path.join(tmp2, ".harness", "runs", "current-run-id"),
                       encoding="utf-8").read().strip()
            run_dir = os.path.join(tmp2, ".harness", "runs", rid)
            lock = os.path.join(run_dir, "scope.lock.json")
            snap = os.path.join(run_dir, "snapshot.txt")
            rjson = os.path.join(run_dir, "run.json")
            cc = _tool(scloc, "--compile", "--plan", plan, "--landmarks", lm, "--run-id", rid,
                       "--root", tmp2)
            entry = json.load(open(rjson, encoding="utf-8")).get(OPERATIVE_KEY)
            t.ok("R0 armed: start+compile ok, run.json carries operative_snapshot{lock,snapshot}",
                 rs.returncode == 0 and cc.returncode == 0 and isinstance(entry, dict)
                 and isinstance(entry.get("scope_lock_sha256"), str)
                 and isinstance(entry.get("snapshot_sha256"), str))

            # (v) post-compile CLEAN (also proves scope-lock reseal passes run-lifecycle's validator).
            r = _run_cli(tmp2, lock, snap)
            t.ok("Ra (v) legit compile flow ⇒ post-compile postbash-diff CLEAN",
                 r.returncode == EXIT_CLEAN and json.loads(r.stdout)["decision"] == "clean")

            # (iii) in-place scope.lock.json tamper (intact snapshot) ⇒ hash != run.json pin ⇒ BLOCKED.
            lock_bytes = open(lock, "rb").read()
            with open(lock, "a", encoding="utf-8") as f:
                f.write("\n#tamper\n")
            r = _run_cli(tmp2, lock, snap)
            t.ok("Rb (iii) in-place scope.lock.json tamper ⇒ BLOCKED (hash != run.json pin)",
                 r.returncode == EXIT_BLOCKED
                 and any("scope.lock.json" in p for p in json.loads(r.stdout)["blocked_paths"]))
            with open(lock, "wb") as f:
                f.write(lock_bytes)                              # restore
            t.ok("Rb' lock restored ⇒ CLEAN again", _run_cli(tmp2, lock, snap).returncode == EXIT_CLEAN)

            # (ii) append a baseline path line to snapshot.txt (the laundering attack) ⇒ snapshot hash
            # != run.json pin ⇒ BLOCKED, and the forged baseline is never diffed.
            snap_bytes = open(snap, "rb").read()
            with open(snap, "a", encoding="utf-8") as f:
                f.write("attacker/out-of-scope/path.py\n")
            r = _run_cli(tmp2, lock, snap)
            t.ok("Rii (ii) appended baseline path in snapshot.txt ⇒ BLOCKED (baseline not trusted)",
                 r.returncode == EXIT_BLOCKED
                 and any("snapshot.txt" in p for p in json.loads(r.stdout)["blocked_paths"]))
            with open(snap, "wb") as f:
                f.write(snap_bytes)                              # restore

            # (i) forged `# scope-lock-sha256:` line in snapshot.txt + a tampered lock ⇒ BLOCKED: the
            # snapshot pin catches the snapshot edit and the lock pin catches the lock (the comment
            # line is not load-bearing — postbash reads the pins from run.json).
            with open(lock, "a", encoding="utf-8") as f:
                f.write("\n#tamper\n")
            forged = _sha256_file(lock)                          # attacker's forged pin for the lock
            with open(snap, "a", encoding="utf-8") as f:
                f.write("# scope-lock-sha256: %s\n" % forged)
            r = _run_cli(tmp2, lock, snap)
            t.ok("Ri (i) forged snapshot hash line + tampered lock ⇒ BLOCKED (both pins hold)",
                 r.returncode == EXIT_BLOCKED)
            with open(lock, "wb") as f:
                f.write(lock_bytes)                              # restore lock
            with open(snap, "wb") as f:
                f.write(snap_bytes)                              # restore snapshot

            # (iv) CLI state transitions (suspend→resume) PRESERVE operative_snapshot ⇒ still CLEAN.
            sp = _tool(runlc, "suspend", "--root", tmp2)
            rp = _tool(runlc, "resume", "--root", tmp2)
            op_after = json.load(open(rjson, encoding="utf-8")).get(OPERATIVE_KEY)
            r = _run_cli(tmp2, lock, snap)
            t.ok("Riv (iv) suspend→resume preserves operative_snapshot ⇒ run.json valid + CLEAN",
                 sp.returncode == 0 and rp.returncode == 0 and op_after == entry
                 and r.returncode == EXIT_CLEAN)

            # (f) run.json content changed outside the CLI ⇒ sealed-state validator fails ⇒ BLOCKED.
            rec = json.load(open(rjson, encoding="utf-8"))
            rj_bytes = open(rjson, "rb").read()
            rec["updated_at"] = "TAMPERED-OUT-OF-BAND"           # mutate a field, do NOT re-seal
            with open(rjson, "w", encoding="utf-8") as f:
                f.write(json.dumps(rec, sort_keys=True, indent=2) + "\n")
            r = _run_cli(tmp2, lock, snap)
            t.ok("Rf (f) run.json changed outside the CLI ⇒ BLOCKED (sealed-state validator)",
                 r.returncode == EXIT_BLOCKED
                 and any(p.endswith("run.json") for p in json.loads(r.stdout)["blocked_paths"]))
            with open(rjson, "wb") as f:
                f.write(rj_bytes)                                # restore the sealed run.json

            # approvals.jsonl: a legitimate CLI append validates (CLEAN); an out-of-band chain break
            # ⇒ BLOCKED. (byte-prefix is the property the append-only hash-chain enforces.)
            apath = os.path.join(run_dir, "approvals.jsonl")
            if os.path.isfile(appr):
                ap = _tool(appr, "append", "--run-id", rid, "--gate-kind", "plan_approval",
                           "--auth-id", "wjlee", "--root", tmp2)
                r = _run_cli(tmp2, lock, snap)
                t.ok("Rg approvals.jsonl legitimate append ⇒ CLEAN (chain validates)",
                     ap.returncode == 0 and r.returncode == EXIT_CLEAN)
                with open(apath, "a", encoding="utf-8") as f:
                    f.write(json.dumps({"kind": "approval", "id": "BOGUS-UNLINKED"}) + "\n")
                r = _run_cli(tmp2, lock, snap)
                t.ok("Rg' approvals.jsonl out-of-band record ⇒ BLOCKED (append-only chain broken)",
                     r.returncode == EXIT_BLOCKED
                     and any("approvals.jsonl" in p for p in json.loads(r.stdout)["blocked_paths"]))
                os.remove(apath)                                 # isolate the compile-refusal tests
            else:
                t.ok("Rg approvals end-to-end skipped (dmc-approvals sibling absent)", True)

            # (d) a second compile REFUSED while the lock is present (SCOPE-LOCK-EXISTS).
            t.ok("Rd (d) second compile REFUSED (lock present)",
                 _tool(scloc, "--compile", "--plan", plan, "--landmarks", lm, "--run-id", rid,
                       "--root", tmp2).returncode == 3)

            # (c) delete-then-recompile REFUSED via the run.json entry (P1, no laundering).
            os.remove(lock)
            cc3 = _tool(scloc, "--compile", "--plan", plan, "--landmarks", lm, "--run-id", rid,
                        "--root", tmp2)
            t.ok("Rc (c) delete-then-recompile REFUSED (SCOPE-LOCK-RECOMPILE)",
                 cc3.returncode == 3 and "SCOPE-LOCK-RECOMPILE" in cc3.stdout)

            # (e) --out override compile succeeds + leaves the run.json operative entry UNTOUCHED.
            out_lock = os.path.join(tmp2, "custom-lock.json")
            cc4 = _tool(scloc, "--compile", "--plan", plan, "--landmarks", lm, "--run-id", rid,
                        "--root", tmp2, "--out", out_lock)
            entry_after = json.load(open(rjson, encoding="utf-8")).get(OPERATIVE_KEY)
            t.ok("Re (e) --out compile succeeds + run.json operative entry UNTOUCHED (P2)",
                 cc4.returncode == 0 and os.path.isfile(out_lock) and entry_after == entry)
        finally:
            shutil.rmtree(tmp2, ignore_errors=True)

    after = _real_repo_porcelain()
    t.ok("Z1 real repo git status --porcelain byte-identical before/after (or git absent)",
         before == after)
    t.done()


# ------------------------------------------------------------------------ main

def main():
    ap = argparse.ArgumentParser(prog="dmc-postbash-diff")
    ap.add_argument("--root", default=".")
    ap.add_argument("--scope-lock", dest="scope_lock", metavar="FILE")
    ap.add_argument("--snapshot", metavar="FILE")
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args()

    if a.self_test:
        selftest()
        return

    if not a.scope_lock or not a.snapshot:
        die("usage: dmc-postbash-diff --scope-lock FILE --snapshot FILE [--root DIR] | --self-test", 2)
    root = os.path.abspath(a.root)
    if not os.path.isdir(root):
        die("--root is not a directory: %s" % root, 2)
    detect(root, a.scope_lock, a.snapshot)


if __name__ == "__main__":
    main()
