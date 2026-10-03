extends SceneTree
## 上下文命中资料垂直切片验收（.scratch/ftg-move-design spec §2–§7 / issue 01）：
## HitProfile 类型与默认值、MoveTable 组合校验、(target_state, hit_context)
## 精确匹配无回退、三种 reaction 的运行时状态/计时/速度/结束事件、Counter Hit
## 生命周期（startup/recovery 触发、active 排除、挥空结束、命中消耗）、5A/6A/214D
## 三组验收样例、以及共享表 profile 数据在 CombatSession 与 Combo Solver 两端
## 产生一致变化的同步性。既有 Hitstop/落地恢复/自然受身回归由既有测试套件承载。
## 运行：godot --headless --path . -s res://tests/test_hit_profiles.gd

const AcceptanceSolverMetrics = preload("res://tests/acceptance_solver_metrics.gd")
var _metrics := AcceptanceSolverMetrics.new()
var _failures := 0


func _initialize() -> void:
	_test_profile_defaults_and_enum_members()
	_test_shared_table_samples_declared()
	_test_profile_copies_are_isolated()
	_test_legal_reactions_validate()
	_test_illegal_profile_combinations_reject()
	_test_exact_match_has_no_fallback()
	_test_sample_5a_ground_normal()
	_test_missing_profile_miss_has_no_side_effects()
	_test_sample_6a_launch_entry_and_jump_cancel_boundary()
	_test_sample_214d_knockdown_lifecycle()
	_test_counter_hit_lifecycle()
	_test_counter_damage_override()
	_test_player_side_uses_profile_selection()
	_test_profile_edits_sync_session_and_solver()
	_test_missing_profile_reports_consistently_in_solver()
	print("")
	_metrics.emit("test_hit_profiles")
	if _failures == 0:
		print("ALL HIT PROFILE TESTS PASSED")
		quit(0)
	else:
		print(str(_failures) + " TEST(S) FAILED")
		quit(1)


# --- 类型与共享表数据 ---

func _test_profile_defaults_and_enum_members() -> void:
	var profile := HitProfile.new()
	_check(profile.target_state == HitProfile.TargetState.UNSET
		and profile.hit_context == HitProfile.HitContext.UNSET
		and profile.reaction == HitProfile.Reaction.UNSET,
		"fresh profile enums default to UNSET sentinels")
	_check(profile.damage_override == -1 and profile.ground_stun_frames == -1
		and profile.air_untech_frames == -1 and profile.knockdown_frames == -1,
		"timer/damage defaults are the undeclared sentinel -1, never 0")
	_check(profile.horizontal_speed_px_s == -1.0 and profile.upward_speed_px_s == -1.0,
		"speed defaults are the undeclared sentinel -1.0")
	_check(HitProfile.TargetState.GROUNDED == 1 and HitProfile.TargetState.AIRBORNE == 2,
		"TargetState members are UNSET=0, GROUNDED=1, AIRBORNE=2")
	_check(HitProfile.HitContext.NORMAL == 1 and HitProfile.HitContext.COUNTER == 2,
		"HitContext members are UNSET=0, NORMAL=1, COUNTER=2")
	_check(HitProfile.Reaction.GROUND_HITSTUN == 1 and HitProfile.Reaction.LAUNCH == 2
		and HitProfile.Reaction.GROUND_KNOCKDOWN == 3,
		"Reaction members are UNSET=0, GROUND_HITSTUN=1, LAUNCH=2, GROUND_KNOCKDOWN=3")
	var stun := _profile(HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL,
		HitProfile.Reaction.GROUND_HITSTUN, {"ground_stun_frames": 12})
	var launch := _profile(HitProfile.TargetState.AIRBORNE, HitProfile.HitContext.NORMAL,
		HitProfile.Reaction.LAUNCH, {"air_untech_frames": 20})
	var down := _profile(HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL,
		HitProfile.Reaction.GROUND_KNOCKDOWN, {"knockdown_frames": 30})
	_check(stun.reaction_timer_frames() == 12 and launch.reaction_timer_frames() == 20
		and down.reaction_timer_frames() == 30,
		"reaction_timer_frames reads the timer matching the declared reaction")


func _test_shared_table_samples_declared() -> void:
	var table := MoveData.default_table()
	_check(not table.is_empty(), "shared manifest loads the migrated profile table")
	if table.is_empty():
		return
	var five_a := table["5A"] as MoveData
	var normal := MoveData.profile_for(five_a, HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL)
	var counter := MoveData.profile_for(five_a, HitProfile.TargetState.GROUNDED, HitProfile.HitContext.COUNTER)
	_check(normal != null and normal.reaction == HitProfile.Reaction.GROUND_HITSTUN
		and normal.ground_stun_frames == 14 and is_equal_approx(normal.upward_speed_px_s, 0.0),
		"5A grounded normal is GROUND_HITSTUN with declared timers and explicit 0 upward speed")
	_check(counter != null and counter.reaction == HitProfile.Reaction.GROUND_HITSTUN
		and counter.ground_stun_frames != normal.ground_stun_frames,
		"5A grounded counter is a legal variant observable from normal")
	_check(MoveData.profile_for(five_a, HitProfile.TargetState.AIRBORNE, HitProfile.HitContext.NORMAL) == null,
		"5A declares no airborne profile (airborne hits must miss, not borrow grounded data)")
	var six_a := table["6A"] as MoveData
	var six_normal := MoveData.profile_for(six_a, HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL)
	var six_counter := MoveData.profile_for(six_a, HitProfile.TargetState.GROUNDED, HitProfile.HitContext.COUNTER)
	_check(six_a.direction_derivation == "6A" and six_a.stance == MoveData.Stance.GROUND,
		"6A is the 6+A forward special listed in the shared manifest")
	_check(six_normal != null and six_normal.reaction == HitProfile.Reaction.LAUNCH
		and six_normal.upward_speed_px_s > 0.0,
		"6A grounded normal is LAUNCH with positive upward speed")
	_check(six_counter != null and six_counter.reaction == HitProfile.Reaction.LAUNCH
		and six_counter.air_untech_frames != six_normal.air_untech_frames,
		"6A grounded counter is a LAUNCH variant observable from normal")
	_check(MoveData.profile_for(six_a, HitProfile.TargetState.AIRBORNE, HitProfile.HitContext.NORMAL) == null,
		"6A leaves the airborne profile undeclared (unmatched when targeted airborne)")
	_check(six_a.jump_cancel_targets == ["jA", "jB", "jC"], "6A declares its jump cancel targets into the delivered air normals (ticket 07)")
	_check((table["5A"] as MoveData).chain_cancel_targets.has("5B"), "5A chains into 5B (ground chain confirm)")
	var d := table["214D"] as MoveData
	var d_normal := MoveData.profile_for(d, HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL)
	var d_counter := MoveData.profile_for(d, HitProfile.TargetState.GROUNDED, HitProfile.HitContext.COUNTER)
	_check(d_normal != null and d_normal.reaction == HitProfile.Reaction.GROUND_KNOCKDOWN
		and d_normal.knockdown_frames >= 1 and is_equal_approx(d_normal.upward_speed_px_s, 0.0),
		"214D grounded normal is GROUND_KNOCKDOWN with an independent timer and 0 upward speed")
	_check(d_counter != null and d_counter.reaction == HitProfile.Reaction.GROUND_KNOCKDOWN
		and d_counter.knockdown_frames != d_normal.knockdown_frames,
		"214D grounded counter is a GROUND_KNOCKDOWN variant")
	for move_id in ["5B", "5D", "5C", "236C"]:
		var move := table[move_id] as MoveData
		_check(MoveData.profile_for(move, HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL) != null,
			"%s keeps an explicitly migrated grounded normal profile" % move_id)
	for move_id in ["jA", "jB", "j5D"]:
		var move := table[move_id] as MoveData
		_check(MoveData.profile_for(move, HitProfile.TargetState.AIRBORNE, HitProfile.HitContext.NORMAL) != null,
			"%s declares an airborne normal profile for air pursuit routes" % move_id)
	_check((table["BC"] as MoveData).hit_profiles.is_empty(), "the throw declares no hit profiles")


func _test_profile_copies_are_isolated() -> void:
	var first := MoveTable.load_default()
	var second := MoveTable.load_default()
	var profile := MoveData.profile_for(first.moves["5A"] as MoveData,
		HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL)
	profile.ground_stun_frames = 99
	var again := MoveData.profile_for(second.moves["5A"] as MoveData,
		HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL)
	_check(again.ground_stun_frames == 14, "mutating one table copy's profile does not leak into other loads")


# --- MoveTable 组合校验（spec §3）---

func _test_legal_reactions_validate() -> void:
	_check(MoveTable.validate([_strike_with([
		_profile(HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL, HitProfile.Reaction.GROUND_HITSTUN,
			{"ground_stun_frames": 12, "horizontal_speed_px_s": 100.0, "upward_speed_px_s": 0.0}),
	])]).is_empty(), "GROUND_HITSTUN on grounded target with declared timers validates")
	_check(MoveTable.validate([_strike_with([
		_profile(HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL, HitProfile.Reaction.LAUNCH,
			{"air_untech_frames": 20, "horizontal_speed_px_s": 100.0, "upward_speed_px_s": 400.0}),
	])]).is_empty(), "LAUNCH on grounded target validates")
	_check(MoveTable.validate([_strike_with([
		_profile(HitProfile.TargetState.AIRBORNE, HitProfile.HitContext.NORMAL, HitProfile.Reaction.LAUNCH,
			{"air_untech_frames": 20, "horizontal_speed_px_s": 100.0, "upward_speed_px_s": 100.0}),
	])]).is_empty(), "LAUNCH on airborne target validates")
	_check(MoveTable.validate([_strike_with([
		_profile(HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL, HitProfile.Reaction.GROUND_KNOCKDOWN,
			{"knockdown_frames": 30, "horizontal_speed_px_s": 100.0, "upward_speed_px_s": 0.0}),
	])]).is_empty(), "GROUND_KNOCKDOWN on grounded target validates")
	_check(MoveTable.validate([_strike_with([
		_profile(HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL, HitProfile.Reaction.GROUND_HITSTUN,
			{"ground_stun_frames": 12, "horizontal_speed_px_s": 100.0, "upward_speed_px_s": 0.0}),
		_profile(HitProfile.TargetState.GROUNDED, HitProfile.HitContext.COUNTER, HitProfile.Reaction.GROUND_HITSTUN,
			{"ground_stun_frames": 18, "horizontal_speed_px_s": 100.0, "upward_speed_px_s": 0.0}),
		_profile(HitProfile.TargetState.AIRBORNE, HitProfile.HitContext.NORMAL, HitProfile.Reaction.LAUNCH,
			{"air_untech_frames": 20, "horizontal_speed_px_s": 100.0, "upward_speed_px_s": 100.0}),
	])]).is_empty(), "grounded normal/counter plus airborne normal validates together")


func _test_illegal_profile_combinations_reject() -> void:
	var cases := [
		["GROUND_HITSTUN 打空中目标", [
			_profile(HitProfile.TargetState.AIRBORNE, HitProfile.HitContext.NORMAL, HitProfile.Reaction.GROUND_HITSTUN,
				{"ground_stun_frames": 12, "upward_speed_px_s": 0.0}),
		], "grounded"],
		["GROUND_KNOCKDOWN 打空中目标", [
			_profile(HitProfile.TargetState.AIRBORNE, HitProfile.HitContext.NORMAL, HitProfile.Reaction.GROUND_KNOCKDOWN,
				{"knockdown_frames": 30, "upward_speed_px_s": 0.0}),
		], "grounded"],
		["GROUND_HITSTUN 缺硬直计时", [
			_profile(HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL, HitProfile.Reaction.GROUND_HITSTUN,
				{"upward_speed_px_s": 0.0}),
		], "ground_stun_frames"],
		["LAUNCH 缺空中受身计时", [
			_profile(HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL, HitProfile.Reaction.LAUNCH,
				{"upward_speed_px_s": 400.0}),
		], "air_untech_frames"],
		["LAUNCH 垂直速度为 0", [
			_profile(HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL, HitProfile.Reaction.LAUNCH,
				{"air_untech_frames": 20, "upward_speed_px_s": 0.0}),
		], "upward_speed_px_s"],
		["GROUND_HITSTUN 保留旧击飞速度", [
			_profile(HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL, HitProfile.Reaction.GROUND_HITSTUN,
				{"ground_stun_frames": 12, "upward_speed_px_s": 110.0}),
		], "upward_speed_px_s"],
		["GROUND_KNOCKDOWN 垂直速度非 0", [
			_profile(HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL, HitProfile.Reaction.GROUND_KNOCKDOWN,
				{"knockdown_frames": 30, "upward_speed_px_s": 90.0}),
		], "upward_speed_px_s"],
		["LAUNCH 声明地面硬直计时", [
			_profile(HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL, HitProfile.Reaction.LAUNCH,
				{"air_untech_frames": 20, "ground_stun_frames": 12, "upward_speed_px_s": 400.0}),
		], "ground_stun_frames"],
		["GROUND_HITSTUN 声明倒地计时", [
			_profile(HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL, HitProfile.Reaction.GROUND_HITSTUN,
				{"ground_stun_frames": 12, "knockdown_frames": 30, "upward_speed_px_s": 0.0}),
		], "knockdown_frames"],
		["GROUND_KNOCKDOWN 声明空中受身计时", [
			_profile(HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL, HitProfile.Reaction.GROUND_KNOCKDOWN,
				{"knockdown_frames": 30, "air_untech_frames": 20, "upward_speed_px_s": 0.0}),
		], "air_untech_frames"],
		["水平速度未声明", [
			_profile(HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL, HitProfile.Reaction.GROUND_HITSTUN,
				{"ground_stun_frames": 12, "upward_speed_px_s": 0.0}),
		], "horizontal_speed_px_s"],
		["水平速度为负", [
			_profile(HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL, HitProfile.Reaction.GROUND_HITSTUN,
				{"ground_stun_frames": 12, "horizontal_speed_px_s": -40.0, "upward_speed_px_s": 0.0}),
		], "horizontal_speed_px_s"],
		["覆盖伤害为负", [
			_profile(HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL, HitProfile.Reaction.GROUND_HITSTUN,
				{"damage_override": -2, "ground_stun_frames": 12, "upward_speed_px_s": 0.0}),
		], "damage_override"],
		["未知 target_state 枚举", [
			_profile(HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL, HitProfile.Reaction.GROUND_HITSTUN,
				{"target_state": 5, "ground_stun_frames": 12, "upward_speed_px_s": 0.0}),
		], "target_state"],
		["未知 hit_context 枚举", [
			_profile(HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL, HitProfile.Reaction.GROUND_HITSTUN,
				{"hit_context": 7, "ground_stun_frames": 12, "upward_speed_px_s": 0.0}),
		], "hit_context"],
		["未知 reaction 枚举", [
			_profile(HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL, HitProfile.Reaction.GROUND_HITSTUN,
				{"reaction": 9, "ground_stun_frames": 12, "upward_speed_px_s": 0.0}),
		], "reaction"],
		["重复 (grounded, normal) 键", [
			_profile(HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL, HitProfile.Reaction.GROUND_HITSTUN,
				{"ground_stun_frames": 12, "horizontal_speed_px_s": 100.0, "upward_speed_px_s": 0.0}),
			_profile(HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL, HitProfile.Reaction.GROUND_HITSTUN,
				{"ground_stun_frames": 14, "horizontal_speed_px_s": 100.0, "upward_speed_px_s": 0.0}),
		], "重复键"],
		["counter 无同状态 normal", [
			_profile(HitProfile.TargetState.GROUNDED, HitProfile.HitContext.COUNTER, HitProfile.Reaction.GROUND_HITSTUN,
				{"ground_stun_frames": 18, "horizontal_speed_px_s": 100.0, "upward_speed_px_s": 0.0}),
		], "normal"],
	]
	for entry in cases:
		var label: String = entry[0]
		var profiles: Array = entry[1]
		var needle: String = entry[2]
		var errors := MoveTable.validate([_strike_with(profiles)])
		var named := false
		for error in errors:
			named = named or error.contains(needle)
		_check(not errors.is_empty() and named,
			"illegal profile data rejects the whole table naming %s: %s" % [needle, label])
	_check(not MoveTable.validate([_strike_with([])]).is_empty(),
		"a strike without any profile rejects the whole table")
	var throw := _strike_with([])
	throw.move_kind = MoveData.MoveKind.THROW
	throw.action_key = ""
	throw.throw_range = 64.0
	throw.startup_frames = 5
	throw.active_frames = GameParams.THROW_TECH_WINDOW_AFTER_GRAB + 1
	throw.hit_profiles = [_profile(HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL,
		HitProfile.Reaction.GROUND_HITSTUN, {"ground_stun_frames": 12, "upward_speed_px_s": 0.0})]
	var throw_errors := MoveTable.validate([throw])
	_check(not throw_errors.is_empty() and throw_errors[0].contains("hit_profiles"),
		"a throw declaring hit profiles rejects the whole table")


# --- 精确匹配（spec §4）---

func _test_exact_match_has_no_fallback() -> void:
	var move := _strike_with([
		_profile(HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL, HitProfile.Reaction.GROUND_HITSTUN,
			{"ground_stun_frames": 12, "horizontal_speed_px_s": 100.0, "upward_speed_px_s": 0.0}),
	])
	_check(MoveData.profile_for(move, HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL) != null,
		"exact (grounded, normal) key finds its profile")
	_check(MoveData.profile_for(move, HitProfile.TargetState.AIRBORNE, HitProfile.HitContext.NORMAL) == null,
		"airborne lookup does not borrow the grounded profile")
	_check(MoveData.profile_for(move, HitProfile.TargetState.GROUNDED, HitProfile.HitContext.COUNTER) == null,
		"counter lookup does not fall back to the normal profile")
	_check(MoveData.profile_for(move, HitProfile.TargetState.AIRBORNE, HitProfile.HitContext.COUNTER) == null,
		"neither dimension may fall back in combination")
	var reversed := _strike_with([
		_profile(HitProfile.TargetState.GROUNDED, HitProfile.HitContext.COUNTER, HitProfile.Reaction.GROUND_HITSTUN,
			{"ground_stun_frames": 18, "horizontal_speed_px_s": 100.0, "upward_speed_px_s": 0.0}),
		_profile(HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL, HitProfile.Reaction.GROUND_HITSTUN,
			{"ground_stun_frames": 12, "horizontal_speed_px_s": 100.0, "upward_speed_px_s": 0.0}),
	])
	var picked := MoveData.profile_for(reversed, HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL)
	_check(picked != null and picked.ground_stun_frames == 12,
		"selection is by key, not by array order (normal still wins when listed last)")


# --- 运行时样例 ---

## 首次命中时刻的可观察快照（受击状态在命中帧当帧读取，避免计时衰减；后续
## 命中不覆盖——样例断言的是本次结算选择的那一击）。
func _capture_hit(session: CombatSession, events: Array[CombatEvent], capture: Dictionary, frame: int) -> void:
	for event in events:
		if event.type == CombatEvent.Type.HIT and not capture.has("event"):
			capture["frame"] = frame
			capture["event"] = event
			capture["state"] = session.dummy_state
			capture["on_ground"] = session.dummy_on_ground
			capture["stun"] = session.dummy_hitstun_left
			capture["knockdown"] = session.dummy_knockdown_left
			capture["velocity"] = session.dummy_velocity
			capture["hp"] = session.dummy_hp
		elif event.type == CombatEvent.Type.HIT_MISS:
			capture["miss_frame"] = frame


func _test_sample_5a_ground_normal() -> void:
	# 样例 A.1/A.4：地面普通命中保持接地；同招打空中目标由 miss 测试覆盖。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var capture := {}
	for frame in range(1, 30):
		var events := session.step(_relative_input(session, 5, "A" if frame == 1 else ""))
		_capture_hit(session, events, capture, frame)
	_check(int(capture.get("frame", -1)) == 6, "5A connects on its first active frame (F6)")
	var hit_event: CombatEvent = capture.get("event")
	_check(hit_event != null and not hit_event.is_counter and is_equal_approx(hit_event.damage, 5.8),
		"the grounded normal hit deals the A-starter scaled damage (round0.1(8×0.72)) and reports the normal context")
	_check(capture.get("state") == CombatSession.DummyState.GROUND_HITSTUN and bool(capture.get("on_ground")),
		"the normal ground hit keeps the dummy grounded in ground hitstun")
	_check(int(capture.get("stun", -1)) == 9, "ground stun comes from the selected profile at the A-starter time layer (floor(14×0.70))")
	var velocity: Vector2 = capture.get("velocity", Vector2.INF)
	_check(velocity.x > 100.0 and is_equal_approx(velocity.y, 0.0),
		"knockback speed comes from the profile at the A-starter trajectory layer (120px/s) with no vertical component")
	_check(not capture.has("miss_frame"), "no miss is reported against the grounded dummy")


func _test_missing_profile_miss_has_no_side_effects() -> void:
	# 样例 A.2/B.4（运行时侧）：6A 未声明 airborne profile——注入浮空入口 PL 把
	# 木桩送入浮空后用 6A 追击必须 MISS_NO_PROFILE：不造成伤害、不改状态、
	# 不刷新受身计时、不取得命中确认、不开启停顿。
	var table := MoveData.default_table()
	var launcher := _strike_with([
		_profile(HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL, HitProfile.Reaction.LAUNCH,
			{"air_untech_frames": 40, "horizontal_speed_px_s": 0.0, "upward_speed_px_s": 300.0}),
	])
	launcher.move_id = "PL"
	launcher.action_key = "L"
	launcher.startup_frames = 3
	launcher.active_frames = 3
	launcher.cancel_targets = ["6A"]
	table["PL"] = launcher
	var session := CombatSession.new(table)
	session.dummy_position = session.player_position + Vector2(70, 0)
	var hits := 0
	var miss_frame := -1
	var hp_at_miss := 0.0
	var state_at_miss := CombatSession.DummyState.NEUTRAL
	var untech_before := 0
	var untech_after := 0
	var cancel_open := true
	for frame in range(1, 40):
		var key := ""
		if frame == 1:
			key = "L"
		elif frame == 13:
			key = "A"
		var digit := 6 if frame == 11 else 5
		var events := session.step(_relative_input(session, digit, key))
		for event in events:
			if event.type == CombatEvent.Type.HIT:
				hits += 1
			elif event.type == CombatEvent.Type.HIT_MISS:
				miss_frame = frame
				hp_at_miss = session.dummy_hp
				state_at_miss = session.dummy_state
				untech_after = session.dummy_hitstun_left
				cancel_open = session.debug_snapshot()["cancel_open"]
		if frame == 20:
			untech_before = session.dummy_hitstun_left
	_check(hits == 1, "the injected launcher connects exactly once before the 6A followup")
	_check(miss_frame == 21, "6A connecting with the airborne dummy reports HIT_MISS on its first active frame")
	_check(is_equal_approx(hp_at_miss, GameParams.DUMMY_MAX_HP - 10.0),
		"the miss deals no damage beyond the launcher's own hit")
	_check(state_at_miss == CombatSession.DummyState.AIR_HITSTUN,
		"the miss changes no hit state (still air hitstun at the miss frame)")
	_check(untech_after < untech_before,
		"the miss does not refresh or extend the air untech timer")
	_check(not cancel_open and not session.hitstop_active(),
		"the miss grants no hit confirmation, no cancel window, and no hitstop")


func _test_sample_6a_launch_entry_and_jump_cancel_boundary() -> void:
	# 样例 B：6A 直接起手（6+A）→ 浮空入口；命中确认后 jump cancel 接 jA 追击；
	# 挥空不取得 jump cancel 资格。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var capture := {}
	for frame in range(1, 20):
		var digit := 6 if frame == 1 else 5
		var key := "A" if frame == 2 else ""
		var events := session.step(_relative_input(session, digit, key))
		_capture_hit(session, events, capture, frame)
	_check(int(capture.get("frame", -1)) == 10, "6A connects on its first active frame (F10)")
	var hit_event: CombatEvent = capture.get("event")
	_check(hit_event != null and not hit_event.is_counter and is_equal_approx(hit_event.damage, 14.9),
		"6A's grounded normal connects for the C-starter scaled damage (round0.1(16×0.93)) in the normal context")
	_check(capture.get("state") == CombatSession.DummyState.AIR_HITSTUN,
		"6A puts the grounded dummy into air hitstun")
	_check(int(capture.get("stun", -1)) == 32, "air untech timer comes from the 6A normal profile at the C-starter time layer (floor(36×0.90))")
	var velocity: Vector2 = capture.get("velocity", Vector2.INF)
	_check(velocity.x > 125.0 and velocity.y < -500.0,
		"6A applies the trajectory-scaled horizontal speed (138px/s minus same-frame friction) and a strong upward launch (515px/s)")

	var pursue := CombatSession.new()
	pursue.dummy_position = pursue.player_position + Vector2(70, 0)
	var pursuit_hits := 0
	for frame in range(1, 60):
		var digit := 6 if frame == 1 else 5
		var key := "A" if (frame == 2 or frame == 24) else ""
		var input := _relative_input(pursue, digit, key)
		if frame == 11:
			input.jump_pressed = true
		var events := pursue.step(input)
		for event in events:
			if event.type == CombatEvent.Type.HIT:
				pursuit_hits += 1
	_check(pursuit_hits == 2, "jump cancel after 6A's confirmed hit lets jA connect as a pursuit")

	var whiff := CombatSession.new()
	whiff.dummy_position = whiff.player_position + Vector2(400, 0)
	var whiff_move_running := false
	var whiff_jumped := false
	for frame in range(1, 40):
		var digit := 6 if frame == 1 else 5
		var input := _relative_input(whiff, digit, "A" if frame == 2 else "")
		if frame == 11:
			input.jump_pressed = true
		whiff.step(input)
		if frame == 13:
			whiff_move_running = whiff.player_move_id == "6A"
			whiff_jumped = whiff.player_prejump_left > 0
	_check(whiff_move_running and not whiff_jumped,
		"a whiffed 6A never grants jump cancel (Space stays buffered-only while the move runs)")
	_check(whiff.dummy_hp == GameParams.DUMMY_MAX_HP, "the whiff never touches the dummy")


func _test_sample_214d_knockdown_lifecycle() -> void:
	# 样例 C：214D 直接起手（214+D）。命中 → KNOCKED_DOWN + 连段结束；倒地期间
	# 打击不命中、不刷新；计时结束自然恢复；恢复后的下一次命中开新连段。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var combo_ends: Array[int] = []
	var recovers: Array[int] = []
	var hits: Array[int] = []
	var misses: Array[int] = []
	var at_knockdown := {}
	for frame in range(1, 75):
		var digit := 5
		if frame == 1:
			digit = 2
		elif frame == 2:
			digit = 1
		elif frame == 3:
			digit = 4
		var key := "D" if frame == 4 else ("A" if frame == 52 else "")
		var events := session.step(_relative_input(session, digit, key))
		session.dummy_position.x = session.player_position.x + session.player_facing * 70.0
		_capture_hit(session, events, at_knockdown, frame)
		for event in events:
			match event.type:
				CombatEvent.Type.HIT:
					hits.append(frame)
				CombatEvent.Type.HIT_MISS:
					misses.append(frame)
				CombatEvent.Type.COMBO_ENDED:
					combo_ends.append(event.combo_end_reason)
				CombatEvent.Type.DUMMY_RECOVERED:
					recovers.append(frame)
	_check(hits == [11, 57] and misses.is_empty(),
		"the knockdown hit connects once and the post-recovery 5A starts a fresh combo hit")
	_check(at_knockdown.get("state") == CombatSession.DummyState.KNOCKED_DOWN
		and int(at_knockdown.get("knockdown", -1)) == 28,
		"214D's hit puts the dummy into independent knockdown for the D-starter time-scaled 28 frames (floor(30×0.96))")
	_check(int(at_knockdown.get("stun", -1)) == 0, "knockdown is not disguised as ground hitstun")
	_check(is_equal_approx(at_knockdown.get("hp", 0.0), GameParams.DUMMY_MAX_HP - 22.0),
		"the knockdown hit deals its base damage once")
	_check(not combo_ends.is_empty() and combo_ends[0] == CombatEvent.ComboEndReason.KNOCKDOWN,
		"entering knockdown ends the combo first with the KNOCKDOWN reason")
	_check(recovers == [47, 74], "the knockdown timer expires naturally at F47 (8 hitstop + 28 scaled frames); the fresh 5A stun recovers at F74")
	_check(session.combo_hits == 1,
		"the post-recovery hit opened a fresh combo (count restarted at 1)")

	# Counter 窗口内的 214D 只改本次结果（倒地 40 帧），不改不可追击规则。
	var counter_session := CombatSession.new(_counter_probe_table())
	counter_session.dummy_position = counter_session.player_position + Vector2(70, 0)
	var counter_capture := {}
	for frame in range(1, 16):
		var digit := 5
		if frame == 1:
			digit = 2
		elif frame == 2:
			digit = 1
		elif frame == 3:
			digit = 4
		var key := "D" if frame == 4 else ""
		var events := counter_session.step(_relative_input(counter_session, digit, key, "D_S" if frame == 3 else ""))
		_capture_hit(counter_session, events, counter_capture, frame)
	var counter_event: CombatEvent = counter_capture.get("event")
	_check(counter_event != null and counter_event.is_counter,
		"214D hitting the dummy's startup selects the counter profile (reported in the event)")
	_check(int(counter_capture.get("knockdown", -1)) == 38,
		"the counter knockdown variant uses its own timer at the D-starter time layer (floor(40×0.96) = 38)")


func _test_counter_hit_lifecycle() -> void:
	# 样例 D：startup/recovery 触发、active 排除、挥空后窗口结束、命中即消耗。
	# D_S：startup 10（F1–F10）、active 2（F11–F12）、recovery 6（F13–F18）。
	# 5A：startup 5、active F(press+5)–F(press+11)、stun 12 / counter 18。
	var run := func(press_frame: int, request: bool) -> Dictionary:
		var session := CombatSession.new(_counter_probe_table())
		session.dummy_position = session.player_position + Vector2(70, 0)
		var capture := {}
		for frame in range(1, 30):
			var request_id := "D_S" if request and frame == 1 else ""
			var events := session.step(_relative_input(session, 5, "A" if frame == press_frame else "", request_id))
			_capture_hit(session, events, capture, frame)
		return capture
	var startup_case: Dictionary = run.call(1, true)
	var startup_event: CombatEvent = startup_case.get("event")
	_check(startup_event != null and startup_event.is_counter,
		"a hit landing in the dummy's startup window selects the counter profile")
	_check(int(startup_case.get("stun", -1)) == 12,
		"the counter hit applies the counter stun at the A-starter time layer (floor(18×0.70) = 12) rather than the normal stun (9)")
	var recovery_case: Dictionary = run.call(8, true)
	var recovery_event: CombatEvent = recovery_case.get("event")
	_check(recovery_event != null and recovery_event.is_counter,
		"a hit landing in the dummy's recovery window selects the counter profile")
	var active_case: Dictionary = run.call(6, true)
	var active_event: CombatEvent = active_case.get("event")
	_check(active_event != null and not active_event.is_counter and int(active_case.get("stun", -1)) == 9,
		"a hit landing while the dummy's move is active stays normal (active is not a counter window)")
	var expired_case: Dictionary = run.call(20, true)
	var expired_event: CombatEvent = expired_case.get("event")
	_check(expired_event != null and not expired_event.is_counter and int(expired_case.get("stun", -1)) == 9,
		"after the whiffed window expires the next hit is normal again")
	var neutral_case: Dictionary = run.call(1, false)
	var neutral_event: CombatEvent = neutral_case.get("event")
	_check(neutral_event != null and not neutral_event.is_counter,
		"a dummy that never attacked is always hit in the normal context")

	# 消耗：counter 命中打断木桩招式，同段内的下一次命中按 normal 选择。
	var session := CombatSession.new(_counter_probe_table())
	session.dummy_position = session.player_position + Vector2(70, 0)
	var contexts: Array[bool] = []
	var stuns: Array[int] = []
	for frame in range(1, 40):
		var request_id := "D_S" if frame == 1 else ""
		var key := ""
		if frame == 1:
			key = "A"
		elif frame == 9:
			key = "B"
		var events := session.step(_relative_input(session, 5, key, request_id))
		for event in events:
			if event.type == CombatEvent.Type.HIT:
				contexts.append(event.is_counter)
				stuns.append(session.dummy_hitstun_left)
	## B 于停顿内按下（F9）、恢复首帧 F15 以链式取消（年龄 1 ≤ 3）起手 5B。
	_check(contexts == [true, false] and stuns == [12, 9],
		"the counter context is consumed on hit: the followup in the same combo selects normal (stun 9 at the second-hit time layer)")


func _test_counter_damage_override() -> void:
	var table := _counter_probe_table()
	var counter := MoveData.profile_for(table["5A"] as MoveData,
		HitProfile.TargetState.GROUNDED, HitProfile.HitContext.COUNTER)
	counter.damage_override = 15
	var session := CombatSession.new(table)
	session.dummy_position = session.player_position + Vector2(70, 0)
	var damage := 0.0
	for frame in range(1, 20):
		var events := session.step(_relative_input(session, 5, "A" if frame == 1 else "", "D_S" if frame == 1 else ""))
		for event in events:
			if event.type == CombatEvent.Type.HIT:
				damage = event.damage
	_check(is_equal_approx(damage, 10.8),
		"damage_override replaces base damage and then takes the A-starter layer (round0.1(15×0.72) = 10.8)")


func _test_player_side_uses_profile_selection() -> void:
	# 木桩攻击玩家走同一选择器：normal/counter 计时来自所选 profile；玩家空中时
	# 无 airborne profile 的打击返回 HIT_MISS，不给硬直。
	var probe := _counter_probe_table()
	var strike := probe["D_G"] as MoveData
	var five_a := probe["5A"] as MoveData
	var session := CombatSession.new({"D_G": strike, "5A": five_a})
	session.dummy_position = session.player_position + Vector2(70, 0)
	var stun_at_hit := 0
	for frame in range(1, 16):
		var events := session.step(_relative_input(session, 5, "", "D_G" if frame == 1 else ""))
		for event in events:
			if event.type == CombatEvent.Type.PLAYER_HIT:
				stun_at_hit = session.player_hitstun_left
	_check(stun_at_hit == 10, "the player hitstun comes from the selected grounded normal profile")

	var countered := CombatSession.new({"D_G": strike.duplicate(), "5A": five_a.duplicate()})
	countered.dummy_position = countered.player_position + Vector2(70, 0)
	var counter_stun := 0
	for frame in range(1, 16):
		var events := countered.step(_relative_input(countered, 5, "A" if frame == 1 else "", "D_G" if frame == 1 else ""))
		for event in events:
			if event.type == CombatEvent.Type.PLAYER_HIT:
				counter_stun = countered.player_hitstun_left
	_check(counter_stun == 14,
		"hitting the player during their own startup selects the counter profile timer")

	var air := CombatSession.new({"D_G": strike.duplicate(), "5A": five_a.duplicate()})
	air.dummy_position = air.player_position + Vector2(70, 0)
	var air_miss := 0
	var air_stun := 0
	for frame in range(1, 26):
		var input := _relative_input(air, 5, "", "D_G" if frame == 5 else "")
		if frame == 1:
			input.jump_pressed = true
			input.dummy_move_request = ""
		var events := air.step(input)
		for event in events:
			if event.type == CombatEvent.Type.HIT_MISS:
				air_miss += 1
				air_stun = air.player_hitstun_left
	_check(air_miss >= 1 and air_stun == 0,
		"a grounded-only strike missing the airborne player reports HIT_MISS with no stun")


# --- 双端一致性（spec §8：同一份表驱动运行时与 Solver）---

func _test_profile_edits_sync_session_and_solver() -> void:
	var table := MoveData.default_table()
	var report := _metrics.solve(_options(table))
	var route := _find_route(report, ["5A", "5B", "6A", "jA", "jB", "j5D"])
	_check(route != null and route.timing_valid,
		"the solver walks the 5A → 5B → 6A (chain cancels) → jump cancel → jA → jB → j5D route on the shared table")
	if route == null:
		return
	var replay := _replay_inputs(route.inputs, table)
	_check(_approx(replay["total_damage"], route.total_damage) and replay["combo_hits"] == route.combo_hits,
		"the runtime replay of the solver inputs matches the solver's damage and hit count")
	var base_damage: float = route.total_damage
	var six_normal := MoveData.profile_for(table["6A"] as MoveData,
		HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL)
	six_normal.damage_override = 25
	six_normal.horizontal_speed_px_s = 90.0
	var edited_report := _metrics.solve(_options(table))
	var edited_route := _find_route(edited_report, ["5A", "5B", "6A", "jA", "jB", "j5D"])
	## 6A 现为路线第三击：伤害层 0.72×0.9²=0.5832 → (25−16)×0.5832 ≈ 5.2。
	_check(edited_route != null and _approx(edited_route.total_damage, base_damage + 5.3),
		"editing the 6A normal profile raises the solver route total by (25-16)*0.5832 with per-hit rounding")
	var edited_replay := _replay_inputs(edited_route.inputs, table)
	_check(_approx(edited_replay["total_damage"], edited_route.total_damage),
		"the runtime replay tracks the same edited-profile damage")
	var six_counter := MoveData.profile_for(table["6A"] as MoveData,
		HitProfile.TargetState.GROUNDED, HitProfile.HitContext.COUNTER)
	six_counter.damage_override = 40
	var counter_report := _metrics.solve(_options(table))
	var counter_route := _find_route(counter_report, ["5A", "5B", "6A", "jA", "jB", "j5D"])
	_check(counter_route != null and _approx(counter_route.total_damage, edited_route.total_damage),
		"counter-profile edits never leak into the solver's normal-context routes (no fallback)")


func _test_missing_profile_reports_consistently_in_solver() -> void:
	# 时序可成、但目标 airborne 无匹配 profile 的接续：Solver 与运行时同表对拍——
	# 边按 MISS_NO_PROFILE 排除，运行时回放同一接缝得到 HIT_MISS 事件。
	var table := MoveData.default_table()
	(table["236C"] as MoveData).cancel_targets = ["5B"]
	# 测试表把 5B 命中框加高：浮空木桩在判定帧仍与命中框相交，接缝卡在
	# profile 缺失（MISS_NO_PROFILE）而不是垂直脱靶。
	(table["5B"] as MoveData).hitbox_size = Vector2(42, 120)
	var report := _metrics.solve(_options(table))
	var edge := _find_edge(report, "236C", "5B", ComboSolver.EdgeKind.CANCEL)
	_check(edge != null and not edge.valid and edge.reason.contains("MISS_NO_PROFILE"),
		"the 236C → 5B edge is excluded with the MISS_NO_PROFILE reason (5B has no airborne profile)")
	var session := CombatSession.new(table)
	session.dummy_position = session.player_position + Vector2(70, 0)
	var misses := 0
	for frame in range(1, 40):
		var digit := 5
		if frame == 1:
			digit = 2
		elif frame == 2:
			digit = 3
		elif frame == 3:
			digit = 6
		var key := ""
		if frame == 4:
			key = "C"
		elif frame == 19:
			key = "B"
		var events := session.step(_relative_input(session, digit, key))
		for event in events:
			if event.type == CombatEvent.Type.HIT_MISS:
				misses += 1
	_check(misses == 1, "the runtime replay of the same seam reports exactly one HIT_MISS")


# --- 助手 ---

func _profile(target: int, context: int, reaction: int, overrides: Dictionary = {}) -> HitProfile:
	var profile := HitProfile.new()
	profile.target_state = target
	profile.hit_context = context
	profile.reaction = reaction
	for field in overrides:
		profile.set(field, overrides[field])
	return profile


func _strike_with(profiles: Array) -> MoveData:
	var move := MoveData.new()
	move.move_id = "PROBE"
	move.move_kind = MoveData.MoveKind.STRIKE
	move.stance = MoveData.Stance.GROUND
	move.action_key = "A"
	move.startup_frames = 5
	move.active_frames = 7
	move.recovery_frames = 13
	move.cancel_window_frames = GameParams.CANCEL_WINDOW_FRAMES
	move.priority = 1
	move.base_damage = 10
	move.attack_attribute = MoveData.AttackAttribute.HIGH
	move.hitbox_size = GameParams.ATTACK_HITBOX_SIZE
	move.hitbox_gap = GameParams.ATTACK_HITBOX_GAP
	var typed: Array[HitProfile] = []
	for profile in profiles:
		typed.append(profile)
	move.hit_profiles = typed
	move.starter_grade = MoveData.StarterGrade.D
	move.block_freeze_frames = 8
	move.block_stun_frames = 9
	move.block_pushback_px_s = 45.0
	return move


## Counter 探针表：共享表 + D_S（木桩慢速挥空攻击，微命中框不触及玩家，
## startup 10 / active 2 / recovery 6）+ D_G（木桩快攻，normal 硬直 10 /
## counter 硬直 14，仅 grounded——玩家空中时必 MISS）。
func _counter_probe_table() -> Dictionary:
	var table := MoveData.default_table()
	var slow := _strike_with([
		_profile(HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL,
			HitProfile.Reaction.GROUND_HITSTUN, {"ground_stun_frames": 5, "horizontal_speed_px_s": 0.0, "upward_speed_px_s": 0.0}),
	])
	slow.move_id = "D_S"
	slow.action_key = ""
	slow.hitbox_size = Vector2(2, 2)
	slow.hitbox_gap = 0.0
	slow.startup_frames = 10
	slow.active_frames = 2
	slow.recovery_frames = 6
	table["D_S"] = slow
	var quick := _strike_with([
		_profile(HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL,
			HitProfile.Reaction.GROUND_HITSTUN, {"ground_stun_frames": 10, "horizontal_speed_px_s": 100.0, "upward_speed_px_s": 0.0}),
		_profile(HitProfile.TargetState.GROUNDED, HitProfile.HitContext.COUNTER,
			HitProfile.Reaction.GROUND_HITSTUN, {"ground_stun_frames": 14, "horizontal_speed_px_s": 100.0, "upward_speed_px_s": 0.0}),
	])
	quick.move_id = "D_G"
	quick.action_key = ""
	quick.hitbox_size = Vector2(60, 60)
	quick.startup_frames = 2
	quick.active_frames = 4
	quick.recovery_frames = 3
	table["D_G"] = quick
	return table


func _relative_input(session: CombatSession, digit: int, key: String = "", dummy_request: String = "") -> FrameInput:
	var axis := 0
	if [1, 4, 7].has(digit):
		axis = -session.player_facing
	elif [3, 6, 9].has(digit):
		axis = session.player_facing
	return FrameInput.make(axis, false, key, [1, 2, 3].has(digit), dummy_request)


func _options(table: Dictionary) -> ComboSolver.SolverOptions:
	var opts := ComboSolver.SolverOptions.new()
	opts.move_table = table
	opts.facings = [1]
	return opts


func _find_route(report: ComboSolver.SolverReport, move_ids: Array[String]) -> ComboSolver.SolverRoute:
	for route in report.routes:
		if route.move_ids == move_ids:
			return route
	return null


func _find_edge(report: ComboSolver.SolverReport, from_id: String, to_id: String, kind: int) -> ComboSolver.SolverEdge:
	for edge in report.edges:
		if edge.from_id == from_id and edge.to_id == to_id and edge.kind == kind:
			return edge
	return null


## 把 Solver 输入表回放到用同一份表的全新 CombatSession（木桩按探针几何钉位）。
func _replay_inputs(inputs: Array, table: Dictionary) -> Dictionary:
	var by_frame := {}
	var last := 0
	for spec in inputs:
		by_frame[spec.frame] = spec
		last = maxi(last, spec.frame)
	var session := CombatSession.new(table)
	var hit_frames: Array[int] = []
	var frame := 0
	while frame < last + 12:
		frame += 1
		while session.hitstop_active():
			session.step(FrameInput.new())
			session.dummy_position.x = session.player_position.x + session.player_facing * ComboSolver.PIN_DX
		var input := FrameInput.new()
		if by_frame.has(frame):
			input = by_frame[frame].to_frame_input()
		var events := session.step(input)
		session.dummy_position.x = session.player_position.x + session.player_facing * ComboSolver.PIN_DX
		for event in events:
			if event.type == CombatEvent.Type.HIT:
				hit_frames.append(frame)
	return {"hit_frames": hit_frames, "combo_hits": session.combo_hits, "total_damage": session.combo_total_damage}


func _approx(value: float, expected: float, tolerance := 0.05) -> bool:
	return absf(value - expected) < tolerance


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  " + label)
	else:
		print("FAIL  " + label)
		_failures += 1
