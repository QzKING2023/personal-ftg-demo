extends SceneTree
## 票据 09 单元测试：j214D 统一 GROUND_BOUNCE（grounded/airborne 双入口）、
## 触地 bounce_contact 与一次性反弹、starter grade + 三层修正跨弹地/落地保持、
## A 起手弹地后命中即收尾（BOUNCE_END）、B 起手一次性 bounce_followup 消费与
## 条件延长、独立输入、第二次 j214D 资料缺失负例、弹地不是 OTG、被防/挥空不
## 锁定起手、落地普通连接分层倍率与 236C>5D 循环负例。
## 运行：godot --headless --path . -s res://tests/test_bounce_corrections.gd

const NEAR_DX := 50.0

var _failures := 0


func _initialize() -> void:
	_test_table_entries_and_wiring()
	_test_bounce_profile_validation()
	_test_solo_input_grounded_entry()
	_test_b_route_airborne_entry_and_followup()
	_test_a_starter_bounce_ender(1)
	_test_a_starter_bounce_ender(-1)
	_test_a_starter_no_continuation()
	_test_a_starter_expired_input_boundary()
	_test_b_starter_full_extension(1)
	_test_b_starter_full_extension(-1)
	_test_b_starter_followup_not_refreshed()
	_test_bounce_is_not_otg()
	_test_blocked_and_miss_do_not_lock_starter()
	_test_landing_link_tier()
	_test_slide_and_rekka_preserve_starter()
	_test_236c_5d_loop_breaks_for_a_starter()
	_test_settlement_keys_carry_bounce_state()
	print("")
	if _failures == 0:
		print("ALL BOUNCE AND CORRECTION TESTS PASSED")
		quit(0)
	else:
		print(str(_failures) + " TEST(S) FAILED")
		quit(1)


func _spawn(dx: float, facing := 1) -> CombatSession:
	var session := CombatSession.new()
	if facing == 1:
		session.dummy_position = session.player_position + Vector2(dx, 0)
	else:
		session.dummy_position = session.player_position - Vector2(dx, 0)
		session.player_facing = -1
	return session


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS  " + message)
	else:
		_failures += 1
		print("FAIL  " + message)


func _press(key: String, down := false, axis := 0) -> FrameInput:
	var input := FrameInput.new()
	if key != "":
		input.pressed_action_keys = [key]
		input.held_action_keys = [key]
	input.down_held = down
	input.move_axis = axis
	return input


func _jump() -> FrameInput:
	var input := FrameInput.new()
	input.jump_pressed = true
	return input


func _axis(axis: int) -> FrameInput:
	var input := FrameInput.new()
	input.move_axis = axis
	return input


## 空中 214 指令逐帧输入（相对面向）：step 0=下(2)、1=下后(1)、2+=后(4)，step 3 按 D。
func _air214(step: int, facing: int) -> FrameInput:
	var input := FrameInput.new()
	match step:
		0:
			input.down_held = true
		1:
			input.down_held = true
			input.move_axis = -facing
		_:
			input.move_axis = -facing
	if step == 3:
		input.pressed_action_keys = ["D"]
		input.held_action_keys = ["D"]
	return input


## 路线运行器：按计划帧喂输入，记录命中（招式/帧/命中后快照）、起手与结束事件。
func _run_plan(plan: Dictionary, facing: int, horizon: int, dx := NEAR_DX) -> Dictionary:
	var session := _spawn(dx, facing)
	var hits: Array[Dictionary] = []
	var ends: Array[Dictionary] = []
	var bounce_contacts: Array[int] = []
	var starts: Array[Dictionary] = []
	for frame in range(1, horizon + 1):
		var input: FrameInput = plan[frame] if plan.has(frame) else FrameInput.new()
		var move_at_start := session.player_move_id
		for event in session.step(input):
			match event.type:
				CombatEvent.Type.HIT:
					hits.append({
						"frame": frame, "move": move_at_start, "hits": event.combo_hits,
						"damage": event.damage,
						"starter": session.combo_starter_grade,
						"damage_scale": session.combo_damage_scale,
						"time_scale": session.combo_time_scale,
						"trajectory_scale": session.combo_trajectory_scale,
						"bounce_followup": session.combo_bounce_followup,
					})
				CombatEvent.Type.HIT_MISS:
					hits.append({"frame": frame, "move": move_at_start, "miss": true})
				CombatEvent.Type.BOUNCE_CONTACT:
					bounce_contacts.append(frame)
				CombatEvent.Type.COMBO_ENDED:
					ends.append({"frame": frame, "reason": event.combo_end_reason})
				CombatEvent.Type.LINK_FAILED:
					ends.append({"frame": frame, "reason": -1, "link_fail": event.link_fail_reason,
						"link_move": event.link_move_id})
		if session.player_move_id != move_at_start and session.player_move_id != "":
			starts.append({"frame": frame, "move": session.player_move_id})
	return {
		"session": session, "hits": hits, "ends": ends, "starts": starts,
		"bounce_contacts": bounce_contacts,
	}


func _hit_moves(run: Dictionary) -> Array[String]:
	var moves: Array[String] = []
	for hit in run["hits"]:
		if not bool(hit.get("miss", false)):
			moves.append(hit["move"])
	return moves


# --- 表项与接线 ---

func _test_table_entries_and_wiring() -> void:
	var result := MoveTable.load_default()
	_check(result.ok, "shared manifest loads with j214D present")
	if not result.ok:
		return
	var moves := result.moves
	var j214d := moves["j214D"] as MoveData
	_check(j214d != null, "j214D exists in the shared table")
	if j214d == null:
		return
	_check(j214d.stance == MoveData.Stance.AIR and j214d.action_key == "D"
		and j214d.direction_derivation == "214D" and j214d.command_tier == MoveData.CommandTier.SPECIAL,
		"j214D is the air 214+D special (SPECIAL tier)")
	_check(j214d.startup_frames == 9 and j214d.active_frames == 4 and j214d.recovery_frames == 22
		and j214d.base_damage == 20 and j214d.starter_grade == MoveData.StarterGrade.D,
		"j214D frame data matches the tuning table (9/4/22, dmg 20, starter D)")
	_check(j214d.hitbox_size == Vector2(52, 36) and is_equal_approx(j214d.hitbox_gap, 4.0)
		and is_equal_approx(j214d.motion_x_px, 12.0) and is_equal_approx(j214d.motion_y_px, 64.0),
		"j214D declares its hitbox and planned dive motion (52×36 gap 4, motion 12/64)")
	_check(j214d.link_targets == ["5B", "6A", "214C"],
		"j214D declares the post-bounce normal links to 5B/6A/214C")
	_check(j214d.cancel_targets.is_empty() and j214d.chain_cancel_targets.is_empty()
		and j214d.special_cancel_targets.is_empty() and not j214d.is_finisher
		and j214d.hit_landing_cancel_targets.is_empty(),
		"j214D grants no cancels, no finisher flag and no landing exception")
	## 双入口资料：grounded 立即上弹、airborne 沿轨迹下落；统一 GROUND_BOUNCE 反应。
	var g_n := MoveData.profile_for(j214d, HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL)
	var g_c := MoveData.profile_for(j214d, HitProfile.TargetState.GROUNDED, HitProfile.HitContext.COUNTER)
	var a_n := MoveData.profile_for(j214d, HitProfile.TargetState.AIRBORNE, HitProfile.HitContext.NORMAL)
	var a_c := MoveData.profile_for(j214d, HitProfile.TargetState.AIRBORNE, HitProfile.HitContext.COUNTER)
	_check(g_n != null and g_c != null and a_n != null and a_c != null
		and g_n.reaction == HitProfile.Reaction.GROUND_BOUNCE
		and a_n.reaction == HitProfile.Reaction.GROUND_BOUNCE,
		"j214D declares GROUND_BOUNCE profiles for grounded and airborne entries with counter pairs")
	_check(g_n.upward_speed_px_s > 0.0 and is_equal_approx(a_n.upward_speed_px_s, 0.0)
		and g_n.air_untech_frames >= 1 and a_n.air_untech_frames >= 1,
		"grounded entry pops up immediately, airborne entry falls along the profile trajectory")
	## 第二次 j214D 负例（资料门）：不声明弹地目标键 → 对弹地目标 MISS_NO_PROFILE。
	_check(MoveData.profile_for(j214d, HitProfile.TargetState.GROUND_BOUNCE, HitProfile.HitContext.NORMAL) == null
		and MoveData.profile_for(j214d, HitProfile.TargetState.GROUND_BOUNCE, HitProfile.HitContext.COUNTER) == null,
		"j214D declares no bounce-target profile: a second j214D on a bouncing target cannot hit or re-bounce")
	## 出口接线（票据 08 预留边界在本票接通）。
	for pair in [["jA", moves["jA"] as MoveData], ["jB", moves["jB"] as MoveData], ["jC", moves["jC"] as MoveData]]:
		var move: MoveData = pair[1]
		_check(move.cancel_targets.has("j214D"), "%s cancels into j214D on hit confirm" % pair[0])
	for source in ["6D", "2D"]:
		_check((moves[source] as MoveData).air_exit_targets.has("j214D"),
			"%s declares the air exit into j214D" % source)
	## 弹地追击资料：仅 5B/6A/214C 声明弹地目标键（LAUNCH 接续）。
	for target in ["5B", "6A", "214C"]:
		var move := moves[target] as MoveData
		var bounce_n := MoveData.profile_for(move, HitProfile.TargetState.GROUND_BOUNCE, HitProfile.HitContext.NORMAL)
		var bounce_c := MoveData.profile_for(move, HitProfile.TargetState.GROUND_BOUNCE, HitProfile.HitContext.COUNTER)
		_check(bounce_n != null and bounce_c != null and bounce_n.reaction == HitProfile.Reaction.LAUNCH,
			"%s declares the bounce-target followup profile (LAUNCH normal+counter)" % target)
	for move_id in ["5A", "5C", "2A", "2B", "2C", "jA", "jB", "jC", "j5D", "j6D", "j2D", "236C"]:
		var move := moves[move_id] as MoveData
		_check(MoveData.profile_for(move, HitProfile.TargetState.GROUND_BOUNCE, HitProfile.HitContext.NORMAL) == null,
			"%s declares no bounce-target profile (explicit gate, no fallback)" % move_id)


# --- 校验拒绝 ---

func _bounce_profile(overrides: Dictionary) -> HitProfile:
	var profile := HitProfile.new()
	profile.target_state = HitProfile.TargetState.GROUNDED
	profile.hit_context = HitProfile.HitContext.NORMAL
	profile.reaction = HitProfile.Reaction.GROUND_BOUNCE
	profile.air_untech_frames = 12
	profile.horizontal_speed_px_s = 80.0
	profile.upward_speed_px_s = 100.0
	for key in overrides:
		profile.set(key, overrides[key])
	return profile


func _test_bounce_profile_validation() -> void:
	var base := MoveTable.load_default()
	_check(base.ok, "default table validates before injected-rejection probes")
	if not base.ok:
		return
	## 弹地目标键不接受再次弹地反应（一次弹地至多一次反弹）。
	var re_bounce := _bounce_profile({"target_state": HitProfile.TargetState.GROUND_BOUNCE})
	var errors := MoveTable.validate([_strike_with(_bounce_profile({})), _strike_with(re_bounce)])
	_check(errors.any(func(e: String): return e.contains("不接受再次弹地")),
		"GROUND_BOUNCE reaction on a bounce-target key is rejected (no re-bounce declaration)")
	## grounded 入口必须声明 >0 的进入上弹初速度。
	errors = MoveTable.validate([_strike_with(_bounce_profile({"upward_speed_px_s": 0.0}))])
	_check(errors.any(func(e: String): return e.contains("进入上弹初速度")),
		"grounded bounce entry without a positive pop velocity is rejected")
	## 计时字段与反应不匹配整表拒绝。
	errors = MoveTable.validate([_strike_with(_bounce_profile({"knockdown_frames": 30}))])
	_check(errors.any(func(e: String): return e.contains("knockdown_frames")),
		"foreign knockdown timer on a GROUND_BOUNCE profile is rejected")
	## 触地前窗口必须声明。
	errors = MoveTable.validate([_strike_with(_bounce_profile({"air_untech_frames": -1}))])
	_check(errors.any(func(e: String): return e.contains("air_untech_frames")),
		"missing pre-touch window on a GROUND_BOUNCE profile is rejected")


func _strike_with(profile: HitProfile) -> MoveData:
	var move := MoveData.new()
	move.move_id = "probeBounce"
	move.move_kind = MoveData.MoveKind.STRIKE
	move.stance = MoveData.Stance.AIR
	move.action_key = "D"
	move.startup_frames = 9
	move.active_frames = 4
	move.recovery_frames = 22
	move.base_damage = 20
	move.attack_attribute = MoveData.AttackAttribute.MID
	move.hitbox_size = Vector2(52, 36)
	move.hitbox_gap = 4.0
	move.starter_grade = MoveData.StarterGrade.D
	move.block_freeze_frames = 8
	move.block_stun_frames = 9
	move.block_pushback_px_s = 45.0
	move.hit_profiles = [profile]
	return move


# --- 独立输入：grounded 入口统一弹地 ---

func _test_solo_input_grounded_entry() -> void:
	var plan := {
		2: _jump(),
		10: _air214(0, 1), 11: _air214(1, 1), 12: _air214(2, 1), 13: _air214(3, 1),
	}
	var run := _run_plan(plan, 1, 130)
	var session: CombatSession = run["session"]
	var hits: Array[Dictionary] = run["hits"]
	_check(hits.size() == 1 and hits[0]["move"] == "j214D" and hits[0]["hits"] == 1,
		"solo jump-in j214D hits the grounded dummy as combo hit 1 (independent input)")
	var first := hits[0]
	_check(bool(first.get("starter", 0) == MoveData.StarterGrade.D) and int(first.get("bounce_followup", -1)) == 1,
		"D starter derives bounce_followup = 1 at GROUND_BOUNCE entry")
	var contacts: Array[int] = run["bounce_contacts"]
	_check(contacts.size() == 1, "exactly one bounce_contact fires in the whole solo flow (%s)" % str(contacts))
	_check(session.dummy_state != CombatSession.DummyState.KNOCKED_DOWN,
		"the bounced dummy never becomes KNOCKED_DOWN (bounce is not OTG knockdown)")
	var recovered := false
	for end in run["ends"]:
		if end.get("reason", -1) == CombatEvent.ComboEndReason.MOVE_RECOVERED:
			recovered = true
	_check(recovered, "without a followup input the combo ends by move-recovered while the bounce continues")
	## 反弹与窗口换算：floor(16×0.96)=15、roundf(330×0.96)=317。
	var bounce_left_seen := -1
	var rebound_seen := false
	var probe_session := _spawn(NEAR_DX, 1)
	for frame in range(1, 60):
		var input: FrameInput = plan[frame] if plan.has(frame) else FrameInput.new()
		for event in probe_session.step(input):
			if event.type == CombatEvent.Type.BOUNCE_CONTACT:
				bounce_left_seen = probe_session.dummy_bounce_left
				rebound_seen = is_equal_approx(probe_session.dummy_velocity.y, -317.0)
	_check(bounce_left_seen == 15 and rebound_seen,
		"bounce_contact opens the unified window pre-scaled by the time layer (15) and rebounds at the trajectory-scaled speed (-317 px/s)")
	## 结束：自然回中立，不转倒地。
	var final_state_ok := false
	for frame in range(1, 131):
		probe_session.step(FrameInput.new())
	final_state_ok = probe_session.dummy_state == CombatSession.DummyState.NEUTRAL and probe_session.dummy_on_ground
	_check(final_state_ok, "the bounce flow ends in natural neutral recovery on the ground")


# --- B 起手：airborne 入口 + 一次性追击消费 ---

func _b_route_plan(facing := 1) -> Dictionary:
	return {
		1: _press("B"), 16: _press("C"),
		30: _press("A", false, facing), 31: _axis(facing),
		48: _jump(),
		60: _press("B"),
		70: _air214(0, facing), 71: _air214(1, facing), 72: _air214(2, facing), 73: _air214(3, facing),
		103: _press("B"),
	}


func _test_b_route_airborne_entry_and_followup() -> void:
	var run := _run_plan(_b_route_plan(1), 1, 160)
	var session: CombatSession = run["session"]
	var moves := _hit_moves(run)
	_check(moves == ["5B", "5C", "6A", "jB", "j214D", "5B"],
		"B-starter route lands 5B>5C>6A>jc.jB>jC>j214D>5B (bounce followup hit) %s" % str(moves))
	var j214d_hit: Dictionary = {}
	var followup_hit: Dictionary = {}
	for hit in run["hits"]:
		if hit["move"] == "j214D":
			j214d_hit = hit
		elif hit["move"] == "5B" and hit["hits"] == 6:
			followup_hit = hit
	_check(not j214d_hit.is_empty() and j214d_hit["bounce_followup"] == 1,
		"B starter derives bounce_followup = 1 at the airborne bounce entry")
	_check(int(session.dummy_bounce_left) >= 0 and not followup_hit.is_empty() and followup_hit["bounce_followup"] == 0,
		"the successful bounce followup consumes the one-shot qualification (1 → 0)")
	_check(run["bounce_contacts"].size() == 1, "one bounce contact in the B route")
	## 弹地窗口按时间层预先换算：B 第 5 击后 time = 0.82×0.94⁴ ≈ 0.639 → floor(16×0.639)=10。
	var window_seen := -1
	var calib := _spawn(NEAR_DX, 1)
	var plan := _b_route_plan(1)
	for frame in range(1, 100):
		var input: FrameInput = plan[frame] if plan.has(frame) else FrameInput.new()
		for _event in calib.step(input):
			if calib.dummy_state == CombatSession.DummyState.GROUND_BOUNCE and not calib.dummy_bounce_contacted:
				window_seen = calib.dummy_bounce_left
	_check(window_seen == 10,
		"the bounce window is pre-scaled at hit time by the time layer (floor(16×0.82×0.94⁴)=10)")


# --- A 起手：命中反馈但弹地后只能收尾 ---

func _a_route_plan(b_press_frame: int, facing := 1) -> Dictionary:
	var plan := {
		1: _press("A"), 9: _press("B"), 24: _press("C"),
		38: _press("A", false, facing), 39: _axis(facing),
		56: _jump(),
		68: _press("B"),
		78: _air214(0, facing), 79: _air214(1, facing), 80: _air214(2, facing), 81: _air214(3, facing),
	}
	if b_press_frame > 0:
		plan[b_press_frame] = _press("B")
	return plan


func _test_a_starter_bounce_ender(facing: int) -> void:
	var run := _run_plan(_a_route_plan(110, facing), facing, 160)
	var moves := _hit_moves(run)
	_check(moves == ["5A", "5B", "5C", "6A", "jB", "j214D", "5B"],
		"A-starter route lands the juggle into j214D and the post-bounce 5B as hit 7 (%s) | facing %+d" % [str(moves), facing])
	var j214d_followup := -1
	var last_followup := -1
	for hit in run["hits"]:
		if hit["move"] == "j214D":
			j214d_followup = int(hit["bounce_followup"])
		if hit["hits"] == 7:
			last_followup = int(hit["bounce_followup"])
	_check(j214d_followup == 0 and last_followup == 0,
		"A starter derives bounce_followup = 0 and the post-bounce hit lands with no qualification | facing %+d" % facing)
	var bounce_end := false
	for end in run["ends"]:
		if end.get("reason", -1) == CombatEvent.ComboEndReason.BOUNCE_END:
			bounce_end = true
	_check(bounce_end, "the A-starter post-bounce hit ends the route immediately (BOUNCE_END) | facing %+d" % facing)
	var session: CombatSession = run["session"]
	_check(not session.combo_active and session.combo_starter_grade == MoveData.StarterGrade.UNSET,
		"combo state is cleared after the bounce end (starter UNSET) | facing %+d" % facing)


func _test_a_starter_no_continuation() -> void:
	## BOUNCE_END 之后的新输入按独立招式处理：不能延续旧连段（不存在第 8 击）。
	var plan := _a_route_plan(110, 1)
	plan[156] = _press("C")
	var run := _run_plan(plan, 1, 190)
	var moves := _hit_moves(run)
	var eighth := moves.size() >= 8 and moves[7] == "5C"
	var ninth_hit_index := -1
	for hit in run["hits"]:
		if not bool(hit.get("miss", false)) and hit["move"] == "5C":
			ninth_hit_index = int(hit["hits"])
	_check(moves.size() == 8 and eighth and ninth_hit_index == 1,
		"after BOUNCE_END the next 5C hit registers as hit 1 of a new combo, never a continuation (%s)" % str(moves))


func _test_a_starter_expired_input_boundary() -> void:
	## 「允许取消但来不及命中」前置边界：过早按下在触地开窗前过期，目押失败可观察。
	var run := _run_plan(_a_route_plan(99, 1), 1, 160)
	var moves := _hit_moves(run)
	var link_fail_seen := false
	for end in run["ends"]:
		if end.has("link_fail"):
			link_fail_seen = true
	_check(moves == ["5A", "5B", "5C", "6A", "jB", "j214D"] and not link_fail_seen,
		"an input pressed too early expires before the bounce window opens: no followup starts and no hit is fabricated (%s)" % str(moves))
	var ended_by_recovery := false
	for end in run["ends"]:
		if end.get("reason", -1) == CombatEvent.ComboEndReason.MOVE_RECOVERED:
			ended_by_recovery = true
	_check(ended_by_recovery and run["bounce_contacts"].size() == 1,
		"the route ends by move-recovered while the single bounce still runs its course")


# --- B 起手：条件延长（6A 追击 + jump cancel 空中链）---

func _b6_route_plan(facing: int) -> Dictionary:
	return {
		1: _press("B"), 16: _press("C"),
		30: _press("A", false, facing), 31: _axis(facing),
		48: _jump(),
		60: _press("B"), 68: _press("C"),
		70: _air214(0, facing), 71: _air214(1, facing), 72: _air214(2, facing), 73: _air214(3, facing),
		103: _press("A", false, facing),
		124: _jump(),
		132: _press("A"),
	}


func _test_b_starter_full_extension(facing: int) -> void:
	var run := _run_plan(_b6_route_plan(facing), facing, 190)
	var moves := _hit_moves(run)
	_check(moves == ["5B", "5C", "6A", "jB", "j214D", "6A", "jA"],
		"B-starter extension lands the bounce followup 6A and jump-cancel jA (7 hits) %s | facing %+d" % [str(moves), facing])
	var grades := []
	for hit in run["hits"]:
		grades.append(int(hit["starter"]))
	var starter_locked := grades.all(func(g: int): return g == MoveData.StarterGrade.B)
	_check(starter_locked, "starter grade B stays locked across float, bounce and landing continuation | facing %+d" % facing)
	## 分层倍率逐击核对：B(0.84/0.82/0.85) × 普通⁴ × 弹地(6A) × 普通。
	var expected_damage := 0.84 * 0.9 * 0.9 * 0.9 * 0.9 * 0.88 * 0.9
	var expected_time := 0.82 * 0.94 * 0.94 * 0.94 * 0.94 * 0.92 * 0.94
	var expected_trajectory := 0.85 * 0.95 * 0.95 * 0.95 * 0.95 * 0.93 * 0.95
	var last: Dictionary = run["hits"][run["hits"].size() - 1]
	_check(is_equal_approx(float(last["damage_scale"]), expected_damage)
		and is_equal_approx(float(last["time_scale"]), expected_time)
		and is_equal_approx(float(last["trajectory_scale"]), expected_trajectory),
		"the three layers accumulate per-tier (normal ×4, bounce followup, normal) without resets | facing %+d" % facing)
	_check(run["bounce_contacts"].size() == 1, "one bounce contact across the extended route | facing %+d" % facing)


func _test_b_starter_followup_not_refreshed() -> void:
	## 反例：资格不随命中刷新——B6 延长后任何后续命中都不再产生追击资格。
	var run := _run_plan(_b6_route_plan(1), 1, 190)
	var session: CombatSession = run["session"]
	var after_followup := false
	var refreshed := false
	for hit in run["hits"]:
		if hit["move"] == "6A" and hit["hits"] == 6:
			after_followup = true
		if after_followup and int(hit["bounce_followup"]) > 0:
			refreshed = true
	_check(after_followup and not refreshed, "subsequent hits never refresh the consumed bounce_followup")
	_check(session.combo_bounce_followup == 0 or not session.combo_active,
		"no live combo carries a bounce_followup after consumption")


# --- 弹地不是 OTG ---

func _test_bounce_is_not_otg() -> void:
	## 弹地窗口内独立起手的 5A 不能命中弹地目标（无资料门 + 连段资格门）。
	var plan := _b_route_plan(1)
	plan.erase(103)
	plan[110] = _press("A")
	var run := _run_plan(plan, 1, 170)
	var session: CombatSession = run["session"]
	var knockdown := false
	var calib := _spawn(NEAR_DX, 1)
	var hp_before_5a := 100.0
	for frame in range(1, 170):
		var input: FrameInput = plan[frame] if plan.has(frame) else FrameInput.new()
		for _event in calib.step(input):
			if calib.dummy_state == CombatSession.DummyState.KNOCKED_DOWN:
				knockdown = true
		if frame == 110:
			hp_before_5a = calib.dummy_hp
	var hp_unchanged := is_equal_approx(calib.dummy_hp, hp_before_5a)
	_check(hp_unchanged and not knockdown,
		"an independent 5A never damages the bouncing dummy and the flow never becomes knockdown (no OTG)")
	_check(run["bounce_contacts"].size() == 1 and session.dummy_state != CombatSession.DummyState.KNOCKED_DOWN,
		"the bounce flow keeps exactly one contact and no knockdown conversion")


# --- 被防/挥空不锁定起手 ---

func _test_blocked_and_miss_do_not_lock_starter() -> void:
	## 挥空：木桩在射程外挥 5A，随后 5B 首击锁定 B。
	var whiff := _spawn(300.0, 1)
	whiff.step(_press("A"))
	for frame in range(2, 26):
		whiff.step(FrameInput.new())
	var starter_after_whiff := whiff.combo_starter_grade
	whiff.dummy_position = whiff.player_position + Vector2(NEAR_DX, 0)
	for frame in range(26, 45):
		var input := _press("B") if frame == 26 else FrameInput.new()
		whiff.step(input)
	_check(starter_after_whiff == MoveData.StarterGrade.UNSET
		and whiff.combo_starter_grade == MoveData.StarterGrade.B,
		"a whiffed 5A locks nothing; the next valid 5B hit locks starter B")
	## 被防：站防挡下 5A，随后 5B 首击仍锁定 B（被防不锁定）。
	var blocked := _spawn(NEAR_DX, 1)
	var blocked_seen := false
	for frame in range(1, 40):
		var input := FrameInput.new()
		if frame == 1:
			input = _press("A")
		elif frame == 29:
			input = _press("B")
		if frame <= 13:
			input.dummy_guard_request = CombatSession.GuardPosture.STANDING
		for event in blocked.step(input):
			if event.type == CombatEvent.Type.ATTACK_BLOCKED:
				blocked_seen = true
	_check(blocked_seen and blocked.combo_starter_grade == MoveData.StarterGrade.B,
		"a blocked 5A does not lock the starter; the follow-up 5B hit locks B")


# --- 落地普通连接分层倍率（票据 09 落表）---

func _test_landing_link_tier() -> void:
	## 2C>6D>j6D>5B（票据 08 R2 输入编排）：5B 经空技延迟普通连接起手，
	## 其命中使用落地连接分层（0.94/0.95/0.95），不是普通命中（0.90/0.94/0.95）。
	var plan := {
		1: _press("C", true), 17: _press("D", false, 1), 35: _press("D", false, 1),
		57: _press("B"),
	}
	var run := _run_plan(plan, 1, 110)
	var moves := _hit_moves(run)
	_check(moves == ["2C", "6D", "j6D", "5B"], "the landing-link route replays 2C>6D>j6D>5B (%s)" % str(moves))
	var last: Dictionary = run["hits"][run["hits"].size() - 1]
	var expected_damage := 0.93 * 0.9 * 0.9 * 0.94
	var expected_time := 0.90 * 0.94 * 0.94 * 0.95
	var expected_trajectory := 0.92 * 0.95 * 0.95 * 0.95
	_check(is_equal_approx(float(last["damage_scale"]), expected_damage)
		and is_equal_approx(float(last["time_scale"]), expected_time)
		and is_equal_approx(float(last["trajectory_scale"]), expected_trajectory),
		"the link-started 5B hit applies the landing-link per-hit tier (0.94/0.95/0.95)")


# --- slide / Rekka 跨状态保持 starter ---

func _test_slide_and_rekka_preserve_starter() -> void:
	## slide 跨越（票据 05 R2 编排 @93px）：236C 段1挥空>段2 slide>5D 捞起，
	## D 起手等级与三层在 slide 命中前后不重置。
	var slide := _spawn(93.0, 1)
	var slide_plan := {
		1: _down(), 2: _down_fwd(1), 3: _fwd(1), 4: _fwd_c(1),
		40: _press("D"),
	}
	var slide_hit_moves: Array[String] = []
	var starter_values := []
	for frame in range(1, 110):
		var input: FrameInput = slide_plan[frame] if slide_plan.has(frame) else FrameInput.new()
		var move_at_start := slide.player_move_id
		for event in slide.step(input):
			if event.type == CombatEvent.Type.HIT:
				slide_hit_moves.append(move_at_start)
				starter_values.append(slide.combo_starter_grade)
	_check(slide_hit_moves == ["236C", "236C", "5D"],
		"slide route replays 236C(whiff seg1)>seg2>5D pickup (%s)" % str(slide_hit_moves))
	_check(starter_values.all(func(g): return g == MoveData.StarterGrade.D),
		"starter D stays locked across the slide state transition")
	## Rekka 跨越（票据 04 编排）：2C>214C>~B(airborne 延长)>5B 目押，B 起手保持。
	var rekka := _spawn(44.0, 1)
	var rekka_plan := {
		1: _press("C", true),
		9: _cmd214(0, 1), 10: _cmd214(1, 1), 11: _cmd214(2, 1), 12: _cmd214(3, 1),
		32: _press("B"),
		70: _press("B"),
	}
	var rekka_hit_moves: Array[String] = []
	var rekka_starters := []
	for frame in range(1, 110):
		var input: FrameInput = rekka_plan[frame] if rekka_plan.has(frame) else FrameInput.new()
		var move_at_start := rekka.player_move_id
		for event in rekka.step(input):
			if event.type == CombatEvent.Type.HIT:
				rekka_hit_moves.append(move_at_start)
				rekka_starters.append(rekka.combo_starter_grade)
	_check(rekka_hit_moves == ["2C", "214C", "214C~B", "5B"],
		"rekka route replays 2C>214C>~B(airborne)>5B (%s)" % str(rekka_hit_moves))
	_check(rekka_starters.all(func(g): return g == MoveData.StarterGrade.C),
		"starter C (2C opener) stays locked through the Rekka derivation and the delayed link")


## 地面 214 指令逐帧输入（相对面向，动作键 C）：step 0=下、1=下后、2+=后，step 3 按 C。
func _cmd214(step: int, facing: int) -> FrameInput:
	var input := FrameInput.new()
	match step:
		0:
			input.down_held = true
		1:
			input.down_held = true
			input.move_axis = -facing
		_:
			input.move_axis = -facing
	if step == 3:
		input.pressed_action_keys = ["C"]
		input.held_action_keys = ["C"]
	return input


func _down() -> FrameInput:
	var input := FrameInput.new()
	input.down_held = true
	return input


func _down_fwd(facing: int) -> FrameInput:
	var input := FrameInput.new()
	input.down_held = true
	input.move_axis = facing
	return input


func _fwd(facing: int) -> FrameInput:
	var input := FrameInput.new()
	input.move_axis = facing
	return input


func _fwd_c(facing: int) -> FrameInput:
	var input := _fwd(facing)
	input.pressed_action_keys = ["C"]
	input.held_action_keys = ["C"]
	return input


# --- 236C > 5D 循环负例（A 起手）---

func _test_236c_5d_loop_breaks_for_a_starter() -> void:
	## A 起手 5A>236C>5D(特殊进入)>5B：目押在 A 起手时间层下不可达，
	## 路线断链（票据 05 结论在本票复验——不形成被禁止的 slide loop）。
	var plan := {
		1: _press("A"),
		3: _down(), 4: _down_fwd(1), 5: _fwd(1), 6: _fwd_c(1),
		34: _press("D"),
		68: _press("B"),
	}
	var run := _run_plan(plan, 1, 150, 70.0)
	var moves := _hit_moves(run)
	var combo_hits_seen := []
	for hit in run["hits"]:
		combo_hits_seen.append(int(hit["hits"]))
	_check(moves.slice(0, 4) == ["5A", "236C", "236C", "5D"] and combo_hits_seen.slice(0, 4) == [1, 2, 3, 4],
		"the A-starter loop candidate reaches 5A>236C(2 hits)>5D inside one combo (%s / %s)" % [str(moves), str(combo_hits_seen)])
	var combo_broken := false
	var b_hit_index := -1
	for hit in run["hits"]:
		if hit["move"] == "5B":
			b_hit_index = int(hit["hits"])
	for end in run["ends"]:
		if end.get("reason", -1) == CombatEvent.ComboEndReason.DUMMY_RECOVERED:
			combo_broken = true
		if end.has("link_fail") and end.get("link_move", "") == "5B":
			combo_broken = true
	_check(combo_broken and (b_hit_index == -1 or b_hit_index == 1),
		"the dummy recovers before any 5B can land in-combo: the route breaks under the A-starter time layer (no 236C>5D loop)")


# --- Solver 状态键承载弹地字段 ---

func _test_settlement_keys_carry_bounce_state() -> void:
	var plan := _b_route_plan(1)
	var session := _spawn(NEAR_DX, 1)
	var keys_at_entry := {}
	var keys_at_contact := {}
	var keys_after_followup := {}
	for frame in range(1, 130):
		var input: FrameInput = plan[frame] if plan.has(frame) else FrameInput.new()
		for _event in session.step(input):
			pass
		var state := session.settlement_state()
		if session.dummy_state == CombatSession.DummyState.GROUND_BOUNCE and not session.dummy_bounce_contacted:
			keys_at_entry = state
		if session.dummy_bounce_contacted and session.combo_bounce_followup == 1:
			keys_at_contact = state
		if session.combo_bounce_followup == 0 and session.combo_active:
			keys_after_followup = state
	_check(not keys_at_entry.is_empty() and keys_at_entry.has("dummy_bounce_contacted")
		and keys_at_entry.has("dummy_bounce_left") and keys_at_entry.has("bounce_followup")
		and keys_at_entry.has("starter_grade") and keys_at_entry.has("damage_scale"),
		"settlement_state carries the bounce/contact/followup/starter/correction keys for solver dedup")
	_check(not keys_at_contact.is_empty() and not keys_after_followup.is_empty()
		and keys_at_contact.get("bounce_followup") == 1
		and keys_after_followup.get("bounce_followup") == 0,
		"the followup consumption changes the settlement key (states before/after dedup apart)")
	_check(keys_at_entry.get("dummy_bounce_contacted") == false
		and keys_at_contact.get("dummy_bounce_contacted") == true,
		"the contact event flips a settlement key (pre-touch and post-touch are distinct states)")
