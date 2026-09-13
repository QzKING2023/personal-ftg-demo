extends SceneTree
## 战斗会话 seam 测试：逐帧输入驱动 CombatSession，只验证可观察状态与事件。
## 纯逻辑同步执行，不依赖场景节点与物理服务器。
## 运行：godot --headless --path . -s res://tests/test_combat_session.gd

var _failures := 0


func _initialize() -> void:
	_test_initial_state()
	_test_attack_phase_windows()
	_test_hit_lands_on_first_active_frame()
	_test_one_hit_per_swing()
	_test_miss_when_out_of_range()
	_test_configurable_move_data()
	_test_hitstun_recovery()
	_test_knockback_applied_before_motion()
	_test_facing_follows_movement()
	_test_movement_and_wall_clamp()
	_test_body_overlap_blocks_player()
	_test_jump_arc()
	_test_jump_ignored_during_attack()
	_test_air_action_without_air_move_ignored()
	_test_repeat_attack_after_recovery()
	_test_hp_clamps_at_zero()
	_test_mash_does_not_cancel_mid_move()
	_test_buffer_age_five_consumes_on_hit()
	_test_buffer_age_six_expires_before_hit()
	_test_buffer_latest_input_overwrites()
	_test_whiff_does_not_consume_buffer()
	_test_ground_route()
	_test_cancel_window_last_frame()
	_test_cancel_window_close_ends_combo()
	_test_independent_move_cannot_hit_stunned_dummy()
	_test_damage_floor_and_no_hit_cap()
	print("")
	if _failures == 0:
		print("ALL SESSION TESTS PASSED")
		quit(0)
	else:
		print(str(_failures) + " TEST(S) FAILED")
		quit(1)


# --- 测试用例 ---

func _test_initial_state() -> void:
	var session := CombatSession.new()
	_check(session.player_position == Vector2(GameParams.PLAYER_SPAWN_X, GameParams.ground_stand_y()), "player spawns at start position")
	_check(session.player_phase == CombatSession.PlayerPhase.NEUTRAL, "player starts neutral")
	_check(session.player_on_ground, "player starts grounded")
	_check(session.player_facing == 1, "player starts facing right")
	_check(session.player_move_id == "", "no move in progress at start")
	_check(session.dummy_position == Vector2(GameParams.DUMMY_SPAWN_X, GameParams.ground_stand_y()), "dummy spawns at start position")
	_check(session.dummy_hp == GameParams.DUMMY_MAX_HP, "dummy starts at full hp")
	_check(session.dummy_state == CombatSession.DummyState.NEUTRAL, "dummy starts neutral")
	_check(session.dummy_hitstun_left == 0, "dummy starts without hitstun")
	_check(session.combo_hits == 0 and not session.combo_active, "combo starts empty and inactive")
	_check(session.combo_total_damage == 0.0, "combo damage starts at zero")
	_check(not session.player_attack_rect().has_area(), "no attack rect while neutral")


func _test_attack_phase_windows() -> void:
	var session := CombatSession.new()
	var phases: Array[int] = []
	var rect_during_move := false
	for i in range(25):
		session.step(FrameInput.make(0, false, "A" if i == 0 else ""))
		phases.append(session.player_phase)
		rect_during_move = rect_during_move or session.player_attack_rect().has_area()
	_check(_phase_range(phases, 0, 3, CombatSession.PlayerPhase.STARTUP), "startup covers frames 1-4 after press")
	_check(_phase_range(phases, 4, 10, CombatSession.PlayerPhase.ACTIVE), "active covers frames 5-11 after press")
	_check(_phase_range(phases, 11, 23, CombatSession.PlayerPhase.RECOVERY), "recovery covers frames 12-24 after press")
	_check(phases[24] == CombatSession.PlayerPhase.NEUTRAL, "move ends exactly after startup+active+recovery frames")
	_check(rect_during_move, "attack rect exists while a move is in progress")
	session.step(FrameInput.new())
	_check(not session.player_attack_rect().has_area(), "attack rect gone after returning to neutral")


func _test_hit_lands_on_first_active_frame() -> void:
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var hit_frames: Array[int] = []
	var recovered_frames: Array[int] = []
	for frame in range(1, 41):
		var events := session.step(FrameInput.make(0, false, "A" if frame == 1 else ""))
		for event in events:
			if event.type == CombatEvent.Type.HIT:
				hit_frames.append(frame)
			elif event.type == CombatEvent.Type.DUMMY_RECOVERED:
				recovered_frames.append(frame)
	_check(hit_frames.size() == 1 and hit_frames[0] == 6, "hit lands exactly on the first active frame (frame 6 after press)")
	# 滞空 10 帧（第 7-16 帧）+ 落地后 12 帧硬直：第 27 帧自然受身。
	_check(recovered_frames.size() == 1 and recovered_frames[0] == 27, "dummy recovers after airborne pause plus hitstun frames")
	_check(session.dummy_hp == GameParams.DUMMY_MAX_HP - GameParams.MOVE_5A_DAMAGE, "hit applies base damage once")


func _test_one_hit_per_swing() -> void:
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var events := _swing(session)
	_check(_count_events(events, CombatEvent.Type.HIT) == 1, "whole active window produces a single hit")
	_check(session.dummy_hp == GameParams.DUMMY_MAX_HP - GameParams.MOVE_5A_DAMAGE, "damage applied exactly once per swing")


func _test_miss_when_out_of_range() -> void:
	var session := CombatSession.new()
	# 默认站位相距 380px，超出命中范围。
	var events := _swing(session)
	_check(events.is_empty(), "out-of-range swing produces no events")
	_check(session.dummy_hp == GameParams.DUMMY_MAX_HP, "out-of-range swing deals no damage")
	_check(session.combo_hits == 0, "whiff does not start a combo")


func _test_configurable_move_data() -> void:
	var move := MoveData.new()
	move.move_name = "test"
	move.startup_frames = 2
	move.active_frames = 3
	move.recovery_frames = 4
	move.base_damage = 7
	move.hitstun_frames = 5
	var session := CombatSession.new({"5A": move})
	session.dummy_position = session.player_position + Vector2(70, 0)
	var hit_frames: Array[int] = []
	var recovered_frames: Array[int] = []
	var phase_after := {}
	for frame in range(1, 20):
		var events := session.step(FrameInput.make(0, false, "A" if frame == 1 else ""))
		phase_after[frame] = session.player_phase
		for event in events:
			if event.type == CombatEvent.Type.HIT:
				hit_frames.append(frame)
			elif event.type == CombatEvent.Type.DUMMY_RECOVERED:
				recovered_frames.append(frame)
	_check(hit_frames == [3], "custom move hits on its own first active frame")
	_check(session.dummy_hp == GameParams.DUMMY_MAX_HP - 7, "custom move applies its own base damage")
	_check(phase_after[2] == CombatSession.PlayerPhase.ACTIVE and phase_after[5] == CombatSession.PlayerPhase.RECOVERY, "custom windows drive phase transitions")
	_check(phase_after[9] == CombatSession.PlayerPhase.NEUTRAL, "custom move ends after its own total frames")
	_check(recovered_frames == [17], "custom hitstun counts down after landing (hit 3, lands 13, hitstun 5)")


func _test_hitstun_recovery() -> void:
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	_swing_start(session)
	for i in range(5):
		session.step(FrameInput.new())
	# 第 6 帧（首个判定帧）命中。
	_check(session.dummy_state == CombatSession.DummyState.GROUND_HITSTUN, "dummy enters ground hitstun on hit")
	_check(not session.dummy_on_ground, "ground hit lifts the dummy briefly")
	_check(session.dummy_hitstun_left == GameParams.HITSTUN_FRAMES, "airborne frames pause the hitstun countdown")
	var steps_after_hit := 0
	var steps_to_landing := -1
	var recovered_events := 0
	while session.dummy_state == CombatSession.DummyState.GROUND_HITSTUN and steps_after_hit < 60:
		var events := session.step(FrameInput.new())
		steps_after_hit += 1
		recovered_events += _count_events(events, CombatEvent.Type.DUMMY_RECOVERED)
		if steps_to_landing == -1 and session.dummy_on_ground:
			steps_to_landing = steps_after_hit
	_check(session.dummy_state == CombatSession.DummyState.NEUTRAL, "hitstun reaching zero returns dummy to neutral")
	_check(steps_to_landing > 0, "dummy lands before recovering")
	_check(steps_after_hit - steps_to_landing == GameParams.HITSTUN_FRAMES - 1, "remaining hitstun counts down exactly hitstun frames from the landing frame")
	_check(recovered_events == 1, "recovery emits exactly one event")
	_check(session.dummy_hitstun_left == 0, "hitstun left is zero after recovery")


func _test_knockback_applied_before_motion() -> void:
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	_swing_start(session)
	for i in range(4):
		session.step(FrameInput.new())
	var pos_before: Vector2 = session.dummy_position
	session.step(FrameInput.new())
	_check(is_equal_approx(session.dummy_velocity.x, GameParams.MOVE_5A_KNOCKBACK - GameParams.DUMMY_HITSTUN_FRICTION * GameParams.PHYSICS_TICK), "hit sets horizontal knockback velocity (same-frame friction applied)")
	_check(is_equal_approx(session.dummy_velocity.y, -GameParams.ATTACK_KNOCKBACK_UP), "grounded hit adds upward knockback")
	_check(session.dummy_position.x > pos_before.x + 2.0, "dummy already moves on the hit frame (hit applies before motion)")
	_check(session.dummy_position.y < pos_before.y, "dummy lifts off on the hit frame")
	_check(not session.dummy_on_ground, "dummy is airborne on the hit frame")


func _test_facing_follows_movement() -> void:
	var session := CombatSession.new()
	for i in range(2):
		session.step(FrameInput.make(-1))
	_check(session.player_facing == -1, "moving left faces left")
	for i in range(2):
		session.step(FrameInput.make(1))
	_check(session.player_facing == 1, "moving right faces right")


func _test_movement_and_wall_clamp() -> void:
	var session := CombatSession.new()
	# 把木桩移开，避免身体阻挡干扰墙体验证。
	session.dummy_position = Vector2(100.0, GameParams.ground_stand_y())
	var start_x := session.player_position.x
	for i in range(30):
		session.step(FrameInput.make(1))
	_check(session.player_position.x > start_x + 50.0, "player moves right with input held")
	for i in range(240):
		session.step(FrameInput.make(1))
	_check(is_equal_approx(session.player_position.x, GameParams.stage_right_limit()), "player clamps at the right stage wall")
	# 左墙验证用全新会话：从出生点向左走，木桩在右侧不挡路。
	var left_session := CombatSession.new()
	for i in range(240):
		left_session.step(FrameInput.make(-1))
	_check(is_equal_approx(left_session.player_position.x, GameParams.stage_left_limit()), "player clamps at the left stage wall")
	_check(session.player_on_ground, "player stays grounded while moving")
	_check(session.player_position.y == GameParams.ground_stand_y(), "player stays on the floor while moving")


func _test_body_overlap_blocks_player() -> void:
	var session := CombatSession.new()
	for i in range(120):
		session.step(FrameInput.make(1))
	var blocked_x := session.dummy_position.x - GameParams.BODY_SIZE.x
	_check(absf(session.player_position.x - blocked_x) < 0.01, "player stops adjacent to the dummy body")
	_check(absf(session.player_position.x - session.dummy_position.x) >= GameParams.BODY_SIZE.x - 0.01, "player and dummy bodies do not overlap")
	_check(is_equal_approx(session.dummy_position.x, GameParams.DUMMY_SPAWN_X), "dummy is not pushed by the player")


func _test_jump_arc() -> void:
	var session := CombatSession.new()
	session.step(FrameInput.make(0, true))
	_check(not session.player_on_ground, "player leaves the ground on the jump frame")
	_check(session.player_position.y < GameParams.ground_stand_y(), "player rises on the jump frame")
	var peak := session.player_position.y
	for i in range(120):
		session.step(FrameInput.new())
		peak = minf(peak, session.player_position.y)
	_check(peak <= GameParams.ground_stand_y() - 60.0, "jump rises well above the ground")
	_check(session.player_on_ground, "player lands back on the ground")
	_check(is_equal_approx(session.player_position.y, GameParams.ground_stand_y()), "player returns to the floor height")
	_check(is_equal_approx(session.player_velocity.y, 0.0), "vertical velocity resets after landing")


func _test_jump_ignored_during_attack() -> void:
	var session := CombatSession.new()
	session.step(FrameInput.make(0, false, "A"))
	session.step(FrameInput.make(0, true))
	_check(session.player_on_ground, "jump input during startup is ignored")
	for i in range(10):
		session.step(FrameInput.make(0, true))
	_check(session.player_on_ground, "jump input during the whole move is ignored")


func _test_air_action_without_air_move_ignored() -> void:
	# 招式表只配置地面招式：空中按下动作键不会起手，缓存也不会被消费。
	var session := CombatSession.new()
	session.step(FrameInput.make(0, true))
	session.step(FrameInput.new())
	for i in range(12):
		session.step(FrameInput.make(0, false, "A" if i == 0 else ""))
		_check(session.player_phase == CombatSession.PlayerPhase.NEUTRAL and session.player_move_id == "", "air action without a configured air move never starts")
	_check(not session.player_attack_rect().has_area(), "no attack rect from an ignored air action")
	for i in range(40):
		session.step(FrameInput.new())
	_check(session.player_on_ground, "player lands after the jump")
	_check(session.player_phase == CombatSession.PlayerPhase.NEUTRAL, "expired air input does not start a move after landing")


func _test_repeat_attack_after_recovery() -> void:
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var events := _swing(session)
	# 等待硬直恢复与击退滑动停止，再走位贴近木桩进行第二次攻击。
	for i in range(60):
		session.step(FrameInput.new())
	for i in range(30):
		session.step(FrameInput.make(1))
	events.append_array(_swing(session))
	_check(_count_events(events, CombatEvent.Type.HIT) == 2, "second attack after full recovery hits again")
	_check(session.dummy_hp == GameParams.DUMMY_MAX_HP - GameParams.MOVE_5A_DAMAGE * 2, "repeat attacks keep reducing hp")


func _test_hp_clamps_at_zero() -> void:
	var session := CombatSession.new()
	session.dummy_hp = 5.0
	session.dummy_position = session.player_position + Vector2(70, 0)
	_swing(session)
	_check(session.dummy_hp == 0.0, "hp clamps at zero instead of going negative")


func _test_mash_does_not_cancel_mid_move() -> void:
	# 连打 A：出招中与后摇中的输入只进缓存；A 不是 5A 的取消目标，
	# 不能中途取消。收招当帧缓存中的 A 立刻起手下一记独立 5A。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var hits_by_end_of_first_move := 0
	for frame in range(1, 26):
		var events := session.step(FrameInput.make(0, false, "A"))
		hits_by_end_of_first_move += _count_events(events, CombatEvent.Type.HIT)
		if frame < 25:
			_check(session.player_move_id == "5A", "mashing never cancels the swing mid-move")
	_check(hits_by_end_of_first_move == 1, "mashing during the swing yields a single hit")
	_check(session.player_phase != CombatSession.PlayerPhase.NEUTRAL, "buffered mash chains a fresh swing right after recovery")
	var total_hits := hits_by_end_of_first_move
	for i in range(20):
		total_hits += _count_events(session.step(FrameInput.new()), CombatEvent.Type.HIT)
	_check(total_hits == 2, "chained swing hits the recovered dummy exactly once more")


func _test_buffer_age_five_consumes_on_hit() -> void:
	# 5A 前摇 8 帧：F1 出招、F9 命中；B 在 F4 输入，命中帧年龄恰为 5，是最后的有效年龄。
	var session := CombatSession.new(_slow_ground_table())
	session.dummy_position = session.player_position + Vector2(70, 0)
	for frame in range(1, 10):
		session.step(FrameInput.make(0, false, _script_key({1: "A", 4: "B"}, frame)))
	_check(session.combo_hits == 1, "5A confirms its hit on frame 9")
	_check(session.player_move_id == "5B", "buffer at age 5 is consumed on the hit-confirm frame")
	_check(session.combo_active, "cancel into 5B keeps the combo active")
	for frame in range(10, 16):
		session.step(FrameInput.new())
	_check(session.combo_hits == 2, "5B follow-up lands after the cancel")


func _test_buffer_age_six_expires_before_hit() -> void:
	# 只把 B 提前一帧（F3 输入）：F9 时年龄已达 6，缓存先过期，命中后不能取消。
	var session := CombatSession.new(_slow_ground_table())
	session.dummy_position = session.player_position + Vector2(70, 0)
	var move_ids: Array[String] = []
	for frame in range(1, 26):
		session.step(FrameInput.make(0, false, _script_key({1: "A", 3: "B"}, frame)))
		move_ids.append(session.player_move_id)
	_check(session.combo_hits == 1, "5A still hits on frame 9")
	_check(not "5B" in move_ids, "buffer at age 6 expires before the hit and is never consumed")
	_check(session.combo_hits == 1 and session.dummy_hp == GameParams.DUMMY_MAX_HP - 10.0, "expired input cannot extend the combo")


func _test_buffer_latest_input_overwrites() -> void:
	# 单槽缓存：先 D 后 B，只有最新的 B 被消费。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var move_ids: Array[String] = []
	for frame in range(1, 8):
		session.step(FrameInput.make(0, false, _script_key({1: "A", 3: "D", 4: "B"}, frame)))
		move_ids.append(session.player_move_id)
	_check(not "5D" in move_ids, "older buffered D is overwritten and never starts")
	_check(session.player_move_id == "5B", "latest buffered B is consumed after the hit confirm")


func _test_whiff_does_not_consume_buffer() -> void:
	# 木桩在范围外：5A 挥空、B 缓存在有效期内也不允许取消，过期后作废。
	var session := CombatSession.new()
	var events: Array[CombatEvent] = []
	for frame in range(1, 41):
		events.append_array(session.step(FrameInput.make(0, false, _script_key({1: "A", 4: "B"}, frame))))
	_check(_count_events(events, CombatEvent.Type.HIT) == 0, "whiff produces no hit events")
	_check(session.dummy_hp == GameParams.DUMMY_MAX_HP, "whiff deals no damage")
	_check(session.combo_hits == 0 and not session.combo_active, "whiff never starts a combo")
	_check(session.player_phase == CombatSession.PlayerPhase.NEUTRAL and session.player_move_id == "", "buffered whiff input expires without starting a second move")


func _test_ground_route() -> void:
	# 稳定地面路线 5A → 5B → 5D：每次后续招式都在命中确认后经缓存取消接上。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var events: Array[CombatEvent] = []
	var move_after_frame := {}
	var finisher_ends := 0
	var dummy_state_at_finisher: CombatSession.DummyState = CombatSession.DummyState.NEUTRAL
	var hitstun_at_finisher := 0
	for frame in range(1, 61):
		var frame_events := session.step(FrameInput.make(0, false, _script_key({1: "A", 5: "B", 9: "D"}, frame)))
		events.append_array(frame_events)
		move_after_frame[frame] = session.player_move_id
		if _combo_end_events(frame_events, CombatEvent.ComboEndReason.FINISHER) > 0:
			finisher_ends += 1
			dummy_state_at_finisher = session.dummy_state
			hitstun_at_finisher = session.dummy_hitstun_left
	var hits := _events_of(events, CombatEvent.Type.HIT)
	_check(hits.size() == 3, "ground route lands all three hits")
	_check(move_after_frame[1] == "5A" and move_after_frame[6] == "5B" and move_after_frame[10] == "5D", "route follows 5A -> 5B -> 5D via hit-confirm cancels")
	_check(hits.size() == 3 and hits[0].combo_hits == 1 and hits[1].combo_hits == 2 and hits[2].combo_hits == 3, "hit events count combo hits in order")
	if hits.size() == 3:
		_check(_approx(hits[0].damage, 10.0), "first hit deals full base damage")
		_check(_approx(hits[1].damage, 10.8), "second hit deals 90% of 5B base damage")
		_check(_approx(hits[2].damage, 14.4), "third hit deals 80% of 5D base damage")
	_check(_approx(session.combo_total_damage, 35.2), "combo total damage accumulates decayed values")
	_check(_approx(session.dummy_hp, GameParams.DUMMY_MAX_HP - 35.2), "dummy hp reflects the decayed route damage")
	_check(_approx(session.combo_last_scale, 0.8), "last hit scale is 80%")
	_check(finisher_ends == 1, "finisher ends the combo exactly once")
	_check(not session.combo_active and session.combo_hits == 3, "combo ends at three hits after the finisher")
	# 收尾结束路线但不主动清除木桩倒地处理：收尾当帧木桩仍处于地面受击，之后自然受身。
	_check(dummy_state_at_finisher == CombatSession.DummyState.GROUND_HITSTUN and hitstun_at_finisher > 0, "finisher keeps the dummy in its knockdown hitstun handling")
	_check(_count_events(events, CombatEvent.Type.DUMMY_RECOVERED) == 1, "dummy recovers naturally after the finisher")
	_check(session.dummy_state == CombatSession.DummyState.NEUTRAL, "dummy is neutral again after natural recovery")
	_check(session.combo_hits == 3, "combo hit count is preserved after the combo ended")


func _test_cancel_window_last_frame() -> void:
	# 取消窗口覆盖命中后第 0–8 帧（含两端）：B 在第 8 帧输入仍可取消。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	for frame in range(1, 15):
		session.step(FrameInput.make(0, false, _script_key({1: "A", 14: "B"}, frame)))
	_check(session.combo_hits == 1, "5A hits on frame 6")
	_check(session.player_move_id == "5B", "input on the last cancel-window frame (age 8) still cancels")
	for frame in range(15, 20):
		session.step(FrameInput.new())
	_check(session.combo_hits == 2, "late-canceled 5B still lands")


func _test_cancel_window_close_ends_combo() -> void:
	# 窗口关闭后（命中后第 9 帧）输入不能取消，连段结束但木桩受击处理不受影响。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var end_frames: Array[int] = []
	var move_at_close := ""
	var dummy_still_stunned_at_close := false
	for frame in range(1, 30):
		var events := session.step(FrameInput.make(0, false, _script_key({1: "A", 15: "B"}, frame)))
		if _combo_end_events(events, CombatEvent.ComboEndReason.CANCEL_WINDOW_CLOSED) > 0:
			end_frames.append(frame)
			move_at_close = session.player_move_id
			dummy_still_stunned_at_close = session.dummy_state == CombatSession.DummyState.GROUND_HITSTUN and session.dummy_hitstun_left > 0
	_check(end_frames == [15], "combo ends exactly when the cancel window closes (frame 15 = hit 6 + 9)")
	_check(move_at_close == "5A", "input after the window cannot cancel the move")
	_check(session.combo_hits == 1 and not session.combo_active, "combo stops at one hit")
	_check(dummy_still_stunned_at_close, "window closing does not clear the dummy hitstun")


func _test_independent_move_cannot_hit_stunned_dummy() -> void:
	# 没有合法取消资格的独立招式不能绕过取消条件追击仍在受击中的木桩；
	# 木桩自然恢复后才能以新一段连段重新命中。
	var session := CombatSession.new(_fast_single_move_table())
	session.dummy_position = session.player_position + Vector2(70, 0)
	var events: Array[CombatEvent] = []
	for frame in range(1, 13):
		events.append_array(session.step(FrameInput.make(0, false, _script_key({1: "A", 8: "A"}, frame))))
	_check(_count_events(events, CombatEvent.Type.HIT) == 1, "second independent swing cannot hit the stunned dummy")
	_check(session.dummy_hp == GameParams.DUMMY_MAX_HP - 10.0, "hp only drops once before recovery")
	_check(session.combo_hits == 1 and not session.combo_active, "combo ends without extending through an independent move")
	for frame in range(13, 40):
		events.append_array(session.step(FrameInput.make(0, false, _script_key({35: "A"}, frame))))
	_check(_count_events(events, CombatEvent.Type.HIT) == 2, "a fresh swing hits after the dummy naturally recovers")
	_check(session.combo_hits == 1 and _approx(session.combo_total_damage, 10.0), "new combo restarts counting at one hit and full scale")


func _test_damage_floor_and_no_hit_cap() -> void:
	# 双招互相取消的自定义表：第 10 击起倍率触底 10%，且没有人为命中数上限。
	var session := CombatSession.new(_loop_table())
	session.dummy_position = session.player_position + Vector2(70, 0)
	var events: Array[CombatEvent] = []
	for frame in range(1, 42):
		var key := ""
		if frame % 2 == 1:
			key = "A" if ((frame + 1) / 2) % 2 == 1 else "B"
		events.append_array(session.step(FrameInput.make(0, false, key)))
	for i in range(3):
		events.append_array(session.step(FrameInput.new()))
	var hits := _events_of(events, CombatEvent.Type.HIT)
	_check(hits.size() == 21, "looped cancels land a hit on every other frame with no hit cap")
	_check(session.combo_hits == 21, "session counts every combo hit")
	if hits.size() == 21:
		_check(_approx(hits[8].damage, 2.0) and _approx(hits[9].damage, 1.0), "damage decays 10% per hit")
		_check(_approx(hits[19].damage, 1.0) and _approx(hits[20].damage, 1.0), "damage stays at the 10% floor past ten hits")
	_check(_approx(session.combo_total_damage, 66.0), "combo total matches per-hit decay plus floor")
	_check(session.combo_active, "combo keeps going while the dummy never recovers")


# --- 辅助 ---

## 从出招到回中立完整走一遍（第 1 帧按下动作键 A）。
func _swing(session: CombatSession) -> Array[CombatEvent]:
	_swing_start(session)
	var events: Array[CombatEvent] = []
	var guard := 0
	while session.player_phase != CombatSession.PlayerPhase.NEUTRAL and guard < 100:
		events.append_array(session.step(FrameInput.new()))
		guard += 1
	return events


## 按下攻击但不推进到结束，供测试从出招帧开始精确数帧。
func _swing_start(session: CombatSession) -> void:
	session.step(FrameInput.make(0, false, "A"))


## 帧脚本：返回该帧的动作键，未指定的帧为空。
func _script_key(script: Dictionary, frame: int) -> String:
	return script.get(frame, "")


## 慢速地面表：5A 前摇 8 帧（F1 出招、F9 命中），用于缓存年龄边界。
func _slow_ground_table() -> Dictionary:
	var starter := MoveData.new()
	starter.move_name = "5A"
	starter.startup_frames = 8
	starter.active_frames = 2
	starter.recovery_frames = 12
	starter.base_damage = 10
	starter.hitstun_frames = 20
	starter.knockback = 0.0
	starter.knockback_up = 0.0
	starter.cancel_targets = ["5B"]
	var linker := MoveData.new()
	linker.move_name = "5B"
	linker.startup_frames = 4
	linker.active_frames = 2
	linker.recovery_frames = 10
	linker.base_damage = 12
	linker.hitstun_frames = 20
	linker.knockback = 0.0
	linker.knockback_up = 0.0
	return {"5A": starter, "5B": linker}


## 快速单招表：短窗口长硬直，用于独立招式绕过取消的验证。
func _fast_single_move_table() -> Dictionary:
	var move := MoveData.new()
	move.move_name = "5A"
	move.startup_frames = 2
	move.active_frames = 2
	move.recovery_frames = 3
	move.base_damage = 10
	move.hitstun_frames = 30
	move.knockback = 0.0
	move.knockback_up = 0.0
	return {"5A": move}


## 互相取消的双招表：5A ↔ 5B，用于伤害递减下限与无命中数上限。
func _loop_table() -> Dictionary:
	var move_a := MoveData.new()
	move_a.move_name = "5A"
	move_a.startup_frames = 2
	move_a.active_frames = 2
	move_a.recovery_frames = 8
	move_a.base_damage = 10
	move_a.hitstun_frames = 60
	move_a.knockback = 0.0
	move_a.knockback_up = 0.0
	move_a.cancel_targets = ["5B"]
	var move_b := MoveData.new()
	move_b.move_name = "5B"
	move_b.startup_frames = 2
	move_b.active_frames = 2
	move_b.recovery_frames = 8
	move_b.base_damage = 10
	move_b.hitstun_frames = 60
	move_b.knockback = 0.0
	move_b.knockback_up = 0.0
	move_b.cancel_targets = ["5A"]
	return {"5A": move_a, "5B": move_b}


func _count_events(events: Array[CombatEvent], type: CombatEvent.Type) -> int:
	var count := 0
	for event in events:
		if event.type == type:
			count += 1
	return count


func _events_of(events: Array[CombatEvent], type: CombatEvent.Type) -> Array[CombatEvent]:
	var matched: Array[CombatEvent] = []
	for event in events:
		if event.type == type:
			matched.append(event)
	return matched


func _combo_end_events(events: Array[CombatEvent], reason: CombatEvent.ComboEndReason) -> int:
	var count := 0
	for event in events:
		if event.type == CombatEvent.Type.COMBO_ENDED and event.combo_end_reason == reason:
			count += 1
	return count


func _approx(value: float, expected: float, tolerance := 0.05) -> bool:
	return absf(value - expected) < tolerance


func _phase_range(phases: Array[int], from: int, to: int, expected: CombatSession.PlayerPhase) -> bool:
	for i in range(from, to + 1):
		if phases[i] != expected:
			return false
	return true


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  " + label)
	else:
		_failures += 1
		print("FAIL  " + label)
