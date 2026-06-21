# evidence.schema.md

The redacted evidence artifact emitted by the v0.4.4 Evidence Harness for an autonomous run. Local-only by default.

```text
# DMC Autonomous Run Evidence — <run_id>
- run_id:
- self_test: N PASS / M FAIL          # extracted, standardized
- commands:                            # one per line: <command> : <result>
  - <cmd> : <result>
- result_summary: PASS | FAIL | PARTIAL
- redaction: applied                   # MUST be present; see below
```

Redaction is **mandatory** and applied before write. The artifact MUST NOT contain: secret/token-shaped values
(`sk-`/`AKIA`/PEM keys/`gh[opsu]_`/JWT/`Bearer`/`ya29.`/`*_token`), credential-var assignment values
(`*_KEY=`/`*_TOKEN=`/`*_SECRET=`), `.env`/credential file **contents**, raw provider payloads, or absolute private paths
(`/Users/<user>/…`, `/home/<user>/…`) — these are replaced by `[redacted:secret]` / `[redacted:env-value]` /
`[redacted:abs-path]`. The value-blind redactor never re-emits a matched value.
```
