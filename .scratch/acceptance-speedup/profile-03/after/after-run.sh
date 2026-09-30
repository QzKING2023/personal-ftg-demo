#!/usr/bin/env bash
# 票据 03 插桩后对照:与 before-run.sh 完全同构(同引擎、同参数、同隔离口径),
# 唯一区别是树已带插桩。比较用 compare_jobs.py。
set -u
ENGINE="D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe"
ROOT="D:/Godot/Program/ftgdemo"
OUT="$ROOT/.scratch/acceptance-speedup/profile-03/after"

run_job() {
	local name="$1"
	local rt="$OUT/runtime-$name"
	mkdir -p "$rt"
	APPDATA="$(cygpath -w "$rt")" LOCALAPPDATA="$(cygpath -w "$rt")" \
		"$ENGINE" --headless --path "$ROOT" \
		--log-file "$(cygpath -w "$rt/engine.log")" \
		-s "res://tests/$name.gd" > "$OUT/$name.log" 2>&1
	echo "exit=$?" > "$OUT/$name.exit"
}

run_job test_combo_solver &
run_job test_solver_route &
wait
echo "done" > "$OUT/all.exit"
