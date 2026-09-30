#!/usr/bin/env bash
ENGINE="D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe"
ROOT="D:/Godot/Program/ftgdemo"
RT="$ROOT/.scratch/acceptance-speedup/profile-03/default-table/runtime"
APPDATA="$(cygpath -w "$RT")" LOCALAPPDATA="$(cygpath -w "$RT")" \
	"$ENGINE" --headless --path "$ROOT" \
	--log-file "$(cygpath -w "$RT/engine.log")" \
	-s "res://.scratch/acceptance-speedup/profile-03/profile_runner.gd" \
	> "$ROOT/.scratch/acceptance-speedup/profile-03/default-table/runner.log" 2>&1
echo "exit=$?" > "$ROOT/.scratch/acceptance-speedup/profile-03/default-table/runner.exit"
