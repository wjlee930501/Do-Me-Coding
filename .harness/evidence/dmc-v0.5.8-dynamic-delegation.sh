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
# --out is FAIL-CLOSED (C7): allow ONLY a NEW (non-existing) file whose canonical parent is a benign temp/work dir OUTSIDE
# the repo. Refuse traversal, .env*/credential/key/token/protected paths, symlinks (target or parent), already-existing
# targets (no overwrite), anything in the repo tree or tracked, system paths, $HOME hidden control files (dotfile basename
# or a .ssh/.config/... control dir), and any parent NOT under an allowlisted temp root. No env var is read. 0=REFUSE,1=ALLOW.
out_refused() { local raw="$1"
  [ -z "$raw" ] && return 0
  printf '%s' "$raw" | grep -qE '(^|/)\.\.(/|$)' && return 0
  # .env-class (case-INSENSITIVE: .env/.ENV/prod.env/prod.ENV/.env.local/.ENV.LOCAL) => REFUSE, except .example/.sample/.template
  printf '%s' "$raw" | grep -qiE '\.env($|\.)' && ! printf '%s' "$raw" | grep -qiE '\.(example|sample|template)$' && return 0
  printf '%s' "$raw" | grep -qiE "$PROT_RE" && return 0
  [ -e "$raw" ] && return 0
  [ -L "$raw" ] && return 0
  local parent base cparent canon root croot ok; parent="$(dirname "$raw" 2>/dev/null)"; base="$(basename "$raw")"
  [ -L "$parent" ] && return 0
  cparent="$(cd "$parent" 2>/dev/null && pwd -P)" || return 0; canon="$cparent/$base"
  [ -e "$canon" ] && return 0
  printf '%s' "$canon" | grep -qiE "$PROT_RE" && return 0
  case "$canon/" in "$ROOTDIR"/*) return 0;; esac
  git -C "$ROOTDIR" ls-files --error-unmatch -- "$canon" >/dev/null 2>&1 && return 0
  printf '%s' "$canon" | grep -qE '^/(etc|usr|bin|sbin|System|Library|var/db|var/root|boot|dev|proc)(/|$)|^/private/etc(/|$)' && return 0
  case "$base" in .*) return 0;; esac
  printf '%s' "$canon" | grep -qE '/\.(ssh|config|gnupg|aws|kube|docker)(/|$)|/\.(gitconfig|git-credentials|netrc|npmrc|zshrc|bashrc|profile)$' && return 0
  ok=1
  for root in /tmp /private/tmp /var/folders /private/var/folders /var/tmp /private/var/tmp; do
    croot="$(cd "$root" 2>/dev/null && pwd -P)" || continue
    case "$cparent/" in "$croot"/*) ok=0; break;; esac
  done
  [ "$ok" = 0 ] || return 0
  return 1
}

handoff() { # <batch_authorized: true|false>
  local ba="$1"; local batch
  case "$ba" in 1|true|yes|on) batch="ACTIVE";; *) batch="OFF";; esac
  cat <<EOF
# DMC Dynamic Delegation Handoff — bounded-batch authorization: $batch
- advisory: this delegation handoff is a recommendation / role spec — NOT an enforcement gate and NOT a machine-readable authorization. The runtime hooks remain the enforcement; push/main/closure ALWAYS require a separate explicit human gate (an ACTIVE bounded-batch state is the human's prior grant for local steps only, never an autonomous push/main/closure grant).

## Roles (owns / must-not / outputs)
| role | owns | must NOT | outputs |
|---|---|---|---|
| Orchestrator | sequencing, scope-control, deciding next step | self-approve; push/merge/closure without a gate; expand tooling to spend context | a per-step decision + the handoff |
| Implementer | the approved-scope edits + their self-tests | edit outside approved scope; touch the protected surface; commit without green tests; read env/secrets | additive diffs + passing self-tests |
| Critic | adversarial review / falsification | author and self-approve in the same pass; grant a push/release | findings + a PASS / REVISE verdict (advisory) |
| Release Gate | the human/explicit authorization for stage→commit→push→main→closure | be satisfied by a critic PASS alone; publish without verification + review | an explicit, per-action authorization |

## Gate matrix (action : autonomy)
- plan / critic / implement-approved-scope / verify / release-audit : autonomous ONLY when batch=ACTIVE (else human-approved)
- local stage / local commit : autonomous ONLY when batch=ACTIVE and tests are green; otherwise human-gated
- review-branch push : HUMAN GATE (never autonomous)
- main publish (merge/ff to main) : HUMAN GATE (never autonomous)
- milestone closure (MILESTONES.md) : HUMAN GATE, and only AFTER publication
- live provider/model/API call / network / credential or .env read : FORBIDDEN (never, in any mode)

## Critic PASS is NOT release authorization (nor approval by itself)
A Critic / Codex ACCEPT is an ADVISORY input — approval EVIDENCE, not approval itself. The CRITIC->APPROVED flip requires an
explicit approval_authorized fact: when batch=ACTIVE the human's bounded-batch scope SUPPLIES approval_authorized for the
LOCAL approval flip only; critic PASS alone is NEVER enough to approve, and approval is never inferred from run state. A
Critic PASS NEVER grants a push, a main publication, or a closure — those authorizations come ONLY from the Release Gate (a human).

## Bounded-batch autonomy (when batch=ACTIVE)
Autonomous: write DRAFT plan → run adversarial critic → revise on REVISE → flip APPROVED only when critic=PASS AND the
bounded-batch scope supplies approval_authorized (critic PASS alone never approves) → implement approved scope → verify →
release-audit → ONE local commit per milestone after tests pass.
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
Under bounded-batch authorization (batch=ACTIVE only) you may run plan→critic→implement→verify→audit→local-commit; push, main publish, and closure are always
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
  # AC3c (HARDENING / C2) the handoff carries an OUTPUT-LEVEL advisory disclaimer (not just a # comment / critic-scoped note),
  # so a stdout-parsing orchestrator cannot read the 'authorization: ACTIVE' header + gate matrix as a machine-readable grant
  { printf '%s' "$H" | grep -qi '^- advisory:' \
    && printf '%s' "$H" | grep -qi 'NOT an enforcement gate' \
    && printf '%s' "$H" | grep -qi 'not a machine-readable authorization'; } \
    && ok "AC3c handoff output carries an advisory disclaimer (recommendation, NOT an enforcement gate / not a machine-readable authorization)" || no "AC3c no output-level advisory disclaimer"
  # AC3d (REVISE / approval-gate separation) the handoff states the CRITIC->APPROVED flip needs an explicit approval_authorized
  # fact (bounded-batch scope) and that critic PASS ALONE never approves; push/main/closure stay HUMAN GATE
  { printf '%s' "$H" | grep -q 'approval_authorized' \
    && printf '%s' "$H" | grep -Eiq 'critic PASS alone is NEVER enough|critic PASS alone never approves' \
    && printf '%s' "$H" | grep -q 'review-branch push : HUMAN GATE'; } \
    && ok "AC3d approval-gate separation: handoff requires approval_authorized for CRITIC->APPROVED; critic PASS alone never approves; push/main/closure stay HUMAN GATE" || no "AC3d approval-separation wording missing"
  # AC4 forbidden list completeness
  { printf '%s' "$H" | grep -qi 'self-approval' && printf '%s' "$H" | grep -qi 'push or main publication without' \
    && printf '%s' "$H" | grep -qi 'closure before publication' && printf '%s' "$H" | grep -qi 'reading .env' \
    && printf '%s' "$H" | grep -qi 'token-max'; } \
    && ok "AC4 forbidden: self-approval / ungated push-main / closure-before-publish / secret-env read / token-max" || no "AC4 forbidden incomplete"
  # AC5 bounded-batch autonomy encoded; local commit gated on batch ACTIVE
  { printf '%s' "$H" | grep -q 'Bounded-batch autonomy' && printf '%s' "$H" | grep -q 'ONE local commit per milestone after tests pass' \
    && printf '%s' "$H" | grep -q 'local commit : autonomous ONLY when batch=ACTIVE'; } \
    && ok "AC5 bounded-batch autonomy encoded; local stage/commit gated on batch ACTIVE + green tests" || no "AC5 batch autonomy"
  # AC5b batch=OFF reflected in the HEADER, and the gate line is a FIXED literal (autonomy ONLY when ACTIVE) —
  # NOT the inverted "autonomous when batch=OFF" (which would imply autonomy when the batch is OFF).
  { local HO; HO="$(handoff false)"
    printf '%s' "$HO" | grep -q 'bounded-batch authorization: OFF' \
    && printf '%s' "$HO" | grep -q 'autonomous ONLY when batch=ACTIVE' \
    && ! printf '%s' "$HO" | grep -qi 'autonomous when batch=OFF'; } \
    && ok "AC5b batch=OFF: header reflects OFF, gate line fixed to 'autonomous ONLY when batch=ACTIVE' (not inverted)" || no "AC5b batch off (inverted/absent)"
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
  # AC12 (HARDENING / Codex) the dispatch tail is fail-CLOSED: it CAPTURES handoff into a verified var with an explicit
  # refusal guard (no bare terminal 'handoff "$BA"' that would exit 0 with empty output = false DONE). Scan only the
  # dispatch region (post-self_test) so the assertion does not match its own pattern text.
  local TAIL; TAIL="$(awk '/^BA=false;/{f=1} f' "$SELFPATH")"
  { printf '%s' "$TAIL" | grep -q 'H="\$(handoff "\$BA")"' \
    && printf '%s' "$TAIL" | grep -q 'refusing to report success' \
    && ! printf '%s' "$TAIL" | grep -qE '^[[:space:]]*handoff "\$BA"([[:space:]]|;|$)'; } \
    && ok "AC12 dispatch fail-closed: captures+verifies handoff with a refusal guard; no bare terminal handoff (no exit-0-on-empty)" || no "AC12 exit-0 fail-open present"
  # AC12b a normal run binds exit 0 to a complete, header-bearing handoff on stdout
  local mo mrc; mo="$(bash "$SELFPATH" --batch-authorized true)"; mrc=$?
  { [ "$mrc" = 0 ] && printf '%s' "$mo" | grep -q '^# DMC Dynamic Delegation Handoff'; } \
    && ok "AC12b normal run: exit 0 only with a complete header-bearing handoff on stdout" || no "AC12b exit not bound to artifact (rc=$mrc)"

  # AC13 (HARDENING / C7) --out is FAIL-CLOSED: allow ONLY a NEW file in a benign temp/work dir OUTSIDE the repo
  local C7D="$TT/c7out"; mkdir -p "$C7D"
  local c7_new="$C7D/ho_new.md" c7_exist="$C7D/ho_exist.md"; : > "$c7_exist"
  ln -s "$c7_new" "$C7D/ho_link.md" 2>/dev/null
  local r_new r_exist r_home r_etc r_intree r_sym r_trav r_dot
  out_refused "$c7_new"; r_new=$?
  out_refused "$c7_exist"; r_exist=$?
  out_refused "${HOME:-/root}/.dmc_c7_sentinel.md"; r_home=$?
  out_refused "/etc/passwd"; r_etc=$?
  out_refused "$ROOTDIR/docs/c7_intree.md"; r_intree=$?
  out_refused "$C7D/ho_link.md"; r_sym=$?
  out_refused "$C7D/../c7out/../x.md"; r_trav=$?
  out_refused "$C7D/.hidden.md"; r_dot=$?
  { [ "$r_new" = 1 ] && [ "$r_exist" = 0 ] && [ "$r_home" = 0 ] && [ "$r_etc" = 0 ] && [ "$r_intree" = 0 ] && [ "$r_sym" = 0 ] && [ "$r_trav" = 0 ] && [ "$r_dot" = 0 ]; } \
    && ok "AC13 C7 --out guard: NEW temp file ALLOWED; existing/home-dotfile/etc-passwd/in-tree/symlink/traversal/dotfile REFUSED" \
    || no "AC13 C7 guard (new=$r_new exist=$r_exist home=$r_home etc=$r_etc intree=$r_intree sym=$r_sym trav=$r_trav dot=$r_dot)"
  # AC13b end-to-end: --out NEW temp path WRITES (exit 0); --out /etc/passwd REFUSED (exit 2, no OS write)
  local c7_e2e="$C7D/e2e.md" rc_e2e rc_etc
  bash "$SELFPATH" --batch-authorized true --out "$c7_e2e" >/dev/null 2>&1; rc_e2e=$?
  bash "$SELFPATH" --batch-authorized true --out /etc/passwd >/dev/null 2>&1; rc_etc=$?
  { [ "$rc_e2e" = 0 ] && [ -s "$c7_e2e" ] && [ "$rc_etc" = 2 ]; } \
    && ok "AC13b C7 end-to-end: --out new temp path writes (exit 0); --out /etc/passwd REFUSED by guard (exit 2)" \
    || no "AC13b C7 e2e (rc_e2e=$rc_e2e wrote=$([ -s "$c7_e2e" ] && echo y || echo n) etc=$rc_etc)"

  # AC14 (C7 / case-insensitive .env) uppercase/mixed-case .env-class --out paths are refused exactly like lowercase
  local re_up re_lo re_lc re_mix
  out_refused "$C7D/prod.ENV"; re_up=$?
  out_refused "$C7D/.ENV.LOCAL"; re_lo=$?
  out_refused "$C7D/prod.env"; re_lc=$?
  out_refused "$C7D/foo.Env.local"; re_mix=$?
  { [ "$re_up" = 0 ] && [ "$re_lo" = 0 ] && [ "$re_lc" = 0 ] && [ "$re_mix" = 0 ]; } \
    && ok "AC14 C7 .env-class refused case-insensitively (prod.ENV / .ENV.LOCAL / prod.env / foo.Env.local all REFUSED)" || no "AC14 .env case bypass (ENV=$re_up LOCAL=$re_lo env=$re_lc mix=$re_mix)"

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
# fail CLOSED: the handoff artifact IS the deliverable — NEVER exit 0 without a complete, header-bearing handoff (Codex)
H="$(handoff "$BA")" || { echo "dynamic-delegation: handoff generation FAILED — refusing to report success" >&2; exit 1; }
printf '%s' "$H" | grep -q '^# DMC Dynamic Delegation Handoff' || { echo "dynamic-delegation: handoff incomplete/empty — refusing to report success" >&2; exit 1; }
if [ -n "$OUT" ]; then
  out_refused "$OUT" && { echo "dynamic-delegation: --out REFUSED — must be a NEW file in a temp/work dir outside the repo (not in-tree/tracked/secret/system/home-dotfile/existing)" >&2; exit 2; }
  printf '%s\n' "$H" > "$OUT" || { echo "dynamic-delegation: failed to write $OUT" >&2; exit 1; }
  echo "dynamic-delegation: wrote $OUT" >&2; exit 0
fi
printf '%s\n' "$H"; exit 0
