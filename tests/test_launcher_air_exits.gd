extends SceneTree
## 票据 07 单元测试：6A jump cancel 空中链、6D/2D 对空限定与空中出口、
## 2C 后 2D 高度失配 / 5D 时序失败、真实上升与有限空中资源。
## 运行：godot --headless --path . -s res://tests/test_launcher_air_exits.gd

const NEAR_DX := 50.0

var _failures := 0


func _initialize() -> void:
	_test_jump_cancel_route_into_jb_jc()
	_test_6a_blocked_no_jump_cancel()
	_test_6a_whiff_no_jump_cancel()
	_test_2c_6d_jc_air_exit_route()
	_test_6d_ground_target_no_profile()
	_test_2d_ground_target_no_hit()
	_test_2c_then_2d_height_miss()
	_test_2c_then_5d_timing_gap()
	_test_2d_airborne_positive_and_ja_exit()
	_test_air_resource_not_renewed()
	_test_6d_blocked_no_air_exit()
	_test_missing_airborne_profile_reports_no_profile()
	print("")
	if _failures == 0:
		print("ALL LAUNCHER AIR EXIT TESTS PASSED")
		quit(0)
	else:
		print(str(_failures) + " TEST(S) FAILED")
		quit(1)


func _spawn(dx: float, facing := 1) -> CombatSession:
	var session := CombatSession.new()
	if facing == 1:
		session.dummy_position = session.player_position + Vector2(dx, 0)
	else:
		session.dummy_position = session.player_position - Vector2(dx, 0)
		session.player_facing = -1
	return session


func _input(key: String, down := false, axis := 0) -> FrameInput:
	var input := FrameInput.new()
	if key != "":
		input.pressed_action_keys = [key]
		input.held_action_keys = [key]
	input.down_held = down
	input.move_axis = axis
	return input


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS  " + message)
	else:
		_failures += 1
		print("FAIL  " + message)


# --- 正例 1：5A > 5B > 5C > 6A > jc.jB > jC（阶段 6 演示路线，双面向）---

func _test_jump_cancel_route_into_jb_jc() -> void:
	for facing in [1, -1]:
		var session := _spawn(NEAR_DX, facing)
		var hit_frames: Array[int] = []
		var move_ids: Array[String] = []
		var prejump_frame := -1
		for frame in range(1, 110):
			# 每段链在上一击的 Hitstop 中按下（输入照常采样、按地面/空中姿态解析），
			# 恢复首个正常帧消费：5A@F1 → B@F9 → C@F24 → 6A@F38（5C 命中当帧 w=0，
			# A 起手时间层下 6A 前摇 8 恰好赶上剩余硬直）→ Space@F56 → jB@F68
			# （离地后空中姿态） → C@F76（jB 命中停顿中，空中姿态）。
			var input := FrameInput.new()
			match frame:
				1: input = _input("A")
				9: input = _input("B")
				24: input = _input("C")
				38:
					input = _input("A")
					input.move_axis = facing
				39: input.move_axis = facing
				56: input.jump_pressed = true
				68: input = _input("B")
				76: input = _input("C")
			var move_at_start := session.player_move_id
			for event in session.step(input):
				if event.type == CombatEvent.Type.HIT:
					hit_frames.append(frame)
					move_ids.append(move_at_start)
			if session.player_prejump_left > 0 and prejump_frame < 0:
				prejump_frame = frame
		_check(hit_frames.size() == 6, "route lands six hits across the jc chain (facing %d): %s" % [facing, str(hit_frames)])
		_check(move_ids == ["5A", "5B", "5C", "6A", "jB", "jC"],
			"the jump cancel route reads 5A > 5B > 5C > 6A > jc.jB > jC (facing %d): %s" % [facing, str(move_ids)])
		_check(prejump_frame > 0, "Space during 6A's hit-confirm window enters pre-jump (facing %d, F%d)" % [facing, prejump_frame])
		_check(session.combo_hits == 6, "combo counts six hits in one unbroken chain (facing %d)" % facing)


# --- 负例 1：6A 被防无 jump cancel；挥空无 jump cancel ---

func _test_6a_blocked_no_jump_cancel() -> void:
	var session := _spawn(NEAR_DX)
	var blocked := false
	var combo_before_space := -1
	var prejump_seen := false
	for frame in range(1, 40):
		var input := FrameInput.new()
		if frame == 1:
			input = _input("A")
			input.move_axis = 1
		elif frame == 2:
			input.move_axis = 1
		elif frame == 24:
			input.jump_pressed = true
			combo_before_space = session.combo_hits
		if frame <= 30:
			input.dummy_guard_request = CombatSession.GuardPosture.STANDING
		for event in session.step(input):
			if event.type == CombatEvent.Type.ATTACK_BLOCKED:
				blocked = true
		if session.player_prejump_left > 0:
			prejump_seen = true
	_check(blocked and combo_before_space == 0 and not prejump_seen,
		"blocked 6A denies jump cancel: Space starts no pre-jump and no air pursuit opens")
	_check(session.player_on_ground, "player stays grounded after Space on a blocked 6A")


func _test_6a_whiff_no_jump_cancel() -> void:
	var session := _spawn(300.0)
	var prejump_during_move := false
	var any_hit := false
	for frame in range(1, 60):
		var input := FrameInput.new()
		if frame == 1:
			input = _input("A")
			input.move_axis = 1
		elif frame == 2:
			input.move_axis = 1
		elif frame == 15:
			input.jump_pressed = true
		var move_running := session.player_move_id == "6A"
		for event in session.step(input):
			if event.type == CombatEvent.Type.HIT:
				any_hit = true
		if move_running and session.player_prejump_left > 0:
			prejump_during_move = true
	_check(not prejump_during_move and not any_hit,
		"whiffed 6A never opens the jump cancel window (Space during the whiffed move starts no pre-jump)")


# --- 正例 2：2C > 6D > jC（低浮空捞起 + 真实上升 + 空中出口，双面向）---

func _test_2c_6d_jc_air_exit_route() -> void:
	for facing in [1, -1]:
		var session := _spawn(NEAR_DX, facing)
		var hit_frames: Array[int] = []
		var hit_moves: Array[String] = []
		var airborne_at_exit := false
		var player_rose := false
		var max_height := 0.0
		var exit_open_frame := -1
		for frame in range(1, 60):
			var input := FrameInput.new()
			match frame:
				1: input = _input("C", true)
				2: input.down_held = true
				14:
					input = _input("D", false, facing)
				15: input.move_axis = facing
				34: input = _input("C")
			for event in session.step(input):
				if event.type == CombatEvent.Type.HIT:
					hit_frames.append(frame)
					hit_moves.append(session.player_move_id)
			if frame >= 31 and frame <= 47:
				if session.player_move_id == "6D" and not session.player_on_ground:
					player_rose = true
					max_height = maxf(max_height, GameParams.ground_stand_y() - session.player_position.y)
				if session.debug_snapshot()["air_exit_open"] and exit_open_frame < 0:
					exit_open_frame = frame
			if frame == 40 and session.player_move_id == "jC":
				airborne_at_exit = not session.player_on_ground
		_check(hit_moves == ["2C", "6D", "jC"],
			"2C chains into 6D which air-exits into jC (facing %d): hits %s" % [facing, str(hit_frames)])
		_check(player_rose and max_height >= 12.0,
			"6D's planned motion lifts the player for real before the exit (facing %d, peak %.1f px)" % [facing, max_height])
		_check(exit_open_frame > 0, "the air exit opens inside 6D's hit-confirm window while airborne (facing %d, F%d)" % [facing, exit_open_frame])
		_check(airborne_at_exit, "jC starts while the player is genuinely airborne after 6D's rise (facing %d)" % facing)
		_check(session.combo_hits == 3, "route counts three hits (facing %d)" % facing)


# --- 负例 2：6D/2D 不命中地面目标 ---

func _test_6d_ground_target_no_profile() -> void:
	var session := _spawn(NEAR_DX)
	var miss_events := 0
	var hits := 0
	for frame in range(1, 30):
		var input := FrameInput.new()
		if frame == 1:
			input.move_axis = 1
			input = _merge_6d_press(input)
		elif frame == 2:
			input.move_axis = 1
		for event in session.step(input):
			if event.type == CombatEvent.Type.HIT_MISS:
				miss_events += 1
			elif event.type == CombatEvent.Type.HIT:
				hits += 1
	_check(hits == 0 and miss_events > 0,
		"6D against a grounded target reports MISS_NO_PROFILE (hitbox touches, no grounded profile): %d miss events" % miss_events)
	_check(session.combo_active == false and session.dummy_hp == GameParams.DUMMY_MAX_HP,
		"no combo starts and no damage lands from grounded 6D")


func _merge_6d_press(input: FrameInput) -> FrameInput:
	input.pressed_action_keys = ["D"]
	input.held_action_keys = ["D"]
	return input


func _test_2d_ground_target_no_hit() -> void:
	var session := _spawn(NEAR_DX)
	var hits := 0
	var rose := false
	for frame in range(1, 30):
		var input := FrameInput.new()
		if frame == 1:
			input = _input("D", true)
		elif frame == 2:
			input.down_held = true
		for event in session.step(input):
			if event.type == CombatEvent.Type.HIT:
				hits += 1
		if session.player_move_id == "2D" and not session.player_on_ground:
			rose = true
	_check(hits == 0 and rose,
		"2D's raised hitbox passes over the grounded dummy without contact (silent whiff, no profile consumed)")
	_check(session.combo_active == false, "2D on a grounded target starts no combo")


# --- 负例 3：2C 低浮空下 2D 高度失配 ---

func _test_2c_then_2d_height_miss() -> void:
	var session := _spawn(NEAR_DX)
	var hits := 0
	var heights_during_active: Array[float] = []
	var two_d := session.move_table()["2D"] as MoveData
	var box_bottom := 0.0
	var dummy_top := 0.0
	for frame in range(1, 55):
		var input := FrameInput.new()
		match frame:
			1: input = _input("C", true)
			2: input.down_held = true
			14: input = _input("D", true)
		if frame >= 15 and frame <= 32:
			input.down_held = true
		for event in session.step(input):
			if event.type == CombatEvent.Type.HIT:
				hits += 1
		if session.player_move_id == "2D" and session.player_phase == CombatSession.PlayerPhase.ACTIVE:
			heights_during_active.append(GameParams.ground_stand_y() - session.dummy_position.y)
			box_bottom = session.player_position.y + two_d.hitbox_y_offset_px + two_d.hitbox_size.y * 0.5
			dummy_top = session.dummy_position.y - GameParams.BODY_SIZE.y * 0.5
	_check(hits == 1, "only 2C connects; 2D whiffs over the low float (hits=%d)" % hits)
	_check(not heights_during_active.is_empty() and box_bottom < dummy_top,
		"height mismatch is observable: 2D box bottom %.1f stays above the floating dummy's top %.1f" % [box_bottom, dummy_top])
	var airborne_during_active := heights_during_active.any(func(h: float) -> bool: return h > 0.0)
	_check(airborne_during_active,
		"the dummy is still airborne across 2D's active frames (failure is height, not timing): %s" % str(heights_during_active.map(func(h: float): return snappedf(h, 0.1))))


# --- 负例 4：2C 后 5D 时序失败（配置缺口 + 独立起手落空）---

func _test_2c_then_5d_timing_gap() -> void:
	var session := _spawn(NEAR_DX)
	var gap_event := false
	var hits := 0
	for frame in range(1, 60):
		var input := FrameInput.new()
		match frame:
			1: input = _input("C", true)
			2: input.down_held = true
			26: input = _input("D")
		for event in session.step(input):
			if event.type == CombatEvent.Type.LINK_FAILED and event.link_fail_reason == CombatEvent.LinkFailReason.CONFIGURATION_GAP:
				gap_event = true
			elif event.type == CombatEvent.Type.HIT:
				hits += 1
	_check(hits == 1 and gap_event,
		"5D after 2C reports a readable CONFIGURATION_GAP (no edge declared) and never connects during the float")


# --- 正例 3：2D 对空中目标命中 + jA 出口（2D > jA）---

func _test_2d_airborne_positive_and_ja_exit() -> void:
	var session := _spawn(NEAR_DX)
	session.dummy_position.y -= 40.0
	session.dummy_on_ground = false
	var hit_moves: Array[String] = []
	var exit_airborne := false
	for frame in range(1, 45):
		var input := FrameInput.new()
		match frame:
			1: input = _input("D", true)
			2: input.down_held = true
			14: input = _input("A")
		for event in session.step(input):
			if event.type == CombatEvent.Type.HIT:
				hit_moves.append(session.player_move_id)
		if frame == 18 and session.player_move_id == "jA":
			exit_airborne = not session.player_on_ground
	_check(hit_moves == ["2D", "jA"],
		"2D intercepts a genuinely airborne target and air-exits into jA: %s" % str(hit_moves))
	_check(exit_airborne, "the jA exit starts while airborne (2D's vertical rise is the real airtime)")
	_check(session.combo_hits == 2, "2D > jA counts two hits")


# --- 负例 5：有限空中资源不因切招续期（无二段跳）---

func _test_air_resource_not_renewed() -> void:
	var session := _spawn(NEAR_DX)
	session.dummy_position.y -= 40.0
	session.dummy_on_ground = false
	var takeoff_velocity := 0.0
	var second_impulse := false
	var land_frame := -1
	for frame in range(1, 60):
		var input := FrameInput.new()
		match frame:
			1: input = _input("D", true)
			2: input.down_held = true
			14: input = _input("A")
			20: input.jump_pressed = true
			25: input.jump_pressed = true
			30: input = _input("C")
		session.step(input)
		if session.player_move_id == "2D" and is_zero_approx(takeoff_velocity) and not session.player_on_ground:
			takeoff_velocity = session.player_velocity.y
		if not session.player_on_ground and session.player_velocity.y < -50.0 and frame > 16:
			second_impulse = true
		if land_frame < 0 and session.player_on_ground and frame > 16:
			land_frame = frame
	_check(takeoff_velocity >= -1.0, "the rise itself is planned motion, not an upward velocity impulse (%.1f)" % takeoff_velocity)
	_check(not second_impulse, "air Space presses never grant a second upward impulse (no double jump)")
	_check(land_frame > 0 and land_frame <= 40,
		"the airtime after 2D's rise ends by physics alone (landing F%d), switching moves does not renew it" % land_frame)


# --- 负例 6：6D 被防无空中出口、保留原侧 ---

func _test_6d_blocked_no_air_exit() -> void:
	var session := _spawn(NEAR_DX)
	var blocked := false
	var exit_open := false
	var start_side := 0
	for frame in range(1, 45):
		var input := FrameInput.new()
		if frame == 1:
			input = _merge_6d_press(FrameInput.new())
			input.move_axis = 1
		elif frame == 2:
			input.move_axis = 1
		elif frame == 14:
			input = _input("C")
		if frame <= 30:
			input.dummy_guard_request = CombatSession.GuardPosture.STANDING
		if frame == 2:
			start_side = 1
		for event in session.step(input):
			if event.type == CombatEvent.Type.ATTACK_BLOCKED:
				blocked = true
		if session.debug_snapshot()["air_exit_open"]:
			exit_open = true
	_check(blocked and not exit_open, "blocked 6D opens no air exit (contact without a HIT)")
	_check((session.player_position.x - session.dummy_position.x) < 0,
		"blocked 6D stays on its original side (crossing denied)")


# --- 资源同步：缺失 airborne profile 两端一致报 no-profile ---

func _test_missing_airborne_profile_reports_no_profile() -> void:
	var table := MoveData.default_table()
	var six_d := table["6D"] as MoveData
	var grounded_only := HitProfile.new()
	grounded_only.target_state = HitProfile.TargetState.GROUNDED
	grounded_only.hit_context = HitProfile.HitContext.NORMAL
	grounded_only.reaction = HitProfile.Reaction.GROUND_HITSTUN
	grounded_only.ground_stun_frames = 14
	grounded_only.horizontal_speed_px_s = 100.0
	grounded_only.upward_speed_px_s = 0.0
	six_d.hit_profiles = [grounded_only]
	var session := CombatSession.new(table)
	session.dummy_position = session.player_position + Vector2(NEAR_DX, 0)
	session.dummy_position.y -= 40.0
	session.dummy_on_ground = false
	var miss_events := 0
	for frame in range(1, 20):
		var input := FrameInput.new()
		if frame == 1:
			input.move_axis = 1
			input = _merge_6d_press(input)
		elif frame == 2:
			input.move_axis = 1
		for event in session.step(input):
			if event.type == CombatEvent.Type.HIT_MISS:
				miss_events += 1
	_check(miss_events > 0, "session: 6D with only a grounded profile reports HIT_MISS on an airborne target (no fallback)")
	var report := ComboSolver.analyze(table)
	var chain_edge_found := false
	var chain_edge_no_profile := false
	for edge in report.edges:
		if edge.from_id == "2C" and edge.to_id == "6D" and edge.kind == ComboSolver.EdgeKind.CHAIN_CANCEL:
			chain_edge_found = true
			if not edge.valid and edge.reason.contains("MISS_NO_PROFILE"):
				chain_edge_no_profile = true
	_check(chain_edge_found and chain_edge_no_profile,
		"solver: the same grounded-only table reports the 2C -> 6D air-chase seam broken by MISS_NO_PROFILE, matching the session")
