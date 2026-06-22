#!/usr/bin/env bash
# DMC Dynamic Delegation Harness (v0.5.8) — ADVISORY / docs-artifact generator, deterministic, inert unless invoked.
#
# Emits a delegation HANDOFF that tells Opus/Opus exactly what each role may do under semi-autonomous work: the four roles
# (Orchestrator / Implementer / Critic / Release Gate) with owns / must-not / outputs, a gate matrix that SEPARATES
# "critic PASS" from release authorization, the bounded-batch autonomy, an explicit forbidden list, and a compact handoff
# prompt. Reads no env/.env/secret; no network/live call. The content is original DMC role text — no leaked/proprietary
# prompt text. Output is the declared docs artifact (its entire purpose).
#
# Usage: dmc-v0.5.8-dynamic-delegation.sh [--batch-authorized true|false] [--out <file>]  |  --self-test
# Exit: 0 = handoff emitted, 2 = usage/refused.
set -u
set -o pipefail
export PYTHONDONTWRITEBYTECODE=1
SELFPATH="$(cd "$(dirname "$0")" 2>/dev/null && pwd -P)/$(basename "$0")"
ROOTDIR="$(cd "$(dirname "$SELFPATH")/../.." 2>/dev/null && pwd -P || true)"
[ -n "$ROOTDIR" ] || ROOTDIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
repo_hash() { git -C "$ROOTDIR" status --porcelain 2>/dev/null | python3 -c 'import hashlib,sys; sys.stdout.write(hashlib.sha256(sys.stdin.buffer.read()).hexdigest())'; }

PROT_RE='(^|/)(\.env)(\.|$)|\.pem$|\.key$|id_rsa|id_ed25519|credentials|secret|\.p12$|\.pfx$|\.keystore$|\.claude/hooks|provider-router\.py'
out_refused() { local raw="$1"
  printf '%s' "$raw" | grep -qE '(^|/)\.\.(/|$)' && return 0
  case "$raw" in *.env|*.env.local|*.env.*) case "$raw" in *.example|*.sample|*.template) ;; *) return 0;; esac;; esac
  printf '%s' "$raw" | grep -qiE "$PROT_RE" && return 0
  [ -L "$raw" ] && return 0
  local parent base cparent canon; parent="$(dirname "$raw" 2>/dev/null)"; base="$(basename "$raw")"
  cparent="$(cd "$parent" 2>/dev/null && pwd -P)" || return 0; canon="$cparent/$base"
  printf '%s' "$canon" | grep -qiE "$PROT_RE" && return 0
  case "$canon/" in "$ROOTDIR"/*) return 0;; esac
  git -C "$ROOTDIR" ls-files --error-unmatch -- "$canon" >/dev/null 2>&1 && return 0
  return 1
}

handoff() { # <batch_authorized: true|false>
  local ba="$1"; local batch
  case "$ba" in 1|true|yes|on) batch="ACTIVE";; *) batch="OFF";; esac
  cat <<EOF
# DMC Dynamic Delegation Handoff — bounded-batch authorization: $batch

## Roles (owns / must-not / outputs)
| role | owns | must NOT | outputs |
|---|---|---|---|
| Orchestrator | sequencing, scope-control, deciding next step | self-approve; push/merge/closure without a gate; expand tooling to spend context | a per-step decision + the handoff |
| Implementer | the approved-scope edits + their self-tests | edit outside approved scope; touch the protected surface; commit without green tests; read env/secrets | additive diffs + passing self-tests |
| Critic | adversarial review / falsification | author and self-approve in the same pass; grant a push/release | findings + a PASS / REVISE verdict (advisory) |
| Release Gate | the human/explicit authorization for stage→commit→push→main→closure | be satisfied by a critic PASS alone; publish without verification + review | an explicit, per-action authorization |

## Gate matrix (action : autonomy)
- plan / critic / implement-approved-scope / verify / release-audit : autonomous when batch=$batch (else human-approved)
- local stage / local commit : autonomous ONLY when batch=ACTIVE and tests are green; otherwise human-gated
- review-branch push : HUMAN GATE (never autonomous)
- main publish (merge/ff to main) : HUMAN GATE (never autonomous)
- milestone closure (MILESTONES.md) : HUMAN GATE, and only AFTER publication
- live provider/model/API call / network / credential or .env read : FORBIDDEN (never, in any mode)

## Critic PASS is NOT release authorization
A Critic / Codex ACCEPT is an ADVISORY input. It authorizes only the next step the bounded batch already authorizes — it
NEVER grants a push, a main publication, or a closure. Authorization for those comes ONLY from the Release Gate (a human).

## Bounded-batch autonomy (when batch=ACTIVE)
Autonomous: write DRAFT plan → run adversarial critic → revise on REVISE → flip APPROVED only after critic PASS with no
required blockers → implement approved scope → verify → release-audit → ONE local commit per milestone after tests pass.
Always-gated regardless of batch: push, main merge, closure, live/network/secret.

## Forbidden (every mode)
- self-approval (author == approver in the same active pass)
- push or main publication without an explicit human gate
- recording closure before publication
- reading .env / credentials / tokens / secrets, or making a live/network/model call
- expanding tools / context just to spend more tokens (token-max disguised as rigor)
- copying leaked / proprietary prompt text

## Compact handoff prompt
"You are one of {Orchestrator, Implementer, Critic, Release Gate}. Act ONLY within your role's owns/must-not above. Keep
work additive and the protected surface byte-unchanged. A Critic PASS is advisory and never authorizes push/main/closure.
Under batch=$batch you may run plan→critic→implement→verify→audit→local-commit; push, main publish, and closure are always
a separate human gate. Never read .env/secrets, never make a live/network call, never self-approve, never expand scope to
spend context. Stop and surface to the human at any gate."
EOF
}

self_test() {
  local P=0 F=0; ok(){ echo "  PASS $1"; P=$((P+1)); }; no(){ echo "  FAIL $1"; F=$((F+1)); }
  local TT; TT="$(mktemp -d)" || { echo "  FATAL: mktemp -d failed"; return 2; }; [ -d "$TT" ] || { echo "  FATAL: temp dir missing"; return 2; }; trap 'rm -rf "$TT"' RETURN
  local PRE; PRE="$(repo_hash)"
  local H; H="$(handoff true)"

  # AC1 all four roles present
  { printf '%s' "$H" | grep -q 'Orchestrator' && printf '%s' "$H" | grep -q 'Implementer' \
    && printf '%s' "$H" | grep -q 'Critic' && printf '%s' "$H" | grep -q 'Release Gate'; } \
    && ok "AC1 handoff includes all four roles (Orchestrator/Implementer/Critic/Release Gate)" || no "AC1 roles missing"
  # AC2 push/main/closure are HUMAN GATE even with batch=ACTIVE
  { printf '%s' "$H" | grep -q 'review-branch push : HUMAN GATE' && printf '%s' "$H" | grep -q 'main publish.*HUMAN GATE' \
    && printf '%s' "$H" | grep -q 'milestone closure.*HUMAN GATE'; } \
    && ok "AC2 push/main/closure are HUMAN GATE (never autonomous, even with batch ACTIVE)" || no "AC2 gate matrix"
  # AC3 critic PASS != release authorization (explicit)
  printf '%s' "$H" | grep -q 'Critic PASS is NOT release authorization' \
    && ok "AC3 critic/Codex ACCEPT is advisory, never a push grant" || no "AC3 critic-as-grant"
  # AC4 forbidden list completeness
  { printf '%s' "$H" | grep -qi 'self-approval' && printf '%s' "$H" | grep -qi 'push or main publication without' \
    && printf '%s' "$H" | grep -qi 'closure before publication' && printf '%s' "$H" | grep -qi 'reading .env' \
    && printf '%s' "$H" | grep -qi 'token-max'; } \
    && ok "AC4 forbidden: self-approval / ungated push-main / closure-before-publish / secret-env read / token-max" || no "AC4 forbidden incomplete"
  # AC5 bounded-batch autonomy encoded; local commit gated on batch ACTIVE
  { printf '%s' "$H" | grep -q 'Bounded-batch autonomy' && printf '%s' "$H" | grep -q 'ONE local commit per milestone after tests pass' \
    && printf '%s' "$H" | grep -q 'local commit : autonomous ONLY when batch=ACTIVE'; } \
    && ok "AC5 bounded-batch autonomy encoded; local stage/commit gated on batch ACTIVE + green tests" || no "AC5 batch autonomy"
  # AC5b batch=OFF reflected in the gate-matrix line (autonomy depends on batch)
  printf '%s' "$(handoff false)" | grep -q 'autonomous when batch=OFF' \
    && ok "AC5b batch=OFF reflected (autonomy depends on the bounded authorization)" || no "AC5b batch off"
  # AC6 compact handoff prompt present
  printf '%s' "$H" | grep -q 'Compact handoff prompt' \
    && ok "AC6 compact handoff prompt present" || no "AC6 no prompt"
  # AC7 no secret-shaped text / no obvious leaked-prompt markers in output
  { ! printf '%s' "$H" | grep -qiE 'sk-[A-Za-z0-9]{16,}|ghp_[A-Za-z0-9]{16,}|AKIA[0-9A-Z]{12,}|BEGIN [A-Z ]*PRIVATE KEY|password\s*[=:]\s*\S' \
    && ! printf '%s' "$H" | grep -qi 'system prompt leak'; } \
    && ok "AC7 no secret-shaped text / no leaked-prompt markers in the handoff" || no "AC7 leak-shaped text present"
  # AC8 deterministic + env-independent
  local b1; b1="$(handoff true)"
  [ "$(handoff true)" = "$b1" ] && local det=1 || local det=0
  local envi; envi="$(env -i PATH="$PATH" HOME="${HOME:-/tmp}" bash "$SELFPATH" --batch-authorized true 2>/dev/null)"
  local diff_ok=1 v; for v in GLM_API_KEY ANTHROPIC_API_KEY DMC_DELEGATE; do [ "$(env "$v=x" bash "$SELFPATH" --batch-authorized true 2>/dev/null)" = "$b1" ] || diff_ok=0; done
  { [ "$det" = 1 ] && [ "$envi" = "$b1" ] && [ "$diff_ok" = 1 ]; } && ok "AC8 deterministic + env-independent" || no "AC8 env-dependent"
  # AC9 structural audit
  local OP; OP="$(sed '/AUDIT_BLOCK_START/,/AUDIT_BLOCK_END/d' "$SELFPATH" | grep -vE '^[[:space:]]*#')"
  # >>>AUDIT_BLOCK_START
  ! printf '%s' "$OP" | grep -nE '(^|[^A-Za-z])(curl|wget)([[:space:]])| --allow-network|os\.environ|getenv|printenv|HASH_CMD|\$\{DMC_' >/dev/null \
    && ok "AC9 no net/env-read/env-hash in operative source" || no "AC9 net/env present"
  # >>>AUDIT_BLOCK_END
  # AC10 env-hash injection
  # >>>AUDIT_BLOCK_START  (hostile-input test; excluded from the operative-source audit)
  local SENT="$TT/sentinel" FAKE="$TT/fakehash"; printf '#!/bin/sh\ntouch "%s"\necho PWNED\n' "$SENT" > "$FAKE"; chmod +x "$FAKE"
  local hb hh; hb="$(repo_hash)"; hh="$(DMC_HASH_CMD="$FAKE" repo_hash)"
  { [ ! -e "$SENT" ] && [ -n "$hb" ] && [ "$hb" = "$hh" ]; } && ok "AC10 env-hash injection: hostile DMC_HASH_CMD never read/executed" || no "AC10 env-controlled hash executed"
  # >>>AUDIT_BLOCK_END
  # AC11 read-only
  { [ -n "$PRE" ] && [ "$(repo_hash)" = "$PRE" ]; } && ok "AC11 read-only: repo byte-unchanged (deterministic sha256)" || no "AC11 repo changed"

  echo "  ---- self-test: PASS=$P FAIL=$F ----"; [ "$F" = 0 ]
}

BA=false; OUT=""; RUN=run
while [ $# -gt 0 ]; do case "$1" in
  --batch-authorized) BA="$2"; shift 2;; --out) OUT="$2"; shift 2;; --self-test) RUN=selftest; shift;;
  -h|--help) sed -n '2,11p' "$0"; exit 0;; *) echo "dynamic-delegation: unknown arg $1" >&2; exit 2;;
esac; done
if [ "$RUN" = selftest ]; then echo "==== DMC DYNAMIC DELEGATION — SELF-TEST ===="; self_test; exit $?; fi
if [ -n "$OUT" ]; then out_refused "$OUT" && { echo "dynamic-delegation: --out protected/secret/in-work-tree — REFUSED" >&2; exit 2; }; handoff "$BA" > "$OUT"; echo "dynamic-delegation: wrote $OUT" >&2; exit 0; fi
handoff "$BA"; exit 0
