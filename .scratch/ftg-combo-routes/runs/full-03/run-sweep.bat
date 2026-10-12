@echo off
set PYTHONIOENCODING=utf-8
cd /d D:\Godot\Program\ftgdemo
python tools/run_acceptance.py --sweep --output .scratch\ftg-combo-routes\runs\full-03 > .scratch\ftg-combo-routes\runs\full-03\sweep.log 2>&1
echo EXIT=%ERRORLEVEL% >> .scratch\ftg-combo-routes\runs\full-03\runner.status.txt
