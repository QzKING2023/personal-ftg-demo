#!/usr/bin/env python3
"""Compare two acceptance summary.json files field by field.

Used by the differential gates (ticket 01: PS-serial vs Python-serial; ticket 02:
parallel vs serial). Numeric fields are compared by value (0 == 0.0); keys listed
in --exclude are skipped wherever they appear (e.g. `seconds`, `total_seconds`).
Exit code 0 means equal.
"""

import argparse
import io
import json
import sys

# `seconds`/`total_seconds`/`solver_elapsed_ms` are wall-clock measurements:
# two runs of the SAME runner produce different values, so gates exclude them.
# Solver profile *_ms fields (ticket 03 instrumentation) are the same class of
# wall-clock measurements; the *_runs counts stay comparable.
DEFAULT_EXCLUDE = ("seconds", "total_seconds", "solver_elapsed_ms",
                   "total_ms", "delay_leaf_ms", "edge_probe_ms",
                   "gap_enum_ms", "route_walk_ms", "other_ms")

# Tier B (ADR-0006 rev4, ticket 06): cross-mode comparisons (dedup fix, hot
# cache, sweep vs cold serial baseline) additionally exclude cache/profiling
# counters and identity fields, and check structural invariants instead:
# hits+misses+bypasses == solver_calls per Solver job (complete cache accounting
# — bypasses are refused/unkeyable requests that never consult the cache; the
# ADR's hits+misses==calls is the bypasses==0 special case), and the
# fingerprint/keys mapping (report_fingerprints / solver_report_keys) compared
# field by field by walk().
TIER_B_EXCLUDE = ("combo_cache", "solver_profile", "mode", "appdata")


def load(path: str):
    with io.open(path, "r", encoding="utf-8-sig") as handle:
        return json.load(handle)


def _collapsed_equal(a, b) -> bool:
    # PS 5.1 ConvertTo-Json collapses empty arrays to {} and single-element
    # arrays to a bare scalar; the semantic value is the same.
    if isinstance(a, (dict, list)) and isinstance(b, (dict, list)):
        return not a and not b
    for x, y in ((a, b), (b, a)):
        if isinstance(x, list) and not isinstance(y, (dict, list)):
            return len(x) == 1 and x[0] == y
    return False


def walk(a, b, path: str, exclude: set, diffs: list) -> None:
    if _collapsed_equal(a, b):
        return
    if isinstance(a, dict) and isinstance(b, dict):
        for key in sorted(set(a) | set(b)):
            if key in exclude:
                continue
            if key not in a or key not in b:
                diffs.append("%s.%s: present only in %s" % (path, key, "left" if key not in b else "right"))
            else:
                walk(a[key], b[key], "%s.%s" % (path, key), exclude, diffs)
    elif isinstance(a, list) and isinstance(b, list):
        if len(a) != len(b):
            diffs.append("%s: length %d != %d" % (path, len(a), len(b)))
        for i, (x, y) in enumerate(zip(a, b)):
            walk(x, y, "%s[%d]" % (path, i), exclude, diffs)
    elif a != b:
        diffs.append("%s: %r != %r" % (path, a, b))


def _tier_b_invariants(summary, side: str, diffs: list) -> None:
    for row in summary.get("tests", []):
        calls = row.get("solver_calls", 0) or 0
        cache = row.get("combo_cache") or {}
        hits = cache.get("hits", 0) or 0
        misses = cache.get("misses", 0) or 0
        bypasses = cache.get("bypasses", 0) or 0
        if calls > 0 and hits + misses + bypasses != calls:
            diffs.append("%s.tests[%s]: combo_cache hits+misses+bypasses=%d "
                         "(hits=%d misses=%d bypasses=%d) != solver_calls=%d"
                         % (side, row.get("test"), hits + misses + bypasses,
                            hits, misses, bypasses, calls))


def main(argv=None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("left")
    parser.add_argument("right")
    parser.add_argument("--exclude", nargs="*", default=[],
                        help="extra field names to skip, added to the default timing exclusions")
    parser.add_argument("--tier-b", action="store_true",
                        help="cross-mode gate (ADR-0006 rev4): additionally exclude "
                             "combo_cache/solver_profile/mode/appdata and require "
                             "hits+misses+bypasses == solver_calls per Solver job")
    parser.add_argument("--invariant-side", choices=("both", "left", "right"), default="both",
                        help="which side(s) the tier B accounting invariant applies to; a frozen "
                             "pre-fix baseline legitimately violates it, so baseline comparisons "
                             "check only the current side (right)")
    args = parser.parse_args(argv)
    exclude = set(DEFAULT_EXCLUDE) | set(args.exclude)
    if args.tier_b:
        exclude |= set(TIER_B_EXCLUDE)
    diffs = []
    left = load(args.left)
    right = load(args.right)
    walk(left, right, "$", exclude, diffs)
    if args.tier_b:
        if args.invariant_side in ("both", "left"):
            _tier_b_invariants(left, "left", diffs)
        if args.invariant_side in ("both", "right"):
            _tier_b_invariants(right, "right", diffs)
    if diffs:
        for line in diffs:
            print(line)
        print("DIFF: %d mismatching field(s)" % len(diffs))
        return 1
    print("OK: summaries equal (excluding %s)%s"
          % (", ".join(sorted(exclude)), " [tier B]" if args.tier_b else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
