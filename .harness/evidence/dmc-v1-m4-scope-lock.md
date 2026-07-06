# DMC v1.0 M4 — Constructive Scope Lock compiler + adjudicator (DMC-T009b)

- run_id: `dmc-v1-m4-20260706`
- date: 2026-07-06
- branch: `claude/dmc-v1-runtime-upgrade-c5uch1`
- plan: `.harness/plans/dmc-v1-m4-run-lifecycle.md` (APPROVED 2026-07-06, approver wjlee) §DMC-T009b
- primitive: P7c (constructive Scope Lock — compile + validate + pure adjudication verdict;
  architecture §P7/§P6/§0.4). The P7 *enforcement* half (Bash write-radius classifier,
  `git apply`/`patch` deny, fail-closed-in-active hook wiring) is out of scope — M6.
- contract: `.harness/schemas/scope-lock.schema.md` (`dmc.scope-lock.v1`; consumed, not edited)
- scope of this task: additive Ring-0 only. The one code file created is `bin/lib/dmc-scope-lock.py`.
  No `.harness/evidence/dmc-v0.*` tool or its bin/lib copy was touched; no schema doc edited; no
  `.claude/**`; no `bin/dmc` edit (T009g owns selftest registration; this module runs standalone);
  no `bin/lib/dmc-v0.*` filename added; no git add/commit/push; no network; no secret read.

## Files created / modified

| Path | Change | In-scope |
|---|---|---|
| bin/lib/dmc-scope-lock.py | new — scope-lock compiler + fail-closed validator + pure adjudicate verdict + hermetic self-test | yes (T009b) |
| .harness/evidence/dmc-v1-m4-scope-lock.md | new — this evidence log | yes (T009b) |

## Design decisions (judgment calls)

- **Lock field set (`dmc.scope-lock.v1`):** the schema's stated fields
  (`schema, work_id, plan_hash, repo_hash, run_id, approved_by, files[], bounds, immutable,
  compiled_at_head, prev_hash`) **plus a sealing `state_hash`**. `state_hash` is the mechanism the
  schema's own "tamper is detectable at Ring 0" line implies; it is additive and mirrors T009a's
  run.json seal, so the artifact stays a superset of the visible contract (not a divergence) and the
  validator can detect an in-place edit. Entries carry the minimal `{path, grant, landmark_class}`;
  a non-`ordinary` entry additionally carries an explicit `landmark_authorized: true` (see below).
- **Canonicalization copied verbatim from T009a** so the run → scope-lock chain composes exactly:
  `canon_hash` = `sha256(json.dumps(obj, sort_keys=True, separators=(",",":"), ensure_ascii=False))`,
  `seal(body)` sets `state_hash = canon_hash(body − state_hash)`, `GENESIS = "0"*64`,
  `HASH_RE = ^[0-9a-f]{16,}$`. On `--compile --run <run.json>` the lock's `prev_hash` links to the
  run record's `state_hash`; with no `--run` it is `GENESIS`. Proven by self-test **C6** (a
  T009a-canonical run.json is chained: `lock.prev_hash == run.state_hash`, lock validates).
- **Compiler inputs = plan + landmark-annotated scope input.** The APPROVED plan is the authority
  (approval enforced, `work_id`/`plan_hash`/`approved_by` bound from it so the lock is tied to the
  exact approved bytes). The `--landmarks` JSON carries the machine-readable
  `files[] {path, grant, landmark_class[, landmark_authorized]}` + P6 `bounds`
  `{max_files, max_added, max_deleted, forbidden_hunk_classes}` — i.e. the plan's authorized-file
  table joined with the P2 landmark map, consumed as structure rather than re-parsed from prose so
  the lock stays deterministic and value-blind. `approved_by` is read from the plan's `Approver:`
  line (approval **provenance**, not authentication — the honest-scope label the schema names).
- **Landmark-edit authorization made checkable (schema: "landmark edits are never implicit"):** a
  non-`ordinary` `landmark_class` entry MUST carry `landmark_authorized: true`, both at compile
  (refuse to emit otherwise) and at validate (`SCOPE-LOCK-LANDMARK-UNAUTHORIZED`). This keeps the
  P2/P7 interaction enforceable by a self-contained, value-blind validator — no re-reading the plan
  at adjudication time.
- **Immutability / concurrent-second-lock (§0.4):** `--compile` refuses to overwrite an existing
  `scope.lock.json` for the run (`SCOPE-LOCK-EXISTS`) — amendment = new plan revision + re-approval,
  never an in-place edit. Asserted as **C4**.
- **`adjudicate(lock, path, op)` is PURE** (no filesystem access, no mutation — Ring-1 wiring is
  M6). Fail-closed: an invalid/tampered lock, an absolute/`..`/secret path, an out-of-scope path,
  or an ungranted op all return `refuse`. Grant semantics: `edit` permits `{edit}`; `create`
  subsumes `{create, edit}` (a newly-created in-scope file may then be edited). Exit-code-as-verdict
  on the CLI: `allow ⇒ 0`, `refuse ⇒ 3`.
- **Determinism:** `files[]` sorted by `(path, grant)`, `forbidden_hunk_classes` sorted, sorted-key
  JSON — identical inputs ⇒ byte-identical lock (**C2**). No timestamps in the artifact at all, so
  the lock is fully content-derived. `repo_hash`/`compiled_at_head` use the established env-free
  git-best-effort pattern with a `no-git` fallback.

## Verification results

- `python3 -m py_compile bin/lib/dmc-scope-lock.py` ⇒ clean (Python 3.9.6).
- `python3 bin/lib/dmc-scope-lock.py --self-test` ⇒ **`[scope-lock] 30 PASS / 0 FAIL`, exit 0**.
  - Deterministic: two consecutive runs print an identical footer.
  - `env -i python3 bin/lib/dmc-scope-lock.py --self-test` ⇒ 30 PASS / 0 FAIL, exit 0 (git absent →
    consistent `no-git` fallback); the value-blind surface (`--validate`/`--adjudicate`) is asserted
    byte-identical under a PATH-only scrubbed env (**C3/C3b**).
- Standalone pre-integration gate (against the repo fixture plan; output confined to the scratchpad,
  real repo untouched):
  - `--compile --plan tests/fixtures/run/plan.md --landmarks <scope.json> --run-id dmc-run-demo` ⇒
    exit 0, writes `scope.lock.json`.
  - `--validate <scope.lock.json>` ⇒ `VALID … conforms to dmc.scope-lock.v1`, exit 0.
  - `--adjudicate <lock> src/app.py edit` ⇒ `ALLOW`, exit 0; `--adjudicate <lock> src/secret.py edit`
    ⇒ `REFUSE: SCOPE-LOCK-PATH-NOT-IN-SCOPE`, exit 3.
- Negative controls (each a real REFUSE — exit 3 via `--validate`/`--compile`, or a `refuse` verdict):
  | Control (per plan §DMC-T009b) | Reason code | Self-test |
  |---|---|---|
  | missing/empty `approved_by` | `SCOPE-LOCK-EMPTY-APPROVED-BY` | N1 |
  | `files[].path` with `..` | `SCOPE-LOCK-BAD-PATH` | N2 |
  | `files[].path` absolute | `SCOPE-LOCK-BAD-PATH` | N2b |
  | `immutable != true` | `SCOPE-LOCK-NOT-IMMUTABLE` | N3 |
  | negative bound | `SCOPE-LOCK-BAD-BOUND` | N4 |
  | non-enum `landmark_class` | `SCOPE-LOCK-BAD-LANDMARK-CLASS` | N5 |
  | non-`ordinary` landmark w/o plan authorization | `SCOPE-LOCK-LANDMARK-UNAUTHORIZED` | N6 |
  | in-place edit (stale state_hash) | `SCOPE-LOCK-TAMPER` | N7 |
  | broken `prev_hash` | `SCOPE-LOCK-BAD-PREV-HASH` | N8 |
  | concurrent second lock for the run | `SCOPE-LOCK-EXISTS` | C4 |
  | compile on a DRAFT plan | `SCOPE-LOCK-PLAN-NOT-APPROVED` | C5 |
  | adjudicate a secret-shaped mutation path | `SCOPE-LOCK-SECRET-PATH` | C7f |
  Reason codes are value-blind (they name schema constants/enums, never a scoped path's content).
- Hermeticity (**Z1**): real repo `git status --porcelain` captured before/after the self-test is
  byte-identical (all fixture I/O confined to `tempfile.mkdtemp()`; the self-contained tempdir git
  init needs no commit, so no host git identity is required).
- Regression / invariants (repo-wide, unchanged by this additive file):
  - `bin/dmc selftest` ⇒ **75 PASS / 0 FAIL, exit 0** (this module is standalone; not in the default
    — run-core/loop-core registration is exclusively T009g).
  - `bin/dmc mirror-check` ⇒ PASS (55/55 byte-identical, no stray `dmc-v0.*`).
  - `grep -RInE 'claude-(opus|sonnet|haiku|fable|mythos)|gpt-[0-9]' bin/` ⇒ empty (Ring-0
    model-name-free). No new `bin/lib/dmc-v0.*` filename. `__pycache__` swept under `bin/`.

## Rollback

Delete `bin/lib/dmc-scope-lock.py` (and this evidence file). Nothing references the module at
runtime yet — the M3 selftest surface (default 75/0) and the pinned legacy baseline are unchanged.

## Not-edit confirmation

`.claude/**`, `bin/dmc`, `bin/lib/dmc-instance-validate.py`, the six M3 schema docs (incl.
`scope-lock.schema.md`, consumed only), the Bash write-radius classifier (M6), the other workers'
files (`dmc-approvals.py`, `dmc-evidence-ledger.py`, `dmc-checkpoints.py`, `dmc-acceptance.py`,
`dmc-verify-plan.py`), `docs/MILESTONES.md`, `.harness/evidence/dmc-v0.*` originals + their bin/lib
copies, and main/master were not touched. No git add/commit/push. No live/network/secret paths.
