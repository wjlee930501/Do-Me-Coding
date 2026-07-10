# Verification Report

## Run ID

dmc-run-8345cbf655e6

## Plan

- Plan: `.harness/plans/dmc-v1.1.7-safesink-askdeny-20260710.md` (Rev 3)
- Plan sha256: `72d9fa17f17024eff6395f678bd128136250357fce92d818268ddadf007f2144`
- Binding chain (all consistent):
  - run.json `plan_hash` == scope.lock `plan_hash` == critic-r4 `plan_hash` == computed plan sha256 == `72d9fa17…`
  - `compiled_at_head` == `d02062cdb15a367ca3ff46e97cb15be86628ef05` == current HEAD
  - operative snapshot bound: run.json `scope_lock_sha256` (`f5685cc4…`) == raw sha256 of scope.lock.json; run.json `snapshot_sha256` (`ad80d2b5…`) == raw sha256 of snapshot.txt
  - `dmc validate plan` -> VALID (dmc.plan-instance.v1)
- Critic chain: r1 REJECT (Rev 1 `020b12c3`, blockers B1/B2/B3) -> r2 APPROVE (Rev 2 `a31d0326`) -> r3 APPROVE (approval-flip `d337a410`, single-region delta proof) -> r4 APPROVE (Rev 3 `72d9fa17`, binding comment ruling). All four at `.harness/evidence/dmc-v1.1.7-safesink-critic-r{1,2,3,4}.json`; r1 is a conformant REJECT.

## Supersession

- Superseding run: dmc-run-8345cbf655e6 (6-path lock, plan_hash 72d9fa17, SUSPENDED, guard armed).
- Superseded run: dmc-run-7020c8701ee9 (5-path lock, plan_hash d337a410 — the Rev 3 additions had not yet added tests/fixtures/m6/test-adversarial.sh). Executor HALTED correctly on the out-of-scope stale assertion at that file:211; Rev 3 folded it in; run 7020 disarmed. Documented, not flagged.

## Changed Files

Tracked delta vs HEAD (numstat), all inside the 6-path scope.lock:

| Path | grant | +/- | landmark |
|---|---|---|---|
| bin/dmc | edit | +3/-1 | enforcement / authorized |
| bin/lib/dmc-bash-radius.py | edit | +150/-26 | enforcement / authorized |
| docs/DMC_V1_ENFORCEMENT_MATRIX.md | edit | +1/-1 | ordinary |
| docs/MILESTONES.md | edit | +59/-0 | release / authorized |
| tests/fixtures/m6/test-adversarial.sh | edit | +5/-4 | ordinary |
| tests/install/test-v1.1.7-safesink-askdeny.sh | create | +177 (new) | ordinary |

- Bounds: +395/-32 across 6 files vs lock `max_added 540 / max_deleted 90 / max_files 6` — within bounds.
- Exempt dirt only: `.codex/config.toml` (pre-existing working-tree modification, present at session start; not in this run's scope); untracked `.harness/evidence/*critic-r{1..4}.json` + plan (governance records). No stray tracked changes.
- Frozen / consumer / CI / identity surfaces byte-untouched (git status empty for): `.claude/hooks/`, `adapters/`, `bin/lib/dmc-v0.*`, `dmc-legacy-selftest.py`, `tests/fixtures/hooks-v0.6.5/`, `tests/fixtures/m6.5/`, `.github/`, `DMC.md`, `CLAUDE.md`, `AGENTS.md`.

## Commands Run

| Command | Result |
|---|---|
| `git rev-parse HEAD` | d02062c (== compiled_at_head) |
| `shasum -a 256 <plan>` | 72d9fa17… (== run/lock/critic-r4) |
| `shasum -a 256 <scope.lock.json>` | f5685cc4… (== run.json scope_lock_sha256) |
| `shasum -a 256 <snapshot.txt>` | ad80d2b5… (== run.json snapshot_sha256) |
| `bin/dmc validate plan <plan>` | VALID (dmc.plan-instance.v1) |
| `python3 bin/lib/dmc-bash-radius.py --self-test` | 95 PASS / 0 FAIL, rc0 |
| `bin/dmc selftest m6-core` | rc0 |
| `bin/dmc selftest m6-suite` | rc0 (test-adversarial 38/0, + 45/0, 10/0, 11/0) |
| `bin/dmc selftest m65-suite` | rc0 (Codex parity green, unchanged) |
| `bash tests/install/test-v1.1.7-safesink-askdeny.sh` | 66 passed, 0 failed |
| adversarial re-run (15 probes vs armed scope.lock) | all match critic security table; NO rc3 |
| `grep -nE "3 ask|human decides" <3 doc surfaces>` | empty (rc1) |
| semantic ask-outcome sweep of classifier | no net-verdict misdescription remains (rc1) |
| `git status --porcelain` (pre + post battery) | stable, byte-identical |

Adversarial re-run raw verdicts (`python3 bin/lib/dmc-bash-radius.py --cmd … --scope-lock <armed lock>`):

```
rc=4 deny  L1  :: echo pwned >&/tmp/evil
rc=4 deny  L1  :: echo pwned >& src/other.py
rc=4 deny  L1  :: echo x 2>& /tmp/evil
rc=4 deny  L1  :: echo x &> /tmp/evil
rc=4 deny  L1  :: echo x > dev/null            (relative, NOT a sink)
rc=4 deny  L1  :: echo x > /dev/fd/../../etc/passwd
rc=0 allow L1  :: echo hi 2>&1
rc=0 allow L1  :: echo hi 1>&2
rc=0 allow L1  :: echo hi >&2
rc=0 allow L1  :: echo hi 2>&-
rc=0 allow L1  :: echo x > /dev/null 2>&1
rc=0 allow L1  :: echo ok >& docs/MILESTONES.md  (in-scope ALLOW)
rc=4 deny  L0  :: git apply x.patch 2>&1
rc=4 deny  L1  :: python3 -c 'open("src/app.py","w")'
rc=4 deny  L1  :: sh -c "echo hi"
```

Not run by design (orchestrator's post-commit replica lane, per task instruction): `dmc selftest --all` and `gate release --full`.

## Manual Checks

- Code review (bin/lib/dmc-bash-radius.py) against the critic-approved spec:
  - (a1) split guard: `&` is not split when the preceding buffered char is `>`/`<`; the `&&`/`||` two-char check runs first, and a spaced backgrounding `cmd &` still splits. `split_segments("sleep 1 & echo done") == ["sleep 1","echo done"]`; `split_segments("echo x 2>&1") == ["echo x 2>&1"]`.
  - (a2/B1) `FDDUP_RE ^(\d*)>&(.*)$` matched BEFORE the `>` regexes; bare-fd / `-` / numeric operand drops as an fd dup, any other operand surfaced as an adjudicated file target (glued and spaced); `&>`/`&>>` stay on the plain REDIR path. Orphaned-target ALLOW-NO-WRITE eliminated.
  - (b/B2) `SAFE_SINKS` exact-set + `FD_SINK_RE ^/dev/fd/[0-9]+$` anchored, no startswith anywhere; safe sinks dropped from `resolved` before the state-hit/adjudicate checks.
  - (c) terminal `if ambiguous:` returns `"deny"`; `BASH-L1-AMBIGUOUS` reason prefix kept, tail rewritten to a fail-closed reword instruction; `EXIT_ASK=3` (:55) + `emit()` "ask" mapping (:122) retained but unreached by L1.
  - (d) funnel-integrity (r4 ruling): `_wrapper_verdict` still `return "ask", None` at :396/:403 (code UNCHANGED); `classify_l1` still `if wv == "ask": ambiguous = True` at :429 (code UNCHANGED, comment only); comment/docstring net-verdict clarifications applied at the WRAPPER_SHELLS block, :376-382 docstring (:378 outcome note), :430, and the :749 self-test comment. Changing the returns to `("deny", None)` would have fired the `wv=="deny"` branch with a null reason — correctly avoided.
- Adversarial re-run (independent, against the armed 6-path scope.lock): see raw table above — B1/B2 closed, fd-dups/safe-sinks ALLOW, in-scope `>&FILE` ALLOW, L0 git-apply floor holds under `2>&1`, no probe returned ask (rc3).
- NO-ASK invariant: module NO-ASK battery (10 former-ask inputs) + integration AD rows + adversarial re-run all assert rc!=3 / decision!="ask". Confirmed live this session: my own `python3 -c` bash call was denied fail-closed by the armed guard (BASH-L1-AMBIGUOUS).
- Docs-truthful lockstep: ENFORCEMENT_MATRIX:108 and bin/dmc bash-radius help both updated to "0 allow / 4 deny — L1 no longer asks" with safe-sink/fd-dup semantics; literal grep and semantic sweep both clean.
- Executor disclosed deviation (declined the optional AMBIGUOUS-reason assertion on the adversarial W4 row): ACCEPTABLE. The adversarial suite's `wrapper_verdict` helper is decision-only (prints deny|ask|allow) by construction; the AMBIGUOUS reason is asserted at the module layer (:669, :778) and the integration layer (:163). Critic r4 itself classified this row's reason-assertion as an "optional nicety." Reason-code coverage present at two layers — no gap.

## Scope Review

Result: PASS

Notes: Tracked working-tree changes are exactly the 6 scope.lock paths (5 edits + 1 create), within the +540/-90/6-file bounds (`forbidden_hunk_classes: []`). No out-of-scope tracked edit; frozen mirrors, Ring-1 consumers (`pre-tool-guard.sh`, codex shims), CI, and identity docs are byte-untouched. `.codex/config.toml` is pre-existing exempt dirt; the critic-verdict JSONs and plan are untracked governance records. Superseded run `dmc-run-7020c8701ee9` binds the older `d337a410` hash with a 5-path lock (no `test-adversarial.sh`, added in Rev 3) — expected and documented, not a defect.

## Package / Env / Migration Review

Package files changed: none
Env files changed: none
Migration files changed: none

Notes: bin/dmc is shell; bin/lib/dmc-bash-radius.py is stdlib-only Python — no new dependency, no package.json / lockfile / requirements change. No `.env*`, no environment-variable reads on the decision path; classifier remains env-independent. No schema/data migration; scope-lock and run-state schemas unchanged.

## AC Coverage

| Acceptance Criterion | Evidence | Status |
|---|---|---|
| B1 closed (`>&FILE`/`&>FILE`/`N>&FILE` surface FILE; out-of-scope DENY, in-scope ALLOW) | module B1 unit+CLI rows; adversarial re-run | PASS |
| fd-dup (`2>&1`/`1>&2`/`>&2`/`2>&-`, `cmd >/dev/null 2>&1`) no write target -> ALLOW | module fd-dup rows; adversarial re-run | PASS |
| B2 closed (safe sinks ALLOW; `/dev/fd/../../etc/passwd` DENY) | module B2 rows; `_is_safe_sink` review; adversarial | PASS |
| ask->deny (every residual L1-AMBIGUOUS -> DENY exit 4, BASH-L1-AMBIGUOUS reason) | terminal funnel review; module NO-ASK battery | PASS |
| NO-ASK invariant (no L1 input yields ask/exit 3) | module NO-ASK battery; adversarial (no rc3) | PASS |
| Rev 3 lockstep (test-adversarial.sh expects `deny`; m6-suite rc0, 38/0) | diff + m6-suite run | PASS |
| No regression on decidable targets + L0 git-apply(+`2>&1`) + backgrounding | module regression rows; m6-core rc0; adversarial | PASS |
| Unarmed path unchanged | module U1/W5 rows | PASS |
| Docs truthful in lockstep (matrix / bin/dmc help / docstring / :430 / :749) + MILESTONES entry | diffs + literal grep empty + semantic sweep clean | PASS |
| Cross-adapter parity intact (m65-suite green unchanged) | m65-suite rc0 | PASS |
| Full battery green — `selftest --all` == 802/3/3 + RESULT PASS | committed-replica lane | PENDING-POST-COMMIT |
| Value-blind + deterministic preserved | module D1/Z1 rows; porcelain byte-identical | PASS |

## Unresolved Risks

- None blocking. All Rev 1 critic blockers (B1 orphaned `>&FILE` target, B2 `/dev/fd/` prefix traversal, B3 CI-uninvoked test coverage) are closed and re-verified: B1/B2 via module + adversarial DENY rows; B3 via security rows living in the CI-covered module `selftest()`.
- Accepted documented edge (pre-ruled by critic r2): a csh-style `>& <digits>` spaced-numeric form drops as an fd-dup, so a file literally named with bare digits via that rare form is a miss — fail-closed-safe; realistic out-of-scope escapes use real paths and are adjudicated.
- Pending downstream gates (outside verifier scope, sequenced post-commit — the run is SUSPENDED/working-tree-only):
  - committed-replica `dmc selftest --all` == 802/3/3 EXACT + rc0 -> PENDING-POST-COMMIT (orchestrator's replica lane; not run by the verifier per instruction).
  - `gate release --full --run-id dmc-run-8345cbf655e6` -> PENDING-POST-STAGING (expect PASS; FLAG expected on bin/dmc + bash-radius.py + MILESTONES non-degrading; no G4 protected-path override present).

## Final Status

PASS

Working-tree implementation verified-complete; two downstream gates pending by design (the committed-replica `--all` and the staged-set release gate are the orchestrator's post-commit/post-staging steps). Binding chain intact, scope clean, funnel integrity held (internal 'ask' signal code unchanged; net armed verdict DENY), both Rev 1 fail-open blockers closed and adversarially re-verified, NO-ASK invariant holds live (the verifier's own python3 -c probe was denied fail-closed by the armed guard), and both halves of the cycle were observed working on the real armed run (safe sinks ALLOW; ambiguous idioms DENY fast).
