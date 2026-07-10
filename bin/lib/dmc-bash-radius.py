#!/usr/bin/env python3
"""dmc-bash-radius.py — DMC v1.0 M6 Bash write-radius classifier (P7 enforcement half; §M6 (i)).

Classifies a candidate Bash command's WRITE radius so the Ring-1 pre-tool guard can allow/ask/deny
a `Bash` tool call the way `dmc-scope-lock adjudicate` already gates `Edit`/`Write`. Two tiers per
the M6 ARMING SEMANTICS:

  L0 static floor (ALWAYS — needs no run, no scope lock, no Ring-0 lookup):
      DENY `git apply` and `patch` application forms — the documented worker-mutation loophole
      (a worker diff is a review artifact, never an executable patch).

  L1 dynamic run-scoped radius (ONLY with --scope-lock present — an active, armed run):
      classify the write TARGETS of redirection (`>`,`>>`,`2>`,`&>`), `sed -i`, `tee`, `mv`/`cp`
      destinations, and `python -c` write idioms. A target is:
        - DENIED if it is a run-state file (scope.lock.json / approvals.jsonl / run.json /
          blocked.json) — those mutate ONLY through the `dmc` CLI, never a Bash redirect;
        - ALLOWED if it adjudicates INSIDE the scope lock (reused by subprocess from
          dmc-scope-lock.py — never re-implemented here);
        - DENIED if it adjudicates OUTSIDE the scope lock (out-of-scope / secret / traversal);
        - a no-write NON-target (ALLOW) when it is a safe sink (`/dev/null`, `/dev/stderr`,
          `/dev/stdout`, `/dev/fd/<n>`) or an fd-duplication idiom (`2>&1`, `>&2`, `2>&-`) — neither
          can touch the working tree, so neither is adjudicated;
        - DENIED (fail-closed) for an ambiguous / unparseable target (a `python -c` idiom, a
          glob/`$(...)` target, a directory destination, a wrapper-exec payload) — the agent
          rewords to a concrete in-scope target rather than stalling on an unattended human ask.
      An unparseable command in this armed context is fail-closed DENY.

Input: JSON on stdin (`{"command": "..."}`, the Claude Code Bash tool_input) or `--cmd STRING`.
Output: one line of JSON — {"tier","decision","reason","targets":[...]} — value-blind (the module
never opens a target file; `targets` are PATHS only, the whole point of a write-radius check).

Exit codes (shared across the M6 verdict CLIs): 0 allow · 3 (ask) · 4 deny. L1 itself emits only
0 allow / 4 deny — safe-sink/fd-dup no-writes allow, every residual target is in-scope allow or
out-of-scope/ambiguous deny; exit 3 remains a defined shared code this classifier no longer reaches.

House rules (v0.6.x / M2-M6 lineage): stdlib-only, deterministic (no wall-clock, no randomness on
the decision path), env-independent (no env reads), offline (no network), fail-closed, value-blind
(reasons name the rule, never the command's content), secret-bearing paths refused by path only.
Reuse-by-invocation: dmc-scope-lock.py adjudication is called as a read-only subprocess so both
modules stay independently deletable.
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

# Exit-code contract, shared across the M6 verdict CLIs.
EXIT_ALLOW = 0
EXIT_ASK = 3
EXIT_DENY = 4

GENESIS = "0" * 64

# Run-state files that mutate ONLY through the `dmc` CLI — a Bash write to any of these is denied
# regardless of scope (canonical bypass fixture (2): an agent editing its own scope/lock file).
# snapshot.txt is included: it is dmc-postbash-diff's arming baseline, so a Bash write to it could
# launder an out-of-scope change as "pre-existing noise" (its integrity is also pinned in run.json).
RUN_STATE_BASENAMES = {"scope.lock.json", "approvals.jsonl", "run.json", "blocked.json",
                       "snapshot.txt"}

# The sibling adjudicator this classifier reuses (never imported — subprocess, so it stays deletable).
SCOPE_LOCK_NAME = "dmc-scope-lock.py"

# Top-level shell control operators we split simple-commands on (quote-aware scan below).
# Leading command-position words we skip to reach the real command word.
SKIP_LEADERS = {"env", "sudo", "command", "nohup", "nice", "time", "builtin", "exec"}

# Wrapper executors whose payload's write radius cannot be adjudicated statically. When ARMED (L1),
# an inner git-apply/patch or write idiom ⇒ DENY; an otherwise-undecidable payload also ⇒ DENY as
# the NET armed verdict (classify_l1 folds the internal ambiguous signal into the terminal
# fail-closed funnel; never a silent allow). L0 and the UNARMED path are untouched — armed-L1-only.
WRAPPER_SHELLS = {"sh", "bash", "zsh", "dash"}
# `xargs` own options that take a SEPARATE value token (so the inner command starts after them);
# bundled forms (-n1, -I{}) and `--flag=value` are single tokens and consume only themselves.
XARGS_VALUE_FLAGS = {"-a", "-d", "-E", "-I", "-L", "-n", "-P", "-s"}

# A redirection operator token: optional fd or `&`, then `>`/`>>`/`>|`.
REDIR_FULL_RE = re.compile(r"^(?:\d+|&)?(?:>>|>\||>)$")
REDIR_PREFIX_RE = re.compile(r"^((?:\d+|&)?(?:>>|>\||>))(.+)$")
# The `>&`/`N>&` fd-dup-or-redirect operator: optional leading fd digits, then `>&`, then a possibly
# glued operand. A bare-fd / `-` operand duplicates or closes a descriptor (no file target); any
# other operand is a real file write target. `&>`/`&>>` (ampersand BEFORE `>`) do NOT match here —
# they keep the plain REDIR_FULL/PREFIX path, which already resolves their file target.
FDDUP_RE = re.compile(r"^(\d*)>&(.*)$")
# A shell-metacharacter that makes a redirection target undecidable by static inspection.
AMBIGUOUS_TARGET_RE = re.compile(r"[\$`*?~{}\[\]]")
# Redirect targets that cannot mutate the working tree — classified as no-write (allow) wherever a
# write target is adjudicated. EXACT-set membership + an ANCHORED fd regex; NEVER a startswith/prefix
# test (which would admit a traversal like `/dev/fd/../../etc/passwd`).
SAFE_SINKS = {"/dev/null", "/dev/stderr", "/dev/stdout"}
FD_SINK_RE = re.compile(r"^/dev/fd/[0-9]+$")


# ------------------------------------------------------------------- helpers

def canon_hash(obj):
    """Shared canonical serialization hash: sorted keys, compact separators, UTF-8, sha256 hex."""
    payload = json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def seal(body):
    """Return a new record with state_hash = canon_hash(body-without-state_hash) (shared seal)."""
    core = {k: v for k, v in body.items() if k != "state_hash"}
    return dict(core, state_hash=canon_hash(core))


def sibling(name):
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), name)


def emit(tier, decision, reason, targets):
    """Print the one-line JSON verdict and exit with the mapped code. targets are paths only."""
    out = {"tier": tier, "decision": decision, "reason": reason, "targets": sorted(set(targets))}
    print(json.dumps(out, sort_keys=True, separators=(",", ":"), ensure_ascii=False))
    sys.exit({"allow": EXIT_ALLOW, "ask": EXIT_ASK, "deny": EXIT_DENY}[decision])


def split_segments(command):
    """Split a command line into top-level simple-command segments, respecting quotes.

    Splits on ; & && || | and newlines (the operators that separate simple commands). Redirections
    and quoted operators are preserved inside a segment. Best-effort — L1 fails closed on anything
    it cannot tokenize.
    """
    segments, buf = [], []
    i, n = 0, len(command)
    quote = None
    while i < n:
        c = command[i]
        if quote:
            buf.append(c)
            if c == quote:
                quote = None
            elif c == "\\" and quote == '"' and i + 1 < n:
                buf.append(command[i + 1])
                i += 2
                continue
            i += 1
            continue
        if c in ("'", '"'):
            quote = c
            buf.append(c)
            i += 1
            continue
        if c == "\\" and i + 1 < n:
            buf.append(c)
            buf.append(command[i + 1])
            i += 2
            continue
        two = command[i:i + 2]
        if two in ("&&", "||"):
            segments.append("".join(buf)); buf = []; i += 2; continue
        # A redirection-dup operator `>&`/`<&` must stay glued to its command: the shell requires the
        # `&` contiguous with `>`/`<`, so a real backgrounding `cmd &` (a space/other char before the
        # `&`) still splits — only skip the split when the preceding buffered char is `>` or `<`.
        if c == "&" and buf and buf[-1] in (">", "<"):
            buf.append(c); i += 1; continue
        if c in (";", "|", "&", "\n"):
            segments.append("".join(buf)); buf = []; i += 1; continue
        buf.append(c)
        i += 1
    segments.append("".join(buf))
    return [s.strip() for s in segments if s.strip()]


def safe_tokens(segment):
    """shlex-tokenize a segment; return None on a parse error (unbalanced quotes etc.)."""
    import shlex
    try:
        return shlex.split(segment, posix=True)
    except ValueError:
        return None


def command_word_index(tokens):
    """Index of the real command word, skipping leading VAR=val assignments and benign leaders."""
    i = 0
    while i < len(tokens):
        tok = tokens[i]
        if re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", tok):   # VAR=val assignment
            i += 1
            continue
        base = os.path.basename(tok)
        if base in SKIP_LEADERS:
            i += 1
            # `env` may carry further VAR=val before the command; the loop's assignment skip handles it.
            continue
        return i
    return None


# ----------------------------------------------------------------- L0 static

def detect_l0(command):
    """Return a (reason, offender) for a `git apply` / `patch` application form, else None.

    Segment- and token-aware primary detection, plus a fail-closed raw-string fallback so a
    command that will not tokenize still cannot smuggle a `git apply` past L0.
    """
    for seg in split_segments(command):
        toks = safe_tokens(seg)
        if not toks:
            continue
        cwi = command_word_index(toks)
        if cwi is None:
            continue
        cw = os.path.basename(toks[cwi])
        rest = toks[cwi + 1:]
        if cw == "patch":
            return "BASH-L0-PATCH: `patch` application form denied (worker diffs are review "
        if cw == "git":
            # first non-option git token, skipping global opts (-C dir, -c k=v, --opt[=val]).
            j = 0
            while j < len(rest):
                tk = rest[j]
                if tk in ("-C", "-c", "--git-dir", "--work-tree", "--namespace"):
                    j += 2
                    continue
                if tk.startswith("-"):
                    j += 1
                    continue
                break
            if j < len(rest) and rest[j] == "apply":
                return "BASH-L0-GIT-APPLY: `git apply` denied (a worker diff is a review artifact, "
    # Fail-closed raw fallback (covers unparseable commands): clear command-position matches only.
    if re.search(r"(?:^|[;&|]\s*|\bsudo\s+|\benv\s+(?:[A-Za-z_]\w*=\S+\s+)*)"
                 r"git\s+(?:-C\s+\S+\s+|-c\s+\S+\s+|--[\w-]+(?:=\S+)?\s+)*apply\b", command):
        return "BASH-L0-GIT-APPLY: `git apply` denied (a worker diff is a review artifact, "
    if re.search(r"(?:^|[;&|]\s*|\bsudo\s+)patch\b(?![\w-])", command):
        return "BASH-L0-PATCH: `patch` application form denied (worker diffs are review "
    return None


# ----------------------------------------------------------------- L1 targets

def _norm_target(path):
    """Strip a leading `./`; return the value-blind path for adjudication (never opened)."""
    p = path.strip()
    while p.startswith("./"):
        p = p[2:]
    return p


def _is_ambiguous(path):
    return path == "" or bool(AMBIGUOUS_TARGET_RE.search(path)) or path.endswith("/") \
        or path in (".", "..") or path.startswith("&")


def _is_safe_sink(path):
    """True iff `path` is a working-tree-inert redirect sink (exact-set + anchored fd regex only)."""
    return path in SAFE_SINKS or bool(FD_SINK_RE.match(path))


def _redirect_targets(tokens):
    """Yield file targets of output redirections in a token list.

    `>&`/`N>&` (fd-dup-or-redirect) is parsed BEFORE the plain `>` regexes: a bare-fd or `-` operand
    is a descriptor duplication/close (no file target, dropped); ANY other operand is a real file
    write target, surfaced and adjudicated like any redirect. `&>`/`&>>` keep the plain redirect path
    (their file target is already resolved there). Operand is the glued suffix (consume 1 token) if
    non-empty, else the NEXT token (consume 2).
    """
    out = []
    i = 0
    n = len(tokens)
    while i < n:
        tok = tokens[i]
        m = FDDUP_RE.match(tok)
        if m:
            glued = m.group(2)
            if glued:
                operand = glued
                i += 1
            else:
                operand = tokens[i + 1] if i + 1 < n else ""
                i += 2
            if operand == "" or operand == "-" or re.match(r"^\d+$", operand):
                continue                # fd duplication/close — no file write target
            out.append(operand)         # a real file write target — adjudicate like any redirect
            continue
        if REDIR_FULL_RE.match(tok):
            tgt = tokens[i + 1] if i + 1 < n else ""
            out.append(tgt)
            i += 2
            continue
        m2 = REDIR_PREFIX_RE.match(tok)
        if m2:
            out.append(m2.group(2))
            i += 1
            continue
        i += 1
    return [t for t in out if not re.match(r"^&\d*[-]?$", t)]   # belt: drop residual bare fd dups


def _operands(args):
    """Non-option operands (a crude but conservative split: a token starting with '-' is an option)."""
    return [a for a in args if not a.startswith("-")]


def _sed_targets(args):
    """File operands of a `sed -i ...` invocation. Returns (targets, in_place, ambiguous)."""
    in_place = any(a == "-i" or a.startswith("-i") or a == "--in-place"
                   or a.startswith("--in-place") for a in args if a.startswith("-"))
    if not in_place:
        return [], False, False
    # If an explicit script flag is present, every non-option arg is a file; otherwise the first
    # non-option arg is the inline script and the rest are files.
    has_script_flag = any(a in ("-e", "-f", "--expression", "--file")
                          or a.startswith(("--expression=", "--file=")) for a in args)
    ops = []
    skip_next = False
    for a in args:
        if skip_next:
            skip_next = False
            continue
        if a in ("-e", "-f", "--expression", "--file"):
            skip_next = True
            continue
        if a.startswith("-"):
            continue
        ops.append(a)
    if not has_script_flag and ops:
        ops = ops[1:]        # drop the inline script operand
    return ops, True, (len(ops) == 0)


def _xargs_inner(args):
    """The inner command argv of an `xargs [flags] cmd...` — xargs' own options stripped so the inner
    command word (e.g. `git`) lands at the front for the payload scan. Conservative: unknown leading
    `-flags` consume only themselves; the known value-taking short flags consume their next token."""
    i = 0
    while i < len(args):
        a = args[i]
        if not a.startswith("-"):
            break
        i += 2 if a in XARGS_VALUE_FLAGS else 1
    return args[i:]


def _payload_has_write(payload_str):
    """Return a short description if a wrapper's inner payload carries a git-apply/patch form OR an L1
    write idiom (redirection, sed -i, tee, mv/cp), else None. Reuses the ANCHORED detect_l0 so a benign
    mention (`sh -c 'echo git apply'`) is NOT a false deny — only a command-position inner form is."""
    if detect_l0(payload_str):
        return "an inner git-apply/patch form"
    for seg in split_segments(payload_str):
        st = safe_tokens(seg)
        if not st:
            continue
        if _redirect_targets(st):
            return "an inner output redirection"
        ci = command_word_index(st)
        if ci is None:
            continue
        icw = os.path.basename(st[ci])
        iargs = st[ci + 1:]
        if icw == "sed" and _sed_targets(iargs)[1]:      # sed -i (in-place)
            return "an inner `sed -i`"
        if icw == "tee":
            return "an inner `tee`"
        if icw in ("mv", "cp"):
            return "an inner `%s`" % icw
    return None


def _wrapper_verdict(cw, args):
    """ARMED-L1 wrapper-exec radius for `sh|bash|zsh|dash -c STR` and `xargs [flags] cmd...`.

    Returns ('deny', reason) when the inner payload carries a git-apply/patch or write idiom, ('ask',
    None) when the payload's radius is otherwise undecidable, or (None, None) when `cw` is not a
    payload-bearing wrapper. Nested wrappers need no recursion — the outer scan either sees the inner
    tokens (deny) or falls through to the internal 'ask' signal (never a silent allow). NOTE: when
    armed, classify_l1 folds that internal 'ask' into the terminal ambiguous funnel, so the NET
    emitted verdict for a benign wrapper payload is DENY (fail-closed, v1.1.7) — the return tuples
    above are the internal signal, not the emitted decision."""
    if cw in WRAPPER_SHELLS:
        payload, i = None, 0
        while i < len(args):
            if args[i] == "-c":
                payload = args[i + 1] if i + 1 < len(args) else ""
                break
            i += 1
        if payload is None:
            return None, None       # `bash script.sh` (no -c): not a payload wrapper
        bad = _payload_has_write(payload)
        if bad:
            return "deny", ("BASH-L1-WRAPPER-EXEC: `%s -c` payload contains %s — a wrapper-exec write "
                            "radius is denied when armed" % (cw, bad))
        return "ask", None
    if cw == "xargs":
        payload = " ".join(_xargs_inner(args))
        bad = _payload_has_write(payload)
        if bad:
            return "deny", ("BASH-L1-WRAPPER-EXEC: `xargs` inner command contains %s — a wrapper-exec "
                            "write radius is denied when armed" % bad)
        return "ask", None
    return None, None


def classify_l1(command, scope_lock_path):
    """Classify the write radius against the scope lock. Returns (decision, reason, targets)."""
    segments = split_segments(command)
    concrete, ambiguous = [], False
    for seg in segments:
        toks = safe_tokens(seg)
        if toks is None:
            # Unparseable segment in an armed context: fail closed.
            return "deny", "BASH-L1-UNPARSEABLE: command segment did not tokenize (armed, " \
                           "fail-closed)", []
        if not toks:
            continue
        concrete.extend(_redirect_targets(toks))
        cwi = command_word_index(toks)
        if cwi is None:
            continue
        cw = os.path.basename(toks[cwi])
        args = toks[cwi + 1:]
        # Wrapper-exec forms (armed L1): the payload's write radius is not statically adjudicable.
        wv, wreason = _wrapper_verdict(cw, args)
        if wv == "deny":
            return "deny", wreason, []
        if wv == "ask":
            ambiguous = True     # outer redirection already captured; ambiguous dominates → terminal DENY (v1.1.7)
            continue
        if cw == "sed":
            tgts, in_place, amb = _sed_targets(args)
            if in_place:
                concrete.extend(tgts)
                ambiguous = ambiguous or amb
        elif cw == "tee":
            ops = _operands(args)
            if ops:
                concrete.extend(ops)
            else:
                ambiguous = True    # `... | tee` with no file operand (writes only to stdout) — none
        elif cw in ("mv", "cp"):
            ops = _operands(args)
            if len(ops) >= 2:
                concrete.append(ops[-1])   # destination is the last operand
            elif ops:
                ambiguous = True
        elif cw in ("python", "python3") and ("-c" in args):
            ambiguous = True            # arbitrary Python write idiom — undecidable target

    # Partition concrete targets: safe sinks are no-write NON-targets (dropped, allow); ambiguous-
    # shaped ones become DENY (fail-closed), not a false ALLOW; the rest are adjudicated.
    resolved = []
    for raw in concrete:
        p = _norm_target(raw)
        if _is_safe_sink(p):
            continue                    # /dev/null etc. cannot touch the working tree — no target
        if _is_ambiguous(p):
            ambiguous = True
            continue
        resolved.append(p)

    # Run-state files are denied outright — those mutate only via the `dmc` CLI.
    state_hits = [p for p in resolved if os.path.basename(p) in RUN_STATE_BASENAMES]
    if state_hits:
        return "deny", ("BASH-L1-RUN-STATE-WRITE: a Bash write targets a run-state file "
                        "(scope.lock.json/approvals.jsonl/run.json/blocked.json) — state mutates "
                        "only via the dmc CLI"), state_hits

    # Adjudicate every remaining concrete target against the scope lock (reuse-by-subprocess).
    out_of_scope = [p for p in resolved if not _adjudicate(scope_lock_path, p)]
    if out_of_scope:
        return "deny", ("BASH-L1-OUT-OF-SCOPE: a Bash write target adjudicates OUTSIDE the locked "
                        "scope (out-of-scope / secret / traversal)"), out_of_scope

    if ambiguous:
        return "deny", ("BASH-L1-AMBIGUOUS: a write idiom has an undecidable target "
                        "(python -c / glob / $(...) / directory / wrapper-exec payload) — "
                        "denied fail-closed; reword to a concrete in-scope redirect target"), resolved

    if resolved:
        return "allow", "BASH-L1-IN-SCOPE: every Bash write target is inside the locked scope", resolved
    return "allow", "BASH-L1-NO-WRITE: no write idiom detected in the command", []


def _adjudicate(scope_lock_path, target):
    """True iff dmc-scope-lock adjudicates `target` ALLOW (op=edit). Reuse-by-subprocess."""
    tool = sibling(SCOPE_LOCK_NAME)
    if not os.path.isfile(tool):
        return False   # fail-closed: no adjudicator => treat as out-of-scope
    try:
        r = subprocess.run([sys.executable, "-B", tool, "--adjudicate", scope_lock_path,
                            target, "edit"], capture_output=True, text=True, timeout=15)
    except OSError:
        return False
    return r.returncode == 0


# --------------------------------------------------------------------- driver

def classify(command, scope_lock_path):
    """Full L0->L1 classification. Emits the verdict + exits (never returns)."""
    l0 = detect_l0(command)
    if l0:
        emit("L0", "deny", l0 + "never an executable patch)", [])
    if not scope_lock_path:
        # No armed run: L1 stands down (repo normal state / the M6 build itself / OMC coexistence).
        emit("L0", "allow", "BASH-L0-UNARMED: no scope lock supplied; L1 write-radius stands down "
                            "(static floor only)", [])
    decision, reason, targets = classify_l1(command, scope_lock_path)
    emit("L1", decision, reason, targets)


def read_command(cmd_arg):
    """Resolve the candidate command from --cmd or the tool_input JSON on stdin."""
    if cmd_arg is not None:
        return cmd_arg
    raw = sys.stdin.read()
    if not raw.strip():
        return ""
    try:
        obj = json.loads(raw)
    except ValueError:
        return raw          # a bare command line on stdin is tolerated
    if isinstance(obj, dict):
        ti = obj.get("tool_input") if isinstance(obj.get("tool_input"), dict) else obj
        val = ti.get("command")
        return val if isinstance(val, str) else ""
    return ""


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


def _fixture_lock(tmp):
    """A minimal, correctly-sealed scope.lock.json the sibling adjudicator will accept."""
    body = {
        "schema": "dmc.scope-lock.v1",
        "work_id": "dmc-bash-radius-selftest",
        "plan_hash": "a" * 40,
        "repo_hash": "b" * 40,
        "run_id": "dmc-run-fixture",
        "approved_by": "SYNTHETIC-FIXTURE",
        "files": [
            {"path": "src/app.py", "grant": "edit", "landmark_class": "ordinary"},
            {"path": "src/new_mod.py", "grant": "create", "landmark_class": "ordinary"},
        ],
        "bounds": {"max_files": 3, "max_added": 200, "max_deleted": 50,
                   "forbidden_hunk_classes": []},
        "immutable": True,
        "compiled_at_head": "no-git",
        "prev_hash": GENESIS,
    }
    lock = seal(body)
    p = os.path.join(tmp, "scope.lock.json")
    with open(p, "w", encoding="utf-8") as f:
        f.write(json.dumps(lock, sort_keys=True, indent=2) + "\n")
    return p


def _run_cli(*args, stdin=None):
    return subprocess.run([sys.executable, "-B", os.path.abspath(__file__), *args],
                          capture_output=True, text=True, input=stdin)


def selftest():
    t = ST("bash-radius")
    before = _real_repo_porcelain()
    tmp = tempfile.mkdtemp(prefix="dmc-bashradius-")
    try:
        lock = _fixture_lock(tmp)

        # -- L0 static floor: ALWAYS denies git apply / patch, armed or not -----------------------
        for cmd in ("git apply patch.diff", "git -C sub apply --3way x.patch",
                    "true && git apply < d.patch", "patch -p1 < fix.diff", "patch <p"):
            r = _run_cli("--cmd", cmd)
            t.ok("L0 deny (unarmed): %r" % cmd,
                 r.returncode == EXIT_DENY and json.loads(r.stdout)["tier"] == "L0")
        for cmd in ("git apply x.patch", "patch -p0 < d"):
            r = _run_cli("--cmd", cmd, "--scope-lock", lock)
            t.ok("L0 deny (armed): %r" % cmd, r.returncode == EXIT_DENY)

        # -- L0 must NOT fire on benign git / non-command 'patch' substrings ----------------------
        for cmd in ("git add --patch", "git format-patch -1", "echo patchwork > src/app.py"):
            r = _run_cli("--cmd", cmd, "--scope-lock", lock)
            t.check("L0 no false-positive: %r" % cmd,
                    lambda rr=r: json.loads(rr.stdout)["decision"] != "deny"
                    or json.loads(rr.stdout)["tier"] != "L0")

        # -- Unarmed L1 stands down: an out-of-scope Bash write PASSES without a lock --------------
        r = _run_cli("--cmd", "echo hi > /etc/nope")
        t.ok("U1 unarmed: out-of-scope write allowed (L1 stands down)",
             r.returncode == EXIT_ALLOW and json.loads(r.stdout)["tier"] == "L0")

        # -- L1 in-scope redirection ALLOWED ------------------------------------------------------
        r = _run_cli("--cmd", "echo x > src/app.py", "--scope-lock", lock)
        t.ok("L1 allow: redirection into an in-scope file",
             r.returncode == EXIT_ALLOW and json.loads(r.stdout)["decision"] == "allow")
        r = _run_cli("--cmd", "printf y >> ./src/app.py", "--scope-lock", lock)
        t.ok("L1 allow: append into an in-scope file (./ + >>)", r.returncode == EXIT_ALLOW)

        # -- L1 out-of-scope redirection DENIED ---------------------------------------------------
        r = _run_cli("--cmd", "echo x > src/other.py", "--scope-lock", lock)
        t.ok("L1 deny: redirection into an out-of-scope file",
             r.returncode == EXIT_DENY and "OUT-OF-SCOPE" in json.loads(r.stdout)["reason"])

        # -- L1 NEG run-state write DENIED (canonical fixture (2)) --------------------------------
        for cmd in ("echo x > .harness/runs/r/scope.lock.json",
                    "echo x >> approvals.jsonl", "sed -i s/a/b/ run.json",
                    "echo x > blocked.json",
                    "echo attacker/path.py >> .harness/runs/r/snapshot.txt"):
            r = _run_cli("--cmd", cmd, "--scope-lock", lock)
            t.ok("L1 deny run-state write: %r" % cmd,
                 r.returncode == EXIT_DENY and "RUN-STATE-WRITE" in json.loads(r.stdout)["reason"])

        # -- L1 sed -i / tee / mv / cp destinations -----------------------------------------------
        r = _run_cli("--cmd", "sed -i 's/a/b/' src/app.py", "--scope-lock", lock)
        t.ok("L1 allow: sed -i on an in-scope file", r.returncode == EXIT_ALLOW)
        r = _run_cli("--cmd", "sed -i 's/a/b/' src/other.py", "--scope-lock", lock)
        t.ok("L1 deny: sed -i on an out-of-scope file", r.returncode == EXIT_DENY)
        r = _run_cli("--cmd", "echo x | tee src/app.py", "--scope-lock", lock)
        t.ok("L1 allow: tee into an in-scope file", r.returncode == EXIT_ALLOW)
        r = _run_cli("--cmd", "cp /src/a src/new_mod.py", "--scope-lock", lock)
        t.ok("L1 allow: cp destination in-scope", r.returncode == EXIT_ALLOW)
        r = _run_cli("--cmd", "mv a.txt src/other.py", "--scope-lock", lock)
        t.ok("L1 deny: mv destination out-of-scope", r.returncode == EXIT_DENY)

        # -- v1.1.7 [ask->deny]: former-ambiguous targets now DENY fail-closed (never ASK) --------
        r = _run_cli("--cmd", "python3 -c 'open(\"src/app.py\",\"w\")'", "--scope-lock", lock)
        t.ok("L1 deny: python -c write idiom (undecidable target, was ask)",
             r.returncode == EXIT_DENY and json.loads(r.stdout)["decision"] == "deny"
             and "AMBIGUOUS" in json.loads(r.stdout)["reason"])
        r = _run_cli("--cmd", "echo x > $OUT", "--scope-lock", lock)
        t.ok("L1 deny: redirection to a variable target (was ask)", r.returncode == EXIT_DENY)
        r = _run_cli("--cmd", "echo x > src/*.py", "--scope-lock", lock)
        t.ok("L1 deny: redirection to a glob target (was ask)", r.returncode == EXIT_DENY)

        # -- v1.1.7 [a2/B1] `>&`/`N>&` file targets surface + adjudicate (no orphaned ALLOW) ------
        # Unit-level parse checks (deterministic, no CLI): the operator surfaces the file, drops fd-dups.
        t.ok("B1 unit: '>&' spaced surfaces the following file token",
             _redirect_targets(["echo", "pwned", ">&", "src/other.py"]) == ["src/other.py"])
        t.ok("B1 unit: '>&FILE' glued surfaces the file token",
             _redirect_targets([">&src/other.py"]) == ["src/other.py"])
        t.ok("B1 unit: 'N>&FILE' glued surfaces the file token",
             _redirect_targets(["2>&/tmp/evil"]) == ["/tmp/evil"])
        t.ok("fd-dup unit: '2>&1' yields no write target", _redirect_targets(["echo", "x", "2>&1"]) == [])
        t.ok("fd-dup unit: '>& 2' spaced-numeric drops", _redirect_targets([">&", "2"]) == [])
        t.ok("fd-dup unit: '2>&-' close drops", _redirect_targets(["2>&-"]) == [])
        t.ok("fd-dup unit: '&>FILE' keeps the plain redirect path (file surfaces)",
             _redirect_targets(["&>/tmp/evil"]) == ["/tmp/evil"])
        # CLI-level B1: out-of-scope `>&` file targets DENY (glued + spaced + N>& + &>); in-scope ALLOW.
        for cmd in ("echo pwned >& src/other.py", "echo pwned >&src/other.py",
                    "echo x 2>& /tmp/evil", "echo x &> /tmp/evil"):
            r = _run_cli("--cmd", cmd, "--scope-lock", lock)
            t.ok("B1 deny: out-of-scope `>&`/`&>` file target ⇒ DENY (no orphaned allow): %r" % cmd,
                 r.returncode == EXIT_DENY and "OUT-OF-SCOPE" in json.loads(r.stdout)["reason"])
        r = _run_cli("--cmd", "echo ok >& src/app.py", "--scope-lock", lock)
        t.ok("B1 allow: in-scope `>&` file target ⇒ ALLOW", r.returncode == EXIT_ALLOW)

        # -- v1.1.7 [fd-dup] descriptor duplications carry no write target ⇒ ALLOW ----------------
        for cmd in ("echo hi 2>&1", "echo hi >&2", "echo hi 1>&2", "echo hi 2>&-", "echo hi >& 2",
                    "echo ok > src/app.py 2>&1"):
            r = _run_cli("--cmd", cmd, "--scope-lock", lock)
            t.ok("fd-dup allow: fd duplication is not a write idiom: %r" % cmd,
                 r.returncode == EXIT_ALLOW and json.loads(r.stdout)["decision"] == "allow")

        # -- v1.1.7 [b/B2] safe-sink allowlist (exact-set + anchored fd) --------------------------
        t.ok("sink unit: /dev/null exact-set sink", _is_safe_sink("/dev/null"))
        t.ok("sink unit: /dev/fd/2 anchored fd sink", _is_safe_sink("/dev/fd/2"))
        t.ok("sink unit: /dev/fd/../../etc/passwd is NOT a sink (no prefix test)",
             not _is_safe_sink("/dev/fd/../../etc/passwd"))
        t.ok("sink unit: /dev/nullx is NOT a sink (exact-set)", not _is_safe_sink("/dev/nullx"))
        t.ok("sink unit: relative dev/null is NOT a sink", not _is_safe_sink("dev/null"))
        for cmd in ("echo x > /dev/null", "echo x 2>/dev/null", "echo x > /dev/stderr",
                    "echo x > /dev/stdout", "echo x > /dev/fd/3", "echo x > /dev/null 2>&1"):
            r = _run_cli("--cmd", cmd, "--scope-lock", lock)
            t.ok("B2 allow: safe sink ⇒ ALLOW (no working-tree write): %r" % cmd,
                 r.returncode == EXIT_ALLOW and json.loads(r.stdout)["decision"] == "allow")
        r = _run_cli("--cmd", "echo x > /dev/fd/../../etc/passwd", "--scope-lock", lock)
        t.ok("B2 deny: /dev/fd traversal is NOT a sink ⇒ adjudicated ⇒ DENY (out-of-scope)",
             r.returncode == EXIT_DENY and "OUT-OF-SCOPE" in json.loads(r.stdout)["reason"])
        r = _run_cli("--cmd", "echo x > /dev/nullx", "--scope-lock", lock)
        t.ok("B2 deny: /dev/nullx is NOT a sink ⇒ DENY (out-of-scope)", r.returncode == EXIT_DENY)

        # -- v1.1.7 [NO-ASK invariant] no L1 input yields verdict `ask` (exit 3) ------------------
        for cmd in ("python3 -c 'open(\"src/app.py\",\"w\")'", "echo x > $OUT", "echo x > src/*.py",
                    "echo x > $(mkfile)", "echo x > somedir/", "mv onlyone", "echo x | tee",
                    'sh -c "echo hi"', "xargs echo", "cp onlyfile"):
            r = _run_cli("--cmd", cmd, "--scope-lock", lock)
            t.ok("NO-ASK: former-ask input never asks (rc!=3, decision!=ask): %r" % cmd,
                 r.returncode != EXIT_ASK and json.loads(r.stdout)["decision"] != "ask")

        # -- v1.1.7 [L0 regression] git-apply combined with a fd-dup still L0 DENY ----------------
        r = _run_cli("--cmd", "git apply x.patch 2>&1", "--scope-lock", lock)
        t.ok("L0 regression: `git apply x.patch 2>&1` (fd-dup not split off) ⇒ L0 DENY",
             r.returncode == EXIT_DENY and json.loads(r.stdout)["tier"] == "L0")

        # -- v1.1.7 [backgrounding] a real `&` still splits (not swallowed as an fd-dup) -----------
        t.ok("bg unit: split_segments does not swallow a real backgrounding '&'",
             split_segments("sleep 1 & echo done") == ["sleep 1", "echo done"])
        t.ok("bg unit: split_segments keeps a contiguous '>&' fd-dup in one segment",
             split_segments("echo x 2>&1") == ["echo x 2>&1"])
        t.ok("bg unit: split_segments keeps a spaced '>&' redirect in one segment",
             split_segments("echo x >& out") == ["echo x >& out"])

        # -- L1 allow: a pure read command (no write idiom) ---------------------------------------
        r = _run_cli("--cmd", "grep -r foo src/ < input.txt", "--scope-lock", lock)
        t.ok("L1 allow: read-only command (input redirection ignored)", r.returncode == EXIT_ALLOW)

        # -- L1 fail-closed: unparseable command in an armed context DENIED -----------------------
        r = _run_cli("--cmd", "echo 'unbalanced > src/app.py", "--scope-lock", lock)
        t.ok("L1 deny: unparseable (unbalanced quote) command fails closed",
             r.returncode == EXIT_DENY and "UNPARSEABLE" in json.loads(r.stdout)["reason"])

        # -- L1 wrapper-exec (ARMED only): payload radius is undecidable ⇒ deny idiom / else deny (fail-closed) --
        # git-apply at the START of the -c payload is preceded by the quote, so L0's anchored scan
        # misses it — the wrapper path is what denies these (reason names the wrapper + inner form).
        for w in ('sh -c "git apply x.patch"', 'bash -c "git apply < d.patch"',
                  'zsh -c "git apply p"', 'dash -c "git apply p"'):
            r = _run_cli("--cmd", w, "--scope-lock", lock)
            t.ok("W1 armed wrapper shell -c git-apply ⇒ DENY (WRAPPER-EXEC): %r" % w,
                 r.returncode == EXIT_DENY and "WRAPPER-EXEC" in json.loads(r.stdout)["reason"])
        # A payload where git-apply follows `&&`/`;`/`|` is ALSO denied — here L0's raw floor already
        # matches (defense in depth); either way exit is DENY.
        r = _run_cli("--cmd", 'zsh -c "cd sub && git apply p"', "--scope-lock", lock)
        t.ok("W1b armed wrapper `&&`-payload git-apply ⇒ DENY (L0 raw floor also covers it)",
             r.returncode == EXIT_DENY)
        for w in ("xargs git apply", "git diff --name-only | xargs -n1 git apply",
                  "find . | xargs -I{} git apply {}"):
            r = _run_cli("--cmd", w, "--scope-lock", lock)
            t.ok("W2 armed xargs feeding git-apply ⇒ DENY: %r" % w,
                 r.returncode == EXIT_DENY and "WRAPPER-EXEC" in json.loads(r.stdout)["reason"])
        for w in ('sh -c "echo x > src/app.py"', 'bash -c "sed -i s/a/b/ src/app.py"'):
            r = _run_cli("--cmd", w, "--scope-lock", lock)
            t.ok("W3 armed wrapper inner write idiom ⇒ DENY: %r" % w,
                 r.returncode == EXIT_DENY and "WRAPPER-EXEC" in json.loads(r.stdout)["reason"])
        for w in ('sh -c "echo hi"', "xargs echo", 'bash -c "ls -la src"'):
            r = _run_cli("--cmd", w, "--scope-lock", lock)
            t.ok("W4 armed wrapper benign payload ⇒ DENY (was ASK; undecidable radius fails closed): %r" % w,
                 r.returncode == EXIT_DENY and json.loads(r.stdout)["decision"] == "deny"
                 and "AMBIGUOUS" in json.loads(r.stdout)["reason"])
        for w in ('sh -c "git apply x.patch"', "xargs git apply", 'sh -c "echo hi"'):
            r = _run_cli("--cmd", w)      # UNARMED: L1 stands down, behavior unchanged
            t.ok("W5 unarmed wrapper unchanged ⇒ allow (L0): %r" % w,
                 r.returncode == EXIT_ALLOW and json.loads(r.stdout)["tier"] == "L0")
        # W6 no L0 regression: `git log --grep="git apply"` armed is NOT a wrapper ⇒ still ALLOW.
        r = _run_cli("--cmd", 'git log --grep="git apply"', "--scope-lock", lock)
        t.ok("W6 armed git log --grep='git apply' ⇒ ALLOW (no wrapper payload, L0 anchor holds)",
             r.returncode == EXIT_ALLOW)
        # W7 L0 still fires FIRST on a bare armed git-apply (the wrapper path never masks L0).
        r = _run_cli("--cmd", "git apply x.patch", "--scope-lock", lock)
        t.ok("W7 bare armed git apply ⇒ L0 DENY (unchanged floor)",
             r.returncode == EXIT_DENY and json.loads(r.stdout)["tier"] == "L0")

        # -- stdin JSON tool_input path -----------------------------------------------------------
        r = _run_cli("--scope-lock", lock,
                     stdin=json.dumps({"tool_input": {"command": "echo x > src/app.py"}}))
        t.ok("I1 stdin tool_input JSON parsed + allowed", r.returncode == EXIT_ALLOW)

        # -- determinism --------------------------------------------------------------------------
        a = _run_cli("--cmd", "echo x > src/other.py", "--scope-lock", lock)
        b = _run_cli("--cmd", "echo x > src/other.py", "--scope-lock", lock)
        t.ok("D1 determinism: identical inputs => identical verdict + exit",
             a.stdout == b.stdout and a.returncode == b.returncode)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    after = _real_repo_porcelain()
    t.ok("Z1 real repo git status --porcelain byte-identical before/after (or git absent)",
         before == after)
    t.done()


# ------------------------------------------------------------------------ main

def main():
    ap = argparse.ArgumentParser(prog="dmc-bash-radius")
    ap.add_argument("--cmd", metavar="STRING", help="candidate Bash command (else read JSON stdin)")
    ap.add_argument("--scope-lock", dest="scope_lock", metavar="FILE",
                    help="compiled scope.lock.json — presence arms L1 write-radius classification")
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args()

    if a.self_test:
        selftest()
        return

    command = read_command(a.cmd)
    classify(command, a.scope_lock)


if __name__ == "__main__":
    main()
