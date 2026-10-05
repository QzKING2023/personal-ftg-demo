"""Stage 1: fast, fixed-input evidence; known route failures still exit nonzero."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", default="D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe")
    parser.add_argument("--output", required=True, help="New evidence directory; never overwrites a run")
    parser.add_argument("--case", default="all", help="Fixed scenario id in inputs.json")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    output = (root / args.output).resolve()
    output.mkdir(parents=True, exist_ok=False)
    traces = output / "traces"
    traces.mkdir()
    env = dict(os.environ)
    runtime = output / "runtime"
    runtime.mkdir()
    env.update(APPDATA=str(runtime), LOCALAPPDATA=str(runtime))
    jobs = [
        ("boundary", "tests/test_acceptance_combo_boundary.gd", [], "BOUNDARY FAILURES="),
        ("replay10", "tests/acceptance_replay_10.gd", [], "REPLAY 10 CHECK"),
        ("symptoms", "tests/replay_combo_routes.gd", ["--", args.case, str(traces)], "TARGET FAILURES="),
    ]
    rows = []
    for name, script, extra, marker in jobs:
        command = [args.engine, "--headless", "--path", str(root), "--log-file",
                   str(runtime / (name + ".log")), "-s", "res://" + script, *extra]
        start = time.monotonic()
        result = subprocess.run(command, cwd=root, env=env, capture_output=True)
        log = result.stdout + result.stderr
        (output / (name + ".log")).write_bytes(log)
        content = log.decode("utf-8", errors="replace")
        errors = len(re.findall(r"SCRIPT ERROR:|Parse Error:|CrashHandlerException", content))
        row = dict(job=name, command=command, exit=result.returncode, script_errors=errors,
                   completed=marker in content, seconds=round(time.monotonic() - start, 3),
                   passes=len(re.findall(r"^\s*PASS\s", content, re.M)),
                   failures=len(re.findall(r"^\s*FAIL\s", content, re.M)))
        rows.append(row)
        print(json.dumps(row, ensure_ascii=False))
    hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(traces.glob("*.jsonl"))}
    summary = dict(jobs=rows, trace_sha256=hashes,
                   scope="Acceptance tools only. Route failures are not converted to success.")
    (output / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return int(any(r["exit"] or r["script_errors"] or r["failures"] or not r["completed"] for r in rows))


if __name__ == "__main__":
    raise SystemExit(main())
