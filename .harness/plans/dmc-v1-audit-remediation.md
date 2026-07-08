# Plan — DMC v1 Audit Remediation (pre-M10 consolidation)

## Goal

Apply the Tier 1+2+3 fixes from the 2026-07-08 full-project audit
(`.harness/evidence/dmc-v1-audit-20260708.md`) so the branch is consistent, security-hardened,
and ready to merge to `main` — with ZERO regression to the pinned legacy baseline (802/3/3) and
every non-frozen suite green. Scope is bounded to genuinely-safe minor fixes, three M6-hook
security-hardening fixes, two CI/ship-surface improvements, and NOTHING that touches the
mirror-pinned frozen legacy tools, the `.before-dmc` snapshots, the 3 human-accepted pinned
FAILs, or a validator's accept/reject contract.

## User Intent

Classification: **Mid-sized change** (consistency + security hardening + doc-accuracy remediation
across ~17 files; no new milestone feature). Not architecture, not a bug-hunt — a bounded
remediation of audit findings the human gated as Tier 1+2+3. Assumption Confidence: high (every
change traces to a specific, evidenced audit finding with a named minimal fix).

## Current Repo Findings

Source: `.harness/evidence/dmc-v1-audit-20260708.md` (7-lane Opus/Sonnet read-only audit). The
enforcement core is sound; findings are hardening/consistency/doc-accuracy. This plan implements
exactly the gated Tier 1+2+3 set:

- **B1** `bin/lib/dmc-delegation.py` — `is_secret_path` is the sole tool (of 11) missing the
  `service-account.json` branch its 10 siblings carry.
- **B2** `bin/lib/dmc-delegation.py` — `resolve_scope_lock_ref`/`_load_json_path_safe` join a
  path-like ref without a `..` guard (release-gate's `safe_repo_rel` rejects it).
- **C1** `.claude/hooks/pre-tool-guard.sh` — the Bash secret-read denylist covers only
  `cat`/`printenv`; `head/grep/base64/… .env` and `cp .env x`→`Read x` evade it (defense-in-depth
  gap; the CLAUDE.md instruction rule stays primary).
- **C2** `.claude/hooks/evidence-log.sh` — `redact()` misses AKIA/JWT/`xox`/`gh*_`/`ya29`/PEM/
  `Bearer`/`Authorization:` token classes, so a logged command line can persist a secret plaintext.
- **A3** `.claude/hooks/evidence-log.sh` — a post-Bash detector crash (exit ∉ {0,4}) passes
  silently instead of recording a soft block.
- **D4** `bin/lib/dmc-legacy-selftest.py` — `--check` flag is accepted but never branched on.
- **D7** `bin/dmc` — the `legacy)` dispatch doesn't `cd` to repo root (tools assume cwd=root).
- **E2** `.github/workflows/dmc-ci.yml` — CF3 model-name grep doesn't scan `.harness/schemas`.
- **E4** `orchestration/roles.json` — `strategic-orchestrator.session_binding` prose omits the
  read-only explorer/planner facets.
- **F1** `.claude/agents/{critic,explorer,planner,verifier,release-auditor}.md` — "Ring-1 …
  arrives in M6" is now false (M6 shipped `d721487`).
- **F2** `docs/CODEX_ADAPTER.md` — "nothing here is built until the M6.5 plan clears its gate"
  contradicts shipped M6.5.
- **F6** `docs/DMC_AGENT_HANDOFF.md` — stale "(v0.2.5)" title tag.
- **F7** `.github/workflows/dmc-ci.yml` — the hermetic non-frozen m6/m65/m7/m8 suites are only
  exercised inside the ADVISORY `--all`; they can be individually BLOCKING.
- **F8** `.github/workflows/dmc-ci.yml` — the bash -n glob lists `adapters/codex/*.sh` (dir has
  only .py) — a permanent no-op.
- **G1** `.claude/install/dmc-install.sh` + `INSTALL_MANIFEST.md` — the 6th canonical agent
  `release-auditor.md` (in roles.json + orchestration doc) is never shipped (`AGENTS=` lists 5).
- **G2** `.gitignore` (root) — the dev repo has ZERO secret-class ignore patterns.

## Relevant Files

Allowed to Edit (scope.lock files[] == this set; single-owner per file):

- `bin/lib/dmc-delegation.py` — edit, ordinary (B1, B2) — owner AR-T1
- `.claude/hooks/pre-tool-guard.sh` — edit, **enforcement (landmark-authorized)** (C1) — owner AR-T2
- `.claude/hooks/evidence-log.sh` — edit, **enforcement (landmark-authorized)** (C2, A3) — owner AR-T2
- `adapters/codex/dmc_codex_common.py` — edit, ordinary (C2 redaction-parity lockstep, critic-A1) — owner AR-T2
- `tests/fixtures/m6.5/_m65common.sh` — edit, ordinary (C2 redaction-parity lockstep, critic-A1) — owner AR-T2
- `.github/workflows/dmc-ci.yml` — edit, **enforcement (landmark-authorized)** (E2, F7, F8) — owner AR-T3
- `orchestration/roles.json` — edit, ordinary (E4) — owner AR-T4
- `.claude/agents/critic.md` — edit, ordinary (F1) — owner AR-T4
- `.claude/agents/explorer.md` — edit, ordinary (F1) — owner AR-T4
- `.claude/agents/planner.md` — edit, ordinary (F1) — owner AR-T4
- `.claude/agents/verifier.md` — edit, ordinary (F1) — owner AR-T4
- `.claude/agents/release-auditor.md` — edit, ordinary (F1) — owner AR-T4
- `docs/CODEX_ADAPTER.md` — edit, ordinary (F2) — owner AR-T4
- `docs/DMC_AGENT_HANDOFF.md` — edit, ordinary (F6) — owner AR-T4
- `.gitignore` — edit, ordinary (G2) — owner AR-T4
- `bin/lib/dmc-legacy-selftest.py` — edit, ordinary (D4) — owner AR-T4
- `bin/dmc` — edit, **enforcement (landmark-authorized)** (D7) — owner AR-T5
- `.claude/install/dmc-install.sh` — edit, **enforcement (landmark-authorized)** (G1) — owner AR-T6
- `INSTALL_MANIFEST.md` — edit, ordinary (G1 regen) — owner AR-T6
- `.harness/plans/dmc-v1-audit-remediation.md` — this plan (orchestrator lane)
- `.harness/evidence/dmc-v1-audit-remediation-build-20260708.md` — build evidence (create)
- `.harness/verification/dmc-v1-audit-remediation.md` — verification report (create)

## Out of Scope

- The mirror-pinned FROZEN legacy tools (`bin/lib/dmc-v0.*.{sh,py}`), the `.before-dmc` snapshots,
  and the 3 human-accepted pinned FAILs — NEVER edited.
- All DEFER-M10 findings: **A1** (eval/`$()` bash-guard bypass — needs a focused security plan +
  W-series reconciliation), **D1** (bare-`md5` false-PASS in ~20 frozen tools — NEW M10
  carry-forward), **CF14** (pyc litter), **A2/A4/A5/A6**, **B3/B4/B5**, **C3/C4/C5/C6/C7**
  (several touch the md5-identity-pinned `secret-paths.sh` triple), **E1/E3**, **F3/F4/F5** (the
  M10 v1.0 identity refresh), **G3/G4/G5**.
- No validator accept/reject contract change; no `.harness/schemas/*.md` contract edit; no
  `secret-paths.sh`/`secret-guard.sh` change (identity-pinned — C4/C5 deferred).
- No merge to `main` under this run (the merge is a separate, human-gated step AFTER this run
  closes green).

## Proposed Changes

**AR-T1 · `bin/lib/dmc-delegation.py`** — (B1) add `if "service-account" in base and
base.endswith(".json"): return True` to `is_secret_path`, byte-identical to the 10 siblings.
(B2) in `resolve_scope_lock_ref` (and/or `_load_json_path_safe`), reject any `ref` whose
normalized form contains a `..` segment before `os.path.join(root, ref)`, returning the existing
value-blind reason code (no new disclosure). Preserve the 41/0 self-test; add 2 self-test rows
(service-account path refused; `..` ref refused).

**AR-T2 · `.claude/hooks/pre-tool-guard.sh` + `.claude/hooks/evidence-log.sh`** (PROTECTED M6) —
(C1) broaden the inline secret-read command denylist to the verb set
`cat|head|tail|less|more|xxd|od|strings|base64|nl|sort|uniq|awk|sed|grep|rg|cp|install|dd|tee`
targeting `\.env`(non-example)/`~?/.ssh`/`~?/.aws`/`*.pem`/`*.key`, mirroring `is_secret_path`'s
classes; keep the existing L0 catastrophic/`git apply` floors byte-unchanged. (C2) extend
`evidence-log.sh redact()` to also mask `AKIA[0-9A-Z]{16}`, `eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+`,
`xox[baprs]-[A-Za-z0-9-]+`, `gh[opsu]_[A-Za-z0-9]+`, `ya29\.[A-Za-z0-9_-]+`, `-----BEGIN[^-]*
PRIVATE KEY-----`, and `(Authorization|Bearer)[: ]+\S+`. (A3) when the post-Bash detector exits
∉ {0,4}, record a soft block via `dmc run block` (or the existing marker path) so the stop gate
still holds — fail-closed. **Critic-A1 (redaction parity, MANDATORY):** the same redaction
transform is hand-copied in `adapters/codex/dmc_codex_common.py` `redact()` (docstring claims
"IDENTICAL to evidence-log.sh redact()") and `tests/fixtures/m6.5/_m65common.sh`
`evidence_log_redact()` — update ALL THREE in lockstep with the identical extended token set so the
codex host redacts the same classes and the m6.5 C3 parity test (which compares the adapter copy
vs the fixture copy) stays green AND true. **Critic-A5 (B2 precision):** B2 rejects only `..`
segments, NEVER absolute paths (self-tests A3/A7/A8 use absolute scope_lock_ref). **Critic-A4
(fixtures):** `tests/fixtures/hooks-v0.6.5/**` is a pinned PRE-M6 rollback snapshot (asserted ==
`git show 2999870:…` by test-rollback.sh, which is NOT in `run_m6_suite`) and MUST be left
untouched — no in-`run_m6_suite` fixture pins live hook bytes, so the "update fixture" conditional
resolves to a no-op. m6-suite (m6-core 99/0 + m6-suite 104/0) + m65-suite (35/0, incl. C3 parity)
MUST stay green; keep the L0 catastrophic/git-apply floors byte-unchanged.

**AR-T3 · `.github/workflows/dmc-ci.yml`** — (E2) add `.harness/schemas` to the CF3 model-name
`grep -RInE` path list. (F8) drop the `adapters/codex/*.sh` glob from the bash -n step. (F7) add
individual BLOCKING steps `bin/dmc selftest m6-suite`, `… m65-suite`, `… m7-suite`, `… m8-suite`
BEFORE the advisory `--all` (each must be confirmed green on the ubuntu runner; if any is
runner-fragile, leave it in the advisory tier and record why). Keep the advisory legacy `--all`
tail unchanged.

**AR-T4 · docs/config/agents/gitignore** — (E4) reword `roles.json`
`strategic-orchestrator.session_binding`. (F1) fix the "arrives in M6" line in all 5 agent files
to "enforced since M6 (`dmc bash-radius`, wired at pre-tool-guard.sh)". (F2) replace
`CODEX_ADAPTER.md`'s top framing with a "Status: IMPLEMENTED (M6.5, Option A advisory)" note.
(F6) drop/bump the `DMC_AGENT_HANDOFF.md` "(v0.2.5)" title. (G2) append the secret-class pattern
set (`.env` + `.env.*` except `.example/.sample/.template/.dist`; `*.pem *.key id_rsa id_ed25519
*.p12 *.pfx *.keystore *.ppk *.p8`; `.npmrc .netrc .pgpass credentials.json *service-account*.json`;
`**/.ssh/ **/.aws/credentials **/.gnupg/`) to root `.gitignore`. (D4) **Critic-A2 (MANDATORY):**
do NOT remove `--check` — `bin/dmc:431` execs `mirror --check`, so removal would break
`dmc mirror-check` (repairing it would force a bin/dmc edit owned by AR-T5). KEEP `--check` and add
a one-line comment documenting it as the explicit alias of the default mirror behavior; aggregator
behavior + the `bin/dmc … mirror --check` call stay working.

**AR-T5 · `bin/dmc`** — (D7) in the `legacy)` case, `cd` to repo root (`cd "$(cd "$HERE/.." &&
pwd)"`) before `exec bash "$HERE/lib/$tool" "$@"`, matching the aggregator's cwd pinning. No other
verb touched; default `selftest` 75/0 + linkcheck must stay green.

**AR-T6 · `.claude/install/dmc-install.sh` + `INSTALL_MANIFEST.md`** — (G1) add
`release-auditor.md` to `AGENTS=`, then regenerate `INSTALL_MANIFEST.md` via
`--emit-manifest` (expect exactly +1 agent line). install-suite (m8-suite 126/0, incl.
manifest-drift byte-equality) MUST stay green.

## Acceptance Criteria

- Criterion: (AC1) Every listed fix (B1,B2,C1,C2,A3,D4,D7,E2,E4,F1,F2,F6,F7,F8,G1,G2) is present
  and does exactly what the audit finding specified; no out-of-scope edit; diff⊆scope.
  Verification Method: `git diff` reviewed against §Proposed Changes + scope.lock.
- Criterion: (AC2) No regression across non-frozen suites: `bin/dmc selftest` 75/0; `selftest
  delegation` 43/0 (41 base +2 new rows); `selftest m6-suite` green (m6-core 99/0 + m6-suite
  104/0); `selftest m7-suite` 85/0; `selftest m8-suite` 126/0 (manifest-drift byte-equality green
  after regen); `selftest m9-suite` 91/0; `selftest release-gate` 39/0; `mirror-check` green;
  `linkcheck` clean.
  Verification Method: run each named selftest, capture PASS/FAIL counts.
- Criterion: (AC3) Frozen baseline intact — committed-replica `bin/dmc selftest --all` reproduces
  legacy 802/3/3 EXACT, all non-legacy sections 0 FAIL.
  Verification Method: committed-replica `selftest --all` run on the committed tree.
- Criterion: (AC4) Security fixes proven AND no over-block (critic-A3) — a synthetic `head .env`/
  `grep KEY .env`/`base64 .env`/`cp .env x`→`Read x` probe is DENIED by the broadened pre-tool-guard
  denylist; AND benign uses of every newly-added verb on NON-secret paths (`grep foo src/x.py`,
  `sed -i.bak s/a/b/ build.log`, `cp a.txt b.txt`, `awk … build.log`, `head README.md`) still
  return empty-stdout ALLOW; a synthetic JWT/AKIA/`xox`/`gh_`/Bearer in a logged command is REDACTED
  in the evidence line (and in the codex-adapter + m6.5-fixture copies, per critic-A1); a forced
  detector non-{0,4} exit records a soft block.
  Verification Method: targeted value-blind negative-control probes (both deny AND allow sets) in a
  scratch dir (no real secrets); the m6/m7/m8 harness command lines are not collaterally denied.
- Criterion: (AC5) CI green on branch after push — all blocking steps (incl. the newly-blocking
  m6/m65/m7/m8 suites + the CF3 grep now covering schemas) pass; advisory `--all` unchanged.
  Verification Method: GitHub Actions run conclusion = success on the pushed HEAD.
- Criterion: (AC6) `git status --porcelain` clean post-commit; INSTALL_MANIFEST diff = exactly +1
  line.
  Verification Method: porcelain + manifest diff review.

## Risks

- Protected-hook regression (C1/C2/A3 on pre-tool-guard.sh + evidence-log.sh): a broadened
  denylist could over-block a legitimate command, or a hook byte-pin fixture could break.
  Mitigation: m6-suite re-run + negative-control probes; keep L0 floors byte-unchanged; update any
  in-scope fixture and re-prove.
- Installer/manifest drift (G1): adding an agent could desync the manifest-drift byte-equality.
  Mitigation: regenerate via `--emit-manifest`; m8-suite manifest-drift must be green.
- CI newly-red (F7): promoting the m6-m8 suites to blocking could surface a runner-portability
  issue. Mitigation: confirm each green on the runner; fall back to advisory + record if fragile
  (workflow-file-only, same fix-forward authority as M9's CI iterations).
- delegation self-test regression (B1/B2). Mitigation: +2 rows, keep 41/0 base green.

## Assumptions

- The m6-m8 suites are hermetic (mktemp) and pass on ubuntu (they were green inside `--all`'s
  non-legacy sections on CI). If F7 reveals otherwise, that suite stays advisory with a recorded
  reason — not a blocker for the rest.
- `evidence-log.sh`/`pre-tool-guard.sh` logic changes take effect per-invocation (no
  settings.json re-registration needed — registration is unchanged).
- The audit findings are accurate as evidenced; the executor re-reads each site before editing.

## Execution Tasks

- [ ] DMC-T017.1: (Opus) bin/lib/dmc-delegation.py — B1 service-account branch + B2 `..` guard, +2
  self-test rows.
  Files: bin/lib/dmc-delegation.py.
  Acceptance: AC1/AC2/AC4. Verification: `bin/dmc selftest delegation` (43/0). Rollback: git revert
  the file (additive). Evidence: build log delegation section. Not-edit: any other file / the schema
  contract. Risk: self-test regression (low). No blockedBy. SOLE owner.
- [ ] DMC-T017.2: (Opus, PROTECTED M6) .claude/hooks/pre-tool-guard.sh (C1) + .claude/hooks/
  evidence-log.sh (C2,A3) + the two redaction-parity siblings (critic-A1).
  Files: .claude/hooks/pre-tool-guard.sh, .claude/hooks/evidence-log.sh,
  adapters/codex/dmc_codex_common.py, tests/fixtures/m6.5/_m65common.sh.
  Acceptance: AC1/AC2/AC4. Verification: `bin/dmc selftest m6-suite` + `m65-suite` (35/0, incl. C3
  parity) green + AC4 probes (both deny AND allow sets). Rollback: git revert the four files
  (logic-only, additive). Evidence: build log hooks section + probe output. Not-edit: the L0
  catastrophic/git-apply floors; secret-paths.sh; settings.json; hooks-v0.6.5 fixture (pinned
  pre-M6, untouched). Risk: over-block / redaction-parity drift (medium — mitigated by m6/m65-suite
  + the allow-set probes). No blockedBy. SOLE owner (all four).
- [ ] DMC-T017.3: (Sonnet) .github/workflows/dmc-ci.yml — E2 CF3 schemas path + F8 dead glob drop
  + F7 blocking m6/m65/m7/m8-suite steps.
  Files: .github/workflows/dmc-ci.yml.
  Acceptance: AC1/AC5. Verification: YAML parse + local `selftest m6/m65/m7/m8-suite` green; CI
  green post-push. Rollback: git revert the workflow. Evidence: build log CI section. Not-edit: the
  advisory `--all` tail; env/pin/fetch-depth steps. Risk: CI newly-red (medium — workflow-file-only
  fix-forward authority). No blockedBy. SOLE owner.
- [ ] DMC-T017.4: (Sonnet) docs/config/agents/gitignore mechanical — E4 + F1(×5) + F2 + F6 + G2 + D4.
  Files: orchestration/roles.json, .claude/agents/critic.md, .claude/agents/explorer.md, .claude/
  agents/planner.md, .claude/agents/verifier.md, .claude/agents/release-auditor.md, docs/
  CODEX_ADAPTER.md, docs/DMC_AGENT_HANDOFF.md, .gitignore, bin/lib/dmc-legacy-selftest.py.
  Acceptance: AC1/AC2. Verification: `bin/dmc selftest` 75/0 + `roles`/`linkcheck` green +
  `git check-ignore` on a sample secret path. Rollback: git revert each file. Evidence: build log
  docs/config section. Not-edit: any schema contract; frozen tools. Risk: linkcheck/roles
  regression (low). No blockedBy. SOLE owner (each file).
- [ ] DMC-T017.5: (Sonnet) bin/dmc — D7 `cd` to repo root in the `legacy)` dispatch.
  Files: bin/dmc.
  Acceptance: AC1/AC2. Verification: `bin/dmc selftest` 75/0 + `bin/dmc legacy v0.2-verify` from a
  subdir resolves root. Rollback: git revert bin/dmc. Evidence: build log bin/dmc section. Not-edit:
  any other verb. Risk: verb-dispatch regression (low). No blockedBy. SOLE bin/dmc owner.
- [ ] DMC-T017.6: (Opus) .claude/install/dmc-install.sh (G1) + INSTALL_MANIFEST.md regen.
  Files: .claude/install/dmc-install.sh, INSTALL_MANIFEST.md.
  Acceptance: AC1/AC2/AC6. Verification: `bin/dmc selftest m8-suite` 126/0 (manifest-drift green);
  manifest diff = +1. Rollback: git revert both. Evidence: build log installer section. Not-edit:
  the installer's Ring-0/1 copy logic beyond AGENTS=; the gitignore here-doc (G3 is DEFER-M10). Risk:
  manifest drift (low — regenerated). blockedBy: none (independent). SOLE owner.

## Verification Commands

- `bin/dmc validate plan .harness/plans/dmc-v1-audit-remediation.md` → VALID
- `git diff --stat` + per-file `git diff` review vs scope.lock (diff⊆scope; AA3 files[]==modified set)
- `bin/dmc selftest` (75/0) · `selftest delegation` (43/0) · `selftest m6-suite` · `selftest
  m7-suite` (85/0) · `selftest m8-suite` (126/0) · `selftest m9-suite` (91/0) · `selftest
  release-gate` (39/0) · `mirror-check` · `linkcheck`
- committed-replica `bin/dmc selftest --all` → legacy 802/3/3 EXACT + all sections 0 FAIL
- AC4 negative-control probes (secret-read deny, redaction, fail-closed) in a scratch dir
- post-push: GitHub Actions run conclusion = success

## Approval Status

Status: APPROVED (Rev 2)
Approver: wjlee (woojin20020@gmail.com) — human scope gate (Tier 1+2+3, AskUserQuestion 2026-07-08)

Scope human-gated (wjlee, Tier 1+2+3) + critic r1 APPROVE (advisory, 0
blockers, plan_hash `41f5c830…`, `.harness/evidence/dmc-v1-audit-remediation-critic-r1.json`); the five advisories are
folded into Rev 2: A1 (redaction-parity lockstep across the 3 copies — +2 files to AR-T2, MANDATORY),
A2 (D4 keep `--check` as alias, never remove — MANDATORY), A3 (AC4 adds the benign-verb allow-set
negative controls), A4 (hooks-v0.6.5 pinned pre-M6, untouched — conditional is a no-op), A5 (B2
rejects `..` only, never absolute). The Tier 1+2+3 SCOPE was human-approved (wjlee, 2026-07-08,
AskUserQuestion) prior to this plan; the Rev 2 A1 scope addition (dmc_codex_common.py +
_m65common.sh) is in service of doing C2 correctly (preserving the redaction-parity invariant the
audit's C2 fix would otherwise silently break), disclosed at the build/commit gate.
