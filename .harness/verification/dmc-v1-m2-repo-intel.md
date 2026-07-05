# Verification Report — dmc-v1-m2 (Repository Intelligence P1/P2/P4/P5)

Run: dmc-v1-m2 · Date: 2026-07-05 · Branch: claude/dmc-v1-runtime-upgrade-c5uch1
Plan: .harness/plans/dmc-v1-runtime-upgrade.md (APPROVED — M2 ONLY, 2026-07-05)

## Status: PASS

## Commands and results

| Command | Result |
|---|---|
| `bash -n bin/dmc` | OK |
| `python3 -m py_compile bin/lib/dmc-repo-intel.py` | OK |
| `bin/dmc selftest orient landmarks depsurface radius` | **36 PASS / 0 FAIL**, exit 0 |
| E-checks (env -i identity; out+validate round-trips ×3; file-based radius refusal exit 3; --out existing-target refusal) | **5 PASS / 0 FAIL** |
| `git status --porcelain` scope audit | only in-scope paths changed |

Aggregate: **41 assertions, 0 FAIL.** Negative controls prove every validator can FAIL
(missing key, stale path, listed-'ordinary', broken inversion, missing attestation,
checkless radius entry, dropped scope entry) and that the ≥1-check-id refusal is intact
(exit 3) while self-tests use synthetic check-ids — critic carry-forward note 2 satisfied.

## Acceptance criteria (plan M2) — all met

- Deterministic at fixed HEAD: O4/L4/D3/R3 determinism assertions + E1 `env -i`
  byte-identity. ✔
- Negative controls: seeded fake landmark detected (L2); seeded dependent found (D1/D2). ✔
- DMC self-scan classifies own hooks/schemas/providers as landmarks (L1–L1f), with the
  protected-union seed covering `dmc-glm-smoke`. ✔
- Verification command `bin/dmc selftest orient landmarks depsurface radius` implemented and
  green. ✔

## Scope compliance

Changed surface: `bin/**`, `tests/fixtures/**`, 4 new `.harness/schemas/*.schema.md`, the
plan's Approval Status block (pre-run, human-instructed), run/evidence/verification state.
Forbidden surfaces untouched (hooks, settings, skills, agents, install, workers/providers,
adapters/router, main/master) — verified from `git status`/diff paths. Additive-only except
the plan edit. Bonus observation: the repo's own pre-tool-guard denied an `rm -rf` cleanup
command during the run (guard fired as designed); cleanup was redone with narrow `rm`.

## Push disclosure

Committed and pushed to the dedicated branch only, under the cloud-runtime
branch-preservation exception pre-authorized in the M2 approval; recorded in
`.harness/evidence/dmc-v1-m2-repo-intel.md`. main/master untouched.

Final branch state addendum (2026-07-05): the auto-logged `.harness/evidence/dmc-v1-m2.md`
was subsequently committed as `eafe062` (cloud clean-tree exception; content-reviewed, tool
event logs only, 0 secret-shaped strings) — so the final M2 branch state includes that file.
See the "Operational Exception — Auto-log Commit" section of the M2 evidence file. No new
risk introduced; **Status remains PASS**.

## Unresolved risks

- Depsurface is regex-tier best-effort (attested in-artifact); AST/LSP deferred by design.
- Radius check-ids cross-resolve into acceptance.json only from M4 (declared forward
  dependency in radius.schema.md).
- The four tools are advisory until wired (M5/M6); enforcement floor remains the hooks.

## Next Action

Human review of M2 outputs. **M3 is not started and not authorized by this run.**
