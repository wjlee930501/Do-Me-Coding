# Do-Me-Coding — Competitive Gap Ledger (v0.1.2 pilot)

Source: real-repo pilot of DMC v0.1.1 in **pokeprice** (`dmc-pilot/v0.1.2`), 2026-06-19.
Each row records a concrete pilot observation, a competitive comparison, a severity, and a
next-version candidate. Comparison cells are marked **[observed]** (seen in this pilot),
**[from-docs]** (general knowledge, not exercised here), or **[unknown]**. No competitor behavior
is fabricated; OMC/OMO were present in pokeprice and were exercised, LazyCodex/OpenCode/Codex were
not installed in the pilot repo.

| # | Category | DMC v0.1.1 — pilot observation | Competitive comparison | Severity | Next-version candidate |
|---|---|---|---|---|---|
| 1 | **Activation UX** | Natural triggers (`<task> dmc`, `dmc-plan`, `dmc-off`) + explicit `/dmc-on|off|status`. Suffix-only/exact matching avoids accidental fire. | LazyCodex `ulw` suffix-style activation [from-docs]; OMC magic-keyword UserPromptSubmit injection [observed in DMC sessions]. DMC parity on ergonomics. | low | — |
| 2 | **State management** | `.harness/mode` (gitignored) + run state (`current-*`) drove passive install cleanly. Open question: which `.harness/{plans,evidence,verification}` artifacts belong committed vs local-only in a *host* repo (Finding 8). | OMC centralizes under `.omc/state` (gitignored) [observed]; OMO under `.omo/` [observed]. DMC mixes durable (plans/verification) + transient (mode/runs) — host-repo policy unclear. | med | v0.1.3 host-repo artifact policy |
| 3 | **Plan quality** | Plan→critic loop produced decision-complete plans; the docs-plan artifact `omc-coexistence-doc.md` routed planning-only with zero edits. | Stronger explicit critic gating than OMC autopilot [from-docs]; comparable to Codex plan-first [from-docs]. | low | — |
| 4 | **Execution control** | Passive install was **clean and additive** (Finding 1); `<task> dmc` moved DMC active on request; scope lock + verification enforced on the code task. | OMC ralph/ultrawork loop-driven [observed]; DMC's gate-driven control is more conservative. | low | — |
| 5 | **Scope control** | DMC scope-guard (in the DMC session) correctly blocked Write/Edit to out-of-scope paths; install into pokeprice required Bash `cp` (not editor tools) — a friction point. | Tighter than OMC (no hard file-scope lock observed) [observed]. | med | doc the cp-install workaround / installer |
| 6 | **Stop/verification behavior** | Stop gate blocked a completion-sounding pause until a verification report existed; forced honest PARTIAL. | Stronger "no verification, no done" enforcement than OMC stop hooks [observed]. | low | — |
| 7 | **Evidence quality** | Phase 1/2A evidence + per-task verification (`setnames-test-*`, `omc-coexistence-*`) captured commands + results. | More structured than OMO `ulw-loop` logs [observed]; comparable to Codex [from-docs]. | low | — |
| 8 | **Rollback** | Throwaway branch `dmc-pilot/v0.1.2` (never main, not pushed); install fully reversible via branch delete / `git revert 2f52c35`. | Branch-isolation discipline stronger than ambient OMC/OMO state [observed]. | low | — |
| 9 | **OMC/OMO coexistence** | `.omc/`+`.omo/`+`.omx/` present (Finding 3) → coexistence meaningfully exercisable. `dmc-off` probe showed DMC **stands down except the catastrophic/security-deny floor** (Finding 7). No project-level hook collision (host had no `.claude/settings.json`). | OMC/OMO have no universal off switch [observed]; DMC steps aside via `.harness/mode` rather than disabling them. | low | — |
| 10 | **Multi-model readiness** | Not exercised. DMC is single-agent (Claude) today; no model routing. | LazyCodex/OMO multi-model [from-docs]. Defer (Finding 9). | med | v0.2 (after v0.1.3 hardening) |
| 11 | **Worker delegation readiness** | Not exercised; no worker execution in v0.1.x by design. | OMC teams/ultrapilot delegate workers [observed/from-docs]. Defer (Finding 9). | med | v0.2 Worker Bridge contract |
| 12 | **Security/secrets posture** | DMC v0.1.1 **blocks Bash-based secret reads** (`cat .env`, `printenv`) — confirmed live (the guard blocked our own commands) — but **does NOT block the `Read`/`Grep` tools against `.env*`** (Finding 4; matcher is `Bash`/`Edit`/`Write` only). `.env.prod.local` present and treated **off-limits**; **no secret content accessed** (Finding 5). Pilot relied on an explicit operating rule, not tool-level enforcement. | OMC/OMO have no comparable secret deny observed [observed]; DMC ahead on Bash, but Read/Grep gap is a real hole. | **high** | **v0.1.3 Read/Grep `.env*` guard hardening** |
| 13 | **Developer friction** | Friction points: (a) install is manual `cp`+merge (no installer); (b) editor-tool scope-guard forces Bash-based host install; (c) host-repo artifact policy ambiguity. Otherwise low. | Lower-ceremony than OMC for quick tasks [observed]; DMC trades ceremony for guarantees. | med | installer + docs |
| 14 | **Install surface / documentation integrity** | `.claude/`, `CLAUDE.md`, `AGENTS.md` were **absent** in pokeprice → low merge-collision risk (Finding 2). BUT installed `DMC.md`/`CLAUDE.md` **reference `docs/OMC_COEXISTENCE.md`, which was NOT installed** into pokeprice (Finding 6) — dangling reference. AGENTS.md correctly skipped (repo-specific). | N/A | **high** | **v0.1.3 install-surface/doc-integrity fix** (bundle referenced support docs) |

## Headline gaps (for v0.1.3 / v0.2)

- **[high] Security/secrets:** secret deny is Bash-only; `Read`/`Grep` of `.env*` is unguarded → v0.1.3 tool-read hardening (or policy/instruction-level deny if tool-level enforcement is unavailable).
- **[high] Install-surface/doc integrity:** install references support docs (`docs/OMC_COEXISTENCE.md`) it does not bundle → v0.1.3 fix (ship referenced docs or remove dangling references).
- **[med] Host-repo artifact policy:** decide which `.harness/{plans,evidence,verification}` artifacts are committed vs local-only in host repos → v0.1.3.
- **[med] Multi-model / worker delegation:** keep deferred until v0.1.3 hardening lands; v0.2 Worker Bridge contract afterward (Finding 9).
- **[med] Developer friction:** no installer; scope-guard forces Bash-based host install — document/automate.
