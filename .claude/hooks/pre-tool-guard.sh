#!/usr/bin/env bash
set -u
INPUT="$(cat)"

# Do-Me-Coding mode gate (v0.1.1): active | passive | off. Absent => active (backward compatible).
DMC_MODE_FILE="${CLAUDE_PROJECT_DIR:-$PWD}/.harness/mode"
DMC_MODE="active"
if [ -f "$DMC_MODE_FILE" ]; then
  DMC_MODE="$(head -n1 "$DMC_MODE_FILE" | tr -d '[:space:]' | tr 'A-Z' 'a-z')"
  case "$DMC_MODE" in active|passive|off) ;; *) DMC_MODE="active" ;; esac
fi

json_get() {
  key="$1"
  if command -v python3 >/dev/null 2>&1; then
    DMC_HOOK_INPUT="$INPUT" python3 - "$key" <<'PY' 2>/dev/null || true
import json, os, sys
key = sys.argv[1]
try:
    data = json.loads(os.environ.get("DMC_HOOK_INPUT", ""))
    cur = data
    for part in key.split("."):
        cur = cur.get(part, "") if isinstance(cur, dict) else ""
    if cur is None:
        cur = ""
    if isinstance(cur, (dict, list)):
        print(json.dumps(cur, ensure_ascii=False))
    else:
        print(str(cur))
except Exception:
    pass
PY
  elif command -v jq >/dev/null 2>&1; then
    printf '%s' "$INPUT" | jq -r ".$key // empty" 2>/dev/null || true
  fi
}

json_string() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
  elif command -v jq >/dev/null 2>&1; then
    jq -Rs .
  else
    sed 's/"/\\"/g; s/^/"/; s/$/"/'
  fi
}


COMMAND="$(json_get 'tool_input.command')"
[ -n "$COMMAND" ] || exit 0

deny() {
  reason="$1"
  reason_json="$(printf '%s' "$reason" | json_string)"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}\n' "$reason_json"
  exit 0
}

ask() {
  reason="$1"
  reason_json="$(printf '%s' "$reason" | json_string)"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":%s}}\n' "$reason_json"
  exit 0
}

CMD_ONE_LINE="$(printf '%s' "$COMMAND" | tr '\n' ' ' | sed 's/[[:space:]][[:space:]]*/ /g')"

if printf '%s' "$CMD_ONE_LINE" | grep -Eiq '(^|[;&|`$()[:space:]])rm[[:space:]]+-rf[[:space:]]+(/|\.|\*|~|/\*)'; then
  deny "Do-Me-Coding blocked destructive rm -rf command. Narrow the target and get explicit approval."
fi

# Block A — catastrophic destructive (enforced in ALL modes: active, passive, off)
if printf '%s' "$CMD_ONE_LINE" | grep -Eiq 'sudo[[:space:]]+rm[[:space:]]+-rf|git[[:space:]]+push[[:space:]].*--force|prisma[[:space:]]+migrate[[:space:]]+reset|rails[[:space:]]+db:drop|python[[:space:]]+manage\.py[[:space:]]+flush|kubectl[[:space:]]+delete|terraform[[:space:]]+destroy'; then
  deny "Do-Me-Coding blocked a high-risk destructive command. Create an approved plan and request explicit human approval."
fi

# Block A — secret exposure (treated as catastrophic; enforced in ALL modes including off).
# `printenv` dumps the whole environment, so it needs no operand. For file-reading / exfil verbs we
# require an actual SECRET OPERAND to appear in the command; ordinary reads with a read-verb but no
# secret operand (grep foo src/x.py, cp a.txt b.txt, head README.md, sed -i.bak s/a/b/ build.log)
# are NOT blocked. The .env.example / .env.sample / .env.template scaffolding files are NOT secrets.
if printf '%s' "$CMD_ONE_LINE" | grep -Eiq '(^|[;&|[:space:]])printenv([^A-Za-z0-9_-]|$)'; then
  deny "Do-Me-Coding blocked a command that may expose secrets. Use targeted, redacted inspection instead."
fi
PTG_SECRET_VERB='(^|[;&|[:space:]])(cat|head|tail|less|more|xxd|od|strings|base64|nl|sort|uniq|awk|sed|grep|rg|cp|install|dd|tee)[[:space:]]'
# Entry operand set: any bare .env, any dotted .env.* (incl. the allow-scaffolding — exempted below),
# or an ssh/aws/pem/key/private-key file token.
PTG_SECRET_OPERAND='(\.env([^A-Za-z0-9._-]|$)|\.env\.|\.ssh|\.aws|\.pem|\.key|id_rsa|id_ed25519)'
# "Other than an allowed .env.example" operand set — a bare .env (not a dotted suffix) or ssh/aws/pem/key.
PTG_SECRET_NONENV='(\.env([^A-Za-z0-9._-]|$)|\.ssh|\.aws|\.pem|\.key|id_rsa|id_ed25519)'
PTG_ENV_ALLOW='\.env\.(example|sample|template)([^A-Za-z0-9._-]|$)'
if printf '%s' "$CMD_ONE_LINE" | grep -Eiq "$PTG_SECRET_VERB" \
   && printf '%s' "$CMD_ONE_LINE" | grep -Eiq "$PTG_SECRET_OPERAND"; then
  # Exempt ONLY when the sole secret operand is an allowed .env.example/.sample/.template file and no
  # other secret operand (bare .env / .ssh / .aws / .pem / .key / id_rsa / id_ed25519) is present.
  if printf '%s' "$CMD_ONE_LINE" | grep -Eiq "$PTG_ENV_ALLOW" \
     && ! printf '%s' "$CMD_ONE_LINE" | grep -Eiq "$PTG_SECRET_NONENV"; then
    :
  else
    deny "Do-Me-Coding blocked a command that may expose secrets. Use targeted, redacted inspection instead."
  fi
fi

# Block A — catastrophic database (enforced in ALL modes)
if printf '%s' "$CMD_ONE_LINE" | grep -Eiq '(DROP[[:space:]]+DATABASE|TRUNCATE[[:space:]]+TABLE)'; then
  deny "Do-Me-Coding blocked a catastrophic database command. Require explicit approval and rollback plan."
fi

# Block A — external-proposal no-mutation floor: `git apply` / `patch` forms (enforced in ALL modes).
# An externally-proposed diff is a review artifact, never an executable patch (CLAUDE.md). This is an
# L0 STATIC floor: it fires inline without any Ring-0 lookup, so it still holds under a synthetic
# CLAUDE_PROJECT_DIR that has no bin/dmc. Both patterns are command-position anchored (start, after
# ; & | `, or after sudo/env VAR=val) so a quoted argument mentioning "git apply"/"patch" — e.g. a
# commit message — is NOT a false positive. The armed L1 classifier (dmc bash-radius) re-checks this
# token-aware; this inline grep is the always-on backstop.
if printf '%s' "$CMD_ONE_LINE" | grep -Eiq '(^|[;&|`]|sudo[[:space:]]+|env[[:space:]]+([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*)[[:space:]]*git[[:space:]]+(-[^[:space:]]+[[:space:]]+([^-][^[:space:]]*[[:space:]]+)?)*apply([^A-Za-z0-9_-]|$)'; then
  deny "Do-Me-Coding blocked 'git apply': a worker diff is a review artifact, not an executable patch. Translate an accepted proposal into scope-guarded Edit/Write under a run scope, then verify."
fi
if printf '%s' "$CMD_ONE_LINE" | grep -Eiq '(^|[;&|`]|sudo[[:space:]]+)[[:space:]]*patch([^A-Za-z0-9_-]|$)'; then
  deny "Do-Me-Coding blocked a 'patch' application form. Worker diffs are review artifacts; apply accepted changes via scope-guarded Edit/Write, never patch."
fi

# Block B — full deny tier (enforced in active and passive; stands down in off)
if [ "$DMC_MODE" != "off" ]; then
  if printf '%s' "$CMD_ONE_LINE" | grep -Eiq 'git[[:space:]]+reset[[:space:]]+--hard|(DELETE[[:space:]]+FROM)'; then
    deny "Do-Me-Coding blocked a destructive command (use /dmc-off only when intentionally stepping aside). Require explicit approval."
  fi
fi

# Block C — ask tier (active mode only; less intrusive in passive/off)
if [ "$DMC_MODE" = "active" ]; then
  if printf '%s' "$CMD_ONE_LINE" | grep -Eiq '(npm|pnpm|yarn|bun)[[:space:]]+publish|npm[[:space:]]+audit[[:space:]]+fix[[:space:]]+--force|schema[[:space:]]+push|migrate[[:space:]]+(deploy|dev|reset)|npm[[:space:]]+install|pnpm[[:space:]]+install|yarn[[:space:]]+install|bun[[:space:]]+install'; then
    ask "Do-Me-Coding detected a package, migration, publish, or schema-changing command. Confirm this is intended."
  fi
fi

# Block D — L1 dynamic Bash write-radius (armed run + active mode only; Ring-0 owns the verdict).
# ARMED := current-run-id present AND that run dir carries an immutable scope.lock.json. The verdict
# comes from `dmc bash-radius` (exit 0 allow / 3 ask / 4 deny); this shim only translates it into the
# host envelope. Fail-closed: armed+active but the Ring-0 CLI (bin/dmc + python3) is unreachable =>
# deny with an actionable reason. Unarmed (no run-id file, or no scope.lock.json — the repo's normal
# state and this M6 build's own run) => stands down; the L0 floors above already fired for
# catastrophic/secret/git-apply. A synthetic CLAUDE_PROJECT_DIR with no run-id file never reaches here.
PTG_PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
PTG_RUN_ID_FILE="$PTG_PROJECT_DIR/.harness/runs/current-run-id"
if [ "$DMC_MODE" = "active" ] && [ -f "$PTG_RUN_ID_FILE" ]; then
  PTG_RUN_ID="$(head -n 1 "$PTG_RUN_ID_FILE" | tr -cd 'A-Za-z0-9._-')"
  PTG_SCOPE_LOCK="$PTG_PROJECT_DIR/.harness/runs/$PTG_RUN_ID/scope.lock.json"
  if [ -n "$PTG_RUN_ID" ] && [ -f "$PTG_SCOPE_LOCK" ]; then
    PTG_DMC=""
    for _cand in "$PTG_PROJECT_DIR/bin/dmc" "$(cd "$(dirname "$0")/../.." 2>/dev/null && pwd)/bin/dmc"; do
      [ -n "$_cand" ] && [ -x "$_cand" ] && { PTG_DMC="$_cand"; break; }
    done
    if [ -z "$PTG_DMC" ] || ! command -v python3 >/dev/null 2>&1; then
      deny "Do-Me-Coding fail-closed: run '$PTG_RUN_ID' is armed (scope.lock.json present) but the Ring-0 write-radius CLI (bin/dmc + python3) is unavailable, so this Bash command cannot be adjudicated. Restore bin/dmc/python3 or suspend the run (dmc run suspend)."
    fi
    PTG_OUT="$("$PTG_DMC" bash-radius --cmd "$COMMAND" --scope-lock "$PTG_SCOPE_LOCK" 2>/dev/null)"
    PTG_RC=$?
    PTG_REASON="$(printf '%s' "$PTG_OUT" | sed -n 's/.*"reason":"\([^"]*\)".*/\1/p')"
    [ -n "$PTG_REASON" ] || PTG_REASON="Bash write-radius adjudication (run '$PTG_RUN_ID')"
    case "$PTG_RC" in
      0) : ;;
      3) ask "Do-Me-Coding write-radius asks confirmation: $PTG_REASON" ;;
      4) deny "Do-Me-Coding blocked an out-of-scope or disallowed Bash write: $PTG_REASON" ;;
      *) deny "Do-Me-Coding fail-closed: Bash write-radius classifier returned status $PTG_RC. $PTG_REASON" ;;
    esac
  fi
fi

exit 0
