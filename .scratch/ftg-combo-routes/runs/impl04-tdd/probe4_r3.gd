extends SceneTree
## 票据 04 临时探测 v4（聚焦）：C 路在 jB 窗口内逐帧前移（jB 命中高度递降），
## 其后 jC/jd/r2/tc 顺序扫描；目标是在 jC 命中框内接上 jC 并完成 j2D→214C~C。
## 运行：D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe --headless --path . -s res://.scratch/ftg-combo-routes/runs/impl04-tdd/probe4_r3.gd

const HORIZON := 340
const PLACE_G := 2.0
const PLACE_R := 6.0


func _initialize() -> void:
	var result := _focused_c()
	print("=== R3-C 聚焦 ===")
	if result.get("ok", false):
		print("成功: ", result["anchors"])
		print("命中序列: ", result["hit_moves"], " 换边: ", result["swaps"],
			" 倒地帧: ", result["knock_frame"], " 倒地距墙: ", result["knock_wall_dist"])
	else:
		print("失败：", result.get("reason", ""))
	var file := FileAccess.open("res://.scratch/ftg-combo-routes/runs/impl04-tdd/probe4-r3-c.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  ", false))
	quit(0)


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


func _jump() -> FrameInput:
	var input := FrameInput.new()
	input.jump_pressed = true
	input.up_held = true
	return input


func _neutral() -> FrameInput:
	return FrameInput.new()


func _build_plan(anchors: Dictionary) -> Dictionary:
	var plan := {}
	var fwd := 1
	var back := -1
	for key in ["c1", "m1", "d1", "b2", "c2", "m2", "d2", "b3", "a3", "jp", "jb", "jc", "jd", "r2", "tc"]:
		if not anchors.has(key):
			continue
		var frame := int(anchors[key])
		match key:
			"b2", "b3", "jb":
				plan[frame] = _press("B")
			"c1", "c2", "tc", "jc":
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
				plan[frame] = _jump()
			"jd":
				plan[frame] = _press("D", 0, true)
			"r2":
				plan[frame - 3] = _direction(0, true)
				plan[frame - 2] = _direction(back, true)
				plan[frame - 1] = _direction(back)
				plan[frame] = _press("C", back)
	return plan


const SEQ_C := ["5C", "236C", "5D", "5B", "5C", "236C", "5D", "5B", "6A", "jB", "jC", "j2D", "214C", "214C~C"]


func _score(plan: Dictionary, horizon := HORIZON) -> Dictionary:
	var session := _place(PLACE_G, PLACE_R, 1)
	var wall := GameParams.stage_right_limit()
	var hit_moves: Array[String] = []
	var swaps: Array[int] = []
	var end_frame := -1
	var knock_frame := -1
	var knock_dist := -1.0
	var progress := 0
	for frame in range(1, horizon + 1):
		var before_move := session.player_move_id
		for event in session.step(plan.get(frame, _neutral())):
			if event.type == CombatEvent.Type.HIT and end_frame < 0:
				if progress < SEQ_C.size() and before_move == SEQ_C[progress]:
					progress += 1
					hit_moves.append(before_move)
				else:
					hit_moves.append("#" + before_move)
			elif event.type == CombatEvent.Type.SWITCHED_SIDES:
				swaps.append(event.direction)
			elif event.type == CombatEvent.Type.COMBO_ENDED and end_frame < 0:
				end_frame = frame
		if knock_frame < 0 and session.dummy_state == CombatSession.DummyState.KNOCKED_DOWN:
			knock_frame = frame
			knock_dist = absf(session.dummy_position.x - wall)
	return {
		"hit_moves": hit_moves, "progress": progress, "swaps": swaps,
		"end_frame": end_frame, "knock_frame": knock_frame, "knock_wall_dist": knock_dist,
	}


func _focused_c() -> Dictionary:
	# 前缀（v1 贪心所得，已验证到 jB#10）。
	var prefix := {"c1": 1, "m1": 15, "d1": 31, "b2": 61, "c2": 71, "m2": 89, "d2": 105, "b3": 133, "a3": 140, "jp": 157}
	var notes := []
	for jb in range(168, 179):
		if not _progress_at(prefix, jb, 10):
			continue
		var anchors := prefix.duplicate()
		anchors["jb"] = jb
		# jc：全窗扫描。
		var jc_best := -1
		for jc in range(jb + 3, jb + 21):
			var trial := anchors.duplicate()
			trial["jc"] = jc
			if _score(_build_plan(trial))["progress"] >= 11:
				jc_best = jc
				break
		if jc_best < 0:
			notes.append("jb=%d: 无 jc" % jb)
			continue
		anchors["jc"] = jc_best
		var jd_best := -1
		for jd in range(jc_best + 3, jc_best + 21):
			var trial := anchors.duplicate()
			trial["jd"] = jd
			if _score(_build_plan(trial))["progress"] >= 12:
				jd_best = jd
				break
		if jd_best < 0:
			notes.append("jb=%d jc=%d: 无 jd" % [jb, jc_best])
			continue
		anchors["jd"] = jd_best
		var r2_best := -1
		for r2 in range(jd_best + 5, jd_best + 35):
			var trial := anchors.duplicate()
			trial["r2"] = r2
			if _score(_build_plan(trial))["progress"] >= 13:
				r2_best = r2
				break
		if r2_best < 0:
			notes.append("jb=%d jc=%d jd=%d: 无 r2" % [jb, jc_best, jd_best])
			continue
		anchors["r2"] = r2_best
		for tc in range(r2_best + 4, r2_best + 27):
			var trial := anchors.duplicate()
			trial["tc"] = tc
			var score := _score(_build_plan(trial))
			if score["progress"] == SEQ_C.size() and score["knock_frame"] > 0 and score["swaps"].is_empty():
				trial["ok_marker"] = true
				var out := trial.duplicate()
				out.erase("ok_marker")
				return {"ok": true, "anchors": out, "hit_moves": score["hit_moves"],
					"swaps": score["swaps"], "knock_frame": score["knock_frame"],
					"knock_wall_dist": score["knock_wall_dist"], "notes": notes}
		notes.append("jb=%d jc=%d jd=%d r2=%d: 无 tc" % [jb, jc_best, jd_best, r2_best])
	return {"ok": false, "reason": "聚焦扫描未完成", "notes": notes}


func _progress_at(prefix: Dictionary, jb: int, want: int) -> bool:
	var trial := prefix.duplicate()
	trial["jb"] = jb
	return _score(_build_plan(trial))["progress"] >= want
