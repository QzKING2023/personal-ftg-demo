#!/bin/bash
cd "D:/Godot/Program/ftgdemo"
export APPDATA="$(pwd)/.scratch/solver-delay-dp-01/appdata"
export LOCALAPPDATA="$(pwd)/.scratch/solver-delay-dp-01/appdata"
"D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe" --headless --path . -s res://.scratch/solver-delay-dp-01/probe5.gd > .scratch/solver-delay-dp-01/probe5.log 2>&1
echo "exit=$?" > .scratch/solver-delay-dp-01/probe5.status
