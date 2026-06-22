# evidence.schema.md

The redacted evidence artifact emitted by the v0.4.4 Evidence Harness for an autonomous run. Local-only by default.

```text
# DMC Autonomous Run Evidence — <run_id>
- run_id:
- self_test: N PASS / M FAIL          # extracted, standardized
- commands:                            # one per line: <command> : <result>
  - <cmd> : <result>
- result_summary: PASS | FAIL | PARTIAL
- redaction: applied for known token/path/env/provider shapes; NOT a completeness guarantee — review before commit
```

Redaction is a **best-effort, value-blind** pass applied before write — it is **NOT a completeness guarantee**, and a
human MUST review an artifact before committing it. The redactor targets these **known shapes**, replacing each with
`[redacted:secret]` / `[redacted:env-value]` / `[redacted:provider-payload]` / `[redacted:abs-path]`:

- secret/token-shaped values (`sk-`/`AKIA`/PEM keys/`gh[opsu]_`/JWT/`Bearer`/`ya29.`/`*_token`);
- credential-var assignment values (`*_KEY=`/`*_TOKEN=`/`*_SECRET=`) **and** bare `password=`/`passwd=`/`secret=`/`token=`/`api-key=`/`auth=` fragments;
- provider-payload content fields (`"content"`/`"text"`/`"message"`/`"completion"`/`"prompt"`: "…");
- absolute private paths (`/Users/<user>/…`, `/home/<user>/…`, `C:\Users\<user>\…`).

The value-blind redactor never re-emits a matched value. Shapes **outside** this set — sub-threshold tokens, non-token
prose, exotic path roots (`/opt`, `/var/folders`, …) — may survive; **do not** treat the artifact as guaranteed-clean.
```
