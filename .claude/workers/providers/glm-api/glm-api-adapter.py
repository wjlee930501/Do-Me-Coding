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
    body = json.dumps({"model": payload["model"],
                       "messages": [{"role": "user", "content": json.dumps(payload)}]}).encode()
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

    result = map_to_result(task, resp)
    if a.out:
        json.dump(result, open(a.out, "w"), indent=2); open(a.out, "a").write("\n")
        print(f"glm-api-adapter: wrote result -> {a.out}")
    else:
        print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
