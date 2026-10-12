extends SceneTree
## 票据 05：木桩跳跃训练请求——R4-A 对空练习的初态进入。
## R4-A 的合法初态是「未受击、普通跳跃轨迹、下落中」的空中木桩；此前训练场
## 没有任何让木桩离地的输入途径（dummy_move_request 仅打击招式且训练场不
## 设置），八样本之一无法按步骤进入。本套件验证训练请求的会话语义与主场景
## 输入接入：空闲木桩按请求以普通跳跃速度离地（可带水平方向，与玩家跳
## 同速），保持未受击跳跃者运动（票据 02 语义），6A 可对其完成对空首击；
## 忙碌状态忽略请求；空中段保存恢复等价。
## 运行：godot --headless --path . -s res://tests/test_dummy_jump_practice.gd

var failures := 0


func _initialize() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	_test_idle_dummy_jump_matches_player_airtime()
	_test_directional_jump_keeps_horizontal_speed()
	_test_6a_first_hit_on_descending_unhit_dummy()
	_test_request_ignored_when_busy()
	_test_settlement_restore_mid_flight()
	await _test_main_scene_adapter_maps_key()
	print("")
	if failures == 0:
		print("ALL TESTS PASSED")
		quit(0)
	else:
		print(str(failures) + " TEST(S) FAILED")
		quit(1)


func check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  " + label)
	else:
		failures += 1
		print("FAIL  " + label)


func _make_session() -> CombatSession:
	var session := CombatSession.new()
	session.player_position = Vector2(300.0, GameParams.ground_stand_y())
	session.dummy_position = Vector2(600.0, GameParams.ground_stand_y())
	return session


func _request_jump(axis := 0) -> FrameInput:
	var input := FrameInput.new()
	input.move_axis = axis
	input.dummy_jump_request = true
	return input


func _event_signature(events: Array) -> String:
	var parts: PackedStringArray = []
	for event in events:
		parts.append("%d/%d/%d/%d" % [event.type, int(round(event.damage)), event.combo_hits, event.move_segment])
	return ",".join(parts)


## 空闲木桩接受跳跃请求：请求帧即首个空中帧，滞空帧数与玩家普通跳一致，
## 全程保持 NEUTRAL（未受击）、无事件，落地回到站立中立。
func _test_idle_dummy_jump_matches_player_airtime() -> void:
	# 玩家侧基准：jump 输入 → pre-jump 4f → 空中段帧数。
	var player_ref := _make_session()
	player_ref.step(FrameInput.new())
	var jump := FrameInput.new()
	jump.jump_pressed = true
	player_ref.step(jump)
	var player_air := 0
	for i in 120:
		player_ref.step(FrameInput.new())
		if not player_ref.player_on_ground:
			player_air += 1
		elif player_air > 0:
			break
	# 木桩侧：请求帧起计数。
	var session := _make_session()
	session.step(FrameInput.new())
	var events := session.step(_request_jump())
	check(events.is_empty(), "jump request itself emits no combat event")
	check(not session.dummy_on_ground, "request frame itself is the first air frame")
	# 请求帧（首个空中帧，当帧不加重力）计入滞空。
	var dummy_air := 1 if not session.dummy_on_ground else 0
	var stayed_neutral := true
	var peak := 0.0
	for i in 120:
		session.step(FrameInput.new())
		if not session.dummy_on_ground:
			dummy_air += 1
			stayed_neutral = stayed_neutral and session.dummy_state == CombatSession.DummyState.NEUTRAL
			peak = maxf(peak, GameParams.ground_stand_y() - session.dummy_position.y)
		elif dummy_air > 0:
			break
	check(dummy_air > 0, "idle dummy leaves ground on jump request (air frames=%d)" % dummy_air)
	check(dummy_air == player_air, "dummy airtime equals player normal jump (dummy=%d player=%d)" % [dummy_air, player_air])
	check(stayed_neutral, "dummy stays NEUTRAL (un-hit) through the whole jump")
	check(peak > 60.0, "dummy reaches a real jump apex (peak=%.1fpx)" % peak)
	check(session.dummy_on_ground and session.dummy_state == CombatSession.DummyState.NEUTRAL,
		"dummy lands back to standing neutral")


## 带方向的请求：空中段水平速度保持请求方向 × PLAYER_MOVE_SPEED（跳跃者
## 运动，无摩擦衰减），落地后摩擦归零。
func _test_directional_jump_keeps_horizontal_speed() -> void:
	for axis in [1, -1]:
		var session := _make_session()
		session.step(FrameInput.new())
		var start_x := session.dummy_position.x
		session.step(_request_jump(axis))
		var air := 0
		var speed_kept := true
		var drift := 0.0
		for i in 120:
			session.step(FrameInput.new())
			if not session.dummy_on_ground:
				air += 1
				speed_kept = speed_kept and is_equal_approx(
					session.dummy_velocity.x, axis * GameParams.PLAYER_MOVE_SPEED)
			elif air > 0:
				break
		drift = session.dummy_position.x - start_x
		check(speed_kept, "axis=%d horizontal speed stays %d px/s while airborne" % [axis, axis * int(GameParams.PLAYER_MOVE_SPEED)])
		check(drift * axis > 100.0, "axis=%d dummy drifts with the jump (drift=%.1fpx)" % [axis, drift])
		for i in 30:
			session.step(FrameInput.new())
		check(is_zero_approx(session.dummy_velocity.x), "axis=%d friction stops the dummy after landing" % axis)


## R4-A 语义：下落中的未受击木桩被 6A 首击——命中前 NEUTRAL 且空中，
## 命中后进入 AIR_HITSTUN（6A 空中资料），连段从 1 hit 起算。
func _test_6a_first_hit_on_descending_unhit_dummy() -> void:
	for facing in [1, -1]:
		var session := _make_session()
		session.player_position = Vector2(480.0, GameParams.ground_stand_y())
		session.dummy_position = Vector2(480.0 + 10.0 * facing, GameParams.ground_stand_y())
		session.step(FrameInput.new())
		session.step(_request_jump())
		# 等到下落段、高度进入出招带（按下时较高，接触落在 7–38px 带内）。
		var armed := false
		for i in 120:
			session.step(FrameInput.new())
			var h := GameParams.ground_stand_y() - session.dummy_position.y
			if session.dummy_velocity.y > 0.0 and h >= 55.0 and h <= 70.0:
				armed = true
				break
		check(armed, "facing=%d dummy reaches descending press band" % facing)
		var pre_state := session.dummy_state
		var pre_air := not session.dummy_on_ground
		var six_a := FrameInput.new()
		six_a.move_axis = facing
		six_a.action_key = "A"
		var hit_events := ""
		var contact_height := -1.0
		for i in 24:
			var events := session.step(six_a if i == 0 else FrameInput.new())
			for event in events:
				if event.type == CombatEvent.Type.HIT:
					hit_events += _event_signature([event])
					contact_height = GameParams.ground_stand_y() - session.dummy_position.y
			if hit_events != "":
				break
		check(hit_events != "", "facing=%d 6A connects on the descending dummy" % facing)
		check(pre_state == CombatSession.DummyState.NEUTRAL and pre_air,
			"facing=%d dummy was un-hit airborne right before the first hit" % facing)
		# 接触高度只做空中接触的健全性下界；7–38px 是 E45 的观察包络，
		# 不是 R4-A 保证域（首击条件=未受击下落，不限定高度带）。
		check(contact_height >= 5.0,
			"facing=%d contact happens clearly airborne (%.1fpx)" % [facing, contact_height])
		check(session.dummy_state == CombatSession.DummyState.AIR_HITSTUN and session.combo_hits == 1,
			"facing=%d 6A airborne profile applies: AIR_HITSTUN, combo starts at 1 hit" % facing)


## 忙碌忽略：受击硬直、防御姿态保持、自身招式进行中，请求都不产生离地
## （不排队、不补发，与木桩攻击请求同一口径）。
func _test_request_ignored_when_busy() -> void:
	# 受击硬直中：5B 命中后请求，木桩保持接地直到硬直自然结束。
	var stunned := _make_session()
	stunned.dummy_position = Vector2(316.0, GameParams.ground_stand_y())
	stunned.step(FrameInput.new())
	var poke := FrameInput.new()
	poke.action_key = "B"
	for i in 10:
		var events := stunned.step(poke if i == 0 else FrameInput.new())
		if events.any(func(event): return event.type == CombatEvent.Type.HIT):
			break
	check(stunned.dummy_state == CombatSession.DummyState.GROUND_HITSTUN, "5B grounds the dummy first")
	stunned.step(_request_jump())
	var grounded_through := true
	for i in 10:
		stunned.step(FrameInput.new())
		grounded_through = grounded_through and stunned.dummy_on_ground
	check(grounded_through, "jump request ignored during hitstun")
	# 防御姿态保持中：同帧防御+跳跃请求，防御优先、不离地。
	var guarding := _make_session()
	guarding.step(FrameInput.new())
	var guard_jump := _request_jump()
	guard_jump.dummy_guard_request = 1
	guarding.step(guard_jump)
	var guard_kept := guarding.dummy_guard == CombatSession.GuardPosture.STANDING and guarding.dummy_on_ground
	for i in 8:
		var hold := FrameInput.new()
		hold.dummy_guard_request = 1
		guarding.step(hold)
		guard_kept = guard_kept and guarding.dummy_on_ground
	check(guard_kept, "jump request ignored while the dummy holds a guard posture")
	# 自身招式进行中：5A 起手后请求，招式期间不离地。
	var acting := _make_session()
	acting.step(FrameInput.new())
	var act := FrameInput.new()
	act.dummy_move_request = "5A"
	acting.step(act)
	acting.step(FrameInput.new())
	check(acting.dummy_move_id == "5A", "dummy strike request starts 5A")
	acting.step(_request_jump())
	var acting_grounded := true
	for i in 8:
		acting.step(FrameInput.new())
		acting_grounded = acting_grounded and acting.dummy_on_ground
	check(acting_grounded, "jump request ignored while the dummy performs a move")


## 空中段保存恢复等价：请求帧与下落段两个切点 clone→restore 后继续喂相同
## 输入，事件签名与木桩位置逐帧一致（请求不因恢复重复触发）。
func _test_settlement_restore_mid_flight() -> void:
	for split in [0, 25]:
		var base := _make_session()
		base.step(FrameInput.new())
		base.step(_request_jump(1))
		for i in split:
			base.step(FrameInput.new())
		var snapshot := base.clone_state()
		var restored := CombatSession.new()
		check(restored.restore_state(snapshot), "split=%d restore_state accepts mid-flight snapshot" % split)
		var events_equal := true
		var position_equal := true
		for i in 60:
			var a := FrameInput.new()
			var b := FrameInput.new()
			var base_events := base.step(a)
			var restored_events := restored.step(b)
			events_equal = events_equal and _event_signature(base_events) == _event_signature(restored_events)
			position_equal = position_equal and is_equal_approx(base.dummy_position.x, restored.dummy_position.x) \
				and is_equal_approx(base.dummy_position.y, restored.dummy_position.y)
		check(events_equal, "split=%d event signatures identical after restore" % split)
		check(position_equal, "split=%d dummy positions identical after restore" % split)


## 主场景输入接入：T（dummy_jump）经适配层产生请求并驱动真实会话离地；
## 按住 ←/→ 时请求带水平方向。
func _test_main_scene_adapter_maps_key() -> void:
	var main: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await physics_frame
	var session: CombatSession = main.session
	check(session != null and session.dummy_on_ground, "main scene starts with a grounded dummy")
	Input.action_press("dummy_jump")
	# 脚本注入的 action_press 要到下一个物理帧才会被 just_pressed 消费
	# （与 test_smoke 攻击注入同一口径），多等一帧再松开。
	await physics_frame
	await physics_frame
	Input.action_release("dummy_jump")
	check(not session.dummy_on_ground, "T key lifts the dummy through the real adapter")
	for i in 50:
		await physics_frame
	check(session.dummy_on_ground, "dummy lands again after the training jump")
	Input.action_press("move_right")
	Input.action_press("dummy_jump")
	await physics_frame
	await physics_frame
	Input.action_release("dummy_jump")
	Input.action_release("move_right")
	check(not session.dummy_on_ground and is_equal_approx(
		session.dummy_velocity.x, GameParams.PLAYER_MOVE_SPEED),
		"holding a direction with T gives the dummy jump horizontal speed")
	main.queue_free()
