# Do-Me-Coding v0.3.0 — E2E Completion Controller

## Goal

Add a **report-only** controller that determines whether a milestone satisfies DMC's **E2E-done** definition
(verified · reviewed · committed · pushed · closure-recorded) and reports **done / in-progress / blocked** with the
missing gates and current state (HEAD, origin sync, closure, verification, excluded-evidence). It **reports only** — it
never approves, stages, commits, pushes, grants a gate, makes a live call, or reads `.env*`/credentials.

## User Intent

tooling / process (a single read-only "is this milestone actually done?" check) — additive, doc + read-only script.

## 1. Problem statement

- The handbook defines E2E-done as five conjuncts (verified · reviewed · committed · pushed · closure-recorded), but
  whether a given milestone meets all five is judged ad-hoc each time. With pushes batch-deferred (current mode),
  several milestones sit at "committed but not pushed/closed" — easy to lose track of which gates remain.
- A read-only controller that, given a milestone, checks the five criteria and reports **done / in-progress / blocked**
  + the missing gates makes the E2E state auditable and supports the human Release Gate's batch-push decision.
- It must be a **pure reporter**: it determines and reports status; it never performs a gate (no push/commit/stage/
  approve), consistent with the handbook's "operating contract, not enforcement."

## 2. Non-goals

- **No act / no gate granting.** Never approves, stages, commits, pushes, or performs any gated action. Reports status.
- No product/adapter/router/schema/hook/validator/guard/`dmc-glm-smoke` change.
- No live provider call, no `.env*`/credential read, no network, no model-API/LLM call, no leaked-text handling.
- Not a substitute for the human Release Gate or Codex audit — an input that reports completion state.
- No mutation of the real repo beyond an optional operator-named `--out` report file (guarded; never `git add`ed).

## 3. Candidate design

### 3.1 `.harness/evidence/dmc-v0.3.0-e2e-completion.sh` (the controller)
- **Invocation:** `dmc-v0.3.0-e2e-completion.sh --milestone <id> [--commit <hash>] [--branch <b>] [--repo <dir>] [--out <file>]`
- **Checks the 5 E2E-done criteria (read-only). Each is `met | unmet | blocked`; "cannot evaluate" ⇒ `blocked`, NEVER a
  silent met/unmet — the controller fails closed about "done":**
  - **verified** — a `.harness/verification/dmc-<id>*.md` report exists AND records `Final Status: PASS`. No report →
    **blocked** (cannot evaluate).
  - **reviewed** — requires a **canonical, anchored review-verdict line** in the verification report — a dedicated
    line of the exact form `^Review-Verdict: critic=PASS codex=ACCEPT` (anchored at line start) AND the plan
    `Status: APPROVED`. A **loose** match is explicitly INSUFFICIENT and must NOT satisfy it: the pervasive worker-result
    **mock-test rows** (`… → ACCEPT`) and the self-reported plan-citation prose (`flipped after critic PASS`) are NOT
    authoritative verdicts. If the canonical anchored line is absent (e.g. a legacy report predating this convention) or
    not `critic=PASS codex=ACCEPT`, or the plan is not APPROVED → **blocked** (the machine cannot confirm review),
    never met. Going forward, verification reports MUST carry this canonical line; legacy reports without it report
    `reviewed=blocked` — the honest "cannot mechanically confirm" answer. (Report text is read as **inert data** —
    literal/anchored grep, never eval'd / never used to open a path.)
  - **committed** — an explicit `--commit <hash>` present in `git log` (read-only), OR an **unambiguous single** commit
    whose message matches the milestone. `--commit` absent-from-log, or a heuristic match that is **absent or non-unique
    (0 or >1 candidates)** → **blocked** (cannot confidently identify "the commit"). Only an explicit/unambiguous commit
    is `met`. **All commit-hash comparisons (here, pushed, closure) are by canonical FULL hash** — every token (the
    `--commit` arg, a git-log hit, an `origin/<branch>` tip, an abbreviated `MILESTONES.md` token like `963f25a`) is run
    through `git rev-parse` first, so a 7-char abbreviation matches a 40-char full hash.
  - **pushed** — **offline / no `git fetch`** (read-only): evaluated against the **locally-cached** `origin/<branch>`
    ref. Branch resolution: `--branch <b>` if given, else `origin/main` (matching the v0.2.6 `DMC_GATE_UPSTREAM` prior).
    **If `origin/<branch>` does not exist locally → `pushed = blocked`** (cannot evaluate; mirrors v0.2.6 G6
    "upstream not found"). If `committed` is `blocked` (no identified commit) → `pushed = blocked` too. Else
    `met` iff the committed criterion's commit is an **ancestor of** `origin/<branch>` (`git merge-base --is-ancestor`).
    The report states the caveat: *"pushed is judged against the last-fetched local origin ref, not the live remote."*
    Also reports HEAD vs origin ahead/behind/in_sync.
  - **closure-recorded** — a `docs/MILESTONES.md` entry references the milestone id **AND the specific commit hash**
    (canonical-full-hash compare, so an abbreviated `963f25a` token matches; an id-only match that points at a superseded
    commit does not satisfy it). If `docs/MILESTONES.md` is **absent/unreadable** → **blocked** (cannot evaluate),
    distinct from "present but no matching entry" (`unmet`). If `committed` is `blocked` (no identified commit) →
    `closure-recorded = blocked` too (cannot evaluate "the commit").
- **PUSHED definition — deliberate, documented refinement of the handbook:** the handbook's E2E-done criterion 4 reads
  `HEAD == origin/main`; this controller uses **per-commit ancestor-of-`origin/<branch>`** instead, because for a
  *per-milestone* check a closed milestone must stay "pushed" even when a later milestone adds unpushed commits (the
  real current state: HEAD ahead of origin). `docs/DMC_E2E_COMPLETION.md` states this is an intentional refinement and
  reports the HEAD-vs-origin ahead/behind alongside, so the handbook's whole-branch invariant is visible too.
- **Overall verdict (fail-closed precedence):** **`blocked`** if ANY criterion is `blocked` (cannot-evaluate dominates);
  else **`in-progress`** if all evaluable but ≥1 `unmet`; else **`done`** (all 5 `met`). The controller NEVER reports
  `done` while any criterion is blocked or unmet.
- **Reports:** overall `done | in-progress | blocked`, per-criterion `met/unmet/blocked` with the **missing/blocked
  gates**, current **HEAD**, **origin sync** (ahead/behind/in_sync), **latest milestone closure state**, **verification
  status**, and **excluded-evidence status** (the auto-logged evidence files are untracked, as expected).
- **Report-only semantics:** prints the report (text, or JSON to `--out`); exit code is informational (`0` done,
  `1` in-progress/blocked, `2` usage/refused) and must never be wired to perform a gate. The controller performs NO act.
- **`--out` write-target guard:** canonicalized; refuses (exit 2, writes nothing) if the path is a protected surface
  (full v0.2.6 `DEFAULT_PROTECTED` + `PROVIDER_CONTRACT.md`) or secret pattern — reuses the v0.2.8 guard pattern.
- **`--self-test`:** builds throwaway temp repos with synthetic milestones at each E2E state (none/committed-only/
  pushed/closed) and asserts the reported status (done/in-progress/blocked + missing gates) — the real repo index/tree
  is never touched (`mktemp` + `trap`, mirrors v0.2.6/v0.2.7).

### 3.2 `docs/DMC_E2E_COMPLETION.md` (the spec)
- Defines the 5 criteria, how each is evaluated (read-only, fail-closed: cannot-evaluate ⇒ blocked), the
  done/in-progress/blocked precedence, and the **report-only contract** (reports state, grants/performs no gate). States
  it is an input to the human Release Gate.
- **Reconciles `pushed` with the handbook explicitly:** documents that the controller uses per-commit
  **ancestor-of-`origin/<branch>`** as an *intentional, justified refinement* of the handbook's `HEAD == origin/main`
  (so a closed milestone stays pushed when later milestones add unpushed commits), evaluated **offline against the
  last-fetched local origin ref (no `git fetch`)** — with HEAD ahead/behind reported alongside so the whole-branch
  invariant stays visible. States the stale-ref caveat plainly.
- **Defines the canonical review-verdict line** `Review-Verdict: critic=PASS codex=ACCEPT` (anchored at line start) that
  verification reports MUST carry for `reviewed` to be machine-confirmable; legacy reports without it report
  `reviewed=blocked`. This v0.3.0 report itself carries the line (dogfood). **Defines canonical-full-hash comparison**
  (every hash token via `git rev-parse`) so abbreviated `MILESTONES.md` tokens match full git hashes.

### 3.3 `.harness/verification/dmc-v0.3.0-e2e-completion.md` (report)
- Records `--self-test` results, the report-only / no-mutation proof, and protected-file byte-unchanged.

## 4. File-level implementation scope

| Path | Change | Edit? |
|---|---|---|
| `docs/DMC_E2E_COMPLETION.md` | NEW — spec + report-only contract | yes (new) |
| `.harness/evidence/dmc-v0.3.0-e2e-completion.sh` | NEW — read-only controller (+ `--self-test`) | yes (new) |
| `.harness/verification/dmc-v0.3.0-e2e-completion.md` | NEW — report | yes (new) |
| adapters / `provider-router.py` / `ROUTING.md` / `WORKER_*_SCHEMA.md` / `.claude/hooks/*` / `dmc-glm-smoke` / product code | **NO change** | no |

## 5. Safety constraints

- **Report-only / read-only.** Issues only read git commands + reads verification/MILESTONES docs; never approves,
  stages, commits, pushes, or performs a gate. Exit code is informational, never an action trigger.
- **Real repo untouched.** Any staging in `--self-test` is temp-repo-only; `--out` writes one guarded operator-named
  file, never `git add`ed.
- **`--out` write-target guard** (canonicalized; refuses protected/secret incl. traversal/symlink; **canonicalization
  failure ⇒ refuse**; `--out` canonicalized to an absolute path **independent of `--repo`**) — reuses v0.2.8.
- **Offline / no `git fetch`.** All git is read-only AND offline — the `pushed` check uses the last-fetched local
  `origin/<branch>` ref; the controller never fetches/networks. Report-text marker greps are **inert data** (literal,
  never eval'd / never used to open a path).
- **No live / no `.env*` / no credentials / no network / no model-API.** None read or invoked.
- **No protected-surface change** — `git diff` over adapters/router/schemas/hooks/`dmc-glm-smoke` empty.
- **Auto-logged evidence excluded** — `.harness/evidence/dmc-v0.3.0-*` auto-log stays untracked/excluded, with priors.

## 6. Verification matrix (`--self-test`; read-only, temp-repo-only)

Self-test temp repos fabricate the origin ref deterministically via `git update-ref refs/remotes/origin/<branch>
<hash>` (no remote/network needed), so the `pushed` ancestor check is exercised in BOTH directions.

| # | Check | Assertion |
|---|---|---|
| E1 | none state | no verification report, no commit → verified=blocked → overall **blocked**; missing/blocked gates listed |
| E2 | committed, NOT pushed (current mode) | verified PASS + reviewed met + commit present, `origin/main` ref set to the commit's **parent** (commit NOT ancestor) → pushed=unmet, closure unmet → **in-progress**; missing = pushed, closure-recorded |
| E3 | pushed, no closure | `origin/main` ref `update-ref` to the commit (commit IS ancestor) → pushed=met; no MILESTONES entry → **in-progress**; missing = closure-recorded |
| E4 | fully done (real-data shapes) | all 5 met: report carries the canonical `Review-Verdict: critic=PASS codex=ACCEPT` line + plan APPROVED; closure entry uses a **7-char abbreviated** hash (mirrors real `MILESTONES.md`) matched via canonical-full-hash compare → **done**; missing = none |
| E5 | reports state fields | HEAD, origin ahead/behind/in_sync, closure state, verification status, excluded-evidence status all present |
| E6 | **unresolvable origin → pushed blocked** | temp repo with NO `origin/<branch>` ref → pushed=blocked → overall **blocked** (never silently in-progress/done) |
| E7 | **reviewed isolated** | verified+committed+closure met AND `origin/<branch>` `update-ref` to the commit so **pushed=met** (E3 setup), but the report lacks the canonical `Review-Verdict:` line / not `APPROVED` → reviewed=blocked → NOT done (overall blocked); missing/blocked = **reviewed only** |
| E10 | **reviewed loose-match → blocked** | a report containing ONLY worker-result mock rows (`… → ACCEPT`) and/or the prose `flipped after critic PASS` — but NO anchored `Review-Verdict: critic=PASS codex=ACCEPT` line → reviewed=**blocked** (loose/mock/prose never satisfies it), NOT met |
| E11 | **closure file absent → blocked** | `docs/MILESTONES.md` absent/unreadable → closure-recorded=blocked → overall **blocked** (distinct from present-but-no-entry → unmet/in-progress) |
| E12 | **hash abbrev↔full normalization** | closure entry uses a 7-char abbreviated hash while `--commit`/origin use the full 40-char hash → canonical `git rev-parse` compare → closure-recorded=**met** (committed/pushed unaffected); a genuinely-absent full hash still blocks (not masked by normalization) |
| E8 | **committed ambiguous → blocked** | `--commit` omitted with 0 or >1 message-matching commits → committed=blocked → pushed/closure cascade to blocked → overall **blocked** |
| E9 | **--commit not in log → blocked** | explicit `--commit <hash>` not present in `git log` → committed=blocked → overall **blocked** |
| M1 | controller mutates nothing | real `git status --porcelain` byte-identical before/after; `--out` writes only the named file, no `git add` |
| M2 | read-only / no act / no fetch / no live | static grep: only read-only git verbs (`log`/`merge-base`/`rev-parse`/`rev-list`/`status --porcelain`/`diff --name-only`/`update-ref` only inside self-test temp repos); NO `git add`/`commit`/`push`/`reset`/`apply`/**`fetch`** against a non-temp target; no `--live`/network/model-API/`.env` open; report-text greps are inert (literal, never eval'd) |
| M3 | `--out` guard (canonicalization-failure ⇒ refuse) | `--out .env` / `.claude/hooks/...` / traversal `x/../...` / symlink-to-protected / `PROVIDER_CONTRACT.md` → REFUSED (exit 2), target byte-unchanged; `--out` canonicalized to an absolute path independent of `--repo`; canonicalization failure ⇒ refuse |
| M4 | protected files byte-unchanged | `git diff --name-only` over adapters/router/`provider-router.py`/`ROUTING.md`/schemas/hooks/`dmc-glm-smoke`/**`PROVIDER_CONTRACT.md`** → empty |
| M5 | self-test own-cleanliness | after `--self-test`, real `git status --porcelain` byte-identical |

## 7. Regression risks

| Risk | Severity | Mitigation |
|---|---|---|
| Controller performs/grants a gate (push/commit) | high | Read-only git only; M2 grep (no act tokens against non-temp); exit code informational, never wired; self-test temp-only. |
| Reports "done" when not actually pushed/closed | high | Fail-closed precedence: cannot-evaluate ⇒ blocked, never done. "pushed" = per-commit ancestor of the **resolved** `origin/<branch>` (offline, last-fetched ref, **stale-ref caveat surfaced**); **unresolvable origin ref ⇒ pushed=blocked** (E6, mirrors v0.2.6 G6). "closure-recorded" = MILESTONES entry referencing the **commit hash**. E2/E3/E4 assert the ancestor check both directions via `update-ref`. |
| `reviewed`/`committed` over-report via marker/heuristic | high | "reviewed" requires **critic PASS + Codex ACCEPT + APPROVED** (verdict, not just markers) else blocked (E7); "committed" requires an **explicit/unambiguous** commit else blocked (E8/E9). Markers read as inert data. |
| `--out` clobbers a protected/secret file | high | Canonicalized write-target guard (reuses v0.2.8); M3 traversal/symlink test. |
| Mutates repo / self-test leaks | med | `mktemp`+`trap`; M1/M5 assert real tree unchanged. |
| Scope creep into enforcement/auto-push | low | §2/§4 report-only; no act; M4 byte-unchanged. |

## 8. Rollback plan

- **Pre-commit:** `git restore` / remove the new files. No code touched.
- **Post-commit:** `git revert <v0.3.0-commit-sha>` — additive doc + read-only script; clean revert.

## 9. Approval Status

Status: APPROVED
Approver: 대표님 (delegated semi-autonomous mode — flipped after 2-round adversarial critic PASS)
Approved At: 2026-06-21
