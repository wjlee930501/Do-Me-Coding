# DMC Codex Adapter — Design (Ring-1 binding, host mode)

How DMC binds to the **Codex CLI as a host harness** — the second first-class adapter beside
Claude Code. This is a Ring-1 design (`docs/DMC_V1_RUNTIME_ARCHITECTURE.md` §0.1, three-ring
model): the adapter is a thin translation layer that turns Codex hook events into calls to the
**same Ring-0 verdict CLIs** (`bin/dmc`) the Claude adapter already uses. No enforcement logic
lives in the adapter. "Codex as HOST" (this doc) is strictly separate from "Codex as WORKER"
(the worker bridge — proposal-only, unchanged; `DMC.md` §Worker Bridge).

This is architecture guidance for the gated M6.5 milestone, not an implementation and not an
enforcement surface. Nothing here is built until the M6.5 plan clears its own critic + human gate.

> **Facts verified 2026-07-06 against official docs (developers.openai.com/codex, raw-HTML
> checked); Codex evolves fast — EVERY fact below must be re-proven by the M6.5 local-CLI spike
> before any build. Architecture guidance, not enforcement.**

Confidence legend: **VERIFIED-OFFICIAL** (in the 2026-07-06 official docs) · **SECONDARY**
(dated/replaceable, lower confidence) · **UNVERIFIED-ASSUMPTION** (to be proven at the spike).

---

## 1. Verified Codex CLI surface (facts)

| Fact | Source | Confidence |
|---|---|---|
| **AGENTS.md** is read at session start. Discovery: global `~/.codex/AGENTS.md` (plus `AGENTS.override.md`), then a Git-root→cwd walk taking one file per directory, concatenated root-down (closer-to-cwd files appended later, so they win on conflict). Size cap `project_doc_max_bytes`, default 32 KiB. Aligns with the community `agents.md` standard. | developers.openai.com/codex/guides/agents-md | VERIFIED-OFFICIAL |
| **config.toml** (`~/.codex/config.toml`, TOML): `model`, `approval_policy` (`untrusted`\|`on-request`\|`never`\|`granular`), `sandbox_mode` (`read-only`\|`workspace-write`\|`danger-full-access`), `[features]` flags (incl. hooks, `multi_agent`) `[SPIKE-CORRECTED 2026-07-06: at codex-cli 0.132.0 both `hooks` and `multi_agent` are `stable` and enabled by DEFAULT (features list) — not experimental/gated]`, `[agents.<name>]` subagent defs, `[[skills.config]]`. Per-project `<repo>/.codex/config.toml` is loaded **only for TRUSTED projects** `[SPIKE-CONFIRMED 2026-07-06 turn-free: untrusted ⇒ project config not merged; trust record `[projects."<path>"] trust_level="trusted"` in `$CODEX_HOME/config.toml` ⇒ merged]`. A managed `requirements.toml` can pin values org-wide. | developers.openai.com/codex/config-reference | VERIFIED-OFFICIAL |
| **Lifecycle hooks** — events: `SessionStart`, `SubagentStart`, `PreToolUse`, `PermissionRequest`, `PostToolUse`, `PreCompact`, `PostCompact`, `UserPromptSubmit`, `SubagentStop`, `Stop`. Configurable via `~/.codex/hooks.json`, `~/.codex/config.toml [hooks]`, `<repo>/.codex/hooks.json`, `<repo>/.codex/config.toml` — the layers **merge** (they do not override). Payload is JSON on stdin: `session_id`, `transcript_path`, `cwd`, `hook_event_name`, `model`, `turn_id`, `permission_mode`. `[SPIKE-2026-07-06: config surface present and the `hooks` feature is `stable`+on, BUT hook FIRING was UNPROVABLE-TURN-FREE — offline `codex exec` reaches the model websocket before any enforcement-hook side-effect and no headless emit/replay surface exists; see §Spike addendum + spike-stop.md]` | developers.openai.com/codex/hooks | VERIFIED-OFFICIAL (firing UNPROVABLE-TURN-FREE) |
| **Hook decision contracts** — `PreToolUse` denies via `hookSpecificOutput.permissionDecision=deny`, or exit 2 + stderr, or `allow` with an `updatedInput` rewrite of the tool arguments. `PermissionRequest` can allow/deny **before** the approval prompt is shown (deny wins). `PostToolUse` can block or replace the tool result but **cannot undo** an effect already applied. `Stop` / `SubagentStop` can force continuation (`decision:"block"` + `reason` injects a synthetic user turn). `[SPIKE-2026-07-06: decision-envelope honoring is UNPROVABLE-TURN-FREE (requires a live model tool-call/turn-end); see §Spike addendum + spike-stop.md]` | developers.openai.com/codex/hooks | VERIFIED-OFFICIAL (honoring UNPROVABLE-TURN-FREE) |
| **Hook enforcement honesty** — OpenAI's own docs describe `PreToolUse` as "a guardrail rather than a complete enforcement boundary": `unified_exec` streaming shells and non-shell / non-MCP tool paths can evade interception. Hooks are a guardrail, not an airtight boundary. | developers.openai.com/codex/hooks | VERIFIED-OFFICIAL |
| **Hook trust** — non-managed hooks require explicit `/hooks` content-hash trust; a hook whose content changes is skipped until re-trusted. Managed (org) hooks are exempt. | developers.openai.com/codex/hooks | VERIFIED-OFFICIAL |
| **Skills** — `.agents/skills/<name>/SKILL.md` (YAML `name`/`description`). Scan order: `$CWD/.agents/skills` → parent dirs → repo root → `~/.agents/skills` → `/etc/codex/skills` → built-in. Progressive disclosure; explicit (`$skill`, `/skills`) or implicit invocation; `[[skills.config]]` enables/disables. Custom prompts `~/.codex/prompts/*.md` are **DEPRECATED** (do not target). Plugins (`.codex-plugin/plugin.json`) can bundle skills + hooks; plugin hooks receive `PLUGIN_ROOT` and (compat) `CLAUDE_PLUGIN_ROOT` env vars; an `/import` command migrates Claude Code configs. | developers.openai.com/codex/skills | VERIFIED-OFFICIAL |
| **Subagents** — real but **explicit-only**: per OpenAI, "Codex doesn't spawn subagents automatically." Defined by `[agents.<name>]` with `config_file`/`description`; `max_threads` default 6, `max_depth` default 1; gated behind the `multi_agent` feature flag `[SPIKE-CORRECTED 2026-07-06: `multi_agent` is `stable` and enabled by DEFAULT at 0.132.0 (features list) — no opt-in flag needed]`. | developers.openai.com/codex/concepts/subagents | VERIFIED-OFFICIAL |
| **Sandbox** — `read-only` \| `workspace-write` \| `danger-full-access`, enforced OS-natively (Seatbelt / bubblewrap / Windows). Even in `workspace-write`, `<root>/.git`, `<root>/.agents`, and `<root>/.codex` stay read-only. Approval policies as above; `requirements.toml` can forbid `never` / `danger-full-access`. | developers.openai.com/codex/concepts/sandboxing | VERIFIED-OFFICIAL |
| **Rules (experimental)** — `.codex/rules/*.rules` Starlark `prefix_rule` with `allow`\|`prompt`\|`forbidden`, most-restrictive-wins, tree-sitter linear-chain splitting only. Marked **EXPERIMENTAL** by OpenAI. | developers.openai.com/codex/rules | VERIFIED-OFFICIAL (feature EXPERIMENTAL) |
| **codex exec** (non-interactive) — `--json` JSONL event stream, `--output-schema` (JSON-Schema-validated final message), `-o` last-message file, `exec resume`, `--ephemeral`, `--ignore-user-config`, `--ignore-rules`; `CODEX_API_KEY` supplied per-invocation. | developers.openai.com/codex/noninteractive | VERIFIED-OFFICIAL |
| **MCP** — `[mcp_servers.<id>]` supports stdio + streamable HTTP transports, `enabled_tools`/`disabled_tools`, and a `required` flag. | developers.openai.com/codex/config-reference | VERIFIED-OFFICIAL |
| **Model names** (dated, non-load-bearing; MUST NOT appear anywhere in Ring-0 — capability classes only, `orchestration/roles.json`): flagship, a general tier, a mini subagent tier, and a preview codex tier. Month-precision release dates. Recorded once here for the M6.5 spike; replaceable lookup, never a gate input. | developers.openai.com/codex/config-reference | SECONDARY |

**Why the AGENTS.md contract (§5) matters:** Codex's project memory is `AGENTS.md`, discovered and
size-capped as above — unlike Claude's `CLAUDE.md`, it is concatenated across a directory walk and
truncated at `project_doc_max_bytes`. That makes a disciplined, deterministic, `Unknown`-honest
generator (not a blind copy) a hard requirement, not a nicety.

---

## 2. Mechanism mapping (Claude adapter → Codex adapter)

Every DMC Claude mechanism (`.claude/settings.json`) maps to a Codex hook event that calls the
**same Ring-0 verdict CLI**. The shim only translates event JSON → CLI args/stdin → host envelope.

| DMC mechanism (Claude) | Ring-1 Claude shim | Codex binding | Notes |
|---|---|---|---|
| PreToolUse **Bash** write-radius / `git apply`/`patch` deny | `.claude/hooks/pre-tool-guard.sh` | Codex `PreToolUse` | Same JSON deny contract (`permissionDecision=deny` / exit 2 + stderr). |
| PreToolUse **Edit\|Write** scope guard | `.claude/hooks/scope-guard.sh` | Codex `PreToolUse` over Codex's edit tools **+ the M6 post-Bash diff guard as backstop** | Codex hooks are non-airtight, so the post-Bash `git diff` guard is load-bearing on both hosts. |
| PreToolUse **Read\|Grep\|Glob** secret guard | `.claude/hooks/secret-guard.sh` | Codex `PreToolUse` (field-name shim) | Path-only decision preserved; Codex tool-input key names are **TBD at spike**. |
| PostToolUse evidence log | `.claude/hooks/evidence-log.sh` | Codex `PostToolUse` | Feeds the Ring-0 receipt ledger; append-only. |
| UserPromptSubmit natural-activation router | `.claude/hooks/dmc-router.sh` | Codex `UserPromptSubmit` | Suffix-trigger routing (`DMC.md` §Natural Activation) unchanged; Ring-0 owns the logic. |
| Stop / completion gate | `.claude/hooks/stop-verify-gate.sh` | Codex `Stop` (`decision:"block"`) **with pre-commit/CI gate retained as fallback** | Codex *does* have a Stop hook (corrects the stale P20 "no Stop hook" assumption); the CI/pre-commit gate stays as backstop given hook non-airtightness. |
| Skills `/dmc-*` | `.claude/skills/dmc-*/SKILL.md` | `.agents/skills/dmc-*/SKILL.md` | Mirror + drift-check between the two skill surfaces (M3 mirror pattern) so they cannot silently diverge. |
| Subagents (roles `strategic-orchestrator`, `implementer`, `critic-falsifier`, `verifier`, `release-auditor` — `orchestration/roles.json`) | `.claude/agents/*.md` | `[agents.<name>]` + `config_file`, invocation documented in the host `AGENTS.md` | Codex is explicit-only; **no auto-dispatch emulation**. Capability classes, never model names. |
| `.harness/mode` (active\|passive\|off) | read by every Claude shim | read identically by every Codex shim | One mode file, both adapters. |
| `settings.json` permissions | `.claude/settings.json` | `sandbox_mode = workspace-write` + `approval_policy` + (defense-in-depth only) `.codex/rules/*` | `.rules` is advisory backstop, never the primary gate. |

**Invariant:** all shims call the same `bin/dmc` verdict CLIs (`verdict gate`, `verdict validate`,
`validate verification`, `run start`). If the two adapters ever diverge on a decision, that is a
Ring-1 bug, because the decision was made in Ring-0.

### 2.1 Codex lifecycle events NOT bound in v1

Codex exposes more events than DMC currently uses. The table above binds only the six DMC needs
today; the rest are recorded here so the M6.5 spike knows what it is deliberately leaving unbound
(and why), not silently missing.

| Codex event | Possible DMC use | v1 disposition |
|---|---|---|
| `SessionStart` | inject the compact context map + autonomy level (the INTEROP.md SessionStart pattern) | **Deferred** — advisory context only; not a gate. Ring-2 `AGENTS.md` already covers it. |
| `PermissionRequest` | second approval layer before the prompt (deny wins) | **Optional defense-in-depth** — the human-only gate stays Ring-0; PermissionRequest may mirror it, never replace it. |
| `PreCompact` / `PostCompact` | drive P11 context recovery (checkpoints/resume) across a compaction | **Deferred** — candidate for a later milestone; Ring-0 resume already exists via `dmc run resume`. |
| `SubagentStart` / `SubagentStop` | write delegation records for explicit subagents | **Deferred** — only meaningful once `[agents.<name>]` delegation is exercised; explicit-only, no auto-dispatch. |

Binding any of these later is additive Ring-1 wiring over existing Ring-0 CLIs — no new enforcement
authority is created by adding an event.

---

## 3. Degraded-invariant matrix

Same Ring-0 decisions, different host reach. This matrix records where Codex's guarantee is weaker
than Claude Code's and names the backstop that closes the gap, so no invariant degrades silently.

What each host actually guarantees per DMC invariant, and the residual gap + backstop where Codex
is weaker. This feeds the standing P20/M10 enforcement matrix (`dmc doctor` prints per-host which
invariants are runtime-enforced vs advisory).

| DMC invariant | Claude Code guarantee | Codex guarantee | Residual gap + backstop |
|---|---|---|---|
| Scope lock on **edits** | PreToolUse Edit\|Write deny before write | PreToolUse over edit tools; deny before write | Codex tool-input field names unproven → spike must confirm; backstop = post-Bash diff guard. |
| Scope lock on **Bash writes** | Bash write-radius classify + post-Bash diff guard (M6) | PreToolUse Bash, but **explicitly non-airtight** (unified_exec / non-shell paths) | Both hosts require the M6 post-Bash `git diff` guard; on Codex it is the primary safety net, not a backstop. |
| **Secret-path read** deny | secret-guard PreToolUse (path-only) | PreToolUse (path-only), pending field-name shim | Instruction-level rule (`CLAUDE.md`/`AGENTS.md`) remains defense-in-depth on both. |
| **Stop / completion** gate | Stop hook + verification-report validator | Stop hook (`decision:block`) — parity confirmed | Hook non-airtightness → pre-commit/CI release gate retained as fallback on Codex. |
| **Natural activation** | UserPromptSubmit router | UserPromptSubmit — parity | None material; both delegate to Ring-0 router. |
| **Approval gates** | `ask` prompts via settings + human gate | `approval_policy` + `PermissionRequest` hook + human gate | Equivalent; human-only gate is Ring-0, host-independent. |
| **Hook trust** | hooks active once wired in settings.json | non-managed hooks need one-time `/hooks` content-hash trust; changed hooks skipped until re-trusted | Installer must **surface the trust step**, never bypass via `--dangerously-bypass-hook-trust`. |
| **Protected DMC bindings** | `.claude/**` editable by agent unless scope-guarded | `<root>/.codex`, `<root>/.agents`, `<root>/.git` are **read-only to the agent** even in workspace-write | Helpful asymmetry: on Codex the agent cannot self-edit its own DMC bindings at runtime. |

---

## 4. Non-goals (v1)

- **`.codex/rules` / execpolicy is NOT load-bearing.** It is EXPERIMENTAL per OpenAI; DMC treats
  it as defense-in-depth only, never the primary gate.
- **`requirements.toml` is NOT a dependency.** It is enterprise/org-managed. Documented only as
  the single non-bypassable layer available to an org that wants one — DMC never requires it.
- **No subagent auto-dispatch emulation.** Codex is explicit-only; the adapter documents explicit
  invocation in the host `AGENTS.md` and does not fake automatic spawning.
- **No model-name hardcoding in Ring-0.** Capability classes only (`orchestration/roles.json`);
  the dated model row in §1 is a lookup, never a gate input.
- **No deprecated `~/.codex/prompts`.** Skills target `.agents/skills/` only.
- **"Codex as HOST" ≠ "Codex as WORKER".** This doc is host-adapter design; the worker bridge
  (proposal-only, no mutation, `DMC.md` §Worker Bridge) is untouched and unconflated.
- **No OpenCode work.** OpenCode remains a Ring-1 stub (`docs/DMC_V1_RUNTIME_ARCHITECTURE.md` §0.1).

---

## 5. Host AGENTS.md content contract (draft v1)

When DMC installs into a Codex host repo, the generator (M6.5 binding; deterministic inputs from
`dmc orient` / `dmc landmarks` where possible) emits a host `AGENTS.md` with the REQUIRED sections
below. Merge policy per `docs/HOST_REPO_ADAPTATION_POLICY.md`: **never blind-copy DMC's own
`AGENTS.md`**; if the host already has one, preserve it and offer to extend, never overwrite.

**The Unknown rule (non-negotiable):** every fact not derivable from the repo is written literally
as `Unknown`. Business logic, commands, and risk notes are **never invented** — an honest
`Unknown` is required, a plausible guess is forbidden.

REQUIRED sections:

1. **Repo identity** — name + one-line purpose. (`dmc orient`)
2. **Stack + package manager** — languages, frameworks, the detected package manager. (`dmc orient`)
3. **Lint / typecheck / test / build commands** — the exact commands, or `Unknown` each.
4. **Architecture landmarks** — key modules / entry points. (`dmc landmarks`)
5. **Protected surfaces** — paths the agent must not edit (secrets, generated, vendored).
6. **Migration / env / auth / billing risk notes** — or `Unknown` per category.
7. **DMC operating rules** — the core loop, the non-negotiable rules (`DMC.md`), and how to invoke
   DMC verbs/skills on **this host** (Codex skill + subagent invocation, explicit).
8. **Verification commands** — the commands a Verifier runs to prove completion, or `Unknown`.
9. **Stop conditions** — when the agent must halt and hand back to the human gate.
10. **Explicit Unknowns list** — every field left `Unknown`, collected in one place for follow-up.

The generator must be deterministic where its inputs are deterministic (repo-derived facts), and
must degrade to `Unknown` — never to a guess — where they are not.

---

## Open questions for the M6.5 spike

- **Tool-input field names** — the exact stdin key names Codex uses per tool (edit path, read
  path, bash command) so the scope/secret shims read the right field. Unproven; blocks the field
  shims.
- **`/import` migration scope** — what a Claude Code → Codex `/import` actually carries over
  (hooks? skills? settings?), and whether it helps or conflicts with the DMC installer.
- **Hook trust UX in fresh clones** — how the one-time `/hooks` content-hash trust presents on a
  fresh host clone, and how the installer surfaces it without ever bypassing it.
- **Whether `PostToolUse` fires for `unified_exec`** — if the evidence/diff guards see streaming
  shell tool calls at all, or if those are exactly the paths that evade interception.
- **AGENTS.md size budget** — how generated DMC operating rules interact with
  `project_doc_max_bytes` (default 32 KiB) once host facts are added, and whether the DMC section
  must be trimmed or externalized.

---

## Spike addendum — local CLI re-proof (codex-cli 0.132.0, 2026-07-06)

Recorded from DMC-T011b.1 (run dmc-run-8fef31d58eee); full evidence + verbatim command outputs in
`.harness/evidence/dmc-v1-m6.5-spike-findings.md`, and the STOP decision in
`.harness/evidence/dmc-v1-m6.5-spike-stop.md`. **No live model turn was taken; no API key was read
or required.** Every verdict below is backed by an observed local behavior on an isolated scratch
`CODEX_HOME` + scratch project (never the user's `~/.codex`).

**Headline (B, load-bearing):** hook FIRING and deny/allow/block ENVELOPE HONORING are
**UNPROVABLE-TURN-FREE** — a live authenticated model turn is the only path to prove either. Offline
`codex exec` goes `thread.started` → `turn.started` → immediate websocket to `api.openai.com` (401,
no auth) → `turn.failed`, with **no hook markers fired**; the enforcement-critical events
(PreToolUse/PostToolUse/Stop) fire around a model tool-call/turn-end; and the CLI exposes **no headless
hook emit/replay/dry-run surface** (only `--dangerously-bypass-hook-trust`, which DMC must not use).
This triggered the plan's B4 STOP → human gate.

**CONFIRMED turn-free:**
- **AGENTS.md discovery + 32 KiB cap** — `debug prompt-input` injects the project `AGENTS.md` under a
  `# AGENTS.md instructions for <path>` / `<INSTRUCTIONS>` wrapper; a 40431-byte file truncates to a
  32936-char block (`END_MARKER` dropped), and `-c project_doc_max_bytes=2000` shrinks it to 2168
  chars. ⇒ the generator MUST keep the DMC section within `project_doc_max_bytes` (default 32 KiB) —
  answers the size-budget open question.
- **Skills `.agents/skills/<name>/SKILL.md` discovery** — the scratch `test-skill` appears in the
  rendered `<skills_instructions>` block with its `.agents/skills/...` path (progressive disclosure:
  name + description + path). Not trust-gated.
- **Trusted-project `.codex/config.toml` merge** — untrusted ⇒ project config not loaded; trust record
  `[projects."<abs-path>"] trust_level="trusted"` in `$CODEX_HOME/config.toml` ⇒ loaded.
- **Sandbox modes** (`read-only|workspace-write|danger-full-access`) and **`codex exec` flags**
  (`--json`, `--output-schema`, `-o`, `--ephemeral`, `--ignore-user-config`, `--ignore-rules`,
  `--skip-git-repo-check`, `exec resume`).
- **Feature stages** (`features list`): `hooks stable true`, `plugin_hooks stable true`,
  `plugins stable true`, `multi_agent stable true`, `unified_exec stable true`,
  `external_migration experimental false`.

**Corrections (tagged inline in §1):** `hooks` and `multi_agent` are `stable` + enabled by default at
0.132.0 (not experimental/gated); a `permissions.profiles`/`default_permissions` sandbox model exists
(`codex sandbox` requires a named `--permissions-profile`), a refinement beyond the `.codex/rules`
framing.

**Open-question dispositions:**
- **Tool-input field names** — TBD-STILL (no turn-free tool-schema dump) ⇒ PreToolUse edit-scope field
  shim degrades to backstop-only (post-Bash diff guard); path-only secret + instruction rules remain.
- **`/import` scope** — interactive TUI-only slash command (no CLI subcommand), tied to
  `external_migration` (experimental, off) ⇒ MUST NOT be a DMC installer dependency.
- **Hook trust UX in fresh clones** — mechanism confirmed (content-hash; `--dangerously-bypass-hook-trust`
  exists) but the interactive `/hooks` UX is TUI-only, not observed headless ⇒ document the manual
  trust step; never bypass.
- **PostToolUse over `unified_exec`** — UNPROVABLE-TURN-FREE; `unified_exec` is `stable`+on, so the
  evasion path is live ⇒ the post-Bash diff guard is the PRIMARY Codex safety net (carry into the
  T011b.5 machine-checkable "Degraded Invariants (Codex)" assertions).

**Not re-proven (non-load-bearing):** the `<root>/.codex`,`.agents` read-only asymmetry — `codex
sandbox macos` requires a `--permissions-profile` whose 0.132 schema was not mapped in-timebox; scoped
degradation stands (rely on the scope guard over those paths), no stop.
