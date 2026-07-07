# Verification Report

## Run ID

dmc-run-fe05b840460e

(Milestone verification for DMC v1 §M6.5 — the Codex adapter build tasks DMC-T011b.2–.5, run under
the armed build run `dmc-run-fe05b840460e` (SUSPENDED wait-state; 23-file scope.lock at HEAD
`40ad75a`). The spike phase T011b.1 was verified separately under `dmc-run-8fef31d58eee`
(`.harness/verification/dmc-run-8fef31d58eee.md`, ACCEPT). Line 1 above is the bare active run id.)

## Plan

.harness/plans/dmc-v1-m6.5-codex-adapter.md (Rev 2; APPROVED 2026-07-06 by wjlee via AskUserQuestion.
Critic chain r1 REJECT (4 blockers B1–B4, plan_hash 9d8562bd…) → Rev 2 → r2 APPROVE (plan_hash
b02b1554…); the spike STOP handed the reduced scope to the human gate, which chose **Option A**
(advisory shims), recorded in `.harness/evidence/dmc-v1-m6.5-spike-stop.md` §Human gate decision.)

## Changed Files

- bin/dmc: SOLE M6.5 edit (A1) — registers the agents-md + skills-mirror verbs, run_m65_suite(), both named selftest sections + the m65-suite aggregate, wired into --all; fast default preserved
- .agents/skills/dmc-critic/SKILL.md: Codex skill binding (Codex-standard frontmatter + host-note; operative payload byte-identical to the Claude counterpart) (new)
- .agents/skills/dmc-plan-hard/SKILL.md: Codex skill binding (new)
- .agents/skills/dmc-start-work/SKILL.md: Codex skill binding (new)
- .agents/skills/dmc-status/SKILL.md: Codex skill binding (new)
- .agents/skills/dmc-verify-hard/SKILL.md: Codex skill binding (new)
- .codex/config.toml: per-project Codex wiring (advisory + trust header; workspace-write; hooks/multi_agent default-on) (new)
- .codex/hooks.json: wires the four bound events to the shims (new)
- .harness/schemas/agents-md.schema.md: dmc.agents-md.v1 content contract (native schema; contract landmark authorized in scope.lock) (new)
- adapters/codex/README.md: advisory-status adapter home (new)
- adapters/codex/dmc-codex-posttooluse.py: PostToolUse shim → dmc postbash-diff + dmc run block + redacted evidence append (new)
- adapters/codex/dmc-codex-pretooluse.py: PreToolUse shim → dmc bash-radius / dmc-scope-lock --adjudicate / path-only secret deny (new)
- adapters/codex/dmc-codex-stop.py: Stop shim → dmc stop-gate quick (state-based, Claude-parity on all inputs) (new)
- adapters/codex/dmc-codex-userpromptsubmit.py: UserPromptSubmit natural-activation router (not a gate) (new)
- adapters/codex/dmc_codex_common.py: shared Ring-1 translation library (superset field read, mode, arming, redact(), path-only secret set, envelopes) (new)
- bin/lib/dmc-agents-md.py: host AGENTS.md generator + validator (the /dmc-init-deep generator, A4) (new)
- bin/lib/dmc-skills-mirror.py: .agents/.claude skills mirror/drift module (module + fixtures only; no bin/dmc edit) (new)
- tests/fixtures/m6.5/_m65common.sh: shared M6.5 suite helpers (new)
- tests/fixtures/m6.5/test-agents-md.sh: AGENTS.md generator + validator suite (new)
- tests/fixtures/m6.5/test-codex-shims.sh: Codex shim happy-path + B2 fail-closed + B3 redaction + cross-adapter parity suite (new)
- tests/fixtures/m6.5/test-skills-mirror.sh: skills mirror/drift suite (new)

(The two T011b.5 deliverables — .harness/evidence/dmc-v1-m6.5-build-20260707.md and this report — plus
the run-dir state and auto-logged evidence ledgers fall under the .harness/evidence//verification//runs/
internal exemption and are not re-declared here. The disclosed pre-existing dirty file
.harness/verification/dmc-run-8fef31d58eee.md — the run #1-report fix — is also exemption-covered and
clears at the phase commit.)

## Commands Run

| Command | Result | Reason | Output Summary |
|---|---|---|---|
| tests/fixtures/m6.5/test-codex-shims.sh (standalone) | PASS | happy-path + B2 fail-closed (a)–(d) + B3 redaction/parity + cross-adapter parity incl. malformed (D10–D15) + passive/off stand-down | 65 PASS / 0 FAIL, exit 0 |
| tests/fixtures/m6.5/test-skills-mirror.sh (standalone) | PASS | mirror/drift over the five bound skills + negative controls | 19 PASS / 0 FAIL, exit 0 |
| tests/fixtures/m6.5/test-agents-md.sh (standalone) | PASS | generator over node/python/empty hosts + Unknown rule + 32 KiB warn + validator refusals | 35 PASS / 0 FAIL, exit 0 |
| bin/dmc selftest m65-suite | PASS | M6.5 aggregate (codex-shims 65 + skills-mirror 19 + agents-md 35) | 119 PASS / 0 FAIL, exit 0 |
| bin/dmc selftest skills-mirror | PASS | module self-test: seeded one-byte drift REFUSED + named; missing counterpart REFUSED; unterminated BEGIN fails closed; extra dmc-* dir REFUSED | 7 PASS / 0 FAIL, exit 0 |
| bin/dmc selftest agents-md | PASS | module self-test: Unknown literal, non-truncation, deterministic bytes, validator refusals | 24 PASS / 0 FAIL, exit 0 |
| bin/dmc mirror-check | PASS | legacy bin/lib ↔ .harness/evidence byte-equality untouched | 55-file byte-equality green, exit 0 |
| bin/dmc linkcheck | PASS | no dangling dmc-verb / artifact-path / role reference across skills+adapters+docs | clean, 24 files scanned, exit 0 |
| bin/dmc selftest linkcheck | PASS | hermetic orchestration link-check + arm-run-id pre-run | 17 PASS / 0 FAIL, exit 0 |
| model-name self-scan (grep over adapters/codex/, bin/lib/dmc-{agents-md,skills-mirror}.py, .codex/, .agents/) | PASS | Ring-0 stays model-name-free (capability classes only) | 0 hits |
| bin/dmc selftest (fast default) | PASS | no-arg default floor preserved by the bin/dmc edit | 75 PASS / 0 FAIL, exit 0 |
| degraded-invariant substring grep over this report (unified_exec gap; post-Bash diff guard = primary Codex net) | PASS | A3 machine-checkable degradation record — both required substrings present | 2/2 substrings found, exit 0 |
| committed-replica bin/dmc selftest --all (throwaway tar-replica + git commit in the copy; real repo untouched) | PASS | pinned baseline + all new sections 0 FAIL (details in Manual Checks) | legacy tools=49 PASS=802 FAIL=3 N/A=3 EXACTLY; new sections 0 FAIL; SELFTEST-ALL RESULT: PASS, exit 0 |
| python3 -m py_compile (adapters/codex/*.py, bin/lib/dmc-agents-md.py, bin/lib/dmc-skills-mirror.py) | PASS | python syntax floor | OK |
| bash -n (tests/fixtures/m6.5/*.sh, bin/dmc) | PASS | shell syntax floor | clean |

## Manual Checks

| Check | Result | Notes |
|---|---|---|
| Turn-free-proof determination (B4) | PASS | at codex-cli 0.132.0 hooks-fire + envelope-honoring are UNPROVABLE turn-free; offline `codex exec` reaches the model websocket (401) with no hook markers; no headless hook emit/replay surface. Recorded in the spike findings + STOP artifact |
| STOP + Option A decision chain | PASS | plan B4 → STOP artifact `.harness/evidence/dmc-v1-m6.5-spike-stop.md` written → human gate (wjlee, AskUserQuestion) chose Option A (advisory shims); Option B live-turn verification deferred to a separate human gate; Option C (defer) not taken |
| Advisory status — NO enforcement-parity claim on Codex | PASS | stated in adapters/codex/README.md, .codex/config.toml header, and every shim docstring; the pre-commit/CI gate is the documented Codex enforcement boundary; the M6 post-Bash diff guard is the primary Codex safety net |
| Active-mode controlled divergence (B2 fail-closed) | PASS | Codex shims fail CLOSED on malformed/renamed/absent input where Claude shims fail OPEN — asserted by fixtures D11–D15; byte-parity everywhere else (D-series); passive/off stand-down identical (D10, E-series) |
| Committed-replica --all == pinned baseline + new sections | PASS | legacy aggregate EXACTLY tools=49 PASS=802 FAIL=3 N/A=3 (the 3 accepted FAILs: v0.1.3 GLM-grep, v0.2.3 V5, v0.3.2 AC5) + originals-alone reproduce 802/3/3; run-core 168/0, loop-core 78/0, roles 19/0, verdict-validate 16/0, verdict-gate 9/0, delegation 29/0, linkcheck 17/0, m6-core 99/0, m6-suite 104/0, skills-mirror 7/0, agents-md 24/0, m65-suite 119/0, mirror-check + rollback-test PASS; SELFTEST-ALL RESULT: PASS, exit 0 |
| Real repo untouched by replica work | PASS | before: HEAD 40ad75a, porcelain-sha 5eb39d41…; after: HEAD 40ad75a unchanged, and porcelain excluding the two authorized T011b.5 deliverables is byte-identical to 5eb39d41…; replica built by tar pipe into the scratchpad, committed + selftested there only |
| Human gate provenance | PASS | wjlee via AskUserQuestion ×2 (Rev 2 milestone approval; spike-STOP Option A reduced-scope decision) — both recorded (plan Approval Status; STOP artifact §Human gate decision) |
| Authoring/verification lane separation (C11) | PASS | this report is the implementer's evidence record; it makes no approval and opens no gate; completion is the Verifier's call and release the human gate's |

## Degraded Invariants (Codex)

These are the milestone's degraded invariants under Option A, recorded as machine-checkable
assertions (not narrative only) so they cannot silently vanish from the record. They map to
`docs/CODEX_ADAPTER.md` §3 and are re-asserted verbatim in `adapters/codex/README.md` and
`dmc_codex_common.py`:

- (i) **unified_exec / non-shell evasion residual gap** — Codex `PreToolUse` is explicitly
  non-airtight: `unified_exec` streaming shells are stable and enabled by default at codex-cli
  0.132.0, so a write can reach the filesystem via a non-shell / unified_exec path that `PreToolUse`
  does not observe. This evasion gap is a KNOWN, standing degradation, never claimed closed.
- (ii) **the post-Bash diff guard is the LOAD-BEARING primary Codex safety net (not a backstop)** —
  because of (i), the M6 post-Bash / post-turn `git diff` guard is what actually catches an
  out-of-scope write on a Codex host; it is the primary safety net, not a secondary backstop, and
  the pre-commit/CI gate is the documented enforcement boundary. No PreToolUse enforcement parity
  with the Claude adapter is claimed on Codex.

Machine check (recorded PASS in Commands Run): a substring grep over this report finds both
`unified_exec` (residual-gap statement (i)) and the `post-Bash diff guard` + `LOAD-BEARING primary
Codex safety net (not a backstop)` phrase (statement (ii)); the check FAILS if either is absent.

Additional recorded degradations (from the spike per-fact disposition, carried forward):
- `tool_input` per-tool field names remain TBD (no turn-free schema dump) — every field read is a
  case-insensitive superset; a renamed field degrades to fail-closed-in-active (B2 case b), and the
  PreToolUse edit-scope field shim is backstop-only behind the post-Bash diff guard.
- B2 case (c) (Ring-0 verdict CLI absent → fail-closed) is N/A for Read/Grep/Glob — their secret
  decision is in-process (path-only), with no external Ring-0 CLI to be absent (fixture note B5).

## Scope Review

Result: PASS

Notes:
All applied edits lie within the `dmc-run-fe05b840460e` scope.lock (23-file allowlist; the 21
non-exempt dirty paths enumerated under Changed Files each adjudicate in-scope, plus the two
exemption-covered T011b.5 deliverables). No `.claude/**` or other protected-surface edit — the
`.claude/hooks/**` redaction contract (`evidence-log.sh redact()`, `pre-tool-guard.sh` secret floor,
`secret-guard.sh` path-only) is CONSUMED read-only for B3, never edited. `orchestration/roles.json`
consumed read-only. The single `bin/dmc` edit is the milestone's SOLE `bin/dmc` change (A1).

`git diff --name-only` vs the plan allowlist accounting: the tracked modified files are `bin/dmc`
(in scope, edit grant) and `.harness/verification/dmc-run-8fef31d58eee.md` (the disclosed run
#1-report fix — an internal-exemption path awaiting the phase commit, NOT a milestone deliverable and
correctly outside this build's file allowlist). Untracked additions are the M6.5 build files (all in
scope) plus DMC-internal local-only artifacts (`.harness/runs/dmc-run-*/`, the auto-logged
`.harness/evidence/dmc-run-*.md` ledgers, and `.harness/runs/dmc-v1-m{3,4,5}-*.md`) which are
local-only per policy and exemption-covered by the crosscheck.

## Package / Env / Migration Review

Package files changed: no
Env files changed: no
Migration files changed: no

Notes: no dependency manifest, environment file, or DB migration touched. No network / live / model /
API call anywhere in the build or verification (the spike attested no live turn, no API key read). No
secret file contents opened — secret cases decide by path only.

## Unresolved Risks

- Hook firing + decision-envelope honoring on Codex remain UNPROVEN (turn-free unprovable at codex-cli
  0.132.0) — accepted by design under Option A: the shims are ADVISORY, the pre-commit/CI gate is the
  Codex enforcement boundary, and the post-Bash diff guard is the primary safety net. Option B (a
  one-time, human-run, explicitly-consented live-turn verification) remains available under a separate
  human gate; nothing here authorizes a live turn.
- `verify-crosscheck` against the SUSPENDED build run on a not-yet-committed working tree: unlike the
  spike-phase run #1 (which had out-of-scope pre-run tracked edits and therefore held until its phase
  commit), THIS run's every dirty non-exempt path adjudicates in-scope and the one pre-existing dirty
  tracked file (`.harness/verification/dmc-run-8fef31d58eee.md`, the run #1-report fix) is covered by
  the crosscheck's `.harness/{evidence,verification,runs}/` internal exemption — so the crosscheck
  ACCEPTED here without needing the phase commit. The phase commit (staging the build) remains a
  separate human release gate and is NOT taken in this milestone.
- verify-crosscheck verdict (verbatim, run against this report + `.harness/runs/dmc-run-fe05b840460e`):
  `ACCEPT: verification report is structurally valid, run-bound, in-scope, and honest` (exit 0).

## Final Status

PASS — under the Option A reduced scope (advisory Codex shims; NO enforcement-parity claim on Codex).
The non-enforcement deliverables proven viable turn-free (skills bindings + mirror, AGENTS.md
generator + schema) and the advisory shims (same Ring-0 verdict CLIs, same envelopes, fail-closed in
active, B3 secret redaction) are all built and green: m65-suite 119/0, module self-tests 7/0 + 24/0,
committed-replica selftest --all == pinned baseline (802/3/3) with every new section 0 FAIL and
SELFTEST-ALL exit 0, model-name scan clean, and the required Degraded Invariants (Codex) assertions
present and grep-verified. Enforcement parity on Codex is explicitly NOT claimed.
