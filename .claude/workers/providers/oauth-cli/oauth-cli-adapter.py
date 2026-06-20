#!/usr/bin/env python3
"""Do-Me-Coding oauth-cli worker adapter (v0.2.2).

Second LIVE provider (`provider_target.type=oauth_cli`). Instead of an API key, it obtains a worker proposal
from a locally-installed, already-authenticated CLI tool that owns an OAuth/session credential OUTSIDE the repo.
The adapter shells out to a C4-validated local binary, feeds it a sanitized task payload on stdin, captures its
stdout, and normalizes that into a WORKER_RESULT_SCHEMA result.

SAFETY CONTRACT:
- DEFAULT MODE = --mock (NO subprocess against the configured CLI). --live --allow-exec is strongly opt-in.
- DMC NEVER reads/stores/logs/serializes/transmits/refreshes the OAuth token. No *_API_KEY env secret exists.
  The auth precheck is non-interactive and token-blind; DMC never drives a login flow.
- Token-material guard (C1): stdout AND stderr scanned (SECRET_VALUE + explicit OAuth/JWT/Bearer patterns) BEFORE
  any persistence/normalization; apparent token -> redact-and-reject (fail-closed). Token VALUES are never printed.
- Subprocess (C4): C4-validated binary (absolute, regular, executable, non-symlink, TOCTOU re-check); shell=False
  ALWAYS; argv list; payload via stdin (never argv); bounded timeout; minimal explicit child env; non-zero exit ->
  fail-closed.
- Pure transform: never writes repo/product files, never runs git, never applies patches. (Writes ONLY --out.)
- Runs worker-context-guard.sh FIRST (fail-closed). Output is validated by worker-result-check.py at import.

Usage:
  oauth-cli-adapter.py --task <task.json> --mock <cli-stdout-fixture.json> [--out <result.json>]
  oauth-cli-adapter.py --task <task.json> --live --allow-exec [--out <result.json>]   # opt-in; needs DMC_OAUTHCLI_BIN
"""
import argparse, json, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))   # .claude/workers/providers/oauth-cli -> repo root
CTX_GUARD = os.path.join(REPO, ".claude", "hooks", "worker-context-guard.sh")

# Baseline secret detector (shared with glm-api / worker-result-check). NOTE: this alone MISSES OAuth token shapes.
SECRET_VALUE = re.compile(
    r'(sk-[A-Za-z0-9_-]{8,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----'
    r'|xox[baprs]-[0-9A-Za-z-]+|ghp_[A-Za-z0-9]{20,})')

# C1: explicit OAuth/bearer/JWT token-material patterns the local CLI may emit (SECRET_VALUE does not cover these).
OAUTH_TOKEN_PATTERNS = [
    re.compile(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),                 # JWT (access_token / id_token)
    re.compile(r'(?i)bearer\s+[A-Za-z0-9._~+/-]+=*'),                                 # Bearer tokens
    re.compile(r'(?i)authorization\s*:\s*\S+'),                                       # Authorization header echoes
    re.compile(r'(?i)(access_token|refresh_token|id_token)["\'\s:=]+\S+'),            # access/refresh/id_token kv/json
    re.compile(r'gh[opsu]_[A-Za-z0-9]{20,}'),                                         # GitHub gho_/ghp_/ghs_/ghu_
    re.compile(r'ya29\.[A-Za-z0-9._-]+'),                                             # Google OAuth
]
# Obvious placeholders that are NOT real token material (value-side secret-likeness heuristic, plan §3).
PLACEHOLDER = re.compile(r'<redacted>|<\.\.\.>|<[A-Za-z][A-Za-z0-9 _-]*>|\*{3,}|\$\{?[A-Za-z_][A-Za-z0-9_]*\}?|x{6,}', re.I)

MAX_CONTENT_LEN = 8000
CONFIDENCE_VALUES = ("low", "med", "high")
DEFAULT_MODEL = "oauth-cli-model"


def die(msg, code=1):
    # Error messages NEVER include a token/secret value (no matched span is ever interpolated here).
    print(f"oauth-cli-adapter: {msg}", file=sys.stderr)
    sys.exit(code)


def is_ci():
    # Best-effort defense-in-depth ONLY — never the sole live-mode guard.
    return any(os.environ.get(v) for v in ("CI", "GITHUB_ACTIONS", "GITLAB_CI", "BUILDKITE", "JENKINS_URL"))


def run_context_guard(task_path):
    if not os.path.exists(CTX_GUARD):
        die("worker-context-guard.sh not found; refusing to dispatch")
    r = subprocess.run(["bash", CTX_GUARD, task_path], capture_output=True, text=True)
    if r.returncode != 0:
        die(f"context-guard rejected task (fail-closed): {r.stderr.strip()}")


def build_payload(task):
    """Sanitized prompt payload: objective, summary, validated snippets, file NAME lists. No file contents beyond
    clipped snippets, no secrets, no broad repo context."""
    payload = {
        "objective": task.get("objective", ""),
        "context_summary": task.get("context_summary", ""),
        "relevant_snippets": task.get("relevant_snippets", []),
        "allowed_files": task.get("allowed_files", []),
        "forbidden_files": task.get("forbidden_files", []),
        "expected_output_type": task.get("expected_output_type", "unified_diff"),
        "model": os.environ.get("DMC_OAUTHCLI_MODEL") or (task.get("provider_target") or {}).get("model") or DEFAULT_MODEL,
    }
    if SECRET_VALUE.search(json.dumps(payload)) or find_token_material(json.dumps(payload)):
        die("built payload contains a secret/token value — refusing (reject unsafe context, not redact)")
    return payload


# ----------------------------------------------------------------------------- C1 token-material guard
def find_token_material(*texts):
    """Return a list of NON-VALUE detector labels for any apparent token/secret in the given text(s). Token VALUES
    are never returned/logged. Obvious placeholders are excluded (value-side heuristic). Used to redact-and-reject
    CLI stdout/stderr BEFORE persistence/normalization (and to re-assert the payload is clean)."""
    labels = []
    for text in texts:
        if not text:
            continue
        for rx in [SECRET_VALUE, *OAUTH_TOKEN_PATTERNS]:
            for m in rx.finditer(text):
                span = m.group(0)
                if PLACEHOLDER.search(span):
                    continue   # placeholder / example value -> not real token material
                labels.append(rx.pattern[:24])
                break          # one hit per pattern is enough; never collect the value
    return labels


# ----------------------------------------------------------------------------- normalization (ported from glm-api, C2)
def _strip_code_fence(text):
    """If text is wrapped in a single markdown code fence (```json … ``` or bare ``` … ```), return the inner
    block; otherwise return the whitespace-stripped text unchanged."""
    s = text.strip()
    m = re.match(r'^```[A-Za-z0-9_+-]*[ \t]*\r?\n(.*?)\r?\n?```[ \t]*$', s, re.DOTALL)
    return m.group(1).strip() if m else s


def _first_json_object(text):
    """Isolate the first balanced top-level {…} object, respecting JSON string literals/escapes. None if absent."""
    start = text.find('{')
    if start == -1:
        return None
    depth, in_str, esc = 0, False, False
    for i in range(start, len(text)):
        c = text[i]
        if in_str:
            if esc:
                esc = False
            elif c == '\\':
                esc = True
            elif c == '"':
                in_str = False
        elif c == '"':
            in_str = True
        elif c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                return text[start:i + 1]
    return None


def _parse_content(content):
    """Parse model content into a JSON object dict, or None. Strip a fence, try json.loads, then isolate the first
    balanced {…} and retry. json.loads ONLY — never eval/exec. Never raises."""
    if not content:
        return None
    candidate = _strip_code_fence(content)
    for cand in (candidate, _first_json_object(candidate)):
        if not cand:
            continue
        try:
            parsed = json.loads(cand)
        except (ValueError, TypeError):
            continue
        if isinstance(parsed, dict):
            return parsed
    return None


def normalize_response(resp):
    """Normalize a GLM-shaped envelope into the structured shape map_to_result consumes. Reused verbatim from the
    proven v0.2.1.1 path. CLI stdout is wrapped into a synthetic envelope by stdout_to_envelope() (C2) BEFORE this
    is called — a raw string is never passed in (that would short-circuit and crash map_to_result)."""
    if not isinstance(resp, dict) or "choices" not in resp:
        return resp
    content, finish_reason = "", None
    try:
        choices = resp.get("choices")
        if isinstance(choices, list) and choices:
            first = choices[0]
            if isinstance(first, dict):
                finish_reason = first.get("finish_reason")
                msg = first.get("message")
                if isinstance(msg, dict) and isinstance(msg.get("content"), str):
                    content = msg["content"]
    except Exception:
        content = ""

    content = content[:MAX_CONTENT_LEN]
    parsed = _parse_content(content) if finish_reason in (None, "stop") else None

    if isinstance(parsed, dict):
        fc = parsed.get("files_changed")
        if not (isinstance(fc, list) and all(isinstance(x, str) for x in fc)):
            fc = []
        fcons = parsed.get("files_considered")
        norm = {
            "summary": parsed["summary"] if isinstance(parsed.get("summary"), str) else "",
            "files_considered": fcons if isinstance(fcons, list) and all(isinstance(x, str) for x in fcons) else [],
            "files_changed": fc,
            "proposed_patch": parsed["proposed_patch"] if isinstance(parsed.get("proposed_patch"), str) else "",
            "instructions": parsed["instructions"] if isinstance(parsed.get("instructions"), str) else "",
            "confidence": parsed["confidence"] if parsed.get("confidence") in CONFIDENCE_VALUES else "med",
        }
    else:
        stripped = content.strip()
        first_line = next((ln.strip() for ln in stripped.splitlines() if ln.strip()), "")
        norm = {
            "summary": first_line[:280],
            "files_considered": [],
            "files_changed": [],
            "proposed_patch": "",
            "instructions": stripped,
            "confidence": "low",
        }

    norm["model_claimed"] = resp.get("model") or DEFAULT_MODEL
    norm["invocation_id"] = resp.get("id") or "oauth-cli-live"
    return norm


def stdout_to_envelope(cli_stdout, model=None, invocation_id=None):
    """C2: wrap raw CLI stdout (a STRING) in a synthetic GLM-shaped envelope so normalize_response can reuse the
    proven path. NEVER feed a raw string to normalize_response/map_to_result directly."""
    return {
        "choices": [{"message": {"content": cli_stdout if isinstance(cli_stdout, str) else ""}, "finish_reason": "stop"}],
        "model": model or DEFAULT_MODEL,
        "id": invocation_id or "oauth-cli-live",
    }


def map_to_result(task, resp):
    """Map a normalized response to WORKER_RESULT_SCHEMA. credential_exposure/no_direct_mutation are adapter-stamped
    and NEVER read from the CLI output."""
    return {
        "task_id": task.get("task_id"),
        "summary": resp.get("summary", ""),
        "files_considered": resp.get("files_considered", []),
        "files_changed": resp.get("files_changed", []),
        "proposed_patch": resp.get("proposed_patch", ""),
        "instructions": resp.get("instructions", ""),
        "risks": resp.get("risks", []),
        "assumptions": resp.get("assumptions", []),
        "test_suggestions": resp.get("test_suggestions", []),
        "confidence": resp.get("confidence", "med"),
        "unresolved_questions": resp.get("unresolved_questions", []),
        "no_direct_mutation": True,
        "provider_metadata": {
            "provider_type": "oauth_cli",
            "provider": "oauth-cli",
            "model_claimed": resp.get("model_claimed") or DEFAULT_MODEL,
            "generated_at": resp.get("generated_at", "1970-01-01T00:00:00Z"),
            "invocation_id": resp.get("invocation_id", "oauth-cli"),
            "credential_exposure": "none",
        },
    }


# ----------------------------------------------------------------------------- C4 live exec path
def resolve_binary(raw):
    """C4 trust model: a user-configured, validated local binary. Reject anything not absolute / regular /
    executable / non-symlink, and re-validate the resolved target (TOCTOU mitigation). Returns the validated path."""
    if not raw:
        die("DMC_OAUTHCLI_BIN not set — cannot run --live (no provider call made)")
    if not os.path.isabs(raw):
        die("DMC_OAUTHCLI_BIN must be an absolute path — refusing")
    if re.search(r'[;|&$<>()`\n\r]', raw):
        die("DMC_OAUTHCLI_BIN contains shell metacharacters — refusing (path, not a shell string)")
    if os.path.islink(raw):
        die("DMC_OAUTHCLI_BIN is a symlink — refusing")
    if not os.path.isfile(raw):
        die("DMC_OAUTHCLI_BIN is not an existing regular file — refusing")
    if not os.access(raw, os.X_OK):
        die("DMC_OAUTHCLI_BIN is not executable — refusing")
    real = os.path.realpath(raw)
    # TOCTOU re-check on the resolved target.
    if os.path.islink(real) or not os.path.isfile(real) or not os.access(real, os.X_OK):
        die("DMC_OAUTHCLI_BIN resolved target failed re-validation — refusing")
    return real


def minimal_env():
    """Explicit minimal child environment — do NOT inherit the full parent env (no repo/DMC secrets, no provider
    keys). Forwards only locale/path basics; DMC_FAKECLI_* test affordances are forwarded only if present (absent in
    production)."""
    keep = {}
    for k in ("PATH", "HOME", "LANG", "LC_ALL", "TMPDIR"):
        if k in os.environ:
            keep[k] = os.environ[k]
    for k in os.environ:
        if k.startswith("DMC_FAKECLI_"):   # deterministic local test stub control (non-secret)
            keep[k] = os.environ[k]
    return keep


def auth_precheck(bin_path, env, timeout):
    """Token-blind, non-interactive auth status check. Returns True iff the CLI reports authenticated. NEVER drives
    a login; NEVER parses/echoes token material."""
    subcmd = os.environ.get("DMC_OAUTHCLI_AUTH_SUBCMD", "auth-status")
    try:
        r = subprocess.run([bin_path, subcmd], capture_output=True, text=True, timeout=timeout, shell=False, env=env)
    except subprocess.TimeoutExpired:
        die("auth precheck exceeded timeout — fail-closed (no run attempted)")
    # The auth output must itself never carry token material.
    if find_token_material(r.stdout, r.stderr):
        die("auth-status output contained token-like material — refusing (token-blind)")
    if r.returncode != 0:
        return False
    parsed = _parse_content(r.stdout)
    return bool(parsed.get("authenticated")) if isinstance(parsed, dict) else False


def run_cli(bin_path, payload, env, timeout):
    """Execute the CLI run subcommand with the sanitized payload on stdin. Token-guards BOTH streams before returning
    stdout. Non-zero exit / timeout -> fail-closed. NEVER echoes stderr (it may carry a token)."""
    subcmd = os.environ.get("DMC_OAUTHCLI_RUN_SUBCMD", "run")
    try:
        r = subprocess.run([bin_path, subcmd], input=json.dumps(payload), capture_output=True, text=True,
                           timeout=timeout, shell=False, env=env)
    except subprocess.TimeoutExpired:
        die("CLI run exceeded timeout — killed, fail-closed (no partial result trusted)")
    if r.returncode != 0:
        die(f"CLI run exited non-zero ({r.returncode}) — fail-closed (no partial result; stderr not echoed)")
    # C1: redact-and-reject BEFORE the output is used/persisted.
    if find_token_material(r.stdout, r.stderr):
        die("CLI output contained token-like material — redact-and-reject (fail-closed before persistence)")
    return r.stdout


def live_call(task, payload):
    """LIVE path (unexercised by build/CI; exercised offline only by the local fake-CLI stub). Multi-gated by main()."""
    bin_path = resolve_binary(os.environ.get("DMC_OAUTHCLI_BIN"))
    env = minimal_env()
    timeout = float(os.environ.get("DMC_OAUTHCLI_TIMEOUT_SECONDS", "60"))
    if not auth_precheck(bin_path, env, timeout):
        die("CLI is not authenticated — fail-closed. Log in via the CLI's own login OUTSIDE DMC (DMC never drives login).")
    return run_cli(bin_path, payload, env, timeout)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--task", required=True)
    ap.add_argument("--mock")
    ap.add_argument("--live", action="store_true")
    ap.add_argument("--allow-exec", action="store_true")
    ap.add_argument("--out")
    a = ap.parse_args()
    task = json.load(open(a.task))

    run_context_guard(a.task)          # fail-closed BEFORE building any payload
    payload = build_payload(task)      # re-asserts no secret/token value in payload

    if not a.live:
        if not a.mock:
            die("default mode requires --mock <cli-stdout-fixture.json> (no subprocess). Use --live --allow-exec for live.")
        fixture = json.load(open(a.mock))                 # {"stdout": "...", "stderr": "..."} — represents CLI output
        out_text = fixture.get("stdout", "") if isinstance(fixture, dict) else ""
        err_text = fixture.get("stderr", "") if isinstance(fixture, dict) else ""
        if find_token_material(out_text, err_text):       # C1: same guard as live, BEFORE normalization
            die("mock CLI output contained token-like material — redact-and-reject (fail-closed before persistence)")
        cli_stdout = out_text
    else:
        # PRIMARY live-mode gates (CI check is defense-in-depth only):
        if not a.allow_exec:
            die("--live requires explicit --allow-exec; refusing (no CLI executed)")
        if is_ci():
            die("--live blocked: CI environment detected (defense-in-depth). Refusing automatic CLI execution.")
        cli_stdout = live_call(task, payload)             # token-guarded inside run_cli

    norm = normalize_response(stdout_to_envelope(cli_stdout))   # C2: synthetic envelope, never a raw string
    result = map_to_result(task, norm)

    if a.out:
        json.dump(result, open(a.out, "w"), indent=2); open(a.out, "a").write("\n")
        print(f"oauth-cli-adapter: wrote result -> {a.out}")
    else:
        print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
