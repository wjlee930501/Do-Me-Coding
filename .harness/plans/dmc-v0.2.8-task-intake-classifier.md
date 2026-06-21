# Do-Me-Coding v0.2.8 — Task Intake Classifier

## Goal

Add a lightweight, **advisory** task-intake classifier that, given a requested DMC task, recommends the **smallest
safe workflow** to close it: which risk dimensions it touches, the required plan depth + critic focus, the protected
paths in play, the required **human gates**, and whether the task must **stop and ask**. It is **advisory only** — it
recommends; it never approves, implements, stages, commits, pushes, grants a gate, makes a live call, or reads
`.env*`/credentials. It mutates nothing except (optionally) writing its recommendation to an operator-named `--out`
file. **Fail-closed by design:** ambiguity or any high-risk signal → recommend the *stricter* path (require the gate,
stop and ask).

## User Intent

tooling / process (route each task to the minimal safe workflow; surface required gates early) — additive, doc +
read-only advisory script.

## 1. Problem statement

- The operator must, for every incoming task, decide: how deep a plan, what the critic should focus on, which protected
  paths are involved, which **human gates** are required (push / live / credential / schema-guard-hook / force /
  external), and whether to **stop and ask**. Today this is done from memory/judgment each time — easy to under-classify
  a risk (e.g. miss that a task touches a schema and silently skip the required gate).
- The handbook codifies the *rules*; nothing maps a *task description* to the *required workflow + gates*. A small
  classifier that does this mapping — **fail-closed**, advisory — reduces the chance of a missed gate and supports the
  anti-token-max goal (pick the smallest sufficient workflow, not the biggest).

## 2. Non-goals

- **No approval / no implementation / no automation of gates.** It recommends; the human and the loop decide. It never
  flips approval, stages, commits, pushes, or acts.
- No product/adapter/router/schema/hook/validator/guard/`dmc-glm-smoke` change.
- No live provider call, no `.env*`/credential read, no network, no leaked-text handling, no model/LLM call (pure
  keyword/heuristic — "lightweight" per the roadmap).
- Not a substitute for the critic, the Codex audit, or the human Release Gate — an *input* to them.
- No mutation of the real repo beyond an optional `--out` recommendation file the operator names (never `git add`ed).

## 3. Candidate design

### 3.1 `.harness/evidence/dmc-v0.2.8-task-intake-classifier.sh` (the classifier)
- **Invocation:** `dmc-v0.2.8-task-intake-classifier.sh --task "<description>" [--signals a,b,c] [--out <file>]`
  (`--task` = free text; `--signals` = explicit dimension hints to OR-in; at least one required.)
- **Dimensions detected** (keyword/heuristic over the task text + explicit `--signals`):
  `docs-only`, `test-only`, `adapter-change`, `router-change`, `schema-change`, `guard-hook-validator-change`,
  `live-provider-call`, `credential-behavior`, `external-publish-send`, `destructive-or-history-rewrite`,
  `unknown-high-ambiguity`.
- **Detection is fail-closed, UNION, and high-risk-dominant:**
  - Keyword families (matched over the task TEXT only — never by opening any file) map to dimensions. Families are
    broadened to this repo's own conventions:
    - **schema-change:** `schema|WORKER_(TASK|RESULT|REVIEW)_SCHEMA`
    - **guard-hook-validator-change:** `hook|guard|validator|secret-guard|scope-guard|pre-tool|stop-verify|worker-context-guard|worker-result-check|evidence-log|dmc-router`
    - **adapter-change:** `adapter|glm-api|oauth-cli|oauth_cli|manual_import` (provider-type tokens included)
    - **router-change:** `router|provider-router|ROUTING`
    - **live-provider-call:** `--live|--allow-network|--allow-exec|live call|real provider|network|http(s)?|GLM_API_KEY`
    - **credential-behavior:** `\.env|credential|token|secret|api[_-]?key|password|passwd|private key|\.pem|\.key|id_rsa|id_ed25519|bearer|oauth token|access_token|refresh_token|id_token|\.npmrc|\.netrc|\.pgpass|credentials\.json|service-account|keystore|\.p12|\.pfx`
    - **external-publish-send:** `publish|upload|send to|external|curl|wget|http|POST|webhook|npm publish|pypi|registry|gh release|email|slack|notion|scp|rsync|push to (a )?(non-origin|other) remote`
    - **destructive-or-history-rewrite:** `push --force|force-push|reset --hard|rebase|history rewrite|git rm|rm -rf|branch -D|clean -fd|filter-branch|filter-repo|reflog expire|gc --prune|stash drop|checkout --|restore --`
    - **docs-only:** `docs|README|handbook|\.md` ; **test-only:** `test|verify|fixture|harness`
  - **Independent protected-path-substring scan (catches low-vocabulary-only risk):** SEPARATELY from the keyword
    families, scan the task text for any protected-surface path fragment: `\.harness/|provider-router|ROUTING|
    WORKER_(TASK|RESULT|REVIEW)_SCHEMA|\.claude/hooks|secret-guard|scope-guard|dmc-glm-smoke|PROVIDER_CONTRACT|provider[
    _-]contract|glm-api|oauth-cli|oauth_cli|manual_import|adapter`. If ANY fragment is present, **force the matching
    protected-surface dimension (gate #7) + `stop_and_ask=true`**, even when the only keyword family that fired was
    docs-only/test-only. This makes the "protected_paths ⇒ named gate #7" invariant **bidirectional**: a protected path
    in the text always raises the gate, regardless of vocabulary.
  - **`harness` is guarded, not low-risk-terminal:** `.harness/` is a PROTECTED directory (plans/guards/schemas live
    there), so `harness` adjacent to `.harness/`-protected content never yields a low-risk terminal — it routes via the
    protected-path scan above. The bare `harness` keyword only contributes to test-only when NO protected-path fragment
    is present.
  - **UNION semantics (never first-match):** scan ALL families; the recommendation is the union of every matched
    dimension + the protected-path scan, merged to the **most-restrictive** (deepest plan, all matched gates, strictest
    stop_and_ask). A low-risk match (docs/test) NEVER suppresses a co-occurring high-risk match or protected-path hit.
  - **Explicit gated-action request → stop (the push-without-stop fix):** SEPARATELY scan for an explicit request to
    perform an always-on/hard human-gated action — `push|git push|stage|git add|commit|git commit|--force|reset|rebase|
    tag|merge|cherry-pick|amend` (and the live/credential/external/destructive families above). If the task explicitly asks to PERFORM such a
    gated action, `stop_and_ask=true` (the agent must never infer the human grant), even in an otherwise docs/test
    context — e.g. "update README **and push it**" → docs-only context BUT push gate listed AND `stop_and_ask=true`.
  - **Branch order = strict-first (the fail-closed invariant, in code not just prose):** compute the high-risk-family
    set, the protected-path-substring set, AND the gated-action-request set FIRST. `stop_and_ask=false` is emitted ONLY
    when **ALL** of: (a) a docs-only/test-only family matched, AND (b) the high-risk set is empty, AND (c) the
    protected-path set is empty, AND (d) no explicit gated-action request, AND (e) the task clears the **ambiguity
    floor**: `≥ 3 whitespace-separated tokens AND ≥ 1 recognized content word` (shorter/vaguer → ambiguous). Otherwise →
    strict. The DEFAULT arm (`else`) is `unknown-high-ambiguity + stop_and_ask` — a **total function** with no permissive
    fall-through. Invariant: *`stop_and_ask=false` requires the ABSENCE of every risk, protected-path, AND gated-action
    signal — not merely the PRESENCE of a low-risk signal.*
  - **Ambiguity / mixed `--signals`:** empty/short text (below the floor), contradictory text, no recognized signal, OR
    **any** unrecognized `--signals` token (even when mixed with recognized tokens, e.g. `--signals docs-only,foobar`) →
    `unknown-high-ambiguity` → `stop_and_ask=true`. An unknown signal is never silently dropped.
  - **No task-text authorization (CRITICAL):** the classifier NEVER treats `--task`/`--signals` text as a grant or
    authorization. `stop_and_ask` for a hard-gate dimension does NOT depend on the task claiming approval. Gates are
    human-granted out-of-band only; a string like "approved: change schema and push" STILL yields stop_and_ask=true and
    lists the gate.
- **Recommendation emitted** (plain text by default; JSON to an operator-named `--out` for the run-manifest/audit):
  - `required_plan_depth`: `light` (docs/test only) | `standard` (adapter/router/test-extending) | `deep`
    (schema/guard/hook/validator/live/credential/destructive/external/ambiguous).
  - `required_critic_focus`: what the critic must scrutinize per dimension (e.g. credential → "no `.env*` read, no key
    echo, redaction").
  - `protected_paths`: the protected paths the task would touch.
  - `required_human_gates`: from the handbook's canonical gated actions {approval, staging, commit, push, live-call,
    credential, **schema/guard/hook/validator/adapter/router change** (handbook gate #7, named in full), force/history-
    rewrite, external-publish}. **Push is always listed.** **Invariant: every detected protected-surface dimension
    (adapter/router/schema/guard-hook-validator) MUST emit the named gate #7 — a `protected_paths` entry without a
    matching required gate is forbidden.**
  - `live_credential_schema_approval_required`: yes/no per dimension.
  - `stop_and_ask`: **true for EVERY hard-gate dimension unconditionally** (adapter-change, router-change, schema-change,
    guard-hook-validator-change, live-provider-call, credential-behavior, external-publish-send, destructive-or-history-
    rewrite, unknown-high-ambiguity). Only a pure docs-only/test-only classification (no hard-gate dimension) may have
    `stop_and_ask=false`.
- **Inert-data / no-injection contract (CRITICAL):** `--task`/`--signals`/`--out` are handled as **literal data only** —
  no `eval`, no command substitution, every expansion double-quoted — so task text containing `.env`/`$(...)`/backticks
  is matched as a string and is NEVER executed or used to open a file.
- **`--out` write-target guard (CRITICAL, canonicalized):** the `--out` path is **CANONICALIZED first** (resolve
  symlinks + collapse `..` via `realpath`/`readlink -f` on the path AND its parent dir) and the guard **REFUSES (exit 2,
  writes nothing) if EITHER the raw OR the canonical path** matches a protected surface or secret pattern — so
  `x/../.claude/hooks/secret-guard.sh` and a symlink whose realpath is protected/secret are both refused. Protected set =
  the full v0.2.6 `DEFAULT_PROTECTED` (verified): `.claude/workers/providers/glm-api`, `.claude/workers/providers/oauth-cli`,
  `.claude/workers/providers/provider-router.py`, `.claude/workers/providers/ROUTING.md`, `.claude/hooks`,
  `WORKER_{TASK,RESULT,REVIEW}_SCHEMA.md`, `dmc-glm-smoke` — **plus `PROVIDER_CONTRACT.md`**. Secret patterns: `.env*`
  (except `.example`/`.sample`/`.template`), `*.pem`, `*.key`, `id_rsa`, `id_ed25519`, `credentials*`, `*secret*`,
  `*.p12`, `*.pfx`, `*.keystore`. **Canonicalization failure ⇒ refuse (fail-closed):** if `realpath`/`readlink -f`
  errors (e.g. macOS strict `realpath` on a non-existent parent), the guard REFUSES (exit 2) rather than skipping the
  check — the independent raw-substring match still applies regardless. (A guarded write may target only a non-protected
  operator-named path; it does not `mkdir -p` outside an existing dir.)
- **Advisory semantics:** output is a recommendation only; the classifier performs nothing. Exit code is informational:
  `0` = classified, `2` = usage/refused. (When `stop_and_ask=true` the recommendation text/JSON says so explicitly; the
  exit code must never be wired by a caller to trigger a stage/commit/push/gate.)
- **`--self-test`:** asserts classification + recommendation for a battery of known inputs (one per dimension + ambiguous
  + multi-dimension + high-risk-dominates + authorization-text + injection-text cases), confirming fail-closed behavior.
  **Non-mutating by design:** it performs ZERO `--out` writes into the repo — any `--out` exercise targets a
  `mktemp` path under `$TMPDIR` (outside the repo), cleaned up via `trap` (mirrors the v0.2.6/v0.2.7 pattern). The real
  repo working tree (`git status --porcelain`) is unchanged after the run.

### 3.1a Dimension → required human gate(s) mapping (vs handbook canonical gated actions)

The handbook (`DMC_OPERATOR_HANDBOOK.md` "Gated actions") defines: (1) approval, (2) staging, (3) commit, (4) push,
(5) live-call, (6) credential, **(7) schema/guard/hook/validator/adapter/router change [one combined gate over six
surfaces]**, (8) force/history-rewrite, (9) external-publish. Mapping (every row also carries the always-on
approval/staging/commit/push gates):

| Dimension | required gate(s) | plan_depth | stop_and_ask |
|---|---|---|---|
| docs-only | (approval/staging/commit/push only) | light | no |
| test-only | (approval/staging/commit/push only) | light | no |
| adapter-change | **#7** schema/guard/hook/validator/adapter/router | standard | **yes** |
| router-change | **#7** | standard | **yes** |
| schema-change | **#7** | deep | **yes** |
| guard-hook-validator-change | **#7** | deep | **yes** |
| live-provider-call | **#5** live-call | deep | **yes** |
| credential-behavior | **#6** credential | deep | **yes** |
| external-publish-send | **#9** external-publish | deep | **yes** |
| destructive-or-history-rewrite | **#8** force/history-rewrite | deep | **yes** |
| unknown-high-ambiguity | all-applicable | deep | **yes** |

adapter/router/validator are **sub-surfaces of the single handbook gate #7**, not separate gates (anti-token-max: do not
imply more gates than the handbook defines).

### 3.2 `docs/DMC_TASK_INTAKE.md` (the spec)
- Documents the dimensions, the broadened keyword families, the **§3.1a dimension→gate mapping table**, and the
  invariants: (i) **advisory-only** (recommends, grants nothing); (ii) **fail-closed total function** — default arm
  strict; `stop_and_ask=false` requires the ABSENCE of every risk and protected-path signal (not the mere presence of a
  low-risk one); (iii) **no task-text authorization** — gates are human/out-of-band only, never inferred from
  `--task`/`--signals`; (iv) **bidirectional protected-surface ⇔ named gate #7** — a protected-path fragment in the text
  always raises gate #7 + stop_and_ask, independent of keyword vocabulary; (v) **inert-data / no-injection** and the
  **`--out` write-target guard**; (vi) `.harness/` is a protected directory, not test-only evidence. States it is a
  heuristic aid, not an oracle — the critic + Codex audit + human gate remain authoritative; the plan's (1)–(9) gate
  numbering is the plan's own labeling of the handbook's unnumbered list.

### 3.3 `.harness/verification/dmc-v0.2.8-task-intake-classifier.md` (report)
- Records `--self-test` results, the fail-closed evidence (ambiguous → stop-and-ask; high-risk keyword → gate required),
  the advisory/no-mutation proof, and protected-file byte-unchanged.

## 4. File-level implementation scope

| Path | Change | Edit? |
|---|---|---|
| `docs/DMC_TASK_INTAKE.md` | NEW — classifier spec + advisory contract | yes (new) |
| `.harness/evidence/dmc-v0.2.8-task-intake-classifier.sh` | NEW — read-only advisory classifier (+ `--self-test`) | yes (new) |
| `.harness/verification/dmc-v0.2.8-task-intake-classifier.md` | NEW — verification report | yes (new) |
| adapters / `provider-router.py` / `ROUTING.md` / `WORKER_*_SCHEMA.md` / `.claude/hooks/*` / `dmc-glm-smoke` / product code | **NO change** | no |

## 5. Safety constraints

- **Advisory / read-only.** Recommends only; never approves/implements/stages/commits/pushes/grants a gate. Exit code
  is informational (never an action trigger).
- **Fail-closed (strongest form).** `stop_and_ask=false` requires the **ABSENCE of every risk and protected-path
  signal**, not merely the PRESENCE of a low-risk one: it is emitted ONLY when a docs/test family matched AND the
  high-risk set is empty AND the independent protected-path-substring set is empty AND the ambiguity floor is cleared;
  else strict. `stop_and_ask=true` is unconditional for every hard-gate dimension and for any protected-path hit; the
  default arm is strict. Never under-classify; never infer a gate-grant from task text.
- **Inert-data / no-injection.** `--task`/`--signals`/`--out` are literal data — `set -u` (and `set -o pipefail`), no
  `eval`, no command substitution, all expansions double-quoted; task text containing `.env`/`$(...)`/backticks is
  matched as a string, never executed/opened (proven by the M6 side-effect sentinel + M10 marker check).
- **No live call / no `.env*` read / no credentials / no network / no LLM call.** Pure keyword heuristic over the task
  TEXT; it matches the *word* `.env` but never *opens* a `.env*`/credential file (verified at runtime — see M2/M5).
- **`--out` write-target guard.** `--out` REFUSES (exit 2, writes nothing) if the resolved path is a protected surface or
  a secret pattern (see §3.1) — so the recommendation file can never clobber a protected/credential file. Otherwise it
  writes ONLY that one operator-named file and never `git add`s it.
- **No mutation by design.** Apart from a guarded `--out`, the classifier writes nothing. `--self-test` performs zero
  in-repo writes (any `--out` exercise targets `$TMPDIR`, cleaned up); the real working tree is unchanged after a run.
- **No protected-surface change** — adapters/router/schemas/hooks/guards/`dmc-glm-smoke` untouched; `git diff` empty (M3).
- **File-tracking is accurate (no false exclusion claim):** the classifier `.sh`, the spec `docs/DMC_TASK_INTAKE.md`, and
  the verification report are **TRACKED deliverables** (committed, like the v0.2.6/v0.2.7 runners under `.harness/evidence/`).
  Only the **auto-logged evidence file** `.harness/evidence/dmc-v0.2.8-task-intake-classifier.md` (the hook-generated
  evidence `.md`, distinct from the verification report) stays **untracked/excluded**, alongside the prior auto-logs.

## 6. Verification matrix (`--self-test` + checks; read-only, runtime-proven where it matters)

Every hard-gate T-row asserts BOTH `stop_and_ask=true` AND the **specific** required gate token (not a vague "gate
required").

| # | Check | Assertion |
|---|---|---|
| T1 | docs-only | `--task "update README handbook"` → docs-only, plan_depth light, gates = approval/staging/commit/push only, `stop_and_ask=false` |
| T2 | test-only | `--task "add verify harness fixtures"` → test-only, light, `stop_and_ask=false` |
| T3 | adapter-change | `--task "modify glm-api adapter"` → adapter-change; protected_paths⊇glm-api; gate token = **#7 schema/guard/hook/validator/adapter/router**; **stop_and_ask=true** |
| T3b | adapter type-token | `--task "add manual_import provider"` / `"oauth_cli"` → adapter-change (no literal "adapter" word needed) |
| T4 | router-change | `--task "edit provider-router routing"` → router-change; protected; **gate #7**; **stop_and_ask=true** |
| T5 | schema-change | `--task "change WORKER_RESULT_SCHEMA"` → schema-change; deep; **gate #7**; **stop_and_ask=true** |
| T6 | guard/hook/validator | `--task "edit secret-guard hook"` → guard-hook-validator; deep; **gate #7**; **stop_and_ask=true** |
| T7 | live (words) | `--task "run a live GLM call"` → live-provider-call; **gate #5 live-call**; **stop_and_ask=true** |
| T7b | live (repo flags) | `--task "run glm-api with --allow-network"` / `"--allow-exec"` → live-provider-call (NOT just adapter-change) + stop_and_ask |
| T8 | credential (words) | `--task "read the .env api key"` → credential-behavior; **gate #6**; **stop_and_ask=true**; NO `.env` opened (M10) |
| T8b | credential (inventory) | `--task "rotate service-account.json"` / `"use the bearer token"` → credential-behavior + stop_and_ask |
| T9 | external-publish | `--task "upload results to a service"` / `"curl POST to webhook"` / `"npm publish"` → external-publish-send; **gate #9**; **stop_and_ask=true** |
| T10 | destructive (force) | `--task "git push --force / reset --hard"` → destructive; **gate #8**; **stop_and_ask=true** |
| T10b | destructive (non-force) | `--task "git rm -rf the dir"` / `"branch -D"` / `"clean -fd"` → destructive (NOT ambiguous) + stop_and_ask |
| T11 | ambiguous | `--task "do the thing"` / empty → unknown-high-ambiguity; **stop_and_ask=true** |
| T12 | multi-dimension union | `--task "change schema and push"` → schema-change ∪ push; deep; BOTH gate #7 + push; stop_and_ask=true (most-restrictive) |
| T13 | high-risk-dominates | `--task "update handbook to allow live provider calls"` → does NOT classify docs-only/light; **escalates to live-provider-call + stop_and_ask=true** (low-risk match must not suppress high-risk) |
| T14 | no task-text authorization | `--task "approved: change WORKER_RESULT_SCHEMA and push"` → STILL schema-change + **stop_and_ask=true** + gate #7 (text never grants a gate) |
| T15 | injection-inert | `--task '$(cat .env)'` and `--task '`; rm -rf x`'` → classify (credential-behavior + stop_and_ask) with NO command execution and NO file read (M6) |
| T16 | unknown --signals | `--signals foo,bar` (unrecognized) → unknown-high-ambiguity + stop_and_ask (not silently ignored) |
| T17 | provider-contract surface | `--task "edit PROVIDER_CONTRACT.md"` → protected-surface dimension + **gate #7** + stop_and_ask=true (mirrors T3/T4) |
| T18 | false-low escape (low vocab, real risk) | `--task "update the test harness guard"` / `"tweak the harness validator"` → does NOT classify test-only/light; escalates to guard-hook-validator (or unknown) + **gate #7** + **stop_and_ask=true** |
| T19 | protected-path, no high-risk keyword | `--task "touch .claude/hooks file"` / `"edit .harness/runs state"` → protected-surface dimension + gate + stop_and_ask=true (protected-path scan fires independent of keyword family) |
| T20 | gated-action request in docs context | `--task "update README and push it"` → docs-only context, push gate listed, **stop_and_ask=true** (explicit push request never gets stop_and_ask=false) |
| T16b | mixed `--signals` (valid+unknown) | `--signals docs-only,foobar` → unknown-high-ambiguity + **stop_and_ask=true** (unknown token not silently dropped) |
| T21 | pure docs/test carve-out (negative) | `--task "rewrite the README onboarding section for clarity"` (no protected-path/gated-action, clears floor) → docs-only, light, **stop_and_ask=false** (proves the carve-out still works and doesn't leak) |
| M1 | mutates nothing (runtime, 2-part) | (a) classify with NO `--out`: real `git status --porcelain` byte-identical before/after; (b) `--out $TMPDIR/m.json`: exactly that one file written, `git status` unchanged (never `git add`ed) |
| M2 | static no-act tokens (neg + pos) | NEG `grep`: no `git add`/`commit`/`push`/`reset`/`apply`, no `eval`, no unquoted `$TASK`/`$OUT`, no `curl`/`wget`/`nc`/socket/LLM client. POS `grep`: every secret token (`.env`, `bearer`, `id_rsa`, …) appears ONLY inside a detector match-pattern variable assignment, and NO line contains both a secret token AND a read verb (`cat`/`source`/`<`/`read`/`head`/`tail`/`grep -f`). Closes the regex-false-positive gap M10 alone cannot. |
| M3 | protected byte-unchanged | `git diff --name-only` over adapters/router/schemas/hooks/`dmc-glm-smoke`/`PROVIDER_CONTRACT.md` → empty |
| M4 | fail-closed total-function (aggregate, signal-keyed) | after the FULL T-battery, assert the property keyed on the **signal sets** (not the dimension label, so the gated-action-in-docs case is covered): **EVERY** classification whose gated-action-request set OR protected-path set OR high-risk set is non-empty has `stop_and_ask=true`; CONVERSELY `stop_and_ask=false` occurs ONLY when all three sets are empty AND the ambiguity floor is cleared. This matches the §3.1 branch-order invariant exactly and proves the push-without-stop rule at the aggregate level (not only via the T20 point-test). The script's final `else` arm is the strict default. |
| M5 | `--out` write-target guard (literal + canonical) | `--out .env`, `.claude/hooks/secret-guard.sh`, `.claude/workers/providers/provider-router.py`, `.../oauth-cli/x`, `PROVIDER_CONTRACT.md`, AND traversal `x/../.claude/hooks/secret-guard.sh` AND a symlink whose `realpath` is a protected/secret file → all REFUSED (exit 2), target byte-unchanged / not created |
| M11 | self-test harness own-cleanliness | after `--self-test` completes (incl. its `$TMPDIR` `--out` exercises), real-repo `git status --porcelain` is byte-identical to before — the harness itself mutates nothing |
| M6 | runtime no-injection (sentinel) | feed `--task '$(touch "$TT/PWNED")'` and a backtick variant; assert exit 0 (classified credential/ambiguous + stop_and_ask) AND **`$TT/PWNED` does not exist** — proves nothing from the task text executed (concrete side-effect probe, not assertion) |
| M7 | exit codes (static contract) | classify → 0; missing `--task`/`--signals` → 2; refused `--out` → 2. (That a caller never *wires* the code to an action is a static/design contract — a caller property, not runtime-testable by this self-test — labeled as such.) |
| M8 | gate-token completeness | every handbook gated action (approval/staging/commit/push/live/credential/#7/force/external) maps to an emittable gate token; T3–T10/T17 assert the SPECIFIC token, so a missed/mislabeled gate fails the self-test |
| M9 | no network / no LLM | static: no `curl`/`wget`/`nc`/python-socket/LLM client invoked; pure keyword heuristic |
| M10 | runtime no-`.env` read (deterministic marker) | run the full battery in a temp dir whose only `.env` holds a unique marker `SENTINEL_LEAK_<rand>`; assert the marker NEVER appears in any run's stdout/stderr/`--out`, AND that credential-task classification is identical regardless of the sentinel's contents. By construction the script takes **no file path from task text**, so `open()` of `.env` is impossible — the marker check is the deterministic, non-root pass/fail (replaces the prior hedged disjunction). |

## 7. Regression risks

| Risk | Severity | Mitigation |
|---|---|---|
| **Task text suppresses a gate (authorization escape hatch)** | high | The classifier NEVER treats `--task`/`--signals` as a grant; `stop_and_ask` for a hard-gate dimension is unconditional; T14 asserts authorization-claiming text still yields stop_and_ask + gate. |
| **`--out` clobbers a protected/secret file** | high | `--out` write-target guard refuses protected-surface/secret paths (exit 2, no write); M5 asserts `--out .env`/hook/router refused. |
| **Free-text arg injection (exec/leak via shell)** | high | Inert-data contract: no `eval`, no command substitution, quoted expansions; T15/M6 feed `$(cat .env)`/backtick text → classified, nothing executed, no file opened. |
| Under-classifies a risk → required gate missed | high | Fail-closed + UNION + high-risk-dominates; broadened families cover repo conventions (`--allow-network`, `git rm`, secret inventory, `oauth_cli`/`manual_import`); T3–T13 assert hard-gate dimensions trigger the named gate + stop_and_ask; gate-token completeness (M8). |
| **False-low escape: real risk described in only low-risk words** (e.g. "test harness" = a guard) | high | Independent protected-path-substring scan forces gate #7 + stop_and_ask regardless of vocabulary; `stop_and_ask=false` requires ABSENCE of all risk/protected signals; `harness` guarded vs `.harness/`; T18/T19 assert escalation; M4 aggregate proves no permissive fall-through. |
| Gate enum incomplete (adapter/router/validator unnamed) | high | Gate #7 named in full; §3.1a mapping table; invariant "protected_paths ⇒ named gate"; M8/T3/T4 assert the specific token. |
| Reads `.env`/credential while detecting credential tasks | high | Matches the WORD in task TEXT only; never opens `.env*`/credential files; **runtime** M10 (sentinel `.env`) proves no read — source-grep alone is insufficient (and false-positives on the detector regex). |
| Mutates repo / self-test leaks | med | No-mutation-by-design; `--out` writes one guarded file; self-test writes only to `$TMPDIR` with `trap` cleanup; M1 (2-part runtime) asserts real working tree unchanged. |
| Classifier mistaken for an approver/automation | med | §2/§5 + spec: advisory only; exit code informational (M7), never an action trigger; grants no gate; the heuristic is an aid, not an oracle — critic + human remain authoritative. |
| Heuristic false-negative on novel phrasing | med | Default arm is strict (unknown-high-ambiguity + stop_and_ask, M4); a low-risk match never suppresses a co-occurring/unresolved high-risk hint (T13). |

## 8. Rollback plan

- **Pre-commit:** `git restore` / remove the new files (spec, classifier, report). No product code touched.
- **Post-commit:** `git revert <v0.2.8-commit-sha>` — additive doc + read-only script; adapters/router/guards/schemas
  untouched → clean revert.

## 9. Approval Status

Status: APPROVED
Approver: 대표님 (delegated semi-autonomous mode — flipped after 4-round adversarial critic PASS)
Approved At: 2026-06-21
