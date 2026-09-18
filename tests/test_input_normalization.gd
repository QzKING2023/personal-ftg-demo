extends SceneTree
## 同一物理键映射→训练场适配→方向历史，含按住上轴与上下/左右中和。
var failures := 0

func _initialize() -> void:
	process_frame.connect(run, CONNECT_ONE_SHOT)

func run() -> void:
	var main: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_physics_process(false)
	for facing in [1, -1]:
		var forward_key := KEY_D if facing == 1 else KEY_A
		var back_key := KEY_A if facing == 1 else KEY_D
		for row in [[[KEY_SPACE], "8"], [[KEY_UP], "8"], [[KEY_SPACE, forward_key], "9"],
			[[KEY_SPACE, back_key], "7"], [[KEY_SPACE, KEY_S], ""],
			[[KEY_SPACE, KEY_S, forward_key], "6"], [[KEY_A, KEY_D], ""],
			[[KEY_UP, KEY_DOWN], ""]]:
			# 每例位于新的引擎帧，避免上一例 just_pressed 边沿驻留同一帧。
			await process_frame
			var session := CombatSession.new()
			session.player_facing = facing
			session.dummy_position = session.player_position + Vector2(200 * facing, 0)
			for key in row[0]:
				key_event(key, true)
			Input.flush_buffered_events()
			for frame in 2:
				session.step(main._read_frame_input())
			var direction := String(session.debug_snapshot()["direction_sequence"])
			check(direction == row[1], "held physical keys %s facing=%d -> %s (expected %s)" % [row[0], facing, direction, row[1]])
			if KEY_S in row[0] or KEY_DOWN in row[0]:
				check(not session.player_crouching and session.player_prejump_left == 0,
					"opposite vertical axes cause neither crouch nor jump")
			for key in row[0]:
				key_event(key, false)
			Input.flush_buffered_events()
	main.queue_free()
	await process_frame
	print("ALL INPUT NORMALIZATION TESTS PASSED" if failures == 0 else "%d TEST(S) FAILED" % failures)
	quit(1 if failures else 0)

func key_event(key: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)

func check(ok: bool, message: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + message)
	if not ok:
		failures += 1
