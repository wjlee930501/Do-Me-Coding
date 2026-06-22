# PLAN — v0.5.5 Verification Planner (APPROVED)

Parent: batch plan (APPROVED). Additive; protected surface untouched.

## Goal
Map changed-path categories + lane to the minimal sufficient verification set (required/optional/forbidden + reason);
protected-near-scope ⇒ byte-unchanged; text-artifacts ⇒ leak scan; guards/importers/classifiers ⇒ reject-path;
malformed/uncategorizable paths ⇒ fail-closed maximal set (never silent skip).

## Accepted file scope (additive)
`docs/VERIFICATION_PLANNER.md` · `.harness/evidence/dmc-v0.5.5-verification-planner.sh` · this plan ·
`.harness/verification/dmc-v0.5.5-verification-planner.md`

## Acceptance criteria
docs-only ⇒ markdown/check/status; shell tool ⇒ self-test + structural grep; provider/import ⇒ schema/result validator +
leak checks + reject-path; protected mentions ⇒ byte-unchanged; malformed path list ⇒ fail closed. Self-test green; repo
byte-unchanged.

## Stop conditions
Silent verification skip, secret read, env inference, protected-surface mutation.
