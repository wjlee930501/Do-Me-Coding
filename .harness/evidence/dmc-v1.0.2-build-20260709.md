# Evidence — v1.0.2 router whole-prompt suffix anchor (overnight cycle 1/3)

Work ID: `dmc-v1.0.2-router-anchor` · Run: `dmc-run-c670495342e1` · Branch:
`claude/dmc-v102-v104-overnight` · LOCAL commit `510f421` (base `d846f0a`) · 2026-07-09 overnight.

Governance: the wjlee pre-sleep overnight autonomy envelope (AskUserQuestion; recorded verbatim in
the plan §User Intent; ruled Constitution III.2(3)-compatible by critic r1 — the human gate is
critic-conditional pre-approval completed by the MORNING gates, which alone may push/CI/main-FF;
AUTONOMY.md autonomous-local-commit, "PUSH and CLOSURE are never autonomous").

## Chain

- Plan `.harness/plans/dmc-v1.0.2-router-anchor.md` — `dmc validate plan` VALID.
- Critic (Opus, fresh): r1 APPROVE FIRST ROUND incl. the envelope adjudication and an independent
  36/36 case-glob↔regex parity battery; r2 build sign-off APPROVE (own re-verification: diff
  read line-by-line, own 36/36 battery, suite 143/0 ×2, v011 39/2). Artifacts:
  `.harness/evidence/dmc-v1.0.2-critic-r{1,2}.json`, validator-VALID.
- Executors (synchronous, scoped; 3-entry landmark-authorized lock, state_hash `d61fcb78a3e33259`):
  T001 Opus (router rebuild; sandbox 23/23 incl. defect-negative repro) · T002 Sonnet (A16 +7
  sub-blocks / 44 assertions; suite 99→143/0 stable ×2; embedded-newline JSON-escaping finding
  documented in-suite) · T003 Sonnet (MILESTONES entry, append-only 22 lines, lexeme-clean).
- Independent verifier (Opus): `.harness/verification/dmc-v1.0.2-router-anchor.md` — Final Status
  PASS on its OWN 6-class sandbox battery; `dmc validate verification` VALID;
  `verify-crosscheck` ACCEPT (run-bound, in-scope, honest). One transparency note: the MILESTONES
  entry names the Codex adapter in accurate parity vocabulary — adjudicated non-defect, recorded
  for the morning gate.
- Full gate: green set minted on the run binding (verify-plan + 3 receipts CHK-V102-* + findings
  ALLOW + goal ALLOW + decision ANSWERED + approvals VALID 2-record chain) →
  `dmc gate release --full --run-id dmc-run-c670495342e1` → **PASS** (8 PASS + non-degrading
  landmark FLAG on `.claude/hooks/dmc-router.sh` + `docs/MILESTONES.md`, recorded, never cleared;
  G4 green via the envelope-pre-ratified MINIMAL `DMC_GATE_PROTECTED` override — the
  `.claude/hooks` line dropped ONLY, all other entries kept verbatim).
- Closure proofs: committed-replica (`510f421` clone) AND live `selftest --all` BOTH
  `aggregate: tools=49 PASS=802 FAIL=3 N/A=3` — **legacy 802/3/3 EXACT**, PASS, exit 0.
- LOCAL commit `510f421` staged by EXPLICIT paths (critic advisory; G1 staged⊆allowlist green).
  NO push. Morning gates pending: push, CI, main FF.

## What changed and why (summary; full detail in the plan/verification)

The Claude router matched trigger tokens with line-oriented grep/sed — ANY interior line ending in
a trigger token routed a multi-line prompt (observed LIVE twice on 2026-07-09: pasted transcripts
self-triggered this orchestrating session; sandbox-reproduced by scout, critic, executor, and
verifier independently). Trigger path rebuilt with whole-string POSIX mechanics; emit strings,
mode writes, and the v011-invariant env-var parse line byte-unchanged; the already-correct Codex
UPS shim untouched (VIII.3(e): parity-RESTORING one-sided edit, machine-checked by the new A16
multi-line/token-only rows driving BOTH adapters). v011-verify: 39/2, all 5 invariant router rows
green, same 2 known non-router FAILs — never gated ALL-PASS.

## Incidents (live-fire, honored)

Ring-1 denied an executor's out-of-repo scratchpad write under the armed run (verbatim in the
executor report; resolved inline without scope change) and two self-inflicted `>`-token
write-radius denials in throwaway inspection commands (re-phrased). A critic-environment grep
false-alarm (ugrep BRE `$` quirk) was root-caused and recorded in the r2 artifact so future
critics use `grep -F` for literal-`$` patterns.
