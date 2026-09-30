#!/usr/bin/env bash
# 票据 03 插桩前基线:test_combo_solver 与 test_solver_route 在当前(未插桩)树上的
# 定向运行。与 tools/run_acceptance.py 的单 job 口径一致:独立 APPDATA、
# --log-file 引擎日志、stdout 落盘、退出码写 .exit 文件。
set -u
ENGINE="D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe"
ROOT="D:/Godot/Program/ftgdemo"
OUT="$ROOT/.scratch/acceptance-speedup/profile-03/before"

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
