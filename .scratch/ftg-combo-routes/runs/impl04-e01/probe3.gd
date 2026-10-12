extends SceneTree
func _initialize() -> void:
	var s := CombatSession.new()
	var wall := GameParams.stage_right_limit()
	var dummy_x := wall - 6.7
	s.dummy_position = Vector2(dummy_x, GameParams.ground_stand_y())
	s.player_position = Vector2(dummy_x - (GameParams.BODY_SIZE.x + 9.3), GameParams.ground_stand_y())
	s.player_facing = 1
	var plan := {}
	plan[1] = _p("B"); plan[12] = _pd("C"); plan[46] = _p("B")
	for frame in range(1, 85):
		var before := s.player_move_id
		for e in s.step(plan.get(frame, FrameInput.new())):
			if e.type in [e.Type.HIT, e.Type.COMBO_ENDED, e.Type.LOW_FLOAT_LANDED, e.Type.DUMMY_RECOVERED, e.Type.LINK_FAILED]:
				print("F%d ev %s move=%s" % [frame, e.Type.keys()[e.type], before])
		if frame >= 40:
			var st = s.clone_state()
			print("F%d move=%s mf=%s ds=%s" % [frame, st.player_move.move_id, str(st.player_move.frame), CombatSession.DummyState.keys()[s.dummy_state]])
	quit(0)
func _p(k: String) -> FrameInput:
	var i := FrameInput.new(); i.pressed_action_keys=[k]; i.held_action_keys=[k]; return i
func _pd(k: String) -> FrameInput:
	var i := _p(k); i.down_held = true; return i
