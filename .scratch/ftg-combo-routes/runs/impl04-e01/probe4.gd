extends SceneTree
## J2 C6 断因探针：逐帧观察 2C>214C>~B>5B 固定计划。
func _initialize() -> void:
	var facing := 1
	var s := CombatSession.new()
	var dx := 12.0
	s.dummy_position = s.player_position + Vector2(dx, 0)
	s.player_facing = facing
	var plan := {}
	plan[1] = _d(facing, 2, "C")
	plan[13] = _d(facing, 2)
	plan[14] = _d(facing, 1)
	plan[15] = _d(facing, 4)
	plan[16] = _mk("C", -facing)
	plan[29] = _mk("B", 0)
	plan[67] = _mk("B", 0)
	for frame in range(1, 96):
		var before := s.player_move_id
		var buffered_before: String = str(s.debug_snapshot()["buffered_move_id"])
		for e in s.step(plan.get(frame, FrameInput.new())):
			if e.type in [e.Type.HIT, e.Type.COMBO_ENDED, e.Type.HITSTOP_ENDED, e.Type.LINK_FAILED, e.Type.REKKA_BRANCH_LOCKED]:
				print("F%d ev %s move=%s reason=%s link=%s" % [frame, e.Type.keys()[e.type], before, str(e.combo_end_reason), str(e.link_fail_reason)])
		if frame in [9,10,17,18,19,20,21,26,27,28,31,32,33]:
			var st = s.clone_state()
			print("F%d move=%s buf=%s/%s combo=%s" % [frame, st.player_move.move_id, str(buffered_before), str(s.debug_snapshot()["buffered_move_id"]), str(s.combo_active)])
	quit(0)
func _d(f: int, digit: int, key: String = "") -> FrameInput:
	var axis := 0
	if digit == 3 or digit == 6 or digit == 9: axis = f
	elif digit == 1 or digit == 4 or digit == 7: axis = -f
	var i := FrameInput.make(axis, false, key, digit >= 1 and digit <= 3)
	return i
func _mk(k: String, axis: int) -> FrameInput:
	return FrameInput.make(axis, false, k, false)
