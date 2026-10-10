extends SceneTree
func _initialize() -> void:
	var session := CombatSession.new()
	session.dummy_position = Vector2(580.0, 470.0 - 70.0)
	session.dummy_velocity = Vector2(0.0, 23.3333 * 4)
	var step := GameParams.GRAVITY * GameParams.PHYSICS_TICK
	print("gravity step=%.6f jump_v=%.4f", step, GameParams.jump_velocity())
	var h := 0.0
	for j in range(1, 25):
		h -= step * (j - 20) * GameParams.PHYSICS_TICK
	print("analytic h(24)=%.6f", h)
	for frame in range(0, 4):
		var vy0 := session.dummy_velocity.y
		var y0 := session.dummy_position.y
		session.step(FrameInput.new())
		print("F%d: vy %.4f -> %.4f | y %.4f -> %.4f (fall %.4f, %.4f/tick)" % [frame + 1, vy0, session.dummy_velocity.y, y0, session.dummy_position.y, session.dummy_position.y - y0, (session.dummy_position.y - y0) / GameParams.PHYSICS_TICK])
	quit(0)
