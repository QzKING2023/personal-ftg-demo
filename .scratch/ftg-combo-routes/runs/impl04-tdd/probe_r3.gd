extends SceneTree
## 票据 04 临时探测：在统一基准下为 R3-B/R3-C（原板边两轮普通 D，接 j2D 专用
## 出口倒地）顺序逐键重锚一套固定输入节奏。只读正式资源，不修改任何数据。
## 运行：D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe --headless --path . -s res://.scratch/ftg-combo-routes/runs/impl04-tdd/probe_r3.gd

const HORIZON := 340
const PLACE_G := 2.0
const PLACE_R := 6.0


func _initialize() -> void:
	var result_b := _probe_route("B")
	_report(result_b, "B")
	var result_c := _probe_route("C")
	_report(result_c, "C")
	var file := FileAccess.open("res://.scratch/ftg-combo-routes/runs/impl04-tdd/probe-r3-anchors.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"B": result_b, "C": result_c}, "  ", false))
	quit(0)


func _report(result: Dictionary, kind: String) -> void:
	print("=== R3-%s 探测 ===" % kind)
	if result.get("ok", false):
		print("成功锚点(jump_mode=%d): " % int(result["jump_mode"]), result["anchors"])
		print("命中序列: ", result["hit_moves"])
		print("换边: ", result["swaps"], "  首次倒地帧: ", result["knock_frame"],
			"  倒地时目标距墙: ", result["knock_wall_dist"])
		for line in result["windows"]:
			print("  窗口 ", line)
	else:
		print("失败：", result.get("reason", ""))
		for line in result.get("windows", []):
			print("  窗口 ", line)


# --- 布置与输入 ---

func _place(g: float, r: float, facing: int) -> CombatSession:
	var session := CombatSession.new()
	var wall := GameParams.stage_right_limit() if facing == 1 else GameParams.stage_left_limit()
	var dummy_x := wall - r * facing
	var player_x := dummy_x - facing * (GameParams.BODY_SIZE.x + g)
	session.player_position = Vector2(player_x, GameParams.ground_stand_y())
	session.dummy_position = Vector2(dummy_x, GameParams.ground_stand_y())
	session.player_facing = facing
	return session


func _press(key: String, axis := 0, down := false) -> FrameInput:
	var input := FrameInput.new()
	input.pressed_action_keys = [key]
	input.held_action_keys = [key]
	input.move_axis = axis
	input.down_held = down
	return input


func _direction(axis: int, down := false) -> FrameInput:
	var input := FrameInput.new()
	input.move_axis = axis
	input.down_held = down
	return input


func _jump(direction: int) -> FrameInput:
	var input := FrameInput.new()
	input.jump_pressed = true
	input.up_held = true
	if direction != 0:
		input.move_axis = direction
	return input


func _neutral() -> FrameInput:
	return FrameInput.new()


# --- 计划构造（anchors 只含已锚定的键；缺键跳过）---

const KEY_ORDER := ["b1", "c1", "m1", "d1", "b2", "c2", "m2", "d2", "b3", "a3", "jp", "jb", "jc", "jd", "r2", "tc"]


func _build_plan(kind: String, facing: int, anchors: Dictionary, jump_mode := 0) -> Dictionary:
	var plan := {}
	var fwd := facing
	var back := -facing
	for key in KEY_ORDER:
		if not anchors.has(key):
			continue
		var frame := int(anchors[key])
		match key:
			"b1", "b2", "b3":
				plan[frame] = _press("B")
			"c1", "c2", "tc":
				plan[frame] = _press("C")
			"m1", "m2":
				plan[frame - 3] = _direction(0, true)
				plan[frame - 2] = _direction(fwd, true)
				plan[frame - 1] = _direction(fwd)
				plan[frame] = _press("C", fwd)
			"d1", "d2":
				plan[frame] = _press("D")
			"a3":
				plan[frame] = _press("A", fwd)
			"jp":
				plan[frame] = _jump(0 if jump_mode == 0 else fwd)
			"jb":
				plan[frame] = _press("B")
			"jc":
				plan[frame] = _press("C")
			"jd":
				plan[frame] = _press("D", 0, true)
			"r2":
				plan[frame - 3] = _direction(0, true)
				plan[frame - 2] = _direction(back, true)
				plan[frame - 1] = _direction(back)
				plan[frame] = _press("C", back)
	return plan


# --- 运行与打分 ---

const SEQ_B := ["5B", "5C", "236C", "5D", "5B", "5C", "236C", "5D", "5B", "6A", "jB", "jC", "j2D", "214C", "214C~C"]
const SEQ_C := ["5C", "236C", "5D", "5B", "5C", "236C", "5D", "5B", "6A", "jB", "jC", "j2D", "214C", "214C~C"]


func _score(kind: String, facing: int, plan: Dictionary, horizon := HORIZON) -> Dictionary:
	var seq := SEQ_B if kind == "B" else SEQ_C
	var session := _place(PLACE_G, PLACE_R, facing)
	var wall := GameParams.stage_right_limit() if facing == 1 else GameParams.stage_left_limit()
	var hit_moves: Array[String] = []
	var swaps: Array[int] = []
	var end_frame := -1
	var end_reason := -1
	var knock_frame := -1
	var knock_dist := -1.0
	var progress := 0
	for frame in range(1, horizon + 1):
		var before_move := session.player_move_id
		for event in session.step(plan.get(frame, _neutral())):
			if event.type == CombatEvent.Type.HIT and end_frame < 0:
				if progress < seq.size() and before_move == seq[progress]:
					progress += 1
					hit_moves.append(before_move)
				else:
					hit_moves.append("#" + before_move)
			elif event.type == CombatEvent.Type.SWITCHED_SIDES:
				swaps.append(event.direction)
			elif event.type == CombatEvent.Type.COMBO_ENDED and end_frame < 0:
				end_frame = frame
				end_reason = event.combo_end_reason
		if knock_frame < 0 and session.dummy_state == CombatSession.DummyState.KNOCKED_DOWN:
			knock_frame = frame
			knock_dist = absf(session.dummy_position.x - wall)
	return {
		"hit_moves": hit_moves, "progress": progress, "swaps": swaps,
		"end_frame": end_frame, "end_reason": end_reason,
		"knock_frame": knock_frame, "knock_wall_dist": knock_dist,
	}


# --- 顺序逐键重锚 ---

func _stages(kind: String) -> Array:
	if kind == "B":
		return [
			{"key": "c1", "prev": "b1", "lo": 4, "hi": 28, "want": 2},
			{"key": "m1", "prev": "c1", "lo": 6, "hi": 34, "want": 3},
			{"key": "d1", "prev": "m1", "lo": 5, "hi": 24, "want": 4},
			{"key": "b2", "prev": "d1", "lo": 6, "hi": 40, "want": 5},
			{"key": "c2", "prev": "b2", "lo": 4, "hi": 28, "want": 6},
			{"key": "m2", "prev": "c2", "lo": 6, "hi": 34, "want": 7},
			{"key": "d2", "prev": "m2", "lo": 5, "hi": 24, "want": 8},
			{"key": "b3", "prev": "d2", "lo": 6, "hi": 40, "want": 9},
			{"key": "a3", "prev": "b3", "lo": 3, "hi": 22, "want": 10},
			{"key": "jp", "prev": "a3", "lo": 4, "hi": 30, "want": 10},
			{"key": "jb", "prev": "jp", "lo": 2, "hi": 24, "want": 11},
			{"key": "jc", "prev": "jb", "lo": 3, "hi": 20, "want": 12},
			{"key": "jd", "prev": "jc", "lo": 3, "hi": 20, "want": 13},
			{"key": "r2", "prev": "jd", "lo": 5, "hi": 34, "want": 14},
			{"key": "tc", "prev": "r2", "lo": 4, "hi": 26, "want": 15},
		]
	return [
		{"key": "m1", "prev": "c1", "lo": 5, "hi": 32, "want": 2},
		{"key": "d1", "prev": "m1", "lo": 5, "hi": 24, "want": 3},
		{"key": "b2", "prev": "d1", "lo": 6, "hi": 40, "want": 4},
		{"key": "c2", "prev": "b2", "lo": 4, "hi": 28, "want": 5},
		{"key": "m2", "prev": "c2", "lo": 6, "hi": 34, "want": 6},
		{"key": "d2", "prev": "m2", "lo": 5, "hi": 24, "want": 7},
		{"key": "b3", "prev": "d2", "lo": 6, "hi": 40, "want": 8},
		{"key": "a3", "prev": "b3", "lo": 3, "hi": 22, "want": 9},
		{"key": "jp", "prev": "a3", "lo": 4, "hi": 30, "want": 9},
		{"key": "jb", "prev": "jp", "lo": 2, "hi": 24, "want": 10},
		{"key": "jc", "prev": "jb", "lo": 3, "hi": 20, "want": 11},
		{"key": "jd", "prev": "jc", "lo": 3, "hi": 20, "want": 12},
		{"key": "r2", "prev": "jd", "lo": 5, "hi": 34, "want": 13},
		{"key": "tc", "prev": "r2", "lo": 4, "hi": 26, "want": 14},
	]


func _probe_route(kind: String) -> Dictionary:
	for jump_mode in [0, 1]:
		var anchors := {"b1": 1} if kind == "B" else {"c1": 1}
		var windows := []
		var failure := ""
		for stage in _stages(kind):
			var key: String = stage["key"]
			var base := int(anchors[stage["prev"]])
			var best_progress := -1
			var best_frames: Array[int] = []
			for offset in range(int(stage["lo"]), int(stage["hi"]) + 1):
				var trial := anchors.duplicate()
				trial[key] = base + offset
				var score := _score(kind, 1, _build_plan(kind, 1, trial, jump_mode))
				if score["progress"] > best_progress:
					best_progress = score["progress"]
					best_frames = [base + offset]
				elif score["progress"] == best_progress:
					best_frames.append(base + offset)
			var ok_frames: Array[int] = []
			for frame in best_frames:
				var trial := anchors.duplicate()
				trial[key] = frame
				var score := _score(kind, 1, _build_plan(kind, 1, trial, jump_mode))
				if score["progress"] >= int(stage["want"]) and score["swaps"].is_empty():
					ok_frames.append(frame)
			if ok_frames.is_empty():
				failure = "阶段 %s 无满足进度 %d 的帧（最佳进度 %d，候选 %s）" % [key, int(stage["want"]), best_progress, str(best_frames.slice(0, 8))]
				windows.append("%s: FAIL best=%d frames=%s" % [key, best_progress, str(best_frames.slice(0, 8))])
				break
			var chosen := ok_frames[ok_frames.size() / 2]
			anchors[key] = chosen
			windows.append("%s: [%d..%d] 选中 %d" % [key, ok_frames[0], ok_frames[ok_frames.size() - 1], chosen])
		if failure == "":
			var final := _score(kind, 1, _build_plan(kind, 1, anchors, jump_mode))
			var seq_len := SEQ_B.size() if kind == "B" else SEQ_C.size()
			if final["progress"] == seq_len and final["knock_frame"] > 0 and final["swaps"].is_empty():
				return {"ok": true, "anchors": anchors, "jump_mode": jump_mode, "windows": windows,
					"hit_moves": final["hit_moves"], "swaps": final["swaps"],
					"knock_frame": final["knock_frame"], "knock_wall_dist": final["knock_wall_dist"]}
			failure = "终局不满足（progress=%d knock=%d swaps=%d）" % [final["progress"], final["knock_frame"], final["swaps"].size()]
			windows.append("final(jump_mode=%d): %s | %s" % [jump_mode, failure, str(final["hit_moves"])])
		print("R3-%s jump_mode=%d 失败：%s" % [kind, jump_mode, failure])
		for line in windows:
			print("  窗口 ", line)
	return {"ok": false, "reason": "两种跳向均未找到完整计划", "windows": []}
