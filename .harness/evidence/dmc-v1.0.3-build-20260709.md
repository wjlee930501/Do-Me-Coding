# Evidence — v1.0.3 generator & classification hardening (overnight cycle 2/3)

Work ID: `dmc-v1.0.3-generator-classify` · Run: `dmc-run-c9a159039747` · Branch:
`claude/dmc-v102-v104-overnight` · LOCAL commit `267a65b` (base `510f421`) · 2026-07-09 overnight.

Governance: the wjlee overnight autonomy envelope (ruled III.2(3)-compatible at v1.0.2 r1; carried
ruling). LOCAL commit only; push/CI/main-FF are morning human gates.

## Chain

- Plan Rev 2 — `dmc validate plan` VALID at both revisions.
- Critic (Opus, carried context, non-authoring): r1 REJECT — the load-bearing catch: the generator
  SHIPS to hosts (`dmc-install.sh:295` ships `bin/lib/*`) while the three companion docs do NOT,
  so unconditional §7 emission would ship dangling references with zero machine tripwire → Rev 2
  presence-gate → r2 APPROVE (fixture no-docs state live-verified) → r3 build sign-off APPROVE
  (own drills: full-document byte-identity `cmp`, host-shape omission on a bare tmp repo,
  live-classifier-fed end-to-end scope-lock drill). Artifacts:
  `.harness/evidence/dmc-v1.0.3-critic-r{1,2,3}.json`, all validator-VALID.
- Executors (synchronous, scoped; 5-entry landmark-authorized lock, state_hash `7006d2bedff5b2ef`):
  T001 Opus — generator §7 PRESENCE-GATED native emission (`COMPANION_DOCS` + atomic
  `companion_docs_present()` fact; paragraph bytes from the committed file; derive→render
  separation kept); STRONGEST proof: `agents-md --stdout` == committed AGENTS.md BYTE-IDENTICAL
  pre-T002; module selftest 24→26 (C1 emit / C2 host-shape omit). T002 Opus — `.codex/` →
  enforcement (one clause; reason string unchanged); landmarks selftest 11→13 (both-file L1g rows,
  L1f intact); live map 187→189 (+2 exactly); end-to-end drill: unauthorized `.codex/hooks.json`
  grant REFUSES (`SCOPE-LOCK-LANDMARK-UNAUTHORIZED`), authorized compiles VALID. T003 Sonnet —
  registered `landmarks.schema.md` seed-union reword EXECUTED (one-bullet diff; "historically
  included …, removed by the human-gated hygiene cycle 2026-07-08" — closing that v1.1+
  deferral); AGENTS.md regen (§4/§5 +2 rows; **§7 hunk NONE** — the root-cause proof held at
  regen time); MILESTONES v1.0.3 entry (append-only, lexeme-clean).
- Independent verifier (Opus, read-only instance): Final Status **PASS (pre-commit build)** —
  own drills incl. the 2-of-3-docs atomicity case (OMITS), the host-shape omission, the
  end-to-end scope-lock REFUSE/VALID pair, live map count 189; report persisted by the
  orchestrator from the verifier's validated scratchpad copy at
  `.harness/verification/dmc-v1.0.3-generator-classify.md` (`dmc validate verification` VALID
  re-run post-persist); the verifier had no Write tool this cycle — sequence disclosed here.
- Plan-label inaccuracy adjudicated (critic r3): the plan's "24/0" for the m6.5 shell suite
  conflated it with the MODULE selftest (24→26); the shell suite is and stays 35/0, untouched.
  Recorded here as the true counts: module 26/0; test-agents-md.sh 35/0; landmarks 13/0.
- Full gate: green set minted on the run binding → `dmc gate release --full` → **PASS** (8 PASS +
  non-degrading landmark FLAG on the 4 landmark paths; NO G4 override — no DEFAULT_PROTECTED path
  in the diff). Staged by explicit paths; G1 staged⊆allowlist green.
- Closure proofs: committed-replica (`267a65b`) AND live `selftest --all` BOTH
  `aggregate: tools=49 PASS=802 FAIL=3 N/A=3` — **legacy 802/3/3 EXACT**, PASS, exit 0.
- LOCAL commit `267a65b`. NO push. Morning gates pending: push, CI, main FF.

## What changed and why (summary)

The §7 companion-docs paragraph regen-loss class (reproduced at M10, hygiene, and Option-B —
three times, each caught only by the standing hand-re-add rule + the frozen v0.4.7 AC6 audit) is
retired at its root cause: the generator now emits the paragraph natively, PRESENCE-GATED so the
shipped tool adds nothing on hosts lacking the docs. `.codex/` shipped wiring is now an
enforcement-class landmark end-to-end (classification → live map → scope-lock refusal →
release-gate FLAG). The registered landmarks.schema.md reword is executed, closing one v1.1+
deferral.
