@echo off
set APPDATA=C:\Users\q1625\AppData\Roaming_ftg_tests\cs01
cd /d D:\Godot\Program\ftgdemo
"D:\Godot\Godot_v4.5.1-stable_mono_win64.exe" --headless --path . -s res://.scratch/ftg-combo-routes/runs/impl01-tdd/probe_cs_air.gd > .scratch\ftg-combo-routes\runs\impl01-tdd\cs-air.log 2>&1
echo EXIT=%ERRORLEVEL% >> .scratch\ftg-combo-routes\runs\impl01-tdd\cs-air.log
