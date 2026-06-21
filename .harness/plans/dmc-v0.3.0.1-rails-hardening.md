# Plan — dmc-v0.3.0.1 Rails Consistency Hardening

Status: APPROVED
Approval Status: APPROVED
Approved: 2026-06-21 — delegated semi-autonomous mode; authorized by human ("Codex 확인받고 계속 진행") after critic panel 3-round PASS + Codex confirmation review ACCEPT (thread 019ee893). Independent approval (critic panel + Codex), not self-approval.
Revision: 4 (round-3 panel airtight-ness fixes; Codex confirmation review: + F4f for DMC_RUN_MANIFEST.md:26 → F4 now 6 sites)

## Goal
Fix the design-intent divergences the Codex holistic deep re-review (thread 019ee893…) found across the v0.2.6–v0.3.0
operating rails — across **every** tool exhibiting each defect class — **before** v0.3.1 and **before** the batch-push, so
published history is already consistent. Patch milestone; new fix commits only (no history rewrite).

## User Intent
The human asked Codex to deeply re-review v0.2.6→now for anything implemented contrary to design intent. Codex returned
REVISE with four divergences (independently verified). Two adversarial critic-panel rounds then proved F4 is a *class*
defect across **five** enumerations (not one) and tightened the acceptance criteria to be CLI-driven and falsifiable.
Intent: bring the read-only rail tools into mutual consistency with the `--out` guard, fail-closed, and protected-surface
invariants the milestone set already claims to uphold.

## Current Repo Findings (verified, file:line)
1. **F1 — v0.2.7 `--out` unguarded (Critical).** `dmc-v0.2.7-run-manifest.sh:131` writes `generate … > "$OUT"` with no
   protected/secret/traversal/symlink guard, unlike v0.2.8/v0.3.0 which call `out_refused()`.
2. **F2 — v0.3.0 `--out` guarded but never written (Major).** `dmc-v0.3.0-e2e-completion.sh:179-181`: `out_refused "$OUT"`
   validates the target, then `emit` writes to **stdout**; `$OUT` is never written. The committed spec/report assert a write
   that does not happen.
3. **F3 — v0.2.6 `--gate` fail-open (Major).** `dmc-v0.2.6-gate-check-runner.sh:137` accepts any `--gate`; only exact
   `push` (`:70`,`:73`) activates push-behind strictness. (DMC_GATE_CHECKS.md:13,20 already documents `stage|commit|push`.)
4. **F4 — PROVIDER_CONTRACT.md missing from protected-set enumerations (Major, CLASS across 6 sites):**
   - **F4a** `dmc-v0.2.6-gate-check-runner.sh:22-30` `DEFAULT_PROTECTED` omits it → G4 won't flag staging it.
   - **F4b** `dmc-v0.2.7-run-manifest.sh:20-28` `DEFAULT_PROTECTED` omits it → single-sources the manifest `protected_paths`
     (`:48`→`:64`) so the manifest under-reports.
   - **F4c** `dmc-v0.2.9-effort-provider-policy.sh:56` H4 `git diff --name-only --` arg list omits it → H4 can't flag a change.
   - **F4d (doc)** `docs/DMC_GATE_CHECKS.md:44-46` prose protected list omits it.
   - **F4e** `dmc-v0.2.8-task-intake-classifier.sh:43` advisory `PROT_PATHS` *label* omits it → emitted `protected_paths`
     (text `:92`, JSON `:99/:106`) under-reports. NOTE: the v0.2.8 *matcher* (`:42`, includes `provider_contract`) and its
     `out_refused` PROT_RE (`:116`) already cover it — only the emitted enumeration label is stale. (v0.3.0 PROT_RE also already lists it.)
   - **F4f (doc)** `docs/DMC_RUN_MANIFEST.md:26` — the `protected_paths[]` field's Notes gloss (`adapters/router/schemas/
     hooks/dmc-glm-smoke`) omits it. (Codex confirmation review flagged this as the 6th site; resolved by adding it to the gloss.)

## Relevant Files
- `.harness/evidence/dmc-v0.2.6-gate-check-runner.sh` — F3, F4a, + ST_PRE guard, self-test.
- `.harness/evidence/dmc-v0.2.7-run-manifest.sh` — F1, F4b, + ST_PRE guard, self-test.
- `.harness/evidence/dmc-v0.2.8-task-intake-classifier.sh` — F4e, self-test.
- `.harness/evidence/dmc-v0.2.9-effort-provider-policy.sh` — F4c.
- `.harness/evidence/dmc-v0.3.0-e2e-completion.sh` — F2, self-test.
- `docs/DMC_GATE_CHECKS.md` — F3 (`--gate` enum) + F4d (prose protected list).
- `docs/DMC_RUN_MANIFEST.md` — F4f (protected_paths Notes gloss) + `--out` guard note.

## Out of Scope (with rationale)
- **`.harness/` not in `--out` PROT_RE.** By-design: rail tools legitimately emit reports under `.harness/`. No change.
- **Input-file secret refusal for `--allowlist`/`--plan`.** Defense-in-depth only; operator-chosen paths, structure-grep
  only, v0.2.7 R6 self-test asserts no secret shapes leak, `secret-guard.sh` covers Read-level. Deferred (anti-token-max).
- **v0.2.7 `--push-state` and v0.3.0 `--branch` are NOT F3-class** (panel-confirmed): `--push-state` is a descriptive
  recorder with no enforcement branch; a typo'd `--branch` fails **closed** (v0.3.0:55). No enum needed.
- **No temp-repo self-test harness added to v0.2.9.** v0.2.9 is by-design a flat structure-check (no `--self-test`, no
  mktemp); F4c is a one-line declarative arg-list addition, so it is verified **structurally** (AC-F4c), not behaviorally —
  building a `--repo` seam + harness purely to behaviorally exercise one arg would be scope creep (anti-token-max).
- **`docs/DMC_EFFORT_PROVIDER_POLICY.md:9-10` left as-is.** It is a behavioral "edits no code / are untouched" prose claim
  using category words (adapters, schemas, hooks, guards), **not** a protected-set enumeration; F4c's byte-unchanged-arglist
  addition does not falsify it. (Both the critic panel and the Codex confirmation review judged this optional/non-enum.)
- **No edit to PROVIDER_CONTRACT.md or any provider surface** — F4 only *references* it in protected lists/labels.

## Proposed Changes
- **F4a/F4b:** add `.claude/workers/providers/PROVIDER_CONTRACT.md` to v0.2.6 and v0.2.7 `DEFAULT_PROTECTED`.
- **F4c:** append it to the v0.2.9 H4 `git diff --name-only --` arg list (`:56`).
- **F4d:** add it to the `docs/DMC_GATE_CHECKS.md` prose protected list.
- **F4e:** add `PROVIDER_CONTRACT.md` to the v0.2.8 `PROT_PATHS` advisory label (`:43`) so emitted `protected_paths` matches.
- **F4f:** add `PROVIDER_CONTRACT.md` to the `docs/DMC_RUN_MANIFEST.md:26` `protected_paths[]` Notes gloss.
- **F3:** insert immediately after arg-parse (after `:141`) and **before the `--allowlist` required-guard at `:147`**
  (so the enum is the first exit-2 source), `case "$GATE" in stage|commit|push) ;; *)
  echo "gate-check: --gate must be stage|commit|push" >&2; exit 2;; esac`. Document the enum in DMC_GATE_CHECKS.md.
- **F1:** port the **entire** v0.2.8 `out_refused()`+`PROT_RE` body **verbatim** (incl. `dirname`/`basename`/`cd … pwd -P`
  canonicalization-failure⇒refuse **and** the `[ -L ] … readlink -f … || return 0` symlink re-check — not just PROT_RE) into
  v0.2.7; call it before the `> "$OUT"` write at `:131`; refuse exit 2 (write nothing). Document the guard in DMC_RUN_MANIFEST.md.
- **F2:** conditional split, **not** a bare redirect: `if [ -n "$OUT" ]; then emit > "$OUT"; echo "e2e: wrote $OUT" >&2;
  else emit; fi`; preserve `[ "$OVERALL" = done ]; exit $?`.
- **ST_PRE guards:** add a real-repo `git -C "$ROOTDIR" status --porcelain | md5` before/after guard to the v0.2.6 and
  v0.2.7 self-tests (mirroring v0.3.0:162/176), since both now gain CLI-invoking self-test cases.

## Acceptance Criteria (CLI-driven & gate-attributed where behavioral; structural where declarative — all falsifiable)
- **AC-F3a (enum reject, CLI, first exit-2 source):** via the CLI entrypoint and **passing a valid `--allowlist`** (so the
  enum is the sole exit-2 cause), `--gate bogus`, `--gate ""`, `--gate " "` each ⇒ exit 2; the enum check is placed before
  the `:147` allowlist guard. Driven through the binary (the existing self-test calls `run_checks()` directly and bypasses it).
- **AC-F3b (positive control, CLI):** each of `--gate stage|commit|push` does **not** exit 2 (not a blanket reject).
- **AC-F4a (G4-attributed):** temp repo on a **non-push gate** (`commit`) stages `.claude/workers/providers/
  PROVIDER_CONTRACT.md` **and** lists that exact path in the allowlist (so G1/G2/G3/G5/G6 PASS); assert the run FAILs **and**
  captured stdout contains `G4 FAIL` (so reverting F4a flips it green→fail-attributed).
- **AC-F4b:** v0.2.7 manifest output `protected_paths` contains the full path `.claude/workers/providers/PROVIDER_CONTRACT.md`.
- **AC-F4e:** v0.2.8 self-test — a `provider_contract`-matching task's emitted `protected_paths` (text + JSON) contains
  `PROVIDER_CONTRACT.md` (v0.2.8 has a real self-test harness, so this is behavioral).
- **AC-F4f (structural):** `docs/DMC_RUN_MANIFEST.md:26` `protected_paths[]` Notes gloss contains `PROVIDER_CONTRACT.md`
  (grep of source as a milestone verification command; reverting F4f fails it).
- **AC-F4c (structural, falsifiable):** the v0.2.9 H4 arg-list line (`:56`) contains `.claude/workers/providers/
  PROVIDER_CONTRACT.md` (grep of source as a milestone verification command; reverting F4c fails it). Documented as
  structural because v0.2.9 has no temp-repo harness by design.
- **AC-F1 (CLI, no-write-on-refusal):** via CLI, `--out <protected/secret/traversal/symlink target>` ⇒ exit 2 **and the
  target does not exist / is unchanged** afterward (assert non-existence, since `> "$OUT"` could otherwise truncate on
  mis-ordering); benign `--out $TT/benign.json` (path free of PROT_RE substrings) ⇒ writes valid JSON.
- **AC-F2 (CLI, byte-equality, same repo state):** in one fixed temp repo, run with `--out FILE` and once without (stdout
  captured); assert FILE exists and is **byte-equal** to the stdout capture (comparison is **stdout-only** — the
  `wrote $OUT` notice is routed to stderr); negative: protected `--out` ⇒ exit 2 **and FILE not created**.
- **AC4 (real repo untouched):** all new self-test cases run strictly within each script's `mktemp -d` sandbox using temp
  repos + temp `--out` paths; v0.2.6/v0.2.7/v0.3.0 carry an ST_PRE md5 before/after guard; v0.2.9 gains no CLI-invoking
  case (structural grep only). Milestone-level: real-repo `git status --porcelain` byte-identical after every `--self-test`.
- **AC5 (provider surface byte-unchanged):** adapters, provider-router.py, ROUTING.md, WORKER_*_SCHEMA.md, .claude/hooks/*,
  dmc-glm-smoke, **PROVIDER_CONTRACT.md** byte-unchanged (F4 only references the last).
- **AC6:** gate-check runner green on the staged set; Codex re-audit ACCEPT.

## Risks
- R1: editing committed-but-unpushed milestone scripts (v0.2.6/7/8/9 + v0.3.0). Mitigation: new fix commits, **no** history
  rewrite; full self-tests re-run; Codex re-audit before commit.
- R2: F2 newly activates a pre-existing, tolerated TOCTOU window between `out_refused` and the write (same as v0.2.8's
  model). Accepted; not in scope to close.
- R3: a non-faithful F1 port could silently become fail-open (dropping a `|| return 0`). Mitigation: AC-F1 exercises
  protected/secret/**traversal/symlink** cases (mirrors v0.2.8:175-178).
- R4: F4c is verified structurally, not behaviorally. Mitigation: the grep is falsifiable against revert; v0.2.9's own
  milestone verification already exercises H4 behavior against the real repo.

## Assumptions
- Valid gate vocabulary is `stage|commit|push` — **confirmed** against `docs/DMC_GATE_CHECKS.md:13,20`.
- The canonical guard to port lives in `dmc-v0.2.8-task-intake-classifier.sh:116-128`.

## Execution Tasks
1. v0.2.6: F4a + F3 (CLI enum, placed before gate_report) + ST_PRE guard; add AC-F3a/AC-F3b/AC-F4a self-test cases (CLI-driven, grep `G4 FAIL`).
2. v0.2.7: F1 (verbatim `out_refused()` port + guard the `--out` write) + F4b + ST_PRE guard; add AC-F1 (CLI, no-write-on-refusal) + AC-F4b cases.
3. v0.2.8: F4e (PROT_PATHS label); add AC-F4e self-test case (emitted protected_paths contains PROVIDER_CONTRACT.md).
4. v0.2.9: F4c (H4 arg list) — structural verification only.
5. v0.3.0: F2 (conditional `emit > "$OUT"`); add AC-F2 (CLI, byte-equality, same temp repo) case.
6. Docs: F3 enum + F4d prose in DMC_GATE_CHECKS.md; F4f (protected_paths Notes gloss) + `--out` guard note in DMC_RUN_MANIFEST.md.
7. Run all four `--self-test`s + the v0.2.9 structural grep; confirm real repo byte-identical; write
   `.harness/verification/dmc-v0.3.0.1-rails-hardening.md` with the canonical `Review-Verdict:` line.

## Verification Commands
- `bash .harness/evidence/dmc-v0.2.6-gate-check-runner.sh --self-test`
- `bash .harness/evidence/dmc-v0.2.7-run-manifest.sh --self-test`
- `bash .harness/evidence/dmc-v0.2.8-task-intake-classifier.sh --self-test`
- `bash .harness/evidence/dmc-v0.3.0-e2e-completion.sh --self-test`
- `grep -n 'diff --name-only' .harness/evidence/dmc-v0.2.9-effort-provider-policy.sh | grep PROVIDER_CONTRACT.md` (F4c structural check, anchored to the H4 `git -C "$ROOT" diff --name-only` arg-list)
- `grep -n 'PROVIDER_CONTRACT.md' docs/DMC_RUN_MANIFEST.md` (F4f structural check)
- `git status --porcelain` (expect: only in-scope files changed; provider surface clean)
- gate-check runner on the staged set; then Codex Independent Release Audit.
