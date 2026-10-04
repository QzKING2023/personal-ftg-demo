#!/bin/bash
t=$1
cd /d/Godot/Program/ftgdemo
APPDATA="$(pwd)/.scratch/solver-checkpoint-01/heavy/$t/appdata" LOCALAPPDATA="$(pwd)/.scratch/solver-checkpoint-01/heavy/$t/localappdata" "D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe" --headless --path . -s res://tests/$t.gd > .scratch/solver-checkpoint-01/heavy/$t.log 2>&1
echo "exit=$?" > .scratch/solver-checkpoint-01/heavy/$t.status.txt
