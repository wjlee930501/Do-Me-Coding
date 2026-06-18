---
name: dmc-on
description: Activate Do-Me-Coding enforcement by setting .harness/mode (active or passive).
argument-hint: "[active|passive]"
disable-model-invocation: true
---

# Do-Me-Coding On

Set the Do-Me-Coding mode for this repository.

Argument: `active` (default) or `passive`.
- **active** — full enforcement: destructive + secret deny, package `ask` prompts, scope lock, stop/verify gate, evidence logging.
- **passive** — full destructive + secret-exposure deny remain; the package `ask` prompts and the scope/stop/evidence workflow gates stand down (less intrusive; use while OMC is driving).

Steps:
1. Resolve the mode from the argument; default to `active` if none given. Accept only `active` or `passive` — for `off`, use `/dmc-off`.
2. Write it:
   ```bash
   printf '<mode>\n' > .harness/mode
   ```
3. Confirm: print the new mode and what it enforces. Note `.harness/mode` is gitignored (a local, transient switch); absent means `active` by default.
