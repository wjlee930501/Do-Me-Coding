# DMC v1.0 Enforcement Matrix

Status: IMPLEMENTED (v1.0, M10). This document is a NARRATIVE wrapper. It does not create,
strengthen, or re-author any guarantee; it narrates data and code that already shipped.

The machine-readable source of truth is `orchestration/harness-matrix.json`
(schema `dmc.harness-matrix.v1`), which self-tags its milestone as
"dmc-v1 M8 (P20 data file; M10 owns the narrative doc)". `dmc doctor` renders that JSON
per-host at runtime. Where this doc and the JSON ever disagree, the JSON wins — this file is
prose over the JSON, not a second source. It is faithful to `docs/CODEX_ADAPTER.md` §3
(the degraded-invariant matrix) and to `docs/DMC_V1_RUNTIME_ARCHITECTURE.md` §P20.

## Honesty rule

From the matrix SSoT (`orchestration/harness-matrix.json` `honesty_rule`): the Codex column
never asserts runtime enforcement — every Codex cell is advisory, each closed by a named
backstop, and `dmc doctor` renders the matrix per-host so each physical line names exactly one
harness. The DMC mode (`active` | `passive` | `off`, read from `.harness/mode`, absent ⇒
`active`) is reported host-independently on its own line, never attributed to a single harness.

Honesty-check provenance (AD-r2-1). The word-boundary lexeme grep this document is validated
against (the plan's VC4 check) is stricter-SHAPED than `dmc doctor`'s own negative control:
VC4 matches its forbidden markers only as whole words, whereas the doctor uses a substring test.
The two controls are intentionally NOT byte-identical; both keep every Codex-scoped cell
advisory and neither is the runtime floor.

## Classification legend

The three per-harness classes, verbatim intent from the JSON `classification_legend`:

- **enforced** — a runtime host mechanism denies/blocks before the effect (claude-code column only).
- **advisory** — wired but not a runtime boundary on this host; a named backstop closes the gap.
- **stub** — Ring-1 adapter not built for this host (absent) — this is the opencode column today.

Only the claude-code column ever carries an enforced-runtime guarantee.
Every codex cell is advisory, each with a named backstop.
Every opencode cell is a stub (the Ring-1 adapter is not built yet).

## The 8 invariants × 3 harnesses

Rendered one harness per physical line (AD-r2-2), reproducing the JSON cell wording.

### 1. scope-edit — Scope lock on edits
- **claude-code**: enforced — PreToolUse Edit|Write deny before write.
- **codex**: advisory — PreToolUse over edit tools (deny before write); tool-input field names unproven at the M6.5 spike; backstop: the post-Bash diff guard.
- **opencode**: stub — Ring-1 adapter not built (absent).

### 2. scope-bash — Scope lock on Bash writes
- **claude-code**: enforced — Bash write-radius classify (L0 git-apply/patch deny always, L1 scope adjudication when armed) + post-Bash diff guard.
- **codex**: advisory — PreToolUse Bash is non-airtight (unified_exec and non-shell paths evade interception); PRIMARY safety net: the M6 post-Bash diff guard.
- **opencode**: stub — Ring-1 adapter not built (absent).

### 3. secret-read — Secret-path read deny
- **claude-code**: enforced — secret-guard PreToolUse path-only deny.
- **codex**: advisory — PreToolUse path-only, pending a tool-input field-name shim; backstop: the instruction-level secret rule (CLAUDE.md / AGENTS.md).
- **opencode**: stub — Ring-1 adapter not built (absent).

### 4. stop-gate — Stop / completion gate
- **claude-code**: enforced — Stop hook + verification-report validator.
- **codex**: advisory — Stop decision:block parity, envelope honoring unproven at the M6.5 spike; backstop: the pre-commit/CI release gate.
- **opencode**: stub — Ring-1 adapter not built (absent).

### 5. natural-activation — Natural activation (suffix routing)
- **claude-code**: enforced — UserPromptSubmit router (Ring-0 owns the routing logic).
- **codex**: advisory — UserPromptSubmit parity; both hosts delegate to the Ring-0 router (no material residual gap).
- **opencode**: stub — Ring-1 adapter not built (absent).

### 6. approval — Approval gates
- **claude-code**: enforced — ask prompts via settings.json + the human-only gate.
- **codex**: advisory — approval_policy + PermissionRequest hook; the human-only gate is Ring-0 and host-independent.
- **opencode**: stub — Ring-1 adapter not built (absent).

### 7. hook-trust — Hook trust
- **claude-code**: enforced — hooks active once wired in settings.json.
- **codex**: advisory — non-managed hooks need a one-time /hooks content-hash trust; a changed hook is skipped until re-trusted; the installer surfaces the trust step and never bypasses it.
- **opencode**: stub — Ring-1 adapter not built (absent).

### 8. protected-dmc-bindings — Protected DMC bindings
- **claude-code**: scope-guard-dependent — .claude/** is editable by the agent unless a scope guard denies it.
- **codex**: stronger asymmetry — the OS sandbox keeps <root>/.codex, <root>/.agents and <root>/.git read-only to the agent even in workspace-write, so the agent cannot self-edit its own DMC bindings at runtime.
- **opencode**: stub — Ring-1 adapter not built (absent).

## Codex (Option-A) posture

The Codex adapter (`adapters/codex/**`) is ADVISORY and is never an enforcement boundary.
Whether Codex lifecycle shims run and whether their deny/allow/block envelopes are honored is
unprovable turn-free (the M6.5 spike, codex-cli 0.132.0). `_FLOORS` in
`adapters/codex/dmc_codex_common.py` is a faithful reproduction of the Claude static floors
(rm -rf, catastrophic, secret-exposure, git-apply, patch), not a runtime boundary. On Codex and
any non-Claude host the real boundary is the pre-commit/CI gate (`.github/workflows/dmc-ci.yml`)
plus the human release gate — no enforcement-parity with the Claude adapter is claimed anywhere
in the repo. See `docs/DMC_V1_HONEST_SCOPE.md` for the shipped scope and residual register.

## Surface enforcement tiers

Every DMC enforcement surface classified into one of five tiers. This is the surface-level view
that the 8-invariant JSON does not itself carry.

- **ENFORCED-runtime** — a Claude Ring-0/1 host hook denies or blocks before the effect.
- **BLOCKING-at-release** — composed into the `dmc gate release` verdict (advisory tool, blocking gate).
- **BLOCKING-in-CI** — a nonzero exit fails the pre-commit/CI job.
- **ADVISORY** — wired but not a runtime boundary; a named backstop closes the gap (the Codex Option-A posture).
- **DOCUMENTED-ONLY** — skill-mandated procedure at runtime, not a settings.json-wired hook.

| Surface | Tier | What it does |
|---|---|---|
| bash-radius L0 static floor (`pre-tool-guard.sh` + `dmc-bash-radius.py`) | ENFORCED-runtime | Command-position deny of git-apply/patch, rm -rf, catastrophic and secret-exposure verbs in ALL modes, armed or not. |
| bash-radius L1 dynamic write-radius | ENFORCED-runtime | When armed+active, adjudicates each Bash write target against the scope lock (0 allow / 3 ask / 4 deny); fail-closed if the CLI is unreachable. |
| scope-guard L1 scope.lock adjudication (`scope-guard.sh`) | ENFORCED-runtime | Edit\|Write PreToolUse deny outside the compiled scope.lock; active-mode only; fail-closed when armed. |
| secret-guard Read/Grep/Glob path-only deny (`secret-guard.sh`) | ENFORCED-runtime | Denies secret-shaped paths by string only in ALL modes (never opens the file, so cannot itself leak). |
| C1-broadened Bash secret-read block (`pre-tool-guard.sh`) | ENFORCED-runtime | Denies read-verb + secret-operand combinations (closes the `cp .env x` → `Read x` two-step); audit C1 remediation, ALL modes. |
| evidence-log C2 redaction + A3 fail-closed (`evidence-log.sh`) | ENFORCED-runtime | Masks known secret shapes in the PostToolUse evidence append; a detector crash/timeout records a sticky BLOCKED marker (fail-closed). |
| postbash diff guard (`dmc-postbash-diff.py`) | ENFORCED-runtime | On an armed run a since-arming out-of-scope change records a sticky BLOCKED marker; the actual hold lands at the stop gate. |
| stop-verify-gate + verify-crosscheck | ENFORCED-runtime | Stop hook arms from run state, delegates to `dmc stop-gate quick`, blocks on hold; verify-crosscheck refuses a PASS that is not honestly supported. |
| worker-context-guard.sh + worker-result-check.py | DOCUMENTED-ONLY (runtime); BLOCKING-at-release | NOT settings.json-wired — invoked by the worker skills/CLI; validate a proposal (no direct mutation, credential_exposure=none, files ⊆ allowed, DISALLOWED categories, token scan); become teeth at the release chain sub-gate. |
| apply-authorization chain (review-check → authorize → apply-check → fidelity) | DOCUMENTED-ONLY (at apply); BLOCKING-at-release | Skill-mandated, not a Ring-0/1 hook block (verbatim tier below); becomes BLOCKING at the M9 release gate chain sub-gate. |
| Codex Option-A shims (`adapters/codex/**`, `_FLOORS` parity) | ADVISORY | Faithful reproduction of the Claude static floors; never a runtime boundary; whether the shims run or their envelopes are honored is unprovable turn-free; the pre-commit/CI gate is the real backstop. |
| `dmc doctor` honesty split | self-CHECK (not a boundary) | Reports each host honestly; the Claude Ring-0 path is proven by a live deny-probe; the Codex host is reported ADVISORY only, with pre-commit/CI as the backstop. |
| `.github/workflows/dmc-ci.yml` (Option-A boundary) | BLOCKING-in-CI | The real enforcement boundary on Codex/non-Claude hosts; 15 blocking steps (13 substantive checks + 2 porcelain sandwiches) + 1 advisory legacy `selftest --all` replay. |
| release gate (`bin/lib/dmc-release-gate.py`, `dmc gate release`) | ADVISORY tool → BLOCKING-at-release verdict | Itself advisory (informs the human gate; grants nothing); composes 9 mirror-pinned sub-gates into one release verdict; the chain sub-gate makes worker-apply provenance BLOCKING-at-release. |

## Worker-chain honest tier (verbatim)

The apply-authorization chain is the single most important honest-tier statement. Quoted verbatim
from `.claude/skills/dmc-worker-review/SKILL.md:35-38`:

> HONEST ENFORCEMENT TIER: the review-check → authorize → apply-check → fidelity chain is
> skill-mandated procedure, not a Ring-0/1 hook block — nothing in the hook path stops an
> Edit/Write that is inside scope.lock but lacks an authorization; the runtime write floor
> remains scope-lock adjudication. The chain becomes BLOCKING at the M9 release gate (a run
> whose applied changes lack an import/delegation chain is refused).

So at runtime the worker validators and the apply-authorization chain are DOCUMENTED-ONLY: the
runtime write floor is scope-lock adjudication, and the chain only becomes teeth at the release
gate's chain sub-gate.

## CI blocking-count reconciliation

`.github/workflows/dmc-ci.yml` is the Option-A enforcement boundary. Its precise tiering:

- **15 blocking steps** = **13 substantive checks** (bash -n syntax floor, `dmc mirror-check`,
  `dmc doctor`, `dmc selftest release-gate`, `dmc selftest m9-suite`, `dmc linkcheck`, the
  model-name grep (CF3), the forbidden-lexeme/network grep (AA1), the Codex wiring presence
  check, and `dmc selftest {m6-suite, m65-suite, m7-suite, m8-suite}`) + **2 porcelain
  cleanliness sandwiches** (PRE and MID). The checkout and python-setup steps are infrastructure.
- **1 advisory step**: the last step, "Legacy full self-test replay", carries
  `continue-on-error: true`. The 802/3/3 legacy `selftest --all` baseline is a
  dev-environment-pinned artifact and count-divergent on GitHub runners by design; see
  `docs/DMC_V1_HONEST_SCOPE.md` for the named-tool root cause. It never fails the job.

The commonly quoted "13 blocking" figure counts the substantive checks only; the 2 porcelain
sandwiches are also blocking, so the honest total is 15 blocking steps.

## See also

- `docs/DMC_V1_HONEST_SCOPE.md` — shipped scope, the disclosed residual register, and the CF14 / D1 postures.
- `docs/DMC_V1_RELEASE_CHECKLIST.md` — the human-facing mirror of the 9 release-gate sub-gates.
- `orchestration/harness-matrix.json` — the machine-readable SSoT this doc narrates.
- `docs/CODEX_ADAPTER.md` §3 — the degraded-invariant matrix in prose.
