#!/usr/bin/env python3
# DMC Run-Metrics Recorder (v1.1) — ADVISORY / opt-in, local-only, append-only, offline.
#
# Appends ONE compact JSONL row per real run to a local metrics ledger, and rolls the ledger up
# into a deterministic aggregate. ALL validation + secret redaction is DELEGATED to the FROZEN
# v0.5.0 validator (bin/lib/dmc-v0.5.0-run-metrics.sh); those rules are never re-implemented here.
# Reads ONLY the record file it is given and the frozen tool's stdout — never the environment,
# never .env / credentials, never the network. The ONLY subprocess target is the pinned frozen
# validator. No gate reads this ledger: it measures, it never grades. Fail-closed with named
# reason codes; secret/protected ledger paths refused by path only.
#
# Usage:  dmc-metrics-recorder.py record --from <record.json> [--ledger <path>]
#         dmc-metrics-recorder.py rollup [--ledger <path>]
#         dmc-metrics-recorder.py --self-test
# Exit: 0 = ok, 1 = record refused by the frozen validator (fail-closed, no append), 2 = usage/refused.
import os
import sys
import re
import json
import subprocess
import io
import contextlib
import tempfile

sys.dont_write_bytecode = True

SELF = os.path.realpath(__file__)
LIBDIR = os.path.dirname(SELF)                       # bin/lib
ROOT = os.path.dirname(os.path.dirname(LIBDIR))      # repo root
VALIDATOR = os.path.join(LIBDIR, "dmc-v0.5.0-run-metrics.sh")
DEFAULT_LEDGER = os.path.join(ROOT, ".harness", "metrics", "ledger.jsonl")

# Field taxonomy mirrors the frozen validator's REQ set (dmc-v0.5.0-run-metrics.sh) — schema field
# NAMES only; the validation + redaction RULES stay in the frozen tool. FREEFORM values are taken
# from the frozen tool's REDACTED emit; enums/numerics from the already-validated input record.
FREEFORM = ["run_id", "goal_type", "efficiency_notes"]
ENUMS = ["mode", "effort", "outcome"]
NUMERIC = ["context_files_count", "estimated_input_tokens", "estimated_output_tokens", "tool_calls",
           "wall_clock_sec", "files_touched", "tests_selected", "tests_run", "tests_passed",
           "tests_failed", "review_findings_total", "blockers", "retry_count", "human_gates"]
REQ = FREEFORM + ENUMS + NUMERIC

# Aggregation groupings for rollup.
COUNT_FIELDS = ["outcome", "effort", "mode"]
SUM_FIELDS = ["retry_count", "human_gates", "blockers", "review_findings_total"]
TEST_FIELDS = ["tests_selected", "tests_run", "tests_passed", "tests_failed"]

# Ledger-path fail-closed guard (override paths only) — modeled on the frozen tools' out_refused:
# refuse traversal, .env-class, secret/protected shapes, symlinks, and any in-repo-tree path; allow
# repo-external temp paths so self-tests never touch the real ledger. Path-only; no content read.
PROT_RE = re.compile(
    r'(^|/)\.env(\.|$)|\.pem$|\.key$|id_rsa|id_ed25519|credentials|secret'
    r'|\.p12$|\.pfx$|\.keystore$|\.claude/hooks|provider-router\.py', re.IGNORECASE)


def err(msg):
    sys.stderr.write("run-metrics-recorder: " + msg + "\n")


def _looks_env(raw):
    if re.search(r'\.env($|\.)', raw, re.IGNORECASE):
        if not re.search(r'\.(example|sample|template)$', raw, re.IGNORECASE):
            return True
    return False


def override_ledger_ok(raw):
    if not raw:
        return (False, "empty-ledger-path")
    if re.search(r'(^|/)\.\.(/|$)', raw):
        return (False, "path-traversal")
    if _looks_env(raw):
        return (False, "env-class-path")
    if PROT_RE.search(raw):
        return (False, "protected-or-secret-path")
    if os.path.islink(raw):
        return (False, "symlink-target")
    parent = os.path.dirname(raw) or "."
    if os.path.islink(parent):
        return (False, "symlink-parent")
    cparent = os.path.realpath(parent)
    if not os.path.isdir(cparent):
        return (False, "parent-not-a-directory")
    canon = os.path.join(cparent, os.path.basename(raw))
    if PROT_RE.search(canon) or _looks_env(canon):
        return (False, "protected-or-secret-canonical")
    if (canon + os.sep).startswith(ROOT + os.sep):
        return (False, "in-repo-tree")            # the DEFAULT ledger is the only in-tree allow
    return (True, "")


def default_ledger_ok(path):
    parent = os.path.dirname(path)
    if os.path.islink(parent):
        return (False, "symlink-parent")
    if os.path.exists(path) and os.path.islink(path):
        return (False, "ledger-is-symlink")
    return (True, "")


def run_validator(mode, record_path):
    # The single subprocess target: the pinned frozen validator. Env is inherited (never read here);
    # the frozen tool is proven env-independent, so inheritance cannot change its output.
    proc = subprocess.run(["bash", VALIDATOR, mode, record_path],
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=ROOT)
    return (proc.returncode,
            proc.stdout.decode("utf-8", "replace"),
            proc.stderr.decode("utf-8", "replace"))


def parse_emit(emit_text):
    # Extract the REDACTED free-form values from the frozen tool's deterministic emit lines.
    vals = {}
    for line in emit_text.splitlines():
        for key in FREEFORM:
            prefix = "- %s: " % key
            if line.startswith(prefix):
                vals[key] = line[len(prefix):]
    return vals


def append_row(ledger_path, line, is_default):
    parent = os.path.dirname(ledger_path) or "."
    if is_default:
        os.makedirs(parent, exist_ok=True)
    if os.path.islink(ledger_path):                 # defense-in-depth TOCTOU re-check
        return (False, "ledger-is-symlink")
    with open(ledger_path, "a", encoding="utf-8") as fh:
        fh.write(line + "\n")
    return (True, "")


def cmd_record(from_path, ledger_arg):
    if not os.path.isfile(from_path):
        err("record: --from file not found: %s" % from_path)
        return 2
    is_default = ledger_arg is None
    ledger_path = DEFAULT_LEDGER if is_default else ledger_arg
    ok, reason = default_ledger_ok(ledger_path) if is_default else override_ledger_ok(ledger_path)
    if not ok:
        err("record: ledger path REFUSED (%s): %s" % (reason, ledger_path))
        return 2

    # 1) frozen validate — non-zero => REFUSE, propagate the frozen stderr, NO append.
    rc, _out, er = run_validator("--validate", from_path)
    if rc != 0:
        sys.stderr.write(er)
        err("record: record REFUSED by frozen validator (exit %d); no append" % rc)
        return 1

    # 2) frozen emit — the redacted, review-safe rendering.
    rc2, emit_out, er2 = run_validator("--from", from_path)
    if rc2 != 0:
        sys.stderr.write(er2)
        err("record: frozen emit failed (exit %d); no append" % rc2)
        return 1

    # 3) redacted free-form values from the emit; enums/numerics from the validated input.
    vals = parse_emit(emit_out)
    for k in FREEFORM:
        if k not in vals:
            err("record: could not parse '%s' from frozen emit; no append" % k)
            return 1
    try:
        with open(from_path, encoding="utf-8") as fh:
            m = json.load(fh)
    except Exception:
        err("record: input JSON unreadable after validation; no append")
        return 1

    row = {}
    for k in FREEFORM:
        row[k] = vals[k]
    for k in ENUMS + NUMERIC:
        row[k] = m[k]
    line = json.dumps(row, sort_keys=True, separators=(",", ":"))

    wok, wreason = append_row(ledger_path, line, is_default)
    if not wok:
        err("record: ledger append REFUSED (%s): %s" % (wreason, ledger_path))
        return 2
    print("run-metrics-recorder: appended 1 row to %s" % ledger_path)
    return 0


def numstr(x):
    if isinstance(x, bool):
        return str(x)
    if isinstance(x, int):
        return str(x)
    if float(x) == int(x):
        return str(int(x))
    return repr(x)


def fmt_counts(d):
    return " ".join("%s=%d" % (k, d[k]) for k in sorted(d))


def median(vals):
    if not vals:
        return 0
    s = sorted(vals)
    n = len(s)
    if n % 2 == 1:
        return s[n // 2]
    return (s[n // 2 - 1] + s[n // 2]) / 2.0


def load_rows(ledger_path):
    valid = []
    malformed = 0
    if not os.path.exists(ledger_path):
        return valid, malformed
    with open(ledger_path, encoding="utf-8") as fh:
        for raw in fh:
            line = raw.rstrip("\n")
            if line.strip() == "":
                continue
            try:
                r = json.loads(line)
            except Exception:
                malformed += 1
                continue
            if not isinstance(r, dict) or not all(k in r for k in REQ):
                malformed += 1
                continue
            valid.append(r)
    return valid, malformed


def cmd_rollup(ledger_arg):
    is_default = ledger_arg is None
    ledger_path = DEFAULT_LEDGER if is_default else ledger_arg
    rows, malformed = load_rows(ledger_path)

    counts = {f: {} for f in COUNT_FIELDS}
    sums = {f: 0 for f in SUM_FIELDS}
    tests = {f: 0 for f in TEST_FIELDS}
    walls = []
    for r in rows:
        for f in COUNT_FIELDS:
            key = str(r[f])
            counts[f][key] = counts[f].get(key, 0) + 1
        for f in SUM_FIELDS:
            sums[f] += r[f]
        for f in TEST_FIELDS:
            tests[f] += r[f]
        walls.append(r["wall_clock_sec"])

    out = [
        "# DMC Run Metrics Rollup",
        "- row_count: %d" % len(rows),
        "- skipped_malformed: %d" % malformed,
        "- by_outcome: %s" % fmt_counts(counts["outcome"]),
        "- by_effort: %s" % fmt_counts(counts["effort"]),
        "- by_mode: %s" % fmt_counts(counts["mode"]),
        "- sums: %s" % " ".join("%s=%s" % (f, numstr(sums[f])) for f in SUM_FIELDS),
        "- tests: selected=%s run=%s passed=%s failed=%s" % (
            numstr(tests["tests_selected"]), numstr(tests["tests_run"]),
            numstr(tests["tests_passed"]), numstr(tests["tests_failed"])),
        "- wall_clock_sec: sum=%s median=%s" % (numstr(sum(walls) if walls else 0), numstr(median(walls))),
    ]
    print("\n".join(out))
    return 0


# ---------------------------------------------------------------- self-test (hermetic; offline; out-of-tree ledger)
def _valid_record(**over):
    base = {
        "run_id": "run-0001", "goal_type": "docs-closure", "mode": "advisory", "effort": "light",
        "context_files_count": 3, "estimated_input_tokens": 1200, "estimated_output_tokens": 400,
        "tool_calls": 7, "wall_clock_sec": 42.5, "files_touched": 1, "tests_selected": 10,
        "tests_run": 10, "tests_passed": 10, "tests_failed": 0, "review_findings_total": 0,
        "blockers": 0, "retry_count": 0, "human_gates": 2, "outcome": "completed",
        "efficiency_notes": "clean",
    }
    base.update(over)
    return base


def _write_json(path, obj):
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(obj, fh)


def _record_captured(from_path, ledger):
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        rc = cmd_record(from_path, ledger)
    return rc


def _rollup_captured(ledger):
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        cmd_rollup(ledger)
    return buf.getvalue()


def _read_bytes(path):
    if not os.path.exists(path):
        return b""
    with open(path, "rb") as fh:
        return fh.read()


def _operative_source():
    # This file's operative source with the audit sentinel region and all full-line comments
    # removed, so the offline audit never self-matches its own forbidden-token literals (mirrors
    # the frozen family's AC6). Markers are assembled from fragments so the detection code itself
    # does not carry the contiguous sentinel and toggle on its own lines.
    tok_start = "AUDIT_BLOCK" "_START"
    tok_end = "AUDIT_BLOCK" "_END"
    keep = []
    in_block = False
    with open(SELF, encoding="utf-8") as fh:
        for ln in fh.read().splitlines():
            if tok_start in ln:
                in_block = True
                continue
            if tok_end in ln:
                in_block = False
                continue
            if in_block:
                continue
            if ln.lstrip().startswith("#"):
                continue
            keep.append(ln)
    return "\n".join(keep)


def run_self_test():
    print("==== DMC RUN-METRICS RECORDER — SELF-TEST ====")
    P = [0]
    F = [0]

    def ok(m):
        print("  PASS " + m)
        P[0] += 1

    def no(m):
        print("  FAIL " + m)
        F[0] += 1

    work = tempfile.mkdtemp(prefix="dmc-metrics-selftest-")
    okj = os.path.join(work, "ok.json")
    ledger = os.path.join(work, "ledger.jsonl")
    _write_json(okj, _valid_record())

    # AC1a: a valid record appends exactly 1 valid-JSON line carrying ALL REQ fields.
    rc = _record_captured(okj, ledger)
    lines = _read_bytes(ledger).decode("utf-8").splitlines()
    line1 = lines[0] if lines else ""
    try:
        parsed = json.loads(line1)
    except Exception:
        parsed = None
    if rc == 0 and len(lines) == 1 and isinstance(parsed, dict) \
            and set(parsed.keys()) == set(REQ) and len(parsed.keys()) == len(REQ):
        ok("AC1a valid record => exactly 1 valid-JSON line carrying all %d REQ fields" % len(REQ))
    else:
        no("AC1a valid append (rc=%s lines=%d)" % (rc, len(lines)))

    # AC1b: re-run appends (2 lines; first byte-identical).
    rc = _record_captured(okj, ledger)
    lines2 = _read_bytes(ledger).decode("utf-8").splitlines()
    if rc == 0 and len(lines2) == 2 and lines2[0] == line1:
        ok("AC1b re-run appends: 2 lines, first byte-identical (append-only)")
    else:
        no("AC1b re-run append (lines=%d, first-identical=%s)" % (len(lines2), lines2[:1] == [line1]))

    # AC1c: invalid record (missing field / bad enum / inconsistent counts) => non-zero + ledger byte-identical.
    before = _read_bytes(ledger)
    miss = _valid_record()
    del miss["tool_calls"]
    missj = os.path.join(work, "miss.json")
    _write_json(missj, miss)
    r1 = _record_captured(missj, ledger)
    badenum = os.path.join(work, "badenum.json")
    _write_json(badenum, _valid_record(mode="bogus"))
    r2 = _record_captured(badenum, ledger)
    badcount = os.path.join(work, "badcount.json")
    _write_json(badcount, _valid_record(tests_passed=99))
    r3 = _record_captured(badcount, ledger)
    if r1 != 0 and r2 != 0 and r3 != 0 and _read_bytes(ledger) == before:
        ok("AC1c invalid records (missing/bad-enum/inconsistent) REFUSED (non-zero); ledger byte-identical")
    else:
        no("AC1c fail-closed (rcs=%s/%s/%s, unchanged=%s)" % (r1, r2, r3, _read_bytes(ledger) == before))

    # AC2: redaction parity — planted secret shapes never survive into the ledger.
    leakj = os.path.join(work, "leak.json")
    leak_ledger = os.path.join(work, "leak-ledger.jsonl")
    _write_json(leakj, _valid_record(
        run_id="ghp_LEAKAAA0123456789ABCDEFGHIJKLMNOP",
        goal_type="deploy sk-LEAKKEY0123456789abcdefghijkl now",
        efficiency_notes="token ya29.LEAKPROVIDER0123 leaked here"))
    rc = _record_captured(leakj, leak_ledger)
    content = _read_bytes(leak_ledger).decode("utf-8")
    planted = ["ghp_LEAK", "sk-LEAKKEY", "ya29.LEAKPROVIDER"]
    if rc == 0 and "[redacted:unsafe-metadata]" in content and not any(p in content for p in planted):
        ok("AC2 redaction parity: run_id/goal_type/notes redacted; 0 raw secret shapes in the ledger")
    else:
        no("AC2 redaction (rc=%s, has-marker=%s)" % (rc, "[redacted:unsafe-metadata]" in content))

    # AC3: symlink ledger => REFUSED (no write to the target).
    target = os.path.join(work, "sym-target.jsonl")
    with open(target, "w", encoding="utf-8") as fh:
        fh.write("")
    linkpath = os.path.join(work, "sym-ledger.jsonl")
    os.symlink(target, linkpath)
    tbefore = _read_bytes(target)
    rc = _record_captured(okj, linkpath)
    if rc == 2 and _read_bytes(target) == tbefore:
        ok("AC3 symlink ledger => REFUSED (exit 2); target byte-identical")
    else:
        no("AC3 symlink guard (rc=%s, target-unchanged=%s)" % (rc, _read_bytes(target) == tbefore))

    # AC4: rollup exact aggregate over 3 rows + determinism + skipped_malformed on a 4th malformed line.
    agg_ledger = os.path.join(work, "agg-ledger.jsonl")
    r_a = os.path.join(work, "a.json")
    r_b = os.path.join(work, "b.json")
    r_c = os.path.join(work, "c.json")
    _write_json(r_a, _valid_record(effort="light", mode="advisory", outcome="completed",
                                   retry_count=0, human_gates=2, blockers=0, review_findings_total=0,
                                   tests_selected=10, tests_run=10, tests_passed=10, tests_failed=0,
                                   wall_clock_sec=42.5))
    _write_json(r_b, _valid_record(effort="deep", mode="autonomous-local-commit", outcome="partial",
                                   retry_count=1, human_gates=1, blockers=1, review_findings_total=2,
                                   tests_selected=5, tests_run=5, tests_passed=4, tests_failed=1,
                                   wall_clock_sec=10))
    _write_json(r_c, _valid_record(effort="light", mode="advisory", outcome="completed",
                                   retry_count=2, human_gates=0, blockers=0, review_findings_total=1,
                                   tests_selected=8, tests_run=8, tests_passed=8, tests_failed=0,
                                   wall_clock_sec=7.5))
    for f in (r_a, r_b, r_c):
        _record_captured(f, agg_ledger)
    roll = _rollup_captured(agg_ledger)
    expect = [
        "- row_count: 3",
        "- skipped_malformed: 0",
        "- by_outcome: completed=2 partial=1",
        "- by_effort: deep=1 light=2",
        "- by_mode: advisory=2 autonomous-local-commit=1",
        "- sums: retry_count=3 human_gates=3 blockers=1 review_findings_total=3",
        "- tests: selected=23 run=23 passed=22 failed=1",
        "- wall_clock_sec: sum=60 median=10",
    ]
    if all(e in roll for e in expect):
        ok("AC4a rollup exact aggregate over 3 rows")
    else:
        no("AC4a rollup aggregate\n----\n%s\n----" % roll)

    roll2 = _rollup_captured(agg_ledger)
    if roll == roll2:
        ok("AC4b rollup deterministic: two identical runs => byte-identical output")
    else:
        no("AC4b rollup non-deterministic")

    with open(agg_ledger, "a", encoding="utf-8") as fh:
        fh.write("{ this is not valid json ]\n")
    roll3 = _rollup_captured(agg_ledger)
    if "- row_count: 3" in roll3 and "- skipped_malformed: 1" in roll3:
        ok("AC4c malformed 4th line => skipped_malformed: 1, row_count still 3, no crash")
    else:
        no("AC4c malformed-line robustness\n----\n%s\n----" % roll3)

    # AC5: structural offline self-audit (mirrors the frozen family's AC6). The forbidden-token
    # regex AND the token-enumerating result message both live inside the sentinel region so the
    # audit never matches its own literals in the operative source.
    op = _operative_source()
    # >>>AUDIT_BLOCK_START
    forbidden = r'os\.environ|getenv|printenv|socket|urllib|requests|\bcurl\b|\bwget\b|--live|--allow-network'
    audit_hit = re.search(forbidden, op)
    if audit_hit is None and os.path.basename(VALIDATOR).startswith("dmc-v0.5.0-run-metrics"):
        ok("AC5 offline posture: no env-read/socket/urllib/requests/curl/wget/--live in the operative source; sole subprocess target is the pinned frozen validator")
    else:
        no("AC5 offline audit (hit=%r)" % (audit_hit and audit_hit.group(0)))
    # >>>AUDIT_BLOCK_END

    print("  ---- self-test: PASS=%d FAIL=%d ----" % (P[0], F[0]))
    return 0 if F[0] == 0 else 1


def print_usage():
    print("usage: dmc-metrics-recorder.py record --from <record.json> [--ledger <path>]")
    print("       dmc-metrics-recorder.py rollup [--ledger <path>]")
    print("       dmc-metrics-recorder.py --self-test")


def _opt(rest, i, name):
    if i + 1 >= len(rest):
        err("%s: %s requires a value" % (rest[0] if rest else "?", name))
        return None
    return rest[i + 1]


def main(argv):
    if not argv:
        print_usage()
        return 2
    cmd = argv[0]
    rest = argv[1:]
    if cmd in ("--self-test", "self-test", "selftest"):
        return run_self_test()
    if cmd in ("-h", "--help", "help"):
        print_usage()
        return 0
    if cmd == "record":
        from_path = None
        ledger = None
        i = 0
        while i < len(rest):
            a = rest[i]
            if a == "--from":
                if i + 1 >= len(rest):
                    err("record: --from requires a value")
                    return 2
                from_path = rest[i + 1]
                i += 2
            elif a == "--ledger":
                if i + 1 >= len(rest):
                    err("record: --ledger requires a value")
                    return 2
                ledger = rest[i + 1]
                i += 2
            else:
                err("record: unknown arg %s" % a)
                return 2
        if not from_path:
            err("record: --from <record.json> required")
            return 2
        return cmd_record(from_path, ledger)
    if cmd == "rollup":
        ledger = None
        i = 0
        while i < len(rest):
            a = rest[i]
            if a == "--ledger":
                if i + 1 >= len(rest):
                    err("rollup: --ledger requires a value")
                    return 2
                ledger = rest[i + 1]
                i += 2
            else:
                err("rollup: unknown arg %s" % a)
                return 2
        return cmd_rollup(ledger)
    err("unknown command: %s (record|rollup|self-test)" % cmd)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
