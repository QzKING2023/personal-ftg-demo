@echo off
set APPDATA=C:\Users\q1625\AppData\Roaming_ftg_tests\cpt01
cd /d D:\Godot\Program\ftgdemo
"D:\Godot\Godot_v4.5.1-stable_mono_win64.exe" --headless --path . -s res://tests/test_solver_checkpoint_trie.gd > .scratch\ftg-combo-routes\runs\impl01-tdd\cpt-recheck.log 2>&1
echo EXIT=%ERRORLEVEL% >> .scratch\ftg-combo-routes\runs\impl01-tdd\cpt-recheck.log
