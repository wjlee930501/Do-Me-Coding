# v1.1.7 — Bash write-radius safe-sink allowlist + residual L1-AMBIGUOUS ask->deny (Rev 3)

## Goal

Eliminate unattended human-stalling `ask` verdicts from the Block D Bash write-radius
classifier (`bin/lib/dmc-bash-radius.py`) in two parts, WITHOUT opening any fail-open hole:

1. SAFE-SINK ALLOWLIST — redirect targets that cannot mutate the working tree become ALLOW under
   an armed run: `/dev/null`, `/dev/stderr`, `/dev/stdout`, `/dev/fd/<n>`; and the `N>&M`
   fd-duplication class (e.g. `2>&1`, `>&2`, `2>&-`), which duplicates a descriptor and has no
   file target, stops being treated as a write idiom (it is currently mis-segmented into a
   dangling empty target).
2. ASK->DENY — every residual L1-AMBIGUOUS verdict (python -c / glob / command-substitution /
   variable / directory / single-operand mv-cp / tee-no-file / wrapper-exec benign payload)
   converts from `ask` (exit 3) to `deny` (exit 4), fail-fast so an agent self-corrects in seconds
   instead of stalling the session on an unattended human prompt.

Rev 2 note: this is "strictly more fail-closed + false-block removal" ONLY once the two Rev 1
holes are closed — (B1) the `>&`/`N>&` orphaned-file-target fail-open and (B2) the `/dev/fd/`
prefix traversal. Rev 2 folds both companion fixes; with them the net-tightening framing is
restored. It does NOT loosen any deny floor and does NOT touch the Block C consent `ask` tier
(npm publish etc.), which is out of scope.

## User Intent

feature

(Behavioral enforcement change to a Ring-0 verdict tool. Human-gate pre-authorization is recorded
under Assumptions A-AUTH; see the Authorization framing note in the Goal.)

## Current Repo Findings

- Finding: The ONLY point L1 emits `ask` is the `classify_l1` terminal branch
  `if ambiguous: return "ask", ("BASH-L1-AMBIGUOUS: ... human decides"), resolved`. Every ask
  source (wrapper benign payload, tee-no-file, single-operand mv/cp, python -c, ambiguous-shaped
  concrete target) funnels through the single `ambiguous` flag into this one branch.
  Source: bin/lib/dmc-bash-radius.py:423-426 (flag set at :379,:391,:397,:399,:405).
- Finding: `2>&1` mis-segments. `split_segments` splits on `&` (bin/lib/dmc-bash-radius.py:143),
  so `echo x 2>&1` becomes segments `['echo x 2>', '1']`; the first carries a dangling `2>` whose
  target is the empty string, which `_is_ambiguous("")` flags -> ASK. The existing fd-dup drop at
  :251 never runs because segmentation already broke the token. EMPIRICALLY CONFIRMED this session.
  Source: bin/lib/dmc-bash-radius.py:143 (split), :230 (`_is_ambiguous("")`), :251 (unreached drop).
- Finding (Rev 2 / B1): the split-guard fix ALONE is fail-open. With `>&`/`N>&` cohering into one
  segment, `_redirect_targets` (:234-251) matches the `>` via REDIR_PREFIX and the fd-dup filter
  (:251) drops the `&`, ORPHANING the FOLLOWING file token. EMPIRICALLY REPRODUCED this session:
  `echo pwned >& src/other.py` and `cmd >& /tmp/evil` both yield raw_targets=[] -> ALLOW-NO-WRITE.
  `_redirect_targets` needs a companion change so `>&FILE`/`N>&FILE` surface the file as a write
  target. Source: bin/lib/dmc-bash-radius.py:234-251 (reproduced under the proposed guard).
- Finding (Rev 2 / B2): a `/dev/fd/` PREFIX (startswith) sink test admits
  `/dev/fd/../../etc/passwd`. Sink membership must be exact-set + an anchored fd regex.
- Finding: safe sinks currently DENY, not ask. `echo x > /dev/null` armed => exit 4 OUT-OF-SCOPE
  (`/dev/null` adjudicates outside the locked scope). Same for `/dev/stderr`, `/dev/fd/2`,
  `2>/dev/null`. EMPIRICALLY CONFIRMED this session.
  Source: bin/lib/dmc-bash-radius.py:418-421 (`_adjudicate` OUTSIDE => deny).
- Finding: LIVE layer, not a frozen mirror. `bin/lib/dmc-bash-radius.py` is the M6 Ring-0
  classifier; the frozen mirrors are `bin/lib/dmc-v0.*-verify.sh`. Editable under a
  landmark-authorized scope.lock. Source: `ls bin/lib`.
- Finding: Consumers of the 0/3/4 verdict — (a) `.claude/hooks/pre-tool-guard.sh:188-193`
  Block D `case` maps `3) ask` / `4) deny`; (b) `adapters/codex/dmc-codex-pretooluse.py:68-77`
  maps `rc == 3` -> pretool_ask; helper `adapters/codex/dmc_codex_common.py:391-399` docstring
  enumerates "0 allow / 3 ask / 4 deny"; (c) `bin/dmc:66-68` bash-radius verb help says
  "-> 0 allow / 3 ask / 4 deny"; (d) `dmc-postbash-diff` is a SEPARATE detector, does NOT consume
  bash-radius exit codes. After the change bash-radius never returns 3, so the `ask` branches in
  (a) and (b) become unreachable-but-harmless. Source: cited file:line.
- Finding: NO cross-adapter parity row asserts an `ask` from L1-AMBIGUOUS. D-rows are D6
  git-apply(deny/L0), D7 out-of-scope(deny), D8 in-scope(allow), D9 `npm install` (Block C
  ask-tier — a different tier, out of scope). No parity test edit is required.
  Source: tests/fixtures/m6.5/test-codex-shims.sh:325-333.
- Finding: self-test case count is NOT pinned. `dmc selftest m6-core` runs
  `python3 BASHRADIUSLIB --self-test` and checks only rc (bin/dmc:648,:685). No live test asserts
  "bash-radius 50", "m6-core 99", or "3 ask / 4 deny" (grep empty). The `802/3/3` legacy aggregate
  counts dmc-v0.* tools ONLY. Adding/converting self-test cases is safe. Source: bin/dmc:648,:685.
- Finding (Rev 2 / B3): the standalone `tests/install/*` files are NOT invoked by CI
  (`dmc-ci.yml` runs `dmc selftest`; the v1.1.4 CI-coverage lesson). Security-critical rows MUST
  live in the MODULE `selftest()` (covered by `selftest --all` and the m6 legs). Source:
  bin/dmc:648,:685 (m6-core/-all wire the module self-test); dmc-ci.yml.
- Finding: `dmc help` output is only asserted to contain `--scope-input`
  (tests/install/test-run-start-arming.sh:169-170). Editing the bash-radius verb help is test-safe.
- Finding: DMC.md:73-74 "`ask` prompts" describes the Block C consent tier (remains active). No
  Block-D-specific `ask` is documented in DMC.md/CLAUDE.md, so those stay truthful (no edit). The
  one authoritative doc asserting L1 "0 allow / 3 ask / 4 deny" is
  docs/DMC_V1_ENFORCEMENT_MATRIX.md:108 — MUST be updated. Source: grep of docs/.
- Finding: EXIT_ASK=3 is a shared M6 exit-code (validators/`scope-lock` use exit 3 for their own
  semantics). The constant + `emit()` table stay; only bash-radius stops REACHING it.
  Source: bin/lib/dmc-bash-radius.py:48-49,:101-105; bin/dmc:262.
- Finding (Rev 3 / semantic sweep): the W4 ask->deny conversion breaks ONE external assertion that
  a literal "3 ask" grep missed — `tests/fixtures/m6/test-adversarial.sh:211` uses a BARE
  `assert_eq ask "$(wrapper_verdict "sh -c 'echo hi'")"` form (plus stale comments :185,:210 and
  the label :212) that expects the old benign-wrapper ASK; with the terminal ambiguous->deny flip
  the armed shim now returns DENY, so `dmc selftest m6-suite` goes rc1 (test-adversarial 37/1)
  while the rest of the battery is green (module selftest 95/0, integration 66/0, m65 161/0, NO-ASK
  grep clean). LIVE-CONFIRMED this session: `sh -c 'echo hi'` armed => rc4 deny. A full semantic
  sweep (`grep -rn "assert_eq ask|\"ask\"|-> *ask|== .ask." tests/ adapters/ bin/ .claude/ docs/`)
  classified EVERY other hit: all remaining are Block C consent-tier `ask` (npm install/publish +
  bypass-awareness F-rows in test-codex-shims.sh / test-compat.sh / pre-tool-guard.sh /
  dmc_codex_common.py — LEGIT, out of scope), FROZEN fixtures (tests/fixtures/hooks-v0.6.5/*,
  bin/lib/dmc-v0.1.3-verify.sh — not edited), consumer contract docstrings (OQ1: leave), or the NEW
  v1.1.7 code itself (dmc-bash-radius.py:25/121/375/392/399/425 — the internal wrapper "ask" SIGNAL
  that funnels to the terminal deny; correct). test-adversarial.sh:211 is the ONLY stale EXTERNAL
  row. One same-file stale COMMENT at dmc-bash-radius.py:748 ("deny idiom / else ask") is already
  in-scope and folds into change (d)'s comment lockstep. Source: this session's sweep + live probe.
- Learning (Rev 3): a behavioral verdict flip must be swept SEMANTICALLY, not by literal token — a
  bare `assert_eq <verdict>` fixture carries no "3 ask" substring and evades a literal grep. Future
  ask/allow/deny changes must also enumerate `assert_eq <verdict>` / `-> <verdict>` fixture rows.

## Relevant Files

| Path | Reason | Allowed to Edit |
|---|---|---|
| bin/lib/dmc-bash-radius.py | Core: split_segments fd-dup guard (a1) + _redirect_targets companion (a2/B1) + traversal-safe safe-sink allowlist (B2) + ask->deny + docstring:21 + reason:426 + comment:748 + MODULE self-test rows (B3) | yes |
| docs/DMC_V1_ENFORCEMENT_MATRIX.md | Truthful lockstep: L1 row (:108) no longer "3 ask" | yes |
| bin/dmc | Truthful lockstep: bash-radius verb help (:66-68) L1 emits 0/4, not 3 | yes |
| docs/MILESTONES.md | Append the v1.1.7 milestone entry (append-one) | yes |
| tests/install/test-v1.1.7-safesink-askdeny.sh | NEW hermetic INTEGRATION test (armed-run live probes; inert-if-executed) | yes |
| tests/fixtures/m6/test-adversarial.sh | LOCKSTEP (Rev 3): stale W4 expectation — :211 `assert_eq ask`->`deny`, :212 label, :185/:210 comments; leaving it asserting superseded behavior is the forbidden one-sided-lockstep class; m6-suite is CI-visible | yes |
| .claude/hooks/pre-tool-guard.sh | Consumer; `3) ask` branch becomes unreachable. Read-only reference (OQ1: leave) | no |
| adapters/codex/dmc-codex-pretooluse.py | Consumer; `rc == 3` branch becomes unreachable. Read-only reference (OQ1: leave) | no |
| adapters/codex/dmc_codex_common.py | Consumer helper docstring enumerates 0/3/4. Read-only reference (OQ1: leave) | no |
| tests/fixtures/m6.5/test-codex-shims.sh | Parity — no ask-from-L1 row exists; MUST stay green unchanged (regression witness) | no |

## Out of Scope

- The Block C consent `ask` tier (npm/pnpm/yarn/bun publish, audit fix --force, schema push,
  migrate) — remains an `ask` verdict; NOT touched.
- Removing the EXIT_ASK constant or the `emit()` "ask" mapping (shared M6 exit-code contract).
- Editing the consumer `ask` translation branches or their docstrings (OQ1 ruling: leave; they
  describe the shared 0/3/4 exit space, and the authoritative enforcement-matrix doc IS updated).
- `dmc-postbash-diff`, scope-guard, secret-guard, L0 floor semantics (git-apply/patch, rm -rf,
  catastrophic/secret verbs) — unchanged.
- Frozen mirrors (`bin/lib/dmc-v0.*`, tests/fixtures/hooks-v0.6.5/*) and PINNED_BASELINE — untouched.
- Any section-9 adoption pilot (gates LIGHTENING/fail-open; this cycle, with B1/B2 closed, removes
  a human-dependency and net-tightens — see the Goal's Authorization note).

## Proposed Changes

- Change (a1): split_segments fd-dup guard — do NOT split on `&` when the immediately-preceding
  buffered char is `>` or `<` (a redirection-dup operator `>&`/`<&`; shell requires it contiguous,
  so a real backgrounding `cmd &` — space before `&` — is unaffected). Keeps `2>&1`/`>&FILE` in
  one segment. Files: bin/lib/dmc-bash-radius.py (split_segments ~:143).
- Change (a2) [B1, CRITICAL companion]: _redirect_targets — parse the `>&` / `N>&` fd-dup-or-redirect
  operator explicitly, BEFORE the existing `>` prefix/full regexes. Precise parsing spec:
    * Match operator token with `FDDUP_RE = ^(\d*)>&(.*)$` (optional leading fd digits; `.*` is a
      glued operand, possibly empty). This matches `>&`, `2>&`, `>&2`, `2>&1`, `2>&-`, `>&FILE`,
      `2>&FILE`. It does NOT match `&>`/`&>>` (ampersand BEFORE `>`), which stay on the unchanged
      REDIR_FULL/PREFIX path and already resolve their file target correctly.
    * Resolve the OPERAND: if the glued group is non-empty, operand = that glued suffix (consume 1
      token); if empty (bare `>&`/`N>&` token), operand = the NEXT token (consume 2).
    * CLASSIFY the operand: if it is a bare fd-number (`^\d+$`) or `-` => fd-duplication, DROP (no
      write target). Otherwise the operand is a FILE write target => append it, adjudicated against
      the scope lock exactly like any other redirect target.
    * Both glued (`>&/tmp/evil`) and spaced (`>& /tmp/evil`) file forms surface the file; both
      glued (`2>&1`) and spaced-numeric (`>& 2`) forms drop as fd-dups (the rare csh `>& 2` = file
      "2" edge is accepted per the critic ruling: numeric operands drop).
    * Keep the trailing `^&\d*[-]?$` filter as a belt-and-suspenders drop of any residual bare
      fd-dup fragment.
  Post-fix verdicts (VERIFIED this session against a 17-case battery, ALL PASS):
    >&FILE / &>FILE / N>&FILE / >& FILE / N>& FILE (FILE non-numeric) => surfaces FILE => adjudicate
      (out-of-scope => DENY, in-scope => ALLOW);
    2>&1 / 1>&2 / >&2 / 2>&- / >& 2 => fd-dup => no write target (drop);
    unchanged: `> f`, `>> f`, `2> f`, `&> f`, `&>> f`, `< f` (read) all behave as before.
  Files: bin/lib/dmc-bash-radius.py (_redirect_targets ~:234-251).
- Change (b) [B2]: safe-sink allowlist — `SAFE_SINKS = {"/dev/null","/dev/stderr","/dev/stdout"}`
  EXACT-set membership + `FD_SINK_RE = ^/dev/fd/[0-9]+$` anchored (NO startswith/prefix anywhere).
  In classify_l1, drop safe-sink paths from `resolved` before the state-hit / out-of-scope /
  adjudicate checks. A command whose only write targets are safe sinks and is otherwise unambiguous
  => ALLOW (NO-WRITE). VERIFIED this session: `/dev/fd/../../etc/passwd`, `/dev/fd/`, `dev/null`,
  `/dev/nullx` all reject; the three sinks + `/dev/fd/<n>` accept.
  Files: bin/lib/dmc-bash-radius.py (module constants + classify_l1 ~:401-408).
- Change (c) [ask->deny, OQ2]: the terminal `if ambiguous:` branch returns `"deny"` (exit 4)
  instead of `"ask"`. KEEP the `BASH-L1-AMBIGUOUS` reason-code prefix (grep stability); REWRITE the
  "— human decides" tail (:426) to a fail-closed instruction ("— denied fail-closed; reword to a
  concrete in-scope redirect target"). Keep EXIT_ASK + emit() table intact.
  Files: bin/lib/dmc-bash-radius.py (:423-426).
- Change (d) [docstring, OQ2 lockstep]: module docstring — update the L1 semantics line :21
  ("ASK for an ambiguous / unparseable target ... the human decides") to the DENY-fail-closed
  behavior, add the safe-sink/fd-dup semantics, note the exit-code (L1 emits 0 allow / 4 deny; 3
  remains a defined shared code the classifier no longer reaches), AND fix the same-file stale
  self-test section comment at :748 ("deny idiom / else ask" -> "...else deny (fail-closed)").
  Files: bin/lib/dmc-bash-radius.py (:1-35, :748).
- Change (e) [B3, MODULE self-test — CI-covered]: add to `selftest()` — (i) B1 negative controls:
  `>& FILE`, `&> FILE`, `N>& FILE`, and glued `>&FILE` with an OUT-OF-SCOPE file => DENY
  (out-of-scope); an IN-SCOPE `>& src/app.py` => ALLOW; (ii) fd-dup rows `2>&1`, `>&2`, `1>&2`,
  `2>&-`, `echo ok > src/app.py 2>&1` => ALLOW/no-write; (iii) B2 traversal control
  `> /dev/fd/../../etc/passwd` => DENY (out-of-scope, not a sink) plus safe-sink ALLOW rows
  (`>/dev/null`, `2>/dev/null`, `>/dev/stderr`, `>/dev/fd/2`); (iv) NO-ASK invariant — a battery of
  every former-ask input asserts rc4 and decision != "ask"; (v) convert the existing ambiguous
  (:612-618) and W4 wrapper (:651-654) ASK rows to DENY; (vi) L0 regression: a bare `git`+`apply`
  form with `2>&1` still L0 DENY; (vii) backgrounding `sleep 1 & echo done` not swallowed as fd-dup.
  Files: bin/lib/dmc-bash-radius.py (selftest()).
- Change (f) [B3, INTEGRATION test]: NEW tests/install/test-v1.1.7-safesink-askdeny.sh — standalone,
  mirrors tests/install/test-run-start-arming.sh: mints a real armed scope.lock and drives LIVE
  probes (inert-if-executed) end-to-end (positive: fd-dup + safe-sink + in-scope ALLOW; negative:
  `>& out-of-scope` DENY, run-state DENY, python-c / command-substitution / glob DENY-not-ASK, L0
  git-apply DENY; NO-ASK invariant; porcelain byte-identical). This is the integration layer; the
  module selftest (change e) is the CI-covered layer.
  Files: tests/install/test-v1.1.7-safesink-askdeny.sh (create).
- Change (g): enforcement matrix L1 row — replace "(0 allow / 3 ask / 4 deny)" with the v1.1.7
  behavior (safe-sinks/fd-dup allow; every remaining target in-scope allow or
  out-of-scope/ambiguous deny — 0 allow / 4 deny; L1 no longer asks).
  Files: docs/DMC_V1_ENFORCEMENT_MATRIX.md (:108).
- Change (h): bin/dmc bash-radius verb help — update "-> 0 allow / 3 ask / 4 deny" to note L1 emits
  0 allow / 4 deny (safe-sinks allow, residual-ambiguous deny). Files: bin/dmc (:66-68).
- Change (i): MILESTONES — append the "## v1.1.7 — Bash write-radius safe-sink allowlist +
  L1-AMBIGUOUS ask->deny — LOCAL (2026-07-10)" entry (what/why, evidence base, B1/B2/B3 closure,
  the Rev 3 test-adversarial lockstep, decisions, AC map). Files: docs/MILESTONES.md (append after
  the v1.1.6 entry).
- Change (j) [Rev 3, MANDATORY lockstep]: tests/fixtures/m6/test-adversarial.sh — flip the stale W4
  benign-wrapper expectation to the v1.1.7 behavior (~4 lines): :211 `assert_eq ask` ->
  `assert_eq deny`; :212 label -> "-> deny (undecidable radius fails closed, v1.1.7)"; the :185 and
  :210 comments "benign wrapper payload is ASK" -> "...is DENY (fail-closed)". Leaving a test
  asserting superseded behavior is the forbidden one-sided-lockstep class.
  Files: tests/fixtures/m6/test-adversarial.sh.

## Acceptance Criteria

- Criterion: [B1 closed] `>&FILE`, `&>FILE`, `N>&FILE` (glued and spaced) surface FILE as a write
  target — out-of-scope => DENY, in-scope => ALLOW; NO orphaned-target ALLOW-NO-WRITE remains.
  Verification Method: module self-test B1 rows (change e-i) + integration negatives, exit 4/0.
- Criterion: [fd-dup] `2>&1`, `1>&2`, `>&2`, `2>&-`, and `cmd >/dev/null 2>&1` classify with NO
  write target (ALLOW); the fd-dup alone never asks/denies.
  Verification Method: module self-test fd-dup rows, exit 0.
- Criterion: [B2 closed] safe-sink targets `/dev/null`, `/dev/stderr`, `/dev/stdout`,
  `/dev/fd/<n>` ALLOW; `/dev/fd/../../etc/passwd` (and any non-anchored form) is NOT a sink =>
  adjudicated => DENY (out-of-scope).
  Verification Method: module self-test B2 rows (change e-iii), exit 0 / exit 4.
- Criterion: [ask->deny] every residual L1-AMBIGUOUS case (python -c / variable /
  command-substitution / glob / directory / single-operand mv-cp / tee-no-file / wrapper-exec
  benign payload) returns DENY (exit 4), never ask (exit 3), with a `BASH-L1-AMBIGUOUS` reason.
  Verification Method: converted self-test rows + integration negatives, exit 4.
- Criterion: [NO-ASK invariant] no L1 input yields verdict `ask` (exit 3). A module-selftest
  battery of every former-ask command asserts rc != 3 and decision != "ask".
  Verification Method: module self-test NO-ASK battery (change e-iv).
- Criterion: [Rev 3 lockstep] no test asserts the superseded W4 benign-wrapper ASK —
  test-adversarial.sh:211 expects `deny`; `dmc selftest m6-suite` is rc0 (test-adversarial 38/0).
  Verification Method: `dmc selftest m6-suite` rc0; grep test-adversarial.sh for a wrapper-payload
  `assert_eq ask` finds none.
- Criterion: no regression on decidable targets — in-scope redirect/sed/tee/mv/cp still ALLOW;
  out-of-scope real file still DENY (OUT-OF-SCOPE); run-state write still DENY; L0 git-apply/patch
  still DENY armed & unarmed, including the git-apply form combined with `2>&1`; backgrounding
  `cmd & ...` not mis-parsed.
  Verification Method: existing + new self-test rows pass; `dmc selftest m6-core` rc0.
- Criterion: unarmed path unchanged (L1 stands down; safe-sink/fd-dup only affect armed L1).
  Verification Method: existing unarmed self-test rows (U1/W5) pass.
- Criterion: docs truthful in lockstep — enforcement matrix L1 row, bin/dmc bash-radius help,
  module docstring :21, comment :748, and the reason :426 reflect "L1 emits 0 allow / 4 deny (no
  ask)"; MILESTONES v1.1.7 entry present.
  Verification Method: grep asserts no "3 ask" / "human decides" claim remains in those surfaces;
  MILESTONES grep finds the v1.1.7 header.
- Criterion: cross-adapter parity intact — `dmc selftest m65-suite` (test-codex-shims.sh) green
  unchanged (no ask-from-L1 row existed).
  Verification Method: `dmc selftest m65-suite` rc0.
- Criterion: full battery green — `dmc selftest --all` legacy aggregate EXACTLY 802/3/3 + RESULT
  PASS; m6-core/m6-suite/m65-suite rc0; new integration test rc0; real-repo
  `git status --porcelain` byte-identical (Z1).
  Verification Method: the verification commands below.
- Criterion: value-blind + deterministic preserved — reasons name rules only; identical inputs ->
  identical verdict + exit.
  Verification Method: existing self-test D1 + Z1 rows pass.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| B1: `>&`/`N>&` orphaned file target fail-open (Rev 1 hole) | high | Change (a2) parses `>&FILE`/`N>&FILE` as adjudicated write targets; VERIFIED against a 17-case battery + module B1 negative controls (change e-i) |
| B2: `/dev/fd/` prefix traversal fail-open (Rev 1 hole) | high | Change (b) exact-set + anchored `^/dev/fd/[0-9]+$`, no startswith; VERIFIED reject of `/dev/fd/../../etc/passwd` + module traversal control (change e-iii) |
| split_segments is shared with the L0 git-apply floor; a bug could weaken L0 | high | Guard fires only on contiguous `>&`/`<&`; add git-apply-with-2>&1 L0-deny regression row; run full m6-core + m6-suite |
| fd-dup guard could swallow a real backgrounding `&` | medium | Guard only when the preceding buffered char is `>`/`<`; `cmd &` has a space before `&` — covered by a self-test row (VERIFIED `sleep 1 & echo done` splits correctly) |
| security-critical rows only in a CI-uninvoked standalone file | medium | B3: rows live in the MODULE selftest() (CI-covered via selftest --all + m6 legs); standalone file is the integration layer only |
| Bare `assert_eq <verdict>` fixtures evade literal greps (the Rev 3 gap) | medium | Rev 3 folds the test-adversarial W4 lockstep + records the semantic-sweep learning; a full sweep found no other stale external row |
| ask->deny denies a legitimate ambiguous write an agent needs | medium | Intended per user directive; reason instructs rewording to a concrete in-scope target; deny recovers in seconds vs. the hours-long ask stall |
| consumer `ask` (rc3) branches become unreachable dead code | low | OQ1: kept as defensive contract-complete mappings; EXIT_ASK stays a shared code |
| self-test case-count change trips a pinned count | low | Verified NO live assertion pins the count or the "3 ask" string |

## Assumptions

| Assumption | Confidence | How to Verify |
|---|---|---|
| Base is d02062c on claude/dmc-fable-core, .harness/mode=active | high | `git rev-parse HEAD` == d02062c; `cat .harness/mode` == active (verified) |
| No test pins the bash-radius self-test count or the "3 ask / 4 deny" string | high | grep of tests/ returned empty (verified) |
| No test-codex-shims.sh parity row asserts ask from L1-AMBIGUOUS (D9 is Block C) | high | tests/fixtures/m6.5/test-codex-shims.sh:325-333 (verified) |
| test-adversarial.sh:211 is the ONLY stale EXTERNAL ask-expectation; all others are Block C / frozen / new-code | high | Rev 3 semantic sweep across tests/ adapters/ bin/ .claude/ docs/ (this session) |
| `dmc help` only asserts it contains `--scope-input`, so editing bash-radius help is safe | high | tests/install/test-run-start-arming.sh:169-170 (verified) |
| DMC.md/CLAUDE.md "ask prompts" = Block C consent (remains true) -> no edit needed | high | DMC.md:73-74 grep (verified) |
| EXIT_ASK=3 is a shared M6 exit-code used by other CLIs (validate/scope-lock) -> keep constant | high | bin/dmc:262; bin/lib/dmc-bash-radius.py:48-49 |
| The B1 _redirect_targets spec and B2 sink regex close the holes with zero redirect regression | high | 17-case _redirect_targets battery + 12-case sink battery both ALL PASS this session |
| Standalone tests/install/* are not invoked by dmc-ci.yml (so B3 module coverage is required) | high | dmc-ci.yml runs `dmc selftest`; bin/dmc:648,:685 wire the module self-test |
| A-AUTH: the Human Release Gate pre-authorized this direction (user directive 2026-07-10: prompts only for true human gates; e2e autonomy otherwise) | high | .harness/evidence/dmc-fable-core-codex-bypass-build-20260710.md Incidents section 1 + .harness/metrics/ledger.jsonl |

## Execution Tasks

- [ ] DMC-T001: split_segments fd-dup guard (a1) — do not split `&` when the last buffered char is
  `>`/`<`. Files: bin/lib/dmc-bash-radius.py. Notes: ~3 lines at the control-op split (~:143).
- [ ] DMC-T002: _redirect_targets companion (a2/B1) — FDDUP_RE `^(\d*)>&(.*)$` handled BEFORE the
  `>` regexes; operand bare-fd/`-` drops, else surfaces as an adjudicated file target; both glued
  and spaced. Files: bin/lib/dmc-bash-radius.py.
- [ ] DMC-T003: safe-sink allowlist (b/B2) — SAFE_SINKS exact set + `^/dev/fd/[0-9]+$` anchored
  regex; filter from `resolved` before state-hit/adjudicate; NO startswith.
  Files: bin/lib/dmc-bash-radius.py.
- [ ] DMC-T004: ask->deny (c/OQ2) — terminal `if ambiguous:` returns "deny"; keep BASH-L1-AMBIGUOUS
  prefix, rewrite the :426 tail; keep EXIT_ASK + emit(). Files: bin/lib/dmc-bash-radius.py.
- [ ] DMC-T005: module docstring + comment (d/OQ2) — update line :21 + safe-sink/fd-dup semantics +
  exit-code note + the :748 self-test comment. Files: bin/lib/dmc-bash-radius.py.
- [ ] DMC-T006: MODULE self-test rows (e/B3) — B1 negatives, fd-dup ALLOW, B2 traversal control +
  safe-sink ALLOW, NO-ASK battery, convert ambiguous+W4 ASK->DENY, L0 git-apply-with-2>&1
  regression, backgrounding-not-swallowed. Files: bin/lib/dmc-bash-radius.py.
- [ ] DMC-T007: INTEGRATION test (f/B3) — tests/install/test-v1.1.7-safesink-askdeny.sh (armed-run
  live probes; inert-if-executed). Files: tests/install/test-v1.1.7-safesink-askdeny.sh.
- [ ] DMC-T008: enforcement matrix L1 row (g). Files: docs/DMC_V1_ENFORCEMENT_MATRIX.md.
- [ ] DMC-T009: bin/dmc bash-radius verb help (h). Files: bin/dmc.
- [ ] DMC-T010: MILESTONES v1.1.7 append-one entry (i). Files: docs/MILESTONES.md.
- [ ] DMC-T011 [Rev 3]: test-adversarial.sh W4 lockstep (j) — :211 `assert_eq ask`->`deny`, :212
  label, :185/:210 comments; then re-run `bin/dmc selftest m6-suite` (expect rc0, test-adversarial
  38/0). Files: tests/fixtures/m6/test-adversarial.sh.

## Verification Commands

| Command | Reason | Required |
|---|---|---|
| python3 bin/lib/dmc-bash-radius.py --self-test | classifier module self-test incl. B1/B2/NO-ASK rows rc0 | yes |
| bin/dmc selftest m6-core | Ring-0 verdict CLIs (bash-radius + siblings) rc0 | yes |
| bin/dmc selftest m6-suite | M6 hook-hardening suites incl. test-adversarial W4 lockstep (38/0) rc0 | yes |
| bin/dmc selftest m65-suite | Codex-adapter parity (test-codex-shims.sh) green unchanged rc0 | yes |
| bash tests/install/test-v1.1.7-safesink-askdeny.sh | integration armed-run probes rc0 | yes |
| bin/dmc selftest --all | legacy aggregate EXACTLY 802/3/3 + RESULT PASS (bash-radius uncounted) | yes |
| grep -nE "3 ask|human decides" docs/DMC_V1_ENFORCEMENT_MATRIX.md bin/dmc bin/lib/dmc-bash-radius.py | NO-ASK doc lockstep: no stale L1-ask claim remains | yes |
| git status --porcelain | working tree matches the changed-files-only scope (G2 staging) | yes |

## Approval Status

Status: APPROVED
Approver: human envelope gate (user directives 2026-07-10 "3번도 착수하자" + the no-prompts e2e-autonomy directive fixing this scope) + critic r2 APPROVE (dmc-v1.1.7-safesink-critic-r2.json)
Approved At: 2026-07-10

Revisions: Rev 1 (initial) → critic r1 REJECT (B1 CRITICAL >&FILE orphaned-target fail-open; B2 HIGH /dev/fd prefix traversal; B3 MEDIUM module-selftest CI coverage) → Rev 2 folds all three (a2 FDDUP_RE companion adjudication; exact-set + anchored fd sink; security rows in module selftest) → critic r2 APPROVE re-bind. Approval flip applied by the orchestrator lane (read-only planner does not self-approve); re-submitted for critic r3 hash re-bind. → Rev 3 (executor halt honored): adds the MANDATORY test-adversarial.sh W4 lockstep (change j / DMC-T011) — a bare `assert_eq ask` wrapper-payload row that the Rev 2 literal "3 ask" grep missed; a full semantic sweep found NO other stale external row (all remaining ask hits are Block C consent-tier, frozen fixtures, consumer contract docs, or the new v1.1.7 code) — plus the same-file :748 comment fold and the semantic-sweep learning. Authorization basis UNCHANGED (the behavioral change is already human-gated; this is its mandatory test lockstep). Status stays APPROVED on the same basis; critic r4 re-binds the new hash.
