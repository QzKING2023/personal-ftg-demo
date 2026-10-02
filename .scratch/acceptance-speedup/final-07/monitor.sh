#!/usr/bin/env bash
# Lightweight progress monitor for the ticket-07 cold full run: appends one
# status line every 5 minutes (wall, stdout lines, tasks dispatched/finished,
# fragments merged into canonical cache, stage files present).
set -u
BASE="$(cd "$(dirname "$0")" && pwd)"
while true; do
  if [ -e "$BASE/full/runner.status.txt" ]; then
    echo "$(date '+%F %T') DONE status=$(cat "$BASE/full/runner.status.txt")" >> "$BASE/monitor.log"
    exit 0
  fi
  out_lines=$(wc -l < "$BASE/full.stdout" 2>/dev/null || echo 0)
  tasks=$(ls "$BASE/full/sweep/workers"/task-*.json 2>/dev/null | wc -l)
  frags=$(ls "$BASE/full/sweep/workers"/worker-*.fragment 2>/dev/null | wc -l)
  echo "$(date '+%F %T') stdout_lines=$out_lines tasks=$tasks fragments=$frags" >> "$BASE/monitor.log"
  sleep 300
done
