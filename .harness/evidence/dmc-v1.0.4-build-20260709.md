# Evidence — v1.0.4 Codex interop & coexistence documentation (overnight cycle 3/3)

Work ID: `dmc-v1.0.4-codex-coexistence-docs` · Run: `dmc-run-9885068dc4d9` · Branch:
`claude/dmc-v102-v104-overnight` · LOCAL commit `5eea17b` (base `267a65b`) · 2026-07-09 overnight.

Governance: the wjlee overnight autonomy envelope (ruled III.2(3)-compatible at v1.0.2 r1; menu
item ratified by name). Docs-only cycle; D5 no-promotion boundary held throughout. LOCAL commit
only; push/CI/main-FF are morning human gates.

## Chain

- Plan — `dmc validate plan` VALID; critic r1 APPROVE FIRST ROUND with three governing rulings:
  (i) dangling-reference law — the breadcrumb pattern lawful, the m8 scan's non-coverage of
  installed docs/ content honestly disclosed with the critic/verifier reading as the compensating
  check; (ii) the promotion line — dated/build-pinned/past-tense/one-consented-session claims
  lawful, standing-behavior claims unlawful; (iii) IV.3 — the dated closure sub-note UNDER
  item-10(e) plus end-of-§4 entries is the lawful append form. Five advisories bound execution
  (IV.2 binds ALL prose as law; pin-drift minimization + recording; full build pins in Observed
  callouts; reference minimalism; explicit-path staging). r2 build sign-off APPROVE (own
  ref-extraction via the m8 regex — exactly ONE non-bundled ref; own pin arithmetic against HEAD
  bytes; own lexeme sweep INCLUDING the nc4 negative-control proof that the control has teeth).
  Artifacts: `.harness/evidence/dmc-v1.0.4-critic-r{1,2}.json`, validator-VALID.
- Executors (synchronous, scoped; 4-entry lock, state_hash `36f0d00134b84ee1`): T001 Opus —
  OMC_COEXISTENCE `## Codex coexistence` (pure append +34; layer-merge standing facts; two dated
  pinned "> Observed" callouts; precedence extension; ONE breadcrumb ref) + CODEX_ADAPTER
  Option-B addendum (+43/-1, the -1 being the inline-dated-tag line with original text preserved).
  T002 Opus — HONEST_SCOPE IV.3 append (+5/-0; item-10(e) byte-intact + compact closure sub-note;
  v1.0.4 register subsection at §4 END; pin-shift arithmetic reported). T003 Sonnet — MILESTONES
  v1.0.4 entry (+24/-0) RECORDING the constitution line-pin drift (`:103`→`:104`,
  `:122-129`→`:127-134`; others unchanged) for a future constitution-hygiene amendment.
- Independent verifier (Opus, read-only instance): Final Status **PASS (pre-commit build)** —
  own extraction (1 non-bundled ref), own pin arithmetic (§5 heading at :127 confirmed), lexeme 0
  hits over 27 /codex/i added lines, 5 facts cross-checked with zero contradiction. One honest
  note: a concurrent-suite run first showed codex-shims 142/1 (its own porcelain guard tripped by
  a SIBLING suite's temp churn in the same batch); isolated re-run = 143/0 clean — recorded, not
  a build defect. Report persisted by the orchestrator from the verifier's validated scratchpad
  (read-only verifier instance; v1.0.3 precedent) at
  `.harness/verification/dmc-v1.0.4-codex-coexistence-docs.md` (validator VALID re-run
  post-persist).
- Full gate: green set minted on the run binding → `dmc gate release --full` → **PASS** (8 PASS +
  non-degrading landmark FLAG on `docs/MILESTONES.md` only; NO G4 override — docs paths absent
  from the protected defaults). Staged by explicit paths.
- LOCAL commit `5eea17b`. NO push. Morning gates pending: push, CI, main FF.

## What changed and why (summary)

The Option-B observations now live in the operating docs instead of only evidence/handoff: the
SHIPPED coexistence doc covers the second host (layer model, observed contenders, the foreign-
layer config write, the trust asymmetry, precedence) with host-safe framing; the repo-internal
adapter design authority carries the dated observation addendum and closes its stale field-names
open question; the disclosure ledger records the observed-on-cli status and the App-surface gap
WITHOUT any tier movement (the "observed-on-cli" posture upgrade remains a registered future
gate). The constitution pin drift caused by the ledger's own append duty is recorded for the next
amendment.

## Closure lines

- Committed-replica `selftest --all` (clean clone of `5eea17b`, task `byxcb5l43`): `aggregate:
  tools=49 PASS=802 FAIL=3 N/A=3`, exit 0 — **legacy 802/3/3 EXACT**, PASS. This is the
  authoritative release proof for the commit and matches the constitution II.2 pinned baseline. A
  clean checkout / CI (no `.harness/mode` ⇒ active default) reads the same 802/3/3.
- Live working-tree `selftest --all`: read `801/4/3` (drift +1) on two runs (`bpbh4w2i4`,
  `bmlk8lf9i`). Root-caused — NOT a code defect, NOT masked: the sole extra fail is the
  `dmc-v0.1.3-verify.sh` assertion `pre-tool-guard npm ask`, which needs **active** mode. The live
  tree was on `.harness/mode=passive` (set 2026-07-09 so the active-mode ask-tier would stop
  prompting during unattended work), and passive stands the ask-tier down by design. Proven by
  flipping the live mode to active and re-running that one suite: `PASS=44 FAIL=1` (only the pinned
  `GLM/worker code found` drift — the glm adapter postdates v0.1.3), i.e. 802/3/3-consistent; mode
  then restored to passive. The clean clone scores 802/3/3 precisely because it has no
  `.harness/mode` and defaults to active.
- NOTE (mode-coupling, for the record): the pinned 802/3/3 baseline assumes **active** mode; running
  `selftest --all` under `passive` will always surface this single `npm ask` drift. Not a
  regression — a property of the passive stand-down. Candidate for a future baseline-doc note and/or
  a mode-aware selftest expectation (registered, not fixed here).
- Morning gates (push, CI, main FF): PENDING-BY-ENVELOPE.
