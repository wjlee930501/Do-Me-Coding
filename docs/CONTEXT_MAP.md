# DMC Context Map (v1.0; supersedes v0.4.7)

A **single-source pointer index** of where each operating concern lives — so instructions are **referenced, not
duplicated** across context files. When a rule belongs in one place, link to it here instead of copy-pasting.

## Operating contracts (compact, non-conflicting)

| concern | canonical source | do NOT duplicate elsewhere |
|---|---|---|
| operating guide · default loop · commands | `DMC.md` | the loop / command list |
| **enforcement mode** (`active`/`passive`/`off`) | `DMC.md` §Modes + `.harness/mode` | mode semantics |
| **autonomy level** (`passive`…`human-gated-push`) | `AUTONOMY.md` (+ `.harness/schemas/autonomy.schema.md`) | level definitions |
| secret-protection patterns | `DMC.md` §Secret Protection | the secret pattern list |
| non-negotiable rules (incl. Rule 7) | `DMC.md` §Non-Negotiable Rules | the rule list |
| project memory (repo facts) | `AGENTS.md` | repo facts / landmarks |
| global agent instructions | `CLAUDE.md` (project-committed, git-tracked) | — |
| schemas | `*_SCHEMA.md` (root) + `.harness/schemas/*.schema.md` | schema bodies |
| guards / control plane | `.harness/evidence/dmc-v0.4.*.sh` + `.claude/hooks/*` | guard logic |
| repo-maintenance governance / amendment | `docs/DMC_CONSTITUTION.md` | law index; governance supremacy only (facts = machine SSoT) |

**Orthogonality:** the **autonomy level** (`AUTONOMY.md`) and the **enforcement mode** (`DMC.md`/`.harness/mode`) are
**independent axes** that compose; neither redefines the other. The enforcement floor (secret/destructive deny) +
Rule 7 hold at every autonomy level.

## Configuration-smell checklist (review before adding/editing a context file)

- ☐ **No duplication** — is this rule already canonical elsewhere? Link to it; don't re-state it.
- ☐ **No conflict** — does it contradict `DMC.md` modes, `AUTONOMY.md` levels, or a guard? Reconcile or stop.
- ☐ **No mode redefinition** — autonomy levels and enforcement modes stay on their own axis.
- ☐ **Stays compact** — a context file that keeps growing is a smell; extract to a referenced doc.
- ☐ **Single source of secrets/levels** — secret patterns live in `DMC.md`; autonomy levels in `AUTONOMY.md`; reference, don't copy.
- ☐ **Provenance honored** — Rule 7 (no copied leaked prompt text); external ideas are unverified design signals only.
- ☐ **Additive-first** — prefer a new referenced doc over editing a core contract; if editing, keep it minimal + explain why.

The v0.4.7 audit (`.harness/evidence/dmc-v0.4.7-context-audit.sh`) checks this map exists, the contracts are non-conflicting
(autonomy orthogonal to modes), and the context files stay within a conciseness bound.
