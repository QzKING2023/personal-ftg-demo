extends SceneTree
## 训练场集成测试：注入输入并推进真实物理帧，验证训练场对战斗会话的接入。
## 移动/跳跃/边界/重置保持可用；一次命中驱动木桩血量、受击反馈与状态显示。
## 运行：godot --headless --path . -s res://tests/test_smoke.gd
## 说明：-s 模式下节点的 _ready 要等第一帧迭代才触发，
## 因此测试挂在一帧 process_frame 之后执行；集成测试用 physics_frame 推进物理帧，
## 用 Input.action_press / parse_input_event 注入输入，结束时调用 quit()。

var _failures := 0


func _initialize() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	var main: Node2D = _test_main_scene_builds()
	var session: CombatSession = main.session
	var player: Player = main.get_node("Player")
	var dummy: Dummy = main.get_node("Dummy")
	await _test_movement_and_bounds(player, session)
	await _test_jump(player)
	await _test_hud_layout_no_overlap(main)
	await _test_crouch_and_guard_presentation(main, player, session)
	await _test_attack_hit_and_feedback(main, player, dummy, session)
	await _test_attack_range(session)
	await _test_ground_combo_display(main, session)
	await _test_direction_derivative_and_float(main, session)
	await _test_jump_cancel_air_pursuit(main, session)
	await _test_full_air_route_keyboard(main, session)
	await _test_backward_qcb_keyboard(main, session)
	await _test_air_derivation_keyboard()
	await _test_session_runs_shared_manifest(main)
	await _test_main_refuses_invalid_manifest()
	await _test_reset(main)
	print("")
	if _failures == 0:
		print("ALL TESTS PASSED")
		quit(0)
	else:
		print(str(_failures) + " TEST(S) FAILED")
		quit(1)


func _test_main_scene_builds() -> Node2D:
	var main: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	# -s 环境下手动加载场景不会设置 current_scene，补上以支持 reload_current_scene。
	current_scene = main
	_check(main.get_node_or_null("Player") != null, "main scene spawns Player")
	_check(main.get_node_or_null("Dummy") != null, "main scene spawns Dummy")
	var session: CombatSession = main.session
	_check(session != null, "main scene drives a combat session")
	_check(session.dummy_hp == GameParams.DUMMY_MAX_HP, "dummy starts at full hp")
	_check(session.dummy_state == CombatSession.DummyState.NEUTRAL, "dummy starts neutral")
	var status: Label = main.get_node_or_null("DummyStatus")
	_check(status != null and status.text.contains("中立"), "dummy status display starts neutral")
	return main


func _test_movement_and_bounds(player: Player, session: CombatSession) -> void:
	# 把木桩移到左侧墙边，避免身体阻挡干扰向右的墙体验证。
	session.dummy_position = Vector2(100.0, GameParams.ground_stand_y())
	await physics_frame
	var start_x := player.position.x
	Input.action_press("move_right")
	for i in 30:
		await physics_frame
	Input.action_release("move_right")
	_check(player.position.x > start_x + 50.0, "player moves right with input held")
	_check(is_equal_approx(player.position.x, session.player_position.x), "player view follows the session position")
	Input.action_press("move_right")
	for i in 240:
		await physics_frame
	Input.action_release("move_right")
	var wall_limit := GameParams.stage_right_limit()
	_check(absf(player.position.x - wall_limit) < 1.0, "player stops at the right stage wall")
	await physics_frame
	_check(absf(player.position.x - wall_limit) < 1.5, "player rests against the wall after input released")


func _test_jump(player: Player) -> void:
	var floor_y := player.position.y
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	var peak := player.position.y
	for i in 120:
		await physics_frame
		peak = minf(peak, player.position.y)
	_check(peak <= floor_y - 60.0, "player rises well above the ground on jump")
	_check(absf(player.position.y - floor_y) < 2.0, "player lands back on the ground")


func _test_hud_layout_no_overlap(main: Node2D) -> void:
	# 键位提示（左上）与木桩状态（右上）按实测文本宽度验证互不重叠：
	# 提示最宽行不超过状态栏左缘；状态栏按最宽战斗文案（浮空受击+两位数连段）
	# 也不得超出 960 设计视口。窗口缩放由 canvas_items 拉伸统一处理。
	var hint: Label = main.get_node("Hint")
	var status: Label = main.get_node("DummyStatus")
	await physics_frame
	var hint_width := hint.get_combined_minimum_size().x
	status.text = "玩家 地面  木桩 HP 100/100\n状态 浮空受击（36）  连段 21 hit · 103.6"
	await physics_frame
	var status_width := status.get_combined_minimum_size().x
	_check(hint.position.x + hint_width <= GameParams.STATUS_OFFSET.x + 0.5,
		"hint block stays clear of the status column")
	_check(GameParams.STATUS_OFFSET.x + status_width <= GameParams.STAGE_WIDTH,
		"status text fits inside the design viewport width")


func _test_crouch_and_guard_presentation(main: Node2D, player: Player, session: CombatSession) -> void:
	# 真实键盘路径（issue 16）：S 蹲下（当帧进入、视觉纵向压扁）；按住后方向进入
	# 站防（整体变色），S+后方向为蹲防；松开后恢复站立无防御；诊断行显示防御姿态。
	session.player_position = Vector2(GameParams.PLAYER_SPAWN_X, GameParams.ground_stand_y())
	session.player_velocity = Vector2.ZERO
	session.player_facing = 1
	session.dummy_position = session.player_position + Vector2(70, 0)
	await physics_frame
	var debug: Label = main.get_node("DebugLine")
	Input.action_press("move_down")
	await physics_frame
	_check(session.player_crouching, "S crouches the player via the real keyboard path")
	_check(player.is_showing_crouch(), "crouching squashes the player visuals")
	Input.action_release("move_down")
	await physics_frame
	_check(not session.player_crouching, "releasing S stands back up")
	Input.action_press("move_left")
	await physics_frame
	_check(session.player_guard == CombatSession.GuardPosture.STANDING, "holding the back direction enters the standing guard")
	_check(player.is_showing_guard(), "guarding tints the player visuals")
	_check(debug.text.contains("站防"), "the debug line shows the standing guard posture")
	Input.action_press("move_down")
	await physics_frame
	_check(session.player_crouching and session.player_guard == CombatSession.GuardPosture.CROUCH, "S plus back enters the crouch guard")
	_check(debug.text.contains("蹲防"), "the debug line shows the crouch guard posture")
	Input.action_release("move_left")
	Input.action_release("move_down")
	await physics_frame
	_check(not session.player_crouching and session.player_guard == CombatSession.GuardPosture.NONE, "releasing everything returns to plain standing")
	_check(not player.is_showing_guard() and not player.is_showing_crouch(), "visuals return to normal after the posture clears")


func _test_attack_hit_and_feedback(main: Node2D, player: Player, dummy: Dummy, session: CombatSession) -> void:
	# 显式回到标准排布：玩家在出生点面朝右，木桩在命中范围内。
	session.player_position = Vector2(GameParams.PLAYER_SPAWN_X, GameParams.ground_stand_y())
	session.player_velocity = Vector2.ZERO
	session.player_facing = 1
	session.dummy_position = session.player_position + Vector2(70, 0)
	await physics_frame
	var dummy_x_before := dummy.position.x
	_check(absf(dummy.position.x - session.dummy_position.x) < 0.01, "dummy view follows the session position")
	# 注意：脚本注入的 action_press 要到下一个物理帧才会被 just_pressed 消费，
	# 因此这里轮询等待命中帧，精确帧序由 tests/test_combat_session.gd 验证。
	Input.action_press("attack_a")
	await physics_frame
	Input.action_release("attack_a")
	var hit := false
	for i in 15:
		await physics_frame
		if session.dummy_hp < GameParams.DUMMY_MAX_HP:
			hit = true
			break
	_check(hit, "attack hits once when the dummy is close")
	_check(session.dummy_hp == GameParams.DUMMY_MAX_HP - GameParams.MOVE_5A_DAMAGE, "damage applied exactly once per swing")
	_check(session.dummy_state == CombatSession.DummyState.GROUND_HITSTUN, "dummy enters hitstun on hit")
	_check(dummy.position.x > dummy_x_before + 2.0, "dummy view shows the knockback displacement")
	_check(dummy.modulate == GameParams.HIT_FLASH_COLOR, "dummy flashes on the hit event")
	var status: Label = main.get_node("DummyStatus")
	_check(status.text.contains("地面受击"), "status display shows the hitstun state")
	for i in 40:
		await physics_frame
	_check(session.dummy_state == CombatSession.DummyState.NEUTRAL, "dummy recovers to neutral after hitstun")
	_check(status.text.contains("中立"), "status display returns to neutral")
	_check(dummy.modulate == Color.WHITE, "hit flash clears after its duration")


func _test_attack_range(session: CombatSession) -> void:
	session.dummy_position = Vector2(850.0, GameParams.ground_stand_y())
	await physics_frame
	Input.action_press("attack_a")
	await physics_frame
	Input.action_release("attack_a")
	for i in 40:
		await physics_frame
	_check(session.dummy_hp == GameParams.DUMMY_MAX_HP - GameParams.MOVE_5A_DAMAGE, "attack misses when the dummy is far away")


func _test_ground_combo_display(main: Node2D, session: CombatSession) -> void:
	# 5A 命中确认后立刻输入 5B：经输入缓存取消接上第二击，训练场显示连段命中数。
	session.player_position = Vector2(GameParams.PLAYER_SPAWN_X, GameParams.ground_stand_y())
	session.player_velocity = Vector2.ZERO
	session.player_facing = 1
	session.dummy_position = session.player_position + Vector2(70, 0)
	await physics_frame
	var hp_before := session.dummy_hp
	var hp_after_first := 0.0
	Input.action_press("attack_a")
	await physics_frame
	Input.action_release("attack_a")
	for i in 15:
		await physics_frame
		if session.dummy_hp < hp_before:
			hp_after_first = session.dummy_hp
			break
	_check(hp_after_first > 0.0, "first attack lands via injected input")
	Input.action_press("attack_b")
	await physics_frame
	Input.action_release("attack_b")
	var second_hit := false
	for i in 20:
		await physics_frame
		if session.dummy_hp < hp_after_first:
			second_hit = true
			break
	_check(second_hit, "input right after the hit cancels 5A into 5B via the buffer")
	_check(session.combo_hits == 2, "session tracks two combo hits")
	_check(absf(hp_after_first - session.dummy_hp - 10.8) < 0.05, "second hit applies decayed damage")
	var status: Label = main.get_node("DummyStatus")
	_check(status.text.contains("连段 2"), "status display shows the combo hit count")


func _test_direction_derivative_and_float(main: Node2D, session: CombatSession) -> void:
	# 键盘方向输入经训练场适配进入方向历史：↓ → ↓+→ → → 再按 C 触发 236C 浮空派生，
	# 状态栏依次显示浮空受击、空中已受身，落地后回到中立。
	# 先等上一段测试的招式与木桩硬直全部结束，方向序列才不会被缓存冲突吃掉。
	for i in 60:
		await physics_frame
		if session.player_phase == CombatSession.PlayerPhase.NEUTRAL and session.dummy_state == CombatSession.DummyState.NEUTRAL:
			break
	session.player_position = Vector2(GameParams.PLAYER_SPAWN_X, GameParams.ground_stand_y())
	session.player_velocity = Vector2.ZERO
	session.player_facing = 1
	session.dummy_position = session.player_position + Vector2(85, 0)
	session.dummy_velocity = Vector2.ZERO
	var hp_before := session.dummy_hp
	await physics_frame
	Input.action_press("move_down")
	await physics_frame
	Input.action_press("move_right")
	await physics_frame
	Input.action_release("move_down")
	await physics_frame
	Input.action_press("attack_c")
	await physics_frame
	Input.action_release("attack_c")
	Input.action_release("move_right")
	# action_press 要到下一个物理帧才会被 just_pressed 消费：轮询等待招式锁定。
	var locked := false
	for i in 5:
		await physics_frame
		if session.player_move_id == "236C":
			locked = true
			break
	_check(locked, "keyboard 236 then C locks the derivative move")
	var saw_float := false
	var saw_float_status := false
	var saw_air_recovered := false
	var saw_air_recovered_status := false
	var back_to_neutral := false
	var status: Label = main.get_node("DummyStatus")
	for i in 100:
		await physics_frame
		if session.dummy_state == CombatSession.DummyState.AIR_HITSTUN:
			saw_float = true
			saw_float_status = saw_float_status or status.text.contains("浮空受击")
		elif session.dummy_state == CombatSession.DummyState.AIR_RECOVERED:
			saw_air_recovered = true
			saw_air_recovered_status = saw_air_recovered_status or status.text.contains("空中已受身")
		elif session.dummy_state == CombatSession.DummyState.NEUTRAL and saw_float:
			back_to_neutral = true
			break
	_check(saw_float, "236C hit launches the dummy into float hitstun via keyboard input")
	_check(saw_float_status, "status display shows the float hitstun state")
	_check(saw_air_recovered, "dummy techs in the air after the float hitstun")
	_check(saw_air_recovered_status, "status display shows the air-recovered state")
	_check(back_to_neutral and status.text.contains("中立"), "dummy returns to neutral after landing")
	_check(_approx_hp(session.dummy_hp, hp_before - GameParams.MOVE_236C_DAMAGE), "236C applies its own base damage")


func _test_jump_cancel_air_pursuit(main: Node2D, session: CombatSession) -> void:
	# 键盘完整走通 jump cancel 前半段：236C 命中 → Space 取消起跳（连段保留、
	# 姿态转空中）→ A 起手 jA 空中追击命中；追击不刷新滞空，木桩照常落地。
	for i in 60:
		await physics_frame
		if session.player_phase == CombatSession.PlayerPhase.NEUTRAL and session.dummy_state == CombatSession.DummyState.NEUTRAL:
			break
	session.player_position = Vector2(GameParams.PLAYER_SPAWN_X, GameParams.ground_stand_y())
	session.player_velocity = Vector2.ZERO
	session.player_facing = 1
	session.dummy_position = session.player_position + Vector2(72, 0)
	session.dummy_velocity = Vector2.ZERO
	var hp_before := session.dummy_hp
	await physics_frame
	Input.action_press("move_down")
	await physics_frame
	Input.action_press("move_right")
	await physics_frame
	Input.action_release("move_down")
	await physics_frame
	Input.action_press("attack_c")
	await physics_frame
	Input.action_release("attack_c")
	Input.action_release("move_right")
	# action_press 要到下一个物理帧才会被 just_pressed 消费：轮询等待派生锁定与命中。
	var locked := false
	for i in 6:
		await physics_frame
		if session.player_move_id == "236C":
			locked = true
			break
	_check(locked, "keyboard 236 then C locks the derivative for the jump cancel route")
	var jumped := false
	for i in 10:
		await physics_frame
		if session.dummy_hp < hp_before:
			await _wait_hitstop_over(session)
			Input.action_press("jump")
			await physics_frame
			Input.action_release("jump")
			# 注入的按键在下一个物理帧才被消费：多等一帧再观察 jump cancel 结果。
			await physics_frame
			jumped = true
			break
	_check(jumped, "236C lands to open the jump cancel window after the freeze")
	# Space 请求先进入 4f 起跳准备（issue 15）：轮询等待离地再观察姿态与空中输入。
	var airborne := false
	for i in 10:
		await physics_frame
		if not session.player_on_ground:
			airborne = true
			break
	_check(airborne, "jump cancel request leaves the ground after the four pre-jump frames")
	_check(session.player_move_id == "" and session.combo_active, "jump cancel clears the move but keeps the combo alive")
	var status: Label = main.get_node("DummyStatus")
	var saw_air_posture := false
	Input.action_press("attack_a")
	await physics_frame
	Input.action_release("attack_a")
	var pursuit_hit := false
	for i in 20:
		await physics_frame
		saw_air_posture = saw_air_posture or status.text.contains("玩家 空中")
		if session.combo_hits == 2:
			pursuit_hit = true
			break
	_check(session.player_move_id == "jA" or pursuit_hit, "air action after jump cancel starts the jA pursuit move")
	_check(saw_air_posture, "status display shows the airborne player posture")
	_check(pursuit_hit, "jA pursuit lands as the second combo hit via keyboard input")
	var landed := false
	for i in 60:
		await physics_frame
		if session.player_on_ground and session.dummy_on_ground:
			landed = true
			break
	_check(landed, "player and dummy both land after the pursuit")
	_check(session.combo_hits == 2, "no extra hits: the pursuit does not refresh the float for another launch")
	_check(session.dummy_hp == hp_before - GameParams.MOVE_236C_DAMAGE - GameParams.MOVE_JA_DAMAGE * 0.9, "route damage is 236C full plus decayed jA")


func _test_full_air_route_keyboard(main: Node2D, session: CombatSession) -> void:
	# 键盘完整走通进阶路线 5A → 236C → Space → jA → jB → jD：五击全部命中，
	# 空中收尾结束连段；状态栏显示空中姿态与连段计数，木桩照常落地并自然受身。
	for i in 60:
		await physics_frame
		if session.player_phase == CombatSession.PlayerPhase.NEUTRAL and session.dummy_state == CombatSession.DummyState.NEUTRAL:
			break
	session.player_position = Vector2(GameParams.PLAYER_SPAWN_X, GameParams.ground_stand_y())
	session.player_velocity = Vector2.ZERO
	session.player_facing = 1
	session.dummy_position = session.player_position + Vector2(52, 0)
	session.dummy_velocity = Vector2.ZERO
	# 前面各测试已累积扣血：重置木桩血量，避免本路线中途触底钳制 0 血。
	session.dummy_hp = GameParams.DUMMY_MAX_HP
	var status: Label = main.get_node("DummyStatus")
	await physics_frame
	# 5A 地面起手。
	Input.action_press("attack_a")
	await physics_frame
	Input.action_release("attack_a")
	var got_hit := false
	for i in 15:
		await physics_frame
		if session.combo_hits == 1:
			got_hit = true
			break
	_check(got_hit, "5A opens the air route as the first hit via keyboard")
	# 5A 取消窗内输入 236 再按 C，命中确认后取消进浮空。
	Input.action_press("move_down")
	await physics_frame
	Input.action_press("move_right")
	await physics_frame
	Input.action_release("move_down")
	await physics_frame
	Input.action_press("attack_c")
	await physics_frame
	Input.action_release("attack_c")
	Input.action_release("move_right")
	got_hit = false
	for i in 15:
		await physics_frame
		if session.combo_hits == 2:
			got_hit = true
			break
	_check(got_hit and session.player_move_id == "236C", "buffered 236C cancels 5A into the launcher")
	_check(session.dummy_state == CombatSession.DummyState.AIR_HITSTUN, "launcher puts the dummy into float hitstun")
	# Space jump cancel 转入空中，连段保留。停顿内 Space 写入独立跳跃槽、恢复
	# 首个正常帧消费（issue 15）；这里等停顿结束后按下，再轮询等待 4f 准备过去。
	await _wait_hitstop_over(session)
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	var airborne := false
	for i in 10:
		await physics_frame
		if not session.player_on_ground:
			airborne = true
			break
	_check(airborne and session.combo_active, "space jump-cancels the confirmed launcher into the air after pre-jump")
	# jA → jB → jD 空中路线；状态栏显示空中姿态与逐击累计的连段计数。
	var saw_air_posture := false
	var route_hits := 0
	for key in ["a", "b", "d"]:
		Input.action_press("attack_" + key)
		await physics_frame
		Input.action_release("attack_" + key)
		got_hit = false
		for i in 15:
			await physics_frame
			saw_air_posture = saw_air_posture or status.text.contains("玩家 空中")
			if session.combo_hits == 2 + route_hits + 1:
				got_hit = true
				break
		route_hits += 1
		_check(got_hit, "air route key %s lands as combo hit %d" % [key.to_upper(), 2 + route_hits])
	_check(route_hits == 3 and session.combo_hits == 5 and not session.combo_active, "jD finishes the air route at five hits and ends the combo")
	_check(saw_air_posture, "status display shows the airborne posture during the route")
	_check(status.text.contains("连段 5"), "status display shows the five-hit combo")
	_check(_approx_hp(session.dummy_hp, GameParams.DUMMY_MAX_HP - 53.0), "route damage totals 53.0 through the decay")
	var settled := false
	for i in 90:
		await physics_frame
		if session.player_on_ground and session.dummy_state == CombatSession.DummyState.NEUTRAL:
			settled = true
			break
	_check(settled, "player lands and the dummy recovers naturally after the air finisher")
	_check(session.combo_hits == 5, "no extra hits land after the route")


func _approx_hp(value: float, expected: float) -> bool:
	return absf(value - expected) < 0.05


## 等待会话退出 Hitstop 冻结（含命中当帧后的整个停顿窗）：停顿内 Space 写入
## 独立跳跃槽（issue 15），恢复首个正常帧才可能消费；这里等停顿结束后再按。
func _wait_hitstop_over(session: CombatSession) -> void:
	for i in GameParams.HITSTOP_FRAMES + 4:
		await physics_frame
		if int(session.debug_snapshot()["hitstop_left"]) == 0:
			break


func _test_backward_qcb_keyboard(main: Node2D, session: CombatSession) -> void:
	# 后退不翻面（issue 12）：真实键盘路径下地面中立直接搓 214——S → S+A → A → J。
	# 按住“后”不翻转面向，214D 被识别、执行并命中（阶段 1 的用户症状经真实
	# 输入适配路径回归）。
	for i in 60:
		await physics_frame
		if session.player_phase == CombatSession.PlayerPhase.NEUTRAL and session.dummy_state == CombatSession.DummyState.NEUTRAL:
			break
	session.player_position = Vector2(GameParams.PLAYER_SPAWN_X, GameParams.ground_stand_y())
	session.player_velocity = Vector2.ZERO
	session.player_facing = 1
	session.dummy_position = session.player_position + Vector2(70, 0)
	session.dummy_velocity = Vector2.ZERO
	var hp_before := session.dummy_hp
	await physics_frame
	Input.action_press("move_down")
	await physics_frame
	Input.action_press("move_left")
	await physics_frame
	Input.action_release("move_down")
	Input.action_press("attack_d")
	await physics_frame
	Input.action_release("attack_d")
	Input.action_release("move_left")
	var locked := false
	for i in 6:
		await physics_frame
		if session.player_move_id == "214D":
			locked = true
			break
	_check(locked, "keyboard 214 from ground neutral (holding back) locks 214D")
	_check(session.player_facing == 1, "holding back keeps facing the dummy through the whole keyboard input")
	var hit := false
	for i in 30:
		await physics_frame
		if session.dummy_hp < hp_before:
			hit = true
			break
	_check(hit, "the keyboard 214D connects on the nearby dummy")


func _test_air_derivation_keyboard() -> void:
	# 配置的空中方向派生走真实训练场输入路径（issue 12）：临时合法 manifest =
	# 共享 9 招 + 空中派生 j214D（AIR + 214 + D）。前跳后 S → S+A → A → J 在空中
	# 识别并起手 j214D；木桩在射程外——成功出招但未命中可区分。
	var air_qcb := (MoveData.default_table()["jD"] as MoveData).duplicate()
	air_qcb.move_id = "j214D"
	air_qcb.direction_derivation = "214D"
	air_qcb.command_tier = MoveData.CommandTier.SPECIAL
	ResourceSaver.save(air_qcb, "user://smoke_air_qcb.tres")
	var shared_manifest := ResourceLoader.load("res://data/move_manifest.tres") as MoveManifest
	var manifest := MoveManifest.new()
	manifest.move_paths = shared_manifest.move_paths.duplicate()
	manifest.move_paths.append("user://smoke_air_qcb.tres")
	ResourceSaver.save(manifest, "user://smoke_air_manifest.tres")

	var air_main: Node2D = load("res://scenes/main.tscn").instantiate()
	air_main.set("manifest_path", "user://smoke_air_manifest.tres")
	root.add_child(air_main)
	await process_frame
	var session: CombatSession = air_main.get("session")
	_check(session != null, "training ground runs the temp manifest with the configured air derivative")
	if session == null:
		air_main.queue_free()
		await process_frame
		return
	_check((session.move_table() as Dictionary).has("j214D"), "session table contains the configured j214D")
	session.dummy_position = Vector2(900.0, GameParams.ground_stand_y())
	await physics_frame
	var hp_before := session.dummy_hp
	# 前跳（面向 +1，木桩在远处）：Space 请求先经 4f 起跳准备，轮询等待离地。
	Input.action_press("jump")
	Input.action_press("move_right")
	await physics_frame
	Input.action_release("jump")
	Input.action_release("move_right")
	var airborne := false
	for i in 10:
		await physics_frame
		if not session.player_on_ground:
			airborne = true
			break
	_check(airborne, "forward jump lifts the player before the air input")
	# 空中 S → S+A → A → J：按锁定面向折算为 2→1→4 + D。
	Input.action_press("move_down")
	await physics_frame
	Input.action_press("move_left")
	await physics_frame
	Input.action_release("move_down")
	Input.action_press("attack_d")
	await physics_frame
	Input.action_release("attack_d")
	Input.action_release("move_left")
	var locked := false
	for i in 6:
		await physics_frame
		if session.player_move_id == "j214D":
			locked = true
			break
	_check(locked, "keyboard air 214 folded by the locked facing starts the configured j214D")
	_check(not session.player_on_ground, "j214D starts while still airborne via the real input path")
	var whiffed := true
	for i in 30:
		await physics_frame
		if session.dummy_hp < hp_before:
			whiffed = false
			break
	_check(whiffed and session.dummy_hp == hp_before, "started-but-whiffed is distinguishable on the real input path")
	# 收尾：等落地并清理临时场景（不影响后续测试的主场景）。
	for i in 60:
		await physics_frame
		if session.player_on_ground:
			break
	air_main.queue_free()
	await process_frame


func _test_session_runs_shared_manifest(main: Node2D) -> void:
	# 训练场会话运行的是共享 manifest 的同一份数据（issue 11）：招式集合与代表字段
	# 都来自 data/move_manifest.tres，冻结首版数值与 GameParams 基线一致。
	var shared := MoveTable.load_default()
	_check(shared.ok, "shared manifest loads and validates for the training ground")
	if not shared.ok:
		return
	var session: CombatSession = main.session
	var table := session.move_table()
	_check(table.keys() == shared.moves.keys(), "training ground session runs the shared manifest move set")
	var session_5a := table["5A"] as MoveData
	var shared_5a := shared.moves["5A"] as MoveData
	_check(session_5a.startup_frames == shared_5a.startup_frames
		and session_5a.startup_frames == GameParams.MOVE_5A_STARTUP_FRAMES,
		"session 5A startup comes from the shared resource (frozen baseline 5)")
	_check(session_5a.base_damage == shared_5a.base_damage
		and session_5a.base_damage == GameParams.MOVE_5A_DAMAGE,
		"session 5A damage comes from the shared resource (frozen baseline 10)")
	var launcher := table["236C"] as MoveData
	_check(launcher.direction_derivation == "236C" and launcher.action_key == "C",
		"derivative moves carry explicit input bindings from the shared resource")


func _test_main_refuses_invalid_manifest() -> void:
	# 手改资源造成非法表：训练场保持拒绝状态（session 为 null）、显示与
	# MoveTable/Solver 完全相同的可定位原因，不回退旧 GameParams 继续运行。
	var broken := (MoveData.default_table()["5A"] as MoveData)
	broken.base_damage = -1
	ResourceSaver.save(broken, "user://smoke_bad_move.tres")
	var manifest := MoveManifest.new()
	manifest.move_paths = ["user://smoke_bad_move.tres"]
	ResourceSaver.save(manifest, "user://smoke_bad_manifest.tres")

	var refused: Node2D = load("res://scenes/main.tscn").instantiate()
	refused.set("manifest_path", "user://smoke_bad_manifest.tres")
	root.add_child(refused)
	await process_frame
	_check(refused.get("session") == null, "training ground refuses to run on an invalid move table")
	var table_error: String = refused.get("table_error")
	_check(table_error != "", "refusal reason is observable on the training ground")
	var load_result := MoveTable.load_manifest("user://smoke_bad_manifest.tres")
	_check(table_error == load_result.first_error(),
		"training ground shows the same rejection reason as the shared loader")
	if not load_result.ok:
		_check(load_result.errors[0].contains("smoke_bad_move.tres") and load_result.errors[0].contains("5A") \
			and load_result.errors[0].contains("base_damage"),
			"rejection reports resource source, move id and field")
	var hint: Label = refused.get_node_or_null("Hint")
	_check(hint != null and hint.text.contains("base_damage") and hint.text.contains("拒绝"),
		"hint label shows the refusal and the offending field")
	var report := ComboSolver.analyze_manifest("user://smoke_bad_manifest.tres")
	_check(report.refused and report.refusal_reason == table_error,
		"solver refuses the same table for the same observable reason")
	# 拒绝状态不产生会话事件：场景仍可安全迭代（重置流程不受影响）。
	refused.queue_free()
	await process_frame


func _test_reset(main: Node2D) -> void:
	var session: CombatSession = main.session
	_check(session.dummy_hp < GameParams.DUMMY_MAX_HP, "dummy damaged before reset")
	var old_main: Node = main
	var event := InputEventAction.new()
	event.action = "reset"
	event.pressed = true
	Input.parse_input_event(event)
	# reset 在输入刷新（process 帧）时触发，可能晚于若干物理帧；轮询等待重载完成。
	var fresh_main: Node = null
	for i in 30:
		await physics_frame
		fresh_main = root.get_node_or_null("Main")
		if fresh_main != null and fresh_main != old_main:
			break
	_check(fresh_main != null and fresh_main != old_main, "scene reloaded on reset")
	if fresh_main != null:
		var fresh_session: CombatSession = fresh_main.session
		var fresh_dummy: Dummy = fresh_main.get_node_or_null("Dummy")
		var fresh_player: Player = fresh_main.get_node_or_null("Player")
		_check(fresh_session.dummy_hp == GameParams.DUMMY_MAX_HP, "reset restores dummy hp")
		_check(fresh_session.dummy_state == CombatSession.DummyState.NEUTRAL, "reset restores dummy state")
		_check(fresh_player != null and fresh_player.position.x == GameParams.PLAYER_SPAWN_X, "reset restores player spawn")


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  " + label)
	else:
		_failures += 1
		print("FAIL  " + label)
