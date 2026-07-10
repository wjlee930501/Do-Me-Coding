#!/usr/bin/env python3
"""dmc_codex_common.py — DMC v1 M6.5 Codex-adapter shared library (Ring-1 translation layer).

ADVISORY STATUS (human gate Option A, recorded 2026-07-07 in
`.harness/evidence/dmc-v1-m6.5-spike-stop.md`) — NON-NEGOTIABLE, stated here so it is impossible to
read this code and infer an enforcement guarantee it does not have:

  At codex-cli 0.132.0 the spike (`.harness/evidence/dmc-v1-m6.5-spike-findings.md`) found that
  (i) whether Codex lifecycle hooks FIRE and (ii) whether the deny/allow/block decision ENVELOPES
  these shims emit are HONORED are BOTH *unprovable turn-free* — a live authenticated model turn is
  the only path to prove either, and no such turn is ever DMC-initiated. Therefore these shims are
  **ADVISORY translators**, not an enforcement boundary. They translate a Codex hook event onto the
  SAME Ring-0 verdict CLIs the Claude shims call and emit the corresponding Codex envelope, but on a
  Codex host the enforcement boundary is the **pre-commit/CI gate** and the M6 **post-Bash diff
  guard is the PRIMARY safety net** (the `unified_exec` streaming-shell path is stable+on, so
  PreToolUse is explicitly non-airtight). NO enforcement-parity claim is made on Codex.

Design contract (`docs/CODEX_ADAPTER.md` §2): the adapter contains NO enforcement logic of its own
except the faithful, byte-consistent reproduction of the Claude shims' *static* mode/floor handling
required for cross-adapter verdict parity — the substantive verdicts (Bash write-radius, edit-scope
adjudication, post-Bash diff, completion gate) all come from Ring-0 (`bin/dmc`, `bin/lib/*.py`). If
the two adapters ever disagree on a decision, that is a Ring-1 bug because the decision was Ring-0's.

House rules (M2-M6 lineage): python3 stdlib-only, deterministic, env-independent beyond documented
inputs, offline (no network / model / API call), fail-closed-in-active on degenerate input, and
secret-bearing paths refused by path only (file contents are NEVER opened here).

tool_input field names are TBD-at-spike (`docs/CODEX_ADAPTER.md` §Open questions; spike §D found no
turn-free tool-schema dump) — so every field read is a *superset* over documented candidate key
names, case-insensitive, across `tool_input` and the event top level. A truly renamed field on a
real operation degrades to fail-closed-in-active (B2 case b), never a silent fail-open.
"""

import json
import os
import re
import subprocess
import sys
import time

# --------------------------------------------------------------------- constants

VALID_MODES = ("active", "passive", "off")

# Superset candidate key names per logical field (case-insensitive lookup). The FIRST documented
# Claude-harness name leads each list; the rest are defensive candidates for Codex's TBD schema.
CMD_KEYS = ("command", "cmd", "script", "shell_command", "commandLine", "command_line")
FILE_PATH_KEYS = ("file_path", "path", "filepath", "filePath", "target_file", "targetFile",
                  "abs_path", "absolute_path", "notebook_path", "notebookPath")
GREP_DIR_KEYS = ("path", "dir", "directory", "search_path", "searchPath")
GLOB_KEYS = ("glob", "pattern", "glob_pattern", "globPattern")
GREP_PATTERN_KEYS = ("pattern", "regex", "query", "search")
PROMPT_KEYS = ("prompt", "user_prompt", "userPrompt", "text", "message")

# Host session permission-mode key (v1.1.5 ask-tier bypass-awareness). The enum matches Claude Code
# (default|acceptEdits|plan|dontAsk|bypassPermissions). snake `permission_mode` is the DOCUMENTED
# parity key — exactly what `pre-tool-guard.sh` reads via `json_get 'permission_mode'`; camelCase
# `permissionMode` is a defensive-only candidate for the TBD Codex schema. Read at the event TOP
# level ONLY (never under tool_input); absent => "" => Block C's ask stays inert-if-absent.
PERMISSION_MODE_KEYS = ("permission_mode", "permissionMode")

# Project-dir resolution order. CLAUDE_PROJECT_DIR is honored FIRST so the cross-adapter parity
# fixtures can pin one synthetic project dir for both adapters (as tests/fixtures/m6/_m6common.sh
# does); DMC_/CODEX_ native vars precede the event `cwd` and finally the process cwd.
PROJECT_DIR_ENV = ("CLAUDE_PROJECT_DIR", "DMC_PROJECT_DIR", "CODEX_PROJECT_DIR")

RUN_STATE_BASENAMES = {"scope.lock.json", "approvals.jsonl", "run.json", "blocked.json",
                       "snapshot.txt"}
SECRET_ALLOW_BASENAMES = {".env.example", ".env.sample", ".env.template", ".env.dist"}


# ----------------------------------------------------------------- event parsing

def read_event():
    """Read stdin and parse the Codex hook event JSON.

    Returns (data, raw) where data is a dict on success, or None when stdin is empty or does not
    parse to a JSON object — the B2 case (a) signal. `raw` is the original text (never logged).
    """
    try:
        raw = sys.stdin.read()
    except Exception:
        return None, ""
    if not raw or not raw.strip():
        return None, raw
    try:
        data = json.loads(raw)
    except Exception:
        return None, raw
    return (data if isinstance(data, dict) else None), raw


def _ci_get(mapping, keys):
    """Case-insensitive first-hit lookup of `keys` in a dict, returning a stringified scalar."""
    if not isinstance(mapping, dict):
        return ""
    lowered = {str(k).lower(): v for k, v in mapping.items()}
    for k in keys:
        if k.lower() in lowered:
            v = lowered[k.lower()]
            if v is None:
                continue
            if isinstance(v, (dict, list)):
                continue
            return str(v)
    return ""


def get_field(data, keys):
    """Superset field read: try `tool_input.<key>` then top-level `<key>`, case-insensitive."""
    if not isinstance(data, dict):
        return ""
    val = _ci_get(data.get("tool_input"), keys)
    if val:
        return val
    return _ci_get(data, keys)


def tool_name(data):
    return _ci_get(data, ("tool_name", "toolName", "tool", "name"))


def event_cwd(data):
    return _ci_get(data, ("cwd", "working_directory", "workingDirectory"))


def stop_hook_active(data):
    """Loop-guard flag (Codex mirrors Claude's `stop_hook_active`)."""
    v = _ci_get(data, ("stop_hook_active", "stopHookActive"))
    return v.strip().lower() == "true"


def permission_mode(data):
    """Top-level `permission_mode` read (mirrors `pre-tool-guard.sh`'s `json_get 'permission_mode'`).

    The host session's blanket-consent record; "" when absent so Block C's ask stays inert-if-absent.
    Read at the event TOP level ONLY (never under tool_input), byte-consistent with the Claude side.
    """
    return _ci_get(data, PERMISSION_MODE_KEYS)


# ---------------------------------------------------------------- project / mode

def resolve_project_dir(data):
    for env in PROJECT_DIR_ENV:
        v = os.environ.get(env)
        if v:
            return v
    cwd = event_cwd(data) if isinstance(data, dict) else ""
    if cwd:
        return cwd
    return os.getcwd()


def read_mode(project_dir):
    """`.harness/mode` parity: absent => active; first non-space token lowercased, validated to the
    enum else active. Byte-consistent with every Claude shim's mode gate."""
    mode_file = os.path.join(project_dir, ".harness", "mode")
    if not os.path.isfile(mode_file):
        return "active"
    try:
        with open(mode_file, "r", encoding="utf-8", errors="replace") as f:
            first = f.readline()
    except Exception:
        return "active"
    tok = re.sub(r"\s", "", first).lower()
    return tok if tok in VALID_MODES else "active"


def arming(project_dir):
    """ARMED := current-run-id present AND that run carries an immutable scope.lock.json.

    Returns (run_id, run_dir, scope_lock) when armed, else (None, None, None) — mirrors the Claude
    shims' arming predicate exactly.
    """
    runs = os.path.join(project_dir, ".harness", "runs")
    rid_file = os.path.join(runs, "current-run-id")
    if not os.path.isfile(rid_file):
        return None, None, None
    try:
        with open(rid_file, "r", encoding="utf-8", errors="replace") as f:
            rid = re.sub(r"[^A-Za-z0-9._-]", "", f.readline().strip())
    except Exception:
        return None, None, None
    if not rid:
        return None, None, None
    run_dir = os.path.join(runs, rid)
    lock = os.path.join(run_dir, "scope.lock.json")
    if not os.path.isfile(lock):
        return None, None, None
    return rid, run_dir, lock


# ------------------------------------------------------------------- redaction

def redact(text):
    """The IDENTICAL redaction transform as `.claude/hooks/evidence-log.sh` redact() (B3),
    hand-copied BYTE-EQUIVALENT here and in tests/fixtures/m6.5/_m65common.sh
    evidence_log_redact() — all three MUST stay in lockstep (redaction-parity, C3 test):
      sed -E 's/(sk-[A-Za-z0-9_-]{8,})/[REDACTED_API_KEY]/g;
              s/(password|secret|token|api[_-]?key)=([^[:space:]]+)/\\1=[REDACTED]/gi;
              s/AKIA[0-9A-Z]{16}/[REDACTED_AWS_KEY]/g;
              s/eyJ[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+/[REDACTED_JWT]/g;
              s/xox[baprs]-[A-Za-z0-9-]+/[REDACTED_SLACK_TOKEN]/g;
              s/gh[opsu]_[A-Za-z0-9]+/[REDACTED_GH_TOKEN]/g;
              s/ya29\\.[A-Za-z0-9_-]+/[REDACTED_GOOGLE_TOKEN]/g;
              s/-----BEGIN[^-]*PRIVATE KEY-----/[REDACTED_PRIVATE_KEY]/g;
              s/(Authorization|Bearer)[ :]+[^[:space:]]+/[REDACTED_AUTH]/gi'
    The `sk-`, AKIA, JWT, Slack, GitHub, Google and PRIVATE KEY rules are case-SENSITIVE; the
    `key=VALUE` and Authorization/Bearer rules are case-insensitive (sed `/gi`, Python re.IGNORECASE).
    Python `[^\\s]` == POSIX `[^[:space:]]` for ASCII, so the two dialects mask identical spans.

    A5 precision (recorded at the human gate): this transform is scoped to COMMAND / CONTENT
    payloads. A secret embedded in a bare file PATH (no `key=` form) is NOT caught here by design;
    that case is covered by the path-only secret DENY (`is_secret_path`), which refuses the operation
    before any path reaches a log. So the absolute no-raw-secret guarantee is: redact() over payloads
    + path-only deny over paths — never opening a secret file's contents in either lane.
    """
    text = re.sub(r"(sk-[A-Za-z0-9_-]{8,})", "[REDACTED_API_KEY]", text)
    text = re.sub(r"(password|secret|token|api[_-]?key)=([^\s]+)",
                  lambda m: m.group(1) + "=[REDACTED]", text, flags=re.IGNORECASE)
    text = re.sub(r"AKIA[0-9A-Z]{16}", "[REDACTED_AWS_KEY]", text)
    text = re.sub(r"eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+", "[REDACTED_JWT]", text)
    text = re.sub(r"xox[baprs]-[A-Za-z0-9-]+", "[REDACTED_SLACK_TOKEN]", text)
    text = re.sub(r"gh[opsu]_[A-Za-z0-9]+", "[REDACTED_GH_TOKEN]", text)
    text = re.sub(r"ya29\.[A-Za-z0-9_-]+", "[REDACTED_GOOGLE_TOKEN]", text)
    text = re.sub(r"-----BEGIN[^-]*PRIVATE KEY-----", "[REDACTED_PRIVATE_KEY]", text)
    text = re.sub(r"(Authorization|Bearer)[ :]+[^\s]+", "[REDACTED_AUTH]", text, flags=re.IGNORECASE)
    return text


# ------------------------------------------------------ secret path/glob (mirror)
# Byte-faithful mirror of `.claude/hooks/secret-guard.sh` is_secret_path / is_secret_glob. PATH /
# GLOB-STRING decisions ONLY — no file is ever opened, so this guard cannot itself leak a secret.

def is_secret_path(p):
    if not p:
        return False
    base = p.replace("\\", "/").rsplit("/", 1)[-1].lower()
    low = p.lower()
    if base in SECRET_ALLOW_BASENAMES:
        return False
    if base == ".env" or base.startswith(".env."):
        return True
    if re.search(r"\.(pem|key|p12|pfx|keystore|jks)$", base):
        return True
    if base in ("id_rsa", "id_dsa", "id_ecdsa", "id_ed25519"):
        return True
    if base in (".npmrc", ".netrc", ".pgpass", "credentials.json"):
        return True
    if "service-account" in base and base.endswith(".json"):
        return True
    if re.search(r"secrets?.*\.(json|ya?ml|env)$", base):
        return True
    if re.search(r"(^|/)\.ssh/", low) or re.search(r"(^|/)\.aws/credentials$", low) \
            or re.search(r"(^|/)\.gnupg/", low):
        return True
    return False


def is_secret_glob(g):
    if not g:
        return False
    low = g.lower()
    if re.search(r"\.(example|sample|template|dist)$", low):
        return False
    if re.search(r"(\.env($|\.|.*)|\.pem$|\.key$|id_rsa|id_ed25519|\.p12$|\.pfx$|\.keystore$|"
                 r"\.jks$|\.npmrc|credential|/\.ssh/|/\.aws/|service-account|secret)", low):
        return True
    return False


# ------------------------------------------------- Bash static floors (mode port)
# Faithful port of `.claude/hooks/pre-tool-guard.sh` static blocks, applied to the whitespace-
# collapsed one-line command. Each entry: (verdict, compiled-regex, reason, min-mode-scope). The
# dynamic L1 write-radius (Block D) is NOT here — it is the armed+active `bin/dmc bash-radius` call.

def _oneline(command):
    return re.sub(r"\s+", " ", command.replace("\n", " ")).strip()


# order and semantics mirror pre-tool-guard.sh exactly.
_FLOORS = [
    # F1..F6 + DB: Block A — enforced in ALL modes (active|passive|off).
    ("deny", re.compile(r"(^|[;&|`$()\s])rm\s+-rf\s+(/|\.|\*|~|/\*)", re.IGNORECASE),
     "Do-Me-Coding blocked destructive rm -rf command. Narrow the target and get explicit "
     "approval.", "all"),
    ("deny", re.compile(r"sudo\s+rm\s+-rf|git\s+push\s+.*--force|prisma\s+migrate\s+reset|"
                        r"rails\s+db:drop|python\s+manage\.py\s+flush|kubectl\s+delete|"
                        r"terraform\s+destroy", re.IGNORECASE),
     "Do-Me-Coding blocked a high-risk destructive command. Create an approved plan and request "
     "explicit human approval.", "all"),
    ("deny", re.compile(r"(^|[;&|\s])(printenv|cat\s+\.env|cat\s+.*\.env|cat\s+~/.ssh|"
                        r"cat\s+~/.aws)", re.IGNORECASE),
     "Do-Me-Coding blocked a command that may expose secrets. Use targeted, redacted inspection "
     "instead.", "all"),
    ("deny", re.compile(r"(DROP\s+DATABASE|TRUNCATE\s+TABLE)", re.IGNORECASE),
     "Do-Me-Coding blocked a catastrophic database command. Require explicit approval and rollback "
     "plan.", "all"),
    ("deny", re.compile(r"(^|[;&|`]|sudo\s+|env\s+([A-Za-z_][A-Za-z0-9_]*=\S*\s+)*)\s*git\s+"
                        r"(-\S+\s+([^-]\S*\s+)?)*apply([^A-Za-z0-9_-]|$)", re.IGNORECASE),
     "Do-Me-Coding blocked 'git apply': a worker diff is a review artifact, not an executable "
     "patch. Translate an accepted proposal into scope-guarded Edit/Write under a run scope, then "
     "verify.", "all"),
    ("deny", re.compile(r"(^|[;&|`]|sudo\s+)\s*patch([^A-Za-z0-9_-]|$)", re.IGNORECASE),
     "Do-Me-Coding blocked a 'patch' application form. Worker diffs are review artifacts; apply "
     "accepted changes via scope-guarded Edit/Write, never patch.", "all"),
    # Block B — deny tier, enforced in active + passive; stands down in off.
    ("deny", re.compile(r"git\s+reset\s+--hard|(DELETE\s+FROM)", re.IGNORECASE),
     "Do-Me-Coding blocked a destructive command (use /dmc-off only when intentionally stepping "
     "aside). Require explicit approval.", "not-off"),
    # Block C — ask tier, active only.
    ("ask", re.compile(r"(npm|pnpm|yarn|bun)\s+publish|npm\s+audit\s+fix\s+--force|schema\s+push|"
                       r"migrate\s+(deploy|dev|reset)|npm\s+install|pnpm\s+install|yarn\s+install|"
                       r"bun\s+install", re.IGNORECASE),
     "Do-Me-Coding detected a package, migration, publish, or schema-changing command. Confirm "
     "this is intended.", "active"),
]


def classify_bash_floors(command, mode):
    """Return (verdict, reason) for the first matching static floor given the mode, else (None, None).
    verdict in {'deny','ask'}. Mode scoping mirrors pre-tool-guard.sh's block gating exactly."""
    one = _oneline(command)
    for verdict, rx, reason, scope in _FLOORS:
        if scope == "not-off" and mode == "off":
            continue
        if scope == "active" and mode != "active":
            continue
        if rx.search(one):
            return verdict, reason
    return None, None


# Block C ask-class label (advisory only, v1.1.5). Byte-faithful mirror of pre-tool-guard.sh:140-145
# PTG_ASK_CLASS precedence (publish > audit-force > schema-push > migrate > install-fallback). The
# label feeds ONLY the value-blind stand-down notice/log; it NEVER affects matching or the ask
# verdict and NEVER carries the command text.
_ASK_CLASS_RULES = (
    ("publish", re.compile(r"(npm|pnpm|yarn|bun)\s+publish", re.IGNORECASE)),
    ("audit-force", re.compile(r"npm\s+audit\s+fix\s+--force", re.IGNORECASE)),
    ("schema-push", re.compile(r"schema\s+push", re.IGNORECASE)),
    ("migrate", re.compile(r"migrate\s+(deploy|dev|reset)", re.IGNORECASE)),
)


def ask_class(command):
    """Return the Block C consequence class of `command` (publish|audit-force|schema-push|migrate|
    install). `install` is the fallback once the four consequential forms are ruled out — the exact
    precedence + fallback of pre-tool-guard.sh's PTG_ASK_CLASS."""
    one = _oneline(command)
    for label, rx in _ASK_CLASS_RULES:
        if rx.search(one):
            return label
    return "install"


# ------------------------------------------------------------- Ring-0 resolution

def _script_root():
    """adapters/codex/dmc_codex_common.py -> repo root (…/DMC)."""
    return os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))


def find_dmc(project_dir):
    for cand in (os.path.join(project_dir, "bin", "dmc"),
                 os.path.join(_script_root(), "bin", "dmc")):
        if cand and os.path.isfile(cand) and os.access(cand, os.X_OK):
            return cand
    return None


def find_scope_lock_lib(project_dir):
    for cand in (os.path.join(project_dir, "bin", "lib", "dmc-scope-lock.py"),
                 os.path.join(_script_root(), "bin", "lib", "dmc-scope-lock.py")):
        if cand and os.path.isfile(cand):
            return cand
    return None


def _reason_from_json(text, default):
    m = re.search(r'"reason":\s*"((?:[^"\\]|\\.)*)"', text or "")
    if m:
        try:
            return json.loads('"' + m.group(1) + '"')
        except Exception:
            return m.group(1)
    return default


def call_bash_radius(dmc, command, scope_lock):
    """`bin/dmc bash-radius --cmd CMD --scope-lock LOCK` -> (rc, reason). rc: 0 allow / 3 ask /
    4 deny / other = classifier failure (caller fails closed)."""
    try:
        r = subprocess.run([dmc, "bash-radius", "--cmd", command, "--scope-lock", scope_lock],
                           capture_output=True, text=True, timeout=20)
    except Exception:
        return None, "bash-radius classifier could not be executed"
    return r.returncode, _reason_from_json(r.stdout, "Bash write-radius adjudication")


def call_scope_adjudicate(scope_lib, lock, rel_path, op="edit"):
    """`python3 -B dmc-scope-lock.py --adjudicate LOCK REL OP` -> (rc, detail). rc 0 allow / 3
    refuse / other = adjudicator failure (caller fails closed)."""
    try:
        r = subprocess.run([sys.executable, "-B", scope_lib, "--adjudicate", lock, rel_path, op],
                           capture_output=True, text=True, timeout=20)
    except Exception:
        return None, "scope-lock adjudicator could not be executed"
    detail = (r.stdout or "").strip() or "scope-lock adjudication refused"
    return r.returncode, detail


def call_postbash_diff(dmc, lock, snapshot, root):
    """`bin/dmc postbash-diff --scope-lock LOCK --snapshot SNAP --root ROOT` -> (rc, reason,
    blocked_paths). rc 0 clean / 4 blocked / other = failure (caller fails closed)."""
    try:
        r = subprocess.run([dmc, "postbash-diff", "--scope-lock", lock, "--snapshot", snapshot,
                            "--root", root], capture_output=True, text=True, timeout=30)
    except Exception:
        return None, "post-Bash diff guard could not be executed", []
    reason = _reason_from_json(r.stdout, "post-Bash out-of-scope change detected")
    paths = []
    m = re.search(r'"blocked_paths":\s*\[([^\]]*)\]', r.stdout or "")
    if m:
        paths = [p for p in re.findall(r'"((?:[^"\\]|\\.)*)"', m.group(1))]
    return r.returncode, reason, paths


def call_stop_gate(dmc, root, report=None):
    """`bin/dmc stop-gate quick --root ROOT [--report FILE]` -> (rc, text). rc 0 pass / non-zero
    hold."""
    args = [dmc, "stop-gate", "quick", "--root", root]
    if report:
        args += ["--report", report]
    try:
        r = subprocess.run(args, capture_output=True, text=True, timeout=30)
    except Exception:
        return None, "stop-gate could not be executed"
    return r.returncode, ((r.stdout or "") + (r.stderr or "")).strip()


def run_block_marker(dmc, root, reason, paths):
    """Best-effort sticky BLOCKED marker via `bin/dmc run block` (idempotent; never raises)."""
    args = [dmc, "run", "block", "--root", root, "--reason", reason,
            "--created-by", "dmc-codex-postbash-diff"]
    if paths:
        args.append("--paths")
        args += paths
    try:
        subprocess.run(args, capture_output=True, text=True, timeout=20)
    except Exception:
        pass


# ---------------------------------------------------------------- envelopes (out)
# Codex decision envelopes (docs/CODEX_ADAPTER.md §1 "Hook decision contracts"). Emitted as compact
# JSON; the shared fixture decision-extractors are whitespace-tolerant so parity compares the
# decision token, not raw bytes. ADVISORY: honoring of these envelopes is unproven on Codex.

def _emit(obj):
    sys.stdout.write(json.dumps(obj, separators=(",", ":"), ensure_ascii=False) + "\n")


def pretool_deny(reason):
    _emit({"hookSpecificOutput": {"hookEventName": "PreToolUse",
                                  "permissionDecision": "deny", "permissionDecisionReason": reason}})
    sys.exit(0)


def pretool_ask(reason):
    _emit({"hookSpecificOutput": {"hookEventName": "PreToolUse",
                                  "permissionDecision": "ask", "permissionDecisionReason": reason}})
    sys.exit(0)


def pretool_allow():
    """Allow == empty success (no envelope), byte-for-byte with the Claude shims' `exit 0`."""
    sys.exit(0)


def pretool_standdown(project_dir, cls):
    """Block C ask-tier ADVISORY stand-down under host-attested bypassPermissions (v1.1.5 mirror of
    pre-tool-guard.sh:152-158). Best-effort append ONE value-blind class/timestamp line (class + UTC
    only, NEVER the command text) to .harness/metrics/ask-tier-advisory.log, emit the byte-identical
    `{"systemMessage":…}` advisory, and exit 0 (allow pass-through). Every log failure is swallowed
    so the shim always exits 0. Deny floors are not consent-seeking and never reach here."""
    try:
        metrics_dir = os.path.join(project_dir, ".harness", "metrics")
        os.makedirs(metrics_dir, exist_ok=True)
        stamp = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        with open(os.path.join(metrics_dir, "ask-tier-advisory.log"), "a",
                  encoding="utf-8") as f:
            f.write("%s ask-tier-standdown class=%s\n" % (stamp, cls))
    except Exception:
        pass
    _emit({"systemMessage":
           "DMC advisory: ask-tier stood down under bypassPermissions (class: %s); "
           "deny floors remain active." % cls})
    sys.exit(0)


def stop_block(reason):
    _emit({"decision": "block", "reason": reason})
    sys.exit(0)


def ups_context(ctx):
    _emit({"hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "additionalContext": ctx}})
    sys.exit(0)
