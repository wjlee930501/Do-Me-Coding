---
name: dmc-off
description: Turn Do-Me-Coding off (catastrophic + secret-exposure deny only) for OMC coexistence.
disable-model-invocation: true
---

# Do-Me-Coding Off

Set Do-Me-Coding to `off`. In `off`, ONLY catastrophic-destructive and secret-exposure commands are denied; the package `ask` prompts, scope lock, stop/verify gate, and evidence logging all stand down. Use this when running OMC (or other tooling) in the same repository.

Steps:
1. **Check for an in-progress run first.** If `.harness/runs/current-run-id` or any `.harness/runs/current-*` exists, WARN that a Do-Me-Coding run is active; recommend finishing or cancelling it — and prefer a separate branch or `git worktree` for OMC work — before turning DMC off.
2. Write off:
   ```bash
   printf 'off\n' > .harness/mode
   ```
3. Confirm the mode is `off` and restate what remains enforced: catastrophic-destructive (e.g. `rm -rf /`, `git push --force`, `terraform destroy`, `DROP DATABASE`) **and** secret-exposure (`cat .env`, `~/.ssh`, `~/.aws`, `printenv`) commands are still denied. It is "non-interfering except catastrophic/security-deny," not fully inert.

Do NOT assume OMC has a universal off switch — DMC simply steps aside via `.harness/mode`. See `docs/OMC_COEXISTENCE.md`.
