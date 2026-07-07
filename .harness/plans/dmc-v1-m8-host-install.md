# Plan: DMC v1 M8 — Host Install / Adaptation (P19 + P20)

Plan ID: dmc-v1-m8-host-install · Date: 2026-07-07 · Format: PLAN_SCHEMA.md
Milestone-scoped plan for master plan §M8 (task DMC-T013, Rev 3 execution order M6→M6.5→**M8**→M7→M9→M10).
**DRAFT** — critic pass is the next gate; the human release gate (wjlee) follows. Design authority:
`.harness/plans/dmc-v1-runtime-upgrade-audit.md` §10 (P19 installer defects) + §4.4/§4.5,
`docs/DMC_V1_RUNTIME_ARCHITECTURE.md` §P19/§P20, `docs/CODEX_ADAPTER.md` §3/§5,
`docs/HOST_REPO_ADAPTATION_POLICY.md`. Ships the surface M6.5 built (adapters/codex, .agents/skills,
.codex templates, host-AGENTS.md generator) plus the Ring-0 core (bin/) that no installer has ever
shipped; edits nothing M6/M6.5/M7 own.

**Rev 2** — revised after DMC critic r1 REJECT (persisted at
`.harness/evidence/dmc-v1-m8-critic-verdict-r1.json`; bound plan_hash `8dfdcf68…`, repo_hash
`82300bda…`). Surgical amendments only. Blockers closed:
- (B1) the model-name self-scan pins the NARROW model-version detector
  `claude-(?:opus|sonnet|haiku|fable|mythos)|gpt-[0-9]|codex-[0-9]` (`bin/lib/dmc-roles.py`
  `MODEL_NAME_RE` form), explicitly NOT the broad v0.6.1 vendor-word `MODEL_NAMES` list; exclusions
  enumerated verbatim (`orchestration/models.json`, the detector's own pattern-definition line, the
  `dmc-roles.py:394` selftest fixture line); harness identifiers `claude-code`/`codex` permitted (do
  not match the narrow regex) so `harness-matrix.json` passes; seeded-token control kept against the
  pinned detector.
- (B2) the `.gitignore` marker pair is pinned as VALID `#`-comment bytes `# DMC:BEGIN` / `# DMC:END`,
  distinct from the CLAUDE.md HTML pair `<!-- DMC:BEGIN -->` / `<!-- DMC:END -->`; both single-owner
  tasks reference the identical pinned bytes (what justifies their No-blockedBy parallelism).
- (B3) the doctor honesty control is scoped to the Codex row only (extract `/codex/i` lines, grep
  those) with the full forbidden lexeme set `enforced|enforce|fires|firing|runtime-enforced|active|
  guaranteed` + the required `ADVISORY`/`pre-commit/CI` substrings asserted on that same row.
- (B4) the install-time pre-existing host `.codex` collision policy is defined (skip-with-warn,
  never-overwrite) and a fifth `existing-codex` fixture proves byte-clean reversal.
- (B5) `--emit-manifest` reproduces the FULL manifest — copy tables from the installer's copy-list
  variables AND the hand-authored Dangling-reference rule + DELIBERATELY NOT COPIED sections from
  templated constants — so exact-equality cannot be achieved by deletion.
- Advisories folded: (A1) schema count 14→26 present-tense; (A2) real eval-fragility fixture
  (single-quote-in-path) replaces the invalid space-path falsifier; (A3) all 8 CODEX_ADAPTER §3
  matrix rows; (A4) hardened no-network grep (`\b(nc|netcat)\b` + python primitives); (A5) the
  `.agents/skills` ship set is the 5 M6.5 skills-mirror workflow skills, not 1:1 with `.claude/skills`.

**Rev 3** — revised after DMC critic r2 REJECT (persisted at
`.harness/evidence/dmc-v1-m8-critic-verdict-r2.json`; bound plan_hash `4f6a34ed…`, repo_hash
`82300bda…`). r2 confirmed B1–B5 CLOSED and A1–A5 folded; ONE new blocker + two advisories. Surgical
amendments only; everything r2 marked "met" is preserved, Out of Scope is unchanged, and the allowlist
gains no new row (the install receipt + sentinel are HOST-side artifacts written by the already-
allowlisted installer/uninstaller, not files in this repo; the new fixture arm is within the existing
`tests/fixtures/m8/**` row). Closed:
- (B6) an explicit `.codex` **provenance mechanism** now makes the created-only removal implementable
  and coherent under install→install→uninstall: the installer records every CREATED host path in a
  host-side receipt `.harness/install-receipt.json` (`created_paths`) AND drops a `.codex/.dmc-created`
  sentinel (pinned bytes) when it creates `.codex` from templates; the collision check treats an
  existing `.codex` WITHOUT the DMC signal as foreign⇒skip-with-warn and WITH it as DMC-owned⇒
  idempotent re-affirm (no misleading warning); the uninstaller removes only signal-carrying /
  receipt-recorded `.codex` paths and removes the receipt LAST; a new fixture arm proves
  fresh→install codex→install codex→uninstall is byte-clean with foreign content never touched.
- Advisories folded: (r2/B3) `dmc doctor` renders the enforcement matrix PER-HOST (each physical
  output line is about exactly one host) and reports the DMC mode host-independently, so no
  `claude-code=enforced` and no bare `active` mode word ever shares a Codex line (keeps the /codex/i
  control fail-closed-sound); (r2/uninstaller) the uninstaller removes DMC-shipped `bin/lib` files
  MANIFEST/receipt-SCOPED (the recorded shipped filenames), not a broad `bin/lib/**` glob — same
  provenance principle as B6, protecting a host's own `bin/lib` content.

Critic r3 re-pass + the human release gate remain PENDING. Approval Status stays DRAFT.

Task numbering: sub-numbered `DMC-T013.1 .. DMC-T013.5` under master §M8's own task `DMC-T013`
(M6 `DMC-T011.1–.4` / M6.5 `DMC-T011b.1–.5` precedent). `DMC-T013.N` was grep-verified unused across
`.harness/` and `docs/` before selection (only the parent `DMC-T013` appears, in the master plan).

## Goal

Make the DMC host installer actually ship and adapt the v1.0 control plane: install Ring-0 (`bin/dmc`
+ `bin/lib/**`) and Ring-1 adapters (`--host claude|codex|both`) with the M6.5 Codex surface,
regenerate `INSTALL_MANIFEST.md` from the installer so it stops being a stale SSoT, fix the audited
P19 defects (no-op gitignore strip, non-idempotent CLAUDE.md append, `${DRY:+}` cosmetic bug,
eval-quoting), add a `dmc doctor` that reports each host's enforcement honestly (Claude firing proven
by synthetic-event probe; Codex firing reported ADVISORY, never claimed), and land the P20 data files
(`orchestration/models.json` dated lookup + `orchestration/harness-matrix.json` enforcement matrix) —
all offline, marker/receipt-based, and reversible to byte-clean.

## User Intent

Classify: **feature** (secondary: refactor — installer/uninstaller repair and ship-surface
expansion; docs — the generated manifest and the enforcement-matrix data file are declarative
artifacts).

## Current Repo Findings

- Finding: the installer ships NO Ring-0 and NO adapters — `dmc-install.sh` copies `.claude/{hooks,
  skills,agents}`, `.harness` skeleton + schemas + mode, root docs, provider adapters, and merges
  CLAUDE.md/settings.json/.gitignore, but never copies `bin/`, `adapters/`, `orchestration/`,
  `.agents/`, or `.codex/`. A host's M6 shims would call a `bin/dmc` that was never installed.
  Source: `.claude/install/dmc-install.sh:27-113` (copy lists: HOOKS/SKILLS/AGENTS/HARNESS_DIRS/
  ROOT_DOCS — no `bin`/`adapters`/`orchestration`); audit §4.4.
- Finding: uninstaller `.gitignore` strip is a real no-op bug — the Python loop sets `skip=True` on
  the marker line but never tests `skip`, so only the marker line is dropped while every appended DMC
  line (`.harness/mode`, `.env`, worker paths) survives. Source: `.claude/install/dmc-uninstall.sh:
  38-43` (`skip=True; continue` then `out.append(ln)` unconditionally; `skip` is dead).
- Finding: the uninstaller never de-appends CLAUDE.md despite claiming to — line 28 prints
  "DMC-appended sections removed below" but no code removes the CLAUDE.md section (only `.gitignore`
  and `settings.json` are stripped). Source: `dmc-uninstall.sh:22-68` (no CLAUDE.md handling).
- Finding: the CLAUDE.md append is non-idempotent (no marker check ⇒ re-install duplicates the
  section) and uses a bare `<!-- Do-Me-Coding (appended by dmc-install) -->` open comment with no
  paired end marker, so there is nothing for a reversible strip to bound. Source: `dmc-install.sh:
  106-112`; audit §3.
- Finding: `${DRY:+...}` always expands because `DRY` is `0` or `1` (both non-empty), so a real
  install prints "(dry-run — nothing written)". Source: `dmc-install.sh:130`, `dmc-uninstall.sh:70`;
  audit §3. Related: `act()` runs `eval "$2"` over command strings that embed literal single-quotes
  around each path (`dmc-install.sh:24`) — robust to a bare space but broken by a single-quote / `$()`
  / metachar in the host path.
- Finding: `INSTALL_MANIFEST.md`'s "single source of truth" claim is false — it lists 3 schemas while
  the installer copies ALL **26** present `.harness/schemas/*.schema.md` (`dmc-install.sh:96` globs
  `*.schema.md`), and lists only `glm-api` while it copies the whole providers dir. It is
  hand-maintained, not generated. (The audit's "14 schemas" figure at audit §3 is stale; the drift
  direction holds and is understated, and the generate-from-installer remedy is count-agnostic.)
  Source: `INSTALL_MANIFEST.md:1-3,46`; `dmc-install.sh:96`; `ls .harness/schemas/*.schema.md | wc -l`
  == 26 at HEAD `82300bda`.
- Finding: the installer records no provenance of what it CREATED vs MERGED-into — CLAUDE.md/.gitignore
  use BEGIN/END markers and settings.json strips DMC-hook entries, but any newly created top-level
  path (and, post-M8, `.codex`, `bin/`, `orchestration/`) has no created-paths record, so a reversible
  uninstall cannot safely distinguish a DMC-created path from a host's own. Source: `dmc-install.sh`
  (no receipt/sentinel emitted); `dmc-uninstall.sh:18` (`rm -rf` by fixed name list, provenance-blind).
- Finding: there is no `dmc doctor` and no P20 data files — `bin/dmc` has no `doctor` verb, and
  `orchestration/` holds only `roles.json` (model-name-free). `orchestration/models.json` and the
  per-harness feature/enforcement matrix are specified but absent. Source: `bin/dmc` (case dispatch,
  no `doctor`/`models`); `ls orchestration/` == `roles.json` only; `docs/DMC_V1_RUNTIME_ARCHITECTURE.md`
  §P20.
- Finding: the M6.5 spike (codex-cli 0.132.0) proved Codex hook **firing** and decision-**envelope
  honoring** UNPROVABLE-TURN-FREE; the human gate chose Option A (advisory shims; the Codex
  enforcement boundary is the pre-commit/CI gate; the M6 post-Bash diff guard is the primary Codex
  safety net). Any doctor report and any Codex wiring the installer writes must preserve this honesty
  and NEVER bypass hook trust. Source: `docs/CODEX_ADAPTER.md` §Spike addendum + §3;
  `adapters/codex/README.md`; handoff rev 5 carry-forward #10.
- Finding: `.agents/skills/` holds only the 5 M6.5 workflow-skill mirrors (`dmc-critic`,
  `dmc-plan-hard`, `dmc-start-work`, `dmc-status`, `dmc-verify-hard`) vs 15 in `.claude/skills/`; the
  ship set is governed by the M6.5 skills-mirror invariant, NOT 1:1 skill parity between surfaces.
  Source: `ls .agents/skills/` (5) vs `ls .claude/skills/` (15); `bin/lib/dmc-skills-mirror.py`.

## Relevant Files

| Path | Reason | Allowed to Edit |
|---|---|---|
| .claude/install/dmc-install.sh | ship Ring-0 (`bin/`) + `orchestration/` always, + adapters/.agents/.codex per `--host`; P19 fixes (`${DRY:+}`, eval-quoting, HTML-pair idempotent CLAUDE.md append, `#`-pair `.gitignore` markers); write the host-side install receipt + `.codex/.dmc-created` sentinel (provenance); provenance-based `.codex` collision (foreign skip-with-warn / DMC-owned re-affirm); `--emit-manifest` (full, templated); Codex trust step surfaced ADVISORY | yes (T013.1 — SOLE installer owner) |
| INSTALL_MANIFEST.md | regenerated-from-installer (copy tables + hand-authored Dangling-reference rule + DELIBERATELY NOT COPIED sections emitted verbatim); drift-checkable via `--emit-manifest` | yes (T013.1 — SOLE manifest owner; M7 re-runs the generator later, expected) |
| .claude/install/dmc-uninstall.sh | reversibility: fix the dead-`skip` `#`-marker-pair `.gitignore` strip, remove the HTML-marked CLAUDE.md section, receipt/sentinel-scoped removal of the new `bin/`/`orchestration/`/adapters/.agents/.codex surfaces (removes the receipt LAST), `${DRY:+}` fix; byte-clean round-trip | yes (T013.2 — SOLE uninstaller owner) |
| bin/lib/dmc-doctor.py (new) | `dmc doctor` module: interpreter probe, hook-registration + Claude synthetic-event firing probe, Codex config/trust presence + honest ADVISORY reporting, foreign-harness/non-interference detection, per-host enforcement-matrix print from harness-matrix.json | yes (new; T013.3) |
| bin/dmc | register the `doctor` verb + `run_m8_suite()` + `doctor`/`m8-suite` selftest sections | yes (T013.3 — SOLE `bin/dmc` editor, single-owner rule) |
| orchestration/models.json (new) | P20 dated, replaceable model-version-name lookup (capability class → available bindings) — the SOLE sanctioned model-name home; non-load-bearing, read by no gate | yes (new; T013.3) |
| orchestration/harness-matrix.json (new) | P20 per-harness enforcement matrix — all 8 CODEX_ADAPTER §3 invariant rows × {claude-code, codex, opencode}; model-version-name-free (harness ids only); the data `dmc doctor` prints per-host | yes (new; T013.3) |
| tests/fixtures/m8/** (new) | 5 fixture host trees (empty, node, existing-claude-settings, existing-OMC, existing-codex) + round-trip/idempotency/doctor-negcontrol/manifest-drift suite scripts, incl. the codex install→install→uninstall provenance arm (hermetic, mktemp) | yes (new; T013.4) |
| .harness/evidence/dmc-v1-m8-*.md, .harness/verification/dmc-v1-m8-*.md | milestone evidence + verification report (`dmc validate verification` VALID) | yes (T013.5) |
| bin/dmc (other verbs), bin/lib/* (except dmc-doctor.py) | Ring-0 SHIPPED by the installer, not edited; the installer reads them as copy sources | no |
| adapters/**, .agents/**, .codex/** | M6.5 surface — the installer reads these as template/copy SOURCES and never edits them | no |
| orchestration/roles.json | registry frozen (M5); installer copies it, doctor reads it, neither edits it | no |
| .claude/hooks/**, .claude/settings.json | M6 frozen surface — the installer copies them into hosts; DMC's own copies are never edited here | no |
| .claude/hooks/worker-result-check.py, worker-context-guard.sh | M7's surface — shipped as-is; M7 hardens them and re-runs the manifest generator afterward | no |

## Out of Scope

- Any change to `.claude/hooks/**`, `.claude/settings.json`, worker validators (M7), provider
  adapters/router (never), or the M6/M6.5 adapter EXECUTABLES. M8 SHIPS these; it does not edit them.
- Making the Codex enforcement boundary real. Under Option A the pre-commit/CI gate IS the Codex
  boundary and is DOCUMENTED-ONLY today; **M9 makes it real**. M8 must not claim it is enforced.
- Option B (a one-time, human-run, consented live-turn verification to upgrade the Codex shims from
  advisory to enforcing) — remains a separate human gate with its own scope; not invoked here.
- Any live/network/model/API call anywhere in install, uninstall, or doctor paths; any credential
  read (`GLM_API_KEY`/`CODEX_API_KEY`); the `codex exec`/`/import` migration path as an installer
  dependency (spike: TUI-only, `external_migration` experimental+off).
- `docs/` identity/version refresh, the enforcement-matrix narrative doc, and the B1–B10 traceability
  table — **M10** owns those. M8 touches only the machine-readable `harness-matrix.json`.
- Model-binding consumption (delegation records reading `models.json`) — M8 lands `models.json` as a
  display/lookup DATA file only; no gate/routing code reads it.
- Deleting `.before-dmc`/zip strays; the `dmc-glm-smoke` protected-set cleanup — separate hygiene
  proposals (audit §5), own approval.
- Staging/commit/push; `docs/MILESTONES.md` (M10, append-only, human-gated).

## Proposed Changes

- Change: **Installer ship-surface + P19 fixes + provenance receipt** (`dmc-install.sh`). Add a
  `--host claude|codex|both` flag (default `claude`, preserving today's behavior). For ALL hosts ship
  the host-independent Ring-0: copy `bin/dmc` + `bin/lib/**` into `<host>/bin/` and
  `orchestration/{roles,models,harness-matrix}.json` into `<host>/orchestration/` (bin/ and
  orchestration/ are committed control plane, NOT added to the `.gitignore` block). For
  `--host claude|both` keep the current `.claude/**` copy set. For `--host codex|both` copy the adapter
  EXECUTABLES (`adapters/codex/dmc_codex_common.py` + the 4 `dmc-codex-*.py` shims) into
  `<host>/adapters/codex/`, the 5 `.agents/skills/dmc-*` M6.5 workflow-skill mirrors
  (`dmc-critic,plan-hard,start-work,status,verify-hard` — the skills-mirror ship set, NOT 1:1 with
  `.claude/skills`), and the `.codex/config.toml` + `.codex/hooks.json` TEMPLATES, and offer (never
  force) the host-AGENTS.md generator (`dmc agents-md`, the M6.5 verb) — never blind-copy DMC's own
  AGENTS.md (`HOST_REPO_ADAPTATION_POLICY`). **Provenance mechanism (pinned):** the installer writes a
  host-side install receipt at `<host>/.harness/install-receipt.json` — JSON with `created_paths`
  (every path DMC CREATED, e.g. `bin/dmc`, each shipped `bin/lib/<file>`, `orchestration/*.json`,
  `.codex/config.toml`, `.codex/hooks.json`, `.codex/.dmc-created`, `.agents/skills/dmc-*`) and
  `merged_targets` (CLAUDE.md/.gitignore/settings.json it appended-into) — and, when it creates
  `.codex` from templates on a host that had none, ALSO drops a sentinel file `<host>/.codex/.dmc-created`
  whose exact byte content is the single line `# DMC-CREATED` (analogous to the pinned marker pairs).
  The receipt is added to the DMC `.gitignore` block (host-local, never committed). **`.codex`
  collision policy (provenance-based):** if `<host>/.codex/config.toml` or `hooks.json` already exists
  WITHOUT the DMC signal (`.codex/.dmc-created` absent AND `.codex` paths not in the receipt) ⇒
  **foreign** ⇒ **skip-with-warn** (never-overwrite, `HOST_REPO_ADAPTATION_POLICY` §"warn and skip":
  print that DMC Codex wiring was NOT applied, advise a manual marker-merge; the trusted-project merge
  nuance in `CODEX_ADAPTER` §Wiring is documented, not auto-performed); if it exists WITH the DMC
  signal ⇒ **DMC-owned** ⇒ **idempotent re-affirm** (re-write the templates from source, keep the
  sentinel + receipt entry, NO misleading "wiring not applied" warning). Fixes: replace `${DRY:+...}`
  with an explicit `[ "$DRY" = 1 ]` conditional; harden `act()` so host paths with a single-quote /
  `$()` / metachar are safe (drop the fragile `eval`, or pass argv without re-quoting); make the
  CLAUDE.md append **idempotent + reversible** with a PAIRED HTML-comment marker `<!-- DMC:BEGIN -->` …
  `<!-- DMC:END -->` (skip when BEGIN present); wrap the `.gitignore` block in a PAIRED **`#`-comment**
  marker `# DMC:BEGIN` … `# DMC:END` (valid gitignore comments — the current single `#` marker at
  `dmc-install.sh:116` is replaced by this pair). Codex wiring the installer writes/prints carries the
  manual `/hooks` content-hash trust step + the ADVISORY (firing unproven at codex-cli 0.132.0) wording
  + names the pre-commit/CI gate as the Codex enforcement boundary; the installer NEVER passes
  `--dangerously-bypass-hook-trust`.
  Files: `.claude/install/dmc-install.sh`. Rationale: audit §4.4/§10 (hosts get v0.1.3 forever; the
  control plane is uninstalled); the two pinned marker pairs plus the receipt + sentinel are what make
  byte-clean reversal correct-by-construction and the double-install sequence coherent.
- Change: **Generated manifest** (`dmc-install.sh --emit-manifest` + `INSTALL_MANIFEST.md`). Add an
  `--emit-manifest` mode that prints the FULL manifest deterministically: the COPY/MERGE tables from
  the installer's own copy-list variables (single source = the installer) AND the hand-authored
  `## Dangling-reference rule` and `## DELIBERATELY NOT COPIED` sections emitted VERBATIM from
  templated heredoc constants embedded in the installer — so exact-equality with the committed
  `INSTALL_MANIFEST.md` cannot be achieved by DELETING those safety-relevant sections. Regenerate the
  committed manifest from it so the SSoT claim becomes true. Re-verify the §Dangling-reference rule
  over the expanded surface: the shipped adapter executables and templates must not pull DMC-internal
  READMEs/evidence into a host (those reference `.harness/evidence/dmc-v1-m6.5-spike-*.md` and
  `docs/CODEX_ADAPTER.md`, DMC working artifacts NOT shipped) — so the DMC-internal
  `adapters/*/README.md` are NOT installed; host Codex operating guidance comes from the generated
  `AGENTS.md` + the bundled `HOST_REPO_ADAPTATION_POLICY.md`. The generator is list-driven, so M7's
  later worker-validator changes are handled by re-running `--emit-manifest` (expected re-run,
  recorded).
  Files: `.claude/install/dmc-install.sh`, `INSTALL_MANIFEST.md`. Rationale: audit §3/§10 (manifest
  drift); kills the false-SSoT class of defect at the source without letting deletion pass the drift
  test.
- Change: **Uninstaller reversibility** (`dmc-uninstall.sh`). Fix the dead-`skip` `.gitignore` strip
  to remove everything between the paired `# DMC:BEGIN` … `# DMC:END` markers, byte-restoring a
  pre-existing host `.gitignore`. Remove the HTML-marked CLAUDE.md section (`<!-- DMC:BEGIN -->` …
  `<!-- DMC:END -->`) the installer now writes — closing the "never de-appends CLAUDE.md" gap.
  **Provenance-scoped removal:** read `<host>/.harness/install-receipt.json` `created_paths` and remove
  ONLY those recorded paths — the DMC-shipped `bin/lib` files by their recorded filenames
  (MANIFEST/receipt-scoped, NOT a broad `bin/lib/**` glob, so a host's own `bin/lib` content is never
  clobbered), `bin/dmc`, `orchestration/{roles,models,harness-matrix}.json`, `adapters/codex/**`,
  `.agents/skills/dmc-*`, and a `.codex` ONLY when it carries the DMC signal (`.codex/.dmc-created`
  present OR its `.codex` paths recorded in the receipt); a foreign `.codex` (no signal, not in the
  receipt) is NEVER touched. Remove the receipt file **LAST**. Replace `${DRY:+...}`. A host file DMC
  created (new CLAUDE.md/settings.json/.gitignore/.codex) is removed entirely (byte-clean); a host file
  DMC merged into has only its marked DMC additions removed, host content preserved.
  Files: `.claude/install/dmc-uninstall.sh`. Rationale: audit §3/§10 + r2 B6; provenance is the only
  sound basis for created-vs-foreign removal and for the install→install→uninstall sequence.
- Change: **`dmc doctor` + honest per-host reporting** (`bin/lib/dmc-doctor.py` + `bin/dmc`). A fast
  (<2s), offline verb that reports, per detected host: (1) interpreter presence (python3, jq, bash) —
  real, checkable; (2) **Claude Code** — hook registration in `settings.json` + a **synthetic-event
  firing probe** (feed a canned PreToolUse event JSON to the Ring-0 verdict CLI and observe the deny/
  allow envelope, exactly as the m6-suite does, turn-free) ⇒ reports firing as PROVEN; (3) **Codex** —
  `.codex/config.toml`/`.codex/hooks.json` presence + project-trust state + turn-free-confirmed
  surfaces (skills discovery, AGENTS.md discovery) ⇒ reports hook firing as **ADVISORY** and prints
  the pre-commit/CI gate as the enforcement boundary — it NEVER prints an enforced/fires-class claim
  on any Codex line; (4) foreign-harness detection + a non-interference/passive recommendation (reusing
  the installer's `detect_other_harness` logic); (5) the **enforcement matrix rendered PER-HOST** —
  each physical output line is about exactly ONE host (never a per-invariant line naming
  `claude-code=enforced` AND `codex` together), and the **DMC mode is reported host-independently**
  (the mode word `active` never appears on a Codex line) — so the /codex/i-scoped honesty control stays
  fail-closed-sound. `doctor` exits non-zero on a real defect (missing interpreter, Ring-0 absent,
  wiring gap). Register the `doctor` verb, a guarded `run_m8_suite()`, and the `doctor` + `m8-suite`
  selftest sections in `bin/dmc` (single-owner rule; sections are NAMED-ONLY + under `--all`, NEVER in
  the no-arg default).
  Files: `bin/lib/dmc-doctor.py`, `bin/dmc`. Rationale: audit §10 (no post-install self-check); the
  honest Claude-proven / Codex-advisory split is the M6.5 finding made operational.
- Change: **P20 data files** (`orchestration/models.json` + `orchestration/harness-matrix.json`).
  `models.json`: a dated, replaceable lookup mapping each capability class (from `roles.json`) to its
  available bindings {claude-code subagent | worker provider | human}; it is the ONLY new file
  permitted to carry model-version-name strings, is read by no gate/routing decision (doctor may
  DISPLAY it), and the model-name self-scan EXCLUDES it by design (the sanctioned home, like
  `CODEX_ADAPTER` §1's dated row). `harness-matrix.json`: model-version-name-free (harness identifiers
  `claude-code`/`codex`/`opencode` only, which do not match the narrow detector); carries ALL 8
  `CODEX_ADAPTER` §3 invariant rows — scope-edit, scope-bash, secret-read, stop-gate,
  natural-activation, approval, **hook-trust**, **protected-DMC-bindings** — each × {claude-code=
  enforced | codex=advisory(+named backstop) | opencode=stub}, faithful to §3. Both are Ring-0-adjacent
  DATA in `orchestration/` beside `roles.json`; both ship into hosts.
  Files: `orchestration/models.json`, `orchestration/harness-matrix.json`. Rationale: architecture
  §P20; model names live in a dated data file, never in Ring-0 code — keeping the model-independence
  invariant true by placement.
- Change: **Install fixture suite** (`tests/fixtures/m8/**`). FIVE hermetic fixture host trees —
  `empty` (bare), `node` (package.json), `existing-claude-settings` (canonical-form `settings.json`
  with a non-DMC hook), `existing-OMC` (`.omc/` marker), `existing-codex` (pre-existing
  `.codex/config.toml` WITHOUT the DMC sentinel = foreign) — plus self-contained suite scripts that run
  every check in `mktemp` sandboxes leaving the real repo byte-identical: `test-install-roundtrip.sh`
  (per host: install → `dmc doctor` PASS → uninstall → byte-clean; incl. the eval-fragility
  single-quote-in-path arm, a DMC-created-`.codex` arm, and the **codex provenance sequence** fresh →
  install `--host codex` → install `--host codex` → uninstall), `test-idempotency.sh` (double-install
  is a no-op AND the codex re-affirm case: the second `--host codex` install re-affirms rather than
  skip-warns), `test-doctor-negcontrols.sh` (seeded defects ⇒ doctor/drift FAIL), and
  `test-manifest-drift.sh` (`--emit-manifest` == committed manifest incl. the hand-authored sections).
  Fixtures with pre-existing merge targets are constructed in DMC-canonical JSON so the merge→strip
  round-trip is byte-exact.
  Files: `tests/fixtures/m8/**`. Rationale: acceptance is a round-trip proof, not prose; negative
  controls make each doctor claim falsifiable (M3 pattern).

## Acceptance Criteria

- Criterion: the installer ships Ring 0+1 — a `--dry-run` install into each fixture lists `bin/dmc`,
  `bin/lib/**`, `orchestration/{roles,models,harness-matrix}.json`, and (per `--host`) the Codex
  adapter executables + the 5 `.agents/skills/dmc-*` mirrors + `.codex` templates; a real `--host
  claude` install into the `empty` fixture yields a host tree where `bin/dmc help` runs. Negative
  control: an install with `bin/` omitted (seeded) ⇒ `dmc doctor` exits non-zero with "Ring-0 missing".
  Verification Method: `tests/fixtures/m8/test-install-roundtrip.sh` (dry-run listing asserts +
  post-install `bin/dmc help`) + the seeded-omission negative control, exit 0.
- Criterion: the P19 defects are fixed and falsified against their pre-fix behavior — (a) a real
  (non-dry) install prints NO "(dry-run)" text while `--dry-run` does (both asserted); (b) a
  double-install leaves exactly ONE CLAUDE.md HTML marker section (grep count == 1) and one
  `# DMC:BEGIN`…`# DMC:END` `.gitignore` block; (c) an install into a fixture whose absolute path
  contains a **single-quote** (a true eval falsifier — the pre-fix `act()` embeds literal
  single-quotes around each path, so it breaks on a single-quote but not on a bare space) succeeds
  after the fix and misbehaves before it.
  Verification Method: `test-idempotency.sh` + `test-install-roundtrip.sh` (single-quote-in-path arm),
  exit 0.
- Criterion: **byte-clean round-trip** — install → uninstall on `empty` and `node` (created-file case)
  leaves the host tree byte-identical to pre-install (`git status --porcelain` empty; `diff -r` clean);
  on `existing-claude-settings`, `existing-OMC`, and `existing-codex` (merge/skip case, canonical-form)
  the host CLAUDE.md / `settings.json` / `.gitignore` / `.codex` are byte-restored (DMC HTML/`#` marked
  sections removed; a foreign `.codex` was skip-with-warn'd at install and is byte-unchanged
  throughout). The install receipt `.harness/install-receipt.json` is host-local (gitignored) and
  removed LAST by uninstall, leaving no residual. Negative controls: the pre-fix dead-`skip` bug would
  leave DMC `.gitignore` lines ⇒ assert ZERO DMC lines remain; the pre-fix no-CLAUDE.md-removal would
  leave the DMC section ⇒ assert it is absent.
  Verification Method: `test-install-roundtrip.sh` byte-diff over all five fixtures + the two negative
  controls, exit 0.
- Criterion: the `.codex` provenance mechanism makes install/uninstall coherent and non-destructive —
  (i) installing `--host codex` into `existing-codex` (foreign, no sentinel) leaves the host
  `.codex/config.toml`/`hooks.json` BYTE-UNCHANGED, prints a skip-with-warn notice, and the subsequent
  uninstall leaves that foreign `.codex` byte-identical (never in the receipt, never touched);
  (ii) the sequence fresh host → install `--host codex` (DMC creates `.codex`, drops the
  `# DMC-CREATED` sentinel, records the `.codex` paths in the receipt) → install `--host codex` again
  (sees the DMC signal ⇒ idempotent re-affirm, NO skip-warn, no duplication) → uninstall removes the
  DMC-created `.codex` + sentinel + receipt (LAST) ⇒ the host tree is byte-clean and had no `.codex`
  originally. Negative control: a foreign `.codex` present during that uninstall is NEVER removed.
  Verification Method: `test-install-roundtrip.sh` codex-provenance-sequence + foreign-untouched arms
  + `test-idempotency.sh` codex-re-affirm arm, exit 0.
- Criterion: `dmc doctor` reports each host honestly — on the Claude fixture it reports interpreters +
  hook registration + a synthetic-event firing probe result (PROVEN) + an ENFORCED matrix row; on the
  Codex fixture it reports config/trust presence + skills/AGENTS.md discovery + an ADVISORY hook row +
  the pre-commit/CI boundary. The enforcement matrix is rendered **PER-HOST** (each physical line about
  exactly one host) and the DMC mode is reported **host-independently** (never the word `active` on a
  Codex line). The honesty control is **SCOPED to the Codex row/section only** — extract the
  doctor-output lines matching `/codex/i` and assert (i) NONE contains any forbidden lexeme,
  case-insensitively, from the set `enforced|enforce|fires|firing|runtime-enforced|active|guaranteed`,
  and (ii) that same Codex row DOES contain the required `ADVISORY` + `pre-commit/CI` substrings.
  Because the matrix is per-host and the control reads only Codex lines, the Claude `ENFORCED` row can
  neither mask nor trip it. Negative controls: (nc1) simulated-missing python3 ⇒ doctor FAILs the
  interpreter check; (nc2) a hook script present but unregistered in `settings.json` ⇒ doctor FLAGS the
  wiring gap; (nc3) a foreign harness present ⇒ doctor reports non-interference/passive; (nc4) a seeded
  "Codex hooks enforced" line ⇒ the scoped forbidden-lexeme control FAILs.
  Verification Method: `dmc selftest doctor` (module unit) + `test-doctor-negcontrols.sh` (Codex-scoped
  forbidden-lexeme grep), exit 0.
- Criterion: the P20 data files are correct and keep Ring-0 model-version-name-free — the self-scan
  uses the NARROW detector `claude-(?:opus|sonnet|haiku|fable|mythos)|gpt-[0-9]|codex-[0-9]`
  (case-insensitive; the `bin/lib/dmc-roles.py` `MODEL_NAME_RE` form), explicitly NOT the broad v0.6.1
  vendor-word `MODEL_NAMES` list (which would flag the bare harness word `claude`). Scanned surfaces:
  `bin/**`, `adapters/**`, `.claude/install/**`, `orchestration/roles.json`,
  `orchestration/harness-matrix.json`. Exclusions (verbatim): `orchestration/models.json` (the
  sanctioned dated home); the detector's own pattern-definition line (any line containing
  `MODEL_NAME_RE`); and the `bin/lib/dmc-roles.py` selftest fixture line (`:394`, whose
  `claude-opus-4-8`/`gpt-5`/`codex-5` are legitimate negative-control tokens). Harness identifiers
  `claude-code`/`codex` are PERMITTED (they do not match the narrow regex), so `harness-matrix.json`
  (which must carry `claude-code`/`codex`/`opencode` rows) passes. `harness-matrix.json` carries all 8
  `CODEX_ADAPTER` §3 rows; `models.json` is the SOLE model-version-name carrier and no gate/verdict/
  routing code reads it. Negative control: a seeded `codex-5`-class token in `bin/lib/dmc-doctor.py` ⇒
  the pinned detector trips (FAIL).
  Verification Method: the pinned-detector self-scan command (Verification Commands) with the
  enumerated exclusions + `models.json`-consumer grep + the seeded-token negative control, exit 0.
- Criterion: the manifest is generated FULL and drift-checkable — `dmc-install.sh --emit-manifest`
  output equals the committed `INSTALL_MANIFEST.md` byte-for-byte AND contains the hand-authored
  `## Dangling-reference rule` and `## DELIBERATELY NOT COPIED` sections (grep for their headers), so
  exact-equality cannot be reached by deleting them; the §Dangling-reference rule holds over the
  expanded ship-surface (no installed file references an unbundled `.md`). Negative controls: a
  hand-edited copy-table line ⇒ `test-manifest-drift.sh` FAILs; DELETING the Dangling-reference section
  from the committed manifest ⇒ the drift test STILL FAILs (the generator re-emits it). (M7 note: a
  later worker-validator change is handled by re-running `--emit-manifest`; expected, not a conflict.)
  Verification Method: `test-manifest-drift.sh` (byte-equality + section-presence + deletion negative
  control) + a dangling-reference scan over a dry-run install listing, exit 0.
- Criterion: the Codex hook-trust boundary is never bypassed and the wiring is presented as advisory —
  `dmc-install.sh` source contains ZERO `--dangerously-bypass-hook-trust`; the Codex wiring the
  installer writes/prints carries the manual `/hooks` content-hash trust step, the "firing unproven at
  codex-cli 0.132.0 / ADVISORY" wording, and names the pre-commit/CI gate as the Codex enforcement
  boundary; Option B is referenced as a separate human gate, not invoked.
  Verification Method: installer source grep (bypass flag absent) + `--host codex` install-output
  substring asserts, exit 0.
- Criterion: no live/network paths, hermetic fixtures, fast default preserved — install/uninstall/
  doctor sources contain zero network/model/API/credential primitives; the check is
  `grep -RInE '\b(nc|netcat)\b|curl|wget|urllib|http\.client|socket|requests|smtplib|ftplib|api\.|
  CODEX_API_KEY|GLM_API_KEY' .claude/install bin/lib/dmc-doctor.py` ⇒ no match (the doctor is python3,
  so python network primitives are the meaningful surface, and `\b(nc|netcat)\b` avoids the
  `sync/func/async` false positive). Every fixture runs in `mktemp` and the real repo `git status
  --porcelain` is byte-identical before/after the whole suite; `dmc selftest` (no arg) is still
  **75 PASS / 0 FAIL**; `dmc selftest --all` equals the pinned baseline (legacy **802/3/3 EXACT**,
  the three human-accepted FAILs untouched) + all prior sections + the new `doctor` and `m8-suite`
  sections at 0 FAIL.
  Verification Method: source grep + porcelain check + `dmc selftest` / `dmc selftest --all`, exit 0.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Merge-target byte-clean is only true for canonical-form host files (a host `settings.json` with non-canonical whitespace re-serializes on strip) | medium | fixtures constructed in DMC-canonical JSON so round-trip is byte-exact; the non-canonical-host case is documented honestly as **semantic** (host content preserved, DMC additions removed) not byte preservation — never over-claimed |
| A host with a pre-existing (foreign) `.codex` gets NO DMC Codex wiring under skip-with-warn (never-overwrite) | medium | this is the honest never-overwrite behavior; the installer prints the skip + advises a manual marker-merge; the `existing-codex` fixture proves the foreign `.codex` stays byte-unchanged; a DMC-created `.codex` is distinguished by the `# DMC-CREATED` sentinel + receipt, so re-install re-affirms and uninstall removes only DMC's own |
| Install-receipt corruption/loss would strand DMC-created paths on uninstall | medium | receipt is a small deterministic JSON the installer rewrites each run; the `.codex/.dmc-created` sentinel is a redundant local signal for the `.codex` case; uninstall removes the receipt LAST so a mid-uninstall abort can be re-run |
| `dmc doctor` gives false confidence about Codex enforcement | high | doctor reports Codex firing as ADVISORY only, never enforced-class; the matrix is per-host and mode is host-independent; the Codex-scoped forbidden-lexeme grep (7 lexemes) negative control fails the build if any enforced/fires/active/guaranteed claim lands on a Codex line; the enforcement matrix names the pre-commit/CI backstop |
| Uninstaller clobbering a host's own `bin/lib` content | medium | removal is receipt/manifest-scoped to the recorded DMC-shipped filenames, never a broad `bin/lib/**` glob (same provenance principle as `.codex`) |
| Shipping `bin/lib/**` into a host without the `.harness/evidence` originals breaks `dmc mirror-check` there | medium | mirror-check is declared a **DMC-development/CI invariant**, not a host gate; host install verification is `dmc doctor` + functional smoke, not `--all`; recorded in evidence and doctor's scope note |
| Manifest generator drifts from reality after M7 hardens worker validators | medium | generator is list-driven from the installer's own copy variables; hand-authored sections come from templated constants (deletion cannot pass the drift test); M7 re-runs `--emit-manifest` (expected re-run per the master Relevant Files M7+M8 tag) |
| Installer complexity/regression as `--host`, paired markers, receipt/sentinel provenance are added | medium | `bash -n` floor; the 5-fixture round-trip + idempotency + provenance-sequence + negative-control suite is the regression net; `--host claude` default preserves today's exact behavior |
| A shipped adapter/README pulls a DMC-internal reference into a host (dangling ref) | medium | DMC-internal READMEs/evidence are NOT installed; dangling-reference rule re-verified over the dry-run listing as an acceptance check; host guidance comes from generated AGENTS.md |
| Codex `.codex/hooks.json` wiring shape unproven at codex-cli 0.132.0 | medium (known) | installer writes it as ADVISORY wiring with the trust step surfaced; never bypasses trust; Option B (human-gated) is the upgrade path, out of scope here |

## Assumptions

| Assumption | Confidence | How to Verify |
|---|---|---|
| python3 (and optionally jq) available on target hosts | medium | `dmc doctor` interpreter probe; POSIX-sh deny floor remains the fallback; negative control nc1 |
| `bin/`, `adapters/`, `.agents/`, `.codex/`, `orchestration/roles.json` are frozen at the milestone HEAD — M8 SHIPS, never edits them | high | `git diff --name-only` vs this plan's allowlist; single-owner audit in the verification report |
| The install receipt + `.codex/.dmc-created` sentinel are the authoritative provenance for created-path removal | high | the codex install→install→uninstall + foreign-untouched fixture arms; the receipt is host-local and removed last |
| The M6.5 Codex surface (advisory shims + 5 skill mirrors + templates + AGENTS.md generator) is the surface to ship as-is under Option A | high | handoff rev 5 §M6.5 closure; `adapters/codex/README.md`; `docs/CODEX_ADAPTER.md` §Spike addendum; `bin/lib/dmc-skills-mirror.py` |
| Canonical-JSON merge fixtures make the install→uninstall round-trip byte-exact | high | `test-install-roundtrip.sh` byte-diff on `existing-claude-settings`/`existing-codex`; the non-canonical caveat is stated, not tested-as-byte-clean |
| `models.json` has no gate consumer in v1 (display/lookup only) | high | consumer grep (referenced only by doctor display); architecture §P20 marks it non-load-bearing |
| Codex hook firing/envelope honoring stays UNPROVABLE-TURN-FREE at 0.132.0 | high | M6.5 spike record; doctor reports ADVISORY accordingly; re-probe belongs to Option B / a newer CLI |

## Execution Tasks

- [ ] DMC-T013.1: Installer ship-surface + P19 fixes + provenance receipt + full generated manifest.
  Add `--host claude|codex|both` (default `claude`); ship `bin/` +
  `orchestration/{roles,models,harness-matrix}.json` for all hosts and the Codex adapter executables +
  the 5 `.agents/skills/dmc-*` mirrors + `.codex` templates for codex|both; write the host-side receipt
  `<host>/.harness/install-receipt.json` (`created_paths`/`merged_targets`; gitignored) and, when
  creating `.codex` from templates, drop the sentinel `<host>/.codex/.dmc-created` with exact content
  `# DMC-CREATED`; `.codex` collision = provenance-based (foreign⇒skip-with-warn, DMC-owned⇒idempotent
  re-affirm); fix `${DRY:+}` and drop fragile `eval` (single-quote/metachar-safe `act()`); write the
  PAIRED HTML markers `<!-- DMC:BEGIN -->`..`<!-- DMC:END -->` around the CLAUDE.md section (idempotent
  skip when BEGIN present) and the PAIRED `#` markers `# DMC:BEGIN`..`# DMC:END` around the `.gitignore`
  block; surface the Codex `/hooks` trust step ADVISORY and never `--dangerously-bypass-hook-trust`; add
  `--emit-manifest` that re-emits the FULL manifest (copy tables + templated Dangling-reference rule +
  DELIBERATELY NOT COPIED constants); regenerate `INSTALL_MANIFEST.md` from it and re-verify the
  dangling-reference rule (DMC-internal READMEs/evidence NOT shipped).
  Files: `.claude/install/dmc-install.sh`, `INSTALL_MANIFEST.md`
  Notes: SOLE owner of the installer AND the manifest (single-owner rule). Does NOT edit `bin/dmc`,
  adapters, `.agents`, `.codex`, or `orchestration/*` sources — reads them as copy sources. The receipt
  + sentinel are host-side artifacts (no repo allowlist row). No blockedBy: BOTH marker pairs and the
  sentinel bytes are pinned byte-verbatim in this plan (the `#` `.gitignore` pair
  `# DMC:BEGIN`/`# DMC:END`, the HTML CLAUDE.md pair `<!-- DMC:BEGIN -->`/`<!-- DMC:END -->`, and
  `# DMC-CREATED`), so writer (T013.1) and stripper (T013.2) cannot diverge.
- [ ] DMC-T013.2: Uninstaller reversibility (provenance-scoped). Fix the dead-`skip` `.gitignore` strip
  to remove everything between the paired `# DMC:BEGIN`..`# DMC:END` markers; remove the HTML-marked
  CLAUDE.md `<!-- DMC:BEGIN -->`..`<!-- DMC:END -->` section; read `<host>/.harness/install-receipt.json`
  and remove ONLY recorded `created_paths` — the DMC-shipped `bin/lib` files by their recorded
  filenames (receipt-scoped, NOT `bin/lib/**`), `bin/dmc`, `orchestration/{roles,models,harness-matrix}.json`,
  `adapters/codex/**`, `.agents/skills/dmc-*`, and a `.codex` ONLY when it carries the `# DMC-CREATED`
  sentinel / is receipt-recorded (a foreign `.codex` untouched); remove the receipt file LAST; fix
  `${DRY:+}`. Created files removed entirely (byte-clean); merged files lose only their marked DMC
  additions.
  Files: `.claude/install/dmc-uninstall.sh`
  Notes: SOLE owner of the uninstaller. Consumes the SAME pinned marker pairs + sentinel bytes + receipt
  schema T013.1 writes (shared byte-verbatim contract, each file single-owned). No blockedBy.
- [ ] DMC-T013.3: `dmc doctor` + P20 data files + SOLE `bin/dmc` edit. Create `bin/lib/dmc-doctor.py`
  (interpreters; Claude hook-registration + synthetic-event firing probe; Codex config/trust presence
  + honest ADVISORY reporting with no enforced-class claim on any Codex line; foreign-harness/
  non-interference; enforcement-matrix printed PER-HOST + mode reported host-independently; <2s; exits
  non-zero on real defect). Create `orchestration/models.json` (SOLE model-version-name home, no gate
  consumer) + `orchestration/harness-matrix.json` (harness-id-only; all 8 `CODEX_ADAPTER` §3 rows).
  Register the `doctor` verb + guarded `run_m8_suite()` + the `doctor`/`m8-suite` selftest sections in
  `bin/dmc` (named-only + under `--all`, NOT in the no-arg default).
  Files: `bin/lib/dmc-doctor.py`, `bin/dmc`, `orchestration/models.json`, `orchestration/harness-matrix.json`
  Notes: SOLE `bin/dmc` editor (single-owner rule). The `run_m8_suite()` runner is guarded (missing
  script ⇒ rc=1) so the `m8-suite` section may be registered before T013.4's scripts exist (M6.5
  precedent). No blockedBy (doctor logic is independent).
- [ ] DMC-T013.4: Install fixture suite. Build `tests/fixtures/m8/{empty,node,existing-claude-settings,
  existing-OMC,existing-codex}/` (canonical-form merge targets; `existing-codex` carries a pre-existing
  `.codex/config.toml` WITHOUT the DMC sentinel = foreign) + `test-install-roundtrip.sh` (5-host
  install→doctor→uninstall→byte-clean + seeded Ring-0-omission + single-quote-in-path arm +
  created-`.codex` arm + the codex provenance sequence fresh→install codex→install codex→uninstall +
  foreign-`.codex`-untouched arm), `test-idempotency.sh` (double-install no-op + codex re-affirm arm:
  second `--host codex` re-affirms, no skip-warn), `test-doctor-negcontrols.sh` (nc1 missing-python3 ·
  nc2 unregistered-hook · nc3 foreign-harness · nc4 seeded-Codex-enforced-line, Codex-scoped grep),
  `test-manifest-drift.sh` (`--emit-manifest` == committed manifest incl. the hand-authored sections +
  hand-edit + section-deletion negative controls). All `mktemp`-hermetic; real repo untouched.
  Files: `tests/fixtures/m8/**`
  Notes: test-only; edits no installer/uninstaller/`bin` source. The `m8-suite` section registered by
  T013.3 invokes these scripts. blockedBy T013.1, T013.2, T013.3.
- [ ] DMC-T013.5: Evidence + verification report. Record the ship-surface proof, P19-fix falsifications
  (incl. the single-quote eval-fragility arm), byte-clean round-trips over 5 fixtures, `.codex`
  provenance proof (foreign-untouched + install→install→uninstall byte-clean + re-affirm), doctor
  honesty (Claude-proven / Codex-advisory, per-host matrix, scoped control), P20 data-file correctness
  (all 8 §3 rows) + pinned-detector self-scan cleanliness, full-manifest drift PASS, no-network/hermetic
  proof, `selftest` 75/0, and `selftest --all` == baseline + new sections. Must pass
  `dmc validate verification`.
  Files: `.harness/evidence/dmc-v1-m8-*.md`, `.harness/verification/dmc-v1-m8-*.md`
  Notes: final status PASS | FAIL | PARTIAL; single-owner audit + `git diff --name-only` vs allowlist
  included. blockedBy T013.1, T013.2, T013.3, T013.4.

## Verification Commands

| Command | Reason | Required |
|---|---|---|
| bash -n .claude/install/dmc-install.sh .claude/install/dmc-uninstall.sh ; python3 -m py_compile bin/lib/dmc-doctor.py | syntax floor over touched files | yes |
| python3 -m json.tool orchestration/models.json orchestration/harness-matrix.json | P20 data files parse | yes |
| bin/dmc selftest | fast default unchanged — 75 PASS / 0 FAIL | yes |
| bin/dmc selftest --all | pinned baseline (legacy 802/3/3 EXACT) + all prior sections + new `doctor` + `m8-suite`, 0 FAIL | yes |
| bin/dmc selftest doctor ; bin/dmc selftest m8-suite | doctor unit + install round-trip/idempotency/negcontrol/manifest-drift | yes |
| tests/fixtures/m8/test-install-roundtrip.sh | 5-host install→doctor→uninstall→byte-clean + Ring-0-omission + single-quote-path + created/foreign/sequence `.codex` provenance arms | yes |
| tests/fixtures/m8/test-idempotency.sh | double-install no-op + codex re-affirm (2nd `--host codex` re-affirms, no skip-warn) | yes |
| tests/fixtures/m8/test-doctor-negcontrols.sh | doctor falsifiability (missing-python3 · unregistered-hook · foreign-harness · Codex-scoped forbidden-lexeme grep over `enforced\|enforce\|fires\|firing\|runtime-enforced\|active\|guaranteed`) | yes |
| tests/fixtures/m8/test-manifest-drift.sh | `--emit-manifest` == committed INSTALL_MANIFEST.md (byte + section-presence; hand-edit + section-deletion negative controls) | yes |
| grep -RInE 'claude-(opus\|sonnet\|haiku\|fable\|mythos)\|gpt-[0-9]\|codex-[0-9]' bin/** adapters/** .claude/install/** orchestration/roles.json orchestration/harness-matrix.json  (exclude orchestration/models.json + the MODEL_NAME_RE definition line + bin/lib/dmc-roles.py:394) ⇒ no match | narrow model-version detector; Ring-0 stays model-name-free; harness ids claude-code/codex permitted | yes |
| grep -RInE '\b(nc\|netcat)\b\|curl\|wget\|urllib\|http\.client\|socket\|requests\|smtplib\|ftplib\|api\.\|CODEX_API_KEY\|GLM_API_KEY\|dangerously-bypass-hook-trust' .claude/install bin/lib/dmc-doctor.py ⇒ no match | no network/credential/trust-bypass path in install/doctor (python primitives + word-bounded nc) | yes |
| grep -Rn 'models.json' bin/ adapters/ (assert: only doctor display references it, no gate/verdict path) | models.json is display/lookup-only, read by no gate | yes |
| git status --porcelain (before/after the whole m8-suite) ; git diff --name-only vs this plan's allowlist | real-repo byte-cleanliness + scope conformance | yes |

## Approval Status

Status: APPROVED
Approver: wjlee (human release gate; granted via AskUserQuestion in the 2026-07-07 session,
option "승인 — Rev 3 그대로", after the critic chain r1 REJECT (5 blockers B1–B5, plan_hash
`8dfdcf68…`) → Rev 2 → r2 REJECT (B1–B5 confirmed closed; 1 new blocker B6, plan_hash
`4f6a34ed…`) → Rev 3 → r3 APPROVE bound to the frozen pre-approval bytes sha256
dd8e23d7246836517103c1e94d949c94132759f6c01b9981d56639137907c24c — verdicts persisted at
`.harness/evidence/dmc-v1-m8-critic-verdict-r{1,2,3}.json`; r3 is the binding artifact;
`dmc verdict validate` VALID ×3 and `dmc verdict gate --plan-hash dd8e23d7…` PASS pre-gate)
Approved At: 2026-07-07

Approval record (verbatim scope of the human gate, 2026-07-07):
- **Approved**: DMC-T013.1–.5 exactly as specified in §Execution Tasks — installer ship-surface +
  P19 fixes + provenance receipt + full generated manifest; uninstaller provenance-scoped
  reversibility; `dmc doctor` + P20 data files + the SOLE `bin/dmc` edit; the 5-fixture install
  suite; evidence + verification.
- **Advisory disposition (recorded at the gate, M6.5-A5 pattern)**: critic r3's three non-blocking
  advisories are accepted AS-IS for this approval and bind the IMPLEMENTATION: (A3 — MANDATORY
  implementation directive) the `.codex/.dmc-created` sentinel is committed-alongside `.codex`,
  NEVER gitignored (cross-clone provenance); (A1) implementers add a fixed-name fallback removal
  for the unconditionally-shipped Ring-0 paths when the receipt is absent, or record the honest
  residual; (A2) the T013.5 verification report hedges "working tree restored" vs "git-status
  clean after the host committed the control plane".
- **Explicitly NOT approved**: staging/commit/push (separate human gates); any `.claude/hooks/**`,
  `.claude/settings.json`, worker-validator, or provider-adapter edit; making the Codex
  enforcement boundary real (M9); Option B live-turn verification (separate human gate, own
  scope); any live/network/model/API call; `docs/` identity refresh and the B1–B10 traceability
  table (M10).
- Approval is recorded here and in the master plan §Approval Status. NOTE (carry-forward-9
  pattern): appending this record changes the plan file's hash by design — the r3 verdict binds
  the pre-approval bytes `dd8e23d7…`, this record cites that hash, and run.json binds the
  post-append bytes.
