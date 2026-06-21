# DMC Task Intake Classifier (v0.2.8)

An **advisory, read-only** classifier that recommends the smallest SAFE workflow for a requested DMC task: the risk
dimensions it touches, required plan depth + critic focus, protected paths, required **human gates**, and whether to
**stop and ask**. It **recommends only** — it never approves, implements, stages, commits, pushes, grants a gate, makes
a live/LLM/network call, or reads `.env*`/credentials. **Fail-closed:** ambiguity or any risk/protected/gated signal →
the stricter recommendation. The critic, the Codex audit, and the human Release Gate remain authoritative — this is a
heuristic aid, not an oracle.

Classifier: `.harness/evidence/dmc-v0.2.8-task-intake-classifier.sh`

## Usage
```
classifier.sh --task "<description>" [--signals a,b,c] [--out <file>]
classifier.sh --self-test
```
Exit: `0` classified, `2` usage/refused. (Advisory — the exit code must never be wired to an action.)

## Dimensions & gate mapping (vs handbook canonical gated actions)

The handbook gated actions: (1) approval (2) staging (3) commit (4) push (5) live-call (6) credential
**(7) schema/guard/hook/validator/adapter/router change — ONE combined gate over six sub-surfaces** (8) force/history-
rewrite (9) external-publish. Mapping (every row also carries the always-on approval/staging/commit/push):

| Dimension | gate | plan_depth | stop_and_ask |
|---|---|---|---|
| docs-only / test-only | (always-on only) | light | no* |
| adapter-change / router-change | #7 | standard | yes |
| schema-change / guard-hook-validator-change | #7 | deep | yes |
| live-provider-call | #5 | deep | yes |
| credential-behavior | #6 | deep | yes |
| external-publish-send | #9 | deep | yes |
| destructive-or-history-rewrite | #8 | deep | yes |
| unknown-high-ambiguity | all-applicable | deep | yes |

`*` docs/test get `stop_and_ask=false` ONLY when **no** risk/protected-path/gated-action signal is present and the
ambiguity floor is cleared (see invariants).

## Invariants (fail-closed, total function)

1. **`stop_and_ask=false` requires the ABSENCE of every risk, protected-path, AND gated-action signal** — not merely
   the presence of a low-risk one. Branch order computes those three sets FIRST; the default `else` arm is
   `unknown-high-ambiguity + stop_and_ask`.
2. **No task-text authorization:** gates are human/out-of-band only; text like "approved: change schema and push" still
   yields `stop_and_ask=true` + the gate.
3. **Bidirectional protected-surface ⇔ gate #7:** an independent protected-path-substring scan (`.harness/`,
   `provider-router`, `ROUTING`, `WORKER_*_SCHEMA`, `.claude/hooks`, `PROVIDER_CONTRACT`, `glm-api`, `oauth-cli`, …)
   forces gate #7 + stop_and_ask regardless of vocabulary. `.harness/` is a protected dir, not test-only evidence.
4. **Explicit gated-action request → stop:** `push|stage|commit|--force|reset|rebase|tag|merge|cherry-pick|amend` (+ the
   live/credential/external/destructive families) force `stop_and_ask=true` even in docs/test context.
5. **Mixed `--signals`:** any unrecognized token (even with valid ones) → `unknown-high-ambiguity + stop_and_ask`.
6. **Ambiguity floor:** `≥ 3 tokens AND ≥ 1 recognized content word`; shorter/vaguer → ambiguous.
7. **Inert-data / no-injection:** `--task`/`--signals` matched as literal strings (grep stdin); `set -u`/`pipefail`, no
   `eval`, no command substitution, quoted expansions — task text containing `.env`/`$(...)`/backticks is matched as a
   string, never executed or used to open a file.
8. **`--out` write-target guard (canonicalized):** refuses (exit 2, writes nothing) if the raw OR canonical (realpath/
   symlink/`..`-resolved) path is a protected surface (full v0.2.6 `DEFAULT_PROTECTED` + `PROVIDER_CONTRACT.md`) or
   secret pattern; canonicalization failure ⇒ refuse.

This classifier was hardened through a four-round adversarial critic panel; the (1)–(9) gate numbering is the plan's own
labeling of the handbook's unnumbered list.
