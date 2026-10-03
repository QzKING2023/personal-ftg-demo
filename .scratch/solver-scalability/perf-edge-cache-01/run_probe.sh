#!/bin/bash
cd /d/Godot/Program/ftgdemo
APPDATA="/d/Godot/Program/ftgdemo/.scratch/solver-scalability/perf-edge-cache-01/appdata-default-probe" LOCALAPPDATA="/d/Godot/Program/ftgdemo/.scratch/solver-scalability/perf-edge-cache-01/appdata-default-probe" "D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe" --headless --path . -s "res://.scratch/solver-scalability/perf-edge-cache-01/default_edge_probe.gd" > .scratch/solver-scalability/perf-edge-cache-01/default-probe.log 2>&1
echo "probe exit=$?" >> .scratch/solver-scalability/perf-edge-cache-01/heavy.status.txt
