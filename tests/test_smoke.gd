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
	await _test_attack_hit_and_feedback(main, player, dummy, session)
	await _test_attack_range(session)
	await _test_ground_combo_display(main, session)
	await _test_direction_derivative_and_float(main, session)
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


func _approx_hp(value: float, expected: float) -> bool:
	return absf(value - expected) < 0.05


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
