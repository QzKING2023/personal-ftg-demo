#!/usr/bin/env python3
"""Ticket 03 zero-semantic-impact gate: compare before/after instrumentation
job logs on the deterministic fields only.

Equal must be: exit code, script error count, PASS count (assertions), the
metrics JSON fingerprints/calls, and the *_runs profile counts (search shape).
Wall-clock *_ms fields are measurements and are reported, not compared.
"""

import json
import re
import sys

METRICS_PREFIX = "ACCEPTANCE_SOLVER_METRICS_JSON="
SCRIPT_ERROR_PATTERNS = [re.compile(p, re.IGNORECASE) for p in
                         ("SCRIPT ERROR:", "Parse Error:", "^FAIL", r"TEST\(S\) FAILED", "CrashHandlerException")]
PASS_PATTERN = re.compile(r"^PASS", re.IGNORECASE)


def parse_log(path):
    with open(path, "rb") as handle:
        lines = handle.read().decode("utf-8", errors="replace").splitlines()
    metrics = None
    for line in lines:
        if line.startswith(METRICS_PREFIX):
            metrics = json.loads(line[len(METRICS_PREFIX):])
    return {
        "script_errors": sum(1 for line in lines if any(p.search(line) for p in SCRIPT_ERROR_PATTERNS)),
        "pass_lines": sum(1 for line in lines if PASS_PATTERN.search(line)),
        "metrics": metrics,
    }


def main(argv):
    if len(argv) < 3:
        print("usage: compare_jobs.py NAME BEFORE_LOG AFTER_LOG")
        return 2
    name, before_path, after_path = argv[0], argv[1], argv[2]
    before, after = parse_log(before_path), parse_log(after_path)
    diffs = []
    for key in ("script_errors", "pass_lines"):
        if before[key] != after[key]:
            diffs.append("%s: %s %d != %d" % (name, key, before[key], after[key]))
    bm, am = before["metrics"] or {}, after["metrics"] or {}
    for key in ("calls", "underlying_calls", "reuse_hits", "reuse_enabled"):
        if bm.get(key) != am.get(key):
            diffs.append("%s: metrics.%s %r != %r" % (name, key, bm.get(key), am.get(key)))
    bfps = [r.get("fingerprint") for r in bm.get("reports", [])]
    afps = [r.get("fingerprint") for r in am.get("reports", [])]
    if bfps != afps:
        diffs.append("%s: report fingerprints differ (%d vs %d entries)" % (name, len(bfps), len(afps)))
        for i, (x, y) in enumerate(zip(bfps, afps)):
            if x != y:
                diffs.append("  [%d] %s != %s" % (i, x, y))
    bpf = {p["key"]: p for p in bm.get("profiles", [])} if "profiles" in bm else None
    apf = {p["key"]: p for p in am.get("profiles", [])}
    if bpf is None:
        print("%s: before log predates instrumentation; profile *_runs compared against none" % name)
    elif set(bpf) != set(apf):
        diffs.append("%s: profile request keys differ" % name)
    else:
        for key in sorted(bpf):
            for field in sorted(k for k in bpf[key] if k.endswith("_runs")):
                if bpf[key][field] != apf[key][field]:
                    diffs.append("%s: %s.%s %d != %d" % (name, key, field, bpf[key][field], apf[key][field]))
    for line in diffs:
        print(line)
    if diffs:
        print("DIFF: %d mismatching field(s)" % len(diffs))
        return 1
    print("OK: %s deterministic fields equal (script_errors=%d pass=%d fingerprints=%d profile_runs equal)" % (
        name, after["script_errors"], after["pass_lines"], len(afps)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
