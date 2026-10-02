#!/usr/bin/env bash
# Ticket 07 final proof launcher: ONE cold full acceptance run, default config
# (sweep on, brand-new cache file, default concurrency 8 → mode=acceptance-sweep).
# Working tree frozen at 2352684 (08 delivered). The orchestrator writes
# summary.json + runner.status.txt + sweep.json into full/ and one compact JSON
# line per completed job to full.stdout (poll liveness by that file's line
# count; engine processes are verified via output files, not CPU counters —
# background Godot CPU readings are a red herring).
# Wall clock: launch.log timestamps + summary total_seconds + sweep stage_walls.
set -u
BASE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$BASE/../../.." && pwd)"
OUT="$BASE/full"
CACHE="$BASE/solver-results.cache"
mkdir -p "$OUT"
cd "$ROOT"
if [ -e "$CACHE" ]; then
  echo "REFUSING: cache file already exists ($CACHE) — this must be a cold run" >&2
  exit 1
fi
echo "launch: $(date '+%F %T')" > "$BASE/launch.log"
nohup python tools/run_acceptance.py \
  --output "$OUT" \
  --cache "$CACHE" \
  --sweep \
  > "$BASE/full.stdout" 2>&1 &
echo $! > "$BASE/full.pid"
echo "pid=$(cat "$BASE/full.pid")" >> "$BASE/launch.log"
cat "$BASE/launch.log"
