#!/usr/bin/env bash
# Ticket 02 pre-baseline fix verification: single-job run of test_combo_solver
# in the orchestrator's per-job口径 (own APPDATA/LOCALAPPDATA, --log-file engine
# log, stdout to file, exit code to .exit). Must show 0 FAIL lines and exit=0
# before the serial full baseline may launch.
set -u
BASE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$BASE/../../.." && pwd)"
ENGINE="D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe"
OUT="$BASE/verify-fix"
RT="$OUT/runtime-test_combo_solver"
mkdir -p "$RT"

cd "$ROOT"
APPDATA="$(cygpath -w "$RT")" LOCALAPPDATA="$(cygpath -w "$RT")" \
"$ENGINE" --headless --path "$ROOT" \
  --log-file "$(cygpath -w "$RT/engine.log")" \
  -s "res://tests/test_combo_solver.gd" > "$OUT/test_combo_solver.log" 2>&1
echo "exit=$?" > "$OUT/test_combo_solver.exit"

fails=$(grep -c '^FAIL' "$OUT/test_combo_solver.log")
passes=$(grep -c '^PASS' "$OUT/test_combo_solver.log")
echo "FAIL=$fails PASS=$passes $(cat "$OUT/test_combo_solver.exit")"
if [ "$fails" -eq 0 ] && grep -q 'exit=0' "$OUT/test_combo_solver.exit"; then
  echo "exit=0" > "$OUT/verify.status.txt"
  echo "VERIFY PASS"
else
  echo "exit=1" > "$OUT/verify.status.txt"
  echo "VERIFY FAIL"
  exit 1
fi
