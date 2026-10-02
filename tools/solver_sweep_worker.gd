extends SceneTree
## 票据 08 全局前置清扫的 worker 入口：descriptor → 重算 → 写缓存 fragment。
## 编排器给每个任务一个 JSONL 文件（FTG_SWEEP_TASK_FILE，每行 {"digest",
## "descriptor"}），worker 逐条调 ComboSolver._sweep_replay 重建请求并现算——
## 存储路径即票据 06 的 fragment 写入（FTG_SOLVER_RESULT_CACHE_FRAGMENT 指向
## 本 worker 的 fragment，父目录由编排器预建）。结果逐行打印
## SWEEP_WORKER_RESULT={"digest": ..., "ok": ..., "error": ...}，任一失败 quit(1)。
## 运行：godot --headless --path . -s res://tools/solver_sweep_worker.gd

const TASK_FILE_ENV := "FTG_SWEEP_TASK_FILE"


func _initialize() -> void:
	var failures := 0
	var task_file := OS.get_environment(TASK_FILE_ENV)
	if task_file == "":
		push_error("SWEEP_WORKER_RESULT=" + JSON.stringify({"digest": "", "ok": false, "error": "缺少 " + TASK_FILE_ENV}))
		quit(1)
		return
	var file := FileAccess.open(task_file, FileAccess.READ)
	if file == null:
		push_error("SWEEP_WORKER_RESULT=" + JSON.stringify({"digest": "", "ok": false, "error": "无法读取任务文件"}))
		quit(1)
		return
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line == "":
			continue
		var parsed = JSON.parse_string(line)
		if not (parsed is Dictionary) or not (parsed as Dictionary).has("descriptor"):
			print("SWEEP_WORKER_RESULT=" + JSON.stringify({"digest": str((parsed as Dictionary).get("digest", "")) if parsed is Dictionary else "", "ok": false, "error": "任务行不是 JSON 对象"}))
			failures += 1
			continue
		var digest := str((parsed as Dictionary).get("digest", ""))
		var result: Dictionary = ComboSolver._sweep_replay(str((parsed as Dictionary).get("descriptor", "")))
		result["digest"] = digest
		print("SWEEP_WORKER_RESULT=" + JSON.stringify(result))
		if not bool(result.get("ok", false)):
			failures += 1
	quit(1 if failures > 0 else 0)
