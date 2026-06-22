# REVIEW_PACKET_V2.md — DMC Review Packet Generator v2 (v0.5.6)

A **names-only, secret-safe** review packet for a `base..head` range. By default it uses git **metadata only** — never
file content, never a commit **body** (`%b`), never a diff/patch. Advisory; inert unless invoked; reads no env/secret;
no network/live call.

## What it emits
- `base` / `head`, the **name-status** file list (names only), and the `+ / -` stat.
- **protected-surface touches** (adapters / router / schemas / hooks / guards / `dmc-glm-smoke`).
- **forbidden/secret paths** (should be none).
- **excluded auto-log evidence** (`.harness/evidence/*.md` — flagged as not-a-review-artifact).
- **commit subjects** (`%s` only) — **value-blind redacted**; the commit **body is never read**.
- **test summary** — extracted ONLY from an allowlisted, canonical `.harness/verification/*.md` report (anchored
  `PASS=N FAIL=M` lines only).

## Hard guarantees
- **No content-extraction primitive** in the source: `%b`, `format-patch`, `cat-file`, `diff-tree`, `log -p`/`--patch`,
  `show <blob>` are structurally absent (asserted by the self-test; a negative control proves the ban bites).
- **`--verify-report` allowlist:** only a canonical, **non-symlink**, in-tree `.harness/verification/*.md` realpath is
  read; symlink / `..` / out-of-tree / non-verification / secret-named paths are **refused** (exit 2).
- A malicious commit subject or body **cannot leak** into the packet (subject redacted; body never read).

## Usage
`--base <sha> --head <sha> [--repo <dir>] [--verify-report <.harness/verification/*.md>] [--out <file>]`. The `--out`
target is refused for secret/protected/in-work-tree/symlink paths.
