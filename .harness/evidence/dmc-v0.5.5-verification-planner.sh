#!/usr/bin/env bash
# DMC Verification Planner (v0.5.5) — ADVISORY / READ-ONLY, deterministic, inert unless invoked.
#
# Given changed-path categories + workflow lane, recommends the MINIMAL SUFFICIENT verification set (required / optional /
# forbidden checks + reason). Converts "run everything" into "run enough, escalate when risk demands it." Required checks
# ACCUMULATE (union) and are fail-CLOSED: an unparseable / unknown path escalates to the maximal verification set (never a
# silent skip). Protected paths (or a protected_surface flag) add protected-path byte-unchanged checks; text-bearing
# artifacts add leak scans; guards/importers/classifiers add reject-path tests. Reads no env/.env/secret; no network/live
# call. Advisory only — this is a recommendation, not an enforcement gate.
#
# Usage: dmc-v0.5.5-verification-planner.sh --changed-paths p[,p..] [--lane <lane>] [--protected-surface b]
#          [--prior-findings N] [--test-failures N] [--out <file>]  |  --from <facts.json>  |  --self-test
# Exit: 0 = plan emitted, 2 = usage/refused.
set -u
set -o pipefail
export PYTHONDONTWRITEBYTECODE=1
SELFPATH="$(cd "$(dirname "$0")" 2>/dev/null && pwd -P)/$(basename "$0")"
ROOTDIR="$(cd "$(dirname "$SELFPATH")/../.." 2>/dev/null && pwd -P || true)"
[ -n "$ROOTDIR" ] || ROOTDIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
# deterministic internal worktree-status hash — reads NO env var and executes NO env-controlled command (python hashlib)
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

plan() { # <facts.json>
  python3 - "$1" <<'PY'
import json,sys,re
try:
    F=json.load(open(sys.argv[1]))
    if not isinstance(F,dict): raise ValueError
except Exception:
    print("verification-planner: invalid facts JSON", file=sys.stderr); sys.exit(2)
def num(v):
    try: return max(0,int(v))
    except Exception:
        try: return max(0,int(float(v)))
        except Exception: return None
# value-blind by construction: this tool emits only CATEGORY labels and check names — it NEVER echoes a raw caller path
LANES_SET={"docs-only","additive-tooling","release-closure","recovery-resume","protected-surface","secret-network-live-risk"}
SECRET=re.compile(r'(^|/)\.env($|\.)|\.pem$|\.key$|id_rsa|id_ed25519|(^|/)credentials|\.aws/credentials|/\.ssh/',re.I)
PROVIDER=re.compile(r'\.claude/workers/providers/|provider-router\.py|(^|/)ROUTING\.md$|PROVIDER_CONTRACT\.md|import',re.I)
GUARD=re.compile(r'\.claude/hooks/|(secret-guard|pre-tool-guard|scope-guard|stop-verify-gate)|guard|classifier|validator|importer',re.I)
SCHEMA=re.compile(r'\.harness/schemas/.*\.schema\.md$|WORKER_(TASK|RESULT|REVIEW)_SCHEMA\.md',re.I)
SMOKE=re.compile(r'(^|/)dmc-glm-smoke$',re.I)
SHELL=re.compile(r'\.harness/evidence/.*\.sh$|\.sh$',re.I)
ARTIFACT=re.compile(r'\.harness/(evidence|verification|runs|review)/.*\.md$|review.*packet|metrics',re.I)
DOCS=re.compile(r'(^|/)docs/.*\.md$|(^|/)[A-Z0-9_]+\.md$|\.md$',re.I)

raw=str(F.get("changed_paths","")); paths=[p.strip() for p in raw.split(",") if p.strip()]
lane=str(F.get("lane","")).strip().lower()
prot_flag=str(F.get("protected_surface","")).strip().lower() not in ("0","false","no","n","none","off","")
findings=num(F.get("prior_findings",0)); failures=num(F.get("test_failures",0))

req=set(); opt=set(); forb=set(); reasons=[]; fail_closed=False
# forbidden checks are ALWAYS present (safety invariants)
forb.update(["read/print .env or any credential file","make a live provider/network call to 'verify'",
             "print raw provider payloads or user content","auto-apply any reviewer/critic output"])
# a malformed/empty path list with no other signal => fail CLOSED to the maximal set
if raw and not paths:
    fail_closed=True; reasons.append("changed_paths present but unparseable => fail-closed maximal verification set")
if not raw and not prot_flag and not lane:
    fail_closed=True; reasons.append("no changed_paths / lane / protected flag => fail-closed maximal verification set")

cats=set()
for p in paths:
    if SECRET.search(p): cats.add("secret"); req.add("REFUSE: a secret file must not be in the changeset — verify by halting, never by reading it")
    elif SMOKE.search(p) or PROVIDER.search(p): cats.add("provider")
    elif SCHEMA.search(p): cats.add("schema")
    elif GUARD.search(p): cats.add("guard")
    elif SHELL.search(p): cats.add("shell")
    elif ARTIFACT.search(p): cats.add("artifact")
    elif DOCS.search(p): cats.add("docs")
    else: cats.add("unknown"); fail_closed=True
# value-blind: one CATEGORY reason per category present — NO caller path is ever echoed
CATMSG={"secret":"a secret-bearing changed path is present => refuse/halt (do not read)",
        "provider":"a provider/import/router path is present (protected)","schema":"a schema is present (protected)",
        "guard":"a guard/hook/validator/classifier/importer path is present (protected)","shell":"a shell tool path is present",
        "artifact":"a text-bearing artifact path is present","docs":"a docs path is present",
        "unknown":"an uncategorizable changed path is present => fail-closed escalate"}
for c in sorted(cats): reasons.append(CATMSG[c])

protected_in_scope = bool(cats & {"provider","schema","guard","secret"}) or prot_flag
# LANE-DRIVEN escalation (Codex #4) — the lane (from the selector) drives required checks regardless of path category
if lane and lane not in LANES_SET:
    fail_closed=True; reasons.append("the provided lane is not recognized => fail-closed maximal verification set")
if lane in ("protected-surface","secret-network-live-risk"):
    protected_in_scope=True; reasons.append("lane=%s => protected-path byte-unchanged required regardless of path category"%lane)
if lane=="secret-network-live-risk":
    req.update(["secret/provider-payload leak scan","reject-path / fail-closed tests","adversarial re-verify (secret/network/live lane)","protected-path byte-unchanged check"])
    reasons.append("lane=secret-network-live-risk => leak scan + reject-path + adversarial verification (regardless of path)")
# per-category required checks (accumulate / union)
if "docs" in cats: req.update(["markdown style/lint check","docs/MILESTONES append-only + status check"])
if "shell" in cats: req.update(["tool --self-test green","structural shell audit (no net/--live/env-read/env-hash; shellcheck-like grep)"])
if "schema" in cats: req.update(["schema field/structure validation","protected-path byte-unchanged check"])
if "provider" in cats: req.update(["WORKER_RESULT schema/result validator","secret/provider-payload leak scan","reject-path / fail-closed tests","protected-path byte-unchanged check"])
if "guard" in cats: req.update(["reject-path / fail-closed tests","protected-path byte-unchanged check"])
if "artifact" in cats: req.update(["secret/free-form metadata leak scan on the emitted artifact"])
if protected_in_scope: req.add("protected-path byte-unchanged check (git diff --name-status over the protected set)")
if fail_closed:
    req.update(["FULL self-test + leak scan + reject-path + protected-path byte-unchanged (fail-closed maximal set)"])
# escalation on prior findings / test failures
if findings is None or failures is None or (findings and findings>=1) or (failures and failures>0):
    req.add("adversarial re-verify of the prior finding / failing area")
    reasons.append("prior findings/test failures (or unparseable) => add adversarial re-verify (fail-closed)")
# optional (only when budget allows and not already required)
opt.update({"full repo self-test suite","cross-tool regression","performance/efficiency metrics capture (v0.5.0)"} - req)

def block(title,items):
    out=["- %s:"%title]
    out += ["  - %s"%i for i in (sorted(items) if items else ["(none)"])]
    return out
o=["# DMC Verification Plan — lane=%s%s"%(lane or "-"," [FAIL-CLOSED]" if fail_closed else "")]
o+=block("required_checks",req); o+=block("optional_checks",opt); o+=block("forbidden_checks",forb)
o+=["- advisory: a recommendation, not an enforcement gate"]; o+=["- reason:"]; o+=["  - %s"%r for r in reasons] or ["  - (none)"]
print("\n".join(o))
PY
}

self_test() {
  local P=0 F=0; ok(){ echo "  PASS $1"; P=$((P+1)); }; no(){ echo "  FAIL $1"; F=$((F+1)); }
  local TT; TT="$(mktemp -d)" || { echo "  FATAL: mktemp -d failed"; return 2; }; [ -d "$TT" ] || { echo "  FATAL: temp dir missing"; return 2; }; trap 'rm -rf "$TT"' RETURN
  local PRE; PRE="$(repo_hash)"
  rp(){ printf '%s' "$1" > "$TT/f.json"; plan "$TT/f.json"; }
  req_has(){ rp "$1" | awk '/^- required_checks:/{f=1;next} /^- optional_checks:/{f=0} f' | grep -qi "$2"; }

  # AC1 docs-only => markdown/style + status; NOT self-test
  { req_has '{"lane":"docs-only","changed_paths":"docs/X.md"}' 'markdown' \
    && ! req_has '{"lane":"docs-only","changed_paths":"docs/X.md"}' 'self-test'; } \
    && ok "AC1 docs-only => markdown/style + status (no heavy self-test)" || no "AC1 docs verification"
  # AC2 shell tool => self-test + structural shell audit
  { req_has '{"lane":"additive-tooling","changed_paths":".harness/evidence/dmc-v0.5.x-foo.sh"}' 'self-test' \
    && req_has '{"lane":"additive-tooling","changed_paths":".harness/evidence/dmc-v0.5.x-foo.sh"}' 'structural shell audit'; } \
    && ok "AC2 shell tool => self-test + structural shell audit" || no "AC2 shell verification"
  # AC3 schema => schema validation + byte-unchanged (protected)
  { req_has '{"changed_paths":".harness/schemas/foo.schema.md"}' 'schema field' \
    && req_has '{"changed_paths":".harness/schemas/foo.schema.md"}' 'byte-unchanged'; } \
    && ok "AC3 schema => schema validation + protected byte-unchanged" || no "AC3 schema verification"
  # AC4 provider/import path => schema/result validator + leak scan + reject-path + byte-unchanged
  local PV='{"changed_paths":".claude/workers/providers/glm-api/x.py"}'
  { req_has "$PV" 'result validator' && req_has "$PV" 'leak scan' && req_has "$PV" 'reject-path' && req_has "$PV" 'byte-unchanged'; } \
    && ok "AC4 provider/import => schema/result validator + leak scan + reject-path + byte-unchanged" || no "AC4 provider verification"
  # AC5 guard/hook/validator => reject-path + byte-unchanged
  { req_has '{"changed_paths":".claude/hooks/secret-guard.sh"}' 'reject-path' \
    && req_has '{"changed_paths":".claude/hooks/secret-guard.sh"}' 'byte-unchanged'; } \
    && ok "AC5 guard/hook/validator => reject-path + byte-unchanged" || no "AC5 guard verification"
  # AC6 protected_surface flag => byte-unchanged even for a docs-only changeset (near-scope)
  req_has '{"lane":"docs-only","changed_paths":"docs/X.md","protected_surface":true}' 'byte-unchanged' \
    && ok "AC6 protected_surface flag => protected byte-unchanged (near-scope)" || no "AC6 near-scope byte-unchanged"
  # AC7 text-bearing artifact => leak scan
  req_has '{"changed_paths":".harness/evidence/run-metrics-out.md"}' 'leak scan' \
    && ok "AC7 text-bearing artifact => leak scan required" || no "AC7 artifact leak scan"
  # AC8 malformed path list => fail closed (maximal set + FAIL-CLOSED marker), NOT silently skipped
  { rp '{"changed_paths":",,,"}' | grep -q 'FAIL-CLOSED' && req_has '{"changed_paths":",,,"}' 'maximal'; } \
    && ok "AC8 malformed path list => FAIL-CLOSED maximal set (not silently skipped)" || no "AC8 silent skip"
  # AC8b an uncategorizable path => fail closed
  rp '{"changed_paths":"weird://thing"}' | grep -q 'FAIL-CLOSED' && ok "AC8b uncategorizable path => FAIL-CLOSED" || no "AC8b uncategorized not failed-closed"
  # AC9 forbidden checks always include no-.env-read / no-live-call / no-payload-print
  { rp '{"changed_paths":"docs/X.md"}' | awk '/forbidden_checks:/{f=1} f' | grep -qi '.env' \
    && rp '{"changed_paths":"docs/X.md"}' | awk '/forbidden_checks:/{f=1} f' | grep -qi 'live provider'; } \
    && ok "AC9 forbidden_checks always: no .env read / no live call / no payload print / no auto-apply" || no "AC9 forbidden missing"
  # AC10 monotonicity: adding a protected path never REMOVES a required check (union)
  local n1 n2; n1="$(rp '{"changed_paths":"docs/X.md"}' | awk '/required_checks:/{f=1;next} /optional_checks:/{f=0} f' | grep -c '^  - ')"
  n2="$(rp '{"changed_paths":"docs/X.md,.claude/hooks/secret-guard.sh"}' | awk '/required_checks:/{f=1;next} /optional_checks:/{f=0} f' | grep -c '^  - ')"
  [ "$n2" -ge "$n1" ] && ok "AC10 union/monotonic: adding a protected path never removes a required check ($n1<=$n2)" || no "AC10 non-monotonic ($n1 $n2)"
  # AC11 deterministic + env-independent
  printf '%s' "$PV" > "$TT/d.json"; local b1; b1="$(plan "$TT/d.json")"
  local envi; envi="$(env -i PATH="$PATH" HOME="${HOME:-/tmp}" bash "$SELFPATH" --from "$TT/d.json" 2>/dev/null)"
  local diff_ok=1 v; for v in GLM_API_KEY ANTHROPIC_API_KEY DMC_VERIFY; do [ "$(env "$v=x" bash "$SELFPATH" --from "$TT/d.json" 2>/dev/null)" = "$b1" ] || diff_ok=0; done
  { [ "$envi" = "$b1" ] && [ "$diff_ok" = 1 ]; } && ok "AC11 deterministic + env-independent" || no "AC11 env-dependent"
  # AC12 structural audit
  local OP; OP="$(sed '/AUDIT_BLOCK_START/,/AUDIT_BLOCK_END/d' "$SELFPATH" | grep -vE '^[[:space:]]*#')"
  # >>>AUDIT_BLOCK_START
  ! printf '%s' "$OP" | grep -nE '(^|[^A-Za-z])(curl|wget)([[:space:]])| --live | --allow-network|os\.environ|getenv|printenv|HASH_CMD|\$\{DMC_' >/dev/null \
    && ok "AC12 no net/env-read/env-hash in operative source" || no "AC12 net/env present"
  # >>>AUDIT_BLOCK_END
  # AC13 env-hash injection
  # >>>AUDIT_BLOCK_START  (hostile-input test; excluded from the operative-source audit)
  local SENT="$TT/sentinel" FAKE="$TT/fakehash"; printf '#!/bin/sh\ntouch "%s"\necho PWNED\n' "$SENT" > "$FAKE"; chmod +x "$FAKE"
  local hb hh; hb="$(repo_hash)"; hh="$(DMC_HASH_CMD="$FAKE" repo_hash)"
  { [ ! -e "$SENT" ] && [ -n "$hb" ] && [ "$hb" = "$hh" ]; } && ok "AC13 env-hash injection: hostile DMC_HASH_CMD never read/executed" || no "AC13 env-controlled hash executed"
  # >>>AUDIT_BLOCK_END
  # AC15 (HARDENING / Codex #4) lane DRIVES escalation regardless of path category
  { req_has '{"lane":"secret-network-live-risk","changed_paths":"docs/X.md"}' 'leak scan' \
    && req_has '{"lane":"secret-network-live-risk","changed_paths":"docs/X.md"}' 'reject-path' \
    && req_has '{"lane":"secret-network-live-risk","changed_paths":"docs/X.md"}' 'byte-unchanged' \
    && req_has '{"lane":"protected-surface","changed_paths":"docs/X.md"}' 'byte-unchanged' \
    && rp '{"lane":"bogus-lane","changed_paths":"docs/X.md"}' | grep -q 'FAIL-CLOSED'; } \
    && ok "AC15 lane drives escalation: secret-lane => leak/reject/byte-unchanged on a docs changeset; unknown lane => FAIL-CLOSED" || no "AC15 lane ignored / under-verified"
  # AC16 (HARDENING / Codex #5) a secret-shaped changed path is value-blind redacted in the output (no metadata leak)
  ! rp '{"changed_paths":".claude/workers/providers/sk-ABCDEFGHIJKLMNOPQRST/x.py"}' | grep -q 'sk-ABCDEFGHIJKLMNOPQRST' \
    && ok "AC16 secret-shaped changed path value-blind redacted in output (no leak)" || no "AC16 metadata leak in reason"

  # AC14 read-only
  { [ -n "$PRE" ] && [ "$(repo_hash)" = "$PRE" ]; } && ok "AC14 read-only: repo byte-unchanged (deterministic sha256)" || no "AC14 repo changed"

  echo "  ---- self-test: PASS=$P FAIL=$F ----"; [ "$F" = 0 ]
}

CP=""; LANE=""; PS=""; FIND=0; FAIL=0; FROM=""; OUT=""; RUN=run
while [ $# -gt 0 ]; do case "$1" in
  --changed-paths) CP="$2"; shift 2;; --lane) LANE="$2"; shift 2;; --protected-surface) PS="$2"; shift 2;;
  --prior-findings) FIND="$2"; shift 2;; --test-failures) FAIL="$2"; shift 2;; --from) FROM="$2"; shift 2;; --out) OUT="$2"; shift 2;;
  --self-test) RUN=selftest; shift;; -h|--help) sed -n '2,12p' "$0"; exit 0;;
  *) echo "verification-planner: unknown arg $1" >&2; exit 2;;
esac; done
if [ "$RUN" = selftest ]; then echo "==== DMC VERIFICATION PLANNER — SELF-TEST ===="; self_test; exit $?; fi
INF=""
if [ -n "$FROM" ]; then [ -f "$FROM" ] || { echo "verification-planner: --from file not found" >&2; exit 2; }; INF="$FROM"
else
  INF="$(mktemp)"; trap 'rm -f "$INF"' EXIT
  python3 - "$CP" "$LANE" "$PS" "$FIND" "$FAIL" > "$INF" <<'PY'
import json,sys
k=["changed_paths","lane","protected_surface","prior_findings","test_failures"]
print(json.dumps(dict(zip(k,sys.argv[1:6]))))
PY
fi
if [ -n "$OUT" ]; then out_refused "$OUT" && { echo "verification-planner: --out protected/secret/in-work-tree — REFUSED" >&2; exit 2; }; plan "$INF" > "$OUT"; echo "verification-planner: wrote $OUT" >&2; exit 0; fi
plan "$INF"; exit $?
