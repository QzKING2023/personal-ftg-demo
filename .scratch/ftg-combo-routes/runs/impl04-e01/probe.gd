extends SceneTree
## 一次性探针（不入库）：2C 挥空/命中逐帧、倒地后 B 的木桩状态边界。

func _initialize() -> void:
	# A) 中立 2C（下+C F1）挥空逐帧 move_id/move.frame/phase。
	var s1 := CombatSession.new()
	s1.dummy_position = s1.player_position + Vector2(300.0, 0)
	print("=== whiff 2C per-frame ===")
	for frame in range(1, 40):
		var input := FrameInput.new()
		if frame == 1:
			input.down_held = true
			input.pressed_action_keys = ["C"]
			input.held_action_keys = ["C"]
		for event in s1.step(input):
			print("F%d event %s" % [frame, CombatEvent.Type.keys()[event.type]])
		var st = s1.clone_state()
		if frame >= 2 and frame <= 34:
			print("F%d move=%s move_frame=%s phase=%s" % [frame, st.player_move.move_id, str(st.player_move.frame), CombatSession.PlayerPhase.keys()[st.player.phase]])
	# B) 命中逐帧。
	var s2 := CombatSession.new()
	s2.dummy_position = s2.player_position + Vector2(14.0, 0)
	print("=== hit 2C per-frame ===")
	var hit_frame := -1
	for frame in range(1, 40):
		var input := FrameInput.new()
		if frame == 1:
			input.down_held = true
			input.pressed_action_keys = ["C"]
			input.held_action_keys = ["C"]
		for event in s2.step(input):
			if event.type == CombatEvent.Type.HIT or event.type == CombatEvent.Type.COMBO_ENDED or event.type == CombatEvent.Type.LOW_FLOAT_LANDED:
				print("F%d event %s" % [frame, CombatEvent.Type.keys()[event.type]])
		var st = s2.clone_state()
		if frame <= 32:
			print("F%d move=%s mf=%s ds=%s" % [frame, st.player_move.move_id, str(st.player_move.frame), CombatSession.DummyState.keys()[s2.dummy_state]])
	# C) R3-B 完整两轮后 F200 按 B：木桩逐状态 + 恢复事件帧。
	print("=== post-knock B probe ===")
	var plan := {}
	plan[1] = _p("B")
	plan[12] = _p("C")
	_m236(plan, 29)
	plan[45] = _p("D")
	plan[74] = _p("B")
	plan[79] = _p("C")
	_m236(plan, 100)
	plan[117] = _p("D")
	plan[143] = _p("B")
	plan[149] = _mk("C", true)
	plan[200] = _p("B")
	var s3 := _place(9.3, 6.7)
	for frame in range(1, 240):
		for event in s3.step(plan.get(frame, FrameInput.new())):
			if event.type in [CombatEvent.Type.HIT, CombatEvent.Type.COMBO_ENDED, CombatEvent.Type.DUMMY_RECOVERED, CombatEvent.Type.LOW_FLOAT_LANDED, CombatEvent.Type.LINK_FAILED]:
				print("F%d ev %s reason=%s" % [frame, CombatEvent.Type.keys()[event.type], str(event.combo_end_reason) + "/" + str(event.link_fail_reason)])
		if frame >= 195:
			var st = s3.clone_state()
			print("F%d p_move=%s ds=%s" % [frame, st.player_move.move_id, CombatSession.DummyState.keys()[s3.dummy_state]])
	quit(0)


func _p(key: String) -> FrameInput:
	var input := FrameInput.new()
	input.pressed_action_keys = [key]
	input.held_action_keys = [key]
	return input


func _mk(key: String, down: bool) -> FrameInput:
	var input := _p(key)
	input.down_held = down
	return input


func _m236(plan: Dictionary, t: int) -> void:
	plan[t - 3] = _d(0, true)
	plan[t - 2] = _d(1, true)
	plan[t - 1] = _d(1)
	plan[t] = _mk2("C", 1)
	plan[t + 1] = FrameInput.new()


func _mk2(key: String, axis: int) -> FrameInput:
	var input := _p(key)
	input.move_axis = axis
	return input


func _d(axis: int, down := false) -> FrameInput:
	var input := FrameInput.new()
	input.move_axis = axis
	input.down_held = down
	return input


func _place(g: float, r: float) -> CombatSession:
	var session := CombatSession.new()
	var wall := GameParams.stage_right_limit()
	var dummy_x := wall - r
	session.dummy_position = Vector2(dummy_x, GameParams.ground_stand_y())
	session.player_position = Vector2(dummy_x - (GameParams.BODY_SIZE.x + g), GameParams.ground_stand_y())
	session.player_facing = 1
	return session
