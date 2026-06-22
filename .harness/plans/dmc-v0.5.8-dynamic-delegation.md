# PLAN — v0.5.8 Dynamic Delegation Harness (APPROVED)

Parent: batch plan (APPROVED). Additive; protected surface untouched. Docs-artifact generator.

## Goal
Produce a delegation handoff encoding the four roles (Orchestrator/Implementer/Critic/Release Gate) with owns/must-not/
outputs, a gate matrix that separates critic PASS from release authorization, the bounded-batch autonomy, an explicit
forbidden list, and a compact handoff prompt. No leaked/proprietary prompt text; no secret-shaped text.

## Accepted file scope (additive)
`docs/DYNAMIC_DELEGATION.md` · `.harness/evidence/dmc-v0.5.8-dynamic-delegation.sh` · this plan ·
`.harness/verification/dmc-v0.5.8-dynamic-delegation.md`

## Acceptance criteria
handoff includes all four roles; gate matrix matches the DMC handbook; stage/commit/push/closure gated unless explicitly
batch-authorized (push/main/closure always human-gated); Codex/critic ACCEPT advisory never a push grant; no leaked/
secret-shaped text. Self-test green; repo byte-unchanged.

## Stop conditions
Critic-PASS-as-release-grant, ungated push/main/closure, secret/env read, leaked prompt text, token-max expansion.
