#!/usr/bin/env bash
# Ticket 02 serial full baseline launcher. Meant to be fired once, after the
# working tree is frozen (committed); the run takes 10-15h (overnight). The
# orchestrator writes summary.json + runner.status.txt into serial-full/ and
# one compact JSON line per completed job to serial-full.stdout (poll liveness
# by that file's line count). Wall clock is derived from launch.log timestamps
# and summary total_seconds.
set -u
BASE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$BASE/../../.." && pwd)"
OUT="$BASE/serial-full"
mkdir -p "$OUT"
cd "$ROOT"
echo "launch: $(date '+%F %T')" > "$BASE/launch.log"
nohup python tools/run_acceptance.py --serial \
  --output ".scratch/acceptance-speedup/baseline-02/serial-full" \
  > "$BASE/serial-full.stdout" 2>&1 &
echo $! > "$BASE/serial-full.pid"
echo "pid=$(cat "$BASE/serial-full.pid")" >> "$BASE/launch.log"
cat "$BASE/launch.log"
