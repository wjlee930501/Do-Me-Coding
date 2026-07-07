# M6.5 Codex Adapter — Build Evidence (DMC-T011b.2–.5)

- **Milestone**: master plan §M6.5 (`DMC-T011b`) · **Plan**: `.harness/plans/dmc-v1-m6.5-codex-adapter.md` (Rev 2, APPROVED 2026-07-06 by wjlee)
- **Build run**: `dmc-run-fe05b840460e` (SUSPENDED wait-state; scope.lock 23 files, HEAD `40ad75a`)
- **Spike run** (T011b.1, closed): `dmc-run-8fef31d58eee` — see `.harness/evidence/dmc-v1-m6.5-spike-findings.md` + `.harness/evidence/dmc-v1-m6.5-spike-stop.md`
- **Date**: 2026-07-07 · **Recorder**: implementer lane (every count below RE-RUN by the recorder; no trust without re-execution)

## Governing framing — Option A (reduced scope), not enforcement parity

The T011b.1 spike concluded, at **codex-cli 0.132.0**, that whether Codex lifecycle hooks **fire**
and whether the deny/allow/block decision **envelopes** the shims emit are **honored** are BOTH
*unprovable turn-free* — a live authenticated model turn is the only path to prove either, and no
live turn is ever DMC-initiated. Per the plan's B4 per-fact disposition table that is a **FULL STOP
of the enforcing-shim build**; the STOP artifact `.harness/evidence/dmc-v1-m6.5-spike-stop.md` was
written and the human gate (wjlee, AskUserQuestion) chose **Option A**:

> Ship `.agents/skills/dmc-*` bindings + mirror module (T011b.3) and the AGENTS.md generator +
> schema (T011b.4) as planned (their surfaces were CONFIRMED turn-free), and build the
> `adapters/codex/` shims as **ADVISORY translators** — same Ring-0 verdict CLIs, same envelopes,
> same fixtures — with the **pre-commit/CI gate as the real enforcement boundary** and the **M6
> post-Bash diff guard as the primary Codex safety net**. **No enforcement-parity is claimed on Codex.**

Every artifact below carries the advisory status in its own bytes (README, config header, shim
docstrings) so the framing cannot be lost by reading any single file in isolation.

## Per-task build record

### DMC-T011b.1 — local Codex CLI verification spike (closed under `dmc-run-8fef31d58eee`)
- Outcome: hooks-fire + envelope-honoring UNPROVABLE turn-free at 0.132.0 → STOP → Option A.
  CONFIRMED turn-free: `.agents/skills/<name>/SKILL.md` discovery, trusted-project `.codex/config.toml`
  merge, sandbox modes, AGENTS.md `project_doc_max_bytes` 32 KiB cap; `hooks`/`multi_agent`/`unified_exec`
  stable + on by default. No live model turn; no API key read. Evidence + `docs/CODEX_ADAPTER.md`
  addendum landed in the spike run; the spike-phase report (`.harness/verification/dmc-run-8fef31d58eee.md`)
  is ACCEPT.

### DMC-T011b.2 — `adapters/codex/` advisory shims + `.codex/` templates + fixtures
- Files created:
  - `adapters/codex/dmc_codex_common.py` — shared Ring-1 translation library (event parse, superset
    field read, `.harness/mode` read, arming detection, `redact()` transform, path-only secret set,
    Codex envelope emitters). Advisory status stated in the module docstring.
  - `adapters/codex/dmc-codex-pretooluse.py` — `PreToolUse`: Bash→`dmc bash-radius`; Edit|Write→
    `dmc-scope-lock --adjudicate`; Read|Grep|Glob→path-only secret deny. (Claude counterparts:
    `pre-tool-guard.sh` + `scope-guard.sh` + `secret-guard.sh`.)
  - `adapters/codex/dmc-codex-posttooluse.py` — `PostToolUse`: `dmc postbash-diff` + `dmc run block`
    + redacted evidence append. (Claude: `evidence-log.sh`.)
  - `adapters/codex/dmc-codex-userpromptsubmit.py` — `UserPromptSubmit`: natural-activation router.
    (Claude: `dmc-router.sh`.) Not a gate — no deny/block envelope.
  - `adapters/codex/dmc-codex-stop.py` — `Stop`: `dmc stop-gate quick`. (Claude: `stop-verify-gate.sh`.)
    State-based (run id from `.harness/runs/current-run-id`, not the event), so it reaches Claude
    parity on every input incl. malformed.
  - `adapters/codex/README.md` — advisory-status home; file/event/Ring-0/Claude-counterpart table;
    trust + mode + fail-closed + field-superset + secret (B3/A5) + degraded-invariants pointers.
  - `.codex/config.toml` — per-project wiring; advisory + trust header; `sandbox_mode=workspace-write`,
    `[features] hooks=true, multi_agent=true` (documented as default-on, set for clarity).
  - `.codex/hooks.json` — wires the four bound events to the shims (`PreToolUse` Bash / Edit|Write /
    Read|Grep|Glob; `PostToolUse` Bash|Edit|Write; `UserPromptSubmit`; `Stop`).
  - `tests/fixtures/m6.5/_m65common.sh`, `tests/fixtures/m6.5/test-codex-shims.sh`.
- Suite: **`test-codex-shims.sh` 65 PASS / 0 FAIL** (recorder re-ran). Covers happy-path (allow/deny/
  block per event), the B2 fail-closed negative controls (a)–(d), the B3 secret-redaction + redaction-
  parity vs `evidence-log.sh redact()`, cross-adapter verdict parity (D-series incl. malformed), and
  passive/off stand-down parity (E-series).

### DMC-T011b.3 — Codex skill bindings + mirror/drift module
- Files created:
  - `.agents/skills/dmc-{plan-hard,critic,start-work,verify-hard,status}/SKILL.md` — Codex-standard
    frontmatter (`name`, `description` only) + one `<!-- DMC-HOST-NOTE:BEGIN/END -->` block carrying
    the Codex explicit-invocation mechanics; the operative payload is byte-identical to the Claude
    counterpart under the documented normalization.
  - `bin/lib/dmc-skills-mirror.py` — `.agents/skills ↔ .claude/skills` mirror/drift check (module +
    fixtures only; **does NOT edit `bin/dmc`** — single-owner rule A1). `MIRRORED_SKILLS` is the
    explicit five-name set, not a `dmc-*` glob.
  - `tests/fixtures/m6.5/test-skills-mirror.sh`.
- Suites (recorder re-ran): **`test-skills-mirror.sh` 19 PASS / 0 FAIL**; **`dmc selftest
  skills-mirror` module self-test 7 PASS / 0 FAIL** (negative controls: seeded one-byte drift REFUSED
  and named; missing counterpart REFUSED; unterminated BEGIN marker fails CLOSED to drift; unexpected
  extra `dmc-*` dir REFUSED; real repo byte-identical after).

### DMC-T011b.4 — host AGENTS.md generator + schema + validator + the SOLE `bin/dmc` edit
- Files created:
  - `bin/lib/dmc-agents-md.py` — 10-section AGENTS.md generator + `--validate`. Unknown-rule enforced;
    never overwrites / never blind-copies (merge policy); never truncates (32 KiB warn only). This verb
    IS the `/dmc-init-deep` generator (A4 skill→verb layering).
  - `.harness/schemas/agents-md.schema.md` — `dmc.agents-md.v1` content contract (native schema, not a
    mirror; not in the `validate schemas-mirror` set). Contract landmark authorized in the scope.lock.
  - `tests/fixtures/m6.5/test-agents-md.sh`.
- `bin/dmc` edit (the milestone's SOLE `bin/dmc` change, A1): registers BOTH verbs (`agents-md`,
  `skills-mirror`), the `run_m65_suite()` runner, and BOTH named selftest sections + the `m65-suite`
  aggregate, all wired into `--all`. Fast no-arg default preserved.
- Suites (recorder re-ran): **`test-agents-md.sh` 35 PASS / 0 FAIL**; **`dmc selftest agents-md`
  module self-test 24 PASS / 0 FAIL** (node/python/empty fixture hosts; Unknown renders literally;
  oversized doc warns but is NOT truncated + still validates; validator REFUSES a deleted section and
  a guessed-filler placeholder; deterministic byte-identical output).

### DMC-T011b.5 — evidence + verification (this record + the milestone report)
- `.harness/evidence/dmc-v1-m6.5-build-20260707.md` (this file) and
  `.harness/verification/dmc-v1-m6.5-codex-adapter.md`.

## Suite results — all RE-RUN by the recorder

| Suite / check | Result | How run |
|---|---|---|
| `tests/fixtures/m6.5/test-codex-shims.sh` | 65 PASS / 0 FAIL, exit 0 | standalone |
| `tests/fixtures/m6.5/test-skills-mirror.sh` | 19 PASS / 0 FAIL, exit 0 | standalone |
| `tests/fixtures/m6.5/test-agents-md.sh` | 35 PASS / 0 FAIL, exit 0 | standalone |
| `bin/dmc selftest m65-suite` (aggregate) | 119 PASS / 0 FAIL, exit 0 | 65+19+35 |
| `bin/dmc selftest skills-mirror` (module) | 7 PASS / 0 FAIL, exit 0 | named |
| `bin/dmc selftest agents-md` (module) | 24 PASS / 0 FAIL, exit 0 | named |
| `bin/dmc mirror-check` | PASS (55-file byte-equality), exit 0 | named |
| `bin/dmc linkcheck` | clean, 24 files scanned, exit 0 | named |
| `bin/dmc selftest linkcheck` (hermetic) | 17 PASS / 0 FAIL, exit 0 | named |
| model-name scan (`adapters/codex/`, new `bin/lib`, `.codex/`, `.agents/`) | 0 hits | grep, capability-class-only |
| `bin/dmc selftest` (fast default) | 75 PASS / 0 FAIL, exit 0 | preserved |
| committed-replica `bin/dmc selftest --all` | recorded in the verification report | throwaway replica |

## Disclosed deviations (honest residuals — none silent)

**(i) Active-mode controlled divergence — Codex shims fail CLOSED where Claude shims fail OPEN.**
This is deliberate (B2 mandate), not a parity break. On an ARMED + ACTIVE run, each Codex gate shim
emits deny/block on degenerate input — (a) unparseable/empty event JSON, (b) a missing/renamed field
on a recognized guarded tool, (c) an absent/failed Ring-0 verdict CLI, (d) an absent `.harness/mode`
(⇒ active) — where the corresponding Claude shim fails OPEN on (a)/(b). Everywhere else the two
adapters are asserted byte-comparable. Fixtures **D11–D15** assert the delta explicitly
(`D11` empty stdin, `D12` garbage stdin, `D13` renamed Bash command, `D14` renamed Edit path,
`D15` renamed Read path → *claude fails open = allow, codex hardens = deny*). In `passive`/`off` or
unarmed, both stand down identically (D10 parity rows), so no non-run session is bricked.

**(ii) B2 case (c) is N/A for Read/Grep/Glob.** The secret decision for Read/Grep/Glob is made
**in-process** (a path-only mirror of `secret-guard.sh`), with no external Ring-0 verdict CLI to be
"absent". So the "Ring-0 CLI absent → fail-closed" control (c) does not apply to those tools; it
applies to Bash (`bash-radius`), Edit/Write (`scope-lock` adjudicator), PostToolUse (`postbash-diff`),
and Stop (`stop-gate`). Recorded as fixture note **B5**; the path-only secret deny itself is still
proven (A6/A8, E2).

**(iii) `.codex/hooks.json` wiring shape is UNPROVEN at 0.132.0.** Whether Codex actually fires the
wired hooks and honors the emitted envelopes is exactly what the spike found unprovable turn-free.
The wiring is shipped as **documented advisory** (matching the confirmed `.codex/config.toml` trust
flow + the confirmed `hooks.json` schema shape), NOT as a proven runtime enforcement path. The
config/README state this in their own bytes and point at the pre-commit/CI gate as the real boundary.

**(iv) `MIRRORED_SKILLS` = the five plan-named workflow skills, not all `dmc-*`.** `.claude/skills/`
holds ~15 `dmc-*` skills; the milestone binds only the five core workflow verbs
(`dmc-plan-hard`, `dmc-critic`, `dmc-start-work`, `dmc-verify-hard`, `dmc-status`) to
`.agents/skills/`. The rest (the worker-bridge skills — a separate FROZEN surface per `DMC.md`
§Worker Bridge / M7 — and the mode-switch skills) are OUT OF SCOPE **by design**, not silently
skipped. The mirror module encodes this as an explicit named set; a literal `dmc-*` glob would
misreport all ten out-of-scope skills as "missing on Codex".

**(v) `tool_input` per-tool field names are still TBD.** The spike found no turn-free tool-schema
dump, so every field read in `dmc_codex_common.py` is a case-insensitive **superset** over documented
candidate key names across `tool_input` and the event top level. A truly renamed field on a real
guarded operation degrades to the fail-closed-in-active deny of (i)/(b), never a silent fail-open;
per the disposition table the PreToolUse edit-scope field shim is **backstop-only**, with the
post-Bash diff guard load-bearing.

## Scope + cleanliness

Applied edits lie within the `dmc-run-fe05b840460e` scope.lock (23-file allowlist). No `.claude/**`
or other protected-surface edit; the `.claude/hooks/**` redaction contract is CONSUMED read-only
(B3). No network / model / API call; no secret file contents opened (secret cases decide by path
only). The two pre-existing dirty files (`bin/dmc` M-state, `.harness/verification/dmc-run-8fef31d58eee.md`
the run #1-report fix) and the run-dir / auto-log artifacts are disclosed exempt/local-only paths
awaiting the phase commit — see the verification report's Scope Review and crosscheck accounting.

## Real-repo-untouched proof (replica work)

Real repo baseline before replica work: HEAD `40ad75aad1e26adb3e116d216555ef16006bafd0`,
`git status --porcelain` sha256 `5eb39d411a519fdd9ff0f6af54b1a04679f97f5998cd6a57ee066e3fb77edd8d`.
The committed-replica proof ran entirely in a throwaway scratch copy (built by `tar` pipe because the
armed `bash-radius` guard denies a `cp` destination out-of-scope by design — the copy idiom is not a
scoped repo write); the real repo HEAD + porcelain-sha were re-verified byte-identical after. Exact
counts and the identical-before/after proof are recorded in
`.harness/verification/dmc-v1-m6.5-codex-adapter.md`.
