@echo off
set APPDATA=C:\Users\q1625\AppData\Roaming_ftg_tests\fix201
cd /d D:\Godot\Program\ftgdemo
"D:\Godot\Godot_v4.5.1-stable_mono_win64.exe" --headless --path . -s res://tests/test_solver_spatial.gd > .scratch\ftg-combo-routes\runs\impl01-tdd\spatial-recheck.log 2>&1
echo EXIT=%ERRORLEVEL% >> .scratch\ftg-combo-routes\runs\impl01-tdd\spatial-recheck.log
"D:\Godot\Godot_v4.5.1-stable_mono_win64.exe" --headless --path . -s res://tests/test_combo_solver.gd > .scratch\ftg-combo-routes\runs\impl01-tdd\combo-solver-recheck.log 2>&1
echo EXIT=%ERRORLEVEL% >> .scratch\ftg-combo-routes\runs\impl01-tdd\combo-solver-recheck.log
