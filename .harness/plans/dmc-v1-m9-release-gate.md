# Plan: DMC v1 M9 — Release Gate Composition + CI + E2E Dry Run (P18 full)

Plan ID: dmc-v1-m9-release-gate · Date: 2026-07-07 · Format: PLAN_SCHEMA.md
Milestone-scoped plan for master plan §M9 (tasks DMC-T014 + DMC-T015,
`.harness/plans/dmc-v1-runtime-upgrade.md` L335-344; Rev 3 execution order
M6→M6.5→M8→M7→M9→M10 — M7 shipped first, so M9 composes M7's chain verbs as designed).

Risk: low (master §M9 header) — additive rollback; NOT a protected surface (light critic
rotation per handoff rev 7 §Next step). M9 is doubly load-bearing: (a) under Option A the
pre-commit/CI gate IS the Codex enforcement boundary (documented-only today — this milestone
builds it real); (b) the M7 apply-authorization chain is skill-mandated at apply time — this
milestone makes chain-absence BLOCKING at release.

Task numbering: sub-numbered `DMC-T014.1..3` + `DMC-T015.1..2` under master tasks
DMC-T014/DMC-T015. `grep -rn "DMC-T014\|DMC-T015" .harness/ docs/` returned exactly 4 hits,
all definitional/pointer (master L336/L339, handoff L228/L237) — dot-sub namespace is CLEAN
(verified 2026-07-07; carry-forward #8 pattern).

**Rev 2** — revised after DMC critic r1 NEEDS_CLARIFICATION (persisted at
`.harness/evidence/dmc-v1-m9-critic-verdict-r1.json`; bound plan_hash `9331d9fc…1d68`,
repo_hash `a318468…`). Surgical amendments only. Blocker closed:
(B1) CI step 7's "no `dangerously-bypass-hook-trust` anywhere" would be permanently red
(the lexeme legitimately appears in ~20 tracked files: adapters/codex/README.md:59,
.codex/config.toml:14, docs/CODEX_ADAPTER.md, evidence/plans) — the step is now pinned to
the M8 :507 AUTHORITATIVE scope and lexeme set: grep over `.claude/install` +
`bin/lib/dmc-doctor.py` ONLY, with the FULL M8 lexeme list
(`nc|netcat|curl|wget|urllib|http.client|socket|requests|smtplib|ftplib|api.|CODEX_API_KEY|
GLM_API_KEY|dangerously-bypass-hook-trust`), not the prose subset, not repo-wide.
Advisories folded: (A1) the green path STAGES exactly scope.lock `files[].path` (`git add`)
in the fixture repo before `gate release --full` — v0.2.6 G2 requires a staged allowlist;
pinned in both fixture scripts and in the readiness schema's gate-checks precondition note;
(A2) release-readiness.schema.md explicitly labels the chain sub-gate
ACCOUNTABILITY/PROVENANCE tier (delegations.jsonl/authorizations are run-dir append-log
exempt from the Ring-0/1 basename denials; the mutation-detection floor is diff-scope +
Ring-1 postbash — no stronger claim);
(A3) the v0.6.5 composer invocation is pinned to the REAL filename
`bin/lib/dmc-v0.6.5-decision-trace.py` (the prose alias "decision-traceability" names the
tool family, not the path);
(A4) the fixtures' `dmc-evidence-ledger.py mint` calls are pinned to
`--evidence-type` ∈ the five-type set (green path uses `verification-report` /
`test-result`) with a resolvable `--verification-ref`, so the receipts sub-gate's v0.6.2
validation passes by construction.

## Goal

Compose the existing validators into ONE release verdict (`dmc gate release --full`, P18
full tier) writing `.harness/runs/<run-id>/release-readiness.json` with a PASS/FAIL/MISSING
verdict per sub-gate and an overall PASS/FAIL/PARTIAL verdict (PARTIAL never presented as
PASS); make the M7 apply-authorization/delegation chain BLOCKING at release; resolve
approval `verification_ref` → artifact (carry-forward #2); ship the greenfield
`.github/workflows/dmc-ci.yml` running the full self-test surface against the pinned
baseline (the real Codex enforcement boundary under Option A); and prove the WHOLE v1 loop
end-to-end on a committed host-shaped fixture (orient→landmarks→plan→critic→approve→run
start→execute with one denied attempt per canonical-five class→receipts→fix-loop→suspend/
resume→release gate→human-gate record), with the <2s quick-tier latency budget measured —
all while keeping the legacy aggregate 802/3/3 EXACT and every existing section 0 FAIL.

## User Intent

Continue the approved dmc-v1-runtime-upgrade in the Rev 3 order: M9 is the next unstarted,
UNAPPROVED milestone (handoff rev 7 §Next step; master §Approval Status "M9/M10 remain
UNAPPROVED"). The user gates milestone approval, staging, commit, and push; workers
implement; a non-authoring critic reviews this plan before any edit; an independent verifier
validates the build before closure.

## Current Repo Findings

All findings re-verified live this session (2026-07-07, HEAD `a318468`, clean tree):

- **The five composable gate tools all have real (non-self-test) modes and are
  mirror-pinned** (bin/lib ↔ `.harness/evidence` byte-equality, 55-file `dmc mirror-check`;
  master risk row L158) — M9 must NOT edit them; it composes them from a NEW module:
  - v0.2.6 `dmc-v0.2.6-gate-check-runner.sh --allowlist F [--repo D] [--gate stage|commit|push]`
    — G1-G6 over REAL git state (staged⊆allowlist, allowlist staged, excluded-evidence,
    protected paths, whitespace, upstream); exit 0/1/2; ADVISORY by design (header: exit
    "must never be wired to stage/commit/push/block"). bash-only ⇒ CLI composition.
  - v0.6.2 evidence-receipt (`validate|gate`, exit 0 valid / 1 invalid / 2 usage) — receipt
    shape (BIND work_id/plan_hash/repo_hash/verification_ref; 5 EVIDENCE_TYPES; E1-E10).
  - v0.6.3 findings-gate (`--validate|--gate|--append-check|--release`, 0 ALLOW/1 REFUSE/2)
    — F1-F10; `--release` = anti-bypass (append-check ∧ gate).
  - v0.6.4 goal-ledger (`--validate|--transition|--append-check|--trace|--authorize`) —
    G1-G8; `--authorize` = anti-bypass.
  - v0.6.5 decision-traceability (`--validate|--answer`) — D1-D8; `--answer` emits the
    Q1-Q6 six-question proof from the record alone.
  Exit-code wrinkle: legacy gates use 0/1/2 while M4-M7 modules use 0/3/2 — the composing
  module must map both (design pinned below).
- **P18 contract** (docs/DMC_V1_RUNTIME_ARCHITECTURE.md:320-333): compose diff⊆scope (P7
  ground truth) · receipt coverage (v0.6.2) · findings (v0.6.3) · goal linkage (v0.6.4) ·
  decision trace (v0.6.5) · gate checks (v0.2.6) · landmark diff review flag (P2); Out =
  `runs/<run>/release-readiness.json` PASS/FAIL per sub-gate; FM: quick tier state-file-only
  <2s, full tier for closure; Rec: "FAIL lists gaps; PARTIAL never presented as PASS".
  The M5 release-auditor contract already binds the output name: `.claude/agents/
  release-auditor.md:21` consumes `release-readiness.json`.
- **Naming**: `gate` is NOT a bin/dmc verb; "release" appears nowhere in bin/dmc — zero
  collisions. linkcheck auto-derives verbs from top-level case arms; `dmc gate release`
  resolves as verb `gate` (VERB_RE takes the first token). Architecture :326 names
  `dmc gate release --quick` for the Ring-1 Stop adapter, but M6 shipped the stop path on
  `dmc stop-gate quick` (stop-verify-gate.sh:90) and the M6 hook surface is FROZEN — naming
  tension resolved below (alias tier, hook untouched).
- **diff⊆scope ground truth available today**: run.json records NO base commit sha
  (repo_hash = sha256 of `git status --porcelain`, NOT a sha); the integrity-proven baseline
  is snapshot.txt (arming-time changed-path set) bound by run.json
  `operative_snapshot.snapshot_sha256` under the sealed state_hash — exactly
  dmc-postbash-diff's "new_changes" semantics; per-path verdicts via
  `dmc-scope-lock.py --adjudicate LOCK PATH OP` (0 allow / 3 refuse). Known honest gap:
  changes COMMITTED before the gate runs vanish from the worktree set (no recorded base
  sha) — disclosed tier + an optional `--base <sha>` escape hatch (design below).
- **Chain-blocking predicate needed**: all 6 existing run dirs contain NO delegations.jsonl
  and `.harness/workers/authorizations/` is empty — an UNCONDITIONAL chain requirement
  would refuse every historical run. delegation.schema.md:46-47 phrases the rule
  conditionally ("a run whose applied changes lack an import/delegation chain is refused").
  `dmc delegation check --run RID` REFUSES on a missing file (DELEG-NO-CHAIN, never
  vacuous); `dmc worker apply-check` REFUSES a missing authorization (WAUTH-MISSING-AUTH).
- **CF2 (verification_ref)**: `bin/lib/dmc-approvals.py` — POST_VERIFICATION_KINDS
  {release, push, waiver} MUST carry non-empty `verification_ref`, "presence-only —
  ref->artifact resolution is enforced by the M9 release gate, not here" (:17-19, :290-293).
  Resolution target shape: repo-relative path; the canonical artifact family is
  `.harness/verification/*.md` validating via `dmc validate verification` (exit 0).
- **CF13d (delegation schema disclosure)**: `.harness/schemas/delegation.schema.md` has NO
  serialization statement; the actual chain rule (dmc-delegation.py:421-438, :479-481) =
  prev_hash over the stored line's exact bytes LF-EXCLUDED, stored lines serialized
  compact-canonical `json.dumps(sort_keys=True, separators=(",",":"), ensure_ascii=False)`.
  The file is EDITABLE: one commit ever (M3), NOT in the 3-schema mirror set
  (plan/run/verification only), not hook-protected; it IS landmark class=contract ⇒ needs an
  explicit allow-row (granted below). Second gap in the same file: the validator-named
  `scope_lock_ref` field is absent from the illustrative JSON.
- **CI reality**: `.github/` does NOT exist (greenfield); remote =
  github.com/wjlee930501/Do-Me-Coding. `git merge-base --is-ancestor 2999870… HEAD` ⇒ the
  m6 restore/rollback fixtures need the FULL history: **actions/checkout `fetch-depth: 0`
  is REQUIRED** (default depth-1 lacks the pinned object and m6-suite fails). All suites
  are offline (headers assert no network; repo-wide grep clean — the only curl string is a
  redaction-test literal). Portability verified: bash 3.2-compatible, dual-pathed sha256,
  portable mktemp, self-set git identities ("a bare CI host needs no ambient
  user.name/email"), python ≥3.7 floor. Measured locally: `--all` ≈275s (legacy block
  ~200s), m6-suite 21.6s, m8-suite 23.3s, m65-suite 10.7s, m7-suite 6.2s — one
  ubuntu-latest job with a 20-min timeout suffices. Carry-forward #7: `--all` must run on a
  PRISTINE checkout (working-tree-drift legacy checks) — CI is exactly that.
- **CF3 (model-name grep)**: the invariant is "model names live ONLY in
  orchestration/models.json (display-only)". Today's carriers: models.json (sanctioned),
  and `bin/lib/dmc-roles.py` at TWO lines (:73 MODEL_NAME_RE detector, :394 seeded
  negative-control tokens) — whole-file exemption is more robust than the M8 plan's
  line-number exclusions (they rot on edit). `.claude/agents/*.md` are all
  `model: inherit` (zero hits); roles.json/harness-matrix.json clean.
- **Option A boundary, concretely**: adapters/codex/README:18-25 "The enforcement boundary
  on Codex hosts is the pre-commit/CI gate"; the machine-checkable assertions already
  exist (m65-suite shim-parity 65 rows; doctor Codex-honesty greps in doctor/m8-suite;
  forbidden-lexeme/network greps from the M8 plan :507 incl.
  `dangerously-bypass-hook-trust`) — all inside `selftest --all` except the release greps,
  which become explicit CI steps.
- **E2E substrate**: `tests/fixtures/host-node` does NOT exist (master names it) — today
  there is `tests/fixtures/node/` (a depsurface fixture, not a host tree) and the M8
  runtime builder `build_host_node` (mktemp). The proven full-loop template is
  `tests/fixtures/m6/test-e2e-ultrawork.sh` (copy_surface of bin/.claude/orchestration/
  .harness/schemas + root schema docs into a mktemp repo; real `dmc run start` arming;
  drives the actual stop hook) — but it covers the stop path only. The denied-attempt rows
  to mirror exist per class: (1) m6 c1a bash out-of-scope deny, (2) c2a scope.lock
  self-edit deny, (3) c3a secret-glob deny, (4) m7 class-4 JWT result REJECT, (5) m7
  class-5 rename-diff REJECT. Receipts/fix-loop CLIs exist but are NOT bin/dmc-dispatched:
  `bin/lib/dmc-acceptance.py compile`, `bin/lib/dmc-verify-plan.py compile`,
  `bin/lib/dmc-evidence-ledger.py mint|coverage` (check_id-required),
  `bin/lib/dmc-fixloop.py append` (cross-run attempt counter), `bin/lib/dmc-approvals.py
  append` (gate kinds). `dmc delegation append` and `worker authorize` default-out resolve
  paths from the TOOL's location ⇒ the E2E must use the copied-surface pattern and/or pass
  `--out` explicitly.
- **Quick-tier latency precedent**: dmc-stop-gate.py budget "<2s" (docstring), self-test C8
  asserts elapsed <2.0s, m6 test-compat latency row measured 0.06s. The <2s budget binds
  the Stop-path quick tier only; the full tier has NO stated budget (closure-time).
- **M10 boundary**: docs/DMC_V1_RELEASE_CHECKLIST.md does not exist and is an M10
  deliverable "consumed by the release gate" — M9's gate must NOT require it (M10 validates
  consumption via its own "`dmc gate release --full` PASS" acceptance). M9 leaves an
  extension point only.
- **Suite home**: tests/fixtures/m9/, `run_m9_suite`, section `m9-suite` — all free (grep
  zero hits). New bin/lib module + new schema file ⇒ INSTALL_MANIFEST regen (+2 auto-listed
  lines) + m8-suite drift re-run, the SAME obligation M7 discharged.

## Relevant Files

| Path | Reason | Allowed to Edit |
|---|---|---|
| bin/lib/dmc-release-gate.py (NEW) | P18 full-tier composer + --quick alias + --self-test | yes (T014.1 — SOLE owner) |
| .harness/schemas/release-readiness.schema.md (NEW) | dmc.release-readiness.v1 contract | yes (T014.1) |
| .harness/schemas/delegation.schema.md | CF13d serialization-disclosure line + scope_lock_ref illustration (contract-class landmark — explicitly authorized HERE) | yes (T014.1 — surgical, two additions only) |
| bin/dmc | `gate)` verb arm, release-gate + m9-suite selftest sections, M9SUITEDIR + run_m9_suite, usage() | yes (T014.2 — SOLE bin/dmc owner) |
| .github/workflows/dmc-ci.yml (NEW) | the CI gate (Option A enforcement boundary) | yes (T014.3 — SOLE owner; master row L82) |
| tests/fixtures/host-node/** (NEW, static) | committed host-shaped fixture the E2E copies into mktemp (master-named path) | yes (T015.1) |
| tests/fixtures/m9/** (NEW: _m9common.sh, test-release-gate.sh, test-e2e-loop.sh) | M9 suite: gate seeded-gap rows + full-loop E2E + latency | yes (T015.1 — SOLE owner) |
| INSTALL_MANIFEST.md | regen-only via --emit-manifest after the two new ship-surface files | yes (T015.2) |
| .harness/evidence/dmc-v1-m9-*.md, .harness/verification/dmc-v1-m9-release-gate.md | evidence + verification report | yes (T015.2) |
| .harness/plans/dmc-v1-m9-release-gate.md (this file), .harness/plans/dmc-v1-runtime-upgrade.md §Approval Status | revisions + approval records only | yes (orchestrator lane, gate-driven) |
| bin/lib/dmc-v0.2.6-gate-check-runner.sh, dmc-v0.6.{2,3,4,5}-*.{sh,py} (+ .harness/evidence originals) | mirror-pinned legacy tools — composed, never edited | no |
| .claude/hooks/** + .claude/settings.json | M6 hook surface FROZEN (stop hook stays on `stop-gate quick`) | no |
| bin/lib/dmc-run-lifecycle.py, dmc-scope-lock.py, dmc-stop-gate.py, dmc-evidence-ledger.py, dmc-fixloop.py, dmc-acceptance.py, dmc-verify-plan.py, dmc-approvals.py, dmc-delegation.py, dmc-worker-review.py, dmc-repo-intel.py | consumed read-only/subprocess by the composer + E2E — not edited | no |
| .claude/workers/providers/** | never edited (master L92) | no |
| .claude/install/**, bin/lib/dmc-doctor.py | M8 surface; manifest REGEN reads the installer, never edits it | no |
| docs/DMC_V1_RELEASE_CHECKLIST.md | M10 deliverable — NOT created here | no |
| tests/fixtures/{m6,m6.5,m7,m8,hooks-v0.6.5,node,run,orchestration,empty,python}/** | other milestones' fixtures | no |

## Out of Scope

- Editing the five composed legacy tools or ANY bin/lib mirror-pinned copy (mirror-check
  55-file byte-equality stands).
- The M6 hook surface: `stop-verify-gate.sh` KEEPS calling `dmc stop-gate quick`; M9 does
  NOT rewire the Ring-1 Stop adapter to `gate release --quick` (that would touch the frozen
  hook). The architecture's `--quick` naming is satisfied by an alias tier (below).
- Adding a base-commit field to run.json / editing the M4 run-lifecycle core — the
  committed-diff blindness of the worktree ground truth is DISCLOSED, with the `--base`
  flag as the caller-supplied escape hatch. (Recording HEAD at arming is a candidate M10/
  hygiene item, not M9.)
- docs/DMC_V1_RELEASE_CHECKLIST.md creation/consumption (M10); docs identity refresh (M10);
  the M10 enforcement matrix (M9's honest-tier statements are INPUTS to it).
- Git server-side/pre-commit hook installation (the CI workflow IS the boundary; local
  `.git/hooks` remain untouched — sample-only today, disclosed).
- Provider adapters/router; installer/uninstaller/doctor code; root WORKER_* schemas.
- Fixing the 3 pinned legacy FAILs (carry-forward #1) — the CI baseline comparison expects
  EXACTLY 802/3/3, never "fixes" them.
- The v0.2-verify credential-grep hardening and the authorizations-dir host-.gitignore
  follow-up (carry-forward #13 b/e) — M10/hygiene candidates, not blocking here.

## Proposed Changes

### 1. NEW `bin/lib/dmc-release-gate.py` (T014.1) — the P18 composer

House conventions (M7 dmc-worker-review.py precedent): stdlib-only, env-independent,
offline, value-blind reason codes (`RGATE-*`), duplicate-key-rejecting JSON, secret-shaped
path refusal, `sys.dont_write_bytecode = True` before any importlib, hermetic `--self-test`
printing `[release-gate] N PASS / M FAIL`.

**CLI**: `release --full --run-id RID [--root DIR] [--base SHA] [--out FILE]` ·
`release --quick [--run-id RID | --run DIR | --root DIR] [--report FILE]` · `--self-test`.
Exit codes (pinned): 0 = overall PASS · 1 = overall FAIL or PARTIAL (gate ran; readiness
not met) · 2 = usage · 3 = REFUSED (structural: unreadable/tampered inputs, unknown run).
The 0/1-vs-3 split maps the two legacy conventions: sub-gate tool exits are captured and
normalized into per-sub-gate verdicts, never leaked raw.

**`--quick` (alias tier — resolves the architecture naming without touching M6)**:
delegates to the SAME logic as `dmc stop-gate quick` by subprocess
(`python3 bin/lib/dmc-stop-gate.py quick …`, translating exit 0→PASS/0 and 4→FAIL/1).
The Ring-1 Stop hook KEEPS calling `stop-gate quick`; `gate release --quick` is the
architecture-named front door for callers/CI. Disclosed as an alias, not a reimplementation
(no drift risk). Budget <2s inherited and re-measured in the E2E.

**`--full` sub-gates** (each yields `{verdict: PASS|FAIL|MISSING|FLAG, reasons[]}` in
`release-readiness.json`; per-sub-gate inputs are RUN-DIR artifacts):

1. `diff-scope` — new_changes = (current `git status --porcelain -uall` ∪
   `git diff --name-only`) MINUS the snapshot.txt baseline, ONLY after run.json's sealed
   state validates AND `operative_snapshot.snapshot_sha256` recomputes over snapshot.txt
   (tamper ⇒ RGATE structural REFUSE exit 3, postbash-diff layer-B semantics); each
   new_change adjudicated via `dmc-scope-lock.py --adjudicate LOCK PATH edit` subprocess —
   any refusal ⇒ FAIL listing the paths. With `--base SHA`: `git diff --name-only SHA..HEAD`
   is UNIONED into the changed set (closes the committed-diff blindness when the caller
   knows the base). Honest tier pinned in the schema: names-only; without `--base`,
   committed-then-gated changes are invisible (disclosed limitation).
2. `gate-checks` (v0.2.6) — materialize a temp allowlist from scope.lock `files[].path`,
   run `dmc-v0.2.6-gate-check-runner.sh --allowlist F --repo ROOT --gate commit`;
   exit 1 ⇒ FAIL with its G-row output captured as reasons; ADVISORY nature preserved (the
   composed verdict is itself advisory to the human release gate, C11 intact).
   PRECONDITION (Rev 2/A1): v0.2.6 G2 requires the allowlist paths STAGED — the release
   candidate must be `git add`ed before the full gate runs. The green-path fixtures stage
   exactly scope.lock `files[].path` before invoking `gate release --full`; the readiness
   schema documents "run the full gate with the release candidate staged" as the
   gate-checks input contract (matching the real closure flow, where the gate precedes the
   human commit gate on a staged tree).
3. `receipts` (v0.6.2 semantics) — required check_ids from the run's verify-plan.json
   `coverage[].resolved_by` (else acceptance.json `checks[].check_id`; NEITHER compiled ⇒
   MISSING); each checked via `dmc-evidence-ledger.py coverage` subprocess; ledger
   integrity via `--validate-ledger`; ADDITIONALLY every minted receipt file under
   `receipts/` must pass `dmc-v0.6.2-evidence-receipt.py validate` (direct v0.2.6-style
   composition of the legacy validator). Any uncovered/invalid ⇒ FAIL.
4. `findings` (v0.6.3) — input `runs/<rid>/findings.json` ({subject, findings[]} snapshot):
   present ⇒ `dmc-v0.6.3-findings-gate.py gate` (stdin), REFUSE ⇒ FAIL; absent ⇒ MISSING.
5. `goal` (v0.6.4) — input `runs/<rid>/goal-ledger.json` ({ledger, completion}):
   present ⇒ `trace` (and `authorize` when prev/next provided), REFUSE ⇒ FAIL; absent ⇒
   MISSING.
6. `decision` (v0.6.5) — input `runs/<rid>/decision-record.json`: present ⇒ `answer`
   (Q1-Q6 from the record alone), REFUSE ⇒ FAIL; absent ⇒ MISSING. Composer invokes the
   REAL filename `bin/lib/dmc-v0.6.5-decision-trace.py` (Rev 2/A3 — the prose alias
   "decision-traceability" names the tool family, not the path).
7. `approvals` (CF2 — the NEW resolution check) — `dmc-approvals.py --validate` over
   approvals.jsonl (absent ⇒ MISSING); then for EVERY release/push/waiver record:
   `verification_ref` must resolve to an existing repo-relative file (traversal/secret-
   shaped refused) that passes `dmc validate verification` (subprocess, exit 0) ⇒ else FAIL
   (`RGATE-VERIFICATION-REF-UNRESOLVED`). This closes carry-forward #2.
8. `chain` (M7 — the BLOCKING predicate) — activity-scoped, matching the schema's
   conditional phrasing: worker-apply activity = (delegations.jsonl exists) OR (any
   `.harness/workers/authorizations/*.json` whose `run_id == RID`). If NO activity ⇒ PASS
   with reason "no delegated/worker applies recorded" (historical runs stay green — the
   rule refuses runs WHOSE APPLIED CHANGES lack a chain, not runs without worker applies).
   If activity: `dmc delegation check --run RID` must PASS (DELEG-NO-CHAIN/CHAIN-BREAK ⇒
   FAIL), AND for each run-bound authorization, `dmc worker apply-check --auth A --task T
   --result R --review REV --scope-lock LOCK` must PASS (task/result/review resolved from
   `.harness/workers/{tasks,results,reviews}/<task_id>.json`; any missing member or
   WAUTH-* refusal ⇒ FAIL). Chain-absence is now BLOCKING at release exactly where the M7
   honest-tier statement promised.
9. `landmark-flag` (P2) — intersect new_changes (sub-gate 1's set) with the run's
   landmarks.json `landmarks[].path` (fallback: regenerate via
   `dmc-repo-intel.py landmarks --root ROOT`); any non-ordinary hit ⇒ verdict FLAG listing
   the paths. FLAG is a REVIEW flag for the human gate — it does NOT fail the gate by
   itself (the paths were already scope-locked/landmark-authorized at compile; pinned
   semantics per P2/P18 "landmark diff review flag").

**Overall verdict**: FAIL if any sub-gate FAILs; else PARTIAL if any sub-gate is MISSING;
else PASS (FLAG never degrades the verdict; it is carried in the output). "FAIL lists gaps;
PARTIAL never presented as PASS" (P18 Rec) — exit 1 for both FAIL and PARTIAL.

**Output**: `.harness/runs/<rid>/release-readiness.json` (or `--out`) —
`{"schema": "dmc.release-readiness.v1", "run_id", "plan_hash", "sub_gates": {...9 named
sub-gates...}, "flags": [...], "verdict": "PASS|FAIL|PARTIAL"}` — deterministic per input
(no timestamps), canonical-JSON, refuses overwrite of an existing readiness file unless
`--out -` (stdout). Write target confined to the run dir / explicit --out with the house
path-safety guard.

**M10 extension point** (one line, no behavior): a reserved optional input
`docs/DMC_V1_RELEASE_CHECKLIST.md` is named in the schema as "consumed from M10 onward;
absent input does NOT produce a MISSING sub-gate in v1.0-M9".

### 2. NEW `.harness/schemas/release-readiness.schema.md` (T014.1)

`dmc.release-readiness.v1` in the house prose+fenced-JSON+Rules shape: the 9 sub-gate
names, verdict enums (sub-gate PASS|FAIL|MISSING|FLAG; overall PASS|FAIL|PARTIAL), the
PARTIAL-never-PASS rule, the chain-activity predicate, the diff-scope honest tier
(names-only; --base escape hatch; committed-diff blindness), the CF2 resolution rule, the
FLAG-is-review-not-failure rule, exit-code mapping, the gate-checks staged-input
precondition (Rev 2/A1), and the M10 checklist extension point. The chain sub-gate is
explicitly labeled ACCOUNTABILITY/PROVENANCE tier (Rev 2/A2): delegations.jsonl and
authorizations/*.json fall under the run-dir append-log exemption of the Ring-0/1 basename
denials, so a deleted chain + deleted authorization yields PASS-with-note — the
mutation-detection floor remains diff-scope + Ring-1 postbash; the chain sub-gate proves
provenance where it exists and blocks unchained applies where activity is recorded, no
stronger claim. Consumer note: `.claude/agents/release-auditor.md` (M5) + the human
release gate (P17).

### 3. `.harness/schemas/delegation.schema.md` — CF13d additions (T014.1, surgical)

Two additions ONLY: (a) one disclosure line under the chain rule: stored lines are
serialized compact-canonical (`sort_keys=True`, separators `(",",":")`, UTF-8,
`ensure_ascii=False`) and `prev_hash` is computed over the stored line's exact bytes with
the terminating LF EXCLUDED — an external chain author must reproduce that serialization,
not hash their submitted bytes; (b) `"scope_lock_ref": "<path | run-default>"` added to the
illustrative JSON block (the validator has required it for `may_mutate: true` since M5 —
the illustration catches up; validator behavior unchanged).

### 4. `bin/dmc` registration (T014.2 — single owner)

`RGATELIB="$HERE/lib/dmc-release-gate.py"` near the other lib vars; new top-level `gate)`
arm with nested `release)` sub-verb (`exec python3 "$RGATELIB" release "$@"`; unknown/absent
sub-verb ⇒ usage exit 2); `M9SUITEDIR="$HERE/../tests/fixtures/m9"` + guarded
`run_m9_suite()` (loop `test-release-gate.sh test-e2e-loop.sh`; missing script ⇒ rc=1);
selftest sections `release-gate` (`python3 "$RGATELIB" --self-test`) + `m9-suite`
registered in BOTH the `--all` block and the named-target block (no-arg default stays
frozen at 9 sections / 75/0); usage() gains the gate verb, both sections, and the
`--full/--quick` flag summary. linkcheck picks up `gate` automatically.

### 5. NEW `.github/workflows/dmc-ci.yml` (T014.3) — the Option A boundary, real

One `ubuntu-latest` job (`timeout-minutes: 25`), `on: [push, workflow_dispatch]`,
`actions/checkout@v4` with **`fetch-depth: 0`** (the m6 restore/rollback fixtures read the
pinned pre-M6 commit `2999870…` via `git show` — depth-1 breaks them). Steps, each named
and fail-fast:
1. `bash -n` floor over `.claude/hooks/*.sh adapters/codex/*.sh tests/fixtures/m*/**.sh
   bin/lib/*.sh` (master Verification Commands row).
2. `git status --porcelain` PRE-sandwich (must be empty — pristine checkout).
3. `bin/dmc mirror-check` (55-file byte-equality — master risk row L158 "in CI").
4. `bin/dmc doctor` (host self-check on the repo itself).
5. `bin/dmc selftest --all` — EXACT pinned baseline 802/3/3 via the built-in comparator
   (carry-forward #1: the 3 FAILs are human-accepted; never masked) + every section 0 FAIL
   + `SELFTEST-ALL RESULT: PASS` (exit 0 is the assertion). This transitively runs the
   adversarial suites (m6/m7), the install suite (m8), the Codex shim-parity suite (m65),
   doctor negcontrols, and the NEW release-gate + m9-suite sections.
6. Model-name grep (CF3, pinned scoping): `grep -RInE
   'claude-(opus|sonnet|haiku|fable|mythos)|gpt-[0-9]|codex-[0-9]' bin adapters
   .claude/install orchestration .claude/agents --exclude=models.json
   --exclude=dmc-roles.py` ⇒ MUST be empty (whole-file exemptions for the sanctioned home
   and the detector-carrying module — more robust than line numbers, disclosed).
7. Forbidden-lexeme/network greps — pinned to the M8 :507 AUTHORITATIVE scope and set
   (Rev 2/B1): `grep -RInE 'nc |netcat|curl|wget|urllib|http\.client|socket|requests|
   smtplib|ftplib|api\.|CODEX_API_KEY|GLM_API_KEY|dangerously-bypass-hook-trust'` over
   `.claude/install/` + `bin/lib/dmc-doctor.py` ONLY ⇒ MUST be empty. NOT repo-wide: the
   bypass lexeme legitimately appears in ~20 tracked files (adapters/codex/README, .codex/
   config.toml, docs/CODEX_ADAPTER.md, evidence/plans — all FORBIDDING or documenting it);
   scoping to the install/doctor surface is what M8 verified and what keeps CI green while
   still guarding the shipped enforcement-class code.
8. Codex wiring presence: `.codex/config.toml` + the `.codex/.dmc-created` sentinel exist
   and are tracked (trust state is per-user and NOT assertable in CI — disclosed in a
   workflow comment; this is the honest extent of "the CI gate IS the Codex boundary").
9. `git status --porcelain` POST-sandwich (suites left the checkout byte-identical).
Workflow comments carry the Option A boundary statement verbatim (advisory shims; CI =
enforcement boundary; no parity claim).

### 6. `tests/fixtures/host-node/` (T015.1) — the master-named static fixture

Committed minimal node-host shape (mirrors m8 `build_host_node`): `package.json`
(host-app), `README.md`, `.gitignore` (node_modules/dist), `src/index.js` (+ one extra
src file so the E2E's benign edit and rename rows have material). The E2E NEVER arms this
directory in place — it copies it into a mktemp repo (m6 copy_surface precedent), so the
committed fixture stays byte-frozen (porcelain guard proves it).

### 7. `tests/fixtures/m9/` suite (T015.1)

`_m9common.sh` (m6/m7/m8 helper conventions: sourced-only, repo-root resolution,
record/assert_eq, porcelain before/after guard, mktemp + trap cleanup, copy_surface of
bin/.claude/orchestration/.harness/schemas + root schema docs + tests/fixtures/host-node
overlay, self-set git identity, NO network, NEVER reads secrets) + two scripts:

- **`test-release-gate.sh`** — arms a disposable host-node-shaped repo (real
  `run start` → scope-lock compile), materializes the FULL green path (acceptance +
  verify-plan compiled; receipts minted per check_id with `--evidence-type` ∈ the
  five-type set — green path uses `verification-report`/`test-result` — and a resolvable
  `--verification-ref`, Rev 2/A4; findings.json with a closure-clean snapshot;
  goal-ledger.json with an approved→completed trace; decision-record.json that `answer`s
  Q1-Q6; approvals.jsonl with plan_approval + a release approval whose verification_ref
  resolves to a VALID verification report; a worker chain: task→result→review→authorize
  (with --out into the fixture) + delegations.jsonl appended; then `git add` of exactly
  scope.lock `files[].path` — the staged-input precondition, Rev 2/A1) → `dmc gate
  release --full` ⇒ PASS exit 0, release-readiness.json validates, all 9 sub-gates PASS
  (landmark FLAG empty). THEN the SEEDED-GAP rows (master acceptance: "seeded-gap fixtures
  each FAIL their sub-gate"), each on a fresh copy: (g1) out-of-scope new_change ⇒
  diff-scope FAIL naming the path; (g2) staged excluded-evidence / protected path ⇒
  gate-checks FAIL; (g3) one uncovered check_id ⇒ receipts FAIL; (g4) an open finding ⇒
  findings FAIL; (g5) completion without approved goal ⇒ goal FAIL; (g6) unresolvable
  decision link ⇒ decision FAIL; (g7) release approval with verification_ref → nonexistent
  file ⇒ approvals FAIL (CF2 has teeth); (g8) worker-apply activity with a tampered
  delegations line ⇒ chain FAIL, AND authorization deleted ⇒ chain FAIL
  (WAUTH-MISSING-AUTH — "apply without a chain refused" at release); (g9) new_change
  touching an enforcement-class landmark ⇒ FLAG fires (and verdict stays PASS — flag ≠
  fail, pinned); (g10) MISSING tier: findings.json removed ⇒ verdict PARTIAL exit 1
  (PARTIAL never PASS); (g11) tampered run.json/snapshot ⇒ structural REFUSE exit 3;
  (g12) no-worker-activity run ⇒ chain PASS-with-note (the predicate row). Plus
  `--quick` alias rows: covered run ⇒ exit 0; uncovered ⇒ exit 1; latency measured <2s.
- **`test-e2e-loop.sh`** — the master-mandated FULL loop on the copied surface:
  orient (--root) → landmarks (--out into fixture) → plan written (m6 writer shape,
  Status: APPROVED) → synthetic critic verdict (schema-valid APPROVE bound to the plan
  sha256; C11 note) → `dmc verdict gate --plan-hash` PASS → `dmc run start` → scope-lock
  compile → EXECUTE: one benign in-scope edit; then ONE DENIED ATTEMPT PER CANONICAL-FIVE
  CLASS (mirror rows: c1a bash out-of-scope deny via pre-tool-guard; c2a scope.lock
  self-edit deny via scope-guard; c3a secret-glob deny via secret-guard; class-4 JWT
  worker-result REJECT; class-5 rename-diff-to-forbidden REJECT) — every deny asserted
  value-blind → acceptance/verify-plan compile → receipts minted → ONE fixloop append
  (attempt 1 ≤ bound) → `dmc run suspend` → stop-gate quick ⇒ PASS (suspended) →
  `dmc run resume` → verification report written (validates) + approvals release record
  (receipts minted with five-type-set evidence_type, Rev 2/A4) → `git add` of the scoped
  paths (staged-input precondition, Rev 2/A1) →
  `dmc gate release --full` ⇒ PASS → human-gate record = the release approval in
  approvals.jsonl (asserted present + validated) → LATENCY rows: `dmc stop-gate quick`
  <2s AND `dmc gate release --quick` <2s (timed, values recorded) → suite prints
  `RESULT: N PASS / 0 FAIL`; real repo porcelain-unchanged throughout.

### 8. Manifest re-proof + evidence (T015.2)

`--emit-manifest` regen (python-heredoc capture; expect EXACTLY +2 auto-listed lines:
`dmc-release-gate.py`, `release-readiness.schema.md`) → commit-time drift re-run
(`selftest m8-suite` 126/0). Evidence `.harness/evidence/dmc-v1-m9-build-<date>.md` +
verification report `.harness/verification/dmc-v1-m9-release-gate.md` (passes
`dmc validate verification`). CI proof: after the human commit/push gate, the workflow run
on the branch must be GREEN — recorded by run URL + conclusion in the evidence (the one
acceptance criterion that can only be proven post-push; sequencing disclosed below).

## Acceptance Criteria

- Criterion: `dmc gate release --full` on a fully-materialized green run ⇒ verdict PASS,
  exit 0, release-readiness.json conforms to dmc.release-readiness.v1 with all 9 sub-gates
  PASS.
  Verification Method: `bash tests/fixtures/m9/test-release-gate.sh` green-path rows PASS,
  exit 0.
- Criterion: every seeded gap FAILS ITS OWN sub-gate (g1-g8), the landmark flag FIRES
  without failing the verdict (g9), a MISSING input yields PARTIAL exit 1 never PASS (g10),
  tampered run state is a structural REFUSE exit 3 (g11), and a no-worker-activity run
  passes the chain sub-gate with the disclosed note (g12).
  Verification Method: same script, seeded-gap rows g1-g12 all PASS, exit 0.
- Criterion: chain-absence is BLOCKING at release — worker-apply activity with a missing
  authorization or broken delegations chain FAILS the chain sub-gate (the M7 honest-tier
  promise realized).
  Verification Method: same script, g8 rows (WAUTH-MISSING-AUTH + DELEG-CHAIN-BREAK
  surfaced in reasons), exit 0.
- Criterion: CF2 — a release/push/waiver approval whose verification_ref does not resolve
  to an existing `dmc validate verification`-VALID artifact FAILS the approvals sub-gate;
  a resolving ref PASSes.
  Verification Method: same script, g7 + green-path approvals rows, exit 0.
- Criterion: the FULL v1 loop completes on the host-node fixture with one denied attempt
  per canonical-five class (all five value-blind denials asserted), receipts, one fix-loop
  attempt, suspend/resume, release gate PASS, and a human-gate record; the real repo is
  byte-unchanged.
  Verification Method: `bash tests/fixtures/m9/test-e2e-loop.sh` ⇒ `RESULT: N PASS /
  0 FAIL`, exit 0; porcelain guard row green.
- Criterion: latency budget — `dmc stop-gate quick` AND `dmc gate release --quick` both
  measured <2s on the fixture (values recorded in evidence).
  Verification Method: latency rows in test-e2e-loop.sh PASS, exit 0.
- Criterion: `--quick` is a faithful alias (same verdict as stop-gate quick on covered,
  uncovered, and suspended runs).
  Verification Method: test-release-gate.sh alias rows PASS.
- Criterion: legacy aggregate EXACT — 49 tools / 802 PASS / 3 FAIL / 3 N/A; every selftest
  section 0 FAIL including NEW `release-gate` + `m9-suite`; fast default stays 75/0;
  mirror-check green (the five composed tools byte-unchanged); linkcheck green with the new
  `gate` verb.
  Verification Method: `bin/dmc selftest --all` exit 0 on a committed replica, then the
  post-commit live re-run (closure condition).
- Criterion: INSTALL_MANIFEST re-proven — regenerated (+2 exactly), drift re-run clean.
  Verification Method: `bin/dmc selftest m8-suite` 126/0; manifest diff reviewed.
- Criterion: delegation.schema.md carries the serialization-disclosure line + the
  scope_lock_ref illustration; `dmc selftest delegation` stays 41/0 (validator behavior
  unchanged).
  Verification Method: grep both additions; `bin/dmc selftest delegation` 0 FAIL.
- Criterion: CI green on branch — the dmc-ci.yml workflow run triggered by the milestone
  push completes with conclusion=success on `claude/dmc-v1-runtime-upgrade-c5uch1`
  (fetch-depth 0; --all EXACT baseline; scoped model-name grep empty; lexeme/network greps
  empty; porcelain sandwich clean).
  Verification Method: `gh run watch`/`gh run view` conclusion recorded in evidence
  post-push (sequencing: this single criterion is verifiable only AFTER the human push
  gate; the closure record cites the run URL).
- Criterion: rollback — additive: a single revert of the M9 commit removes the new module,
  schema, workflow, fixtures, and bin/dmc registration; no pre-existing file is
  behavior-changed except the two delegation.schema.md doc additions (revert restores).
  Verification Method: `git revert` dry-run review of the M9 commit contents (additive
  diff), recorded in evidence.
- Criterion: suites leave the real repo byte-untouched.
  Verification Method: `git status --porcelain` identical before/after each suite
  (_m9common.sh guard).

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| CI first-run env surprises (runner tooling, timing) | medium | Suites verified offline/portable (bash 3.2 floor, dual sha256, self-set git identity); fetch-depth 0 pinned; 25-min timeout; CI-green is an explicitly post-push acceptance criterion with a fix-forward loop under the same plan scope if the first run is red (workflow-file-only iterations) |
| Chain predicate too loose (activity-scoped) reads as a hole | low | Predicate matches delegation.schema.md's conditional phrasing; g8/g12 rows pin both directions; the honest tier (skill-mandated at apply, BLOCKING at release when activity exists) is restated in the readiness schema |
| diff-scope committed-diff blindness misread as coverage | medium | Disclosed in schema + report; `--base` escape hatch; E2E gates BEFORE committing (the designed closure flow); recording HEAD-at-arming deferred (M10/hygiene candidate) |
| Legacy-tool exit-code mapping errors (0/1 vs 0/3) | low | Normalization table pinned in §1; self-test rows per sub-gate exercise both PASS and FAIL exits of each composed tool |
| Gate writes into run dir collide with scope-guard basenames | low | release-readiness.json is NOT in RUN_STATE_BASENAMES (verified); gate is a CLI (not hook-mediated); write-once + path-safety guard |
| m6 restore/rollback CI failure on shallow clone | high w/o mitigation | `fetch-depth: 0` REQUIRED, pinned in the workflow + this plan |
| `--quick` alias drifts from stop-gate behavior | low | Alias is a subprocess delegation to dmc-stop-gate.py (no logic copy); alias rows compare verdicts on three run states |
| E2E flakiness from timing (latency rows) | low | 2s budget vs measured 0.06s precedent (33× headroom); latency rows record values, not just booleans |
| Working-tree-drift legacy FAILs during build | expected | Carry-forward #7: committed-replica `--all` + post-commit live re-run |
| New verb/section registration conflicts | low | T014.2 is the SOLE bin/dmc owner (single-owner rule) |

## Assumptions

- GitHub Actions is available on the repo (public repo on github.com; push-triggered
  workflows run from the pushed ref's workflow file — the branch run satisfies "CI green on
  branch" without touching main).
- The five composed legacy tools' CLIs are stable (mirror-pinned; any change would fail
  mirror-check first).
- `.harness/schemas/delegation.schema.md` is editable under this plan's explicit allow-row
  (contract-class landmark authorization recorded here; not mirror-pinned, not
  hook-protected — verified).
- Orchestrator/worker split per handoff: Fable 5 directs; Opus 4.8 implements the composer
  + E2E suite (T014.1, T015.1), Sonnet 5 the mechanical registration/CI/manifest tasks
  (T014.2, T014.3, T015.2); all subagents `auto` permission mode, dispatched SYNCHRONOUSLY
  (M7 operational learning); Ring-0 guards enforce independently.
- The stop hook remains on `dmc stop-gate quick` (M6 frozen surface); no session reload
  needed (no settings.json change).

## Execution Tasks

- [ ] DMC-T014.1: NEW `bin/lib/dmc-release-gate.py` (release --full 9 sub-gates + --quick
  alias + --self-test with per-sub-gate PASS/FAIL/MISSING/FLAG rows and exit-mapping rows)
  + NEW `.harness/schemas/release-readiness.schema.md` + the two surgical
  `delegation.schema.md` additions (CF13d line + scope_lock_ref illustration).
  Files: bin/lib/dmc-release-gate.py, .harness/schemas/release-readiness.schema.md,
  .harness/schemas/delegation.schema.md.
  Notes: SOLE owner; composes legacy tools by subprocess ONLY (no edits to them). No
  blockedBy.
- [ ] DMC-T014.2: bin/dmc registration (gate arm + release sub-verb, RGATELIB, M9SUITEDIR +
  run_m9_suite, release-gate + m9-suite sections in --all + named blocks, usage()).
  Files: bin/dmc.
  Notes: SOLE bin/dmc owner. blockedBy T014.1.
- [ ] DMC-T014.3: NEW `.github/workflows/dmc-ci.yml` per §Proposed Changes 5 (fetch-depth
  0; the 9 steps; Option A boundary comments; CF3-scoped model-name grep; lexeme/network
  greps).
  Files: .github/workflows/dmc-ci.yml.
  Notes: SOLE owner. No blockedBy (file is inert until pushed).
- [ ] DMC-T015.1: `tests/fixtures/host-node/` static fixture + `tests/fixtures/m9/`
  (_m9common.sh, test-release-gate.sh with green path + g1-g12 + alias rows,
  test-e2e-loop.sh with the full loop + five denials + latency rows).
  Files: tests/fixtures/host-node/**, tests/fixtures/m9/**.
  Notes: SOLE owner; porcelain guard mandatory; copy-surface pattern; never arms the
  committed fixture in place. blockedBy T014.1, T014.2.
- [ ] DMC-T015.2: INSTALL_MANIFEST regen (+2) + m8-suite drift re-run + committed-replica
  `selftest --all` proof + evidence `.harness/evidence/dmc-v1-m9-build-<date>.md` +
  verification report `.harness/verification/dmc-v1-m9-release-gate.md` (passes
  `dmc validate verification`); post-push CI-run conclusion recorded in evidence.
  Files: INSTALL_MANIFEST.md, .harness/evidence/dmc-v1-m9-*.md,
  .harness/verification/dmc-v1-m9-release-gate.md.
  Notes: blockedBy T014.1–T015.1.

## Verification Commands

| Command | Reason | Required |
|---|---|---|
| bash -n .github/workflows/../../tests/fixtures/m9/*.sh (suite scripts) + python3 -m py_compile bin/lib/dmc-release-gate.py | syntax floor | yes |
| python3 bin/lib/dmc-release-gate.py --self-test | composer unit rows ([release-gate] N/0) | yes |
| bin/dmc selftest release-gate · bin/dmc selftest m9-suite | new sections directly | yes |
| bash tests/fixtures/m9/test-release-gate.sh · bash tests/fixtures/m9/test-e2e-loop.sh | green path + g1-g12 + full loop + latency | yes |
| bin/dmc selftest | fast default unchanged (9 sections, 75/0) | yes |
| bin/dmc selftest --all | legacy 802/3/3 EXACT + every section 0 FAIL — committed replica, then post-commit live | yes |
| bin/dmc selftest delegation · bin/dmc selftest worker-check · bin/dmc selftest m7-suite | M7 surfaces unregressed (41/0 · 34/0 · 85/0) | yes |
| bin/dmc selftest m8-suite | manifest drift re-proof (126/0) post-regen | yes |
| bin/dmc mirror-check · bin/dmc linkcheck | composed tools byte-unchanged; gate verb resolves | yes |
| bin/dmc validate plan .harness/plans/dmc-v1-m9-release-gate.md · dmc validate verification .harness/verification/dmc-v1-m9-release-gate.md | instance validity | yes |
| git status --porcelain before/after each suite · git diff --name-only vs this plan's allowlist | repo hygiene + scope conformance | yes |
| gh run view <id> --json conclusion (post-push) | CI green on branch (the post-push criterion) | yes |

## Approval Status

Status: APPROVED
Approver: wjlee (human release gate; granted via AskUserQuestion in the 2026-07-08
session, option "승인 (권장)", after the critic chain r1 NEEDS_CLARIFICATION (B1 CI
lexeme-grep scope would be permanently red; bound plan_hash `9331d9fc…1d68`) → Rev 2 →
r2 APPROVE bound to the frozen pre-approval bytes sha256
`b90722a6366744567a90269c296e31b428f211c99ae025714f8705dbde15a40a` — verdicts persisted at
`.harness/evidence/dmc-v1-m9-critic-verdict-r{1,2}.json`; r2 is the binding artifact;
`dmc verdict validate` VALID ×2 and `dmc verdict gate --plan-hash b90722a6…` PASS pre-gate)
Approved At: 2026-07-08

Approval record (verbatim scope of the human gate, 2026-07-08):
- **Approved**: DMC-T014.1, DMC-T014.2, DMC-T014.3, DMC-T015.1, DMC-T015.2 exactly as
  specified in §Execution Tasks, including the NEW `bin/lib/dmc-release-gate.py` +
  `.harness/schemas/release-readiness.schema.md`, the two surgical
  `delegation.schema.md` additions (contract-class landmark authorized by THIS gate), the
  bin/dmc `gate` verb + sections, the greenfield `.github/workflows/dmc-ci.yml` (master
  row L82), and the `tests/fixtures/host-node` + `tests/fixtures/m9` suites.
- **Advisory disposition (r2 advisories, recorded at the gate)**:
  AA1 — dmc-ci.yml pins the byte-exact M8 :507 pattern
  (`\b(nc|netcat)\b|curl|wget|urllib|http\.client|socket|requests|smtplib|ftplib|api\.|CODEX_API_KEY|GLM_API_KEY|dangerously-bypass-hook-trust`
  over `.claude/install/` + `bin/lib/dmc-doctor.py` ONLY) = **MANDATORY implementation
  directive**;
  AA2 — the "~20 tracked files" figure is corrected to "10 files (22 occurrences)" in the
  build evidence = accepted (plan text left as-is per carry-forward #9; the evidence
  carries the correction);
  AA3 — the E2E fixture's scope.lock `files[]` must equal the modified/new set (v0.2.6 G2
  is cached-diff semantics) = **MANDATORY fixture directive**.
- **Sequencing disclosure accepted**: the "CI green on branch" acceptance criterion is
  verifiable only AFTER the human push gate; the closure record cites the workflow run
  URL/conclusion.
- **Explicitly NOT approved**: staging, commit, push (separate human gates); edits to the
  five mirror-pinned legacy tools, the M6 hook surface + settings.json, the M4 lifecycle
  core, providers, installer/uninstaller/doctor code; docs/DMC_V1_RELEASE_CHECKLIST.md
  (M10); any live provider call.
- Hash note (carry-forward #9): appending this record changes the plan file's hash by
  design — the r2 verdict binds the pre-approval bytes `b90722a6…5a40a`, this record cites
  that hash, and run.json will bind the post-append bytes.
