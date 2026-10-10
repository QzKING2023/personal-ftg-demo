extends SceneTree
## 票据 04 临时探测 v3：贪心锚点 + 相邻对（含三元组）爬山完成 R3 计划。
## v1/v2 教训：B 的 6A 断点与 C 的 jC 断点均非单键可解；jB/jC 与跳向强耦合。
## 另附 B 墙聚焦验证（5B#9 接地眩晕 6N vs 6A 最早 active 差 1F）。
## 运行：D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe --headless --path . -s res://.scratch/ftg-combo-routes/runs/impl04-tdd/probe3_r3.gd

const HORIZON := 340
const PLACE_G := 2.0
const PLACE_R := 6.0


func _initialize() -> void:
	for kind in ["C", "B"]:
		var result := _hill_climb(kind)
		print("=== R3-%s 爬山 ===" % kind)
		if result.get("ok", false):
			print("成功(jump_mode=%d): " % int(result["jump_mode"]), result["anchors"])
			print("命中序列: ", result["hit_moves"], " 换边: ", result["swaps"],
				" 倒地帧: ", result["knock_frame"], " 倒地距墙: ", result["knock_wall_dist"])
		else:
			print("失败：", result.get("reason", ""))
		var file := FileAccess.open("res://.scratch/ftg-combo-routes/runs/impl04-tdd/probe3-r3-%s.json" % kind, FileAccess.WRITE)
		file.store_string(JSON.stringify(result, "  ", false))
	_b_wall_check()
	quit(0)


# --- 布置与输入（同 v1）---

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
			"b1", "b2", "b3", "jb":
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
				plan[frame] = _jump(0 if jump_mode == 0 else fwd)
			"jd":
				plan[frame] = _press("D", 0, true)
			"r2":
				plan[frame - 3] = _direction(0, true)
				plan[frame - 2] = _direction(back, true)
				plan[frame - 1] = _direction(back)
				plan[frame] = _press("C", back)
	return plan


const SEQ_B := ["5B", "5C", "236C", "5D", "5B", "5C", "236C", "5D", "5B", "6A", "jB", "jC", "j2D", "214C", "214C~C"]
const SEQ_C := ["5C", "236C", "5D", "5B", "5C", "236C", "5D", "5B", "6A", "jB", "jC", "j2D", "214C", "214C~C"]


func _score(kind: String, facing: int, plan: Dictionary, horizon := HORIZON) -> Dictionary:
	var seq := SEQ_B if kind == "B" else SEQ_C
	var session := _place(PLACE_G, PLACE_R, facing)
	var wall := GameParams.stage_right_limit() if facing == 1 else GameParams.stage_left_limit()
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
				if progress < seq.size() and before_move == seq[progress]:
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


func _stages(kind: String) -> Array:
	if kind == "B":
		return [
			{"key": "c1", "prev": "b1", "lo": 4, "hi": 28, "want": 2},
			{"key": "m1", "prev": "c1", "lo": 6, "hi": 36, "want": 3},
			{"key": "d1", "prev": "m1", "lo": 5, "hi": 26, "want": 4},
			{"key": "b2", "prev": "d1", "lo": 6, "hi": 40, "want": 5},
			{"key": "c2", "prev": "b2", "lo": 4, "hi": 28, "want": 6},
			{"key": "m2", "prev": "c2", "lo": 6, "hi": 36, "want": 7},
			{"key": "d2", "prev": "m2", "lo": 5, "hi": 26, "want": 8},
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
		{"key": "m1", "prev": "c1", "lo": 5, "hi": 34, "want": 2},
		{"key": "d1", "prev": "m1", "lo": 5, "hi": 26, "want": 3},
		{"key": "b2", "prev": "d1", "lo": 6, "hi": 40, "want": 4},
		{"key": "c2", "prev": "b2", "lo": 4, "hi": 28, "want": 5},
		{"key": "m2", "prev": "c2", "lo": 6, "hi": 36, "want": 6},
		{"key": "d2", "prev": "m2", "lo": 5, "hi": 26, "want": 7},
		{"key": "b3", "prev": "d2", "lo": 6, "hi": 40, "want": 8},
		{"key": "a3", "prev": "b3", "lo": 3, "hi": 22, "want": 9},
		{"key": "jp", "prev": "a3", "lo": 4, "hi": 30, "want": 9},
		{"key": "jb", "prev": "jp", "lo": 2, "hi": 24, "want": 10},
		{"key": "jc", "prev": "jb", "lo": 3, "hi": 20, "want": 11},
		{"key": "jd", "prev": "jc", "lo": 3, "hi": 20, "want": 12},
		{"key": "r2", "prev": "jd", "lo": 5, "hi": 34, "want": 13},
		{"key": "tc", "prev": "r2", "lo": 4, "hi": 26, "want": 14},
	]


func _hill_climb(kind: String) -> Dictionary:
	for jump_mode in [0, 1]:
		var stages := _stages(kind)
		var seq_len := SEQ_B.size() if kind == "B" else SEQ_C.size()
		var anchors := {"b1": 1} if kind == "B" else {"c1": 1}
		# 阶段 1：贪心逐键（同 v1）。
		for stage in stages:
			var key: String = stage["key"]
			var base := int(anchors[stage["prev"]])
			var best_progress := -1
			var ok: Array[int] = []
			for offset in range(int(stage["lo"]), int(stage["hi"]) + 1):
				var trial := anchors.duplicate()
				trial[key] = base + offset
				var score := _score(kind, 1, _build_plan(kind, 1, trial, jump_mode))
				if score["progress"] > best_progress:
					best_progress = score["progress"]
					ok = [base + offset]
				elif score["progress"] == best_progress:
					ok.append(base + offset)
			var good: Array[int] = []
			for frame in ok:
				var trial := anchors.duplicate()
				trial[key] = frame
				var score := _score(kind, 1, _build_plan(kind, 1, trial, jump_mode))
				if score["progress"] >= int(stage["want"]) and score["swaps"].is_empty():
					good.append(frame)
			if good.is_empty():
				break
			anchors[key] = good[good.size() / 2]
		if anchors.size() <= stages.size():
			# 阶段 2：相邻对/三元组爬山。
			var improved := _climb(kind, jump_mode, stages, anchors, seq_len)
			if improved.get("ok", false):
				return improved
		var final := _score(kind, 1, _build_plan(kind, 1, anchors, jump_mode))
		if final["progress"] == seq_len and final["knock_frame"] > 0 and final["swaps"].is_empty():
			return {"ok": true, "anchors": anchors, "jump_mode": jump_mode, "hit_moves": final["hit_moves"],
				"swaps": final["swaps"], "knock_frame": final["knock_frame"], "knock_wall_dist": final["knock_wall_dist"]}
	return {"ok": false, "reason": "爬山未找到完整计划"}


## 相邻对与 (jp,jb,jc) 三元组的坐标下降；分数 = progress×1000 − 帧偏移平方和惩罚。
func _climb(kind: String, jump_mode: int, stages: Array, anchors: Dictionary, seq_len: int) -> Dictionary:
	var keys: Array[String] = []
	for stage in stages:
		keys.append(stage["key"])
	# 贪心断点之后缺失的键按典型相对间距补齐再爬山。
	var fills := {"jc": 7, "jd": 9, "r2": 15, "tc": 15, "a3": 6, "jp": 17, "jb": 17, "b3": 27}
	for key in keys:
		if not anchors.has(key):
			var idx := keys.find(key)
			var prev: int = anchors[keys[idx - 1]] if idx > 0 and anchors.has(keys[idx - 1]) else 1
			anchors[key] = prev + int(fills.get(key, 10))
	var best := _plan_score(kind, 1, anchors, jump_mode, seq_len)
	for iteration in range(12):
		var changed := false
		for group_start in range(keys.size() - 1):
			for size in [3, 2]:
				if group_start + size > keys.size():
					continue
				if size == 3 and not (keys[group_start] == "jp" or keys[group_start] == "a3"):
					continue
				var group := keys.slice(group_start, group_start + size)
				var base_frames := []
				for key in group:
					base_frames.append(int(anchors[key]))
				var best_local := best
				var best_local_frames := base_frames.duplicate()
				for a in range(-7, 8):
					for b in range(-7, 8):
						if size == 3:
							for c in range(-7, 8):
								var candidate_frames := [base_frames[0] + a, base_frames[1] + b, base_frames[2] + c]
								var trial := _apply_group(anchors, group, candidate_frames)
								var value := _plan_score(kind, 1, trial, jump_mode, seq_len)
								if value > best_local:
									best_local = value
									best_local_frames = candidate_frames
						else:
							var candidate_frames := [base_frames[0] + a, base_frames[1] + b]
							var trial := _apply_group(anchors, group, candidate_frames)
							var value := _plan_score(kind, 1, trial, jump_mode, seq_len)
							if value > best_local:
								best_local = value
								best_local_frames = candidate_frames
				if best_local > best:
					best = best_local
					anchors = _apply_group(anchors, group, best_local_frames)
					changed = true
				if best >= seq_len * 1000:
					break
			if best >= seq_len * 1000:
				break
		if not changed or best >= seq_len * 1000:
			break
	if best >= seq_len * 1000:
		var final := _score(kind, 1, _build_plan(kind, 1, anchors, jump_mode))
		if final["progress"] == seq_len and final["knock_frame"] > 0 and final["swaps"].is_empty():
			return {"ok": true, "anchors": anchors, "jump_mode": jump_mode, "hit_moves": final["hit_moves"],
				"swaps": final["swaps"], "knock_frame": final["knock_frame"], "knock_wall_dist": final["knock_wall_dist"]}
	return {"ok": false}


func _apply_group(anchors: Dictionary, group: Array, frames: Array) -> Dictionary:
	var trial := anchors.duplicate()
	for i in range(group.size()):
		trial[group[i]] = frames[i]
	return trial


func _plan_score(kind: String, facing: int, anchors: Dictionary, jump_mode: int, seq_len: int) -> int:
	var score := _score(kind, facing, _build_plan(kind, facing, anchors, jump_mode))
	var value := int(score["progress"]) * 1000
	if int(score["progress"]) == seq_len and int(score["knock_frame"]) > 0 and score["swaps"].is_empty():
		value += 500
	if not score["swaps"].is_empty():
		value -= 100
	return value


# --- B 墙聚焦验证：6A 在 5B#9 之后的最早可能 active 与目标恢复帧 ---

func _b_wall_check() -> void:
	print("=== B 墙验证：d2 × b3 × a3 全扫（5B#9 → 6A 是否可同连段命中）===")
	var found := 0
	var best_info := ""
	for d2 in range(109, 131):
		for b3 in range(d2 + 12, d2 + 45):
			var anchors := {"b1": 1, "c1": 12, "m1": 29, "d1": 45, "b2": 74, "c2": 79, "m2": 100, "d2": d2, "b3": b3}
			var base_score := _score("B", 1, _build_plan("B", 1, anchors))
			if base_score["progress"] < 9:
				continue
			for a3 in range(b3 + 3, b3 + 23):
				var trial := anchors.duplicate()
				trial["a3"] = a3
				var score := _score("B", 1, _build_plan("B", 1, trial))
				if score["progress"] >= 10 and score["swaps"].is_empty():
					found += 1
					if best_info == "":
						best_info = "d2=%d b3=%d a3=%d" % [d2, b3, a3]
	print("B: 5B#9 后 6A 同连段命中的组合数 = %d（%s）" % [found, best_info if best_info != "" else "无"])
