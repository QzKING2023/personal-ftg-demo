extends SceneTree
## 票据 04 临时诊断：打印 R3 计划在指定帧区间的逐帧状态（玩家招式/阶段/位置、
## 木桩状态/位置/硬直余量、事件），定位 B 的 6A 断点与 C 的 jC 断点。
## 用法：修改下方 kind/anchors/frame 范围后运行。

const PLACE_G := 2.0
const PLACE_R := 6.0


func _initialize() -> void:
	var anchors_b := {"b1": 1, "c1": 12, "m1": 29, "d1": 45, "b2": 74, "c2": 79, "m2": 100, "d2": 117, "b3": 144, "a3": 151, "jp": 160, "jb": 168, "jc": 181, "jd": 190, "r2": 205, "tc": 220}
	var anchors_c := {"c1": 1, "m1": 15, "d1": 31, "b2": 61, "c2": 71, "m2": 89, "d2": 105, "b3": 133, "a3": 140, "jp": 157, "jb": 170, "jc": 174, "jd": 198, "r2": 213, "tc": 228}
	_dump("B", anchors_b, 140, 185)
	_dump("C", anchors_c, 190, 265)
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


func _build_plan(kind: String, facing: int, anchors: Dictionary) -> Dictionary:
	var plan := {}
	var fwd := facing
	var back := -facing
	for key in ["b1", "c1", "m1", "d1", "b2", "c2", "m2", "d2", "b3", "a3", "jp", "jb", "jc", "jd", "r2", "tc"]:
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
				plan[frame] = _jump(0)
			"jd":
				plan[frame] = _press("D", 0, true)
			"r2":
				plan[frame - 3] = _direction(0, true)
				plan[frame - 2] = _direction(back, true)
				plan[frame - 1] = _direction(back)
				plan[frame] = _press("C", back)
	return plan


func _dump(kind: String, anchors: Dictionary, from_frame: int, to_frame: int) -> void:
	print("=== R3-%s 逐帧（F%d–F%d）===" % [kind, from_frame, to_frame])
	var session := _place(PLACE_G, PLACE_R, 1)
	var plan := _build_plan(kind, 1, anchors)
	for frame in range(1, to_frame + 1):
		var before_move := session.player_move_id
		var input: FrameInput = plan.get(frame, _neutral())
		var tags := ""
		if input.pressed_action_keys.size() > 0:
			tags += " press=" + str(input.pressed_action_keys)
		if input.move_axis != 0 or input.down_held or input.up_held or input.jump_pressed:
			tags += " axis=%d%s%s%s" % [input.move_axis, " dn" if input.down_held else "", " up" if input.up_held else "", " JUMP" if input.jump_pressed else ""]
		var events := session.step(input)
		var event_text := ""
		for event in events:
			match event.type:
				CombatEvent.Type.HIT:
					event_text += " HIT(%s,#%d)" % [before_move, event.combo_hits]
				CombatEvent.Type.HIT_MISS:
					event_text += " MISS(%s seg%d)" % [before_move, event.combo_hits]
				CombatEvent.Type.COMBO_ENDED:
					event_text += " END(%d)" % event.combo_end_reason
				CombatEvent.Type.SWITCHED_SIDES:
					event_text += " SWAP"
				CombatEvent.Type.HITSTOP_STARTED:
					event_text += " HS+"
				CombatEvent.Type.HITSTOP_ENDED:
					event_text += " HS-"
				CombatEvent.Type.LINK_FAILED:
					event_text += " LINKFAIL(%d)" % event.link_fail_reason
				CombatEvent.Type.DUMMY_RECOVERED:
					event_text += " DUMMY_OK"
				_:
					event_text += " E%d" % event.type
		if frame >= from_frame or event_text != "":
			print("F%-4d %-6s ph%-2d y=%-7.1f x=%-7.1f | dummy st%-2d y=%-7.2f x=%-7.1f stun=%-3d ch=%-2d%s%s" % [
				frame, session.player_move_id, session.player_phase,
				session.player_position.y, session.player_position.x,
				session.dummy_state, session.dummy_position.y, session.dummy_position.x,
				session.dummy_hitstun_left, session.combo_hits,
				event_text, tags])
