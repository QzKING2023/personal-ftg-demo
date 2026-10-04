extends SceneTree

func _digest(tag: String, table: Dictionary) -> void:
	var opts := ComboSolver.SolverOptions.new()
	opts.move_table = table
	var r: Dictionary = ComboSolver._build_solve_request(true, opts, table, true)
	print(tag, " digest=", str(r["digest"]).substr(0, 20))

func _initialize() -> void:
	var t1 := MoveData.default_table()
	(t1["5B"] as MoveData).cancel_targets = ["5D", "5A"]
	_digest("t1-first ", t1)
	## 模拟后续测试的注入变体（慢回边 + 上浮回边）
	var slow := _slow_self_loop()
	_digest("slow     ", {"5Z": slow})
	var t1b := MoveData.default_table()
	(t1b["5B"] as MoveData).cancel_targets = ["5D", "5A"]
	_digest("t1-rebld ", t1b)
	var plain := MoveData.default_table()
	_digest("plain    ", plain)
	quit(0)

func _slow_self_loop() -> MoveData:
	var slow := _injected_move("5Z", "Z")
	slow.startup_frames = 2300
	slow.active_frames = 2
	slow.recovery_frames = 5
	_set_probe_stun(slow, 2450)
	_set_probe_horizontal(slow, 0.0)
	slow.cancel_targets = ["5Z"]
	return slow

func _injected_move(new_id: String, key: String) -> MoveData:
	var move := MoveData.default_table()["5A"].duplicate() as MoveData
	move.move_id = new_id
	move.action_key = key
	move.direction_derivation = ""
	return move

func _set_probe_stun(move: MoveData, frames: int) -> void:
	for profile in move.hit_profiles:
		profile.ground_stun_frames = frames

func _set_probe_horizontal(move: MoveData, speed: float) -> void:
	for profile in move.hit_profiles:
		profile.horizontal_speed_px_s = speed
