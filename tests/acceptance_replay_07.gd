extends SceneTree
## 票据 07 验收回放：6A jump cancel 空中链、6D/2D 对空限定、真实上升与空中出口。
## 覆盖：R1 演示路线 5A>5B>5C>6A>jc.jB>jC（双面向）；R2 2C>6D>jC 低浮空捞起
## +真实上升+空中出口（双面向）；R2b 6D 命中后不取出口的完整位移穿越；R3 2C 后
## 2D 高位挥空与 5D 时序失败；R4 6D/2D 对地拒绝（MISS_NO_PROFILE / 高位越过）；
## R5 2D 对空正例 + jA 出口 + 有限空中资源；R6 版边墙截断与被防不穿越。
## 运行：godot --headless --path . -s res://tests/acceptance_replay_07.gd
## 证据归档 acceptance/07/（replay-routes.log）。

const NEAR_DX := 50.0

var _failures := 0


func _initialize() -> void:
	_replay_r1_jump_cancel_route(1)
	_replay_r1_jump_cancel_route(-1)
	_replay_r2_2c_6d_jc(1)
	_replay_r2_2c_6d_jc(-1)
	_replay_r2b_6d_full_cross(1)
	_replay_r2b_6d_full_cross(-1)
	_replay_r3_2d_height_and_5d_timing(1)
	_replay_r4_ground_rejection(1)
	_replay_r5_2d_airborne_exit_and_air_resource(1)
	_replay_r6_wall_clamp_and_blocked(1)
	_replay_r6_wall_clamp_and_blocked(-1)
	print("")
	if _failures == 0:
		print("ALL REPLAY 07 CHECKS PASSED")
		quit(0)
	else:
		print(str(_failures) + " REPLAY 07 CHECK(S) FAILED")
		quit(1)


func _spawn(dx: float, facing: int) -> CombatSession:
	var session := CombatSession.new()
	if facing == 1:
		session.dummy_position = session.player_position + Vector2(dx, 0)
	else:
		session.dummy_position = session.player_position - Vector2(dx, 0)
		session.player_facing = -1
	return session


func _press(key: String, down := false, axis := 0) -> FrameInput:
	var input := FrameInput.new()
	if key != "":
		input.pressed_action_keys = [key]
		input.held_action_keys = [key]
	input.down_held = down
	input.move_axis = axis
	return input


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  " + label)
	else:
		_failures += 1
		print("  FAIL  " + label)


func _log_event(frame: int, tag: String, event: CombatEvent, session: CombatSession) -> void:
	match event.type:
		CombatEvent.Type.HIT:
			print("  F%-3d %s HIT seg%d 伤%.1f 第%d击 玩家y=%.1f 木桩y=%.1f" % [
				frame, tag, event.move_segment, event.damage, event.combo_hits,
				session.player_position.y, session.dummy_position.y])
		CombatEvent.Type.HIT_MISS:
			print("  F%-3d %s HIT_MISS（无 grounded 资料，不回退）%s" % [frame, tag, session.player_move_id])
		CombatEvent.Type.ATTACK_BLOCKED:
			print("  F%-3d %s ATTACK_BLOCKED 姿态%d 玩家x=%.1f 木桩x=%.1f" % [
				frame, tag, event.guard_posture, session.player_position.x, session.dummy_position.x])
		CombatEvent.Type.SWITCHED_SIDES:
			print("  F%-3d %s SWITCHED_SIDES 新面向%d（下一帧生效）" % [frame, tag, event.direction])
		CombatEvent.Type.COMBO_ENDED:
			print("  F%-3d %s COMBO_ENDED 原因%d" % [frame, tag, event.combo_end_reason])
		CombatEvent.Type.LINK_FAILED:
			print("  F%-3d %s LINK_FAILED 原因%d %s" % [frame, tag, event.link_fail_reason, event.link_move_id])
		CombatEvent.Type.DUMMY_RECOVERED:
			print("  F%-3d %s DUMMY_RECOVERED" % [frame, tag])


## R1 演示路线：5A > 5B > 5C > 6A > jc.jB > jC——每段链在上一击 Hitstop 中按下，
## Space 于 6A 命中确认窗口内消费进入 pre-jump，jB/jC 按空中姿态解析起手。
func _replay_r1_jump_cancel_route(facing: int) -> void:
	var session := _spawn(NEAR_DX, facing)
	print("=== R1 演示路线 5A>5B>5C>6A>jc.jB>jC | 面向 %d | 起始间距 %.0f px ===" % [facing, NEAR_DX])
	var hit_moves: Array[String] = []
	var hit_frames: Array[int] = []
	var prejump_frame := -1
	var takeoff_frame := -1
	for frame in range(1, 110):
		var input := FrameInput.new()
		match frame:
			1: input = _press("A")
			9: input = _press("B")
			24: input = _press("C")
			38: input = _press("A", false, facing)
			39: input.move_axis = facing
			56: input.jump_pressed = true
			68: input = _press("B")
			76: input = _press("C")
		var move_at_start := session.player_move_id
		for event in session.step(input):
			_log_event(frame, "R1", event, session)
			if event.type == CombatEvent.Type.HIT:
				hit_moves.append(move_at_start)
				hit_frames.append(frame)
		if session.player_prejump_left > 0 and prejump_frame < 0:
			prejump_frame = frame
		if not session.player_on_ground and takeoff_frame < 0 and prejump_frame > 0:
			takeoff_frame = frame
	_check(hit_moves == ["5A", "5B", "5C", "6A", "jB", "jC"],
		"R1 路线按 5A>5B>5C>6A>jc.jB>jC 六击成立（命中帧 %s）" % str(hit_frames))
	_check(prejump_frame > 0 and takeoff_frame == prejump_frame + GameParams.PLAYER_PREJUMP_FRAMES,
		"R1 Space 在 6A 命中确认窗口内进入 pre-jump（F%d），%d 帧后真实离地（F%d）" % [
			prejump_frame, GameParams.PLAYER_PREJUMP_FRAMES, takeoff_frame])
	print("")


## R2：2C 命中低浮空 → 链式 6D 捞起浮空（对空资料）→ 6D 计划位移真实上升 →
## 空中出口 jC（停顿中按下、空中姿态解析、恢复首个正常帧消费）。
func _replay_r2_2c_6d_jc(facing: int) -> void:
	var session := _spawn(NEAR_DX, facing)
	print("=== R2 2C>6D>jC 低浮空捞起 + 空中出口 | 面向 %d | 起始间距 %.0f px ===" % [facing, NEAR_DX])
	var hit_moves: Array[String] = []
	var hit_frames: Array[int] = []
	var peak_height := 0.0
	var exit_frame := -1
	var airborne_at_exit := false
	for frame in range(1, 70):
		var input := FrameInput.new()
		match frame:
			1: input = _press("C", true)
			2: input.down_held = true
			14: input = _press("D", false, facing)
			15: input.move_axis = facing
			34: input = _press("C")
		for event in session.step(input):
			_log_event(frame, "R2", event, session)
			if event.type == CombatEvent.Type.HIT:
				hit_moves.append(session.player_move_id)
				hit_frames.append(frame)
		if session.player_move_id == "6D" or session.player_move_id == "jC":
			peak_height = maxf(peak_height, GameParams.ground_stand_y() - session.player_position.y)
		if frame >= 31 and session.debug_snapshot()["air_exit_open"] and exit_frame < 0:
			exit_frame = frame
		if frame == 40 and session.player_move_id == "jC":
			airborne_at_exit = not session.player_on_ground
	_check(hit_moves == ["2C", "6D", "jC"],
		"R2 三击成立（命中帧 %s）" % str(hit_frames))
	_check(peak_height >= 20.0, "R2 6D 真实上升（峰值 %.1f px，非姿态瞬移）" % peak_height)
	_check(exit_frame > 0, "R2 空中出口在 6D 命中确认窗口内开放（F%d）" % exit_frame)
	_check(airborne_at_exit, "R2 jC 出口起手时玩家真实滞空")
	print("")


## R2b：6D 命中浮空目标后不取出口——完整 88px 位移在最小合法间距下终点仍差
## ~13px 越不过木桩一个身位：按 M-02 截在原侧身体边界、不换边（正向换边是
## motion/5B 对空资料的调校观察项，见 frame-data 票据 07）。
func _replay_r2b_6d_full_cross(facing: int) -> void:
	var session := _spawn(NEAR_DX, facing)
	session.dummy_position.y -= 40.0
	session.dummy_on_ground = false
	print("=== R2b 6D 命中后完整位移（M-02 原侧保留） | 面向 %d ===" % facing)
	var swap_frame := -1
	var hit_frame := -1
	for frame in range(1, 60):
		var input := FrameInput.new()
		match frame:
			1: input = _press("D", false, facing)
			2: input.move_axis = facing
		for event in session.step(input):
			_log_event(frame, "R2b", event, session)
			if event.type == CombatEvent.Type.HIT:
				hit_frame = frame
			elif event.type == CombatEvent.Type.SWITCHED_SIDES:
				swap_frame = frame
	_check(hit_frame > 0 and swap_frame < 0,
		"R2b 实际 HIT 且 cross_ok 授予，但 88px 终点未越过木桩身位——按 M-02 截原侧、不换边（F%d 命中）" % hit_frame)
	_check((session.player_position.x - session.dummy_position.x) * facing < 0,
		"R2b 玩家全程保留原侧（终点 dx=%.1f，击退漂移后仍在木桩身后）" % (session.player_position.x - session.dummy_position.x))
	print("")


## R3：2C 低浮空下的两条失败路——2D 因高位判定垂直不重叠挥空；5D 因 2C 未声明
## 边（时序上等不到独立起手进浮空窗口）报 CONFIGURATION_GAP。
func _replay_r3_2d_height_and_5d_timing(facing: int) -> void:
	print("=== R3 2C 后 2D 高位挥空 / 5D 时序失败 | 面向 %d ===" % facing)
	var two_d_hits := 0
	var box_bottom := 0.0
	var dummy_top := 0.0
	var heights: Array[float] = []
	var session := _spawn(NEAR_DX, facing)
	var two_d := session.move_table()["2D"] as MoveData
	for frame in range(1, 55):
		var input := FrameInput.new()
		match frame:
			1: input = _press("C", true)
			2: input.down_held = true
			14: input = _press("D", true)
		if frame >= 15 and frame <= 32:
			input.down_held = true
		for event in session.step(input):
			_log_event(frame, "R3a", event, session)
			if event.type == CombatEvent.Type.HIT:
				two_d_hits += 1
		if session.player_move_id == "2D" and session.player_phase == CombatSession.PlayerPhase.ACTIVE:
			heights.append(snappedf(GameParams.ground_stand_y() - session.dummy_position.y, 0.1))
			box_bottom = session.player_position.y + two_d.hitbox_y_offset_px + two_d.hitbox_size.y * 0.5
			dummy_top = session.dummy_position.y - GameParams.BODY_SIZE.y * 0.5
	_check(two_d_hits == 1, "R3a 只有 2C 命中（2D 无第二次 HIT）")
	_check(box_bottom < dummy_top,
		"R3a 高度失配可观察：2D 框底 %.1f 高于浮空木桩顶 %.1f（active 期木桩高度 %s px）" % [
			box_bottom, dummy_top, str(heights)])
	var gap_event := false
	var five_d_hits := 0
	var session_b := _spawn(NEAR_DX, facing)
	for frame in range(1, 60):
		var input := FrameInput.new()
		match frame:
			1: input = _press("C", true)
			2: input.down_held = true
			26: input = _press("D")
		for event in session_b.step(input):
			_log_event(frame, "R3b", event, session_b)
			if event.type == CombatEvent.Type.LINK_FAILED and event.link_fail_reason == CombatEvent.LinkFailReason.CONFIGURATION_GAP:
				gap_event = true
			elif event.type == CombatEvent.Type.HIT:
				five_d_hits += 1
	_check(five_d_hits == 1 and gap_event,
		"R3b 2C 后 5D 报可读 CONFIGURATION_GAP（2C 未声明 5D 边），独立起手落在倒地外")
	print("")


## R4：对地拒绝——6D 命中框触及地面木桩但无 grounded 资料（MISS_NO_PROFILE）；
## 2D 高位框从地面木桩上方越过（无接触、无连段），挥空同样真实上升再回落。
func _replay_r4_ground_rejection(facing: int) -> void:
	print("=== R4 6D/2D 对地拒绝 | 面向 %d ===" % facing)
	var session := _spawn(NEAR_DX, facing)
	var miss_events := 0
	var hits := 0
	var rose := false
	for frame in range(1, 40):
		var input := FrameInput.new()
		match frame:
			1: input = _press("D", false, facing)
			2: input.move_axis = facing
		for event in session.step(input):
			_log_event(frame, "R4a", event, session)
			if event.type == CombatEvent.Type.HIT_MISS:
				miss_events += 1
			elif event.type == CombatEvent.Type.HIT:
				hits += 1
		if session.player_move_id == "6D" and not session.player_on_ground:
			rose = true
	_check(hits == 0 and miss_events > 0 and rose,
		"R4a 6D 对地：MISS_NO_PROFILE 可读、无伤害无连段；挥空仍真实上升")
	var session_b := _spawn(NEAR_DX, facing)
	var hits_b := 0
	var rose_b := false
	var landed_frame := -1
	for frame in range(1, 60):
		var input := FrameInput.new()
		match frame:
			1: input = _press("D", true)
			2: input.down_held = true
		for event in session_b.step(input):
			_log_event(frame, "R4b", event, session_b)
			if event.type == CombatEvent.Type.HIT:
				hits_b += 1
		if session_b.player_move_id == "2D" and not session_b.player_on_ground:
			rose_b = true
		if landed_frame < 0 and rose_b and session_b.player_on_ground:
			landed_frame = frame
	_check(hits_b == 0 and rose_b and landed_frame > 0,
		"R4b 2D 高位框越过地面木桩（无接触），上升后 F%d 物理回落" % landed_frame)
	print("")


## R5：2D 对真正空中的目标命中（高位框垂直范围成立）→ 空中出口 jA → 滞空期间
## Space 不产生第二次上升冲量（无二段跳、切招不续期）。
func _replay_r5_2d_airborne_exit_and_air_resource(facing: int) -> void:
	var session := _spawn(NEAR_DX, facing)
	session.dummy_position.y -= 40.0
	session.dummy_on_ground = false
	print("=== R5 2D 对空命中 + jA 出口 + 有限空中资源 | 面向 %d ===" % facing)
	var hit_moves: Array[String] = []
	var second_impulse := false
	var land_frame := -1
	for frame in range(1, 60):
		var input := FrameInput.new()
		match frame:
			1: input = _press("D", true)
			2: input.down_held = true
			14: input = _press("A")
			20: input.jump_pressed = true
			25: input.jump_pressed = true
			30: input = _press("C")
		for event in session.step(input):
			_log_event(frame, "R5", event, session)
			if event.type == CombatEvent.Type.HIT:
				hit_moves.append(session.player_move_id)
		if not session.player_on_ground and session.player_velocity.y < -50.0 and frame > 16:
			second_impulse = true
		if land_frame < 0 and frame > 16 and session.player_on_ground:
			land_frame = frame
	_check(hit_moves == ["2D", "jA"], "R5 2D 命中空中目标后经空中出口进入 jA（%s）" % str(hit_moves))
	_check(not second_impulse, "R5 滞空中 Space 不产生第二次上升冲量（无二段跳）")
	_check(land_frame > 0 and land_frame <= 40,
		"R5 滞空按物理自然结束（F%d 落地），切招不续期空中资源" % land_frame)
	print("")


## R6：版边 6D 墙截断（标记可观察、不越界、不换边）与被防 6D 截原侧、无空中出口。
## 版边探针把悬空白木桩放在玩家正上方（同 x 不触发面向翻转），6D 朝墙挥空——
## 墙截断与「挥空不换边」同时成立。
func _replay_r6_wall_clamp_and_blocked(facing: int) -> void:
	print("=== R6 6D 版边墙截断与被防不穿越 | 面向 %d ===" % facing)
	var session := CombatSession.new()
	session.player_facing = facing
	if facing == 1:
		session.player_position.x = GameParams.stage_right_limit()
	else:
		session.player_position.x = GameParams.stage_left_limit()
	session.dummy_position.x = session.player_position.x
	session.dummy_position.y -= 110.0
	session.dummy_on_ground = false
	var wall_clamped := false
	var swap_frame := -1
	for frame in range(1, 50):
		var input := FrameInput.new()
		match frame:
			1: input = _press("D", false, facing)
			2: input.move_axis = facing
		for event in session.step(input):
			_log_event(frame, "R6a", event, session)
			if event.type == CombatEvent.Type.SWITCHED_SIDES:
				swap_frame = frame
		if session.debug_snapshot()["motion_wall_clamped"]:
			wall_clamped = true
	_check(wall_clamped and swap_frame < 0,
		"R6a 版边 6D：墙截断标记可观察、不换边")
	_check(session.player_position.x <= GameParams.stage_right_limit() + 0.01
		and session.player_position.x >= GameParams.stage_left_limit() - 0.01,
		"R6a 版边不出界")
	var session_b := _spawn(NEAR_DX, facing)
	var blocked := false
	var exit_open := false
	for frame in range(1, 45):
		var input := FrameInput.new()
		match frame:
			1: input = _press("D", false, facing)
			2: input.move_axis = facing
			14: input = _press("C")
		if frame <= 30:
			input.dummy_guard_request = CombatSession.GuardPosture.STANDING
		for event in session_b.step(input):
			_log_event(frame, "R6b", event, session_b)
			if event.type == CombatEvent.Type.ATTACK_BLOCKED:
				blocked = true
		if session_b.debug_snapshot()["air_exit_open"]:
			exit_open = true
	_check(blocked and not exit_open, "R6b 被防 6D 无空中出口")
	_check((session_b.player_position.x - session_b.dummy_position.x) * facing < 0,
		"R6b 被防截原侧（无穿越）")
	print("")
