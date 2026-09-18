extends SceneTree
## 真人试玩回归：地面蹲姿停止主动移动，方向仍进入搓招历史。
var failures := 0

func _initialize() -> void:
	var minimal := CombatSession.new()
	var origin := minimal.player_position.x
	minimal.step(FrameInput.make(1, false, "", true))
	check(minimal.player_crouching and is_equal_approx(minimal.player_position.x, origin),
		"one frame down-forward from rest: dx=%.3f vx=%.3f" % [minimal.player_position.x - origin, minimal.player_velocity.x])
	for facing in [1, -1]:
		for axis in [-1, 0, 1]:
			for moving in [false, true]:
				var session := CombatSession.new()
				session.player_position.x = 480
				session.player_facing = facing
				session.dummy_position = session.player_position + Vector2(300 * facing, 0)
				if moving:
					for frame in 6:
						session.step(FrameInput.make(facing))
				var start_x := session.player_position.x
				var stationary := true
				for frame in 10:
					session.step(FrameInput.make(axis, false, "", true))
					stationary = stationary and is_equal_approx(session.player_position.x, start_x) and is_zero_approx(session.player_velocity.x)
				check(session.player_crouching and stationary,
					"crouch stationary facing=%d axis=%d moving=%s x=%.3f -> %.3f vx=%.3f" % [facing, axis, moving, start_x, session.player_position.x, session.player_velocity.x])
				check(session.player_guard == (CombatSession.GuardPosture.CROUCH if axis == -facing else CombatSession.GuardPosture.NONE),
					"down-back still guards; down/down-forward do not")
				session.step(FrameInput.make(facing))
				check(not session.player_crouching and session.player_velocity.x * facing > 0,
					"releasing down restores standing movement immediately")
		_test_command_and_air(facing)
		_test_crouch_hit_knockback(facing)
	print("ALL CROUCH TESTS PASSED" if failures == 0 else "%d TEST(S) FAILED" % failures)
	quit(1 if failures else 0)

func _test_command_and_air(facing: int) -> void:
	var session := CombatSession.new()
	session.player_position.x = 480
	session.player_facing = facing
	session.dummy_position = session.player_position + Vector2(300 * facing, 0)
	session.step(FrameInput.make(0, false, "", true))
	session.step(FrameInput.make(facing, false, "", true))
	check(is_equal_approx(session.player_position.x, 480) and session.debug_snapshot()["direction_sequence"] == "23",
		"stationary crouch preserves 23 command history facing=%d" % facing)
	session.step(FrameInput.make(facing, false, "C"))
	for frame in 3:
		session.step(FrameInput.make(facing))
	check(session.player_move_id == "236C", "crouch directions still produce 236C facing=%d" % facing)
	var air := CombatSession.new()
	air.player_position.x = 480
	air.player_facing = facing
	air.dummy_position = air.player_position + Vector2(300 * facing, 0)
	air.step(FrameInput.make(facing, true))
	for frame in 4:
		air.step(FrameInput.make(facing))
	var airborne_vx := air.player_velocity.x
	for frame in 3:
		air.step(FrameInput.make(-facing, false, "", true))
	check(not air.player_on_ground and not air.player_crouching and airborne_vx * facing > 0 and is_equal_approx(air.player_velocity.x, airborne_vx),
		"air down-back preserves jump momentum facing=%d" % facing)

func _test_crouch_hit_knockback(facing: int) -> void:
	var session := CombatSession.new()
	session.player_position.x = 480
	session.player_facing = facing
	session.dummy_position = session.player_position + Vector2(70 * facing, 0)
	var hit := false
	var displaced_in_stun := false
	for frame in 30:
		var before_x := session.player_position.x
		var events := session.step(FrameInput.make(facing, false, "", true, "5A" if frame == 0 else ""))
		for event in events:
			if event.type == CombatEvent.Type.PLAYER_HIT:
				hit = true
		if session.player_hitstun_left > 0 and session.player_crouching and (session.player_position.x - before_x) * facing < 0:
			displaced_in_stun = true
	check(hit and displaced_in_stun, "crouch does not suppress incoming knockback facing=%d" % facing)

func check(ok: bool, message: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + message)
	if not ok:
		failures += 1
