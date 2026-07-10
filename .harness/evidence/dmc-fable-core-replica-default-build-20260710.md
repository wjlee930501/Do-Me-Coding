# Build Evidence — v1.1.6 committed-replica default for the selftest --all legacy leg (dmc-fable-core-replica-default)

Date: 2026-07-10 · Branch: `claude/dmc-fable-core` · Base: `92371db` (v1.1.5) · **Change commit: `3361890`** (+282/−8: `bin/dmc` 83/7, `docs/DMC_V1_HONEST_SCOPE.md` 1/1, `docs/MILESTONES.md` 60/0, `tests/install/test-selftest-replica-default.sh` 138 new).
Work ID: `dmc-fable-core-replica-default` · System-review item #1 (value pre-proven by the v1.1.4 replica catch) · Authorization: standing envelope + user directive 2026-07-10 ("3번도 착수하자"); push→CI→main-FF pre-authorized after v1.1.5+v1.1.6 complete.

## What shipped

`bin/dmc selftest --all` (and the new focused `selftest legacy-all`) runs the frozen legacy replay against a COMMITTED REPLICA by default: clone --no-hardlinks into mktemp, remote severed, HEAD-sha guard, the REPLICA's own `dmc-legacy-selftest.py` invoked. This retires, in one redirect of the single call site: the V15 tree-coupling flake (any tracked dirt → 801/4/3 misread), the mode-coupling flake (passive → false FAIL), and the manual rituals (committed-replica clone, `.codex/config.toml` stash, mode-restore). FAIL-LOUD on every provisioning failure — no code path silently falls back to the in-place run. `--in-place` preserves the historical byte-identical invocation as an explicit hatch. The `legacy-mirror` leg (frozen bin/lib↔evidence pin) stays in-place against the LIVE repo — mirror integrity unweakened (separate leg; mirror-check 55-file green). `.harness/mode` is never copied (gitignored ⇒ absent ⇒ active = mode normalization). Honesty boundary in HONEST_SCOPE + MILESTONES: env-var coupling (leaked-key class) is NOT fixed — the replica inherits the parent env.

## Live headline proof (this very repo, dirty `.codex/config.toml` present)

- default `bin/dmc selftest legacy-all` → `aggregate: tools=49 PASS=802 FAIL=3 N/A=3` + `PASS aggregate == pinned baseline exactly` + `SELFTEST-ALL RESULT: PASS`, rc 0.
- `bin/dmc selftest legacy-all --in-place` → `aggregate: tools=49 PASS=801 FAIL=4 N/A=3` + `FAIL aggregate DRIFTED`, rc 1 — the hatch reproducing the historical misread (tree-coupled tool flips; mode tool doesn't, mode=active). The FLIP pair is the cycle's thesis demonstrated live.

## Chain

| Stage | Artifact / evidence |
|---|---|
| Plan Rev 1 (DRAFT `76d5f7a3…`) → critic r1 APPROVE (0 blockers; rulings: keep `legacy-all` target, two-tool FLIP controls, keep HONEST_SCOPE clause, keep HEAD-sha guard; 1 advisory nit) | `.harness/evidence/dmc-fable-core-replica-default-critic-r1.json` |
| Rev 2 (`b33f355c…`, nit folded: AC C2–C4 two-tool wording; approval flip) → critic r2 APPROVE re-bind (delta exact; C1 exact-aggregate pin unweakened; C11-clean) | `...-critic-r2.json` |
| Armed run `dmc-run-6e707694161f` (one-command `--scope-input`, 4-path lock; armed at `92371db` — critic pre-approved the rebase-free arm over the disjoint v1.1.5 commit) | run dir |
| Opus executor: all 4 edits + suite; fast arms 10/10 live-verified; lane DEGRADED during the ~10-min legs (repeated silent idles) | executor interim report; `3361890` diff |
| Independent Opus verifier ran the AUTHORITATIVE battery itself: hermetic suite **15/15** (C1 dirty+passive sandbox `802/3/3` EXACT; C2 tree FLIP; C3 mode FLIP; C4 plumbing; C5 fail-loud; Z porcelain), live FLIP pair (above), m65 all green, neutrality diffs EMPTY, mirror-check + linkcheck green; ruled the executor's omitted OPTIONAL `--in-place` belt acceptable and closed it first-hand with the live 801/4/3 leg. **PASS** | `.harness/verification/dmc-run-6e707694161f.md` (schema-VALID) |
| Green set (CHK-V116-HELPER/SUITE/DOCS) + all frozen validators green → **release gate PASS** (8 PASS + non-degrading FLAG on bin/dmc + MILESTONES; NO G4 override); minted by the sibling v1.1.5 exec lane (own lane degraded) | run dir green set + `release-readiness.json` |
| Change commit | `3361890` |
| **Committed-replica `--all` at `3361890`** (non-DMC-named `replica-v116`, severed): `aggregate: tools=49 PASS=802 FAIL=3 N/A=3` EXACT + `SELFTEST-ALL RESULT: PASS` + replica `test-codex-shims.sh: 161 PASS / 0 FAIL` + **overall exit 0** — including the NESTED exercise of the new replica-default path inside the replica itself | background task log |

## Learnings (registered)

1. **Long blocking legs (10min+) inside worker lanes cause silent idles** — both the executor and (once) the verifier lane idled mid-leg without reporting; the verifier completed on resume, the executor lane was abandoned and its remaining duties re-routed (verifier = authoritative battery; sibling exec lane = mint+gate). Orchestration rule going forward: route long legs through the ORCHESTRATOR's run_in_background (guaranteed completion notification), keep worker-lane runs short.
2. The orchestrator's own Bash is equally guard-adjudicated: two live denies this wrap (out-of-repo path argument; a slipped `2>/dev/null`) — both self-corrected in seconds, re-demonstrating the deny-vs-ask asymmetry that fixes v1.1.7's scope.
3. Metrics ledger now carries 8 real rows (4 envelope + v1.1.4 premature+final + v1.1.5 + v1.1.6).

## Pending

- Records commit (both v1.1.5 and v1.1.6 governance artifacts) — immediately after this file.
- Push → CI green → main FF: pre-authorized by the user ("v1.1.5, v1.1.6도 완료되면 푸시까지 진행해줘"); executing now.
- v1.1.7 (safe-sink allowlist + L1-AMBIGUOUS ask→deny) queued next — scope fixed by the user's no-prompts directive.
