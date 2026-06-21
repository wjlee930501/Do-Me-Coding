# DMC Interop — Claude Code & LazyCodex (v0.4.8)

How the DMC autonomous control plane maps onto **Claude Code** hooks/subagents/plugins and **LazyCodex/OmO-style**
workflows. These are **interoperability targets, not runtime dependencies** — DMC's guards are plain shell/`python3` and
run standalone; nothing here requires LazyCodex or any plugin to be installed.

## Suggested hook points (Claude Code `.claude/settings.json` wiring)

Each maps a Claude Code hook event to an existing DMC guard. Wiring is **opt-in**; the guards also run by hand
(`--self-test` / direct invocation). DMC guards are advisory/read-only and **grant no gate**.

| hook event | DMC guard / artifact | purpose |
|---|---|---|
| **SessionStart** (context injection) | `docs/CONTEXT_MAP.md` + `AGENTS.md` + `AUTONOMY.md` | inject the compact context map + autonomy level; no instruction duplication |
| **PreToolUse** (secret/network guard) | `dmc-v0.4.5-secret-network-live-guard.sh` + `.claude/hooks/secret-guard.sh` / `pre-tool-guard.sh` | fail-closed block of secret reads / live calls / network before a tool runs |
| **PostToolUse / post-edit** (diff guard) | `dmc-v0.4.3-scope-overeager-guard.sh` | classify the edit diff ALLOWED/SUSPICIOUS/BLOCKED against the approved scope + over-eager bounds |
| **PreCommit** (evidence generation) | `dmc-v0.4.4-evidence-harness.sh` | extract + redact self-test counts/commands/summary into an evidence artifact |
| **Stop / final report** | DMC final-report format (`DMC.md` §Evidence Policy) + `dmc-v0.4.6-reviewer-loop.sh` | emit the self-review + the Codex/Kim handoff; never auto-apply reviewer output |

Pre-run, the **`dmc-v0.4.2-branch-isolation-guard.sh`** confirms a dedicated branch + clean worktree, and the
**`dmc-v0.4.1-goal-plan-compiler.sh`** compiles the goal into a run-plan with the autonomy level + human gates.

## LazyCodex / OmO-style workflow mapping (inspiration, not a clone)

| LazyCodex-style concern | DMC equivalent (already in-repo) |
|---|---|
| project memory | `AGENTS.md` + `.harness/memory/` + `docs/CONTEXT_MAP.md` |
| planning | `dmc-v0.4.1-goal-plan-compiler.sh` → `.harness/plans/` (`/dmc-plan-hard`) |
| execution (scoped) | `/dmc-start-work` approved scope under `.harness/runs/` |
| hooks | `.claude/hooks/*` + the v0.4 guards |
| diagnostics / evidence | `dmc-v0.4.4-evidence-harness.sh` + `.harness/evidence/` + `.harness/verification/` |
| verified completion | `dmc-v0.3.7-closure-controller.sh` (5 closure conditions; append-only candidate) |
| reviewer loop | `dmc-v0.4.6-reviewer-loop.sh` + `docs/REVIEW_HANDOFF_TEMPLATE.md` |

## Claude Code subagents / plugins

DMC's existing subagents (`planner`, `explorer`, `executor`, `verifier`, `critic` — `.claude/agents/`) and skills
(`.claude/skills/`) are the orchestration surface. A plugin packaging is possible but **not required**; the control plane
is file-based and host-agnostic (see `INSTALL_MANIFEST.md`).

## No-runtime-dependency contract

- DMC does **not** import, call, or require LazyCodex/OmO at runtime.
- The hook wiring is **suggested**; absent it, every guard still runs standalone.
- Provenance: external harness ideas are **unverified design signals only** (`DMC.md` Rule 7 — no copied prompt text).
