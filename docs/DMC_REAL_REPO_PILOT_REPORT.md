# Do-Me-Coding v0.1.2 — Real-Repo Pilot Report

Date: 2026-06-19
Run ID: dmc-v0.1.2-pilot
Plan: `.harness/plans/dmc-v0.1.2-real-repo-pilot-gap-ledger.md` (APPROVED 2026-06-19)
Companion: `docs/COMPETITIVE_GAP_LEDGER.md`

## Pilot repo identity
- **Repo:** pokeprice — `/Users/woojinlee/Documents/projects/pokeprice`
- **Remote:** `https://github.com/wjlee930501/pokeprice.git`
- **Risk class:** low-risk / non-production
- **Stack:** Node/TypeScript (vite, vitest, drizzle, pnpm); `api/`, `client/`, `server/`, `services/`, `shared/`
- **Pre-existing harnesses:** `.omc/`, `.omo/`, `.omx/` present; `.claude/`, `CLAUDE.md`, `AGENTS.md` absent; user-scope `~/.codex` present.

## Branch & commit checkpoints
- Base: `main` @ `5ea18b0` (clean)
- Pilot branch: **`dmc-pilot/v0.1.2`** (local only — NOT pushed)
- Phase 2A install checkpoint: **`2f52c35` chore(dmc): install pilot harness in passive mode** (35 files, +1444)
- pokeprice modifications confined to this branch; fully reversible.

## Phase 1 — Compatibility audit (read-only) — PASS
- pokeprice on `main`, clean; additive install (no Claude config/doc collision).
- OMC/OMO/OMX present → coexistence exercisable. `vitest run` available for verification. README/DEPLOY/docs targets available.
- Secrets inventoried by filename only: `.env.example` (tracked), `.env.local`, `.env.prod.local` (untracked, gitignored). No contents read.
- Ignore-rule gap noted: pokeprice `.gitignore` lacked `.harness/*` transient rules.

## Phase 2A — Install/adapt (passive) — PASS
- Created `dmc-pilot/v0.1.2`; installed `.claude/{hooks×5, skills×9, agents×5, settings.json}`, `.harness/` skeleton + schemas, `.harness/mode=passive`, `DMC.md`, root schemas, `CLAUDE.md`.
- Appended `.harness/{mode, runs/current-*, evidence/manual-*.md}` to pokeprice `.gitignore`.
- `AGENTS.md` deliberately NOT copied (DMC's is repo-specific; would misdescribe pokeprice).
- **Doc-integrity gap found:** installed `DMC.md`/`CLAUDE.md` reference `docs/OMC_COEXISTENCE.md`, which was not installed → dangling reference (ledger #14).
- Sanity: settings.json valid JSON (4 events); `bash -n` all 5 hooks OK; transient state gitignored; `.omc/.omo/.omx` untouched.

## Phase 2B — Three pilot tasks — PASS (all 3)
| Task | Trigger | Result | Artifact |
|---|---|---|---|
| Docs-only | `dmc-plan` | PASS — routed planning-only, zero source edits | pokeprice `.harness/plans/omc-coexistence-doc.md` |
| Low-risk code | `<task> dmc` | PASS — small, reversible, test-verified (no `process.env`/dotenv/config touched) | pokeprice `server/setNames.test.ts`; verif `setnames-test-20260619.md` |
| OMC/OMO coexistence | `dmc-off` | PASS — DMC stood down except catastrophic/security-deny floor; no interference | verif `omc-coexistence-20260619.md` |

## Security guardrail result — HONORED
- No `Read`/`Grep`/`cat`/print/edit of `.env`, `.env.local`, `.env.prod.local`, or any `.env*` contents in any phase.
- `.env.prod.local` (production) treated as completely off-limits; referenced by filename only.
- Confirmed the live limitation: DMC v0.1.1 blocks Bash secret reads but does NOT guard `Read`/`Grep` — safety here came from the explicit operating rule, not tool enforcement (→ v0.1.3).

## Task-by-task verdict
- Phase 1: PASS · Phase 2A: PASS · Phase 2B docs/code/coexistence: PASS · Security guardrail: HONORED.

## Overall verdict

**PASS with follow-up gaps.**

The pilot proves DMC v0.1.1 installs cleanly and additively into a real OMC/OMO repo, activates naturally, enforces scope/verification, coexists via `dmc-off`, and is fully reversible — with **no secret exposure**. Two high-severity gaps and several medium ones were surfaced for v0.1.3/v0.2 (below), so it is not an unqualified PASS.

## Recommended next actions
1. **v0.1.3 — Security/tool-read guard hardening:** extend secret protection beyond Bash to `Read`/`Grep` access of `.env*` (tool-level matcher where Claude Code allows, else policy/instruction-level deny).
2. **v0.1.3 — Install surface / doc integrity fix:** bundle referenced support docs (e.g. `docs/OMC_COEXISTENCE.md`) with the install, or remove dangling references.
3. **v0.1.3 — Host-repo artifact policy:** define which `.harness/{plans,evidence,verification}` artifacts are committed vs local-only when DMC is installed into a host repo.
4. **v0.2 — Worker Bridge contract:** design multi-model / worker delegation only after v0.1.3 hardening lands (keep GLM/worker execution deferred until then).

## Rollback (pilot is non-destructive)
- pokeprice: `git -C pokeprice checkout main && git -C pokeprice branch -D dmc-pilot/v0.1.2` (or `git revert 2f52c35`). Branch never pushed.
- DMC repo: only these two docs (+ run artifacts) added; no product source changed.
