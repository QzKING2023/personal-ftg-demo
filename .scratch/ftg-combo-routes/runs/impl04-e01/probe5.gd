extends SceneTree
func _initialize() -> void:
	var s := CombatSession.new()
	s.dummy_position = s.player_position + Vector2(26.0, 0)
	var plan := {}
	plan[1] = _mk("C", 0, true)
	plan[17] = _mk("D", 1, false)
	plan[35] = FrameInput.make(0, false, "D", true)
	plan[49] = _d(0); plan[50] = _d(1); plan[51] = _d(1); plan[52] = _mk("C", 1, false)
	for frame in range(1, 80):
		var before := s.player_move_id
		for e in s.step(plan.get(frame, FrameInput.new())):
			if e.type == e.Type.HIT:
				print("F%d HIT %s" % [frame, before])
	quit(0)
func _mk(k: String, axis: int, down: bool) -> FrameInput:
	return FrameInput.make(axis, false, k, down)
func _d(a: int) -> FrameInput:
	return FrameInput.make(a, false, "", false)
