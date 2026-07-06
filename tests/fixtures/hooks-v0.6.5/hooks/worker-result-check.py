#!/usr/bin/env python3
"""Do-Me-Coding Worker Bridge — result validator (v0.2).

Validates a worker RESULT against its TASK at import/review time, BEFORE any human application.
Checks (per WORKER_RESULT_SCHEMA.md): no_direct_mutation, credential_exposure=none,
files_changed == diff touched paths, files_changed ⊆ allowed_files, ∩ forbidden_files = ∅,
no disallowed category, no inline secret value. Reads JSON only; applies nothing.

Usage: worker-result-check.py <task.json> <result.json>   ->  exit 0 ACCEPT / 1 REJECT
"""
import json, re, sys

DISALLOWED = [
    (re.compile(r'(^|/)\.env(\.|$)'), '.env*'),
    (re.compile(r'\.lock$|(^|/)(package-lock\.json|pnpm-lock\.yaml|yarn\.lock)$'), 'lockfile'),
    (re.compile(r'(^|/)(package\.json|requirements\.txt|go\.mod|Cargo\.toml|Gemfile)$'), 'dependency-file'),
    (re.compile(r'(^|/)migrations?/|drizzle'), 'db/schema/migration'),
    (re.compile(r'\.(png|jpe?g|gif|pdf|zip|so|dylib|exe|bin|woff2?)$'), 'binary'),
    (re.compile(r'(prod|production)[.-].*config|\.prod\.'), 'production-config'),
]
SECRET_VALUE = re.compile(
    r'(sk-[A-Za-z0-9_-]{8,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----'
    r'|xox[baprs]-[0-9A-Za-z-]+|ghp_[A-Za-z0-9]{20,})')


def diff_paths(patch):
    paths = set()
    for ln in patch.splitlines():
        m = re.match(r'^(?:---|\+\+\+) (?:a/|b/)?(.+?)\s*$', ln)
        if m:
            p = m.group(1).strip()
            if p != '/dev/null':
                paths.add(p)
    return paths


def main():
    if len(sys.argv) != 3:
        print("usage: worker-result-check.py <task.json> <result.json>", file=sys.stderr)
        sys.exit(2)
    task = json.load(open(sys.argv[1]))
    result = json.load(open(sys.argv[2]))
    errs = []

    if result.get('no_direct_mutation') is not True:
        errs.append('no_direct_mutation must be true')
    if (result.get('provider_metadata') or {}).get('credential_exposure') != 'none':
        errs.append('provider_metadata.credential_exposure must be none')

    allowed = set(task.get('allowed_files') or [])
    forbidden = set(task.get('forbidden_files') or [])
    fc = set(result.get('files_changed') or [])
    patch = result.get('proposed_patch') or ''
    dp = diff_paths(patch)

    if patch and dp != fc:
        errs.append(f'files_changed {sorted(fc)} != diff touched paths {sorted(dp)}')
    for p in sorted(fc | dp):
        if allowed and p not in allowed:
            errs.append(f'out-of-scope path not in allowed_files: {p}')
        if p in forbidden:
            errs.append(f'forbidden_files path: {p}')
        for rx, label in DISALLOWED:
            if rx.search(p):
                errs.append(f'disallowed category [{label}]: {p}')

    if SECRET_VALUE.search(json.dumps(result)):
        errs.append('inline secret value detected in result')

    if errs:
        print('REJECT')
        for e in errs:
            print('  - ' + e)
        sys.exit(1)
    print('ACCEPT (all import/review checks pass)')
    sys.exit(0)


if __name__ == '__main__':
    main()
