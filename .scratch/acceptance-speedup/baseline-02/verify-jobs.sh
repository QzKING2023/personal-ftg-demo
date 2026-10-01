#!/usr/bin/env bash
# Ticket 02 pre-baseline fix verification for arbitrary jobs, in the
# orchestrator's per-job口径 (own APPDATA/LOCALAPPDATA, --log-file engine log,
# stdout to file, exit code to .exit). Each named job must show 0 FAIL lines
# and exit=0 before the serial full baseline relaunch.
# Usage: bash verify-jobs.sh <out-subdir> <job1> [job2 ...]
set -u
BASE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$BASE/../../.." && pwd)"
ENGINE="D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe"
OUT="$BASE/$1"
shift
mkdir -p "$OUT"

for job in "$@"; do
  RT="$OUT/runtime-$job"
  mkdir -p "$RT"
  (
    cd "$ROOT"
    APPDATA="$(cygpath -w "$RT")" LOCALAPPDATA="$(cygpath -w "$RT")" \
    "$ENGINE" --headless --path "$ROOT" \
      --log-file "$(cygpath -w "$RT/engine.log")" \
      -s "res://tests/$job.gd" > "$OUT/$job.log" 2>&1
    echo "exit=$?" > "$OUT/$job.exit"
  ) &
done
wait

overall=0
for job in "$@"; do
  fails=$(grep -c '^FAIL' "$OUT/$job.log")
  code=$(tr -d '\r\n' < "$OUT/$job.exit")
  echo "$job: FAIL=$fails $code"
  [ "$fails" -eq 0 ] && [ "$code" = "exit=0" ] || overall=1
done
echo "exit=$overall" > "$OUT/verify.status.txt"
[ "$overall" -eq 0 ] && echo "VERIFY PASS" || echo "VERIFY FAIL"
exit $overall
