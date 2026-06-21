# Plan — dmc-v0.3.6 Review Packet Generator

Status: APPROVED
Approval Status: APPROVED
Mode: PLAN ONLY until APPROVED. **Additive, read-only** — reads git state + the verification report and modifies no
protected surface.

## Goal
A **read-only** generator that auto-produces a **review packet** for a milestone — a single human/external-review
artifact summarizing: the **staged/commit summary** (files + counts + subject), a **protected-surface scan**, a
**forbidden/secret-file scan (filename-only)**, a **verification summary** (Review-Verdict + PASS/FAIL + Final Status),
and **residual risks** (push-deferred state, protected touches, auto-log exclusions). It mechanizes the manual review
packs prepared by hand earlier. It **mutates nothing**, makes **no live call**, and — non-negotiable — **never reads or
prints the contents of any secret-bearing file, nor any free-form commit-message body**: scans inventory by **filename
only**.

## User Intent
v0.3.6 roadmap: "review pack 자동 생성 (staged/commit summary, protected/forbidden scan, verification summary, residual
risks)." Turn the hand-built review pack into a deterministic, read-only tool.

## Current Repo Findings
- The earlier review packs were assembled by hand (per-commit summary, forbidden/protected scans, verification summary).
- `git show --stat`/`--name-status`/`--name-only` and `git diff --cached --name-status`/`--stat`/`--numstat` print
  **filenames + line counts ONLY** (no file contents) — the safe summary primitives. **Content-dumping forms are
  FORBIDDEN in this tool**: a bare `git show <ref>` / `git diff` (no `--stat`/`--name-only`/`--name-status`), and the
  `-p`/`--patch` family (`git show -p`, `git log -p`, `git diff-tree -p`, `git format-patch`, `git cat-file`) all dump the
  diff body **including any secret file's contents**.
- **Commit-MESSAGE leak channel**: `git ... --format='%b'` (commit BODY) echoes arbitrary free-form text verbatim — a
  secret pasted into a commit message would leak. This tool uses **only `%H` (hash) + `%s` (subject)** and extracts the
  `Review-Verdict:` line by an **explicit single-line grep** — it **never** emits `%b`.
- `dmc-v0.2.6-gate-check-runner.sh:22-31` defines `DEFAULT_PROTECTED` — the DMC protected-PATH set (enumerated in §A3).
  v0.3.6 **reuses that PROTECTED-PATH set** and separately **inlines the CLAUDE.md secret-FILE pattern set** (§A4) — the
  two vocabularies are distinct (the gate runner's protected set is adapter/router/schema/hook paths, NOT the secret-file
  patterns).
- Verification-report conventions vary across the 23 reports: `N PASS / M FAIL` and `N/M` count forms; a `## Final
  Status` `**PASS**`/`**FAIL**` marker; and a `Review-Verdict: critic=… codex=…` line present in only the **7** v0.3.x
  reports (the 16 older v0.1.x/v0.2.x reports have a Final-Status block but **no** Review-Verdict line). The extractor must
  handle all three cases without crashing. (There is **no** `PASS=N FAIL=M` token anywhere — do not match it.)
- The repo CLAUDE.md secret-protection rule (v0.1.3): NEVER read/grep/print `.env*` (except `.example/.sample/.template`),
  private keys, credential/token files — inventory by **filename only**.

## Relevant Files (all additive)
- `docs/DMC_REVIEW_PACKET.md` — the review-packet spec (sections; the names-only/no-content secret rule incl. commit-body
  + verify-report-path channels; read-only).
- `.harness/evidence/dmc-v0.3.6-review-packet.sh` — the generator (+ `--self-test`).
- `.harness/verification/dmc-v0.3.6-review-packet.md` — verification report.
- `.harness/plans/dmc-v0.3.6-review-packet.md` — this plan.

## Out of Scope (with rationale)
- **No secret content access (any channel)** — the forbidden/protected scan classifies by **filename pattern ONLY**; the
  tool NEVER `cat`s/reads/greps-inside/echoes the body of a matched secret file. It uses ONLY the names-only git
  primitives above (never a content-dumping `git show`/`git diff`/`-p`/`log -p`/`cat-file`). It emits the commit **subject
  (`%s`)** and the grepped **`Review-Verdict:` line** but **never the commit body (`%b`)**. A `--verify-report` whose path
  matches the secret-pattern set is **refused unread**. A secret value (in a changeset file, a commit-message body, or a
  secret-pathed verify-report) must never appear in the packet.
- **No mutation / no gate** — read-only over git + the verification report; stages/commits/pushes/grants-a-gate nothing.
- **No live call / no network** — git-local + file reads only.
- **No protected/adapter/router/schema/hook/guard edit** — read-only over all of them.

## Proposed Changes
### A. `.harness/evidence/dmc-v0.3.6-review-packet.sh` (new; `--self-test`; `PYTHONDONTWRITEBYTECODE`)
CLI: `dmc-v0.3.6-review-packet.sh [--commit <ref>] [--staged] [--repo <dir>] [--verify-report <path>] [--out <file>]`
· `--self-test`. Default: `--commit HEAD`. Pipeline (read-only):
1. **Changeset (names-only git ONLY)** — `--staged` ⇒ `git -C <repo> diff --cached --name-status` (+ `--numstat`); else
   `--commit <ref>` ⇒ `git -C <repo> show --stat --name-status --format='%H%n%s' <ref>` (hash + subject + names + counts;
   **never** `%b`, **never** the diff body). The commit hash via `%H`, subject via `%s`.
2. **Summary** — file count + insertions/deletions (from `--numstat`/`--stat`), the commit hash + **subject (`%s`)**, and
   the `Review-Verdict:` line extracted by `git log -1 --format='%B' <ref> | grep -m1 '^Review-Verdict:'` — i.e. emit
   **only** the matched single line, never the surrounding body. (`%B` is consumed by grep and discarded; only the matched
   `Review-Verdict:` line is emitted.)
3. **Protected-surface scan** — which changed **paths** match the DMC protected-PATH set (names only): exactly the
   gate-check `DEFAULT_PROTECTED` 10 entries — `.claude/workers/providers/glm-api`, `.claude/workers/providers/oauth-cli`,
   `.claude/workers/providers/provider-router.py`, `.claude/workers/providers/ROUTING.md`,
   `.claude/workers/providers/PROVIDER_CONTRACT.md`, `.claude/hooks`, `WORKER_TASK_SCHEMA.md`, `WORKER_RESULT_SCHEMA.md`,
   `WORKER_REVIEW_SCHEMA.md`, `dmc-glm-smoke` → "protected surfaces touched (review-required)". Empty ⇒ "none".
4. **Forbidden/secret scan (filename-only)** — which changed **paths** match the CLAUDE.md secret patterns (`.env*` except
   `.example/.sample/.template`, `*.pem`, `*.key`, `id_rsa`, `id_ed25519`, `*.p12/.pfx/.keystore`, `credentials`
   (covers `credentials.json`), `.npmrc`, `.netrc`, `.pgpass`, `*service-account*`, `*secret*`, `.ssh/`,
   `.aws/credentials`) → "FORBIDDEN files present — STOP" (filename only; never contents). Empty ⇒ "none".
5. **Verification summary** — if `--verify-report` is given: first **guard its path** with the secret-pattern set — a
   secret-pattern path is **refused unread** ("verify-report path refused (secret-pattern); not read"). Else read the
   `.md` and extract, in three cases: (a) `Review-Verdict:` line present ⇒ emit it; (b) report present but no
   `Review-Verdict` ⇒ emit "Review-Verdict: not present"; plus the count line (`[0-9]+ PASS / [0-9]+ FAIL` or `[0-9]+/[0-9]+`)
   and the `## Final Status` `**PASS**`/`**FAIL**` marker; (c) no `--verify-report` ⇒ "no verification report provided".
   The packet states these are the report's **own self-attested claims** (advisory; not independently re-verified) and
   stamps the report's `## Run ID` if present.
6. **Residual risks** — push state via `git -C <repo> rev-list --count origin/main..HEAD` + `…HEAD..origin/main`
   (**integers only**; no `git log`/range-diff); protected surfaces touched (+ whether the verify report claims
   authorization); forbidden files present (if any ⇒ block); auto-log evidence left untracked.
7. **Emit** a markdown review packet (`--out` guarded, or stdout): the 5 sections + a header (milestone/ref) + a footer
   stating read-only/advisory/names-only. **Advisory exit codes**: `0` clean; `3` if a FORBIDDEN secret file is present in
   the changeset (distinct from `2` = usage/`--out`-refused). Even on the `3` path, the packet prints **only filenames**.

### B. `docs/DMC_REVIEW_PACKET.md`
The review-packet spec: the 5 sections; the **names-only / no-secret-content** rule across **all three channels** (file
contents, commit-message body `%b`, secret-pathed `--verify-report`); the names-only git discipline (allowed vs forbidden
git primitives); the read-only/advisory/grants-no-gate contract; the FORBIDDEN-present STOP behavior + advisory exit `3`;
a note that `credentials`/`*service-account*` intentionally widen the CLAUDE.md `*.json` forms (over-inclusive, safe).

## Acceptance Criteria (measurable; `--self-test`, offline only; a FIXED $TMPDIR temp git repo with pinned commits)
- **AC1 read-only (oracle sufficient for a git-READING tool)**: over the whole self-test, sample **pre==post** on BOTH
  the real repo AND the temp repo: `git rev-parse HEAD`, `git rev-parse --abbrev-ref HEAD`, `md5` of `git config --list`,
  AND `git status --porcelain` — all unchanged (catches a HEAD-move/branch-switch/config-write/index mutation, not just
  working-tree dirtiness). The tool stages/commits/pushes/mutates **nothing**.
- **AC2 secret-protection (names-only; THE critical invariant — 3 channels)**: in a temp git repo whose HEAD commit
  touches a `.env` containing a unique sentinel `S3CR3T_SENTINEL_<uuid>` AND whose commit-message **body** contains a
  distinct sentinel `MSGBODY_SENTINEL_<uuid>`: the packet **lists the `.env` filename** in the forbidden scan, but
  `grep -F` finds **neither** sentinel anywhere in the packet (captured **stdout** AND the `--out` artifact). A third run
  with `--verify-report` pointed at a secret-pattern path (a `.env` holding `VR_SENTINEL_<uuid>`) **refuses it unread** and
  the sentinel never appears. A **structural source audit** asserts the script's git changeset commands match ONLY
  `git (-C …)? show --stat|--name-status|--name-only|--format='%H%n%s'` / `git diff --cached --name-status|--name-only|--stat|--numstat`
  / `git log -1 --format='%B' … | grep` / `git rev-list --count` / `git rev-parse` / `git config --list`, and **FAIL** if
  any of `git show <ref>` (no --stat/--name-only/--name-status), `-p`/`--patch`, `git log -p`, `git diff-tree`,
  `git format-patch`, `git cat-file`, `--format=…%b`, or a `cat`/`<`-read of a matched secret path appears in the source.
  Additionally, the audit asserts any `--format='%B'` occurrence is **immediately consumed by `grep -m1 '^Review-Verdict:'`**
  (FAIL a `%B` piped to anything else — `grep -v`/`cat`/`head` — which could dump the full body).
- **AC3 packet correctness (fixture pinned)**: a temp-repo commit touching `src/app.js` (normal),
  `.claude/workers/providers/provider-router.py` (protected), and `.env` (secret): the **summary** contains all three
  filenames; the **protected scan** contains `provider-router.py` and NOT `src/app.js`; the **forbidden scan** contains
  `.env` + a STOP marker; **residual-risks** contains both the protected-touch line and the forbidden-block line.
  (Set-membership assertions — not full-output equality — since the temp commit hash varies.)
- **AC4 forbidden STOP (exit pinned)**: the forbidden-present run asserts exit `== 3` AND stdout contains
  `FORBIDDEN files present — STOP` AND a residual-risk block; a clean changeset (no secret file) asserts exit `== 0` AND
  the forbidden section `== none`.
- **AC5 verification summary (3 cases, real tokens)**: (i) a fixture report with a `Review-Verdict:` line + `N PASS / M FAIL`
  + `## Final Status **PASS**` ⇒ the packet extracts the verbatim Review-Verdict line, the count, and the Final-Status
  marker; (ii) a fixture report WITHOUT a `Review-Verdict` line ⇒ the packet emits "Review-Verdict: not present" + the
  count/Final-Status, no crash; (iii) no `--verify-report` ⇒ "no verification report provided", exit not a crash.
- **AC6 `--out` guard (pinned pairs)**: reuse the v0.3.5 hardened `out_refused`; assert a benign-resolving
  `$TT/sub/../benign.json` is **refused**, a protected/secret/symlink target is refused, and a plain `$TT/benign.json` is
  **allowed**.
- **AC7**: gate-check green (additive; no protected change); critic + Codex audit → ACCEPT before commit. (Process gate —
  not self-test-falsifiable.)

## Risks (+ mitigations)
- **R1 secret content leak (the gravest) — 3 channels** → AC2 closes all three: (1) file contents — names-only scan +
  `--stat`/`--name-status`-only git + no `cat` of a matched path; (2) commit-message body — `%b` is never emitted (only
  `%s` + the grepped `Review-Verdict:` line); (3) `--verify-report` path — refused unread if it matches a secret pattern.
  The structural audit FAILS on any content-dumping git primitive. Sentinels (file, message-body, verify-report) prove
  non-emission via `grep -F` over stdout AND `--out`.
- **R2 accidental mutation** → AC1's strengthened oracle (HEAD + branch + config + porcelain, both repos) — catches a
  HEAD-move/config-write a porcelain-only check would miss; the tool runs only read git primitives + file reads + a guarded
  `--out` write.
- **R3 false "clean"** → the forbidden/secret patterns mirror the CLAUDE.md list; a forbidden hit forces the STOP section
  + advisory exit `3` (no silent pass). The protected set is the exact gate-check `DEFAULT_PROTECTED` 10 entries.
- **R4 reading the verify report as a trust source** → the report is a non-secret `.md` (and a secret-pattern path is
  refused unread); the packet quotes its Review-Verdict/counts/Final-Status **verbatim** but labels them the report's own
  self-attested claims (advisory), stamping its Run ID for traceability.

## Assumptions
- A milestone is reviewed either as a commit (`--commit`) or a staged set (`--staged`) in a git repo (`--repo`).
- The self-test temp repo uses pinned author/committer dates (`GIT_AUTHOR_DATE`/`GIT_COMMITTER_DATE`) for stable commits;
  packet-content assertions use **set-membership**, not verbatim equality (the temp commit hash varies).

## Execution Tasks (after APPROVED)
1. Author `dmc-v0.3.6-review-packet.sh` (pipeline A1–A7; names-only git incl. no `%b`; filename-only secret scan;
   `--verify-report` secret-path guard; the 10 protected entries; 3-case verify extraction; advisory exit `3`; `--out`
   hardened guard; `--self-test` using a fixed temp git repo with file/commit-body/verify-report sentinels;
   PYTHONDONTWRITEBYTECODE).
2. Author `docs/DMC_REVIEW_PACKET.md` (change B).
3. Run `--self-test` → all PASS (esp. AC2 three-channel sentinel-never-emitted + names-only structural audit; AC1
   strengthened oracle); write the verification report; gate-check; critic; Codex audit; commit on ACCEPT; **no push**.

## Verification Commands
- `bash .harness/evidence/dmc-v0.3.6-review-packet.sh --self-test`
- a functional run `--commit HEAD --verify-report .harness/verification/dmc-v0.3.5-execution-manifest.md` to eyeball
- `git status --porcelain` (expect only additive untracked + excluded auto-log); gate-check runner; then Codex audit.

## Approval Status
**APPROVED (rev 2)** — round-1 3-critic panel returned **REVISE** ×3; all REQUIRED applied: (1) closed the **commit-body
`%b`** leak channel (only `%H`+`%s` + a grepped single-line `Review-Verdict:`); (2) **guard the `--verify-report` path**
(secret-pattern ⇒ refused unread); (3) AC2 now proves **three** sentinels (file/commit-body/verify-report-path) via
`grep -F` over stdout AND `--out`, with an enumerated forbidden-git-primitive audit (incl. the `%B`-must-be-grep-consumed
binding); (4) verify extraction uses the **real** tokens (`N PASS / M FAIL`, `N/M`, `## Final Status`), 3 cases; (5) the
**10 gate-check `DEFAULT_PROTECTED`** entries enumerated inline + AC3 pins `provider-router.py`; (6) AC1 oracle
strengthened (HEAD + branch + `config --list` + porcelain, both repos); (7) AC3/AC4/AC6 pinned (fixture/exit-3/benign-`..`).
**Round-2 focused re-pass: PASS/PASS** (zero remaining_required; the AC2 `%B`-binding hardening folded in; cosmetic
23/16 tally corrected). Next: `/dmc-start-work`. Additive/read-only; no provider-surface change.
