#!/usr/bin/env bash
# Ticket 02 parallel full run launcher (--concurrency 8). Diff-gate counterpart
# of launch-serial-baseline.sh: runs against the same frozen tree, writes
# summary.json + runner.status.txt into parallel-full/ and one compact JSON
# line per completed job to parallel-full.stdout. Wall clock = parallel-full/
# runner.status.txt mtime minus the launch timestamp recorded here.
set -u
BASE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$BASE/../../.." && pwd)"
OUT="$BASE/parallel-full"
mkdir -p "$OUT"
cd "$ROOT"
echo "launch: $(date '+%F %T')" > "$BASE/parallel-launch.log"
nohup python tools/run_acceptance.py --concurrency 8 \
  --output ".scratch/acceptance-speedup/baseline-02/parallel-full" \
  > "$BASE/parallel-full.stdout" 2>&1 &
echo $! > "$BASE/parallel-full.pid"
echo "pid=$(cat "$BASE/parallel-full.pid")" >> "$BASE/parallel-launch.log"
cat "$BASE/parallel-launch.log"
