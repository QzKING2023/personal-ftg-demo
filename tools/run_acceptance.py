#!/usr/bin/env python3
"""Acceptance orchestrator (serial and parallel modes).

Output-contract clone of tools/run_acceptance.ps1 (kept as differential baseline
and fallback): same job set and canonical order, same per-job APPDATA isolation,
same failure predicate, same summary.json schema and runner.status.txt contract.

Parallel mode (ticket 02): the import job runs alone first (it writes the shared
import-cache directory), then the remaining jobs fan out over a thread pool with
--concurrency workers (default 8). Summary.json always reports jobs in canonical
order regardless of completion order; stdout emits one compact JSON line per job
completion in completion order (each line carries its job name).

Worker pool (P6): --sweep defaults to reusable engine processes
(tools/solver_pool_worker.gd) pulling one deduplicated request at a time, with
per-request heartbeat/stage counters (heartbeat.json), pause checkpoints
(P5 resume snapshots) enabling single-request restart-resume, longest-job-first
dispatch (durations sidecar next to the cache) and slow quarantine. Every
request ends complete / incomplete / failed; a killed worker can never be
counted as complete — speed comes only from lane saturation and engine reuse,
never from truncating solver search, altering report caps or hiding timeouts.
'--sweep-mode spawn' keeps the ticket-08 one-process-per-request path as the
differential oracle.

Log capture differs mechanically: PS `*>` writes UTF-16LE while we capture raw
engine stdout (UTF-8); the diff gate compares parsed count fields, not bytes.
"""

import argparse
import json
import os
import re
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

DEFAULT_ENGINE = "D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe"
DEFAULT_OUTPUT = ".scratch/ftg-combat-foundation/acceptance-2026-09-17/final"
METRICS_PREFIX = "ACCEPTANCE_SOLVER_METRICS_JSON="
# Persistent solver result cache (ticket 06): canonical file plus per-job
# fragments under <output>/cache-fragments/, merged back at run end. The Godot
# side loads/reads via these env vars; --no-reuse sets neither and skips merge.
CACHE_CANONICAL_ENV = "FTG_SOLVER_RESULT_CACHE"
CACHE_FRAGMENT_ENV = "FTG_SOLVER_RESULT_CACHE_FRAGMENT"
CACHE_HEADER = {"schema": "ftg-demo-solver-result-cache", "version": 1}
DEFAULT_CACHE_RELATIVE = ".cache/acceptance/solver-results.cache"
# Global pre-sweep (ticket 08): three stages — enumerate (stub mode, per-job
# descriptor files, all outputs discarded) → unique requests fan out to one
# worker process each over the same lanes → every job runs again warm against
# the merged canonical cache. The enumerate switch is orchestrator-internal
# (env only, never an acceptance argument); --sweep-stage enumerate stops after
# the enumeration pass so the determinism gate can run it twice and diff.
SWEEP_ENUMERATE_ENV = "FTG_SOLVER_ENUMERATE"
SWEEP_TASK_FILE_ENV = "FTG_SWEEP_TASK_FILE"
SWEEP_WORKER_SCRIPT = "res://tools/solver_sweep_worker.gd"
SWEEP_WORKER_RESULT_PREFIX = "SWEEP_WORKER_RESULT="
# Reusable worker pool (P6): long-lived engine processes pull one request at a
# time from an assignment file; per-request heartbeat/stage counters flow
# through heartbeat.json (mtime + progress tuple drive stall/no-progress kills);
# checkpoints (<digest>.json snapshots) make single-request restart resume
# instead of recompute. Machine channel is file-based; stdout stays human-only.
POOL_CONTROL_ENV = "FTG_POOL_CONTROL_DIR"
POOL_WATCHDOG_ENV = "FTG_SOLVER_WATCHDOG_MS"
POOL_WORKER_SCRIPT = "res://tools/solver_pool_worker.gd"
POOL_POLL_SECONDS = 0.2
POOL_STOP_GRACE_SECONDS = 30.0

# Godot script errors can abort a single test function while the process still
# exits 0, so the log must be scanned separately. Select-String is
# case-insensitive by default; keep that so counts match the PS baseline.
SCRIPT_ERROR_PATTERNS = [
    re.compile(p, re.IGNORECASE)
    for p in ("SCRIPT ERROR:", "Parse Error:", "^FAIL", r"TEST\(S\) FAILED", "CrashHandlerException")
]
PASS_PATTERN = re.compile(r"^PASS", re.IGNORECASE)
METRICS_LINE = re.compile(r"^" + re.escape(METRICS_PREFIX), re.IGNORECASE)


def discover_jobs(project_root: Path) -> list:
    jobs = [{"name": "import", "args": ["--editor", "--quit"]}]
    tests_dir = project_root / "tests"
    for entry in sorted(tests_dir.glob("test_*.gd"), key=lambda p: p.name.lower()):
        jobs.append({"name": entry.stem, "args": ["-s", "res://tests/%s" % entry.name]})
    jobs.append({"name": "diagnose_inputs", "args": ["-s", "res://tests/diagnose_inputs.gd"]})
    jobs.append({"name": "main-smoke", "args": ["--quit-after", "300"]})
    return jobs


def _int0(value) -> int:
    # Mirrors PS [int] casts: null/missing counts coerce to 0, never fail loudly.
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0


def _float0(value) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0.0


def read_log_lines(path: Path) -> list:
    data = path.read_bytes()
    return data.decode("utf-8", errors="replace").splitlines()


def parse_metrics(lines: list):
    payload = None
    for line in lines:
        if METRICS_LINE.search(line):
            payload = line[len(METRICS_PREFIX):]
    if payload is None:
        return None
    try:
        return json.loads(payload)
    except ValueError:
        return None


def _job_env(runtime: Path, cache: Path, fragment: Path, enumerate_to: Path = None) -> dict:
    env = dict(os.environ)
    env["APPDATA"] = str(runtime)
    env["LOCALAPPDATA"] = str(runtime)
    if cache is not None:
        # The engine's FileAccess cannot create missing parent directories,
        # so the fragment directory must exist before the job starts.
        fragment.parent.mkdir(parents=True, exist_ok=True)
        env[CACHE_CANONICAL_ENV] = str(cache)
        env[CACHE_FRAGMENT_ENV] = str(fragment)
    if enumerate_to is not None:
        enumerate_to.parent.mkdir(parents=True, exist_ok=True)
        env[SWEEP_ENUMERATE_ENV] = str(enumerate_to)
    else:
        # Never let a stray FTG_SOLVER_ENUMERATE from the orchestrator's own
        # environment leak into warm jobs or workers (stub mode is
        # orchestrator-internal by contract).
        env.pop(SWEEP_ENUMERATE_ENV, None)
    return env


def run_job(job: dict, engine: str, project_root: Path, log_root: Path, no_reuse: bool,
            cache: Path = None, enumerate_to: Path = None) -> dict:
    runtime = log_root / ("runtime-" + job["name"])
    runtime.mkdir(parents=True, exist_ok=True)
    argv = [
        engine,
        "--headless",
        "--path",
        str(project_root),
        "--log-file",
        str(runtime / "engine.log"),
    ] + job["args"]
    if no_reuse and job["name"] not in ("import", "main-smoke"):
        argv += ["--", "--acceptance-no-reuse"]

    fragment = log_root / "cache-fragments" / (job["name"] + ".fragment")
    env = _job_env(runtime, cache, fragment, enumerate_to)

    log_path = log_root / (job["name"] + ".log")
    started = time.perf_counter()
    with open(log_path, "wb") as sink:
        code = subprocess.run(argv, cwd=str(project_root), env=env, stdout=sink,
                              stderr=subprocess.STDOUT).returncode
    elapsed = round(time.perf_counter() - started, 2)

    lines = read_log_lines(log_path)
    script_errors = sum(1 for line in lines if any(p.search(line) for p in SCRIPT_ERROR_PATTERNS))
    pass_lines = sum(1 for line in lines if PASS_PATTERN.search(line))
    metrics = parse_metrics(lines)
    reports = (metrics or {}).get("reports") or []

    return {
        "test": job["name"],
        "exit": _int0(code),
        "script_errors": script_errors,
        "pass_lines": pass_lines,
        "assertions": pass_lines,
        "seconds": elapsed,
        "solver_calls": _int0((metrics or {}).get("calls")),
        "solver_underlying_calls": _int0((metrics or {}).get("underlying_calls")),
        "solver_reuse_hits": _int0((metrics or {}).get("reuse_hits")),
        "solver_reuse_hit_rate": _float0((metrics or {}).get("reuse_hit_rate")),
        "solver_elapsed_ms": _float0((metrics or {}).get("elapsed_ms")),
        "combo_cache": metrics.get("combo_cache") if metrics else {},
        "solver_profile": (metrics or {}).get("profile_totals") or {},
        "report_fingerprints": [str(v) if (v := r.get("fingerprint")) is not None else "" for r in reports],
        # Per-unique-report request keys (ticket 06 Tier B invariant): the hot/cold
        # gate requires the fingerprint→keys mapping to match field by field.
        "solver_report_keys": [[str(k) for k in (r.get("keys") or [])] for r in reports],
        "appdata": str(runtime),
    }


def write_json(path: Path, payload) -> None:
    # utf-8-sig matches PS 5.1 `Set-Content -Encoding UTF8` (BOM) so existing
    # tooling that reads summary.json keeps working unchanged.
    with open(path, "w", encoding="utf-8-sig") as handle:
        json.dump(payload, handle, indent=4, ensure_ascii=True)


def _read_cache_file(path: Path):
    """Parse one cache file: (ordered digest→line dict, bad_line_count, header_ok)."""
    entries: dict = {}
    bad = 0
    saw_header = False
    header_ok = True
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except ValueError:
            bad += 1
            continue
        if not isinstance(obj, dict):
            bad += 1
            continue
        if "digest" in obj:
            digest = obj.get("digest")
            entry = obj.get("entry")
            if not (isinstance(digest, str) and digest and isinstance(entry, str) and entry):
                bad += 1
            elif digest not in entries:
                entries[digest] = obj
        elif "schema" in obj:
            saw_header = True
            if obj.get("schema") != CACHE_HEADER["schema"] \
                    or obj.get("version") != CACHE_HEADER["version"]:
                # Unknown format: drop the file wholesale, mirroring the Godot
                # loader (entries are then rebuilt from fragments).
                return {}, bad, False
        else:
            bad += 1
    return entries, bad, header_ok and saw_header


def merge_cache_fragments(canonical: Path, fragment_dir: Path, report_path: Path = None) -> dict:
    """Lock-free fragment merge (ticket 06): union canonical + per-job fragments
    keyed by digest (canonical first, fragments in sorted name order — a fixed
    merge order keeps re-merging the same inputs byte-identical / idempotent).
    The canonical file is replaced atomically; corrupt lines are skipped."""
    entries: dict = {}
    before = 0
    if canonical.is_file():
        canonical_entries, _, ok = _read_cache_file(canonical)
        if ok:
            entries.update(canonical_entries)
            before = len(entries)
    fragments = []
    merged_new = 0
    frag_paths = sorted(fragment_dir.glob("*.fragment")) if fragment_dir.is_dir() else []
    for frag in frag_paths:
        frag_entries, bad, _ = _read_cache_file(frag)
        added = sum(1 for digest in frag_entries if digest not in entries)
        for digest in frag_entries:
            if digest not in entries:
                entries[digest] = frag_entries[digest]
        merged_new += added
        fragments.append({"file": frag.name, "entries": len(frag_entries),
                          "merged_new": added, "bad_lines": bad})
    canonical.parent.mkdir(parents=True, exist_ok=True)
    tmp = canonical.with_name(canonical.name + ".tmp")
    with open(tmp, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(json.dumps(CACHE_HEADER, separators=(",", ":")) + "\n")
        for digest in entries:
            handle.write(json.dumps(entries[digest], separators=(",", ":"),
                                    ensure_ascii=False) + "\n")
    os.replace(str(tmp), str(canonical))
    stats = {
        "canonical": str(canonical),
        "entries_before": before,
        "fragments": fragments,
        "entries_after": len(entries),
        "merged_new": merged_new,
    }
    if report_path is not None:
        with open(report_path, "w", encoding="utf-8") as handle:
            json.dump(stats, handle, indent=2, ensure_ascii=False)
    return stats


def _read_descriptor_file(path: Path) -> list:
    """One enumeration pass product: the ordered (digest, descriptor) request
    sequence of a job. Malformed lines are skipped, mirroring the cache reader."""
    records = []
    if not path.is_file():
        return records
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line:
            continue
        try:
            obj = json.loads(line)
        except ValueError:
            continue
        if isinstance(obj, dict) and isinstance(obj.get("digest"), str) and obj["digest"] \
                and isinstance(obj.get("descriptor"), str) and obj["descriptor"]:
            records.append((obj["digest"], obj["descriptor"]))
    return records


def _collect_unique_descriptors(per_job: dict) -> dict:
    """Cross-job dedup (digest → descriptor); downstream task order is the
    sorted digest order, so this map's insertion order never leaks out."""
    unique = {}
    for name in sorted(per_job):
        for digest, descriptor in per_job[name]:
            if digest not in unique:
                unique[digest] = descriptor
    return unique


def _parse_worker_results(log_path: Path) -> list:
    results = []
    for line in read_log_lines(log_path):
        if line.startswith(SWEEP_WORKER_RESULT_PREFIX):
            try:
                payload = json.loads(line[len(SWEEP_WORKER_RESULT_PREFIX):])
            except ValueError:
                continue
            if isinstance(payload, dict):
                results.append(payload)
    return results


def run_sweep_task(index: int, digest: str, descriptor: str, engine: str, project_root: Path,
                   sweep_root: Path, cache: Path) -> dict:
    """One unique request → one worker process: descriptor → recompute →
    cache fragment (ticket 06 infrastructure)."""
    task_file = sweep_root / ("task-%04d.json" % index)
    with open(task_file, "w", encoding="utf-8") as handle:
        handle.write(json.dumps({"digest": digest, "descriptor": descriptor}) + "\n")
    fragment = sweep_root / ("worker-%04d.fragment" % index)
    runtime = sweep_root / ("runtime-%04d" % index)
    runtime.mkdir(parents=True, exist_ok=True)
    argv = [engine, "--headless", "--path", str(project_root), "-s", SWEEP_WORKER_SCRIPT]
    env = dict(os.environ)
    env["APPDATA"] = str(runtime)
    env["LOCALAPPDATA"] = str(runtime)
    env[CACHE_CANONICAL_ENV] = str(cache)
    env[CACHE_FRAGMENT_ENV] = str(fragment)
    env[SWEEP_TASK_FILE_ENV] = str(task_file)
    env.pop(SWEEP_ENUMERATE_ENV, None)
    log_path = sweep_root / ("worker-%04d.log" % index)
    started = time.perf_counter()
    with open(log_path, "wb") as sink:
        code = subprocess.run(argv, cwd=str(project_root), env=env, stdout=sink,
                              stderr=subprocess.STDOUT).returncode
    elapsed = round(time.perf_counter() - started, 2)
    worker_rows = _parse_worker_results(log_path)
    replay_ok = all(bool(row.get("ok")) for row in worker_rows) and len(worker_rows) >= 1
    return {
        "digest": digest,
        "exit": _int0(code),
        "seconds": elapsed,
        "replay_ok": replay_ok,
        "log": log_path.name,
    }


def _read_json_quietly(path: Path):
    """Whole-file JSON read for pool control files; None on any damage (the
    writer rewrites whole files, so a torn read just retries next poll)."""
    try:
        if not path.is_file():
            return None
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None


def _write_json_atomic(path: Path, payload) -> None:
    tmp = path.with_name(path.name + ".tmp")
    with open(tmp, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, separators=(",", ":"))
    os.replace(str(tmp), str(path))


def _load_durations(cache: Path) -> dict:
    data = _read_json_quietly(cache.with_name(cache.name + ".durations.json"))
    return {str(k): float(v) for k, v in (data or {}).items()
            if isinstance(v, (int, float))}


def _save_durations(cache: Path, durations: dict) -> None:
    path = cache.with_name(cache.name + ".durations.json")
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        with open(path, "w", encoding="utf-8") as handle:
            json.dump({k: round(v, 2) for k, v in sorted(durations.items())}, handle,
                      indent=2, ensure_ascii=True)
    except OSError as error:
        print("warning: durations sidecar write failed: %s" % error, file=sys.stderr)


def _ljf_order(ordered: list, durations: dict) -> list:
    """Longest-job-first with unknown-digest-first heuristic: fresh digests
    (new since the last run) get the worst known duration +1 so they land at
    the head; ties keep the deterministic sorted-digest order."""
    if not durations:
        return list(ordered)
    worst = max(durations.values()) if durations else 0.0
    return sorted(ordered, key=lambda item: (-(durations.get(item[0], worst + 1.0)), item[0]))


class WorkerSlot:
    """One reusable engine process: dispatch via assignment file, collect via
    result file, monitor via heartbeat file. Fragment paths are per (slot,
    generation): a respawned worker's in-memory fragment map starts empty and
    whole-file rewrites, so earlier generations must keep their own files."""

    def __init__(self, index: int, engine: str, project_root: Path, sweep_root: Path,
                 cache: Path, watchdog_ms: int):
        self.index = index
        self.engine = engine
        self.project_root = project_root
        self.sweep_root = sweep_root
        self.cache = cache
        self.watchdog_ms = watchdog_ms
        self.control = sweep_root / "pool" / ("worker-%02d" % index)
        self.control.mkdir(parents=True, exist_ok=True)
        self.runtime = sweep_root / ("pool-runtime-%02d" % index)
        self.runtime.mkdir(parents=True, exist_ok=True)
        self.gen = 0
        self.proc = None
        self.log_handle = None
        self.seq = 0
        self.in_flight = None
        self.served = 0
        self.kills = 0
        self.events = sweep_root / "pool-events.jsonl"

    # -- lifecycle -------------------------------------------------------

    def _log_event(self, event: str, extra: dict = None) -> None:
        row = {"slot": self.index, "gen": self.gen, "event": event,
               "pid": self.proc.pid if self.proc is not None else None,
               "time": round(time.time(), 3)}
        row.update(extra or {})
        with open(self.events, "a", encoding="utf-8") as handle:
            handle.write(json.dumps(row, ensure_ascii=True) + "\n")

    def spawn(self) -> None:
        fragment = self.sweep_root / ("pool-worker-%02d-g%d.fragment" % (self.index, self.gen))
        argv = [self.engine, "--headless", "--path", str(self.project_root), "-s", POOL_WORKER_SCRIPT]
        env = dict(os.environ)
        env["APPDATA"] = str(self.runtime)
        env["LOCALAPPDATA"] = str(self.runtime)
        env[CACHE_CANONICAL_ENV] = str(self.cache)
        env[CACHE_FRAGMENT_ENV] = str(fragment)
        env[POOL_CONTROL_ENV] = str(self.control)
        env[POOL_WATCHDOG_ENV] = str(self.watchdog_ms)
        env.pop(SWEEP_ENUMERATE_ENV, None)
        self.log_handle = open(self.control / ("worker-g%d.log" % self.gen), "ab")
        self.proc = subprocess.Popen(argv, cwd=str(self.project_root), env=env,
                                     stdout=self.log_handle, stderr=subprocess.STDOUT)
        self._log_event("spawn")

    def ensure_running(self) -> None:
        if self.proc is None or self.proc.poll() is not None:
            if self.proc is not None:
                self._log_event("exit-observed", {"code": self.proc.returncode})
                self.gen += 1
                if self.log_handle is not None:
                    self.log_handle.close()
                    self.log_handle = None
            self.spawn()

    def kill_current(self, reason: str) -> bool:
        """Kill the process (stall / no-progress / quarantine). Returns whether
        a live process was actually terminated — a worker that died on its own
        is handled (requeued) without counting as a runner kill. Either way the
        attempt can never be counted as passed: its digest only becomes
        complete through a later healthy attempt's ok result."""
        terminated = False
        if self.proc is not None and self.proc.poll() is None:
            self.proc.kill()
            self.proc.wait(timeout=10)
            terminated = True
        self._log_event("kill" if terminated else "exit-handled", {"reason": reason})
        if terminated:
            self.kills += 1
        return terminated

    def stop(self) -> None:
        self.seq += 1
        _write_json_atomic(self.control / "assignment.json", {"seq": self.seq, "stop": True})
        if self.proc is not None and self.proc.poll() is None:
            try:
                self.proc.wait(timeout=POOL_STOP_GRACE_SECONDS)
            except subprocess.TimeoutExpired:
                self.kill_current("stop-timeout")
        if self.log_handle is not None:
            self.log_handle.close()
            self.log_handle = None

    # -- dispatch / collect ----------------------------------------------

    def dispatch(self, digest: str, descriptor: str, attempt: int, carry: dict = None) -> dict:
        self.ensure_running()
        self.seq += 1
        task_name = "task-%d.json" % self.seq
        with open(self.control / task_name, "w", encoding="utf-8") as handle:
            handle.write(json.dumps({"digest": digest, "descriptor": descriptor}) + "\n")
        for stale in ("heartbeat.json", "result.json"):
            try:
                (self.control / stale).unlink()
            except OSError:
                pass
        _write_json_atomic(self.control / "assignment.json", {"seq": self.seq, "task": task_name})
        carry = carry or {}
        self.in_flight = {
            "digest": digest, "descriptor": descriptor, "seq": self.seq,
            "attempt": attempt, "started": time.perf_counter(),
            "started_wall": time.time(),
            "busy_before": float(carry.get("busy_before", 0.0)),
            "heartbeats": int(carry.get("heartbeats", 0)),
            "pauses": int(carry.get("pauses", 0)),
            "progress": None, "progress_since_wall": time.time(),
            "kills": list(carry.get("kills", ())),
            "worker_exits": list(carry.get("worker_exits", ())),
            "terminations": int(carry.get("terminations", 0)),
        }
        return self.in_flight

    def heartbeat(self):
        """(payload-or-None, mtime-or-None) for the live heartbeat file."""
        path = self.control / "heartbeat.json"
        try:
            mtime = path.stat().st_mtime
        except OSError:
            return None, None
        return _read_json_quietly(path), mtime

    def result(self):
        return _read_json_quietly(self.control / "result.json")

    def collect(self):
        """A finished attempt: result.json seq matches the in-flight dispatch."""
        payload = self.result()
        if not isinstance(payload, dict) or self.in_flight is None:
            return None
        if int(payload.get("seq", -1)) != self.in_flight["seq"]:
            return None
        return payload


class SweepPool:
    """Reusable worker pool driving the deduplicated sweep requests to a
    complete / incomplete / failed verdict per request. Speed comes only from
    lane saturation + cross-request engine reuse; a slow or stuck request is
    killed, restarted (resuming its persisted checkpoint when loadable) and,
    once its allowance is spent, honestly recorded — never silently passed,
    never truncated."""

    def __init__(self, engine: str, project_root: Path, sweep_root: Path, cache: Path,
                 lanes: int, watchdog_ms: int, stall_limit: float, restarts: int,
                 budget: float):
        self.engine = engine
        self.project_root = project_root
        self.sweep_root = sweep_root
        self.cache = cache
        self.lanes = lanes
        self.watchdog_ms = watchdog_ms
        self.stall_limit = stall_limit
        self.restarts = restarts
        self.budget = budget
        self.slots = [WorkerSlot(i, engine, project_root, sweep_root, cache, watchdog_ms)
                      for i in range(max(1, lanes))]

    def run(self, ordered: list) -> tuple:
        """ordered: [(digest, descriptor)] in LJF order. Returns (rows by
        digest, pool report block)."""
        covered_before = set()
        if self.cache is not None and self.cache.is_file():
            entries, _, ok = _read_cache_file(self.cache)
            if ok:
                covered_before = set(entries)
        rows = {}
        pending = []
        cache_hits = 0
        for digest, descriptor in ordered:
            if digest in covered_before:
                cache_hits += 1
                rows[digest] = {
                    "digest": digest, "status": "complete", "exit": 0, "seconds": 0.0,
                    "replay_ok": True, "log": None, "attempts": 0, "restarts": 0,
                    "killed": False, "kill_reasons": [], "worker_exits": [],
                    "cache_hit": True, "resumed": False, "pauses": 0,
                    "heartbeats": 0, "error": "",
                }
            else:
                pending.append((digest, descriptor))
        attempt_count = {}
        in_use = set()
        started = time.perf_counter()
        try:
            while pending or in_use:
                for slot in self.slots:
                    self._service(slot, rows, attempt_count)
                pending, in_use = self._dispatch(pending, rows)
                time.sleep(POOL_POLL_SECONDS)
        finally:
            for slot in self.slots:
                try:
                    slot.stop()
                except OSError as error:
                    print("warning: worker %d stop failed: %s" % (slot.index, error),
                          file=sys.stderr)
        wall = time.perf_counter() - started
        report = {
            "lanes": len(self.slots),
            "watchdog_ms": self.watchdog_ms,
            "stall_limit": round(self.stall_limit, 2),
            "restarts_max": self.restarts,
            "budget_seconds": round(self.budget, 2) if self.budget > 0 else None,
            "cache_hit_skips": cache_hits,
            "wall_seconds": round(wall, 2),
            "kills": sum(slot.kills for slot in self.slots),
            "workers": [{"slot": s.index, "generations": s.gen + 1, "served": s.served,
                         "kills": s.kills} for s in self.slots],
        }
        return rows, report

    # -- internals ---------------------------------------------------------

    def _dispatch(self, pending: list, rows: dict) -> tuple:
        still_pending = list(pending)
        for slot in self.slots:
            if slot.in_flight is not None or not still_pending:
                continue
            digest, descriptor = still_pending.pop(0)
            attempt = 1
            slot.dispatch(digest, descriptor, attempt)
        in_use = sum(1 for slot in self.slots if slot.in_flight is not None)
        return still_pending, in_use

    def _service(self, slot: WorkerSlot, rows: dict, attempt_count: dict) -> None:
        flight = slot.in_flight
        if flight is None:
            return
        now = time.perf_counter()
        finished = slot.collect()
        if finished is not None:
            self._finalize(slot, rows, flight, finished)
            return
        exited = slot.proc.poll() if slot.proc is not None else None
        if exited is not None:
            flight["worker_exits"].append(int(exited))
            self._kill_and_requeue(slot, rows, attempt_count, "worker-exit-code-%d" % exited)
            return
        hb, mtime = slot.heartbeat()
        since_progress = None
        if hb is not None and isinstance(hb, dict) and hb.get("state") == "running" \
                and hb.get("digest") == flight["digest"]:
            flight["pauses"] = max(flight["pauses"], int(hb.get("pause", 0)))
            progress = (str(hb.get("phase", "")), int(hb.get("sources_done", -1)),
                        int(hb.get("cycles_done", -1)), int(hb.get("spatial_done", -1)))
            if progress != flight["progress"]:
                flight["progress"] = progress
                flight["progress_since_wall"] = time.time()
                flight["heartbeats"] += 1
            since_progress = time.time() - flight["progress_since_wall"]
        last_signal = mtime if mtime is not None else flight["started_wall"]
        stall = time.time() - last_signal
        if stall > self.stall_limit:
            self._kill_and_requeue(slot, rows, attempt_count, "stall")
            return
        if since_progress is not None and since_progress > self.stall_limit:
            self._kill_and_requeue(slot, rows, attempt_count, "no-progress")
            return
        busy = (now - flight["started"]) + flight["busy_before"]
        if self.budget > 0 and busy > self.budget:
            self._kill_and_requeue(slot, rows, attempt_count, "slow-quarantine", final=True)
            return

    def _kill_and_requeue(self, slot: WorkerSlot, rows: dict, attempt_count: dict,
                          reason: str, final: bool = False) -> None:
        flight = slot.in_flight
        terminated = slot.kill_current(reason)
        flight["kills"].append(reason)
        if terminated:
            flight["terminations"] = flight.get("terminations", 0) + 1
        flight["busy_before"] += time.perf_counter() - flight["started"]
        digest = flight["digest"]
        attempts = attempt_count.get(digest, 1)
        if not final and attempts <= self.restarts:
            attempt_count[digest] = attempts + 1
            slot.dispatch(digest, flight["descriptor"], attempts + 1, carry={
                "busy_before": flight["busy_before"],
                "heartbeats": flight["heartbeats"],
                "kills": flight["kills"],
                "worker_exits": flight["worker_exits"],
                "terminations": flight.get("terminations", 0),
            })
            print("sweep-task: %s killed (%s) → restart attempt %d"
                  % (digest[:12], reason, attempts + 1), flush=True)
            return
        made_progress = flight["progress"] is not None or flight["pauses"] > 0
        rows[digest] = self._row(flight, {
            "digest": digest, "ok": False,
            "error": "重启额度耗尽：%s%s" % (reason, "（曾观察到进展）" if made_progress else "（无进展信号）"),
        }, exit_code=(slot.proc.returncode if slot.proc is not None else 1),
            status=("incomplete" if made_progress and not final else "failed"))
        slot.in_flight = None
        print("sweep-task: %s status=%s (%s)" % (digest[:12], rows[digest]["status"], reason),
              flush=True)

    def _finalize(self, slot: WorkerSlot, rows: dict, flight: dict, finished: dict) -> None:
        ok = bool(finished.get("ok", False))
        busy = (time.perf_counter() - flight["started"]) + flight["busy_before"]
        flight["busy_before"] = busy
        status = "complete" if ok else "failed"
        rows[flight["digest"]] = self._row(flight, finished, exit_code=0, status=status)
        slot.in_flight = None
        slot.served += 1
        print("sweep-task: %s status=%s exit=0 replay_ok=%s pauses=%d resumed=%s %.1fs"
              % (flight["digest"][:12], status, ok, int(finished.get("pauses", 0)),
                 bool(finished.get("resumed", False)), busy), flush=True)

    def _row(self, flight: dict, finished: dict, exit_code: int, status: str) -> dict:
        return {
            "digest": flight["digest"],
            "status": status,
            "exit": _int0(exit_code),
            "seconds": round(flight["busy_before"], 2),
            "replay_ok": bool(finished.get("ok", False)),
            "log": None,
            "attempts": flight["attempt"],
            "restarts": flight["attempt"] - 1,
            "killed": flight.get("terminations", 0) > 0,
            "kill_reasons": flight["kills"],
            "worker_exits": flight["worker_exits"],
            "cache_hit": False,
            "resumed": bool(finished.get("resumed", False)),
            "pauses": int(finished.get("pauses", 0)) if finished.get("ok") else flight["pauses"],
            "heartbeats": flight["heartbeats"],
            "error": str(finished.get("error", "")),
        }


def run_sweep_pool(args, project_root: Path, sweep_root: Path, cache: Path,
                   ordered: list) -> tuple:
    durations = _load_durations(cache) if cache is not None else {}
    pool = SweepPool(args.engine, project_root, sweep_root, cache,
                     lanes=args.concurrency, watchdog_ms=args.pool_watchdog_ms,
                     stall_limit=args.pool_stall_limit, restarts=args.pool_restarts,
                     budget=args.pool_budget)
    rows, pool_report = pool.run(_ljf_order(list(ordered), durations))
    task_records = [rows[digest] for digest, _ in ordered]
    if cache is not None:
        known = dict(durations)
        for row in task_records:
            if row["status"] == "complete" and not row["cache_hit"]:
                known[row["digest"]] = max(row["seconds"], 0.01)
        _save_durations(cache, known)
    return task_records, pool_report


def run_sweep(args, project_root: Path, log_root: Path, cache: Path, jobs: list) -> int:
    """Ticket 08 three-stage global pre-sweep. The enumeration pass's stdout,
    summaries and exit codes are discarded entirely — only its per-job descriptor
    files feed the sweep; warm-run misses are recorded as enumeration gaps."""
    results = [None] * len(jobs)

    def record(index: int, row: dict) -> None:
        results[index] = row
        print(json.dumps(row, separators=(",", ":")), flush=True)
        write_json(log_root / "summary.json", [r for r in results if r is not None])

    remaining = list(enumerate(jobs[1:], start=1))

    import_started = time.perf_counter()
    record(0, run_job(jobs[0], args.engine, project_root, log_root, args.no_reuse, cache))
    import_seconds = time.perf_counter() - import_started

    descriptor_dir = log_root / "sweep" / "descriptors"
    descriptor_dir.mkdir(parents=True, exist_ok=True)
    enum_root = log_root / "enumerate"
    enum_started = time.perf_counter()

    def enumerate_one(item):
        index, job = item
        row = run_job(job, args.engine, project_root, enum_root, False, cache,
                      enumerate_to=descriptor_dir / (job["name"] + ".jsonl"))
        return index, job["name"], row

    with ThreadPoolExecutor(max_workers=args.concurrency) as pool:
        enum_rows = {name: row for _, name, row in pool.map(enumerate_one, remaining)}
    enum_seconds = time.perf_counter() - enum_started

    per_job = {job["name"]: _read_descriptor_file(descriptor_dir / (job["name"] + ".jsonl"))
               for _, job in remaining}
    unique = _collect_unique_descriptors(per_job)
    report = {
        "mode": "acceptance-sweep",
        "concurrency": args.concurrency,
        "cache": str(cache),
        "enumerate": {
            "wall_seconds": round(enum_seconds, 2),
            "jobs": {name: {
                "exit": row["exit"],
                "seconds": row["seconds"],
                "requests": len(per_job[name]),
            } for name, row in enum_rows.items()},
            "requests_total": sum(len(v) for v in per_job.values()),
            "unique_descriptors": len(unique),
        },
        "stage_walls": {"import": round(import_seconds, 2),
                        "enumerate": round(enum_seconds, 2)},
    }

    if args.sweep_stage == "enumerate":
        write_json(log_root / "sweep.json", report)
        with open(log_root / "runner.status.txt", "w", encoding="ascii") as handle:
            handle.write("exit=0\n")
        print("sweep-enumerate: %d request(s) → %d unique descriptor(s), wall %.1fs"
              % (report["enumerate"]["requests_total"], len(unique), enum_seconds), flush=True)
        return 0

    sweep_root = log_root / "sweep" / "workers"
    sweep_root.mkdir(parents=True, exist_ok=True)
    ordered = sorted(unique.items())
    sweep_started = time.perf_counter()
    pool_report = None

    if args.sweep_mode == "pool":
        task_records, pool_report = run_sweep_pool(args, project_root, sweep_root,
                                                   cache, ordered)
    else:
        def sweep_one(item):
            index, (digest, descriptor) = item
            return index, run_sweep_task(index, digest, descriptor, args.engine,
                                         project_root, sweep_root, cache)

        task_records = [None] * len(ordered)
        if ordered:
            with ThreadPoolExecutor(max_workers=args.concurrency) as pool:
                for index, row in pool.map(sweep_one, list(enumerate(ordered))):
                    task_records[index] = row
        for row in task_records:
            # Spawn mode carries the old per-request verdicts; the P6 tri-state
            # is derived the same honest way (no result, no complete).
            row["status"] = "complete" if row["exit"] == 0 and row["replay_ok"] else "failed"
            row.update({"attempts": 1, "restarts": 0, "killed": False, "kill_reasons": [],
                        "worker_exits": [], "cache_hit": False, "resumed": False,
                        "pauses": 0, "heartbeats": 0, "error": ""})
            print("sweep-task: %s exit=%d replay_ok=%s %.1fs"
                  % (row["digest"][:12], row["exit"], row["replay_ok"], row["seconds"]),
                  flush=True)
    sweep_seconds = time.perf_counter() - sweep_started

    merge_stats = None
    try:
        merge_stats = merge_cache_fragments(cache, sweep_root, log_root / "sweep-merge.json")
    except OSError as error:
        print("warning: sweep fragment merge failed: %s" % error, file=sys.stderr)
    covered = set()
    if cache is not None and cache.is_file():
        entries, _, ok = _read_cache_file(cache)
        if ok:
            covered = set(entries)
    gaps = [row["digest"] for row in task_records if row["digest"] not in covered]
    busy_total = sum(row["seconds"] for row in task_records)
    status_counts = {}
    for row in task_records:
        status_counts[row["status"]] = status_counts.get(row["status"], 0) + 1
    report["sweep"] = {
        "mode": args.sweep_mode,
        "wall_seconds": round(sweep_seconds, 2),
        "lanes": args.concurrency,
        "tasks": len(ordered),
        "task_busy_seconds": round(busy_total, 2),
        "lane_busy_ratio": round(busy_total / (args.concurrency * sweep_seconds), 4)
                            if ordered and sweep_seconds > 0 else None,
        "covered": len(ordered) - len(gaps),
        "gaps": gaps,
        "status_counts": status_counts,
        "quarantined": [row["digest"] for row in task_records
                        if "slow-quarantine" in row.get("kill_reasons", [])],
        "task_rows": [{"digest": row["digest"], "status": row["status"],
                       "exit": row["exit"], "seconds": row["seconds"],
                       "replay_ok": row["replay_ok"], "attempts": row["attempts"],
                       "restarts": row["restarts"], "killed": row["killed"],
                       "kill_reasons": row["kill_reasons"],
                       "worker_exits": row["worker_exits"],
                       "cache_hit": row["cache_hit"], "resumed": row["resumed"],
                       "pauses": row["pauses"], "error": row["error"]}
                      for row in task_records],
        "pool": pool_report,
        "merge": merge_stats,
    }
    report["stage_walls"]["sweep"] = round(sweep_seconds, 2)

    # Warm stage longest-job-first: the enumerate pass just produced a fresh
    # per-job duration sample; spending the slowest jobs' lanes first shrinks
    # the tail without touching any job's semantics (summary stays canonical).
    warm_started = time.perf_counter()
    warm_order = sorted(remaining, key=lambda item: -_float0(
        (enum_rows.get(item[1]["name"], {}) or {}).get("seconds", 0)))
    if args.concurrency == 1:
        for index, job in warm_order:
            record(index, run_job(job, args.engine, project_root, log_root, args.no_reuse, cache))
    else:
        with ThreadPoolExecutor(max_workers=args.concurrency) as pool:
            futures = {
                pool.submit(run_job, job, args.engine, project_root, log_root, args.no_reuse, cache): index
                for index, job in warm_order
            }
            for future in as_completed(futures):
                record(futures[future], future.result())
    warm_seconds = time.perf_counter() - warm_started
    report["stage_walls"]["warm"] = round(warm_seconds, 2)
    report["stage_walls"]["total"] = round(import_seconds + enum_seconds + sweep_seconds + warm_seconds, 2)
    report["warm"] = {
        "wall_seconds": round(warm_seconds, 2),
        "misses_total": sum(_int0((r.get("combo_cache") or {}).get("misses")) for r in results if r),
    }

    total_calls = sum(r["solver_calls"] for r in results)
    total_reuse_hits = sum(r["solver_reuse_hits"] for r in results)
    summary = {
        "mode": "acceptance-sweep",
        "total_seconds": round(sum(r["seconds"] for r in results), 2),
        "total_assertions": sum(r["assertions"] for r in results),
        "total_solver_calls": total_calls,
        "total_solver_underlying_calls": sum(r["solver_underlying_calls"] for r in results),
        "total_solver_reuse_hits": total_reuse_hits,
        "solver_reuse_hit_rate": total_reuse_hits / total_calls if total_calls > 0 else 0.0,
        "tests": results,
    }
    write_json(log_root / "summary.json", summary)
    write_json(log_root / "sweep.json", report)
    if cache is not None:
        try:
            stats = merge_cache_fragments(cache, log_root / "cache-fragments",
                                          log_root / "cache-merge.json")
            print("cache-merge: %d entries (+%d new from %d fragment(s))"
                  % (stats["entries_after"], stats["merged_new"], len(stats["fragments"])),
                  flush=True)
        except OSError as error:
            print("warning: cache merge failed: %s" % error, file=sys.stderr)
    exit_code = 1 if any(r["exit"] != 0 or r["script_errors"] > 0 for r in results) else 0
    with open(log_root / "runner.status.txt", "w", encoding="ascii") as handle:
        handle.write("exit=%d\n" % exit_code)
    return exit_code


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Acceptance orchestrator (PS runner parity, parallel fan-out).")
    parser.add_argument("--engine", default=DEFAULT_ENGINE)
    parser.add_argument("--output", default=DEFAULT_OUTPUT)
    parser.add_argument("--concurrency", "--jobs", dest="concurrency", type=int, default=8,
                        help="parallel fan-out for test jobs after the import barrier (default 8)")
    parser.add_argument("--serial", action="store_true",
                        help="force serial mode (equivalent to --concurrency 1; overrides --concurrency)")
    parser.add_argument("--cache", default=None,
                        help="persistent solver result cache file (default: %s; "
                             "disabled entirely with --no-reuse)" % DEFAULT_CACHE_RELATIVE)
    parser.add_argument("--no-reuse", action="store_true",
                        help="baseline mode: pass --acceptance-no-reuse to test jobs and "
                             "skip persistent cache loading/writing/merging")
    parser.add_argument("--sweep", action="store_true",
                        help="global pre-sweep mode (ticket 08): enumerate every job first "
                             "(stub mode, outputs discarded), compute the deduplicated unique "
                             "requests across lanes into cache fragments, then run all jobs "
                             "warm; requires the persistent cache")
    parser.add_argument("--sweep-stage", choices=("all", "enumerate"), default="all",
                        help="stop after the enumeration pass (determinism gate: run twice, "
                             "diff the per-job descriptor sequences)")
    parser.add_argument("--sweep-mode", choices=("pool", "spawn"), default="pool",
                        help="sweep stage worker model: 'pool' = reusable engine processes "
                             "with per-request heartbeat/checkpoint, longest-job-first "
                             "dispatch, stall kill + checkpoint restart and slow quarantine "
                             "(P6, default); 'spawn' = legacy one-process-per-request "
                             "(differential oracle)")
    parser.add_argument("--pool-watchdog-ms", type=int, default=30000,
                        help="solver watchdog budget per pause window in pool mode "
                             "(0 disables pause checkpoints); resource control only, "
                             "never part of the request key or the report")
    parser.add_argument("--pool-stall-limit", type=float, default=900.0,
                        help="seconds without a heartbeat (or without forward progress) "
                             "before a pool worker is killed and its request restarted")
    parser.add_argument("--pool-restarts", type=int, default=2,
                        help="per-request restart allowance before the request is settled "
                             "as incomplete/failed (never silently complete)")
    parser.add_argument("--pool-budget", type=float, default=3600.0,
                        help="per-request cumulative busy-seconds budget (slow quarantine); "
                             "exceeding it kills the request and records it honestly as "
                             "failed (0 disables)")
    parser.add_argument("--only", default=None,
                        help="comma-separated job-name filter for evidence runs (import "
                             "always runs; canonical order and summary schema unchanged)")
    args = parser.parse_args(argv)
    if args.serial:
        args.concurrency = 1
    if args.concurrency < 1:
        parser.error("--concurrency must be >= 1")
    if args.pool_watchdog_ms < 0:
        parser.error("--pool-watchdog-ms must be >= 0")
    if args.pool_stall_limit <= 0 or args.pool_restarts < 0 or args.pool_budget < 0:
        parser.error("--pool-stall-limit/--pool-restarts/--pool-budget must be non-negative "
                     "(stall limit positive)")
    if args.sweep and args.no_reuse:
        parser.error("--sweep needs the persistent cache; --no-reuse is the reuse-free "
                     "baseline mode (no enumeration, no sweep, no cache IO)")

    project_root = Path(__file__).resolve().parent.parent
    log_root = Path(os.path.abspath(str(project_root / args.output)))
    log_root.mkdir(parents=True, exist_ok=True)
    cache = None
    if not args.no_reuse:
        cache = Path(os.path.abspath(str(project_root / args.cache))) if args.cache \
            else project_root / DEFAULT_CACHE_RELATIVE

    jobs = discover_jobs(project_root)
    if args.only:
        wanted = {name.strip() for name in args.only.split(",") if name.strip()}
        jobs = [jobs[0]] + [job for job in jobs[1:] if job["name"] in wanted]
    if args.sweep:
        return run_sweep(args, project_root, log_root, cache, jobs)
    results = [None] * len(jobs)

    def record(index: int, row: dict) -> None:
        # Main-thread only (serial loop or the as_completed loop), so the print
        # and the progressive summary write need no lock.
        results[index] = row
        print(json.dumps(row, separators=(",", ":")), flush=True)
        write_json(log_root / "summary.json", [r for r in results if r is not None])

    # Import barrier: the import job writes the shared import-cache directory,
    # so it must exit before any concurrent test job starts (ticket 02).
    record(0, run_job(jobs[0], args.engine, project_root, log_root, args.no_reuse, cache))

    remaining = list(enumerate(jobs[1:], start=1))
    if args.concurrency == 1:
        for index, job in remaining:
            record(index, run_job(job, args.engine, project_root, log_root, args.no_reuse, cache))
    else:
        with ThreadPoolExecutor(max_workers=args.concurrency) as pool:
            futures = {
                pool.submit(run_job, job, args.engine, project_root, log_root, args.no_reuse, cache): index
                for index, job in remaining
            }
            for future in as_completed(futures):
                record(futures[future], future.result())

    total_calls = sum(r["solver_calls"] for r in results)
    total_reuse_hits = sum(r["solver_reuse_hits"] for r in results)
    summary = {
        "mode": "baseline-no-acceptance-reuse" if args.no_reuse else "acceptance-reuse",
        "total_seconds": round(sum(r["seconds"] for r in results), 2),
        "total_assertions": sum(r["assertions"] for r in results),
        "total_solver_calls": total_calls,
        "total_solver_underlying_calls": sum(r["solver_underlying_calls"] for r in results),
        "total_solver_reuse_hits": total_reuse_hits,
        "solver_reuse_hit_rate": total_reuse_hits / total_calls if total_calls > 0 else 0.0,
        "tests": results,
    }
    write_json(log_root / "summary.json", summary)
    if cache is not None:
        try:
            stats = merge_cache_fragments(cache, log_root / "cache-fragments",
                                          log_root / "cache-merge.json")
            print("cache-merge: %d entries (+%d new from %d fragment(s))"
                  % (stats["entries_after"], stats["merged_new"], len(stats["fragments"])),
                  flush=True)
        except OSError as error:
            # Cache merge is an optimization, never an acceptance failure.
            print("warning: cache merge failed: %s" % error, file=sys.stderr)
    # Failure predicate: only a real non-zero process exit code or a positive
    # script-error count; missing counts already normalized to 0 above.
    exit_code = 1 if any(r["exit"] != 0 or r["script_errors"] > 0 for r in results) else 0
    with open(log_root / "runner.status.txt", "w", encoding="ascii") as handle:
        handle.write("exit=%d\n" % exit_code)
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
