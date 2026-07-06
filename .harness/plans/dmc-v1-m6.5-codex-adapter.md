# Plan: DMC v1 M6.5 — Codex Adapter (P21, spike-first)

Plan ID: dmc-v1-m6.5-codex-adapter · Date: 2026-07-06 · Format: PLAN_SCHEMA.md
Milestone-scoped plan for master plan §M6.5 (inserted by Rev 3 per the approved direction plan
`.harness/plans/dmc-v0.5-codex-adapter-direction.md`). **DRAFT** — its critic pass is
deliberately deferred until M6 ships (the Ring-0 verdict-CLI interfaces the shims bind to are
M6 deliverables); then critic + human gate before any implementation. Design authority:
`docs/CODEX_ADAPTER.md`.

## Goal

Make DMC installable and enforceable inside Codex CLI as a host: translate the Codex lifecycle
hook events onto the SAME Ring-0 verdict CLIs the Claude shims call (no enforcement logic in
the adapter), bind the `dmc-*` workflow skills to Codex's `.agents/skills/` surface, template
the per-project `.codex/` config/hooks wiring, and give hosts a deterministic, contract-bound
AGENTS.md generator — all gated behind a local-CLI verification spike that re-proves the
web-verified (2026-07-06) Codex surface before anything is built.

## User Intent

Classify: **feature** (secondary: docs — templates and the AGENTS.md content contract are
declarative artifacts).

## Current Repo Findings

- Finding: no Codex host surface exists — no `adapters/codex/`, `.codex/`, `.agents/`; the
  master plan carried Codex only as an M8 timeboxed spike until Rev 3 promoted it.
  Source: repo listing 2026-07-06; `.harness/plans/dmc-v1-runtime-upgrade.md` Rev 3 §M6.5.
- Finding: the Codex CLI surface needed for near-parity binding is officially documented
  (lifecycle hooks incl. Stop with `decision:"block"`, PreToolUse deny/allow/updatedInput,
  `.agents/skills/` SKILL.md standard, per-project `.codex/config.toml`+`hooks.json` under a
  trusted-project flow, sandbox modes, `codex exec --json --output-schema`) but was verified
  from web docs, not a local install; OpenAI marks hooks "a guardrail rather than a complete
  enforcement boundary".
  Source: `docs/CODEX_ADAPTER.md` §1 facts table (with URLs + confidence tags).
- Finding: Ring-0 verdict CLIs the shims must call (Bash radius, post-Bash diff, semantic
  cross-check, stop-gate quick) are M6 deliverables; their CLI names/contracts freeze at M6
  closure.
  Source: `.harness/plans/dmc-v1-m6-hook-hardening.md` §Proposed Changes.
- Finding: Codex protects `<root>/.codex` and `<root>/.agents` read-only against the agent in
  workspace-write mode — the agent cannot self-edit DMC's Codex bindings at runtime (a
  guarantee the Claude adapter does not have for `.claude/`).
  Source: `docs/CODEX_ADAPTER.md` §3 degraded-invariant matrix.

## Relevant Files

| Path | Reason | Allowed to Edit |
|---|---|---|
| .harness/evidence/dmc-v1-m6.5-spike-*.md | spike findings (surface re-proof or refutation) | yes |
| adapters/codex/** (new) | hook shims: Codex event JSON → Ring-0 verdict CLI → Codex decision envelope | yes (new) |
| .codex/hooks.json, .codex/config.toml (new, template-in-repo) | DMC repo's own Codex wiring + the template hosts copy | yes (new) |
| .agents/skills/dmc-*/** (new) | Codex-side skill bindings mirroring .claude/skills dmc verbs | yes (new) |
| bin/lib/dmc-agents-md.py (new), bin/dmc | host-AGENTS.md generator bound to the CODEX_ADAPTER §5 content contract (consumes orient/landmarks; Unknown rule enforced) + verb registration (single owner) | yes (additive) |
| bin/lib/dmc-skills-mirror.py (new) | .agents/skills ↔ .claude/skills mirror/drift check (M3 pattern) + selftest section | yes (additive) |
| .harness/schemas/agents-md.schema.md (new) | content contract as a validatable schema | yes (new) |
| tests/fixtures/m6.5/** (new) | shim unit fixtures (event JSON → expected decision), generator fixtures | yes (new) |
| docs/CODEX_ADAPTER.md | spike-findings addendum + any fact-table corrections (tagged) | yes |
| .harness/evidence/dmc-v1-m6.5-*.md, .harness/verification/dmc-v1-m6.5-*.md | evidence/verification | yes |
| .claude/hooks/**, .claude/settings.json | M6 surface — frozen after M6 | no |
| .claude/install/** | installer is M8's surface (ships what this milestone builds) | no |
| .claude/workers/providers/**, worker validators | never / M7 | no |
| orchestration/roles.json | registry frozen; adapter consumes it read-only | no |

## Out of Scope

- Installer `--host codex|claude|both` work (M8 / P19).
- Any change to Claude hooks, settings, worker surfaces, provider adapters.
- Codex `.rules`/execpolicy as load-bearing enforcement (defense-in-depth note only);
  `requirements.toml`; subagent auto-dispatch emulation; deprecated `~/.codex/prompts`.
- Any live model/API call. The spike drives the LOCAL Codex CLI binary offline-where-possible;
  it must not require or read any API key, and it makes no DMC-initiated network call. If the
  local CLI itself is absent, the spike is BLOCKED (fallback path, below) — never simulated.
- Staging/commit/push; `docs/MILESTONES.md`.

## Proposed Changes

- Change: SPIKE FIRST (blocking) — on a locally installed Codex CLI, empirically re-prove:
  hook events fire (PreToolUse/PostToolUse/UserPromptSubmit/Stop) with documented JSON stdin;
  deny/allow/block envelopes honored; per-tool `tool_input` field names recorded per tool;
  `.agents/skills/` discovery + invocation; per-project `.codex/` trust flow UX; `/import`
  migration scope; whether PostToolUse observes unified_exec writes. Findings (confirmations
  AND refutations) written to evidence and, as an addendum + tagged corrections, into
  `docs/CODEX_ADAPTER.md`. GATE: if the surface is materially unconfirmed, STOP — the
  milestone downgrades to the master plan's documented-manual + pre-commit/CI-gate fallback,
  and the human gate decides the reduced scope.
  Files: .harness/evidence/dmc-v1-m6.5-spike-*.md, docs/CODEX_ADAPTER.md
  Rationale: web-verified facts must never authorize a build (direction plan assumption row 1).
- Change: hook shims under `adapters/codex/` — one thin executable per bound event, each:
  parse Codex event JSON (superset field read, case-insensitive paths) → call the SAME Ring-0
  verdict CLI as the Claude shim → emit the Codex decision envelope; fail-closed in active
  mode; `.harness/mode` respected identically; Stop shim arms from run state and holds on
  BLOCKED runs, with the pre-commit/CI gate documented as the fallback completion gate.
  Files: adapters/codex/**, .codex/hooks.json, .codex/config.toml, tests/fixtures/m6.5/**
  Rationale: parity-by-construction — verdicts come from one place; the adapter only
  translates envelopes.
- Change: skill bindings `.agents/skills/dmc-{plan-hard,critic,start-work,verify-hard,status}/`
  mirroring the Claude skills' operative instructions bound to the same `dmc` verbs, plus a
  mirror/drift check (M3 pattern) wired into selftest so the two skill surfaces cannot
  silently diverge.
  Files: .agents/skills/dmc-*/**, bin/lib/dmc-skills-mirror.py, bin/dmc
  Rationale: direction plan T104 note; one workflow, two hosts.
- Change: host-AGENTS.md generator — `dmc` verb emitting the CODEX_ADAPTER §5 contract
  sections from repo facts (orient/landmarks inputs where available); every non-derivable
  fact emitted literally as `Unknown`; never invents business logic; merge policy per
  `docs/HOST_REPO_ADAPTATION_POLICY.md` (never blind-copy DMC's own AGENTS.md); schema +
  validator + refusal fixtures (missing section / invented-fact heuristics / non-Unknown
  placeholder).
  Files: bin/lib/dmc-agents-md.py, bin/dmc, .harness/schemas/agents-md.schema.md, tests/fixtures/m6.5/**
  Rationale: Priority 4 lands as a contract-bound Ring-0 tool, host-agnostic (Claude hosts
  can use it too).

## Acceptance Criteria

- Criterion: spike evidence exists and every CODEX_ADAPTER §1 fact the build relies on is
  marked confirmed / corrected / refuted; a refuted load-bearing fact ⇒ recorded STOP +
  fallback decision, not a silent workaround.
  Verification Method: spike evidence file review; addendum present in docs/CODEX_ADAPTER.md.
- Criterion: for each bound event, shim fixtures prove: in-scope op → allow; out-of-scope
  edit → deny; secret-path read → deny; out-of-scope post-Bash diff → BLOCKED verdict
  surfaced; stop with unresolved BLOCKED/receipt-gap → block; suspended run → no block —
  byte-comparable verdicts with the Claude shim on identical inputs.
  Verification Method: adapters/codex fixture suite (offline, event-JSON driven), exit 0;
  cross-adapter verdict-parity check.
- Criterion: skills mirror/drift check green; a seeded one-byte drift in a mirrored skill is
  REFUSED (negative control).
  Verification Method: `bin/dmc selftest` new section.
- Criterion: AGENTS.md generator emits all contract sections on the node/python/empty fixture
  hosts; unknown facts render literally as `Unknown`; validator refuses a generated file with
  a missing section (negative control).
  Verification Method: generator fixture suite + schema validator, exit 0.
- Criterion: `bin/dmc selftest --all` == pinned baseline + new sections 0 FAIL; mirror-check
  green; no `.claude/` or protected-surface diff.
  Verification Method: selftest --all; `git diff --name-only` vs this plan's allowlist.
- Criterion: Ring-0 stays model-name-free (capability classes only; Codex model names appear
  ONLY in the dated lookup rows of docs/CODEX_ADAPTER.md).
  Verification Method: v0.6.1 self-scan extended over adapters/ and new bin/lib files.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Local Codex CLI unavailable or older than the documented surface | medium | spike is BLOCKED, not faked; fallback = documented-manual + pre-commit/CI gate, human-gated reduced scope |
| Codex hook non-airtightness (unified_exec / non-shell paths) leaks writes past PreToolUse | high (known) | post-Bash/post-turn diff guard + release gate are the load-bearing backstops; degraded-invariant matrix keeps the gap explicit; never claim parity where there is none |
| Hook trust flow blocks hosts (untrusted hooks silently skipped) | medium | trust step documented in template + generated AGENTS.md; spike records the UX; never auto-bypass trust |
| M6 verdict-CLI interfaces shift before this milestone starts | medium | critic pass deferred until M6 ships; plan re-validated then; shims bind to frozen CLI names |
| Skill text drift between hosts | low | mirror/drift selftest with negative control |
| Adapter accidentally grows enforcement logic | medium | acceptance requires verdict parity vs Claude shim on identical inputs; code review checklist: adapters translate, never decide |

## Assumptions

| Assumption | Confidence | How to Verify |
|---|---|---|
| CODEX_ADAPTER §1 facts hold on a current local Codex CLI | medium until spike | the blocking spike task |
| M6 ships the four Ring-0 verdict CLIs with stable names/exit contracts | high | M6 closure record + `bin/dmc help` |
| Codex PostToolUse (or turn-end) provides a usable anchor for the post-Bash diff guard | medium | spike probes; if absent, guard runs at Stop + pre-commit gate (recorded degradation) |
| `.agents/skills` discovery works from repo root in a fresh clone without extra config | medium | spike probes a scratch clone |

## Execution Tasks

- [ ] DMC-T012a: Local Codex CLI verification spike + findings evidence + CODEX_ADAPTER
  addendum/corrections. BLOCKING GATE for all later tasks.
  Files: .harness/evidence/dmc-v1-m6.5-spike-*.md, docs/CODEX_ADAPTER.md
  Notes: offline-where-possible; no API key read; refutation ⇒ STOP + human decision.
- [ ] DMC-T012b: adapters/codex/ shims + .codex templates + fixture suite + cross-adapter
  verdict-parity check.
  Files: adapters/codex/**, .codex/*, tests/fixtures/m6.5/**
  Notes: shims call M6 Ring-0 CLIs only; fail-closed-in-active; mode-file parity.
- [ ] DMC-T012c: .agents/skills/dmc-* bindings + skills mirror/drift check + selftest section.
  Files: .agents/skills/dmc-*/**, bin/lib/dmc-skills-mirror.py, bin/dmc
  Notes: single-owner rule for bin/dmc verb registration (shared with T012d).
- [ ] DMC-T012d: host-AGENTS.md generator + schema + validator + fixtures.
  Files: bin/lib/dmc-agents-md.py, bin/dmc, .harness/schemas/agents-md.schema.md, tests/fixtures/m6.5/**
  Notes: Unknown rule enforced by validator; merge policy per HOST_REPO_ADAPTATION_POLICY.
- [ ] DMC-T012e: evidence + verification report (must pass `dmc validate verification`).
  Files: .harness/evidence/dmc-v1-m6.5-*.md, .harness/verification/dmc-v1-m6.5-*.md
  Notes: final status PASS | FAIL | PARTIAL; degraded invariants restated honestly.

## Verification Commands

| Command | Reason | Required |
|---|---|---|
| spike transcript / evidence review | web-verified facts re-proven locally | yes |
| adapters/codex fixture suite (offline event-JSON) | shim correctness + verdict parity | yes |
| bin/dmc selftest --all | pinned baseline + new sections 0 FAIL | yes |
| bin/dmc mirror-check | legacy copies untouched | yes |
| model-name self-scan over adapters/** + new bin/lib | Ring-0 stays model-name-free | yes |
| bash -n / python3 -m py_compile on touched files | syntax floor | yes |
| git diff --name-only vs allowlist; git status --porcelain | scope + cleanliness | yes |

## Approval Status

Status: DRAFT
Approver: (pending — wjlee, human release gate; critic pass deferred until after M6 ships)
Approved At: —
