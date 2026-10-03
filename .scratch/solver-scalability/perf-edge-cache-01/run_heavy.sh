#!/bin/bash
cd /d/Godot/Program/ftgdemo
E="D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe"
for t in test_combo_solver test_solver_route; do
  d=".scratch/solver-scalability/perf-edge-cache-01/appdata-$t"
  mkdir -p "$d"
  APPDATA="$(pwd)/$d" LOCALAPPDATA="$(pwd)/$d" "$E" --headless --path . -s "res://tests/$t.gd" > ".scratch/solver-scalability/perf-edge-cache-01/$t.log" 2>&1
  echo "$t exit=$?" >> .scratch/solver-scalability/perf-edge-cache-01/heavy.status.txt
done
echo done >> .scratch/solver-scalability/perf-edge-cache-01/heavy.status.txt
