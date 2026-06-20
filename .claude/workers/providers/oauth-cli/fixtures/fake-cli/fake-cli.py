#!/usr/bin/env python3
"""Deterministic LOCAL fake CLI stub for oauth-cli adapter verification (v0.2.2, C3).

This is NOT a provider and holds NO credential. It exercises DMC's own subprocess wrapper offline:
the adapter invokes it as `fake-cli.py <subcommand>` (subcommand = auth-status | run) with the sanitized
payload on stdin, exactly as it would a real OAuth CLI. Behavior is selected by env DMC_FAKECLI_MODE so a
single committed stub covers every required case. No network, no token store, no real OAuth.

Modes (DMC_FAKECLI_MODE):
  success | fenced | prose | nonzero-exit | timeout | stdout-token | stderr-token | auth-unauthenticated
"""
import json, os, sys, time

MODE = os.environ.get("DMC_FAKECLI_MODE", "success")
SUBCMD = sys.argv[1] if len(sys.argv) > 1 else ""

# A well-formed, in-scope worker result for the toy task (files_changed == diff paths == ["src/setNames.ts"]).
PATCH = ("--- a/src/setNames.ts\n+++ b/src/setNames.ts\n@@ -1,3 +1,4 @@\n"
         " export const names = [\n   \"Bulbasaur\",\n+  \"Pikachu\",\n ];\n")
RESULT_OBJ = {"summary": "Append \"Pikachu\" to the names array in src/setNames.ts.",
              "files_changed": ["src/setNames.ts"], "proposed_patch": PATCH, "confidence": "high"}

# Deliberately SECRET_VALUE-missed token shapes (JWT / Bearer / ya29) — no placeholder words in the token value.
JWT = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ0ZXN0LXVzZXIiLCJpYXQiOjE1fQ.s1GnAtUreVALue0987abcXYZ"


def auth_status():
    authed = (MODE != "auth-unauthenticated")
    sys.stdout.write(json.dumps({"authenticated": authed}))   # token-blind: only a boolean, never token material
    return 0


def run():
    if MODE == "success":
        sys.stdout.write(json.dumps(RESULT_OBJ)); return 0
    if MODE == "fenced":
        sys.stdout.write("Here is the change:\n```json\n" + json.dumps(RESULT_OBJ, indent=2) + "\n```\n"); return 0
    if MODE == "prose":
        sys.stdout.write("I would append a Pikachu entry but cannot produce a patch here."); return 0
    if MODE == "nonzero-exit":
        sys.stderr.write("simulated provider failure\n"); return 3
    if MODE == "timeout":
        time.sleep(30); sys.stdout.write(json.dumps(RESULT_OBJ)); return 0   # adapter kills before this
    if MODE == "stdout-token":
        sys.stdout.write("Authorization: Bearer " + JWT + "\n" + json.dumps(RESULT_OBJ)); return 0
    if MODE == "stderr-token":
        sys.stderr.write("debug: access_token=" + JWT + "\n")
        sys.stdout.write(json.dumps(RESULT_OBJ)); return 0
    sys.stdout.write(json.dumps(RESULT_OBJ)); return 0


def main():
    if SUBCMD == "auth-status":
        sys.exit(auth_status())
    if SUBCMD == "run":
        sys.exit(run())
    sys.stderr.write(f"fake-cli: unknown subcommand {SUBCMD!r}\n"); sys.exit(2)


if __name__ == "__main__":
    main()
