# PLAN — v0.6.3 Findings Gate (DRAFT, Rev 2)

**Parent roadmap:** `.harness/plans/dmc-v0.6.1-v0.6.5-roadmap.md` (APPROVED). **Branch:** `dmc-control-plane/v0.6.1`.
**Depends on:** v0.6.1.0 Trace Linkage Contract (`--validate-entry finding` / `--validate-entry approval`) — committed.
**Type:** schema + deterministic validator + release gate (append-only + closure) + append-check. **Additive, advisory,
fail-closed, input-only, read-only**; no protected-surface change, no live/model/API/`.env`/network, no auto-apply.

**Rev 2 (2026-06-23):** incorporated the dual Critic gate (critic NEEDS-CLARIFICATION + Codex REVISE, convergent). Fixes:
(1) the authoritative decision is **`--release` = append-check(prev→next) AND gate(next)** so a dropped prior finding can't be
bypassed by running `--gate` alone; (2) **waiver must be a subject-consistent `approval` fragment that passes
`--validate-entry approval`** (shape+binding verified; *authenticity that a human truly approved is upstream — honest scope*),
not a bare `{type,source}`; (3) **`summary_class` (non-prose) enforced at validate AND gate**; (4) append identity =
**canonical-JSON per `id`** (not "byte-identical"), **duplicate finding ids rejected**; (5) a **sibling `token_ok` predicate**
(`^[A-Za-z0-9._-]+$`) for category tokens — distinct from v0.6.2's `artifact_ref_ok` (which needs `/` or hex); `evidence_ref`
shape-only (receipt-existence = v0.6.5); (6) value-blind on every sub-command; spelled-out 4-field subject compare;
contract-negative.

**Purpose.** Answer **Q3 — "what findings remain?"** and ensure **no unresolved finding crosses a release gate invisibly.**

---

## 1. Problem statement
Agents note problems then proceed: findings get silently dropped, left stateless, or waived without an explicit human
decision. v0.6.3 makes every finding a typed, subject-bound register entry with a state + state-specific requirements, and the
**release decision couples** an append-only check (no finding dropped/rewritten) with a closure check (no blocked/unknown/
unmet-requirement crosses).

## 2. Non-goals
- **No** silent/dropped findings, no hidden/implicit waivers, no unknown finding state, no state rewrite.
- **No** provider/model/API/network/`.env` read; reads only the input file/stdin; all sub-commands call **no git**.
- **Not** verifying authenticity of a human approval or existence of a referenced receipt (input-only) — that is upstream
  (human Release Gate + v0.6.5 composer); v0.6.3 verifies **shape + subject-consistency**, honestly scoped.
- **Not** implementing v0.6.4/v0.6.5; mints only `finding` fragments.

## 3. Design
### 3.1 Predicates (decidable; pinned)
- **`token_ok(s)`** := single-line, non-empty, `^[A-Za-z0-9._-]+$`, length ≤ 128 (a category/owner/target token; **sibling of**,
  not equal to, v0.6.2's `artifact_ref_ok`). Rejects whitespace/prose/`/`-paths/secret-shapes.
- **`ref_ok(s)`** (for `evidence_ref`) := `token_ok(s)` (an `evidence_receipt_id`) OR v0.6.2-style safe path/hash. **Shape-only**;
  that it links a *real* receipt is the v0.6.5 composer's job (honest scope).

### 3.2 Finding (a trace-linkage `finding` fragment + v0.6.3-owned fields)
```text
{ "kind":"finding", "id":"<opaque>", "producer_milestone_id":"v0.6.3",
  "state":"resolved|accepted-risk|deferred|blocked",
  "work_id","plan_hash"(hex≥16),"repo_hash"(hex≥16),"verification_ref",   # 4 contract binding fields
  "summary_class": "<token_ok>",                                          # REQUIRED, all states (the "what")
  "evidence_ref": "<ref_ok>",                                             # REQUIRED iff resolved
  "waiver": { "approval": <approval entry> },                             # REQUIRED iff accepted-risk (see §3.3)
  "owner":"<token_ok>", "target":"<token_ok>", "release_policy":"<token_ok>" }   # REQUIRED iff deferred
```
Base entry (kind=finding, producer=v0.6.3, id, 4-binding, state ∈ 4) passes the contract `--validate-entry finding`;
`summary_class`/`evidence_ref`/`waiver`/`owner`/`target`/`release_policy` are **v0.6.3-owned**.

### 3.3 Pass/fail matrix (release) — every requirement enforced at `--validate` AND `--gate`
| state | release | requires (besides `summary_class` non-prose, always) |
|-------|---------|------------------------------------------------------|
| `resolved` | PASS | `evidence_ref` (`ref_ok`) |
| `accepted-risk` | PASS | `waiver.approval` is an **`approval` entry that passes contract `--validate-entry approval`** AND is **subject-consistent** with the finding (4 binding fields equal) — defeats spoofed/cross-subject waivers; *human authenticity upstream* |
| `deferred` | PASS | `owner` + `target` + `release_policy` (all `token_ok`) |
| `blocked` | **FAIL** | — never crosses |
| unknown/missing | **FAIL** | — fail-closed |

### 3.4 Sub-commands
- `--validate <finding.json|->` → validate one finding (state ∈ 4; 4-binding; `summary_class` `token_ok`; the state's required
  fields present + valid; waiver via contract). exit 0/1/2.
- `--gate <{subject, findings:[…]}>` → snapshot closure: ALLOW iff every finding is subject-consistent (its 4 binding fields ==
  the subject's corresponding 4 of 5) AND release-PASS (§3.3); empty findings → ALLOW (no findings = valid Q3); a finding
  without a state → REFUSE. exit 0 ALLOW / 1 REFUSE.
- `--append-check <{prev:[…], next:[…]}>` → ALLOW iff every `prev` `id` is in `next` with **canonical-JSON-identical** content
  (no drop, no state/content rewrite) and only additions exist; **duplicate ids within prev or next → REFUSE**. exit 0/1.
- `--release <{subject, prev:[…], next:[…]}>` → **the authoritative release decision** = `append-check(prev,next)` ALLOW **AND**
  `gate({subject, findings:next})` ALLOW. Either fails → REFUSE. This prevents bypass-by-drop. Emits the verdict + the Q3
  remaining-findings list. `--out` optional, write-safe.
- `--self-test`.

### 3.5 Outputs
- `.harness/schemas/findings-register.schema.md` — finding shape + 4 states + pass/fail matrix + the two predicates +
  append-only(canonical) rule + the `--release` coupling + honest scope; cites trace-linkage.
- `.harness/evidence/dmc-v0.6.3-findings-gate.{py,sh}` — validator + gate + append-check + release; input-only, env-free,
  no-heredoc/no-temp, dup-key-rejecting, value-blind on every sub-command, write-safe `--out`.
- `.harness/verification/dmc-v0.6.3-findings-gate.md` — report.

## 4. File scope (additive only): the 3 deliverables + this plan. No other file touched.

## 5. Acceptance criteria (`--self-test`; every negative named, asserts its reason)
| ID | Assertion |
|----|-----------|
| F1 | a valid finding in each of the 4 states → VALID; base entry passes contract `--validate-entry finding`. |
| F1neg | the contract REJECTs a finding fragment with producer ≠ v0.6.3 (binding is load-bearing). |
| F2 | unknown/missing `state` → REJECT. |
| F3a | `resolved` without `evidence_ref` (or non-`ref_ok`) → REJECT. |
| F3b | `accepted-risk` waiver that fails `--validate-entry approval` (non-human type / bad source prefix / wrong producer) → REJECT. |
| F3c | `accepted-risk` waiver subject ≠ finding subject (foreign-subject approval) → REJECT. |
| F3d | `accepted-risk` with no `waiver` → REJECT (no hidden waiver). |
| F3e | `deferred` missing any of `owner`/`target`/`release_policy` → REJECT (3 named negatives). |
| F4 | missing/empty/prose/whitespace/`/`-containing `summary_class` → REJECT (not `token_ok`). |
| F5 | gate: a `blocked` or unknown-state finding present → REFUSE. |
| F6 | gate: a finding whose 4 binding fields ≠ the subject's → REFUSE (per-field negatives). |
| F7 | gate: all findings PASS → ALLOW (verdict lists remaining findings = Q3 answer); empty findings → ALLOW (emits empty Q3 list). |
| F8a | append-check: dropping a prev finding → REFUSE. |
| F8b | append-check: rewriting a prev finding's state/content (canonical-different) → REFUSE; reordering keys / reformatting with identical content → ALLOW. |
| F8c | append-check: duplicate finding `id` in prev or next → REFUSE. |
| F8d | append-check: pure additions → ALLOW. |
| F9 | **release: drop a prior `blocked` finding from `next` then `--gate(next)` would ALLOW, but `--release` REFUSEs** (append-check catches the drop) — the bypass-by-drop control. |
| F10 | duplicate JSON key / secret-shaped string anywhere (incl. prev/next arrays) → REJECT; malformed root / `findings` not array → REFUSE. |
| F11 | determinism/env-free: `env -i` + hostile credential var → identical verdict; all sub-commands call no git. |
| F12 | read-only: repo byte-unchanged after `--self-test`; `--out` write-safe (core + wrapper). |
| F13 | regression: v0.6.1.0 (26/0) + v0.6.1 (7/0) + v0.6.2 (18/0) verifiers still green. |
| Fneg | every negative FAILs for its own reason; positives pass — no false-green. |

## 6. Safety constraints
Additive only; no protected-surface change; no live/model/API/network/`.env`; deterministic + env-independent; value-blind
reject-on-match (every sub-command); duplicate-key rejecting; advisory/fail-closed; inert unless invoked; **no silent/dropped
finding, no hidden/unverifiable-shape waiver, no unknown state, no state rewrite**; no-heredoc/no-temp; all sub-commands call no
git; `--out` write-safe (core + wrapper).

## 7. Regression budget
Before commit: v0.6.1.0 (26/0) + v0.6.1 (7/0) + v0.6.2 (18/0) self-tests.

## 8. Rollback
Additive on the feature branch: `git checkout -- <files>` before commit, or revert the additive commit. No protected surface,
no history rewrite, no force.

## 9. Approval status: **DRAFT (Rev 2) — Critic stage done (critic + Codex incorporated)**
Per the retained full-rigor cadence (one critic + one Codex per gate; fix the REVISE, proceed), build now → verify
(`--self-test`) → one audit round (DMC verifier + Codex) → commit on `dmc-control-plane/v0.6.1`. Push / main-FF / closure
remain human-gated.
