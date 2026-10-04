import os
import pathlib
import subprocess
import sys
import time

root = pathlib.Path(__file__).resolve().parents[2]
name, script = sys.argv[1:3]
out = root / '.scratch/solver-recovery-followup' / name
out.mkdir(parents=True, exist_ok=True)
env = os.environ.copy()
env['APPDATA'] = str(out / 'appdata')
env['LOCALAPPDATA'] = str(out / 'localappdata')
env['PYTHONIOENCODING'] = 'utf-8'
for key in list(env):
    if key.startswith('FTG_'):
        del env[key]
start = time.monotonic()
with (out / 'output.log').open('w', encoding='utf-8') as log:
    result = subprocess.run(['D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe',
        '--headless', '--path', str(root), '-s', script, *sys.argv[3:]],
        cwd=root, env=env, stdout=log, stderr=subprocess.STDOUT)
(out / 'status.txt').write_text(f'exit={result.returncode}\nseconds={time.monotonic()-start:.3f}\n')
print((out / 'output.log').read_text(encoding='utf-8'))
sys.exit(result.returncode)
