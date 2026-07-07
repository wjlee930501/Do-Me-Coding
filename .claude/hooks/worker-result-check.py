#!/usr/bin/env python3
"""Do-Me-Coding Worker Bridge — result validator (v0.2; M7-hardened).

Validates a worker RESULT against its TASK at import/review time, BEFORE any human application.
Checks (per WORKER_RESULT_SCHEMA.md): no_direct_mutation, credential_exposure=none, a task/result
required-field floor, files_changed == diff touched paths, files_changed ⊆ allowed_files,
∩ forbidden_files = ∅, no disallowed category, no inline token/secret material, and task_id/provider
provenance consistency. Reads JSON only; applies nothing. FAIL-CLOSED: malformed/duplicate-key input,
an empty allowed_files scope, or an unloadable detector source ⇒ clean REJECT (never a traceback).

Token detectors (SECRET_VALUE + the six credential-token classes a worker result must never carry + PLACEHOLDER exclusion) are imported
EXACTLY from .claude/workers/providers/oauth-cli/oauth-cli-adapter.py — single source, no re-derived
subset — mirroring the manual-import adapter precedent (manual-import-adapter.py). The module-level
`DISALLOWED` list and `diff_paths(patch) -> set` are PRESERVED VERBATIM because
manual-import-adapter.py imports both by name; the hardened diff parsing lives in the NEW
`diff_entries()` (rename/copy/binary/zero-path aware, fail-closed).

Usage: worker-result-check.py <task.json> <result.json>   ->  exit 0 ACCEPT / 1 REJECT / 2 usage
"""
import importlib.util, json, os, re, sys

# The importlib load below must NOT write .pyc into __pycache__ (esp. under the protected providers
# tree). Disable bytecode caching before any importlib load (manual-import-adapter.py:31-33 precedent).
sys.dont_write_bytecode = True

DISALLOWED = [
    (re.compile(r'(^|/)\.env(\.|$)'), '.env*'),
    (re.compile(r'\.lock$|(^|/)(package-lock\.json|pnpm-lock\.yaml|yarn\.lock)$'), 'lockfile'),
    (re.compile(r'(^|/)(package\.json|requirements\.txt|go\.mod|Cargo\.toml|Gemfile)$'), 'dependency-file'),
    (re.compile(r'(^|/)migrations?/|drizzle'), 'db/schema/migration'),
    (re.compile(r'\.(png|jpe?g|gif|pdf|zip|so|dylib|exe|bin|woff2?)$'), 'binary'),
    (re.compile(r'(prod|production)[.-].*config|\.prod\.'), 'production-config'),
]


def diff_paths(patch):
    paths = set()
    for ln in patch.splitlines():
        m = re.match(r'^(?:---|\+\+\+) (?:a/|b/)?(.+?)\s*$', ln)
        if m:
            p = m.group(1).strip()
            if p != '/dev/null':
                paths.add(p)
    return paths


# --- Shared-source token detectors: imported EXACTLY from oauth-cli-adapter.py (no re-derived subset;
# manual-import precedent). A load failure keeps this module import-safe (manual-import imports
# DISALLOWED/diff_paths from here) and fail-closes the CLI via _DETECTOR_ERR — NEVER a module-level
# sys.exit, which would escape manual-import's `except Exception` _load and break its exit-2 contract
# and C7 byte-determinism. The local 5-class SECRET_VALUE literal is replaced by the imported one. ---
_DETECTOR_ERR = None
SECRET_VALUE = None
PLACEHOLDER = None
find_token_material = None
try:
    _OAUTH_SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                              "..", "workers", "providers", "oauth-cli", "oauth-cli-adapter.py")
    _spec = importlib.util.spec_from_file_location("dmc_oauth_cli_adapter_rc", _OAUTH_SRC)
    if _spec is None or _spec.loader is None:
        raise ImportError("no spec/loader for the oauth-cli detector source")
    _det = importlib.util.module_from_spec(_spec)
    _spec.loader.exec_module(_det)   # __main__-guarded source: defines constants/functions only
    SECRET_VALUE = _det.SECRET_VALUE
    PLACEHOLDER = _det.PLACEHOLDER
    find_token_material = _det.find_token_material
except Exception:
    _DETECTOR_ERR = 'detector source missing/unloadable (fail-closed)'


# --- Hardened diff parser (NEW; diff_paths above stays legacy-verbatim for the manual-import import). ---
_DIFF_GIT_RE = re.compile(r'^diff --git a/(.+) b/(.+)$')
_MINUS_RE = re.compile(r'^--- (?:a/|b/)?(.+?)\s*$')
_PLUS_RE = re.compile(r'^\+\+\+ (?:a/|b/)?(.+?)\s*$')
_RENAME_FROM_RE = re.compile(r'^rename from (.+?)\s*$')
_RENAME_TO_RE = re.compile(r'^rename to (.+?)\s*$')
_COPY_FROM_RE = re.compile(r'^copy from (.+?)\s*$')
_COPY_TO_RE = re.compile(r'^copy to (.+?)\s*$')
_BINARY_RE = re.compile(r'^Binary files (?:a/)?(.+?) and (?:b/)?(.+?) differ\s*$')


def diff_entries(patch):
    """Structured, fail-closed diff parser. Returns a list of
    {"paths": [...sorted, /dev/null excluded...], "kind": "text|rename|copy|binary", "hunks": <@@ count>}.
    Path-source precedence (pinned): ---/+++ , rename from/to, copy from/to, and
    "Binary files a/X and b/Y differ" are AUTHORITATIVE; the `diff --git a/X b/Y` header contributes
    paths ONLY as the zero-path fallback (e.g. GIT binary patch). c-quoted paths are refused upstream
    and NEVER unquoted here. Over-rejects rather than bypasses on ambiguous/space-bearing paths."""
    entries = []
    cur = None

    def flush():
        nonlocal cur
        if cur is None:
            return
        paths = set(cur['auth']) or set(cur['header'])
        paths.discard('/dev/null')
        if cur['rename']:
            kind = 'rename'
        elif cur['copy']:
            kind = 'copy'
        elif cur['binary']:
            kind = 'binary'
        else:
            kind = 'text'
        entries.append({'paths': sorted(paths), 'kind': kind, 'hunks': cur['hunks']})
        cur = None

    def ensure():
        nonlocal cur
        if cur is None:
            cur = {'auth': set(), 'header': set(), 'rename': False,
                   'copy': False, 'binary': False, 'hunks': 0, 'saw_minus': False}
        return cur

    for ln in patch.splitlines():
        mg = _DIFF_GIT_RE.match(ln)
        if mg:
            flush()
            e = ensure()
            e['header'].add(mg.group(1).strip())
            e['header'].add(mg.group(2).strip())
            continue
        mm = _MINUS_RE.match(ln)
        if mm:
            if cur is not None and cur['saw_minus']:
                flush()
            e = ensure()
            e['saw_minus'] = True
            e['auth'].add(mm.group(1).strip())
            continue
        mp = _PLUS_RE.match(ln)
        if mp:
            ensure()['auth'].add(mp.group(1).strip())
            continue
        mb = _BINARY_RE.match(ln)
        if mb:
            e = ensure()
            e['binary'] = True
            e['auth'].add(mb.group(1).strip())
            e['auth'].add(mb.group(2).strip())
            continue
        if ln.strip() == 'GIT binary patch':
            ensure()['binary'] = True
            continue
        m = _RENAME_FROM_RE.match(ln) or _RENAME_TO_RE.match(ln)
        if m:
            e = ensure()
            e['rename'] = True
            e['auth'].add(m.group(1).strip())
            continue
        m = _COPY_FROM_RE.match(ln) or _COPY_TO_RE.match(ln)
        if m:
            e = ensure()
            e['copy'] = True
            e['auth'].add(m.group(1).strip())
            continue
        if ln.startswith('@@') and cur is not None:
            cur['hunks'] += 1
    flush()
    return entries


def _no_dup_keys(pairs):
    seen = {}
    for k, v in pairs:
        if k in seen:
            raise ValueError('duplicate key in JSON object')
        seen[k] = v
    return seen


def _reject(reasons):
    print('REJECT')
    for r in reasons:
        print('  - ' + r)
    sys.exit(1)


def main():
    if len(sys.argv) != 3:
        print("usage: worker-result-check.py <task.json> <result.json>", file=sys.stderr)
        sys.exit(2)

    # Detector availability degrades to REJECT, never to a bypass.
    if _DETECTOR_ERR is not None:
        _reject([_DETECTOR_ERR])

    try:
        with open(sys.argv[1]) as f:
            task = json.load(f, object_pairs_hook=_no_dup_keys)
        with open(sys.argv[2]) as f:
            result = json.load(f, object_pairs_hook=_no_dup_keys)
    except Exception:
        _reject(['malformed, unreadable, or duplicate-key JSON (fail-closed)'])

    if not isinstance(task, dict) or not isinstance(result, dict):
        _reject(['task and result must both be JSON objects (fail-closed)'])

    errs = []

    # --- proposal-safety invariants (v0.2) ---
    if result.get('no_direct_mutation') is not True:
        errs.append('no_direct_mutation must be true')
    pm = result.get('provider_metadata')
    if not isinstance(pm, dict):
        errs.append('result missing required field: provider_metadata')
        pm = {}
    if pm.get('credential_exposure') != 'none':
        errs.append('provider_metadata.credential_exposure must be none')

    # --- task-side floor (compatibility-verified against every legacy VAL caller) ---
    task_id = task.get('task_id')
    if not (isinstance(task_id, str) and task_id.strip()):
        errs.append('task floor: task_id must be a non-empty string')
    allowed_raw = task.get('allowed_files')
    if not (isinstance(allowed_raw, list) and allowed_raw):
        errs.append('empty allowed_files: scope-less worker tasks are refused')
    pt = task.get('provider_target')
    if not isinstance(pt, dict):
        errs.append('task floor: provider_target missing')
        pt = {}
    ptype = pt.get('type')
    if not (isinstance(ptype, str) and ptype.strip()):
        errs.append('task floor: provider_target.type must be non-empty')

    # --- result-side required-field presence (the proven v0.3.3 C1 floor) ---
    for k in ('task_id', 'summary', 'files_considered', 'files_changed',
              'proposed_patch', 'instructions', 'confidence', 'no_direct_mutation'):
        if k not in result:
            errs.append('result missing required field: ' + k)
    for k in ('provider_type', 'provider', 'credential_exposure'):
        if k not in pm:
            errs.append('result missing required field: provider_metadata.' + k)

    # --- provenance-consistency cross-checks (worker-supplied metadata; NOT authentication) ---
    if result.get('task_id') != task.get('task_id'):
        errs.append('result.task_id does not match task.task_id')
    if isinstance(ptype, str) and ptype == 'mock':
        pass  # mock carve-out: a mock task may be served by any adapter in mock mode (v0.2 legacy)
    else:
        if pm.get('provider_type') != ptype:
            errs.append('provider_type mismatch: result != task.provider_target.type')
        tprov = pt.get('provider')
        if isinstance(tprov, str) and tprov.strip() and pm.get('provider') != tprov:
            errs.append('provider mismatch: result != task.provider_target.provider')

    # --- scope / disallowed-category / diff-fidelity ---
    allowed = set(allowed_raw) if isinstance(allowed_raw, list) else set()
    forbidden = set(task.get('forbidden_files') or [])
    fc = set(result.get('files_changed') or [])
    patch = result.get('proposed_patch') or ''
    if not isinstance(patch, str):
        patch = ''

    for ln in patch.splitlines():
        if ln.startswith('diff --git') and '"' in ln:
            errs.append('c-quoted path refused: git-quoted path in diff --git header (fail-closed)')
            break

    dp = set()
    for e in diff_entries(patch):
        dp.update(e['paths'])
    if patch.strip() and not dp:
        errs.append('unparseable diff: non-empty proposed_patch yielded zero paths (fail-closed)')
    if patch and dp != fc:
        errs.append('files_changed %s != diff touched paths %s' % (sorted(fc), sorted(dp)))
    for p in sorted(fc | dp):
        if allowed and p not in allowed:
            errs.append('out-of-scope path not in allowed_files: ' + p)
        if p in forbidden:
            errs.append('forbidden_files path: ' + p)
        for rx, label in DISALLOWED:
            if rx.search(p):
                errs.append('disallowed category [%s]: %s' % (label, p))

    # --- token/secret material scan (value-blind: only labels are computed, VALUES never printed;
    # PLACEHOLDER-excluded). Single imported source covers SECRET_VALUE + the six OAuth/JWT classes. ---
    if find_token_material(json.dumps(task), json.dumps(result)):
        errs.append('token/secret material detected in task/result bundle (value-blind)')

    if errs:
        _reject(errs)
    print('ACCEPT (all import/review checks pass)')
    sys.exit(0)


if __name__ == '__main__':
    main()
