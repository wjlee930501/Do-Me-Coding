# VERIFICATION_PLANNER.md — DMC Verification Planner (v0.5.5)

Run **enough**, not everything — with escalation when risk demands it. The planner
(`.harness/evidence/dmc-v0.5.5-verification-planner.sh`) maps changed-path categories + workflow lane to the minimal
sufficient verification set. Advisory; inert unless invoked; reads no env/`.env`/secret; no network/live call.

## Inputs
`changed_paths` (csv) · `lane` · `protected_surface` (bool) · `prior_findings` (int) · `test_failures` (int).

## Outputs
`required_checks` (union, accumulating) · `optional_checks` · `forbidden_checks` (always present) · `reason`.

## Rules
- **Per category (required, accumulated):** docs ⇒ markdown style + append-only/status; shell tool ⇒ `--self-test` +
  structural shell audit; schema ⇒ schema validation + **protected byte-unchanged**; provider/import ⇒ result/schema
  validator + **leak scan** + **reject-path tests** + byte-unchanged; guard/hook/validator/classifier/importer ⇒
  reject-path + byte-unchanged; text-bearing artifact ⇒ **leak scan**.
- **Protected near-scope** (a protected path *or* a `protected_surface` flag) ⇒ add a **protected-path byte-unchanged**
  check (`git diff --name-status` over the protected set).
- **Fail-CLOSED:** an unparseable / empty-but-present / uncategorizable `changed_paths` ⇒ the **maximal** verification set
  (self-test + leak scan + reject-path + byte-unchanged), flagged `[FAIL-CLOSED]` — **never silently skipped**.
- **Forbidden checks (always):** read/print `.env` or any credential; make a live provider/network call to "verify";
  print raw provider payloads or user content; auto-apply reviewer/critic output.
- **Escalation:** any prior finding / test failure (or an unparseable count) ⇒ add an adversarial re-verify.
- **Lane-driven escalation:** the workflow `lane` (from the v0.5.3 selector) drives required checks regardless of path
  category — a `protected-surface` lane forces protected byte-unchanged; a `secret-network-live-risk` lane forces leak
  scan + reject-path + adversarial re-verify + byte-unchanged; an unrecognized lane ⇒ fail-closed maximal set. Caller
  changed-path values echoed in the reason are **value-blind redacted**.
- **Monotonic / union:** adding a riskier path never removes a required check.
