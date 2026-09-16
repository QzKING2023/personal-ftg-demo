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
	_test_ground_facing_tracks_dummy()
	_test_direction_folding_uses_frame_start_facing()
	_test_turn_keeps_direction_history()
	_test_qcf_qcb_work_in_both_facings()
	_test_qcf_after_walkback_both_facings()
	_test_air_direction_derivation_resolves_by_locked_facing()
	_test_phase_locked_facing_and_crossing()
	_test_movement_and_wall_clamp()
	_test_body_overlap_blocks_player()
	_test_jump_arc()
	_test_jump_ignored_during_attack()
	_test_air_input_keeps_takeoff_velocity_and_facing()
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
	_test_direction_window_age_boundary()
	_test_direction_sequence_consumed_after_lock()
	_test_directions_never_start_moves_or_use_buffer()
	_test_slow_direction_beats_action_buffer_window()
	_test_lenient_623_accepts_extra_segments()
	_test_strict_commands_reject_inserted_directions()
	_test_lenient_locks_first_endpoint()
	_test_same_move_prefers_latest_candidate()
	_test_same_endpoint_prefers_nearest_start()
	_test_super_variant_windows()
	_test_command_tier_priority_ordering()
	_test_consumption_covers_extra_segments_keeps_tail()
	_test_consumed_hold_and_neutral_resegmentation()
	_test_launcher_puts_dummy_in_float_hitstun()
	_test_air_tech_ends_combo_before_landing()
	_test_float_landing_keeps_remaining_hitstun()
	_test_independent_move_cannot_hit_floating_dummy()
	_test_5A_cancels_into_236C_relaunch()
	_test_5B_cancels_into_214D_finisher()
	_test_jump_cancel_requires_hit_config_and_window()
	_test_jump_cancel_236C_into_jA_pursuit()
	_test_jump_cancel_5C_into_jA_pursuit()
	_test_space_does_not_touch_action_buffer()
	_test_no_double_jump_after_jump_cancel()
	_test_jump_airtime_matches_param()
	_test_jump_cancel_landing_without_pursuit_ends_combo()
	_test_neutral_jump_jA_cannot_pursue()
	_test_full_air_route_5A_236C_jA_jB_jD()
	_test_same_frame_hit_landing_and_landing_followup()
	_test_landing_seam_only_opens_on_the_landing_frame()
	_test_landing_does_not_grant_normal_cancels()
	_test_air_tech_breaks_combo_before_late_pursuit()
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
	var move := _probe_move("test", "A")
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


func _test_ground_facing_tracks_dummy() -> void:
	# 面向规则（issue 12）：地面自由行动（中立/移动）时每帧面向木桩——后退不翻面；
	# 木桩换侧后地面自由行动重新面向；与木桩横向重合时保持当前面向。
	var session := CombatSession.new()
	for i in range(4):
		session.step(FrameInput.make(-1))
	_check(session.player_facing == 1, "backward walk keeps facing the dummy (no flip)")
	_check(session.player_position.x < session.dummy_position.x, "backward walk moves the player away but stays left of the dummy")
	for i in range(4):
		session.step(FrameInput.make(1))
	_check(session.player_facing == 1, "forward walk keeps facing the dummy")
	# 木桩换到玩家左侧（显式中间状态）：地面自由行动下一帧重新面向木桩。
	session.dummy_position = Vector2(session.player_position.x - 200.0, GameParams.ground_stand_y())
	session.step(FrameInput.new())
	_check(session.player_facing == -1, "ground neutral re-faces the dummy after it changes sides")
	# 横向重合（无水平差）时保持当前面向。
	session.dummy_position.x = session.player_position.x
	var facing_before := session.player_facing
	session.step(FrameInput.new())
	_check(session.player_facing == facing_before, "horizontal overlap keeps the current facing")


func _test_direction_folding_uses_frame_start_facing() -> void:
	# 方向折算契约（spec 面向 seam）：先用物理帧开始时的面向采样，再在地面自由
	# 行动的运动与位置更新后重新指向木桩；本帧产生的面向变化从下一物理帧生效，
	# 不改写已记录的历史段。左右面向镜像一致。
	# 右侧用例：玩家在木桩右侧却仍面向 +1（显式中间状态），世界右输入。
	var right := CombatSession.new()
	right.dummy_position = right.player_position - Vector2(200.0, 0.0)
	right.player_facing = 1
	right.step(FrameInput.make(1))
	_check(String(right.debug_snapshot()["direction_sequence"]) == "6", "F1 world-right records relative 6 with the frame-start facing")
	_check(right.player_facing == -1, "facing flips to the dummy after the frame's motion")
	right.step(FrameInput.make(1))
	_check(String(right.debug_snapshot()["direction_sequence"]) == "64", "F2 same physical key records 4 only from the next frame")
	# 左侧镜像：玩家在木桩左侧、帧首面向 -1，世界左输入同样得到 F1=6、F2=4。
	var left := CombatSession.new()
	left.dummy_position = left.player_position + Vector2(200.0, 0.0)
	left.player_facing = -1
	left.step(FrameInput.make(-1))
	_check(String(left.debug_snapshot()["direction_sequence"]) == "6", "mirror F1 world-left records relative 6")
	_check(left.player_facing == 1, "mirror facing flips to the dummy after the frame's motion")
	left.step(FrameInput.make(-1))
	_check(String(left.debug_snapshot()["direction_sequence"]) == "64", "mirror F2 same physical key records 4 from the next frame")


func _test_turn_keeps_direction_history() -> void:
	# 转身不清空方向历史，也不按新面向重解释旧段（spec「转身前历史」seam）：
	# 序列中途木桩换侧使面向翻转，旧段保持录入时的相对数字，新面向只用于
	# 之后的采样——跨转身仍组成同一指令。
	# 1) 地面版：面向 +1 输入 2、3 后木桩换到左侧；换侧后的首个运动帧面向翻
	#    为 -1，再下一帧世界左按新面向记 6——历史保持 236 并识别 236C。
	var turn := CombatSession.new()
	turn.dummy_position = turn.player_position + Vector2(70, 0)
	turn.step(FrameInput.make(0, false, "", true))
	turn.step(FrameInput.make(1, false, "", true))
	turn.dummy_position = Vector2(turn.player_position.x - 70.0, GameParams.ground_stand_y())
	turn.step(FrameInput.new())
	_check(turn.player_facing == -1, "facing turned toward the moved dummy before the command ends")
	turn.step(FrameInput.make(-1, false, "C"))
	_check(String(turn.debug_snapshot()["direction_sequence"]) == "", "the recognized 236C consumed the cross-turn history")
	_check(turn.player_move_id == "236C", "the command completed across the turn still recognizes 236C")
	var turn_hits := _run_neutral(turn, 30)
	_check(turn_hits == 1, "the cross-turn 236C executes and hits")
	# 2) 空跳落地版：跳跃后段按面向 +1 录得 2、3（保持方向窗口内），落地帧前
	#    木桩已在左侧——落地完成重新面向 -1，下一帧世界左记 6 并按 C：
	#    旧 2/3 不清空、不反转，跨落地转身组成 236C。
	var land := CombatSession.new()
	land.dummy_position = Vector2(900.0, GameParams.ground_stand_y())
	land.step(FrameInput.make(0, true))
	for i in range(24):
		land.step(FrameInput.new())
	land.step(FrameInput.make(0, false, "", true))
	land.step(FrameInput.make(1, false, "", true))
	land.dummy_position = Vector2(50.0, GameParams.ground_stand_y())
	for i in range(50):
		land.step(FrameInput.new())
		if land.player_on_ground:
			break
	_check(land.player_on_ground, "the empty jump lands before the command ends")
	_check(land.player_facing == -1, "landing re-faces the dummy now on the left")
	_check(String(land.debug_snapshot()["direction_sequence"]) == "23", "the air-recorded 2 and 3 survive the landing turn")
	land.step(FrameInput.make(-1, false, "C"))
	_check(land.player_move_id == "236C", "the post-landing 6 completes 236C from the kept history")


func _test_qcf_qcb_work_in_both_facings() -> void:
	# 左右面向使用同一套相对方向输入（issue 12）：236C 与 214D 在两侧面向的
	# 地面中立均能识别并执行；后退后的方向历史不再因移动翻转而失败。
	# 右面向 214D：木桩在右，S → S+A → A+J（世界左 = 后）。
	var right_qcb := CombatSession.new()
	right_qcb.dummy_position = right_qcb.player_position + Vector2(70, 0)
	var right_qcb_hits := _play_script(right_qcb, [
		[0, true, ""], [-1, true, ""], [-1, false, "D"],
	])
	_check(right_qcb.player_move_id == "214D", "ground-neutral 214 starts 214D while facing right")
	right_qcb_hits += _run_neutral(right_qcb, 30)
	_check(right_qcb_hits == 1, "the backward quarter circle connects as a single hit while facing right")
	# 左面向 236C：木桩在左，先走向木桩使面向 -1，S → S+A → A+K（世界左 = 前）。
	var left_qcf := CombatSession.new()
	left_qcf.dummy_position = left_qcf.player_position - Vector2(70, 0)
	var left_qcf_hits := _play_script(left_qcf, [
		[-1, false, ""], [-1, false, ""],
		[0, true, ""], [-1, true, ""], [-1, false, "C"],
	])
	_check(left_qcf.player_move_id == "236C", "mirror 236 starts 236C while facing left")
	left_qcf_hits += _run_neutral(left_qcf, 30)
	_check(left_qcf_hits == 1, "the mirror quarter circle connects as a single hit while facing left")
	# 左面向 214D：木桩在左，S → S+D → D+J（世界右 = 后）。
	var left_qcb := CombatSession.new()
	left_qcb.dummy_position = left_qcb.player_position - Vector2(70, 0)
	var left_qcb_hits := _play_script(left_qcb, [
		[-1, false, ""], [-1, false, ""],
		[0, true, ""], [1, true, ""], [1, false, "D"],
	])
	_check(left_qcb.player_move_id == "214D", "mirror 214 starts 214D while facing left")
	left_qcb_hits += _run_neutral(left_qcb, 35)
	_check(left_qcb_hits == 1, "the mirror backward quarter circle connects while facing left")


func _test_qcf_after_walkback_both_facings() -> void:
	# 后退后的方向历史（阶段 1 遗留症状的永久回归）：后退不翻面，随后朝木桩
	# 搓 236 应被识别——序列内同一物理键不再被两种面向解释。
	# 右面向：按 A 后退（世界左、远离木桩），再 S → S+D → D+K。
	var right := CombatSession.new()
	right.dummy_position = right.player_position + Vector2(70, 0)
	var right_hits := _play_script(right, [
		[-1, false, ""], [-1, false, ""], [-1, false, ""], [-1, false, ""],
		[0, false, ""],
		[0, true, ""], [1, true, ""], [1, false, ""], [1, false, "C"],
	])
	_check(right.player_move_id == "236C", "236 toward the dummy works right after walking back")
	right_hits += _run_neutral(right, 30)
	_check(right_hits == 1, "the after-walkback 236C connects")
	# 左面向镜像：按 D 后退（世界右、远离木桩），再 S → S+A → A+K。
	var left := CombatSession.new()
	left.dummy_position = left.player_position - Vector2(70, 0)
	var left_hits := _play_script(left, [
		[1, false, ""], [1, false, ""], [1, false, ""], [1, false, ""],
		[0, false, ""],
		[0, true, ""], [-1, true, ""], [-1, false, ""], [-1, false, "C"],
	])
	_check(left.player_move_id == "236C", "mirror 236 toward the dummy works right after walking back")
	left_hits += _run_neutral(left, 30)
	_check(left_hits == 1, "the mirror after-walkback 236C connects")


func _test_air_direction_derivation_resolves_by_locked_facing() -> void:
	# 空中方向派生（issue 12）：空中方向历史按锁定面向折算，配置的空中派生
	# （注入表的 j214D）能被识别并执行；镜像一致；未识别回落为无派生空中招式，
	# 识别但不可接续、成功出招但未命中三种结果可区分。
	# 1) 成功出招但未命中：右面向前跳（木桩在远处），空中 S → S+A → A → D。
	var whiff := CombatSession.new(_air_derivation_table())
	whiff.dummy_position = Vector2(900.0, GameParams.ground_stand_y())
	whiff.step(FrameInput.make(1, true))
	_play_script(whiff, [
		[0, true, ""], [-1, true, ""], [-1, false, "D"],
	])
	_check(whiff.player_move_id == "j214D", "air 214 folded by the locked facing starts the configured j214D")
	_check(not whiff.player_on_ground, "j214D starts while still airborne")
	var whiff_hits := _run_neutral(whiff, 50)
	_check(whiff_hits == 0 and whiff.dummy_hp == GameParams.DUMMY_MAX_HP, "started-but-whiffed is observable: no hit, no damage")
	# 2) 左面向镜像：木桩在左，面向 -1 前跳，S → S+D → D → D（世界右 = 后）。
	var mirror := CombatSession.new(_air_derivation_table())
	mirror.dummy_position = Vector2(50.0, GameParams.ground_stand_y())
	_play_script(mirror, [[-1, false, ""]])
	mirror.step(FrameInput.make(-1, true))
	_play_script(mirror, [
		[0, true, ""], [1, true, ""], [1, false, "D"],
	])
	_check(mirror.player_move_id == "j214D", "mirror air 214 with the locked facing starts j214D")
	# 3) 未识别（方向序列不匹配）：空中 2→3→6 + D 回落为无派生 jD。
	var mismatch := CombatSession.new(_air_derivation_table())
	mismatch.dummy_position = Vector2(900.0, GameParams.ground_stand_y())
	mismatch.step(FrameInput.make(1, true))
	_play_script(mismatch, [
		[0, true, ""], [1, true, ""], [1, false, ""], [1, false, "D"],
	])
	_check(mismatch.player_move_id == "jD", "air 236 falls back to the plain air move for the key (derivation not matched)")
	# 4) 识别但不可接续：jA 执行中搓 214 + D——派生被识别并缓存，但当前招式
	#    不能取消、落地后空中姿态不再匹配，缓存过期作废，全程不起手 j214D。
	var stuck := CombatSession.new(_air_derivation_table())
	stuck.dummy_position = Vector2(900.0, GameParams.ground_stand_y())
	stuck.step(FrameInput.make(1, true))
	_play_script(stuck, [
		[0, false, "A"], [0, true, ""], [-1, true, ""], [-1, false, "D"],
	])
	_check(stuck.player_move_id == "jA", "jA is in progress when the air 214 finishes")
	_check(String(stuck.debug_snapshot()["buffered_move_id"]) == "j214D", "the air derivation is recognized and buffered (observable via diagnostics)")
	var saw_stuck_start := false
	for i in range(60):
		_run_neutral(stuck, 1)
		saw_stuck_start = saw_stuck_start or stuck.player_move_id == "j214D"
	_check(not saw_stuck_start and stuck.player_on_ground, "recognized-but-uncontinuable never starts the buffered j214D")
	_check(stuck.dummy_hp == GameParams.DUMMY_MAX_HP, "the uncontinuable buffer produces no hit")
	# 5) 空中派生不在地面解析（姿态分离）：地面 214 + D 无地面 D 招式，不起手。
	var ground := CombatSession.new(_air_derivation_table())
	ground.dummy_position = Vector2(900.0, GameParams.ground_stand_y())
	_play_script(ground, [
		[0, true, ""], [-1, true, ""], [-1, false, "D"],
	])
	_check(ground.player_move_id == "" and ground.player_phase == CombatSession.PlayerPhase.NEUTRAL, "air derivations do not resolve from the ground stance")


func _test_phase_locked_facing_and_crossing() -> void:
	# 阶段面向锁定（issue 12）：出招与空中阶段保持进入阶段时的面向；空中越过
	# 木桩不自动转身；落地完成后（回到地面自由行动）重新面向木桩。
	# 1) 地面出招期间木桩换到另一侧：整招面向不变，收招回到自由行动后翻转。
	var ground_move := CombatSession.new()
	ground_move.dummy_position = Vector2(900.0, GameParams.ground_stand_y())
	ground_move.step(FrameInput.make(0, false, "A"))
	ground_move.dummy_position = Vector2(50.0, GameParams.ground_stand_y())
	var move_facing_locked := true
	for i in range(24):
		ground_move.step(FrameInput.new())
		move_facing_locked = move_facing_locked and ground_move.player_facing == 1
	_check(move_facing_locked, "facing stays locked for the whole ground move while the dummy changes sides")
	ground_move.step(FrameInput.new())
	_check(ground_move.player_facing == -1, "free action re-faces the dummy after the move recovers")
	# 2) 空中越过木桩（显式中间状态：升空中、向前水平速度、面向 +1、木桩在
	#    前下方；高度取在身体垂直重叠带之上，越过木桩横向位置后面向不变，
	#    落地完成后重新面向木桩。
	var crossing := CombatSession.new()
	crossing.dummy_position = crossing.player_position + Vector2(100.0, 0.0)
	crossing.player_on_ground = false
	crossing.player_velocity = Vector2(1000.0, 0.0)
	crossing.player_position.y -= 100.0
	var crossed := false
	var air_facing_locked := true
	var landed_facing := 0
	for i in range(60):
		crossing.step(FrameInput.new())
		if not crossing.player_on_ground:
			air_facing_locked = air_facing_locked and crossing.player_facing == 1
			crossed = crossed or crossing.player_position.x > crossing.dummy_position.x
		else:
			landed_facing = crossing.player_facing
			break
	_check(crossed, "the player sails past the dummy's horizontal position mid-air")
	_check(air_facing_locked, "crossing the dummy mid-air never flips the takeoff facing")
	_check(landed_facing == -1, "after landing the player re-faces the dummy left behind")


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


func _test_air_input_keeps_takeoff_velocity_and_facing() -> void:
	# 已明确规则（执行路径）：普通空中运动保留起跳横向速度，玩家方向输入
	# 不能主动改变空中横向速度或面向。木桩放在左侧（起跳面向 -1，向右行走
	# 是后退）；前跳后按住反方向 / 松开水平键都不得改变速度向量或面向，直到落地。
	var session := CombatSession.new()
	session.dummy_position = Vector2(100.0, GameParams.ground_stand_y())
	for i in range(20):
		session.step(FrameInput.make(1))
	_check(session.player_facing == -1, "backward walk faces the dummy on the left before takeoff")
	session.step(FrameInput.make(1, true))
	var takeoff_vx := session.player_velocity.x
	_check(takeoff_vx > 300.0, "backward jump takes off at walking speed")
	for i in range(38):
		session.step(FrameInput.make(-1))
	_check(not session.player_on_ground, "player is still airborne while holding reverse")
	_check(is_equal_approx(session.player_velocity.x, takeoff_vx), "holding reverse in the air keeps the takeoff horizontal velocity")
	_check(session.player_facing == -1, "holding reverse in the air never flips the takeoff facing")
	for i in range(10):
		session.step(FrameInput.make(-1))
	_check(session.player_on_ground, "player still lands normally after holding reverse mid-air")

	var release := CombatSession.new()
	release.dummy_position = Vector2(100.0, GameParams.ground_stand_y())
	for i in range(20):
		release.step(FrameInput.make(1))
	release.step(FrameInput.make(1, true))
	var release_takeoff := release.player_velocity.x
	for i in range(38):
		release.step(FrameInput.new())
	_check(not release.player_on_ground, "player is still airborne after releasing horizontal input")
	_check(is_equal_approx(release.player_velocity.x, release_takeoff), "releasing horizontal input mid-air keeps the takeoff velocity (no air friction decay)")
	_check(release.player_facing == -1, "facing stays unchanged after releasing mid-air")


func _test_air_action_without_air_move_ignored() -> void:
	# 招式表只配置地面招式：空中按下动作键不会起手，缓存也不会被消费。
	# （默认表已配置 jA，空中 A 的起手行为由 jump cancel 测试覆盖。）
	var session := CombatSession.new(_fast_single_move_table())
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


func _test_direction_window_age_boundary() -> void:
	# 窗口按实际 variant 步数计（issue 13）：214 为三步 × 10 = 30 帧，含首段帧。
	# F1–F3 输入 214，F30 按 D（首段年龄 29）仍识别；F31（年龄 30）过期回落 5D。
	# 左右面向成功/失败帧一致（左面向用下、下右、右的物理镜像）。
	var session := CombatSession.new()
	for frame in range(1, 31):
		session.step(_qcb_input(frame, 30, "D"))
	_check(session.player_move_id == "214D", "three-step command at age 29 (F30) is the last valid boundary")
	var late_session := CombatSession.new()
	for frame in range(1, 32):
		late_session.step(_qcb_input(frame, 31, "D"))
	_check(late_session.player_move_id == "5D", "age 30 (F31) expires before the key press and falls back to the plain move")
	var mirror := CombatSession.new()
	mirror.dummy_position = mirror.player_position + Vector2(-200, 0)
	mirror.step(FrameInput.new())
	for digit in [2, 1, 4]:
		mirror.step(_relative_input(mirror, digit))
	for i in range(26):
		mirror.step(FrameInput.new())
	mirror.step(_relative_input(mirror, 5, "D"))
	_check(mirror.player_move_id == "214D", "left-facing mirror keeps the same success frame (F31, age 29)")
	var mirror_late := CombatSession.new()
	mirror_late.dummy_position = mirror_late.player_position + Vector2(-200, 0)
	mirror_late.step(FrameInput.new())
	for digit in [2, 1, 4]:
		mirror_late.step(_relative_input(mirror_late, digit))
	for i in range(27):
		mirror_late.step(FrameInput.new())
	mirror_late.step(_relative_input(mirror_late, 5, "D"))
	_check(mirror_late.player_move_id == "5D", "left-facing mirror keeps the same failure frame (F32, age 30)")


func _test_direction_sequence_consumed_after_lock() -> void:
	# 识别 236C 的当帧消费整段方向历史并锁定招式：没有新方向前，再按 C 只得到普通 5C。
	var session := CombatSession.new()
	for frame in range(1, 5):
		session.step(_qcf_input(frame, 4, "C"))
	_check(session.player_move_id == "236C", "236 followed by C locks the derivative on the key-press frame")
	for frame in range(5, 34):
		session.step(FrameInput.new())
	_check(session.player_phase == CombatSession.PlayerPhase.NEUTRAL, "derivative move finishes its full recovery")
	session.step(FrameInput.make(0, false, "C"))
	_check(session.player_move_id == "5C", "second C without fresh directions resolves the plain move, not another derivative")


func _test_directions_never_start_moves_or_use_buffer() -> void:
	# 方向输入不占用动作键缓存：只输方向时不会起手任何招式，随后的动作键照常起手。
	var session := CombatSession.new()
	for frame in range(1, 11):
		session.step(_qcf_input(frame, -1, ""))
	_check(session.player_phase == CombatSession.PlayerPhase.NEUTRAL and session.player_move_id == "", "direction input alone never starts a move")
	session.step(FrameInput.make(0, false, "A"))
	_check(session.player_move_id == "5A", "action buffer stays untouched by direction input and still starts 5A")


func _test_slow_direction_beats_action_buffer_window() -> void:
	# 方向识别只受独立 24 帧窗口限制：236 跨 19 帧输入（远超 6 帧动作缓存）仍能触发派生。
	var session := CombatSession.new()
	for frame in range(1, 21):
		var down := frame == 1 or frame == 10
		var axis := 1 if frame >= 10 else 0
		session.step(FrameInput.make(axis, false, "C" if frame == 20 else "", down))
	_check(session.player_move_id == "236C", "direction spread over 19 frames still triggers the derivative")


func _test_lenient_623_accepts_extra_segments() -> void:
	# 宽松谓词 {前={3,6,9}}→{下={1,2,3}}→{前={3,6,9}}：323、313、63236 与标准 623
	# 都成立（段间允许额外方向段，每段最多推进一个谓词步骤）；长按 3 只有一个
	# 方向段，不能满足三个谓词（一个方向段不复用）。左右镜像识别结果一致。
	var table := _command_rule_table()
	for pair in [["323", [3, 2, 3]], ["313", [3, 1, 3]], ["63236", [6, 3, 2, 3, 6]], ["623", [6, 2, 3]]]:
		var session := CombatSession.new(table)
		for digit in pair[1]:
			session.step(_relative_input(session, digit))
		session.step(_relative_input(session, 5, "A"))
		_check(session.player_move_id == "623A", "lenient 623A accepts input %s (extra direction segments allowed)" % pair[0])
	var hold := CombatSession.new(table)
	for i in range(3):
		hold.step(_relative_input(hold, 3))
	hold.step(_relative_input(hold, 3, "A"))
	_check(hold.player_move_id == "5A", "holding 3 keeps a single segment and cannot satisfy three predicates")
	var mirror := CombatSession.new(table)
	mirror.dummy_position = mirror.player_position + Vector2(-200, 0)
	mirror.step(FrameInput.new())
	for digit in [3, 2, 3]:
		mirror.step(_relative_input(mirror, digit))
	mirror.step(_relative_input(mirror, 5, "A"))
	_check(mirror.player_move_id == "623A", "left-facing mirror 323 recognizes the same lenient command")


func _test_strict_commands_reject_inserted_directions() -> void:
	# 236/214 严格匹配：段间插入其他非中立方向、终点后插入非中立方向都会失败；
	# 超必杀长串不由普通指令自动推导；终点前的旧方向段（后退后搓招）不阻塞严格匹配。
	var inserted := CombatSession.new()
	_run_relative(inserted, [[2], [3], [4], [6, "C"]])
	_check(inserted.player_move_id == "5C", "inserting 4 between 236 breaks the strict match")
	var post := CombatSession.new()
	_run_relative(post, [[2], [3], [6], [4, "C"]])
	_check(post.player_move_id == "5C", "post-endpoint 4 breaks the strict 236C candidate")
	var no_super := CombatSession.new()
	_run_relative(no_super, [[2], [3], [6], [2], [6, "C"]])
	_check(no_super.player_move_id == "5C", "23626 is not auto-derived from plain 236C")
	var lead := CombatSession.new()
	_run_relative(lead, [[4], [4], [2], [3], [6, "C"]])
	_check(lead.player_move_id == "236C", "leading back segments do not break the strict tail match")


func _test_lenient_locks_first_endpoint() -> void:
	# 宽松指令在完成前置谓词后于第一个满足终点谓词的段锁定：F3 的 3 锁定终点，
	# F4 的 6 不改写；锁定本身不消费、不起手，动作键帧才识别并消费终点及之前的
	# 全部历史，终点后的 6 保留。
	var session := CombatSession.new(_command_rule_table())
	_run_relative(session, [[3], [2], [3]])
	var lock := _lock_for(session, "623A")
	_check(not lock.is_empty() and int(lock["endpoint"]) == 3 and int(lock["start"]) == 1,
		"the lenient candidate locks its first legal endpoint at F3 (visible in diagnostics)")
	_check(session.player_move_id == "" and String(session.debug_snapshot()["direction_sequence"]) == "323",
		"the lock alone consumes nothing and starts no move")
	_run_relative(session, [[6]])
	lock = _lock_for(session, "623A")
	_check(not lock.is_empty() and int(lock["endpoint"]) == 3, "the extra 6 at F4 does not rewrite the locked endpoint")
	session.step(_relative_input(session, 5, "A"))
	_check(session.player_move_id == "623A", "the action key at F5 recognizes the locked lenient match")
	_check(String(session.debug_snapshot()["direction_sequence"]) == "6",
		"consumption covers the endpoint and everything before it; the post-endpoint 6 survives")


func _test_same_move_prefers_latest_candidate() -> void:
	# 同招多候选：623、长中立、再 623 后按 A——选最近完成的候选（第二次的终点），
	# 消费含第一次在内的全部历史（旧串不可留待再按 A 复用）；首串过期也不阻塞
	# 同次动作事件识别较新的有效串。
	var table := _command_rule_table()
	var session := CombatSession.new(table)
	for digit in [6, 2, 3]:
		session.step(_relative_input(session, digit))
	for i in range(21):
		session.step(FrameInput.new())
	for digit in [6, 2, 3]:
		session.step(_relative_input(session, digit))
	session.step(_relative_input(session, 5, "A"))
	_check(session.player_move_id == "623A", "A@F28 selects the most recently completed candidate")
	_run_neutral(session, 40)
	session.step(_relative_input(session, 5, "A"))
	_check(session.player_move_id == "5A", "the consumed old string cannot serve a second A press")
	var expired_old := CombatSession.new(table)
	for digit in [6, 2, 3]:
		expired_old.step(_relative_input(expired_old, digit))
	for i in range(21):
		expired_old.step(FrameInput.new())
	for digit in [6, 2, 3]:
		expired_old.step(_relative_input(expired_old, digit))
	for i in range(3):
		expired_old.step(FrameInput.new())
	expired_old.step(_relative_input(expired_old, 5, "A"))
	_check(expired_old.player_move_id == "623A",
		"the expired first candidate (age 30 at F31) does not block the newer valid one in the same action event")


func _test_same_endpoint_prefers_nearest_start() -> void:
	# 终点同帧的两个候选选起点更近者：6,3,2,3 中 F2 的 3 既完成起点 F1 候选的
	# 下谓词、又自起一个前谓词候选，两个候选终点同为 F4。A@F31 时 F1 候选年龄 30
	# 已过期、F2 候选年龄 29 仍有效——按更近起点识别；A@F32 两个起点都过期，
	# 回落普通招式。
	var table := _command_rule_table()
	var session := CombatSession.new(table)
	for digit in [6, 3, 2, 3]:
		session.step(_relative_input(session, digit))
	for i in range(26):
		session.step(FrameInput.new())
	session.step(_relative_input(session, 5, "A"))
	_check(session.player_move_id == "623A", "endpoint tie picks the nearer start whose window is still valid at F31")
	var late := CombatSession.new(table)
	for digit in [6, 3, 2, 3]:
		late.step(_relative_input(late, digit))
	for i in range(27):
		late.step(FrameInput.new())
	late.step(_relative_input(late, 5, "A"))
	_check(late.player_move_id == "5A", "both starts are expired at F32 and the plain move resolves")


func _test_super_variant_windows() -> void:
	# 窗口按实际命中的 variant 步数计，不按指令"原始长度"计：五步替代串 5×10=50f
	# （F50 识别、F51 过期），六步基础串 6×10=60f（F60 识别、F61 过期）。
	# 长按不生成新方向段，保持 6 不延长也不缩短窗口。
	var table := _tier_table()
	var s50 := CombatSession.new(table)
	for digit in [2, 3, 6, 2, 6]:
		s50.step(_relative_input(s50, digit))
	for i in range(44):
		s50.step(_relative_input(s50, 6))
	s50.step(_relative_input(s50, 6, "D"))
	_check(s50.player_move_id == "SD", "five-step alternative still valid at F50 (window 50f incl. the first segment)")
	var s51 := CombatSession.new(table)
	for digit in [2, 3, 6, 2, 6]:
		s51.step(_relative_input(s51, digit))
	for i in range(45):
		s51.step(_relative_input(s51, 6))
	s51.step(_relative_input(s51, 6, "D"))
	_check(s51.player_move_id == "5D", "five-step alternative expires at F51")
	var s60 := CombatSession.new(table)
	for digit in [2, 3, 6, 2, 3, 6]:
		s60.step(_relative_input(s60, digit))
	for i in range(53):
		s60.step(_relative_input(s60, 6))
	s60.step(_relative_input(s60, 6, "D"))
	_check(s60.player_move_id == "SD", "six-step variant still valid at F60 (window 60f)")
	var s61 := CombatSession.new(table)
	for digit in [2, 3, 6, 2, 3, 6]:
		s61.step(_relative_input(s61, digit))
	for i in range(54):
		s61.step(_relative_input(s61, 6))
	s61.step(_relative_input(s61, 6, "D"))
	_check(s61.player_move_id == "5D", "six-step variant expires at F61")
	# 26236 同为五步替代串，使用同一 50f 边界。
	var s50b := CombatSession.new(table)
	for digit in [2, 6, 2, 3, 6]:
		s50b.step(_relative_input(s50b, digit))
	for i in range(44):
		s50b.step(_relative_input(s50b, 6))
	s50b.step(_relative_input(s50b, 6, "D"))
	_check(s50b.player_move_id == "SD", "the 26236 five-step alternative shares the same F50 boundary")
	var s51b := CombatSession.new(table)
	for digit in [2, 6, 2, 3, 6]:
		s51b.step(_relative_input(s51b, digit))
	for i in range(45):
		s51b.step(_relative_input(s51b, 6))
	s51b.step(_relative_input(s51b, 6, "D"))
	_check(s51b.player_move_id == "5D", "the 26236 five-step alternative expires at F51 like 23626")


func _test_command_tier_priority_ordering() -> void:
	# 超必杀 > 普通必杀 > 普通拳脚，同层按配置 priority：即使超必杀 priority 最低，
	# 23626 输入同时命中超必杀五步串与宽松 623D 时仍选超必杀；同层 priority 高者胜。
	var table := _tier_table()
	var super_case := CombatSession.new(table)
	for digit in [2, 3, 6, 2, 6]:
		super_case.step(_relative_input(super_case, digit))
	super_case.step(_relative_input(super_case, 6, "D"))
	_check(super_case.player_move_id == "SD", "the super tier outranks specials regardless of configured priority")
	var special_case := CombatSession.new(table)
	for digit in [6, 2, 3]:
		special_case.step(_relative_input(special_case, digit))
	special_case.step(_relative_input(special_case, 5, "D"))
	_check(special_case.player_move_id == "623D", "the matched special outranks the plain normal on the same key")
	var plain_case := CombatSession.new(table)
	plain_case.step(_relative_input(plain_case, 5, "D"))
	_check(plain_case.player_move_id == "5D", "without direction matches the plain normal resolves")
	var same_layer := CombatSession.new(table)
	for digit in [6, 3, 6]:
		same_layer.step(_relative_input(same_layer, digit))
	same_layer.step(_relative_input(same_layer, 5, "D"))
	_check(same_layer.player_move_id == "623D", "within one tier the higher declared priority wins (623D p9 over 63D p5)")
	var flipped := CombatSession.new(_tier_table(5, 9))
	for digit in [6, 3, 6]:
		flipped.step(_relative_input(flipped, digit))
	flipped.step(_relative_input(flipped, 5, "D"))
	_check(flipped.player_move_id == "63D", "swapping priorities flips the same-layer winner")


func _test_consumption_covers_extra_segments_keeps_tail() -> void:
	# 成功识别消费所选终点及之前的全部历史（含宽松匹配跳过的额外段）；
	# 终点后的历史保留，残留段不能拼出新指令。
	var table := _command_rule_table()
	var session := CombatSession.new(table)
	for digit in [6, 2, 1, 2, 6]:
		session.step(_relative_input(session, digit))
	session.step(_relative_input(session, 5, "A"))
	_check(session.player_move_id == "623A", "lenient match across extra segments recognizes at the action key")
	_check(String(session.debug_snapshot()["direction_sequence"]) == "",
		"consumption removes the endpoint and every earlier segment (skipped extras included)")
	session.step(_relative_input(session, 1))
	session.step(_relative_input(session, 4, "D"))
	_check(String(session.debug_snapshot()["buffered_move_id"]) == "5D",
		"the leftover tail cannot reassemble 214D from consumed history (plain fallback buffered)")


func _test_consumed_hold_and_neutral_resegmentation() -> void:
	# 消费不会把持续按住的同一逻辑方向变成新方向段；中立打断连续按住后，
	# 重新进入才形成新的独立段——三个独立 3 段各推进一个谓词，可再次识别。
	var table := _command_rule_table()
	var session := CombatSession.new(table)
	for digit in [3, 2, 3]:
		session.step(_relative_input(session, digit))
	session.step(_relative_input(session, 3, "A"))
	_check(session.player_move_id == "623A", "recognition at F4 while still holding 3")
	session.step(_relative_input(session, 3))
	_check(String(session.debug_snapshot()["direction_sequence"]) == "",
		"holding 3 after consumption does not open a new segment")
	session.step(_relative_input(session, 2))
	session.step(_relative_input(session, 3, "A"))
	_check(String(session.debug_snapshot()["buffered_move_id"]) == "5A",
		"only the fresh 2/3 segments remain and cannot re-recognize 623A (plain fallback buffered)")
	var neutral_broken := CombatSession.new(table)
	for digit in [3, 5, 3, 5]:
		neutral_broken.step(_relative_input(neutral_broken, digit))
	neutral_broken.step(_relative_input(neutral_broken, 3, "A"))
	_check(neutral_broken.player_move_id == "623A",
		"neutral gaps split the hold into three independent segments satisfying three predicates")


func _test_launcher_puts_dummy_in_float_hitstun() -> void:
	# C 语义在招式数据中表达：5C 命中把木桩置入浮空受击；取消窗关闭先断连，
	# 浮空受身（硬直归零）与落地恢复中立是两个独立可观察时刻。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var events: Array[CombatEvent] = []
	var hit_frame := -1
	for frame in range(1, 8):
		var frame_events := session.step(FrameInput.make(0, false, "C" if frame == 1 else ""))
		events.append_array(frame_events)
		if _count_events(frame_events, CombatEvent.Type.HIT) > 0:
			hit_frame = frame
	_check(hit_frame == 7, "5C hits on its first active frame")
	_check(session.dummy_state == CombatSession.DummyState.AIR_HITSTUN, "launcher hit puts the dummy into float hitstun")
	_check(not session.dummy_on_ground, "dummy lifts off on the launcher hit")
	_check(session.dummy_hitstun_left == GameParams.FLOAT_HITSTUN_FRAMES, "float hitstun starts at its configured length")
	_check(_approx(session.dummy_hp, GameParams.DUMMY_MAX_HP - GameParams.MOVE_5C_DAMAGE), "5C applies its own base damage")
	var combo_end_frames: Array[int] = []
	var tech_frame := -1
	var state_left_air_recovered := true
	var land_frame := -1
	for frame in range(8, 60):
		var frame_events := session.step(FrameInput.new())
		events.append_array(frame_events)
		if _combo_end_events(frame_events, CombatEvent.ComboEndReason.CANCEL_WINDOW_CLOSED) > 0:
			combo_end_frames.append(frame)
		if session.dummy_state == CombatSession.DummyState.AIR_RECOVERED:
			if tech_frame == -1:
				tech_frame = frame
		elif tech_frame != -1 and land_frame == -1 and session.dummy_on_ground:
			land_frame = frame
			state_left_air_recovered = session.dummy_state == CombatSession.DummyState.NEUTRAL
	_check(combo_end_frames == [hit_frame + GameParams.CANCEL_WINDOW_FRAMES + 1], "combo ends when the cancel window closes while the dummy still floats")
	_check(tech_frame == hit_frame + GameParams.FLOAT_HITSTUN_FRAMES, "float hitstun runs out exactly FLOAT_HITSTUN frames after the hit while airborne (hit frame not consumed)")
	_check(land_frame == hit_frame + GameParams.DUMMY_FLOAT_AIRTIME_FRAMES, "float airtime lasts the configured frames from the hit")
	_check(state_left_air_recovered, "dummy only returns to neutral on landing after the air tech")
	_check(_count_events(events, CombatEvent.Type.DUMMY_RECOVERED) == 1, "recovery event fires exactly once at landing, not at the tech")
	_check(_count_events(events, CombatEvent.Type.COMBO_ENDED) == 1, "no second combo-end is emitted at the tech after the window already closed")


func _test_air_tech_ends_combo_before_landing() -> void:
	# 浮空受身当帧立即结束连段（长取消窗保持连段存活到受身），落地后才恢复中立；
	# 空中已受身的木桩即使被摆回命中框内也不可追击。
	var session := CombatSession.new(_float_probe_table())
	session.dummy_position = session.player_position + Vector2(70, 0)
	var tech_end_frames: Array[int] = []
	var tech_recovered_events := 0
	for frame in range(1, 16):
		var frame_events := session.step(FrameInput.make(0, false, "C" if frame == 1 else ""))
		if frame == 3:
			_check(_count_events(frame_events, CombatEvent.Type.HIT) == 1 and session.dummy_state == CombatSession.DummyState.AIR_HITSTUN, "probe launcher hits on frame 3 into float hitstun")
		if _combo_end_events(frame_events, CombatEvent.ComboEndReason.DUMMY_RECOVERED) > 0:
			tech_end_frames.append(frame)
		tech_recovered_events += _count_events(frame_events, CombatEvent.Type.DUMMY_RECOVERED)
	_check(tech_end_frames == [15], "air tech on the frame float hitstun runs out ends the combo immediately")
	_check(session.dummy_state == CombatSession.DummyState.AIR_RECOVERED, "dummy is air-recovered right after the tech")
	_check(not session.dummy_on_ground and session.dummy_state != CombatSession.DummyState.NEUTRAL, "dummy is still airborne and not neutral after the tech")
	_check(not session.combo_active and session.combo_hits == 1, "combo stops counting at the tech")
	_check(tech_recovered_events == 0, "no recovery event at the tech itself")
	# 受身后把木桩摆回玩家命中框内并挥出独立 5A：空中已受身期间不可追击。
	session.dummy_position = session.player_position + Vector2(70, -40)
	var probe_events: Array[CombatEvent] = []
	for frame in range(16, 21):
		probe_events.append_array(session.step(FrameInput.make(0, false, "A" if frame == 16 else "")))
	_check(_count_events(probe_events, CombatEvent.Type.HIT) == 0, "air-recovered dummy cannot be hit even inside the attack rect")
	_check(_approx(session.dummy_hp, GameParams.DUMMY_MAX_HP - 10.0), "hp is unchanged by the post-tech probe")
	var land_frame := -1
	var recovered_events := 0
	for frame in range(21, 70):
		var frame_events := session.step(FrameInput.new())
		recovered_events += _count_events(frame_events, CombatEvent.Type.DUMMY_RECOVERED)
		if land_frame == -1 and session.dummy_on_ground and session.dummy_state == CombatSession.DummyState.NEUTRAL:
			land_frame = frame
	_check(land_frame > 0, "air-recovered dummy lands and returns to neutral")
	_check(recovered_events == 1, "single recovery event fires at landing")


func _test_float_landing_keeps_remaining_hitstun() -> void:
	# 浮空硬直未耗尽就落地：转为地面受击硬直继续倒地处理，
	# 落地当帧起继续消耗，剩余帧数从落地保留到自然受身。
	var float_hitstun := 60
	var hit_frame := 3
	var session := CombatSession.new(_long_float_table(float_hitstun))
	session.dummy_position = session.player_position + Vector2(70, 0)
	var convert_frame := -1
	var convert_hitstun := -1
	var last_air_frame := -1
	var recover_frame := -1
	var recovered_events := 0
	for frame in range(1, 70):
		var frame_events := session.step(FrameInput.make(0, false, "C" if frame == 1 else ""))
		if session.dummy_state == CombatSession.DummyState.AIR_HITSTUN:
			last_air_frame = frame
		elif convert_frame == -1 and session.dummy_state == CombatSession.DummyState.GROUND_HITSTUN and session.dummy_on_ground:
			convert_frame = frame
			convert_hitstun = session.dummy_hitstun_left
		recovered_events += _count_events(frame_events, CombatEvent.Type.DUMMY_RECOVERED)
		if convert_frame != -1 and recover_frame == -1 and session.dummy_state == CombatSession.DummyState.NEUTRAL:
			recover_frame = frame
	_check(last_air_frame == hit_frame + GameParams.DUMMY_FLOAT_AIRTIME_FRAMES - 1, "float lasts the configured airtime while hitstun remains")
	_check(convert_frame == hit_frame + GameParams.DUMMY_FLOAT_AIRTIME_FRAMES and convert_hitstun == float_hitstun - GameParams.DUMMY_FLOAT_AIRTIME_FRAMES, "landing converts leftover float hitstun into ground hitstun and ticks it on the landing frame")
	_check(recover_frame == hit_frame + float_hitstun, "converted hitstun counts down on the ground until natural recovery")
	_check(recovered_events == 1, "natural recovery emits exactly one event")


func _test_independent_move_cannot_hit_floating_dummy() -> void:
	# 浮空后续不依赖隐式普通连接：取消窗关闭后，独立招式即使够得着也追不上浮空木桩；
	# 木桩落地自然受身恢复中立后，新的独立招式才能开启下一段连段。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var keys := {1: "C", 30: "A", 56: "A"}
	var hit_frames: Array[int] = []
	for frame in range(1, 70):
		if frame == 30:
			# 把浮空中的木桩摆回 5A 命中框内（离地 20px、仍在浮空受击）。
			session.dummy_position = session.player_position + Vector2(70, -20)
		var frame_events := session.step(FrameInput.make(0, false, keys.get(frame, "")))
		if _count_events(frame_events, CombatEvent.Type.HIT) > 0:
			hit_frames.append(frame)
		if frame == 36:
			_check(session.dummy_state == CombatSession.DummyState.AIR_HITSTUN, "dummy is still in float hitstun through the independent probe")
	_check(hit_frames.size() == 2 and hit_frames[0] == 7, "first hit launches on frame 7 and the floating dummy survives the probe")
	_check(hit_frames[1] >= 56, "fresh swing only hits again after natural recovery")
	_check(_approx(session.dummy_hp, GameParams.DUMMY_MAX_HP - GameParams.MOVE_5C_DAMAGE - GameParams.MOVE_5A_DAMAGE), "only the launcher and the post-recovery swing deal damage")
	_check(session.combo_hits == 1, "post-recovery hit starts a fresh combo count")


func _test_5A_cancels_into_236C_relaunch() -> void:
	# 高级路线接缝：236C 是 5A 的取消目标；5A 命中确认后在取消窗口内消费缓存的 236C，
	# 把被 5A 打得微浮的木桩重新打入完整浮空受击。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(72, 0)
	var hit_frames: Array[int] = []
	for frame in range(1, 21):
		var down := frame == 1 or frame == 2
		var axis := 1 if frame == 2 or frame == 3 else 0
		var key := ""
		if frame == 4:
			key = "A"
		elif frame == 6:
			key = "C"
		var frame_events := session.step(FrameInput.make(axis, false, key, down))
		if _count_events(frame_events, CombatEvent.Type.HIT) > 0:
			hit_frames.append(frame)
		if frame == 9:
			_check(session.player_move_id == "236C", "buffered 236C is consumed on 5A's hit-confirm frame")
		if frame == 15:
			_check(session.dummy_hitstun_left == GameParams.FLOAT_HITSTUN_FRAMES, "relaunch refreshes the full float hitstun")
	_check(hit_frames == [9, 15], "5A hits on frame 9 and the canceled 236C connects on frame 15")
	_check(session.combo_hits == 2 and session.combo_active, "relaunch counts as the second combo hit")
	_check(session.dummy_state == CombatSession.DummyState.AIR_HITSTUN and not session.dummy_on_ground, "mid-hop dummy is relaunched into full float hitstun")
	_check(_approx(session.dummy_hp, GameParams.DUMMY_MAX_HP - GameParams.MOVE_5A_DAMAGE - GameParams.MOVE_236C_DAMAGE * 0.9), "route damage is 5A full plus decayed 236C")
	_check(_approx(session.combo_last_scale, 0.9), "second hit scale is 90%")


func _test_5B_cancels_into_214D_finisher() -> void:
	# 214D 是 5B 的取消目标（面向锁定时反向四分之一圆）：方向收尾命中后结束路线但保留倒地处理。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var hit_frames: Array[int] = []
	var finisher_state := CombatSession.DummyState.NEUTRAL
	var finisher_hitstun := -1
	var recovered_events := 0
	for frame in range(1, 45):
		# 5B 起手后在执行中输入 214（↓、↓+←、←）并在取消窗口内按 D。
		var down := frame == 1 or frame == 2
		var axis := -1 if frame == 2 or frame == 3 else 0
		var key := ""
		if frame == 1:
			key = "B"
		elif frame == 3:
			key = "D"
		var frame_events := session.step(FrameInput.make(axis, false, key, down))
		if _count_events(frame_events, CombatEvent.Type.HIT) > 0:
			hit_frames.append(frame)
		if frame == 5:
			_check(session.player_move_id == "214D", "buffered 214D is consumed on 5B's hit-confirm frame")
		if _combo_end_events(frame_events, CombatEvent.ComboEndReason.FINISHER) > 0:
			finisher_state = session.dummy_state
			finisher_hitstun = session.dummy_hitstun_left
		recovered_events += _count_events(frame_events, CombatEvent.Type.DUMMY_RECOVERED)
	_check(hit_frames == [5, 12], "5B hits on frame 5 and the canceled 214D connects on frame 12")
	_check(_approx(session.dummy_hp, GameParams.DUMMY_MAX_HP - GameParams.MOVE_5B_DAMAGE - GameParams.MOVE_214D_DAMAGE * 0.9), "route damage is 5B full plus decayed 214D")
	_check(finisher_state == CombatSession.DummyState.GROUND_HITSTUN and finisher_hitstun == GameParams.HITSTUN_FRAMES, "direction finisher keeps the dummy's knockdown hitstun handling")
	_check(recovered_events == 1, "dummy recovers naturally after the direction finisher")
	_check(session.dummy_state == CombatSession.DummyState.NEUTRAL, "dummy is neutral again after recovery")


func _test_jump_cancel_requires_hit_config_and_window() -> void:
	# jump cancel 门槛：招式配置（5C/236C）、命中确认（挥空不算）与取消窗口缺一不可；
	# 不满足时 Space 不改变玩家与连段状态，收招后 Space 恢复为普通跳跃。
	var whiff := CombatSession.new()
	whiff.dummy_position = Vector2(900.0, GameParams.ground_stand_y())
	var grounded_on_space := false
	for frame in range(1, 28):
		whiff.step(FrameInput.make(0, frame == 8, "C" if frame == 1 else ""))
		if frame == 8:
			grounded_on_space = whiff.player_on_ground
	_check(grounded_on_space and whiff.combo_hits == 0 and not whiff.combo_active, "whiffed launcher ignores space during the move")
	whiff.step(FrameInput.make(0, true))
	_check(not whiff.player_on_ground, "space works again as a normal jump after the whiffed move recovers")

	var plain := CombatSession.new()
	plain.dummy_position = plain.player_position + Vector2(70, 0)
	var unconfigured_state_ok := false
	for frame in range(1, 10):
		plain.step(FrameInput.make(0, frame == 7 or frame == 8, "A" if frame == 1 else ""))
		if frame == 9:
			unconfigured_state_ok = plain.player_on_ground and plain.player_move_id == "5A"
	_check(unconfigured_state_ok, "hit move without jump cancel config ignores space")
	_check(plain.combo_hits == 1 and plain.combo_active, "space on an unconfigured move leaves the combo state untouched")

	var late := CombatSession.new()
	late.dummy_position = late.player_position + Vector2(72, 0)
	var end_frames: Array[int] = []
	for frame in range(1, 21):
		var input := _qcf_input(frame, 4, "C") if frame <= 4 else FrameInput.make(0, frame == 19)
		var events := late.step(input)
		if _combo_end_events(events, CombatEvent.ComboEndReason.CANCEL_WINDOW_CLOSED) > 0:
			end_frames.append(frame)
	_check(late.player_on_ground and not late.combo_active, "space after the cancel window cannot jump cancel")
	_check(end_frames == [19], "combo ends from the closed cancel window, not from the space press")


func _test_jump_cancel_236C_into_jA_pursuit() -> void:
	# 高级路线前半段：236C 命中确认 → Space jump cancel 转入空中并保留连段 →
	# A 起手 jA 空中追击。追击是普通命中：不刷新木桩滞空，木桩仍在原始浮空抛物线上落地。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(72, 0)
	var hit_frames: Array[int] = []
	var land_frame := -1
	var airborne_seen := false
	var vy_before_pursuit := 0.0
	var combo_end_frames: Array[int] = []
	for frame in range(1, 80):
		var input := _qcf_input(frame, 4, "C") if frame <= 4 else FrameInput.make(0, frame == 11, "A" if frame == 13 else "")
		var events := session.step(input)
		if _count_events(events, CombatEvent.Type.HIT) > 0:
			hit_frames.append(frame)
		if frame == 11:
			_check(not session.player_on_ground, "space on the confirmed 236C lifts the player on the same frame")
			_check(session.player_move_id == "" and session.player_phase == CombatSession.PlayerPhase.NEUTRAL, "jump cancel clears the launcher into neutral air")
			_check(session.combo_active and session.combo_hits == 1, "jump cancel keeps the combo alive for air pursuit")
		if frame == 14:
			_check(session.player_move_id == "jA", "air action after jump cancel starts the jA pursuit move")
			_check(not session.player_on_ground, "jA starts while airborne")
		if frame == 16:
			vy_before_pursuit = session.dummy_velocity.y
		if frame == 17:
			_check(session.dummy_state == CombatSession.DummyState.GROUND_HITSTUN and not session.dummy_on_ground, "jA pursuit keeps the dummy airborne in normal hitstun")
			_check(is_equal_approx(session.dummy_velocity.y, vy_before_pursuit + GameParams.GRAVITY * GameParams.PHYSICS_TICK), "pursuit hit does not refresh the float arc")
		if frame > 10:
			if session.dummy_on_ground:
				if airborne_seen and land_frame == -1:
					land_frame = frame
			else:
				airborne_seen = true
		if _combo_end_events(events, CombatEvent.ComboEndReason.CANCEL_WINDOW_CLOSED) > 0:
			combo_end_frames.append(frame)
	_check(hit_frames == [10, 17], "236C hits on frame 10 and the pursued jA connects on frame 17")
	_check(session.combo_hits == 2 and not session.combo_active, "route counts two hits and ends when jA's cancel window closes")
	_check(combo_end_frames == [26], "combo ends nine frames after the jA hit")
	_check(land_frame == 10 + GameParams.DUMMY_FLOAT_AIRTIME_FRAMES, "dummy lands exactly one float airtime after the launcher, unrefreshed by the pursuit")
	_check(_approx(session.dummy_hp, GameParams.DUMMY_MAX_HP - GameParams.MOVE_236C_DAMAGE - GameParams.MOVE_JA_DAMAGE * 0.9), "route damage is 236C full plus decayed jA")


func _test_jump_cancel_5C_into_jA_pursuit() -> void:
	# 5C 与 236C 同样配置 jump cancel：C 语义命中 → Space → jA 空中追击计数第二击。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var hit_frames: Array[int] = []
	for frame in range(1, 30):
		var key := ""
		if frame == 1:
			key = "C"
		elif frame == 10:
			key = "A"
		var events := session.step(FrameInput.make(0, frame == 8, key))
		if _count_events(events, CombatEvent.Type.HIT) > 0:
			hit_frames.append(frame)
	_check(hit_frames == [7, 14], "5C hits on frame 7 and the jump-canceled jA connects on frame 14")
	_check(session.combo_hits == 2, "jA pursuit after 5C counts as the second combo hit")


func _test_space_does_not_touch_action_buffer() -> void:
	# Space 与动作键缓存完全独立：5A 命中后按 Space（5A 未配置 jump cancel）不缓存、
	# 不消费也不覆盖动作键，随后输入的 B 仍按缓存取消进 5B。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	for frame in range(1, 17):
		var key := ""
		if frame == 1:
			key = "A"
		elif frame == 9:
			key = "B"
		session.step(FrameInput.make(0, frame == 7, key))
		if frame == 8:
			_check(session.player_on_ground and session.player_move_id == "5A", "space neither jumps nor disturbs the ongoing move")
		if frame == 10:
			_check(session.player_move_id == "5B", "action buffer survives the space press and still cancels 5A into 5B")
	_check(session.combo_hits == 2, "the buffered cancel still extends the combo")


func _test_no_double_jump_after_jump_cancel() -> void:
	# jump cancel 转入空中后 Space 不再起跳：无二段跳、无第二次向上速度，
	# 落地帧仍恰为起跳帧 + PLAYER_JUMP_AIRTIME_FRAMES。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(72, 0)
	var jump_cancel_frame := -1
	var land_frame := -1
	var second_impulse_seen := false
	for frame in range(1, 60):
		var input := _qcf_input(frame, 4, "C") if frame <= 4 else FrameInput.make(0, frame == 11 or frame == 16 or frame == 21 or frame == 26)
		session.step(input)
		if frame == 11:
			jump_cancel_frame = frame
		if jump_cancel_frame != -1 and land_frame == -1:
			if session.player_on_ground:
				land_frame = frame
			elif frame > jump_cancel_frame + 2 and session.player_velocity.y < -GameParams.jump_velocity() * 0.9:
				second_impulse_seen = true
	_check(jump_cancel_frame == 11 and not second_impulse_seen, "air space presses never grant a second upward impulse")
	_check(land_frame == jump_cancel_frame + GameParams.PLAYER_JUMP_AIRTIME_FRAMES, "airtime after jump cancel stays exactly the configured frames with no double jump")


func _test_jump_airtime_matches_param() -> void:
	# 默认参数：玩家跳跃持续 40 个物理帧、木桩浮空滞空 48 个物理帧（滞空由参数换算）。
	var session := CombatSession.new()
	session.dummy_position = Vector2(100.0, GameParams.ground_stand_y())
	var jump_frame := 5
	var land_frame := -1
	for frame in range(1, 60):
		session.step(FrameInput.make(0, frame == jump_frame))
		if land_frame == -1 and frame > jump_frame and session.player_on_ground:
			land_frame = frame
	_check(land_frame == jump_frame + GameParams.PLAYER_JUMP_AIRTIME_FRAMES, "neutral jump lasts exactly the configured airtime frames")
	_check(GameParams.PLAYER_JUMP_AIRTIME_FRAMES == 40 and GameParams.DUMMY_FLOAT_AIRTIME_FRAMES == 48, "default airtime params are 40-frame jump and 48-frame float")


func _test_jump_cancel_landing_without_pursuit_ends_combo() -> void:
	# jump cancel 后始终不接空中起手：玩家落地当帧追击资格作废，连段以收招未接续结束；
	# 木桩浮空处理不受影响（长浮空硬直下木桩仍在浮空受击中）。
	var table := MoveData.default_table()
	(table["5C"] as MoveData).hitstun_frames = 60
	var session := CombatSession.new(table)
	session.dummy_position = session.player_position + Vector2(70, 0)
	var end_frames: Array[int] = []
	var end_reasons: Array[int] = []
	var dummy_state_at_end := CombatSession.DummyState.NEUTRAL
	for frame in range(1, 50):
		var events := session.step(FrameInput.make(0, frame == 8, "C" if frame == 1 else ""))
		for event in events:
			if event.type == CombatEvent.Type.COMBO_ENDED:
				end_frames.append(frame)
				end_reasons.append(event.combo_end_reason)
				dummy_state_at_end = session.dummy_state
	_check(end_frames == [48], "combo ends exactly when the player lands without air pursuit")
	_check(end_reasons == [CombatEvent.ComboEndReason.MOVE_RECOVERED], "landing without pursuit ends the combo as an unrecovered cancel")
	_check(session.combo_hits == 1, "combo stops counting at the launcher hit")
	_check(dummy_state_at_end == CombatSession.DummyState.AIR_HITSTUN, "landing without pursuit leaves the dummy's float handling untouched")


func _test_neutral_jump_jA_cannot_pursue() -> void:
	# 收招断连后的普通跳跃不产生追击资格：空中 jA 即使把浮空木桩摆进命中框也打不中。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var hit_frames: Array[int] = []
	for frame in range(1, 50):
		var key := ""
		if frame == 1:
			key = "C"
		elif frame == 32:
			key = "A"
		if frame == 31:
			# 木桩仍在浮空受击中：摆进 jA 命中框并停住，验证资格而非几何挡住追击。
			session.dummy_position = session.player_position + Vector2(70, -15)
			session.dummy_velocity = Vector2.ZERO
		var events := session.step(FrameInput.make(0, frame == 30, key))
		if _count_events(events, CombatEvent.Type.HIT) > 0:
			hit_frames.append(frame)
		if frame == 34:
			_check(session.player_move_id == "jA", "air action during a plain jump still starts jA")
			_check(session.dummy_state == CombatSession.DummyState.AIR_HITSTUN, "dummy is still in float hitstun inside the attack rect")
	_check(hit_frames == [7], "neutral-jump jA cannot pursue the floating dummy")
	_check(session.combo_hits == 1, "combo count stays at the launcher hit")


func _test_full_air_route_5A_236C_jA_jB_jD() -> void:
	# 完整空中路线：5A → 236C（命中确认取消）→ Space jump cancel →
	# jA → jB → jD 空中收尾。五次命中依次计入连段并按 100%~60% 递减；
	# 空中收尾结束连段但保留木桩倒地处理，木桩照常落地并自然受身。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(64, 0)
	var hit_frames: Array[int] = []
	var move_ids: Array[String] = []
	var end_frames: Array[int] = []
	var end_reasons: Array[int] = []
	var recovered_frames: Array[int] = []
	var hit_while_grounded := false
	var saw_airborne_ground_hitstun := false
	for frame in range(1, 80):
		var down := frame == 1 or frame == 2
		var axis := 1 if frame == 2 or frame == 3 else 0
		var key := ""
		if frame == 4:
			key = "A"
		elif frame == 6:
			key = "C"
		elif frame == 17:
			key = "A"
		elif frame == 19:
			key = "B"
		elif frame == 23:
			key = "D"
		var events := session.step(FrameInput.make(axis, frame == 16, key, down))
		move_ids.append(session.player_move_id)
		if _count_events(events, CombatEvent.Type.HIT) > 0:
			hit_frames.append(frame)
			# 空中路线段（jump cancel 之后）的命中必须滞空完成。
			hit_while_grounded = hit_while_grounded or (frame >= 17 and session.player_on_ground)
		for event in events:
			if event.type == CombatEvent.Type.COMBO_ENDED:
				end_frames.append(frame)
				end_reasons.append(event.combo_end_reason)
			elif event.type == CombatEvent.Type.DUMMY_RECOVERED:
				recovered_frames.append(frame)
		if frame == 22:
			saw_airborne_ground_hitstun = session.dummy_state == CombatSession.DummyState.GROUND_HITSTUN \
				and not session.dummy_on_ground and session.dummy_hitstun_left == GameParams.HITSTUN_FRAMES
	_check(hit_frames == [9, 15, 21, 25, 29], "air route lands 5A/236C on 9/15, then jA/jB/jD on 21/25/29")
	_check(move_ids[8] == "236C" and move_ids[16] == "jA" and move_ids[20] == "jB" and move_ids[24] == "jD", "route chains 236C -> jA -> jB -> jD via hit-confirm cancels")
	_check(not hit_while_grounded, "every air-route hit lands while the player is airborne")
	_check(not session.combo_active and session.combo_hits == 5, "air finisher ends the route at five hits")
	_check(end_frames == [29] and end_reasons == [CombatEvent.ComboEndReason.FINISHER], "jD hit is the only combo end, as the air finisher")
	_check(_approx(session.combo_last_scale, 0.6), "fifth hit lands at 60 percent scale")
	_check(_approx(session.combo_total_damage, 53.0), "route damage decays to a 53.0 total")
	_check(_approx(session.dummy_hp, GameParams.DUMMY_MAX_HP - 53.0), "dummy hp reflects the full air route")
	_check(saw_airborne_ground_hitstun, "air pursuit keeps the dummy airborne in normal hitstun until it lands")
	_check(recovered_frames == [73], "dummy completes its knockdown handling with one natural recovery after the finisher")
	_check(session.dummy_state == CombatSession.DummyState.NEUTRAL and session.combo_hits == 5, "combo count stops growing after the route ends")


func _test_same_frame_hit_landing_and_landing_followup() -> void:
	# 临界落地帧：jB 命中、玩家落地与缓存消费发生在同一物理帧。结算顺序固定为
	# 命中刷新木桩硬直 → 落地 → 取消判定 → 消费缓存：木桩受击硬直只剩 1 帧时，
	# 命中先刷新为 12（落地当帧不消耗新硬直）；jB 配置的落地接续把缓存的 D
	# 按地面姿态重解析为 5D，并作为合法接续在落地当帧起手。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(64, 0)
	var hit_frames: Array[int] = []
	var move_ids: Array[String] = []
	var end_frames: Array[int] = []
	var end_reasons: Array[int] = []
	var recovered_frames: Array[int] = []
	var critical_events: Array[CombatEvent] = []
	var critical_state_ok := false
	var jB_in_progress_at_pin := false
	for frame in range(1, 80):
		if frame == 56:
			# 临界初态：jB 已出招未命中、玩家距落地 1 帧、木桩硬直只剩 1 帧、
			# D 已按空中姿态缓存为 jD。路线前段全部由真实输入打出。
			jB_in_progress_at_pin = session.player_move_id == "jB" and not session.player_on_ground
			session.dummy_position = Vector2(session.player_position.x + 60.0, GameParams.ground_stand_y())
			session.dummy_velocity = Vector2.ZERO
			session.dummy_state = CombatSession.DummyState.GROUND_HITSTUN
			session.dummy_hitstun_left = 1
			session.dummy_on_ground = true
		var down := frame == 1 or frame == 2
		var axis := 1 if frame == 2 or frame == 3 else 0
		var key := ""
		if frame == 4:
			key = "A"
		elif frame == 6:
			key = "C"
		elif frame == 44:
			key = "A"
		elif frame == 52:
			key = "B"
		elif frame == 54:
			key = "D"
		var events := session.step(FrameInput.make(axis, frame == 16, key, down))
		move_ids.append(session.player_move_id)
		if _count_events(events, CombatEvent.Type.HIT) > 0:
			hit_frames.append(frame)
		for event in events:
			if event.type == CombatEvent.Type.COMBO_ENDED:
				end_frames.append(frame)
				end_reasons.append(event.combo_end_reason)
			elif event.type == CombatEvent.Type.DUMMY_RECOVERED:
				recovered_frames.append(frame)
		if frame == 56:
			critical_events = events
			critical_state_ok = session.player_move_id == "5D" and session.player_on_ground \
				and session.combo_hits == 4 and session.combo_active \
				and session.dummy_state == CombatSession.DummyState.GROUND_HITSTUN \
				and session.dummy_hitstun_left == GameParams.HITSTUN_FRAMES
	_check(jB_in_progress_at_pin, "route reaches the critical frame with jB airborne and one frame from landing")
	_check(hit_frames == [9, 15, 48, 56, 61], "jB hits exactly on the landing frame, then the landing followup 5D connects")
	_check(critical_events.size() == 1 and critical_events[0].type == CombatEvent.Type.HIT, "the critical frame emits only the hit event: hit refreshed hitstun before landing ticked it")
	_check(critical_state_ok, "same-frame order is hit refresh -> landing -> cancel -> consume: buffered D starts 5D as a legal followup")
	_check(not "jD" in move_ids, "the buffered D is never consumed as the air finisher on the landing frame")
	_check(end_frames == [61] and end_reasons == [CombatEvent.ComboEndReason.FINISHER], "landing followup 5D ends the route as the ground finisher")
	_check(_approx(session.combo_total_damage, 51.8), "route damage totals 51.8 through the landing followup")
	_check(recovered_frames == [77] and session.dummy_state == CombatSession.DummyState.NEUTRAL, "dummy completes its knockdown handling after the finisher")
	_check(session.combo_hits == 5, "combo counts all five hits and stops there")


func _test_landing_seam_only_opens_on_the_landing_frame() -> void:
	# 落地接续只在落地当帧开放：jB 命中与落地同帧但没有缓存 D，落地后下一帧
	# 才按 D——落地帧已过，接缝关闭，jB 作废断连；地面解析出的 5D 只按独立
	# 招式起手，打不中仍在受击中的木桩，连段命中数不再增长。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(64, 0)
	var hit_frames: Array[int] = []
	var move_ids: Array[String] = []
	var end_frames: Array[int] = []
	var end_reasons: Array[int] = []
	var recovered_frames: Array[int] = []
	var independent_5D_started := false
	for frame in range(1, 90):
		if frame == 56:
			session.dummy_position = Vector2(session.player_position.x + 60.0, GameParams.ground_stand_y())
			session.dummy_velocity = Vector2.ZERO
			session.dummy_state = CombatSession.DummyState.GROUND_HITSTUN
			session.dummy_hitstun_left = 1
			session.dummy_on_ground = true
		var down := frame == 1 or frame == 2
		var axis := 1 if frame == 2 or frame == 3 else 0
		var key := ""
		if frame == 4:
			key = "A"
		elif frame == 6:
			key = "C"
		elif frame == 44:
			key = "A"
		elif frame == 52:
			key = "B"
		elif frame == 57:
			key = "D"
		var events := session.step(FrameInput.make(axis, frame == 16, key, down))
		move_ids.append(session.player_move_id)
		if _count_events(events, CombatEvent.Type.HIT) > 0:
			hit_frames.append(frame)
		for event in events:
			if event.type == CombatEvent.Type.COMBO_ENDED:
				end_frames.append(frame)
				end_reasons.append(event.combo_end_reason)
			elif event.type == CombatEvent.Type.DUMMY_RECOVERED:
				recovered_frames.append(frame)
		if frame == 57:
			independent_5D_started = session.player_move_id == "5D" and not session.combo_active
	_check(hit_frames == [9, 15, 48, 56], "jB lands on the landing frame but no fifth hit ever connects")
	_check(independent_5D_started, "D pressed after the landing frame starts 5D as an independent move")
	_check(end_frames == [56] and end_reasons == [CombatEvent.ComboEndReason.MOVE_RECOVERED], "the landed jB is invalidated on its landing frame and ends the combo there")
	_check(session.combo_hits == 4 and _approx(session.combo_total_damage, 41.0), "the independent 5D cannot extend the combo against the stunned dummy")
	_check(recovered_frames == [77] and session.dummy_state == CombatSession.DummyState.NEUTRAL, "dummy finishes its own knockdown handling after the whiffed probe")


func _test_landing_does_not_grant_normal_cancels() -> void:
	# 落地不自动授予取消资格：jA 未配置落地接续，落地帧缓存的 D 不会接出 5D；
	# 滞留地面姿态的空中招式作废，连段以收招未接续结束，木桩受击处理独立继续。
	# 木桩浮空硬直在 jA 命中前只剩 1 帧：命中先刷新为 12，自然受身没有先发生。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(64, 0)
	var hit_frames: Array[int] = []
	var move_ids: Array[String] = []
	var end_frames: Array[int] = []
	var end_reasons: Array[int] = []
	var recovered_frames: Array[int] = []
	var hitstun_at_jA_hit := -1
	var player_neutral_after_landing := false
	for frame in range(1, 80):
		var key := ""
		if frame == 1:
			key = "C"
		elif frame == 39:
			key = "A"
		elif frame == 45:
			key = "D"
		var events := session.step(FrameInput.make(0, frame == 8, key))
		move_ids.append(session.player_move_id)
		if _count_events(events, CombatEvent.Type.HIT) > 0:
			hit_frames.append(frame)
			if frame == 43:
				hitstun_at_jA_hit = session.dummy_hitstun_left
		for event in events:
			if event.type == CombatEvent.Type.COMBO_ENDED:
				end_frames.append(frame)
				end_reasons.append(event.combo_end_reason)
			elif event.type == CombatEvent.Type.DUMMY_RECOVERED:
				recovered_frames.append(frame)
		if frame == 49:
			player_neutral_after_landing = session.player_move_id == "" \
				and session.player_phase == CombatSession.PlayerPhase.NEUTRAL and session.player_on_ground
	_check(hit_frames == [7, 43], "5C launches and the late jA pursuit connects at the hitstun boundary")
	_check(hitstun_at_jA_hit == GameParams.HITSTUN_FRAMES, "jA hit refreshes the one-frame-left hitstun before natural recovery takes it")
	_check(end_frames == [48] and end_reasons == [CombatEvent.ComboEndReason.MOVE_RECOVERED], "combo ends on the landing frame as an unrecovered air move")
	_check(player_neutral_after_landing, "the landed air move is cleared and the player is neutral again")
	_check(not "5D" in move_ids and not "jD" in move_ids, "buffered D is never consumed: landing grants no cancel to an unconfigured move")
	_check(session.combo_hits == 2 and not session.combo_active, "combo stops at two hits")
	_check(recovered_frames == [66] and session.dummy_state == CombatSession.DummyState.NEUTRAL, "dummy finishes its own knockdown handling regardless of the combo end")


func _test_air_tech_breaks_combo_before_late_pursuit() -> void:
	# 追击迟到：木桩浮空硬直耗尽先自然受身，连段立即结束；迟到的 jA 即使把
	# 木桩含在命中框内也不能命中，连段命中数停在受身前不再增长；
	# 落地作废的空中招式不会触发第二次连段结束。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(64, 0)
	var hit_frames: Array[int] = []
	var end_frames: Array[int] = []
	var end_reasons: Array[int] = []
	var recovered_frames: Array[int] = []
	var pursuit_overlaps_recovered_dummy := false
	var player_neutral_after_landing := false
	for frame in range(1, 80):
		var down := frame == 1 or frame == 2
		var axis := 1 if frame == 2 or frame == 3 else 0
		var key := ""
		if frame == 4:
			key = "A"
		elif frame == 6:
			key = "C"
		elif frame == 49:
			key = "A"
		var events := session.step(FrameInput.make(axis, frame == 16, key, down))
		if _count_events(events, CombatEvent.Type.HIT) > 0:
			hit_frames.append(frame)
		for event in events:
			if event.type == CombatEvent.Type.COMBO_ENDED:
				end_frames.append(frame)
				end_reasons.append(event.combo_end_reason)
			elif event.type == CombatEvent.Type.DUMMY_RECOVERED:
				recovered_frames.append(frame)
		if frame == 53:
			pursuit_overlaps_recovered_dummy = session.dummy_state == CombatSession.DummyState.AIR_RECOVERED \
				and session.player_move_id == "jA" \
				and session.player_attack_rect().intersects(Rect2(session.dummy_position - GameParams.BODY_SIZE * 0.5, GameParams.BODY_SIZE))
		if frame == 57:
			player_neutral_after_landing = session.player_move_id == "" and session.player_on_ground
	_check(hit_frames == [9, 15], "only the launcher route lands before the air tech")
	_check(end_frames == [51] and end_reasons == [CombatEvent.ComboEndReason.DUMMY_RECOVERED], "air tech ends the combo exactly when float hitstun runs out, with no second end at landing")
	_check(pursuit_overlaps_recovered_dummy, "late jA overlaps the air-recovered dummy inside its attack rect but cannot hit it")
	_check(player_neutral_after_landing, "the landed pursuit move is cleared on landing")
	_check(session.combo_hits == 2 and not session.combo_active, "combo count freezes at the tech")
	_check(recovered_frames == [62] and session.dummy_state == CombatSession.DummyState.NEUTRAL, "air-recovered dummy lands back to neutral with a single recovery event")


# --- 辅助 ---

## 依次喂入 [axis, down, key] 单帧步并结算，返回总命中数。
func _play_script(session: CombatSession, steps: Array) -> int:
	var hits := 0
	for step in steps:
		var events := session.step(FrameInput.make(step[0], false, step[2], step[1]))
		hits += _count_events(events, CombatEvent.Type.HIT)
	return hits


## 连续 frames 帧中立无输入，返回总命中数（等待招式结算完成）。
func _run_neutral(session: CombatSession, frames: int) -> int:
	var hits := 0
	for i in range(frames):
		var events := session.step(FrameInput.new())
		hits += _count_events(events, CombatEvent.Type.HIT)
	return hits

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


## 前四分之一圆输入脚本（面向右）：F1 ↓、F2 ↓+→、F3 →，其余帧中立；key_frame 帧附带动作键。
func _qcf_input(frame: int, key_frame: int, key: String) -> FrameInput:
	var axis := 1 if frame == 2 or frame == 3 else 0
	var down := frame == 1 or frame == 2
	return FrameInput.make(axis, false, key if frame == key_frame else "", down)


## 后四分之一圆输入脚本（面向右）：F1 ↓、F2 ↓+←、F3 ←，其余帧中立；key_frame 帧附带动作键。
func _qcb_input(frame: int, key_frame: int, key: String) -> FrameInput:
	var axis := -1 if frame == 2 or frame == 3 else 0
	var down := frame == 1 or frame == 2
	return FrameInput.make(axis, false, key if frame == key_frame else "", down)


## 相对小键盘方向 → FrameInput：按会话当前面向折算世界水平轴（3/6/9 为前），
## 1/2/3 带下方向，5 为中立；key 为该帧动作键。左右面向用同一份数字脚本。
func _relative_input(session: CombatSession, digit: int, key: String = "") -> FrameInput:
	var axis := 0
	if digit == 3 or digit == 6 or digit == 9:
		axis = session.player_facing
	elif digit == 1 or digit == 4 or digit == 7:
		axis = -session.player_facing
	var down := digit >= 1 and digit <= 3
	return FrameInput.make(axis, false, key, down)


## 相对方向逐帧脚本：每项为 [digit] 或 [digit, "key"]。
func _run_relative(session: CombatSession, frames: Array) -> void:
	for item in frames:
		session.step(_relative_input(session, item[0], item[1] if item.size() > 1 else ""))


## 诊断快照中某招式当前的指令锁定候选（宽松首个终点锁定的可观察口径）。
func _lock_for(session: CombatSession, move_id: String) -> Dictionary:
	for entry in session.debug_snapshot()["direction_locks"]:
		if entry["move_id"] == move_id:
			return entry
	return {}


## 指令规则注入表：宽松 623A 与严格 214D（均 SPECIAL 层）分别与同键普通招式
## 5A/5D（NORMAL 层）共存——层级、宽松与记法全部由数据表达。
func _command_rule_table() -> Dictionary:
	var dp := _probe_move("623A", "A")
	dp.direction_derivation = "623A"
	dp.lenient_command = true
	dp.command_tier = MoveData.CommandTier.SPECIAL
	var plain_a := _probe_move("5A", "A")
	var qcb := _probe_move("214D", "D")
	qcb.direction_derivation = "214D"
	qcb.command_tier = MoveData.CommandTier.SPECIAL
	var plain_d := _probe_move("5D", "D")
	return {"623A": dp, "5A": plain_a, "214D": qcb, "5D": plain_d}


## 指令分层注入表：同键 D 上超必杀 SD（六步基础串 + 五步替代串 23626/26236，
## priority 最低）、宽松必杀 623D/63D（priority 可调）与普通 5D——验证层级与
## 同层 priority 顺序。
func _tier_table(p623 := 9, p63 := 5) -> Dictionary:
	var super_move := _probe_move("SD", "D")
	super_move.direction_derivation = "236236D"
	super_move.input_alternatives = ["23626D", "26236D"]
	super_move.command_tier = MoveData.CommandTier.SUPER
	super_move.priority = 0
	var dp := _probe_move("623D", "D")
	dp.direction_derivation = "623D"
	dp.lenient_command = true
	dp.command_tier = MoveData.CommandTier.SPECIAL
	dp.priority = p623
	var short := _probe_move("63D", "D")
	short.direction_derivation = "63D"
	short.lenient_command = true
	short.command_tier = MoveData.CommandTier.SPECIAL
	short.priority = p63
	var plain := _probe_move("5D", "D")
	return {"SD": super_move, "623D": dp, "63D": short, "5D": plain}


## 测试用探针招式：字段齐全的合法打击招式（值取旧 GameParams 运行时默认，
## issue 11 起核心字段缺省是“未声明”哨兵值，程序内构造必须显式补齐）。
func _probe_move(id: String, key: String) -> MoveData:
	var move := MoveData.new()
	move.move_id = id
	move.move_kind = MoveData.MoveKind.STRIKE
	move.stance = MoveData.Stance.GROUND
	move.action_key = key
	move.startup_frames = 5
	move.active_frames = 7
	move.recovery_frames = 13
	move.cancel_window_frames = GameParams.CANCEL_WINDOW_FRAMES
	move.priority = 1
	move.base_damage = 10
	move.attack_attribute = MoveData.AttackAttribute.HIGH
	move.hitbox_size = GameParams.ATTACK_HITBOX_SIZE
	move.hitbox_gap = GameParams.ATTACK_HITBOX_GAP
	move.hit_result = MoveData.HitResult.GROUND_HITSTUN
	move.hitstun_frames = GameParams.HITSTUN_FRAMES
	move.knockback = GameParams.MOVE_5A_KNOCKBACK
	move.knockback_up = GameParams.ATTACK_KNOCKBACK_UP
	return move


## 空中派生注入表：j214D（AIR + 214 派生，SPECIAL 层与同键 jD 分层）、无派生 jD
## 回落与 jA（识别但不可接续场景的执行中招式）；地面无 D/A 招式，隔离姿态解析。
func _air_derivation_table() -> Dictionary:
	var air_qcb := _probe_move("j214D", "D")
	air_qcb.stance = MoveData.Stance.AIR
	air_qcb.direction_derivation = "214D"
	air_qcb.command_tier = MoveData.CommandTier.SPECIAL
	air_qcb.air_attack = true
	var air_plain := _probe_move("jD", "D")
	air_plain.stance = MoveData.Stance.AIR
	air_plain.air_attack = true
	var air_a := _probe_move("jA", "A")
	air_a.stance = MoveData.Stance.AIR
	air_a.air_attack = true
	return {"j214D": air_qcb, "jD": air_plain, "jA": air_a}


## 浮空受身探针表：5C 硬直 12、取消窗 60、收招总长 15 帧——
## 招式收招与受身同帧（运动阶段先于收招结算），保证连段存活到受身帧。
func _float_probe_table() -> Dictionary:
	var launcher := _probe_move("5C", "C")
	launcher.startup_frames = 2
	launcher.active_frames = 2
	launcher.recovery_frames = 11
	launcher.base_damage = 10
	launcher.hit_result = MoveData.HitResult.LAUNCH
	launcher.hitstun_frames = 12
	launcher.knockback = 0.0
	launcher.knockback_up = GameParams.float_launch_speed()
	launcher.cancel_window_frames = 60
	var probe := _probe_move("5A", "A")
	probe.startup_frames = 2
	probe.active_frames = 2
	probe.recovery_frames = 8
	probe.base_damage = 10
	probe.hitstun_frames = 30
	probe.knockback = 0.0
	probe.knockback_up = 0.0
	return {"5C": launcher, "5A": probe}


## 长浮空表：硬直超过滞空，验证落地保留剩余浮空硬直。
func _long_float_table(float_hitstun: int) -> Dictionary:
	var table := _float_probe_table()
	(table["5C"] as MoveData).hitstun_frames = float_hitstun
	return table


## 慢速地面表：5A 前摇 8 帧（F1 出招、F9 命中），用于缓存年龄边界。
func _slow_ground_table() -> Dictionary:
	var starter := _probe_move("5A", "A")
	starter.startup_frames = 8
	starter.active_frames = 2
	starter.recovery_frames = 12
	starter.base_damage = 10
	starter.hitstun_frames = 20
	starter.knockback = 0.0
	starter.knockback_up = 0.0
	starter.cancel_targets = ["5B"]
	var linker := _probe_move("5B", "B")
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
	var move := _probe_move("5A", "A")
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
	var move_a := _probe_move("5A", "A")
	move_a.startup_frames = 2
	move_a.active_frames = 2
	move_a.recovery_frames = 8
	move_a.base_damage = 10
	move_a.hitstun_frames = 60
	move_a.knockback = 0.0
	move_a.knockback_up = 0.0
	move_a.cancel_targets = ["5B"]
	var move_b := _probe_move("5B", "B")
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
