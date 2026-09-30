#!/usr/bin/env python3
"""Unit tests for the acceptance orchestrator scheduling seam (ticket 02).

External-behavior tests only: canonical job order, import barrier, concurrency
cap, failure predicate, serial mode. run_job is stubbed; nothing launches Godot.
"""

import contextlib
import io
import json
import sys
import tempfile
import threading
import time
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))

import run_acceptance as ra

FAKE_JOBS = [
    {"name": "import", "args": []},
    {"name": "test_aaa", "args": []},
    {"name": "test_bbb", "args": []},
    {"name": "test_ccc", "args": []},
    {"name": "diagnose_inputs", "args": []},
    {"name": "main-smoke", "args": []},
]
CANONICAL = [job["name"] for job in FAKE_JOBS]


class Recorder:
    """Stub run_job: tracks timeline and in-flight count, returns a row."""

    def __init__(self, delays, exit_failures=(), script_error_jobs=()):
        self.delays = delays
        self.exit_failures = set(exit_failures)
        self.script_error_jobs = set(script_error_jobs)
        self.lock = threading.Lock()
        self.events = []  # (name, kind, perf_counter)
        self.active = 0
        self.max_active = 0

    def __call__(self, job, engine, project_root, log_root, no_reuse):
        name = job["name"]
        with self.lock:
            self.active += 1
            self.max_active = max(self.max_active, self.active)
        started = time.perf_counter()
        with self.lock:
            self.events.append((name, "start", started))
        time.sleep(self.delays.get(name, 0.01))
        finished = time.perf_counter()
        with self.lock:
            self.active -= 1
            self.events.append((name, "end", finished))
        return {
            "test": name,
            "exit": 1 if name in self.exit_failures else 0,
            "script_errors": 1 if name in self.script_error_jobs else 0,
            "pass_lines": 1,
            "assertions": 1,
            "seconds": round(finished - started, 2),
            "solver_calls": 0,
            "solver_underlying_calls": 0,
            "solver_reuse_hits": 0,
            "solver_reuse_hit_rate": 0.0,
            "solver_elapsed_ms": 0.0,
            "combo_cache": {},
            "solver_profile": {},
            "report_fingerprints": [],
            "appdata": "stub",
        }

    def starts(self, name):
        return [t for n, kind, t in self.events if n == name and kind == "start"][0]

    def ends(self, name):
        return [t for n, kind, t in self.events if n == name and kind == "end"][0]


def run_orchestrator(recorder, cli_args):
    with tempfile.TemporaryDirectory() as tmp:
        output = str(Path(tmp) / "out")
        with mock.patch.object(ra, "discover_jobs", return_value=[dict(j) for j in FAKE_JOBS]), \
                mock.patch.object(ra, "run_job", recorder), \
                contextlib.redirect_stdout(io.StringIO()):
            code = ra.main(cli_args + ["--output", output])
        with open(Path(output) / "summary.json", encoding="utf-8-sig") as handle:
            summary = json.load(handle)
        status = (Path(output) / "runner.status.txt").read_text(encoding="ascii").strip()
    return code, summary, status


# Delays chosen so completion order inverts canonical order (aaa longest).
INVERTING_DELAYS = {"import": 0.2, "test_aaa": 0.3, "test_bbb": 0.05,
                    "test_ccc": 0.12, "diagnose_inputs": 0.02, "main-smoke": 0.02}


class SchedulingTests(unittest.TestCase):

    def test_summary_keeps_canonical_order_despite_out_of_order_completion(self):
        recorder = Recorder(INVERTING_DELAYS)
        code, summary, status = run_orchestrator(recorder, ["--concurrency", "8"])
        self.assertEqual([row["test"] for row in summary["tests"]], CANONICAL)
        self.assertEqual(code, 0)
        self.assertEqual(status, "exit=0")
        self.assertEqual(summary["total_assertions"], len(FAKE_JOBS))

    def test_import_barrier_holds_before_any_test_job_starts(self):
        recorder = Recorder(INVERTING_DELAYS)
        run_orchestrator(recorder, ["--concurrency", "8"])
        import_end = recorder.ends("import")
        for name in CANONICAL[1:]:
            self.assertGreaterEqual(recorder.starts(name), import_end,
                                    "%s started before import finished" % name)

    def test_concurrency_cap_is_respected(self):
        recorder = Recorder(dict.fromkeys(CANONICAL[1:], 0.05))
        run_orchestrator(recorder, ["--concurrency", "2"])
        self.assertLessEqual(recorder.max_active, 2)

    def test_default_concurrency_fans_out(self):
        recorder = Recorder(dict.fromkeys(CANONICAL[1:], 0.06))
        run_orchestrator(recorder, [])
        # Import runs alone, then all five test jobs must overlap in the pool.
        self.assertGreaterEqual(recorder.max_active, 3)

    def test_serial_mode_never_overlaps(self):
        recorder = Recorder(INVERTING_DELAYS)
        run_orchestrator(recorder, ["--serial"])
        self.assertLessEqual(recorder.max_active, 1)

    def test_jobs_alias_selects_serial(self):
        recorder = Recorder(INVERTING_DELAYS)
        run_orchestrator(recorder, ["--jobs", "1"])
        self.assertLessEqual(recorder.max_active, 1)

    def test_failure_predicate_exit_code(self):
        recorder = Recorder(INVERTING_DELAYS, exit_failures=["test_bbb"])
        code, _, status = run_orchestrator(recorder, ["--concurrency", "4"])
        self.assertEqual(code, 1)
        self.assertEqual(status, "exit=1")

    def test_failure_predicate_script_errors(self):
        recorder = Recorder(INVERTING_DELAYS, script_error_jobs=["test_ccc"])
        code, _, status = run_orchestrator(recorder, ["--concurrency", "4"])
        self.assertEqual(code, 1)
        self.assertEqual(status, "exit=1")


if __name__ == "__main__":
    unittest.main()
