# dmc.agents-md.v1 — Host AGENTS.md content contract (P21, M6.5)

The content contract a generated (or hand-authored) host `AGENTS.md` must satisfy to be a valid
DMC project-memory document for a Codex host. Emitted by `dmc agents-md` (the generator that
`docs/HOST_REPO_ADAPTATION_POLICY.md` calls `/dmc-init-deep` — one generator, skill -> verb
layering) and enforced by `dmc agents-md --validate FILE`. Additive; advisory; **input-only**;
**fail-closed** (VALID => exit 0, REFUSED => exit 3). Design authority: `docs/CODEX_ADAPTER.md` §5.

This is a native `.harness/schemas/` schema (like `scope-lock.schema.md`), not a mirror of a
canonical `*_SCHEMA.md` root; it is not part of the `dmc validate schemas-mirror` plan/run/
verification mirror set.

## Required sections (all ten, in order)

Each section is a level-2 heading of the exact form `## N. Title` with N and Title as below, and a
**non-empty** body. The generator emits repo-derived facts where derivable and the literal token
`Unknown` where not; DMC-constant doctrine (sections 7 and 9) is emitted verbatim because it
originates in DMC, not the host.

```text
# AGENTS.md — <repo name>

<one-line generator provenance note>

## 1. Repo identity
- Name: <derived>            (repo directory name)
- Purpose: <derived|Unknown> (one-line purpose; not repo-derivable => Unknown)

## 2. Stack and package manager
- Languages: <derived|Unknown>
- Package manager: <derived|Unknown>
- Frameworks: <derived|Unknown>

## 3. Lint / typecheck / test / build commands
- Lint: <derived command|Unknown>
- Typecheck: <derived command|Unknown>
- Test: <derived command|Unknown>
- Build: <derived command|Unknown>
- Other detected commands (uncategorized): <list>   (optional; only if present)

## 4. Architecture landmarks
- <path> — <class> (<reason>)   (one per landmark) | Unknown

## 5. Protected surfaces
- the universal DMC secret-file set (always present; a repo constant, never Unknown)
- version-control internals; DMC enforcement bindings
- repository enforcement/contract/release landmarks (optional; only if detected)

## 6. Migration / env / auth / billing risk notes
- Migration / Env / Auth / Billing: <Unknown per category> (risk judgment, never invented)

## 7. DMC operating rules
- the core loop; the four non-negotiable rules; host-specific EXPLICIT skill + subagent
  invocation (Codex is explicit-only). DMC-constant; never Unknown.

## 8. Verification commands
- Host build/test verification: <derived|Unknown>
- the DMC completion gate (always applies). Never fully Unknown.

## 9. Stop conditions
- when to halt and hand back to the human release gate. DMC-constant; never Unknown.

## 10. Explicit Unknowns
- every field left Unknown, aggregated here for follow-up | a "none — all derivable" line
```

## The Unknown rule (non-negotiable)

Every fact not derivable from the repository is written literally as `Unknown`. Business logic,
commands, and risk notes are **never invented** — an honest `Unknown` is required; a plausible
guess is forbidden. `Unknown` is the sanctioned, contract-valid marker and the validator accepts
it. Every `Unknown` field is also aggregated into section 10.

## Merge policy (from `docs/HOST_REPO_ADAPTATION_POLICY.md`)

The generator **never blind-copies** DMC's own `AGENTS.md` and **never overwrites** an existing
one: if the output path exists it refuses (exit 3) and the caller chooses a different `--out` or
removes the file deliberately. `--stdout` prints without touching the filesystem.

## Size budget

Codex reads `AGENTS.md` up to `project_doc_max_bytes` (default **32768 bytes**, spike-confirmed at
codex-cli 0.132.0) and truncates beyond it. The generator **never truncates**; when output exceeds
32768 bytes it prints a stderr warning (exit stays 0) naming the sections to externalize (typically
section 4 Architecture landmarks and section 7 DMC operating rules).

## Validator refusal heuristics (`--validate FILE`)

REFUSED (exit 3) when any of:

- a REQUIRED section heading (`## N. Title`, N = 1..10, exact title) is **missing**, or its title
  does not match the contract title;
- a required section body is **empty / whitespace-only**;
- a required section body contains **guessed-looking filler** that should have been `Unknown`:
  - an unfinished-work token — `TODO`, `TBD`, `FIXME`, `WIP`, `XXX` (case-insensitive, word-bounded);
  - `lorem` / lorem-ipsum placeholder text (case-insensitive);
  - a `???` placeholder;
  - an unfilled angle-bracket template placeholder, matched as `<...>` around a word/phrase
    (a fully-resolved document has none; `Unknown` has no angle brackets and is unaffected).

VALID (exit 0) when all ten sections are present, correctly titled, non-empty, and free of the
filler heuristics above. The literal token `Unknown` is explicitly ALLOWED and is the correct way
to mark a non-derivable fact.
