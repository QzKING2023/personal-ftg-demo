#!/bin/bash
cd /d/Godot/Program/ftgdemo
E="D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe"
d1=".scratch/solver-scalability/perf-edge-cache-01/appdata-diag2"; mkdir -p "$d1"
APPDATA="$(pwd)/$d1" LOCALAPPDATA="$(pwd)/$d1" "$E" --headless --path . -s "res://.scratch/solver-scalability/perf-edge-cache-01/reuse_diag_probe.gd" > .scratch/solver-scalability/perf-edge-cache-01/diag2.log 2>&1
echo "diag2 exit=$?" >> .scratch/solver-scalability/perf-edge-cache-01/final.status.txt
for t in test_combo_solver test_solver_route; do
  d=".scratch/solver-scalability/perf-edge-cache-01/appdata-$t-2"; mkdir -p "$d"
  APPDATA="$(pwd)/$d" LOCALAPPDATA="$(pwd)/$d" "$E" --headless --path . -s "res://tests/$t.gd" > ".scratch/solver-scalability/perf-edge-cache-01/$t-2.log" 2>&1
  echo "$t-2 exit=$?" >> .scratch/solver-scalability/perf-edge-cache-01/final.status.txt
done
echo done >> .scratch/solver-scalability/perf-edge-cache-01/final.status.txt
