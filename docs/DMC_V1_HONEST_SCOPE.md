# DMC v1.0 Honest Scope

Status: IMPLEMENTED (v1.0, M10). This document records what DMC v1.0 does NOT claim, and the
disclosed residual register carried forward to v1.1+. Nothing here is blocking for the v1.0 ship;
everything here is a known, written-down limitation. The point of the doc is that these gaps are
disclosed, not implied.

Companion docs: `docs/DMC_V1_ENFORCEMENT_MATRIX.md` (the per-harness/per-surface tiers) and
`docs/DMC_V1_RELEASE_CHECKLIST.md` (the human-facing release-gate mirror).

## 1. Approval identity = provenance, NOT authentication

The approval and worker-provenance checks verify SHAPE and CONSISTENCY of worker-supplied
metadata; they do not authenticate an actor. `.claude/hooks/worker-result-check.py:236` labels
its cross-checks exactly: "provenance-consistency cross-checks (worker-supplied metadata; NOT
authentication)". The audit records the same as B9 ("Q6 approval is shape-checked provenance,
not authentication").

Concretely: `result_id` is NOT a unique key — adapter-defaulted invocation ids can be shared
(M7 residual (f), disclosed in `apply-authorization.schema.md`); uniqueness rests on
`task_result_hash`, not on identity. Cryptographic approval authentication (the folded-in v0.6.6
mission) is deferred to v1.1+ (`docs/DMC_V1_RUNTIME_ARCHITECTURE.md:395`). The v1.0 guarantee is
provenance and consistency, never authentication.

## 2. Redaction = known shapes ONLY

The evidence-log redaction (`.claude/hooks/evidence-log.sh:72`, `redact()`) masks a FIXED set of
known secret shapes. Anything outside these shapes is NOT masked. The exact post-C2 class list
(hand-copied byte-equivalent into `adapters/codex/dmc_codex_common.py` and the m6.5 fixture,
kept in lockstep by the redaction-parity C3 test):

1. `sk-[A-Za-z0-9_-]{8,}` → `[REDACTED_API_KEY]`
2. `(password|secret|token|api[_-]?key)=<val>` → `\1=[REDACTED]`
3. `AKIA[0-9A-Z]{16}` → `[REDACTED_AWS_KEY]`
4. `eyJ<b64>.<b64>` → `[REDACTED_JWT]`
5. `xox[baprs]-...` → `[REDACTED_SLACK_TOKEN]`
6. `gh[opsu]_...` → `[REDACTED_GH_TOKEN]`
7. `ya29\....` → `[REDACTED_GOOGLE_TOKEN]`
8. `-----BEGIN..PRIVATE KEY-----` → `[REDACTED_PRIVATE_KEY]`
9. `(Authorization|Bearer)[ :]+<val>` → `[REDACTED_AUTH]`

A secret in any other shape is written to the evidence log unmasked. The redaction is a
defense-in-depth hygiene layer over known shapes, not a guarantee that no secret can ever reach
the log — the primary secret defense is the path-level read deny (secret-guard + the C1 Bash
secret-read block), which never opens the file at all.

## 3. Dependency / credential scan = regex best-effort

The worker-proposal dependency/credential guard is regex best-effort, not a semantic analyzer.
The DISALLOWED category list (`.claude/hooks/worker-result-check.py:26-33`) is:

- `.env*` — `(^|/)\.env(\.|$)`
- lockfile — `.lock`, `package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`
- dependency-file — `package.json`, `requirements.txt`, `go.mod`, `Cargo.toml`, `Gemfile`
- db/schema/migration — `migrations?/`, `drizzle`
- binary — `.png/.jpe?g/.gif/.pdf/.zip/.so/.dylib/.exe/.bin/.woff2?`
- production-config — `(prod|production)[.-].*config`, `.prod.`

This is a filename/path regex screen. A dependency or credential file whose name is outside these
patterns is not caught. Separately, M7 residual (b): `bin/lib/dmc-v0.2-verify.sh`'s credential
grep is a brittle content-substring coupling (two reworded validator comments pass only because
they carry the allow-word `never`; a future reword dropping it re-triggers the false positive) —
a v1.1+ hardening candidate to narrow the grep to real credential shapes.

## 4. Disclosed residual register (NONE blocking)

Source of truth: `.harness/plans/dmc-v1-runtime-upgrade-handoff.md:346-420` (items 10-15). Each
line is a disclosed, non-blocking residual carried to v1.1+.

DMC-PRIORITY (v1.1 activation tuning): the DMC-priority-over-other-layers clause (`CLAUDE.md`,
`docs/OMC_COEXISTENCE.md`) is instruction-level best-effort delivered via `UserPromptSubmit`
additionalContext — NOT a runtime boundary; Claude Code merges hook arrays and DMC cannot
suppress another plugin's hooks.

### M6 (item 12; verifier-confirmed, 4 flagged advisory)
- (a) a broad `Grep` with no path can still read secret-file CONTENTS in a non-secret dir (pre-M6 residual, unchanged by M6).
- (b) run-id-armed-without-lock window — edits between `run start` and scope-compile fall to the legacy path.
- (c) evidence-log "run is now BLOCKED" wording over-claims if the marker write fails (the stop gate fail-closes independently, so enforcement is intact).
- (d) `.claude/settings.json` unchanged ⇒ any NEW hook registration needs a session reload.
- (e) the operative snapshot is pinned-not-recaptured by design; the bash-radius deny message enumerates 4 basenames though `snapshot.txt` is enforced (cosmetic).

### M6.5 (item 10; Codex Option-A)
- (a) the Codex PostToolUse evidence append truncates an Edit/Write `file_path` to 500 chars WITHOUT `redact()` (exact parity with the accepted Claude baseline `evidence-log.sh:73`); the A5 shim-docstring wording slightly over-claims path-only deny coverage — tighten/redact in a later hygiene pass.
- (b) `_FLOORS` in `dmc_codex_common.py` is a faithful reproduction of the Claude static floors, guarded against drift only by the D-series parity fixtures (a change to `pre-tool-guard.sh` floors must be mirrored or D-series fails).
- (c) the Codex boundary under Option A was DOCUMENTED-ONLY at M6.5; M9 made it real (`.github/workflows/dmc-ci.yml`).
- (d) Option B (one-time, human-run, consented live-turn verification, NEW gate + own scope) remains available to upgrade the shims to verified-blocking.
- (e) `.codex/hooks.json` wiring shape + per-tool `tool_input` field names remain UNPROVEN at codex-cli 0.132.0 — re-probe at an Option-B turn or a newer CLI.

### M7 (item 13; worker hardening)
- (a) the apply-authorization chain is skill-mandated at apply time — nothing in Ring-0/1 blocks an in-scope Edit/Write lacking an authorization; the runtime write floor remains scope-lock adjudication; M9 makes chain-absence BLOCKING at release (the honest tier inherited by the enforcement matrix).
- (b) `dmc-v0.2-verify.sh:73`'s credential grep is a brittle content-substring coupling (see §3) — a v1.1+ narrowing candidate.
- (c) inert `SECRET_VALUE`/`PLACEHOLDER` module bindings remain in `worker-result-check.py` (no in-file consumer; harmless; future cleanup).
- (d) delegation chain hashing presupposes the module's compact-canonical line serialization — external chain authors need a disclosure line in `delegation.schema.md` (M9 consumer note).
- (e) `.harness/workers/authorizations/` is not in the installer's HARNESS_DIRS/host-.gitignore local-only block (installer frozen for M7; `authorize` mkdirs at runtime) — v1.1+ follow-up.
- (f) `result_id` is NOT a unique key (adapter-defaulted invocation ids are shared); uniqueness rests on `task_result_hash` (see §1).

### M8 (item 11; install/manifest)
- (a) the `verify-crosscheck` basename self-exclusion is a latent sharp edge — a dirty file sharing the report's basename evades the undeclared-file flag (benign, disclosed).
- (b) the A1 receipt-absent fallback removes fixed-name `dmc-*` bin/lib files — a host's own `dmc-something` file would be misidentified (documented, gate-accepted trade-off).
- (c) merge-target byte restoration is proven for CANONICAL-form host files only — non-canonical hosts get SEMANTIC restoration (honestly hedged).
- (d) M8 fixture host trees are materialized at runtime in mktemp (committed files = the 5 suite scripts only).
- (e) the `.codex/.dmc-created` sentinel must stay committed (never gitignored) for cross-clone provenance.
- (f) `dmc doctor`'s Claude-side "hook PROVEN" probe result applies to Claude only — the Codex column stays ADVISORY until a consented Option-B turn.

### M9 (item 15; release gate)
- (a) `delegation.schema.md` carries THREE additive text loci vs the "two additions" framing — all on-topic + validator-neutral (delegation 41/0); only the count undersells the third.
- (b) the chain sub-gate invokes `dmc delegation check --run RID` WITHOUT `--root`, resolving via the tool's `repo_root()` — correct for real closure + copy-surface E2E, fails closed on mismatched root; passing `--root` is a hygiene candidate.
- (c) the chain sub-gate is honestly a provenance/accountability tier, NOT tamper-detection (a deleted `delegations.jsonl` + deleted authorization ⇒ PASS-with-note via the run-dir append-log exemption); the mutation floor remains diff-scope + Ring-1 postbash.

### Pre-M10 audit DEFER-M10 backlog (`.harness/evidence/dmc-v1-audit-20260708.md:52-62`)
- A1 (MED, security): the L0 git-apply/patch deny + L1 write-radius are evadable via `eval …` and `$(…)` command substitution (inline grep anchors backtick not `$(`); postbash-diff backstops only when armed+active) — a focused security-hardening plan, not a minor edit.
- A2/A4/A5/A6: secret-directory Grep, run-dir self-authorable stop-gate inputs, no-python fail-open on the Bash surface, stop-gate quick-tier latency at scale.
- B3 (RUNNING→DONE unreachable — no `complete` verb), B4 (apply-check does not re-run check_review), B5 (checkpoints `--validate` structure-only).
- C3 (glm-api adapter does not token-scan output), C4 (secret-guard no symlink resolve), C5 (secret-filename coverage misses `prod.env`/`*.ppk`/`*.p8`/`*.asc`/`*.gpg`/bare `credentials`), C6/C7 (placeholder heuristic; `--out` target parity) — several touch the md5-identity-pinned `secret-paths.sh` triple.
- E1 (instance-validate leaves 7 documented enums unenforced), E3 (linkcheck scan-surface excludes schema/doc cross-refs).
- F3/F4/F5 (identity staleness — the M10 identity refresh deliverable), G3 (host-shipped `.gitignore` block narrow), G4 (`authorizations/` not in HARNESS_DIRS — same as M7 (e)), G5 (orphaned M2/M4 fixtures).

### Audit-remediation critic advisories (`.harness/evidence/dmc-v1-audit-remediation-critic-r2.json`)
- V1 (low): `resolve_scope_lock_ref` None maps to `DELEG-SCOPE-LOCK-TRAVERSAL`, and also None for an empty/absent ref (schema-guaranteed non-empty, so ~unreachable); fail-closed either way, cosmetic reason-code only.
- V3 (low): the C1 key/cert operand classes match as substrings — a benign path ending in `.key`/`.pem` denies on a read-verb; an accepted conservative over-match, no allow-set impact.

## 5. CF14 — CI-tier baseline / legacy `--all` divergence (the v1.0 posture)

This is the ratified v1.0 posture (gate decision option (b), `.harness/plans/dmc-v1-runtime-upgrade-handoff.md:397-409`): formalize the advisory tier plus a documented CI-tier baseline as the accepted v1.0 shipping state. The 13 substantive blocking checks are NEVER weakened.

- The blocking CI surface is the 13 substantive M9-built checks (plus the 2 porcelain sandwiches) on ubuntu-latest; the legacy `dmc selftest --all` replay is ADVISORY (`continue-on-error: true`) and count-divergent by design.
- Named-tool root cause (NOT brittle runner counts): `dmc-v0.2.6` diverges on all CI runners for a non-md5 cause (a git-version-sensitive porcelain assertion), `dmc-v0.3.9` cascades from its composition of v0.2.6, and `dmc-v0.3.1` additionally diverges on any non-BSD-md5/Linux host via its line-17-before-line-19 md5 ordering.
- The only pinned number, 802/3/3, is maintainer-local / committed-replica scoped — a dev-environment artifact, never a runner count. GitHub runner counts (e.g. ubuntu, macos-latest) are NOT pinned because runner-image bumps would silently invalidate them.
- Option (a) — hardening the frozen tools for runner portability — is a SEPARATE post-v1.0 hygiene milestone with GitHub-runner access; it is not folded into a feature milestone (CF1 discipline), and it must never mask the divergence by weakening the M9-built blocking checks.

## 6. D1 — bare-BSD-md5 vacuous self-asserts (documented, not hardened)

Roughly 20 FROZEN legacy tools (`bin/lib/dmc-v0.*` + their `.harness/evidence/` mirrors) use bare
BSD `md5` with no `md5sum` fallback in their "repo byte-unchanged / no-drift" self-assertions. On
any host without BSD `md5` (GitHub ubuntu ships only `md5sum`), the hash resolves to empty and the
check collapses to `'' == ''` — a silent vacuous PASS. This is DOCUMENTED, not hardened, for
v1.0 (a frozen-tool fix would break the mirror-pin; it is a separate v1.1+ hygiene plan).

- The AUTHORITATIVE real-repo cleanliness guarantee is NOT the md5 self-checks — it is the non-md5
  CI porcelain PRE/MID sandwiches (`.github/workflows/dmc-ci.yml`), which assert a byte-clean tree
  independently of any md5 tool.
- The one D1 site that masks a SECURITY invariant (not just hygiene) is
  `bin/lib/dmc-v0.2-verify.sh:15-17` — a secret-detector drift check that `md5`-compares
  `is_secret_path()` across `secret-guard.sh` and `lib/secret-paths.sh`; on a non-BSD-md5 host both
  sides collapse to empty and the drift check passes vacuously.
- The correct future-fix template already ships in the suite:
  `bin/lib/dmc-v0.4.9-autonomous-dry-run.sh:28-31` resolves a `HASH_CMD`
  (`md5sum || md5`) once and hard-fails via `require_hash()` if none exists, so the byte-unchanged
  check can never collapse to `'' == ''`. Any v1.1+ backport should follow that pattern.
