extends SceneTree
## 无头测试：逻辑冒烟 + 物理集成，不依赖渲染与真实按键。
## 运行：godot --headless --path . -s res://tests/test_smoke.gd
## 说明：-s 模式下节点的 _ready 要等第一帧迭代才触发，
## 因此测试挂在一帧 process_frame 之后执行；集成测试用 physics_frame 推进物理帧，
## 用 Input.action_press / parse_input_event 注入输入，结束时调用 quit()。

const STEP := 1.0 / 60.0

var _failures := 0


func _initialize() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	var main := _test_main_scene_builds()
	var player: Node = main.get_node("Player")
	var dummy: Node = main.get_node("Dummy")
	_test_dummy_receive_hit(dummy)
	_test_dummy_hp_clamps_at_zero(dummy)
	_test_one_hit_per_swing(player, dummy)
	_test_attack_phases(player)
	await _test_movement_and_bounds(player, dummy)
	await _test_jump(player)
	await _test_attack_range(player, dummy)
	await _test_reset(player, dummy)
	print("")
	if _failures == 0:
		print("ALL TESTS PASSED")
		quit(0)
	else:
		print(str(_failures) + " TEST(S) FAILED")
		quit(1)


# --- 冒烟测试（同步逻辑）---

func _test_main_scene_builds() -> Node:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	# -s 环境下手动加载场景不会设置 current_scene，补上以支持 reload_current_scene。
	current_scene = main
	_check(main.get_node_or_null("Player") != null, "main scene spawns Player")
	_check(main.get_node_or_null("Dummy") != null, "main scene spawns Dummy")
	_check(main.get_node("Dummy").hp == GameParams.DUMMY_MAX_HP, "dummy starts at full hp")
	_check(main.get_node("Player").attack_shape.disabled, "attack hitbox starts disabled")
	return main


func _test_dummy_receive_hit(dummy: Node) -> void:
	var hp_before: float = dummy.hp
	dummy.receive_hit(GameParams.ATTACK_DAMAGE, 1)
	_check(dummy.hp == hp_before - GameParams.ATTACK_DAMAGE, "receive_hit reduces hp")
	_check(dummy.velocity.x > 0.0, "hit from the left knocks dummy right")
	_check(dummy.modulate == GameParams.HIT_FLASH_COLOR, "hit flashes the dummy")
	dummy.receive_hit(GameParams.ATTACK_DAMAGE, -1)
	_check(dummy.velocity.x < 0.0, "hit from the right knocks dummy left")


func _test_dummy_hp_clamps_at_zero(dummy: Node) -> void:
	for i in 20:
		dummy.receive_hit(GameParams.ATTACK_DAMAGE, 1)
	_check(dummy.hp == 0.0, "hp clamps at zero")


func _test_one_hit_per_swing(player: Node, dummy: Node) -> void:
	dummy.hp = GameParams.DUMMY_MAX_HP
	player._start_attack()
	player._phase = Player.AttackPhase.ACTIVE
	var first_hit: bool = player._try_hit_body(dummy)
	var second_hit: bool = player._try_hit_body(dummy)
	_check(first_hit and not second_hit, "same swing hits the same target at most once")
	_check(dummy.hp == GameParams.DUMMY_MAX_HP - GameParams.ATTACK_DAMAGE, "damage applied exactly once per swing")


func _test_attack_phases(player: Node) -> void:
	player._start_attack()
	player._physics_process(STEP)
	_check(player._phase == Player.AttackPhase.STARTUP, "attack starts in startup")
	for i in 5:
		player._physics_process(STEP)
	_check(player._phase == Player.AttackPhase.ACTIVE, "startup flows into active")
	_check(not player.attack_shape.disabled, "hitbox enabled during active")
	for i in 8:
		player._physics_process(STEP)
	_check(player._phase == Player.AttackPhase.RECOVERY, "active flows into recovery")
	_check(player.attack_shape.disabled, "hitbox disabled during recovery")
	for i in 16:
		player._physics_process(STEP)
	_check(player._phase == Player.AttackPhase.NONE, "recovery returns to idle")
	_check(player.attack_shape.disabled, "hitbox disabled after attack")


# --- 集成测试（真实物理帧 + 注入输入）---

func _test_movement_and_bounds(player: Node, dummy: Node) -> void:
	var floor_y := GameParams.ground_stand_y()
	player.position = Vector2(240, floor_y)
	dummy.position = Vector2(100, floor_y)
	await physics_frame
	var start_x: float = player.position.x
	Input.action_press("move_right")
	for i in 30:
		await physics_frame
	Input.action_release("move_right")
	_check(player.position.x > start_x + 50.0, "player moves right with input held")
	Input.action_press("move_right")
	for i in 240:
		await physics_frame
	Input.action_release("move_right")
	var wall_limit := GameParams.STAGE_WIDTH - GameParams.WALL_THICKNESS - GameParams.BODY_SIZE.x * 0.5
	_check(absf(player.position.x - wall_limit) < 1.0, "player stops at the right stage wall")
	await physics_frame
	_check(absf(player.position.x - wall_limit) < 1.5, "player rests against the wall after input released")


func _test_jump(player: Node) -> void:
	var floor_y: float = player.position.y
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	var peak: float = player.position.y
	for i in 120:
		await physics_frame
		peak = minf(peak, player.position.y)
		if i > 5 and player.is_on_floor():
			break
	_check(peak <= floor_y - 60.0, "player rises well above the ground on jump")
	_check(absf(player.position.y - floor_y) < 2.0, "player lands back on the ground")


func _test_attack_range(player: Node, dummy: Node) -> void:
	var floor_y := GameParams.ground_stand_y()
	player.position = Vector2(240, floor_y)
	player.facing = 1
	dummy.hp = GameParams.DUMMY_MAX_HP
	# 远离：整套攻击打完不应命中。
	dummy.position = Vector2(800, floor_y)
	await physics_frame
	player._start_attack()
	for i in 40:
		await physics_frame
	_check(dummy.hp == GameParams.DUMMY_MAX_HP, "attack misses when the dummy is far away")
	# 贴近：应命中一次。
	dummy.position = player.position + Vector2(70, 0)
	await physics_frame
	player._start_attack()
	for i in 40:
		await physics_frame
	_check(dummy.hp == GameParams.DUMMY_MAX_HP - GameParams.ATTACK_DAMAGE, "attack hits once when the dummy is close")


func _test_reset(player: Node, dummy: Node) -> void:
	# 让场景处于受击后的脏状态，再通过 reset 输入事件触发重载。
	dummy.receive_hit(GameParams.ATTACK_DAMAGE, 1)
	_check(dummy.hp < GameParams.DUMMY_MAX_HP, "dummy damaged before reset")
	var old_main: Node = player.get_parent()
	var event := InputEventAction.new()
	event.action = "reset"
	event.pressed = true
	Input.parse_input_event(event)
	for i in 3:
		await physics_frame
	var fresh_main := root.get_node_or_null("Main")
	_check(fresh_main != null and fresh_main != old_main, "scene reloaded on reset")
	if fresh_main != null:
		var fresh_dummy: Node = fresh_main.get_node_or_null("Dummy")
		var fresh_player: Node = fresh_main.get_node_or_null("Player")
		_check(fresh_dummy != null and fresh_dummy.hp == GameParams.DUMMY_MAX_HP, "reset restores dummy hp")
		_check(fresh_player != null and fresh_player.position.x == GameParams.PLAYER_SPAWN_X, "reset restores player spawn")


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  " + label)
	else:
		_failures += 1
		print("FAIL  " + label)
