# Verification Report

Review-Verdict: critic=PASS codex=ACCEPT

## Run ID
dmc-v0.3.0.1-rails-hardening

## Plan
`.harness/plans/dmc-v0.3.0.1-rails-hardening.md` (Status: APPROVED, rev 4; delegated semi-autonomous mode). Approved
after a 3-round adversarial critic panel (PASS) **and** a Codex confirmation review (ACCEPT, thread 019ee893). Patch
milestone remediating the divergences the Codex holistic deep re-review found across the v0.2.6–v0.3.0 rails; additive,
no provider-routing change, no history rewrite.

## Changed Files (9 — approved scope)
- `.harness/evidence/dmc-v0.2.6-gate-check-runner.sh` — F4a (DEFAULT_PROTECTED += PROVIDER_CONTRACT.md), F3 (`--gate` enum
  before the `--allowlist` guard), ST_PRE real-repo guard, +3 self-test cases (S8/S9/S10).
- `.harness/evidence/dmc-v0.2.7-run-manifest.sh` — F1 (verbatim `out_refused()`/PROT_RE port + guard the `--out` write),
  F4b (DEFAULT_PROTECTED), ST_PRE guard, +3 self-test cases (R8/R9/R10).
- `.harness/evidence/dmc-v0.2.8-task-intake-classifier.sh` — F4e (PROT_PATHS label), +1 self-test case (M12).
- `.harness/evidence/dmc-v0.2.9-effort-provider-policy.sh` — F4c (H4 `diff --name-only` arg-list).
- `.harness/evidence/dmc-v0.3.0-e2e-completion.sh` — F2 (conditional `emit > "$OUT"`), +2 self-test cases (M-F2/M-F2neg).
- `docs/DMC_GATE_CHECKS.md` — F3 enum doc, F4d prose protected list.
- `docs/DMC_RUN_MANIFEST.md` — F4f protected_paths gloss, `--out` guard note.
- `.harness/plans/dmc-v0.3.0.1-rails-hardening.md` — the approved plan.
- `.harness/verification/dmc-v0.3.0.1-rails-hardening.md` — this report (carries the canonical `Review-Verdict:` line).

Unchanged (byte-identical): `provider-router.py`, `ROUTING.md`, `PROVIDER_CONTRACT.md` (only *referenced* in protected
lists, never edited), adapters, `WORKER_*_SCHEMA.md`, `.claude/hooks/*`, `dmc-glm-smoke`.

## Findings remediated (from the Codex deep re-review + 3 critic rounds)
- **F1 (Critical)** v0.2.7 `--out` was an unguarded `> "$OUT"`. Fixed: ported the v0.2.8 `out_refused()`/PROT_RE verbatim
  (canonicalization-failure⇒refuse + symlink re-check) and call it before the redirect (refuse exit 2, write nothing).
- **F2 (Major)** v0.3.0 `--out` was guard-checked then ignored (emit → stdout). Fixed: conditional `emit > "$OUT"` after
  the guard; `wrote $OUT` notice on stderr so the file's bytes equal the stdout report; `OVERALL` exit semantics preserved.
- **F3 (Major)** v0.2.6 `--gate` accepted any value (only `push` was strict ⇒ a typo downgraded). Fixed: `stage|commit|push`
  enum, rejected (exit 2) before the `--allowlist` guard.
- **F4 (Major, CLASS across 6 sites)** PROVIDER_CONTRACT.md was missing from every protected-set enumeration: F4a v0.2.6
  DEFAULT_PROTECTED, F4b v0.2.7 DEFAULT_PROTECTED, F4c v0.2.9 H4 arg-list, F4d DMC_GATE_CHECKS.md prose, F4e v0.2.8
  PROT_PATHS label, F4f DMC_RUN_MANIFEST.md gloss. All added.

## F4 completeness census (every protected-set enumeration in the rails)
| Site | Kind | PROVIDER_CONTRACT.md |
|---|---|---|
| v0.2.6 DEFAULT_PROTECTED | guard input | ✓ (F4a) |
| v0.2.7 DEFAULT_PROTECTED → manifest `protected_paths` | guard input + emitted | ✓ (F4b) |
| v0.2.8 PROT_PATHS label → emitted `protected_paths` | advisory emitted | ✓ (F4e) |
| v0.2.9 H4 `diff --name-only` arg-list | guard input | ✓ (F4c) |
| DMC_GATE_CHECKS.md prose list | doc | ✓ (F4d) |
| DMC_RUN_MANIFEST.md `protected_paths[]` gloss | doc | ✓ (F4f) |
| v0.2.8 `out_refused` PROT_RE / v0.3.0 PROT_RE | guard input | already present (out of scope) |

Codex confirmation review independently confirmed no 7th omitting site.

## Commands Run
| Command | Result |
|---|---|
| `dmc-v0.2.6-gate-check-runner.sh --self-test` | **16 PASS / 0 FAIL**, exit 0 (incl. S8 `--gate` enum reject incl. empty/ws, S9 stage\|commit\|push positive control, S10 PROVIDER_CONTRACT.md → `G4 FAIL` attributed) |
| `dmc-v0.2.7-run-manifest.sh --self-test` | **8 PASS / 0 FAIL**, exit 0 (incl. R8 `--out` protected/secret/traversal refused exit 2 + target not created, R9 benign `--out` valid JSON, R10 `protected_paths` ⊇ PROVIDER_CONTRACT.md) |
| `dmc-v0.2.8-task-intake-classifier.sh --self-test` | **33 PASS / 0 FAIL**, exit 0 (incl. M12 emitted `protected_paths` names PROVIDER_CONTRACT.md, text+JSON) |
| `dmc-v0.3.0-e2e-completion.sh --self-test` | **16 PASS / 0 FAIL**, exit 0 (incl. M-F2 `--out` byte-equal to stdout, M-F2neg protected `--out` exit 2 + not created) |
| `dmc-v0.2.9-effort-provider-policy.sh` (self-check) | **15 PASS / 0 FAIL**, exit 0 |
| `grep 'diff --name-only' …v0.2.9… \| grep PROVIDER_CONTRACT.md` | matches (F4c structural) |
| `grep 'PROVIDER_CONTRACT.md' docs/DMC_RUN_MANIFEST.md` | matches (F4f structural) |
| real-repo `git status --porcelain` md5 before/after all self-tests | identical (self-tests + CLI sub-invocations mutated nothing) |
| provider-surface `git diff --name-only` over the protected set | empty (byte-unchanged) |

## Critic + confirmation process
3-round adversarial critic panel (5 dimensions). Round 1: 3 PASS / 2 REVISE (scope-completeness found F4 was a class
defect, not 1 site; verification-sufficiency found the ACs unfalsifiable). Round 2: still REVISE (F4e 4th→5th site; AC-F4c
non-executable on a harness-less tool; AC4 ST_PRE false for 3/4 scripts). Round 3: PASS/PASS (+ airtight-ness fixes:
enum-first-exit-2, byte-equality stderr exclusion, anchored F4c grep). Codex confirmation review then added F4f
(DMC_RUN_MANIFEST.md, the 6th site) → ACCEPT. Implementation surfaced one plan bug (the F4c verification grep anchored on
`git diff --name-only` but the code is `git -C "$ROOT" diff --name-only`) — corrected in the plan; fix itself was correct.

## Safety Posture
All five tools remain advisory/read-only/report-only; none stages/commits/pushes/grants a gate. The net effect of every
fix is **stricter** (F1 adds a guard, F3 removes a permissive fallthrough, F4 widens deny-lists, F2 gates a write behind
the pre-existing refusal). No live/model-API/network call; no `.env*`/credential read. `--out` writes are
canonicalization-guarded across v0.2.7/v0.2.8/v0.3.0. Self-tests run only in `mktemp` temp repos; real repo byte-identical.
Provider surface byte-unchanged; PROVIDER_CONTRACT.md referenced only. No history rewrite. Push DEFERRED to the human's
batch review.

## Final Status
**PASS** — 88 self-test assertions green across 5 tools (16+8+33+16+15), all exit 0; both structural checks pass; all 6
F4 sites covered; real repo and provider surface byte-unchanged. Stopped before commit pending the Codex Independent
Release Audit of the implementation, then staging review, then commit; **push deferred** (batch).
