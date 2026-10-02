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


def _job_env(runtime: Path, cache: Path, fragment: Path) -> dict:
    env = dict(os.environ)
    env["APPDATA"] = str(runtime)
    env["LOCALAPPDATA"] = str(runtime)
    if cache is not None:
        # The engine's FileAccess cannot create missing parent directories,
        # so the fragment directory must exist before the job starts.
        fragment.parent.mkdir(parents=True, exist_ok=True)
        env[CACHE_CANONICAL_ENV] = str(cache)
        env[CACHE_FRAGMENT_ENV] = str(fragment)
    return env


def run_job(job: dict, engine: str, project_root: Path, log_root: Path, no_reuse: bool,
            cache: Path = None) -> dict:
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
    env = _job_env(runtime, cache, fragment)

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
    args = parser.parse_args(argv)
    if args.serial:
        args.concurrency = 1
    if args.concurrency < 1:
        parser.error("--concurrency must be >= 1")

    project_root = Path(__file__).resolve().parent.parent
    log_root = Path(os.path.abspath(str(project_root / args.output)))
    log_root.mkdir(parents=True, exist_ok=True)
    cache = None
    if not args.no_reuse:
        cache = Path(os.path.abspath(str(project_root / args.cache))) if args.cache \
            else project_root / DEFAULT_CACHE_RELATIVE

    jobs = discover_jobs(project_root)
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
