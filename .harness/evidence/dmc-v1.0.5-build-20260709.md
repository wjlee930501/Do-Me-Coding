# Evidence — v1.0.5 AGENTS.md generator compaction

Work ID: `dmc-v1.0.5-agentsmd-compaction` · Run: `dmc-run-02ba039531cf` · Branch:
`claude/dmc-v105-agentsmd-compaction` · LOCAL commit `1cdb357` (base `5d345b5`) · 2026-07-09.

Governance: authorized this session by wjlee via AskUserQuestion (lightweighting-strategy synthesis →
"A1 + A2 함께"). Deterministic artifact-compaction cycle (bucket A: objective machine-checkable
metric, no enforcement/gate/floor/schema change — so no measurement pilot needed). Autonomous through
the LOCAL commit gate on the dedicated branch; push/CI/main-FF are a human gate.

## Chain

- Plan — `dmc validate plan` VALID (Rev 1 and Rev 2). Critic r1 REJECT (1 blocking,
  `.harness/evidence/dmc-v1.0.5-critic-r1.json`): B1 = A2's original "move §7/§9 up" reorder breaks
  the physical-order-dependent negative-control fixtures (V1 `dmc-agents-md.py:683` deletes §6 via
  `(?=## 7\.)`, plus V4 and a `test-agents-md.sh` awk) — the plan scoped the validator's
  order-independence but MISSED the fixtures' hardcoded successors; the critic reproduced the flip
  empirically. Advisories: the subset-parity guard was a tautology → count-parity; the generator is
  NOT in DEFAULT_PROTECTED → no override. Rev 2 folded: A2 reframed as inventory-last
  [1,2,3,6,7,8,9,10,4,5] (preserves §6→§7 adjacency, no jumble); the fixture rewrite made explicit
  in-scope; count-parity guard; override dropped. Critic r2 APPROVE (0 blocking,
  `dmc-v1.0.5-critic-r2.json`) — verified empirically (simulated the reordered doc and ran every
  fixture), and caught two MORE order-dependent fixtures (E4 `:658`, `test-agents-md.sh:144`) carried
  into the build as binding advisories.
- Executor (Opus, synchronous, scoped; 4-file landmark-authorized lock, state_hash
  `7d20de0fb7ad603f`): A1 dedup §5 render (compact "(see section 4)" + per-class counts 106/82/1;
  ~8.5 KB blob removed); A2 inventory-last emit order [1,2,3,6,7,8,9,10,4,5]; count-parity selftest
  PC1 (parses rendered §5 vs re-derived §4; module selftest 26→27); rewrote V1/V4/E4 + awk:182/:144
  order-independent (each still fails on its intended defect); regenerated AGENTS.md 32,490 B →
  24,126 B; MILESTONES v1.0.5 entry appended.
- Independent verifier (Opus, read-only): Final Status PASS (pre-commit build) — 9 checks
  reproduced; the critical check (negative controls still real) proven by reasoning through V1's
  rewritten slice logic + the empirical selftest; diff scope 4 files / 231-87 within bounds; bucket-A
  confirmed. Report `.harness/verification/dmc-v1.0.5-agentsmd-compaction.md` (`dmc validate
  verification` VALID).
- Full gate: green set minted on the run binding (plan_hash `213ad358…`, repo_hash `d178ffa0…`) →
  `dmc gate release --full` → PASS (8 sub-gates PASS + non-degrading landmark FLAG on
  `bin/lib/dmc-agents-md.py` [enforcement] + `docs/MILESTONES.md` [release]; NO DMC_GATE_PROTECTED
  override). Staged exactly the 4 scope files.
- LOCAL commit `1cdb357`. NO push. Human gates pending: push, CI, main FF.

## What changed and why

AGENTS.md was 287 lines / 32,490 B — 278 B under Codex's 32,768-byte `project_doc_max_bytes` cap,
with the ~104-path landmark list emitted twice (§4 bullets + §5's 8.5 KB re-inline) and the
behavioral rules (§7/§9) sitting AFTER the inventory (so a host-side truncation eats the rules
first). v1.0.5 fixes both at the generator (so the fix reaches host repos): dedup the §5 re-inline to
a cross-reference + per-class count, and emit the inventory LAST so rules precede it. Margin 278 B →
~8.6 KB. Deterministic, self-verifying, reversible — bucket A, no measurement pilot required.

## Closure lines

- Module selftest 27/0 · m65-suite 35/0 · test-agents-md.sh 35/0 · mirror-check PASS · linkcheck clean.
- AGENTS.md: 24,126 B (< 28,672); order [1,2,3,6,7,8,9,10,4,5]; §7@653 / §9@1965 both < §4@3094;
  `agents-md --validate` VALID; AC6 pointers present (AUTONOMY.md + CONTEXT_MAP.md);
  `agents-md --stdout` byte-identical to committed.
- Committed-replica `selftest --all` (clean clone of `1cdb357`, write-back severed): `aggregate:
  tools=49 PASS=802 FAIL=3 N/A=3`, exit 0 — **legacy 802/3/3 EXACT**, PASS. Authoritative release
  proof; matches the II.2 pinned baseline; a clean checkout / CI reads the same.
- Live `selftest --all` (mode active), ISOLATED run: **802/3/3 EXACT**, PASS (only the 3 pinned
  fails: v0.1.3 / v0.2.3 / v0.3.2). The generator is not among the 49 legacy tools, so the count is
  unaffected. HONEST NOTE: the FIRST live run read `800/5/3` because it executed CONCURRENTLY with
  the replica clone's own `selftest --all` — shared temp / git-porcelain churn tripped 2
  porcelain-sensitive tools (the known concurrent-suite artifact, cf. codex-shims 142/1 under
  concurrent suites). The isolated re-run reproduced `802/3/3 EXACT`. NOT a code defect (the clean
  clone proves it); recorded, not masked.
- Human gates (push, CI, main FF): PENDING.
