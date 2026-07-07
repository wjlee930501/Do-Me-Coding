# DMC Codex Adapter — ADVISORY hook shims (Ring-1)

This directory is DMC's **host adapter for the Codex CLI**: thin Ring-1 shims that translate Codex
lifecycle hook events onto the **same Ring-0 verdict CLIs** (`bin/dmc`, `bin/lib/*.py`) the Claude
Code adapter already calls. No enforcement logic lives here — the substantive verdicts are Ring-0's.

## Status: ADVISORY, not an enforcement boundary (human gate Option A)

At **codex-cli 0.132.0** the M6.5 verification spike
(`.harness/evidence/dmc-v1-m6.5-spike-findings.md`) determined that whether Codex lifecycle hooks
**fire** and whether the deny/allow/block decision **envelopes** these shims emit are **honored** are
BOTH *unprovable turn-free* — a live authenticated model turn is the only path to prove either, and
no live turn is ever DMC-initiated. The human gate chose **Option A**
(`.harness/evidence/dmc-v1-m6.5-spike-stop.md`): ship these shims as **ADVISORY translators**.

Concretely, on a Codex host:

- **Hook firing / envelope honoring is UNPROVEN.** These shims are advisory. Do not rely on them as
  a runtime enforcement boundary.
- **The enforcement boundary on Codex hosts is the pre-commit / CI gate.** That is where DMC scope,
  secret, and completion invariants are actually enforced for Codex work.
- **The M6 post-Bash diff guard is the PRIMARY safety net** on Codex (not a backstop): `unified_exec`
  streaming shells are `stable` and on by default, so Codex `PreToolUse` is explicitly non-airtight
  and can be evaded — the post-turn/post-Bash `git diff` guard is what actually catches an
  out-of-scope write.
- **No enforcement-parity with the Claude adapter is claimed.** The shims reproduce the Claude
  verdicts *by construction* (same Ring-0 CLIs), but the Codex host does not give them the same
  runtime reach.

`Option B` (a one-time, human-run, explicitly-consented live-turn verification to confirm
firing/envelope honoring before promoting the shims to enforcement-class) remains available later
as a separate human gate with its own scope. Nothing here authorizes a live turn.

## Files

| File | Codex event | Ring-0 binding | Claude counterpart |
|---|---|---|---|
| `dmc_codex_common.py` | — (shared library) | field read, mode, arming, redact, secret paths, envelopes | — |
| `dmc-codex-pretooluse.py` | `PreToolUse` | Bash→`dmc bash-radius`; Edit\|Write→`dmc-scope-lock --adjudicate`; Read\|Grep\|Glob→path-only secret deny | `pre-tool-guard.sh` + `scope-guard.sh` + `secret-guard.sh` |
| `dmc-codex-posttooluse.py` | `PostToolUse` | `dmc postbash-diff` + `dmc run block` + redacted evidence append | `evidence-log.sh` |
| `dmc-codex-userpromptsubmit.py` | `UserPromptSubmit` | natural-activation router (`.harness/mode`) | `dmc-router.sh` |
| `dmc-codex-stop.py` | `Stop` | `dmc stop-gate quick` | `stop-verify-gate.sh` |

Each shim is a single thin executable: read the Codex event JSON on stdin → call the same Ring-0
CLI as the corresponding Claude shim → emit the Codex envelope (`PreToolUse`
`hookSpecificOutput.permissionDecision`; `PostToolUse`/`Stop` `{"decision":"block","reason":…}`;
`UserPromptSubmit` `additionalContext`). All are python3 stdlib-only, deterministic, offline, and
make no network / model / API call.

## Wiring + trust (spike-confirmed turn-free)

`.codex/config.toml` and `.codex/hooks.json` in the repo root wire the shims. Two SEPARATE trust
steps apply, and DMC never bypasses either:

1. **Project trust** — a per-project `<repo>/.codex/config.toml` is merged only for a **trusted
   project** (`[projects."<abs-path>"] trust_level = "trusted"` in `$CODEX_HOME/config.toml`).
2. **Hook trust** — `<repo>/.codex/hooks.json` is gated by a one-time content-hash `/hooks` trust; a
   hook whose bytes change is skipped until re-trusted. **Never** use
   `--dangerously-bypass-hook-trust` — surface the trust step, do not bypass it.

`.agents/skills/` discovery and `AGENTS.md` discovery are NOT trust-gated (filesystem scan +
project-doc read), unlike executable project config.

## Mode + fail-closed behavior

`.harness/mode` is read identically to the Claude shims — **absent ⇒ active**; `passive` ⇒ deny tier
only, gates stand down; `off` ⇒ only the L0 static floor applies and dynamic verdicts stand down.

**Fail-closed (B2):** in **ACTIVE** mode with an **ARMED** run (current-run-id + `scope.lock.json`),
each shim emits a deny/block on degenerate input — (a) unparseable/empty event JSON, (b) a
missing/renamed expected field on a recognized guarded tool, (c) an absent/failed Ring-0 verdict
CLI, (d) an absent `.harness/mode` (⇒ active). This **hardens beyond the Claude shims**, which fail
*open* on (a)/(b). In `passive`/`off`, or when unarmed, the shims stand down **identically to the
Claude side**, so no non-run or stepped-aside session is bricked. (The `UserPromptSubmit` router is
not a gate — it has no deny/block envelope; its fail-safe posture is "do nothing" on degenerate
input, and it has no Ring-0 CLI so B2 case (c) does not apply there. The `Stop` gate is state-based —
the run id comes from `.harness/runs/current-run-id`, not the event — so it reaches Claude parity on
every input including malformed ones.)

## Field-name superset (tool_input names TBD-at-spike)

The spike could not dump Codex's per-tool `tool_input` schema turn-free
(`docs/CODEX_ADAPTER.md` §Open questions), so every field read in `dmc_codex_common.py` is a
case-insensitive **superset** over documented candidate key names across `tool_input` and the event
top level. A truly renamed field on a real guarded operation degrades to the fail-closed-in-active
deny above (B2 case b), never a silent fail-open. Per the spike disposition, the PreToolUse
edit-scope field shim is **backstop-only** — the post-Bash diff guard is the load-bearing net.

## Secret handling (B3 + A5)

Secret-bearing content is protected in two lanes, and **no secret file's contents are ever opened**:

- **Payloads** (Bash command / edited content) pass through the **identical `redact()` transform** as
  `.claude/hooks/evidence-log.sh` before reaching the evidence log — `sk-…` API keys and
  `password|secret|token|api_key=VALUE` forms are redacted.
- **Paths** are decided by the **path-only** secret guard (mirror of `secret-guard.sh`) — a
  secret-shaped path is DENIED before the operation runs, so it never reaches a log.

**A5 precision (recorded at the human gate):** the absolute no-raw-secret guarantee is scoped to
**command/content payloads** via `redact()`; a secret embedded in a bare file **path** (with no
`key=` form) is not caught by `redact()` by design — it is handled by the path-only secret deny.
Together (redact over payloads + path-only deny over paths) they uphold `CLAUDE.md` §Secret
Protection on the Codex surface.

## Degraded invariants (Codex) — see the M6.5 verification report

The residual gaps are recorded as machine-checkable assertions in
`.harness/verification/dmc-v1-m6.5-codex-adapter.md`: (i) the `unified_exec` / non-shell **evasion
residual gap** in Codex `PreToolUse`, and (ii) the **post-Bash diff guard as the load-bearing primary
Codex safety net** (not a backstop). These map to `docs/CODEX_ADAPTER.md` §3.
