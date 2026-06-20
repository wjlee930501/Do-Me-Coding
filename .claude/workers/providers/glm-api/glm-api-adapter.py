#!/usr/bin/env python3
"""Do-Me-Coding glm-api worker adapter (v0.2.1).

Maps a sanitized DMC worker TASK -> GLM request -> WORKER_RESULT_SCHEMA result.

SAFETY CONTRACT:
- DEFAULT MODE = --mock (NO network). --live is multi-gated and unexercised by build/CI.
- Reads GLM_API_KEY from env ONLY; NEVER prints/logs/serializes the key value.
- Pure transform: never writes repo/product files, never runs git, never applies patches.
  (It may write ONLY the local-only result artifact given via --out.)
- Runs worker-context-guard.sh FIRST (fail-closed). Security model: reject unsafe context, not redact.

Usage:
  glm-api-adapter.py --task <task.json> --mock <response_fixture.json> [--out <result.json>]
  glm-api-adapter.py --task <task.json> --live --allow-network [--out <result.json>]   # opt-in; needs GLM_API_KEY
"""
import argparse, json, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))   # .claude/workers/providers/glm-api -> repo root
CTX_GUARD = os.path.join(REPO, ".claude", "hooks", "worker-context-guard.sh")

SECRET_VALUE = re.compile(
    r'(sk-[A-Za-z0-9_-]{8,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----'
    r'|xox[baprs]-[0-9A-Za-z-]+|ghp_[A-Za-z0-9]{20,})')

# Bound on model content (chars) before parsing/mapping: an over-long response cannot blow up memory or
# downstream checks. Clipping is applied to raw content (and any derived instructions/summary), never to a
# well-formed JSON object of reasonable size (the happy path is far under this cap).
MAX_CONTENT_LEN = 8000
CONFIDENCE_VALUES = ("low", "med", "high")


def die(msg, code=1):
    # Error messages NEVER include the key value (the value is not interpolated anywhere).
    print(f"glm-api-adapter: {msg}", file=sys.stderr)
    sys.exit(code)


def run_context_guard(task_path):
    if not os.path.exists(CTX_GUARD):
        die("worker-context-guard.sh not found; refusing to dispatch")
    r = subprocess.run(["bash", CTX_GUARD, task_path], capture_output=True, text=True)
    if r.returncode != 0:
        die(f"context-guard rejected task (fail-closed): {r.stderr.strip()}")


def build_payload(task):
    """Sanitized request payload: objective, summary, validated snippets, file NAME lists. No file contents
    beyond clipped snippets, no secrets, no broad repo context."""
    payload = {
        "objective": task.get("objective", ""),
        "context_summary": task.get("context_summary", ""),
        "relevant_snippets": task.get("relevant_snippets", []),
        "allowed_files": task.get("allowed_files", []),
        "forbidden_files": task.get("forbidden_files", []),
        "expected_output_type": task.get("expected_output_type", "unified_diff"),
        "model": os.environ.get("GLM_MODEL") or (task.get("provider_target") or {}).get("model") or "glm-5.2",
    }
    # SECURITY MODEL: reject, don't redact. Re-assert the final payload carries no secret VALUE.
    if SECRET_VALUE.search(json.dumps(payload)):
        die("built payload contains a secret value — refusing (reject unsafe context, not redact)")
    return payload


def _strip_code_fence(text):
    """If text is wrapped in a single markdown code fence (```json … ``` or bare ``` … ```), return the inner
    block; otherwise return the whitespace-stripped text unchanged."""
    s = text.strip()
    m = re.match(r'^```[A-Za-z0-9_+-]*[ \t]*\r?\n(.*?)\r?\n?```[ \t]*$', s, re.DOTALL)
    return m.group(1).strip() if m else s


def _first_json_object(text):
    """Isolate the first balanced top-level {…} object, respecting JSON string literals/escapes so braces inside
    strings don't affect depth. Returns the substring or None. Drops leading/trailing prose."""
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
    """Parse model content into a JSON object dict, or None if none can be isolated/parsed.
    Strategy: strip a code fence, try json.loads directly, then isolate the first balanced {…} and retry.
    json.loads ONLY — never eval/exec. Never raises."""
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
    """Normalize a provider response into the TOP-LEVEL structured shape map_to_result consumes.

    - Mock fixtures are already top-level structured (no `choices` key) -> passed through unchanged
      (mock-first backward compatibility).
    - Live GLM chat completions carry the answer in choices[0].message.content (a string). Extract it
      defensively (C2: no IndexError/KeyError/TypeError may escape) and parse it robustly (C1: tolerate markdown
      fences / surrounding prose; json.loads only). On any failure -> graceful low-confidence plain-text/empty
      fallback. Adapter-enforced fields (credential_exposure/no_direct_mutation) are NEVER read from the model
      here; map_to_result stamps them."""
    if not isinstance(resp, dict) or "choices" not in resp:
        return resp  # top-level structured mock -> unchanged

    # ---- defensive envelope extraction (C2) ----
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

    content = content[:MAX_CONTENT_LEN]  # bound length BEFORE parsing/mapping

    # Non-stop finish (length/content_filter/…) => content likely truncated => prefer the plain-text fallback.
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
        # plain-text / empty / malformed / non-stop fallback -> schema-valid, safe (empty file set, no patch)
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

    norm["model_claimed"] = resp.get("model") or "glm-5.2"
    norm["invocation_id"] = resp.get("id") or "glm-live"
    return norm


def map_to_result(task, resp):
    """Map a provider response (mock fixture or live) to WORKER_RESULT_SCHEMA. credential_exposure is always none."""
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
            "provider_type": "api_key",
            "provider": "glm-api",
            "model_claimed": resp.get("model_claimed") or resp.get("model") or "glm-5.2",
            "generated_at": resp.get("generated_at", "1970-01-01T00:00:00Z"),
            "invocation_id": resp.get("invocation_id", "glm-mock"),
            "credential_exposure": "none",
        },
    }


def is_ci():
    # Best-effort defense-in-depth ONLY — never the sole live-mode guard.
    return any(os.environ.get(v) for v in ("CI", "GITHUB_ACTIONS", "GITLAB_CI", "BUILDKITE", "JENKINS_URL"))


def live_call(payload):
    """LIVE path (unexercised by build/CI). Key from env ONLY; Authorization header redacted in logs."""
    key = os.environ.get("GLM_API_KEY")
    if not key:
        die("GLM_API_KEY not set (no value to print) — cannot run --live; no network call made")
    import urllib.request
    base = os.environ.get("GLM_API_BASE", "https://open.bigmodel.cn/api/paas/v4").rstrip("/")
    timeout = float(os.environ.get("GLM_API_TIMEOUT_SECONDS", "60"))
    system_msg = ("Return ONLY a single JSON object with keys: summary (string), files_changed (array of file "
                  "paths you changed), proposed_patch (unified diff string), confidence (one of low|med|high). "
                  "No prose, no markdown code fences. If you cannot produce a patch, return files_changed: [] and "
                  "put your analysis in an instructions field.")
    body = json.dumps({"model": payload["model"],
                       "messages": [{"role": "system", "content": system_msg},
                                    {"role": "user", "content": json.dumps(payload)}]}).encode()
    req = urllib.request.Request(base + "/chat/completions", data=body,
                                 headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"})
    # Log WITHOUT the Authorization header / key value:
    print(f"glm-api-adapter: live request -> {base} (model {payload['model']}; Authorization header REDACTED)", file=sys.stderr)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--task", required=True)
    ap.add_argument("--mock")
    ap.add_argument("--live", action="store_true")
    ap.add_argument("--allow-network", action="store_true")
    ap.add_argument("--out")
    a = ap.parse_args()
    task = json.load(open(a.task))

    run_context_guard(a.task)          # fail-closed BEFORE building any payload
    payload = build_payload(task)      # re-asserts no secret value in payload

    if not a.live:
        if not a.mock:
            die("default mode requires --mock <response_fixture.json> (no network). Use --live --allow-network for live.")
        resp = json.load(open(a.mock))
    else:
        # PRIMARY live-mode gates (CI check below is defense-in-depth only):
        if not a.allow_network:
            die("--live requires explicit --allow-network; refusing (no network call made)")
        if not os.environ.get("GLM_API_KEY"):
            die("--live requires GLM_API_KEY in env (no value printed); refusing (no network call made)")
        if is_ci():
            die("--live blocked: CI environment detected (defense-in-depth). Refusing automatic live call.")
        resp = live_call(payload)

    resp = normalize_response(resp)    # live choices[].message.content -> structured; mock top-level -> unchanged
    result = map_to_result(task, resp)
    if a.out:
        json.dump(result, open(a.out, "w"), indent=2); open(a.out, "a").write("\n")
        print(f"glm-api-adapter: wrote result -> {a.out}")
    else:
        print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
