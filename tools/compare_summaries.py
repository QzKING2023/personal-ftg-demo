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


def main(argv=None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("left")
    parser.add_argument("right")
    parser.add_argument("--exclude", nargs="*", default=[],
                        help="extra field names to skip, added to the default timing exclusions")
    args = parser.parse_args(argv)
    exclude = set(DEFAULT_EXCLUDE) | set(args.exclude)
    diffs = []
    walk(load(args.left), load(args.right), "$", exclude, diffs)
    if diffs:
        for line in diffs:
            print(line)
        print("DIFF: %d mismatching field(s)" % len(diffs))
        return 1
    print("OK: summaries equal (excluding %s)" % ", ".join(sorted(exclude)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
