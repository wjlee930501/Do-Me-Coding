# Verification Report

## Run ID

dmc-run-53553ac50a20

## Plan

.harness/plans/dmc-v1-m6-hook-hardening.md

## Changed Files

- .claude/hooks/pre-tool-guard.sh: shim over Ring-0 Bash write-radius; git apply/patch L0 floor; fail-closed-when-armed
- .claude/hooks/scope-guard.sh: shim over scope-lock adjudication; self-escalation fix; narrow evidence/verification exemption; out-of-project deny
- .claude/hooks/secret-guard.sh: superset keys (file_path/glob/pattern/path), case-insensitive, path-only
- .claude/hooks/stop-verify-gate.sh: shim over stop-gate quick (receipt coverage + semantic cross-check); keyword regex removed; suspended run passes
- .claude/hooks/evidence-log.sh: post-Bash out-of-scope diff guard wired to PostToolUse Bash; sticky BLOCKED marker via the dmc CLI
- adapters/claude-code/README.md: Ring-1 adapter home (new)
- bin/lib/dmc-bash-radius.py: Bash write-radius classifier CLI (L0 git-apply/patch deny; L1 scope-lock adjudication) (new)
- bin/lib/dmc-postbash-diff.py: post-Bash out-of-scope + run-state tamper detector vs the arming snapshot (new)
- bin/lib/dmc-verify-crosscheck.py: semantic verification-report cross-check (run-id bind, changed-files in scope, honest PASS) (new)
- bin/lib/dmc-stop-gate.py: completion quick gate (receipt coverage + BLOCKED + cross-check) (new)
- bin/lib/dmc-run-lifecycle.py: verdict-REJECT arming floor (C11); blocked.json sidecar; arming snapshot.txt (STATES/run.json schema unchanged)
- bin/lib/dmc-scope-lock.py: Rev 3 Option A write-once operative-snapshot record in run.json at the compile lock-write site; --out isolation; delete-then-recompile refusal
- bin/dmc: M6 verb registration + selftest m6-suite (single-owner)
- .harness/schemas/blocked-marker.schema.md: blocked.json sidecar schema (new)
- tests/fixtures/hooks-v0.6.5/: byte-identical pre-M6 hook-tree + settings.json fixtures pinned to 2999870 (committed 192dce6)
- tests/fixtures/m6/test-rollback.sh: whole-tree rollback proof (committed 192dce6)
- tests/fixtures/m6/_m6common.sh: shared suite helpers (arming, tool-JSON, porcelain guard) (new)
- tests/fixtures/m6/test-adversarial.sh: negative controls — canonical five, git-apply floor, fail-closed, verdict floor (new)
- tests/fixtures/m6/test-compat.sh: compatibility matrix — legacy behavioral rows, per-mode rows, unarmed/armed rows, latency (new)
- tests/fixtures/m6/test-e2e-ultrawork.sh: ultrawork stop-block E2E on a full-surface copy (new)
- tests/fixtures/m6/test-restore.sh: pre-commit restore proof vs the pinned commit (new)
- .harness/plans/dmc-v1-m6-hook-hardening.md: Rev 2 + Rev 3 (human-gated amendment)
- .harness/evidence/dmc-v1-m6-critic-verdict-r1.json: critic REJECT (7 blockers)
- .harness/evidence/dmc-v1-m6-critic-verdict-r2.json: critic APPROVE (Rev 2)
- .harness/evidence/dmc-v1-m6-critic-verdict-r3.json: critic APPROVE (binding pre-approval artifact)
- .harness/evidence/dmc-v1-m6-critic-verdict-r4.json: critic APPROVE (Rev 3 amendment)
- .harness/evidence/dmc-v1-m6-build-20260706.md: build evidence (this milestone)

## Commands Run

| Command | Result | Reason | Output Summary |
|---|---|---|---|
| bash tests/fixtures/m6/test-adversarial.sh | PASS | canonical-five (1)(2)(3), git-apply floor incl. armed wrapper-exec deny, fail-closed, verdict floor | 38 PASS / 0 FAIL, exit 0 |
| bash tests/fixtures/m6/test-compat.sh | PASS | no over-blocking; legacy behavioral + per-mode + unarmed/armed rows; latency | 45 PASS / 0 FAIL, exit 0 |
| bash tests/fixtures/m6/test-e2e-ultrawork.sh | PASS | master §M6 acceptance stop-block E2E (hold -> pass -> suspend) | 10 PASS / 0 FAIL, exit 0 |
| bash tests/fixtures/m6/test-restore.sh | PASS | pre-commit restore proof vs pinned 2999870 | 11 PASS / 0 FAIL, exit 0 |
| bin/dmc selftest m6-suite | PASS | registered aggregate of the four suites | 104 PASS / 0 FAIL, exit 0 |
| bin/dmc selftest m6-core | PASS | Ring-0 verdict-CLI regression floor (bash-radius 50, postbash-diff 25, verify-crosscheck 13, stop-gate 11) | 99 PASS / 0 FAIL, exit 0 |
| bin/dmc selftest run-core | PASS | scoped run-lifecycle edit regression floor | 168 PASS / 0 FAIL, exit 0 |
| bin/dmc mirror-check | PASS | copy-routed tools byte-untouched | 55-file byte-equality green, exit 0 |
| bash -n (bin/dmc, 5 hooks, 5 suite scripts) | PASS | shell syntax floor | all clean |
| python3 -m py_compile (6 touched bin/lib/*.py) | PASS | python syntax floor | OK |
| bin/dmc legacy v0.1.3-verify --self-test (dirty tree) | PASS | live-hook behavioral baseline (shim runtime contract) | 43 behavioral PASS + 2 non-behavioral FAIL (evidence-log byte-pin changed; GLM/worker code found) — the byte-pin FAIL clears on commit (committed replica: 44/1) |
| bin/dmc selftest --all (COMMITTED REPLICA — throwaway cp -R + git commit in the copy; real repo porcelain+HEAD verified untouched) | PASS | committed-tree baseline proof (carry-forward #7 closure pattern) | legacy aggregate EXACTLY 802 PASS / 3 FAIL / 3 N/A (the pinned 3 accepted FAILs: v0.1.3, v0.2.3, v0.3.2) + originals-alone reproduce 802/3/3; ALL new sections 0 FAIL — run-core 168/0, loop-core 78/0, roles 19/0, verdict-validate 16/0, verdict-gate 9/0, delegation 29/0, linkcheck 17/0, bash-radius 50/0, postbash-diff 25/0, verify-crosscheck 13/0, stop-gate 11/0, m6-suite 104/0; NO clean module FAILs. The post-commit LIVE re-run remains the closure condition. |
| bin/dmc selftest --all (DIRTY tree, for the record) | PASS | dirty-tree drift accounting (see Unresolved Risks) | legacy aggregate 786 PASS / 19 FAIL / 3 N/A — the +16 drift is FULLY accounted (13 uncommitted-working-tree-drift checks); all new sections 0 FAIL |

## Manual Checks

| Check | Result | Notes |
|---|---|---|
| Canonical (1) Bash write outside scope denied + BLOCKED + stop held | PASS | c1a-c1g |
| Canonical (2) self-edit of scope.lock/run-state + tamper + recompile refused | PASS | c2a-c2f |
| Canonical (3) secret reads denied by path (Glob/Grep/Read, case-variant) | PASS | c3a-c3d; benign Grep 'secret' NOT denied (c3e) |
| git apply/patch L0 floor denies command-position forms | PASS | bare, pipe, git -C, env-prefixed, sudo patch |
| git apply/patch armed wrapper-exec forms denied | PASS | armed sh -c / bash -c / xargs inner git-apply -> BASH-L1-WRAPPER-EXEC deny; benign wrapper payload -> ask; unarmed wrappers stay L0-allow (documented boundary) |
| Fail-closed when armed + Ring-0 unresolvable | PASS | pre-tool-guard + scope-guard both deny (fc-a, fc-b) |
| Verdict floor: REJECT refuses arming; NEEDS_CLARIFICATION arms | PASS | vf-a/b/c (C11: no machine verdict opens the human gate) |
| Suspended run does not block stop | PASS | E2E-3b + compat stop-gate passive/off stand-down |
| Repo left byte-identical | PASS | porcelain before/after in every suite |

## Scope Review

Result: PASS

Notes:
All applied edits lie within the plan's authorized file scope (the protected `.claude/hooks/*.sh`
this milestone explicitly authorizes, the scoped bin/lib edits, additive new CLIs/tests/schema, and
the two human-gated scope additions — the plan-file Rev 3 amendment apply and bin/lib/dmc-scope-lock.py).
`.claude/settings.json` was NOT modified. `dmc-router.sh`, the worker guards, and the installer are
untouched. Only T011.1 fixtures are committed (192dce6); the rest is uncommitted pending the release gate.

HONEST-SCOPE residuals (disclosed, not masked):
- Grep-content-read residual (pre-M6, UNCHANGED): a broad `Grep` with no file_path/path cannot be
  path-blocked; Grep respects .gitignore (gitignored secrets skipped) and the CLAUDE.md instruction
  layer remains the defense-in-depth. M6 did not narrow or widen this.
- git-apply/patch WRAPPER-FORM boundary (hardened this milestone): the inline L0 floor is
  command-position anchored, so UNARMED it does not descend into `sh -c "git apply …"` /
  `bash -c "…"` / `xargs git apply` (allow — the accepted L0 boundary). ARMED, bash-radius now
  CLOSES all of these: the token-aware L0 catches `GIT_DIR=x git apply` and `env … patch`, and the
  L1 wrapper-exec detector (BASH-L1-WRAPPER-EXEC) descends into `sh -c`/`bash -c`/`xargs` payloads
  and DENIES an inner git-apply/patch, while a benign wrapper payload is ASK (wrapper opacity, not
  over-blocked). Only residual: an UNARMED session (no active run) still allows a wrapper-obfuscated
  git-apply — the L0 floor's anchored-grep limitation, unchanged. The suite pins all of this
  (test-adversarial ga-unarmed + ga-armed rows).
- Notebook tool coverage: the secret-guard reads a superset of tool_input keys (file_path, path,
  glob, pattern) but NOT `notebook_path` — that key was added in T011.3 then dropped as dead code.
  The tool-name gate and the settings.json matcher are Read|Grep|Glob (Notebook tools are
  intentionally uncovered this milestone), and settings.json was not modified, so a `notebook_path`
  key would never be reached; covering NotebookRead/Edit is a future-milestone settings-wiring change.
- Run-id-armed-without-lock window: the stop gate arms on `current-run-id` alone, while the write
  guards (scope/bash-radius/postbash) require the compiled `scope.lock.json`. Between `dmc run start`
  and `dmc-scope-lock --compile`, Edit/Bash writes fall to the legacy current-scope.txt path, not L1.
- evidence-log "run is now BLOCKED" wording: the post-Bash feedback asserts BLOCKED before confirming
  the `dmc run block` marker write succeeded; if that write fails the message over-claims. This is
  cosmetic — the stop gate fail-closes independently (it re-reads blocked.json / receipts), so an
  unwritten marker cannot silently pass completion.
- settings.json: no new matcher/event registration was required (the existing wiring already routes
  the five events). Any FUTURE new registration would need a Claude Code session reload to take effect.
- Snapshot design: the arming `snapshot.txt` is pinned at `dmc run start` and NOT recaptured mid-run;
  the write-once operative-snapshot record binds its hash so a later baseline pre-seed is a detectable
  tamper (by design — a mutable baseline would be a laundering vector).
- bash-radius run-state deny message text still enumerates only four basenames although `snapshot.txt`
  is also enforced — cosmetic message drift, the enforcement set is correct.

## Package / Env / Migration Review

Package files changed: no
Env files changed: no
Migration files changed: no

Notes:
No package manifests, env files, or DB migrations touched. No network / live / model / API call; no
secret read (secret cases assert DENY by path only, never opening a file).

## Unresolved Risks

- Dirty-tree `selftest --all` drift, FULLY ACCOUNTED (benign, resolves on commit): on the
  uncommitted working tree the legacy aggregate reads 786 PASS / 19 FAIL / 3 N/A vs the pinned
  802 / 3 / 3 — a delta of +16 FAILs. Every one is an uncommitted-working-tree-drift / byte-pin
  check tripped by the M6 hook edits (chiefly `.claude/hooks/evidence-log.sh`). Per-script drift
  (dirty FAIL over baseline FAIL): v0.1.3 +1, v0.2 +2, v0.2.1 +2, v0.2.1.1 +1, v0.2.2 +1,
  v0.2.3 +2, v0.2.4 +1, v0.2.5 +1, v0.2.9 +1 (H4), v0.3.1 +1 (V12), v0.3.3 +1 (C9),
  v0.5.9 +1 (AC13 working-tree drift), v0.6.0 +1 (V15 working-tree drift) = +16 across 13 scripts.
  NOTE: this is broader than the initially-scoped "8 + 2" attribution — v0.2.9/v0.3.1/v0.3.3 also
  byte-pin `evidence-log.sh` and were verified as the remaining +3. All resolve on a committed tree.
- COMMITTED-REPLICA PROOF (closure, not deferred): a throwaway `cp -R` of the repo with
  `git add -A && git commit` IN THE COPY (real repo porcelain + HEAD verified byte-identical before
  and after) ran `bin/dmc selftest --all` and produced the legacy aggregate EXACTLY 802 PASS /
  3 FAIL / 3 N/A (originals-alone also reproduce 802/3/3) plus every new section at 0 FAIL and no
  clean module FAILs. The post-commit LIVE re-run of this same proof remains the standing closure
  condition at the release gate.
- git-apply wrapper obfuscation while UNARMED (no active run) still allows — the L0 anchored-grep
  boundary, unchanged this milestone; armed sessions close it (BASH-L1-WRAPPER-EXEC). Extending the
  static L0 floor to descend into shell wrappers would be a future hardening.

## Final Status

PASS
