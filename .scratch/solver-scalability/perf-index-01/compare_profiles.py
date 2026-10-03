#!/usr/bin/env python3
"""Compare per-request solver fingerprints between two acceptance metric logs.

Usage: python compare_profiles.py <baseline.log> <candidate.log>
Extracts the ACCEPTANCE_SOLVER_METRICS_JSON line from each log, builds
key -> fingerprint maps from the profiles array, and reports:
  - requests missing in either direction
  - fingerprint mismatches per key
  - final verdict (exit code 0 = identical per-request fingerprints)
"""
import json
import re
import sys


def load_profiles(path):
    text = open(path, encoding="utf-8", errors="replace").read()
    matches = re.findall(r"^ACCEPTANCE_SOLVER_METRICS_JSON=(\{.*\})$", text, re.MULTILINE)
    if not matches:
        raise SystemExit(f"no ACCEPTANCE_SOLVER_METRICS_JSON line in {path}")
    payload = json.loads(matches[-1])
    return {p["key"]: p["fingerprint"] for p in payload["profiles"]}, payload


def main():
    base_path, cand_path = sys.argv[1], sys.argv[2]
    base, base_payload = load_profiles(base_path)
    cand, cand_payload = load_profiles(cand_path)
    only_base = sorted(set(base) - set(cand))
    only_cand = sorted(set(cand) - set(base))
    mismatches = sorted(k for k in set(base) & set(cand) if base[k] != cand[k])
    print(f"baseline requests: {len(base)}  candidate requests: {len(cand)}")
    print(f"only in baseline: {only_base}")
    print(f"only in candidate: {only_cand}")
    print(f"fingerprint mismatches: {mismatches}")
    unique_base = {v for v in base.values()}
    unique_cand = {v for v in cand.values()}
    print(f"unique fingerprints baseline={len(unique_base)} candidate={len(unique_cand)} "
          f"set_equal={unique_base == unique_cand}")
    ok = not only_base and not only_cand and not mismatches
    print("PASS per-request fingerprints identical" if ok else "FAIL fingerprint drift detected")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
