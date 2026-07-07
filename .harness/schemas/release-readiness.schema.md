# dmc.release-readiness.v1 — P18 release-readiness verdict (composed)

Emitted by `dmc gate release --full` (`bin/lib/dmc-release-gate.py`) into
`.harness/runs/<run-id>/release-readiness.json`. It is the ONE composed release verdict for a run:
nine sub-gate verdicts plus one overall verdict, produced by invoking the shipped, mirror-pinned
validators read-only as subprocesses and NORMALIZING each tool's exit into a per-sub-gate verdict —
never leaking a raw exit code. Fail-closed, value-blind, deterministic per input (no timestamps).

ADVISORY tier: this artifact INFORMS the human release gate (P17) and the release-auditor agent
(M5); it grants nothing. The runtime enforcement floor stays the hooks (Ring-0/1) and the scope
lock; `gate release` composes their outputs into a readiness summary, no stronger claim.

```json
{
  "schema": "dmc.release-readiness.v1",
  "run_id": "<the run this readiness verdict is for>",
  "plan_hash": "<the run.json plan_hash the verdict binds to>",
  "sub_gates": {
    "diff-scope":     {"verdict": "PASS|FAIL",                 "reasons": ["<RGATE-* code>"]},
    "gate-checks":    {"verdict": "PASS|FAIL",                 "reasons": ["<RGATE-* code>"]},
    "receipts":       {"verdict": "PASS|FAIL|MISSING",         "reasons": ["<RGATE-* code>"]},
    "findings":       {"verdict": "PASS|FAIL|MISSING",         "reasons": ["<RGATE-* code>"]},
    "goal":           {"verdict": "PASS|FAIL|MISSING",         "reasons": ["<RGATE-* code>"]},
    "decision":       {"verdict": "PASS|FAIL|MISSING",         "reasons": ["<RGATE-* code>"]},
    "approvals":      {"verdict": "PASS|FAIL|MISSING",         "reasons": ["<RGATE-* code>"]},
    "chain":          {"verdict": "PASS|FAIL",                 "reasons": ["<RGATE-* code>"]},
    "landmark-flag":  {"verdict": "PASS|FLAG",                 "reasons": ["<RGATE-* code>"]}
  },
  "flags": ["<landmark path flagged for human review>"],
  "verdict": "PASS|FAIL|PARTIAL"
}
```

## The nine sub-gates

Each sub-gate carries a `verdict` in `{PASS, FAIL, MISSING, FLAG}` (only the values shown per
sub-gate above are reachable) and a list of value-blind `RGATE-*` `reasons`. Per-sub-gate inputs are
RUN-DIR artifacts under `.harness/runs/<run-id>/`.

1. **diff-scope** (P7 ground truth). The new-changed-path set since arming
   (`git status --porcelain -uall` ∪ `git diff --name-only`, MINUS the arming `snapshot.txt`
   baseline) is adjudicated path-by-path by `dmc-scope-lock.py --adjudicate`. Any change outside the
   locked scope ⇒ FAIL listing the paths; else PASS.
2. **gate-checks** (v0.2.6). The advisory G1–G6 runner over a temp allowlist built from the scope
   lock's `files[].path`. exit 1 ⇒ FAIL with its G-rows in `reasons`; else PASS.
3. **receipts** (v0.6.2 semantics). Required check_ids (verify-plan.json `coverage[].resolved_by`,
   else acceptance.json `checks[].check_id`) must be receipt-covered, the ledger chain must validate
   (`--validate-ledger`), and every minted `receipts/*.json` must pass the v0.6.2 validator. No
   compiled check set ⇒ MISSING; any uncovered/invalid ⇒ FAIL; else PASS.
4. **findings** (v0.6.3). `findings.json` present ⇒ `findings-gate gate` (REFUSE ⇒ FAIL); absent ⇒
   MISSING.
5. **goal** (v0.6.4). `goal-ledger.json` present ⇒ `goal-ledger trace` (REFUSE ⇒ FAIL); absent ⇒
   MISSING.
6. **decision** (v0.6.5). `decision-record.json` present ⇒ `decision-trace answer` (the Q1–Q6 proof;
   REFUSE ⇒ FAIL); absent ⇒ MISSING.
7. **approvals** (P17 / CF2). `approvals.jsonl` present ⇒ `approvals --validate`, then the CF2
   resolution below; absent ⇒ MISSING.
8. **chain** (M7 — ACCOUNTABILITY / PROVENANCE tier). The delegation/apply-authorization chain,
   activity-scoped (below).
9. **landmark-flag** (P2). New changes intersected with the run's non-ordinary landmarks — a REVIEW
   flag, never a failure (below).

## Rules (composer-enforced, fail-closed)

- **Overall verdict.** `FAIL` if ANY sub-gate is FAIL; else `PARTIAL` if ANY sub-gate is MISSING;
  else `PASS`. A `FLAG` never degrades the verdict. **PARTIAL is NEVER presented as PASS** (P18 Rec:
  "FAIL lists gaps; PARTIAL never presented as PASS") — a missing input is an honest gap, not a pass.
- **Exit map.** `dmc gate release --full` exits `0` on overall PASS, `1` on overall FAIL or PARTIAL
  (the gate ran; readiness not met), `2` on usage, and `3` on a structural REFUSE (unreadable/tampered
  run state, unknown run, or an unsafe/existing `--out` — no readiness JSON is emitted in that case).
- **Sub-gate exit normalization.** The composed tools use two exit conventions (legacy gates `0`
  PASS / `1` FAIL; M4–M7 modules `0` PASS / `3` REFUSE). Each sub-gate captures its tool's exit and
  maps it to a per-sub-gate verdict here; a raw exit code is NEVER surfaced.
- **diff-scope honest tier (names-only).** The verdict is at the PATH-NAME tier — it proves the
  changed *path set* is in scope, not the changed *content*. The worktree ground truth has a
  disclosed blind spot: changes COMMITTED before the gate runs vanish from the worktree set (run.json
  records no base commit sha), so a `--base <sha>` escape hatch UNIONs `git diff --name-only
  <sha>..HEAD` into the changed set when the caller knows the base. Without `--base`,
  committed-then-gated changes are invisible (disclosed limitation). The run's own evidence
  (`.harness/evidence/`, `.harness/verification/`) and append-only run logs (`.harness/runs/`) are
  exempt from adjudication (they are not scope-locked working files) — mirroring
  `bin/lib/dmc-postbash-diff.py`.
- **Baseline integrity (sealed trust).** Before diff-scope runs, run.json's sealed state is validated
  (`dmc-run-lifecycle --validate`) and only a valid seal makes its `operative_snapshot` pins trusted;
  a run.json seal failure, or a `snapshot.txt` that does not recompute against the run.json
  `snapshot_sha256` pin, POISONS the baseline and is a structural REFUSE (exit 3) — the untrusted
  baseline is never diffed (mirror of `dmc-postbash-diff.py` layer-B).
- **gate-checks staged-input precondition (Rev 2/A1).** v0.2.6 G2 (allowlist fully staged) is
  cached-diff semantics: run the full gate with the release candidate STAGED (`git add` of exactly
  the scope lock's `files[].path`) — this matches the real closure flow, where `gate release`
  precedes the human commit gate on a staged tree. An unstaged tree is an honest gate-checks FAIL,
  not a composer bug.
- **CF2 verification_ref resolution (approvals).** For EVERY `release` / `push` / `waiver` approval
  record, `verification_ref` MUST resolve to a safe, repo-relative, non-secret, EXISTING file that
  passes `dmc validate verification` (exit 0); else the sub-gate FAILs with
  `RGATE-VERIFICATION-REF-UNRESOLVED`. `dmc-approvals.py` enforces `verification_ref` PRESENCE only;
  ref→artifact resolution is enforced HERE (closes carry-forward #2 — CF2 gets teeth at release).
- **chain activity predicate (ACCOUNTABILITY / PROVENANCE tier, Rev 2/A2).** Worker-apply activity =
  `delegations.jsonl` exists OR any `.harness/workers/authorizations/*.json` whose `run_id` equals
  this run. With NO activity ⇒ PASS with a note (historical runs stay green — the schema rule refuses
  runs WHOSE APPLIED CHANGES lack a chain, not runs without worker applies). With activity ⇒ `dmc
  delegation check` must PASS AND every run-bound authorization must `dmc worker apply-check` PASS
  (task/result/review resolved from `.harness/workers/{tasks,results,reviews}/<task_id>.json`; a
  missing member or WAUTH-* refusal ⇒ FAIL). This sub-gate is ACCOUNTABILITY/PROVENANCE, not
  tamper-detection: `delegations.jsonl` and `authorizations/*.json` live under the run-dir append-log
  exemption of the Ring-0/1 basename denials, so a deleted chain + deleted authorization yields
  PASS-with-note. The mutation-detection floor remains diff-scope + the Ring-1 postbash detector; the
  chain sub-gate proves provenance WHERE it exists and blocks unchained applies WHERE activity is
  recorded — no stronger claim.
- **FLAG is review, not failure (landmark-flag).** A new change touching a non-ordinary landmark
  (the run's `dmc.landmarks.v1` `landmarks.json`, else regenerated via `dmc-repo-intel landmarks`)
  yields verdict FLAG and adds the paths to top-level `flags`. FLAG is a REVIEW cue for the human
  gate — the paths were already scope-locked / landmark-authorized at compile, so FLAG NEVER fails
  the gate by itself.
- **Write-once output.** `release-readiness.json` is written once per gate run; a second write to an
  existing path is REFUSED (exit 3, `RGATE-OUTPUT-EXISTS`) unless `--out -` (stdout). Canonical JSON
  (sorted keys), no timestamps ⇒ byte-deterministic per input. `--out` is path-safety guarded.
- **M10 checklist extension point.** `docs/DMC_V1_RELEASE_CHECKLIST.md` is a reserved optional input
  consumed from M10 onward; its ABSENCE does NOT produce a MISSING sub-gate in v1.0-M9 (M9 leaves the
  extension point only; M10 validates consumption via its own `dmc gate release --full` PASS
  acceptance).

Negative controls the composer must handle: a tampered run.json or forged `snapshot.txt` ⇒ structural
REFUSE exit 3 (never diffed); an out-of-scope new change ⇒ diff-scope FAIL; an uncovered required
check ⇒ receipts FAIL; a blocked finding ⇒ findings FAIL; a completion without an approved goal ⇒
goal FAIL; an unresolved decision link ⇒ decision FAIL; a release approval whose `verification_ref`
does not resolve to a VALID artifact ⇒ approvals FAIL; recorded apply activity with a broken chain or
a missing authorization ⇒ chain FAIL; a missing input ⇒ MISSING sub-gate ⇒ overall PARTIAL (never
PASS); a landmark-touching change ⇒ FLAG without failing the verdict.

Consumers: the human release gate (P17) and `.claude/agents/release-auditor.md` (M5), which consumes
`release-readiness.json`. Extends `.harness/schemas/scope-lock.schema.md` (the write floor),
`.harness/schemas/delegation.schema.md` + `.harness/schemas/apply-authorization.schema.md` (the chain
sub-gate), and the v0.6.2–v0.6.5 evidence/findings/goal/decision validators.
