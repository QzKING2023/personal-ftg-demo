#!/bin/bash
cd /d/Godot/Program/ftgdemo
APPDATA="/d/Godot/Program/ftgdemo/.scratch/solver-scalability/perf-edge-cache-01/appdata-diag" LOCALAPPDATA="/d/Godot/Program/ftgdemo/.scratch/solver-scalability/perf-edge-cache-01/appdata-diag" "D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe" --headless --path . -s "res://.scratch/solver-scalability/perf-edge-cache-01/reuse_diag_probe.gd" > .scratch/solver-scalability/perf-edge-cache-01/diag.log 2>&1
echo "diag exit=$?" >> .scratch/solver-scalability/perf-edge-cache-01/heavy.status.txt
