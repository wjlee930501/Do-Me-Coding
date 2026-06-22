# CONTEXT_BUDGET.md — DMC Context Budgeting Policy (v0.5.1)

Make context loading intentional. For a given goal, load the **smallest sufficient** context — not every doc. This policy
plus `.harness/evidence/dmc-v0.5.1-context-budgeter.sh` classify candidate context files into tiers and warn when a run's
context weight exceeds budget. Advisory only; **inert unless invoked**; reads no secrets and no `.env`.

## Tiers
- **required** — must be loaded (carries the rules/scope the run cannot proceed safely without).
- **useful** — load if budget allows (improves quality; not strictly required).
- **optional** — load only on demand (related but usually unnecessary).
- **forbidden** — NEVER loaded (secret-bearing: `.env*` except templates, keys, credentials, tokens). Requesting one in
  `--touched` is **REFUSED** (non-zero exit).
- **excluded** — deliberately left out, each with a stated reason (stale history / long prose / duplicate instruction).

## Rules
- `DMC.md` (operating guide + non-negotiable secret/safety rules) is **required for every goal**.
- `AUTONOMY.md` (levels + stop conditions) is **required** for guard / security / provider work; optional otherwise.
- Prefer the single-source **`docs/CONTEXT_MAP.md` pointer index** over loading every doc; treat `AGENTS.md` project-memory
  as a pointer, not a second copy of the rules — **avoid duplicate instructions** across `AGENTS.md` / `DMC.md` /
  `AUTONOMY.md` (load `DMC.md` once; do not also load the others purely to re-read the same rules).
- **Avoid stale milestone history**: `docs/MILESTONES.md` is required only for a docs-closure goal (you append to it), or
  useful when an explicit `--milestone-range` is requested; otherwise excluded.
- **Schemas and evidence scripts before long prose**: load the relevant `.harness/schemas/*.schema.md` and
  `.harness/evidence/*.sh` (compact, executable, self-testing) before long prose docs (e.g. `docs/INTEROP.md`).
- **Never** include `.env*`, credentials, tokens, keys, or any secret file — the budgeter classifies them forbidden and
  never reads their contents (weight is computed only for non-forbidden files). Forbidden classification is
  **path-derived** (mirrors the secret-name patterns), so a mislabeled `--map` category cannot route a secret file into
  the loaded (required/useful) set.

## Weight & budget
Context weight = total line count of the **loaded** set (required + useful). The default budget is 800 lines (override with
`--budget N`). Exceeding it is **reported loudly** — a `## WARNING: context budget exceeded` line plus a distinct exit
code (3) — never silently ignored.

## Inputs / outputs (tool)
`--goal-type <type> --touched <p[,p...]> --milestone-range <range> --mode <mode> [--map <repo-map.json>] [--budget N]`
emits a markdown report: the four loaded/excluded tiers (each file + line weight), the estimated context weight, and the
budget/overflow status. With no `--map`, a built-in catalog of the repo's key context files is used (line weights via
`wc -l`, skipping forbidden files). Goal types: `docs-closure`, `schema-additive`, `guard-hardening`, `security`,
`provider-change`, `capstone-safety`, `generic`.
