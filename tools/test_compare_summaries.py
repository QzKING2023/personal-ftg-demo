#!/usr/bin/env python3
"""Unit tests for compare_summaries Tier B mode (ticket 06, ADR-0006 rev4)."""

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import compare_summaries as cs


def _row(test, solver_calls=0, hits=0, misses=0, bypasses=0, keys=None, cache_entries=5):
    return {
        "test": test,
        "exit": 0,
        "script_errors": 0,
        "pass_lines": 2,
        "assertions": 2,
        "seconds": 1.0,
        "solver_calls": solver_calls,
        "solver_underlying_calls": solver_calls,
        "solver_reuse_hits": 0,
        "solver_reuse_hit_rate": 0.0,
        "solver_elapsed_ms": 1.0,
        "combo_cache": {"enabled": True, "entries": cache_entries, "hits": hits,
                        "misses": misses, "bypasses": bypasses},
        "solver_profile": {"requests": solver_calls, "delay_leaf_runs": solver_calls * 10},
        "report_fingerprints": ["fp-a", "fp-b"],
        "solver_report_keys": keys if keys is not None else [["k1"], ["k2"]],
        "appdata": "X:/appdata-" + test,
    }


def _summary(mode, **row_overrides):
    row = _row("test_x", **row_overrides)
    return {
        "mode": mode,
        "total_seconds": 5.0,
        "total_assertions": row["assertions"],
        "total_solver_calls": row["solver_calls"],
        "total_solver_underlying_calls": row["solver_calls"],
        "total_solver_reuse_hits": 0,
        "solver_reuse_hit_rate": 0.0,
        "tests": [row],
    }


def _write(tmp, name, payload):
    path = Path(tmp) / name
    path.write_text(json.dumps(payload), encoding="utf-8")
    return str(path)


class TierBTests(unittest.TestCase):
    def _gate(self, left, right, *extra):
        with tempfile.TemporaryDirectory() as tmp:
            return cs.main([_write(tmp, "l.json", left), _write(tmp, "r.json", right)] + list(extra))

    def test_hot_vs_cold_passes_tier_b_but_fails_plain(self):
        cold = _summary("acceptance-reuse", solver_calls=3, hits=1, misses=2, cache_entries=3)
        hot = _summary("acceptance-reuse", solver_calls=3, hits=3, misses=0, cache_entries=3)
        self.assertEqual(self._gate(cold, hot), 1)
        self.assertEqual(self._gate(cold, hot, "--tier-b"), 0)

    def test_tier_b_flags_broken_hit_miss_invariant(self):
        good = _summary("acceptance-reuse", solver_calls=3, hits=1, misses=2)
        bypassed = _summary("acceptance-reuse", solver_calls=3, hits=1, misses=1)
        with tempfile.TemporaryDirectory() as tmp:
            import contextlib
            import io
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                code = cs.main([_write(tmp, "l.json", good), _write(tmp, "r.json", bypassed), "--tier-b"])
        self.assertEqual(code, 1)
        self.assertIn("hits+misses", out.getvalue())

    def test_tier_b_accepts_refused_load_bypass_accounting(self):
        # smoke-shaped job: one refused-manifest request counted as a bypass.
        refused = _summary("acceptance-reuse", solver_calls=1, hits=0, misses=0, bypasses=1)
        self.assertEqual(self._gate(refused, refused, "--tier-b"), 0)

    def test_tier_b_compares_report_keys_field_by_field(self):
        left = _summary("acceptance-reuse", keys=[["a"], ["b"]])
        right = _summary("acceptance-reuse", keys=[["a"], ["c"]])
        self.assertEqual(self._gate(left, right, "--tier-b"), 1)

    def test_no_solver_calls_rows_skip_invariant(self):
        left = _summary("acceptance-reuse", solver_calls=0, hits=0, misses=0, cache_entries=0)
        right = _summary("acceptance-reuse", solver_calls=0, hits=0, misses=0, cache_entries=0)
        self.assertEqual(self._gate(left, right, "--tier-b"), 0)

    def test_invariant_side_right_tolerates_frozen_baseline(self):
        # A pre-fix baseline (e.g. the 0/0/0 analyze-entry anomaly) on the left
        # must not fail the gate when only the current side is under invariant.
        current = _summary("acceptance-reuse", solver_calls=3, hits=1, misses=2)
        frozen = _summary("acceptance-reuse", solver_calls=3, hits=0, misses=0, cache_entries=0)
        with tempfile.TemporaryDirectory() as tmp:
            import contextlib
            import io
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                code = cs.main([_write(tmp, "l.json", frozen), _write(tmp, "r.json", current),
                                "--tier-b", "--invariant-side", "right"])
        self.assertEqual(code, 0)
        # Default (both) still flags the frozen side.
        with tempfile.TemporaryDirectory() as tmp:
            code = cs.main([_write(tmp, "l.json", frozen), _write(tmp, "r.json", current), "--tier-b"])
        self.assertEqual(code, 1)


if __name__ == "__main__":
    unittest.main()
