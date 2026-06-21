#!/usr/bin/env python3
"""Do-Me-Coding manual-import worker adapter (v0.3.1) — STANDALONE PURE-VALIDATION IMPORTER.

provider_target.type = manual_import. Ingests a manually-supplied, provider-like LOOSE proposal artifact
("manual-import envelope v1"), validates it FAIL-CLOSED, and emits a normalized WORKER_RESULT_SCHEMA result.

This is NOT a network/exec provider: NO live mode, NO credentials, NO network, NO provider subprocess (the ONLY
subprocess is the read-only worker-context-guard.sh on the TASK). NO auto-apply: the result is a review artifact
(no_direct_mutation=true); application happens later via scope-guarded Edit/Write, never `git apply`.

The imported artifact is UNTRUSTED. Adapter-owned identity/provenance/safety-invariant fields are REJECTED if
supplied (a human cannot assert their own provenance). Token/secret-shaped content in the RAW import is REJECTED
before any result is constructed — the real credential gate. credential_exposure="none" describes ONLY DMC's own
handling AFTER the raw scan passes — NOT the unknown upstream tool the human used.

Guard parity: at least as strict as worker-result-check.py, plus adapter-only superset guards. The OAuth/JWT/Bearer/
ya29/access_token/gh[opsu]_/Authorization token class and the strict envelope shape are adapter-SOLE gates (the
validator covers neither). Token detectors are REUSED via shared-source import from oauth-cli-adapter.py (the exact
list, not a re-derived subset; drift-checked by the verify harness V16). Scope / disallowed-category / sk-class
secret / no_direct_mutation are also validator-backstopped (worker-result-check.py).

Trust posture: a trust-minimized LOCAL ingestion lane that validates a DEFINED contract (envelope + safety battery),
NOT the semantic truth of the proposal, and NOT a human-approval bypass.

Usage:
  manual-import-adapter.py --task <task.json> --import <artifact.json|-> [--out <result.json>]
Exit: 0 accepted / 1 rejected (fail-closed) / 2 usage|--out refused.
"""
import argparse, importlib.util, json, os, re, subprocess, sys

# Importing the shared detector modules below must NOT write .pyc into __pycache__ (esp. under the protected
# .claude/hooks/ dir). Disable bytecode caching for this process before any importlib load.
sys.dont_write_bytecode = True

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))   # .../providers/manual-import -> repo root
CTX_GUARD = os.path.join(REPO, ".claude", "hooks", "worker-context-guard.sh")
OAUTH_ADAPTER = os.path.join(REPO, ".claude", "workers", "providers", "oauth-cli", "oauth-cli-adapter.py")
RESULT_CHECK = os.path.join(REPO, ".claude", "hooks", "worker-result-check.py")

CONFIDENCE_VALUES = ("low", "med", "high")
GENERATED_AT = "1970-01-01T00:00:00Z"   # deterministic sentinel (NO wall-clock) — mirrors glm/oauth offline stamps
INVOCATION_ID = "manual-import"         # deterministic sentinel (NO randomness)
MODEL_CLAIMED = "unknown"               # honest: DMC does not know the upstream tool/model
DEFAULT_MAX_BYTES = 1 << 20             # 1 MiB; override via DMC_MANUAL_IMPORT_MAX_BYTES

# "manual-import envelope v1": the human supplies ONLY these proposal-substance fields.
MANDATORY_FIELDS = ("summary", "files_changed", "confidence")        # plus (proposed_patch OR instructions)
OPTIONAL_FIELDS = ("instructions", "proposed_patch", "files_considered", "risks",
                   "assumptions", "test_suggestions", "unresolved_questions")
HUMAN_FIELDS = set(MANDATORY_FIELDS) | set(OPTIONAL_FIELDS)
# Adapter-OWNED identity / provenance / safety invariants — REJECTED if present in the import.
ADAPTER_OWNED = ("task_id", "provider_type", "provider", "provider_metadata",
                 "generated_at", "invocation_id", "no_direct_mutation", "credential_exposure")
LIST_FIELDS = ("files_changed", "files_considered", "risks", "assumptions",
               "test_suggestions", "unresolved_questions")
STR_FIELDS = ("summary", "proposed_patch", "instructions")


def die(msg, code=1):
    # GENERIC / leak-clean: NEVER interpolates any value, key, or path from the imported artifact.
    print(f"manual-import-adapter: {msg}", file=sys.stderr)
    sys.exit(code)


def _load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        die("cannot load a shared DMC detector module — refusing (fail-closed)", 2)
    mod = importlib.util.module_from_spec(spec)
    try:
        spec.loader.exec_module(mod)   # __main__-guarded source: defines constants/functions; runs no main()
    except Exception:
        die("failed to load a shared DMC detector module — refusing (fail-closed)", 2)
    return mod


# --- Shared-source EXACT reuse (no re-derived subset; drift-checked by the verify harness V16) ---
_OAUTH = _load(OAUTH_ADAPTER, "dmc_oauth_cli_adapter")
_RC = _load(RESULT_CHECK, "dmc_worker_result_check")
SECRET_VALUE = _OAUTH.SECRET_VALUE                  # sk-/AKIA/PRIVATE KEY/xox/ghp_ (identical to worker-result-check.py)
OAUTH_TOKEN_PATTERNS = _OAUTH.OAUTH_TOKEN_PATTERNS  # JWT/Bearer/Authorization/access_token/gh[opsu]/ya29 — adapter-sole gate
find_token_material = _OAUTH.find_token_material    # value-blind detector labels; PLACEHOLDER-excluded
DISALLOWED = _RC.DISALLOWED                         # .env*/lockfile/dependency/migration/binary/production-config
diff_paths = _RC.diff_paths                         # unified-diff touched-path parser


# --- --out write-target guard (canonicalized; refuse protected/secret OR canonicalization failure) ---
PROT_RE = re.compile(
    r'(^|/)\.env(\.|$)|\.pem$|\.key$|id_rsa|id_ed25519|credentials|secret|\.p12$|\.pfx$|\.keystore$'
    r'|\.claude/hooks|provider-router\.py|/ROUTING\.md$|WORKER_(TASK|RESULT|REVIEW)_SCHEMA\.md'
    r'|PROVIDER_CONTRACT\.md|workers/providers/(glm-api|oauth-cli|manual-import)|(^|/)dmc-glm-smoke$', re.I)


def out_refused(raw):
    if ".." in re.split(r'[/\\]', raw):   # reject any path-traversal component (operator picks --out, but a `..` target is refused)
        return True
    if PROT_RE.search(raw):
        return True
    base = os.path.basename(raw)
    if re.search(r'\.env($|\.)', base, re.I) and not re.search(r'\.(example|sample|template)$', base, re.I):
        return True
    parent = os.path.dirname(raw) or "."
    try:
        cparent = os.path.realpath(parent)   # resolves symlinks; failure => refuse (fail-closed)
    except Exception:
        return True
    if PROT_RE.search(os.path.join(cparent, base)):
        return True
    if os.path.islink(raw):
        try:
            tgt = os.path.realpath(raw)
        except Exception:
            return True
        if PROT_RE.search(tgt):
            return True
    return False


def run_context_guard(task_path):
    if not os.path.exists(CTX_GUARD):
        die("worker-context-guard.sh not found — refusing to import (fail-closed)")
    r = subprocess.run(["bash", CTX_GUARD, task_path], capture_output=True, text=True)   # positional, shell=False
    if r.returncode != 0:
        die("context-guard refused the task (fail-closed)")   # generic; do NOT echo guard stderr


def read_import(src):
    max_bytes = DEFAULT_MAX_BYTES
    env_max = os.environ.get("DMC_MANUAL_IMPORT_MAX_BYTES")
    if env_max:
        try:
            v = int(env_max)
            if v > 0:
                max_bytes = v
        except ValueError:
            pass
    if src == "-":
        raw = sys.stdin.buffer.read(max_bytes + 1)
    else:
        try:
            with open(src, "rb") as f:
                raw = f.read(max_bytes + 1)
        except OSError:
            die("cannot read --import artifact", 2)
    if len(raw) > max_bytes:
        die("import exceeds max artifact size — refusing (fail-closed)")
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError:
        die("import is not valid UTF-8 — refusing")


def validate_envelope(env):
    """Strict 'manual-import envelope v1': adapter-owned fields rejected if supplied; unknown keys rejected;
    mandatory set present + typed. ADAPTER-SOLE gate (worker-result-check.py performs no shape/unknown-field check)."""
    if not isinstance(env, dict):
        die("import is not a JSON object (manual-import envelope v1 required) — refusing")
    for key in env:
        if key in ADAPTER_OWNED:
            die("import supplies an adapter-owned field (identity/provenance/safety invariants are adapter-stamped, "
                "not human-supplied) — refusing")
        if key not in HUMAN_FIELDS:
            die("import contains a field outside manual-import envelope v1 (unknown field) — refusing")
    for k in MANDATORY_FIELDS:
        if k not in env:
            die("import is missing a mandatory envelope field — refusing")
    if not isinstance(env.get("summary"), str) or not env.get("summary").strip():
        die("invalid envelope: summary must be a non-empty string — refusing")
    if env.get("confidence") not in CONFIDENCE_VALUES:
        die("invalid envelope: confidence must be low|med|high — refusing")
    for k in STR_FIELDS:
        if k in env and not isinstance(env[k], str):
            die("invalid envelope: a text field must be a string — refusing")
    for k in LIST_FIELDS:
        if k in env:
            v = env[k]
            if not (isinstance(v, list) and all(isinstance(x, str) for x in v)):
                die("invalid envelope: a list field must be a list of strings — refusing")
    pp = env.get("proposed_patch", "") or ""
    instr = env.get("instructions", "") or ""
    if not pp.strip() and not instr.strip():
        die("invalid envelope: at least one of proposed_patch / instructions is required — refusing")


def check_scope(task, env):
    """Adapter-side scope/disallowed-category check (at-least-as-strict; also validator-backstopped). Leak-clean:
    never echoes a path. Reuses the validator's exact diff_paths + DISALLOWED (shared-source)."""
    allowed = set(task.get("allowed_files") or [])
    forbidden = set(task.get("forbidden_files") or [])
    fc = set(env.get("files_changed") or [])
    patch = env.get("proposed_patch", "") or ""
    dp = diff_paths(patch)
    if patch.strip() and dp != fc:
        die("files_changed does not match proposed_patch touched paths — refusing")
    for p in (fc | dp):
        if allowed and p not in allowed:
            die("out-of-scope path (not in task allowed_files) — refusing")
        if p in forbidden:
            die("forbidden_files path — refusing")
        for rx, _label in DISALLOWED:
            if rx.search(p):
                die("disallowed-category path — refusing")


def build_result(task, env):
    """Normalize envelope v1 + adapter-OWNED deterministic stamps -> WORKER_RESULT_SCHEMA result. Identity /
    provenance / safety invariants are stamped here, NEVER read from the import."""
    return {
        "task_id": task.get("task_id"),
        "summary": env.get("summary", ""),
        "files_considered": env.get("files_considered", []),
        "files_changed": env.get("files_changed", []),
        "proposed_patch": env.get("proposed_patch", ""),
        "instructions": env.get("instructions", ""),
        "risks": env.get("risks", []),
        "assumptions": env.get("assumptions", []),
        "test_suggestions": env.get("test_suggestions", []),
        "confidence": env.get("confidence", "med"),
        "unresolved_questions": env.get("unresolved_questions", []),
        "no_direct_mutation": True,
        "provider_metadata": {
            "provider_type": "manual_import",
            "provider": "manual-import",
            "model_claimed": MODEL_CLAIMED,
            "generated_at": GENERATED_AT,
            "invocation_id": INVOCATION_ID,
            "credential_exposure": "none",
        },
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--task", required=True)
    ap.add_argument("--import", dest="import_", required=True)
    ap.add_argument("--out")
    a = ap.parse_args()

    # --out write-target guard FIRST: refuse a protected/secret target before doing anything (write nothing).
    if a.out and out_refused(a.out):
        die("--out target is protected/secret — REFUSED (writing nothing)", 2)

    try:
        task = json.load(open(a.task))
    except (OSError, ValueError):
        die("cannot read/parse --task", 2)

    run_context_guard(a.task)                       # positional context-guard, fail-closed, BEFORE reading the import
    text = read_import(a.import_)                    # size-bounded read (stdin or file)

    # REAL CREDENTIAL GATE (pre-stamp): scan the RAW import for secret/token material. Reject fail-closed.
    if find_token_material(text):
        die("import contains secret/token-like material — REFUSED (fail-closed, no result constructed)")

    try:
        env = json.loads(text)
    except ValueError:
        die("import is not valid JSON — refusing")

    validate_envelope(env)                          # strict envelope v1 (adapter-sole gate)
    check_scope(task, env)                           # scope / disallowed-category (also validator-backstopped)
    result = build_result(task, env)                # normalize + deterministic stamps

    out_text = json.dumps(result, indent=2)
    if a.out:
        with open(a.out, "w") as f:
            f.write(out_text + "\n")
        print(f"manual-import-adapter: wrote result -> {a.out}")
    else:
        print(out_text)


if __name__ == "__main__":
    main()
