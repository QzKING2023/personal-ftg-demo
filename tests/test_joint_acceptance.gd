extends SceneTree
## 最新规格的联合验收反例：显式落地目标不能绕过空技着地惩罚。
var failures := 0

func _initialize() -> void:
	for facing in [1, -1]:
		var session := CombatSession.new()
		session.player_facing = facing
		session.dummy_position = session.player_position + Vector2(52 * facing, 0)
		var hits: Array[int] = []
		var landed := false
		for frame in range(1, 85):
			var key: String = {36: "B", 41: "D"}.get(frame, "")
			var events := session.step(FrameInput.make(0,
				frame == 1, key, false))
			for event in events:
				if event.type == CombatEvent.Type.HIT:
					hits.append(frame)
			if frame == 43:
				landed = session.player_on_ground and session.player_landing_recovery_left == 4
				print("LANDING facing=%d physical=%d move=%s recovery=%d hits=%s" %
					[facing, frame, session.player_move_id, session.player_landing_recovery_left, hits])
				check(landed and session.combo_hits == 1, "real input route hits jB before landing")
			if session.player_landing_recovery_left > 0:
				check(session.player_move_id == "", "landing recovery rejects configured cancel facing=%d F%d" % [facing, frame])
		check(hits == [43], "forbidden landing followup never becomes a second hit")
	print("ALL JOINT ACCEPTANCE TESTS PASSED" if failures == 0 else "%d TEST(S) FAILED" % failures)
	quit(0 if failures == 0 else 1)

func check(ok: bool, message: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + message)
	if not ok:
		failures += 1
