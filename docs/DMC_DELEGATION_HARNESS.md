# DMC Autonomous Delegation Harness (v0.3.8)

How DMC autonomous delegation runs **safely** — the roles, the critic handoff, the **allowed-autonomy vs gated-action
matrix** (faithful to the handbook gate map), and the **run-transcript checklist**. A read-only validator
(`.harness/evidence/dmc-v0.3.8-delegation-harness.sh`) mechanically checks a run's allowed-autonomy preconditions + its
observable push boundary. **The harness is a behavioral norm + a read-only check — not an enforcement mechanism; the
human Release Gate remains authoritative.**

> **Canonical role taxonomy: `orchestration/roles.json`** (the P14 `dmc.roles.v1` registry) is the
> single machine-readable home for the DMC orchestration roles and capability classes. The role table
> in section 1 below is **derived / legacy reference**; if it disagrees with the registry, the registry
> wins. Validate it with `bin/dmc roles validate`. This banner is additive — every section below is
> unchanged.

## 1. Roles (separation of duties)

_Derived / legacy view — canonical source: `orchestration/roles.json` (`dmc.roles.v1`)._

| role | does | never |
|---|---|---|
| **Orchestrator** | writes/revises the plan, applies REQUIRED changes, prepares staged/commit candidates | approves its own work; self-grants a gate |
| **Critic** | a **separate** adversarial pass → PASS / REVISE (required vs optional split) | implements; approves; edits |
| **Implementer** | writes only the **approved-scope** files; runs verification | touches out-of-scope or protected files |
| **Independent Auditor** (Codex) | read-only audit → ACCEPT / REVISE / BLOCKED — an **advisory input** | grants a gate; the agent never treats ACCEPT as a grant |
| **Release Gate** (human) | flips APPROVED; authorizes STAGE / COMMIT / PUSH / live / protected change | — (the gate is human; an agent never assumes it) |

**Hard separation:** no self-approval; no author-and-approve in one pass; the role that wrote a thing never approves it.

## 2. Critic handoff

A critic pass is a structured adversarial review, one verdict per dimension:

```json
{ "dimension": "...", "verdict": "PASS|REVISE", "required_changes": ["..."], "optional": ["..."], "notes": "..." }
```

Flow: DRAFT plan → critic panel → **REVISE** (apply REQUIRED) → focused re-pass → **PASS** → the human flips APPROVED.
Required changes are blocking; optional are non-blocking. The critic only reviews — it never implements or approves.

## 3. Allowed-autonomy vs gated-action matrix

Faithful to `docs/DMC_AGENT_HANDOFF.md:8-21`, `docs/DMC_OPERATOR_HANDBOOK.md:48-66`, and
`docs/DMC_EFFORT_PROVIDER_POLICY.md:28-31`.

**Allowed autonomously (no human gate):**
- write / revise a **DRAFT** plan
- run a **critic** panel; apply **REQUIRED** changes
- **START-WORK within the approved scope** (in-scope files only)
- run **verification** (mock / offline)
- run the **Codex audit** and the **gate-check** — these are **advisory inputs**

**Gated (require an explicit human gate EACH time — or a recorded standing delegation that pre-grants it):**

| gated action | gate |
|---|---|
| **APPROVED** flip | human |
| **STAGE** (`git add`) | human |
| **COMMIT** (`git commit`) | human |
| **PUSH** (`git push`) | human |
| **CLOSURE** (`docs/MILESTONES.md` entry + docs commit/push) | human |
| live-provider-call · credential / `.env` access | human |
| protected-surface change **beyond the approved scope** | human |
| history-rewrite / force · external-publish / send | human |

> **Codex ACCEPT and the gate-check are advisory INPUTS feeding the human Release Gate — never a granted gate.** An agent
> never treats a Codex ACCEPT as authorizing STAGE or COMMIT. A Codex ACCEPT is a *precondition* to the human commit gate,
> not the grant of it.

**Delegated autonomy.** A **recorded standing human delegation** may pre-grant specific gated actions for a scoped batch
(e.g. STAGE + COMMIT), with PUSH and CLOSURE remaining per-action gated. This is a *recorded human authorization* of those
gates — **not** autonomous self-granting. (The v0.3.x rails batch ran under exactly such a standing delegation.)

## 4. Run-transcript checklist

Per milestone:

- ☐ **DRAFT plan** written (`Approval Status: DRAFT`)
- ☐ **separate critic PASS** (a distinct review pass; REVISE looped back)
- ☐ **REQUIRED applied**
- ☐ **human APPROVED flip** (or a recorded standing delegation)
- ☐ **approved-scope-only implementation** (run state set; no out-of-scope / protected edit)
- ☐ **verification PASS** (harness/report green)
- ☐ **Codex ACCEPT** (an advisory input) recorded **before** the gated stage/commit transition
- ☐ **STAGE under a recorded gate/delegation** (approved files only; auto-log excluded)
- ☐ **COMMIT under a recorded gate/delegation** (exact message; clean boundary)
- ☐ **PUSH under a per-action human gate** — or correctly **deferred**
- ☐ **CLOSURE under a human gate** (`MILESTONES.md` entry; docs commit)

## Validator

```
dmc-v0.3.8-delegation-harness.sh --milestone <id> --plan <plan.md> --verify-report <report.md> --commit <ref> \
    [--repo <dir>] [--push-approved] [--out <file>]
dmc-v0.3.8-delegation-harness.sh --self-test
```

It checks the allowed-autonomy **preconditions** (plan APPROVED · separate critic=PASS · Codex ACCEPT input ·
verification PASS) and the **push boundary** (`DEFERRED` ⇒ compliant · `PUSHED` ⇒ needs `--push-approved` · `UNKNOWN`
⇒ NON-COMPLIANT, fail-closed). It performs no action and grants no gate; it **surfaces** the gated STAGE/COMMIT/CLOSURE
actions (whose authorization is a recorded human gate or standing delegation) rather than blessing them. Advisory exit
`0` (AUTONOMY-COMPLIANT) / `1` (NON-COMPLIANT). The `--verify-report` / `--plan` paths are refused unread if secret; git
is metadata-only.
