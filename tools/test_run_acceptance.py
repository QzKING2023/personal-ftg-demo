#!/usr/bin/env python3
"""Unit tests for the acceptance orchestrator scheduling seam (ticket 02).

External-behavior tests only: canonical job order, import barrier, concurrency
cap, failure predicate, serial mode. run_job is stubbed; nothing launches Godot.
"""

import contextlib
import io
import json
import os
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

    def __init__(self, delays, exit_failures=(), script_error_jobs=(), descriptors=None):
        self.delays = delays
        self.exit_failures = set(exit_failures)
        self.script_error_jobs = set(script_error_jobs)
        self.descriptors = descriptors or {}
        self.enumerated = []
        self.lock = threading.Lock()
        self.events = []  # (name, kind, perf_counter)
        self.active = 0
        self.max_active = 0

    def __call__(self, job, engine, project_root, log_root, no_reuse, cache=None,
                 enumerate_to=None):
        name = job["name"]
        with self.lock:
            self.active += 1
            self.max_active = max(self.max_active, self.active)
        started = time.perf_counter()
        with self.lock:
            self.events.append((name, "start", started))
        if enumerate_to is not None:
            # Behave like the real enumeration pass: emit the job's descriptor file.
            enumerate_to.parent.mkdir(parents=True, exist_ok=True)
            lines = []
            for digest in self.descriptors.get(name, []):
                lines.append(json.dumps({"digest": digest, "descriptor": "D1:[S%d:%s;];" % (len(digest), digest)}))
            enumerate_to.write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8")
            self.enumerated.append(name)
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
            "solver_report_keys": [],
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


class CachePlumbingTests(unittest.TestCase):
    """Ticket 06: persistent-cache env plumbing and lock-free fragment merge."""

    def test_job_env_sets_cache_vars_only_with_cache(self):
        with tempfile.TemporaryDirectory() as tmp:
            runtime = Path(tmp) / "runtime-test_x"
            cache = Path(tmp) / "cache" / "solver-results.cache"
            fragment = Path(tmp) / "out" / "cache-fragments" / "test_x.fragment"
            with mock.patch.dict(os.environ, {"APPDATA": "keep-out", "LOCALAPPDATA": "keep-out"}):
                env = ra._job_env(runtime, cache, fragment)
            self.assertEqual(env["APPDATA"], str(runtime))
            self.assertEqual(env[ra.CACHE_CANONICAL_ENV], str(cache))
            self.assertEqual(env[ra.CACHE_FRAGMENT_ENV], str(fragment))
            self.assertTrue(fragment.parent.is_dir(),
                            "the fragment directory is created before the job starts")
            env = ra._job_env(runtime, None, fragment)
            self.assertNotIn(ra.CACHE_CANONICAL_ENV, env)
            self.assertNotIn(ra.CACHE_FRAGMENT_ENV, env)

    def test_merge_unions_fragments_and_is_idempotent(self):
        with tempfile.TemporaryDirectory() as tmp:
            canonical = Path(tmp) / "cache" / "solver-results.cache"
            frag_dir = Path(tmp) / "run" / "cache-fragments"
            frag_dir.mkdir(parents=True)
            shared = json.dumps({"digest": "shared", "entry": "e-shared"})
            (frag_dir / "test_aaa.fragment").write_text(
                '{"schema": "%s", "version": 1}\n%s\n%s\n'
                % (ra.CACHE_HEADER["schema"], shared,
                   json.dumps({"digest": "aaa-only", "entry": "e-aaa"})), encoding="utf-8")
            (frag_dir / "test_bbb.fragment").write_text(
                '{"schema": "%s", "version": 1}\n%s\n'
                % (ra.CACHE_HEADER["schema"],
                   json.dumps({"digest": "bbb-only", "entry": "e-bbb"})), encoding="utf-8")
            stats = ra.merge_cache_fragments(canonical, frag_dir)
            self.assertEqual(stats["entries_after"], 3)
            self.assertEqual(stats["merged_new"], 3)
            first_bytes = canonical.read_bytes()
            # Re-merging the same fragments must change nothing (idempotent),
            # including byte order: canonical entries first, fragments sorted.
            stats2 = ra.merge_cache_fragments(canonical, frag_dir)
            self.assertEqual(stats2["merged_new"], 0)
            self.assertEqual(stats2["entries_after"], 3)
            self.assertEqual(canonical.read_bytes(), first_bytes)
            lines = canonical.read_text(encoding="utf-8").splitlines()
            self.assertEqual(json.loads(lines[0]), ra.CACHE_HEADER)
            self.assertEqual([json.loads(line)["digest"] for line in lines[1:]],
                             ["shared", "aaa-only", "bbb-only"])

    def test_merge_skips_corrupt_lines_and_rejects_foreign_header(self):
        with tempfile.TemporaryDirectory() as tmp:
            canonical = Path(tmp) / "cache" / "solver-results.cache"
            frag_dir = Path(tmp) / "run" / "cache-fragments"
            frag_dir.mkdir(parents=True)
            (frag_dir / "test_aaa.fragment").write_text(
                '{"schema": "%s", "version": 1}\n'
                '{"digest": "good", "entry": "e1"}\n'
                'not json at all\n'
                '{"digest": "", "entry": "empty digest"}\n'
                '{"digest": "no-entry"}\n'
                '{"unknown": "shape"}\n' % ra.CACHE_HEADER["schema"], encoding="utf-8")
            stats = ra.merge_cache_fragments(canonical, frag_dir)
            self.assertEqual(stats["entries_after"], 1)
            self.assertEqual(stats["fragments"][0]["bad_lines"], 4)
            (frag_dir / "test_bbb.fragment").write_text(
                '{"schema": "someone-elses", "version": 9}\n'
                '{"digest": "foreign", "entry": "e"}\n', encoding="utf-8")
            # A foreign-header fragment is dropped wholesale (same rule as the
            # Godot loader): its entries must not leak into the canonical file.
            stats = ra.merge_cache_fragments(canonical, frag_dir)
            self.assertEqual(stats["entries_after"], 1)
            foreign = Path(tmp) / "foreign.cache"
            foreign.write_text('{"schema": "old", "version": 0}\n'
                               '{"digest": "stale", "entry": "e"}\n', encoding="utf-8")
            entries, _, ok = ra._read_cache_file(foreign)
            self.assertFalse(ok)
            self.assertEqual(entries, {})

    def test_main_merges_only_when_reuse_enabled(self):
        recorder = Recorder(INVERTING_DELAYS)
        with tempfile.TemporaryDirectory() as tmp:
            output = str(Path(tmp) / "out")
            cache_path = str(Path(tmp) / "cache" / "solver-results.cache")
            with mock.patch.object(ra, "discover_jobs", return_value=[dict(j) for j in FAKE_JOBS]), \
                    mock.patch.object(ra, "run_job", recorder), \
                    mock.patch.object(ra, "merge_cache_fragments") as merge, \
                    contextlib.redirect_stdout(io.StringIO()):
                ra.main(["--output", output, "--cache", cache_path])
            self.assertEqual(merge.call_count, 1)
            self.assertEqual(merge.call_args[0][0], Path(cache_path))
        with tempfile.TemporaryDirectory() as tmp:
            output = str(Path(tmp) / "out")
            with mock.patch.object(ra, "discover_jobs", return_value=[dict(j) for j in FAKE_JOBS]), \
                    mock.patch.object(ra, "run_job", recorder), \
                    mock.patch.object(ra, "merge_cache_fragments") as merge, \
                    contextlib.redirect_stdout(io.StringIO()):
                ra.main(["--output", output, "--no-reuse"])
            merge.assert_not_called()


class SweepTests(unittest.TestCase):
    """Ticket 08: three-stage global pre-sweep orchestration (run_job stubbed)."""

    def run_sweep_cli(self, recorder, cli_args, task_mock=None, merge_mock=None,
                      want_summary=True):
        with tempfile.TemporaryDirectory() as tmp:
            output = str(Path(tmp) / "out")
            cache_path = str(Path(tmp) / "cache" / "solver-results.cache")
            patches = [
                mock.patch.object(ra, "discover_jobs", return_value=[dict(j) for j in FAKE_JOBS]),
                mock.patch.object(ra, "run_job", recorder),
            ]
            if task_mock is not None:
                patches.append(mock.patch.object(ra, "run_sweep_task", task_mock))
            if merge_mock is not None:
                patches.append(mock.patch.object(ra, "merge_cache_fragments", merge_mock))
            with contextlib.ExitStack() as stack:
                for patch in patches:
                    stack.enter_context(patch)
                stdout = io.StringIO()
                with contextlib.redirect_stdout(stdout):
                    code = ra.main(cli_args + ["--output", output, "--cache", cache_path])
            out = Path(output)
            summary = None
            if want_summary and (out / "summary.json").is_file():
                with open(out / "summary.json", encoding="utf-8-sig") as handle:
                    summary = json.load(handle)
            sweep = None
            if (out / "sweep.json").is_file():
                with open(out / "sweep.json", encoding="utf-8-sig") as handle:
                    sweep = json.load(handle)
            status = (out / "runner.status.txt").read_text(encoding="ascii").strip()
        return code, summary, sweep, status

    def test_sweep_conflicts_with_no_reuse(self):
        with self.assertRaises(SystemExit):
            ra.main(["--sweep", "--no-reuse", "--output", "unused"])

    def test_enumerate_stage_writes_no_summary_and_records_every_job(self):
        recorder = Recorder(INVERTING_DELAYS)
        code, summary, sweep, status = self.run_sweep_cli(
            recorder, ["--sweep", "--sweep-stage", "enumerate"], want_summary=False)
        self.assertEqual(code, 0)
        self.assertEqual(status, "exit=0")
        self.assertIsNone(summary)
        self.assertIsNotNone(sweep)
        self.assertEqual(sweep["mode"], "acceptance-sweep")
        self.assertEqual(sorted(sweep["enumerate"]["jobs"]),
                         sorted(CANONICAL[1:]))
        # Enumerate-only never reaches the sweep or warm stages.
        self.assertNotIn("sweep", sweep)
        self.assertNotIn("warm", sweep)
        # Import ran exactly once before any enumeration job.
        import_end = recorder.ends("import")
        for name in CANONICAL[1:]:
            self.assertGreaterEqual(recorder.starts(name), import_end)

    def test_full_sweep_runs_each_job_twice_and_reports_mode(self):
        recorder = Recorder(INVERTING_DELAYS)
        task_calls = []

        def fake_task(index, digest, descriptor, engine, project_root, sweep_root, cache):
            task_calls.append(digest)
            return {"digest": digest, "exit": 0, "seconds": 1.0,
                    "replay_ok": True, "log": "worker-%04d.log" % index}

        def fake_merge(canonical, fragment_dir, report_path=None):
            # Side effect of a real merge: the canonical now covers the digests.
            digests = sorted(set(task_calls))
            canonical.parent.mkdir(parents=True, exist_ok=True)
            lines = [json.dumps(ra.CACHE_HEADER)]
            lines += [json.dumps({"digest": d, "entry": "e"}) for d in digests]
            canonical.write_text("\n".join(lines) + "\n", encoding="utf-8")
            return {"entries_after": len(digests), "merged_new": len(digests),
                    "fragments": []}

        code, summary, sweep, status = self.run_sweep_cli(
            recorder, ["--sweep"], task_mock=fake_task, merge_mock=fake_merge)
        self.assertEqual(code, 0)
        self.assertEqual(status, "exit=0")
        self.assertEqual(summary["mode"], "acceptance-sweep")
        self.assertEqual([row["test"] for row in summary["tests"]], CANONICAL)
        # Every non-import job ran twice: once to enumerate, once warm.
        self.assertEqual(sorted(recorder.enumerated), sorted(CANONICAL[1:]))
        self.assertEqual(sum(1 for _ in recorder.enumerated), len(CANONICAL) - 1)
        twice = {name: 0 for name in CANONICAL}
        for name, kind, _ in recorder.events:
            if kind == "start":
                twice[name] += 1
        self.assertEqual(twice, {name: (2 if name != "import" else 1) for name in CANONICAL})
        self.assertIn("sweep", sweep)
        self.assertIn("warm", sweep)
        self.assertEqual(set(sweep["stage_walls"]), {"import", "enumerate", "sweep", "warm", "total"})

    def test_unique_descriptors_dedup_across_jobs_and_drive_sweep_tasks(self):
        # test_aaa and test_bbb share one digest; test_ccc adds another.
        recorder = Recorder(INVERTING_DELAYS, descriptors={
            "test_aaa": ["d1", "d1"],
            "test_bbb": ["d1"],
            "test_ccc": ["d0"],
        })
        task_calls = []

        def fake_task(index, digest, descriptor, engine, project_root, sweep_root, cache):
            task_calls.append(digest)
            return {"digest": digest, "exit": 0, "seconds": 0.5,
                    "replay_ok": True, "log": "worker-%04d.log" % index}

        def fake_merge(canonical, fragment_dir, report_path=None):
            digests = sorted(set(task_calls))
            canonical.parent.mkdir(parents=True, exist_ok=True)
            lines = [json.dumps(ra.CACHE_HEADER)]
            lines += [json.dumps({"digest": d, "entry": "e"}) for d in digests]
            canonical.write_text("\n".join(lines) + "\n", encoding="utf-8")
            return {"entries_after": len(digests), "merged_new": len(digests),
                    "fragments": []}

        code, summary, sweep, status = self.run_sweep_cli(
            recorder, ["--sweep"], task_mock=fake_task, merge_mock=fake_merge)
        self.assertEqual(code, 0)
        self.assertEqual(sweep["enumerate"]["requests_total"], 4)
        self.assertEqual(sweep["enumerate"]["unique_descriptors"], 2)
        # Tasks fan out over the deduplicated set in sorted (deterministic) order.
        self.assertEqual(task_calls, ["d0", "d1"])
        self.assertEqual(sweep["sweep"]["tasks"], 2)
        self.assertEqual(sweep["sweep"]["covered"], 2)
        self.assertEqual(sweep["sweep"]["gaps"], [])

    def test_sweep_gap_recorded_when_digest_missing_after_merge(self):
        recorder = Recorder(INVERTING_DELAYS, descriptors={"test_aaa": ["d1"]})

        def fake_task(index, digest, descriptor, engine, project_root, sweep_root, cache):
            return {"digest": digest, "exit": 0, "seconds": 0.5,
                    "replay_ok": False, "log": "worker-%04d.log" % index}

        def fake_merge(canonical, fragment_dir, report_path=None):
            # A merge that covers nothing (e.g. worker crashed before storing).
            canonical.parent.mkdir(parents=True, exist_ok=True)
            canonical.write_text(json.dumps(ra.CACHE_HEADER) + "\n", encoding="utf-8")
            return {"entries_after": 0, "merged_new": 0, "fragments": []}

        code, summary, sweep, status = self.run_sweep_cli(
            recorder, ["--sweep"], task_mock=fake_task, merge_mock=fake_merge)
        self.assertEqual(code, 0)
        self.assertEqual(sweep["sweep"]["covered"], 0)
        self.assertEqual(sweep["sweep"]["gaps"], ["d1"])

    def test_job_env_enumerate_plumbing(self):
        with tempfile.TemporaryDirectory() as tmp:
            runtime = Path(tmp) / "runtime-test_x"
            cache = Path(tmp) / "cache" / "solver-results.cache"
            fragment = Path(tmp) / "out" / "cache-fragments" / "test_x.fragment"
            enumerate_to = Path(tmp) / "out" / "sweep" / "descriptors" / "test_x.jsonl"
            env = ra._job_env(runtime, cache, fragment, enumerate_to)
            self.assertEqual(env[ra.SWEEP_ENUMERATE_ENV], str(enumerate_to))
            self.assertTrue(enumerate_to.parent.is_dir())
            env = ra._job_env(runtime, cache, fragment)
            self.assertNotIn(ra.SWEEP_ENUMERATE_ENV, env)

    def test_read_descriptor_file_skips_malformed_lines(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "job.jsonl"
            path.write_text("\n".join([
                json.dumps({"digest": "aaa", "descriptor": "text-a"}),
                "not json",
                json.dumps({"digest": "", "descriptor": "x"}),
                json.dumps({"digest": "bbb"}),
                json.dumps({"digest": "bbb", "descriptor": "text-b"}),
                json.dumps({"digest": "aaa", "descriptor": "text-a"}),
            ]) + "\n", encoding="utf-8")
            records = ra._read_descriptor_file(path)
            # Repeats are preserved in the sequence; dedup is the collector's job.
            self.assertEqual(records, [("aaa", "text-a"), ("bbb", "text-b"),
                                       ("aaa", "text-a")])
            unique = ra._collect_unique_descriptors({"job": records})
            self.assertEqual(list(unique), ["aaa", "bbb"])
            self.assertEqual(ra._read_descriptor_file(Path(tmp) / "missing.jsonl"), [])


if __name__ == "__main__":
    unittest.main()
