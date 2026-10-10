extends SceneTree
## 票据 04 临时探测 v5（聚焦笛卡尔积）：C 路 jb/jc/jd/r2/tc 各层收集全部达标帧
## 后做有界叉积；jd 偏好更晚（俯冲更深、命中-落地同帧），r2 覆盖 j2D 停顿内喂入。
## 运行：D:/Godot/Godot_v4.5.1-stable_mono_win64_console.exe --headless --path . -s res://.scratch/ftg-combo-routes/runs/impl04-tdd/probe5_r3.gd

const HORIZON := 340
const PLACE_G := 2.0
const PLACE_R := 6.0
const BUDGET := 20000


func _initialize() -> void:
	var result := _focused_c()
	print("=== R3-C 叉积 ===")
	if result.get("ok", false):
		print("成功: ", result["anchors"])
		print("命中序列: ", result["hit_moves"], " 换边: ", result["swaps"],
			" 倒地帧: ", result["knock_frame"], " 倒地距墙: ", result["knock_wall_dist"])
	else:
		print("失败：", result.get("reason", ""))
		for note in result.get("notes", []):
			print("  ", note)
	var file := FileAccess.open("res://.scratch/ftg-combo-routes/runs/impl04-tdd/probe5-r3-c.json", FileAccess.WRITE)
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
				plan[frame - 2] = _direction(1, true)
				plan[frame - 1] = _direction(1)
				plan[frame] = _press("C", 1)
			"d1", "d2":
				plan[frame] = _press("D")
			"a3":
				plan[frame] = _press("A", 1)
			"jp":
				plan[frame] = _jump()
			"jd":
				plan[frame] = _press("D", 0, true)
			"r2":
				plan[frame - 3] = _direction(0, true)
				plan[frame - 2] = _direction(-1, true)
				plan[frame - 1] = _direction(-1)
				plan[frame] = _press("C", -1)
	return plan


const SEQ_C := ["5C", "236C", "5D", "5B", "5C", "236C", "5D", "5B", "6A", "jB", "jC", "j2D", "214C", "214C~C"]


func _score(plan: Dictionary, horizon := HORIZON) -> Dictionary:
	var session := _place(PLACE_G, PLACE_R, 1)
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
			knock_dist = absf(session.dummy_position.x - GameParams.stage_right_limit())
	return {
		"hit_moves": hit_moves, "progress": progress, "swaps": swaps,
		"end_frame": end_frame, "knock_frame": knock_frame, "knock_wall_dist": knock_dist,
	}


func _collect(anchors: Dictionary, key: String, lo: int, hi: int, want: int) -> Array[int]:
	var out: Array[int] = []
	for frame in range(lo, hi + 1):
		var trial := anchors.duplicate()
		trial[key] = frame
		var score := _score(_build_plan(trial))
		if score["progress"] >= want and score["swaps"].is_empty():
			out.append(frame)
	return out


func _focused_c() -> Dictionary:
	var prefix := {"c1": 1, "m1": 15, "d1": 31, "b2": 61, "c2": 71, "m2": 89, "d2": 105, "b3": 133, "a3": 140}
	var budget := 0
	var notes := []
	for jp in [147, 152, 157, 162, 167]:
		var with_jp := prefix.duplicate()
		with_jp["jp"] = jp
		var jbs := _collect(with_jp, "jb", jp + 2, jp + 24, 10)
		budget += 23
		for jb in jbs:
			var with_jb := with_jp.duplicate()
			with_jb["jb"] = jb
			var jcs := _collect(with_jb, "jc", jb + 3, jb + 20, 11)
			budget += 18
			for jc in jcs:
				var with_jc := with_jb.duplicate()
				with_jc["jc"] = jc
				var jds := _collect(with_jc, "jd", jc + 3, jc + 24, 12)
				budget += 22
				for jd in jds:
					var with_jd := with_jc.duplicate()
					with_jd["jd"] = jd
					var r2s := _collect(with_jd, "r2", jd + 4, jd + 40, 13)
					budget += 37
					for r2 in r2s:
						var with_r2 := with_jd.duplicate()
						with_r2["r2"] = r2
						for tc in range(r2 + 4, r2 + 27):
							budget += 1
							var trial := with_r2.duplicate()
							trial["tc"] = tc
							var score := _score(_build_plan(trial))
							if score["progress"] == SEQ_C.size() and score["knock_frame"] > 0 and score["swaps"].is_empty():
								return {"ok": true, "anchors": trial, "hit_moves": score["hit_moves"],
									"swaps": score["swaps"], "knock_frame": score["knock_frame"],
									"knock_wall_dist": score["knock_wall_dist"], "budget": budget}
						if budget > BUDGET:
							return {"ok": false, "reason": "预算耗尽", "notes": notes, "budget": budget}
					notes.append("jp=%d jb=%d jc=%d jd=%d: r2 候选 %s" % [jp, jb, jc, jd, str(r2s)])
	return {"ok": false, "reason": "叉积未完成", "notes": notes.slice(0, 24), "budget": budget}
