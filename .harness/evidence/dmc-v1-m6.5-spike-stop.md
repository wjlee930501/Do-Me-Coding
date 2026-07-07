# M6.5 Codex Adapter — SPIKE STOP + Human-Gate Decision Point

- **Task**: DMC-T011b.1 · **Run**: dmc-run-8fef31d58eee · **Date**: 2026-07-06
- **Codex CLI**: `codex-cli 0.132.0`
- **Trigger**: plan `.harness/plans/dmc-v1-m6.5-codex-adapter.md` §Proposed Changes B4 "No-live-turn rule"
- **Companion evidence**: `.harness/evidence/dmc-v1-m6.5-spike-findings.md`

## Why this STOP exists

The spike concluded that a **live authenticated model turn is the ONLY path to prove (i) Codex
lifecycle hooks fire and (ii) deny/allow/block decision envelopes are honored.** Per the plan's B4
rule, that is NOT an exception the implementer may take — it is a STOP + human-gate decision point,
recorded here. **No live model turn was taken; no API key was read or required** (see the
no-live-turn attestation in the findings file).

## What is proven vs unprovable (turn-free)

- **UNPROVABLE-TURN-FREE** (this STOP): hooks fire; PreToolUse deny/allow/updatedInput honored;
  Stop `decision:"block"` honored; PostToolUse observes unified_exec writes; per-tool `tool_input`
  field names. Basis: offline `codex exec` reaches the model websocket (401, no auth) before any
  enforcement-hook side-effect is observable, no hook markers fire, and the CLI exposes **no headless
  hook emit/replay/dry-run surface** (exhaustive subcommand search; only `--dangerously-bypass-hook-trust`
  exists, which DMC must not use).
- **CONFIRMED turn-free** (NOT blocked by this STOP): AGENTS.md discovery + 32 KiB `project_doc_max_bytes`
  cap; `.agents/skills/<name>/SKILL.md` discovery; trusted-project `.codex/config.toml` merge; sandbox
  modes; `hooks`/`multi_agent`/`unified_exec` are stable + enabled by default.

## The decision handed to the human gate

Per the plan's per-fact disposition table, "hooks fire" and "decision contracts honored" being
unprovable-turn-free ⇒ **FULL STOP of the enforcing-shim build** for those claims, and the milestone
**defaults to documented-manual + pre-commit/CI gate**. The human gate chooses the reduced scope:

- **Option A (recommended default)** — proceed with the NON-enforcement deliverables that ARE proven
  viable: `.agents/skills/dmc-*` bindings + mirror module (T011b.3) and the AGENTS.md generator +
  schema (T011b.4); build the `adapters/codex/` shims as **advisory** translators bound to the same
  Ring-0 verdict CLIs, with the **pre-commit/CI gate as the real enforcement boundary** and the
  **post-Bash diff guard as the primary Codex safety net**. Enforcement parity is NOT claimed on Codex.
- **Option B** — additionally authorize a ONE-TIME, human-run, explicitly-consented live-turn
  verification (outside DMC automation; a NEW human gate + its own scope) to empirically confirm
  firing/envelope honoring before shipping the shims as enforcement-class. This spike did not and will
  not take that turn.
- **Option C** — defer the Codex shim build entirely; ship only skills + AGENTS.md generator now.

## Constraints reaffirmed

- No DMC-initiated live model turn — ever. This artifact does not authorize one.
- `--dangerously-bypass-hook-trust` is forbidden as an enforcement or proof mechanism.
- Any live-turn verification (Option B) is a separate, human-initiated gate with its own consent and scope.

**STATUS: STOPPED — awaiting human-gate decision (A / B / C).**

## Human gate decision (recorded 2026-07-07 KST)

**DECISION: Option A** — approver wjlee, granted via AskUserQuestion in the orchestrating session
(option "A — advisory shim으로 진행 (권장)").

Operative consequences (bind T011b.2–.5):
- T011b.3 (skills bindings + mirror) and T011b.4 (AGENTS.md generator + schema) proceed AS PLANNED
  (their surfaces were CONFIRMED turn-free by the spike).
- T011b.2 ships the `adapters/codex/` shims as **ADVISORY translators**: same Ring-0 verdict CLIs,
  same envelopes, same fixtures (happy-path + B2 fail-closed + B3 redaction negative controls) —
  but **NO enforcement-parity claim on Codex**. The documented enforcement boundary on Codex hosts
  is the **pre-commit/CI gate**, with the **M6 post-Bash diff guard as the primary safety net**.
- All shim/adapter docs, the generated host AGENTS.md operating rules, and the T011b.5
  verification report MUST state the advisory status explicitly (feeds the A3 machine-checkable
  "Degraded Invariants (Codex)" assertions).
- **Option B remains available later** as a separate, human-initiated, explicitly-consented
  live-turn verification under a NEW human gate with its own scope — never DMC-initiated. Nothing
  in this decision authorizes a live turn.
- Option C (defer) was NOT taken.
