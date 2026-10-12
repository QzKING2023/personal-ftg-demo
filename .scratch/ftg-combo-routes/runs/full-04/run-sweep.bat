@echo off
set PYTHONIOENCODING=utf-8
cd /d D:\Godot\Program\ftgdemo
python tools/run_acceptance.py --sweep --output .scratch\ftg-combo-routes\runs\full-04 > .scratch\ftg-combo-routes\runs\full-04\sweep.log 2>&1
echo EXIT=%ERRORLEVEL% >> .scratch\ftg-combo-routes\runs\full-04\runner.status.txt
