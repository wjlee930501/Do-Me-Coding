# SESSION LOG — 2026-07-08 · dmc-v1-runtime-upgrade (M9)

Branch: `claude/dmc-v1-runtime-upgrade-c5uch1` · milestone `HEAD` == `origin` == `4114a6b`
(pushed, fast-forward, no force; the handoff-rev-8 docs commit follows) · `main` untouched.

**One-line summary:** ONE session closed M9 (release-gate composition + CI + E2E dry run)
end-to-end: 6-scout parallel workflow → plan authored (VALID) → critic rotation (r1
NEEDS_CLARIFICATION on the CI lexeme-grep scope → Rev 2 → r2 APPROVE) → human gate (AA1 byte-exact
M8:507 CI grep + AA3 G2 cached-diff fixture rule both MANDATORY) → armed run `dmc-run-25ecbe729a18`
(17-entry scope.lock) → 5 synchronous executors (+2 CI amendments) → r3 build sign-off APPROVE +
independent verifier PASS → committed-replica `--all` 802/3/3 EXACT → human commit gate → `a7ef8d6`
pushed → live post-commit `--all` 802/3/3 EXACT exit 0 → **six workflow-file-only CI fix-forwards →
CI GREEN at `4114a6b`** (Actions 28899008386 = success) → closure (stop-gate PASS, honest
crosscheck REFUSE, run SUSPENDED).

> Reconstruction aid only. Canonical resume doc: `.harness/plans/dmc-v1-runtime-upgrade-handoff.md`
> (rev 8). Full reports: `.harness/verification/dmc-v1-m9-release-gate.md`,
> `.harness/evidence/dmc-v1-m9-build-20260708.md`,
> `.harness/evidence/dmc-v1-m9-critic-verdict-r{1,2,3-buildsignoff}.json`.

## 1. What shipped (`a7ef8d6`, 17-file scope; CI fix-forwards `395da6c`..`4114a6b`)

- NEW `bin/lib/dmc-release-gate.py` — the `dmc gate release --full` composer: 9 sub-gates
  (diff-scope sealed-trust+`--base`, gate-checks v0.2.6 temp-allowlist+staged precondition, receipts
  v0.6.2 coverage/validate, findings/goal/decision present⇒gate/trace/answer else MISSING, approvals
  +CF2 `verification_ref`→artifact resolution, chain activity-predicate no-activity⇒PASS-with-note,
  landmark-flag FLAG-never-FAIL); overall FAIL>PARTIAL>PASS, PARTIAL never presented as PASS; exit
  0/1/2/3; output `dmc.release-readiness.v1`; `--quick` = flags-only delegation to dmc-stop-gate.py;
  39/0 self-test. The 5 composed legacy tools stay mirror-pinned (subprocess-composed, never edited).
- NEW `.github/workflows/dmc-ci.yml` — the Option A Codex enforcement boundary made REAL. 13 BLOCKING
  checks (bash -n, porcelain PRE/MID, mirror-check, doctor, `selftest release-gate` 39/0, `selftest
  m9-suite` 56/0+35/0, linkcheck, CF3 model-name grep, AA1 lexeme/network grep, Codex-wiring presence);
  the full legacy `selftest --all` replay is ADVISORY (continue-on-error).
- NEW `.harness/schemas/release-readiness.schema.md` (`dmc.release-readiness.v1`) + two surgical
  additions to `.harness/schemas/delegation.schema.md` (scope_lock_ref illustration + serialization
  disclosure); delegation validator unchanged (41/0).
- NEW `tests/fixtures/host-node/` (inert host-app substrate) + `tests/fixtures/m9/` (`_m9common.sh`,
  `test-release-gate.sh` 56/0 incl. g1–g12 seeded gaps + alias, `test-e2e-loop.sh` 35/0 incl. the
  five canonical denials + latency 0.10–0.15s <2s).
- `bin/dmc` — `gate release` verb arm, `RGATELIB` + `M9SUITEDIR` + guarded `run_m9_suite()`, sections
  `release-gate` + `m9-suite` in `--all` + named blocks; usage updated. `INSTALL_MANIFEST.md` regen
  (+2: dmc-release-gate.py, release-readiness.schema.md); m8-suite drift re-proof 126/0.

## 2. The verification story

Non-authoring lanes end to end: 6 read-only scout agents (parallel Workflow) fed the plan; the
critic (fresh ×3) judged r1/r2/r3 with sha256-bound `plan_hash` each round — r1 flagged that the CI
"no dangerously-bypass-hook-trust anywhere" step would be permanently red repo-wide (the lexeme
legitimately lives in 10 files/22 occurrences), so Rev 2 pinned the byte-exact M8:507 pattern scoped
to `.claude/install` + `bin/lib/dmc-doctor.py`. Five executors (Opus/Sonnet, `auto` mode) built under
the armed scope.lock; a T014.3 executor caught a real CI defect (the `.codex/.dmc-created` sentinel is
an installer-only provenance marker absent on the dev repo — the wiring-presence step was amended to
assert `config.toml`+`hooks.json` tracked instead). Verifier (non-authoring) re-ran every suite and
authored the VALID report. Build closure = committed-replica + live post-commit `--all` on the real
tree: 802/3/3 EXACT, all sections 0 FAIL, SELFTEST-ALL PASS.

## 3. The CI-green fix-forward arc (the session's hard problem)

The first CI run on GitHub was red at 796/9, not the pinned 802/3/3. Diagnosis converged decisively:
the legacy verify tools call `python3 -m py_compile`, which **IGNORES** `PYTHONDONTWRITEBYTECODE` but
**HONORS** `PYTHONPYCACHEPREFIX`; the resulting in-tree `__pycache__/*.pyc` litter tripped those tools'
OWN `git status --porcelain` cleanliness assertions (v0.2.1:47, v0.2.3:89, v0.6.0:148, v0.3.9:194 +
the providers/manifest checks). Fix arc (each a human-gated, workflow-file-only commit):
1. `PYTHONDONTWRITEBYTECODE=1` (`395da6c`) — insufficient (py_compile ignores it).
2. `PYTHONPYCACHEPREFIX=/tmp/dmc-pycache` (`ac926fe`) — **PROVEN locally on a python-3.12 committed
   replica: 799/6 → 802/3/3 EXACT, 0 in-tree pyc.** First value used `${{ runner.temp }}` which is
   invalid at job-level `env:` (runner context is step-only) → literal `/tmp` (`e29a006`).
3. python-3.9 pin (`56ce86e`) — matches the baseline interpreter.
4. macos-latest trial (`5be5dba`) — 800/5, closer but still not exact.
5. **Human-gated decision:** make the full legacy `selftest --all` replay ADVISORY (continue-on-error;
   output still visible), keep every M9-built check BLOCKING; revert to ubuntu-latest (`4114a6b`) →
   **CI GREEN**.

**Load-bearing finding:** the pinned 802/3/3 baseline is a macOS-dev-environment artifact that NO
GitHub runner reproduces EXACTLY (ubuntu 799/6, macos-latest 800/5). The divergence is confined to
2–3 frozen mirror-pinned legacy tools (v0.2.6, v0.3.9, v0.3.1) whose porcelain-cleanliness assertions
react to runner OS/py-patch bytecode behavior — tools M9 cannot edit. Deferred to M10 as
Carry-forward 14; the maintainer's local/committed-replica run stays the definitive 802/3/3 proof.
The M9-built blocking checks were NEVER weakened to force green.

## 4. Operational learnings (this session)

- **py_compile vs env vars**: `PYTHONDONTWRITEBYTECODE` does not stop `py_compile`; `PYTHONPYCACHEPREFIX`
  redirects even py_compile's bytecode out of the tree. When a "no-pyc" invariant must hold across a
  runner you don't control, redirect the cache prefix — don't just disable writes.
- **Reproduce the CI env locally before burning cycles**: the python-3.12 committed-replica proof
  (799/6 → 802/3/3 with the prefix) turned a guess into a verified fix before the push.
- **`${{ runner.temp }}` is step-only** — invalid in a job-level `env:` block (use a literal path or a
  step-scoped value); it silently invalidates the whole workflow ("workflow file issue").
- **Advisory ≠ masking**: making the legacy replay `continue-on-error` keeps its full output visible
  and every M9-built check blocking — an honest green, with the baseline-portability gap explicitly
  carried to M10, not silently dropped.
- **verify-crosscheck disposition** (unchanged from M7/M8): declaring the out-of-lock master-plan
  approval edit yields `CROSSCHECK-CHANGED-FILE-OUT-OF-SCOPE` — the designed hold; recorded verbatim.
- **Run pointer clearing** (`.harness/runs/current-run-id` removal) disarms the scope/stop gates for
  post-run orchestrator docs (M8/M7 precedent); a status probe carrying `2>/dev/null` was denied by
  bash-radius L1 while armed.

## 5. Next (M10 — per handoff rev 8 §Next step; LAST milestone)

M10 final docs + identity + release checklist: own plan → critic → human gate. M10 owns Carry-forward
14 (CI-baseline-portability): decide between (a) a scoped hygiene plan addressing the frozen legacy
tools' runner portability (touches the frozen surface → separate approval) or (b) formalizing the
advisory tier + a documented CI-tier baseline as the accepted v1.0 posture. Do NOT mask the 3 pinned
FAILs (Carry-forward 1).
