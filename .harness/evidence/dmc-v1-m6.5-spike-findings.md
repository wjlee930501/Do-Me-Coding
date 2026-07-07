# M6.5 Codex Adapter — Local CLI Verification Spike (findings)

- **Task**: DMC-T011b.1 (BLOCKING GATE for T011b.2–.5)
- **Date**: 2026-07-06 (probes executed 2026-07-06 UTC; command log timestamps below are `...15:20Z`)
- **Codex CLI**: `codex-cli 0.132.0` at `/usr/local/bin/codex` → `@openai/codex` (npm install)
- **Run**: dmc-run-8fef31d58eee (SUSPENDED; scope.lock: create spike-findings.md, create spike-stop.md, edit docs/CODEX_ADAPTER.md)
- **Plan**: `.harness/plans/dmc-v1-m6.5-codex-adapter.md` (APPROVED Rev 2)
- **Design authority**: `docs/CODEX_ADAPTER.md` §1 facts table + §Open questions

## No-live-turn attestation

NO live model turn was taken. NO API key was read, set, or required (`CODEX_API_KEY` never touched;
no `~/.codex/auth*` or credential file read; `codex login` never run). All probes used an **isolated
scratch `CODEX_HOME`** and a scratch git project under the session scratchpad, never the user's real
`~/.codex`. No secret file contents were read. The only network the local CLI initiated on its own is
recorded verbatim in §"CLI-initiated network" — no model turn resulted (401 throughout, no auth). No
simulated proofs: every "confirmed" verdict below has an observed local behavior behind it.

## Headline determination (B — the load-bearing sub-question)

**Can hook firing AND deny/allow/block envelope honoring be proven with NO live model turn?**
**NO — UNPROVABLE-TURN-FREE.** A live authenticated model turn is the ONLY path to prove either.
This triggers the plan's B4 No-live-turn STOP rule → `.harness/evidence/dmc-v1-m6.5-spike-stop.md`
is written and the decision is handed to the human gate. Default fallback per plan: documented-manual
+ pre-commit/CI gate; the enforcing-shim build for the firing/envelope claims is FULL-STOPPED.

Basis (all observed, see appendix):
- Offline `codex exec --json` on a **trusted** scratch project emits `thread.started` → `turn.started`
  → immediately opens a websocket to `wss://api.openai.com/v1/responses` (401, no auth) → retries →
  `turn.failed`. **No SessionStart / UserPromptSubmit / PreToolUse hook marker was created.** The
  lifecycle reaches for the model connection before any enforcement hook side-effect is observable.
- The enforcement-critical events DMC binds (PreToolUse deny, PostToolUse evidence/diff, Stop gate)
  fire around a **model tool-call or turn-end** — i.e., they require a successful model turn.
- There is **no headless hook surface** anywhere in the CLI: an exhaustive subcommand search found no
  `hook test`/`emit`/`replay`/`--dry-run`. The only hook-related flag is `--dangerously-bypass-hook-trust`
  (exec/resume/fork), which disables trust-gating — it does NOT fire hooks headlessly, and the plan
  forbids using it. `debug` exposes only `models`, `app-server`, `prompt-input` (no hook emitter).

## Per-fact disposition (mirrors the plan's per-fact table; verdict per fact)

| CODEX_ADAPTER §1 fact | Spike verdict | Evidence | Disposition triggered |
|---|---|---|---|
| Lifecycle hooks FIRE (PreToolUse/PostToolUse/UserPromptSubmit/Stop) with JSON stdin | **UNPROVABLE-TURN-FREE** | offline `exec` reaches model websocket first; no markers; no headless emit surface | **FULL STOP** of enforcing-shim build → documented-manual + pre-commit/CI gate; human gate (STOP artifact written) |
| Hook decision contracts honored (PreToolUse deny/allow/updatedInput; Stop `decision:block`) | **UNPROVABLE-TURN-FREE** | envelope honoring needs a model tool-call/turn-end; no replay/dry-run path | **FULL STOP** of the enforcement claim → that path ships advisory-only + pre-commit/CI gate; human gate |
| Hook enforcement honesty — unified_exec / non-shell non-airtight | **CONFIRMED (gap is live)** | `features list`: `unified_exec  stable  true` (on by default) | STANDING degradation (not a stop): post-Bash diff guard is PRIMARY Codex net |
| PostToolUse observes unified_exec writes | **UNPROVABLE-TURN-FREE** | needs a turn; unified_exec active by default | SCOPED: diff guard runs at Stop + pre-commit gate |
| tool_input field names per tool | **TBD-STILL (unprovable turn-free)** | no turn-free tool-schema dump; needs a turn or the hooks reference | SCOPED: PreToolUse edit-scope degrades to backstop-only (post-Bash diff guard); path-only secret + instruction rule remain |
| Hook trust (content-hash `/hooks`; changed hooks skipped) | **CONFIRMED (mechanism); UX not headless-observed** | `--dangerously-bypass-hook-trust` exists on exec/resume/fork | SCOPED: document manual trust step + fail visibly; NEVER bypass |
| Skills `.agents/skills/<name>/SKILL.md` discovery | **CONFIRMED turn-free** | scratch `test-skill` appears in `debug prompt-input` skills block with its `.agents/skills/...` path | No degradation — skill bindings viable |
| Per-project `.codex/config.toml` trusted-project merge | **CONFIRMED turn-free** | untrusted ⇒ project config not loaded (render `read-only`); after `[projects."<path>"] trust_level="trusted"` ⇒ loads (`workspace-write`) | No degradation for config load; hooks.json firing is the separate unprovable fact above |
| Sandbox modes read-only \| workspace-write \| danger-full-access | **CONFIRMED** | `--help` possible-values; render reflects `sandbox_mode` | — |
| Sandbox read-only `<root>/.codex`,`.agents` asymmetry | **NOT DIRECTLY RE-PROVEN** | `codex sandbox macos` requires a `--permissions-profile` whose 0.132 schema was not mapped in-timebox | SCOPED (non-load-bearing): rely on scope guard over those paths; no stop |
| AGENTS.md discovery + `project_doc_max_bytes` (32 KiB) size cap | **CONFIRMED turn-free** | 40431-byte AGENTS.md truncated to a 32936-char injected block (END_MARKER dropped); `-c project_doc_max_bytes=2000` ⇒ 2168-char block | No stop — generator must respect the cap (answers the size-budget open question) |

### Corrections to §1 (tagged in docs/CODEX_ADAPTER.md)

- **`hooks` / `multi_agent` are STABLE and ENABLED BY DEFAULT at 0.132.0**, not experimental/gated.
  `features list`: `hooks  stable  true`, `multi_agent  stable  true`, `plugin_hooks  stable  true`,
  `plugins  stable  true`. The §1 config.toml row (`[features]` flags incl. hooks) and the subagents
  row ("gated behind the `multi_agent` feature flag") over-state the gating — both features are on.
- **A `permissions.profiles` / `default_permissions` model exists** (`codex sandbox` requires a named
  `--permissions-profile` resolved from the config stack; error `default_permissions refers to
  undefined profile ...`). This is a refinement beyond the doc's `.codex/rules`-centric framing;
  schema not fully mapped in-timebox.

## Turn-free probe results (p1–p5)

- **p1 — `codex exec` offline**: WORKS AS A PROBE, proves the negative. Trusted scratch project, no
  auth: `thread.started`→`turn.started`→websocket 401→`turn.failed`; no hook markers. Shows the
  lifecycle reaches the model connection before any observable enforcement-hook side-effect. Does NOT
  prove firing/envelope honoring.
- **p2 — replay / `--dry-run` / transcript-replay surface**: DOES NOT EXIST. No `--dry-run` on `exec`;
  no replay/emit under `debug` (only `models`, `app-server`, `prompt-input`); exhaustive per-subcommand
  grep for `hook|replay|dry-run|emit|test` found only `--dangerously-bypass-hook-trust` and doctor's
  "Emit a redacted machine-readable report".
- **p3 — direct hook-runner / emit path**: DOES NOT EXIST. No `hooks` subcommand; no hook-emit verb.
- **p4 — `/hooks` trust-UX inspection**: PARTIAL. Trust mechanism CONFIRMED to exist (bypass flag);
  the exact interactive `/hooks` content-hash UX is TUI-only and was not observed headless. Trust
  persists under `CODEX_HOME` (project trust recorded as `[projects."<path>"] trust_level="trusted"`
  in `$CODEX_HOME/config.toml`, verified by the config-load flip in p-config below).
- **p5 — sandbox read-only `.codex`/`.agents` via direct file op**: NOT COMPLETED. `codex sandbox
  macos` requires `--permissions-profile <NAME>` from the config stack; the 0.132 permissions-profile
  schema was not mapped within the timebox, so the asymmetry was not directly re-proven. Non-load-bearing
  per the disposition table (scoped degradation stands regardless) — no stop.
- **p-config (trusted-project merge, extra probe)**: CONFIRMED. `debug prompt-input` renders `read-only`
  for an untrusted scratch project even though its `.codex/config.toml` sets `workspace-write`; after a
  trust record is added it renders `workspace-write`. Isolates config-load from render default (a
  `-c sandbox_mode=workspace-write` override always flips the render, confirming the render reflects
  the effective `sandbox_mode`).

## tool_input field-name findings (D)

TBD-STILL. No turn-free surface exposes per-tool `tool_input` key names (the model emits tool calls
only during a live turn; `debug prompt-input` renders session context, not tool schemas). The
`<permissions instructions>` block does name escalation params (`sandbox_permissions`, `justification`,
`prefix_rule`) and describes shell command-segment splitting, but these are approval-escalation fields,
not the PreToolUse `tool_input` schema. Consequence per disposition: the PreToolUse edit-scope field
shim degrades to backstop-only (post-Bash diff guard); path-only secret rule + instruction-level rule
remain.

## Trust-flow UX notes (C)

- **Project trust** gates per-project `.codex/config.toml` (and, by the same trusted-project flow,
  `.codex/hooks.json`). Recorded as `[projects."<abs-path>"] trust_level = "trusted"` in
  `$CODEX_HOME/config.toml`. Verified turn-free: untrusted ⇒ project config not merged; trusted ⇒ merged.
- **Hook trust** is a SEPARATE content-hash trust (per docs, via the interactive `/hooks` command);
  a hook whose content changes is skipped until re-trusted. `--dangerously-bypass-hook-trust` exists on
  `exec`/`resume`/`fork` and is DANGEROUS — DMC MUST NOT use it (plan disposition). The interactive UX
  itself was not observed headless.
- **`.agents/skills` discovery and AGENTS.md discovery are NOT trust-gated** — both loaded in the
  untrusted scratch project (filesystem scan + project-doc read), unlike executable project config.

## /import scope (G)

`/import` is an interactive TUI slash-command, NOT a CLI subcommand (no `import` under `codex --help`;
`plugin` has only `add/list/marketplace/remove`). It is associated with the `external_migration`
feature, which is `experimental  false` (disabled by default) at 0.132.0. Its migration scope is not
inspectable headless and MUST NOT be a dependency of the DMC installer, which wires config
programmatically. No real import was run against the user's `~/.claude`.

## Consequences — active dispositions after this spike

The following are now the recorded state for the human gate:

1. **FULL STOP (enforcing-shim build)** for the two load-bearing facts "hooks fire" and "decision
   contracts honored" — both UNPROVABLE-TURN-FREE. The M6.5 enforcement claim for Codex shims
   downgrades to the **documented-manual + pre-commit/CI gate** default; the human gate decides the
   reduced scope (advisory shims + CI/pre-commit enforcement vs deferral). STOP artifact written.
2. **STANDING degradation**: `unified_exec` is stable+on → the non-shell/streaming evasion path is
   live; the **post-Bash diff guard is the PRIMARY Codex safety net** (not a backstop). Carry into the
   A3 machine-checkable "Degraded Invariants (Codex)" assertions at T011b.5.
3. **SCOPED degradation**: PostToolUse-over-unified_exec unproven ⇒ diff guard at Stop + pre-commit gate.
4. **SCOPED degradation**: `tool_input` field names TBD ⇒ PreToolUse edit-scope field shim is
   backstop-only; path-only secret + instruction-level rules remain.
5. **SCOPED (non-load-bearing)**: `.codex`/`.agents` read-only asymmetry not re-proven ⇒ rely on the
   scope guard over those paths as on Claude; no stop.
6. **VIABLE (no degradation)**: skills `.agents/skills` bindings (T011b.3), the trusted-project
   `.codex/config.toml` wiring template, and the AGENTS.md generator (T011b.4) — AGENTS.md discovery +
   the 32 KiB `project_doc_max_bytes` cap are confirmed, so the generator must fit/trim the DMC section
   to ≤32 KiB (answers the size-budget open question).

## Appendix — exact commands + observed outputs

Isolation for all probes: `export CODEX_HOME=<scratchpad>/codexhome`; scratch git project at
`<scratchpad>/proj` with `.codex/hooks.json` (SessionStart/UserPromptSubmit/PreToolUse `touch` marker
hooks), `.codex/config.toml` (`sandbox_mode=workspace-write`, `approval_policy=never`),
`.agents/skills/test-skill/SKILL.md`, and `AGENTS.md`.

### A. Surface inventory
- `codex --version` → `codex-cli 0.132.0`.
- `codex --help` → subcommands: exec, review, login, logout, mcp, plugin, mcp-server, app-server,
  remote-control, app, completion, update, doctor, sandbox, debug, apply, resume, fork, cloud,
  exec-server, features, help. Global `--dangerously-bypass-hook-trust`; `-s/--sandbox
  [read-only|workspace-write|danger-full-access]`. No top-level `hooks` subcommand.
- `codex exec --help` → `--json`, `--output-schema <FILE>`, `-o/--output-last-message <FILE>`,
  `--ephemeral`, `--ignore-user-config`, `--ignore-rules`, `--skip-git-repo-check`,
  `--dangerously-bypass-hook-trust`; subcommands `resume`, `review`.
- `codex debug --help` → `models`, `app-server`, `prompt-input` only.
- `codex features list` → `hooks stable true`, `plugin_hooks stable true`, `plugins stable true`,
  `multi_agent stable true`, `unified_exec stable true`, `external_migration experimental false`,
  `guardian_approval stable true`.

### B. Turn-free firing probe (p1) — verbatim
```
$ codex exec --json "trigger a tool now"       # CODEX_HOME=scratch, trusted project, no auth
{"type":"thread.started","thread_id":"019f3804-..."}
{"type":"turn.started"}
ERROR codex_api::endpoint::responses_websocket: failed to connect to websocket: HTTP error: 401 Unauthorized, url: wss://api.openai.com/v1/responses
... (5x wss retries, then 5x https retries) ...
{"type":"turn.failed","error":{"message":"unexpected status 401 Unauthorized: Missing bearer or basic authentication in header, url: https://api.openai.com/v1/responses ..."}}
$ ls .codex/marks/        # markers directory EMPTY — no hook fired
```

### C. AGENTS.md + skills discovery (p-render) — `codex debug prompt-input "hello spike probe"`
Rendered (exit 0, no network): a `developer` `<skills_instructions>` block listing built-in skills
(from `$CODEX_HOME/skills/.system/...`) AND `test-skill` with path
`.../proj/.agents/skills/test-skill/SKILL.md`; a `user` message `# AGENTS.md instructions for
.../proj` wrapping the scratch `AGENTS.md` in `<INSTRUCTIONS>...</INSTRUCTIONS>`; an
`<environment_context>` (cwd/shell/date/timezone).

### D. Trusted-project merge (p-config)
```
untrusted:            sandbox_mode` is `read-only`      (project .codex/config.toml NOT loaded)
-c sandbox_mode=workspace-write:  ... `workspace-write` (render reflects effective mode)
after adding [projects."<path>"] trust_level="trusted": ... `workspace-write` (project config loaded)
```

### E. AGENTS.md size cap (F)
```
AGENTS.md bytes: 40431 → injected block length: 32936 chars; contains END_MARKER_AT_40K: False
-c project_doc_max_bytes=2000 → injected block length: 2168 chars
```

### CLI-initiated network (recorded per constraint 2)
- `codex exec` opens `wss://api.openai.com/v1/responses` at `turn.started` (401 without auth; no model
  turn occurred). Retries then `turn.failed` on its own (~15s); not killed as it self-terminated.
- `codex doctor --json --summary` runs a reachability probe `GET https://chatgpt.com/backend-api/`
  (HTTP 404) — a health check, not a model turn; no auth used. Run once; not repeated.
No credentials were supplied to any of these; no secret content was read or emitted.
