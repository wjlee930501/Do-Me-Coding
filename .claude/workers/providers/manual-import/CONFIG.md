# manual-import — configuration (v0.3.1)

manual_import is a **pure-validation importer**: it makes **no** network/model-API/live call, reads **no** `.env*` or
credentials, and requires **no** API key or token. There is therefore **no credential configuration** of any kind.

## Environment

| Variable | Required | Purpose |
|---|---|---|
| `DMC_MANUAL_IMPORT_MAX_BYTES` | optional | Max accepted artifact size in bytes (default **1048576 = 1 MiB**). An import larger than this is rejected **before** parse/scan (untrusted-input / DoS / log-amplification hygiene). A non-positive or non-integer value is ignored (default used). |

No other environment variable is read. In particular **no** `*_API_KEY`, `DMC_OAUTHCLI_*`, or any credential/path/secret
variable is consulted — manual_import has nothing to authenticate to.

## Safety
- **No credentials in the repo; none read at runtime.** The adapter opens only the operator-provided `--task`,
  `--import`, and `--out` paths — never `.env*`, never an implicit/HOME-derived location.
- **No values logged or serialized.** Reject diagnostics are generic and never echo imported content; secret/token-shaped
  content is rejected (never redacted-and-emitted).
- **`credential_exposure="none"`** in the emitted result describes **only DMC's own handling** of the artifact (DMC made
  no call, used no credentials) **after** the raw secret/token scan passes — it is **not** a claim about the unknown
  upstream tool the human used.
- **`--out`** writes only the normalized result and refuses a protected/secret/traversal/symlink target (canonicalized).
