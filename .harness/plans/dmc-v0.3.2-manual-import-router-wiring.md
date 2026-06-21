# Plan — dmc-v0.3.2 Manual Import Router Wiring

Status: APPROVED
Approval Status: APPROVED
Approved: 2026-06-21 — delegated semi-autonomous mode; Orchestrator flip (8-step process step 3) after critic round-1
(dim2 PASS; dim1/dim3/dim4 REVISE) → round-2 focused re-pass = 3× PASS + 2 refinements folded in. Independent critic
panels, not self-approval. Authorizes exactly the provider-router.py + ROUTING.md edits below.
Revision: 3 (round-2 PASS×3 + A5-predicate pin + AC3b router-prefix discriminator)
Mode: PLAN ONLY until APPROVED. Touches the **protected** provider surface at exactly **two** files —
`provider-router.py` AND `ROUTING.md` — both **explicitly authorized by this plan** and nothing else.

## Goal
Now that v0.3.1 proved the manual_import adapter safe (verified + Codex-audited + committed `a28f37e`), raise it into the
routing layer: register `(manual_import, manual-import)` in `provider-router.py` so the router dispatches to the standalone
adapter **unchanged**, keep `ROUTING.md` truthful, and verify **routed-vs-direct `--out` parity** with **zero regression**
to glm-api / oauth-cli routing.

## User Intent
v0.3.2 of the delegated roadmap: "provider-router.py에 manual_import registry 연결 … direct adapter vs routed --out JSON
parity. v0.3.1에서 안전성이 증명된 뒤에만 routing layer로 올림." The router gains provider **selection** for manual_import;
it adds no new trust (it already only "execs one of a few known adapter scripts").

## Current Repo Findings (verified, file:line)
- `provider-router.py:36-39` REGISTRY = `(api_key,glm-api)` + `(oauth_cli,oauth-cli)`, each with a `live_flag`.
- `provider-router.py:55-56` `select_entry` **refuses** `ptype in ("", "mock", "manual_import")`.
- `provider-router.py:98-112` argv build: `--task` always; `--mock`/`--out` if given; on `--live`, exactly the entry's
  `live_flag` (`:104 required = entry["live_flag"]` → would be `None` for a no-live entry).
- manual_import adapter (committed v0.3.1) CLI: `--task <task> --import <artifact|-> [--out]`; deterministic sentinels
  (`GENERATED_AT='1970-01-01T00:00:00Z'`, `INVOCATION_ID='manual-import'`); rejects `--mock` (argparse exit 2).
- glm-api / oauth-cli adapters reject `--import` (argparse exit 2) — verified by the critic.
- `ROUTING.md:13` ("mock / manual_import / empty type → refuse") and `:21` ("… or mock / manual_import → refuse") become
  **factually false** once manual_import routes — a security-relevant doc on the protected surface → must be corrected here.

## Relevant Files (protected edits are authorized by THIS plan)
- `.claude/workers/providers/provider-router.py` — **authorized protected edit** (5 changes below).
- `.claude/workers/providers/ROUTING.md` — **authorized protected edit** (truthful routing-table + contract update).
- `.harness/evidence/dmc-v0.3.2-verify.sh` — routing-only verification harness (new, additive).
- `.harness/verification/dmc-v0.3.2-manual-import-router-wiring.md` — verification report (new).
- `.harness/plans/dmc-v0.3.2-manual-import-router-wiring.md` — this plan.

## Out of Scope (with rationale)
- **No adapter change** — `manual-import-adapter.py` + glm-api/oauth-cli adapters byte-unchanged; the router dispatches them
  unchanged.
- **No schema/guard/hook/validator/dmc-glm-smoke/PROVIDER_CONTRACT.md change** (C8 at PROVIDER_CONTRACT.md:23 is `--mock`-
  scoped and never names manual_import → no contract edit needed).
- **No live path for manual_import**; no change to glm-api/oauth-cli **routing behavior**.
- **No selection-policy / fallback / cost routing** (that is v0.3.4).

## Proposed Changes
### A. `provider-router.py` (5 edits)
1. **REGISTRY entry** (`:36-39`): `("manual_import", "manual-import"): {"adapter": "manual-import/manual-import-adapter.py", "live_flag": None}`.
2. **Refusal tuple** (`:55`): `("", "mock", "manual_import")` → `("", "mock")` (`""`/`mock` still refuse).
3. **`--import` arg + forward**: `ap.add_argument("--import", dest="import_")` (**no** `required=True` — adapter enforces it);
   set `allow_abbrev=False` on the parser (exact dispatch-flag surface); in argv build `if a.import_: argv += ["--import", a.import_]`.
4. **No-live guard** — insert at the **TOP of the `if a.live:` block, BEFORE `:104 required = entry["live_flag"]`**:
   `if entry["live_flag"] is None: die(f"--live not supported for (type={ptype}, provider={provider}) — refusing")`
   (deterministic "live not supported" message, not the incidental "requires explicit None").
5. **Router-side cross-flag rejection (REQUIRED)** — before building/forwarding argv: refuse `--mock` when the selected
   entry is manual_import (identified by **`entry["live_flag"] is None`**, consistent with the A4 guard) and refuse
   `--import` when the selected entry is NOT manual_import (`entry["live_flag"] is not None`), each via an explicit `die()`
   **before exec** (router owns its contract, mirroring the existing `:106-109` mismatched-live-flag refusal; not delegated
   to the adapter-argparse backstop). Legitimate combos stay allowed (`--mock` for glm-api/oauth-cli; `--import` for manual_import).

### B. `ROUTING.md` (truthful accompanying update)
- Routing table (`:11-13`): add `| manual_import | manual-import | manual-import/manual-import-adapter.py | — (no live) |`;
  change `:13` to `| mock / empty type | — | (none — refuse) | — |`.
- Selection-contract prose (`:21`): refuse list becomes `mock` / empty type (drop manual_import; note manual_import routes
  to the manual-import adapter with **no live mode**).
- Argv hygiene (`:29`): operator-provided paths now include `--import`.
- Live opt-in & cross-flag (`:39-45`): note manual_import has **no** live mode; the router refuses `--mock` for
  manual_import and `--import` for non-manual_import **before dispatch** (router-side, per change A5).
- Note "manual_import routing added in v0.3.2".

## Acceptance Criteria (measurable; `dmc-v0.3.2-verify.sh`, mock/offline only)
- **AC1 routed selection**: `--task <mi-task> --import <import-success.json> --print-dispatch` ⇒ adapter ==
  `manual-import-adapter.py`; argv contains `--import` and NOT `--mock`/`--live`; prints only paths+flags.
- **AC2 routed-vs-direct parity (explicit)**: with the **same** `<mi-task>` and **same** `import-success.json` on both
  sides, `provider-router.py … --out R` and `manual-import-adapter.py … --out D`, then **`cmp -s R D`** (compare `--out`
  JSON only, NOT stdout which carries the "wrote result ->" line). Byte-identical (deterministic sentinels).
- **AC3 manual_import live refused**: `… --import <fx> --live` ⇒ non-zero **and** stderr matches **"live not supported"**
  (the change-A4 guard, not "requires explicit None").
- **AC3b router cross-flag refused (pre-exec)**: `--import <fx>` against a glm-api task ⇒ router refuses; `--mock <fx>`
  against a manual_import task ⇒ router refuses — each asserting the **`provider-router:` die() prefix (exit 1)**, distinct
  from the adapter-argparse backstop (`error:` / exit 2), so the test cannot pass on the adapter and proves router-side
  pre-exec rejection.
- **AC4 no regression (incl. live-flag translation)**: glm-api + oauth-cli `--print-dispatch` + routed-vs-direct `--out`
  parity (mock) **unchanged**; router still refuses `""`/`mock`; **and** the V8 live-flag-translation behaviors hold —
  glm-api forwards only `--allow-network`, oauth-cli only `--allow-exec`, and a mismatched/cross opt-in flag is still
  refused (`--print-dispatch` over `--live`).
- **AC5 protected surface (scoped)**: the **only** changed tracked files are `provider-router.py` **and** `ROUTING.md`;
  a **scoped** `git diff --name-only` over `manual-import/`, `glm-api/`, `oauth-cli/`, `.claude/hooks/`, `WORKER_*_SCHEMA.md`,
  `PROVIDER_CONTRACT.md`, `dmc-glm-smoke` is **empty** (manual-import-adapter.py byte-unchanged).
- **AC6 router self-audit**: no new network/exec/secret surface (still execs only a registered adapter; `shell=False`);
  argv hygiene preserved (no task-derived string on argv); `--print-dispatch` payload = paths+flags only.
- **AC7**: gate-check green with `DMC_GATE_PROTECTED` = `DEFAULT_PROTECTED` **minus exactly the `provider-router.py` and
  `ROUTING.md` lines** (all other protected lines retained — glm-api/oauth-cli/hooks/schemas/PROVIDER_CONTRACT/dmc-glm-smoke
  still G4-covered); then critic + Codex Independent Release Audit → ACCEPT before commit.

## Risks (+ mitigations)
- **R1 regression to glm-api/oauth-cli routing** → AC4 re-checks both providers' dispatch + parity + **live-flag translation**;
  changes are additive.
- **R2 `None` live_flag** → change-A4 guard (before `:104`) + AC3 asserts the "live not supported" message; the path is
  fail-closed even without the guard (critic-confirmed) but the guard makes the refusal intentional + clearly-messaged.
- **R3 cross-flag** → router-side rejection (change A5) owns the contract before exec; the adapter-argparse backstop remains
  as defense-in-depth.
- **R4 protected-file edits** → exactly two files (router + ROUTING.md), both authorized; gate-check carve-out names exactly
  those two; Codex audit confirms no other protected change; v0.3.3 re-validates the whole provider contract.
- **R5 ROUTING.md untruthful** → fixed in this milestone (change B); AC5 asserts ROUTING.md changed and is consistent.

## Rollback Plan
- Single additive-commit `git revert` restores the `manual_import` refusal + the ROUTING.md table; no schema/adapter/hook
  impact; manual_import returns to unrouted (exactly as today). No history rewrite.

## Execution Tasks (after APPROVED)
1. Edit `provider-router.py`: changes A1–A5 (REGISTRY, refusal tuple, `--import`+`allow_abbrev=False`, no-live guard before
   `:104`, router-side cross-flag rejection).
2. Edit `ROUTING.md`: change B (table row, contract prose, argv-hygiene, cross-flag, v0.3.2 note).
3. Author `dmc-v0.3.2-verify.sh` (AC1–AC6; reuse v0.3.1 `import-success.json` + a manual_import task; glm/oauth regression +
   live-flag translation via their existing fixtures; mock/offline only).
4. Run the harness → all PASS; confirm scoped protected diff = `provider-router.py` + `ROUTING.md` only; write the
   verification report with the canonical `Review-Verdict:` line.
5. Gate-check (DMC_GATE_PROTECTED carved to exclude exactly router + ROUTING.md), critic re-pass, Codex audit; commit on
   ACCEPT; **no push** (batch-deferred).

## Verification Commands
- `bash .harness/evidence/dmc-v0.3.2-verify.sh` (expect ALL PASS)
- `git diff --name-only HEAD -- .claude/workers/providers .claude/hooks WORKER_*_SCHEMA.md dmc-glm-smoke` (expect EXACTLY
  `provider-router.py` + `ROUTING.md`)
- gate-check with `DMC_GATE_PROTECTED` = DEFAULT_PROTECTED minus the router+ROUTING.md lines; then Codex audit.

## Approval Status
**APPROVED** (2026-06-21, revision 3) — Orchestrator flip after the round-2 focused critic re-pass returned 3× PASS (dim2
PASS in round 1). Next: `/dmc-start-work`. The `provider-router.py` + `ROUTING.md` edits are authorized by THIS plan and
nothing else on the provider surface; commit only on Codex ACCEPT; push deferred (human gate).
