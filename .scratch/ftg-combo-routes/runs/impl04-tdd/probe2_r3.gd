extends SceneTree
## 票据 04 临时探测 v2：DFS 回溯逐键重锚 R3-B/R3-C。v1 贪心失败于 B 的 6A
##（5B#9 接地眩晕 6N vs 6A active 晚 1F——诊断发现让 5D#8 打在目标弧顶可使
## 5B#9 以空中资料命中）与 C 的 jC（jB 命中时玩家过高，纯几何）。v2 对每阶段
## 保留全部达标帧并按序回溯搜索。只读正式资源。
## 运行：D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe --headless --path . -s res://.scratch/ftg-combo-routes/runs/impl04-tdd/probe2_r3.gd

const HORIZON := 340
const PLACE_G := 2.0
const PLACE_R := 6.0
const NODE_BUDGET := 6000

var _nodes := 0


func _initialize() -> void:
	var out := {}
	for kind in ["B", "C"]:
		var result: Variant = _probe_route(kind)
		out[kind] = result
		print("=== R3-%s ===" % kind)
		if result.get("ok", false):
			print("成功(jump_mode=%d): " % int(result["jump_mode"]), result["anchors"])
			print("命中序列: ", result["hit_moves"], " 换边: ", result["swaps"],
				" 倒地帧: ", result["knock_frame"], " 倒地距墙: ", result["knock_wall_dist"])
		else:
			print("失败：", result.get("reason", ""), "（节点数 %d）" % _nodes)
	var file := FileAccess.open("res://.scratch/ftg-combo-routes/runs/impl04-tdd/probe2-r3-anchors.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(out, "  ", false))
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


## 逐阶段收集达标帧（progress ≥ want 且零换边）并递归回溯；每个节点的候选
## 在当前锚点下重新收集，使早期阶段的备选帧真正参与后续搜索。
func _probe_route(kind: String) -> Variant:
	for jump_mode in [0, 1]:
		_nodes = 0
		var stages := _stages(kind)
		var seq_len := SEQ_B.size() if kind == "B" else SEQ_C.size()
		var found: Variant = _search(kind, jump_mode, stages, 0, {"b1": 1} if kind == "B" else {"c1": 1}, seq_len)
		if found != null:
			return found
		print("R3-%s(jm=%d) 递归搜索未找到完整计划（节点 %d）" % [kind, jump_mode, _nodes])
	return {"ok": false, "reason": "两种跳向均未找到完整计划"}


func _search(kind: String, jump_mode: int, stages: Array, index: int, anchors: Dictionary, seq_len: int) -> Variant:
	if index == stages.size():
		_nodes += 1
		var final := _score(kind, 1, _build_plan(kind, 1, anchors, jump_mode))
		if final["progress"] == seq_len and final["knock_frame"] > 0 and final["swaps"].is_empty():
			return {
				"ok": true, "anchors": anchors.duplicate(), "jump_mode": jump_mode,
				"hit_moves": final["hit_moves"], "swaps": final["swaps"],
				"knock_frame": final["knock_frame"], "knock_wall_dist": final["knock_wall_dist"],
			}
		return null
	if _nodes > NODE_BUDGET:
		return null
	var stage: Dictionary = stages[index]
	var key: String = stage["key"]
	var base := int(anchors[stage["prev"]])
	var best_progress := -1
	var frames_at_best: Array[int] = []
	for offset in range(int(stage["lo"]), int(stage["hi"]) + 1):
		_nodes += 1
		var trial := anchors.duplicate()
		trial[key] = base + offset
		var score := _score(kind, 1, _build_plan(kind, 1, trial, jump_mode))
		if score["progress"] > best_progress:
			best_progress = score["progress"]
			frames_at_best = [base + offset]
		elif score["progress"] == best_progress:
			frames_at_best.append(base + offset)
	var ok: Array[int] = []
	for frame in frames_at_best:
		var trial := anchors.duplicate()
		trial[key] = frame
		var score := _score(kind, 1, _build_plan(kind, 1, trial, jump_mode))
		if score["progress"] >= int(stage["want"]) and score["swaps"].is_empty():
			ok.append(frame)
	if ok.is_empty():
		return null
	var mid := ok[ok.size() / 2]
	var ordered: Array[int] = ok.duplicate()
	ordered.sort_custom(func(a, b): return absi(a - mid) < absi(b - mid))
	for frame in ordered:
		var trial := anchors.duplicate()
		trial[key] = frame
		var found: Variant = _search(kind, jump_mode, stages, index + 1, trial, seq_len)
		if found != null:
			return found
	return null
