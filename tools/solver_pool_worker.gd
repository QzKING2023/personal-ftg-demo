extends SceneTree
## P6 可复用清扫 worker：常驻引擎进程，轮询控制目录里的 assignment.json 逐条
## 领任务（每任务一个 JSON 行文件 {"digest","descriptor"}），带看门狗资源预算
## 现算并经票据 06 fragment 机制入缓存。与 solver_sweep_worker.gd（一请求一进程）
## 保持同一 descriptor→现算语义；差异只在生命周期与资源控制：
##   - 看门狗（FTG_SOLVER_WATCHDOG_MS>0 时启用）：请求在安全点暂停并持久化快照
##     （<control>/resume/<digest>.json），每次暂停写 heartbeat.json（阶段计数 +
##     P0 profile_v2 计数）——编排器据此判存活/进展，卡死即杀即重启；
##   - 重启恢复：领到任务时若该 digest 已有可加载快照，直接 resume_analysis 续算
##     （跨进程、跨重启复用同一快照），续算完成的报告由 _sweep_store_completed
##     显式入缓存（resume 完成腿本身不回写）；
##   - 机器可读通道全部走文件（assignment.json / result.json / heartbeat.json，
##     整文件重写，坏读由编排器容错）；stdout 只留人读痕迹。
## 运行：godot --headless --path . -s res://tools/solver_pool_worker.gd
## 控制：FTG_POOL_CONTROL_DIR 必填；assignment {"seq":N,"task":"task-N.json"} 或
## {"seq":N,"stop":true} 优雅退出。

const CONTROL_ENV := "FTG_POOL_CONTROL_DIR"
const WATCHDOG_ENV := "FTG_SOLVER_WATCHDOG_MS"
const POLL_MS := 200
## 暂停次数硬顶：编排器看门狗是主防线，这里只兜「续算永远在同一点打转」的 runaway。
const MAX_PAUSES := 10000


func _initialize() -> void:
	var control := OS.get_environment(CONTROL_ENV)
	if control == "":
		push_error("pool worker 缺少 %s" % CONTROL_ENV)
		quit(1)
		return
	var watchdog_text := OS.get_environment(WATCHDOG_ENV)
	var watchdog_ms := int(watchdog_text) if watchdog_text.is_valid_int() else 0
	var resume_dir := control.path_join("resume")
	DirAccess.make_dir_recursive_absolute(resume_dir)
	var last_seq := -1
	var idle_announced := false
	while true:
		var assignment = _read_json(control.path_join("assignment.json"))
		if assignment is Dictionary:
			if bool((assignment as Dictionary).get("stop", false)):
				break
			var seq := int((assignment as Dictionary).get("seq", -1))
			var task_name := str((assignment as Dictionary).get("task", ""))
			if seq != last_seq and task_name != "":
				last_seq = seq
				idle_announced = false
				var outcome := _process_task(control, resume_dir, task_name, watchdog_ms)
				outcome["seq"] = last_seq
				print("SWEEP_WORKER_RESULT=" + JSON.stringify(outcome))
				_write_json(control.path_join("result.json"), outcome)
				continue
		if not idle_announced:
			idle_announced = true
			_write_json(control.path_join("heartbeat.json"), {
				"state": "idle", "wall_ms": Time.get_ticks_msec(),
			})
		OS.delay_msec(POLL_MS)
	quit(0)


func _process_task(control: String, resume_dir: String, task_name: String, watchdog_ms: int) -> Dictionary:
	var started := Time.get_ticks_msec()
	var task = _read_json(control.path_join(task_name))
	if not (task is Dictionary) or str((task as Dictionary).get("digest", "")) == "" \
			or str((task as Dictionary).get("descriptor", "")) == "":
		return _fail("", "任务文件不可读：%s" % task_name, started)
	var digest := str((task as Dictionary)["digest"])
	var descriptor := str((task as Dictionary)["descriptor"])
	var resume_path := resume_dir.path_join("%s.json" % digest)
	var overrides := {}
	if watchdog_ms > 0:
		overrides = {"watchdog_ms": watchdog_ms, "resume_path": resume_path}
	_write_json(control.path_join("heartbeat.json"), {
		"state": "running", "digest": digest, "pause": 0, "phase": "start",
		"wall_ms": started, "profile": {},
	})
	var report: ComboSolver.SolverReport = null
	var resumed := false
	if FileAccess.file_exists(resume_path) and _snapshot_loadable(resume_path):
		report = ComboSolver.resume_analysis(resume_path)
		if report != null and report.refused:
			## 快照 payload 损坏（表解码失败等）：如实放弃续算，回退整段重算。
			report = null
		else:
			resumed = true
	if report == null:
		var replay: Dictionary = ComboSolver._sweep_replay(descriptor, overrides)
		if not bool(replay.get("ok", false)):
			return _fail(digest, str(replay.get("error", "")), started)
		report = replay["report"]
	var pauses := 0
	while report != null and report.paused_incomplete:
		pauses += 1
		if pauses > MAX_PAUSES:
			return _fail(digest, "暂停次数超过硬顶 %d（续算疑似原地打转）" % MAX_PAUSES, started)
		_write_json(control.path_join("heartbeat.json"), _heartbeat(digest, pauses, resume_path))
		report = ComboSolver.resume_analysis(resume_path)
		if report == null or report.refused:
			return _fail(digest, "续算失败：快照不可恢复", started)
	if resumed or pauses > 0:
		var stored: Dictionary = ComboSolver._sweep_store_completed(descriptor, digest, report)
		if not bool(stored.get("ok", false)):
			return _fail(digest, str(stored.get("error", "")), started)
	return {
		"digest": digest, "ok": true, "error": "",
		"pauses": pauses, "resumed": resumed,
		"seconds": round((Time.get_ticks_msec() - started) / 1000.0 * 100) / 100.0,
	}


func _heartbeat(digest: String, pause: int, resume_path: String) -> Dictionary:
	var payload := {
		"state": "running", "digest": digest, "pause": pause,
		"phase": "", "sources_done": -1, "cycles_done": -1, "spatial_done": -1,
		"wall_ms": Time.get_ticks_msec(),
	}
	var snapshot = _read_json(resume_path)
	if snapshot is Dictionary:
		var progress = (snapshot as Dictionary).get("progress", {})
		if progress is Dictionary:
			payload["phase"] = str((progress as Dictionary).get("phase", ""))
			payload["sources_done"] = int((progress as Dictionary).get("sources_done", -1))
			payload["cycles_done"] = int((progress as Dictionary).get("cycles_done", -1))
			payload["spatial_done"] = int((progress as Dictionary).get("spatial_done", -1))
	payload["profile"] = ComboSolver.last_request_profile_v2()
	return payload


func _snapshot_loadable(path: String) -> bool:
	var parsed = _read_json(path)
	return parsed is Dictionary \
		and str((parsed as Dictionary).get("schema", "")) == ComboSolver._RESUME_SCHEMA_VERSION


func _read_json(path: String):
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	if text.strip_edges() == "":
		return null
	return JSON.parse_string(text)


func _write_json(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload))
	file.close()


func _fail(digest: String, error: String, started: int) -> Dictionary:
	return {
		"digest": digest, "ok": false, "error": error,
		"pauses": 0, "resumed": false,
		"seconds": round((Time.get_ticks_msec() - started) / 1000.0 * 100) / 100.0,
	}
