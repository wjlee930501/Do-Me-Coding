# Build Evidence — v1.1.5 Codex adapter Block C bypass-awareness mirror (dmc-fable-core-codex-bypass)

Date: 2026-07-10 · Branch: `claude/dmc-fable-core` · Base: `497ca4b` (v1.1.4 deployed; main FF'd + CI green same day) · **Change commit: `92371db`** (+277/0: `adapters/codex/dmc_codex_common.py` 61, `adapters/codex/dmc-codex-pretooluse.py` 7, `tests/fixtures/m6.5/test-codex-shims.sh` 132, `docs/MILESTONES.md` 77).
Work ID: `dmc-fable-core-codex-bypass` · Registered follow-up item 2 · Authorization: standing envelope + user directive 2026-07-10 ("2번도 적용하자"); push→CI→main-FF separately pre-authorized by the user for after BOTH v1.1.5 and v1.1.6 complete ("v1.1.5, v1.1.6도 완료되면 푸시까지 진행해줘").

## What shipped

The Codex adapter's Block C Python mirror now carries the v1.1.1 ask-tier bypass-awareness. Under a host-attested top-level `permission_mode == "bypassPermissions"` (exact literal), the Block C `ask` verdict stands down to an advisory: byte-identical systemMessage to the Claude side + ONE value-blind `<UTC> ask-tier-standdown class=<cls>` line in `.harness/metrics/ask-tier-advisory.log` + exit 0. Deny floors (Block A/B) and Block D write-radius NEVER stand down (the branch sits at the unique `ask` verdict point, structurally after deny returns). Inert-if-absent: no field / any other value ⇒ byte-identical current behavior (fail-closed to ask).

Unblocking research (this session, GPT-5.6 launch day): Codex CLI hooks now officially document `permission_mode` with the SAME enum as Claude Code (`default|acceptEdits|plan|dontAsk|bypassPermissions`). Live delivery on a real Codex turn remains turn-free-unprovable — the mirror inherits the adapter's Option-A ADVISORY posture; no enforcement-parity claim added (recorded at v1.1.1-equal prominence in the MILESTONES entry).

## Chain (single armed run, first-pass clean)

| Stage | Artifact / evidence |
|---|---|
| Research | Codex `permission_mode` documented-enum finding (session research lane; fed the registered decision) |
| Plan Rev 1 (DRAFT `f34f0b7b…`) → critic r1 APPROVE (0 blockers; 3 executor-level advisories) | `.harness/evidence/dmc-fable-core-codex-bypass-critic-r1.json` |
| Approval flip → Rev 2 (`2c9fff0b…`) — applied by the ORCHESTRATOR lane; the genuinely read-only planner declined to self-approve its own artifact (lane separation upheld; critic r2 ruled the routing C11-clean) → critic r2 APPROVE re-bind | `...-critic-r2.json` |
| Armed run `dmc-run-5d7b9cb3ca28` (one-command `--scope-input`, 4-path lock, changed-files-only per the v1.1.4 G2 learning) → suspend | run dir `run.json` / `scope.lock.json` |
| Opus executor: M1+M2+section F+MILESTONES; all 3 critic advisories folded (shared systemMessage extractor; snake=parity/camel=defensive key comment + snake in parity rows; fresh passive sandbox) | executor report; `92371db` diff |
| Independent Opus verifier: **zero defects**; honest PARTIAL verdict (solely the two by-design post-staging gates unrun — "no verification, no done" applied to itself) | `.harness/verification/dmc-run-5d7b9cb3ca28.md` (schema-VALID) |
| Green set minted (CHK-V115-MIRROR/SECTIONF/MILESTONES) + all frozen validators green | run dir green set + `release-readiness.json` |
| **Release gate PASS** — 8 sub-gates PASS + landmark-flag FLAG (non-degrading: the two enforcement `.py` + MILESTONES; candidate staged after arming so flagged as expected); NO G4 override (adapters/codex not in DEFAULT_PROTECTED) | `release-readiness.json` verdict PASS |
| Change commit | `92371db` |

## Final verification (AC closure)

- Executor + verifier live battery: `test-codex-shims.sh` **161 PASS / 0 FAIL** (143→161, +18 section F), `selftest m65-suite` all four RESULT lines 0 FAIL, porcelain hermetic.
- grep-AC: `bypassPermissions` token appears ONLY at common.py:56 (keys comment), :483 (standdown docstring), :498 (systemMessage) and pretooluse.py:52/:55 (ask branch) — NO deny-path reference.
- Deny-under-bypass: F4 (`git push --force`) + F5 (secret cat) still deny with bypass present; F7 passive+bypass ⇒ no ask/no message/no log (mode composition); F8 value-blind (fake token absent from log); F-PAR1 cross-adapter extracted systemMessage byte-EQUAL + same log-line shape.
- Neutrality: `agents-md --root . --stdout | diff - AGENTS.md` EMPTY; `dmc-install.sh --emit-manifest | diff - INSTALL_MANIFEST.md` EMPTY (both .py are name/path-class listed; content edits neutral — F7 finding held).
- **Committed-replica `--all` at `92371db`** (clone --no-hardlinks into non-DMC-named dir `replica-v115`, remote severed): `aggregate: tools=49 PASS=802 FAIL=3 N/A=3` EXACT + `SELFTEST-ALL RESULT: PASS` + replica `test-codex-shims.sh: 161 PASS / 0 FAIL` + **overall exit 0**.
- Metrics: ledger row appended for `dmc-run-5d7b9cb3ca28`.

## Incidents & learnings (registered)

1. **Unattended ask-tier stall (drove a user directive + v1.1.7 scope):** one exec-lane probe containing `2>&1` was classified BASH-L1-AMBIGUOUS by the write-radius under the armed window → ask → the confirmation prompt sat for HOURS unattended. Two sibling probes with decidable targets (`2>/dev/null`) were DENIED and self-corrected in seconds. User directive recorded: prompts only for true human gates; e2e autonomy otherwise. v1.1.7 scope fixed accordingly: safe-sink allowlist (`/dev/null`, `/dev/stderr`, `/dev/stdout`, `/dev/fd/*`, `2>&1` fd-dup = allow) + residual L1-AMBIGUOUS ask→deny (fail-fast; strictly fail-closed).
2. Read-only planner lane correctly refused to write `Status: APPROVED` into its own plan — approval-flip mechanics belong to the gate-holding orchestrator lane (critic r2: C11-clean). House pattern updated.
3. SendMessage bodies starting with raw `{` are swallowed as protocol objects (two verdict deliveries lost before diagnosis) — all lanes now instructed to wrap JSON in code fences with leading text.
4. Armed-window guard also adjudicates ORCHESTRATOR Bash: out-of-repo path arguments deny (BASH-L1-OUT-OF-SCOPE), and out-of-repo Writes (session memory) are blocked until disarm — both correct fail-closed behavior, worked around by deferral/cd.

## Pending

- Records commit for this cycle is deliberately DEFERRED until after the v1.1.6 gate (run `dmc-run-6e707694161f` was armed at `92371db`; moving HEAD before its gate would break the compiled_at_head binding). One records commit will follow the v1.1.6 change commit.
- Push → CI → main FF: pre-authorized by the user for after BOTH cycles complete; executed by the orchestrator at that point.
