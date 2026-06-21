# Verification Report

Review-Verdict: critic=PASS codex=ACCEPT

(critic=PASS via the round-1 3-critic adversarial panel (selection-policy + no-env/no-exec + AC-falsifiability) → REVISE →
all REQUIRED applied → round-2 focused re-pass PASS/PASS, zero remaining_required, zero new_defects. codex=ACCEPT via the
Codex Independent Release Audit (thread 019eea04): REVISE (out_refused `..`-component gap) → fix → ACCEPT; safe-to-stage
yes, safe-to-commit yes, safe-to-push no (push = human gate). Protected surface modified: none.)

## Run ID
dmc-v0.3.4-provider-selection

## Plan
`.harness/plans/dmc-v0.3.4-provider-selection.md` (Status: APPROVED, rev 2). Authorizes a fully **additive, read-only**
selector + policy doc + this report. No protected-surface edit.

## Changed Files
- `.harness/evidence/dmc-v0.3.4-provider-selector.sh` — the advisory provider-selection runner (new) + `--self-test`.
- `docs/DMC_PROVIDER_SELECTION.md` — the provider-candidate ranking policy (new).
- `.harness/verification/dmc-v0.3.4-provider-selection.md` — this report (new).
- `.harness/plans/dmc-v0.3.4-provider-selection.md` — the approved plan (new).

Unchanged (byte-identical): `provider-router.py`, `ROUTING.md`, `PROVIDER_CONTRACT.md`, all adapters,
`WORKER_*_SCHEMA.md`, `.claude/hooks/*`, validators/guards, `dmc-glm-smoke`, the v0.2.8 classifier, the v0.2.9 policy
script/doc. The selector is **read-only** over every composed component (`git diff` over `.claude/` and the policy doc is
empty).

## What shipped
A read-only/advisory **Unified Provider Selection Runner** that composes the v0.2.8 task-intake classifier + the v0.2.9
effort/provider policy + the v0.3.2 router to emit **ranked `provider_target` candidates**. Candidate set = exactly the
three registered targets; **`mock` is a per-candidate `run_mode`, not a candidate** (the round-1 load-bearing fix). It
**executes nothing** (optional `--dispatch-check` uses only the router's `--print-dispatch` via a single chokepoint
helper), **infers nothing from env/secrets** (candidate output is byte-identical under `env -i` and across a
multi-var/multi-value credential matrix), and **grants no gate** (advisory; fail-closed when the classifier is absent).

## Commands Run
| Command | Result |
|---|---|
| `bash .harness/evidence/dmc-v0.3.4-provider-selector.sh --self-test` | **14 PASS / 0 FAIL**, exit 0 |
| functional run (`--task <adapter-task> --dispatch-check`) | correct: stop_and_ask=true, #7 gate, manual_import rank1, live-capable pair mock+`#5` escalation, all routes=yes |
| `git diff --stat` over `.claude/` + the v0.2.9 policy doc | empty (read-only over all composed components) |
| `find .claude -name '*.pyc' -o -name '__pycache__'` | none (`PYTHONDONTWRITEBYTECODE=1`) |

## Acceptance Criteria (self-test, offline only) — 14/14
- **AC1 read-only + no-exec**: (a) git-status `md5` pre==post over the whole self-test (real repo byte-unchanged);
  (b) behavioral **sentinel** — `--dispatch-check` against a marker-creating sentinel router never produces the marker
  (the chokepoint always passes `--print-dispatch`); the **real** router `--print-dispatch` routes glm-api and mutates
  nothing; source audit finds **no** bare adapter/router process-spawn.
- **AC2 no env/secret inference**: PRIMARY `env -i` byte-identity; DIFFERENTIAL across 5 credential vars ×
  {unset, dummy, realistic, second realistic} all byte-identical; STRUCTURAL audit (code positions only, comment-stripped)
  finds **no** environment read and **no** credential-var expansion; a decoy `.env` in cwd is never read/leaked.
- **AC3 candidate correctness (boundary tuples pinned inline)**: docs-only → stop=false, no #7, manual_import rank1 +
  live-capable `mock`, offline-first; adapter/protected → stop=true, human-gate-required (#7); live/credential →
  stop=true, #5/#6 flagged, no live-no-gate default.
- **AC4 dispatch-check mock-only**: chokepoint argv **always** has `--print-dispatch`, **never** the forbidden flags
  (`--live`/`--allow-network`/`--allow-exec`/`--mock`/`--import`); end-to-end annotates the 3 routable candidates
  `routes=yes`; executes nothing.
- **AC5 fail-closed**: classifier absent ⇒ `fail_closed:true`, empty candidate list (no live candidate), conservative
  gate (`stop_and_ask`/`human_gate_required` true).
- **AC6 `--out` guard**: protected/secret/traversal(incl a benign-resolving `..`)/symlink targets refused; benign
  allowed. Reuses the v0.2.8 canonicalized guard, **hardened** (v0.3.4) with an explicit `..`-component rejection before
  canonicalization (matching the v0.3.1 manual-import adapter) — a Codex-required fix.

## Safety Posture
Zero protected-surface edits; all composed components byte-unchanged. Mock/offline only — no live/network/credential/
model-API call; `manual_import` has no live mode. No env/secret inference (proven by `env -i` + differential +
structural audit). No `__pycache__` artifacts. The runner is advisory: it selects/executes/grants nothing.

## Notes on the critic round
Round-1 panel REVISE → fixed: (1) **mock category error** — `mock` reframed as a glm-api/oauth-cli `run_mode`, candidate
set is the three registered targets; (2) AC2 strengthened to `env -i` static proof + multi-var/value differential +
structural (not substring) no-env-read audit; (3) AC1/AC4 no-exec given named mechanisms (git-status md5 + behavioral
sentinel + single `--print-dispatch` chokepoint); (4) AC3 boundary tuples pinned inline. Round-2 re-pass: PASS/PASS.
Two self-test false-fails surfaced during implementation (the structural audits matching the forbidden tokens in their
own header comments and PASS/FAIL message strings) were fixed by auditing comment-stripped code positions and rewording
the labels — the audits remain true invariants over real reads. Codex Independent Release Audit round-1 returned
**REVISE** (one REQUIRED: the verbatim-reused v0.2.8 `out_refused` lacked an outright `..`-component rejection, so a
benign-resolving `dir/../out.json` could slip past) → fixed by adding the `..`-component refusal before canonicalization +
an AC6 benign-`..` assertion; re-audit pending.

## Final Status
**PASS** — 14/14 self-test assertions green (incl. the post-Codex `..`-traversal hardening); only the 4 approved additive
files present; all composed components byte-unchanged. **Codex Independent Release Audit: ACCEPT** (safe-to-stage yes,
safe-to-commit yes). Staged the approved additive set (gate-check carving the auto-log evidence `.md`), committed;
**push deferred** to the human gate.
