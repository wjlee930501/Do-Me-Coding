# Plan: DMC Direction Re-alignment — Codex Adapter / Fable Pattern Transfer

Plan ID: dmc-v0.5-codex-adapter-direction · Date: 2026-07-06 · Format: PLAN_SCHEMA.md
**Rev 2** — revised after DMC critic REVISE (advisory verdict R1, `dmc.critic-verdict.v1`,
persisted at `.harness/evidence/dmc-v0.5-direction-critic-verdict-r1.json`). Blockers closed:
(B1) post-Bash diff-guard exemption narrowed — run-state files (`scope.lock.json`,
`approvals.jsonl`, `run.json`) explicitly DENIED, canonical fixture (2) preserved;
(B2) Rev 3 amendment now includes the master plan's authorization bookkeeping (Relevant Files
rows, P-coverage map P21 entry, M8 spike-line supersession) and the installer `--host` work is
assigned to M8, not M6.5; (B3) M7-after-M8 manifest-drift consequence addressed via an M7
authorization extension + recorded interim risk. Optional items O1–O4 also applied.
Version-label note: the strategic brief names this direction "DMC v0.5". The repo has since
shipped v0.5.x/v0.6.x and is mid-v1.0 (M1–M5 shipped on `claude/dmc-v1-runtime-upgrade-c5uch1`,
M6–M10 unapproved). This plan keeps the brief's requested filename but lands its content as a
**re-sequencing of the v1 milestone track**, not a parallel version line. It is a
**direction/planning plan**: when approved it authorizes docs + plan-file edits ONLY — every
implementation milestone it sequences (M6, M6.5) still requires its own milestone-scoped plan,
critic pass, and human gate (the M4/M5 pattern).

## Goal

Re-align DMC so the next milestones make DMC usable by Codex CLI as a **host harness** (not only
Claude Code), while (a) leaving the core loop — Goal → Intent Gate → Repo Scan → Plan → Critic →
Scope Lock → Execute → Verify → Fix Loop → Evidence → Report → Continue/Stop — untouched,
(b) finishing the enforcement wiring that BOTH adapters depend on (M6) first, and
(c) explicitly deprioritizing Worker Bridge expansion. Concretely: promote the Codex adapter
from an M8 timeboxed spike to a first-class milestone (M6.5), add the brief's post-Bash diff
guard to M6's scope, correct the stale "Codex has no Stop hook" assumption with verified 2026
facts, and assign the host-AGENTS.md content contract a home (M6.5).

Direction answers required by the brief (decision record):

1. **What should DMC v0.5 become?** The brief's "v0.5" is, in current versioning, the v1 track
   re-sequenced: DMC becomes a two-host disciplined execution harness — one model/host-agnostic
   Ring-0 core (`bin/dmc` + schemas + `.harness` lifecycle + `orchestration/`), a full Claude
   Code adapter, and a first-class minimal Codex adapter. Fable-observed working patterns stay
   encoded as runtime primitives (M4/M5, already shipped) and enforcement rails (M6), never as
   copied prompt text.
2. **What remains DMC Core?** `bin/dmc` + `bin/lib/*` (run-lifecycle, scope-lock, approvals,
   evidence ledger, fixloop, instance validators, repo intel, verdict/delegation validators),
   root `*_SCHEMA.md` + `.harness/schemas/`, `orchestration/roles.json`, `.harness/` artifact
   conventions. Zero host/model names (v0.6.1 self-scan invariant).
3. **What belongs to the Claude Adapter?** `.claude/hooks/*`, `.claude/settings.json`,
   `.claude/skills/*`, `.claude/agents/*`, the installer's Claude path. M6 turns the hooks into
   shims over Ring-0 verdict CLIs.
4. **What belongs to the Codex Adapter?** `adapters/codex/` (hook shims translating Codex hook
   events → the SAME Ring-0 verdict CLIs), `.codex/` config + hooks.json templates,
   `.agents/skills/dmc-*` skill bindings, the host-AGENTS.md generation contract. The installer
   `--host codex|claude|both` path is M8's (P19) job — M6.5 ships adapter content/templates,
   M8 ships them to hosts (avoids building on the pre-P19 installer M8 reworks). NOT
   load-bearing: Codex `.rules` (experimental), `requirements.toml` (enterprise-only),
   subagent auto-dispatch (Codex is explicit-only).
5. **What should be postponed?** Worker Bridge expansion (old M7 hardening re-sequenced after
   M8; no new providers), the real-repo A/B benchmark harness (P5 — design deferred post-M9),
   OpenCode adapter, model router, independent CLI/daemon/web UI.
6. **Smallest useful next changes?** Four planning/docs artifacts: master plan Rev 3 amendment,
   `docs/CODEX_ADAPTER.md`, the M6 milestone plan, the M6.5 milestone plan. No code.
7. **What files first?** Exactly the four above (see Execution Tasks).
8. **How will we verify?** `bin/dmc validate plan` on every plan touched/created,
   `bin/dmc linkcheck`, `bin/dmc selftest` default unchanged (75/0), no file outside the
   authorized list in `git diff --name-only`, critic verdict artifact schema-valid.

## User Intent

Classify: **docs** (secondary aspect: planning — milestone re-sequencing; no product code,
no hooks, no schemas, no bin/ edits under this plan).

## Current Repo Findings

- Finding: Ring-0 is already host-agnostic — `bin/dmc` + `bin/lib/*.py` contain zero Claude
  references and no Claude Code runtime dependency; a Codex adapter is a greenfield Ring-1
  event-binding shim, not a core rewrite.
  Source: session grep over `bin/dmc`, `bin/lib/*.py` (arch survey, 2026-07-06); `docs/DMC_V1_RUNTIME_ARCHITECTURE.md` §0.1 three-ring model.
- Finding: M4/M5 primitives (immutable `scope.lock.json`, typed approvals, receipt ledger,
  fixloop, roles registry) are shipped but dormant — live enforcement is still the six v0.x
  hooks; `scope-guard.sh` matches `Edit|Write` only against legacy `current-scope.txt`; the only
  PostToolUse hook is the `evidence-log.sh` logger; M6 is the wiring milestone.
  Source: `.claude/settings.json`; `.claude/hooks/scope-guard.sh`; `bin/lib/dmc-scope-lock.py` docstring; master plan §M6.
- Finding: Priority 1 (Codex adapter) is NOT PRESENT but already designed — no `adapters/`,
  `.codex/`, `.agents/`, or `docs/CODEX_ADAPTER.md` exist; the master plan carries it only as
  M8's "Codex minimal binding spike (timeboxed)"; `docs/INTEROP.md` covers LazyCodex/OmO, not
  Codex CLI; `_DMC_CODEX_*.md` files are build-DMC-from-scratch prompts (opposite direction).
  Source: repo listing 2026-07-06; `.harness/plans/dmc-v1-runtime-upgrade.md` §M8, §Assumptions; `docs/INTEROP.md`.
- Finding: Priority 2 (Bash diff scope guard) is the unstarted M6 DMC-T011 verbatim on its
  pre-classification half (Bash write-radius classifier, `git apply`/`patch` deny); the brief's
  POST-Bash detection half (`git diff --name-only` vs locked scope after Bash, run → BLOCKED)
  appears in no milestone.
  Source: master plan §M6 DMC-T011; `.claude/settings.json` PostToolUse block.
- Finding: Priority 3 (verification artifact validator) is PARTIALLY shipped —
  `dmc validate verification` (M3) enforces structure (9 required sections, Scope Review
  Result:, PEM lines, Final Status token) but is wired to no hook; `stop-verify-gate.sh` is
  existence-only and keyword-triggered (a FAIL report satisfies it); semantic cross-checks
  (run-id match, changed-files vs git, PASS-forbidden-on-failed-required, files⊆scope) exist
  nowhere. M6's receipt-coverage stop gate covers part; the semantic report validator is a gap.
  Source: `bin/lib/dmc-instance-validate.py` validate_verification(); `.claude/hooks/stop-verify-gate.sh`; master plan §M6.
- Finding: Priority 4 (host AGENTS.md) has policy but no contract —
  `docs/HOST_REPO_ADAPTATION_POLICY.md` forbids blind-copying DMC's AGENTS.md and routes
  generation to `/dmc-init-deep`, which is 6-step free-prose with an informal one-line Unknown
  rule ("Add unknowns explicitly") but no required-content contract and no determinism;
  P19 (M8) is unbuilt and does not emit AGENTS.md.
  Source: `docs/HOST_REPO_ADAPTATION_POLICY.md`; `.claude/skills/dmc-init-deep/SKILL.md`; master plan §M8.
- Finding: Priority 5 (real-repo A/B benchmark) is NOT PRESENT —
  `docs/DMC_REAL_REPO_PILOT_REPORT.md` is a one-shot manual narrative; M9 E2E is a fixture
  dry-run, not A/B.
  Source: `docs/DMC_REAL_REPO_PILOT_REPORT.md`; master plan §M9.
- Finding: the master plan's Codex assumption is stale — it plans around "Codex has no Stop
  hook ⇒ release gate as pre-commit/CI" (P20), but official Codex CLI docs (verified
  2026-07-06 against developers.openai.com/codex raw HTML) document a full lifecycle hook
  system (`SessionStart`, `PreToolUse`, `PermissionRequest`, `PostToolUse`, `UserPromptSubmit`,
  `Stop`, `SubagentStop`; JSON stdin; PreToolUse deny/allow/updatedInput; Stop
  `decision:"block"`), skills at `.agents/skills/` (SKILL.md standard), per-project
  `.codex/config.toml` + `.codex/hooks.json` (trusted projects), sandbox modes
  (`read-only|workspace-write|danger-full-access`), approval policies, experimental `.rules`
  execpolicy, explicit-only subagents, and `codex exec --json --output-schema`.
  Source: developers.openai.com/codex/{hooks,skills,config-reference,concepts/sandboxing,noninteractive} + llms-full.txt (web research session 2026-07-06); master plan §Assumptions row 3; `docs/DMC_V1_RUNTIME_ARCHITECTURE.md` P20.
- Finding: Codex hooks are officially described as "a guardrail rather than a complete
  enforcement boundary" (unified_exec / non-shell tool paths can bypass interception) — so the
  post-Bash diff guard and the release gate remain required backstops on Codex, independent of
  hook parity.
  Source: developers.openai.com/codex/hooks (same research session).

## Relevant Files

| Path | Reason | Allowed to Edit |
|---|---|---|
| .harness/plans/dmc-v0.5-codex-adapter-direction.md | this plan | yes |
| .harness/plans/dmc-v1-runtime-upgrade.md | Rev 3 amendment: M6.5 insertion, re-sequencing, M6 post-Bash addition, P20 correction, deferred registry | yes (plan text only; approval records byte-preserved) |
| docs/CODEX_ADAPTER.md (new) | conservative Codex adapter design doc | yes |
| .harness/plans/dmc-v1-m6-hook-hardening.md (new) | M6 milestone-scoped plan (authoring only) | yes |
| .harness/plans/dmc-v1-m6.5-codex-adapter.md (new) | M6.5 milestone-scoped plan (authoring only) | yes |
| .harness/evidence/dmc-v0.5-direction-* | evidence for this plan's execution + persisted critic-verdict artifacts | yes |
| .harness/verification/dmc-v0.5-codex-adapter-direction.md | verification report | yes |
| .claude/hooks/*, .claude/settings.json | protected surface — M6's job | no |
| bin/**, .harness/schemas/**, orchestration/** | Ring-0 — no code under this plan | no |
| adapters/**, .codex/**, .agents/** | M6.5's job — not created here | no |
| .claude/workers/providers/** | never (standing rule) | no |
| AGENTS.md, DMC.md, CLAUDE.md | identity refresh is M10's job | no |
| docs/DMC_V1_RUNTIME_ARCHITECTURE.md | P20 correction happens via master plan Rev 3 note instead; architecture doc untouched to keep this plan minimal | no |

## Out of Scope

- Any implementation of M6 or M6.5 (each requires its own milestone plan → critic → human gate).
- Any edit to hooks, settings.json, bin/, schemas, orchestration/, installer, worker validators.
- Worker Bridge expansion: no new providers, no live-path change, no async workers.
- Building the P5 benchmark harness (recorded as deferred; design postponed post-M9).
- Model router, independent CLI, daemon, web UI, OpenCode adapter.
- Any secret access, any live/network provider call, any copied or reconstructed proprietary
  prompt text (observable-pattern transfer only).
- Any push/stage/commit without its own human gate.

## Proposed Changes

- Change: master plan Rev 3 amendment — (a) insert **M6.5 — Codex Adapter (P21)** between M6
  and M8, promoted from the M8 spike: `adapters/codex/` hook shims over the same Ring-0 verdict
  CLIs, `.codex/` config+hooks templates, `.agents/skills/dmc-*` bindings, host-AGENTS.md
  content contract + generator binding; its FIRST task is a local-CLI verification spike that
  re-proves the web-verified hook/skill surface before any build, with the original "downgrade
  to documented-manual + pre-commit/CI gate" fallback kept; the installer `--host
  codex|claude|both` path stays M8-owned (P19) — M6.5 builds adapter content, M8 ships it;
  (b) extend M6 DMC-T011 with the **post-Bash diff guard** (PostToolUse Bash → changed-files vs
  `scope.lock.json`; out-of-scope ⇒ run BLOCKED + evidence + stop-gate hold until resolved).
  The DMC-internal exemption is NARROW: only `.harness/evidence/`, `.harness/verification/`,
  and append-only run logs; Bash-mediated writes to run-state files — `scope.lock.json`,
  `approvals.jsonl`, `run.json` — are explicitly DENIED (state mutations only via the `dmc`
  CLI), preserving canonical bypass fixture (2) and the audit's "scope self-escalation via
  `.harness/runs` auto-allow" finding; (c) re-sequence execution order to
  **M6 → M6.5 → M8 → M7 → M9 → M10** (worker hardening deprioritized but still ahead of M9's
  delegation-chain checks), AND extend M7's authorization with `INSTALL_MANIFEST.md`
  regeneration + a post-M7 manifest drift re-run (M7 edits worker validators that the M8
  installer ships — the manifest must be re-proven after M7); (d) correct the stale P20 Codex
  assumption in place with the confidence-tagged 2026 facts, and mark
  `docs/DMC_V1_RUNTIME_ARCHITECTURE.md` §P20 ("Codex has no Stop hook") as superseded-by-Rev-3
  with its in-doc cleanup assigned to M10 (the architecture doc itself stays untouched until
  M10); (e) add a Deferred register naming Worker-Bridge expansion and the P5 benchmark as
  explicitly postponed with re-entry condition (post-M9 planning); (f) authorization
  bookkeeping for the re-sequencing: Relevant Files rows updated — `adapters/**` extended to
  M6.5, NEW `.agents/**` row (M6.5), NEW `.codex/**` row (M6.5, templates), `.claude/install/*`
  remains M8-only; the REQUIRED-primitive coverage map gains `P21→M6.5`; M8 DMC-T013's "Codex
  minimal binding spike" line is replaced by "ship/install the M6.5 adapter (`--host
  codex|claude|both`)" so ownership is not duplicated.
  Files: .harness/plans/dmc-v1-runtime-upgrade.md
  Rationale: encodes the brief's priority order into the governing plan without discarding the
  approved M2–M5 record or restarting planning from zero; closes critic R1 blockers B1–B3.
- Change: new `docs/CODEX_ADAPTER.md` — conservative design doc containing: (1) verified-facts
  table of the Codex surface, each fact carrying a source URL + confidence tag
  (VERIFIED-OFFICIAL / SECONDARY / UNVERIFIED-ASSUMPTION) and a "verified 2026-07-06, re-verify
  at M6.5 spike" banner; (2) mechanism mapping table Claude→Codex (6 hook events, skills →
  `.agents/skills/`, subagents → `[agents.<name>]` explicit-only, stop gate → Stop hook with
  pre-commit/CI fallback, mode file, secret/scope/evidence guards); (3) degraded-invariant
  matrix (what each Codex mechanism does NOT guarantee — hook non-airtightness, trust flow,
  experimental rules) feeding the future P20/M10 enforcement matrix; (4) explicit non-goals
  (no `.rules` as load-bearing, no requirements.toml dependency, no worker-bridge conflation:
  "Codex as host" ≠ "Codex as worker"); (5) host-AGENTS.md content contract draft (repo
  identity, stack, package manager, lint/typecheck/test/build commands, architecture landmarks,
  protected surfaces, migration/env/auth/billing risk notes, DMC operating rules, verification
  commands, stop conditions — every unknown fact written as `Unknown`, business logic never
  invented).
  Files: docs/CODEX_ADAPTER.md
  Rationale: the brief's Priority 1 investigation deliverable; design before build; assumptions
  marked instead of invented.
- Change: author the M6 milestone-scoped plan (hook/guard hardening incl. the post-Bash diff
  guard addition) as a DRAFT for its own critic + human gate.
  Files: .harness/plans/dmc-v1-m6-hook-hardening.md
  Rationale: M6 is the protected-surface milestone both adapters depend on; the brief's
  Priorities 2–3 land here; scope/verification hardening precedes the Codex adapter per the
  brief's own ordering.
- Change: author the M6.5 milestone-scoped plan (Codex adapter) as a DRAFT for its own critic +
  human gate.
  Files: .harness/plans/dmc-v1-m6.5-codex-adapter.md
  Rationale: Priority 1 becomes a gated, first-class milestone instead of a spike inside M8.
- Change: record Priority 3's remaining gap as an M6-plan line item — extend the stop gate /
  release gate path with semantic verification-report cross-checks (report run-id == active
  run, changed-files list ⊆ approved scope and consistent with `git diff --name-only`, PASS
  refused when a required verification command failed or was skipped without reason) via a
  Ring-0 `dmc` check consumed by the hook shim, not new hook logic.
  Files: .harness/plans/dmc-v1-m6-hook-hardening.md (same M6 plan)
  Rationale: the structural validator shipped in M3; what is missing is semantic cross-checking
  and wiring — that belongs to the enforcement milestone, not a new tool family.

## Acceptance Criteria

- Criterion: this plan, the amended master plan, and both new milestone plans all pass
  `bin/dmc validate plan` (ACCEPT, exit 0).
  Verification Method: run the validator on all four paths; record output in evidence.
- Criterion: master plan Rev 3 preserves the M2–M5 approval records verbatim (no byte change
  inside the two "Approval record" blocks and the Approval Status grants for M2–M5).
  Verification Method: mechanical check — extract the approval blocks from the pre-amendment
  file (`git show HEAD:…`) and the post-amendment file by their heading markers, byte-compare
  with `cmp`; command + output recorded in evidence.
- Criterion: `docs/CODEX_ADAPTER.md` contains all five committed components (facts table with
  per-fact confidence tags + URLs, Claude→Codex mapping covering every hook event DMC uses,
  degraded-invariant matrix, non-goals incl. host≠worker separation, host-AGENTS.md content
  contract with the brief's field list + Unknown rule) and zero copied proprietary prompt text.
  Verification Method: checklist review against this criterion recorded in the verification
  report; own-words spot audit.
- Criterion: no file outside this plan's authorized list changes; Ring-0 and `.claude/` remain
  byte-unchanged.
  Verification Method: `git status --porcelain` + `git diff --name-only` vs the Relevant Files
  allowlist, recorded in evidence.
- Criterion: repo self-checks unaffected — `bin/dmc selftest` default sections stay 75 PASS /
  0 FAIL and `bin/dmc linkcheck` exits 0 after all edits.
  Verification Method: run both; record output.
- Criterion: the deferred register exists in master plan Rev 3 naming Worker-Bridge expansion
  and the P5 benchmark as postponed with their re-entry condition (post-M9 planning).
  Verification Method: grep the amended plan for the register section.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Codex surface drift after 2026-07-06 verification (hooks GA but evolving; rules explicitly experimental) | medium | confidence tags + re-verify banner; M6.5's first task is a local-CLI spike that re-proves the surface before build; documented-manual fallback retained |
| Web-researched facts wrong despite raw-HTML verification | medium | no build under this plan; facts land in a design doc marked with provenance; spike gate before implementation |
| Rev 3 edit corrupts the approved-milestone record | low | amendment is additive; approval blocks byte-preserved and diff-audited; validator re-run |
| M9 depends on M7 delegation checks while M7 is deprioritized | low | order keeps M7 before M9 (M6 → M6.5 → M8 → M7 → M9 → M10); M9 untouched |
| Scope creep from "design doc" into implementation | medium | Relevant Files allowlist has no code path; any code requires the gated M6/M6.5 plans |
| Two adapters drift apart over time | medium | both adapters are shims over the SAME Ring-0 verdict CLIs; degraded-invariant matrix makes per-host guarantees explicit; M10 enforcement matrix is the standing record |
| M6.5 plan authored now goes stale if M6 outcomes change hook shim interfaces | low | M6.5 plan is DRAFT until its own gate; its critic pass happens after M6 ships |
| M8 install fixtures ship pre-M7 worker validators (audited JWT/rename-diff/empty-allowed bypasses) during the M6.5-first window | medium | recorded in Rev 3 as an accepted interim risk; M7 authorization extended with INSTALL_MANIFEST regen + post-M7 drift re-run; M9 release gate re-composes the worker checks before any release |

## Assumptions

| Assumption | Confidence | How to Verify |
|---|---|---|
| Codex CLI ships lifecycle hooks (PreToolUse/PostToolUse/Stop/UserPromptSubmit/...) with JSON stdin and a deny/allow/block contract | high (official docs, raw-HTML verified 2026-07-06) | M6.5 spike: probe events on a locally installed Codex CLI before any build |
| Codex supports `.agents/skills/` SKILL.md standard + per-project `.codex/` (trusted) config/hooks | high (same source) | same spike |
| Codex hooks are NOT airtight (unified_exec / non-shell paths) — backstops required | high (officially stated) | design treats hooks as guardrail; post-Bash diff guard + release gate remain load-bearing |
| Hook/skill trust flow (`/hooks` content-hash trust) affects host installs | high | installer/M6.5 plan documents the trust step; spike confirms UX |
| A local Codex CLI is available for the M6.5 spike | medium | check at M6.5 start; if absent, spike is blocked and the documented-manual + pre-commit/CI fallback path is used |
| `dmc validate plan` accepts this plan's extended prose (version-label note, direction answers under Goal) | medium | run the validator immediately after writing; restructure if refused |

## Execution Tasks

- [ ] DMC-T101: Master plan Rev 3 amendment — insert M6.5 (Codex Adapter, P21, spike-first;
  installer stays M8), extend M6 DMC-T011 with the post-Bash diff guard (narrow exemption;
  run-state files DENIED) + semantic verification cross-checks, re-sequence
  M6→M6.5→M8→M7→M9→M10 with the M7 authorization extension (INSTALL_MANIFEST regen + drift
  re-run), correct the P20 Codex assumption (confidence-tagged; architecture-doc supersession
  note, cleanup → M10), add the Deferred register (Worker-Bridge expansion, P5 benchmark), and
  apply the authorization bookkeeping (Relevant Files rows for adapters/.agents/.codex;
  P-coverage map P21→M6.5; M8 DMC-T013 spike line superseded).
  Files: .harness/plans/dmc-v1-runtime-upgrade.md
  Notes: additive; M2–M5 approval records byte-preserved (mechanical cmp check);
  `dmc validate plan` re-run after.
- [ ] DMC-T102: Write docs/CODEX_ADAPTER.md (five components per Proposed Changes; own words;
  provenance + confidence tags; re-verify banner).
  Files: docs/CODEX_ADAPTER.md
  Notes: design only; no code, no templates that execute.
- [ ] DMC-T103: Author .harness/plans/dmc-v1-m6-hook-hardening.md (DRAFT) — M6 scope per master
  plan DMC-T011 + post-Bash diff guard + semantic verification cross-checks; protected-surface
  safeguards (byte-preserved pre-M6 hooks as fixtures, single-revert restore).
  Files: .harness/plans/dmc-v1-m6-hook-hardening.md
  Notes: authoring only; own critic + human gate before any implementation.
- [ ] DMC-T104: Author .harness/plans/dmc-v1-m6.5-codex-adapter.md (DRAFT) — spike-first Codex
  adapter milestone; scope = adapters/codex/, .codex templates, .agents/skills bindings,
  host-AGENTS.md contract + generator binding; installer --host path excluded (M8-owned);
  fallback documented.
  Files: .harness/plans/dmc-v1-m6.5-codex-adapter.md
  Notes: authoring only; critic pass deferred until after M6 ships (interface stability).
  Must include a mirror/drift check (M3 pattern) between .agents/skills/dmc-* and their
  .claude/skills equivalents so the two skill surfaces cannot silently diverge.
- [ ] DMC-T105: Evidence + verification report for this direction plan's execution.
  Files: .harness/evidence/dmc-v0.5-direction-20260706.md, .harness/verification/dmc-v0.5-codex-adapter-direction.md
  Notes: final status PASS | FAIL | PARTIAL; verification report must pass
  `dmc validate verification`.

## Verification Commands

| Command | Reason | Required |
|---|---|---|
| bin/dmc validate plan .harness/plans/dmc-v0.5-codex-adapter-direction.md | this plan schema-valid | yes |
| bin/dmc validate plan .harness/plans/dmc-v1-runtime-upgrade.md | Rev 3 amendment stays valid | yes |
| bin/dmc validate plan .harness/plans/dmc-v1-m6-hook-hardening.md | new M6 plan schema-valid | yes |
| bin/dmc validate plan .harness/plans/dmc-v1-m6.5-codex-adapter.md | new M6.5 plan schema-valid | yes |
| bin/dmc linkcheck | no dangling verb/path/role refs introduced | yes |
| bin/dmc selftest | default 9 sections stay 75/0 | yes |
| git diff --name-only (vs Relevant Files allowlist) | scope proof — docs/plans only | yes |
| bin/dmc validate verification .harness/verification/dmc-v0.5-codex-adapter-direction.md | report structure floor | yes |

## Approval Status

Status: APPROVED
Approver: wjlee (human release gate; granted via AskUserQuestion in the 2026-07-06 session,
option "APPROVED — 실행 착수", after critic R2 PASS on Rev 2 plan_hash 277ee35d…)
Approved At: 2026-07-06

Approval record (verbatim scope of the human gate, 2026-07-06):
- **Approved**: DMC-T101–T105 exactly as specified in §Execution Tasks — master plan Rev 3
  amendment, docs/CODEX_ADAPTER.md, authoring the M6 and M6.5 milestone plans as DRAFT,
  evidence + verification artifacts. Docs and plan files only.
- **Explicitly NOT approved**: any implementation of M6/M6.5 (each needs its own plan → critic
  → human gate), any edit to hooks/settings/bin/schemas/orchestration/installer/worker
  surfaces, staging/commit/push (each a separate human gate), live calls, secret access,
  main/master changes.
