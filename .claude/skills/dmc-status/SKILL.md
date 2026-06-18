---
name: dmc-status
description: Report the current Do-Me-Coding mode and whether a run is in progress.
disable-model-invocation: true
---

# Do-Me-Coding Status

Report current Do-Me-Coding state:

1. **Mode** — read the first line of `.harness/mode`. If the file is absent, report `active (default)`.
2. **Active run** — if `.harness/runs/current-run-id` exists, print the run id and WARN that a Do-Me-Coding run is in progress; recommend finishing or cancelling it (and using a separate branch / `git worktree` for OMC) before OMC work. If absent, report "no active run".
3. **What the mode enforces:**
   - `active` — full enforcement (deny + ask, scope lock, stop/verify gate, evidence logging).
   - `passive` — full destructive + secret deny; ask prompts and scope/stop/evidence gates stand down.
   - `off` — catastrophic-destructive + secret-exposure deny only; everything else passes through.
