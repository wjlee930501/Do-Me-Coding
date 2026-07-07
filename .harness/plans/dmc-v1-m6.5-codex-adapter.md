# Plan: DMC v1 M6.5 — Codex Adapter (P21, spike-first)

Plan ID: dmc-v1-m6.5-codex-adapter · Date: 2026-07-06 · Format: PLAN_SCHEMA.md
Milestone-scoped plan for master plan §M6.5 (task DMC-T011b, inserted by Rev 3 per the approved
direction plan `.harness/plans/dmc-v0.5-codex-adapter-direction.md`). **DRAFT** — its critic pass
was deliberately deferred until M6 shipped (the Ring-0 verdict-CLI interfaces the shims bind to are
M6 deliverables). M6 has since shipped and those CLIs are frozen at HEAD 517bac0; the critic r1 pass
has run (REJECT). Design authority: `docs/CODEX_ADAPTER.md`.

**Rev 2** — revised after DMC critic REJECT (r1, persisted at
`.harness/evidence/dmc-v1-m6.5-critic-verdict-r1.json`; bound plan_hash `9d8562bd…`). Surgical
amendments only; every Rev 1 criterion the critic marked "met" is preserved unchanged, and nothing
in Rev 1's Out of Scope is relaxed (no-relaxation doctrine). Blockers closed:
- (B1) execution tasks renumbered `DMC-T012a–e` → `DMC-T011b.1 .. DMC-T011b.5` (sub-numbered under
  master §M6.5's own task `DMC-T011b`), removing the prefix collision with master §M7's `DMC-T012`
  and aligning to the sub-plan's master task ID — following the M6 precedent (`DMC-T011.1–.4`);
  every internal cross-reference updated; handoff carry-forward #8 updated to record the applied
  rename (grep-verified `DMC-T011b.N` was unused anywhere in `.harness/` or `docs/`).
- (B2) a per-bound-event fail-closed negative-control set added — (a) unparseable/empty event JSON,
  (b) missing/renamed expected `tool_input` field, (c) Ring-0 verdict CLI absent or
  non-zero/unexpected exit, (d) absent `.harness/mode` (⇒ active) — each asserting a deny/block
  envelope in active mode; passive/off behavior identical to the Claude side; cross-adapter
  verdict-parity extended over the malformed inputs.
- (B3) a secret-redaction acceptance criterion + negative control added; the Codex shims are bound
  explicitly to the existing redaction contract (`.claude/hooks/evidence-log.sh` `redact()` +
  `pre-tool-guard.sh` secret floor + `secret-guard.sh` path-only) and to the CLAUDE.md
  secret-protection rule.
- (B4) the spike-constraint ↔ firing-proof contradiction resolved decision-completely: an explicit
  turn-free-proof sub-question with named candidate probes; a hard "no DMC-initiated live model
  turn — ever" rule with a STOP + human-gate artifact if a live turn is the only proof path; the
  documented-manual + pre-commit/CI fallback as the stated default; and a per-fact disposition table
  (full-stop vs scoped degradation) over every load-bearing §1 fact.
- Advisories: (A1) a single `bin/dmc` owner named — T011b.4 is the SOLE `bin/dmc` editor
  (registers both the skills-mirror and agents-md verbs + both selftest sections); T011b.3 delivers
  its module + fixtures only and T011b.4 is `blockedBy` T011b.3; (A3) the degraded invariants made
  machine-checkable acceptance assertions in the verification report; (A4) a one-line note that the
  host-AGENTS.md generator verb and `/dmc-init-deep` are the same generator (skill → verb layering).

Critic r2 re-pass + the human release gate remain PENDING. Approval Status stays DRAFT.

## Goal

Make DMC installable and enforceable inside Codex CLI as a host: translate the Codex lifecycle
hook events onto the SAME Ring-0 verdict CLIs the Claude shims call (no enforcement logic in
the adapter), bind the `dmc-*` workflow skills to Codex's `.agents/skills/` surface, template
the per-project `.codex/` config/hooks wiring, and give hosts a deterministic, contract-bound
AGENTS.md generator — all gated behind a local-CLI verification spike that re-proves the
web-verified (2026-07-06) Codex surface before anything is built.

## User Intent

Classify: **feature** (secondary: docs — templates and the AGENTS.md content contract are
declarative artifacts).

## Current Repo Findings

- Finding: no Codex host surface exists — no `adapters/codex/`, `.codex/`, `.agents/`; the
  master plan carried Codex only as an M8 timeboxed spike until Rev 3 promoted it.
  Source: repo listing 2026-07-06; `.harness/plans/dmc-v1-runtime-upgrade.md` Rev 3 §M6.5.
- Finding: the Codex CLI surface needed for near-parity binding is officially documented
  (lifecycle hooks incl. Stop with `decision:"block"`, PreToolUse deny/allow/updatedInput,
  `.agents/skills/` SKILL.md standard, per-project `.codex/config.toml`+`hooks.json` under a
  trusted-project flow, sandbox modes, `codex exec --json --output-schema`) but was verified
  from web docs, not a local install; OpenAI marks hooks "a guardrail rather than a complete
  enforcement boundary".
  Source: `docs/CODEX_ADAPTER.md` §1 facts table (with URLs + confidence tags).
- Finding: Ring-0 verdict CLIs the shims must call (Bash radius, post-Bash diff, semantic
  cross-check, stop-gate quick) are M6 deliverables; their CLI names/contracts froze at M6
  closure (HEAD 517bac0).
  Source: `.harness/plans/dmc-v1-m6-hook-hardening.md` §Proposed Changes; M6 closure record.
- Finding: Codex protects `<root>/.codex` and `<root>/.agents` read-only against the agent in
  workspace-write mode — the agent cannot self-edit DMC's Codex bindings at runtime (a
  guarantee the Claude adapter does not have for `.claude/`).
  Source: `docs/CODEX_ADAPTER.md` §3 degraded-invariant matrix.
- Finding: the Claude shims already implement a redaction contract the Codex shims must reuse —
  `.claude/hooks/evidence-log.sh` `redact()` (sed over `sk-…` keys and
  `password|secret|token|api[_-]?key=…` payloads, applied to the logged command; `file_path`
  truncated), plus `pre-tool-guard.sh` secret-exposure denies and `secret-guard.sh`'s path-only
  decision (never opens file contents).
  Source: `.claude/hooks/evidence-log.sh:68-73`, `pre-tool-guard.sh:77-80`; CLAUDE.md §Secret Protection.

## Relevant Files

| Path | Reason | Allowed to Edit |
|---|---|---|
| .harness/evidence/dmc-v1-m6.5-spike-*.md | spike findings (surface re-proof or refutation) + turn-free-proof determination; the STOP artifact `dmc-v1-m6.5-spike-stop.md` lands here if a live turn is the only proof path | yes |
| adapters/codex/** (new) | hook shims: Codex event JSON → Ring-0 verdict CLI → Codex decision envelope; fail-closed-in-active on degenerate input; redaction contract reused | yes (new) |
| .codex/hooks.json, .codex/config.toml (new, template-in-repo) | DMC repo's own Codex wiring + the template hosts copy | yes (new) |
| .agents/skills/dmc-*/** (new) | Codex-side skill bindings mirroring .claude/skills dmc verbs | yes (new) |
| bin/lib/dmc-agents-md.py (new), bin/dmc | host-AGENTS.md generator bound to the CODEX_ADAPTER §5 content contract (consumes orient/landmarks; Unknown rule enforced); AND the SOLE bin/dmc edit — T011b.4 registers BOTH the skills-mirror and agents-md verbs + BOTH selftest sections (single-owner rule, A1) | yes (additive) |
| bin/lib/dmc-skills-mirror.py (new) | .agents/skills ↔ .claude/skills mirror/drift check module (M3 pattern) + mirror fixtures — module + fixtures ONLY; its bin/dmc verb + selftest section are registered by the single owner T011b.4 (no bin/dmc edit in T011b.3) | yes (additive) |
| .harness/schemas/agents-md.schema.md (new) | content contract as a validatable schema | yes (new) |
| tests/fixtures/m6.5/** (new) | shim unit fixtures (event JSON → expected decision), B2 fail-closed negative controls, B3 secret-redaction negative control, generator fixtures | yes (new) |
| docs/CODEX_ADAPTER.md | spike-findings addendum + any fact-table corrections (tagged) | yes |
| .harness/evidence/dmc-v1-m6.5-*.md, .harness/verification/dmc-v1-m6.5-*.md | evidence/verification (incl. the A3 machine-checkable degraded-invariant assertions) | yes |
| .claude/hooks/**, .claude/settings.json | M6 surface — frozen after M6; ALSO the read-only redaction-contract reference the Codex shims bind to for B3 (`evidence-log.sh` `redact()`, `pre-tool-guard.sh` secret floor, `secret-guard.sh` path-only) — read, never edit | no |
| .claude/install/** | installer is M8's surface (ships what this milestone builds) | no |
| .claude/workers/providers/**, worker validators | never / M7 | no |
| orchestration/roles.json | registry frozen; adapter consumes it read-only | no |

## Out of Scope

- Installer `--host codex|claude|both` work (M8 / P19).
- Any change to Claude hooks, settings, worker surfaces, provider adapters. The
  `.claude/hooks/**` redaction contract is CONSUMED read-only by the Codex shims (B3), never
  edited here.
- Codex `.rules`/execpolicy as load-bearing enforcement (defense-in-depth note only);
  `requirements.toml`; subagent auto-dispatch emulation; deprecated `~/.codex/prompts`.
- Any live model/API call, and any DMC-initiated model turn. The spike drives the LOCAL Codex
  CLI binary offline-where-possible; it must not require or read any API key, and it makes no
  DMC-initiated network call. If the local CLI itself is absent, the spike is BLOCKED (fallback
  path, below) — never simulated. No simulated proofs, ever.
- Staging/commit/push; `docs/MILESTONES.md`. The handoff carry-forward #8 edit recording the B1
  rename is applied OUTSIDE this plan (it is not a milestone deliverable and is not added to the
  file allowlist).

## Proposed Changes

- Change: SPIKE FIRST (blocking) — on a locally installed Codex CLI, empirically re-prove:
  hook events fire (PreToolUse/PostToolUse/UserPromptSubmit/Stop) with documented JSON stdin;
  deny/allow/block envelopes honored; per-tool `tool_input` field names recorded per tool;
  `.agents/skills/` discovery + invocation; per-project `.codex/` trust flow UX; `/import`
  migration scope; whether PostToolUse observes unified_exec writes. Findings (confirmations
  AND refutations) written to evidence and, as an addendum + tagged corrections, into
  `docs/CODEX_ADAPTER.md`. GATE: if the surface is materially unconfirmed, STOP — the
  milestone downgrades to the master plan's documented-manual + pre-commit/CI-gate fallback,
  and the human gate decides the reduced scope.
  Turn-free-proof sub-question (B4): make "does a turn-free method exist to prove (i) hook
  events fire and (ii) deny/allow/block envelopes are honored, with NO live model turn — no API
  key, no network?" an EXPLICIT spike sub-question. Candidate turn-free probes (each a
  CANDIDATE, to be proven or refuted at the spike, never assumed):
  (p1) `codex exec --json --ignore-user-config` run offline around a synthetic/stubbed tool op
  — whether the hook lifecycle fires without network;
  (p2) a hook replay / `--dry-run` / transcript-replay surface, if one exists, that fires hooks
  without a model turn;
  (p3) direct hook-runner invocation feeding documented event JSON to observe envelope honoring
  without the agent, if Codex exposes a hook test/emit path;
  (p4) `/hooks` trust-UX inspection (proves trust + content-hash behavior, not firing) with no turn;
  (p5) sandbox read-only `<root>/.codex`/`.agents` behavior via a direct file op (proves the
  protected-bindings asymmetry, not firing).
  No-live-turn rule (B4): ANY live model turn (API key + network) is NEVER DMC-initiated under
  this plan. If the spike concludes a live turn is the ONLY path to prove firing/envelope
  honoring, that is a STOP + human-gate decision point with a recorded artifact
  `.harness/evidence/dmc-v1-m6.5-spike-stop.md` — not an exception the implementer may take.
  Default (B4): if firing/envelope honoring cannot be proven turn-free, the milestone takes the
  documented-manual + pre-commit/CI-gate fallback and the human gate decides the reduced scope.
  Per-fact disposition on refutation or unprovable-turn-free (each load-bearing §1 fact the
  build relies on → FULL STOP vs named scoped degradation):

  | Load-bearing CODEX_ADAPTER §1 fact | What the build relies on it for | On refutation / unprovable turn-free |
  |---|---|---|
  | Lifecycle hooks fire (PreToolUse/PostToolUse/UserPromptSubmit/Stop) with JSON stdin | the shims exist only if events fire | FULL STOP of the enforcing-shim build; milestone → documented-manual + pre-commit/CI gate; human gate decides reduced scope |
  | Hook decision contracts honored (PreToolUse deny/allow/updatedInput; Stop `decision:"block"`) | the deny/block envelopes the shims emit | FULL STOP of the enforcement claim for the unhonored envelope; that path ships advisory-only + pre-commit/CI gate; human gate |
  | Hook enforcement honesty — unified_exec / non-shell paths non-airtight | known evasion gap | NOT a stop — the standing degradation: the M6 post-Bash diff guard is the PRIMARY Codex safety net; recorded in the degraded-invariant matrix (A3) |
  | PostToolUse observes unified_exec writes | anchor for the post-Bash diff guard | SCOPED degradation: if unobserved, the diff guard runs at Stop + pre-commit gate (Assumption row 3); recorded, not silent |
  | tool_input field names per tool (TBD-at-spike) | scope/secret PreToolUse field shims | SCOPED degradation for that tool's field shim: PreToolUse edit-scope degrades to backstop-only (post-Bash diff guard); path-only secret rule + instruction-level rule remain; recorded |
  | Hook trust (content-hash `/hooks` trust; changed hooks skipped) | install/wiring correctness | SCOPED degradation: document the manual trust step + fail visibly; NEVER bypass via `--dangerously-bypass-hook-trust` |
  | Skills `.agents/skills/SKILL.md` discovery | skill bindings | SCOPED degradation: skills unbound on Codex; workflow invoked via explicit prompts + host AGENTS.md; mirror check still guards text parity where bindings exist |
  | Per-project `.codex/config.toml` + `hooks.json` trusted-project merge | wiring templates | SCOPED degradation: fall back to `~/.codex` global wiring + documented manual trust; template ships documented-manual |
  | Sandbox read-only `<root>/.codex`,`.agents` (protected-bindings asymmetry) | helpful asymmetry, NOT load-bearing for enforcement | SCOPED degradation: note the agent CAN self-edit bindings on this version; rely on the scope guard over those paths as on Claude; no stop |
  | AGENTS.md discovery + `project_doc_max_bytes` (32 KiB) size cap | generator | SCOPED degradation: generator still emits the contract; trim/externalize the DMC section per the size-budget Open question; no stop |

  Files: .harness/evidence/dmc-v1-m6.5-spike-*.md, docs/CODEX_ADAPTER.md
  Rationale: web-verified facts must never authorize a build (direction plan assumption row 1);
  the spike's own constraints must not silently force the fallback for the very facts the shims
  depend on — the disposition table makes each outcome an explicit, recorded decision.
- Change: hook shims under `adapters/codex/` — one thin executable per bound event, each:
  parse Codex event JSON (superset field read, case-insensitive paths) → call the SAME Ring-0
  verdict CLI as the Claude shim → emit the Codex decision envelope; fail-closed in active
  mode; `.harness/mode` respected identically (absent ⇒ active; passive/off behavior identical
  to the Claude side); Stop shim arms from run state and holds on BLOCKED runs, with the
  pre-commit/CI gate documented as the fallback completion gate. FAIL-CLOSED NEGATIVE CONTROLS
  (B2) — for EVERY bound event, a negative-control fixture set proves a deny/block envelope in
  ACTIVE mode on each of: (a) unparseable/empty event JSON; (b) a missing or renamed expected
  `tool_input` field (field names are TBD-at-spike per CODEX_ADAPTER §2/§3); (c) a Ring-0
  verdict CLI that is absent or exits non-zero/unexpectedly; (d) an absent `.harness/mode` file
  (⇒ active). Passive/off behavior for these degenerate inputs is IDENTICAL to the Claude side
  (off ⇒ only the L0 static floor applies and the dynamic verdicts stand down — no fail-closed
  brick; passive ⇒ deny tier applies, gates stand down), so no session is bricked on hosts where
  DMC is passive/off. The cross-adapter verdict-parity check is extended to include these
  malformed inputs (byte-comparable verdicts/envelopes with the Claude shim on identical
  inputs, malformed ones included). SECRET REDACTION (B3): the shims are bound to the existing
  redaction contract — the `redact()` transform in `.claude/hooks/evidence-log.sh` (sed over
  `sk-…` keys + `password|secret|token|api[_-]?key=…` payloads) and the secret floor in
  `pre-tool-guard.sh` + the path-only decision in `secret-guard.sh`; the Codex shims apply the
  IDENTICAL redaction transform (or route through a shared Ring-0 evidence-append that performs
  it) before any `tool_input` reaches evidence/receipt/log output, and NEVER open or read
  secret-file contents. This upholds CLAUDE.md §Secret Protection on the new
  enforcement-adjacent surface.
  Files: adapters/codex/**, .codex/hooks.json, .codex/config.toml, tests/fixtures/m6.5/**
  Rationale: parity-by-construction — verdicts come from one place; the adapter only
  translates envelopes; fail-open on malformed input and secret leakage are the load-bearing
  gaps for an enforcement-class shim, so both are negative-controlled, not asserted in prose.
- Change: skill bindings `.agents/skills/dmc-{plan-hard,critic,start-work,verify-hard,status}/`
  mirroring the Claude skills' operative instructions bound to the same `dmc` verbs, plus a
  mirror/drift-check module `bin/lib/dmc-skills-mirror.py` (M3 pattern) so the two skill
  surfaces cannot silently diverge. This task (T011b.3) delivers the bindings + module +
  fixtures ONLY and does NOT edit `bin/dmc`; the mirror verb and its `bin/dmc selftest` section
  are registered by the single `bin/dmc` owner (T011b.4), which is `blockedBy` T011b.3 so the
  module exists before its verb is wired (single-owner rule, A1).
  Files: .agents/skills/dmc-*/**, bin/lib/dmc-skills-mirror.py, tests/fixtures/m6.5/**
  Rationale: direction plan T104 note; one workflow, two hosts; one file, one owner.
- Change: host-AGENTS.md generator — a `dmc` verb emitting the CODEX_ADAPTER §5 contract
  sections from repo facts (orient/landmarks inputs where available); every non-derivable
  fact emitted literally as `Unknown`; never invents business logic; merge policy per
  `docs/HOST_REPO_ADAPTATION_POLICY.md` (never blind-copy DMC's own AGENTS.md); schema +
  validator + refusal fixtures (missing section / invented-fact heuristics / non-Unknown
  placeholder). NAMING NOTE (A4): this generator verb IS the same generator that
  `docs/HOST_REPO_ADAPTATION_POLICY.md` calls `/dmc-init-deep` — a skill → verb layering, one
  generator, not two (prevents a future split-brain). T011b.4 is the SOLE `bin/dmc` editor for
  this milestone: it registers BOTH the agents-md and skills-mirror verbs + BOTH selftest
  sections in one place (single-owner rule, A1).
  Files: bin/lib/dmc-agents-md.py, bin/dmc, .harness/schemas/agents-md.schema.md, tests/fixtures/m6.5/**
  Rationale: Priority 4 lands as a contract-bound Ring-0 tool, host-agnostic (Claude hosts
  can use it too); a single bin/dmc owner avoids dangling verbs and cross-task contention.

## Acceptance Criteria

- Criterion: spike evidence exists and every CODEX_ADAPTER §1 fact the build relies on is
  marked confirmed / corrected / refuted; a refuted load-bearing fact ⇒ recorded STOP +
  fallback decision per the per-fact disposition table, not a silent workaround. The turn-free
  proof determination is recorded; if the spike concludes a live model turn is the only proof
  path, the STOP artifact `.harness/evidence/dmc-v1-m6.5-spike-stop.md` exists and NO live turn
  was taken (no simulated proofs).
  Verification Method: spike evidence file review; addendum present in docs/CODEX_ADAPTER.md;
  per-fact disposition table populated; STOP artifact present iff triggered.
- Criterion: for each bound event, shim fixtures prove the happy path — in-scope op → allow;
  out-of-scope edit → deny; secret-path read → deny; out-of-scope post-Bash diff → BLOCKED
  verdict surfaced; stop with unresolved BLOCKED/receipt-gap → block; suspended run → no block
  — AND a fail-closed negative-control set: (a) unparseable/empty event JSON, (b) missing or
  renamed expected `tool_input` field, (c) Ring-0 verdict CLI absent or non-zero/unexpected
  exit, (d) absent `.harness/mode` (⇒ active) — each ⇒ a deny/block envelope in ACTIVE mode;
  passive/off behavior identical to the Claude side. Verdicts are byte-comparable with the
  Claude shim on identical inputs, the malformed ones included.
  Verification Method: adapters/codex fixture suite (offline, event-JSON driven), exit 0;
  cross-adapter verdict-parity check extended over the B2 malformed inputs.
- Criterion: an edit/Bash event whose `tool_input` carries a secret-looking payload (key/token
  /.env content or path) ⇒ no raw secret content appears in ANY evidence/receipt/log output
  from the Codex shims, and the Codex redaction output matches the `evidence-log.sh` `redact()`
  contract on the shared secret fixture (binding by construction). Upholds CLAUDE.md §Secret
  Protection on the Codex surface.
  Verification Method: secret-redaction negative-control fixture + redaction-parity check vs
  the `redact()` contract, exit 0; grep asserts no raw secret token in any Codex-shim output.
- Criterion: skills mirror/drift check green; a seeded one-byte drift in a mirrored skill is
  REFUSED (negative control).
  Verification Method: `bin/dmc selftest` new section (registered by T011b.4).
- Criterion: AGENTS.md generator emits all contract sections on the node/python/empty fixture
  hosts; unknown facts render literally as `Unknown`; validator refuses a generated file with
  a missing section (negative control).
  Verification Method: generator fixture suite + schema validator, exit 0.
- Criterion: the M6.5 verification report carries the degraded invariants as machine-checkable
  assertions, not narrative only — a required "Degraded Invariants (Codex)" section whose
  substrings a grep-based check finds, naming (i) the unified_exec / non-shell evasion residual
  gap, and (ii) the post-Bash diff guard as the LOAD-BEARING primary Codex safety net (not a
  backstop) — mapped to CODEX_ADAPTER §3 rows; the check FAILS if either substring is absent so
  the degradation cannot silently vanish from the record.
  Verification Method: `dmc validate verification` + the degraded-invariant substring grep
  listed in Verification Commands, exit 0.
- Criterion: `bin/dmc selftest --all` == pinned baseline + new sections 0 FAIL; mirror-check
  green; no `.claude/` or protected-surface diff.
  Verification Method: selftest --all; `git diff --name-only` vs this plan's allowlist.
- Criterion: Ring-0 stays model-name-free (capability classes only; Codex model names appear
  ONLY in the dated lookup rows of docs/CODEX_ADAPTER.md).
  Verification Method: v0.6.1 self-scan extended over adapters/ and new bin/lib files.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Local Codex CLI unavailable or older than the documented surface | medium | spike is BLOCKED, not faked; fallback = documented-manual + pre-commit/CI gate, human-gated reduced scope |
| Firing/envelope honoring provable only via a live model turn | high | explicit turn-free-proof sub-question with candidate probes (B4); no DMC-initiated live turn — ever; STOP + human-gate artifact if a turn is the only path; documented-manual fallback as default |
| Codex shim fail-OPENS on malformed/renamed/absent input → enforcement bypass | high | per-bound-event fail-closed negative controls (B2, cases a–d); cross-adapter parity extended over malformed inputs; deny/block asserted in active mode; passive/off parity avoids bricking |
| Secret-bearing `tool_input` persisted to Codex evidence/receipt/log | high | shims bound to the existing redaction contract + a secret-redaction negative control (B3); path-only secret decision preserved (contents never opened); CLAUDE.md §Secret Protection |
| Codex hook non-airtightness (unified_exec / non-shell paths) leaks writes past PreToolUse | high (known) | post-Bash/post-turn diff guard + release gate are the load-bearing backstops; degraded-invariant matrix + the A3 machine-checkable assertion keep the gap explicit; never claim parity where there is none |
| Hook trust flow blocks hosts (untrusted hooks silently skipped) | medium | trust step documented in template + generated AGENTS.md; spike records the UX; never auto-bypass trust |
| M6 verdict-CLI interfaces shift before this milestone starts | low | M6 has shipped and the CLIs are frozen at HEAD 517bac0; shims bind to the frozen CLI names; plan re-validated at critic r2 |
| Skill text drift between hosts | low | mirror/drift selftest with negative control |
| Adapter accidentally grows enforcement logic | medium | acceptance requires verdict parity vs Claude shim on identical inputs (happy-path AND malformed); code review checklist: adapters translate, never decide |
| bin/dmc contention across the two verb-adding tasks | low | single-owner rule (A1): T011b.4 is the SOLE bin/dmc editor; T011b.3 ships module + fixtures only; T011b.4 blockedBy T011b.3 |

## Assumptions

| Assumption | Confidence | How to Verify |
|---|---|---|
| CODEX_ADAPTER §1 facts hold on a current local Codex CLI | medium until spike | the blocking spike task (T011b.1); each load-bearing fact has a disposition in the §Proposed Changes per-fact table on refutation/unprovability |
| M6 shipped the four Ring-0 verdict CLIs with stable names/exit contracts | high | M6 closure record + `bin/dmc help` (frozen at HEAD 517bac0) |
| Codex PostToolUse (or turn-end) provides a usable anchor for the post-Bash diff guard | medium | spike probes; if absent, guard runs at Stop + pre-commit gate (recorded SCOPED degradation in the per-fact table) |
| `.agents/skills` discovery works from repo root in a fresh clone without extra config | medium | spike probes a scratch clone |
| A turn-free method exists to prove hook firing + envelope honoring | unknown until spike | the B4 turn-free-proof sub-question + candidate probes (p1–p5); on "no", the documented-manual fallback default applies and the human gate decides |

## Execution Tasks

- [ ] DMC-T011b.1: Local Codex CLI verification spike + findings evidence + CODEX_ADAPTER
  addendum/corrections + the B4 turn-free-proof determination + the per-fact disposition
  record. BLOCKING GATE for all later tasks (T011b.2–.5).
  Files: .harness/evidence/dmc-v1-m6.5-spike-*.md, docs/CODEX_ADAPTER.md
  Notes: offline-where-possible; no API key read; NO DMC-initiated live model turn — ever. If
  firing/envelope honoring is unprovable turn-free, record the STOP artifact
  .harness/evidence/dmc-v1-m6.5-spike-stop.md and hand to the human gate; a refuted load-bearing
  fact ⇒ the disposition table decides full-stop vs scoped degradation. No simulated proofs.
- [ ] DMC-T011b.2: adapters/codex/ shims + .codex templates + fixture suite (happy-path + B2
  fail-closed negative controls (a)–(d) per bound event + B3 secret-redaction negative control)
  + cross-adapter verdict-parity check extended over the malformed inputs.
  Files: adapters/codex/**, .codex/*, tests/fixtures/m6.5/**
  Notes: shims call M6 Ring-0 CLIs only; fail-closed-in-active on every degenerate input;
  passive/off parity to the Claude side; mode-file parity; bound to the
  evidence-log.sh/pre-tool-guard.sh/secret-guard.sh redaction contract. blockedBy T011b.1.
- [ ] DMC-T011b.3: .agents/skills/dmc-* bindings + bin/lib/dmc-skills-mirror.py mirror/drift
  module + mirror fixtures — module + fixtures ONLY, does NOT edit bin/dmc.
  Files: .agents/skills/dmc-*/**, bin/lib/dmc-skills-mirror.py, tests/fixtures/m6.5/**
  Notes: seeded one-byte drift REFUSED; the mirror verb + selftest section are registered by
  the single bin/dmc owner T011b.4 (A1). blockedBy T011b.1.
- [ ] DMC-T011b.4: host-AGENTS.md generator + schema + validator + generator fixtures, AND the
  SOLE bin/dmc edit — registers BOTH the skills-mirror and agents-md verbs + BOTH selftest
  sections (single-owner rule, A1).
  Files: bin/lib/dmc-agents-md.py, bin/dmc, .harness/schemas/agents-md.schema.md, tests/fixtures/m6.5/**
  Notes: Unknown rule enforced by validator; merge policy per HOST_REPO_ADAPTATION_POLICY; this
  generator IS the /dmc-init-deep generator (skill → verb layering, A4). blockedBy T011b.3.
- [ ] DMC-T011b.5: evidence + verification report (must pass `dmc validate verification`; must
  carry the A3 machine-checkable degraded-invariant assertions).
  Files: .harness/evidence/dmc-v1-m6.5-*.md, .harness/verification/dmc-v1-m6.5-*.md
  Notes: final status PASS | FAIL | PARTIAL; degraded invariants restated honestly with the
  required "Degraded Invariants (Codex)" substrings the A3 grep check asserts. blockedBy
  T011b.2, T011b.3, T011b.4.

## Verification Commands

| Command | Reason | Required |
|---|---|---|
| spike transcript / evidence review + per-fact disposition + turn-free-proof determination | web-verified facts re-proven locally; B4 decision-complete | yes |
| adapters/codex fixture suite (offline event-JSON): happy-path + B2 fail-closed negative controls (a)–(d) per bound event | shim correctness + fail-closed on malformed input | yes |
| cross-adapter verdict-parity check (incl. B2 malformed inputs) | parity binds fail-closed behavior, not just happy paths | yes |
| secret-redaction negative-control + redaction-parity vs evidence-log.sh redact(); grep for raw secret tokens in Codex-shim outputs | B3 secret protection on the Codex surface | yes |
| degraded-invariant substring grep over the M6.5 verification report (unified_exec gap; post-Bash diff guard = primary Codex net) | A3 machine-checkable degradation record | yes |
| bin/dmc selftest --all | pinned baseline + new sections 0 FAIL | yes |
| bin/dmc mirror-check | legacy copies untouched | yes |
| model-name self-scan over adapters/** + new bin/lib | Ring-0 stays model-name-free | yes |
| bash -n / python3 -m py_compile on touched files | syntax floor | yes |
| git diff --name-only vs allowlist; git status --porcelain | scope + cleanliness | yes |

## Approval Status

Status: APPROVED
Approver: wjlee (human release gate; granted via AskUserQuestion in the 2026-07-06 session,
option "승인 — Rev 2 그대로", after the critic chain r1 REJECT (4 blockers B1–B4, plan_hash
9d8562bd9f20489aaa2c50cb1fcdf86c08f9d51ab4681e876406a5e4ec5361d0) → Rev 2 → r2 APPROVE bound
to the frozen pre-approval bytes sha256
b02b155487cab1c185153016f78f15f0e14bf9f50be6208e7cf3112cd84fa111 — verdicts persisted at
.harness/evidence/dmc-v1-m6.5-critic-verdict-r{1,2}.json; r2 is the binding artifact;
`dmc verdict validate` VALID and `dmc verdict gate --plan-hash b02b1554…` PASS pre-gate)
Approved At: 2026-07-06

Approval record (verbatim scope of the human gate, 2026-07-06):
- **Approved**: DMC-T011b.1–.5 exactly as specified in §Execution Tasks — spike-first
  (T011b.1 is the blocking gate for .2–.5), adapters/codex shims + .codex templates + fixture
  suite (happy-path + B2 fail-closed + B3 secret-redaction negative controls), .agents/skills
  bindings + mirror module, host-AGENTS.md generator + schema (T011b.4 the sole bin/dmc owner),
  evidence + verification.
- **A5 advisory disposition (recorded at the gate)**: critic r2's non-blocking advisory A5
  (Acceptance Criterion 3's absolute no-secret clause vs the redact() contract on a
  path-embedded short secret) is accepted AS-IS for this approval; the precision choice per the
  critic's suggested fix is handled at T011b.2 implementation, not by a plan re-edit.
- **Explicitly NOT approved**: staging/commit/push (separate human gates); any live model/API
  call or DMC-initiated model turn (a spike concluding live-turn-only ⇒ STOP artifact
  `.harness/evidence/dmc-v1-m6.5-spike-stop.md` + a NEW human gate); installer/`--host` work
  (M8); worker-surface changes (M7); any `.claude/**` or other protected-surface edit.
- Approval is recorded here and in the master plan §Approval Status. NOTE (carry-forward 9
  pattern): appending this record changes the plan file's hash by design — the r2 verdict binds
  the pre-approval bytes `b02b1554…`, this record cites that hash, and run.json binds the
  post-append bytes.
