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
	_test_5B_late_214c_starts_independently()
	_test_jump_cancel_requires_hit_config_and_window()
	_test_jump_cancel_6A_into_jA_pursuit()
	_test_jump_cancel_5C_into_jA_pursuit()
	_test_space_does_not_touch_action_buffer()
	_test_no_double_jump_after_jump_cancel()
	_test_jump_airtime_matches_param()
	_test_jump_lifecycle_prejump_air_landing_recovery()
	_test_prejump_locks_actions_and_rejump()
	_test_landing_recovery_locks_and_empty_jump_exception()
	_test_air_move_landing_penalty_and_extra_recovery()
	_test_hitstop_jump_slot_lifetime_seam()
	_test_jump_and_action_same_frame_competition()
	_test_cached_jump_direction_seam()
	_test_jump_cancel_landing_without_pursuit_ends_combo()
	_test_neutral_jump_jA_cannot_pursue()
	_test_full_air_route_5A_5B_6A_jA_jB_j5D()
	_test_same_frame_hit_landing_and_landing_followup()
	_test_landing_seam_only_opens_on_the_landing_frame()
	_test_landing_does_not_grant_normal_cancels()
	_test_air_tech_breaks_combo_before_late_pursuit()
	_test_hitstop_freezes_eight_physics_frames_after_hit()
	_test_hitstop_records_input_and_pauses_ages()
	_test_hitstop_does_not_consume_direction_window()
	_test_cancel_age_counts_normal_frames()
	_test_cancel_diagnostics_and_consumption_record()
	_test_crouch_entry_and_stationary_movement()
	_test_guard_postures_ground_air_prejump()
	_test_dummy_attack_lifecycle_observable()
	_test_guard_attribute_matrix()
	_test_block_guard_stun_hitstop_repeatable()
	_test_player_hit_reaction_locks()
	_test_crouch_blocked_in_restricted_phases()
	_test_landing_guard_gates()
	_test_guard_stun_holds_posture_block_string()
	_test_guard_break_hits_through_hitstun()
	_test_throw_combination_recognition_and_start()
	_test_throw_single_key_wait_anchor()
	_test_throw_combination_extra_key_and_state()
	_test_throw_hold_overlap_rules()
	_test_throw_lifecycle_result_both_facings()
	_test_throw_tech_window_boundaries()
	_test_throw_disabled_states()
	_test_throw_range_failure_observable()
	_test_throw_hitstop_intent_attempts_once()
	_test_dash_two_taps_trigger_duration_and_free_return()
	_test_dash_hold_and_pattern_rules()
	_test_dash_restricted_states()
	_test_dash_mirror_both_facings()
	_test_dash_action_locks_and_hit_interrupt()
	_test_starter_grade_locks_on_first_hit_only()
	_test_three_layer_corrections_accumulate()
	_test_normal_5D_has_no_reverse_5B()
	_test_link_failure_reasons_readable()
	_test_crouch_normals_select_by_down_state()
	_test_crouch_rapid_repress_without_direction_reentry()
	_test_crouch_chain_route_2A_2B()
	_test_stand_chains_into_crouch_5A_2B_5B_2C()
	_test_2C_low_float_sweep_lifecycle()
	_test_2C_low_float_corrections_and_combo_end()
	_test_2C_whiff_no_low_float()
	_test_2C_airborne_target_miss_no_profile()
	_test_2C_then_5D_fails_and_no_otg()
	_test_dummy_guard_request_drives_posture()
	_test_dummy_guard_rejections_observable()
	_test_player_attack_blocked_independent_result()
	_test_dummy_guard_attribute_leak_matrix()
	_test_blocked_contact_opens_chain_and_special_cancels()
	_test_blocked_denies_hit_confirm_and_jump_cancel()
	_test_whiff_still_cannot_cancel()
	_test_blockstun_locks_dummy_actions_and_holds_guard()
	_test_blocked_then_guard_release_hits_fresh()
	_test_undeclared_block_fields_default_deny()
	_test_blocked_freeze_uses_declared_frames()
	_test_rekka_window_requires_contact_hit_block_whiff()
	_test_rekka_first_press_locks_branch()
	_test_rekka_window_expiry_keeps_throw_rules_outside()
	_test_rekka_b_ground_knockdown_airborne_extension_and_link()
	_test_rekka_c_ground_knockdown_and_airborne_spike()
	_test_rekka_starter_and_corrections_across_rekka()
	_test_rekka_blocked_derivation_only_block_result()
	_test_rekka_only_moves_not_input_startable()
	_test_236c_two_segments_windows_events_and_states()
	_test_236c_seg1_blocked_terminates_whole_move()
	_test_236c_seg1_whiff_seg2_ground_slide_lifecycle()
	_test_special_d_entry_pickup_and_5b_link()
	_test_special_d_entry_from_seg1_hit_skips_seg2()
	_test_special_d_entry_expired_window_is_independent()
	_test_slide_pickup_requires_explicit_slide_profile()
	_test_slide_survives_whiffed_pickup()
	_test_slide_corrections_and_starter_lock()
	_test_a_starter_slide_cycle_breaks()
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
	_check(not session.player_crouching, "player starts standing")
	_check(session.player_guard == CombatSession.GuardPosture.NONE, "player starts unguarded")
	_check(session.player_guard_stun_left == 0 and session.player_hitstun_left == 0, "player starts without guard stun or hitstun")
	_check(session.dummy_move_id == "" and session.dummy_phase == CombatSession.PlayerPhase.NEUTRAL, "dummy starts without an attack")


func _test_attack_phase_windows() -> void:
	var session := CombatSession.new()
	var phases: Array[int] = []
	var rect_during_move := false
	for i in range(25):
		session.step(FrameInput.make(0, false, "A" if i == 0 else ""))
		phases.append(session.player_phase)
		rect_during_move = rect_during_move or session.player_attack_rect().has_area()
	_check(_phase_range(phases, 0, 3, CombatSession.PlayerPhase.STARTUP), "startup covers frames 1-4 after press")
	_check(_phase_range(phases, 4, 7, CombatSession.PlayerPhase.ACTIVE), "active covers frames 5-8 after press")
	_check(_phase_range(phases, 8, 17, CombatSession.PlayerPhase.RECOVERY), "recovery covers frames 9-18 after press")
	_check(phases[18] == CombatSession.PlayerPhase.NEUTRAL, "move ends exactly after startup+active+recovery frames")
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
	# 命中后 8 帧 Hitstop（第 7–14 帧）+ A 起手时间修正后的 9 帧地面硬直（floor(14×0.70)）：
	# 第 23 帧自然受身（普通地面命中保持接地）。
	_check(recovered_frames.size() == 1 and recovered_frames[0] == 6 + GameParams.HITSTOP_FRAMES + 9, "dummy recovers after the freeze plus A-starter-scaled hitstun frames (stays grounded throughout)")
	_check(_approx(session.dummy_hp, GameParams.DUMMY_MAX_HP - 5.8), "hit applies the A-starter-scaled damage once (round0.1(8×0.72) = 5.8)")


func _test_one_hit_per_swing() -> void:
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var events := _swing(session)
	_check(_count_events(events, CombatEvent.Type.HIT) == 1, "whole active window produces a single hit")
	_check(_approx(session.dummy_hp, GameParams.DUMMY_MAX_HP - 5.8), "damage applied exactly once per swing")


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
	_set_probe_stun(move, 5)
	var session := CombatSession.new({"5A": move})
	session.dummy_position = session.player_position + Vector2(70, 0)
	var hit_frames: Array[int] = []
	var recovered_frames: Array[int] = []
	var phase_after := {}
	for frame in range(1, 30):
		var events := session.step(FrameInput.make(0, false, "A" if frame == 1 else ""))
		phase_after[frame] = session.player_phase
		for event in events:
			if event.type == CombatEvent.Type.HIT:
				hit_frames.append(frame)
			elif event.type == CombatEvent.Type.DUMMY_RECOVERED:
				recovered_frames.append(frame)
	_check(hit_frames == [3], "custom move hits on its own first active frame")
	_check(session.dummy_hp == GameParams.DUMMY_MAX_HP - 7, "custom move applies its own base damage")
	# 命中（第 3 帧）后的 8 帧停顿冻结招式推进：恢复（第 12 帧）后判定/后摇帧继续。
	_check(phase_after[2] == CombatSession.PlayerPhase.ACTIVE and phase_after[13] == CombatSession.PlayerPhase.RECOVERY, "custom windows drive phase transitions around the freeze")
	_check(phase_after[17] == CombatSession.PlayerPhase.NEUTRAL, "custom move ends after its own total frames plus the frozen ones")
	_check(recovered_frames == [15], "custom hitstun counts down after the freeze (hit 3, freeze 4-11, D-starter scaled floor(5×0.96)=4 ticks 12-15)")


func _test_hitstun_recovery() -> void:
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	_swing_start(session)
	for i in range(5):
		session.step(FrameInput.new())
	# 第 6 帧（首个判定帧）命中。普通地面命中保持接地（profile 垂直速度显式 0），
	# 硬直只在停顿后的正常帧倒数。
	_check(session.dummy_state == CombatSession.DummyState.GROUND_HITSTUN, "dummy enters ground hitstun on hit")
	_check(session.dummy_on_ground, "ground hit keeps the dummy grounded (no implicit liftoff)")
	_check(session.dummy_hitstun_left == 9, "hitstun starts at the A-starter time-scaled ground stun frames (floor(14×0.70))")
	var steps_after_hit := 0
	var recovered_events := 0
	var left_ground := false
	while session.dummy_state == CombatSession.DummyState.GROUND_HITSTUN and steps_after_hit < 60:
		var events := session.step(FrameInput.new())
		steps_after_hit += 1
		recovered_events += _count_events(events, CombatEvent.Type.DUMMY_RECOVERED)
		left_ground = left_ground or not session.dummy_on_ground
	_check(session.dummy_state == CombatSession.DummyState.NEUTRAL, "hitstun reaching zero returns dummy to neutral")
	_check(not left_ground, "the dummy never leaves the ground during ground hitstun")
	_check(steps_after_hit == GameParams.HITSTOP_FRAMES + 9, "recovery lands exactly 8 frozen plus 9 A-starter-scaled stun frames after the hit")
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
	_check(is_equal_approx(session.dummy_velocity.x, 120.0 - GameParams.DUMMY_HITSTUN_FRICTION * GameParams.PHYSICS_TICK), "hit sets the A-starter trajectory-scaled knockback velocity round(160×0.75)=120 (same-frame friction applied)")
	_check(is_equal_approx(session.dummy_velocity.y, 0.0), "grounded normal hit applies no vertical velocity (profile upward is explicit 0)")
	_check(session.dummy_position.x > pos_before.x + 1.5, "dummy already moves on the hit frame (hit applies before motion)")
	_check(absf(session.dummy_position.y - pos_before.y) < 0.001, "ground hit keeps the dummy on the ground line")
	_check(session.dummy_on_ground, "dummy stays grounded on the hit frame")


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
	# 转身不清空方向历史，已开始的指令候选锁定首次相对面向（票据 06 M-04）：
	# 序列中途木桩换侧使面向翻转，旧段保持录入时的相对数字，候选的后续段仍
	# 按锁定面向折算——换边后用原面向前向完成指令；新面向前向不构成候选段。
	# 1) 地面版：面向 +1 输入 2、3 后木桩换到左侧；候选进行中参考面向锁定 +1，
	#    再下一帧世界右按锁定面向记 6——历史保持 236 并识别 236C。
	var turn := CombatSession.new()
	turn.dummy_position = turn.player_position + Vector2(70, 0)
	turn.step(FrameInput.make(0, false, "", true))
	turn.step(FrameInput.make(1, false, "", true))
	turn.dummy_position = Vector2(turn.player_position.x - 70.0, GameParams.ground_stand_y())
	turn.step(FrameInput.new())
	_check(turn.player_facing == -1, "facing turned toward the moved dummy before the command ends")
	turn.step(FrameInput.make(1, false, "C"))
	## C 的组合等待（issue 17 表内含投）：配对窗口末帧（+3f）按单键处理，
	## 识别锚点仍是按下帧——跨转身历史照常消费。
	_run_neutral(turn, 3)
	_check(String(turn.debug_snapshot()["direction_sequence"]) == "", "the recognized 236C consumed the cross-turn history")
	_check(turn.player_move_id == "236C", "the command completed across the turn still recognizes 236C")
	var turn_hits := _run_neutral(turn, 30)
	_check(turn_hits == 2, "the cross-turn 236C executes and hits with both segments")
	# 1b) 负例：换边后按新面向前向（世界左）不构成候选段——折为 4，236 断链，
	#     不以新面向重解释已开始的候选。
	var wrong := CombatSession.new()
	wrong.dummy_position = wrong.player_position + Vector2(70, 0)
	wrong.step(FrameInput.make(0, false, "", true))
	wrong.step(FrameInput.make(1, false, "", true))
	wrong.dummy_position = Vector2(wrong.player_position.x - 70.0, GameParams.ground_stand_y())
	wrong.step(FrameInput.new())
	wrong.step(FrameInput.make(-1, false, "C"))
	_run_neutral(wrong, 4)
	_check(String(wrong.debug_snapshot()["direction_sequence"]) == "234", "the new-facing forward folds as 4 and breaks the started candidate")
	_check(wrong.player_move_id != "236C", "the candidate is not reinterpreted with the new facing")
	# 2) 空跳落地版：跳跃后段按面向 +1 录得 2、3（保持方向窗口内），落地帧前
	#    木桩已在左侧——落地完成面向翻 -1，但候选锁定面向仍为 +1，下一帧世界
	#    右按锁定面向记 6 并按 C：旧 2/3 不清空、不反转，跨落地转身组成 236C。
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
	land.step(FrameInput.make(1, false, "C"))
	_run_neutral(land, 3)
	_check(land.player_move_id == "236C", "the post-landing world-right 6 completes 236C under the locked candidate facing")


func _test_qcf_qcb_work_in_both_facings() -> void:
	# 左右面向使用同一套相对方向输入（issue 12）：236C 与 214C 在两侧面向的
	# 地面中立均能识别并执行；后退后的方向历史不再因移动翻转而失败。
	# 右面向 214C：木桩在右，S → S+A → A+K（世界左 = 后）。C 是投组合成员键
	# （表内含 BC 投）：单键在配对窗口末帧（+3f）起手，脚本补 3 帧（票据 10：
	# 旧地面 214D 移除后，214 后撤指令的识别主体迁移至 214C）。
	var right_qcb := CombatSession.new()
	right_qcb.dummy_position = right_qcb.player_position + Vector2(70, 0)
	var right_qcb_hits := _play_script(right_qcb, [
		[0, true, ""], [-1, true, ""], [-1, false, "C"],
		[0, false, ""], [0, false, ""], [0, false, ""],
	])
	_check(right_qcb.player_move_id == "214C", "ground-neutral 214 starts 214C while facing right")
	right_qcb_hits += _run_neutral(right_qcb, 30)
	_check(right_qcb_hits == 1, "the backward quarter circle connects as a single hit while facing right")
	# 左面向 236C：木桩在左，先走向木桩使面向 -1，S → S+A → A+K（世界左 = 前）。
	# C 是投组合成员键（表内含 BC 投）：单键在配对窗口末帧（+3f）起手，脚本补 3 帧。
	var left_qcf := CombatSession.new()
	left_qcf.dummy_position = left_qcf.player_position - Vector2(70, 0)
	var left_qcf_hits := _play_script(left_qcf, [
		[-1, false, ""], [-1, false, ""],
		[0, true, ""], [-1, true, ""], [-1, false, "C"],
		[0, false, ""], [0, false, ""], [0, false, ""],
	])
	_check(left_qcf.player_move_id == "236C", "mirror 236 starts 236C while facing left")
	left_qcf_hits += _run_neutral(left_qcf, 30)
	_check(left_qcf_hits == 2, "the mirror quarter circle connects with both 236C segments while facing left")
	# 左面向 214C：木桩在左，S → S+D → D+K（世界右 = 后）。
	var left_qcb := CombatSession.new()
	left_qcb.dummy_position = left_qcb.player_position - Vector2(70, 0)
	var left_qcb_hits := _play_script(left_qcb, [
		[-1, false, ""], [-1, false, ""],
		[0, true, ""], [1, true, ""], [1, false, "C"],
		[0, false, ""], [0, false, ""], [0, false, ""],
	])
	_check(left_qcb.player_move_id == "214C", "mirror 214 starts 214C while facing left")
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
		[0, false, ""], [0, false, ""], [0, false, ""],
	])
	_check(right.player_move_id == "236C", "236 toward the dummy works right after walking back")
	right_hits += _run_neutral(right, 30)
	_check(right_hits == 2, "the after-walkback 236C connects with both segments")
	# 左面向镜像：按 D 后退（世界右、远离木桩），再 S → S+A → A+K。
	var left := CombatSession.new()
	left.dummy_position = left.player_position - Vector2(70, 0)
	var left_hits := _play_script(left, [
		[1, false, ""], [1, false, ""], [1, false, ""], [1, false, ""],
		[0, false, ""],
		[0, true, ""], [-1, true, ""], [-1, false, ""], [-1, false, "C"],
		[0, false, ""], [0, false, ""], [0, false, ""],
	])
	_check(left.player_move_id == "236C", "mirror 236 toward the dummy works right after walking back")
	left_hits += _run_neutral(left, 30)
	_check(left_hits == 2, "the mirror after-walkback 236C connects with both segments")


func _test_air_direction_derivation_resolves_by_locked_facing() -> void:
	# 空中方向派生（issue 12）：空中方向历史按锁定面向折算，配置的空中派生
	# （注入表的 j214D）能被识别并执行；镜像一致；未识别回落为无派生空中招式，
	# 识别但不可接续、成功出招但未命中三种结果可区分。
	# 1) 成功出招但未命中：右面向前跳（木桩在远处），空中 S → S+A → A → D。
	#    （起跳准备 4f 后离地，214 在空中段输入。）
	var whiff := CombatSession.new(_air_derivation_table())
	whiff.dummy_position = Vector2(900.0, GameParams.ground_stand_y())
	whiff.step(FrameInput.make(1, true))
	_run_neutral(whiff, 4)
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
	_run_neutral(mirror, 4)
	_play_script(mirror, [
		[0, true, ""], [1, true, ""], [1, false, "D"],
	])
	_check(mirror.player_move_id == "j214D", "mirror air 214 with the locked facing starts j214D")
	# 3) 未识别（方向序列不匹配）：空中 2→3→6 + D 回落为无派生 jD。
	var mismatch := CombatSession.new(_air_derivation_table())
	mismatch.dummy_position = Vector2(900.0, GameParams.ground_stand_y())
	mismatch.step(FrameInput.make(1, true))
	_run_neutral(mismatch, 4)
	_play_script(mismatch, [
		[0, true, ""], [1, true, ""], [1, false, ""], [1, false, "D"],
	])
	_check(mismatch.player_move_id == "jD", "air 236 falls back to the plain air move for the key (derivation not matched)")
	# 4) 识别但不可接续：jA 执行中搓 214 + D——派生被识别并缓存，但当前招式
	#    不能取消、落地后空中姿态不再匹配，缓存过期作废，全程不起手 j214D。
	var stuck := CombatSession.new(_air_derivation_table())
	stuck.dummy_position = Vector2(900.0, GameParams.ground_stand_y())
	stuck.step(FrameInput.make(1, true))
	_run_neutral(stuck, 4)
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
	# 面向与攻击方向（票据 06 M-04 修订 issue 12 旧规则）：面向每个物理帧在
	# 运动结算后按横向关系更新；当前招式的攻击方向锁定在启动面向，不因换边
	# 反向；空中越桩同样翻转面向，落地后保持朝向木桩。
	# 1) 地面出招期间木桩换到另一侧：面向翻转，但本招 hitbox 仍朝启动方向。
	var ground_move := CombatSession.new()
	ground_move.dummy_position = Vector2(900.0, GameParams.ground_stand_y())
	ground_move.step(FrameInput.make(0, false, "A"))
	var attack_dir_locked := ground_move.player_attack_rect().position.x > ground_move.player_position.x
	ground_move.dummy_position = Vector2(50.0, GameParams.ground_stand_y())
	var move_facing_flipped := false
	for i in range(18):
		ground_move.step(FrameInput.new())
		move_facing_flipped = move_facing_flipped or ground_move.player_facing == -1
		if ground_move.player_move_id != "":
			attack_dir_locked = attack_dir_locked and ground_move.player_attack_rect().position.x > ground_move.player_position.x
	_check(move_facing_flipped, "facing follows the dummy's side change during the ground move (M-04)")
	_check(attack_dir_locked, "the move's attack direction stays locked to its startup facing")
	ground_move.step(FrameInput.new())
	_check(ground_move.player_facing == -1, "free action re-faces the dummy after the move recovers")
	# 2) 空中越过木桩（显式中间状态：升空中、向前水平速度、面向 +1、木桩在
	#    前下方；高度取在身体垂直重叠带之上）：越过横向位置后的下一帧面向
	#    翻转（M-04：空中不锁死面向）；起跳水平速度不受翻转影响。
	var crossing := CombatSession.new()
	crossing.dummy_position = crossing.player_position + Vector2(100.0, 0.0)
	crossing.player_on_ground = false
	crossing.player_velocity = Vector2(1000.0, 0.0)
	crossing.player_position.y -= 100.0
	var crossed := false
	var facing_flipped_after_cross := false
	var landed_facing := 0
	for i in range(60):
		crossing.step(FrameInput.new())
		if not crossing.player_on_ground:
			if crossing.player_position.x > crossing.dummy_position.x:
				if crossed and crossing.player_facing == -1:
					facing_flipped_after_cross = true
				crossed = true
		else:
			landed_facing = crossing.player_facing
			break
	_check(crossed, "the player sails past the dummy's horizontal position mid-air")
	_check(facing_flipped_after_cross, "crossing the dummy mid-air flips the facing on the next frame (M-04)")
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
	for i in range(3):
		session.step(FrameInput.new())
	_check(session.player_on_ground, "player stays grounded through all four pre-jump frames")
	session.step(FrameInput.new())
	_check(not session.player_on_ground, "player leaves the ground on the first frame after pre-jump")
	_check(session.player_position.y < GameParams.ground_stand_y(), "player rises on the first airborne frame")
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
	for i in range(4):
		session.step(FrameInput.make(1))
	var takeoff_vx := session.player_velocity.x
	_check(takeoff_vx > 300.0, "backward jump takes off at walking speed")
	for i in range(33):
		session.step(FrameInput.make(-1))
	_check(not session.player_on_ground, "player is still airborne while holding reverse")
	_check(is_equal_approx(session.player_velocity.x, takeoff_vx), "holding reverse in the air keeps the takeoff horizontal velocity")
	_check(session.player_facing == -1, "holding reverse in the air never flips the takeoff facing")
	for i in range(12):
		session.step(FrameInput.make(-1))
	_check(session.player_on_ground, "player still lands normally after holding reverse mid-air")

	var release := CombatSession.new()
	release.dummy_position = Vector2(100.0, GameParams.ground_stand_y())
	for i in range(20):
		release.step(FrameInput.make(1))
	release.step(FrameInput.make(1, true))
	for i in range(4):
		release.step(FrameInput.make(1))
	var release_takeoff := release.player_velocity.x
	for i in range(33):
		release.step(FrameInput.new())
	_check(not release.player_on_ground, "player is still airborne after releasing horizontal input")
	_check(is_equal_approx(release.player_velocity.x, release_takeoff), "releasing horizontal input mid-air keeps the takeoff velocity (no air friction decay)")
	_check(release.player_facing == -1, "facing stays unchanged after releasing mid-air")


func _test_air_action_without_air_move_ignored() -> void:
	# 招式表只配置地面招式：空中按下动作键不会起手，缓存也不会被消费。
	# （默认表已配置 jA，空中 A 的起手行为由 jump cancel 测试覆盖。）
	var session := CombatSession.new(_fast_single_move_table())
	session.step(FrameInput.make(0, true))
	for i in range(4):
		session.step(FrameInput.new())
	_check(not session.player_on_ground, "the jump reaches the air phase right after pre-jump")
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
	_check(_approx(session.dummy_hp, GameParams.DUMMY_MAX_HP - 11.6), "repeat attacks keep reducing hp (two fresh A-starter combos, 5.8 each)")


func _test_hp_clamps_at_zero() -> void:
	var session := CombatSession.new()
	session.dummy_hp = 5.0
	session.dummy_position = session.player_position + Vector2(70, 0)
	_swing(session)
	_check(session.dummy_hp == 0.0, "hp clamps at zero instead of going negative")


func _test_mash_does_not_cancel_mid_move() -> void:
	# 连打 A：出招中与后摇中的输入只进缓存；A 不是 5A 的取消目标，
	# 不能中途取消。收招当帧（含停顿延长的收招）缓存中的 A 立刻起手下一记独立 5A。
	# 站位 60px：A 起手轨迹修正后的击退（120px/s）不至于把木桩推出第二记 5A 的射程。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(60, 0)
	var hits_by_end_of_first_move := 0
	for frame in range(1, 32):
		var events := session.step(FrameInput.make(0, false, "A"))
		hits_by_end_of_first_move += _count_events(events, CombatEvent.Type.HIT)
		if frame < 30:
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
	# 5B 于 F9 起手，其前摇穿过 5A 命中的 8 帧停顿：F21 才命中。
	for frame in range(10, 22):
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
	# 单槽缓存：先 D 后 B，只有最新的 B 被消费。B 是投组合成员键（表内含投）：
	# 等待在停顿内到期（F4+3=F7），5A 命中（F6）后停顿 F7–F14，恢复首帧 F15
	# 以取消消费 5B。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var move_ids: Array[String] = []
	for frame in range(1, 17):
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
	# 稳定地面路线 5A → 5B → 5D：后续招式在命中接触后经链式取消窗口接上。
	# B/C 是投组合成员键（表内含 BC 投，issue 17）：B@F5 的等待在停顿内到期，
	# 5A 命中（F6）后停顿 F7–F14，恢复首帧 F15 以链式取消（年龄 1 ≤ 3）消费起手
	# 5B；5B 于 F21 命中，同帧 D 链式取消起手 5D（D 不参与组合、不等待），F37 命中。
	# 5D 不再是收尾：连段由木桩自然受身结束（F53）。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var events: Array[CombatEvent] = []
	var move_after_frame := {}
	var combo_end_frames: Array[int] = []
	var link_fails := 0
	for frame in range(1, 61):
		var frame_events := session.step(FrameInput.make(0, false, _script_key({1: "A", 5: "B", 21: "D"}, frame)))
		events.append_array(frame_events)
		move_after_frame[frame] = session.player_move_id
		if _combo_end_events(frame_events, CombatEvent.ComboEndReason.DUMMY_RECOVERED) > 0:
			combo_end_frames.append(frame)
		link_fails += _count_events(frame_events, CombatEvent.Type.LINK_FAILED)
	var hits := _events_of(events, CombatEvent.Type.HIT)
	_check(hits.size() == 3, "ground route lands all three hits")
	# 命中当帧 D（非组合键）以链式取消（年龄 0）起手 5D；停顿顺延后续物理帧。
	_check(move_after_frame[1] == "5A" and move_after_frame[15] == "5B" and move_after_frame[21] == "5D", "route follows 5A -> 5B -> 5D via chain cancels")
	_check(hits.size() == 3 and hits[0].combo_hits == 1 and hits[1].combo_hits == 2 and hits[2].combo_hits == 3, "hit events count combo hits in order")
	if hits.size() == 3:
		_check(_approx(hits[0].damage, 5.8), "first hit applies the A-starter damage scale (round0.1(8×0.72))")
		_check(_approx(hits[1].damage, 7.8), "second hit deals 12 × 0.72×0.90")
		_check(_approx(hits[2].damage, 10.5), "third hit deals 18 × 0.72×0.90×0.90")
	_check(_approx(session.combo_total_damage, 24.1), "combo total damage accumulates the three-layer values")
	_check(_approx(session.dummy_hp, GameParams.DUMMY_MAX_HP - 24.1), "dummy hp reflects the corrected route damage")
	_check(_approx(session.combo_last_scale, 0.5832), "last hit scale is the accumulated damage layer 0.72×0.9×0.9")
	_check(link_fails == 0, "no link failures occur on the cancel route")
	_check(combo_end_frames == [52], "combo ends once when the dummy naturally recovers (F52)")
	_check(not session.combo_active and session.combo_hits == 3, "combo ends at three hits after the dummy recovers")
	_check(session.dummy_state == CombatSession.DummyState.NEUTRAL, "dummy is neutral again after natural recovery")
	_check(session.combo_hits == 3, "combo hit count is preserved after the combo ended")


func _test_cancel_window_last_frame() -> void:
	# 取消窗口按正常帧计龄：停顿中（年龄暂停）输入的 B 在配对窗口内到期
	# （F11+3=F14，仍在停顿中），恢复首个正常帧（F15，年龄 0）消费取消；
	# 5B 前摇穿过停顿后在 F19 命中。年龄 8 的最后有效输入帧由
	# _test_cancel_age_counts_normal_frames 单独覆盖。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	for frame in range(1, 16):
		session.step(FrameInput.make(0, false, _script_key({1: "A", 11: "B"}, frame)))
	_check(session.combo_hits == 1, "5A hits on frame 6")
	_check(session.player_move_id == "5B", "input during the freeze is consumed as a cancel on the first normal frame")
	for frame in range(16, 29):
		session.step(FrameInput.new())
	_check(session.combo_hits == 2, "the canceled 5B still lands after the freeze-extended startup")


func _test_cancel_window_close_ends_combo() -> void:
	# 链式取消窗口（0–3）早已关闭；B 在 5A 后段按下、组合等待在恢复前解除，
	# 作为普通连接候选在 5A 完全恢复当帧（F27）评估：木桩已于 F23 自然受身
	# （连段随之结束），目标已恢复 → LINK_FAILED(TARGET_RECOVERED)。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var end_frames: Array[int] = []
	var link_events: Array[CombatEvent] = []
	for frame in range(1, 32):
		var events := session.step(FrameInput.make(0, false, _script_key({1: "A", 23: "B"}, frame)))
		if _combo_end_events(events, CombatEvent.ComboEndReason.DUMMY_RECOVERED) > 0:
			end_frames.append(frame)
		for event in events:
			if event.type == CombatEvent.Type.LINK_FAILED:
				link_events.append(event)
	_check(end_frames == [23], "the combo ends when the dummy naturally recovers before the attacker (F23)")
	_check(link_events.size() == 1 and link_events[0].link_fail_reason == CombatEvent.LinkFailReason.TARGET_RECOVERED \
		and link_events[0].link_move_id == "5B" and not session.combo_active,
		"the late buffered 5B is a declared link edge and fails with the readable TARGET_RECOVERED reason on the recovery frame")
	_check(session.player_move_id == "", "input after the cancel window cannot cancel the move")
	_check(session.combo_hits == 1 and not session.combo_active, "combo stops at one hit")


func _test_independent_move_cannot_hit_stunned_dummy() -> void:
	# 没有合法取消资格的独立招式不能绕过取消条件追击仍在受击中的木桩；
	# 木桩自然恢复后才能以新一段连段重新命中。
	# 停顿顺延：命中 F3、停顿 F4–F11、硬直自 F12 起消耗（F41 自然受身），
	# 停顿中按下的 A 在恢复帧 F12 缓存、F15 收招后起手第二记独立 5A。
	var session := CombatSession.new(_fast_single_move_table())
	session.dummy_position = session.player_position + Vector2(70, 0)
	var events: Array[CombatEvent] = []
	for frame in range(1, 16):
		events.append_array(session.step(FrameInput.make(0, false, _script_key({1: "A", 8: "A"}, frame))))
	_check(_count_events(events, CombatEvent.Type.HIT) == 1, "second independent swing cannot hit the stunned dummy")
	_check(session.dummy_hp == GameParams.DUMMY_MAX_HP - 10.0, "hp only drops once before recovery")
	_check(session.combo_hits == 1 and not session.combo_active, "combo ends without extending through an independent move")
	for frame in range(13, 60):
		events.append_array(session.step(FrameInput.make(0, false, _script_key({45: "A"}, frame))))
	_check(_count_events(events, CombatEvent.Type.HIT) == 2, "a fresh swing hits after the dummy naturally recovers")
	_check(session.combo_hits == 1 and _approx(session.combo_total_damage, 10.0), "new combo restarts counting at one hit and full scale")


func _test_damage_floor_and_no_hit_cap() -> void:
	# 双招互相取消的自定义表：每次命中触发 8 帧停顿，长硬直木桩不恢复，
	# 没有人为命中数上限。D 起手倍率 1.00、普通命中每击 0.90：第 n 击 =
	# base × 0.9^(n-1)，独立舍入；命中招式序列由回放记录，期望值按同序列推导。
	var table := _loop_table()
	var session := CombatSession.new(table)
	session.dummy_position = session.player_position + Vector2(70, 0)
	var events: Array[CombatEvent] = []
	var hit_move_ids: Array[String] = []
	for frame in range(1, 210):
		var key := ""
		if frame == 1:
			key = "A"
		elif frame >= 3 and (frame - 3) % 10 == 0:
			key = "B" if ((frame - 3) / 10) % 2 == 0 else "A"
		var frame_events := session.step(FrameInput.make(0, false, key))
		events.append_array(frame_events)
		if _count_events(frame_events, CombatEvent.Type.HIT) > 0:
			hit_move_ids.append(session.player_move_id)
	for i in range(3):
		events.append_array(session.step(FrameInput.new()))
	var hits := _events_of(events, CombatEvent.Type.HIT)
	_check(hits.size() == 21, "looped cancels land a hit on every cycle with no hit cap")
	_check(session.combo_hits == 21, "session counts every combo hit")
	var expected_total := 0.0
	var scale := 1.0
	for i in range(hit_move_ids.size()):
		var base := float((table[hit_move_ids[i]] as MoveData).base_damage)
		var expected_damage := snappedf(base * maxf(GameParams.COMBO_DAMAGE_FLOOR, scale), 0.1)
		_check(_approx(hits[i].damage, expected_damage), "hit %d (%s) damage follows the three-layer model" % [i + 1, hit_move_ids[i]])
		expected_total = snappedf(expected_total + expected_damage, 0.1)
		scale *= GameParams.NORMAL_HIT_DAMAGE_SCALE
	_check(_approx(session.combo_total_damage, expected_total), "combo total matches the layered model (floor not reached within 21 hits)")
	_check(session.combo_damage_scale > GameParams.COMBO_DAMAGE_FLOOR, "damage layer stays above the 10% floor within 21 hits")
	_check(session.combo_active, "combo keeps going while the dummy never recovers")


func _test_direction_window_age_boundary() -> void:
	# 窗口按实际 variant 步数计（issue 13）：214 为三步 × 10 = 30 帧，含首段帧。
	# 票据 10 起识别主体为 214C（旧地面 214D 已移除）：C 是投组合成员键，但方向
	# 解析发生在按下当帧（缓存行即刻显示 214C），配对等待只推迟起手 3 帧——
	# 窗口口径仍是「按下当帧的首段年龄」：F1–F3 输入 214，F30 按 C（年龄 29）仍
	# 识别、F33 起手；F31 按（年龄 30）过期回落 5C（F34 起手）。
	# 左右面向成功/失败帧一致（左面向用下、下右、右的物理镜像）。
	var session := CombatSession.new()
	for frame in range(1, 31):
		session.step(_qcb_input(frame, 30, "C"))
	_pairing_wait(session)
	_check(session.player_move_id == "214C", "three-step command pressed at age 29 (F30) is the last valid boundary")
	var late_session := CombatSession.new()
	for frame in range(1, 32):
		late_session.step(_qcb_input(frame, 31, "C"))
	_pairing_wait(late_session)
	_check(late_session.player_move_id == "5C", "age 30 (F31) expires before the key press and falls back to the plain move")
	var mirror := CombatSession.new()
	mirror.dummy_position = mirror.player_position + Vector2(-200, 0)
	mirror.step(FrameInput.new())
	for digit in [2, 1, 4]:
		mirror.step(_relative_input(mirror, digit))
	for i in range(26):
		mirror.step(FrameInput.new())
	mirror.step(_relative_input(mirror, 5, "C"))
	_pairing_wait(mirror)
	_check(mirror.player_move_id == "214C", "left-facing mirror keeps the same success frame (press F31 at age 29)")
	var mirror_late := CombatSession.new()
	mirror_late.dummy_position = mirror_late.player_position + Vector2(-200, 0)
	mirror_late.step(FrameInput.new())
	for digit in [2, 1, 4]:
		mirror_late.step(_relative_input(mirror_late, digit))
	for i in range(27):
		mirror_late.step(FrameInput.new())
	mirror_late.step(_relative_input(mirror_late, 5, "C"))
	_pairing_wait(mirror_late)
	_check(mirror_late.player_move_id == "5C", "left-facing mirror keeps the same failure frame (press F32 at age 30)")


func _test_direction_sequence_consumed_after_lock() -> void:
	# 识别 236C 的当帧消费整段方向历史并锁定招式：没有新方向前，再按 C 只得到普通 5C。
	# C 是投组合成员键（表内含投）：按下帧识别、配对窗口末帧（F7）起手。
	# 票据 05 起 236C 全长 35 帧（F7 起手 → F41 收招）。
	var session := CombatSession.new()
	for frame in range(1, 8):
		session.step(_qcf_input(frame, 4, "C"))
	_check(session.player_move_id == "236C", "236 followed by C locks the derivative at the pairing-window end with the press-frame anchor")
	for frame in range(8, 45):
		session.step(FrameInput.new())
	_check(session.player_phase == CombatSession.PlayerPhase.NEUTRAL, "derivative move finishes its full recovery")
	session.step(FrameInput.make(0, false, "C"))
	_run_neutral(session, 3)
	_check(session.player_move_id == "5C", "second C without fresh directions resolves the plain move, not another derivative")


func _test_directions_never_start_moves_or_use_buffer() -> void:
	# 方向输入不占用动作键缓存：只输方向时不会起手任何招式，随后的动作键照常起手。
	var session := CombatSession.new()
	for frame in range(1, 11):
		session.step(_qcf_input(frame, -1, ""))
	_check(session.player_phase == CombatSession.PlayerPhase.NEUTRAL and session.player_move_id == "", "direction input alone never starts a move")
	session.step(FrameInput.make(0, false, "A"))
	_check(session.player_move_id == "6A", "action buffer stays untouched by direction input: the A press starts a move, routed to the 6+A special by the forward-tail segment (priority over plain 5A)")


func _test_slow_direction_beats_action_buffer_window() -> void:
	# 方向识别只受独立 24 帧窗口限制：236 跨 19 帧输入（远超 6 帧动作缓存）仍能触发派生。
	# C 是投组合成员键：锚点仍在 F20，起手顺延到配对窗口末帧 F23。
	var session := CombatSession.new()
	for frame in range(1, 24):
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
	# C 是投组合成员键（表内含投）：判定帧顺延 3f 到配对窗口末帧。
	var inserted := CombatSession.new()
	_run_relative(inserted, [[2], [3], [4], [6, "C"]])
	_run_neutral(inserted, 3)
	_check(inserted.player_move_id == "5C", "inserting 4 between 236 breaks the strict match")
	var post := CombatSession.new()
	_run_relative(post, [[2], [3], [6], [4, "C"]])
	_run_neutral(post, 3)
	_check(post.player_move_id == "5C", "post-endpoint 4 breaks the strict 236C candidate")
	var no_super := CombatSession.new()
	_run_relative(no_super, [[2], [3], [6], [2], [6, "C"]])
	_run_neutral(no_super, 3)
	_check(no_super.player_move_id == "5C", "23626 is not auto-derived from plain 236C")
	var lead := CombatSession.new()
	_run_relative(lead, [[4], [4], [2], [3], [6, "C"]])
	_run_neutral(lead, 3)
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
	# 浮空语义在新基线由专用 launcher 6A 承担（票据 05 起 236C 迁移为两段判定，
	# 不再配置 jump cancel）：6A 命中把木桩置入浮空受击；取消窗关闭先断连，浮空
	# 受身（硬直归零）与落地恢复中立是两个独立可观察时刻。C 起手三层修正：
	# 伤害 ×0.93、时间 ×0.90、轨迹 ×0.92（untech floor(36×0.90)=32、
	# 起跳 round(560×0.92)=515 px/s → 滞空 44 帧）。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var events: Array[CombatEvent] = []
	var hit_frame := -1
	## 6A：F1 持前方向、F2 按 A（优先级高于 5A）→ F2 起手，首个判定帧 F10 命中。
	for frame in range(1, 11):
		var frame_events := session.step(FrameInput.make(1 if frame == 1 else 0, false, "A" if frame == 2 else ""))
		events.append_array(frame_events)
		if _count_events(frame_events, CombatEvent.Type.HIT) > 0:
			hit_frame = frame
	_check(hit_frame == 10, "6A hits on its first active frame")
	_check(session.dummy_state == CombatSession.DummyState.AIR_HITSTUN, "launcher hit puts the dummy into float hitstun")
	_check(not session.dummy_on_ground, "dummy lifts off on the launcher hit")
	_check(session.dummy_hitstun_left == 32, "float hitstun starts at the C-starter time-scaled length (floor(36×0.90))")
	_check(_approx(session.dummy_hp, GameParams.DUMMY_MAX_HP - 14.9), "6A applies its base damage at C-starter scale (round0.1(16×0.93)=14.9)")
	var combo_end_frames: Array[int] = []
	var tech_frame := -1
	var state_left_air_recovered := true
	var land_frame := -1
	for frame in range(11, 84):
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
	_check(combo_end_frames == [hit_frame + GameParams.HITSTOP_FRAMES + GameParams.CANCEL_WINDOW_FRAMES + 1], "combo ends when the cancel window closes while the dummy still floats (frozen frames do not age it)")
	_check(tech_frame == hit_frame + GameParams.HITSTOP_FRAMES + 32, "float hitstun runs out exactly the scaled untech frames after the hit (the freeze pauses it)")
	_check(land_frame == 63, "dummy lands after the air tech on the trajectory-scaled arc (round(560×0.92)=515 px/s)")
	_check(state_left_air_recovered, "dummy only returns to neutral on landing after the air tech")
	_check(_count_events(events, CombatEvent.Type.DUMMY_RECOVERED) == 1, "recovery event fires exactly once at landing, not at the tech")
	_check(_count_events(events, CombatEvent.Type.COMBO_ENDED) == 1, "no second combo-end is emitted at the tech after the window already closed")


func _test_air_tech_ends_combo_before_landing() -> void:
	# 浮空受身当帧立即结束连段（长取消窗保持连段存活到受身），落地后才恢复中立；
	# 空中已受身的木桩即使被摆回命中框内也不可追击。
	# 停顿顺延：探针 5C 于 F3 命中、F4–F11 停顿、F22 受身（3 + 8 + floor(12×0.96)=11）。
	var session := CombatSession.new(_float_probe_table())
	session.dummy_position = session.player_position + Vector2(70, 0)
	var tech_end_frames: Array[int] = []
	var tech_recovered_events := 0
	for frame in range(1, 24):
		var frame_events := session.step(FrameInput.make(0, false, "C" if frame == 1 else ""))
		if frame == 3:
			_check(_count_events(frame_events, CombatEvent.Type.HIT) == 1 and session.dummy_state == CombatSession.DummyState.AIR_HITSTUN, "probe launcher hits on frame 3 into float hitstun")
		if _combo_end_events(frame_events, CombatEvent.ComboEndReason.DUMMY_RECOVERED) > 0:
			tech_end_frames.append(frame)
		tech_recovered_events += _count_events(frame_events, CombatEvent.Type.DUMMY_RECOVERED)
	_check(tech_end_frames == [22], "air tech on the frame float hitstun runs out ends the combo immediately")
	_check(session.dummy_state == CombatSession.DummyState.AIR_RECOVERED, "dummy is air-recovered right after the tech")
	_check(not session.dummy_on_ground and session.dummy_state != CombatSession.DummyState.NEUTRAL, "dummy is still airborne and not neutral after the tech")
	_check(not session.combo_active and session.combo_hits == 1, "combo stops counting at the tech")
	_check(tech_recovered_events == 0, "no recovery event at the tech itself")
	# 受身后把木桩摆回玩家命中框内并挥出独立 5A：空中已受身期间不可追击。
	session.dummy_position = session.player_position + Vector2(70, -40)
	var probe_events: Array[CombatEvent] = []
	for frame in range(24, 32):
		probe_events.append_array(session.step(FrameInput.make(0, false, "A" if frame == 24 else "")))
	_check(_count_events(probe_events, CombatEvent.Type.HIT) == 0, "air-recovered dummy cannot be hit even inside the attack rect")
	_check(_approx(session.dummy_hp, GameParams.DUMMY_MAX_HP - 10.0), "hp is unchanged by the post-tech probe")
	var land_frame := -1
	var recovered_events := 0
	for frame in range(32, 90):
		var frame_events := session.step(FrameInput.new())
		recovered_events += _count_events(frame_events, CombatEvent.Type.DUMMY_RECOVERED)
		if land_frame == -1 and session.dummy_on_ground and session.dummy_state == CombatSession.DummyState.NEUTRAL:
			land_frame = frame
	_check(land_frame > 0, "air-recovered dummy lands and returns to neutral")
	_check(recovered_events == 1, "single recovery event fires at landing")


func _test_float_landing_keeps_remaining_hitstun() -> void:
	# 浮空硬直未耗尽就落地：转为地面受击硬直继续倒地处理，
	# 落地当帧起继续消耗，剩余帧数从落地保留到自然受身。
	# D 起手时间修正：受身计时 floor(60×0.96)=57；轨迹修正 round(560×0.96)=538
	# 使滞空 47 帧（原 560px/s 为 48），落地保留 57-47=10 帧。
	var float_hitstun := 57
	var hit_frame := 3
	var session := CombatSession.new(_long_float_table(60))
	session.dummy_position = session.player_position + Vector2(70, 0)
	var convert_frame := -1
	var convert_hitstun := -1
	var last_air_frame := -1
	var recover_frame := -1
	var recovered_events := 0
	for frame in range(1, 80):
		var frame_events := session.step(FrameInput.make(0, false, "C" if frame == 1 else ""))
		if session.dummy_state == CombatSession.DummyState.AIR_HITSTUN:
			last_air_frame = frame
		elif convert_frame == -1 and session.dummy_state == CombatSession.DummyState.GROUND_HITSTUN and session.dummy_on_ground:
			convert_frame = frame
			convert_hitstun = session.dummy_hitstun_left
		recovered_events += _count_events(frame_events, CombatEvent.Type.DUMMY_RECOVERED)
		if convert_frame != -1 and recover_frame == -1 and session.dummy_state == CombatSession.DummyState.NEUTRAL:
			recover_frame = frame
	_check(last_air_frame == hit_frame + GameParams.HITSTOP_FRAMES + 46, "float lasts 47 trajectory-scaled normal frames while hitstun remains (the freeze pauses the arc)")
	_check(convert_frame == hit_frame + GameParams.HITSTOP_FRAMES + 47 and convert_hitstun == 10, "landing converts leftover float hitstun into ground hitstun and ticks it on the landing frame")
	_check(recover_frame == hit_frame + GameParams.HITSTOP_FRAMES + float_hitstun, "converted hitstun counts down on the ground until natural recovery")
	_check(recovered_events == 1, "natural recovery emits exactly one event")


func _test_independent_move_cannot_hit_floating_dummy() -> void:
	# 浮空后续不依赖隐式普通连接：取消窗关闭后，独立招式即使够得着也追不上浮空木桩；
	# 木桩落地自然受身恢复中立后，新的独立招式才能开启下一段连段。
	# 236C（2/3/6 于 F1–F3、C@F4、F7 起手）两段命中：段 1 F13、段 2 F26（独立
	# 起手的多段招式在段 1 实际命中后按本招延续继续命中，票据 05）。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var hit_frames: Array[int] = []
	var feed := {1: [0, true], 2: [1, true], 3: [1, false], 4: [0, false, "C"], 33: [0, false, "A"], 70: [0, false, "A"]}
	for frame in range(1, 85):
		var spec: Array = feed.get(frame, [0, false])
		if frame == 33:
			# 把浮空中的木桩摆回 5A 命中框内（离地 20px、仍在浮空受击）。
			session.dummy_position = session.player_position + Vector2(70, -20)
		var frame_events := session.step(FrameInput.make(int(spec[0]), false, spec[2] if spec.size() > 2 else "", bool(spec[1])))
		if _count_events(frame_events, CombatEvent.Type.HIT) > 0:
			hit_frames.append(frame)
		if frame == 39:
			_check(session.dummy_state == CombatSession.DummyState.AIR_HITSTUN, "dummy is still in float hitstun through the independent probe")
	_check(hit_frames.size() == 3 and hit_frames[0] == 13 and hit_frames[1] == 26, "both 236C segments hit (F13/F26) and the floating dummy survives the probe")
	_check(hit_frames[2] >= 70, "fresh swing only hits again after natural recovery")
	_check(_approx(session.dummy_hp, GameParams.DUMMY_MAX_HP - 8.0 - 10.8 - 5.8), "only the two segments and the post-recovery swing deal damage")
	_check(session.combo_hits == 1, "post-recovery hit starts a fresh combo count")

func _test_5A_cancels_into_236C_relaunch() -> void:
	# 高级路线接缝：236C 是 5A 的必杀取消目标；5A 命中确认后在取消窗口内消费缓存
	# 的 236C。票据 05 起 236C 是两段判定：段 1 把地面硬直中的木桩重新打入低浮空，
	# 段 2 按独立空中资料延长浮空（A 起手累计层：段 1 时间 0.72×0.94=0.677 →
	# floor(32×0.677)=21）。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(72, 0)
	var hit_frames: Array[int] = []
	var hit_segments: Array[int] = []
	for frame in range(1, 40):
		var down := frame == 1 or frame == 2
		# 6+A 已是共享表招式（优先级高于 5A）：A 按下帧的方向段不能以 6 结尾，
		# 否则 A 键解析为 6A；236 的 6 段延后到 F5 补入，236C 仍在 F6 按下时配齐。
		var axis := 1 if frame == 2 or frame == 5 else 0
		var key := ""
		if frame == 4:
			key = "A"
		elif frame == 6:
			key = "C"
		var frame_events := session.step(FrameInput.make(axis, false, key, down))
		for event in frame_events:
			if event.type == CombatEvent.Type.HIT:
				hit_frames.append(frame)
				hit_segments.append(event.move_segment)
		if frame == 9:
			_check(session.player_move_id == "236C", "buffered 236C is consumed on 5A's hit-confirm frame (special cancel, window 0-5)")
		if frame == 23:
			_check(session.dummy_hitstun_left == 21, "segment 1 relaunches at the accumulated time scale (floor(32×0.72×0.94))")
	_check(hit_frames == [9, 23, 36] and hit_segments == [1, 1, 2], "5A hits on frame 9, then both 236C segments connect (seg1 F23, seg2 F36)")
	_check(session.combo_hits == 3 and session.combo_active, "both segments count as combo hits")
	_check(session.dummy_state == CombatSession.DummyState.AIR_HITSTUN and not session.dummy_on_ground, "the stunned grounded dummy is relaunched and kept airborne by both segments")
	_check(_approx(session.dummy_hp, GameParams.DUMMY_MAX_HP - 5.8 - 5.2 - 7.0), "route damage is 5A at A-starter scale plus both segments at the accumulated layers (8×0.648 + 12×0.583)")
	_check(_approx(session.combo_last_scale, 0.5832), "third hit damage layer is 0.72×0.90×0.90")


func _test_5B_late_214c_starts_independently() -> void:
	# 旧路线 5B→214D 已随票据 10 移除（地面 214D 不再存在；倒地收尾职责在
	# 214C~C，D 起手缩放见 test_bounce_corrections 与 replay_04）。本场景迁移为
	# 同输入形状的 214C：5B 的必杀取消窗口（接触起 0–5 正常帧）早已关闭——
	# 搓入的 214C 不被取消消费；5B 完全收招后它作为独立招式起手，此时木桩已
	# 自然受身，命中按新连段首击结算（首段 GROUND_HITSTUN 14，D 起手
	# floor(14×0.96)=13 帧）。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var hit_frames: Array[int] = []
	var combo_end_frames: Array[int] = []
	var recovered_events := 0
	for frame in range(1, 90):
		# 5B 于 F4 起手（B@F1+3 等待）、F10 命中；停顿 F11–F18；214 在 F11–F13 搓入、
		# C@F30 按下当帧解析为 214C（配对等待 3 帧也计入缓存年龄——6 帧缓存恰
		# 覆盖 5B 完全恢复的 F34）；5B 收招后独立起手 214C（8/4/20），F42 首段
		# 命中中立木桩。
		var down := frame == 11 or frame == 12
		var axis := -1 if frame == 12 or frame == 13 else 0
		var key := ""
		if frame == 1:
			key = "B"
		elif frame == 30:
			key = "C"
		var frame_events := session.step(FrameInput.make(axis, false, key, down))
		if _count_events(frame_events, CombatEvent.Type.HIT) > 0:
			hit_frames.append(frame)
		if frame >= 19 and frame <= 33:
			if frame == 19:
				_check(session.player_move_id == "5B", "window-closed 214C is not consumed as a cancel (special window 0-5 from contact)")
		if _combo_end_events(frame_events, CombatEvent.ComboEndReason.DUMMY_RECOVERED) > 0:
			combo_end_frames.append(frame)
		recovered_events += _count_events(frame_events, CombatEvent.Type.DUMMY_RECOVERED)
	_check(hit_frames == [10, 42], "5B hits on frame 10; the late 214C only starts independently after full recovery")
	_check(combo_end_frames == [29], "the first combo ends when the dummy recovers naturally (F29) before 5B finishes; the fresh 214C combo closes on its own cancel window (F59) ahead of the F63 recovery")
	_check(session.combo_hits == 1, "the independent 214C hit starts a fresh combo count")
	_check(recovered_events == 2, "dummy recovers naturally after the 5B stun and again after the 214C stun")
	_check(session.dummy_state == CombatSession.DummyState.NEUTRAL, "dummy is neutral again after recovery")


func _test_jump_cancel_requires_hit_config_and_window() -> void:
	# jump cancel 门槛：招式配置（6A）、命中确认（挥空不算）与取消窗口缺一不可；
	# 不满足时 Space 不改变玩家与连段状态，收招后 Space 恢复为普通跳跃。
	var whiff := CombatSession.new()
	whiff.dummy_position = Vector2(900.0, GameParams.ground_stand_y())
	var grounded_on_space := false
	## C 是投组合成员键：挥空 5C 于 F4 起手、F30 收招。
	for frame in range(1, 32):
		whiff.step(FrameInput.make(0, frame == 8, "C" if frame == 1 else ""))
		if frame == 8:
			grounded_on_space = whiff.player_on_ground
	_check(grounded_on_space and whiff.combo_hits == 0 and not whiff.combo_active, "whiffed launcher ignores space during the move")
	whiff.step(FrameInput.make(0, true))
	for i in range(8):
		whiff.step(FrameInput.new())
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
	## 6A（F1 前方向、F2 A）于 F10 命中、停顿 F11–F18；正常年龄 9（物理 F27）关窗，
	## F28 的 Space 已在窗外。
	for frame in range(1, 30):
		var events := late.step(FrameInput.make(1 if frame == 1 else 0, frame == 28, "A" if frame == 2 else ""))
		if _combo_end_events(events, CombatEvent.ComboEndReason.CANCEL_WINDOW_CLOSED) > 0:
			end_frames.append(frame)
	_check(late.player_on_ground and not late.combo_active, "space after the cancel window cannot jump cancel")
	_check(end_frames == [27], "combo ends from the closed cancel window (normal age 9 = physics 27), not from the space press")


func _test_jump_cancel_6A_into_jA_pursuit() -> void:
	# 高级路线前半段（票据 05 起 launcher 为 6A，236C 已迁移为两段判定）：
	# 6A 命中确认 → 停顿（F11–F18，Space 在停顿内无效）→ F19（恢复首个正常帧，
	# 取消年龄 1）Space jump cancel 进入 4f 起跳准备（F19–F22 地面、F23 离地）
	# 并保留连段 → F28 空中 A 起手 jA 追击、F32 命中。追击是普通命中：不刷新
	# 木桩滞空，木桩仍在原始浮空抛物线上落地。C 起手：6A round0.1(16×0.93)=14.9、
	# jA 第二击 0.93×0.90=0.837 → 6.7。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(72, 0)
	var hit_frames: Array[int] = []
	var land_frame := -1
	var airborne_seen := false
	var combo_end_frames: Array[int] = []
	for frame in range(1, 80):
		var key := ""
		if frame == 2 or frame == 28:
			key = "A"
		var events := session.step(FrameInput.make(1 if frame == 1 else 0, frame == 19, key))
		if _count_events(events, CombatEvent.Type.HIT) > 0:
			hit_frames.append(frame)
		if frame == 19:
			_check(session.player_on_ground and session.player_prejump_left == 4, "space on the first normal frame after the freeze enters the four pre-jump frames")
			_check(session.player_move_id == "" and session.player_phase == CombatSession.PlayerPhase.NEUTRAL, "jump cancel clears the launcher into neutral ground prep")
			_check(session.combo_active and session.combo_hits == 1, "jump cancel keeps the combo alive for air pursuit")
		if frame == 23:
			_check(not session.player_on_ground, "the jump cancel leaves the ground four prep frames after the request")
		if frame == 29:
			_check(session.player_move_id == "jA", "air action after jump cancel starts the jA pursuit move")
			_check(not session.player_on_ground, "jA starts while airborne")
		if frame == 32:
			_check(session.dummy_state == CombatSession.DummyState.AIR_HITSTUN and not session.dummy_on_ground, "jA pursuit keeps the dummy airborne in air hitstun")
			_check(session.dummy_hitstun_left == 10, "pursuit hit refreshes the time-scaled untech (floor(12×0.93×0.94))")
		if frame > 10:
			if session.dummy_on_ground:
				if airborne_seen and land_frame == -1:
					land_frame = frame
			else:
				airborne_seen = true
		if _combo_end_events(events, CombatEvent.ComboEndReason.CANCEL_WINDOW_CLOSED) > 0:
			combo_end_frames.append(frame)
	_check(hit_frames == [10, 32], "6A hits on frame 10 and the pursued jA connects on frame 32")
	_check(session.combo_hits == 2 and not session.combo_active, "route counts two hits and ends when jA's cancel window closes")
	_check(combo_end_frames == [49], "combo ends nine normal frames after the jA hit (frozen frames excluded)")
	_check(land_frame == 61, "the pursuit's airborne profile resets the dummy's arc with its small upward speed (land F61, earlier than the untouched launcher arc)")
	_check(_approx(session.dummy_hp, GameParams.DUMMY_MAX_HP - 14.9 - 6.7), "route damage is 6A at C-starter scale plus decayed jA")

func _test_jump_cancel_5C_into_jA_pursuit() -> void:
	# 旧路线负例：5C 不再是专用 launcher，资源不再声明 jump cancel——命中后的
	# Space 不产生 jump cancel、不进入准备，jA 追击不成立；连段保持到 5C 完全
	# 收招（普通地面命中不因取消窗口关闭提前结束，5C 声明了普通连接边）。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var hit_frames: Array[int] = []
	var end_frames: Array[int] = []
	var end_reasons: Array[int] = []
	for frame in range(1, 55):
		var key := ""
		if frame == 1:
			key = "C"
		elif frame == 24:
			key = "A"
		var events := session.step(FrameInput.make(0, frame == 16, key))
		if _count_events(events, CombatEvent.Type.HIT) > 0:
			hit_frames.append(frame)
		for event in events:
			if event.type == CombatEvent.Type.COMBO_ENDED:
				end_frames.append(frame)
				end_reasons.append(event.combo_end_reason)
	_check(hit_frames == [12], "5C lands as a normal ground hit (F12) with no air pursuit")
	_check(session.combo_hits == 1, "no second combo hit: 5C no longer grants jump cancel pursuit")
	_check(not session.player_prejump_left > 0 and session.player_on_ground, "space after the 5C hit never enters pre-jump (no jump cancel configured)")
	_check(end_frames == [32] and end_reasons == [CombatEvent.ComboEndReason.DUMMY_RECOVERED],
		"the combo survives past the cancel window (link edge declared) and ends when the dummy recovers (F32)")


func _test_space_does_not_touch_action_buffer() -> void:
	# Space 与动作键缓存完全独立：5A 命中（F6）后的停顿内按 Space 不缓存、不消费
	# 也不覆盖动作键（停顿内 jump 独立缓存属跳跃 issue）；B 在停顿中照常进缓存，
	# 恢复首帧（F15）消费取消进 5B。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	for frame in range(1, 31):
		var key := ""
		if frame == 1:
			key = "A"
		elif frame == 9:
			key = "B"
		session.step(FrameInput.make(0, frame == 7, key))
		if frame == 8:
			_check(session.player_on_ground and session.player_move_id == "5A", "space inside the freeze neither jumps nor disturbs the ongoing move")
		if frame == 16:
			_check(session.player_move_id == "5B", "action buffer survives the space press and still cancels 5A into 5B on recovery")
	_check(session.combo_hits == 2, "the buffered cancel still extends the combo")


func _test_no_double_jump_after_jump_cancel() -> void:
	# jump cancel 转入空中后 Space 不再起跳：无二段跳、无第二次向上速度，
	# 落地帧仍恰为请求帧 + 准备 4f + 滞空 38f（正常帧口径，停顿不计入滞空）。
	# 6A（F1 前方向、F2 A）于 F10 命中后的停顿（F11–F18）后 F19（正常年龄 1，
	# 窗口内）请求被接受：F19–F22 准备、F23 离地、F61 落地。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(72, 0)
	var jump_cancel_frame := -1
	var airborne_seen := false
	var land_frame := -1
	var second_impulse_seen := false
	for frame in range(1, 70):
		session.step(FrameInput.make(1 if frame == 1 else 0, frame == 19 or frame == 24 or frame == 29 or frame == 34, "A" if frame == 2 else ""))
		if frame == 19:
			jump_cancel_frame = frame
			_check(session.player_on_ground and session.player_prejump_left == 4, "the jump cancel request enters the normal four pre-jump frames")
		if jump_cancel_frame != -1 and land_frame == -1:
			if not session.player_on_ground:
				airborne_seen = true
			elif airborne_seen:
				land_frame = frame
			elif frame > jump_cancel_frame + GameParams.PLAYER_PREJUMP_FRAMES + 2 					and session.player_velocity.y < -GameParams.jump_velocity() * 0.9:
				second_impulse_seen = true
	_check(jump_cancel_frame == 19 and not second_impulse_seen, "air space presses never grant a second upward impulse")
	_check(land_frame == jump_cancel_frame + GameParams.PLAYER_PREJUMP_FRAMES + GameParams.PLAYER_JUMP_AIRTIME_FRAMES, "airtime after jump cancel stays exactly the configured frames with no double jump")

func _test_jump_airtime_matches_param() -> void:
	# 默认参数：玩家空中阶段 38 个物理帧、木桩浮空滞空 48 个物理帧（滞空由参数换算）。
	var session := CombatSession.new()
	session.dummy_position = Vector2(100.0, GameParams.ground_stand_y())
	var jump_frame := 5
	var first_air_frame := -1
	var land_frame := -1
	for frame in range(1, 70):
		session.step(FrameInput.make(0, frame == jump_frame))
		if first_air_frame == -1 and not session.player_on_ground:
			first_air_frame = frame
		if land_frame == -1 and first_air_frame != -1 and session.player_on_ground:
			land_frame = frame
	_check(first_air_frame == jump_frame + GameParams.PLAYER_PREJUMP_FRAMES, "takeoff happens exactly pre-jump frames after the request")
	_check(land_frame == jump_frame + GameParams.PLAYER_PREJUMP_FRAMES + GameParams.PLAYER_JUMP_AIRTIME_FRAMES, "neutral jump lasts pre-jump plus exactly the configured airtime frames")
	_check(GameParams.PLAYER_PREJUMP_FRAMES == 4 and GameParams.PLAYER_JUMP_AIRTIME_FRAMES == 38 and GameParams.DUMMY_FLOAT_AIRTIME_FRAMES == 48, "default jump params are 4f pre-jump, 38-frame airtime and 48-frame float")


func _test_jump_lifecycle_prejump_air_landing_recovery() -> void:
	# 普通跳分期（issue 15）：Space 请求被接受的当帧是准备第 1 帧，4f 全部地面
	# 姿态；下一个正常帧离地进入空中阶段；落地帧是基础落地恢复第 1 帧，空跳
	# 恢复共 3f——整周期 45f（无停顿、中断与额外恢复）。
	var session := CombatSession.new()
	session.dummy_position = Vector2(100.0, GameParams.ground_stand_y())
	var prep_grounded_neutral := true
	var prep_counts: Array[int] = []
	var first_air_frame := -1
	var land_frame := -1
	var recovery_counts: Array[int] = []
	var free_frame := -1
	for frame in range(1, 60):
		session.step(FrameInput.make(0, frame == 1))
		if frame <= 4:
			prep_grounded_neutral = prep_grounded_neutral and session.player_on_ground \
				and session.player_phase == CombatSession.PlayerPhase.NEUTRAL
			prep_counts.append(session.player_prejump_left)
		if first_air_frame == -1 and not session.player_on_ground:
			first_air_frame = frame
		if land_frame == -1 and first_air_frame != -1 and session.player_on_ground:
			land_frame = frame
		if land_frame != -1 and frame >= land_frame and frame <= land_frame + 3:
			recovery_counts.append(session.player_landing_recovery_left)
		if free_frame == -1 and land_frame != -1 and frame > land_frame \
				and session.player_landing_recovery_left == 0 and session.player_prejump_left == 0:
			free_frame = frame
	_check(prep_grounded_neutral, "pre-jump frames 1-4 stay grounded and neutral")
	_check(prep_counts == [4, 3, 2, 1], "pre-jump counts down 4/3/2/1 across the four prep frames")
	_check(first_air_frame == 5, "the first airborne frame is the normal frame right after pre-jump")
	_check(land_frame == 1 + GameParams.PLAYER_PREJUMP_FRAMES + GameParams.PLAYER_JUMP_AIRTIME_FRAMES,
		"landing happens exactly pre-jump plus airtime frames after the accepted request")
	_check(recovery_counts == [3, 2, 1, 0], "empty-jump landing recovery counts down 3/2/1 and reaches 0 on the fourth frame")
	_check(free_frame == 46, "the whole jump cycle spans 45 frames (request frame 1 through recovery frame 45)")
	# 离地当帧按空中姿态解析（spec：下一个正常帧离地并按空中姿态解析）：
	# A 恰在离地帧按下即解析为空中招式并当帧起手（准备最后一帧仍是地面姿态）。
	var air_press := CombatSession.new()
	air_press.dummy_position = Vector2(100.0, GameParams.ground_stand_y())
	var ja_frame := -1
	for frame in range(1, 12):
		air_press.step(FrameInput.make(0, frame == 1, "A" if frame == 5 else ""))
		if air_press.player_move_id == "jA" and ja_frame == -1:
			ja_frame = frame
	_check(ja_frame == 5, "an action key pressed on the first airborne frame resolves by air stance and starts jA that frame")


func _test_prejump_locks_actions_and_rejump() -> void:
	# pre-jump 锁定（issue 15）：四帧准备期间普通拳脚与方向必杀都不得起手——
	# 当前数据模型没有任何"显式配置的地面必杀取消"（spec 可选字段清单未定义
	# pre-jump 取消目标的配置位），全部输入只记录不消费；准备内按下的地面动作
	# 不因之后离地被重解释为空中技（不跨姿态自动重解释）；准备内再次 Space
	# 不重置、不延长准备计时（无再次跳跃）。
	var session := CombatSession.new()
	session.dummy_position = Vector2(900.0, GameParams.ground_stand_y())
	var move_started := false
	var buffer_at_f9 := ""
	var buffer_at_f10 := ""
	for frame in range(1, 12):
		session.step(FrameInput.make(0, frame == 1, "A" if frame == 4 else ""))
		move_started = move_started or session.player_move_id != ""
		if frame == 9:
			buffer_at_f9 = String(session.debug_snapshot()["buffered_move_id"])
		if frame == 10:
			buffer_at_f10 = String(session.debug_snapshot()["buffered_move_id"])
	_check(not move_started, "an action key pressed on the last pre-jump frame never starts a move")
	_check(not session.player_on_ground and session.player_prejump_left == 0, "the jump proceeds into the air after the locked pre-jump")
	_check(buffer_at_f9 == "5A", "the prep-frame press keeps its ground resolution (5A) while airborne")
	_check(buffer_at_f10 == "", "the unstarted press expires at its original age 6, never reinterpreted as an air move")

	var special := CombatSession.new()
	special.dummy_position = Vector2(900.0, GameParams.ground_stand_y())
	var special_started := false
	for frame in range(1, 12):
		var input := FrameInput.make(0, frame == 1)
		if frame == 2:
			input = FrameInput.make(0, false, "", true)
		elif frame == 3:
			input = FrameInput.make(1, false, "", true)
		elif frame == 4:
			input = FrameInput.make(1, false, "C")
		special.step(input)
		special_started = special_started or special.player_move_id != ""
	_check(not special_started, "a ground special buffered during pre-jump cannot start (no configured pre-jump cancel exists)")

	var rejump := CombatSession.new()
	rejump.dummy_position = Vector2(100.0, GameParams.ground_stand_y())
	var takeoff_frame := -1
	var land_frame := -1
	for frame in range(1, 55):
		rejump.step(FrameInput.make(0, frame <= 4))
		if takeoff_frame == -1 and not rejump.player_on_ground:
			takeoff_frame = frame
		if land_frame == -1 and takeoff_frame != -1 and rejump.player_on_ground:
			land_frame = frame
	_check(takeoff_frame == 5, "repeated space presses during pre-jump neither reset nor extend the preparation")
	_check(land_frame == 5 + GameParams.PLAYER_JUMP_AIRTIME_FRAMES, "the jump keeps the original schedule despite extra space presses")


func _test_landing_recovery_locks_and_empty_jump_exception() -> void:
	# 落地恢复锁定（issue 15）：任意跳跃的落地恢复首帧不可攻击——首帧攻击只保留
	# 原始输入、不进入可执行缓存；空跳恢复第 2、3 帧可取消为合法攻击（按下即按
	# 地面解析当帧起手）；启动过空中招式的落地恢复全程不可取消，缓存保留原龄、
	# 恢复结束后才按新状态起手。
	# 1) 首帧 raw-only：A 恰在落地帧按下（按下时仍算空中姿态）不进可执行缓存。
	var raw := CombatSession.new()
	raw.dummy_position = Vector2(100.0, GameParams.ground_stand_y())
	var landing_frame := -1
	var any_move := false
	var buffer_after_landing := "?"
	for frame in range(1, 52):
		raw.step(FrameInput.make(0, frame == 1, "A" if frame == 43 else ""))
		any_move = any_move or raw.player_move_id != ""
		if frame == 44:
			buffer_after_landing = String(raw.debug_snapshot()["buffered_move_id"])
		if landing_frame == -1 and frame > 5 and raw.player_on_ground:
			landing_frame = frame
	_check(landing_frame == 43, "the empty jump lands on frame 43 (request 1 + prep 4 + airtime 38)")
	_check(buffer_after_landing == "", "an attack pressed exactly on the landing frame is raw-only: it never enters the executable buffer")
	_check(not any_move, "no move ever starts from the first-frame press through the whole recovery")

	# 2) 空跳恢复第 2 帧按下 A：地面解析的 5A 当帧起手（合法攻击例外）。
	var empty := CombatSession.new()
	empty.dummy_position = Vector2(100.0, GameParams.ground_stand_y())
	var empty_start := -1
	for frame in range(1, 52):
		empty.step(FrameInput.make(0, frame == 1, "A" if frame == 44 else ""))
		if empty.player_move_id == "5A" and empty_start == -1:
			empty_start = frame
	_check(empty_start == 44, "an attack pressed on empty-jump recovery frame 2 starts the same frame")

	# 3) 空技落地恢复全程锁定：jA 空中起手后，恢复第 2 帧按下的 A 不当帧起手，
	#    缓存保留原龄，恢复结束后才起手。
	var air := CombatSession.new()
	air.dummy_position = Vector2(100.0, GameParams.ground_stand_y())
	var ja_started := false
	var air_start := -1
	for frame in range(1, 56):
		var key := ""
		if frame == 8:
			key = "A"
		elif frame == 44:
			key = "A"
		air.step(FrameInput.make(0, frame == 1, key))
		if frame == 9:
			ja_started = air.player_move_id == "jA"
		if frame >= 44 and air.player_move_id == "5A" and air_start == -1:
			air_start = frame
	_check(ja_started, "the air action during the jump starts jA (precondition)")
	_check(air_start >= 46, "after an air move the landing recovery stays locked: the frame-2 press does not start immediately")
	_check(air_start != -1, "the buffered attack eventually starts once the landing recovery ends")


func _test_air_move_landing_penalty_and_extra_recovery() -> void:
	# 空技着地惩罚（issue 15）：空中招式一旦开始 startup，本次跳跃默认 +1f 落地
	# 恢复（每跳一次，挥空同样计入）；资源 extra_landing_recovery_frames 显式
	# 叠加更多；延长不改变空中阶段——滞空仍恰 38f，落地帧与空跳一致。
	var session := CombatSession.new()
	session.dummy_position = Vector2(900.0, GameParams.ground_stand_y())
	var recovery_seen: Array[int] = []
	var land_frame := -1
	for frame in range(1, 50):
		session.step(FrameInput.make(0, frame == 1, "A" if frame == 8 else ""))
		if session.player_landing_recovery_left > 0:
			recovery_seen.append(session.player_landing_recovery_left)
		if land_frame == -1 and frame > 5 and session.player_on_ground:
			land_frame = frame
	_check(recovery_seen == [4, 3, 2, 1], "a whiffed jA still adds the default +1f penalty to the base landing recovery")
	_check(land_frame == 1 + GameParams.PLAYER_PREJUMP_FRAMES + GameParams.PLAYER_JUMP_AIRTIME_FRAMES,
		"the penalty lengthens recovery without changing the air phase: landing stays on frame 43")
	var empty := CombatSession.new()
	empty.dummy_position = Vector2(900.0, GameParams.ground_stand_y())
	var empty_land := -1
	for frame in range(1, 50):
		empty.step(FrameInput.make(0, frame == 1))
		if empty_land == -1 and frame > 5 and empty.player_on_ground:
			empty_land = frame
	_check(empty_land == land_frame, "an empty jump and a jA jump land on the same frame (airtime is untouched)")

	var table := MoveData.default_table()
	(table["jA"] as MoveData).extra_landing_recovery_frames = 2
	var extra := CombatSession.new(table)
	extra.dummy_position = Vector2(900.0, GameParams.ground_stand_y())
	var extra_recovery: Array[int] = []
	for frame in range(1, 52):
		extra.step(FrameInput.make(0, frame == 1, "A" if frame == 8 else ""))
		if extra.player_landing_recovery_left > 0:
			extra_recovery.append(extra.player_landing_recovery_left)
	_check(extra_recovery == [6, 5, 4, 3, 2, 1], "explicit extra recovery stacks onto the base 3 and the default +1f penalty")


func _age_boundary_table(total_frames: int) -> Dictionary:
	## 停顿寿命对照表：短地面打击 S（前摇 5 → 按下 +5 帧命中；总帧数可调，
	## 决定收招帧），无 jump cancel 配置——用作跳跃槽年龄边界的状态限制。
	var move := _probe_move("S", "A")
	move.startup_frames = 5
	move.active_frames = 2
	move.recovery_frames = total_frames - 7
	_set_probe_stun(move, 30)
	_set_probe_horizontal(move, 0.0)
	return {"S": move}


func _test_hitstop_jump_slot_lifetime_seam() -> void:
	# spec seam「Hitstop内jump及寿命」：6A 命中 F22（F13 前方向、F14 A 起手）、
	# 停顿 F23–F30；F24 按下 Space——停顿只记录，F31（恢复首个正常帧、槽年龄 0）
	# 消费产生 jump cancel：F31–F34 起跳准备、F35 离地。对照（状态限制）：收招把
	# 消费推迟到 F34 时年龄 5 仍可消费；推迟到 F35 时年龄 6 在消费前先过期。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var slot_ages: Array[int] = []
	var takeoff_frame := -1
	for frame in range(1, 43):
		var input := FrameInput.make(1 if frame == 13 else 0, frame == 24)
		if frame == 14:
			input = FrameInput.make(0, false, "A")
		session.step(input)
		if frame >= 24 and frame <= 28:
			slot_ages.append(int(session.debug_snapshot()["jump_slot_age"]))
		if frame == 31:
			_check(session.player_on_ground and session.player_prejump_left == 4, "the resume frame consumes the frozen jump press at age 0: pre-jump starts")
			_check(session.player_move_id == "" and session.combo_active, "the jump cancel clears the launcher while the combo stays alive")
		if takeoff_frame == -1 and not session.player_on_ground:
			takeoff_frame = frame
	_check(slot_ages == [0, 0, 0, 0, 0], "the jump slot age stays 0 through the freeze (aging counts normal frames only)")
	_check(takeoff_frame == 35, "four prep frames after the resume: the jump cancel leaves the ground exactly on frame 35")

	## S 的收招被自身命中停顿顺延 8 个物理帧：总 12 帧于 F34 收招（年龄 5），
	## 总 13 帧于 F35 收招（此时冻结槽已到年龄 6）。
	var five := CombatSession.new(_age_boundary_table(12))
	five.dummy_position = five.player_position + Vector2(70, 0)
	var five_takeoff := -1
	for frame in range(1, 45):
		var input := FrameInput.make(0, frame == 23)
		if frame == 15:
			input = FrameInput.make(0, false, "A")
		five.step(input)
		if five_takeoff == -1 and frame > 29 and not five.player_on_ground:
			five_takeoff = frame
	_check(five_takeoff == 38, "age 5 is still consumable: the blocked slot fires when the move ends (prep F34-F37, takeoff F38)")

	var six := CombatSession.new(_age_boundary_table(13))
	six.dummy_position = six.player_position + Vector2(70, 0)
	var six_takeoff := -1
	for frame in range(1, 50):
		var input := FrameInput.make(0, frame == 23 or frame == 42)
		if frame == 15:
			input = FrameInput.make(0, false, "A")
		six.step(input)
		if six_takeoff == -1 and frame > 29 and not six.player_on_ground:
			six_takeoff = frame
	_check(six_takeoff == 46, "age 6 expires before consumption: the frozen press never fires; a fresh press at F42 takes off at F46 after its own prep")


func _competition_table() -> Dictionary:
	# 竞争对照表：L 于 F20 命中（前摇 6、按下 F14）且同时配置地面取消与
	# jump cancel；取消目标 F 总 6 帧、命中框远（挥空、无额外停顿），在 F29
	# 消费起手、F34 收招——幸存的跳跃槽恰以年龄 5 消费；jA 仅为 jump cancel
	# 目标占位（空中姿态）。
	var launcher := _probe_move("L", "C")
	launcher.startup_frames = 6
	launcher.active_frames = 2
	launcher.recovery_frames = 12
	_set_probe_launch(launcher, 60, 0.0, GameParams.float_launch_speed())
	launcher.cancel_targets = ["F"]
	launcher.jump_cancel_targets = ["jA"]
	var follow := _probe_move("F", "A")
	follow.startup_frames = 2
	follow.active_frames = 2
	follow.recovery_frames = 2
	_set_probe_stun(follow, 20)
	_set_probe_horizontal(follow, 0.0)
	follow.hitbox_gap = 400.0
	var air := _probe_move("jA", "A")
	air.stance = MoveData.Stance.AIR
	air.air_attack = true
	return {"L": launcher, "F": follow, "jA": air}


func _test_jump_and_action_same_frame_competition() -> void:
	# spec seam「jump与动作同帧竞争」：L 于 F20 命中且同时允许 jump cancel 与
	# 地面 5A 取消；停顿 F21–F28。jump@F23、A@F24 → F29 只启动 5A（较新的
	# 原始请求优先），jump 槽保留原龄、F 收招后以年龄 5 消费；交换顺序 →
	# F29 只进入 pre-jump，A 槽保留但普通 A 不能取消准备（过期作废）；
	# 同帧按下 → 只启动 5A。每组后续均重查新状态，每帧最多启动一个。
	# 1) jump@F23、A@F24：较新的攻击优先，跳跃槽幸存。
	var first := CombatSession.new(_competition_table())
	first.dummy_position = first.player_position + Vector2(70, 0)
	var first_takeoff := -1
	for frame in range(1, 42):
		var input := FrameInput.make(0, frame == 23, "A" if frame == 24 else "")
		if frame == 14:
			input = FrameInput.make(0, false, "C")
		first.step(input)
		if frame == 29:
			_check(first.player_move_id == "F" and first.player_prejump_left == 0, "newer attack wins: only the 5A cancel starts on the resume frame")
			_check(int(first.debug_snapshot()["jump_slot_age"]) == 0, "the jump slot survives the lost arbitration with its original age")
		if first_takeoff == -1 and frame > 29 and not first.player_on_ground:
			first_takeoff = frame
	_check(first_takeoff == 38, "the surviving slot rechecks on later frames: it fires at age 5 when the move recovers (prep F34-F37)")

	# 2) A@F23、jump@F24：较新的 jump 优先，A 槽保留但不可取消准备。
	var second := CombatSession.new(_competition_table())
	second.dummy_position = second.player_position + Vector2(70, 0)
	var f_ever_started := false
	var second_takeoff := -1
	for frame in range(1, 42):
		var input := FrameInput.make(0, frame == 24, "A" if frame == 23 else "")
		if frame == 14:
			input = FrameInput.make(0, false, "C")
		second.step(input)
		f_ever_started = f_ever_started or second.player_move_id == "F"
		if frame == 29:
			_check(second.player_prejump_left == 4 and second.player_move_id == "", "newer jump wins: F29 enters pre-jump instead of starting the attack")
		if frame == 35:
			_check(String(second.debug_snapshot()["buffered_move_id"]) == "", "the retained A slot cannot cancel the preparation and expires at age 6")
		if second_takeoff == -1 and frame > 29 and not second.player_on_ground:
			second_takeoff = frame
	_check(not f_ever_started, "the buffered normal attack never starts after losing the arbitration")
	_check(second_takeoff == 33, "the winning jump leaves the ground on frame 33 (prep F29-F32)")

	# 3) jump 与 A 同帧 F24：攻击优先。
	var third := CombatSession.new(_competition_table())
	third.dummy_position = third.player_position + Vector2(70, 0)
	var third_takeoff := -1
	for frame in range(1, 42):
		var input := FrameInput.make(0, frame == 24, "A" if frame == 24 else "")
		if frame == 14:
			input = FrameInput.make(0, false, "C")
		third.step(input)
		if frame == 29:
			_check(third.player_move_id == "F" and third.player_prejump_left == 0, "same physics frame: the attack wins and only the 5A cancel starts")
		if third_takeoff == -1 and frame > 29 and not third.player_on_ground:
			third_takeoff = frame
	_check(third_takeoff == 38, "the jump slot kept at its original age fires after the move recovers (one new action per frame)")


func _test_cached_jump_direction_seam() -> void:
	# spec seam「缓存jump的跳向」：右面向、6A 命中 F22（F13 前方向、F14 A 起手）、
	# 停顿 F23–F30；Space+世界右（相对前跳 9）在停顿内按下；恢复后仅按世界左——
	# F31 消费原请求进入向右跳的 pre-jump，改按左不重写斜跳请求（消费前松键/反向/
	# 面向变化都不改写）。对照：原始 8 请求在 pre-jump 内仍可按当前输入改成斜跳，
	# 且不重置准备计时。左面向镜像：世界左+Space 为前跳 9，恢复后按世界右仍向左起跳。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var slot_dir_at_f26 := -1
	var takeoff_vx := 0.0
	for frame in range(1, 40):
		var axis := 1 if frame == 23 else (-1 if frame >= 31 else (1 if frame == 13 else 0))
		var input := FrameInput.make(axis, frame == 23)
		if frame == 14:
			input = FrameInput.make(0, false, "A")
		session.step(input)
		if frame == 26:
			# 槽已被消费/不存在时读 null：显式记 -1，让时间线漂移表现为断言失败
			# 而不是运行时错误静默中止整个测试函数。
			var slot_dir: Variant = session.debug_snapshot()["jump_slot_direction"]
			if slot_dir != null:
				slot_dir_at_f26 = int(slot_dir)
		if frame == 31:
			_check(session.player_prejump_left == 4, "the frozen diagonal request is consumed on the resume frame (pre-jump starts)")
		if frame == 35 and not session.player_on_ground:
			takeoff_vx = session.player_velocity.x
	_check(slot_dir_at_f26 == 1, "the slot keeps the world-horizontal direction pressed inside the freeze")
	_check(takeoff_vx > 150.0, "holding reverse after the freeze never rewrites the request: the takeoff still moves rightward")

	var vertical := CombatSession.new()
	vertical.dummy_position = vertical.player_position + Vector2(70, 0)
	var vertical_vx := 0.0
	for frame in range(1, 40):
		var axis := 1 if frame == 13 or frame >= 31 else 0
		var input := FrameInput.make(axis, frame == 23, "A" if frame == 14 else "")
		vertical.step(input)
		if frame == 35 and not vertical.player_on_ground:
			vertical_vx = vertical.player_velocity.x
	_check(vertical_vx > 150.0, "an original vertical request can still turn diagonal inside pre-jump (takeoff stays on frame 35, prep timer untouched)")

	var mirror := CombatSession.new()
	mirror.dummy_position = mirror.player_position + Vector2(-70, 0)
	var mirror_vx := 0.0
	for frame in range(1, 40):
		var axis := -1 if frame == 23 else (-1 if frame == 13 else (1 if frame >= 31 else 0))
		var input := FrameInput.make(axis, frame == 23)
		if frame == 14:
			input = FrameInput.make(0, false, "A")
		mirror.step(input)
		if frame == 35 and not mirror.player_on_ground:
			mirror_vx = mirror.player_velocity.x
	_check(mirror_vx < -150.0, "left-facing mirror: world-left + Space is the forward 9; holding world right at resume still takes off leftward")


func _test_jump_cancel_landing_without_pursuit_ends_combo() -> void:
	# jump cancel 后始终不接空中起手：玩家落地当帧追击资格作废，连段以收招未接续结束；
	# 木桩浮空处理不受影响（长浮空硬直下木桩仍在浮空受击中）。
	# 6A（F1 前方向、F2 A）于 F10 命中、停顿 F11–F18、F16 Space（停顿内记录）
	# F19 消费进入准备（F23 离地）、F61 落地断连。C 起手时间修正 0.90：声明 67
	# 帧受身使实际应用值回到 60（floor(67×0.90)），保持原编排。
	var table := MoveData.default_table()
	MoveData.profile_for(table["6A"], HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL).air_untech_frames = 67
	var session := CombatSession.new(table)
	session.dummy_position = session.player_position + Vector2(70, 0)
	var end_frames: Array[int] = []
	var end_reasons: Array[int] = []
	var dummy_state_at_end := CombatSession.DummyState.NEUTRAL
	for frame in range(1, 65):
		var axis := 1 if frame == 1 else 0
		var events := session.step(FrameInput.make(axis, frame == 16, "A" if frame == 2 else ""))
		for event in events:
			if event.type == CombatEvent.Type.COMBO_ENDED:
				end_frames.append(frame)
				end_reasons.append(event.combo_end_reason)
				dummy_state_at_end = session.dummy_state
	_check(end_frames == [61], "combo ends exactly when the player lands without air pursuit")
	_check(end_reasons == [CombatEvent.ComboEndReason.MOVE_RECOVERED], "landing without pursuit ends the combo as an unrecovered cancel")
	_check(session.combo_hits == 1, "combo stops counting at the launcher hit")
	_check(dummy_state_at_end == CombatSession.DummyState.AIR_HITSTUN, "landing without pursuit leaves the dummy's float handling untouched")


func _test_neutral_jump_jA_cannot_pursue() -> void:
	# 收招断连后的普通跳跃不产生追击资格：空中 jA 即使把浮空/已受身木桩摆进
	# 命中框也打不中。6A（F1 前方向、F2 A）于 F10 命中（C 起手受身 floor(36×0.90)=32，
	# F50 受身）、6A 于 F43 收招、F45 Space 进入准备（F49 离地）、jA F51 起手。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var hit_frames: Array[int] = []
	for frame in range(1, 62):
		var key := ""
		if frame == 2:
			key = "A"
		elif frame == 51:
			key = "A"
		if frame == 50:
			# 木桩在受身边界附近：摆进 jA 命中框并停住，验证资格而非几何挡住追击。
			session.dummy_position = session.player_position + Vector2(70, -15)
			session.dummy_velocity = Vector2.ZERO
		var events := session.step(FrameInput.make(1 if frame == 1 else 0, frame == 45, key))
		if _count_events(events, CombatEvent.Type.HIT) > 0:
			hit_frames.append(frame)
		if frame == 53:
			_check(session.player_move_id == "jA", "air action during a plain jump still starts jA")
			_check(session.dummy_state != CombatSession.DummyState.NEUTRAL, "dummy is still in its post-launch state inside the attack rect")
	_check(hit_frames == [10], "neutral-jump jA cannot pursue the floating dummy")
	_check(session.combo_hits == 1, "combo count stays at the launcher hit")


func _test_full_air_route_5A_5B_6A_jA_jB_j5D() -> void:
	# 完整空中路线（票据 05 起 launcher 为 6A）：5A → 5B（链式取消）→ 6A（链式
	# 取消）→ Space jump cancel → jA → jB → j5D 空中收束（票据 08：jD 迁移为
	# 空中 D 系，无后续边；命中后连段按落地截断/取消窗关闭结束，不再有
	# FINISHER 语义）。六次命中依次计入连段并按三层修正递减；每次命中后的
	# 8 帧停顿顺延后续物理帧。编排（贴身 64 px）：5A F4 起手、F9 命中；B@F6 于
	# F9 消费 → 5B F1=F9、F23 命中；6+A@F19 于 F23 消费 → 6A F1=F23、F39 命中；
	# 停顿 F40–F47、F48 Space（恢复首帧）→ F52 离地；jA@F65 → F69 命中（恰在
	# 浮空受身前刷新）；B@F70（停顿内）→ F78 消费 → jB F82 命中；D@F83 → F91
	# 消费 → j5D F97 命中收束。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(64, 0)
	var hit_frames: Array[int] = []
	var move_ids: Array[String] = []
	var end_frames: Array[int] = []
	var end_reasons: Array[int] = []
	var recovered_frames: Array[int] = []
	var keys := {4: "A", 6: "B", 19: "A", 65: "A", 70: "B", 83: "D"}
	for frame in range(1, 130):
		var down := frame == 1 or frame == 2
		# 6+A 已是共享表招式（优先级高于 5A）：6A 按下帧的方向段以 6 结尾。
		var axis := 1 if frame == 2 or frame == 19 else 0
		var key: String = keys.get(frame, "")
		var events := session.step(FrameInput.make(axis, frame == 48, key, down))
		move_ids.append(session.player_move_id)
		if _count_events(events, CombatEvent.Type.HIT) > 0:
			hit_frames.append(frame)
		for event in events:
			if event.type == CombatEvent.Type.COMBO_ENDED:
				end_frames.append(frame)
				end_reasons.append(event.combo_end_reason)
			elif event.type == CombatEvent.Type.DUMMY_RECOVERED:
				recovered_frames.append(frame)
	_check(hit_frames == [9, 23, 39, 69, 82, 97], "route lands all six hits on the scheduled frames")
	_check(move_ids.has("jA") and move_ids.has("jB") and move_ids.has("j5D"), "route chains jA -> jB -> j5D via hit-confirm cancels after the 6A jump cancel")
	_check(end_frames == [114] and end_reasons == [CombatEvent.ComboEndReason.CANCEL_WINDOW_CLOSED], "j5D carries no follow-up edges: the cancel window closes (F114) before the attacker lands, ending the route")
	_check(session.combo_hits == 6 and not session.combo_active, "combo counts all six hits and stops there")
	_check(_approx(session.combo_total_damage, 39.6), "route damage accumulates the three-layer values (5.8+7.8+9.3+4.2+5.7+6.8)")
	_check(recovered_frames == [119] and session.dummy_state == CombatSession.DummyState.NEUTRAL, "dummy completes its own recovery handling once after the closer")

func _test_same_frame_hit_landing_and_landing_followup() -> void:
	var session := CombatSession.new(_seam_table())
	session.dummy_position = session.player_position + Vector2(52, 0)
	var hit_frames: Array[int] = []
	var move_ids: Array[String] = []
	var end_frames: Array[int] = []
	var end_reasons: Array[int] = []
	var recovered_frames: Array[int] = []
	var critical_events: Array[CombatEvent] = []
	var critical_state_ok := false
	var jB_in_progress_before_landing := false
	for frame in range(1, 155):
		var down := frame == 1 or frame == 2
		# 6+A 已是共享表招式（优先级高于 5A）：A 按下帧的方向段不能以 6 结尾，
		# 否则 A 键解析为 6A；236 的 6 段延后到 F5 补入，236C 仍在 F6 按下时配齐。
		var axis := 1 if frame == 2 or frame == 5 else 0
		var key := ""
		if frame == 4:
			key = "A"
		elif frame == 6:
			key = "C"
		elif frame == 65:
			key = "A"
		elif frame == 75:
			# B 是投组合成员键（表内含投，issue 17）：停顿内按下、等待在 F78 到期，
			# 恢复首帧 F78 消费——与临界帧几何保持一致。
			key = "B"
		elif frame == 80:
			key = "D"
		var events := session.step(FrameInput.make(axis, frame == 32, key, down))
		# 木桩横向钉位（与 Solver 探针同一几何假设）：路线帧编排不依赖击退漂移。
		session.dummy_position.x = session.player_position.x + 64.0 * session.player_facing
		move_ids.append(session.player_move_id)
		if _count_events(events, CombatEvent.Type.HIT) > 0:
			hit_frames.append(frame)
		for event in events:
			if event.type == CombatEvent.Type.COMBO_ENDED:
				end_frames.append(frame)
				end_reasons.append(event.combo_end_reason)
			elif event.type == CombatEvent.Type.DUMMY_RECOVERED:
				recovered_frames.append(frame)
		if frame == 81:
			jB_in_progress_before_landing = session.player_move_id == "jB" and not session.player_on_ground
		if frame == 82:
			critical_events = events
			critical_state_ok = session.player_move_id == "" and session.player_on_ground \
				and session.combo_hits == 4 and not session.combo_active \
				and session.dummy_state == CombatSession.DummyState.AIR_HITSTUN \
				and not session.dummy_on_ground and session.dummy_hitstun_left == 11
	_check(jB_in_progress_before_landing, "route reaches the critical frame with jB airborne and one frame from landing")
	_check(hit_frames == [9, 23, 69, 82], "jB hits exactly on the landing frame, then recovery blocks the landing followup")
	_check(critical_events.size() == 3 and critical_events[0].type == CombatEvent.Type.HIT \
		and critical_events[1].type == CombatEvent.Type.HITSTOP_STARTED,
		"the critical frame emits the hit then the hitstop-start boundary: hit refreshed hitstun before landing ticked it")
	_check(critical_state_ok, "same-frame order is hit refresh -> landing -> cancel -> consume: recovery blocks buffered D")
	_check(not "j5D" in move_ids, "the buffered D is never consumed as an air D move on the landing frame")
	_check(end_frames == [82] and end_reasons == [CombatEvent.ComboEndReason.MOVE_RECOVERED], "landing truncates jB and ends the route")
	_check(_approx(session.combo_total_damage, 28.5), "route damage stops at the four corrected hits (5.8+11.7+4.7+6.3) without the forbidden followup")
	_check(recovered_frames == [107] and session.dummy_state == CombatSession.DummyState.NEUTRAL, "dummy completes its knockdown handling after the final air hit")
	_check(session.combo_hits == 4, "combo counts all four hits and stops there")


func _test_landing_seam_only_opens_on_the_landing_frame() -> void:
	# 落地接续只在落地当帧开放：jB 命中与落地同帧（F82）但没有缓存 D，
	# 恢复后的正常帧（F91）才按 D——落地帧已过，接缝关闭，jB 作废断连；
	# 地面解析出的 5D 只按独立招式起手；受击时间层修正缩短后的木桩浮空期里
	# 5D 判定窗口对上的是空中目标（5D 无 airborne 资料），精确匹配不回退，
	# 连段命中数不再增长。
	var session := CombatSession.new(_seam_table())
	session.dummy_position = session.player_position + Vector2(52, 0)
	var hit_frames: Array[int] = []
	var move_ids: Array[String] = []
	var end_frames: Array[int] = []
	var end_reasons: Array[int] = []
	var recovered_frames: Array[int] = []
	var independent_5D_started := false
	for frame in range(1, 155):
		var down := frame == 1 or frame == 2
		# 6+A 已是共享表招式（优先级高于 5A）：A 按下帧的方向段不能以 6 结尾，
		# 否则 A 键解析为 6A；236 的 6 段延后到 F5 补入，236C 仍在 F6 按下时配齐。
		var axis := 1 if frame == 2 or frame == 5 else 0
		var key := ""
		if frame == 4:
			key = "A"
		elif frame == 6:
			key = "C"
		elif frame == 65:
			key = "A"
		elif frame == 75:
			# B 是投组合成员键：停顿内按下（F75）、F78 消费——保持临界帧几何。
			key = "B"
		elif frame == 91:
			key = "D"
		var events := session.step(FrameInput.make(axis, frame == 32, key, down))
		# 木桩横向钉位（与 Solver 探针同一几何假设）：路线帧编排不依赖击退漂移。
		session.dummy_position.x = session.player_position.x + 64.0 * session.player_facing
		move_ids.append(session.player_move_id)
		if _count_events(events, CombatEvent.Type.HIT) > 0:
			hit_frames.append(frame)
		for event in events:
			if event.type == CombatEvent.Type.COMBO_ENDED:
				end_frames.append(frame)
				end_reasons.append(event.combo_end_reason)
			elif event.type == CombatEvent.Type.DUMMY_RECOVERED:
				recovered_frames.append(frame)
		if frame == 94:
			independent_5D_started = session.player_move_id == "5D" and not session.combo_active
	_check(hit_frames == [9, 23, 69, 82], "jB lands on the landing frame; the late 5D cannot connect (no airborne profile for the floating dummy)")
	_check(independent_5D_started, "D pressed during the air-move landing recovery only starts 5D after the recovery ends")
	_check(end_frames == [82] and end_reasons == [CombatEvent.ComboEndReason.MOVE_RECOVERED], "the landed jB is invalidated on its landing frame; the whiffed 5D ends nothing")
	_check(session.combo_hits == 4 and _approx(session.combo_total_damage, 28.5), "the independent 5D never extends the route combo: the airborne dummy is out of its declared profiles")
	_check(recovered_frames == [107] and session.dummy_state == CombatSession.DummyState.NEUTRAL, "dummy finishes its own knockdown handling after the whiffed probe")


func _test_landing_does_not_grant_normal_cancels() -> void:
	# 落地不自动授予取消资格：jA 未配置落地接续，落地帧缓存的 D 不会接出 5D；
	# 滞留地面姿态的空中招式作废，连段以收招未接续结束，木桩受击处理独立继续。
	# 6A（F1 前方向、F2 A）于 F10 命中；C 起手时间 0.90 下声明 40/622 使实际
	# 应用值保持 36 帧受身与 560px/s 起跳（原编排不变）：停顿 F11–F18、
	# F16 Space（停顿内）→ F19 消费进入准备（F23 离地）；
	# jA F50 起手、F54 命中（恰在浮空受身边界；停顿 F55–F62 内按 D 只进缓存），
	# 落地 F69 断连（早于取消窗关闭 F71），D 过期作废。
	var table := MoveData.default_table()
	# 票据 08 起 jA 配置了到空中 D 系的取消边；本测试的命题是「未配置接续的
	# 空技落地不授予取消」——隔离注入表清空 jA 的取消目标，保持原前提。
	(table["jA"] as MoveData).cancel_targets = [] as Array[String]
	var profile := MoveData.profile_for(table["6A"], HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL)
	profile.air_untech_frames = 40
	profile.upward_speed_px_s = 622.0
	var session := CombatSession.new(table)
	session.dummy_position = session.player_position + Vector2(64, 0)
	var hit_frames: Array[int] = []
	var move_ids: Array[String] = []
	var end_frames: Array[int] = []
	var end_reasons: Array[int] = []
	var recovered_frames: Array[int] = []
	var hitstun_at_jA_hit := -1
	var player_neutral_after_landing := false
	for frame in range(1, 95):
		var key := ""
		if frame == 2:
			key = "A"
		elif frame == 50:
			key = "A"
		elif frame == 53:
			key = "D"
		var events := session.step(FrameInput.make(1 if frame == 1 else 0, frame == 16, key))
		move_ids.append(session.player_move_id)
		if _count_events(events, CombatEvent.Type.HIT) > 0:
			hit_frames.append(frame)
			if frame == 54:
				hitstun_at_jA_hit = session.dummy_hitstun_left
		for event in events:
			if event.type == CombatEvent.Type.COMBO_ENDED:
				end_frames.append(frame)
				end_reasons.append(event.combo_end_reason)
			elif event.type == CombatEvent.Type.DUMMY_RECOVERED:
				recovered_frames.append(frame)
		if frame == 71:
			player_neutral_after_landing = session.player_move_id == "" \
				and session.player_phase == CombatSession.PlayerPhase.NEUTRAL and session.player_on_ground
	_check(hit_frames == [10, 54], "6A launches and the late jA pursuit connects on the tech-boundary frame")
	_check(hitstun_at_jA_hit == 10, "jA hit refreshes the time-scaled hitstun (floor(12×0.90×0.94)) before natural recovery takes it")
	_check(end_frames == [69] and end_reasons == [CombatEvent.ComboEndReason.MOVE_RECOVERED], "combo ends on the landing frame as an unrecovered air move")
	_check(player_neutral_after_landing, "the landed air move is cleared and the player is neutral again")
	_check(not "5D" in move_ids and not "j5D" in move_ids, "buffered D is never consumed as a cancel: landing grants no cancel to an air D move")
	_check(session.combo_hits == 2 and not session.combo_active, "combo stops at two hits")
	_check(recovered_frames == [85] and session.dummy_state == CombatSession.DummyState.NEUTRAL, "dummy finishes its own knockdown handling regardless of the combo end")


func _test_air_tech_breaks_combo_before_late_pursuit() -> void:
	# 追击迟到：木桩浮空硬直耗尽先自然受身，连段立即结束；迟到的 jA 即使把
	# 木桩含在命中框内也不能命中，连段命中数停在受身前不再增长；
	# 落地作废的空中招式不会触发第二次连段结束。
	# 停顿顺延：5A/236C 命中 9/23、F32 jump cancel 请求（F36 离地）；236C 为
	# 第二击（A 起手时间层 0.658），声明 55/851 使实际应用值保持 36 帧受身与
	# 560px/s 起跳（原编排不变）：浮空硬直自 F24 正常帧起消耗，F67 受身断连；
	# 迟到的 jA（F65 起手）到 F69 才进判定。
	## 票据 05 起 236C 迁移为两段：本测试同样注入「旧单段 launcher」探针形态
	## （55/851 补偿 A 起手 0.658/0.684 层，保持 36 帧受身与 560px/s 起跳）。
	var base := MoveData.default_table()
	var launcher := base["236C"] as MoveData
	var profile := MoveData.profile_for(launcher, HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL)
	profile.air_untech_frames = 55
	profile.upward_speed_px_s = 851.0
	profile.horizontal_speed_px_s = 200.0
	launcher.active_frames = 5
	launcher.recovery_frames = 18
	launcher.base_damage = 18
	launcher.attack_attribute = MoveData.AttackAttribute.HIGH
	launcher.segments = [] as Array[MoveSegment]
	launcher.special_entry_targets = [] as Array[String]
	launcher.special_entry_window_frames = -1
	launcher.hit_profiles = [profile]
	launcher.jump_cancel_targets = ["jA"] as Array[String]
	var session := CombatSession.new(base)
	session.dummy_position = session.player_position + Vector2(64, 0)
	var hit_frames: Array[int] = []
	var end_frames: Array[int] = []
	var end_reasons: Array[int] = []
	var recovered_frames: Array[int] = []
	var pursuit_overlaps_recovered_dummy := false
	var player_neutral_after_landing := false
	for frame in range(1, 90):
		var down := frame == 1 or frame == 2
		# 6+A 已是共享表招式（优先级高于 5A）：A 按下帧的方向段不能以 6 结尾，
		# 否则 A 键解析为 6A；236 的 6 段延后到 F5 补入，236C 仍在 F6 按下时配齐。
		var axis := 1 if frame == 2 or frame == 5 else 0
		var key := ""
		if frame == 4:
			key = "A"
		elif frame == 6:
			key = "C"
		elif frame == 65:
			key = "A"
		var events := session.step(FrameInput.make(axis, frame == 32, key, down))
		# 木桩横向钉位（与 Solver 探针同一几何假设）：路线帧编排不依赖击退漂移。
		session.dummy_position.x = session.player_position.x + 64.0 * session.player_facing
		if _count_events(events, CombatEvent.Type.HIT) > 0:
			hit_frames.append(frame)
		for event in events:
			if event.type == CombatEvent.Type.COMBO_ENDED:
				end_frames.append(frame)
				end_reasons.append(event.combo_end_reason)
			elif event.type == CombatEvent.Type.DUMMY_RECOVERED:
				recovered_frames.append(frame)
		if frame == 71:
			pursuit_overlaps_recovered_dummy = session.dummy_state == CombatSession.DummyState.AIR_RECOVERED \
				and session.player_move_id == "jA" \
				and session.player_attack_rect().intersects(Rect2(session.dummy_position - GameParams.BODY_SIZE * 0.5, GameParams.BODY_SIZE))
		if frame == 76:
			player_neutral_after_landing = session.player_move_id == "" and session.player_on_ground
	_check(hit_frames == [9, 23], "only the launcher route lands before the air tech")
	_check(end_frames == [67] and end_reasons == [CombatEvent.ComboEndReason.DUMMY_RECOVERED], "air tech ends the combo exactly when float hitstun runs out, with no second end at landing")
	print("AIRTECH end=", end_frames, " recovered=", recovered_frames, " overlapF71=", pursuit_overlaps_recovered_dummy, " dummy_state_F71=")
	_check(player_neutral_after_landing, "the landed pursuit move is cleared on landing")
	_check(session.combo_hits == 2 and not session.combo_active, "combo count freezes at the tech")
	_check(recovered_frames == [83] and session.dummy_state == CombatSession.DummyState.NEUTRAL, "air-recovered dummy lands back to neutral with a single recovery event")


# --- Hitstop、输入缓存与命中确认取消（issue 14）---

func _test_hitstop_freezes_eight_physics_frames_after_hit() -> void:
	# 命中帧完成命中与受击应用后冻结后续 8 个物理帧：双方动作、位置、速度、受击与
	# 自然受身计时全部暂停，物理帧号照常递增；CombatEvent 标出停顿边界（命中帧开始、
	# 恢复首个正常帧结束），恢复帧起正常结算继续推进。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var hit_frame := -1
	var stop_started_frames: Array[int] = []
	var stop_ended_frames: Array[int] = []
	var frozen_snaps: Array[Dictionary] = []
	for frame in range(1, 24):
		var events := session.step(FrameInput.make(0, false, "A" if frame == 1 else ""))
		for event in events:
			match event.type:
				CombatEvent.Type.HIT:
					hit_frame = frame
				CombatEvent.Type.HITSTOP_STARTED:
					stop_started_frames.append(frame)
				CombatEvent.Type.HITSTOP_ENDED:
					stop_ended_frames.append(frame)
		if frame >= 6 and frame <= 15:
			frozen_snaps.append(session.debug_snapshot())
	_check(hit_frame == 6, "5A still hits on frame 6; the freeze starts only after the hit frame settles")
	_check(stop_started_frames == [6] and stop_ended_frames == [15],
		"hitstop boundaries are events: started on the hit frame, ended on the first normal frame (6 + 8 frozen = 15)")
	# 冻结帧（7–14）：物理帧号递增、hitstop_left 递减、双方位置/速度/阶段/受击硬直不变。
	var frame_numbers: Array[int] = []
	var stop_lefts: Array[int] = []
	for snap in frozen_snaps:
		frame_numbers.append(int(snap["frame"]))
		stop_lefts.append(int(snap["hitstop_left"]))
	_check(frame_numbers == [6, 7, 8, 9, 10, 11, 12, 13, 14, 15], "physics frame numbers keep incrementing through the freeze")
	_check(stop_lefts == [8, 7, 6, 5, 4, 3, 2, 1, 0, 0], "hitstop countdown is observable frame by frame (8 frozen frames after the hit; 0 again on the recovery frame)")
	# 冻结帧（7–14）双方完全冻结：用独立重放比较木桩的位置/速度/硬直/离地状态。
	var replay := CombatSession.new()
	replay.dummy_position = replay.player_position + Vector2(70, 0)
	var replay_states: Array[Dictionary] = []
	var player_states: Array[Dictionary] = []
	for frame in range(1, 15):
		replay.step(FrameInput.make(0, false, "A" if frame == 1 else ""))
		if frame >= 7:
			replay_states.append({
				"pos": replay.dummy_position, "vel": replay.dummy_velocity,
				"stun": replay.dummy_hitstun_left, "air": replay.dummy_on_ground,
			})
			player_states.append({
				"pos": replay.player_position, "phase": replay.player_phase, "move": replay.player_move_id,
			})
	_check(replay.dummy_velocity != Vector2.ZERO, "the hit left the dummy with knockback velocity (precondition)")
	var dummy_state_frozen := true
	var player_state_frozen := true
	for i in range(replay_states.size()):
		dummy_state_frozen = dummy_state_frozen and replay_states[i]["pos"] == replay_states[0]["pos"] \
			and replay_states[i]["vel"] == replay_states[0]["vel"] and replay_states[i]["stun"] == replay_states[0]["stun"] \
			and replay_states[i]["air"] == replay_states[0]["air"]
		player_state_frozen = player_state_frozen and player_states[i]["pos"] == player_states[0]["pos"] \
			and player_states[i]["phase"] == player_states[0]["phase"] and player_states[i]["move"] == player_states[0]["move"]
	_check(dummy_state_frozen, "dummy position, velocity, hitstun and airborne state are frozen through frames 7-14")
	_check(player_state_frozen and replay.player_phase == CombatSession.PlayerPhase.ACTIVE,
		"player position, move and phase stay frozen (still mid-active at frame 14 instead of reaching recovery)")
	# 恢复帧（15）起正常结算：木桩速度重新受摩擦推进（不再与冻结值相等）。
	replay.step(FrameInput.new())
	_check(int(replay.debug_snapshot()["frame"]) == 15 and replay.dummy_velocity.x != (replay_states[0]["vel"] as Vector2).x,
		"the first normal frame after recovery resumes physics (friction moves the knocked-back dummy again)")


func _test_hitstop_records_input_and_pauses_ages() -> void:
	# 停顿中仍记录物理键、方向历史及动作键事件；缓存、方向窗口和取消窗口年龄
	# 只按正常战斗帧增加——停顿帧不消耗它们；恢复后的首个正常帧才消费。
	# 5A 于 F6 命中，F7–F14 停顿：停顿中 B 覆盖旧 D 缓存、年龄保持 0，
	# F15（恢复首个正常帧）消费 5B；方向窗口不被 8 个停顿帧消耗（C@F39 识别 214C）。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var ages_during_stop: Array[int] = []
	var buffered_during_stop: Array[String] = []
	var frozen_move_stable := true
	for frame in range(1, 20):
		var key := ""
		if frame == 1:
			key = "A"
		elif frame == 8:
			key = "D"
		elif frame == 9:
			key = "B"
		session.step(FrameInput.make(0, false, key, frame >= 10 and frame <= 13))
		var snap := session.debug_snapshot()
		if frame >= 10 and frame <= 14:
			ages_during_stop.append(int(snap["buffer_age"]))
			buffered_during_stop.append(String(snap["buffered_move_id"]))
			frozen_move_stable = frozen_move_stable and session.player_move_id == "5A"
	_check(frozen_move_stable, "the freeze neither starts nor consumes buffered moves (5A stays in progress through F14)")
	_check(ages_during_stop == [0, 0, 0, 0, 0],
		"buffer age stays 0 through the freeze (aging counts normal frames only)")
	_check(buffered_during_stop == ["5B", "5B", "5B", "5B", "5B"],
		"the freeze keeps recording action events: latest B overwrites the older D buffer")
	_check(session.debug_snapshot()["direction_sequence"] == "2",
		"direction input pressed during the freeze is recorded into the history")
	_check(session.player_move_id == "5B",
		"the first normal frame after recovery consumes the paused-age buffer as a cancel")
	# 停顿中记录的输入从恢复首个正常帧起算年龄 0（与跳跃槽同一口径）：D@F8（停顿内）
	# 拥有恢复后完整的 0–5 六个正常帧——F20（年龄 5）仍在缓存，F21（年龄 6）过期。
	# D 不是 5A 的取消目标，5A 又未收招，缓存的 5D 始终只记录不消费。
	var held := CombatSession.new()
	held.dummy_position = held.player_position + Vector2(70, 0)
	for frame in range(1, 22):
		held.step(FrameInput.make(0, false, "A" if frame == 1 else ("D" if frame == 8 else "")))
		if frame == 20:
			var held_snap := held.debug_snapshot()
			_check(String(held_snap["buffered_move_id"]) == "5D" and int(held_snap["buffer_age"]) == 5,
				"a press recorded during the freeze keeps the full 0-5 window from recovery (age 5 at physics 20)")
	_check(String(held.debug_snapshot()["buffered_move_id"]) == "",
		"the freeze-recorded press expires at age 6 (physics 21), same as a normal-frame press")


func _test_hitstop_does_not_consume_direction_window() -> void:
	# 方向窗口按正常帧计龄：命中停顿插入的 8 个物理帧不消耗指令窗口——
	# 214 于 F2–F4 输入，F6 命中触发 8 帧停顿；C（投组合成员键）方向解析在
	# 按下当帧、配对等待只推迟起手——F39 按下时首段正常年龄 29 仍识别 214C
	# （F42 起手）；F40 按则（年龄 30）过期回落 5C。
	var late := CombatSession.new()
	late.dummy_position = late.player_position + Vector2(70, 0)
	for frame in range(1, 40):
		var key := "A" if frame == 1 else ("C" if frame == 39 else "")
		var down := frame == 2 or frame == 3
		var axis := -1 if frame == 3 or frame >= 4 else 0
		late.step(FrameInput.make(axis, false, key, down))
	_pairing_wait(late)
	_check(late.player_move_id == "214C", "C pressed at normal age 29 (physics 39 with 8 frozen frames inside) still recognizes 214C")
	var expired := CombatSession.new()
	expired.dummy_position = expired.player_position + Vector2(70, 0)
	for frame in range(1, 41):
		var key := "A" if frame == 1 else ("C" if frame == 40 else "")
		var down := frame == 2 or frame == 3
		var axis := -1 if frame == 3 or frame >= 4 else 0
		expired.step(FrameInput.make(axis, false, key, down))
	_pairing_wait(expired)
	_check(expired.player_move_id == "5C", "C pressed at normal age 30 (physics 40) expires: the freeze never extended the window")


func _test_cancel_age_counts_normal_frames() -> void:
	# 取消窗口年龄只按正常战斗帧计：命中帧为年龄 0，8 个停顿帧不计龄——
	# 恢复后年龄从 1 续计。探针表（5A 命中确认取消窗口 8、前摇 8）：命中 F9、
	# 停顿 F10–F17，物理帧 25（年龄 8，含两端）是最后的有效取消帧，
	# 物理帧 26（年龄 9）窗口关闭：输入不能取消且连段在当帧结束。
	var last := CombatSession.new(_slow_ground_table())
	last.dummy_position = last.player_position + Vector2(70, 0)
	# B 是投组合成员键：F22 按下、配对窗口末帧 F25 消费——恰为取消年龄 8 的最后有效帧。
	for frame in range(1, 26):
		last.step(FrameInput.make(0, false, "A" if frame == 1 else ("B" if frame == 22 else "")))
	_check(last.player_move_id == "5B", "input at cancel age 8 (physics 25 = hit 9 + 8 frozen + 8 normal) still cancels")
	var closed := CombatSession.new(_slow_ground_table())
	closed.dummy_position = closed.player_position + Vector2(70, 0)
	var end_frames: Array[int] = []
	var started_5b := false
	for frame in range(1, 30):
		var events := closed.step(FrameInput.make(0, false, "A" if frame == 1 else ("B" if frame == 26 else "")))
		if _combo_end_events(events, CombatEvent.ComboEndReason.CANCEL_WINDOW_CLOSED) > 0:
			end_frames.append(frame)
		started_5b = started_5b or closed.player_move_id == "5B"
	_check(end_frames == [26], "cancel window closes at normal age 9 (physics 26), not with the freeze")
	_check(not started_5b and closed.player_move_id == "5A", "input at age 9 cannot cancel and never starts the target")


func _test_cancel_diagnostics_and_consumption_record() -> void:
	# 诊断显示取消资格与实际消费结果：命中确认后 cancel_age 按正常帧计龄、
	# cancel_open 随窗口开关；挥空永远没有取消资格；缓存被真正消费时记录
	# 消费结果（招式与物理帧）。探针表：5A 命中确认取消 5B（窗口 8）、前摇 8、
	# 命中 F9、停顿 F10–F17、F18 恢复。
	var session := CombatSession.new(_slow_ground_table())
	session.dummy_position = session.player_position + Vector2(70, 0)
	var age_at_frame := {}
	var open_at_frame := {}
	# B 于 F22 按下：探针表无 BC 投，B 不进入组合等待，当帧（年龄 4 ≤ 8）即消费。
	for frame in range(1, 23):
		session.step(FrameInput.make(0, false, "A" if frame == 1 else ("B" if frame == 22 else "")))
		var snap := session.debug_snapshot()
		age_at_frame[frame] = int(snap["cancel_age"])
		open_at_frame[frame] = bool(snap["cancel_open"])
	_check(age_at_frame[9] == 0 and age_at_frame[17] == 0 and age_at_frame[18] == 1 and age_at_frame[21] == 4,
		"cancel age counts normal frames only (0 through the freeze, resuming at 1 on recovery)")
	_check(open_at_frame[9] and open_at_frame[18] and open_at_frame[21],
		"cancel eligibility stays open while the window ages in normal frames (frozen frames pause it)")
	var snap := session.debug_snapshot()
	_check(String(snap["buffer_consumed_move_id"]) == "5B" and int(snap["buffer_consumed_frame"]) == 22,
		"the consumed buffer records what started and on which physics frame")
	_check(int(snap["cancel_age"]) == -1,
		"the newly canceled-into move has no confirmed hit yet, so its cancel age is unset")
	session.step(FrameInput.new())
	_check(not bool(session.debug_snapshot()["cancel_open"]),
		"eligibility stays closed until the new move actually hits")
	# 挥空：全程没有命中确认，取消年龄/资格永不出现；挥空期间的输入也永不消费
	# （缓存消费记录停在最初从中立起手的那一次）。
	var whiff := CombatSession.new(_slow_ground_table())
	whiff.dummy_position = Vector2(900.0, GameParams.ground_stand_y())
	var whiff_clean := true
	for frame in range(1, 26):
		whiff.step(FrameInput.make(0, false, "A" if frame == 1 else ("B" if frame == 4 else "")))
		var whiff_snap := whiff.debug_snapshot()
		whiff_clean = whiff_clean and int(whiff_snap["cancel_age"]) == -1 and not bool(whiff_snap["cancel_open"]) \
			and int(whiff_snap["buffer_consumed_frame"]) <= 1
	_check(whiff_clean, "a whiffed move never gains hit-confirm cancel eligibility in diagnostics")


# --- 阶段 3 票据 01：起手修正基线与普通连接 ---

func _test_starter_grade_locks_on_first_hit_only() -> void:
	# 首次实际 HIT 锁定招式声明的 starter grade；挥空不锁定、不累计；连段结束后
	# 清除，下一段首击重新锁定；被防/挥空路径在阶段 4 票据接入。
	var whiff := CombatSession.new()
	whiff.dummy_position = Vector2(2000.0, 0.0)
	whiff.step(FrameInput.make(0, false, "A"))
	for i in range(30):
		whiff.step(FrameInput.new())
	_check(whiff.combo_hits == 0 and whiff.combo_starter_grade == MoveData.StarterGrade.UNSET,
		"a whiffed move never locks the starter grade")
	_check(whiff.combo_damage_scale == 1.0 and whiff.combo_time_scale == 1.0 and whiff.combo_trajectory_scale == 1.0,
		"a whiffed move never accumulates any correction layer")
	var hit := CombatSession.new()
	hit.dummy_position = hit.player_position + Vector2(60, 0)
	var grade_at_hit := -1
	var scales_at_hit := {}
	hit.step(FrameInput.make(0, false, "A"))
	for i in range(35):
		var events := hit.step(FrameInput.new())
		if _count_events(events, CombatEvent.Type.HIT) > 0:
			grade_at_hit = hit.combo_starter_grade
			scales_at_hit = hit.debug_snapshot()
	_check(hit.combo_hits == 1 and grade_at_hit == MoveData.StarterGrade.A,
		"the first actual hit locks the move's declared A starter grade")
	_check(_approx(scales_at_hit["damage_scale"], 0.72) and _approx(scales_at_hit["time_scale"], 0.70) and _approx(scales_at_hit["trajectory_scale"], 0.75),
		"the starter hit initializes all three layers from the A starter multipliers")
	## 5A 声明了普通连接边，连段保持到完全恢复（F28）之后由木桩恢复结束。
	_check(not hit.combo_active and hit.combo_starter_grade == MoveData.StarterGrade.UNSET,
		"combo end clears the starter grade and the three layers")


func _test_three_layer_corrections_accumulate() -> void:
	# 连续普通命中中三层独立累计：伤害 round0.1(base×层值)、时间 floor(声明×层值)
	# 夹最小 1、轨迹 round(速度×层值)；互不反推。5A > 5B 链式二连（A 起手）。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(60, 0)
	var damages: Array[float] = []
	var stuns: Array[int] = []
	var snapshots: Array[Dictionary] = []
	for frame in range(1, 30):
		var events := session.step(FrameInput.make(0, false, _script_key({1: "A", 5: "B"}, frame)))
		for event in events:
			if event.type == CombatEvent.Type.HIT:
				damages.append(event.damage)
				stuns.append(session.dummy_hitstun_left)
				snapshots.append(session.debug_snapshot())
	_check(damages.size() == 2, "the two-hit chain lands")
	if damages.size() == 2:
		_check(_approx(damages[0], 5.8), "hit 1 damage = round0.1(8×0.72) = 5.8")
		_check(_approx(damages[1], 7.8), "hit 2 damage = round0.1(12×0.648) = 7.8 (damage layer only)")
		_check(stuns[0] == 9 and stuns[1] == 9, "stun layers: floor(14×0.70)=9 then floor(14×0.658)=9 (time layer only)")
		_check(_approx(snapshots[0]["damage_scale"], 0.72) and _approx(snapshots[1]["damage_scale"], 0.648),
			"damage layer accumulates independently in diagnostics")
		_check(_approx(snapshots[0]["time_scale"], 0.70) and _approx(snapshots[1]["time_scale"], 0.658),
			"time layer accumulates independently in diagnostics")
		_check(_approx(snapshots[0]["trajectory_scale"], 0.75) and _approx(snapshots[1]["trajectory_scale"], 0.7125),
			"trajectory layer accumulates independently in diagnostics")


func _test_normal_5D_has_no_reverse_5B() -> void:
	# 反例：普通来源的 5D 不取得反向 5B 出口——5D 命中后按 B，5D 没有声明到
	# 5B 的取消或普通连接边；木桩仍在受击中时，5B 只能作为独立招式起手，
	# 连段资格已消失，不能命中，连段命中数停在 3。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(56, 0)
	var hit_frames: Array[int] = []
	for frame in range(1, 70):
		var events := session.step(FrameInput.make(0, false, _script_key({1: "A", 5: "B", 21: "D", 38: "B"}, frame)))
		for event in events:
			if event.type == CombatEvent.Type.HIT:
				hit_frames.append(frame)
	_check(hit_frames == [6, 21, 36], "the route lands 5A > 5B > 5D (chain cancels) and nothing more")
	_check(session.combo_hits == 3, "the combo count stops at three hits: no reverse 5B edge exists")
	_check(not session.combo_active, "the 5D combo has ended long before the late B could matter")


func _test_link_failure_reasons_readable() -> void:
	# 普通连接的失败原因可读且分层：声明边的目标已自然恢复 → TARGET_RECOVERED；
	# 目标处于普通倒地（不可追击且非中立）→ STATE_INCOMPATIBLE；已消费的连接招
	# 判定窗口结束无接触 → DISTANCE_INSUFFICIENT。
	# 探针表：长硬直 5A（30 帧）声明 link_targets ["5B"]，B 为短前摇普通技。
	var linker := _probe_move("5A", "A")
	linker.startup_frames = 5
	linker.active_frames = 2
	linker.recovery_frames = 4
	_set_probe_stun(linker, 60)
	_set_probe_horizontal(linker, 0.0)
	linker.link_targets = ["5B"]
	var five_b := _probe_move("5B", "B")
	five_b.startup_frames = 5
	five_b.active_frames = 2
	five_b.recovery_frames = 4
	_set_probe_stun(five_b, 60)
	_set_probe_horizontal(five_b, 0.0)
	five_b.hitbox_size = Vector2(4, 4)
	five_b.hitbox_gap = 900.0
	var table := {"5A": linker, "5B": five_b}
	# 1) 距离不足：5A 命中（站位 60）后 B 在恢复后段缓存；5B 判定框远离木桩，
	#    连接招起手但判定窗口结束无接触。
	var far := CombatSession.new(table)
	far.dummy_position = far.player_position + Vector2(60, 0)
	var distance_reason := -1
	for frame in range(1, 40):
		var events := far.step(FrameInput.make(0, false, _script_key({1: "A", 8: "B"}, frame)))
		for event in events:
			if event.type == CombatEvent.Type.LINK_FAILED:
				distance_reason = event.link_fail_reason
	_check(distance_reason == CombatEvent.LinkFailReason.DISTANCE_INSUFFICIENT,
		"a consumed link move whose active window passes without contact reports DISTANCE_INSUFFICIENT")
	# 2) 目标已自然恢复：短硬直 5A（受击时间层 D 起手 floor(8×0.96)=7）在攻击者
	#    完全恢复前结束——收招当帧评估报 TARGET_RECOVERED。
	var quick := _probe_move("5A", "A")
	quick.startup_frames = 5
	quick.active_frames = 2
	quick.recovery_frames = 6
	_set_probe_stun(quick, 8)
	_set_probe_horizontal(quick, 0.0)
	quick.link_targets = ["5B"]
	var quick_table := {"5A": quick, "5B": five_b}
	var recovered := CombatSession.new(quick_table)
	recovered.dummy_position = recovered.player_position + Vector2(60, 0)
	var recovered_reason := -1
	for frame in range(1, 40):
		var events := recovered.step(FrameInput.make(0, false, _script_key({1: "A", 17: "B"}, frame)))
		for event in events:
			if event.type == CombatEvent.Type.LINK_FAILED:
				recovered_reason = event.link_fail_reason
	_check(recovered_reason == CombatEvent.LinkFailReason.TARGET_RECOVERED,
		"a declared link whose target naturally recovered first reports TARGET_RECOVERED")
	# 4) 配置缺口：长硬直 5A（探针）后缓存的 C（声明了 5B 连接边、未声明 5C）
	#    在收招当帧按 CONFIGURATION_GAP 报告，输入不作废、按独立招式继续。
	var undeclared := _probe_move("5C", "C")
	undeclared.startup_frames = 5
	undeclared.active_frames = 2
	undeclared.recovery_frames = 4
	_set_probe_stun(undeclared, 60)
	_set_probe_horizontal(undeclared, 0.0)
	var gap_table := {"5A": linker, "5B": five_b, "5C": undeclared}
	var gap_session := CombatSession.new(gap_table)
	gap_session.dummy_position = gap_session.player_position + Vector2(60, 0)
	var gap_reason := -1
	var gap_move := ""
	for frame in range(1, 40):
		var events := gap_session.step(FrameInput.make(0, false, _script_key({1: "A", 16: "C"}, frame)))
		for event in events:
			if event.type == CombatEvent.Type.LINK_FAILED:
				gap_reason = event.link_fail_reason
				gap_move = event.link_move_id
	_check(gap_reason == CombatEvent.LinkFailReason.CONFIGURATION_GAP and gap_move == "5C",
		"an undeclared link target held in the buffer at recovery reports CONFIGURATION_GAP without consuming the input")


# --- 票据 02：蹲姿普通技与低浮空扫倒 ---

func _test_crouch_normals_select_by_down_state() -> void:
	# 蹲姿选招按当帧输入状态（下方向 ∈ {1,2,3}），不依赖方向历史段：
	# 2A/2B/2C 覆盖同名站立招（优先级），无下方向时回落 5A/5B/5C，空中回落 jA。
	var table := MoveData.default_table()
	_check((table["2A"] as MoveData).requires_crouch and (table["2A"] as MoveData).attack_attribute == MoveData.AttackAttribute.LOW,
		"2A declares the crouch requirement and the low attribute from the resource")
	_check((table["2B"] as MoveData).requires_crouch and (table["2B"] as MoveData).attack_attribute == MoveData.AttackAttribute.LOW,
		"2B declares the crouch requirement and the low attribute")
	_check((table["2C"] as MoveData).requires_crouch and (table["2C"] as MoveData).attack_attribute == MoveData.AttackAttribute.LOW,
		"2C declares the crouch requirement and the low attribute")
	var down := CombatSession.new()
	down.step(FrameInput.make(0, false, "A", true))
	_check(down.player_move_id == "2A", "down + A starts 2A by the current-frame crouch state")
	var down_forward := CombatSession.new()
	down_forward.step(FrameInput.make(1, false, "A", true))
	_check(down_forward.player_move_id == "2A", "down-forward + A still routes to 2A (down predicate covers 1/2/3)")
	var down_back := CombatSession.new()
	down_back.step(FrameInput.make(-1, false, "A", true))
	_check(down_back.player_move_id == "2A", "down-back + A routes to 2A (crouch guarding input)")
	var stand := CombatSession.new()
	stand.step(FrameInput.make(0, false, "A"))
	_check(stand.player_move_id == "5A", "A without down keeps the standing 5A")
	var forward := CombatSession.new()
	forward.step(FrameInput.make(1, false, "A"))
	_check(forward.player_move_id == "6A", "forward + A keeps the direction-derived 6A")
	# 2B/2C：B/C 是投组合成员键，配对窗口（+3 物理帧）后按单键起手。
	var crouch_b := CombatSession.new()
	for frame in range(1, 7):
		crouch_b.step(FrameInput.make(0, false, "B" if frame == 1 else "", true))
	_check(crouch_b.player_move_id == "2B", "down + B resolves to 2B after the combination wait")
	var crouch_c := CombatSession.new()
	for frame in range(1, 7):
		crouch_c.step(FrameInput.make(0, false, "C" if frame == 1 else "", true))
	_check(crouch_c.player_move_id == "2C", "down + C resolves to 2C after the combination wait")
	# 空中按下方向不构成蹲姿：蹲姿招式不是候选，A 键解析为 jA。
	var air := CombatSession.new()
	air.step(FrameInput.make(0, true))
	for frame in range(2, 6):
		air.step(FrameInput.new())
	var air_events := air.step(FrameInput.make(0, false, "A", true))
	_check(air_events.size() >= 0 and air.player_move_id == "jA" and not air.player_on_ground,
		"airborne down + A starts jA; the crouch gate is ground-only")


func _test_crouch_rapid_repress_without_direction_reentry() -> void:
	# 蹲姿选招不消费方向历史：持续按住下时连续两次 A 按下都解析为 2A——
	# 不要求松开再按下方向重新建段（方向派生路径做不到这一点，是姿态锁定的回归）。
	var session := CombatSession.new()
	var move_after_frame := {}
	for frame in range(1, 26):
		var key := ""
		if frame == 1 or frame == 21:
			key = "A"
		session.step(FrameInput.make(0, false, key, true))
		move_after_frame[frame] = session.player_move_id
	# F1 与 F21 都在按住下时按下 A：两次都是 2A（5+4+10=19 帧，F21 已完全恢复）。
	_check(move_after_frame[1] == "2A", "first press under held down starts 2A")
	_check(move_after_frame[21] == "2A", "the re-press after 2A recovery still resolves to 2A without direction re-entry")


func _test_crouch_chain_route_2A_2B() -> void:
	# 2A > 2B 链式取消路线：F1 ↓+A 起手 2A（命中 F6，停顿 F7–F14），F6 命中当帧
	# 按住下按 B（组合等待在停顿中到期），恢复首帧 F15 以链式取消（2A 链含 2B）
	# 起手 2B，F22 命中；地面硬直 floor(14×0.658)=9 帧后自然受身（F39）。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var events: Array[CombatEvent] = []
	var move_after_frame := {}
	var hits := 0
	for frame in range(1, 45):
		var key := ""
		if frame == 1 or frame == 6:
			key = "B" if frame == 6 else "A"
		var frame_events := session.step(FrameInput.make(0, false, key, true))
		events.append_array(frame_events)
		hits += _count_events(frame_events, CombatEvent.Type.HIT)
		move_after_frame[frame] = session.player_move_id
	_check(hits == 2 and move_after_frame[1] == "2A" and move_after_frame[15] == "2B",
		"the 2A -> 2B crouch chain lands both hits via the chain-cancel window")
	var hit_events := _events_of(events, CombatEvent.Type.HIT)
	if hit_events.size() == 2:
		_check(_approx(hit_events[0].damage, 5.8), "2A deals 8 × A-starter 0.72 = 5.8")
		_check(_approx(hit_events[1].damage, 7.1), "2B deals 11 × 0.648 = 7.1")
	_check(_approx(session.combo_total_damage, 12.9), "route total is 12.9")
	_check(_count_events(events, CombatEvent.Type.COMBO_ENDED) == 1
		and _combo_end_events(events, CombatEvent.ComboEndReason.DUMMY_RECOVERED) == 1,
		"the crouch chain ends once by the dummy's natural recovery")
	_check(session.dummy_state == CombatSession.DummyState.NEUTRAL, "2B is a plain grounded hit; no low float appears")


func _test_stand_chains_into_crouch_5A_2B_5B_2C() -> void:
	# 站立普通技的链式取消边声明到蹲姿目标：5A > 2B（F1 A 起手、命中 F6、
	# F6 按住下按 B → F15 起手 2B、F22 命中）；5B > 2C（F1 B 起手 F4（组合等待）、
	# 命中 F10、F10 按住下按 C → F19 起手 2C、F28 命中进入低浮空）。
	var route_a := CombatSession.new()
	route_a.dummy_position = route_a.player_position + Vector2(70, 0)
	var hits_a := 0
	var moves_a: Array[String] = []
	for frame in range(1, 30):
		var key := ""
		if frame == 1:
			key = "A"
		elif frame == 6:
			key = "B"
		var axis := 0
		var down := frame >= 6
		var frame_events := route_a.step(FrameInput.make(axis, false, key, down))
		hits_a += _count_events(frame_events, CombatEvent.Type.HIT)
		moves_a.append(String(route_a.player_move_id))
	_check(hits_a == 2 and moves_a[14] == "2B",
		"5A chains into the crouch 2B when the B press carries the down state (declared edge 5A -> 2B)")
	var route_b := CombatSession.new()
	route_b.dummy_position = route_b.player_position + Vector2(70, 0)
	var hits_b := 0
	var moves_b: Array[String] = []
	for frame in range(1, 40):
		var key := ""
		if frame == 1:
			key = "B"
		elif frame == 10:
			key = "C"
		var down := frame >= 10
		var frame_events := route_b.step(FrameInput.make(0, false, key, down))
		hits_b += _count_events(frame_events, CombatEvent.Type.HIT)
		moves_b.append(String(route_b.player_move_id))
	_check(hits_b == 2 and moves_b[18] == "2C",
		"5B chains into the crouch 2C (declared edge 5B -> 2C)")
	_check(route_b.dummy_state == CombatSession.DummyState.LOW_FLOAT_SWEEP,
		"the chained 2C puts the grounded dummy into the low-float sweep")


func _test_2C_low_float_sweep_lifecycle() -> void:
	# 单招 2C：F1 ↓+C（组合等待）F4 起手、F13 命中（C 起手 0.90/0.92）——
	# 低浮空受击计时 floor(20×0.90)=18、触地速度 round(120×0.92)=110、
	# 倒地计时 floor(30×0.90)=27。F14–F21 停顿（计时冻结）后浮空 F22–F30、
	# F31 触地转 GROUND_KNOCKDOWN，F58 自然恢复。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var events: Array[CombatEvent] = []
	var state_after_frame := {}
	var timer_after_frame := {}
	var move_after_frame := {}
	for frame in range(1, 62):
		var key := "C" if frame == 1 else ""
		var frame_events := session.step(FrameInput.make(0, false, key, true))
		events.append_array(frame_events)
		state_after_frame[frame] = session.dummy_state
		move_after_frame[frame] = session.player_move_id
		timer_after_frame[frame] = [session.dummy_hitstun_left, session.dummy_knockdown_left, session.dummy_on_ground]
	_check(move_after_frame[4] == "2C", "2C starts after the combination wait resolves")
	_check(_count_events(events, CombatEvent.Type.HIT) == 1, "solo 2C lands exactly one hit")
	_check(state_after_frame[13] == CombatSession.DummyState.LOW_FLOAT_SWEEP and not timer_after_frame[13][2],
		"the 2C hit switches the grounded dummy into the airborne LOW_FLOAT_SWEEP state")
	_check(timer_after_frame[13][0] == 18, "the low-float hit window is the C-starter-scaled floor(20×0.90)=18 frames")
	_check(timer_after_frame[21][0] == 18, "the low-float timer stays frozen through the 8 hitstop frames")
	_check(timer_after_frame[25][0] < 18, "the low-float timer ticks down on normal frames once the freeze ends")
	var landed := _events_of(events, CombatEvent.Type.LOW_FLOAT_LANDED)
	_check(landed.size() == 1, "the low float emits exactly one touch-down event")
	_check(state_after_frame[31] == CombatSession.DummyState.KNOCKED_DOWN and timer_after_frame[31][1] == 27,
		"touching the ground converts LOW_FLOAT_SWEEP into the plain knockdown with the scaled 27-frame timer")
	_check(_count_events(events, CombatEvent.Type.DUMMY_RECOVERED) == 1 and session.dummy_state == CombatSession.DummyState.NEUTRAL,
		"the knockdown recovers naturally back to neutral (no OTG, no tech)")
	_check(session.dummy_hp == GameParams.DUMMY_MAX_HP - 13.0, "solo 2C deals 14 × C-starter damage layer 0.93 = 13.0")


func _test_2C_low_float_corrections_and_combo_end() -> void:
	# 5B > 2C：B 起手三层修正跨低浮空保留（伤 0.756/时 0.7708/轨 0.8075），
	# 触地转倒地（F45，与取消窗口关闭同帧时运动阶段先行）清除修正与起手等级；
	# 触地当帧 COMBO_ENDED(KNOCKDOWN)，F68 自然恢复。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var events: Array[CombatEvent] = []
	var combo_state_after_frame := {}
	for frame in range(1, 72):
		var key := ""
		if frame == 1:
			key = "B"
		elif frame == 10:
			key = "C"
		var down := frame >= 10
		var frame_events := session.step(FrameInput.make(0, false, key, down))
		events.append_array(frame_events)
		combo_state_after_frame[frame] = [session.combo_active, session.combo_starter_grade,
			session.combo_damage_scale, session.combo_time_scale, session.combo_trajectory_scale,
			session.dummy_state]
	_check(_count_events(events, CombatEvent.Type.HIT) == 2, "5B > 2C lands both hits")
	_check(_approx(session.combo_total_damage, 20.7), "route damage is 10.1 + 10.6 with the B-starter layers")
	var float_state: Array = combo_state_after_frame[44]
	_check(float_state[0] and float_state[1] == MoveData.StarterGrade.B
		and _approx(float_state[2], 0.756) and _approx(float_state[3], 0.7708) and _approx(float_state[4], 0.8075),
		"the starter grade and all three correction layers persist through the low float")
	_check(float_state[5] == CombatSession.DummyState.LOW_FLOAT_SWEEP, "the dummy is still in the low float on the frame before touchdown")
	var knockdown_state: Array = combo_state_after_frame[45]
	_check(knockdown_state[5] == CombatSession.DummyState.KNOCKED_DOWN and not knockdown_state[0]
		and knockdown_state[1] == MoveData.StarterGrade.UNSET
		and knockdown_state[2] == 1.0 and knockdown_state[3] == 1.0 and knockdown_state[4] == 1.0,
		"entering the knockdown ends the combo and clears the starter grade and correction layers")
	_check(_combo_end_events(events, CombatEvent.ComboEndReason.KNOCKDOWN) == 1,
		"the touchdown frame reports the combo end with the KNOCKDOWN reason (motion phase runs before the cancel-window close)")
	_check(_count_events(events, CombatEvent.Type.DUMMY_RECOVERED) == 1, "the dummy recovers naturally after the knockdown")


func _test_2C_whiff_no_low_float() -> void:
	# 木桩在 2C 判定外：挥空不产生接触、取消年龄或受击状态——低浮空只在
	# 实际命中 grounded 目标时出现。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(200, 0)
	var events: Array[CombatEvent] = []
	for frame in range(1, 45):
		var key := "C" if frame == 1 else ""
		events.append_array(session.step(FrameInput.make(0, false, key, true)))
	_check(_count_events(events, CombatEvent.Type.HIT) == 0 and _count_events(events, CombatEvent.Type.HIT_MISS) == 0,
		"a whiffed 2C produces no contact events at all")
	_check(session.dummy_state == CombatSession.DummyState.NEUTRAL and not session.combo_active,
		"the whiffed sweep leaves the dummy neutral without starting a combo")
	_check(_count_events(events, CombatEvent.Type.LOW_FLOAT_LANDED) == 0,
		"a whiffed 2C never raises the low-float or touchdown events")
	_check(session.player_phase == CombatSession.PlayerPhase.NEUTRAL and session.player_move_id == "",
		"the whiffed sweep finishes its full recovery back to neutral")


func _test_2C_airborne_target_miss_no_profile() -> void:
	# 2C 只声明 grounded 资料：命中判定前的目标状态是 AIRBORNE 时按精确键
	# 查找失败（MISS_NO_PROFILE）——不回退 grounded 资料、不改受击状态。
	# 探针表：6A 链式取消进 2C，2C 判定框放大到覆盖浮空段几何（几何注入只为
	# 命中资料键行为的可观察性，不是共享表调校值）。
	var table := MoveData.default_table()
	var six_a := table["6A"] as MoveData
	six_a.chain_cancel_targets = ["2C"]
	six_a.chain_cancel_window_frames = 3
	var two_c := table["2C"] as MoveData
	two_c.hitbox_size = Vector2(52, 180)
	var session := CombatSession.new(table)
	session.dummy_position = session.player_position + Vector2(70, 0)
	var events: Array[CombatEvent] = []
	var state_after_frame := {}
	for frame in range(1, 40):
		var key := ""
		if frame == 2:
			key = "A"
		elif frame == 10:
			key = "C"
		var down := frame >= 10
		var frame_events := session.step(FrameInput.make(1 if frame == 1 else 0, false, key, down))
		events.append_array(frame_events)
		state_after_frame[frame] = session.dummy_state
	_check(_count_events(events, CombatEvent.Type.HIT) == 1, "only the 6A launcher connects")
	_check(_count_events(events, CombatEvent.Type.HIT_MISS) == 1,
		"2C against the airborne target reports MISS_NO_PROFILE (no AIRBORNE key declared)")
	_check(state_after_frame[29] == CombatSession.DummyState.AIR_HITSTUN,
		"the miss does not overwrite the launcher's air hitstun with any grounded result")
	_check(_count_events(events, CombatEvent.Type.LOW_FLOAT_LANDED) == 0,
		"no low float appears from the missed sweep")


func _test_2C_then_5D_fails_and_no_otg() -> void:
	# 2C 命中后缓存的 5D 在取消窗口关闭当帧（F30）按 CONFIGURATION_GAP 报告
	# （2C 未声明到 5D 的普通连接边）；停顿顺延使 2C 完全恢复落在 F41，F38 重按的
	# D 以独立招式起手（F42），判定窗口 F49–F52 全部落在普通倒地上——不命中、
	# 不刷新倒地计时（F58 恢复不受影响）。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var events: Array[CombatEvent] = []
	var recovered_frame := -1
	var move_after_frame := {}
	for frame in range(1, 62):
		var key := ""
		if frame == 1:
			key = "C"
		elif frame == 30 or frame == 38:
			key = "D"
		var frame_events := session.step(FrameInput.make(0, false, key, frame == 1))
		events.append_array(frame_events)
		move_after_frame[frame] = session.player_move_id
		for event in frame_events:
			if event.type == CombatEvent.Type.DUMMY_RECOVERED:
				recovered_frame = frame
	_check(_count_events(events, CombatEvent.Type.HIT) == 1, "only the 2C itself lands")
	var gaps := _events_of(events, CombatEvent.Type.LINK_FAILED)
	_check(gaps.size() == 1 and gaps[0].link_fail_reason == CombatEvent.LinkFailReason.CONFIGURATION_GAP
		and gaps[0].link_move_id == "5D",
		"the buffered 5D after 2C is reported as an undeclared link edge when the cancel window closes")
	_check(move_after_frame[42] == "5D", "the 5D still starts independently after the sweep recovery")
	_check(_count_events(events, CombatEvent.Type.HIT) == 1 and recovered_frame == 58,
		"the independent 5D cannot hit the knocked-down dummy and never refreshes the knockdown timer (recovery stays at F58)")
	_check(session.dummy_state == CombatSession.DummyState.NEUTRAL and not session.combo_active,
		"the session settles back to neutral after the failed pursuit")


# --- 木桩防御与被防取消（票据 03）---

## 带木桩防御请求的帧输入：guard 取 GuardPosture 值（0 无 / 1 站 / 2 蹲 / 3 空）。
func _guard_input(key: String, guard: int, down := false, axis := 0) -> FrameInput:
	var input := FrameInput.make(axis, false, key, down)
	input.dummy_guard_request = guard
	return input


## 探针招式的被防结果声明（D-02/D-03 三字段）。
func _set_probe_block(move: MoveData, freeze: int, stun: int, pushback: float) -> void:
	move.block_freeze_frames = freeze
	move.block_stun_frames = stun
	move.block_pushback_px_s = pushback


func _test_dummy_guard_request_drives_posture() -> void:
	# 逐帧显式请求驱动木桩防御姿态；NONE 不防御；木桩出招期间请求不成立
	# （BUSY 可观察拒绝），木桩无自主决策。
	var session := CombatSession.new()
	session.step(_guard_input("", CombatSession.GuardPosture.STANDING))
	_check(session.dummy_guard == CombatSession.GuardPosture.STANDING,
		"a STAND request puts the grounded dummy into standing guard")
	session.step(_guard_input("", CombatSession.GuardPosture.CROUCH))
	_check(session.dummy_guard == CombatSession.GuardPosture.CROUCH,
		"a CROUCH request switches the dummy into crouch guard the same frame")
	session.step(_guard_input("", CombatSession.GuardPosture.NONE))
	_check(session.dummy_guard == CombatSession.GuardPosture.NONE,
		"a NONE request stops guarding without any fallback")
	var attack := FrameInput.make(0, false, "", false)
	attack.dummy_guard_request = CombatSession.GuardPosture.STANDING
	attack.dummy_move_request = "5A"
	session.step(attack)
	_check(session.dummy_move_id == "5A" and session.dummy_guard == CombatSession.GuardPosture.NONE,
		"starting the requested attack replaces the guard posture (no guarding while attacking)")
	var follow_events := session.step(_guard_input("", CombatSession.GuardPosture.STANDING))
	_check(session.dummy_move_id == "5A" and session.dummy_guard == CombatSession.GuardPosture.NONE,
		"the dummy cannot guard while executing its own requested attack (guard stays down)")
	var rejects := _events_of(follow_events, CombatEvent.Type.DUMMY_GUARD_REJECTED)
	_check(rejects.size() == 1 and rejects[0].guard_reject_reason == CombatEvent.DummyGuardRejectReason.BUSY,
		"the guard request during the dummy move is rejected with the observable BUSY reason")


func _test_dummy_guard_rejections_observable() -> void:
	# 地面木桩收到 AIR：请求不成立（STATE），不静默回退为任何地面防御；
	# 空中木桩收到 STAND 同为 STATE；空中受击中收到 AIR 是 BUSY——原因可区分。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var events: Array[CombatEvent] = []
	var guard_after := {}
	for frame in range(1, 6):
		events.append_array(session.step(_guard_input("", CombatSession.GuardPosture.AIR)))
		guard_after[frame] = session.dummy_guard
	var rejects := _events_of(events, CombatEvent.Type.DUMMY_GUARD_REJECTED)
	_check(rejects.size() == 5 and rejects[0].guard_reject_reason == CombatEvent.DummyGuardRejectReason.STATE,
		"an AIR request on the grounded dummy is rejected every frame with the STATE reason")
	_check(guard_after[5] == CombatSession.GuardPosture.NONE,
		"the mismatched AIR request never silently becomes any ground guard")
	# 236C 两段命中把木桩打入浮空（段 2 F26 空中延长）：F37–F40 请求 STAND
	# （状态不符）→ STATE；F41–F43 请求 AIR（姿态匹配但受击占用）→ BUSY。
	var launch_events: Array[CombatEvent] = []
	for frame in range(1, 46):
		var digit := 5
		var key := ""
		if frame == 1:
			digit = 2
		elif frame == 2:
			digit = 3
		elif frame == 3:
			digit = 6
		elif frame == 4:
			key = "C"
		var request := CombatSession.GuardPosture.NONE
		# 票据 05：段 2 于 F26 命中（空中延长）、停顿 F27–F34；F37–F40 的 STAND
		# 落在延长后的滞空段，F41–F43 的 AIR 落在受击占用段。
		if frame >= 37 and frame <= 40:
			request = CombatSession.GuardPosture.STANDING
		elif frame >= 41 and frame <= 43:
			request = CombatSession.GuardPosture.AIR
		var input := _relative_input(session, digit, key)
		input.dummy_guard_request = request
		launch_events.append_array(session.step(input))
	var state_rejects := 0
	var busy_rejects := 0
	for event in launch_events:
		if event.type == CombatEvent.Type.DUMMY_GUARD_REJECTED:
			if event.guard_reject_reason == CombatEvent.DummyGuardRejectReason.STATE:
				state_rejects += 1
			elif event.guard_reject_reason == CombatEvent.DummyGuardRejectReason.BUSY:
				busy_rejects += 1
	_check(state_rejects == 4, "STAND requests on the airborne dummy report the STATE mismatch (4 frames)")
	_check(busy_rejects == 3, "AIR requests while airborne in hitstun report the BUSY reason (3 frames)")


func _test_player_attack_blocked_independent_result() -> void:
	# 5A 被站防：ATTACK_BLOCKED 记录方向与姿态；被防停顿/硬直/推退独立结算，
	# 不读 HitProfile、不掉血、不起连段、不锁 starter、不累计三层修正。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(60, 0)
	var events: Array[CombatEvent] = []
	var blockstun_after := {}
	var guard_after := {}
	var pushback_velocity := 0.0
	var state_at_contact := {}
	var player_x := session.player_position.x
	var dummy_x := session.dummy_position.x
	var dummy_pushed_away := false
	for frame in range(1, 30):
		var key := "A" if frame == 1 else ""
		var frame_events := session.step(_guard_input(key, CombatSession.GuardPosture.STANDING))
		events.append_array(frame_events)
		blockstun_after[frame] = session.dummy_blockstun_left
		guard_after[frame] = session.dummy_guard
		if frame == 6:
			state_at_contact = session.settlement_state()
			pushback_velocity = session.dummy_velocity.x
		if frame == 20:
			dummy_pushed_away = session.dummy_position.x > dummy_x and session.player_position.x <= player_x
	var blocked := _events_of(events, CombatEvent.Type.ATTACK_BLOCKED)
	_check(blocked.size() == 1, "the guarded 5A raises exactly one ATTACK_BLOCKED contact event")
	_check(blocked[0].direction == 1 and blocked[0].guard_posture == CombatSession.GuardPosture.STANDING,
		"the blocked event records the attack direction and the guarding posture")
	_check(blocked[0].block_freeze_frames == 8 and blocked[0].block_stun_frames == 9
		and _approx(blocked[0].block_pushback_px_s, 45.0),
		"the blocked event carries the declared block freeze/stun/pushback values")
	_check(_count_events(events, CombatEvent.Type.HIT) == 0,
		"a blocked contact never reports a HIT event")
	_check(_count_events(events, CombatEvent.Type.HITSTOP_STARTED) == 1,
		"the blocked contact still opens exactly one freeze window (declared block freeze)")
	_check(session.dummy_hp == GameParams.DUMMY_MAX_HP and not session.combo_active and session.combo_hits == 0,
		"a blocked attack deals no damage and never starts a combo")
	_check(session.combo_starter_grade == MoveData.StarterGrade.UNSET
		and _approx(session.combo_damage_scale, 1.0) and _approx(session.combo_time_scale, 1.0)
		and _approx(session.combo_trajectory_scale, 1.0),
		"a blocked contact locks no starter grade and accumulates no correction layer")
	_check(blockstun_after[6] == 9, "the defender enters the declared 9f blockstun on the contact frame")
	_check(blockstun_after[14] == 9 and blockstun_after[15] == 8,
		"the blockstun timer stays frozen through the 8 freeze frames, then ticks on normal frames")
	_check(guard_after[23] == CombatSession.GuardPosture.STANDING,
		"the blockstun keeps the guarding posture frozen (block strings hold the guard)")
	_check(pushback_velocity > 0.0,
		"the contact frame leaves the defender with pushback velocity away from the attacker")
	_check(dummy_pushed_away, "after the freeze the defender is actually pushed away in space")
	_check(state_at_contact.get("move_blocked", false) == true and int(state_at_contact.get("contact_age", -1)) == 0,
		"the settlement snapshot exposes the blocked contact with a contact age for solver state keys")


func _test_dummy_guard_attribute_leak_matrix() -> void:
	# 木桩侧与玩家同一属性矩阵：站防漏 low（2A 命中）、蹲防挡 low（2A 被防）、
	# mid（5A）两种姿态都挡。
	var outcomes := {}
	for row in [["STAND_2A", CombatSession.GuardPosture.STANDING, true],
			["CROUCH_2A", CombatSession.GuardPosture.CROUCH, true],
			["STAND_5A", CombatSession.GuardPosture.STANDING, false]]:
		var session := CombatSession.new()
		session.dummy_position = session.player_position + Vector2(60, 0)
		var events: Array[CombatEvent] = []
		for frame in range(1, 12):
			var key := "A" if frame == 1 else ""
			events.append_array(session.step(_guard_input(key, int(row[1]), bool(row[2]))))
		outcomes[row[0]] = [
			_count_events(events, CombatEvent.Type.HIT),
			_count_events(events, CombatEvent.Type.ATTACK_BLOCKED),
		]
	_check(outcomes["STAND_2A"][0] == 1 and outcomes["STAND_2A"][1] == 0,
		"the standing guard leaks low: 2A hits through it")
	_check(outcomes["CROUCH_2A"][0] == 0 and outcomes["CROUCH_2A"][1] == 1,
		"the crouch guard blocks the low 2A")
	_check(outcomes["STAND_5A"][0] == 0 and outcomes["STAND_5A"][1] == 1,
		"the standing guard blocks the mid 5A")


func _test_blocked_contact_opens_chain_and_special_cancels() -> void:
	# 被防接触开放配置的链式/必杀取消：5A 被防后同窗口内 5B（链）与 236C（必杀）
	# 都能起手并再次被防——被防不当命中、不断连段。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(60, 0)
	var events: Array[CombatEvent] = []
	var move_after := {}
	for frame in range(1, 30):
		var key := ""
		if frame == 1:
			key = "A"
		elif frame == 6:
			key = "B"
		events.append_array(session.step(_guard_input(key, CombatSession.GuardPosture.STANDING)))
		move_after[frame] = session.player_move_id
	_check(_count_events(events, CombatEvent.Type.ATTACK_BLOCKED) == 2
		and _count_events(events, CombatEvent.Type.HIT) == 0,
		"5A blocked → chain-cancelled 5B is blocked again (two contacts, zero hits)")
	_check(move_after[15] == "5B",
		"the buffered B starts 5B as a chain cancel right after the freeze (within the contact window)")
	_check(move_after[14] == "5A",
		"the cancel starts before the first 5A finished recovering (a cancel, not a wait for recovery)")
	# 必杀取消：停顿中喂 236 方向并在停顿内按 C——恢复首个正常帧后 236C 起手并被防。
	var session2 := CombatSession.new()
	session2.dummy_position = session2.player_position + Vector2(60, 0)
	var events2: Array[CombatEvent] = []
	var move_after2 := {}
	for frame in range(1, 34):
		var digit := 5
		var key := ""
		if frame == 1:
			key = "A"
		elif frame == 7:
			digit = 2
		elif frame == 8:
			digit = 3
		elif frame == 9:
			digit = 6
		elif frame == 13:
			key = "C"
		var input := _relative_input(session2, digit, key)
		input.dummy_guard_request = CombatSession.GuardPosture.STANDING
		events2.append_array(session2.step(input))
		move_after2[frame] = session2.player_move_id
	_check(move_after2[16] == "236C",
		"the buffered C starts 236C as a special cancel after the freeze (within the contact window)")
	_check(_count_events(events2, CombatEvent.Type.ATTACK_BLOCKED) == 2
		and _count_events(events2, CombatEvent.Type.HIT) == 0,
		"both the 5A and the cancelled 236C are blocked by the standing guard")


func _test_blocked_denies_hit_confirm_and_jump_cancel() -> void:
	# 被防只开链式：命中确认目标 5X 不因被防起手，Space 不因被防 jump cancel；
	# 同一被防接触下链式 5B 仍然成立（分支选择性的正反对照）。
	var table := {
		"5A": _probe_move("5A", "A"),
		"5X": _probe_move("5X", "X"),
		"5B": _probe_move("5B", "B"),
	}
	var five := table["5A"] as MoveData
	five.cancel_targets = ["5X"]
	five.chain_cancel_targets = ["5B"]
	five.chain_cancel_window_frames = 3
	five.jump_cancel_targets = ["jA"]
	_set_probe_block(five, 2, 4, 0.0)
	_set_probe_block(table["5X"] as MoveData, 2, 4, 0.0)
	_set_probe_block(table["5B"] as MoveData, 2, 4, 0.0)
	var session := CombatSession.new(table)
	session.dummy_position = session.player_position + Vector2(60, 0)
	var events: Array[CombatEvent] = []
	var move_ids: Array = []
	var prejump_values: Array = []
	for frame in range(1, 32):
		var key := ""
		var jump := false
		if frame == 1:
			key = "A"
		elif frame == 7:
			key = "X"
		elif frame == 8:
			jump = true
		elif frame == 9:
			key = "B"
		var input := _guard_input(key, CombatSession.GuardPosture.STANDING)
		input.jump_pressed = jump
		input.up_held = jump
		events.append_array(session.step(input))
		move_ids.append(session.player_move_id)
		prejump_values.append(session.player_prejump_left)
	# 探针 5A（5/7/13）F1 起手、F6 被防、停顿 F7–F8、F9 恢复首个正常帧。
	_check(not move_ids.has("5X"),
		"the hit-confirm-only target 5X never starts from the blocked contact")
	_check(_range_all(prejump_values, 0, 30, 0),
		"Space never opens a jump cancel on a blocked contact")
	_check(move_ids[8] == "5B",
		"the chain-configured 5B still starts from the same blocked contact")
	_check(_count_events(events, CombatEvent.Type.ATTACK_BLOCKED) == 2
		and _count_events(events, CombatEvent.Type.HIT) == 0,
		"both contacts are blocked and neither counts as a hit")


func _test_whiff_still_cannot_cancel() -> void:
	# 挥空没有接触：不产生取消年龄、不开任何取消目标；窗口内缓存的 B 过期作废。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(200, 0)
	var events: Array[CombatEvent] = []
	var move_ids: Array = []
	var cancel_open_values: Array = []
	var cancel_age_at_six := -2
	for frame in range(1, 40):
		var key := ""
		if frame == 1:
			key = "A"
		elif frame == 6:
			key = "B"
		events.append_array(session.step(FrameInput.make(0, false, key)))
		move_ids.append(session.player_move_id)
		var snap := session.debug_snapshot()
		cancel_open_values.append(bool(snap["cancel_open"]))
		if frame == 6:
			cancel_age_at_six = int(snap["cancel_age"])
	_check(_count_events(events, CombatEvent.Type.ATTACK_BLOCKED) == 0
		and _count_events(events, CombatEvent.Type.HIT) == 0,
		"a whiff produces neither a hit nor a blocked contact")
	_check(not move_ids.has("5B"),
		"the buffered B expires without ever starting a cancel")
	var cancel_never_open := true
	for opened in cancel_open_values:
		cancel_never_open = cancel_never_open and not opened
	_check(cancel_never_open and cancel_age_at_six == -1,
		"the whiffed move never opens a cancel window or a cancel age")


func _test_blockstun_locks_dummy_actions_and_holds_guard() -> void:
	# 被防硬直期间木桩不能按请求出招（反击时点观察口）；硬直结束后的首个输入帧
	# 请求生效。连防：被防硬直内姿态冻结，后续攻击再次被防。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(60, 0)
	var dummy_move_ids: Array = []
	for frame in range(1, 26):
		var input := _guard_input("A" if frame == 1 else "", CombatSession.GuardPosture.STANDING)
		if frame >= 15:
			input.dummy_move_request = "5A"
		session.step(input)
		dummy_move_ids.append(session.dummy_move_id)
	_check(_range_all(dummy_move_ids, 14, 22, ""),
		"the blockstunned dummy cannot start the requested counter before the stun ends")
	_check(dummy_move_ids[23] == "5A",
		"the requested counter starts on the first input frame after the blockstun")
	var session2 := CombatSession.new()
	session2.dummy_position = session2.player_position + Vector2(60, 0)
	var events: Array[CombatEvent] = []
	var guard_always_held := true
	## 被防停顿顺延恢复：第一记 5A 到 F28 才收招，第二记 F32 起手、F37 接触。
	for frame in range(1, 46):
		var key := ""
		if frame == 1 or frame == 32:
			key = "A"
		events.append_array(session2.step(_guard_input(key, CombatSession.GuardPosture.STANDING)))
		guard_always_held = guard_always_held and session2.dummy_guard == CombatSession.GuardPosture.STANDING
	_check(_count_events(events, CombatEvent.Type.ATTACK_BLOCKED) == 2,
		"the second 5A is also blocked while the guard request is held (block string)")
	_check(guard_always_held,
		"the guard posture stays observable through the whole block string")


func _test_blocked_then_guard_release_hits_fresh() -> void:
	# 站防请求在被防硬直内停止：姿态冻结到硬直结束才落地 NONE；随后同一招正常
	# 命中——命中/被防两分支在同一站位可切换复现。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(60, 0)
	var events: Array[CombatEvent] = []
	var guard_after := {}
	for frame in range(1, 42):
		var key := ""
		if frame == 1 or frame == 30:
			key = "A"
		var request := CombatSession.GuardPosture.STANDING if frame <= 14 else CombatSession.GuardPosture.NONE
		events.append_array(session.step(_guard_input(key, request)))
		guard_after[frame] = session.dummy_guard
	_check(guard_after[20] == CombatSession.GuardPosture.STANDING and guard_after[24] == CombatSession.GuardPosture.NONE,
		"releasing the request during blockstun keeps the posture frozen until the stun ends")
	_check(_count_events(events, CombatEvent.Type.ATTACK_BLOCKED) == 1
		and _count_events(events, CombatEvent.Type.HIT) == 1,
		"the first 5A is blocked and the second, after the release, lands a clean hit")
	_check(session.combo_hits == 1 and session.combo_starter_grade == MoveData.StarterGrade.A,
		"the fresh hit starts a new combo and locks its own starter grade")


func _test_undeclared_block_fields_default_deny() -> void:
	# 未声明被防结果的招式不可被防（默认禁止）：木桩保持站防姿态，攻击照常命中。
	var session := CombatSession.new({"5A": _probe_move("5A", "A")})
	session.dummy_position = session.player_position + Vector2(60, 0)
	var events: Array[CombatEvent] = []
	for frame in range(1, 12):
		var key := "A" if frame == 1 else ""
		events.append_array(session.step(_guard_input(key, CombatSession.GuardPosture.STANDING)))
	_check(_count_events(events, CombatEvent.Type.HIT) == 1
		and _count_events(events, CombatEvent.Type.ATTACK_BLOCKED) == 0,
		"an undeclared block result denies blocking: the attack hits through the guard")
	_check(session.dummy_guard == CombatSession.GuardPosture.STANDING,
		"the guard posture itself stays observable even while the move is unblockable")


func _test_blocked_freeze_uses_declared_frames() -> void:
	# 被防停顿读取招式声明的 3f，不沿用命中 Hitstop 的 8f；停顿结束后的首帧即恢复
	# 被防硬直倒数。300px/s 推退让双方位移都大到可观察（45px/s 初值下攻击方推退
	# 在接触当帧被摩擦抵消，见共享表测试）。
	var table := {"5A": _probe_move("5A", "A")}
	_set_probe_block(table["5A"] as MoveData, 3, 5, 300.0)
	var session := CombatSession.new(table)
	session.dummy_position = session.player_position + Vector2(60, 0)
	var events: Array[CombatEvent] = []
	var blockstun_after := {}
	var hitstop_after := {}
	var player_x := session.player_position.x
	var dummy_x := session.dummy_position.x
	for frame in range(1, 16):
		var key := "A" if frame == 1 else ""
		events.append_array(session.step(_guard_input(key, CombatSession.GuardPosture.STANDING)))
		blockstun_after[frame] = session.dummy_blockstun_left
		hitstop_after[frame] = session.debug_snapshot()["hitstop_left"]
	_check(hitstop_after[6] == 3 and hitstop_after[8] == 1 and hitstop_after[9] == 0,
		"the block freeze lasts exactly the declared 3 frames (not the 8f hit hitstop)")
	_check(blockstun_after[9] == 5 and blockstun_after[10] == 4,
		"the blockstun ticks again from the first normal frame after the freeze")
	_check(session.dummy_position.x > dummy_x + 5.0 and session.player_position.x < player_x - 5.0,
		"the declared 300px/s pushback visibly separates both sides after the freeze")


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

func _test_crouch_entry_and_stationary_movement() -> void:
	# 2026-09-18 真人反馈：1/2/3 当帧蹲下并停止行走；离开下方向当帧站起；
	# 4 为站防且保留后退行走，原始方向仍用于蹲防和搓招。
	var crouch3 := CombatSession.new()
	var crouched_on_press := false
	var x_after := 0.0
	for frame in range(1, 16):
		crouch3.step(_relative_input(crouch3, 3))
		if frame == 1:
			crouched_on_press = crouch3.player_crouching
		x_after = crouch3.player_position.x
	_check(crouched_on_press, "holding 3 enters crouch on the same frame")
	_check(crouch3.player_crouching, "holding 3 keeps crouching")
	_check(is_equal_approx(x_after, GameParams.PLAYER_SPAWN_X), "holding 3 crouches without moving forward")
	_check(crouch3.player_guard == CombatSession.GuardPosture.NONE, "3 is not a guard direction")

	var crouch2 := CombatSession.new()
	for frame in range(1, 6):
		crouch2.step(_relative_input(crouch2, 2))
	_check(crouch2.player_crouching, "holding 2 crouches in place")
	_check(is_equal_approx(crouch2.player_position.x, GameParams.PLAYER_SPAWN_X), "holding 2 crouches without moving")

	var crouch1 := CombatSession.new()
	for frame in range(1, 16):
		crouch1.step(_relative_input(crouch1, 1))
	_check(crouch1.player_crouching and crouch1.player_guard == CombatSession.GuardPosture.CROUCH,
		"1 enters the crouch-guard posture")
	_check(is_equal_approx(crouch1.player_position.x, GameParams.PLAYER_SPAWN_X), "holding 1 crouch-guards without moving backward")

	var stand := CombatSession.new()
	stand.step(_relative_input(stand, 2))
	stand.step(_relative_input(stand, 6))
	_check(stand.player_crouching == false, "leaving the down direction stands up on the same frame")

	var back := CombatSession.new()
	for frame in range(1, 16):
		back.step(_relative_input(back, 4))
	_check(back.player_guard == CombatSession.GuardPosture.STANDING and not back.player_crouching,
		"4 guards standing without crouching")
	_check(back.player_position.x < GameParams.PLAYER_SPAWN_X - 25.0, "standing guard keeps the backward walk of 4")


func _test_guard_postures_ground_air_prejump() -> void:
	# 防御姿态（issue 16）：地面 4 为站防、1 为蹲防，其余方向不防御；真正离地后
	# 4/1 均为空防且 1 的下方向不再形成蹲下；pre-jump 四帧与离地当帧不新进入防御。
	var ground4 := CombatSession.new()
	ground4.step(_relative_input(ground4, 4))
	_check(ground4.player_guard == CombatSession.GuardPosture.STANDING, "ground 4 is the standing guard")
	var ground1 := CombatSession.new()
	ground1.step(_relative_input(ground1, 1))
	_check(ground1.player_guard == CombatSession.GuardPosture.CROUCH, "ground 1 is the crouch guard")
	for digit in [5, 2, 3, 6, 8]:
		var probe := CombatSession.new()
		probe.step(_relative_input(probe, digit))
		_check(probe.player_guard == CombatSession.GuardPosture.NONE, "ground digit %d does not guard" % digit)

	# 右面向垂直跳（木桩在右）：按住 4 贯穿准备与滞空。F1–F4 准备、F5 离地当帧
	# 均不防御；F6 起真正离地后进入空防。
	var air := CombatSession.new()
	var guard_frames: Array[int] = []
	for frame in range(1, 9):
		air.step(FrameInput.make(-1, frame == 1, "", false))
		guard_frames.append(air.player_guard)
	_check(guard_frames[0] == CombatSession.GuardPosture.NONE and guard_frames[4] == CombatSession.GuardPosture.NONE,
		"pre-jump frames and the takeoff frame never newly enter guard")
	_check(guard_frames[5] == CombatSession.GuardPosture.AIR and guard_frames[7] == CombatSession.GuardPosture.AIR,
		"4 becomes the air guard once truly airborne")

	# 空中 1：空防 + 下方向只保留运动输入（不蹲下）。
	var air_one := CombatSession.new()
	for frame in range(1, 8):
		air_one.step(FrameInput.make(-1, frame == 1, "", frame >= 6))
	_check(air_one.player_guard == CombatSession.GuardPosture.AIR and not air_one.player_crouching,
		"air 1 is the air guard and the down component forms no crouch")


func _test_dummy_attack_lifecycle_observable() -> void:
	# 木桩确定性攻击（issue 16）：请求当帧起手（请求帧为第 1 帧），阶段窗口与
	# 命中框可观察；射程外挥空不产生事件；木桩被玩家命中时攻击被打断（后续不再
	# 连接玩家）。
	var strike := _dummy_strike("D_H", MoveData.AttackAttribute.HIGH, false)
	var session := CombatSession.new({"D_H": strike})
	session.dummy_position = Vector2(900.0, GameParams.ground_stand_y())
	var phases: Array[int] = []
	var any_event := false
	var rect_only_in_active := true
	var started_on_request_frame := false
	for frame in range(1, 10):
		var events := session.step(_relative_input(session, 5, "", "D_H" if frame == 1 else ""))
		any_event = any_event or not events.is_empty()
		phases.append(session.dummy_phase)
		if frame == 1:
			started_on_request_frame = session.dummy_move_id == "D_H"
		rect_only_in_active = rect_only_in_active \
			and (session.dummy_phase != CombatSession.PlayerPhase.ACTIVE or session.dummy_attack_rect().has_area())
	_check(started_on_request_frame and phases[0] == CombatSession.PlayerPhase.STARTUP,
		"the request starts the dummy move on the same frame (first startup frame)")
	_check(_phase_range(phases, 1, 4, CombatSession.PlayerPhase.ACTIVE), "dummy active window follows its own data (frames 2-5)")
	_check(_phase_range(phases, 5, 7, CombatSession.PlayerPhase.RECOVERY), "dummy recovery window follows its own data")
	_check(phases[8] == CombatSession.PlayerPhase.NEUTRAL and session.dummy_move_id == "",
		"dummy returns to neutral after its total frames")
	_check(rect_only_in_active, "dummy attack rect exists only while active")
	_check(not any_event and session.dummy_hp == GameParams.DUMMY_MAX_HP, "an out-of-range dummy attack produces no events")

	# 木桩出招被打断：慢速攻击（前摇 8）尚未进入判定即被 5A 命中，攻击清除、
	# 之后不再连接玩家。
	var slow := _dummy_strike("D_S", MoveData.AttackAttribute.HIGH, false)
	slow.startup_frames = 8
	var interrupt := CombatSession.new({"D_S": slow, "5A": _probe_move("5A", "A")})
	interrupt.dummy_position = interrupt.player_position + Vector2(70, 0)
	var player_hits := 0
	var player_got_hit := 0
	for frame in range(1, 16):
		var events := interrupt.step(_relative_input(interrupt, 5, "A" if frame == 1 else "", "D_S" if frame == 1 else ""))
		player_hits += _count_events(events, CombatEvent.Type.HIT)
		player_got_hit += _count_events(events, CombatEvent.Type.PLAYER_HIT)
		if frame == 6:
			_check(interrupt.dummy_move_id == "", "the dummy attack is cleared the frame the player's hit lands")
	_check(player_hits == 1, "the player's attack lands once on the attacking dummy")
	_check(player_got_hit == 0, "the interrupted dummy attack never connects with the player")


## 属性矩阵单格：玩家全程按 digit 姿态输入，F1 附带木桩攻击请求（前摇 2 → F3
## 连接）；返回 "blocked"/"hit"/"none"。
func _matrix_outcome(move_id: String, digit: int) -> String:
	var session := CombatSession.new(_dummy_attribute_table())
	session.dummy_position = session.player_position + Vector2(70, 0)
	return _run_matrix_case(session, move_id, digit, 1)


## 空中矩阵单格：F1 起跳（面向右、按住 4），F7 附带木桩攻击请求；返回结果同上。
func _air_matrix_outcome(move_id: String) -> String:
	var session := CombatSession.new(_dummy_attribute_table())
	session.dummy_position = session.player_position + Vector2(70, 0)
	return _run_matrix_case(session, move_id, 4, 7, true)


func _run_matrix_case(session: CombatSession, move_id: String, digit: int, request_frame: int, jump_start := false) -> String:
	var result := "none"
	for frame in range(1, 13):
		var input: FrameInput
		if jump_start:
			input = FrameInput.make(-1, frame == 1, "", false)
		else:
			input = _relative_input(session, digit)
		if frame == request_frame:
			input.dummy_move_request = move_id
		var events := session.step(input)
		for event in events:
			if event.type == CombatEvent.Type.BLOCKED:
				result = "blocked"
			elif event.type == CombatEvent.Type.PLAYER_HIT:
				result = "hit"
	return result


func _test_guard_attribute_matrix() -> void:
	# 属性矩阵（issue 16）：站防挡 high/mid/overhead、漏 low；蹲防挡 high/mid/low、
	# 漏 overhead；空防默认挡带 air 的打击、漏纯地面属性；无姿态全漏。
	# 判定全部来自显式数据（攻击属性 + 正交 air 标记），不以姿态猜测。
	_check(_matrix_outcome("D_H", 4) == "blocked", "standing guard blocks high")
	_check(_matrix_outcome("D_M", 4) == "blocked", "standing guard blocks mid")
	_check(_matrix_outcome("D_O", 4) == "blocked", "standing guard blocks overhead")
	_check(_matrix_outcome("D_L", 4) == "hit", "standing guard is hit by low")
	_check(_matrix_outcome("D_H", 1) == "blocked", "crouch guard blocks high")
	_check(_matrix_outcome("D_M", 1) == "blocked", "crouch guard blocks mid")
	_check(_matrix_outcome("D_L", 1) == "blocked", "crouch guard blocks low")
	_check(_matrix_outcome("D_O", 1) == "hit", "crouch guard is hit by overhead")
	_check(_matrix_outcome("D_H", 5) == "hit", "no posture is hit by high")
	_check(_air_matrix_outcome("D_A") == "blocked", "air guard blocks an air-flagged strike by default")
	_check(_air_matrix_outcome("D_H") == "hit", "air guard is hit by a pure ground attribute")


func _test_block_guard_stun_hitstop_repeatable() -> void:
	# 防御命中（issue 16）：挡下当帧 BLOCKED 事件 + 防御硬直（= 打击 hitstun）+
	# 随后 8 帧停顿冻结双方（硬直不倒数、木桩招式不推进）；停顿后逐帧倒数；
	# 硬直期间不可出招、不可起跳；同一场景重跑事件序列一致（可重复观察）。
	# 短窗口攻击（2/1/1 共 4 帧）：若不停顿，F4 就应收招——以 dummy_move_id 的
	# 存续证明停顿冻结了木桩反馈。
	var run := func() -> Dictionary:
		var strike := _dummy_strike("D_H", MoveData.AttackAttribute.HIGH, false)
		strike.active_frames = 1
		strike.recovery_frames = 1
		var session := CombatSession.new({"D_H": strike})
		session.dummy_position = session.player_position + Vector2(70, 0)
		var block_frames: Array[int] = []
		var stun_counts: Array[int] = []
		var dummy_move_alive: Array[bool] = []
		for frame in range(1, 23):
			## F5 按下动作键 A、F7 按下 Space：验证防御硬直期间不可出招、不可起跳
			## （只记录不起手）。
			var key := "A" if frame == 5 else ""
			var input := _relative_input(session, 4, key, "D_H" if frame == 1 else "")
			if frame == 7:
				input.jump_pressed = true
			var events := session.step(input)
			block_frames.append(_count_events(events, CombatEvent.Type.BLOCKED))
			stun_counts.append(session.player_guard_stun_left)
			dummy_move_alive.append(session.dummy_move_id != "")
		return {"block_frames": block_frames, "stun_counts": stun_counts, "dummy_move_alive": dummy_move_alive, "session": session}
	var first: Dictionary = run.call()
	var second: Dictionary = run.call()
	_check(first["block_frames"] == second["block_frames"] and first["stun_counts"] == second["stun_counts"],
		"the same blocking scenario replays identically (repeatable observability)")
	var blocks: Array[int] = first["block_frames"]
	var stuns: Array[int] = first["stun_counts"]
	var alive: Array[bool] = first["dummy_move_alive"]
	_check(blocks[2] == 1 and blocks.count(1) == 1, "exactly one BLOCKED event lands on the connect frame (F3)")
	_check((first["session"] as CombatSession).player_hitstun_left == 0 and (first["session"] as CombatSession).dummy_hp == GameParams.DUMMY_MAX_HP,
		"a blocked strike deals no hitstun and no dummy-side damage")
	_check(stuns[2] == 10, "guard stun starts at the strike's own hitstun frames (10)")
	_check(_range_all(stuns, 3, 10, 10), "guard stun freezes through the eight hitstop frames (F4-F11)")
	_check(stuns[11] == 9 and stuns[12] == 8, "guard stun counts down one per normal frame after the freeze")
	_check(_range_all(alive, 3, 10, true) and alive[11] == false,
		"the dummy's move stays frozen through the hitstop and finishes only after it (F12)")
	_check((first["session"] as CombatSession).player_move_id == "" and (first["session"] as CombatSession).player_prejump_left == 0,
		"no move or jump can start during guard stun (frame-5 attack and frame-7 space stay buffered-only)")
	_check(stuns[19] == 1 and stuns[20] == 0 and stuns[21] == 0, "guard stun reaches zero and stays there")


func _test_player_hit_reaction_locks() -> void:
	# 未防御命中（issue 16）：PLAYER_HIT 事件 + 受击硬直（= 打击 hitstun）+ 水平
	# 击退 + Hitstop；受击硬直中不蹲下、不出招、不进入防御；硬直结束后恢复自由
	# 行动（可蹲、可出招）。
	var session := CombatSession.new({"D_H": _dummy_strike("D_H", MoveData.AttackAttribute.HIGH, false), "5A": _probe_move("5A", "A")})
	session.dummy_position = session.player_position + Vector2(70, 0)
	var hit_frame := -1
	var velocity_after_hit := 0.0
	var hitstun_counts: Array[int] = []
	var crouched_during_stun := false
	var guarded_during_stun := false
	var move_started_during_stun := false
	for frame in range(1, 25):
		var digit := 5
		var key := ""
		if frame == 5 or frame == 8:
			digit = 2
		if frame == 6:
			key = "A"
		if frame == 24:
			key = "A"
		var events := session.step(_relative_input(session, digit, key, "D_H" if frame == 1 else ""))
		if _count_events(events, CombatEvent.Type.PLAYER_HIT) == 1:
			hit_frame = frame
			velocity_after_hit = session.player_velocity.x
		hitstun_counts.append(session.player_hitstun_left)
		if frame >= 5 and frame <= 10:
			crouched_during_stun = crouched_during_stun or session.player_crouching
			guarded_during_stun = guarded_during_stun or session.player_guard != CombatSession.GuardPosture.NONE
			move_started_during_stun = move_started_during_stun or session.player_move_id != ""
	_check(hit_frame == 3, "the unguarded strike connects on the dummy's first active frame (F3)")
	_check(hitstun_counts[2] == 10, "player hitstun starts at the strike's own hitstun frames (10)")
	_check(_range_all(hitstun_counts, 3, 10, 10), "player hitstun freezes through the hitstop")
	_check(hitstun_counts[11] == 9, "player hitstun counts down after the freeze")
	_check(velocity_after_hit < 0.0, "the hit applies horizontal knockback away from the dummy")
	_check(not crouched_during_stun and not guarded_during_stun and not move_started_during_stun,
		"hitstun locks posture: no crouch from 2, no guard, and the frame-6 attack never starts")
	_check(session.dummy_hp == GameParams.DUMMY_MAX_HP, "the dummy attack does not change the dummy's own hp")
	_check(session.player_hitstun_left == 0, "hitstun has fully counted down by the end of the script")
	_check(session.player_move_id == "5A", "after hitstun ends the frame-24 attack starts normally")


func _test_crouch_blocked_in_restricted_phases() -> void:
	# 受限阶段不被下方向强行改姿态（issue 16）：出招、pre-jump、空中与空技落地
	# 恢复中按住 2 不蹲；空跳落地恢复第 2、3 帧例外可进入蹲下（首帧钳掉）。
	# 受击硬直中的姿态冻结见 _test_player_hit_reaction_locks。
	var attacking := CombatSession.new({"5A": _probe_move("5A", "A")})
	var crouched_during_move := false
	for frame in range(1, 8):
		attacking.step(_relative_input(attacking, 2, "A" if frame == 1 else ""))
		crouched_during_move = crouched_during_move or attacking.player_crouching
	_check(not crouched_during_move, "holding 2 during a move never crouches")

	var prep := CombatSession.new()
	var crouched_during_prep := false
	for frame in range(1, 5):
		var input := _relative_input(prep, 5 if frame == 1 else 2)
		if frame == 1:
			input.jump_pressed = true
		prep.step(input)
		crouched_during_prep = crouched_during_prep or prep.player_crouching
	_check(not crouched_during_prep and prep.player_prejump_left > 0,
		"holding 2 through pre-jump never crouches")

	var airborne := CombatSession.new()
	var crouched_in_air := false
	for frame in range(1, 12):
		var input := _relative_input(airborne, 5 if frame == 1 else 2)
		if frame == 1:
			input.jump_pressed = true
		airborne.step(input)
		if frame >= 6:
			crouched_in_air = crouched_in_air or airborne.player_crouching
	_check(not crouched_in_air and not airborne.player_on_ground, "holding 2 airborne never forms a crouch")

	# 空跳（F1 请求 → F5 离地 → F43 落地）：落地首帧不蹲，恢复第 2、3 帧可蹲。
	# 空技（F8 jA 挥空）：基础 +1f 恢复（F43–F46）全程不蹲，F47 恢复自由后可蹲。
	var empty_jump := CombatSession.new()
	var empty_frames := {}
	for frame in range(1, 49):
		var input := _relative_input(empty_jump, 5 if frame < 42 else 2)
		if frame == 1:
			input.jump_pressed = true
		empty_jump.step(input)
		if frame >= 42:
			empty_frames[frame] = empty_jump.player_crouching
	_check(empty_frames[43] == false, "the landing frame itself does not crouch (first-frame clamp)")
	_check(empty_frames[44] == true and empty_frames[45] == true, "empty-jump recovery frames 2-3 crouch on demand")

	var air_move := CombatSession.new()
	var air_frames := {}
	for frame in range(1, 49):
		var input := _relative_input(air_move, 5 if frame < 42 else 2, "A" if frame == 8 else "")
		if frame == 1:
			input.jump_pressed = true
		air_move.step(input)
		if frame >= 42:
			air_frames[frame] = air_move.player_crouching
	_check(air_frames[43] == false and air_frames[44] == false and air_frames[46] == false,
		"an air-move jump stays uncrouched through its whole landing recovery")
	_check(air_frames[47] == true, "crouch returns the frame after the air-move landing recovery ends")


func _test_landing_guard_gates() -> void:
	# 落地防御门（issue 16）：任何跳跃的落地恢复首帧不可防御；空跳第 2、3 帧
	# 可防御；空技恢复全程不可防御。落地前空中按 4 为空防（离地后成立）。
	var empty_jump := CombatSession.new()
	var guards := {}
	for frame in range(1, 49):
		var input := _relative_input(empty_jump, 5 if frame < 40 else 4)
		if frame == 1:
			input.jump_pressed = true
		empty_jump.step(input)
		if frame >= 40:
			guards[frame] = empty_jump.player_guard
	_check(guards[42] == CombatSession.GuardPosture.AIR, "4 stays the air guard while still airborne before landing")
	_check(guards[43] == CombatSession.GuardPosture.NONE, "the landing frame itself cannot guard (first-frame clamp)")
	_check(guards[44] == CombatSession.GuardPosture.STANDING and guards[45] == CombatSession.GuardPosture.STANDING,
		"empty-jump recovery frames 2-3 can guard")
	_check(guards[47] == CombatSession.GuardPosture.STANDING, "guarding resumes normally after the recovery")

	var air_move := CombatSession.new()
	var air_guards := {}
	for frame in range(1, 49):
		var input := _relative_input(air_move, 5 if frame < 40 else 4, "A" if frame == 8 else "")
		if frame == 1:
			input.jump_pressed = true
		air_move.step(input)
		if frame >= 42:
			air_guards[frame] = air_move.player_guard
	_check(air_guards[43] == CombatSession.GuardPosture.NONE and air_guards[44] == CombatSession.GuardPosture.NONE \
		and air_guards[46] == CombatSession.GuardPosture.NONE,
		"an air-move jump cannot guard through its whole landing recovery")
	_check(air_guards[47] == CombatSession.GuardPosture.STANDING, "standing guard returns the frame after the recovery ends")


func _test_guard_stun_holds_posture_block_string() -> void:
	# 防御硬直保持姿态（issue 16）：硬直中松开方向、或按住下方向，姿态都冻结在
	# 进入硬直时的站防——第二次打击在硬直中被同一姿态挡下（连防），无需重新
	# 按住 4。短窗口攻击（2/1/1）：第一击 F3 挡下、停顿 F4–F11、F12 收招后木桩
	# 空闲；F13 请求第二击、F15 连接时硬直仍在（剩 7 帧）。
	var strike := _dummy_strike("D1", MoveData.AttackAttribute.HIGH, false)
	strike.active_frames = 1
	strike.recovery_frames = 1
	var second := _dummy_strike("D2", MoveData.AttackAttribute.HIGH, false)
	second.active_frames = 1
	second.recovery_frames = 1
	var session := CombatSession.new({"D1": strike, "D2": second})
	session.dummy_position = session.player_position + Vector2(70, 0)
	var block_frames: Array[int] = []
	var guard_at_f8 := 0
	var crouched_at_f8 := false
	for frame in range(1, 17):
		var digit := 4
		if frame >= 4:
			digit = 2 if frame == 8 else 5
		var request := "D1" if frame == 1 else ("D2" if frame == 13 else "")
		var events := session.step(_relative_input(session, digit, "", request))
		block_frames.append(_count_events(events, CombatEvent.Type.BLOCKED))
		if frame == 8:
			guard_at_f8 = session.player_guard
			crouched_at_f8 = session.player_crouching
	_check(block_frames == [0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0],
		"the frame-3 block and the frame-15 block-in-stun both land exactly once")
	_check(guard_at_f8 == CombatSession.GuardPosture.STANDING and not crouched_at_f8,
		"guard stun freezes the posture: holding 2 mid-stun neither crouches nor flips the standing guard")
	_check(session.player_guard == CombatSession.GuardPosture.STANDING,
		"the held standing guard survives the whole block string")


func _test_guard_break_hits_through_hitstun() -> void:
	# 防御被打破（issue 16）：站防漏 low 被命中后进入受击硬直——姿态可观测量
	# 冻结在站防（不改姿态），但硬直期间一律不设防：随后的 high 直接连中玩家，
	# 不会被残留的站防姿态挡下。低段攻击（2/4/3）F3 命中、停顿 F4–F11、
	# F17 收招；F18 请求高段（2/1/1）、F20 连接时受击硬直仍剩 2 帧。
	var low := _dummy_strike("D_L", MoveData.AttackAttribute.LOW, false)
	var high := _dummy_strike("D_H", MoveData.AttackAttribute.HIGH, false)
	high.active_frames = 1
	high.recovery_frames = 1
	var session := CombatSession.new({"D_L": low, "D_H": high})
	session.dummy_position = session.player_position + Vector2(70, 0)
	var player_hit_frames: Array[int] = []
	var blocked_total := 0
	var guard_at_f19 := 0
	for frame in range(1, 22):
		var request := "D_L" if frame == 1 else ("D_H" if frame == 18 else "")
		var events := session.step(_relative_input(session, 4, "", request))
		if _count_events(events, CombatEvent.Type.PLAYER_HIT) == 1:
			player_hit_frames.append(frame)
		blocked_total += _count_events(events, CombatEvent.Type.BLOCKED)
		if frame == 19:
			guard_at_f19 = session.player_guard
	_check(player_hit_frames == [3, 20], "the low breaks the standing guard at F3 and the high connects again at F20")
	_check(blocked_total == 0, "nothing is blocked once the guard is broken: hitstun leaves the player defenseless")
	_check(guard_at_f19 == CombatSession.GuardPosture.STANDING,
		"the posture observable stays frozen at standing through the hitstun (no posture switch, just no protection)")


# --- 普通投、投距失败与拆投（issue 17）---

## 投技测试表：单键打击招式 + BC 普通投（与共享 data/moves/BC.tres 同构：
## startup 5 / active 11（投发生 1f + 拆投延续 10f）/ recovery 10 / 投距 64）。
func _throw_table() -> Dictionary:
	var table := {
		"5A": _probe_move("5A", "A"),
		"5B": _probe_move("5B", "B"),
		"5C": _probe_move("5C", "C"),
		"5D": _probe_move("5D", "D"),
	}
	var throw_move := MoveData.new()
	throw_move.move_id = "BC"
	throw_move.move_kind = MoveData.MoveKind.THROW
	throw_move.stance = MoveData.Stance.GROUND
	throw_move.startup_frames = 5
	throw_move.active_frames = GameParams.THROW_TECH_WINDOW_AFTER_GRAB + 1
	throw_move.recovery_frames = 10
	throw_move.cancel_window_frames = 0
	throw_move.priority = 1
	throw_move.throw_range = 64.0
	table["BC"] = throw_move
	return table


## 组合帧输入：pressed/held 为本帧动作键集合，down 为下方向，tech 为木桩拆投请求。
func _keys_frame(pressed: Array, held: Array, down := false, tech := false) -> FrameInput:
	var input := FrameInput.new()
	input.down_held = down
	input.dummy_tech_request = tech
	for key in pressed:
		input.pressed_action_keys.append(String(key))
	for key in held:
		input.held_action_keys.append(String(key))
	return input


func _throw_fail_events(events: Array[CombatEvent], reason: CombatEvent.ThrowFailReason) -> int:
	var count := 0
	for event in events:
		if event.type == CombatEvent.Type.THROW_FAILED and event.throw_fail_reason == reason:
			count += 1
	return count


func _test_throw_combination_recognition_and_start() -> void:
	# B+C 组合识别与起手（issue 17）：≤3f 容差内两键新按下且配齐帧仍按住 → 组合
	# 覆盖单键选择，投距内配齐当帧启动普通投；超出容差 1 帧则不组成组合——B 在
	# 配对窗口末帧按单键处理（5B 起手），不属于“投失败回退”。同帧 B+C+D 由组合
	# 覆盖 D；投距外失败不回退任何单键。
	var close := CombatSession.new(_throw_table())
	close.dummy_position = close.player_position + Vector2(60, 0)
	var move_ids: Array[String] = []
	var held_at_completion: Array = []
	for frame in range(1, 15):
		var pressed: Array = []
		var held: Array = []
		if frame >= 10:
			held.append("B")
		if frame == 10:
			pressed.append("B")
		if frame == 13:
			pressed.append("C")
			held.append("C")
		close.step(_keys_frame(pressed, held))
		move_ids.append(close.player_move_id)
		if frame == 13:
			held_at_completion = close.debug_snapshot()["held_action_keys"]
	_check(_range_all(move_ids, 9, 11, ""), "B alone never starts 5B during the pairing window (F10-F12)")
	_check(move_ids[12] == "BC" and close.player_phase == CombatSession.PlayerPhase.STARTUP,
		"B@F10 held plus C@F13 completes the combination and starts the throw on F13")
	_check(not move_ids.has("5B") and not move_ids.has("5C"), "the completed combination suppresses the member single keys")
	_check(held_at_completion == ["B", "C"], "the raw hold records of both member keys stay observable on the completion frame")

	# 对照：C@F14 超出容差——B 已在 F13 按单键处理（5B 起手），无投、无失败事件。
	var late := CombatSession.new(_throw_table())
	late.dummy_position = late.player_position + Vector2(60, 0)
	var late_moves: Array[String] = []
	var late_events: Array[CombatEvent] = []
	for frame in range(1, 19):
		var pressed: Array = []
		var held: Array = []
		if frame >= 10:
			held.append("B")
		if frame == 10:
			pressed.append("B")
		if frame == 14:
			pressed.append("C")
			held.append("C")
		late_events.append_array(late.step(_keys_frame(pressed, held)))
		late_moves.append(late.player_move_id)
	_check(late_moves[12] == "5B", "the over-tolerance control processes B as a single key at the window end (F13, 5B starts)")
	_check(not late_moves.has("BC") and _count_events(late_events, CombatEvent.Type.THROW_HIT) == 0,
		"C one frame too late never forms the combination or a throw")
	_check(_count_events(late_events, CombatEvent.Type.THROW_FAILED) == 0,
		"the single-key fallback at the window end is not a throw failure")

	# 同帧 B+C+D：组合覆盖 D（起投）；投距外同帧配齐则失败且不回退任何单键。
	var same_frame := CombatSession.new(_throw_table())
	same_frame.dummy_position = same_frame.player_position + Vector2(60, 0)
	same_frame.step(_keys_frame(["B", "C", "D"], ["B", "C", "D"]))
	_check(same_frame.player_move_id == "BC", "same-frame B+C+D is covered by the explicit combination (throw starts)")
	var far := CombatSession.new(_throw_table())
	far.dummy_position = far.player_position + Vector2(100, 0)
	var far_moves: Array[String] = []
	var far_events: Array[CombatEvent] = []
	for frame in range(1, 15):
		var events := far.step(_keys_frame(["B", "C", "D"] if frame == 10 else [], ["B", "C", "D"] if frame == 10 else []))
		far_events.append_array(events)
		far_moves.append(far.player_move_id)
	_check(_throw_fail_events(far_events, CombatEvent.ThrowFailReason.RANGE) == 1,
		"the same-frame combination out of throw range fails with an observable RANGE reason")
	_check(not far_moves.has("5B") and not far_moves.has("5C") and not far_moves.has("5D") and not far_moves.has("BC"),
		"the failed combination falls back to no single key at all (B, C and D alike)")


func _test_throw_single_key_wait_anchor() -> void:
	# 单键等待的输入锚点（issue 17 seam）：参与组合的 C 单独按下时保留原按下帧的
	# 方向识别与缓存起龄点——等待期间只是候选（诊断可见），配对窗口末帧按单键
	# 处理：236+C 在 C@F30 的识别锚点下于 F33 起手，缓存年龄 3。
	var table := _throw_table()
	var qcf := _probe_move("236C", "C")
	qcf.direction_derivation = "236C"
	qcf.command_tier = MoveData.CommandTier.SPECIAL
	table["236C"] = qcf
	var session := CombatSession.new(table)
	session.dummy_position = session.player_position + Vector2(80, 0)
	var move_ids: Array[String] = []
	var buffered_during_wait := ""
	for frame in range(1, 36):
		var pressed: Array = []
		var held: Array = []
		var axis := 0
		var down := false
		if frame == 1:
			down = true
		elif frame == 2:
			axis = 1
			down = true
		elif frame >= 3:
			axis = 1
		if frame == 30:
			pressed.append("C")
			held.append("C")
		var input := _keys_frame(pressed, held, down)
		input.move_axis = axis
		session.step(input)
		move_ids.append(session.player_move_id)
		if frame == 31:
			buffered_during_wait = String(session.debug_snapshot()["buffered_move_id"])
	_check(_range_all(move_ids, 29, 31, ""), "the waiting C stays a candidate through F30-F32 (no early start)")
	_check(buffered_during_wait == "236C",
		"the waiting single key keeps its press-frame direction match (236C locked at F30, observable as a buffer candidate)")
	_check(move_ids[32] == "236C", "C@F30 is processed as a single key at the window end (F33) with its original anchor")


func _test_throw_combination_extra_key_and_state() -> void:
	# 组合等待期间的额外键（issue 17 seam）：非成员 D 不随 B+C 等待，按其输入帧
	# 正常处理；随后配齐的 B+C 因招式阶段失败——无投启动、无撤销 5D、旧 B 不能
	# 在等待结束后覆盖 D，失败原因可观察。
	var session := CombatSession.new(_throw_table())
	session.dummy_position = session.player_position + Vector2(60, 0)
	var move_ids: Array[String] = []
	var fail_frames: Array[int] = []
	for frame in range(1, 16):
		var pressed: Array = []
		var held: Array = []
		if frame >= 10:
			held.append("B")
		if frame == 10:
			pressed.append("B")
		if frame == 11:
			pressed.append("D")
			held.append("D")
		if frame == 13:
			pressed.append("C")
			held.append("C")
		var events := session.step(_keys_frame(pressed, held))
		move_ids.append(session.player_move_id)
		if _throw_fail_events(events, CombatEvent.ThrowFailReason.STATE) > 0:
			fail_frames.append(frame)
	_check(move_ids[10] == "5D", "the non-member D starts 5D on its own input frame (F11, no combination wait)")
	_check(fail_frames == [13], "the later B+C combination is recognized but rejected for state on the completion frame (F13)")
	_check(_range_all(move_ids, 12, 14, "5D"), "the running 5D is never undone by the failed throw attempt")
	_check(not move_ids.has("BC") and not move_ids.has("5B"), "no throw starts and the consumed B press never re-emits as 5B")


func _test_throw_hold_overlap_rules() -> void:
	# 组合重叠与长持（issue 17 seam）：组合要求每个组成键在容差内有新的按下且
	# 配齐帧仍按住——首键提前松开后按第二键不组成组合；仅有长期按住状态不能
	# 补齐组合。两种情况都回落为单键路径（按组合等待规则处理）。
	var released := CombatSession.new(_throw_table())
	released.dummy_position = released.player_position + Vector2(60, 0)
	var released_moves: Array[String] = []
	var released_events: Array[CombatEvent] = []
	for frame in range(1, 16):
		var pressed: Array = []
		var held: Array = []
		if frame == 10:
			pressed.append("B")
			held.append("B")
		if frame == 12:
			pressed.append("C")
			held.append("C")
		released_events.append_array(released.step(_keys_frame(pressed, held)))
		released_moves.append(released.player_move_id)
	_check(not released_moves.has("BC") and not released_moves.has("5B"),
		"releasing B before the C press breaks the combination (no throw; B's overwritten candidacy never re-emits)")
	_check(released_moves[14] == "5C",
		"the later C press owns the single slot and processes as a single key at its own window end (F15)")
	_check(_count_events(released_events, CombatEvent.Type.THROW_HIT) == 0 and _count_events(released_events, CombatEvent.Type.THROW_FAILED) == 0,
		"no throw attempt happens without the held overlap")

	var long_hold := CombatSession.new(_throw_table())
	long_hold.dummy_position = long_hold.player_position + Vector2(60, 0)
	var long_moves: Array[String] = []
	for frame in range(1, 16):
		var pressed: Array = []
		var held: Array = []
		if frame >= 5:
			held.append("B")
		if frame == 5:
			pressed.append("B")
		if frame == 13:
			pressed.append("C")
			held.append("C")
		long_hold.step(_keys_frame(pressed, held))
		long_moves.append(long_hold.player_move_id)
	_check(long_moves[7] == "5B" and not long_moves.has("BC"),
		"a long-held B press outside the tolerance cannot complete the combination (5B starts at its own window end)")

	var same_frame := CombatSession.new(_throw_table())
	same_frame.dummy_position = same_frame.player_position + Vector2(60, 0)
	same_frame.step(_keys_frame(["B", "C"], ["B", "C"]))
	_check(same_frame.player_move_id == "BC", "both member keys newly pressed on the same frame complete the combination immediately")


func _test_throw_lifecycle_result_both_facings() -> void:
	# 普通投生命周期与结果（issue 17）：startup 固定 5f（F13 起手 → F17 投发生），
	# 拆投窗口覆盖 F13–F27（投发生后延续 10f）；未被拆投时 F27 成立投结果——
	# 木桩沿投向击退并进入地面受击硬直，无 HP 伤害、不进入连段计数；
	# 收招后回中立，木桩稍后自然受身。左右面向镜像：时间线一致、投向相反。
	var run := func(facing_right: bool) -> Dictionary:
		var session := CombatSession.new(_throw_table())
		session.dummy_position = session.player_position + Vector2(60 if facing_right else -60, 0)
		var phases: Array[int] = []
		var hit_frame := -1
		var hit_direction := 0
		var dummy_velocity_at_hit := 0.0
		var all: Array[CombatEvent] = []
		for frame in range(1, 61):
			var pressed: Array = []
			var held: Array = []
			if frame >= 10:
				held.append("B")
			if frame == 10:
				pressed.append("B")
			if frame == 13:
				pressed.append("C")
				held.append("C")
			var events := session.step(_keys_frame(pressed, held))
			all.append_array(events)
			if frame <= 40:
				phases.append(session.player_phase)
			if _count_events(events, CombatEvent.Type.THROW_HIT) == 1:
				hit_frame = frame
				hit_direction = _events_of(events, CombatEvent.Type.THROW_HIT)[0].direction
				dummy_velocity_at_hit = session.dummy_velocity.x
		return {
			"session": session, "phases": phases, "hit_frame": hit_frame,
			"hit_direction": hit_direction, "dummy_velocity_at_hit": dummy_velocity_at_hit,
			"events": all,
		}
	var right: Dictionary = run.call(true)
	var right_session := right["session"] as CombatSession
	_check(_phase_range(right["phases"], 12, 15, CombatSession.PlayerPhase.STARTUP),
		"the throw startup window covers F13-F16 (startup fixed at 5 frames, F17 is the grab frame)")
	_check(_phase_range(right["phases"], 16, 26, CombatSession.PlayerPhase.ACTIVE),
		"the active window F17-F27 is the grab plus the ten tech-window continuation frames")
	_check(_phase_range(right["phases"], 27, 36, CombatSession.PlayerPhase.RECOVERY) and (right["phases"] as Array)[37] == CombatSession.PlayerPhase.NEUTRAL,
		"the throw recovers F28-F37 and returns to neutral on F38")
	_check(right["hit_frame"] == 27, "the un-teched throw result lands exactly when the tech window closes (F27 = F13 + 14)")
	_check(right["hit_direction"] == 1 and right["dummy_velocity_at_hit"] > 0.0,
		"facing right throws the dummy to the right (direction decided by facing)")
	_check(right_session.dummy_hp == GameParams.DUMMY_MAX_HP and right_session.combo_hits == 0 and not right_session.combo_active,
		"the throw result deals no HP damage and never counts as a combo hit")
	_check(right_session.dummy_state == CombatSession.DummyState.NEUTRAL,
		"the thrown dummy recovers naturally after its hitstun")
	_check(_count_events(right["events"], CombatEvent.Type.DUMMY_RECOVERED) == 1,
		"exactly one natural recovery follows the throw hitstun")
	var left: Dictionary = run.call(false)
	_check(left["hit_frame"] == 27 and left["hit_direction"] == -1 and left["dummy_velocity_at_hit"] < 0.0,
		"the mirrored timeline is identical while the throw direction flips with facing")
	_check((left["phases"] as Array) == (right["phases"] as Array), "both facings share the exact throw phase timeline")


func _test_throw_tech_window_boundaries() -> void:
	# 拆投窗口边界（issue 17）：窗口从首个 startup 帧（起手当帧）开始，到投发生
	# 后延续 10f 的末帧（F27）为止——F27 当帧拆投仍阻止投结果；F28 起窗口关闭，
	# 投结果已在 F27 成立，迟到的拆投请求无效。拆投后玩家当帧回中立、木桩不受
	# 任何投结果影响。
	var run := func(tech_frame: int) -> Dictionary:
		var session := CombatSession.new(_throw_table())
		session.dummy_position = session.player_position + Vector2(60, 0)
		var tech_seen := -1
		var hit_frame := -1
		var move_after_tech := ""
		for frame in range(1, 34):
			var pressed: Array = []
			var held: Array = []
			if frame >= 10:
				held.append("B")
			if frame == 10:
				pressed.append("B")
			if frame == 13:
				pressed.append("C")
				held.append("C")
			var events := session.step(_keys_frame(pressed, held, false, frame == tech_frame))
			if _count_events(events, CombatEvent.Type.THROW_TECHED) == 1:
				tech_seen = frame
				move_after_tech = session.player_move_id
			if _count_events(events, CombatEvent.Type.THROW_HIT) == 1:
				hit_frame = frame
		return {"session": session, "tech_seen": tech_seen, "hit_frame": hit_frame, "move_after_tech": move_after_tech}
	var first_day: Dictionary = run.call(13)
	_check(first_day["tech_seen"] == 13 and first_day["hit_frame"] == -1 and first_day["move_after_tech"] == "",
		"a tech on the throw's first startup frame (F13) breaks it immediately: no result, player back to neutral on the same frame")
	_check((first_day["session"] as CombatSession).dummy_state == CombatSession.DummyState.NEUTRAL,
		"the first-frame tech leaves the dummy completely untouched")
	var mid: Dictionary = run.call(20)
	_check(mid["tech_seen"] == 20 and mid["hit_frame"] == -1 and (mid["session"] as CombatSession).dummy_state == CombatSession.DummyState.NEUTRAL,
		"a mid-window tech (F20, inside the post-grab continuation) still prevents the throw result")
	var last_valid: Dictionary = run.call(27)
	_check(last_valid["tech_seen"] == 27 and last_valid["hit_frame"] == -1,
		"the last valid tech frame is F27 (grab F17 plus ten continuation frames): it still prevents the result")
	var too_late: Dictionary = run.call(28)
	_check(too_late["tech_seen"] == -1 and too_late["hit_frame"] == 27,
		"a tech one frame later (F28) is outside the window: the result already landed on F27 and the request is ignored")
	_check((too_late["session"] as CombatSession).dummy_state == CombatSession.DummyState.GROUND_HITSTUN,
		"the late tech cannot undo the applied throw hitstun")


func _test_throw_disabled_states() -> void:
	# 禁用状态（issue 17）：蹲下、pre-jump、空中、招式阶段、受击硬直和落地恢复
	# 中不执行普通投——配齐的组合在这些状态被拒绝（STATE 原因可观察），不回退
	# 单键；空跳落地恢复第 2、3 帧的攻击例外不适用于投。
	var run := func(mode: String) -> Dictionary:
		var session := CombatSession.new(_throw_table())
		session.dummy_position = session.player_position + Vector2(60, 0)
		var c_frame := 13
		var b_frame := 10
		var fail_frames: Array[int] = []
		var move_ids: Array[String] = []
		var last_frame := 16
		var recovery_at_c := -1
		if mode == "landing" or mode == "landing2":
			b_frame = 41
			c_frame = 43 if mode == "landing" else 44
			last_frame = 47
		for frame in range(1, last_frame + 1):
			var pressed: Array = []
			var held: Array = []
			if mode == "move" and frame == 11:
				## A 于 F11 起手（F15 才进入判定）：组合在 F13 配齐时 5A 仍在
				## 招式阶段，且尝试先于命中发生——纯招式阶段门，无停顿介入。
				pressed.append("A")
				held.append("A")
			if frame >= b_frame:
				held.append("B")
			if frame == b_frame:
				pressed.append("B")
			if frame == c_frame:
				pressed.append("C")
				held.append("C")
			var input := _keys_frame(pressed, held, mode == "crouch")
			if (mode == "prejump" and frame == 10) or ((mode == "air" or mode == "landing" or mode == "landing2") and frame == 1):
				input.jump_pressed = true
			if mode == "hitstun" and frame == 1:
				input.dummy_move_request = "5A"
			var events := session.step(input)
			move_ids.append(session.player_move_id)
			if frame == c_frame:
				recovery_at_c = session.player_landing_recovery_left
			if _throw_fail_events(events, CombatEvent.ThrowFailReason.STATE) > 0:
				fail_frames.append(frame)
		return {"session": session, "fail_frames": fail_frames, "move_ids": move_ids, "c_frame": c_frame, "recovery_at_c": recovery_at_c}
	for mode in ["crouch", "prejump", "air", "move", "hitstun", "landing", "landing2"]:
		var result: Dictionary = run.call(mode)
		var session := result["session"] as CombatSession
		var expected_fail: int = result["c_frame"]
		if mode == "hitstun":
			## 5A 请求 F1、F6 连接受击（硬直 12）+ 停顿 F7–F14：组合意图在恢复首个
			## 正常帧 F15 尝试一次并被拒。
			expected_fail = 15
		_check(result["fail_frames"] == [expected_fail],
			"the completed combination in state '%s' is rejected exactly once with the STATE reason" % mode)
		_check(not (result["move_ids"] as Array).has("BC"),
			"state '%s' never executes the throw" % mode)
		if mode == "crouch":
			_check(session.player_crouching, "the crouch case actually held the crouch posture")
		if mode == "move":
			_check((result["move_ids"] as Array)[10] == "5A", "the move-phase case actually had 5A running")
		if mode == "hitstun":
			_check(session.player_hitstun_left > 0, "the hitstun case actually stunned the player (hitstun still counting at the script end)")
		if mode == "landing" or mode == "landing2":
			_check(result["recovery_at_c"] > 0 and session.player_on_ground,
				"the landing cases (%s) attempted the throw inside the landing recovery, on the ground" % mode)


func _test_throw_range_failure_observable() -> void:
	# 投距失败（issue 17）：投距 = 身体中心水平距离 ≤64px 且身体矩形垂直重叠。
	# 距离超限或垂直不重叠时组合被拒绝（RANGE 原因可观察），不启动投、不回退
	# 普通拳脚；边界 64px 恰好成立。
	var run := func(offset: float, dy := 0.0) -> Dictionary:
		var session := CombatSession.new(_throw_table())
		session.dummy_position = session.player_position + Vector2(offset, -dy)
		var fail_frames: Array[int] = []
		var move_ids: Array[String] = []
		for frame in range(1, 16):
			var pressed: Array = []
			var held: Array = []
			if frame >= 10:
				held.append("B")
			if frame == 10:
				pressed.append("B")
			if frame == 13:
				pressed.append("C")
				held.append("C")
			var events := session.step(_keys_frame(pressed, held))
			move_ids.append(session.player_move_id)
			if _throw_fail_events(events, CombatEvent.ThrowFailReason.RANGE) > 0:
				fail_frames.append(frame)
		return {"session": session, "fail_frames": fail_frames, "move_ids": move_ids}
	var boundary: Dictionary = run.call(64.0)
	_check((boundary["move_ids"] as Array)[12] == "BC" and (boundary["fail_frames"] as Array).is_empty(),
		"the throw range boundary is inclusive: 64px body-center distance still throws")
	var over: Dictionary = run.call(66.0)
	_check(over["fail_frames"] == [13] and not (over["move_ids"] as Array).has("BC"),
		"beyond the throw range the combination is rejected on the completion frame")
	_check(not (over["move_ids"] as Array).has("5B") and not (over["move_ids"] as Array).has("5C"),
		"the range failure never falls back to the member strikes")
	_check((over["session"] as CombatSession).dummy_hp == GameParams.DUMMY_MAX_HP,
		"the failed throw leaves the dummy untouched")
	var no_overlap: Dictionary = run.call(60.0, 200.0)
	_check(no_overlap["fail_frames"] == [13] and not (no_overlap["move_ids"] as Array).has("BC"),
		"bodies that do not overlap vertically are outside the throw range even within 64px horizontally")
	# 左右镜像：投距外的失败帧与原因一致（同一份键序、镜像站位）。
	var mirror := CombatSession.new(_throw_table())
	mirror.dummy_position = mirror.player_position + Vector2(-66, 0)
	var mirror_fails: Array[int] = []
	for frame in range(1, 16):
		var pressed: Array = []
		var held: Array = []
		if frame >= 10:
			held.append("B")
		if frame == 10:
			pressed.append("B")
		if frame == 13:
			pressed.append("C")
			held.append("C")
		var events := mirror.step(_keys_frame(pressed, held))
		if _throw_fail_events(events, CombatEvent.ThrowFailReason.RANGE) > 0:
			mirror_fails.append(frame)
	_check(mirror_fails == [13] and not mirror.player_move_id == "BC",
		"the mirrored out-of-range rejection fails on the same frame with the same RANGE reason")


func _test_throw_hitstop_intent_attempts_once() -> void:
	# Hitstop 内的组合（issue 17 seam）：停顿中配齐的组合只记录意图，不启动不
	# 消费；未被更新动作输入覆盖时，恢复首个正常帧尝试一次——该帧仍处招式阶段
	# 则拒绝并结束投请求（之后不补投、不回退）。第二键晚 1 帧已超出 3f 容差，
	# 即使两次都在停顿内也不组成投；恢复前的新动作输入覆盖待处理投请求。
	var base := func(c_frame: int, extra_key_frame := 0) -> Dictionary:
		var session := CombatSession.new(_throw_table())
		session.dummy_position = session.player_position + Vector2(70, 0)
		var fail_frames: Array[int] = []
		var hit_frames: Array[int] = []
		var move_ids: Array[String] = []
		var pending_seen := false
		for frame in range(1, 46):
			var pressed: Array = []
			var held: Array = []
			if frame == 15:
				pressed.append("A")
				held.append("A")
			if frame >= 23:
				held.append("B")
			if frame == 23:
				pressed.append("B")
			if frame == c_frame:
				pressed.append("C")
				held.append("C")
			if frame == extra_key_frame:
				pressed.append("A")
				held.append("A")
			var events := session.step(_keys_frame(pressed, held))
			move_ids.append(session.player_move_id)
			if _throw_fail_events(events, CombatEvent.ThrowFailReason.STATE) > 0:
				fail_frames.append(frame)
			if _count_events(events, CombatEvent.Type.THROW_HIT) > 0:
				hit_frames.append(frame)
			if frame >= c_frame and frame <= 27:
				pending_seen = pending_seen or bool(session.debug_snapshot()["pending_combination"])
		return {
			"session": session, "fail_frames": fail_frames, "hit_frames": hit_frames,
			"move_ids": move_ids, "pending_seen": pending_seen,
		}
	## 5A 于 F15 起手、F20 首个判定帧命中，停顿 F21–F28，F29 恢复首个正常帧。
	var once: Dictionary = base.call(26)
	_check(once["pending_seen"], "the combination completed inside the hitstop is recorded as pending intent (observable)")
	_check(once["fail_frames"] == [29], "the pending throw is attempted exactly once, on the first normal frame after the freeze (F29)")
	_check((once["move_ids"] as Array)[14] == "5A" and not (once["move_ids"] as Array).has("BC"),
		"the state-rejected throw neither starts nor disturbs the running 5A")
	_check(once["hit_frames"].is_empty() and not (once["move_ids"] as Array).has("5B"),
		"after the single failed attempt the B press is gone: no retry, no throw result, no fallback to 5B")
	var too_late: Dictionary = base.call(27)
	_check(too_late["fail_frames"].is_empty() and not (too_late["move_ids"] as Array).has("BC"),
		"C one frame later (F27) exceeds the 3-frame tolerance even though both presses sit inside the freeze")
	var overridden: Dictionary = base.call(26, 27)
	_check(overridden["fail_frames"].is_empty() and not (overridden["move_ids"] as Array).has("BC"),
		"a newer action input (A on F27) overrides the pending throw intent: no attempt happens on resume")


# --- 66 前冲与 44 后撤（issue 18）---

## 冲刺双击脚本：F1 按下第一个同向段、F2 逻辑中立、F3 第二段起按住到 hold_end。
## 记录每帧步后的 dash_left、水平位置、面向与 DASH_STARTED 的 (帧, 世界方向)；
## digit 只接受 4/6（世界轴按会话面向折算，左右面向可用同一份脚本镜像）。
func _dash_script(session: CombatSession, digit: int, total: int, hold_end: int) -> Dictionary:
	var dash_counts: Array[int] = []
	var positions: Array[float] = []
	var facings: Array[int] = []
	var start_frames: Array[int] = []
	var start_directions: Array[int] = []
	for frame in range(1, total + 1):
		var d := digit if frame == 1 or (frame >= 3 and frame <= hold_end) else 5
		var events := session.step(_relative_input(session, d))
		dash_counts.append(session.player_dash_left)
		positions.append(session.player_position.x)
		facings.append(session.player_facing)
		for event in events:
			if event.type == CombatEvent.Type.DASH_STARTED:
				start_frames.append(frame)
				start_directions.append(event.direction)
	return {
		"dash_counts": dash_counts, "positions": positions, "facings": facings,
		"start_frames": start_frames, "start_directions": start_directions,
	}


func _test_dash_two_taps_trigger_duration_and_free_return() -> void:
	# 66/44 触发与 12f 持续（issue 18）：两个独立同向方向段（中间至少一个逻辑
	# 中立帧）的第二段到来当帧启动冲刺，dash_left 从 12 逐帧倒数到 1，恰 12 帧后
	# 回到地面自由行动（下一帧可起手普通招式）；位移恰为 12 × 冲刺速度 × 物理帧
	# 步长；44 与 66 时间线一致、方向相反、面向保持锁定并清掉按后进入的站防。
	var run := func(digit: int) -> Dictionary:
		var session := CombatSession.new()
		var result := _dash_script(session, digit, 16, 14)
		result["session"] = session
		return result
	var forward: Dictionary = run.call(6)
	var f_counts: Array[int] = forward["dash_counts"]
	var f_positions: Array[float] = forward["positions"]
	_check((forward["start_frames"] as Array) == [3] and (forward["start_directions"] as Array) == [1],
		"the second forward segment starts the dash on its own frame (F3), world direction +1")
	_check(f_counts.slice(2, 14) == [12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1],
		"dash_left counts down 12 through 1 across exactly twelve dash frames (F3-F14)")
	_check(f_counts[14] == 0, "dash_left reaches 0 on the first frame after the dash (F15)")
	var dash_distance := GameParams.PLAYER_DASH_FRAMES * GameParams.PLAYER_DASH_SPEED * GameParams.PHYSICS_TICK
	_check(_approx(f_positions[13] - f_positions[1], dash_distance, 0.01),
		"the forward dash covers exactly twelve frames of dash-speed movement (%dpx at the default param)" % int(dash_distance))
	var back: Dictionary = run.call(4)
	var b_counts: Array[int] = back["dash_counts"]
	var b_positions: Array[float] = back["positions"]
	_check((back["start_frames"] as Array) == [3] and (back["start_directions"] as Array) == [-1],
		"44 taps start the backdash on the second segment's own frame, world direction -1")
	_check(b_counts == f_counts, "both dashes share the exact countdown timeline")
	_check(_approx(b_positions[13] - b_positions[1], -dash_distance, 0.01),
		"the backdash covers the same distance in the opposite direction")
	var b_session := back["session"] as CombatSession
	_check(b_session.player_facing == 1, "the facing stays locked toward the dummy during the backdash (no flip while moving away)")
	_check(b_session.player_guard == CombatSession.GuardPosture.NONE, "the dash clears the standing guard the first back tap held")

	# 冲刺期间按 A 不起手、结束下一帧起手：证明 12f 后回到地面自由行动。
	var blocked := CombatSession.new()
	var blocked_moves: Array[String] = []
	for frame in range(1, 17):
		var key := "A" if frame == 6 or frame == 15 else ""
		var d := 6 if frame == 1 or (frame >= 3 and frame <= 14) else 5
		blocked.step(_relative_input(blocked, d, key))
		blocked_moves.append(blocked.player_move_id)
	_check(_range_all(blocked_moves, 5, 13, ""), "an action key pressed mid-dash (F6) never starts while the dash runs")
	_check(blocked_moves[14] == "5A", "the frame after the dash ends (F15) accepts a fresh attack start")


func _test_dash_hold_and_pattern_rules() -> void:
	# 持续按住与非法模式（issue 18）：长按只生成一个方向段，永不冲刺；两段之间
	# 没有逻辑中立帧（6-3-6、6-2-6）不触发；中立间隙后插有其他方向段（6-5-3-5-6）
	# 时新段的上一段不是同向段，不触发；冲刺后继续按住不重复触发，保留期内的
	# 新双击才再次冲刺。
	var hold := CombatSession.new()
	var hold_events: Array[CombatEvent] = []
	for frame in range(1, 31):
		hold_events.append_array(hold.step(_relative_input(hold, 6)))
	_check(_count_events(hold_events, CombatEvent.Type.DASH_STARTED) == 0 and hold.player_dash_left == 0,
		"holding the forward direction never forms a second segment and never dashes")

	var no_gap := CombatSession.new()
	var no_gap_events: Array[CombatEvent] = []
	for frame in range(1, 4):
		no_gap_events.append_array(no_gap.step(_relative_input(no_gap, [6, 3, 6][frame - 1])))
	for frame in range(4, 21):
		no_gap_events.append_array(no_gap.step(_relative_input(no_gap, 6)))
	_check(_count_events(no_gap_events, CombatEvent.Type.DASH_STARTED) == 0,
		"6-3-6 keeps a non-neutral direction between the forward segments: no dash without a logical neutral frame")

	var no_gap_down := CombatSession.new()
	var down_events: Array[CombatEvent] = []
	for frame in range(1, 4):
		down_events.append_array(no_gap_down.step(_relative_input(no_gap_down, [6, 2, 6][frame - 1])))
	for frame in range(4, 21):
		down_events.append_array(no_gap_down.step(_relative_input(no_gap_down, 6)))
	_check(_count_events(down_events, CombatEvent.Type.DASH_STARTED) == 0,
		"6-2-6 without any neutral frame between the forward segments never dashes")

	var diagonal := CombatSession.new()
	var diag_events: Array[CombatEvent] = []
	for frame in range(1, 6):
		diag_events.append_array(diagonal.step(_relative_input(diagonal, [6, 5, 3, 5, 6][frame - 1])))
	_check(_count_events(diag_events, CombatEvent.Type.DASH_STARTED) == 0,
		"a diagonal segment between the neutral gap and the new tap (6-5-3-5-6) breaks the pattern")

	# 第一段 F3 触发后按住到 F40 只有一次冲刺；F41 松开、F42 再按下时旧第一段已出
	# 保留窗口不触发；F43 松开、F44 与 F42 段组成新双击 → 第二次冲刺。
	var retrigger := CombatSession.new()
	var start_frames: Array[int] = []
	for frame in range(1, 45):
		var digit := 5
		if frame == 1 or (frame >= 3 and frame <= 40) or frame == 42 or frame == 44:
			digit = 6
		var events := retrigger.step(_relative_input(retrigger, digit))
		if _count_events(events, CombatEvent.Type.DASH_STARTED) > 0:
			start_frames.append(frame)
	_check(start_frames == [3, 44],
		"holding through the dash triggers exactly once; only a fresh in-retention double tap dashes again")


func _test_dash_restricted_states() -> void:
	# 受限状态不识别（issue 18）：出招、受击（含其 Hitstop）、pre-jump、空中与
	# 落地恢复期间第二段到来不触发；状态解除后新的同向段当帧触发（方向历史统一，
	# 受限时记录的旧第一段仍可与新段组成 66，保留窗口内有效）。
	var move_phase := CombatSession.new()
	var move_start_frames: Array[int] = []
	for frame in range(1, 29):
		var digit := 5
		var key := ""
		if frame == 1:
			key = "A"
		elif frame in [2, 4, 26, 28]:
			digit = 6
		var events := move_phase.step(_relative_input(move_phase, digit, key))
		if _count_events(events, CombatEvent.Type.DASH_STARTED) > 0:
			move_start_frames.append(frame)
	_check(move_start_frames == [26],
		"the second segment inside the running 5A never starts a dash; the first free-frame segment pairs with the in-move first segment and dashes (F26)")

	# 木桩 5A F1 请求、F6 命中玩家（玩家受击 14 帧不随修正缩放 + 停顿 F7-F14，
	# 恢复自由 F29）：停顿/硬直内的双击（F7/F11 两段）不触发；F29 的第一个
	# 自由帧上，新的 6 段与硬直中记录的旧 6 段组成 66 → 当帧冲刺。
	var hitstun := CombatSession.new()
	hitstun.dummy_position = hitstun.player_position + Vector2(70, 0)
	var hit_frame := -1
	var hitstun_start_frames: Array[int] = []
	for frame in range(1, 33):
		var digit := 5
		var request := "5A" if frame == 1 else ""
		if frame in [7, 11, 27, 29]:
			digit = 6
		var events := hitstun.step(_relative_input(hitstun, digit, "", request))
		if _count_events(events, CombatEvent.Type.PLAYER_HIT) > 0:
			hit_frame = frame
		if _count_events(events, CombatEvent.Type.DASH_STARTED) > 0:
			hitstun_start_frames.append(frame)
	_check(hit_frame == 6, "the dummy strike actually connects with the player on F6 (setup sanity)")
	_check(hitstun_start_frames == [29],
		"the second segment inside the hitstop/hitstun never starts a dash; the first free-frame segment pairs with the frozen first segment and dashes (F29)")

	# pre-jump / 空中 / 落地恢复：Space F1 起跳（准备 F1-F4、空中 F5-F42、落地 F43、
	# 恢复 F43-F45）；双击分别落在准备（F2/F4）与空中（F6/F8），落地恢复内的第二段
	# （F45）被拒；F47 的新段与 F45 段组成新双击 → 冲刺。
	var jump_case := CombatSession.new()
	jump_case.dummy_position = Vector2(100.0, GameParams.ground_stand_y())
	var jump_start_frames: Array[int] = []
	for frame in range(1, 49):
		var digit := 5
		var jump := frame == 1
		if frame in [2, 4, 6, 8, 43, 45, 47]:
			digit = 6
		var input := _relative_input(jump_case, digit)
		input.jump_pressed = jump
		var events := jump_case.step(input)
		if _count_events(events, CombatEvent.Type.DASH_STARTED) > 0:
			jump_start_frames.append(frame)
	_check(jump_start_frames == [47],
		"double taps during pre-jump, airtime and landing recovery never start a dash; the first free tap pair (F45/F47) does")


func _test_dash_mirror_both_facings() -> void:
	# 左右面向镜像（issue 18）：同一份相对数字脚本（6-5-6）在左右面向下都在第二段
	# 当帧触发；世界方向相反、位移大小相等、时间线一致、冲刺期间面向保持锁定。
	var run := func(dummy_offset: float) -> Dictionary:
		var session := CombatSession.new()
		session.dummy_position = Vector2(session.player_position.x + dummy_offset, GameParams.ground_stand_y())
		var result := _dash_script(session, 6, 15, 14)
		result["session"] = session
		return result
	var right: Dictionary = run.call(300.0)
	var left: Dictionary = run.call(-300.0)
	var dash_distance := GameParams.PLAYER_DASH_FRAMES * GameParams.PLAYER_DASH_SPEED * GameParams.PHYSICS_TICK
	_check((right["start_frames"] as Array) == [3] and (right["start_directions"] as Array) == [1],
		"facing right: the digit script dashes toward the dummy (world +1)")
	_check((left["start_frames"] as Array) == [3] and (left["start_directions"] as Array) == [-1],
		"facing left: the same digit script dashes toward the dummy (world -1)")
	_check((right["dash_counts"] as Array) == (left["dash_counts"] as Array), "both facings share the exact twelve-frame countdown")
	_check(_approx((right["positions"] as Array)[13] - (right["positions"] as Array)[1], dash_distance, 0.01),
		"facing right covers the full dash displacement")
	_check(_approx((left["positions"] as Array)[13] - (left["positions"] as Array)[1], -dash_distance, 0.01),
		"facing left covers the mirrored displacement of equal magnitude")
	_check((right["facings"] as Array).slice(2, 14).count(1) == 12 and (left["facings"] as Array).slice(2, 14).count(-1) == 12,
		"the facing locked at dash start stays constant for the whole dash on both sides")


func _test_dash_action_locks_and_hit_interrupt() -> void:
	# 冲刺期间的动作门与被打断（issue 18）：冲刺中 Space 不进入 pre-jump、B+C 投
	# 组合被状态拒绝（STATE 原因可观察，停顿后恢复首帧尝试一次）；木桩打击命中
	# 冲刺中的玩家当帧打断冲刺——进入受击硬直、冲刺计数清零、速度被击退改写。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(100, 0)
	var prejump_seen := false
	var throw_fail_frames: Array[int] = []
	var dash_start_frames: Array[int] = []
	var hit_frame := -1
	var dash_left_at_hit := -1
	var velocity_after_hit := 0.0
	var hitstun_at_hit := -1
	for frame in range(1, 24):
		var digit := 6 if frame == 1 or (frame >= 3 and frame <= 14) else 5
		var request := "5A" if frame == 3 else ""
		var input := _relative_input(session, digit, "", request)
		if frame == 5:
			input.jump_pressed = true
		if frame >= 6:
			input.held_action_keys.append("B")
		if frame == 6:
			input.pressed_action_keys.append("B")
		if frame == 9:
			input.pressed_action_keys.append("C")
			input.held_action_keys.append("C")
		var events := session.step(input)
		prejump_seen = prejump_seen or session.player_prejump_left > 0
		if _throw_fail_events(events, CombatEvent.ThrowFailReason.STATE) > 0:
			throw_fail_frames.append(frame)
		if _count_events(events, CombatEvent.Type.DASH_STARTED) > 0:
			dash_start_frames.append(frame)
		if _count_events(events, CombatEvent.Type.PLAYER_HIT) > 0:
			hit_frame = frame
			dash_left_at_hit = session.player_dash_left
			hitstun_at_hit = session.player_hitstun_left
			velocity_after_hit = session.player_velocity.x
	_check(dash_start_frames == [3], "the dash itself starts on F3 and never re-triggers")
	_check(not prejump_seen, "Space pressed mid-dash never enters pre-jump preparation")
	_check(throw_fail_frames == [17],
		"the B+C combination completed inside the dash's hitstop is state-rejected once on the resume frame (F17)")
	_check(hit_frame == 8 and dash_left_at_hit == 0 and hitstun_at_hit > 0 and velocity_after_hit < 0.0,
		"the dummy strike landing mid-dash (F8) interrupts it on the same frame: dash cleared, hitstun applied, knockback away from the dummy")


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


## C 键投组合配对等待（≤3 帧）：单键起手在配对窗口末帧——按完 C 后补 3 个
## 空帧再断言起手结果（票据 10 迁移 214C 识别主体的固定补偿）。
func _pairing_wait(session: CombatSession) -> void:
	for i in range(3):
		session.step(FrameInput.new())


## 相对小键盘方向 → FrameInput：按会话当前面向折算世界水平轴（3/6/9 为前），
## 1/2/3 带下方向，5 为中立；key 为该帧动作键，dummy_request 为该帧木桩攻击请求。
## 左右面向用同一份数字脚本。
func _relative_input(session: CombatSession, digit: int, key: String = "", dummy_request: String = "") -> FrameInput:
	var axis := 0
	if digit == 3 or digit == 6 or digit == 9:
		axis = session.player_facing
	elif digit == 1 or digit == 4 or digit == 7:
		axis = -session.player_facing
	var down := digit >= 1 and digit <= 3
	var input := FrameInput.make(axis, false, key, down)
	input.dummy_move_request = dummy_request
	return input


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
	move.hit_profiles = _probe_profiles(GameParams.HITSTUN_FRAMES, GameParams.MOVE_5A_KNOCKBACK)
	move.starter_grade = MoveData.StarterGrade.D
	return move


## 木桩确定性攻击探针：显式攻击属性 + 正交 air 标记；无动作键绑定（玩家无法
## 主动使用，隔离木桩攻击表）。短窗口（2/4/3）与 hitstun 10 便于逐帧断言。
func _dummy_strike(id: String, attribute: int, air: bool) -> MoveData:
	var move := _probe_move(id, "")
	move.attack_attribute = attribute
	move.air_attack = air
	move.startup_frames = 2
	move.active_frames = 4
	move.recovery_frames = 3
	move.hit_profiles = _dummy_profiles()
	move.starter_grade = MoveData.StarterGrade.D
	return move


## 属性矩阵注入表：high/mid/low/overhead 纯地面属性 + air 正交标记的高位打击。
func _dummy_attribute_table() -> Dictionary:
	return {
		"D_H": _dummy_strike("D_H", MoveData.AttackAttribute.HIGH, false),
		"D_M": _dummy_strike("D_M", MoveData.AttackAttribute.MID, false),
		"D_L": _dummy_strike("D_L", MoveData.AttackAttribute.LOW, false),
		"D_O": _dummy_strike("D_O", MoveData.AttackAttribute.OVERHEAD, false),
		"D_A": _dummy_strike("D_A", MoveData.AttackAttribute.HIGH, true),
	}


func _range_all(values: Array, from: int, to: int, expected: Variant) -> bool:
	for i in range(from, to + 1):
		if values[i] != expected:
			return false
	return true


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
	_set_probe_launch(launcher, 12, 0.0, GameParams.float_launch_speed())
	launcher.cancel_window_frames = 60
	var probe := _probe_move("5A", "A")
	probe.startup_frames = 2
	probe.active_frames = 2
	probe.recovery_frames = 8
	probe.base_damage = 10
	_set_probe_stun(probe, 30)
	_set_probe_horizontal(probe, 0.0)
	return {"5C": launcher, "5A": probe}


## 长浮空表：硬直超过滞空，验证落地保留剩余浮空硬直。
func _long_float_table(float_hitstun: int) -> Dictionary:
	var table := _float_probe_table()
	MoveData.profile_for(table["5C"], HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL).air_untech_frames = float_hitstun
	return table


## 慢速地面表：5A 前摇 8 帧（F1 出招、F9 命中），用于缓存年龄边界。
func _slow_ground_table() -> Dictionary:
	var starter := _probe_move("5A", "A")
	starter.startup_frames = 8
	starter.active_frames = 2
	starter.recovery_frames = 12
	starter.base_damage = 10
	_set_probe_stun(starter, 20)
	_set_probe_horizontal(starter, 0.0)
	starter.cancel_targets = ["5B"]
	var linker := _probe_move("5B", "B")
	linker.startup_frames = 4
	linker.active_frames = 2
	linker.recovery_frames = 10
	linker.base_damage = 12
	_set_probe_stun(linker, 20)
	_set_probe_horizontal(linker, 0.0)
	return {"5A": starter, "5B": linker}


## 快速单招表：短窗口长硬直，用于独立招式绕过取消的验证。
func _fast_single_move_table() -> Dictionary:
	var move := _probe_move("5A", "A")
	move.startup_frames = 2
	move.active_frames = 2
	move.recovery_frames = 3
	move.base_damage = 10
	_set_probe_stun(move, 30)
	_set_probe_horizontal(move, 0.0)
	return {"5A": move}


## 互相取消的双招表：5A ↔ 5B，用于伤害递减下限与无命中数上限。
func _loop_table() -> Dictionary:
	var move_a := _probe_move("5A", "A")
	move_a.startup_frames = 2
	move_a.active_frames = 2
	move_a.recovery_frames = 8
	move_a.base_damage = 10
	_set_probe_stun(move_a, 60)
	_set_probe_horizontal(move_a, 0.0)
	move_a.cancel_targets = ["5B"]
	var move_b := _probe_move("5B", "B")
	move_b.startup_frames = 2
	move_b.active_frames = 2
	move_b.recovery_frames = 8
	move_b.base_damage = 10
	_set_probe_stun(move_b, 60)
	_set_probe_horizontal(move_b, 0.0)
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


## 落地接缝表：共享表 + 调低 236C 的击飞高度并放宽受身（480/38）——受身截止
## 不再卡在 jA 的最后一帧，木桩下落段穿过落地帧命中框，接缝语义有余量。
## 接缝测试的对象是同帧顺序与落地锁，不是共享表的最终调校值。
func _seam_table() -> Dictionary:
	## 票据 05 起 236C 迁移为两段判定且不再承担 launcher/jump cancel；落地接缝
	## 力学（issue 时代行为）改由注入的「旧单段 launcher」形态承载——这是探针
	## 假设，不代表共享表行为。临界帧编排按「实际应用值」设计：路线里 236C 是
	## 第二击（A 起手时间层 0.72×0.94=0.658、轨迹层 0.72×0.95=0.684），声明值
	## 补偿修正后保持 round(730×0.658)=480 的垂直速度与 floor(58×0.658)=38 的
	## 受身计时。
	var table := MoveData.default_table()
	var launcher := table["236C"] as MoveData
	var profile := MoveData.profile_for(launcher, HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL)
	profile.upward_speed_px_s = 730.0
	profile.air_untech_frames = 58
	profile.horizontal_speed_px_s = 200.0
	launcher.active_frames = 5
	launcher.recovery_frames = 18
	launcher.base_damage = 18
	launcher.attack_attribute = MoveData.AttackAttribute.HIGH
	launcher.segments = [] as Array[MoveSegment]
	launcher.special_entry_targets = [] as Array[String]
	launcher.special_entry_window_frames = -1
	launcher.hit_profiles = [profile]
	launcher.jump_cancel_targets = ["jA"] as Array[String]
	return table


## 探针命中资料（上下文命中资料迁移）：grounded normal/counter 同值——既有回归
## 不区分 counter 变体，只要求上下文匹配不落空。
func _probe_profiles(stun: int, horizontal: float) -> Array[HitProfile]:
	var normal := HitProfile.new()
	normal.target_state = HitProfile.TargetState.GROUNDED
	normal.hit_context = HitProfile.HitContext.NORMAL
	normal.reaction = HitProfile.Reaction.GROUND_HITSTUN
	normal.ground_stun_frames = stun
	normal.horizontal_speed_px_s = horizontal
	normal.upward_speed_px_s = 0.0
	var counter := normal.duplicate() as HitProfile
	counter.hit_context = HitProfile.HitContext.COUNTER
	return [normal, counter]


func _set_probe_stun(move: MoveData, frames: int) -> void:
	for profile in move.hit_profiles:
		profile.ground_stun_frames = frames


func _set_probe_horizontal(move: MoveData, speed: float) -> void:
	for profile in move.hit_profiles:
		profile.horizontal_speed_px_s = speed


## 把探针的全部 profile 改写为 LAUNCH（旧 hit_result=LAUNCH + hitstun + 击退
## 三件套的等价迁移：受身计时、水平幅值与垂直初速度进入每个 profile）。
func _set_probe_launch(move: MoveData, untech: int, horizontal: float, upward: float) -> void:
	for profile in move.hit_profiles:
		profile.reaction = HitProfile.Reaction.LAUNCH
		profile.ground_stun_frames = -1
		profile.air_untech_frames = untech
		profile.horizontal_speed_px_s = horizontal
		profile.upward_speed_px_s = upward


## 木桩攻击探针的命中资料：grounded normal/counter（硬直 10）+ airborne normal
## LAUNCH（空中受身 10、微垂直初速度）——空防矩阵的空中命中与玩家侧计时共用。
func _dummy_profiles() -> Array[HitProfile]:
	var profiles := _probe_profiles(10, 100.0)
	var airborne := HitProfile.new()
	airborne.target_state = HitProfile.TargetState.AIRBORNE
	airborne.hit_context = HitProfile.HitContext.NORMAL
	airborne.reaction = HitProfile.Reaction.LAUNCH
	airborne.air_untech_frames = 10
	airborne.horizontal_speed_px_s = 100.0
	airborne.upward_speed_px_s = 60.0
	profiles.append(airborne)
	return profiles


# --- 票据 04：Rekka 首段、派生锁定与地空结果 ---
## 时间轴约定：B/C 是投组合成员键——中立按下有 3 物理帧组合等待，C 在 F4 按下
## 时 214C 首段 F1=F7、active F14–F17、接触 F14、停顿 F15–F22、恢复 F23；
## 2C 起手同样 +3（F1 按下、F4 起手）。停顿中的按键照常采样锁分支。


## 相对方向输入 + 木桩防御请求（Rekka 回放共用）。
func _rekka_input(session: CombatSession, digit: int, key: String, guard := 0) -> FrameInput:
	var input := _relative_input(session, digit, key)
	input.dummy_guard_request = guard
	return input


## 同帧多键按下输入（同帧 B+C 仲裁用：pressed/held 同时含两键）。
func _multi_key_input(keys: Array, guard := 0) -> FrameInput:
	var input := FrameInput.new()
	for key in keys:
		input.pressed_action_keys.append(key)
		input.held_action_keys.append(key)
	input.dummy_guard_request = guard
	return input


## 裸 214C 起手脚本：F1–F3 喂 2/1/4，F4 按 C——首段 F1=F7，active F14–F17。
func _run_214c_opener(session: CombatSession, guard := 0) -> Array[CombatEvent]:
	var events: Array[CombatEvent] = []
	for frame in range(1, 5):
		var digit: int = [2, 1, 4, 5][frame - 1]
		var key := "C" if frame == 4 else ""
		events.append_array(session.step(_rekka_input(session, digit, key, guard)))
	return events


func _test_rekka_window_requires_contact_hit_block_whiff() -> void:
	# 命中：首段命中开放派生窗口——停顿中按 B 立即锁 ~B，恢复首个正常帧起手派生。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(60, 0)
	var events := _run_214c_opener(session)
	var move_after := {}
	for frame in range(5, 45):
		var key := "B" if frame == 16 else ""
		events.append_array(session.step(_rekka_input(session, 5, key)))
		move_after[frame] = session.player_move_id
	var locks := events.filter(func(e: CombatEvent) -> bool: return e.type == CombatEvent.Type.REKKA_BRANCH_LOCKED)
	_check(locks.size() == 1 and locks[0].rekka_branch == "B" and locks[0].rekka_move_id == "214C~B",
		"first hit contact opens the derivation window and the first B press locks 214C~B")
	_check(move_after[23] == "214C" and move_after[24] == "214C~B",
		"the locked branch starts the derived move on the first normal frame after the freeze")
	_check(_count_events(events, CombatEvent.Type.HIT) == 2,
		"both the opener and the derived 214C~B land as real hits")
	# 被防：首段被站防同样开放派生窗口——分支锁定不依赖命中。
	var session2 := CombatSession.new()
	session2.dummy_position = session2.player_position + Vector2(60, 0)
	var events2 := _run_214c_opener(session2, CombatSession.GuardPosture.STANDING)
	var move_after2 := {}
	var starter_at_25: int = -1
	for frame in range(5, 45):
		var key := "B" if frame == 16 else ""
		var input := _rekka_input(session2, 5, key)
		input.dummy_guard_request = CombatSession.GuardPosture.STANDING if frame <= 30 else 0
		events2.append_array(session2.step(input))
		move_after2[frame] = session2.player_move_id
		if frame == 25:
			starter_at_25 = session2.combo_starter_grade
	_check(_count_events(events2, CombatEvent.Type.ATTACK_BLOCKED) == 1
		and _count_events(events2, CombatEvent.Type.REKKA_BRANCH_LOCKED) == 1,
		"a blocked opener contact still opens the window and locks the branch")
	_check(move_after2[24] == "214C~B",
		"the derivation starts after the blocked contact freeze as well")
	_check(_count_events(events2, CombatEvent.Type.HIT) == 1 and starter_at_25 == MoveData.StarterGrade.UNSET,
		"the blocked opener does not count as a hit and locks no starter; the derived 214C~B (low) leaks through the standing guard as a fresh B-starter combo")
	# 挥空：无接触不开窗口——B 只是普通输入，派生从不发生。
	var session3 := CombatSession.new()
	session3.dummy_position = session3.player_position + Vector2(200, 0)
	var events3 := _run_214c_opener(session3)
	var move_ids := []
	for frame in range(5, 45):
		var key := "B" if frame == 16 else ""
		events3.append_array(session3.step(_rekka_input(session3, 5, key)))
		move_ids.append(session3.player_move_id)
	_check(_count_events(events3, CombatEvent.Type.REKKA_BRANCH_LOCKED) == 0 and not move_ids.has("214C~B"),
		"a whiffed opener never opens the derivation window")
	_check(_count_events(events3, CombatEvent.Type.HIT) == 0 and _count_events(events3, CombatEvent.Type.ATTACK_BLOCKED) == 0,
		"a whiff produces no contact at all")


func _test_rekka_first_press_locks_branch() -> void:
	# 同帧 B+C：固定 C > B 优先级直接锁 ~C，不产生普通投等待或投意图。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(60, 0)
	var events := _run_214c_opener(session)
	var move_after := {}
	var branch_at_16 := ""
	for frame in range(5, 45):
		var input := _rekka_input(session, 5, "")
		if frame == 16:
			input = _multi_key_input(["B", "C"])
		events.append_array(session.step(input))
		move_after[frame] = session.player_move_id
		if frame == 16:
			branch_at_16 = String(session.debug_snapshot()["rekka_branch"])
	_check(branch_at_16 == "C",
		"a same-frame B+C press locks ~C immediately (fixed C > B priority)")
	_check(_count_events(events, CombatEvent.Type.REKKA_BRANCH_LOCKED) == 1,
		"only one branch lock event is emitted for the same-frame press")
	_check(_count_events(events, CombatEvent.Type.THROW_FAILED) == 0 and _count_events(events, CombatEvent.Type.THROW_HIT) == 0,
		"the same-frame B+C inside the window never becomes a throw combination")
	_check(move_after[24] == "214C~C",
		"the locked ~C branch starts after the freeze")
	# 先 B 后 C：首按锁 ~B，之后另一键不改写分支。
	var session2 := CombatSession.new()
	session2.dummy_position = session2.player_position + Vector2(60, 0)
	var events2 := _run_214c_opener(session2)
	var move_after2 := {}
	for frame in range(5, 45):
		var key := ""
		if frame == 16:
			key = "B"
		elif frame == 19:
			key = "C"
		events2.append_array(session2.step(_rekka_input(session2, 5, key)))
		move_after2[frame] = session2.player_move_id
	var locks2 := events2.filter(func(e: CombatEvent) -> bool: return e.type == CombatEvent.Type.REKKA_BRANCH_LOCKED)
	_check(locks2.size() == 1 and locks2[0].rekka_branch == "B",
		"the first B press locks ~B and the later C press cannot rewrite the branch")
	_check(move_after2[24] == "214C~B" and not (move_after2.values() as Array).has("214C~C"),
		"the derived move stays 214C~B and ~C never starts")
	_check(_count_events(events2, CombatEvent.Type.THROW_FAILED) == 0,
		"the later C press does not pair into a throw with the consumed B press")
	# 同帧 D+B：~B 照常锁定；D 不被派生仲裁吞掉，照常写入单键缓存。
	var session3 := CombatSession.new()
	session3.dummy_position = session3.player_position + Vector2(60, 0)
	var events3 := _run_214c_opener(session3)
	var buffered_at_16 := ""
	for frame in range(5, 45):
		var input := _rekka_input(session3, 5, "")
		if frame == 16:
			input = _multi_key_input(["D", "B"])
		events3.append_array(session3.step(input))
		if frame == 16:
			buffered_at_16 = String(session3.debug_snapshot()["buffered_key"])
	_check(_count_events(events3, CombatEvent.Type.REKKA_BRANCH_LOCKED) == 1
		and buffered_at_16 == "D" and session3.player_move_id == "214C~B",
		"a same-frame D+B press still locks ~B while the D press buffers normally")


func _test_rekka_window_expiry_keeps_throw_rules_outside() -> void:
	# 窗口长度 12：接触年龄 13 起关闭——窗口外 B+C 走既有组合规则（配对成功、
	# 招式中被状态门拒绝），窗口关闭后释放的新组合在恢复后可正常投。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(60, 0)
	var events := _run_214c_opener(session, CombatSession.GuardPosture.STANDING)
	var move_after := {}
	for frame in range(5, 70):
		var input := _rekka_input(session, 5, "", CombatSession.GuardPosture.STANDING if frame <= 20 else 0)
		if frame == 36 or frame == 48:
			input = _multi_key_input(["B", "C"])
		events.append_array(session.step(input))
		move_after[frame] = session.player_move_id
	_check(_count_events(events, CombatEvent.Type.REKKA_BRANCH_LOCKED) == 0,
		"a B+C press after the derivation window closes locks no branch")
	var failed := events.filter(func(e: CombatEvent) -> bool:
		return e.type == CombatEvent.Type.THROW_FAILED)
	_check(failed.size() == 1 and failed[0].throw_fail_reason == CombatEvent.ThrowFailReason.STATE,
		"outside the window B+C pairs normally and the throw is state-gated while the opener still runs")
	_check(move_after[48] == "BC" and _count_events(events, CombatEvent.Type.THROW_HIT) == 1,
		"after the opener fully recovers a fresh B+C combination executes the throw with existing rules")


func _test_rekka_b_ground_knockdown_airborne_extension_and_link() -> void:
	# 地面：首段命中地面目标后 ~B 命中 grounded → GROUND_KNOCKDOWN，连段与修正清除。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(60, 0)
	var events := _run_214c_opener(session)
	for frame in range(5, 50):
		var key := "B" if frame == 16 else ""
		events.append_array(session.step(_rekka_input(session, 5, key)))
	_check(session.dummy_state == CombatSession.DummyState.KNOCKED_DOWN,
		"214C~B on a grounded target causes a normal knockdown")
	_check(_combo_end_events(events, CombatEvent.ComboEndReason.KNOCKDOWN) == 1
		and not session.combo_active and session.combo_starter_grade == MoveData.StarterGrade.UNSET,
		"the knockdown ends the combo and clears the starter and corrections")
	# 空中（正例路线 2C > 214C > ~B > 5B）：~B 命中 airborne → 延长浮空而非倒地，
	# 触地转地面硬直保剩余计时，~B 完全恢复后普通连接 5B 命中。
	# 时间轴：2C F1=F4、接触 F12、停顿 F13–F20；停顿中 F15–F17 喂 214、F18 按 C、
	# 214C F1=F21、接触 F28（空中）、停顿 F29–F36；F30 按 B、~B F1=F37、接触 F43、
	# 停顿 F44–F51；~B 收招 F72、F68 缓存 B、5B 起手 F72、命中 F78。
	var session2 := CombatSession.new()
	session2.dummy_position = session2.player_position + Vector2(48, 0)
	var events2: Array[CombatEvent] = []
	var states := {}
	for frame in range(1, 95):
		var digit := 5
		var key := ""
		if frame == 1:
			digit = 2
			key = "C"
		elif frame in [15, 16, 17]:
			digit = [2, 1, 4][frame - 15]
		elif frame == 19:
			key = "C"
		elif frame == 32:
			key = "B"
		elif frame == 70:
			key = "B"
		events2.append_array(session2.step(_rekka_input(session2, digit, key)))
		if frame == 48:
			states["state_at_48"] = session2.dummy_state
		elif frame == 65:
			states["state_at_65"] = session2.dummy_state
		elif frame == 74:
			states["move_at_74"] = session2.player_move_id
	_check(_count_events(events2, CombatEvent.Type.HIT) == 4,
		"the canonical route 2C > 214C > 214C~B > 5B lands four real hits")
	_check(states["state_at_48"] == CombatSession.DummyState.AIR_HITSTUN,
		"~B on an airborne target extends the float instead of knocking down")
	_check(states["state_at_65"] == CombatSession.DummyState.GROUND_HITSTUN,
		"the extended float lands and converts to ground hitstun keeping the remaining timer")
	_check(states["move_at_74"] == "5B",
		"the buffered 5B is consumed as a normal link on the frame 214C~B fully recovers")
	_check(_count_events(events2, CombatEvent.Type.SPIKE_LANDED) == 0,
		"~B never triggers the downward-slam landing conversion")


func _test_rekka_c_ground_knockdown_and_airborne_spike() -> void:
	# 地面：~C 命中 grounded 直接普通倒地收尾。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(60, 0)
	var events := _run_214c_opener(session)
	for frame in range(5, 50):
		var key := "C" if frame == 16 else ""
		events.append_array(session.step(_rekka_input(session, 5, key)))
	_check(session.dummy_state == CombatSession.DummyState.KNOCKED_DOWN
		and _combo_end_events(events, CombatEvent.ComboEndReason.KNOCKDOWN) == 1,
		"214C~C on a grounded target knocks down directly")
	_check(_count_events(events, CombatEvent.Type.SPIKE_LANDED) == 0,
		"a grounded ~C hit does not go through the spike fall")
	# 空中：~C 命中 airborne 使用独立向下击落资料——先坠落（SPIKE_FALL），
	# 触地同帧转普通倒地并发出 SPIKE_LANDED；收尾在命中当帧结束连段。
	# 时间轴：同上正例路线，F30 按 C、~C F1=F37、接触 F45（空中）、停顿 F46–F53、
	# 触地转倒地约 F55。
	var session2 := CombatSession.new()
	session2.dummy_position = session2.player_position + Vector2(48, 0)
	var events2: Array[CombatEvent] = []
	var spike_states := []
	for frame in range(1, 75):
		var digit := 5
		var key := ""
		if frame == 1:
			digit = 2
			key = "C"
		elif frame in [15, 16, 17]:
			digit = [2, 1, 4][frame - 15]
		elif frame == 19:
			key = "C"
		elif frame == 32:
			key = "C"
		events2.append_array(session2.step(_rekka_input(session2, digit, key)))
		if frame >= 49 and frame <= 58:
			spike_states.append(session2.dummy_state)
	_check(_count_events(events2, CombatEvent.Type.HIT) == 3,
		"2C > 214C > 214C~C lands three hits before the spike conversion")
	_check(spike_states.has(CombatSession.DummyState.SPIKE_FALL),
		"~C on an airborne target enters the downward spike fall instead of an instant knockdown")
	_check(session2.dummy_state == CombatSession.DummyState.KNOCKED_DOWN
		and _count_events(events2, CombatEvent.Type.SPIKE_LANDED) == 1,
		"the spike lands and converts to a normal knockdown on touch")
	_check(_combo_end_events(events2, CombatEvent.ComboEndReason.FINISHER) == 1,
		"~C is a finisher: the combo ends on its hit frame")
	_check(not session2.combo_active and session2.combo_starter_grade == MoveData.StarterGrade.UNSET,
		"the finisher clears the combo starter and corrections")


func _test_rekka_starter_and_corrections_across_rekka() -> void:
	# 2C(C 起手) > 214C > 214C~B：起手等级锁定 C，三层修正跨 Rekka 每击累计保留。
	# 接触帧：2C F12、214C F28、~B F43；停顿冻结期字段稳定，采样点取接触后。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(48, 0)
	var events: Array[CombatEvent] = []
	var scales := {}
	for frame in range(1, 55):
		var digit := 5
		var key := ""
		if frame == 1:
			digit = 2
			key = "C"
		elif frame in [15, 16, 17]:
			digit = [2, 1, 4][frame - 15]
		elif frame == 19:
			key = "C"
		elif frame == 32:
			key = "B"
		events.append_array(session.step(_rekka_input(session, digit, key)))
		if frame == 15:
			scales["after_2c"] = [session.combo_starter_grade, session.combo_time_scale]
		elif frame == 32:
			scales["after_214c"] = [session.combo_starter_grade, session.combo_time_scale]
		elif frame == 48:
			scales["after_b"] = [session.combo_starter_grade, session.combo_time_scale]
	_check(scales["after_2c"] == [MoveData.StarterGrade.C, 0.90],
		"the first real hit locks the C starter and initializes the time layer")
	_check(scales["after_214c"] == [MoveData.StarterGrade.C, 0.90 * 0.94],
		"the opener hit keeps the starter and multiplies the time layer")
	_check(scales["after_b"] == [MoveData.StarterGrade.C, 0.90 * 0.94 * 0.94],
		"the derived hit continues accumulating across the Rekka chain")


func _test_rekka_blocked_derivation_only_block_result() -> void:
	# 蹲防全程：首段 mid 被防开放窗口，~B low 同样被防——派生只产生对应 BLOCKED
	# 结果，不产生命中、不锁起手、不累计修正。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(60, 0)
	var events := _run_214c_opener(session, CombatSession.GuardPosture.CROUCH)
	for frame in range(5, 50):
		var key := "B" if frame == 16 else ""
		events.append_array(session.step(_rekka_input(session, 5, key, CombatSession.GuardPosture.CROUCH)))
	_check(_count_events(events, CombatEvent.Type.ATTACK_BLOCKED) == 2
		and _count_events(events, CombatEvent.Type.HIT) == 0,
		"both the opener and the derived 214C~B are blocked with zero hits")
	_check(_count_events(events, CombatEvent.Type.REKKA_BRANCH_LOCKED) == 1,
		"the derivation branch still locks from the blocked contact")
	_check(not session.combo_active and session.combo_hits == 0
		and session.combo_starter_grade == MoveData.StarterGrade.UNSET
		and is_equal_approx(session.combo_time_scale, 1.0),
		"blocked derivations lock no starter and accumulate no corrections")


func _test_rekka_only_moves_not_input_startable() -> void:
	# 派生招式不参与单键/指令选择：中立按 B 起手 5B（组合等待 3 帧后 F4 起手）；
	# 214 方向后按 B 仍是 5B；214 方向后按 C 起手首段 214C（首段本身是普通指令招式）。
	var session := CombatSession.new()
	for frame in range(1, 6):
		session.step(FrameInput.make(0, false, "B" if frame == 1 else ""))
	_check(session.player_move_id == "5B",
		"a neutral B press starts 5B, not the rekka-only 214C~B")
	var session2 := CombatSession.new()
	for frame in range(1, 9):
		var digit: int = [2, 1, 4, 5, 5, 5, 5, 5][frame - 1]
		var key := "B" if frame == 4 else ""
		session2.step(_relative_input(session2, digit, key))
	_check(session2.player_move_id == "5B",
		"after the 214 motion a B press still resolves to 5B (derived moves are not input-selectable)")
	var session3 := CombatSession.new()
	for frame in range(1, 9):
		var digit: int = [2, 1, 4, 5, 5, 5, 5, 5][frame - 1]
		var key := "C" if frame == 4 else ""
		session3.step(_relative_input(session3, digit, key))
	_check(session3.player_move_id == "214C",
		"the opener 214C itself is a normal command move and starts from 214+C")


# --- 票据 05：236C 两段、GROUND_SLIDE 与来源限定 D ---

func _test_236c_two_segments_windows_events_and_states() -> void:
	# 两段判定（S-01/S-02）：段 1 独立 active/命中框/资料，段间隔 3f 是段 2 的
	# 前摇（Counter 窗口）；每段对同一目标至多命中一次；两段实际命中各自产生
	# HIT 事件与伤害（8/12 × 各层修正）。@70px 两段都够得着。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var phases: Array[int] = []
	var segments: Array[int] = []
	var hits: Array[int] = []
	var seg1_rect_width := -1.0
	var seg2_rect_width := -1.0
	var airborne_after_seg2 := false
	for frame in range(1, 60):
		var down := frame == 1 or frame == 2
		var axis := 1 if (frame == 2 or frame == 3) else 0
		var key := "C" if frame == 4 else ""
		var events := session.step(FrameInput.make(axis, false, key, down))
		phases.append(session.player_phase)
		if frame == 12 or frame == 13:
			seg1_rect_width = session.player_attack_rect().size.x
		if frame == 25 or frame == 26:
			seg2_rect_width = session.player_attack_rect().size.x
		for event in events:
			if event.type == CombatEvent.Type.HIT:
				hits.append(frame)
				segments.append(event.move_segment)
		if frame == 27:
			airborne_after_seg2 = session.dummy_state == CombatSession.DummyState.AIR_HITSTUN and not session.dummy_on_ground
	_check(_phase_range(phases, 6, 10, CombatSession.PlayerPhase.STARTUP), "segment 1 startup covers F7-F11 (move starts F7 after the 3f C wait)")
	_check(_phase_range(phases, 11, 12, CombatSession.PlayerPhase.ACTIVE), "segment 1 is active on F12-F13")
	_check(_phase_range(phases, 21, 23, CombatSession.PlayerPhase.STARTUP), "the 3f inter-segment gap counts as segment 2 startup (F22-F24 after the freeze)")
	_check(_phase_range(phases, 24, 25, CombatSession.PlayerPhase.ACTIVE), "segment 2 is active on F25-F26")
	_check(_phase_range(phases, 34, 55, CombatSession.PlayerPhase.RECOVERY), "recovery runs F35-F56 (the second freeze shifts the frame count)")
	_check(hits == [13, 26] and segments == [1, 2], "both segments hit exactly once each with their own event and segment tag")
	_check(is_equal_approx(seg1_rect_width, 40.0) and is_equal_approx(seg2_rect_width, 46.0), "each segment declares its own hitbox width (40 vs 46)")
	_check(session.combo_hits == 2 and _approx(session.dummy_hp, GameParams.DUMMY_MAX_HP - 8.0 - 10.8), "segment damage applies per segment at the D-starter layers (8×1.0 + 12×0.90)")
	_check(airborne_after_seg2, "segment 2 hitting the floated target applies its airborne profile (extension, no slide)")


func _test_236c_seg1_blocked_terminates_whole_move() -> void:
	# 段 1 被防立即终止整招（S-02）：只产生段 1 的被防结果（停顿/硬直/推退），
	# 段 2 不执行、无第二次段接触；停顿后玩家直接回中立。被防不授予特殊进入
	# 资格——停顿中按 D 只在恢复后作为独立 5D 起手，且因木桩连防再次被防。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var blocked_frames: Array[int] = []
	var blocked_segments: Array[int] = []
	var entry_seen := false
	for frame in range(1, 55):
		var down := frame == 1 or frame == 2
		var axis := 1 if (frame == 2 or frame == 3) else 0
		var key := "C" if frame == 4 else ("D" if frame == 15 else "")
		var input := FrameInput.make(axis, false, key, down)
		input.dummy_guard_request = CombatSession.GuardPosture.STANDING if frame <= 40 else 0
		var events := session.step(input)
		for event in events:
			if event.type == CombatEvent.Type.ATTACK_BLOCKED:
				blocked_frames.append(frame)
				blocked_segments.append(event.move_segment)
		entry_seen = entry_seen or bool(session.debug_snapshot()["special_entry_open"])
		if frame == 14:
			_check(session.player_move_id == "" and session.player_phase == CombatSession.PlayerPhase.NEUTRAL, "the whole move is cleared during the block freeze (no segment 2 commitment)")
	_check(blocked_frames == [13, 29] and blocked_segments == [1, 1], "segment 1 is blocked on F13 and the move terminates; the later D press only starts an independent 5D that is blocked in turn")
	_check(session.combo_hits == 0 and not session.combo_active, "no hit is ever recorded on the blocked route")
	_check(not entry_seen, "a blocked 236C never grants the special D entry qualification")
	_check(session.dummy_state == CombatSession.DummyState.NEUTRAL and session.dummy_blockstun_left == 0, "the dummy finishes its blockstun and returns to neutral")


func _test_236c_seg1_whiff_seg2_ground_slide_lifecycle() -> void:
	# 段 1 挥空不终止（S-03）：@93px 段 1 命中框够不着、段 2 够得着——段 2 命中
	# grounded 目标进入击飞触地滑行（S-04）：LOW_FLOAT_TO_SLIDE 滞空（untech 15、
	# 起跳 round(120×0.96)=115 px/s）→ F36 触地转 GROUND_SLIDE（slide 17 帧，
	# 自下一正常帧倒数）→ F53 自然回中立并结束连段；不经过普通倒地、无 OTG。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(93, 0)
	var hits: Array[int] = []
	var slide_start := -1
	var recovered := -1
	var knockdown_seen := false
	var slide_distances: Array[float] = []
	var starter_in_window: int = MoveData.StarterGrade.UNSET
	for frame in range(1, 80):
		var down := frame == 1 or frame == 2
		var axis := 1 if (frame == 2 or frame == 3) else 0
		var key := "C" if frame == 4 else ""
		var events := session.step(FrameInput.make(axis, false, key, down))
		var combo_closed_at := -1
		for event in events:
			if event.type == CombatEvent.Type.HIT:
				hits.append(frame)
			elif event.type == CombatEvent.Type.SLIDE_STARTED:
				slide_start = frame
			elif event.type == CombatEvent.Type.COMBO_ENDED:
				combo_closed_at = frame
			elif event.type == CombatEvent.Type.DUMMY_RECOVERED:
				recovered = frame
		knockdown_seen = knockdown_seen or session.dummy_state == CombatSession.DummyState.KNOCKED_DOWN
		if frame == 19:
			_check(session.dummy_state == CombatSession.DummyState.LOW_FLOAT_TO_SLIDE and not session.dummy_on_ground \
				and session.dummy_hitstun_left == 15 and session.dummy_slide_left == 17, "segment 2 launches the grounded target into the float-before-slide state with pre-scaled timers (floor(16×0.96)/floor(18×0.96))")
		if frame == 40:
			starter_in_window = session.combo_starter_grade
		if frame == 20 or frame == 45:
			slide_distances.append(session.dummy_position.x)
	_check(hits == [18], "segment 1 whiffs at 93px and only segment 2 connects (F18, grounded profile)")
	_check(slide_start == 36, "touchdown on F36 converts the float into GROUND_SLIDE with the SLIDE_STARTED event")
	_check(slide_distances.size() == 2 and slide_distances[1] > slide_distances[0] + 5.0, "the dummy keeps travelling away through the float and the slide (real displacement, not a pinned probe)")
	_check(recovered == 53 and session.dummy_state == CombatSession.DummyState.NEUTRAL, "the slide timer runs out into natural neutral recovery (F53) after the combo already closed at the entry-window expiry (F43)")
	_check(not knockdown_seen, "the slide path never passes through a normal knockdown (no OTG state mixing)")
	_check(starter_in_window == MoveData.StarterGrade.D, "the lone segment 2 hit locks the D starter kept across the slide (until the combo closes)")


func _test_special_d_entry_pickup_and_5b_link() -> void:
	# 来源限定 D 进入与目押（I-05）：段 2 命中授予一次性资格（Hitstop 中保持），
	# D 在窗口内按下经取消路径消费起手普通 5D（via special entry）；5D 实际命中
	# 覆盖浮空状态；5B 只在 5D 完全恢复后作为普通连接起手（F70），5D 恢复期间
	# 不被打断；连段最终以木桩自然恢复结束。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var hits: Array[int] = []
	var move_at := {}
	for frame in range(1, 110):
		var down := frame == 1 or frame == 2
		var axis := 1 if (frame == 2 or frame == 3) else 0
		var key := ""
		if frame == 4:
			key = "C"
		elif frame == 26:
			key = "D"
		elif frame == 66:
			key = "B"
		var events := session.step(FrameInput.make(axis, false, key, down))
		for event in events:
			if event.type == CombatEvent.Type.HIT:
				hits.append(frame)
		move_at[frame] = session.player_move_id
		if frame == 14:
			_check(bool(session.debug_snapshot()["special_entry_open"]), "segment 1's hit already grants the one-time special D entry qualification (each segment grants its own)")
		if frame == 36:
			var snap := session.debug_snapshot()
			_check(String(snap["move_id"]) == "5D" and bool(snap["move_via_special_entry"]) and not bool(snap["special_entry_open"]), "5D starts via the consumed qualification (source-limited, one-time)")
		if frame == 69:
			_check(session.player_move_id == "5D", "the buffered 5B never interrupts 5D mid-recovery (no reverse cancel)")
	_check(hits == [13, 26, 41, 76], "the route lands both segments, the special-entry 5D (F41) and the linked 5B (F76)")
	_check(move_at[70] == "5B", "5B starts exactly on 5D's full-recovery frame as a normal link")
	_check(session.combo_hits == 4 and _approx(session.dummy_hp, GameParams.DUMMY_MAX_HP - 42.1), "four-hit route damage accumulates across the pickup and the link")


func _test_special_d_entry_from_seg1_hit_skips_seg2() -> void:
	# 段 1 命中当下也可特殊取消 D（S-02 允许例）：取消成立则原 236C 立即结束、
	# 段 2 不执行——全程只有一次 236C 命中，5D 以第二击身份命中浮空目标。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var hits: Array[int] = []
	var hit_sources: Array[String] = []
	for frame in range(1, 60):
		var down := frame == 1 or frame == 2
		var axis := 1 if (frame == 2 or frame == 3) else 0
		var key := ""
		if frame == 4:
			key = "C"
		elif frame == 14:
			key = "D"
		var events := session.step(FrameInput.make(axis, false, key, down))
		for event in events:
			if event.type == CombatEvent.Type.HIT:
				hits.append(frame)
				hit_sources.append(session.player_move_id)
		if frame == 15:
			_check(session.player_move_id == "236C", "the D press during the freeze stays buffered until the resume frame")
	_check(hits == [13, 29] and hit_sources == ["236C", "5D"], "canceling from segment 1's hit skips segment 2 entirely (single 236C hit, then the entry 5D)")
	_check(session.combo_hits == 2 and _approx(session.dummy_hp, GameParams.DUMMY_MAX_HP - 8.0 - 16.2), "the entry 5D counts as the second hit at the 0.90 damage layer (18×0.90)")


func _test_special_d_entry_expired_window_is_independent() -> void:
	# 窗口关闭后不能补发特殊 D（I-05 拒绝例）：资格随连段结束清除；迟到的 D
	# 只作为独立招式起手，不能命中仍在硬直中的木桩（无命中确认延续）。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var hits := 0
	var via_entry_seen := false
	var last_hit_combo := 0
	for frame in range(1, 90):
		var down := frame == 1 or frame == 2
		var axis := 1 if (frame == 2 or frame == 3) else 0
		var key := ""
		if frame == 4:
			key = "C"
		elif frame == 53:
			key = "D"
		var events := session.step(FrameInput.make(axis, false, key, down))
		for event in events:
			if event.type == CombatEvent.Type.HIT:
				hits += 1
				last_hit_combo = event.combo_hits
		if session.player_move_id == "5D":
			via_entry_seen = via_entry_seen or bool(session.debug_snapshot()["move_via_special_entry"])
	_check(hits == 3 and last_hit_combo == 1, "the late D press can only hit the recovered dummy as a fresh independent combo (combo count restarts at 1)")
	_check(not via_entry_seen, "the late 5D runs as an independent move without the entry source or its link edge")


func _test_slide_pickup_requires_explicit_slide_profile() -> void:
	# slide 资料门（S-05.2）：注入去掉 5D slide 资料的表——特殊进入的 5D 在滑行
	# 目标上命中框已连接但无 (GROUND_SLIDE, normal) 资料 → HIT_MISS：不造成伤害、
	# 不覆盖滑行状态、滑行计时照常倒数；挥空/无资料不延长滑行窗口。
	var table := MoveData.default_table()
	var five_d := table["5D"] as MoveData
	var kept: Array[HitProfile] = []
	for profile in five_d.hit_profiles:
		if profile.target_state != HitProfile.TargetState.GROUND_SLIDE:
			kept.append(profile)
	five_d.hit_profiles = kept
	var session := CombatSession.new(table)
	session.dummy_position = session.player_position + Vector2(93, 0)
	var miss_frames: Array[int] = []
	var slide_left_at_miss := -1
	var slide_state_at_miss := CombatSession.DummyState.NEUTRAL
	var recovered := -1
	for frame in range(1, 80):
		var down := frame == 1 or frame == 2
		var axis := 1 if (frame == 2 or frame == 3) else 0
		var key := ""
		if frame == 4:
			key = "C"
		elif frame == 30:
			key = "D"
		var events := session.step(FrameInput.make(axis, false, key, down))
		for event in events:
			if event.type == CombatEvent.Type.HIT_MISS:
				miss_frames.append(frame)
				slide_left_at_miss = session.dummy_slide_left
				slide_state_at_miss = session.dummy_state
			elif event.type == CombatEvent.Type.COMBO_ENDED and event.combo_end_reason == CombatEvent.ComboEndReason.DUMMY_RECOVERED:
				recovered = frame
	_check(miss_frames == [37], "the special-entry 5D connects its hitbox on the sliding target but reports HIT_MISS without a slide profile (no fallback)")
	_check(slide_left_at_miss == 16 and slide_state_at_miss == CombatSession.DummyState.GROUND_SLIDE, "the miss does not override or reset the ongoing slide state")
	_check(session.combo_hits == 1 and _approx(session.dummy_hp, GameParams.DUMMY_MAX_HP - 12.0), "no damage is dealt beyond the launching segment 2 hit")
	_check(recovered == 53, "the slide window is not extended by the miss (natural recovery on schedule)")


func _test_slide_survives_whiffed_pickup() -> void:
	# 挥空后原轨迹继续（路线 R-01 拒绝例）：注入更大的段 2 水平击退使木桩滑出
	# 5D 判定范围——挥空的 5D 完全无接触（票据 06 起 5D 突进 72px 会追近约
	# 1.5 个身位，注入击退须相应加大），滑行按原时间线走完；有 D 与无 D 的
	# 两次运行恢复帧一致。
	var make_run := func(press_d: bool) -> int:
		var table := MoveData.default_table()
		var seg2 := (table["236C"] as MoveData).segments[0]
		var grounded := seg2.profile_for(HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL)
		grounded.horizontal_speed_px_s = 600.0
		var run := CombatSession.new(table)
		run.dummy_position = run.player_position + Vector2(93, 0)
		var recover_frame := -1
		for frame in range(1, 80):
			var down := frame == 1 or frame == 2
			var axis := 1 if (frame == 2 or frame == 3) else 0
			var key := ""
			if frame == 4:
				key = "C"
			elif frame == 30 and press_d:
				key = "D"
			var events := run.step(FrameInput.make(axis, false, key, down))
			for event in events:
				if event.type == CombatEvent.Type.DUMMY_RECOVERED:
					recover_frame = frame
		return recover_frame
	var with_d: int = make_run.call(true)
	var without_d: int = make_run.call(false)
	_check(with_d > 0 and with_d == without_d, "a whiffed 5D pickup leaves the slide trajectory and recovery timing untouched (%d == %d)" % [with_d, without_d])


func _test_slide_corrections_and_starter_lock() -> void:
	# 修正跨 slide 保留 + slide 命中分层倍率（frame-data 修正初值）：D 起手段 2
	# 命中（时间 0.96）→ 5D 捞起滑行目标乘 slide 倍率（0.92/0.96/0.96），与普通
	# 命中倍率（0.90/0.94/0.95）可区分；自然恢复清除全部修正。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(93, 0)
	for frame in range(1, 90):
		var down := frame == 1 or frame == 2
		var axis := 1 if (frame == 2 or frame == 3) else 0
		var key := ""
		if frame == 4:
			key = "C"
		elif frame == 30:
			key = "D"
		session.step(FrameInput.make(axis, false, key, down))
		if frame == 30:
			_check(session.combo_starter_grade == MoveData.StarterGrade.D and is_equal_approx(session.combo_time_scale, 0.96), "the D starter and its scales survive into the slide window")
		if frame == 38:
			_check(is_equal_approx(session.combo_damage_scale, 0.92) and is_equal_approx(session.combo_time_scale, 0.9216) \
				and is_equal_approx(session.combo_trajectory_scale, 0.9216), "the slide pickup applies the dedicated slide multipliers (1.0×0.92 / 0.96×0.96 / 0.96×0.96)")
	_check(session.combo_starter_grade == MoveData.StarterGrade.UNSET and is_equal_approx(session.combo_damage_scale, 1.0) \
		and is_equal_approx(session.combo_time_scale, 1.0) and is_equal_approx(session.combo_trajectory_scale, 1.0), "natural recovery clears the starter and all three correction layers")


func _test_a_starter_slide_cycle_breaks() -> void:
	# A 起手不形成 slide loop（票据 05 反例）：事件驱动的循环 5A > 236C(段命中)
	# > 特殊进入 5D > 5B 目押 > 5B 必杀取消 236C > ……——A 起手时间层衰减最快，
	# 循环在有限击数内断链（第一圈 5B 目押即因目标恢复失败），没有任何全局
	# 命中数/时长上限参与。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var pending := {}
	var combo_ended_at := -1
	var combo_end_reason := -1
	var link_fail_reason := -1
	var hits := 0
	for frame in range(1, 400):
		var key: String = pending.get(frame, "")
		var down: bool = pending.get("d%d" % frame, false)
		var axis := 1 if pending.get("a%d" % frame, false) else 0
		if frame == 1:
			key = "A"
		var events := session.step(FrameInput.make(axis, false, key, down))
		for event in events:
			if event.type == CombatEvent.Type.HIT:
				hits += 1
				var source := session.player_move_id
				if source == "5A" or source == "5B":
					pending[frame + 1] = ""
					pending["d%d" % (frame + 1)] = true
					pending[frame + 2] = ""
					pending["a%d" % (frame + 2)] = true
					pending["d%d" % (frame + 2)] = true
					pending[frame + 3] = ""
					pending["a%d" % (frame + 3)] = true
					pending[frame + 4] = "C"
				elif source == "236C":
					pending[frame + 2] = "D"
				elif source == "5D":
					pending[frame + 25] = "B"
			elif event.type == CombatEvent.Type.LINK_FAILED:
				link_fail_reason = event.link_fail_reason
			elif event.type == CombatEvent.Type.COMBO_ENDED:
				combo_ended_at = frame
				combo_end_reason = event.combo_end_reason
		if link_fail_reason != -1:
			break
	_check(combo_ended_at > 0 and hits <= 6, "the A-starter cycle breaks within a bounded number of hits (combo closed F%d after %d hits)" % [combo_ended_at, hits])
	_check(combo_end_reason == CombatEvent.ComboEndReason.DUMMY_RECOVERED \
		and link_fail_reason == CombatEvent.LinkFailReason.TARGET_RECOVERED, "the A-starter time layer runs the pickup target out before the 5B link (dummy recovers mid-5D, link fails target-recovered — no slide loop)")


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  " + label)
	else:
		_failures += 1
		print("FAIL  " + label)
