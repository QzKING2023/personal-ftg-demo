extends SceneTree
## 在新进程加载真实默认 manifest，观察训练场输入适配后的命中及 Solver 输出。
var scene: Node2D
var failed := false

func _initialize() -> void:
	process_frame.connect(run, CONNECT_ONE_SHOT)

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var invalid := "--invalid" in args
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	var report := ComboSolver.solve()
	if invalid:
		check(scene.session == null and report.refused, "invalid local file rejected by training ground and Solver")
		check(scene.table_error == report.refusal_reason, "same resource, id, field and rejection reason")
		print("REFUSAL ", scene.table_error)
	else:
		var startup := int(args[0])
		var damage := float(args[1])
		var session: CombatSession = scene.session
		if session == null or report.refused:
			check(false, "legal local file loads in both consumers")
		else:
			session.dummy_position = session.player_position + Vector2(70, 0)
			var start := -1
			var hit := -1
			var hp := session.dummy_hp
			var event := InputEventKey.new()
			event.physical_keycode = KEY_U
			event.pressed = true
			Input.parse_input_event(event)
			for tick in range(1, 40):
				await physics_frame
				if tick == 3:
					event.pressed = false
					Input.parse_input_event(event)
				if start < 0 and session.player_move_id == "5A":
					start = tick
				if hit < 0 and session.dummy_hp < hp:
					hit = tick
			check(start >= 0 and hit - start == startup, "training ground U input observes edited startup")
			check(is_equal_approx(hp - session.dummy_hp, damage), "training ground observes edited damage")
			var found := false
			for route in report.routes:
				if route.move_ids == ["5A", "5B", "5D"]:
					found = true
					check(route.hit_frames[0] == 1 + startup, "Solver observes same first-hit frame")
					check(is_equal_approx(route.total_damage, damage + 25.2), "Solver observes same damage change")
					print("FILE_SYNC startup=%d damage=%.1f training_start=%d training_hit=%d solver_hits=%s solver_damage=%.1f" %
						[startup, damage, start, hit, route.hit_frames, route.total_damage])
			check(found, "representative ground route remains available")
	scene.queue_free()
	await process_frame
	quit(1 if failed else 0)

func check(ok: bool, message: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + message)
	failed = failed or not ok
