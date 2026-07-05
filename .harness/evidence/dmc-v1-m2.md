# Evidence Log

Run ID: dmc-v1-m2
Started: 2026-07-05T09:42:55Z

## Tool Events

### 2026-07-05T09:42:55Z Write

File: /home/user/Do-Me-Coding/.harness/runs/current-run-id

### 2026-07-05T09:43:04Z Write

File: /home/user/Do-Me-Coding/.harness/runs/current-scope.txt

### 2026-07-05T09:44:30Z Write

File: /home/user/Do-Me-Coding/.harness/schemas/orientation.schema.md

### 2026-07-05T09:44:40Z Write

File: /home/user/Do-Me-Coding/.harness/schemas/landmarks.schema.md

### 2026-07-05T09:44:48Z Write

File: /home/user/Do-Me-Coding/.harness/schemas/depsurface.schema.md

### 2026-07-05T09:44:57Z Write

File: /home/user/Do-Me-Coding/.harness/schemas/radius.schema.md

### 2026-07-05T09:45:18Z Write

File: /home/user/Do-Me-Coding/bin/dmc

### 2026-07-05T09:47:09Z Write

File: /home/user/Do-Me-Coding/bin/lib/dmc-repo-intel.py

### 2026-07-05T09:47:15Z Write

File: /home/user/Do-Me-Coding/tests/fixtures/node/package.json

### 2026-07-05T09:47:16Z Write

File: /home/user/Do-Me-Coding/tests/fixtures/node/src/a.js

### 2026-07-05T09:47:18Z Write

File: /home/user/Do-Me-Coding/tests/fixtures/node/src/b.js

### 2026-07-05T09:47:19Z Write

File: /home/user/Do-Me-Coding/tests/fixtures/node/src/style.css

### 2026-07-05T09:47:20Z Write

File: /home/user/Do-Me-Coding/tests/fixtures/python/pyproject.toml

### 2026-07-05T09:47:21Z Write

File: /home/user/Do-Me-Coding/tests/fixtures/python/pkg/__init__.py

### 2026-07-05T09:47:22Z Write

File: /home/user/Do-Me-Coding/tests/fixtures/python/pkg/core.py

### 2026-07-05T09:47:23Z Write

File: /home/user/Do-Me-Coding/tests/fixtures/python/pkg/cli.py

### 2026-07-05T09:47:24Z Write

File: /home/user/Do-Me-Coding/tests/fixtures/empty/.gitkeep

### 2026-07-05T09:47:32Z Bash

```bash
chmod +x /home/user/Do-Me-Coding/bin/dmc && bash -n /home/user/Do-Me-Coding/bin/dmc && python3 -m py_compile /home/user/Do-Me-Coding/bin/lib/dmc-repo-intel.py && echo SYNTAX-OK && bin/dmc selftest 2>&1 | tail -60
```

### 2026-07-05T09:47:48Z Bash

```bash
cd /home/user/Do-Me-Coding
T=$(mktemp -d)
# E1: env-independence — orient output byte-identical under env -i
bin/dmc orient --root tests/fixtures/node > "$T/o1.json"
env -i PATH=/usr/bin:/bin:/usr/local/bin python3 bin/lib/dmc-repo-intel.py orient --root tests/fixtures/node > "$T/o2.json"
cmp -s "$T/o1.json" "$T/o2.json" && echo "PASS E1 env -i byte-identical" || echo "FAIL E1"
# E2: CLI round-trip — generate to --out then validate
bin/dmc landmarks --root . --out "$T/lm.json" && bin/dmc landmarks --validate "$T/lm.json" && echo "PASS E2 landmarks out+validate round-trip"
bin/dmc depsurface --root tests/fixtures/python --out "$T/ds.json" && bin/dmc depsurface --validate "$T/ds.json" && echo "PASS E2b depsurface round-trip"
# E3: radius file-based end-to-end with synthetic checks; then refusal without checks
bin/dmc landmarks --root tests/fixtures/node --out "$T/fxlm.json"
printf '{"pkg/cli.py": ["CHK-1"]}' > "$T/chk.json"; printf '{}' > "$T/nochk.json"
bin/dmc radius --depsurface "$T/ds.json" --landmarks "$T/fxlm.json" --checks "$T/chk.json" --scope pkg/cli.py --out "$T/rad.json" && bin/dmc radius --validate "$T/rad.json" && echo "PASS E3 radius file round-trip"
bin/dmc radius --depsurface "$T/ds.json" --landmarks "$T/fxlm.json" --checks "$T/nochk.json" --scope pkg/cli.py > "$T/refuse.txt"; rc=$?
[ $rc -eq 3 ] && grep -q "without >=1 check_id" "$T/refuse.txt" && echo "PASS E4 radius refusal exit 3"
# E5: --out guard refuses existing target
bin/dmc orient --root tests/fixtures/empty --out "$T/o1.json" 2>/dev/null; [ $? -eq 3 ] && echo "PASS E5 --out refuses existing target"
rm -rf "$T"
# E6: repo cleanliness + scope compliance
echo "--- changed/untracked tracked-tree paths ---"
git status --porcelain
```

### 2026-07-05T09:48:30Z Write

File: /home/user/Do-Me-Coding/.harness/evidence/dmc-v1-m2-repo-intel.md

### 2026-07-05T09:48:40Z Bash

```bash
rm /home/user/Do-Me-Coding/bin/lib/__pycache__/*.pyc && rmdir /home/user/Do-Me-Coding/bin/lib/__pycache__ && ls /home/user/Do-Me-Coding/bin/lib/
```

### 2026-07-05T09:48:58Z Write

File: /home/user/Do-Me-Coding/.harness/verification/dmc-v1-m2-repo-intel.md

### 2026-07-05T09:49:15Z Bash

```bash
git add bin tests .harness/schemas/orientation.schema.md .harness/schemas/landmarks.schema.md .harness/schemas/depsurface.schema.md .harness/schemas/radius.schema.md .harness/plans/dmc-v1-runtime-upgrade.md .harness/evidence/dmc-v1-m2-repo-intel.md .harness/verification/dmc-v1-m2-repo-intel.md && git status --porcelain && git commit -m "$(cat <<'EOF'
feat(dmc): M2 repository intelligence — P1/P2/P4/P5 (dmc orient/landmarks/depsurface/radius)

Human-gated M2-only milestone (plan Approval Status records M1 retroactive
ratification + M2-only approval; M3+ unapproved).

- bin/dmc Ring-0 entry point + bin/lib/dmc-repo-intel.py: deterministic,
  env-independent, offline generators with fail-closed validators
  (VALID=0 / REFUSED=3) and embedded self-tests for all four primitives.
- Schemas: orientation/landmarks/depsurface/radius (.harness/schemas/).
- Fixtures: tests/fixtures/{node,python,empty} with seeded dependents and
  an unscanned-extension file.
- Radius enforces >=1 check_id per entry (fail-closed, refusal untouched by
  tests — synthetic CHK-SYNTH-* ids on the positive path only).
- Landmark seed carries the DMC protected union; self-scan classifies own
  hooks/settings/providers/schemas/MILESTONES correctly.

Verification: selftest 36 PASS / 0 FAIL + 5 E-checks (env -i byte-identity,
out+validate round-trips, refusal exit 3, --out guard) = 41/0. Evidence:
.harness/evidence/dmc-v1-m2-repo-intel.md; report:
.harness/verification/dmc-v1-m2-repo-intel.md. Additive except the plan's
Approval Status block; protected surfaces untouched.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_017HL6QfwPnLQgghjg42bWuX
EOF
)" && git push -u origin claude/dmc-v1-runtime-upgrade-c5uch1 && git log --oneline -3 && git status --porcelain
```

